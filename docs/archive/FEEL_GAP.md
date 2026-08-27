> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot. `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 scoped this as REWRITE (keep ~26 of 39 "strikes" — rendering perf, movement physics, audio QA
> methodology — cut the Bazaar/Drift-Rig/Crusher-specific strikes) — the "Edited 2026-08-25" header below
> suggests that edit was done, but it was never committed. Moved here rather than promoted to the live
> tree, on the same reasoning as `AGENT_PLAY_EVALUATION_PROTOCOL.md`'s header. Kept for provenance —
> the surviving rendering/movement/audio methodology may still be worth pulling from for later
> presentation work.

---

# The Feel Gap — why it reads "flat, blocky, clunky," and a small-overhaul plan

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

> ## ⚠️ THIS DOCUMENT NO LONGER SETS PRIORITY — see `docs/PRIORITY.md`
>
> Tracks A and B below **shipped** (through strike 26) and the diagnosis they came from still holds. What
> has changed is the frame around them. An independent subjective audit of the artifact on 2026-08-17
> (`docs/handoff/VIBE_AUDIT_RESPONSE.md`, overall **4.9/10**) found that the remaining gap is not mainly a
> look problem, and reordered the work:
>
> - **The lowest scores are not art.** Lore 2.2, Surprise 3.2, Addiction 3.3, Fun Tax 3.5. The put-down
>   point is the moment the first line runs — the thesis moment — and no amount of look fixes that.
> - **"Factorio × Terraria" is retired as the operative design test.** The game is a *kinetic industrial
>   descent*; the remembered image is the miner on the bending gold rope, not a factory. This document
>   argues against a target we no longer build toward.
> - **Stop adding surface grain.** *"The frame already has grain; it needs form."* Several Track A
>   proposals below push grain; that direction is closed. Solid-to-air boundaries need a value-and-edge
>   signature instead.
> - **The HUD is the art director** — ~85–90% of the interface floats above the world, and the next
>   presentation pass is a **subtraction**, not a redesign.
>
> Read the analysis here; take the ordering from `docs/PRIORITY.md`.

_Analysis date: 2026-08-15. Grounded in real base-zoom captures of the boot screen (`_moment_boot.png`,
`_moment_boot_z2.png`) cross-checked by three independent lenses: a zero-context first-time viewer, a
game-feel/Noita-vibe read, and a code-grounded early-game UX audit. Supersedes the older informal
"vibe gap" notes._

## The complaint (in the developer's words)

> "Too two-dimensional and blocky… hard to see the character from the base zoom… it kind of hurts the
> eyes to play… feels so clunky still… the way the character plays is clunky, the early game is annoying
> instead of seamless… a tedious clunky small-dimensional mining simulator." Noita is the **vibe**
> reference (not a copy target) — tactile, juicy, atmospheric, alive.

## The one-line reframe

Two findings change how we should think about this:

1. **The atmosphere is not missing — it's whispering.** The renderer already has parallax ridgelines,
   edge-AO, autotile chamfer/fillet, atmospheric haze on far hills, godrays, a day/night sky, a glow
   Environment, and GPU dust motes. They're dialed so subtle they don't register in a screenshot. Most of
   the "look" fix is **amplifying what exists + a few targeted additions**, not building an engine.
2. **The early-game clunk is largely engineered in.** The code deliberately makes hand-mining a "PAIN…
   the teacher that makes you crave automation," with an intentionally-bad starter pick. The grind
   *works* — but it lands **before** any of its payoff, so a first-timer just feels the tedium. The fix is
   a **philosophy shift for the first 60 seconds**, not only tuning.

So: this is a **small overhaul**, mostly **code** (no new art needed for ~80% of the win), not a rewrite.

---

## Part 1 — The vocabulary (naming what you feel)

Precise words for each vague feeling, so we can aim at them:

### Look
- **"Too 2D / cardboard" = flat, unlit forms.** Nothing has ambient occlusion, contact shadows, or a
  directional key light, so every object is a sticker pasted on a backdrop. The scene collapses to **two
  planes: "stuff" and "sky."** That literally *is* two-dimensionality.
- **"Blocky" = a hard, axis-aligned grid silhouette.** The grass→air line is a near-straight horizontal
  cut; dug tunnels are perfect black rectangular slots on a visible 32px grid. It reads laser-cut, not
  carved.
- **"Can't see the character" = avatar camouflage + zero screen-presence.** He's ~4% of frame at base
  zoom, the **same brown value** as the dirt, machines, and tree trunks around him, with no rim light and
  no size dominance. You locate him only by the floating white triangle — the *marker* is more visible
  than the *character*.
- **"Hurts the eyes" = inverted focal hierarchy + muddy midtones.** The brightest things on screen are
  the **UI yellow** and the **empty sky** — not the play space. The action band (character, machines,
  bushes, mountains) is a same-value brown/grey jumble your eye can't get purchase on. Your gaze is pulled
  *away* from where you're actually playing.
- **Underground "fog" = molded-soft terrain reading as smoke in darkness.** No material grain, no strata,
  no ore structure — a dark grey-black cloud with amorphous black holes. Reads like a coffee stain, not a
  wall of rock you carve. (This one has a known art fork; see below.)

### Feel / flow
- **"Clunky character / tedious early game" = an engineered-grind opening that front-loads the pain.**
  Concretely: a deliberately-slow tier-1 pick (ore/coal = 1.5s each; **4 ore = 6s of holding** for step
  one), a **charge that resets to zero on any re-aim** (mis-aims cost the whole dig), a tight **3.2-cell
  reach** with one-layer line-of-sight carving (you can't dig a satisfying pocket from one stance —
  constant shuffling), **150 px/s traversal** across a wide zoomed-out world, and a **first reward gated**
  behind face-the-forge → Q-toss → fall time → 1.3s pickup grace → walk-over. All of it wrapped in a
  **13-step imperative text ladder** behind a **mandatory seed/tint menu** you must clear before you can
  even move.

---

## Part 2 — Root causes (grounded, prioritized)

### Look (most-impactful first)
1. **No lighting model** — flat/unlit, no AO, no cast shadows. ~60% of the cardboard feel. _(bones exist:
   edge-AO is present but weak; no contact shadows.)_ **CODE.**
2. **Untextured slab terrain + hard grid edges + rectangular dig slots.** No material grain; laser-cut
   silhouette. **CODE (shader/mold), partial ART.**
3. **No depth layering / atmospheric perspective** — the scene is two planes. _(bones exist: parallax +
   far-hill haze, but far too subtle.)_ **CODE.**
4. **Avatar has no screen-presence** — tiny, camouflaged, no rim/keylight, no size dominance. **CODE +
   ART.**
5. **Muddy low-saturation palette + inverted focal hierarchy** (UI is the most vivid thing). **CODE
   (grade).**
6. _(Honorable mention)_ **Inert frame** — motes barely register, no grass sway, no dig-debris, no
   surface life. **CODE.**

### Feel / flow
1. **The opening is a grind by design, and the grind lands before its payoff.** Intentional friction, but
   a first-timer only feels tedium.
2. **High hold-to-reward ratio with reset-on-misaim** and no stored progress.
3. **Small reach + one-layer LOS carving** forces constant repositioning.
4. **Slow traversal in a big-looking world.**
5. **Text-directed, low-agency onboarding** behind a mandatory menu.
6. **The first reward is fiddly and delayed** (positioning + timers), so the first dopamine hit is late.

---

## Part 3 — The small-overhaul proposal set

Two tracks. Tags: **[CODE]** = I can just do it, no new art. **[ART]** = needs your pixel-art. Effort S/M/L.

### Track A — LOOK (the vibe)
- **A1. Give the world mass: a lighting/AO amplification pass.** Strengthen edge-AO into real contact
  shadows; add drop-shadows under the player, machines, and trees so they sit *in* the world; add a warm
  directional sun-tint on lit surfaces + cool shadow tint so terrain has form. _The single biggest
  cardboard-killer._ **[CODE] M.**
- **A2. Push the background back: atmospheric depth.** Much stronger desaturate+lighten+haze on far
  ridgelines, a depth-fog gradient, and a soft foreground vignette/occluder to bracket the play space.
  Turns "two planes" into layered depth. **[CODE] S–M.**
- **A3. Color grade + fix the focal hierarchy.** Lift world saturation, warm the sunlit ground, cool the
  shadows, and **pull the UI yellow down** so the world — not the HUD — is the brightest thing. Reserve
  saturation/brightness for the player and interactables. **[CODE] S.**
- **A4. Make the character the clear focal point.** Zoom in a notch for the early game (bigger avatar) +
  a cool rim/key light on the player + a subtle idle-bob and a dig-swing tell + a signature accent colour
  nothing else wears. The code parts get most of the way; a larger/higher-contrast sprite is the finisher.
  **[CODE] S + [ART] M.**
- **A5. Break the laser-cut grid.** Amplify the terrain edge-mold so the surface line and dig-walls read
  organic; add rubble/debris at dig faces. _(Touches the crisp-tiles-vs-molded art fork — I'd tune, not
  overhaul.)_ **[CODE] M.**
- **A6. Bring the frame to life.** Ensure motes drift at the **surface** (not just underground), add grass
  sway, punchy dig-debris bursts + a stronger dig impact (shake/flash), machine smoke/glow. **[CODE] S–M.**

### Track B — FEEL / FLOW (seamless early game)
- **B1. De-grind the first minute (keep the grind for later).** Faster first-ore break (or a slightly
  better opening tool), and **stop resetting mining charge on re-aim** (carry-over or a grace window) so
  mis-aims don't punish. Let the ache arrive **deeper**, once the hook is set. **[CODE] S.**
- **B2. Front-load the dopamine.** First dig pops a satisfying chunk *instantly* (debris + sparkle + count
  tick + crunch), and the first ore→ingot is less fiddly (loosen Q-toss positioning/grace, or auto-route
  the very first ore). **[CODE] S.**
- **B3. Seamless traversal.** More move speed / a touch more momentum (or zoom in so 150px/s feels right),
  and forgiving jump/step-up (coyote time; the 3-tile-lip hard-wall is a rough early stop). **[CODE] S.**
- **B4. Less text, more show.** Shorten the early objective labels to glanceable prompts, lean on the
  existing pulsing target-ring instead of sentences, and let ENTER skip straight past the seed/tint menu
  into play. **[CODE] S.**
- **B5. Agency first.** Let the very first action be a free, satisfying dig *anywhere* (moving + digging is
  immediately rewarding), then layer the objective on top. Show, don't tell. **[CODE/design] M.**

### Recommended "first strike" — the smallest all-code bundle that flips the vibe
Do these together, screenshot before/after, then react:
**A1 (mass/AO/shadows) + A3 (grade + tame the UI) + A4-code (rim + zoom-in) + A6 (surface motes + dig
juice)** for the *look*, and **B1 (no charge-reset + faster first digs) + B2 (instant reward juice)** for
the *feel*. ~6 code changes, no new art, that together move the game from "flat tedious sim" toward
"juicy tactile." Then we decide the art-dependent pieces (bigger sprite, real terrain tiles) with fresh
eyes.

---

## What shipped (2026-08-16)

Executed in two strikes, each slice its own commit, harness 26/26 green after every one.

### Strike 1 — the smallest all-code bundle
| Slice | Commit | What changed |
|---|---|---|
| B1 | `827d51e` | Mining charge banks **per cell**, so a cursor slip costs travel time and never progress; cracks hold, then heal and evict. Shallow band softened (first ore 1.5s → 0.9s) with **every deep number untouched**, so the gradient that teaches gets *sharper*: deepslate goes from ~2× surface rock to ~3×. |
| B2 | `f83eaf2` | A **"+N" payout tick** rises off every break and pickup, merging into one climbing number; derived by diffing the pack, so it always names the real yield. The **Q-toss finds the mouth** when a machine in reach genuinely eats what you hold — a new sim-side `machine_eats` truth beside `machine_status`. |
| A1 | `8c9a7cf` | Carved edges get a **key light from above**: lit lip on sky-facing tops, deepest shadow on undersides, walls between. Occlusion alone can't make a form. |
| A3·A4·A6 | `0a0ae40` | Base zoom **0.70× → 1.00×** (the avatar was under 1% of frame width); HUD gold and text stepped down so the world is the brightest thing; grade leans on **saturation** rather than contrast (which would crush an already-black deep); motes denser, every break sprays in its material's colour. |

### Strike 2 — ground, air, and the guide
| Slice | Commit | What changed |
|---|---|---|
| S2 | `107ebf5` | **Sedimentary bedding** at three incommensurable periods (~18/7/4 cells), warped along x so layers dip like real strata. Forty cells of untouched dirt were one brown expanse. |
| A2 | `2d1a375` | A **third, farthest ridgeline** near the sky's own value, and a much steeper aerial-perspective falloff. The Sinkforge crown hazes with them — its unhazed black had become a sticker. |
| B4 | `0264478` | The objective banner **leads with the short goal**; the long how-to appears only just after a step opens, and again once you've been stuck long enough to want it back. |
| A5 | `fc9c7ea` | The grass cap grows a **ragged fringe** — varying thickness, roots fingering down, tufts overhanging the line. The walked line never moves; only the paint stops being a ruler. |
| — | `952d2a6` | A **`delve` moment** in the capture instrument. Every look pass until now was graded on surface shots, i.e. half the evidence. |
| — | `9d89699` | **The deep reads as stone.** Three renderer causes, none of them the molded terrain everyone assumed: the additive lamp was painting over the rock its own veil-cut had revealed; bedding's absolute colour targets were a no-op on dark stone; and tonal range is compressed twice underground, so jitter and bedding now grow with depth. Plus sparse **fissures** — speckles are point noise, a fracture is a line, and a line is what an eye reads as structure. |

Also fixed en route: carried terrain blocks (earth/stone/shale/deepslate/sealrock) had no palette entry and
drew as **blank white squares** in the hotbar — three identical blanks, which read as missing art because
it was. They now get real colours and a lit-top block glyph.

### What turned out not to need doing
- **B3 (traversal).** The doc assumed coyote time and jump buffering were missing; both already exist
  (0.08s / 0.10s), and A4's zoom did the "150 px/s feels slow" half. The 3-cell lip is a real design
  boundary — you dig or build past it — not clunk.
- **B4's "let ENTER skip the menu".** The title screen already opens with `[ENTER] descend`; seed and
  lamp are opt-in. One keypress to play was already true.

### Strike 3 — depth, and what a blend mode was costing
| Slice | Commit | What changed |
|---|---|---|
| S3 | `452f222` | **Shadow multiplies.** The veil carried a shadow COLOUR in RGB and a darkness in A, alpha-blended over the world — which is what fog does, not what shadow does. At the deep's opacity only a third of a cell's own colour survived; the rest was a smooth wash with no relationship to the rock under it, averaging away every honest terrain pass. A multiply preserves relative contrast perfectly and hue for free, which deleted the whole per-cell shadow bake that existed only to fake hue preservation. Light cuts now carry their SOURCE's colour (lamp-lit rock comes out amber through the multiply), so the additive pass — which was adding +85/255 over the reveal and washing pool centres to cream — got demoted to bloom. Ambient re-graded off measurements: at the old value unlit dirt printed rgb(6,10,24), a 4:1 blue bias that erased material identity. Sub-surface scatter 3→7 tiles, because cutting to pitch one tile under an open surface turned the bottom third of the opening frame into a void. The back plane recesses decisively and rock catches a lit rim on vertical faces, not just sky-facing tops. |
| — | `452f222` | A **`room` moment**: 13×7 chamber, two torches. A one-cell shaft cannot answer whether carved space reads as a room. It could not, before this. |

### Strike 4 — movement worth building speed for
| Slice | Commit | What changed |
|---|---|---|
| S4 | `49b85d3` | **The grapple.** A ninja rope, not Terraria's hook: one position-based distance constraint per substep that cancels only the OUTWARD radial component of velocity, so everything tangential survives and reeling in adds energy the way a skater spins up. Deliberately doesn't wrap corners — a straight line you can read at a glance is the better toy. **Momentum survives**, which is the bug that would have made the rest decorative: the controller's normal job is to hold you at RUN_SPEED and it was doing exactly that to a released swing, bleeding 420px/s back to a walk in a sixth of a second. Plus a terminal for the arc (a perfect pumper hit 6.6× run speed — a slingshot, not a swing), camera look-ahead, a body that leans into the arc, speed streaks, and a plant that chips and cracks. |
| — | `49b85d3` | **`tools/check_grapple.gd`** turns "is it fun" into the properties the fun is made of — it bites, it swings, it lifts, it crosses, it keeps. Headline: a 10-cell chasm no jump can clear, crossed by swinging it, through the real body and the real constraint. |
| — | `2c3d5dd` | The winch is **named at depth 10**, where a player stops thinking about the hole and starts thinking about the climb. A key hint in a footer strip is a place to look something up after you already wanted it. |

### Strike 5 — the world stops being flat, literally
| Slice | Commit | What changed |
|---|---|---|
| S5 | `2b9375b` | **Rifts, ledges, spires, rubble.** Every carve the generator did was horizontal — round pockets, wide flat-floored caverns, worms explicitly biased flat — so the underground had no vertical dimension at all and every screen looked like every other screen. A rift falls THROUGH the layer stack: a landmark, a shortcut down that is a problem coming up, and a hard vertical edge in a world made of soft horizontal ones. The vertical passes run AFTER the ore field, so a rift slices veins and shows them in its walls. Budgeted against the dig-your-factory guard (first cut tripped it at 26.5% open); floor spires kept stubby after two agentic rungs failed on stalagmites taller than the body could step over. |
| S5 | `1c6aaa2` | **The descent gets a colour arc.** Stone, shale and deepslate sat within 0.03 of each other on every channel — three materials the eye reads as one — and twenty rows of the game's heart were painted in exactly one colour, with depth sold by darkness alone. Warm ochre clay, honest neutral middle, slate-blue Stonereach, cold violet approach. |
| S5 | `829c20d` | **Stop playing through a keyhole.** The camera shows 40×22 cells; the lamp revealed 5.4. Whatever the terrain passes put in the world, the player met one lamp-width of it at a time. Now 9 cells — the lamp shows you the ROOM, not the arm's length. |
| S5 | `91c0529` | **The chasm pays.** A landmark you have no reason to visit is scenery. Rift walls mineralize (real fissures are where hydrothermal veins form), rifts keep clear of the spawn window, and rich ore stays a deep find — the chasm makes the deep band richer, it does not move the band up. |
| S5 | `b17ec1e` | **The horizon gets a shape**, and every hillside becomes climbable by construction. The plateau ran 36 columns against a 40-column camera, so the first frame's horizon was a ruler line edge to edge. Relief ramps back in outside the fixture pad — and the slope budget is arithmetic (Σ amplitude×frequency < 1, envelope ramps included) and asserted per column per seed, because 2-row rises are walls and travel across them measured at 60% of flat-ground speed. Caught a real trap en route: at a shaft mouth flush with the ground beside it, the climb stopped one row short and leapt into the shaft's own second column, forever. |

### Strike 6 — the vibe layer, and the lighting bug under all of it
| Slice | Commit | What changed |
|---|---|---|
| S6 | `e3d491e` | **The score descends with you.** There was a full ambience layer — wind, cave-air, drips, a factory hum — and no TONE. Three synthesized beds (an OPEN stack with no third, a MINOR colour, a SUB weight) run in parallel, mixed purely by depth, with the whole stack pitched down together: you are not hearing tracks crossfade, you are hearing one thing sink. Partials are snapped to whole cycles per loop window, which is what makes the loops seamless without a crossfade. |
| S6 | `e3d491e` | **Footsteps exist.** The single most frequent action in the game was silent over a hardcoded brown puff. The material underfoot now picks the scuff pitch and the dust colour, so a stone floor never throws dirt and the body stands ON something. |
| S6 | `e3d491e` | **The descent is named.** A permanent depth readout (metres below the datum, plus the band you are in, in that band's colour) and a one-time arrival banner with a pitched sting the first time you cross into a band. Descending crossings only — climbing out is retreat, not arrival. Forty rows with no waypoints and no answer to "how deep am I" now has seven of the first and a permanent answer to the second. |
| S6 | `ca43f7d` | **The dig rhythm.** The biggest single source of tedium was that mining had no momentum: every block started from a dead stop, so a twenty-block shaft was twenty unrelated chores. Consecutive breaks now build a rhythm (three blocks to full) worth +60% charge rate and a third off the swing cadence. Nothing is displayed for it — the body swings visibly faster and the strikes come audibly quicker. The first block of a session still costs exactly what it did, so hand-mining still argues for automation. |
| S6 | `88cc897` | **MASS OCCLUDES — the lighting bug under the whole "it reads 2D" complaint.** The veil's light level was a pure function of ROW: open air and the middle of a hundred tonnes of rock at the same depth got identical light. A torch-lit 13×7 chamber measured luma 0.142 against 0.117 for the stone around it — 1.2×, which no eye reads as SPACE — so the recessed wall plane, its cast shadows, the carved edges and the second-plane hue shift were all arguing with the lighting. Openness is now a blurred field and buried cells lose MASS_SHADE of their light; the same chamber measures 3.5×. Two things fell out: WALL_RECESS could go back from 0.52 to 0.32 (half the wall's value had been spent proving it was not the rock in front of it, at the cost of the room's back wall being a black rectangle), and torches got the head-lamp's two-cut treatment, because one quadratic pool put a 2-cell disc on the wall and left the rest of a hung chamber black. |
| — | `e3d491e` `ca43f7d` `88cc897` | Three new harness layers for three things that rot silently: **`check_score`** (seamless loops, a monotone descent, an eased mix), **`check_rhythm`** (a cold start is unchanged; the grace window outlasts the gap between pick-blows, or the rhythm would sag mid-charge and read as stutter), **`check_room_reads`** (the contrast law off the baked veil, not off a screenshot). 30 layers, green. |

### Strike 7 — a world big enough to get lost in, printed on rock that isn't static
| Slice | Commit | What changed |
|---|---|---|
| S7 | `9b2cc68` | **The world grows 96×80 → 128×128.** A 40×22 camera in an 80-row world could see a fifth of the whole descent at once, and the deep band was eleven rows thick — you arrived at the bottom before the score's minor bed had finished coming in. The layer ladder was re-spanned into the new height rather than stretched (deepslate 76, seal 84), so onboarding is untouched: loop-health 98.7 → 98.5, first-arc 1162 → 1108 frames. The size is the *pacing*, not a number. |
| S7 | `613853c` | **Bigger world was, briefly, an emptier world.** Every generator budget was a `*_PER_COL` figure — caverns, tunnels, rifts, ledges, four ore fields — so growing the world 60% taller kept the same feature COUNT spread over 60% more rock, and the deep got measurably barren the moment it got interesting. All eight sites now scale against `DENSITY_ROWS`, the height the figures were tuned at. Density is a property of the world, not of its column count. |
| S7 | `72428a9` | **The map becomes a descent chart.** It was a minimap: a rectangle of coloured cells that answered "what is beside me" in a game whose only question is "how far down am I". It now draws the strata as labelled bands down the side with your own depth marked against them, and the HUD stopped sizing its own panel from world constants — a 128-row world had been silently inflating the map box past the screen. |
| S7 | `96b05c7` | **The rock was static, and the moss was a lawn.** Two texture fields shipped above the grid they were sampled on (the fine grit octave at 1.30, the molding boundary grit at 1.10), so underground rock printed as a high-contrast 8px checkerboard under a one-pixel dithered edge — and worse, that checkerboard was averaging away the hue, patch, crack and rim passes layered on it. Grain is now sampled anisotropically (X compressed to 0.38) so speckle became *bedding*; moss got a depth gate, because a cave-floor lichen that grows identically at row 20 and row 90 is wallpaper. |
| S7 | `335f5f0` | **`tools/check_texture.gd` — no noise field may be white noise.** The frequency bug is easy to write (a bigger number reads like "finer detail") and impossible to see in the source, so it gets a test rather than a comment: sample each field along the line the real paint loop walks, measure lag-1 Pearson autocorrelation, fail below 0.25 — roughly three samples per feature, the honest boundary between texture and static. It found three fields the hand pass missed, all from one cause: FastNoiseLite defaults to **5-octave FBM**, so a field with a perfectly resolvable base still ships four doublings of it and the top octave is always over the grid. Octave budgets are now explicit per field. With the fractal tails gone the base frequencies could finally come down to what they always meant. 31 layers, green. |

### Strike 8 — the rock had a pattern but no surface
| Slice | Commit | What changed |
|---|---|---|
| S8 | `48ec8f3` | **The paint is what you see, so test the paint.** `check_texture` now bakes the real FineTerrain over a real world and measures the PIXELS, because the field-level Nyquist guard is structurally blind to the three ways confetti actually gets in: amplitude (a resolvable field times a loud swing steps just as hard as an unresolvable one), thresholds (a mask is far less correlated than the field it came from, so an "embedded stone" cuts into single squares), and stacking. The metric is a **second difference**, not a neighbour step — a step ceiling punishes FORM, since a smooth shading gradient steps between neighbours exactly as much as a checkerboard does, while a checkerboard hides under it. Curvature is zero on any ramp and peaks on alternation, which is the distinction the eye makes between "this is curving" and "these are two tiles". |
| S8 | `48ec8f3` | **The retune.** Grain spread to features spanning 8–11 fine cells at two thirds the amplitude; stone and crack cut to one octave each (a thresholded field must not carry an octave tail — doubling once puts detail at the grid's own scale and prints the blob as squares and the crack as dots) and both ramped in with smoothstep instead of switching; a floor under the value, because six independent darkeners stack there and unfloored they punched single cells to black. Measured 12.7% / 17.9% roughness before, 5.9% / 5.6% after. |
| S8 | `48ec8f3` | **The form the confetti was standing in for.** In the paint, a signed key from how directly a cell sits under sky-ward air versus under an overhang, falling off over six rows rather than two, because the eye reads a gradient as a curved surface and a step as an edge. In the veil, the same idea at world scale and nearly free: the VERTICAL GRADIENT of the openness field — already baked, already smooth — is exactly the missing "which way does this mass face". A dug chamber now measures 2.21× its surrounding rock, up from 1.76×, and its own floor keeps 122% of the open light. |
| S8 | `48ec8f3` | Moss patches were three fine cells across — green confetti, the loudest wrong note in the shallow rock; and the carved-edge teal and back-rock blue were strong enough to print edge cells as navy holes. |
| S8 | `48ec8f3` | **The arrival banner became an arrival PLATE.** At three times its size across a full-width bar, the one moment the descent gets to be an event read as a modal dialog — it covered the play space and competed with the objective banner directly above it. Weight in a title card comes from spacing, not point size: half the type, letters tracked apart, a kicker carrying the depth, rules only as wide as the words, no panel at all. |

### Strike 9 — the miner builds a run
| Slice | Commit | What changed |
|---|---|---|
| S9 | `dbed1d3` | **The stride.** RUN_SPEED is tuned for MINING — close quarters, one cell at a time, stop exactly where you meant to — and it is the wrong speed for crossing 128 columns; the world grew 60% taller without the legs getting any longer. Raising the constant would fix the commute and ruin the mining, which is why it stayed wrong. So it stops being a constant: hold one direction on the ground and after 0.9s of unbroken travel the miner settles into a run 55% faster over the next 1.2s. Everything short — a step to line up a dig, a hop onto a ledge, the whole first second of any movement — is untouched, and the measured top speed still reads 150.0. |
| S9 | `dbed1d3` | **It costs something, and a wall needs no special case:** a wall zeroes velocity.x, which fails the "actually travelling" test, so running into rock breaks the run without the controller ever being told what a wall is. It survives leaving the ground, so a ledge mid-sprint doesn't cost the sprint. **And it buys something** — the property that decides whether this is a mechanic or a number: a five-cell gap is cleared running and NOT walking. Speed you can only feel is decoration; speed that changes which terrain is passable is a verb. |
| S9 | `dbed1d3` | The tells came mostly free, because everything that sells speed was already velocity-driven. Added: the body leans into the run the way it already leans into a swing, the heels kick more floor up, and the camera **leads further** — a camera that keeps the body dead centre at 232 px/s quietly cancels the whole point, since the ground scrolls faster but the frame looks identical. |
| S9 | `dbed1d3` | **`check_stride`** holds the two halves against each other and they pull hard enough that neither survives alone. Also fixed RUNG 4, which the run broke honestly: the agent walked to its column at 222 px/s and its own momentum carried it off the spot. A player brakes on approach without being told to; the agent had to be. |

### Strike 10 — the first screen had nothing in its bottom half
| Slice | Commit | What changed |
|---|---|---|
| S10 | `6b47515` | **Daylight soaks into soil, not rock** — sixteen tiles instead of seven. The band under the grass is the INVITATION to dig; the dark begins at rock depth, where the player has genuinely descended. The deep is untouched. |
| S10 | `6b47515` | **The soil gets a profile**, keyed to depth below its own column's surface so it follows a hillside rather than lying in flat world rows: dark organic humus under the turf, warm iron-stained subsoil, pale pebbles and dark clasts (soil is a MIXTURE, not a solid — that is the difference the eye reads between dirt and rock), and roots reaching down from whatever is growing above. |
| S10 | `6b47515` | **`check_opening`** — dead space becomes a number, after two wrong instruments. Relative detail rewards darkness (at mean luma 14 a two-byte dither scores 14% and looks like nothing); band averages hide regions (dead space is SPATIAL, so tile it and cap the dead fraction); and judging the sky was only ever measuring how much sky is in frame. The judged region now starts at the real horizon, read from the sim and the live camera. **13 of 32 ground tiles dead before, 0 after.** It also caught the fix overshooting — reading soil inclusions at the rock's own scale turned the opening into a gravel pit that scored beautifully and looked worse than the gradient it replaced. |
| S10 | `6b47515` | The harness grows a **second kind of layer**: the dummy renderer paints blank frames, so anything judging PIXELS has to own a window. `add_gl` runs it without `--headless`, and it self-skips green where no display exists — a passing "no dead space" on an all-black image is a lie. 33 layers. |

### Strike 11 — the rock never told you what was behind it
| Slice | Commit | What changed |
|---|---|---|
| S11 | `2f965c9` | **The hollow ring.** The generator fills this world with caverns, halls, rifts and aquifers and none of it existed until you physically fell into it — every block was broken blind, which makes digging a chore rather than a search. A face with a cavity behind it now answers the pick differently: `_hollow_at` cones forward along the swing direction, and the ring is layered over the crunch, pitched and level-scaled by how much void is back there. |
| S11 | `2f965c9` | **You can see it too** — a draught of dust pulled toward the cavity, so the tell survives with the sound off. |
| S11 | `2f965c9` | **The breach beat.** Punching through into real space is a low swell (a closing filter over a 74→38 Hz sink), a burst of dust and a shake. Hear the ring, then the breach, and a dig has a shape. |
| S11 | `2f965c9` | **`check_tells`** proves the tell is HONEST in both directions on a hand-built fixture: it climbs on approach (0.00 → 0.16 → 0.48 → 0.96 → 1.00) and never falsely peaks, it reads 0.00 in solid rock (a tell that fires everywhere is worse than none — the player learns to ignore it), and it answers the SWING rather than the standing spot (0.96 into a void, 0.00 away from it). 34 layers. |

### Strike 12 — the session had no measured shape, and its best moment was a checkbox
| Slice | Commit | What changed |
|---|---|---|
| S12 | — | **`arc_driver.gd`** — the first-automation arc extracted from `check_loop_health` (463 → 167 lines) so more than one layer can play the *same* opening. Two copies of an arc are two arcs, and the day they drift is the day the two numbers stop being about the same game. |
| S12 | — | **`check_pacing`** — the instrument this whole push was missing. Every other layer measures a MOMENT; this one plays a real session (the opening arc, then the descent that follows it) and writes down the NEWS, then scores the two ways pacing fails: the **longest silence as a share of the session** (scale-free, because an agent plays six times faster than a person) and the **event density** (a session can be evenly paced and still have nothing in it). It prints the whole timeline plus a shape strip. Measured 15% / 26.6 per 1000 frames; caps ratcheted to 20% / 18.0. |
| S12 | — | It found its first bug in itself before it found one in the game: counting raw stratum *changes* scored fourteen announcements in the opening, because the surface band boundary runs through the row you walk on. The plate is latched and fires once. An instrument that credits the game for banners it doesn't raise is worse than no instrument — it now mirrors `_note_stratum`'s gate exactly. |
| S12 | — | **THE LINE RUNS.** The finding: the longest silence in the whole session sat *immediately after first automation* — the moment the game's entire thesis lands, the moment a machine the player built outgrows them, and it ticked a checkbox and said nothing. It now gets the arrival plate (the game has exactly one channel that means "stop, look" and this is what it's for), a new `ignite` sting — a spin-up, a knock of engagement, and a major triad that locks in rather than stabs — and sparks, dust and a shake aimed at the MACHINE rather than at the screen. |
| S12 | — | **The arrival plate becomes legible anywhere.** Photographing the new hail exposed a defect five strata plates had been hiding: panel-less type only reads over something dark, and every stratum plate fires underground. At midday against a bright sky the words simply vanished. Fixed with a scrim rather than a panel (a panel is the modal dialog this design was built to escape) — and the *first* scrim was worse, stacking translucent bands with an overlap to hide the seams, when overlapping alpha COMPOSITES and every seam came out darker than its neighbours, rasterizing as venetian blinds across the sky. Rebuilt as an interpolated vertex grid: adjacent quads share edge vertices and their colours, so it is one continuous smoothstepped field with no edge anywhere for the eye to catch. |
| S12 | — | **A `line` capture moment**, timed off the ceremony rather than off the driver (the arc's last step stands back and waits, so by the time it returns the plate has come and gone). `history/95-the-line-runs.png`. |

### Strike 13 — the earth was not rich, and finding a seam was not a moment
| Slice | Commit | What changed |
|---|---|---|
| S13 | — | **`check_richness`** — strike 12's parting shot, measured. Sinks seventeen honest shafts through the real generated world and counts ENCOUNTERS, where an encounter is a contiguous RUN of something other than plain rock (a six-cell vein is met ONCE, not six times). Two numbers, per band and overall: the **density**, and **the drought** — the longest unbroken run of plain rock anywhere in any shaft, because a world can hit a fine average and still contain the stretch that made the player quit. |
| S13 | — | The verdict was worse than the pacing timeline suggested: **a 55-row drought at column 55, running from the surface through the entire top half of the world**, and TOPSOIL — the band a new player spends their whole first session in — at **1.2 encounters per hundred rows**. |
| S13 | — | **The depth ramp gets a floor.** Vein acceptance was `depth_frac × CHANCE_DEEP`, a linear ramp *from zero*, so the design intent "deeper is richer" was implemented as "the shallow world is empty". It now runs from a floor to full; deep acceptance is untouched (at `depth_frac` 1 the floor drops out of the expression), so the core pull survives exactly as designed and "poorer" stops meaning "barren". **TOPSOIL 1.2 → 7.3.** |
| S13 | — | **The drought pass** — the guarantee randomness cannot give you. An average is not what tedium is made of: random placement produces long empty runs constantly, because that is what randomness IS, so the property has to be *enforced*. A last pass over the finished rock walks every column and plants something back into the middle of any silence that has run too long — usually a small vein, and a third of the time a **vug**, a little cavity in solid rock, which is the better half of the deal because strike 11's hollow ring makes a vug something you *hear before you reach it*. **Drought 55 → 19 rows, density 5.6 → 8.2.** |
| S13 | — | **The strike that finds the vein.** Enriching the whole world moved the session timeline by *exactly nothing*, which exposed the real gap: breaking the first block of a seam and breaking its sixth were the same event. Strike 11 taught the rock to say there is SPACE behind it; this is the other half of the sentence. It fires on **exposure, not proximity** — a neighbour only counts if this blow is what uncovered it, every other side still buried — so tunnelling along a seam you already opened stays quiet, and breaking through into one rings: a struck-bronze `vein` sting (two partials a shade out of tune so they beat against each other the way real struck metal does), a spray of sparks in the ore's own colour, and a kick. |
| S13 | — | The descent's timeline stops being a metronome: `\|..\|..\|..\|.\|` → `\|..\|\|..\|\|\|\|.\|`, session density 26.6 → **30.6** events per 1000 frames, floor ratcheted to 24.0. 36 layers. `history/96-the-earth-has-things-in-it.png`. |

### Strike 14 — the rock had no detail below its own cell
| Slice | Commit | What changed |
|---|---|---|
| S14 | — | **`tools/dead_space.gd`** — what "dead space" MEANS, and the two wrong instruments it took to get there, extracted out of `check_opening` so more than one layer can ask the question and they are provably asking the SAME one. Two definitions of dead space would be two standards. |
| S14 | — | **`check_underground`** — the surface is the easy half and it is the half a player looks at for thirty seconds. Everything after that happens under a lamp, under a veil that MULTIPLIES, which is exactly the arithmetic that took the opening's bottom half down to five levels while every terrain pass ran correctly. The design problem was making a guard that does not punish darkness: down there the dark is the POINT, and a test that counted unlit tiles would only measure how much unlit rock is in frame and push the whole game toward flat and bright. So it judges only tiles above a **lit floor** — the lamp pool and the near rock. A dead tile out in the black is correct; a dead tile under your own lamp is the picture failing where the player is looking. |
| S14 | — | The verdict, magnified 3×: the lamp-lit rock is a field of **flat squares**. The molded texture holds one texel per 8-pixel cell and is drawn NEAREST, so there is exactly zero detail below that cell — and it sits directly beside a miner sprite drawn at one-pixel detail, so the eye reads the world as the blurred thing behind the sharp thing. It looked like compression artifacts. It also slipped through the shared dead-space test, because the **lamp's own gradient** satisfied the range half of the test while the rock supplied none of the detail half. |
| S14 | — | **`rock_grit.gdshader`** — tooth inside the cell, locked to WORLD space. That distinction is the whole point: the screen post-pass already carries a film grain and cannot do this job, because grain that sits still while the rock slides underneath reads as dirt on the lens. Two octaves (one is television static), mostly multiplicative so dark faces do not fizz, with a small additive floor. This is **not** the crisp-versus-molded fork — that fork is about cell BOUNDARIES, which this does not touch; it is about what lives inside a cell, and the answer in both aesthetics is "something". **Local contrast in the lit rock: median 2.8 → 5.5, minimum 1.6 → 2.9.** `history/97-the-rock-gets-tooth.png`. |
| S14 | — | It cost an hour to a Godot detail worth writing down: **`COLOR` arrives in a canvas `fragment()` already holding texture × modulate**, so sampling `TEXTURE` again and multiplying it back in *squares* the value. The whole world rendered at 0.4× brightness, and it was slow to pin down because an inert version of the shader did it too — the bug was in the boilerplate, not in the effect. Measured, not eyeballed: mean frame luma 16.21 → 6.57 → 16.24. 37 layers. |

### Strike 15 — the way down was not a route, it was a chore
| Slice | Commit | What changed |
|---|---|---|
| S15 | — | The pacing timeline put the session's longest silence in one place, and it was not where I expected: the moment first automation lands, the player turns around, and heads for the deep. What they do then is pick a column and hold the mouse, for as long as it takes, and that is the whole second act. It is not traversal, it is a progress bar performed at a fixed rate — which is why the descent's timeline came out a metronome even *after* the earth was given things to find in it. Richness fixes what you meet on the way down. It cannot fix that there is only one way down. |
| S15 | — | **`tools/check_descent.gd`** — measure the geometry the choice would need, before building anything on top of it. Flood the *standable* open space from the sky downward (four-connected and two cells tall, because a body walks and falls and does not squeeze through diagonals) and ask three questions: how deep does it REACH, how many separate MOUTHS can it be entered from, and where is the tallest DROP worth committing to. The verdict on the world as generated: **1 row.** The rifts that give the underground its vertical structure were all sealed under an unbroken lid of topsoil. The grapple was hanging in a world with nothing to hang from. |
| S15 | — | **Sinkholes** (`_open_sinkholes`) — three throats per world, cut from a rift's ceiling up to daylight: a narrow shaft that FLARES as it rises, so it reads from the surface as a mouth rather than a bore hole, and wanders a little on the way so it is not a drilled line. Placed off a real rift and spaced apart, so every one of them goes somewhere. **Reach 1 → 63 rows. Standable open space 2305 → 4062 cells.** The descent is now a decision — dig (slow, safe, yours) or find the open way and ride it down (fast, committed, the world's) — and a decision is the difference between traversal and a chore. |
| S15 | — | Three worldgen guards went red, and they were right to: they encoded "the near-surface is sealed", which had been true and was now the thing being changed. The wrong fix is to loosen them. **`WorldData.routes`** — provenance, not content: every cell a *deliberate* vertical route carved. The identity guard asks whether the underground is solid-dominant, whether caves are punctuation in rock you carve rather than the medium you traverse; a chasm cut on purpose to give the world a vertical dimension is the *opposite* of what that guard defends against while being indistinguishable from it in a raw open-cell count. So the guard now measures **undirected** cave separately (17.0%, ceiling 25%) from total open space (26.5%, ceiling 32%), and surface-walkability counts MOUTHS — cliff groups, `SINKHOLE_COUNT` of them — instead of column steps. The number stayed honest and the world got to change. |
| S15 | — | RUNG 4 then failed, and the failure was the feature working: the play-test hardcoded column 84 as clear ground, a sinkhole opened at 78–84, and forty rows of hole is a wall however good the ground looks on the far side of it. `_standing_ground` now walks outward from where the body actually IS and stops at the first cliff, returning the furthest column that is both FOOTED (solid for a socket's depth — level ground can open into a rift two cells down, and the second cut drops you through your own floor) and REACHABLE. A play-test that assumes a flat world is a play-test that forbids one. 38 layers. `history/98-the-way-down-is-a-choice.png`. |

### Strike 16 — the second route existed, and nobody could have taken it
| Slice | Commit | What changed |
|---|---|---|
| S16 | — | **`tools/check_plunge.gd`** — Strike 15 proved the geometry of a way down and stopped there, which is exactly one step short of knowing anything. So both routes get PLAYED, from the same surface to the same depth in the same world: sink a shaft by hand, or walk to a mouth and go down the hole. Three numbers, each a different way to be wrong — the SPEEDUP (a route slower than the pickaxe is a novelty), the COST (the plunge must break zero blocks or it is the first route with a head start), and the PURCHASE (whether the rope can bite in the throat, which is what separates a fall you steer from a cutscene with a landing). First honest verdict: the body fell twelve rows, landed on a shelf, and stood there for the entire budget. |
| S16 | — | The first thing that broke was the guard that had greenlit Strike 15. `check_descent` flooded open space four-connected and reported a reach of sixty-three rows — but air is connected in ways a body is not, and that flood happily walked the miner up a nine-cell wall one cell at a time. Rewritten to move the way the CONTROLLER moves: step up one, jump up two, fall any distance, and nothing else. Same reach, 63 rows — but connected standable space **4062 → 1094 cells**, and now the number means what it says. A connectivity proof a body cannot reproduce is not a proof. |
| S16 | — | The mouths opened over the *leftmost* rift column that cleared the keepout, which is frequently the thin tapering END of a chasm — hence the twelve-row drop onto a floor. They are now ranked by `_drop_below`, the unbroken fall underneath, and cut over the deepest, with `SINKHOLE_MIN_DROP` refusing to open one at all over less than fourteen rows. The wander that keeps a throat from reading as a drilled pipe was also drifting the shaft off the column the fall was under, so a body slid down the SIDE of its own sinkhole catching every shelf: the source column is now opened at every row regardless — one plumb fall line with the collapse shaped around it. |
| S16 | — | **The winch could not haul from standing.** `player.gd` gated reeling to `not on_floor`, defending against a conflict that does not exist — jump is Space, the reel is W/S, and on the ground with a hook planted overhead the key did nothing at all. What it cost was the tool's entire headline claim: the grapple exists to answer the trip back up, and a winch that only engages once you are *already airborne* is not a way up, it is something you use after a jump. The played descent caught it the expensive way — a body standing on a shelf, holding UP into a planted line, for 150 frames, three separate times. Now it hauls from standing; the only refusal left is winching toward an anchor at or below your own feet. |
| S16 | — | **`REEL_SPEED` 165 → 420 px/s.** The body runs at 150 and strides at 232, so hauling yourself up a line was *slower than walking* — a hand-over-hand crawl wearing a winch's name, and it made the free route cost three hauls and 48% of the descent. 420 is thirteen cells a second: decisively faster than the legs, so reaching for the rope is always the quick answer, and still slow enough that a long haul is a commitment you feel. The pendulum is untouched, because reeling changes the RADIUS and the arc's speed comes from conserved tangential momentum — measured, the swing still tops out at **2.80× RUN_SPEED** and the reel lift went to **6.8 cells**. |
| S16 | — | The verdict after all four: **legs alone get 16 rows down the hole; the rope gets 34** — the tool's reason to exist, stated as a number, in terrain nobody designed for it (`check_grapple` proves the rope works on a rig built to suit it, which is a different and much easier claim). And the plunge went **0.3× → 1.1×** the pickaxe's speed at zero blocks broken. The 2.0× floor I wrote before ever playing the route was a wish; parity is the line that matters, because below it the free route is a novelty and at parity-plus-zero-cost it is a genuine choice. 39 layers. `history/99-the-rope-is-the-way-down.png`. |

### Strike 17 — the tool you move with was fired blind, and it dropped you every second press
| Slice | Commit | What changed |
|---|---|---|
| S17 | — | **The aiming ghost.** Every reaching tool in the game shows you its target — the pick has its aim box, the builder its ghost — except the one tool whose entire job is *distance*. You pointed at a wall fifteen cells off and found out whether you had the range, and whether anything was in the way, only after the throw. So: a thin dotted lead and a small ring on the cell the hook would take, drawn quietly (nothing that competes with an ore glint) and ONLY while the line is stowed, because once you are on the rope a second line racing your cursor across the rock is noise at exactly the moment you can least afford it. |
| S17 | — | **Chaining.** A second press used to CUT the line — the right binding for a tool you reach for occasionally, the wrong one for a movement system. Crossing a chasm in three arcs meant six presses, and every second one dropped you out of the swing you had just built, so the rope could never become a *rhythm*. Now firing while anchored throws a new hook while the old line keeps holding, and the anchor swaps only at the instant the new one bites: nothing is ever released into empty air, and a throw that finds no rock costs you the throw and nothing else. Letting go needed no key of its own — jumping off a taut line already cuts it and stacks a leap on the arc. |
| S17 | — | **`tools/check_aim.gd`** — the ghost is only worth drawing if it is HONEST, so 48 shots go round the compass and every predicted bite is checked against where the hook actually plants. Three of forty-eight disagreed. The cause was that the hook flew in `FLY_SPEED × delta` bites with each frame's leftover clipped, so the sample points depended on the frame rate and on when in the flight you looked — a shot grazing a block corner resolved one way in the marker and another in the hook. Both now walk fixed quarter-cell steps **from the origin**, and they agree 44 of 44. Three lies in forty-eight is all it takes to stop trusting a marker, and a marker you distrust is worse than none: you are then aiming blind *and* reading noise. |
| S17 | — | Chaining also yanked ten percent of the radius out at the swap (the fresh-plant slack takeup), which the constraint reads as outward motion and cancels — an arc that bleeds speed every time you reach for the next hold is a chain nobody chains. A chained plant now takes the distance as it is and lets the swing tighten it. |
| S17 | — | Three assertions in this layer were written, measured, and thrown away, which is the part worth keeping: **"chaining keeps more speed"** is false — a body that lets go is a projectile and a projectile never loses speed, so free-fall "keeps" 96% of the arc *by falling out of it*. **"Chaining keeps more height"** and **"covers more ground"** are true or false depending entirely on where the next hold is and when you threw, and a well-timed release beating a chain is not a bug, it is the skill ceiling of a ninja rope working as designed. Gating on any of them would freeze one rig's geometry into a rule about movement. What chaining actually promises is narrower and absolute — you are never dropped (0 frames off the line, against 12 for the old toggle), the swap happens, and a throw that finds nothing costs nothing — so that is what is asserted, and the trade is printed beside it as context. |
| S17 | — | The finer probe step shifted bite points enough to cost the played descent an extra hop (`check_plunge` 1.1× → 0.9×, under its floor). Fixed at the source rather than by moving the floor: the hop was winching all the way to the hook when it only ever needed to clear one lip, so it now releases the moment the way ahead reads open. Hops fell from ~50 frames to 7–9, and **the plunge went to 1.4× the pickaxe**. 40 layers. `history/100-the-hook-you-can-aim.png`. |

### Strike 18 — a fall cost nothing, and speed sounded like standing still
| Slice | Commit | What changed |
|---|---|---|
| S18 | — | Once the mouths opened and the winch got geared up, a forty-row hole became a *strictly better staircase*: free, instant, and with no more consequence than stepping off a kerb. A route with no downside is not a choice, and making the descent a choice was the entire point of cutting the mouths. So a hard landing now costs **grip** — for a fraction of a second the legs have reduced authority and the stride is gone. Deliberately not damage: there is no health system, inventing one to price a fall is a far larger decision than this needs, and a platformer that takes control *away* feels broken however well-earned the moment. You still steer, still jump, still mine; you just do not accelerate out of a forty-metre drop like you stepped off a kerb. |
| S18 | — | Priced on the **distance fallen, not the impact speed**, and that distinction is the whole design. Impact speed saturates — terminal velocity arrives after 5.4 cells — so by that measure a six-cell hop and a forty-row plunge land identically, and any threshold fires on both or on neither. The first implementation used speed and `check_impact` showed exactly that. Distance keeps counting, and it is also what the player is tracking: nobody feels px/s, everybody feels "that was a long way down". |
| S18 | — | It also makes **the rope the answer with no special case**: a taut line RESETS the fall, because a fall the rope caught is over. Let go again and a new one starts from there. A descent you flew properly costs nothing, one you merely survived costs a beat, and let go too high and the *new* fall is long enough to charge for too. Measured: the same 30-cell drop costs 0.24s uncaught and 0.00s caught — and both still land at terminal speed, which is not the rope failing, it is why the price is distance. |
| S18 | — | Pricing a fall by distance meant every **teleport** — a savegame restoring your position, a harness rig setting up a shot — banked the whole warp as a drop and charged for it on the next touchdown. `Player.place()` is the seam all six non-gameplay movers now go through. Nothing in the game teleports during play, so this is not a gameplay concern; it is the kind of latent bug that only appears the moment a quantity starts being *measured across time*. |
| S18 | — | **The rush** (`Sfx.set_rush`) — a speed-driven bed, brighter and thinner than the surface wind, riding pitch as well as level because that is what actually sells velocity: a bed that only gets louder reads as "more wind", one that also climbs reads as "you, going faster". Zeroed at RUN_SPEED, so ordinary mining never whistles and the sound can only ever mean "faster than you can run" — the one speed the rope and a sinkhole give you. Every other bed in the mixer tells you WHERE you are; none of them told you how fast. |
| S18 | — | And the cost is made **visible**: the impact pose is held for exactly as long as the grip is missing. A cost a player cannot see reads as the controller having gone vague — they feel the sluggishness and blame the game, not the forty metres they just fell. Land hard, fold up for a beat, push off slowly: one legible event. 41 layers. `history/101-sixty-four-metres-down-one-hole.png` — the plunge delivering the body 64 metres down into an aquifer chamber, in one fall, for free. |

### Strike 19 — the aquifers were blue rectangles
| Slice | Commit | What changed |
|---|---|---|
| S19 | — | The played descent now drops a body sixty-four metres into an aquifer chamber, which turned water from something you wade through into something you LOOK at — and looked at, it was the most programmer-art thing on screen. A uniform translucent slab, a hard bright stripe along the top, and *more stripes stacked inside it*: the waterline was drawn for every water cell rather than only the exposed ones, so a pool three deep came out as three glowing horizontal rules in a flat fill. It read as a stack of UI panels. |
| S19 | — | Three fixes, none expensive. **The surface is the surface** — only a cell with nothing above it owns a waterline, and only that line ripples (a travelling sine with a soft meniscus hung under it, so the fill appears to *end in* a surface instead of having a stroke painted on it). **Depth darkens** — the further inside the body a cell sits, the deeper its colour, because a gradient is the cheapest cue that a volume has volume. **It moves** — two caustic band sets at different scales drifting opposite ways, because one band pattern is a stripe and two interfering is what light on moving water looks like. |
| S19 | — | The rig immediately found a second bug the eye had been reading as "terracing": **an interior water cell was drawing its own level as a height.** A cell's level is bookkeeping about how much water lives there, not how tall it is — the water above is resting ON it, so there is no air in it to draw. Honouring the level everywhere made any settling body break into horizontal slabs with rock showing between them, which is what a large pool looks like for the seconds the sim takes to even out, and what an unevenly-fed aquifer looks like forever. |
| S19 | — | The self-sheen was drawing a 1.15-cell glow at every cell centre: adjacent discs touch without merging, so a wide aquifer was a visible field of **polka dots** — invisible under a flat slab, and the loudest thing in frame the moment the fill stopped being one. It now lights only the body's SKIN (top and side cells) over a radius wide enough that neighbours blend, which is cheaper on a deep pool and closer to what dim water does anyway: the light leaves at the surface, not out of the middle. |
| S19 | — | **`tools/check_water_reads.gd`** (`add_gl`) — judged from pixels on a sealed, flooded cistern. Getting the rig honest took four passes, and each failure is worth more than the fix: the body was placed inside solid rock and shoved to daylight forty rows away; the shared dead-space judge reads FULL-WIDTH rows and was grading mostly rock; the HUD's banner, stratum plate and a hint bubble sat across the water and accounted for most of the "bright edges"; and the reference strip taken below the pool floor turned out to be *the world's own natural aquifer*, so the water was being compared against more water. The reference is now the cistern's own sealed wall — rock by construction, same depth, same light. |
| S19 | — | And one assertion was deliberately **downgraded to a report**: the shared dead-space judge grades this body 60% featureless, and it is the wrong standard here. "Dead" was defined for ROCK, which is supposed to have tooth; water is the one thing in frame that is *meant* to be smooth, and the only way to satisfy a terrain standard would be to put grain on water. The property a fluid actually has to have is that you can see it is there, so the gate is colour separation from the rock it sits in — **47 sRGB levels of blue-over-red** — with the dead fraction printed underneath for anyone reading a regression. 42 layers. `history/102-water-that-reads-as-water.png`. |

---

### Strike 20 — the ground stopped being a table

The surface was measured before it was changed, and the picture that came back was one character per two
columns, `0` = highest ground:

```
0000000001249000000000000000000000000000000001100001200000000000
```

Flat. The apparent sixty-seven rows of range was *entirely* the three sinkhole mouths — with the holes
excluded, nine rows over a hundred and sixteen columns. And it was flat on purpose: the generator holds
`|dh/dx| <= sum(amp x freq) < 1` so every column-to-column step is one the body's auto-step-up glides.

That budget is arithmetic, not a tuning choice, and it has a consequence nobody had written down: **amplitude
is bought with wavelength.** A six-row hill that never steps more than a row needs ~63 columns to rise over.
The world is 128 wide. There is room for two such hills, and that is the entire ceiling on walkable relief
here. No amount of turning the amplitude up gets past it — turning it up just breaks the budget.

So the relief that matters stopped pretending to be a hill and became a **step**. Three fixed scarps split
the surface into terraces at different heights: a five-row headland wall west of the base, a four-row drop
off the eastern edge of the home terrace, and a six-row wall beyond that. Everything between them still
obeys the budget and is walked exactly as before. The faces are the marked exception — the same shape as the
sinkhole mouths, which is to say *a rule kept everywhere by construction and broken only at places recorded
well enough that a test can tell design from noise*.

| # | What shipped | Why |
|---|---|---|
| 1 | `SCARP_COLS` / `SCARP_STEPS` / `terrace()` / `on_scarp()` in `heightmap_world_gen.gd` | Terraces joined by faces too tall to walk up — the only way past the slope budget |
| 2 | Terraces measured **from the base pad**, not from column zero | The fix for the bug the first version shipped; see below |
| 3 | `tools/check_relief.gd` (43rd layer) — relief, steepness, walkability, flatness of the pad, and faces that need the rope, all with mouths excluded | Holds *both* ends: raising relief without the walkability half is just reintroducing the old bug |
| 4 | `tests/test_worldgen.gd` grants scarps the same exemption routes get, and now asserts every designed face **stands** | A scarp flattened by a clamp or eaten by a later pass would leave every other assertion green |
| 5 | `check_plunge` re-aimed: the rope is measured on the way **back**, not on the way down | The old assertion could only pass when the legs route was broken — see below |

**The bug the first version shipped, and what it teaches.** The pad returns the bare datum (`FLAT_SURFACE_ROW`)
by contract, so when `terrace()` accumulated from column zero, the terrain either side of the base sat five
rows above ground the pad held flat. The base was at the bottom of a bowl with unclimbable walls. Three
separate layers caught it and none of them was the one aimed at scarps: `check_fastforward` stalled at 297px
walking out of the base, `test_worldgen` reported a stray five-row rise at column 38 (one column outside the
pad), and `check_opening` went to 22% dead tiles. Subtracting the pad's own terrace value makes the pad a
terrace in its own right and every edge continuous by construction. **A new global offset needs an anchor,
and the anchor is whatever the world holds fixed** — here, the ground the fixtures are stamped on.

**The assertion that was never a property.** `check_plunge` asserted the rope reached *deeper* than legs.
It cannot: a sinkhole throat is cut as a plumb fall line on purpose and nothing beats gravity at going down.
It only ever passed because the mouth it happened to pick had a ledge the legs hung up on — it was gating on
a *defect in the route* rather than a *virtue of the tool*, and it went green again the moment the terraces
reshuffled the ranking toward a cleaner hole. Both runs also stopped at `TARGET_ROWS`, so the number was
saturated at the same ceiling for both and could not have shown a gap even in principle.

Falling in is free either way. What the rope is for is the **return**, so that is what is measured now — and
the measurement immediately found a real defect in the rig (the ride handed input control back to the player
before the climb started, so the winch axis was overwritten by real hardware every frame, and the rope
"climbed" one row). Fixed:

| route | rows regained, same hole, same budget |
|---|---|
| legs alone | **0** — a thirty-four row hole is a one-way door |
| with the rope | **54** — out of the shaft and on up the terrain above it |

Result: 43 layers green.

### Strike 21 — the rope is how you travel

Everything the grapple had been asked to prove was VERTICAL: `check_grapple` swings it on a rig built to
suit it, `check_plunge` rides it down a sinkhole and climbs back out, `check_impact` catches a fall with it.
All of that says the tool works. None of it says the tool is how you MOVE — and "a movement overhaul centred
on the grappling hook" is a claim about horizontal distance per second.

So `tools/check_traverse.gd` (44th layer) crosses the same span twice, in three venues, and the numbers
came back saying three different things:

| venue | on legs | on the rope |
|---|---|---|
| a gallery, 88 columns | 758 frames, top 232 px/s | **606 frames, top 396 px/s** |
| open sky, 40 columns | 471 frames | **351 frames**, on 2 opportunist throws |
| the headland scarp, 5 rows | **stopped** | **over it** |

| # | What shipped | Why |
|---|---|---|
| 1 | `check_traverse` — three venues, frames-to-cross, with the driver reading the aiming ghost before it throws | Turns "is the rope movement?" into a number that cannot be argued with |
| 2 | `Grapple.hauled` + `Player._winch_drive()` — the winch converts line taken in into approach speed | The constraint only CLAMPED a position; the reel was a lift, and set you down with no momentum |
| 3 | The reel gate judges the DIRECTION of the pull, not the anchor's height | Unblocks the ground zip — the only rope verb available with no ceiling |
| 4 | The scarps are proven ANSWERABLE, not merely present | Strike 20 asserted walls too tall to walk up and never checked the rope reached the top |
| 5 | The dust field gets a wind: your own travel, turned around | Streaks said the MINER was fast while the air around it hung perfectly still |

**The winch was a lift, not a winch.** The distance constraint only ever clamps a position to a circle and
cancels the outward radial velocity. Shortening the line therefore moved the body by *correcting its
position* and left the velocity untouched — so the reel carried you along the rope and set you down at a
standstill, every time, and letting go gave you nothing to let go with. All the care in the swing physics
was conserving the momentum of a body that had none. Stated physically the fix is one sentence: a winch
taking line in at `REEL_SPEED` means the body *approaches the anchor* at `REEL_SPEED`. So set the inward
radial component to the haul rate — never add (that compounds), never touch the tangential (that is the
pendulum).

**Three rig defects, each of which read exactly like a broken game.** Worth recording together, because the
instrument was wrong three times before the game was wrong once:

1. *The sky run covered 7 columns in 900 frames.* Not the rope — the jump-when-blocked branch sat in the
   `else` of `if with_rope`, so the roped body had been quietly denied its legs. A rope is an ADDITION to a
   body, and a rig that withholds the boots is measuring its own handicap. (Same principle already written
   into `check_plunge._climb`.)
2. *The driver threw at anything.* On the surface almost every forward-and-up throw plants in the ground a
   cell or two ahead: too close to swing from, too close to zip to, and once the winch has wound in you are
   on a two-foot leash pinned to a wall you cannot walk away from. A probe caught the body frozen at zero
   velocity for four hundred consecutive frames. The game already ships the answer — the aiming ghost — so
   the driver now traces before it throws and skips a hold that is too near, too low, or nothing at all.
3. *The scarp read as unclimbable.* The instinctive throw is steep and across; a five-row plateau three
   columns away is CLEARED by anything steeper than about forty-five degrees, so the hook sailed over the
   top into open sky every single time. Aiming at the lip — which is precisely what the ghost is drawn for
   — puts the body on top of a wall its legs cannot touch.

**And one finding that is level design, not tuning.** A grapple needs something overhead to bite. Under a
roof that is everywhere; under open sky it is trees, scarp faces and sinkhole mouths — and the surface run
beat the legs on *two* throws in forty columns. So the sky is not ropeless, it is **sparse**: out there every
hold is a landmark, which is a fact worth building levels around rather than tuning away.

Result: 44 layers green.

### Strike 22 — the line catches on the corner

`scenes/grapple.gd` used to carry this paragraph:

> *WHAT IT DELIBERATELY DOESN'T DO: the line does not wrap around corners. Worms wraps; Bionic Commando
> doesn't; neither does Spider-Man. Wrapping needs a per-frame corner search and a wrap stack, and it buys
> realism in exchange for a rope whose behaviour the player can no longer predict from where they are
> pointing. A straight line you can read at a glance is the better toy.*

That was the right call for the tool as it then was — a way DOWN a shaft, reached for occasionally. Strike 21
measured the same tool crossing a gallery half again as fast as a full stride, which makes it the movement
system rather than an accessory to one, and a movement system earns depth an accessory does not.

The predictability objection deserved an answer rather than a reversal, and it has one: the line is now
drawn as rope with visible slack instead of as a chord, so a bend is something you can SEE, and the aiming
ghost means the anchor is chosen deliberately rather than discovered.

| # | What shipped | Why |
|---|---|---|
| 1 | The rope is a POLYLINE — `pivots`, `hitch()`, `spent()`, `free_length()`, `update_line()` | A line that hangs through solid rock is a laser with a rope's texture |
| 2 | The constraint and `resolve_velocity` act from the HITCH, not the hook | Wrapping must change where you orbit without ever moving what you are tied to |
| 3 | `_draw_cord` / `_draw_hook` split; the renderer draws the whole bent polyline | Drawing it as one chord put rope through the rock the wrap exists to go around |
| 4 | `tools/check_wrap.gd` (45th layer) — bends, comes off, holds the hook, whips, keeps its speed | Five ways the idea could be quietly wrong |
| 5 | A catch only counts once the run has been in OPEN AIR | The hook bites *inside* its block, so a naive scan caught the line on the thing it was tied to |

**Measured:** the arc turns at **4.8 rad/s wrapped against 1.2 free**, and keeps **100%** of its speed
through the sharpest wrap (420 → 420 px/s, two wrap events at speed). Wrapping spends line, the free radius
shortens, and conserved tangential speed over a shorter radius is a faster rotation — that is the skill
ceiling a ninja rope is supposed to have.

**The pivot fourteen pixels from the hook.** The hook bites at the probe sample where solidity is first
found, so the anchor sits up to a quarter-cell *inside* its own block. A corner scan that took the first
solid sample therefore caught the line on the block it was tied to and pinned the body to the roof it had
just thrown at. A catch now only counts once the run has been in open air: rock re-entered, not rock left.

**And a third assertion that was never a property.** "IT WHIPS" was first written as *a caught arc comes
round under the hook sooner*, which is not something this manoeuvre even aims at — a wrapped line orbits the
CORNER, and reaching the hook's x is a goal that belongs to the unwrapped case. Measured, the caught arc was
*slower* to that mark (90 frames vs 58) while being obviously, visibly faster to watch. Restated as angular
rate about the hitch, the same run reports 4× — the physics was right and the sentence was wrong.

Two more rig lessons, both about checks that cannot fail:

- *"It comes off again"* first compared the FINAL pivot count against the peak, and failed a run whose own
  log showed the pivot being released — the swing back out had caught a fresh one by the time it looked.
  What must be true is that a wrap is REVERSIBLE, so it now asserts the stack **ever** emptied.
- *"Without the pivot eating the arc"* passed while reporting `0 -> 0 px/s`: the counter starts at 1.0 and is
  only ever lowered, so a run with no wrap-at-speed went green on an empty sample. It is now gated on having
  watched one. **A check that cannot fail for want of data is not a check.**

Result: 45 layers green.

### Strike 23 — the rope gets a voice, and the library gets an ear

Three strikes made the line the movement system. It was very nearly silent while being it: a borrowed
`clunk` on the throw, a borrowed `crunch` on the bite, a borrowed `pop` on the release, and **nothing at all
for the winch** — the one rope action you hold down for seconds at a time, hauling thirteen cells a second.
A continuous verb with no continuous sound reads as a thing that is not happening.

| # | What shipped | Why |
|---|---|---|
| 1 | `_gen_winch` + the `set_line` driver — a geared drum under a pawl clicking over ratchet teeth | The biggest hole in the mix: a held action with no held sound |
| 2 | `_gen_creak` — the line singing under load, driven by speed on a TAUT rope | What tells you the swing is carrying weight |
| 3 | `_gen_catch` + a spark at the hitch — the wrap's own voice | A wrap is the one rope event with no other tell in the mix |
| 4 | `tools/check_voice.gd` (46th layer) — audible, distinguishable, click-free, and driven | Nothing here is an audio file; a generator with a sign error ships silence and no diff shows it |

The winch is driven off the drum's **actual haul rate** (`Grapple.hauled / delta`) rather than off the key,
so a winch that has hit `MIN_LENGTH`, or is refused because the pull would wind you into the floor, goes
quiet instead of grinding away on nothing.

**Why a harness layer for sound at all.** Every sound in this game is synthesised at boot from a fixed seed.
There are no audio files, so there is nothing to listen to in a repo and no artist to catch a sound that came
out wrong. A generator with a sign error produces silence; two generators that drift together produce a game
where the cave drip and an ore strike are the same event to the ear and the player stops hearing either.
Both are invisible in a diff.

**And the layer immediately found its own blind spots — twice.** Worth recording, because both look exactly
like a defect in the game:

- *"The water bed clicks."* It reported the pour ambience jumping 0.884 across its loop seam. It does not:
  the pour is a bright filtered-noise band where neighbouring samples routinely differ by most of full
  scale, so an ordinary sample step looked identical to a discontinuity. **A click is an OUTLIER against the
  signal it sits in** — measured as a multiple of the buffer's own mean step, the worst bed in the game is
  2.2×, and nothing ticks.
- *"The cave drip and an ore vein are the same sound."* They are not — one is a pitch sweep falling
  1500→620 Hz, the other a struck 587 Hz bell. Mean brightness cannot tell those apart, because it averages
  the sweep into the bell. Adding a **contour** feature (brightness in the first quarter against the last)
  separated them on the axis that actually distinguishes them to an ear.

Only after fixing the instrument twice did a real confusion survive: the new `catch` sat **0.125** from
`crunch`, near enough that a player would learn one sound for two events. Rope-onto-corner is now built as
the opposite of hook-into-stone — soft against hard, low-passed far harder, and swelling before it decays
because that is what a line does as it slides onto an edge and loads. It measures **1.308** apart, and the
closest pair in the whole fourteen-sound library is now `drip`/`clunk` at 0.206.

Result: 46 layers green.

### Strike 24 — the game teaches what it actually does

Four strikes turned the winch into the movement system, and the game never mentioned any of it. Chaining a
throw instead of landing, the line bending round a corner and whipping you through it, catching a fall you
are already committed to — three techniques the harness *measures* (`check_traverse`, `check_wrap`,
`check_impact`) and the player has no way to learn. That is the worst kind of gap: **the build is strictly
better and the game plays strictly worse**, because depth nobody can reach is the same as depth nobody built.

None of the three can be taught up front, either. "The line bends around corners" is noise to someone who has
never swung one. They are situational lessons, so they are triggered by the situation.

| # | What shipped | Why |
|---|---|---|
| 1 | State-edge hints became a **table** (`Hints._moments`) instead of a const-per-hint ritual | Two bespoke hints was fine; five was copy-paste. The predicate is the only part that differs, and it lives in the controller |
| 2 | Three rope hints — `chain`, `wrapped`, `hard_landing` — fired by `MainView._note_rope_moments()` | Each names a technique the frame it would have paid off: the release at speed, the first bend, the landing that cost your footing |
| 3 | **Reading time, not wall time** (`note_busy` + `MAX_LINGER`) | A hint fired mid-arc at 400 px/s is a hint nobody read. The bubble now arrives on the moment and waits for the landing |
| 4 | The help card (H) carries the three techniques in its own key-first voice | A lesson you can only be told once is a lesson you can miss |
| 5 | `tools/check_teaching.gd` (47th layer) — it fires when true, fires once, names a real key, and can be read in time | The failure no other layer can see: rebind GRAPPLE off F and the game keeps confidently telling a new player to press F forever |

**The key check is the one worth stealing.** Every capital letter standing alone in a hint string is scanned
against the **live `InputMap`** — not against a list someone remembered to update. `A` and `I` are exempted as
English words; everything else (`F`, `W`, `S`, `Q`, `R`, `SPACE`, `RMB`, ...) has to be bound to something. A
remap, a dropped action or a renamed control now breaks the harness instead of quietly making the tutorial lie.

**And the read-time gate is the part that is really a feel fix.** The whole reason these hints fire mid-swing
is that the swing is what they explain. The whole reason that is a problem is that nobody reads at speed. The
countdown running only while the body is under ~190 px/s dissolves the conflict rather than trading one side
off against the other — the bubble is connected to the moment *and* legible after it.

### Strike 25 — you can wind a swing up, and you can hear it

Everybody has been on a swing, and everybody knows you can pump one. Here you could not.
`constrain_position` clamped the body to a circle and `resolve_velocity` killed the outward radial part,
and between them **nothing ever noticed that the radius had changed** — so hauling the line in at the
bottom of an arc, the most basic thing anyone does on a rope, did nothing at all to how fast the arc went.
Every swing was worth exactly the height you fell into it from, and the winch was a lift with a rope on it.
`REEL_SPEED`'s own comment already claimed "the arc's speed comes from conserved tangential momentum". It
was describing physics that had never been written.

| # | What shipped | Why |
|---|---|---|
| 1 | `Grapple.pump()` — angular momentum conserved when the free radius changes | L = m·v·r is the entire skill of a grapple game. Halve the radius, double the tangential speed |
| 2 | Wired into the taut block, straight after `resolve_velocity` | That call has just made the velocity purely tangential, so the scale lands on exactly the right component |
| 3 | The creak reads **real line tension** (`v²/r` + the weight hanging below the hitch), not raw speed | Tension peaks at the bottom of the arc — which is exactly where reeling pays. The sound tells you when to pull, with no UI at all |
| 4 | A `pump` teaching moment, fired at the bottom of a fast arc | Strike 24's machinery, used for the skill it was built for |
| 5 | `tools/check_pump.gd` (48th layer) | Measures the arc, and **listens to the mix** |

**Measured:** an in-phase arm (reel at the bottom, pay out at the top) reaches **0.89 rad** against **0.59**
for a swing nobody touches — half again as wide. Peak spin goes from 0.93 rad/s to 16.4. Reeling *against*
the rhythm reaches 0.64 — barely better than hands off.

**The assertion I had to throw away.** I wrote "out of phase must KILL the arc" before measuring, and it is
simply not true: paying out at the bottom does lose tangential speed, but it also drops the body further,
and the two very nearly cancel. The real asymmetry is all in the other direction, so the check now says
*the rhythm is what pays, not the reeling* — which forbids the thing that actually matters (a rule that
rewards holding a key) without asserting a symmetry the physics never had. Fifth time this pattern has come
up; see the `assertions-written-then-discarded` note.

**And a defect the audio layer could not see.** Strike 23 shipped `_gen_winch`, `_gen_creak`, `_gen_catch`,
the `catch` stream and the whole `set_line` driver — and **nothing ever called `set_line`**. The winch and
the line were silent in the actual game, a wrap made no sound, and `check_voice` went green the whole time
because *it* called `set_line` by hand. An instrument that only ever tests itself is not an instrument.
`check_pump` now plays a real swing and listens to the levels the controller produced, and asserts they
fall back to zero when the line is cut.

### Strike 26 — the miner is a miner again

The user's read: *"the sprite doesn't really fit the vibe anymore."* Measured, it was worse than that.
`assets/sprites/miner.png` carries **877 distinct colours in 1111 opaque pixels** — very nearly a unique
colour per pixel. That is a soft image at pixel-art size, and it loses twice: it fights a world whose
terrain, ore and machines are all code-drawn from a tight palette, and it wrecks the sticker rim, because
`Player._draw` builds that rim by stamping the sprite eight times behind itself and soft alpha edges smear
into a halo instead of cutting an outline. Worse, it was the **only** frame — walk, jump, climb and dig all
fell back to it through `SPRITE_FALLBACKS`, so the body was a decal while the rope did all the moving.

| # | What shipped | Why |
|---|---|---|
| 1 | `tools/bake_miner.gd` — frames authored as ASCII over a named 16-colour palette | At 32x48 the art IS the data. In the repo as text, a limb moves by editing a line and a diff shows what changed |
| 2 | A shared `BASE` + per-frame `LEGS`/`ARMS` overlays + a `GEAR` layer stamped *behind* the body | One base is why fifteen frames look like one character. Behind-the-body is why the pack occludes the pick's haft, the way a strap would |
| 3 | 15 frames incl. five the rope needed and nothing had ever drawn: `swing`, `haul`, `hang`, `climb_0/1` | Five strikes made the line the movement system and the body never changed pose for any of it |
| 4 | Interior value ramp + a **teal** accent (lamp lens, goggles, bandolier, glove cuffs, buckle) | The two legibility gaps blind testers flagged that rendering cannot close: the body read as a flat brown blob, and as warm-on-warm it read as one of the machines |
| 5 | `_sprite_key()` reads the grapple; `_audit()` enforces the invariants | A pose set the game never selects is decoration |

**Measured:** 0 partial-alpha pixels across all 15 frames (so the 8-stamp rim cuts clean), **19** distinct
opaque colours for the whole set, 0 orphan pixels, 715-805 opaque px per frame.

**Not yet live, and it is worth being exact about why.** The new PNGs have no `.import` sidecars, so
`ResourceLoader.exists()` is false, `Art.tex()` returns null, and the game keeps using the old path —
gracefully, which is the fallback working as designed. Generating them needs `godot --import`, which runs
in editor mode, and on this machine that blocks in `CryptoMbedTLS::load_default_certificates` →
`SecTrustCopyAnchorCertificates` on a wedged `securityd`. The `override.cfg` workaround does not reach the
editor path and neither does the same setting in `project.godot` (verified, then reverted). **Hand-forging
`.import` files was deliberately rejected**: they would point at `.ctex` files that do not exist, turning a
clean null into load errors in every harness run. One editor open, or one import on a healthy machine,
activates the whole set.

## STRIKE 27 — the rock stops knowing where the grid is

The sprites went live (the keychain cleared, `--import` ran in 8s, 16 sidecars) and the first close look at
the miner standing in the real world showed two things at once, one of them not about the miner at all.

**The instrument came first, and it is the point of this strike.** `check_texture` already bakes the real
FineTerrain and measures its pixels — but it substitutes a FLAT GREY for the material palette, on purpose,
so its numbers are attributable to the texture passes alone. That makes it structurally blind to a defect in
the *coarse input*, and there was one. `tools/check_grid` (49th layer) bakes with the REAL palette and asks
one question: does a pair of adjacent fine cells step harder when it straddles a coarse boundary than when
it sits inside one? Deep interior cells only, one material only, well below the soil profile — so a step can
only come from the grid. Measured before touching anything:

| axis | seam step | body step | ratio |
|---|---|---|---|
| left–right | 5.691 | 5.334 | 1.07x |
| top–bottom | 13.175 | 5.529 | **2.38x** |

That is `_strata`, the sedimentary bedding. It is a smooth function of `y` whose own source says it must be
"cloudy patches ... NOT a per-cell random that seams at every tile edge (which just rebuilds the grid)" — and
it was evaluated once per 32px cell, which is exactly how you rebuild the grid. Worse, `#S2` multiplies it by
up to **3.2x with depth**, so the game amplified the term that was drawing the mosaic, hardest where the game
is played. A hard horizontal rule across the whole world every 32 pixels.

