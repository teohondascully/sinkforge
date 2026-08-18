# Visual triage — making SINKFORGE playable to look at

**Status:** recommendation and evidence ledger. This document is not permission for a wholesale art
rewrite, a new UI framework, or a threshold reduction. It turns screenshot-level presentation complaints
into a small number of falsifiable, sequenced workstreams.

**Evidence basis:** a read of the supplied surface frames on 2026-08-17 (called **Frame A**: normal
surface play and **Frame B**: sapling tutorial), alongside the current priority and feel documents. The
Noita frame supplied for comparison is a reference for visual restraint and material hierarchy only—not a
palette, rendering, animation, or product target to copy.

## Executive verdict

The current surface frame reads more like a dense development sandbox than a coherent place. The miner,
mountain silhouette, and idea of a grappling industrial descent still carry it, but three systems consume
that goodwill:

1. **Instructional chrome competes with the game.** Tutorials, labels, arrows, selection rings, item
   panels, and rope guidance all want primary attention at once.
2. **Terrain describes texture before material.** Dirt, stone, deposits, and shadow use similar small,
   high-contrast square variation, so the eye reads noise/camouflage before it reads earth, fracture,
   mass, or excavation.
3. **The surface-to-subsoil transition changes visual grammar.** The grass lip is crisp, flat, and tile-like;
   the earth below is diffuse and mottled. They do not yet feel like layers of one physical world.

Solve these through **many narrow, screenshot-led tickets**, because the project has parallel implementation
capacity and the frame needs iteration. The four root workstreams exist to keep those tickets coherent, not
to restrict their count. Each ticket must name its frame, one visual hypothesis, owner, before/after review,
and a regression guard; agents may iterate quickly without creating a single unreviewable “polish” change.

## What was observed versus what is inferred

| Frame | Observed | Inference | Confidence |
|---|---|---|---|
| A | A selected-item panel, two `FORGE` labels and pointers, two circular interaction/selection marks, a high-contrast dashed grapple guide, and bright ore/glint marks compete in one shallow surface view. | The player has insufficient visual quiet to choose a natural focal point; most helpers are styled as persistent screen furniture rather than transient state. | High |
| A | Earth, stone, and dark underground cells repeat bright tan/grey squares at similar scale and contrast. The eye finds many isolated marks before it finds a broad dirt mass or rock plane. | The terrain generator/renderer lacks a material hierarchy: it applies texture as decoration rather than using texture to describe substance. | High |
| A | The grass line is a thin crisp green/brown strip while the cells immediately under it are much blurrier, darker, and more varied. | The terrain layers are authored/rendered under incompatible edge, palette, and pixel-scale rules. | High |
| A | The dashed line beside the active grapple/aim state is prominent from surface to player, independent of whether the player is reading a route or experiencing tension. | The line reads as tool/debug geometry more than as a physical cable. It likely reduces the satisfaction of a movement verb intended to be expressive. | Medium — a motion clip is needed to judge timing. |
| B | A three-line, screen-centred SAPLING tutorial panel obscures the player’s immediate sky/world context while arrows/circles and machine labels remain visible beneath it. | The tutorial system explains a mechanic while interrupting the verb it is meant to teach; it is a comprehension aid with a high attention cost. | High |
| Noita reference | The world holds most of the contrast and visual mass; HUD is confined to corners; terrain has coherent dark silhouette and contained material variation. | SINKFORGE should borrow its information discipline and value hierarchy, not its specific pixel density, palette, or destructive-pixel simulation. | High |

## Root workstreams

### V1 — Guidance quietness and state hierarchy

**Problem.** The game presents teaching, selection, machine status, objective-like labels, and movement
guides simultaneously. Their common visual language—bright outline, gold/white accent, black plate, arrow,
or ring—makes them all equally urgent.

**Design rule.** At any moment, only one of these may be primary: (a) an immediate player action, (b) a
newly discovered object, or (c) a genuine danger/failure. Everything else must recede, wait, or attach to
its source in the world.

