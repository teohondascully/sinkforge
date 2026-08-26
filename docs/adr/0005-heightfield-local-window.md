# ADR 0005: The ground-plane query is a local windowed scan, not a global per-column heightfield

**Status:** accepted, 2026-08-26.

## Context

An external Codex audit flagged `docs/ARCHITECTURE.md` §9's heightfield ground-plane design: "derive a
per-column surface height from the fine terrain... sub-pixel column heights, linearly interpolated
between columns" cannot represent a floor under a reachable overhang — two disjoint walkable air
pockets in the same terrain column — because a single scalar per column has no room for a second
answer. This ADR resolves that finding and the investigation it triggered. Deliberately kept as three
separate findings rather than one, because collapsing them into "the audit found a bug and we fixed
it" would lose two things that are each independently true and each independently load-bearing for a
future reader: the spec's own defect, and the fact that the shipped code had already moved past it
before anyone noticed either way.

## Finding 1: the specification was wrong

`docs/ARCHITECTURE.md` §9, as originally written, described an unqualified per-column surface height —
one Fx scalar derived from scanning the whole column. That representation genuinely cannot encode a
floor beneath a reachable overhang: "the height of column X" is a single value, and a column with two
disjoint walkable air pockets has no single correct answer to give it. Codex was right to flag this as
a real representational gap, not a false positive. This finding stands on its own regardless of what
the actual implementation does — a spec can be wrong even if nobody ever built it as written.

## Finding 2: the implementation had already diverged from that spec, in the right direction

`sim/body/heightfield.gd`'s actual code was never the global scan the spec described.
`column_surface_y(grid, terrain_col, scan_from_row, max_rows)` is a bounded query over an explicit row
window, not the whole column, and its only real caller, `sim/body/body.gd::_resolve_floor()`, always
passes a small window centred on the body's own current position: `scan_from = maxi(0, row - 2)`,
`max_rows = 6`. Nothing in `docs/ARCHITECTURE.md` §9's prose mentions this window; the spec describes an
unqualified per-column height and the code implements a local one. Investigating Finding 1 (`sim/body`
present and exercised, one real call site, no stored structure to migrate — recorded in this session's
own scoping pass before any measurement was taken) is what surfaced this gap between what was written
and what was built.

This is worth stating as its own finding, separate from "the spec was wrong," because the two claims
are not the same claim and do not carry the same weight. A wrong spec that was faithfully implemented
is a defect to fix in the code. A wrong spec whose implementation had already moved past it, in a
direction that happens to bound the exact failure mode the spec couldn't represent, is a defect in the
*documentation* — the code was already better than what described it. That is still drift: nobody
decided to narrow the query to a local window, and nobody updated the spec to say so once it happened.
Recording it here is what keeps "the implementation is right" from reading as "so there was never a
problem" — there was a problem, in the doc, and it went unnoticed specifically because the code never
exhibited it.

## Finding 3: measurement showed the residual case is rare enough that the trade holds

