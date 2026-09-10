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
	_test_each_workload_presses_what_it_is_named_for()
	_test_the_dig_sweep_is_wider_than_the_miner()
	_test_the_seat_parses_its_workload_and_refuses_a_typo()
	_test_region_setup_is_a_slice_of_preparation_not_a_fourth_phase()
	_test_the_setup_line_names_the_multiplier_a_per_cell_rate_carries()
	_test_a_real_paint_charges_setup_and_cells_over_different_areas()
	_test_a_real_paint_records_the_dilated_span_the_painters_actually_scan()
	_test_the_neighbourhood_build_is_priced_in_the_unit_the_trade_is_offered_in()
	_test_the_chunk_split_duplicates_halo_and_the_probe_measures_it()
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


## REGION SETUP IS A SLICE OF PREPARATION, NOT A FOURTH PHASE (D0545). The PREP clock in `BakeChunk.paint`
## wraps the whole callback, observation included, so `prep_setup_usec` is CONTAINED in `prep_usec` and the
## two must never be summed. This is the containment `docs/QUALITY.md`'s two-instruments rule asks for: the
## counters do not add to a cover, one is inside the other, and a suite says which.
func _test_region_setup_is_a_slice_of_preparation_not_a_fourth_phase() -> void:
	BakeCost.reset()
	_check(BakeCost.prep_setup_usec == 0 and BakeCost.prep_setups == 0,
		"a reset BakeCost holds no region setup")
	var began: int = Time.get_ticks_usec()
	BakeCost.note_setup(began, 812)
	BakeCost.note(BakeCost.PREP, began, 110, 7, "dig")
	_check(BakeCost.prep_setups == 1 and BakeCost.prep_setup_cells == 812,
		"one setup counted, over the cells the envelope observed: 812")
	_check(BakeCost.prep_cells == 110,
		"preparation still counts the PAINTED cells: 110, not the 812 observed")
	_check(BakeCost.prep_setup_usec <= BakeCost.prep_usec,
		"setup is contained in preparation: %d <= %d" % [BakeCost.prep_setup_usec, BakeCost.prep_usec])
	BakeCost.reset()
	_check(BakeCost.prep_setup_cells == 0, "reset closes the window's setup counters too")


## The line exists to print the ratio the per-cell rate is silently carrying, so the ratio is what is
## pinned. 812 observed against 110 painted is a dig partial grown by the 9-cell margin on four sides;
## the number a reader must see is 7.38x, not either area alone.
func _test_the_setup_line_names_the_multiplier_a_per_cell_rate_carries() -> void:
	BakeCost.reset()
	_check(BakeCost.setup_line() == "", "no setups means no line, never a 0.00x")
	var began: int = Time.get_ticks_usec()
	BakeCost.note_setup(began, 812)
	BakeCost.note(BakeCost.PREP, began, 110, 7, "dig")
	var line: String = BakeCost.setup_line()
	_check(line.contains("obs_cells=812") and line.contains("painted_cells=110"),
		"both denominators are printed, because the point is that they differ: %s" % line)
	_check(line.contains("obs/painted=7.38x"),
		"the multiplier is stated, not left to the reader: %s" % line)
	BakeCost.reset()


## THE INSTRUMENT IS WIRED, not merely present (D0545). The two pins above call `note_setup` themselves,
## so they stay green if `BakeChunk._paint` never calls it -- the house failure exactly, arriving as a
## quiet zero rather than an error. This drives a REAL `BakeChunk.paint` over a posed observation whose
## window is deliberately WIDER than the chunk being painted, and asserts the two counters took their
## areas from different places. If either read the other's, the ratio the line exists to print is 1.00x.
func _test_a_real_paint_charges_setup_and_cells_over_different_areas() -> void:
	var cell_px: int = 4
	var per_chunk: int = BakeWindow.CHUNK_PX / cell_px
	var w := BakeWindow.new()
	w.plan(Vector2i(3000, 1000), cell_px)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	var i: int = 4 * w.grid().x + 60
	var wide := Rect2i(58 * per_chunk, 2 * per_chunk, 4 * per_chunk, 4 * per_chunk)
	var obs := Interface.Observation.new()
	obs.window = wide
	obs.legend = PackedStringArray(["", "clay"])
	obs.materials = PackedByteArray()
	obs.materials.resize(wide.size.x * wide.size.y)
	var chunk := BakeChunk.new()
	var empty: Array[Callable] = []
	chunk.setup(w, func(_r: Rect2) -> Interface.Observation: return obs,
		MaterialLook.new(), RockTone.new(0), empty, null)
	var ci := Node2D.new()
	BakeCost.reset()
	chunk.paint(ci, i, w.chunk_rect(i))
	_check(BakeCost.prep_setups == 1,
		"the production path called note_setup once, not %d" % BakeCost.prep_setups)
	_check(BakeCost.prep_setup_cells == wide.get_area(),
		"setup charged the OBSERVED window %d, not %d" % [wide.get_area(), BakeCost.prep_setup_cells])
	_check(BakeCost.prep_cells == per_chunk * per_chunk,
		"preparation charged the PAINTED chunk %d, not %d" % [per_chunk * per_chunk, BakeCost.prep_cells])
	_check(BakeCost.prep_setup_cells > BakeCost.prep_cells,
		"observed exceeds painted, which is the finding: %d > %d"
			% [BakeCost.prep_setup_cells, BakeCost.prep_cells])
	ci.free()
	BakeCost.reset()


