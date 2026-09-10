class_name BakeCost
extends RefCounted

## THE TERRAIN BAKE'S PHASE CLOCKS: preparation and upload, counted separately, over a whole window.
##
## `docs/PERF_PLAN.md`'s first remaining-work item asks for exactly this split -- "separate shader
## startup, terrain preparation, upload, dynamic painters and draw time" -- and until it existed the
## three phases were one number nobody could act on. `view/draw_cost.gd` already ranks the DYNAMIC
## painters, and `shell/frame_meter.gd` already times the draw phase and the frame; neither can see the
## bake, because a chunk paints inside a `CanvasItem._draw` callback that the frame meter's `draw=` field
## does not attribute (a 417 ms mining frame read `draw=0.8 rcpu=0.1`, 2026-09-07). So the bake is a hole
## in the middle of the budget, and it is the hole the director's freeze lived in.
##
## PREPARATION is the CPU that turns an observation into pixels and bytes: the baked painters, the
## grammar map's fill, and (on the shader path) the data image's build. UPLOAD is the CPU handed to the
## driver to move a finished image to the GPU: `ImageTexture.update` and the first `create_from_image`.
## The two are split because they answer different questions and legacy already paid for confusing them
## -- `docs/PERF_PLAN.md`'s rule 5: "a dirty-region fast lane is capped by its whole-buffer upload.
## Measure `set_data`/`update` separately; the per-cell ratio RISES as the region shrinks."
##
## Static because there is exactly one bake in a process and the reader (the seat's meter tick) is three
## layers away from the writer, with no path between them that does not thread an instrument through the
## picture's own constructors. `reset()` closes a window; a suite calls it first so it measures its own
## work and not the boot's.

## The two phases, as one enum, because they are stamped by one function: written as two near-identical
## `note_prep`/`note_upload` first, which the duplication gate correctly refused -- they differed only in
## which three counters they touched, and a pair like that drifts the moment one of them learns something.
enum { PREP, UPLOAD }

static var prep_usec: int = 0
static var prep_chunks: int = 0
static var prep_cells: int = 0
static var upload_usec: int = 0
static var uploads: int = 0
static var upload_cells: int = 0
## Peak aggregate preparation in one physics tick, not a window average or single chunk.
static var prep_tick_max_cells: int = 0
static var prep_tick_max_usec: int = 0
static var _tick: int = -1
static var _tick_cells: int = 0
static var _tick_usec: int = 0
static var capture_bursts: bool = false
static var slowest: Dictionary = {}
static var _event: Dictionary = {}
## PREPARATION CHARGED PER SCHEDULING REASON OVER THE WHOLE WINDOW. `slowest` says what one burst was
## made of; this says what the window was made of, and they answer different questions. A treatment that
## defers optional work has to be judged on the second: one 9 ms margin burst could be the only margin
## work in five seconds, or one of forty. D0541 is explicit that two independently-aggregated extrema
## must not be read as one event, and a per-reason total is the statistic that has no such join in it.
static var prep_by_reason: Dictionary = {}
## REGION SETUP, THE PART OF PREPARATION SPENT OBSERVING RATHER THAN PAINTING (D0545 instrument).
##
## A SUBSET OF `prep_usec`, NOT A FOURTH PHASE -- the PREP clock wraps the whole callback, observation
## included, so these two must never be added together. Named `prep_setup_*` so the containment is in the
## name: whatever a reader does with it, `prep_setup_usec <= prep_usec` is an invariant a suite pins.
##
## It exists because preparation's us/cell cannot answer item 4's third case. `BakeChunk._paint` charges
## the clock over the PAINTED rect, while `WorldView.observe_rect` observes that rect grown by
## `WINDOW_MARGIN_CELLS` (9) on all four sides and builds both planes. The observed area is therefore
## 1.33x the painted one for the per-frame view, 4.5x for a whole 16-cell chunk and 7-30x for the small
## partial rects a dig plans -- so a per-cell rate charged over painted cells rises as the rect shrinks
## whether or not a dug cell is dearer to shade. `prep_setup_cells` records the observed area so that
## ratio is MEASURED here rather than reasoned about from the source.
static var prep_setup_usec: int = 0
static var prep_setup_cells: int = 0
static var prep_setups: int = 0


