# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-30.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**THE WORKFLOW CHANGED THIS RUN.** `main` is branch-protected: no direct push, work goes through a PR,
and three checks are required to merge. **Merge by REBASE, never merge-commit or squash** — either of
those writes `noreply@github.com` permanently into `main` and the authorship gate then fails on every
later commit, with no remedy short of a history rewrite. `docs/NEEDS_DIRECTOR.md` P010, D0231.

**Reset this round:** the parked queue `docs/NEEDS_DIRECTOR.md` is at **9 items** — read it FIRST if you
are the director picking this up. P011 is CLOSED (you ruled it); P013 and P014 are new and cheap.

**TWO PRs OPEN, STACKED.** #6 carries Phase 0 (the contract) and is parked on gate 7 alone — P012.
#7 carries the prerequisites + Phase 1 and is branched off #6, so the ledger stays sequential.

## STOPPED AT ◆ — Phase 1 delivered, awaiting your review (D0237, D0238, D0240)

**The prerequisites landed and the skeleton is built. Phase 2 does not start until you look.**

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

**Evidence:** 39/39 suites pass, determinism included. Layer lint **mutation-tested on `world_view.gd`
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
