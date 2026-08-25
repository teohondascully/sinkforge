# experiment/claims_runner

## Purpose

Runs the claims in `claims/` against their scenarios and updates
status/History per `docs/CLAIMS.md`. This is the concrete link between a
written design claim and the evidence that supports or refutes it — a
claim without a claims_runner entry is an assertion, not a claim.

## Dependencies

`harness` (drives scenarios via `harness/driver`, reads results via
`harness/aggregate`). Not `sim` directly (see `experiment/README.md`).

## Consumers

Whoever reviews claim status (a human, per this layer's "proposes evidence,
never decides design" contract) — not another code layer above this one.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
