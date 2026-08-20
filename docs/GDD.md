# SINKFORGE — Game Design Document v0.2

> *A 2D side-view game where you are a person digging an industrial empire into a vast destructible underworld. You explore and mine freely in every direction (Terraria), but you engineer strictly vertical gravity-factory chains (the hook). Early on you are the logistics — mining by hand, hauling ore in your pack. Then you automate your own labor — ladders, lifts, elevators, auto-haulers — until the factory moves goods, and you, at scale. Deeper is richer is stronger. Part Factorio, part Terraria, all about conquering the dark by out-engineering it.*

> **v0.2 is a deliberate expansion** (2026-06-27) from "pure vertical-logistics prototype" to an **embodied, open-world, danger-gated industrial game.** The gravity-vertical production hook is UNCHANGED and remains the soul.

---

## Core Identity

**Genre:** Embodied 2D factory automation + exploration/survival, in an open destructible underworld
**Engine:** Godot 4.6.2 (GDScript)
**Platform:** macOS dev (M4 Pro) → Steam (Windows/Mac/Linux)
**Perspective:** Side-view; a character in a world; the camera lives at body-scale and pulls back to base-scale
**Scope:** Ambitious / flagship project
**Team:** Solo developer

---

## The Hook — Gravity Is Your Conveyor Belt (UNCHANGED)

Your **production** is vertical and gravity does the work. Raw ore enters at the top of a chain and falls through crushers, smelters, assemblers, refineries — each stage processing it further as it descends. This single decision drives everything:
- **Layout is a vertical puzzle** — you think in falls, drops, and lifts, not flat belt routing.
- **"Going deeper" is mechanical, not cosmetic** — your factory literally grows downward into the earth.
- **Power and lifting create tension** — gravity is free going down, but moving things (and yourself) UP costs energy.
- **Verticality compounds** — each stage feeds the one below; a bottleneck high up starves everything beneath it.

**The division of labor that makes the whole game cohere:** you **explore and dig FREELY** in any direction, but you **PRODUCE strictly vertically.** Horizontal space is for movement, housing, storage, and routing; vertical columns are where materials transform. Exploration is open; engineering is gravity-bound.

---

## The Body & The World (NEW IN v0.2)

- **You are a person down there.** Side-view platformer movement (walk, fall, jump, climb). The camera follows you; it pulls back when you're surveying your base.
- **The world is a large destructible underground** — wide AND deep, **dominated by solid, molded, ore-rich earth you mine and carve your factory INTO** (base safe by construction). This is **dig-your-factory, NOT follow-the-cave**: solid ≫ cave, ore frequent and organic (veins/blobs). Caves/dungeons/pockets-of-the-strange are KEPT but are the rarer, opt-in **punctuation** — located danger/reward/shrine-camps you *choose* to breach, not the medium you traverse. The factory is a *foothold* you grow inside a much bigger dark. (See PROGRESSION §10.)
- **You share physical space with your factory.** You walk among your machines and the falling ore — stand on platforms, ride lifts, get in the path of the flow. The production is happening *around your body*, not behind a god-cursor.
- **Why you're here: power & territory.** You descend to claim and industrialize more of the world. Deeper = richer materials = stronger you = more empire. The dopamine is conquest-by-engineering.

---

## The Pillars

