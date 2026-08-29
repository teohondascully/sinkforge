---
id: C004
title: Discovering a reveal-layer feature raises subsequent dig activity
status: BLOCKED
kind: balance
owner: engineering
created: 2026-08-28
last_measured: never
first_failed_at: never
scenario: (none yet — needs recorded play sessions against the reveal-test terrain sites, sparse and
  dense, per the Falsifiable form below)
blocked_on: the reveal-layer terrain extension and the dig mechanic it depends on exist and are
  gate-verified as of this filing, but the claim itself requires recorded human play sessions across the
  density conditions, and none has been recorded yet. See `docs/GDD.md` §12 for the design finding this
  claim tests, and `docs/CLAIMS.md` §7 (the "does lateral variety sustain interest" entry) for the prior,
  unfiled framing of the same underlying question.
---

## Claim

Digging out a reveal-layer feature (a discoverable, deliberately inert placeholder material scattered
through topsoil terrain, `data/materials/glimmer.yaml`) measurably raises the player's dig-event rate in
the minutes immediately following the discovery, compared to the minutes immediately preceding it.

## Why this matters

This is `docs/GDD.md` §12's Reveal want-layer, given a falsifiable form. §8 already named the underlying
question ("whether lateral variety survives losing re-rolled geology... new material kinds forcing search
sideways as much as down... unverified") as the reversal's largest open question; `docs/CLAIMS.md` §7
independently listed it as the second-highest-priority claim to write, before this brief connected it to
a specific mechanism (Reveal) and a specific, non-circular metric. If discovering something does not
change subsequent play, the Reveal layer is inert and that is learned cheaply, before any demand content
is authored on the assumption that exploration alone sustains interest.

## Falsifiable form

Under recorded human play (`tests/body/play_scene.gd`-shaped `--play` mode, real physical-key input, no
scripted policy — a scripted digger with any awareness of feature placement would make this claim
circular, see "What this claim does not measure" below), across several sessions against both the sparse
and dense reveal-test terrain sites (`data/strata/reveal_test_sparse.yaml`,
`data/strata/reveal_test_dense.yaml`), the mean dig-event rate in the 300-tick (5s) window immediately
after a reveal event exceeds the mean dig-event rate in the 300-tick window immediately before it, pooled
across all qualifying reveal events (those with a full 300-tick window on both sides — a reveal within 5s
of session start or end is excluded, not padded).

## Metric

`dig_rate_lift`: computed entirely from a session's own recorded tick trace (tick index, whether a dig
event fired that tick, and — only for a tick where a dig event fired — whether the excavated cell's
material was the reveal material). **Deliberately does not use feature location.** The original framing
of this layer's pull ("does the player travel toward an unrevealed feature") was rejected because it
requires the measuring code to know where undiscovered features are — information the player does not
have — which makes the metric either meaningless (nothing to compare against, since the features are by
definition hidden) or, if wired into an agent's own decision policy instead of pure post-hoc analysis,
straightforwardly cheating: the agent would be reading world state a real player cannot see
(`docs/EXPERIENCE_EVALUATION.md`'s Readiness Gate 6 names exactly this failure — "the actor can be given
only player-visible information... the evaluation is `INVALID`"). `dig_rate_lift` uses only information
that becomes available at the moment of the dig itself (was the cell just excavated the reveal material —
the same thing a human player sees the instant they dig it), never a distance or bias computation against
cells not yet dug. This is the anti-cheat property, and it is why this metric is computable from real,
unscripted human play at all.

## Threshold

**Not set.** Per `docs/CLAIMS.md` §9, a threshold set before any measurement exists is a guess wearing a
decimal point. The first real recorded-session measurement gives a number to reason from — same
precedent as `C003`.

## Current value

Never measured. The terrain extension and dig mechanic are built and gate-verified as of this claim's
filing (`docs/DECISIONS_LEDGER.md`, this session's entries); no human play session has been recorded
against either reveal-test site yet.

## What this claim does not measure

- **Whether the player travels toward unrevealed content.** Rejected explicitly, see Metric above — not
  measurable without exposing hidden world state to whatever produces the play trace.
- **Whether density is tuned correctly.** This claim tests whether the mechanism produces a lift at all,
  under the two test densities built. It does not establish an optimal density, and a density sweep
  compares different generations (deterministic per-seed feature placement does not hold ACROSS density
  values, only within one) — `sim/terrain_gen/shaft_generator.gd`'s own docstring states this.
  Distinguishing whether a lift exists from how strong it should be is future work, deliberately out of
  scope for this first cheap test.
- **Whether Flow or Pressure pull.** Both are unbuilt (`docs/GDD.md` §12). This claim is Reveal-only.
- **Whether an agent's play would show the same lift a human's does.** A scripted or agent-driven digger
  is exactly what this claim's own metric was designed to avoid depending on. If an agent-based version
  is wanted later, it needs a genuinely feature-blind sensing model, which does not exist yet.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-08-28 | — | — | not measured | BLOCKED | Claim authored alongside the reveal-layer terrain/dig build (`docs/GDD.md` §12). Blocked on recorded human play sessions, which this build does not itself produce. |
