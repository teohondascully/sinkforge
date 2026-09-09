# The five-pass performance programme: implementation report and audit corrections

## Audit correction — D0538, September 8

The programme is not complete. Pass 2 remains an approximate, disabled shader; pass 3 needs burst
evidence, not an average-utilisation argument; pass 4 is opt-in pending motion evaluation.
The original report below is retained as historical evidence, with these corrections taking precedence:

- The fixture's `max` was a **median of window maxima**, not the worst observed frame. The quoted
  54.5 → 21.5 ms is therefore not a verified reduction of the actual maximum. D0538 preserves both
  statistics under explicit names and uses the real frame population for over-budget counts.
- Withheld frame comparisons still printed, and a missing repetition could pass. D0538 adds
  regressions, suppresses invalid presentation metrics, and rejects failed/incomplete processes.
- The 46/31 cells per tick measured **repainted rectangle area**, including air and dig repaints,
  not solid cells admitted by the streaming lane. Comparing it with a 512-solid-cell lane budget is
  not a utilisation measurement. Wide-zoom fall now measures a 6.865 ms preparation burst despite
  a 0.306 ms/tick average. Frame statistics were withheld for loss of focus; no FPS claim follows.
- Fresh matched captures at 131 m, tick 31 (requested 30), fixed-fps 60, yield mean display-space
  luminance 0.083141 CPU / 0.083696 shader in world rect (350,120)-(980,450): ratio 1.00667.
  This does not reproduce a blanket 2.4–3x brightness mismatch. The older table divides red channels,
  not luminance, and does not isolate a shading term. Noise/appearance differences remain visible.

Artifacts: `/tmp/sinkforge-audit-fixed-dig.json`, `/tmp/sinkforge-audit-wide-fall.json`,
`/tmp/sinkforge-audit-cave-{cpu,shader}.png`, `/tmp/sinkforge-picture-diff.gd`.
These are bounded checks, not broad renderer certification. Current-frame GPU cost remains unmeasured.

**Addressed to:** Astra, for audit. **From:** the working session on `main`.
**Programme:** `docs/PERF_PLAN.md`'s numbered queue plus its "remaining work, in dependency order".
**Baseline for "since Astra":** `b836bac3`, your last commit. Everything below is D0535-D0537 in
`docs/DECISIONS_LEDGER.md`, one entry per judgment call.

Every number here was read off a tool's output in this session. Where I say **measured**, the command is
given so you can re-measure. Where I say **reasoned**, no measurement supports it. Where I could not do
something, the reason is stated rather than the item quietly dropped. **Section 9 is the list of claims I
would attack first if I were you** -- start there.

**One framing before the detail:** the director's 360 fps (2.78 ms a frame) is **already met on this host
on the average and the median**, and was met before I changed anything. The programme's value was not in
raising the average. It was in (a) discovering that the frame rate had been measured in a regime that
made it read 114 fps when it was 381, and (b) finding a 36.5-38.1 ms spike in one HUD chip that fired
every few dozen ticks while mining. The tail was the problem, and the tail is what moved.

---

## 0. What changed, and where

| commit | entry | what |
|---|---|---|
| `e97e8270` | D0535 | the fixture: four named workloads, a host-speed control in every window, the bake's preparation and upload split from the draw, six refusal rules, and a scripted seat made deaf to the machine's real keyboard |
| `b7773ea4` | D0536 | the minimap repaints changed cells instead of the whole world on every terrain version |
| (this commit) | D0537 | presentation interpolation behind `--interpolate`, OFF by default |

New files: `tools/perf_fixture.py`, `tools/test_perf_fixture.py`, `view/visuals/bake_cost.gd`,
`tests/test_perf_fixture.gd`. Changed: `shell/frame_meter.gd`, `shell/seat_drive.gd`,
`shell/seat_flags.gd`, `shell/main.gd`, `view/visuals/bake_chunk.gd`, `view/visuals/gram_map.gd`,
`view/hud/minimap.gd`, `view/camera_rig.gd`, `view/view_stack.gd`, and four suites.

**I edited `tools/` and it is yours.** `tools/perf_fixture.py` and `tools/test_perf_fixture.py` are NEW
files and I touched none of your existing ones. If you would rather they lived elsewhere, say so.

