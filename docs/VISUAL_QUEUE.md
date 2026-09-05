# Visual Queue (v2, 2026-09-04)

**Re-derived from the REAL seat.** v1 (fa8be271) was catalogued from `tests/body/reveal_scene.gd` with its
`--camera` flag teleporting the camera 70 m from the miner's lamp -- its "deep is black" frames were a
picture of nothing, and three of its P0s were artifacts (v1's V02 "no lamp presence", V03 "miner invisible
underground", V07/V08 "mouths and rifts invisible" -- all visible in the real seat). This catalogue comes
from 22 captures of `godot --path . -- --fresh --warp=col,row --zoom=2.0 --screenshot-tick=40` (the
player's default zoom, the miner and lamp in frame) across: spawn, the left hills and world edge, both
sinkhole mouths, 16 m / 30 m / 50 m / 71 m / 103 m / 130 m / 160 m / 190 m / 215 m, two aquifers, a mine
hold, the large map, the settings page, and four whole-width overviews at zoom 0.66. Captures live in the
session scratchpad; the seat flags reproduce every one.

Each entry: what, where (file/system), rank (P0 = the frame cannot be read, P1 = misreads, P2 = flat or
generic, P3 = polish), and legacy's answer where it had one. **Executed** marks what this session shipped;
**Fork** marks a taste call made here and queued for the director (`docs/TASTE_QUEUE.md`).

---

## The diagnosis, in four sentences

1. **Rock and the cave behind it are the same colour at nearly the same brightness**, so the SHAPE of
   the space -- the one thing a mining game must make legible -- is a soft mosaic the eye has to work for.
2. **The rock's texture is television static**: legacy's per-cell tone jitter, correct at a 32 px cell,
   is noise at a 4 px cell (64 samples where legacy had one), so rock reads as grain, not as stone.
3. **The light is grey.** The lamp's cuts are untinted (D0375's own follow-up), the deep is a flat 0.34
   grey-black at every depth below 14 m, and nothing in the frame is warm against anything cool.
4. **The frame shows the void past the world's edge** from most of the world -- the world is 64 m wide,
   the view 40 m, and the camera is not clamped.

The generation underneath is better than the frame shows: the whole-width overviews show two rifts, two
mouths, ledges and rounded pockets. It is the rendering that hides it.

---

## P0 -- the frame cannot be read

### V01 · Rock vs cave-void contrast
**What:** the background wall plane (rock behind a dug or natural cavity) is the rock's own palette, a
little darker. At 16 m, 71 m and 103 m the boundary between "stone you can stand on" and "space you can
walk through" is a soft edge between two brown or grey mosaics. **Where:** `view/visuals/wall_painter.gd`
(the wall's darkening and its 2-cell AO ramp), `view/visuals/terrain_painter.gd` (no edge treatment on the
rock side). **Legacy:** a 32 px cell carried chamfers, concave fillets and edge AO
(`legacy/.../terrain_painter.gd`, ruled not portable at 4 px in D0378) -- the answer here is a rim, not a
chamfer: a one-cell lit edge on up-facing rock and a one-cell shadow on undersides, plus a wall plane at
half the rock's value. **Executed** (see below).

### V02 · Rock texture is static
**What:** every 4 px cell has an independent brightness; at play zoom the rock is a field of 8 px
squares of random value. Soil, clay, shale and hardrock all read as the same noise in a different hue.
**Where:** `view/visuals/rock_tone.gd` (`_cell_jitter`, the per-cell term), `material_look.gd`.
**Legacy:** the same jitter at one sample per metre read as texture. **Executed**: jitter at metre scale,
low-frequency bedding.

### V03 · The deep is one flat grey
**What:** `skylight_ceiling` falls from 1.0 at the surface line to 0.34 by 14 m of DEPTH -- absolute
depth, not depth under rock -- so a tunnel 5 m under an open hillside is as dark as a pocket at 200 m, and
everything below 14 m sits at one brightness. **Where:** `VeilPainter.skylight_ceiling`, now
`veil.gdshader`. **Legacy:** `_skylight_alpha` measured from the first solid rock above the cell and
scattered `SKY_FADE` under it. **Executed**: the shader reads the per-column surface.

### V04 · The light has no colour
**What:** the lamp lifts the veil in grey; the deep is grey-black; ore glints are white. There is no
warm-against-cool anywhere in the underground frame, which is the whole of legacy's "lit" identity.
**Where:** `veil.gdshader` (lamp cuts untinted -- D0375's stated follow-up), `light_painter.gd`
(`LAMP_BLOOM = 0.17` against legacy's 0.32). **Executed**: amber lamp, cool deep, legacy's bloom.

### V05 · The world's edge is in frame
**What:** at x < 20 m or x > 44 m the frame shows the flat cut of the world's side and the parallax
mountains behind it (r05, r06, r11, r13: up to a quarter of the frame is void). **Where:**
`view/camera_rig.gd` (no world-bounds clamp). **Legacy:** clamped the camera to the world rect.
**Executed**: clamp.

---

## P1 -- misreads

### V06 · The miner is pasted on
**What:** drawn in `Main._draw` above every layer, unlit: pure-black 2 px outline, saturated orange helmet
and cyan visor at full brightness inside a 0.34-grey cave. The world is lit; the miner is not.
**Where:** `view/visuals/miner_draw.gd`, `shell/main.gd::_draw`. **Legacy:** the miner sat under the veil
and read lit by its own lamp; the helmet lamp alone stayed additive. **Executed**: the body under the
veil, the helmet lamp above it.

### V07 · Miner outline and palette clash with the world
**What:** 2 px pure-black outlines and a five-colour saturated palette against a desaturated,
soft-shaded world. Even lit, it is a different art direction. **Where:** `miner_draw.gd` (`OUTLINE`,
the body colours). **Fork**: outline to a dark umber and the visor toned down here; a sprite redraw is
the director's.

### V08 · Water is a blue splodge
**What:** an aquifer is a flat, fully saturated blue region with no surface line, no depth gradient and
no relation to the rock around it (r13, r14). **Where:** `view/visuals/water_painter.gd`. **Legacy:** a
brighter surface skin line, a darker body with depth, the sheen in the light layer.

### V09 · The large map reads as a weather map
**What:** rock is yellow, void is sky-blue, ore is gold on yellow; the panel draws UNDER the objective
banner and OVER the hotbar (r17). **Where:** `view/hud/minimap.gd` (`_class_color`, the layer order in
`ViewStack._mount_hud`). **Executed**: void dark, rock the band colour, panel above the chips.

### V10 · The surface pad is 24 m of ruler-flat ground
**What:** the middle 24 m of the surface (cols 64-160) sits at exactly the datum row; the hills to the
left and the dip to the right are 10 m and 4 m of relief that the pad interrupts. **Where:**
`sim/terrain_gen/relief.gd` (the pad), `data/strata/shallow_clay.yaml` (`relief.pad_m`). **Fork**
(generation; moves the golden): a 6-8 m pad.

### V11 · No water above 140 m
**What:** every aquifer in the boot world lies between 140 m and 230 m; R3 says water is the antagonist
and the first two hours of play never meet it. **Where:** `data/strata/shallow_clay.yaml` (`aquifer:`
depth range). **Fork** (generation; moves the golden).

### V12 · Stonereach is 8% air
**What:** 64-128 m is 7.6-8.0% air against 21-23% above and 17-19% below; the layer where hand-mining
stops is also the layer with the fewest places to be. **Where:** `data/strata/shallow_clay.yaml` (`cave:`
per-layer density). **Fork** (generation).

### V13 · The lamp pool is small and does not lead
**What:** at 20 m the pool reads as a 3 m blob beside the miner; the beam's 1.9 m lead is not visible as
a direction. **Where:** `VeilPainter.LAMP_*`, `lamp_head`. **Legacy:** the same radii, but on a brighter
base the cut revealed more. Re-judge after V03/V04.

### V14 · Ore glints are the only pull, and they are everywhere in Stonereach
**What:** dozens of white `+` stars per frame at 100 m+ (r11, r13); at that density they are texture, not
a target. **Where:** `view/visuals/glint_painter.gd` (density), the generator's ore rate (`richness`).

### V15 · The sky has a hard horizon line
**What:** a 1 px dark line across the sky at the horizon height, visible from the surface and from the
mouths (r06, r19); and a flat light-grey haze BAND above it in the overviews. **Where:**
`view/visuals/sky_painter.gd` (`HORIZON_Y`, the gradient quad's edge, the haze rect). **Executed**.

---

## P2 -- flat or generic

### V16 · Soil, clay and shale bands are indistinguishable
**What:** the depth chip announces THE CLAYBAND and SHALE REACH but the rock looks the same at 16 m and
24 m; band colours differ by a few units of value under the veil. **Where:** `material_look.gd` band
palette, `data/materials/*.yaml` `base_color`.

### V17 · The wall plane has no depth cue
**What:** the cavity's back wall is a flat fill; nothing says "this is behind". **Where:**
`wall_painter.gd`. **Executed** with V01 (darker, cooler, the AO kept).

### V18 · No atmosphere in caves
**What:** no haze, no dust, no gradient toward the cave's dark end. **Where:** `veil.gdshader` (a cool
tint in the dark end is the cheap half), `view/fx/particles.gd` (ambient motes, none).

### V19 · Trees are lollipops
**What:** a 1-cell trunk under a 3x2.5 m ellipse of one green; fine at a glance, generic on the second.
**Where:** `sim/terrain_gen/tree_pass.gd`, `data/materials/leaves.yaml`, `wood.yaml`.

### V20 · The grass cap is one bright cell
**What:** a single 4 px line of saturated green over brown; reads as a drawn edge, not turf.
**Where:** `view/visuals/surface_tone.gd` (the cap), `terrain_painter.gd::cell_fill`.

### V21 · The soil profile is invisible
**What:** the two metres under the grass should darken and brown into rock; the mosaic hides it.
**Where:** `surface_tone.gd` (the profile term). Re-judge after V02.

### V22 · Objective banner dominates the frame
**What:** "Mine 4 ore" is the largest, brightest element on screen at all times. **Where:**
`view/hud/objective_line.gd`, `ui_theme.gd`. **Executed**: smaller, dimmer after its first seconds.

### V23 · "ENTERING X" plate fires at boot
**What:** the arrival plate announces OPEN SKY before the player has moved (r01, r16). **Where:**
`view/hud/arrival_plate.gd` (first observation counts as an arrival). **Executed**: the first frame primes.

### V24 · Machine glyphs are 8 px
**What:** at `CHROME_SCALE = 0.5` on a 16 px cell the FORGE glyph is a dark square with three dots.
**Where:** `view/visuals/machine_painter.gd`, `machine_glyphs.gd`.

### V25 · Machines are the darkest thing on screen
**What:** the forge's casing is near-black on brown soil; the nameplate is the only cue. **Where:**
`machine_look.gd` colours.

### V26 · Hotbar icons are unreadable
**What:** the coal and stone icons are 3-4 px smudges in a 40 px slot. **Where:** `view/hud/hotbar.gd`
(icon draw), `item_look.gd`.

### V27 · The depth chip reads as debug text
**What:** "71 m STONEREACH" in a grey box; correct, uncomposed. **Where:** `view/hud/depth_chip.gd`.

### V28 · Key legend never fades
**What:** "A / D move · SPACE jump · LMB mine" stays after the verbs are demonstrated. **Where:**
`view/hud/key_legend.gd`.

### V29 · The mine aim ring is a thin circle
**What:** a 1 px yellow ring; no fill, no target cell highlight, no reach feedback until the red slash
appears. **Where:** `view/visuals/mark_painter.gd`.

### V30 · Mining refusal is a red slash with no reason
**What:** aiming at air or past reach shows a slashed square; the same mark for three different reasons.
**Where:** `mark_painter.gd`, `Observation.aim_*`.

### V31 · No mining feedback in the rock
**What:** cracks exist (`crack_painter.gd`) but read as a few grey pixels at play zoom; no chip burst
visible at this scale; the broken cell just vanishes. **Where:** `crack_painter.gd`, `particles.gd`
(`chip` size), `Observation.mining_blow_px`.

### V32 · Ore in rock is a grey smear
**What:** iron reads as grey cells with white dots; coal as black cells; against the static both are
"another mosaic". **Where:** `material_look.gd` nugget rendering, `ore_painter.gd` pips.

### V33 · Lode outlines are thin orange wireframes
**What:** the lode's flecked socket reads as a 1 px orange contour (r03, r20). **Where:**
`ore_painter.gd::paint_lode`.

### V34 · The minimap corner form is a thin sliver
**What:** 24 px wide for a 64 m world, 300 px tall; unreadable as a map, reads as a colour bar.
**Where:** `minimap.gd` (corner size), `ViewStack._mount_hud`.

### V35 · The overview zoom frames void
**What:** at the 0.66 rung the 64 m world is a column with void either side (r19-r22); the default is
derived correctly (D0335) but the settings page still offers the rung. **Where:**
`camera_rig.gd::ZOOM_LEVELS`, `settings_page.gd`.

### V36 · The parallax mountains only show at the world's edge
**What:** `sky_painter.gd` draws ridges that the terrain covers everywhere except past the edge, where
they read as a bug. **Where:** `sky_painter.gd::_hills`. Resolved by V05's clamp.

### V37 · Falling and landing have no weight
**What:** no dust on landing, no squash, the landing sound alone. **Where:** `view/fx/particles.gd`,
`miner_draw.gd` (no pose change).

### V38 · No motion on standing rock
**What:** nothing in a cave moves: no drips outside water, no dust, no flicker. **Where:**
`water_drips.gd` (water only), `light_painter.gd` (the lamp does not flicker).

### V39 · Water has no surface highlight in the light
**What:** the sheen exists in the light layer but is invisible at this darkness. **Where:**
`light_painter.gd` (water skin), `water_painter.gd`. Re-judge after V04.

### V40 · Ledges, spires and rubble read as more mosaic
**What:** the studding passes ported in 8d exist (r11's ledge) but their edges are the same soft mosaic
as the cave wall. **Where:** V01's rim will separate them; re-judge after.

---

## P3 -- polish

### V41 · Stars are white pixels at fixed positions
### V42 · The moon is a 4 px crescent
### V43 · Clouds are grey ellipses (r02 v1)
### V44 · The sky gradient has one hue
### V45 · The post-fx lens adds nothing visible (`post_fx_layer.gd`: grain and vignette below threshold)
### V46 · Rock tooth and grit shaders are invisible under the veil (`tooth_layer.gd`)
### V47 · Heat haze cannot be judged without a working forge in frame
### V48 · Torch and conduit light cannot be judged without one placed (`veil_sources.gd`)
### V49 · The settings page is a grey list (r18): functional, uncomposed
### V50 · Hint bubbles are a grey box with a tail (r13)
### V51 · Tree trunks are one cell wide at every height
### V52 · The world's bottom edge is a hard cut at 256 m (r22)
### V53 · Nameplates ("FORGE") are 5 px caps in a grey pill
### V54 · Payout numbers rise as plain text
### V55 · The miner's pick is static while mining (`mining_swing_phase` is on the observation, unused by the sprite)

---

## What this session executed

Filled in as each lands, with the commit and the before/after capture pair. See `docs/WORKING.md`.

## Taste forks for the director (`docs/TASTE_QUEUE.md`)

- V07 miner palette: outline umber and visor toned down here; a redraw of the sprite in the world's
  language is the director's call.
- V10/V11/V12 generation: each moves the golden and needs the CI re-pin; the calls are the director's.
- V04 the deep's cool tint: chosen here (a blue-grey dark, amber lamp); the hue is a taste knob.
