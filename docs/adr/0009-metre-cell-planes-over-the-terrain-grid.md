# ADR 0009: The metre-cell planes sit beside the terrain grid, and every metre-cell fact is derived from the 4 px cells it covers

**Status:** accepted, 2026-09-03. Records the state the director ruled in `docs/DECISIONS_LEDGER.md`
D0345 ("water at the fine grid, §9 stands") together with D0019/D0020 and `docs/ARCHITECTURE.md` §9,
and fixes the derivation rules `sim/world`'s verbs run on. Required because it decides the data the tick
order and the save schema carry (`docs/QUALITY.md` gate 20). Written at the start of A′ step 3b; step 4
wires the planes into `Interface`.

## Context

Two grids, one metre. The terrain/digging grid is 4 px (`TileGrid`, sparse, the running signature of
D0261); machines, items, power and the placed layers live on the 16 px metre cell (§9's table); water
flows through the 4 px grid (§9, ruled D0345). Legacy had one grid, so `set_solid`, `block_supported`,
`place_rope` and the rest all read `solid.has(cell)` and were done. Here a metre cell covers sixteen
terrain cells and can be wholly rock, wholly air, or anything between, because `Mining` clears a 13-cell
disc at 4 px and hand-dug tunnels never align to metres.

## Decision

1. **Storage.** `sim/world/logic_grid.gd` (`LogicGrid`) holds the metre-cell planes, keyed `logic_cell:
   Vector2i`: one `placed` plane (cell → kind: `&"machine"`, `&"conduit"`, `&"rope"`, `&"torch"`), the
   conduit tier, and the `sapling` plane (cell → age). `sim/fluid/water_plane.gd` holds water at the
   terrain cell (D0344). `sim/world/world.gd` (`World`) owns all three — `grid: TileGrid`, `logic:
   LogicGrid`, `water: WaterPlane` — and is the one object the hub, the interface and the save hold.
   `TileGrid` itself stays exactly what its header says: the 4 px grid, knowing nothing of metres.
2. **One occupancy plane, so exclusivity is structural.** Legacy's rule that solid rock, a machine, a
   conduit, a rope and a torch are mutually exclusive per cell was a five-way `or` in `cell_occupied`.
   Here every placed thing is one entry in `placed`, so two cannot share a cell by construction.
   Machines register their footprint as the opaque kind `&"machine"`: `sim/world` still knows no
   machine *type*, which is what its must-not protects. Saplings keep legacy's known exception (not in
   the exclusive set), recorded rather than silently fixed.
3. **Derivations, from the sixteen cells (`TERRAIN_PER_LOGIC = 4` per axis):**
   - `logic_solid(c)`: all sixteen solid. `logic_air(c)`: all sixteen air. Partially dug is neither.
   - `logic_open(c)`: in bounds, `logic_air`, and nothing placed there. Placement needs a whole open
     metre; a machine does not sit in a half-dug hole.
   - `cell_occupied(c)` (legacy's name): any rock in the metre, or anything placed. Conservative on
     purpose: a rope does not hang through a sliver of rock.
   - `wall_backs(c)`: any of the sixteen has a wall.
   - `face_solid(c, dir)`: the four terrain cells of the neighbouring metre along the shared edge are
     all solid — "a full face to build off", and for `dir = down`, "a floor across the metre".
   - `block_supported(c)`: `wall_backs`, or some face is solid, or an orthogonal neighbour holds a
     machine or a conduit. Legacy's list exactly, with "solid neighbour" read as a full face.
   - Torch backing: `wall_backs` or any `face_solid`. Sapling soil: the four cells of the face below
     are all a material whose record says `soil: true` (`data/materials`; `clay` is legacy's `earth`).
4. **Terrain verbs write sixteen cells.** `set_solid(c, material)` sets every terrain cell of the metre
   and calls `WaterPlane.displace` on each — the coupling legacy kept inline in `set_solid`
   (`factory_sim.gd:708`), landing here as D0344 said it would; it returns the units displaced so the
   caller can account for them. `set_solid(c, &"")` excavates all sixteen (revealing walls, as digging
   does). `place_block` is `set_solid` behind legacy's refusals (bounds, occupancy) and, as in legacy,
   does NOT check support: the command layer gates on `block_supported` because machines are exempt.
5. **Pack accounting is not here.** Legacy's verbs spent the pack and wrote `total_consumed` inline.
   `World`'s verbs are geometry: they return what they did (`hung`, `cut`, `displaced`, `true`) and the
   items sub-step wraps them with the ledger, the same seam `WaterPlane.add_water` already has.
6. **Signatures fold.** `World.state_signature()` is the three planes' running signatures joined; each
   plane keeps its own two XOR lanes through `StateHash` and its own `recomputed_signature()` self-check.
   Every plane enters the golden when step 4 puts a `World` in it (one re-pin, from CI Linux).
7. **Sorting.** Any walk over a plane in state-affecting code uses a sorted cell order
   (`WaterFlow._cell_less` for `Vector2i`, `Ordering.ids` for ids — D0346), never dictionary order.

## Consequences

- A metre cell has three states, not two. Every consumer that legacy wrote as `solid.has(cell)` must
  say which it means: `logic_solid`, `logic_air`, or `cell_occupied`. The suite pins each on a half-dug
  metre so the choice is visible.
- `TileGrid` is untouched; its golden does not move for this ADR. `LogicGrid` and `WaterPlane` are new
  state and move the golden only once they are in it.
- Deferred, with the reason: `fill` (packed/loose backfill) waits on the crusher-chain ruling (plan §8);
  foliage settling and `Flora.grow` wait on wood/leaves materials and ground piles (items sub-step);
  `surface_row`/`ramp_dir` are superseded by `Heightfield` pending the ramps ruling; `updraft_at` reads
  a machine flag and lands with transport.
- `TERRAIN_PER_LOGIC` is written as `4` in `sim/world` because deriving it from `Body.LOGIC_TILE_PX /
  Heightfield.TERRAIN_CELL_PX` would make `world` depend on `body`, which depends on `world`. The
  relation is asserted in `tests/test_world_verbs.gd` instead, so the two cannot drift silently.

## Reverse cost

CHEAP until step 4 wires the planes into the golden and step 6 paints them; the planes are
dictionaries and the derivations are one file of pure functions.
