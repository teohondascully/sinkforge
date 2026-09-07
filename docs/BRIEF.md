# Brief

**Last updated: 2026-09-07.** Repository cleanup Batches 1–2, starting at `61b50fa4`; D0480.

## Delivered

Public setup and build status now describe the implemented game and missing rig economy.
Onboarding no longer instructs a new agent to repeat the pivot.
C003 remains BLOCKED with current dependencies, rather than claiming saves and interfaces do not exist.
WORKING is a short current-state page. BACKLOG routes work to existing P/T/V records.
Five prior operational documents and the preceding gameplay brief are preserved under
`docs/archive/cleanup-2026-09-07/`. No code, tests, historical evidence, or gameplay rules were removed.

## Verification

- The documented item-suite command passed 78 assertions under Godot 4.6.2.
- Schema validation, generated-data freshness, working-date and ledger integrity checks passed.
- CI non-shrink check passed: no jobs, suites, or enforcing steps removed.
- The five operational snapshots match their source at 61b50fa4.
- Local documentation links and diff whitespace checked.
- Claim-reference check reports VOID (no claim-linked scenarios); it is not proof of a measured claim.
- Gate-status completed but found no completed CI run for the starting HEAD, so remote outcomes
  are UNKNOWN. Its initial untracked-doc failure was resolved by staging and rerunning that check.
  Its Linux display-install step fails on this macOS host. No full CI pass is claimed.

## What was learned

The suite runners already share CI-derived selection; another suite list would duplicate the solution.
Gate-status actively executes checks and repeats local step resolution, including mutation sweeps.
This is concrete avoidable overhead, now a Batch 3 item. Engineering's percentage split remains an
estimate; measure implementation, model waits, simulation/capture, verification and documentation
separately before changing orchestration.

## Next

Batch 3: harness/test/tool organization and module contracts, with gate-report deduplication a
bounded first candidate. [Cleanup plan](CLEANUP_PLAN.md) records scope and acceptance.
Gameplay continuation remains the forge checkpoint and subsequent opening rungs; see the
[preserved gameplay brief](archive/cleanup-2026-09-07/BRIEF.md).
