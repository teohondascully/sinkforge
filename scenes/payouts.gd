class_name Payouts
extends RefCounted

## The PAYOUT layer (juice — #B2): the little "+3 ore" tick that rises off a block you just broke.
##
## Why it exists: breaking rock already had dust, debris, shake and a thump — everything that says the
## BLOW landed — but nothing that says you got PAID. The gain went straight into a hotbar number in the
## corner of the screen, far from where you were looking, so the first minute of the game read as
## effort without reward. This puts the reward at the point of impact, in the item's own colour.
##
## Ticks MERGE: a second gain of the same item near a still-young tick bumps its count instead of
## stacking a second label, so fast digging counts UP (+1 → +2 → +3) rather than spamming the frame —
## the ramp is the satisfying part.
##
## Pure representation, exactly like [Particles]: MainView emits, WorldRenderer draws, the sim never
## sees it. Capped so it can't unbound.

const MAX: int = 12
const LIFE: float = 0.90            ## seconds a tick lives
const RISE: float = 30.0            ## world px it floats upward over its life
const MERGE_RADIUS: float = 40.0    ## a new gain this close to a live tick of the same item merges in
const MERGE_AGE: float = 0.45       ## …as long as that tick is still this young
const FONT_SIZE: int = 11
const PIP_R: float = 3.6            ## radius of the item-coloured diamond ahead of the number

# Each tick: pos, item, count, age.
var _t: Array[Dictionary] = []


## Bank a gain of `count` × `item` at `pos` (world px) — merging into a recent nearby tick of the same
## item when there is one, so a fast dig streak reads as one climbing number.
func gain(pos: Vector2, item: StringName, count: int = 1) -> void:
	if count <= 0:
		return
	for q: Dictionary in _t:
		if q["item"] == item and float(q["age"]) < MERGE_AGE \
				and Vector2(q["pos"]).distance_to(pos) < MERGE_RADIUS:
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


## Draw each tick as a `◆ +N` plate in the item's own colour, rising and fading. The dark drop-shadow
## keeps it legible over bright ore and dark rock alike; the rise eases OUT (fast off the block, then
## drifting) so the pop lands at the moment of the break, and the fade waits for the back half so the
## number is fully solid while you are still looking at it. The pip is drawn here rather than through
## Visuals.draw_item because a textured glyph can't be faded per-call.
func draw(canvas: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	for q: Dictionary in _t:
		var t: float = clampf(float(q["age"]) / LIFE, 0.0, 1.0)     # 0 → 1
		var label: String = "+%d" % int(q["count"])
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var span: float = PIP_R * 2.0 + 3.0 + w
		var origin: Vector2 = Vector2(q["pos"]) - Vector2(span * 0.5, RISE * (1.0 - pow(1.0 - t, 2.2)))
		var alpha: float = clampf((1.0 - t) * 2.0, 0.0, 1.0)        # solid, then fades over the back half
		var tint: Color = Visuals.item_color(q["item"]).lightened(0.35)
		tint.a = alpha
		var pip: Vector2 = origin + Vector2(PIP_R, -FONT_SIZE * 0.3)
		canvas.draw_colored_polygon(PackedVector2Array([
			pip + Vector2(0.0, -PIP_R), pip + Vector2(PIP_R, 0.0),
			pip + Vector2(0.0, PIP_R), pip + Vector2(-PIP_R, 0.0)]), tint)
		var text_at: Vector2 = origin + Vector2(PIP_R * 2.0 + 3.0, 0.0)
		canvas.draw_string(font, text_at + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, Color(0.03, 0.04, 0.06, alpha * 0.75))
		canvas.draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, tint)
