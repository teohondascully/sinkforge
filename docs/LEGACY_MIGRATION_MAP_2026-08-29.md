# Legacy revival — Phase 1 file-level map

> **Amended 2026-09-03 (D0341/D0342):** the `KEEP-CURRENT` verdict on `legacy/src/core/factory_sim.gd`
> is REVERSED. It conflated the body and terrain (where the current build wins) with machines, items,
> water, power and transport (where the current build has zero lines). The complete read of 2026-09-02
> found the hub already fixed-tick and integer-shaped; `docs/A_PRIME_REFACTOR_PLAN.md` lifts it whole.
> Every other verdict in this file stands as the pinned-hash record it was.

**Committed 2026-08-29 as the pinned-hash record, per the director's Q5 ruling.** Nothing was ported,
copied, or migrated to produce it; the working tree was returned to its opening state.

| | |
|---|---|
| Legacy | `666e5518dd6f881cd6d81799543d60e0a79773ae` (tag `pre-pivot`) |
| Current | `0be151fa72e93f7877bff3975cd762ba777072a1` (`main`) |
| Godot | 4.6.2.stable.official.71f334935 |
| Files moved | 0 |

## Provenance, and what this file is not

This is the report as the director received it, committed verbatim in substance so the slice work has a
fixed reference. Three things a future reader needs to know before trusting it:

1. **It was produced by a separate analysis pass, not by the session that committed it.** The committing
   session re-verified the pinned hashes, the band-row arithmetic, and the existence and line counts of
   every file named in §2's Slice 0 scope (`docs/DECISIONS_LEDGER.md` D0187). It did **not** independently
   re-derive the 432 verdicts. Verdicts on files outside Slice 0's scope carry the original pass's
   authority, not this repository's.
2. **The current-side manifest (167 rows) is not reproduced here.** The report rendered its manifest as
   two filterable tabs; only the legacy-side 265 rows were captured in the text handed over. The
   current-side rows exist in the original artifact and are absent from this file. Stating the total as
   "432 verdicts" is therefore accurate about the original pass and **not** a description of this
   document, which carries 265. Do not cite this file as the record of the current-side verdicts.
3. **`git rev-parse pre-pivot` does not return `666e551`.** `pre-pivot` is an *annotated* tag, so that
   command returns the tag object (`eb54352`). Use `git rev-parse pre-pivot^{commit}`. The map's hash is
   correct; the naive command is what misleads. Recorded because the committing session tripped on it.

The map's own stated weaknesses are reproduced faithfully in §12 and are not softened. Five of them are
being closed by direct full reads as the slices proceed; see D0187 for which.

---

## Method

Built manifest-first: enumerate every tracked file, classify the non-code populations as groups with a
stated reason, assign a verdict to every remaining source file, and only then draw conclusions.
Dependency claims come from a parsed graph of `preload`, `extends`, `ExtResource` and bare `class_name`
references across both trees, not from reading and remembering.

**Self-check — all five pass**

```
1. MANIFEST COVERAGE
   legacy  :  622 tracked /  622 accounted   MATCH
   current : 3509 tracked / 3509 accounted   MATCH

2. EVERY SOURCE FILE HAS A VERDICT
   legacy  : 265 source files, 265 verdicts, 0 unaccounted
   current : 167 source files, 167 verdicts, 0 unaccounted

3. NO SUBSTANTIVE VERDICT RESTS ON TRACE ALONE
   legacy files with a LIFT/MERGE/DEAD/REBUILD/KEEP verdict
   that were never opened: 0

4. LOC RECONCILES
   legacy  verdict LOC sum = 81198  (manifest total 81198)  MATCH
   current verdict LOC sum = 17824  (manifest total 17824)  MATCH

5. READ DEPTH
   legacy  : 46 FULL, 17 SKIM, 43 SCAN, 159 TRACE-ONLY
   current :  9 FULL,  9 SKIM,           149 TRACE-ONLY
```

The 159 trace-only legacy files are 151 `tools/` harness layers, 5 `tests/` suites — all carrying the same
SKIP verdict against the current substrate — plus 3 repo-metadata files. None carries a LIFT, MERGE, DEAD,
REBUILD or KEEP verdict. The 149 current-side trace-only files are 53 `docs/archive` scrubbing artifacts
and 96 `tools`/`tests`/`data` files covered by directory rule.

**Read depth, defined.** FULL — whole file read. SKIM — header, doc-comments, targeted sections. SCAN —
declaration header plus an automated scan for dead-economy identifiers. TRACE — verdict from measured
properties only: line count, `extends` target, banned-engine-class scan, and the complete inbound and
outbound edge sets.

**Where this map is weakest, stated up front.** Two files were never read in full, and every estimate
touching view or shell inherits that: `scenes/main.gd` (3,003 lines, 52 outbound dependencies — the
largest fan-out in either codebase) and `scenes/world_renderer.gd` (3,656 lines). Their headers,
delegation surfaces, and the mining charge loop were read in full; the remainder was scanned. The
2026-08-25 compatibility audit flagged the same gap on `main.gd` and never closed it. This pass did not
close it either.

---

## Finding 01 — Where legacy lives, and whether it runs

It is already inside this repository: `legacy/`, 359 tracked files under a `.gdignore`, excluded from
every gate. It is byte-complete against the `pre-pivot` tag — comparing the tag's `src scenes tools tests
assets` trees against `legacy/` gives an empty diff in both directions across 356 files. Three files exist
only in `legacy/`: `.gdignore`, `README.md`, `tools/prose_words.txt`.

It cannot run in place for exactly one reason: `project.godot` was never copied in. The tag has it.

**Verified — legacy runs, first try, zero code changes:**

```sh
git worktree add /tmp/legacy-run pre-pivot
godot --headless --import --path /tmp/legacy-run
SF_MOMENT_DIR=/tmp/shots godot --path /tmp/legacy-run \
  --script res://tools/capture_moments.gd -- delve

