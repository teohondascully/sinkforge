extends "res://tests/test_base.gd"

## THE GRAPPLE'S SOLVER, alone against a chamber of terrain cells (A' step 5b, D0359): the properties
## legacy's `check_grapple`, `check_aim` and `check_wrap` read off the tool without a body -- it bites, a
## miss stows, the ghost agrees with the hook around the compass, the winch reels and pays, the constraint
## projects onto the circle and never outside it, the radial cancel keeps the tangent, the pump scales by
## the haul, the line wraps a spur and comes off it, a chained shot swaps the anchor only on a bite, and
## the whole state round-trips through capture. The body-coupled properties (swing speed, reel lift, the
## chasm, momentum kept) are `tests/test_grapple_body.gd`'s.

const S: int = Fx.SCALE
const W: int = 260           ## terrain cells: 1040 px, wide enough that a level shot runs OUT of line
const H: int = 120           ## 480 px
const CEIL_ROWS: int = 10    ## rows 0..9 solid: the ceiling's underside is y = 40 px
const FLOOR_ROW: int = 100   ## rows 100.. solid
const WALL: int = 4          ## cells of wall each side


func _initialize() -> void:
	_test_bites_the_ceiling()
	_test_miss_runs_out_of_line_and_stows()
	_test_trace_agrees_with_the_flight_around_the_compass()
	_test_reel_and_pay_out()
	_test_constraint_projects_onto_the_circle_never_outside()
	_test_velocity_keeps_the_tangent_and_drops_the_outward_part()
	_test_pump_scales_the_tangent_by_the_haul()
	_test_wraps_a_spur_and_unwraps()
	_test_chain_swaps_the_anchor_only_on_a_bite()
	_test_slack()
	_test_capture_restore_and_determinism()
	_finish("grapple")


func _chamber() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 1)
	for col: int in range(W):
		for row: int in range(H):
			if row < CEIL_ROWS or row >= FLOOR_ROW or col < WALL or col >= W - WALL:
				grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _px(x: int, y: int) -> Vector2i:
	return Vector2i(x * S, y * S)


## Fire and fly until the hook lands or stows; returns the ticks it took, or -1 for a stow.
func _shoot(g: Grapple, grid: TileGrid, from: Vector2i, toward: Vector2i, cap: int = 40) -> int:
	g.fire(from, toward)
	for i: int in cap:
		g.begin_tick()
		g.advance(grid, from)
		if g.state == Grapple.State.ANCHORED and not g.throwing():
			return i + 1
		if not g.live():
			return -1
	return -1


func _test_bites_the_ceiling() -> void:
	var grid: TileGrid = _chamber()
	var g: Grapple = Grapple.new()
	var from: Vector2i = _px(320, 300)
	var ticks: int = _shoot(g, grid, from, _px(320, 20))
	_check(g.state == Grapple.State.ANCHORED, "a shot at the ceiling ANCHORS")
	# 260 px of air at 30 px a tick: legacy's cap of 12 frames for 8 cells (256 px) ports as is.
	_check(ticks > 0 and ticks <= 12, "it bites within 12 ticks (took %d)" % ticks)
	_check(grid.is_solid(g.anchor_cell), "it anchored in a genuinely solid cell %s" % g.anchor_cell)
	_check(g.anchor.y <= 40 * S and g.anchor.y >= 40 * S - Grapple.PROBE,
		"the hook bit at its contact point, within one probe of the ceiling's underside (y=%d px)" % (g.anchor.y / S))
	var dist: int = Fx.length(g.anchor.x - from.x, g.anchor.y - from.y)
	_check(g.length == (dist * 9) / 10, "a fresh plant takes up a tenth of the slack (%d of %d px)" % [g.length / S, dist / S])
	_check(g.just_planted, "the plant tick raises just_planted")
	g.begin_tick()
	_check(not g.just_planted, "...and the next tick clears it")
	g.cut()
	_check(not g.live() and g.just_cut, "cutting the line stows it and raises just_cut")
	g.begin_tick()
	_check(not g.just_cut and g.pivots.is_empty(), "the cut one-shot clears; the pivots are gone")


