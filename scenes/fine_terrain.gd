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
## ...and the two things that decide whether that reads as ROCK or as STATIC.
##
## FREQUENCY. Sampled on an integer grid, a noise field at frequency 1.3 has a period well under two
## samples: neighbouring fine cells get uncorrelated values, and the "crisp grit" octave was therefore
## not grit at all — it was white noise, one value per 8px cell. Printed at 3x magnification the rock
## floor came out as a high-contrast CHECKERBOARD, which is the loudest programmer-art tell there is, and
## no amount of hue, patch or crack work above it survives being averaged with static. Both octaves now
## resolve: features clump across several cells the way granular rock does.
##
## ANISOTROPY. Even resolved, isotropic noise reads as fog or sand — never as stone. Rock has GRAIN, and
## sedimentary rock's grain is horizontal. Sampling with the X axis compressed makes every feature wider
## than it is tall, so the grain lies down into bedding and the eye reads a face of layered rock instead
## of a field of dots. Same trick CAVE_XSTRETCH plays on the cave noise, one scale down.
const GRAIN_FREQ: float = 0.34                         ## dense speckle — clumps ~3 fine cells (24px)
const GRAIN_FREQ2: float = 0.85                        ## crisper grit, still above the sample rate
const GRAIN_XSTRETCH: float = 0.38                     ## <1 = features stretch HORIZONTALLY (bedding)
const GRAIN_AMP: float = 0.15                          ## value swing of the grain
## ROCK INTERNAL TONAL VARIATION (diff-04 #1): the interiors of the reference rock are far from flat —
## broad PATCHES of lighter/darker rock, darker EMBEDDED-STONE blobs, and faint hairline cracks. Three
## noise scales layer on top of the fine grain so the rock reads busy/detailed EVERYWHERE, not just at
## edges. Patch = a big soft ±value swing; stone = a mid-freq mask that, past a threshold, darkens a
## whole cluster into an embedded stone; crack = a ridged thin dark seam.
const PATCH_FREQ: float = 0.045                        ## big low-freq tonal patches (~22 fine cells / ~2.7 cells)
const PATCH_AMP: float = 0.19                          ## value swing of the broad patches (lighter/darker rock)
const STONE_FREQ: float = 0.16                         ## embedded darker-stone blobs (~6 fine cells across)
const STONE_THRESH: float = 0.42                       ## noise above this darkens into an embedded stone
const STONE_DARKEN: float = 0.30                       ## how much a stone blob darkens the fill
const CRACK_FREQ: float = 0.11                         ## faint hairline cracks — ridged noise near its zero-crossing
const CRACK_DARKEN: float = 0.26                       ## how dark a crack seam gets
## ROCK HUE VARIATION (diff-04 #3): the reference rock isn't one blue-grey — it drifts subtly teal ↔
## faint brown ↔ faint violet by region. A very-low-freq 2-noise field picks a hue offset per region;
## kept DARK + subtle so it breaks the monochrome without turning the rock colourful.
const HUE_FREQ: float = 0.028                          ## enormous regions (~36 fine cells) so a whole face shares a tint
const HUE_AMP: float = 0.12                            ## strength of the region hue lerp (subtle)
const HUE_TEAL := Color(0.16, 0.30, 0.34)              ## cool teal pole
const HUE_BROWN := Color(0.30, 0.24, 0.17)             ## faint warm-brown pole
const HUE_VIOLET := Color(0.24, 0.18, 0.30)            ## faint violet pole
## MOSS on exposed rock TOPS (Noita diff 5): the topmost solid fine cells of a rock face (open air above)
## tint toward an olive/moss green — the mossy ledges of the reference. Confined to the top MOSS_DEPTH
## fine rows below the exposed surface, and only where enough open air sits above (a real ledge, not a
## crevice ceiling). Deterministic per fine cell — no RNG, determinism-safe.
const MOSS_COLOR := Color(0.25, 0.36, 0.15)            ## olive-moss green, darkened off the LAWN a saturated green
                                                      ## printed at 3x: growth ON rock, not green tiles
