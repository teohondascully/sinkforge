# Working state

**Last updated: 2026-09-10 (Astra's audit answered in full -- D0575 withdrawn, D0576-D0579 fix what it reproduced; D0577 found D0569's floor had made the veil a CONSTANT underground; D0583-D0586 relit the frame after three hours with the director's screen. Ten queue items turned out already built.)**

## Overnight queue

**Authored 2026-09-10 by the director, merging the original 30-item overnight queue with the 48-item
frame-gap triage taken from `docs/media/reference/2026-09-10-lighting-reference.jpg`.** `/loop` drives
this to exhaustion. `docs/NORTH_STAR.md` is the standard every item here is judged against.

**THE DIRECTOR'S INSTRUCTIONS, VERBATIM, because they are the whole shape of the run:**
- *"Your goal is to complete all items in the queue overnight without stopping, and if you ever reach a
  blocker, move to the next item and document."*
- *"At the end of the queue, you must cycle back and forth with side by side comparisons of the
  reference image lighting and our game until they match perfectly."*
- *"I'm more concerned about just the entire Tiny Glade / Noita north star for design feel and
  uniqueness. This game doesn't pass as 2026, it passes as 2016."*

**THE ORDERING RULE, and it is not cost.** A z-axis engine overhaul is a live fork (see NEEDS_DIRECTOR).
Every item below is either z-DURABLE (per-cell appearance, screen-space effects, sim rules, content --
you would apply the same work to each plane) or z-FRAGILE (the bake window/chunk structure, the
single-plane observation array, the minimap, the save format). **This queue is ordered so that a night's
work survives that decision either way.** Nothing z-fragile is in it.

**AND THE SEQUENCING FINDING THAT PUT PHASE 2 WHERE IT IS:** the z spike must NOT run before the
lighting lands. Both planes are the same brown noise today, so a layer switch would be visually
illegible and would feel bad for reasons that have nothing to do with z -- a false negative on a
six-week decision.

**If an item's output is a new sentence on screen, it is the wrong item.** (`NORTH_STAR.md` §4.)

### Phase 0 -- SEE IT FIRST-HAND (done 2026-09-10)

- [x] 1  Opus playthrough, rung 0, judging feel. Seven HUD rectangles; the dig leaves no readable mark.
- [x] 2  Opus playthrough from the BUILD door. Rungs 4 and 5 work under a competent driver: 4 commands.
- [x] 3  Opus playthrough of rungs 6-9, never played by anyone. **Rung 6 works and is invisible; rung 7
         is effectively unreachable; 8 and 9 are blocked behind it, not behind their own content.**
- [x] 4  `docs/NORTH_STAR.md` -- the missing document. Written.
- [x] 5  Loose material falls, with an angle of repose (D0562, `sim/mining/slump.gd`, 27 asserted,
         all four guards mutation-witnessed).

### Phase 1 -- THE WORLD BEHAVES (finish what item 5 started)

- [x] 6  Dust and settle (D0564). A vacated cell puffs; the step knocks the camera in proportion to how
         much moved. Capture: `docs/media/moments/2026-09-10-slump-dust.png`. PARKED: it rides
         `Interface.services()` rather than the door, because `observation.gd` is at its file cap (P034).
- [x] 7  Undermining drops a mass (D0566). Verified in a seat (the capture above is a mound's flank mid-
         collapse) and pinned headless. Found and fixed a session-ender on the way: a full burial ejected
         the body to the far corner of the world, so earth now packs around a player. `test_slump_body.gd`.
- [x] 8  **THE TRAP -- fixed (D0567).** `BodySwing` refused the line's constrained position outright
         whenever it would clip rock, which in a shaft is every tick, so the reel did nothing forever.
         It now slides along the face, which is legacy's own behaviour. One hook: 0 px -> 82 px. Chained
         hooks: row 55 -> row 26 of a 10 m shaft. The last 1.5 m over the lip is geometric
         (`Grapple.MIN_LENGTH`) and is parked as P035 with three candidate answers.
- [x] 9  Descent as a verb (D0568). The spare rule now applies only to blows that are not aimed at or
         below the boots. Measured on the naive input a player actually gives -- point below yourself and
         hold: **0 rows in 8 bursts before, 24 rows in 12 bursts after.** `tests/test_way_down.gd`.

### Phase 1b -- THE AUDIT'S CORRECTIONS (Astra, 2026-09-10; runs BEFORE phase 2)

**Why this phase exists and why it is first.** Astra audited `c52d6baf` plus staged D0575 and
reproduced two slump bugs my passing tests miss, one lighting-model error that inverts the conclusion
phase 2 was built on, and one arithmetic error in my own reported range. **D0575 is WITHDRAWN from the
tree** (diff preserved at `scratchpad/withdrawn/D0575-material-bands.patch`): it raised albedo to
compensate for damage A8 caused, and it failed a real gate -- `test_material_palette.gd`, coal 0.0933
against a 0.1426 floor, reproduced here. Astra's qualification is the load-bearing half: that floor is
DERIVED from inter-rock separation, so widening the palette moved its own bar. Coal did not get darker.

**Every item below was reproduced by a second party, not proposed.** They are correctness debt, and
phase 2 cannot be measured honestly while A8 stands.

- [x] A1 **DONE (D0576).** Slump moves a grain twice in one tick. `_next` defers cells woken BY a move; it does not
       protect a destination that was ALREADY in the queue. Overlapping wake neighbourhoods put a
       grain through (10,26) to (10,27) in one `settle()`. Fix, regression test, mutation-witness.
- [x] A2 **DONE (D0576).** Slump forgets a grain whose blocker leaves. A cell blocked by the body rect (or by water)
       returns `target() == c`, hits the bare `continue`, and is dropped from the queue forever;
       nothing wakes it when the body walks away. Distinguish rest from transient refusal.
- [x] A3 **DONE (D0576), with a stated residual bound.** Overflow must defer, not forget. `QUEUE_CAP` silently drops work. The comparison I drew to
       `TileGrid.SOLIDITY_LOG_CAP` is misleading -- the grid falls back to an all-changed signal, which
       is a defer. Slump has no such fallback.
- [x] A4 **DONE (D0576).** Four movements is not four checks. A tick may inspect 4096 candidates, and `pop_front()`
       shifts the array on every one. Budget examined work separately from moved work; queue cursor or
       ring buffer. `sim/fluid/MODULE.md` makes the active set a hard constraint and I never profiled it.
- [x] A5 **DONE (D0579).** Machine occupancy is absent from `Slump._open()`. It checks terrain, water and the player
       rect -- not machine bases. Define and test what falling earth does to machinery.
- [x] A6 **DONE (D0576), reproduced both ways.** One slump test is still vacuous. The supported-cell test wakes row 28 while its subject sits
       on row 29, so its unchanged result does not establish the subject was evaluated. This is
       `[[instrument-cannot-register-subject]]` for the SECOND time in this one file.
- [x] A7 **DONE (D0579) -- the queue travels WITH the save.** Deriving it on load was tried and measured wrong: the generated world holds 1061 unsupported loose cells, so a rebuild-on-load collapsed a tenth of the world's loose earth on every load. `test_boot_snapshot.gd` caught it. See P041. Not a
       cosmetic frame. Ruling or fix; `TreeFall` shares the property and that does not excuse it.
- [x] A8 **DONE (D0577) -- and it was erasing more than shape.** See item 10. Preserve shape
       modulation and lift AMBIENT instead of clamping combined output; compare against the current
       clamp with materials and lights held fixed. **Do not brighten materials to compensate before
       this is isolated** -- that is precisely the mistake D0575 was.
       **RESULT:** not just mass/key -- buried rock, mid rock, a lit cut face, cave air and true void
       all returned one identical value, rgb (0.5500, 0.5610, 0.6382). The clamp cannot be rescued by a
       smaller floor: the underground's brightest possible output is 0.442, so any floor that lifts the
       deep to the reference's brightness sits above the entire range. Replaced with a depth-ramped
       ambient LIFT (`lit = mix(s, 0.48 + 0.69*s, d/AMBIENT_DARK)`), which restores two-thirds of the
       lost contrast at the brightness D0569 wanted and leaves the surface bit-identical.
- [x] A9 **DONE (D0578), and it was reachable, not only a proof gap.** Grapple `_slide` checks destinations, not swept paths. "Every candidate is a subset of the
       requested move" is not a collision-safety proof; a direct helper probe accepted a move across an
       intervening solid floor because the endpoint was clear. The pre-existing full-projection path
       shares the weakness. Four witnesses before this is called closed: (1) the maximum correction
       reachable through normal reeling and pivot changes, (2) thin barriers along that correction path,
       (3) repeated blocked reeling then release -- the rope shortens even when the move is refused,
       (4) velocity and landing bookkeeping against the ACCEPTED displacement, not the requested one.
- [x] A10 **DONE (D0578).** `tools/run_suites.sh` ETA divides by parallelism twice. Elapsed wall time per completed
       suite already carries concurrent throughput; dividing again by `SWEEP_JOBS` understates every
       estimate. "Approximate" does not excuse the arithmetic. (My own tool, D0573.)
- [x] A11 **DONE (D0579).** Hand mining and drilling give inconsistent terrain response. Only a hand blow seeds the
       slump queue. In an automation game the drill is the normal case. Shared event distribution, not
       a permanent exclusion -- and NOT a second destructive read of `take_solidity_changes()`.
- [x] A12 **DONE -- asked as P038 in `docs/NEEDS_DIRECTOR.md`, with a recommendation.** Confirm T012's supersession. `LAMP_TINT` 0.62 replaced a
       ruled 0.38. It may be right under the newer reference brief, but a session must not infer that a
       numerical ruling evaporated. T017 was reverted, so no landed override remains there.

### Phase 2 -- LIGHT (~55% of the gap to the reference)

**FIVE OF THIS PHASE'S SEVEN ITEMS TURNED OUT TO BE ALREADY BUILT** (10, 11, 13, 15, 16), and 23 in
phase 4 with them. That is the phase's real finding and it is worth stating plainly: the frame did not
read as 2026 because effects were missing, it read that way because **D0569's floor was erasing the
underground's entire value structure** -- rock, cave and void all returning one identical colour. The
effects were drawing correctly onto a flat field. D0577 is the fix; item 14 is the only unbuilt item
left here.

- [~] 10 **Edge occlusion -- ALREADY PRESENT (D0569), but the fix I shipped beside it is WRONG.** The
         AO and rim light are implemented and correct (`rock_tone.gd:229-246`, legacy's own 0.125 per
         open neighbour); `rock_tone.gd`'s header calling them "deliberately not here" is stale. Probed
         directly: luma 0.26 (interior) to 0.06 (fully carved), a 4.1x range.
         **THE ERROR: `DEEP_FLOOR = 0.55` clamps the COMBINED output, and underground the combined
         output can never reach it.** `sky = 1 - 0.66 = 0.34`; `shade = mass * (1 + 0.30*key)` with
         `mass <= 1.0`, so `shade <= 1.30` and `s = shade*sky <= 0.442 < 0.55`. Every solid cell below
         the scatter band therefore clamps to exactly 0.55 and the mass/key term is not attenuated, it
         is **erased**. My ledger line saying the floor "does not flatten depth" is false. Astra found
         it; the arithmetic is three constants and I did not do it. Reopened as **A8**.
- [~] 11 Machines and lamps emit light (D0570, D0571). They DO emit; a machine's pool was 2.8 m and lit
         its own casing. Widened to 5 m, warmed the lamp. **P036 IS WITHDRAWN: the premise was false.**
         I wrote that "our lights multiply, so a lit cell can never exceed the material's base colour".
         The VEIL multiplies -- but `view/view_stack.gd:_mount_light` mounts `LightPainter` and
         `OrePainter` on an ADD-blended canvas above it, which D0373 documents as legacy's own third
         blend. An additive pass already exists and already draws lamp bloom, machine pools, godrays and
         water sheen. Raising albedo was never the only door. The real question is which term is
         deficient -- material, ambient, direct, surface response or glow -- and A8 answers it first.
- [x] 12 Lamp warmth (D0571). `LAMP_TINT` 0.38 -> 0.62, measured against the reference's amber (0.553,
         0.340, 0.226) where ours read nearly neutral. The distance colour shift is folded into P036.
