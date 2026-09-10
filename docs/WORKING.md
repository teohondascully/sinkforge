# Working state

**Last updated: 2026-09-09 (performance programme and its audit; gameplay measured by strangers 127-132, D0544).**

## Performance programme — the five passes, September 8

**D0547 runner/GPU checkpoint:** foreground argv now permits focus and a PID-scoped keeper requests
it; measured focus still gates claims (latest 0.92/0.95, withheld). Setup and density counts survive
JSON; runtime/settings/engine provenance constrains comparisons. Metal System Trace produced real
PID-filtered GPU intervals; Godot's zero GPU timer remains unmeasured. Exact shader parity is OPEN.
Claude's `d344a35d` included the initial five tooling files; do not reapply those changes.
[Status, reproduction and verification](audits/2026-09-09-runner-gpu-closeout.md).

**D0542 implemented:** paired slowest-preparation receipts and per-chunk scheduling reasons now
reach the saved performance report. One 900-tick dig trace attributes its 9.793 ms warm peak to
four optional-margin callbacks (1,024 rectangle cells). Focus was lost: frame metrics withheld.
Six focused engine suites plus Python fixture tests pass. No scheduling/art change or full-battery
claim. Next: cold-descent coverage and a bounded optional-margin treatment; see the handoff below.

**September 9 review, D0541:** D0540's streaming attribution is not established. Peak preparation
time and peak cells are independent extrema, not one event, and rectangle area does not identify
a lane. Before scheduler changes, retain a paired slowest-event receipt and scheduling reason through
the draw callback. [Claude handoff and bounded implementation queue](audits/2026-09-09-bake-burst-handoff.md).
Three focused bake/fixture suites pass; no runtime changes or new FPS claim in this analysis pass.

**D0539 small follow-up:** explicit camera resets clear camera interpolation history, including
cuts below the inferred-teleport threshold. Four new assertions failed before the fix; camera,
main-boot and world-view suites pass afterward. Miner history/simulation are unchanged;
interpolation remains opt-in. Focused verification, not a full-battery or motion-quality claim.

**D0538 audit corrections take precedence over the historical summaries below:** the fixture now
rejects failed/incomplete processes and empty repetitions, suppresses withheld frame comparisons,
retains raw parsed windows, reports actual maximum separately from median window maxima, and uses
the real frame denominator. Peak preparation per physics tick is now instrumented. The earlier
54.5 → 21.5 ms was a median-of-maxima claim, not actual worst-frame evidence. The prefetch utilisation
argument compared different populations and is withdrawn. Wide zoom showed a 6.865 ms preparation
burst against 0.306 ms/tick average; presentation numbers were withheld. Fresh cave captures do not
reproduce the claimed blanket 2.4–3x brightness excess. Full corrections and artifacts are in the
[audit report](audits/2026-09-08-performance-programme.md). Shader parity, lane-specific burst
attribution, interpolation motion review and water/large-factory coverage remain open.

Astra's pass 1 is committed at `6b4b5e6c` (D0533, exact-picture neighborhood sharing) and pass 2 is
partial at `b836bac3` (D0534, the OFF-by-default shader prototype retains surface tufts). The engineer
verified both, ran the complete battery Astra's handoff left outstanding (172 checks, 144 suites, 0
failures) and carried the remaining queue. Full account for audit:
[the report](audits/2026-09-08-performance-programme.md).

**The measurement came first (D0535).** `tools/perf_fixture.py` plus `view/visuals/bake_cost.gd` and a
calibration loop in `shell/frame_meter.gd`: four named workloads, terrain preparation and upload split
from the draw, a fixed-work host-speed control inside every window, and six refusal rules that VOID a run
rather than report it. It refused four of its own first runs, correctly. A scripted seat is now deaf to
the machine's real keyboard and mouse -- `PlayInput.verbs` read the hardware on every seat, driven or
not, so a keystroke typed by whoever owns the laptop could change what MINE snaps to.

**Where the frame stands -- MEASURED VALID for the first time (D0551), `--front`, quiet desktop, 1280x720,
zoom 2, M4 Pro, window focused in 100% of frames.** All four workloads, 3 reps, controls 1.37-1.44:

| workload | fps_wall | p50 | p99 | max | over 16.7 ms | bake prep |
|---|---|---|---|---|---|---|
| still | 394.6 | 1.62 ms | 15.73 ms | 26.25 ms | 0.84% | **0.000 ms/tick** |
| walk | 381.3 | 1.52 ms | 16.51 ms | 32.21 ms | 0.97% | 0.070 ms/tick |
| dig | 348.7 | 1.55 ms | 17.70 ms | 35.08 ms | 1.47% | 0.537, peak 7.551 |
| fall | 377.9 | 1.46 ms | 17.79 ms | 35.45 ms | 1.23% | 0.395 ms/tick |

