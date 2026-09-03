# FLIP vs FINISH — directional feasibility analysis

**Status:** analysis, awaiting the director's go/no-go. **Written 2026-09-02.** Nothing was ported,
moved, or executed to produce it; Phase 2 (§8) does not start without the director's explicit approval.

| | |
|---|---|
| Current tree | `7bedcbd8d77e01c05297726fe61a7690f0ff505a` (`main` = `origin/main`) |
| Legacy | `legacy/` in that tree, byte-identical to tag `pre-pivot` (`666e5518`) |
| Population | 491 code files: 210 under `legacy/`, 281 elsewhere. 120,649 lines. |
| Coverage | 491 of 491 accounted, 0 unaccounted, 0 duplicated (§1) |
| Raw evidence | 17 worker reports + the aggregated breaker table, in the session scratchpad (not tracked) |

---

## 0. The answer in one screen

**Can legacy's sim be made deterministic?** Yes, within a platform, in about one working week.
Read in full, legacy has **172 determinism-breaker rows in 17 files**, 963 estimated changed lines in
those rows plus a 250–350-line fixed-tick controller for `main.gd` and a ~40-line `Fx` vector layer.
Only **23 rows break replay on a single machine**, and all 23 are one structural defect: two clocks
(`sim.advance(delta)` in `_process`, the body in `_physics_process`) and state decisions taken at frame
rate in the scene layer. `FactorySim.tick()` itself has one within-platform breaker (its own `delta`
wrapper). `FastNoiseLite` is **not on legacy's state path**: the fine-terrain molding it drives is read
only by the renderer; the player collides against the coarse grid (§3.1).

**Cross-platform bit-identity is open in BOTH directions.** Legacy's 102 cross-platform rows are float
math and seeded float RNG, 52 of them in the world generator. The current build carries 16 rows of the
same class, all on its own terrain-generation path (D0171/D0183, still present at HEAD). The fix is the
same design cycle either way.

**The flip's central premise is half wrong.** Legacy's *sim* is already node-free, fixed-tick at 20 Hz,
and integer-shaped (24 live breakers, 77 lines, all mechanical). The non-determinism lives in
`main.gd`, `player.gd` and `grapple.gd` — the scene layer — and the rebuild has already replaced the two
largest pieces of it (`sim/body`, `sim/mining`) and must write the third (the grapple under `Fx`) in
either direction. So the flip does not buy determinism cheaply. What it buys is a complete game on day
one, at the price of the architecture the substrate exists to demonstrate (§6).

**Recommendation: FINISH, amended — lift legacy's sim hub whole, not one component at a time (§7).**

| | A · finish as practised | A′ · finish, lift `FactorySim` whole | B · flip |
|---|---|---|---|
| Time to a complete, deterministic, playable game | 5.5–7 weeks | 4.5–5.5 weeks | 3.5–4 weeks |
| Confidence in that number | low–medium | low–medium | low–medium |
| Layer boundaries, size caps, L2 door, 4 px world | kept | kept | red, waived, or reverted |
| Cross-platform determinism | open (same fix) | open (same fix) | open (same fix) |
| Chief failure mode | re-derivation tax continues | grid adapter larger than a facade | a third pivot; gates green while switched off |

---

## 1. Method and coverage (the addendum's §4)

**Enumerate first.** `git ls-files` filtered to `.gd .py .sh .gdshader .tscn .yaml .yml`: 491 files. A
script assigned every file to exactly one of 17 disjoint slices (self-check before dispatch: 491
assigned, 0 missing, 0 duplicated) and wrote the slice lists to disk.

**Seventeen read-only workers**, each with the same brief (breaker classes, severities, conversion
costs, a strict report format) and its own slice. Each wrote one report. Six were cut off by a session
rate limit during their final message; all six had already written complete reports, which the
self-check below confirms rather than trusts.

| worker | slice | files | lines | read depth (FILE rows) |
|---|---|---|---|---|
| L1 | `legacy/src/core/factory_sim.gd` | 1 | 3,259 | 1 FULL |
| L2 | rest of `legacy/src/` | 17 | 2,723 | 17 FULL |
| L3 | `player grapple falling_items fine_terrain(view) world_seeder strata controls` | 7 | 3,261 | 7 FULL |
| L4 | `legacy/scenes/main.gd` | 1 | 3,003 | 1 FULL |
| L5 | `world_renderer light_layer sky_painter terrain_painter water_view` + 5 shaders + tscn | 11 | 4,975 | 11 FULL |
| L6 | `visuals machine_view rope_view particles art payouts score sfx` | 8 | 4,358 | 8 FULL |
| L7 | `hud hints hover_info objectives settings settings_page ui_theme page_surface` | 8 | 4,542 | 8 FULL |
| L8 | 8 `bazaar*` + 5 `legacy/tests/` | 13 | 7,305 | 5 FULL, 8 SKIM (dead files) |
| L9–L12 | `legacy/tools/` in four LOC-balanced slices | 36 ×4 | 46,162 | 105 FULL, 39 SKIM (check layers) |
| C1 | `core/ sim/ interface/ shell/ data/ .github/` | 54 | 6,103 | 30 FULL, 24 SKIM (yaml, generated) |
| C2 | `view/` | 36 | 5,878 | 32 FULL, 4 large files skimmed as briefed |
| C3, C4 | `tests/` in two slices | 51 + 49 | 16,450 | 100 FULL |
| C5 | `tools/` + 17 scripts under `docs/` | 91 | 12,630 | 59 FULL, 32 HEADER (17 docs scripts skipped with reason, 15 large tools skimmed as briefed) |

