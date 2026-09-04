# Visual Queue

**The map Fable executes from.** Catalogued 2026-09-04 from 10 captures across spawn, shallow, mid,
deep, overview and edge positions at the boot seed (shallow_clay, 20260826). Each entry: what's wrong,
where (file/system), impact rank (P0 = unplayable, P1 = misreads, P2 = flat/generic, P3 = polish),
and — where legacy solved it — a pointer to legacy's answer.

Baseline captures: `scratchpad/captures/` (session-local; the Fable session should recapture after fixes).

---

## P0 — unplayable or misread

### V01 · Darkness drowning
**What:** the underground is near-black everywhere outside a tiny lamp pool. 15 m underground is as dark
as 200 m. No sense of space, depth, or structure. The game happens in undifferentiated blackness.
**Where:** `view/visuals/veil_painter.gd` (the skylight ceiling drops too fast), `VeilPainter.AMBIENT_DARK
= 0.66`, `SKY_REACH_M = 12.0`, `SKY_FADE_M = 16.0` — legacy's same constants, but legacy's skylight also
scattered under the first solid rock, and the per-column surface row isn't wired yet (the comment says so).
**Impact:** P0 — the player cannot see the game they are playing.
**Legacy's answer:** `_skylight_alpha` scatters light under rock via `SKY_FADE`; the overall veil was much
brighter in the first 30 m; the lamp was also much more prominent (three overlapping pools that summed
to visible bloom). `world_renderer.gd:3263-3270`.

### V02 · No lamp presence
**What:** the lamp cut in the veil is functionally invisible at surface and barely visible underground.
The three radii (beam 9 m, throat 5 m, body 3.4 m) exist but their combined lift reads as a faint lightening
of the blackness, not as a pool of light you stand in.
**Where:** `VeilPainter.lamp_lift`, `LightPainter.paint_frame` (the additive bloom at `LAMP_BLOOM = 0.17`).
**Impact:** P0 — the lamp IS the game's primary light. If it doesn't read, nothing reads.
**Legacy's answer:** the bloom was 0.32 (nearly 2x), and legacy's veil base was brighter so the cut
revealed more. The lamp also scaled differently with depth — at surface it was at 0.30 floor, which was
visible against legacy's lighter sky.

### V03 · Miner invisible underground
**What:** the miner sprite is a dark silhouette. Against the sky it reads; against dark rock it vanishes.
**Where:** `view/visuals/miner_draw.gd`, `shell/main.gd::COLOR_BODY/COLOR_BODY_GROUNDED`.
**Impact:** P0 — the player cannot see themselves.
**Legacy's answer:** the miner sprite was drawn with ambient light from the lamp, and the lamp bloom
backlit the body. The body colour was the same warm red/yellow but the lit environment made it read.

### V04 · No terrain structure visible
**What:** even where the veil is bright enough to see, the rock reads as a flat, noisy brown fill. No
visible bedding, layering, fissures, or carved-edge contrast. The rock_tone shading and surface_tone
exist but are too subtle at this darkness level.
**Where:** `view/visuals/rock_tone.gd` (the tone terms), `view/visuals/terrain_painter.gd` (cell_fill),
`view/visuals/surface_tone.gd`. Also: legacy's chamfers/fillets/edge AO were ruled not portable at 4px
(step 6o, D0378).
**Impact:** P0 — rock does not read as rock.
**Legacy's answer:** `terrain_painter.gd` at 438 lines had the autotile chamfers, concave fillets, and
carved-edge AO that made rock read as carved. These were ruled not portable at the 4px cell. The question
is what replaces them.

---

## P1 — misreads or misleading

### V05 · Surface reads as a line, not as ground
**What:** the ground surface is a pixel-thin line separating sky from near-black. No thickness, no soil
profile visible, no transition. The tufts exist but read as artifacts at play zoom.
**Where:** `view/visuals/surface_tone.gd` (the soil profile, the cap, the tufts), `view/visuals/
terrain_painter.gd` (cell_fill at the surface). The relief system ported in step 8b gives the surface
hills and scarps, but at the default zoom the hills are ~2 m peak-to-trough over 64 m — barely a pixel
of variation.
**Impact:** P1 — the surface is the player's first impression and it reads as a flat line.
**Legacy's answer:** 32px cells made the terrain surface naturally thick; hills at one-metre resolution
were visible. Also the soil tinting (browns/greens) was visible against a lighter background.

