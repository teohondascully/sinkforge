---
id: C006
title: A ~200 m vertical commute spends its minute traversing, and the meter says how much
status: PASSING
kind: structural
owner: engineering
created: 2026-09-12
last_measured: 2026-09-12
first_failed_at: 2026-09-12
scenario: scenarios/commute_200.yaml
---

## Claim

Between the face at the foot of a 100 m bore and the forge on the surface, a round trip on foot and
line — fall in, mine, climb back out one chained grapple bite at a time, feed the machine — is a
commute whose decision-minute is spent traversing, not working. The claim is the split itself: the
meter reports what the run was spent on, and traversal is its largest share.

## Why this matters

The minute-25 question the director keeps asking is whether the shaft commute is a cost the game
can afford — "the shaft is one number that goes up" is the failure shape, and an unmeasured answer
is a guess. `docs/CLAIMS.md` §7 asks whether long commutes stay acceptable; the only honest way to
answer is to build the commute and measure what it costs. This claim is that instrument: it pins a
real ~200 m vertical round trip (down a hundred, work, back up a hundred) and reports the
traversal/digging/processing split every run, so a movement or grapple change that re-prices the
commute shows up here first.

The ascent half is itself evidence: `Grapple.MAX_RANGE` is ~30 m, so a 100 m shaft cannot be
climbed in one shot — the measured policy chains bites up the bore wall, which is exactly the
climb a player performs and exactly the kind of minute-25 activity the question is about.

## Falsifiable form

On scenario `commute_200` (fixed seed, the `commute_200` start on `shallow_clay`), the scripted
`commute` agent: walks to the bore's lip, descends the hundred metres, mines the ore face in its
foot wall, ascends the west wall by chained grapple until the lip mantle tops out, and delivers
ore and coal to the forge in its well. The claim holds iff, on the run's own observation channels:

- every leg completes and the fed forge reads `working` (the goal event),
- the decision meter's report is non-empty — the run produced per-minute bins and counted payloads,
- the `traversal` bucket (walk_to + descend + ascend_grapple) is the largest share of counted
  decisions, with `digging` (the face) and `processing` (the feeds) each holding a real share.

## Metric

`tools/measure_decisions.gd -- commute_200` prints the per-minute decision table and bucket totals;
`tests/test_commute_report.gd` asserts the clauses above against `ScenarioDriver.run_metered`.

## Threshold

Traversal is the largest bucket of counted decisions — the commute is a commute. The share itself
is reported rather than thresholded: the first measurement stands as the reference value, and a
later run whose traversal share collapses (faster work, slower travel, a shaft that teleports the
climb) is the failure the claim exists to catch.

## Current value

**Measured 2026-09-12: 608 decisions in 10.1 s — traversal 490 (80.6%), digging 60 (9.9%),
processing 58 (9.5%); the forge read `working` with `{ore:5, coal:2}` in its intake** (D0647).
The descent fell 100 m in 193 ticks (~3.2 s); the chained ascent climbed back in 250 ticks (~4.2 s)
over six bites; 240 of the 608 emissions were empty frames — the fall and the hook flights inside
those legs. `first_failed_at` is the same day's WIP run: the first ascent state machine read
`anchored` for "bite", which a chained shot never drops — the hook re-fired every other tick, the
tip sawtoothed at the hand, the body hung 17 m short of the rim until `THROW_CAP`, and the stall
left it on the rope while the deliver legs burned 3200+ ticks of hops.

## What this claim does not measure

- **Whether the commute is FUN.** Ten seconds of fall-and-climb per trip is a structural cost; the
  experience claim (does the shaft stay interesting the fortieth time) is unwritten.
- **A loaded or longer mine.** One face, one forge, 100 m. The 200 m question scales with the
  shaft; deeper fixtures are the same claim at a larger number.
- **The commute under cargo or damage.** The pack held ore and coal; weight, water, and a hurt
  body are unmeasured.
- **What a player would do.** The policy is scripted and knows the fixture — a human's commute
  includes mistakes, rope placement, and shortcuts this route never attempts.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-09-12 | wip | commute_200 | legs_ok=false — ascent stalled on the chained-shot observable; body hung on the rope, deliver starved | FAILING | `first_failed_at`. The throw loop treated `grapple_anchored` as the bite signal; a chain never drops it. |
| 2026-09-12 | D0647 | commute_200 | 608 ticks — traversal 490, digging 60, processing 58; forge `working` | PASSING | Resolution is `grapple_throwing` ending; a find is `grapple_length` growing. Near the rim a reeled-out line is the lip mantle's window, not a miss — the rim hold replaced the re-bite loop, the mantle topped out at (39,20), and the spent line was walked taut and jumped loose. |
