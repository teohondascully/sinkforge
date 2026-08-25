# Game Design Document

**Status:** normative. **Last revised:** 2026-08-25 (pivot). **Supersedes:** the archived `GDD.md`, `PROGRESSION.md`, `BAZAAR.md`, `MATERIAL_SPINE.md`, `LODE_PLAN.md`, `DIRECTOR_BRIEF.md`.

This document holds the design state. It is deliberately explicit about what is decided, what is open, what is dead, and what has already been ruled out and why. That last category matters most: several of the dead ideas are the obvious first answer to a real problem, and without a record they get reinvented within weeks.

**Confidence, stated so that readers know which parts are load-bearing.** §§1 to 4, 7, 9, 10 and 13 are constraints and hold regardless of what gets built. §5 and §6 are the current best reasoning about a factory that does not exist yet: they are provisional, and the first playable run should be expected to revise them. Where any section makes a claim about how the game will play, it should eventually be replaced by a claim file with a measured value. Until then it is a hypothesis with a paragraph of argument behind it, and it should not be defended as though it were a measurement.

---

## 1. Premise

**Sinkforge is a factory game with a roguelite structure and an idle game's progression curve.**

The player bores a shaft from a permanent surface rig, builds extraction and routing infrastructure inside it, hauls refined material back up, and surfaces before the shaft floods. The shaft is lost. The material is spent on the rig, which extends and deepens the next run.

Two factories exist and they do different jobs:

- **The shaft factory is disposable and different every run.** Chutes, drills, forges, pumps, built fast under a clock, lost when the run ends. This is the logistics puzzle.
- **The surface rig is permanent and never lost.** It processes what you haul up and is optimized across dozens of runs. This is the long game.

The emotional fantasy: descend into an unknown underground world and build the infrastructure that lets you reach places and resources you could not handle alone. An embodied engineer, not an omniscient factory planner.

**Reference points, worth playing before designing against this document:** Dome Keeper (dig down, haul up, run-based, feeding a persistent thing at the top) is the closest existing game to this structure. SteamWorld Dig 2 is the best-feeling dig platformer ever made and a better movement reference than Noita or Terraria.

**Why Noita is the wrong movement reference, precisely, and what to take instead.** Noita's collision is genuinely well-built — collision geometry derived from the pixel grid, not equal to it (`docs/ARCHITECTURE.md` §9 has the engineering detail) — but that is not where its frictionless feel comes from. Noita players do get stuck on single pixels; it's a documented complaint with a built-in unstuck mechanism. The feeling comes from flight: near-unlimited vertical mobility that deletes ground-traversal friction entirely rather than solving it. That answer isn't available here. A flying player breaks R1 outright — upward movement becomes free, lifts become pointless, the central asymmetry of the whole design evaporates — so it cannot be copied even partially. **The rope and grapple are this game's answer to the same problem, and should be treated as the vertical traversal primitive, not one feature among several.** Fast attach, fast climb, no fumbling, auto-anchor at shaft mouths, a dismount that doesn't fling the player, swing momentum worth chaining. If traversal ends up feeling great, it will be because the rope is great, not because collision is perfect — collision correctness is necessary, not sufficient, and design/engineering effort on movement should be allocated accordingly.

---

## 2. The genre synthesis

This section exists because the premise alone does not constrain enough. Each parent genre contributes something specific and each contributes something that must be refused.

### From factory games

**Take:** ratio puzzles, throughput bottlenecks, the satisfaction of a line that runs without you, legible material flow through physical space.

**Refuse:** recipe-tree depth as the source of complexity. Factorio earns depth from forty hours of recipe graph. A forty-minute run cannot, so depth has to come from somewhere structurally different. See §6.

**Refuse:** planar routing. In Factorio, if two things need a belt you build a second belt, because space is free. Here everything shares a few vertical lines and contention is the puzzle.

### From roguelites

**Take:** bounded sessions, procedural variety, meta-progression, the push-your-luck moment at the end of a run.

**Refuse:** run-to-run randomness as the only variety. After fifteen runs the geology stops surprising anyone. Long-tail variety comes from **constraints**, not content: one modifier per shaft (this one floods fast, no fuel above 50m, hard rock starts early). Each is an afternoon of work and they compose. Constraint variety beats content variety by an order of magnitude in cost per hour of play.

