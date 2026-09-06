# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-06, fifteenth round: Part A of the A+ brief, then the integration pass (the
fourteenth round's brief is in `git log -p -- docs/BRIEF.md`; D0396–D0404). THIS ROUND: Part A -- the
fresh-boot stutter closed at cause (D0405), the ruled beds (D0406), the beacon witnessed in the dark
(D0407), the water's ripple bound (D0408). Then the director's next brief re-ranked everything under
Astra's new-player review, "don't polish the look of an uncompleteable game": ranks 1-6 fixed with a
playthrough test (D0409–D0413), rank 8's first slice measured and fixed (D0414). Part B, the signature
look, is deferred and not started.** Captures before and after are under
`tests/body/recordings/round15_2026-09-06/{beds,beacon,settings,tutorial,hud}/`.

**Headline: a stranger can now finish the opening.** Before D0409 the first rung could not be completed --
the tutorial's ore yielded an item no recipe took, the forge stood a step beyond the scoop's reach, the
hopper was scooped through rock, and the cache sat off the pad. `tests/test_tutorial_playthrough.gd`
drives a fresh start through rungs 1-6 with the door's own verbs in 48 s of play; a build without the
`yields` contract fails it at rung 1. Every sentence the tutorial speaks now names the key it is bound to,
the thing it means is ringed in the world, and the lesson text lives at one place on the screen instead
of over the rock the lesson is about.

---

## What landed

**Part A (D0405–D0408).** The water's active set with the lifted pass kept as the oracle, the aquifers
settled at generation (hub p50 first 5 s 13.3 → 1.25 ms; water errors at the 206 m warp 249 → 0);
`BedSequence`, a seeded succession for the laminae; the `beacon_probe` start record and the `room`
fixture, the amber ring 2.3-2.8x its control's luminance from ten metres in the dark; the ripple's tops
held under the film.

**Rank 1 (D0409), the opening loop.** `yields` on the material record (`WorldMaterials.yield_of`), one
reach for the scoop and the pick (3.2 m), a standing collect verb, the `pile` fixture, the cache moved onto
the pad. The playthrough suite, 20 assertions, is the proof.

**Rank 2 (D0410), the settings agree with reality.** Every row has a consumer, pinned live: the three
audio layers' injected levels, the score mounted (+50 ms boot, named), the shake kicked and decayed by the
rig, the zoom immediate, the large map a modal that deafens the hands, fifteen bindings listed, the
footer's legend fitting and LEFT/RIGHT adjusting a slider.

**Rank 3 (D0411), the tutorial teaches.** `[MINE]` fills with the CURRENT binding from a table the shell
writes; the goal carries its count; every rung shows its how-to the moment it opens and again on a stall
(legacy's forty-second silence reversed); a finished rung is acknowledged first; `TargetGuide` rings the
vein, the forge, the trunk, the drill, the seam; the ladder rides the save.

**Rank 4 (D0412), the hotbar.** The selection follows its item when the pack compacts; the tenth digit
reaches slot 10; an empty pack draws no bar.

**Rank 6 (D0413), the HUD's composition.** `LessonDock` replaces the head-anchored bubble: one place, lower
left above the hotbar band, its rect a function of the text alone and pinned 38 px clear of the action
area round the miner at the closest zoom under the largest lead a visible lesson can have (a 260 wrap
fails at -67: the mutant). The depth chip: an edgeless plate, 11/8 pt, dimmed. Rank 5 (the water
errors) landed inside D0405.

**Rank 8, first slice (D0414).** Measured on the scripted walk with a meter that could finally see the
frame: three instrument gaps closed (a 16.7 ms threshold, HUD chips named, a draw-phase clock). Two CPU
causes at cause: the observation's plane rebuild 9.3 → 0.66 ms (the surface read off the sky floor; the
old scan was also wrong underground), the target ring 3.0 → 0.04 ms a frame. Quiet-tick p99 on the walk
6.4 → 2.6 ms. The remainder is the CPU waiting on the GPU at a constant 230 draw calls.

---

## What was learned

