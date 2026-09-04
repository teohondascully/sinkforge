class_name GlintPainter
extends RefCounted

## THE DISCOVERY TWINKLE. Ported from `legacy/scenes/world_renderer.gd:1295-1330 _draw_glint_flares`.
## `docs/LEGACY_GAP.md` Lane A / Lane T. `docs/DECISIONS_LEDGER.md` D0300.
##
## Legacy is careful to say this is NOT the lode (`view/visuals/wall_painter.gd`, D0299): "The lode in the
## wall... has to hold up to being looked at for a long time. This is not the glint, which is a rare
## twinkle that says something is over there and still fires on top of this." One is a face you work, the
## other is a moment that catches your eye. They coexist deliberately.
##
## **ONLY EXPOSED ORE GLINTS**, in legacy's own words: "a fleck catches the light at a dug face, not
## buried in solid rock. Ore twinkling everywhere, including cells sealed inside stone, reads as a
## floating starfield; gating to exposed faces clusters the sparkle onto the vein that has been dug into."
## So the cell must be solid AND have at least one open neighbour — a face, not an interior.
##
## **`glitters` IS A SEPARATE PREDICATE FROM `nugget_color`, AND COAL IS WHY.** `data/materials/coal.yaml`
## sets `glitters: false` and its comment carries legacy's reason verbatim: glittering coal was being
## mistaken for a gem. Coal has nuggets and does not glint, so both fields are read and neither stands in
## for the other.
##
## WHAT DID NOT COME OVER, AND THE ONE THING THAT CHANGED SHAPE.
##
##   * **`glint_dark`.** Legacy scales the flare by how dark the veil has made the cell, so a vein in
##     daylight stays quiet and a vein in the deep flares at full strength — "a lit surface vein reads as
##     rock, not a sparkle". There is no veil yet (T1 #2), so the quantity it reads does not exist. Depth
##     is what skylight was a proxy for, so the gate is denominated in METRES here and stated as such,
##     rather than silently dropped — dropping it would make the surface twinkle, which is the one
##     outcome legacy names as wrong.
##   * **The per-cycle fleck choice.** Legacy scatters `nugget_count` flecks inside one 32px cell and
##     flares a different one each cycle. At 4px a whole CELL is one mark (D0189, D0299), so there is
##     exactly one fleck to choose from and the cycle index has nothing to select between. The variety
##     legacy got within a cell is carried here by the per-cell hash phase across cells instead.
##
##   * **The colour.** Legacy's own header says the glint arrives at rgb 255,255,~237 — "the brightest
##     mineral mark in the game therefore says bright rather than ore" — and that every repair for it
##     "changes how loud and what colour a deliberate discovery cue is, so it is a look decision rather
##     than a tuning one." That is LEGACY'S open question and it is not this port's to answer. The
##     `lightened(0.65)` is carried over unchanged and the question travels with it.
##
## **`is_speck` IS NOT PART OF THIS PREDICATE, AND ADDING IT WAS THE FIRST VERSION'S BUG.** It seemed to
## follow from D0299 — if a cell is the mark, surely only a marked cell glints — and it is a
## misreading of what the two mechanisms are for. `is_speck` decides how ore is COLOURED: ~10% of a vein's
## cells take the mineral hue so a patch reads as flecked rock rather than as painted metal. Legacy's
## glint asks a different question, and its predicate is exactly `has_nuggets() and glitters` plus
## exposure — the speckle field is used only to pick a POSITION inside the cell, never to decide whether
## the cell may flare at all. Intersecting the two multiplied the population by the mark density: measured
## on the real `reveal_test_dense` world, **1,183 exposed ore faces became 81**, and at a 14.7% duty that
## is ~12 flaring cells in a thousand-row world. The tests all passed. The capture is what showed it —
## three of four moments diffed at exactly ZERO pixels against the commit before the painter existed.

