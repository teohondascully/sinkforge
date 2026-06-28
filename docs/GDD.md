# SINKFORGE — Game Design Document v0.1

> *A 2D side-view factory automation game where gravity is your conveyor belt. Dig downward, discover exotic materials, and engineer increasingly complex vertical production chains that cascade resources from the surface to the depths. Part Factorio, part idle progression, all about the satisfaction of a perfectly tuned machine running itself while you push deeper.*

---

## Core Identity

**Genre:** 2D Factory Automation / Idle Progression
**Engine:** Godot 4.6.2 (GDScript)
**Platform:** macOS dev (M4 Pro) → Steam (Windows/Mac/Linux)
**Perspective:** Side-view, vertical orientation
**Scope:** Ambitious / flagship project
**Solo dev with Assistant Code as assistant**

---

## The Hook — Gravity Is Your Conveyor Belt

In Factorio, you build flat and move resources horizontally with belts. In Sinkforge, **your factory is vertical and gravity does the work.** Resources fall. You design production chains that cascade downward — raw ore enters at the top, falls through crushers, smelters, assemblers, refineries, each stage processing it further as it descends.

This single design decision changes everything:
- **Layout is a vertical puzzle.** You're thinking in falls, drops, and lifts, not flat belt routing.
- **"Going deeper" is mechanical, not cosmetic.** Your factory literally grows downward into the earth.
- **Power and lifting create natural tension.** Gravity is free going down, but moving things UP costs energy. Do you process at the surface and drop refined goods, or haul raw materials down to where exotic processing happens?
- **Verticality compounds.** Each layer feeds the one below. A bottleneck at layer 3 starves everything beneath it.

---

## The Pillars

1. **Every machine you place multiplies what's below.** Exponential scaling is structural, not bolted on.
2. **The factory should run without you — then you make it run better.** Idle progression meets active optimization.
3. **Going deeper always reveals something that breaks your current setup.** New materials force redesigns. Comfort is temporary.
4. **"Just one more layer" at 2am.** The compulsion loop is the descent.

---

## Core Gameplay Loop

```
DIG DOWN ──► DISCOVER MATERIAL ──► DESIGN PRODUCTION CHAIN ──┐
   ▲                                                          │
   │                                                          ▼
   └──── UNLOCK DEEPER ACCESS ◄──── OPTIMIZE & AUTOMATE ◄─────┘
                                    (idle generation funds expansion)
```

### 1. DIG DOWN
- Deploy mining to break through earth and expose new depth layers
- Each layer has distinct geology, materials, hazards, and physics quirks
- Digging costs resources — early game it's slow and manual-ish, late game you have automated excavation fleets

### 2. DISCOVER MATERIAL
- New depth layers introduce new raw materials
- Each material has properties that demand new processing approaches
- Some materials interact with existing chains (catalysts, byproducts, contaminants)

### 3. DESIGN PRODUCTION CHAIN
- Place machines that transform materials as they fall through them
- Chain stages vertically: extract → crush → smelt → refine → assemble
- Manage power, throughput, and the cost of lifting materials against gravity

### 4. OPTIMIZE & AUTOMATE
- Eliminate bottlenecks, balance flow rates, merge shared byproduct streams
- Once a chain is tuned, it runs autonomously and generates output
- Idle generation funds the next expansion downward

### 5. UNLOCK DEEPER ACCESS
- Refined outputs unlock new excavation tech, new machine tiers, deeper access
- The cycle repeats — but now with more complex inputs and higher stakes

---

## Vertical Factory Mechanics

### Gravity Flow
- Items have mass and fall through open vertical shafts
- **Drop chutes:** Free vertical transport (downward only)
- **Splitters/mergers:** Direct falling items left/right into different chains
- **Catchers:** Stop falling items and feed them into a machine
- **Lifts/elevators:** Move items UP — costs power, creates strategic friction

### Machine Stacking
- Machines occupy vertical space and process items that pass through or into them
- Output drops to the next machine below (or into a chute/buffer)
- Vertical alignment matters — misaligned chains waste space and require lateral routing

### Lateral Routing
- Not everything is a straight drop. Conveyors and pipes handle horizontal movement
- Horizontal movement is slower/costlier than free-fall — encourages vertical-first thinking
- Creates the puzzle: how do you fold a complex multi-input recipe into vertical space?

### Power System
- Machines consume power; lifts consume more
- Power generation evolves with depth (surface solar → combustion → geothermal from deep heat → exotic deep-layer energy)
- Power is a parallel production chain you must also automate

---

## Depth Layers (Progression Spine)

