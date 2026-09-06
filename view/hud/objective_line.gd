class_name ObjectiveLine
extends RefCounted

## THE OBJECTIVE BANNER (A' step 6h (ii), D0370): the current step's goal chip centred at the top, with
## its how-to line arriving when a step opens and again once you have sat on it long enough to be stuck.
## Legacy `hud.gd`'s `_draw_objective_line` on the layout/paint split; every number legacy's authoring
## number through `UiTheme.px`/`pt`. The chip owns the ladder and steps it from the frame, so the banner
## and the world are one tick.
##
## Legacy's rule -- nothing OFFERED after the first lesson, a later step's how-to arriving only once you had
## stalled forty seconds -- is REVERSED (D0411, the review's rank 3: "guidance disappears at the wrong point
## in learning"). Every rung now keeps its goal chip, shows its how-to for `HINT_HOLD` seconds the moment it
## opens, fades it, and brings it back once you have stalled (`HINT_STUCK`); a rung just finished is
## acknowledged with a tick for `ACK_HOLD` seconds before the next goal takes the plate. The banner is
## centred between the two corner chips and clamps to the free span, the how-to being the part that gives;
## a finished ladder lingers and then clears the screen for veterans.

const HINT_HOLD: float = 9.0
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0
const GOAL_FADE: float = 1.2          ## how long reactive guidance takes to arrive once you have stalled
const ACK_HOLD: float = 1.6           ## seconds a just-finished rung shows its tick before the next goal
const GOAL_SIZE: int = 11   ## legacy 13: the banner was the largest thing in the frame (VISUAL_QUEUE v2 V22)
const HOWTO_SIZE: int = 9   ## legacy 10
const PAD: float = 12.0
const TOP: float = 8.0
const GOAL_INK := Color(0.97, 0.93, 0.78)
const DONE_INK := Color(0.62, 0.86, 0.58)

var objectives: Objectives = Objectives.new()
var _last_time: float = 0.0


## The goal's and the how-to's alphas for a step of `age` at `index`, legacy's arithmetic.
static func alphas(_index: int, age: float, done: bool) -> Dictionary:
	if done:
		return {"goal": 1.0, "hint": 0.0}
	var hint_a: float = 0.0
	if age < HINT_HOLD + HINT_FADE:
		hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
	elif age > HINT_STUCK:
		hint_a = clampf((age - HINT_STUCK) / GOAL_FADE, 0.0, 1.0)
	return {"goal": 1.0, "hint": hint_a}


## Everything the banner decides; `{}` when there is nothing to say. `corner_w` is the wider of the two
## corner chips in canvas px (the depth chip; legacy also measured FORGED), so the banner cannot grow
## under either.
static func layout(obj: Objectives, font: Font, corner_w: float) -> Dictionary:
	if obj == null or font == null:
		return {}
	if obj.all_done() and obj.done_for() > Objectives.LINGER_DONE:
		return {}
	var text: String
	var ink: Color
	var howto: String = ""
	var a: Dictionary
	if obj.all_done():
		text = "✓  All set — keep digging deeper."
		ink = DONE_INK
		a = alphas(0, 0.0, true)
	elif obj.current_index() > 0 and obj.step_age < ACK_HOLD:
		# The rung just finished, acknowledged: its goal with a tick, before the next takes the plate.
		text = "✓  " + String(Objectives.STEPS[obj.current_index() - 1]["goal"])
		ink = DONE_INK
		a = alphas(0, 0.0, true)
	else:
		var step: Dictionary = Objectives.STEPS[obj.current_index()]
		text = String(step["goal"])
		var progress: String = obj.progress(step["id"])
		if progress != "":
			text += "   " + progress
		ink = GOAL_INK
		a = alphas(obj.current_index(), obj.step_age, false)
		if float(a["hint"]) > 0.0:
			howto = BindingLabels.fill(String(step["label"]))
	if float(a["goal"]) <= 0.0 and float(a["hint"]) <= 0.0:
		return {}
	var pad: float = UiTheme.px(PAD)
	var free_w: float = UiTheme.CANVAS.x - (corner_w + UiTheme.px(18.0)) * 2.0
	text = Inspector.fit_text(font, text, UiTheme.pt(GOAL_SIZE), free_w - pad * 2.0 - UiTheme.px(14.0))
	howto = Inspector.fit_text(font, howto, UiTheme.pt(HOWTO_SIZE), free_w - pad * 2.0)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE)).x + UiTheme.px(14.0)
	var hw: float = font.get_string_size(howto, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(HOWTO_SIZE)).x if howto != "" else 0.0
	var w: float = minf(maxf(tw, hw) + pad * 2.0, free_w)
	var h: float = UiTheme.px(24.0) + (UiTheme.px(13.0) if howto != "" else 0.0)
	var rect := Rect2((UiTheme.CANVAS.x - w) * 0.5, UiTheme.px(TOP), w, h)
	var cy: float = rect.position.y + UiTheme.px(12.0)
	return {"rect": rect, "text": text, "ink": ink, "goal_a": a["goal"], "howto": howto, "hint_a": a["hint"],
		"done": obj.all_done(), "bullet": Vector2(rect.position.x + pad + UiTheme.px(1.0), cy),
		"text_at": Vector2(rect.position.x + pad + UiTheme.px(14.0), cy + UiTheme.px(5.0)),
		"howto_at": Vector2(rect.position.x + pad, cy + UiTheme.px(18.0))}


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	objectives.refresh(frame.obs, dt)
	var font: Font = ThemeDB.fallback_font
	var depth: Dictionary = DepthChip.layout(frame, font)
	var corner_w: float = (depth["chip"] as Rect2).size.x if not depth.is_empty() else 0.0
	var l: Dictionary = layout(objectives, font, corner_w)
	if l.is_empty():
		return
	UiTheme.panel(ci, l["rect"], maxf(float(l["goal_a"]), float(l["hint_a"])))
	var ink: Color = l["ink"]
	if not bool(l["done"]):
		ci.draw_circle(l["bullet"], UiTheme.px(3.0), Color(ink, ink.a * float(l["goal_a"])))
	ci.draw_string(font, l["text_at"], l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE), Color(ink, ink.a * float(l["goal_a"])))
	if String(l["howto"]) != "":
		ci.draw_string(font, l["howto_at"], l["howto"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(HOWTO_SIZE), Color(UiTheme.UI_TEXT_DIM, float(l["hint_a"])))
