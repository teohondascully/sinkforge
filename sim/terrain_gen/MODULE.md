# sim/terrain_gen

## Purpose

Seeded strata generation, deposit and ruin placement, per-site parameters.
Writes into `world`'s tile grid. Generation is called once, at shaft
creation, and scoped to that one shaft's bounded region — updated
2026-08-27: the 2026-08-25 pivot had this called per-run (once per
disposable session); the 2026-08-27 reversal retired that structure, so
generation now runs exactly once, ever, per persistent shaft, not
repeatedly across sessions and not for one persistent *world* either (it
still only generates the bounded shaft region, same as before — only the
per-session repetition is gone).

## Must-not

- Depend on session state. Generation takes a seed and site parameters as
  inputs; it must not reach into `sim/run` (or whatever ends up owning
  session/flood state — see `sim/run/MODULE.md`'s own open question) for
  phase, flood clock, or any other in-session state. This keeps generation
  callable in isolation (by `harness/scenario` fixtures, by tooling, by
  tests) without spinning up a session.

## Dependencies

`core`, `world` (for tile and material types — generation writes tiles, it
doesn't invent its own representation of them).

## Consumers

`interface`, indirectly (generated terrain is what `observe()` surfaces
once a shaft exists). Sim-internal: `run` (invokes generation once at
shaft creation — provisional naming, see `sim/run/MODULE.md`'s own open
question about what module this ends up being).

## Tick phase

None. Generation runs once at shaft creation, not as part of the fixed
per-tick phase order.

## Public API

- `ShaftGenerator` (`shaft_generator.gd`) — `.generate(site: Dictionary, seed: int) -> TileGrid`. Reads a
  `StrataData` site config and a seed, returns a fully generated `TileGrid`. Depth-bands the base rock
  into `docs/GDD.md` §11's three layers, carves caves, scatters ore/coal/iron veins, places one empty
  ruin chamber. Deterministic in `(site, seed)` only — no session state, per this module's Must-not.
- `StrataData` (`strata_data.gd`) — reads `data/strata/generated.gd`, codegen'd from
  `data/strata/*.yaml`. `.get_site(id)`, `.exists(id)`. Same mechanism as `sim/world/materials.gd` —
  `docs/adr/0004-data-codegen.md`.
- `ValueNoise` (`value_noise.gd`) — engine-free 2D noise, `.sample(x, y, seed) -> float` in roughly
  [-1, 1]. Deterministic WITHIN a platform (same seed, same build → same output); NOT yet proven
  bit-identical ACROSS platforms — it uses real `float` arithmetic, the one place in `sim/` that departs
  from the fixed-point rule `docs/ARCHITECTURE.md`'s own Determinism section states, and IEEE 754 doesn't
  guarantee identical results for the same expression across CPU architectures. Real, measured, diagnosed
  gap, not fixed (`docs/DECISIONS_LEDGER.md` D0171/D0172 — converting to `Fx` is a real design cycle, not
  yet scheduled). Not terrain_gen-specific in principle, but has no other consumer yet.

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
- **Reveal-layer placeholder scatter** (`docs/GDD.md` §12, `claims/C004`, `docs/DECISIONS_LEDGER.md`
  D0110/D0111): an optional `site["reveal"]` config, read only if present (`shallow_clay`, the real
  site, deliberately does not carry one). Reuses `_grow_vein` (the same already-legacy-ported accretion
  algorithm `_scatter_vein_material`/`_scatter_iron` already use), confined to topsoil rows only, unlike
  the depth-weighted whole-grid acceptance curve those two use. **Determinism holds per-site, not across
  sites at different density** — `data/strata/reveal_test_sparse.yaml`/`reveal_test_dense.yaml` are two
  distinct sites, not one site with a runtime knob, specifically because a density sweep is a sweep over
  generations, never a re-sample of one generation. Do not add a runtime density parameter to
  `ShaftGenerator.generate` later without re-reading this note.
