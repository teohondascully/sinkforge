class_name FineTerrain
extends RefCounted

## FINE TERRAIN MOLDING (renderer-only, Noita-look slice 1) — makes the coarse 32px sim terrain READ
## as granular, molded rock at an 8px sub-cell grain, WITHOUT touching the sim. The sim still stores
## terrain as one material id per 32px cell (sim.solid); this baker re-renders that coarse field so its
## straight edges become organic, clumpy, curved boundaries.
##
## Technique (the whole trick): conceptually subdivide each coarse cell into SUBDIV×SUBDIV fine cells.
## For each fine cell compute a smooth "solidness" 0..1 by BILINEARLY sampling coarse solid/air at the
## fine cell's centre (so a solid/air boundary becomes a smooth ramp across ~1 coarse cell instead of a
## hard step), then PERTURB it with a deterministic FastNoiseLite and THRESHOLD at 0.5. The bilinear
## ramp is what lets the noise bend the edge: deep interior (solidness 1) and deep air (solidness 0)
## never flip — molding only happens in the ~1-cell boundary band — so cave mouths round out, walls get
## an irregular clumpy profile and rock tops undulate, while the base stays solid by construction.
##
## The result bakes to ONE Image at fine resolution, uploaded to an ImageTexture and drawn stretched
## over the world with NEAREST filtering (crisp 8px fine pixels). It rebuilds ONLY when the terrain
## changes (mirrors the veil/chunk repaint-on-change discipline) — never per frame.
##
## LIMITATION (by design, this slice): the molding is driven by COARSE data, so features are still
## ~32px-scale organic wobble — true fine-grained detail (thin 8px veins, sand piles) needs fine DATA
## in the sim, a later slice. This slice is safe and sim-free.


## ─────────────────────────────────────────────────────────────────────────────────────────────────────
## A STANDING CONSTRAINT ON THIS RENDERER, written down because THREE separate tickets have now discovered
## it independently and none of them left a note. If you are about to add a texture, a mark, a treatment or
## a cue that has to be visible UNDERGROUND, read this first — it will otherwise cost you a day.
##
##   ANYTHING MULTIPLICATIVE IS INVISIBLE AT DEPTH. Anything that must survive the dark has to be
##   ADDITIVE, in absolute value levels.
##
## The reason is arithmetic, not taste. The darkness veil is a MULTIPLY layer, and the sampled rock mean
## underground is about 10/255. Any effect expressed as a fraction of the material's own colour — which is
## everything routed through `vmul` here — is therefore scaled by the same factor that made the rock dark.
## A generous +-0.16 swing on `vmul` arrives as about 1.6 levels, against a measured within-window standard
## deviation of 4.5. It is not that the effect is too weak; it is that it is being divided by the dark.
##
## The three that learned it the hard way:
##   * `rock_grit`'s additive floor sat BELOW the multiply, so raising GRAIN_AMP, adding a companion and
##     raising the noise frequency all measured as nothing (58% -> 55% -> 59% against a 75% floor). Fixed
##     by `rock_tooth.gdshader`, which draws the same texture ABOVE the veil and adds in absolute levels.
##   * `_draw_edge_ao` in `terrain_painter.gd` paints a contact treatment that reaches ZERO pixels
##     underground — hiding that whole layer moves an underground frame LESS than photographing it twice.
##   * the material grammars below (TR-02/TR-04) were written into `vmul` first and moved dirt-vs-stone
##     separability two points for a 5.3x amplitude ratio.
##
## AND THE SECOND HALF, WHICH IS NEWER AND HARDER. Additive is necessary and not sufficient: at a mean luma
## of 10 a 4x crop of underground rock is visually BLACK, so a difference an instrument can measure there
## may be one no eye can use. A separation statistic is not a perception. Judge a treatment where the
## player can actually see — inside the lamp — and treat "unreadable out in the dark" as a BRIGHTNESS
## finding rather than a texture one.
## ─────────────────────────────────────────────────────────────────────────────────────────────────────

const SUBDIV: int = 4                                  ## fine cells per coarse cell side (8px fine @ 32px cell)
const FINE: int = 8                                    ## fine cell size in world px (CELL / SUBDIV)
## P2: the fine SHAPE (which fine cells are solid) now comes from the sim's real fine grid — the boundary
## molding/threshold constants that computed it here are gone. What remains below is pure LOOK: grain,
## moss, back-rock, shadow tints, and a low-freq tonal drift (_noise) painted over that real shape.
const TONAL_FREQ: float = 0.085                        ## low-freq drift so a broad rock face isn't one flat colour
## GRAIN + SPECKLE (Noita diff 4): a dense high-frequency per-fine-cell noise field that pits and clods
## the rock so it reads granular/textured, not smooth flat-shaded. Two octaves — a fine speckle and a
## crisper grit — modulate each solid fine cell's value.
## ...and the two things that decide whether that reads as ROCK or as STATIC.
##
## FREQUENCY. Sampled on an integer grid, a noise field at frequency 1.3 has a period well under two
## samples: neighbouring fine cells get uncorrelated values, and the "crisp grit" octave was therefore
## not grit at all — it was white noise, one value per 8px cell. Printed at 3x magnification the rock
## floor came out as a high-contrast CHECKERBOARD, which is the loudest programmer-art tell there is, and
## no amount of hue, patch or crack work above it survives being averaged with static. Both octaves now
## resolve: features clump across several cells the way granular rock does.
##
## ANISOTROPY. Even resolved, isotropic noise reads as fog or sand — never as stone. Rock has GRAIN, and
## sedimentary rock's grain is horizontal. Sampling with the X axis compressed makes every feature wider
## than it is tall, so the grain lies down into bedding and the eye reads a face of layered rock instead
## of a field of dots. Same trick CAVE_XSTRETCH plays on the cave noise, one scale down.
##
## AMPLITUDE, which is the half that resolving the frequency does not fix. A field can clear the Nyquist
## floor comfortably and still print as a checkerboard, because what the eye judges is the STEP between
## two neighbouring squares, and a resolvable field multiplied by a loud swing steps just as hard as an
## unresolvable one. Measured on the painted pixels rather than on the input fields, the rock was jumping
## 9% of its own luminance across a face and 12% down one, between squares twelve SCREEN pixels wide —
## which is not grain, it is tiling. The budget below is set so the total lands under 6%, and every term
## that spends any of it has to be worth seeing at that size.
const GRAIN_FREQ: float = 0.09                         ## bedding grain — a feature spans ~11 fine cells
const GRAIN_FREQ2: float = 0.115                       ## the finer octave — ~9 cells, still a shape not a dot
const GRAIN_XSTRETCH: float = 0.38                     ## <1 = features stretch HORIZONTALLY (bedding)
const GRAIN_AMP: float = 0.10                          ## value swing of the grain
## ROCK INTERNAL TONAL VARIATION (diff-04 #1): the interiors of the reference rock are far from flat —
## broad PATCHES of lighter/darker rock, darker EMBEDDED-STONE blobs, and faint hairline cracks. Three
## noise scales layer on top of the fine grain so the rock reads busy/detailed EVERYWHERE, not just at
## edges. Patch = a big soft ±value swing; stone = a mid-freq mask that, past a threshold, darkens a
## whole cluster into an embedded stone; crack = a ridged thin dark seam.
##
## Both of the last two are THRESHOLDED, which is its own trap. A threshold turns a smooth field into a
## binary mask, and a mask is far less correlated than the field behind it: a comfortably-resolved field
## can cut into scattered single cells, so an "embedded stone" prints as one dark square and a "hairline
## crack" as a line of dots. Both now ramp in over several cells instead of switching, which is also what
## makes them read as a blob and a seam rather than as damage.
## THE CONTACT MUST NOT BE THE CELL.
##
## Materials are stored one per 32px coarse cell, so every place two of them meet is an axis-aligned
## rectangle edge — and the ground is not one material: earth, shale, stone, ore and coal interleave cell by
## cell, each with its own base colour, and `_paint_fine` reads that colour FLAT for all SUBDIV² children.
## Stored that way it paints a QUILT: flat-shaded blocks in a grid. That is the "weird contrast between the
## lighting of the blocks" read, and it survives the veil being switched off entirely, which is how it was
## finally pinned on the palette rather than on the light. `check_grid` never saw it because it excludes
## pairs whose coarse parents hold different materials — reasonably, since dirt meeting stone SHOULD step.
## The defect is not that the contact is sharp. It is that the contact is a RECTANGLE.
##
## So the material LOOKUP is displaced: each fine cell asks which coarse cell it belongs to after a small
## noise offset, up to CONTACT_WARP fine cells. A cell's interior is unaffected — a displaced sample lands
## back in the same cell — and only the boundary moves, so every contact becomes a wandering line at 8px
## granularity instead of a 32px step. Nothing else changes: not the palette, not the tone, and not the
## SHAPE, which keeps reading `_solid_mask` at the true index so molding and AO are untouched.
const CONTACT_WARP: float = 3.2
const CONTACT_FREQ: float = 0.14                       ## ~7 fine cells per wiggle — a contact, not a fringe

const PATCH_FREQ: float = 0.045                        ## big low-freq tonal patches (~22 fine cells / ~2.7 cells)
const PATCH_AMP: float = 0.22                          ## value swing of the broad patches (lighter/darker rock)
const STONE_FREQ: float = 0.10                         ## embedded darker-stone blobs (~10 fine cells across)
const STONE_THRESH: float = 0.34                       ## noise above this darkens into an embedded stone
const STONE_RAMP: float = 1.6                          ## cells the blob's edge fades in over (1/ramp of noise range)
const STONE_DARKEN: float = 0.17                       ## how much a stone blob darkens the fill
const CRACK_FREQ: float = 0.09                         ## faint hairline cracks — ridged noise near its zero-crossing
const CRACK_BAND: float = 0.075                        ## |noise| under this is seam; wider = a line, not a dotted one
const CRACK_DARKEN: float = 0.15                       ## how dark a crack seam gets