- [x] 13 **ALREADY PRESENT.** `VeilLight.sky_light` does exactly this and `tests/test_flat_planes.gd`
         pins it: the same depth reads 0.56 down an open shaft against 0.42 under rock.
- [x] 14 **THE PLANE SEPARATION IS PRESENT AND MEASURES REAL; THE DEPTH RAMP IS DECLINED, WITH CAUSE
         (D0580).** The audit's framing was "separate distant/background space from playable surfaces;
         do not wash everything equally or conceal ore" -- and `WallPainter` already does exactly that:
         `RECESS 0.32` and a `COOL_MIX 0.30` drift toward `(0.16, 0.19, 0.30)`, its own header calling
         it "the same rock a plane back, flatter and cooler". Measured across three materials at 2, 20,
         60 and 120 m: the wall runs at **0.54-0.77 of the front plane's luma** and is consistently
         cooler (clay front -0.167 on the blue-minus-red axis against the wall's -0.045; hardrock
         -0.017 against +0.033). Not a wash, and ore is on the front plane so nothing conceals it.
         **The depth ramp is the part that is declined, and the reason is written in that file already:**
         "the wall was darkened once in its own paint and again by the shadow veil, so the veil
         compounded a value that had already been crushed, and a lit chamber came out as a black
         rectangle." Legacy measured that regression. D0577 has just restored the veil's depth response
         after D0569 erased it, so a second depth term on the wall would recreate the exact fault the
         file warns about, at the exact moment the first term started working again.
         **What is genuinely unbuilt** is ambient particulate in lit air OUTSIDE a lift shaft --
         `AmbiencePainter.updraft_motes` covers lift shafts, `FallingItems.motes` covers drops, and
         neither is general. That is a feel item, so it is BUILT-PARKED for the announced capture batch
         rather than judged here.
- [x] 15 **ALREADY PRESENT AND ALREADY PINNED.** `LightPainter._paint_godrays` draws two tapered
         polygon passes per qualifying column plus a shimmer and a floor pool where the ray lands,
         called unconditionally from `paint_frame`, no gating flag. `tests/test_light_painter.gd:87`
         `_test_the_godray()` pins seven properties of it. **THE LIMIT, which is the useful part:**
         `godray()` takes three terrain ROWS -- the column's own surface and its two neighbours -- so it
         can only ever express a VERTICAL drop. Angled light and a ray occluded from the side are
         outside what the rule can say, exactly as the audit predicted. Anything angled is a different
         pass and a different item.
- [x] 16 **ALREADY PRESENT AND ALREADY PINNED.** `LAMP_BLOOM` 0.17 with `lamp_flick`, `FURNACE_EMBER`
         and `BURNER_GLOW` on the machine pools, all on the ADD canvas.
         `_test_the_lamp_bloom_scales_with_depth` and `_test_machine_pools_by_kind_and_status` cover
         them. Per the audit: improve source coherence and restraint before adding a pass, and bloom
         accents illumination rather than substituting for it -- which is what D0577 was for.

### Phase 3 -- ROCK (~25% of the gap)

- [x] 17 **PREMISE MEASURED FALSE.** There is no 4 px static. `BeddingTone._cell_jitter` divides by
         `CELLS_PER_METRE` before sampling, so its features are 17-48 METRES; `_strata`'s periods are
         18/7/4 m. Measured on a run of rock, the mean absolute luma step GROWS with scale (pixel 0.0118,
         cell 0.0174, metre 0.0238), which is the signature of structure, not noise. Handed back to Astra
         in `docs/audits/2026-09-10-overnight-queue-audit-request.md` §2.4 with a request for the frame
         where the static reads.
- [x] 18 **DISSOLVED BY A POPULATION FIX, same audit §2.4.** "Our rock is 3x flatter than the reference"
         compared our DEEP massive stone against the reference's SURFACE clastic rock -- the reference
         frame reads "+2 m OPEN SKY". Like for like, our surface clay's metre-scale energy is 0.047-0.172
         against the reference's 0.071-0.133: the same range, and both vary more band to band than they
         differ from each other. Two constants revisiting T017 were moved and REVERTED -- they had not
         moved the measured number anyway, because `GRAM_CLUMP[massive]` gates that term to 0.25 for the
         material I was sampling.
