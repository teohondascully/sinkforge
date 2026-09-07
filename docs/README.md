# Documentation guide

Status: current navigation, 2026-09-07. This page assigns document responsibilities;
it does not supersede gameplay rulings or engineering policies.

## Start here

| Need | Owner |
| --- | --- |
| What runs today; quick start | [Root README](../README.md) |
| Setup, tests, content generation, commits | [Contributing](../CONTRIBUTING.md) |
| Session orientation and operating rules | [Context](../CONTEXT.md) |
| Current execution state | [Working state](WORKING.md) |
| Active work and routing to existing IDs | [Backlog](BACKLOG.md) |
| Intended game design | [GDD](GDD.md) |
| Implemented boundaries and architectural contracts | [Architecture](ARCHITECTURE.md) |
| Required checks | [Quality](QUALITY.md) |
| Claim definitions and evidence limits | [Claims](CLAIMS.md) |
| Decision rationale | [ADRs](adr/README.md), [decisions](DECISIONS.md), [ledger](DECISIONS_LEDGER.md) |

Design documents describe intended behavior; they do not certify implementation.
The ledger is an append-only historical record. A newer explicit ruling may supersede an older one.
Find relevant IDs through a targeted search; reading the full ledger is not routine onboarding.

## Current execution and review

[WORKING](WORKING.md) owns current session state. [BACKLOG](BACKLOG.md) is the task entry point.
[BRIEF](BRIEF.md) summarizes the most recently reported session, with its scope and evidence.
[BRANCHING](BRANCHING.md) retains the repository's branch policy.

Existing [director records](NEEDS_DIRECTOR.md), [taste records](TASTE_QUEUE.md),
[visual findings](VISUAL_QUEUE.md), and the [September 7 review](VISUAL_REVIEW_QUEUE_2026-09-07.md)
retain their IDs and evidence. Their old rankings are not fresh execution orders.
Route new work through BACKLOG and update its owning record rather than duplicating a task.

## Evidence and historical reference

- [Playtests](playtests/): build-specific observations, not universal claims.
- [Audits](audits/): findings against the audited build.
- [Milestones](MILESTONES.md): curated capture provenance.
- [Corrections](CORRECTIONS.md): the ledger's recorded amendments.
- [Experience evaluation](EXPERIENCE_EVALUATION.md): evaluation design; not proof that its proposed pipeline exists.
- [Evidence policy](EVIDENCE.md): fixtures, curated evidence, and routine outputs.
- [Archive](archive/README.md): superseded instructions and preserved records.

The [A′ plan](A_PRIME_REFACTOR_PLAN.md) and [flip analysis](FLIP_ANALYSIS_2026-09-02.md)
explain the approved port. Completed steps are historical; the economy remains unfinished.
[Migration map](LEGACY_MIGRATION_MAP_2026-08-29.md), [legacy gap](LEGACY_GAP.md),
[port order](PORT_ORDER.md), [performance plan](PERF_PLAN.md), and
[coordinator contract](COORDINATOR_CONTRACT.md) retain their measurements and source mappings.
They are not independent current task queues.

## Maintenance

Give new documents a status and a defined owner/purpose. Keep measured claims tied to their build.
Archive completed instructions only after preserving unresolved work and stable references.
Do not move large evidence collections or rewrite Git history as incidental cleanup.
The prior guide is preserved in [the cleanup snapshot](archive/cleanup-2026-09-07/README.md).
