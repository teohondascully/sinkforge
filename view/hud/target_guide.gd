class_name TargetGuide
extends RefCounted

## THE TARGET RING (D0411, the review's rank 3: "highlight the actual reachable target briefly"). A lesson
## that says "the silver-flecked rock to your left" still asks the player to find it; this draws a breathing
## ring in the world on the thing the current rung means -- the nearest ore cell for MINE, the forge for
## SMELT, a trunk for WOOD, the crew's drill for BUILD, the coal seam for FUEL, the cache for the later rungs
## -- with the same alpha the rung's how-to has, so it arrives when the lesson does, fades when the lesson
## fades, and comes back when the player has stalled. It never highlights what is not on screen: the search
## is the observation's own window.

const TREE: Array[StringName] = [&"wood", &"leaves"]   ## a tree over its own trunk is not roof (D0478)
const RING_M: float = 0.9              ## the ring's radius, metres
const RING_WIDTH: float = 2.0          ## canvas px
const BREATH_HZ: float = 0.8
## THE TARGET IS THE ONE WHITE MARK (D0449; T032 answered). The ring was gold, and every machine's need
## bubble is a gold-amber ring on a stem: strangers 25 and 26 read "RINGED" and pressed the forge's bubble
## and the drill shaft's, 6-9 m off. The target's ink is achromatic -- white over a dark rim -- and no
## status colour is (`StatusLook`); the ring wears four compass ticks, a reticle, which no bubble does.
const INK := Color(0.98, 0.98, 0.96)
const RIM := Color(0.05, 0.04, 0.03)
const TICK_LEN: float = 5.0            ## canvas px, outside the ring at the compass points
## THE SEARCH REACHES THE SCREEN'S HALF-WIDTH AND PAYS FOR IT ACROSS FRAMES (D0431, stranger 6). Ten metres
## left the tutorial tree unringed from the drill shaft 13 m away, and the stranger went the other way over
## the chimney. A 100-cell miss is 40k visits, ten times D0414's budget; so the ring walk spends at most
## `VISITS_PER_FRAME` a frame and resumes where it stopped, keyed on the rung, the terrain and the body's
## METRE, so a walking body does not restart it every cell. The ring arrives within a few frames of a hit.
const SEARCH_CELLS: int = 100          ## twenty-five metres each way: the window's half-width at play zoom
const VISITS_PER_FRAME: int = 4000     ## about 2 ms of predicate calls, D0414's measure
## THE RING OUTLIVES THE HOW-TO (D0428, stranger 5). D0411 gave the ring the how-to's alpha, so it faded at
## nine seconds and came back at the forty-second stall -- and the fifth stranger, who had wandered for ten
## seconds, spent the thirty between pressing DROP five metres from a forge nothing was pointing at. The
## pointer that does not read is cheap: it stays for the rung's life at this floor, full while the how-to
## is up. A ring a stranger has stopped needing is one ring; a rung with no pointer is a stranger lost.
const RING_FLOOR: float = 0.38
## THE RING DOES NOT TIGHTEN (D0447 reversed D0433). D0433 shrank the ring to 0.35 m within NEAR_M so it would
## not sit on the miner's chest; eight of eight strangers who tried had mined the vein on the pad before it,
## eight of fifteen since -- every failure at the range where the ring was a nine-pixel speck. RING_NEAR_M
## is RING_M now (the lerp below is a constant); within NEAR_M the target's own metre is outlined inside the
## ring, so the ring finds the eye and the outline names the block. The chest overlap is the cheaper fault.
const RING_NEAR_M: float = 0.9       ## D0447: the ring no longer tightens; the outline names the block inside it
const NEAR_M: float = 2.2               ## from the body's CENTRE, 1.25 m over its feet: a cell beside the boot is 1.6-2 m off
const FAR_M: float = 3.5
## THE BLOCK ITSELF WHEN YOU ARE THERE (D0443, strangers 13 and 17). A 0.35 m ring at play zoom is a
## nine-pixel speck beside the miner's boot, and the thirteenth stranger, standing on the pad with the vein a
## step to the left, dug the ground under their own feet and never saw it. D0438 hung a chevron over the
## target; the seventeenth stranger pointed AT the chevron, on air, three times. Within NEAR_M the guide
## outlines the target's own metre -- the square the pointer must land on -- breathing, with a faint fill.
const NEAR_FILL: float = 0.14
## THE RING PREFERS YOUR OWN LEVEL (D0436, strangers 11 and 12). Two of three strangers on the capped world
## walked right before pointing, and the ring left the vein at the pad for the drill shaft's buried ore two
## metres under the surface: nearer by the ruler, past the reach from anywhere they could stand, and the
## how-to still said "at your feet". Each held MINE on it under TOO FAR a dozen times and never came back.
## A hit farther than a reach above or below the body's centre -- reachable only by digging, climbing or a
## fall -- ranks behind every hit in the body's own reach band, whatever the distance across.
const BAND_PX: float = float(Interface.Observation.REACH_PX)
const OUT_OF_BAND: float = 1.0e12      ## px^2 added to a hit outside the band: past any in-window distance