**The reason roguelite structure fits this game specifically, and does not fit factory games generally:** in most factory games terrain barely matters. Ore patches are a rounding error against a flat infinite plane, which is exactly why nobody has made a good roguelite Factorio: randomizing the map does not change your build.

**Here the terrain is the factory.** The shape you dig is the routing. So procedural geology directly rewrites your layout every run: ore at 60m on the left instead of 30m on the right, an aquifer where you wanted your main chute, a shale band eight tiles thick instead of two. You cannot run the same build twice.

That is the differentiator. Not gravity by itself. **Gravity plus procedural excavation means the layout problem is fresh every run.**

### From idle games

**Take:** the prestige feeling of blowing through content that used to be hard. Offline processing as a return hook. Numbers that get satisfyingly large.

**Refuse, absolutely: global multipliers.** This is the single most important prohibition in this document.

Factory games are ratio puzzles. Idle games are number puzzles. A global "+50% production" does not create a new ratio problem, it slides you along the same curve, and after ten of them the layout stops mattering. The game becomes an idle game wearing a factory costume.

There is no upgrade in Sinkforge whose effect is to multiply an existing rate. See §5 for what replaces them.

---

## 3. Why the pivot happened

The previous design was a persistent world whose only material sink was a one-time descent gate. The game is therefore structurally complete the moment the first automated line exists, roughly fifteen minutes in. Every observed symptom (no reason to descend, machines with no motivating pain, a shop showing fifteen options before the player wants any) was downstream of that single absence.

An independent source-derived analysis in the prior repository reached the same diagnosis from the code side: the mid-tier production chain was a dead end and one material had become a de facto universal currency. Two independent paths to the same conclusion is the strongest evidence available that the read was correct.

The run-based structure supplies the missing demand without inventing a new sink: **the run itself is the sink.** Everything built inside a shaft is spent to reach depth, and the shaft is lost.

---

## 4. The four rules

### R1. Down is free, up is powered

Gravity moves material downward at zero cost, through excavated space. All upward movement consumes fuel per unit per meter, forever.

This is the central asymmetry. It makes the factory necessary (you cannot hand-carry enough), makes depth expensive (haul cost scales with distance), makes fuel the universal constraint, and gives the instrument a legible cost model to score against.

**Implementation note.** The prior codebase had no precedent for this: every upward mechanism used a proportional power throttle, a rate or capacity gate, never a per-unit or per-distance charge. New economic construction, not a tuning pass.

**Open sub-question:** does R1 govern every upward movement inside the shaft, or only the shaft-to-surface boundary? The rule as written says every. The cheaper first implementation is the boundary only. Decide before building, record as an ADR.

**Corollary that is easy to get wrong.** If fuel is found above the player, gravity delivers it free and fuel logistics becomes trivial. Fuel must be found within or below the layer being worked, so the interesting problem is lateral distribution and metering.

### R2. Deep material is required, not more valuable

No exponential per-unit value by depth. Tier-N upgrades require tier-N material *and* large quantities of tier-1 material. The exponential lives in quantity required, which produces the idle-game curve while keeping every layer permanently relevant.

Ruled out: roughly 5x value per layer. It makes shallow material worthless, strands the surface refinery on deep material only, turns every run that fails to reach depth into a zero, and kills all shallow content.

**Implementation note.** No value or price concept existed in the prior data model. R2 is greenfield recipe-quantity design.

### R3. Run length is a purchased resource

The rig's pump capacity determines how long a shaft holds before flooding. Session length becomes diegetic and progression legible, and run length grows from very short to long without a menu-unlocked timer.

**Why the flood and not a timer.** A literal timer that unlocks from 15 to 40 minutes reads as artificial and feels like being told to stop playing. Water rising from below ends the run for a physical reason the player can push back against with infrastructure. It also gives the design several things at once: pumping is a continuous fuel sink that scales with depth, depth becomes a real decision rather than a formality, and a rising waterline in a cross-section shaft is the game's best screenshot.

**Water kills machines, not the player.** It rises from the bottom, so it eats the factory from the bottom up, which means the deepest, richest, most expensive production is always the first thing lost. That tension curve is automatic and it is the right one. Diving below the waterline to grab one last thing is a voluntary risk that needs no health system.