**Recommended treatment sequence.**

1. Inventory every tutorial, ring, arrow, floating label, and persistent screen panel by trigger, duration,
   dismissal condition, and visual priority.
2. Establish four visual priority tiers:
   - **Critical:** immediate danger or interaction failure; may interrupt attention.
   - **Active:** current targeted/held/attached object; local, concise, and stateful.
   - **Discoverable:** a new affordance; appears once near its object, then fades or becomes contextual.
   - **Ambient:** learned/status information; corner-bound, world-embedded, or hidden until requested.
3. Convert the SAPLING lesson first. It should be a source-bound one-line affordance when sapling is held
   over valid grass, not a centred explanatory panel. Its full explanation belongs in an opt-in help/history
   surface if it is needed at all.
4. Suppress non-critical teaching while the player is moving quickly, aiming, swinging, or in the middle of
   an active interaction. Resume only when they settle and the cue remains relevant.
5. Give helpers an expiry: demonstrated action, loss of relevance, explicit dismissal, or a short first-use
   timeout. Do not leave instructional art on screen because the player has not yet performed the exact
   desired action.

**Acceptance evidence.** Compare normal surface, active grapple, selected sapling, map-open, and first
machine frames. The game should retain a clear action target while no tutorial panel blocks the player or
the relevant terrain. `check_hud_layout` can protect known collisions; captures and human review decide
whether the hierarchy feels quiet.

**Do not do.** Do not replace every hint with a new icon system, remove critical feedback, or make learning
opaque in the name of cleanliness.

**Priority placement.** This is **T2.1 follow-through**, before any large art pass and before subjective
opening evaluations. It protects real desire measurement by stopping the UI from supplying a next action.

### V2 — Terrain material grammar

**Problem.** The terrain currently communicates “many differently coloured squares” before it communicates
what each region is made of. The bright isolated cells create a spotted/camouflage read. In Frame A, the
dark void-adjacent mass, dirt, stone, and mineral glints share enough frequency and contrast that material
identity collapses at a glance.

**Design rule.** Material hierarchy must be read in this order: broad mass → boundary/plane → material type
→ local texture → special/resource detail. If local texture is the first thing noticed, it is too loud.

**Recommended first experiment: one cross-section, not a global repaint.**

Use a controlled representative surface-to-stone slice and produce A/B captures. Alter only the rule set
for dirt, stone, and their contact:

- reduce isolated near-white/near-black single-cell accents in dirt;
- group variation into low-frequency clumps, seams, compaction bands, or directional strata;
- reserve the strongest light accents for a small set of meaningful events: fresh fracture, ore glint,
  wetness, or torch/lamp response;
- make dirt warmer and more horizontally layered/packed; make stone cooler, more planar/fractured, and
  less randomly speckled;
- preserve enough nonuniformity that the world does not become a flat tiled wallpaper.

The test is not “does it have more grain?” More undifferentiated grain is explicitly a rejected strategy.
The test is whether a player can name the material and infer its mass/edge before attending to decorative
variation.

**Acceptance evidence.** Review at 1× and normal play scale, in daylight and underground light. Re-run the
existing rock/void legibility procedure for interiors; a beautiful cross-section that worsens route reading
is rejected. Ask independent reviewers to identify dirt, stone, ore, empty space, and recently mined edge
without labels.

**Do not do.** Do not hand-edit every block, increase global brightness, add global noise, or ship a new
texture atlas before the rule works in the controlled slice.

**Priority placement.** New **T3 terrain-material grammar** item, immediately after T3.1’s functional
interior readability treatment. It is a visible quality milestone, but it must not overtake T1.0/T2.1.

### V3 — Surface-to-subsoil continuity

**Problem.** The grass cap is a crisp, thin platform and the dirt beneath it behaves as another rendering
language. This makes the surface look composited over a noisy underground rather than supported by earth.