## Legacy's own two time constants, in seconds. Neither is a pixel count, so both transfer unchanged.
const PERIOD: float = 3.4       ## how long between one cell's flares
const FLARE_LEN: float = 0.5    ## how long a flare lasts, inside that period

## Legacy's flare geometry is in ITS pixels, where one cell is 32px = 1 m. This world draws 16px to the
## metre (`MaterialLook.CELLS_PER_METRE` x `Interface.TERRAIN_CELL_PX`), so legacy's absolute pixel sizes
## come over at half — the director's WG-4 ruling for legacy absolute pixels. Held in METRES rather than
## pixels so WG-4's own re-denomination cannot silently rescale the star.
const STAR_MIN_M: float = 2.0 / 32.0
const STAR_GROW_M: float = 2.5 / 32.0
const STAR_WIDTH_M: float = 1.2 / 32.0
const CORE_MIN_M: float = 1.1 / 32.0
const CORE_GROW_M: float = 0.8 / 32.0

## The depth gate that stands in for legacy's `glint_dark`. Legacy fades the flare out as skylight rises
## and kills it below 0.05 of full darkness; skylight in that world reaches roughly 12 m down. Ramped
## rather than switched, for the same reason legacy ramps it: a hard on/off at one row draws a horizontal
## line across the world where none exists.
const GLINT_FULL_M: float = 12.0   ## at and below this depth, flares are at full strength
const GLINT_NONE_M: float = 2.0    ## above this, no flare at all -- the surface does not twinkle

## The four neighbours a face is exposed to. Named as data for the same reason `WallPainter.PROBES` is:
## "which directions count as exposed" is then something a test can read rather than infer.
const FACES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


## How strongly a cell at `row` flares, 0..1 — legacy's `glint_dark`, re-read off depth. Returned as a
## number rather than folded into the draw because it is the one part of this painter carrying a
## substitution, and a substitution nobody can measure is a substitution nobody will revisit.
static func depth_gate(look: MaterialLook, row: int) -> float:
	if look == null:
		return 0.0
	var m: float = look.depth_m_exact(row)
	if m <= GLINT_NONE_M:
		return 0.0
	return clampf((m - GLINT_NONE_M) / (GLINT_FULL_M - GLINT_NONE_M), 0.0, 1.0)


## True when this cell is a face rather than an interior: solid, with at least one open neighbour.
static func is_exposed_face(obs: Interface.Observation, c: Vector2i) -> bool:
	if obs == null or not obs.solid_at(c):
		return false
	for d: Vector2i in FACES:
		if not obs.solid_at(c + d):
			return true
	return false


## `is_exposed_face` on the plane's own bytes: a solid cell with an air (0) neighbour on one of its four
## faces, where a neighbour past the plane's edge reads as air exactly as `solid_at` answers false there.
## Byte reads instead of four `material_at` lookups: the scan visits every buried ore cell to find the
## exposed ones, and there are thousands of those in a window (D0390).
static func exposed_index(materials: PackedByteArray, at: int, w: int, h: int) -> bool:
	if materials[at] == 0:
		return false
	var x: int = at % w
	var y: int = at / w
	if x == 0 or materials[at - 1] == 0:
		return true
	if x == w - 1 or materials[at + 1] == 0:
		return true
	if y == 0 or materials[at - w] == 0:
		return true
	return y == h - 1 or materials[at + w] == 0


## Whether this cell can EVER glint, ignoring time: an exposed face of a glittering, nugget-bearing
## material. Split from the time term so a test can pose the population without posing the clock — and so
## the two can fail separately, which they did twice: the first version returned true for coal, and the
## second was intersected with `is_speck` and returned true for 81 cells in a world with 1,183 faces.
static func can_glint(look: MaterialLook, obs: Interface.Observation, c: Vector2i) -> bool:
	if look == null or obs == null:
		return false
	var material: StringName = obs.material_at(c)
	if material == &"":
		return false
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if not rec.has("nugget_color") or not bool(rec.get("glitters", false)):
		return false
	return is_exposed_face(obs, c)