## THE MATERIAL GRAMMARS (TR-02 / TR-04). Indexed by MaterialDef.grammar: 0 Clastic, 1 Bedded, 2 Massive.
##
## Until these existed this baker received one thing per cell — a COLOUR — so every solid material in the
## world ran the identical noise at a different hue, and the audit's "both read as square variation before
## material" was a structural fact rather than a tuning choice. No amplitude fixes a layer that cannot tell
## which material it is painting.
##
## The two ends are deliberately opposite in BOTH the cues a viewer has: how loud the surface is, and which
## way it runs. Soil is granular and clumpy and has no direction — loose ground does not fracture along
## planes. Stone is a quiet broad plane cut by steeply-dipping seams, so it is quieter AND directional, and
## its direction is the opposite of bedding's. A material told apart on only one of those is told apart by
## a knob rather than by a language.
enum { GRAM_CLASTIC = 0, GRAM_BEDDED = 1, GRAM_MASSIVE = 2 }
const GRAM_GRAIN: Array[float] = [1.60, 0.85, 0.30]    ## grain amplitude: soil granular, stone restrained
const GRAM_XSTR: Array[float] = [1.00, 0.35, 1.60]     ## <1 stretches features along the horizontal
const GRAM_CLUMP: Array[float] = [1.45, 0.60, 0.25]    ## embedded aggregate — pebbles in soil, not in stone
const GRAM_SEAM: Array[float] = [0.15, 1.20, 2.20]     ## fracture seam strength
## SEAM SAMPLING — and these were INVERTED for their whole first life, with a comment asserting the
## opposite of what the arithmetic did. `get_noise_2d(x * a, y * b)`: a LARGE multiplier makes the field
## vary fast on that axis, which makes features NARROW on it. So elongated-horizontally (bedding) needs a
## SMALL x and a LARGE y, and the original [3.00, 0.35] for Bedded gave features 3.7 cells wide by 31.7
## tall — vertical laminae, in the material named for flat ones. Massive had the mirror error.
##
## It was invisible to every number the layer prints because ANISO is disqualified by its own null rig, so
## the one cue that could have registered a direction error was excluded on independent grounds. Caught by
## computing 1/(freq * multiplier) per grammar and reading the answer against the comment.
const GRAM_SEAM_X: Array[float] = [1.00, 0.35, 3.40]   ## bedded runs FLAT (small x), massive runs STEEP
const GRAM_SEAM_Y: Array[float] = [1.00, 3.00, 0.40]
const GRAM_SEAM_W: Array[float] = [1.00, 1.35, 1.70]   ## seam band width — a plane's fracture is a LINE, not a fleck
## BROAD MASS BEFORE MICROTEXTURE, which is TR-03 and which is also what made the first attempt fail.
## The broad tonal patch field is the largest single variation term in this bake (PATCH_AMP 0.22, additive,
## against a grain term of 0.10 applied multiplicatively on near-black rock). While it was global it was a
## large material-BLIND variance sitting on top of every material's own signal, diluting exactly the
## difference the grammar was trying to state — the grain amplitudes differed by 2.9x and the measured
## separation moved four points. A material's broad mass is part of its language, not the world's: soil is
## mottled by compaction at large scale, a stone plane is quiet at large scale and speaks in its seams.
const GRAM_PATCH: Array[float] = [1.35, 1.00, 0.50]

## THE MARKS HAVE TO ARRIVE IN ABSOLUTE LEVELS, and this is the third time the same root cause has decided
## a ticket in this renderer. Everything above modulates `vmul`, which multiplies the material's own
## colour — and underground that colour is near-black. MEASURED: the sampled rock mean is ~10/255, so the
## whole +-0.16 grain swing lands as about 1.6 levels, against a measured within-window standard deviation
## of 4.5. The multiplicative marks are therefore a minority of the variation a viewer can see, which is
## why raising the earth/stone grain ratio from 2.9x to 5.3x moved separability two points: not because
## the grammar was absent, but because it was being written below the multiply.
##
## `rock_grit` lost the same argument to the darkness veil (6a) and was answered by `rock_tooth`, which
## adds ABOVE the veil in absolute levels. `_draw_edge_ao` lost it to the fine layer covering the coarse
## bake. So these are additive companions in value levels: what they write is what arrives, at any
## brightness. Kept SMALL — the tooth adds 0.030 at peak and reads clearly on dark rock, so a few
## thousandths is a legible mark underground and nothing at all in daylight.
## REMOVED AFTER MEASUREMENT, and the removal is the point. Additive companions to the marks below were
## added on the reasoning above — sound arithmetic, and the same root cause that decided 6a. They moved
## dirt-vs-stone separability 65% -> 64%, i.e. nothing, while costing two extra noise lookups per fine
## cell in the path `check_dig_hitch` guards. A mechanism that has been right twice is the one that stops
## being checked on its third outing; this was its third and it lost. The constraint above is still true
## and still worth reading — it is why the marks CANNOT read at depth — but "additive" turns out to be
## necessary rather than sufficient, and paying frame time for a disproved hypothesis is how a renderer
## accumulates weight. Reinstate only against a lit-band measurement that shows a need.
## ROCK HUE VARIATION (diff-04 #3): the reference rock isn't one blue-grey — it drifts subtly teal ↔
## faint brown ↔ faint violet by region. A very-low-freq 2-noise field picks a hue offset per region;
## kept DARK + subtle so it breaks the monochrome without turning the rock colourful.
const HUE_FREQ: float = 0.028                          ## enormous regions (~36 fine cells) so a whole face shares a tint
const HUE_AMP: float = 0.12                            ## strength of the region hue lerp (subtle)
const HUE_TEAL := Color(0.16, 0.30, 0.34)              ## cool teal pole
const HUE_BROWN := Color(0.30, 0.24, 0.17)             ## faint warm-brown pole
const HUE_VIOLET := Color(0.24, 0.18, 0.30)            ## faint violet pole
## MOSS on exposed rock TOPS (Noita diff 5): the topmost solid fine cells of a rock face (open air above)
## tint toward an olive/moss green — the mossy ledges of the reference. Confined to the top MOSS_DEPTH
## fine rows below the exposed surface, and only where enough open air sits above (a real ledge, not a
## crevice ceiling). Deterministic per fine cell — no RNG, determinism-safe.
const MOSS_COLOR := Color(0.25, 0.36, 0.15)            ## olive-moss green, darkened off the LAWN a saturated green
                                                      ## printed at 3x: growth ON rock, not green tiles
const MOSS_DEPTH: int = 3                              ## fine rows of moss below an exposed top edge (5 read as a
                                                      ## LAWN at 3x magnification; 3 is a damp rim on a ledge)
## MOSS IS ALIVE, and living things want light and water. Ungated, the band carpeted every exposed ledge
## at EVERY depth in saturated olive — a green lawn a hundred metres inside the earth, which is the
## loudest wrong note in the underground and reads instantly as a texture RULE rather than as a world.
## It now thins with depth and is gone below MOSS_DEAD_ROW, so the shallow ledges keep the damp growing
## look the reference has and the deep is bare rock, the way the deep should be.
const RIM_DEPTH: int = 2                               ## fine rows the lit lip fades over (1 = a dotted line)
const MOSS_LUSH_ROW: int = 22                          ## full moss down to here — the damp shallow ledges
const MOSS_DEAD_ROW: int = 34                          ## ...and none below here (14 m: roots and daylight end)
const MOSS_FREQ: float = 0.15                          ## breaks the moss into organic patches, not a solid band
                                                       ## (at 0.30 a patch was ~3 fine cells: green confetti,
                                                       ## the single loudest wrong note in the shallow rock)
## HANGING MOSS TUFTS (diff-04 #2): a few moss pixels drip BELOW down-facing overhangs (open air directly
## below a solid fine cell). Confined to the top HANG_DEPTH fine rows below such a lip, noise-masked so
## only the odd lip grows a tuft — the reference's hanging tufts under ledges.
const HANG_DEPTH: int = 3                              ## fine rows a tuft hangs below an overhang lip
const HANG_GATE: float = 0.30                          ## only lips whose moss-noise clears this hang a tuft (sparse)
## THE SOIL PROFILE (#S10) — the top of the underground is GROUND, not a fill colour.
##
## The opening frame's bottom half is the band directly under the grass, and it was painted with exactly
## the same rules as rock ninety metres down: one material colour, the same grain, the same everything. So
## the most-looked-at region in the game was also its least specific one, and a player looking down from
## spawn saw a brown rectangle rather than somewhere to dig.
##
## Real soil is strongly BANDED and every band is a different colour — dark organic humus right under the
## turf, a warmer mineral subsoil below it, then weathered rock. It also has things IN it, which rock does
## not: roots reaching down from whatever is growing above, and loose stones that are LIGHTER than the
## earth around them rather than darker (a cobble in dirt catches light; a stone inclusion in rock does
## not). All three are functions of depth-below-this-column's-own-surface, so a hillside's profile follows
## the hill instead of lying in flat world rows.
const SOIL_ROWS: int = 40                 ## fine rows below a column's surface the profile spans (10 cells)
const HUMUS_ROWS: int = 5                 ## the dark organic band right under the turf
const HUMUS_DARKEN: float = 0.26          ## how much darker humus is than the earth below it
const SUBSOIL_ROWS: int = 20              ## the warm mineral band under the humus
const SUBSOIL_WARM: float = 0.13          ## how far the subsoil lifts toward its own warm pole
const SUBSOIL_POLE := Color(0.52, 0.35, 0.18)   ## iron-stained ochre — what makes a subsoil read as subsoil
## ROOTS. Thin, near-vertical, dark, and reaching DOWN from the turf line — the one feature that says the
## surface above is alive and the ground below it is connected to it. Noise picks which columns grow one
## and how far it reaches, so they are sparse and uneven rather than a fringe.
const ROOT_FREQ: float = 0.14             ## along-X: roots cluster where growth clusters
const ROOT_GATE: float = 0.34             ## noise above this grows a root (sparse — most columns have none)
const ROOT_MAX: int = 26                  ## deepest a root reaches, in fine rows
const ROOT_DARKEN: float = 0.30
## COBBLES AND CLASTS. Soil is a MIXTURE, not a solid, and that is the difference the eye actually reads
## between dirt and rock: rock is one substance with texture on it, soil is full of things that are not
## soil. So the same inclusion field the rock reads as a dark embedded stone is read here at a far lower
## threshold and in BOTH directions — pale cobbles where it runs high (a stone in dirt catches light) and
## dark clasts where it runs low. Same geometry, seen from two sides, at three times the density.
## Read at COBBLE_SCALE the inclusion field gives PEBBLES rather than boulders, which is the difference
## between soil and rubble — and it is a difference the eye is very sure about. Read at the rock's own
## scale and threshold the first attempt turned the whole opening frame into a gravel pit that scored
## beautifully on every content metric and looked worse than the dead gradient it replaced.
const COBBLE_SCALE: float = 1.9           ## finer than the rock's inclusions — stones, not outcrops
const COBBLE_THRESH: float = 0.26
const COBBLE_LIGHTEN: float = 0.26
const CLAST_THRESH: float = -0.30         ## ...and below this the inclusion is a dark lump instead
const CLAST_DARKEN: float = 0.20
## THE ROCK GETS A TOP AND A BOTTOM (#S8).
##
## Everything above this line is TEXTURE: noise that says what the rock is MADE of. None of it says which
## way a surface FACES, and a surface that faces nowhere is a flat sheet with a pattern printed on it.
## That is most of what is left of "it still reads 2D" — the interior of every rock face was painted at
## exactly one brightness, and the only thing separating a floor from a ceiling was a two-row rim.
##
## Light underground arrives from above and from whatever you have cut open. So a cell brightens by how
## close it sits under open sky-ward air and darkens by how directly it hangs beneath an overhang, and
## both fall off over FORM_REACH rows rather than two — because the eye reads a GRADIENT as a curved
## surface and a step as an edge, which is the whole difference between a lit shelf and a lit line.
##
## It is deliberately one-directional. An isotropic "distance from air" term is ambient occlusion and
## makes rock look soft; a directional one is a key light and makes rock look SOLID. The rim highlight
## survives on top of it, cut back, because a crisp one-row lip is what keeps the silhouette readable
## once the body of the face has a gradient of its own.
const FORM_REACH: int = 6              ## fine rows the sky-ward gradient falls over (~1.5 coarse cells)
const FORM_LIFT: float = 0.22          ## brightening at a cell with open air directly above it
const FORM_SINK: float = 0.13          ## darkening at a cell hanging directly under an overhang
## RECESSED BACK-ROCK (fix-2 diff 6): the cool tone the eroded/back-wall fine cells shift toward, so the
## rock BEHIND the carved foreground reads as a distinct, cooler, set-back layer (Noita's fore/background
## rock depth) instead of a flat near-black void.
const BACKROCK_COOL := Color(0.10, 0.15, 0.20)
## THE BACK WALL IS A SURFACE (#S13) — and until now it was the one large thing on screen that was not.
##
## Everything above this line paints the rock you have NOT dug. The moment you dig, what fills the frame is
## the BACK WALL, and it was drawn by the coarse pass as `draw_rect(cell, one_colour)` plus two speckles and
## an occasional fissure: one flat fill per 32px cell, carrying the same `_strata` quantised to the coarse
## row that #S12 just took out of the foreground. So the better the front rock got, the more the wall behind
## it read as cardboard — and a player spends the entire game looking at it, because it is the inside of
## every shaft, room and gallery they have ever cut.
##
## It moves here, to fine resolution, for the same reason the foreground did: this is where the grain, the
## reconstructed tone and the per-8px shape already live. The coarse pass keeps drawing walls underneath at
## z -10 (harmless, and it is the fallback if this layer is ever off); the fine layer covers it at z -9, and
## nothing else in the game draws in between.
##
## The cast shadow has to come with it. The coarse pass carried the wall's whole sense of depth in AO strips
## along the cell edges — "the recess is carried by the cast shadows above" — and covering that up without
## replacing it would flatten the wall even as the tone improved. `_wall_shade` re-casts it from the fine
## grid, directionally: rock overhead is the deepest shadow, rock to the side less, a floor below least,
## because light reaches a floor.
const WALL_RECESS: float = 0.32                        ## how far the back plane sits behind the front one, in value
const WALL_COOL := Color(0.16, 0.19, 0.30)             ## the cool it drifts toward (distance desaturates)
const WALL_STRATA_QUIET: float = 0.7                   ## the same beds, a little quieter back there
const WALL_AO_UNDER: float = 0.62                      ## cast shadow under a solid ceiling — the deepest
const WALL_AO_SIDE: float = 0.34                       ## …beside a solid wall
const WALL_AO_ABOVE: float = 0.16                      ## …over a solid floor: light reaches a floor
const WALL_AO_REACH: int = 5                           ## fine cells the cast fades over (~1.2 coarse cells)
const WALL_AO_MAX: float = 0.74                        ## a corner stacks three casts; it may not reach black
## The wall is a DISTANT plane, so its texture is deliberately quieter than the foreground's. Matching the
## front rock's grain amplitude here would collapse the depth cue the recess exists to create: two surfaces
## at the same visual roughness read as one surface.
## THE VOID IS OPAQUE TOO, AND THAT BROKE THE ONE MASK THAT MATTERED. `rock_grit.gdshader` is titled
## "SUB-CELL TOOTH FOR THE ROCK" and says "air gets none of this", masking with `step(0.004, COLOR.a)`.
## But only the SKY is cleared here — both void branches (the back wall you have dug into, and the wall
## behind a foreground shelf) write alpha 255 exactly like solid rock. So the tooth written to make rock
## read as rock has been applied to the void at equal strength for its whole life, and the measurement
## says so: air's local grain is 2.06 against rock's 1.83. **The void is textured slightly MORE than the
## material.** That is not a tuning problem and no amplitude fixes it — texturing both equally cannot
## separate them by construction.
##
## One level of alpha, invisible at 254/255 on an opaque layer, gives the pass something true to mask on.
const VOID_ALPHA: int = 254

