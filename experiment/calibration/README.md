# experiment/calibration

## Purpose

Recorded human sessions, captured through the same L2 `interface` and the
same telemetry schema as agent runs, so proxy metrics (the numbers bots
produce) can be checked against real human behavior instead of assumed to
correlate with it.

## Dependencies

`harness` (a calibration session is stored/replayed in the same shape as a
`harness/driver` run so it can go through `harness/aggregate` unmodified).
Not `sim` directly (see `experiment/README.md`).

## Consumers

`experiment/claims_runner` (a claim about human behavior should be checked
against calibration data, not just bot data), `harness/envelope` (envelope
design should be validated against how far constrained-bot behavior
diverges from recorded human behavior).

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