1. **You automate your own labor.** Everything the factory does for you, you first did by hand. The arc from "I carry the ore" to "the elevator carries the ore and me" *is* the game. (Factorio's soul.)
2. **Every machine you place multiplies what's below.** Exponential scaling is structural, not bolted on.
3. **The factory runs without you — so you can go dig, explore, and fight.** Idle/automation frees your body for the frontier.
4. **Going deeper always reveals something that breaks your current setup.** New materials force redesigns; new dark forces new defenses. Comfort is temporary.
5. **You open the wall into danger on YOUR terms.** Threat is located and opt-in, never ambient harassment. The reward for danger is the tech that advances everything.
6. **"Just one more layer" at 2am.** The compulsion is the descent and the empire growing under your feet.

---

## Core Gameplay Loop (embodied)

```
       DIG / EXPLORE ──► HAUL IT BACK ──► BUILD A VERTICAL CHAIN ──┐
          ▲  (by hand early)   (your pack early)                    │
          │                                                          ▼
   CLAIM DEEPER / ◄── AUTOMATE YOUR LABOR ◄── TUNE & RESEARCH ◄──────┘
   BEAT A BOSS        (ladders→lifts→elevators→auto-haul)   (factory funds + unlocks)
   (for capstone tech)
```

1. **Dig & explore** — mine through earth to expose materials and new depth; open into caves/dungeons when you choose.
2. **Haul it back** — early game *you* carry ore in your inventory to where it's processed. This friction is the point: it's what you'll want to automate.
3. **Build a vertical chain** — place machines where you stand; raw material falls through them and transforms (the gravity hook).
4. **Tune & research** — balance throughput/power; your production unlocks the next tier of tech.
5. **Automate your labor** — replace your own hauling and climbing with ladders, lifts, elevators, auto-haulers. The factory now moves goods and *you*.
6. **Claim deeper / beat a boss** — descend for richer material; clear dungeons and defeat bosses to earn the pivotal capstones (the elevator blueprint, deep-dive gear) that gate the big leaps.

---

## The Manual → Automated Arc (the heart)

This is the spine of progression and the reason the game feels like *yours*:

| Stage | Movement | Hauling | Building |
|-------|----------|---------|----------|
| **Early** | mine & climb by hand; fall down, scramble up | carry ore in a limited pack, trip by trip | place one machine at a time, within arm's reach |
| **Mid** | ladders, ropes, platforms you built; first powered lift | drop-chutes and short lifts move material for you | reach extends; you build standing on your own scaffolds |
| **Late** | ride your own elevator network; traversal gear | automated haulers and elevators move goods at scale | lay out whole wings; the base hauls itself |

**Design rule:** never hand the player an automation they haven't first *missed by hand*. Friction pulls the tool — exactly our dev demand-pull rule, wearing a game-design hat. Two players won't converge on the same base, because *how* you automate your descent is an open optimization space.

---

## Vertical Factory Mechanics (production core — UNCHANGED)

### Gravity Flow
- Items fall through open vertical shafts. **Drop chutes** = free downward transport.
- **Splitters/mergers** direct falling items into different chains *(built — splitter divides a stream 50/50 down + sideways; see ARCHITECTURE).*
- **Catchers** stop falling items and feed a machine. **Lifts/elevators** move items (and you) UP for power — strategic friction.

### Machine Stacking & Lateral Routing
- Machines occupy vertical space and process items that pass through or into them; output drops to the next machine below.
- Not everything is a straight drop — limited lateral routing exists, but horizontal movement is slower/costlier, which preserves vertical-first thinking. The puzzle: fold a complex multi-input recipe into vertical space.

### Power System
- Machines consume power; lifts (of goods and of you) consume more. Power generation evolves with depth (surface → combustion → geothermal → exotic). Power is a parallel chain you must also automate.

---

## The Danger Model (NEW IN v0.2 — "you open the wall")

The elegant constraint that keeps combat from being annoying:

- **Your base is safe by construction.** Because you mine through *solid earth*, your carved tunnels and chambers have no open space for things to spawn or wander into. No creeper strolling in from a cave to grief your factory. Seal a tunnel and it's yours.
- **Danger is located, not ambient.** Threats live in **pre-existing caves**, **dungeons**, and **boss arenas** — discrete places you choose to breach. You decide when to open the wall into danger.
- **Danger pays in progression.** Dungeons drop quick loot; **bosses gate pivotal tech** — e.g., defeat the mid-game boss to earn the *elevator blueprint*. Combat and the factory feed each other: the factory arms and supplies you; combat unlocks the factory's next leap.
- **Tone:** survival pressure, earned and opt-in — not tower-defense harassment. (This deliberately **reopens** the previously-deferred hazards decision; see DECISIONS.)

---

## Progression / Tech Gating — Woven (all three)

No single gate; the three reinforce each other:
- **Factory-research (backbone)** — producing and researching with your factory unlocks most machine tiers and upgrades, Factorio-science style. The factory unlocks the factory.
- **Depth-reveals (the driver)** — descending exposes new *materials*, which feed research and force redesigns. Depth is the pull.
- **Boss/dungeon capstones (the turning points)** — a handful of pivotal unlocks (elevator, deep-dive gear, key blueprints) require beating a boss or clearing a dungeon. Combat delivers the leaps.

---

## Depth Layers (Progression Spine)

Each layer is a distinct "act" with new materials, a physics twist, and now its own *flavor of dark* (caves/dungeon/boss). The open world means a layer is a region you inhabit, not just a horizontal stripe.

| Depth | Layer Name | New Material(s) | Twist / New Mechanic |
|-------|-----------|-----------------|----------------------|
| 0 | Surface | Scrap, basic ore | Tutorial — establish dig + gravity-flow basics |
| 1 | Topsoil & Clay | Iron, copper, coal | First multi-stage chains (smelting); first caves |
| 2 | Bedrock | Stone, quartz | Power scaling; first lift needed; first dungeon |
| 3 | Crystal Veins | Crystalline ores | Heat management (stay cold) |
| 4 | The Wet Layer | Pressurized fluids | Liquid handling, pipes, flooding |
| 5 | Thermal Strata | Magma-adjacent ores | Heat as resource and threat; geothermal power |
| 6 | The Hollow | Exotic gas pockets | Gas processing, pressure |
| 7 | Compression Zone | Density-altered matter | Gravity behaves differently |
| 8 | The Glow | Bioluminescent/radioactive | Materials decay over time — throughput races |
| 9+ | The Sinkforge | ??? | Endgame — physics breaks down; megastructure assembly |

**Principle:** every layer must force a *reconsideration* of the existing factory, not just a bolted-on wing. New materials flow UP into earlier chains or pull earlier products DOWN, weaving the whole base together.

---

## The Idle / Automation Layer

Idle-ish, not a clicker. The twist in v0.2: automation frees your **body** for the frontier.
- **Active play:** digging, exploring, fighting, designing, optimizing, troubleshooting.
- **Passive generation:** tuned chains produce on their own while you're off claiming territory or away.
- **Offline progression:** the factory runs while you're gone (caps/buffers fill — a reason to return and expand).
- **Prestige-free:** no resets. Permanent vertical empire. The satisfaction is the growing machine and the growing claim.

---

## Open Design Questions (the organs that stay flexible)

Resolved enough to build around (see DECISIONS): embodied player ✓ · open destructible world ✓ · gravity-vertical production ✓ · shared physical space ✓ · manual→automated arc ✓ · located/opt-in danger ✓ · woven progression ✓ · power & territory pull ✓.

Deliberately still open — to be discovered through play, not pre-decided:
- [ ] **What is "the Sinkforge"?** Endgame narrative + mechanical payoff.
- [ ] **Story/setting:** who are you, why dig, how much narrative vs. sandbox.
- [ ] **Combat feel:** what fighting actually *is* (melee/ranged/tools-as-weapons), how the body fights.
- [ ] **World generation:** how the open underground is authored/generated; how big "big" is; cave/dungeon distribution.
- [ ] **Specific tech tree:** the actual unlock graph across the three woven gates.
- [ ] **Presentation:** art style, tile size, the camera's body-scale ↔ base-scale zoom, the visual language of flow.
- [ ] **Item-physics granularity at scale:** when discrete falling items hand off to abstract throughput (the locked hybrid rule governs; the *threshold* is open).

---

## Prototype Plan (v0.2 — embodied path)

> Prototype 1 (god-view vertical factory: vent → splitter → processor, deterministic node-free sim, cascade + conservation) is **built and playable** — it answered "does gravity-flow read and behave correctly?" Yes. The pivot reframes everything after it around the body.

### Prototype 2: Does the Embodied Dig-Build-Haul Loop Feel Good? *(current)*
The new core-feel question. Smallest embodied slices, each felt before the next:
- **P2·S1 — The body that digs:** a controllable character with platformer movement in the shaft; solid-earth cells you mine to clear; camera follows; the existing factory runs in the same space. *Test: does inhabiting and digging this world feel good?*
- **P2·S2 — Hands on materials:** mining yields ore to a carried inventory; you manually haul and feed it into a vent/machine to start a chain. *Test: is being the logistics satisfying (and tedious-in-a-good-way)?*
- **P2·S3 — Embodied building:** place/remove machines from your inventory only within reach of where you stand. *Test: does situated building beat the god-cursor?*

### Prototype 3: The First Automation You Earn
- Build the first labor-saver (ladder/lift) that removes a friction you felt in P2. *Test: does automating your own labor land as a real reward?*

### Prototype 4: Open the Wall
- One cave/dungeon pocket and a first boss that gates one capstone (the lift/elevator blueprint). *Test: is opt-in danger-for-tech a good gate?*

### Prototype 5+: Depth, Power, Idle
- Power as a constraint; a second depth layer with a new material that reweaves the chain; passive/offline generation. *Test: the full descend→reweave→automate→leave→return loop.*

---

*Document version 0.2 — embodied open-world pivot. Gravity-vertical production hook preserved; body, world, danger, and the automate-your-labor arc added. Skeleton settled; organs (story, combat feel, worldgen, art) intentionally open.*