### V06 · Trees read as dark blocks, not as trees
**What:** tree trunks (wood) and canopies (leaves) are rendered as dark cells at the surface, barely
distinguishable from rock. No vertical shape, no colour separation from the terrain.
**Where:** `sim/terrain_gen/tree_pass.gd` (trunk 2-3 cells tall, canopy 3×2.5 m), the material colours
in `data/materials/wood.yaml` and `leaves.yaml`, `view/visuals/material_look.gd`.
**Impact:** P1 — trees are a legibility anchor ("I'm near spawn") and they're invisible.
**Legacy's answer:** legacy's one-metre cells made trees ~3 cells tall with a distinct green canopy crown
above brown trunk. The scale carried the legibility.

### V07 · Sinkhole mouths invisible
**What:** the sinkhole mouths ported in step 8c (3 per world, flared from rift to surface) are not
readable at play zoom. They should be dramatic gateways to the underground.
**Where:** `sim/terrain_gen/vertical_passes.gd` (cut_throat, flare), but the rendering is the terrain
bake which just fills the cells. The ABSENCE of terrain cells at the mouth is invisible against the dark
background below.
**Impact:** P1 — mouths are the progression hook ("go down there") and they're invisible.
**Legacy's answer:** daylight pouring through the mouth (godrays from `LightPainter._paint_godrays`)
lit the chasm walls. The mouth read as a bright gap in dark ground, not as a dark gap in dark ground.

### V08 · Rifts invisible
**What:** the rifts (step 8c, pinch-and-open chasms) are open-air cells in solid rock. But everything
underground is equally dark, so a rift reads the same as surrounding rock.
**Where:** same as V01 — the veil makes rock and air equally dark underground.
**Impact:** P1 — rifts are the world's vertical structure and they're invisible.

### V09 · Aquifer water invisible
**What:** aquifer pockets (step 8e) are filled with water cells. The water painter renders them but
they're drowned in the overall darkness. The teal/cyan cells visible in the sinkhole capture are the
only sign of water.
**Where:** `view/visuals/water_painter.gd` (paints water cells), but the veil dims them.
**Impact:** P1 — water is a core mechanic (R3) and it's invisible until you're standing in it.