## THE SEARCH IS PAID ONCE PER CELL MOVED, NOT PER FRAME (D0414). The first cut scanned the full 81x81
## window through a Callable every rendered frame: 3 ms, forty per cent of the 120 Hz budget, the largest
## single HUD cost the meter found. Two fixes at cause: the cell search walks rings outward and stops once
## no farther ring can beat the best hit (a vein two metres off costs a few hundred visits, not 6561); and
## the result is cached on the rung, the body's cell and the terrain version, which are the only inputs
## the answer can move on. `scan_visits` counts predicate calls so a suite can pin the bound.
static var scan_visits: int = 0

const MISS_HOLD_CELLS: int = 4         ## a metre: how far the body walks before a fruitless scan is repeated

var objectives: Objectives
var _cache_key: Array = []
var _cache_at: Vector2 = NONE
var _miss_cell: Vector2i = Vector2i(-1000000, -1000000)
var _miss_version: int = -1
## The ring walk in flight: the next radius to visit and the best so far; `_scan_key` names what it is for.
var _scan_key: Array = []
var _scan_r: int = 0
var _scan_best: Vector2 = NONE
var _scan_best_d: float = 1.0e18


func _init(p_objectives: Objectives) -> void:
	objectives = p_objectives


## The predicate a rung searches the terrain with, or an invalid Callable when its target is a machine or
## a pile (answered at once from the observation's lists).
static func cell_predicate(id: StringName, o: Interface.Observation) -> Callable:
	match id:
		&"mine":
			return func(c: Vector2i) -> bool: return o.is_ore_like_at(c) and o.material_at(c) != &"coal"
		&"wood":
			return func(c: Vector2i) -> bool: return o.material_at(c) == &"wood"
		&"fuel":
			return func(c: Vector2i) -> bool: return o.material_at(c) == &"coal"
	return Callable()


## The world position (px) of the current rung's target, or NONE. Pure over the observation; the full
## search, for a suite. The painter walks the same rings across frames (`_cached_target`).
static func target(id: StringName, o: Interface.Observation) -> Vector2:
	var body: Vector2 = Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	var wanted: Callable = cell_predicate(id, o)
	if wanted.is_valid():
		return _nearest_cell(o, body, wanted)
	match id:
		&"smelt":
			# D0486 (strangers 70-75, 0 of 6 smelted; three never found the seam): the forge takes coal too, so
			# the ring goes to the coal seam until the pack holds coal, then to the forge -- the ring says what
			# the rung needs NEXT, one thing at a time.
			if int(Payouts.pack_counts(o).get(&"coal", 0)) == 0:
				var seam: Vector2 = _nearest_cell(o, body, func(c: Vector2i) -> bool: return o.material_at(c) == &"coal")
				if seam != NONE:
					return seam
			return _nearest_machine(o, body, &"processor")
		&"deliver":
			return _nearest_machine(o, body, &"rig")              # the crew's rig takes the ingots (D0485)
		&"build":
			# The drill in hand: the ring moves from the pile to the shaft's mouth (D0459), where [BUILD] goes.
			if int(Payouts.pack_counts(o).get(&"drill", 0)) > 0:
				return shaft_mouth(o, body)
			return _nearest_pile(o, body, &"drill")
		&"hopper":
			return _nearest_pile(o, body, &"hopper")
		&"power":
			return _nearest_pile(o, body, &"generator")
		&"winch":
			return _nearest_pile(o, body, &"winch_head")
	return NONE

const NONE := Vector2(-1.0e9, -1.0e9)
const SHAFT_ABOVE_M: int = 4              ## how far above a forge the shaft's vein and mouth are looked for


