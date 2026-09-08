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

## Design context for the next milestone (advisory, 2026-09-07)

Owner: director/PM for rulings; engineering for explicitly assigned experiments. This synthesizes the
director/Astra discussions of groundwater, water transport, grapple anchors, and reasons to keep playing.
It is NOT a replacement GDD, an approved implementation list, or an instruction to interrupt a batch.
Earlier status rows on this page require revalidation; they predate the recent rig/opening work.

### Read at the next safe checkpoint, not inside a stranger mission

At inspection HEAD was `41d31df68efb962e2aa44f54f6c9582a4445f99f`; seats 115-120 were running
from runtime copies. Finish and classify that batch against its pinned build and mission. Do not change
its prompts, thresholds, fixtures, or tested runtime in response to this context. Keep this document out
of blind actors' and blind judges' inputs: it supplies the desires those evaluations should discover.
The next feature remains the current director-approved queue until the director explicitly changes it.

### Experience hypothesis: more reasons to care about the same world

The rig supplies direction, not every reason to play. Seek overlapping, voluntarily chosen projects:
acquisition (that copper), comfort (a better journey), mastery (a self-feeding forge), curiosity (that
flooded arch), ownership (my workshop), and progression (a genuinely new capability).
Desired rhythm: discover -> improvise -> build -> enjoy the improvement -> choose another project.
An established district should be dependable under an adequate automated supply, while new excavation
creates fresh uncertainty. Dependable does not mean free upkeep, infinite fuel, or guaranteed immunity.
Continuous groundwater is compatible with this; neither its success nor its failure is established.
Do not turn a finished project immediately into another emergency. Human enjoyment remains unmeasured;
agent continuation is a stated proxy, not proof of fun, addiction, or session length.

### Water: reclaim territory, then make the obstacle useful

- Distinguish finite stored water from replenished groundwater. A reservoir being full does not make it
  infinite. A permanent source needs a declared replenishment rule, independent of player success.
- Water enters exposed permeable ground and accumulates when supply exceeds removal. A water table
  explains seepage; it does not eliminate seepage. Model volume first; geometry determines height.
- A local reservoir may be avoided. Required deep material can make the broader wet region relevant,
  while route, exposed area, sealing, and workshop placement give different responses to it.
- Reclaiming a chamber should offer access, useful space, discovery, or a better installation, rather
  than merely satisfying an instruction to buy a pump. Later coolant use is already a design direction.
- A dry layer beneath a wet region needs an explicit geological/game rule and drainage consequences.
  Rain is not part of this proposal; surface weather remains on the supplied spec's dead list.
- Flood scrap, silt, and slow dismantling are existing design commitments with cumulative punishment
  risk. Evaluate them; this discussion does NOT authorize removing or weakening them.
- Do not commit to a cavity-level solver on an unmeasured cost claim. Air-connected caves can contain
  separate pools; narrow passages, topology changes, and active fluid work still have costs. Consider a
  small source integration with existing fluid machinery before proposing a replacement solver.
- Rendering can be local; active world simulation must not depend on the player's camera. Offline
  shaft simulation remains frozen. Pump discharge/deletion must be a declared rule, not a visual lie.

### Water transport: promising, NOT approved

Moving water carrying loose goods could reinforce terrain-as-routing and make one system useful for
access, transport, atmosphere, and eventually cooling. Standing water should not be a conveyor.
Start any approved experiment with finite release, lateral/downward flow, and visible recoverable goods.
Keep machines immobile; avoid a new density taxonomy or item destruction in the first experiment.
Verify goods actually enter the world: reported hand mining yields into the pack, so a reservoir alone
does not create the intended dug supply. Ordinary dropping or machine output must supply loose cargo.

Explicit rulings required before gameplay implementation:

| Fork | What must be resolved |
| --- | --- |
| Sideways water transport | Reopens the feeder's exclusive transport role; retain a real role for controlled, compact transfer. |
| Powered upward water transport | Reopens lift economics and overlaps the proposed caisson; repeated small lifts can bypass the winch. Defer. |
| Replenished source | Define supply and exhaustion/head limits; no arbitrary full-enough-to-be-infinite threshold. |
| Reliable established districts | Test compatibility with finite deposits and fuel logistics; do not silently grant endless resources. |

### Beauty, traversal, and ownership

Water's signature moment should be a player-caused release that visibly follows their channel, carries
cargo, and changes a place. Prioritize readable surfaces/currents, spill-to-pool transitions, wet contacts,
visible cargo, restrained warm/cool lighting, and localized sound. Preserve legibility and measured GPU
budgets; this is not approval for a shader rewrite. Every UI element should feel considered, not loud.

A proposed grapple anchor assembly could improve familiar routes: a walk-through background mast with
a visible, forgiving target and a truthful preview. Require support; preserve natural anchors; avoid
floating anchor ladders or fiddly multi-part construction. Measure loaded hand-haul implications.
This is a candidate, not a new blueprint/unlock or a ruled movement change.

