# P1 — guidance quietness, after-frames

**Paired with `../baseline/`, which is immutable.** These are the same moments, same seed (1337), same
capture path, after each `P1` strike. **Never regenerate `../baseline/`** — a "before" that moves with the
work is not a before, and the mistake is easy: I overwrote three of them once and restored from
`975071f` before they became evidence.

| frame | what changed |
|---|---|
| `_moment_sapling.png` | **strike 1.** The SAPLING lesson no longer draws under the TOPSOIL ceremony. The plate finishes; the bubble arrives alone. Compare `../baseline/_moment_sapling.png`, where the bubble sits on top of the ceremony's title. |
| `_moment_boot.png` | unchanged by strike 1 by design — no lesson is up at t=0. Kept so the pair is complete. |
| `_moment_map.png` | **strike 1.** The arrival plate is held while the big map is open instead of drawn across it. Compare `../baseline/_moment_map.png`, where the plate crosses the map's `TOPSOIL` label and its `0 m` reading. |
| `_moment_delve.png` | **strike 1.** Same rule underground: the GRAPPLE lesson no longer shares pixels with `10 METRES DOWN / THE CLAYBAND`. |

| `_moment_quiet.png` | **strike 3 / `UI-08`.** A new moment: the surface with the announce channel empty and nothing hovered. There is no baseline pair for it, deliberately — **`boot` cannot serve as a quiet frame because the TOPSOIL ceremony is up on frame one**, so the game's own opening shot contains an interrupt and every judgement made on it judges the interrupt. |

## The quiet frame, read

**Six surfaces remain, and every one of them was chosen rather than timed** — which is the whole point of
having this frame: there is nothing left to blame the composition on.

    top-left      0 m TOPSOIL                          ambient
    top-centre    Mine 4 ore / Dig ore — hold LMB…     active  <- the largest, brightest thing on screen
    top-right     FORGED 0                             ambient
    centre        aim ring + pointer                   active
    bottom-centre Wood Pickaxe + hotbar                ambient
    bottom-left   F hook · Q drop · E pack · M map     ambient

**The objective slab is now the loudest element in the game's opening frame**, and it is legitimately
there — it is the first lesson, and T2.1's shipped subtraction retires the slab *after* that. Whether the
first lesson should be that big is a composition question, not a collision one, and this frame is what a
a later look should answer it on.

**What the world does now that the interface is out of its way:** the sun, the gearwheel landmark, the
ruin arch, the tree, both forges, the cave mouth and the ore glints all read. The subsoil does not — it is
one undifferentiated brown field from the grass line to the bottom of the frame, which is `SF-02`/`TR-03`
and `c1`'s tooth, not `P1`'s.

## What strike 1 did NOT fix, visible in `_moment_sapling.png`

The bubble now has the frame to itself and **is still large enough to cover the tree the lesson is about.**
That is `UI-06` (a tutorial maximum footprint) and `UI-05` (one action plus one immediate consequence —
*"It grows into a NEW TREE: wood is renewable"* is a second concept competing with the instruction).
**Recorded here rather than folded into strike 1's claim**, because "the frame is quieter" and "the lesson
is the right size" are different claims and only the first one has been earned.

**Strikes 2 and 3 then did both**: the sapling bubble is two lines instead of three (45px against a 61px
ceiling), and the renewability sentence now arrives on the plant that earns it.