- [~] 19 **MEASURED, MECHANISM FOUND, BUILD PARKED (D0581).** Rock does vary with depth -- clay runs
         0.376 at the surface to 0.211 at 10 m and back to 0.360 at 20 m, mean metre-to-metre luma step
         0.0255. But the complaint is right about the place it was made: **the flattest seven-metre
         window sits inside 1-10 m in all six columns sampled** (4-10, 3-9, 1-7, 1-7, 1-7, 2-8), and
         that is exactly where the tutorial happens. The mean step is uniform across columns
         (0.0242-0.0257), so this is a property of DEPTH, not of the column I first sampled -- checked
         precisely because `bedding_metres` warps the bed coordinate by up to +/-6 m along x.
         **THE MECHANISM:** `BeddingTone.tone_depth_boost` is `1 + depth/256`, so 1.00 at the surface
         and 1.47 at 120 m, and it multiplies BOTH the jitter and the bedding. The shallow world gets
         the least of both, by construction. The boost exists to compensate for the veil darkening the
         deep, and near the surface there is nothing to compensate -- so this is a side effect, not a
         bug in the boost. Fixing it means raising the RAW strata amplitude at short periods, which
         revisits T017, and it is a look call that needs a frame. Parked for the capture batch.
- [~] 20 **MEASURED: THE ROCKS SEPARATE ON HUE, NOT ON VALUE.** At 60 m the closest pair in luma is
         **0.029** (clay 0.197, deepstone 0.168) against clay's own within-patch spread of **0.037** --
         so their brightness ranges overlap and value alone cannot tell them apart. The blue-minus-red
         axis does the work: clay -0.129, hardrock -0.012, deepstone +0.031, a spread of 0.10 unlit.
         **A hypothesis of mine measured FALSE here and is reported rather than buried:** I expected the
         warm lamp (`LAMP_TINT` 0.62 multiplies blue by 0.690) to compress exactly the axis carrying the
         separation. It does the opposite -- under the lamp the cool spread RISES to 0.1365 and the luma
         spread to 0.0793, because the lamp brightens everything and scales differences with it. T012's
         ruled 0.38 gives 0.1459, so 0.62 costs about 6% of the hue separation: real, small, and the
         opposite sign from what I predicted. Whether 0.10 of hue reads "at a glance" needs a person or
         a vision judge asked WHAT IT SEES (never which it prefers). Parked for the capture batch.
- [ ] 21 **NEEDS A RULING FIRST (per-cell provenance is sim state).** A cut face reads as cut, not as a natural cave wall. **GENUINELY UNBUILT, and the largest
         remaining item in this phase.** Nothing anywhere distinguishes a dug cell from a generated one:
         `RockTone` shades by grammar and noise fields, `GlintPainter` is the only thing that mentions a
         "dug face" and it means exposed ore. Doing this needs per-cell provenance -- sim state, with a
         save-format cost -- so it is not a view-side change and wants a ruling before it is started.
- [~] 22 Rubble and scree at the foot of a cut. **Cosmetic debris stays SEPARATE from solid simulation**
         (audit): particles can communicate a collapse without every speck obstructing a factory. The
         particle channel already exists -- `SeatEffects.SLUMP_DUST` puffs a vacated cell (D0564) --
         so this is a tuning-and-taste item on shipped machinery, not new machinery. Capture batch.

### Phase 4 -- AIR (~8%)

- [x] 23 **ALREADY PRESENT AND ALREADY PINNED**, in two places: `AmbiencePainter.updraft_motes` (six
         per lift shaft, fading as they climb, none under rock) and `FallingItems.motes` (one per drop
         for the light pass). `test_ambience_painter.gd` and `test_falling_items.gd`.
- [x] 24 **ALREADY PRESENT.** `SeatEffects` fires `particles.debris` along the swing direction plus a
         `dust` puff on every break, and `particles.chip` on a strike that does not break.
- [x] 25 **DONE (D0586).** D0564 puffed the cell that EMPTIED; `Slump` now publishes
         `landed_this_tick` and the seat puffs where the earth arrives too. Half the count -- a landing
         is a thump, not a cell coming apart.
- [x] 26 **ALREADY PRESENT.** `haze_painter.gd` is the plume over a working furnace (D0379). Note this is
         HEAT haze, not the atmospheric depth haze item 14 wants -- those are two different things and
         the queue conflated them.

### Phase 5 -- SURFACE (~7%)

- [~] 27 **BUILT (D0584), CAPTURED.** The canopy was one flat rectangle of green because `_cell_jitter`
         samples in METRES (17-48 m periods) and a canopy is 1.5 m across -- every leaf cell drew the
         same value. Plants now take a cell-scale `foliage_tone` with clumps, a per-cell break-up and a
         per-column term so no two trees match, and they no longer take sedimentary bedding. The
         SILHOUETTE is still rectangular; that is generation, not view, and is a separate item.
- [ ] 28 Grass tufts with height variation. **NOT ATTEMPTED.** `SurfaceTone` already carries moss,
         roots, blades and hanging tufts, all WITHIN the cap cell. Real height variation means drawing
         into the air row above the surface, which is a new painter rather than a constant.
- [x] 29 **ALREADY BUILT, AND NOW ACTUALLY VISIBLE (D0583).** `SkyPainter` has had a starfield, sun,
         moon, clouds, the Sinkforge crown and three parallax ridgelines since D0244. `DAYLIGHT` was
         pinned at 0.35 (dusk) explicitly to show the most features at once, not because it looked
         right. At 0.15 the stars read and the sky agrees with the ground.
- [ ] 30 Falling and drifting leaves. **NOT ATTEMPTED** -- needs an ambient emitter keyed to canopies.

### Phase 6 -- FRAME AND CAMERA

**THREE OF FOUR ALREADY BUILT, and that makes TEN across the whole queue** (10, 13, 15, 16, 23, 26, 31,
32, 33, and half of 11). **The queue was authored from stale diagnoses.** Several items came from
Astra's earlier observation notes and from a triage pass that read the source's intent rather than
running against the current tree -- item 31's "the frame shows the void past the world" was fixed by
D0333 on 2026-09-01, item 33 asks for a 64 m world that already exists, and item 10's premise was
inverted. The lesson for the rest of the queue: **measure the item before building it.** It has cost
nothing and saved most of a night.

- [x] 31 **ALREADY PRESENT (D0333, 2026-09-01), CALLED, AND TESTED.** `CameraRig.set_world_limits` /
         `clamp_to_limits`, applied inside `step()`, called from `shell/main.gd:106` with the grid's
         pixel bounds, covered by three assertions in `tests/test_camera_rig.gd`. Astra's point 4 was
         written before D0333 landed and the queue inherited it stale.
- [x] 32 **ALREADY SATISFIED.** `Settings.zoom_idx` defaults to **0** and `shell/main.gd:89` reads
         `ZOOM_LEVELS[zoom_idx]`, so the boot zoom already IS `ZOOM_LEVELS[0]` = 2.00. Measured on the
         real world: 2.00 shows 40.0 m of a 64.0 m world, so nothing is framed with void at the default.
- [x] 33 **ALREADY DONE -- THE WORLD IS ALREADY 64 m.** Measured, not read: `WorldSeeder.load_world`
         gives 256 cells x 4 px = 1024 world px = **64.0 m**, which is exactly what P031's ruling asked
         for. The audit's caution ("widening only postpones an empty east edge") still applies to item
         34, and now applies to a width that already exists rather than to one being proposed.
- [x] 34 **DONE (D0590).** Astra's D7 ruling picked among T036's four: a deliberate noninteractive
         continuation, no wider world, and the bore-wall lore DEFERRED rather than taken. What stood
         past the edge was not void -- `SkyPainter` fills below the horizon across the whole view, so it
         was the sky's own blue at luma 0.1968, ground-coloured sky where earth should be. It is now
         stratified `deepstone` that recedes over 12 m, measured at a near-constant 60-75% of the
         in-world rock at every depth: darker than both the fill it replaced and the terrain it
         continues, with no step at the surface and no black at the far end. **Not yet judged on a
         frame** -- the director is using the screen; the capture belongs to item 49.
         *(superseded)* The east edge, T036: cliff, bore wall, dark rock to the canvas, or a wider world. **THE ONE
         REAL ITEM IN THIS PHASE, and widening is no longer among its answers.** Measured across the
         zoom ladder on the 64 m world: 2.00 shows 40.0 m (no void), 1.40 shows 57.1 m (no void), 1.00
         shows 80.0 m (**256 px of void**), 0.66 shows 121.2 m (**915 px of void**). So the defect is
         real but it is confined to the two widest zooms, and it is a QUESTION about what the world ends
         with, not a width to change. Four candidate answers are already written in T036.

