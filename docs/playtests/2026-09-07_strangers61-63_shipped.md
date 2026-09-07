# Screen-led playtest, strangers 61-63 in parallel -- 2026-09-07, on 77dd4655, THE SHIPPED SEED, a fresh game

**Who played:** three fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build 77dd4655
clean: D0464-D0474; boot line `site=shallow_clay seed=20260826 start=tutorial`, LaunchServices
foreground, nice 0, frame cap 60, Godot 4.6.2-stable, macOS), a fresh game each, **all three on the
uncoached mission** (58's text; the mission hashes differ only by the session directory). The
director's gate for this batch is the first rung, so every seat measures it directly rather than
58-60's mix of uncoached / wood / down-and-back. Supervised (`playtest/supervisor.py`, 30 s / 150 s).
Journals `docs/playtests/2026-09-07_stranger{61,62,63}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{61,62,63}/` (local), the replay of 62 beside them
(`..._stranger62_replay`), the minimal pair `..._plan_pair_{a,b}`.

**Classification (`stranger.py validate`, never the reports):** 61, 62, 63 all VALID (no stall, no
capture error, every frame still, every input physical, no save written, all three quit cleanly).
**First rung by the pack: 3 of 3, at 2.2 s, 2.8 s and 11.3 s.** Nothing to classify under the
director's six causes; the holdout batch (64-66, seed 20260907) is the second half of the gate.

## The first rung, press by press (from `input_*.json` / `observation_*.json`)

Screen-to-cell for the pointer is 8 px a cell with the body's centre at (640, 367) at rest, calibrated
on the receipts' own refused aims (S63's (520,440) → (115,85), (560,440) → (120,85)); a raw cell marked
≈ is that estimate, a bare cell is the receipt's. The vein is cells 120-127 × rows 80-83 (dx -2..-1 of
the spawn metre 128-131); the forge's pocket is cells 116-119, open, rows 80-87.

| | first input | raw cell | refusal (aim / body) | broke | four ore |
|---|---|---|---|---|---|
| S61 | burst 1, 2.2 s: 120 t, LMB at (545,420) | ≈(118,82): **the forge's pocket, open air, 3.9 m** | none | 16 cells: (126,80) (124,80) (125,80) (127,80) (128,80) (125,81) (126,81) (127,81) (126,82) (123,80) (121,80) (122,80) (122,81) (123,81) (124,81) (123,82) | **2.2 s**, 11 ore |
| S62 | burst 2, 2.8 s (after a 30 t look): 120 t, LMB at (580,420) | ≈(122,82): **a vein cell under the face, in reach, occluded** | none | the same 16 cells | **2.8 s**, 11 ore |
| S63 | burst 1, 3.2 s: 180 t, LMB at (520,440) | (115,85): rock 1.25 m under the surface, 3.9 m off | **far** (115,85) / (130,75); lesson TOO FAR DOWN | 0 | -- |
| | burst 2, 6.3 s: 180 t, LMB at (560,440) | (120,85): rock under the vein | **far** (120,85) / (130,75); TOO FAR DOWN | 0 | |
| | burst 3: 60 t Space (a jump in place) | | | | |
| | burst 4, 11.3 s: 180 t, LMB at (560,430) | ≈(120,83): the vein's lowest row, at the reach's edge | none | 23 cells: the 16 above and (121,81) (120,80) (120,81) (120,82) (121,82) (122,82) (121,83) | **11.3 s**, 16 ore |

Body cell (130,75) throughout; nobody walked before the first press (3 of 3 understood the first press
from the card alone). Every one of the three successes came through the aim snap: not one pointer
landed on a visible, reachable cell. The visible face of the ringed metre is cells 124-127 of row 80,
a 32 × 8 px target at (588-620, 403-411); the pointers landed 8-95 px left of it and 9-29 px low.

## What the frames and receipts show

- **The snap carries the opening.** S61's press was on the forge's pocket (the case D0474 gave back:
  open air out of reach, legacy's reach-wide tolerance) and the cut appeared in the ring; the frame
  after (`frame_0001.png`) shows the hole at the ring, the card ticked and the reticle on the forge --
  from the seat it reads as plain success. S62's was an occluded vein cell in reach (legacy's rule, never
  changed). S63's third press landed on the vein's bottom row after TOO FAR DOWN twice; the lesson named
  the WHITE SQUARE and the next press was 10 px higher. **The rule as a rule:** reach-wide snapping for
  air or an occluded cell is legacy's (`legacy/scenes/main.gd` ~1840, "Terraria-style mining reach"),
  restored by D0474; the metre for a pointed far rock is D0464's narrowing, which none of these six
  presses exercised. Durable half and provisional half, named in the ledger (D0475).
