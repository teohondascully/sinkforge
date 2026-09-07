# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-07, the overnight loop. Earlier parts are in `git log -p -- docs/BRIEF.md`
(D0405–D0415; D0416–D0428; D0429–D0443). THIS PART: the loop run under the director's fifteen
amendments -- every seat pinned (build, seed, mission hash, model, launcher, priority, frame cap), every
run VALID or VOID by a classifier that never reads the agent's report, the first rung read from the pack,
the ceiling run kept apart -- thirty-six strangers in twelve batches (25-60), D0448–D0474, twenty-seven
ledger entries, all on main.** Reports in `docs/playtests/2026-09-0{6,7}_*`;
sessions under `tests/body/recordings/playtest_2026-09-07_stranger{25..60}/` (local); the harness in
`playtest/` (`stranger.py`, `supervisor.py`, `replay.py`, `ceiling.py`, `seat.sh`).

**Headline: the opening (rungs 1-3) went 3 of 3 twice in a row on the shipped seed after D0452-D0458,
1 of 2 valid on the holdout seed; the fourth rung, reached by nobody in sixty bursts from a fresh
game, was played fifteen times from a save that starts at its door (D0462): 13 valid, the drill in hand
3, placed 1, against a scripted ceiling of 14.1 s. Ten game fixes came out of those fifteen frames
(D0464–D0473), each one a state the game had let pass in silence; what is left on that rung is the
strangers' pointer and their stride, which no lesson reaches. The last batch, a fresh game on the fixed
build, found D0464 had taken the opening with it (2 of 3 at 12.8 and 16.8 s, one never, against six of
six at 1.3-21.6 s before): the metre now applies to a pointed rock only (D0474), confirmed by hand and
not yet by a batch.**

---

## What landed

**Game fixes, each on a batch's frames and inputs, each pinned.** D0452 a held MINE snaps whatever the
hand holds (one clay had switched the aim to the exact cell and refused "sight" inside the ring). D0456
the scoop measures from the body's trunk (the forge's ingots come to the drop spot). D0457 the world ends
in a wall. D0458 the cut mark over a buried target; D0459 the ring moves to the shaft's mouth once the
drill is carried. D0461 STILL WORKING and the card in hub seconds. D0463 "Copper ore". D0464 the aim
snap's tolerance is a metre once the cursor is out of reach (a hold on the mark from a body length past
the reach had cut the ground at the feet, wordless). D0465 a carried machine's icon is its casing. D0466
the build how-to names the ring that moves. D0467 the cut mark stays while any cell of the roof stands;
CUT THROUGH for the air after your own bite. D0468 the mark is the metre and a cell either side (a body a
metre wide rests its edge on the neighbour column). D0469 the line is a drill over a smelter; WRONG SPOT
for a drill set elsewhere. D0470 a BUILD that places nothing says why (TOO FAR, STEP ASIDE); D0472 only
with a machine in hand. D0471 HARD LANDING at terminal speed, not on a hop. D0473 TOO FAR DOWN for a
far target under the ground. D0474 the metre is for a pointed rock; open air out of reach keeps
legacy's reach (the correction of D0464, in `docs/CORRECTIONS.md`).

