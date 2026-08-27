> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot despite `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 recommending it be KEPT as-is (a process/engineering doc with no game-design content the pivot
> touches) — the doc set that actually shipped (`docs/README.md`'s normative table) is smaller than the
> plan recommended, which is a later, real decision, not an oversight this move corrects. Moved here
> while closing the `.git/info/exclude` hole (ANVIL step 1) rather than restored to the live tree,
> because restoring a file to `docs/` on an old plan's authority alone is exactly the "acting on a stale
> doc" failure this project's own retrospective documented. Every `tools/` path referenced inside is the
> pre-pivot tree, now frozen under `legacy/tools/`. Kept for provenance, not deleted.

---

# The A+ programme

A bounded refactor programme, not a rolling improvement list. It has an entry condition, six areas, a
fixed order, and an exit condition. **No new gameplay feature and no Freight Winch work begins until it
exits.** Unpublished, like PRIORITY.md and FEEL_GAP.md.

## The sequence, and where we actually are

**Last corrected 2026-08-23, third pass.** The second pass, on 2026-08-22, said its own lesson: a status
summary that is not maintained is read as current. It then left THREE views of the same six areas in one
file that disagreed with each other and with the repository. The diagram said Area 2 was part-started, the
one-line table said Area 2 was closed, and the ledger below said nothing had been extracted yet. Area 4 was
"not started", "opened, one cliff closed", and "OPEN, in progress" in three places. Area 6 was "BLOCKED in
the repository", "DEFERRED by director", and "COMPLETE, history rewrite executed and published".

This pass keeps ONE statement of state and MEASURES the two that were most contested rather than choosing
between the sentences already written.

    Area 1  reliability and save safety               CLOSED
    Area 2  architecture                              CLOSED
    Area 3  harness truth and readiness               CLOSED
    Area 4  performance and maintainability           CLOSED
    Area 5  documentation and contributor readiness   CLOSED
    Area 6  public presentation                       CLOSED, tree and history both, measured below
            |
    gameplay evaluation and Freight Winch work        the programme is at its exit

### Area 6, measured rather than argued from the sentences in this file

Three sections here reached three conclusions about whether the published history still exposes the
process corpus. None of them is the evidence. This is:

    git rev-parse origin/main                                  63b75cd
    git rev-list --count origin/main                           887      (the census counted 1015)
    git log --oneline origin/main -- <the two session logs>     0 commits

The rewrite was executed and pushed. The blocker recorded above it, "the deferral was made on a number
that is wrong, so the decision is re-opened for the director", was written BEFORE that happened and has
been true of nothing since. It is struck rather than deleted, because the reasoning in it is sound and the
number it corrects is still the right number.

### The state of each area, in one line

| Area | State | The evidence |
| --- | --- | --- |
| 1 — reliability | **CLOSED** | 154 assertions across four save layers, 0 stood down, all PASS; every intake item mapped to where it is satisfied; the one unreachable guard flagged as such rather than ticked |
| 2 — architecture | **CLOSED** | `hud.gd` 4790 → 2015, `bazaar_page.gd` 3044 → 1441, `world_renderer.gd` 4601 → 3557; every remaining candidate carries measured rejection numbers; `main.gd` and `factory_sim.gd` measured and found to have no separable seam |
| 3 — harness truth | **CLOSED** | six instrument defects found and fixed, then five more on 2026-08-23: a wait whose budget was smaller than what it waited for, two layers reporting on art that had not been drawn, two counting layers with floors but no way to say no, two collision detectors never shown finding a collision, and the assertion floor that now holds all 91 counting layers |
| 4 — performance | **CLOSED** | the DIG hitch was the bazaar scan and not the terrain, p99 30.5ms → 17.1ms against brute force; the frame SLO promoted and its allowances moved out of one machine's numbers into a host registry that refuses rather than defaults; a live coupling bug found and gated behaviourally and by writer population |
| 5 — documentation | **CLOSED** | exit-4 explained, four registration classes documented, five stale layer citations removed and the class gated, the one-worktree workflow written down, two wrong commit-message claims published as errata |
| 6 — public presentation | **CLOSED** | tree and history. `origin/main` carries 887 commits where the census found 1015, the two session logs appear in none of them, and the fresh-clone scan recorded 0 residual blobs and 3 documented KEEP-VERBATIM message spans |

### Why the programme has not exited

**It has.** All six areas are closed, the configured sweep is green on `main`, and every stand-down carries
a written reason and resolves on every run of its layer. What remains open are findings rather than areas,
and they are listed with the evidence in `docs/A_PLUS_STATUS.md`:

1. Two pixel layers went red once each, on one sweep of 2026-08-22, and nothing has reproduced them.
   Classified environmental and unexplained; the shader-cache hypothesis was tested and weakened but not
   retired, because the test could not be run in the domain where the symptom lives.
2. `check_machine_state`'s ratios move with fixture timing by an order of magnitude, so `MOTION_MARGIN`
   cannot be trusted against them. Re-deriving it needs the negative population it was derived against,
   which no longer exists. **Queued for the director, not taken.**
3. `frametime.paced-phase` resolves out-of-reach on this host every run. Arming it means accepting an
   allowance that a reading has exceeded. **Queued for the director, not taken.**

Two blockers that were open are kept below rather than deleted, so the record shows how they went:

2. ~~**Area 3, the grapple bow.**~~ **CLOSED 2026-08-22.** Promoted, and it did take a red rather than
   remove one along the way. Both renderers now read 0.3631 against the renderer's own `rope_sag` of
   0.3718, and CI's display job went 15 PASS / 1 FAIL → 16 PASS / 0 FAIL at `32e7a45`. See Area 3.7 CLOSED.

3. ~~**Area 3, the material grammar.**~~ **CLOSED 2026-08-22, with a caveat on the number.** The director
   ruled against borrowing or lowering the floor and directed a visual/material pass at the named
   mechanism — seam direction not reaching the rendered frame. That pass shipped (`11968e4`): the tooth
   now takes the material's direction from an R8 grammar texture, additively and in absolute levels.
   `READ_FLOOR` was not touched. The layer passes. **But the closure figure of 99.14% is one draw of a
   statistic that reads 76.72 / 78.45 / 98.28 / 100.00 over four runs of the same commit** — see the
   Area 3.6 CORRECTION at the end of this document. Passing on every run measured; margin thin and
   unstable; the instrument, not the grammar, is what is owed next.

**Nothing here is a coverage claim.** An area marked closed means its listed items were done and
evidenced, not that the subject is beyond improvement.

## Entry condition

- Every capture-deafness domain has a disposition with evidence: integrated, superseded, rejected, or
  preserved. Five domains: harness, scenes, docs, src, tests.
- The branch is closed or explicitly parked, and its unique work is recoverable either way.
- `main` is the canonical baseline and the suite is green on it.

## STATUS LEDGER — synchronized with reality

> **Area 2 is CLOSED as of 2026-08-22.** `world_renderer.gd` 4601 -> 3557 across `097c769` (machines),
> `8fa99a8` (water) and `d1d5ab8` (rope + grapple). Every remaining candidate carries measured rejection
> numbers; `main.gd` and `factory_sim.gd` were measured and have no separable seam. Three older sections
> in this file reached different conclusions and are each marked at their own heading rather than
> deleted — a working record that silently agrees with itself is not a record.


**This file stays out of the tree.** It is the working record and it is full of the things a working
record is full of: vendor names quoted from census output, the labels the work was coordinated under,
and a narration of the presentation pass itself. Publishing it would put back exactly what Area 6 took
out, and naming the pass is a sharper tell than any single word in it.

The publishable half is `docs/A_PLUS_STATUS.md`, which is tracked: the disposition table, the Area 2 seam
measurement, and the Area 4 bazaar measurement, written as engineering rather than as process. It is
scanned against the same instrument before every commit that touches it.


The narrative below this ledger is append-only and records how each area was worked.

**THE DISPOSITION TABLE THAT WAS HERE IS GONE, and its absence is the point.** It was the third of three
tables in this file stating the state of the same six areas, and it disagreed with the other two: it said
Area 2 was partial with nothing extracted, three hundred lines above a section closing the extraction
programme on evidence, and it said Area 4 was open on the day Area 4 closed. A record that keeps three
answers to one question has no answer to it. **There is one table now, under "The state of each area, in
one line" at the top of this file**, and it is the thing to read first.

What this row carried that the one above does not, kept because it names the artifacts: Area 6's rewrite
was published at `origin/main` `8d0d6f7` with `pre-lode` at `927fbbe`, and the fresh clone verified the
tree byte-identical, a cold import clean, 110 PASS / 0 FAIL / 0 SKIP, and reachable-history residue of 0
blobs and 3 documented KEEP-VERBATIM message spans.

**Area 6 is closed permanently.** No further history rewrites, force-pushes, branch creation or archive
cleanup, absent a new concrete defect found by the post-push scan.

## Area 1 — Reliability and safety

- Save isolation and durable save transactions.
- Explicit migration and version semantics.
- No destructive harness fixtures.
- Honest PASS / FAIL / SKIP behaviour throughout.

## Area 2 — Architecture

- Split oversized controller, renderer and HUD files along real boundaries. `hud.gd` and
  `world_renderer.gd` are the two that a reviewer will open first and judge fastest.
- Consolidate manual registries into validated content definitions.
- Remove duplicated serializer and assertion logic.
- Clarify simulation and rendering ownership, and how invalidation crosses that seam.

## Area 3 — Harness quality

- Repair invalid and vacuous checks. Known open: `check_material_grammar` borrows `READ_FLOOR` from
  `check_rock_reads` rather than deriving it; `check_grapple_reads` selects cord by hue alone and its mask
  admits any warm grey in the corridor, which is why CI is red.
- Share runner, lock and verdict code.
- Add mutation and non-vacuity tests. `check_vacuous_assertions` exists on the divergent line and was
  rejected for producing false positives; it is the right idea and needs control-flow awareness.
- Preserve full artifacts and diagnostics.
- Separate headless correctness from headed visual and performance coverage.

## Area 4 — Performance and maintainability

- Profile before optimising. No cliff is a cliff until it is measured.
- Fix confirmed scaling cliffs only.
- Add reproducible performance semantics, so a number means the same thing on two machines.
- Reduce hidden coupling between renderer, sim and save state.

## Area 5 — Documentation and contributor readiness

- Reconcile architecture docs with executable behaviour.
- Contributor, release and export workflow.
- A clear repository map.
- Remove stale references and misleading counts. One class of these is now gated: the registry has to
  resolve to distinct existing scripts, so a layer total cannot drift.

## Area 6 — Public presentation

- A README that explains the engineering system accurately.
- A clear explanation of the play-agent, evaluation and harness architecture, which is the most
  distinctive thing here: the test surface is roughly 40k lines against a 27k-line game, and that reads
  as rigour or as imbalance depending entirely on whether the repository explains it.
- Keep history and media intentionally, with clone guidance. Decided 2026-08-21: `history/` (229 MB) and
  `docs/media` (98 MB) stay tracked, so a fresh clone is about 616 MB and the README must say why.
- Make the project legible to a senior-staff reviewer in their first ten minutes.

## Exit condition

All six areas closed or explicitly deferred with a written reason. Suite green. CI green, or its one red
explained in the README as an environment limit rather than left ambiguous. Only then does gameplay work
resume.

**Where that stands, 2026-08-23.** All six closed with the evidence named in the table at the top. The
configured sweep on `main` reads `112 PASS / 0 FAIL / 0 SKIP of 112` with the six registered stand-downs
and nothing else, `HARNESS_EXIT=4`, `HARNESS_RESULT=yes`, `HARNESS_QUOTABLE=yes`. Be exact about what that
sentence can mean, because the runner is: a sweep with a display cannot reach exit 0 and never will, since
three of the six stand-downs are structural. The reachable target is exit 4 with exactly the registered six
and no others. **"Configured sweep passed with six documented stand-downs" is the accurate sentence; "all
112 layers fully asserted" is not.**

The programme is therefore AT its exit and gameplay is unblocked by it. Three findings remain open and are
listed under "Why the programme has not exited" above; none of them is an area, and two are queued for the
director rather than taken.

---

## Area 2 groundwork: where `hud.gd`'s real boundaries are

Measured 2026-08-21, before any cutting. `hud.gd` is 4790 lines, 163 functions, 163 constants, and
`world_renderer.gd` is 4566 more; together they are 35% of the game's 26.7k lines of code. The file is
several screens in one, and the question is which seams are real.

**The first measurement was wrong and is worth keeping.** Counting how many of the 60 member fields each
cluster touches suggested the detail plate was the cleanest candidate: 320 lines against 3 fields. It is
in fact the WORST candidate. Field coupling ignores the call surface, and the detail plate calls 18
sibling functions. An instrument that measures one kind of coupling reports a file as separable when it
is not.

    cluster        funcs  lines  consts  excl-const  sibling calls
    settings          16    376      29           0              5
    bazaar/bench      13    195      21           0              7
    works              4    101      10           1              8
    rail               6     81      14           0              1
    pack               3     64       9           0              6
    detail             9    320      30           3             18

### What this says to do, in order

1. **The shared constant layer comes first, and it blocks everything.** Every cluster uses 9 to 30
   constants and almost none exclusively: 0 exclusive for settings, bazaar, rail and pack. Palette,
   spacing and typography belong in one place before any screen moves, or each extraction drags a copy
   of the theme with it.
2. **Settings is the first screen to move.** 376 lines, the largest cluster, and only 5 sibling calls:
   the best payoff per unit of coupling in the file.
3. Then bazaar/bench (195 lines, 7 calls), works (101, 8), pack (64, 6).
4. **The detail plate goes last**, or not until the shared drawing primitives it leans on
   (`_round_rect`, `_chip_label`, `_chip_numeral`, `_verb_button`, `_state_plate`, `_demand_mark`,
   `_draw_thing_icon`) have moved into `Visuals`, which already holds static drawing helpers taking a
   `CanvasItem`. Move the primitives and its 18 calls collapse; move the screen first and they become a
   wide parameter list.
5. `rail` is the cheapest possible proof of the pattern at 81 lines and 1 call, if a rehearsal is wanted
   before settings.

### Not started

No extraction has been performed. `check_hud_layout` covers collisions and gives partial cover for this
work, but a screen split deserves before/after captures of the affected moments and a reviewed plan, not
an overnight cut.

## Area 2 intake: the surface and the sim each answer "can this be paid for" (filed 2026-08-21)

Found while giving the counter's cost helpers an owner, by a fragment scan rather than by reading:

    scenes/bazaar_costs.gd     int(inventory.get(item, 0)) < int(cost[item])   the ink and the verb state
    src/core/factory_sim.gd    the same line, twice                            craft_unlocked, craft_item

Two implementations of one question, at two layers. This is not the four-copies-in-one-file case that
`BazaarCosts` exists to close: the sim gates the actual spend and the surface decides what to draw, and a
UI that asked the sim for every chip's ink on every frame would be a different design. But they can
disagree, and if they ever do the counter will offer a craft the sim then refuses, which reads to a
player as the button lying.

Not fixed here, and deliberately not folded into a relocation slice. Filed with the evidence so the next
Area 2 pass can decide whether the surface should ask the sim, whether the sim should ask a shared
predicate, or whether the duplication is correct and should be documented as such.

## Area 3 intake: the measurement window has no readiness gate (filed 2026-08-21)

Three sweeps at `da83400`; the failing set moved between them on a byte-identical tree. Capture layers read
chance and driver layers read zero **in the same run**, which no rendering constant can cause. Each such
layer opens its window on a fixed frame count; the shader cache is disabled every boot, so on a contended
box the window can open before the scene is ready.

Repair, when Area 3 comes up: gate the window on an **observable** — shaders resident, world generated,
actuator confirmed to have fired at least once — instead of a frame count. Do not touch the bounds; every
one of them is correct and the runs feeding them were not. Full evidence in the archive record.

### Area 3 intake, second finding: a readiness gate already exists and is set 15x too low

`check_snap_frame` failed one sweep with `CONTROL: one bucket over DOES move the picture — 0 changed
against 0`. Three isolated runs on the identical tree then passed with control ratios of roughly 540x,
1000x and higher, so the red is the same degenerate-run class and not attributable to the constants work.

The useful part is the number the layer printed on its way past the problem:

    structured pixels, three healthy runs   299238   300881   303455
    structured pixels, the failing run       32912
    MIN_STRUCTURED                           20000    <- the floor it cleared

**The frame that produced a meaningless measurement carried a tenth of the picture and passed the guard
meant to catch exactly that.** The floor is not wrong in kind, it is wrong in scale: it was set to catch an
empty frame and the degenerate frames on this box are not empty, they are sparse.

This is the readiness gate proposed in the previous intake, already sitting in the layer. The Area 3 repair
is to derive these floors from an observed healthy population rather than from a round number, and to apply
the same treatment to every capture layer. Note the floor cannot simply be raised to 250000 without first
characterising the healthy population per layer and per environment, since CI's software rasterizer will
have its own distribution. Derive, do not guess. See the archive record for the full evidence.

---

## Status log

### Milestone 2 (Area 2.2, HUD architecture) — in progress

| Commit | Slice | Evidence |
| --- | --- | --- |
| `04d5e22` | 2.2a model: `SettingsPage` owns the page's shape | 4 faces pixel-exact vs noise floor; SOLE_OWNER guard, 2 mutants |
| `d0d2b43` | duplicate letter-spaced text collapsed (4 names, 2 impls) | 109 green; 2 external refs broke and were caught by the suite |
| `3f6e532` | plate primitives to `Visuals`; 3 more copies found in mocks | SOLE_IMPL guard, 1 mutant |
| `4872f4f` | `_focus_ring` + its 6 constants to `Visuals` | 4 faces pixel-exact; 2 mutants |
| `5f80c04` | keycaps to `Visuals` with explicit probe passthrough | 19/19 panel readings identical; 3-sample noise floor; 2 mutants |
| `e9b6baf` | 2.2a model: SET_*/REMAP_* measurements to `SettingsPage` | 3 faces pixel-exact; SOLE_OWNER guard |
| `e4940fb` | rail cluster to `UiTheme` — `e9b6baf` had misfiled it | 12/12 consts and 5/5 helper bodies identical at source; 2 mutants |
| `b8784c4` | 2.2a rendering: the settings page draws itself | 27/27 bodies identical at source; 3 faces pixel-exact vs a same-tree noise pass; 3 mutants |
| `9580005` | `thing_icon` to `Visuals`; the hotbar's copy collapsed | boot 0.054% vs 0.058–0.589% noise; bazaar path identical at source; 1 mutant |
| `2443163` | 2.2b: the bench draws itself, in a new `BazaarPage` | 9/9 bodies identical at source; 2 bistable moments resolved; 2 mutants |
| `06ae531` | the `.uid` sibling `2443163` missed | generated-file check added to every checkpoint |
| `83c380d` | `thing_label` beside the `thing_icon` that already took the same table | SOLE_IMPL guard |
| `114f18b` | 2.2c model: the counter's model moves to the page, ahead of the tabs reading it | 15 model funcs; property forwards; 2 mutants |
| `74e49b6` | 2.2c rendering: the works tab joins the page it was already reading | 8/8 bodies identical at source; `works` NOT separable from noise and not reported as a pass |
| `ed30d3f` | 2.2d: rail and pack, and the contrast layer follows the palette | 10/10 bodies identical at source; 2 mutants on the widened loader |
| *pending* | **2.2e: the detail plate, and the cost seam gets an owner** | 21/21 bodies + 33/33 constants identical at source, 5 negative controls; `bench` a 0 px null; 4 mutants |

hud.gd: 4790 to 2162 lines, a 55% reduction. visuals.gd: 1536 to 1837. settings_page.gd: 0 to 871.
bazaar_page.gd: 0 to 1889. bazaar_costs.gd: 0 to 67. ui_theme.gd: 0 to 236.

**Rejected / deferred, with reasons**
- *Extracting the Settings RENDERING before the primitives moved.* Measured first: it called 11 hud
  primitives, 9 shared with other clusters. Would have produced the parameter-heavy module 2.2e warns
  against. Deferred until the primitives landed, which reordered 2.2e ahead of 2.2a-rendering.
- *Moving `_round_rect` wholesale.* It carries the `panel_probe` hook. A thin wrapper stays on the Hud
  because the probe is a property of the page being measured, not of how a box is drawn.
- *`mock_bazaar._tracked_w`.* Routes through the mock's own font helper, so it is not the flagged
  fragment. Left alone rather than forced.

**Intake from the 2.2a rendering slice**

- *A guard for the two halves of `settings_page.gd`.* The file is now data-and-pure-functions above a
  banner and drawing below it, and nothing enforces the split but a doc comment. A static function that
  reaches for `_canvas` should fail a check. Cheap to write against the existing `SOLE_IMPL` machinery.
  Not done in the slice that created the need, so that the slice stayed one thing.
- *The `_binding_clashes` near-miss is a class, not an incident.* Twelve private methods left `Hud`; one
  of them had external callers including a harness layer, and the census that was supposed to find that
  was written with a lookbehind excluding `.`, so `hud._binding_clashes()` was invisible to it. Any
  future extraction needs the caller census to COUNT the object-prefixed form, not exclude it.

**Rejected in this slice**
- *Deleting the three stale `HELPER_TAGS` entries.* That is the smallest change that turns the red green
  and it shrinks the registry: the settings drawing helpers did not stop being drawing surfaces by
  changing file. The check now enumerates `Hud` and `SettingsPage`, proved load-bearing by a mutant that
  reverts the enumeration and fails naming all three.

**The Bazaar measured before it is touched (2026-08-21)**

58 functions, 982 code lines, five clusters. Coupling decided the order rather than the guess:

| cluster | funcs | lines | calls out to | called from |
| --- | --- | --- | --- | --- |
| shell | 10 | 129 | detail 2, works 1, railpack 1, bench 1, other 11 | other 6, detail 2, bench 1 |
| bench | 9 | 121 | shell 1, other 3 | shell 1, other 1, detail 1 |
| works | 6 | 78 | other 12, detail 1 | shell 1, other 2 |
| railpack | 12 | 182 | other 15, detail 2 | shell 1, other 2, detail 1 |
| **detail** | **21** | **423** | bench 1, shell 2, railpack 1, **other 26** | shell 2, works 1, railpack 2, other 3 |

`detail` is the hub on both axes, which is the measured reason it goes last. `bench` is the loosest
and goes first. The shell calls into three not-yet-moved clusters, so moving it first would create
backwards coupling that later slices then have to unpick; leaves first, shell last.

**2.2e is smaller than planned, and this is a corrected measurement.** Of the eleven candidate
primitives, ten are reached only from inside the detail plate and should travel with it rather than
going to `Visuals`. The first pass said four of them were cross-cluster; that was an artifact of a
cluster map that omitted the detail plate's own helpers, so `_verb_button`, `_demand_mark` and
`_detail_chip` counted as "other". Only `_draw_thing_icon` is genuinely shared — railpack, works,
bench twice, detail — and it is the only one that has to move before the cluster extractions.

**The invariant the Bazaar decomposition holds:** nothing in `BazaarPage` calls back into `Hud`. The
shell may call in; the page may not call out. Each slice must pay whatever that costs at the time it
moves, rather than leaving a cycle for a later slice to unpick. 2.2b paid one: `_tab_bench` took the
picked tech id as a parameter instead of calling `bazaar_action()`.

**The second boundary: measured twice, and the first reading was wrong (2026-08-21)**

The page doubled and then doubled again, so the question is whether it still belongs in one file. It was
measured at 1070 lines and again at 1937, and the two readings disagree. **The second one supersedes the
first**, which is the reason the decision was held until the plate had landed.

At 1070 lines the internal call graph, with the high-fan-in helpers cut out, showed three tab clusters
over 25 lines of shared fabric, and the obvious conclusion was a per-tab split. At 1937 lines that is no
longer what the graph says: the detail plate does not form a fourth cluster, it **fuses with works+rail
into one 719-line component**, and a three-way split would put the largest thing in the file on the wrong
side of every line drawn.

**The fusion is two functions and fifteen lines.**

    _cost_order   10 lines   called by _draw_bazaar_detail  and by _cost_glyphs
    _can_afford    5 lines   called by _draw_bazaar_detail  and by _works_row

Both are cost queries with no drawing in them, and both already sit in the page's pure half. Counting
them as shared rather than as works-tab helpers is not a refactor, it is a correction to the cluster
map. Do that and the file separates cleanly:

| unit | funcs | lines |
| --- | --- | --- |
| detail plate | 24 | 522 |
| pack | 7 | 190 |
| works and rail | 18 | 182 |
| bench | 8 | 101 |
| **shared core** (12 fabric helpers + the 2 cost queries) | **16** | **56** |

**Four files over a small core, and the split is worth taking.** Not yet: the shell is the last thing
still in `hud.gd`, and a slice that lands after a split is a slice that can re-fuse it. Order is shell,
then split.

**CONFIRMED after the fact.** Moving the three cost queries to `BazaarCosts` was predicted to open the
seam, and re-running the same graph on the resulting file says it did, with nothing else changed:

    before the move   one fused component      719 lines, 44 funcs   (detail + works + rail)
    after the move    detail 522, pack 190, works and rail 182, bench 101, fabric 39 lines

The prediction and the check were separate acts on separate days of the same afternoon, which is the
only reason the confirmation is worth anything.

Drawing/pure at 1937 lines: 25 funcs and 699 lines touch `_canvas`, 51 funcs and 365 lines never do.

**What this cost and what it bought.** Two measurements instead of one, and the first was recorded here
as a conclusion before the evidence that overturned it existed. The reading was honest and the frame was
not named: "three clusters over 25 lines" was true of a file missing its largest cluster. See
[[name-the-frame]].

**Gate 3: the plate's captures, and what pixels could and could not settle (2026-08-21)**

Five Bazaar moments, two runs per code state, captured inside ONE worktree so the tree, the import and
`user://` are held fixed and the code is the only difference. Counts are pixels over a 0.20 threshold on
a 1920x1080 frame.

