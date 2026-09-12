---
id: C003
title: A scripted bot reaches the first rig demand from a cold start
status: PASSING
kind: structural
owner: engineering
created: 2026-08-27
last_measured: 2026-09-11
first_failed_at: 2026-09-11
scenario: scenarios/cold_start_to_d1.yaml
---

## Claim

A scripted agent, given no privileged information beyond what a first-time player would have, can start
from a cold checkpoint (fresh persistent shaft, permanent rig, nothing built), and satisfy the rig's
first demand (D1: 2 ingots, unlocking the drill — `data/progression`'s implemented record; the "30
iron ingot" in this file's first draft predated it), entirely headless,
within N sim-minutes.

## Why this matters

This is C001's replacement, not its edit — the run-based structure C001 measured is retired
(`docs/DECISIONS_LEDGER.md` D0076), and this claim is shaped like the checkpoint-lineage idea from the
director's reversal brief (§4): `(checkpoint, seed, policy, horizon)`, with "cold start" as the
checkpoint and D1 as the horizon's success condition. It plays the same tracer-bullet role C001 did —
thin everywhere, complete once, and it is the first point at which "the game is buildable on this
foundation" becomes checkable rather than argued.

It is also the first claim that will actually need `data/economy/`'s real content to exist, which makes
it the natural definition-of-done for the demand-authoring work that follows this document's own
GDD edits — filing it now, before that work starts, is what keeps that work honest about what it is
actually trying to produce.

## Falsifiable form

Under the `constrained` envelope, on scenario `cold_start_to_d1` with a fixed seed, an agent starting
from a cold checkpoint (no prior state) satisfies D1's demand within N sim-minutes, with zero invariant
violations, in a process launched with no rendering context, and the resulting state is a valid
checkpoint (re-loadable, re-derivable byte-identically from the same seed and input log).

## Metric

Named 2026-09-11 (D0605): `demand_satisfied` rides `Machines.events` onto `o.events` at the stage
advance — `{kind, id, stage, cell}` where `id` is the demand record's own (`"d1"`). `ticks_used` is
the count of MOVE ticks applied through `Interface.apply` — the only ticks that advance the world —
so the number is world-time, not wall-clock or call count.

## Threshold

**Not set.** C001's own threshold (7,200 ticks) was sourced from Draft A's run-length curve, which no
longer exists. This claim has no equivalent source yet, because `data/economy/` — where D1's actual
quantities and the rig's demand-delivery mechanics get authored — does not exist. Setting a number now
would be "a guess wearing a decimal point" (`docs/CLAIMS.md` §9's own rule against exactly this). The
threshold gets set once `data/economy/` exists and a first real playthrough (even a manual one) gives a
number to reason from, not before.

## Current value

**Measured 2026-09-11: 414 ticks** (~6.9 sim-seconds at 60 Hz) — `tests/test_cold_start_d1.gd` drives
a scripted bot through `Interface.apply`/`observe` on the stamped tutorial site: mine the surface
vein, feed the forge, mine the coal seam, feed it again, scoop two ingots, feed the rig. The event
arrived; item conservation held over the whole run. `first_failed_at` is populated from the same
commit's mutation run: suppressing the event kind left every leg green and the claim's assertion red,
which is the observation §10a asks for — the measurement path can fail.

## Current blockers and available foundation

Updated 2026-09-11. The run is executable and green; what remains between this suite and the claim's
full falsifiable form:

- **The envelope is `oracle`, not `constrained`.** No fog-filtered envelope exists — `Envelope` is a
  spatial window only. The scripted policy reads only authored fixture positions and surface
  solidity, so no hidden state enters the run; the honest upgrade is a constrained window once the
  type exists, and the policy would not need to change. The driver's report names the envelope it
  actually used so the gap stays visible rather than silently read as satisfied.
- **The threshold is still unset.** The scripted floor is now measured (414 ticks); a human-pacing
  threshold wants either a real playthrough number or a director ruling on what multiple of the bot
  floor counts as completable.
- **Checkpoint re-derivation is not exercised here.** The claim asks for a re-loadable resulting
  state; the suite does not save/reload mid-run. `shell/save_game.gd` exists for it.

The previous blockers are resolved: the rig demand transaction (`sim/economy/demands.gd` + the rig
runner), D1's unlock (`drill` granted at stage advance), economy records (`data/progression`), the
demand event, and the scenario record all exist and are exercised. **The driver exists (D0620):**
`harness/driver/scenario_driver.gd` consumes the record via `ScenarioRecords` (generated from the
yaml by the same codegen pass as `data/`, schema-validated by `scenarios/SCHEMA.yaml`), boots the
named site/start/seed, and hands the run to the bot `agent:` names (`harness/bots/cold_start.gd`).
The suite is now an assertion shell over that machinery, not a second copy of the route.

## What this claim does not measure

- **Whether the demand curve is any good.** This is a completability claim against whatever D1 turns
  out to require. It says nothing about whether D1, D2, D3... form a well-paced sequence.
- **Whether a human could do it.** Same caveat C001 carried — the agent operates under a constrained
  envelope, not a human one.
- **Whether the reachability-rule from the reversal brief holds past D3.** The rule the director
  restated ("every demand must require at least one material that was inaccessible before the previous
  unlock") is a property of the whole demand chain, not something this single claim, aimed at D1 alone,
  can establish.
- **Checkpoint fidelity beyond this one scenario.** Passing this claim proves one checkpoint is
  reachable and re-derivable. It does not prove the checkpoint mechanism generalizes to arbitrary points
  in a much longer session.
- **Performance at scale.** A cold-start-to-D1 episode exercises almost nothing of the §10 budgets.

Each of those needs its own claim. This one establishes only that the persistent-world loop closes at
its first real checkpoint.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-08-27 | — | — | not measured | BLOCKED | Claim authored to replace retired `C001` (`docs/DECISIONS_LEDGER.md` D0076). Blocked on nearly the entire remaining build sequence — see above. |
| 2026-09-11 | D0605+D0609 | d1 wants 2 ingots | 414 ticks | PASSING | `test_cold_start_d1.gd` + `scenarios/cold_start_to_d1.yaml`. Scripted bot through apply/observe only; conservation clean. First-failed via the same commit's event-kind mutation. Threshold still unset. |
| 2026-09-11 | D0620 | d1 wants 2 ingots | within 30000-tick budget | PASSING | Same run now driven by `harness/driver` consuming the generated scenario record — yaml is the single source, the suite asserts over the driver's report. Event-suppression mutation re-verified red. |