**Implementation note.** The prior fluid system's design contract explicitly guarantees total water is invariant across a tick. A flood clock is a controlled source. Contain that violation to one clearly named function gated by run state; do not thread it through the existing passes.

### R4. Every tool tier removes one skill and introduces another

Upgrades change the shape of the problem, not the numbers. A dug chute is free, lossy, and spills at junctions. A lined chute is lossless but rigid, so routes must be planned. A sorted chute introduces filtering decisions and jams. Each tier makes the old problem trivial and adds a new failure mode.

This is what gets twenty hours out of eight machines, and it is the mechanical expression of the no-multipliers prohibition in §2.

**This rule is closer to done than any other.** The prior repository already shipped a two-axis tool model along exactly these lines: a tier axis gating what material can be cut at all, and an interchangeable head axis changing what one action does, plus directional grain in the terrain. The mechanic does not need redesigning. Only its acquisition model moves, from research and shop purchase to rig upgrades and artifacts.

---

## 5. Meta-progression

Three axes. None of them is a multiplier.

| Axis | Currency | Effect |
|---|---|---|
| Starting depth and loadout | Material | Compresses the early run |
| Verbs | Artifacts | Changes what layouts are possible |
| Surface rig | Material | Offline processing, the idle hook |

### Starting depth is the prestige bar

Run 1: you start at the surface with nothing and spend six minutes hand-mining topsoil.
Run 12: you start with a pre-sunk 40m shaft, a forge already lit at the bottom, one drill in your pack. Those six minutes are gone.
Run 30: you start at 100m with a working two-drill line and a chute already running to the surface bin. Your run begins where run 1 ended.

That is prestige structure applied to a factory, and it delivers the idle-game feeling without touching a single ratio. The layout puzzle stays intact because the puzzle just moved deeper.

**Starting deep compresses content, it does not skip it.** Riding the rig's bore past your old depths at speed is the prestige feeling. Deleting the shallow layers from play is not.

### Verbs, not tiers

Unlocks are new capabilities: the feeder, the pump, filtering, a chute liner, rope upgrades. Twenty verbs is a deep game. Twenty multipliers is a spreadsheet.

Where tiers exist at all, two per family maximum, with variants inside each tier that trade off against each other rather than strictly dominating. A strict tier ladder is a multiplier wearing a costume.

**Eight upgrade families**, roughly three to four items each, about twenty-eight unlocks total: extraction, routing, vertical transport, buffering, fuel, water, body, survey.

Two notes on specific families. **Body upgrades** (pack size, dig speed, climb speed, air, lantern radius) are the most satisfying early unlocks and should cap early, so that late game forces automation rather than making hauling viable at 200m. **Survey upgrades** (ore ping, strata map, ruin locator, waterline forecast) are the cheapest depth this design will ever get: information changes your entire build order and costs almost nothing to implement.

### The two currencies do different jobs

Material buys capacity. Artifacts, found in deep ruins, unlock verbs.

This creates a second viable strategy rather than one optimal line. Sometimes mining straight down *is* correct: you spot a ruin at 140m, skip extraction entirely, sprint, grab the schematic, take a terrible material score, and come back with a new verb unlocked. That is a **dive run**, and it has a real cost rather than being a degenerate exploit, because you still need drills to punch through hard rock to get there.

### The idle loop

The surface rig processes raw material on a real clock while you are not playing, capped at a few hours' worth. You return to a full output buffer. This is the return hook.

Capped deliberately: uncapped offline production teaches players to wait instead of dig, which is the opposite of what this game wants.

**Unlock cadence must be decoupled from run cadence.** Three separate clocks so something is always resolving: purchases between every run including the two-minute ones, artifacts found mid-run that apply immediately, and rig construction that completes on its own schedule. A structure where the player waits two hours for one dopamine event is a structure that loses the player.

---

## 6. Where the depth comes from

A forty-minute factory cannot earn depth the way a forty-hour one does. Three sources are available here that Factorio does not have, and they are what makes the short-session structure viable rather than merely convenient.

**The spine.** A vertical factory is a sequence, not a plane. Everything shares the same few vertical lines, so every new consumer at 90m contends with everything below it, and contention worsens as you descend rather than staying flat. Contention on a shared spine is a genuinely different puzzle from planar routing. This is the strongest mechanical asset in the design and it is currently unexploited.