Ownership need not begin with a furniture economy: satisfying chamber shapes, deliberate machine
arrangement, good lighting, and recognizable routes can make an existing workshop feel finished.
Optional discoveries should sometimes be worth visiting without a current rig-material shortage.
Preserve useful old districts and quiet moments; avoid turning every apparent choice into a required
counter. Do not add combat, weather, decoration trees, or new hazards from analogy alone.

### Candidate experiments for PM selection, not an engineering queue

1. Reclaimed workshop: one dry base, wet useful extension, optional visible discovery, pump with legible
   supply, two viable excavation approaches, and a solution that can be left operating unattended.
2. One watercourse: ordinary input releases finite water and transports loose goods to a useful,
   recoverable destination. First check legal reachability and material/water accounting.
3. One supported grapple anchor: placement improves a repeated journey without making natural anchors
   obsolete. Judge aim, dismount, route comfort, and loaded travel separately.

Select one only after an explicit scope/ruling. Watch whether the player forms another project of their
own, understands causes, changes a layout, enjoys the result, and returns voluntarily. Do not give the
actor these desired answers. Use the existing [evaluation protocol](EXPERIENCE_EVALUATION.md); agents
cannot certify enjoyment, and a scripted witness cannot establish unprompted discovery.

## Iteration inspection: 41d31df6 (proposals, not implemented)

Read-only source inspection, 2026-09-07; no full battery or GPU benchmark run beside active seats.
Completed S109-114 manifests identify `af086f668b1197c5dac7d82c18f6626418cefa7f`; all final
responses have `quit=true`. Their 242 timing rows sum to 7,332.14 seat-seconds: between-command
`think_ms` 6,895.30 (94.0%), `play_ms` 427.51 (5.8%), pickup 2.28, capture/return 7.05.
These are SUMMED CONCURRENT SEAT TIME, not batch elapsed time or a measured feature-cycle split.
`think_ms` includes orchestration, tool/image handling, scheduling and inference; it cannot isolate
model speed. `play_ms` also includes settling/render work through capture, not just simulation CPU.
Source: completed scratchpad `stranger-109` through `stranger-114` timing.jsonl and batch.json;
the durable gameplay interpretation is [the batch report](playtests/2026-09-07_strangers109-114_stride.md).
Do not reinterpret its adapter-calibration failure as a new game verdict.

Already implemented: isolated runtime copies and concurrent seat launches (`playtest/batch.py`), shared
fresh-game snapshots, composed inputs, event-ended bursts (`seat_events.gd`), per-burst timing, replay,
and per-invocation gate-report deduplication. Do not assign these again as new optimization work.

Ranked next tooling proposals, each requiring a scoped implementation task:

1. Aggregate existing timing into one batch report, separating actual batch wall time, summed seat time,
   post-frame waiting, and burst execution. Add outer cycle spans for implementation, verification,
   review and reporting only where timing is currently missing. No new telemetry framework.
2. Harden `run_suites.sh` result accounting (expected identities, missing/duplicate results, worker
   failures), then have the local battery delegate its suite phase to that runner with bounded jobs.
   It currently loops serially. Preserve suite population, assertion floors, diagnostics, exit status,
   and full-battery-before-push policy; isolate shared writes before increasing concurrency.
3. Give battery gates unique per-run logs instead of shared `/tmp/gate.log`; preserve parser failures
   even after partial output. Runner tests must inject failure and missing-result cases before trust.
4. Reuse verified battery receipts for reporting only with exact source/input/environment identity.
   `gate_status.py` currently reruns local gates even after a battery; its existing cache lasts one
   report only. Explicitly distinguish reused evidence, fresh checks, CI status, and stale/unknown.
5. At an approved milestone, replace repeated full journeys with focused replay/encounter checks for
   known defects; retain blind journeys for changed discoverability. Calibration changes (like D0520)
   form a new actor condition, not a clean before/after gameplay comparison.
6. Pilot a step tool returning the original captured image and minimal player receipt together, so a
   separate image-open/model turn is unnecessary. Keep original pixels, journal/input artifacts, and
   diagnostic isolation. Measure calls, latency and actor outcomes; no downsampling assumption.
7. Schedule ready seats independently and benchmark bounded concurrency, not simply more windows.
   `batch.py` launches seats, not model inference: `--model` is recorded metadata in `stranger.py`.
   Inspect the outer agent scheduler before attributing waits to provider limits or serial dispatch.

Do not replace the fluid/game systems, train a local model, weaken CI, remove evidence, or change blind
observation semantics as an incidental efficiency fix. Runtime isolation permits code work during a
frozen episode only after snapshot/copy provenance is complete; it does not isolate CPU/GPU contention.
