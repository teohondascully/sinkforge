# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-04, thirteenth round: the three passes (the twelfth round's brief is in
`git log -p -- docs/BRIEF.md`; A′ steps 6 and 8, D0362–D0388). THIS ROUND: the game that felt like
20 fps runs at 120 with one dropped frame a second (D0390); the light is a colour again and the miner,
the factory and the map read as one world (D0391–D0393); the A+ list is closed to the extent it could be
without a ruling (D0394).** The director's eye has still not judged the executed look; the pairs are on
disk and the forks are T012–T017.

**Headline: the instrument was the defect.** `Engine.get_frames_per_second()` averages, so a 30 ms
stall every hub tick and a 100 ms stall every camera move read as "100 fps" (D0389) while the director
felt 20. A wall-clock meter over `_process` spacing found both in a minute. Every one of the six causes
was a full-plane walk done per frame or per tick that a version key or a flat plane made free; none of
them was rendering. The sim's determinism did not move: the shaft-replay golden matched at all 200
checkpoints after every commit.

---

## What landed

- **Pass 1, performance (D0390).** `shell/frame_meter.gd` (p50/p99/max, frames over 8.3 and 16.7 ms,
  hub-tick physics split) and `--perf-drive` (a scripted walk; the standstill number is not the game).
  The water phase skips when nothing changed since a no-change step; `HubCache` keys each hub plane on
  its own version, bucket-indexed; `TileGrid` extends `SignedPlane` and keeps flat index planes so a
  window is row slices; the veil composes on the GPU (`veil.gdshader`, `VeilLayer`), the CPU painter
  the pinned reference; the glint and seam caches key on the terrain version. Moving-camera frame p99
  93 → 21 ms; painters 6 → 2 ms a frame.
- **Pass 2, the look (D0391–D0393; `docs/VISUAL_QUEUE.md` v2, 55 entries from 22 captures of the real
  seat).** Legacy's light composition lifted whole: an ambient dark that is a colour, skylight
  scattered under each column's own surface, a void floor, an amber lamp; the camera clamped to the
  world; the miner and the factory drawn UNDER the veil so the scene lights them; the halo a shadow rim;
  the map no longer a weather chart of ore, modal when large; the plate primes for a second; banner and
  horizon seam. Before/after: `tests/body/recordings/look_pass_2026-09-04/`.
- **Pass 3, A+ (D0394).** Gate 36 (the second gate 30), `gate_status.py` runs again and says what it
  is doing; the battery's exit code, the flaky detector's regex, gate 27 (earlier this round); one
  `_check(true)` made a real assertion with a control; fifty dead legacy files removed after the
  reference check. CI 122 → 124 suites (`test_water_rest`, `test_flat_planes`).

---

## What was learned

1. **An averaged frame counter cannot register a stall.** The Engine's fps was 100 with 44 frames over
   16.7 ms every five seconds. Measure frame SPACING and report the tail (p99, max, count over budget),
   never the mean; and measure MOVING, since every stall here was keyed to the window re-centring.
2. **"Nothing changed" is a version key, not a flag.** The outer `_hub_dirty` flag missed every write
   that did not go through the door; a per-plane version compared at the consumer catches all of them
   and costs nothing. The water rest marker is the same idea on a pure step: `(version, terrain_version,
   grid id)` unchanged since a no-change step means the step is a no-op.
3. **A per-cell Dictionary is a full-plane walk every time it is windowed.** 17K lode entries filtered
   per snap was 2-3 ms; a bucket index or a flat byte plane with row slices is what makes a window free.
   The observation was designed as copies; copies of a WORLD-sized plane per frame were the bill.
4. **The veil's cost was the CPU composing per texel what a shader does in one pass.** The port kept
   legacy's CPU painter and drew the same picture; keeping it as the pinned reference and moving the
   composition to the GPU cost 200 lines and returned most of the 4 ms the painters gave back. The pin (`test_flat_planes`) reads
   the same constants on both sides.
5. **Legacy's light was the missing thing, not more contrast.** V01–V04 (rock reads as void, the deep
   is flat, the light is grey) were one root cause: the veil was a grey multiply with no ambient colour,
   no skylight scatter and no void floor. Legacy had all three in `world_renderer.gd`, and lifting them
   moved eight catalogue entries at once (V01, V03, V04, V17 executed; V13, V16, V31, V40 re-judged). Fix
   the light before judging the texture.
6. **The miner "pasted on" was a z-order.** Legacy drew him above the light so he stayed crisp; under
   this build's darker veil that read as a sticker. Under the veil he belongs, and his own lamp lifts
   him. The same call for the factory (D0393 reverses D0364). Coherence is where in the stack, not how it
   is drawn.
7. **A perceived band is a pixel sample away from a real one.** The sky's horizon "band" was blamed on
   the veil; sampling the pixels with and without the veil gave identical values (the sky painter's
   gradient). No change was made there. Sample before attributing.
8. **The seat needs flags to be captured.** `--fresh --warp --zoom --screenshot-tick --screenshot-out
   --act` reproduce any frame of the real game headless; the first captures loaded the director's save
   and warped into a one-cell slot. Standable means solid under both feet and air four columns wide.
9. **The contiguity check was the instrument's own trip-wire.** Two gates numbered 30 made `gate_status`
   FATAL since D0266, and it was called "hanging" because it also ran two silent
   minutes. A progress line per step is the cheapest cure for a tool being believed dead.
10. **Dead ranges inside a read-only reference are free; dead FILES are not.** Live code cites
    `legacy/<file>:<line>` hundreds of times, so excising in-file ranges lies to every citation. Fifty
    whole files, cited by nothing outside `legacy/`, were the safe half of the plan's §3.4.

---

## The decisions this round is waiting on

**The eye, on the real seat.** `godot --path .` and the pairs under `tests/body/recordings/look_pass_
2026-09-04/`. T012 the lamp's lean (0.45 amber against legacy's 0.28), T013 the miner under the veil with a
shadow rim, T014 the factory under the veil, T015 the map without ore, T017 the rock's texture knobs.
**T016, the three generation forks:** the 24 m ruler-flat pad, no water above 140 m, Stonereach at 8% air.
Each is a data diff plus the CI re-pin. **Step 7's scope** (plan §8) and the `history/` cull are unchanged
from the twelfth brief.

**CI:** every commit of this round is unpushed at the time of writing (e60d43b4 → f3f39a59 on top of
origin/main 2b50c5ab); the push and its run follow this brief. `gate_status.py` on f3f39a59: 36 gates,
26 with enforcing code, FAIL [], ADVISORY [14, 33]; local battery 28 PASS.

---

## Anything that felt wrong even though it passed

**One dropped frame a second, walking.** The lode plane's window build, the metre field and the glint
scan all rebuild on the snap (3-4 ms together). Under 8.3 ms each, over it together, once a second.
**The sky painter is 1 ms every frame** for a gradient and a moon.
**The taste calls are mine.** The lamp's lean, the deep's blue-grey, the miner's rim, the map's palette:
each one constant, each reversible, none seen by the director.
**V02, the texture, was not touched.** Under the new light it reads as lit stone rather than static; the
knobs are named in T017 and the art pass is the director's.

---

## Blocked, and what it's waiting on

Nothing blocks; the next step is the director's eye.

## Taste queue

**17 open.** T001–T011 unchanged; T012–T017 new this round (`docs/TASTE_QUEUE.md`).
