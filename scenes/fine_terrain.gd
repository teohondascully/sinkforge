class_name FineTerrain
extends RefCounted

## FINE TERRAIN MOLDING (renderer-only, Noita-look slice 1) — makes the coarse 32px sim terrain READ
## as granular, molded rock at an 8px sub-cell grain, WITHOUT touching the sim. The sim still stores
## terrain as one material id per 32px cell (sim.solid); this baker re-renders that coarse field so its
## straight edges become organic, clumpy, curved boundaries.
##
## Technique (the whole trick): conceptually subdivide each coarse cell into SUBDIV×SUBDIV fine cells.
## For each fine cell compute a smooth "solidness" 0..1 by BILINEARLY sampling coarse solid/air at the
## fine cell's centre (so a solid/air boundary becomes a smooth ramp across ~1 coarse cell instead of a
## hard step), then PERTURB it with a deterministic FastNoiseLite and THRESHOLD at 0.5. The bilinear
## ramp is what lets the noise bend the edge: deep interior (solidness 1) and deep air (solidness 0)
## never flip — molding only happens in the ~1-cell boundary band — so cave mouths round out, walls get
## an irregular clumpy profile and rock tops undulate, while the base stays solid by construction.
##
## The result bakes to ONE Image at fine resolution, uploaded to an ImageTexture and drawn stretched
## over the world with NEAREST filtering (crisp 8px fine pixels). It rebuilds ONLY when the terrain
## changes (mirrors the veil/chunk repaint-on-change discipline) — never per frame.
##
## LIMITATION (by design, this slice): the molding is driven by COARSE data, so features are still
## ~32px-scale organic wobble — true fine-grained detail (thin 8px veins, sand piles) needs fine DATA
## in the sim, a later slice. This slice is safe and sim-free.

const SUBDIV: int = 4                                  ## fine cells per coarse cell side (8px fine @ 32px cell)
const FINE: int = 8                                    ## fine cell size in world px (CELL / SUBDIV)
## P2: the fine SHAPE (which fine cells are solid) now comes from the sim's real fine grid — the boundary
## molding/threshold constants that computed it here are gone. What remains below is pure LOOK: grain,
## moss, back-rock, shadow tints, and a low-freq tonal drift (_noise) painted over that real shape.
const TONAL_FREQ: float = 0.085                        ## low-freq drift so a broad rock face isn't one flat colour
## GRAIN + SPECKLE (Noita diff 4): a dense high-frequency per-fine-cell noise field that pits and clods
## the rock so it reads granular/textured, not smooth flat-shaded. Two octaves — a fine speckle and a
## crisper grit — modulate each solid fine cell's value.
const GRAIN_FREQ: float = 0.55                         ## dense speckle — clumps ~2 fine cells (16px)
const GRAIN_FREQ2: float = 1.30                        ## crisp per-fine-cell grit
const GRAIN_AMP: float = 0.17                          ## value swing of the grain (fix-2 diff 4: 0.14 -> 0.17 so
                                                      ## the granular pits/clods still read in the raised gloom)
## MOSS on exposed rock TOPS (Noita diff 5): the topmost solid fine cells of a rock face (open air above)
## tint toward an olive/moss green — the mossy ledges of the reference. Confined to the top MOSS_DEPTH
## fine rows below the exposed surface, and only where enough open air sits above (a real ledge, not a
## crevice ceiling). Deterministic per fine cell — no RNG, determinism-safe.
const MOSS_COLOR := Color(0.34, 0.46, 0.18)            ## olive-moss green (fix-2 diff 5: lifted a touch so it
                                                      ## catches the raised ambient and reads across the frame)
const MOSS_DEPTH: int = 3                              ## fine rows of moss below an exposed top edge
const MOSS_FREQ: float = 0.9                           ## breaks the moss into organic patches, not a solid band
## RECESSED BACK-ROCK (fix-2 diff 6): the cool tone the eroded/back-wall fine cells shift toward, so the
## rock BEHIND the carved foreground reads as a distinct, cooler, set-back layer (Noita's fore/background
## rock depth) instead of a flat near-black void.
const BACKROCK_COOL := Color(0.10, 0.15, 0.20)
## COOL SHADOW tint (fix-2 diff 3): carved/AO-shadowed foreground rock is lerped toward this cold
## teal-blue so shadows read blue-grey (the reference's cold rock), not the warm brown murk of pass-1.
const SHADOW_TEAL := Color(0.13, 0.20, 0.27)

