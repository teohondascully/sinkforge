# Screen-led playtest, strangers 58-60 in parallel -- 2026-09-07, on 8612f74a, THE SHIPPED SEED, a fresh game

**Who played:** three fresh-context agents (Claude Haiku 4.5) at once, seats pinned (build 8612f74a
clean: D0464-D0473; boot line `site=shallow_clay seed=20260826 start=tutorial`, LaunchServices
foreground, frame cap 60, Godot 4.6.2, macOS), a fresh game each -- the first shipped-seed batch since
D0464 -- with the three missions of 34-36 (58 uncoached; 59 wood; 60 down-and-back). Supervised. Journals
`docs/playtests/2026-09-07_stranger{58,59,60}_journal.md`; artifacts
`tests/body/recordings/playtest_2026-09-07_stranger{58,59,60}/` (local).

**Classification:** 58, 59, 60 all VALID. **First rung by the pack: 2 of 3, at 12.8 s and 16.8 s;
S60 never** (sixty bursts, five clay, "never found a single ore"). Against 34-39's six of six at
1.3-21.6 s (five under 6 s) on the build before D0464. **The opening regressed, and the cause is
D0464's metre.**

## Timeline (game seconds, from the receipts)

| | S58 uncoached | S59 wood | S60 down-and-back |
|---|---|---|---|
| First press | 2.2 s, (540,415): **"air"** | 2.2 s, (530,430): **"air"** | 2.2 s, (540,420): **"air"** |
| Four ore | **12.8 s** (the fourth press, 16 cells) | **16.8 s** | never |
| Two ingots | 36.0 s (five in all) | 42.5 s (ten) | -- |
| Wood | 80.6 s | never: leaves, then coal and clay under two trees | -- |
| End | BUILD, 91 s: RMB on the ring three times, no drill | wood, 105 s | mine, 104 s, five clay |

## What the frames and receipts show

- **All three first presses landed where every first press since D0449 has: the forge's open pocket,
  80 px left of the ring, 3.9 m from the body.** Before D0464 that press snapped to the vein 2.3 m from
  the cursor (legacy's reach-wide tolerance) and the first rung came in 1.3-2.2 s; on D0464 the pointed
  cell is open air out of reach, nothing solid stands within a metre of the cursor, and the hold is
  refused "air". By hand on 8612f74a: aim (117, 81), open, refused; on the D0474 tree the same two presses
  cut 5 and 11 ore. **D0474:** the metre applies to a pointed ROCK out of reach (stranger 43's case);
  open air out of reach keeps legacy's reach. Recorded in `docs/CORRECTIONS.md`.
- **The forge's bubble question stands as it was:** the pointer goes to the forge's column first
  (3 of 3 again, 13 of 20 since D0449); the snap is what turned that press into ore, and D0474 gives it
  back. Whether to quiet the need-bubble and nameplate during the mine rung is still the director's.
- **S58 reached BUILD from a fresh game at 80.6 s** -- the first fresh-game stranger to reach it since
  the variant began -- and pressed RMB on the ring three times with the ingot or the wood selected, with
  no drill in hand (D0472 keeps that press silent by design; the how-to's first clause is dig).
- **S59's wood: leaves, then the ground.** "NOT ORE" on the leaves, the forge refused them, then forty
  bursts of coal and clay under two trees. The trunk's two cells against the pointer, as in 34-42.

## What this decides

D0474 on these frames, by hand confirmed. The opening's next read is a shipped-seed batch on the D0474
build; the run closes here with that as the first item of the next session.
