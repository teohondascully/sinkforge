# Visual triage: making Sinkforge playable to look at

An evidence ledger, not a licence for a wholesale art rewrite, a new UI framework, or a threshold
reduction. It turns screenshot-level presentation complaints into a small number of falsifiable,
sequenced workstreams.

**Evidence basis.** A review on 2026-08-17 of two surface frames, called Frame A (normal surface play)
and Frame B (the sapling tutorial), alongside the priority and feel documents. The tracked captures
showing the same two states are `docs/media/baseline/_moment_boot.png` and
`docs/media/baseline/_moment_sapling.png`. The Noita frame used for comparison is a reference for visual
restraint and material hierarchy only. It is not a palette, rendering, animation or product target to
copy.

## Verdict

The surface frame reads more like a dense development sandbox than a coherent place. The miner, the
mountain silhouette and the idea of a grappling industrial descent still carry it, but three systems
consume that goodwill.

1. **Instructional chrome competes with the game.** Tutorials, labels, arrows, selection rings, item
   panels and rope guidance all want primary attention at once.
2. **Terrain describes texture before material.** Dirt, stone, deposits and shadow use similar small,
   high-contrast square variation, so the eye reads noise and camouflage before it reads earth, fracture,
   mass or excavation.
3. **The surface-to-subsoil transition changes visual grammar.** The grass lip is crisp, flat and
   tile-like; the earth below is diffuse and mottled. They do not yet read as layers of one physical
   world.

These are best solved through many narrow, screenshot-led tickets, because the frame needs iteration. The
four root workstreams exist to keep those tickets coherent, not to restrict their count. Each ticket
names its frame, one visual hypothesis, a before/after review, and a regression guard.

## Observed versus inferred

| Frame | Observed | Inference | Confidence |
|---|---|---|---|
| A | A selected-item panel, two `FORGE` labels and pointers, two circular interaction and selection marks, a high-contrast dashed grapple guide, and bright ore glints all compete in one shallow surface view. | The player has insufficient visual quiet to choose a natural focal point. Most helpers are styled as persistent screen furniture rather than transient state. | High |
| A | Earth, stone and dark underground cells repeat bright tan and grey squares at similar scale and contrast. The eye finds many isolated marks before it finds a broad dirt mass or a rock plane. | The terrain generator and renderer lack a material hierarchy. They apply texture as decoration rather than using texture to describe substance. | High |
| A | The grass line is a thin crisp green and brown strip while the cells immediately under it are much blurrier, darker and more varied. | The terrain layers are authored and rendered under incompatible edge, palette and pixel-scale rules. | High |
| A | The dashed line beside the active grapple and aim state is prominent from surface to player, independent of whether the player is reading a route or feeling tension. | The line reads as tool or debug geometry more than as a physical cable, and it likely reduces the satisfaction of a movement verb intended to be expressive. | Medium. A motion clip is needed to judge timing. |
| B | A three-line SAPLING tutorial panel obscures the player's immediate sky and world context, and the tree the lesson is about, while arrows, circles and machine labels remain visible beneath it. **This row said "screen-centred" until 2026-08-20; that half is withdrawn.** The bubble is world-anchored, not screen-anchored: `hint_anchor` is a world position pushed through the canvas transform rather than a canvas coordinate, and in the audited frame that position is the miner's head (`scenes/main.gd:826-841`). The draw only clamps it on-canvas so a body near a world edge still gets taught; it never places it (`scenes/hud.gd:700-701`). It *read* as centred here because the body was near screen centre. **The occlusion is the half that was genuinely observed and it is not withdrawn** — for whether it has since been treated, read the ticket rather than this row. | The tutorial system explains a mechanic while interrupting the verb it is meant to teach. It is a comprehension aid with a high attention cost. | High |
| Noita reference | The world holds most of the contrast and visual mass, the HUD is confined to corners, and terrain has a coherent dark silhouette with contained material variation. | Sinkforge should borrow its information discipline and value hierarchy, not its pixel density, palette, or destructive-pixel simulation. | High |

## Root workstreams

### V1: Guidance quietness and state hierarchy

**Problem.** The game presents teaching, selection, machine status, objective-like labels and movement
guides simultaneously. Their common visual language of bright outline, gold or white accent, black plate,
arrow and ring makes them all equally urgent.

**Design rule.** At any moment only one of these may be primary: an immediate player action, a newly
discovered object, or a genuine danger or failure. Everything else recedes, waits, or attaches to its
source in the world.

**Treatment sequence.**

1. Inventory every tutorial, ring, arrow, floating label and persistent screen panel by trigger,
   duration, dismissal condition and visual priority.
2. Establish four visual priority tiers:
   - *Critical:* immediate danger or interaction failure. May interrupt attention.
   - *Active:* the current targeted, held or attached object. Local, concise and stateful.
   - *Discoverable:* a new affordance. Appears once near its object, then fades or becomes contextual.
   - *Ambient:* learned or status information. Corner-bound, world-embedded, or hidden until requested.
3. Convert the SAPLING lesson first. It should be a source-bound one-line affordance beside the valid
   grass, not an explanatory panel riding over the body. *(This step read "not a centred explanatory
   panel" until 2026-08-20. The panel has never been screen-centred — see the withdrawal in the Frame B
   row above — and the step stands on its other half: bound to the ground it is about, rather than
   following the miner and covering the tree.)* Its full explanation belongs in an opt-in help surface if
   it is needed at all.
4. Suppress non-critical teaching while the player is moving quickly, aiming, swinging, or in the middle
   of an interaction. Resume only when they settle and the cue is still relevant.
5. Give helpers an expiry: the action demonstrated, relevance lost, explicit dismissal, or a short
   first-use timeout. Instructional art should not sit on screen because the player has not yet performed
   the exact desired action.

**Acceptance evidence.** Compare normal surface, active grapple, selected sapling, map-open and
first-machine frames. The game should retain a clear action target while no tutorial panel blocks the
player or the relevant terrain. `tools/check_hud_layout.gd` protects known collisions; captures decide
whether the hierarchy feels quiet.