const MOSS_DEPTH: int = 3                              ## fine rows of moss below an exposed top edge (5 read as a
                                                      ## LAWN at 3x magnification; 3 is a damp rim on a ledge)
## MOSS IS ALIVE, and living things want light and water. Ungated, the band carpeted every exposed ledge
## at EVERY depth in saturated olive — a green lawn a hundred metres inside the earth, which is the
## loudest wrong note in the underground and reads instantly as a texture RULE rather than as a world.
## It now thins with depth and is gone below MOSS_DEAD_ROW, so the shallow ledges keep the damp growing
## look the reference has and the deep is bare rock, the way the deep should be.
const RIM_DEPTH: int = 2                               ## fine rows the lit lip fades over (1 = a dotted line)
const MOSS_LUSH_ROW: int = 22                          ## full moss down to here — the damp shallow ledges
const MOSS_DEAD_ROW: int = 34                          ## ...and none below here (14 m: roots and daylight end)
const MOSS_FREQ: float = 0.9                           ## breaks the moss into organic patches, not a solid band
## HANGING MOSS TUFTS (diff-04 #2): a few moss pixels drip BELOW down-facing overhangs (open air directly
## below a solid fine cell). Confined to the top HANG_DEPTH fine rows below such a lip, noise-masked so
## only the odd lip grows a tuft — the reference's hanging tufts under ledges.
const HANG_DEPTH: int = 3                              ## fine rows a tuft hangs below an overhang lip
const HANG_GATE: float = 0.30                          ## only lips whose moss-noise clears this hang a tuft (sparse)
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
var _patch: FastNoiseLite                              ## broad tonal patches (diff-04 #1)
var _stone: FastNoiseLite                              ## embedded darker-stone blobs (diff-04 #1)
var _crack: FastNoiseLite                              ## hairline crack seams (diff-04 #1)
var _huex: FastNoiseLite                               ## region hue field, x axis (diff-04 #3)
var _huey: FastNoiseLite                               ## region hue field, y axis (diff-04 #3)
var _img: Image
var _tex: ImageTexture
# Persisted caches so a per-dig rebake can patch a SUB-RECT instead of the whole grid (#102 dirty-chunks).
# The full rebake fills them; rebake_region refreshes only the changed cells + reads neighbours from these.
var _data: PackedByteArray = PackedByteArray()          ## the baked pixel bytes (region rebakes overwrite a sub-rect)
var _fine_solid: PackedByteArray = PackedByteArray()    ## the real fine solid/air grid (neighbours for region AO/moss)
var _solid_mask: PackedFloat32Array = PackedFloat32Array()  ## coarse solidity 0/1
var _mat_col: PackedColorArray = PackedColorArray()     ## coarse body colour (solid cells)
var _wall_col: PackedColorArray = PackedColorArray()    ## coarse back-wall colour
var _surf_row: PackedInt32Array = PackedInt32Array()    ## walkable surface row per column (cap band)
var last_baked_cells: int = 0                           ## fine cells the LAST bake touched — the dig-hitch friction gauge (#103)
## Fine-cell dilation for a region rebake: must cover the widest neighbour reach any paint term reads so a
## patched region is byte-identical to a full bake — MOSS_DEPTH(3 up) / HANG_DEPTH(3 down) / SUBDIV(4,
## accretion). RIM_DEPTH(2) and _moss_life (a pure function of the row) are both inside that reach.
const REGION_MARGIN: int = 6


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
	# diff-04 #1 — broad tonal patches + embedded stones + cracks (each its own seed so they don't correlate).
	_patch = FastNoiseLite.new()
	_patch.seed = seed ^ 0x2545f491
	_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch.frequency = PATCH_FREQ
	_stone = FastNoiseLite.new()
	_stone.seed = seed ^ 0x1b873593
	_stone.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_stone.frequency = STONE_FREQ
	_crack = FastNoiseLite.new()
	_crack.seed = seed ^ 0x85ebca77
	_crack.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_crack.frequency = CRACK_FREQ
	# diff-04 #3 — two independent low-freq fields → a region hue offset picked per broad region.
	_huex = FastNoiseLite.new()
	_huex.seed = seed ^ 0xc2b2ae35
	_huex.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_huex.frequency = HUE_FREQ
	_huey = FastNoiseLite.new()
	_huey.seed = seed ^ 0x27d4eb2f
	_huey.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_huey.frequency = HUE_FREQ
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
## P2: the fine SHAPE now comes from the sim's real fine grid (fine_solid_at) instead
## of a molded field computed here from the coarse mask — real fine DATA reads crunchier + carries whatever
## detail worldgen put there. The renderer keeps ownership of the LOOK (AO, grain, moss, rim, palette).
## Runs the WHOLE fine grid; called on the initial paint + a wholesale change (load/repaint_world). The
## per-dig fast lane is rebake_region (dirty-chunks, #102). Fills the persisted caches, then paints every
## fine cell via _paint_fine (shared with the region path).
func rebake(solid_at: Callable, fine_solid_at: Callable, material_color_at: Callable, wall_color_at: Callable,
		surface_at: Callable) -> void:
	# The walkable-surface row per column (cache the coarse authority once) so the mold can leave that
	# cell's cap band to the coarse grass/ramp pass beneath it.
	_surf_row.resize(_cols)
	for cx: int in _cols:
		_surf_row[cx] = int(surface_at.call(cx))
	# Coarse solid mask (0.0/1.0): a single lookup per coarse cell instead of SUBDIV² per fine.
	_solid_mask.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			_solid_mask[cy * _cols + cx] = 1.0 if bool(solid_at.call(Vector2i(cx, cy))) else 0.0
	# Cache coarse colours once per cell (reused by all SUBDIV² children).
	_mat_col.resize(_cols * _rows)
	_wall_col.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			var idx: int = cy * _cols + cx
			if _solid_mask[idx] > 0.5:
				_mat_col[idx] = material_color_at.call(Vector2i(cx, cy)) as Color
			_wall_col[idx] = wall_color_at.call(Vector2i(cx, cy)) as Color
	_data.resize(_fcols * _frows * 4)
	# Read the REAL fine solid/air shape from the sim's fine grid (P2 — the molding lives in the sim's fine
	# DATA), stashed so the paint can read neighbours for fine AO.
	_fine_solid.resize(_fcols * _frows)
	for fy: int in _frows:
		for fx: int in _fcols:
			_fine_solid[fy * _fcols + fx] = 1 if bool(fine_solid_at.call(fx, fy)) else 0
	for fy: int in _frows:
		for fx: int in _fcols:
			_paint_fine(fx, fy)
	last_baked_cells = _fcols * _frows
	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, _data)
	_tex.update(_img)