**Depreciation.** Infrastructure has a lifespan, because water is coming for it from below. Every build decision is therefore an investment question: *will this drill pay back its fuel and my two minutes before it drowns?* At minute 8 a deep drill is a great investment. At minute 33 the same drill is resource you should have spent hauling. No factory game asks this, because their structures are permanent and therefore always worth building. This turns a build order into an economics problem whose answer changes minute to minute.

Note that this property depends on whether machines can be carried out (see §8, open). Full retrieval collapses the calculus entirely.

**Labor.** Early, the player *is* a machine in their own factory. Every second hauling is a second not building. The point of automation is firing yourself from your own supply chain, which is a real allocation problem and makes automation emotionally legible in a way a research tree never does.

**Recipe depth is deliberately shallow and wide.** Three or four processing steps maximum. The unifying rule is that **every machine is a consumer, not just a producer**, so the factory is a distribution network under time pressure on a contended spine rather than a tree of recipes. That is deep with eight machines instead of eighty, which is the only version buildable solo.

**One decision carries more weight than any other in the material economy:** refined material is lighter per unit value than raw. So the player chooses between spending fuel and time below to reduce haul weight, or hauling raw and refining safely up top. That single choice makes the forge a logistics decision rather than a processing step.

---

## 7. Locked

Decided. Treat as requirements.

**Run-based, not persistent world.** A session is a bounded expedition with a defined end.

**One permanent rig over one enormous sinkhole.** Each run bores a fresh shaft into a different part of it. New geology every run without a fiction for terrain regeneration; lateral variety without relocating the base.

**Material, not score.** A run's output is physical material delivered to the surface, spent as material. No abstract points, no currency, no shop. If you haul forty iron up, you have forty iron.

**Two currencies.** Material buys capacity. Artifacts unlock verbs. Nothing else.

**Score is what is in the surface bin when the run ends.** Not what was mined, not what is in a chute. What actually arrived. The throughput of the haul chain *is* the score rate.

**No zeroes.** Pack contents are always kept. No run in a bounded-session game should be worth nothing; that is how players are lost permanently.

**The Sinkforge is a horizon, not a mechanic.** It is at the bottom. Nobody has reached it. Deepest run is a record. It does not consume, pull, or act on the world.

**No combat, no enemies, no health bar.** Danger is environmental and systemic. Scope decision as much as design decision.

---

## 8. Open

Do not architect around a specific answer. Each must be expressible as configuration or data. If switching would require touching logic, that is a design leak and should be reported.

**Run cadence: Draft A or Draft C.** The largest open question.

*Draft A, escalating runs.* Length grows with purchased pump capacity: roughly 2, 3, 5, 8, 12, 20, 30, 40 minutes across about twenty-five runs. Sketch of the intended shape: first ingot around minute five of total playtime, first machine placed on the rig around minute eight, first automation in the shaft around minute twenty-five after roughly five separate purchases. Front-loaded reward cadence, which matters enormously: a fixed forty-minute structure delivers one progression event in the time Draft A delivers five. The opening is replayed and mastered rather than authored once and abandoned. Early runs are cheap to sweep, which serves the instrument directly.

Risks: a two-minute run may read as a menu with a walk attached, and this is unverified; the factory is absent from the shaft for the first twenty minutes of play (mitigated by placing the rig factory in front of the player at minute eight); twenty-five differently-lengthed runs is a large tuning surface.

*Draft C, fixed short runs.* Every run is ten to twelve minutes. Depth comes from starting deeper and better tools. Constant cadence, no length-tuning problem, much less content risk. Risk: ten minutes may cap layout complexity, and the game may never deliver the long sustained build that makes factory games feel like factory games.

They share nearly all machinery. A collapses to C by flattening the curve. Build A, keep C as a data-only fallback.

**Surface rig form.** A vertical factory built upward, mirroring the shaft, versus a small fixed deck with slots. The upward version is more distinctive, gives the game a silhouette (a growing tower above, a growing scar below), and uses the same puzzle language as the shaft with inverted economics: on the rig you have power, so up is cheap. It is also a second layout system, and its machine set must stay small, perhaps six.