const WALL_GRAIN: float = 0.055
const WALL_PATCH: float = 0.11

## Apply a wall's strata to its base body colour, then set it back. THE single authority for what a wall
## colour is — the coarse pass calls it per cell, the fine pass per fine cell with a reconstructed strata,
## so the two cannot drift apart. Order matters and matches the original: bedding rides on the material's
## own colour, and the recess + cool are applied last, to the result.
static func apply_wall_tone(base: Color, strata: float) -> Color:
	var col: Color = base.lightened(strata * 0.85) if strata > 0.0 else base.darkened(-strata * 1.05)
	return col.darkened(WALL_RECESS).lerp(WALL_COOL, 0.30)
## COOL SHADOW tint (fix-2 diff 3): carved/AO-shadowed foreground rock is lerped toward this cold
## teal-blue so shadows read blue-grey (the reference's cold rock), not the warm brown murk of pass-1.
const SHADOW_TEAL := Color(0.13, 0.20, 0.27)
## THE COARSE TONE, RECONSTRUCTED (#S12) — the last thing in the rock that still knew where the grid was.
##
## Everything above this line is sampled per FINE cell and measured by check_texture. All of it is painted
## on top of a BASE colour the renderer computes per COARSE cell, and that base carries two deliberately
## smooth low-frequency fields: a cloudy value jitter and the sedimentary banding. Their own source calls
## for "cloudy patches ... NOT a per-cell random that seams at every tile edge (which just rebuilds the
## grid)" — and then evaluates them once per 32px cell, which is precisely how you rebuild the grid. A
## smooth field held constant across a 4x4 block is a mosaic, every one of its steps lands on a coarse
## boundary, and both terms are multiplied by up to 3.2x with depth, so the mosaic shouts loudest exactly
## where the game is played. Measured before the fix (tools/check_grid): crossing a coarse ROW stepped
## 2.38x harder than the rock's own grain, which is a hard horizontal rule drawn across the whole world
## every 32 pixels — read as "flat", "blocky", "tiled", and impossible to unsee once you have seen it.
##
## The fix is not new art, it is not resampling the fields, and it changes no cell's centre: the renderer
## still hands over ONE tone per coarse cell, and the paint BILINEARLY reconstructs the field between
## those samples. Mapping fine cell centres to continuous coarse coordinates puts the samples on an even
## 1/SUBDIV lattice, so the reconstruction steps by exactly the same amount everywhere and the boundary
## stops being special. Cost is four array reads and three lerps per fine cell — no extra Callable, no
## extra noise, and the per-dig fast lane is untouched because a tone never changes when you mine.
const STRATA_WARM := Color(0.86, 0.74, 0.52)   ## the sandy band
const STRATA_COOL := Color(0.15, 0.16, 0.21)   ## the cool clay/silt band

## Apply a (jitter, strata) tone to a base body colour. THE single authority for what a tone means — the
## coarse pass calls it per cell and the fine pass calls it per fine cell with a reconstructed tone, so
## the two passes cannot drift apart. Both terms arrive already scaled by the renderer's depth boost.
static func apply_tone(base: Color, tone: Vector2) -> Color:
	var col: Color = base.lightened(tone.x) if tone.x > 0.0 else base.darkened(-tone.x)
	if tone.y > 0.0:
		return col.lightened(tone.y * 0.85).lerp(STRATA_WARM, tone.y * 0.30)
	return col.darkened(-tone.y * 1.05).lerp(STRATA_COOL, -tone.y * 0.20)


var _cols: int
var _rows: int
var _fcols: int                                        ## fine-grid width  = cols * SUBDIV
var _frows: int                                        ## fine-grid height = rows * SUBDIV
var _noise: FastNoiseLite                              ## low-freq tonal drift over the real fine shape
var _grain: FastNoiseLite                              ## dense speckle field (diff 4)
var _grain2: FastNoiseLite                             ## crisp grit octave
var _moss: FastNoiseLite                               ## moss patch mask (diff 5)
var _root: FastNoiseLite                               ## which columns grow a root, and how deep (#S10)
var _patch: FastNoiseLite                              ## broad tonal patches (diff-04 #1)
var _warp: FastNoiseLite                               ## displaces the MATERIAL lookup so contacts wander
var _stone: FastNoiseLite                              ## embedded darker-stone blobs (diff-04 #1)
var _crack: FastNoiseLite                              ## hairline crack seams (diff-04 #1)
var _huex: FastNoiseLite                               ## region hue field, x axis (diff-04 #3)
var _huey: FastNoiseLite                               ## region hue field, y axis (diff-04 #3)
var _img: Image
var _tex: ImageTexture
# Persisted caches so a per-dig rebake can patch a SUB-RECT instead of the whole grid (#102 dirty-chunks).
# The full rebake fills them; rebake_region refreshes only the changed cells + reads neighbours from these.
var _data: PackedByteArray = PackedByteArray()          ## the baked pixel bytes (region rebakes overwrite a sub-rect)
var _fine_solid: PackedByteArray = PackedByteArray()    ## the real fine solid/air grid (neighbours for region AO/moss)
var _solid_mask: PackedFloat32Array = PackedFloat32Array()  ## coarse solidity 0/1
var _mat_col: PackedColorArray = PackedColorArray()     ## coarse body BASE colour, tone NOT yet applied
var _mat_gram: PackedByteArray = PackedByteArray()      ## coarse body texture GRAMMAR (see GRAM_* above)

## OPTIONAL per-coarse-cell grammar lookup: (Vector2i) -> int. Left unset every cell reads Clastic, which
## is byte-identical to the behaviour before grammars existed — deliberately, because `rebake` has eight
## call sites across five files and one of them passes its arguments positionally out of an array. A new
## required parameter would have churned five harness fixtures to say "unchanged".
##
## THE COST OF THAT CHOICE, PAID ONCE ALREADY: this is an INPUT to the bake that does not appear in the
## bake's signature, so a caller can omit it and get a silently different world rather than an error.
## Anyone constructing a second FineTerrain to compare against the renderer's — `check_dig_hitch` builds
## one to prove the region path is byte-identical to the full path — MUST copy this across, or the two
## differ by configuration while the comparison claims they differ by path.
var grammar_at: Callable = Callable()
var _tone: PackedVector2Array = PackedVector2Array()    ## coarse (jitter, strata) samples, reconstructed per fine cell
var _wall_col: PackedColorArray = PackedColorArray()    ## coarse back-wall BASE colour, tone NOT applied
var _wall_has: PackedByteArray = PackedByteArray()      ## #S13: 1 where the coarse cell actually HAS a wall
var _surf_row: PackedInt32Array = PackedInt32Array()    ## walkable surface row per column (cap band)
var last_baked_cells: int = 0                           ## fine cells the LAST bake touched — the dig-hitch friction gauge (#103)
## FINE CELLS THE LAST `rebake` PAINTED BEFORE RETURNING — the cost that is actually in front of the first
## frame, which `last_baked_cells` stopped being able to answer the moment bakes became progressive. Every
## `bake_pending` slice and every per-dig region bake overwrites `last_baked_cells`, so a reader who asks it
## "how big was the boot bake?" ten frames later gets the size of the most recent 4ms fill slice instead.
## That is not a hypothetical: it is what `check_dig_hitch` measured, and it reported 1024 for a bake of
## tens of thousands of cells. Written by `rebake` and by nothing else.
var opening_baked_cells: int = 0
## PROGRESSIVE BAKE STATE (#17). -1 = nothing outstanding; otherwise the next fine ROW `bake_pending` owes.
var _pending_fy: int = -1
## The fine-cell rect the opening bake already painted, skipped while filling the rest.
var _painted_view: Rect2i = Rect2i()
## Fine-cell dilation for a region rebake: must cover the widest neighbour reach any paint term reads so a
## patched region is byte-identical to a full bake — MOSS_DEPTH(3 up) / HANG_DEPTH(3 down) / SUBDIV(4,
## accretion). RIM_DEPTH(2), WALL_AO_REACH(5) and _moss_life (a pure function of the row) are all inside it.
const REGION_MARGIN: int = 6


