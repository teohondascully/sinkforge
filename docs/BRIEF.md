# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03, eleventh round. A′: steps 0–4 done (tenth round's brief is in `git log -p
-- docs/BRIEF.md`; the ledger D0343–D0357 carries every one of them). THIS ROUND: STEP 5, THE GRAPPLE,
IS COMPLETE — 5a the `Fx` vectors (D0358), 5b the solver (D0359), 5c the line on the body and the
medium it moves through (D0360), 5d the rope painter (D0361). Step 6, the views and the boot scene, is
next.** Two rulings from step 5 are open in plan §8: the resolver and the ramp glide.

**Headline: the rope swings, and it swings the way legacy's did.** A hook flies from the hand at 30 px a
tick toward the aimed cell, bites in the first solid cell it samples, and the body hangs from it on a
position constraint that removes only the outward half of its velocity. Reeling spins the arc up, paying
out brakes it, the line wraps around corners and comes off them, a jump cuts a taut line and stacks the
leap on the swing. Driven through the real body against legacy's own floors: the pumped swing reaches
419 px/s against a floor of 172 (1.15× the legs); 90 ticks of reeling lift the body 240 px against 96;
a 320 px chasm no jump clears is crossed and landed; 372 of 420 px/s survive 30 ticks after a hands-off
release. Around it, the body gained what the plan listed from `player.gd`: rope grip and climb, the
lift's updraft, water wading, the coast above top speed, the step-down snap, machines as ground and wall,
wood that passes, `place()`. The calibrated body corpus (the hostile chamber, the movement course, the
golden traverse) held without a re-pin; the shaft-replay golden moved because the signature grew, with
its coverage summary identical to the pinned one, and is re-pinned from CI's Linux build.

---

## What landed

- **Step 5a (D0358).** `Fx.normalize`, `dot`, `limit_length`: `Vector2i` pairs of `Fx` (i32 components
  are the format), a CEILING root and truncated components so neither division can add energy, the i32
  minimum clamped on entry (its square summed twice wraps i64 and read as "no direction"). 17 assertions.
- **Step 5b (D0359).** `sim/body/grapple.gd`, legacy's ninja rope under `Fx` at identical pixels (480 px
  of line, the probe one terrain cell so the aiming ghost and the hook agree cell for cell), the wrapping
  polyline, the projection and the radial cancel through the raw delta over a ceiling root, the pump as
  one 21/20 ratio. 63 assertions: bite, miss, 48 compass shots where ghost and hook agree on whether and
  where, reel, projection never outside, tangent kept, pump 100→105 exactly, wrap and unwrap, chain,
  round trip. The coordinate gate gained the `fx` tag (mutation-tested). CI 82 → 83.
- **Step 5c (D0360).** `Surroundings` (bare terrain, the body as it was) / `WorldSurroundings` (machines,
  ropes, water, drafts; in `sim/run`, so `sim/body`'s dependencies do not grow); `body_swing.gd` couples
  the line after both axes collide, with a COLLISION STAND-IN pending the resolver ruling; `body_medium.gd`
  (water's five multipliers as ratios, the 110 px/s climb with the 6 px top hold, the 120 px/s draft); the
  coast; `VerticalResolve.step_down`; the heightfield and the floor diagnostic take the body's own
  predicate; `place()`. The ramp glide is NOT ported (§8). 69 assertions in two suites. CI 83 → 85.
- **Step 5d (D0361).** `view/visuals/rope_painter.gd` on `Frame` — placed ropes, the bowed cord (legacy's
  `rope_sag`), the hook wedge, the aim ghost from the door's own trace — and `carry_look.gd`; three
  observation booleans so the view never names the sim's enum; `ROPE_Z = −10` in the play scene. 20
  structural assertions. CI 85 → 86. **Step 5 is complete.**

---

## What was learned

1. **A 16-bit unit vector is the wrong instrument at a 100 px radius.** `pin + normalize(d) * free`
   fell about a hundred units short of the circle on five of seven probes, because a component's
   truncation (under one unit) is multiplied by the radius. `d * free / ceil|d|` lands within a few units
   and still never outside. The suite found it before any body did; the bound it asserts is the one that
   holds, not the one I wanted.
2. **The energy direction has to be built into the root, not the divide.** `isqrt`'s floor lets a
   quotient overshoot by a unit; a projection solver is stable only while rounding cannot add energy, so
   both vector divisions and the grapple use a ceiling root. `isqrt_ceil` is public for it.
3. **A gate written for cells read every `Vector2i` as a cell.** The coordinate-naming gate predates
   D0358's convention and wanted `terrain_`/`logic_` on pixel points. Its rule — every coordinate names
   its space — survives with a third tag, `fx`; the fix is a tag, not an exemption, and it was
   mutation-tested with one name left untagged.
4. **A jump right after a reel finds the line slack for exactly one tick.** The winch leaves the body
   closing on the hook at 418 px/s, so the tick after the reel stops it sits inside the circle. Legacy
   read the previous frame's tautness; ours now cuts on last tick's or this tick's. Found by a probe
   printing the tick, not by reasoning about it.
5. **A machine as a wall but not a floor is a machine the body walks through.** The horizontal sweep saw
   it, the heightfield did not; the body stepped onto it and fell through it, measured at 274 px past an
   80 px face. Every solidity read on the body's path has to be the same predicate — the heightfield, the
   resolver's row picks, and the floor-selection diagnostic (which otherwise reports the terrain under a
   machine as an ambiguous second floor, by `push_error`, which the runner counts as a crash).
6. **Legacy's 1.3-cell step means a lone machine is a step, not a wall.** The first test expected the
   body to stop at a machine's face; the body climbed it, correctly. Blocking is shown with two stacked.
7. **The release kick stacks the winch's rise.** `(min(vy, 0) + JUMP) × 21/20` is legacy's formula and
   gives −806 after a reel, not a bare −383; the expectation was mine to fix, not the port's.
8. **The body corpus did not need a re-pin, and the replay golden did — for a stated reason.** The
   coast and the step-down snap left the golden traverse inside its 5% and the hostile chamber at 64/64;
   the replay's coverage summary (jumps 858, digs 360, corner_ok 6) is identical to the pinned run's, so
   the hash shift at checkpoint 0 is the signature's two new fields. A re-pin with its discriminator
   read, not assumed.
9. **`Callable.bind` appends.** `body._blocked.bind(grid)` called with a cell passed `(cell, grid)`;
   every body suite went red on a type error at once, which is the good kind of failure. A lambda.
10. **The suite-coverage gate reads the tracked tree.** A new suite added to CI's list but not yet
    committed reports "dangling"; the gate is right and the commit resolves it. Run the local coverage
    gate before pushing — the 5b push went red on CI for exactly this, one commit after it passed here.

---

## The decisions this round is waiting on

**The resolver (P-28).** The swing's collision half is a stand-in: a projected position whose box would
overlap rock is refused and the line reads slack for the tick. Same outcome at a flat wall (pinned), a
different one at a corner, where legacy slides along the face and this holds. Ruling on the resolver
turns the stand-in into legacy's re-resolve of both axes.

**The ramp glide.** Not ported; the heightfield is this build's ramp. Confirm, or it is a small lift.

**Plan §8's other rulings** stand as before: Splitter, Ore Vent, power gating, the Crusher chain,
`press_plate`/`mill_gear`, `earth` 5.6 → 6 ticks, the material-id/item-id map, pre-pivot saves refused,
the 36 untracked recordings (gate 27 red locally), the `history/` cull. **Standing:** P004, P015/P017,
P026–P029, T001–T004.

**CI:** 5a green on all four jobs; 5b's first push went red on the suite-coverage gate (the new suite
was not in CI's list) and was corrected in 5c; 5c was harvested on a draft PR for the golden re-pin and
main receives it re-pinned. The head's run is the one to read.

---

## Anything that felt wrong even though it passed

**The collision stand-in.** It is a documented deviation at corners, chosen over touching a parked
resolver; the file header, §8 and D0360 all say so, and a suite pins the wall case so the deviation
cannot widen unnoticed.

**The ghost is traced from the last aimed cell, not the pointer.** The observation has no pointer; the
mine hold's aim is what the door knows. Legacy traced from the raw pointer every frame. On the frame
where the aim cell changes, the ghost lags one tick.

**`Grapple` reads `Body.TICK_HZ` and `Body` holds a `Grapple`.** A class-name cycle GDScript resolves
(the resolvers already do the same to `Body`), kept so the tick rate is one constant, not two.

**The winch drive measures from the hitch, legacy from the anchor.** A wrapped line pulls from its
hitch; the deviation is stated in `body_swing.gd` and D0360.

**Two `Vector2i` conventions now share one type.** A cell index and an `Fx` pixel pair are both
`Vector2i`; the name tag is the only thing telling them apart, which is why the gate had to learn it.

---

## Blocked, and what it's waiting on

Nothing blocks step 6. The swing's corner behaviour and the ramp glide wait on §8.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