## Where this cell sits in its own flare cycle, 0..1, peaking at 1 mid-flare and 0 the rest of the period.
## Legacy's hash and phase offset, unchanged — `(x * 73856093) ^ (y * 19349663)`, masked, `% 997`.
static func flare_at(c: Vector2i, anim_time: float) -> float:
	var h: int = ((c.x * 73856093) ^ (c.y * 19349663)) & 0x7fffffff
	var offset: float = float(h % 997) / 997.0 * PERIOD
	var t: float = fposmod(anim_time + offset, PERIOD)
	if t > FLARE_LEN:
		return 0.0
	return sin(t / FLARE_LEN * PI)   ## 0 -> 1 -> 0 across the flare window


## The flare's alpha for one cell at one instant: the cycle term times the depth gate, times legacy's
## 0.85. Returned as a number for the reason this repo keeps rediscovering — Godot exposes no way to read
## back a `CanvasItem`'s draw commands, so a painter tested only by being called asserts nothing beyond
## "it did not crash", which is exactly what a broken early return does.
static func alpha_at(look: MaterialLook, obs: Interface.Observation, c: Vector2i,
		anim_time: float) -> float:
	if not can_glint(look, obs, c):
		return 0.0
	return 0.85 * flare_at(c, anim_time) * depth_gate(look, c.y)


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var obs: Interface.Observation = frame.obs
	var cell_px: int = obs.cell_px
	var metre_px: float = float(cell_px * MaterialLook.CELLS_PER_METRE)
	var r: Rect2i = TerrainPainter.visit_rect(obs, frame.view_world_rect, cell_px)
	for col: int in range(r.position.x, r.end.x):
		for row: int in range(r.position.y, r.end.y):
			var c := Vector2i(col, row)
			var a: float = alpha_at(frame.look, obs, c, frame.anim_time)
			if a <= 0.0:
				continue
			_star(ci, Vector2(c) * float(cell_px) + Vector2.ONE * (float(cell_px) * 0.5),
				flare_at(c, frame.anim_time), metre_px,
				frame.look.speck_color(obs.material_at(c), col, row), a)


## One four-point star: two crossed lines and a brighter core. Legacy's shape exactly — "a small 4-point
## star, not a lens flare" — with its `lightened(0.65)`, which is the part legacy itself flags as a look
## question rather than a tuning one.
static func _star(ci: CanvasItem, p: Vector2, flare: float, metre_px: float, nugget: Color,
		alpha: float) -> void:
	var r: float = (STAR_MIN_M + STAR_GROW_M * flare) * metre_px
	var w: float = maxf(STAR_WIDTH_M * metre_px, 1.0)   ## a sub-pixel line does not draw at all
	var col: Color = nugget.lightened(0.65)
	col.a = alpha
	ci.draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, w)
	ci.draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, w)
	ci.draw_circle(p, (CORE_MIN_M + CORE_GROW_M * flare) * metre_px,
		Color(col, minf(1.0, alpha + 0.15)))