## THE PER-DIG FAST LANE (#102 dirty-chunks — the mining micro-freeze fix). Rebake ONLY the fine cells under
## the changed coarse cells [cmin..cmax], DILATED by REGION_MARGIN so every neighbour-reading paint term
## (AO / moss / accretion / rim) recomputes exactly as a full bake would → the output is byte-identical to
## rebake() but touches ~256 cells for a single dig, not the whole ~120k grid. Falls back to a full rebake
## if the grid was never fully baked (nothing cached to patch). Callables match rebake()'s.
func rebake_region(cmin: Vector2i, cmax: Vector2i, solid_at: Callable, fine_solid_at: Callable,
		material_color_at: Callable, wall_color_at: Callable, surface_at: Callable) -> void:
	if _data.size() != _fcols * _frows * 4:
		rebake(solid_at, fine_solid_at, material_color_at, wall_color_at, surface_at)
		return
	cmin.x = maxi(cmin.x, 0)
	cmin.y = maxi(cmin.y, 0)
	cmax.x = mini(cmax.x, _cols - 1)
	cmax.y = mini(cmax.y, _rows - 1)
	if cmin.x > cmax.x or cmin.y > cmax.y:
		return
	# 1) Refresh the coarse caches for the changed cells only (a handful — cheap). Neighbour coarse cells the
	#    dilated paint reads keep their persisted values (they didn't change).
	for cx: int in range(cmin.x, cmax.x + 1):
		_surf_row[cx] = int(surface_at.call(cx))
	for cy: int in range(cmin.y, cmax.y + 1):
		for cx: int in range(cmin.x, cmax.x + 1):
			var idx: int = cy * _cols + cx
			var s: bool = bool(solid_at.call(Vector2i(cx, cy)))
			_solid_mask[idx] = 1.0 if s else 0.0
			if s:
				_mat_col[idx] = material_color_at.call(Vector2i(cx, cy)) as Color
			_wall_col[idx] = wall_color_at.call(Vector2i(cx, cy)) as Color
	# 2) Refresh the real fine solid/air shape for the changed cells' fine footprint.
	var fx0c: int = cmin.x * SUBDIV
	var fy0c: int = cmin.y * SUBDIV
	var fx1c: int = (cmax.x + 1) * SUBDIV - 1
	var fy1c: int = (cmax.y + 1) * SUBDIV - 1
	for fy: int in range(fy0c, fy1c + 1):
		for fx: int in range(fx0c, fx1c + 1):
			_fine_solid[fy * _fcols + fx] = 1 if bool(fine_solid_at.call(fx, fy)) else 0
	# 3) Repaint the footprint DILATED by the neighbour reach so border AO/moss/accretion recompute right.
	var fx0: int = maxi(fx0c - REGION_MARGIN, 0)
	var fy0: int = maxi(fy0c - REGION_MARGIN, 0)
	var fx1: int = mini(fx1c + REGION_MARGIN, _fcols - 1)
	var fy1: int = mini(fy1c + REGION_MARGIN, _frows - 1)
	var painted: int = 0
	for fy: int in range(fy0, fy1 + 1):
		for fx: int in range(fx0, fx1 + 1):
			_paint_fine(fx, fy)
			painted += 1
	last_baked_cells = painted
	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, _data)
	_tex.update(_img)