**The median clears 2.78 ms everywhere; sustained `fps_wall` straddles 360 rather than clearing it.**
The earlier "400-530 fps, 360 already met on the average and the median" is WITHDRAWN: those numbers came
from windows macOS was not presenting. **And the remaining tail is not the bake.** A still frame with
zero terrain preparation carries a p99 of 15.73 ms and a worst frame of 26.25 ms, so 89% of dig's p99 is
present when the bake does nothing; the draw phase's p99 is flat at 12.6-13.3 ms across all four and is
LOWEST on the workload doing the most terrain work. The worst frame is a different story and does track
the bake (dig exceeds still by 8.83 ms against a measured 7.551 ms peak preparation). The next target is
the draw-phase floor, not another bake treatment.

**Landed since:** the minimap repaints changed cells rather than the world (D0536) -- it was rebuilding
all ~17,000 logic cells on every terrain version change, 36.5-38.1 ms in one HUD chip on nineteen of
twenty slow frames of a mining run; the worst frame of that run fell 54.5 -> 21.5 ms, reproduced.
Presentation interpolation behind `--interpolate`, OFF (D0537): the camera and the miner presented
between sim ticks, lerped before the pixel snap so the grid survives, at no measurable cost. It is a
motion change and awaits the director's eye.

**Audited by Astra, D0538-D0539, and corrected.** Five real defects in the fixture: stderr discarded so a
failed seat looked healthy, no check that the process exited 0 or that every window arrived, `max`
reported as a median of per-window maxima under a worst-frame label, and an invented `/600` denominator
under the over-budget counts. Astra also fixed a real bug in D0537: `CameraRig.warp_to` never passed
through the teleport guard, so a short camera cut blended from a stale position (verified here -- their
four assertions all fire when the fix is reverted). Their peak-per-tick preparation telemetry is the
instrument the programme was missing.

**D0540, the claim re-measured and the next bottleneck named.** On the corrected fixture, with the
pre-D0536 minimap restored in the working tree and the control at 1.02x, the observed maximum falls
**61.08 -> 35.87 ms** and frames over 16.7 ms fall from 205 of 13,359 to 165 of 14,548. The earlier
"54.5 -> 21.5" was the mislabelled statistic and is withdrawn. The same run names what is left:
**preparation peaks at 9.0 ms in ONE physics tick over 1024 cells at ordinary play zoom**, against a
0.56 ms/tick average -- 3.2x the frame budget, untouched by the HUD fix, and the next thing to fix.

**The bake burst, D0541-D0543.** Astra's audit found D0540's "9 ms over 1024 cells" joined a peak
duration and a peak area the instrument had maximised independently, and built a paired receipt and
per-chunk scheduling attribution (D0542). On that: the optional margin is now capped per tick and ordered
one chunk ahead of the camera's own travel (D0543), with mandatory work uncapped and mutation-tested to
stay so. Default-zoom dig, both arms: the work is bit-identical -- 876 dig callbacks over 84,804 cells,
96 margin over 24,576 -- so the cap defers and drops nothing, and the slowest event moves from four
margin callbacks at 9.821 ms to four dig callbacks at 9.486 ms. The picture is byte-identical at a
settled tick. No timing improvement is claimed.

