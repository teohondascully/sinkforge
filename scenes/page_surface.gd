class_name PageSurface
extends RefCounted

## WHAT EVERY DRAWN PAGE NEEDS AND NOTHING ELSE.
##
## A page is a plain object that draws onto somebody else's canvas. It therefore needs four things and,
## it turns out, exactly four: the canvas, the font, whether a probe run is measuring, and the array the
## probe collects into. Every helper below is a function of those and nothing more, which is why they
## belong here rather than being written out once per page.
##
## They were written out once per page. `SettingsPage` and `BazaarPage` held eleven of these each,
## byte-identical after comments, because each page acquired its own copy at the moment it was carved out
## of `hud.gd`. Two copies that agree are survivable; the arithmetic stops being survivable at the split
## this is clearing the way for, where five units would have carried five copies of the same eleven.
##
## Nothing here draws anything of its own. Each one binds the canvas, the font and the probe onto a
## primitive that lives in `Visuals` or `UiTheme`, so the shared thing stays in one place and this is only
## the address it is reached through.


## The canvas is somebody else's; a page never creates one and never keeps a reference to the owner.
var _canvas: CanvasItem = null
var _font: Font = ThemeDB.fallback_font

## `probing` is mirrored from the Hud, and `panel_probe` is THE SAME array object it holds, shared by
## reference: a layout check reads the rectangles out of it after a draw, so a copy would collect nothing.
var probing: bool = false
var panel_probe: Array[Rect2] = []


func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	if probing:
		panel_probe.append(rect)
	Visuals.round_rect(_canvas, rect, r, col)


func _round_rect_left(rect: Rect2, r: float, col: Color) -> void:
	Visuals.round_rect_left(_canvas, rect, r, col)


func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	return Visuals.keycap(_canvas, _font, at, key, fs, panel_probe if probing else [])


func _keycap_w(key: String, fs: int) -> float:
	return Visuals.keycap_width(_font, key, fs)


func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	Visuals.tracked(_canvas, _font, text, at, size, track, col)


func _tracked_w(text: String, size: int, track: float) -> float:
	return Visuals.tracked_width(_font, text, size, track)


func _rail_slots(rail: Rect2, n: int, min_pitch: float, slot_h: float) -> Array:
	return UiTheme.rail_slots(rail, n, min_pitch, slot_h)


func _rail_word_slot_h() -> float:
	return UiTheme.rail_word_slot_h(_font)


func _rail_key_slot_h() -> float:
	return UiTheme.rail_key_slot_h(_font)


func _rail_word_dy() -> float:
	return UiTheme.rail_word_dy(_font)


func _rail_key_dy() -> float:
	return UiTheme.rail_key_dy(_font)

## Darkens the frame's edges so the eye is pushed to whatever the modal is showing. Every modern pause
## screen does it, and this one did not, which was part of why a panel read as pasted onto a screenshot.
## It sat on both pages under the name `_bazaar_vignette`, including on the settings page, where the
## Bazaar has nothing to do with it.
func _modal_vignette(peak: float) -> void:
	Visuals.edge_vignette(_canvas, UiTheme.CANVAS, peak)
