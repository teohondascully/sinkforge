# Screen-led playtest, strangers 70-75 (six in parallel) -- 2026-09-07, on fa5d5dbb, THE NEW OPENING, a fresh game

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build fa5d5dbb clean:
D0482-D0485, the coal-fed forge, the crew's rig, no free drill, deliver in place of wood; boot line
`site=shallow_clay seed=20260826 start=tutorial`; LaunchServices foreground, nice 0, frame cap 60, Godot
4.6.2-stable, macOS), uncoached. Supervised (30 s / 180 s). Six seats at once ran without a stall: **all six
VALID** (`stranger.py validate`). Journals `docs/playtests/2026-09-07_stranger{70..75}_journal.md`;
artifacts `tests/body/recordings/playtest_2026-09-07_stranger{70..75}/` (local), the scripted witness of the
same build beside them (`..._witness_new_opening`: ore 1.3 s, coal 3.4 s, two ingots 9.6 s, the drill in
hand 17.7 s).

**One confound, known before the reading:** this build's smelt how-to ran to a third line and lost its
tail to the ellipsis -- every stranger saw "...holding each stack (its number key sele…" and never the
words "press Q". CI's objective-line suite caught it after the push; fixed in 8c6fc9f4. The batch is a
valid measurement of fa5d5dbb, not of the fixed label.

## What the receipts say

| | four ore | coal in the pack | Q pressed | what the Q did | two ingots |
|---|---|---|---|---|---|
| S70 | 17.0 s | never | 0 | -- | never |
| S71 | 2.2 s | 36.6 s (5) | 0 | -- | never |
| S72 | 8.0 s | 17.8 s (5) | 0 | -- | never |
| S73 | 27.8 s | never | 2 | 44.3 s at cell 108: the forge took the ore (2.5 m, in reach); 69.3 s at 163: floor | never |
| S74 | 3.3 s | 14.3 s (9) | 4 | at cells 173 and 137 (ON the rig) with ore selected: floor each time, DROPPED | never |
| S75 | 1.3 s | never | 1 | 74.7 s at cell 123: the forge took 11 ore | never |

**First rung 6 of 6** (the snap again; S70 and S73 dug for it). **Smelt 0 of 6.** Nobody dropped both
stacks at the forge: the three with coal never pressed Q; the two who fed the forge had no coal; one fed
the rig. Three of six never found the seam (a metre of black at +5, eight metres from the forge, a
32 × 8 px face at spawn); the three who did dug into it or beside it (cells 146-153, rows 80-86).

## Causes, in the director's classes

1. **Refusal wording (the label):** the truncated how-to is the batch's dominant cause -- four of six never
   pressed the drop key, where every batch since D0443 had pressed it by the fifth burst. Fixed (8c6fc9f4);
   the objective-line suite pins every label at two lines whole and would have caught it locally.
2. **Material legibility (the seam):** three of six never found coal; "the black seam right of you" is one
   metre wide and reads as shadow on the surface. **D0486:** the smelt ring goes to the coal seam until the
   pack holds coal, then to the forge -- the ring says what the rung needs next.
3. **Target identity (the rig):** S74 fed the rig (ringed? no: the rig's need-bubble asks for ingots
   from tick one), the same class as the shaft forge's bubble in 67-69. For the director: a machine's
   need-bubble while another machine is ringed.
4. **Pointer:** S73 and S70 dug for the ore instead of pressing on the ring (27.8 s and 17.0 s).

## What this decides

D0486 on these frames. No further batch tonight: the label fix and the seam ring are both discoverability
changes and the next batch measures them together. The scripted witness stands as the cheap check.
