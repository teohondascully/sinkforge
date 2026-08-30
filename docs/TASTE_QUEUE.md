# Taste queue

Feel, visual, and design judgment calls, batched for the director in one sitting. Never mixed with
correctness — that goes through the gates, not here. `CONTEXT.md`, "Review bandwidth" and "Playable
fixtures"; format detail in `docs/ARCHITECTURE.md` §6.

Every entry is a playable fixture ID and exactly one question. If a fixture needs two questions, it
should be two fixtures.

```
F### · <fixture name / what it isolates> · <one question>
```

---

Empty. No fixtures exist yet — `harness/` and `scenarios/` are skeletons, and a fixture needs a real
driver and scenario format under it. First entries expected once the stage-4 fixtures land
(`ONBOARDING.md`, item 4: the hostile chamber and a rope traversal segment).

---

## Slice 0 (D0189) — the legacy palette, now on the world

Not fixtures in the `F###` sense (no fixture format exists yet); these are the two visual judgment calls
Slice 0 produced that are the director's, not the engineer's.

**T001 · `ore_copper` reads SILVER, not copper.** It maps to legacy's `ore`, which is legacy's GENERIC
ore-in-rock record — a grey host with a silvery-white fleck. Legacy never authored a copper-specific
material, so there is nothing to lift. It was taken unaltered rather than retinted, because inventing a
copper hue and calling it a port would hide new art inside a migration. *Question: retint it toward
copper, or is a neutral ore-grey correct for the tier?*

**T002 · The band tint is at 0.10 and is nearly invisible.** Legacy's 8 band colours were authored as
ANNOUNCEMENT colours — type on a dark HUD plate, every one between 0.44 and 0.96 in its brightest channel.
Used as a background fill at full strength they wash the world out completely, so the scene leans the
background only 10% toward the current band. That makes depth-as-colour almost unreadable, which may be
right (the band belongs in a HUD readout at Slice 4, not in the dirt) or may be too timid. *Question:
raise the tint, or leave the world neutral and let the band live in the HUD?*

---

## Slice 1 (D0195) — the mining verb

**T003 · Mining times: the shallow end is legacy's exactly, the deep end is twice as fast.** The two
codebases do not share a hardness scale — legacy's numbers ARE seconds, this project's are unitless — and
no single factor maps one onto the other. `TICKS_PER_HARDNESS = 17` is derived from the shallow end, where
a player starts, and lands clay at 0.283s against legacy earth's 0.28s and hardrock at 0.850s against
legacy stone's 0.850s (exact, and not fitted to). The deep end falls out faster because this project's
hardness scale compresses there:

| material | hardness | breaks in | legacy counterpart |
|---|---|---|---|
| clay | 1.0 | **0.283 s** | earth 0.28 s |
| glimmer | 1.0 | 0.283 s | — (authored here) |
| coal | 1.5 | 0.417 s | coal 0.90 s |
| ore_copper | 2.0 | 0.567 s | ore 0.90 s |
| hardrock | 3.0 | **0.850 s** | stone 0.850 s |
| ore_iron | 3.5 | 0.983 s | iron 3.00 s |
| deepstone | 5.0 | 1.417 s | deepslate 2.80 s |

Rhythm shortens consecutive breaks by up to 1.6x on top of this (deepstone measured at 85, 71, 62 ticks
across three in a row). *Question: is the deep end supposed to be this fast? The alternative is to stop
treating the two scales as relatable at all and author a `break_seconds` per material directly — which is
more honest but abandons the one anchor that currently ties this build's feel to legacy's.*

**Only playing it answers this.** The agent trace cannot: it has no sense of whether a 1.4-second hold on
deepstone is a satisfying commitment or a chore, and that is precisely the axis the whole migration is
about.

**T004 · The bite radius: 0, 1, 2 or 3.** New with D0200, and it partly re-frames T003 above — that table
measures seconds **per cell**, and one blow no longer removes one cell. What a radius costs, measured:

| radius | cells per blow | as a fraction of a square metre | rate against legacy | 24-cell shaft takes |
|---|---|---|---|---|
| 0 (Slice 1) | 1 | 0.06 m² | **0.06x** | 991 ticks (16.5 s) |
| 1 | 5 | 0.31 m² | 0.31x | 505 ticks (8.4 s) |
| **2 (shipped)** | **13** | **0.81 m²** | **0.80x** | **242 ticks (4.0 s)** |
| 3 | 29 | 1.81 m² | 1.79x | 152 ticks (2.5 s) |

Legacy is the 1.00x row that does not exist here: its 32px cell IS one square metre and one charge removes
it. Radius 2 is the largest disc that stays under that, which is where the default came from — but "closest
to legacy" is a derivation, not a ruling. Legacy was a factory game with a rig to feed; this is a descent
game, and the right answer may well be that digging should feel *faster* than legacy rather than equal to
it, in which case radius 3 is the honest choice and the metre stops being the anchor.

*Question: sweep `--bite=0/1/2/3` in `--play` and say which one feels like mining rather than like waiting
or like a cheat.* Radius 0 is exactly the build that was played and reported as "weird", so it is the
control and it should feel worse.

**Two things to watch that no measurement covers.** First, **the hole's edge**: a disc is a regular shape,
so a swept column comes out with straighter sides than Noita's, whose raggedness comes from irregular
material rather than from a small bite. Second, **the dead time after a blow** — a blow ends on the cell it
just cleared, so the cursor is over air until it moves. That was 504 of the director's 876 held ticks at
radius 0; a larger radius shortens it but does not remove it, and the real fix (if it needs one) is a
mechanic question, not a constant.
