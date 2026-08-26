# sim/terrain_gen

## Purpose

Seeded strata generation, deposit and ruin placement, per-site parameters.
Writes into `world`'s tile grid. Generation is called per-run and scoped to
a bounded shaft region now, not a single persistent grid — this changed
from the pre-pivot design, where terrain generation produced one world that
persisted across the whole game.

## Must-not

- Depend on run state. Generation takes a seed and site parameters as
  inputs; it must not reach into `sim/run` for phase, flood clock, or any
  other in-run state. This keeps generation callable in isolation (by
  `harness/scenario` fixtures, by tooling, by tests) without spinning up a
  run.

## Dependencies

`core`, `world` (for tile and material types — generation writes tiles, it
doesn't invent its own representation of them).

## Consumers

`interface`, indirectly (generated terrain is what `observe()` surfaces
once a shaft exists). Sim-internal: `run` (invokes generation at
site-selection/run-start, scoped to that run's shaft).

## Tick phase

None. Generation runs once at run/site setup, not as part of the fixed
per-tick phase order.

## Public API

- `ShaftGenerator` (`shaft_generator.gd`) — `.generate(site: Dictionary, seed: int) -> TileGrid`. Reads a
  `StrataData` site config and a seed, returns a fully generated `TileGrid`. Depth-bands the base rock
  into `docs/GDD.md` §11's three layers, carves caves, scatters ore/coal/iron veins, places one empty
  ruin chamber. Deterministic in `(site, seed)` only — no run state, per this module's Must-not.
- `StrataData` (`strata_data.gd`) — reads `data/strata/generated.gd`, codegen'd from
  `data/strata/*.yaml`. `.get_site(id)`, `.exists(id)`. Same mechanism as `sim/world/materials.gd` —
  `docs/adr/0004-data-codegen.md`.
- `ValueNoise` (`value_noise.gd`) — deterministic engine-free 2D noise, `.sample(x, y, seed) -> float`
  in roughly [-1, 1]. Not terrain_gen-specific in principle, but has no other consumer yet.

## Gotchas

- **Port scope is a real subset of legacy, not all of it.** `docs/DECISIONS_LEDGER.md` D0017: strata
  banding, cave carving, and ore/coal/iron scattering only. Big caverns, tunnels, rifts, sinkhole mouths,
  ledges, spires, rubble, lodes, aquifers, aquifer treasure, surface trees, the bazaar ruin, and the
  L1/L2 "seal" gate are NOT ported — most are artifacts of the pre-pivot progression-gated structure.
- **No per-cell richness/deposit amount.** `data/strata/*.yaml`'s `amount_base`, `rich_chance`, etc. are
  schema-validated but unread by `ShaftGenerator` — a vein cell is just its material id. Richness
  accounting is `sim/economy`/`sim/items` territory, neither of which exists yet.
- **`FastNoiseLite` and `RandomNumberGenerator` cannot be used here** — both are Godot engine classes,
  forbidden in `sim/` (`docs/ARCHITECTURE.md` engine-free rule), and both are now caught by
  `tools/layer_lint/no_engine_imports.py` (D0023, closed after this module needed to route around the
  gap). Use `ValueNoise` for noise fields and `core/SplitRng` (via `.split("terrain_gen")`) for
  randomness — see `docs/DECISIONS_LEDGER.md` D0005 for why the label match matters.
  `SplitRng.next_float()`/`.next_range()` were added this stage specifically to support this.
  `ShaftGenerator._carve_caves` samples `ValueNoise` off the raw world seed directly (like legacy's
  `FastNoiseLite`), NOT off the `SplitRng` vein stream — the two are independent by construction, so
  the order cave carving runs in relative to vein scattering doesn't affect either one's own sequence.
- **A full-generation test can miss a floor a targeted unit test would catch** (D0024). `_grow_vein`'s
  `min_row` argument and its host-rock-only replacement rule both need a test built to force them, not
  a test that merely runs code that happens to contain them — an accretion blob is compact enough, and
  the relevant cells sparse enough, that a real generation run may never actually probe either guard.
- **Ruin placement is deliberately minimal** (D0018): one carved-empty chamber, nothing inside it.
