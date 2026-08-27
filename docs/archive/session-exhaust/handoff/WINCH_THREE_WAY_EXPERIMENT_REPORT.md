# Freight Winch hero-machine three-way visual experiment — report

Director-assigned (item 3 of the 2026-08-24 five-item order: "build a three-way Winch hero-machine visual
experiment... Head silhouette; Station silhouette; cable/skip transit; loading, movement, arrival, stalled,
and unpowered states"). Isolation held throughout: three disposable worktrees, no merge, no push, stops at
the director-selection boundary. Mirrors the ITM three-way methodology (`docs/handoff/
ITM_THREE_WAY_EXPERIMENT_REPORT.md`).

## 1. Base SHA

`14d326b` — canonical `main` at the moment all three worktrees were created (after this session's two Winch
mechanical fixes: hand-feed via `machine_eats`, and the `no_power`/`blocked` status split). `main` has since
advanced to `3071898` (Bazaar apparatus, `blocked_station` alert-text fix) — unaffected by and independent
of this experiment; none of the three worktrees needed to be rebased to run it.

Worktrees: `/private/tmp/sinkforge-winch-visual-{A,B,C}`, `git worktree add --detach` at `14d326b`. Three
separate worktrees rather than one with stashes (the ITM precedent), because each option needed real,
independent engine runs in parallel — a shared worktree would have serialized what three parallel builder
agents were doing.

## 2. Exact files changed per option

| Option | Files | Diff stat | Commit |
|---|---|---|---|
| Baseline | none | reference state, `main` unmodified | — |
| A (conservative repair) | `scenes/visuals.gd`, `scenes/world_renderer.gd` | 2 files, +76 / −6 | `6ac68d6` |
| B (system-level correction) | `scenes/visuals.gd`, `scenes/world_renderer.gd` | 2 files, +142 / −6 | `69d7248` |
| C (distinctive alternative) | `scenes/machine_view.gd`, `scenes/visuals.gd`, `scenes/world_renderer.gd` | 3 files, +173 / −7 | `2a8f129` |

No option touched gameplay, save schema, thresholds, the harness, or any system beyond the Winch's own
rendering — each was scoped to `MACHINE_PROFILE`/`draw_machine_glyph` (silhouettes) plus one new draw pass
in `world_renderer.gd` (the cable/transit overlay), matching the brief exactly.

## 3. What each option built

**A — conservative repair.** Distinct `MACHINE_PROFILE` crowns for Head (a drum with an axle spool, 5
spokes that rotate while active) and Station (a shallow catch-basin with a glinting payload drop). A
straight-line cable + moving skip glyph in `world_renderer.gd`, following the same pattern the existing
power-pulse bead effect already uses. The existing `Visuals.STATUS_LOOK` lamp language reused as-is — no
new marks.

**B — system-level correction.** Head and Station share one `MACHINE_PROFILE` crown (a wide "drum" — the
family resemblance is the point), differentiated by exactly one tell each (an intake lip on the Head, a
discharge chute on the Station), both drawn through one shared `_winch_drum()` helper so the pair is
literally the same code, not just similar-looking code. A sagging cable whose tint is driven by the *same*
`sim.machine_status()` read the corner lamp already uses, so the cable and the lamp can never disagree.

**C — distinctive alternative.** A headframe/bunker silhouette pair (touches `machine_view.gd` as well as
`visuals.gd`) with a real sagging cable and a moving skip, going furthest from the shared "hopper" glyph of
any option.

## 4. Captures

16 named states per option (64 total + 16 baseline = 80), identical seed (1337), identical fixture (Head
and Station placed 8 cells apart with a cleared corridor between them so the cable's full span sits in one
wide shot), identical camera poses across baseline/A/B/C, via one shared, unmodified capture rig
(`tools/_scratch_winch_visual_capture.gd`, gitignored scratch, run through `tools/with_machine.sh` for
every invocation). States: `unlinked`, `idle`, `no_power`, `loading`, `movement` (at 25/50/75% transit
progress, posed directly against `sim.winch_transit`'s own fields rather than timed), `arrival` (posed by
setting `ticks_remaining=1` and stepping once, so the real `_advance_winch_transit` delivers the cargo — not
narrated), `stalled` (the Station backed up to `WINCH_STATION_CAP`, then the Head fed — both `_run_winch_head`
and `_status_winch_head` refuse/report for real, not simulated). Each state captured close (on the Head or
Station) and/or wide (both endpoints + the full cable span), matching what that state needs to demonstrate.

All three builder agents ran the identical rig unmodified and verified their own results against it before
reporting; none of them found the rig itself needed changes.

## 5. Weighted score table

Three independent evaluator agents, fresh (not forked — no inherited build-process context), each given
the SAME curated capture subset per option but a DIFFERENT presentation order (to control for the position
bias a comparative vision judgment is known to carry) and a DISTINCT persona lens, scoring against the
director's own rubric (`docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md`, weights in parenthesis).
Evaluator 1 scored first-read hierarchy/play legibility/material honesty/restraint; evaluator 2 scored
identity/motion clarity/integration/cost-risk; evaluator 3 scored play legibility/motion clarity/restraint
(overlapping with 1 and 2 by design, so those three dimensions carry two independent readings, averaged).

| Dimension (weight) | Baseline | A | B | C |
|---|---|---|---|---|
| First-read hierarchy (20%) | 3 | 5 | 3 | 7 |
| SINKFORGE identity (20%) | 1 | 3 | 5 | 4 |
| Play legibility (15%, avg of 2) | 3.0 | 5.5 | 4.0 | 5.5 |
| Material/physical honesty (15%) | 1 | 4 | 1 | 7 |
| Integration (10%) | 2 | 3 | 4 | 5 |
| Motion/state clarity (10%, avg of 2) | 1.5 | 4.5 | 3.0 | 5.5 |
| Restraint (5%, avg of 2) | 6.0 | 6.5 | 6.5 | 5.5 |
| Cost and risk (5%) | 8 | 6 | 8 | 8 |
| **Weighted total (0–10)** | **2.45** | **4.40** | **3.78** | **5.80** |

**All three evaluators independently scored C highest on identity/first-read/material-honesty questions.**
The weighted total ranks **C > A > B > Baseline**, and C's lead is not close (5.80 vs. 4.40) — but see §6:
this is not the same as unanimous agreement on what should ship.

## 6. Evaluator disagreement report

Reported as disagreements, not averaged away, per the director's own rule ("the agent may recommend one,
but it may not silently choose its favorite").

**Evaluator 1 (first-time player) and evaluator 2 (identity)** both independently favored **C**'s sagging
cable as the strongest single element across all three options — evaluator 1: *"the clearest, most
immediate 'these two belong together' of the three"*; evaluator 2 scored it highest on identity and
motion clarity. Evaluator 2's closing opinion, unprompted: *"I'd take C's cable rendering and graft B's
spool glyph onto it rather than ship either alone"* — a genuine hybrid recommendation, not a clean pick.

**Evaluator 3 (systems-legibility) personally preferred A**, for reasons the other two evaluators' curated
image sets didn't surface: A's loading state shows *"a bright glowing square pip... the highest-contrast
'cargo present' cue of the four sets"* and its stalled state shows *"a distinct padlock-shaped icon... a
real, non-color-dependent signal none of the others have."* This is a real disagreement, not noise — it
turns on state-transition legibility specifically, a dimension only evaluator 3 scored in depth, and it is
evidence AGAINST simply shipping C outright: C won on identity and first-read, A won on the specific
question of "can you tell loading from stalled from moving without reading text."

**Option B's central idea — a shared drum grammar, cable tint driven by the same status the lamp reads —
was independently praised in principle by all three evaluators and independently marked as under-executed
by all three on contrast.** Builder self-report: *"the 1.6px cable line is faint against a busy
background."* Evaluator 1: *"I could not find any visible link between Head and Station in any of the five
frames"* (Treatment 2 in their order = B). Evaluator 2: *"very low-contrast against the sky, easy to miss
entirely at wide-shot scale."* Evaluator 3: *"the pip is orange-on-orange, low contrast against the cable
itself"* (this specific note was on C, not B, but the same contrast complaint recurs against B's cable
throughout their read). **Three independent readings and the builder's own converge on the same specific,
fixable defect** — this is the strongest-evidenced single finding in the whole experiment, and it is a
contrast/line-weight problem, not a concept problem.

