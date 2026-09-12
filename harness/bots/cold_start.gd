class_name ColdStartBot
extends RefCounted

## The scripted T0 policy for `cold_start` scenarios (D0620). Deliberately dumb in the way a T0
## scripted bot should be (this dir's README): it walks toward a named column hopping so the pad's
## wells cannot hold it, aims the mine hold at the nearest solid cell of a named metre, feeds a
## machine by standing in reach and dropping the selected stack, and scoops with COLLECT. The world
## only ever advances inside a MOVE tick, exactly as it does under a player's input -- the mine hold
## rides the frame, so every swing costs real ticks.
##
## The route is C003's: mine the tutorial vein, feed the forge, mine coal, feed the forge, collect
## the ingots, deliver them to the rig. Its world reads are the authored fixture positions and the
## solidity of surface cells a standing player can see -- nothing hidden, so a constrained envelope
## would change the window, not the policy.

var world: World
var items: Items
var body: Body
var iface: Interface
var env: Interface.Envelope
var o: Interface.Observation
var budget: int = 30000
var ticks: int = 0

const ORE_WANT: int = 6    ## smelt_ingot needs 4; margin for the burst's randomness
const COAL_WANT: int = 4   ## needs 2, same reason


func _init(p_budget: int) -> void:
	budget = p_budget


func attach(p_world: World, p_items: Items, p_body: Body, p_iface: Interface, p_env: Interface.Envelope) -> void:
	world = p_world
	items = p_items
	body = p_body
	iface = p_iface
	env = p_env


## The route. `anchor` is the fixture's dy-0 logic cell (one row under the spawn air metre).
## Returns {legs_ok}: every leg completed inside the budget. Named `execute`, not `run` --
## check_claim_references reads `func run(` as a check-registering file and this is a policy.
func execute(anchor: Vector2i) -> Dictionary:
	var vein: Array = [anchor + Vector2i(-1, 0), anchor + Vector2i(-2, 0)]
	var coal: Array = [anchor + Vector2i(5, 0), anchor + Vector2i(6, 0)]
	var forge_m: Vector2i = anchor + Vector2i(-3, 0)
	var rig_m: Vector2i = anchor + Vector2i(2, 0)
	var ok: bool = true
	ok = mine_until(vein, ORE_WANT, "ore") and ok
	ok = deliver_to(forge_m, &"ore") and ok
	ok = mine_until(coal, COAL_WANT, "coal") and ok
	ok = deliver_to(forge_m, &"coal") and ok
	ok = await_and_collect(&"ingot", 2, forge_m) and ok
	ok = deliver_to(rig_m, &"ingot") and ok
	return {"legs_ok": ok, "ticks": ticks}


## One world tick: a MOVE frame walking `dir`, optionally holding MINE on `aim`. `hop` makes the tick
## jump+mantle -- used only when forward progress has stalled, not held on permanently: a permanently
## hopping body ends up on ledges and crowns it never meant to stand on, and the drop's reach is
## measured from where the body actually is.
func tick(dir: int, aim: Vector2i = Vector2i(-1, -1), mine: bool = false, hop: bool = false) -> void:
	var f: InputFrame = InputFrame.new()
	f.move_dir = dir
	f.jump_pressed = hop and body.on_floor
	f.jump_held = hop
	f.mantle_hold = hop
	if aim != Vector2i(-1, -1):
		f.has_aim = true
		f.aim_col = aim.x
		f.aim_row = aim.y
	f.mine_held = mine
	iface.apply(Command.move(f))
	ticks += 1


## Walk toward `target_col`; hop only when a tick made no forward progress. Stops when within `slack`
## metres of the target with feet at or below `max_row`'s level. Returns false only on budget.
func walk_to(target_col: int, slack: int = 0, max_row: int = 999) -> bool:
	var stall: int = 0
	var last_x: int = -1
	while ticks < budget:
		o = iface.observe(env)
		var p: Vector2i = pos()
		if absi(p.x - target_col) <= slack and p.y <= max_row and body.on_floor:
			return true
		var px: int = body.pos_x / Fx.SCALE
		stall = 0 if px != last_x else stall + 1
		last_x = px
		tick(signi(target_col * 16 + 8 - px) if absi(target_col - p.x) > slack else 0,
			Vector2i(-1, -1), false, stall > 20)
	return false


## The body's current logic cell.
func pos() -> Vector2i:
	return Vector2i(body.pos_x / Fx.SCALE / 16, (body.pos_y + Body.HEIGHT_PX / 2 * Fx.SCALE) / Fx.SCALE / 16)


## How much of `item` the pack holds, read off the last observation.
func carried(item: StringName) -> int:
	for slot: Dictionary in o.pack:
		if slot["item"] == item:
			return int(slot["count"])
	return 0


## Select the slot holding `item` (o.pack's order IS the hotbar's). Returns whether it was found.
func select(item: StringName) -> bool:
	for i: int in o.pack.size():
		if o.pack[i]["item"] == item:
			iface.apply(Command.select(i))
			return true
	return false


## The solid terrain cell of `metres` nearest the body, or (-1,-1). Nearest-first IS the staircase
## order: it breaks the top/closest cells before the ones behind them.
func nearest_solid(metres: Array) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	for m: Vector2i in metres:
		for ty: int in range(m.y * 4, m.y * 4 + 4):
			for tx: int in range(m.x * 4, m.x * 4 + 4):
				var c := Vector2i(tx, ty)
				if not world.grid.in_bounds(c) or world.grid.get_material(c) == &"":
					continue
				var d: int = absi(tx * 4 + 2 - body.pos_x / Fx.SCALE) + absi(ty * 4 + 2 - body.pos_y / Fx.SCALE)
				if best_d < 0 or d < best_d:
					best_d = d
					best = c
	return best


## Mine `metres` until the pack holds `want` of `item`. Fails if the budget runs out first.
func mine_until(metres: Array, want: int, item: StringName) -> bool:
	while ticks < budget:
		o = iface.observe(env)
		if carried(item) >= want:
			return true
		var aim: Vector2i = nearest_solid(metres)
		if aim == Vector2i(-1, -1):
			return false   # the vein ran out -- a fixture fault, not a stall
		var d_px: int = absi(aim.x * 4 + 2 - body.pos_x / Fx.SCALE)
		var dir: int = signi(aim.x * 4 - body.pos_x / Fx.SCALE) if d_px > 40 else 0
		tick(dir, aim, true)
	return false


## Stand within reach of `machine_m` on the ground, select `item`, drop it. The walk stops level
## with the machine's row, not above it: a drop from four metres up a ledge is out of reach even
## when it is one metre sideways.
func deliver_to(machine_m: Vector2i, item: StringName) -> bool:
	if not walk_to(machine_m.x + 1, 1, machine_m.y + 1):
		return false
	o = iface.observe(env)
	var before: int = int(o.pack_total())
	if not select(item):
		return false
	var r: Interface.Result = iface.apply(Command.drop())
	o = iface.observe(env)
	return r.ok or int(o.pack_total()) < before


## Idle beside `source_m`, scooping every ~30 ticks, until the pack holds `want` of `item`.
func await_and_collect(item: StringName, want: int, source_m: Vector2i) -> bool:
	var since_scoop: int = 0
	while ticks < budget:
		o = iface.observe(env)
		if carried(item) >= want:
			return true
		since_scoop += 1
		if since_scoop >= 30:
			iface.apply(Command.collect())
			since_scoop = 0
		var p: Vector2i = pos()
		tick(signi(source_m.x + 1 - p.x))
	return false
