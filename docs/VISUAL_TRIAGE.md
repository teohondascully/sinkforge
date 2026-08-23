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
> `MainView`, so it is excluded twice over. `scenes/world_renderer.gd` declares **thirty more `_draw*`
> methods and not one of them is classified**, and an assertion that prints *"every drawing surface is
> classified"* over a population containing none of them. The two thirties are a coincidence and not a
> comparison: the registry's is counted from the live object graph across the Hud AND its pages, where
> `scenes/hud.gd` alone declares 23; the world plane's is counted from one file's declarations. This is the missing plane
> `UI-01` and the ceremony's rope half both hit, arrived at from the third direction: not a missing state,
> not a missing measurement, a **missing half of the register**.
>
> **The guidance surfaces that live outside it, with the cardinality each can reach.** Eight of the thirty
> are guidance rather than world content; that split is a judgement and is mine, and the remaining
> twenty-two are terrain, décor and effects, for which the registry's vocabulary has no tag at all.
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
>
> **Two of those are unbounded, and they are the two the symptom names.** Dig marks draw one bracketed cell
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
> standing on an objective step, cursor on a machine, can hold: N dig-mark brackets, M echo rings, a
> travelling front, a chevron on a tether over a washed cell, a reticle, an interact pulse, a build ghost,
> and — across the HUD plane, governed by a rule that does not know the above exists — an objective line, a
> hover panel and one `critical` interrupt. **The one-at-a-time rule caps the last of those at one and says
> nothing about the other ten.**
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

| `FORGE` labels and pointers read as duplicated UI | V1 | Play-disrupting | Determine which state each communicates; collapse redundant state or bind it to object proximity |
| Selected-item panel competes with the active action | V1 | Play-disrupting | Compare persistent versus action-only display in capture |
| Dashed grapple guide reads as debug geometry | V4 | Play-disrupting | Three-state motion comparison |
| Dirt has isolated pale and brown blocks | V2 | Frame-breaking | Measure accent density; test clustered low-frequency variation |
| Stone, dirt and deposit share texture frequency | V2 | Frame-breaking | Define per-material silhouette, palette and variation rules |
| Bright glints read as noise before resource | V2 | Play-disrupting | Reserve high-value accents for resource and event semantics |
| Grass lip and dirt below use incompatible pixel grammar | V3 | Frame-breaking | Controlled cross-section A/B |
| Underground darkness masks mass while texture persists | T3.1 with V2 | Functional | Interior readability treatment before art polish |
| Cavities read as cut-out black rather than excavated volume | V2 and V3 | Play-disrupting | Compare fresh-cut face and background-plane treatment |
| Tree, ruin and surface structures feel tile-adjacent | T3.11 | Craft debt | Revisit only after the ground is coherent |
| Machine labels and status are more vivid than the machines | V1 with T3.2 | Play-disrupting | Give hardware state a visible world expression before adding more chrome |
| The screen is busy even in an idle moment | V1 | Frame-breaking | Create a quiet-frame capture criterion |
| Player silhouette is not the default focal point | V1, V2, V4 | Play-disrupting | Eye-path review of normal surface and underground frames |

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