**Coverage self-check (mechanical, not by hand):** every path in the manifest appears as a `FILE:` row
in exactly one report; every report has all five required sections.
**Result: manifest 491, accounted 491, unaccounted 0, duplicated 0, problems 0.**

**Skipped with reason:** 17 scripts under `docs/archive/session-exhaust/` and
`docs/audits/2026-09-01-droid-mission/` (archived rewrite helpers and audit-evidence repro scripts, not
on any path); 3 `data/*/generated.gd` (generated); 21 `data/**/*.yaml` (schema read, content skimmed).
Each still has its own row.

**Verification of the workers' claims:**
- **Spot-check:** 14 breaker rows sampled at random (seed 20260902) from the aggregated table; the
  cited line was printed from the tree for each. 14 of 14 match the claim (two cite the head of a
  range rather than the exact expression).
- **Control greps**, run by the orchestrator over `legacy/src legacy/scenes` with a positive control
  (`FastNoiseLite.new` = 7, expected non-zero): `randomize(` 0; bare `randi/randf` 25 (particles 14,
  sfx 5, main 3, water_view 2, layered_world_gen 1); `RandomNumberGenerator` 54; `Time.get_*`/ticks 3
  (progressive bake pacing, HUD); `func _physics_process` 1 (player); `func _process` 3; engine physics
  classes 0; `Input.` 3 (controls.gd only); `.keys()` 31; `.sort()` 7; `sort_custom` 10;
  `Engine.time_scale` 6. Every non-cosmetic hit appears in a worker's breaker or exclusion table.
  (A first pass of this probe returned zero for every pattern because zsh does not word-split a
  two-directory variable; it was re-run with explicit paths and the control.)
- **Fine-terrain crux, checked independently before the workers reported:** `fine_is_solid` /
  `fine_solid_bytes` are read only from `world_renderer.gd:2654,2660,2675`; `player.gd` collides via
  `sim.is_solid` (:566), `surface_row`, `ramp_dir`. L1, L2 and L3 reached the same conclusion from their
  own greps.
- **Graph artefact corrected:** the orchestrator's dependency graph drew `FactorySim -> scenes/fine_terrain.gd`;
  L3 showed that `factory_sim.gd:19` declares a local `const FineTerrain := preload("res://src/core/
  fine_terrain.gd")` that shadows the global `class_name FineTerrain` (the painter). The edge is a token
  artefact; the real callee is the sim-side molder.

**Breaker totals, machine-summed from the 17 reports:** 197 rows; legacy 172, current build 22, tests 3
(host-bound, not sim).

---

## 2. Corrections to the brief's premises, measured

The brief's framing was written from memory. Seven of its premises change under measurement, and
several change the arithmetic.

1. **"Built in under a week."** First commit 2026-06-27; `FactorySim` is in the second commit
   ("node-free fixed-tick FactorySim"). 1,026 commits over 27 commit-days to the `pre-pivot` tag on
   2026-08-25. Game code (`src/`+`scenes/` `.gd`): 4,216 lines on 2026-06-28, 12,762 on 08-14, 28,522 on
   08-25. The Aug 14–25 push added 15.8k lines in 11 days on top of seven weeks of foundation. Key sim
   systems landed across that span: `mine`/`craft` 06-27, `place_rope` 07-11, `_run_pump` 08-09,
   `_seep_step` 08-16, the winch 08-24.
2. **"~5x slower."** By game lines per day the two builds are at parity: legacy 28,522 / 27 ≈ 1,056;
   the rebuild 9,171 / 8 ≈ 1,146 (1,068 → 10,239, 2026-08-25 → 09-01). The rate is wildly
   non-stationary: +235/day over Aug 25–29, +2,665/day over Aug 29–Sep 1. By layer: `sim/` 782 → 2,992
   (+276/day), `view/` 0 → 5,706 in four days, `interface/` 0 → 622. What *is* slower is playable game per
   line: the rebuild's lines went to substrate (tests 16,438, tools 8,709 py, 341 ledger entries in 8
   days), to a from-scratch body and terrain, and to view, while machines, items, water, power, transport
   and economy have zero lines. That is the real gap and it is measured in §6.
3. **"~30% ported."** 10,239 / 28,522 = 35.9% by raw lines. Against *live* legacy (28,522 minus
   ~5,100 GDD §9-dead lines: bazaar 2,641 + in-file dead blocks 668 / 399 / 408 / 354 / 142 / ~470) it is
   about 44% by lines, an upper bound because the rebuild's lines include things legacy lacks
   (`interface/`, `invariants`, the hollow tell).
4. **"No verification substrate" in legacy.** Legacy has 143 tool files (46,162 lines, 30-layer
   registered harness), 54 live tests, and its own same-process determinism corpus (§3.4). It lacks
   two-process replay, goldens and input-log replay, and its harness runs on engine frames (§4.3).