### Phase 7 -- HUD (~5%, and the one that removes shipped work)

- [~] 35 **TONED (D0583), CAPTURED.** Against a night world a 90%-opaque plate is the brightest thing
         on screen. `UI_BG` 0.90 -> 0.66, `UI_EDGE` and the bevel toned with it, and the minimap's chart
         darkened (`ROCK_DARKEN` 0.35 -> 0.70 -- these are `Color.darkened` AMOUNTS, so larger is
         darker; written as 0.20 first, which made it brighter, and the capture said so at once). The
         COUNT is unchanged; what changed is that the furniture no longer sits on top of the world.
- [~] 36 Cut instructional prose. **PLATES TONED, COPY UNTOUCHED, DELIBERATELY.** The audit is right
         that this must not become an absolute -- "replace it only when an embodied cue actually
         communicates the same information reliably" -- and the GRAPPLE lesson teaches SHIFT-to-throw
         and W-to-climb, which nothing in the world currently says. The plates carrying it are quieter
         (D0583); the sentences stand until something replaces them.
- [~] 37 **HALF ALREADY BUILT, AND THE OTHER HALF IS NOW NAMED.** `view/visuals/machine_labels.gd`
         already solves plate-on-plate: runs collapse to one plate with a count, and neighbours that
         would overlap are shelf-packed onto a second row, with the aimed machine packed first.
         `tests/test_machine_painter.gd:128` pins all of it. **THE REAL DEFECT IS THAT "MOUTH" IS NOT A
         PLATE.** It is a `RingWord` -- the word under a target ring -- and `RingWord` and
         `MachineLabels` are two independent systems with no shared packing, so a ring word can land on
         a machine plate and neither knows. That is the collision the queue reported, and it is a view
         change with a frame to judge, so it is for the capture batch.
- [ ] 38 The recipe line has no words: "1 [grey] 2 [orange] -> 1 [yellow]".
- [ ] 39 A diegetic depth and band indicator.

### Phase 8 -- CONTENT

- [~] 40 **THE CUE ALREADY EXISTS (D0521).** `core/reach.gd` is the one reach rule -- 3.2 m, held as
         16/5 so the squared compare stays exact -- and `RingWord.draw_under` appends **IN_REACH** to a
         metre target's word when the body is inside it. The remaining gap is the one D0557 named and
         did not close: nothing distinguishes 3.2 m from the 5 m a player reads as "next to it", so the
         ring is visible from far outside the reach it is gating. A frame item.
- [ ] 41 Join "you are carrying coal" to "the forge is starved". Both are drawn; nothing connects them.
- [~] 42 **MEASURED AND PUT TO THE DIRECTOR (P042).** Two tiers on file, `d1` and `d2`. This is content
         design -- what a tier should ASK for is the director's call -- but it pairs exactly with 43.
- [~] 43 **MEASURED, AND THE QUEUE'S OWN COUNT WAS WRONG (P042).** Six orphans, not seven: `torch` IS
         placed by a start. The six are `rope`, `pump`, `plate_press`, `iron_forge`, `gear_mill`,
         `blast_furnace`. **Four of them strand a recipe apiece** -- `press_plate`, `smelt_iron`,
         `mill_gear`, `smelt_rich` -- so of the game's **6 recipes only 2 are reachable** (`mine_ore` on
         the drill, `smelt_ingot` on the processor). Two-thirds of the crafting content cannot be
         reached by any route the game currently offers.
         **CORRECTED 2026-09-10 (D0588): they are unreachable TWICE OVER.** Astra caught that
         `ore_iron` yields `ore` while `smelt_iron` consumes `iron`; checking the whole graph,
         **`iron` and `rich_ore` are consumed by recipes and produced by nothing anywhere**. The set of
         recipes whose MACHINE is unobtainable and the set whose INPUTS are unproducible are the same
         four, so neither half of the fix does anything alone. P042's "one ruling would reach all of it"
         is withdrawn.
- [ ] 50 **A PROGRESSION GRAPH, GENERATED FROM `data/`, THAT CAN FAIL.** The director's ask: map every
         craftable as both an economy to read and a validation that new content enters the tree rather
         than being dropped in isolated. Scoped against the repo (agent pass, 2026-09-10) -- these are
         the facts that decide its shape, all verified in-tree:
         - **Prior art is null.** `tools/schema_validator` does per-file fields and types only and says
           so in its docstring; it does no cross-record reference checking of any kind.
           `tests/test_economy.gd` is a `ProductionRate` ring buffer with zero recipe assertions;
           `test_reach.gd` and `test_reachability_sweep.gd` are name collisions (arm reach, body
           traversal). **What exists to build on is `tools/data_codegen/generate.py`** -- it already
           loads every YAML under `data/` and already has a `--check` gate mode.
         - **A build cost cannot be added to a machine record.** `data/machines/SCHEMA.yaml` lists
           `craft_cost`/`craft_count` under `forbidden:`, enforced by the validator, on a director's
           ruling: "not as code, not as a craft_cost data field." So the proposal's quantity increment
           has no field to stand on. The cost that DOES exist is the rig's `wants:`.
         - **Three quarters of "what consumes an item" is in code, not data.** `Machines.machine_eats`
           is a union of four rules -- the coal-burner set, `winch_head` + bulk, `rig` + the current
           demand, and `recipe.inputs`. Only the last is in `data/`. A data-only checker models one
           quarter of consumption and is blind to the rest; say so in its own output or it overclaims.
         - **Nothing in the data marks which start is the shipped one.** `tutorial` is named only by
           `shell/main.gd`'s `const START`. `site:` splits "stamps world geometry" from "stamps a pack",
           which is the wrong axis -- `beacon_probe` and `lighting_bench` both carry it and both say in
           their own first line that they are scenario records, not starts of play. Without a
           discriminator the gate would count a bench's placed machine as shipped progression. Needs an
           optional `shipped:` on the starts schema (absent reads false, this schema family's own
           convention) plus an assertion that `main.gd`'s `START` names a record carrying it. **A
           hand-maintained list inside the checker is the option to refuse** -- same shape as the
           allowlist `check_ci_not_shrunk` exists to reject.
         - **A naive scan would be fooled today.** `data/strata/shallow_clay.yaml` has a top-level
           `iron:` key that is terrain-gen tuning, not an item. Anything grepping `data/` for
           item-shaped strings "finds" iron and declares `smelt_iron` fed.
         - **The AND semantics are the likely silent bug.** A recipe is reachable only when ALL its
           inputs are; plain graph search declares it reachable on one. The fixpoint used for D0588 --
           repeatedly fire every recipe whose inputs are all available -- is the correct semantics.
           Cycles are not rejected wholesale: reject only a cycle that cannot START from a seed.
         - **It lands RED on today's tree**, so it ships `continue-on-error` (reported-only, the
           `coverage_check.py` precedent) or it waits on P042. It cannot block work on a design call it
           cannot make.
         Deliverable in this repo's conventions: `tools/layer_lint/check_content_reachable.py` with
         `tools/layer_lint/test_check_content_reachable.py` beside it, one step in harness.yml's `gates`
         job (which buys `run_local_battery` pickup, a `check_ci_not_shrunk` floor, and mutation-test
         enrolment for free), QUALITY gate **37, appended** -- gate numbers are addresses. Population
         line first, then members, then one PASS/FAIL line. **Mutation cases that matter:** an empty
         `data/recipes/` must FAIL rather than pass vacuously; a seeded cycle must PASS where an unseeded
         one FAILS; and flipping `dev_kit` into the shipped set must CHANGE the verdict -- if it does
         not, the fixture exclusion is decorative and the whole proof is unfalsified.
         **Build (a) the graph and a member-listing reported-only gate. Defer the blocking verdict, the
         `shipped:` field and every quantity/fuel increment until P042 is answered.**

### Phase 9 -- VERIFY

- [ ] 44 Opus playthrough again, same route as item 1. The only honest test of phases 1-5.
- [ ] 45 A stranger batch STARTED AT RUNG 4, six seats, haiku, pinned mission.
- [ ] 46 Astra's fixture question (`docs/audits/2026-09-09-presentation-regime-handoff.md`).
- [x] 47 **DONE.** Battery 179/179 (151 suites + 28 gates), tree clean, 12 commits pushed to origin.
- [x] 48 **DONE.** `docs/BRIEF.md` leads with the five findings; the ledger carries D0575-D0586; this
         file is current; P038-P043 are the open director questions.