| moment | same code (HEAD) | same code (treated) | treatment, 4 pairings |
| --- | --- | --- | --- |
| bench | 0 | 0 | 0, 0, 0, 0 |
| counter | 30713 | 16996 | 12470, 4329, 23407, 32512 |
| works | 34236 | 39571 | 40794, 64272, 10554, 45699 |
| works_short | 32266 | 22344 | 11879, 26936, 38388, 53910 |
| pack_full | 512 | **148637** | 56145, 155350, 56037, 155066 |

**`bench` is a decisive null: 0 px in all six comparisons**, so those two frames are byte-identical
across the change. Nothing else is decisive, and none of it is reported as a pass.

**`pack_full` reads by FRAME, not by tree.** Everything paired with the first treated frame lands at
~56,100 and everything paired with the second at ~155,200, while the two treated frames differ from
EACH OTHER by 148,637 on identical code. A within-code difference that equals the cross-code difference
is an instrument that cannot separate them. The same shape, weaker, is in `counter`, `works` and
`works_short`: every treatment reading falls inside the spread of same-code readings.

**What the pixels are actually measuring.** A first attempt compared two different worktrees and found
`pack_full` at 2.2-2.7% against a 0.025% floor, which looked like a finding. It was not: the same-code
floor in the treated tree is 7.2%. Two corrections were needed to see that. The first pass also used the
moment named `pack`, which has no Bazaar pose at all -- its log reads "through the LOOSE plug" and its
`modal=none`, so it is the terrain gravel moment and could not have registered this change at any size.
The Bazaar pack frame is `pack_full`.

**Therefore source equivalence is the load-bearing evidence for this slice, and pixels are corroborating
at best.** That is the right order for a change that is provably textual: 21/21 relocated bodies and
33/33 relocated constants identical as normalised token streams, each with negative controls that fire.

**The shell landed, and the split seam survived it — but only once the coordinator was named (2026-08-21)**

Moving the shell onto the page appeared to undo the split: the four clean units collapsed back into one
958-line component. They had not. **The shell is not a fifth peer, it is the coordinator**, and a
coordinator fuses everything it coordinates when a clustering metric treats it as a peer. Cutting it out
alongside the shared fabric, the same way the fabric itself is cut, the units are still there and one
more has appeared:

| unit | funcs | lines |
| --- | --- | --- |
| detail | 21 | 470 |
| pack | 7 | 190 |
| works | 9 | 127 |
| bench | 8 | 101 |
| rail | 8 | 53 |
| coordinator | 12 | 155 |
| fabric | 15 | 49 |

`rail` separated from `works` once the shell arrived, because what had joined them was reached through
the shell all along.

**The whole coordinator-to-tab interface is six calls, and they ask one question:**

    _bazaar_geometry  -> _detail_wanted_h
    _bazaar_wanted_h  -> _bench_tallest, _detail_wanted_h, _ledger_h, _pack_rows, _works_rows_needed

"How tall does your tab want to be." Nothing else crosses. That is the interface the split gets to keep,
and it is small enough that each unit can move on its own slice without the others being touched.

**The lesson is about the metric, not the code.** Connected components answer "what would fall apart if
these edges were cut", and a coordinator's edges are the ones you least want to cut. Anything that talks
to everything -- a fabric helper, a shell, an accessor -- has to be named and held out before the
question means anything. Held out, the answer had been stable across three separate measurements.

**The split would have multiplied a duplicate by five, so the base class comes first (2026-08-21)**

Measuring the rail unit before extracting it turned up something larger than the unit. Eleven helpers
were defined in BOTH `BazaarPage` and `SettingsPage`, byte-identical after comment stripping:

    _round_rect  _round_rect_left  _keycap  _keycap_w  _tracked  _tracked_w
    _rail_slots  _rail_word_slot_h  _rail_key_slot_h  _rail_word_dy  _rail_key_dy

Not copied by hand. Each page acquired its own set at the moment it was carved out of `hud.gd`, which
makes this decomposition's own byproduct rather than anything inherited. It is the class the repository
already has a guard for: two implementations that agree, with nothing in the tree comparing them, and
the day one is fixed and the other is not the two surfaces disagree about a keycap.

**Every one of the eleven needs exactly four fields** -- `_canvas`, `_font`, `probing`, `panel_probe` --
and nothing else, which is a base class stated as a measurement. `PageSurface` holds those four and the
eleven, and both pages extend it. A twelfth came with them: `_bazaar_vignette`, identical in both, and
sitting on the settings page under a name that mentions a screen it has nothing to do with. It is
`_modal_vignette` now.

    bazaar_page.gd   2072 -> 2016      settings_page.gd   871 -> 816      page_surface.gd  0 -> 81
    identical bodies remaining across the two pages: none

**The arithmetic that decided the order.** The five-way split was next, and it would have carried these
eleven into five units: 24 lines becoming 120, in five places that must agree forever. Doing the base
first makes each unit carry none. This is the same reasoning that put `BazaarCosts` before the split and
it is worth stating as a rule for the rest of the programme: **before dividing something, look for what
the division would multiply.**

**Next:** the five-way split of `BazaarPage` -- detail 470, pack 190, works 127, bench 101, rail 53 --
behind a 155-line coordinator, a 49-line fabric and `PageSurface`. 2.2c, 2.2d and 2.2e have landed, the
shell has landed, and no Bazaar drawing remains in `hud.gd`.

## 2.2f — the bench leaves the page, and two guards learn where it went

`f1ecc19`, pushed. `scenes/bazaar_bench.gd` (new, `BazaarBench extends PageSurface`), `scenes/bazaar_page.gd`
(2017 → 1885), `tools/check_shared_constants.gd`, `tools/check_hud_layout.gd`.

Sweep: **109 PASS / 0 FAIL / 0 SKIP**, `HARNESS_RESULT=yes`, 6 registered stand-downs. The sweep before the
guard repairs read 107/2; both reds are recorded below with their classification.

### The reachability scan had a hole, and it had already passed a verdict on four pushed commits

The scan that clears an extraction matched `identifier.member`. A call through an expression —
`_bazaar()._tab_bench(g, …)` at `scenes/hud.gd:1473` — has a `)` for a receiver and never matched, so the
scan reported **0 dangling references when there was one**. This is the `_craft_id` failure again: it would
not have failed the sweep, it would have *hung* a layer.

The receiver pattern is now `[\)\]A-Za-z0-9_]\s*\.\s*(\w+)`. Because a broken instrument invalidates its
earlier verdicts and not only its latest one, the corrected scan was re-run against all four extractions
already pushed this session (`ed30d3f`, `79ce3a0`, `01189f0`, `7e40442`). It raised 49 hits, and **all 49
resolve** once the receiver's class is resolved through its `extends` chain — `UiTheme.RAIL_*` is not
`Hud.RAIL_*`, and `BazaarPage.probing` reaches `PageSurface.probing` by inheritance. The scan is
receiver-blind by name; the resolver is the part that makes its output mean anything. Control: a fabricated
name resolves to nothing.

**One genuine break, one fix**: `BazaarPage._tab_bench` restored as a forwarder.

### Both reds were the guards working

| red | classification | disposition |
| --- | --- | --- |
| `check_shared_constants` — 6 × `BENCH_*` owner mismatch | correct detection, stale registry | owner repointed to `bazaar_bench.gd`; assertion unchanged |
| `check_hud_layout` — `STALE: _draw_tech_chip` | correct detection, instrument one level too shallow | surface walk made transitive |

No threshold was lowered and nothing became a SKIP. `check_hud_layout` derives its surface list by walking
the objects the Hud holds — written when no page held a page. `BazaarBench` hangs off `BazaarPage`, one level
past where the walk stopped. It now continues through each surface it discovers, using the already-seen array
as both de-duplicator and cycle break, and reports **30** `_draw*` methods where it saw 29.

Mutation-tested, both: a wrong owner path fails; removing `_draw_tech_chip` from `HELPER_TAGS` fails as
`UNTAGGED: _draw_tech_chip` — which is the evidence that the deepened walk *reaches* the new file, rather
than passing over an empty set.

### Re-measured seam, current frame

Held out: coordinator (15) + fabric (9, fan-in ≥ 3). Page at 1885 lines.

| unit | funcs | lines |
| --- | --- | --- |
| detail — demand and hold | 12 | 222 |
| pack | 7 | 204 |
| works | 9 | 145 |
| detail — chips | 4 | 37 |
| detail — pack summary | 1 | 32 |

The 9 fabric helpers split by what state they need: 4 need only `PageSurface`, 3 need `_sim`/`_icons`, and
`open_rack`/`open_machines` read the page's own option lists. **`BazaarBench` already re-declares `_sim` and
`_icons` and carries its own copy of `_draw_thing_icon`** — the duplication a three-way split would multiply
by three. Next slice is therefore `BazaarSurface extends PageSurface` holding `_sim`, `_icons` and the seven
page-independent helpers, on the same reasoning that put `PageSurface` in before the first split.

## 2.2g — a base for the tabs, then the pack tab leaves

`361c55d` and `ebb43da`, both pushed. Sweeps green at each: **109 PASS / 0 FAIL / 0 SKIP**, `HARNESS_EXIT=4`,
6 registered stand-downs.

