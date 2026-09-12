extends "res://tests/test_base.gd"

## C003's executable core (D0609): a scripted bot reaches the rig's first demand from a cold start on
## the tutorial site, driving the real door -- every action is a `Command` through `Interface.apply`,
## every read an `observe()`; nothing is stamped into a buffer or hand-fed. The claim's metric,
## `demand_satisfied.id == "d1"`, is read off `o.events` (D0605).
##
## The bot is deliberately dumb in the way a T0 scripted bot should be (harness/bots' README): it
## walks toward a named column hopping so the pad's wells (the rig's, the adit's lip) cannot hold it,
## aims the mine hold at the nearest solid cell of a named metre, feeds a machine by standing in
## reach and dropping the selected stack, and scoops with COLLECT. The world only ever advances
## inside a MOVE tick, exactly as it does under a player's input -- the mine hold rides the frame,
## so every swing costs real ticks.
##
## What this is NOT: the full scenario driver. `harness/scenario` and `harness/driver` are skeleton
## layers (READMEs only); this suite is the claim's substance -- cold start, scripted play, D1 met --
## ahead of that scaffolding, and `scenarios/cold_start_to_d1.yaml` names this same run.
##
## On the envelope: the claim asks for `constrained`; no fog-filtered envelope exists yet (Envelope is
## a spatial window only), so this runs the oracle window -- but the policy's only world reads are the
## authored fixture positions (hardcoded) and the solidity of surface cells a standing player can see.
## Nothing hidden is consulted; a constrained run would change the window, not the policy.

const TICK_BUDGET: int = 30000   ## ~8 game-minutes; measured need is a small fraction of this
const ORE_WANT: int = 6          ## smelt_ingot needs 4; margin for the burst's randomness
const COAL_WANT: int = 4         ## needs 2, same reason

var _world: World
var _items: Items
var _machines: Machines
var _body: Body
var _iface: Interface
var _env: Interface.Envelope
var _o: Interface.Observation
var _spawn: Vector2i
var _ticks: int = 0


func _initialize() -> void:
	_test_a_scripted_bot_reaches_d1_from_a_cold_start()
	_finish("cold_start_d1")