## 7. What each option improves over baseline

All three: give the Head and Station *some* visible connection where baseline shows none at all (baseline's
cable is entirely absent — evaluator 1: *"no cable, no cargo icon, no motion cue"*), and all three give the
two machines at least one point of silhouette differentiation baseline never had (baseline: literally the
same glyph, tinted).

A: lowest risk, cleanest diff, reuses the existing status-lamp system without touching it — the safest
"remove the obvious defect" answer, and it scored the best state-transition legibility of the three per
evaluator 3.

B: the only option where the cable's color is mechanically tied to the same status read the corner lamp
uses (evaluator 2: *"the physical object and the lamp can't disagree"*) — the most architecturally coherent
idea, undermined by its execution's contrast.

C: the strongest single first-impression win — sagging cable weight, a genuinely different Head/Station
silhouette pair, the only option to touch `machine_view.gd` as well as the two files the others confined
themselves to.

## 8. What each option damages or costs

None of the three regress any harness layer (`SF_ONLY='check_status_reads|check_casing_light|sim
\(core|play-tests'` green on all three worktrees, each independently). None touch gameplay, footprint, or
verbs.

A: the least distinctive of the three per two of three evaluators — evaluator 1: *"a wire, not a winch
cable"*; evaluator 2 ranked its identity score lowest of the three treatments (tied with B's motion score).