`BazaarSurface` sits between `PageSurface` and the tabs and holds only what measurement said was shared:
`_draw_thing_icon` (called from all four tabs), `_item_label` (two), `_cost_numeral` (two), plus `_sim` and
`_icons`. The lamp, glyph inset, verb button and the plate's bottom shelf are detail-plate and shell fabric
— `_detail_row` is called from no tab at all — so they stayed. That kept **ten constants out of the base**;
`_detail_lamp` alone would have dragged `DETAIL_LAMP_STEP`, which derives from `DETAIL_ART`, which the plate
needs.

`BazaarPack` then went cleanly because it calls nothing back. Its hover-tooltip state moved with it and the
page keeps three forwarding properties, so the Hud's own three did not change. `PACK_CELL` went down to the
base rather than with the tab: the panel's minimum height is written from it, and page and tab are siblings.

`scenes/bazaar_page.gd` is now **1636 lines**, from 3044 at the start of this area and 4790 at programme start.

### Reds this section, both classified, no bound touched

| red | classification | disposition |
| --- | --- | --- |
| `check_prose` — 5 em-dashes in `scenes/` comments | correct detection, my pre-flight had the wrong rule set | replaced with the house ` -- ` |

The prose gate reads **comment bodies only**, so the five em-dashes in player-facing string literals in the
same files are outside it and were left alone; the reported counts (2 and 3) matching the comment-line counts
exactly is what established that. Its population is **tracked files**, so `bazaar_pack.gd` passed while
untracked and would have failed on the next commit — a new file's prose is ungated for one slice.

### Capture evidence for the pack tab: INCONCLUSIVE, and recorded as such

Same-tree before/after, three samples each of `pack_full` and `pack_fresh`, tree restored and verified
byte-identical afterwards.

| | px above 0.20 |
| --- | --- |
| same-code floor, baseline tree | 1051 .. 18207 |
| same-code floor, treated tree | 811 .. 3596 |
| before vs after | 216 .. 16952 |

The treatment range sits inside the floor and the closest pair in the set is a before against an after,
which a real rendering change could not produce — but **no crossing zero appeared**, so this is suggestive
and not confirming. The equivalence claim rests on the token-stream comparison and on `check_pack_layout`,
which re-derives the geometry at risk here and reads 190 fresh / 236 stocked / 348 bench, unchanged.

### Remaining, and the obstacle

| unit | funcs | lines | calls out |
| --- | --- | --- | --- |
| detail | 14 | 232 | `_hold_text_w`, `_item_demand`, `_state_plate`, `_verb_button`, `_verb_button_w` |
| works | 7 | 135 | `_craft_id`, `open_machines`, `open_rack`, `works_demand`, `works_window_first` |

Both call back into the page, which pack did not. A sibling that calls the page is a cycle, so each of those
outbound calls has to be resolved — moved down to the base, moved with the unit, or turned into an argument —
before either can be lifted. That is the next question, and it is why pack went first.

## 2.2h — the catalogue, then WORKS; and why the detail plate is not a fifth tab

`1523f54` and `e9feb96`, both pushed, each on a green sweep (**109 PASS / 0 FAIL / 0 SKIP**, `HARNESS_EXIT=4`).

`BazaarCatalogue` holds the four lists `scenes/main.gd` fills and the four questions asked of them. It went
first because WORKS and the shell both query them: a tab that reaches back into its owner is a cycle, not a
split. Nothing outside moved — the page keeps a property of each list and the three queries stay page
methods, so `main.gd`, the Hud and both checks read and write exactly where they always did.

`BazaarWorks` then went out: 9 bodies, identical as token streams once the single intended rename is undone
(catalogue access moving onto the handed-in object), with a mutation control **and** a control proving the
undo is not a blanket eraser. `BAZAAR_COLS`, `BAZAAR_GUTTER` and `BAZAAR_ROW_H` went down to `BazaarSurface`
for the reason `PACK_CELL` did; `SHORT_SELECTED` had no reader outside the tab and went with it. All four
owner entries were re-pointed and each was shown to fail when aimed at the wrong file.

**Correction to `e9feb96`'s message:** it states the page is 1412 lines. It is **1441** — 1412 was the count
before the accessor and forwarders were appended. Not worth rewriting a pushed commit; recorded here instead.

### A boundary bug worth naming: a `const` can span lines too

The first attempt at the WORKS cut produced an unparseable file. `const SHORT_SELECTED := Color(` is a
**multi-line declaration**, and the extractor took declarations as one line each — so it split the constant,
carrying an unclosed `(` into the new file and leaving the continuation behind. This is the function-body
boundary error in a new place: *a declaration's extent is a bracket question, not a line question.*

The extractor now walks bracket depth for declarations, and both sides of every cut are asserted to balance
at zero. That assertion is what makes the class of error visible instead of arriving as a parse error three
steps later.

### DEFERRED: the detail plate stays on the page, and this is a finding rather than a shortfall

Measured in the current frame — coordinator and fan-in≥3 fabric held out, page at 50 funcs / 1442 lines:

| component | funcs | lines |
| --- | --- | --- |
| detail — demand and hold | 12 | 222 |
| detail — chips | 4 | 37 |
| detail — pack summary | 1 | 32 |
| everything else | 6 | ≤19 each |

Taken as a whole unit the plate is 21 funcs and 502 lines, and it **still calls out to nine page functions**,
including `bazaar_action` — the shell's own dispatcher — and uses 41 constants, 19 of them shared with the
rest of the page, among them `TAB_PACK` / `TAB_WORKS` / `TAB_BENCH`, which `main.gd` and two checks read.

The three tabs were separable because each owns a region and answers the shell one question. The detail plate
does neither: it draws under whichever tab is showing, reads `bazaar_tab` to decide what to show, and asks
`bazaar_action` what is focused.

> **The detail plate is not a fourth tab. It is the shell's bottom half.**

Extracting it would need roughly fifteen injected names and would reintroduce through `bazaar_action` exactly
the cycle the catalogue was created to remove — the same reason the rail was left alone at 41 lines. Recorded
as DEFERRED, not blocked: if the plate is ever split it should follow a decision about the *shell*, not about
the tabs. Area 2.2 exits here.

### Where the area landed

| file | at area open | now |
| --- | --- | --- |
| `scenes/hud.gd` | 3044 | 2015 |
| `scenes/bazaar_page.gd` | 3044 | 1441 |

Extracted this area: `page_surface.gd`, `bazaar_costs.gd`, `bazaar_surface.gd`, `bazaar_catalogue.gd`,
`bazaar_bench.gd`, `bazaar_pack.gd`, `bazaar_works.gd`.

## Area 3.1 — check_material_grammar was photographing a flicker

`a499e06`, pushed, sweep green (**109 PASS / 0 FAIL / 0 SKIP**, `HARNESS_EXIT=4`). Layer runtime 18s, was 19s.

The layer went red on one sweep and green on the next with nobody touching the tree. Reproduced: five
repeats on a byte-identical checkout read **78.38, 78.38, 74.32, 77.03, 75.68** against a floor of 75.00.
One red in five, from the instrument.

**Cause.** `world_renderer.gd:4395` gives the lamp's amber pool
`0.17 + 0.030*sin(t*11.0) + 0.020*sin(t*27.0)` on a clock that free-runs on wall-clock delta — a ±29% swing
on the bloom over exactly the band this layer measures. The layer grabbed one frame per placement, so it
sampled one arbitrary phase, and pooled three placements at three arbitrary phases.

**Repair.** Pose the clock, as the fixture already posed the pointer nine lines above — it had removed the
mouse from the measurement and left the clock in it. `_process` is stopped first, because setting the clock
and letting the frame run advances it again before the draw. Zero is the flicker's own mean, not an
arbitrary pose: both sine terms vanish there.

| | runs | min | max | spread | failures |
| --- | --- | --- | --- | --- | --- |
| baseline | 5 | 74.32 | 78.38 | 4.06 | **1** |
| clock posed | 13 | 75.68 | 78.38 | 2.70 | 0 |

**NOT CLOSED.** The statistic is quantised at 1/74 = 1.35 points, so the surviving margin to the floor is
half a window — and the layer's own comment already names spread-against-margin as its real defect. Raising
`n` by pooling more depths is the route the file sanctions and it stays open as the next Area 3 step. The
floor was not touched.

### Two corrections to my own record, both from reading an underpowered comparison

**1. The commit message's claim about `lamp_residual()` is wrong.** It says waiting on the lamp residual
instead of a frame count "made the spread worse". It did not. The comparison was 5 samples against 5:

    clock only, first 5    75.68 77.03 77.03 77.03 77.03      spread 1.35
    clock + lamp wait, 5   75.68 77.03 78.38 78.38 77.03      spread 2.70
    clock only, next 8     78.38 75.68 77.03 77.03 75.68 …    spread 2.70   <- dissolves the difference

The 1.35 was a lucky draw. Both arms sit at 2.70. The supportable statement is that the lamp wait showed
**no measurable improvement** and was reverted for lack of evidence, not that it was harmful. The mechanism
I proposed for the harm — that a variable-length wait re-varies everything else that free-runs — is
plausible and *unevidenced*; it should not be repeated as a finding.

**2. `e9feb96` states the page is 1412 lines; it is 1441.** 1412 was the count before the accessor and
forwarders were appended.

Neither is worth rewriting pushed history for. The standing lesson is narrower and worth more than either:
**a spread is not a number you can read off five samples, and a commit message is a bad place to put a
comparative claim** — it is the one artifact that cannot be corrected in place.

### Area 3.1 continued — raising `n` is REJECTED, and the null rig is why

The open step was to shrink the 1.35-point quantum by pooling more depths. Both honest forms were tried and
both fail, which turns the open step into a recorded decision.

| DEPTHS | n (lit) | outcome |
| --- | --- | --- |
| `[22, 26, 30]` (shipped) | 74 | GRAIN survives its null; ANISO disqualified at 65–73% |
| `[14,18,22,26,30,34,38]` | 196 | **both** cues disqualified — null separates at 63% (ceiling 62%) |
| `[18,22,26,30,34]` | ~140 | **both** disqualified — null at 62% and 68–74% |
| `[20,22,26,30,32]` | 127 | passes, but edge spacing is 2 rows on 16-row slabs |

Widening the band breaks the null: more placements expose more position and lighting asymmetry, and the
earth-vs-earth control correctly refuses to let the layer speak. Narrowing the spacing passes only by
adding placements that are not independent — the file already records that objection against halving the
stride, and it applies unchanged here.

> **The sample size is not free to raise, because the rig is only null-clean over a narrow band of depths.**

