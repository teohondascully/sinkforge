> **SUPERSEDED 2026-08-25.** One of the two read-only audits that established the ground truth for the pivot. Remains accurate about the code it measured (the codebase now in `legacy/`).
> Kept for provenance: `legacy/` may still contain code that implements what this document describes,
> and an agent reading that code needs to be able to find out why. See `docs/GDD.md` for current design.

---

# SINKFORGE Codebase Compatibility Audit vs. the Target Architecture Brief

**Audit date:** 2026-08-25. **Pinned commit:** `666e551` (`git rev-parse HEAD`). **Auditor:** 19 parallel read-only
agents (one Workflow run) plus two live harness runs (`tools/check_frametime.gd`, `tests/test_stress.gd`) and
one follow-up agent, orchestrated and synthesized by the session that produced this file. No source, test,
harness, or doc was modified while gathering evidence; the only files this audit produced are this one and its
raw working data under this session's scratchpad.

**What this document is:** a measurement of the current codebase against the architecture brief the director
supplied, scored by the brief's own Section 18 rubric. **What it is not:** a design opinion, a proposal, or the
start of an implementation. Per the brief's own Section 18.5, this audit does not evaluate whether the game
design is good and does not propose design changes.

**Scope decision (from the director's Q1 answer, verbatim intent):** the pivot is *same game, materially
revised design, new architecture* — vertical excavation + factory + embodied movement survives; the Bazaar,
persistent-world structure, and the seven-layer plan do not. Section 1 of the brief is scored as current, not
obsolete. Where a subsystem's compatibility depends on whether the Bazaar concept survives, this is flagged
explicitly rather than silently baked into one score.

---

## 0. Headline result

**The decision rule outputs INCREMENTAL, not REBUILD** (full application in §6). Of the rule's six conditions,
one trips true and it does so on a single 152-line file's coupling to one Node2D class's constants — not on
anything resembling systemic engine coupling, a dependency cycle, an inflated cost ratio, or a
CharacterBody2D-bound controller. The other five conditions are false, several by a wide margin:

- **Zero dependency cycles** in the entire 252-file `.gd` graph (Tarjan's algorithm, exact).
- **72% of the 25 measured subsystems already score ≥3/5** compatible (rule's rebuild trigger is <40%).
- **Sim-layer engine coupling averages ~1.1–1.3 out of 5**, not the ≥3.5 the rule tests for.
- **Movement is not built on `CharacterBody2D`/`move_and_slide`** — condition 6 is false outright.
- **Items and machines are packed `Dictionary`/`Array` data, not per-instance Nodes** — the codebase already
  avoids the Section 11 anti-pattern condition 4 tests for.
- The LOCKED architecture decision this project already made — "the sim is node-free" — **holds under the
  brief's stricter P1 test, with no gap**, across all 11 files / 5,399 lines of `src/core/`.

Two things any two-condition rebuild trigger can't see, because they're not in the rubric:

1. **`tools/` has grown 90% (33,773 → 64,319 GDScript lines) in the 5 days since the last portfolio audit.**
   The repository is, by raw volume, more instrumentation than game — 2.6 lines of harness/test code per line
   of game code (§Appendix A) — though 36% of that is gitignored scratch work, not shipped harness.
2. **`docs/A_PLUS_PROGRAM.md` already shows all six of its areas CLOSED.** There is no live A+ work to pause.
   What the director's "pause new investment" instinct actually protects is the next feature after A+'s exit —
   Freight Winch — and that's a live, real risk under any REBUILD-leaning read of this data (§7).

---

## 1. Subsystem compatibility matrix

25 rows, one per brief Section-5 subsystem this repository has a real analog for (`sim/commands` scored on its
absent-but-inferable de facto surface). `layer` is the brief's canonical name for the subsystem's *function*,
not necessarily where the code sits today — three rows (`sim/body`, `sim/run`'s closest analogs) are functionally
sim-tier but physically implemented in `scenes/`, which is itself the loudest structural finding in this audit
(§1.1). Hours are engineering-judgment **estimates**, not measurements — flagged inline throughout the raw
agent data, and where an agent left them at 0 (unpopulated rather than genuinely zero), this table fills the
gap with an orchestrator-level estimate marked `[est]`, kept clearly separate from agent-derived numbers.

| Subsystem | Exists | LOC | Engine coupling | Determinism | Data-driven | Compat. | Verdict | Port hrs | Greenfield hrs |
|---|---|---:|:-:|:-:|:-:|:-:|---|---:|---:|
| sim/terrain_gen | yes | 1,273 | 1 | 0 | 4 | **4** | PORT | 45 | 130 |
| sim/world | yes | 385 | 2 | 0 | 4 | **3** | REWRITE | 20 | 40 |
| sim/body *(physically `scenes/`)* | yes | 1,207 | 4 | 3 | 4 | **4** | PORT | 16 | 80 |
| sim/items | yes | 635 | 0 | 0 | 0 | **4** | PORT | 20 | 45 |
| sim/machines | yes | 417 | 0 | 0 | 3 | **4** | PORT | 16 | 35 |
| sim/behaviors | yes | 1,302 | 0 | 0 | 4 | **2** | REWRITE | 70 | 55 |
| sim/transport (power) | yes | 89 | 0 | 0 | 0 | **5** | KEEP | 1 | 6 |
| sim/fluid (water) | yes | 100 | 0 | 0 | 0 | **5** | KEEP | 1 | 8 |
| sim/economy | yes | 189 | 1 | 1 | 2 | **4** | PORT | 8 `[est]` | 20 `[est]` |
| sim/meta (save) | partial | 455 | 1 | 0 | 0 | **2** | REWRITE | 15 `[est]` | 60 `[est]` |
| sim/run | **no** | 450 | 3 | 2 | 2 | **1** | REWRITE | 5 `[est]` | 50 `[est]` |
| sim/commands | **no** | 0 | 3 | 1 | 4 | **1** | REWRITE | 0 | 20 |
| sim/telemetry | partial | 10 | 0 | 0 | 4 | **2** | REWRITE | 2 | 16 |
| sim/invariants | partial | 305 | 1 | 0 | 4 | **3** | PORT | 12 | 50 |
| view/render_world | yes | 4,736 | 5 | 3 | 3 | **3** | PORT/REWRITE† | 80 `[est]` | 220 `[est]` |
| view/render_entities | yes | 1,210 | 4 | 1 | 2 | **4** | PORT | 35 `[est]` | 50 `[est]` |
| view/fx | yes | 350 | 4 | 3 | 4 | **4** | PORT | 15 `[est]` | 30 `[est]` |
| view/hud | yes | 2,905 | 4 | 2 | 3 | **3** | PORT | 70 `[est]` | 150 `[est]` |
| view/camera | partial | 56‡ | 5 | 3 | 4 | **2** | REWRITE | 5 `[est]` | 25 `[est]` |
| shell (session controller) | yes | 6,751 | 4 | 3 | 3 | **4** | PORT | 60 | 350 |
| shell (Bazaar, as generic shop-UI infra)§ | yes | 2,641 | 3 | 1 | 2 | **4** | PORT | 30 | 120 |
| harness/headless | yes | 1,968 | 2 | 0 | 3 | **5** | KEEP | 10 `[est]` | 0 |
| harness/scenario | **no** | 32,106 | 4 | 1 | 5 | **2** | REWRITE | 0 | 500 `[est]` |
| harness/agent_api | partial | 3,063 | 4 | 4 | 5 | **4** | PORT | 40 `[est]` | 90 `[est]` |
| harness/report | yes | 818 | 0 | 0 | 2 | **5** | KEEP | 8 `[est]` | 0 |

† `view/render_world`'s own centerpiece, `world_renderer.gd` (3,656 lines, the largest file in the repo), is
individually REWRITE in the file salvage list (§3) — too Godot-idiom-specific to port mechanically — while its
five extraction-seam siblings (`machine_view.gd`, `water_view.gd`, `rope_view.gd`, `terrain_painter.gd`,
`sky_painter.gd`) are individually PORT. The row score blends both.

‡ Measured as a lower-bound identifier-line proxy inside `scenes/main.gd`, which was not in this audit's file
list and was not read in full — flagged, not guessed at (§8).

§ Scored per the director's explicit instruction: as generic shop/menu infrastructure, separately from whether
the Bazaar *concept* survives (it doesn't, per Q1). `bazaars.gd` (245 LOC, the one file that *is* the
Bazaar-as-physical-structure) is scored DELETE on its own in the file salvage list and drags this row down from
what its seven siblings alone would earn.

**18/25 rows (72%) score ≥3.** The seven that don't: `sim/behaviors` (13 machine behaviors, only 2 map cleanly
to the brief's ~8 composable primitives — real redesign, not decomposition-by-rename), `sim/meta` (a single
undifferentiated save envelope with zero run/meta separation), `sim/run` and `sim/commands` (genuinely don't
exist — not under-implemented, structurally absent), `sim/telemetry` (one narrow cosmetic event queue, no
system), `view/camera` (no standalone module; lives inline in an unaudited 3,003-line controller file), and
`harness/scenario` (108 check-layer files of mature, well-tested, but purely imperative content with no
declarative scenario format — the single largest LOC subsystem measured in this whole audit).

### 1.1 The one finding that recurs across almost every low score

**A structural naming mismatch, not a coupling defect.** The brief's Section 5 catalog places movement in
`sim/body` and expects it engine-free; SINKFORGE's own `docs/ARCHITECTURE.md` classifies `scenes/player.gd` and
`scenes/grapple.gd` as **view**, "representation only." Both descriptions are correct about the *code that
exists* — `player.gd` is `class_name Player extends Node2D` with real `_physics_process`/`_unhandled_input`
hooks — and both miss that `grapple.gd` is already `RefCounted` with zero engine API touched, and that
`tools/check_controls.gd` already proves `Player.new()` runs its non-draw logic off-tree today. The movement
*math* doesn't need the engine; the *file* is currently fused to it by convention, not necessity. The same
pattern repeats for `sim/run`: nothing in this codebase implements a bounded run with a duration — no `R3`,
no `run_duration` constant, no rig-driven pump timer — and the closest-named files (`score.gd`, `payouts.gd`,
`objectives.gd`) are, by their own doc comments, ambient music, floating-text cosmetics, and a tutorial
checklist respectively. Grepping for "run" or "score" surfaces the wrong files entirely; the actual gap (no run
concept exists at all) produces no error anywhere because nothing in the harness expects one.

---

## 2. Coupling analysis

**Dependency graph: zero cycles, exactly.** Built the full script-dependency graph from `preload("res://...")`
(42 edges) and `extends "res://..."` (125 edges) across all 252 `.gd` files in `src/`, `scenes/`, `tools/` and
ran Tarjan's SCC algorithm: 0 nontrivial strongly-connected components, 0 self-loops. `load("res://...")` (91
call sites) never targets a `.gd` file in this codebase — it's used exclusively for `.tres`/`.gdshader`/`.tscn`.
The graph is shallow: no file has fan-out above 4 (`src/core/factory_sim.gd`, preloading its four subsystem
files), so there's no long chain for a cycle to hide in. A secondary, noisier `class_name`-bare-type-reference
scan found no additional real cycle (one apparent hit was hand-verified as a doc-comment false positive) but
did surface `FactorySim` as a pervasive second-order hub — expected and consistent with the LOCKED
one-shared-sim-object architecture, not an accidental one.

**Two God objects, both explainable:**
- `tools/check_base.gd` — 124 of 252 files (63% of `tools/`) extend it directly. By design (its own header):
  literal-path `extends` was chosen specifically so a bare `godot --script` layer invocation doesn't depend on
  the global class cache. Zero fan-out. This is harness-internal, not a gameplay coupling problem.
- `src/core/factory_sim.gd` — the single shared sim object every other subsystem holds a typed reference to.
  Matches the LOCKED architecture description exactly; not a defect.

**Files over 400 lines: 76 of 257** (`find ... | xargs wc -l`, full list in the raw workflow output). Largest:
`scenes/world_renderer.gd` at 3,656 lines — independently re-measured and confirmed against
`docs/A_PLUS_STATUS.md`'s own claim (3,656 as of `096974e`), not merely restated. Next: `src/core/factory_sim.gd`
(3,259), `scenes/main.gd` (3,003) — **neither of the two largest game-logic files was in this ticket's read
list**; `main.gd` in particular was only spot-read for camera/verb citations, never read in full, and that gap
is real (§8). Two more of the top ten (`tools/play_tests.gd` 2,181, `tests/test_sim.gd` 2,015) are
harness/test files, consistent with the instrumentation-weighted LOC finding in the Appendix.

**Direct scene-tree reach-ins (the closest analog to a "layer violation" count, since no literal
`sim`/`view`/`shell` split exists yet):** `src/` scores 0 across `get_node(`, `get_tree(`, `"/root"`, and `$`
shorthand — direct, strong corroboration of the LOCKED node-free ADR. `scenes/` scores only 1 hit on the same
four patterns (`main.gd:426`, a scene-reload call) — but this **undercounts** the view layer's real reach-in
surface: `scenes/` uses Godot 4's `%UniqueName` idiom 71 times, a pattern the requested grep never covered. Read
`scenes/=1` as "the 4-pattern grep is nearly blind to this codebase's actual node-access idiom," not as "the
view layer barely touches the tree."

**The one real, measured layer-violation analog:** `scenes/world_seeder.gd` (152 lines, self-classified in its
own docstring as "sim tier... no scene nodes") references `MainView` (a `Node2D`) constants **32 times** across
15 distinct symbols, for pure layout numbers (`MainView.MINESHAFT_COL`, `ADIT_CHAMBER_COL`, etc.) it needs to
place tutorial fixtures. `docs/ARCHITECTURE.md` itself files this same script under `scenes/` — "representation
only" — so this is a real, pre-existing classification tension in the codebase's own documentation, not an
artifact of this audit. Every other file in every other row scored 0 layer violations. This single 152-line
file is what trips condition 3 of the decision rule (§6).

---

## 3. Salvage inventory

**Method:** subsystem agents produced detailed, cited KEEP/PORT/REWRITE/DELETE rows for every file they read in
full that exceeded 100 lines or appeared in `docs/ARCHITECTURE.md`'s module index (64 unique `.gd` files + 5
shaders, individually justified — full table in the raw workflow output, `sm_salvage.txt`). The remaining 199
`.gd` files were classified mechanically by directory-default rule (below), since a per-file agent pass across
all 257 files was judged not to add signal over the pattern the detailed 64 already established for each
directory. Combined (approximate — a small reconciliation gap of ~1 file from path-formatting artifacts,
not investigated further):

| Verdict | Detailed (agent-cited) | Mechanical (directory-default) | Combined |
|---|---:|---:|---:|
| KEEP | 21 | 17 | ~38 |
| PORT | 39 | 9 | ~48 |
| REWRITE | 3 | 103 | ~106 |
| DELETE | 1 | 70 | ~71 |

**The mechanical defaults**, in order of how much they actually decide:

- **`tools/_scratch_*.gd` (70 files, DELETE):** every one is gitignored (`.gitignore:105`) and has *never been
  committed* (`git log --oneline -1` on a sample returns nothing) — these were never part of the shipped
  repository. This is also 36% of `tools/`'s raw GDScript line count (§Appendix A), which matters for reading
  the instrumentation-ratio finding correctly: it's inflated by throwaway analysis scripts, not by maintained
  harness surface.
- **`tools/check_*.gd` not individually detailed (103 files, REWRITE):** the harness/scenario finding applies
  directly — imperative, one-bespoke-script-per-test-case content. The four that *were* individually read
  (`check_saveload.gd`, `check_save_durability.gd`, `check_settings.gd`, `check_mining.gd`) all scored PORT, not
  REWRITE, because their assertion logic is sound and portable even though the GDScript itself needs
  rewriting against a new sim API — the REWRITE default likely undercounts how much of this population is
  closer to PORT on individual inspection; treat the 103 figure as a conservative (rebuild-leaning) default,
  not a verified REWRITE for every file in it.
- **`src/core/` and `scenes/` non-detailed files (PORT default):** matches the pattern every individually-read
  sibling in the same directory showed.
- **`src/data/` (KEEP default):** matches the ground-truth-verified Resource-schema pattern.

**Named DELETE, with reasons (not defaults):** `scenes/bazaars.gd` (245 lines) — the one file that *is* the
Bazaar-as-physical-structure mechanic itself (wood-frame detection, ruin/ghost-slot presentation, market-stall
decorative transform). Zero generic-infrastructure reading is possible; nothing here is "a shop UI," it's "a
structure the world detects and decorates." This is the one salvage verdict most directly downstream of the
director's Q1 answer.

**Named KEEP as-is (selected, highest-confidence):** `src/core/power_flow.gd`, `src/core/water_flow.gd`
(89/100 lines, engineered-deterministic, active-cell-only, exactly the Section 11 target pattern — not the
anti-pattern), `src/core/machine_state.gd` (45 lines, zero conditional logic, pure data bag),
`src/data/mining_rules.gd`, `src/data/bit_rules.gd` (a genuine, already-working example of the
composable-primitive pattern the brief wants for machine behaviors and never applied there), `scenes/hover_info.gd`,
`scenes/hints.gd` (clean `RefCounted`, delta-driven, zero engine API), `tools/run_harness.sh`,
`tools/check_base.gd` (the Section 8.1 headless driver, already built and arguably exceeding the brief's own
spec — PASS/FAIL/SKIP/**VOID** four-state protocol vs. the brief's three, a machine-wide lock with stale-holder
recovery, and a save-sentinel that hashes the player's real save file before/after every sweep — none of which
has a brief-8.1 analog).

**Art/shaders (per the director's Q23 instruction — literal file list, not folded into a generic row):**
`erase.gdshader` (KEEP, trivial and universal), `heat_haze.gdshader` (PORT — algorithm portable, `SCREEN_UV`
binding Godot-specific), `post_fx.gdshader` (PORT — same shape, plus a mip-based defocus binding),
`rock_grit.gdshader` (KEEP — reads only its own texture, no external dependency), `rock_tooth.gdshader` (PORT —
algorithm portable, depends on a GDScript-rebuilt runtime texture uniform).

**Terrain-gen tuning, as a parameter inventory (per Q23), not a file list:** 118 hardcoded tuning constants
across `layered_world_gen.gd` (99) and `heightmap_world_gen.gd` (19) — cave/ore/scarp thresholds, band rows,
richness strength — control every generation decision. None are externalized to a Resource today; they travel
with the algorithm as GDScript literals and should be extracted as data during a port, not before.

---

## 4. Effort estimate

**E_port ≈ 584 hours** (agent-measured rows sum to 293; orchestrator estimates for the ~12 rows agents left at
0/0 add ≈291 more — see the `[est]` markers in §1's table). **E_greenfield ≈ 2,150 hours** (agent-measured rows
sum to 955; orchestrator estimates add ≈1,195 more, dominated by `harness/scenario`'s 500-hour estimate for
re-expressing ~108 known scenarios in a declarative format).

**This total has a real data-quality gap, stated plainly rather than smoothed over:** roughly half of the 25
measured rows — including the single largest one, `harness/scenario` at 32,106 LOC — left the agent-reported
hour fields at 0, which reads as unpopulated rather than a genuine zero-cost estimate. The `[est]` figures in
§1 are this session's own engineering judgment, informed by the same measured LOC/coupling/verdict data the
agents produced, not a second independent measurement. Treat E_port and E_greenfield as **directionally right,
not precise** — the conclusion that follows from them (§6, condition 5) is robust to this imprecision because
the agent-measured figures *alone*, before any orchestrator estimate is added, already clear the rule's 0.8×
threshold by a wide margin (293 vs. 0.8×955≈764).

**E_risk:** not independently measured (no historical porting data exists in this repository to derive it
from). Applied as a reasoned multiplier — port risk +15% (known code, mechanical transformation), greenfield
risk +35% (new design decisions, integration unknowns, and this project's own extensively-documented history of
rework when a first diagnosis turns out wrong) — giving E_port+E_risk≈672 and E_greenfield+E_risk≈2,903.

---

## 5. Build-vs-rebuild recommendation

Per Section 18.4's instruction: **the rule's mechanical output is reported first, unqualified, then argued
separately.**

## 6. The decision rule, applied mechanically

| # | Condition | Threshold | Measured | Result |
|---|---|---|---|---|
| 1 | Sim engine coupling, weighted mean | ≥3.5 | 1.14 (simple mean) / 1.35 (LOC-weighted), across the 14 canonical `sim/*` subsystems | **FALSE** |
| 2 | Fraction of subsystems scoring ≥3 | <40% | 72% (18/25) | **FALSE** |
| 3 | Cycle spanning ≥3 modules, OR ≥15 layer violations | either | 0 cycles (exact); 32 layer-violation instances via the one real analog found (`world_seeder.gd`→`MainView`, §2) | **TRUE**, via the layer-violation clause only, on a single-file analog |
| 4 | Item/machine representation >5× over Section 11 tick budget | >5× | No Node-per-item/machine anti-pattern found — packed `Dictionary`/`Array` state, one `Node2D` draws everything; real frametime evidence shows ~2× headroom to the frame budget at current (sub-late-game) scale | **FALSE** |
| 5 | E_port+E_risk_port > 0.8×(E_greenfield+E_risk_greenfield) | | 672 > 0.8×2,903≈2,322? No — 672 is ~23% of that figure | **FALSE** |
| 6 | Movement on `CharacterBody2D`/`move_and_slide`, AND unextractable without touching >30% of gameplay code | both | Not `CharacterBody2D`, zero `move_and_slide`/`move_and_collide` calls anywhere in `scenes/` or `src/` | **FALSE** (first clause alone fails) |

**One condition trips true. The rule requires two. Mechanical output: INCREMENTAL.**

**The argument, separately, and bluntly:** condition 3 is the entire case for REBUILD in this data, and it is
thin. It rests on one 152-line seeding script referencing 15 layout constants on a `Node2D` class — not a
cycle, not a pervasive pattern (every other row and both other coupling passes measured zero), and not
something that resists a mechanical fix: the fix is "move 15 constants somewhere both files can read," which is
exactly the kind of change condition 3 exists to distinguish *from*. If a stricter reading of condition 3
counts the file rather than the reference (1, not 32) — a legitimate alternate framing of the same measurement,
and arguably the more natural one for "how many modules violate the boundary" — condition 3 is false too, and
**zero of six conditions trip.** Either way, nothing else in this audit points toward REBUILD: the dependency
graph is genuinely acyclic, engine coupling in the sim-analog code is low almost everywhere it was measured,
the majority of subsystems already score compatible, the effort math favors porting by a wide margin even
before adjusting for the estimate gap, and the two most expensive things to get wrong architecturally —
movement physics and item/machine representation — were both already built the way the target architecture
wants them built, not the way it's worried they'll have been built.

**What actually needs real work, named plainly, is not "is the codebase compatible" — it mostly is — but four
specific things that don't exist and have to be designed, not extracted:** `sim/run` (no bounded-session/duration
concept exists at all), `sim/commands` (no typed command vocabulary — two incompatible calling conventions
today), `sim/meta` (no run/meta save separation — one undifferentiated envelope), and `harness/scenario`'s
declarative format (108 files of mature imperative tests with no schema to re-express them in). None of these
four are made harder or easier by a REBUILD-vs-PORT choice for the rest of the codebase — they're greenfield
either way, and they're where the real 2,150-hour greenfield estimate actually lives.

**Salvage list (per Section 18.4's requirement that a rebuild recommendation not discard tuning work — restated
here even though the recommendation is INCREMENTAL, since a strangler-fig migration will still discard anything
not explicitly named):** 118 terrain-gen tuning constants (§3), 5 shader algorithms (2 KEEP outright, 3 PORT),
the entire `src/data/` Resource content (22 machine `.tres`, 16 material `.tres`, 6 recipe `.tres` — all
independently confirmed data-driven, zero code divergence within each), `docs/DECISIONS.md`'s ADR log itself
(a working example of the kind of decision record the brief's own C-series discipline asks for), and the
harness's own hard-won protocol layer (`lock_lib.sh`'s machine-lock, `run_harness.sh`'s PASS/FAIL/SKIP/VOID
contract, the save-sentinel) — all four subsystems scoring 5/5 compatible in §1.

### Strangler-fig plan (the actionable half of an INCREMENTAL recommendation)

1. **Extract `sim/run` and `sim/commands` first, as pure greenfield, behind a thin adapter `scenes/main.gd`
   calls into.** Nothing else is blocked on these existing; they're additive. This also gives Freight Winch
   (§7) a real home to land in rather than another set of `try_*` methods bolted onto `main.gd`.
2. **Fix the one real layer violation** (`world_seeder.gd`'s 15 `MainView` constants) as a standalone, low-risk
   PR — it's the only concrete blocker condition 3 names, and clearing it removes the sole condition currently
   tripping the rebuild rule.
3. **Decompose `sim/behaviors`** (§1, compatibility 2) — 2 of 13 machine behaviors are clean primitive matches;
   the other 11 need real redesign against whatever primitive set the target architecture settles on. This is
   the largest genuine REWRITE inside the "sim" half of the codebase and should be scheduled before new machine
   content, not after.
4. **Design the declarative scenario schema, then re-express the highest-value 10–15 of the 108 `check_*.gd`
   layers against it** as a pilot, before committing to re-expressing all 108. `harness/agent_api`
   (`play_agent.gd`/`play_tests.gd`) is a much cheaper, higher-confidence PORT and should move first, both
   because it's ready and because a working T0/T2-style agent surface makes validating steps 1–3 faster.
5. **CI gate at every step:** the layer-lint this repo doesn't have yet (Section 4's "no module may import a
   sibling's internal files," enforced) should be written and turned on *before* step 1, not after, so
   `sim/run`/`sim/commands` are born inside the boundary instead of needing a second cleanup pass.

---

## 7. Risk register

| # | Risk | Evidence | Mitigation, mapped to this document |
|---|---|---|---|
| 1 | **Freight Winch (or any post-A+ feature work) ships into the codebase while this audit is unresolved, becoming exactly the "polish work that may be discarded" the director wanted to avoid.** `docs/A_PLUS_PROGRAM.md` already shows all six areas CLOSED — there is no live A+ work to pause, but `main.gd` already contains a working stub of the Freight Winch link verb (`try_link_winch`, `main.gd:1495-1513`), meaning feature work may already be starting. | §0, §6 strangler-fig step 1 | Land `sim/commands`/`sim/run` first (step 1) so Freight Winch has a real home; don't let it accumulate as more `main.gd` verbs. |
| 2 | **`tools/` grew 90% in 5 days** (33,773→64,319 GDScript lines since the 2026-08-20 portfolio audit) with no sign of slowing, and 65% of the tracked harness is one-bespoke-script-per-test-case (`harness/scenario`, compat score 2). If this rate continues, the instrumentation-to-game ratio (already 2.6:1) grows faster than the game itself, and a future audit inherits an even larger REWRITE bill for the harness alone. | Appendix A, §1 (`harness/scenario` row) | Prioritize the declarative-scenario pilot (strangler-fig step 4) before the `check_*.gd` population grows further; it only gets more expensive to re-express later. |
| 3 | **`sim/behaviors`' decomposition is underestimated by everyone, including this audit, until someone actually designs the primitive set.** Only 2 of 13 behaviors map cleanly to the brief's ~8 primitives; three behaviors (Freight Winch, splitter, generator) have no home in the named list at all, and `_run_crush`/`_run_drift` each bypass the generic dispatch/flow path with their own full override — real evidence that "8 primitives" may itself need revising against what this game's mechanics actually require. | §1 (`sim/behaviors` row, compat 2, the audit's most detailed single finding) | Schedule this as its own design pass (strangler-fig step 3) with an explicit "is 8 still the right number" check, not a mechanical port task. |
| 4 | **The two largest game-logic files in the repo (`scenes/main.gd`, 3,003 lines; and by proxy the `sim/run`/`view/camera` logic embedded in it) were never read in full by this audit** — only spot-cited for verb/camera evidence. Any effort estimate touching `shell`, `view/camera`, or `sim/commands` inherits that gap. | §2, §8 | Read `main.gd` in full before scheduling strangler-fig step 1 — it's the file every extraction in this plan calls into or out of. |
| 5 | **Condition 3's fragility cuts both ways.** This audit argues it shouldn't trigger REBUILD because it's one file — but that also means the entire mechanical-rule case for INCREMENTAL rests on a threshold this document itself calls contestable (32 vs. 1, depending on unit of count). If a future, stricter layer-lint (strangler-fig step 5) surfaces real violations elsewhere once `sim/view/shell` directories actually exist, the rule's condition 3 could flip on evidence this audit couldn't see because the boundary it's testing doesn't exist yet. | §2, §6 | Build the layer-lint *first* (step 5, reordered ahead of step 1 if this risk is taken seriously) so condition 3 gets re-evaluated against real enforcement, not a one-file analog, before large extraction work is sunk. |

---

## 8. Where this document is likely wrong

Per Section 18's own instruction, stated as findings rather than hedges:

- **`scenes/main.gd` (3,003 lines) was never read in full.** Every citation from it in this document (camera
  logic, `try_link_winch`, Bazaar-gate glue) came from targeted greps and spot-reads. It's the file every
  strangler-fig step in §6 calls into or out of, and it's the second-largest file this audit didn't fully read
  (after `world_renderer.gd`, which *was* read in full). The `view/camera` LOC figure (56) is an explicit
  lower-bound proxy, not a real subsystem extraction.
- **The 22-vs-25 machine `.tres` file discrepancy.** This document's own ground-truth-verification agent
  (`gt-data-ratio`) measured 22 files under `src/data/machines/`, contradicting the "25 files" figure this
  audit's own orchestration script asserted as known ground truth at launch. The 22 figure, independently
  re-measured with `find`, is trusted here; the 25 figure was not reproducible and should be treated as stale.
  This is exactly the kind of unverified assumption Section 18's own methodology exists to catch, and it caught
  it inside its own setup, not just in the target codebase.
- **`docs/REPO_PORTFOLIO_AUDIT.md`'s `tools/` baseline (112 files / 33,773 LOC) does not reconcile with this
  audit's measurement under any subset boundary tried** (tracked-only: 148 files/46,505 LOC; full working tree:
  221 files/69,967 LOC). Five days of continuous commits plausibly explain growth, but the specific 112/33,773
  figure was not independently re-derivable from the current tree, and this document does not claim to have
  explained the gap — only to have flagged it rather than silently adopting or silently ignoring it.
- **Condition 5's E_port/E_greenfield totals rest half on real per-subsystem agent estimates and half on this
  orchestrating session's own judgment** (§4) — a real methodological seam, disclosed rather than smoothed into
  one number. The conclusion is robust to it (agent-only figures already clear the threshold), but a reader who
  doesn't trust the `[est]` rows should re-derive condition 5 from the agent-only subtotal (293 vs. 764) rather
  than the blended one.
- **The brief itself assumes a `sim`/`view`/`shell` directory split that doesn't exist in this codebase yet.**
  Every subsystem agent independently hit this and reported it as N/A-with-analog rather than guessing — that
  consistency across 19 independently-run agents is itself weak evidence the brief's assumption, not the
  codebase, is the thing slightly out of step here: SINKFORGE already separates sim-purity (`src/` vs.
  `scenes/`) along almost exactly the boundary the brief wants, just without the brief's directory names, and a
  chunk of this audit's effort went into re-deriving that mapping rather than reading it off a folder structure.
  That's a real, if modest, brief defect worth naming per Section 0's instruction to say so with evidence.
- **This audit found no repository text matching "Section 18.1"/"module catalog"/"R1"–"R4" anywhere in
  `docs/*.md`**, confirmed independently by multiple agents. The brief was audited from the copy supplied at
  the start of this task, not from anything already checked into this repository — expected, since the brief
  states it was written without repository access, but worth stating plainly rather than assuming a reader
  knows that.

---

## Appendix A: instrumentation-to-game ratio and the `tools/` composition

`src/`+`scenes/` (`.gd` only) = **28,522 lines / 55 files**. `tools/`+`tests/` (`.gd`+`.sh`) = **74,033 lines /
220 files**. Ratio: **2.60** — for every line that makes the game run, ~2.6 lines exist to observe or verify it.
Versus the 2026-08-20 baseline: `src/` +9.0%, `scenes/` +13.0%, `tests/` +5.0%, **`tools/` +90.5%** (232 commits
touched `tools/` in the intervening 5 days). Caveat that matters for reading the ratio honestly: 36% of
`tools/`'s raw GDScript (23,067 of 64,319 lines) sits in gitignored `_scratch_*.gd` one-off files, never
committed — the maintained, registered instrument (108 `check_*.gd` layers) alone is 32,407 lines, which would
put a "maintained-instrument-only" ratio closer to **1.5×** rather than 2.6×. Both numbers are real
measurements of different questions ("what's on disk" vs. "what's actually shipped and maintained"); this
document reports both rather than picking the more dramatic one.

Within tracked `tools/` (148 files / 46,505 LOC, the fair comparison since scratch is entirely untracked):
capture/screenshot machinery is **7 files / 3,454 LOC (7.4%)**; the deterministic scenario/check harness is
**101 files / 30,303 LOC (65.2%)** — outweighing capture tooling roughly 9-to-1 by LOC. The instrument this
repository has built is overwhelmingly a test harness, not a screenshot factory, whatever the raw file count
of `_moment_*.png`-adjacent tooling suggests at a glance.

## Appendix B: peer sessions and A+/Freight Winch status

10 peer sessions exist on this machine, 7 named `sinkforge-*`, all idle at audit time (`ListAgents`). None were
messaged about this audit or asked to hold work — that's a live open question for the director, not something
this audit decided unilaterally. `docs/A_PLUS_PROGRAM.md` (last corrected 2026-08-23) shows all six of its areas
CLOSED; "pause A+" has nothing live to act on. The real exposure is Freight Winch (§7, risk 1).

## Appendix C: live perf/determinism evidence (not extrapolated — directly run)

`tools/check_frametime.gd`, unarmed, on a quiet box: IDLE mean 8.39ms (p95 10.60), RUN mean 8.31ms (p95 9.53,
cap 2.0×, PASS), DIG mean 8.54ms (p95 10.98, cap 6.0×, PASS), SWING mean 8.32ms (p95 10.44, cap 2.0×, PASS) —
**~2× headroom** against the brief's 16.6ms/frame budget at current (not late-game) scale. **407 draw calls**
against the brief's ≤150 budget — already 2.7× over, at ordinary load, before any late-game stress test exists
to run. `tests/test_stress.gd`, headless: **ALL PASS** — item conservation held and a 364-op seeded interleaved
sequence (including a mid-sequence save/load round-trip) was byte-identical on re-run from the same seed. Real
determinism evidence, at hundreds-of-ops scale — not yet the brief's 20,000-tick/2,000-machine scale, which no
existing harness layer exercises (a genuine, named gap, not filled here per the audit's no-new-implementation
scope).