**The fix changes no cell's centre.** The renderer still hands over one tone per coarse cell; the fine bake
now BILINEARLY reconstructs the field between those samples (`_tone_at_fine`). Mapping fine-cell *centres* to
continuous coarse coordinates puts the samples on an even 1/SUBDIV lattice, so the reconstruction steps by the
same amount everywhere and the boundary stops being special — sampling at `fx / SUBDIV` instead would have left
the grid intact. Cost: four array reads and three lerps per fine cell, no extra Callable, and the per-dig fast
lane is untouched because a tone is a pure function of (x, y) and mining cannot change one.

    left–right  1.07x -> 1.01x        top–bottom  2.38x -> 0.99x

The vertical *body* step went UP, 5.53 to 6.25: the bedding did not get quieter, it got redistributed — the
same tonal energy now varies across the face instead of piling onto cell boundaries. `check_dig_hitch` still
proves a region bake is byte-identical to a full one, which was the risky part of the refactor.

**And the miner stopped wearing a slab.** The sticker outline was two rings — a 2.6px cool halo and a 1.4px
near-black inner edge — built for a sprite with no silhouette of its own to lean on. The authored pixel art
has one: it carries its own one-pixel near-black outline, so the second ring was drawing black on top of
black. At 1.4px in eight directions, on art whose pixels are ONE world px, that is up to two solid pixels of
black wrapped round every limb — the legs printed as black boxes with boots inside them. Deleting it costs
nothing against the sky, where the art's own outline does the same job. What is left is one thin cool rim at
1.5px: separation, not a sticker.

