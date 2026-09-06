class_name TargetGuide
extends RefCounted

## THE TARGET RING (D0411, the review's rank 3: "highlight the actual reachable target briefly"). A lesson
## that says "the silver-flecked rock to your left" still asks the player to find it; this draws a breathing
## ring in the world on the thing the current rung means -- the nearest ore cell for MINE, the forge for
## SMELT, a trunk for WOOD, the crew's drill for BUILD, the coal seam for FUEL, the cache for the later rungs
## -- with the same alpha the rung's how-to has, so it arrives when the lesson does, fades when the lesson
## fades, and comes back when the player has stalled. It never highlights what is not on screen: the search
## is the observation's own window.

const RING_M: float = 0.9              ## the ring's radius, metres
const RING_WIDTH: float = 2.0          ## canvas px
const BREATH_HZ: float = 0.8
const INK := Color(0.97, 0.87, 0.55)
const SEARCH_CELLS: int = 40           ## ten metres each way, in terrain cells

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


func _init(p_objectives: Objectives) -> void:
	objectives = p_objectives


## The world position (px) of the current rung's target, or NONE. Pure over the observation.
static func target(id: StringName, o: Interface.Observation) -> Vector2:
	var body: Vector2 = Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	match id:
		&"mine":
			return _nearest_cell(o, body, func(c: Vector2i) -> bool: return o.is_ore_like_at(c) and o.material_at(c) != &"coal")
		&"smelt":
			return _nearest_machine(o, body, &"processor")
		&"wood":
			return _nearest_cell(o, body, func(c: Vector2i) -> bool: return o.material_at(c) == &"wood")
		&"build":
			return _nearest_pile(o, body, &"drill")
		&"fuel":
			return _nearest_cell(o, body, func(c: Vector2i) -> bool: return o.material_at(c) == &"coal")
		&"hopper":
			return _nearest_pile(o, body, &"hopper")
		&"power":
			return _nearest_pile(o, body, &"generator")
		&"winch":
			return _nearest_pile(o, body, &"winch_head")
	return NONE

const NONE := Vector2(-1.0e9, -1.0e9)


## Rings outward from the body's cell. A ring at Chebyshev radius r holds no point nearer than (r - 1)
## cells, so once a hit is held the walk stops at the ring that can no longer beat it.
static func _nearest_cell(o: Interface.Observation, body: Vector2, wanted: Callable) -> Vector2:
	var cell_px: float = float(o.cell_px)
	var centre := Vector2i(floori(body.x / cell_px), floori(body.y / cell_px))
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for r: int in range(0, SEARCH_CELLS + 1):
		if best != NONE and float((r - 1) * (r - 1)) * cell_px * cell_px > best_d:
			break
		for c: Vector2i in _ring(centre, r):
			if not o.window.has_point(c):
				continue
			scan_visits += 1
			if not bool(wanted.call(c)):
				continue
			var at: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * cell_px
			var d: float = at.distance_squared_to(body)
			if d < best_d:
				best_d = d
				best = at
	return best


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


static func _nearest_machine(o: Interface.Observation, body: Vector2, id: StringName) -> Vector2:
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") != id:   # the machine's record id; its `behavior` is a routing tag, empty for a forge
			continue
		var at: Vector2 = (Vector2(rec["cell"]) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		var d: float = at.distance_squared_to(body)
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
		var d: float = at.distance_squared_to(body)
		if d < best_d:
			best_d = d
			best = at
	return best


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or objectives == null or objectives.all_done():
		return
	var alpha: float = float(ObjectiveLine.alphas(objectives.current_index(), objectives.step_age, false)["hint"])
	if alpha <= 0.0:
		return
	var at: Vector2 = _cached_target(objectives.current_id(), frame.obs)
	if at == NONE:
		return
	var canvas: Vector2 = frame.canvas_of(at)
	if not Rect2(Vector2.ZERO, UiTheme.CANVAS).has_point(canvas):
		return
	var breath: float = 0.55 + 0.45 * sin(frame.anim_time * TAU * BREATH_HZ)
	var r: float = RING_M * float(o_px_per_m(frame)) * (0.92 + 0.08 * breath)
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(INK, alpha * (0.45 + 0.4 * breath)), RING_WIDTH, true)
	ci.draw_arc(canvas, r * 0.55, 0.0, TAU, 24, Color(INK, alpha * 0.25 * breath), 1.0, true)


## The target for this rung, searched once per (rung, body cell, terrain version, pile count) and reused
## across the frames in between -- the only inputs the answer can move on.
func _cached_target(id: StringName, o: Interface.Observation) -> Vector2:
	var key: Array = [id, o.cell, o.terrain_version, o.piles.size(), o.machines.size()]
	if key == _cache_key:
		return _cache_at
	# A miss is the expensive answer (the whole window walked for nothing) and a metre of walking cannot
	# bring a target ten metres off into reach; hold it until the body has moved that far or dug.
	var same_rung: bool = not _cache_key.is_empty() and _cache_key[0] == id
	if same_rung and _cache_at == NONE and o.terrain_version == _miss_version and o.cell.distance_squared_to(_miss_cell) < MISS_HOLD_CELLS * MISS_HOLD_CELLS:
		return NONE
	_cache_key = key
	_cache_at = target(id, o)
	if _cache_at == NONE:
		_miss_cell = o.cell
		_miss_version = o.terrain_version
	return _cache_at


## Canvas px a metre at this frame's zoom, off the view rect.
static func o_px_per_m(frame: Frame) -> float:
	var r: Rect2 = frame.view_world_rect
	if r.size.x <= 0.0:
		return 0.0
	return UiTheme.CANVAS.x / r.size.x * float(MaterialLook.CELLS_PER_METRE * Interface.Observation.CELL_PX)
