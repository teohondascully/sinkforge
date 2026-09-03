class_name LodeWork
extends RefCounted

## WORKING A LODE BY HAND: the second kind of work through the one hold (`docs/LODE.md` §5 in legacy).
## Rock breaks: a charge that ends in a cell vanishing, banked on the cell. A lode is worked: a short
## repeating cycle that yields a unit and changes nothing, so there is nothing to bank and nothing to
## crack, and the payout is the progress read. The cadence and the rhythm are the miner's, shared with
## `Mining`. Lifted in A' step 3i (D0354) from `legacy/scenes/main.gd` `_update_mining`'s lode branch
## (1522-1624) and `try_work_lode` 1963; `LODE_CYCLE` 0.55 s is 33 ticks at 60 Hz.
##
## STATE: the target and its charge, signed. Not banked: moving to a fresh face starts the cycle over.

const LODE_CYCLE_TICKS: int = 33
const CYCLE_COST: int = LODE_CYCLE_TICKS * Mining.CHARGE_UNIT

var target: Vector2i = Mining.NO_CELL
var charge: int = 0
var took_this_tick: StringName = &""


## One tick of the hold on a lode face. Returns the unit taken this tick, or &"". The face must be
## workable (an open cell with a lode behind it and something left), in reach and in sight; the pack
## must have room, since `take_lode` refuses rather than spills (D0348) -- a full pack simply stalls the
## cycle at full charge until room is made.
func work(world: World, items: Items, mining: Mining, body_x: int, body_y: int, face: Vector2i, held: bool) -> StringName:
	took_this_tick = &""
	var body_cell: Vector2i = Aim.cell_of(body_x, body_y)
	var workable: bool = held and world.deposits.lode_workable(world.grid, face) \
		and Mining.in_reach(body_x, body_y, face) and LineOfSight.clear(world.grid, body_cell, face)
	if not workable:
		target = Mining.NO_CELL
		charge = 0
		return &""
	if face != target:
		target = face
		charge = 0
	charge += Mining.CHARGE_UNIT + (Mining.CHARGE_UNIT * mining.rhythm()) / Mining.RHYTHM_SPEED_DEN
	if charge < CYCLE_COST:
		return &""
	took_this_tick = items.take_lode(face)
	if took_this_tick != &"":
		charge = 0
	return took_this_tick


## Progress toward the next unit, per mille, for the view's read.
func progress_per_mille() -> int:
	return clampi(charge * 1000 / CYCLE_COST, 0, 1000)


func state_signature() -> String:
	return "l%d,%d:%d" % [target.x, target.y, charge]
