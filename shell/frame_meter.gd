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

## THE HOST-SPEED CONTROL, sampled beside every frame time and reported in the same line.
##
## A fixed-work integer loop: no allocation, no draw call, no engine call but the two clock reads. Its
## cost is a property of the core this thread got and of nothing in the game, so when its median moves
## between two windows those two windows' frame numbers are NOT comparable. That is not a hypothetical:
## D0527 classified 72 still frames by a draw-free loop and found every painter, every HUD chip and the
## sim-side `observe` slower by the SAME ~3x factor in the same frames -- the host, not a painter. Three
## sets of numbers were voided for want of this line, so the control now travels INSIDE the measurement
## rather than being reconstructed afterwards from a suspicion.
##
## `CAL_ITERS` and `CAL_EVERY` are set together against the 1 us clock. At 600 iterations the loop cost
## 14-26 us, where a single tick of quantisation is 4-7% and the fixture read 1.21x of drift between two
## windows that were probably identical -- a control whose own noise reaches the threshold it guards is
## not a control. At 2400 it costs ~60 us, so quantisation is under 2%; sampling one frame in four keeps
## its share of a 400 fps frame near half a percent, and still leaves hundreds of samples in a window.
const CAL_ITERS: int = 2400
const CAL_EVERY: int = 4
var _cal: PackedInt64Array = PackedInt64Array()
## The loop's own result, kept so nothing about the arithmetic is unobservable and can be reasoned away.
var cal_sink: int = 0


func note_process() -> void:
	var now: int = Time.get_ticks_usec()
	if _last_process_usec >= 0:
		last_frame_usec = now - _last_process_usec
		_frames.append(last_frame_usec)
		# SAMPLED WITH THE FRAME IT DESCRIBES, not with the call. The first `_process` closes no frame --
		# there is nothing before it to measure against -- so a focus sample taken there has no frame to
		# belong to, and `focus` was reported over a denominator one short of its numerator: a 15-frame
		# window read **1.07**, a share of frames larger than all of them. It is 1/n, so a 600-frame
		# window was inflated by 0.17% and a run at a true 0.9483 could read 0.95 and clear the fixture's
		# guard. The guard is what stands between this programme and another set of withdrawn numbers.
		if DisplayServer.window_is_focused():
			_focused += 1
	_last_process_usec = now
	_note_calibration()


## One sample of the fixed-work loop. Timed around the loop alone -- the frame's own spacing is already
## recorded above, so this pays only its own cost and never enters `_frames`.
func _note_calibration() -> void:
	if _frames.size() % CAL_EVERY != 0:
		return
	var began: int = Time.get_ticks_usec()
	var x: int = 0x9E3779B9
	for _i: int in CAL_ITERS:
		x = (x * 1103515245 + 12345) & 0x7FFFFFFF
		x = x ^ (x >> 7)
	cal_sink = x
	_cal.append(Time.get_ticks_usec() - began)


## The control's median and spread for the window just closed, in microseconds, plus the ratio of its
## p99 to its p50 -- the one number that says whether the host held still while the window ran.
func calibration() -> String:
	if _cal.is_empty():
		return "cal n=0"
	var c: PackedInt64Array = _cal.duplicate()
	c.sort()
	var p50: int = _quantile(c, 0.5)
	var p99: int = _quantile(c, 0.99)
	return "cal p50=%dus p99=%dus max=%dus spread=%.2f n=%d" % [p50, p99, c[c.size() - 1],
		float(p99) / float(maxi(p50, 1)), c.size()]


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
	_draws.append(last_draw_usec)
	# SPLIT BY WHETHER TERRAIN WAS PAINTED SINCE THE LAST FRAME CLOSED. Tagged against the previous
	# post-draw, NOT against this frame's own pre-draw: `BakeChunk.paint` runs in the engine's queued-
	# redraw flush, which happens BEFORE `frame_pre_draw` fires, so a pre-to-post comparison read zero
	# baking frames in every window of a dig run -- a split that could not register its own subject.
	if BakeCost.prep_chunks > _pre_draw_chunks:
		_pre_draw_chunks = BakeCost.prep_chunks
		_draws_baking.append(last_draw_usec)
	else:
		_draws_quiet.append(last_draw_usec)


