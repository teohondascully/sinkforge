class_name HubTick
extends RefCounted

## THE HUB TICK: legacy `FactorySim.tick()` (`legacy/src/core/factory_sim.gd`, the body at `func tick`),
## lifted in A' step 3d (D0349) as the fixed order the machine and fluid systems advance in. Stateless;
## the state is in the three services it is handed.
##
## CADENCE. Legacy's hub ran at 20 Hz on its own clock. This one runs on the body's 60 Hz tick, every
## `HUB_TICK_DIVISOR`th tick (D0345: a verbatim port, the numbers in `data/` unchanged), so the hub is a
## phase of the one tick rather than a second clock (ADR 0005). `advance` is the hook the body tick calls
## with its tick index; `step` is one hub tick, which tests drive directly the way legacy's did.
##
## Order, as legacy's: power field, each machine in placement order, item flow between machines
## (`Flow`, D0350), water, (seep, flora: rulings pending), prune empty piles, (production sampling:
## economy).

const HUB_TICK_DIVISOR: int = 3


static func advance(body_tick: int, world: World, items: Items, machines: Machines) -> bool:
	if body_tick % HUB_TICK_DIVISOR != 0:
		return false
	step(world, items, machines)
	return true


static func step(world: World, items: Items, machines: Machines) -> void:
	machines.power = PowerFlow.compute(world, machines)
	for m: MachineState in machines.machines:
		Runners.run(m, world, items, machines)
	Flow.step(world, items, machines)
	WaterFlow.step(world.water, world.grid)
	items.piles.prune_empty()