1. **A stranger's blocker is a contract nobody wrote down.** Ore yielded "ore_iron", the forge took "ore";
   both sides were right and the game could not be finished. The material record now SAYS what it yields,
   and the playthrough is the only test that would have caught it.
2. **Reach is one number or it is a trap.** The scoop at 2.5 m and the pick at 3.2 m put a machine in
   the pick's reach and out of the hand's. One constant, referenced twice.
3. **A reversed rule has a suite pinning the old one.** D0411 reversed legacy's silence; three pins in
   `test_objective_line` encoded the silence and I ran every suite but that one. CI caught it, one push
   later. Grep the CLASS across `tests/` when a rule flips, and run every hit.
4. **A lambda on an engine singleton outlives the script language.** Two lambdas of a RefCounted on the
   `RenderingServer` signals crashed Godot at exit on every perf run ("Godot quit unexpectedly", four
   reports). A Node's own methods are dropped with the node. The crash reports were the instrument.
5. **The painters' total was never the frame.** Every slow frame had painters under 3.5 ms; the frame
   was 17-23. The missing phase was the draw's vsync wait after the CPU overran, and the overrun was an
   observation scan (7.85 ms) and a HUD chip (3 ms) the report showed as `?`. Name the chips; clock the
   phase; only then fix.
6. **A cache keyed right is not a cache that hits.** The window snaps every eight metres, as designed --
   and each hit of the miss cost 9 ms because one field inside it was scanned instead of read. Measure
   the cost of a miss, not just the rate.
7. **The scan was wrong as well as slow.** Scanning the surface from the window's top made rock at the
   top row "the surface" and a cave mouth there a shaft to the sky. The cheap answer (the sky floor) was
   also the true one.
8. **The engine's TIME monitors refresh once a second.** Forty consecutive slow frames read identical
   `proc`/`phys` values. An instrument that repeats itself is not measuring the frame.
9. **The drop count under vsync is not a treatment metric on a shared machine.** 4-23 run to run; the
   A/B spread swallowed the treatment. The quiet-tick p99 and a vsync-off count moved cleanly and are
   what the ledger quotes.
10. **"Short pointer only" is a design sentence, not a spec.** Read as: what stays near the miner points
    and does not read. Written into the ledger as a reading so the director can overrule a reading, not
    a mystery.
11. **The action area is a testable rect.** Mining reach plus half the body, the camera's lead at the
    busy threshold, the closest zoom, the TALLEST lesson: 38 px clear, and the pin fails a wider wrap.

---

## The decisions this round is waiting on

**Play the opening.** `godot --path .`: rungs 1-6 complete from a fresh start; the lessons dock lower
left; every settings row does something. **Part B:** the signature look was deferred for the integration
pass; the game now completes end to end, and the walk's remaining frame drops are GPU-side, which is the
same work. **The new forks T024–T028** (`docs/TASTE_QUEUE.md`): the dock without a body cue, the
inspector's tooltip at the aim, the unbindable digits, the tutorial's thin-crust cavity, the score's
boot cost. **Ranks 7, 9-13** were not reached: ore legibility (V32), the map's corner view, the
Tiny-Glade lighting prototype, feel, audio, world identity.

**CI:** every commit is on main; `5c36864c` is the head to read. One red run (83072b0d, the objective
line's stale pins, fixed in bbe37387 which is green), two cancelled by following pushes.

---

## Anything that felt wrong even though it passed

**The walk still drops frames.** ~100 of 1500 frames over 8.3 ms with vsync off, at a constant 230 draw
calls and 2.5 ms of painters: the GPU, which the script cannot time under Metal. **The boot's first frame
is 73-85 ms** (shader compiles), named, not fixed. **The tutorial's opening cavity logs the ambiguous-floor
invariant on every crossing** (T027). **The target ring's miss is a 3 ms scan** once per metre walked
where no ore is within ten. **The inspector's tooltip sits at the aim** (T025).

---

## Blocked, and what it's waiting on

Nothing blocks; the next step is the director's hands on the opening.

## Taste queue

**22 open.** T001–T011 unchanged; T012–T017 closed; T018–T023 open from the last round; T024–T028 new.
