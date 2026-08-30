extends "res://tests/test_base.gd"

## D0205. A climb owns its own tick's vertical state, and the tick may never end naming a grounding source
## while reporting the body airborne.
##
## The defect (D0202/D0203): `_try_step` placed the feet on a ledge, zeroed `vel_y` and set `on_floor` --
## and then the SAME tick's `_integrate_vertical` + `VerticalResolve.move_and_resolve` ran anyway,
## re-applying gravity to that zeroed velocity and clearing `on_floor` as its own first act. On a ledge
## narrower than the body's footprint nothing could re-establish the grounding, so the body sank into the
## cell it had just climbed onto. The tell was on screen for the whole investigation and nothing watched
## for it: `floor_source_this_tick == "try_step"` together with `on_floor == false`, which is a
## contradiction, because `_try_step` sets `on_floor = true` on the line beside it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_step_up_grounding.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
## The geometry from `tests/fixture_step_up_into_wall_probe.gd`, transcribed at the failing tick of the
## director's own session: a wall at column 6 for most of its height that juts to column 5 for the two
## rows at the body's feet. Kept as its own copy rather than imported, so this suite states the shape it
## is about instead of depending on a fixture that exists to be RETIRED when the wider defect is fixed.
const LEDGE_MAP: Array[String] = [
	"#############",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#....########",
	"#....########",
	"#############",
	"#############",
]


func _initialize() -> void:
	_test_a_step_up_tick_ends_grounded_and_not_embedded()
	_test_the_contradiction_is_impossible_across_a_whole_walk()
	_test_a_jump_is_the_one_exempt_producer_of_the_pair()
	_test_an_ordinary_fall_still_grounds_through_resolve_floor()
	_test_the_invariant_itself_fires_when_the_pair_is_posed_directly()
	_finish("step_up_grounding")


func _map_grid(map: Array[String]) -> TileGrid:
	var grid: TileGrid = TileGrid.new(map[0].length(), map.size(), 1)
	for row: int in map.size():
		for col: int in map[row].length():
			if map[row][col] == "#":
				grid.set_material(Vector2i(col, row), &"clay")
	return grid


## The tick that used to fail. Body at rest at the foot of the ledge, pressing toward it: `_try_step`
## fires, and the tick must END with that grounding intact rather than undone by the vertical pass.
func _test_a_step_up_tick_ends_grounded_and_not_embedded() -> void:
	var grid: TileGrid = _map_grid(LEDGE_MAP)
	var body: Body = Body.new(Fx.from_int(12), Fx.from_int(32))
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	body.tick(input, grid)
	print("  [OBSERVED] step-up tick: floor_source=%s on_floor=%s vel_y=%.2f overlap=%d"
		% [body.floor_source_this_tick, body.on_floor, float(body.vel_y) / float(Fx.SCALE),
		PropertyChecks.solid_overlap_count(body, grid)])
	_check(body.stepped_up_this_tick, "the geometry actually poses a step-up -- without this the rest passes on a tick that never climbed")
	_check(body.floor_source_this_tick == &"try_step",
		"the climb is what grounded the body (got %s)" % body.floor_source_this_tick)
	_check(body.on_floor, "and the tick ENDS grounded -- the vertical pass did not discard it")
	_check(body.vel_y == 0, "with vel_y still zero, so no gravity was applied to a body the climb had just settled (got %d)" % body.vel_y)
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0, "and the body is not inside rock (overlapping %d cells)" % PropertyChecks.solid_overlap_count(body, grid))


## The invariant itself, over a whole walk rather than one tick. This is the assertion that would have
## caught D0202 on the day it was introduced, stated as a property of every tick.
func _test_the_contradiction_is_impossible_across_a_whole_walk() -> void:
	var grid: TileGrid = _map_grid(LEDGE_MAP)
	var body: Body = Body.new(Fx.from_int(12), Fx.from_int(32))
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	var violations: int = 0
	var grounded_ticks: int = 0
	for _i: int in 60:
		body.tick(input, grid)
		if body.grounding_consistency_violation_this_tick:
			violations += 1
		if body.floor_source_this_tick != &"":
			grounded_ticks += 1
	print("  [OBSERVED] 60 ticks pressing into the ledge: %d grounding-consistency violations, %d ticks named a floor source"
		% [violations, grounded_ticks])
	_check(violations == 0,
		"no tick ends naming a grounding source while reporting the body airborne (%d did)" % violations)
	_check(grounded_ticks > 0,
		"and the run actually grounded on some of those ticks -- a body that never touched anything would satisfy the above vacuously (%d)"
		% grounded_ticks)


