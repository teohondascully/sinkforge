# Screen-led playtest, strangers 40-42 in parallel -- 2026-09-07, on f298443d, THE HOLDOUT SEED 20260907

**Who played:** three fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build f298443d clean,
`--seed=20260907` -- boot line `site=shallow_clay seed=20260907 start=tutorial`, LaunchServices
foreground, frame cap 60, Godot 4.6.2, macOS), the same three missions (40 uncoached; 41 wood; 42
down-and-back), supervised. The director's rule 7: after two consecutive 3-of-3 on the shipped seed
(34-36, 37-39), one holdout before any wording is called fixed. The holdout world keeps the pad and its
fixtures (the record stamps them relative to the spawn) and changes everything around them: a pit to the
west, a different sinkhole east, copper lodes and a deep cave system under the pad. Journals
`docs/playtests/2026-09-07_stranger{40,41,42}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{40,41,42}/` (local).

**Classification:** 40 VALID, 41 VALID, 42 VOID (a frame that did not settle at burst 27: the body was
swinging on the grapple line, which never comes to rest; the rule voids it and the mechanism is the
harness's, not the game's -- noted for the director). **First rung by the pack: 1 of 2 valid runs**, at
36.9 s; the void run had it at 1.3 s on the first press. **The opening signal does not transfer to the
holdout as it stands.**

## Timeline (game seconds, from the receipts' pack)

| | S40 uncoached | S41 wood | S42 down-and-back (VOID at burst 27) |
|---|---|---|---|
| First press | D first; (470,405) far; (550,405) at burst 10 | (545,405): the forge's own cell -- THAT IS A MACHINE | (540,450) |
| Four ore | **36.9** (3 ore at 13.1 s from a bite of 23 cells; the fourth found underground) | never: 16 copper from a lode at 18 m, NOT ORE read at 63 s | **1.3** |
| Two ingots | **46.7** | -- | -- |
| Wood | never: a tree felled, 11 cuts, the stub left standing | -- | -- |
| Deepest | 2 m | 66 m ("trapped") | 33 m, grappled back to 30 |

## What the frames and receipts show

- **The first presses cluster on the forge's column again** (545-550, 405): the ring sits beside the forge
  on this pad as on the shipped one, and the strangers' pointer lands 80 px left of the ring's centre, on
  the forge's foot or on the forge. On the shipped seed the bite there hit the vein for 5-11 ore; here S40's
  bite of 23 cells took 3 ore and NOT ORE (for the clay), and S41's press was on the machine itself. The
  mechanism is the pointer's offset, not the seed; the seed decided how much ore the offset bite found.
- **S41 mined copper for forty seconds.** "Ore Copper Lode" in the clayband: `ore_copper` yields itself,
  the rung counts `ore`. NOT ORE said "that was ore copper" at 63 s (the item label reads oddly: "ore
  copper"). It never came back up.
- **S40's tree: felled, no block.** Eleven cuts of the sixteen; the stub above the cut stays standing by
  design (D0438: its cuts are the player's) and the stranger read the crown's fall as "destroyed".
- **S42 went deep and grappled.** GRAPPLE, PUMP IT and THE LINE CAUGHT all read; it climbed from 33 to
  30 m and could not find the way up. The swing is what voided the run.

## What this decides

The two 3-of-3 batches were on one world; the holdout gives 1 of 2 valid. The wording is not "fixed".
The next reads: the item label for `ore_copper`; whether NOT ORE should name the vein's material
("that was copper ore"); the rung-4 variant (D0462) for the cut mark and the moving ring, which no
stranger has reached in sixty bursts on either seed.