func _test_miss_runs_out_of_line_and_stows() -> void:
	var grid: TileGrid = _chamber()
	var g: Grapple = Grapple.new()
	var from: Vector2i = _px(100, 200)
	var ticks: int = _shoot(g, grid, from, _px(200, 200))   # the far wall is 924 px off: out of line
	_check(ticks == -1 and not g.live(), "a shot that hits nothing runs out of line and stows")
	_check(g._flown == Grapple.MAX_RANGE, "it flew exactly the winch's line before stowing (%d px)" % (g._flown / S))
	var t: Dictionary = g.trace(grid, from, _px(200, 200))
	_check(not t["hit"], "trace agrees: nothing in range that way")


## Legacy `check_aim`: 48 shots around the compass, and the ghost must name the hook's cell every time.
func _test_trace_agrees_with_the_flight_around_the_compass() -> void:
	var grid: TileGrid = _chamber()
	var from: Vector2i = _px(520, 200)
	var wrong: int = 0
	var missed: int = 0
	var bites: int = 0
	for i: int in 48:
		var a: float = float(i) * TAU / 48.0
		var toward := Vector2i(from.x + int(cos(a) * 200.0 * S), from.y + int(sin(a) * 200.0 * S))
		var g: Grapple = Grapple.new()
		var t: Dictionary = g.trace(grid, from, toward)
		var ticks: int = _shoot(g, grid, from, toward)
		if t["hit"] != (ticks > 0):
			missed += 1
		elif t["hit"] and (t["cell"] != g.anchor_cell or t["at"] != g.anchor):
			wrong += 1
		if ticks > 0:
			bites += 1
	_check(bites > 0, "the rig gives the ghost something to find (%d of 48 bit)" % bites)
	_check(missed == 0, "the ghost and the hook agree on WHETHER a shot lands (%d disagreed)" % missed)
	_check(wrong == 0, "...and on WHERE, cell and contact point (%d differed)" % wrong)


func _test_reel_and_pay_out() -> void:
	var grid: TileGrid = _chamber()
	var g: Grapple = Grapple.new()
	var from: Vector2i = _px(320, 300)
	_shoot(g, grid, from, _px(320, 20))
	var before: int = g.length
	for _i: int in 10:
		g.reel(1)
	_check(g.length == before - 10 * Grapple.REEL_PER_TICK, "ten ticks of reel take in 70 px exactly")
	_check(g.hauled == Grapple.REEL_PER_TICK, "hauled reports the tick's take (7 px)")
	g.reel(-1)
	_check(g.length == before - 10 * Grapple.REEL_PER_TICK + Grapple.PAY_PER_TICK and g.hauled < 0,
		"paying out lengthens the line and hauled goes negative")
	g.reel(0)
	_check(g.hauled == 0, "no axis, no haul")
	for _i: int in 200:
		g.reel(1)
	_check(g.length == Grapple.MIN_LENGTH, "reeling floors at MIN_LENGTH")
	for _i: int in 200:
		g.reel(-1)
	_check(g.length == Grapple.MAX_RANGE, "paying out caps at MAX_RANGE")
	var idle: Grapple = Grapple.new()
	idle.reel(1)
	_check(idle.hauled == 0 and idle.length == 0, "a stowed line cannot be reeled")


func _rig_anchored(pin: Vector2i, len_px: int) -> Grapple:
	var g: Grapple = Grapple.new()
	g.state = Grapple.State.ANCHORED
	g.anchor = pin
	g.anchor_cell = Vector2i(pin.x / Grapple.CELL_FX, pin.y / Grapple.CELL_FX)
	g.length = len_px * S
	return g


func _test_constraint_projects_onto_the_circle_never_outside() -> void:
	var pin: Vector2i = _px(320, 40)
	var g: Grapple = _rig_anchored(pin, 100)
	var inside: Vector2i = _px(320, 120)
	_check(g.constrain_position_fx(inside) == inside and not g.taut, "a point inside the radius is untouched, line slack")
	var probes: Array = [_px(320, 200), _px(420, 140), _px(250, 300), _px(320 + 300, 40 - 200),
		Vector2i(pin.x + 1, pin.y + 200 * S), Vector2i(2147483647, pin.y + 1), Vector2i(pin.x - 1, -2147483648)]
	var outside: int = 0
	var short: int = 0
	var slack: int = 0
	for p: Vector2i in probes:
		var q: Vector2i = g.constrain_position_fx(p)
		var r: int = Fx.length(q.x - pin.x, q.y - pin.y)
		if r > 100 * S:
			outside += 1
		if r < 100 * S - 4:
			short += 1
		if not g.taut:
			slack += 1
	_check(outside == 0, "no projected point lies outside the circle (%d of %d did)" % [outside, probes.size()])
	_check(short == 0, "every projected point lies within 4 units of it (%d short)" % short)
	_check(slack == 0, "every projection reports the line taut (%d did not)" % slack)
	var below: Vector2i = g.constrain_position_fx(_px(320, 200))
	_check(below == _px(320, 140), "straight below, the projection is exact: 100 px under the pin (got %s)" % below)
	var idle: Grapple = Grapple.new()
	_check(idle.constrain_position_fx(_px(9, 9)) == _px(9, 9), "a stowed line constrains nothing")


