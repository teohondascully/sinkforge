class_name Hud
extends Node2D

## Screen-fixed HUD. Lives under a CanvasLayer so the follow-camera does NOT scroll it. Reads the sim
## only (OUTPUT total + the carried inventory) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## The hand-build palette (set by MainView): the machine names you can place, and which is selected.
var palette_names: PackedStringArray = []
var selected_getter: Callable
## The active carried-item slot in the inventory hotbar (set by MainView; mouse-wheel cycles it).
var inv_selected_getter: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_string(_font, Vector2(10, 22), "FORGED   %d ingot" % int(sim.total_produced.get(&"ingot", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))
	_draw_palette()
	_draw_inventory()
	draw_string(_font, Vector2(10, CANVAS.y - 10),
		"move A/D   jump SPACE   mine LMB   build RMB   build-sel 1/2   wheel item   deposit E   pause P",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.78, 0.85))
	if paused_getter.is_valid() and bool(paused_getter.call()):
		draw_string(_font, Vector2(CANVAS.x - 110, 22), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


## The build palette, with the selected machine boxed/brightened — so RMB-to-build has a visible
## current choice (1/2 cycle it). Drawn top-left under OUTPUT.
func _draw_palette() -> void:
	if palette_names.is_empty():
		return
	var sel: int = int(selected_getter.call()) if selected_getter.is_valid() else 0
	var x: float = 10.0
	var y: float = 44.0
	draw_string(_font, Vector2(x, y), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.78, 0.68))
	x += 52.0
	for i: int in palette_names.size():
		var label: String = "%d %s" % [i + 1, palette_names[i]]
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var on: bool = i == sel
		if on:
			draw_rect(Rect2(x - 4.0, y - 13.0, w + 8.0, 18.0), Color(0.30, 0.50, 0.34, 0.55))
		draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.60, 0.96, 0.62) if on else Color(0.50, 0.55, 0.62))
		x += w + 18.0


## The carried pack as a hotbar of slots (icon + count), centred along the bottom. The active slot
## (mouse-wheel) is highlighted; it's the item E deposits. Reads `sim.inventory_slots()`.
func _draw_inventory() -> void:
	var slots: Array[Dictionary] = sim.inventory_slots()
	var n: int = FactorySim.INVENTORY_SLOTS
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = CANVAS.y - 28.0 - SLOT
	for i: int in n:
		var sx: float = x0 + float(i) * (SLOT + SLOT_GAP)
		var slot_rect := Rect2(sx, y, SLOT, SLOT)
		draw_rect(slot_rect, Color(0.09, 0.10, 0.13, 0.88))
		var active: bool = i == sel
		draw_rect(slot_rect, Color(0.96, 0.85, 0.42) if active else Color(0.30, 0.32, 0.38),
			false, 2.0 if active else 1.0)
		if i < slots.size():
			var item: StringName = slots[i]["item"]
			var count: int = int(slots[i]["count"])
			draw_rect(Rect2(sx + 5.0, y + 4.0, SLOT - 10.0, SLOT - 13.0), _item_color(item))
			draw_string(_font, Vector2(sx + 4.0, y + SLOT - 4.0), str(count),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.97, 0.97, 0.99))


func _item_color(item: StringName) -> Color:
	if item == &"ore":
		return Color(0.88, 0.52, 0.24)
	if item == &"ingot":
		return Color(0.97, 0.85, 0.42)
	return Color(0.70, 0.72, 0.78)


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