**The runner can measure frames again, and the GPU is measured at last (Astra's D0547, verified as D0548).**
`--front` was emitting `--unfocused` unconditionally, so the one regime a frame rate can be claimed from
was launched refusing focus -- which is why frame metrics were WITHHELD at focus 0.00 in every run of
D0542 through D0546. Astra fixed it (foreground requested by the launched PID), added source/settings/
engine provenance with comparison guards, and captured a real Metal trace. **GPU execution is 5.14% of a
20.477 s dig capture** (1,052 ms union of 19,958 intervals; Fragment 76.9%, Compute 16.6%, Vertex 6.5%) --
the first evidence for the CPU-bound premise this programme has assumed throughout. Verified here by
source read, an independent brute-force check of the interval union over 3,000 random cases, and a full
battery (173 gates, 145 suites) under a working-tree guard. **Still open: `FOCUS_MIN = 0.95` and the
option-conflict guard are UNPINNED** -- lowering the threshold to 0.50 keeps every test green, on the one
number that decides whether a frame measurement may be believed. Reported to Astra, whose file it is.

**Half the dig's dilated work is the chunk split (D0549).** `plan_tick` computes one `dig_rect` and
`partials_of` cuts it along chunk boundaries; each piece then builds its own `RockNeighborhood` over its
own dilated rect, so adjacent halos overlap. Measured across three windows: **overlap 50.8%, 50.8%,
49.2%** -- about 1,050-1,130 dilated cells a dig tick computed twice and drawing nothing, a ceiling of
~74-76 ms against ~157-162 ms of dig preparation. The per-tick and per-callback accumulators, wired on
opposite sides of the frame, agree exactly (50,828 both ways). A sharing treatment would be
picture-identical -- `RockNeighborhood.code()` indexes by absolute cell -- but is NOT implemented: it
threads shared state through `Frame` into `TerrainPainter` and needs a byte-identical capture and an
interleaved A/B, which D0547 has only just made possible.

**Streaming coverage is verified and the prefetch is not starved:** 96 chunks streamed as margin at
default zoom and 128 at wide zoom, with **zero arriving on screen unpainted**, before and after.

**What it redirects, and what that redirect turned out to be worth (D0545).** Digging is 85% of
preparation and margin 15%, and the handoff's third case -- dirty-repaint region setup -- is now
**measured and closed as the leading suspect**. `BakeCost.prep_setup_*` times the observation apart from
the painters: region setup is **14.0% and 12.7% of preparation** across two warm dig windows, at an
observed-over-painted area ratio of **7.33x and 7.14x**. The inflation is real -- every bake rect is
grown by `WINDOW_MARGIN_CELLS` (9) on four sides while the clock is charged over the painted rect -- but
it explains only about **17%** of the 5.5 us/cell gap between dig (14.4) and margin (8.9). **D0546 finished it: solid-cell
density is not the answer either (dig 75.2% solid against margin 69.4%, a 1.08x difference), and the
real denominator is the DILATED span.** `TerrainPainter` builds one `RockNeighborhood` per callback over
`cells.grow(FORM_REACH)` and scans it three times; charged per dilated cell the two reasons converge to
**3.01/2.94 us (dig) against 2.71/2.86 (margin), within 3-11%**, where per painted cell they differ
1.64-1.82x. So a dirty repaint is dear because a dig plans MANY SMALL RECTS and every per-callback cost
is paid over a grown region, not because a dug cell is dear. The treatment that points at -- coalescing
a tick's dig rects so the dilation is paid once -- is an affected-area change, is NOT implemented, and
its cost (the union repaints cells that did not need it) is unmeasured. Five mutants killed across the
two entries. No scheduling, picture, or FPS claim. Left open: at wide zoom a terminal-velocity fall's slowest event is three margin callbacks
at 28.089 ms, which is what avoiding a hole costs there; its before arm came back VOID and that A/B is
inconclusive and was stopped rather than stacked.

**Not done, with reasons in the report:** the shader prototype stays OFF and unfixed -- its divergence is
not the reported seam but a whole-surface brightness difference that grows with distance into the rock
(2.44x at a cut's edge, 3.00x five cells in), so the carved-edge lighting gradient is the suspect and
enabling it is a director art call (T040). Movement-ahead prefetch was inspected and NOT built, but that
inspection's central number is WITHDRAWN (D0538): 46 and 31 cells a tick is repainted rectangle area
including air and unbudgeted dig repaints, not solid cells admitted by the window lane, so it cannot be
read against a 512-solid-cell budget. What survives is that no visible hole appears at the first
presented frame after a cold warp to 131 m -- and D0540's 9.0 ms single-tick burst says the lane's
scheduling is the open problem after all.

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
receipt using the ring's word (D0530) -- both now MEASURED by strangers 127-132 (D0544, below).

**Strangers 127-132, 2026-09-09 (D0544), on `60da8d1d`, all six VALID, 0 Invariants.** Four ore 6 of 6,
coal 5 of 6, two ingots 3 of 6, delivered 1 of 6, the drill placed 0 of 6.
[The report](playtests/2026-09-09_strangers127-132_hotbar.md). **D0529 fires exactly on its trigger** --
three seats entered the 4-cell edge band, all three saw the lesson, no seat outside a band saw one; two of
the three then left the band, where two of three ended at the edge in 121-126. **D0530 was seen once**, by
the only seat that finished a rung past deliver, and that seat did not quit on the card; one observation,
not a measurement. **The batch's finding is neither lesson: the hotbar renumbers itself under the player.**
`slots` is the bar's own order, draining a stack removes it and shifts every later stack down a number, and
re-acquiring it appends at the end -- so the smelt rung, which asks the player to drain stacks into a
machine, is what invalidates the numbers the card tells them to press. Four of six fed or selected the
wrong stack; the only seat that delivered is the only one whose bar never reordered. No regression is
claimed from 3/6 to 1/6 delivered: six seats cannot separate those. Live and separate: two seats stood
beside a ringed RIG at TOO FAR.

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