## THE SHAFT'S MOUTH (D0459): "the line" is a drill over a vein over a forge in one column, and the seeded
## shaft is the one place with a forge under ore under open air. The mouth is the open metre right above
## the topmost ore-like metre that stands over a processor within SHAFT_ABOVE_M; the nearest such mouth to
## the body by the ring's own ranking. NONE when the window holds no forge with ore over it.
static func shaft_mouth(o: Interface.Observation, body: Vector2) -> Vector2:
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") != &"processor":
			continue
		var col: int = (rec["cell"] as Vector2i).x
		var row: int = (rec["cell"] as Vector2i).y - 1
		var vein_row: int = -1
		for _step: int in SHAFT_ABOVE_M:
			var c := Vector2i(col * 4 + 2, row * 4 + 2)
			if not o.in_window(c):
				break
			if o.is_ore_like_at(c):
				vein_row = row
			elif vein_row >= 0 and not o.solid_at(c):
				break
			row -= 1
		if vein_row < 0:
			continue
		var mouth := Vector2i(col * 4 + 2, (vein_row - 1) * 4 + 2)
		if not o.in_window(mouth) or o.solid_at(mouth):
			continue
		var at: Vector2 = (Vector2(col, vein_row - 1) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		var d: float = _ranked(at, body)
		if d < best_d:
			best_d = d
			best = at
	return best


## Rings outward from the body's cell. A ring at Chebyshev radius r holds no point nearer than (r - 1)
## cells, so once a hit is held the walk stops at the ring that can no longer beat it. The full walk.
static func _nearest_cell(o: Interface.Observation, body: Vector2, wanted: Callable) -> Vector2:
	var step: Dictionary = scan(o, body, wanted, 0, NONE, 1.0e18, 0x7fffffff)
	return step["best"]


## The ring walk from radius `from_r`, spending at most `budget` predicate calls: returns the best so far,
## its squared distance, the next radius to visit, and whether the walk is done (the rings ran out, or no
## farther ring can beat the hit). Pure; the painter's state is what it hands back in.
static func scan(o: Interface.Observation, body: Vector2, wanted: Callable, from_r: int, best: Vector2, best_d: float, budget: int) -> Dictionary:
	var cell_px: float = float(o.cell_px)
	var centre := Vector2i(floori(body.x / cell_px), floori(body.y / cell_px))
	var spent: int = 0
	var r: int = from_r
	while r <= SEARCH_CELLS:
		if best != NONE and float((r - 1) * (r - 1)) * cell_px * cell_px > best_d:
			return {"best": best, "best_d": best_d, "next_r": r, "done": true}
		if spent >= budget:
			return {"best": best, "best_d": best_d, "next_r": r, "done": false}
		for c: Vector2i in _ring(centre, r):
			if not o.window.has_point(c):
				continue
			scan_visits += 1
			spent += 1
			if not bool(wanted.call(c)):
				continue
			var at: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * cell_px
			var d: float = _ranked(at, body)
			if d < best_d:
				best_d = d
				best = at
		r += 1
	return {"best": best, "best_d": best_d, "next_r": r, "done": true}


## The cells at Chebyshev radius `r` round `centre`; the centre itself at r == 0.
static func _ring(centre: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if r == 0:
		out.append(centre)
		return out
	for i: int in range(-r, r + 1):
		out.append(centre + Vector2i(i, -r))
		out.append(centre + Vector2i(i, r))
	for j: int in range(-r + 1, r):
		out.append(centre + Vector2i(-r, j))
		out.append(centre + Vector2i(r, j))
	return out


## The band rule for a machine or a pile, the same as a cell's (D0438, stranger 14: the SMELT ring chose the
## auto forge buried in the drill shaft over the surface forge eighteen metres off, and the drop fell short).
static func _ranked(at: Vector2, body: Vector2) -> float:
	var d: float = at.distance_squared_to(body)
	return d + OUT_OF_BAND if absf(at.y - body.y) > BAND_PX else d


static func _nearest_machine(o: Interface.Observation, body: Vector2, id: StringName) -> Vector2:
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") != id:   # the machine's record id; its `behavior` is a routing tag, empty for a forge
			continue
		var at: Vector2 = (Vector2(rec["cell"]) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		var d: float = _ranked(at, body)
		if d < best_d:
			best_d = d
			best = at
	return best


static func _nearest_pile(o: Interface.Observation, body: Vector2, item: StringName) -> Vector2:
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for cell: Vector2i in o.piles:
		if int((o.piles[cell] as Dictionary).get(item, 0)) <= 0:
			continue
		var at: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		var d: float = _ranked(at, body)
		if d < best_d:
			best_d = d
			best = at
	return best


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or objectives == null or objectives.all_done():
		return
	var alpha: float = ring_alpha(objectives)
	if alpha <= 0.0:
		return
	var at: Vector2 = _cached_target(objectives.current_id(), frame.obs)
	if at == NONE:
		return
	var canvas: Vector2 = frame.canvas_of(at)
	if not Rect2(Vector2.ZERO, UiTheme.CANVAS).has_point(canvas):
		return
	var breath: float = 0.55 + 0.45 * sin(frame.anim_time * TAU * BREATH_HZ)
	var body: Vector2 = Vector2(float(frame.obs.pos_x), float(frame.obs.pos_y)) / float(Fx.SCALE)
	var r: float = ring_m(body.distance_to(at) / float(Interface.Observation.LOGIC_PX)) * float(o_px_per_m(frame)) * (0.92 + 0.08 * breath)
	var ink: float = alpha * (0.55 + 0.4 * breath)
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(RIM, alpha * 0.6), RING_WIDTH + 2.0, true)
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(INK, ink), RING_WIDTH, true)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(canvas + d * (r + 2.0), canvas + d * (r + 2.0 + TICK_LEN), Color(RIM, alpha * 0.6), RING_WIDTH + 2.0, true)
		ci.draw_line(canvas + d * (r + 2.0), canvas + d * (r + 2.0 + TICK_LEN), Color(INK, ink), RING_WIDTH, true)
	if near(body.distance_to(at) / float(Interface.Observation.LOGIC_PX)):
		_outline(frame, ci, target_metre(at), alpha, ink, breath)
	var cut: Rect2 = cut_metre(frame.obs, at)
	if cut.size != Vector2.ZERO:
		_outline(frame, ci, cut, alpha, ink, breath)


## The target's metre, or the metre to cut, drawn as the one white square with its rim.
func _outline(frame: Frame, ci: CanvasItem, metre: Rect2, alpha: float, ink: float, breath: float) -> void:
	var rect := Rect2(frame.canvas_of(metre.position), frame.canvas_of(metre.end) - frame.canvas_of(metre.position))
	ci.draw_rect(rect, Color(INK, alpha * NEAR_FILL * breath))
	ci.draw_rect(rect.grow(1.0), Color(RIM, alpha * 0.6), false, RING_WIDTH + 2.0)
	ci.draw_rect(rect, Color(INK, ink), false, RING_WIDTH)


## THE CUT MARK (T038's second answer, D0458): a target under the ground -- the crew's drill three metres
## down in the roofed adit, the cache under the spawn -- gets a second white square on the topmost solid
## metre straight above it, the one to dig at. Strangers 31 and 32 reached BUILD and dug elsewhere; the ring
## from three metres up cannot say "here". Empty when the target is not buried (a solid metre must stand
## over it) or the column's top is out of the window.
static func cut_metre(o: Interface.Observation, at: Vector2) -> Rect2:
	var m: float = float(Interface.Observation.LOGIC_PX)
	var col: int = int(floorf(at.x / m))
	var row: int = int(floorf(at.y / m)) - 1
	var top: int = -1                                                       # the topmost solid metre of the roof over the target
	for _step: int in 64:
		if not o.in_window(Vector2i(col * 4 + 2, row * 4 + 2)):
			return Rect2()
		if _metre_has_rock(o, col, row):
			top = row
		elif top >= 0:
			break                                                           # open air over a roof: the roof's top is the cut
		row -= 1
	if top < 0:
		return Rect2()
	var rim: float = m / 4.0                                                # one cell either side (D0468)
	return Rect2(Vector2(float(col) * m - rim, float(top) * m), Vector2(m + 2.0 * rim, m))


## A metre is roof while ANY of its cells stands (D0467): the first bite takes the centre and the mark
## used to vanish with it, the body still on the rim; the mark stays until the hole is clear. The hole
## is the metre AND one cell either side (D0468): a body a metre wide rests its edges on whichever
## neighbour column it overlaps, so four cells never drop it and six always do. Roof is GROUND: a tree's
## own trunk and crown over a wood target are not a roof to dig through (D0478: on the wood rung the
## square floated in the sky above the leaves, strangers 62-64).
static func _metre_has_rock(o: Interface.Observation, col: int, row: int) -> bool:
	for dy: int in 4:
		for dx: int in range(-1, 5):
			var m: StringName = o.material_at(Vector2i(col * 4 + dx, row * 4 + dy))
			if m != &"" and m not in TREE:
				return true
	return false


## The metre (world px) the target cell lies in: what the pointer has to land on.
static func target_metre(at: Vector2) -> Rect2:
	var m: float = float(Interface.Observation.LOGIC_PX)
	return Rect2(Vector2(floorf(at.x / m), floorf(at.y / m)) * m, Vector2(m, m))


## Whether the target is close enough that the ring has tightened to a speck and the block's outline carries it.
static func near(dist_m: float) -> bool:
	return dist_m <= NEAR_M


## The ring's radius in metres for a target `dist_m` from the body: tight when the body has arrived, full
## from FAR_M out.
static func ring_m(dist_m: float) -> float:
	return lerpf(RING_NEAR_M, RING_M, clampf((dist_m - NEAR_M) / (FAR_M - NEAR_M), 0.0, 1.0))


## The ring's alpha: the how-to's while it is up, never below RING_FLOOR while the rung is open; nothing
## during a just-finished rung's acknowledgement (the how-to's own zero there).
static func ring_alpha(obj: Objectives) -> float:
	if obj.current_index() > 0 and obj.step_age < ObjectiveLine.ACK_HOLD:
		return 0.0
	return maxf(float(ObjectiveLine.alphas(obj.current_index(), obj.step_age, false)["hint"]), RING_FLOOR)


## The target for this rung, searched once per (rung, body cell, terrain version, pile count) and reused
## across the frames in between -- the only inputs the answer can move on.
func _cached_target(id: StringName, o: Interface.Observation) -> Vector2:
	var wanted: Callable = cell_predicate(id, o)
	if wanted.is_valid():
		return _scanned_target(id, o, wanted)
	var key: Array = [id, o.cell, o.terrain_version, o.piles.size(), o.machines.size()]
	if key == _cache_key:
		return _cache_at
	_cache_key = key
	_cache_at = target(id, o)
	return _cache_at


## A terrain search paid across frames: keyed on the rung, the terrain and the body's METRE, it walks
## `VISITS_PER_FRAME` predicate calls a frame from where it stopped and answers with the best so far. A
## finished miss holds until the body has walked MISS_HOLD_CELLS or dug, as before.
func _scanned_target(id: StringName, o: Interface.Observation, wanted: Callable) -> Vector2:
	var metre := Vector2i(floori(float(o.cell.x) / 4.0), floori(float(o.cell.y) / 4.0))
	var key: Array = [id, metre, o.terrain_version]
	if key != _scan_key:
		var same_rung: bool = not _scan_key.is_empty() and _scan_key[0] == id
		if same_rung and _scan_best == NONE and _scan_r > SEARCH_CELLS and o.terrain_version == _miss_version and o.cell.distance_squared_to(_miss_cell) < MISS_HOLD_CELLS * MISS_HOLD_CELLS:
			return NONE
		_scan_key = key
		_scan_r = 0
		_scan_best = NONE
		_scan_best_d = 1.0e18
	if _scan_r <= SEARCH_CELLS:
		var body: Vector2 = Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
		var step: Dictionary = scan(o, body, wanted, _scan_r, _scan_best, _scan_best_d, VISITS_PER_FRAME)
		_scan_best = step["best"]
		_scan_best_d = step["best_d"]
		_scan_r = SEARCH_CELLS + 1 if bool(step["done"]) else int(step["next_r"])
		if bool(step["done"]) and _scan_best == NONE:
			_miss_cell = o.cell
			_miss_version = o.terrain_version
	return _scan_best


## Canvas px a metre at this frame's zoom, off the view rect.
static func o_px_per_m(frame: Frame) -> float:
	var r: Rect2 = frame.view_world_rect
	if r.size.x <= 0.0:
		return 0.0
	return UiTheme.CANVAS.x / r.size.x * float(MaterialLook.CELLS_PER_METRE * Interface.Observation.CELL_PX)