## One event of `phase`, timed from `began` to now, over `n` terrain cells (preparation) or texels
## (upload). The clock is read here rather than at the call site so a stamp cannot be half-applied.
static func note(phase: int, began: int, n: int, planned: int = -1, reason: String = "unknown") -> void:
	var spent: int = Time.get_ticks_usec() - began
	if phase == PREP:
		if capture_bursts:
			record_preparation(Engine.get_physics_frames(), Engine.get_frames_drawn(), planned, spent, n, reason)
		var tick: int = Engine.get_physics_frames()
		if tick != _tick:
			_tick = tick
			_tick_cells = 0
			_tick_usec = 0
		var part: Dictionary = prep_by_reason.get(reason, {"usec": 0, "cells": 0, "callbacks": 0})
		part["usec"] += spent
		part["cells"] += n
		part["callbacks"] += 1
		prep_by_reason[reason] = part
		_tick_cells += n
		_tick_usec += spent
		prep_tick_max_cells = maxi(prep_tick_max_cells, _tick_cells)
		prep_tick_max_usec = maxi(prep_tick_max_usec, _tick_usec)
		prep_usec += spent
		prep_chunks += 1
		prep_cells += n
	else:
		upload_usec += spent
		uploads += 1
		upload_cells += n


## One measured callback. Group by execution identity; retain the complete slowest event, not
## unrelated extrema. Called only in profiling mode; explicit measurements also permit deterministic tests.
static func record_preparation(physics: int, render: int, planned: int, usec: int, cells: int, reason: String) -> void:
	if _event.is_empty() or _event["physics"] != physics or _event["render"] != render:
		_event = {"physics": physics, "render": render, "planned": [], "usec": 0,
			"cells": 0, "callbacks": 0, "reasons": {}}
	if not _event["planned"].has(planned):
		_event["planned"].append(planned)
	_event["usec"] += usec
	_event["cells"] += cells
	_event["callbacks"] += 1
	var part: Dictionary = _event["reasons"].get(reason, {"usec": 0, "cells": 0, "callbacks": 0})
	part["usec"] += usec
	part["cells"] += cells
	part["callbacks"] += 1
	_event["reasons"][reason] = part
	if _event["usec"] > int(slowest.get("usec", -1)):
		slowest = _event.duplicate(true)


## THE SOLID CELLS ONE CALLBACK PAINTED, charged to its reason (D0546). Counted and charged AFTER the PREP
## clock has closed, and only while profiling, because the count is an O(cells) walk of the observation and
## an instrument that runs inside the window it measures reports its own cost as the subject's.
##
## It exists to settle what D0545 left open. Preparation's us/cell is charged over PAINTED cells, and dig
## partials cost 14.4 against margin's 8.9 -- a 5.5 us gap of which region setup explains about 17%. The
## painters' real unit is the SOLID cell (`TerrainPainter.cell_fill` -> `RockTone.shade` probes neighbours
## per solid cell and skips air), so if density is the rest of that gap, the per-solid-cell costs converge.
## If they do not, the gap is something else and this says so instead of confirming a guess.
## `dilated` is `cells.grow(RockTone.FORM_REACH)`'s area -- the span `RockNeighborhood` actually builds
## and scans three times, once per callback (`terrain_painter.gd:69`). It is arithmetic on a rect, not a
## walk, and it is the denominator the painters' real cost is proportional to.
static func note_density(reason: String, solid: int, dilated: int) -> void:
	var part: Dictionary = prep_by_reason.get(reason,
		{"usec": 0, "cells": 0, "callbacks": 0, "solid": 0, "dilated": 0})
	part["solid"] = int(part.get("solid", 0)) + solid
	part["dilated"] = int(part.get("dilated", 0)) + dilated
	prep_by_reason[reason] = part


## HOW MUCH OF THE DIG'S DILATED WORK IS THE CHUNK SPLIT'S FAULT (D0548 headroom probe).
##
## `BakeWindow.plan_tick` computes ONE `dig_rect` for the tick and then `partials_of` cuts it along chunk
## boundaries, because a chunk is the paint unit -- each is its own `CanvasItem` with its own `_draw`. Every
## piece then builds its own `RockNeighborhood` over `cells.grow(FORM_REACH)` (`terrain_painter.gd:69`), and
## adjacent pieces' halos OVERLAP across every shared boundary. D0546 showed cost tracks the dilated span,
## so that overlap is paid work that draws nothing.
##
## `paid` is the sum of the pieces' dilated spans; `shared` is the dilated span of their union -- what ONE
## neighbourhood covering the whole dig rect would need. The ratio is the ceiling on any sharing treatment
## and nothing more: it says what could be saved, never that saving it is free or correct.
static var dig_paid_dilated: int = 0
static var dig_shared_dilated: int = 0
static var dig_split_ticks: int = 0


