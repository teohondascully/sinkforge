extends "res://tests/test_base.gd"

## D0213. The ceiling corner nudge is an INSTANT TRANSLATION -- up to 6px of horizontal position in one
## tick, 360 px/s against a 150 px/s run speed -- and this suite pins the condition under which it is
## allowed to happen: the body must already be travelling horizontally. It is the third instance of the
## class D0209 (auto step-up firing mid-air) and D0212 (mantle doing the same) opened, and the first one
## found by a code audit rather than by the director noticing the body move somewhere it had not asked to
## go. That is the reason this file exists rather than another ledger entry: the class needs a test that
## fails when a FOURTH instance is added, not three separate fixes.
##
## Two of the four checks below are controls, and they are the point of the suite:
##   * the consented case must STILL fire, or the "fix" is a deletion of a mechanic
##     `docs/ARCHITECTURE.md` §9 specifies and `test_body_acceptance` requires at 100%
##   * the ceiling contact must actually happen in the invented case, or "no nudge fired" is just a
##     probe that never posed its subject
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_corner_consent.gd

const SLAB_LAST_COL: int = 19   ## the slab spans columns [0, 19]; column 20 onward is open sky
const SLAB_TOP_ROW: int = 10
const SLAB_ROWS: int = 3
const FLOOR_ROW: int = 30
const GRID_W: int = 80
const GRID_H: int = 40
const TICKS: int = 40


func _initialize() -> void:
	_test_a_straight_up_jump_under_an_overhang_is_never_moved_sideways()
	_test_that_case_really_does_contact_the_ceiling()
	_test_a_running_jump_still_gets_its_corner_nudge()
	_test_the_consent_invariant_fires_on_the_displacement_the_defect_produced()
	_test_the_consent_invariant_exempts_the_two_recovery_paths()
	_finish("corner_consent")


## A flat floor with a slab overhead whose right edge is at `SLAB_LAST_COL`. A body standing under that
## edge and jumping puts its head into the slab with 6px of the box still covered, which is exactly the
## "ceiling contact near a corner" shape §9 names the mechanic for, and exactly the shape a 6px nudge can
## resolve (`docs/DECISIONS_LEDGER.md` D0055: a nudge can only ever rescue an EXITING graze).
func _build() -> TileGrid:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for col: int in range(0, SLAB_LAST_COL + 1):
		for row: int in range(SLAB_TOP_ROW, SLAB_TOP_ROW + SLAB_ROWS):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


