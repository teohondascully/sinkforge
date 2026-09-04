class_name Payouts
extends RefCounted

## THE PAYOUT LAYER (A' step 6d, D0365): the "+3 ore" tick that rises off the body when the pack gains,
## so the reward reads at the point of the work rather than only in a hotbar counter at the edge of the
## screen. Legacy `scenes/payouts.gd`, whose gains `MainView` emitted from its verbs; here the layer reads
## the OBSERVATION and banks a gain whenever the pack's count of an item rose since the last frame -- the
## pack is the one ledger every yield lands in, so no verb has to be wired to it and none can be missed.
##
## Ticks merge: a second gain of the same item near a still-young tick bumps its count instead of
## stacking a second label, so a fast dig streak counts up (+1, +2, +3) rather than spamming the frame.
## Pure representation; capped so it cannot grow without bound. Sizes are legacy's px under the
## fine-detail transform (`SCALE`, a 32 px cell became 16).

const MAX: int = 12
const LIFE: float = 0.90            ## seconds a tick lives
const RISE: float = 30.0            ## legacy px it floats upward over its life
const MERGE_RADIUS: float = 40.0    ## a new gain this close (legacy px) to a live tick of the same item merges in
const MERGE_AGE: float = 0.45       ## ...as long as that tick is still this young
const FONT_SIZE: int = 11
const PIP_R: float = 3.6            ## radius of the item-coloured diamond ahead of the number
const SCALE: float = float(Interface.Observation.LOGIC_PX) / 32.0

var _t: Array[Dictionary] = []      ## each tick: pos (legacy px), item, count, age
var _prev_pack: Dictionary = {}
var _primed: bool = false
var _last_time: float = 0.0


## The gains between two packs ({item: count}), as [{item, count}] in item order; the first frame primes.
static func gains_between(prev: Dictionary, now: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in Ordering.ids(now.keys()):
		var d: int = int(now[item]) - int(prev.get(item, 0))
		if d > 0:
			out.append({"item": item, "count": d})
	return out


static func pack_counts(o: Interface.Observation) -> Dictionary:
	var counts: Dictionary = {}
	for slot: Dictionary in o.pack:
		var item := StringName(String(slot.get("item", "")))
		counts[item] = int(counts.get(item, 0)) + int(slot.get("count", 0))
	return counts


## Bank a gain of `count` × `item` at `pos` (legacy px), merging into a recent nearby tick of the same
## item when there is one.
func gain(pos: Vector2, item: StringName, count: int = 1) -> void:
	if count <= 0:
		return
	for q: Dictionary in _t:
		if q["item"] == item and float(q["age"]) < MERGE_AGE and Vector2(q["pos"]).distance_to(pos) < MERGE_RADIUS:
			q["count"] = int(q["count"]) + count
			q["age"] = 0.0                          # re-pop it: the count changed, so re-read it
			return
	if _t.size() >= MAX:
		return
	_t.append({"pos": pos, "item": item, "count": count, "age": 0.0})


func advance(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for q: Dictionary in _t:
		q["age"] = float(q["age"]) + delta
		if float(q["age"]) < LIFE:
			kept.append(q)
	_t = kept


func size() -> int:
	return _t.size()


## Read the frame's pack against the last one, bank the gains at the body's hand, age the ticks. No
## drawing: the observation step is separable so it can be exercised without a canvas.
func observe_frame(frame: Frame) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	var now: Dictionary = pack_counts(o)
	if _primed:
		var hand := Vector2(float(o.hand.x) / float(Fx.SCALE), float(o.hand.y) / float(Fx.SCALE)) / SCALE
		for g: Dictionary in gains_between(_prev_pack, now):
			gain(hand, g["item"], int(g["count"]))
	_prev_pack = now
	_primed = true
	advance(dt)


func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	observe_frame(frame)
	if _t.is_empty():
		return
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(SCALE, SCALE))
	draw(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Each tick as a `◆ +N` plate in the item's own colour, rising and fading. The rise eases out so the pop
## lands at the moment of the gain, and the fade waits for the back half so the number is solid while it
## is being read; a dark drop-shadow keeps it legible over bright ore and dark rock alike.
func draw(canvas: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	for q: Dictionary in _t:
		var t: float = clampf(float(q["age"]) / LIFE, 0.0, 1.0)
		var label: String = "+%d" % int(q["count"])
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var span: float = PIP_R * 2.0 + 3.0 + w
		var origin: Vector2 = Vector2(q["pos"]) - Vector2(span * 0.5, RISE * (1.0 - pow(1.0 - t, 2.2)))
		var alpha: float = clampf((1.0 - t) * 2.0, 0.0, 1.0)
		var tint: Color = ItemLook.color(q["item"]).lightened(0.35)
		tint.a = alpha
		var pip: Vector2 = origin + Vector2(PIP_R, -FONT_SIZE * 0.3)
		canvas.draw_colored_polygon(PackedVector2Array([pip + Vector2(0.0, -PIP_R), pip + Vector2(PIP_R, 0.0),
			pip + Vector2(0.0, PIP_R), pip + Vector2(-PIP_R, 0.0)]), tint)
		var text_at: Vector2 = origin + Vector2(PIP_R * 2.0 + 3.0, 0.0)
		canvas.draw_string(font, text_at + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.03, 0.04, 0.06, alpha * 0.75))
		canvas.draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