### Phase 10 -- THE MATCH LOOP (the director's closing instruction; does not terminate on its own)

- [~] 49 **FIRST PASS DONE, THREE OF FOUR CONDITIONS MOVED.** See below.

### Phase 10 -- THE MATCH LOOP: first pass, 2026-09-10

**The stopping rule this item was given** (written earlier tonight, from the audit): numerical match
against a single JPEG is rejected as the terminus. The loop stops on four readable conditions, judged on
our frames: **materials read as themselves at play zoom; carved space is spatially separable from solid
rock; the lighting is attractive rather than merely bright; and it holds under a moving camera.** Each
pass records which of the four it moved.

**Pass 1 moved three of the four.** Captures:
`docs/media/moments/2026-09-10-before-night.png` (the opening frame as it was),
`-after-night-surface.png`, `-after-night-deep.png`.

| condition | before | after | moved? |
|---|---|---|---|
| materials read as themselves | canopy 0.479 luma, flat, brighter than lit ground; three trees identical | foliage clumped at cell scale, trees differ from each other, no sedimentary bedding on a tree | **yes** |
| carved space separable from rock | a void and mid rock both resolved near 0.58 -- no dark end in the deep | void darkened after the ambient lift; carved shapes read as holes | **yes** |
| lighting attractive, not merely bright | sky 0.086 at the zenith over ground at 0.344 -- night sky, noon ground | night level on the surface, night sky, lamp is the brightest thing in the frame | **yes** |
| holds under a moving camera | not tested | **not tested** | no |

**Measured against the reference, on a real 45 m frame:**

| | before tonight | now | reference |
|---|---|---|---|
| unlit deep rock | 0.0195 | **0.1926** | 0.190 |
| the lamp's pool | 0.210 | 0.4355 | 0.515 |
| rock 1 m from the lamp | 0.157 | 0.2758 | 0.377 |
| surface ground at night | 0.344 | 0.155 | 0.148 |

**What the loop should take next, in order:**

1. **The fourth condition is untested.** Every judgement above is a still. A moving camera is where
   pixel-snap, the veil's per-frame field sampling and the parallax ridgelines can all fail, and none of
   it shows in a screenshot. This wants a short recorded pan, not another capture.
2. **Rock a metre from the lamp is the largest remaining numeric gap** (0.276 against 0.377). The
   multiply half is at its ceiling there, so it is the additive pass's falloff shape, not a veil
   constant.
3. **Tree silhouettes are still rectangles.** The canopy now reads as foliage but its outline is a
   block, and that outline is generation rather than view.
4. **The shallow world is still the flattest rock in it** (D0581) -- the flattest seven-metre window is
   inside 1-10 m in every column sampled, which is exactly where the tutorial happens.

### Explicitly DEFERRED, with the reason (do not quietly pick these up)

- **The chute, the feeder, holes-as-routing** (GDD §13 positions two and three). Wanted, and they are
  design rather than implementation: far better decided once the world behaves and can be seen, and they
  are the items a z ruling would most change. Designing the routing primitives twice is the expensive
  mistake.
- **The z spike.** Cheap and informative, but only AFTER phase 2. See the sequencing finding above.
- **Minimap restyle.** z-fragile, low value.
- **Miner sprite work.** He is 40 px tall and his lamp is already the best-reading thing in the build.
- **Any further bake-pipeline perf work.** The programme is closed and a z ruling would redo it.
- **New HUD text of any kind. Permanently.** `NORTH_STAR.md` §4.

## Performance programme — the five passes, September 8

**D0547 runner/GPU checkpoint:** foreground argv now permits focus and a PID-scoped keeper requests
it; measured focus still gates claims (latest 0.92/0.95, withheld). Setup and density counts survive
JSON; runtime/settings/engine provenance constrains comparisons. Metal System Trace produced real
PID-filtered GPU intervals; Godot's zero GPU timer remains unmeasured. Exact shader parity is OPEN.
Claude's `d344a35d` included the initial five tooling files; do not reapply those changes.
[Status, reproduction and verification](audits/2026-09-09-runner-gpu-closeout.md).

**D0542 implemented:** paired slowest-preparation receipts and per-chunk scheduling reasons now
reach the saved performance report. One 900-tick dig trace attributes its 9.793 ms warm peak to
four optional-margin callbacks (1,024 rectangle cells). Focus was lost: frame metrics withheld.
Six focused engine suites plus Python fixture tests pass. No scheduling/art change or full-battery
claim. Next: cold-descent coverage and a bounded optional-margin treatment; see the handoff below.

**September 9 review, D0541:** D0540's streaming attribution is not established. Peak preparation
time and peak cells are independent extrema, not one event, and rectangle area does not identify
a lane. Before scheduler changes, retain a paired slowest-event receipt and scheduling reason through
the draw callback. [Claude handoff and bounded implementation queue](audits/2026-09-09-bake-burst-handoff.md).
Three focused bake/fixture suites pass; no runtime changes or new FPS claim in this analysis pass.

**D0539 small follow-up:** explicit camera resets clear camera interpolation history, including
cuts below the inferred-teleport threshold. Four new assertions failed before the fix; camera,
main-boot and world-view suites pass afterward. Miner history/simulation are unchanged;
interpolation remains opt-in. Focused verification, not a full-battery or motion-quality claim.

**D0538 audit corrections take precedence over the historical summaries below:** the fixture now
rejects failed/incomplete processes and empty repetitions, suppresses withheld frame comparisons,
retains raw parsed windows, reports actual maximum separately from median window maxima, and uses
the real frame denominator. Peak preparation per physics tick is now instrumented. The earlier
54.5 → 21.5 ms was a median-of-maxima claim, not actual worst-frame evidence. The prefetch utilisation
argument compared different populations and is withdrawn. Wide zoom showed a 6.865 ms preparation
burst against 0.306 ms/tick average; presentation numbers were withheld. Fresh cave captures do not
reproduce the claimed blanket 2.4–3x brightness excess. Full corrections and artifacts are in the
[audit report](audits/2026-09-08-performance-programme.md). Shader parity, lane-specific burst
attribution, interpolation motion review and water/large-factory coverage remain open.

Astra's pass 1 is committed at `6b4b5e6c` (D0533, exact-picture neighborhood sharing) and pass 2 is
partial at `b836bac3` (D0534, the OFF-by-default shader prototype retains surface tufts). The engineer
verified both, ran the complete battery Astra's handoff left outstanding (172 checks, 144 suites, 0
failures) and carried the remaining queue. Full account for audit:
[the report](audits/2026-09-08-performance-programme.md).

**The measurement came first (D0535).** `tools/perf_fixture.py` plus `view/visuals/bake_cost.gd` and a
calibration loop in `shell/frame_meter.gd`: four named workloads, terrain preparation and upload split
from the draw, a fixed-work host-speed control inside every window, and six refusal rules that VOID a run
rather than report it. It refused four of its own first runs, correctly. A scripted seat is now deaf to
the machine's real keyboard and mouse -- `PlayInput.verbs` read the hardware on every seat, driven or
not, so a keystroke typed by whoever owns the laptop could change what MINE snaps to.

**Where the frame stands -- MEASURED VALID for the first time (D0551), `--front`, quiet desktop, 1280x720,
zoom 2, M4 Pro, window focused in 100% of frames.** All four workloads, 3 reps, controls 1.37-1.44:

| workload | fps_wall | p50 | p99 | max | over 16.7 ms | bake prep |
|---|---|---|---|---|---|---|
| still | 394.6 | 1.62 ms | 15.73 ms | 26.25 ms | 0.84% | **0.000 ms/tick** |
| walk | 381.3 | 1.52 ms | 16.51 ms | 32.21 ms | 0.97% | 0.070 ms/tick |
| dig | 348.7 | 1.55 ms | 17.70 ms | 35.08 ms | 1.47% | 0.537, peak 7.551 |
| fall | 377.9 | 1.46 ms | 17.79 ms | 35.45 ms | 1.23% | 0.395 ms/tick |

**The median clears 2.78 ms everywhere; sustained `fps_wall` straddles 360 rather than clearing it.**
The earlier "400-530 fps, 360 already met on the average and the median" is WITHDRAWN: those numbers came
from windows macOS was not presenting.

