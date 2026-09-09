# Working state

**Last updated: 2026-09-08 (tooling; gameplay section reconciled September 7).**

## Current stage

The A′ legacy port has implemented the playable systems through its presentation and generation work.
The rig-as-consumer economy (A′ step 7) remains unimplemented.
[The backlog](BACKLOG.md) owns task routing; [the plan](A_PRIME_REFACTOR_PLAN.md) retains port detail.

## Gameplay continuation

**Reconciled 2026-09-07 late from the engineer's verified batches (D0506-D0520).** The opening is measured
by six-seat blind batches on the shipped seed, all seats VALID, reports under [playtests](playtests/):
103-108 (`2026-09-07_strangers103-108_drop.md`), 109-114 (`..._stride.md`), 115-120 (`..._reach.md`),
121-126 (`..._inreach.md`).

Where the opening stands, by rung, over the last four batches (24 seats): four ore 24 of 24; coal in the
pack 21 of 24; two ingots 8 of 24; delivered 4 of 24; the drill placed 2 of 24; the fuel rung reached by 2.
The last batch alone (D0521, the ring reads IN REACH by the drop's own rule): smelt 3 of 6, delivered 3 of
6, the drill placed 2 of 6, against 1 delivery in the 18 seats before it. The walls left in it: the world's
east edge (14 of 24 seats walked to it), the ceremony card read as the end (2 seats), a self-dug pit.

Landed since the first-rung brief: the boots' footing (D0509), the lazy terrain bake and the tooth's
grammar texture (D0506, D0511), the drop refused with the stack in hand when its eater is in sight but
out of reach (D0513), the FED receipt and the TOO FAR lesson with metres and direction (D0517), the cards
leading with WALK and STAND (D0515), the floor-ambiguity check bounded to its subject (D0516: 0 reports a
seat, from 38-168), new_game's phases and the batch's fresh-game snapshot (D0518, D0519: a seat boots in
0.7 s, six in 5.4 s wall), the mission's tick calibration (D0520: it did not change the actor's walks),
the ring's IN REACH state (D0521), the spider cracks removed at the director's ask (D0523), THE EDGE
lesson at the world boundary (D0529) and the acknowledged rung's card naming the next rung with the
receipt using the ring's word (D0530) -- the last two answer the walls 121-126 left and are UNMEASURED:
the next batch is their test.

The director's freeze, measured and mitigated: the investigated blow stalls were terrain bake work, not the sim (0.3 ms a tick
headless). A blow repaints its own dilated rectangle, chunks are 16 cells, and the streaming lane budgets
solid cells a tick (D0522, D0524: worst blow frame 419 -> 60 ms, a shaft fall's worst 80-90 -> 22-23 ms);
a still frame redraws only the layers whose input moved (D0531, ~5% of the still tick; the 18 ms still
frames themselves are display pacing and a slow host, D0527, not a painter). The floor left is the CPU
molded tone at 18-25 microseconds a solid cell: T040 in the taste queue carries the shader evidence
(D0528, behind a flag that is OFF) and the orchestrator's read that its picture is not yet the CPU's.

For the director (numbers in the reports): the stride at 9 m/s against a 3.2 m reach (T035); the layout
(the forge alone lies left of the spawn, and everything else right of it); D3-D6's rewards; the hotbar
with an empty pack (D0412); T040's fork. Unresolved and unchanged: the grapple, wood, the sinkholes near
the pad, evaluator diagnostics in observations. The rig-as-consumer economy (A' step 7) is still
unimplemented; the rig pays the drill for two ingots (D0485) and the winch pair for six (D0492).

## Repository cleanup (director-approved)

Tooling implementation complete (D0525): timing summaries, runner accounting/optional battery
parallelism, provenance-checked reporting receipts, parser/log isolation, and an opt-in
command-plus-image pilot. [Execution evidence and rollout limits](superpowers/plans/2026-09-07-iteration-efficiency.md).
Focused tests and the real-engine runner self-test pass; no whole-battery speedup or live-agent
latency improvement is claimed. Fresh checks and existing actor protocol remain the defaults.
Active director assignment: optimize the terrain shading hot path after the engineer's D0522/D0524,
preserving appearance. 360 fps is a measured host-specific target, not a hardware-independent guarantee.
Implemented D0526: bounded byte solidity, skip zero-weight bedding, reuse AO offsets. The focused
shading sample costs 40-56% less with identical colour hashes; this is not a full-frame speedup claim.
The CPU slice was incorporated in c8385ca3. Its full verification passed 28 gates and 142 suites before
the engineer's subsequent additions; that run is not certification of the now-144-suite tree.
D0528 subsequently added the GPU prototype, off by default; appearance parity and presentation
interpolation remain undone. Twelve focused integration suites pass on 41f00226 (D0532), including
the shader-data path, world view and main boot; the current full 144-suite battery was not rerun here.
Reproduction and next bottlenecks: [performance plan](PERF_PLAN.md).
Sequential continuation: D0533 completes shared per-region CPU shading with exact picture parity;
the existing shader prototype's seam/appearance correction is next, then prefetch, interpolation and
remaining dynamic painters. No 360 fps acceptance claim yet.
The gameplay section above was reconciled by the engineer at their 2026-09-07 late checkpoint
(after strangers 115-120); the batch queue is theirs, the tooling queue is this section's.

- Batch 1: accurate README, contributing commands, onboarding, tests guide and C003 blockers.
- Batch 2: concise working state, documentation authority, backlog routing and evidence retention.
- Batch 3: subsequent harness/test/tool organization and module-contract cleanup.

Batches 1–2 are documentation work; no gameplay, source paths, evidence, or CI checks are removed.
Batches 1–2 are complete. Focused item suite (78 assertions), schema/codegen, documentation links,
snapshot fidelity, working freshness, ledger integrity and CI non-shrink checks passed.
Gate-status found no completed CI run for the starting HEAD; full CI is not claimed.
The reported iteration-time percentages are estimates; measure one cycle before changing orchestration.

## Durable history

The full prior working state is preserved in
[the dated snapshot](archive/cleanup-2026-09-07/WORKING.md), including measurements and open forks.
[The ledger](DECISIONS_LEDGER.md), [playtests](playtests/), and [visual records](VISUAL_QUEUE.md)
retain source evidence. Do not execute completed instructions from the snapshot.