Also measured, and it sharpens what this layer is: **ANISO is disqualified in all 8 runs** (65–73% against a
62% ceiling), so the verdict rests on GRAIN alone with no redundancy. That is a documented design state, not
a discovery — `check_material_grammar.gd:150-158` already records it, along with the reason (direction is
not reaching the frame because the seams are drawn multiplicatively). Two hypotheses of mine were wrong and
are recorded so they are not retried: the torch line **is** mirror-symmetric (odd offsets −19…+19), and
anisotropy **is** mirror-invariant (`gh`/`gv` are `absf` sums, so the null's mirror cannot flip it).

Net for 3.1: the flicker was real and is fixed; the margin remains half a window and now has a documented
reason why the obvious remedy does not work. Any future attempt has to widen the null-clean band first.

## Area 3.2 — the stand-down ledger, audited; and a new flaky layer found while auditing it

`24f6853`, pushed, sweep green.

### The verdict was advising the wrong edit

Six sweeps this session resolved the same way: 5 ASSERTED, 1 out-of-reach. Under them the verdict printed
*"ASSERTED means the debt is paid on this machine and the row can be deleted."* The plan was to act on it —
deleting the five would turn `HARNESS_EXIT=4` into a true full sweep. Reading the ledger first overturned
that outright.

| row | resolves | deletable? |
| --- | --- | --- |
| `prose.wide-word-list` | ASSERTED | **No** — the list is held out of the repo on purpose; the row is what stops a fresh clone reading as a pass |
| `save-durability.failed-backup` | ASSERTED | **No** — never fires on macOS because the platform refuses the forcing write |
| `ceremony.words-vs-sky-arm` | ASSERTED | **No** — a control arm, stood down when the arm cannot be measured |
| `grapple.gr03-single-frame-bow` | ASSERTED | ledger says PROBABLY MISFILED — only reachable beside a red |
| `bindings.file-order-control` | ASSERTED | ledger says MISLABELLED — the condition is deterministic per engine build, not environmental |

> **An `env` row resolves ASSERTED on the machines that can reach the assertion. Several exist for the
> machines that cannot.** ASSERTED is the state where the row is *least* informative, not the state that
> retires it.

The line now says what the state means and sends the reader to the row. The two rows the ledger itself
flags — one misfiled, one mislabelled — are left as they are: both say "until somebody decides what it
should be", and reclassifying a row changes what the gate enforces.

### FILED: `check_machine_identity` is flaky under sweep contention

Surfaced on the sweep that verified the change above. Not attributable to it — that commit alters printed
text only.

| where | tightest pair | verdict |
| --- | --- | --- |
| standalone ×5 | Iron Forge/Forge, 0.006 (family-exempt) | pass ×5 |
| full sweep, before | Iron Forge/Forge, 0.005 | pass |
| full sweep, failing | **Pump/Splitter, 0.020** | FAIL — Plate Press/Forge 0.025, Forge/Splitter 0.023 |
| full sweep, after | Iron Forge/Forge, 0.005 | pass |

The tell is not that a number moved. **The distance matrix rearranged**: the forge pair that is tightest in
every other run is not tightest in the failing one, while three unrelated non-family pairs collapsed to the
bound. A shifted reading is noise; a re-ordered matrix means the subjects were photographed in different
states.

Suspected mechanism, and it is the one just fixed next door in 3.1: `SHOW_FRAMES = 12` gives a newly placed
machine twelve *frames* before the shutter, and machine glyphs animate on the renderer's free-running
`_anim_time`. Under a parallel sweep, frames and wall-clock come apart, so each machine is captured at a
different point of its appearance. Repair is the same shape — pose the clock, stop `_process`, and wait on
an observable rather than a frame count — and it is the next Area 3 step.

Classification: **instrument defect, pre-existing, non-attributable.** No bound touched, nothing converted
to a skip.

## Area 3.3 — the same clock, the second layer

`e777dcc`, pushed, sweep green. `check_machine_identity` now poses `_anim_time` for every capture, subjects
and baseline alike, with `_process` stopped first — the repair 3.1 took, applied to the layer 3.2 found.

The still-frame noise control keeps its ability to fail (3.9, 4.0, 11.4 levels across runs), so the pose has
not made it vacuous. Inside the sweep since, the tightest pair reads Iron Forge/Forge 0.009 — the pair that
is tightest in every healthy run — where the failing sweep read Pump/Splitter 0.020.

**NOT PROVEN FIXED.** The flake is roughly one sweep in eight and one green sweep cannot settle that. What is
established is the mechanism and that the ordering held under contention once. Confirmation is accumulated
sweeps, not argument.

### The generalisation worth keeping

Two layers, found independently, same defect:

> **A fixture that poses some of its nondeterminism and not the rest is still nondeterministic — it just
> fails less often, which is harder to diagnose.**

`check_material_grammar` posed the pointer and left the clock. `check_machine_identity` counted frames
against a clock that runs on wall time. Both read pixels from animated draw code. The screen for the rest of
the suite: **which layers read pixels, and which of those pose `_anim_time`?** That is the next sweep of
Area 3 and it is a grep, not an investigation.

## Area 3.4 — CI has been red for 20+ commits, and I made one of its two reds

`00ec990`, pushed: a revert.

### The standing state, which the programme had not recorded

CI is red and has been for at least 20 commits, spanning earlier sessions. Three jobs; the headless and
authorship jobs pass, and *the layers that need a surface (xvfb + software Vulkan)* fails. Two causes:

- `check_grapple_reads` — 2 failures every run, the SAG_CAP saturation the stand-down ledger already
  describes: readings of 0.4624 and 0.4634 against rims of 0.4650 and 0.4656. The ledger's own note calls
  this **PROBABLY MISFILED**, on the grounds that instrument saturation is a spoiled sample rather than a
  defect in the subject. Not touched — it cannot be reproduced on this box, and changing a FAIL to a VOID
  from remote logs alone is the edit that most needs local evidence.
- `check_material_grammar` — **mine**, and new.

### I introduced a CI regression and it took a before/after to see it

    CI, four runs before the clock pose     check_material_grammar  PASS  (42s, 49s, …)
    CI, the run carrying the clock pose     FAIL — 72.97% against the 75.00% floor
    this box, thirteen runs with the pose   75.68 – 78.38, no failures

The pose value was justified by one term and applied to all of them. `a499e06`'s message states that zero
"is the flicker's own mean" because both sine terms vanish there — true of the flicker, false of the clock.
The same `_anim_time` drives sawtooths, `fmod(t, 1.6)` and the per-cell phase spread, and zero is the
*start* of those cycles, an extreme.

> **Posing a clock poses every term hanging off it. A pose value justified by one term is not justified.**

On this box that extreme sits at or above the mean, so the layer looked fixed. On software Vulkan it sits
below the floor, every run.

Reverted. The diagnosis survives — the layer really does photograph one arbitrary phase of an animated lamp,
and that really is its run-to-run spread. What does not survive is freezing the clock at a single point. The
remedy that can hold on both boxes is to sample several phases spanning the joint period and average each
window's cue across them: unbiased for every term rather than for the one that was examined. **It will be
verified on CI before it is called a fix.**

### The process failure, which is the part worth keeping

Every local instrument said the change was good: 13 runs, zero failures, a spread cut from 4.06 to 2.70, a
named mechanism, a mutation control. None of that was wrong, and none of it covered the population that
matters. The layer's whole subject is *what the renderer draws*, and there are two renderers.

**Screen, from now on, for any change to a pixel layer: does this alter what is captured, and has it been
seen on the software renderer?** A green sweep on this box is one machine's answer.

`check_machine_identity` took the same pose in `e777dcc` and its CI run is still in flight; if it regressed
the same way it comes out the same way.

### CI after the revert: one cause, not two

Run on `00ec990`: **15 PASS / 1 FAIL of 16**. `check_material_grammar` PASS 49s (my regression gone),
`check_machine_identity` PASS 42s (its pose did **not** regress CI — that mitigation stands). The sole
remaining failure is `check_grapple_reads`.

### DEFERRED: `check_grapple_reads`, with the third attempt designed

The guard is not the bug. `_bow_now` collects cord-coloured pixels in a corridor about the chord and takes
the **99th percentile** of perpendicular offset; the guard then rejects any reading at or above `SAG_CAP`
because at this shot's 49.3° chord a real rope cannot depart it by more than 0.2736. The rejection is
correct — 0.4624 and 0.4634 are saturation, not bows. **Converting that FAIL to a VOID would hide the
defect the programme has already named**, which is that the mask selects cord by hue alone and software
Vulkan renders rock closer to `ROPE_HUE` than hardware does.

The file records two attempts that failed, and their evidence is the design input:

1. *anchor-visibility* — a taut cord had 370 rope-coloured pixels in the corridor and 3 near an anchor.
2. *longest connected run* — the cord breaks into dashes at this tolerance; longest runs spanned 0.16 and
   0.09 of the chord, and both ropes returned NO CORD.

Both establish the same thing: the cord is ~370–470 matching pixels spread along the **whole** chord, and it
is neither anchored-visible nor contiguous. The file's own proposal is to bin by position along the chord,
because a cord occupies nearly every bin and an intruding patch occupies few. Concretely:

- per-bin **maximum** offset over ~24 stations, giving a profile rather than a pixel population;
- require occupancy across most bins, else NO CORD — this is the discriminator the two failed attempts were
  reaching for, and it is a property of the *distribution*, not of any connected component;
- **median-filter the profile** across neighbouring bins before taking its peak, so a single contaminated
  station cannot set the answer, while a real arc — smooth across neighbours — survives.

Not attempted here, deliberately. It replaces the layer's central statistic, and that statistic has bounds
attached; a change that shifts the reported bow could turn a locally-green layer red and put me in the
position of adjusting bounds I must not adjust. It needs its own slice with room to iterate against CI, and
CI is the only place the failure reproduces. Marked DEFERRED with the design recorded, not blocked.

## Area 1 — audited, and it reads as substantially already met

No code change; this is a coverage audit, because the next item in the sequence was Area 1 and the honest
first step was to find out what is actually missing rather than to start building.

| bullet | evidence |
| --- | --- |
| Save isolation and durable save transactions | `check_save_isolation` 27 assertions, `check_save_durability` **107**, both PASS |
| Explicit migration and version semantics | covered — see below |
| No destructive harness fixtures | `save_sentinel` runs every sweep and reports the player's real save byte-identical, absent throughout |
| Honest PASS / FAIL / SKIP behaviour | the stand-down ledger, plus the verdict correction in 3.2 |

`check_save_frontier` adds 12 and `check_saveload` 8. **154 assertions across the four, all green.**

The migration bullet is the one I expected to find hollow, and it is not. `save_game.gd` has `VERSION = 2`,
an `OLDEST_READABLE` floor, a single-step `_migrate` chain, and validation deliberately run *after*
migration rather than before — with the reasoning written down, because supplying a field an older envelope
predates is exactly what a migration branch is for. The tests match:

- a **genuinely v1-shaped** envelope, with `seep_tick` erased rather than merely relabelled, must load, keep
  its world, and migrate the missing field to zero "rather than to garbage";
- `VERSION + 1` must be refused and must leave the sim untouched;
- every version in `[OLDEST_READABLE, VERSION]` must land at `VERSION` after `_migrate` — which is what
  catches a `VERSION` bump shipped without its branch, the failure mode the file names in its own comment;
- `VERSION > OLDEST_READABLE`, so the chain can never be vacuously empty.

That is the shape this programme asks for elsewhere and does not always get: a bound that is derived, a
control that fails, and the error path tested rather than assumed.

**Proposed: Area 1 closes on this evidence.** Recorded as a proposal rather than done unilaterally — the
areas are the programme's spine and closing one is a director call. Nothing here is blocked either way.

## Area 3.5 — the identity red was real, and my first diagnosis of it was backwards

CI failed `check_machine_identity` on `Crusher/Lift` at exactly the bound. Two runs after the clock pose
landed: one PASS, one FAIL, both printing `0.025` against a floor printed as `2.5%`. Four runs before the
pose had all passed. The obvious reading, and the one I wrote down first, was that the pose caused it, by
the same mechanism that had just made me revert the `check_material_grammar` pose: phase zero is where
every `sin(t*k)`, `fmod(t*k,N)` and bare `t*k` angle in the glyph code simultaneously reads zero, so it
looked like the single degenerate point of the cycle.

**A phase sweep refuted that before I acted on it.** Eight poses across the cycle, measured locally:

    t=0.00  0.07  0.19  0.41  0.73  1.13  1.87  3.09
    mean over 190 pairs   0.258 .. 0.260, one excursion to 0.243
    Crusher/Lift          0.0259 0.0259 0.0268 0.0251 0.0421 0.0259 0.0251 0.0255

Flat. Phase zero is not special, and the degeneracy argument was wrong even though it reads well off the
source. The rates share no common period, which is true, and it does not follow that the whole
distribution collapses at their common zero.

### What the free clock was actually doing, paired and alternated

    free-running   0.0391  0.0336  0.0591      spread 0.0255
    posed          0.0281  0.0259  0.0255      spread 0.0026

Every free reading exceeds every posed reading. Not scatter around a true value: **added distance.** The
mask is `|patch - bare| >= 12/255` against a bare stage captured once, and the twenty subjects are
photographed over several seconds. Anything in the background that moved between the bare shutter and a
subject's shutter lands in that subject's mask as material it does not have. The layer had been passing
partly on that, and reverting the pose would have restored it. **Restoring a noisy instrument is lowering
a bound with extra steps** and is refused on the same grounds.

Corollary worth keeping: the layer's still-frame CONTROL diffs two CONSECUTIVE bare frames. That is the
shortest interval in the run, and it was certifying a threshold used across the longest one. It is sound
now only because the pose makes the two intervals the same interval.

### The layer was not measuring what it says it measures

`SILHOUETTE_ONLY` gates the glyph and the light pool. `_draw_machine_io` was called unconditionally, so
the item-tinted port wedges were inside every mask. The Lift spouts UP: it wore a teal chevron in its
crown band that nothing else in the registry had, and the layer was crediting it as shape.

Gating them changed the tight end in the direction that says the old readings were flattering:

    Drill/Lift      0.039    entered the ten-most-alike for the first time
    Drift Rig/Lift  0.043    likewise
    furnace pairs   0.018 -> 0.006, which is what identical profiles should read

### And the art defect underneath, which was independent of both

    lift    BODY + (0.08, 0.00, 0.18, 0.22) + (0.74, 0.00, 0.18, 0.22)
    crush   BODY + (0.08, 0.04, 0.18, 0.18) + (0.41, 0.04, 0.18, 0.18) + (0.74, 0.04, 0.18, 0.18)

The crusher's outer teeth were on the lift's exact x-grid at the lift's exact width. Every other entry in
`MACHINE_PROFILE` carries the measured collision it was authored against; this one carried the sentence
"A CRUSHER HAS TEETH" and no number. Replaced by a four-tooth comb chosen by searching the table for the
crown that maximises the crusher's distance to its NEAREST neighbour, not to the lift specifically.

### Attribution, because two changes landed and only one of them cleared the bound

    ports IN,  old crown    0.025    at the bound
    ports OUT, old crown    0.035    passes, still the tightest non-family pair
    ports IN,  new crown   >0.059
    ports OUT, new crown   >0.045    out of the tight end

The gate is what makes it pass. The crown is what stops it being the closest call in the registry. Saying
"the crusher reshape fixed CI" would have been false, and it is the sentence I would have written if I had
not run the fourth cell.

Shipped as `4b65096`. Sweep 109 PASS / 0 FAIL / 0 SKIP, HARNESS_RESULT=yes, 6 registered stand-downs.

## Area 6 — BLOCKED, and it is the repository rather than the tree

The Area 6 item "public documents expose no internal coordination artifacts" is **satisfied in the
working tree and not satisfied in the published repository.**

`docs/tracelog/` and `docs/handoff/` are untracked now, excluded through `.git/info/exclude` (which is
local, so the exclusion itself is not published either), and every file is intact on disk. `f215f2e`
untracked them and `f215f2e` is an ancestor of `origin/main`. Untracking is not removal:

    docs/tracelog   100 commits in published history
    docs/handoff     43 commits in published history
    19 distinct paths, ~748 KB at peak version, all readable with `git log --all` on a fresh clone

The filenames alone carry it. Nothing in a file scan of the tree can reach any of this, which is the
whole point: **the repository is not its tree.**

**This needs an explicit history rewrite and force-push to a public remote, which is a stop condition
under the standing rules, so it is recorded and not executed.** Two further notes for whoever authorises
it:

- **Do not record this finding in a tracked document.** A shipping file that says "the coordination notes
  were removed from history" is a signpost to go and read them. That is why this paragraph is here, in the
  locally-excluded programme document, rather than in `DECISIONS.md` where the rest of Area 5's errata went.
- The rewrite must be screened by reading the resulting **diff**, not the added-file list, and the commit
  MESSAGES need the same pass as the paths, since 25 pushed messages were already known to carry process
  vocabulary independently of any file.

## Area 1 — CLOSED

Closed on evidence read off the tree and off a green sweep, not off the intake list. Four layers hold it:
`check_saveload`, `check_save_frontier`, `check_save_isolation`, `check_save_durability`.

    check_save_durability   107 assertions      0 stood down    PASS
    check_save_isolation     27                 0               PASS
    check_save_frontier      12                 0               PASS
    check_saveload            8                 0               PASS
                            154 total           0               all PASS

Each intake item, against where it is actually satisfied:

| Item | Evidence |
| --- | --- |
| A version floor exists | `save_game.gd:32` `OLDEST_READABLE = 1` against `VERSION = 2`, and the floor is a named constant rather than a literal at the comparison |
| A migration chain exists | `_migrate` walks single-step branches from the envelope's version upward |
| Validation happens after migration | `_valid_envelope` bounds the version first, then the migrated envelope is re-checked; a chain that stops short is refused rather than accepted |
| Future versions are rejected without mutating the sim | `v > VERSION` fails the range test and returns false before staging; and restore is transactional regardless, staging the whole envelope into a scratch dictionary so the live sim is untouched until the envelope is known good |
| Version-range coverage | the range is `[OLDEST_READABLE, VERSION]` and both ends are exercised; the v1 fixture is a genuinely v1-shaped envelope with `seep_tick` ERASED rather than relabelled, which is the distinction that makes it a migration test instead of a version-string test |
| Durability and isolation | the write encodes to a temp file, reads it back to prove it decodes, copies the slot to `.bak`, and only then renames; `check_save_isolation` holds the separation between a run's slot and a real one |
| Destructive fixture behaviour is guarded | the sweep's `save_sentinel` reports each run that the player's real save is byte-identical, and it reported "absent throughout" on the closing run |
| PASS/FAIL/SKIP explicit | all 154 are PASS with none stood down; `save-durability.failed-backup` is a registered conditional row and it resolved ASSERTED |

**The one thing worth flagging rather than ticking.** The migration chain has exactly one step in it,
v1 to v2. A chain of one is not much of a chain, and the guard that matters, the refusal at
`save_game.gd:168` when the chain does not arrive at `VERSION`, is unreachable today by construction.
It is there for the bump that has not happened yet: raising `VERSION` to 3 without writing the branch
would otherwise load a v2 envelope as if it were v3, silently, because the range gate already said yes.
That is a guard written for a future defect, correctly, and it should be understood as untested-because-
unreachable rather than as verified.

Closing verdict quoted from the sweep of `4b65096`: 109 PASS / 0 FAIL / 0 SKIP of 109,
HARNESS_RESULT=yes, exactly 6 registered stand-downs.

## Area 3.6 — the material-grammar margin: NOT acceptable, and the reason is the denominator

The question was whether the remaining margin is acceptable or needs another design correction. It needs
one. The evidence, thirteen readings across both renderers:

    Metal      78.38  78.38  78.38  77.03  77.03  75.68  75.68  77.03  79.73
    lavapipe   77.03  78.38  77.03  77.03            (and 72.97 from the reverted pose)
    floor      75.00

Those look like a comfortable spread until they are converted into the unit the layer actually counts in.
There are 74 lit windows, so **one window is 1.35 points**, and the readings above are 56, 57, 58 and 59
windows against a floor at 55.5. The worst honest reading clears the bound by HALF A WINDOW while the
observed spread is three windows. A bound with less margin than the measurement's own quantum is not
measuring the grammar, it is measuring where the rounding fell.

### Why n is weaker than 74 suggests, which is the actual defect

`DEPTHS` is described in the file as "three independent placements". They are not independent. A slab is
`HALF_H` = 8 tall, the depths are 4 apart, and `STRIDE` is 2, so each rig samples nine rows and adjacent
rigs share seven of them:

    27 rig-rows drawn from 13 distinct world rows

The slab is repainted for every rig, so a shared row is the same cells wearing the same materials under a
lamp that moved with the rig. That is not a second look at the question; it is the same look, pooled
twice. It also explains the quantisation directly: thirteen readings landing on four values is what a
statistic with far fewer independent samples than its denominator claims looks like.

### The correction, and the confound it nearly shipped as a finding

Sideways is the only axis where replication is real, because `HALF_W` bounds a rig's reach and rigs a
full width apart share no cell, no torch and no lamp. The file already rejects "moving the player", but
that rejection is about moving the BODY off the seam, which unmatches the mirror pairs on lamp distance.
Moving the whole rig is what the depth replication does.

First attempt: widest spacing the grid allows. It read

    offset   0    75.68%   74 lit
    offset +41   61.43%   70 lit
    pooled       67.59%  145 lit     FAIL against the 75.00 floor

and I was one commit from reporting "the structure grammar is not robust across the world". **The
pictures said otherwise.** Dumping the rigs showed the HUD band label on each:

    28 m  SHALE REACH        the body's column
    41 m  THE LONG DARK      one rig-width right

`cy` is `surface_row(cx) + depth`, so a column over a valley puts its rig deeper in absolute terms and in
a different band, with a different tint and a different ambient. Holding depth-below-surface fixed does
not hold depth fixed. The 61.43% was a fact about which band was photographed. A number cannot tell you
what it photographed, and this is the second time today that looking at the image overturned a reading
that was about to become a finding.

The fix is not a tolerance on the surface row, which would be a guess at the thing that matters. It is
`Strata.band_at`, which IS the thing that matters and is the same table that printed those two labels: a
candidate column is admitted only when every depth in `DEPTHS` lands in the same band as it does at the
base column. Nothing to tune and it cannot drift from the bands it protects.

### Where that leaves it, stated plainly

**At the shipped seed the terrain offers no qualifying column.** Base column 49, surface row 20, and all
18 candidates are refused; the nearest sits 3 rows off and still crosses a band at one of the depths. So
the machinery is in, correct, and inert: 74 windows, 16s, behaviour identical to before.

That is not a fix, and it should not be recorded as one. What changed is that the thin n is now a
PRINTED limit with its reason attached rather than a silent property of the rig. The margin remains half
a window, and closing it needs one of:

- a narrower rig, so more of them fit inside one band (`HALF_W` down, more columns, roughly constant
  windows but genuinely independent ones)
- a seed or a location chosen for flat terrain, which makes the layer's result conditional on where it
  stood, and that wants arguing before it is done
- accepting the layer as a coarse gate and saying so in its verdict, rather than implying a precision of
  0.01% from a statistic that moves in steps of 1.35

Not decided here. What IS decided: the margin is not acceptable as it stands, and the layer must not be
read as having 3 points of headroom when it has half a window.

## Area 3.7 — the grapple bow, third and fourth attempts, both still DIAGNOSTIC

The layer still asserts on `pct99` and still reports its saturation. Two candidates now run beside it and
print their readings, which is the arrangement the brief asks for: the saturated result stays visible
until a replacement is proven on both renderers.

### What the profile made possible, and it was there all along

The per-station sketch is what turned this from guessing into reading. On lavapipe:

    taut    . 0 . . . . 0 1 1 1 1 . 0 0 . . 0 8 8 8 0 0 0 0
    slack   3 3 4 4 4 . . 4 4 . . 3 3 3 . . . 8 8 8 8 0 0 0

Digit 8 is SATURATION rather than "high": the sketch scales by the rim and 247 of 248 px prints as 8. So
three to four stations at 71% to 83% of the chord are pinned in both arms, and the slack arm's real
signal, 3s and 4s across the middle against the taut arm's 0s and 1s, was underneath it the whole time.
Which also kills the median-filter-only idea outright: the contaminated block is WIDER than a three-wide
median, so the filter finds a majority of contaminated neighbours and returns contamination.

### Candidate one: reject what the renderer cannot draw. Real, and not enough.

The corridor is `span * SAG_CAP + 24.0`. The 24 exists so a pinned rope can be SEEN to be pinned, which
makes it also a strip nothing is ever drawn into. Taking each station's best IN-BAND offset (rather than
dropping the whole station, since the far end holds both cord and contamination) fired exactly as
designed on CI: 3 over-band stations per arm, and

    0.4638  ->  0.4106   taut
    0.4648  ->  0.4177   slack