**Battery at the head of this work: 173 checks, 145 suites, 0 failures, 507 s** (`jobs=1`).

---

## 1. Your pass 1, verified rather than trusted

Your handoff said the complete battery had not been run on `b836bac3`. I ran it: **172 checks, 144
suites, 0 failures, 502 s**. I also re-measured your exact-picture claim independently: the seat's
`frame_0000.png` is still md5 `6287d89b47052a06b4ce421c0937f057` on your head. Pass 1 stands as written.
I did not re-derive your per-region shading numbers; your evidence (16,392 exact-colour comparisons and a
killed mutant) is stronger than a re-measurement would be, and `docs/PERF_PLAN.md` tells the next session
not to repeat the expensive CPU baseline work.

---

## 2. Pass 0 -- the fixture, because three sets of numbers had already been voided (D0535)

`docs/PERF_PLAN.md`'s remaining-work item 1. I built this before touching any of the four optimisation
passes, and it immediately justified itself: **it refused four of its own first runs, and each refusal
was a real defect in the fixture rather than a fault in the game.**

```sh
python3 tools/perf_fixture.py --all --reps 3 --ticks 1500 --out /tmp/base.json
python3 tools/perf_fixture.py --workload dig --reps 2 --ticks 1500 --front --out /tmp/after.json
python3 tools/perf_fixture.py --compare /tmp/base.json /tmp/after.json
python3 tools/test_perf_fixture.py          # the refusal rules, each with a passing control
bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/test_perf_fixture.gd   # 45 assertions
```

**The workloads.** `still`, `walk`, `dig`, `fall`, as `--perf-drive=NAME`; an unknown name is refused
rather than silently walked. `dig` holds MINE with the pointer sweeping across the body's own width;
`fall` digs for 380 ticks of each 480-tick cycle then returns the body to the shaft's top and lets it
fall down what it cut.

**The phase split.** `view/visuals/bake_cost.gd` counts terrain preparation and upload apart, per cell as
well as per window -- neither was visible to any existing clock, because a chunk paints inside a
`CanvasItem._draw` the frame meter's `draw=` does not attribute. `shell/frame_meter.gd` now reports the
draw phase over every frame rather than the worst eight.

**The six refusal rules**, each mutation-tested against a control that must still pass:

1. fewer than two warm windows -> VOID;
2. a `dig`/`fall` window that baked no chunks -> VOID (`still` and `walk` are exempt, and the scope is
   itself the mutation);
3. a `walk` that ended in one place, or a `still` that moved -> VOID;
4. the host-speed control drifting past 1.20x -> SUSPECT with the drift stated, past 1.50x -> VOID;
5. any warm window paced at ~120 Hz -> the FRAME statistics are withheld, the phase clocks are not;
6. a window with no PERF line is dropped rather than carried with holes.

**Live mutation of the instrument itself:** with `BakeCost.note`'s PREP stamp removed from
`BakeChunk.paint`, two `dig` runs reported `VOID: 4 of 4 warm windows baked NO chunks` instead of a
smaller, cheaper-looking number. `view/visuals/bake_chunk.gd` restored to md5
`85fc9ffa40ed24c966fae68e1c20b634`.

### 2.1 The finding that changes how every earlier frame number should be read

**A scripted seat was reading the machine's real keyboard and mouse.** `PlayInput.verbs` read
`Controls.pressed` and `Input.is_physical_key_pressed` on every seat, driven or not, and `_hud_keys` did
the same whenever `--act=` was empty. A headed seat takes focus on this machine -- sampled once a second
against `System Events`, `godot` was frontmost at t+1 s and t+5 s of a run while the director worked in
another application. So a keystroke typed by the machine's owner reached the seat, `Command.select`
changed the held item, and the held item changes what MINE snaps to (D0490). Three `dig` runs stopped at
the surface with `bake prep=0.000ms/tick chunks=0` for four consecutive windows; two more runs of the
identical script descended normally.

The mechanism is certain from the source. That it caused those three specific runs is **inference from
the reproduction pattern, not proof** -- I could not observe the keystroke. Attack this if you like; the
fix is right either way, and **every `--act=` capture this project has ever taken shared the exposure.**

### 2.2 The regime problem, which the first control could not see

