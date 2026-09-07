# Active backlog

Status: task entry point, 2026-09-07. Existing P/T/V/D identifiers remain stable.
This index consolidates execution routing; historical records retain detailed findings.
A candidate requiring revalidation is not an instruction to implement it.

## Current work

| ID | Category / status | Next action and acceptance | Evidence / owner |
| --- | --- | --- | --- |
| CLEAN-1 | Documentation / complete | Public setup/status corrected; focused command, schema and links checked | [Cleanup plan](CLEANUP_PLAN.md) |
| CLEAN-2 | Documentation / complete | Concise working state, queue routing, preserved history and retention policy | [Cleanup plan](CLEANUP_PLAN.md) |
| CLEAN-3 | Organization / queued | Reconcile harness, tools and test ownership; preserve discovered suites and resource paths | [Cleanup plan](CLEANUP_PLAN.md) |
| OPENING | Gameplay / engineering continuation | Evaluate forge checkpoint, then wood and BUILD; validate on named build | [Gameplay brief](archive/cleanup-2026-09-07/BRIEF.md), D0479 |
| AIM | UX / decision required | Resolve effective-target preview and reach seam from recorded presses | [First-rung evidence](playtests/2026-09-07_strangers61-63_shipped.md) |
| TRAVERSAL | Feel / decision required | Review sinkhole placement, stride, grapple corner behavior; replay before changing | [Taste records](TASTE_QUEUE.md), [body swing](../sim/body/body_swing.gd) |
| ECONOMY | Design / unimplemented | Scope rig demand delivery and first unlock; measure C003 when executable | [C003](../claims/C003-cold-start-reaches-d1.md), A′ step 7 |
| LOOP | Tooling / proposed | Measure action-to-verdict latency; reuse replay and checkpoints before new orchestration | [Iteration policy](#iteration-cost) |
| GATE-REPORT | Tooling / observed overhead | Deduplicate local step evaluation within one report; preserve CI/local distinctions and failure status | [gate_status.py](../tools/gate_status.py), repeated local mutation sweeps observed during cleanup |
| VISUAL | Visual / candidates need revalidation | Select one current failure, compare identical play-zoom frames | [Visual evidence](VISUAL_QUEUE.md), [review candidates](VISUAL_REVIEW_QUEUE_2026-09-07.md) |

## Existing record ownership

- P identifiers: [NEEDS_DIRECTOR](NEEDS_DIRECTOR.md). Explicit CLOSED/RULED entries remain historical.
  Other entries require checking their cited implementation against current HEAD before scheduling.
- T identifiers: [TASTE_QUEUE](TASTE_QUEUE.md). Decisions remain the director's; no cleanup rules them.
- V identifiers: [VISUAL_QUEUE](VISUAL_QUEUE.md). Later executed sections may supersede earlier findings.
- September 7 numbered recommendations: [review](VISUAL_REVIEW_QUEUE_2026-09-07.md).
  These are proposals, some conflicting with later decisions; retain section plus item number.
- D identifiers: [ledger](DECISIONS_LEDGER.md), rationale rather than a work queue.
- Audit and playtest reports: evidence, not independently maintained task status.

When selecting a historical item, create one row here using its existing ID, name the current
reproduction and acceptance criterion, and link to the source. Do not re-open an explicitly closed
item without new evidence. When closing a row, update its source status or add a superseding reference.
No historical candidate has been silently marked fixed by this consolidation.

## Iteration cost

The reported 40% measurement / 25% verification / 20% documentation / 15% overhead split is an
estimate, not a timing result. It omits a distinct implementation category.
Before changing orchestration, measure one representative cycle: implementation, focused tests,
required gates, agent/model wait, simulation/capture, performance measurement, and documentation.
Record wall time separately from summed concurrent task time.

Prefer focused regressions during development and required integration checks at the completed batch.
Run stranger episodes for changed discoverability or interaction, not every internal refactor.
Use the existing replay, ceiling, suite selection, and checkpoint tools before adding replacements.
Do not overlap benchmark runs with other resource-heavy work. Independent read-only review can overlap;
shared-file edits need explicit ownership. A second runtime tree would need a separate isolation design.

Documentation completion updates one owning record and a short session handoff. Do not reproduce
a whole report in WORKING, BRIEF, every queue, and the ledger.
