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
##
## THE TICK NAMES ITS ITEM, AND A LOSS IS A TICK TOO (D0424, the third stranger; T029). "+1" beside a
## green chip was read as wood by the first stranger when it was a sapling; and the third pressed [DROP]
## five metres from the forge, watched the hotbar vanish and come back, and read a forge at work. Now
## the tick says "+7 ore" -- and "-7 ore" when the stack leaves the pack, in the same place, dimmer and
## without the pip, so a drop reads as a drop wherever it landed. A loss never merges with a gain: the
## two are what happened, in order, and a drop re-collected after its grace shows both.

const MAX: int = 12
const LIFE: float = 0.90            ## seconds a tick lives
const RISE: float = 30.0            ## legacy px it floats upward over its life
const MERGE_RADIUS: float = 40.0    ## a new gain this close (legacy px) to a live tick of the same item merges in
const MERGE_AGE: float = 0.45       ## ...as long as that tick is still this young
const FONT_SIZE: int = 11
const PIP_R: float = 3.6            ## radius of the item-coloured diamond ahead of the number
const LOSS_DIM: float = 0.7         ## a loss tick's alpha against a gain's: legible, not a reward
const SCALE: float = float(Interface.Units.LOGIC_PX) / 32.0

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


## The losses: every item whose count fell, as [{item, count}] with count the size of the fall (positive),
## in item order. An item that left the pack entirely is in `prev` and not `now`, so both are walked.
static func losses_between(prev: Dictionary, now: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys: Array = prev.keys()
	for k: Variant in now.keys():
		if not prev.has(k):
			keys.append(k)
	for item: StringName in Ordering.ids(keys):
		var d: int = int(now.get(item, 0)) - int(prev.get(item, 0))
		if d < 0:
			out.append({"item": item, "count": -d})
	return out


## What a tick says: the signed count and the item's name in lower case ("+7 ore", "-1 drill"), and for a
## gain a machine beside the body is still working on, how many more are coming ("+1 ingot · 2 more").
static func label_of(item: StringName, count: int, loss: bool, more: int = 0) -> String:
	var base: String = "%s%d %s" % ["-" if loss else "+", count, Hotbar.item_label(item).to_lower()]
	return base if loss or more <= 0 else "%s · %d more" % [base, more]


## THE TICK SAYS WHAT IS STILL COMING (T033, D0442; stranger 8 fed seven ore, took the first ingot and
## walked off to look for the second). For a gained `item`, the units the machines within the collect
## reach of the body still owe: what sits in their output buffers plus what their held inputs will make,
## by their recipe. The machine's own badge is eight pixels at play zoom; the tick at the head is legible.
static func coming(o: Interface.Observation, item: StringName) -> int:
	var body := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	var more: int = 0
	for rec: Dictionary in o.machines:
		var at: Vector2 = (Vector2(rec["cell"]) + Vector2(0.5, 0.5)) * float(Interface.Units.LOGIC_PX)
		if at.distance_to(body) > float(Interface.Units.REACH_PX):
			continue
		more += int((rec.get("output", {}) as Dictionary).get(item, 0))
		var recipe: Dictionary = RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {})
		var out_n: int = int((recipe.get("outputs", {}) as Dictionary).get(item, 0))
		if out_n <= 0:
			continue
		var batches: int = -1
		for need: Variant in (recipe.get("inputs", {}) as Dictionary):
			var held: int = int((rec.get("input", {}) as Dictionary).get(StringName(String(need)), 0))
			var per: int = maxi(int((recipe["inputs"] as Dictionary)[need]), 1)
			batches = held / per if batches < 0 else mini(batches, held / per)
		more += maxi(batches, 0) * out_n
	return more


static func pack_counts(o: Interface.Observation) -> Dictionary:
	var counts: Dictionary = {}
	for slot: Dictionary in o.pack:
		var item := StringName(String(slot.get("item", "")))
		counts[item] = int(counts.get(item, 0)) + int(slot.get("count", 0))
	return counts


## Bank a gain of `count` × `item` at `pos` (legacy px), merging into a recent nearby tick of the same
## item and sign when there is one.
func gain(pos: Vector2, item: StringName, count: int = 1, loss: bool = false, more: int = 0) -> void:
	if count <= 0:
		return
	for q: Dictionary in _t:
		if q["item"] == item and bool(q["loss"]) == loss and float(q["age"]) < MERGE_AGE and Vector2(q["pos"]).distance_to(pos) < MERGE_RADIUS:
			q["count"] = int(q["count"]) + count
			q["more"] = more                         # the latest word on what is still coming
			q["age"] = 0.0                          # re-pop it: the count changed, so re-read it
			return
	if _t.size() >= MAX:
		return
	_t.append({"pos": pos, "item": item, "count": count, "age": 0.0, "loss": loss, "more": more})


## A loss of `count` × `item`: the same tick, signed the other way.
func lose(pos: Vector2, item: StringName, count: int = 1) -> void:
	gain(pos, item, count, true)


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
			gain(hand, g["item"], int(g["count"]), false, coming(o, g["item"]))
		for g: Dictionary in losses_between(_prev_pack, now):
			lose(hand, g["item"], int(g["count"]))
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
		var loss: bool = bool(q.get("loss", false))
		var label: String = label_of(q["item"], int(q["count"]), loss, int(q.get("more", 0)))
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var span: float = PIP_R * 2.0 + 3.0 + w
		var origin: Vector2 = Vector2(q["pos"]) - Vector2(span * 0.5, RISE * (1.0 - pow(1.0 - t, 2.2)))
		var alpha: float = clampf((1.0 - t) * 2.0, 0.0, 1.0) * (LOSS_DIM if loss else 1.0)
		var tint: Color = ItemLook.color(q["item"]).lightened(0.35)
		tint.a = alpha
		if not loss:                                  # a loss has no pip: the number and the name carry it
			var pip: Vector2 = origin + Vector2(PIP_R, -FONT_SIZE * 0.3)
			canvas.draw_colored_polygon(PackedVector2Array([pip + Vector2(0.0, -PIP_R), pip + Vector2(PIP_R, 0.0),
				pip + Vector2(0.0, PIP_R), pip + Vector2(-PIP_R, 0.0)]), tint)
		var text_at: Vector2 = origin + Vector2(PIP_R * 2.0 + 3.0, 0.0)
		canvas.draw_string(font, text_at + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.03, 0.04, 0.06, alpha * 0.75))
		canvas.draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
