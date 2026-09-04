class_name MachineLabels
extends RefCounted

## THE NAMEPLATES (A' step 6c, D0364): legacy `scenes/machine_view.gd`'s `_plan_machine_labels` and
## `_draw_machine_label`, laid out for the whole frame rather than one machine at a time, because three
## plates centred on adjacent cells overlap into garbage and a machine cannot see its neighbours.
##
## Runs collapse: a row of contiguous machines with the same name is labelled once, as `HOPPER ×3` --
## measured over EVERY named machine, because the count is a statement about the factory, not about where
## the body happens to stand; visibility decides only where a plate is drawn. What is left is shelf-packed
## left to right, dropping to a second row when a plate would land on the one before it; the aimed
## machine is packed first, so pointing at something always names it.
##
## Sizes are legacy's screen pixels at its 1.0 zoom; the painter draws them under a 0.5 transform, the
## fine-detail rule (a 32 px cell became 16).

const FONT_SIZE: int = 8
const HEIGHT: float = 11.0
const SHELVES: int = 2          ## two rows of plates and no more: a third collides with the machine one cell up
const SHELF_H: float = 12.0
const PLATE := Color(0.04, 0.05, 0.08, 0.82)
const INK := Color(0.86, 0.90, 0.98)


## The frame's plan: cell -> {text, shelf, cx, w}. `named` is cell -> upper-case name for every machine,
## `shown` the cells whose plate may draw, `aim` the aimed logic cell (or (-1,-1)). Widths in legacy px.
static func plan(named: Dictionary, shown: Dictionary, aim: Vector2i, font: Font, cell_px: float) -> Dictionary:
	var runs: Array[Dictionary] = []
	for key: Variant in named:
		var c: Vector2i = key
		if named.get(c - Vector2i(1, 0), "") == named[c]:
			continue                          # mid-run: the westmost machine owns the plate for the run
		var n: int = 1
		while named.get(c + Vector2i(n, 0), "") == named[c]:
			n += 1
		var lo: int = -1
		var hi: int = -1
		for k: int in n:
			if shown.has(Vector2i(c.x + k, c.y)):
				if lo < 0:
					lo = c.x + k
				hi = c.x + k
		if lo < 0:
			continue                          # a run with nothing visible in it wants no plate
		var text: String = String(named[c]) if n == 1 else "%s ×%d" % [named[c], n]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 6.0
		runs.append({"cell": Vector2i(lo, c.y), "row": c.y, "x0": c.x, "text": text, "w": w, "lo": lo, "hi": hi,
			"aimed": 0 if (aim.y == c.y and aim.x >= c.x and aim.x < c.x + n) else 1})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["aimed"]) != int(b["aimed"]):
			return int(a["aimed"]) < int(b["aimed"])
		if int(a["row"]) != int(b["row"]):
			return int(a["row"]) < int(b["row"])
		return int(a["x0"]) < int(b["x0"]))
	var out: Dictionary = {}
	var claimed: Dictionary = {}              # "row:shelf" -> the x (legacy px) this shelf is occupied up to
	for r: Dictionary in runs:
		var w2: float = float(r["w"])
		# The plate hangs over the part of the run you can see, in legacy px (world px × 2).
		var cx: float = (float(int(r["lo"])) + float(int(r["hi"]) - int(r["lo"]) + 1) * 0.5) * cell_px * 2.0
		for shelf: int in SHELVES:
			var slot: String = "%d:%d" % [int(r["row"]), shelf]
			if cx - w2 * 0.5 < float(claimed.get(slot, -1.0e9)):
				continue
			claimed[slot] = cx + w2 * 0.5 + 2.0
			out[r["cell"]] = {"text": r["text"], "shelf": shelf, "cx": cx, "w": w2}
			break
	return out


## One plate, in legacy px under the painter's 0.5 transform: `top_px` is the machine's top edge in
## legacy px (world y × 2).
static func draw(ci: CanvasItem, font: Font, entry: Dictionary, top_px: float) -> void:
	var w: float = float(entry["w"])
	var left: float = float(entry["cx"]) - w * 0.5
	var top: float = top_px - HEIGHT - float(int(entry["shelf"])) * SHELF_H
	ci.draw_rect(Rect2(left, top, w, HEIGHT), PLATE)
	ci.draw_string(font, Vector2(left + 3.0, top + 8.5), String(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
