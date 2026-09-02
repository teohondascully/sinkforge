# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-09-01.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

## CURRENT STAGE — the 120 Hz programme (2026-09-01)

**The director set a hard bar: 120 Hz, 8.33 ms a frame — "I refuse to ship a flaky and bad performing
game."** That interrupted the sequential port, which resumes after. `docs/PERF_PLAN.md` is the ranked,
sourced plan and the recovered record of how legacy already hit this bar at this same framing.

**Measured by `view/draw_cost.gd`, inside the frame — painters 4.01 ms against the 8.33 ms budget**
(`veil=2.99 sky=0.97 glint=0.03 bake=0.01`), plus a 1.58 ms sim tick, so the frame is ~5.6 ms. Legacy
budgets its own fine-fill at "4ms of the project's 8.33ms budget", so this is parity.

**A correction that matters for anyone reading older numbers in this file's history:** the wall-clock
"ms/tick" slope is only valid ABOVE the tick interval. `reveal_scene` ticks in `_physics_process`, pinned
at 60/sec, so three consecutive optimisations all measured "15.9 ms/tick" — 1/60 s — while the work inside
the frame kept falling. The 64.6 -> 17.9 ms improvement was real; below ~16.7 ms the slope was the clock.

Landed: the veil became a metre-resolution lightmap drawn in ONE call instead of 14,080 (D0336, 41.47 →
3.58 ms); the glint iterates a cached sparse list instead of every visible cell (D0337, 11.83 → 0.01 ms);
the per-frame observation stopped building a wall plane whose only reader D0326 had already moved into
the bake (D0338, observe 10.60 → 6.36 ms). Also `view/draw_cost.gd`, the per-painter attribution
instrument — built BEFORE any fix, because legacy's own note says optimising against a total "is how you
end up tuning the wrong thing confidently".