5. **"Wall-clock `advance(delta)`."** `advance` is an accumulator that runs whole `tick()` calls at
   `TICKS_PER_SECOND = 20` and drops backlog past 6 ticks a frame (`factory_sim.gd:1930-1938`). The sim
   clock is fixed; the wrapper is the breaker, and it is ten lines.
6. **"`FastNoiseLite` in the sim."** Seven `.new` sites: three in the view-side `scenes/fine_terrain.gd`
   (seeded from a literal 1337, cosmetic), two in the sim-side fine molder (output read by the renderer
   only), two in `layered_world_gen.gd` (cave carve, richness band — the only two on the state path).
7. **The substrate as described vs as in the tree.** The event-sourced log (Anvil) is parked and not
   tracked. `harness/`, `experiment/`, `scenarios/` are README-only. `interface/` (622 lines) is
   rebuild-only by its own header. What exists: `core/` 422, `sim/` 2,992, `interface/` 622, `view/` 5,706,
   `shell/` 497, `tests/` 16,438, `tools/` 8,709 py + 42 sh, a 39-step CI workflow, and the process docs.

---

## 3. The deciding question — the exact enumeration

### 3.1 Every breaker row in legacy, by file

Machine-summed from the workers' tables. `FLOAT` = FLOAT-STATE; `RNG` = seeded engine RNG on the
state path (35 rows, of which 18 are float methods); `BANNED` = deterministic in fact, forbidden by
`docs/ARCHITECTURE.md`'s rule. `est` = the workers' estimated changed lines for the rows.

| file | rows | FLOAT | RNG | FASTNOISE | WALLCLOCK | HASH-ITER | ENGINE-OTHER | UNSEEDED | WITHIN | CROSS | BANNED | MECH | RESTR | REWRITE | est |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `legacy/src/core/layered_world_gen.gd` | 52 | 16 | 34 | 2 | 0 | 0 | 0 | 0 | 0 | 31 | 21 | 49 | 0 | 3 | 142 |
| `legacy/scenes/main.gd` | 37 | 17 | 0 | 0 | 9 | 3 | 6 | 2 | 17 | 16 | 4 | 17 | 20 | 0 | 249 |
| `legacy/src/core/factory_sim.gd` | 29 | 14 | 0 | 1 | 1 | 12 | 1 | 0 | 1 | 14 | 14 | 22 | 2 | 0 | 77 |
| `legacy/scenes/player.gd` | 19 | 17 | 0 | 0 | 1 | 0 | 1 | 0 | 2 | 17 | 0 | 14 | 3 | 1 | 223 |
| `legacy/scenes/grapple.gd` | 9 | 7 | 0 | 0 | 2 | 0 | 0 | 0 | 2 | 7 | 0 | 2 | 2 | 5 | 170 |
| `legacy/src/core/power_flow.gd` | 8 | 8 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 8 | 0 | 8 | 0 | 0 | 16 |
| `legacy/src/core/heightmap_world_gen.gd` | 4 | 3 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 3 | 3 | 0 | 1 | 21 |
| `legacy/src/core/save_game.gd` | 3 | 2 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 2 | 1 | 2 | 1 | 0 | 12 |
| `legacy/src/core/machine_state.gd` | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 2 | 0 | 0 | 2 |
| `legacy/src/data/mining_rules.gd` | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 2 | 0 | 0 | 12 |
| `legacy/src/core/flora.gd` | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 3 |
| `legacy/src/data/bit_rules.gd` (dead) | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 |
| `legacy/src/data/recipe_def.gd` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 7 |
| `legacy/src/data/seams.gd` | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 2 |
| `legacy/scenes/world_seeder.gd` | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 3 |
| `legacy/scenes/world_renderer.gd` | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 1 | 0 | 12 |
| `legacy/scenes/hints.gd` | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 12 |
| **total** | **172** | 91 | 35 | 3 | 14 | 18 | 9 | 2 | **23** | **102** | **47** | 125 | 31 | 10 | **963** |

Five of `factory_sim.gd`'s 29 rows and eight of `main.gd`'s 37 sit inside GDD §9-dead blocks and cost
nothing (they are deleted). The 193 remaining legacy code files have **zero** rows: every view, audio,
UI, bazaar, test and tool file was read and excluded with a stated reason (the exclusion tables hold
~200 rows: cosmetic `delta`s, seeded audio RNG, dictionary loops that terminate in draw calls). The
world's fine terrain, the falling-item animation and the sky are render-only.

### 3.2 The 23 within-platform breakers are one defect

Every row that breaks replay on a single machine is the same shape: a decision that should happen on
a tick happens on a frame, or reads the engine inside the decision.

- **Two clocks.** `main.gd:672` feeds `sim.advance(delta)` from `_process`; `player.gd:197-209`
  integrates in `_physics_process` with `1/60` substeps; `factory_sim.gd:1930-1938` drops backlog past
  six ticks a frame; `main.gd:2384` (`Engine.time_scale` 2/4/8) makes the sim/body phase frame-rate
  dependent. Legacy's own harness knows this: three tool headers say "real-time physics has minor
  variance", `check_drift.gd:88-89` records the dropped ticks, `play_tests.gd` runs a three-try retry
  because a miss "can be timing variance rather than a broken game", and `check_fastforward` is dead by
  determinism.
