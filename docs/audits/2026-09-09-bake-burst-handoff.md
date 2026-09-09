# Bake-burst attribution: handoff to Claude

Reviewed head: `b9f1f7c1`. Scope: source analysis of D0540 and the scheduling change it recommends.
No renderer or fixture behavior changed in this pass. This is not a new performance benchmark.

## Bottom line

Keep the minimap optimisation. D0540 reports a corrected before/after with actual maxima; this review
does not rerun that experiment. Preparation bursts are a legitimate next target. However, the current
evidence does **not** identify the streaming allowance as their cause. Do not split or cap mandatory
digging work based on the number 1024 alone.

## Findings

### 1. Peak time and peak cells are not one event

`view/visuals/bake_cost.gd:57` independently updates `prep_tick_max_cells` and `prep_tick_max_usec`.
`tools/perf_fixture.py:320` independently maximises them again across warm windows. Neither preserves
the identity of the tick that produced a maximum. D0540's wording "9 ms ... over 1024 cells" therefore
joins measurements the instrument did not join.

Reproduction using the real summariser, no game or timer involved:

```text
warm sample A: peak_cells=200,  peak_prep_ms=9
warm sample B: peak_cells=1024, peak_prep_ms=1
summary:       warm_peak_cells=1024, warm_peak_prep_ms=9
```

This is a limitation in D0538's telemetry, which I authored. Both extrema are individually useful;
they must not be interpreted as the attributes of one event. Fix the producer as well as the Python
aggregation: pairing already-independent window maxima in Python cannot recover the missing event.

### 2. Rectangle area does not identify a lane or a chunk count

`BakeChunk._paint` at `view/visuals/bake_chunk.gd:177` returns the area of the paint rectangle. That
rectangle can be partial or whole and includes air. Every preparation callback uses the same counter.
`BakeWindow.plan_tick` combines mandatory dig work and window work into `Plan.whole` and `Plan.partial`;
the cost stamp no longer knows why a chunk was selected.

1024 cells equals four full-chunk *areas*. It does not prove four full-chunk callbacks, a streaming
selection, or 1024 solid cells. Several partial rectangles can sum to the same number.

### 3. The streaming budget is not a whole-frame cap

The current policy has four distinct cases:

| Case | Current behavior | Safe action if it dominates |
|---|---|---|
| Initial bake | Paint everything required | Treat as startup; measure separately |
| Dig-influenced terrain | Mandatory, outside window allowance | Reduce work per dirty region; don't defer visible excavation |
| Previously unpainted terrain already visible | Mandatory even beyond allowance | Prefetch earlier or reduce paint cost; don't introduce holes |
| Not-yet-visible margin | Budgeted at 512 solid cells | Defer or prioritise this optional work |

`tests/test_bake_budget.gd` already demonstrates this distinction: twelve solid margin chunks drain
two per tick; moving the view exposes five chunks and admits 1280 solid cells immediately; a dig can
add whole chunks without spending the margin's allowance. All these cases passed in this review.

A shared remaining-work budget may help **optional margin work** coexist with digging. It cannot
promise a 2.78 ms frame when mandatory work alone exceeds that time. Do not reinterpret "shared budget"
as permission to delay the cut a player just made.

### 4. Zero solid cells is not necessarily zero preparation cost

`BakeLane` permits every zero-solid-cell margin chunk. But `BakeChunk._paint` still observes its region,
invokes the retained painters (including the background-wall painter), and fills the grammar map.
An air foreground over a wall is not an empty rendering workload. The budget is a useful proxy for
rock shading, not a proof that these callbacks are free. Measure this before adding a second budget.

### 5. The fall fixture revisits terrain it already painted

`shell/seat_drive.gd:138` explicitly describes falling down the shaft the same run first excavated.
This is useful movement/revisit coverage, but not a dedicated cold-streaming descent. Some work may
enter at the bottom; the fixture does not certify how much. A cold warp tests immediate coverage, not
whether a moving camera continuously outruns the prefetch margin.

## Implementation queue, in order

### D0542 implementation checkpoint — September 9

Items 1 and 2 below are implemented. `BakeCost.slowest` retains a deep-copied event with actual
physics/render IDs, planned ticks, summed preparation microseconds, rectangle cells, callbacks,
and per-reason totals. Per-chunk attribution survives to the draw callback. Detailed capture is
enabled by profiling; legacy independent maxima remain separate. `BURST` lines survive parsing
and JSON summarisation with their source repetition and window tick.

