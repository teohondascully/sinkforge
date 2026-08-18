extends RefCounted

## THE TERRAIN PAINTER — the coarse-terrain draw pipeline (per-cell fill/grain/ore-crystals, the autotile
## silhouette chamfers + concave fillets, carved-edge ambient occlusion, and the walkable surface cap/ramp
## pass), extracted from WorldRenderer so the renderer isn't carrying ~300 lines of terrain drawing.
## Stateless: it paints onto the baked terrain CanvasItem the renderer hands it, reads terrain from r.sim,
## and pulls each cell's APPEARANCE (colour/grain/speckles/material) from the renderer's shared helpers
## (r._cell_fill_color / r._material / r._cell_speckles — those stay on WorldRenderer because walls,
## fine-terrain and the minimap share them). Bake-time code (drawn once per dirty chunk into the terrain
## SubViewport, not per frame), so the r.x reach-backs are amortized. Deterministic; purely cosmetic.

## THE KEY LIGHT (#A1) — the carved-edge pass's four face weights, in one place because they only mean
## anything relative to each other. Light comes from straight ABOVE (the same direction the veil's
## skylight floods), so a sky-facing top catches a warm lit lip while an underside falls into the
## deepest shadow in the frame and walls sit between. The SPREAD between these numbers is what gives a
## block a top and a bottom; flattening them back toward each other returns the sticker look.
const LIT_RIM: float = 0.14      ## the dimmer highlight a VERTICAL face catches from the same key light
const LIT_LIP: float = 0.30      ## warm highlight alpha on the very edge of a sky-facing face
const AO_TOP: float = 0.07       ## whisper of dark under that lip, just enough to give it thickness
const AO_SIDE: float = 0.26      ## walls — the mid tone
const AO_UNDER: float = 0.46     ## overhangs/ceilings — nothing in the world is darker