- **State decided at frame rate in `main.gd`** (17 rows): the mining charge, rhythm, crack bank, lode
  cycle and THE break frame (`1523-1614`, `1688-1699`, `1963-1978`); drop grace (`2282-2290`); pile
  collection (`2329-2347`). In `grapple.gd`: the hook's bite step (`140-173`) and reel (`201-210`).
- **Engine reads inside the decision:** `Input` via `Controls` inside the body step (`player.gd:199-203,
  220-226`); the OS pointer resolved through a lerped camera and an unseeded shake jitter into the aim
  cell (`main.gd:968, 1526-1527, 1484`); `Settings.auto_pickup` and the zoom preference read from the
  prefs file into inventory outcomes (`2330`, `259-260`).
- **Unseeded RNG:** the title-screen reroll seed (`main.gd:984`).
- **A frame-sampled save key:** `hints_taught` (`hints.gd:205-221`).

**The fix is one restructure, sized by L4 from the file:** a single fixed-step controller tick
(`_age_drop_grace`, pile collection, `_update_mining`, verb application moved out of `_process`; `sim.
tick()` once every three controller ticks; `time_scale` becomes ticks-per-frame; the cap-and-drop
retired), plus one command record per tick capturing held keys, the aim as a world cell, the UI-eats-click
flag and the one-shot verbs. ~60–80 lines of harness + ~40 of command record + integer accumulators
pasted from `sim/mining/mining.gd` (~70) + integer gates (~30) + an integer line-of-sight DDA and aim snap
(~75, absent from both trees) + sorts and the seed (~15) = **250–350 lines in `main.gd`**, then
`player.gd`'s step driven from that tick (~30), the grapple's two clocks (~25), `hints` (~12). The same
command record is what gives agents and humans one door (§4.3).

### 3.3 The 102 cross-platform rows are the same class the rebuild has not fixed either

- **World generation, 56 rows / 163 lines** (`layered_world_gen.gd`, `heightmap_world_gen.gd`): two
  `FastNoiseLite` fields, 18 float RNG draws, four transcendental sites (`sin` heightmap, `cos`/`sin` worm
  path, `sin` rift, `pow` throat). One seeded RNG threaded in a fixed pass order; pure in (cols, rows,
  seed). Within-platform deterministic today. Four rows are REWRITE (the transcendental shapes).
- **`FactorySim`, 10 live rows:** `MachineState.progress` (`+0.05/tick`, exactly convertible for all six
  shipped recipe times) and the power throttle's clamp/round. **`power_flow.gd`, 8 rows:** the whole
  field, converts to milli-int in ~16 lines plus ~15 in the consumers. **Save:** two floats.
- **`player.gd`, 17 rows:** float kinematics. Six of them are already ported into `sim/body` at zero new
  lines, three more with a small gap; the rest are the mechanisms `sim/body` lacks (rope climb, wading,
  coast, updraft, step-down, machine collision, authored ramps, `place()`), ~200 lines.
- **`grapple.gd`, 7 rows, 5 REWRITE:** `normalized()`, `dot()`, divide-by-length, the pump's
  `PUMP_CLAMP 1.05` (store `21/20`, the reciprocal trap the repo already recorded twice, and the same
  literal recurs as `RELEASE_KICK` at `player.gd:316`). Blocked on the ~40-line `Fx` vector layer (PRE-2),
  which is absent. ~170 + 40 + 40 lines. **This cost is identical in both directions.**
- **`main.gd`, 16 rows:** distance and rect gates, the DDA.

The current build's own 22 rows: 16 CROSS, all on terrain generation (`value_noise.gd` 5,
`shaft_generator.gd` 9, `cave_passes.gd`, `split_rng.gd::next_range`); body, mining, gait, tile grid
and invariants are integer-exact. The four D0183 sites are still present at HEAD, three at drifted line
numbers. The rebuild's terrain ports of legacy's caves, caverns, veins and `_density_count` carry the
same crack as their sources. **Neither tree is cross-platform proven; the fix (an `Fx` noise, an
integer range draw, a re-tuned calibration, a golden re-pin — D0172) is one design cycle in either
direction.** A zero-code probe exists for it: `legacy/tools/frontier_corpus.gd` prints integer worldgen
tallies for 12 seeds headless; run it on macOS-arm64 and Linux-x86_64 and diff.

### 3.4 The 47 deterministic-but-banned rows

Insertion-ordered dictionary iteration (18 rows — Godot 4 preserves insertion order, and every
insertion sequence traced is tick-ordered), floats that are exact by construction, one
`ResourceLoader.exists` bulk-class check. Cost: a sort before each loop and a golden re-pin. The one
place a sort is not semantically free is the hopper's "first thing it tastes" latch
(`factory_sim.gd:2309`), where insertion order is the designed rule.

Legacy's own tests corroborate the split: `test_sim`, `test_power_water`, `test_stress` and
`test_worldgen` carry 25 same-process two-instance signature equalities (including a 60-world regen
fuzz and four mid-run save/restore equalities), and `check_save_frontier` + `check_save_durability` prove
restore independence. All pass by legacy's account. All are same-process, so they prove `tick()` is
order-stable and free of global RNG and wall clock under those fixtures — and nothing more: the signature
renders two float fields through `str()`, so sub-print drift is invisible. A flip needs a bit-exact
signature before those greens mean what they say.

