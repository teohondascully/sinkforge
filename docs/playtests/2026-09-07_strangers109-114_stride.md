# Screen-led playtest, strangers 109-114 in parallel -- 2026-09-07 late, on af086f66 (D0513-D0519), THE SHIPPED SEED, the batch's snapshot

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once through `playtest/batch.py`, seats pinned
(build af086f66 clean; boot line `site=shallow_clay seed=20260826 start=tutorial`; every seat opened the
batch's fresh-game snapshot `snapshot_af086f66_0.json`, D0519, first frame byte-identical to a generated
one; LaunchServices foreground, nice 0, frame cap 60, Godot 4.6.2-stable, macOS), all six on the uncoached
mission (58's text). Measures D0513 (a drop with its eater in sight but out of reach is refused), D0515
(the cards lead with WALK and STAND), D0517 (the FED receipt, the TOO FAR lesson that points, the plate let
go), D0516 (the floor-ambiguity check). **Six seats booted in 5.4 s wall** (8.1 s for 103-108; the snapshot
4.1 s once). Supervised; no seat replaced; S111's AGENT stalled at burst 40 and was resumed from its
transcript (the seat had answered; the resumed agent wrote the report). Journals
`docs/playtests/2026-09-07_stranger{109..114}_journal.md`.

**Classification (`stranger.py validate`):** 109-114 all VALID. `Invariants` reports in the seat logs:
0, 0, 0, 0, 0, 0 (38 to 168 a seat in 103-108; D0516).

| | four ore | coal in pack | two ingots | delivered | bursts | where it ended |
|---|---|---|---|---|---|---|
| S109 | 2.2 s | 7.5 s | -- | -- | 35 | Q from 130 and 128, the band's edge, "TOO FAR" |
| S110 | 1.3 s | -- | -- | -- | 48 | read "9 m to your LEFT" at 188 and searched 20 bursts without walking it |
| S111 | 7.4 s | 16.5 s | 24.3 s | 28.6 s | 43 | the drill in the pack; RMB at the shaft mouth from 171, 3.5 m off |
| S112 | 2.2 s | 11.4 s | -- | -- | 35 | read "6 m to your RIGHT"; dug down; never within 2.7 m of the forge |
| S113 | 2.2 s | 18.1 s | 40.7 s | -- | 31 | quit on the checkmark card, the deliver card a second away |
| S114 | 69.3 s | 31.8 s | -- | -- | 50 | dug the WAY DOWN's square for ore; "4 m to your LEFT" read as another forge |

**Four ore 6 of 6. Coal 5 of 6. Two ingots 2 of 6 (1 in 103-108). Delivered 1 of 6 (0). S111 reached the
drill at 28.6 s, the fastest run the harness has recorded.** Nobody lost a stack: zero floor drops within
sight of a forge (44 in 103-108), and no journal says "disappeared" or "respawned".

## What the frames and receipts show

- **D0513 and D0517 read as designed.** S110 quoted "TOO FAR — the FORGE that takes ore is 9 m to your
  LEFT", S112 "6 m to your RIGHT", S114 "4 m to your LEFT"; S113 quoted the receipt "3 coal → forge" and
  "7 ore → forge" in the timeline; S113's clay drop beside the forge drew WRONG STACK and they switched
  stacks. The stack stayed in the pack every time (`pack` unchanged at every refused Q).
- **The wall is where the body stops, and that is the mission's own stride.** The receipts give the body
  36 cells per 60-tick press and 17-18 per 30-tick press, 9 m/s, exactly. The forge accepts a drop within
  3.2 m of the body's centre to its cell's centre; with the machine at foot level that is a band 22 cells
  wide (cells 107-128 at the surface). The mission text says "A short walk (30 ticks) moves the figure a
  few body-lengths" and "keep bursts 30 to 120 ticks": a 30-tick press is 4.4 m, so a stranger lands in a
  5.4 m band by luck of burst length and then presses Q where it stands. S109 stood at 130 then 128 (the
  band's last cell: a headless probe passes the reach test at px 514 and fails at 515; the receipts give the
  cell, not the pixel; `frame_0014`'s slot reads TOO FAR); S111 aimed the drill at
  the mouth from 171 (14 cells, 3.5 m); S112 and S114 pressed from the spawn. The ones who got through
  stood at 123 (S111, walked left until the forge stopped them) and 111 (S113). A person taps a key; the
  adapter allows a 5-tick tap (0.7 m) and the mission never says what a tick moves. Fixed in the template
  (D0520); this batch's null on the drop is the instrument's, and is re-measured next.
- **"9 m to your LEFT" is honest and not actionable for these agents.** Three read it correctly; none
  converted metres into ticks, because nothing tells them the speed. Same fix.
- **S113 quit on the ceremony.** `frame_0030` shows "✓ Forge 2 ingots" with the state already on the
  deliver rung; the deliver card replaced it one burst later. The mission says quit when the game says it
  is done; the checkmark card said it. A one-burst wait would have shown the next card.
- **S114's first rung took 69 s** (35 bursts): the first cut came up clay, "NOT ORE — that was clay"
  taught the distinction, and S114 then dug THE WAY DOWN's white square for the ore instead of the vein
  in the ring. One seat; the same white-square confusion S105 had in 103-108.
- **S111's build rung.** "TOO FAR — the ring is past your reach" from 171 and from 165 aiming at 222.
  The mouth ring at (157,86) is reachable from the lip only from cells 151-164 (its centre is 44 px below
  the body's). The stride again.
- **D0516 in the field:** zero ambiguity reports in six seats; the check's subject is a surface the feet
  reached, and the opening's pockets under the pad are 12-20 rows down.

## What changed because of this batch

- **D0520** the mission template says what a tick moves: a tap of 5 ticks is a third of a body length,
  30 ticks two body lengths, 60 ticks four and a half; "to stand beside something, tap". The adapter's
  calibration, not the game's coaching: a person watching the body move has this; a stranger reading
  stills does not.

## For the director

The stride (T035) is measured: 9 m/s, 36 cells a second-long press, the reach 3.2 m centre to centre. The
question is whether a HUMAN feels the same overshoot; the strangers' overshoot is the burst's, now
calibrated. The layout and D3-D6 stand as before.
