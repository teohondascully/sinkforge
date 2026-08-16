extends SceneTree

## THE DIG RHYTHM — the anti-tedium rule, pinned. Mining used to have no momentum: every block started
## from a dead stop, so a twenty-block shaft was twenty unrelated chores. The rhythm makes staying in the
## work pay you back. That is a FEEL change, and feel changes are exactly the ones that rot silently, so
## the five properties that make it feel like a groove instead of a random speed-up are asserted here.
##
##   1. a cold start is unchanged   — the first block of a session costs exactly what it always did, so
##                                    hand-mining still argues for automation (the friction is the point)
##   2. it fills in a few blocks    — not twenty; the reward has to arrive inside the shaft you are digging
##   3. full rhythm is FELT         — a real fraction faster, not a rounding error you could never notice
##   4. it cannot be banked         — leave the rock and it bleeds all the way back to nothing
##   5. the grace outlasts a swing  — THE load-bearing one: if the grace window were shorter than the gap
##                                    between pick-blows, the rhythm would bleed away DURING a single
##                                    charge and the speed-up would read as the game stuttering at random
##
## The decay is driven through the real _update_mining each frame, not by reimplementing the maths here.

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _frames: int = 0
var _fails: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	MainView.dev_start = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== dig rhythm ==")
	process_frame.connect(_on_frame)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	process_frame.disconnect(_on_frame)
	_run()
	if _fails == 0:
		print("check_rhythm: PASS")
		quit(0)
	else:
		print("check_rhythm: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	# 1. A COLD START IS UNCHANGED. The rhythm is a multiplier on top of the tool speed, and at rest it
	#    must be exactly 1.0 — a first block that is secretly faster would quietly undo the grind the
	#    whole automation pull rests on.
	_check(_main._rhythm == 0.0, "boots at zero rhythm")
	_check(absf(_rate(0.0) - 1.0) < 1e-6, "cold start costs exactly the base rate (%.3fx)" % _rate(0.0))

	# 2. IT FILLS IN A FEW BLOCKS. Three or four, not twenty: the payoff has to land inside the shaft you
	#    are currently digging or it is not a rhythm, it is an achievement.
	var to_full: int = int(ceil(1.0 / MainView.RHYTHM_GAIN))
	_check(to_full >= 2 and to_full <= 5, "%d blocks to full rhythm" % to_full)

	# 3. FULL RHYTHM IS FELT. Both halves: the charge rate AND the swing cadence, because a speed-up you
	#    cannot see the body performing reads as the game cheating rather than as you getting into it.
	_check(_rate(1.0) >= 1.35, "full rhythm digs %.2fx faster" % _rate(1.0))
	var cold_swing: float = MainView.SWING_PERIOD
	var hot_swing: float = MainView.SWING_PERIOD / (1.0 + MainView.RHYTHM_SWING)
	_check(hot_swing <= cold_swing * 0.75,
		"full rhythm swings %.0f%% quicker (%.3fs -> %.3fs)"
			% [(1.0 - hot_swing / cold_swing) * 100.0, cold_swing, hot_swing])

	# 5. THE GRACE OUTLASTS A SWING — asserted before 4 because it is the one that matters. Between two
	#    pick-blows of a single charge no block breaks, so `_rhythm_idle` is climbing the whole time; if
	#    the grace were shorter than that gap, the rhythm would sag mid-charge on every hard rock.
	_check(MainView.RHYTHM_GRACE > cold_swing * 2.0,
		"grace (%.2fs) outlasts the slowest swing gap (%.2fs)" % [MainView.RHYTHM_GRACE, cold_swing])

	# 4. IT CANNOT BE BANKED — driven through the REAL per-frame path. First: inside the grace window it
	#    must hold, so glancing away for a moment does not cost you the groove.
	_main._rhythm = 1.0
	_main._rhythm_idle = 0.0
	_step(MainView.RHYTHM_GRACE * 0.75)
	_check(_main._rhythm > 0.99, "holds through the grace window (%.3f)" % _main._rhythm)
	# Then: leave it long enough and it is gone, all the way to zero, not to some sticky floor.
	_step(MainView.RHYTHM_GRACE + 1.0 / MainView.RHYTHM_DECAY + 0.5)
	_check(_main._rhythm == 0.0, "bleeds all the way back to zero (%.3f)" % _main._rhythm)


## The charge-rate multiplier the mining loop applies at a given rhythm.
func _rate(rhythm: float) -> float:
	return 1.0 + rhythm * MainView.RHYTHM_SPEED


## Advance the real game loop for `seconds` of wall time, with nothing held down.
func _step(seconds: float) -> void:
	for _i: int in int(ceil(seconds * 60.0)):
		_main._update_mining(1.0 / 60.0)
