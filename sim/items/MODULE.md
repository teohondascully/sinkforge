# sim/items

## Purpose

Item instances as packed arrays: falling, settling, pile state, pickup.
The foundational data structure for "a physical thing exists in the
world" — analogous to what `world` is for tiles. Other gameplay modules
(behaviors, transport, machines, economy) consume it to do their jobs.

## Must-not

- Own transport policy. How and whether an item moves through a chute or a
  powered lift (cost, direction, rate) belongs to `sim/transport`; `items`
  only holds the instances and their basic physical state (falling,
  settling into a pile, being picked up).

## Dependencies

`core`, `world` (falling/settling/pickup all query tile occupancy and
solidity to know where an item can rest), `data` (the pack's two numbers,
`data/player/pack.yaml`). NOT `machines`: a machine's input buffer is reached
through a `Callable` the owner supplies (`Items.machine_buffer`,
`Items.machine_total`), so the landing rule can cascade into a machine
without this module knowing one exists.

## Source

Lifted in A′ step 3c (D0348) from `legacy/src/core/factory_sim.gd`: the
`inventory`/`ground`/`sink` dictionaries and the ledger, `take_into_pack`
(THE ONE DOOR into the pack), `_spill_to_world`, `drop_item`, `collect_ground`,
`_resettle_pile_above`, `_column_landing`, `take_lode`, `deposit`, and the pack
half of every world verb (spend on place, recover on removal).

## Consumers

`interface`, at minimum. Sim-internal: `behaviors` (primitives consume and
produce item instances), `transport` (moves item instances per R1),
`machines` (machines consume/produce items via behaviors), `economy`
(haul accounting and conversion operate on item quantities), `invariants`
(matter conservation, non-negative buffers, "no items inside solid rock"
all read item state), `run` (extraction resolution counts hauled items).

## Tick phase

`items` (5th phase — after `transport`, so this phase resolves physical
falling/settling/piling for anything not already claimed by a transport
mechanism that tick).

## Public API

- `Pack` (`pack.gd`) — the carried items and the bulk cap. `Pack.inventory_slots()`/`bulk_cap()` (from
  data), `.count()`, `.add()` (uncapped), `.remove() → removed`, `.slots()` (hotbar order = pickup order,
  which is state), `.ids()` (text order), `Pack.is_bulk_item()` (everything but a placeable machine),
  `.carried_bulk()`, `.pack_room()`, `.can_carry()`, running signature, `.clone()`.
- `GroundPiles` (`ground_piles.gd`) — `ground` (logic_cell → live `{item → count}`) and `sink`.
  `.pile(cell)` (live, created on first landing), `.has_pile()`, `.count_at()`, `.prune_empty()`,
  `.present(item)`, `.pile_logic_cells()`, from-scratch `.recomputed_signature()` (live inner
  dictionaries cannot pass a sandwich), `.clone()`.
- `Landing` (`landing.gd`) — `Landing.column_landing(world, piles, machine_buffer, col, start_row) →
  {to_cell, target}`: the first machine below catches, else the metre above the first rock, else the
  sink. No slope roll (ADR 0009's deferred list).
- `Items` (`items.gd`) — THE SERVICE: `pack`, `piles`, `total_produced`/`total_consumed`, `flow_events`
  (view channel, never read back), `last_drop_landing`, `machine_buffer`/`machine_total` Callables.
  `.take_into_pack(item, n, spill_at) → taken` (the rest spills), `.drop_item()`, `.collect_ground()`
  (capped too), `.resettle_pile_above()`, `.take_lode(terrain_cell)` (refuses a full pack), `.deposit()`,
  `.present(item)`, `.produced()`/`.consumed()`, `.state_signature()`.
- `BuildVerbs` (`build_verbs.gd`) — static over `Items`: `place_block`, `place_conduit`/`remove_conduit`,
  `place_rope → hung`/`retract_rope`/`remove_rope`, `place_torch`/`remove_torch`,
  `plant_sapling`/`remove_sapling` (a full pack leaves it planted). Spend = consumed, recover = produced.
- `Invariants.check_item_conservation(items, tick)`: present == produced − consumed for every item.

## Gotchas

- **Piles are live dictionaries mutated in place** (legacy's shape), so `GroundPiles` has no running
  signature — only the from-scratch one. `Items.state_signature()` joins the pack's lanes, the piles'
  rebuild and the ledger.
- **A full pack does not refuse the swing** (`take_into_pack` spills) but **does refuse the lode**
  (`take_lode`): a lode face is not destroyed by being worked, so there is no homeless material.