static func note_dig_span(paid: int, shared: int) -> void:
	dig_paid_dilated += paid
	dig_shared_dilated += shared
	dig_split_ticks += 1


## One region setup, timed from `began` to now, over the `observed` cells the envelope actually covered.
## Charged INSIDE a PREP callback, so it is a slice of `prep_usec` and never an addition to it.
static func note_setup(began: int, observed: int) -> void:
	prep_setup_usec += Time.get_ticks_usec() - began
	prep_setup_cells += observed
	prep_setups += 1


static func reset() -> void:
	slowest = {}
	_event = {}
	prep_by_reason = {}
	prep_setup_usec = 0
	prep_setup_cells = 0
	prep_setups = 0
	dig_paid_dilated = 0
	dig_shared_dilated = 0
	dig_split_ticks = 0
	_tick = -1
	_tick_cells = 0
	_tick_usec = 0
	prep_tick_max_cells = 0
	prep_tick_max_usec = 0
	prep_usec = 0
	prep_chunks = 0
	prep_cells = 0
	upload_usec = 0
	uploads = 0
	upload_cells = 0


## The window's line: both phases per rendered tick, and preparation's per-cell cost -- which is the
## number that survives a change of workload, where a per-tick total does not. `docs/PERF_PLAN.md`'s
## rule 6: "extent is not cost. Gate on per-cell us, not on cell count."
static func report(ticks: int) -> String:
	var t: float = float(maxi(ticks, 1))
	return "bake prep=%.3fms/tick chunks=%d cells=%d %.2fus/cell | upload=%.3fms/tick n=%d cells=%d %.3fus/cell | peak_tick cells=%d prep=%.3fms" % [
		float(prep_usec) / 1000.0 / t, prep_chunks, prep_cells,
		float(prep_usec) / float(maxi(prep_cells, 1)),
		float(upload_usec) / 1000.0 / t, uploads, upload_cells,
		float(upload_usec) / float(maxi(upload_cells, 1)), prep_tick_max_cells,
		float(prep_tick_max_usec) / 1000.0] + setup_line() + split_line() + reason_line()


## The share of preparation that was region setup, and the area that setup actually observed against the
## area the callbacks painted. Both denominators are printed because the whole point of the line is that
## they differ: `obs/painted` is the multiplier a per-cell rate is silently carrying.
static func setup_line() -> String:
	if prep_setups == 0:
		return ""
	return " | setup=%.3fms/%dcb %.1f%%ofprep obs_cells=%d painted_cells=%d obs/painted=%.2fx" % [
		float(prep_setup_usec) / 1000.0, prep_setups,
		100.0 * float(prep_setup_usec) / float(maxi(prep_usec, 1)),
		prep_setup_cells, prep_cells,
		float(prep_setup_cells) / float(maxi(prep_cells, 1))]


## What the chunk split costs the dig, as a ceiling on sharing: paid against shared dilated span.
static func split_line() -> String:
	if dig_split_ticks == 0:
		return ""
	return " | dig_split ticks=%d paid_dilated=%d shared_dilated=%d overlap=%.1f%%" % [
		dig_split_ticks, dig_paid_dilated, dig_shared_dilated,
		100.0 * float(dig_paid_dilated - dig_shared_dilated) / float(maxi(dig_paid_dilated, 1))]


## The window's preparation split by why each chunk was selected, slowest reason first. Empty when
## nothing was prepared; `unknown` when the run is not capturing attribution.
static func reason_line() -> String:
	if prep_by_reason.is_empty():
		return ""
	var names: Array = prep_by_reason.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(prep_by_reason[a]["usec"]) > int(prep_by_reason[b]["usec"]))
	var parts: PackedStringArray = PackedStringArray()
	for r: String in names:
		var d: Dictionary = prep_by_reason[r]
		var solid: int = int(d.get("solid", 0))
		var dil: int = int(d.get("dilated", 0))
		parts.append("%s=%.3fms/%dcb/%dcells/%dsolid/%ddilated %.1fus_cell %sus_solid %sus_dilated" % [
			r, float(d["usec"]) / 1000.0, d["callbacks"], d["cells"], solid, dil,
			float(d["usec"]) / float(maxi(int(d["cells"]), 1)),
			"%.1f" % (float(d["usec"]) / float(solid)) if solid > 0 else "n/a",
			"%.2f" % (float(d["usec"]) / float(dil)) if dil > 0 else "n/a"])
	return " | by_reason " + " ".join(parts)
