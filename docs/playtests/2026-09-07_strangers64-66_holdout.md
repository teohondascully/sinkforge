# Screen-led playtest, strangers 64-66 in parallel -- 2026-09-07, on 77dd4655, THE HOLDOUT SEED, a fresh game

**Who played:** three fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build 77dd4655
clean; `--seed=20260907`, boot line `site=shallow_clay seed=20260907 start=tutorial`; LaunchServices
foreground, nice 0, frame cap 60, Godot 4.6.2-stable, macOS), a fresh game each, all three on the
uncoached mission (58's text). The second half of the director's first-rung gate: 61-63 went 3 of 3 on
the shipped seed on this build; the rule asks for a holdout before the opening is called stable.
Supervised. Journals `docs/playtests/2026-09-07_stranger{64,65,66}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{64,65,66}/` (local).

**Classification (`stranger.py validate`):** 64, 65, 66 all VALID. **First rung by the pack: 3 of 3, at
8.7 s, 7.0 s and 4.3 s.** With 61-63 that is two consecutive valid 3-of-3 batches on two seeds: **the
shipped-seed first-rung gate passes on the D0474 build.** Six of six against 58-60's two of three.

## The first rung, press by press

The world differs from the shipped seed beyond the pad (the tree stands at the same six metres; the
sinkhole's mouth is at cell ~199, dx +17 m, against 190 on the shipped seed). Cells as in 61-63's report.

| | first input | raw cell | refusal (aim / body) | broke | four ore |
|---|---|---|---|---|---|
| S64 | burst 1, 2.2 s: 120 t LMB at (420,400) | (102,80): the surface 7 m left, past the trees | **far** (102,80) / (130,75); TOO FAR | 0 | |
| | bursts 2-4: A 30 t, D 20 t, D 15 t (a 4.5 m stride left and two back: cell 112, 123, 131) | | | | |
| | burst 5, 8.7 s: 120 t LMB at (540,400) | ≈(119,79/80): the forge's top | none: snapped to the vein | 16 cells (122-129, 80-82) | **8.7 s**, 9 ore |
| S65 | burst 2, 2.8 s: 120 t LMB at (640,410) | (130,81): **the ground under its own feet** (the screen's centre) | `air` after the cut; NOT ORE (mined_wrong) | 9 cells (128-132, 80-82); the body dropped a cell into its hole | |
| | burst 3, 4.9 s: 120 t LMB at (640,380) | (130,78): its own body | `air`; NOT ORE | 0 | |
| | burst 4, 7.0 s: 120 t LMB at (610,420) | ≈(126,82): the vein under the face | none | 16 cells (124-128, 80-84) | **7.0 s**, 9 ore |
| S66 | burst 1, 2.2 s: 120 t LMB at (550,405) | (118,80): **the forge's top cell, in reach, open** | `air`; THAT IS A MACHINE | 0 | |
| | burst 2, 4.3 s: 120 t LMB at (540,420) | ≈(118,82): the pocket below it, **out of reach** | none: snapped to the vein | 16 cells (121-128, 80-82) | **4.3 s**, 11 ore |

Nobody walked before the first press except S64 after a refusal. Under the director's causes the three
refused openings are: S64 pointer/aim (7 m left, at the trees' foot), S65 pointer/aim (the screen's
centre, twice), S66 pointer/aim on the forge's own cell. Every eventual success came through the snap
again; none pointed at a visible reachable cell.

## What the frames and receipts show

- **The forge's column is a coin flip on the pointed cell's reach.** S66's two presses were 15 px apart
  on the same column: the forge's top cell (118,80) is inside the reach by the game's own measure (the receipt aims it
  exactly), and legacy's rule for an open cell in reach holds ("precise in-reach hovering is unchanged":
  the aim stays exact, refused `air`, THAT IS A MACHINE); the pocket cell (118,82) is out of reach, so
  the reach-wide snap carried it to the vein. Legacy's seam, verbatim (`legacy/scenes/main.gd`
  `_effective_aim`), not D0474's; recorded, not changed.
- **The smelt rung: 1 of 3.** S64 dropped from cell 125, 1.5 m right of the forge's column, and had two
  ingots at 17.4 s, four by 21.4 s. S65 and S66 pressed Q at the spawn
  cell (S66 three times, once as a 300 t hold; DROPPED on screen in full, `frame_0007.png`), then **walked
  right in 60-120 t strides and went into the sinkhole at cell 199 within 30 s** (S65 at burst 15, 29.8 s;
  S66 at burst 14, 29.5 s), 32 m down by the end, S65 pressing Q at (206,206) beside the guide's
  distance speck, which its report calls "the forge at SHALE REACH". Nine strangers have ended in a
  sinkhole now (cell 190 on the shipped seed, 199 here). The keepout is D0388's 12 m about the spawn
  (`data/strata/shallow_clay.yaml`, `sinkhole.keepout_m`), the mouth's half-width 3 m, the strangers'
  stride 9 m a second: the second stride east lands on the mouth on both seeds.
- **The stale dig mark, a third time.** S64's burst 1 (2.2 s) was refused `far` at (102,80) and painted
  it; at burst 28 (50.0 s), body at cell 101, a hold on the air right of the tree (refused `air`,
  NOTHING THERE on screen) dug 9 cells at (100-104, 80-82) -- the mark, now in reach and in sight. At
  burst 35 S64 walked onto that hole and fell 18 m. With 62 and 63 that is three of six valid runs.
- **Wood: 0 of 3.** S64 cut 8 trunk cells at chest height (bursts 12-13: the same pixel refused `air` one
  burst and cut the trunk the next -- (590,345) sits on the trunk's right edge, and the camera's rest
  differs by a pixel between bursts), then held on the gap seven times over 30 s (NOTHING THERE, CUT
  THROUGH) with the seven cells left standing behind the body's legs; its report counts "17 cuts". The
  cut mark stood over the crown here too.

## What this decides

The first-rung gate passes: two consecutive valid 3-of-3 batches (61-63 shipped, 64-66 holdout) with four
ore by ordinary input at 2.2-11.3 s, no injection, no semantic command. The forge rung is 3 of 6 across
the two batches (15.9, 30.1, 17.4 s), wood 1 of 6 (47.5 s), BUILD reached once (47.5 s), finished never.
Taken now with frame-and-input causes: the stale dig mark (three runs) and the cut mark over a tree
(three frames). For the director: the sinkhole mouths one stride past the pad, the smelt lesson's BESIDE,
the Q at the spawn cell (4 of 6 first drops), the trunk behind the body's legs, the stride.
