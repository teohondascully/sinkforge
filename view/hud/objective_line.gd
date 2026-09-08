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
## THE HOW-TO WRAPS BEFORE IT GIVES (D0424, stranger 3): the smelt rung's sentence ends "then wait: the
## ingots come to you", and at 1280 wide it was elided at "the ingo…" -- the clause that says the ingots
## are collected for you was the one cut. A lesson may take a second line; only past HOWTO_LINES does the
## tail give with an ellipsis, so a squeezed banner still degrades and never grows past the corner chips.
const HOWTO_LINES: int = 2
const HOWTO_LINE_H: float = 11.0   ## authored px between how-to lines
const PAD: float = 12.0
const TOP: float = 8.0
const GOAL_INK := Color(0.97, 0.93, 0.78)
const DONE_INK := Color(0.62, 0.86, 0.58)
## THE ACKNOWLEDGED RUNG NAMES THE NEXT (D0525, strangers 113 and 124): "✓  Forge 2 ingots" stood alone on
## the plate for ACK_HOLD seconds and two strangers read it as the end of the game and quit -- "No new
## objectives appeared". A person waits a beat; one who looks away for the beat sees the same. The tick
## card carries the next rung's goal after this separator, in GOAL_INK, so a finished rung is never the
## last word on the plate. When the whole line will not fit, the next goal is cut to its first clause (up to
## its first comma or colon), never to nothing: "next" stays.
const NEXT_SEP: String = "   ·   next: "

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
	var pad: float = UiTheme.px(PAD)
	var free_w: float = UiTheme.CANVAS.x - (corner_w + UiTheme.px(18.0)) * 2.0
	var say: Dictionary = wording(obj, font, free_w - pad * 2.0 - UiTheme.px(14.0))
	var a: Dictionary = say["a"]
	if float(a["goal"]) <= 0.0 and float(a["hint"]) <= 0.0:
		return {}
	var text: String = say["text"]
	var lines: PackedStringArray = wrap_howto(font, say["howto"], UiTheme.pt(HOWTO_SIZE), free_w - pad * 2.0)
	var howto: String = "\n".join(lines)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE)).x + UiTheme.px(14.0)
	var hw: float = 0.0
	for line: String in lines:
		hw = maxf(hw, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(HOWTO_SIZE)).x)
	var w: float = minf(maxf(tw, hw) + pad * 2.0, free_w)
	var h: float = UiTheme.px(24.0) + (UiTheme.px(13.0) + UiTheme.px(HOWTO_LINE_H) * float(lines.size() - 1) if howto != "" else 0.0)
	var rect := Rect2((UiTheme.CANVAS.x - w) * 0.5, UiTheme.px(TOP), w, h)
	var cy: float = rect.position.y + UiTheme.px(12.0)
	return {"rect": rect, "text": text, "tail": say["tail"], "ink": say["ink"], "goal_a": a["goal"], "howto": howto,
		"hint_a": a["hint"], "done": obj.all_done(), "bullet": Vector2(rect.position.x + pad + UiTheme.px(1.0), cy),
		"text_at": Vector2(rect.position.x + pad + UiTheme.px(14.0), cy + UiTheme.px(5.0)),
		"howto_at": Vector2(rect.position.x + pad, cy + UiTheme.px(18.0))}


## What the plate says, fitted to `max_w`: `text` the whole line, `tail` the end of it drawn in GOAL_INK
## after the rest in `ink` ("" when the line is one ink), `a` the alphas, `howto` the lesson or "".
static func wording(obj: Objectives, font: Font, max_w: float) -> Dictionary:
	var size: int = UiTheme.pt(GOAL_SIZE)
	if obj.all_done():
		return {"text": Inspector.fit_text(font, "✓  All set — keep digging deeper.", size, max_w), "tail": "",
			"ink": DONE_INK, "a": alphas(0, 0.0, true), "howto": ""}
	if obj.current_index() > 0 and obj.step_age < ACK_HOLD:
		return acknowledged(obj.current_index(), font, max_w)
	var step: Dictionary = Objectives.STEPS[obj.current_index()]
	var text: String = String(step["goal"])
	var progress: String = obj.progress(step["id"])
	if progress != "":
		text += "   " + progress
	var a: Dictionary = alphas(obj.current_index(), obj.step_age, false)
	var howto: String = BindingLabels.fill(String(step["label"])) if float(a["hint"]) > 0.0 else ""
	return {"text": Inspector.fit_text(font, text, size, max_w), "tail": "", "ink": GOAL_INK, "a": a, "howto": howto}