Three `--front` runs of the `dig` workload, with the CPU control steady at 61, 60 and 61 us and painter
CPU at 2.372, 2.418 and 2.401 ms/tick, reported `fps_wall` **381.4, 533.1 and 409.8**. The middle one
differs from the third by an edit worth 0.7% of painter CPU.

So the frame rate and the frame percentiles move about 30% run to run here for reasons the CPU control
does not capture. `tools/perf_fixture.py` now carries a **measured noise floor per metric** and prints
"not evidence" on any line that does not clear it. A second control was added -- the share of frames
drawn into a focused window -- after three runs of one workload reported the draw phase at **4.40, 1.31
and 0.55 ms**: frontmost, occluded behind a terminal, and being handed the front back by the fixture's
own focus custodian. macOS stops presenting what nobody can see.

**Consequence for your pass-1 and D0526 numbers:** none of your per-region or per-sample numbers are
affected -- they are CPU timers on a fixed workload. But the headed A/B in `docs/PERF_PLAN.md`
("388.6 -> 454.3 fps", "93.6/117.2 fps" for the first baseline) is exactly the kind of measurement this
finding voids, and the plan already says not to use it for a whole-game claim. I would now go further:
**that comparison cannot support a frame-rate claim in either direction**, because the window regime was
not recorded.

### 2.3 Two things measured and deliberately not adopted

* **Hiding the seat's window** drops the draw phase from 4.40 ms to 0.50 with *identical* bake work
  (chunk counts 190/130/120/124/124 both ways). The director's explicit call, asked and answered: that is
  presentation leaving the measurement, not work getting cheaper. `--hidden` survives only as a
  deliberate isolation and withholds every frame number when used.
* **`--display-driver headless`** is not an alternative to a window: it forces the dummy rendering
  driver, and the terrain bake's SubViewport then renders nothing at all (`bake prep=0.000ms/tick`). Every
  frame measurement in this programme therefore needs a real window on someone's screen.

---

## 3. The baseline, at `b836bac3`, and how to read it

**Host: Apple M4 Pro, 24 GiB, Godot 4.6.2, 1280x720, `--disable-vsync --max-fps 0`, play zoom 2, 1500
ticks a run, five 300-tick windows, window 1 discarded as cold.** Medians over the warm windows.

Two regimes, and the difference between them is the point:

| workload | regime | phases | frames | fps_wall | p50 | p99 | worst | draw p50 | painters | bake prep | us/cell |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| still | custodian | SUSPECT 1.39x | paced 10/12 | -- | -- | -- | -- | 5.64 | 2.792 | 0.000 | -- |
| walk | custodian | SUSPECT 1.31x | paced 12/12 | -- | -- | -- | -- | 5.41 | 2.489 | 0.000 | -- |
| dig | custodian | VALID | VALID | 114.6 | 6.10 | 40.18 | 62.71 | 4.40 | 2.430 | 0.554 | 12.30 |
| fall | custodian | SUSPECT 1.23x | paced 1/12 | -- | -- | -- | -- | 1.33 | 2.519 | 0.391 | 12.47 |
| **dig** | **`--front`** | **VALID** | **VALID** | **381.4** | **1.84** | **13.41** | **54.51** | **1.68** | **2.372** | **0.551** | **11.81** |
| **fall** | **`--front`** | **VALID** | **VALID** | **397.5** | **1.85** | **10.53** | **53.21** | **1.71** | **2.349** | **0.364** | **12.17** |

Quiet physics tick 0.61-0.68 ms everywhere. Upload 0.001-0.002 ms/tick, 19-30 uploads a window.

**The same `dig` workload reads 114.6 fps under the focus custodian and 381.4 with the window frontmost.**
Neither is wrong; they are different regimes, and only the second is a frame rate a player would see.

**What is stable and what is not.** Stable across every run I took: painter CPU per tick (2.35-2.42),
bake preparation per cell (11.6-12.5 us), the quiet physics tick (0.61-0.68 ms), the chunk and cell counts
(bit-identical run to run: 190/130/120/124/124), and the worst frame when a structural cause changes.
Not stable: `fps_wall`, frame p50/p99, and the draw phase.

**The instrument gap you already named:** Metal reports `rgpu=0.0`. Every GPU cost in this programme is
unmeasured. The upload numbers above are the CPU handed to the driver and nothing else.

---

## 4. Pass 2 -- the shader prototype: diagnosed further, NOT fixed, and why