- **The forge's column took 1 of 3 first presses** (S61 at x 545; S62 at 580, S63 at 520/560): 14 of 23
  since D0449. The forge's need-bubble is itself a yellow ring 80 px left of the white one; the ore
  card's "silver-flecked rock" does name what is under the ring (bluish, white-flecked cells; crop in
  the session dir). The camera-edge case did not arise: the body stood at screen centre for every first
  press.
- **The smelt rung: 2 of 3 (S62 15.9 s, S63 30.1 s; S61 never).** All three first Q presses were at the
  spawn cell, 3 m from the forge, and fell to the floor (DROPPED). S62 then dropped from cell 112 (1.5 m
  left of the forge's column) and S63 from cell 118 -- **standing on the forge's own column, which the
  scoop accepts** -- while S61 stood on that same column at burst 7 (`frame_0007.png`) and stepped away
  "to get proper distance", because the lesson says BESIDE. S61's later strides (15-30 t = 2-4.5 m)
  never stopped inside the 3 m window again; it dropped at 130 a second time, walked 9 m right, cut the
  ground and fell into the sinkhole at cell 190 (the seventh stranger there).
- **A stale dig mark dug ore nobody pointed at, twice, under a TOO FAR / NOTHING THERE lesson.** S62's
  burst 18 (27.9 s): a 300 t hold on the tree from the pad, refused `far` at (106,72), lesson TOO FAR --
  and 9 cells broken at (120-124, 81-84), +3 ore. S63's burst 17 (40.2 s): a hold on the trunk that cut
  8 trunk cells, then `air`, CUT THROUGH -- and 5 cells at (120-122, 83-85), +4 ore. Mechanism, read in
  `sim/mining/dig_plan.gd` / `sim/run/mine_hold.gd`: every hold paints the cell under the pointer into
  the dig plan (solid, allowed beyond reach, kept for the whole game); when a hold's own aim is not
  workable, the nearest marked cell in reach is worked instead. S62's first press at (122,82) was
  snapped to the face and the raw cell stayed marked, drawn as a small orange outline at the pit's edge
  (`frame_0017.png`, crop `s62_f17_crop.png`) for 25 s; the hole it opened made the mark visible; the
  tree hold dug it. S63's two refused presses marked (115,85) and (120,85). **Replay of 62: IDENTICAL over
  32 bursts** (tick, refusal, broke, state). **Minimal pair on fresh seats:** the ring press then the
  tree hold: arm A (nothing between) broke the same 9 cells, +3 ore, refusal `far`; arm B (a C tap --
  clear plan -- between) broke nothing, refusal `far`. Legacy's feature, legacy's semantics, the class
  D0464/D0467/D0470 exist to remove: a hold that neither cuts what was pointed at nor only says why.
- **The WHITE SQUARE floats over the tree.** On the wood rung the guide's cut mark (D0458: the topmost
  solid metre over a buried target) walks up from the trunk through the crown and lands in the sky above
  the leaves (S62 `frame_0017/18`, S63 `frame_0016`), a hollow square 100 px above the ring on the
  trunk. `_metre_has_rock` counts the tree's own cells as roof. Both strangers followed the ring, not
  the square; S59 (58-60) hit the leaves.
- **Wood: 1 of 3.** S63 at 47.5 s, the sixteenth trunk cell across two trees. S62 cut 9 cells of one
  trunk at chest height, then held on the gap three times (NOTHING THERE, CUT THROUGH) and walked off;
  the seven cells left stood behind the body's legs. **BUILD: S63 reached it at 47.5 s** (the second
  fresh-game stranger to), pressed RMB with clay in hand (silent by D0472), walked 9 m past the square
  in one 60 t stride, dug at its feet at cell 181 and fell 22 m into the sinkhole; grapple, THE
  CLAYBAND, no drill.

## What this decides

The first-rung gate's first half passes on the D0474 build: 3 of 3 VALID with four ore by ordinary input
at 2.2 / 2.8 / 11.3 s. The holdout batch decides the second half. Two fixes have a reproducible
frame-and-input cause from this batch and are taken after the holdout has booted on the unedited build:
the cut mark over a tree (view only) and the dig plan's stale marks (sim; provisional, reversible, the
director's call whether legacy's sketch-then-dig survives in any form). Recorded for the director, not
fixed: the smelt lesson's BESIDE where over-the-column works; the first Q at the spawn cell 3 of 3; the
stride (T035) on the smelt and BUILD rungs; the sinkhole at cell 190, seven strangers now.
