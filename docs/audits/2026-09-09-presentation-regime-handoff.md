# The presentation regime is inside the measurement — handoff for Astra

From Claude, after D0555. **Your files, my finding.** `tools/perf_fixture.py` and everything under
`tools/` are yours; I did not edit them. What follows is the evidence and the commands, so the call on
the fixture is yours to make.

## What was measured

The draw phase (`frame_pre_draw` → `frame_post_draw`) is not work. It is the process blocked on a
drawable that does not exist yet. One workload (`still`, zero terrain preparation), frontmost,
`focus=1.00` in all 24 windows, control 71–96 µs, quiet tick 0.47–0.52 ms, one variable:

| `--max-fps` | achieved fps | draw p50 | draw p99 |
|---|---|---|---|
| 60 | 60.0 | 0.62–0.66 | 0.80–0.88 |
| 90 | 90.0 | 0.57–0.58 | 0.74–5.02 |
| 120 | 120.0 | 0.47–0.48 | 1.31–2.48 |
| 150 | 150.0 | 0.37–0.38 | **8.24–8.51** |
| 200 | 195.0 | 0.33–0.34 | 8.46–9.61 |
| 300 | 262–266 | 0.37–0.71 | 11.10–12.90 |
| 0 | 395–412 | 1.38–1.45 | 12.70–13.35 |

The step is at the display's own rate and its height is one 120 Hz slot. Your Metal trace agrees from
the other side: 5.1% GPU busy. So does `rcpu`, which reads 0.1 ms in 545 of the 653 slow frames this
programme has logged.

## The part that concerns your file, and why I did not touch it

`flags_for` hardcodes `--disable-vsync --max-fps 0`, and `frame_note` **WITHHOLDS any warm window whose
`fps_wall` lands in `PACED_BAND`**. `project.godot` sets no vsync or `max_fps` key, so a player runs
vsync on at 120 Hz — which means **the fixture currently refuses, by construction, the only regime a
player is ever in.** Measured both ways, same tree, same seat, frontmost, `focus=1.00`:

| arm | fps_wall | frame p99 | over 16.7 ms |
|---|---|---|---|
| still, vsync | 118.8–120.0 | 13.81–15.97 | 1–5 / 597 |
| still, `--disable-vsync` | 399–416 | 14.27–16.39 | 14–20 / 2068 |
| dig, vsync | 119.2–119.8 | **23.37–25.45** | **28, 28, 28, 30 / 597** |
| dig, `--disable-vsync` | 320–358 | 17.09–21.25 | 22–35 / 1598 |

Your docstring's reasoning is right about the *rate*: under pacing, `fps_wall` and the percentiles
describe the display. It does not hold for the **count**. Dig drops 28–30 frames a window either way;
only the denominator moved, and it moved in the direction that made the defect look 2.5–4× smaller.
That is what let D0551 size the bake at ~11% of the p99 when it is worth ~9.5 ms of 25 (withdrawn in
`docs/CORRECTIONS.md`).

So there is a real question your file owns and I have not answered: **can a vsynced window report the
over-budget COUNT and the phase clocks while still withholding `fps_wall` and the percentiles?** That is
a narrowing of `frame_note`, not a removal, and it is yours.

## What I did change (mine, landed in `b0d6b7a2`)

`shell/frame_meter.gd` only. The window line now ends with `present vsync=on max_fps=0 screen=120.0Hz`,
**appended after the control**, so `PERF_RE` — which is not anchored at the end — keeps matching
unchanged. I verified that against your regex before writing it. Also fixed: `focus` was computed over a
denominator one short of its numerator (the first `_process` closes no frame but sampled focus anyway),
so a 15-frame window read 1.07 and a 600-frame window was inflated 0.17% — enough for a true 0.9483 to
clear your 0.95 guard. **I did not lower the guard**; it now guards a number that cannot exceed 1.

## Reproduce

```sh
# the ladder (mine, ephemeral, not checked in):
#   scratchpad/slack_dose.py  -- caps 90/120/150/200/300/0, still, frontmost
#   scratchpad/shipped.py     -- vsync vs --disable-vsync, still and dig, frontmost
# or directly, one arm:
/opt/homebrew/bin/godot --resolution 1280x720 --path . \
  -- --fresh --muted --zoom=2 --quit-after=900 --perf-drive=dig      # shipped: vsync on
/opt/homebrew/bin/godot --resolution 1280x720 --disable-vsync --max-fps 0 --path . \
  -- --fresh --muted --zoom=2 --quit-after=900 --perf-drive=dig      # the programme's flags
```
Both need the front to mean anything; without it macOS paces the process to 120 Hz regardless and every
window reads `focus=0.00`. My first ladder ran that way and its numbers are not in the tables above.

## Still open, and still yours

Shader parity (T040, director's call), the option-conflict guard and `FOCUS_MIN` pins you reported as
not fixed, and the question above. Nothing here asks you to reapply anything.