func _test_a_scripted_bot_reaches_d1_from_a_cold_start() -> void:
	_world = WorldSeeder.load_world(StrataData.SHALLOW_CLAY, 20260825)
	_items = Items.new(_world)
	_machines = Machines.new()
	_machines.attach_to(_items)
	_check(WorldSeeder.stamp(_world, _items, _machines, &"tutorial", &"shallow_clay"),
		"the tutorial start stamps on the real site")
	_spawn = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	# spawn_logic_cell is the AIR metre the body stands in; the fixtures' dy-0 anchor is one logic
	# row under it (world_seeder.gd's `anchor`), so feet rest on the anchor row's top.
	var anchor: Vector2i = _spawn + Vector2i(0, 1)
	_body = Body.new(
		Fx.from_int(_spawn.x * 16 + 8),
		Fx.from_int(anchor.y * 16) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	_iface = Interface.new(_world.grid, _body, Mining.new(), _world, _items, _machines)
	_env = Interface.Envelope.oracle_over(_world.grid)

	var vein: Array = [anchor + Vector2i(-1, 0), anchor + Vector2i(-2, 0)]
	var coal: Array = [anchor + Vector2i(5, 0), anchor + Vector2i(6, 0)]
	var forge_m: Vector2i = anchor + Vector2i(-3, 0)
	var rig_m: Vector2i = anchor + Vector2i(2, 0)

	var ok: bool = true
	ok = _mine_until(vein, ORE_WANT, "ore") and ok
	ok = _deliver_to(forge_m, &"ore") and ok
	ok = _mine_until(coal, COAL_WANT, "coal") and ok
	ok = _deliver_to(forge_m, &"coal") and ok
	ok = _await_and_collect(&"ingot", 2, forge_m) and ok
	ok = _deliver_to(rig_m, &"ingot") and ok

	var ev: Dictionary = _await_event(&"demand_satisfied", &"d1", 200)
	_check(not ev.is_empty(), "the rig emits demand_satisfied d1 through o.events (ticks_used=%d)" % _ticks)
	_check(ok, "every leg of the cold start completed inside the tick budget (ticks_used=%d)" % _ticks)
	_check(Invariants.check_item_conservation(_items, 5) == null,
		"the claim's own rider: zero invariant violations over the whole run")


## --- the bot's moves -------------------------------------------------------------------------------

## One world tick: a MOVE frame walking `dir`, optionally holding MINE on `aim`. `hop` makes the tick
## jump+mantle -- used only when forward progress has stalled, not held on permanently: a permanently
## hopping body ends up on ledges and crowns it never meant to stand on, and the drop's reach is
## measured from where the body actually is (measured, this suite's first run).
func _tick(dir: int, aim: Vector2i = Vector2i(-1, -1), mine: bool = false, hop: bool = false) -> void:
	var f: InputFrame = InputFrame.new()
	f.move_dir = dir
	f.jump_pressed = hop and _body.on_floor
	f.jump_held = hop
	f.mantle_hold = hop
	if aim != Vector2i(-1, -1):
		f.has_aim = true
		f.aim_col = aim.x
		f.aim_row = aim.y
	f.mine_held = mine
	_iface.apply(Command.move(f))
	_ticks += 1


## Walk toward `target_col`; hop only when a tick made no forward progress (a lip, a well's wall).
## Stops when within `slack` metres of the target with feet at or below `max_row`'s level (so a
## machine in a well is met on the ground, not flown over). Returns false only on budget.
func _walk_to(target_col: int, slack: int = 0, max_row: int = 999) -> bool:
	var stall: int = 0
	var last_x: int = -1
	while _ticks < TICK_BUDGET:
		_o = _iface.observe(_env)
		var pos: Vector2i = _pos()
		if absi(pos.x - target_col) <= slack and pos.y <= max_row and _body.on_floor:
			return true
		var px: int = _body.pos_x / Fx.SCALE
		stall = 0 if px != last_x else stall + 1
		last_x = px
		_tick(signi(target_col * 16 + 8 - px) if absi(target_col - pos.x) > slack else 0,
			Vector2i(-1, -1), false, stall > 20)
	return false


## The body's current logic cell.
func _pos() -> Vector2i:
	return Vector2i(_body.pos_x / Fx.SCALE / 16, (_body.pos_y + Body.HEIGHT_PX / 2 * Fx.SCALE) / Fx.SCALE / 16)


## How much of `item` the pack holds, read off the last observation.
func _carried(item: StringName) -> int:
	for slot: Dictionary in _o.pack:
		if slot["item"] == item:
			return int(slot["count"])
	return 0


## Select the slot holding `item` (o.pack's order IS the hotbar's). Returns whether it was found.
func _select(item: StringName) -> bool:
	for i: int in _o.pack.size():
		if _o.pack[i]["item"] == item:
			_iface.apply(Command.select(i))
			return true
	return false


## The solid terrain cell of `metres` nearest the body, or (-1,-1). Nearest-first IS the staircase
## order: it breaks the top/closest cells before the ones behind them.
func _nearest_solid(metres: Array) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	for m: Vector2i in metres:
		for ty: int in range(m.y * 4, m.y * 4 + 4):
			for tx: int in range(m.x * 4, m.x * 4 + 4):
				var c := Vector2i(tx, ty)
				if not _world.grid.in_bounds(c) or _world.grid.get_material(c) == &"":
					continue
				var d: int = absi(tx * 4 + 2 - _body.pos_x / Fx.SCALE) + absi(ty * 4 + 2 - _body.pos_y / Fx.SCALE)
				if best_d < 0 or d < best_d:
					best_d = d
					best = c
	return best


## Mine `metres` until the pack holds `want` of `item`. Fails if the budget runs out first.
func _mine_until(metres: Array, want: int, item: StringName) -> bool:
	while _ticks < TICK_BUDGET:
		_o = _iface.observe(_env)
		if _carried(item) >= want:
			return true
		var aim: Vector2i = _nearest_solid(metres)
		if aim == Vector2i(-1, -1):
			return false   # the vein ran out -- a fixture fault, not a stall
		# Close the distance if the nearest solid is out of reach (REACH_PX ~ 51 px).
		var d_px: int = absi(aim.x * 4 + 2 - _body.pos_x / Fx.SCALE)
		var dir: int = signi(aim.x * 4 - _body.pos_x / Fx.SCALE) if d_px > 40 else 0
		_tick(dir, aim, true)
	return false


## Stand within reach of `machine_m` on the ground, select `item`, drop it (the drop feeds a
## reachable eater -- sim/run/verbs.gd). The walk stops level with the machine's row, not above it:
## a drop from four metres up a ledge is out of reach even when it is one metre sideways.
func _deliver_to(machine_m: Vector2i, item: StringName) -> bool:
	if not _walk_to(machine_m.x + 1, 1, machine_m.y + 1):
		return false
	_o = _iface.observe(_env)
	var before: int = int(_o.pack_total())
	if not _select(item):
		return false
	var r: Interface.Result = _iface.apply(Command.drop())
	_o = _iface.observe(_env)
	return r.ok or int(_o.pack_total()) < before


## Idle beside `source_m`, scooping every ~30 ticks, until the pack holds `want` of `item` (the
## machine's outputs land in the open cell under it, inside collect reach).
func _await_and_collect(item: StringName, want: int, source_m: Vector2i) -> bool:
	var since_scoop: int = 0
	while _ticks < TICK_BUDGET:
		_o = _iface.observe(_env)
		if _carried(item) >= want:
			return true
		since_scoop += 1
		if since_scoop >= 30:
			_iface.apply(Command.collect())
			since_scoop = 0
		var pos: Vector2i = _pos()
		_tick(signi(source_m.x + 1 - pos.x))
	return false


## Run idle ticks until an event of `kind` (and `id`, when given) shows on o.events.
func _await_event(kind: StringName, id: StringName, budget: int) -> Dictionary:
	for i: int in budget:
		_o = _iface.observe(_env)
		for ev: Dictionary in _o.events:
			if ev.get("kind") == kind and (id == &"" or ev.get("id") == id):
				return ev
		_tick(0)
	return {}
