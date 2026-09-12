---
id: C005
title: The hole a player digs is a conveyor, and a machine fed through it jams on junk
status: PASSING
kind: structural
owner: engineering
created: 2026-09-12
last_measured: 2026-09-12
first_failed_at: 2026-09-12
scenario: scenarios/conveyor_jam.yaml
---

## Claim

A pile of ore and coal resting on a capped shaft rides the column into a machine's intake when the cap
is dug out from under it — no conveyor entity, no routing UI, the hole itself is the transport — and the
same machine that ran on the delivered pile then blocks when the player feeds a foreign item through the
same gravity route, with the junk left sitting in the intake.

## Why this matters

`docs/GDD.md` §10 calls the hole-as-conveyor discovery the single most important thing the design can
produce, and `docs/CLAIMS.md` §7's first-ranked open question is whether anyone digs a connecting chute
unprompted. That question cannot be asked of a world in which the physics does not work: this claim is
the precondition, measured end to end — excavation, gravity routing, machine intake, and the
self-inflicted jam are all real and all legible on the observation's own channels. If it passes, the
teaching-moment design has something true to teach. If it fails, the discovery beat is fiction.

The jam half is what makes the beat a *discovery* rather than a delivery animation: the first machine
a player feeds this way blocks on a mistake they made, and the intake still visibly holds the item that
did it — the consequence is the whole explanation.

## Falsifiable form

On scenario `conveyor_jam` (fixed seed, the `conveyor_probe` start on `shallow_clay`), the scripted
`conveyor_probe` agent: walks to a capped bore with a resting ore/coal pile on the cap and a cold forge
at its foot; digs the cap; then descends the bore and drops one clay into the same column. The claim
holds iff, on the run's own observation channels:

- `flow_events` record ore and coal moving from the pile's cell to the forge's cell through the dug
  column (`from (35,19) to (35,27)`),
- the forge's machine record reads `working` before the foreign item is introduced,
- a `flow_event` records the clay landing in the same intake,
- the forge's machine record then reads `blocked` with the clay still counted in its intake buffer,
- a control run on identical geometry with the record's shipped `intake: pass` never reads `blocked`,
- and item conservation holds over the whole run.

## Metric

`tests/test_conveyor_jam.gd` asserts the sequence above against `ScenarioDriver`'s report and the bot's
`notes` evidence channel; the goal event is `machine_status` at the forge's cell reading `blocked`.

## Threshold

The sequence itself is the threshold: every clause above must hold in one run, in order — `working`
strictly before `blocked`, the clay still present at the end. A run where the forge blocks before the
pile arrives, or where the intake empties the junk, fails.

## Current value

**Measured 2026-09-12: 311 ticks, all clauses hold** (D0645+D0646). Ore `{count:4}` and coal `{count:2}`
flow `(35,19)->(35,27)` at the cap break; the forge reads `working`; the tossed clay lands
`(35,25)->(35,27)`; the forge reads `blocked` holding `{ore:4, coal:2, clay:1}`; the `pass` control
passes the clay through and never blocks; conservation clean. `first_failed_at` is the same day's WIP
run (commit `702761d0`), which failed 8 of 18 assertions — the route never reached the forge — before
D0646's measured fixes closed it.

## What this claim does not measure

- **Whether anyone digs the chute unprompted.** That is the §7 question this claim exists to enable —
  it wants a constrained or human agent that was never told the hole is a conveyor. The scripted policy
  here knows the fixture's layout; it proves the physics, not the discovery. A human-discovery variant
  is a separate claim.
- **Whether the discovery FEELS like a discovery.** Timing, readability of the falling pile, the jam's
  drama — all unmeasured; this is a structural claim, not an experience one.
- **Whether `intake: jam` is the right shipped default.** The fixture's jam is a placed-instance
  override (D0645); the shipped records all read `pass`. Which intakes should jam in the real game is a
  design call this claim deliberately does not settle.
- **General column routing.** One column, one machine, one pile. Water, multiple machines in a column,
  and partial blockages are unmeasured.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-09-12 | 702761d0 | conveyor_probe | 8/18 assertions fail — route never reached the forge | FAILING | WIP commit; `first_failed_at`. The pile-route worked after codegen (`(35,19)->(35,27)` measured) but the descent could not thread the one-metre mouth. |
| 2026-09-12 | D0646 | conveyor_probe | 311 ticks, 18/18 | PASSING | Measured fixes: hardrock cap+walls (clay slumps into the wake), 2m bore AND 2m dug mouth (1m gap = perfect piston for a 1m body), hardrock west wall two deep (the r=2 bite nicked clay behind the target; ~30 cells refilled the bore), hands-off-while-falling descend + step off the caught lip, approach-until-`Mining.in_reach` (the cap's far corner sat 1.3px outside reach on a held pick). |