var _cols: int
var _rows: int
var _fcols: int                                        ## fine-grid width  = cols * SUBDIV
var _frows: int                                        ## fine-grid height = rows * SUBDIV
var _noise: FastNoiseLite                              ## low-freq tonal drift over the real fine shape
var _grain: FastNoiseLite                              ## dense speckle field (diff 4)
var _grain2: FastNoiseLite                             ## crisp grit octave
var _moss: FastNoiseLite                               ## moss patch mask (diff 5)
var _img: Image
var _tex: ImageTexture


func _init(cols: int, rows: int, seed: int) -> void:
	_cols = cols
	_rows = rows
	_fcols = cols * SUBDIV
	_frows = rows * SUBDIV
	_noise = FastNoiseLite.new()
	_noise.seed = seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = TONAL_FREQ
	_grain = FastNoiseLite.new()
	_grain.seed = seed ^ 0x27d4eb2f
	_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_grain.frequency = GRAIN_FREQ
	_grain2 = FastNoiseLite.new()
	_grain2.seed = seed ^ 0x165667b1
	_grain2.noise_type = FastNoiseLite.TYPE_VALUE      ## blocky value noise = crisp per-pixel grit
	_grain2.frequency = GRAIN_FREQ2
	_moss = FastNoiseLite.new()
	_moss.seed = seed ^ 0x9e3779b1
	_moss.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_moss.frequency = MOSS_FREQ
	_img = Image.create(_fcols, _frows, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)


func texture() -> Texture2D:
	return _tex


## World-space rect the baked texture covers (the whole world, stretched 1 fine texel = FINE px).
func world_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(_cols * CELL_PX()), float(_rows * CELL_PX()))


static func CELL_PX() -> int:
	return SUBDIV * FINE   # 32


## The topmost fine-row band of a column's walkable surface cell the mold leaves to the COARSE cap: the
## grass/lip + ramp cap draws below (z -10) and must stay legible + exactly on the walked line, so the
## mold doesn't paint over it. Small (SURFACE_KEEP fine rows ≈ the cap thickness) so the rock just below
## the grass is still fully molded.
const SURFACE_KEEP: int = 2

