# Screen-led playtest, strangers 76-81 in parallel -- 2026-09-07, on 37252f4c (D0488–D0492), THE SHIPPED SEED, a fresh game

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build 37252f4c clean, one
docs commit past the pushed 7037e526; boot line `site=shallow_clay seed=20260826 start=tutorial`,
LaunchServices foreground, nice 0, frame cap 60, Godot 4.6.2-stable, macOS), a fresh game each, all six on
the uncoached mission (58's text). The batch the director asked for at the milestones: it measures the
shortened smelt card (8c6fc9f4), the smelt ring to the coal seam (D0486) and the refusal slot (D0488)
together, on the opening with the rig (D0485) and D2 (D0492). Supervised (`playtest/supervisor.py`,
30 s / 150 s). Journals `docs/playtests/2026-09-07_stranger{76..81}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{76..81}/` (local).

**Classification (`stranger.py validate`, never the reports):** 76-81 all VALID, all six quit cleanly.

| | first ore (pack) | coal in pack | two ingots | delivered | drill set | bursts |
|---|---|---|---|---|---|---|
| S76 | 28.8 s (burst 18) | never | -- | -- | -- | 57 |
| S77 | 2.2 s (1) | 13.1 s (7) | 46.7 s (29) | **54.0 s (37): the rig paid the drill** | RMB on the vein itself, silent | 46 |
| S78 | 1.3 s (1) | never | -- | -- | -- | 38 |
| S79 | 17.7 s (10) | never | -- | -- | -- | 34 |
| S80 | 4.3 s (2) | 19.8 s (10) | -- | -- | -- | 47 |
| S81 | 4.0 s (4) | never | -- | -- | -- | 41 |

**Ore 6 of 6** (1.3-28.8 s; four in the first 5 s). **Coal 2 of 6. Smelt 1 of 6. Deliver 1 of 6: S77 is the
first stranger the rig has ever paid** (two ingots at 46.7 s, the drill in hand at 54.0 s, 45 s after the
first ore). **BUILD 0 of 6.** Against 70-75 (ore 6 of 6, smelt 0 of 6) the smelt rung moved from none to one
and the coal from none in the pack to two.

## What the frames and receipts show

- **The coal seam is not read as coal. Four of six never held any.** S79's `frame_0013.png` (21.0 s): the body
  stands ON the seam's metre with the WHITE RING and its outline under its own feet, the card reading "the
  black seam right of you"; the next burst is a 60-tick stride right, to cell 185, and the run never comes
  back. In that frame the seam metre (cells 148-151) and the shaft's open mouth two metres right of it are
  the same black: a solid black metre beside a black hole. Three reports say they "pointed at dark areas"
  and got NOTHING THERE or TOO FAR DOWN -- the receipts agree: S79's presses at (152,92), (164,80), (157,89),
  (148,97); S78's at (146,103), (146,95), (158,86); S81's the same shape. None on the seam's four rows. The
  hover card over the seam did not help: `Inspector._describe_terrain` names ANY solid cell with a deposit
  "Ore Vein -- N ore" (S77's `frame_0044.png` shows the card over the shaft's vein; the seam's record has
  `deposit: 13`, so its card read "Ore Vein -- 13 ore"). S80 saw "Coal Lode -- 13 left" only AFTER cutting
  into the seam from above at 19.8 s, when the exposed face became a lode. **Fixed (D0493):** the card over a
  solid metre whose material record is `kind: fuel` reads "Coal Seam -- N coal -- hold to cut it; the forge
  burns it". The seam's look (one black metre that reads as shadow) stays the director's.
- **The two who found coal dug INTO the seam from its top, by accident of standing there.** S77 at 13.1 s from
  cell 147: a 120-tick hold at (620,470) snapped to (145,80) and broke 49 cells (clay and the seam's edge;
  coal in the pack), then fell into the adit. S80 at 19.8 s from cell 151, standing on the seam, held on
  (152,81) under its own feet -- CUT THROUGH -- and came up with coal 3, then 9, then 18. Neither pressed
  the ring on purpose; both were standing on the seam because it is the second stride's landing.
- **S80 had ore 7 and coal 9 beside the forge at 30.6 s and pressed nothing.** Burst 15: A for 60 ticks to cell
  115, one metre from the forge's column; burst 16: D back to 151. Its first Q was at 37.9 s from cell 153
  (5.7 m off, DROPPED on the floor), then Tab, Space, Q again at 153, then right to 187, 223, 254. The ring
  was on the forge the whole time. Cause by the receipts: the drop was pressed where the stranger stood
  when it thought of it, not where the ring was; the report calls the forge "unreachable".
- **S76's forty bursts to the number key.** Ore at 28.8 s (its first press at 1.2 s was 6 m left, on the
  tree's foot, TOO FAR; then a 10 m walk left and back). On the smelt rung it pressed Q eleven times at cells
  150-173, every drop to the floor or into the SHAFT forge's range (WRONG STACK at 67.0 s: "you dropped clay;
  the machine beside you takes ore" -- the shaft forge, 4 m left and 3 m down of cell 173), and learned the
  slot keys from that lesson at burst 41. The card said "hold each stack" -- the two-line compression of
  8c6fc9f4. **Fixed (D0493):** "by it, press each stack's NUMBER then [DROP]; the ingots come to you", two
  lines, the last clause kept (the objective-line suite's pin).
- **S77's BUILD: RMB on the vein, silent.** With the drill in hand at 58.3 s, from the adit at (148,91), RMB at
  (720,360) -> the shaft's vein metre (39,22), solid; the ring stood on the open mouth above it; the hover
  card over the vein said "stand a Drill just above it". The press placed nothing and said nothing: BUILD had
  refusals for `far` and `here` only (D0470). S77 waited two bursts for the drill to work, then quit ("no
  visual feedback"). **Fixed (D0493):** `build_rock` -- IN THE ROCK -- "a machine stands in the open, not
  inside rock. Point at the open metre in the WHITE RING, right above the vein, then press [BUILD]."
- **The slot (D0488) cannot be isolated in this batch.** Every seat met refusals (far, air, far_below,
  cut_through) and the slot's words are the lessons' headlines; the reports quote the headlines and cannot
  say which plate they read them from. No seat's receipts show a refusal repeated on the same cell after a
  release, which is the case the slot exists for. It measures nothing here and costs nothing.
- **The strides, again.** S79 went 130 -> 148 -> 185 -> 221 -> 254 in four D bursts; S80 and S81 also ended
  at (254,84), a hollow 31 m right of the pad; S76 at 173 and 207. The seam at +5 m is inside the first
  stride; the forge at -3 m is one stride the other way. Recorded for the director (T035), not changed.

## What this decides

The opening's first rung holds (6 of 6, ore in under 5 s for four). The smelt rung is the wall: 1 of 6, and
the wall is the coal's legibility, not the forge's -- the metre is black beside a black hole, its card called
it ore, and the card's "right of you" is true only at the spawn. Three fixes taken with frame-and-input
causes (D0493): the seam's card, the smelt card's number key, BUILD's IN THE ROCK. The seam's look and the
stride are the director's. The next batch after the next discoverability change; the rig's first payment to
a stranger (S77, 54 s) is the milestone this build was for.
