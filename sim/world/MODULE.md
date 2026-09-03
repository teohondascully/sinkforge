# sim/world

## Purpose

Tile grid, chunks, material IDs, hardness, terrain queries and mutations.
The single source of truth for "what is at this cell" — solid rock, an
excavated void, what material, how hard it is to dig. Foundational: nearly
every other gameplay submodule queries or mutates it.

## Must-not

- Know about machine TYPES. A machine registers its footprint here as the opaque occupant kind
  `&"machine"` (ADR 0009, D0347) so occupancy is one plane; this module never reads a def, a state or
  a behaviour, and `block_supported` asks only "is something built there".
- Know about items. No item instances, no item types.
- Spend a pack or write a ledger. The verbs here are geometry and return what they did; the items
  sub-step wraps them (ADR 0009 §5).

## Dependencies

`core` (`StateHash`, `Ordering`), `data` (`MaterialsRecords`, through `WorldMaterials`). Not `fluid`:
the water PLANE is here, the water ALGORITHM is there and reads this module.

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
- `WorldMaterials` (`materials.gd`) — hardness by material id. `.hardness()`, `.exists()`, `.is_soil()`.
  Reads `data/materials/generated.gd`, codegen'd from `data/materials/*.yaml` — see Gotchas.
- `LogicGrid` (`logic_grid.gd`, A′ step 3b, ADR 0009) — the 16 px metre-cell planes, every coordinate a
  `logic_cell`: one `placed` plane (cell → `&"machine"`/`&"conduit"`/`&"rope"`/`&"torch"`, mutually
  exclusive by construction), conduit tiers, the `sapling` plane (cell → age). `.occupant()`,
  `.is_occupied()`, `.occupy(cell, kind, tier)` (refuses an occupied cell), `.vacate() → kind`,
  `.has_conduit()`/`.conduit_tier()`/`.is_climbable()`/`.has_torch()`/`.has_sapling()`/`.sapling_age()`,
  `.plant()`/`.set_sapling_age()`/`.unplant()`, `.logic_rope_anchor()`/`.rope_length()`,
  `.placed_logic_cells(kind)`/`.sapling_logic_cells()` (scan order), running `.state_signature()` +
  `.recomputed_signature()`, `.clone()`.
- `WaterPlane` (`water_plane.gd`, D0344, here since D0347) — integer water per terrain cell; API in `sim/fluid/MODULE.md`.
- `World` (`world.gd`, ADR 0009) — THE OWNER: `grid`, `logic`, `water`, `deposits`. The metre-cell derivations `.logic_in_bounds()`, `.terrain_cells_of()`, `.terrain_face_cells(cell, dir)`,
  `.logic_solid()` (all sixteen rock), `.logic_air()` (all sixteen air), `.logic_open()` (air, in bounds,
  nothing placed), `.cell_occupied()` (any rock or anything placed), `.wall_backs()`, `.face_solid(cell,
  dir)`, `.soil_below()`, `.block_supported()`, `.backed()`, `.logic_ore_body()` (every rock cell ore-like);
  the terrain verbs `.set_solid(cell, material) → water displaced` (sixteen cells; `&""` excavates),
  `.set_wall()`, `.place_block()`, `.bore_one() → material` (the drill's bite: one unit off the first
  solid ore cell, excavated when spent, D0349); the joined `.state_signature()`/`.recomputed_signature()`, `.clone()`.
- `PlacedVerbs` (`placed_verbs.gd`) — static over a `World`: `place_conduit`/`remove_conduit`,
  `place_rope(world, anchor, max_segments) → hung`/`retract_rope`/`remove_rope → cut`,
  `place_torch`/`remove_torch`, `can_plant_sapling`/`plant_sapling`/`remove_sapling`. Legacy's
  refusals in legacy's order, minus the pack.

**`Seams` is NOT here any more** (D0227 in, D0237 out to `core/seams.gd`: `view/` may reach `core`, never
`sim`). It was never listed here while it was — a public-API list that omits a module's own file is the
same shape as a gate that cannot see its subject.

## Gotchas

- **Not chunked.** `TileGrid` is a sparse `Dictionary`, not the fixed-size chunk array the Purpose line
  above names — chunk size is an unresolved EXPENSIVE decision (`docs/DECISIONS_LEDGER.md` D0019:
  interacts with dirty-rect rebuild cost, the fluid active-cell set, and the render packet, none of
  which exist yet to measure against). A sparse store is correct regardless of what size, if any, a
  later optimization picks — nothing here forecloses adding one.
- **The 16px logic grid is `LogicGrid`, a sibling of `TileGrid`, not a second copy of terrain.** What
  lives there is what is PLACED (new state); every terrain fact at the metre is derived from the
  sixteen 4 px cells (ADR 0009). `TileGrid` still stores only the 4 px grid and knows nothing of metres.
  A metre cell has three states — rock, air, half-dug — and a consumer must say which it means.
- **`data/materials/*.yaml` is read through generated code, not hand-mirrored.** `tools/data_codegen/
  generate.py` emits `data/materials/generated.gd` (`MaterialsRecords.RECORDS`); `WorldMaterials` reads
  it directly. `docs/adr/0004-data-codegen.md` has the contract, `docs/DECISIONS_LEDGER.md` D0021 the
  original gap this resolves. Drift is now a build failure (`generate.py --check`), not a hand-sync task.
- **`_dig_extent` tracks DUG history only, not "everything currently open."** A column can have a
  natural, generation-time opening (a cave) far from anywhere the player has dug; `extend_terrain_dig_extent`
  deliberately never merges the two. It lives here, not on `Body` or anywhere else, because a shaft's
  `TileGrid` is exactly what determinism already replays — a side table anywhere else would be new,
  unreplayed state (`docs/DECISIONS_LEDGER.md` D0125).
