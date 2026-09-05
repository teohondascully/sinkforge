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

---

## A′ steps 6 and 8 (D0373–D0388) — the ported world, built and not yet seen

Every item below is BUILT and PARKED: the plan's rule for step 6 ("look verdicts are the director's") and
step 8's switch-on (D0388) both end at an eye, and no eye has been on this build since the boot landed.
`godot --path .` shows all of it at once; each line is one question.

**T005 · The hills are quarter-metre steps, legacy's were metre steps.** `Relief` evaluates the same three
sines per terrain column, so the ground rolls smoothly where legacy's stepped in one-metre risers; the
scarps still drop 5 m and 4 m over two metres. *Question: does the smooth roll read as ground, or does it
want legacy's terraced steps back (a `step_m` on the record)?*

**T006 · The sinkhole mouths at 12 m from spawn, legacy's at 20 m.** The keepout halved with the world's
width so a mouth exists at the boot seed at all (D0388). *Question: is a mouth three pad-widths from the
tutorial's ground a landmark or a hazard too close to home?*

**T007 · Teeth a metre wide tapering to a cell, rubble a metre square, ledges a metre thick.** Legacy's
were one metre-cell each; these widths are the port's own (D0384). *Question: at 16 px a metre, do the
teeth read as stalactites or as fangs, and is the rubble a boulder or a crate?*

**T008 · Trees: a half-metre trunk and a 3 × 2.5 m elliptical canopy.** Legacy's trunk was a metre wide
with a six-cell T of leaves (D0387). *Question: tree, or lollipop? The record's four width fields are the
dials.*

**T009 · The richness band's texture.** Legacy's simplex became value noise on a 22 m lattice, smoothstepped
(D0386); the frontier is measurably richer than spawn, but the band's grain is coarser than legacy's.
*Question: can it be felt in play at all, or only in a heat-map?*

**T010 · An aquifer is a sealed pocket full to the brim.** Dig into one and the water phase takes over
(D0344). *Question: does the first breach read as a find or as a flood?*

**T011 · Step 6's looks, in one sitting.** The machine painter and its status marks (6c), the payouts
(6d), the falling items (6e), the synthesized beds (6f), the hotbar, inspector, objectives, hints and
minimap (6g–6i), the settings page (6j), the lights (6k), the ore seams and the veil's sources (6l), the
marks (6m), the ambience (6n), the surface tone (6o), the two shaders (6p). Each was ported from legacy
with its numbers converted, none has been judged. *Question: which of these reads as legacy's, and which
as programmer art in legacy's colours?*

## The look pass (D0391–D0393) — calls made from the real seat's captures, each reversible

Captured from `godot --path . -- --fresh --warp=col,row --zoom=2.0 --screenshot-*` (`docs/VISUAL_QUEUE.md`
v2 has the method and the before/after list). Each of these was TAKEN here so the frame could be judged
as a whole; each is one constant.

**T012 · RULED 2026-09-05: keep it warm; eased to 0.38 (D0398).** The lamp leans amber at 0.45, legacy at 0.28. `VeilLight.LAMP_TINT`. At legacy's 0.28 the
pool read white against this build's blue-grey deep. *Question: is 0.45 a lamp or a campfire? The deep's
`AMBIENT_LIGHT` (0.34, 0.35, 0.42) is legacy's exactly and is the other half of the contrast.*

**T013 · RULED 2026-09-05: under the veil, keep it.** The miner is lit by his own lamp and wears a shadow rim, not legacy's cyan halo. `MinerLook.
RIM_COLOR`, `ViewStack.BODY_Z`. Legacy drew him above the light "so he stays crisp". *Question: does he
now belong, or did he lose his read against dark rock? The sprite's own black outline and saturated
palette (helmet, visor) are the next question, and a redraw is yours.*

**T014 · RULED 2026-09-05: under the veil AND legible starved -- the status beacon (D0401).** The factory is under the veil. `ViewStack.MACHINE_Z` (D0393, reversing D0364). Lit by the
scene and its own pools. *Question: can a starved machine still be read from ten metres in the dark, or
does it want its status lamp brighter?*

**T015 · RULED 2026-09-05: ore the player has SEEN -- SeenPlane (D0400).** The map does not mark ore. `Minimap.class_color` (D0392). A design call as much as a look:
the survey upgrades sell what the fleck gave away. *Question: agreed, or should the corner map show ore
the player has SEEN (which needs a fog plane the observation does not carry)?*

**T016 · RULED 2026-09-05: all three, by impact -- executed and re-pinned (D0402).** The three generation forks, each moves the golden. V10 the 24 m ruler-flat pad
(`relief.pad_m`); V11 no water above 140 m (`aquifer:` depth range); V12 Stonereach at 8% air against
22% above and 18% below (`cave:` per-layer density). *Question: which, if any, and in what order? Each is
a data diff plus the CI re-pin flow.*

**T017 · RULED 2026-09-05: more bedding, fewer inclusions -- executed in D0398 (hardrock bedded with parting planes, the tooth's cell 1/8 m).** The rock's texture is legacy's at legacy's granularity. `RockTone.GRAIN_AMP`/`STONE_DARKEN`,
`MaterialLook.STRATA_AMOUNT`. Under the new light it reads as lit stone rather than static; the bedding
is faint. *Question: more bedding (STRATA_AMOUNT up), fewer inclusions (STONE_DARKEN down), or leave it
for the art pass?*


## The two-phase round (D0396–D0404) — the calls made here, each one constant

**T018 · The parting planes' weight and rhythm.** `RockTone.LAM_DARKEN` 0.42 + `LAM_ADD` 0.045, bed thickness
2 / 1 / 0.5 m by the fade field. Under the lamp the face reads as layered stone; where the field runs flat
the lines rule a metre apart (VISUAL_QUEUE V71). *Question: fainter and fewer, or this, or a second
warp so the beds fold?*

**T019 · The map is a strata chart.** The band colours at 55% toward grey (`Minimap.MAP_DESATURATE`); the
ladder still reads as bands down the map. *Question: keep the chart, or plain rock with the chip alone
naming the band?*

**T020 · The deep's lamp.** `VeilPainter.lamp_scale` shrinks the pool with depth; at 200 m the lit disc is
a few metres (V63). The dark is the design; the drowning was the complaint. *Question: a floor under the
depth scale, or a wider pool that the deep earns with a better lamp?*

**T021 · RETURN TO SURFACE is priced at nothing.** A stranded player stands at the spawn again with the
world and the pack kept (D0396). *Question: should being stranded cost something -- the pack, the line,
a walk -- or is a free way out the right price for a game about not getting stuck?*

**T022 · "Seen" is an eight-metre disc on a hub tick.** It counts ore behind a metre of rock whose face
the lamp lit (D0400). *Question: is that the survey's meaning of seen, or does the map want a sight line?*

**T023 · The status beacon breathes at 0.9 Hz between 0.30 and 0.75 in the status colour.** *Question:
is a pulse the right call for "wants something", or a steady colour with the working glow off?*