`tools/zoom.gd` is new and small — crop a capture and magnify it NEAREST, so the art can be judged as
authored rather than as a bilinear smear. The vision-testing loop needed it and kept improvising it.

**All 49 layers green**, including the three pixel-judging GL layers that had not been runnable for an entire
session (`check_opening` 0/32 dead, `check_underground` 0/13 dead, `check_water_reads` legible at 44.9 levels).

**What this strike found and did NOT fix.** `_wall_fill_color` is the same bug one function over: the back
wall is a flat fill per 32px cell carrying the same `_strata(c)` quantised to the coarse row. `check_grid`
cannot see it — it samples only cells with all nine fine neighbours solid — and the back wall is what you look
at for the entire game once you have dug in. Fixing it means the fine layer painting air cells, which is a
change with its own z-order and coverage questions. Named here so it does not get lost.

## STRIKE 28 — the back wall becomes a surface

Strike 27 ended by naming what it had not fixed, and this is it. `_wall_fill_color` was the same defect one
function over — but the fuller problem was worse than the tone, and worth stating plainly:

> Everything the fine bake does paints the rock you have **not** dug. The moment you dig, what fills the
> frame is the back wall, and it was `draw_rect(cell, one_colour)` plus two speckles and an occasional
> fissure. One flat fill per 32px cell, carrying the same `_strata` quantised to the coarse row.