CAPTURED delve -> _moment_delve.png (1920x1080) | settled=60 body=(49, 34)
```

12 of 12 canonical moments rendered at 1920x1080. The `delve` moment starts the body at row 19 and reaches
row 34 by digging, through legacy's real `PlayAgent` driving the real verbs. **Legacy mines downward,
today, end to end, headless.**

One decoy worth naming: `~/Projects/sinkforge-freeze-20260820` is a separate 1.1 GB checkout with a warm
`.godot` cache, which makes it tempting. Its HEAD (`8fa89b9`) is not an ancestor of `pre-pivot` — it
pre-dates the 2026-08-19 history rewrite, so its commits were rewritten out from under it. Use the tag.

---

## Finding 02 — What each side actually is

| | |
|---|---|
| Current game code | 1,937 lines, 20 `.gd` files |
| Legacy game code | 28,522 lines, 55 `.gd` files |
| Ratio | 14.7x legacy : current |
| Current instrument | 9,723 lines (tools + tests) |
| Instrument : game | 5.85 — gate 7's own number |

The current build's entire game is 4 files in `core/`, 5 in `sim/body/`, 3 in `sim/terrain_gen/`, 2 in
`sim/world/`, 1 in `sim/invariants/`, and 2 generated data records.

**Four of the five architecture layers contain no code at all:**

```
interface/     1 files     1 .md     0 code   <- "THE ONLY DOOR" (L2)
harness/       6 files     6 .md     0 code   <- L3
experiment/    5 files     5 .md     0 code   <- L4
view/          1 files     1 .md     0 code
shell/         1 files     1 .md     0 code
scenarios/     1 files     1 .md     0 code
claims/        4 files     4 .md     0 code
```

The substrate that genuinely exists lives in `tools/` and `tests/`: 30 declared gates of which 19 have
enforcing code and 11 are NO-CODE, a two-process bit-identical replay determinism check, a goalless input
fuzzer, a hostile-geometry acceptance suite, and a gate-status tool that refuses to report a gate as
passing when CI never ran it. That part is real and is the portfolio piece. The L2-L4 stack above it is a
directory skeleton.

**The repository is already asking for this migration.** Gate 7 is red; CI's most recent conclusion is
failure. Its own output: *"instrument grew 157 lines against game's 28 over the last 10 commits, more than
2x. Per docs/CLAIMS.md, the next unit of work is game, not another check."* Gate 7 counts
`core + sim + interface + view + shell` as "game". Every line lifted into `view/` and `shell/` lands on the
failing side of that ratio. This migration is not in tension with the substrate's standards — it is the
remedy the substrate is currently demanding.

**The two grids line up better than expected:**

| Property | Legacy | Current | Relationship |
|---|---|---|---|
| Logic cell | 32 px | 16 px | exactly 2x |
| SUBDIV | 4 | 4 | identical |
| Fine / terrain cell | 8 px | 4 px | exactly 2x |
| Body collider | 14 x 34 px | 16 x 40 px | aspect 0.41 vs 0.40 |
| Body in logic cells | 0.44 x 1.06 | 1.00 x 2.50 | 2.3x divergence |
| Run speed / gravity | 150 / 900 | 150 / 900 | identical |
| Jump vel / max fall | -365 / 560 | -365 / 560 | identical |

Same dual-grid architecture at exactly half the pixel scale — a constant, not a redesign. The movement
feel constants are already identical, because `sim/body/body.gd` says in its own header that they were
ported from `legacy/scenes/player.gd`.

The one real divergence is the body-to-cell proportion, and it is a design decision rather than a defect.
Legacy's miner is under half a cell wide — its own comment: *"At the zoomed-out camera the avatar reads as
a small nimble figure in a big granular world... Under a cell wide, so a one-wide shaft fits."* The current
body is exactly one logic tile wide, with zero clearance in a one-tile shaft. **This is Q1.**

---

## Finding 03 — The gap, in pixels

Both columns were rendered from the two pinned commits. The current build's flatness is deliberate —
`play_scene.gd`'s header records the instruction: *"a renderer that looks unfinished cannot be mistaken for
a verdict on feel, only the controller can be."* It is not failed art; it is absent art.

| Shot | What it shows |
|---|---|
| Current · hostile chamber | Solid-colour rects. No shader, light or sprite. |
| Legacy · boot | Depth readout, objective card, hotbar, key hints, 3 parallax ranges. |
| Current · `reveal_test_dense` | The Reveal want-layer under test. Flat brown field, cyan pockets. |
| Legacy · delve | Shaft cut by the real agent. Head-lamp pool, shadow veil, band card. |
| Legacy · room | The back wall reads as a recessed plane, not a hole in a sheet. |
| Legacy · counter | Elevation, defocus, tabbed rail, detail pane. **Design-dead per GDD §9.** |

---

## Finding 04 — The couplings, traced

These are the claims the migration's safety rests on, so none is a description — each is a parsed edge set.

**Legacy's view layer has almost no engine coupling.** Across 28,522 lines: `get_node(` 0 occurrences;
`$NodeName` 0; `%UniqueName` 0; `get_tree(` 1 (a scene reload); `.tscn` files 1, six lines, a stub.

The only scene file in the entire legacy project is one `Node2D` with a script attached. Every node in
legacy's view is constructed in code. No editor-authored tree to reproduce, no node paths to rewire.
Twenty-four of the 33 files in `scenes/` are plain `RefCounted`.

**Correction to prior art.** `docs/archive/COMPAT_AUDIT_2026-08-25.md`, run against this same commit,
reported *"scenes/ uses Godot 4's %UniqueName idiom 71 times"* and told readers to treat its own measured
scene-coupling score of 1 as an undercount. The idiom it hypothesised is not there; a direct count finds
zero. The audit's original measurement was right and its own walk-back was wrong — which matters, because
that walk-back is the stated reason it scored `view/render_world` down to 3/5 and hedged the view layer
generally.

**The painters are a star around one coordinator:**

```
scenes/sky_painter.gd
  DEPENDS ON (2):
      -> scenes/world_renderer.gd   [class-ref]   <- the only path to anything dead
      -> src/data/seams.gd          [class-ref]   <- pure data, itself LIFT
  IMPORTED BY (1):
      <- scenes/world_renderer.gd

src/core/factory_sim.gd
  IMPORTED BY (103 of 237 files)          <- the hub
```

Every painter's only route to the dead-economy set runs through `world_renderer.gd`, the coordinator they
hold a back-reference to. Replacing the coordinator severs all of them at once. That is what makes "rebuild
the coordinator, lift the painters underneath it" a safe plan rather than a hopeful one.

One caveat found by reading rather than tracing: `sky_painter` reads eight private fields off the
coordinator (`r._guide_targets`, `r._aim`, `r._anim_time`, ...). The rebuilt coordinator must supply an
equivalent state object. That is a defined interface, but it is more work than "sever a back-reference."

**CLOSED 2026-08-30 (D0234/D0240/D0244), and it was smaller than this paragraph feared.** Measured off the
legacy source rather than estimated: across all five painters the reach-in collapses to FOUR KINDS, and
five of `sky_painter`'s own eight fields are a single array of screen-space marks. The state object is
`view/frame.gd` — `obs`, `anim_time`, `view_world_rect`, `zoom`, `look`, `marks` — and painters are static,
stateless, and draw to their own `CanvasItem`, never through the coordinator. `docs/COORDINATOR_CONTRACT.md`
carries the measured table.

**The poison is a leaf:**

```
src/data/research_rules.gd
  DEPENDS ON (0)
  IMPORTED BY (16):
      3x scenes/bazaar_*.gd      (already DEAD)
      1x src/core/factory_sim.gd (KEEP-CURRENT, not lifted)
      3x tests/  +  8x tools/    (SKIP, superseded)
```

Not one of its sixteen importers is on the lift side. Excising the terminal economy is provably safe, not
hopefully safe.

A caution on reading reachability here: 142 of 237 files have a transitive path to the poison set — but
almost all of it runs through `FactorySim`, which is not being lifted. Cut the sim hub and the leaks that
actually matter are 12 files in `scenes/`, every one already MERGE or REBUILD for other reasons.

---

## Finding 05 — Where exactly the poison is

```gdscript
# legacy/src/data/research_rules.gd
## The next researchable tech: first un-researched entry in ORDER with its
## prereq met, or &"" when the tree is exhausted.
static func next_tech(research: Dictionary) -> StringName:
    for tid: StringName in ORDER:
        if not research.has(tid) and prereq_met(tid, research):
            return tid
    return &""
```

Eleven techs in `ORDER`, each a one-time cost. Alongside them, 22 machine `craft_cost` blocks, 3 tool
recipes and 4 bit recipes — also one-time. Total lifetime demand is a fixed, finite integral. Pay it and
nothing consumes the player's output ever again.

Legacy is not entirely without recurring sinks, which sharpens the diagnosis. Generators and drills burn
coal continuously (`GENERATOR_FUEL_TICKS = 100`, `DRILL_FUEL_TICKS = 60`); `factory_sim.gd`'s own comment
reads *"the drill burns COAL to run, so automating ore creates demand for coal."* But that sink is
self-satisfying — the horizontal drill's bored coal *"feeds its OWN fuel bunker first, so it is
self-sustaining"* — while the refined chain (ore → ingot → plate/gear) had no consumer beyond the one-time
purchases.

The precise statement is therefore not "legacy had no sinks." It is: **legacy's refined output was
terminal.** Which is exactly what `docs/GDD.md` §3 names, and exactly what rig-as-consumer fixes.

**The GDD has already ruled on most of this.** §9's dead list names mechanisms directly: *"Terminal
products with no standing demand, a one-time descent gate as the only material sink, a research-tree menu
gating one-tier-deep tech, the Bazaar (as shop and as physical structure), currency, electricity as an
early automation tier... horizontal boring."*

So the best-looking screen in legacy is already dead by name. But §9 also says *"One thing should be
repurposed rather than deleted... a throttled per-trip capacity plus a fixed transit duration linking two
arbitrary cells"* — which is verbatim the Freight Winch. Both winch records were marked DEAD on the first
pass; the GDD says repurpose.

---

## Finding 06 — Two defects found on the way

**Defect A — "cannot mine down" is unbuilt, not broken.**

```gdscript
func _dig_target_cell() -> Vector2i:
    var cx: int = _px_to_cell(_right_x() - 1) + 1 if facing > 0 else _px_to_cell(_left_x()) - 1
    var cy: int = _px_to_cell(pos_y)
    return Vector2i(cx, cy)
```

No downward branch, and the module documents it as deliberate (D0110): *"Horizontal-only on purpose... a
single well-defined direction avoids the aim-direction design question a vertical/diagonal dig would raise
(which key means 'down', does it compete with mantle_hold's up-key) without a stated answer yet."*

Legacy answers that exact question: there is no dig key. Mining is cursor-aimed against a reach radius
(`REACH_CELLS = 3.2`), hold-to-charge, with the charge banked per cell so a mis-aim costs travel time and
never progress.

**Defect B — `dig_pressed` violates its own contract in the human path.**

`InputFrame.dig_pressed` is documented edge-triggered: *"true only on the tick the button transitioned to
held... not a hold-to-clear-a-wall auto-repeat (D0110)."* Two adjacent lines in
`tests/body/reveal_scene.gd` handle jump correctly and dig incorrectly:

```gdscript
125    input.jump_pressed = jump_held and not _was_jump_held   # <- edge, correct
126    _was_jump_held = jump_held
127    input.dig_pressed = Input.is_physical_key_pressed(KEY_E)  # <- raw held state
```

No `_was_dig_held` exists anywhere in the repository. Measured against the director's own committed
807-tick session: dig was true for exactly one run of 30 consecutive ticks — one physical hold, recorded as
30 events where the contract specifies 1, and it is the only dig input in the session. Worth fixing before
more `--play` sessions are recorded against `claims/C004`. **Not** established as the cause of the
`body left the world` bounds violation — that was not investigated, and it stands as `docs/WORKING.md`
describes it.

*(Fixed 2026-08-29, `docs/DECISIONS_LEDGER.md` D0188, with a regression test over a synthetic hold.)*

---

## Finding 07 — Six verdicts that reading changed

These are the reason the file-level pass was worth doing. Each was assigned from the dependency graph and
measured properties, and each was wrong.

| File | First pass | After reading | Why |
|---|---|---|---|
| `scenes/score.gd` (162) | Dead | **Lift** | Not a points system. It is the musical **score**: three synthesized beds mixed by the body's depth. Killed on its filename — the exact trap the compat audit warned about (*"grepping for run or score surfaces the wrong files entirely"*). |
| `scenes/payouts.gd` (77) | Dead | **Lift** | Not an economy payout. It is the floating "+3 ore" tick rising off a broken block, with merging. GDD §7 forbids abstract points, not showing the material you just got. |
| `scenes/hints.gd` (317) | Lift | **Merge** | Mechanism is excellent and lifts whole. Its lesson tables teach `descent_engine`, BORER, spur, drift_rig, conduit, generator and "take it to the BENCH" — all dead. Invisible in the graph; it is data, not an edge. |
| `scenes/hover_info.gd` (188) | Lift | **Merge** | Same shape: right architecture, dead content. Branches on descent, h_drill, sealrock, DESCENT_QUOTA. |
| `scenes/machine_view.gd` (726) | Lift | **Merge** | Nine dead-content references: Borer facing-mirror, descent behavior, DESCENT_EATS, `_destinations_h_drill`. |
| `scenes/page_surface.gd` (81) | Merge | **Lift** | The other direction. Genuinely generic; both dependencies are themselves LIFT, and its one Bazaar-flavoured member had already been renamed `_modal_vignette`. Nothing to cut. |

**And one coupling no graph could have shown.** `src/core/flora.gd` — sapling growth — calls
`sim.invalidate_bazaars()`, because a grown trunk can complete or destroy a wood-frame Bazaar. Its own
comment: *"A TREE IS MADE OF WOOD, AND SO IS A BAZAAR."* A real Bazaar coupling inside a file about plants,
found only by reading it.

Similarly, `src/core/save_game.gd` serialises `sim.research` into the save envelope at three sites. Porting
the save format would carry the dead tech ladder across as a schema field.

---

## The manifest — legacy, 265 files

Verdict totals: **LIFT 63 · MERGE 19 · REBUILD 5 · KEEP-CURRENT 6 · DEAD 11 · SKIP 151 · SKIP-READ 7 ·
SKIP-DONE 3.**

> The current-side 167 rows are **not** in this file — see "Provenance" above.

| File | LOC | Verdict | Destination | Read | Reasoning |
|---|---|---|---|---|---|
| `.editorconfig` | 17 | SKIP | - | TRACE | Repo metadata, not game or instrument code. |
| `.githooks/commit-msg` | 27 | SKIP-DONE | - | TRACE | Already ported forward: the current repo runs its own `.githooks/commit-msg` (ledger enforcement). |
| `.githooks/pre-commit` | 105 | SKIP-DONE | - | TRACE | Already ported forward. |
| `.github/actions/harness-verdict/action.yml` | 29 | SKIP | - | TRACE | Legacy CI for the legacy harness. Current `harness.yml` supersedes. |
| `.github/workflows/harness.yml` | 290 | SKIP | - | TRACE | Legacy CI for the legacy harness. Current `harness.yml` supersedes. |
| `.gitignore` | 147 | SKIP | - | TRACE | Repo metadata. |
| `project.godot` | 45 | SKIP | - | TRACE | Legacy project config (32px cell assumptions, legacy autoloads). Current supersedes. |
| `scenes/art.gd` | 26 | **LANDED** `view/visuals/art.gd` (D0227) | view/visuals | FULL | Colour/shape helpers. 0 deps, 0 sim. |
| `scenes/bazaar_bench.gd` | 191 | DEAD | - | SCAN | Research bench tab — the UI of the terminal ladder. |
| `scenes/bazaar_catalogue.gd` | 55 | DEAD | - | SCAN | Catalogue model behind the tabs. |
| `scenes/bazaar_costs.gd` | 67 | DEAD | - | SCAN | *"THE ONE PLACE THAT DECIDES WHETHER A PRICE CAN BE PAID"*, consolidating 4 surfaces onto one answer. The `craft_cost` implementation dies, but note the PATTERN: rig demands will have the same many-surfaces-one-affordability-answer problem. |
| `scenes/bazaar_pack.gd` | 304 | DEAD | - | SCAN | Pack tab. Dead with the shop. |
| `scenes/bazaar_page.gd` | 1454 | DEAD | - | SCAN | 1454-line shop screen. Dead by GDD §9. Its LAYOUT GRAMMAR survives via `ui_theme.gd`, lifted separately. |
| `scenes/bazaar_surface.gd` | 52 | DEAD | - | SCAN | Base class for the 3 bazaar tabs. |
| `scenes/bazaar_works.gd` | 273 | DEAD | - | SCAN | Machines+Rack tab: the one-time purchase surface itself. |
| `scenes/bazaars.gd` | 245 | DEAD | - | SCAN | The Bazaar as PHYSICAL STRUCTURE (wood-frame detection, ruin/ghost slots). GDD §9 kills it by name. |
| `scenes/controls.gd` | 235 | LIFT | shell/input | FULL | **[UPGRADED IN IMPORTANCE after reading]** Not just a keymap. (1) A DEAFNESS switch cutting hardware at the POLLING layer, because disabling `_input` does not stop `Input.is_action_pressed`. (2) A POSABLE POINTER API (`pose_pointer`/`release_pointer`/`pointer_posed`) so a harness can aim without touching the OS cursor, and a measurement can ASSERT no pose is set. That is a working answer to Q2. (3) Documents the GDScript `Vector2 != null` trap this repo also records. |
| `scenes/erase.gdshader` | 11 | LIFT | view/shaders | SKIM | Retained-target eraser. Trivial, universal. |
| `scenes/falling_items.gd` | 210 | LIFT | view/render_entities | SKIM | Item toss/settle animation. GDD §13: *"every item always visible at item scale"*. |
| `scenes/fine_terrain.gd` | 1402 | LIFT | view/render_world | SKIM | THE molded-rock bake, 11 cosmetic noise fields. Takes shape from the sim as INJECTED CALLABLES (`rebake(solid_at, fine_solid_at, ...)`) — already an interface seam. `FastNoiseLite` is legal in `view/`. |
| `scenes/grapple.gd` | 389 | MERGE | sim/body + view | SCAN | ZERO dead-content references, `RefCounted`, zero engine API. Behaves as a NINJA ROPE, not Terraria's hook: the constraint removes only the OUTWARD velocity component, conserving everything tangential through the arc — literally GDD §1's *"swing momentum worth chaining"*. Dep: `factory_sim(is_solid)` → rebind to `TileGrid`. Needs `Fx` to enter `sim/`. |
| `scenes/heat_haze.gdshader` | 24 | LIFT | view/shaders | SKIM | Screen-space warp, vertex-alpha masked. `SCREEN_UV` binding is Godot-generic. |
| `scenes/hints.gd` | 317 | MERGE | view/hud | FULL | **[DOWNGRADED from LIFT]** MECHANISM lifts whole: acquisition-edge firing, relevance gates, ceremony arbitration, busy-freeze so a lesson fired mid-swing returns intact, save-persisted latches. CONTENT tables teach dead machines. Lift the engine, re-author the 22 lessons. |
| `scenes/hover_info.gd` | 188 | MERGE | view/hud | FULL | **[DOWNGRADED from LIFT]** `describe()` returns a render-agnostic dict — exactly an Observation projection. But branches on descent/h_drill/sealrock/DESCENT_QUOTA/the bench. Contains a finding the CURRENT build needs: the body rect always covers TWO ROWS (34px body vs 32px cell) and 2-4 cells total, so a cell-addressed verb is never really one cell. |
| `scenes/hud.gd` | 2189 | MERGE | view/hud | SKIM | Reads exactly 16 sim accessors (an Observation shape). Lift depth readout/hotbar/objective card/announce/key hints; DROP the `bazaar_page` delegation. Must split. |
| `scenes/light_layer.gd` | 25 | **LANDED** `view/fx/light_layer.gd` (D0227; see P009) | view/fx | FULL | **[REASON CORRECTED]** 25 lines: a canvas + blend mode + a `Callable` painter. Its own header: *"MainView owns all the light math"*. Lifting this gets the CANVAS, not the lighting — head-lamp pool and darkness veil live in `main.gd` (REBUILD). Do not mistake this file for the lighting. |
| `scenes/machine_view.gd` | 726 | MERGE | view/render_entities | SCAN | **[DOWNGRADED from LIFT]** Casing/construction-anim/status/nameplate/load-gauge, extracted along a MEASURED seam. 9 dead-content references to trim. |
| `scenes/main.gd` | 3003 | REBUILD | shell/ | SKIM | 3003 lines, 52 deps — largest fan-out in the codebase. Owns input, verbs, lifecycle, camera, AND the mining charge loop (salvage). Never read in full by any audit including this one. |
| `scenes/main.tscn` | 6 | SKIP | - | FULL | 6-line stub: one `Node2D` + script. |
| `scenes/objectives.gd` | 211 | REBUILD | sim/economy | SKIM | A 14-step ladder of which 5 steps are Claim-the-Bazaar / Research-Automation / Research-Power / Research-Descent / Breach-the-seal. Content dead. MECHANISM worth re-deriving: measures progress as deltas against a construction-time baseline, so a pre-stocked pack cannot tick a step — the same derived-not-authored discipline `CONTEXT.md` requires of fixtures. |
| `scenes/page_surface.gd` | 81 | LIFT | view/hud | FULL | **[UPGRADED from MERGE]** Genuinely generic: canvas + font + probe, binding onto Visuals/UiTheme primitives. Nothing to cut. |
| `scenes/particles.gd` | 117 | **LANDED** `view/fx/particles.gd` (D0216) | view/fx | FULL | 8 named emitters incl. the draught (the silent half of the hollow tell) and chip/debris. Capped at 240. Uses `randf()` and its header states WHY that is safe: *"it never touches the sim, so randf() is safe here"* — the right precedent for view-layer nondeterminism. |
| `scenes/payouts.gd` | 77 | LIFT | view/fx | SCAN | **[CORRECTED from DEAD]** The floating "+3 ore" tick that rises off a broken block, with merging for repeat gains. 77 lines, pure feedback. |
| `scenes/player.gd` | 818 | KEEP-CURRENT | - | SKIM | Float `Node2D` `_physics_process` controller. Its OWN header: *"purely a representation-layer entity... never enters the deterministic tick"*. Current `sim/body` already carries its exact feel constants. Nothing to gain, 4 gates to lose. |
| `scenes/post_fx.gdshader` | 85 | LIFT | view/shaders | SKIM | Vignette+grain+aberration+filmic grade. The "shot through glass" look. |
| `scenes/rock_grit.gdshader` | 44 | LIFT | view/shaders | SKIM | Sub-cell tooth. Hardcodes the 8px cell → retune to 4px (Q1). |
| `scenes/rock_tooth.gdshader` | 69 | LIFT | view/shaders | SKIM | Additive-above-veil rock marks. Encodes the additive-at-depth constraint. |
| `scenes/rope_view.gd` | 274 | LIFT | view/render_entities | SCAN | Grapple cord with slack bow, hook, aim ghost, hung climb-ropes. 1 dead reference, in a comment. |
| `scenes/score.gd` | 162 | **LANDED** `view/audio/score.gd` (D0215) | view/audio | SCAN | **[CORRECTED from DEAD]** The MUSICAL score: three synthesized beds mixed by the body's DEPTH. Pure presentation, zero economy. |
| `scenes/settings.gd` | 455 | **LANDED** `shell/settings.gd` + `shell/settings_bindings.gd` (D0227) | shell/settings | SCAN | Audio levels, shake, zoom, bindings; persisted to `user://` ConfigFile, deliberately OUT of SaveGame (*"a save is a world; settings belong to this machine"*). ZERO dead references. `persist` defaults false so a scripted run works from pure defaults. |
| `scenes/settings_page.gd` | 865 | MERGE | view/hud | SCAN | Settings screen, unrelated to the economy. CORRECTED from LIFT: depends on `scenes/main.gd` (REBUILD), so that edge must be cut first. |
| `scenes/sfx.gd` | 1125 | LIFT | view/audio | SCAN | Every sound SYNTHESIZED at boot (no audio assets to port), plus looping beds whose levels follow the world. Resolves a blow against the material it lands on — the hollow/breach tells live here. Only 6 dead references, all trivial. `RandomNumberGenerator` is legal in `view/`; gate 2 polices `core/` and `sim/` only. |
| `scenes/sky_painter.gd` | 255 | **LANDED** `view/visuals/sky_painter.gd` (D0244) | view/visuals | FULL | Sky gradient, star field, sun/moon arc, clouds, 3 parallax ridges with aerial perspective — AND the SINKFORGE CROWN on the horizon. That matters: GDD §9 rejected Sinkforge-as-consumer partly because it *"is invisible from anywhere the player stands, so it cannot carry emotional weight"*. Legacy already built the answer. The 8-private-field caveat below is CLOSED: D0234 measured the real reach-in (five of the eight are one `marks` array), and the painter now takes `(frame, ci)` and draws to its own canvas. What is still open is not structural — whether it LOOKS right is P015, the director's ◆. |
| `scenes/strata.gd` | 55 | LIFT | data/strata | FULL | Band names+colours+depth readout. Dep: `layered_world_gen` for 2 row constants → becomes YAML. **Highest visual return per line.** |
| `scenes/terrain_painter.gd` | 438 | LIFT | view/render_world | SCAN | Per-cell fill, grain, ore crystals, autotile chamfers/fillets, carved-edge AO, surface cap/ramp. ZERO dead-content references. Bake-time, not per-frame. |
| `scenes/ui_theme.gd` | 236 | LIFT | view/hud | FULL | Panel/tab/elevation/defocus grammar. Dep: `visuals` only. This is what makes the UI read as 2026. |
| `scenes/visuals.gd` | 1850 | LIFT | view/visuals | SKIM | Palette + machine/item look registry. Deps: art, machine_def, recipe_def. ZERO sim dep. The single biggest clean lift. |
| `scenes/water_view.gd` | 362 | LIFT | view/render_world | SCAN | Surface line, depth shading, ripples, caustics, meniscus, drips. ZERO dead-content references. Its header carries a MEASURED extraction-seam table — that table is the decomposition data a `world_renderer` rebuild needs. |
| `scenes/world_renderer.gd` | 3656 | REBUILD | view/render_world | SKIM | THE COORDINATOR. `Node2D`, 161 sim refs, 25 deps. Every painter's ONLY poison path runs through it. Rebuild against `observe()`; painters lift underneath. Must split for the 400-line gate. |
| `scenes/world_seeder.gd` | 152 | REBUILD | scenarios/ | SCAN | Hand-placed tutorial fixtures + starter kit. The compat audit's ONE measured layer violation (32 MainView constant refs across 15 symbols). `CONTEXT.md` requires fixtures be DERIVED from a real run — this is authored by construction, so it cannot port as a fixture. |
| `src/core/factory_sim.gd` | 3259 | KEEP-CURRENT | - | SKIM | The hub: imported by 103 of 237 files. `advance(delta: float)`, `FastNoiseLite`, 35 float sites, hash-map iteration. Breaks gate 2 + the tick contract. |
| `src/core/fine_terrain.gd` | 114 | MERGE | sim/terrain_gen | SKIM | THE SIM-SIDE molding. Deterministic in (seed,coords) but via `FastNoiseLite` → gate 2 hard fail. Algorithm lifts, noise source becomes `core/SplitRng`. Distinct from the 1402-line view bake of the same name. |
| `src/core/flora.gd` | 64 | MERGE | sim/world | FULL | **[REASON CORRECTED]** Deterministic cell-hash growth, no RNG, conservation-ledgered. But calls `sim.invalidate_bazaars()` — a REAL Bazaar coupling invisible in the dependency graph. Must be cut. Found only by reading. |
| `src/core/heightmap_world_gen.gd` | 163 | KEEP-CURRENT | - | SCAN | Seeded `RandomNumberGenerator` (gate 2 ban). Hardcodes a flat spawn plateau at columns 39-58 for the bazaar-ruin footprint. Superseded by `ShaftGenerator`. |
| `src/core/layered_world_gen.gd` | 1059 | KEEP-CURRENT | - | SKIM | `FastNoiseLite` + `RandomNumberGenerator` + 89 float sites. Gate 2 bans both by name. 118 tuning constants worth reading as reference. |
| `src/core/machine_state.gd` | 45 | LIFT | sim/machines | FULL | Zero conditional logic, pure data bag. Two float fields need `Fx` to enter `sim/`. Its `fed` field is overloaded by two runners meaning different things — its own comment says *"check both before splitting it"*. |
| `src/core/power_flow.gd` | 89 | LIFT | sim/transport | FULL | Stateless, recomputed per tick, explicit L→R/R→L tie-break. float→Fx. Serves R1. Tier placement deferred (Q3). |
| `src/core/save_game.gd` | 455 | REBUILD | sim/meta | SCAN | Save shape is OPEN again post-pivot (ARCHITECTURE §11). AND it is an economy re-contamination vector: the envelope serialises `sim.research` directly (3 sites) and calls `invalidate_bazaars()` on restore. |
| `src/core/water_flow.gd` | 100 | LIFT | sim/fluid | FULL | **[REASON CORRECTED]** INTEGER LEVELS ONLY — no float anywhere, so NO `Fx` conversion needed, contrary to the first pass. Snapshot-based with an explicit deterministic sort, so its dict iteration is already order-stable. Its contract *"no source, no drain, sum invariant"* is exactly the constraint GDD §4 R3 says to violate in ONE named function for local flooding. |
| `src/core/world_data.gd` | 39 | KEEP-CURRENT | - | FULL | Coarse grid container. Superseded by `sim/world/tile_grid.gd`. Holds `lodes`, `amounts`, `water`, `routes` fields the current `TileGrid` has no equivalent for and will need. |
| `src/core/world_gen.gd` | 12 | KEEP-CURRENT | - | FULL | Abstract base for the two generators above. Dies with them. |
| `src/data/bit_rules.gd` | 110 | LIFT | data/tools | FULL | Point/Broad/Lance/Sinker/Wedge — shape not speed. GDD §4 R4 authorises verbatim. `BIT_RECIPES` stripped. |
| `src/data/machine_def.gd` | 21 | MERGE | data/machines | FULL | `craft_cost` field MUST be dropped at conversion (re-imports the one-time-purchase economy as data). |
| `src/data/machines/blast_furnace.tres` | 15 | LIFT | data/machines | SCAN | 2 ingots from 1 rich ore — the quality axis. `craft_cost` STRIPPED. |
| `src/data/machines/conduit.tres` | 12 | MERGE | sim/transport | SCAN | Power distribution. Q3 deferral. `craft_cost` STRIPPED. |
| `src/data/machines/crusher.tres` | 13 | LIFT | data/machines | SCAN | Spoil→gravel. Serves GDD §6 depreciation/spoil. `craft_cost` STRIPPED. |
| `src/data/machines/descent_engine.tres` | 12 | DEAD | - | SCAN | GDD §9 dead list, verbatim: *"a one-time descent gate as the only material sink"*. |
| `src/data/machines/drift_rig.tres` | 14 | LIFT | data/machines | SCAN | Powered gallery sorter. `craft_cost` STRIPPED. |
| `src/data/machines/drill.tres` | 14 | LIFT | data/machines | SCAN | Coal-burning ore extractor — the first automation. `craft_cost` STRIPPED. |
| `src/data/machines/gear_mill.tres` | 15 | LIFT | data/machines | SCAN | Gear crafter. `craft_cost` STRIPPED. |
| `src/data/machines/generator.tres` | 12 | MERGE | sim/transport | SCAN | GDD §9 dead-lists *"electricity as an early automation tier"* but ALSO warns removing power silently freezes every upward machine at unpowered throughput — *"the worst failure class this project has"*. Lift the mechanism, defer the tier. Q3. |
| `src/data/machines/h_drill.tres` | 14 | DEAD | - | SCAN | GDD §9 dead list, verbatim: *"horizontal boring"*. Also self-fuelling, which closes the loop the economy needed open. |
| `src/data/machines/hopper.tres` | 13 | LIFT | data/machines | SCAN | Buffer/stockpile. GDD §13's "buffers" rung. `craft_cost` STRIPPED. |
| `src/data/machines/iron_forge.tres` | 15 | LIFT | data/machines | SCAN | L2 smelter. `craft_cost` STRIPPED. |
| `src/data/machines/lift.tres` | 13 | MERGE | sim/transport | SCAN | The powered vertical transport. R1's own implementation note wires the cost mechanism to the shaft-to-surface lift. Core to R1. |
| `src/data/machines/ore_vent.tres` | 11 | MERGE | data/machines | SCAN | **[JUDGMENT, not a GDD ruling]** No `craft_cost` — world-placed, not built, which fits GDD §10's found-Forge opening. But an INFINITE ore source, which reads as fighting R2's finite-deposit relocation pressure. Flagged for the director, not ruled. |
| `src/data/machines/plate_press.tres` | 15 | LIFT | data/machines | SCAN | Plate crafter. `craft_cost` STRIPPED. |
| `src/data/machines/processor.tres` | 13 | LIFT | data/machines | SCAN | Generic recipe runner. `craft_cost` STRIPPED. |
| `src/data/machines/pump.tres` | 13 | LIFT | data/machines | SCAN | R3's own mechanism: the powered flood-drain. Named in GDD §4 R3. |
| `src/data/machines/rope.tres` | 13 | LIFT | data/machines | SCAN | Placeable climb. GDD §1 names rope as THE vertical traversal primitive. |
| `src/data/machines/splitter.tres` | 13 | MERGE | sim/machines | SCAN | GDD §9 flags this explicitly as needing a DECISION not automatic removal: the only branching mechanism, and *"two carved chutes are a splitter"* may make it redundant. Not the mapper's to rule. |
| `src/data/machines/spur.tres` | 12 | LIFT | data/machines | SCAN | Reach-extender for a drill Head. `craft_cost` STRIPPED. |
| `src/data/machines/torch.tres` | 14 | LIFT | data/machines | SCAN | Placeable light. Drives the room shot's warm pools. |
| `src/data/machines/winch_head.tres` | 13 | MERGE | sim/transport | SCAN | GDD §9: *"One thing should be repurposed rather than deleted... a throttled per-trip capacity plus a fixed transit duration linking two arbitrary cells."* `factory_sim` confirms exactly that: Head+Station, one player-drawn route, `WINCH_TRANSIT_TICKS` countdown. This IS the shaft-to-surface haul. |
| `src/data/machines/winch_station.tres` | 13 | MERGE | sim/transport | SCAN | The Station half of the same repurposed haul mechanism. |
| `src/data/material_def.gd` | 46 | MERGE | data/materials | FULL | A rich APPEARANCE schema, and a real art asset: `base_color`, `grain`, a Clastic/Bedded/Massive texture-grammar enum, `cap_color`, `nugget_color`+`count`, `depth_darken`, `glitters`. Becomes YAML under gate 22 (no binary resources in `data/`). |
| `src/data/materials/*.tres` (16 files) | 14-16 ea | LIFT | data/materials | FULL | Material records: colour, display name, wall variant. Pure content, zero economy structure. Files: `coal`, `deepslate`, `deepslate_wall`, `dirt_wall`, `earth`, `gravel`, `iron`, `leaves`, `ore`, `rich_ore`, `sealrock`, `shale`, `shale_wall`, `stone`, `stone_wall`, `wood`. |
| `src/data/mining_rules.gd` | 183 | MERGE | sim/economy + data | FULL | Hardness/tier/tool-gate tables. Pure static data. `mine_seconds()` returns float → becomes tick counts. `TOOL_RECIPES` must be STRIPPED. |
| `src/data/recipe_def.gd` | 14 | MERGE | data/recipes | FULL | `id`/`inputs`/`outputs`/`time`. Recipes survive; their acquisition model does not. `time: float` seconds becomes a tick count. |
| `src/data/recipes/*.tres` (6 files) | 12-15 ea | LIFT | data/recipes | FULL | Recipe records. The processing CHAIN survives; only its acquisition model dies. Files: `mill_gear`, `mine_ore`, `press_plate`, `smelt_ingot`, `smelt_iron`, `smelt_rich`. |
| `src/data/research_rules.gd` | 129 | DEAD | - | FULL | **THE TERMINAL ECONOMY.** 11-entry finite `ORDER`; `next_tech()` returns `""` when exhausted. 0 outbound deps; NONE of its 16 importers are on the lift side. Excision is provably safe. |
| `src/data/seams.gd` | 80 | **LANDED** `core/seams.gd` (D0227, moved to `core/` by D0237) | core | FULL | Rock grain as PLANES (row/column/anti-diagonal), a pure function of (coord, world_seed), never saved, RNG-free integer hashes. Exactly the current architecture's preferred shape. `RATE_*` and `_plane()` are float → `Fx` for `sim/`. Also the substrate for the Wedge bit AND used by `sky_painter` as a scatter hash. |
| `tests/*.gd` (5 suites) | 128-2015 ea | SKIP | - | TRACE | Legacy test suite against the legacy sim. Dies with that sim; current `tests/` supersedes. Files: `test_base`, `test_power_water`, `test_sim`, `test_stress`, `test_worldgen`. |
| `tools/**` (151 layers) | varies | SKIP | - | TRACE | Legacy's own 108-layer harness. Superseded by the CURRENT substrate (30 gates, 19 with enforcing code). Imperative one-script-per-case; no declarative format. |
| `tools/capture_moments.gd` | 1977 | SKIP-READ | - | SKIM | The blind-vision moment renderer that produced this report's screenshots. Worth re-deriving; not portable as-is (references `research_rules` + `bazaars`). |
| `tools/check_base.gd` | 301 | SKIP-READ | - | TRACE | Legacy harness base: 124 of 148 tools extend it. PASS/FAIL/SKIP/VOID 4-state + machine lock + save sentinel. Concepts already in `docs/QUALITY.md` §2; read for ideas, do not port. |
| `tools/check_mining.gd` | 154 | SKIP-READ | - | TRACE | Compat audit scored PORT: its ASSERTIONS about mining are sound and are **the spec for Slice 1's tests**. |
| `tools/lock_lib.sh` | 153 | SKIP-READ | - | TRACE | Machine-wide lock with stale-holder recovery. Current harness has its own. |
| `tools/play_agent.gd` | 882 | SKIP-READ | - | TRACE | The agent that DUG the delve/room/swing shots. Proves legacy mining end-to-end. Its verb sequencing is **the reference for Slice 1**. |
| `tools/play_tests.gd` | 2181 | SKIP-READ | - | TRACE | Scripted play suite. Directly references `research_rules`; dies with it. |
| `tools/run_harness.sh` | 1435 | SKIP-READ | - | TRACE | Sweep runner + verdict contract. Concept already carried by the current substrate. |
| `tools/check_trailers.sh` | 158 | SKIP-DONE | - | TRACE | Already ported forward. |

**Group-skipped populations, with reasons.** Legacy (357 files): 65 `.uid` and 16 `.import`
(Godot-generated), 166 `history/` screenshots, 90 `docs/` prose superseded by the current docs, 2 root
prose files, 17 `assets/` binaries (16 sprite PNGs + 1 `.aseprite` — these lift as a group, subject to Q1's
scale question), 1 LICENSE. Current (3,342 files): 2,749 `.log` harness artifacts, 325 `.png`, 173 `.md`,
59 `.uid`, 18 `.state`, 11 `.stdout`, 6 `.patch`, 1 LICENSE.

---

## Summary — how the 81,198 lines divide

| Verdict | Files | Lines | What it means |
|---|---|---|---|
| Lift | 63 | 8,539 | Comes over, rebinding its sim reads. Palette, UI theme, shaders, painters, audio, particles, strata, seams, water & power flow, all 44 data records. |
| Merge | 19 | 5,203 | Mechanism lifts, content re-authored: HUD, hints, hover, machine view, mining rules, grapple, fine terrain, the winch, power tier. |
| Rebuild | 5 | 7,477 | Needs a new spine. `world_renderer`, `main`, `save_game`, `objectives`, `world_seeder`. |
| Keep current | 6 | 5,350 | Current wins outright: the sim core, world gen, world data, the body controller. |
| Dead | 11 | 2,796 | The Bazaar (8 files), the research ladder, 2 machine records the GDD names. |
| Skip | 161 | 51,833 | Legacy's own 108-layer harness and tests, superseded. 7 flagged worth reading; 3 already ported forward. |

"Rebuild" is the row most easily misread. It is not 7,477 lines of loss — it is where the coordinator needs
a new spine while most of its contents travel with it. And the largest bucket, SKIP at 51,833 lines, is
legacy's *instrument*, not its game: the thing this project has already rebuilt better.

---

## Section 08 — The four calls, argued

**Simulation core — Keep current.** Not close. Legacy's sim violates four current rules simultaneously:
engine classes on the generation path (`FastNoiseLite`, `RandomNumberGenerator`, banned by name in
`tools/layer_lint/no_engine_imports.py` — gate 2 hard fail); floats on the state path (89 sites in
`layered_world_gen.gd` alone, against a spec requiring i32/16-bit fixed point); `advance(delta: float)`
taking a wall clock and running a tick accumulator, against `CONTEXT.md`'s *"The sim advances only by
explicit tick()"*; and ~11 hash-map iterations in state-affecting code. Lifting it deletes gates 2, 8, 24,
25, 26 and the fuzzer. The honest counter-argument: legacy's sim is engineered-deterministic and its stress
test replays byte-identical. It is a good sim. It is not *this* sim, and the substrate is bolted to this
one. One thing to carry across regardless: `world_data.gd` holds `lodes`, `amounts`, `water` and `routes`
fields the current `TileGrid` has no equivalent for and will need.

**Collision & mining — Keep collision, Merge the verb.** The premise needs splitting; the halves have
opposite answers. *Collision:* keep, decisively — the current controller is the strongest part of this
build (fixed-point, deterministic across processes, with an acceptance suite, a bounds invariant, a
reachability sweep, a per-commit fuzzer and a permanent regression fixture), and it already carries
legacy's feel constants verbatim. *The verb:* merge, and it is the fastest route to a playable game.
Downward mining is absent, not broken. Legacy supplies the missing design answer and the thing that makes
it feel like mining rather than cell deletion: **the hollow tell** — a weighted count of open cells ahead
of the face, biased along the swing, driving sound pitch, a draught of particles, and a breach payoff when
the wall gives way. Roughly 150 lines of view-side logic reading `is_solid`. And `hover_info.gd`
contributes a warning the current build needs: legacy measured that its body rect always covers two rows
and 2-4 cells, never one, so a cell-addressed verb is never really about one cell.

**Economy — Keep structure, lift content.** What stays dead: `ResearchRules.ORDER`, the one-time
`craft_cost` model, the Bazaar as the place you spend. What comes over: 22 machine records, 16 materials, 6
recipes, the coal-burn mechanism, the forge, ingots, plates, gears. Two contamination vectors to close
explicitly, both found by reading: the machine `.tres` files carry `craft_cost`/`craft_count` as fields —
strip them at conversion and make the schema validator reject them, so re-adding fails a gate rather than a
review; and `save_game.gd` serialises `sim.research` into the envelope, so the save schema is a second path
back in.

**Presentation / HUD — Lift, confirmed portable.** Confirmed more strongly than expected: zero `get_node`,
zero `%UniqueName`, one six-line `.tscn`, 24 of 33 files pure `RefCounted`. This layer also has the least
economy entanglement — a palette does not know what a demand is. `ui_theme.gd` deserves singling out: a
measured palette, with WCAG contrast ratios computed per plate and every colour's role argued from *"can a
player's input reach the thing this mark is on?"*. That is not something a rebuild recovers by trying
harder. Two qualifications: the best-looking screen (the Bazaar) is design-dead, so "lift the HUD" means
the world-facing furniture and the UiTheme grammar, not `hud.gd`; and `hud.gd` (2,189) and
`world_renderer.gd` (3,656) blow the 400-line gate by 5-9x, so they arrive as splitting work.

---

## Section 09 — Critical path

**Slice 0 — Strata names + material palette on the existing scene.** <1 session · no new layer · one revert
to undo. Lift `strata.gd` (55 lines) plus the 16 material records' colours, and paint them in the existing
`reveal_scene`. No `view/`, no L2. The smallest thing that stops the build looking like a debug harness —
and the cheapest possible test of Q1, before anything expensive depends on the answer.

**Slice 1 — Downward mining, with the hollow tell.** 2-3 sessions · touches `sim/body` · supersedes D0110.
Answer Q2, then cursor-aim + reach + hold-to-charge against the current `TileGrid`, with the current
collision untouched. Port the hollow tell and breach as view feedback. Lift `controls.gd` here for its
posable pointer. At the end of this slice a human can mine downward — the brief's stated bar, reached
without L2 and without touching the economy.

**Slice 2 — `interface/` exists.** 3-5 sessions · the keystone · ADR required. `observe()` /
`apply(Command)`, with `Command.Mine(cell)` as its first real member and `InputFrame` becoming its raw
level. Every lifted view file needs a legal thing to read.

**Slice 3 — `view/` exists.** 5-7 sessions · the bulk of the visual payoff. Turn the layer lint on `view/`
*first*. Then a new coordinator against `observe()`, with `sky_painter`, `terrain_painter`, `water_view`,
`rope_view`, `fine_terrain`, the five shaders, `particles`, `light_layer`, `visuals` underneath it. Use
legacy's own measured seam tables to choose the split boundaries.

**Slice 4 — HUD furniture and audio.** 3-4 sessions. UiTheme, depth readout, hotbar, objective card,
announce channel, key hints, band banner, `page_surface`, `settings`. Plus `sfx.gd` and `score.gd` — every
sound is synthesized at boot, so there are no audio assets to port. Bazaar left behind.

**Slice 5 — Content on rig demands.** 4+ sessions · blocked on `data/economy/`, reserved to the director.
44 records to YAML with `craft_cost` stripped, hung on the rig-as-consumer chain. Tool/bit model arrives
here, acquired by demand rather than research.

**Smallest slice that produces a visibly better playable state:** Slice 0, and it should run before
anything else is approved. Under a session, no gated layer touched, and it answers the one question that
silently governs every later estimate: does legacy's art read correctly at half its authored scale? Finding
that out for 55 lines beats finding it out four sessions into the renderer.

---

## Section 10 — Risks

**Effort blowup on the two coordinators — most likely to bite.** `world_renderer.gd` (3,656) and `hud.gd`
(2,189) must be split to clear a 400-line gate legacy never had. `QUALITY.md` §2 records
`sim/body/body.gd` landing at exactly 400 lines three commits running because it was trimmed rather than
split. These two will produce that pressure at 5-9x the scale. *Mitigation:* legacy already measured its own
extraction seams — `water_view.gd`'s header carries a table of four candidate boundaries scored on outbound
calls, inbound entry points, variables read and state written on both sides. Use it.

**Economy re-contamination through data and schema, not code.** Nobody will re-add `ResearchRules` — it is
loudly dead. The realistic paths are the 22 machine records quietly carrying `craft_cost` across during a
"content only" lift, and `save_game.gd`'s envelope carrying `sim.research` as a schema field. Close both at
the gate, not in review.

**Determinism regression through the noise swap.** Only `src/core/fine_terrain.gd` (114 lines) is affected:
it is on the sim path and uses `FastNoiseLite`. Its 1,402-line view-side namesake is not — it receives shape
from the sim as injected `Callable`s and its 11 noise fields are purely cosmetic, so it keeps its noise and
lands in `view/` legally. Do the sim-side swap before any golden hashes or fixtures are authored against
lifted terrain.

**Substrate breakage by omission.** Lower than it looks: 11 of 30 gates have no enforcing code, and four of
the five layers a lift would touch have nothing in them to break. The real exposure is the inverse — `view/`
and `shell/` are ungated *because they are empty*, and gate 1's layer lint has never had to police a real
`view → interface` boundary. Turn it on before Slice 3.

**The lifted art doesn't fit the world.** Q1. Legacy's sprites are 32x48 for a 14x34 body in a 32px world;
the current body is 16x40 in a 16px world, 2.3x bulkier relative to its terrain. Slice 0 exists to surface
this for the price of 55 lines.

---

## Section 11 — What the director must rule on

All five were ruled on 2026-08-29. The rulings are recorded here beside the questions.

**Q1 · blocks Slices 3-4 · World scale: rescale the art, or rescale the body?**
Legacy's look was composed for a 32px cell with a miner under half a cell wide; the current world is 16px
with a body a full cell wide.
*Map's recommendation:* keep 16px (normative in ARCHITECTURE.md §9, ADR-gated, the fixed-point range budget
is built on it) and adjust drawn sprite scale in `view/`. But run Slice 0 first: if legacy's terrain palette
reads as mush at 4px cells, this becomes a real fork rather than a view constant.
**RULED: keep 16px, adapt the art to it, do NOT coarsen the world.** The 16px cell is normative AND is the
deliberately finer-grained world (Noita-esque pixel granularity is wanted). Legacy's art is what adapts. If
the art reads as mush at 16px, the fix is to retune the ART. Report the finding; do not resolve it by
coarsening the world.

**Q2 · blocks Slice 1 · Mining input: cursor-aim, or a directional key?**
D0110 deferred this explicitly and it is why downward mining does not exist.
*Map's recommendation:* adopt legacy's aim model; legacy already solved the measurement problem too, via
`controls.gd`'s posable-pointer API and its deafness switch.
**RULED: CURSOR-AIM, Terraria-style.** Reach radius (`REACH_CELLS = 3.2`), hold-to-charge, charge banked per
cell so a mis-aim costs travel time not progress. Use the posable-pointer API so the harness can aim without
touching the OS cursor and a measurement can assert no pose is set — a contaminated aim reading is VOID, not
FAIL. The sim receives `Command.Mine(target_cell)`; whose cursor produced it is the caller's business.
**This supersedes D0110.**

**Q3 · shapes Slice 5 · Does the coal→power sink survive, and at what tier?**
**RULED: deferred to the economy work.** Lift `power_flow.gd`'s mechanism but do NOT wire it to an early
tier. Settles with R1's transport cost model at Slice 5. Same deferral covers generator, conduit, lift.

**Q4 · The Splitter, and the Ore Vent.**
**RULED: not ruled — deferred to Slice 5.** No ruling on the Splitter (the GDD reserved it). The Ore Vent
MERGE verdict is treated as a flagged question, not a finding.

**Q5 · procedural · Commit this map, and keep `legacy/`?**
**RULED: yes to both.** Commit as the pinned-hash record (this file). `legacy/` stays until Slice 4 lands,
then reduces to the buckets still unported — deleting it now strands every Merge row's source. And fix
Defect B standalone and first, before Slice 1 and before any more `--play` sessions.

---

## Section 12 — What the map is least sure of

Reproduced without softening. Where a later session has closed one, that is noted inline.

1. **The effort numbers.** Sessions, not hours; judgment, not measurement. The coordinator rows are where
   the map expects to be most wrong, and in the pessimistic direction.
2. **`main.gd` and `world_renderer.gd` were never read in full** — 6,659 lines between them, and every
   `view`/`shell` estimate inherits that. *(Both scheduled for full reads; see D0187.)*
3. **The `body left the world` bounds violation is unexplained.** Defect B was found nearby and
   deliberately not claimed as its cause.
4. **Whether legacy's atmosphere survives the sim-side noise swap.** The look depends on molding that
   depends on `FastNoiseLite`'s specific output. A `SplitRng` reimplementation will be deterministic and
   will not be identical. Slice 0 does not answer this.
5. **159 legacy files carry a SKIP verdict on trace alone.** They are legacy's harness, and the argument
   for skipping them is categorical (the current substrate supersedes it) rather than per-file. If that
   category judgment is wrong, it is wrong 151 times.
6. **The 22 machine records were field-enumerated, not read as prose.** Every field was extracted; the
   surrounding comments were not read.

---

## What actually landed, and what changed on the way (2026-08-30)

Six files have moved from LIFT to LANDED. **The unblocked batch is now dry** — every remaining LIFT row
is blocked on the `WorldRenderer` coordinator (~1,540 lines), on legacy's `FactorySim` (~2,700), or on
`MachineDef`/`RecipeDef` entities this build does not have (~2,050). `docs/NEEDS_DIRECTOR.md` P005 was
closed by the director choosing option 1; option 3 (un-park the coordinator) is the only route left to
changing how the game looks.

**Corrected while porting:** P005's "~900 lines liftable" already counted `score` and `particles`. The
remaining batch was **586 lines**.

| File | Landed as | Changed on the way |
|---|---|---|
| `score.gd` | `view/audio/score.gd` | One line: `Settings.music_db()` became an injected `music_db` float (D0215). **Now reconnectable** — `shell/settings.gd` provides the real source, but `shell/` has no boot, so the two are still not wired. |
| `particles.gd` | `view/fx/particles.gd` | Nothing. Lifted unchanged (D0216). |
| `art.gd` | `view/visuals/art.gd` | Added `clear_cache()` for tests. **`res://assets/` does not exist**, which is its designed empty state, not a defect — but it means only the miss path is testable. |
| `light_layer.gd` | `view/fx/light_layer.gd` | Nothing. **No consumer**: this build draws one flat `_draw` with no blend modes, and the veil "is not in Slice 0". Flagged as possibly contradicting its own ruling — `NEEDS_DIRECTOR` P009. |
| `settings.gd` | `shell/settings.gd` (131) + `shell/settings_bindings.gd` (351) | **SPLIT**, at its own seam: 455 lines against a 400-line blocking gate. Nothing in the first half reads an InputEvent, nothing in the second reads an audio level. `reconcile()` then came over at 52 against a 50-line function limit, so the device-rescue block became `_rescue_emptied_devices`, body unchanged. Its three `Controls` dependencies (`defaults`, `event_from_spec`, `register`) were already present from the Slice 1 lift. |
| `seams.gd` | `core/seams.gd` (D0237; was `sim/world/`) | **Float → integer**, which is what let it into `sim/` at all. Proven exact over the entire domain: 196,608 comparisons, 0 disagreements, with the naive `v < int(rate * 65535)` form kept as a control that must keep failing (it differs on exactly 3 inputs). Also renamed for the D0027 coordinate rule: `terrain_cell`, `terrain_dir`, `terrain_axis()`. |

**Three of the six have no consumer today** (`art`, `light_layer`, `seams`) and one is one wire away
(`score`). That is not an argument against having ported them — each was cheap and provably inert — but
it is the reason the batch running dry does not look like progress on screen.
