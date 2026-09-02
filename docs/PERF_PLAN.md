# Performance — the 120 Hz programme

**The bar, set by the director 2026-09-01: 120 Hz. 8.33 ms a frame.** This document is the ranked,
sourced plan for getting there, and the recovered record of how legacy already did.

Everything below is quoted from, or measured against, `legacy/`. Legacy hit 120 fps **at this same
framing** — `legacy/scenes/world_renderer.gd:3154` states "The camera shows 40x22 cells at the 1.00x
default zoom" and `:2612` budgets against "4ms of the project's 8.33ms budget". So none of this is a
design limit; it is unported architecture.

## Where we are

**Painters, measured inside the frame by `view/draw_cost.gd` — the number that is trustworthy:**

```
painters total=4.01ms (budget 8.33ms at 120Hz)
  veil=2.99  sky=0.97  glint=0.03  bake=0.01  seam=0.01  crumble=0.01  crack=0.00
refresh=0.05ms (observe=0.03ms)   plane_rebuilds=21/600 ticks
```

Plus a sim tick of **1.58 ms**, measured with the tick clock unpinned. So the frame is ≈**5.6 ms against
an 8.33 ms budget**. Legacy budgets its own fine-fill at *"4ms of the project's 8.33ms budget"*
(`world_renderer.gd:2612`), so the painter total is at parity.

| painter | before | after |
|---|---|---|
| veil | 41.47 ms | **2.99** |
| glint | 11.86 ms | **0.03** |
| observe (not a painter) | 10.60 ms | **0.03** |
| terrain (baked, D0326) | — | 0.01 |

### A CORRECTION: the wall-clock "ms/tick" figures below ~16.7 ms were measuring a clock

`tests/body/reveal_scene.gd` ticks in `_physics_process`, which Godot pins at 60/sec. Three consecutive
optimisations all measured "15.9 ms/tick" — which is 1/60 s — while the per-painter instrument showed the
work inside the frame still falling. **The wall-clock slope had stopped measuring us.**

The 64.6 → 17.9 ms improvement it reported was real, because that work exceeded the tick interval. Every
number it gave below the interval was the clock. Vsync is the same trap one layer out and legacy warns
about it explicitly (quoted below) — this document carried that warning before the session walked into
its sibling.

**Rule: a wall-clock slope over `_physics_process` ticks is only valid ABOVE the tick interval. Use the
per-painter instrument, which is measured inside the frame and cannot be pinned by a refresh rate.**

## The instrument

`view/draw_cost.gd` + `PaintLayer.last_draw_usec` + `WorldView.draw_cost_report()`. Printed by the
shutter on every capture. **Build this before optimising anything** — legacy's own verdict, from
`legacy/tools/profile_frame.gd:3`:

> "check_frametime says a frame costs 39.59ms during a dig against an 8.33ms budget. It does not say
> WHY, and the project has never had a tool that does. […] So every optimisation decision so far has
> been taken against a total, which is how you end up tuning the wrong thing confidently."

### Two measurement traps legacy paid for and wrote down

* **Vsync makes a millisecond number unanswerable** (`check_frametime.gd:29`): *"When it is on, every
  frame that fits inside the refresh interval measures as exactly the refresh interval. A game with 4ms
  of headroom and one with 0.1ms both report a perfect 8.33, and the number says nothing."* The
  instrument that survives is the **missed-deadline rate** (frames past 1.5× the interval) **plus worst
  frame severity** — neither alone. Rate alone scored a real 30.5→17.1 ms fix as nothing (`:355`).
* **A timing measurement cannot share the machine** (`run_harness.sh:239`): IDLE p95 15.59 ms alone vs
  20.70 ms inside the parallel sweep. Contention once **inverted a verdict** entirely (`:316`).

## Done

- **D0326** — terrain and wall baked into one SubViewport quad. Measures 0.00 ms. Legacy: ~11,882 draw
  calls, ~72% of the frame, → 1.
- **D0336** — the veil is a metre-resolution lightmap, one `draw_texture_rect`, MUL blend, LINEAR filter.
  Was 14,080 `draw_rect` calls a frame.
- **D0337** — glint iterates a cached sparse cell list, not the visible rect.
- **D0338** — the per-frame observation no longer builds the wall plane; its only reader is baked.

## Next, in payoff order

### 1. `TileGrid` planes as a flat array — the remaining 6.36 ms

`Interface.observe` walks the window doing a `Vector2i`-keyed `Dictionary` lookup per cell (~18,900 cells
at this framing). **Legacy has no equivalent to port because legacy never paid this**: its renderer reads
`sim.solid` / `sim.deposits` / `sim.water` directly and builds no per-frame copy. `Interface.Observation`
is a rewrite-only construct and this is the bill our own layer separation created.

The fix is legacy-*shaped* even though the component is not — `factory_sim.gd:795`:

> "for consumers that would otherwise call `fine_is_solid()` a quarter of a million times. The renderer's
> boot bake did exactly that and spent **1.67s** on it; **handing the array over turns that loop into a
> memcpy**."