So the better the foreground rock got, the more the wall behind it read as cardboard — and a player spends
the whole game looking at it, because it is the inside of every shaft, room and gallery they ever cut. Where
the foreground carries grain, patches, embedded stones, cracks, hue drift, AO and form at 8px, the wall
carried two 5px squares per 32px cell.

**check_grid could not see it.** It samples only cells with all nine fine neighbours solid, and a wall cell
is air by definition — so the one large thing on screen had no instrument on it at all. That is the same
blind spot check_texture had, in a different place, and it is why the layer now sweeps the wall too: a wall
cell counts when it is painted, not solid, its coarse parent not solid (which excludes the eroded back-ROCK
branch, a different paint), and the same true of all eight neighbours.

There was nothing to measure "before": the wall was not in the fine texture at all. It is now.

| | seam | body | ratio |
|---|---|---|---|
| across the wall | 3.454 | 3.221 | 1.07x |
| down the wall | 4.362 | 4.180 | 1.04x |

**The cast shadow had to move with it.** The coarse pass carried the wall's entire sense of depth in AO
strips ruled along the cell edges — "the recess is carried by the cast shadows above" — and the fine layer
covers those. Replacing them was not optional: covering them silently would have flattened the wall at the
exact moment its tone got better. `_wall_shade` re-throws the cast from the fine grid with the coarse pass's
own weights (rock overhead deepest, sides less, a floor below least — light reaches a floor), fading over
five fine cells, so an opening's shadow is a gradient instead of the ruled border a per-cell strip drew.