and then stopped. The blob straddles the band edge and its inside half is still the largest offset
present. Separation: none.

**The structural reason, which is the part worth keeping.** `_bow_clean` takes the PEAK of the surviving
profile, and a peak is a maximum: one contaminated station owns it regardless of what the other
twenty-three say. No amount of rejection repairs an estimator decided by its worst member.

### Candidate two: the cord's own shape turns every station into a witness

`_draw_cord` draws the hang as `sin(t * PI) * sag`. So each station independently estimates the SAME
scalar, and the MEDIAN of those estimates tolerates a minority of bad stations exactly where a maximum
cannot. Half the stroke width comes off first because the mask finds the cord's outer edge, and `CORD_W`
is now named in the renderer and read from there instead of 4.5 living in two files.

Conditioning sets the window, not taste: near either end `sin(t * PI)` goes to zero and multiplies the
half-width and the noise without limit. At `sin >= 0.70`, the central half, amplification is at most
1.43x.

**PRE-REGISTERED.** Working the expected values off the CI profile before running anything, the
prediction for lavapipe is **taut about 0.073 against slack about 0.216**. Local, two runs:

    taut    0.0503  0.0501
    slack   0.1838  0.1838      3.7x apart, stable to four decimals

Lower than the peak on both arms, which is what a median of a hang's stations should be. The CI reading
is the test, and it is a real test because the number to beat was written down first.

### Not done, and what "done" requires

Neither candidate asserts anything yet. Promotion needs the lavapipe reading to separate the arms, and
then a floor and a ratio argued from the drawn geometry rather than from the readings they are meant to
judge. If lavapipe still refuses to separate, the honest outcome is that this layer cannot judge a hang
on a software renderer, which is a stand-down with a reason and not a lowered bound.

## Area 3.7 continued — the sag-median holds on both renderers, and the incumbent's PASS was a coincidence

### The pre-registered prediction, scored honestly

I wrote down taut about 0.073 against slack about 0.216 for lavapipe before running it. Actual:

    lavapipe   taut 0.0501   slack 0.1838
    local      taut 0.0501   slack 0.1838

**The direction was right and the numbers were not.** The prediction came off digit-bin midpoints in the
printed sketch, which is a coarse instrument to predict with, and it landed about 40% high on one arm and
18% high on the other. What the prediction was FOR still worked: it committed me to "these separate"
before the data arrived, so the separation is a confirmation rather than a reading-off. But the numeric
part should not be cited as a hit.

**The result that matters is the one I did not predict**: the two renderers agree to FOUR DECIMAL PLACES
on both arms, where `pct99` reads 0.0536/0.2372 locally and 0.4624/0.4634 on lavapipe. A statistic that
gives the same answer on a hardware GPU and a software rasterizer is measuring the drawing rather than
the renderer.

Why it works is not luck: the contamination lives at the two chord ends, which is exactly where dividing
by `sin(t * PI)` is ill-conditioned and where the window already excludes it. Two reasons converging on
the same window is the reason to trust it.

### The incumbent's local PASS is not earned, and this is the real finding

Printing the renderer's own prediction beside the reading turned the whole thing over. `_at_slack(0.55)`
CLAMPS, so the rig never reached 0.55; the renderer drew at slack 0.269:

    slack   renderer drew 0.3718 of the chord -> 0.2422 perpendicular    pct99 read 0.2366
    taut    renderer drew 0.0056             -> 0.0037                   pct99 read 0.0536

The slack arm agrees to 97.7%, which looks like a vindication of `pct99` on hardware. It is not.
**The largest offset sits at station 4 of 24, t=0.19, and the hang's apex is at t=0.50 by construction.**
The perpendicular departure of the drawn cord is `sin(t * PI) * sag * |cos(chord angle)|`, which I
derived rather than assumed, and at t=0.19 the cord can reach 71px. The mask found 125px there.

So `pct99` returns the right number from the wrong place. On hardware that coincidence produces a green
assertion; on lavapipe the same contamination is larger and saturates instead. **The layer has never
measured this rope on either renderer.** That is a quiet green that has been shipping, and it is a
better finding than the saturation it was hiding behind.

The taut arm makes it unarguable without any coincidence to explain away: 0.0536 measured against 0.0037
drawn, 14x, on a cord the renderer bows by two pixels.

### Two candidate causes, both refused by their own counts

- **The miner.** `_body_mask` is applied at four other sites in this layer and never to the bow, and the
  miner stands at the hand end wearing rope-coloured pixels. Applying it discarded **0 pixels**. Not it.
- **A wrapped rope.** `_draw_cord(at, pivot, 0.0)` puts straight rope-coloured segments in the frame for
  every pivot, and `hitch()` is the LAST pivot, so earlier spans belong to no chord this scan knows.
  The rig carries **0 pivots**. Not it.

Both guards are kept and print only when they fire. Each cost one run and each would otherwise have been
written up as a fix; the counts are what stopped that, and they are the cheap version of the positive
control this repository keeps relearning it needs.

What remains is the cause the layer's own history already names: lamp-lit rock inside `ROPE_TOL` of
`ROPE_HUE`. Colour cannot separate them.

### Where it stands, and what promotion now requires

Still DIAGNOSTIC. The layer asserts on `pct99` and still reports its saturation.

The sag-median satisfies both existing bounds without either being touched: 0.1838 against a `BOW_FLOOR`
of 0.15, and a ratio of 3.67 against a `TENSION_MARGIN` of 3.0. That is tempting and it is not sufficient,
because its absolute value is still not a calibrated sag: the taut arm reads 0.0501 where 0.0037 was
drawn. A discriminator that separates two arms reliably is not the same thing as a measurement of how far
a rope hangs, and GR-03's floor is a claim of the second kind.

**The next instrument is now specified rather than guessed, and colour is not part of it.** The apex
location is the discriminator: fit the per-station profile to `sin(t * PI)`, report the fitted `sag` AND
the goodness of fit, and refuse to answer when the shape is not a hang. That test rejects rock at any
hue, and it is checkable against `rope_sag` at run time rather than against a calibrated constant.


### The agreement metric, and why BOTH arms are unmeasured

Measured rather than estimated, on hardware:

    taut    sag-median 0.0501    100% of well-conditioned stations agree with it
    slack   sag-median 0.1838     50%

The taut arm's 100% is the finding, not the reassurance. Every station agrees on roughly 26 pixels of
offset, uniformly along the chord, on a cord the renderer bows by TWO. So the taut reading is a
consistent 26px band of rope-coloured pixels that has nothing to do with sag, and it is exactly the "flat
26 pixels regardless" that this file's own history records as a property of an old ROPE. It was never the
rope. It is the mask, and it has outlived two rope implementations.

So agreement alone is not the test either, and that is worth stating plainly because I nearly shipped it
as one:

> **A hang must satisfy BOTH: its stations must agree with each other, AND their common value must match
> what `rope_sag` says was drawn.** Agreement without the value is a uniform artefact. The value without
> agreement is `pct99`, which found 125px at t=0.19 where the cord can reach 71.

Against that pair of requirements:

    taut    agreement 100%   value 0.0501 against 0.0037 drawn    REJECT on value
    slack   agreement  50%   value 0.1838 against 0.2422 drawn    REJECT on shape

**Neither arm is a measurement on either renderer.** The layer's local green and its CI red are the same
defect seen at two contamination levels.

### Deliberately NOT shipped tonight

Wiring that pair of tests into `_bow_measured` would be correct and would turn the local sweep red, from
109 PASS to 108 PASS / 1 FAIL, by withdrawing an assertion that has been passing on a coincidence. I am
not doing it in this session, and the reason is not squeamishness about a red:

- the agreement band (0.25) and the value tolerance have not been derived, only chosen, and a rejection
  rule whose constants are picked is the thing this programme spent the evening removing elsewhere
- it has been read on hardware but the agreement figure has not yet been read on lavapipe
- turning the suite red is a decision that should be taken with the day's other reds visible, not at the
  end of a long session on the strength of one run

What IS shipped is the evidence, printed every run on both renderers, with the layer's behaviour
unchanged. The next slice has a specified job: derive the two tolerances, read them on lavapipe, then let
`_bow_measured` refuse both arms and take the red.

### The shaped ceiling: the same refusal, asked per station, with no chosen number

The lavapipe read closed the last gap in the evidence, and it is a clean one: **the sag-median and its
agreement figure are IDENTICAL on both renderers.**

    hardware   taut 0.0501 / 100% agree     slack 0.1838 / 50% agree
    lavapipe   taut 0.0501 / 100% agree     slack 0.1838 / 50% agree

while the contamination itself is renderer-dependent and moves:

    hardware   largest offset 125 px at t=0.19   the hand end
    lavapipe   largest offset 223 px at t=0.81   the piton end

Always at an END, which is why the central window is immune to it and why the two renderers agree.

That observation gives a strictly better rejection than the flat band, and it costs no new constant. The
flat band asked "could the cord ever be this far out". The answer available is "could the cord be this
far out HERE":

    ceiling(t) = sin(t * PI) * SAG_CAP * span * |cos(chord angle)|  +  half a stroke

Every term read off the renderer: the `sin` from `_draw_cord`, `SAG_CAP` and `CORD_W` from the same file,
the `|cos|` because the bow is applied in Y while this mask measures perpendicular distance. It is the
same physical refusal, asked at the right resolution, and it bites hardest exactly where a flat band is
most generous. Verified against all four known cases before it was written:

    lavapipe taut   t=0.81   223 px  vs ceiling  86     flat band allowed 224
    lavapipe slack  t=0.81   221 px  vs          83
    hardware slack  t=0.19   125 px  vs          83
    hardware slack  t=0.52    95 px  vs         146     kept, and this one is the cord

Effect on hardware, the slack arm:

    profile   33444..44..333...1111000  ->  .......44..333...1111000    6 stations refused
    clean     0.2366 -> 0.1866, now within 0.003 of the sag-median
    argmax    125 px at t=0.19 -> 122 px at t=0.31

### What is still wrong, stated so the next slice starts from it

The layer still cannot measure this hang, and the remaining gap is narrower and better defined:

- **The peak is at t=0.31, not 0.50.** Endpoint mismatch is RULED OUT: `_draw_grapple` uses
  `player.hand()` and so does this layer, and `hitch()` is the last pivot which is what `_draw_cord`
  receives. So the shape disagreement is real rather than an indexing error.
- **Mid-chord undershoots.** At t=0.52 the cord should read 127 px and the mask finds about 95.
- **Agreement is still 50%**, so the two populations are still there, now both under the cap curve.

Two untested leads, both cheap: `ROPE_HUE` may match the 2px core rather than the 4.5px under-stroke, in
which case the half-width term is 1.0 and not 2.25; and `g.slack()` is read at PRINT time, a frame after
the shutter, so the predicted value may describe a rope that had moved. The second is this repository's
own recurring fault, a posed field read at the wrong moment, and it should be checked first.

## Area 3.6 CORRECTION — the material-grammar layer FAILED, one sweep after I said it never had

The entry above says "the worst honest reading clears the bound by HALF A WINDOW". That is now wrong in
the direction that matters. The next full sweep read:

    FAIL: dirt and stone are tellable apart 74.32% of the time over 74 lit windows (floor 75.00%)

74.32% of 74 is **55 windows against a floor of 55.5**. Fourteen readings now span 55, 56, 57, 58 and 59
windows, and the floor sits between the first two. The layer does not have a thin margin; it **straddles
its own floor**, and the only reason that took this long to see is that a half-window margin fails about
one run in fourteen.

**Classified: known thin-margin flake. Not caused by the change in the same commit.** The `[mg]` line in
the failing run reads `rig offsets [0]`, so the band-matched replication admitted no extra column and the
layer ran exactly as it did before it was touched. The other change in flight was in a different file.

**The bound is not being moved and the layer is not being skipped.** What this is, is the prediction
landing: the entry above argued from quantisation that the margin could not be trusted, and the very next
sweep produced the failure that argument implies. That sequence is worth more than the argument alone
was, because the failure was pre-registered by it rather than explained after it.

It also settles the disposition question. This is no longer "a margin that ought to be improved
eventually". It is a layer that reports a coin-flip about one run in fourteen, and it needs the
denominator fixed before its verdict means anything. The three options recorded above stand, and the
first of them, a narrower rig so more of them fit inside one band, is now the one to do rather than to
consider.

### Both leads closed, one was a real bug, neither was the cause

**`ROPE_HUE` was a hand-copied literal of `WorldRenderer.ROPE_CORE`** -- the same three floats in two
files with nothing relating them, which is the exact class `check_shared_constants` exists for and which
this layer had been carrying the whole time. A repaint of the rope would have left the mask hunting the
old colour and reporting a rope that had vanished. Now derived.

It also settles which stroke to subtract. `ROPE_SHADE` is 0.888 away from `ROPE_CORE` and `ROPE_TOL` is
0.20, so the mask sees the FIBRE and never the 4.5px under-stroke beneath it. The half-width term was
`CORD_W * 0.5` = 2.25 and should be `CORD_CORE_W * 0.5` = 1.0. Effect, as expected, small:

    taut   sag-median 0.0501 -> 0.0525      slack 0.1838 -> 0.1862

**The slack-timing lead is dead by inspection**, and it is worth writing down why rather than leaving it
listed. The pixel loop between `get_image()` and the print contains no awaits, so no frame advances
between them: the slack read and the shutter are the same frame. This repository's recurring fault did
not apply here, and I checked instead of assuming it did in either direction.

### What is left, posed precisely

Agreement is still 50% on the slack arm and the peak is still at t=0.31. After the shaped ceiling the
profile reads

    .......44..333...1111000

which decreases from station 8 to station 11 and is empty at 9, 10, 14, 15 and 16. A cord should rise to
station 11 or 12 and fall symmetrically. And the obvious explanation runs the wrong way: near the apex
the offset is stationary, so a bin there should hold pixels at nearly the apex value, while a bin away
from the apex spans a RANGE and its maximum sits at the bin edge nearer the apex, which is LESS. Bins
away from the middle should therefore read LOW, and these read high.

So the shape disagreement is not binning, not endpoints, not the stroke width and not the slack read. The
mask is finding something at stations 7 and 8 that outreaches the cord's own apex, on hardware, under the
per-station physical ceiling. That is the next thing to photograph rather than to reason about -- the
same move that overturned the depth-band reading and the machine-identity diagnosis today.

## Area 3.7 CORRECTION — the shaped ceiling was cutting the rope, and the photograph is what caught it

**I shipped a wrong instrument in `9cb5d10` and this retracts it.** The per-station ceiling was presented
as "the same refusal asked at the right resolution, with no chosen number". The no-chosen-number part was
true. The resolution part was wrong, and it made the measurement worse.

### The mistake, exactly

The ceiling read `sin(along / span * PI) * SAG_CAP * span * |cos|`, which treats `along` as the cord's
parameter t. It is not. `_draw_cord` displaces each point by `sin(t * PI) * sag` **in Y**, and Y has a
component along any chord that is not horizontal:

    along(t) = t * span + sin(t * PI) * sag * axis.y

On this rig `axis.y` is -0.758, so the apex at t=0.50 arrives at along/span = 0.22. The station axis was
never the cord's parameter. Solving the mapping for the observed argmax gives t=0.585 and a predicted
offset of 124 px against 122 measured, which closes it to within two pixels.

**So the "contamination at t=0.19" was the cord's own apex**, and the shaped ceiling refused every point
from t=0.30 to t=0.585 -- the entire middle of the rope. The tell was in the number I published as an
improvement: `clean` moved 0.2366 -> 0.1866 while the renderer's own figure was 0.2422. **A tighter bound
that moves the answer away from the truth is not tighter**, and I read that drop as contamination being
removed because I was expecting contamination to be removed.

Everything downstream of the t-mapping goes with it. `_bow_sag_median` and `_bow_agree` are WITHDRAWN and
their numbers must not be quoted. Their four-decimal agreement across two renderers read as robustness
and was two runs making one systematic error identically -- a reproducibility that measured the mistake,
not the rope. That is the sharpest version of this failure class I have hit: **agreement between
instruments is not evidence when they share the defect.**

### What is true instead, and it is better

No station is needed. Wherever the apex lands in `along`, the largest perpendicular offset anywhere on
the cord is `sag * |cos(chord angle)|`. Divide the largest offset by that cosine and the drawn sag comes
back as a share of the chord, which is exactly what `rope_sag` reports:

    slack   recovered 0.3631   renderer drew 0.3718     97.7%
    taut    recovered 0.0809   renderer drew 0.0056     14x

**The slack arm is now a measurement**, checkable against the renderer every run rather than against a
calibrated constant. The taut arm is not: its 29 px of rope-coloured pixels are not a cord that bows two.

And the ceiling keeps the one part of the shaped version that was right, the cosine the ORIGINAL flat
band was missing: `SAG_CAP * span * |cos| + half a fibre` is 145 px here, against the 221 the uncorrected
band allowed. Flat, because the along-mapping makes a per-station bound unsafe. It refuses the lavapipe
contamination at 221 and 223 px and keeps the apex at 125.

### How it was caught, which is the part to keep

By looking at the capture. I had written "the next thing to photograph rather than to reason about", did
it, and the picture showed a rope whose deepest point sits far from the middle of its chord. The
arithmetic followed in four lines. Three times today the image overturned a number that was about to
become a finding: the depth-band confound, the machine-identity diagnosis, and this. The numbers were all
internally consistent each time.