**Harness.** D0452 the LaunchServices launcher at foreground priority (every seat before it ran at nice
5 under the director's load). D0454 the pin and the void classifier; the replay. D0455 the supervisor.
D0460 `--seed`. D0462 the rung-N variant (`--load`, the seat's save command, `ceiling.py --save-to`).
D0467 `--rung4` (the fourth rung scripted: 14.1 s) and `slots` in the receipts (the pack dict is sorted;
the bar is not). D0453 the commit identity is the Gmail address from 51fe12d7.

---

## What was learned

1. **A silent substitution is a quiet green.** The snap cut nine cells 2.85 m from the pointer and the
   receipt read "dug"; the stranger's journal read "mined the white square". Every refusal now has a
   word; every hold either cuts what was pointed at or says why not (D0464, D0467, D0470).
2. **The predicate must be as narrow as the rung's name.** "Build the line" ticked on any drill; one
   stood in a tunnel boring ore into nothing while the next rung waited forever (D0469).
3. **A lesson about the wrong verb outranks the how-to.** TOO FAR for BUILD, fired with no drill in
   hand, sent two strangers after a ring under the ground; TOO FAR itself sent three past the square
   at a 4.5 m stride (D0472, D0473; T035).
4. **The mark is a promise the physics has to keep.** A metre-wide mark over a metre-wide body: four
   cells never drop it, six always do (D0468). The mark vanished with the first bite's centre cell while
   three quarters of the metre stood (D0467).
5. **A sound's threshold is not a lesson's.** HARD LANDING fired on a hop because the thud's 240 px/s
   is a two-metre step and a jump lands at 365 (D0471).
6. **A noun the world has two of is not a guide.** "The shaft's mouth" read as the pad's own shaft for
   two of three (D0466).
7. **The receipt's order is not the bar's.** The scripted run pressed the coal's key for the drill; a
   sorted dict and a pickup-ordered bar are two populations (D0467, `slots`).
8. **A runtime error inside a test shrinks the count.** `27 asserted, ALL PASS` with the pin never
   reached; the battery found it after the key was read with a default. grep SCRIPT ERROR; compare the
   count.
9. **The grapple's swing voids a run.** Rule 3's non-settling frame is right for a stall and wrong for a
   swing, which is periodic; three runs (42, 47, 48) are void on it. A rule for the
   director, below.
10. **The variant is the instrument for later rungs.** Fifteen runs at BUILD's door in the time sixty
    bursts from a fresh game reached it once.
11. **A rule measured on one rung is re-measured on every rung that shares its instrument.** D0464's
    metre was right for the mark and took the opening's forgiveness with it; five batches on the variant
    could not see it, one fresh-game batch did. Alternate the variant with the shipped seed (D0474).

---

## The decisions this round is waiting on

**The swing (rule 3).** Mark a frame on the line "on the line, in motion" and keep the run, or keep
voiding. **T035 RUN_SPEED** (9 m/s): three strangers stepped 4.5-7.5 m past the square on "step closer";
a human taps. **The forge's bubble during the mine rung:** 10 of 17 first presses since D0449 landed on
the forge's column, 80 px left of the ring; a gate on the need-bubble and nameplate while the rung is
open is one flag in `MachinePainter` (not done: 58-60 put 3 of 3 first presses there again, 13 of 20
since D0449; D0474 turns that press back into ore, so the question is now feel, not the rung). **The shaft's width:** a body a metre wide cannot walk into a mouth a metre wide and stands over
it on both lips; inside, it must jump with a direction held. **Provisional, overrule by deletion:** T032
the reticle (D0449), T036 the wall (D0457), T038 "spawn" (D0451), the metre tolerance (D0464), the
six-column mark (D0468), the build wording (D0466). **Open from before:** T031, T033, T034, T037,
T024–T030, D0427's occlusion.

---

## Anything that felt wrong even though it passed

**Every batch is three Haiku agents; the population's pointer is inside every number.** Two strangers
"mined the white square" three metres from it. **The playthrough suite drives the door with cells, not
pixels;** it latches every rung and cannot see what the strangers cannot see. **The variant's save is one
world position** (the body a body length left of the pad); a stranger arriving from the wood rung stands
elsewhere. **The receipts' `refusal` for a five-tick press is read by the agent and never seen on the
screen** (the mark is gone by the settled capture). **`interface.gd`, `observation.gd` and `hints.gd`
sit at the size gate;** the next field costs a rewrap.

---

## Blocked, and what it's waiting on

Nothing is blocked. The GPU profile still needs an idle machine (D0418). The fourth rung's next
evidence needs a population that can read the screen better than these agents, or a human at the seat.