A local window bounds the overhang problem, it does not eliminate it. Two disjoint walkable floors
closer together than the window itself can still tie inside one call to `surface_y_at_x`, and
`_resolve_floor` picks whichever is higher (`mini` of the three foot/centre samples) with no knowledge
that a second, lower one exists — no finite window closes this completely, only bounds how far apart
two floors have to be before it can happen (`Body.FLOOR_SCAN_ROWS`, see "The guard, and what it
actually covers" below, for the measured width this project actually uses). The question this session
was asked to answer, before
proposing anything: how often does `sim/terrain_gen/shaft_generator.gd`'s real cave generation actually
produce that shape, and how much of it is genuinely reachable rather than merely present.

**Method.** A throwaway analysis script (never committed) drove the real `ShaftGenerator` against the
`shallow_clay` site config across 100 seeds, full-depth shafts (4,800 terrain columns total). For each
column: found maximal vertical open runs of at least `Body.HEIGHT_PX / CELL` (10 rows) — "pockets" —
bounded below by real solid rock. Built a reachability graph over adjacent columns' pockets via
union-find: two pockets are connected if their open row-ranges overlap, and the climb from either
pocket's own floor up into that shared band is within the body's real reach (`max(STEP_UP_CELLS=4,
MANTLE_CELLS=8, max_jump_cells)`) — falling to a pocket's own floor from inside the shared band is
unconditional (no fall damage exists at this stage, so any drop is valid), only the climb direction
needs a budget. `max_jump_cells` (18) was measured empirically: a straight-up jump held to its true
peak under the real `Body.JUMP_VELOCITY`/`GRAVITY_PER_TICK`/`APEX_FLOAT_TICKS` constants, not derived
from the continuous projectile formula — the two disagree because of the fixed-tick apex float, and
using the formula would have quietly mis-sized the whole reachability graph in a direction nobody would
have thought to check.

Two bugs in this method were caught and fixed before the numbers below were trusted. First, an early
adjacency check compared a pocket's floor row (by definition solid) against the *other* pocket's own
open range (by definition never containing a solid row), which could never be true — it reported 0%
reachable against 82% raw multi-pocket columns, an obvious contradiction caught by hand-inspecting a
few adjacent columns' raw pocket data rather than by re-reading the code, and fixed by comparing the two
pockets' open-range *overlap* instead. Second, the fixed version applied a single symmetric height cap
to both climbing and falling, when only climbing needs one; correcting to the asymmetric model above
moved the final number by less than half a percentage point (0.75% → 0.85%), which is itself evidence
that most of the naively "connected" pairs were never reachable even under the more permissive correct
model.

**Result.** Genuinely reachable multi-floor columns: **0.85%** (41 of 4,800). Shafts containing at
least one such column: **12%** (12 of 100). Distribution: mostly isolated single columns, not
contiguous runs — median run length 1, longest observed run 9 columns.

**Superseded by D0045/D0046 — this was largely an artifact, not a property of the terrain design.**
Left as written below because the ledger is append-only and this is what was actually measured at the
time, but the reading has to be sharper than "the number is stale." This measurement ran against
`ValueNoise`'s output at roughly 1.7x `FastNoiseLite`'s real standard deviation — legacy's cave
thresholds (`threshold_top`/`threshold_deep`) were tuned against the NARROWER distribution and ported
into this codebase unchanged, so the wider one cleared them far more often than legacy's own tuning
ever intended. D0045 corrected the calibration; D0046 re-ran this exact method against the corrected
generator and found **0 of 4,800 reachable columns**, down from 41. That is not "the same phenomenon,
measured smaller." Two different claims, and they are not the same finding:

- *What this document originally said*: a real design trade-off exists — the local-window query cannot
  represent a floor under a reachable overhang — and its residual cost is low enough to accept rather
  than build stateful tracking for.
- *What is actually true*: the representational gap is real (Finding 1 stands on its own regardless —
  a global heightfield genuinely cannot encode two floors in one column), but the specific TERRAIN SHAPE
  that would have exercised it was, to the resolution of this measurement, an artifact of a bug in an
  adjacent module (`ValueNoise` carving denser than legacy's tuning intended), not a property of the
  cave-generation design Codex's audit was actually looking at. Legacy never intended this geometry to
  occur at the rate the uncorrected generator produced it. Fixing the adjacent bug removed the case
  this ADR was built to accept, rather than merely shrinking it.

The second framing is both more accurate and the better record: it says the terrain design was never
actually the source of the residual risk this ADR spent its effort accepting, and a reader relying on
"we accepted a documented limitation" alone would misattribute the fix (D0045) to a decision (this ADR)
it had nothing to do with.

**0/4,800 is not zero.** It is a null result below the resolution of a 100-seed sample — the correct
reading is an upper bound (roughly 0.06% at this sample size by a standard zero-count estimate), not
"the case cannot occur." A rarer residual, or one the corrected generator's other site configs produce
at a different rate, is not ruled out.

**The guard stays, and this changes what it's for.** Before D0045/D0046, `Invariants.check_floor_selection`
existed to measure a known, accepted, non-zero cost. After, its job is different and arguably more
valuable: it is now the ONLY thing that would tell us this case reappeared — from a future noise change,
a new site config, a threshold retune, or any other change to cave generation — without anyone having to
think to re-run this measurement by hand. A guard that fires zero times in normal testing and exists
specifically to catch a regression nobody is currently watching for is exactly the shape of instrument
worth keeping even when its current incidence is a null result.

**Decision.** Accept the local-window query's representational gap (Finding 1) as a real, permanent
property of this design — a global heightfield genuinely cannot do better without the stateful tracking
below — but do not treat 0.85%/12% as the residual cost that trade was made against; that number's own
terrain shape has since been shown to be substantially an artifact of D0045's bug, not of the design.
Do not build stateful floor-selection tracking (continuity across ticks, remembering which pocket the
body last stood in): even under the corrected generator, where the measured case is now a null result,
there is no positive evidence of a real cost to weigh against that mechanic's design cost. This is what
D0042 (`docs/DECISIONS_LEDGER.md`) records as its own point: a documented trade-off whose cost was never
measured is an assumption with better formatting, not a decision — this ADR exists so the next reader
inherits a measured trade instead of an assumed one, including the correction to that measurement.

**Rejected alternative:** build the stateful selection anyway, on the grounds that "genuinely
reachable" cases are exactly the ones a player will eventually stand in. Rejected on two independent
grounds, stated separately because either alone would have been enough. First, as measured before
D0045/D0046: the cost of *not* building it — a player meeting a silently-wrong floor roughly once every
eight runs, scattered, median one column wide — was real but low against the design cost of continuity
tracking (the query would need to know which pocket the body was last resolved into, and prefer staying
consistent with it across ties). Second, as understood after D0045/D0046: most of what that cost
estimate was based on has since been shown to be an artifact of a noise-calibration bug, not a property
of the terrain design, so building a stateful mechanic to serve it would have been solving a problem
that — to the resolution of the best available measurement — does not currently exist. The guard below
converts the residual cost from "silent" to "measured," which is the cheaper fix for what actually
matters about a rare case: not eliminating it, knowing when it happens.

## The guard, and what it actually covers

`sim/invariants/invariants.gd` (`Invariants.check_floor_selection` / `report_floor_selection`) is wired
into `_resolve_floor` diagnostically (D0043) — it never changes which floor gets picked, it only
detects when the chosen floor's own scan window also contains a second real, walkable-clearance floor,
and logs it (`push_error`, not `assert()` — see below) with column, both candidate rows, seed, and
position. This is what turns "player reports standing on the wrong floor, no error, no way to
reproduce it" into a position-and-seed-reproducible event. Originally framed as a way to compare a
real-play incidence number against the 0.85%/12% generated-terrain figure; per D0046, that figure is
now a null result (0/4,800), so the guard's live purpose going forward is different and, if anything,
more load-bearing: it is the only thing that would notice this case reappearing after a future noise,
threshold, or site-config change, without anyone having to re-run D0042's measurement by hand to find
out. A real-play report from this guard is no longer "the incidence we expected," it's a signal
something upstream changed.

**Correction, same day (D0044): the first version of this guard could not do that.** It shared
`_resolve_floor`'s original 6-row window exactly, and `tests/test_cave_geometry.gd`'s first pass proved
the guard was silent on a fixture built to match this ADR's own "genuinely reachable" definition — a
shelf and a lower floor 16 rows apart. A window that cannot span 16 rows cannot report a 16-row-apart
violation; the guard reported zero not because the case doesn't happen, but because it structurally
could not see it. A check that cannot be nonzero is not evidence, it's a check that looks like one — the
director's own framing, and correct. Two resolutions were on the table: keep the window narrow and state
plainly that it cannot validate 0.85%/12%, or widen the window and measure what that costs. Widened.

First, whether widening is even safe was verified empirically before committing to it, because the
naive worry is real: if `_resolve_floor`'s window directly gates which floor a *falling* body snaps
onto, widening it should let a body detect a distant floor from far above and teleport down to it,
breaking ordinary free-fall. It doesn't, and re-reading the code shows why: `if surface == NO_FLOOR or
_bottom_y() < surface: on_floor = false; return false` gates every candidate on the body having
*already physically reached* it — the window only controls how far the query can see, never when a
body is allowed to land. A wider window lets the query notice a real floor sooner; it can't make the
body arrive there sooner. Confirmed both by direct experiment (temporarily setting the window to 40 in
a probe changed nothing about a normal fall's tick-by-tick trajectory) and by the full acceptance suite
staying byte-identical at the final width (below).

Second, the width itself is measured, not guessed. Re-running this ADR's own reachability analysis
(same method, same 100 seeds / 4,800 columns) and this time recording the row-gap between a
genuinely-reachable column's own two floors — a quantity the original measurement never captured, only
lateral clustering across columns — gives, across 197 gap samples: min 11, p50 16, p90 23, p95 24, p99
36, max 36. `sim/body/body.gd`'s `FLOOR_SCAN_ROWS` is now **48**, covering the observed max with
headroom. `tests/test_cave_geometry.gd`'s own 16-row fixture sits almost exactly on the measured
median (16), which is a useful cross-check that the fixture is representative, not a chosen-to-pass
outlier.

Third, the perf cost, measured rather than assumed: an in-process microbenchmark (200,000 `tick()`
calls on a body at rest, isolating per-tick cost from Godot's own process-startup noise) measured
**37.2µs/tick at the original 6-row window, 55.3µs/tick at 48 rows** — a real ~18µs/tick increase, all
of it from the diagnostic check's own scan (the resolve calls themselves cost the same at either width
once a floor is found on the first row, which is the common case). Against `docs/ARCHITECTURE.md` §10's
sim-tick budget (≤2.0ms p50 / ≤4.0ms p99, at a much larger scale — 2,000 machines, 20,000 items,
40,000 active fluid cells — not the one player body this cost belongs to), 55µs is under 3% of the p50
budget for the *entire* simulation, for a cost that exists exactly once (there is one body). Accepted
as negligible; not optimized further, since there is no measured reason to.

With the corrected window, `tests/test_cave_geometry.gd` was rewritten (its first version's whole point
— proving the narrow window couldn't see the case — is no longer true) to prove the *opposite*, using
`Body.FLOOR_SCAN_ROWS` directly rather than an arbitrary widened test value: the guard now genuinely
fires standing on the shelf, both via a direct `check_floor_selection` call and via a real `Body`
settling through real `tick()` physics (`push_error` visibly firing in the suite's own stderr). A new
finding surfaced by that same rewrite: the guard logs on *nearly every call*, not once — one ~400-tick
settle onto the ambiguous shelf produced, measured directly by mutation-testing the fix below
(temporarily reverting it and re-running the same probe), 778 near-identical log lines, not merely once
per tick: `body.gd::_move_and_resolve_vertical` calls `_resolve_floor` twice on most resting ticks (once
inside its substep loop, once via its own trailing catch-all), so an unratelimited guard fires roughly
twice per tick. This would bury the signal a real occurrence exists to produce and make an incidence
count impossible to derive from real play. Fixed (D0052), not merely flagged: `sim/invariants` stays
deliberately stateless (its own `MODULE.md`: "produces no gameplay state itself"), so the de-duplication
lives at the CALLER instead — `sim/body/body.gd::_resolve_floor()` already tracks the body's own
position every tick, and now suppresses a repeat report while the resolved (column, floor) pair is
unchanged, regardless of how many times `_resolve_floor` runs that same tick, clearing that memory the
moment the violation itself clears so a later recurrence — even at the identical pair — is treated as a
fresh episode. `tests/test_cave_geometry.gd` proves this directly: the same ~400-tick settle that
produced 778 lines under the reverted gate produces exactly one under the real fix.

**`push_error()`, not `assert()`.** `docs/ARCHITECTURE.md` §4's "Invariants, asserted continuously"
states "panic in debug, log in release." This module logs unconditionally in both build types instead.
`core/MODULE.md`'s own documented, empirically-verified hazard: an unguarded runtime error inside a bare
`--headless --script` run does not crash the process, it hangs indefinitely with no exit code and no
further output — the same finding that shaped `Fx.div()`'s zero-guard. A failed `assert()` is a runtime
error by the same mechanism, so a literal panic would carry that same hang risk in exactly the headless
test/gate context invariant checks need to run cleanly under. `push_error()` already surfaces loudly
(editor debugger, release log) without that risk, so "panic in debug" is read here as "surface it
loudly," not "halt the process" — a stated reinterpretation, not a silent deviation, recorded as its own
point in D0043.

## Consequences

- `docs/ARCHITECTURE.md` §9 now describes the local windowed query as the actual design, with this
  ADR and the measured incidence cited inline, so a reader no longer has to discover the divergence
  between prose and code the way this investigation did.
- `sim/body/body.gd::_resolve_floor()` gained one diagnostic-only block (reports to `Invariants`, reads
  nothing back, changes no behavior) and a new named constant, `FLOOR_SCAN_ROWS = 48` (D0044, widened
  from the original 6), shared by the resolve calls and the diagnostic check on purpose — confirmed via
  full acceptance-suite re-run, both at the original width and again at the final one:
  `tests/test_body.gd` (17/17), `tests/test_body_acceptance.gd` (9/9, `velocity_efficiency` 0.9978 and
  `traverse_time` 225 ticks against golden 225, byte-identical at both widths), zero invariant
  violations fired anywhere on the existing scripted chamber (expected — no existing section has
  multi-level geometry).
- `sim/invariants` gained its first real code and its first sim-internal consumer (`sim/body`). Its
  MODULE.md's "nothing in `sim/` reads its output back" still holds in the sense that matters — no
  gameplay decision depends on a violation — even though a sim module now calls in.
- `tests/body/hostile_chamber.gd` gained a cave-geometry section (tunnel, one overhang shelf, one gap)
  outside the scripted traversal span, and `tests/test_hostile_chamber.gd` / `tests/test_cave_geometry.gd`
  assert what the current query actually does against it, not that the limitation is solved.
- No `sim/body` behavior changed. No `docs/ARCHITECTURE.md` constant changed. The rewrite this ADR was
  originally scoped to build did not happen — this document is what happened instead.
