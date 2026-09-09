extends "res://tests/test_base.gd"

## THE PERFORMANCE FIXTURE'S OWN INSTRUMENTS (D0535). `BakeCost` splits the terrain bake into preparation
## and upload -- the two phases `docs/PERF_PLAN.md`'s first remaining-work item asks for and the only two
## no other clock in the build can see; `FrameMeter` carries a fixed-work host-speed control beside every
## frame time, which is the line three voided sets of numbers needed and did not have (D0527); and
## `SeatDrive` poses the four named workloads a script, not a person, has to be able to reproduce.
##
## THE FAILURE THIS SUITE IS ABOUT is a workload that stops doing its own work and reports a number
## anyway. It happened four times while the fixture was being built and every time it arrived as a quiet
## zero, never as an error: a dig that mined air for 600 ticks, a walk pressed against the world's east
## edge. So the assertions below are mostly about the hand -- that the sweep is wider than the miner,
## that the phases are pressed on the ticks they claim -- rather than about any timing.

const CYCLE: int = SeatDrive.FALL_CYCLE
const BODY_PX: int = Body.WIDTH_PX


func _initialize() -> void:
	_test_bake_cost_counts_both_phases_and_resets()
	_test_slowest_receipt_keeps_its_own_cells_and_reasons()
	_test_the_control_loop_is_fixed_work_and_is_reported()
	_test_each_workload_presses_what_it_is_named_for()
	_test_the_dig_sweep_is_wider_than_the_miner()
	_test_the_seat_parses_its_workload_and_refuses_a_typo()
	_finish("perf_fixture")


## Preparation and upload are counted apart, per cell as well as per window, and `reset` closes a window
## without leaving the last one's work in the next one's numbers.
func _test_slowest_receipt_keeps_its_own_cells_and_reasons() -> void:
	BakeCost.reset()
	BakeCost.record_preparation(10, 20, 9, 6000, 100, "dig")
	BakeCost.record_preparation(10, 20, 9, 3000, 100, "margin")
	BakeCost.record_preparation(11, 21, 11, 1000, 1024, "visible")
	var event: Dictionary = BakeCost.slowest
	_check(event["usec"] == 9000 and event["cells"] == 200 and event["callbacks"] == 2,
		"slowest receipt pairs 9ms with its own 200 cells, not the later 1024-cell tick")
	_check(event["physics"] == 10 and event["render"] == 20 and event["planned"] == [9],
		"delayed drawing preserves both planning and execution identity")
	_check(event["reasons"]["dig"]["usec"] == 6000 and event["reasons"]["margin"]["cells"] == 100,
		"same-event reason totals remain separate and add to the event")
	BakeCost.reset()
	_check(BakeCost.slowest.is_empty(), "reset does not carry a previous window's slow receipt")


func _test_bake_cost_counts_both_phases_and_resets() -> void:
	BakeCost.reset()
	_check(BakeCost.prep_usec == 0 and BakeCost.upload_usec == 0, "a reset BakeCost holds no work")
	var began: int = Time.get_ticks_usec()
	BakeCost.note(BakeCost.PREP, began, 256)
	BakeCost.note(BakeCost.PREP, began, 64)
	BakeCost.note(BakeCost.UPLOAD, began, 4096)
	_check(BakeCost.prep_chunks == 2, "two prepared chunks counted, not one and not three")
	_check(BakeCost.prep_cells == 320, "the cells are summed across chunks: 256 + 64 == %d" % BakeCost.prep_cells)
	_check(BakeCost.prep_tick_max_cells == 320, "a burst sums both chunks in the same physics tick")
	_check(BakeCost.uploads == 1 and BakeCost.upload_cells == 4096, "the upload is counted apart from the preparation")
	# THE TWO PHASES MUST NOT SHARE A CLOCK. An upload charged to preparation is exactly the confusion
	# `docs/PERF_PLAN.md`'s rule 5 warns about ("measure `set_data`/`update` separately; the per-cell
	# ratio RISES as the region shrinks"), and it would hide a dirty-region lane capped by its own upload.
	var line: String = BakeCost.report(300)
	_check(line.contains("prep=") and line.contains("upload="), "the report names both phases: %s" % line)
	_check(line.contains("us/cell"), "and charges per cell, not per chunk: %s" % line)
	BakeCost.reset()
	_check(BakeCost.prep_cells == 0 and BakeCost.upload_cells == 0, "reset clears both phases")
	_check(BakeCost.prep_tick_max_cells == 0, "reset clears the burst high-water mark")


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


