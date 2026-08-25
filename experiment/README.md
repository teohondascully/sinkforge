# experiment

## Purpose

The research layer. No game code lives here. This is where claims get
evaluated: design claim -> scenario -> sweep -> metrics -> verdict. A human
decides what to do with the verdict — this layer proposes evidence, it
never decides design.

## Dependencies

`harness` only. Must not depend on `sim` directly — every run this layer
needs goes through `harness/driver`, which is the only thing that talks to
`interface`/`sim`. If a piece of `experiment/` code finds itself importing
from `sim/`, that's a layering violation, not a shortcut.

## Subdirectories

- `claims_runner/` — runs the claims in `claims/` against their scenarios,
  updates status/History per `docs/CLAIMS.md`.
- `sweeps/` — N seeds x M envelopes -> distributions.
- `ablations/` — change one `data/` value, re-run the corpus, diff every
  metric.
- `calibration/` — recorded human sessions, captured through the same L2
  interface and telemetry schema as agent runs, so proxy metrics can be
  checked against real human behavior instead of assumed.

Each has its own README.md.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