**Design rule.** The surface is the exposed upper boundary of the same ground that continues beneath it.
Grass, roots, loose earth, packed soil, and stone should communicate depth and weathering without requiring
a separate tile aesthetic.

**Recommended treatment sequence.**

1. Establish a shared palette/value bridge: topsoil becomes a controlled first dirt stratum rather than a
hard transition into unrelated noise.
2. Add a sparse, purposeful transition vocabulary—roots, compacted bands, small loose pockets, or erosion
marks—only if it serves the depth read.
3. Make cut faces and fresh excavations visually related to their source material, so a mined opening reads
as removed mass rather than black shapes drawn over terrain.
4. Re-evaluate the grass-cap-on-shaft-floor defect separately. It is correctness debt; do not hide it under
an art treatment.

**Acceptance evidence.** A player should read, without a depth counter, where air begins, where topsoil
ends, and why the ground can support the structures above it. The cross-section must look intentional at
1×, 4×, and normal camera scale.

**Priority placement.** Fold into V2’s first experiment. Do not create an independent surface-art project
until terrain grammar proves it needs one.

### V4 — Grapple visual language

**Problem.** The existing dashed grapple/aim guide is a very clear vector, but in Frame A it is high-contrast
and persistent enough to read as debug scaffolding. It is visually louder than the player and competes with
the world even before the movement has become expressive.

**Design rule.** The rope/cable must communicate state and physical tension, not display hidden targeting
math. Its visual intensity follows commitment: quiet while merely aiming, clearer while attached, strongest
at tension/release/collision.

**Recommended experiment.** Capture the same movement sequence under three reversible treatments:

1. current dashed guide;
2. dim, short-range aim reticle with a physical attached cable only after commitment;
3. low-contrast aim arc/ghost with cable opacity and slight tension response after attachment.

Review motion, not a still, for target clarity, accidental-anchor prevention, player silhouette, and urge to
swing again. The player must still be able to aim a fast grapple reliably.

**Acceptance evidence.** No guide is visible as persistent geometry when it is not helping an immediate
decision. Attached/loaded rope state is readable from its physical form, endpoint, and motion. Grapple
controls remain at least as reliable under direct player use.

**Priority placement.** New **T3 grapple visual language** item alongside T3.10 swing-release momentum.
It may run after V1 and V2; it should not become an input-feel rewrite.

### V5 — Bazaar and settings as an installed industrial interface

**Problem.** The Pack, Works, Bench, and Settings frames are not merely oversized. They use a generic stack
of dark rounded cards, widely tracked uppercase labels, gold rectangular fills, floating resource chips,
and large dead zones. The result reads as a 2008 presentation/dashboard placed over the game, rather than
part of a kinetic industrial world.

**Design rule.** The Bazaar should feel like an operated workbench or field terminal with a clear current
decision—not a slideshow of the whole catalogue. Settings should be a quiet utility surface, not a second
dashboard. The world should remain context only when that context helps the decision; it must not show
through as competing scenery.

**Priority placement.** Create a menu-overhaul parent under T2.1 immediately after V1’s tutorial quietness.
It may run in parallel with T3.1 because it is a contained UI/system pass, but it must begin with a visual
language and information-architecture prototype, not a piecemeal reskin. See the `MNU-*` queue in
`VISUAL_RECOMMENDATIONS_SURFACE.md`.

## Candidate visual backlog — symptoms grouped under roots

These are observations to preserve, not twenty independent implementation tickets.