**Machine retrieval.** Whether the player can carry placed machines out of a flooding shaft. Determines whether depreciation exists (see §6). Retrieval creates the best final two minutes available in the design: rich material in one hand, an expensive drill in the other, water rising, pick one. It also competes with material for the same pack, which is good tension. But full retrieval collapses the investment calculus.

**Run termination.** Flood reaching the deck (forced) versus voluntary extraction. Both work; they produce different games. Note that voluntary cash-out plus a good haul at minute twelve makes short farming runs optimal, which dissolves the structure. If voluntary, something must make late minutes disproportionately valuable.

**Branching.** See §9.

---

## 9. Dead, and why

Recorded so they are not reinvented. Each of these is the obvious first answer to a real problem.

**Global multipliers and percentage upgrades.** See §2. This is the one most likely to be reintroduced by good intentions, because it is what every idle game does and it is easy.

**The Sinkforge as a continuous consumer.** The idea: it sits at the bottom, eats material forever, and feeding it opens the way down. Fails on four counts. It is invisible from anywhere the player stands, so it cannot carry emotional weight. If everything sinks uniformly, nothing sinks. A continuous open column to the bottom is a ladder past every gate. And it fights the lateral relocation pressure that finite deposits create. It existed to solve the missing-sink problem in a persistent world; the run-based structure solves that without it.

**Chutes as the bulk path to the surface.** Physically impossible: chutes fall downward. This error invalidated a chain of dependent conclusions before it was caught.

**Exponential ore value by depth.** See R2.

**Combat, enemies, and guardians.** A second game with its own animation, balance, AI, and feel budget. It would move the identity from excavation and logistics to action, and it is not what makes this distinct.

**Per-run contracts and objectives.** Adds pressure and specificity; also turns the game into a chore list. Artifacts give the second axis without this cost.

**Persistent-world progression, the Bazaar (as shop and as physical structure), currency, the research tree as a menu, the descent gate as a one-time toll, electricity as an early automation tier, waste and tailings, the mid-tier production chain with no demand behind it, horizontal boring.**

**The seven-layer depth plan.** Reduced to three layers plus the core. It was never actually seven in the prior code; that number came from a document, not an implementation.

**Two items need a decision rather than automatic removal:**

*Branching.* The prior Splitter was the only branching mechanism and was documented in-repo as intentionally ungated core-loop infrastructure. Under the hole-is-a-conveyor philosophy, two carved chutes are a splitter and no machine is needed. That may be right, but it must be a stated decision, not a silent capability loss.

*Power gating.* The prior Generator was the only power source, and every upward-transport mechanism's cost depended on reading a nonzero power field. Removing power without deciding what replaces it does not break those machines; it silently freezes them at their unpowered throughput with no error. That is the worst failure class this project has. Power removal is entangled with R1's design and must happen in the same decision.

**One thing should be repurposed rather than deleted.** The prior long-distance haul machine's underlying mechanism, a throttled per-trip capacity plus a fixed transit duration linking two arbitrary cells, is the closest existing analog to the shaft-to-surface haul this design needs.

---

## 10. The target first experience

This is the product. Everything else serves it.

**First five minutes.** The player moves and digs with no tutorial text. They find a Forge that already exists in the world, cold and ancient, with a mouth on top and a chute out the bottom, with one fuel unit already burning and one ore on the ground beside it. They pick up the ore, drop it in the mouth, get an ingot, and the fire goes out. Zero UI opened. The demonstration is a physical act they performed, not a message they read. Then they need both fuel and ore and have neither.

**First ten minutes.** They haul fuel by hand. Fine once, annoying twice. Then they realize they can dig a hole from the fuel source down to the Forge's intake and let gravity do it.

**That moment, discovering that a hole is a conveyor belt, is the single most important thing this design can produce.** It cannot happen if routing is a purchasable machine. Free excavated routing is therefore not a convenience, it is the core. Never place a tutorial prompt near it.

The first logistics failure follows immediately and is self-inflicted: fuel and ore down the same hole, jamming the intake. Visible in the world as a physical pile, with an obvious fix.

**Rules that fall out of this:**

