> **ARCHIVED 2026-09-03.** The WG-4 cell-denominated-constant conversion plan. EXECUTED in full
> (D0305, D0307; `docs/BRIEF.md` 2026-09-01 carries the sweep table). Kept for the measurements and the
> per-constant reasoning; nothing in it is pending.

# WG-4 — the conversion plan

**Read-only diagnostic pass. Nothing outside this file was touched.**

**Pinned at `c8d3ea77a8d45aad98baa781b056cd34a08331df`** (`c8d3ea7`, "docs(needs-director): P023/P024/P025
raised…"). Every `file:line` below is that hash unless the row says otherwise.

**Three things about the tree moved underneath this pass, and all three are recorded rather than
smoothed over**, because a report that silently averages two trees is worse than one that names both:

1. **HEAD advanced to `13a4ec5`** ("feat(view): terrain onto the coordinator, and the backdrop under it
   (D0276)") while this was being written. Two new painters landed —
   `view/visuals/terrain_painter.gd` and `view/visuals/backdrop_painter.gd`. **Both were re-scanned at
   `13a4ec5` and are classified below** (§3, bucket 2); neither adds a bucket-1 constant. The CI suite
   count went **48 → 49** (`tests/test_terrain_painter.gd`), and §6's exposure analysis was re-checked
   against the new list.
2. **The checked-out branch changed from `main` to `run/carve-measure`** during the pass. Both sit at
   `13a4ec5`; no content difference.
3. **`view/visuals/crumble_painter.gd` and `world_view.gd`'s live cosmetic clock were uncommitted
   work-in-progress when I read them, and are NOT on the line I pinned.** They now live on branch
   **`run/anim-clock` at `bdd2c06`** ("feat(view,sim): a cosmetic clock, crumble, and the pick's swing
   cadence"), which is not an ancestor of HEAD. Every citation of those two is tagged `bdd2c06:` and
   line-verified against that commit, not against my working-tree snapshot. On the pinned line,
   `view/world_view.gd` carries `const ANIM_TIME: float = 0.0` at **:28** and
   `WINDOW_MARGIN_CELLS` at **:33**.

---

## 0. The finding that changes the shape of the question

**WG-4 names one conversion factor. There are two, and they run in opposite directions.** Blind
multiplication is wrong not only because some constants are already correct, but because a second
population is wrong *the other way*.

The unit ladder, verified from source rather than assumed:

| | legacy | this build | source |
|---|---|---|---|
| one metre | `CELL` = **32 px** | `LOGIC_TILE_PX` = **16 px** | `legacy/src/core/factory_sim.gd:36`, `sim/body/body.gd:63` |
| the generator's cell | `CELL` = 32 px = **1 m** | `TERRAIN_CELL_PX` = **4 px** = **0.25 m** | `legacy/src/core/factory_sim.gd:36`, `sim/body/heightfield.gd:12` |
| depth readout | `depth_m(row) = row - SURFACE_ROW` | `depth_m(row) = floor(row / 4)` | `legacy/scenes/strata.gd:54-55`, `view/visuals/material_look.gd:114-115` |

Legacy states it outright, and this is the load-bearing quote for everything below:

> `legacy/scenes/strata.gd:16` — "`depth_m` is rows below the surface datum… **One metre is one cell, 32px.**"

Confirmed that legacy's generator really ran on that coarse grid and not on its fine layer:
`legacy/src/core/factory_sim.gd:24-25` declares `GRID_COLS: int = 128` / `GRID_ROWS: int = 128`, and
`LayeredWorldGen` writes `WorldData.cols`/`rows`. `SUBDIV` is a separate render/mold layer
(`legacy/src/core/fine_terrain.gd`). So a legacy world was 128 m × 128 m, and one legacy generator cell
was one square metre.

That gives **three** transfer rules, not one:

| the legacy constant is denominated in… | factor to this build | direction of the error if copied verbatim |
|---|---|---|
| **cell counts** (lengths) | **× 4** | **4× too small** — this is WG-4 |
| **cell counts** (areas / blob sizes / per-cell rates) | **× 16** | **16× too small** (or 16× too dense) |
| **metres, fractions, ratios, ticks, seconds, screen pixels** | **× 1** | correct, transfers intact |
| **absolute world pixels** | **× 0.5** | **2× too LARGE in metres** — the mirror class |

The fourth row is `docs/LEGACY_GAP.md`'s own "Findings that are defects in the CURRENT build" #4
("`RUN_SPEED 150`, `GRAVITY 900`, `JUMP_VELOCITY -365` identical to legacy… **double speed and double
gravity in metres**"). Verified here against source: `legacy/scenes/player.gd:26,29,32,37` reads
`RUN_SPEED: float = 150.0`, `GRAVITY: float = 900.0`, `JUMP_VELOCITY: float = -365.0`,
`MAX_FALL: float = 560.0` — byte-identical to `sim/body/body.gd:30-33`.

**Consequence for the ruling.** A single "multiply the cell constants by 4" sweep would correct the
first row, leave the second row still 4× short (because area needs 16, not 4), and do nothing about the
fourth row, which is a live, unruled population of its own. The four buckets below are drawn on those
lines.

---

## 1. Method, and the controls on it

Every search below was run with a positive control first, because a search that finds nothing may have
been incapable of finding anything.

- **`git grep -E` was not used at all.** `\b`/`\s` match nothing under `-E` (memory:
  `git-grep-ere-drops-escapes`); every scan used plain `grep -rn` with literal patterns.
- **Positive controls run and passed:** `grep -rn "const" core sim view interface` → **252 lines**
  (negative control `zzqqxxnotathing` → **0**); `grep -c "D0017" docs/DECISIONS_LEDGER.md` → **4**;
  `grep -rn "CAVE_FREQ" legacy/` → **2 hits**; `grep -rn "CELL_PX" core sim view interface` → **32**;
  `grep -c "^## D0" docs/DECISIONS_LEDGER.md` → **276**; `grep -rn "ShaftGenerator.generate" tests/`
  → **20**.
- **Declaration FORMS enumerated before any total was reported**, per
  `declaration-forms-a-scan-omits`. Across `core/ sim/ view/ interface/` the complete set is:
  `var` (530), `const` (191), `static func` (130), `func` (125), `class_name` (36), `class` (6),
  `static var` (4), `enum` (2). **There is no `@export` and no `@onready` anywhere in these four
  directories**, so those forms cannot hide a value. `static var` (4 instances, all in
  `core/split_rng.gd` / `core/entity_id_pool.gd` state) carries no scale constant.
- **Inline literals at their only use site** were swept separately with an awk pass that strips
  comments and keeps only code lines carrying both a numeric literal and one of
  `cell|row|col|px|tile|_m|metre` (case-insensitive variants). That pass is what surfaced
  `view/visuals/crumble_painter.gd`, a file created by another session *during* this pass, absent from
  the initial `find`, and since moved to branch `run/anim-clock` (`bdd2c06`).
- **`data/strata/*.yaml` is included even though the brief scoped the inventory to
  `core/ sim/ view/ interface/`.** WG-4's literal subject lives there, and those values reach `sim/`
  through `data/strata/generated.gd` → `sim/terrain_gen/strata_data.gd` →
  `sim/terrain_gen/shaft_generator.gd`. Excluding them would have produced a report about everything
  except the thing being ruled on.
- **Every legacy value below was read from the legacy file in this session**, and the quoted line is
  given. No value is reproduced from `docs/LEGACY_GAP.md` without independent confirmation, with one
  labelled exception (§5, the stale pocket-size measurement).

**One thing that has already changed since `LEGACY_GAP.md` was written and matters here:** WG-1, WG-2
and WG-3 are all **CLOSED** (D0254, D0257, D0258). `FASTNOISELITE_SD_CALIBRATION` is **0.9644**, not
the 0.574 the gap doc quotes, and `ValueNoise` is five-octave FBM now
(`sim/terrain_gen/value_noise.gd:78,133-135`). WG-4 is the last of the four still open.

---

## 2. BUCKET 1 — WRONG, undersized

**21 distinct constants across 57 file:line sites.** Fifteen are live (read by
`ShaftGenerator` today); six are inert (five unconsumed data fields, one uncalled code constant).

The three site files (`shallow_clay.yaml`, `reveal_test_dense.yaml`, `reveal_test_sparse.yaml`) carry
the same fields with the same values — `reveal_test_*.yaml`'s own headers say every field except `id`
and `reveal` is "copied verbatim from `shallow_clay.yaml`" — so each row below lists all three line
numbers.

### 1a · LENGTH constants (×4)

| # | site | current | legacy origin | correct | derivation |
|---|---|---|---|---|---|
| 1 | `data/strata/shallow_clay.yaml:24`, `reveal_test_dense.yaml:17`, `reveal_test_sparse.yaml:22` — `cave.min_depth_cells` | **6** | `legacy/src/core/layered_world_gen.gd:19` `const CAVE_MIN_DEPTH: int = 6` — "*Caves never breach this many tiles below a column's surface, which keeps the spawn base solid.*" | **24** | 6 legacy cells = 6.00 m. 6 terrain cells = **1.50 m**. × 4. |
| 2 | `shallow_clay.yaml:31`, `dense:21`, `sparse:26` — `strata_shelf.band_height_cells` | **4** | `layered_world_gen.gd:35` `const STRATA_BAND_H: int = 4` — "*Rows per band.*" | **16** | 4 legacy rows = 4.00 m. 4 terrain rows = **1.00 m**. × 4. |
| 3 | `shallow_clay.yaml:21`, `dense:14`, `sparse:19` — `cave.frequency` | **0.11** | `layered_world_gen.gd:21` `const CAVE_FREQ: float = 0.11` — "*Noise scale: smaller means larger, smoother pockets. ~0.10 gives room-sized caverns.*" | **0.0275** | Frequency is 1/length, so it scales the **other way**. 0.11 per legacy cell = 0.11 per metre → period **9.09 m**. 0.11 per terrain cell = 0.44 per metre → period **2.27 m**. ÷ 4. |

### 1b · AREA constants (×16)

`_grow_vein`'s `size` is a count of cells placed by an accretion blob
(`sim/terrain_gen/shaft_generator.gd:184-201`), so it is an **area**, and legacy says so:
`layered_world_gen.gd:131` — "*Vein body size in cells of the accretion blob.*" A legacy cell is 1 m²;
a terrain cell is 1/16 m².

| # | site | current | legacy origin | correct | derivation |
|---|---|---|---|---|---|
| 4 | `shallow_clay.yaml:41`, `dense:30`, `sparse:35` — `ore.size_min` | **8** | `layered_world_gen.gd:132` `const ORE_SIZE_MIN: int = 8` | **128** | 8 legacy cells = 8.00 m². 8 terrain cells = **0.500 m²**. × 16. |
| 5 | `shallow_clay.yaml:42`, `dense:31`, `sparse:36` — `ore.size_depth_bonus` | **44** | `layered_world_gen.gd:133` `const ORE_SIZE_DEPTH_BONUS: int = 44` | **704** | × 16, same axis. |
| 6 | `shallow_clay.yaml:61`, `dense:43`, `sparse:48` — `coal.size_min` | **6** | `layered_world_gen.gd:137` `const COAL_SIZE_MIN: int = 6` | **96** | 6 → 0.375 m². × 16. |
| 7 | `shallow_clay.yaml:62`, `dense:44`, `sparse:49` — `coal.size_depth_bonus` | **30** | `layered_world_gen.gd:138` `const COAL_SIZE_DEPTH_BONUS: int = 30` | **480** | × 16. |
| 8 | `shallow_clay.yaml:74`, `dense:52`, `sparse:57` — `iron.size_min` | **10** | `layered_world_gen.gd:176` `const IRON_SIZE_MIN: int = 10` | **160** | 10 → 0.625 m². × 16. |
| 9 | `shallow_clay.yaml:75`, `dense:53`, `sparse:58` — `iron.size_depth_bonus` | **30** | `layered_world_gen.gd:177` `const IRON_SIZE_DEPTH_BONUS: int = 30` | **480** | × 16. |
| 10 | `reveal_test_dense.yaml:68`, `reveal_test_sparse.yaml:75` — `reveal.size_min` | **6** | no direct legacy analog; the field is `_grow_vein`'s `size` argument via `shaft_generator.gd:222`, and it was chosen against the same ore/coal register | **96** | Same area axis as rows 4–9. **Weaker provenance than the rows above** — see §5 note. |

### 1c · SEED DENSITY (÷16, split across two constants)

`ShaftGenerator._density_count` (`sim/terrain_gen/shaft_generator.gd:127-128`) is
`round(width * per_col * height / DENSITY_ROWS)` — byte-for-byte legacy's
`legacy/src/core/layered_world_gen.gd:13-14`. Seeds per cell is therefore `per_col / DENSITY_ROWS`,
independent of world size. Measured:

```
legacy  ore: 204.8 seeds over 16384 m^2 = 0.01250 seeds/m^2      (128x128 cells, 1 cell = 1 m)
current ore: 614.4 seeds over  3072 m^2 = 0.20000 seeds/m^2      (48x1024 terrain cells)
                                                       -> 16.0x legacy
```

Two constants carry that 16×, and both are genuinely wrong on their own axis:

| # | site | current | legacy origin | correct | derivation |
|---|---|---|---|---|---|
| 11 | `sim/terrain_gen/shaft_generator.gd:29` — `const DENSITY_ROWS: int = 80` | **80** | `layered_world_gen.gd:10` `const DENSITY_ROWS: int = 80` — "*world height the `*_PER_COL` figures below are calibrated to*" | **320** | It is a **row count**. 80 legacy rows = 80 m = **320 terrain rows**. × 4. |
| 12 | `shallow_clay.yaml:38`, `dense:27`, `sparse:32` — `ore.attempts_per_col` | **1.0** | `layered_world_gen.gd:123` `const ORE_ATTEMPTS_PER_COL: float = 1.0` | **0.25** | Per **column**, and a legacy column is 1 m wide against this build's 0.25 m. ÷ 4. |
| 13 | `shallow_clay.yaml:58`, `dense:40`, `sparse:45` — `coal.attempts_per_col` | **0.8** | `layered_world_gen.gd:135` `const COAL_ATTEMPTS_PER_COL: float = 0.8` | **0.2** | ÷ 4. |
| 14 | `shallow_clay.yaml:73`, `dense:51`, `sparse:56` — `iron.attempts_per_col` | **0.5** | `layered_world_gen.gd:175` `const IRON_ATTEMPTS_PER_COL: float = 0.5` | **0.125** | ÷ 4. |
| 15 | `reveal_test_dense.yaml:67` / `reveal_test_sparse.yaml:74` — `reveal.attempts_per_col` | **0.6** / **0.15** | no legacy analog — the swept variable for `claims/C004` | **0.15** / **0.0375** | ÷ 4, to keep the *ratio* between the two sites (which is the thing under test) while restoring the physical density. **See §5 — this one is arguably a hold.** |

Rows 11 and 12–15 multiply: `320` and `÷4` together give exactly ÷16, restoring **0.01250 seeds/m²**,
1.00× legacy. Verified by re-running the same expression with the corrected values.

### 1d · INERT — real, derivable, and deliberately NOT proposed for this pass

| # | site | current | legacy origin | correct | why it is held |
|---|---|---|---|---|---|
| 16 | `core/seams.gd:60` — `const RUN_CAP: int = 3` | **3** | `legacy/src/data/seams.gd:26` `const RUN_CAP: int = 3` — "*Cells one plain swing may take along the grain.*" | **12** | 3 legacy cells = 3.00 m; 3 terrain cells = **0.75 m**. × 4. **Nothing in the tree reads it** — `grep -rn "RUN_CAP"` outside `legacy/` returns exactly two lines, both inside `core/seams.gd` itself (its own docstring at :23 and the declaration at :60). `tests/test_seams.gd` asserts nothing about it. The calve verb does not exist. |
| 17-21 | `shallow_clay.yaml:50,51,65,66,78` + the same in `dense`/`sparse` — `ore.pending_sim_economy.amount_base` **30**, `amount_depth_bonus` **170**, `coal.pending_sim_economy.amount_base` **30**, `amount_depth_bonus` **170**, `iron.pending_sim_economy.amount` **220** | as shown | `layered_world_gen.gd:143,144,139,140,178` | ÷16 **if** consumed per-cell (30 per 1 m² cell becomes **480 per m²** at 1/16 m² cells) | **Structurally unconsumed by construction** — nested under `pending_sim_economy` precisely so "unconsumed" is a fact a reader can see (D0025). `sim/economy`/`sim/items` do not exist. Whoever builds them chooses the unit; correcting them now decides that in advance. |

`ore.pending_sim_economy.rich_chance` (0.45) and `rich_amount_mult` (1.5) are **not** in this bucket —
they are a probability and a multiplier. Bucket 2.

---

## 3. BUCKET 2 — CORRECT ALREADY

**This is the bucket that makes blind multiplication wrong.** 40 constants, grouped by the reason each
one survived the grid change.

### 2a · Denominated in METRES, and multiplied by `TERRAIN_CELLS_PER_METER` at the point of use

`sim/terrain_gen/shaft_generator.gd:24` `const TERRAIN_CELLS_PER_METER: int = 4` is itself correct: it
is a definition, not a port.

- `data/strata/shallow_clay.yaml:13` (+`dense:7`, `sparse:12`) `max_depth_m: 256` — converted at
  `shaft_generator.gd:36`.
- `:16` `topsoil_shale_end: 40`, `:17` `stonereach_end: 140` — converted at `shaft_generator.gd:41-42`.
  These are the director's own GDD §11 boundaries, **not** legacy values (D0025 says so explicitly:
  legacy's `DEEPSLATE_ROW`/`SEAL_TOP` 76/84 were *not* ported).
- `:86` `ruin.min_depth_m: 100` — converted at `shaft_generator.gd:228`.
- `data/bands/*.yaml` `from_m` (all 8 files: `open_sky` −119, `topsoil` 0, `the_clayband` 10,
  `shale_reach` 24, `the_long_dark` 40, `the_deepslate` 56, `the_seal` 64, `stonereach` 66). Every
  file's own header carries the conversion: "*Legacy keyed bands by ROW at its own 32px logic cell with
  `SURFACE_ROW=20`; this file keys them by METRES BELOW SURFACE, which is scale-free — one metre is one
  logic tile on BOTH sides… Legacy row → metres: `row - 20`.*" Spot-checked: legacy `strata.gd:26`
  `{"from": 30, "name": "THE CLAYBAND"}` → `from_m: 10`. Exact.
- `view/visuals/material_look.gd:59-62` `ZONE_TINTS` `from_m`/`to_m` — ported in metres (D0252),
  legacy rows 30/46/64/86 → 10/26/44/66.
- `view/visuals/material_look.gd:73` `DEPTH_DARKEN_FULL_M: float = 128.0` — legacy normalised by
  `GRID_ROWS` (128 rows == 128 m); kept as metres so it survives the grid change.

### 2b · Dimensionless — fractions, probabilities, ratios, counts-of-counts

- `data/strata/*.yaml` `cave.x_stretch: 2.1` ← `layered_world_gen.gd:28` `CAVE_XSTRETCH: float = 2.1`.
  "X is compressed by this factor" — a ratio.
- `cave.threshold_top: 0.47` / `threshold_deep: 0.31` ← `layered_world_gen.gd:25-26`. Thresholds on a
  noise field whose output range is fixed. **Correct as thresholds** — but see the coupling warning in
  §5 and `docs/NEEDS_DIRECTOR.md` P021.
- `strata_shelf.shelf_every: 3` ← `layered_world_gen.gd:63` `STRATA_SHELF_EVERY: int = 3`. A count of
  **bands**, not of cells. Legacy's own comment forbids lowering it to 2, and D0017 carries that
  forward as a named, untested regression risk.
- `strata_shelf.shelf_resist: 0.34` ← `layered_world_gen.gd:65`. A threshold offset.
- `ore.chance_deep: 0.85`, `ore.shallow_floor: 0.34`, `coal.chance_deep: 0.95`,
  `coal.shallow_floor: 0.42` ← `layered_world_gen.gd:125,129,136,130`. Acceptance probabilities.
- `ore.pending_sim_economy.rich_chance: 0.45`, `rich_amount_mult: 1.5` ←
  `layered_world_gen.gd:147-148`.
- `core/seams.gd:46-49` `RATE_HORIZONTAL 1800` / `RATE_VERTICAL 1200` / `RATE_DIAGONAL 700` /
  `RATE_DENOMINATOR 10000` ← `legacy/src/data/seams.gd:16-18` (0.18 / 0.12 / 0.07). Probabilities,
  converted to exact integer ten-thousandths. `core/seams.gd:31-36` proves the integer form is exact
  over all 65,536 inputs per plane.
- `view/visuals/crack_painter.gd:31-36,47-48` `SHADE_ALPHA 0.22`, `CRACK_MIN 2`,
  `CRACK_PER_FRAC 5.0`, `LEN_BASE 0.18`, `LEN_PER_FRAC 0.34`, `ELBOW_TURN 0.4`, `SHADOW_ALPHA 0.45`,
  `CRACK_ALPHA_BASE 0.30`, `CRACK_ALPHA_PER_FRAC 0.6` ← `legacy/scenes/world_renderer.gd:952-968`,
  read and confirmed line by line. Alphas, counts, radians, and fractions-of-a-length.

### 2c · Denominated in TIME — ticks, seconds, Hz

Time is scale-free. `sim/body/body.gd:34,40,41,52,53,56` (`TICK_HZ 60`, `GROUND_ACCEL_TICKS 8`,
`GROUND_DECEL_TICKS 4`, `COYOTE_TICKS 6`, `JUMP_BUFFER_TICKS 6`, `APEX_FLOAT_TICKS 3`);
`sim/mining/mining.gd:50,55,56,64,65` (`TICKS_PER_HARDNESS 17`, `CRACK_HOLD_TICKS 150`,
`CRACK_HEAL_PER_TICK 512`, `RHYTHM_GRACE_TICKS 66`, `RHYTHM_DECAY_PER_TICK 11`);
`view/camera_rig.gd:42,45,46` (`LEAD_TIME 0.34 s`, `LEAD_EASE 5.0/s`, `FOLLOW_SPEED 8.0/s`), all three
verbatim from `legacy/scenes/main.gd:96,100,101`; `view/visuals/miner_look.gd:41,42`
(`DIG_TICKS_PER_FRAME 8`, `WALK_TICKS_PER_FRAME 6`);
`bdd2c06:view/visuals/crumble_painter.gd:34,45` (`DUR 0.24 s`, `FLASH_UNTIL 0.28` of duration)
← `legacy/scenes/world_renderer.gd:2488-2490`; `bdd2c06:view/world_view.gd:47`
(`SECONDS_PER_TICK 1/60`); `view/audio/score.gd:32-48` (Hz, seconds, dB).

### 2d · Denominated in SCREEN pixels, on a `CanvasLayer` the camera does not transform

The single most important distinction in this bucket, and the one a blind sweep would destroy: a screen
pixel is a screen pixel on both sides of the migration, at any world scale or zoom.

- `view/hud/depth_chip.gd:29-35,40-41` — `LABEL_SIZE 15`, `BAND_SIZE 10`, `MARGIN (10,8)`,
  `CHIP_HEIGHT 22.0`, `PAD 12.0`, `GAP 10.0`, `MIN_WIDTH 96.0`, `LABEL_BASELINE 6.0`,
  `BAND_BASELINE 5.0` ← `legacy/scenes/hud.gd:842-863`. Its `PaintLayer` is parented to a `HudLayer`,
  which is a `CanvasLayer` (`view/hud/hud_layer.gd:31`), so none of these is a world length.
- `view/hud/ui_theme.gd:81` `CANVAS := Vector2(640, 360)` — the authoring canvas, scaled to the window.
- `view/hud/hud_layer.gd:31` `HUD_CANVAS_LAYER: int = 10` — a z-order index.

### 2e · Explicitly re-derived at this build's grid rather than copied

These are the exemplars, and every one of them carries its own derivation in its own file.

- `view/visuals/material_look.gd:35` `CELLS_PER_METRE: int = 4`, and `_strata`/`_cell_jitter`
  (`:220-244`) computed **in metres** — "*feeding raw terrain rows into legacy's frequencies would give
  beds a quarter of their authored thickness — ~4.6 metres instead of ~18.5*". D0252.
- `view/visuals/material_look.gd:78` `LEGACY_CELL_SUBCELLS: float = 64.0` — `nugget_count / 64`
  preserves areal density exactly, "*one 32px legacy cell covers 64 of these*". D0189.
- `view/visuals/crack_painter.gd:78-84` — sizes cracks against `blow_px` (the blow's own footprint),
  not against the cell. Its header names WG-4 by ID and says "*If WG-4 is ruled on and the grid is
  re-denominated, this file needs no change*". `interface/interface.gd:305` derives
  `mining_blow_px = (2 * bite_radius + 1) * Mining.CELL_PX` at the door so no view has to.
- `bdd2c06:view/visuals/crumble_painter.gd:38-39` (**branch `run/anim-clock`, not on the pinned line**)
  `SPREAD_PER_CELL = 5.0 / 32.0`, `FALL_PER_CELL = 11.0 / 32.0`, applied as
  `* cell_px` at `:136-137`. Confirmed against `legacy/scenes/world_renderer.gd:2497`
  (`out * (t * 5.0) + Vector2(0.0, t * t * 11.0)`) — legacy's raw pixel offsets, divided by legacy's own
  cell so they survive at either denomination. Its header states the reasoning and names WG-4 by ID:
  "*copied literally onto a 4px cell they would throw debris eight cells clear of the hole it came
  from… carried as those fractions, so this file is correct at either denomination and survives
  whatever `docs/LEGACY_GAP.md` WG-4 is ruled to be.*" **When that branch merges it needs no WG-4
  change**, which is the useful fact here.
- `view/visuals/terrain_painter.gd:32` (**landed at `13a4ec5`**) `OVERDRAW_CELLS: int = 1` — one cell of
  overdraw so a cell straddling the screen edge is drawn whole. Sized in cells and applied against
  `cell_px` at runtime (`:42-49`); correct at any cell size, and no legacy origin — the file's own
  header states the legacy fillets/AO/surface-cap are deliberately **not** ported (T1 #2/#3).
- `view/visuals/backdrop_painter.gd:28,33` (**landed at `13a4ec5`**) `BAND_TINT: float = 0.10` (a
  fraction, with its own D0189 reasoning about announcement colours being too bright as fills) and
  `SPAN: float = 12000.0` — a deliberately generous backdrop rect, not a ported length: "*Big enough to
  cover any framing the debug flags can produce… being generous costs one draw call.*"
- `sim/mining/hollow_tell.gd:19-24` `CELLS_PER_TILE 4`, `REACH 4`, `SPREAD 2` — reads at the **logic
  tile**, restoring legacy's 20 samples and 4 metres. `:39` `TOTAL_WEIGHT` is *derived* from `REACH`
  and `SPREAD`, not written down. D0196.
- `sim/mining/mining.gd:30-31` `REACH_NUM 16 / REACH_DEN 5` — "*legacy's 32px cell and this world's
  16px logic tile are both ONE METRE, so the portable quantity is 3.2 METRES, not 102.4 pixels*". D0195.
- `sim/mining/mining.gd:82` `DEFAULT_BITE_RADIUS: int = 2` — derived from legacy's **volumetric** rate.
  D0200 is the exact WG-4 correction already made once, in `sim/`: "*Slice 1 charged a full metre's
  worth of hardness-seconds to remove ONE of those 16*".
- `sim/body/body.gd:63-65` `LOGIC_TILE_PX 16`, `STEP_UP_PX`, `MANTLE_PX` — D0035 caught exactly this
  class ("*STEP_UP_PX/MANTLE_PX were the wrong unit*") and fixed it: 4px → 16px.
- `sim/body/heightfield.gd:35` `DIG_HEADROOM_CELLS: int = 2` — derived (8 px / 4 px), restoring the
  property legacy got free from its 32px cell. D0269.
- `sim/body/vertical_resolve.gd:20` `V_SUBSTEP_PX: int = 2` — sized against **this build's** 4px cell,
  not legacy's clamp value.
- `sim/body/body.gd:79` `FLOOR_SCAN_ROWS: int = 48` — measured here (D0044), no legacy origin.
- `view/visuals/miner_look.gd:37` `WALK_SPEED_MIN: int = 10 * Fx.SCALE` — legacy's `10.0` px/s
  threshold against `RUN_SPEED`, and both sides port in pixels, so the **ratio** 10/150 is preserved
  either way. `docs/LEGACY_GAP.md` finding 4's own rule: "*constants stated relative to `RUN_SPEED`
  port unchanged either way*".
- `data/strata/shallow_clay.yaml:12` `width_cells: 48` — authored for this build ("*terrain-grid (4px)
  cells wide — a shaft, not an open world*"), no legacy analog. Legacy had `GRID_COLS = 128`, a
  different concept.
- `view/visuals/sky_painter.gd:38` `HORIZON_Y: float = 0.0` — derived: legacy's was
  `SURFACE_LINE(22) * CELL(32)`; this world's grid starts at the datum.
- `view/visuals/sky_painter.gd:237` `clear_r = TERRAIN_CELL_PX * 3.25` — legacy's `CELL * 3.25`
  re-expressed against this build's cell. Checked: legacy 32 × 3.25 = 104 px; 104 × `SCALE` = 13 px;
  4 × 3.25 = 13 px. Identical.

---

## 4. BUCKET 3 — DELIBERATELY DIVERGENT

Each has a ledger entry that states the divergence and the reason. **Do not propose changing these.**

| constant(s) | divergence | ledger |
|---|---|---|
| `view/visuals/sky_painter.gd:26-32` `LEGACY_CELL_PX 32.0`, `SCALE = 4/32 = 0.125`, `INV_SCALE = 8.0` | Scales the sky by the **cell** ratio, not the **metre** ratio. A metre-preserving `SCALE` would be 0.5, so every sky feature is deliberately 4× smaller in metres than legacy's. The stated frame is "*the same fraction of a screenful of CELLS*". `INV_SCALE` on `freq` (`:173`) is the correct inverse — D0244 records that multiplying by `SCALE` instead would have "*stretched every ridge wavelength 64x instead of shrinking it 8x*". | **D0244** |
| `sim/mining/hollow_tell.gd` — probing at the logic tile; out-of-bounds reads **SOLID** where legacy reads hollow | "*Probing the same PHYSICAL box cell-by-cell would be 32×33 = 1056 samples per blow — not a rescale, a rewrite.*" The OOB flip is because 48 terrain cells is only 12 logic tiles against a probe that reaches 4. | **D0196** |
| `sim/mining/mining.gd:82` `DEFAULT_BITE_RADIUS 2` | The volumetric correction, already applied. r=2's 13 cells is 0.81 m², "*the largest disc that stays under legacy's metre*"; `tests/test_mining_bite.gd` asserts r=3 would exceed it. | **D0200** (corrects **D0195**) |
| `sim/mining/mining.gd:50` `TICKS_PER_HARDNESS 17` | Derived from the shallow end only; the deep end deliberately lands faster than legacy ("*that is a tuning question for the director, not a porting error*"). | **D0195** |
| `sim/body/body.gd:50-51` `AIR_CONTROL_NUM 4 / DEN 5` | The one feel decision in the block, raised 3→4 on a measured sweep. §9's table names no air-control ratio. | **D0210** |
| `sim/terrain_gen/` scope: no caverns, tunnels, rifts, sinkholes, ledges, spires, rubble, lodes, aquifers, trees, seal | The whole reason `layered_world_gen.gd`'s other ~70 constants have no counterpart to convert. | **D0017**, **D0025** |
| `sim/terrain_gen/value_noise.gd:78` `FASTNOISELITE_SD_CALIBRATION 0.9644`, `:133-135` `FBM_OCTAVES 5` etc. | Re-derived by tail measurement, not SD. **WG-2 and WG-3 are closed.** | **D0258** (with **D0257**) |
| `data/bands/*.yaml` `from_m` | Re-keyed from legacy's rows to metres. | **D0189** |
| `view/visuals/material_look.gd` bedding/jitter in metres; `ZONE_TINTS` ported and **not applied** | The metres conversion is the ruling; the tint is parked on a glimmer hue clash (**P019**). | **D0252** |

---

## 5. BUCKET 4 — CANNOT TELL

### 4a · The absolute-world-pixel population — origin unambiguous, **convention unruled**

This is the ×0.5 mirror class from §0. Every value below is traceable to an exact legacy line, so the
*origin* is not what is ambiguous — **what is ambiguous is which convention the director wants**, and
`docs/LEGACY_GAP.md`'s own "Open questions this pass raises" already lists it: "*The scale convention —
pixels or metres for the remaining absolute constants (finding 4 above)*".

| site | current | legacy origin | in metres |
|---|---|---|---|
| `sim/body/body.gd:30` `RUN_SPEED_PX_S` | 150 | `legacy/scenes/player.gd:26` `RUN_SPEED: float = 150.0` | 4.69 → **9.38 m/s** |
| `sim/body/body.gd:31` `GRAVITY_PX_S2` | 900 | `player.gd:29` `GRAVITY: float = 900.0` | 28.1 → **56.3 m/s²** |
| `sim/body/body.gd:32` `JUMP_VELOCITY_PX_S` | −365 | `player.gd:32` `JUMP_VELOCITY: float = -365.0` | 2× |
| `sim/body/body.gd:33` `MAX_FALL_PX_S` | 560 | `player.gd:37` `MAX_FALL: float = 560.0` | 2× |
| `sim/body/body.gd:66` `CORNER_NUDGE_PX` | 6 | `docs/ARCHITECTURE.md` §9, **not** legacy | — (spec'd, not ported) |
| `view/camera_rig.gd:43` `LEAD_MAX` | 170.0 | `legacy/scenes/main.gd:98` `CAMERA_LEAD_MAX: float = 170.0` | 5.31 → **10.6 m** |
| `view/fx/particles.gd:30-106` — all speeds (60–150 px/s), sizes (1.8–3.0 px), gravities (6–420 px/s²), spawn jitter (±2 to ±9 px) | verbatim | `legacy/scenes/particles.gd`, **lifted unchanged** (D0216) | 2× |
| `view/visuals/miner_look.gd:95-98` — the 32×48 sprite drawn 1:1 on a 16×40 body | verbatim | `legacy/scenes/player.gd:664-793`, 32×48 on a 34px collider | 1 m × 1.5 m → **2 m × 3 m** |
| `view/visuals/crack_painter.gd:38-41` `SHADOW_WIDTH 3.0`, `CRACK_WIDTH 1.5`, `PIP_BASE 1.5`, `PIP_PER_FRAC 2.0` | verbatim | `legacy/scenes/world_renderer.gd:964-968` — `draw_line(…, 3.0)`, `draw_line(…, 1.5)`, `draw_circle(center, 1.5 + 2.0 * _mine_frac, …)` | 2× |

**Two specific things worth the director's eye inside this bucket:**

1. **`view/visuals/crack_painter.gd:29-30`'s own header is wrong about its own constants.** It says
   "*Legacy's constants, unchanged. Every one of them is a fraction or a colour; **none is a pixel
   count**, which is why they transfer while the size above does not.*" Four of them *are* pixel counts,
   quoted above from legacy source. The consequence is not a crash: at the default bite the crack length
   runs 3.6–10.4 px against a fixed 3.0 px stroke and a 1.5–3.5 px pip radius, where legacy's ran
   5.8–16.6 px against the same stroke — so the fracture reads proportionally **fatter** here, and the
   pip covers most of two terrain cells. This is a `caveat-in-prose-does-not-protect` instance: a
   correct general claim in a header, made false by four members of the set it describes.

2. **`view/camera_rig.gd:43` `LEAD_MAX 170.0` is inert in this build, and that is a null result worth
   stating rather than a defect.** Max reachable lead here: horizontal `150 × 0.34 = 51 px`, vertical
   `560 × 0.34 × 0.55 = 104.7 px`. The cap cannot bind. In legacy it *just* bound: the stride raised top
   speed to 232 px/s (`player.gd:51`) and `main.gd:694` multiplied the lead time by
   `(1 + STRIDE_LEAD × stride)` with `STRIDE_LEAD = 0.55` (`main.gd:97`), giving a vertical lead of
   `560 × 0.34 × 1.55 × 0.55 = 162.3 px` against the 170 cap. **`CameraRig` deliberately does not port
   the stride multiplier** (its header says so, and `docs/LEGACY_GAP.md` T1 #10 confirms the stride
   itself is absent). So the constant is correct-under-the-pixel-convention and simply unreachable
   until the stride lands.

**What would settle 4a:** one director ruling of the form *"absolute world-pixel constants port under
the PIXEL convention (values unchanged, physical quantities 2× legacy) — this is now the standing rule"*
or *"…under the METRE convention (halve them)"*. It is one sentence and it closes this entire bucket
plus `docs/LEGACY_GAP.md` finding 4 plus the grapple's own constants (PRE-2/T1 #12) before they are
written. **My recommendation: rule the PIXEL convention and write it down.** The pixel convention is
already load-bearing across the whole movement/acceptance corpus, the camera, the sprite and the
particle layer; the metre convention is already load-bearing in exactly the places that were re-derived
on purpose (Mining, HollowTell, MaterialLook, `data/bands`). Both halves are internally consistent
today; changing the pixel half would re-pin every movement number in the project to buy nothing a player
can name.

### 4b · No traceable legacy origin

| site | current | why it cannot be settled from legacy |
|---|---|---|
| `data/strata/shallow_clay.yaml:87`, `dense:60`, `sparse:65` — `ruin.radius_cells: 4` | 4 | **D0018** states the ruin has no legacy analog: "*the old `_stamp_bazaar_ruin` was tied to the dead Bazaar mechanic*", and its "*exact generation parameters (frequency, size, content rules) are undesigned — inventing them now would be deciding unstated design*". So there is no origin value to convert. **What it does mean physically, measured:** radius 4 terrain cells = **1.00 m**, a chamber **2.00 m across**, against a body that is 1.00 m × 2.50 m. The guaranteed chamber is shorter than the player. Whether that is a bug depends on a design intent that has never been stated. |
| `data/strata/reveal_test_dense.yaml:67` / `sparse:74` — `reveal.attempts_per_col` 0.6 / 0.15 | — | Listed in bucket 1c row 15 on the *arithmetic*, but it is the **swept variable** for `claims/C004` and the file's own comment says it is "*deliberately not tuned toward any notion of 'correct' yet*". Correcting it is a design act, not a conversion. `claims/C004-reveal-raises-dig-persistence.md` is `status: BLOCKED`, `last_measured: never`, so nothing is re-pinned by moving it either way. |
| `data/strata/reveal_test_dense.yaml:68` / `sparse:75` — `reveal.size_min: 6` | 6 | Same. Its provenance is "the same register the ore/coal fields were written in", which is an inference about the author's habit, not a cited legacy constant. **Evidence that would settle it:** a director statement of what a glimmer pocket should be in metres. |

---

## 6. BLAST RADIUS — bucket 1 only

The director asked for three categories, sharply separated. **The answer is unusually clean, and it is
the expensive answer:**

- **LOOK only:** *nothing.* Not one bucket-1 constant is a renderer number.
- **SIM BEHAVIOUR:** *nothing independently.* Every sim-behaviour consequence below arrives **through**
  world generation, not beside it.
- **WORLD GENERATION:** items 1–15 (§2a, 2b, 2c). All fifteen. Every seed re-pins.
- **NOTHING AT ALL:** items 16–21 (§2d, the inert set).

### 6a · The suites that go red, by filename, checked by reading them

**49 suites run in CI** (`.github/workflows/harness.yml` at `13a4ec5`; it was 48 at the pinned hash,
plus `tests/test_terrain_painter.gd`). Of those, exactly **four** reach a real `ShaftGenerator` run
against a real site config — verified by grepping every `tests/` file for `ShaftGenerator.generate` and
`StrataData`, then reading each hit:

| suite | how it is exposed | what specifically fails |
|---|---|---|
| **`tests/test_shaft_generator.gd`** | calls `ShaftGenerator.generate` and `_carve_caves` directly, 10 sites | `_test_band_hash_matches_reference` (:29-35) pins the shelf-row set for **`band_height=4, shelf_every=3`** against a from-scratch Python reference — **item 2 invalidates it**. `_test_carve_fraction_by_region` (:127-171) carries three ratchets: `shelf_frac > 0.0`, `shelf_frac < open_frac`, `\|open_frac − 0.0493\| < 0.0060`, `\|total_frac − 0.0329\| < 0.0060` — **items 1–3 move all four**, and the ±0.0060 band is tight. `_test_caves_never_carve_above_min_depth` (:51-63) reads `min_depth_cells` from the config, so it follows item 1 rather than breaking. `_test_ruin_carves_a_chamber` (:243-262) hardcodes `{"count": 1, "min_depth_m": 100, "radius_cells": 4}` in the test body — it will keep passing while testing a value the shipped config no longer has, if `radius_cells` is ever ruled on. |
| **`tests/test_shaft_replay_determinism.gd`** | `tests/fixture_shaft_replay_probe.gd` generates `StrataData.SHALLOW_CLAY` and runs a real `Body` over it for ~20,000 ticks | **`GOLDEN_HASHES` (:79-99), all 200 entries, re-pin.** This is the sim-behaviour consequence, and it arrives through generation. The file's own header states the re-pin protocol and it is not cheap: the array **must be captured from CI's own pinned Linux build**, never locally (D0167 made that mistake once). It has already been re-pinned three times this session (D0254, D0258, D0269) and each entry documents its own cause and divergence checkpoint. Divergence should be at **checkpoint 0** for any of items 1–3, because the seed reaches the field before the first cell is written — a divergence *partway* would be the alarming shape. |
| **`tests/test_reveal_spawn_bounds.gd`** | `ShaftGenerator.generate(StrataData.get_site(site), seed)` × 400 seeds × 2 sites | Its documented spawn-flush distribution — `reveal_test_dense` **213/400 (53.2%)**, `reveal_test_sparse` **56/400 (14.0%)** (`:15-16`, also in `tests/body/reveal_session_setup.gd:27-28`) — is a statistic **about a specific terrain field**. Items 1–3 change the field. This is also a **runtime** risk: the file records `ShaftGenerator.generate` at ~858 ms per 48×1024 shaft, ~414 ms of it five-octave noise, at 384 generations. |
| **`tests/test_reveal_replay_driver.gd`** | `const SITE_ID = &"reveal_test_dense"`, replays a committed recording | **D0256 already found this exact failure once**: its seed "*was pinned to a coincidence of the truncated noise field… it still reached its target column and still fired 6 digs, but hit glimmer 0 times*", and re-picking required scanning 59 seeds of which **only 37 (63%) qualify at all**. Any of items 1–3 (and especially item 15, reveal density) can reproduce that silently. |

### 6b · Suites that are NOT exposed, and this is the cost saving

Read and confirmed: the entire movement/acceptance/fuzz corpus runs on **hand-built** worlds, not on
generated terrain. `tests/body/fuzz_driver_common.gd:6,25,28` drives `HostileChamber`;
`tests/test_body_acceptance.gd:34` calls `HostileChamber.build()`; `tests/test_recorded_sessions.gd:38`
replays only against `["hostile_chamber", "movement_course"]`.

So **none** of these go red for any bucket-1 change:
`test_body.gd`, `test_body_acceptance.gd`, `test_body_dig.gd`, `test_body_fuzz.gd`,
`test_body_fuzz_fast.gd`, `test_body_fuzz_regression_d0122.gd`, `test_bounds_invariant.gd`,
`test_camera_rig.gd`, `test_cave_geometry.gd`, `test_corner_consent.gd`, `test_crack_painter.gd`,
`test_empty_population_guard.gd`, `test_entity_id_pool.gd`, `test_fixed_point.gd`,
`test_floor_source_telemetry.gd`, `test_footprint_grounding.gd`, `test_heightfield.gd`,
`test_hostile_chamber.gd`, `test_hud.gd`, `test_interface.gd`, `test_material_palette.gd`,
`test_miner_look.gd`, `test_mining.gd`, `test_mining_bite.gd`, `test_movement_course.gd`,
`test_particles.gd`, `test_reachability_sweep.gd`, `test_recorded_sessions.gd`,
`test_replay_determinism.gd`, `test_reveal_args.gd`, `test_reveal_metric.gd`,
`test_reveal_scene_dig_edge.gd`, `test_score.gd`, `test_seams.gd`, `test_settings.gd`,
`test_sky_painter.gd`, `test_split_rng.gd`, `test_step_up_grounding.gd`,
`test_terrain_painter.gd`, `test_tile_grid.gd`, `test_view_lifts.gd`, `test_view_window.gd`,
`test_world_materials.gd`, `test_world_view.gd`.

(`test_terrain_painter.gd` was checked at `13a4ec5` rather than assumed from its name: it builds its
own `TileGrid.new(GRID_W, GRID_H, 7)` at `:30` and returns **0** hits for `ShaftGenerator|StrataData`.)

Two of those deserve a specific note rather than a place on a list:

- **`tests/test_material_palette.gd` survives, but for a reason worth checking.** `:31`
  `const MAX_ROW: int = 1024  ## max_depth_m 256 * TERRAIN_CELLS_PER_METER 4` — derived from the
  metre-denominated field, not from a cell count. It calls `MaterialLook` directly and never builds a
  world. It would only break if `max_depth_m` or `CELLS_PER_METRE` moved, and neither is in bucket 1.
- **`tests/test_value_noise.gd` will stay green while quietly stopping measuring the shipped field.**
  `:105` and `:156` hardcode `var frequency: float = 0.11` and `var x_stretch: float = 2.1` as
  **literals**, under a comment (`:99-100`) claiming they are "*the real cave-carving
  frequency/x_stretch (`data/strata/shallow_clay.yaml`)*". `:178`'s row loop starts at `6`, which is
  `min_depth_cells`. If item 3 lands and these literals do not follow, the comment becomes false and
  the tail-matching test measures a frequency the game no longer uses. **This is a quiet-green in
  waiting and it must move in the same commit.** It is not on the red list precisely because it is the
  more dangerous kind of green.

### 6c · Non-test consequences

- **`docs/milestones/*.png` and `docs/MILESTONES.md`.** Every capture is pinned to a commit, so a
  generation change makes them historical rather than red. No gate fails; the images stop depicting the
  current world.
- **`tests/body/recordings/*.log`.** Six committed recordings carry `site=`/`seed=`/`bite=` headers and
  replay against generated terrain. They remain valid as **input traces** (D0198's rule) but stop being
  re-runnable as played. `test_recorded_sessions.gd` does not replay them against generated worlds, so
  no suite goes red — but `test_reveal_replay_driver.gd`'s single recording does (§6a).
- **`claims/C004-reveal-raises-dig-persistence.md` is `status: BLOCKED`, `last_measured: never`.**
  There is no C004 number to re-pin. This is the one place the cost is genuinely zero.
- **Gate 7 (instrument/game LOC velocity).** A yaml-and-two-constants change is a small game diff. If
  test re-pins land in the same arc, watch the ratio — `docs/WORKING.md` records PR #10 parked on
  exactly this.

---

## 7. RECOMMENDED SEQUENCE

### The one thing that must not be done piecemeal

**Items 4–9 (sizes, ×16) and items 11–15 (densities, ÷16) are a single arithmetic unit.** Total ore
volume is `attempts × accept × mean_size`. Correcting only the sizes multiplies every material in the
world by 16; correcting only the densities divides it by 16. Correcting both leaves total volume
approximately unchanged and converts the world from *many tiny scattered specks* into *fewer,
room-scale bodies* — which is the actual deliverable, and is the same reading
`docs/LEGACY_GAP.md` gives for the caves ("*The build does not over-cave — it under-caves and
fragments*"). **They ship together or not at all.**

### Take these together, in one re-pin (one branch, one CI golden capture)

**Batch A — the generator conversion.** Items 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14 (thirteen
constants, three yaml files plus `sim/terrain_gen/shaft_generator.gd:29`), plus the coupled literals in
`tests/test_value_noise.gd:105,156` **in the same commit**.

One re-pin is right rather than four because the expensive artifact — `GOLDEN_HASHES`, captured from
CI's pinned Linux build — costs the same whether one constant moved or thirteen. Splitting it pays that
cost four times and produces four intermediate worlds nobody wanted.

Order of work inside the batch:

1. **Measure before touching anything.** Extend `test_shaft_generator._measure_carve` to also report
   pocket-count and pocket-size distribution and total void fraction, and record today's numbers.
   `docs/LEGACY_GAP.md`'s pocket figures ("40 pockets, median 21 cells… at 0.0275: 11 pockets, median
   101") were measured **before** D0254's seed fix and D0258's octave port and are stale for the current
   field. Do not carry them forward. This is also `docs/NEEDS_DIRECTOR.md` P021's own decision-free half.
2. Change the thirteen constants and the two test literals.
3. Re-measure. **Re-derive the three ratchet bands in `_test_carve_fraction_by_region` from the new
   measurement**; do not widen them. `_test_band_hash_matches_reference`'s expected shelf-row set must
   be regenerated from the Python reference at `band_height=16`, not hand-edited.
4. Mutation-test the re-pinned ratchets before trusting them: revert one constant, confirm red.
5. Re-capture `GOLDEN_HASHES` **from CI's pinned Linux build**, confirm divergence begins at
   **checkpoint 0**, and cross-check elementwise against the local macOS run.
6. Re-pick `test_reveal_replay_driver`'s seed by scanning, exactly as D0256 did — and report the
   qualification rate, because it is the number that says whether the seed is a coincidence again.
7. Re-baseline `test_reveal_spawn_bounds`'s 400-seed flush distribution.

### Hold these, and here is the argument

- **Item 15, `reveal.attempts_per_col`.** Hold. It is `claims/C004`'s swept variable, not a ported
  constant, and its file says it is deliberately untuned. Moving it in Batch A conflates a conversion
  with a design change on the one axis a claim is watching. If Batch A's density correction makes the
  sparse site produce nothing at all, that is a *finding to report*, not a reason to quietly retune.
- **Item 10, `reveal.size_min`.** Hold with item 15, same reason.
- **Item 16, `Seams.RUN_CAP`.** Hold, and **do not correct it in isolation**. It has zero callers and
  zero assertions; the calve verb it serves does not exist; `BitRules`, which supplied its cap in
  legacy, is dead (`docs/LEGACY_GAP.md`, "What is dead"). Correcting an inert constant produces a
  number nobody can check and a green nobody can trust. Convert it *in the commit that builds the
  verb*, where a test can see it fire.
- **Items 17–21, `pending_sim_economy`.** Hold. They are nested under that key specifically so
  "unconsumed" is structural rather than a claim in a comment (D0025). The correct unit is a decision
  belonging to whoever builds `sim/economy` — per cell, per metre, or per body. Converting them now
  pre-decides it, and the file's own comment already instructs the right thing: "*Whichever module lands
  first should read these and promote them back to ore's top level.*"

### Two items I recommend the director rule on but **not** by converting

- **`cave.frequency` (item 3) at this world's width.** This is the one place where the metre-correct
  answer may be the wrong answer, and it is arithmetic, not taste. Measured: across 48 columns at
  `x_stretch 2.1`, the field spans **2.51 noise periods** at `freq 0.11` and **0.63** at the corrected
  `0.0275`. Vertically it spans 112.6 and 28.2 periods respectively. **A metre-correct cave frequency
  means the entire 12 m shaft width sits inside less than one noise period** — the field becomes
  essentially monotone across x, and lateral cave structure disappears entirely while vertical structure
  stays rich. Legacy authored `0.11` for a **128 m-wide open world**; this build is a **12 m-wide
  shaft**. The conversion is arithmetically right and may still be the wrong number for a world 10×
  narrower than the one it was tuned in. **Two honest options:** take `0.0275` and accept a world with
  vertical-only cave structure (defensible — "*the player's own shaft is the vertical structure now*",
  D0017), or take an intermediate value derived from *this* world's width and say so. Either way it
  should be a stated choice, not a side effect of a sweep. `docs/NEEDS_DIRECTOR.md` P021 already names
  this as candidate (1) and calls it "*the explanation I find most likely*" for the missing 15%.
- **`cave.threshold_top` / `threshold_deep` / `shelf_resist` (bucket 2).** They are correct as
  thresholds and are not in bucket 1. But the *fraction* they select is a property of the field, and
  item 3 changes the field's spatial structure. Expect the carve fraction to move; **re-measure it, do
  not predict it**, and re-derive the ratchets from the measurement (step 3 above). D0258's own lesson
  applies directly: a constant can be honestly derived and still calibrate the wrong quantity.

### Do these first, and they cost nothing

- **Rule the pixel/metre convention (§5, bucket 4a).** One sentence, and it closes the entire
  second population before the grapple's constants are written. This is independent of Batch A and
  should not wait on it.
- **Fix `view/visuals/crack_painter.gd:29-30`'s header claim.** Four of the constants it says are not
  pixel counts are pixel counts. Pure documentation; no behaviour change; removes a caveat that
  currently protects nothing.

---

## 8. What I could NOT determine

Stated plainly, with the evidence that would settle each.

1. **Whether the pixel-denominated population (§5, 4a) is wrong at all.** The arithmetic is certain
   (2× in metres); the *intent* is not. **Settles it:** a director ruling on the convention. I recommend
   PIXEL and gave the argument, but I am not the one who decides it.
2. **`ruin.radius_cells: 4` (§5, 4b).** No legacy origin exists to convert from — D0018 says the
   parameters are undesigned. **Settles it:** a statement of intended chamber size in metres. The
   measured fact that may inform it: at 4 cells the chamber is 2.00 m across against a 2.50 m body.
3. **`reveal.attempts_per_col` / `reveal.size_min`.** Whether these are conversions or design knobs.
   **Settles it:** whether C004's density sweep is meant to compare *physically comparable* densities
   (then convert) or *arbitrary* ones (then do not).
4. **What the corrected world actually looks like.** I ran no Godot process — the harness is not
   concurrency-safe and other sessions hold this tree. Every number in this report is either read from a
   file, quoted from a prior committed measurement with its provenance named, or derived arithmetically
   in a Python snippet whose inputs are all cited file:line values. **The carve fraction, pocket-size
   distribution and total void fraction after correction are not predicted anywhere in this document,
   deliberately.** They must be measured (§7, step 1 and step 3).
5. **NULL RESULT, checked rather than assumed: legacy's "near 15%" was never a measurement.** P021's
   candidate (3) suspected this; it is now confirmed against source. The phrase occurs **exactly once
   in all of `legacy/`** — `grep -rn "near 15%\|15% of the underground" legacy/` returns a single hit,
   `legacy/src/core/layered_world_gen.gd:23`, inside the comment above `CAVE_THRESHOLD_TOP`. The only
   carve-fraction assertion legacy actually shipped is in `legacy/tests/test_worldgen.gd:421-427`, and
   it is an **upper bound in the opposite direction**: `_check(undirected < 0.25, …)` and
   `_check(open_frac < 0.32, "…the underground is solid-dominant all in")`, with `open_frac` computed
   as `carved / total_below` and `WorldData.routes` subtracted out at `:386-390` — the "guard that
   needs an exemption carved into it" `docs/LEGACY_GAP.md` already names. **Legacy never measured a
   15% floor; it measured a 25%/32% ceiling and stayed under it.** So "near 15%" is an aspiration in a
   comment, and chasing it by moving thresholds would be `range-read-as-observations` on a number with
   no observation behind it. This materially weakens P021 candidate (1) as a *motivation* for
   converting `cave.frequency` — the conversion is still right on its own arithmetic (§2a item 3), but
   it should not be justified by a 15% target that does not exist.

### One search that could not have found its subject, reported as required

**The inline-literal sweep is scoped by vocabulary, not by exhaustion.** It keeps code lines carrying
both a numeric literal and one of `cell|row|col|px|tile|_m|metre`. A cell-denominated literal written
into a line that uses none of those words — say a bare `if gap > 6:` — would not appear. I mitigated
this by reading all 36 `.gd` files in the four directories directly rather than relying on the sweep
alone, and by reading `sim/terrain_gen/shaft_generator.gd` in full, but **I cannot claim the inline-
literal population is exhaustively enumerated the way the `const` population is.** The `const`
population *is* exhaustive: 191 declarations, forms enumerated first, no `@export` or `@onready`
present to hide one.
