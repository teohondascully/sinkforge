> **ARCHIVED 2026-08-27 — CORRECTED, not a loose end.** First written up as "two dated snapshots, authority
> unreconciled." Wrong, same correction as `docs/archive/DIRECTOR_BRIEF-postpivot-edit-2026-08-25.md`'s
> own header: `docs/archive/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md`'s header already explains the
> relationship — "the three-way visual experiment protocol... extracted 2026-08-26" FROM this exact file,
> leaving out "the 50-atomic-findings audit and the priority-sequence mapping... both about pre-pivot
> Bazaar-era screens that no longer exist." 96 extracted lines + that stated reason vs. this file's 465
> full lines is a clean parent -> curated-subset relationship, not two competing edits. This file IS "the
> untracked original" that file refers to; its header now names this path directly. Moved here while
> closing the `.git/info/exclude` hole (ANVIL step 1).

---

# SINKFORGE visual quality programme

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

## Purpose

This document turns the director's screenshot-level concerns into a visual product programme. It is not
a reskin brief and it is not permission to make isolated pixels prettier. Its purpose is to answer a harder
question:

> Would a new player in 2026 understand what they are looking at, feel that this world has a point of view,
> and want to stay long enough to discover the next thing?

The supplied surface and underground frames are the primary evidence. Design documents explain intent; the
frame decides whether the intent is visible.

The existing visual documents remain authoritative for their ticket inventories:

- `docs/VISUAL_TRIAGE.md` — root causes and workstream sequencing.
- `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` — concrete UI, grapple, terrain, surface, machine, and pixel-craft tickets.
- `docs/handoff/VISUAL_TRIAGE_ENGINEER_BRIEF.md` — earlier V1-first adoption brief.
- `docs/PRIORITY.md` — project-level ordering and dependencies.
- `docs/MENU_MATRIX.md` — menu ticket status and closure evidence.

This document adds the missing product layer: what the game currently feels like to a first-time player,
what visual qualities are absent, and how to compare three deliberately different treatments before any
one treatment becomes canonical.

## Director verdict

The game is not failing because it lacks enough effects. It is failing because too many systems use the
same visual grammar and none of them owns the frame.

The current artifact reads as a technically ambitious prototype wearing a generic pixel-game interface.
The grappling premise and deep-earth silhouette are promising, but a new player can reasonably conclude:

- this is an old debug build rather than a finished game;
- the text and panels are more important than the world;
- the earth is a texture atlas rather than a physical mass;
- the lights are rendering artifacts rather than fixtures with sources;
- the tutorial is a presentation layer explaining a system instead of a world teaching through action;
- the machines and materials have not yet acquired a house style.

That is a retention risk. A player does not owe the game patience while it explains why its roughness is
intentional.

## Devil's-advocate first-session review

The following is written from the perspective of a player familiar with current 2026 games, arriving with
no knowledge of the code, design bible, or intended fixes.

### The first 400 milliseconds

The eye meets several large rectangular claims at once: depth/stratum, a top objective, a forged counter,
floating machine labels, circular markers, a grapple guide, a tutorial bubble, a hotbar, and a keyboard
legend. There is no clear answer to “what should I look at first?”

The top objective is especially damaging. It is a broad dark plate with large text and a small instruction,
so it reads like a task manager pinned over the game. It gives the player a verb, but it does not make the
world object that satisfies the verb visually special.

The player sprite is small and low-contrast relative to the UI. The player should be the default anchor of
the scene; instead, the largest text and brightest borders win.

### Typography and text rendering

The text feels grainy and soft rather than deliberately pixel-authored. The problem is not simply
anti-aliasing. It is the combination of:

- mixed apparent pixel scales between world art, UI text, icons, and effects;
- wide tracking used as a substitute for typographic identity;
- large headings with weak internal rhythm;
- low-contrast body text sitting on noisy translucent plates;
- labels that are visually larger than the object they identify;
- values, units, and key glyphs that do not share a dependable alignment system;
- a type treatment that could belong to any survival-crafting prototype.