**Out of scope.** Replacing every hint with a new icon system, removing critical feedback, or making
learning opaque in the name of cleanliness.

**Priority placement.** T2.1 follow-through, before any large art pass and before subjective opening
evaluations. It protects real desire measurement by stopping the UI from supplying a next action.

### V2: Terrain material grammar

**Problem.** The terrain communicates "many differently coloured squares" before it communicates what
each region is made of. Bright isolated cells create a spotted, camouflage read. In Frame A the dark
void-adjacent mass, the dirt, the stone and the mineral glints share enough frequency and contrast that
material identity collapses at a glance.

**Design rule.** Material hierarchy reads in this order: broad mass, then boundary or plane, then
material type, then local texture, then special or resource detail. If local texture is the first thing
noticed, it is too loud.

**First experiment: one cross-section, not a global repaint.** Take a controlled representative
surface-to-stone slice and produce A/B captures. Alter only the rule set for dirt, stone and their
contact:

- reduce isolated near-white and near-black single-cell accents in dirt;
- group variation into low-frequency clumps, seams, compaction bands or directional strata;
- reserve the strongest light accents for a small set of meaningful events: fresh fracture, ore glint,
  wetness, or lamp response;
- make dirt warmer and more horizontally layered and packed; make stone cooler, more planar and
  fractured, and less randomly speckled;
- preserve enough non-uniformity that the world does not become flat tiled wallpaper.

The test is not whether it has more grain. More undifferentiated grain is a rejected strategy. The test
is whether a player can name the material and infer its mass and edge before attending to decorative
variation.

**Acceptance evidence.** Review at 1× and normal play scale, in daylight and in underground light. Re-run
the existing rock and void legibility procedure for interiors (`tools/check_rock_reads.gd`,
`tools/check_room_reads.gd`); a beautiful cross-section that worsens route reading is rejected. Ask
independent reviewers to identify dirt, stone, ore, empty space and a recently mined edge without labels.

**Out of scope.** Hand-editing every block, increasing global brightness, adding global noise, or
shipping a new texture atlas before the rule works in the controlled slice.

**Priority placement.** A new T3 terrain-material-grammar item, immediately after T3.1's functional
interior readability treatment. It is a visible quality milestone, but it must not overtake T1.0 or T2.1.

### V3: Surface-to-subsoil continuity

**Problem.** The grass cap is a crisp thin platform and the dirt beneath it behaves as another rendering
language, so the surface looks composited over a noisy underground rather than supported by earth.

**Design rule.** The surface is the exposed upper boundary of the same ground that continues beneath it.
Grass, roots, loose earth, packed soil and stone should communicate depth and weathering without
requiring a separate tile aesthetic.

**Treatment sequence.**

1. Establish a shared palette and value bridge, so topsoil becomes a controlled first dirt stratum rather
   than a hard transition into unrelated noise.
2. Add a sparse, purposeful transition vocabulary of roots, compacted bands, small loose pockets or
   erosion marks, only where it serves the depth read.
3. Make cut faces and fresh excavations visually related to their source material, so a mined opening
   reads as removed mass rather than a black shape drawn over terrain.
4. Handle the grass-cap-on-shaft-floor defect separately. That is correctness debt, and it should not be
   hidden under an art treatment.

**Acceptance evidence.** A player should read, without a depth counter, where air begins, where topsoil
ends, and why the ground can support the structures above it. The cross-section must look intentional at
1×, 4× and normal camera scale.

**Priority placement.** Folded into V2's first experiment. No independent surface-art project until
terrain grammar proves it needs one.

### V4: Grapple visual language

**Problem.** The dashed grapple and aim guide is a very clear vector, but in Frame A it is high-contrast
and persistent enough to read as debug scaffolding. It is visually louder than the player and competes
with the world before the movement has become expressive.

**Design rule.** The rope communicates state and physical tension, not hidden targeting math. Its visual
intensity follows commitment: quiet while merely aiming, clearer while attached, strongest at tension,
release and collision.

**Experiment.** Capture the same movement sequence under three reversible treatments:

1. the current dashed guide;
2. a dim, short-range aim reticle, with a physical attached cable only after commitment;
3. a low-contrast aim arc or ghost, with cable opacity and slight tension response after attachment.

Review motion rather than a still, for target clarity, accidental-anchor prevention, player silhouette,
and the urge to swing again. The player must still be able to aim a fast grapple reliably.

**Acceptance evidence.** No guide is visible as persistent geometry when it is not helping an immediate
decision. Attached and loaded rope state is readable from its physical form, endpoint and motion. Grapple
control remains at least as reliable under direct play.

**Priority placement.** A new T3 grapple-visual-language item alongside T3.10 swing-release momentum. It
may run after V1 and V2, and it should not become an input-feel rewrite.

### V5: Bazaar and settings as an installed industrial interface

**Problem.** The Pack, Works, Bench and Settings frames are not merely oversized. They use a generic
stack of dark rounded cards, widely tracked uppercase labels, gold rectangular fills, floating resource
chips and large dead zones. The result reads as a presentation dashboard placed over the game rather than
part of a kinetic industrial world.

**Design rule.** The Bazaar should feel like an operated workbench or field terminal with a clear current
decision, rather than a slideshow of the whole catalogue. Settings should be a quiet utility surface, not
a second dashboard. The world remains context only where that context helps the decision, and must not
show through as competing scenery.

**Priority placement.** A menu-overhaul parent under T2.1, immediately after V1's tutorial quietness. It
may run in parallel with T3.1 because it is a contained UI pass, but it begins with a visual language and
information-architecture prototype rather than a piecemeal reskin.

## Candidate backlog, grouped under roots

Observations to preserve, not twenty independent implementation tickets.

