# Repository cleanup plan

Status: approved by the director, 2026-09-07. Starting tree: `61b50fa4`.
Scope: improve repository truthfulness, navigation, and maintainability without gameplay changes.

## Coordination

Documentation ownership for Batches 1–2: README, CONTRIBUTING, CONTEXT, ONBOARDING, docs index,
WORKING, C003, backlog navigation and evidence policy. Gameplay and harness execution remain separate.
Check the worktree before each batch; preserve concurrent changes.
No evidence deletion, history rewrite, code move, or gameplay rule change is included in Batches 1–2.

## Batch 1 — truthful entry points

Completed 2026-09-07. Verification and limitations are in [BRIEF](BRIEF.md).

- Replace obsolete root build status with implemented scope and explicit remaining economy work.
- Verify setup and test command signatures against scripts and CI.
- Remove completed pivot instructions from active onboarding; preserve a dated snapshot.
- Correct C003 blockers and the tests guide without asserting new measurements.
- Document the existing playtest adapter and its platform constraints.

Acceptance: changed local links resolve; documented check commands run or limitations are reported;
no statement claims a full game, cross-platform proof, or complete CI pass without corresponding evidence.

## Batch 2 — documentation and evidence

Completed 2026-09-07. Historical records remain at stable paths with explicit queue routing.

- Preserve prior operational guidance and WORKING before shortening the active pages.
- Establish one task entry point, retaining source IDs and unresolved decisions.
- Distinguish historical visual proposals from approved work.
- Keep completed migration documents accessible at stable paths as references.
- Specify evidence retention without moving or deleting unique artifacts.
- Reduce status-update duplication and record an actionable iteration-cost investigation.

Acceptance: current work stays concise, every former queue has explicit routing, historical records
remain accessible, and no unresolved item is silently treated as closed.

## Batch 3 — subsequent organization work

- Inventory actual harness/adapter, test-support, capture and profiling ownership.
- Propose individual file moves with callers, resource references, UIDs and suite-membership checks.
- Consolidate placeholder directories only after their contracts have a destination.
- Audit module comments and current API contracts, preserving necessary port provenance.
- Inspect cohesion of files near the size cap; avoid splits solely to satisfy a number.
- Reuse existing CI-derived suite selection; do not create a duplicate suite manifest.
- Cache each local step evaluation within one gate-status invocation. Repeated resolution currently
  re-executes checks; verify with a counted runner and preserve separate CI and local verdicts.
- Evaluate checkpoint regeneration and archived-log distribution with retention manifests.

Acceptance: unchanged gameplay/replay results, preserved tests and resource resolution, and documented
fresh-clone workflow. Runtime reorganizations require their relevant tests; doc-only batches do not
justify repeatedly running expensive visual or model-driven episodes.