B: the cable-contrast defect in §6 is real and reproducible across every independent read; as captured, a
player is unlikely to notice the linking cable exists at normal play zoom.

C: went furthest from the existing rendering conventions (the only option to touch a third file), which is
the most implementation risk of the three, though nothing in verification caught an actual defect from it.

## 9. What remains unproven, and one gap this exercise surfaced that no option addresses

**"Movement" is not legibly shown by ANY option at normal wide-shot scale**, per every evaluator
independently. A moving skip glyph exists in all three builders' code and is confirmed present in the
close-range captures, but none of the three make it read as *moving* cargo in the wide establishing shot a
player would actually see during normal play — this needs either a bigger/brighter transit marker or a
tighter default camera framing near an active route, not a treatment-specific fix.

**The Station's own status lamp does not distinguish "receiving normally" from "so full it is blocking the
route."** Evaluator 3, independently and unprompted, on all four capture sets equally: the Station in the
`stalled` state shows the same green "working" mark it shows in ordinary operation, because the Station
runs `_status_mover`'s convention (working while it holds anything) and has no awareness that its own
fullness is the reason the Head can't queue a trip. This is a real, mechanically-grounded finding — not a
treatment defect, since none of the three options were asked to change Station-side status — but it is new
information this exercise surfaced and none of A/B/C fix it. Recorded here rather than fixed mid-experiment,
per the isolation rule against touching gameplay/status mechanics inside a visual-comparison worktree.

**The captures predate this session's `blocked_station` alert-text fix.** Evaluator 3 correctly observed
*"Winch Head — output blocked — dig a drain"* in every capture set, including all three treatments — this
was accurate at the time of capture (`14d326b`) but is already fixed on canonical `main` (`3071898`,
`&"blocked_station"` with correct text, committed the same session). Not a live defect; recorded so nobody
re-discovers it as new.

## 10. Recommendation

The weighted synthesis and two of three independent evaluators favor **C** as the strongest single visual
identity, by a real margin — but the honest recommendation is not a clean pick. Evaluator 2's own closing
words were the most concrete: *C's physical cable rendering is the best executed of the three; B's shared
drum-grammar concept and status-driven cable tint is the most architecturally right idea; A's state-specific
cues (the glowing loading pip, the stalled padlock) are the clearest for telling states apart without
reading text.* Given the director's own rubric explicitly weights identity (20%) and first-read hierarchy
(20%) above motion/state clarity (10%), the numbers say **C**, but state-transition legibility — arguably
the more player-facing-important property for a machine whose whole job is to communicate "is this working
right now" — was C's comparatively weaker showing (5.5 vs. A's implicit strength there per evaluator 3).

**This report does not select an option.** Per the protocol, the director selects; the recommendation above
names the real tradeoff rather than picking for them.

## 11. Exact patch for each option

Recoverable from each worktree's own commit, none merged or pushed:

- A: `/private/tmp/sinkforge-winch-visual-A`, commit `6ac68d6`
- B: `/private/tmp/sinkforge-winch-visual-B`, commit `69d7248`
- C: `/private/tmp/sinkforge-winch-visual-C`, commit `2a8f129`

`git diff 14d326b..<commit>` in the relevant worktree reproduces each patch exactly. All three worktrees
and their captures (`/private/tmp/sinkforge-winch-captures/{baseline,optionA,optionB,optionC}/`, 80 PNGs
total) are retained pending the director's selection.

## 12. Isolation and integration rules — held

Three disposable worktrees, each touched only rendering-layer files. No merge, no push, no edits to
canonical `main`'s gameplay, save schema, thresholds, or harness registry from any worktree. Each option
preserved as a worktree commit rather than deleted. Stops here, at the director-selection boundary — the
same stopping point as the ITM three-way experiment.