## Area 3.7 CLOSED — the bow shipped, and the number came from the renderer's own field

`_bow_now` returned `pct99`, a 99th percentile over every rope-coloured pixel in the corridor. That
population contains lamp-lit rock, and on lavapipe it pinned: **0.4624 taut against 0.4634 slack** — two
readings agreeing to three decimals about a rope that is either hanging or not.

It now returns the peak of the per-station profile with the physical ceiling applied, divided by
`|cos(chord angle)|`. The division is the part worth keeping. `rope_sag` is a VERTICAL hang applied in Y;
the mask measures PERPENDICULAR departure; the two differ by exactly that cosine. The saturation guard had
said so in prose since it was written, with nothing acting on it.

| | recovered | `rope_sag` says |
| --- | --- | --- |
| slack | 0.3631 | 0.3718 (97.7%) |
| taut | 0.0809 | 0.0056 |

Identical on hardware and lavapipe. **No constant moved** — `BOW_FLOOR` stays 0.15, `SAG_CAP` untouched;
the correction put the measurement on the scale those constants were already written for.

The taut arm is still contaminated, and that does not weaken the comparison it feeds: junk can only push a
reading up, so an inflated taut makes the 4.5x slack-to-taut ratio a LOWER bound against a 3.0x margin.
`pct99` stays in the diagnostic line, so the saturated reading is still visible beside the one that
replaced it rather than deleted with it.

**Verified against history, not asserted:** the display job read 15 PASS / 1 FAIL on `e045962`, `6db6994`,
`53cdee4` and `ef28dd4`, and 16 PASS / 0 FAIL on `32e7a45`.

## Area 3.6 CLOSED — the replication was inert for its whole life, and the grammar does not clear its floor

The margin was decided against, and the fix was to widen the denominator. Doing so found two defects, and
then the number they had been hiding.

**The band admission test was conjoined across `DEPTHS`.** A column was admitted only if depths 22, 26 AND
30 all landed in the same band there as at the base column. That is stronger than the rationale it was
written for, and stronger in a direction that guards nothing — the depths are not in the same band as each
other. At base surface row 20, depth 22 is row 42 (THE CLAYBAND) while 26 and 30 are rows 46 and 50 (SHALE
REACH). Each depth alone admits 14–16 surface rows; the intersection is four, and the nearest column the
terrain offered sat three rows outside it:

    depth 22   surface rows  8..21   14 admissible
    depth 26   surface rows 18..33   16
    depth 30   surface rows 14..29   16
    all three  surface rows 18..21    4      <- and the terrain's nearest candidate was 3 rows out

So the layer printed `rig offsets [0] -- 18 candidate(s) refused` on every run it ever made. Thirty lines
of comment describing sideways replication, and it had never once placed a second rig.

**Unstacking it exposed the second defect immediately.** `off` walks outward one column at a time and each
candidate was checked only against the BASE, so depth 30 accepted offsets `[0, 48, 49]` — two rigs
overlapping in 40 of their 41 columns, pooled as independent evidence. Candidates are now rejected against
every offset already taken. This was latent precisely because the first defect kept the set at one element.

**The number.** Denominator 74 windows at one column → 116 across five placements; reading 74.32–79% →
**70.69%**, the same figure on hardware and on lavapipe. It did not drift toward the floor, it fell
through it. Nothing about the terrain changed: the old greens were a statement about one column of rock,
and the flake that put this layer on the list — 55 windows one run, 56 the next, against a floor at 55.5 —
was the only symptom that ever reached the surface.

**`READ_FLOOR` is not moved.** The layer FAILS and the failure is the finding.

### The per-placement split, which is why the pooled figure is the only one to read

`[mg-rig]` now prints each placement. On the NULL rig — identical earth either side of the seam — GRAIN reads:

    57.1%   63.2%   85.7%   52.2%   61.9%

A placement separating rock from itself at 85.7% is a demonstration that one placement's AUC carries no
verdict at this n, whatever it says. The pooled null falls back under its ceiling because those deviations
point in different directions and cancel. That is what makes pooling load-bearing here rather than merely
convenient — and it is why the TREAT spread (52.4–90.5%) must not be read as a depth trend.

## Area 6 — the CI badge: an unsatisfiable gate, and the check that exempted the one job needing it

**The workflow had not been green in its last 40 runs** (31 failure, 9 cancelled, 0 success). Almost none
of that was a tree problem.

`SF_STRICT` makes any stand-down a non-zero exit, and two layers the display job selects carry registered
`always` rows — `grapple.gr05-preview-share` and `ceremony.words-vs-sky` — that stand down on every run on
every machine. The step could not return 0 on any tree that has ever existed. **`32e7a45` is the proof
rather than the argument: 16 PASS / 0 FAIL / 0 SKIP of 16, and the job failed anyway.**

`tools/harness_verdict.sh` already names the reachable target in those words — *"EXIT 4, WITH EXACTLY THESE
STAND-DOWNS AND NO OTHERS"* — and never got to apply it here, because its ledger check exempts anything
printing `SUBSET RUN` and the display job selects by `SF_GL_ONLY`. **The gate that could never pass and the
check that never ran were the same job.**

The exemption is removed rather than narrowed. Its stated reason held before `sd_absent` existed; that
function now names and holds out registered layers which did not run in this job, so the comparison is
already restricted to the layers that reported. Both directions were checked on a three-layer subset
before removing it — clean it reports `exactly the registered ones, 2 id(s)`; with one invented
`SKIP: [grapple.invented-row]` appended it reports NOT REGISTERED and exits 1.

The run step tolerates exit 4 and only 4. **Exit 1 still fails it, and 1 masks 4, so a FAIL cannot hide in
the tolerance** — the only way this could have become a licence.

| local simulation | result |
| --- | --- |
| `SF_GL_ONLY` + `SF_STRICT`, current tree | reproduces CI exactly, mg failing at the same 70.69%; ledger now checked: `exactly the registered ones, 3 id(s)` |
| same, with the one real red excluded | exit 4, ledger clean, **step exits 0 → job green** |

Net effect is a STRICTER workflow: the display job gained a ledger check it never had, and lost a condition
no tree could satisfy. It is still red today on the material-grammar red, which is a real finding and the
right reason for a red badge.


## Area 4 — profiled first, and the profile disagreed with the harness's own attribution

### The cliff, and it was not where the layer said

