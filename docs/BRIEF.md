# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-07, the first-rung gate. Earlier parts are in `git log -p -- docs/BRIEF.md`
(D0405–D0415; D0416–D0428; D0429–D0443; D0448–D0474, the overnight loop). THIS PART: the director's
brief of 2026-09-07 -- one shipped-seed batch on the D0474 build, a holdout if it is 3 of 3, then the
forge rung, wood and BUILD separately -- taken as far as the gate and its two fixes: strangers 61-66 in
two batches, D0475–D0478, on main.** Reports `docs/playtests/2026-09-07_strangers{61-63_shipped,
64-66_holdout}.md`; sessions `tests/body/recordings/playtest_2026-09-07_stranger{61..66}/` (local) with
the replay of 62 and the minimal pair beside them; the harness in `playtest/` (`evidence.py` is new).

**Headline: the shipped-seed first-rung gate passes -- two consecutive valid 3-of-3 batches on two seeds
(61-63 shipped: 2.2 / 2.8 / 11.3 s; 64-66 holdout 20260907: 8.7 / 7.0 / 4.3 s), four ore in the pack by
ordinary input, every seat pinned, no void. Every one of the six successes came through the aim snap:
no pointer landed on a visible reachable cell. D0474 is legacy's reach rule verbatim, durable, with one
provisional line (the metre for a pointed far rock). Reading the six runs' receipts found two defects the
opening had been carrying in silence -- a dig plan that kept every mark for the whole game and dug one
25-48 s later under a TOO FAR lesson (three of six runs), and a WHITE SQUARE that floated in the sky
over the tree's crown on the wood rung -- both fixed on their frames and inputs, both pinned, both
mutation-tested. The forge rung is 3 of 6, wood 1 of 6, BUILD reached once; nine strangers have now
ended in a sinkhole one stride east of the pad.**

---

## What landed

**The gate (D0475).** Three uncoached strangers a batch (58-60's mission mix set aside so every seat
measures the opening); the pack, never the card; the classifier, never the report. D0474's two halves
named: the reach-wide snap for open air or an occluded cell out of reach is legacy's `_effective_aim`
verbatim, seam included (an open cell IN reach aims exactly and is refused -- S66's press on the forge's
top cell got THAT IS A MACHINE, its next press two cells lower, out of reach, cut 11 ore); the metre for a
pointed rock out of reach is D0464's one line, pinned, unexercised by any batch since. The director's
seven aim cases are all pinned now (two added: open air too far, a machine's cell and the pocket below it).

**D0477 the dig plan lives while the button is held.** Legacy's plan painted the solid cell under the
pointer on every hold, kept it for the game, and worked the nearest mark when the aim itself was
refused. S62's first press, snapped to the face, left its raw cell marked; a 300-tick hold on the tree
from the pad 25 s later, refused `far`, dug 9 vein cells for 3 ore. S63 and S64 the same shape (S64 then
walked onto its hole and fell 18 m). Replay IDENTICAL; minimal pair on fresh seats (a C tap between the
presses removes the dig); the interface pin's mutant digs three released marks. Sketch-then-dig survives
inside one hold; a sketch across a release does not. Reversible in two lines.

**D0478 the cut mark's roof is ground.** `_metre_has_rock` no longer counts wood or leaves; the mark
over a trunk under its own crown is gone, a metre of clay over the crown still earns one.

**D0476 the receipts carry the pointed cell** (raw cell, snapped aim, body at the first held tick) and
`playtest/evidence.py` prints the per-burst table the reports are written from.

---

## What was learned

1. **The snap is the opening.** Six of six first rungs came through it; the visible face of the ringed
   metre is a 32 × 8 px target and the strangers' pointers land 8-95 px left and 9-29 px low. D0464 took
   it away and the opening went 2 of 3; D0474 gave it back and it went 6 of 6.
2. **A rule copied verbatim is still a decision once a stranger meets it.** Legacy's plan and legacy's
   reach seam both came through D0354/D0474 untouched; one had to change, the other is pinned so that a
   change to it is a choice.
3. **The seam turns one column into a coin flip.** Two presses 15 px apart on the forge's column: the
   upper cell in reach (exact, refused), the lower out of reach (snapped, 11 ore). No lesson can explain
   that; the director decides whether it should exist.
4. **A stale mark is the quiet form of the silent substitution.** Drawn as a small orange outline nobody
   read, it dug ore the receipt recorded and the lesson contradicted. The receipts caught it; no report
   did (S62's says "widened the hole").
5. **The mark's "buried" test needs a material, not a solidity.** A tree is solid over its own trunk.
6. **The stride sets the map's hazards.** A 60-tick D is 9 m; the sinkhole mouth's near rim is 12 m
   (D0388's keepout); the second stride east lands in it on both seeds. Two strangers went in within
   30 s on the holdout, looking for a forge that stood 3 m to their left.
7. **BESIDE excluded the cell that works.** S61 stood on the forge's own column, read "stand BESIDE it"
   and stepped away; S63 dropped from that column and smelted.
8. **A press with the aim only at refusal is half a receipt.** Six runs were read with a scratch
   screen-to-cell estimate before the seat was made to say the cell it knew.
9. **The gate ran twice and the second run tripped on the first run's artifact.** `gate_timing.txt`, a
   CI step's report; ignored now. And I committed past that red count before reading it -- the chain
   was joined with `&&`, the commit was typed after it by hand. Read the count before the next command.

---

## The decisions this round is waiting on

**The sinkhole mouths one stride from the pad** (nine strangers; D0388's 12 m keepout, a 3 m half-width
mouth, a 9 m stride): move the keepout past two strides, rim the mouth, or keep the antagonist where it
is. **The reach seam** (learned 3): keep legacy's exact-in-reach rule or snap open air inside reach too.
**The smelt lesson's BESIDE** (learned 7) and **the first Q at the spawn cell** (4 of 6). **The plan** --
D0477 is the reversible half; the whole feature back with a legible mark is the other answer. **From
before:** the swing rule, T035 RUN_SPEED, the forge's bubble during the mine rung (14 of 23 first presses
on its column since D0449), the shaft's width, the how-to's 9 s hold; T031-T039, D0427's occlusion.

---

## Anything that felt wrong even though it passed

**The gate measures the snap, not the pointer.** Six of six with nobody on the target. **Every batch is
three Haiku agents;** two reports called a visible lesson "no feedback" (S66) and a guide speck at 31 m
"the forge" (S65). **The wood rung is 1 of 6** and the strangers cut nine of sixteen trunk cells at
chest height, then hold on the gap; the seven behind the body's legs are never tried. **The first draft of
the plan pin passed on the mutant** (its marks were out of the body's sight, so legacy's drain could not
have dug them either); the pin now carries a workability control. **The seat's mission text still leaks the receipt's `lesson` and `refusal` to
the agent** through the command's JSON line.

---

## Blocked, and what it's waiting on

Nothing is blocked. Next by the director's order: the forge rung with the same discipline (a rung-2 save
variant, or the shipped seed read at the drop), then wood and BUILD separately; a shipped-seed batch on
this build re-measures the opening after D0477.