## Build one texture field, with its FRACTAL TAIL CAPPED. FastNoiseLite defaults to 5-octave FBM, and
## each octave doubles the frequency — so a field whose BASE frequency resolves on the fine grid still
## ships three or four octaves that do not, and those octaves are white noise mixed straight into the
## result. That default is the systemic cause of "the rock reads as static": every field here was quietly
## carrying an aliased tail. `octaves` is chosen per field so its HIGHEST octave still has a period of
## more than two samples; check_texture measures the result rather than trusting the arithmetic.
static func _field(seed: int, salt: int, type: FastNoiseLite.NoiseType, freq: float,
		octaves: int = 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed ^ salt
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_NONE if octaves <= 1 else FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = maxi(octaves, 1)
	return n


func _init(cols: int, rows: int, seed: int) -> void:
	_cols = cols
	_rows = rows
	_fcols = cols * SUBDIV
	_frows = rows * SUBDIV
	# Octave budgets: a field is allowed as many octaves as keep its top one resolvable on this grid.
	_noise = _field(seed, 0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, TONAL_FREQ, 3)
	_grain = _field(seed, 0x27d4eb2f, FastNoiseLite.TYPE_SIMPLEX, GRAIN_FREQ)
	_grain2 = _field(seed, 0x165667b1, FastNoiseLite.TYPE_VALUE, GRAIN_FREQ2)   ## crisper grit
	_moss = _field(seed, 0x9e3779b1, FastNoiseLite.TYPE_SIMPLEX, MOSS_FREQ)
	_root = _field(seed, 0x7feb352d, FastNoiseLite.TYPE_SIMPLEX, ROOT_FREQ)
	# diff-04 #1 — broad tonal patches + embedded stones + cracks (each its own seed so they don't correlate).
	_patch = _field(seed, 0x2545f491, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, PATCH_FREQ, 3)
	_warp = _field(seed, 0x6f4f2b91, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, CONTACT_FREQ, 2)
	# Both are THRESHOLDED downstream, so neither may carry an octave tail: doubling the frequency once
	# puts detail at the grid's own scale, and a threshold on that prints the blob as scattered squares
	# and the crack as dots. One octave each — the shape is the point, not the roughness of its edge.
	_stone = _field(seed, 0x1b873593, FastNoiseLite.TYPE_SIMPLEX, STONE_FREQ)
	_crack = _field(seed, 0x85ebca77, FastNoiseLite.TYPE_SIMPLEX, CRACK_FREQ)
	# diff-04 #3 — two independent low-freq fields → a region hue offset picked per broad region.
	_huex = FastNoiseLite.new()
	_huex.seed = seed ^ 0xc2b2ae35
	_huex.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_huex.frequency = HUE_FREQ
	_huey = FastNoiseLite.new()
	_huey.seed = seed ^ 0x27d4eb2f
	_huey.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_huey.frequency = HUE_FREQ
	_img = Image.create(_fcols, _frows, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)


func texture() -> Texture2D:
	return _tex


## World-space rect the baked texture covers (the whole world, stretched 1 fine texel = FINE px).
func world_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(_cols * CELL_PX()), float(_rows * CELL_PX()))


static func CELL_PX() -> int:
	return SUBDIV * FINE   # 32


## The topmost fine-row band of a column's walkable surface cell the mold leaves to the COARSE cap: the
## grass/lip + ramp cap draws below (z -10) and must stay legible + exactly on the walked line, so the
## mold doesn't paint over it. Small (SURFACE_KEEP fine rows ≈ the cap thickness) so the rock just below
## the grass is still fully molded.
const SURFACE_KEEP: int = 2

## "THIS COLUMN HAS NO WALKED SURFACE" — the value `_surf_row` holds for a column that is a hole.
##
## The authority it caches, `FactorySim.surface_row`, returns the first solid cell scanning from row 0 and
## has no memory of the original ground. That is correct at generation time and wrong the moment anybody
## digs: sink a shaft and the function answers with the rock at the BOTTOM of it, so every consumer that
## means *the walked ground* is handed a row forty tiles down and dresses it as ground. Both of this file's
## consumers did. The cap band left the top of that cell transparent so the coarse grass could show
## through, which is why `_moment_boot.png` has a GRASS-CAPPED LEDGE eight hundred pixels underground; and
## `_soil` keyed its humus/subsoil profile to depth below it, which painted TOPSOIL COLOUR at the foot of
## any shaft — the exact case its own docstring promises is "left alone entirely".
##
## The bound is derived, not guessed: `HeightmapWorldGen.ground_row` clamps every column into
## [SURFACE_ROW_MIN, SURFACE_ROW_MAX], so a first-solid below that band is provably not ground.
##
## KNOW WHAT THIS IS AND IS NOT. It is a REJECTION test, and it can only reject what leaves the band: a
## rift floor at row 70, yes; the ten-row shaft you dug from row 20 down to row 30, no — that answer is
## still inside [MIN, MAX] and still comes back dressed as ground. That is the right trade for the passes
## below, which paint, and for which the visible failure was grass eight hundred pixels underground. It is
## the WRONG tool for anything asking *how deep am I*, because the shallow shaft is exactly the case those
## consumers live in. Where the caller has a COLUMN rather than a row, `HeightmapWorldGen.ground_row(col)`
## answers directly and without the hole in the middle.
const NO_SURFACE: int = -1


## `FactorySim.surface_row`'s answer, or NO_SURFACE when that answer is a hole floor rather than ground.
##
## Static and public because FOUR passes across three files ask this question and every one of them was
## getting it wrong the same way — `TerrainPainter` (the cap/ramp pass that draws the grass, plus both
## chamfer `keep_top` tests), `WorldRenderer._draw_background`, and this file's mold. Six copies of one
## bound is how the next consumer gets written without it, so there is one.
static func walked_surface(row: int) -> int:
	return row if row <= HeightmapWorldGen.SURFACE_ROW_MAX else NO_SURFACE

