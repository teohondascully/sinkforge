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
## THE SLOWEST SINGLE DRAW EACH PAINTER HAD, worst first -- the statistic `report` and `frame_report`
## between them cannot produce (D0552). One frame's snapshot and a per-tick average both describe a
## painter that never spikes exactly as they describe one that does.
static func peaks(layers: Array[PaintLayer], top: int = 4) -> String:
	var rows: Array[Dictionary] = []
	for layer: PaintLayer in layers:
		if layer.max_draw_usec > 0:
			rows.append({"label": layer.label, "usec": layer.max_draw_usec})
	if rows.is_empty():
		return ""
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["usec"] > b["usec"])
	var parts: PackedStringArray = PackedStringArray()
	for i: int in mini(top, rows.size()):
		parts.append("%s=%.2fms" % [rows[i]["label"], float(rows[i]["usec"]) / 1000.0])
	# THE SUM IS OF INDEPENDENT MAXIMA AND IS NOT A FRAME ANYONE SAT THROUGH. D0541 caught exactly this
	# join one layer up -- a peak duration and a peak area maximised separately and then reported as one
	# event -- so the name says what it is rather than inviting the same reading. It is an upper bound on
	# a worst frame, useful only as that.
	var bound: int = 0
	for r: Dictionary in rows:
		bound += int(r["usec"])
	return " | peak_draw " + " ".join(parts) + " (sum_of_separate_peaks=%.2fms, not one frame)" % (
		float(bound) / 1000.0)


static func frame_report(layers: Array[PaintLayer], hud: Array[PaintLayer], refresh_usec: int,
		observe_usec: int, iface: Interface, ticks: int) -> String:
	var rebuilds: String = ""
	if iface != null:
		rebuilds = " plane_rebuilds=%d hub_rebuilds=%d /%d ticks" % [iface.plane_rebuilds(), iface.hub_rebuilds(), ticks]
	var chips: String = ""
	if not hud.is_empty():
		chips = " | hud " + report(hud)
	# THE REDRAWS ACTUALLY ISSUED against the redraws a queue-everything coordinator would have issued
	# (D0531). It cannot be read off the costs above: a layer whose redraw was skipped still reports what
	# it cost the last time it DID draw, which is the honest answer to a different question.
	var queued: int = 0
	# AND THE PAINTER CPU THAT ACTUALLY BOUGHT, per rendered tick, accumulated over the whole run. The
	# per-frame costs ranked above cannot answer it: a skipped layer reports the last frame it DID draw.
	# It is also the one painter number that does not move when the display paces the process, which the
	# frame rate does by a factor of four (D0527, D0531).
	var drawn_usec: int = 0
	for layer: PaintLayer in layers:
		queued += layer.queues
		drawn_usec += layer.sum_draw_usec
	return "%s | refresh=%.2fms (observe=%.2fms) queued=%d/%d drawn=%.3fms/tick%s%s" % [report(layers),
		float(refresh_usec) / 1000.0, float(observe_usec) / 1000.0,
		queued, ticks * layers.size(), float(drawn_usec) / 1000.0 / float(maxi(ticks, 1)),
		rebuilds, chips] + peaks(layers)


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
