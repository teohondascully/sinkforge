extends RefCounted

## The coarse-terrain draw pipeline: per-cell fill, grain and ore crystals, the autotile silhouette
## chamfers and concave fillets, carved-edge ambient occlusion, and the walkable surface cap/ramp pass.
## Stateless. It paints onto the terrain CanvasItem the renderer hands it, reads terrain from r.sim, and
## takes each cell's appearance from the renderer's shared helpers (r._cell_fill_color / r._material /
## r._cell_speckles), which live there because walls, fine terrain and the minimap share them. Bake-time
## code: drawn once per dirty chunk into the terrain SubViewport, not per frame. Deterministic, cosmetic.

## The carved-edge pass's four face weights, kept together because they only mean anything relative to
## each other. Light comes from straight above, the direction the veil's skylight floods, so a sky-facing
## top catches a warm lit lip, an underside falls into the deepest shadow in the frame, and walls sit
## between. The spread between these numbers is what gives a block a top and a bottom.
const LIT_RIM: float = 0.14      ## the dimmer highlight a vertical face catches from the same key light
const LIT_LIP: float = 0.30      ## warm highlight alpha on the very edge of a sky-facing face
const AO_TOP: float = 0.07       ## whisper of dark under that lip, just enough to give it thickness
const AO_SIDE: float = 0.26      ## walls, the mid tone
const AO_UNDER: float = 0.46     ## overhangs and ceilings, the darkest tone in the world

## The corner radius, named once because three passes have to agree on it. `_draw_cell_silhouette` cuts
## this much off every convex corner. `_draw_edge_ao` must inset its face strips by exactly the same
## amount: an inset smaller than the cut leaves an AO sliver floating in the air over the 45 degree face,
## and an inset larger than it leaves the corner unshaded. `_draw_inner_fillets` rounds concave junctions
## to the same radius, so convex and concave corners read as one edge vocabulary.
const CHAMFER: float = 7.0

## The carved-edge strip stack on a foreground face: how many strips, and how thick each one is. The
## stack's total depth is what `_ao_scoop` has to match to sit flush against it at a concave junction, so
## the scoop derives its depth from these rather than restating the product as its own literal. (The
## back-wall cast in `paint_wall_face` runs its own deeper stack; see the note there.)
const AO_STEPS: int = 3
const AO_STRIP: float = 2.0
const AO_DEPTH: float = AO_STEPS * AO_STRIP

