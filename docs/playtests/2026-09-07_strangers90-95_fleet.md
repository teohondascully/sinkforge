# Screen-led playtest, strangers 90-95 in parallel -- 2026-09-07, on dc3d3ff9 (D0494–D0499), THE SHIPPED SEED, a fresh game

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build dc3d3ff9 clean; boot
line `site=shallow_clay seed=20260826 start=tutorial`; LaunchServices foreground, nice 0, frame cap 60,
Godot 4.6.2-stable, macOS), a fresh game each, all six on the uncoached mission (58's text). The first batch
booted through `playtest/batch.py` (D0501): each seat in its own worktree, tiled. It measures the fleet on
76-81's findings together: the seam's look (D0494), the cards (D0495), the drop slot (D0496), the seam two
metres wide (D0497), unringed bubbles standing down (D0498), the ring's word (D0499). Supervised. Journals
`docs/playtests/2026-09-07_stranger{90..95}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{90..95}/` (local). **Batch 82-87 before it was VOID**
(reused session directories after a rejected boot had already run; D0501) and is not read.

**Classification (`stranger.py validate`):** 90-95 all VALID.

| | four ore | coal in pack | two ingots | delivered | drill set | fuelled | automation | bursts |
|---|---|---|---|---|---|---|---|---|
| S90 | 15.0 s | -- | -- | -- | -- | -- | -- | 44 |
| S91 | 1.8 s | 6.1 s | 34.8 s | 43.0 s | 49.0 s | 56.3 s | **56.3 s, the hopper rung at 58 s** | 49 |
| S92 | 2.2 s | -- | -- | -- | -- | -- | -- | 33 |
| S93 | 2.2 s | -- | -- | -- | -- | -- | -- | 33 |
| S94 | 1.7 s | 6.5 s | **19.4 s** | -- | -- | -- | -- | 32 |
| S95 | 3.2 s | 28.2 s | 57.8 s | 81.6 s | -- | -- | -- | 37 |

**Against 76-81: ore 6 of 6 (6); coal 3 of 6 (2); two ingots 3 of 6 (1); delivered 2 of 6 (1); the drill set,
fuelled and the first automation 1 of 6 (0).** S91 is the first stranger to pass the automation rung and
the first to say "would definitely keep playing"; S94 is the fastest forge of any stranger.

## What the frames and receipts show

- **The seam is found now, and the word is read.** S91 held coal at 6.1 s, S94 at 6.5 s (both straight from
  the ring), S95 at 28.2 s. S92's report: "confirmed COAL SEAM and FORGE locations visible"; S95's: labels
  "FORGE, CREW RIG, COAL SEAM, ORE, DRILL". Nobody hunted "black" this time.
- **TOO FAR DOWN at a surface seam: the wall for S92 and S93.** Both stood four to nine metres from the seam
  and pressed at its rows 83-86 (S92: eight presses, far_below then cut_through; S93 the same shape) and
  read "dig at the WHITE SQUARE first" -- then dug squares for the rest of the run. Cause in the receipts:
  D0473 measured "buried" as eight cells under the body's CENTRE, and the seam's bottom row is exactly
  eight under a body on the pad. **Fixed (D0504):** two metres under the FEET.
- **S94 dropped its ingots eight metres past the rig and never went back.** One 60-tick D from 126 to 162,
  Q at 162 (DROPPED, the slot said it), back to 135 with an empty pack, seventeen Q presses at a ring on the
  rig; the report calls the inventory invisible. **Fixed (D0505):** the deliver ring goes to a dropped stack
  of ingots first, its word INGOTS. The stride that overshot stays the director's (T035).
- **S90 dug under its own feet at the screen's centre** (bursts 1-8, the same class as S65), fell into its
  hole, took ore by the vein's edge at 15 s, then pressed the seam from four metres (TOO FAR), dropped its
  stacks far from any forge (five WRONG STACK / floor drops in one second at 42.8-43.8 s) and ended with
  clay. No new frame cause: the first press at the screen's centre and the stride.
- **S95 recovered a dropped stack by walking over it** (the DROPPED lesson's own sentence), then delivered
  from a better position at 81.6 s. The second stranger to be paid.
- **The bubbles stood down and nobody fed the rig by mistake** (0 of 6, against 1 of 6 in 70-75). S91's
  hesitation "multiple forge-like structures with different states" is the shaft forge, unringed and dim.
- **The card at "in the open…"** (D0495) ellipsized on every seat this batch played; fixed as D0502 after
  the boot, so these six read the cut line. S95's forge read "1 ore + 2 coal" -- the machine card, not the
  cut one.

## What this decides

The opening's wall moved from "find the coal" (four of six lost there in 76-81) to "reach it" (two of six
lost to a lesson that pointed down instead of across) and "keep hold of the ingots" (one). Two fixes taken
with receipts (D0504, D0505). For the director: the stride (T035; S94's one burst past the rig, S92's
walks to cell 202 and 254), the first press at the screen's centre (S90, S65 before it), and the hotbar when
the pack is empty ("invisible inventory", S94).