## Rebake the fine terrain into the Image + upload. The Callables let the paint reuse the exact palette /
## surface authority the coarse pass uses:
##   solid_at(Vector2i) -> bool              (the COARSE cell — parent solidity, for colour + accretion source)
##   fine_solid_at(int fx, int fy) -> bool   (P2: the REAL fine terrain grid from the sim — the molded shape)
##   material_color_at(Vector2i) -> Color    (the coarse cell's body BASE colour, tone NOT applied)
##   tone_at(Vector2i) -> Vector2            (#S12: that cell's (jitter, strata) sample, reconstructed here)
##   wall_color_at(Vector2i) -> Color        (the back-wall colour to show where solid rock is ERODED to air)
##   surface_at(int col) -> int              (the walkable surface row of a column; its cap is left uncovered)
## P2: the fine SHAPE now comes from the sim's real fine grid (fine_solid_at) instead
## of a molded field computed here from the coarse mask — real fine DATA reads crunchier + carries whatever
## detail worldgen put there. The renderer keeps ownership of the LOOK (AO, grain, moss, rim, palette).
## Runs the WHOLE fine grid; called on the initial paint + a wholesale change (load/repaint_world). The
## per-dig fast lane is rebake_region (dirty-chunks, #102). Fills the persisted caches, then paints every
## fine cell via _paint_fine (shared with the region path).
## `fine_solid_bulk` is the sim's fine grid handed over WHOLE instead of read a cell at a time. It is
## optional and the per-cell Callable remains the fallback, so callers that have no array (check_texture
## builds a synthetic world) are unaffected. See the loop below for why it exists.
## `view` is the world-space rectangle the player can actually SEE, and passing one turns the bake
## PROGRESSIVE: the visible fine cells are painted now and the rest are owed to `bake_pending`. Left empty
## (every existing caller, and both harness layers) the whole grid is painted in one go, exactly as before.
## See `bake_pending` for why this is safe and what the world looks like in between.
func rebake(solid_at: Callable, fine_solid_at: Callable, material_color_at: Callable, wall_color_at: Callable,
		surface_at: Callable, tone_at: Callable, has_wall_at: Callable,
		fine_solid_bulk: PackedByteArray = PackedByteArray(), view: Rect2 = Rect2()) -> void:
	# The walkable-surface row per column (cache the coarse authority once) so the mold can leave that
	# cell's cap band to the coarse grass/ramp pass beneath it.
	_surf_row.resize(_cols)
	for cx: int in _cols:
		_surf_row[cx] = walked_surface(int(surface_at.call(cx)))
	# Coarse solid mask (0.0/1.0): a single lookup per coarse cell instead of SUBDIV² per fine.
	_solid_mask.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			_solid_mask[cy * _cols + cx] = 1.0 if bool(solid_at.call(Vector2i(cx, cy))) else 0.0
	# Cache coarse colours once per cell (reused by all SUBDIV² children).
	_mat_col.resize(_cols * _rows)
	_mat_gram.resize(_cols * _rows)
	_wall_col.resize(_cols * _rows)
	# The tone is sampled on EVERY cell, solid or not: the reconstruction below reads a fine cell's four
	# surrounding coarse samples, and an air cell beside a rock face is one of them.
	_tone.resize(_cols * _rows)
	_wall_has.resize(_cols * _rows)
	for cy: int in _rows:
		for cx: int in _cols:
			var idx: int = cy * _cols + cx
			# One Vector2i per cell rather than four identical ones — same four Callables, a quarter of
			# the allocations feeding them.
			var cell := Vector2i(cx, cy)
			# THE GRAMMAR IS WRITTEN ON EVERY CELL, solid or not, for the same reason the tone above is:
			# the reconstruction reads a fine cell's surrounding coarse samples and an air cell beside a
			# rock face is one of them. Leaving air cells unwritten is what broke byte-identity — an
			# unwritten entry keeps whatever an earlier bake left, a fresh instance holds zero, and the two
			# disagree by a couple of pixels in accreted rock. Stale is not merely wrong, it is
			# INSTANCE-DEPENDENT, which is the one thing a region-vs-full comparison cannot tolerate.
			_mat_gram[idx] = _grammar_of(cell) if _solid_mask[idx] > 0.5 else GRAM_CLASTIC
			if _solid_mask[idx] > 0.5:
				_mat_col[idx] = material_color_at.call(cell) as Color
			_wall_col[idx] = wall_color_at.call(cell) as Color
			_tone[idx] = tone_at.call(cell) as Vector2
			_wall_has[idx] = 1 if bool(has_wall_at.call(cell)) else 0
	_data.resize(_fcols * _frows * 4)
	# Read the REAL fine solid/air shape from the sim's fine grid (P2 — the molding lives in the sim's fine
	# DATA), stashed so the paint can read neighbours for fine AO.
	# ONE COPY INSTEAD OF 262144 DYNAMIC DISPATCHES. This loop called a Callable once per fine cell to read
	# an array the sim already holds — `FactorySim._fine_solid`, a PackedByteArray of 0/1 with the same
	# `fy * width + fx` layout and the same dimensions — so the whole loop is a memcpy. Duplicated rather
	# than aliased: the baker's copy is a SNAPSHOT, and rebake_region writes into it later.
	#
	# WHAT IT ACTUALLY BOUGHT, because this comment used to claim otherwise and the claim was wrong. It
	# read "the bake measured 1671.79ms — 6.377us per cell … at a quarter of a million invocations it
	# dominates everything the bake actually computes." Neither half survived being measured (`25494c4`):
	#
	#   full bake, per-cell Callable   1695.31 ms   6.467 us/cell
	#   full bake, bulk fine grid      1520.65 ms   5.801 us/cell   1.11x
	#
	# 175ms — about 10%, not the 10x the dispatch count suggested, and nothing near "dominates". The
	# hypothesis was reasonable and the arithmetic was seductive; it was still a guess, and the number in
	# the comment was neither of the two the benchmark later produced.
	#
	# DO NOT RE-DERIVE THIS THE HARD WAY. The other obvious candidate is also dead: the eight
	# get_noise_2d() calls per fine cell measure 16% (246.84ms, `9bac504`, instrument at
	# tools/measure_bake_noise.gd). The remaining ~74% is the REST of `_paint_fine` — Color allocation and
	# lerps, apply_tone, _contact_index, _accreted_color, the neighbour scans — with no hotspot at all,
	# just a hundred interpreted operations across 262144 iterations. Micro-optimisation cannot reach a
	# diffuse 74%. The two options that preserve the output byte-identically are baking the visible region
	# first and filling outward on later frames, or getting the bake off the main thread.
	#
	# The Callable path is kept, and is not dead code: check_texture bakes a synthetic world that has no
	# sim behind it. A size mismatch also falls back here rather than baking a wrong-shaped grid.
	if fine_solid_bulk.size() == _fcols * _frows:
		_fine_solid = fine_solid_bulk.duplicate()
	else:
		_fine_solid.resize(_fcols * _frows)
		for fy: int in _frows:
			for fx: int in _fcols:
				_fine_solid[fy * _fcols + fx] = 1 if bool(fine_solid_at.call(fx, fy)) else 0
	_pending_fy = -1
	_painted_view = _fine_rect(view)
	if _painted_view.size == Vector2i.ZERO:
		for fy: int in _frows:
			for fx: int in _fcols:
				_paint_fine(fx, fy)
		last_baked_cells = _fcols * _frows
		opening_baked_cells = last_baked_cells
	else:
		# A partial bake leaves cells UNWRITTEN, and on a re-bake (a save load) those cells still hold the
		# previous world's pixels. Clearing to transparent is what makes the unpainted region fall through
		# to the coarse pass instead of showing somewhere else's rock. One memset of ~1MB.
		_data.fill(0)
		for fy: int in range(_painted_view.position.y, _painted_view.end.y):
			for fx: int in range(_painted_view.position.x, _painted_view.end.x):
				_paint_fine(fx, fy)
		last_baked_cells = _painted_view.size.x * _painted_view.size.y
		opening_baked_cells = last_baked_cells
		_pending_fy = 0
	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, _data)
	_tex.update(_img)


## The fine-cell rect a world-space rectangle covers, clamped to the grid. An empty or off-world rect
## returns a zero-size rect, which is the "bake everything at once" signal.
func _fine_rect(view: Rect2) -> Rect2i:
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return Rect2i()
	var x0: int = clampi(int(floor(view.position.x / float(FINE))), 0, _fcols)
	var y0: int = clampi(int(floor(view.position.y / float(FINE))), 0, _frows)
	var x1: int = clampi(int(ceil(view.end.x / float(FINE))), 0, _fcols)
	var y1: int = clampi(int(ceil(view.end.y / float(FINE))), 0, _frows)
	if x1 <= x0 or y1 <= y0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## PAINT WHAT THE PLAYER CANNOT SEE YET, A SLICE PER FRAME (#17). Returns true while work remains.
##
## The full bake is 262144 fine cells and it is not fast: 1199ms on this machine after the peer's loop
## work, ~4.6us a cell. Every millisecond of it is spent before the first frame, and the profiling that
## went looking for the hotspot found there isn't one — the bulk fine-grid handover bought 11%, the eight
## noise calls per cell are 16%, and the remaining ~74% is `_paint_fine` itself, a hundred interpreted
## operations with no peak anywhere in it. `rebake`'s own comment states the conclusion: micro-optimisation
## cannot reach a diffuse 74%, and the two options that preserve the output EXACTLY are baking the visible
## region first or getting the bake off the main thread. This is the first one.
##
## WHY IT IS SAFE, and the reason is a property of `_paint_fine` rather than a promise about this function:
## it reads only the coarse caches, `_fine_solid`, `_surf_row` and the noise fields — every one of which is
## fully populated by `rebake` BEFORE any painting starts — and writes only its own four bytes. So the
## painting order over the grid cannot affect the result, ANY partition of the cells yields the same image,
## and a progressive bake is byte-identical to a single-shot one by construction rather than by testing.
## `tools/check_progressive_bake.gd` asserts it anyway, because "by construction" is what every one of this
## project's vacuous guards also said.
##
## WHAT THE WORLD LOOKS LIKE IN BETWEEN: unpainted fine cells are transparent, and the coarse terrain pass
## still draws underneath at z -10 — the same fallback that covers this layer being switched off entirely.
## So the not-yet-filled region reads as the old blocky 32px terrain, not as a hole, and it is off-screen
## anyway unless the camera outruns the fill.
##
## THE BUDGET IS TIME, NOT CELLS, because the point is to fit inside a frame and a cell count that fits on
## this machine does not fit on a slower one. Granularity is one fine ROW — 384 cells, ~1.8ms — so a budget
## can overshoot by that much and one row is always painted however small the budget is. Progress is
## guaranteed: a budget of zero still advances a row per call rather than stalling forever.
##
## Deliberately NOT self-driving off a timer inside this class. The caller owns the frame, knows whether it
## is mid-dig, and is the only one that can decide this frame has 4ms to spare.
func bake_pending(budget_usec: int = 4000) -> bool:
	if _pending_fy < 0:
		return false
	var t0: int = Time.get_ticks_usec()
	var painted: int = 0
	while _pending_fy < _frows:
		var fy: int = _pending_fy
		var skip: bool = fy >= _painted_view.position.y and fy < _painted_view.end.y
		for fx: int in _fcols:
			if skip and fx >= _painted_view.position.x and fx < _painted_view.end.x:
				continue
			_paint_fine(fx, fy)
			painted += 1
		_pending_fy += 1
		if Time.get_ticks_usec() - t0 >= budget_usec:
			break
	last_baked_cells = painted
	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, _data)
	_tex.update(_img)
	if _pending_fy >= _frows:
		_pending_fy = -1
		return false
	return true


## Fine rows still owed by a progressive bake — 0 when the grid is whole. The harness reads it; so does any
## caller that wants to know whether the world it is looking at is finished.
func pending_rows() -> int:
	return 0 if _pending_fy < 0 else _frows - _pending_fy


## FINISH THE OUTSTANDING FILL NOW, in one call. Returns the rows it had to paint.
##
## This exists because THREE harness layers needed it within an hour of #17 landing, each with its own
## paragraph explaining the same thing, and a rule retyped three times is a rule about to be typed wrong a
## fourth. They need it for two different reasons and both are legitimate:
##
##   * a layer that JUDGES the baked image (`check_grid` reads `_data` directly) must judge a WHOLE one.
##     Unpainted cells are transparent, its sweeps skip transparent cells, and it failed on a sample too
##     thin to mean anything rather than on anything about the rock.
##   * a layer that TIMES frames (`check_frametime`) must not catch the tail of the boot fill inside a
##     phase named IDLE, because every ratio it reports divides by IDLE.
##
## Neither is hiding a cost. The fill is a boot transient that happens once and never again, and a layer
## that measured it would be reporting it under the wrong name. What SHOULD measure it is a layer named for
## it — `check_progressive_bake` — and what should measure a dig landing during it is `check_dig_hitch`,
## which now does, before it calls this.
func finish_pending() -> int:
	var owed: int = pending_rows()
	while bake_pending(1 << 30):
		pass
	return owed


## The fine-cell rect the last `rebake` painted before returning; zero-size after a whole-grid bake.
##
## Exposed so the CONTRACT can be asserted rather than the cell count. "The opening bake is bigger than a
## dig" is a number that happened to be in scope; "the opening bake contains the body" is the property, and
## it is the one that fails when a caller hands over a rect built from a camera that has not moved onto the
## player yet — which is a real thing that happened, and which a cell-count floor near 4096 waved through.
func opening_rect() -> Rect2i:
	return _painted_view


## The baked pixel bytes, for a test that wants to compare two bakes WITHOUT going through the texture.
## `texture().get_image()` returns a blank surface under the headless driver, which is how one byte-identity
## assertion in this project passed for its whole life while comparing two blank images. These bytes are
## CPU-side and are the same in both drivers.
func baked_bytes() -> PackedByteArray:
	return _data


