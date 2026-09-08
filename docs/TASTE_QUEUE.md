# Taste queue

Status: source records. Use [BACKLOG](BACKLOG.md) to schedule current work; existing T IDs
and director rulings remain authoritative. Historical descriptions require current-frame review.

Feel, visual, and design judgment calls, batched for the director in one sitting. Never mixed with
correctness — that goes through the gates, not here. `CONTEXT.md`, "Review bandwidth" and "Playable
fixtures"; format detail in `docs/ARCHITECTURE.md` §6.

Every entry is a playable fixture ID and exactly one question. If a fixture needs two questions, it
should be two fixtures.

```
F### · <fixture name / what it isolates> · <one question>
```

---

The proposed F-series fixture format was not adopted here. The T-series records below contain
the actual taste questions; the working playtest adapter is documented in `playtest/README.md`.

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

## The integration pass (D0409–D0414) — the calls made from a stranger's first ten minutes

**T024 · The lessons dock lower left; nothing anchored to the body reads.** D0413 read the review's
"short pointer only" as: what stays near the miner points and does not read (the rung's ring, the aim
marks). *Question: does a lesson want a second, tiny cue at the body -- a pip that says "look down-left"
-- or is one stable place enough once the player has met it?*

**T025 · The inspector's hover tooltip still draws at the pointer, which IS the aim.** Rank 6 named the
action area round the miner and the aim; the tooltip was not named and was left. *Question: a tooltip
that docks beside the lesson, or a tooltip that yields while MINE is held?*

**T026 · The hotbar's ten digits are physical keys, not actions.** The remap page lists fifteen actions
and none of them is a slot (D0412). *Question: ten more rows on the remap page, or a single "hotbar
keys" row that cycles layouts?*

**T027 · The tutorial's opening cavity is a metre of crust over four metres of pocket.** D0353's `open`
fixture, legacy's shape; the body walks it fine and the ambiguous-floor invariant logs on every crossing
(D0414). *Question: is the thin crust the intended tease of what lies under, or should the pocket be a
step down the stranger can see?*

**T028 · The score costs 50 ms of boot and is silent until the body is deep.** Mounted so the MUSIC slider
has a consumer (D0410). *Question: worth its boot cost before any music is authored, or a stub until it is?*

**T029 · TAKEN 2026-09-06 by its third option, provisionally (D0424).** Only the selected hotbar slot carries its name. The first stranger cut a tree's leaves, saw a
green block appear beside the ingots, and believed it was wood; the counter stayed 0/1 and read as a bug
(D0421). *Question: a name under every slot (clutter), a name on hover only, or the item's name flashed
beside the miner as it lands in the pack?* The payout tick now says "+1 sapling" / "-7 ore"; the hotbar's
label is unchanged. The director may still want a name on hover as well.