## Draw the solid cells in `rect`, then the concave fillets + the surface cap/ramp pass for its columns.
static func paint(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	# Only the surface band survives the fine layer, so the rest is skipped, but row by row in the original
	# order: a cell's chamfers bleed past its own rect and composite against whatever was drawn before them,
	# so visit order is part of the picture. Walking the columns instead moved 75 pixels of the frame;
	# restricting the rows moved none. `surface_row` scans a column from the sky down, so it is hoisted out
	# of the inner loop.
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
	_draw_inner_fillets(r, ci, rect)   # concave junctions rounded into the open cells
	_draw_terrain_surface(r, ci, rect)


## The concave half of the autotile: wherever an open cell's corner meets two solid orthogonal faces, a
## quarter-round shoulder of the supporting rock's colour fills that corner, so a carved junction reads
## as worn rock instead of a right-angled seam. Bottom corners take the floor cell's colour, top corners
## the ceiling's. Runs per chunk after the cells, and the surface cap/ramp pass then paints over it, so
## the walked line stays authoritative.
static func _draw_inner_fillets(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	const R: float = CHAMFER
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
			# An open cell with a wall behind it is painted by the fine layer, so its fillet would never be
			# seen. Only open air, a hillside or the sky side of an arch, still shows one.
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
## chunked painter can draw just its block's cells.
static func _draw_terrain_cell(r: WorldRenderer, ci: CanvasItem, c: Vector2i) -> void:
		var pos := Vector2(c) * float(WorldRenderer.CELL)
		var def: MaterialDef = r._material(r.sim.solid[c])
		# If a tile PNG exists for this material, draw it and skip the procedural fill. The surface
		# cap/ramp pass below still runs.
		var tile: Texture2D = Art.tex("tile_" + String(def.id))
		if tile != null:
			ci.draw_texture_rect(tile, Rect2(pos, Vector2(WorldRenderer.CELL, WorldRenderer.CELL)), false)
			return
		var col: Color = r._cell_fill_color(c, def)
		_draw_cell_silhouette(r, ci, c, pos, col)
		if def.grain:
			# Rock grain: a darker pit, a lighter clod, a mid chip, deterministic per cell, so the surface
			# reads as textured rock rather than a colour swatch.
			var sp: Array[Vector2] = r._cell_speckles(c, 3)
			ci.draw_rect(Rect2(pos + sp[0] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.darkened(0.26))
			ci.draw_rect(Rect2(pos + sp[1] - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col.lightened(0.12))
			ci.draw_rect(Rect2(pos + sp[2] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col.darkened(0.14))
			_draw_fissure(ci, c, pos, col)
		if def.has_nuggets():  # embedded specks so a vein reads as ore in rock, not an orange block
			# Speck density tracks the remaining deposit, so a drill eating a vein bottom-up visibly fades. A
			# cell with no pool entry counts as amount 1.
			# The specks are angular crystals seated in a dark socket. Round warm flecks read as embers rather
			# than as mineral. The colours stay below the glow HDR threshold so daylight ore does not bloom;
			# underground the dark-gated seam pass lights them.
			var richness: int = int(r.sim.deposits.get(c, 1))
			var nug_n: int = clampi(def.nugget_count + richness - 1, maxi(def.nugget_count, 4), def.nugget_count + 6)
			var socket: Color = def.nugget_color.darkened(0.55)     # dark rock socket seats the crystal
			var facet: Color = def.nugget_color.lightened(0.22)     # a hard mineral facet catching light, dim, no bloom
			for nug: Vector2 in r._cell_speckles(c, nug_n):
				var p: Vector2 = pos + nug
				const R: float = 3.2
				# An irregular faceted chip. A symmetric quad reads as a soft gem instead of rough crystal.
				var v0: Vector2 = p + Vector2(0.0, -R)
				var v1: Vector2 = p + Vector2(R * 0.72, -R * 0.12)
				var v2: Vector2 = p + Vector2(R * 0.16, R)
				var v3: Vector2 = p + Vector2(-R * 0.72, R * 0.12)
				var off := Vector2(0.6, 0.8)                         # socket offset (light from upper-left)
				ci.draw_colored_polygon(PackedVector2Array([v0 + off, v1 + off, v2 + off, v3 + off]), socket)
				ci.draw_colored_polygon(PackedVector2Array([v0, v1, v2, v3]), def.nugget_color)
				ci.draw_colored_polygon(PackedVector2Array([v0, v1, p]), facet)  # upper-right face catches light
		_draw_edge_ao(r, ci, c, pos)  # carved depth: ambient occlusion on faces that border open air


## The cell's body fill, autotiled: the silhouette chamfers every convex corner, a 45° cut wherever two
## adjacent faces are both open, so free edges read as weathered earth and a lone block as a boulder.
## The angle is 45° to match the ramp geometry, so the world has one diagonal vocabulary throughout. The
## cut is skipped on the top corners of the column's walkable surface cell, where the cap/ramp pass owns
## the edge and the line drawn has to be the line walked. Sprite tiles (tile_<id>.png) bypass this.
static func _draw_cell_silhouette(r: WorldRenderer, ci: CanvasItem, c: Vector2i, pos: Vector2, col: Color) -> void:
	const R: float = CHAMFER
	var open_u: bool = not r.sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not r.sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not r.sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not r.sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = FineTerrain.walked_surface(r.sim.surface_row(c.x)) == c.y     # the walked line: the cap/ramp pass owns it
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


## Ambient-occlusion crevice shadow on every cell face that borders open air: inset strips of fading dark
## so dug tunnels and exposed dirt faces read as carved rather than as flat stickers. Each strip insets
## where the silhouette chamfered that corner. Where a face dead-ends into an overhang (perpendicular
## neighbour solid and the diagonal past it solid too) a nested scoop darkens the junction end. Both cells
## at a junction patch their own face; the scoop is symmetric and neither draws outside its own box.
##
## What the pass is worth depends on depth. It draws on the coarse layer at z=-10. `FineTerrain` draws its
## mold at z=-9 and writes alpha 255 over every solid cell (`fine_terrain.gd:822`), so a coarse pixel can
## survive only where the mold has eroded back from the cell edge. The mold is organic and does not fill a
## cell to its square boundary, and that eroded band is exactly where these strips sit.
##
## Method: a frozen world (`Engine.time_scale = 0`) with the mold baked out to `pending_rows() == 0`. One
## process captures the frame with this function drawing and with it skipped, then counts every pixel that
## moves by more than one 8-bit step in any channel. Three runs, each beside a same-vs-same capture of the
## untouched scene:
##
##                              floor            drawn-vs-skipped
##   surface, at the opening    24 / 72 / 21     4427 / 4531 / 4559
##   underground, 50 rows down  15 / 38 /  9       48 /   43 /    9
##
## At the surface the pass paints roughly 4500 px: sixty to two hundred times its own noise floor. Fifty
## rows down the signal is the floor. Paired, the excess is +33 / +5 / 0 out of 2073600 px and two of the
## three runs show nothing at all, which bounds the contribution under about forty pixels or 0.002% of the
## frame. That is not separable from noise rather than zero. The pass stays for the surface work.
##
## Consequence for anyone reading this file: whatever makes rock read as carved at depth is not this
## function, despite what the paragraph above promises. It is `FineTerrain`'s rim, rim_warm and form sink.
## Caveats: one seed and one gallery shape. A pixel count states area rather than noticeability.
static func _draw_edge_ao(r: WorldRenderer, ci: CanvasItem, c: Vector2i, pos: Vector2) -> void:
	const STEPS: int = AO_STEPS
	const CH: float = CHAMFER                          # the silhouette's cut, so the strips inset off it
	var open_u: bool = not r.sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not r.sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not r.sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not r.sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = FineTerrain.walked_surface(r.sim.surface_row(c.x)) == c.y   # top corners uncut there: the cap pass owns them
	var cs: float = float(WorldRenderer.CELL)
	# The key light comes from above, matching the skylight the veil bakes down each column, so the three
	# exposed faces do three jobs: a warm lit lip on top, deep shadow underneath, walls between. Darkening
	# all four equally is occlusion without a light, and it reads as a drawn outline around every block.
	var top_lip := Color(1.0, 0.95, 0.84, LIT_LIP)
	# A side face catches a rim, not a lip: light from above grazes a vertical wall rather than striking
	# it. It still has to catch something, or a dug room reads as a terrace from above, not a chamber.
	var side_rim := Color(1.0, 0.94, 0.86, LIT_RIM)
	for i: int in STEPS:
		var fade: float = 1.0 - float(i) / float(STEPS)
		var o: float = float(i) * AO_STRIP
		var s: float = AO_STRIP
		if open_u:
			var x0: float = CH if (open_l and not keep_top) else 0.0
			var x1: float = cs - (CH if (open_r and not keep_top) else 0.0)
			# The edge catches the sun; below it a whisper of dark gives the lip its thickness.
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
	# The concave scoops. A face's end is concave when its continuation cell is solid (the face stops) and
	# the diagonal past it is solid too (an overhang roofs the junction). Two nested rects per scoop.
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
	const DEPTH: float = AO_DEPTH                      # flush with the strip stack it sits on top of
	for ext: float in [9.0, 5.0]:                      # two nested patches = a cheap gradient
		var run: Vector2 = along * ext
		var thick := Vector2(DEPTH, DEPTH) - along.abs() * DEPTH
		if not near_edge:
			thick = -thick
		var rc := Rect2(corner, run + thick).abs()
		ci.draw_rect(rc, Color(0.0, 0.0, 0.0, 0.14))


## Smooth the blocky surface from the sim's silhouette authority (sim.surface_row / sim.ramp_dir), so the
## diagonal drawn is exactly the one the avatar walks. Every material slopes, so the ramp geometry is
## universal; only the edge paint is material-specific, a grass cap versus a stone lip.
static func _draw_terrain_surface(r: WorldRenderer, ci: CanvasItem, rect: Rect2i) -> void:
	for col: int in range(rect.position.x, rect.position.x + rect.size.x):
		if col >= FactorySim.GRID_COLS:
			break
		# `surface_row` returns the first solid cell scanning down, so on a dug column it names the rock at
		# the bottom of the player's shaft, which this pass would otherwise cap and ramp like a hillside.
		# `walked_surface` rejects any row below the band the generator can produce: NO_SURFACE means the
		# column has ground but not up here, where the GRID_ROWS test means it has none at all.
		var row: int = FineTerrain.walked_surface(r.sim.surface_row(col))
		if row == FineTerrain.NO_SURFACE or row >= FactorySim.GRID_ROWS:
			continue  # empty column, or a hole floor that is not the walked line
		# Only this chunk's rows own the cap. The wedge reaches one cell up into the chunk above, which is
		# harmless (chunks are not clipped) and that neighbour is dirtied on a dig, so stale caps clear.
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
		# A 45° ramp wedge over the air corner, the same earth mass as the cell below, so it fills with the
		# cell's own body colour rather than flat base_color and carries a per-vertex gradient: cap edge lit,
		# shadow pooled at the inner base corner, so the slope reads as a rounded carved shoulder rather than
		# a flat triangle. Shading only; the hypotenuse stays on the 45° line the sim defines.
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
		# Grain speckles so the wedge carries the body's rock texture. The wedge occupies the cell box above
		# the cell top (py-CELL..py), so a speckle is kept only if it falls under the diagonal.
		if def.grain:
			var wedge_top := Vector2(px, py - WorldRenderer.CELL)
			for sp: Vector2 in r._cell_speckles(cell, 2):
				if _in_ramp(sp, dir):
					ci.draw_rect(Rect2(wedge_top + sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), body.darkened(0.22))
		# The cap edge (grass/lip) rides the diagonal, with a soft dark liner just under it for a carved rim.
		ci.draw_line(foot, peak, edge.darkened(0.35), 4.0)
		ci.draw_line(foot, peak, edge, 3.0)


## Everything that makes a back-wall cell read as a rock plane behind the play space rather than a hole
## punched in the world. Texture first: the foreground rock's grain and fracture vocabulary at reduced
## contrast, because a wall with no texture is indistinguishable from a void whatever colour it is. Then
## the cast: every edge where this cell meets solid rock takes an inward shadow, deepest under a ceiling,
## moderate beside a wall, light above a floor, because the key light comes from above and a floor stays
## open to the sky while an overhang does not. The directional cast is what makes the recess read as a
## room: it is what a real recess does to the light in it.
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


## A sparse fracture through the rock, so a mass of solid cells has structure of its own. Speckles alone
## are point noise and a wall of them reads as static; a line is what an eye reads as structure. Roughly
## one cell in five gets one, running shallowly along the bedding, with a lighter highlight under it so
## the crack catches the overhead key light. Deterministic per cell, so a rebaked chunk is identical.
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


## A flat surface cell takes a ragged cap rather than one uniform bar of cap colour, because a run of
## flat columns otherwise draws a single ruled line the full width of the world. Nothing here moves the
## walked line, which is still exactly `py`; only the paint is broken up, three ways:
##   * cap thickness varies per 8px slice, so the grass/earth boundary is an interface, not a rule;
##   * roots finger a few px further down out of some slices, so that interface interlocks;
##   * tufts overhang a few px into the air above the line, which is what kills the razor edge. They
##     overhang into the neighbouring chunk's box, which the chunk bake tolerates because chunks are
##     not clipped and the fillet pass already reaches a full cell up.
## Deterministic per column, so nothing shimmers when a chunk rebakes after a dig.
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


## A stable scramble of (column, slice), the fringe's only source of variation. Same shape as
## _cell_speckles' hash and equally RNG-free, so a rebaked chunk is byte-identical to the first bake.
static func _fringe_hash(col: int, slice: int) -> int:
	var h: int = (col * 374761393) ^ (slice * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## True when a local point (0..CELL within the wedge's upper box) falls under the 45° diagonal, inside the
## ramp triangle, which keeps grain speckles off the open-air side. Rising-right fills where x+y ≥ CELL,
## rising-left where y ≥ x.
static func _in_ramp(local: Vector2, dir: int) -> bool:
	if dir == 1:
		return local.x + local.y >= float(WorldRenderer.CELL)
	return local.y >= local.x