`check_frametime`'s DIG phase reads p99 **30.5ms** against a p50 of 8.32, reproducing to ±0.26ms over six
runs — a deterministic ~3.7-frame stall, not jitter. The layer's header attributes DIG to *"the
fine-terrain REGION rebake; the known hot path (#102)"*. Timing every bake on the dig path:

| | measured | |
| --- | --- | --- |
| fine region rebake | 3.56ms | the accused |
| coarse chunk bake | <2.00ms | never reached the print threshold |
| `bake_pending` | 5.86ms | over its own 4ms budget by one row, as documented |
| veil full rebake | 15.52ms | **twice, both at boot**, before any phase ran |
| `main._process` | **18.85ms** | and here it is |

The veil is worth naming because it nearly became the answer: two events at 15.5ms, and p99 over 200
frames is the top two frames. It fit perfectly and it was wrong — both events sat at log lines 6 and 8,
before the phases began at line 115. Checking where they landed rather than that they existed is the only
reason it did not get written up.

Inside `main._process` → `_update_bazaars` → `FactorySim.find_bazaars` → a full-grid rescan at **16.4ms**,
twelve of them against eleven mines.

### Why it was invisible

`_rescan_bazaars` walks ~16,000 origins calling `is_bazaar_at` then `bazaar_gap_at`. The first fails on its
opening read almost everywhere; the second walks the whole 4×3 window before returning nothing, on every
origin. The cache made this per-dig instead of per-frame, and the docstring recorded that as
*"O(1) amortized between digs"* — true between digs, and the cost it hides is the one a player meets,
because while mining most frames follow a dig. **A complexity claim measured on the wrong axis.**

### The reject is exact, not a heuristic

A bazaar needs eight cells in wood; a ruin is that frame with exactly one missing. So among any TWO of the
eight, at least one is wood in both cases. Two dictionary reads on the top-beam corners reject an origin
outright.

Verified against brute force rather than argued — the pre-reject scan inlined as a control:

- 40 rounds of random digging and wood-dropping: **0 mismatches** on both caches
- the gap placed at each of the eight frame cells in turn, including the two corners the reject samples:
  **9 of 9 identical**, complete frame found 1/1, all ruin variants found **8/8**

| | before | after |
| --- | --- | --- |
| DIG p99 | 30.73 30.81 30.72 30.43 30.29 30.59 | 16.81 16.64 17.99 |
| DIG worst | 31.4 … 34.1 | 17.7 … 20.8 |
| DIG mean | 8.83–9.02ms (112 fps) | 8.54–8.56ms (117 fps) |

**A 44% cut in the worst dig frame.** The ~17ms residual is one missed deadline rather than two and is not
claimed as finished.

### The absolute 120fps budget: run for the first time, and it is a false positive

`SF_PERF_HOST` gates the only 8.33ms assertion in the project and has been set nowhere for the whole life
of the code. Setting it (`mac16,8`) failed all four phases — including **RUN at p95 9.46ms with 0.0% of
frames missing their slot and a mean of 8.31ms**. That is a phase comfortably holding 120fps being marked
as under it.

The cause is in the layer's own header: under vsync a frame lands on 1.0x or 2.0x the interval and nothing
between, so **p95 measures the pacing, not the work**. The layer already computes the right quantity — the
share of frames past 1.5x the interval — and only prints it.

**Not promoted, deliberately.** Turning it into the assertion needs a drop-rate bound chosen from a
distribution nobody has measured, which is a decision rather than a cleanup. The registry row now carries
the demonstrated false positive instead of only "arbitrary hardware", so the reason the gate is off is the
real one.


### The residual, measured rather than assumed finished

Re-profiled after the fix: `main._process` maxes at **5.39ms**, down from 18.85ms, and `_update_bazaars`
is still the largest thing inside it. The rescan now costs ~4.5ms because the two-read reject still
**visits all ~16,000 origins** — 32,000 dictionary reads is simply what that costs in GDScript.

Removing the walk entirely needs an index of wood cells, and that is **blocked by a real coupling rather
than by effort**: `solid` is mutated by direct dictionary assignment (`sim.solid[c] = &"wood"` in the
generator and in test fixtures), so there is no choke point at which an index could be maintained
soundly. An index that any caller can silently invalidate is worse than the walk.

That makes it an Area 4 *hidden coupling* item rather than a perf task: give `solid` a mutator, then the
index becomes safe and the dig frame loses another ~4.5ms.

**Sized, and deliberately not attempted.** There are **41 direct mutation sites** — 18 in game code
(`factory_sim.gd` 14, `flora.gd` 2, `objectives.gd` 1, `world_renderer.gd` 1) and 23 in fixtures and
tools. A fixture that writes `solid` directly and bypasses the mutator leaves the index stale, and a stale
index does not fail loudly: it makes a shop appear or vanish. That is a correctness risk in gameplay logic
against a ~4.5ms win on a subset of frames, which is the wrong trade to make in one sitting.

The narrower version is worth noting for whoever picks this up: all nine `_bazaars_dirty = true` sites live
in `factory_sim.gd` alone, so accumulating changed CELLS beside that flag — and falling back to the full
walk on bulk paths like `load_world` — gets most of the win inside one file. That is the shape to try
first, with the brute-force control from this section reused as the check.


## Director decisions, 2026-08-22

Two governance calls, recorded here because both were previously carried as blockers I could not resolve.

**1. Material grammar — the floor stays, the grammar moves.** The ~70.7% reading is accepted as real, and
the measurement is accepted as having enough independent placements to matter. `READ_FLOOR` is **not** to
be lowered and **not** to be re-derived from a different sibling layer. The remedy is a visual/material
pass on the mechanism this layer already named: **seam direction is not reaching the rendered frame
strongly enough**. That is terrain-grammar work and explicitly not test calibration.

**2. Published history — deferred, no rewrite.** See the blocker entry above. Area 6 closes as
*explicitly deferred by director decision*, which satisfies the exit condition's "closed or explicitly
deferred with a written reason".

### Milestone sequence set by the director

1. Resolve or explicitly defer material grammar.
2. **Define the performance SLO** rather than treating "120fps p95" as an already-valid universal contract.
3. Finish documentation and public-presentation verification.
4. Close or explicitly defer the Area 6 history issue. *(done, above)*
5. Exit the A+ programme.
6. Only then return to gameplay evaluation, the Freight sink design, and Freight Winch implementation.

The framing that matters: the remaining work is no longer harness cleanup. It is two visible design and
governance choices -- how terrain should read, and whether public history is worth rewriting -- and the
second is now answered.


## Area 2 — the remaining slices, and the measurement that changed what "oversized" means

### Bullet 1: split oversized files. Satisfied, and NOT by splitting `world_renderer.gd`

> **SUPERSEDED 2026-08-22 — see "Area 2 — the extraction programme, closed on evidence".** This section
> concluded that `world_renderer.gd` should not be split, on a code-vs-comment measurement. Three seams
> were later cut from it (4601 -> 3557) and the conclusion here is wrong, but the REASONING is kept
> because the correction is instructive: this measured DENSITY (code lines, comment share, largest
> function) and density does not answer whether a boundary exists. The later pass measured the interface
> that survives a move, which does. A file can be all-short-functions, 41% comments, no god-method, and
> still contain three blocks that only ever talk to themselves.
>
> The table below also prints 4602. The file was 4601: `wc -l` and `grep -c` agree, and it ends in a
> newline.


The area names two files "a reviewer will open first and judge fastest": `hud.gd`, which was split
4790 -> 2015 across seven extracted pages, and `world_renderer.gd`, which was not. Before cutting it,
the file was measured. The result does not support the cut:

| file | lines | **code** | docs | largest function (code lines) |
| --- | --- | --- | --- | --- |
| `world_renderer.gd` | 4602 | **2370** | 41% | `setup` 95 |
| `factory_sim.gd` | 2968 | 1679 | 32% | `_run_drill` 62 |
| `main.gd` | 2798 | 1680 | 31% | `_unhandled_input` 109 |
| `hud.gd` | 2016 | 1172 | 30% | `_draw_hover` 96 |
| `fine_terrain.gd` | 1409 | 572 | **53%** | `_paint_fine` 88 |

**No function in the codebase exceeds ~120 code lines**, and `world_renderer.gd` averages 17 across 141
functions. "Oversized" was being measured in LINES, and lines in this repository are 30-53% prose. The
hud split was justified because the counter had genuinely separable PAGES, each with its own state; the
renderer's per-frame painters legitimately touch every entity, and that coupling is the renderer's job
rather than a tangle. Splitting it would move documentation between files and add indirection without
reducing any function's complexity.

**The seam that IS real, if it is ever wanted.** Holding out the coordinators (`_paint_lights`,
`_update_veil` -- the two that must ask every entity for its light), the veil leaf measures 8 functions
and 144 code lines with 4 private state vars, **2 foreign references and 2 outward calls**. That is a
genuine module boundary and it is recorded here rather than taken, because 144 lines is not worth the
churn today and the plan should outlive the appetite.

### The instrument error inside that measurement, because it nearly became the finding

The first pass computed each function's body as "up to the next `func`", which attributes the *doc comment
block of the following function* to the previous one. It reported `daylight` at 128 lines and gave an
8-function leaf the same 54 foreign-state references as the entire 17-function cluster -- the foreign
names were being read out of comments. In a file that is 41% prose, a body extractor that cannot tell code
from documentation measures the documentation. The corrected extractor ends a body at the first column-0
line and strips comments; every number above comes from that one.

### Bullet 2: manual registries -> validated content definitions. SHIPPED

`check_rules_registry`, layer 110, 105 assertions. Guards nine hand-kept dictionaries against each other
rather than each against the world. Thirteen raw hits on the first pass, **zero real** -- nine a namespace
confusion between tool CLASS and tool ID in the checker, four deliberate absences already documented at
the table. Shown to fail on three separate mutants.

### Bullet 3: duplicated logic. SHIPPED

Three copies of "can this be paid for" became one, owned by `FactorySim` because that is the layer which
gates the spend, with the counter delegating downward. There are no `to_dict`/`from_dict` serializer pairs
in the tree, so the "duplicated serializer" half of the bullet had no subject.

### Bullet 4: simulation and rendering ownership, and how invalidation crosses the seam

Answered by the Area 4 profile rather than by reading. The largest stall in the game was a **sim** cache
(`find_bazaars`) invalidated by a **terrain** edit and paid for inside a **render** frame, while the
harness attributed it to the renderer's fine-terrain rebake. The seam is real and it is a cache
invalidation, not a call graph.

The concrete debt it leaves: `FactorySim.solid` is mutated by direct dictionary assignment at 41 sites,
so no index over it can be maintained soundly. That is the coupling to fix if the remaining ~4.5ms of the
dig frame is ever wanted, and it is a mutator, not a rewrite.

### One question for the director, not a defect

`shale` takes `DEFAULT_HARDNESS` 0.50 while `stone` is 0.85, so a deeper band material is softer than the
one above it. Fissile rock being soft is defensible geology, and the number has never been decided in
writing -- it is the default, arrived at by omission. Changing it changes the mining feel of a whole band,
so it is named in the new layer's exemption list and left alone.

## Area 4 — the formal pass: seven full-grid loops, and the second cliff ran every frame

The first fix earned a question rather than a conclusion: having found one O(world)-per-event scan, is
there another of the same shape? There are **seven full-grid loops in the tree. Six are fine.**

The seventh is `bazaar_completion_cell`, and it was worse than the one already fixed in the one way that
matters. The rescan at least had a dirty-flag cache, so it only paid after a dig; this one walked all
~16,000 origins with its own copy of the "which cell finishes this frame" predicate, called from
`_guide_targets()` in `_process` for as long as the objective read "Claim the Bazaar". Uncached, every
frame, in the first minutes of a new game.

| | per call |
| --- | --- |
| `bazaar_completion_cell` | 3.17ms |
| `find_bazaar_ruins` (cached) | 0.12ms |

**38% of a 120fps frame spent re-deriving something the sim had already computed and stored.** The fix is
not an optimisation, it is deleting a duplicate: `_ruins_cache` already holds every frame that is exactly
one wood short, in the same row-major order, behind the same dirty flag, so the completion cell IS the
first ruin's gap. `_bazaar_missing_one` and `bazaar_gap_at` were two implementations of one predicate and
the second one went, with its 34 lines. **3.17ms -> 0.10ms, 32x** (`e78845e`).

Verified rather than argued, because "equivalent" was the whole claim: the live scan against the cached
lookup over 60 rounds of random digging and wood-dropping, **0 mismatches**, with 18 of those rounds
carrying a real completion cell so the comparison had something to be right about.

## Area 4 — the frame SLO WAS promoted, which supersedes "not promoted, deliberately" above

The earlier Area 4 section closes by declining to promote the absolute budget, on the grounds that it
needed "a drop-rate bound chosen from a distribution nobody has measured". The distribution was then
measured, so that paragraph is superseded rather than merely dated (`b70c254`).

p95 is gone. In its place, two terms, because either one alone is blind to a real regression: **how OFTEN
a deadline is missed** (a frame past 1.5x the refresh interval) and **how LATE the worst one is**. Rate
alone cannot see a stall getting shallower; severity alone cannot see one getting more frequent.

The bounds are ratchets onto five consecutive runs of 200 frames per phase, not judgements about what is
good enough:

    IDLE   0.5 0.5 0.5 0.5 0.5 %     worst ~1.8x interval
    RUN    0.0 0.0 0.0 0.0 0.0 %     worst ~1.4x
    SWING  0.0 0.0 0.0 0.0 0.0 %     worst ~1.4x
    DIG    3.2 3.0 4.0 3.2 3.0 %     worst ~2.5x

DIG gets its own 6.0% allowance because it is the only phase doing work a player asked for mid-frame, and
hiding that behind one global number would let a dig regression spend the quiet phases' headroom. The
severity bound is 3.0x, which is the only bound here with a demonstrated failure: **the pre-fix bazaar
rescan FAILS it** (DIG worst 31.4-34.1ms against a 25.0ms bar) and the fixed build clears it at 17.7-20.8.
A bound that would have caught the largest stall this project has measured.

### And a contention guard, written and then RETRACTED — the evidence is the useful part

Running the new SLO on a box at load average 11.3 produced IDLE 13.5% missed and RUN 38.5%, then RUN 4.5%
on the very next run of the same build. An eightfold move between consecutive runs of identical code is
not a verdict about the code, and the repository's standing rule is that a spoiled sample is **VOID, not
FAIL**. So I added a guard: stand the SLO down when the quiet-phase median sits off the refresh interval
by more than `VSYNC_PINNED_MS`, on the theory that a quiet, vsync-paced box paces on the panel.

It was verified working — it fired, it printed its reason, the relative hitch ratios still asserted — and
it was still wrong. **Checked afterwards against the 146 quiet medians in the retained sweep logs:**

    min 7.37   p05 7.76   p25 8.02   median 8.31   p75 8.34   p95 9.35   max 29.41    (interval 8.33ms)
    below the window 55 (38%)   ·   asserts 73 (50%)   ·   above the window 18 (12%)

**The guard declines on half of all runs on this box.** Two faults, both worth keeping:

1. **38% of runs sit BELOW the interval**, the direction contention cannot produce — those frames finished
   early. `absf()` spent half the budget on a reading that is evidence of health.
2. **Fatal: the distributions overlap.** The contended runs measured that day read 8.67, 9.35 and 9.44;
   ordinary sweep runs in the same log set read 9.23, 9.31, 9.49, 9.69 and 9.86. No bar on this quantity
   separates them at all.

It was also the wrong constant. `VSYNC_PINNED_MS` is calibrated to answer *"is this run vsync-pinned"* — a
different question — and its margin against the worst clean reading was **0.01ms**. Two unrelated literals
that had to be ordered, and I wrote the ordering instead of deriving it.

**Nothing else in reach works either, and this is the part worth carrying forward.** The quiet phases' own
miss rate is the obvious discriminator and is disqualified twice: it IS the subject of the IDLE term, so a
guard keyed on it stands the assertion down exactly when it was about to fail — and it has false negatives
anyway, since the first contended run read IDLE 0.5% / RUN 0.0% while both working phases fell over. A
CPU-starvation probe is blind to it too: what breaks frame pacing on this platform is largely
compositor-side, and WindowServer was the top process on the box, ahead of any of the hogs.

So the contract stays the operator's, which is what `SF_PERF_HOST` already means — setting it is a promise
that this is controlled, quiet hardware. The layer cannot verify that promise and no longer pretends to.
It prints the evidence a reader needs to classify a red, names the classification as work still owed, and
lets the red stand. **A stand-down that fires on half of all runs is not caution, it is a gate that runs
nowhere** — and this project has shipped one of those before.

Re-measured after the retraction, at load average 4.55: IDLE 0.5%, RUN 0.0%, DIG 3.2%, SWING 0.0%,
asserted and passing. Ordinary desktop load does not spoil the SLO; the load-11.3 case was extreme.

## Area 5 — VERIFIED 2026-08-22, not merely marked done

Re-checked rather than trusted, because "DONE" written by the person who did it is not evidence.

**Every stated count is exact.** The runner registers 110 layers under four verbs; `docs/ENGINEERING.md`
publishes the breakdown and all four rows match the runner line-for-line:

    add 92   add_gl 14   add_excl 3   add_excl_hl 1     = 110

`README.md` says "17 layers are registered as needing a real window, three of which also need the machine
to themselves" — that is `add_gl` + `add_excl` = 17, of which `add_excl` = 3. Correct. `README.md` and
`CONTRIBUTING.md` both state 110 in every place they state it.

**No dead references.** 46 distinct file paths are cited in backticks across `README.md`,
`CONTRIBUTING.md` and `docs/ENGINEERING.md`. Two do not exist on disk — `export_presets.cfg` and
`head.tres` — and both are correct prose rather than rot: the README says `export_presets.cfg` "is
gitignored", and says of the other, in as many words, "There is no `head.tres`, because the Head is the
Drill". A path checker that reads paths and not sentences reports these as dead; a reader does not. Run
with a fabricated path as a control, which reported DEAD as it must.

## Area 6 — the history census, and why the deferral is re-opened

The **tree** is clean and this was checked both ways: `git ls-files` and `git ls-tree -r origin/main`
both return **0** tracked files under `docs/tracelog/`, `docs/handoff/`, `docs/superpowers/` or
`.claude/`. The three tracelog files are present on disk, untracked and locally excluded, and nothing has
been deleted.

The **history** is a different surface, and this is the distinction the whole item turns on: a working
tree can be spotless while `git clone` still hands over everything that was ever committed. `f215f2e`
("untrack the working notes", 2026-08-20) removed these paths from the index. It did not remove them from
history, and it is itself pushed.

Censused from `origin/main` directly:

| | |
| --- | --- |
| distinct process-corpus paths | **26** |
| blob versions of them | **173** |
| total content | **12.1 MB** (of a 363 MB clone) |
| commits touching them | **162** of 1015 |
| window | 2026-08-16 `10641ac` … 2026-08-20 `f215f2e` |

The largest are `docs/tracelog/c2.md` (211 KB), `docs/tracelog/c1.md` (181 KB),
`docs/handoff/AUDIT_UPDATE.md` (138 KB, 27 versions), `docs/PEER_SESSIONS.md` (82 KB) and
`AUDIT_REPONSE.md` (63 KB).

**What is in them**, counted over the extracted 12.7 MB with both a positive control (`sinkforge`, 515)
and a negative control (`zzqqxx`, 0) in the same command, because a scan with no witness reports zero for
every failure including its own:

    claude 380   ·   anthropic 55   ·   subagent 172   ·   "the user" 1127   ·   co-authored 23

An earlier version of this scan returned **0 for every word including the positive control**, because
`git` was not on the path inside the subshell it ran in. Every one of those zeros looked like good news.
The control is the only reason the void was caught rather than published.

**The message surface is UNCHANGED, and I briefly recorded otherwise.** A first pass reported it as
nearly clear. That pass counted matching *lines* from `git log --format=%H%n%s%n%b`, and a commit body is
many lines, so it was a line tally wearing a commit tally's label — and the subject/body split it printed
was misaligned on top of that. Re-run per commit, against the held-out `tools/prose_words.txt` rather than
an ad-hoc regex, with both controls:

    1015 commits scanned
      25 carry at least one listed word     <- unchanged from the earlier census
         agentic 17 | subagent 6 | AI 1 | Claude 1
       4 of them in SUBJECT lines           <- what GitHub renders in the commit list and in blame
       controls: bazaar 68, zzqqxx 0

So Area 6 has **two** live surfaces, not one: 25 commit messages and 12.1 MB of file content. Only the
content half is new information; the message half was already known and is not improving on its own.

**Not acted on. This needs the director**, on two counts: a history rewrite is a standing stop condition,
and the existing deferral was decided against roughly half of the real scope. The decision itself may well
be unchanged — the reasoning about operational risk does not depend on the number — but it should be
re-taken knowingly rather than inherited from a bad census.

## Area 3.6 CORRECTION — TR-02 passes, but 99.14% was one draw, not the build

The TR-02 closure is recorded as `STRUCTURE verdict 70.69% FAIL -> 99.14% PASS (floor 75.00%)`. The fix is
real and the layer does pass. **The number is not reproducible, and it is the top of its range.**

Four runs of the **same commit** (`c5ea40c`), same 116 lit windows, nothing changed between them:

    76.72%   78.45%   98.28%   100.00%          floor 75.00%

A **23-point spread on identical code.** All four pass, so this is not a red — but the closure reads as a
24-point margin and the low end of four samples is under two points clear. The earlier readings make the
same point across configurations: at n=116 the retained logs hold 71.55 (pre-fix), 95.69 and 99.14; at
n=74 and n=70 they hold several sub-floor values.

**What this is.** A thresholded fraction over a sampled population, reported from one draw. The layer
counts how often two materials are tellable apart over the windows that happen to be lit, and both the
window set and what is inside them move between runs. That is the [[unstable-threshold-statistics]] shape:
the statistic can measure its own threshold. It is also [[scrutiny-asymmetry]] — 99.14% arrived as the
happy end of a correction, which is exactly when a number gets the least scrutiny, and I carried it
forward twice without re-running it.

**Not repaired here, and the floor is not moving.** The honest summary of TR-02 is: the mechanism was
found and fixed, the layer clears its floor on every run measured on this build, and the margin is thin
and highly variable rather than the 24 points the closure implies. What is owed is a stability fix to the
instrument — report mean and median over several draws rather than one, which is what this project already
concluded once for a different layer — not another attempt at the grammar.

### Area 6 preflight brief — written 2026-08-22, nothing executed

Director's call: produce the exposure brief first and change nothing; prepare but do not run the rewrite;
no force-push until the preflight proves byte-identical content, a valid archive, clean reachable-history
scans and a green fresh-clone suite. The likely disposition is to preserve the 1015-commit record and
remove only the transcripts, coordination artifacts and message tells.

Brief at `docs/handoff/AREA6_EXPOSURE_BRIEF.md`, with `area6_delete.txt` (28 paths) and
`area6_replace.txt` (14 paths) beside it. The three findings that changed the shape of the job:

- The first path list was **wrong by 16 paths**, because it was hand-written from what I expected to find
  rather than scanned. Rescanning every text blob found vendor words in `scenes/main.gd` (144 versions),
  `tools/run_harness.sh` (125), `README.md` and `.gitignore`. **A path-deletion filter over that list
  would have deleted the game.** The set had to be split: 28 paths absent from the tree (delete) against
  14 live shipping files whose current versions are clean and whose history is not (content replace).
- **658 of 1015 commits change SHA**, not 162 — the contaminated window starts at `10641ac` and every
  descendant is rewritten.
- **Two blockers before anything can run**: `git-filter-repo` is not installed, and the 328 MB archive
  bundle predates the current tip, so the last day of work currently has no recovery path.

### Area 6 dry run — VALIDATED IN A DISPOSABLE CLONE, 2026-08-22, nothing pushed

Full record in `docs/handoff/AREA6_EXPOSURE_BRIEF.md` Part 2. Canonical checkout never touched.

Recovery bundle taken and **proven by restoring from it** (sha256 `2becfb1e…`, 328 MB, 69 heads, complete
history, contains `c5ea40c`/`e78845e`/`43dcdd4`, fabricated SHA correctly absent). `git-filter-repo`
2.47.0 from a Homebrew bottle, script sha256 recorded. The rewrite ran once, combining all three
dispositions, in 33 seconds.

**The result that matters: the root tree object SHA is IDENTICAL on both sides**
(`26947c370b9bf227e74a7cc063a3ef29e3072d1b`). Not a file-by-file diff — the whole tree hashes to the same
value, which is the strongest available proof that no runtime file moved, changed or vanished.

    tree-set equality      595 = 595 files, 0 either way
    blob scan              2524/2524 parsed, control positive, 0 vendor hits
    message scan           873 commits, 25 -> 0, control 68 -> 63
    cold import            .godot absent on the fresh clone, import exit 0
    commits                1015 -> 873

The 142 dropped commits reconcile exactly: 138 non-merge commits that touched **only** deleted paths
(predicted 138, observed 138) plus 4 degenerate merges. They are `docs(trace):` and `docs(priority):`
commits whose messages are themselves the artifact, so pruning them removes a tell rather than losing
record.

**Two findings are NOT cleared, and neither is a threshold to lower.** The vendor-word scan passes at
zero and is the wrong instrument for what is left: **83 of 873 commit messages (10%, 6 in subjects)
narrate a multi-session process** — "both sessions hit tonight", "belongs to the peer session", session
labels `c1`/`c2`, "issued 0045". That is prose editing under judgement, not substitution, and it is a
second director decision. The same vocabulary also sits in 38 historical blob versions of live files
whose current versions are clean.

One more instrument lesson, the fourth of the session and the sharpest: a coordination scan run from the
**wrong working directory** read the canonical repo, stopped at 525 of 2524 objects — and **its positive
control still passed**, because the objects it did read are shared between both repos. A control proves
the instrument can see; it does not prove it looked everywhere. Assert `parsed == expected` separately.

### Area 6 side-finding — the authorship gate has never run in CI, and tracking it would be the tell

The rewritten fresh clone stood down one assertion group the canonical tree asserts:

    canonical clone   HELD: [prose.wide-word-list] this run asserted it (11 word(s))
    fresh clone       SKIP: [prose.wide-word-list] no wide word list at .../tools/prose_words.txt

`tools/prose_words.txt` is **untracked** (`git ls-files` returns 0) and the workflow never sets
`SF_PROSE_WORDS`. So the wide authorship-vocabulary check — the one instrument aimed squarely at the Area 6
problem — runs **only on this machine**, and has never run in CI or in any clone.

It is a registered stand-down rather than a silent pass, so the harness has always been honest about it.
But the practical consequence is worth stating plainly: **nothing in CI prevents vendor vocabulary being
reintroduced.**

The obvious fix is the wrong one. A tracked list of forbidden vendor words is itself a tell — a public
file enumerating "claude, anthropic, agentic" advertises exactly what was scrubbed, which is why the list
was moved out of the tree in the first place. So this is not a defect to fix by tracking it; it is a
constraint to state. If CI coverage is wanted, the list has to arrive out of band (a secret, or a
generated file), and that is a director decision rather than a cleanup.

Recorded as a known limitation. No threshold moved, no stand-down deleted.

### Area 2/4 CORRECTION — the `solid` mutator sizing names a file that does not exist

The Area 4 residual section sizes the deferred `solid`-mutator task at "**41 direct mutation sites** — 18
in game code (`factory_sim.gd` 14, `flora.gd` 2, `objectives.gd` 1, `world_renderer.gd` 1) and 23 in
fixtures and tools". Re-derived with a working control (82 total `solid[` occurrences, so the scan can
see):

    assignments  solid[...] = ...     19
    erases       solid.erase(...)     18
                                      --
    total mutation sites              37

    game code (src + scenes)   19    factory_sim 13 · fine_terrain 4 (two files) · flora 2
    tools and fixtures         18    7 files

**The totals nearly agree (18 vs 19 game) and the SETS do not**, which is the failure mode this project
already has a name for. Specifically:

- `objectives.gd` performs **0** direct `solid` mutations today (it mentions `solid` four times, all
  reads). It lives at `scenes/objectives.gd`, not `src/core/`. **I first wrote here that the file did not
  exist at all — that was wrong, and it was wrong for the same reason the thing it was correcting was:
  I checked one guessed path and reported its absence as the file's absence.** Corrected on the spot;
  the lesson is that "not found" is a statement about where you looked.
- `scenes/world_renderer.gd` performs **0** `solid` mutations.
- `fine_terrain.gd` — which holds 4 of them across its two copies — is **not named** in the doc.
- The doc's count omitted `solid.erase` entirely, which is half the real mutation surface (18 of 37).