| Symptom | Root | Severity | First investigation |
|---|---|---:|---|
| Lesson bubble prints over the world object its own lesson names (`UI-01`, **open, and re-scoped from evidence** — see the note below the table) | V1 | Frame-breaking | Read the number `capture_moments -- teach` now prints; then decide where a lesson may sit relative to its subject |
| Multiple arrows, rings and labels in one surface frame (**inventory taken 2026-08-23** — see the second note below the table; the count is structural and the tier assignment is a director call) | V1 | Frame-breaking | Inventory simultaneous helper states and assign priority tiers |

> ### `UI-01` was re-scoped on 2026-08-23, because two of its three claims were measurably wrong
>
> The row above used to read *"Multi-line tutorial panel over the body, occluding the thing it teaches"*,
> with a note withdrawing an earlier "screen-centred" reading. Captured on the current build, that
> description fails on its first two clauses and holds on the third, which is the worst way for a ticket
> to be wrong: the visible half is fixed, so a reader is sent to fix it again.
>
> - **"Multi-line" is stale.** The box was 250x52 at 11pt over a 230px wrap. It is 8pt over 176 with every
>   lesson rewritten to one line, and `check_hud_layout._check_lesson_footprint()` measures all of them
>   against a height ceiling with two controls. The capture the original claim was drawn from predates
>   `1c21996`, which shortened the text.
> - **"Over the body" is wrong.** The bubble draws ABOVE its anchor with the tail reaching down. On the
>   SAPLING lesson it sits above and left of the miner and the grass it names is completely unoccluded.
>   Its line references (`main.gd:826-841`, `hud.gd:700-701`) no longer point at the panel.
> - **"Occluding the thing it teaches" is RIGHT, and now has a number.** On the `teach` moment the lesson
>   reads *"THE LINE CAUGHT, it bent around the rock instead of through it"* and the bubble covers the
>   bend. Measured at the shutter over four consecutive runs: **1 of 1 pivots covered, 23.0 to 23.4 canvas
>   px inside the rect**, roughly a third of the bubble's height.
>
> **And the mechanism is a rule that already exists, applied to too small a population.** `main.gd`
> anchors a lesson at its SUBJECT CELL rather than at the miner's head when the lesson has a relevance
> gate, which is the same defect fixed once already for the planting lesson. `wrapped` has no gate, so it
> falls back to the head, and on a rope the head is beside the bend. The measurement prints `gate=none`
> for exactly this reason.
>
> **So the remaining work is a design call, not a refactor:** a lesson whose subject is a world object
> should point at that object, and the object here is a pivot rather than a cell. Where a lesson may sit
> relative to the world is the director's to decide, so the instrument reports the number and asserts
> nothing. Reproduce with
> `SF_MOMENT_DIR=<dir> godot --path . --script res://tools/capture_moments.gd -- teach`.
>
> This also has no home in `check_hud_layout`, and that is not an oversight in the layer. It compares HUD
> rectangles against HUD rectangles; every rope is drawn in world space. The same wall stopped the zone
> ceremony's rope half, where it was recorded as *"not a missing state, a missing plane"*.