## THE DENOMINATOR THE PAINTERS ACTUALLY COST BY (D0546). `TerrainPainter.paint` builds one
## `RockNeighborhood` per callback over `cells.grow(RockTone.FORM_REACH)` and scans it three times, so a
## callback's cost tracks that DILATED span, not the rect it charges. Measured over a dig: 3.01 and 2.94
## us a dilated cell against margin's 2.71 and 2.86 -- converging within 3-11% where the per-painted-cell
## figures differ 1.64-1.82x. This pins that the recorded span is the dilated one and comes from the
## production path; charge it the painted rect instead and the ratio the finding rests on vanishes.
##
## `capture_bursts` gates the density walk, so it is set here deliberately: with it off the production
## path must record NOTHING, which is the other half of the pin.
func _test_a_real_paint_records_the_dilated_span_the_painters_actually_scan() -> void:
	var cell_px: int = 4
	var per_chunk: int = BakeWindow.CHUNK_PX / cell_px
	var w := BakeWindow.new()
	w.plan(Vector2i(3000, 1000), cell_px)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	var i: int = 4 * w.grid().x + 60
	var wide := Rect2i(58 * per_chunk, 2 * per_chunk, 4 * per_chunk, 4 * per_chunk)
	var obs := Interface.Observation.new()
	obs.window = wide
	obs.legend = PackedStringArray(["", "clay"])
	obs.materials = PackedByteArray()
	obs.materials.resize(wide.size.x * wide.size.y)
	obs.materials.fill(1)                       # every observed cell solid, so `solid` is checkable
	var chunk := BakeChunk.new()
	var empty: Array[Callable] = []
	chunk.setup(w, func(_r: Rect2) -> Interface.Observation: return obs,
		MaterialLook.new(), RockTone.new(0), empty, null)
	var ci := Node2D.new()
	var painted: Rect2i = w.cells_of(w.chunk_rect(i))
	var expected: int = painted.grow(RockTone.FORM_REACH).get_area()
	BakeCost.reset()
	BakeCost.capture_bursts = true
	chunk.paint(ci, i, w.chunk_rect(i))
	var part: Dictionary = BakeCost.prep_by_reason.get("unknown", {})
	_check(int(part.get("dilated", 0)) == expected,
		"the DILATED span is recorded: %d, expected grow(%d) of %d painted = %d"
			% [int(part.get("dilated", 0)), RockTone.FORM_REACH, painted.get_area(), expected])
	_check(expected > painted.get_area(),
		"the dilated span exceeds the painted rect, which is the finding: %d > %d"
			% [expected, painted.get_area()])
	_check(int(part.get("solid", 0)) == painted.get_area(),
		"every cell was solid, so solid == painted here: %d" % int(part.get("solid", 0)))
	BakeCost.reset()
	BakeCost.capture_bursts = false
	chunk.paint(ci, i, w.chunk_rect(i))
	_check(not BakeCost.prep_by_reason.get("unknown", {}).has("dilated"),
		"with profiling off the density walk does not run at all")
	ci.free()
	BakeCost.reset()


## THE HEADROOM PROBE MEASURES THE SPLIT, AND RUNS (D0549). `plan_tick` cuts one dig rect along chunk
## boundaries, and each piece dilates by `FORM_REACH` independently, so adjacent pieces' halos overlap.
## The probe records the pieces' total dilated span against their union's. Two things are pinned: that a
## dig crossing a boundary really does pay more than its union (the finding), and that the probe is driven
## from `plan_tick` rather than only by a test calling it (the wiring).
##
## `capture_bursts` gates it, so it is set deliberately and cleared afterwards: with profiling off the
## probe must record nothing at all.
func _test_the_neighbourhood_build_is_priced_in_the_unit_the_trade_is_offered_in() -> void:
	# D0556. `dig_split` weighs the union trade in cells dilated by `RockTone.FORM_REACH` (6) and `setup`
	# measures a span dilated by `WINDOW_MARGIN_CELLS` (9), so sizing the trade by setup's share of prep
	# charges the saving to a clock that cannot measure it. `RockNeighborhood._init` spans exactly
	# `grow(FORM_REACH)`. `[[budget-in-the-wrong-unit-is-green-forever]]`, one clock over.
	BakeCost.reset()
	_check(BakeCost.form_line() == "", "no builds means no line, never a 0.00us/dilated")
	var began: int = Time.get_ticks_usec()
	BakeCost.note_form(began, 529)
	BakeCost.note_setup(began, 1600)
	BakeCost.note(BakeCost.PREP, began, 121, 7, "dig")
	_check(BakeCost.prep_forms == 1 and BakeCost.prep_form_cells == 529,
		"one build counted, over the cells it spanned: 529")
	_check(BakeCost.prep_form_usec <= BakeCost.prep_usec, "the build is contained in preparation, never"
		+ " added to it: %d <= %d" % [BakeCost.prep_form_usec, BakeCost.prep_usec])
	# A BUILD THAT DID NOT HAPPEN COSTS AND COUNTS NOTHING: `TerrainPainter` skips it with no tone or an
	# empty rect, and a zero-cell build averaged in drags the very rate the trade is decided on.
	BakeCost.note_form(Time.get_ticks_usec(), 0)
	_check(BakeCost.prep_forms == 1 and BakeCost.prep_form_cells == 529,
		"a skipped build is not a build: %d over %d cells" % [BakeCost.prep_forms, BakeCost.prep_form_cells])
	_check(BakeCost.setup_line().contains("form=") and BakeCost.setup_line().contains("us/dilated"),
		"the window line carries the build beside the setup it is not: %s" % BakeCost.setup_line())
	BakeCost.reset()