### 3.5 Verdict on the deciding question

| question | answer | confidence |
|---|---|---|
| Within-platform byte-determinism of legacy's sim | **~1 working week** (est. 5–7 days): one controller tick + command record (250–350), body tick (30), grapple clocks (25), `FactorySim` type pass (77), power (31), save v3 (12), hints (12), seed (2), sorts (~20); then a bit-exact `state_signature` and a two-process golden test on the pattern `tests/test_shaft_replay_determinism.gd` already has | HIGH on the enumeration (complete read, controls, 14/14 spot-check); MEDIUM on the line estimates |
| Cross-platform | **open in both directions**; the same worldgen float/noise cycle (~90 lines of `Fx` noise + calibration + re-pins per D0172, plus legacy's 4 transcendental shapes if legacy's generator is kept) | HIGH that it is symmetric |
| Mechanical / restructure / rewrite | 125 / 31 / 10; the 10 rewrites are the grapple (5), the swing coupling (1), and four worldgen shapes | HIGH |
| Is `FactorySim.tick()` a rewrite? | **No.** Integer grids, tick counters, 28 discrete mutators (20 player-facing), 68 read accessors, derived power rebuilt per tick, state-complete save. A type pass. | HIGH |

**What lifts back from the rebuild.** As *patterns and references*: `Fx`, `SplitRng`, `core/seams.gd`'s
exact conversion with its all-inputs proof, `sim/mining/mining.gd`'s integer charge loop (paste its
constants and order of operations into `_update_mining`), `sim/body`'s integer kinematics as the worked
reference for converting `player.gd` in place, `TileGrid`'s order-independent running hash with its
self-check, the two-process golden, the goalless fuzzer, the recorded-session corpus, `TestBase.over()`,
`run_gd_test.sh`'s masked-crash guard. As *code dropped in*: **not `sim/body`**. Every
determinism-carrying `sim/` file takes a `TileGrid` (4 px terrain cells, 16 px logic cells); legacy's
authoritative grid is the 32 px `CELL` dictionary that machines, water, power and items key on, plus the
fine byte array, and the body is a different size in cells (0.44 wide vs 1.00). No facade exists in
either tree. Converting `player.gd` in place (~260 lines) is cheaper than building one — which also
means a flip does **not** inherit the 102 body tests bound to `Body.tick(InputFrame, TileGrid)`.

---

## 4. What drops onto legacy free, what turns red, and what does not exist

### 4.1 The CI workflow, 39 steps (C1)

| tag | steps | on a legacy-based tree |
|---|---|---|
| PROCESS | 24 | run unchanged: authorship, hooks, formatter, WORKING freshness, suite coverage, untracked files, ledger integrity, gate mutation tests, duplication |
| STRUCTURAL | 11 | **red on contact**: layer table, engine-free `sim/`, 400/50 caps, LOC ratio, data codegen, claim refs, strict typing |
| SIM-BOUND | 2 | 67 suites of which 35 name current `sim/` classes |
| HEADED | 2 | xvfb boot |

### 4.2 `tools/`, 74 files (C5), and what the structural gates would say

- **52 files / 7,562 lines drop on unchanged and pass.** 8 need a one-line directory remap.
  10 (probes and captures bound to `reveal_scene`/`ShaftGenerator`/`Body`) are rebuild-only, and legacy
  has its own versions of each.
- **The trap:** five gates (`layer_lint`, `no_engine_imports`, `check_coordinate_naming`, the
  `MODULE.md` rule, `schema_validator`) print `PASS (vacuously)` and exit 0 on a tree with no `core/`
  or `sim/`. A flip that forgets the remap keeps a green CI with the architecture gates switched off.
