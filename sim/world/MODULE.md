# sim/world

## Purpose

Tile grid, chunks, material IDs, hardness, terrain queries and mutations.
The single source of truth for "what is at this cell" — solid rock, an
excavated void, what material, how hard it is to dig. Foundational: nearly
every other gameplay submodule queries or mutates it.

## Must-not

- Know about machines. No machine types, no machine placement concepts.
- Know about items. No item instances, no item types.

## Dependencies

`core` only.

## Consumers

`interface`, at minimum. Sim-internal: `terrain_gen` (writes generated
tiles), `body` (collision/depenetration/step-up against tile solidity),
`items` (falling/settling/pickup query tile occupancy), `behaviors`
(primitives that mutate terrain, e.g. an extraction primitive), `transport`
(chutes/lifts/feeders query traversable excavated space), `machines`
(placement validity queries tile state), `fluid` (the water automaton
operates over the tile grid), `invariants` (checks like "no items inside
solid rock" and "no machine in an invalid cell" read world state), `run`
(drives shaft generation and reads world state for termination conditions).

## Tick phase

None. `world` is substrate — a data store queried and mutated by other
phases — not itself one of the fixed tick phases.

## Public API

- `TileGrid` (`tile_grid.gd`) — the fine (4px) terrain/digging grid, sparse `Dictionary`-backed. Every
  coordinate is named `terrain_cell: Vector2i` (never a bare `cell`) — `docs/DECISIONS_LEDGER.md` D0020.
  `.get_material()`/`.set_material()`, `.get_wall()`/`.set_wall()` (the background layer, revealed by
  `.excavate()` rather than erased with it), `.is_solid()`, `.in_bounds()`, `.occupied_cells()`
  (sorted, block cells only), `.state_signature()` (canonical, for determinism checks).
- `WorldMaterials` (`materials.gd`) — hardness by material id. `.hardness()`, `.exists()`. Mirrors
  `data/materials/*.yaml` by hand — no runtime YAML loader exists yet, see Gotchas.

## Gotchas

- **Not chunked.** `TileGrid` is a sparse `Dictionary`, not the fixed-size chunk array the Purpose line
  above names — chunk size is an unresolved EXPENSIVE decision (`docs/DECISIONS_LEDGER.md` D0019:
  interacts with dirty-rect rebuild cost, the fluid active-cell set, and the render packet, none of
  which exist yet to measure against). A sparse store is correct regardless of what size, if any, a
  later optimization picks — nothing here forecloses adding one.
- **The 16px machine/logic grid is not represented here at all**, on purpose. It's a view over this
  grid's data, not a second array — whatever module needs it (`sim/machines`, most likely) builds that
  view when it exists; `sim/world` only ever stores the 4px grid.
- **`data/materials/*.yaml` has no runtime loader.** `WorldMaterials.HARDNESS` is a hand-kept mirror —
  `docs/DECISIONS_LEDGER.md` D0021 has the full reasoning (Godot ships no YAML parser) and the real
  options for fixing it. If the two ever disagree, the `.yaml` file is right and this table is stale.