> ### The helper inventory, taken 2026-08-23 — and the registry that already exists is total over the wrong population
>
> `docs/PRIORITY.md:1317` gates `UI-09`–`UI-15` on "a helper inventory", and the row above names it as the
> first investigation. **Most of it already existed and nobody had said so.** `Hud.HELPER_TAGS` classifies
> every drawing surface as `critical` / `active` / `discoverable` / `ambient` / `internal`, the `critical`
> tag carries a one-at-a-time rule, and `check_hud_layout._check_helper_registry()` asserts the table
> against the live method list in BOTH directions, so a surface added without a tag fails rather than
> becoming the eighth thing on the screen. Measured on tonight's sweep:
>
>     helpers: critical 4 · active 3 · discoverable 6 · ambient 5 · internal 12
>     PASS: the HUD reports 30 _draw* methods to classify
>
> **The gap is the population, not the rule.** The registry is built by walking `_main._hud` and every
> object it transitively holds that is `RefCounted` and script-backed. `WorldRenderer` is a Node held by
> `MainView`, so it is excluded twice over — and so is everything it in turn holds.
>
> **The population partitions exactly, which is why these numbers can be re-measured rather than trusted.**
> The rule: distinct `_draw*` names matching `^\s*(static\s+)?func\s+_draw`, over the tracked `.gd` files
> that declare any. Fourteen files do.
>
> | | files | distinct `_draw*` names |
> |---|---:|---:|
> | reachable from the Hud, and classified | 5 — `hud`, `bazaar_page`, `settings_page`, `bazaar_bench`, `bazaar_surface` | **30** |
> | the world plane, and classified by nothing | 9 — `world_renderer`, `machine_view`, `rope_view`, `terrain_painter`, `water_view`, `bazaars`, `player`, `light_layer`, `falling_items` | **58** |
>
> The five-file count of 30 **reproduces the registry's own measured 30 exactly**, and every name in
> `HELPER_TAGS` is declared in one of those five, so the partition is checked rather than assumed. The only
> name the two sides share is `_draw` itself, which is Godot's dispatch and a collision rather than a
> shared surface. **So the registry classifies 30 of 88 drawing surfaces and asserts, of all of them, that
> "every drawing surface is classified".** This is the missing plane
> `UI-01` and the ceremony's rope half both hit, arrived at from the third direction: not a missing state,
> not a missing measurement, a **missing half of the register**.
>
> **AND THE WORLD PLANE IS NOT UNGOVERNED — IT HAS ITS OWN, SEPARATE RULE.** `machine_view.gd` packs its
> name plates onto shelves (`_label_plan`, `LABEL_SHELVES`) and drops any plate that would overlap a
> neighbour's, which is a layout system with a collision policy. It simply is not `HELPER_TAGS`, knows
> nothing of it, and is known by nothing. Two independent layout authorities over one screen, neither aware
> the other exists, is a better description of this ticket than "no rule".
>
> **The guidance surfaces outside the registry, with the cardinality each can reach.** Twelve of the 58 are
> guidance rather than world content; that split is a judgement and is mine, and the remaining forty-six
> are terrain, décor and effects, for which the registry's vocabulary has no tag at all.
>
> | surface | plane | how many at once | live when |
> |---|---|---|---|
> | `_draw_dig_marks` | marks | **0..N**, view-culled only | any marked cell is on screen |
> | `_draw_scan` echoes | world | **0..N**, one ring + diamond + pip each | for `SCAN_ECHO_LINGER` after a sonar pulse |
> | `_draw_scan` front | world | 0..1, two concentric arcs | while the pulse still travels |
> | `_draw_guide_targets` | marks | **0..1** | the current objective has a spatial step |
> | `_draw_ping` | marks | 0..1, ring + bobbing pin | a map-click beacon is set |
> | `_draw_aim` reticle | world | 0..1 | the cursor is on an in-bounds cell |
> | `_draw_interact_pulse` | world | 0..1 | the cursor is on a rich vein or a machine |
> | one of four `*_preview` | world | 0..1 | build mode; `_ghost_def.behavior` holds one value |
> | `_draw_machine_label` | machines | **0..N**, shelf-packed, overlaps dropped | one per visible machine that wins a shelf |
> | `_draw_machine_status` | machines | **0..N** | one per visible machine |
> | `_draw_machine_io` | machines | **0..N** | one per visible machine; its own comment calls it cosmetic |
> | `_draw_load_gauge` | machines | **0..N** | one per visible machine |
>
> **Six of those are unbounded, and they include the two the symptom names.** Dig marks draw one bracketed cell
> per mark with no cap beyond the view rect, and each scan echo draws its own expanding ring. "Multiple
> arrows, rings and labels in one surface frame" is therefore **structural rather than a defect**: it is
> what the build is specified to do, and no rule anywhere says how much of it may happen at once.
>
> **What is NOT the cause, checked and cleared.** `_draw_guide_targets` loops, which reads like the obvious
> culprit. It cannot be: `MainView._guide_targets()` matches on a single `_objectives.current_id()` and
> every branch does exactly one `out.append(...)`, so the array holds **0 or 1** and the chevron cannot
> multiply. The plural loop is the shape of the code, not the shape of the screen.
>
> **The arithmetic the ticket was reaching for.** A player mid-build with marks down, shortly after a scan,
> standing on an objective step, cursor on a machine, in sight of a drill/forge stack, can hold: N dig-mark
> brackets, M echo rings, a travelling front, a chevron on a tether over a washed cell, a reticle, an
> interact pulse, a build ghost, and per visible machine a name plate, a status bubble, IO ports and a load
> gauge — and then, across the HUD plane, governed by a rule that does not know any of the above exists, an
> objective line, a hover panel and one `critical` interrupt. **The one-at-a-time rule caps the last of
> those at one and says nothing about the rest.**
>
> **Proposed tiers, and this half is a director call rather than a finding.** The existing vocabulary
> extends to the world plane without new words: `_draw_guide_targets` and `_draw_ping` are `critical` (each
> is a summons that expects to be answered), `_draw_aim`, `_draw_interact_pulse` and the previews are
> `active` (they describe what is under your hand this instant, and already cannot coexist), and
> `_draw_dig_marks` and the scan echoes are `ambient` (state you read at a glance) — which, if adopted,
> would put **two `critical` surfaces on screen together**, the chevron and the ping, in flat breach of the
> rule the HUD half already enforces. That collision is the reason the tiers are proposed here and not
> committed: extending the registry is a five-line change, and deciding what happens when it immediately
> goes red is the design question the ticket actually contains.

