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
const SLOW_USEC: int = 25000
const SLOW_KEEP: int = 4
var last_frame_usec: int = 0


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
		slow.append("SLOW %.1fms %s" % [_ms(last_frame_usec), context])


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
