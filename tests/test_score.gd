extends "res://tests/test_base.gd"

## D0215. `view/audio/score.gd`, the first thing lifted out of legacy since `controls.gd`, and the first
## sound this build has ever made. The suite checks the three claims its own header makes, because a
## lifted file arrives with prose that was true of a different codebase and nothing in the port proves it
## is still true of this one.
##
##   1. The loop is SEAMLESS. Every partial completes a whole number of cycles across the window, so the
##      wrap from the last sample to the first is an ordinary step rather than a click. Checked against a
##      control -- the largest step INSIDE the buffer -- so "small" is measured in the signal's own units
##      instead of against a number picked here.
##   2. The beds are DETERMINISTIC. `_gen_sub` uses a seeded RNG for its noise breath and the header
##      claims "the same recording every boot"; two generations at the same seed must be byte-identical.
##   3. The mix is a FUNCTION OF DEPTH, in the direction the header describes: OPEN thins going down,
##      MINOR and SUB grow, and everything pitches down together.
##
## `_muted` is asserted too, and it is not a formality: this suite runs under `--headless`, where the
## Dummy audio driver never reaps a started voice. A regression that started playback here would surface
## as an ObjectDB leak warning at the end of an unrelated CI job.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_score.gd


## A synthesised `Score`, DETACHED, with `_ready()` called by hand and freed by the caller. Two Godot
## facts make this the right shape rather than `get_root().add_child(...)`, and both were found here:
## from a `SceneTree` script's own `_initialize()`, a node added to the root does not get `_ready()` in
## time -- the three players stay null and every access is a SCRIPT ERROR that `_check` cannot see. And
## `queue_free()` never runs at all, because the suite quits before the tree processes the queue, which
## leaves an ObjectDB leak that `tools/run_gd_test.sh` reads as an engine-level failure. Adding the
## players as children of a DETACHED node works fine, so nothing is lost by staying out of the tree.
func _built() -> Score:
	var score: Score = Score.new()
	score._ready()
	return score


func _initialize() -> void:
	_test_the_loop_wraps_without_a_click()
	_test_the_noise_bed_is_the_same_recording_every_boot()
	_test_the_mix_follows_depth_in_the_direction_the_header_claims()
	_test_nothing_plays_under_headless()
	_finish("score")


## The seam test. A partial that does not complete whole cycles in the window leaves the buffer at a
## different phase than it started, and the loop point steps by that difference every 6 seconds -- an
## audible tick. `_stack` snaps each frequency to prevent it; this measures the result rather than
## re-deriving the ratio table here, which would be a test fitted to the thing it checks.
func _test_the_loop_wraps_without_a_click() -> void:
	var score: Score = _built()
	for named: Array in [["open", score._gen_open()], ["minor", score._gen_minor()]]:
		var buf: PackedFloat32Array = named[1]
		var biggest_inside: float = 0.0
		for i: int in range(1, buf.size()):
			biggest_inside = maxf(biggest_inside, absf(buf[i] - buf[i - 1]))
		var at_the_wrap: float = absf(buf[0] - buf[buf.size() - 1])
		_check(buf.size() == int(Score.RATE * Score.LOOP_SECONDS),
			"%s bed is the full loop window (%d samples)" % [named[0], buf.size()])
		_check(at_the_wrap <= biggest_inside,
			"%s wraps by %.6f, no worse than the largest step inside the buffer (%.6f)" %
			[named[0], at_the_wrap, biggest_inside])
	score.free()


func _test_the_noise_bed_is_the_same_recording_every_boot() -> void:
	var score: Score = _built()
	var a: PackedFloat32Array = score._gen_sub(_seeded())
	var b: PackedFloat32Array = score._gen_sub(_seeded())
	_check(a == b, "two generations of the noise bed at the same seed are identical")
	var different: PackedFloat32Array = score._gen_sub(_seeded(1))
	_check(a != different,
		"control: a different seed really does produce a different bed, so the check above is not " +
		"comparing two empty buffers")
	score.free()


func _seeded(offset: int = 0) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260816 + offset
	return rng


## `delta` is passed large enough to defeat `FADE_RATE`'s easing in one call. The easing is real and
## wanted in play -- a fast fall must not slam the score -- but inside a test it would only measure how
## many times this function was called.
func _test_the_mix_follows_depth_in_the_direction_the_header_claims() -> void:
	var score: Score = _built()
	score.set_depth(0.0, 100.0)
	var surface: Array = [score._open.volume_db, score._minor.volume_db, score._sub.volume_db, score._open.pitch_scale]
	score.set_depth(1.0, 100.0)
	var deep: Array = [score._open.volume_db, score._minor.volume_db, score._sub.volume_db, score._open.pitch_scale]
	_check(deep[0] < surface[0], "OPEN thins with depth (%.1f dB -> %.1f dB)" % [surface[0], deep[0]])
	_check(deep[1] > surface[1], "MINOR fades in with depth (%.1f dB -> %.1f dB)" % [surface[1], deep[1]])
	_check(deep[2] > surface[2], "SUB grows with depth (%.1f dB -> %.1f dB)" % [surface[2], deep[2]])
	_check(deep[3] < surface[3],
		"and the whole stack pitches down together (%.2f -> %.2f), which is what makes it read as one " %
		[surface[3], deep[3]] + "thing sinking rather than three tracks crossfading")
	_check(score._minor.pitch_scale == deep[3] and score._sub.pitch_scale == deep[3],
		"all three beds share one pitch, so they cannot drift out of tune")
	score.free()


func _test_nothing_plays_under_headless() -> void:
	var score: Score = _built()
	_check(DisplayServer.get_name() == "headless", "control: this suite really is running headless")
	_check(score._muted, "so the score mutes itself, and no voice is started for the Dummy driver to leak")
	_check(not score._open.playing, "confirmed on the player itself after synthesis")
	score.free()