The wall's grain is deliberately **quieter** than the foreground's (0.055 against 0.10). Matching it would
collapse the depth cue the recess exists to create: two surfaces at the same visual roughness read as one
surface.

Structurally, `apply_wall_tone` joins `apply_tone` on FineTerrain as the single authority for what a wall
colour is, so the coarse pass and the fine pass cannot drift apart — the same split #S12 made, applied to
the wall: a base without bedding, plus a bedding value reconstructed between coarse samples.

All 49 layers green, `check_dig_hitch` included — a region bake is still byte-identical to a full one, which
is the property most at risk from a change this deep in the paint (`WALL_AO_REACH` of 5 sits inside the
existing `REGION_MARGIN` of 6, which is why).

## STRIKE 29 — mining stopped stalling the game

Asked whether the game runs smoothly, the honest answer was that nobody knew: forty-nine layers judged what
the game DOES and not one judged how fast. So `tools/check_frametime` (50th layer) came first — four phases,
wall-clock ticks around `frame_post_draw`, percentiles rather than means. It found this immediately:

| phase | mean | p95 | p99 |
|---|---|---|---|
| IDLE / RUN / SWING | 8.3ms | ~9ms | ~10ms | (a clean 120fps)
| **DIG** | **35.8ms** | **104.6ms** | **114.0ms** |

