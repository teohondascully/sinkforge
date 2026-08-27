# Lane D — read-only evidence brief: T2.3 (DIG stall) and T3.1 (rock/void legibility)

UNTRACKED. 2026-08-23. **Read-only: no engine, no capture, no lock, no implementation file touched.**
T2.3 and T3.1 are PEER-OWNED. This is a proposal returned to their owner, not an edit to their lane.
`docs/PRIORITY.md` was deliberately NOT modified.

## Coordinator verification of the four load-bearing claims

Lane D is a subagent and its findings are hypotheses until checked. Four were checked directly against the
tree by the coordinator before any of this was recorded; all four hold.

| claim | verified how | result |
|---|---|---|
| `docs/PRIORITY.md` still declares the value cue exhausted | read lines 1492-1496 | **CONFIRMED**, verbatim: *"THE VALUE APPROACH IS EXHAUSTED. The pooled value gap is 0.4 levels (rock 8.4 vs air 8.8), and value alone separates at chance."* |
| the layer now reads VALUE far above chance | read `docs/tracelog/sweeps/2026-08-23-final-green/65-check_rock_reads.log` | **CONFIRMED**: *"VALUE: rock median 14.9, air median 9.0, gap 6.0 -> you would be right 88% of the time"* and *"the better cue is VALUE at 88%"* |
| the orientation separation has collapsed from ~16 levels | read `.../66-check_contact_edge.log` | **CONFIRMED**: *"lit ROCK by face orientation — TOP 44.1 (n=49), SIDE 39.2 (n=51)"*, *"TOP sits 4.9 levels above SIDE"* |
| nothing can fail on it | read `tools/check_contact_edge.gd:298` | **CONFIRMED**: the whole lit-pool arm prints *"(diagnostic, never gated)"* |

## The shared cause, which is why these are one item and not two

Both tickets are filed as waiting on a person: a feel call for T2.3, a blind vision tester for T3.1.
**Neither is waiting on a person.** In both cases the work that answers the ticket was done under a
different banner and never crossed back into the ticket, and in both cases **the ticket's headline quantity
is printed by its instrument and asserted by nothing** — so green sweeps rolled past a direct contradiction
without a gate twitching.

This is the house failure class aimed at the queue rather than at a layer: **an instrument that cannot
register its subject reports a quiet green**, and here the subject is the ticket's own conclusion.

## T2.3 — the DIG stall was the bazaar rescan, and it is fixed

The ~33 ms frame the ticket calls its remaining feel question was **not mining**. `main._process` ran
`_update_bazaars` -> `FactorySim.find_bazaars`, a full 16384-origin rescan at 16.4 ms, every frame.

    d38d232  2026-08-22  two-dictionary early reject on the top-beam corners, verified against brute
                         force: 0 mismatches over 40 rounds, 9 of 9 on the placed-gap cases
                         DIG p99 30.5 -> 16.8/16.6/18.0   worst 31.4-34.1 -> 17.7-20.8
    bdebe95  2026-08-22  a SECOND uncached full-grid walk, bazaar_completion_cell at 3.17 ms every
                         frame, deleted as a duplicate of _ruins_cache. 32x.
    4d7ff90  2026-08-22  replaced the unmeasurable p95-vs-8.33ms budget with a two-term SLO
    9cb4fbb  2026-08-22  measured the post-fix rescan directly, median 2.74 ms over 40 samples

24 independent sweep runs on 2026-08-22/23 read DIG p50 8.30-8.37, p95 10.27-11.29, p99 16.45-18.90.
**None of `d38d232`, `bdebe95` or `4d7ff90` appears anywhere in `docs/PRIORITY.md`, `docs/FEEL_GAP.md` or
the overnight state file.**

**Status: UNBLOCKED, and effectively DONE but unclosed.** No person, no decision, no missing measurement.