### V10 · Ore indistinguishable from rock
**What:** ore deposits in the rock face are rendered as differently-coloured cells but the veil dims
both ore and rock to near-identical darkness. Only the glint sparkles (the discovery twinkle) signal ore.
**Where:** `view/visuals/ore_painter.gd` (seam glow in the seam's mineral hue), `view/visuals/
glint_painter.gd` (the twinkle). The glint is above the veil deliberately; the seam glow is on the
additive canvas. Both exist but neither is strong enough.
**Impact:** P1 — ore is what the player is looking for and it's invisible until discovered by glint.

---

## P2 — flat, generic, no pull

### V11 · No "something over there" pull
**What:** nothing in the frame draws the eye or invites exploration. No visible light source in the
distance, no cave opening catching skylight, no warm glow from a machine, no hint of ore ahead. The
frame is darkness with a lamp blob.
**Where:** systemic — a function of V01 (darkness drowning) combined with the absence of distant
light cues.
**Impact:** P2 — the game's core loop is "go deeper and find things" and nothing says "this way".
**Legacy's answer:** godrays through mouths, machine pool glows, ore seam glows, torch flames, conduit
beads — all read as distant signals because the base darkness was lighter enough to show them.

### V12 · Terrain generation reads as boring at play zoom
**What:** at the zoom the player actually uses, the world reads as a flat surface over undifferentiated
dark fill. The hills (pad 32 m, waves, scarps) exist but the amplitude is 2-4 m over 64 m — at play
zoom this is maybe 3-5 pixels of variation.
**Where:** `data/strata/shallow_clay.yaml` (relief config: `amp_m` values, scarp positions), the world
is 64 m wide (half of legacy's 128 m).
**Impact:** P2 — the surface needs to read as terrain, not as a line.

### V13 · No depth gradient in rock colour
**What:** rock colour does not change with depth. Topsoil, clay, and deep rock are the same brown at all
depths. The depth chip says "TOPSOIL" but the picture doesn't change.
**Where:** `data/strata/shallow_clay.yaml` (the bands table drives `material_look.gd`), `view/visuals/
material_look.gd::cell_color` (reads the band). The bands exist but are swamped by the veil's darkness.
**Impact:** P2 — a depth gradient is legibility ("I'm deeper now") and it's invisible.

### V14 · Minimap too narrow to read
**What:** the minimap is a thin vertical strip on the right edge. At this size, individual features
(ores, caves, water) are 1-2 pixels wide and unreadable. It shows the world shape but nothing else.
**Where:** `view/hud/minimap.gd` (corner form, keyed on coarse_version).
**Impact:** P2 — the minimap should be a glanceable guide to "where am I" and "what's nearby".

### V15 · Hotbar barely visible
**What:** the hotbar at the bottom centre has a single slot with a selection indicator. Against the dark
background it's hard to spot. The slot is empty-looking (a small "1" in the corner).
**Where:** `view/hud/hotbar.gd` (the widget), `view/hud/ui_theme.gd` (the theme tokens).
**Impact:** P2 — the hotbar is the player's inventory interface.

### V16 · No cave atmosphere
**What:** caves have no ambient fill, no background colour variation, no sense of enclosed space. A cave
is just "not rock" — the absence of cells, rendered as black void.
**Where:** `view/visuals/backdrop_painter.gd` (the band-tinted fill behind everything), but underground
the backdrop is covered by the veil's darkness.
**Impact:** P2 — caves should feel like enclosed spaces with their own atmosphere.

### V17 · Background wall invisible
**What:** the wall plane (step 6, wall_painter.gd) renders the background wall behind the play space,
but it's invisible under the veil's darkness. The wall exists and is baked correctly, but nobody can see
it.
**Where:** `view/visuals/wall_painter.gd` (baked at WALL_Z = -60, behind terrain).
**Impact:** P2 — the wall gives depth to cavities. Invisible walls = flat cavities.

### V18 · Ledges/spires/rubble invisible
**What:** the studding passes (step 8d) placed ledges, teeth, and rubble through the world. None are
readable at play zoom under the current darkness.
**Where:** `sim/terrain_gen/studding_passes.gd`, rendered through the terrain bake.
**Impact:** P2 — structural variety in the caves is invisible.

---

## P3 — polish, texture, feel

### V19 · Sky gradient is flat
**What:** the sky is a simple dark-to-light gradient. No clouds, no atmospheric scattering, no horizon
glow. The moon is a small crescent. Functional but generic.
**Where:** `view/visuals/sky_painter.gd`.
**Impact:** P3 — the sky is the backdrop to the surface experience.

### V20 · No particle life at surface
**What:** no wind particles, no dust motes, no atmospheric particles. The surface is static.
**Where:** `view/fx/particles.gd` (has chip/pop but no ambient).
**Impact:** P3 — surface life.

### V21 · Machine glyphs too small
**What:** machine glyphs at `CHROME_SCALE = 0.5` on a 16px logic cell are 8 pixels. At play zoom,
that's ~16 screen pixels — barely readable.
**Where:** `view/visuals/machine_painter.gd`, `view/visuals/machine_glyphs.gd`.
**Impact:** P3 — machines should be immediately recognisable.

### V22 · Objective banner dominates the frame
**What:** "Mine 4 ore" banner is the largest, brightest element on screen. It's larger than the miner,
larger than any terrain feature, and stays visible at all times.
**Where:** `view/hud/objective_line.gd` (the chip shape).
**Impact:** P3 — the objective is information, not the focal point.

### V23 · Key legend position
**What:** "LMB mine" is in the bottom-left corner, small text against dark background.
**Where:** `view/hud/key_legend.gd`.
**Impact:** P3 — fine as-is, but should fade once demonstrated.

### V24 · No post-processing warmth
**What:** the post-fx layer exists (`view/visuals/post_fx_layer.gd`) but the frame reads cold and flat.
No vignette, no colour grade, no film grain at the level that adds atmosphere.
**Where:** `view/visuals/post_fx_layer.gd`.
**Impact:** P3 — colour grading is what makes a frame feel authored rather than debug-rendered.

### V25 · Rock tooth / grain invisible
**What:** the `rock_tooth.gdshader` and `rock_grit.gdshader` exist (step 6p) but their effect is
invisible under the darkness. They're applied over the terrain bake correctly but contribute nothing
visible.
**Where:** `view/visuals/tooth_layer.gd`, the shader at `TOOTH_Z = -44`.
**Impact:** P3 — sub-cell texture that can't be seen.

### V26 · Heat haze invisible
**What:** `heat_haze.gdshader` (step 6p) plumes over working forges and burners — but with no machines
placed and everything dark, it contributes nothing.
**Where:** `view/visuals/haze_painter.gd`.
**Impact:** P3 — atmospheric effect that needs machines to show.

### V27 · Depth chip is informational only
**What:** "1 m TOPSOIL" is correct but reads as debug text, not as a game HUD element. No icon, no
visual weight, no integration with the frame's visual language.
**Where:** `view/hud/depth_chip.gd`.
**Impact:** P3 — should read as part of the game, not as an overlay.

### V28 · Lode flecks invisible
**What:** the lode painter's live-metal flecks (`ore_painter.paint_lode` at `LODE_Z`) exist but are
invisible in the dark. They drain monotonically as ore is extracted — a nice touch nobody can see.
**Where:** `view/visuals/ore_painter.gd`.
**Impact:** P3 — a good mechanic hidden by the darkness.

### V29 · Surface tone cap invisible
**What:** `SurfaceTone.cap_color` paints the walked surface cell in a cap colour (green moss, brown
roots). Invisible against the dark terrain.
**Where:** `view/visuals/surface_tone.gd`.
**Impact:** P3 — surface life detail hidden by darkness.

### V30 · World edge is a hard cut
**What:** at the left and right edges of the 64 m world, the terrain simply stops. No fade, no
boundary, no visual signal.
**Where:** `view/visuals/terrain_bake.gd` (draws to world bounds), no edge treatment.
**Impact:** P3 — should feel like a natural boundary, not a programmer's edge.

---

## The root cause

**V01 (darkness drowning) is the root of V02-V10 and V17-V18, V25, V28-V29.** Fixing the veil's
skylight scatter, the lamp bloom, and the base brightness would make 15+ of these entries visible
for the first time without touching any of them individually. The priorities above are ranked as if V01
is fixed — without it, every item below P0 is invisible and cannot be judged.

**Legacy's answer, in one line:** `_skylight_alpha` scattered light 16 m under the first solid rock,
`LAMP_BLOOM` was 0.32 not 0.17, and the veil's `_base` split cached the skylight+burial and the lamp
cut into a duplicate per frame — so the base was always visible and the lamp always read as a cut in it.
The per-column surface row was wired to the observation.

---

## What the Fable session should execute, in order

1. **Wire `Observation.surface_y` into the veil skylight** — the comment in `VeilPainter.skylight_ceiling`
   says the per-column surface row isn't wired yet. Legacy's scatter uses it. This alone makes shallow
   caves visible.
2. **Raise `LAMP_BLOOM`** from 0.17 to 0.28-0.32 and re-evaluate the lamp scale curve.
3. **Port the veil base/scratch split** — the cached base makes the per-frame cost affordable AND makes
   the lamp read as a cut in something visible, not as a dim glow in blackness.
4. **Evaluate the remaining 25 items** once the darkness is fixed — most of them are literally invisible
   until then.