func _test_the_chunk_split_duplicates_halo_and_the_probe_measures_it() -> void:
	var cell_px: int = 4
	var per_chunk: int = BakeWindow.CHUNK_PX / cell_px
	var w := BakeWindow.new()
	w.plan(Vector2i(3000, 1000), cell_px)
	w.set_margin(0)                              # the dig rect is then exactly the dug cells' box
	# two cells straddling a chunk boundary, so the dig rect is cut in two
	var edge: int = 60 * per_chunk
	var dug: Array = [Vector2i(edge - 1, 300), Vector2i(edge, 300)]
	for i: int in w.chunk_count():
		if w.chunk_rect(i).intersects(w.dig_rect(dug)):
			w.note_painted(i)                    # painted, so the dig plans PARTIALS rather than wholes
	BakeCost.reset()
	BakeCost.capture_bursts = true
	var p: BakeWindow.Plan = w.plan_tick(Rect2(0.0, 0.0, 8.0, 8.0), dug, null)
	_check(p.partial.size() >= 2,
		"the dig rect was cut along the chunk boundary into %d pieces" % p.partial.size())
	_check(BakeCost.dig_split_ticks == 1,
		"the probe ran from plan_tick, not only from a test: %d tick(s)" % BakeCost.dig_split_ticks)
	_check(BakeCost.dig_paid_dilated > BakeCost.dig_shared_dilated,
		"the pieces' dilated spans exceed their union's, which is the finding: %d > %d"
			% [BakeCost.dig_paid_dilated, BakeCost.dig_shared_dilated])
	_check(BakeCost.split_line().contains("overlap="),
		"and the line states the overlap: %s" % BakeCost.split_line())
	# THE PEAK PAIR IS ONE TICK'S TRADE, never two independent maxima (D0556). The frame a player loses
	# is dropped by ONE tick, so the peak is what decides whether the treatment is worth writing -- and a
	# worst-paid tick reported beside some OTHER tick's shared span is a trade nobody was ever offered,
	# which reads as a better one than any tick actually had. Posed so the two disagree: taking maxima
	# apart would pair 100 with 45 and report 55% where the worst tick's own trade is 90%.
	BakeCost.reset()
	BakeCost.note_dig_span(100, 10, 400, 40)
	BakeCost.note_dig_span(50, 45, 200, 180)
	_check(BakeCost.dig_peak_paid == 100 and BakeCost.dig_peak_shared == 10,
		"the peak tick reports its own shared span: paid=%d shared=%d"
			% [BakeCost.dig_peak_paid, BakeCost.dig_peak_shared])
	_check(BakeCost.dig_peak_paid_obs == 400 and BakeCost.dig_peak_shared_obs == 40,
		"and the observation span of that same tick, not of the other one: paid=%d shared=%d"
			% [BakeCost.dig_peak_paid_obs, BakeCost.dig_peak_shared_obs])
	# THE OBSERVATION'S DILATION IS A SEPARATE TRADE and is silent unless it was supplied: a caller that
	# passes only the neighbourhood span must not have a 100% observation overlap invented for it.
	BakeCost.reset()
	BakeCost.note_dig_span(100, 10)
	_check(not BakeCost.split_line().contains("obs_span"),
		"an unsupplied observation span is absent, not a measured zero: %s" % BakeCost.split_line())
	BakeCost.reset()
	BakeCost.capture_bursts = false
	var q: BakeWindow.Plan = w.plan_tick(Rect2(0.0, 0.0, 8.0, 8.0), dug, null)
	_check(q != null and BakeCost.dig_split_ticks == 0,
		"with profiling off the probe records nothing")
	BakeCost.reset()