**One real open item, and it is a diagnostic that now lies.** `STUCK_REFUSALS = 30`
(`tools/check_frametime.gd:841`) fires after 30 consecutive frames with no break. The fixture now digs at
the player-legal rate, 11 breaks in 400 frames, so ~36 quiet frames between breaks is NORMAL. It fires on
24 of 24 recorded runs and prints `!! try_mine REFUSED` about a path that no longer calls `try_mine` —
the docstring sizing it was written for the pre-conversion arm and `795ab80` invalidated it. A diagnostic
that has cried wolf 24 times is where the next genuine stall will arrive unseen.

Also stale: `docs/PRIORITY.md:1244` says *"`check_frametime` ITSELF IS STILL UNCONVERTED"*, false since
`795ab80` five days ago.

## T3.1 — both of the ticket's settled numbers are now wrong, in opposite directions

**6a, wrong in the tree's FAVOUR.** The ticket says value separates at chance on a 0.4-level gap. Ten
sweeps read VALUE at 87-88% on a gap of 5.9-6.3, **the best of the three cues**, with GRAIN at 85% and
CHROMA at 89% on an axis the gate is deliberately blind to. The ticket's *"the open part is the INTERIOR"*
has closed too: plain interior reads 86% on VALUE over n=391.

The mechanism is the transferable part. `49ed8f6` doubled `TOOTH` 0.030 -> 0.060 because the cue had
decayed without anyone touching it: *"terrain moved under it, air's own grain rose while rock's held"*, and
the same constant fell to 77.8% against a 75.00% floor. **Separation is not a property the renderer holds.
It decays when unrelated terrain work changes the other side of the comparison.**

**6b, wrong AGAINST the tree, and this is the one that matters.** The ticket rests on *"TOP sits ~16 levels
above SIDE and both hold to within a level or two across six runs"* and names the open question as whether
16 levels is a difference an eye can use. Measured across every recorded sweep the separation is **-0.0 to
5.7 levels**, and one run printed **exactly zero** — which is the ticket's own definition of *"fog rather
than carved mass"*, as a number, inside a green sweep.

It cannot fail because `check_contact_edge`'s lit-pool arm is `diagnostic, never gated`, and `ORIENT_MIN`
is a sample-count floor rather than a floor on the separation itself.

Genuinely improved meanwhile, and worth keeping: unlit contact detectability 95% -> 98%, step median
10.4 -> 18.3 against flat rock at 1.8; lit contact step 21.9 -> 27.4 against a lit flat 4.32.

**Status: PARTLY BLOCKED, but not where the ticket says.** The blind tester is blocked on stale captures
(the newest tracked `_moment_*.png` is 2026-08-20 and three renderer commits landed after it) and that
premise still holds. But it is the THIRD blocker, not the first.

## Proposed next steps, for the owner to accept or reject

**T2.3, zero machine time.** Write `d38d232`, the p99 30.5 -> ~17, and the Area 4 SLO row into T2.3 and
close it on measurement. Then raise `STUCK_REFUSALS` above the observed ~36-frame inter-break interval and
fix the `try_mine` wording.

**T3.1 (a), zero machine time.** Strike the exhausted-value paragraph; VALUE separates at 88% on a
6.0-level gap over ten runs. Replace the ~16-level orientation figure with the measured -0.0 to 5.7.

**T3.1 (b), one machine slot, and the only thing that would protect this.** Put a floor under the number
that decayed: either assert `TOP - SIDE >= k` so a run printing -0.0 goes red, or assert the VALUE and
GRAIN legs separately so `best` cannot hide one collapsing behind the other. **Derive `k` from the recorded
spread; do not invent it** — three positives and no negative population cannot locate a bound. Note this is
harness expansion and needs a priority ID under the freeze, and it now has the thing the freeze asks for:
a demonstrated silent regression.

**T3.1 (c), only after (a) and (b).** The blind tester, on captures regenerated at HEAD, written to a new
location and never over the canonical frames.
