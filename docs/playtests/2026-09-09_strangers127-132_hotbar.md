# Screen-led playtest, strangers 127-132 in parallel -- 2026-09-09, on `60da8d1d`, THE SHIPPED SEED, the batch's snapshot

**Who played:** six fresh-context agents (Claude Haiku 4.5) at once through `playtest/batch.py`, launched
from a clean checkout at `60da8d1d`; boot line `site=shallow_clay seed=20260826 start=tutorial`; every seat
opened `snapshot_60da8d1d_0.json` (sha256 `582665420cae`, D0519); six seats booted in **5.0 s wall**, the
snapshot generated in 3.7 s. LaunchServices foreground, nice 0, frame cap 60, Godot 4.6.2-stable, macOS.
Mission sha256 `6eddb85c4481...`, identical for all six and byte-identical to
`docs/playtests/MISSION_TEMPLATE.md` under the two substitutions the template itself prescribes
(`SESSION_DIR`, `GOAL_PARAGRAPH` = the uncoached goal); its HTML comments were stripped because they carry
ledger ids and the list of goals used so far, which must not reach a blind stranger. Supervised; no seat
replaced; no agent stalled. Journals `docs/playtests/2026-09-09_stranger{127..132}_journal.md`.

**This batch is the test of D0529 (THE EDGE lesson) and D0530 (the acknowledged rung's card), which
shipped unmeasured.** The game differs from 121-126's `2fe07582` by those two and by the performance work
of D0535-D0543, which changed no simulation and no picture.

**Classification (`stranger.py validate`):** 127-132 all **VALID**. `Invariants` reports: 0 in all six
seat logs. `ERROR:` lines: 0 in all six.

| | four ore | coal in pack | two ingots | delivered | drill placed | bursts | where it ended |
|---|---|---|---|---|---|---|---|
| S127 | 1.3 s | 8.4 s | 25.1 s | 34.8 s | -- | 36 | the world's east edge, drill in the pack, two BUILD refusals from cell 254 |
| S128 | 2.2 s | 11.7 s | 19.2 s | -- | -- | 38 | beside the RIG at TOO FAR; ingots dropped at its feet |
| S129 | 4.3 s | 63.1 s | -- | -- | -- | 45 | 50 m down, coal reached only at 63 s, out of budget |
| S130 | 2.2 s | -- | -- | -- | -- | 41 | never reached coal: TOO FAR, then TOO FAR DOWN |
| S131 | 3.2 s | 8.5 s | -- | -- | -- | 37 | circling three forges, feeding the wrong stack |
| S132 | 2.2 s | 20.1 s | 33.1 s | -- | -- | 40 | beside the RIG at TOO FAR, 12+ attempts |

**Four ore 6 of 6. Coal 5 of 6. Two ingots 3 of 6. Delivered 1 of 6. The drill placed 0 of 6.**
Against 121-126 (6/6, 5/6, 3/6, 3/6, 2/6) this is the same through smelting and lower after it. **Six
seats cannot separate 3/6 from 1/6, and no regression is claimed here** -- what the receipts do establish
is a mechanism that was invisible in every earlier batch, below.

## The finding: the hotbar renumbers itself under the player, and the smelt rung is what triggers it

`state.slots` is the bar's own order -- "slot N is key N" (`playtest/seat.gd:261`). Taken across a run it
is not stable:

| seat | burst | slots (= keys 1,2,3) | what changed |
|---|---|---|---|
| S131 | 3 | `ore, coal, clay` | 2 = coal |
| S131 | 12 | `coal, clay` | ore drained; **everything shifts down**, 1 = coal |
| S131 | 23 | `clay, coal` | coal re-acquired; **1 and 2 have swapped** |
| S132 | 14 | `ore, clay, coal` | 3 = coal |
| S132 | 21 | `clay, ingot` | 2 = ingot |
| S132 | 24 | `ingot, clay` | **swapped again**, 1 = ingot |

The mechanism is in the source and is deliberate. `sim/items/pack.gd:16-18`: "INSERTION ORDER IS STATE
HERE, on purpose: the hotbar draws stacks in the order they were first picked up." And `remove()` at
`sim/items/pack.gd:47`: "A stack drained to 0 leaves the pack, **so the hotbar never shows an empty
slot**." The comment names the benefit; the cost is that draining a stack renumbers every stack after it,
and re-acquiring that item appends it at the END rather than restoring its number.

**The rung that asks the player to drain stacks into a machine is the rung that renumbers their keys**,
and the card's own instruction is "press each stack's NUMBER and Q". Four of six seats hit this:

- **S129's receipts contradict its own report** and show it exactly. The agent reported "forge consumed
  7 ore, produced 1 Clay". The pack says otherwise: burst 2 gains `clay:1` **and** `ore:7` from the same
  first cut; burst 21 `ore -7` (fed); burst 22 `clay -1` (**fed clay, the wrong stack**); bursts 24/33/35
  each `clay +1`, which is mining, not forging. Nothing produced clay. It fed the wrong number.
- **S128:** "For a long time I tried to deliver stack 1 (clay) before realizing the ingots were in stack 2."
- **S131:** "unclear which number key corresponded to which resource... items seemed to reorder or my
  understanding was wrong." Its slots did reorder, twice.
- **S132:** 12+ delivery attempts; its ingot moved from key 2 to key 1 at burst 24.

**The one seat that delivered is the one whose bar never reordered.** S127 held at most two stacks the
entire run (`ore` -> `ore,coal` -> `coal` -> `[]` -> `ingot` -> `drill`) and carried **zero clay**. Every
seat that accumulated clay failed to deliver. That is 6 seats, not a proof, but the mechanism is in the
source and the wrong-stack feed is on the receipt.

## D0529, THE EDGE lesson: fires exactly on its trigger, and mostly works

`view/hud/hints.gd:168-169` fires the lesson within `EDGE_CELLS = 4` of either boundary. Measured against
the body cell rather than the lesson field (the field is sticky -- it holds the last hint shown, so it
cannot time an entry):

| seat | min x | max x | bursts in the left band (<4) | in the right band (>=252) | edge lesson seen |
|---|---|---|---|---|---|
| S127 | 2 | 254 | 9 | 27,30,31,33,34,35,36 | left **and** right |
| S128 | 93 | 250 | -- | -- | none |
| S129 | 76 | 194 | -- | -- | none |
| S130 | 76 | 254 | -- | 23,24,25 | right |
| S131 | 2 | 202 | 9,21,22,23,24 | -- | left |
| S132 | 130 | 184 | -- | -- | none |

**Perfect correspondence: every seat that entered a band saw the lesson, no seat outside a band saw one,
no misses and no false positives.** Whether it turns a player around: **S130 and S131 left the band after
it and did not return to it; S127 did not** -- it entered at burst 27 and spent seven of its last ten
bursts there, ending on the east edge with two BUILD refusals aimed 88 cells (22 m) back at the work site.
Against 121-126, where two of the three seats that reached cell 254 ended there dropping stacks, this is
a better outcome from the same trigger, on three seats.

## D0530, the acknowledged rung's card: one observation, and it is the right one

Only S127 finished a rung past `deliver`, so the post-delivery ceremony card was seen **once**. It did not
end the run: S127 read "Build the line", kept its drill and played fifteen more bursts. In 121-126 two of
the three seats that finished a rung on a ceremony card read the ceremony as the end. **No seat in this
batch quit on a card.** One seat reaching the card is one observation, not a measurement of D0530.

## The other walls, unchanged or new

- **The RIG's reach, twice (S128, S132).** Both stood beside a ringed RIG, pressed the number and Q, and
  got TOO FAR repeatedly. `Reach.NUM/DEN` is 16/5 m = 3.2 m at legacy's cell, which is **one metre** in
  this world (`core/reach.gd:13-15`). S132: "the white ring marker shows the target exists, but all
  attempts... resulted in TOO FAR." S128 concluded a body length "gave no clear feedback about what
  distance that actually represented". D0521 draws the ring solid when in reach; neither seat reported
  reading that state, which is worth a look at what the ring shows at the RIG specifically.
- **Coal is the new floor (S130, and S129 at 63 s).** S130 never obtained coal in 41 bursts: TOO FAR at
  the seam, then TOO FAR DOWN with "dig at the white square first", then NOTHING THERE at the squares it
  chose. Refusals across the batch: `air` 14, `far` 6, `sight` 2, `build_far` 2.
- **Three forges, no way to tell them apart (S131).** "Multiple forges existed but no clear labels
  distinguishing ore-forge vs coal-forge"; it read "TOO FAR — the FORGE that takes ore is 8 m to your
  LEFT" and reported the message not updating as it walked.

## For the director

The opening's first rung is solid: four ore 6 of 6, fastest at 1.3 s. What this batch found is not a
lesson-wording problem but an **identity problem in the hotbar** -- the number a player learns stops being
true exactly when they use a stack, which is what smelting is. It is a deliberate design choice with an
unpriced cost, and it is the first finding in six batches that explains failures at three different rungs
at once (feeding the forge, feeding the rig, selecting the drill).

D0529 works. D0530 was seen once and behaved. Neither is the thing standing between a stranger and the
drill.

**Not claimed:** any regression from 3/6 to 1/6 delivered (six seats cannot separate those); any
measurement of D0530 (one observation); that the hotbar is the sole cause of the delivery failures (the
RIG's reach feedback is a live and separate suspect).