**Mining stalled the game for over 100ms per dig.** At roughly one dig a second while hand-mining, that is a
visible stutter about once a second, in the verb the game is named after.

**It was not the new work.** A worktree at HEAD~2 measured p99 114.09ms against the current 114.02ms —
identical, so #S12 and #S13 were not involved. The fine-terrain region bake never even crossed a 2ms print
threshold. Then, by elimination:

- disable the terrain viewport re-bake → p99 114 → **40ms**
- disable the chunk repaints instead → p99 114 → **108ms**

So ~100ms of a 114ms hitch was **one thing**: the coarse-terrain `SubViewport` re-rendering. It is the whole
world, 4096x4096, with every chunk painter inside it — which means nothing is ever culled, and a one-cell dig
replayed every chunk over sixteen megapixels.

**Fix 1 — the bake became incremental (#S14).** The render target is now RETAINED (`CLEAR_MODE_NEVER`) and a
dig makes only the dirty chunks visible, so only their buffers replay. `scenes/erase.gdshader` blanks those
chunks' rects first with `blend_disabled`, because alpha blending can add coverage but never remove it — a
cell dug open to the sky would otherwise keep its rock forever. Full bakes (initial paint, loading a save)
still clear and draw everything.

**A hypothesis that was wrong, recorded because it was expensive.** Before the retained-target fix I tried
deleting the viewport entirely and drawing chunks straight into the main tree, on the theory that Godot would
cull the off-screen ones. It measured **349ms mean, 1018ms worst** — an order of magnitude worse. The bake is
load-bearing; the old comment about "~11,882 draws" was not being pessimistic.

**Fix 2 — the veil became regional.** The skylight lightmap rebuilt all 16,384 cells on every dig, 13ms a
time. A dig changes light only near itself and only down its own columns, so it now rebuilds a column band:
the dug columns, widened by the openness blur's reach. This needed one structural change — the vertical blur
wrote its result back over the raw solidity it was built from, which is harmless when every column is rebuilt
every time and fatal once a bake covers a band, so raw solidity now lives in its own persistent buffer.

| DIG | before | after |
|---|---|---|
| mean | 35.8ms | **13.9ms** |
| p95 | 104.6ms | **33.8ms** |
| p99 | 114.0ms | **42.3ms** |

**The bar is relative, and that took a round to get right.** An absolute millisecond budget is unmeasurable
here: vsync does not reliably disengage on macOS, so every fast frame reports exactly the refresh interval
and a game with 4ms of headroom scores the same as one with 0.1ms. Worse, a background reindex can put whole
SECONDS into a frame the game had no part in — during this work Spotlight was at 250% CPU with a load average
above 20, and the same build measured 1014ms frames while IDLE. A layer that fails when Spotlight is busy is
a layer people learn to ignore. Both effects move the quiet frames and the busy frames together, so the layer
gates the RATIO: a dig may cost a few times a quiet frame, never twenty. It was 13.6x. It is now 4.3x, and
the bar is 6x.

**What is still there.** The residual is the retained 4096x4096 target itself: on a tile-based GPU,
`CLEAR_MODE_NEVER` means loading and storing the whole attachment every render however little is drawn. The
fix is to split the bake into a grid of smaller targets so a dig loads a megapixel instead of sixteen. That is
a real refactor and it is the next thing worth doing if mining still reads as anything but instant.

All 50 layers green.

## STRIKE 30 — the coarse pass stops drawing what nobody can see

The previous strike left one thing on the table and named it wrong. It said the residual dig cost was the
retained 4096x4096 target, and that splitting the bake into a grid of smaller render targets was the next fix.

**That prediction was tested and it was false.** The tiled bake was built — sixteen-cell tiles, one
`SubViewport` each, chunks offset into their tile, the bake quad drawing N textures — and measured at
**neutral**: DIG p95 33.4 / 36.9 / 36.6ms across three runs against the retained version's 33.8. (A single
early run reported 7.78ms and that number was wrong; its p50 sat BELOW the idle quiet frame, which is
physically impossible, and it did not reproduce. Vsync had disengaged for one run.) The tiling also moved
~1450 pixels of a boot frame for no benefit, so it was reverted rather than kept on a simplicity argument.

