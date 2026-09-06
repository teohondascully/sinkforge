class_name FrameMeter
extends RefCounted

## THE WALL-CLOCK FRAME METER, opt-in with `--perf`. Reads the spacing between RENDERED frames (`_process`
## to `_process`), not between physics ticks -- physics runs at a fixed 60 Hz by construction, so its
## spacing measures the schedule, not the game. `Engine.get_frames_per_second()` reported 116-119 on a
## build the director felt at "20fps" (2026-09-04): the counter averages over a second and hides a stall
## every hub tick. What a hand feels is the p99 and the count of frames over budget, so those lead.
##
## Also splits the physics tick by whether the hub ran that tick (`HubTick.HUB_TICK_DIVISOR`), because
## the two populations differ by an order of magnitude and a single p50 hides the one that hitches.

const BUDGET_120_USEC: int = 8333
const BUDGET_60_USEC: int = 16667

var _frames: PackedInt64Array = PackedInt64Array()
var _hub: PackedInt64Array = PackedInt64Array()
var _quiet: PackedInt64Array = PackedInt64Array()
var _last_process_usec: int = -1
## The worst frames' context lines, appended by `note_slow` from the shell when a frame ran long.
var slow: PackedStringArray = PackedStringArray()
## A dropped frame at 60 Hz is what the hand feels, so that is the line (was 25 ms, which kept only the
## boot's shader compiles and missed every steady-state hitch -- D0414).
const SLOW_USEC: int = 16667
const SLOW_KEEP: int = 8
var last_frame_usec: int = 0
## The viewport whose render time is measured, when the shell hands one over (`measure_render`).
var _vp: RID = RID()


func note_process() -> void:
	var now: int = Time.get_ticks_usec()
	if _last_process_usec >= 0:
		last_frame_usec = now - _last_process_usec
		_frames.append(last_frame_usec)
	_last_process_usec = now


## True when the frame just closed ran past `SLOW_USEC`, so the shell can attach its context.
func last_was_slow() -> bool:
	return last_frame_usec > SLOW_USEC


func note_slow(context: String) -> void:
	if slow.size() < SLOW_KEEP:
		slow.append("SLOW %.1fms %s %s" % [_ms(last_frame_usec), engine_split(), context])


## Ask the renderer to time this viewport's frames, CPU and GPU, so a slow frame can be attributed to the
## script (process/physics) or to the draw (D0414: the painters' own total was under 2 ms in every slow
## frame the meter caught, so the cost was somewhere the painters could not see).
func measure_render(vp: RID) -> void:
	_vp = vp
	if _vp.is_valid():
		RenderingServer.viewport_set_measure_render_time(_vp, true)


var _pre_draw_usec: int = 0
## Wall time from the renderer's pre-draw to post-draw signal: the draw submit, and under vsync the wait
## for the display, which is the one phase neither the painters' clocks nor the physics clock can see.
## THE SEAT NODE forwards the two `RenderingServer` signals here (`Main._on_pre_draw/_on_post_draw`) --
## never a lambda of this RefCounted connected to the singleton: that Callable outlived the script
## language at exit and every perf run ended in "Godot quit unexpectedly" (four crash reports, 2026-09-06
## 15:12-15:14, `Callable::~Callable -> GDScriptInstance::~GDScriptInstance` on a dead mutex). A Node's
## own connections are dropped when the tree frees it.
var last_draw_usec: int = 0


func note_pre_draw() -> void:
	_pre_draw_usec = Time.get_ticks_usec()


func note_post_draw() -> void:
	last_draw_usec = Time.get_ticks_usec() - _pre_draw_usec


## The draw phase and what the renderer was handed: the pre-draw to post-draw wall time, the viewport's
## measured render CPU/GPU ms (GPU reads 0.0 under Metal: unsupported, not free), and the frame's draw
## calls and primitives. `Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS` were tried and dropped: they
## refresh once a second and read the same value across forty consecutive slow frames.
func engine_split() -> String:
	var line: String = "draw=%.1f" % _ms(last_draw_usec)
	if _vp.is_valid():
		line += " rcpu=%.1f rgpu=%.1f" % [RenderingServer.viewport_get_measured_render_time_cpu(_vp), RenderingServer.viewport_get_measured_render_time_gpu(_vp)]
	line += " calls=%d prims=%d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
	return line


func note_physics(usec: int, hub: bool) -> void:
	if hub:
		_hub.append(usec)
	else:
		_quiet.append(usec)


func reset() -> void:
	_frames.clear()
	_hub.clear()
	_quiet.clear()
	slow.clear()


## One line: render-frame p50/p99/max, the over-budget counts at 120 and 60 Hz, and the physics split.
func report() -> String:
	if _frames.size() < 2:
		return "PERF frames=%d (too few)" % _frames.size()
	var f: PackedInt64Array = _frames.duplicate()
	f.sort()
	var over120: int = 0
	var over60: int = 0
	for d: int in f:
		if d > BUDGET_120_USEC:
			over120 += 1
		if d > BUDGET_60_USEC:
			over60 += 1
	var span_usec: int = 0
	for d: int in f:
		span_usec += d
	var fps: float = float(f.size()) * 1e6 / float(maxi(span_usec, 1))
	return "PERF frames=%d fps_wall=%.1f frame p50=%.2fms p99=%.2fms max=%.2fms over8.3ms=%d over16.7ms=%d | physics hub p50=%.2fms p99=%.2fms n=%d | quiet p50=%.2fms p99=%.2fms n=%d" % [
		f.size(), fps, _ms(_quantile(f, 0.5)), _ms(_quantile(f, 0.99)), _ms(f[f.size() - 1]), over120, over60,
		_ms(_quantile_of(_hub, 0.5)), _ms(_quantile_of(_hub, 0.99)), _hub.size(),
		_ms(_quantile_of(_quiet, 0.5)), _ms(_quantile_of(_quiet, 0.99)), _quiet.size()]


static func _quantile_of(samples: PackedInt64Array, q: float) -> int:
	if samples.is_empty():
		return 0
	var s: PackedInt64Array = samples.duplicate()
	s.sort()
	return _quantile(s, q)


static func _quantile(sorted: PackedInt64Array, q: float) -> int:
	var i: int = clampi(int(floor(q * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return sorted[i]


static func _ms(usec: int) -> float:
	return float(usec) / 1000.0
