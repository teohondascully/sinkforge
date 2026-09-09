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


static func reset() -> void:
	slowest = {}
	_event = {}
	prep_by_reason = {}
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
		float(prep_tick_max_usec) / 1000.0] + reason_line()


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
		parts.append("%s=%.3fms/%dcb/%dcells" % [r, float(d["usec"]) / 1000.0, d["callbacks"], d["cells"]])
	return " | by_reason " + " ".join(parts)
