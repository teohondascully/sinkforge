# harness/envelope

## Purpose

Agent capability definitions: fog/vision, lookahead/planning, motor noise,
priors. An envelope is what `interface`'s `observe(envelope)` filters
through — it's the mechanism that makes a bot run and a human run
comparable, by making explicit exactly what each one is allowed to know
and how precisely it can act.

## Three standard envelopes

- **oracle** — perfect info. Measures the ceiling: what's achievable if
  discoverability and perception aren't the bottleneck.
- **constrained** — fogged. Measures the floor/discoverability: what's
  achievable under the same information limits a real player has.
- **language** — natural-language reasoning over player-visible
  observation. Measures legibility: can a reasoning process that only sees
  what a human sees figure out what to do. Never in CI (this envelope is
  inherently slow/nondeterministic-ish and belongs to the slow loop only).

## Dependencies

`interface`, `core` (an envelope is defined in terms of `Observation`'s
shape).

## Consumers

`harness/bots` (each bot is written against one envelope), `harness/driver`
(applies the envelope when calling `observe()`), `experiment/sweeps` (runs
the same scenario across multiple envelopes to compare distributions).

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