Back `TileGrid`'s planes with a flat `PackedByteArray` indexed `row * width + col` instead of a
`Vector2i`-keyed `Dictionary`; a window read becomes row slices. **Touches `state_signature`'s own
storage, so it is a determinism-sensitive pass and needs its own golden re-pin.**

### 2. Stop re-queueing canvases that did not change

`WorldView.refresh()` calls `queue_redraw()` on **every layer every tick**. Legacy's controller
**never calls `queue_redraw` at all** (`main.gd`, grepped) — the view is invalidated per cell by
`note_mined(cell)`, and `repaint_world()` is called from exactly one place, `_load_game()`. An
`ImageTexture.update()` mutates in place, so a retained `draw_texture_rect` shows new content **without**
being re-queued (`world_renderer.gd:526`).

### 3. Shared radial glow texture for every light pool

`_make_glow_texture()` / `_draw_glow()` (`world_renderer.gd:3634`): one 128×128 `GradientTexture2D`,
`FILL_RADIAL`, stops `[0.0, 0.42, 1.0]` → alpha `[0.92, 0.22, 0.0]`, one tinted `draw_texture_rect` per
pool. No shader, no per-light texture, no per-pixel CPU falloff. ~20 lines.

### 4. `LightLayer` — a canvas per blend mode

`legacy/scenes/light_layer.gd`, 25 lines, copy verbatim. Prerequisite for 3 and for the additive layer
below. Its header: *"each pass can carry its own blend mode, which a single CanvasItem cannot switch
mid-`_draw`."* Legacy's stack: `_dark` MUL at z 50, `_lights` ADD at z 51.

### 5. The additive light layer (also closes a D0336 deviation)

A MULTIPLY veil cannot brighten, so D0336 clamps the above-ambient half of the key light. Legacy answers
this with the second canvas rather than one pass doing both. Porting 4 then this restores the cue.

### 6. Fixed timestep with render interpolation

Legacy runs a single `_process` and hands the raw frame delta to `sim.advance(delta)`, which owns an
accumulator internally; the body substeps (`Player.MAX_SUBSTEP`) so it cannot tunnel. It has **no**
interpolation of sim state for rendering. Also worth copying: the **catch-up spiral guard**
(`factory_sim.gd:1920`) — past a cap the excess sim-time is **dropped by trimming the accumulator rather
than chased**, "so the factory momentarily runs in slow motion instead of locking up."

### 7. Budget the worst case, not the default

Legacy's widest rung is a **9.2× area multiplier** over its default (40×22 cells vs ~121×67), and legacy
had **no LOD at all** — no zoom-gated cell granularity, no painter skipping. Our ladder has the same
shape. Budget against the widest rung.

The one LOD legacy does have is sub-pixel detail gating (`visuals.gd:215`): *"Detail below the pixel grid
is not subtle, it is a cost with no image attached."* `draw_string` is called out as the priciest
per-call in the machine layer.

## Rules extracted from legacy, worth not rediscovering

1. **Never walk the whole grid per event.** Two instances cost 16.4 ms and 3.17 ms per call, both from
   `_process`. After fixing one, *enumerate every other one* — the second was found only by asking.
2. **A cache behind a dirty flag that a dig invalidates is not a cache while mining.** State the cost on
   the invalidating frame, not the amortised one.
3. **Make the reject cheap.** Two dictionary reads before a window walk was the entire 6× win.
4. **View-culling after a world-sized scan buys nothing** — the scan's cost is a property of the world,
   not the screen.
5. **A dirty-region fast lane is capped by its whole-buffer upload.** Measure `set_data`/`update`
   separately; the per-cell ratio *rises* as the region shrinks.
6. **Extent is not cost.** Gate on per-cell µs, not on cell count.
7. **Derive cull margins from the primitives they cull** (`world_renderer.gd:3094`: a hand-set 6.0 against
   a 7.6-cell torch clipped every torch near the view edge).
8. **Array literals in a hot loop are ~30% of a per-cell GDScript pass** (`_air_weight`, 1.3 ms of a
   4.5 ms dig region — "The loop read beautifully and cost more than everything it was measuring").
9. **`[] != null` and `{} != null` are TRUE in GDScript.** It silently opened an unbounded per-frame
   append in legacy's HUD. Also `docs/CLAIMS.md`'s "guards that cannot be false".
10. **Prove the fixture did the work it is named for, inside the timed loop.** A phase that mined nothing
    reported 9.36 ms against an honest 33.37 — "the broken fixture looked like a 3.5x performance win".
11. **Benchmark on the real hot data.** Timing a sky corner put `_paint_fine` at 5% of the bake, wrong by
    20×, because the function early-returns on air.
12. **When flattening a hot function, keep the readable version as the spec in the test file** and assert
    equality over hostile inputs.

## Instruments legacy built that we have not ported

`tools/profile_frame.gd` (per-phase attribution), `tools/check_frametime.gd` (the 120 fps gate, with the
missed-deadline-rate + severity contract and a per-host ratchet registry in `tools/perf_hosts.txt`),
`tools/measure_bake_noise.gd`, `tools/check_dig_hitch.gd` (region-vs-full per-cell µs **ratio**, which
held at 1.175 on x86/lavapipe against 1.19–1.28 on M4/Metal — two architectures, one number).
