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

var objectives: Objectives


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


static func _nearest_cell(o: Interface.Observation, body: Vector2, wanted: Callable) -> Vector2:
	var cell_px: float = float(o.cell_px)
	var centre := Vector2i(floori(body.x / cell_px), floori(body.y / cell_px))
	var best: Vector2 = NONE
	var best_d: float = 1.0e18
	for dy: int in range(-SEARCH_CELLS, SEARCH_CELLS + 1):
		for dx: int in range(-SEARCH_CELLS, SEARCH_CELLS + 1):
			var c: Vector2i = centre + Vector2i(dx, dy)
			if not o.window.has_point(c) or not bool(wanted.call(c)):
				continue
			var at: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * cell_px
			var d: float = at.distance_squared_to(body)
			if d < best_d:
				best_d = d
				best = at
	return best


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
	var at: Vector2 = target(objectives.current_id(), frame.obs)
	if at == NONE:
		return
	var canvas: Vector2 = frame.canvas_of(at)
	if not Rect2(Vector2.ZERO, UiTheme.CANVAS).has_point(canvas):
		return
	var breath: float = 0.55 + 0.45 * sin(frame.anim_time * TAU * BREATH_HZ)
	var r: float = RING_M * float(o_px_per_m(frame)) * (0.92 + 0.08 * breath)
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(INK, alpha * (0.45 + 0.4 * breath)), RING_WIDTH, true)
	ci.draw_arc(canvas, r * 0.55, 0.0, TAU, 24, Color(INK, alpha * 0.25 * breath), 1.0, true)


## Canvas px a metre at this frame's zoom, off the view rect.
static func o_px_per_m(frame: Frame) -> float:
	var r: Rect2 = frame.view_world_rect
	if r.size.x <= 0.0:
		return 0.0
	return UiTheme.CANVAS.x / r.size.x * float(MaterialLook.CELLS_PER_METRE * Interface.Observation.CELL_PX)