## Every frame's draw phase, not just the worst eight. The window report needs the median: a dig window
## and a fall window carried the SAME painter CPU per tick (2.49 vs 2.40 ms) and the same physics, and
## ran at 114 and 510 frames a second. The difference had to be in a phase nothing was ranking, and the
## draw phase was the only one left unmeasured across the whole population rather than at its tail.
var _draws: PackedInt64Array = PackedInt64Array()
## The same population split in two: frames that painted terrain chunks, and frames that did not. The
## baseline made the question unavoidable -- `dig` and `fall` carry the same painter CPU per tick and the
## same physics tick, and run at 115 and 510 frames a second, with the draw phase at 4.40 ms against 1.33.
## A median over both populations at once cannot say whether the bake's own render is what costs that.
var _draws_baking: PackedInt64Array = PackedInt64Array()
var _draws_quiet: PackedInt64Array = PackedInt64Array()
var _pre_draw_chunks: int = 0
## HOW MANY OF THE WINDOW'S FRAMES WERE DRAWN INTO A FOCUSED WINDOW. The second control, and it exists
## because the first one could not see this: three runs of the identical `dig` workload, with the CPU
## control steady, reported the draw phase at 4.40, 1.31 and 0.55 ms and the frame rate at 115, 507 and
## 134 a second. The variable was the compositor -- whether this window was frontmost, occluded behind
## the director's own work, or being handed the front back by the fixture's focus custodian. macOS stops
## presenting what nobody can see, and the draw phase is where that shows up. So a frame number is only
## comparable with another frame number taken in the SAME window regime, and this is the field that says
## which regime a run was in. `[[the-human-is-inside-the-measurement]]`.
var _focused: int = 0


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
	_cal.clear()
	_draws.clear()
	_draws_baking.clear()
	_draws_quiet.clear()
	_focused = 0
	slow.clear()


## THE PRESENTATION REGIME THIS WINDOW RAN IN: whether the swapchain made the process wait, and what it
## was waiting for. The THIRD control, and it exists for the same reason as `_focused` -- a variable that
## lives outside the game and changes every frame number in the line beside it.
##
## `--disable-vsync --max-fps 0` lets this app produce ~400 frames a second against a 120 Hz display, so
## it blocks in `RenderingServer.draw` on a drawable that does not exist yet, and that block is counted in
## `draw` and in the frame's own spacing. Measured on the `still` workload, frontmost, one variable (D0555):
## the draw p99 is 0.74-2.48 ms at any cap up to 120 and 8.24-8.51 ms at a cap of 150 -- a step at the
## display's rate whose height is one 120 Hz slot. That wait is SLACK, not cost, and counting it as cost
## made a still frame look as expensive as a digging one.
##
## The number it wrecks is the RATE. A capped run and an uncapped run drop about the SAME NUMBER of frames
## over 16.7 ms (dig: 28-30 a window vsynced, 22-35 unvsynced) over populations of 597 and 1598, so the
## fraction moved 2.5-4x while nothing about the game changed. `over8.3ms=` and `over16.7ms=` may only be
## compared between windows this field agrees on. `[[read-the-count-not-the-rate]]`.
func presentation() -> String:
	var mode: int = DisplayServer.window_get_vsync_mode()
	var hz: float = DisplayServer.screen_get_refresh_rate()
	return "present vsync=%s max_fps=%d screen=%s" % [VSYNC_NAMES.get(mode, "mode%d" % mode),
		Engine.max_fps, "?" if hz <= 0.0 else "%.1fHz" % hz]


## Named rather than printed as an integer: a reader must not have to know the engine's enum to tell a
## run that waited on the display from one that did not. `screen_get_refresh_rate` returns a negative
## fallback when the platform declines to answer (headless does), and that reads `?` rather than `0.0Hz`,
## which would be a rate nobody could have measured.
const VSYNC_NAMES: Dictionary = {
	DisplayServer.VSYNC_DISABLED: "off", DisplayServer.VSYNC_ENABLED: "on",
	DisplayServer.VSYNC_ADAPTIVE: "adaptive", DisplayServer.VSYNC_MAILBOX: "mailbox"}


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
	return "PERF frames=%d fps_wall=%.1f frame p50=%.2fms p99=%.2fms max=%.2fms over8.3ms=%d over16.7ms=%d focus=%.2f | draw p50=%.2fms p99=%.2fms baking p50=%.2fms n=%d quiet p50=%.2fms n=%d | physics hub p50=%.2fms p99=%.2fms n=%d | quiet p50=%.2fms p99=%.2fms n=%d | %s | %s" % [
		f.size(), fps, _ms(_quantile(f, 0.5)), _ms(_quantile(f, 0.99)), _ms(f[f.size() - 1]), over120, over60,
		float(_focused) / float(maxi(f.size(), 1)),
		_ms(_quantile_of(_draws, 0.5)), _ms(_quantile_of(_draws, 0.99)),
		_ms(_quantile_of(_draws_baking, 0.5)), _draws_baking.size(),
		_ms(_quantile_of(_draws_quiet, 0.5)), _draws_quiet.size(),
		_ms(_quantile_of(_hub, 0.5)), _ms(_quantile_of(_hub, 0.99)), _hub.size(),
		_ms(_quantile_of(_quiet, 0.5)), _ms(_quantile_of(_quiet, 0.99)), _quiet.size(),
		calibration(), presentation()]


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
