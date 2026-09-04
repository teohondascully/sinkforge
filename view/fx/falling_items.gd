class_name FallingItems
extends RefCounted

## THE COSMETIC FALLING-PRODUCT LAYER (A' step 6e, D0365), the visual half of the hybrid item model: the
## sim's abstract flow is authoritative and emits write-only flow events; this turns them into discrete
## drops that fall, glow and spark on landing. Legacy `scenes/falling_items.gd` on the observation's
## CONSUMED channel: `observe` hands each tick's events over exactly once and empties them (D0356), so
## the one sim write legacy made here (`flow_events.clear()`) is gone and the layer never touches the
## sim. It holds no production math and owns its own state, tick and draw.
##
## Sizes are legacy's px at the fine-detail scale (`SCALE`, a 32 px cell became 16), drawn under one
## transform so every constant below is legacy's own number.

const FALL_DURATION: float = 0.30
const MAX_ITEMS: int = 240          ## past this a pouring column reads the same and only adds churn
## The landing ring is the widest thing a drop paints, so the cull pad is derived from it, never written.
const RING_R0: float = 4.0
const RING_GROW: float = 11.0
const RING_WIDTH: float = 2.0
const SMEAR_REACH: float = 8.0
const NUGGET_R: float = 6.0
const TRAIL_SIZE: float = 5.5
const TRAIL_SHRINK: float = 0.6
const DRAW_PAD: float = maxf(RING_R0 + RING_GROW + RING_WIDTH * 0.5, maxf(SMEAR_REACH, NUGGET_R))
const SCALE: float = float(Interface.Observation.LOGIC_PX) / 32.0
const CELL: float = float(Interface.Observation.LOGIC_PX)

var _items: Array[Dictionary] = []   ## from/to in legacy px, t (0..1), color
var _pool: Array[Dictionary] = []    ## retired drops, reused so steady-state streaming allocates nothing
var _motes_scratch: Array[Dictionary] = []
var _landed: Dictionary = {}         ## cell -> {pos, color, drop}: this frame's landings, merged by cell
var _last_time: float = 0.0


## A logic cell's centre in legacy px (world px over SCALE).
static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL / SCALE


## This frame's events into drops: `count` flights per event, jittered so a stack fans out.
func spawn_from_events(events: Array[Dictionary]) -> void:
	for ev: Dictionary in events:
		var from: Vector2 = cell_center(ev["from"])
		var to: Vector2 = cell_center(ev["to"])
		var color: Color = ItemLook.color(StringName(String(ev["item"])))
		var count: int = int(ev["count"])
		for i: int in count:
			var jitter := Vector2((float(i) - float(count - 1) * 0.5) * 4.0, 0.0)
			_spawn(from + jitter, to + jitter, color, 0.0)


## Inject a drop directly; `t` seeds its progress so a caller can stage a spread-out stream at once.
func inject(from: Vector2, to: Vector2, color: Color, t: float = 0.0) -> void:
	_spawn(from, to, color, t)


func _spawn(from: Vector2, to: Vector2, color: Color, t: float) -> void:
	if _items.size() >= MAX_ITEMS:
		return
	var f: Dictionary
	if _pool.is_empty():
		f = {"from": from, "to": to, "t": t, "color": color}
	else:
		f = _pool.pop_back()
		f["from"] = from
		f["to"] = to
		f["t"] = t
		f["color"] = color
	_items.append(f)


## Advance every drop and retire arrivals into the pool, recording each landing merged BY CELL with the
## longest fall of the group: ten puffs on one cell is a smear, and the deepest drop sizes the cue.
func advance(delta: float) -> void:
	var i: int = _items.size() - 1
	while i >= 0:
		var f: Dictionary = _items[i]
		var t: float = float(f["t"]) + delta / FALL_DURATION
		if t < 1.0:
			f["t"] = t
		else:
			var to: Vector2 = f["to"]
			var drop: float = absf(to.y - (f["from"] as Vector2).y)
			var key: Vector2i = Vector2i((to * SCALE / CELL).floor())
			if not _landed.has(key) or drop > float(_landed[key]["drop"]):
				_landed[key] = {"pos": to * SCALE, "color": f["color"], "drop": drop * SCALE}
			_items[i] = _items[_items.size() - 1]
			_items.resize(_items.size() - 1)
			_pool.append(f)
		i -= 1