## Each workload presses exactly what its name says, on the ticks it says.
func _test_each_workload_presses_what_it_is_named_for() -> void:
	var f: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=still"]))
	var pressed: int = 0
	for t: int in 600:
		for a: StringName in [Controls.MINE, Controls.LEFT, Controls.RIGHT, Controls.JUMP]:
			if SeatDrive.driven(f, t, a):
				pressed += 1
	_check(pressed == 0, "the still workload presses nothing at all, over 600 ticks: %d presses" % pressed)

	var dig: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=dig"]))
	_check(not SeatDrive.driven(dig, 19, Controls.MINE), "the dig does not swing before tick 20")
	_check(SeatDrive.driven(dig, 20, Controls.MINE), "and holds MINE from tick 20")
	_check(SeatDrive.driven(dig, 1400, Controls.MINE), "and is still holding it a thousand ticks later")
	_check(not SeatDrive.driven(dig, 400, Controls.RIGHT), "and never walks")

	var fall: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=fall"]))
	_check(SeatDrive.driven(fall, SeatDrive.FALL_MINE_UNTIL - 1, Controls.MINE), "the fall digs to the end of its dig phase")
	_check(not SeatDrive.driven(fall, SeatDrive.FALL_MINE_UNTIL, Controls.MINE), "then releases, so the drop is a fall and not a dig")
	_check(not SeatDrive.driven(fall, SeatDrive.FALL_DROP_AT, Controls.MINE), "and is still released when the body is returned to the shaft's top")
	_check(SeatDrive.driven(fall, CYCLE + 30, Controls.MINE), "and digs again on the next cycle")

	var walk: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=walk"]))
	# A ONE-WAY WALK IS NOT A WORKLOAD IN THIS WORLD: 256 cells wide against a 160-cell camera, so it
	# reaches the east edge inside one window and stands there. The patrol is what keeps the camera moving.
	_check(SeatDrive.driven(walk, 10, Controls.RIGHT) != SeatDrive.driven(walk, 250, Controls.RIGHT),
		"the walk turns round rather than walking into the world's edge and stopping")
	_check(not SeatDrive.driven(walk, 300, Controls.MINE), "and never mines")


## The sweep has to cut a shaft WIDER THAN THE MINER or he cannot fall into it -- the game says so in as
## many words, and said it for a thousand ticks while the fixture reported zero bake work.
func _test_the_dig_sweep_is_wider_than_the_miner() -> void:
	var span: int = SeatDrive.DIG_SWEEP[SeatDrive.DIG_SWEEP.size() - 1] - SeatDrive.DIG_SWEEP[0]
	_check(span > BODY_PX, "the sweep spans %d logic px against a %d px body" % [span, BODY_PX])
	# AND IT MUST ACTUALLY VISIT THEM. A sweep whose tick divisor outran the swing period would charge
	# five cells and break none, which reads as a dig doing nothing at all -- the same quiet zero again.
	var seen: Dictionary = {}
	var dig: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=dig"]))
	var body: Body = Body.new(1000 * Fx.SCALE, 500 * Fx.SCALE)
	for t: int in SeatDrive.DIG_SWEEP_TICKS * SeatDrive.DIG_SWEEP.size():
		seen[int(SeatDrive.feet_aim(dig, body, t).x)] = true
	_check(seen.size() == SeatDrive.DIG_SWEEP.size(),
		"one full sweep visits every offset once: %d of %d" % [seen.size(), SeatDrive.DIG_SWEEP.size()])
	_check(SeatDrive.DIG_SWEEP_TICKS >= 8, "and rests on each long enough for a blow to land")
	# THE AIM IS THE FLOOR HE STANDS ON, not the row beneath it. One cell of difference kept a shelf under
	# the miner and stopped four consecutive windows dead.
	var aim: Vector2 = SeatDrive.feet_aim(dig, body, 0)
	var feet: float = 500.0 + float(Body.HEIGHT_PX) / 2.0
	_check(aim.y > feet - 4.0 and aim.y <= feet + 2.0,
		"the dig aims into the floor cell itself: %.1f against feet at %.1f" % [aim.y, feet])


## The seat parses a named workload, refuses a typo rather than walking, and takes the no-focus flag.
func _test_the_seat_parses_its_workload_and_refuses_a_typo() -> void:
	var f: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=fall", "--unfocused"]))
	_check(bool(f["perf"]) and bool(f["drive"]), "--perf-drive= turns the meter and the scripted hand on")
	_check(String(f["workload"]) == SeatDrive.FALL, "and names the workload: %s" % f["workload"])
	_check(bool(f["unfocused"]), "--unfocused is parsed")
	var bare: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive"]))
	_check(String(bare["workload"]) == SeatDrive.WALK, "bare --perf-drive is still the walk")
	_check(not bool(bare["unfocused"]), "and takes no focus flag it was not given")
	# A TYPO MUST NOT BECOME A WALK. A misspelled workload that silently fell back would report a walk's
	# numbers under a dig's heading, which is the one failure a performance fixture cannot survive.
	var typo: Dictionary = SeatFlags.parse(PackedStringArray(["--perf-drive=dgi"]))
	_check(String(typo["workload"]) == SeatDrive.WALK and not SeatDrive.WORKLOADS.has("dgi"),
		"an unknown workload is refused, not silently walked")
	for i: int in 10:
		_check(not SeatDrive.no_digit(i), "a scripted seat holds no digit key: %d" % i)