**The real cost was measured rather than predicted.** Instrumenting the dig path per stage gave
`veil_region 0.6ms`, `queue_chunks 0.0ms`, and `chunk_paint 3.0–27.8ms` — the entire remaining hitch was
`_paint_terrain_chunk`, at roughly 220 microseconds per cell.

**And almost none of what it drew could be seen.** Since #S13 the fine layer paints every solid cell
opaquely, every eroded one as back-rock, and every walled air cell as the back wall — which underground is
the whole frame. The coarse pass was drawing speckles, fissures, chamfers, fillets and wall faces
underneath an opaque texture, sixty-four cells at a time. Disabling it entirely and capturing confirmed the
shape of the claim in both directions: underground the frame was unchanged, and at the surface the grass cap
vanished. The cap is the exception, because the mold deliberately leaves the top `SURFACE_KEEP` fine rows of
each column's surface cell transparent so the cap can own the walked line.

So the pass survives, confined to what survives it: the cell pass and the background pass both restricted to
one row either side of the walked line, and the fillets to open cells with no wall behind them — a hillside,
the sky side of an arch, the one place an open cell is not covered.

> ## ⚠ WITHDRAWN 2026-08-17 — BOTH COLUMNS PREDATE THE WORK-PROOF. DO NOT USE AS A BASELINE.
>
> Every figure in the table below was taken before `check_frametime` asserted that the mining it was timing
> **actually excavated anything.** Without that proof the gauge measures cost per frame while the subject is
> free to do less work, so **a low number is what a BROKEN dig produces.** Measured directly: **13.06 ms p95
> when mining excavated nothing, against 32.81 ms with the work-proof forcing the job.** Breaking mining
> outright would have registered here as a 60% win.
>
> So the 33.8 → 19.8 improvement is **UNKNOWN, not disproven** — both endpoints are unusable, and whether
> the change helped is now an open question rather than a settled one. It may well have.
>
> **The honest current number, measured twice by two sessions with the work-proof active:** DIG p95
> **32.81 ms** at 46 mines, and **32.30 / 33.76 / 35.06 ms** at 40 mines — against an 8.33 ms budget, with
> ~66–72% of frames over it. That is the baseline for the optimisation sprint. The second session found
> the table below first and was one step from filing "regressed to pre-#S30" against it, which is why this
> banner is here and not only in the commit that fixed the gauge.
>
> See `docs/PEER_SESSIONS.md` §12 shape **28** — *a guard whose green gets better as the subject gets more
> broken.*

| | before | after |
|---|---|---|
| DIG mean | 13.9ms | **10.4ms** |
| DIG p95 | 33.8ms | **19.8ms** |
| DIG p99 | 42.3ms | **21.7ms** |
| DIG worst | 49.1ms | **23.5ms** |

Against where this started — 104.6ms p95, a visible stall once a second — mining now costs 2.4x a quiet
frame. RUN and SWING hold 1.0x. *(Also withdrawn — same reason as the banner above.)*

