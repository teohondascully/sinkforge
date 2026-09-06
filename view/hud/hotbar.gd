class_name Hotbar
extends RefCounted

## THE HOTBAR (A' step 6g, D0368): the carried pack as a row of slots, icon and count, centred along the
## bottom; the active slot lit; the selected item named above the bar; a chevron at whichever end has
## more pack behind it; the hovered slot's tooltip; and the PACK FULL chip top-right while the pack has
## no room. Ported from `legacy/scenes/hud.gd`'s `_draw_inventory`, `_more_mark`, `_draw_item_tooltip`,
## `_item_label` and `_draw_pack_full` (2049-2189, 1036-1053), in `DepthChip`'s shape: `layout()` decides
## and returns data, `paint()` transcribes. EVERY NUMBER IS IN LEGACY'S AUTHORING CANVAS (`UiTheme.
## AUTHORED`, 640x360) and carried onto ours through `UiTheme.px`/`UiTheme.pt` at the point of use
## (D0290).
##
## Legacy's own rules, kept: the bar shows only the slots you carry (a trailing empty well reads as
## "broken, what goes here?"), with a floor of one; THE BAR IS A WINDOW ONTO THE PACK, NOT THE PACK, and
## the window is placed to contain the selection rather than assuming it does; the keybind digit follows
## the pack index and stops when the keys do; the chevron is a mark and not a count, because a bar that
## reports totals is on its way to being a second inventory.
##
## Reads `obs.pack` (pickup order, the sim's own), `obs.pack_selected`, `obs.pack_slots` (the cap),
## `obs.pack_bulk`/`pack_bulk_cap`. A machine item's name is its record's display name (data), a
## resource's its id with the underscores spaced and the first letter raised.

const SLOT: float = 30.0
const SLOT_GAP: float = 4.0
## Where the bottom furniture starts, as one definition: `bottom_furniture_fraction` is the last row
## that is still world, for anything outside the HUD that must not paint under the bar.
const HOTBAR_BAND_TOP: float = UiTheme.AUTHORED.y - 28.0 - SLOT - 7.0
const HOTBAR_BAND_H: float = SLOT + 14.0
const COUNT_SIZE: int = 11
const KEY_SIZE: int = 8
const LABEL_SIZE: int = 11
const TIP_NAME_SIZE: int = 11
const TIP_BODY_SIZE: int = 10
const TIP_WRAP: float = 200.0
const CHIP_TOP: float = 34.0        ## the PACK FULL chip's y, the ambient corner register under FORGED
const NO_POINTER := Vector2(-1.0, -1.0)


static func bottom_furniture_fraction() -> float:
	return HOTBAR_BAND_TOP / UiTheme.AUTHORED.y


## Human-readable name for a carried item.
static func item_label(item: StringName) -> String:
	var rec: Dictionary = MachinesRecords.RECORDS.get(String(item), {})
	if not rec.is_empty():
		return String(rec.get("display_name", String(item)))
	var s: String = String(item).replace("_", " ")
	return s.substr(0, 1).to_upper() + s.substr(1)


## Which pack index the first well shows: the window is centred on the selection and clamped to the
## pack, derived purely from `sel`. A selection past the tenth well used to draw ten wells and light none.
static func window_start(carried: int, n: int, sel: int) -> int:
	return clampi(sel - n / 2, 0, maxi(carried - n, 0))


