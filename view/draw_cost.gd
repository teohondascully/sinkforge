class_name DrawCost
extends RefCounted

## THE FRAME-BUDGET INSTRUMENT. Split out of `view/world_view.gd` (D0336) when that file reached 402 lines
## against `docs/QUALITY.md` §2's 400 cap — and split rather than trimmed, which is the rule that exists
## because `sim/body/body.gd` sat at exactly 400 for three commits running.
##
## The seam is real and not just line arithmetic: `WorldView` SEQUENCES a render, while this decides how
## to name and rank what that render cost. Nothing here feeds the picture — it reads timings a layer has
## already stamped and formats them — so it cannot move a pixel or a determinism hash.
##
## **IT EXISTS BECAUSE A TOTAL CANNOT BE OPTIMISED AGAINST.** Legacy learned this the expensive way and
## wrote it down in `legacy/tools/profile_frame.gd:3`:
##
##   > "check_frametime says a frame costs 39.59ms during a dig against an 8.33ms budget. It does not say
##   > WHY, and the project has never had a tool that does. […] So every optimisation decision so far has
##   > been taken against a total, which is how you end up tuning the wrong thing confidently."
##
## The first report this produced attributed 41.47 ms of a 54.23 ms frame to one painter, which is the
## whole argument for building it before touching anything.

## The 120 Hz frame budget, in milliseconds. Written as the division rather than as 8.33 so the number and
## the rate cannot drift apart, matching `legacy/tools/check_frametime.gd:91`'s own `1000.0 / 120.0`.
const BUDGET_MS: float = 1000.0 / 120.0


## Per-painter draw cost for the last rendered frame, slowest first, as one printable line.
##
## Sorted rather than listed in mount order because the only question it answers is "what do I fix first".
## Reads `last_draw_usec`, which each layer stamps at the end of its own `_draw` — so the numbers describe
## the last frame Godot actually DREW, not the last `refresh()`. A layer whose redraw Godot coalesced away
## reports its previous cost, which is the honest answer rather than a zero.
static func report(layers: Array[PaintLayer]) -> String:
	var rows: Array = []
	var total: int = 0
	for layer: PaintLayer in layers:
		rows.append({"label": layer.label, "usec": layer.last_draw_usec})
		total += layer.last_draw_usec
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["usec"] > b["usec"])
	var parts: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		parts.append("%s=%.2fms" % [r["label"], float(r["usec"]) / 1000.0])
	return "painters total=%.2fms (budget %.2fms at 120Hz) -- %s" % [
		float(total) / 1000.0, BUDGET_MS, " ".join(parts)]


## The whole frame's line: the world painters ranked, the refresh and observe cost, the two plane caches'
## rebuild counts against the ticks drawn, and the HUD chips ranked -- a budget that left the HUD out was
## measuring part of the frame (D0390).
static func frame_report(layers: Array[PaintLayer], hud: Array[PaintLayer], refresh_usec: int,
		observe_usec: int, iface: Interface, ticks: int) -> String:
	var rebuilds: String = ""
	if iface != null:
		rebuilds = " plane_rebuilds=%d hub_rebuilds=%d /%d ticks" % [iface.plane_rebuilds(), iface.hub_rebuilds(), ticks]
	var chips: String = ""
	if not hud.is_empty():
		chips = " | hud " + report(hud)
	return "%s | refresh=%.2fms (observe=%.2fms)%s%s" % [report(layers),
		float(refresh_usec) / 1000.0, float(observe_usec) / 1000.0, rebuilds, chips]


## The painter's own name, for the report. **THE METHOD NAME ALONE IS NOT AN IDENTIFIER**: four painters
## on this stack expose `paint` and two expose `paint_frame`, so a report keyed on the method prints
## `paint=1.40ms paint=0.65ms` and names nothing — which is the same blindness as reporting a total, one
## level down. The script's own file stem separates them, so a row points at exactly one file.
static func label_for(paint: Callable) -> StringName:
	var method: String = String(paint.get_method())
	var obj: Object = paint.get_object()
	var stem: String = ""
	if obj != null:
		# A static-function Callable's object IS the GDScript resource, so its path names the painter's
		# file; a stateful painter's object is the instance, whose script gives the same path.
		var script: Script = obj as Script
		if script == null:
			script = obj.get_script() as Script
		if script != null and script.resource_path != "":
			stem = script.resource_path.get_file().get_basename()
	if stem == "":
		stem = obj.get_class() if obj != null else "lambda"
	return StringName(stem if method == "" else "%s.%s" % [stem, method])


## THE ABLATION SWITCH (D0418): hide every layer whose cost-report label starts with one of `stems`, and
## `post` for the lens. Returns the labels it hid, so the seat can print what the run was WITHOUT. The
## frame meter can clock the draw phase but not the GPU; removing one full-screen pass at a time and
## reading the frame is the only profile the seat can run.
## Reads the view's own children: every world painter is a `PaintLayer` mounted directly on the view
## (the HUD's chips hang off the HUD layer and are not reached), and the lens is its `PostFxLayer`.
static func mute(view: Node, stems: PackedStringArray) -> PackedStringArray:
	var hid: PackedStringArray = PackedStringArray()
	for child: Node in view.get_children():
		var layer: PaintLayer = child as PaintLayer
		if layer != null:
			for stem: String in stems:
				if String(layer.label).begins_with(stem):
					layer.visible = false
					hid.append(String(layer.label))
					break
		elif child is PostFxLayer and stems.has("post"):
			(child as CanvasLayer).visible = false   # the lens is a CanvasLayer, not a CanvasItem
			hid.append("post")
	return hid