**Status: not finished. Reason logged.**

I did the diagnosis and stopped there. The finding is that **the reported "seam" is not a seam.**

Reading pixels out of the two 4x zooms (`scratchpad/w14/zoom_cpu_4x.png`, `zoom_shader_4x.png`) along
three rows: in the dark region left of the cut the two paths are **byte-identical** ((18,15,15),
(15,14,15)), so the lighting is the same. From the first rock column rightwards:

| distance into the rock | CPU | shader | ratio |
|---|---|---|---:|
| cut edge | (84,73,45) | (205,165,76) | 2.44x |
| +1 cell | (88,75,67) | (210,166,132) | 2.39x |
| +2 cells | (77,77,67) | (204,171,133) | 2.65x |
| +3 cells | (64,54,57) | (192,151,128) | 3.00x |
| +4 cells | (63,52,45) | (189,150,117) | 3.00x |

**The whole rock surface is 2.4-3.0x too bright, and the ratio GROWS with distance into the rock.** The
CPU darkens deep rock strongly; the shader barely does. The red line at the cut's edge is simply the
brightest cell of a uniformly over-bright surface, and chasing it as a seam would have been chasing the
wrong thing. My reading, **reasoned and not measured**: the suspect is the carved-edge/ambient term --
the one that brightens rock near air and darkens it deep inside -- not the noise fields the shader header
already declares inexact. A brightness ratio that grows monotonically with depth into rock is not what a
different noise sample looks like.

I checked and eliminated one obvious candidate: `TerrainPainter.paint`, the painter the flag swaps out,
does nothing but the tufts and `cell_fill`, so the swap loses no other pass.

**Why I stopped.** The prototype is OFF, enabling it is a director art call (T040), and the remaining
work is inside a picture the director owns. Reproduce with:

```sh
godot --resolution 1280x720 --path . -- --fresh --muted --zoom=2 --warp=130,600 \
  --screenshot-tick=20 --screenshot-out=/tmp/shader.png --shader-tone
```

---

## 5. Pass 3 -- movement-ahead prefetch: inspected, NOT built, with the numbers

**Status: not built, deliberately.** Your item 2 says to inspect prefetch coverage and upload cost before
adding scheduling rules, and never to accept holes. I inspected. There is nothing to fix.

* **The streaming lane is not saturated.** `BakeLane.WINDOW_LANE_SOLID_CELLS` is **512 solid cells a
  tick**. The two workloads that stress streaming hardest demand **45.8 cells a tick** (`dig`, 13,751
  cells over 300 ticks) and **31.4** (`fall`, 9,425). That is **6-9% of the lane's own budget.** Prefetch
  moves work earlier in time; it cannot help a lane that is idle 91% of the time.
* **No visible hole.** After a cold `--warp=130,600` (131 m down, terrain the bake has never seen), the
  first frame the shutter can capture is tick 16 -- which *is* the first presented frame, since the
  shutter waits for one -- and the window is completely painted. Captures at ticks 16, 24 and during a
  `fall` all show intact terrain. `scratchpad/pass3/`.
* **Upload is not a cap.** 0.001-0.002 ms/tick of CPU across 19-30 uploads a window. Metal's GPU time is
  unavailable, so **the GPU side of this claim is unmeasured** -- that is the honest limit of it.

**Reasoned, not measured:** a fall exposes new terrain at roughly 36 terrain cells a second against a
lane that admits 30,720, so I do not expect this to change at any camera speed this game can produce.
The place I would expect it to change is a much wider zoom rung, which I did not test.

---

## 6. Pass 5 -- the HUD and the tail: the one big win (D0536)

**Status: done.** Taken before pass 4 because the measurement pointed here.

Of the twenty slow frames the meter kept in a 1500-tick `--front` dig, **nineteen carried
`minimap.paint=36.5-38.1 ms`** inside a 49.7-56.4 ms frame. Thirteen times the entire 2.78 ms budget, in
one HUD chip. `Minimap.ensure_texture` rebuilt the whole chart -- every logic cell of the world, 64 x 256
here, about 17,000 -- calling `class_color` and `set_pixel` per cell, whenever `map_version` moved. A dig
is exactly what moves `map_version`, so the chip was at its most expensive precisely while the player was
doing the thing the director described as the world freezing.