**T030 · The drag paints a dig plan a stranger cannot name.** Holding MINE while the pointer moves marks
cells for later digging (legacy's plan); the second stranger left yellow dashes on distant canopies and a
trunk and had no word for them or a way to clear them it knew (D0423). *Question: gate the plan behind a
modifier, teach it as a lesson when the first dash lands, or make CLEAR_PLAN a visible control?*

**T031 · TAKEN 2026-09-06, provisionally (D0434): two metres of clay cap the mouth in the tutorial start; two record lines reverse it.** The shaft beside the pad swallows a stranger who walks right for two seconds. The third
stranger, beside the forge with the smelt rung open, pressed D for 120 ticks and stood 22 m down THE
CLAYBAND with no line and the way back a lesson it had not met (D0424); the fourth took the same fall
looking for a tree (D0425 gives the wood rung a tree on the pad, which removes that reason to leave it).
The fifth fell in too (D0428): three of five; then 6, 7, 8 and 9: eight of nine. **The mechanism:** it is a one-metre chimney 45 m deep at
+14 m from spawn, and `vertical_passes.gd` clamps a sinkhole that would open inside the 12 m spawn keepout
to exactly the keepout's edge -- the world's first mouth stands two metres past the pad by construction, and
D0388 lowered the keepout so the boot seed would HAVE a mouth. Legacy's opening had the same shaft.
*Question: is a forty-metre fall two metres past the pad the intended first descent, or does the clamp
want to DROP a mouth that lands in the keepout (so the first one falls where the terrain puts it), or the
mouth a lip the body cannot walk into blind?*

**T032 · Four kinds of ring on the opening frame.** *TAKEN provisionally (D0449): the target is the one
white mark, a reticle with compass ticks over a dark rim; the machine bubbles keep their status colours.* The tutorial's target ring (pale gold, breathing), the
machine status pips (a small ring and a dot), the grapple's landing ring (hemp now, and gated, D0424), and
the aim square's own ring when the pointer rests on a lode. The third stranger's first hesitation was
which ring the lesson meant. *Question: does the target ring want a distinct FORM -- brackets, a
reticle, ticks at the compass points -- rather than only a distinct ink?*

**T033 · The machine's held count and progress bar are eight pixels tall at play zoom.** *TAKEN (D0442): the
second option -- the arrival tick reads "+1 ingot · 2 more". The badge and bar are as they were.* Stranger 8 fed
seven ore, took the first ingot and walked off to look for the second; the forge wore a "5" badge and a
filling bar the whole time (frame 7 of run 8), drawn at legacy's chrome scale on a one-metre face. *Question:
a larger badge on the machine you stand beside, a "5 more" line in the arrival tick ("+1 ingot, 2 more
coming"), or leave the face alone and let the ring on the forge hold the player there?*

**T034 · A felled trunk leaves its crown in the air.** Stranger 10 cut the tutorial tree's trunk for a
wood block and walked away from a canopy of leaves floating over nothing (frame 33 of run 10). The tree
pass plants leaves as terrain cells, so the trunk's fall does not take them. *Question: does the crown
fall with the trunk (Terraria's whole-tree drop), crumble to leaves over a few seconds, or stay -- an
arbour reads as a ruin here -- and if it falls, does it pay leaves or wood?*

**T035 · Walking is fast against the pad.** *More (D0444): strangers 17 and 20 overshot the vein by five
metres on two presses and never mined; three of the last six first-rung failures begin with a walk.* RUN_SPEED is legacy's 150 px/s, 9.4 m/s in this scale: a D
held for two thirds of a second carried stranger 11 seven metres, past the forge pocket, the vein, the
adit and the drill shaft -- the whole authored opening -- before the first frame came back. Two of three
strangers on the capped world overshot the pad on their first key. The world is 64 m wide, so the east
edge is three seconds of walking from spawn. *Question: is the pad too small for the speed, or the speed
too high for the pad? A walk/run split (shift), a wider pad, or a slower legacy constant re-derived for
a body 1.25 m tall.*

**T036 · The world ends without a wall.** *TAKEN provisionally (D0457): the edge blocks the body like rock
(two lines in `WorldSurroundings.blocks`); what the edge LOOKS like stays open.* *More (D0444): at the edge the camera clamps and the body leaves
the frame's centre; stranger 21 read THE WAY DOWN there and pressed "under me" at screen centre sixteen
times, on air.* Strangers 11 and 12 both walked to the east edge (32 m from
spawn) and stood at the screen's right border with the ground running under the frame and nothing drawn
past it; the camera clamps to the grid and the body clamps a tick later (frame 28 of run 11, frame 21 of
run 12). *Question: a cliff, a sheer bore wall in the lore's own material, dark rock to the edge of the
canvas, or a wider world so the edge is never reached in the opening?*

**T037 · Nothing says the way down is to dig.** *TAKEN provisionally (D0440): the moment lesson, fired
after 24 m of surface ranged with rock broken once and nothing below 4 m. Overrule by deleting the row.* Stranger 15, sent to descend twenty metres, mined four
ore in the first hold and then walked the pad for a minute looking for "an entrance" to the caverns
visible below, pressing Q, E, Tab and Shift; "no access to deep areas" was the verdict. The GDD's identity
is solid earth you carve into, and the only sentence that says so is the fourth rung's "dig down to it".
*Question: a moment lesson ("THE WAY DOWN — the ground is rock you can cut: point at the floor and hold
[MINE]") fired when the first rung is done and the body has crossed the pad without digging; or the
first rung's own how-to naming the floor as rock; or leave it to the fourth rung and accept the walk.*

**T038 · "Spawn" is a word the player does not have.** *TAKEN provisionally (D0451): "buried in the WHITE
RING, right of where you began"; the outline-on-the-surface and moved-pile answers stay open.* The fourth rung's how-to says "The crew's drill lies
under the ground RIGHT of spawn -- dig down to it"; stranger 22, three rungs done in 41 s, stopped there:
"I couldn't determine what spawn meant." The drill's ring is on the pile three metres down, under rock.
*Question: "to the RIGHT of where you began", or the dig spot itself marked on the surface above the pile
(a second outline, on the ground the player must open), or the drill pile moved up under the adit floor
where a stranger already walks?*

**T039 · The hotbar's capacity: shown or not.** Astra's visual queue (P0 items 5-6) asks for a content-aware
hotbar with an explicit capacity ("5/10" or an expandable tray). The bar IS content-aware already -- it
draws only the slots carried, with a floor of one (legacy's rule, D0368) -- and hides the cap on purpose:
"a bar that reports totals is on its way to being a second inventory"; the PACK FULL chip says when the
cap bites. *Question: does the director want the cap visible before it bites (a "5 of 10" under the bar,
or one dim empty well past the last full one), or does legacy's rule stand?* Two strangers (14, 20) said
they could not tell what they held from the bar; none said they wanted to know how much more it takes.

**T040 · The terrain's per-cell shading: on the CPU as it is, or a data texture with the tone in a shader.**
The director, playing 2fe07582: "the whole world freezes every single time I mine a block; if I jump down a
shaft it glitches as it loads another part of the world". Measured (D0522, D0524): the sim costs 0.3 ms a
tick; every stall was the terrain bake, and the bake's unit cost is the molded shading, 18-25 us a SOLID
cell (`TerrainPainter.cell_fill` -> `RockTone.shade` probes each cell's neighbours out to FORM_REACH + 1
through a Callable, then one `draw_rect`; air cells are near free). Three fixes landed around that cost
without touching it: a dig repaints its own dilated rectangle (a blow 419 ms -> 60 ms worst), chunks went
128 -> 32 -> 16 cells, and the streaming lane paints at most 512 solid cells a tick (a shaft fall's worst
frames 80-90 ms -> 22-23 ms). What remains is the floor that cost sets: 512 cells is 11-13 ms of bake in a
16.7 ms frame, so a fall into solid ground still runs 17-25 ms frames (34-37 of the first 2000, at 512
and at 384 alike); the only way under it is fewer cells a tick, which is chunks arriving later. *The
fork: keep the CPU tone and accept the stutter on new ground, or bake per chunk a small data texture
(material id, grammar, distance-to-air as the shader's inputs, ~1 us a cell to build) and move the molded
tone into the rock shader beside the tooth (`rock_tooth.gdshader` already samples the grammar map, D0398,
D0511). The second is the "molded vs crisp" question the underground-legibility work parked: the tone's
LOOK would be re-derived in GLSL, and a capture comparison would decide whether it is the same picture.
A worker can do the first half (the data texture, the shader reading it) as a bounded ticket once the
director says the look may move by a capture's difference.*