## Fully-transparent texel (all 4 bytes zeroed) so region and full bakes stay byte-identical on air/cap
## cells — no stale RGB lingering under A=0 from a prior bake.
func _clear_fine(i4: int) -> void:
	_data[i4] = 0
	_data[i4 + 1] = 0
	_data[i4 + 2] = 0
	_data[i4 + 3] = 0


## Paint ONE fine cell into _data from the cached coarse + fine grids — the per-cell body shared by the full
## rebake and the region fast lane. Solid → the parent's molded body colour with fine AO/hue/grain/moss/rim;
## eroded (parent solid, now fine-air) → recessed back-rock; genuine open air / surface cap → transparent.
func _paint_fine(fx: int, fy: int) -> void:
	var i4: int = (fy * _fcols + fx) * 4
	var pcol: int = fx / SUBDIV
	var prow: int = fy / SUBDIV
	var cidx: int = prow * _cols + pcol
	# Leave the coarse surface CAP band uncovered: the top SURFACE_KEEP fine rows of a column's walkable
	# surface cell stay transparent so the grass/lip + ramp cap (z -10) reads through and the SEEN top line
	# stays exactly the WALKED line. Rock below the cap is still fully molded.
	if prow == _surf_row[pcol] and (fy - prow * SUBDIV) < SURFACE_KEEP:
		_clear_fine(i4)
		return
	var here_solid: bool = _fine_solid[fy * _fcols + fx] == 1
	var parent_solid: bool = _solid_mask[cidx] > 0.5
	if here_solid:
		var col: Color = _mat_col[cidx] if parent_solid else _accreted_color(_mat_col, _wall_col, _solid_mask, fx, fy, cidx)
		# ROCK HUE VARIATION (diff-04 #3): pull the body colour a hair toward a region-picked hue pole
		# (teal / faint brown / faint violet) so a broad rock face carries its own subtle tint and the frame
		# stops reading as one monochrome blue-grey. Very-low-freq → whole faces share a tone; a two-noise
		# pick keeps neighbouring regions from all landing on the same pole.
		var hx: float = _huex.get_noise_2d(float(fx), float(fy))
		var hy: float = _huey.get_noise_2d(float(fx), float(fy))
		var pole: Color = HUE_TEAL if hx < -0.15 else (HUE_BROWN if hx > 0.20 else HUE_VIOLET)
		col = col.lerp(pole, HUE_AMP * clampf(0.5 + 0.5 * hy, 0.15, 1.0))
		# Fine AO: air among the 4 orthogonal AND 4 diagonal fine neighbours; each open cell darkens the
		# fill toward that edge, so a lone fine nub reads round and an exposed face reads deeply carved.
		var air_n: float = _air_weight(_fine_solid, fx, fy)
		var shade: float = 1.0 - 0.125 * air_n
		if air_n > 0.5:                         # COOL SHADOW (fix-2 diff 3): carved rock tints cold teal-blue
			col = col.lerp(SHADOW_TEAL, clampf(air_n / 6.0, 0.0, 1.0) * 0.34)
		# A low-frequency tonal drift so a broad rock face isn't one flat colour + interiors deepen.
		var drift: float = _noise.get_noise_2d(float(fx) * 0.35 + 500.0, float(fy) * 0.35) * 0.07
		# BROAD TONAL PATCHES (diff-04 #1): a big soft low-freq value swing so wide areas of rock read as
		# lighter/darker patches, not one flat tone — the reference's mottled interiors.
		drift += _patch.get_noise_2d(float(fx), float(fy)) * PATCH_AMP
		# DENSE GRAIN/SPECKLE (diff 4): two octaves of high-freq noise pit + clod the rock so it reads
		# granular. Multiplicative on value so it rides the material's own colour.
		var gx: float = float(fx) * GRAIN_XSTRETCH
		var grain: float = _grain.get_noise_2d(gx, float(fy)) * GRAIN_AMP \
			+ _grain2.get_noise_2d(gx, float(fy)) * (GRAIN_AMP * 0.45)
		# EMBEDDED STONES + CRACKS (diff-04 #1): a mid-freq mask, past a threshold, darkens a whole cluster
		# into an embedded darker stone; a ridged near-zero band of a second field cuts a thin dark crack.
		var stone: float = _stone.get_noise_2d(float(fx), float(fy))
		if stone > STONE_THRESH:
			grain -= STONE_DARKEN * clampf((stone - STONE_THRESH) * 4.0, 0.0, 1.0)
		var crackv: float = absf(_crack.get_noise_2d(float(fx) * 1.4, float(fy)))
		if crackv < 0.05:
			grain -= CRACK_DARKEN * (1.0 - crackv / 0.05)
		# RIM light (diff 7): the topmost solid fine cell of a face (open air directly above) catches a
		# bright lip — Noita's lit rock edges. A thin bright band only on the up-facing surface.
		# ...and it fades over RIM_DEPTH rows rather than lighting exactly one. A binary rim lights the
		# single topmost fine cell of each column, and the mold deliberately makes that boundary ragged —
		# so along a flat floor the lit cells and their unlit neighbours alternate, and a lip that should
		# read as a lit EDGE printed as a dotted line. Falling off over two rows makes it a band.
		var top_dist: int = _top_air_distance(_fine_solid, fx, fy)
		var rim: float = 0.0
		var rim_warm: float = 0.0
		if top_dist >= 0 and top_dist < RIM_DEPTH and not _fine_air(_fine_solid, fx, fy + 1):
			var lip: float = 1.0 - float(top_dist) / float(RIM_DEPTH)
			rim = 0.17 * lip
			rim_warm = 0.04 * lip
		var vmul: float = shade + grain
		var out := Color(col.r * vmul + drift + rim + rim_warm, col.g * vmul + drift + rim,
			col.b * vmul + drift + rim, 1.0)
		# MOSS (diff 5 / diff-04 #2): tint the exposed rock TOPS toward olive-moss. A top edge = open air
		# above; the top MOSS_DEPTH rows below it wear moss in organic patches (noise-masked), fading down.
		var alive: float = _moss_life(fy)
		if top_dist >= 0 and top_dist < MOSS_DEPTH:
			var patch: float = _moss.get_noise_2d(float(fx), float(fy) * 0.6)
			if alive > 0.0 and patch > -0.28:       # diff-04 #2: wider accept → more coverage
				var band: float = (1.0 - float(top_dist) / float(MOSS_DEPTH)) \
					* clampf((patch + 0.28) * 1.5, 0.0, 1.0)
				out = out.lerp(MOSS_COLOR, 0.66 * band * alive)
		else:
			# HANGING MOSS TUFTS (diff-04 #2): the top rows just BELOW a down-facing overhang lip grow a few
			# moss pixels dripping into the air — the reference's hanging tufts under ledges.
			var hang: int = _bottom_air_distance(_fine_solid, fx, fy)
			if hang >= 0 and hang < HANG_DEPTH:
				var hp: float = _moss.get_noise_2d(float(fx) * 1.3, float(fy) * 1.3 + 90.0)
				if alive > 0.0 and hp > HANG_GATE:
					var hband: float = (1.0 - float(hang) / float(HANG_DEPTH)) \
						* clampf((hp - HANG_GATE) * 3.0, 0.0, 1.0)
					out = out.lerp(MOSS_COLOR.darkened(0.12), 0.66 * hband * alive)
		_data[i4] = int(clampf(out.r, 0.0, 1.0) * 255.0)
		_data[i4 + 1] = int(clampf(out.g, 0.0, 1.0) * 255.0)
		_data[i4 + 2] = int(clampf(out.b, 0.0, 1.0) * 255.0)
		_data[i4 + 3] = 255
	elif parent_solid:
		# Eroded: this fine cell WAS rock, molding opened it → paint the RECESSED BACK-ROCK behind so the
		# blocky coarse fill can't show through the organic curve (fix-2 diff 6): a darker, COOLER wall that
		# reads as rock set BEHIND the foreground shelf, + a touch of fine AO so the pocket reads scooped.
		var wc: Color = _wall_col[cidx].darkened(0.42).lerp(BACKROCK_COOL, 0.30)
		var back_ao: float = 1.0 - 0.10 * _air_weight(_fine_solid, fx, fy)
		_data[i4] = int(clampf(wc.r * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 1] = int(clampf(wc.g * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 2] = int(clampf(wc.b * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 3] = 255
	else:
		_clear_fine(i4)   # genuine open air — transparent, the world below shows unchanged


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
## How alive moss is at a fine row: full in the damp shallows, gone in the deep. A pure function of the
## row, so a region re-bake after a dig stays byte-identical to a full bake.
func _moss_life(fy: int) -> float:
	var row: float = float(fy) / float(SUBDIV)
	return clampf((float(MOSS_DEAD_ROW) - row) / float(MOSS_DEAD_ROW - MOSS_LUSH_ROW), 0.0, 1.0)


## MOSS_DEPTH — an interior or overhung cell). Walks straight up: the first open-air cell within
## MOSS_DEPTH gives the distance; all-solid = interior. Drives the moss band on Noita ledge tops (diff 5).
func _top_air_distance(fine_solid: PackedByteArray, fx: int, fy: int) -> int:
	for d: int in range(MOSS_DEPTH):
		if _fine_air(fine_solid, fx, fy - d - 1):
			return d
	return -1


## Rows above the nearest EXPOSED bottom surface directly below this solid fine cell (0 = open air right
## below — a down-facing overhang lip; N = N solid rows above such a lip; -1 = no open bottom within
## HANG_DEPTH). Mirror of _top_air_distance downward; drives the hanging moss tufts (diff-04 #2).
func _bottom_air_distance(fine_solid: PackedByteArray, fx: int, fy: int) -> int:
	for d: int in range(HANG_DEPTH):
		if _fine_air(fine_solid, fx, fy + d + 1):
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