**Verifying "it changed nothing" needed an instrument of its own.** A naive image diff of two captures was
useless: two runs of *identical* code differ in 37.8% of pixels, because the miner's animation phase and the
dust motes land differently. Thresholding above that noise gave a usable signal (identical code: 2 pixels
over 0.20; a real change: thousands), and a diff MAP — reference dimmed to grey, changed pixels in magenta —
made attribution immediate. It showed the first attempt at this change moving a full-width line at the grass
boundary, and it showed the final one moving nothing but the miner, the dust ring, the sparks and two
drifting motes. Boot settles at 46 changed pixels against a 2–75 pixel noise floor; delve's 4276 are all
sprite, zero terrain; room's 68 are the miner.

Two hypotheses died on the way and are worth recording: the seam was blamed on the loop order (row-major to
column-major), which measurement put at 75 pixels; and on the background pass at the surface band, which the
fix barely moved. Both were wrong, and the ~1450 pixels actually belonged to the tiling that was then
reverted. The bisect that settled it ran each edit alone behind a temporary env switch.

All 50 layers green.

## STRIKE 31 — the rock gets a grain

Mining has had exactly one verb since the beginning: point at a cell, hold, the cell goes away. Every block
costs the same attention as every other, so a thousand blocks cost a thousand times the attention — which is
the whole reason hand-mining reads as a chore rather than a craft. `docs/BITS.md` §4 is the answer and this
is its first half.

**Every rock cell now has a seam** — a bedding plane, a joint, a diagonal, or nothing — and a blow that
follows one calves the contiguous run of same-seam rock with it, up to three cells. Reading the rock pays.

**Cutting across the grain costs nothing extra.** Stated twice in the spec on purpose and enforced from both
ends by `check_seam`: along the grain must take MORE than one cell, across it must take EXACTLY one. A player
who never notices seams plays the game we already shipped; a player who does gets paid for looking. Any
version where the wrong swing is slower is the treadmill coming back in through the window.

**Planes, not a sprinkle** — the one place the implementation departs from the spec, and it is load-bearing.
Rolling a direction per cell at 35% density gives a contiguous run of three about once in six hundred cells,
so the mechanic would have fired essentially never and been invisible besides. Real rock does not work that
way either: bedding planes are horizontal and run for miles, joints are vertical and roughly parallel, and
both are properties of a PLANE rather than of a stone. So a horizontal seam is a ROW of the world, a vertical
seam a COLUMN, a diagonal one anti-diagonal. Runs come for free and the field reads as strata, which the
terrain already draws. Storage cost is still zero — a pure function of coordinate and seed, saved nowhere.

**Drawn, because a mechanic you cannot see before you act is a slot machine.** The grain is a per-frame
overlay clipped to solid rock by construction (drawn per cell, so a plane crossing a chamber stops at the
chamber and resumes on the far side, exactly as a real one does). A parting is a shadow with a lit lip, never
a drawn line — the first version was ruled at constant strength and read as ink lying on top of the rock, so
each cell's stretch now gets its own span and a one-pixel wobble, and one stretch in five is welded shut.
That single change is what took it from CAD overlay to geology.

Three gates keep the run honest, each for its own reason: it is **contiguous** (a blow can never reach across
an open chamber), it re-checks the **drive** per cell (a seam must never smuggle you past a depth gate), and
it does **not** re-check reach — reach gates the blow, and the calve is a consequence of the blow rather than
a second one.

*(⚠ WITHDRAWN — both figures in this sentence predate `check_frametime`'s work-proof; see the banner at the
DIG table above. "Costs nothing" was concluded from a gauge that scored less work as better.)*

Costs nothing: DIG p95 19.0ms against 19.8 before, RUN and SWING flat at 1.0x a quiet frame — and that is
with a dig now breaking up to three cells instead of one.

All 51 layers green (`check_seam` is the new one).

## STRIKE 32 — picks stop being the same pick, faster

The pick ladder was doing two jobs and doing the second one badly. `MiningRules.TOOLS` gates which rock you
may bite at all by tier — a wood pick *cannot* touch deepslate, it does not grind slowly through it — and it
also multiplied break speed 1.0 → 1.7 → 2.6. So every upgrade was mostly the old pick with a bigger number,
and the source said so out loud: *"its value today is SPEED (deepslate 1.65s → 1.08s)."* That is the
treadmill. `docs/BITS.md` §2 deletes it, and this is that change.

**The drive is a key. The bit is the verb.** The tier decides what you may bite at all — monotonic, one
track, never lost. The BIT decides what one swing takes — bought, horizontal, and a new layer never takes one
away from you. Five of them, each a different job rather than the same job faster:

| | takes | and the cost that makes it a choice |
|---|---|---|
| **Point** | one cell, any direction | none — the baseline, and it never stops being correct |
| **Broad** | 2x2 | **pulverises: nothing it breaks reaches your pack** |
| **Lance** | five cells driven the way you face | 0.85s of recovery; a commitment, not a rhythm |
| **Sinker** | three straight down | down only — but it sinks the clean 1-wide shaft a gravity chain wants |
| **Wedge** | splits eight cells along a seam | does *nothing at all* across the grain |

**The Broad's price is what makes the set a set.** You hollow a chamber with it and swap to the Point at the
first vein, because Broad would grind the ore to nothing. That swap is the mechanic. Without that cost the
Broad is a free 4x upgrade and every other bit is pointless, which is why `check_bits` asserts the pulverise
from three directions — the cells break, the pack does not move, and the produced ledger does not move
either (a pulverised block was never produced, so conservation stays total).

**Equipping is stateless.** The bit you dig with is simply the one in your selected hotbar slot; select
anything else and you are on the Point. No equip screen, no new key, no saved field to migrate, and no way
to be confused about what you are holding. There is no Point *item* at all — it is what "not a bit" means.

**The Wedge's refusal had to move.** A bit that does nothing across the grain cannot refuse inside `try_mine`:
the hold-loop charges on `_mineable`, so a cell that reads as mineable and then will not break spiders a full
charge and starts over forever — the exact bug `check_mining`'s last case exists to make impossible. The gate
lives in the predicate instead, so the aim cursor greys out on rock the Wedge cannot split, before you press
anything. That is also the honest way to sell a specialist tool.

**A stale assertion was inverted, on purpose.** `test_sim` demanded that a better pick chew the same rock
faster — the treadmill written down as a requirement. It now demands the opposite, with the reason recorded
beside it. That is the whole point of the strike, and it is the one place where a red harness was the correct
outcome rather than a regression.

Costs nothing: DIG p95 19.6ms, RUN and SWING flat at 1.0x a quiet frame.

All 52 layers green (`check_bits` is the new one).

## STRIKE 33 — one counter, three tabs

> _[Section removed 2026-08-25, pivot: the Bazaar pack/craft screen is dead design. See git history for the
> original text.]_

## STRIKE 34 — the counter stops looking like a dialog box

> _[Section removed 2026-08-25, pivot: the Bazaar counter's visual redesign is dead design. See git history
> for the original text.]_

## STRIKE 35 — the gallery that sorts itself

> _[Section removed 2026-08-25, pivot: the Drift Rig is a dead machine. See git history for the original
> text.]_

## STRIKE 36 — the wall that weeps

> _[Section removed 2026-08-25, pivot: this strike's packing/fill mechanic is sourced from the Crusher and
> Drift Rig's spoil stream, both dead design. See git history for the original text.]_

## STRIKE 37 — the rock that says no

`docs/BITS.md` §2 deleted the speed axis: a drive is a **key**, not a stat, and rock above your tier does
not come slowly, it does not come at all. §5 is the other half of that bargain and it was missing. Until
this strike, holding the button on deepslate with a wood pick produced *nothing whatsoever* — no sound, no
spark, no words, no crack. That is indistinguishable from a game that dropped your click, and it is the
single worst thing a hard gate can feel like. A binary gate is only honest if you can see it coming.

**It says so before the press.** The aim cursor now reads the gate itself: `_drive_bites` is false on rock
your drive cannot open, and the marker goes cold red and crossed. The predicate the cursor draws and the
predicate the mining loop branches on are the same function, so the marker and the gate can never disagree
— `check_refusal` asserts them against each other rather than each against a hard-coded answer.

**It skids.** A held press on refused rock fires on its own 0.30s cadence: sparks in the tool's own colour,
a 0.45 shake, and a real synthesised **skid** — a 0.30s band-passed scrape sliding down in pitch with a thin
1240→880 Hz ring, built to sound nothing like the 0.09s crunch of rock giving. You are not being ignored;
you are swinging and not biting, and your hands know the difference before you read anything.

**One tell says it, and only one.** The first cut had the skid flash "DEEPSLATE needs the Stone Pickaxe" —
and then the hover inspector, which is on screen the whole time your cursor is on that rock, said the same
thing again in different words. Two panels saying one sentence is noise, and noise is what players learn to
tune out. So the words were split by ownership: the **inspector** owns the tier refusal and now derives it
from the gate's own table (`MiningRules.drive_for()` → "too hard — the Stone Pickaxe (tier 2) bites it" —
the lowest drive that actually opens this rock, with the rung, not "you need a better pick"), and the
**skid's** one line is reserved for the refusal nothing else explains: the Wedge splitting along the grain
when your swing is across it. That one fires once, then stays quiet for six seconds.

**And it shuts up where the pick works.** The last case in `check_refusal` holds LMB through the real mining
loop on ordinary stone and asserts no skid, no flash, ever. A tell that fires on rock you can break is worse
than no tell at all.

Held by `tools/check_refusal.gd` (harness layer 55, 17 assertions), photographed at
`history/117-the-rock-that-says-no.png`.

## STRIKE 38 — the vein outlives the blow

The user asked a question that turned out to be a hole in the floor: *"it's odd that you can mine an ore and
it disappears, but you can drill an ore and it might have 400 deposit."* It is odd. Chasing it down found
that one cell was **both terrain and resource**, and the two verbs acting on it disagreed by two orders of
magnitude — a drill took 250 units out of an ore cell, a pick took a 3-6 burst and then erased the rest.

**Swinging your pick at ore was the single most destructive act in the game, and nothing said so.** No tell,
no refusal, no number on screen — the deposit had never once been visible. A player clearing a room to build
in it could annihilate a four-hundred-unit vein in six swings and never learn that they had.

And it was fighting the kit. `docs/BITS.md` shipped a bit set whose whole premise is that you clear rock
freely, by shape; clearing rock freely was punished in exactly the places worth clearing. #S37 had just spent
a strike making rock honest about what it refuses, while ore stayed silently punishing.

**The blow now OPENS the vein instead of ending it.** What the burst does not take stays in the cell as a
**lode** — ore in the background plane, exposed, still there, still worth what it was worth. Hold on it and
you work it: a short repeating cycle that yields a unit and clears nothing, which is a different verb from
mining and feels like one. The hand rate is deliberately poor; it is how you get your first ore, never how
you supply a factory.

**And the deposit is finally on screen.** The fleck field thins as the vein drains, off a deterministic set,
taking a prefix — so flecks vanish one by one rather than reshuffling and a half-worked vein looks like the
same vein, half worked. This was not a hypothetical gap: it broke the Drift Rig's own capture, where the rig
chewed one 250-unit cell forever and the photograph had to seed thin seams by hand to show a cycle.

**Three cuts to learn how to draw it.** A filled rect with a hairline rim read as a poster stuck on the rock
— the exact grid tell `check_grid` exists to keep out. Soft overlapping blobs read as smoke. What worked was
architectural rather than cosmetic: route the lode through `_wall_base_color`, the single authority the
fine-terrain bake already uses, so it inherits the molding, bedding, recess shadow and veil every other wall
gets. Then one more correction — an ore block's matrix is within a hair of stone's, so painting the wall the
ore's own colour is exactly correct and completely invisible. The wall is now the rock carried 42% of the way
toward the metal, which derives per material: coal stains it dark, iron rusty, ore pale.

This is phase 1 of four (`docs/LODE_PLAN.md`). Ore is still authored solid by the generator — the cutover,
the tutorial rewrite and the Drill Head are phases 2 and 3, behind a pushed `pre-lode` tag.

Held by `tools/check_lode.gd` (harness layer 56, 39 assertions), photographed at
`history/118-the-vein-outlives-the-blow.png`.

## Open decisions for you
1. **The crisp-vs-molded terrain art fork.** Still the single biggest remaining gap, and now much better
   isolated: with the lamp, bedding, depth-contrast and fissure passes in, what residual softness remains
   underground is the 8px mold itself — the deliberate aesthetic — not a lighting bug. That makes this a
   clean either/or rather than a guess.
2. **Avatar redraw (A4).** The zoom and rim buy real presence now; a larger, higher-contrast sprite with a
   signature accent colour nothing else wears is the finisher — yours to draw when ready.
3. **B5 (agency first).** Largely served by B1+B2+B4 — digging anywhere now pays instantly and visibly.
   Going further means delaying the objective chain itself, which is a design call, not a tuning one.