One 900-tick dig discovery trace (`/tmp/sinkforge-paired-burst-dig.json`, local ephemeral artifact)
found the slowest warm preparation event at physics 722/render 1499, planned tick 722:
9,793 microseconds, 1,024 rectangle cells, four callbacks, all `margin`. This is one paired
observation, not a join of maxima. Both warm windows lost foreground status, so frame metrics
are WITHHELD. It establishes optional-margin attribution for this event, not an FPS gain or a
universal cause. Scheduler behaviour and the rendered picture were not changed by this pass.

Verification: six engine suites (perf_fixture, bake_budget, bake_lanes, terrain_bake, main_boot,
world_view) passed; Python fixture tests passed including nested BURST parsing and opposite
time/area maxima. New producer and reason tests failed before implementation. No full battery
or cold-descent trace was run. Continue with item 3's cold-descent coverage, then a bounded
optional-margin scheduling treatment and matched picture/cost checks; do not enable the GPU
prototype or claim sustained 360 FPS from this instrumentation work.

1. **One paired burst receipt, not another benchmark framework.** Retain the slowest preparation
   event with its physics-frame ID, render-frame ID, elapsed preparation time, rectangle-cell count
   and actual callback count. Preserve separate maximum-area statistics under explicit names.
   Carry that same record through JSON; do not reconstruct it from extrema.
2. **Preserve scheduling reasons to the draw callback.** Classify whole selections as initial,
   dig-influenced, newly-visible, or optional margin; classify partials as dig-influenced. For overlap,
   mandatory wins, and charge work once. Pass classification with the planned batch, not mutable
   "current reason" global state: `_draw` occurs after planning. Record planned tick and actual draw
   tick so delayed rendering cannot silently change attribution. Include full-rebake fallback.
3. **Run one bounded discovery trace.** Default-zoom dig plus a pre-excavated, unbaked descent at
   widest zoom. The latter is a labelled performance fixture, not a golden gameplay episode. Require
   actual newly-visible callbacks during the timed descent; otherwise it is a revisit control only.
4. **Pick exactly one treatment from the receipt.** Optional margin dominates: subtract mandatory
   predicted cost from discretionary allowance and prefer chunks in the travel direction. Mandatory
   new-visible work dominates: extend prefetch lead without widening the observation blindly. Dirty
   repaints dominate: inspect repeated region setup and affected area before altering scheduling.
5. **Verify effect and picture together.** Same head/settings/seed/workload; interleaved A/B order;
   compare actual tails and the attributed phase. No stale cuts, missing terrain, starved prefetch,
   or changes to the deterministic sim. Stop after a bounded inconclusive trial rather than stacking
   runs whose noise hides the effect. Leave GPU cost labelled unmeasured until a real GPU instrument.

### D0543 implementation checkpoint — September 9 (Claude)

Items 3 and 4 are done; item 5's picture check is done and its timing half is inconclusive and stopped.

**Item 3, cold-descent coverage — ANSWERED WITHOUT THE FIXTURE.** `BakeCost` now carries per-window
per-reason totals, so the fixture separates prefetch that arrived in time (`margin`) from prefetch that
arrived late (`visible`). Default zoom: 96 chunks streamed as margin, **zero late**. Wide zoom (1.25,
the widest this 256-cell world supports at 1280 px): 128 chunks, **zero late**. Before and after the
treatment alike. The prefetch is not starved. Your acceptance criterion needed a third outcome, not two:
a run that crossed no new terrain has no margin work either, so "no visible callbacks" alone cannot tell
a revisit from a prefetch that never lost — the verdict now separates OVERTAKEN / COVERED / REVISIT ONLY.

A `descend` workload was written and removed: carrying the body through rock at terminal velocity is
cancelled exactly by the collision resolver and walks the body out of the world, and D0538 rightly voids
a run whose seat prints `ERROR:`. A real pre-excavated unbaked descent needs a world dug by one run and
loaded by another; that fixture does not exist and shipping the scaffolding would have claimed it did.

**Item 4, one treatment — optional margin, capped per tick and ordered toward travel (D0543).** The cap
is `ceil(wide * speed / CHUNK_PX)` floored at one, every term read off the window; the lead is one chunk
because the margin is one chunk deep. Mandatory work is uncapped and mutation-tested to stay that way.
Default-zoom dig, both arms: **the work is bit-identical** — 876 dig callbacks over 84,804 cells and 96
margin callbacks over 24,576 — so the cap defers and drops nothing, and the slowest event moves from
**4 callbacks / 1,024 cells / 9.821 ms, all margin** to **4 callbacks / 462 cells / 9.486 ms, all dig**.
No timing improvement is claimed: the before arm's control drifted 1.25x and the comparator refused.

**Item 5, picture: byte-identical** at a settled tick, md5 `1e08015770075ff9da0505bed9b4d51d`. Two
earlier attempts differed by 55% and were measuring the capture, not the render — an unposed shutter
tick, then a seat reading the real keyboard.