## THE PER-DIG FAST LANE (#102 dirty-chunks — the mining micro-freeze fix). Rebake ONLY the fine cells under
## the changed coarse cells [cmin..cmax] WIDENED by the sim's SYNC_BAND re-mold ring, then DILATED by
## REGION_MARGIN so every neighbour-reading paint term (AO / moss / accretion / rim) recomputes exactly as
## a full bake would → the output is byte-identical to rebake() but touches ~576 cells for a single dig,
## not the whole 262k grid. Falls back to a full rebake if the grid was never fully baked (nothing cached
## to patch). Callables match rebake()'s.
func rebake_region(cmin: Vector2i, cmax: Vector2i, solid_at: Callable, fine_solid_at: Callable,
		material_color_at: Callable, wall_color_at: Callable, surface_at: Callable, tone_at: Callable,
		has_wall_at: Callable) -> void:
	if _data.size() != _fcols * _frows * 4:
		rebake(solid_at, fine_solid_at, material_color_at, wall_color_at, surface_at, tone_at, has_wall_at)
		return
	cmin.x = maxi(cmin.x, 0)
	cmin.y = maxi(cmin.y, 0)
	cmax.x = mini(cmax.x, _cols - 1)
	cmax.y = mini(cmax.y, _rows - 1)
	if cmin.x > cmax.x or cmin.y > cmax.y:
		return
	# 1) Refresh the coarse caches for the changed cells only (a handful — cheap). Neighbour coarse cells the
	#    dilated paint reads keep their persisted values (they didn't change).
	for cx: int in range(cmin.x, cmax.x + 1):
		_surf_row[cx] = walked_surface(int(surface_at.call(cx)))
	for cy: int in range(cmin.y, cmax.y + 1):
		for cx: int in range(cmin.x, cmax.x + 1):
			var idx: int = cy * _cols + cx
			var s: bool = bool(solid_at.call(Vector2i(cx, cy)))
			_solid_mask[idx] = 1.0 if s else 0.0
			if s:
				_mat_col[idx] = material_color_at.call(Vector2i(cx, cy)) as Color
				_mat_gram[idx] = _grammar_of(Vector2i(cx, cy))
			else:
				_mat_gram[idx] = GRAM_CLASTIC   # never leave an entry to go stale — see rebake()
			_wall_col[idx] = wall_color_at.call(Vector2i(cx, cy)) as Color
			_wall_has[idx] = 1 if bool(has_wall_at.call(Vector2i(cx, cy))) else 0
	# _tone is deliberately NOT refreshed: a tone is a pure function of (x, y), so mining cannot change
	# one. Leaving the cache alone is what keeps a region bake byte-identical to a full bake here.
	# 2) Refresh the real fine solid/air shape over every fine cell the EDIT COULD HAVE CHANGED.
	#    That window is NOT the changed coarse cells' own footprint: the sim re-molds a SYNC_BAND ring of
	#    coarse cells around each edit (src/core/fine_terrain.gd sync_block), because a fine cell's molded
	#    shape reads its parent's eight coarse neighbours. Refreshing only the footprint left the ring
	#    holding pre-dig solidity, and a single stale bit there smeared ~16 texels of wrong AO/moss — a
	#    region bake that was no longer byte-identical to a full one. Read the band width from the sim so
	#    the two cannot drift apart again.
	var band: int = FactorySim.FineTerrain.SYNC_BAND
	var fx0c: int = maxi((cmin.x - band) * SUBDIV, 0)
	var fy0c: int = maxi((cmin.y - band) * SUBDIV, 0)
	var fx1c: int = mini((cmax.x + 1 + band) * SUBDIV - 1, _fcols - 1)
	var fy1c: int = mini((cmax.y + 1 + band) * SUBDIV - 1, _frows - 1)
	for fy: int in range(fy0c, fy1c + 1):
		for fx: int in range(fx0c, fx1c + 1):
			_fine_solid[fy * _fcols + fx] = 1 if bool(fine_solid_at.call(fx, fy)) else 0
	# 3) Repaint the footprint DILATED by the neighbour reach so border AO/moss/accretion recompute right.
	var fx0: int = maxi(fx0c - REGION_MARGIN, 0)
	var fy0: int = maxi(fy0c - REGION_MARGIN, 0)
	var fx1: int = mini(fx1c + REGION_MARGIN, _fcols - 1)
	var fy1: int = mini(fy1c + REGION_MARGIN, _frows - 1)
	var painted: int = 0
	for fy: int in range(fy0, fy1 + 1):
		for fx: int in range(fx0, fx1 + 1):
			_paint_fine(fx, fy)
			painted += 1
	last_baked_cells = painted
	_img.set_data(_fcols, _frows, false, Image.FORMAT_RGBA8, _data)
	_tex.update(_img)


## Fully-transparent texel (all 4 bytes zeroed) so region and full bakes stay byte-identical on air/cap
## cells — no stale RGB lingering under A=0 from a prior bake.
func _clear_fine(i4: int) -> void:
	_data[i4] = 0
	_data[i4 + 1] = 0
	_data[i4 + 2] = 0
	_data[i4 + 3] = 0


## Paint ONE fine cell into _data from the cached coarse + fine grids — the per-cell body shared by the full
## rebake and the region fast lane. Solid → the parent's molded body colour with fine AO/hue/grain/moss/rim;
## eroded (parent solid, now fine-air) → recessed back-rock; genuine open air / surface cap → transparent.
## The grammar of the nearest solid coarse neighbour — the grammar half of `_accreted_color`, and it walks
## the same eight neighbours in the same order so a fine cell's grammar and its colour always come from the
## SAME coarse cell. Falls back to Clastic when a fine cell is genuinely isolated, which is the same
## fallback the colour path uses and is deterministic rather than left over.
func _accreted_gram(fx: int, fy: int) -> int:
	var pcx: int = fx / SUBDIV
	var pcy: int = fy / SUBDIV
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var nx: int = pcx + d.x
		var ny: int = pcy + d.y
		if nx < 0 or ny < 0 or nx >= _cols or ny >= _rows:
			continue
		if _solid_mask[ny * _cols + nx] > 0.5:
			return _gram_at(ny * _cols + nx)
	return GRAM_CLASTIC


## The grammar cached for a coarse index, tolerant of an unfilled cache so the paint cannot fault on a
## world baked before `grammar_at` was set.
func _gram_at(idx: int) -> int:
	return _mat_gram[idx] if idx >= 0 and idx < _mat_gram.size() else GRAM_CLASTIC


## This cell's texture grammar, or Clastic when no lookup was supplied (see `grammar_at`).
func _grammar_of(cell: Vector2i) -> int:
	if not grammar_at.is_valid():
		return GRAM_CLASTIC
	return clampi(int(grammar_at.call(cell)), 0, GRAM_SEAM.size() - 1)