## Where the drops landed since the last call (world px), and the caller consumes them: calling twice in
## a frame gets nothing the second time, so two consumers cannot both fire the same landing.
func take_landings() -> Dictionary:
	var out: Dictionary = _landed
	_landed = {}
	return out


func size() -> int:
	return _items.size()


## Current {pos (world px), color} of each drop, for a light pass. A reused scratch array, valid until
## the next call.
func motes() -> Array[Dictionary]:
	if _motes_scratch.size() > _items.size():
		_motes_scratch.resize(_items.size())
	while _motes_scratch.size() < _items.size():
		_motes_scratch.append({"pos": Vector2.ZERO, "color": Color.WHITE})
	for i: int in _items.size():
		var m: Dictionary = _motes_scratch[i]
		m["pos"] = _pos(_items[i]) * SCALE
		m["color"] = _items[i]["color"]
	return _motes_scratch


func _pos(f: Dictionary) -> Vector2:
	return sample(f["from"], f["to"], float(f["t"]))


## A point on the toss arc at progress `t`: horizontal eases out (a tossed item shoots forward early then
## settles into its column), vertical descends linearly minus a bow that grows with toss distance, so
## only sideways tosses visibly arc.
static func sample(from: Vector2, to: Vector2, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var ex: float = 1.0 - (1.0 - t) * (1.0 - t)
	return Vector2(lerpf(from.x, to.x, ex), lerpf(from.y, to.y, t) - sin(t * PI) * bow(from, to))


static func bow(from: Vector2, to: Vector2) -> float:
	return 10.0 + absf(to.x - from.x) * 0.28


## The frame: spawn this tick's events, advance on the clock, draw what the view can see.
func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	spawn_from_events(frame.obs.flow_events)
	advance(dt)
	var view := Rect2(frame.view_world_rect.position / SCALE, frame.view_world_rect.size / SCALE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	draw(ci, view)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw(canvas: CanvasItem, view: Rect2) -> void:
	for f: Dictionary in _items:
		if view.intersects(bounds(f)):
			_draw_item(canvas, f)


## About ten primitives a drop: a fading comet trail, the nugget with its motion smear, the landing ring.
func _draw_item(canvas: CanvasItem, f: Dictionary) -> void:
	var from: Vector2 = f["from"]
	var to: Vector2 = f["to"]
	var t: float = clampf(float(f["t"]), 0.0, 1.0)
	var col: Color = f["color"]
	for i: int in range(5, 0, -1):
		var pp: Vector2 = sample(from, to, clampf(t - float(i) * 0.055, 0.0, 1.0))
		var a: float = (1.0 - float(i) / 6.0) * 0.34
		var sz: float = TRAIL_SIZE - float(i) * TRAIL_SHRINK
		canvas.draw_rect(Rect2(pp - Vector2(sz, sz), Vector2(sz * 2.0, sz * 2.0)), Color(col.r, col.g, col.b, a))
	var p: Vector2 = _pos(f)
	if t > 0.84:
		var lt: float = (t - 0.84) / 0.16
		canvas.draw_arc(to, RING_R0 + lt * RING_GROW, 0.0, TAU, 18, Color(col.r, col.g, col.b, (1.0 - lt) * 0.7), RING_WIDTH)
	canvas.draw_rect(Rect2(p - Vector2(3.0, SMEAR_REACH), Vector2(6.0, SMEAR_REACH * 2.0)), Color(col.r, col.g, col.b, 0.45))
	canvas.draw_rect(Rect2(p - Vector2(NUGGET_R, NUGGET_R), Vector2(NUGGET_R * 2.0, NUGGET_R * 2.0)), Color(0.05, 0.05, 0.07))
	canvas.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), col)
	canvas.draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.lightened(0.5))


## The box (legacy px) a drop can paint into over its whole flight: the arc rises above both ends, the
## trail lags the head, the ring expands around `to`. Stable over `t`, so a drop cannot flicker at the
## screen edge across frames.
static func bounds(f: Dictionary) -> Rect2:
	var from: Vector2 = f["from"]
	var to: Vector2 = f["to"]
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y) - bow(from, to))
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y))
	return Rect2(lo - Vector2(DRAW_PAD, DRAW_PAD), (hi - lo) + Vector2(DRAW_PAD, DRAW_PAD) * 2.0)