**What this redirects.** Digging is **85%** of preparation and margin **15%** (1,282 ms / 876 callbacks
against 226 ms / 96; 80/20 at wide zoom). The slowest single EVENT was margin and the population is
overwhelmingly dig — your finding 1's join, one level up. So item 4's third case is the live one, and it
is explicitly not a scheduling change. Dig repaints also cost 20.5 us a cell against a 12-14 us mean.

**Left open and NOT claimed.** At wide zoom the `fall` workload does reach terminal velocity, and with
the cap its slowest event was three margin callbacks, 768 cells, **28.089 ms in one tick** — the cap
raising itself to three to keep ahead, which is what not having a hole costs there. That run was SUSPECT
(control 1.25x); its matching before arm came back VOID (control 2.02x) and I stopped rather than stack,
per item 5. Frame metrics were withheld in every run tonight (focus 0.00). GPU cost stays unmeasured.

### D0545 checkpoint — September 9 (Claude): item 4's third case, measured and closed

Your item 4 said "dirty repaints dominate: **inspect repeated region setup and affected area** before
altering scheduling." Both halves are now measured, and the answer is a null on the leading suspect.

**The mechanism is real.** `WorldView.observe_rect:232` grows every bake rect by `WINDOW_MARGIN_CELLS`
(9) on all four sides and takes both planes (the per-frame path declines walls; the bake does not), while
`BakeChunk._paint` charges its clock over the PAINTED rect. Observed/painted is 1.33x for the per-frame
view, 4.5x for a whole chunk, 7-30x for a dig's partials. `interface/envelope.gd:78` already says the
neighbouring half: "It HURTS a caller that asks for many small rects."

**The measurement says it is not the bottleneck.** New `BakeCost.prep_setup_*` times `frame_for` apart
from the painters (a SLICE of `prep_usec`, never a fourth phase). 900-tick dig, zoom 2, two warm windows:
setup is **14.0% / 12.7% of preparation** at **7.33x / 7.14x** observed-over-painted. The area inflation
is exactly as predicted; the time is not where the cost lives.

**Where the gap actually is.** Same window: dig **14.4 us/cell** over 94 cells a callback, margin **8.9
us/cell** over 256 -- a 5.5 us gap. Apportioning setup by observed area, region setup explains **~17%**
of it. The remaining 83% points at **solid-cell density**, since `RockTone.shade` costs per solid cell
and skips air, and a dig site is rock where this workload's margin chunks are substantially air. That is
the next measurement and is explicitly NOT claimed here.

**A hazard I checked before touching anything, and it is a null.** `Interface.observe` drains
`_events`, `_drop_went` and `_build_went` -- the flow events, the FED receipt's landing and the BUILD
refusal -- and the bake calls it several times a tick and discards all of it. It cannot lose a player's
receipt: in `shell/main.gd._physics_process` every `door.apply` runs before `view.refresh()`, which
observes at once, and `_effects` afterwards only reads the frame; the bake's own observes happen later
in the chunk layers' `_draw`, on an already-empty channel. This also means sharing one observation
across a tick's chunks cannot change event delivery, if that treatment is ever wanted.

**Mutation-tested:** deleting the `note_setup` call fails 3 assertions, charging it the painted area
fails 2. The unit pins alone would survive the first, so the suite also drives a real `BakeChunk.paint`
over an observation window wider than the chunk it paints.

**Yours to rule on:** `tools/perf_fixture.py` does not parse the new `setup=` field, so it never reaches
the saved JSON — the numbers above were read off the seat's own report line. That file is yours; I did
not edit it. Adding one regex would put region setup into every future run's record.

## Tests that earn their cost

- Two ticks with opposite time/area maxima: the slowest receipt retains its own cells and tick.
- Two preparation callbacks in one draw: their sum and count share one event identity.
- Dirty chunk also requested by streaming: charged once, mandatory reason preserved.
- Mandatory work exceeds allowance: still shown now; optional work can wait and later drains.
- Air foreground with background wall: counted as a preparation callback, not declared free.
- Cold-descent fixture: both moving-body and newly-visible-paint witnesses; a warm replay is a control.

## Verification and limits

Three focused suites passed: bake_budget, bake_lanes, perf_fixture. The initial sandboxed launch failed
in Godot's user-log rotation before tests; the approved unrestricted rerun passed all three in two
seconds. CodeRabbit 0.7.3 is signed out, so this was direct source review, not a CodeRabbit result.
No full suite rerun, new FPS measurement, or claim that the shader seam is resolved.

The originally considered saved-run provenance improvement remains useful but is deferred. Do not
start that separate workstream ahead of the paired receipt needed to select the next game optimisation.
