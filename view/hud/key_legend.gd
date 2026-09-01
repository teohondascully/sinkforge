class_name KeyLegend
extends RefCounted

## THE BOTTOM-LEFT KEY LEGEND, and the idea in it: **a line that teaches itself out of existence.**
## Ported from `legacy/scenes/hud.gd:2021-2043` (`HINT_KEYS`, `note_hint_used`, `_draw_hint`).
##
## Legacy's own note on the line it replaced — "the tiny bottom-left key legend, which replaces the giant
## footer" — and on why each row goes away: *"everything here has been used, so the line has finished its
## job."* A permanent control footer is furniture the player stops seeing in the first minute and which
## then costs a strip of screen forever. One that retires row by row costs nothing after the first minute
## and is there for exactly as long as it is needed.
##
## **THE TABLE IS NOT LEGACY'S, AND THAT IS NOT A LIBERTY.** Its five rows are grapple, drop, craft, map
## and help — **not one of those verbs exists in this build.** Porting the table would put five hints on
## screen for keys that do nothing, which is worse than no legend at all. What ports is the MECHANISM and
## the rule; the rows are this build's own three verbs, read off `view/controls.gd` so the labels cannot
## drift from the bindings.
##
## **RETIRED ON THE EFFECT, NOT ON THE KEYPRESS, and the difference is deliberate.** Legacy's
## `note_hint_used` is called from its input handler, so a row goes away the instant the key is pressed.
## This reads the OBSERVATION instead: you have learned to walk when you have MOVED, not when you have
## held a key against a wall. It is also the only source a HUD chip has — the alternative is a second
## contract carrying raw input into `view/hud/`, which would be a parallel path to the same tick that
## `view/hud/hud_layer.gd` exists specifically to avoid.

## Each row: the id it is remembered by, the label, and (implicitly) the observation that satisfies it.
## Ids are `Controls`' own action names, so a row can never name a binding that does not exist.
const ROWS: Array[Dictionary] = [
	{"id": Controls.LEFT, "label": "A / D  move"},
	{"id": Controls.JUMP, "label": "SPACE  jump"},
	{"id": Controls.MINE, "label": "LMB  mine"},
]

const SEPARATOR: String = "   ·   "   ## legacy's own separator, a middle dot with air either side
const SIZE: int = 10                  ## legacy's, in `UiTheme.AUTHORED` pixels
const MARGIN_X: float = 10.0
const BASELINE_UP: float = 8.0        ## above the canvas's bottom edge

## What counts as having DONE each verb. Small, so the legend cannot retire a row on sensor noise: a body
## nudged one pixel by a resolver has not walked anywhere.
const MOVED_PX_PER_S: int = 20 * Fx.SCALE

var _used: Dictionary = {}


## Marks whatever this frame demonstrates. Returns true when something retired, so a test can tell "the
## player did nothing new" from "the guard suppressed it" — the same reason `CrumblePainter.note_frame`
## and `ArrivalPlate.note_frame` report.
func note_frame(frame: Frame) -> bool:
	if frame == null or frame.obs == null:
		return false
	var before: int = _used.size()
	var obs: Interface.Observation = frame.obs
	if absi(obs.vel_x) > MOVED_PX_PER_S:
		_used[Controls.LEFT] = true
	if not obs.on_floor:
		_used[Controls.JUMP] = true
	if obs.mining_is_charging or obs.mining_broke:
		_used[Controls.MINE] = true
	return _used.size() > before


## The rows still worth showing, in the table's order. Returned as data — and EMPTY when the legend has
## finished its job, which is a state the chip has to be able to be in rather than a degenerate one.
func remaining() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Dictionary in ROWS:
		if not _used.has(row["id"]):
			out.append(String(row["label"]))
	return out


## Everything the legend decides. Empty when there is nothing left to say — the same split, and the same
## reason, as `view/hud/depth_chip.gd`: `paint` alone can only ever assert "it did not crash", which is
## exactly what a chip that has silently retired every row also does.
func layout(frame: Frame, font: Font) -> Dictionary:
	# The observation is checked even though the legend's CONTENT does not depend on it. `WorldView`
	# builds a frame every rendered tick and an incomplete one must draw nothing — the same rule every
	# other chip follows. Without it `paint` reached `draw_string` on a startup frame, which Godot refuses
	# outside `_draw()`; the masked-crash detector caught it and no assertion here would have, because
	# every row of this suite is about the legend's CONTENT and the content was correct.
	if frame == null or frame.obs == null or font == null:
		return {}
	var parts: PackedStringArray = remaining()
	if parts.is_empty():
		return {}
	return {
		"text": SEPARATOR.join(parts),
		"at": Vector2(UiTheme.px(MARGIN_X), UiTheme.CANVAS.y - UiTheme.px(BASELINE_UP)),
		"rows": parts.size(),
	}


## The transcription, holding no decision of its own beyond the empty-layout guard.
func paint(frame: Frame, ci: CanvasItem) -> void:
	note_frame(frame)
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(frame, font)
	if l.is_empty():
		return
	# `UI_TEXT_DIM`, legacy's own choice and the second rung of the ramp. Not `UI_TEXT_FAINT`: this is
	# type the player is meant to READ once, and `view/hud/ui_theme.gd` records that the faint rung
	# measures between 2.04 and 3.96 against the plates it lands on.
	ci.draw_string(font, l["at"], l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.pt(SIZE), UiTheme.UI_TEXT_DIM)