- **After the remap, measured:** size gate red on **15 of 55 legacy game files** (`world_renderer`
  3,656, `factory_sim` 3,259, `main` 3,003, `hud` 2,189, `visuals` 1,850, `fine_terrain` 1,402, `sfx`
  1,125, `layered_world_gen` 1,059, `settings_page` 865, `player` 818, `machine_view` 726, `save_game`
  455, `settings` 455, `terrain_painter` 438, plus dead `bazaar_page` 1,454) and 66 of 257 including
  tools; ~53 game functions over 50 lines (span estimate); layer lint red by construction (20 of 37
  `scenes/` files read `FactorySim`; the current build's `view/` is 36 of 36 layer-clean); engine
  imports red on ~70 lines in 6 `src/` files; gate 7's letter red at 2.4x instrument-to-game;
  duplication red on ≥184 clusters inside `legacy/tools`. Every one is waive-or-refactor, and the
  refactor is Direction A's work.

### 4.3 Tests (C3, C4), the agent-playthrough pattern, and legacy's own harness

- **Current `tests/`, 100 files, 446 `_test_` functions:** portable as-is 15 files / 1,310 lines / 43
  tests (mechanism: crash probes, vacuity guard, replay stub, `SplitRng`, ids); PORTABLE-IF 45 files /
  7,290 lines / 232 tests (bound to `sim/body`, `sim/terrain_gen`, `TileGrid`, `interface/`); as a
  pattern 26 files / 5,305 lines / 108 tests; rebuild-only 14 files / 2,545 lines / 63 tests (the
  `Interface → Frame → painter` contract). The pattern is thin and tick-exact: `tick(input, world)` + a
  canonical `state_signature()` + per-tick telemetry flags; the fuzzer and the two-process replay need
  no scene at all. **Legacy's `advance` already wraps a `tick()`**, and `legacy/tests/test_base.gd` already
  carries `_build_sim()` and `_state_signature(sim)` — the current `test_base.gd:3` says it was adapted
  from it.
- **Legacy's harness, 143 files:** 26 + 25 + 26 + 18 = 95 layers with a live subject, 19 dead, the rest
  partial or hygiene. **83 files / 31,270 lines would be worth retaining in a flip** (the rope-feel suite
  2,916 lines with zero grapple in current `sim/`; `check_frametime` the only frame-rate gate;
  `play_agent` + `play_tests` the only whole-loop driver in either tree, ~2,230 live lines). But **48
  layers are clocked on engine frames** (`await physics_frame`, `Engine.get_physics_frames()`), enter one
  level below the input map (write `player.input_dir`, call `grapple.fire`), and `PlayAgent.mine_cell`
  loops `try_mine` until the cell is gone, breaking a cell per call where a human waits `hardness` seconds.
  Legacy has four input doors, not one. Five bare-sim layers are already tick-exact. Re-clocking is
  small per file and the same shape in every file; `PlayAgent` itself is ~20 lines.
- **What legacy has that the current build lacks, transfer regardless of direction (L10, L12):** the
  harness protocol — three-state + VOID verdicts with reason lines, `PASS*` stand-downs, HOME-keyed
  `user://` isolation that fails closed, the machine lock, the save sentinel, the wall-clock cap, the
  self-checksum, the post-sweep quotability gates (~1,850 lines of shell); `check_base._verdict` refusing
  a green that asserted nothing and printing the asserted count (current `test_base.gd::_finish` has no
  pass counter); a hash-mixing lint. `tools/run_suites.sh` (124 lines) has none of it.

### 4.4 The event log and the L2 door

The event-sourced log is parked (`.anvil/` gitignored, D0153–D0155); there is nothing to drop on.
`interface/` is rebuild-only: legacy's renderer reads 31 accessors at 203 sites (`world_renderer` 147,
`terrain_painter` 33, `water_view` 23), the HUD family 23 live accessors, and 7 injection sites hand a
live `FactorySim` to the view. Against the current 34-field `Observation`, 7 are carried, 4 superseded,
**20 not carried** (machines, water, ore amounts, items, power, torches, ramps…). Reads do not break
determinism; they break the agent-comparability invariant (`CONTEXT.md`, "same door"). The per-tick
command record in §3.2 is most of an `apply()`; an `observe()` is optional under B and required under A.

### 4.5 The value split

| substrate piece | gated on determinism? | free on legacy? |
|---|---|---|
| process CI (24 steps), 52 tools, formatter, CI-shrink guard, `gate_status` | no | **yes** |
| mutation-test discipline, correction record, audit methodology | no | yes (a practice) |
| two-process replay, goldens, fuzzer, recorded-session corpus | **yes** | after the retrofit |
| agent playthroughs comparable to humans | yes + the command record | after both |
| layer boundaries, size caps, coordinate naming, data codegen, claim refs | no | **no — red, waived, or Direction A** |
| L2 `observe()` door, `Frame`/painter contract, 4 px world | no | **no — rebuild-only** |
| event-sourced log | — | does not exist |

---

## 5. What the rebuild gained, and what carries either way