**READ THE TABLE ABOVE WITH D0555 IN HAND -- it was taken at `--disable-vsync --max-fps 0`, and that flag
is inside the measurement.** At ~400 fps the app produces 3.4 frames for every one a 120 Hz screen can
present, so it blocks in `RenderingServer.draw` on a drawable that does not exist yet: ~13 ms at the p99
of every workload, `rcpu` 0.1 ms, GPU 5.1% busy. That wait is SLACK, not cost. Capping the rate below
the display's drains it -- draw p99 is 0.80-2.48 ms at any cap up to 120 and 8.24-8.51 ms at 150, a step
at the screen's own rate whose height is one 120 Hz slot. **"89% of the tail is there when the bake does
nothing" is WITHDRAWN** (see `docs/CORRECTIONS.md`): both arms sat in the same wait, so subtracting one
from the other compared two waits. `project.godot` sets no vsync key, so what a player runs is:

| workload | regime | fps_wall | p99 | over 16.7 ms |
|---|---|---|---|---|
| still | vsync (shipped) | 118.8-120.0 | 13.81-15.97 ms | **1-5 / 597** |
| dig | vsync (shipped) | 119.2-119.8 | **23.37-25.45 ms** | **28-30 / 597** |
| still | `--disable-vsync` | 399-416 | 14.27-16.39 ms | 14-20 / 2068 |
| dig | `--disable-vsync` | 320-358 | 17.09-21.25 ms | 22-35 / 1598 |

**One frame in twenty is a 22-31 ms stall while digging, against one in 300 standing still**, and the
dropped-frame COUNT barely moves between regimes while the RATE moves 2.5-4x. The bake is worth ~9.5 ms
of the shipped p99, not the 2.0 ms D0551 sized it at, so D0549's halo and D0550's sharing are back at
full size. A warm dropped dig frame is ~8.6 ms vblank wait + ~3.5 painters + ~1.2 refresh + ~1.7 HUD and
**7.0-8.8 ms that no painter clock reaches** -- the bake, inside the redraw flush -- against 0.47-1.83 ms
of the same residual on still. The window line now carries `present vsync= max_fps= screen=` so this
cannot be read the wrong way again.

**Landed since:** the minimap repaints changed cells rather than the world (D0536) -- it was rebuilding
all ~17,000 logic cells on every terrain version change, 36.5-38.1 ms in one HUD chip on nineteen of
twenty slow frames of a mining run; the worst frame of that run fell 54.5 -> 21.5 ms, reproduced.
Presentation interpolation behind `--interpolate`, OFF (D0537): the camera and the miner presented
between sim ticks, lerped before the pixel snap so the grid survives, at no measurable cost. It is a
motion change and awaits the director's eye.

**Audited by Astra, D0538-D0539, and corrected.** Five real defects in the fixture: stderr discarded so a
failed seat looked healthy, no check that the process exited 0 or that every window arrived, `max`
reported as a median of per-window maxima under a worst-frame label, and an invented `/600` denominator
under the over-budget counts. Astra also fixed a real bug in D0537: `CameraRig.warp_to` never passed
through the teleport guard, so a short camera cut blended from a stale position (verified here -- their
four assertions all fire when the fix is reverted). Their peak-per-tick preparation telemetry is the
instrument the programme was missing.

**D0540, the claim re-measured and the next bottleneck named.** On the corrected fixture, with the
pre-D0536 minimap restored in the working tree and the control at 1.02x, the observed maximum falls
**61.08 -> 35.87 ms** and frames over 16.7 ms fall from 205 of 13,359 to 165 of 14,548. The earlier
"54.5 -> 21.5" was the mislabelled statistic and is withdrawn. The same run names what is left:
**preparation peaks at 9.0 ms in ONE physics tick over 1024 cells at ordinary play zoom**, against a
0.56 ms/tick average -- 3.2x the frame budget, untouched by the HUD fix, and the next thing to fix.

**The bake burst, D0541-D0543.** Astra's audit found D0540's "9 ms over 1024 cells" joined a peak
duration and a peak area the instrument had maximised independently, and built a paired receipt and
per-chunk scheduling attribution (D0542). On that: the optional margin is now capped per tick and ordered
one chunk ahead of the camera's own travel (D0543), with mandatory work uncapped and mutation-tested to
stay so. Default-zoom dig, both arms: the work is bit-identical -- 876 dig callbacks over 84,804 cells,
96 margin over 24,576 -- so the cap defers and drops nothing, and the slowest event moves from four
margin callbacks at 9.821 ms to four dig callbacks at 9.486 ms. The picture is byte-identical at a
settled tick. No timing improvement is claimed.