| Symptom | Root | Severity | First investigation |
|---|---|---:|---|
| Screen-centred multi-line tutorial panel | V1 | Frame-breaking | Measure duration/coverage and replace one lesson with contextual first-use cue |
| Multiple arrows/rings/labels in one surface frame | V1 | Frame-breaking | Inventory simultaneous helper states and assign priority tiers |
| `FORGE` labels and pointers read like duplicated UI | V1 | Play-disrupting | Determine which state each communicates; collapse redundant state or bind it to object proximity |
| Selected item panel competes with active action | V1 | Play-disrupting | Compare persistent versus action-only display in capture |
| Dashed grapple guide reads as debug geometry | V4 | Play-disrupting | Three-state motion comparison |
| Dirt has isolated pale/brown blocks (“cow spots”) | V2 | Frame-breaking | Measure accent density and test clustered low-frequency variation |
| Stone/dirt/deposit share texture frequency | V2 | Frame-breaking | Define per-material silhouette, palette, and variation rules |
| Bright glints read as noise before resource | V2 | Play-disrupting | Reserve high-value accents for resource/event semantics |
| Grass lip and dirt below use incompatible pixel grammar | V3 | Frame-breaking | Controlled cross-section A/B |
| Underground darkness masks mass while texture persists | T3.1 + V2 | Functional | Interior readability treatment before art polish |
| Cavities read as cut-out black rather than excavated volume | V2/V3 | Play-disrupting | Compare fresh-cut face and background-plane treatment |
| Tree/ruin/surface structures feel tile-adjacent | Existing T3.11 | Craft debt | Revisit only after ground is coherent |
| Machine labels/status are more vivid than machines | V1 + existing T3.2 | Play-disrupting | Give hardware state a visible world expression before adding more chrome |
| Screen is busy even in an idle moment | V1 | Frame-breaking | Create a “quiet frame” capture criterion |
| Player silhouette is not the default focal point | V1/V2/V4 | Play-disrupting | Heat-map/eye-path review of normal surface and underground frames |

## Sequencing and milestones

### Milestone 1 — Quiet enough to play

Complete V1’s first-use/tutorial hierarchy pass. Deliver before/after captures of the sapling interaction,
normal surface movement, a grapple, map-open, and first machine. This is a high-visibility improvement and
the correct next presentation milestone after repository cleanup.

### Milestone 2 — Ground with a material identity

After T3.1 resolves the functional interior rock problem, run V2/V3’s controlled cross-section experiment.
Ship only a rule that improves or preserves legibility in the same captures. This is the first broad visual
quality milestone; it should make screenshots feel authored rather than procedurally speckled.

### Milestone 3 — A kinetic tool, not a targeting overlay

Run V4 in motion alongside T3.10. Ship a grapple state language only if direct movement remains reliable.
This supports the game’s remembered image: a miner moving through an industrial world, rather than a cursor
operating a physics toy.

## Review protocol

For every selected visual change:

1. State the hypothesis before producing pixels.
2. Capture the exact same named moment/seed/camera before and after; never overwrite canonical evidence.
3. Review at normal play scale first, then 1× and 4×.
4. Separate functional legibility checks from subjective craft judgment.
5. Test one root rule at a time; no multi-system “polish” commit.
6. Keep a rejected-treatment record with the reason it failed. Reverting a bad visual hypothesis is success.
7. Do not promote a screenshot improvement to a gameplay claim without an appropriate player/agent
   evaluation.

## What not to copy from Noita

- Do not copy its palette, exact pixel scale, UI layout, silhouette style, procedural material simulation,
  or tone.
- Do not make the surface darker simply because Noita is darker.
- Do not confuse granular simulation with good material communication; SINKFORGE needs readable planned
  construction and tunnelling, not visual chaos.

Borrow only the discipline: quiet information hierarchy, world-first composition, material-specific value
language, and confidence in leaving much of the screen visually calm.

## Ownership and priority integration

The main engineer should add **one parent priority entry at a time**, after consulting this ledger:

1. extend T2.1 with V1 guidance quietness;
2. retain T3.1 as the functional underground prerequisite;
3. add one T3 terrain-material grammar parent item covering V2/V3;
4. add one T3 grapple visual-language parent item alongside T3.10.

`PRIORITY.md` remains the small decision queue and milestone map. This file and
`VISUAL_RECOMMENDATIONS_SURFACE.md` are the evidence-rich granular queue. It is fine to cut many
independent tickets from a selected workstream in parallel, but only one milestone-level parent needs to
occupy the active priority table at a time.