The remediation is unchanged and still correct: `solid` has no choke point, so no index over it can be
maintained soundly, and that is what blocks the remaining ~4.5ms of the dig frame. But **the inventory a
future reader would work from was wrong**, and would have sent them to a nonexistent file and past the
one they needed. Re-derive the set before starting; do not trust the list above either without re-running
the scan with its control.

This was found by an audit that itself failed twice first — `git grep -E` with `\b` and `\s` silently
matched nothing and reported 0 sites where 82 occurrences exist. Fifth instance of that trap this
session. Use `-w`, or POSIX classes, never `-E` with escapes.

### Area 6 dry run — FINAL: the rewritten history is green

    110 PASS / 0 FAIL / 0 SKIP of 110    HARNESS_EXIT=4    HARNESS_RESULT=yes    311s
    7 assertion groups stood down across 5 layers, exactly the registered ones
    check_trailers (CI-equivalent): PASS - 1009 commits, one author, no trailers

First run read 109/1. The single FAIL was `core.hooksPath ... 'unset'` — a fresh-clone configuration
artifact, confirmed by the archive clone showing the same and the canonical showing it set. Configured
and re-run; nothing lowered.

**A fresh clone's green is 7 stand-downs, not 6.** The extra is `prose.wide-word-list`, and it is honest:
the word list is untracked by design, so no clone can run that check.

All nine preflights pass. Two findings remain uncleared and are director decisions, not defects to route
around: 83 of 873 commit messages carry multi-session process narration (6 in subject lines), and 38
historical blob versions of live files carry the same vocabulary. The vendor-word scan passes at zero and
is structurally unable to see either.

Nothing pushed. Canonical `main` is `c5ea40c`, clean, level with `origin/main`.

### Area 6 — items A and B done, rewrite re-validated, still not pushed (2026-08-22)

**Item B SHIPPED to main as `e1306f9`.** The authorship gate no longer depends on an untracked local
word list. `tools/prose_tokens.sha256` is tracked and carries ten salted digests plus a nonsense
sentinel. Absence is now a FAILURE rather than a stand-down, the registry row is deleted because the
runner refuses to let the ledger name a row nobody can trip, and two controls run before the sweep does.
Sensitivity is preserved and measured rather than claimed: seeding the digest set with a word that really
is in the tree flags 48 files where `git grep -w` finds 41 and `git grep` finds 48. **Verified in a cold
clone**, which is the point — it stood down there before and now asserts.

**Item A done as 126 hand-authored line rules** (`docs/handoff/area6_message_mapping.md`), 123
replacements and 3 kept verbatim. Process narration in commit messages: **83 -> 2**, and both survivors
are the reviewed keep-verbatim lines.

Two things a regex would have got wrong, which is the argument for the mapping:

- `` `c3 a2 c2 80 c2 94` `` are the hex bytes of a UTF-8 em-dash and "C1 control" means Unicode C1
  control characters. Neither is a session label; substituting either destroys a technical fact.
- **filter-repo rewrites old commit ids inside messages to their new values before a message callback
  runs.** Three keys carried a sha, silently stopped matching, and three commits survived the first
  regeneration still crediting a session label. The after-scan caught it; inspection did not.

Attribution was rewritten to the pass and never to a person, and two drafts saying "review" were
tightened, because "caught on review" implies independent human validation that did not happen.

All nine preflights pass on the regenerated rewrite (1016 -> 874 commits, `c14d0af`): root tree object
identical, 2527/2527 blobs scanned with the control positive and zero vendor hits, cold import clean, and
the full harness **110 PASS / 0 FAIL / 0 SKIP with six stand-downs, matching the canonical tree** rather
than the seven a fresh clone used to report.

**Outstanding and reported, not routed around:** coordination vocabulary in historical blob versions of
live files (114 citing corpus paths, 105 "peer session", 24 "orchestrator", 13 PEER_SESSIONS). Current
versions are clean, so the tree is unaffected. It needs the same hand-authored treatment item A got.

Nothing pushed beyond `e1306f9`. Canonical `main` is clean and level with `origin/main`.

## Area 2 — world_renderer.gd measured before any extraction (2026-08-22)

> **HISTORICAL — this is the FIRST of three measurements and its numbers were later corrected twice.**
> Kept as written because both corrections matter. (1) Its spans ended each function at the next `func`,
> which absorbed the declarations sitting between them and inflated every row: lighting/veil reads 955
> lines and 68 variables here against a true 639 and 23. (2) Its candidate memberships were recorded as
> COUNTS, so `terrain-bake | 23 funcs` cannot be reproduced — a later derivation gets 10 functions and 101
> lines, and the two disagree about the population rather than about the code. The ranking that closed
> Area 2 is in "the extraction programme, closed on evidence" and supersedes every number below.


4601 lines, 140 functions, 1867 comment lines (41%). Four candidate seams were measured rather than
eyeballed, on three axes: how much the candidate still needs from the parent (out-calls), how wide an
interface the parent needs back (in-calls), and how much mutable state it touches.

| seam | funcs | lines | out-calls | in-calls | vars read | vars WRITTEN on both sides |
|---|---|---|---|---|---|---|
| lighting/veil | 21 | 955 | 10 | 5 | **68** | 2 (`_veil_dirty`, `_veil_cols_dirty`) |
| machines | 19 | 642 | 1 | 4 | 10 | **0** |
| water | 6 | 307 | 1 | 3 | 4 | **0** |
| terrain-bake | 23 | 498 | 2 | 9 | 12 | 1 (`_fine_dirty`) |

**The finding is that the obvious seam is the wrong one.** Lighting/veil is the largest block and very
nearly contiguous (roughly 3568-4600 unbroken), which is exactly what makes it look extractable. It reads
**68** of the file's mutable variables and writes two dirty-flags that the parent also writes. Moving it
would relocate 955 lines and leave the coupling in place — a smaller file and the same design. It fails
the "extract only if the seam reduces coupling" test and is NOT a candidate.

`machines` (642 lines, one outbound call, a four-function interface, no shared writes) and `water`
(307 lines, one outbound call, three-function interface, no shared writes) both pass. `machines` has the
better size-to-coupling ratio and is the first slice.

> **OUTCOME.** Both were cut, `machines` in `097c769` and `water` in `8fa99a8`, and a third the state-based
> ranking here could not see — `rope + grapple`, which owns no mutable field — in `d1d5ab8`. The line
> counts in this paragraph are the inflated ones; the true bodies are 460 and 220.

**Method note.** Function-call coupling alone would have ranked lighting/veil second-best (10 out-calls is
not obviously fatal). Only the shared-mutable-state axis exposed it. A seam analysis that counts calls and
not state measures the shape of the code rather than the cost of moving it — the same distinction as a
gate that counts hits without asking which population it drew from.

## Area 4 — the Bazaar cache, verified rather than assumed

The item read "verify the Bazaar cache and any remaining full-grid scans". Verified means measured, and
the interesting part is that the verification found no defect and still produced a number worth keeping.

**The invalidation graph.** `_bazaars_dirty` is written from nine sites and every one is event-driven:
`set_solid`, `mine`, `place_block`, `_run_drill` (x1), `_run_h_drill` (x2), `_run_drift` (x2), and
`save_game` on load. Nothing dirties it unconditionally per frame.

**The read graph is per-frame, and that is the part that matters.** `find_bazaars` is reached from
`hud._draw_minimap` (via `_draw`) and from `Bazaars.update(sim, dt)`, so the cache is consulted every
frame. A running drill therefore breaks a block, dirties the flag, and the next frame pays a rescan. That
is the shape the original stutter had, so it is worth knowing what one rescan costs now.

**Measured directly**, headless, machine lock held, 40 samples, dirty flag forced before each:

    rescan   min 2.69  p25 2.72  median 2.74  mean 2.75  p95 2.82  max 2.86   ms
    cached   median 0.000                                    ratio ~27000x

The cached path is the control and it travels inside the same run: if the two came back alike the timer
would be measuring call overhead, and every number would be void. They separate by four orders of
magnitude, so the timer is registering the rescan.

**Disposition: no defect. The cache is correct and the repair holds.** A dig costs 2.74ms, a third of a
120fps frame, against the 16.4ms two-whole-frames it cost before the two-read early reject landed.

**What was actually wrong was the evidence, not the code.** The source proved the repair with a
frame-level ceiling: "the same profile shows nothing above 5.9ms". That is the right evidence for "is the
stutter gone" and the wrong evidence for "what does a rescan cost", because a frame ceiling bounds the
rescan without ever measuring it. The direct number is now recorded beside it with its control and its
spread (0.17ms across 40 samples, so a stable cost rather than a sampled one).

**Full-grid scan census.** Of the nested-range loops across `scenes/` and `src/`, all but one are bounded
by a radius, a rect, a band or a view window. The single genuine full-grid walk is `_rescan_bazaars` at
`GRID_ROWS x GRID_COLS` = 16384 origins, and it is the one just measured. No unguarded per-frame full-grid
scan remains.

## Area 2 — the extraction programme, closed on evidence (2026-08-22)

Three seams cut: `machines` (460 lines), `water` (220), `rope + grapple` (119). `world_renderer.gd`
4601 -> 3555. Every remaining candidate in that file is rejected with its numbers, and the two other
large files are measured and have no separable seam. The published half of this is in
`docs/A_PLUS_STATUS.md`; what follows is the working detail that does not belong in a shipping tree.

**Method, so it can be re-run.** `$SCRATCH/a2/{measure,cluster,extract}.py`.
`cluster.py` derives MEMBERSHIP (seed from named state or a named draw family, grow by adding
file-private helpers whose only callers are already inside, hold out the coordinators by name).
`measure.py` scores it. `extract.py` performs the move. The membership matters as much as the score:
the old terrain-bake row said 23 functions and did not say which, so it cannot be reproduced.

**Four instrument defects found and fixed this session, all of them the house shape — an instrument that
cannot register its subject, reporting a quiet green rather than a gap:**

1. every const's own declaration line counted as an outside use, so `consts move` was 0 for every
   candidate, identically. Identical results across unlike candidates is the tell.
2. `^func` did not match `^static func` (the same miss as `static var` on the machines slice), so
   `rope_sag` was invisible and rope scored 7 crossings instead of 8 — tying the best row.
3. the constant-safety check reads one file; `CORD_CORE_W` and `ROPE_CORE` are read by
   `check_grapple_reads.gd`, outside the corpus. Reachability is only as wide as what you read.
4. the clustering closure fused on `setup`/`_process` before a holdout list existed.

Each was caught by a control, not by inspection: the const bug by every row reading 0; the static-func bug
by the compiler; the one-file bug by `git grep -w` across the repo; the fusion by reading the membership
rather than the count.

**Open, deliberately not done here:** `_draw_aim_ghost` is drawn and asserted by nothing (four layers stay
green with it disabled). Recorded as the next slice, not folded into a refactor commit.

## NEXT SLICE — spec, written down before it is started (2026-08-22)

**The gate that was set:** reconcile the population definition, THEN convert only the protocol tail, with
retained logs and a receipt whose stand-down status is stated accurately. The reconciliation is done and
pushed (`c3e5284`). What follows is the conversion, specified so it does not have to be re-derived.

**Population.** `P_INHERIT` = tracked `.gd` matching `^extends "res://tools/check_base.gd"` = **89**.
Re-derive, never quote:

    git grep -l '^extends "res://tools/check_base.gd"' -- '*.gd' | wc -l

Partition: **31 call `_verdict()`, 58 hand-roll, 0 neither.** The convertible set is the 58. Every inheritor
is also registered and also named `check_*` — both set differences empty.

**What may move: the verdict tail ONLY.**

    if _failures == 0:
        print("check_x: PASS — note")
        quit(0)
    else:
        printerr("check_x: FAIL (%d)" % _failures)
        quit(1)

becomes `_verdict("check_x", "note")`. Nothing else in `_initialize()` moves. 21 of the 58 carry real
judgement there — a whole settings round-trip, a whole layout suite, a headless skip decision — and
sweeping those into shared code would change what other layers measure. The tail is not always inside
`_initialize()`: it is for 40, elsewhere for 18. Convert it where it lives.

**What the conversion buys.** `_verdict()` refuses a green that asserted nothing and prints the assertion
count. A hand-rolled tail does neither, so zero assertions and zero failures is a PASS. Proven by paired
mutation: override `_check` to a no-op and `check_paint_terms` exits 0 with its PASS line unchanged while
`check_shared_constants` exits 1 naming the defect.

**Per-layer verification.** After converting a layer, the same no-op `_check` override must turn it red. A
layer that stays green after conversion has not been converted.

**Blast radius, already established.** Nothing parses the green line: `harness_verdict.sh` says it is
deliberately not a search for PASS/FAIL and classifies on exit codes. So `PASS — note` becoming
`PASS (N asserted) — note` is safe. 19 layers print a green line that never names them (`AGILITY OK`);
converting them also brings them inside `check_verdict_claims`' subject definition.

**Receipt wording.** "Configured sweep passed with six documented stand-downs." NOT "full sweep" — the
runner prints "this run does not count as a full sweep" whenever a conditional row stands down, which on
this tree is every run.

**Standing hazard.** Pixel-judging layers went red in two of four sweeps today and passed standalone every
time, reading degenerate (a miner silhouette at 0.0 levels where it reads 87). All four sweeps retained
under `docs/tracelog/sweeps/`. A red here needs a standalone re-run before it is called a regression, and
must not be deleted when it stops reproducing.


================================================================================================
NEXT SLICE — EXECUTED 2026-08-23. Outcome below; the spec above is left as written.
================================================================================================

DONE, and the spec held with two amendments found by running it.

  Converted   55 of the 58, in five batches, 97c62d8 .. 9474ffd, pushed at 1a11707.
  Population  P_INHERIT 89 = 86 _verdict() + 3 hand-rolling + 0 neither   (was 31 / 58 / 0)
  Sweep       110 PASS / 0 FAIL / 0 SKIP, six documented stand-downs, HARNESS_EXIT=4,
              HARNESS_RESULT=yes, 287s
              docs/tracelog/sweeps/2026-08-23-verdict-tail-converted-green/

AMENDMENT 1 — the spec said 58 convertible. It is 55.
  check_frametime, check_opening and check_underground call neither _check() nor _verdict().
  They hand-roll comparisons AND diagnostics, so there is no shared tail in them to move. The
  scanner refused all three by itself rather than guessing, which is why the number is trustworthy.
  They are now the only three layers the no-assertions guard does not cover. OPEN FINDING.

AMENDMENT 2 — the spec's blast-radius reading was incomplete, and the gap was real.
  It said nothing parses the green line, which is true of the RUNNER and false of a LAYER:
  check_verdict_claims keys on literals containing `<layer>: PASS`. It was already blind to the
  31 existing _verdict() users, and this conversion would have taken it to 86 of 89 blind with
  nothing going red to say so. Armed first (a91725c), then it found a second defect in itself
  (782c6d9): its negated class matched newlines, so two quotes anywhere in a file bracketed a
  candidate literal and it reported a claim assembled out of comment prose about itself.

  THE GENERAL FORM, worth carrying: "nothing downstream parses this" must name the downstream.
  The runner is not the only reader of a layer's output. Another LAYER can be.

THE BEFORE-STATE, which is the number this slice existed for:
  with _check overridden to record nothing, the 55 hand-rollers returned 55 PASS / 0 FAIL / 0 SKIP.
  Fifty-five registered layers exiting 0 having asserted nothing, and none of them noticing.
  docs/tracelog/sweeps/2026-08-22-verdict-tail-00-baseline-noop-mutant/

NEXT: a gate that would have caught it. Nothing today asserts that a layer inheriting check_base.gd
reaches its verdict through _verdict(). Such a gate has to carry the three above as a NAMED,
RATCHETED exemption list -- shrink-only -- or it is red on arrival and catches nothing.

### NEXT SLICE — CLOSED 2026-08-23

Converted, all 58, and the population moved under it while the work was being done. Recorded here because
the spec above quotes numbers that are now wrong, and the file's own rule is to re-derive rather than quote.

**The before-state was measured, not assumed.** 55 registered layers exited 0 having asserted nothing, with
a travelling control proving the zero was measured rather than produced by a broken scan.

**55 converted mechanically, 3 by hand** with each decision recorded beside its diagnostic, because their
tails carried judgement a rewrite would have dropped. 32 kept a note, 8 were bare, 15 dropped an
uninformative "X OK" string, and 19 of the 55 had been sending their FAIL verdict to stdout.

**The gate was armed before the conversion could disarm it.** `check_verdict_claims` could not see a claim
made through `_verdict()`, so the conversion would have moved every claim out of its subject definition
while the gate stayed green. Fixed first, then fixed again for a second defect it found in itself: its
`: PASS` regex matched across newlines and read a claim out of comment prose between two quotes.

**And a second way to hand-roll the protocol was found and gated.** A layer can bypass `_verdict()` without
having a tail at all, by calling `quit(0)` under its own power or by writing `_passes`/`_failures` directly.
`check_verdict_route` holds both rules over 90 inheritors. Its exemption dictionary is a shrink-only ratchet
and it emptied itself on first contact with real data, going `3 FAILURE(S) of 12` to zero.

**The partition today**, re-derived rather than quoted:

    git grep -l '^extends "res://tools/check_base.gd"' -- '*.gd' | wc -l                          91
    git grep -l '^extends "res://tools/check_base.gd"' -- '*.gd' | xargs grep -L '_verdict(' | wc -l   0

91 inheritors, 91 calling `_verdict()`, 0 hand-rolling, 0 neither. The 89/31/58 in the spec above was true
when it was written.