**The runner can measure frames again, and the GPU is measured at last (Astra's D0547, verified as D0548).**
`--front` was emitting `--unfocused` unconditionally, so the one regime a frame rate can be claimed from
was launched refusing focus -- which is why frame metrics were WITHHELD at focus 0.00 in every run of
D0542 through D0546. Astra fixed it (foreground requested by the launched PID), added source/settings/
engine provenance with comparison guards, and captured a real Metal trace. **GPU execution is 5.14% of a
20.477 s dig capture** (1,052 ms union of 19,958 intervals; Fragment 76.9%, Compute 16.6%, Vertex 6.5%) --
the first evidence for the CPU-bound premise this programme has assumed throughout. Verified here by
source read, an independent brute-force check of the interval union over 3,000 random cases, and a full
battery (173 gates, 145 suites) under a working-tree guard. **Still open: `FOCUS_MIN = 0.95` and the
option-conflict guard are UNPINNED** -- lowering the threshold to 0.50 keeps every test green, on the one
number that decides whether a frame measurement may be believed. Reported to Astra, whose file it is.

**Half the dig's dilated work is the chunk split (D0549).** `plan_tick` computes one `dig_rect` and
`partials_of` cuts it along chunk boundaries; each piece then builds its own `RockNeighborhood` over its
own dilated rect, so adjacent halos overlap. Measured across three windows: **overlap 50.8%, 50.8%,
49.2%** -- about 1,050-1,130 dilated cells a dig tick computed twice and drawing nothing, a ceiling of
~74-76 ms against ~157-162 ms of dig preparation. The per-tick and per-callback accumulators, wired on
opposite sides of the frame, agree exactly (50,828 both ways). A sharing treatment would be
picture-identical -- `RockNeighborhood.code()` indexes by absolute cell -- but is NOT implemented: it
threads shared state through `Frame` into `TerrainPainter` and needs a byte-identical capture and an
interleaved A/B, which D0547 has only just made possible.

**The painter instrument could not see a burst either (D0552).** `draw_cost.gd` read only the last
draw and a running total, so a painter costing 0.5 ms every tick and one costing 0.1 ms with an 8 ms
spike looked identical. `PaintLayer.max_draw_usec` now records the peak. On a still frame doing no
terrain work: **`machine_painter` peaks at 4.15 ms against a 0.48 ms average -- 8.6x**, with sky 2.65,
veil 1.77, miner 1.66. Real and actionable. **It does not explain the tail:** host-normalised those
peaks sum to ~5.1 ms against a 13.30 ms draw p99, and that sum is an impossible frame where all four
peak at once, so the painters are at most ~38% of it. The rest is presentation, which `--hidden` removes
by construction -- the next `--front` run has a specific question to answer instead of a guess.

**Measurement protocol (2026-09-09):** `--hidden` is the DEFAULT for CPU-phase work; it agrees with
`--front` to 0.2% once control-normalised, and it never touches the director's screen. Frame claims
(`fps_wall`, p50/p99, worst frame, draw phase) need `--front`, which owns the screen for the run, so
they are batched and announced rather than fired ad hoc.

**Streaming coverage is verified and the prefetch is not starved:** 96 chunks streamed as margin at
default zoom and 128 at wide zoom, with **zero arriving on screen unpainted**, before and after.

**What it redirects, and what that redirect turned out to be worth (D0545).** Digging is 85% of
preparation and margin 15%, and the handoff's third case -- dirty-repaint region setup -- is now
**measured and closed as the leading suspect**. `BakeCost.prep_setup_*` times the observation apart from
the painters: region setup is **14.0% and 12.7% of preparation** across two warm dig windows, at an
observed-over-painted area ratio of **7.33x and 7.14x**. The inflation is real -- every bake rect is
grown by `WINDOW_MARGIN_CELLS` (9) on four sides while the clock is charged over the painted rect -- but
it explains only about **17%** of the 5.5 us/cell gap between dig (14.4) and margin (8.9). **D0546 finished it: solid-cell
density is not the answer either (dig 75.2% solid against margin 69.4%, a 1.08x difference), and the
real denominator is the DILATED span.** `TerrainPainter` builds one `RockNeighborhood` per callback over
`cells.grow(FORM_REACH)` and scans it three times; charged per dilated cell the two reasons converge to
**3.01/2.94 us (dig) against 2.71/2.86 (margin), within 3-11%**, where per painted cell they differ
1.64-1.82x. So a dirty repaint is dear because a dig plans MANY SMALL RECTS and every per-callback cost
is paid over a grown region, not because a dug cell is dear. The treatment that points at -- coalescing
a tick's dig rects so the dilation is paid once -- is an affected-area change, is NOT implemented, and
its cost (the union repaints cells that did not need it) is unmeasured. Five mutants killed across the
two entries. No scheduling, picture, or FPS claim. Left open: at wide zoom a terminal-velocity fall's slowest event is three margin callbacks
at 28.089 ms, which is what avoiding a hole costs there; its before arm came back VOID and that A/B is
inconclusive and was stopped rather than stacked.

**Not done, with reasons in the report:** the shader prototype stays OFF and unfixed -- its divergence is
not the reported seam but a whole-surface brightness difference that grows with distance into the rock
(2.44x at a cut's edge, 3.00x five cells in), so the carved-edge lighting gradient is the suspect and
enabling it is a director art call (T040). Movement-ahead prefetch was inspected and NOT built, but that
inspection's central number is WITHDRAWN (D0538): 46 and 31 cells a tick is repainted rectangle area
including air and unbudgeted dig repaints, not solid cells admitted by the window lane, so it cannot be
read against a 512-solid-cell budget. What survives is that no visible hole appears at the first
presented frame after a cold warp to 131 m -- and D0540's 9.0 ms single-tick burst says the lane's
scheduling is the open problem after all.

## Current stage

The A′ legacy port has implemented the playable systems through its presentation and generation work.
The rig-as-consumer economy (A′ step 7) remains unimplemented.
[The backlog](BACKLOG.md) owns task routing; [the plan](A_PRIME_REFACTOR_PLAN.md) retains port detail.

## Gameplay continuation

**Reconciled 2026-09-07 late from the engineer's verified batches (D0506-D0520).** The opening is measured
by six-seat blind batches on the shipped seed, all seats VALID, reports under [playtests](playtests/):
103-108 (`2026-09-07_strangers103-108_drop.md`), 109-114 (`..._stride.md`), 115-120 (`..._reach.md`),
121-126 (`..._inreach.md`).

Where the opening stands, by rung, over the last four batches (24 seats): four ore 24 of 24; coal in the
pack 21 of 24; two ingots 8 of 24; delivered 4 of 24; the drill placed 2 of 24; the fuel rung reached by 2.
The last batch alone (D0521, the ring reads IN REACH by the drop's own rule): smelt 3 of 6, delivered 3 of
6, the drill placed 2 of 6, against 1 delivery in the 18 seats before it. The walls left in it: the world's
east edge (14 of 24 seats walked to it), the ceremony card read as the end (2 seats), a self-dug pit.

Landed since the first-rung brief: the boots' footing (D0509), the lazy terrain bake and the tooth's
grammar texture (D0506, D0511), the drop refused with the stack in hand when its eater is in sight but
out of reach (D0513), the FED receipt and the TOO FAR lesson with metres and direction (D0517), the cards
leading with WALK and STAND (D0515), the floor-ambiguity check bounded to its subject (D0516: 0 reports a
seat, from 38-168), new_game's phases and the batch's fresh-game snapshot (D0518, D0519: a seat boots in
0.7 s, six in 5.4 s wall), the mission's tick calibration (D0520: it did not change the actor's walks),
the ring's IN REACH state (D0521), the spider cracks removed at the director's ask (D0523), THE EDGE
lesson at the world boundary (D0529) and the acknowledged rung's card naming the next rung with the
receipt using the ring's word (D0530) -- both now MEASURED by strangers 127-132 (D0544, below).

**Strangers 127-132, 2026-09-09 (D0544), on `60da8d1d`, all six VALID, 0 Invariants.** Four ore 6 of 6,
coal 5 of 6, two ingots 3 of 6, delivered 1 of 6, the drill placed 0 of 6.
[The report](playtests/2026-09-09_strangers127-132_hotbar.md). **D0529 fires exactly on its trigger** --
three seats entered the 4-cell edge band, all three saw the lesson, no seat outside a band saw one; two of
the three then left the band, where two of three ended at the edge in 121-126. **D0530 was seen once**, by
the only seat that finished a rung past deliver, and that seat did not quit on the card; one observation,
not a measurement. **The batch's finding is neither lesson: the hotbar renumbers itself under the player.**
`slots` is the bar's own order, draining a stack removes it and shifts every later stack down a number, and
re-acquiring it appends at the end -- so the smelt rung, which asks the player to drain stacks into a
machine, is what invalidates the numbers the card tells them to press. Four of six fed or selected the
wrong stack; the only seat that delivered is the only one whose bar never reordered. No regression is
claimed from 3/6 to 1/6 delivered: six seats cannot separate those. Live and separate: two seats stood
beside a ringed RIG at TOO FAR.

The director's freeze, measured and mitigated: the investigated blow stalls were terrain bake work, not the sim (0.3 ms a tick
headless). A blow repaints its own dilated rectangle, chunks are 16 cells, and the streaming lane budgets
solid cells a tick (D0522, D0524: worst blow frame 419 -> 60 ms, a shaft fall's worst 80-90 -> 22-23 ms);
a still frame redraws only the layers whose input moved (D0531, ~5% of the still tick; the 18 ms still
frames themselves are display pacing and a slow host, D0527, not a painter). The floor left is the CPU
molded tone at 18-25 microseconds a solid cell: T040 in the taste queue carries the shader evidence
(D0528, behind a flag that is OFF) and the orchestrator's read that its picture is not yet the CPU's.

For the director (numbers in the reports): the stride at 9 m/s against a 3.2 m reach (T035); the layout
(the forge alone lies left of the spawn, and everything else right of it); D3-D6's rewards; the hotbar
with an empty pack (D0412); T040's fork. Unresolved and unchanged: the grapple, wood, the sinkholes near
the pad, evaluator diagnostics in observations. The rig-as-consumer economy (A' step 7) is still
unimplemented; the rig pays the drill for two ingots (D0485) and the winch pair for six (D0492).

**D0553, the hotbar fixed (director's ruling on D0544's finding).** A stack now keeps its number: a
drained stack leaves a gap that holds its slot, the item returns to that number when picked up again, a
new item takes the leftmost gap before growing the bar, and an empty pack still draws no bar. `items` is
untouched, so the signature, conservation and text-order walks are unchanged; saves carry the gaps in a
new optional `pack_order` field whose absence is not an error. The empty well draws empty but keeps its
key digit. Nine assertions, three mutants killed. **Whether it moves delivery is for the next batch to
measure** -- strangers 127-132 are the before.

**D0554, chasing the batch's second wall.** Two seats reached `deliver` and neither delivered; S128 saw
"NO MACHINE HERE — nothing in sight takes that stack" for 24 of 38 bursts and never once saw
`dropped_short`, the only lesson carrying metres and a direction. A headless probe reproduced its exact
positions through the real command path: the sim is correct -- the refusal fires inside `FAR_EATER_M`
(12 m) exactly as D0513 specifies. What was wrong is the sentence. **A radius cannot match a rectangle:**
the play view is 40 x 22.5 m, half-extents 20.0 and 11.25, and 12 sits between them, so "in sight" was
false in both directions -- denying a machine filling the screen to the left, naming one off the top.
The sentence now says "near enough", which is what the game tested; **no behaviour changed**. Whether the
12 m window itself should widen (or become a rectangle) is a feel call left to the director, with three
options in the entry. And it is NOT why S128 failed: that was the hotbar, fixed in D0553.

**The perf programme STOPS at D0556, and the director's own words are why:** "it's been like 5 days with
no new features or UI improvements." Checked against the log rather than argued with -- 16 commits on
2026-09-09, **14 of them measurement**. D0555 and D0556 are both worth having (the frame tail was the
compositor, not the game; the bake's remaining treatment is worth 10% and will not stop the hitch), but
they are instruments, and instruments are not what the game needed today. **The next session opens on
gameplay and UI, not on the bake.** What is left of the perf queue, sized and parked: the shared
neighbourhood is a NO (D0556); the lever with the bigger arm is merging a tick's dig rects before
painting, unattempted and unestimated; Astra owns the fixture question in
`docs/audits/2026-09-09-presentation-regime-handoff.md`.

**Two shipped and UNMEASURED gameplay changes are the next batch's job:** D0553 (a stack keeps its
number -- the hotbar stopped renumbering under the player, which is why two seats never delivered) and
D0554 (the floor lesson stopped claiming what was in sight). Strangers 127-132 found the first; nothing
has tested either fix.

**One structural note so it is not rediscovered at a line cap:** `tests/test_perf_fixture.gd` reached
400 lines and `tests/test_frame_meter.gd` was split out of it (D0556). Suites are registered by hand in
`.github/workflows/harness.yml`, and a `_test_` function is registered by hand in `_initialize()` -- a
test that is written and not listed is silently dead, and `ALL PASS` will not say so. Read the asserted
COUNT after adding one; that is how tonight's was caught.

**D0557, and the pivot the director called for.** "It's been like 5 days with no new features or UI
improvements" -- checked, and right about the day: 16 commits on 2026-09-09, 14 of them measurement.
The perf programme is closed at D0556 and the work is gameplay again.

**THE REACH LINE ships.** While the ringed target is a machine (or BUILD's mouth) and the body is out of
reach, the ground the body's CENTRE must stand inside is drawn as a dashed circle at 3.2 m round the
ringed metre. It vanishes when the body crosses it and D0521's solid rim, fill and "· IN REACH" word take
over. No rule changed. Three strangers in three batches asked for this in their own words, most plainly
S111: "the game showed me I was always too far but never showed me WHERE close enough was."

**And the reach is 3.2 m, not one.** `docs/playtests/2026-09-09_strangers127-132_hotbar.md` published
"one metre" off a misread docstring; corrected in place and in `docs/CORRECTIONS.md`. It moved the fix a
whole layer: one metre is a rule to loosen (sim, the director's), 3.2 m is a thing to draw (view, mine).

**The gameplay queue, from the last batch's own findings, in the strangers' words:**

1. ~~**The TOO FAR lesson goes stale.**~~ DONE (D0558): it counts down every observe from where the body
   is now, and lets go the moment the body crosses into the drop's reach. The sentence also stopped
   reading "is 4 m to your ABOVE", which a PASS line had been quoting since D0517.
2. **Coal is the floor** -- and the journal says the batch report mis-attributed it. D0560 read S130's
   own words: it stood at the ringed coal seam, was refused, wrote "my reach is about a body length" (the
   game's phrase), stepped that far, was refused again, and walked back to the forge. The wall was `far`,
   not the 14 `air` refusals the report led with. TWO FIXES SHIPPED: the reach line now covers rock
   (D0560 -- and rock's locus is a rounded rectangle, not the circle a machine gets), and the three
   "about a body length" lessons now say 3.2 metres, substituted from `Reach` so the prose cannot drift.
   STILL OPEN: S130 pressed a NUMBER key at the seam twice expecting a panel like the forge's. Nothing
   says a seam is CUT rather than operated, and to a newcomer the two read alike. **Unmeasured -- the
   next batch is the test of all of it.**
3. ~~**S131's "three forges, no labels"**~~ DONE (D0559), and the capture changed what got built. There
   really are two forges; the far one had NO plate, because nameplates reached 6.4 m while the drop
   names a machine in words out to 12. One defect, not two. There is no ore-forge/coal-forge
   distinction -- both run `smelt_ingot` -- so that phrase in the report is a stranger's invention that
   I copied down; the missing thing was a NAME. The range now lives in `Reach.NAMED_M` and all three
   readers share it.

**D0553 and D0554 remain shipped and unmeasured**; with D0557 that is three gameplay changes waiting on
a batch, which is what the next stranger run is for.

**MEASURED: strangers 133-138 (D0561), and the overnight gameplay work landed.** Six seats, one snapshot,
uncoached, all VALID. **Delivery went from 0 of 6 to 4 of 6**; five reached `deliver` against two last
batch; one reached `fuel`. First rung 6 of 6, fastest 1.3 s. D0553 (the hotbar keeping its number) is the
reason. **Three of six strangers named the dashed reach ring and the 3.2 m under their own heading "what
the game told you well"** -- against 127-132, where D0521's IN REACH state went unread by every seat.

**The next wall is the world's east edge and it is the director's.** `world_edge_right` fired for 3 of 6
and is the last thing BOTH failures did before their bursts ran out. D0529's lesson fires exactly on its
trigger, names the way back, and they walk east anyway -- 121-126 sent 14 of 24 seats there. The lesson
has labelled the behaviour without moving it, so the question is what the world puts east of the opening.

**Also open, from the same batch:** BUILD's MOUTH (four seats reached `build`, one passed it, "TOO FAR
despite visible proximity"); nothing joins "you are carrying coal" to "the forge is starved" though both
are drawn (S138 stopped holding 12 coal and 11 ore, believing it had failed to get coal); and the forge's
recipe notation `1 [box] 2 -> [box] 1` was misread. S136's refinement of the reach work, in one line: the
3.2 m "only appeared after a failed attempt, not proactively".

**Read the receipts, not the reports.** Two of six final reports are refuted by their own
`observation_*.json` -- S138's "coal remained unsolved" (it held 12 coal) and S134's "TOO FAR every time
at the RIG from 7+ positions" (one drop lesson in 54 bursts, no `far` refusal at all, and
`world_edge_right` at burst 30).

## Repository cleanup (director-approved)

Tooling implementation complete (D0525): timing summaries, runner accounting/optional battery
parallelism, provenance-checked reporting receipts, parser/log isolation, and an opt-in
command-plus-image pilot. [Execution evidence and rollout limits](superpowers/plans/2026-09-07-iteration-efficiency.md).
Focused tests and the real-engine runner self-test pass; no whole-battery speedup or live-agent
latency improvement is claimed. Fresh checks and existing actor protocol remain the defaults.
Active director assignment: optimize the terrain shading hot path after the engineer's D0522/D0524,
preserving appearance. 360 fps is a measured host-specific target, not a hardware-independent guarantee.
Implemented D0526: bounded byte solidity, skip zero-weight bedding, reuse AO offsets. The focused
shading sample costs 40-56% less with identical colour hashes; this is not a full-frame speedup claim.
The CPU slice was incorporated in c8385ca3. Its full verification passed 28 gates and 142 suites before
the engineer's subsequent additions; that run is not certification of the now-144-suite tree.
D0528 subsequently added the GPU prototype, off by default; appearance parity and presentation
interpolation remain undone. Twelve focused integration suites pass on 41f00226 (D0532), including
the shader-data path, world view and main boot; the current full 144-suite battery was not rerun here.
Reproduction and next bottlenecks: [performance plan](PERF_PLAN.md).
Sequential continuation: D0533 completes shared per-region CPU shading with exact picture parity;
the existing shader prototype's seam/appearance correction is next, then prefetch, interpolation and
remaining dynamic painters. No 360 fps acceptance claim yet.
The gameplay section above was reconciled by the engineer at their 2026-09-07 late checkpoint
(after strangers 115-120); the batch queue is theirs, the tooling queue is this section's.

- Batch 1: accurate README, contributing commands, onboarding, tests guide and C003 blockers.
- Batch 2: concise working state, documentation authority, backlog routing and evidence retention.
- Batch 3: subsequent harness/test/tool organization and module-contract cleanup.

Batches 1–2 are documentation work; no gameplay, source paths, evidence, or CI checks are removed.
Batches 1–2 are complete. Focused item suite (78 assertions), schema/codegen, documentation links,
snapshot fidelity, working freshness, ledger integrity and CI non-shrink checks passed.
Gate-status found no completed CI run for the starting HEAD; full CI is not claimed.
The reported iteration-time percentages are estimates; measure one cycle before changing orchestration.

## Durable history

The full prior working state is preserved in
[the dated snapshot](archive/cleanup-2026-09-07/WORKING.md), including measurements and open forks.
[The ledger](DECISIONS_LEDGER.md), [playtests](playtests/), and [visual records](VISUAL_QUEUE.md)
retain source evidence. Do not execute completed instructions from the snapshot.