The result resembles a 2006 game menu or a presentation mockup rendered over a game, not a single authored
instrument panel. A modern player will not describe this as “retro”; they will describe it as unfinished.

### Panels, borders, and chrome

The dark rounded rectangles, thin outlines, gold bars, floating chips, and translucent plates are repeated
so often that they stop communicating state. Gold appears to mean selection, title, cost, enabled state,
and emphasis. White appears to mean rope, impact, resource glint, and attention. A visual language with too
many meanings is not a language; it is noise.

The menus are also too eager to show their implementation. Empty space, repeated card shells, inactive rows,
and explanatory copy are all visible at once. The player sees the catalogue before seeing the decision.

### Tutorial and guidance behavior

The tutorial bubbles are not just large; they interrupt the relationship between action and consequence.
They explain a world object while obscuring the world, or explain a verb while other helpers continue to
compete for attention.

The correct question is not “does the bubble fit inside its rectangle?” It is “does the player see the
thing the sentence names before the sentence finishes?”

The current game often answers no.

### Terrain and blockiness

The ground has a recognizable tile-grid substrate, but the grid is not being used to create a coherent
material language. Dirt contains isolated pale and brown marks with similar frequency and contrast to stone.
The eye reads spots before mass. The surface grass lip is crisp and tile-like while the soil below is soft,
blurred, and mottled. The result looks like a platform pasted on top of a noise field.

The blockiness itself is not the problem. Terraria, Noita, and other successful pixel games are blocky. Their
blocks have authored value ramps, silhouettes, material rules, and deliberate exceptions. SINKFORGE currently
uses blockiness as a coordinate system, not yet as an aesthetic decision.

### Lighting and the vertical streams

The underground light streams look like downward-pointing design artifacts rather than light emitted by a
fixture. Their shape is too regular, their source is not always legible, and their falloff does not explain
the geometry around them. They read as a renderer pass saying “this area is lit,” not as lamps, shafts, or
industrial luminaires occupying space.

The central light pool is also competing with the player and with the terrain material. A light should make
the world more readable and more physical; it should not turn every nearby surface into the same warm haze.

### Material honesty

Stone, dirt, ore, void, water, lamps, and metal do not yet have sufficiently different visual behaviors.
Hue changes help, but hue alone is not material identity. A material needs a distinct combination of:

- broad value/mass;
- boundary behavior;
- texture frequency;
- directional grain or fracture;
- response to light;
- response to excavation;
- meaningful accents.

Ore glints are currently close enough to other bright marks that the player can read “sparkle” before “resource.”
Dark void can retain texture while rock loses mass, making empty space and solid space harder to distinguish.

## Expanded screenshot audit: 50 atomic findings

The screenshot review surfaced more than a handful of broad complaints. The inventory below makes the
symptoms concrete enough to test without turning each symptom into a new parent in `PRIORITY.md`. These are
atomic observations, not 50 independent implementation tasks. Each must map to an existing workstream and
be re-confirmed against a current capture before work begins; stale pixels do not become requirements.

### Surface props and vegetation (`SUR-01`–`SUR-10`)

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| SUR-01 | The canopy reads as a green dirt block rather than foliage. | T3.12 terrain grammar |
| SUR-02 | The trunk shares the soil's square texture rhythm and loses object identity. | T3.12 |
| SUR-03 | The tree has no readable branch/crown gesture at normal play scale. | T3.12 |
| SUR-04 | The trunk has no root or ground-contact cue. | T3.12 |
| SUR-05 | The canopy is hard-cropped into a rectangular tile silhouette. | T3.12 |
| SUR-06 | Highlights appear as random pale patches rather than planes or leaves. | T3.12 |
| SUR-07 | The tree casts no convincing contact shadow into the surface. | T3.12 / lighting |
| SUR-08 | Prop outlines use the same border language as UI plates. | pixel craft / V5 |
| SUR-09 | Tree scale is ambiguous against the miner and machines. | world composition |
| SUR-10 | Trees, rocks, lamps, and machines lack a shared construction grammar. | machines / T3.12 |