## Rebake the fine terrain into the Image + upload. The Callables let the paint reuse the exact palette /
## surface authority the coarse pass uses:
##   solid_at(Vector2i) -> bool              (the COARSE cell — parent solidity, for colour + accretion source)
##   fine_solid_at(int fx, int fy) -> bool   (P2: the REAL fine terrain grid from the sim — the molded shape)
##   material_color_at(Vector2i) -> Color    (the coarse cell's body colour; only called on solid cells)
##   wall_color_at(Vector2i) -> Color        (the back-wall colour to show where solid rock is ERODED to air)
##   surface_at(int col) -> int              (the walkable surface row of a column; its cap is left uncovered)
## P2 (docs/FINE_TERRAIN.md): the fine SHAPE now comes from the sim's real fine grid (fine_solid_at) instead
## of a molded field computed here from the coarse mask — real fine DATA reads crunchier + carries whatever
## detail worldgen put there. The renderer keeps ownership of the LOOK (AO, grain, moss, rim, palette).
## Runs the full fine grid once; called only on terrain change (see WorldRenderer._fine_dirty).
func rebake(solid_at: Callable, fine_solid_at: Callable, material_color_at: Callable, wall_color_at: Callable,
		surface_at: Callable) -> void:
	# The walkable-surface row per column (cache the coarse authority once) so the mold can leave that
	# cell's cap band to the coarse grass/ramp pass beneath it.
	var surf_row: PackedInt32Array = PackedInt32Array()
	surf_row.resize(_cols)
	for cx: int in _cols:
		surf_row[cx] = int(surface_at.call(cx))
	# Precompute the coarse solid mask (0.0/1.0) padded by one cell so bilinear sampling at the world
	# edge reads "air" outside — a single dictionary lookup per coarse cell instead of SUBDIV² per fine.
	var solid_mask: PackedFloat32Array = PackedFloat32Array()
	solid_mask.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			solid_mask[cy * _cols + cx] = 1.0 if bool(solid_at.call(Vector2i(cx, cy))) else 0.0
	# Cache coarse colours once per cell (reused by all SUBDIV² children).
	var mat_col: PackedColorArray = PackedColorArray()
	var wall_col: PackedColorArray = PackedColorArray()
	mat_col.resize(_cols * _rows)
	wall_col.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			var idx: int = cy * _cols + cx
			if solid_mask[idx] > 0.5:
				mat_col[idx] = material_color_at.call(Vector2i(cx, cy)) as Color
			wall_col[idx] = wall_color_at.call(Vector2i(cx, cy)) as Color

	var data: PackedByteArray = PackedByteArray()
	data.resize(_fcols * _frows * 4)
	# First pass: read the REAL fine solid/air shape from the sim's fine grid (P2 — the molding now lives in
	# the sim's fine DATA, not a field computed here), stashed so pass two can read neighbours for fine AO.
	var fine_solid: PackedByteArray = PackedByteArray()
	fine_solid.resize(_fcols * _frows)
	for fy: int in _frows:
		for fx: int in _fcols:
			fine_solid[fy * _fcols + fx] = 1 if bool(fine_solid_at.call(fx, fy)) else 0

	# Second pass: paint. Solid fine cell → its parent's molded body colour, with fine-scale AO (darker
	# where it borders air = rounded/carved read) + a low-freq tonal drift. Eroded fine cell (parent was
	# solid, now air) → the back-wall colour so the blocky terrain fill beneath never peeks through the
	# curve. Fine cell over genuinely-open coarse air → transparent (backdrop/existing walls unchanged).
	for fy: int in _frows:
		for fx: int in _fcols:
			var i4: int = (fy * _fcols + fx) * 4
			var pcol: int = fx / SUBDIV
			var prow: int = fy / SUBDIV
			var cidx: int = prow * _cols + pcol
			# Leave the coarse surface CAP band uncovered: the top SURFACE_KEEP fine rows of a column's
			# walkable surface cell stay transparent so the grass/lip + ramp cap (z -10) reads through and
			# the SEEN top line stays exactly the WALKED line. Rock below the cap is still fully molded.
			if prow == surf_row[pcol] and (fy - prow * SUBDIV) < SURFACE_KEEP:
				data[i4 + 3] = 0
				continue
			var here_solid: bool = fine_solid[fy * _fcols + fx] == 1
			var parent_solid: bool = solid_mask[cidx] > 0.5
			if here_solid:
				var col: Color = mat_col[cidx] if parent_solid else _accreted_color(mat_col, wall_col, solid_mask, fx, fy, cidx)
				# Fine AO: air among the 4 orthogonal AND 4 diagonal fine neighbours; each open cell darkens
				# the fill toward that edge, so a lone fine nub reads round and an exposed face reads deeply
				# carved (the shadow that sells molded rock). Diagonals count half so corners round smoothly.
				# Interior AO DEEPENED (diff 7): 0.085 → 0.16 per air neighbour so exposed faces go far darker
				# (toward black cores), reading rounded + carved against the near-black veil.
				var air_n: float = _air_weight(fine_solid, fx, fy)
				var shade: float = 1.0 - 0.125 * air_n
				if air_n > 0.5:                         # COOL SHADOW (fix-2 diff 3): carved rock tints cold teal-blue
					col = col.lerp(SHADOW_TEAL, clampf(air_n / 6.0, 0.0, 1.0) * 0.34)
				# A low-frequency tonal drift so a broad rock face isn't one flat colour + interiors deepen.
				var drift: float = _noise.get_noise_2d(float(fx) * 0.35 + 500.0, float(fy) * 0.35) * 0.07
				# DENSE GRAIN/SPECKLE (diff 4): two octaves of high-freq noise pit + clod the rock so it
				# reads granular. Multiplicative on value so it rides the material's own colour.
				var grain: float = _grain.get_noise_2d(float(fx), float(fy)) * GRAIN_AMP \
					+ _grain2.get_noise_2d(float(fx), float(fy)) * (GRAIN_AMP * 0.55)
				# RIM light (diff 7): the topmost solid fine cell of a face (open air directly above) catches
				# a bright lip — Noita's lit rock edges. A thin bright band only on the up-facing surface.
				var rim: float = 0.0
				var rim_warm: float = 0.0
				if _fine_air(fine_solid, fx, fy - 1) and not _fine_air(fine_solid, fx, fy + 1):
					rim = 0.17
					rim_warm = 0.04
				var vmul: float = shade + grain
				var out := Color(col.r * vmul + drift + rim + rim_warm, col.g * vmul + drift + rim,
					col.b * vmul + drift + rim, 1.0)
				# MOSS (diff 5): tint the exposed rock TOPS toward olive-moss. A top edge = open air above;
				# the top MOSS_DEPTH rows below it wear moss in organic patches (noise-masked), fading down.
				var top_dist: int = _top_air_distance(fine_solid, fx, fy)
				if top_dist >= 0 and top_dist < MOSS_DEPTH:
					var patch: float = _moss.get_noise_2d(float(fx), float(fy) * 0.6)
					if patch > -0.1:
						var band: float = (1.0 - float(top_dist) / float(MOSS_DEPTH)) \
							* clampf((patch + 0.1) * 1.6, 0.0, 1.0)
						out = out.lerp(MOSS_COLOR, 0.80 * band)   # fix-2 diff 5: moss reads stronger in the gloom
				data[i4] = int(clampf(out.r, 0.0, 1.0) * 255.0)
				data[i4 + 1] = int(clampf(out.g, 0.0, 1.0) * 255.0)
				data[i4 + 2] = int(clampf(out.b, 0.0, 1.0) * 255.0)
				data[i4 + 3] = 255
			elif parent_solid:
				# Eroded: this fine cell WAS rock, molding opened it → paint the RECESSED BACK-ROCK behind
				# so the blocky coarse fill can't show through the organic curve. This is the depth layer
				# (fix-2 diff 6): a darker, COOLER version of the wall that reads as rock set BEHIND the
				# foreground shelf — not a flat near-black void (pass-1 crushed it to 0.55 and lost the 3D
				# read). Darken 0.55 → 0.42 (still clearly recessed, but legible) + a cool teal shift so it
				# sits back in the same cold palette as the shadowed rock. A touch of fine AO from the
				# air-facing side keeps the pocket reading scooped.
				var wc: Color = wall_col[cidx].darkened(0.42).lerp(BACKROCK_COOL, 0.30)
				var back_ao: float = 1.0 - 0.10 * _air_weight(fine_solid, fx, fy)
				data[i4] = int(clampf(wc.r * back_ao, 0.0, 1.0) * 255.0)
				data[i4 + 1] = int(clampf(wc.g * back_ao, 0.0, 1.0) * 255.0)
				data[i4 + 2] = int(clampf(wc.b * back_ao, 0.0, 1.0) * 255.0)
				data[i4 + 3] = 255
			else:
				data[i4 + 3] = 0   # genuine open air — transparent, the world below shows unchanged

	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, data)
	_tex.update(_img)