func _test_velocity_keeps_the_tangent_and_drops_the_outward_part() -> void:
	var pin: Vector2i = _px(320, 40)
	var g: Grapple = _rig_anchored(pin, 100)
	var pos: Vector2i = g.constrain_position_fx(_px(320, 200))
	_check(g.resolve_velocity_fx(pos, 100 * S, 50 * S) == Vector2i(100 * S, 0),
		"hanging straight down, (100, 50) keeps its 100 across and loses the 50 outward")
	_check(g.resolve_velocity_fx(pos, 100 * S, -50 * S) == Vector2i(100 * S, -50 * S),
		"...and an inward 50 is left alone")
	_check(g.resolve_velocity_fx(pos, -300 * S, 0) == Vector2i(-300 * S, 0), "pure tangent survives whole")
	var diag: Vector2i = g.constrain_position_fx(pin + _px(200, 200))
	var v: Vector2i = g.resolve_velocity_fx(diag, 10 * S, 10 * S)
	_check(Fx.length(v.x, v.y) <= 4, "on the diagonal a purely outward push is cancelled to within 4 units (left %d)" % Fx.length(v.x, v.y))
	g.taut = false
	_check(g.resolve_velocity_fx(pos, 0, 50 * S) == Vector2i(0, 50 * S), "a slack line cancels nothing")


func _test_pump_scales_the_tangent_by_the_haul() -> void:
	var pin: Vector2i = _px(320, 40)
	var g: Grapple = _rig_anchored(pin, 100)
	var pos: Vector2i = g.constrain_position_fx(_px(320, 200))
	g.hauled = 7 * S
	_check(g.pump_fx(pos, 100 * S, 0) == Vector2i(105 * S, 0),
		"7 px hauled on a 100 px radius asks 1.07 and the clamp gives 21/20: 100 -> 105 exactly")
	_check(g.pump_fx(pos, 0, 50 * S) == Vector2i(0, 50 * S), "the radial part is not pumped")
	g.hauled = -7 * S
	var paid: Vector2i = g.pump_fx(pos, 100 * S, 0)
	_check(paid.x < 100 * S and paid.x >= 95 * S, "paying out brakes the tangent by the same law, floored at 20/21 (got %d px/s)" % (paid.x / S))
	g.hauled = 2 * S
	_check(g.pump_fx(pos, 100 * S, 0) == Vector2i(102 * S, 0), "under the clamp the ratio is the haul's own: 102/100")
	g.hauled = 0
	_check(g.pump_fx(pos, 100 * S, 0) == Vector2i(100 * S, 0), "no haul, no pump")
	g.taut = false
	g.hauled = 7 * S
	_check(g.pump_fx(pos, 100 * S, 0) == Vector2i(100 * S, 0), "a slack line does not pump")


## Legacy `check_wrap`: a spur juts from the wall between the hook and the body; the line must BEND around
## it rather than hang through it, and come off again when the body swings back.
func _test_wraps_a_spur_and_unwraps() -> void:
	var grid: TileGrid = _chamber()
	for col: int in range(82, 96):
		for row: int in range(20, 22):
			grid.set_material(Vector2i(col, row), &"hardrock")   # a shelf at y 80..88 px, x 328..384
	var g: Grapple = _rig_anchored(_px(320, 40), 200)
	var above: Vector2i = _px(400, 60)
	g.update_line(grid, above)
	_check(g.pivots.is_empty(), "a straight run over the spur catches nothing")
	var below: Vector2i = _px(400, 140)
	g.update_line(grid, below)
	_check(g.pivots.size() == 1, "swinging under the spur's tip catches the line on it (%d pivots)" % g.pivots.size())
	_check(g.hitch_fx() != g.anchor and g.spent() > 0, "the hitch moves to the corner and the fixed segment spends line (%d px)" % (g.spent() / S))
	_check(g.free_length() == g.length - g.spent(), "free length is what the swing has left")
	_check(not g._blocked(grid, g.hitch_fx(), below), "the line from the hitch to the body is clear of rock")
	# The line runs from (320, 40) toward (400, 140) and meets the shelf's TOP face at x = 352: the
	# catch is the corner of that entry cell nearest the last clear sample, nudged 2 px back along the
	# line -- legacy's rule, which catches where the rope first touches rock, not at the shelf's tip.
	var p: Vector2i = g.pivots[0]
	_check(p.x >= 346 * S and p.x <= 356 * S and p.y >= 76 * S and p.y <= 82 * S,
		"the pivot sits at the shelf's top-face entry corner, nudged off it (%d, %d px)" % [p.x / S, p.y / S])
	g.update_line(grid, above)
	_check(g.pivots.is_empty(), "...and it COMES OFF again when the body swings back over the spur")
	var stowed: Grapple = Grapple.new()
	stowed.update_line(grid, below)
	_check(stowed.pivots.is_empty(), "a stowed line wraps nothing")