## Draw the solid cells in `rect`, then the concave fillets + the surface cap/ramp pass for its columns.
static func paint(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	# #S15: only the surface band survives the fine layer, so the rest is skipped — but ROW BY ROW, in the
	# original order. A cell's chamfers bleed past its own rect and composite against whatever was drawn
	# before them, so the visit order is part of the picture: walking the columns instead moved 75 pixels of
	# the frame where restricting the rows moved none. The saving is in the cells skipped, not the order.
	# `surface_row` SCANS a column from the sky down, so it is hoisted out of the inner loop — eight calls
	# per chunk rather than sixty-four.
	var band: PackedInt32Array = PackedInt32Array()
	band.resize(rect.size.x)
	for i: int in rect.size.x:
		band[i] = FineTerrain.walked_surface(r.sim.surface_row(rect.position.x + i))
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			# One row either side of the walked line, so the cap's chamfers still have a neighbour to sit on.
			if absi(cy - band[cx - rect.position.x]) > 1:
				continue
			var c := Vector2i(cx, cy)
			if not r.sim.solid.has(c):
				continue
			_draw_terrain_cell(r, ci, c)
	_draw_inner_fillets(r, ci, rect)   # concave junctions rounded into the open cells (autotile #9)
	_draw_terrain_surface(r, ci, rect)


## The concave half of the autotile: wherever an OPEN cell's corner meets two solid
## orthogonal faces (a floor meeting a wall, a ceiling meeting a pillar), a quarter-round shoulder of
## the supporting rock's own colour fills that corner — carved junctions read as worn rock, not Lego
## seams. Bottom corners take the FLOOR cell's colour, top corners the CEILING's. Runs per chunk after
## the cells; the surface cap/ramp pass paints after (over) it, so the walked line stays authoritative.
static func _draw_inner_fillets(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	const R: float = 7.0
	var s: float = float(WorldRenderer.CELL)
	# Per corner: offsets of the two solid supports, the corner point in the open cell's box, the fan's
	# start angle (degrees), and which support paints it (its own body colour).
	var corners: Array = [
		{"a": Vector2i(0, -1), "b": Vector2i(-1, 0), "pt": Vector2(0.0, 0.0), "deg": 0.0, "src": Vector2i(0, -1)},
		{"a": Vector2i(0, -1), "b": Vector2i(1, 0), "pt": Vector2(s, 0.0), "deg": 90.0, "src": Vector2i(0, -1)},
		{"a": Vector2i(0, 1), "b": Vector2i(1, 0), "pt": Vector2(s, s), "deg": 180.0, "src": Vector2i(0, 1)},
		{"a": Vector2i(0, 1), "b": Vector2i(-1, 0), "pt": Vector2(0.0, s), "deg": 270.0, "src": Vector2i(0, 1)},
	]
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var c := Vector2i(cx, cy)
			# #S15: an open cell with a wall behind it is painted by the fine layer, so its fillet would
			# never be seen. Only open AIR — a hillside, the sky side of an arch — still shows one.
			if r.sim.wall.has(c):
				continue
			if r.sim.solid.has(c) or not r.sim.in_bounds(c):
				continue
			var pos := Vector2(c) * s
			for k: Dictionary in corners:
				if not r.sim.is_solid(c + (k["a"] as Vector2i)) or not r.sim.is_solid(c + (k["b"] as Vector2i)):
					continue
				var src: Vector2i = c + (k["src"] as Vector2i)
				var col: Color = r._cell_fill_color(src, r._material(r.sim.material_at(src)))
				var corner: Vector2 = pos + (k["pt"] as Vector2)
				var fan := PackedVector2Array([corner])
				for i: int in 4:
					var a: float = deg_to_rad(float(k["deg"]) + 90.0 * float(i) / 3.0)
					fan.append(corner + Vector2(cos(a), sin(a)) * R)
				ci.draw_colored_polygon(fan, col)


## One solid terrain cell: fill, grain, ore nuggets, and carved-edge AO. Split out of the cell loop so the
## chunked painter can draw just its block's cells (was `for cell in sim.solid` over the whole world).
static func _draw_terrain_cell(r: WorldRenderer, ci: CanvasItem, c: Vector2i) -> void:
		var pos := Vector2(c) * float(WorldRenderer.CELL)
		var def: MaterialDef = r._material(r.sim.solid[c])
		# Sprite-ready: if a tile PNG exists for this material, draw it and skip the procedural fill
		# (still draw the surface cap/ramp pass below).
		var tile: Texture2D = Art.tex("tile_" + String(def.id))
		if tile != null:
			ci.draw_texture_rect(tile, Rect2(pos, Vector2(WorldRenderer.CELL, WorldRenderer.CELL)), false)
			return
		var col: Color = r._cell_fill_color(c, def)
		_draw_cell_silhouette(r, ci, c, pos, col)
		if def.grain:
			# Rock grain — a darker pit + a lighter clod + a mid chip, deterministic per cell, so the
			# surface reads as textured rock rather than a colour swatch.
			var sp: Array[Vector2] = r._cell_speckles(c, 3)
			ci.draw_rect(Rect2(pos + sp[0] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.darkened(0.26))
			ci.draw_rect(Rect2(pos + sp[1] - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col.lightened(0.12))
			ci.draw_rect(Rect2(pos + sp[2] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col.darkened(0.14))
			_draw_fissure(ci, c, pos, col)
		if def.has_nuggets():  # embedded specks so a vein reads as ore IN rock, not an orange block
			# Speck DENSITY tracks the remaining deposit: a rich body sparkles thickly, a
			# nearly-drained one thins to a fleck — so a chunk's "set amount" READS, and a drill eating it
			# bottom-up visibly fades. (Cells with no pool entry = amount 1 = today's sparse look.)
			# BLIND-PLAYTEST FIX: a vein must read as MINERAL-IN-ROCK, not warm blobs. The instrument kept
			# calling round warm flecks "embers/coals" (fire) — so the specks are now ANGULAR, dark-SOCKETED
			# CRYSTALS (a rough faceted chip seated in a rock socket, a lit upper facet), the Terraria/Minecraft
			# ore language. Kept below the glow HDR threshold so daylight ore does NOT bloom like an ember;
			# the crystals glow only via the dark-gated seam pass underground.
			var richness: int = int(r.sim.deposits.get(c, 1))
			var nug_n: int = clampi(def.nugget_count + richness - 1, maxi(def.nugget_count, 4), def.nugget_count + 6)
			var socket: Color = def.nugget_color.darkened(0.55)     # dark rock socket seats the crystal
			var facet: Color = def.nugget_color.lightened(0.22)     # a hard mineral facet catching light (dim — no bloom)
			for nug: Vector2 in r._cell_speckles(c, nug_n):
				var p: Vector2 = pos + nug
				const R: float = 3.2
				# An IRREGULAR faceted chip (asymmetric quad = rough crystal, not a soft gem/blob).
				var v0: Vector2 = p + Vector2(0.0, -R)
				var v1: Vector2 = p + Vector2(R * 0.72, -R * 0.12)
				var v2: Vector2 = p + Vector2(R * 0.16, R)
				var v3: Vector2 = p + Vector2(-R * 0.72, R * 0.12)
				var off := Vector2(0.6, 0.8)                         # socket offset (light from upper-left)
				ci.draw_colored_polygon(PackedVector2Array([v0 + off, v1 + off, v2 + off, v3 + off]), socket)
				ci.draw_colored_polygon(PackedVector2Array([v0, v1, v2, v3]), def.nugget_color)
				ci.draw_colored_polygon(PackedVector2Array([v0, v1, p]), facet)  # upper-right face catches light
		_draw_edge_ao(r, ci, c, pos)  # carved depth: ambient occlusion on faces that border open air


## The cell's body FILL, autotiled: instead of a flat square, the silhouette CHAMFERS
## every convex corner — a 45° cut wherever two adjacent faces are both open — so free edges read as
## weathered earth, a lone block reads as a boulder, and cave mouths lose the Lego. The 45° echoes the
## ramp language (one diagonal vocabulary everywhere). The cut is skipped on the top corners of the
## column's walkable surface cell: the cap/ramp pass owns that edge, and the seen line must stay
## exactly the walked line. Sprite tiles (tile_<id>.png) bypass this — art brings its own edges.
static func _draw_cell_silhouette(r: WorldRenderer, ci: CanvasItem, c: Vector2i, pos: Vector2, col: Color) -> void:
	const R: float = 7.0
	var open_u: bool = not r.sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not r.sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not r.sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not r.sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = FineTerrain.walked_surface(r.sim.surface_row(c.x)) == c.y     # the walk line — the cap/ramp pass owns it
	var s: float = float(WorldRenderer.CELL)
	var pts := PackedVector2Array()
	if open_u and open_l and not keep_top:               # top-left
		pts.append(pos + Vector2(0.0, R)); pts.append(pos + Vector2(R, 0.0))
	else:
		pts.append(pos)
	if open_u and open_r and not keep_top:               # top-right
		pts.append(pos + Vector2(s - R, 0.0)); pts.append(pos + Vector2(s, R))
	else:
		pts.append(pos + Vector2(s, 0.0))
	if open_d and open_r:                                # bottom-right
		pts.append(pos + Vector2(s, s - R)); pts.append(pos + Vector2(s - R, s))
	else:
		pts.append(pos + Vector2(s, s))
	if open_d and open_l:                                # bottom-left
		pts.append(pos + Vector2(R, s)); pts.append(pos + Vector2(0.0, s - R))
	else:
		pts.append(pos + Vector2(0.0, s))
	ci.draw_colored_polygon(pts, col)


## Ambient-occlusion crevice shadow on each cell face that borders OPEN air — a few inset strips of
## fading dark, so dug tunnels and exposed dirt faces look CARVED (recessed), not like flat stickers.
## CORNER-AWARE: each strip INSETS where the silhouette chamfered that corner (no AO
## sliver floating over the 45° cut), and where a face DEAD-ENDS into an overhang (perpendicular
## neighbour solid but the diagonal past it solid too — a concave inside corner) a nested SCOOP patch
## darkens the junction end, so carved pockets read scooped from the rock, not taped together. Both
## cells at a junction patch their own face, so the scoop is symmetric with zero cross-cell drawing.
##
## MEASURED 2026-08-18, BECAUSE ALMOST NONE OF THE ABOVE REACHES A PLAYER UNDERGROUND. This pass draws on
## the COARSE layer at z=-10. `FineTerrain` draws its mold at z=-9 and writes alpha 255 over every solid
## cell (`fine_terrain.gd:822`), so the only place a coarse pixel survives is where the mold — which is
## organic and does not fill a cell to its square boundary — has eroded away from the edge. That is exactly
## the band these strips are drawn in, which is why the answer is "some" rather than "none", and why the
## coarse FILL and this TREATMENT had to be mutated separately to tell them apart.
##
## Every colour in this function forced to opaque magenta, the mold allowed to finish baking first
## (`pending_rows() == 0`, 164-203 frames of waiting), seed 1337, one standing each:
##
##                                          magenta px   open faces   px per face
##   SURFACE, at the opening, 1.00x             4057          115        35.28
##   UNDERGROUND, a carved gallery, 1.00x        247          184         1.34
##   UNDERGROUND, zoomed out two steps          1759          640         2.75
##
## NORMALISED BY OPEN FACES, and the normalisation overturned my own first reading of it. An open face is
## one side of a solid cell whose neighbour is air — exactly the unit this function draws one strip set for
## — counted by projecting each cell centre through the live canvas transform. Without it, the zoomed-out
## row reads as "more edges in frame", which is what I wrote down first and asked a peer to attack.
##
## It is not only that. Per face, the treatment survives TWICE AS WELL zoomed out (2.75 against 1.34) while
## each face covers FEWER screen pixels — a purely geometric account predicts about a quarter, so the
## measurement is roughly eight times the geometric prediction. Something non-geometric is letting the
## coarse layer through at low zoom.
##
## I PROPOSED A MECHANISM AND IT IS REFUTED BY ONE LINE. The story was that the mold's texture is stretched
## over the world rect and FILTERED, so minifying it softens the alpha edge that does the covering.
## `world_renderer.gd:402` sets `_fine_layer.texture_filter = TEXTURE_FILTER_NEAREST`. There is no softening;
## a minified texel either covers a pixel or it does not.
##
## So the effect is measured and UNEXPLAINED, and it is left that way deliberately. I wrote the filtering
## story from an intuition about what minification does, without reading the line that decides it — an hour
## after writing to a peer that every defect we found tonight was "prose written from an intention, never
## re-derived from the artefact". A plausible wrong mechanism attached to a real number is worse than a
## blank, because the next reader inherits the story and not the doubt.
##
## What survives: per open face the treatment is roughly twice as visible zoomed out as at 1.00x, against a
## geometric prediction of a quarter, on one seed and one standing per row. If that generalises, the coarse
## layer shows through more at exactly the scales a player uses to read the shape of a dig — which is worth
## explaining and is not explained here.
##
## So: REAL AT THE SURFACE at 35 pixels per face, and 1.34 pixels per face in the view the game is actually
## played in. The
## carved reading underground is not coming from here — `FineTerrain`'s own rim, rim_warm and form sink are
## what a player sees at depth. A peer measured the coarse FILL as 7398 at the surface and 0 underground on
## the same day; the two results are complementary rather than contradictory, and together they say the
## fill is fully covered while the treatment survives only in the mold's erosion.
##
## NOT DELETED, and the number is the reason: at the surface it is doing visible work, and the surface is
## the first frame anybody sees. What is retired is the BELIEF — any comment or layer rationale that credits
## this pass with the contact reading at depth is describing a pass the player cannot see there.
##
## Caveats, so the figures are not over-read: one seed, one gallery shape, one standing per row, and a pixel
## count is a statement about area rather than about noticeability.
static func _draw_edge_ao(r: WorldRenderer, ci: CanvasItem, c: Vector2i, pos: Vector2) -> void:
	const STEPS: int = 3
	const CH: float = 7.0                              # the silhouette's chamfer radius — keep in lockstep
	var open_u: bool = not r.sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not r.sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not r.sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not r.sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = FineTerrain.walked_surface(r.sim.surface_row(c.x)) == c.y   # top corners uncut there — the cap pass owns them
	var cs: float = float(WorldRenderer.CELL)
	# THE KEY LIGHT (#A1). This pass used to darken all four faces by the same amount, which is
	# ambient occlusion without a light — and occlusion alone can't make a form. Every block got an
	# even dark border and read as a sticker with a drawn outline, which is most of what "flat" and
	# "two-dimensional" meant. Light now comes from ABOVE, matching the skylight model the veil already
	# bakes (daylight floods DOWN each column), so the three exposed faces do three different jobs:
	# a sky-facing top catches a warm LIT lip, an underside falls into deep shadow, and the walls sit
	# between. Same cheap strips, same bake, but the rock finally has a top and a bottom.
	var top_lip := Color(1.0, 0.95, 0.84, LIT_LIP)
	# A side face catches a RIM, not a lip. Light from above grazes a vertical wall instead of striking
	# it, so the wall gets a thin dim highlight where it meets open air — but it must get SOMETHING. A
	# room dug into rock is read almost entirely from its silhouette, and a silhouette with lit tops and
	# unlit sides reads as a terrace seen from above, not as a chamber seen from the side (#S3).
	var side_rim := Color(1.0, 0.94, 0.86, LIT_RIM)
	for i: int in STEPS:
		var fade: float = 1.0 - float(i) / float(STEPS)
		var o: float = float(i) * 2.0
		var s := 2.0
		if open_u:
			var x0: float = CH if (open_l and not keep_top) else 0.0
			var x1: float = cs - (CH if (open_r and not keep_top) else 0.0)
			# The very edge catches the sun; below it only a whisper of dark, enough to give the lip
			# thickness without re-flattening the face we just lit.
			var col: Color = top_lip if i == 0 else Color(0.0, 0.0, 0.0, AO_TOP * fade)
			ci.draw_rect(Rect2(pos.x + x0, pos.y + o, x1 - x0, s), col)
		if open_d:
			var x0: float = CH if open_l else 0.0
			var x1: float = cs - (CH if open_r else 0.0)
			ci.draw_rect(Rect2(pos.x + x0, pos.y + cs - o - s, x1 - x0, s),
				Color(0.0, 0.0, 0.0, AO_UNDER * fade))
		if open_l:
			var y0: float = CH if (open_u and not keep_top) else 0.0
			var y1: float = cs - (CH if open_d else 0.0)
			ci.draw_rect(Rect2(pos.x + o, pos.y + y0, s, y1 - y0),
				side_rim if i == 0 else Color(0.0, 0.0, 0.0, AO_SIDE * fade))
		if open_r:
			var y0: float = CH if (open_u and not keep_top) else 0.0
			var y1: float = cs - (CH if open_d else 0.0)
			ci.draw_rect(Rect2(pos.x + cs - o - s, pos.y + y0, s, y1 - y0),
				side_rim if i == 0 else Color(0.0, 0.0, 0.0, AO_SIDE * fade))
	# The concave scoops. A face's end is concave when its continuation cell is solid (the face stops)
	# AND the diagonal past it is solid too (an overhang roofs the junction). Each scoop: two nested
	# rects hugging that end of the face, stacking extra dark onto the strips already there.
	var solid_ul: bool = r.sim.is_solid(c + Vector2i(-1, -1))
	var solid_ur: bool = r.sim.is_solid(c + Vector2i(1, -1))
	var solid_dl: bool = r.sim.is_solid(c + Vector2i(-1, 1))
	var solid_dr: bool = r.sim.is_solid(c + Vector2i(1, 1))
	if open_u:
		if not open_l and solid_ul:
			_ao_scoop(ci, pos + Vector2(0.0, 0.0), Vector2(1.0, 0.0), true)
		if not open_r and solid_ur:
			_ao_scoop(ci, pos + Vector2(cs, 0.0), Vector2(-1.0, 0.0), true)
	if open_d:
		if not open_l and solid_dl:
			_ao_scoop(ci, pos + Vector2(0.0, cs), Vector2(1.0, 0.0), false)
		if not open_r and solid_dr:
			_ao_scoop(ci, pos + Vector2(cs, cs), Vector2(-1.0, 0.0), false)
	if open_l:
		if not open_u and solid_ul:
			_ao_scoop(ci, pos + Vector2(0.0, 0.0), Vector2(0.0, 1.0), true)
		if not open_d and solid_dl:
			_ao_scoop(ci, pos + Vector2(0.0, cs), Vector2(0.0, -1.0), true)
	if open_r:
		if not open_u and solid_ur:
			_ao_scoop(ci, pos + Vector2(cs, 0.0), Vector2(0.0, 1.0), false)
		if not open_d and solid_dr:
			_ao_scoop(ci, pos + Vector2(cs, cs), Vector2(0.0, -1.0), false)


## One concave-junction scoop: nested darkening rects growing from `corner` along `along` (the face
## direction), hugging the face surface. `near_edge` = the face lies on the min side of the perpendicular
## axis (top/left faces) vs the max side (bottom/right). Alphas stack on the face strips beneath.
static func _ao_scoop(ci: CanvasItem, corner: Vector2, along: Vector2, near_edge: bool) -> void:
	const DEPTH: float = 6.0                           # matches the strip stack (3 steps x 2 px)
	for ext: float in [9.0, 5.0]:                      # two nested patches = a cheap gradient
		var run: Vector2 = along * ext
		var thick := Vector2(DEPTH, DEPTH) - along.abs() * DEPTH
		if not near_edge:
			thick = -thick
		var rc := Rect2(corner, run + thick).abs()
		ci.draw_rect(rc, Color(0.0, 0.0, 0.0, 0.14))


## Smooth the blocky surface, reading the sim's shared silhouette authority (sim.surface_row /
## sim.ramp_dir) so the diagonal we DRAW is exactly the one the avatar WALKS. The ramp GEOMETRY is
## universal (every material slopes); only the EDGE PAINT is material-specific (grass cap vs stone lip).
static func _draw_terrain_surface(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	for col: int in range(rect.position.x, rect.position.x + rect.size.x):
		if col >= FactorySim.GRID_COLS:
			break
		# THE PASS THAT DRAWS THE GRASS, and the one that put a turf cap eight hundred pixels underground.
		# `surface_row` returns the first solid cell scanning down, so on a dug column it names the rock at
		# the bottom of the player's own shaft — and this pass then caps it, chamfers it and ramps it as if
		# it were the hillside. `walked_surface` rejects any row below the band the generator can produce.
		# The existing GRID_ROWS test already meant "this column has no surface"; NO_SURFACE is the same
		# statement about a column that has ground, but not up here.
		var row: int = FineTerrain.walked_surface(r.sim.surface_row(col))
		if row == FineTerrain.NO_SURFACE or row >= FactorySim.GRID_ROWS:
			continue  # empty column, or a hole floor that is not the walked line
		# Only THIS chunk's rows own the cap. (The wedge reaches one cell up into the chunk above, which is
		# harmless — chunks aren't clipped — and that neighbour is dirtied on a dig so stale caps clear.)
		if row < rect.position.y or row >= rect.position.y + rect.size.y:
			continue
		var cell := Vector2i(col, row)
		var def: MaterialDef = r._material(r.sim.material_at(cell))
		var edge: Color = def.cap_color if def.has_cap() else def.base_color.lightened(0.18)
		var px := float(col * WorldRenderer.CELL)
		var py := float(row * WorldRenderer.CELL)
		var dir: int = r.sim.ramp_dir(col)
		if dir == 0:
			_draw_flat_cap(ci, px, py, edge, col)
			continue
		# A 45° ramp wedge over the air corner. It's the SAME earth mass as the cell below, so it fills with
		# the cell's own body colour (not flat base_color) and carries a CONCAVE scoop: a per-vertex gradient
		# lights the top cap edge and pools shadow at the inner base corner, so the slope reads as a rounded,
		# carved earth shoulder instead of a flat triangular sticker. The WALKED hypotenuse (cap edge) stays
		# exactly on the 45° line the sim authority defines — only shading is added, never the geometry.
		var body: Color = r._cell_fill_color(cell, def)
		var foot := Vector2(px, py) if dir == 1 else Vector2(px + WorldRenderer.CELL, py)         # the low (flat-side) corner
		var outer := Vector2(px + WorldRenderer.CELL, py) if dir == 1 else Vector2(px, py)        # bottom corner under the peak
		var peak := Vector2(px + WorldRenderer.CELL, py - WorldRenderer.CELL) if dir == 1 else Vector2(px, py - WorldRenderer.CELL)  # the raised cap corner
		# draw_polygon lets each vertex carry its own colour → the gradient. Cap corners lit, base pooled dark.
		var lit: Color = body.lightened(0.10)
		var pooled: Color = body.darkened(0.16)
		ci.draw_polygon(PackedVector2Array([foot, outer, peak]),
			PackedColorArray([pooled, pooled, lit]))
		# A second, tighter shadow triangle hugging the inner (base) corner deepens the concave scoop.
		var mid := (foot + outer) * 0.5
		ci.draw_polygon(PackedVector2Array([foot, mid, outer]),
			PackedColorArray([Color(0,0,0,0.14), Color(0,0,0,0.05), Color(0,0,0,0.14)]))
		# A couple of grain speckles so the wedge carries the same rock texture as the body (not a smooth face).
		# The wedge occupies the CELL-box ABOVE the cell top (py-CELL..py); speckles are placed there and kept
		# only if they fall under the diagonal (inside the triangle), so no fleck floats out over open air.
		if def.grain:
			var wedge_top := Vector2(px, py - WorldRenderer.CELL)
			for sp: Vector2 in r._cell_speckles(cell, 2):
				if _in_ramp(sp, dir):
					ci.draw_rect(Rect2(wedge_top + sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), body.darkened(0.22))
		# The cap edge (grass/lip) rides the diagonal, with a soft dark liner just under it for a carved rim.
		ci.draw_line(foot, peak, edge.darkened(0.35), 4.0)
		ci.draw_line(foot, peak, edge, 3.0)


## THE WALL FACE (#S3) — everything that makes a back-wall cell read as a rock surface a plane behind
## the play space, rather than as a hole punched in the world.
##
## Two jobs. First TEXTURE: the same grain and fracture vocabulary as the foreground rock, at reduced
## contrast, because it is the same ground seen from further away — a wall with no texture at all is
## indistinguishable from a void no matter what colour it is. Second, and far more important, the CAST:
## every edge where this cell meets solid rock takes an inward shadow from it. Under a ceiling it is
## deepest, beside a wall it is moderate, and above a floor it is light — because the world's key light
## comes from above (#A1), so a floor stays open to the sky while an overhang does not. That directional
## cast is the whole illusion: it is what a real recess does, and once it is there the eye stops reading
## a rectangle and starts reading a room.
##
## Called from WorldRenderer._draw_background, so it runs on the chunk bake (a dig), never per frame.
static func paint_wall_face(r: WorldRenderer, ci: CanvasItem, c: Vector2i, pos: Vector2, col: Color) -> void:
	var cs: float = float(WorldRenderer.CELL)
	var sp: Array[Vector2] = r._cell_speckles(c, 3)
	ci.draw_rect(Rect2(pos + sp[0] - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), col.darkened(0.16))
	ci.draw_rect(Rect2(pos + sp[1] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.lightened(0.07))
	_draw_fissure(ci, c + Vector2i(7, 3), pos, col.darkened(0.10))   # offset so it never twins the front
	# The cast. Six steps rather than the foreground's three: a recess falls off over a longer distance
	# than a chamfered edge does, and a short stack here reads as a drawn border instead of a shadow.
	const STEPS: int = 6
	for i: int in STEPS:
		var fade: float = 1.0 - float(i) / float(STEPS)
		var o: float = float(i) * 2.0
		var s := 2.0
		if r.sim.is_solid(c + Vector2i(0, -1)):
			ci.draw_rect(Rect2(pos.x, pos.y + o, cs, s),
				Color(0.0, 0.0, 0.0, WorldRenderer.WALL_AO_UNDER * fade))
		if r.sim.is_solid(c + Vector2i(0, 1)):
			ci.draw_rect(Rect2(pos.x, pos.y + cs - o - s, cs, s),
				Color(0.0, 0.0, 0.0, WorldRenderer.WALL_AO_ABOVE * fade))
		if r.sim.is_solid(c + Vector2i(-1, 0)):
			ci.draw_rect(Rect2(pos.x + o, pos.y, s, cs),
				Color(0.0, 0.0, 0.0, WorldRenderer.WALL_AO_SIDE * fade))
		if r.sim.is_solid(c + Vector2i(1, 0)):
			ci.draw_rect(Rect2(pos.x + cs - o - s, pos.y, s, cs),
				Color(0.0, 0.0, 0.0, WorldRenderer.WALL_AO_SIDE * fade))


## FISSURES — a sparse fracture running through the rock, so a MASS of solid cells has structure of its
## own. Speckles alone give a cell surface texture, but they are point noise: a wall of them is a field
## of static, which is a large part of why a solid body of rock underground read as fog rather than as
## stone. A fracture is a LINE, and a line is the one thing an eye reads as structure at a glance.
##
## Roughly one cell in five gets one, and it runs shallowly across the cell — along the bedding, since
## rock splits along its layers — with a lighter highlight under it so the crack has an edge that
## catches the same overhead key light as everything else. Deterministic per cell like the speckles, so
## the same rock always carries the same crack and a rebaked chunk is identical.
static func _draw_fissure(ci: CanvasItem, c: Vector2i, pos: Vector2, col: Color) -> void:
	var h: int = _fringe_hash(c.x * 31 + c.y, c.y)
	if h % 5 != 0:
		return
	var cs: float = float(WorldRenderer.CELL)
	var y0: float = 6.0 + float((h >> 4) % int(cs - 12.0))
	var slope: float = float((h >> 11) % 7) - 3.0                   # -3..+3 px of dip across the cell
	var x0: float = 2.0 + float((h >> 17) % 6)
	var x1: float = cs - 2.0 - float((h >> 21) % 6)
	var a := pos + Vector2(x0, y0)
	var b := pos + Vector2(x1, y0 + slope)
	ci.draw_line(a + Vector2(0.0, 1.0), b + Vector2(0.0, 1.0), col.lightened(0.16), 1.0)
	ci.draw_line(a, b, col.darkened(0.42), 1.0)


## THE FLAT CAP, RAGGED (#A5). A flat surface cell used to take one uniform 4px bar of cap colour, and a
## run of flat columns therefore drew a single ruled line the full width of the world — the loudest
## remaining piece of "blocky", and the thing that made the ground read as a cardboard cut-out laid over
## the sky. Nothing here moves the WALKED line: the sim's surface row is still exactly `py`, and the
## avatar walks it. Only the paint is broken up, in three ways that each attack a different straight
## edge:
##   * the cap's THICKNESS varies per 8px slice, so the grass/earth boundary underneath stops being a
##     rule and starts being an interface;
##   * ROOTS finger a few px further down out of some slices, so that interface interlocks rather than
##     butting;
##   * TUFTS overhang a few px into the air above the line, which is what actually kills the razor.
##     They are cosmetic overhang into a neighbouring chunk's box, which the chunk bake tolerates (the
##     fillet pass already reaches a full cell up).
## Deterministic per column — the same column always grows the same fringe, so nothing shimmers when a
## chunk rebakes after a dig.
static func _draw_flat_cap(ci: CanvasItem, px: float, py: float, edge: Color, col: int) -> void:
	const SLICES: int = 4
	var sw: float = float(WorldRenderer.CELL) / float(SLICES)
	var root: Color = edge.darkened(0.34)
	for i: int in SLICES:
		var h: int = _fringe_hash(col, i)
		var thick: float = 3.0 + float(h % 4)                     # 3..6 px of cap
		ci.draw_rect(Rect2(px + float(i) * sw, py, sw, thick), edge)
		if h % 5 == 0:                                            # a root fingering down into the earth
			var rx: float = px + float(i) * sw + float((h >> 3) % 5)
			ci.draw_rect(Rect2(rx, py + thick, 2.0, 2.0 + float((h >> 6) % 3)), root)
		if h % 3 == 0:                                            # a blade overhanging the line
			var tx: float = px + float(i) * sw + float((h >> 9) % 6)
			ci.draw_rect(Rect2(tx, py - 2.0 - float((h >> 12) % 3), 2.0, 4.0), edge)


## A stable scramble of (column, slice) — the fringe's only source of variation. Same shape as
## _cell_speckles' hash and equally RNG-free, so a rebaked chunk is byte-identical to the first bake.
static func _fringe_hash(col: int, slice: int) -> int:
	var h: int = (col * 374761393) ^ (slice * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## True when a local point (0..CELL within the wedge's upper box) falls UNDER the 45° diagonal — i.e. inside
## the filled ramp triangle. Keeps grain speckles on the earth and off the open-air side. Mirrors the two
## ramp orientations: rising-right fills where x+y ≥ CELL; rising-left where y ≥ x.
static func _in_ramp(local: Vector2, dir: int) -> bool:
	if dir == 1:
		return local.x + local.y >= float(WorldRenderer.CELL)
	return local.y >= local.x