Each layer is a distinct "act" with new materials, mechanics, and a physics twist.

| Depth | Layer Name | New Material(s) | Twist / New Mechanic |
|-------|-----------|-----------------|----------------------|
| 0 | Surface | Scrap, basic ore | Tutorial — establish gravity-flow basics |
| 1 | Topsoil & Clay | Iron, copper, coal | First multi-stage chains (smelting) |
| 2 | Bedrock | Stone, quartz | Power scaling, first lifts needed |
| 3 | Crystal Veins | Crystalline ores | Materials that must stay cold (heat management) |
| 4 | The Wet Layer | Pressurized fluids | Liquid handling, pipes, flooding hazard |
| 5 | Thermal Strata | Magma-adjacent ores | Heat as both resource and threat; geothermal power |
| 6 | The Hollow | Exotic gas pockets | Gas processing, pressure differentials |
| 7 | Compression Zone | Density-altered matter | Gravity behaves differently — items fall faster/slower |
| 8 | The Glow | Bioluminescent/radioactive | Materials that decay over time — throughput races |
| 9+ | The Sinkforge | ??? | Endgame — physics rules break down, megastructure assembly |

**Design principle:** Every layer must force the player to reconsider their existing factory, not just bolt on a new wing. New materials should flow UP into earlier chains or require pulling earlier products DOWN, weaving the whole factory together.

---

## The Idle Layer

Sinkforge is "idle-ish" — not a pure clicker, but progression continues when systems are automated and when you're away.

- **Active play:** Designing, optimizing, expanding, troubleshooting bottlenecks
- **Passive generation:** Tuned production chains generate resources on their own
- **Offline progression:** Factory runs while you're away (with caps/buffers that fill up, creating a reason to return and expand storage)
- **The tension:** Idle output funds expansion, but expansion requires active design. You're never just watching numbers — you're always building toward the next idle baseline.
- **Prestige-free:** Like The Depth decision — no resets. Permanent vertical empire. The satisfaction is the growing machine, not optimizing for a reset multiplier.

---

## Scaling & The Compulsion Loop

Why this scales where The Depth didn't:

- **Structural exponential growth:** Each layer's output feeds the next. Doubling layer 2 throughput cascades benefits to all layers below.
- **Constant hands-on decisions:** Machine placement, flow balancing, bottleneck hunting — the player's hands are always busy.
- **Multiple optimization targets:** Throughput, power efficiency, space efficiency, lift minimization — always something to tune.
- **The descent as a carrot:** There's always a next layer, and you always want to see what material it holds and what it'll do to your factory.
- **Numbers go up, visibly:** Idle generation rates, production counters, depth meter — constant feedback that you're growing.

---

## Open Design Questions

- [ ] **Mining model:** Manual dig vs. designate-and-automate vs. hybrid?
- [ ] **How granular is item physics?** Individual falling items (Factorio-style item-on-belt) vs. abstracted throughput flows?
- [ ] **Combat/hazards:** Are there threats (cave-ins, creatures, floods) or is it pure logistics?
- [ ] **Build constraints:** Free-form digging vs. structured grid? How much can you reshape the earth?
- [ ] **Art style:** Pixel art resolution and tile size (likely 32x32 per earlier preference)
- [ ] **Tech/research tree:** Linear depth-gated vs. branching choices?
- [ ] **What is the Sinkforge?** Endgame narrative/mechanical payoff
- [ ] **Story/setting:** Why are you digging? Is there narrative or is it pure sandbox?

---

## Prototype Plan

### Prototype 1: Does Gravity-Flow Feel Good? (Week 1-2)
- Vertical shaft, items spawn at top and fall
- Place 2-3 machine types that catch, process, and drop items
- A splitter and a chute
- **Test:** Is watching resources cascade through a vertical chain satisfying? Does building it feel like a puzzle?

### Prototype 2: The First Real Chain (Week 2-3)
- Implement a 3-stage production chain (ore → crushed → smelted → ingot)
- Add power as a constraint
- Add a lift (upward transport with power cost)
- **Test:** Does balancing throughput and power create interesting decisions?

### Prototype 3: Dig & Discover (Week 3-4)
- Implement digging downward to expose a new layer
- New layer introduces one new material requiring a new processing step
- **Test:** Does discovering a new material and integrating it into the factory feel rewarding?

### Prototype 4: The Idle Test (Week 4-5)
- Automated chains generate resources passively
- Offline progression with storage caps
- **Test:** Is there a satisfying loop of "tune it, let it run, come back, expand"?

---

*Document version 0.1 — concept pivot from The Depth. Core hook (vertical gravity factory) established.*
