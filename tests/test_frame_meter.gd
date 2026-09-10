extends "res://tests/test_base.gd"

## THE FRAME METER'S OWN CONTROLS (D0556, split out of `tests/test_perf_fixture.gd` at that file's 400-line
## cap -- a seam, not a trim: what a workload does is that suite's, what the clock watching it can and
## cannot see is this one's).
##
## THE FAILURE THIS SUITE IS ABOUT is a frame number that describes something other than the game. It has
## happened three times and every time the number looked ordinary: a window macOS had stopped presenting
## (114 against 381 fps for identical work), a host whose main thread ran 3x slow between sleeps, and a
## process producing 400 frames a second against a 120 Hz display and blocking on a drawable for 13 ms of
## every p99. So the meter carries three controls beside every number -- a fixed-work loop, the focused
## share, and the presentation regime -- and the assertions here are that each of them can be FALSE.

func _initialize() -> void:
	_test_the_control_loop_is_fixed_work_and_is_reported()
	_test_the_window_line_says_which_presentation_regime_produced_it()
	_test_the_focus_share_is_a_share_of_the_frames_it_describes()
	_finish("frame_meter")


## The control loop must do the SAME work every time it is asked, or it measures itself rather than the
## host. Its result is kept in `cal_sink` precisely so this can be asserted instead of assumed.
func _test_the_control_loop_is_fixed_work_and_is_reported() -> void:
	var m: FrameMeter = FrameMeter.new()
	_check(m.calibration().contains("n=0"), "a fresh meter has taken no control samples")
	for _i: int in FrameMeter.CAL_EVERY * 4:
		m.note_process()
	var first: int = m.cal_sink
	var n: FrameMeter = FrameMeter.new()
	for _i: int in FrameMeter.CAL_EVERY * 4:
		n.note_process()
	_check(first != 0, "the loop produced a result, so nothing about it was skipped")
	_check(first == n.cal_sink, "two meters run the same fixed work: %d == %d" % [first, n.cal_sink])
	_check(m.calibration().contains("p50=") and m.calibration().contains("spread="),
		"the control reports a median and a spread: %s" % m.calibration())
	# THE WINDOW LINE MUST CARRY IT. A control computed and not printed is a control nobody can check a
	# past run against, and every run this fixture produces is read later, from its log, by someone else.
	_check(m.report().contains("cal p50="), "the window report carries the control: %s" % m.report())
	_check(m.report().contains("draw p50="), "and the draw phase, over every frame rather than the worst eight")
	m.reset()
	_check(m.calibration().contains("n=0"), "reset clears the control's samples with the frames'")


func _test_the_window_line_says_which_presentation_regime_produced_it() -> void:
	# THE THIRD CONTROL (D0555), and the same defect as `focus` one layer down. `--disable-vsync
	# --max-fps 0` lets the app produce ~400 frames a second against a 120 Hz display, so it blocks on a
	# drawable that does not exist yet: 8.24-8.51 ms of WAITING, counted as draw time and frame time.
	# The same dig workload drops 28-30 frames a window vsynced and 22-35 unvsynced, over 597 frames
	# against 1598 -- the RATE moved 2.5-4x on a game that did not change. A report that cannot say its
	# regime cannot be compared. `[[window-regime-is-inside-the-measurement]]`,
	# `[[read-the-count-not-the-rate]]`.
	var m: FrameMeter = FrameMeter.new()
	for _i: int in FrameMeter.CAL_EVERY * 4:
		m.note_process()
	var line: String = m.report()
	_check(line.contains("present vsync=") and line.contains("max_fps=") and line.contains("screen="),
		"the window line carries the presentation regime: %s" % line)
	# NAMED, NOT NUMBERED: a reader must not have to know the engine's enum to tell a run that waited on
	# the display from one that did not, so the mode is a word and never the integer behind it.
	var named: bool = false
	for word: String in ["vsync=off", "vsync=on", "vsync=adaptive", "vsync=mailbox"]:
		named = named or line.contains(word)
	_check(named, "the vsync mode is a word, not the enum's integer: %s" % m.presentation())
	# AND AN UNANSWERED REFRESH RATE READS AS UNANSWERED. `screen_get_refresh_rate` returns a negative
	# fallback where the platform declines (headless is one), and printing that as 0.0Hz would be a rate
	# nobody measured -- an invented identifying constant, which is the one thing a receipt may not carry.
	_check(not m.presentation().contains("screen=0.0Hz") and not m.presentation().contains("-1"),
		"an unanswered refresh rate is not reported as a measured one: %s" % m.presentation())


func _test_the_focus_share_is_a_share_of_the_frames_it_describes() -> void:
	# `focus` gates every frame number this programme publishes (the fixture withholds a window below
	# 0.95), so a focus that can exceed 1.0 is a guard reporting more agreement than it measured. The
	# first `_process` closes no frame, so its focus sample had no frame to belong to and the share was
	# computed over n-1: a 15-frame window read 1.07. `[[guards-that-cannot-be-false]]`.
	var m: FrameMeter = FrameMeter.new()
	for _i: int in 16:
		m.note_process()
	var share: float = float(m.report().split("focus=")[1].split(" ")[0])
	_check(share <= 1.0, "a share of the frames cannot exceed all of them: focus=%.2f" % share)
	_check(m.report().contains("frames=15 "), "and the window still reports the 15 frames 16 calls close")