func _paint_fine(fx: int, fy: int) -> void:
	var i4: int = (fy * _fcols + fx) * 4
	var pcol: int = fx / SUBDIV
	var prow: int = fy / SUBDIV
	var cidx: int = prow * _cols + pcol
	# Leave the coarse surface CAP band uncovered: the top SURFACE_KEEP fine rows of a column's walkable
	# surface cell stay transparent so the grass/lip + ramp cap (z -10) reads through and the SEEN top line
	# stays exactly the WALKED line. Rock below the cap is still fully molded.
	if prow == _surf_row[pcol] and (fy - prow * SUBDIV) < SURFACE_KEEP:
		_clear_fine(i4)
		return
	var here_solid: bool = _fine_solid[fy * _fcols + fx] == 1
	var parent_solid: bool = _solid_mask[cidx] > 0.5
	if here_solid:
		var midx: int = _contact_index(fx, fy, cidx)
		var base: Color = _mat_col[midx] if parent_solid else _accreted_color(_mat_col, _wall_col, _solid_mask, fx, fy, cidx)
		# #S12: put the tone back on at FINE resolution. The base arrives untoned, so this is the only
		# place the jitter and the bedding reach the rock — as a reconstructed field, not as a mosaic.
		var col: Color = apply_tone(base, _tone_at_fine(fx, fy))
		# ROCK HUE VARIATION (diff-04 #3): pull the body colour a hair toward a region-picked hue pole
		# (teal / faint brown / faint violet) so a broad rock face carries its own subtle tint and the frame
		# stops reading as one monochrome blue-grey. Very-low-freq → whole faces share a tone; a two-noise
		# pick keeps neighbouring regions from all landing on the same pole.
		var hx: float = _huex.get_noise_2d(float(fx), float(fy))
		var hy: float = _huey.get_noise_2d(float(fx), float(fy))
		var pole: Color = HUE_TEAL if hx < -0.15 else (HUE_BROWN if hx > 0.20 else HUE_VIOLET)
		col = col.lerp(pole, HUE_AMP * clampf(0.5 + 0.5 * hy, 0.15, 1.0))
		# Fine AO: air among the 4 orthogonal AND 4 diagonal fine neighbours; each open cell darkens the
		# fill toward that edge, so a lone fine nub reads round and an exposed face reads deeply carved.
		var air_n: float = _air_weight(_fine_solid, fx, fy)
		var shade: float = 1.0 - 0.125 * air_n
		if air_n > 0.5:                         # COOL SHADOW (fix-2 diff 3): carved rock tints cold teal-blue
			col = col.lerp(SHADOW_TEAL, clampf(air_n / 6.0, 0.0, 1.0) * 0.20)
		# A low-frequency tonal drift so a broad rock face isn't one flat colour + interiors deepen.
		var drift: float = _noise.get_noise_2d(float(fx) * 0.35 + 500.0, float(fy) * 0.35) * 0.07
		# BROAD TONAL PATCHES (diff-04 #1): a big soft low-freq value swing so wide areas of rock read as
		# lighter/darker patches, not one flat tone — the reference's mottled interiors.
		drift += _patch.get_noise_2d(float(fx), float(fy)) * PATCH_AMP * GRAM_PATCH[_gram_at(midx)]
		# DENSE GRAIN/SPECKLE (diff 4): two octaves of high-freq noise pit + clod the rock so it reads
		# granular. Multiplicative on value so it rides the material's own colour.
		# THE MATERIAL'S OWN LANGUAGE. `gram` is read at the WARPED index, the same one the colour came
		# from, so grammar and hue never disagree about which material a fine cell belongs to — reading it
		# at `cidx` would put stone's seams a few pixels into the dirt at every contact.
		# MIRROR THE COLOUR'S BRANCH EXACTLY. `_mat_gram` is only written for SOLID coarse cells, so a fine
		# cell whose coarse parent is AIR — accreted rock reaching over a hole — has no fresh entry to read
		# and `_gram_at(midx)` hands back whatever an older bake left there. Colour never had this problem
		# because it already takes `_accreted_color` on that branch; the grammar was reading straight
		# through it.
		#
		# STALE IS NOT MERELY WRONG, IT IS INSTANCE-DEPENDENT: a FineTerrain that did one full bake and one
		# that accumulated region bakes hold different leftovers, so the region path stopped being
		# byte-identical to the full path. `check_dig_hitch` reds on precisely that and it found this within
		# one sweep of the grammars landing.
		var gram: int = _gram_at(midx) if parent_solid else _accreted_gram(fx, fy)
		var gx: float = float(fx) * GRAIN_XSTRETCH * GRAM_XSTR[gram]
		var gamp: float = GRAIN_AMP * GRAM_GRAIN[gram]
		var grain: float = _grain.get_noise_2d(gx, float(fy)) * gamp \
			+ _grain2.get_noise_2d(gx, float(fy)) * (gamp * 0.35)
		# EMBEDDED STONES + CRACKS (diff-04 #1): a mid-freq mask, past a threshold, darkens a whole cluster
		# into an embedded darker stone; a ridged near-zero band of a second field cuts a thin dark crack.
		# Both are now the material's, not the world's: soil gets the clumps and almost no seams, stone gets
		# the seams and almost no clumps.
		var stone: float = _stone.get_noise_2d(float(fx), float(fy))
		if stone > STONE_THRESH:
			grain -= STONE_DARKEN * GRAM_CLUMP[gram] \
				* smoothstep(0.0, 1.0, (stone - STONE_THRESH) * STONE_RAMP)
		var crackv: float = absf(_crack.get_noise_2d(float(fx) * GRAM_SEAM_X[gram],
			float(fy) * GRAM_SEAM_Y[gram]))
		var seam_band: float = CRACK_BAND * GRAM_SEAM_W[gram]
		if crackv < seam_band:
			grain -= CRACK_DARKEN * GRAM_SEAM[gram] \
				* smoothstep(0.0, 1.0, 1.0 - crackv / seam_band)
		# RIM light (diff 7): the topmost solid fine cell of a face (open air directly above) catches a
		# bright lip — Noita's lit rock edges. A thin bright band only on the up-facing surface.
		# ...and it fades over RIM_DEPTH rows rather than lighting exactly one. A binary rim lights the
		# single topmost fine cell of each column, and the mold deliberately makes that boundary ragged —
		# so along a flat floor the lit cells and their unlit neighbours alternate, and a lip that should
		# read as a lit EDGE printed as a dotted line. Falling off over two rows makes it a band.
		var top_dist: int = _top_air_distance(_fine_solid, fx, fy)
		var rim: float = 0.0
		var rim_warm: float = 0.0
		if top_dist >= 0 and top_dist < RIM_DEPTH and not _fine_air(_fine_solid, fx, fy + 1):
			var lip: float = 1.0 - float(top_dist) / float(RIM_DEPTH)
			rim = 0.10 * lip                # cut back: the FORM term below now carries the falloff
			rim_warm = 0.03 * lip
		# Rock in shadow is DARK ROCK, never a hole. Six independent darkeners stack here (carved-edge AO,
		# the form sink, grain, an embedded stone, a crack) and unfloored they could drive a single cell to
		# black, which prints as a puncture in an otherwise continuous face — the same wrong note as a
		# blown highlight, at the other end.
		var vmul: float = maxf(0.22, shade + grain + _sky_form(fx, fy))
		var out := Color(col.r * vmul + drift + rim + rim_warm, col.g * vmul + drift + rim,
			col.b * vmul + drift + rim, 1.0)
		out = _soil(out, fx, fy, pcol)
		# MOSS (diff 5 / diff-04 #2): tint the exposed rock TOPS toward olive-moss. A top edge = open air
		# above; the top MOSS_DEPTH rows below it wear moss in organic patches (noise-masked), fading down.
		var alive: float = _moss_life(fy)
		if top_dist >= 0 and top_dist < MOSS_DEPTH:
			var patch: float = _moss.get_noise_2d(float(fx), float(fy) * 0.6)
			if alive > 0.0 and patch > -0.28:       # diff-04 #2: wider accept → more coverage
				var band: float = (1.0 - float(top_dist) / float(MOSS_DEPTH)) \
					* clampf((patch + 0.28) * 1.5, 0.0, 1.0)
				out = out.lerp(MOSS_COLOR, 0.55 * band * alive)
		else:
			# HANGING MOSS TUFTS (diff-04 #2): the top rows just BELOW a down-facing overhang lip grow a few
			# moss pixels dripping into the air — the reference's hanging tufts under ledges.
			var hang: int = _bottom_air_distance(_fine_solid, fx, fy)
			if hang >= 0 and hang < HANG_DEPTH:
				var hp: float = _moss.get_noise_2d(float(fx) * 0.9, float(fy) * 0.9 + 90.0)
				if alive > 0.0 and hp > HANG_GATE:
					var hband: float = (1.0 - float(hang) / float(HANG_DEPTH)) \
						* clampf((hp - HANG_GATE) * 3.0, 0.0, 1.0)
					out = out.lerp(MOSS_COLOR.darkened(0.12), 0.55 * hband * alive)
		_data[i4] = int(clampf(out.r, 0.0, 1.0) * 255.0)
		_data[i4 + 1] = int(clampf(out.g, 0.0, 1.0) * 255.0)
		_data[i4 + 2] = int(clampf(out.b, 0.0, 1.0) * 255.0)
		_data[i4 + 3] = 255
	elif parent_solid:
		# Eroded: this fine cell WAS rock, molding opened it → paint the RECESSED BACK-ROCK behind so the
		# blocky coarse fill can't show through the organic curve (fix-2 diff 6): a darker, COOLER wall that
		# reads as rock set BEHIND the foreground shelf, + a touch of fine AO so the pocket reads scooped.
		var wc: Color = _wall_body(fx, fy, cidx).darkened(0.42).lerp(BACKROCK_COOL, 0.18)
		var back_ao: float = 1.0 - 0.10 * _air_weight(_fine_solid, fx, fy)
		_data[i4] = int(clampf(wc.r * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 1] = int(clampf(wc.g * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 2] = int(clampf(wc.b * back_ao, 0.0, 1.0) * 255.0)
		_data[i4 + 3] = VOID_ALPHA   # NOT 255: this is air, and the tooth pass masks on it
	elif _wall_has[cidx] == 1:
		# #S13 THE BACK WALL. Genuine open air, but the coarse cell carries a wall — so this is the inside
		# of something you have dug, and it is most of what is on screen once you have. Painted here rather
		# than left to the coarse pass's flat per-cell rect, with the reconstructed tone, its own quieter
		# grain, and the cast shadow re-thrown from the fine grid so the recess still reads.
		var wall: Color = _wall_body(fx, fy, cidx)
		var wgrain: float = _grain.get_noise_2d(float(fx) * GRAIN_XSTRETCH, float(fy)) * WALL_GRAIN \
			+ _patch.get_noise_2d(float(fx), float(fy)) * WALL_PATCH
		var wshade: float = 1.0 - _wall_shade(fx, fy)
		var wout := Color(maxf(wall.r * wshade + wgrain, 0.0), maxf(wall.g * wshade + wgrain, 0.0),
			maxf(wall.b * wshade + wgrain, 0.0), 1.0)
		_data[i4] = int(clampf(wout.r, 0.0, 1.0) * 255.0)
		_data[i4 + 1] = int(clampf(wout.g, 0.0, 1.0) * 255.0)
		_data[i4 + 2] = int(clampf(wout.b, 0.0, 1.0) * 255.0)
		_data[i4 + 3] = VOID_ALPHA   # NOT 255: this is air, and the tooth pass masks on it
	else:
		_clear_fine(i4)   # genuine open air with nothing behind it (the sky) — transparent


## THE TONE FIELD, REBUILT BETWEEN SAMPLES (#S12). Bilinearly interpolate the coarse (jitter, strata)
## samples at this fine cell's position.
##
## The mapping is the part that matters. A fine cell's CENTRE sits at world coordinate
## (fx + 0.5) * FINE, which in coarse units is (fx + 0.5) / SUBDIV - 0.5 relative to coarse cell centres.
## On that lattice consecutive fine cells are an even 1/SUBDIV apart both inside a coarse cell and across
## a boundary — which is the whole reason the seam stops being special. Sampling at fx / SUBDIV instead
## would put four samples inside each cell and none on the boundary, and the grid would survive.
##
## Clamped at the world edges so the border reconstructs against itself rather than against nothing.
## Which coarse cell this fine cell takes its MATERIAL COLOUR from, after the contact warp (see
## CONTACT_WARP). Falls back to the true parent whenever the displaced sample lands somewhere that is not
## solid rock: a warp that reached into air would paint rock the colour of nothing, and what happens at a
## face is the molding's job, not this one's.
func _contact_index(fx: int, fy: int, cidx: int) -> int:
	var dx: float = _warp.get_noise_2d(float(fx), float(fy)) * CONTACT_WARP
	var dy: float = _warp.get_noise_2d(float(fx) + 311.0, float(fy) - 197.0) * CONTACT_WARP
	var wc: int = clampi(int(floor((float(fx) + dx) / float(SUBDIV))), 0, _cols - 1)
	var wr: int = clampi(int(floor((float(fy) + dy) / float(SUBDIV))), 0, _rows - 1)
	var widx: int = wr * _cols + wc
	return widx if _solid_mask[widx] > 0.5 else cidx


func _tone_at_fine(fx: int, fy: int) -> Vector2:
	var u: float = (float(fx) + 0.5) / float(SUBDIV) - 0.5
	var v: float = (float(fy) + 0.5) / float(SUBDIV) - 0.5
	var x0: int = clampi(int(floor(u)), 0, _cols - 1)
	var y0: int = clampi(int(floor(v)), 0, _rows - 1)
	var x1: int = mini(x0 + 1, _cols - 1)
	var y1: int = mini(y0 + 1, _rows - 1)
	# SMOOTHSTEPPED, not linear. `_tone` is one sample per COARSE cell and the beds it carries swing far
	# enough to be seen, so how it is interpolated is not a detail. Straight bilinear is continuous in VALUE
	# but not in SLOPE: the gradient turns a corner at every sample point, and the eye reads a slope
	# discontinuity as an edge. The result is a faint facet running through every cell CENTRE — a grid, drawn
	# by the smoothing meant to hide one. A screenshot measured luma steps 2.5x harder on that phase than
	# between it. Smoothstep zeroes the derivative at each sample, so the field arrives and leaves flat and
	# the facets have nothing to draw.
	var tx: float = clampf(u - float(x0), 0.0, 1.0)
	var ty: float = clampf(v - float(y0), 0.0, 1.0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var top: Vector2 = _tone[y0 * _cols + x0].lerp(_tone[y0 * _cols + x1], tx)
	var bot: Vector2 = _tone[y1 * _cols + x0].lerp(_tone[y1 * _cols + x1], tx)
	return top.lerp(bot, ty)


## A back-wall cell's body colour: the cached BASE with its strata put back on at fine resolution, quieted
## the way the coarse pass quieted it, then set back behind the front plane.
func _wall_body(fx: int, fy: int, cidx: int) -> Color:
	return apply_wall_tone(_wall_col[cidx], _tone_at_fine(fx, fy).y * WALL_STRATA_QUIET)


## THE CAST SHADOW ON THE BACK WALL (#S13), re-thrown from the fine grid.
##
## The coarse pass carried the wall's entire sense of depth in AO strips ruled along the cell edges, and the
## fine layer now covers those — so it has to cast the shadow itself or the wall goes flat exactly as its
## tone gets better. Directional, with the coarse pass's own weights: rock overhead is the deepest shadow,
## rock to either side less, and a floor below least, because light reaches a floor.
##
## Each direction walks out until it finds solid rock or runs out of reach, and fades with distance, so an
## opening's shadow is a gradient rather than the ruled border a per-cell strip drew. Capped below black: a
## corner throws three casts at once and unclamped they would punch a hole in the wall.
func _wall_shade(fx: int, fy: int) -> float:
	var d: float = WALL_AO_UNDER * _cast(fx, fy, 0, -1) + WALL_AO_ABOVE * _cast(fx, fy, 0, 1) \
		+ WALL_AO_SIDE * _cast(fx, fy, -1, 0) + WALL_AO_SIDE * _cast(fx, fy, 1, 0)
	return clampf(d, 0.0, WALL_AO_MAX)


## 1.0 when solid rock sits immediately that way, fading to 0.0 at WALL_AO_REACH fine cells. Early-exits on
## the first solid cell, and every probe is inside REGION_MARGIN so a patched region matches a full bake.
func _cast(fx: int, fy: int, dx: int, dy: int) -> float:
	for i: int in range(WALL_AO_REACH):
		if not _fine_air(_fine_solid, fx + dx * (i + 1), fy + dy * (i + 1)):
			return 1.0 - float(i) / float(WALL_AO_REACH)
	return 0.0


## Weighted OPEN-air neighbour count around a solid fine cell — the fine AO term. Orthogonal neighbours
## weigh 1, diagonals 0.5, so an exposed face darkens strongly and a corner rounds off smoothly (0..6).
## Off-grid counts as air (the world edge reads carved, not walled).
## Orthogonal neighbours count 1.0, diagonals 0.5, and anything off the grid counts as air — exactly as the
## two array-literal loops this replaces did, and `check_dig_hitch` holds the result byte-identical.
##
## WHY IT IS WRITTEN OUT LONGHAND. This is the single most expensive helper in the per-texel paint (~1.3ms
## of a 4.5ms dig region, measured by tools/profile_frame.gd), and almost none of that was the eight array
## reads. Each call ALLOCATED TWO `Array[Vector2i]` LITERALS — eight Vector2i objects built and thrown away
## per texel, 576 times a dig and 262144 times a load — and then made eight function calls to do work that
## is one index and one comparison. The loop read beautifully and cost more than everything it was
## measuring. Written flat it allocates nothing and calls nothing.
func _air_weight(fine_solid: PackedByteArray, fx: int, fy: int) -> float:
	var w: float = 0.0
	var lo_x: bool = fx - 1 < 0
	var hi_x: bool = fx + 1 >= _fcols
	var lo_y: bool = fy - 1 < 0
	var hi_y: bool = fy + 1 >= _frows
	var row: int = fy * _fcols
	var up: int = row - _fcols
	var dn: int = row + _fcols
	if lo_x or fine_solid[row + fx - 1] == 0:
		w += 1.0
	if hi_x or fine_solid[row + fx + 1] == 0:
		w += 1.0
	if lo_y or fine_solid[up + fx] == 0:
		w += 1.0
	if hi_y or fine_solid[dn + fx] == 0:
		w += 1.0
	if lo_x or lo_y or fine_solid[up + fx - 1] == 0:
		w += 0.5
	if hi_x or lo_y or fine_solid[up + fx + 1] == 0:
		w += 0.5
	if lo_x or hi_y or fine_solid[dn + fx - 1] == 0:
		w += 0.5
	if hi_x or hi_y or fine_solid[dn + fx + 1] == 0:
		w += 0.5
	return w


func _fine_air(fine_solid: PackedByteArray, fx: int, fy: int) -> bool:
	if fx < 0 or fy < 0 or fx >= _fcols or fy >= _frows:
		return true
	return fine_solid[fy * _fcols + fx] == 0


## How alive moss is at a fine row: full in the damp shallows, gone in the deep. A pure function of the
## row, so a region re-bake after a dig stays byte-identical to a full bake.
func _moss_life(fy: int) -> float:
	var row: float = float(fy) / float(SUBDIV)
	return clampf((float(MOSS_DEAD_ROW) - row) / float(MOSS_DEAD_ROW - MOSS_LUSH_ROW), 0.0, 1.0)


## THE KEY LIGHT (#S8) — a signed brightness for one solid fine cell, from which way its mass faces.
##
## Walks straight up until it hits air or runs out of FORM_REACH, and straight down for the same. Air
## found close above means this cell is near the TOP of its mass, so it catches light; air found close
## below means it hangs under a lip, so it falls into shadow. Both fade with distance, and a cell with
## rock above and below within reach gets both terms and nets out — which is what the middle of a wall
## should look like.
##
## Cheap on purpose: at most 2*FORM_REACH probes, early-exiting on the first air, and every probe is
## inside the region-rebake margin so a patched region stays byte-identical to a full bake.
## Same reach, same falloff, same break — the `_fine_air` call per step is inlined for the reason spelled
## out on _air_weight: this runs up to 2*FORM_REACH times per texel and was the second-largest helper in
## the paint (~0.96ms of a 4.5ms dig region). The column bound is hoisted because it cannot change inside
## either loop.

func _sky_form(fx: int, fy: int) -> float:
	var f: float = 0.0
	var oob_x: bool = fx < 0 or fx >= _fcols
	for d: int in range(FORM_REACH):
		var yy: int = fy - d - 1
		if oob_x or yy < 0 or yy >= _frows or _fine_solid[yy * _fcols + fx] == 0:
			f += FORM_LIFT * (1.0 - float(d) / float(FORM_REACH))
			break
	for d: int in range(FORM_REACH):
		var yy: int = fy + d + 1
		if oob_x or yy < 0 or yy >= _frows or _fine_solid[yy * _fcols + fx] == 0:
			f -= FORM_SINK * (1.0 - float(d) / float(FORM_REACH))
			break
	return f


## THE SOIL PROFILE (#S10). Everything here is keyed to depth below THIS COLUMN's own surface, so the
## bands follow a hillside instead of lying in flat world rows, and a column that is rock all the way up
## (a cliff face, anything underground) is left alone entirely — `depth` only lands inside SOIL_ROWS for
## cells that are genuinely near a walkable top.
func _soil(c: Color, fx: int, fy: int, pcol: int) -> Color:
	# Checked, not left to the arithmetic. NO_SURFACE is negative, so the subtraction below would make
	# `depth` *larger* and the range test would reject it for most of the grid — but only for most of it:
	# near the top of the world a hole column would land back inside SOIL_ROWS and get the topsoil profile
	# it must never have. A sentinel that works by accident for 90% of its inputs is the shape this whole
	# fix is about.
	if _surf_row[pcol] == NO_SURFACE:
		return c
	var depth: int = fy - (_surf_row[pcol] * SUBDIV + SURFACE_KEEP)
	if depth < 0 or depth >= SOIL_ROWS:
		return c
	# Fade the whole profile out over its last third, or the bottom of the soil would be a ruled line
	# across the world — which is the exact failure the bands exist to fix, moved down ten cells.
	var strength: float = clampf(float(SOIL_ROWS - depth) / (float(SOIL_ROWS) * 0.34), 0.0, 1.0)
	var out: Color = c
	if depth < HUMUS_ROWS:
		# Ramped in as well as out. Darkest AT the turf line puts the band's maximum contrast directly
		# against the coarse grass cap, which prints as a hard seam ruled across the whole world — the
		# humus has to meet the cap, not fight it.
		var d: float = float(depth) / float(HUMUS_ROWS)
		out = out.darkened(HUMUS_DARKEN * smoothstep(0.0, 0.4, d) * (1.0 - d))
	elif depth < HUMUS_ROWS + SUBSOIL_ROWS:
		var t: float = float(depth - HUMUS_ROWS) / float(SUBSOIL_ROWS)
		out = out.lerp(SUBSOIL_POLE, SUBSOIL_WARM * (1.0 - t) * strength)
	# INCLUSIONS, both signs. `strength` fades them with the profile so the soil dissolves into plain rock
	# rather than ending at a ruled line.
	var peb: float = _stone.get_noise_2d(float(fx) * COBBLE_SCALE, float(fy) * COBBLE_SCALE)
	if peb > COBBLE_THRESH:
		out = out.lightened(COBBLE_LIGHTEN * smoothstep(0.0, 1.0, (peb - COBBLE_THRESH) * STONE_RAMP)
			* strength)
	elif peb < CLAST_THRESH:
		out = out.darkened(CLAST_DARKEN * smoothstep(0.0, 1.0, (CLAST_THRESH - peb) * STONE_RAMP)
			* strength)
	# ROOTS: sparse, near-vertical, reaching down from the turf. The X sample is compressed so a root is
	# THIN across and long down — the same anisotropy trick the bedding grain uses, turned ninety degrees.
	var rn: float = _root.get_noise_2d(float(fx) * 1.9, float(fy) * 0.18)
	if rn > ROOT_GATE:
		var reach: float = float(ROOT_MAX) * clampf((rn - ROOT_GATE) * 3.0, 0.0, 1.0)
		if float(depth) < reach:
			out = out.darkened(ROOT_DARKEN * (1.0 - float(depth) / reach))
	return out


## Rows below the nearest EXPOSED top surface directly above this solid fine cell (0 = this cell has open
## air right above it — a ledge top; N = N solid rows below such a top; -1 = no open top within
## MOSS_DEPTH — an interior or overhung cell). Walks straight up: the first open-air cell within
## MOSS_DEPTH gives the distance; all-solid = interior. Drives the moss band on Noita ledge tops (diff 5).
func _top_air_distance(fine_solid: PackedByteArray, fx: int, fy: int) -> int:
	for d: int in range(MOSS_DEPTH):
		if _fine_air(fine_solid, fx, fy - d - 1):
			return d
	return -1


## Rows above the nearest EXPOSED bottom surface directly below this solid fine cell (0 = open air right
## below — a down-facing overhang lip; N = N solid rows above such a lip; -1 = no open bottom within
## HANG_DEPTH). Mirror of _top_air_distance downward; drives the hanging moss tufts (diff-04 #2).
func _bottom_air_distance(fine_solid: PackedByteArray, fx: int, fy: int) -> int:
	for d: int in range(HANG_DEPTH):
		if _fine_air(fine_solid, fx, fy + d + 1):
			return d
	return -1


## Colour for a fine cell of rock ACCRETED into a coarse-air cell (molding grew rock past the coarse
## boundary): borrow the nearest solid coarse neighbour's body colour so the growth reads as the same
## rock mass reaching over, not a new material. Falls back to the parent's wall tint if truly isolated.
func _accreted_color(mat_col: PackedColorArray, wall_col: PackedColorArray, mask: PackedFloat32Array,
		fx: int, fy: int, cidx: int) -> Color:
	var pcx: int = fx / SUBDIV
	var pcy: int = fy / SUBDIV
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var nx: int = pcx + d.x
		var ny: int = pcy + d.y
		if nx < 0 or ny < 0 or nx >= _cols or ny >= _rows:
			continue
		if mask[ny * _cols + nx] > 0.5:
			return mat_col[ny * _cols + nx]
	return wall_col[cidx].lightened(0.05)