It now keeps the class and memory bytes its image was painted from and repaints only the cells that
differ.

| | before | after | second run after | claimable |
|---|---:|---:|---:|---|
| **worst frame** | **54.51 ms** | **21.46 ms** | **20.89 ms** | **YES, -61%** |
| `fps_wall` | 381.4 | 533.1 | 409.8 | no |
| frame p50 | 1.84 ms | 1.38 ms | 1.79 ms | no |
| frame p99 | 13.41 ms | 12.26 ms | 13.22 ms | no |
| over 16.7 ms | 9 of 600 | 6.5 of 600 | 7.5 of 600 | no |
| painters | 2.372 ms/tick | 2.418 ms/tick | 2.401 ms/tick | no change |
| bake prep | 11.81 us/cell | 11.59 us/cell | 11.82 us/cell | no change |

**Only the worst frame is claimed.** A first draft of D0536 claimed the `fps_wall` and p50 improvements;
the third column withdrew them before the commit was pushed. `minimap.paint=36.5-38.1ms` no longer
appears on any slow frame, which is the qualitative half of the same evidence.

**The pin caught a bug that would have shipped.** Holding `o.map` rather than a duplicate aliases the
world's own coarse plane, so the diff compares the array with itself and repaints zero cells for ever --
a minimap that silently stops updating the moment you mine. The suite now pins the patched image
byte-for-byte against a full rebuild, twice.

**A second change measured and reverted.** Throttling the repaint to 10 Hz was implemented, pinned with
two assertions, measured at 2.418 -> 2.401 ms/tick (inside the 5% floor) and backed out. The
`minimap.paint=1.61ms` visible on slow frames after the fix is not a diff running every tick: `map_version`
moves only when a *logic* cell's class changes, which needs a write at the cell's centre. It was the
ordinary cost of the chip in a frame where the host was slow and every painter was slow with it.

**What remains in pass 5, measured and not acted on.** On a slow `--front` dig frame the world painters
total 4.39 ms and the HUD 3.94, led by `machine_painter.paint_frame` 1.44, `veil_layer.paint_frame` 1.22,
`sky_painter.paint` 0.91, `minimap.paint` 1.61 and `target_guide.paint` 1.20, with `refresh` at 1.08 ms
(`observe` 0.98). `queued=5988/6240` -- 96% of layers redraw every tick during a dig, so D0531's redraw
gate buys almost nothing while the terrain is changing. One outlier I saw once and did not chase:
`objective_line.paint=7.56ms` at tick 108 of one run. **I have no explanation for it and it is the first
thing I would instrument next.**

---

## 7. Pass 4 -- presentation interpolation, shipped OFF (D0537)

**Status: implemented, measured, default OFF, awaiting the director's eye.**

The sim is 60 Hz and the seat renders 400-530 frames a second, so seven or eight frames in nine repeat a
picture already on screen; the camera moves in one 4.8-screen-pixel step a tick at the body's 9 m/s. The
director's display paces at 120 Hz and is being handed one distinct position per two refreshes.

**The design decision is the order of two operations.** `CameraRig.snap_to_pixel` exists because this is
pixel art. Lerping two already-snapped positions puts the camera back on fractional pixels and undoes
that rule -- the mutant that does it reports 621.775, 622.05, 622.325 and the suite goes red on nine of
eleven sampled fractions. Lerping the two **un-snapped** positions and snapping the result keeps every
frame on the grid and turns one 4.8-pixel jump into up to five one-pixel steps.

**Only the camera and the miner's layer move**, because both are `Node2D` transforms and a frame costs two
vector writes and no repaint. The veil is why nothing else does: `veil_layer.paint_frame` rebuilds a lamp
texture per draw at 1.05-1.22 ms, so running it every frame at 500 fps would cost half a core. Its lamp
therefore lags one tick -- 0.15 m against a lightmap whose own resolution is 1 m.

**A placement is taken whole**: past `TELEPORT_PX` (48 world px) the step is not interpolated. Mutation
tested both ways -- removing the guard smears a teleport by 96 px and the suite fails; a body that walked
a quarter of that bound is still interpolated, so the guard is not vacuous.