## --- THE SPARSE CACHE (D0337) ----------------------------------------------------------------------
##
## **`paint` ABOVE ASKS EVERY VISIBLE CELL WHETHER IT COULD GLINT, EVERY FRAME.** `can_glint` is a
## `MaterialsRecords` dictionary lookup plus four `solid_at` neighbour probes, so at the 40-metre framing
## that is roughly **70,000 dictionary lookups a frame over a 160x88 rect** — measured by
## `view/draw_cost.gd` at **11.83 ms against a 120 Hz budget of 8.33** (D0336), and the largest remaining
## painter once the veil became a lightmap.
##
## Legacy never had this problem because its per-frame passes iterate SPARSE sim collections and cull each
## entry, never cells. `legacy/scenes/world_renderer.gd:756` states the rule for its whole `_draw`:
##
##   > "This per-frame pass draws only the live and sparse content (machines, items, conduits, cursor),
##   > with no full-world cell loop."
##
## This build's `view/` cannot reach a sparse ore list — `Interface.Observation` exposes a window, not the
## world's deposits — so the sparse list is DERIVED once and cached, which is legacy's own second pattern
## for exactly this (`_leaf_cells` / `_leaf_cache_dirty`, rebuilt only when terrain changes rather than
## scanning all of `sim.solid` per frame for canopy cells).
##
## **KEYED ON THE MATERIALS HASH, like `VeilPainter.field_for` and for the same reasons.** A dug-cell count
## is equal across a dig that removed one cell and added another; a tick number rebuilds every frame,
## which is the thing being fixed. Which cells CAN glint is a pure function of (window, solidity), and
## those two are exactly what the key holds. The time term is deliberately NOT cached: the flare cycle
## moves every frame and is three cheap arithmetic ops, so caching it would freeze the animation.
var _cells: Array[Vector2i] = []
var _cached_key: Array = []
var _has_cache: bool = false


## The cells in this observation's window that can ever glint, from the cache when nothing that feeds it
## has changed. KEYED ON THE WINDOW AND THE TERRAIN VERSION, not a hash of the plane: hashing ~80K bytes
## a frame was 0.5 ms of every frame, and the miss path visited every cell through `material_at` and a
## record lookup -- 25-33 ms on every camera move (D0390). A miss now asks the plane, natively, where each
## glittering ordinal occurs (`PackedByteArray.find`), and visits only those. A posed observation that
## changes its plane without bumping `terrain_version` is posing a state the door never produces.
func glint_cells(look: MaterialLook, obs: Interface.Observation) -> Array[Vector2i]:
	var key: Array = [obs.window, obs.terrain_version]
	if _has_cache and _cached_key == key:
		return _cells
	var found: Array[Vector2i] = []
	var w: Rect2i = obs.window
	if look != null and w.size.x > 0:
		for g: int in glittering_ordinals(obs.legend):
			var at: int = obs.materials.find(g)
			while at >= 0:
				if exposed_index(obs.materials, at, w.size.x, w.size.y):
					found.append(Vector2i(w.position.x + at % w.size.x, w.position.y + at / w.size.x))
				at = obs.materials.find(g, at + 1)
	found.sort()   # column-major, the order the per-cell scan produced
	_cells = found
	_cached_key = key
	_has_cache = true
	return _cells


## The legend indices of every material that can glint: has a nugget colour and glitters.
static func glittering_ordinals(legend: PackedStringArray) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in legend.size():
		if legend[i] == "":
			continue
		var rec: Dictionary = MaterialsRecords.RECORDS.get(legend[i], {})
		if rec.has("nugget_color") and bool(rec.get("glitters", false)):
			out.append(i)
	return out


## The cached path. Identical picture to `paint` above, which is KEPT as the per-cell reference the way
## `VeilPainter._paint_with` is: `tests/test_glint_painter.gd` asserts the two draw the same set.
##
## Iterates the cached cells rather than the visible rect, so per-frame cost is O(glinting cells) — a
## handful of exposed ore faces — instead of O(visible cells). No view cull is applied to the list because
## the window IS the visible rect plus `WorldView.WINDOW_MARGIN_CELLS`, so every cached cell is already at
## most a margin off-screen, and a star drawn there is clipped by the viewport for free.
func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var obs: Interface.Observation = frame.obs
	var cell_px: int = obs.cell_px
	var metre_px: float = float(cell_px * MaterialLook.CELLS_PER_METRE)
	for c: Vector2i in glint_cells(frame.look, obs):
		var a: float = 0.85 * flare_at(c, frame.anim_time) * depth_gate(frame.look, c.y)
		if a <= 0.0:
			continue
		_star(ci, Vector2(c) * float(cell_px) + Vector2.ONE * (float(cell_px) * 0.5),
			flare_at(c, frame.anim_time), metre_px,
			frame.look.speck_color(obs.material_at(c), c.x, c.y), a)
