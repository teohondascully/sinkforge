class_name FallingItems
extends RefCounted

## The COSMETIC falling-product layer — the visual half of the hybrid item model. The sim's abstract
## flow is authoritative (it emits write-only `flow_events`); this turns those events into discrete
## drops that stream down the gravity "conveyor", glow, and spark on landing. It NEVER feeds back into
## the sim (no production math here) — delete it and the numbers are identical. Owns its own state +
## update tick + draw, so MainView stays a controller, not a particle system.

const FALL_DURATION: float = 0.30
## HARD CAP on live discrete drops: the abstract flow layer is authoritative — production
## math never depends on these — so past the cap a new drop adds churn and screen noise, not information
## (a pouring column at 240 reads identically to one at 400). Spawns beyond it simply aren't visualized.
const MAX_ITEMS: int = 240

## The landing sparkle ring, which is the widest thing a drop paints: it expands from RING_R0 out to
## RING_R0 + RING_GROW over the last of the fall, stroked RING_WIDTH wide, so its outermost painted pixel
## sits RING_R0 + RING_GROW + RING_WIDTH * 0.5 from the landing point.
const RING_R0: float = 4.0
const RING_GROW: float = 11.0
const RING_WIDTH: float = 2.0
## The nugget's own furniture, measured from the drop's centre: the vertical motion smear hangs
## SMEAR_REACH below it, the dark backing rect covers NUGGET_R around it, and the comet trail is drawn
## around that same centre at TRAIL_SIZE less one TRAIL_SHRINK step (4.9) at its very largest, so
## NUGGET_R already covers the trail.
const SMEAR_REACH: float = 8.0
const NUGGET_R: float = 6.0
const TRAIL_SIZE: float = 5.5
const TRAIL_SHRINK: float = 0.6

## How far past the flight path a drop can still paint, in px. DERIVED, and that is the point: this is a
## cull margin, and a cull margin smaller than the thing it culls drops a sparkle that is still on screen,
## which is the kind of bug that only appears when the player is walking away from a working machine.
## It used to be 16.0 by hand, beside a comment that put the ring at radius 15 and called 16 generous.
## The stroke's own half-width is the sixteenth pixel, so the margin was exactly saturated rather than
## generous, and nothing in the code related the two numbers.
const DRAW_PAD: float = maxf(RING_R0 + RING_GROW + RING_WIDTH * 0.5, maxf(SMEAR_REACH, NUGGET_R))

## Each drop: {from, to: Vector2 (world), t: 0..1 progress, color: Color}.
var _items: Array[Dictionary] = []
## Retired drop dicts, reused by the next spawn — the high-churn pooling the principles doc asks for
##: steady-state streaming allocates NOTHING per event.
var _pool: Array[Dictionary] = []
var _motes_scratch: Array[Dictionary] = []   ## reused motes() output (the light pass calls it per frame)
## Landings retired this frame, keyed by the cell they came down on -> {pos, color, drop}. Drained by
## `take_landings()`; see there for why it merges rather than lists.
var _landed: Dictionary = {}


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
			_spawn(from + jitter, to + jitter, color, 0.0)
	sim.flow_events.clear()


## Inject a drop directly (staged visual captures / tests bypass the sim event channel); `t` seeds its
## progress so a capture can stage a spread-out stream in one frame.
func inject(from: Vector2, to: Vector2, color: Color, t: float = 0.0) -> void:
	_spawn(from, to, color, t)


## One drop into flight: from the pool when it has one (overwrite in place), a fresh dict only while
## the pool is still warming up. Refused (silently — cosmetic layer) once MAX_ITEMS are in the air.
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


## Advance every drop along its fall; retire arrivals into the pool. In-place swap-remove (no rebuilt
## array per frame) — draw order between two falling nuggets is imperceptible, so the shuffle is free.
func advance(delta: float) -> void:
	var i: int = _items.size() - 1
	while i >= 0:
		var f: Dictionary = _items[i]
		var t: float = float(f["t"]) + delta / FALL_DURATION
		if t < 1.0:
			f["t"] = t
		else:
			# ARRIVED. Record it before the dict goes back to the pool and its fields are overwritten.
			var to: Vector2 = f["to"]
			var drop: float = absf(to.y - (f["from"] as Vector2).y)
			# Derived, never written down: a literal 32 here would be correct today and silently wrong the day
			# CELL moves, merging landings on the wrong grid. That constant is already duplicated across
			# this repo more times than anyone wants; this is not becoming another one.
			var key: Vector2i = Vector2i((to / float(WorldRenderer.CELL)).round())
			if not _landed.has(key) or drop > float(_landed[key]["drop"]):
				_landed[key] = {"pos": to, "color": f["color"], "drop": drop}
			_items[i] = _items[_items.size() - 1]
			_items.resize(_items.size() - 1)
			_pool.append(f)
		i -= 1