**Next and largest: `TileGrid`'s planes as a flat `PackedByteArray` instead of a `Vector2i`-keyed
`Dictionary`** — `observe` is still 6.36 ms of the 15.9. Legacy has nothing to port here because it never
built a per-frame observation at all; the fix is legacy-SHAPED (`factory_sim.gd:795`, "handing the array
over turns that loop into a memcpy") but the component is ours. It touches `state_signature`'s storage,
so it needs its own determinism pass and golden re-pin.

**In flight: PR #47** (D0335–D0339). Its `test_shaft_replay_determinism` golden must be re-pinned from
that PR's own CI Linux run — D0335 widens the world, which is a world-GENERATION change.

## The sequential port (2026-09-01)

**The director replaced the fleet/lane model with a sequential one:** establish the dependency order,
then port ONE complete vertical at a time — running and verified — before the next. `docs/PORT_ORDER.md`
is that order, 13 components, written and agreed this session. The lane table below is the previous
model and is retained only for its blocked/unblocked facts.

### Landed this stage, all merged to main

| # | Component | Ledger | What it is |
|---|---|---|---|
| V1 | Terrain bake | D0326 | Static terrain drawn ONCE into a world-sized SubViewport and replayed as one quad, instead of re-issuing every per-cell painter loop every frame. Legacy measured that pass at ~72% of frame draw calls. |
| — | Zoom ladder | D0325 | Legacy's four framing rungs, converted ×2 for the cell regime. Ported and tested; **not yet the default** — see below. |
| V2 | Molded-rock shading | D0327 | `RockTone`: tonal drift, patches, two-octave grain, stone blobs, crack seams, hue poles, and the eight-table texture grammar. |
| V2b | Carved-edge terms | D0329 | AO, the rim lip, the sky-form gradient — the three terms that read a neighbour. |
| V3 | Lens + palette grade | D0328 | `post_fx.gdshader`, on the deterministic tick clock rather than `TIME`. |
| — | Sub-cell tooth | D0331 | `rock_grit.gdshader` — the world-space roughness that gives rock detail *inside* a cell. |
| — | Skylight ceiling | D0332 | Depth darkness. The veil darkened by burial and not by depth, so 2 m and 200 m looked identical. |
| — | Camera limits | D0333 | The camera showed past the world; a third of the frame was grey void at the wide framing. |

### Four defects found, and how — this is the useful part

Three came from **looking at a capture**, one from **sweeping the ported legacy file for its
optimizations**. None was reachable by any gate:

* **D0330** — a partial re-bake seams along every chunk edge, because painters read up to 7 cells out
  and only the dug cell's own chunk was marked dirty. Appears **only after mining, only near a
  boundary, never in a fresh bake**. A mutant escaped first: setting the *call site's* margin to 0 left
  the suite green, because the test posed its own subject and bypassed the wiring.
* **D0331** — the baked quad was sampled LINEAR (`NEAREST` was set inside the viewport, which governs
  drawing *into* it, not sampling *out*), and country rock had no variation inside a cell at all.
* **D0332** — no depth darkness.
* **D0333** — no camera limits, and D0273's stated reason for deferring them **was not true**: both
  debug framings bypass the rig entirely.

### Open, and named

* **The zoom ladder is still not the default.** It needs a world wider than 12 m; `width_cells: 48` is
  the play site's, and a 40-metre frame on it is mostly void. Generation at 512 cells measured ~10 s.
* **The progressive bake is not ported** (legacy `fine_terrain.gd:768-812`, a TIME-budgeted slice per
  frame). Ours paints every chunk in one `UPDATE_ONCE`: fine at 27k cells, will hitch at 289k.
* **The wall is toothed along with the rock**, because our painters blend alpha where legacy stamps
  bytes. Separating them changes a painter shared with the non-baked path.
* **The skylight's under-rock scatter is folded into the reach** — it needs `Observation.surface_y`
  wired at paint time.
* The mining reach ring reads as a debug overlay, but it lives in `tests/body/`, not in shipped code.

### The honest visual verdict

Measured: the delve capture went from **178 distinct colours (2026-08-30 baseline) to 1,268**. Caves
read as voids with lit lips, the sky is genuinely good, the depth gradient works, the lamp pool works.
**It is still not shippable.** Country rock reads as soft brown cloud, the glimmer marks read as
floating glyphs, and the frame has no composition beyond "world fills screen".

## Overnight queue

**Authored 2026-08-31 on the director's explicit instruction** ("author the missing ## section properly
— this is setup, not a decision"). `.claude/commands/loop.md` requires this section to exist before a
`/loop` run and forbids the running session from inventing one; the director's LOOP CONTROL FIX
supersedes that by handing the classification rule down directly. Items come from `docs/LEGACY_GAP.md`,
which is `docs/MASTER_PLAN_AUG30.md` §3's own output.

### The rule that governs this queue

**A parked decision pauses a LANE, never the RUN.** `.claude/commands/loop.md` carries the full
procedure; the short form is: write the ruling to `docs/NEEDS_DIRECTOR.md` with its measurement, decide
whether it gates only this item or the whole lane, and **take the next item either way**. Rulings
accumulate into a batch and are surfaced together, never one at a time.

**Reporting is not stopping.** Two runs stalled here — the first halted on one ruling (P020) at 8
commits; the second finished a unit, reported, and treated the report as a terminus. After you report,
take the next item.

**The run stops on exactly three things:** a determinism two-process replay divergence, decision-free
work exhausted across ALL lanes, or the time budget. Not a parked ruling. Not a gate block. Not a taste
call. Not finishing something.

### LANE STATUS

| lane | state | gated by |
|---|---|---|
| C · sprites/visuals | **UNBLOCKED and moving** — miner sprite (D0268), headroom (D0269) | — |
| F · HUD/UI | **UNBLOCKED** — the host exists (D0271), depth chip shipped | — |
| A · camera/framing | **UNBLOCKED** — follow/lead/pixel-snap shipped (D0273) | — |
| E · mining feedback | **UNBLOCKED and moving** — cracks shipped (D0275); crumble wants PRE-1 | crumble: PRE-1 (P025) · ring: P024 |
| G · audio | OPEN — the score is wired; SFX want P024's swing edge for the RING only | partly P024 |
| D · harness | OPEN — O(1) hash (D0261), suite selection (D0260), runner diagnostic (D0272) | — |
| B · world-gen, view side | OPEN, decision-free | — |
| B · world-gen, sim side | BLOCKED-ON-DIRECTOR | P021 (15% carve), WG-4 |
| economy | OUT OF SCOPE this run | redesign, sequenced separately |

### DECISION-FREE — work to exhaustion, low-decision lanes first

- [x] **WG-1 · seed truncated to 16 bits** (D0254). Only 65,536 worlds existed. Carried out a latent
      `_grow_vein` ceiling bug with it.
- [x] **WG-3 · single-octave where legacy is 5-octave FBM** (D0258). Ported `FastNoiseLite`'s own
      `GenFractalFBm` onto the existing `sample()` primitive, which is left untouched so its from-scratch
      Python goldens survive.
- [x] **WG-2 · shelf bands impermeable** (D0258). Closed by WG-3, not by a threshold move: 0 → 15 of
      97,920. The wall was a field with no tail, not a line set too high.
- [x] **LANE C · sprites/visuals** — FIRST PASS LANDED (D0268/D0269).
      Remaining: pickaxe swing, tool/item/machine sprites, post-fx, glimmer.
- [ ] **LANE C tail** — miner, pickaxe + swing, tool/item/machine sprites, particles,
      post-fx, glimmer. Pure view, self-tested by capture. Highest item count in the backlog.
- [x] **LANE F · HUD host + depth readout** (D0271). H-01 unblocked all 65 of Lane H's rows.
- [ ] **LANE F tail** — depth readout, strata bands, hotbar, objective card, key hints, map, theme
      grammar. Port-and-refactor, trim dead content.
- [x] **LANE G · audio** — hollow tell and breach (D0293/D0303), **blow-against-material (D0313)**:
      four parameterised strike voices, synthesized at boot, no assets. Remaining: the depth-mixed score.
- [x] **LANE A · camera follow, lead, pixel-snap** (D0273). Shake parks with its trigger (T1 #9).
- [ ] **LANE A tail — zoom/sprite-scale.** View only — body collision width is a resolver
      touch and parks.
- [x] **LANE D · determinism fast-track** (§6) — DONE (D0261) — `state_signature()` to an O(1) running hash, ~74s → ~5s.
      **Guard:** the hash IS the determinism contract; it must update on every mutation path, and a
      forgotten update must be mutation-proven to break a test, or it does not ship.
- [x] **PRE-3 · the L2 door onto the mining verb** (D0274) — unblocked six backlog items.
- [x] **T1 #5 · mine cracks** (D0275). Crumble needs PRE-1's clock and parks.
- [ ] **LANE B, view-side only** — depth shading, light pool, shadow veil, parallax, back-wall. No
      constant, no threshold; runs while B's sim-side sits parked.
- [ ] **P021 measurement (decision-free half)** — instrument TOTAL void fraction (caves + ruins +
      chambers + entry shafts) against legacy's "near 15%". Measuring is free; the remedy is the
      director's.
- [ ] **Standing backlog tails** (§9) — gate 2 filter, Seams doc-drift, empty-state guard rollout,
      the cheap gate fixes, headed-boot CI on Ubuntu.

### NEEDS-RULING — parked, and NOT a reason to stop

- **P021** · the 15% carve gap. Survived the octave port (0.0358 → 0.0329). Closing it is a threshold
  move. Three candidates written out; my recommendation is to measure total void first.
- **WG-4** · cell-denominated constants never converted, every feature 4x undersized in length and 16x in
  area. Squarely a threshold move.
- **P019** · the depth tint, parked on a glimmer hue clash.
- **P015, P017** · the sky. Two images and the director's eye.
- **The terminal economy** · redesign, not port. Sequenced separately, out of this run's scope.

### EXPENSIVE — never decided in-loop

Moving any `data/strata/*.yaml` threshold or cell-denominated constant; changing terrain resolution or
`CELLS_PER_METRE`; any collision-resolver touch; bypassing a gate.

**Gate 7 is not on this list and never was.** Verified 2026-08-31: `docs` is in neither population and
`.md` is not in `CODE_EXTENSIONS`, so the docs-exclusion fix has already landed (D0251). A gate-7 red
means the instrument genuinely outgrew the game, and the remedy is game work — which is why the WG-3 port
belongs in the same arc as the instruments that found it.

## CURRENT — the overnight run of 2026-08-31/09-01

**Fifteen PRs merged green, #16–#31.** Every one rebase-merged, authorship clean. The ledger runs
**D0286–D0313**. What is worth knowing, rather than what happened:

**THE RUN'S DOMINANT FINDING: five separate greens this session were measuring nothing, and four of them
were my own instruments.** They are listed together because the shape repeats and the shape is the
lesson, not any one of them.

- **D0309/D0311 — a capture diff of ZERO has two causes and the output cannot tell them apart.**
  `SeamPainter` shipped correct, mounted, mutation-tested, and its verification capture read **0 of
  2,073,600 pixels changed**. The painter was fine; the moment did not pose it. The move that separates
  "the layer is dead" from "the gate is closed" is an **ungated full-viewport fill from the same layer**
  — it read 99.8%, in one run. Then the fix went stale **within the hour** when D0307 moved the world,
  and the replacement control (`seam_run > 0`) passed on a frame that still diffed at zero, because the
  subject was **posed and off-camera**. "Posed" and "in frame" are different claims.
- **D0310 — a suite printed `ALL PASS` and exited 0 with three of its tests calling methods that no
  longer existed.** Only the D0115 masked-crash detector failed the run.
- **D0312 — a palette test measured `&"stone"`, which `data/materials/` does not carry.** `matrix_color`
  answers an unmapped material with a flat debug brown, so every patch measured a **constant**, spread
  read 0.0000 at both depths, and the surviving comparison was `0 >= 0` and **passed**.
- **D0308 — a mutation escaped because the population could not pose the gate.** The seam-run test
  asserted "every cell shares the worked cell's seam" on a HORIZONTAL run — which walks `(1,0)`, and
  `Seams.at` keys HORIZONTAL to the row, so **every cell in it is horizontal by construction**.
- **D0307 — WG-2's closure assertion is `shelf_frac > 0.0` against a quantity measured at 0, 1, 6, 15
  and 17 cells out of 46,080.** No trend, 17× between adjacent rows, one landing on zero. **That is a
  noise floor**, and the sentence declaring WG-2 closed rested on **one carved cell**. Not touched:
  re-stating a Tier-0 closure criterion is the director's call (**P028**).

**WG-4 is fully converted (D0305 + D0307).** `cave.frequency` 0.11 → 0.0656 ships tuned and
BUILT-PARKED. The sweep behind it **falsified two predictions**: the metre-correct 0.0275 does not make
caves vanish, it **consolidates** them (271 pockets of median 7 → 47 of median 121), and **void fraction
is flat across a 4× frequency change** (0.0822–0.0871), which excludes `MASTER_PLAN_AUG30`'s stated
most-likely explanation for P021's missing 15%.

**Three ports landed with their legacy sources named.** The grain reveal (**D0308**, PRE-4 closed —
`core/seams.gd` had been unwired for four sessions behind one `int`); the stride and the stagger
(**D0310**, T1 #9/#10 — and these port in **pixels**, not metres, because `body.gd` matches legacy's
`RUN_SPEED`/`GRAVITY`/`JUMP`/`MAX_FALL` four for four); per-material strike voices (**D0313**).

**Two shipped guarantees were found to be in genuine conflict and neither was weakened** (**P029**):
legacy's bedding depth boost needs ≥1.83 to clear its own 2× requirement, and anything above ~1.0 pushes
deepstone inside glimmer's 0.25 distinctness floor. Shipped 1.0 — a 53% recovery of post-veil deep
spread — with the frontier parked as a table.

**Determinism held at every world and body change.** Two processes bit-identical (first mismatch −1),
seed+1 control diverging at checkpoint 0, at each of three re-pins. Goldens harvested from CI's own Linux
build per D0167 and cross-checked elementwise against local macOS: **0 of 200 differ, all three times.**

### In flight

Nothing. Every branch this run opened is merged and deleted.

### Open, and parked for the director

- **P028 · WG-2's closure rests on six cells in ninety-two thousand.** The cheap resolution is 200 seeds.
  It gates **P026**: if the true shelf rate was never above zero at `0.11` either, then the metre-correct
  `cave.frequency 0.0275` never re-opened WG-2 and a **seventeen-fold** larger cave is one line away.
- **P029 · the bedding boost and the glimmer floor cannot both be satisfied.** Measured frontier in the
  entry; option (2), re-hueing glimmer away from deepstone, buys the whole range back and is an art call.
- **P026 · `cave.frequency`** — BUILT at 0.0656, with the full sweep table.
- **P027 · the veil's remaining halves** — the amber tint and where `_skylight_alpha` belongs.
- **P004 · the per-commit fuzzer poses neither the corner nudge, nor dig, nor now the stride.** Measured
  this run: its longest unbroken heading in 50,000 ticks is **10** against the **55** a stride needs.

## Earlier — sky_painter draws, and the world has no sky to jump into (D0243–D0250)

**The ◆ is P015 and it is your eye on two images.** `view/visuals/sky_painter.gd` is lifted, wired to the
`Frame`, layer-clean, drawing, and milestone-captured — `docs/milestones/slice3_horizon_23b0ec4.png`
(168 colours) against `docs/milestones/slice3_horizon_sky_23b0ec4.png` (199), four pairs in all, and
`docs/MILESTONES.md` carries the row. What is NOT decided is whether it looks right;
four look calls are itemised in P015 and none of them was tuned, only derived. **Phase 2
(`terrain_painter`) does not start until you look.**

**P013 ruled and ENFORCED, not just written down** (D0243). `view/` may read appearance data from `data/`,
so `data` became a modelled layer rather than an unpoliced one — an unmodelled edge cannot be enforced,
which is the vacuous-gate shape. Mutation-tested both directions: a legal `view→data` edge passes, a
planted `view→sim` edge fails, and `data: set()` is the load-bearing line that stops `data` laundering a
dependency. ADR 0008; the lint's own suite went 8 → 11 branches.

**The recurring test-over-empty-state bug is now a caught class** (D0245). It had landed four times, each
time in a test written by someone being careful. `TestBase.over()` / `_check_over()` refuse an assertion
whose population is EMPTY even when the condition is true, and say VACUOUS rather than an ordinary red.
Mutation-tested: disabling the count check turns the new suite red on 3 assertions and flips its
deliberately-failing line to PASS. **14 call sites across 7 suites.** Two rules came out of the retrofit
and live in the guard's docstring — only assertions that PASS on empty need it (`gaps.size() > 3` already
fails, so wrapping it is decoration), and the population must be COUNTED in the loop, never computed as a
product of constants.

**It found a live one on its first outing.** The three fuzz suites gate on `counts[kind] == 0` and their
only population guard was `summary_line != ""` — a PRESENCE check. A probe that simulated nothing still
prints a summary line, so `total_ticks=0` passes it and satisfies every hard-zero beneath it. The full
sweep now reads `over 1500000 item(s)` where it previously reported nothing at all.

**And that made a second finding fall out** (D0247, P016). The sweep reports `grounded_no_floor=46`
against a bound of **59**, and `bounds=1179015` against a recorded 805,397. **Measured twice,
byte-identical** — so it is a stable count at a moved trajectory, not noise and not a determinism
regression. Nothing is red, which is the point: 13 counts of slack is 13 counts of regression the gate
will not catch. NOT ratcheted, because D0184 is your own ruling that 59 is provisional and moves for
non-regression reasons; P016 has the three options. The `bounds` growth is reported as a number and NOT
diagnosed — a plausible mechanism exists and asserting it without measuring is the move this ledger keeps
correcting.

**THE FINDING THAT OUTRANKS THE REST, and it came from the director playing** (D0249, P017).
*"my head bumps at the surfaceline and i cant jump higher."* Row 0 is the surface datum, the top of the
`TileGrid`, AND `SkyPainter.HORIZON_Y`, all at once. Legacy had `SURFACE_ROW = 20` — twenty rows of air
above the ground; re-keying the band ladder to metres-below-surface (`topsoil from_m: 0`) made it
scale-free, which was right, and dropped the headroom on the way. Jump is a **74px apex, ~18 rows** at a
4px cell, so the capability is there and the world ends one row above the player's head. The rock lid
itself is D0199 and deliberate — without it the first jump of any session leaves the world.

**Why nothing caught it:** `test_reveal_spawn_bounds` measures this exact region every run — it holds
JUMP from every spawn and asserts the head never reaches y=0 — and PASSES. *"The player cannot leave the
world"* and *"the player cannot leave the ground"* are the same measurement from opposite intents. The
invariant guarding the ceiling is indistinguishable from the defect, and only a human trying to jump
could separate them. **Rule P015 and P017 together**: whether the sky is enterable decides several of
P015's look calls with it.

**Nothing had ever opened a window** (D0248). The director ran P015's own documented command and got an
agent-mode run that drove itself 12 ticks and quit. All 42 suites are `--headless`, so this whole class
was invisible: a scene can boot, render, satisfy every assertion here, and still not do what its header
tells a human to type. Three defects — the doc line omitted `--play`; `--play` was parsed outside
`RevealArgs`; and `_test_every_flag_is_reachable` could not see that, because it draws its population
from the PARSER'S OWN KEYS and is therefore blind to what the parser omits (sibling to D0245). Fixed with
an assertion over the SCENE'S SOURCE, and `tools/check_headed_boot.sh` + a `headed_boot` CI job under
xvfb — **186 distinct colours on the runner against 188 locally**, so it genuinely renders.

**Bin A verification pass** (D0246): P014 confirmed (`core/MODULE.md` at exactly 100, cap enforced, zero
headroom — and `check_size_limits.py`'s own header still claimed "98 … two lines", now fixed); refs/t3
cleanup verified positively (0 t3 refs; the one identity separating `--all` from the scanned population is
located, not assumed — `refs/tmp/pr6merge{,2}`); two stale `seams.gd` addresses in the migration map fixed
after D0237 moved it to `core/`, and `sky_painter`'s "reads 8 private fields" caveat closed. One null
result: the cold-read audit's `test_body_fuzz.gd` row was already fixed by D0150.

## Also this run — Phase 1: the coordinator (D0237, D0238, D0240)

**The prerequisites landed and the skeleton is built.**

**P0a — `Seams` is in `core/`** (D0237). `view` may depend on `{interface, core}` and not `sim`, and
`sky_painter` calls `Seams.grain()` five times. `class_name` is path-independent so `test_seams` passes
unchanged. **A correction to my own Phase-0 argument:** I called `Seams` "core-shaped" on the evidence
that it references nothing — that tests what a file *imports*, not what it *means*. `at`/`aligned`/
`RUN_CAP` are mining vocabulary; only `grain()` is domain-free, and it is the only thing `view/` calls.

**P0b — two doors through L2** (D0238). `Observation` carries `walls`/`wall_legend` and a per-column
`Fx` `surface_y`. Neither is a new computation; both existed behind a `TileGrid` that `view/` may not
hold. Each is derived **per window**, so a window above the floor reports `NO_FLOOR` rather than
scanning past its own edge. ADR 0007 amended in place.

**Phase 1 — the coordinator** (D0240). `view/world_view.gd` (101 lines), `view/frame.gd` (57),
`view/paint_layer.gd` (45). **Nothing ported from `reveal_scene.gd`**, which sits at 398/400 with
`_physics_process` at 49/50 — its arg parsing, agent-drive modes and recording flush are ~120 lines of
non-coordinator work and stayed put. `MaterialLook` moved `tests/body/` → `view/visuals/`.

**Evidence:** 42/42 suites pass as of `f38eb03`, determinism included. Layer lint **mutation-tested on `world_view.gd`
itself** — a planted `TileGrid` ref fails with the exact message, removing it passes. **Gate 7 green and
positive: instrument +60 against game +464** (3,762 → 4,226).

**Two things I got wrong and fixed inside the run.** My first draft had a `view → sim` edge
(`Heightfield.TERRAIN_CELL_PX`), fixed by moving the conversion into `Interface.Envelope.covering()` —
and the tempting repair, copying `material_look.gd`'s `CELLS_PER_METRE = 4`, would have been right by
coincidence and wrong by construction. And the new suite's first draft asserted the observation window
was "non-empty" over a window that was **entirely margin**, because a Godot node is not in the tree until
a process frame passes.

## DONE LAST RUN — D0224 to D0233, five PRs

**D0224 — the layer lint had never evaluated an edge.** A REQUIRED CI check printed PASS for weeks while
its own output read `22 files scanned, 0 res://*.gd references checked`. It matched only `res://` paths
against a codebase that couples entirely through `class_name` globals, so every "the boundaries hold"
claim rested on nothing. **38 edges resolve now, 0 violations** — the boundaries do hold, measured.
Plant-proven on the real tree (a `TileGrid` reference in `view/controls.gd` is caught; removing it
returns PASS). It exits 2 rather than passing if it ever resolves zero edges again. **Its own docstring
warned about the blindness and that protected nothing** — a caveat does not travel with a verdict, so
the edge counts are printed on every run now. Sibling reach-in over `class_name` edges is parked (P008):
applying it reports 14 violations that are all ordinary structure.

**D0225/D0226 — two gates made honest.** The size gate linted 8 gitignored scratch files locally and 0 in
CI; `git check-ignore` now gives both one population (94 → 86). The `MODULE.md` 60-line rule that 10 of
18 files broke and nothing read is 100 and enforced — `core/MODULE.md` at 98 has two lines of headroom.

**D0227 — the last unblocked lifts, batch now genuinely dry.** `seams`, `art`, `light_layer`, `settings`.
Game LOC 3,075 → 3,760. `settings.gd` (455) split at its own seam to clear a 400-line gate. `seams`'
float→integer conversion is proven exact over the **entire domain, 196,608 comparisons, 0 disagreements**,
with the naive form kept as a control that must keep failing. **Three of four have no consumer** and
`light_layer` may contradict the ruling that lifted it (P009).

**D0228 — every director recording is now a regression test** (P002's ruling): 6 sessions, 9,718 ticks,
0 bad / 0 airborne / 0 unconsented, with a climb-count positive control so a replay that did nothing
cannot pass. **D0229/D0230** — `test_reveal_spawn_bounds` 81.1s → 61.3s, and the local battery is a
tracked tool that reads the `tests` job (38 suites) rather than grepping the file (39, the extra being
the 1.5M-tick nightly sweep).

**D0231/D0232 — what branch protection broke.** The authorship gate cannot pass a PR: GitHub's synthetic
merge commit is a second committer identity. Fixed by pinning the job to the PR's head. See the warning
at the top of this file for the part that is not fixable in the gate.

**Two defects of mine reached CI and are worth the lesson.** A coordinate-naming violation in `seams.gd`,
because I ran the gate set BEFORE writing the file and never after; and an `ImportError` from inlining
`references_in`, whose caller lives in `coupling.py` — reachability scoped to the one file I was editing.
Both now covered by mirroring the whole gates job locally (27 checks) before pushing.

**One thing worth knowing: `coupling.py` had already made D0224's discovery.** Its docstring records that
a real check found "ZERO res://-based sim/ references but 13 class_name declarations", and it unions both
edge kinds. The insight was in the repository the whole time, in a neighbouring tool.

## THE PRESENTATION BATCH IS MOSTLY BLOCKED — read `docs/NEEDS_DIRECTOR.md` P005

Classifying all 21 code files in the 63-file LIFT set by the legacy types they use **in code with
comments stripped**: ~1,540 lines blocked on the `WorldRenderer` coordinator, ~2,700 on legacy's
`FactorySim`, ~2,050 on `MachineDef`/`RecipeDef` entities this build does not have, and **~945 liftable
today**. The run's own "no coordinator rebuilds" non-negotiable is what blocks most of its own queue.

**Of that ~945, only two files had a CONSUMER** — score and particles, both now done. `art.gd` needs
sprites that do not exist, `light_layer.gd` needs light math in the absent coordinator, `seams.gd` needs
a `docs/BITS.md` not in this tree. **"No unsatisfied dependency" and "has a consumer" are different
questions.** P005 carries the three options; option 3 (un-park the coordinator) is the only route to
changing how the game actually looks.

## SLICE 1.5, the bite — delivered, still awaiting the director's play verdict

Full account in `docs/DECISIONS_LEDGER.md` D0199-D0205. **Result:** `Mining.bite_radius`, a Euclidean
disc, default 2 (0.81 m^2, the largest disc under legacy's metre); `--bite=0` is bit-for-bit Slice 1 and
is the control. The same 24-cell shaft takes **991 ticks at bite=0, 242 at bite=2**. The brief's premise
was false in both halves and the real defect was its opposite (D0200): mining was already at 4px and
collision already ran on it; what was wrong is that one blow removed a sixteenth of a metre while being
charged a full metre's hardness-seconds, **0.06x legacy per unit volume**, unmeasured because the check
was in seconds-per-CELL and the two codebases' cells are different sizes.

**Two rules that outlived it.** D0204: a build handed over for a feel judgment gets played from a CLEAN
CHECKOUT — the director's second session read 8 bad ticks clean and 268 in a dirty tree, 33x. D0201: four
suites written across Slices 0 and 1 were passing locally and running in no CI job at all, including two
mutation-tested bounds controls; gate 31 now reconciles the sets and prints members.

**WAITING ON THE DIRECTOR:** play it (`godot --path . tests/body/reveal_scene.tscn -- --play`, sweeping
`--bite=0/1/2/3`) and rule. **Note the geometry question underneath it:** the world is 48 cells / 12 m
wide, the body is 8.3% of that and 33% of the screen's height at zoom 6. Shrinking the body and widening
the world are the same fix from two ends, and no mining change reaches either.

## STANDING — carried forward, unchanged by this round

**D0193 — the bounds invariant has no magnitude, and it is the director's call** (gate 24's subject). It
fired at 0.3125px and 3.4px; D0055 built it for 15.85px, and this world is 192px wide, so pressing into a
wall is ordinary play. The discriminator is written up: overshoot against `|vel|/TICK_HZ` separates a
wall-press from an escape without a threshold picked to silence a log.

**The fuzzer still never sets `mine_held`.** Gate 26 is green about cursor-aim mining only because it
never exercises it. Named four times now; still its own unit of work. **Line of sight is not ported**
(D0195) — a player can mine through one tile of rock, a real behaviour difference from legacy.

**Standing instruction — milestone recordings and captures.** Every slice, and any work that changes what
a player sees or does, commits the `--play`/agent `.log`, a screenshot, and the commit SHA it was produced
against, **generated from the commit, never hand-typed**, agent-mode always LABELLED. Fixed 1920x1080,
fixed camera, plus a before/after PAIR. `docs/MILESTONES.md` carries the rows;
`tools/capture_moments.sh <slice-label>` is the driver, with `BITE=` and `TICKS=` pinning the two things a
mining change moves — and D0219 is why both halves of a pair must pin them explicitly.

**Slices 0, 1 and 1.5 closed; Slice 2 closed this round.** The Q1 answer that gates the expensive slices
stands: **the palette reads at 16px; the FLECK does not**, so `terrain_painter.gd` is not portable as
written and needs an art pass rather than a port. **`claims/C004` is still untouched on purpose:** four
real human sessions exist, but deciding whether one qualifies is the director's judgment.

## CLOSED — D0139, reverted on the director's ruling; the diagnosis survived, the remedy did not

Shelved on branch **`shelf/d0139-full-footprint`** (`f8186fb`, pushed), reverted from the tree. Recover
with `git checkout shelf/d0139-full-footprint -- sim/body/vertical_resolve.gd tests/test_vertical_resolve.gd`.
Four measurements against it, three from its own investigation: its acceptance signal failed
(`grounded_no_floor` stayed at 59 while attribution flipped, the flaw changing hands); it regressed
`test_body_acceptance`'s HARD gate; it broke `check_size_limits`; and it made real play 33x worse. **Its
diagnosis was right and is closed by D0206 instead** — the criterion really was the bug, but the fix is
one shared full-footprint criterion, not making `resolve_floor` refuse landings while the backstop keeps
the same flaw.

## OPEN, NOT STARTED — the persistent-world GDD reversal

A director brief reversing the 2026-08-25 run-based-roguelite pivot back to a persistent single shaft +
rig-as-consumer (further than the already-closed 2026-08-27 reversal `docs/GDD.md` §9 already records) —
its full text exists only in prior conversation history, not in any tracked doc. A fresh session needs the
brief re-supplied (asked of the director, not reconstructed from a summary) before touching `docs/GDD.md`.

## Standing, unchanged, all reserved for the director

- **`data/economy/`, D1-D6** — the demand-chain content itself; `tools/economy_check/` (parked, D0153)
  waits for it.
- **`history/`'s pre-pivot image cull** — waits on the director, unchanged.
- **`claims/C004`** — no longer blocked on getting a session at all (4 real ones exist now, see above);
  blocked on one that actually produces a qualifying reveal with real dig events on both sides.
- **A Codex finding on THE CONTROL PLANE** (parked, D0155, but the finding stands regardless of whether
  the slice is in the tree): CONSTRAINED restricts distance, not discovery — Anvil FINDING `ed491e83`
  existed only inside the now-parked `.anvil/log/`; recoverable via `git show 4ec12bb:.anvil/log/2026-08-29T095108.038191Z-ed491e83.json`.
