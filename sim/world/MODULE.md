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
  `.excavate()` rather than erased with it), `.is_solid()`, `.in_bounds()`, `.occupied_terrain_cells()`
  (`Array[Vector2i]`, sorted, block cells only — named and typed this way, not the bare `Array` it
  returned before D0026's resolution audit, so a caller sees "terrain" without reading the doc comment),
  `.state_signature()` (canonical, for determinism checks; includes dig history, see below).
  `.extend_terrain_dig_extent(col, touch_top, touch_bottom)` (D0125) — per-column high/low-water mark. Merges
  this touch into column `col`'s own historical [min,max] dug extent and returns the merged range, which
  the caller (`Body._handle_dig`) excavates in full. Column-scoped: two adjacent columns disagreeing is
  legal geometry, only a gap strictly within one column was the illegal shape this closes.
- `WorldMaterials` (`materials.gd`) — hardness by material id. `.hardness()`, `.exists()`. Reads
  `data/materials/generated.gd`, codegen'd from `data/materials/*.yaml` — see Gotchas.

**`Seams` is NOT here any more.** It landed in this module 2026-08-30 (D0227) and left the same day
(D0237) for `core/seams.gd`, because `view/` may depend on `{interface, core}` but never on `sim`, and
`sky_painter`'s starfield calls `Seams.grain()`. It was never listed in this section while it was
here — a gap worth naming rather than quietly closing, since a public-API list that omits a module's own
file is the same shape as a gate that cannot see its subject. Nothing in `sim/world` referenced it.

## Gotchas

- **Not chunked.** `TileGrid` is a sparse `Dictionary`, not the fixed-size chunk array the Purpose line
  above names — chunk size is an unresolved EXPENSIVE decision (`docs/DECISIONS_LEDGER.md` D0019:
  interacts with dirty-rect rebuild cost, the fluid active-cell set, and the render packet, none of
  which exist yet to measure against). A sparse store is correct regardless of what size, if any, a
  later optimization picks — nothing here forecloses adding one.
- **The 16px machine/logic grid is not represented here at all**, on purpose. It's a view over this
  grid's data, not a second array — whatever module needs it (`sim/machines`, most likely) builds that
  view when it exists; `sim/world` only ever stores the 4px grid.
- **`data/materials/*.yaml` is read through generated code, not hand-mirrored.** `tools/data_codegen/
  generate.py` emits `data/materials/generated.gd` (`MaterialsRecords.RECORDS`); `WorldMaterials` reads
  it directly. `docs/adr/0004-data-codegen.md` has the contract, `docs/DECISIONS_LEDGER.md` D0021 the
  original gap this resolves. Drift is now a build failure (`generate.py --check`), not a hand-sync task.
- **`_dig_extent` tracks DUG history only, not "everything currently open."** A column can have a
  natural, generation-time opening (a cave) far from anywhere the player has dug; `extend_terrain_dig_extent`
  deliberately never merges the two. It lives here, not on `Body` or anywhere else, because a shaft's
  `TileGrid` is exactly what determinism already replays — a side table anywhere else would be new,
  unreplayed state (`docs/DECISIONS_LEDGER.md` D0125).
