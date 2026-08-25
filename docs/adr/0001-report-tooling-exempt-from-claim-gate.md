# ADR 0001: Report and visualization tooling is exempt from the claim-reference gate

**Status:** accepted, 2026-08-25.

## Context

`docs/QUALITY.md` gate 15 — "every harness layer names a claim" — is the direct fix for the prior
codebase's instrumentation growing without direction (108 registered check layers, a large fraction
defending nothing). `tools/layer_lint/check_claim_references.py` enforces it mechanically: any file
under `harness/` that registers a check (`func run()`) must carry `# claim: C###`, or the build fails.

`harness/aggregate/` and `tools/report/` don't fit that shape. They don't assert anything themselves —
they turn telemetry and run artifacts from checks that already ran into human-readable output. A
report generator that names a single claim would be naming an arbitrary one; it serves the whole
corpus, not one design assertion.

## Decision

Report and visualization tooling is exempt from gate 15. A file claiming the exemption must say so
explicitly: `# claim: EXEMPT (ADR-0001)`. `check_claim_references.py` accepts that marker in place of
a claim ID and treats an unmarked file with no claim as a gate failure, same as before — the exemption
has to be stated, never assumed from a file's location or name.

## Consequences

- The exemption is narrow and explicit by construction: it exists only where the marker is written,
  so it can't silently spread to a check that should have named a claim and didn't.
- Scope discipline is now a human judgment call, not a mechanical one: whoever writes the marker is
  asserting "this file only reports, it doesn't assert" — worth re-checking if `tools/report/` or
  `harness/aggregate/` ever grow something that reduces telemetry to a pass/fail verdict of its own,
  since that would be a check wearing a report's exemption.
