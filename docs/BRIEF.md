# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-05, fourteenth round: the two phases (the thirteenth round's brief is in `git log
-p -- docs/BRIEF.md`; D0390–D0395). THIS ROUND: Phase 1 -- the director's stuck state was the seat's
inverted climb axis, fixed, with a GAME face for the way out and the way over (D0396); boot 7.6 → 1.8 s
with a save (D0397). Phase 2 -- the six rulings applied (D0398–D0402, the golden re-pinned from CI Linux),
the character smaller with a three-beat stroke (D0399), four feel rows (D0403), and the round's own perf
regression found and fixed by the meter (D0404).** Captures before and after every change are on disk
under `tests/body/recordings/phase2_2026-09-05/`.

**Headline: the two things the director could not do were the seat's, not the sim's or the world's.** The
slot they left at 22:09 was read and driven through the seat's own hand before anything was changed: the
body stood on a step in an open rift with the line anchored above, and W paid the line OUT because the
hand built the climb axis with the wrong sign against a contract three readers agreed on -- and the test
had pinned the wrong sign, checking the driver against itself. The load was 4.7 s of generation thrown away
on every start because the restore stages a whole world and swaps it in. Neither needed a line in `sim/`.

---

## What landed

- **F1 (D0396).** `PlayInput.read`: `climb_dir` +1 is up. Settings: a GAME face -- RETURN TO SURFACE (the
  nearest floor to the spawn, the line cut) and NEW GAME (armed on the first press, the slot moved to `.bak`
  and the scene reloaded on the second); the rail's tabs answer a click; digits 1-4; ESC closes.
- **F2 (D0397).** `Session.from_save` (no generation under a restore); `TileGrid.load_cells` via `GridLoad`
  (both layers in one pass each, the term folded once a cell, pinned equal to the per-cell writers and to
  the grid's own rebuild); `Sfx`/`Beds` `synthesize`/`attach` with `SceneAudio.setup_async` on a worker
  thread, byte-identical; `ValueNoise.FbmField`, the fBm a column at a time with the lattice memoised across
  columns, `==` on the doubles over 10,922 samples. Headless whole-process: 7.56 → 1.78 s with the slot, 6.42
  → 3.11 s fresh. `Main.boot` prints its phases.
- **T017 + the static (D0398).** The "television static" was `rock_tooth.gdshader`'s 1/32 m cell: one
  screen pixel at zoom 2 adding 0.06 over rock at 0.05. Now 1/8 m at half the weight. Hardrock is `bedded`
  and bedded rock has parting planes (`RockTone.lamina`) on the hue bands' own warped coordinate, bed
  thickness by facies; deepstone's plates; inclusions fewer and softer. The depth ladder on the GDD's
  layers (THE DEEP WORKS at 140 m). T012: `LAMP_TINT` 0.38.
- **The character (D0399).** `DRAW_SCALE` 0.85; the baker lifted into `tools/` with `dig_mid`; the stroke
  wind-up / level / struck on braced legs, phase-locked, the clockless fallback the same table; the idle
  breathes; swing, hang and climb poses from the observation's booleans.
- **T015 (D0400, D0404).** `SeenPlane`: a lamp's-reach disc about the body on every hub tick, saved, outside
  every signature; the map paints ore only where seen, updating in place per step. The chart's bands 55%
  toward grey.
- **T014 (D0401).** The status beacon: a breathing cut in the status colour for any machine that wants
  something.
- **T016 (D0402).** `pad_half_m` 8 / `ramp_m` 8; `cave.deep_at_m` 140 (Stonereach 8% → 11-14% air);
  `aquifer.min_depth_m` 48 (water from 76 m). Golden re-pinned from CI Linux (PR #51, run 33953607297),
  the CI array equal to the local dump elementwise, `test_carve_fraction` re-pinned to the measured density.
- **Feel (D0403).** The lamp breathes within 3.5% (exactly 1 at t = 0); debris and dust on a break, a chip
  per blow; landing dust; the water's skin a world pixel.
- CI 124 → 126 suites (`test_rock_laminae`, `test_seen_plane`); `tests/fixture_shaft_golden.gd` holds the
  array.

---

## What was learned

1. **Drive the player's own state through the player's own hand before touching anything.** The slot
   said where the body was; the hand said what each key did there. Walking worked, W did nothing, S reeled
   in: the defect named itself in one table. The terrain was never the problem.
2. **A test that checks the driver against itself pins the bug.** `climb_dir == -1, "W climbs up"` was
   green for a round. The pin now runs W's frame through `Grapple.reel` and asserts the line SHORTENS: the
   consumer decides the sign.
3. **The load's biggest cost was work the next step discarded.** Generation under a restore; the fix is a
   second constructor, not a faster generator. The faster generator came second and was measured
   bit-exact: a memoised field is only a speed-up if `==` holds on every double.
4. **Identical arithmetic in identical order is bit-exact; a reordered sum is not.** `FbmField` sums
   octaves per row in the per-sample order and doubles `fy` the way the loop did; the first draft used a
   `_scale(i)` helper per row and would have been slow, not wrong -- but the same care is what made the
   sanity check `mismatches 0` instead of a tolerance.
5. **The static was a pass, not a tone.** Every knob on the rock tone moved 61.6% of pixels by under 0.2 in
   total: the laminae were real and invisible. Cropping at 2x showed features smaller than a cell, which no
   cell-level tone can make. Name the layer a feature's SIZE belongs to before tuning the layer you meant.
6. **A grammar with no material is a grammar with no look.** Bedded existed; nothing was bedded. The
   world's "varied geology" was one data field away before any constant moved.
7. **The band ladder's numbers were legacy's world.** THE LONG DARK at 45 m, STONEREACH at 206 m: the
   ladder stopped at 66 m in a 128 m world. Legacy's constants carry legacy's world size (again).
8. **Two frames read as a twitch; three read as a stroke.** The level mid-swing is the frame the eye reads
   as motion. And the clockless fallback should BE the phase-locked table on a clock of the period, so the
   two never drift.
9. **A feel change that costs frames is a regression whatever it looks like.** The seen plane's version
   moved every hub tick and the map rebuilt 17K pixels each time: p99 21 → 46 ms, found only because the
   brief said "fps still 120" and the meter was run. Update in place when a step turns a few dozen cells.
10. **A re-pin's tuple moving is the world changing; the same tuple on CI and local is the check.** PR #51:
    833/345/5 from 858/360/6, identical on both platforms, 200 of 200 equal elementwise. And a ratchet
    beside the golden (`test_carve_fraction`) is a neighbour to run BEFORE the PR, not after.
11. **A vacuous check writes itself when a test is going well.** Twice this round a control compared a call
    to itself or ended in `or true`; both caught on reading back. The hunt is never finished.
12. **A sealed pocket has no surface.** The water's skin line cannot be judged on a generated aquifer; a
    breach makes the surface. State what a capture CAN show before claiming it shows a fix.

---

## The decisions this round is waiting on

**Play it.** `godot --path .`: the slot loads in under two seconds, W reels the line in, settings has the
GAME face. **The six new forks, T018–T023** (`docs/TASTE_QUEUE.md`): the parting planes' weight and rhythm,
the map as a strata chart, the deep's lamp at 200 m, RETURN TO SURFACE priced at nothing, "seen" as an
eight-metre disc, the beacon's pulse. **Two design rows:** V60 (no release key for a slack line, legacy's
rule) and V73 (NEW GAME has no seed control). **Step 7's scope** as before.

**CI:** every commit of this round is on main; `f77b6acb` is the head to read. One red run on the way
(e62f91ab: `test_gram_map` pinned the old tooth cell, fixed next commit), one cancelled by a following
push, one WORKING.md freshness gate (fixed in the commit after). The draft PR #51 shows MERGED because
main took its commit.

---

## Anything that felt wrong even though it passed

**The laminae are mine.** Under the lamp the rock reads as layered stone; where the fade field runs flat
it reads as ruled paper (V71, T018). **The status beacon was never seen in the dark:** no start record
places a machine underground; the suite pins its cuts and colours. **The first five seconds after a fresh
boot stutter** while the new aquifers pour (13 ms hub ticks; V65). **RETURN TO SURFACE is free** (T021).
**The "seen" rule counts ore behind a lit rock face** (T022).

---

## Blocked, and what it's waiting on

Nothing blocks; the next step is the director's hands on it.

## Taste queue

**17 open.** T001–T011 unchanged; T012–T017 ruled and executed, closed; T018–T023 new this round.