## Weighted OPEN-air neighbour count around a solid fine cell — the fine AO term. Orthogonal neighbours
## weigh 1, diagonals 0.5, so an exposed face darkens strongly and a corner rounds off smoothly (0..6).
## Off-grid counts as air (the world edge reads carved, not walled).
func _air_weight(fine_solid: PackedByteArray, fx: int, fy: int) -> float:
	var w: float = 0.0
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if _fine_air(fine_solid, fx + d.x, fy + d.y):
			w += 1.0
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if _fine_air(fine_solid, fx + d.x, fy + d.y):
			w += 0.5
	return w


func _fine_air(fine_solid: PackedByteArray, fx: int, fy: int) -> bool:
	if fx < 0 or fy < 0 or fx >= _fcols or fy >= _frows:
		return true
	return fine_solid[fy * _fcols + fx] == 0


## Rows below the nearest EXPOSED top surface directly above this solid fine cell (0 = this cell has
## open air right above it — a ledge top; N = N solid rows below such a top; -1 = no open top within
## MOSS_DEPTH — an interior or overhung cell). Walks straight up: the first open-air cell within
## MOSS_DEPTH gives the distance; all-solid = interior. Drives the moss band on Noita ledge tops (diff 5).
func _top_air_distance(fine_solid: PackedByteArray, fx: int, fy: int) -> int:
	for d: int in range(MOSS_DEPTH):
		if _fine_air(fine_solid, fx, fy - d - 1):
			return d
	return -1


## Colour for a fine cell of rock ACCRETED into a coarse-air cell (molding grew rock past the coarse
## boundary): borrow the nearest solid coarse neighbour's body colour so the growth reads as the same
## rock mass reaching over, not a new material. Falls back to the parent's wall tint if truly isolated.
func _accreted_color(mat_col: PackedColorArray, wall_col: PackedColorArray, mask: PackedFloat32Array,
		fx: int, fy: int, cidx: int) -> Color:
	var pcx: int = fx / SUBDIV
	var pcy: int = fy / SUBDIV
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var nx: int = pcx + d.x
		var ny: int = pcy + d.y
		if nx < 0 or ny < 0 or nx >= _cols or ny >= _rows:
			continue
		if mask[ny * _cols + nx] > 0.5:
			return mat_col[ny * _cols + nx]
	return wall_col[cidx].lightened(0.05)
