# The Claim System

**Status:** normative. **Last revised:** 2026-08-25.

---

## 1. What a claim is

A claim is a design assertion written so that it can be wrong.

Game design usually cannot say that. "The opening should feel rewarding" has no failure condition, so it never fails, so nothing is learned. A claim converts an assertion into a scenario, a metric, and a threshold, and then CI tells you when it stops being true.

**The claim is the unit of work in this repository.** Not the feature, not the ticket, not the sprint. Work begins by writing a claim that fails and ends when it passes.

---

## 2. Why this exists

Three problems it solves, all of them observed in the prior codebase:

**Design regressions are invisible.** A balance change that quietly creates a dominant strategy shows up ten hours of play later, if ever. A claim on strategy diversity catches it in the fast loop.

**Instrumentation grows without direction.** The prior repository accumulated 108 registered check layers, a large fraction of which tested systems now being deleted. The gate "every harness layer names a claim" makes that impossible: a check that cannot say what design assertion it defends does not merge.

**Agent evidence has no anchor.** Thousands of agent runs produce numbers. Without a claim, a number is trivia. With one, it is a verdict.

---

## 3. File format

One file per claim, in `claims/`, named `C###-short-slug.md`.

```markdown
---
id: C001
title: A bounded run completes in under two minutes
status: FAILING          # FAILING | PASSING | RETIRED | BLOCKED
kind: structural         # structural | balance | feel | legibility | performance
owner: design            # design | engineering
created: 2026-08-25
last_measured: never
scenario: scenarios/first_bore.yaml
---

## Claim
One sentence, in English, that a person could disagree with.

## Why this matters
Two or three sentences. What breaks if this is false. If you cannot answer,
the claim is not worth measuring.

## Falsifiable form
The precise statement being tested, including the envelope and the population.
"Under the constrained envelope, across 50 seeds, the median ... "

## Metric
The exact quantity. Name the telemetry events it derives from.

## Threshold
The number, and one sentence on where the number came from. A threshold with
no justification is a guess wearing a decimal point.

## Current value
Measured, with date and commit. `never measured` is a valid entry and is
better than an estimate.

## What this claim does not measure
Required. Every claim has a blind spot and naming it is what keeps the corpus
honest.

## History
| Date | Commit | Value | Status | Note |
|---|---|---|---|---|
```

---

## 4. Statuses

| Status | Meaning |
|---|---|
| `FAILING` | Measured, below threshold. Normal for new claims. This is where work starts. |
| `PASSING` | Measured, at or above threshold, as of the recorded commit. |
| `BLOCKED` | Cannot be measured yet because the system it tests does not exist. Must name what it waits on. |
| `RETIRED` | The design changed and this claim no longer applies. Never deleted; the history is the record of what was believed and when. |

A claim is never deleted. Retirement requires a one-line reason and the date.

---

## 5. Kinds, and what each can actually establish

Being precise here is what separates an instrument from a dashboard.

**`structural`** — reachability, softlocks, completability, whether a goal can be achieved at all. Agents establish these definitively. Highest confidence available.

**`balance`** — dominant strategies, strategy diversity, payback times, throughput ceilings, dead content. Agents establish these well, under the oracle envelope, with the caveat that an agent's optimum is not a human's.

**`feel`** — movement quality, latency, stall, agility. Measured from raw-input telemetry against fixed geometry. Objective and reliable, but note that "no edge catches" is necessary for good feel, not sufficient.

**`legibility`** — can state be read from the screen. Measured by rendering a frame and asking a vision model. Genuinely useful and genuinely noisy. Never gates CI.

**`performance`** — budgets from `docs/ARCHITECTURE.md` §10.

**There is no `engagement` kind, deliberately.** An agent cannot measure whether a game is fun. Claims that gesture at fun must be decomposed into structural, balance, or legibility claims with a stated proxy, or they do not belong in the corpus. If you find yourself writing a claim whose metric is a composite "engagement score," stop: that is the failure mode this project exists to avoid, and it is the first thing a serious reviewer will attack.

---

## 6. Workflow

1. **Write the claim first.** Before the code. It fails, because the system does not exist. That is correct.
2. **Write the scenario** that would measure it. It may be `BLOCKED` until the system exists.
3. **Build until it passes.** The claim is the definition of done.
4. **Record the value and commit** in the History table.
5. **Leave it in the corpus forever.** It now defends against regression.

**Every bug a human finds becomes a claim or a scenario.** That is what makes the corpus compound rather than accumulate.

---

## 7. The claims worth writing first

`C001` establishes that the loop closes. The next few should target the design's highest-uncertainty assumptions, because those are what a document cannot settle and what the first playable run can.

In rough order of how badly a wrong answer would hurt:

- **Does the hole-as-conveyor discovery happen unprompted?** Give a constrained agent, and then three humans, a shaft with a forge and a fuel source at different depths, and measure whether anyone digs a connecting chute without being told. `docs/GDD.md` §10 calls this the single most important thing the design can produce. If nobody finds it, the premise needs a teaching moment and one must be designed.
- **Is a two-minute run a game or a menu?** The whole Draft A cadence rests on this and it is entirely unverified. `docs/GDD.md` §8.
- **Does strategy diversity exist?** Cluster the build orders of many oracle agents with randomized objective weightings on one seed. Convergence on a single build means the rest of the design is furniture. This is the metric that most directly tests whether the game is a factory game at all.
- **Does infrastructure pay back inside a run?** If building a drill costs more material than it returns before the water reaches it, the optimal strategy is to build nothing and hand-mine, and the game eats itself. `docs/GDD.md` §6.

Write these as `BLOCKED` now if you like. A blocked claim that names what it waits on is a better artifact than a plan that says the same thing in prose.

---

## 8. The corpus as a portfolio artifact

`claims/` is the most legible thing in this repository to an outside reader. It is a list of things the project believes about its own design, each with a number attached and a history of when it was true.

Keep it readable. Sentence case, no jargon, no internal shorthand. Someone who has never seen the game should be able to read a claim file and understand both what is being asserted and what would prove it wrong.

---

## 9. Thresholds

The weakest part of any claim system, so state the rules:

- A threshold needs a one-sentence justification. "Because it felt right" is an acceptable justification if it is honestly labeled as such; an unlabeled guess is not.
- Thresholds move only with a recorded reason in History. Moving a threshold to make a claim pass is the same offence as lowering a CI gate to make it green.
- A claim whose threshold has moved three times is telling you the claim is wrong, not the number.