| `FORGE` labels and pointers read as duplicated UI (**investigated 2026-08-23** — two of its three remedies already shipped; see the third note below the table) | V1 | Play-disrupting | Determine which state each communicates; collapse redundant state or bind it to object proximity |
| Selected-item panel competes with the active action (**investigated 2026-08-23** — not occlusion, measured; the salience reading survives as a prototype call) | V1 | Play-disrupting | Compare persistent versus action-only display in capture |
| Dashed grapple guide reads as debug geometry | V4 | Play-disrupting | Three-state motion comparison |
| Dirt has isolated pale and brown blocks | V2 | Frame-breaking | Measure accent density; test clustered low-frequency variation |
| Stone, dirt and deposit share texture frequency | V2 | Frame-breaking | Define per-material silhouette, palette and variation rules |
| Bright glints read as noise before resource | V2 | Play-disrupting | Reserve high-value accents for resource and event semantics |
| Grass lip and dirt below use incompatible pixel grammar | V3 | Frame-breaking | Controlled cross-section A/B |
| Underground darkness masks mass while texture persists | T3.1 with V2 | Functional | Interior readability treatment before art polish |
| Cavities read as cut-out black rather than excavated volume | V2 and V3 | Play-disrupting | Compare fresh-cut face and background-plane treatment |
| Tree, ruin and surface structures feel tile-adjacent | T3.11 | Craft debt | Revisit only after the ground is coherent |
| Machine labels and status are more vivid than the machines (**measured 2026-08-23** — four standing marks exceed the file's own `CHROME` ceiling; see the note below the table) | V1 with T3.2 | Play-disrupting | Give hardware state a visible world expression before adding more chrome |
| The screen is busy even in an idle moment (**criterion specified 2026-08-23** — the duty period is 62.83s, so a one-frame criterion cannot work; see the note below the table) | V1 | Frame-breaking | Create a quiet-frame capture criterion |
| Player silhouette is not the default focal point (**measured 2026-08-23** — true on the surface at 0.18% of the top decile, FALSE underground at 5.11%; see the last note below the table) | V1, V2, V4 | Play-disrupting | Eye-path review of normal surface and underground frames |

> ### The silhouette row, measured 2026-08-23 — true on the surface, and the opposite underground
>
> The stated investigation is an eye-path review of surface and underground frames. Both frames existed
> already, from captures taken for other rows. The instrument is the one the vividness note above
> established: luma, and specifically **what share of a frame's brightest 0.1% of pixels lands on each
> subject.** Boxes were placed by hand and every one was cropped and looked at before its number was used.
>
> **SURFACE** (`_moment_line.png`; frame mean 66, p99.9 threshold luma 239, 2837 pixels above it):
>
> | subject | box mean | px in the frame's top 0.1% | share |
> |---|---:|---:|---:|
> | the **miner** | 64 | **5** | **0.18%** |
> | one **Drill**, a single cell | 198 | 464 | **16.36%** |
> | the **Bazaar awning** | 172 | 1406 | **49.56%** |
>
> **A one-cell machine takes ninety-one times the miner's share of the frame's brightest pixels, and the
> market awning alone takes half of them.** Background-free samples put the miner's torso at luma **32**
> against a sky of **98** — the player is a dark shape, and the darkest significant object in a frame
> containing his own factory.
>
> **UNDERGROUND** (`_moment_fall_plate.png`; frame mean 23, p99.9 threshold 222, 2132 pixels above it): the
> miner holds **109 of them, 5.11%** — **twenty-nine times his surface share.**
>
> ### The mechanism, and it decides the remedy
>
> **The miner's own emission is the same in both frames.** Torso 32 on the surface and 33 underground; hard
> hat 107 and 101. He did not get brighter. What changed is what he is standing in front of: sky at 98 and
> an awning at 172 become rock at 14.
>
> So the row is **half right, and the half it gets wrong is the important one.** It names surface and
> underground together, and underground the player already is the focal point — dominating his surround
> (33 against 14) and carrying a lamp glow besides.
>
> > **Therefore the remedy is subtraction on the surface, not a brighter miner.** Brightening him is the
> > obvious reading of "not the default focal point" and it would break the frame where he currently works.
> > This is the same conclusion `T2.1` reaches from a different direction, and it is the reason that ticket
> > is written as a subtraction pass rather than an emphasis pass.
>
> **What this does not measure.** Two frames, one apiece, both from moments built for other rows. Luma
> only: no saturation, no motion, no colour opponency. And brightness dominance is one axis of attention,
> not attention itself — on the other obvious axis, local contrast, the miner does well in BOTH frames (32
> against a 98 sky, 33 against 14 rock), which is why he reads as a legible silhouette while still not
> being what the eye goes to first. The row conflates those two axes and the measurement separates them.
> Whether the Bazaar is entitled to its half of the top decile — it is a destination, and destinations may
> earn salience — is a design question this cannot answer.

> ### "More vivid than the machines", measured 2026-08-23 — against the project's own rule rather than against taste
>
> The row's remedy is a design call, but its DIAGNOSIS is a number and nobody had taken it. It can be taken
> without any aesthetic judgement at all, because `world_renderer.gd` already states the rule:
>
> > *Pure white is the brightest mark this screen can make and there is exactly one of it, so it is spent on
> > the rarest thing: something that has just happened, at the moment it happens. Chrome is what the player
> > looks through rather than at, and it has no moment: the cursor, the build ghost's border, guidance. It
> > is allowed to be bright, and it is not allowed to be white.*
> >
> >     const CHROME := Color(0.78, 0.83, 0.92)      # luma 0.8253, or 210/255
>
> **So "too vivid" has a definition here: a STANDING mark brighter than CHROME.** The audit rule, so it can
> be re-run: every `Color(r, g, b)` literal with all channels ≤ 1.0, in the nine world-plane files, scored
> by Rec.601 luma. **Forty come out above CHROME.** Most are entitled to: sparks, glints, mine cracks,
> crumble, scan returns and speed streaks are events, and `LAMP_COLOR`, torch pools and the light-layer
> gradients are light sources rather than marks. Sorting them into event / light / standing is a judgement
> and it is mine.
>
> **Four standing marks are left, and one of them is the control.**
>
> | site | luma | how far CHROME → white | delta from CHROME |
> |---|---:|---:|---|
> | `machine_view.gd:538` nameplate text | 229 | **+41.1%** | `(+0.08, +0.07, +0.06)` |
> | `rope_view.gd:148` `AIM_MARK`, the grapple aim ring | 223 | **+29.3%** | `(+0.21, +0.05, −0.36)` |
> | `machine_view.gd:560` `out_col`, "neutral routes" | 217 | **+14.8%** | `(+0.02, +0.03, +0.02)` |
> | `machine_view.gd:259` held-count badge | 210 | 0.0% | exact — it takes the constant |
>
> **The deltas separate two different faults, and the badge proves the rule is followable.** The badge takes
> `WorldRenderer.CHROME` and carries a comment defending the choice: *"a count is a standing quantity rather
> than something that just happened, and it sits on its own near-black plate, so it keeps every bit of its
> contrast at the lower value."* **That argument applies word for word to the nameplate three hundred lines
> later, which sits on its own near-black plate and does not take the constant.**
>
> The nameplate and `out_col` are not independent colour choices. Both are **near-uniform positive offsets**
> from CHROME — `(+0.08, +0.07, +0.06)` and `(+0.02, +0.03, +0.02)` — which is the signature of a value
> typed from memory rather than chosen. The constant's own docstring anticipates exactly this: *"One constant
> rather than a palette, because the sites that take it differ only in alpha."* These two differ in more
> than alpha, by hand, in the brighter direction both times.
>
> `AIM_MARK` is the other kind. Its delta is not uniform — it is a warm amber, a deliberate hue away from
> chrome's cool. So it is a real decision, and only its LUMA is in question.
>
> ### And this hands `GR-06` a lever it did not have
>
> `AIM_MARK` is drawn at `rope_view.gd:208` as the ring on the hook target, which is inside what `GR-06`
> measures. That red is logged as settled-measurement-awaiting-a-design-call, with *"next experiment: none"*
> and two options: the aim mark is too loud, or the pairing is wrong. **The first option is no longer a
> matter of taste.** A standing mark at 223 against a stated ceiling of 210 is out of contract with a rule
> the file already carries, so quietening it is a change the codebase licenses rather than one somebody has
> to defend.
>
> The minimal form, if that is the call: hold the hue and scale to CHROME's luma, `Color(0.99, 0.88, 0.56)`
> → `Color(0.93, 0.83, 0.53)`, a factor of 0.9417. Taking it to CHROME outright is a hue decision and a
> larger one. **Neither is taken here** — the aim mark is director-owned and this only narrows it.
>
> **CORRECTION TO THE PARAGRAPH ABOVE, AND IT NAMES A BETTER TICKET.** This was first written against
> `GR-06`, which is the assertion in `check_grapple_reads`. **`GR-04` is the ticket that already localised
> the ring**, and its statement in that file's own header is:
>
> > *"REPRODUCES, and it is the endpoint MARK rather than the lead: the same preview adds ~15 levels of edge
> > on dark rock and its ring alone carries ~208 against open sky. Reported, never asserted: how loud an aim
> > mark should be is a design call."*
>
> So the ring was identified before this note existed, by a different route, and the contribution here is
> narrower than first claimed: not *which* mark is loud, which `GR-04` already had, but that the mark is
> **out of contract with a ceiling its own repository states**, which turns "how loud should it be" from an
> open question into a bounded one.
>
> **The two are convergent because they measure different quantities, and that is the only reason the
> convergence counts.** `GR-04` measures rendered edge gradient against a photographed sky; this measures
> the authored colour literal against a named constant. Two instruments agreeing on a shared number would
> be worth little; two unrelated quantities pointing at the same object is evidence about the object.
>
> For the nameplate and `out_col` the change is smaller than a decision: take the constant. That is what it
> is for, and the badge beside them already does.

> ### The quiet-frame capture criterion, specified 2026-08-23 — and the first thing it has to say is that a quiet frame is not a frame
>
> The row asks for a criterion, so this is a criterion rather than a fix. The finding that shapes it came
> out of counting, and it is the reason a single capture cannot serve.
>
> **The idle frame is driven by fourteen distinct oscillators, and its composite duty period is 62.83
> seconds.** The rule, so the number is re-measurable: distinct multipliers in `sin`/`cos` calls taken on
> `_anim_time`, across `world_renderer.gd` (13), `machine_view.gd` (3, two shared) and `rope_view.gd` (1).
>
>     0.7  0.9  1.4  1.6  1.8  2.2  2.6  3.0  4.0  6.5  9.0  11.0  23.0  27.0   rad/s
>
> Every one is a multiple of 0.1 rad/s, so the fundamental is 0.1 and the composite repeats every
> **2π/0.1 = 62.83 s, or 3770 frames at 60Hz**. The fastest cue is the lamp's 27.0 at a 0.233 s period; the
> slowest is a 0.7 shimmer at 8.98 s. **A one-frame capture criterion samples one of 3770 phases.**
>
> **And it is worse than fourteen, because most of them carry a per-element phase term.** `+ float(cx) *
> 0.35` on the seal breath, `+ float(c.x) * 1.3` on the sapling sway, `+ float(seam["pos"].x) * 0.02` on
> the seam, `+ float(tc.x) * 1.7` and `+ float(tc.y)` on the torch gutter, `+ float(c.x) * 0.6 + float(c.y)
> * 0.4` on the rock breath, `+ float(col) * 1.3` on the column shimmer. The offsets do not change the
> period, they change the phase — so this is not fourteen things breathing together, it is **one phase per
> drawn cell**. "Busy in an idle moment" is not an accident of tuning; it is the shape of the field.
>
> **The grain is outside the period entirely.** `post_fx.gdshader` re-seeds on `fract(TIME * 0.96)`, a
> 1.042 s cycle on the shader built-in that no GDScript pose reaches. 62.83 / 1.042 = 60.32, not an
> integer, so with grain included the frame state **never exactly repeats**.
>
> ### The criterion
>
> **A quiet frame is a statistic over a posed duty period, in three parts.** Only the third is new, and the
> third is the one the symptom is actually about.
>
> | part | what it bounds | instrument |
> |---|---|---|
> | **static coverage** | share of canvas under HUD panels | EXISTS — `check_hud_layout`'s footprint report; the bare screen measures 7.84% against a ratchet of 8.00%. Read its stated limit: `panel_probe` sees panels, not loose glyphs, so it is a LOWER bound |
> | **live attention surfaces** | how many things are asking | PARTLY EXISTS — `HELPER_TAGS` gives the tags and the one-`critical`-at-a-time rule, but classifies 30 of 88 surfaces (see the helper-inventory note above), so the world plane must be enumerated before this part can be stated at all |
> | **animated fraction** | share of pixels that MOVE over the duty period | **DOES NOT EXIST.** This is the part to build |
>
> **How the third part must be measured, because two of this repo's standing traps sit directly on it.**
>
> - **Pose both clocks, and pose them by SETTING rather than waiting.** `WorldRenderer.ANIM_FROZEN` holds
>   `_anim_time`; only `Engine.time_scale = 0.0` reaches the shader grain. Waiting out a 62.83 s duty
>   period is not available to a test, and waiting would advance the sim as well, so the phase has to be
>   assigned: set `_anim_time` to each sample point and capture.
> - **Sample above Nyquist for the FASTEST cue, not the slowest.** 27.0 rad/s is 4.297 Hz, so the duty
>   period needs **at least 540 samples**. Undersampling does not merely miss the lamp flicker: it folds it
>   into a low frequency and reports a slow, wide shimmer that is not there.
> - **Count changed pixels above a floor, and keep the diff map.** A mean delta reads a crushed cue as an
>   absent one, and captures on this project differ run-to-run by enough that a bare difference is not
>   evidence. The floor has to come from a subject-removed run rather than from zero.
>
> **Not built here.** The harness workstream is frozen and this is a new instrument rather than a repair,
> so it wants a director-approved priority ID. What is settled and does not need re-deriving is the shape:
> 62.83 s, 540 samples, both clocks posed, changed-pixel count with a measured floor.

> ### The `FORGE` labels row, investigated 2026-08-23 — two thirds of its remedy already shipped, and the third is somewhere else
>
> The row's first investigation reads *"determine which state each communicates; collapse redundant state or
> bind it to object proximity."* **Both of those are done, and were done before this ticket was read.**
>
> - **Bound to proximity.** `MachineView._label_visible()` gates the nameplate on
>   `LABEL_NEAR_CELLS = MainView.REACH_CELLS * 2.0`, derived rather than picked. Its own comment records the
>   symptom this row describes and records fixing it: the plate used to ride a pure zoom gate that was true
>   for every machine on screen from the first frame, so *"a base of any size wore a permanent band of text
>   across it."*
> - **Redundant state collapsed.** `_draw_machine_status()` returns early on `_guided(machine.cell)`,
>   because a machine already wearing a guidance chevron does not also need a need-bubble bobbing in the
>   same column *"saying a version of the same sentence."*
>
> **What survives is one duplication, and it is measured rather than argued.** Posing the pointer at a
> machine after the drill/forge line runs reports, at the shutter:
>
>     aim=(56, 21) machine=true reach=true hover_empty=false label_visible=true name=Drill
>
> Both name it, in the same frame, in two planes: a world plate reading `DRILL` over the casing, and the HUD
> inspector reading `Drill` in the corner. They are not merely coincident — **they fire on the same event.**
> `_label_visible()` returns true unconditionally when `cell == _aim`, and `HoverInfo.describe()` returns
> `{}` only when the cell is unreachable, so pointing at any machine you can act on raises both. And reach
> (3.2 cells) sits inside label-near (6.4), so at any zoom past `TEXT_ZOOM` the plate was already up for
> proximity before the aim exemption did anything.
>
> That exemption is justified in place as the case where *"a plate too small to read is still better than no
> answer."* For a machine in reach the premise is false: there is another answer, in the corner, at 13pt.
>
> ### AND THE CAPTURE FOUND SOMETHING THE ROW IS NOT ABOUT — the inspector prints over the ceremony
>
> The same frame shows the machine inspector overlapping the stratum arrival plate, clipping `THE LINE RUNS`
> and `IT WORKS WITHOUT YOU`. Unlike `UI-01`, this is **not** a missing plane: both surfaces register into
> `panel_probe` and both are inside `check_hud_layout`'s population. It is a missing ROW. The matrix poses
> fifteen states and pairs the arrival with the corner map, the big map and pause, and pairs the hover with
> fast-forward and the big map — **and never pairs those two with each other.**
>
> Posed temporarily as `"a stratum arrival WITH a machine hovered"`, the layer convicts itself on the first
> run:
>
>     FAIL: a stratum arrival WITH a machine hovered: no two panels collide —
>       [P: (410.0, 44.0), S: (218.0, 50.0)] x [P: (209.1, 61.55), S: (221.8, 50.0)]  (overlap 21x32)
>
> **21x32 canvas px, and that is the floor rather than the figure.** The posed inspector is at
> `HOVER_MIN_W` = 218; the photographed one carries `factory makes 53.1 ore/min` and is wider, so its left
> edge sits further into the plate. The row was reverted rather than committed, because a red whose fix is a
> design call should not be added before the call is made.
>
> **The fix has a precedent already in the file, which is why it is worth naming.** `_draw_hover()` ALREADY
> stands down for `minimap_large` and for `_modal_open()`, on the stated rule that *"the big map is the
> screen."* A ceremony is the screen too, for `ARRIVAL_HOLD` = 3.4s. `HELPER_TAGS` independently agrees:
> the arrival is `critical` and the inspector is `active`, and the registry's own vocabulary says an
> interrupt that *"arrives on its own schedule and expects to be read now"* outranks a surface describing
> what is under your hand. **Three separate parts of the codebase already imply the answer and none of them
> is wired to the others** — which is the same sentence as the helper-inventory note above.
>
> Suppressing a live inspector for 3.4s is still a change to what the player sees, so it is queued rather
> than taken: fix first, then the matrix row, so the row lands green instead of reddening `main`.
>
> **A SECOND ceremony collision was predicted from the same camera constants and it is REFUTED.** If the
> look-ahead can push the body down the frame, it can push it up the frame too, and a body falling past a
> stratum line would then be behind the plate announcing it. The arithmetic said so: a terminal-velocity
> fall with residual stride gives 162 world px of lead, 81 canvas px, which lands the body at canvas y ~99
> inside a band of 61.6..111.6.
>
> **It does not happen, and the reason is the term the arithmetic left out.** Measured over a real
> fifteen-row plunge with the plate up at full alpha, sampling every frame: the body's canvas y ranged
> **161.0 to 184.4**, never within fifty pixels of the band's bottom edge at 110.3. The follow lag opposes
> the look-ahead, and against a fall the two nearly cancel — at v=480 the body sat at 179, at v=525 it sat
> at 179, both within a pixel of dead centre. The minimum of 161 was not reached while falling at all: it
> came a frame after the body STOPPED, when the eased lead had not yet decayed.
>
> The ceremony ticket therefore does **not** gain a second collision, and `HOVER-CEREMONY` stands alone.

> ### The selected-item row, investigated 2026-08-23 — the geometric reading is cleanly negative, with the margin stated
>
> The row's first investigation is *"compare persistent versus action-only display in capture"*, which
> presumes the competition is worth prototyping against. There are two readings of "competes with the active
> action" and only one of them is answerable without a design call, so it was answered first: **does the
> hotbar cover the place where actions happen?**
>
> **It does not, and the margin is about thirty-four canvas pixels.** Everything here is a constant. *(This
> read "about eleven" when first written on 2026-08-23 and the figure was corrected the same day — see the
> camera-model note below. The conclusion did not change; the margin got larger.)*
>
> | quantity | value | source |
> |---|---|---|
> | hotbar band | canvas y **295..339** | `HOTBAR_BAND_TOP` = 360 − 28 − `SLOT` 30 − 7; `HOTBAR_BAND_H` = 44 |
> | world → canvas | **0.5** at zoom 1.00 | 40 cells x `CELL` 32 = 1280 world px across a 1280px viewport, halved into a 640px canvas |
> | reach | **51.2 canvas px** | `REACH_CELLS` 3.2 x 16 canvas px per cell |
> | worst body offset | **+30.1 canvas px** below centre | a full-stride jump: lead 105.8 world px MINUS the follow trail 45.6, halved into canvas px |
>
> So the bottom of the reachable disc reaches canvas **261.3** against a band beginning at **295**.
>
> **THE CAMERA MODEL, because the first version of this table used only half of it.** The camera lerps
> toward `body + lead` at `CAMERA_FOLLOW_SPEED` 8/s, and a lerp chasing a moving target sits a steady
> `v / k` behind it. So the camera settles at
>
>     camera = body + lead - v / CAMERA_FOLLOW_SPEED
>
> and the two terms **oppose each other**: the look-ahead pushes the camera along the motion, the follow lag
> holds it back. Using the lead alone put the worst jump offset at 52.9 canvas px and the margin at 11. With
> the trail it is 30.1 and 34. The error was conservative — it overstated the risk — but it was an error,
> and it came from reading one line of `_process` and not the line under it.
>
> **The model is not asserted, it is checked against a measurement that was taken to refute something
> else.** Over a real fifteen-row plunge down a generated shaft, sampled every frame, the body's canvas y
> ranged **161.0 to 184.4** with velocity reaching 525 of a `MAX_FALL` 560. The model predicts **162.6** at
> terminal velocity. Measured 161.0, predicted 162.6, and the two were arrived at independently.
>
> **The camera look-ahead is the whole reason this needed computing rather than asserting**, and it nearly
> produced the opposite answer. `T2.1` states that "the camera centres the body, so the miner sits at canvas
> (320, 180)", and on that premise the disc bottom is 231.2 and the margin is 64px — comfortable, and wrong.
> The camera does not centre the body: it leads by `_cam_lead`, and the lead is **subtracted** from the
> body's screen position, so **upward** motion pushes the body DOWN the frame, toward the bar. Falling does
> the opposite and is never the risky direction. At the `CAMERA_LEAD_MAX` cap of 170 world px the disc would
> reach 316.2 and overlap by 21px — the cap is simply not reachable, because it needs about 909 px/s of pure
> vertical and the fastest upward motion the build has is `SWING_MAX_SPEED` 420 and `JUMP_VELOCITY` 365.
>
> Two things make the real margin larger than the eleven above, and neither is relied on: the lead is eased
> at `CAMERA_LEAD_EASE` 5/s so it never attains its steady-state value before gravity bleeds the climb, and
> `stride` decays in the air, so the 1.55 multiplier is already falling by the time the body is high. Zoom
> only helps: 1.00 is the largest in `ZOOM_LEVELS`, and every other level shrinks the disc in canvas px. The
> bar widens with the pack but never grows taller, so a fuller pack cannot change the answer.
>
> **What survives is the other reading, and it is a design call.** "Competes" as *salience* — a lit,
> saturated, permanently-present bar drawing the eye away from the work — is untouched by any of the above,
> and it is what the row's own stated investigation is really asking for. That comparison needs the
> persistent and action-only builds captured side by side, which is a prototype rather than a measurement.
> Queued as such. **The value of the negative is that it removes the cheaper explanation**: if the bar reads
> as competing, it is not because it is in the way.

## Milestones

### 1: Quiet enough to play

Complete V1's first-use and tutorial hierarchy pass. Deliver before/after captures of the sapling
interaction, normal surface movement, a grapple, map-open, and the first machine. This is a
high-visibility improvement and the correct next presentation milestone after repository cleanup.

### 2: Ground with a material identity

After T3.1 resolves the functional interior rock problem, run V2 and V3's controlled cross-section
experiment. Ship only a rule that improves or preserves legibility in the same captures. This is the
first broad visual quality milestone, and it should make screenshots feel authored rather than
procedurally speckled.

### 3: A kinetic tool, not a targeting overlay

Run V4 in motion alongside T3.10. Ship a grapple state language only if direct movement remains reliable.
This supports the game's remembered image: a miner moving through an industrial world, rather than a
cursor operating a physics toy.

## Review protocol

For every selected visual change:

1. State the hypothesis before producing pixels.
2. Capture the same named moment, seed and camera before and after. Never overwrite canonical evidence.
3. Review at normal play scale first, then 1× and 4×.
4. Separate functional legibility checks from subjective craft judgement.
5. Test one root rule at a time. No multi-system polish commit.
6. Keep a rejected-treatment record with the reason it failed. Reverting a bad visual hypothesis counts
   as a result.
7. Do not promote a screenshot improvement to a gameplay claim without a play-test behind it.

## What not to copy from Noita

- Not its palette, pixel scale, UI layout, silhouette style, procedural material simulation, or tone.
- Not its darkness, applied to the surface simply because Noita is darker.
- Not granular simulation as a stand-in for material communication. Sinkforge needs readable planned
  construction and tunnelling, not visual chaos.

Borrow only the discipline: quiet information hierarchy, world-first composition, material-specific value
language, and confidence in leaving much of the screen visually calm.

## Integration with the priority queue

Add one parent priority entry at a time, after consulting this ledger:

1. extend T2.1 with V1 guidance quietness;
2. retain T3.1 as the functional underground prerequisite;
3. add one T3 terrain-material-grammar parent item covering V2 and V3;
4. add one T3 grapple-visual-language parent item alongside T3.10.

This file is the evidence-rich granular queue, kept separate from the small decision queue and milestone
map. Many independent tickets may run in parallel out of a selected workstream, but only one
milestone-level parent occupies the active priority table at a time.