### Grass and topsoil (`SUR-11`–`SUR-20`)

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| SUR-11 | The bright green cap is visually detached from the soil mass beneath it. | V3 / T3.12 |
| SUR-12 | Grass-cap thickness jumps abruptly from cell to cell. | T3.12 |
| SUR-13 | Grass tips repeat with no authored rhythm or silhouette variation. | T3.12 |
| SUR-14 | The green value is brighter than the scene's focal hierarchy warrants. | lighting / T3.12 |
| SUR-15 | There is no compacted or root-bound topsoil band beneath the grass. | V3 |
| SUR-16 | Excavating one cell exposes a texture unrelated to the surface edge. | V3 |
| SUR-17 | Unsupported overhangs have no visual stress or material response. | V3 / world coherence |
| SUR-18 | Ledge edges change grammar at arbitrary tile boundaries. | V3 |
| SUR-19 | Subsurface texture frequency remains too similar at different depths. | V2 / descent legibility |
| SUR-20 | The surface boundary reads as a tile seam rather than geological layering. | V2/V3 |

### Lighting and atmosphere (`LGT-01`–`LGT-10`)

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| LGT-01 | A light stream has no consistently legible source fixture. | lighting / V5 |
| LGT-02 | Beam width and spacing repeat with mechanical uniformity. | lighting |
| LGT-03 | Haze forms rectangular slabs instead of volumetric falloff. | lighting |
| LGT-04 | Light does not visibly occlude around solid geometry. | V2 / lighting |
| LGT-05 | Warm spill flattens nearby material differences. | V2 / lighting |
| LGT-06 | Dark regions retain decorative texture while losing mass and edge. | V2 |
| LGT-07 | Glow is brighter than the fixture that supposedly emits it. | lighting / machines |
| LGT-08 | Dust/bokeh particles share the same language as ore glints. | material honesty |
| LGT-09 | Shadow shapes are broad rectangles unrelated to the object casting them. | lighting |
| LGT-10 | Machine state is not reinforced by deliberate, source-stable lighting. | machines / V5 |

### UI, typography, and information hierarchy (`UIQ-01`–`UIQ-10`)

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| UIQ-01 | Text edges are soft or grainy at the actual gameplay scale. | V5 / pixel craft |
| UIQ-02 | Tracking is applied broadly, substituting spacing for a type identity. | V5 |
| UIQ-03 | Body copy loses contrast against noisy translucent plates. | V5 |
| UIQ-04 | Depth, objective, and forged-counter plates compete for first read. | V1 / V5 |
| UIQ-05 | The objective is not visually tied to the object that satisfies it. | V1 |
| UIQ-06 | The persistent keyboard legend consumes attention after controls are learned. | V1 |
| UIQ-07 | Gold is overloaded as selection, title, cost, enabled state, and emphasis. | V5 |
| UIQ-08 | White is overloaded as rope, glint, impact, and attention. | V5 / grapple |
| UIQ-09 | Labels, values, and units do not share stable baselines or alignment. | V5 |
| UIQ-10 | Generic rounded modal plates erase the distinction between utility, shop, research, and world object. | V5 |

### Composition, pixel craft, and action feedback (`QUA-01`–`QUA-10`)

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| QUA-01 | The player is too small and low-contrast to anchor the frame. | world composition |
| QUA-02 | Labels, machines, and effects compete laterally with the player. | V1 / composition |
| QUA-03 | World art, text, icons, and effects appear to use incompatible pixel scales. | pixel craft |
| QUA-04 | Blur/grain is present without a semantic reason and lowers material clarity. | pixel craft / lighting |
| QUA-05 | Machines read as finished boxes rather than assembled, grounded mechanisms. | machines |
| QUA-06 | Dig impact does not clearly distinguish fracture, removal, and empty space. | action feedback |
| QUA-07 | Building appears as an instant object rather than orientation plus assembly. | action feedback |
| QUA-08 | Hauling communicates inventory change more strongly than body weight or consequence. | action feedback / Freight |
| QUA-09 | Grapple targeting exposes aim math more than cable attachment and tension. | V4 / T3.13 |
| QUA-10 | Depth banners and ceremonies obscure the world they are meant to make memorable. | V1 / descent |