**Cost: nothing the fixture can see.** `--front`, `dig`, 2 reps of 1500 ticks, control 58.5 -> 61 us:
`fps_wall` 455.5 -> 427.3, p50 1.585 -> 1.725, p99 13.02 -> 13.28, worst 20.39 -> 20.80, painters 2.401 ->
2.406 ms/tick, prep 11.95 -> 12.06 us/cell. **Every one is inside its own noise floor** and none is
claimed in either direction.

**Why OFF.** With the flag on and off the seat's frame at `--warp=130,90 --screenshot-tick=120` is
byte-identical (md5 `1fc4657fee294bf63417c00c1c80b8d7`) -- the pin working exactly as intended, and also
the reason the verdict is not mine: a still capture cannot judge motion. `godot --path . -- --interpolate`.

---

## 8. The 360 fps north star, stated honestly

* **It is already met on the average and the median**, and was before this programme: `--front` `dig`
  reads `fps_wall` 381-533 and frame p50 1.38-1.84 ms against a 2.78 ms budget. It was met at
  `b836bac3` too.
* **It is not met on the tail.** Worst frames of 21 ms and a p99 of 12-13 ms remain, which is 5-9 frames
  in 600 over 16.7 ms. That is what a hand feels, and it is what moved (54.5 -> 21 ms).
* **`fps_wall` is the wrong metric to steer by on this host.** It moves 30% run to run with every CPU
  quantity held. Steer by painter CPU per tick, bake preparation per cell, the physics tick, and the
  worst frame.
* **Most of those frames are discarded.** At 500 fps into a 120 Hz display with a 60 Hz sim, roughly four
  in five rendered frames are never shown and seven in nine show a picture already on screen. Raising the
  average buys nothing further; D0537 is the change that would make extra frames mean something.
* **This is one host.** Nothing here supports a claim about any other machine, and the GPU side is
  unmeasured everywhere because Metal reports zero.

---

## 9. What I would attack first, if I were you

1. **The `dig` fps claim in section 3.** 381.4 is a median of eight windows over two runs, and I have
   shown the metric moves 30%. I believe the *regime* conclusion (114 vs 381) because it has a mechanism
   and a second control; I would not defend 381 as a number to three digits.
2. **"The keystrokes caused those three stuck runs" (2.1).** The mechanism is certain; the causal link is
   inference from a reproduction pattern. If you can think of another cause for three stuck runs among
   five of an identical script, I want to hear it.
3. **The noise floors themselves** (`NOISE_FLOOR` in `tools/perf_fixture.py`). They come from three
   like-for-like runs. Three is not many, and I set `warm_max` at 15% from judgment rather than from a
   distribution -- which matters, because the worst-frame claim in section 6 is the one thing this
   programme actually claims.
4. **The shader diagnosis (4).** The pixel table is measured; "the carved-edge term is the suspect" is
   reasoning from the shape of the ratio, and I did not confirm it by disabling that term.
5. **The prefetch null result (5).** The lane utilisation is measured; the conclusion that no camera speed
   this game can produce would saturate it is reasoned, and I did not test the widest zoom rung, which is
   where `docs/PERF_PLAN.md`'s historical section says to budget.
6. **`still` and `walk` never produced a clean verdict.** Both were paced at 120 Hz in every warm window
   under the custodian, and I never re-ran them `--front`. The pass-5 painter figures in section 6 come
   from slow `dig` frames, which are by selection the expensive ones.
7. **`objective_line.paint=7.56ms`.** Seen once, unexplained, not chased.

## 10. Re-running everything

```sh
bash tools/run_local_battery.sh /opt/homebrew/bin/godot          # 173 checks, 145 suites
python3 tools/test_perf_fixture.py                               # the refusal rules and their controls
bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/test_perf_fixture.gd
bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/test_minimap.gd
bash tools/run_gd_test.sh /opt/homebrew/bin/godot res://tests/test_camera_rig.gd
python3 tools/perf_fixture.py --workload dig --reps 2 --ticks 1500 --front --out /tmp/dig.json
python3 tools/perf_fixture.py --workload dig --reps 2 --ticks 1500 --front --seat=--interpolate --out /tmp/lerp.json
python3 tools/perf_fixture.py --compare /tmp/dig.json /tmp/lerp.json
```

A `--front` run takes the screen for the length of the run. Without it the runner hands focus back to
whatever application had it, by unix id, and the frame numbers are withheld.