func _test_chain_swaps_the_anchor_only_on_a_bite() -> void:
	var grid: TileGrid = _chamber()
	var g: Grapple = Grapple.new()
	var from: Vector2i = _px(320, 300)
	_shoot(g, grid, from, _px(320, 20))
	var old_anchor: Vector2i = g.anchor
	g.fire(from, _px(520, 300))          # level: out of line, a chained MISS
	_check(g.state == Grapple.State.ANCHORED and g.throwing(), "firing while anchored chains: still anchored, a hook in the air")
	for _i: int in 20:
		g.begin_tick()
		g.advance(grid, from)
	_check(g.state == Grapple.State.ANCHORED and g.anchor == old_anchor and not g.throwing(),
		"a chained miss leaves the body on the line it was already on")
	g.fire(from, _px(420, 20))           # a second ceiling point: a chained BITE
	var ticks: int = 0
	while g.throwing() and ticks < 40:
		g.begin_tick()
		g.advance(grid, from)
		ticks += 1
	_check(g.state == Grapple.State.ANCHORED and g.anchor != old_anchor, "a chained bite swaps the anchor (%d ticks)" % ticks)
	var dist: int = Fx.length(g.anchor.x - from.x, g.anchor.y - from.y)
	_check(g.length == dist, "...taking the distance as it is: no slack take-up at the swap (%d == %d px)" % [g.length / S, dist / S])
	_check(g.just_planted, "the swap is a plant")


func _test_slack() -> void:
	var g: Grapple = _rig_anchored(_px(320, 40), 100)
	_check(g.slack_permille(_px(320, 140)) == 0, "at full radius the line is bar-taut")
	_check(g.slack_permille(_px(320, 90)) == 500, "at half radius it is half slack")
	_check(g.slack_permille(_px(320, 40)) == 1000, "at the pin it is fully slack")
	_check(Grapple.new().slack_permille(_px(0, 0)) == 0, "a stowed line has no sag")


func _drive(g: Grapple, grid: TileGrid) -> void:
	var from: Vector2i = _px(320, 300)
	g.fire(from, _px(360, 20))
	for i: int in 12:
		g.begin_tick()
		g.advance(grid, from)
		g.reel(1 if i % 3 == 0 else -1)
		var pos: Vector2i = _px(320 + i * 9, 300 - i * 5)
		g.update_line(grid, pos)
		pos = g.constrain_position_fx(pos)
		g.resolve_velocity_fx(pos, 100 * S, 20 * S)
		g.pump_fx(pos, 100 * S, 20 * S)


func _test_capture_restore_and_determinism() -> void:
	var grid: TileGrid = _chamber()
	var a: Grapple = Grapple.new()
	var b: Grapple = Grapple.new()
	_drive(a, grid)
	_drive(b, grid)
	_check(a.state == Grapple.State.ANCHORED, "the drive anchored")
	_check(a.state_signature() == b.state_signature(), "two identical drives sign identically")
	var c: Grapple = Grapple.new()
	c.restore(a.capture())
	_check(c.state_signature() == a.state_signature(), "capture/restore round-trips the signature")
	_check(c.capture() == a.capture(), "...and the capture itself")
	c.reel(1)
	_check(c.state_signature() != a.state_signature(), "a reel changes the signature")
	var fresh: Grapple = Grapple.new()
	_check(fresh.state_signature() != a.state_signature(), "a stowed line signs differently from a live one")
	_check(fresh.capture()["pivots"].is_empty() and fresh.capture()["state"] == 0, "a fresh capture is the stowed state")