## Everything the bar decides, as data; `{}` when there is nothing to draw. `pointer` is in our canvas
## px (`NO_POINTER` for none) and only the tooltip reads it.
static func layout(frame: Frame, font: Font, pointer: Vector2 = NO_POINTER) -> Dictionary:
	if frame == null or frame.obs == null or font == null:
		return {}
	var o: Interface.Observation = frame.obs
	var slots: Array[Dictionary] = o.pack
	if slots.is_empty():
		return {}   # an empty pack draws no bar (D0412): a lit empty well read as missing content
	var cap: int = maxi(1, o.pack_slots)
	var n: int = clampi(slots.size(), 1, cap)
	var sel: int = o.pack_selected
	var w0: int = window_start(slots.size(), n, sel)
	var total_w: float = float(n) * SLOT + float(n - 1) * SLOT_GAP
	var x0: float = (UiTheme.AUTHORED.x - total_w) * 0.5
	var y: float = HOTBAR_BAND_TOP + 7.0
	var wells: Array[Dictionary] = []
	var tooltip: Dictionary = {}
	var sel_lit: bool = false
	for k: int in n:
		var i: int = w0 + k
		var sx: float = x0 + float(k) * (SLOT + SLOT_GAP)
		var rect := Rect2(UiTheme.px(sx), UiTheme.px(y), UiTheme.px(SLOT), UiTheme.px(SLOT))
		var active: bool = i == sel
		sel_lit = sel_lit or active
		var well: Dictionary = {"rect": rect, "index": i, "active": active,
			"key": ("0" if i == 9 else str(i + 1)) if i < 10 else ""}
		if i < slots.size():
			well["item"] = slots[i]["item"]
			well["count"] = int(slots[i]["count"])
			if rect.has_point(pointer):
				tooltip = {"item": slots[i]["item"], "count": int(slots[i]["count"]),
					"anchor": Vector2(rect.get_center().x, rect.position.y)}
		wells.append(well)
	var backing := Rect2(UiTheme.px(x0 - 8.0), UiTheme.px(HOTBAR_BAND_TOP), UiTheme.px(total_w + 16.0), UiTheme.px(HOTBAR_BAND_H))
	var label: Dictionary = {}
	if sel >= w0 and sel < mini(w0 + n, slots.size()):
		var text: String = item_label(slots[sel]["item"])
		var lw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LABEL_SIZE)).x
		var lx: float = UiTheme.px(x0 + float(sel - w0) * (SLOT + SLOT_GAP)) + (UiTheme.px(SLOT) - lw) * 0.5
		var ly: float = UiTheme.px(y - 12.0)
		label = {"text": text, "at": Vector2(lx, ly),
			"plate": Rect2(lx - UiTheme.px(5.0), ly - UiTheme.px(11.0), lw + UiTheme.px(10.0), UiTheme.px(15.0))}
	return {"wells": wells, "backing": backing, "window": w0, "sel": sel, "sel_lit": sel_lit,
		"more_left": w0 > 0, "more_right": w0 + n < slots.size(),
		"mark_y": UiTheme.px(y + SLOT * 0.5), "label": label,
		"tooltip": tooltip_layout(font, tooltip) if not tooltip.is_empty() else {}}


## The hovered slot's tooltip: name and count, and one purpose line, clamped on-canvas above the slot.
static func tooltip_layout(font: Font, tip: Dictionary) -> Dictionary:
	var name_line: String = "%s  ×%d" % [item_label(tip["item"]), int(tip["count"])]
	var purpose: String = ItemLook.purpose(tip["item"])
	var wrap: float = UiTheme.px(TIP_WRAP)
	var name_w: float = font.get_string_size(name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(TIP_NAME_SIZE)).x
	var body: Vector2 = font.get_multiline_string_size(purpose, HORIZONTAL_ALIGNMENT_LEFT, wrap, UiTheme.pt(TIP_BODY_SIZE)) if purpose != "" else Vector2.ZERO
	var w: float = maxf(name_w, minf(body.x, wrap)) + UiTheme.px(18.0)
	var h: float = UiTheme.px(22.0) + (body.y + UiTheme.px(4.0) if purpose != "" else 0.0)
	var anchor: Vector2 = tip["anchor"]
	var origin := Vector2(clampf(anchor.x - w * 0.5, UiTheme.px(6.0), UiTheme.CANVAS.x - w - UiTheme.px(6.0)),
		maxf(anchor.y - h - UiTheme.px(6.0), UiTheme.px(6.0)))
	return {"rect": Rect2(origin, Vector2(w, h)), "name": name_line, "purpose": purpose, "wrap": wrap,
		"name_at": origin + Vector2(UiTheme.px(9.0), UiTheme.px(15.0)), "body_at": origin + Vector2(UiTheme.px(9.0), UiTheme.px(29.0))}


## The PACK FULL chip: `{}` while there is room.
static func pack_full_layout(frame: Frame, font: Font) -> Dictionary:
	if frame == null or frame.obs == null or font == null:
		return {}
	var o: Interface.Observation = frame.obs
	if o.pack_bulk_cap <= 0 or o.pack_bulk < o.pack_bulk_cap:
		return {}
	var label: String = "PACK FULL"
	var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(COUNT_SIZE)).x
	var w: float = lw + UiTheme.px(24.0)
	var chip := Rect2(UiTheme.CANVAS.x - w - UiTheme.px(10.0), UiTheme.px(CHIP_TOP), w, UiTheme.px(22.0))
	return {"chip": chip, "label": label, "at": chip.position + Vector2(UiTheme.px(10.0), UiTheme.px(15.0))}


static func _pointer(ci: CanvasItem) -> Vector2:
	var vp: Viewport = ci.get_viewport()
	return vp.get_mouse_position() if vp != null else NO_POINTER


