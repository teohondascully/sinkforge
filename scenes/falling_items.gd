class_name FallingItems
extends RefCounted

## The COSMETIC falling-product layer — the visual half of the hybrid item model. The sim's abstract
## flow is authoritative (it emits write-only `flow_events`); this turns those events into discrete
## drops that stream down the gravity "conveyor", glow, and spark on landing. It NEVER feeds back into
## the sim (no production math here) — delete it and the numbers are identical. Owns its own state +
## update tick + draw, so MainView stays a controller, not a particle system.

const FALL_DURATION: float = 0.30

## Each drop: {from, to: Vector2 (world), t: 0..1 progress, color: Color}.
var _items: Array[Dictionary] = []


## Turn this tick's sim flow_events into drops (and consume them). `cell_center` maps a cell → world
## centre (MainView's converter) so this module needn't know the grid geometry.
func spawn_from_events(sim: FactorySim, cell_center: Callable) -> void:
	for ev: Dictionary in sim.flow_events:
		var from: Vector2 = cell_center.call(ev["from"])
		var to: Vector2 = cell_center.call(ev["to"])
		var color: Color = Visuals.item_color(ev["item"])
		var count: int = int(ev["count"])
		for i: int in count:
			var jitter := Vector2((float(i) - float(count - 1) * 0.5) * 4.0, 0.0)
			_items.append({"from": from + jitter, "to": to + jitter, "t": 0.0, "color": color})
	sim.flow_events.clear()


## Inject a drop directly (staged visual captures / tests bypass the sim event channel); `t` seeds its
## progress so a capture can stage a spread-out stream in one frame.
func inject(from: Vector2, to: Vector2, color: Color, t: float = 0.0) -> void:
	_items.append({"from": from, "to": to, "t": t, "color": color})


## Advance every drop along its fall; retire the ones that have arrived.
func advance(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for f: Dictionary in _items:
		var t: float = float(f["t"]) + delta / FALL_DURATION
		if t < 1.0:
			f["t"] = t
			keep.append(f)
	_items = keep


func size() -> int:
	return _items.size()


## Current {pos, color} of each drop — MainView's light pass turns these into glowing motes.
func motes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in _items:
		out.append({"pos": _pos(f), "color": f["color"]})
	return out


## The world position of a drop along its ballistic arc (the ONE authority — the trail samples it too).
func _pos(f: Dictionary) -> Vector2:
	return _sample(f["from"], f["to"], float(f["t"]))


## A point on the toss arc from `from` to `to` at progress `t`. Horizontal eases OUT (a tossed item
## shoots forward early, then settles into its landing column); vertical descends linearly minus an
## upward BOW (the launch hop) that grows with the toss distance. A straight-down spit (from.x == to.x)
## keeps the original ~10px pop unchanged — so machine output is visually identical, only sideways
## tosses arc. This is the Minecraft forward-and-down throw expressed over the column landing.
func _sample(from: Vector2, to: Vector2, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var ex: float = 1.0 - (1.0 - t) * (1.0 - t)        # ease-out horizontal
	var x: float = lerpf(from.x, to.x, ex)
	var bow: float = 10.0 + absf(to.x - from.x) * 0.28  # launch hop, taller the further it's tossed
	var y: float = lerpf(from.y, to.y, t) - sin(t * PI) * bow
	return Vector2(x, y)


## Paint the stream on `canvas`: a fading comet-trail + a chunky glowing nugget with a vertical motion-
## smear + a landing sparkle — the gravity pour made loud (the glow itself is added by MainView's lights).
func draw(canvas: CanvasItem) -> void:
	for f: Dictionary in _items:
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var t: float = clampf(float(f["t"]), 0.0, 1.0)
		var col: Color = f["color"]
		var trail: int = 5
		for i: int in range(trail, 0, -1):
			var tt: float = clampf(t - float(i) * 0.055, 0.0, 1.0)
			var pp: Vector2 = _sample(from, to, tt)
			var a: float = (1.0 - float(i) / float(trail + 1)) * 0.34
			var sz: float = 5.5 - float(i) * 0.6
			canvas.draw_rect(Rect2(pp - Vector2(sz, sz), Vector2(sz * 2.0, sz * 2.0)), Color(col.r, col.g, col.b, a))
		var p: Vector2 = _pos(f)
		if t > 0.84:  # landing sparkle: an expanding ring as it nears its rest pile
			var lt: float = (t - 0.84) / 0.16
			canvas.draw_arc(to, 4.0 + lt * 11.0, 0.0, TAU, 18, Color(col.r, col.g, col.b, (1.0 - lt) * 0.7), 2.0)
		canvas.draw_rect(Rect2(p - Vector2(3.0, 8.0), Vector2(6.0, 16.0)), Color(col.r, col.g, col.b, 0.45))  # smear
		canvas.draw_rect(Rect2(p - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Color(0.05, 0.05, 0.07))
		canvas.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), col)
		canvas.draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.lightened(0.5))  # bright core
