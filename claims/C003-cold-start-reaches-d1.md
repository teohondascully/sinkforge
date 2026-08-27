---
id: C003
title: A scripted bot reaches the first rig demand from a cold start
status: BLOCKED
kind: structural
owner: engineering
created: 2026-08-27
last_measured: never
first_failed_at: never
scenario: scenarios/cold_start_to_d1.yaml
blocked_on: nearly everything. No save/load code exists anywhere in the repository. No `interface/`,
  no `harness/`, no `sim/commands` beyond a skeleton `MODULE.md`. `data/economy/` (the D1 demand itself)
  does not exist. Determinism is proven only against `core/` plus a stub sim, never through a real
  session. See "Why this is blocked on nearly everything" below.
---

## Claim

A scripted agent, given no privileged information beyond what a first-time player would have, can start
from a cold checkpoint (fresh persistent shaft, permanent rig, nothing built), and satisfy the rig's
first demand (D1 — currently drafted, in the director's reversal brief, this session's transcript, not a
tracked repository file — as 30 iron ingot, unlocking the drill), entirely headless, within N sim-minutes.

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

Not yet named precisely — depends on how demand-satisfaction is surfaced through `interface/`'s
`observe()`, which does not exist yet. Provisionally: a telemetry event marking a demand as satisfied
(`demand_satisfied.id == "D1"`), with `ticks_used` from the same driver-process pattern C001 used.

## Threshold

**Not set.** C001's own threshold (7,200 ticks) was sourced from Draft A's run-length curve, which no
longer exists. This claim has no equivalent source yet, because `data/economy/` — where D1's actual
quantities and the rig's demand-delivery mechanics get authored — does not exist. Setting a number now
would be "a guess wearing a decimal point" (`docs/CLAIMS.md` §9's own rule against exactly this). The
threshold gets set once `data/economy/` exists and a first real playthrough (even a manual one) gives a
number to reason from, not before.

## Current value

Never measured. Blocked on essentially the entire remaining build sequence.

## Why this is blocked on nearly everything

Verified directly, not assumed, during the review that preceded this claim's filing:

- **No save/load code exists anywhere.** `docs/ARCHITECTURE.md` §11's checkpoint/save schema is prose
  only — no serialization exists in `sim/`, `shell/`, or anywhere else in the repository.
- **No `interface/`, no `harness/`.** Both are stub `README.md`/`MODULE.md` files. The
  `(checkpoint, seed, policy, horizon)` episode format this claim is shaped around is a generalization
  of the `scenarios/*.yaml` format `harness/scenario/` is supposed to hold, and that layer is unbuilt.
- **No `sim/commands` beyond a skeleton.** A scripted agent needs a typed command vocabulary to act
  through; `sim/commands/MODULE.md` states the shape and nothing else exists.
- **No `data/economy/`.** There is nothing for a bot to play toward yet — this is next session's
  explicit scope (`docs/WORKING.md`), not started.
- **Determinism is unproven at the scale this needs.** `replay_determinism_test` is proven only against
  `core/` plus a trivial stub sim. Nothing has shown determinism holds through `sim/world` +
  `sim/terrain_gen` + `sim/body` combined over a realistic session, let alone through
  `machines`/`transport`/`fluid`/`economy`, none of which have a line of code yet. Any future claim about
  checkpoint fidelity — including this one's own re-loadability requirement — inherits that gap until it
  is closed.

This is not a near-term claim. It is filed now so the eventual work has a stated target rather than
accumulating toward one that was never written down — the same reasoning `docs/CLAIMS.md` §6 gives for
writing a claim before the code that satisfies it exists.

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