## The one legitimate producer of the pair, exempted by flag rather than by tolerance. A buffered jump
## fires AFTER the vertical resolve by design (the tick order's own comment calls it a one-tick
## touch-and-go), so a tick can land and launch, ending with a floor source and `on_floor` false. Without
## the exemption the invariant would fire on correct behaviour; without this test the exemption could be
## widened to anything at all and nothing would notice.
func _test_a_jump_is_the_one_exempt_producer_of_the_pair() -> void:
	var grid: TileGrid = _flat_grid(20, 40)
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(20 * CELL - Body.HEIGHT_PX / 2))
	var input: InputFrame = InputFrame.new()
	var jumped_with_source: int = 0
	var violations: int = 0
	for i: int in 40:
		input.jump_pressed = i % 12 == 0
		input.jump_held = i % 12 < 4
		body.tick(input, grid)
		if body.grounding_consistency_violation_this_tick:
			violations += 1
		if body.jumped_this_tick and body.floor_source_this_tick != &"" and not body.on_floor:
			jumped_with_source += 1
	print("  [OBSERVED] 40 ticks of repeated jumping: %d ticks both grounded and launched, %d violations"
		% [jumped_with_source, violations])
	_check(jumped_with_source > 0,
		"the run really does produce the exempt pair -- a jump landing and launching in one tick (%d); if this reads 0 the exemption is untested"
		% jumped_with_source)
	_check(violations == 0, "and the invariant stays silent on it (%d violations)" % violations)


## The control for the fix itself: skipping the vertical pass on a climb tick must not stop an ORDINARY
## fall from grounding. If this broke, every landing in the game would go through the wrong path and the
## tests above would still pass.
func _test_an_ordinary_fall_still_grounds_through_resolve_floor() -> void:
	var grid: TileGrid = _flat_grid(20, 40)
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(4 * CELL))
	var input: InputFrame = InputFrame.new()
	var landed_tick: int = -1
	for i: int in 200:
		body.tick(input, grid)
		if body.on_floor and landed_tick < 0:
			landed_tick = i
	print("  [OBSERVED] a plain fall onto flat ground: landed at tick %d, source=%s, overlap=%d"
		% [landed_tick, body.floor_source_this_tick, PropertyChecks.solid_overlap_count(body, grid)])
	_check(landed_tick >= 0, "a body dropped onto flat ground still lands")
	_check(body.on_floor and body.floor_source_this_tick == &"resolve_floor",
		"and rests grounded via resolve_floor, not via a climb (source %s)" % body.floor_source_this_tick)
	_check(not body.stepped_up_this_tick,
		"with no step-up involved -- this path is the one the fix must leave completely alone")
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0, "and it is not inside the floor (overlapping %d)" % PropertyChecks.solid_overlap_count(body, grid))


## THE POSITIVE CONTROL FOR THE INVARIANT, and the reason it exists: with the fix in place the resolver
## no longer produces the contradictory state, so every test above passes just as happily against an
## invariant that can never fire at all. Confirmed, not assumed -- mutating the guard to `if true: return`
## left the whole suite green until this test existed. The state is therefore POSED by hand and the check
## called directly, which is the only way to observe a guard whose subject the code has stopped emitting.
##
## The three exemption clauses get a negative control each, so the exemption cannot be quietly widened:
## a guard exempting everything would pass a positive-control-only test.
func _test_the_invariant_itself_fires_when_the_pair_is_posed_directly() -> void:
	var cases: Array = [
		{"src": &"try_step", "floor": false, "jumped": false, "want": true,
			"label": "a grounding source with the body airborne and no jump FIRES"},
		{"src": &"try_step", "floor": false, "jumped": true, "want": false,
			"label": "the same pair on a tick that jumped is exempt"},
		{"src": &"try_step", "floor": true, "jumped": false, "want": false,
			"label": "a grounding source with the body grounded is not a contradiction"},
		{"src": &"", "floor": false, "jumped": false, "want": false,
			"label": "airborne with no grounding source is ordinary flight"},
	]
	for c: Dictionary in cases:
		var body: Body = Body.new(Fx.from_int(40), Fx.from_int(40))
		body.floor_source_this_tick = c["src"]
		body.on_floor = c["floor"]
		body.jumped_this_tick = c["jumped"]
		body.grounding_consistency_violation_this_tick = false
		body._enforce_grounding_consistency()
		_check(body.grounding_consistency_violation_this_tick == bool(c["want"]),
			"%s (fired=%s, wanted %s)" % [c["label"], body.grounding_consistency_violation_this_tick, c["want"]])