### Item and slot presentation (`ITM-01`–`ITM-20`)

The latest underground frame exposes a separate failure class: item presentation is being treated as a
uniform grid of black square containers. That is not neutral framing. The repeated wells become the strongest
shape in the scene, flatten different materials into identical tiles, and make the inventory/hotbar look like
debug UI stacked over the world. These findings are deliberately separate from icon-craft tickets because the
container, spacing, and state hierarchy are part of the problem.

| ID | Specific finding to verify | Preferred parent |
|---|---|---|
| ITM-01 | Every item sits in the same opaque black square regardless of material or function. | V5 / Pack |
| ITM-02 | The repeated squares form a barcode/grid that competes with the world. | V1 / V5 |
| ITM-03 | Container silhouette communicates more strongly than the item silhouette. | pixel craft |
| ITM-04 | Black wells remain visually dominant in a dark underground frame. | V5 / lighting |
| ITM-05 | Empty slots use the same heavy treatment as occupied slots. | Pack |
| ITM-06 | Selected-slot borders are too thick and become a second HUD focal point. | V5 |
| ITM-07 | Unselected item icons lose too much value and become unreadable at 1×. | pixel craft |
| ITM-08 | Item background color has no relationship to material, category, or state. | Pack / material honesty |
| ITM-09 | Icons use inconsistent apparent scales inside identical wells. | pixel craft |
| ITM-10 | Resource, tool, and machine icons share a frame despite different meanings. | Pack / V5 |
| ITM-11 | Machine items read like inventory tokens rather than installable physical objects. | machines / Pack |
| ITM-12 | A long row of slots creates a UI strip instead of a carried kit with weight and grouping. | Pack |
| ITM-13 | Empty space inside a slot reads as missing content rather than deliberate capacity. | Pack |
| ITM-14 | The selected-item title is visually detached from its icon and action context. | V1 / Pack |
| ITM-15 | Key index, item icon, and stack count compete as three equal focal marks. | V5 |
| ITM-16 | Stack counts have no compact material glyph or hierarchy and fall back to generic text. | V5 / Pack |
| ITM-17 | Hover/focus state does not reveal why an item is actionable or unavailable. | V5 |
| ITM-18 | Pickup feedback changes a number but does not visually connect the item to the slot. | action feedback |
| ITM-19 | Items have no visible state vocabulary for worn, active, blocked, loaded, or depleted. | Pack / machines |
| ITM-20 | Slot expansion/reordering changes the bar's geometry instead of preserving a stable instrument anchor. | Pack / V5 |

The first three-way experiment should compare: (A) lighter containers with the current icons, (B) category and
state-led wells with stable geometry, and (C) a distinctive carried-kit treatment where materials occupy a
single physical tray or grouped rack rather than twenty identical cards. The experiment must include occupied,
empty, selected, unavailable, large-stack, and machine-item states. It must not be judged from a single icon
crop: the question is whether the whole frame becomes quieter while the item remains easier to use.

These findings intentionally overlap at the symptom level. For example, a soft label may be a typography
problem, a compositing problem, or a renderer-scale problem. The experiment must identify the mechanism before
assigning a fix. A ticket is not closed because one screenshot looks cleaner; it is closed when the chosen
treatment improves the parent workstream's acceptance states without regressing play legibility.

### World composition

The background mountain silhouette, surface props, gear landmark, machines, player, labels, rings, and
depth ceremonies all compete laterally. There is no reliable focal path from player → immediate affordance →
interesting world feature.