## WHERE THE DROPS LANDED THIS FRAME, and the caller consumes them.
##
## A drop's feedback used to fire at the moment of the THROW and at the toss cell (`main.gd`, one
## `_particles.pop` at `target`), while the item itself is still in the air for `FALL_DURATION` and comes
## down at `sim.last_drop_landing`, which may be forty rows below. So the one cue the toss had was in the
## wrong place at the wrong time, and the arrival — the part with any weight in it — had none at all.
##
## MERGED BY CELL, which is the whole reason this returns a dictionary rather than a list. A stack of ten
## spawns ten flights (`spawn_from_events` loops `count` with jitter), and ten separate puffs on one cell is
## not ten times the feedback, it is a smear. One landing per cell per frame, carrying the LONGEST fall of
## the group, because the deepest drop is the one the sound and the dust should be sized to.
##
## Returns the accumulator and clears it: whoever calls this owns the events, and calling twice in a frame
## gets nothing the second time. That is deliberate — two consumers would both fire the same landing.
func take_landings() -> Dictionary:
	var out: Dictionary = _landed
	_landed = {}
	return out


func size() -> int:
	return _items.size()


## Current {pos, color} of each drop — MainView's light pass turns these into glowing motes. Returns a
## REUSED scratch array (valid until the next call): the per-frame caller iterates and forgets it.
func motes() -> Array[Dictionary]:
	if _motes_scratch.size() > _items.size():
		_motes_scratch.resize(_items.size())
	while _motes_scratch.size() < _items.size():
		_motes_scratch.append({"pos": Vector2.ZERO, "color": Color.WHITE})
	for i: int in _items.size():
		var m: Dictionary = _motes_scratch[i]
		m["pos"] = _pos(_items[i])
		m["color"] = _items[i]["color"]
	return _motes_scratch


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
	var y: float = lerpf(from.y, to.y, t) - sin(t * PI) * _bow(from, to)
	return Vector2(x, y)


## The height of the launch hop, taller the further the item is tossed. Factored out because the cull box
## has to know exactly how far above the straight line the arc reaches — if these two ever disagreed, drops
## would vanish at the top of a long toss and the bug would only show on wide machine spacings.
func _bow(from: Vector2, to: Vector2) -> float:
	return 10.0 + absf(to.x - from.x) * 0.28


## Paint the stream on `canvas`: a fading comet-trail + a chunky glowing nugget with a vertical motion-
## smear + a landing sparkle — the gravity pour made loud (the glow itself is added by MainView's lights).
func draw(canvas: CanvasItem, view: Rect2) -> void:
	for f: Dictionary in _items:
		if not view.intersects(_bounds(f)):
			continue                      # off-screen: invisible, so drawing it is pure cost
		_draw_item(canvas, f)


## Everything one drop paints this frame — about ten primitives, which is the whole reason the cull above
## matters. MAX_ITEMS is 240, so an unculled pour costs the frame ~2400 draw calls whether or not the
## player can see a single one of them, and a factory you have left running upstairs while you mine is
## exactly the case where none of them are on screen.
func _draw_item(canvas: CanvasItem, f: Dictionary) -> void:
	var from: Vector2 = f["from"]
	var to: Vector2 = f["to"]
	var t: float = clampf(float(f["t"]), 0.0, 1.0)
	var col: Color = f["color"]
	var trail: int = 5
	for i: int in range(trail, 0, -1):
		var tt: float = clampf(t - float(i) * 0.055, 0.0, 1.0)
		var pp: Vector2 = _sample(from, to, tt)
		var a: float = (1.0 - float(i) / float(trail + 1)) * 0.34
		var sz: float = TRAIL_SIZE - float(i) * TRAIL_SHRINK
		canvas.draw_rect(Rect2(pp - Vector2(sz, sz), Vector2(sz * 2.0, sz * 2.0)), Color(col.r, col.g, col.b, a))
	var p: Vector2 = _pos(f)
	if t > 0.84:  # landing sparkle: an expanding ring as it nears its rest pile
		var lt: float = (t - 0.84) / 0.16
		canvas.draw_arc(to, RING_R0 + lt * RING_GROW, 0.0, TAU, 18,
			Color(col.r, col.g, col.b, (1.0 - lt) * 0.7), RING_WIDTH)
	canvas.draw_rect(Rect2(p - Vector2(3.0, SMEAR_REACH), Vector2(6.0, SMEAR_REACH * 2.0)),
		Color(col.r, col.g, col.b, 0.45))  # smear
	canvas.draw_rect(Rect2(p - Vector2(NUGGET_R, NUGGET_R), Vector2(NUGGET_R * 2.0, NUGGET_R * 2.0)),
		Color(0.05, 0.05, 0.07))
	canvas.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9.0, 9.0)), col)
	canvas.draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.lightened(0.5))  # bright core


## The world box this drop can paint into, for the whole of its flight.
##
## Deliberately the WHOLE arc rather than the drop's position this instant: the trail lags the head by up
## to five samples and the landing ring expands around `to`, so a box around the current point alone would
## clip a trail that is still on screen after the head has left it. Bounding the flight also makes the
## test cheap and stable — it does not change as `t` advances, so an item cannot flicker in and out at the
## screen edge across frames.
func _bounds(f: Dictionary) -> Rect2:
	var from: Vector2 = f["from"]
	var to: Vector2 = f["to"]
	var lo := Vector2(minf(from.x, to.x), minf(from.y, to.y) - _bow(from, to))   # the arc rises ABOVE both ends
	var hi := Vector2(maxf(from.x, to.x), maxf(from.y, to.y))
	return Rect2(lo - Vector2(DRAW_PAD, DRAW_PAD), (hi - lo) + Vector2(DRAW_PAD, DRAW_PAD) * 2.0)