- No machine exists that answers a pain the player has not personally felt, twice.
- The first automation is free and dug, not purchased.
- Recipes are excavated from ruins, not researched in a menu. Descending *is* the tech tree, and the player can never see options they have no reason to want.
- Every item on the ground is collectible by walking over it. An uncollectible pile is a broken promise about physicality, and it was the single most damaging defect in the prior build.
- Starved, jammed, and running are three distinct animations. Starved is the most important animation in the game.

**A worked sketch of how the curve should feel, for calibration only, not specification:**

*Run 1.* Hand-dig to 30m. Find the forge. Learn the hole trick. Water arrives at minute 30 with no pump. Climb out with a small haul of shallow material. Unlock the pump.

*Run 8.* Start at 25m with a forge. Through shale in eight minutes. Hit hard rock at 80m and stop cold, because a single drill cannot be fueled fast enough at that distance. Spend the middle of the run building the fuel chute, get four minutes of extraction, water takes it. You now understand that the fuel chain is the game.

*Run 25.* Start at 100m with a running line. Spend the first ten minutes not mining at all, building a pump wall at 180m to hold a section dry. Punch into the deep layer at 210m. The water climbs while two pumps and a heavy drill run off one chute that is now your entire economy. At minute 36 the pump starves, the section floods in twelve seconds, and you sprint up the rope with a full pack.

Same shape at a different scale, which is precisely why idle games work.

---

## 11. Depth structure

Three layers plus the core. Each earns its existence with one physical rule and one economic consequence.

| Layer | Physical rule | Teaches |
|---|---|---|
| Topsoil / shale | Soft, fast digging. Fuel and first ore. Water seeps. | Gravity routing |
| Stonereach | Hard rock, hand-mining ineffective. Flooding is a real threat. Richer ore. | Pumping and fuel routing |
| The Deep Works | Engineered, not natural. Someone built here. Heat and pressure. | Long-distance haul |
| The Sinkforge | The bottom. Unreached. | Nothing. It is a horizon. |

Three layers authored well beats seven gestured at.

**Why not just mine straight down?** Because hands stop working. Rock hardness is tiered and each tier is impassable without infrastructure, so depth is a function of how far down your supply chain reaches, not how long you hold the dig button. And depth is not the score; material delivered is. A dive to the bottom with an empty pack is worth nothing.

**Two gates on meta-progression, pointing the same direction.** Material delivered is the soft currency and buys verbs. Deepest layer reached is the hard gate and determines which verbs are purchasable at all. This kills the grind-shallow-forever exploit twice over: shallow material is worth little, and shallow runs cannot unlock deep tech at any price.

**Reaching the bottom and igniting it are one goal, not two.** Two endings in a game without a writer makes both feel thin.

---

## 12. Automation progression

```
hands
→ holes            gravity routing. free. dug, not built.
→ buffers          time-shifted labor. no power.
→ burners          consume fuel routed by hand
→ fuel chutes      routing feeding routing. the first real system.
→ vertical return  the first thing that costs continuously
→ metered flow     solutions to problems the player created
→ heat or steam    the first thing that generates rather than consumes
→ freight          long-distance, expensive, permanent
```

Note position two: the free thing. The player's first automation should be a hole they dug, not a machine they bought.

Electricity does not appear for hours, and possibly never.

**Routing primitives, three only.** Chute (excavated space, free, direction is the shape of the dig). Bin (buffers N, releases at rate R, fill level visible from outside). Feeder (the only thing that moves an item sideways or up one cell, costs fuel, scarce by design). Filtering appears only after a player has merged two streams and jammed something. It is a fix, not a feature.

**Three hard rules for routing.** Every item is always visible at item scale and always collectible by walking over it. A blocked machine is legible from ten meters without a tooltip. No machine has hidden internal inventory; if it holds material, the material renders on the outside.

**Self-fueling should be possible and should cost.** A drill feeding its own fuel chain requires splitting the output and returning a fraction uphill, which costs a feeder. Real puzzle, terminates, feels earned. Not an accidental infinite loop.

---

## 13. What must remain true regardless

- Embodied movement through the world.
- Vertical descent as the main structural progression.
- Gravity-based physical logistics.
- Factories that occupy and reshape real underground space.
- The relationship between personal traversal and automation.
- The game being evaluable by autonomous agents as part of its development process.

Machine names, UI structure, progression trees, lore, visual language, and economy are all open to revision. The untouchable part is the relationship between body, depth, excavation, and automation.