The world should own most of the composition, as Noita does, but SINKFORGE should not copy Noita's palette
or destructibility. Its own identity should come from engineered descent: pressure, strata, cable, counterweight,
brass, slate, wet clay, soot, and machinery embedded in earth.

### Machines and objects

Several machines still read as icons placed into terrain. The DRIFT RIG is the strongest exception because it
has a chassis, bolts, and a mechanism. The rest need a family grammar: footprint, contact with ground, intake/
output orientation, working state, stopped state, and a visible reason to exist.

> _[Passage removed 2026-08-25, pivot: the Bazaar is dead design. See git history for the original text.]_

### Action feedback

Dig, build, haul, and grapple do not yet have equal physical follow-through:

- dig needs a clearer contact/fracture rhythm and a stronger distinction between removing a mass and painting a hole;
- build needs assembly, orientation, and commissioning rather than a finished box appearing;
- haul needs body weight, inertia, and a visible relationship between carried mass and movement;
- grapple is the strongest verb, but its guide still exposes targeting math more than physical cable state.

### Menus and utility surfaces

> _[Section removed 2026-08-25, pivot: Settings/Pack/Works/Bench menu-language is specific to the
> persistent-world Bazaar screen. See git history for the original text.]_

## What a SINKFORGE visual identity could be

This is a design direction, not a locked palette:

- **World:** cool slate, packed clay, dark cavities, and restrained atmospheric blue.
- **Industrial accents:** aged brass, oxidized copper, warm ember, and dirty ivory reserved for physical
  mechanisms and immediate interaction.
- **Typography:** compact, high-legibility industrial labels with a small number of sizes and weights;
  tracking used selectively rather than everywhere.
- **Material language:** broad masses first, directional structure second, microtexture last.
- **Lighting:** fixtures have sources, occlusion, spill, and state; light is not a uniform orange veil.
- **UI:** field instruments and work surfaces, not generic rounded-card software.
- **Effects:** impact and consequence are bright; ambient decoration recedes.
- **Pixel craft:** one authored base scale, deliberate ramps, crisp silhouettes, and special effects that
  earn their contrast.

The identity should feel like a worker's instrument built into a living geological machine—not a standard
survival UI recolored brown and gold.

## Three-way visual experiment protocol

Every selected component receives three treatments before integration.

### Option 0 — baseline

Capture the current component unchanged. Record the exact commit, state, viewport, zoom, seed, renderer,
and input pose. This is the control, not a straw man.

### Option A — conservative repair

Fix the diagnosed problem while preserving the existing geometry, art assets, and interaction model. This
answers: “Can we remove the obvious defect with low risk?”

### Option B — system-level correction

Apply a coherent visual rule to the component and its immediate siblings. Examples:

- replace a label with a source-bound state indicator;
- give all controls one focus/disabled/active family;
- make the light stream derive from source, occlusion, and falloff;
- give terrain two distinct variation languages rather than repainting one tile.

### Option C — distinctive SINKFORGE alternative

Try a more opinionated direction that could make the game memorable. It must remain playable and compatible
with the world, but it is allowed to change layout, silhouette, typography, palette role, or effect language.
This is not permission for a global rewrite. It is a bounded provocation designed to reveal whether the current
design is merely familiar because nobody tried a stronger idea.

### Required comparison

All three options must use:

- the same gameplay state;
- the same seed and camera pose;
- the same viewport and zoom;
- the same input sequence where motion matters;
- the same renderer and machine conditions;
- the same capture naming and evidence format.

For a UI component, capture quiet, active, disabled, focused, and error states. For terrain, capture daylight,
underground, lamp-lit, fresh excavation, and material boundary states. For motion, capture a short ordered
sequence, not only a still.

## Evaluation rubric

Score each option from 0–10, with one evidence sentence per dimension:

| Dimension | Weight | Question |
|---|---:|---|
| First-read hierarchy | 20 | Does the eye know what matters first? |
| SINKFORGE identity | 20 | Could this belong to this game and not any generic survival game? |
| Play legibility | 15 | Can a first-time player infer the next useful action? |
| Material/physical honesty | 15 | Do objects, light, terrain, and effects behave like their meanings? |
| Integration | 10 | Does the treatment improve the surrounding frame rather than one isolated object? |
| Motion/state clarity | 10 | Does it communicate transitions, commitment, tension, and consequence? |
| Restraint | 5 | Does it remove noise rather than add a new layer of noise? |
| Cost and risk | 5 | Is the improvement proportionate to implementation and regression risk? |

The director selects the option. The agent may recommend one, but it may not silently choose its favorite.
A visually attractive option that lowers first-read hierarchy or play legibility is rejected.

## First-time-player review questions

After seeing each option for 400ms, ask:

1. What is the player supposed to notice first?
2. What can the player do right now?
3. What object or material is most important?
4. What changed between the baseline and treatment?
5. What do you think will happen if you interact with it?
6. Does anything look like debug scaffolding or a placeholder?
7. Does this look like a game with a specific authorial taste?

For active sequences, ask:

- Did the visual state explain why the action succeeded or failed?
- Did the effect make the action feel heavier, sharper, or more deliberate?
- Did any helper or effect obscure the thing being acted upon?

The actor/evaluator must distinguish “the player could not understand the game” from “the evaluator could
not understand the game.” A failed review is a finding only after the test fixture and actor capability are
validated.

## Isolation and integration rules

- Experiments happen in one disposable visual-design workspace or temporary duplicate of the selected code slice.
- Do not create a fleet of feature worktrees.
- Do not edit gameplay, save schema, thresholds, or unrelated visual systems while comparing options.
- Do not overwrite canonical captures.
- Do not run two Godot or harness processes concurrently.
- Preserve each option as a patch, branch ref, or exported diff until the director chooses.
- Integrate only the selected option against current `main`.
- Run the strongest relevant functional and visual verification after integration.
- Rejected options remain documented with the reason they were rejected.

## Recommended visual sequence

1. **Settings:** implement the approved compact utility direction (Variant B) as the first real in-game visual
   prototype. It is contained, high-impact, and establishes the control grammar.
2. **Top-left depth/stratum instrument:** compare a compact field-marker treatment against the current large
   plate. It should communicate depth without becoming a second objective rail.
3. **Tutorial/announce hierarchy:** ensure the lesson names the visible subject and does not cover it.
4. **Lighting streams:** prototype source-bound fixtures, physically plausible falloff, and a stateful industrial
   alternative. Reject any option that merely changes orange to another color.
5. **Terrain cross-section:** compare current noise, conservative clustered strata, and a bolder authored material
   grammar at normal play scale before distributing anything globally.
6. **Machines/Bazaar:** give one machine family and the Bazaar a recognizable installed-object grammar.
7. **Grapple:** compare the current guide, a quiet aim preview, and a physical tension language in motion.
8. **Action feedback:** dig, build, and haul receive bounded three-way treatments after their visual systems have
   a coherent identity.

## Definition of success

This programme succeeds when a new player can look at a frame and say, without coaching:

- what the place is;
- what the player is doing;
- what matters now;
- what is solid, empty, wet, valuable, or dangerous;
- which machine is physical and what it is doing;
- what the next action might be;
- and why this looks like SINKFORGE rather than a generic 2006 pixel prototype.

It does not succeed because every panel has a border, every material has more noise, or every screenshot is
technically free of collisions.

## Priority integration

Do not add dozens of independent visual items to `docs/PRIORITY.md`. Keep the existing parent structure and
attach each chosen experiment to one parent:

- V1 → T2.1 guidance subtraction;
- V5 → T2.1m menu overhaul;
- T3.1 → functional rock/void readability;
- V2/V3 → T3.12 terrain material grammar;
- V4 → T3.13 grapple visual language;
- action feedback → the relevant T2/T3 verb item.

Each parent may have one active experiment at a time. A new experiment begins only after the previous one has
an explicit decision and retained evidence.
