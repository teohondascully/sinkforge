# experiment/sweeps

## Purpose

N seeds x M envelopes -> distributions. Runs the same scenario repeatedly
across a seed range and across `harness/envelope` variants, and produces
the distribution of outcomes rather than a single pass/fail — this is the
slow loop's core tool.

## Dependencies

`harness` (drives many runs via `harness/driver`, reads results via
`harness/aggregate`). Not `sim` directly (see `experiment/README.md`).

## Consumers

`experiment/claims_runner` (a claim's verdict may depend on a distribution,
not just one run), whoever is reviewing design decisions with sweep output
in hand.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