static func paint(frame: Frame, ci: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(frame, font, _pointer(ci))
	if l.is_empty():
		return
	UiTheme.panel(ci, l["backing"])
	for w: Dictionary in l["wells"]:
		var r: Rect2 = w["rect"]
		if bool(w["active"]):
			ci.draw_rect(r.grow(UiTheme.px(2.0)), Color(UiTheme.UI_ACCENT.r, UiTheme.UI_ACCENT.g, UiTheme.UI_ACCENT.b, 0.18))
		ci.draw_rect(r, UiTheme.UI_SLOT)
		ci.draw_line(r.position + Vector2(1.0, 1.0), r.position + Vector2(r.size.x - 1.0, 1.0), UiTheme.UI_EDGE_HI, 1.0)
		ci.draw_rect(r, UiTheme.UI_ACCENT if bool(w["active"]) else UiTheme.UI_EDGE, false, 2.0 if bool(w["active"]) else 1.0)
		if String(w["key"]) != "":
			ci.draw_string(font, r.position + Vector2(UiTheme.px(2.0), UiTheme.px(9.0)), w["key"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(KEY_SIZE), UiTheme.UI_TEXT_FAINT)
		if w.has("item"):
			ItemLook.draw(ci, r.get_center() + Vector2(0.0, -UiTheme.px(1.0)), UiTheme.px(SLOT - 14.0), w["item"])
			var cnt: String = str(int(w["count"]))
			var cw: float = font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(COUNT_SIZE)).x
			ci.draw_rect(Rect2(r.end.x - cw - UiTheme.px(5.0), r.end.y - UiTheme.px(13.0), cw + UiTheme.px(4.0), UiTheme.px(12.0)), Color(0.03, 0.03, 0.05, 0.85))
			ci.draw_string(font, Vector2(r.end.x - cw - UiTheme.px(3.0), r.end.y - UiTheme.px(3.0)), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(COUNT_SIZE), UiTheme.UI_TEXT)
	var backing: Rect2 = l["backing"]
	if bool(l["more_left"]):
		_more_mark(ci, Vector2(backing.position.x - UiTheme.px(5.0), l["mark_y"]), -1.0)
	if bool(l["more_right"]):
		_more_mark(ci, Vector2(backing.end.x + UiTheme.px(5.0), l["mark_y"]), 1.0)
	var label: Dictionary = l["label"]
	if not label.is_empty():
		ci.draw_rect(label["plate"], Color(0.05, 0.06, 0.09, 0.88))
		ci.draw_string(font, label["at"], label["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LABEL_SIZE), UiTheme.UI_TEXT)
	var tip: Dictionary = l["tooltip"]
	if not tip.is_empty():
		var rect: Rect2 = tip["rect"]
		ci.draw_rect(rect, Color(UiTheme.UI_BG.r, UiTheme.UI_BG.g, UiTheme.UI_BG.b, 0.96))
		ci.draw_rect(rect, UiTheme.UI_EDGE, false, 1.0)
		ci.draw_rect(Rect2(rect.position, Vector2(UiTheme.px(2.0), rect.size.y)), Color(UiTheme.UI_EDGE_HI, 1.0))
		ci.draw_string(font, tip["name_at"], tip["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(TIP_NAME_SIZE), UiTheme.UI_TEXT)
		if String(tip["purpose"]) != "":
			ci.draw_multiline_string(font, tip["body_at"], tip["purpose"], HORIZONTAL_ALIGNMENT_LEFT, tip["wrap"], UiTheme.pt(TIP_BODY_SIZE), -1, Color(0.78, 0.74, 0.62))


## "There is more pack this way": a dim chevron pointing outward from the end of the bar.
static func _more_mark(ci: CanvasItem, at: Vector2, dir: float) -> void:
	var col := Color(UiTheme.UI_TEXT_DIM.r, UiTheme.UI_TEXT_DIM.g, UiTheme.UI_TEXT_DIM.b, 0.55)
	ci.draw_line(at + Vector2(UiTheme.px(-3.0) * dir, UiTheme.px(-5.0)), at + Vector2(UiTheme.px(2.0) * dir, 0.0), col, 1.5)
	ci.draw_line(at + Vector2(UiTheme.px(2.0) * dir, 0.0), at + Vector2(UiTheme.px(-3.0) * dir, UiTheme.px(5.0)), col, 1.5)


static func paint_pack_full(frame: Frame, ci: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = pack_full_layout(frame, font)
	if l.is_empty():
		return
	var chip: Rect2 = l["chip"]
	UiTheme.panel(ci, chip)
	ci.draw_rect(Rect2(chip.position.x, chip.position.y, 2.5, chip.size.y), UiTheme.UI_WARN)
	ci.draw_string(font, l["at"], l["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(COUNT_SIZE), Color(0.94, 0.64, 0.44))