**Carries either way.** `Fx`, `SplitRng`, `EntityIdPool`, `Seams` (exact over 196,608 inputs with the
wrong conversion kept as a failing control); `sim/body` (1,169 lines, tick-only, `Fx`, 102 tests, the
acceptance chamber, the fuzzers, the bounds and reachability sweeps); `sim/mining` (integer charge,
hardness→ticks, bite, crack bank, rhythm, hollow tell); `TileGrid`'s running hash with `recomputed_
signature()`; the two-process golden and its CI-Linux re-pin discipline; `TestBase.over()`; the
masked-crash guard; the CI-shrink fingerprint gate; the formatter; the design work (rig-as-consumer, the
four rules, GDD §9's dead list — every lane in `LEGACY_GAP.md` converged on the same dead set, and this
analysis's 17 workers did again); 341 ledger entries and `CORRECTIONS.md`.

**What the rebuild re-derived instead of porting (C2, verified against legacy source).** Three of the
ledger's headline performance wins are restorations of architecture legacy already had and the port
dropped: the dirty-chunk margin (D0330; legacy `world_renderer.gd:657-663`), the veil as one lightmap
(D0336; `:330/:2769`), the sparse glint (D0337; `:1298`). And 3,930 of `view/`'s 5,878 lines are
smaller re-expressions of larger legacy originals (sfx 168 vs 1,125; ui_theme 127 vs 236, 13 of 36
tokens carried; terrain_painter 91 vs 438; three HUD chips vs 30 surfaces). `LEGACY_GAP.md`'s "15 call
sites in five surfaces" is 23 sites in 6; its "18 of 36" is 13. Each of these understates remaining work.
This is the mechanism behind the perceived slowness, and it is the thing to change, not the substrate.

**What legacy has that neither the rebuild nor a from-scratch continuation gets for free:** the
harness protocol (§4.3), the rope suite, the whole-loop agent, and ~420 lines of world content with no
current equivalent and not dead (relief and scarps, rifts, sinkhole throats, ledges, spires, rubble,
droughts, lodes, aquifers, trees, the richness field).

---

## 6. The cost of each direction

**What remains to port under any FINISH, measured from the reports, live lines only** (dead lines
removed): **view ≈ 10,200** — `world_renderer` ≈2,260 unported by seam (lighting 12 of 18 functions,
marks 24 of 31, ambience 16 of 17, ore 6 of 8), `terrain_painter` ≈350, `water_view` 362 (no water
painter exists), `visuals` 1,535, `machine_view` ≈620, `rope_view` 274, `payouts` 77, `sfx` ≈1,030,
`falling_items` 210, HUD family ≈3,420, two shaders 93. **Sim ≈ 5,100–5,300** — `FactorySim` live 2,591,
water 100, power 89, flora 64, `machine_state` 45, save 455, `world_data` 39, worldgen residue ≈583,
live data defs ≈110, grapple 389, player residue ≈200, `main.gd`'s unported state logic ≈450. Plus the
economy redesign (V13, not a port), PRE-2, and a resolver ruling for the grapple's collision half.

**Rates, measured, and their limits.** View porting ran ~1,500–2,000 lines/day on its best days
(Aug 31 → Sep 1: 3,753 → 5,706; the sequential-port day landed V1, V2, V2b and half of V3 within four
hours of merges). Sim ran 276/day over the eight days and ~460/day over Aug 29–31, and that was
from-scratch body and terrain with fuzz, acceptance and goldens attached — not a port rate. The
sequential model has one day of data. Every duration below is therefore low-to-medium confidence; the
*ratios* between the directions are firmer than the absolutes.

### A · finish as practised
Sim 5,200 at 276–460/day = 11–19 days; view 10,200 at 1,500–2,000/day = 5–7 days; grapple + PRE-2 3
days; economy ≈5 days; determinism re-pins and gates ≈3 days. **27–37 working days, 5.5–7 weeks.**
Failure mode: the re-derivation tax (§5) continues — each component re-expressed through
`Observation`/`Frame`, each dropping a legacy mechanism and re-measuring its cost — and the sim-side
rate stays at the from-scratch number because the port order treats `FactorySim` as KEEP-CURRENT.

### A′ · finish, but lift the sim hub whole
The migration map's `KEEP-CURRENT` verdict on `factory_sim.gd` conflated two things: the rebuild's body
and terrain do win outright, but `sim/machines`, `sim/items`, `sim/transport`, `sim/fluid` and
`sim/economy` are `MODULE.md`-only, and legacy's implementation of exactly those is already tick-only and
integer-shaped (§3.5). So: lift `FactorySim`'s 2,591 live lines + water (verbatim) + power (milli-int)
+ flora + `machine_state` + save into `sim/` as a block, split at its own seams to meet the 400-line
cap, with the 24 + 8 mechanical rows fixed on the way in; give `TileGrid` the machine/item/water/power
planes at the 16 px logic cell (legacy's 32 px cell is one metre; so is this build's 16 px logic cell —
the 4 px terrain grid and heightfield collision stay); add the 20 missing accessors to `observe()`; then
port the views that were blocked on those systems (`machine_view`, `water_view`, `visuals`, the HUD).
Sim lift 3,400 lines at a mechanical 600–800/day = 4–6 days; grid planes + `observe()` + suites 3–4 days;
grapple + PRE-2 3 days; view 5–7 days; economy ≈5; re-pins ≈3. **23–28 working days, 4.5–5.5 weeks.**
Failure mode: the grid adapter (C1's one seam) is larger than a set of planes — it is the one design
decision in the plan and it is EXPENSIVE by `CONTEXT.md`'s test (it shapes the tick order's data), so
it needs the director's ruling before it starts. Also closes V5, V6, V8, V10 and V11 in one move.

### B · flip
Days 1–7: the determinism retrofit (§3.2, §3.5 — ~1,300 lines in `main.gd`, `player.gd`, `grapple.gd`,
`factory_sim.gd`, `power_flow.gd`, `save_game.gd`, `hints.gd`), a bit-exact signature, a two-process
golden on the existing pattern. Days 8–10: re-clock the ~48 frame-driven harness layers and `PlayAgent`,
strip ~5,100 dead lines (two classes dangle: `BazaarPage` from `hud.gd`/`main.gd`, `Bazaars` from
`main.gd`/`world_renderer.gd`), drop on the 24 process steps and 52 tools with the remap done and the
five vacuous gates checked. Weeks 3–4: the economy redesign. **18–20 working days, 3.5–4 weeks**, to a
complete, deterministic-within-platform, replayable legacy with process CI.
What it does not have at the end: the structural gates (15 files over 400, ~53 functions over 50,
layer lint by construction, ~70 engine-import lines) red or waived; no `observe()` door and 7 live
`FactorySim` injections into the view; the world reverted to 32 px cells with one-metre coarse
collision (the four-resolution scheme, heightfield collision and the sub-cell mining bite of
`docs/ARCHITECTURE.md` §9 are gone, and the Slice 1.5 bite work with them); cross-platform still open.
Failure modes: (1) the five vacuous gates read green with the architecture switched off; (2) this is a
third pivot in nine days (08-25, 08-27, now) and the portfolio thesis becomes "determinism retrofitted
onto a 3,000-line coordinator"; (3) fast-forward and `time_scale` conflict with a single clock and
must be redesigned as ticks-per-frame; (4) the economy that killed legacy at fifteen minutes is still
its economy until week 3.

---

## 7. Recommendation — then STOP

**FINISH, amended to A′.** The decision driver is §3's answer: legacy's *sim* is not the
non-deterministic part. `FactorySim.tick()` is fixed-tick, integer-shaped and within-platform
deterministic today; its whole bill is a type pass. The non-determinism is the scene layer's two
clocks and frame-rate decisions, which both directions must restructure, and which the rebuild has
already half-replaced. That removes the flip's supposed advantage — determinism is not what it buys —
and it removes the rebuild's stated reason for treating the sim hub as a rewrite target, which is the
measured cause of the slowness (§5, §6). Lift the hub whole, keep the architecture, and the sequential
port's remaining bill is view work the rebuild already does at speed.

**If the director's priority is a playable build in under three weeks regardless of the
architecture, B is viable**, its plan is in this document and in L4's report, and its price is stated
in §6 rather than discovered later. The two differ by roughly a week on this evidence, which is inside
the estimate's error; they differ by the whole thesis of the project.

**Either way, three things transfer now and should not wait on the decision:** legacy's harness
protocol and verdict discipline (§4.3), the cross-platform probe (`frontier_corpus.gd` on both CI
platforms), and a bit-exact state signature for whichever sim is authoritative.

**This analysis stops here.** No branch was created, no file under `legacy/`, `core/`, `sim/`,
`interface/`, `view/` or `shell/` was touched, and §8 is a procedure, not a start.

---

## 8. Phase 2 procedure, conditional on the director's approval

**If A′:** (1) director's ruling on the grid planes (EXPENSIVE); ledger entry reversing the migration
map's `KEEP-CURRENT` on `factory_sim.gd`. (2) Lift `water_flow.gd` verbatim into `sim/fluid` with its
tests (the cleanest system port available, zero rows). (3) Lift `FactorySim` live code into
`sim/machines`, `sim/items`, `sim/transport`, `sim/economy` split at its own seams, dead blocks dropped,
the 24 + 8 rows fixed on the way, `machines` insertion order preserved as state, the hopper latch kept
as designed; two-process golden re-pinned from CI Linux after each step. (4) `TileGrid` planes +
`observe()` fields + `apply()` verbs from the 28 mutators. (5) PRE-2 and the grapple under `Fx`, after
the resolver ruling. (6) The views the systems unblock, in `PORT_ORDER.md`'s sequence. (7) Economy
(V13) as the director scopes it. (8) The worldgen `Fx` cycle (D0172) when cross-platform matters.

**If B:** (1) Check out `pre-pivot` as the working base on a branch; move the current tree's
`tools/`, CI and tests aside, keep `legacy/tools`. (2) L4's controller tick and command record; `player`
step and `grapple` clocks onto it; `advance` retired; `time_scale` as ticks-per-frame. (3) `FactorySim`
type pass, power milli-int, save v3, hints, seed, sorts. (4) Bit-exact signature; two-process golden;
seed+1 control. (5) Re-clock the harness layers; `PlayAgent` through the command record. (6) Strip
dead code; two dangling classes. (7) Remap and drop on the 24 process steps and 52 tools; assert the
five vacuous gates are not vacuous. (8) Economy. (9) Worldgen `Fx` cycle when cross-platform matters.

---

## 9. Open questions no reading can settle

- Whether Godot's `randi_range` is a pure-integer bounded draw (17 rows move from banned to CROSS if
  not); whether `FileAccess.store_var` round-trips a double bit-exactly; `str(float)`'s digit count.
- Whether IEEE basic ops actually diverge between the two CI platforms at these sites (D0171's
  root-cause caveat still applies); the `frontier_corpus.gd` probe answers it for legacy's generator.
- Rulings the workers could not make: the Splitter, the Ore Vent and power gating (16 of legacy's 54
  live tests hinge on them); the Crusher/packing/seep chain (133 lines, exists only for the Drift Rig,
  not on the §9 list); `sim.ramp_dir`'s authored ramps versus `Heightfield`.
- Three instruments in the current suite are quietly wrong today, independent of the decision (C5):
  `gate_status.py` mis-addresses the double-numbered gate 30 and its NO-CODE docstring is stale;
  `flaky_test_detector.py` can never parse `run_suites.sh`'s output; `run_local_battery.sh` exits 0 on
  failing gates unless `GATES_ONLY=1`. And gate 27 fails on this machine now (36 untracked recordings).
- Two provenance notes found on the way: `view/fx/light_layer.gd:13` says "NO CONSUMER TODAY" and
  `terrain_bake.gd:83,86` consumes it; `view/visuals/erase.gdshader` is an uncited code-identical lift.
