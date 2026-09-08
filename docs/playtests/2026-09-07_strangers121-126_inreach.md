# Screen-led playtest, strangers 121-126 in parallel -- 2026-09-07 late, on 2fe07582 (D0521, the ring reads IN REACH), THE SHIPPED SEED, the batch's snapshot

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once through `playtest/batch.py`, launched from
a clean worktree at 2fe07582 (the main checkout carried another session's untracked tooling under
`playtest/`, which D0510's dirty check rightly refuses); boot line `site=shallow_clay seed=20260826
start=tutorial`; every seat opened `snapshot_2fe07582_0.json` (D0519); six seats in 5.6 s wall. The mission is
115-120's (D0520's calibration line included), so the actor condition is 115-120's and the game differs by
D0521 alone: the ring on a machine target draws solid and filled with "FORGE · IN REACH" (or RIG, MOUTH) by
the drop's own reach rule, now in `core/reach.gd`. Supervised; no seat replaced; no agent stalled. Journals
`docs/playtests/2026-09-07_stranger{121..126}_journal.md`.

**Classification (`stranger.py validate`):** 121-126 all VALID. `Invariants` reports: 0 in all six logs.

| | four ore | coal in pack | two ingots | delivered | drill placed | bursts | where it ended |
|---|---|---|---|---|---|---|---|
| S121 | 2.2 s | 10.8 s | -- | -- | -- | 34 | the world's right edge; three floor drops with nothing in sight |
| S122 | 1.3 s | 31.8 s | 40.7 s | 55.5 s | 63.5 s | 57 | the fuel rung's card; quit near budget |
| S123 | 7.0 s | -- | -- | -- | -- | 42 | fed 6 ore from inside its own pit at the spawn; never reached the seam |
| S124 | 2.2 s | 19.0 s | 40.1 s | 42.5 s | -- | 37 | the drill in the pack; quit on the ✓ Deliver card before the build card |
| S125 | 12.6 s | 22.7 s | 36.5 s | 39.1 s | 43.7 s | 54 | the fuel rung: coal mined, the drill not yet fed |
| S126 | 2.4 s | 28.5 s | -- | -- | -- | 59 | the world's right edge; ten drops between 203 and 254 |

**Four ore 6 of 6. Coal 5 of 6. Two ingots 3 of 6 (2 in 115-120). Delivered 3 of 6 (0). The drill placed
2 of 6 (0 in any batch before). Two seats reached the fuel rung, the fifth of six.** Before D0521, one seat
in eighteen had delivered (S111). The three who got through named the state: S125 "the in-reach indicators
(RIG-IN-REACH, MOUTH-IN-REACH) for proximity feedback"; S124 fed with "11 ORE → FORGE", "3 COAL → FORGE"
and read "+1 ingots, 2 more coming"; S122 delivered, then right-clicked the drill into the mouth.

## What the frames and receipts show

- **The reach state is the difference.** Same mission, same actor behaviour (their walks are still 30-60
  ticks), one HUD change: three of six fed the forge and the rig from inside the band, against two of six
  feeding anything in 115-120 and one of eighteen delivering before. S123 also fed (6 ore from (130,82),
  the receipt in their timeline) but had no coal.
- **The checkmark card, again.** S124 quit at 43.6 s on "✓ Deliver 2 ingots" with the drill in the pack,
  "no new objective appeared"; the build card follows one burst later. S113 did the same on the forge's
  card. Two of the three seats that finished a rung on its ceremony card read the ceremony as the end.
- **The edge, again.** S121, S124 and S126 reached cell 254 (S124 on the way back); S121 and S126 ended
  there dropping stacks with nothing in sight (NO MACHINE HERE, true). Fourteen of twenty-four seats over
  four batches have reached the right edge.
- **S123's pit.** First cuts under the spawn read "NOT ORE — that was clay" three times (they dug the pad
  looking for ore), and from the pit's floor (row 82) the seam was TOO FAR and the pit's sides blocked the
  walk; the one drop that fed was ore, into a starved forge. The footing rule (D0509) spares the boots'
  cells from a blow AIMED elsewhere; a blow aimed at the ground still opens it, as THE WAY DOWN teaches.
- **S125's fuel rung** ("Fuel the Drill") came at 57 s: coal mined, then out of budget at 54 bursts. The
  first seat to see the fifth card.

## What changed because of this batch

Nothing new in the game from these six; the two findings that repeat (the ceremony card read as the end,
the right edge) are the director's to rule on: the checkmark card's linger before the next card, and the
world's east boundary that reads as "keep going".

## For the director

D0521 is the first change since the fleet that moved delivery: 3 of 6. The remaining walls in these six
are not the drop: one seat dug itself a pit at the spawn and could not get out to the seam, two walked
30 m to the world's edge, and two quit on a ceremony card. The stride (T035) stands measured at 9 m/s.
