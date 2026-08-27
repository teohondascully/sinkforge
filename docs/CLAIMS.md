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
id: C0NN
title: One sentence a person could disagree with
status: FAILING          # FAILING | PASSING | RETIRED | BLOCKED
kind: structural         # structural | balance | feel | legibility | performance
owner: design            # design | engineering
created: 2026-08-25
last_measured: never
first_failed_at: never   # date+commit of the first FAILING measurement. see §10.
scenario: scenarios/<name>.yaml
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
| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
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

**`docs/EXPERIENCE_EVALUATION.md` is the concrete method for stated-proxy work above `legibility`** — the calibrated-actor, validity-classified, never-averaged protocol for asking questions a single vision-model glance can't answer. It is a specification, not a harness layer: nothing in this section changes because it exists, and no claim may cite it in place of naming a real `kind` and a real metric.

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

`C003` establishes that the loop closes at its first real checkpoint. The next few should target the design's highest-uncertainty assumptions, because those are what a document cannot settle and what the first playable session can.

In rough order of how badly a wrong answer would hurt:

- **Does the hole-as-conveyor discovery happen unprompted?** Give a constrained agent, and then three humans, a shaft with a forge and a fuel source at different depths, and measure whether anyone digs a connecting chute without being told. `docs/GDD.md` §10 calls this the single most important thing the design can produce. If nobody finds it, the premise needs a teaching moment and one must be designed.
- **Does lateral variety sustain interest without re-rolled geology?** One persistent shaft means the terrain surprises the player exactly once, laterally, rather than every run the way it used to. `docs/GDD.md` §8 calls this the reversal's own largest open question and it is entirely unverified.
- **Does strategy diversity exist?** Cluster the build orders of many oracle agents with randomized objective weightings on one seed. Convergence on a single build means the rest of the design is furniture. This is the metric that most directly tests whether the game is a factory game at all.
- **Does infrastructure pay back before local flooding reaches it?** If building a drill costs more material than it returns before the water in that section rises, the optimal strategy is to build nothing and hand-mine, and the game eats itself. `docs/GDD.md` §6.

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

---

## 10. Claim-rot mechanisms

`docs/QUALITY.md`'s claim-reference gate constrains instrumentation: every check must trace to a
claim. Nothing constrains claims themselves. That's a gap, and pressure moves to fill it the same
way it filled the prior codebase's instrumentation — a claim filed to unblock a PR, describing what
the code already does rather than constraining what it must keep doing. That is what paperwork looks
like in a system built to resist paperwork. Four mitigations, none sufficient alone:

**a. A claim must have been observed failing at least once.** `first_failed_at` in the frontmatter
records the date and commit of the first `FAILING` measurement. A claim born `FAILING` and driven to
`PASSING` has demonstrated discriminating power — it distinguished a state where the design assertion
didn't hold from one where it does. A claim born `PASSING` was written to describe existing behavior,
which cannot fail by construction and defends nothing. This is `docs/QUALITY.md` §2's mutation
principle ("a check that has never been observed failing is not a check") applied to the corpus
itself, not just to individual harness layers. **Until `first_failed_at` is populated, the claim is
provisional and does not satisfy the claim-reference gate for any harness layer** — a check citing an
unproven claim ID is the same violation as citing no claim ID at all.

**b. Threshold before measurement.** Fill in `Threshold` before `Current value`. If the current value
is measured first and the threshold is set to match it, the threshold has ratcheted to whatever the
code happens to do today and the claim measures nothing going forward — it will read `PASSING` at the
moment of authorship and regress the instant reality changes, which inverts the claim's purpose.
Record which came first in `History`'s `Note` column the first time a claim is measured
("threshold set before first measurement" or the reverse, honestly, if it happened the wrong way
round).

**c. Cap the active (non-`RETIRED`) corpus at 40 claims.** Adding a 41st claim means retiring one
first. Retirement is hygiene, not failure — a claim can be `RETIRED` because the design it measured
changed, because a stronger claim subsumed it, or because it turned out to measure nothing useful.
The cap exists so the corpus stays something a reviewer can actually read, and so writing a new claim
is a real cost weighed against the existing forty rather than a free action. The `docs/CLAIMS.md` §8
"portfolio artifact" framing depends on the corpus staying legible; forty claims already tests that.

**d. Draw the claim/test boundary explicitly.** A correctness assertion is a test: it belongs in
`tests/`, and it would pass or fail identically regardless of what the design decided. A design
assertion is a claim: it could be true or false depending on a decision someone could have made
differently, and the corpus exists to make that decision checkable. "Conservation of matter holds"
is a test — no design choice makes it acceptable for matter to vanish. "Lateral variety sustains
interest without re-rolled geology" is a claim — a different `data/economy/` design changes what's
being asserted.
Without this line, the corpus fills with trivially-true correctness claims dressed as design claims,
which inflates the count against the cap in (c) without buying any of what a claim is supposed to
buy: a design decision made falsifiable.