## Settles a body at `start_px` on the floor, then jumps it and holds `move_dir` for the flight.
## Returns the run's own record: every quantity the checks below need, gathered in one place so no check
## re-derives one from another.
func _jump_under_the_slab(start_px: int, move_dir: int) -> Dictionary:
	var grid: TileGrid = _build()
	var body: Body = Body.new(
		Fx.from_int(start_px), Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	var settle: InputFrame = InputFrame.new()
	for _i: int in 20:
		body.tick(settle, grid)
	var settled_x: int = body.pos_x
	var nudges: int = 0
	var consent_violations: int = 0
	var ceiling_stops: int = 0
	var max_abs_dx: int = 0
	for t: int in TICKS:
		var input: InputFrame = InputFrame.new()
		input.move_dir = move_dir
		input.jump_pressed = t == 0
		input.jump_held = t < 12
		var before_vy: int = body.vel_y
		body.tick(input, grid)
		if body.corner_corrected_this_tick:
			nudges += 1
		if body.translation_consent_violation_this_tick:
			consent_violations += 1
		# A ceiling stop is the OTHER outcome of `resolve_ceiling`: rising, then held at zero by the
		# slab rather than by the apex. `APEX_BAND` separates the two -- an apex arrives through it.
		if before_vy < -Body.APEX_BAND and body.vel_y == 0:
			ceiling_stops += 1
		max_abs_dx = maxi(max_abs_dx, absi(body.pos_x - settled_x))
	return {"nudges": nudges, "consent_violations": consent_violations,
		"ceiling_stops": ceiling_stops, "max_abs_dx": max_abs_dx, "settled_x": settled_x,
		"facing": body.facing}


## THE DEFECT, posed. Before D0213 this run moved the body +6.00px: `resolve_ceiling` took its nudge
## direction from `body.facing` whenever `vel_x` was zero, and `facing` defaults to +1 and is never
## cleared, so a body that had never been asked to move in any direction still had one on file.
func _test_a_straight_up_jump_under_an_overhang_is_never_moved_sideways() -> void:
	var r: Dictionary = _jump_under_the_slab(82, 0)
	_check(r["facing"] == 1, "the body still has a facing on file (the field the old rule read): %d" % r["facing"])
	_check(r["max_abs_dx"] == 0,
		"no horizontal displacement across the whole flight with no input (max |dx| = %.2f px, was 6.00)"
		% [float(r["max_abs_dx"]) / float(Fx.SCALE)])
	_check(r["nudges"] == 0, "no corner correction fired without horizontal motion (%d fired)" % r["nudges"])
	_check(r["consent_violations"] == 0,
		"and the consent invariant stayed silent, which it only can if nothing moved (%d)" % r["consent_violations"])


## The control for the check above, and not optional: "no nudge fired" is worth nothing unless the run
## actually put the body's head into the slab. If the geometry ever drifts so the head misses, this fails
## and the suite says so, instead of passing because it posed nothing (`docs/QUALITY.md`'s own rule about
## a probe that cannot register its subject).
func _test_that_case_really_does_contact_the_ceiling() -> void:
	var r: Dictionary = _jump_under_the_slab(82, 0)
	_check(r["ceiling_stops"] >= 1,
		"the jump really is stopped by the slab, not merely by its own apex (%d stops)" % r["ceiling_stops"])


## The mechanic itself, still working. §9 specifies corner correction and `test_body_acceptance` asserts
## `corner_correction_success_rate == 100%`, so a gate that silenced this case would be a deletion, not a
## fix. It matters that this run is AIRBORNE and has no coyote time left: gating this path the way the two
## climbs were gated (`recently_grounded`) would take this to zero, because `move_and_resolve` clears
## `on_floor` before any substep and `_handle_jump` zeroes the coyote counter on launch. A ceiling is only
## ever contacted moving upward, so there is no grounded state for this path to be restricted to.
func _test_a_running_jump_still_gets_its_corner_nudge() -> void:
	var r: Dictionary = _jump_under_the_slab(78, 1)
	_check(r["nudges"] >= 1, "the consented corner nudge still fires (%d)" % r["nudges"])
	_check(r["consent_violations"] == 0,
		"and it is not a consent violation, because the body was already moving that way (%d)" % r["consent_violations"])


## The invariant's own positive control, posed with the exact numbers the defect produced: no input, no
## incoming velocity, no recovery, and +6px of displacement. A guard is not trusted for reaching its
## check; it is trusted for firing (`docs/QUALITY.md`). Expressed as data rather than by reverting the
## fix so the control travels with the suite instead of living in one session's shell history.
func _test_the_consent_invariant_fires_on_the_displacement_the_defect_produced() -> void:
	var six_px: int = Body.CORNER_NUDGE_PX * Fx.SCALE
	var v: Invariants.TranslationConsentViolation = Invariants.check_translation_consent(
		0, 0, Fx.from_int(82), Fx.from_int(82) + six_px, false)
	_check(v != null, "the consent check fires on +6px with no input and no incoming velocity")
	_check(v != null and v.dx == six_px, "and reports the displacement itself, %d Fx" % [six_px])
	_check(Invariants.check_translation_consent(0, 0, Fx.from_int(82), Fx.from_int(82), false) == null,
		"and stays silent when nothing moved")


## The negative controls, one per exemption, so neither can be widened by accident. Each of the four
## clauses is checked alone, with the other three held at their firing values -- a single combined case
## would pass even if three of the four had stopped working.
func _test_the_consent_invariant_exempts_the_two_recovery_paths() -> void:
	var from_x: int = Fx.from_int(82)
	var to_x: int = from_x + Body.CORNER_NUDGE_PX * Fx.SCALE
	_check(Invariants.check_translation_consent(1, 0, from_x, to_x, false) == null,
		"horizontal input in the tick is consent")
	_check(Invariants.check_translation_consent(0, Fx.from_int(50), from_x, to_x, false) == null,
		"incoming horizontal velocity is consent (the body was already travelling)")
	_check(Invariants.check_translation_consent(0, 0, from_x, to_x, true) == null,
		"a depenetration or bounds correction accounts for its own displacement")