## The rung just finished, acknowledged: its goal with a tick, then NEXT_SEP and the goal of the rung that
## is current now, `next_index` (D0525). The next goal gives first, to its first clause, when the whole
## line will not fit `max_w`; the ellipsis is the last resort and cuts from the end, so "next:" survives it.
static func acknowledged(next_index: int, font: Font, max_w: float) -> Dictionary:
	var size: int = UiTheme.pt(GOAL_SIZE)
	var head: String = "✓  " + String(Objectives.STEPS[next_index - 1]["goal"])
	var next: String = String(Objectives.STEPS[next_index]["goal"])
	var text: String = head + NEXT_SEP + next
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		text = head + NEXT_SEP + first_clause(next)
	text = Inspector.fit_text(font, text, size, max_w)
	var tail: String = text.substr(head.length()) if text.begins_with(head) else ""
	return {"text": text, "tail": tail, "ink": DONE_INK, "a": alphas(0, 0.0, true), "howto": ""}


## A goal up to its first comma or colon; the whole goal when it has neither.
static func first_clause(goal: String) -> String:
	var cut: int = goal.length()
	for mark: String in [",", ":"]:
		var at: int = goal.find(mark)
		if at > 0:
			cut = mini(cut, at)
	return goal.substr(0, cut).strip_edges(false, true)


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	objectives.refresh(frame.obs, dt)
	var font: Font = ThemeDB.fallback_font
	var depth: Dictionary = DepthChip.layout(frame, font)
	var corner_w: float = (depth["chip"] as Rect2).size.x if not depth.is_empty() else 0.0
	# The corner map is a chart that fills its box now (D0430), the wider of the two corner chips.
	if frame.obs.map_cells.x > 0 and frame.obs.map_cells.y > 0:
		corner_w = maxf(corner_w, Minimap.frame_rect(frame.obs.map_cells, false).size.x)
	var l: Dictionary = layout(objectives, font, corner_w)
	if l.is_empty():
		return
	UiTheme.panel(ci, l["rect"], maxf(float(l["goal_a"]), float(l["hint_a"])))
	var ink: Color = l["ink"]
	if not bool(l["done"]):
		ci.draw_circle(l["bullet"], UiTheme.px(3.0), Color(ink, ink.a * float(l["goal_a"])))
	var text: String = l["text"]
	var tail: String = l["tail"]
	var head: String = text.substr(0, text.length() - tail.length())
	ci.draw_string(font, l["text_at"], head, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE), Color(ink, ink.a * float(l["goal_a"])))
	if tail != "":
		# The next rung's goal after the tick's, in the goal's own ink (D0525): two words on one line.
		var at_tail: Vector2 = (l["text_at"] as Vector2) + Vector2(font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE)).x, 0.0)
		ci.draw_string(font, at_tail, tail, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(GOAL_SIZE), Color(GOAL_INK, GOAL_INK.a * float(l["goal_a"])))
	if String(l["howto"]) != "":
		var at: Vector2 = l["howto_at"]
		for line: String in String(l["howto"]).split("\n"):
			ci.draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(HOWTO_SIZE), Color(UiTheme.UI_TEXT_DIM, float(l["hint_a"])))
			at.y += UiTheme.px(HOWTO_LINE_H)


## The how-to as at most HOWTO_LINES lines of `max_w`, greedy on words; the last line gives with an
## ellipsis when the rest will not fit. An empty how-to is no lines.
static func wrap_howto(font: Font, text: String, size: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	if text == "":
		return out
	var words: PackedStringArray = text.split(" ", false)
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		out.append(text)
		return out
	# Two lines that both fit: the split that leaves them most even, so no line is a single orphaned word.
	var best: int = -1
	var best_w: float = INF
	for i: int in range(1, words.size()):
		var a: float = font.get_string_size(" ".join(words.slice(0, i)), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var b: float = font.get_string_size(" ".join(words.slice(i)), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if a <= max_w and b <= max_w and maxf(a, b) < best_w:
			best_w = maxf(a, b)
			best = i
	if best > 0 and HOWTO_LINES >= 2:
		out.append(" ".join(words.slice(0, best)))
		out.append(" ".join(words.slice(best)))
		return out
	var line: String = ""
	var i: int = 0
	while i < words.size() and out.size() < HOWTO_LINES - 1:
		var trial: String = words[i] if line == "" else line + " " + words[i]
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
			out.append(line)
			line = ""
			continue
		line = trial
		i += 1
	var rest: PackedStringArray = words.slice(i)
	var tail: String = line if rest.is_empty() else (line + " " if line != "" else "") + " ".join(rest)
	out.append(Inspector.fit_text(font, tail, size, max_w))
	return out
