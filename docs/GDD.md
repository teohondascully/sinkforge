# Game Design Document

**Status:** normative. **Last revised:** 2026-08-27 (second pivot: run-based roguelite retired, back to a persistent single shaft — see §9). **Supersedes:** the archived `GDD.md`, `PROGRESSION.md`, `BAZAAR.md`, `MATERIAL_SPINE.md`, `LODE_PLAN.md`, `DIRECTOR_BRIEF.md`.

This document holds the design state. It is deliberately explicit about what is decided, what is open, what is dead, and what has already been ruled out and why. That last category matters most: several of the dead ideas are the obvious first answer to a real problem, and without a record they get reinvented within weeks.

**Confidence, stated so that readers know which parts are load-bearing.** §§1 to 4, 7, 9, 10 and 14 are constraints and hold regardless of what gets built. §5, §6, and §12 are the current best reasoning about a factory and a moment-to-moment loop that do not exist yet: they are provisional, and the first playable session should be expected to revise them. Where any section makes a claim about how the game will play, it should eventually be replaced by a claim file with a measured value. Until then it is a hypothesis with a paragraph of argument behind it, and it should not be defended as though it were a measurement.

---

## 1. Premise

**Sinkforge is a factory game with a persistent underground shaft and an idle game's progression curve.**

The player bores a shaft from a permanent surface rig, builds extraction and routing infrastructure inside it, and hauls refined material back up to satisfy demands waiting at the rig. There is no reset: the shaft the player is digging today is the same shaft they started on, deeper and more built-out than it was an hour ago. Satisfying a demand unlocks the next capability — a tool, a machine, access to a harder material — which is what lets the shaft go deeper still.

One shaft, one permanent rig, and they do different jobs:

- **The shaft is where the factory lives.** Chutes, drills, forges, pumps — built once, extended as depth demands more, never discarded wholesale. This is the logistics puzzle, and it only gets more contended as it grows.
- **The rig is the standing consumer.** It sits at the top, wants specific material in specific quantity per unlock, and is what turns "keep digging" into a reason rather than a default. This is what makes the factory necessary in the first place.

**The terrain is the factory.** The shape you dig is the routing — an aquifer where you wanted your main chute, a shale band eight tiles thick instead of two, ore forty meters further than the last vein. This is true regardless of whether the shaft resets; it never depended on runs, and it is the project's central identity claim (`CONTEXT.md` quotes it directly). What no longer holds is the claim that used to sit next to it — that every playthrough reshuffles the geology. There is one shaft now, so the terrain surprises the player exactly once, laterally, as they dig into ground nobody has touched yet. See §8 for the honest open question that leaves.

The emotional fantasy: descend into an unknown underground world and build the infrastructure that lets you reach places and resources you could not handle alone. An embodied engineer, not an omniscient factory planner.

**Reference points, worth playing before designing against this document:** Dome Keeper (dig down, haul up, run-based, feeding a persistent thing at the top) is the closest existing game to this structure. SteamWorld Dig 2 is the best-feeling dig platformer ever made and a better movement reference than Noita or Terraria.

**Why Noita is the wrong movement reference, precisely, and what to take instead.** Noita's collision is genuinely well-built — collision geometry derived from the pixel grid, not equal to it (`docs/ARCHITECTURE.md` §9 has the engineering detail) — but that is not where its frictionless feel comes from. Noita players do get stuck on single pixels; it's a documented complaint with a built-in unstuck mechanism. The feeling comes from flight: near-unlimited vertical mobility that deletes ground-traversal friction entirely rather than solving it. That answer isn't available here. A flying player breaks R1 outright — upward movement becomes free, lifts become pointless, the central asymmetry of the whole design evaporates — so it cannot be copied even partially. **The rope and grapple are this game's answer to the same problem, and should be treated as the vertical traversal primitive, not one feature among several.** Fast attach, fast climb, no fumbling, auto-anchor at shaft mouths, a dismount that doesn't fling the player, swing momentum worth chaining. If traversal ends up feeling great, it will be because the rope is great, not because collision is perfect — collision correctness is necessary, not sufficient, and design/engineering effort on movement should be allocated accordingly.

---

## 2. The genre synthesis

This section exists because the premise alone does not constrain enough. Each parent genre contributes something specific and each contributes something that must be refused.

**Two parent genres now, not three.** The roguelite lens — bounded sessions, run-to-run variety, the push-your-luck ending — is retired along with the run structure it described; see §9. What it was doing that still matters (constraint-driven variety, the terrain being the actual routing problem) moved to §1 and §9 rather than disappearing with it.

### From factory games

**Take:** ratio puzzles, throughput bottlenecks, the satisfaction of a line that runs without you, legible material flow through physical space.

**Refuse:** recipe-tree depth as the source of complexity. Factorio earns depth from forty hours of recipe graph. This project's complexity is meant to come from the spine, depreciation, and labor instead — a deliberate identity choice, not a limit imposed by session length. See §6.

**Refuse:** planar routing. In Factorio, if two things need a belt you build a second belt, because space is free. Here everything shares a few vertical lines and contention is the puzzle.

### From idle games

**Take:** the prestige feeling of blowing through content that used to be hard. Offline processing as a return hook. Numbers that get satisfyingly large.

**Refuse, absolutely: global multipliers.** This is the single most important prohibition in this document.

Factory games are ratio puzzles. Idle games are number puzzles. A global "+50% production" does not create a new ratio problem, it slides you along the same curve, and after ten of them the layout stops mattering. The game becomes an idle game wearing a factory costume.

There is no upgrade in Sinkforge whose effect is to multiply an existing rate. See §5 for what replaces them.

---

## 3. Why the pivot happened, and why the first fix was wrong

The previous design was a persistent world whose only material sink was a one-time descent gate. The game is therefore structurally complete the moment the first automated line exists, roughly fifteen minutes in. Every observed symptom (no reason to descend, machines with no motivating pain, a shop showing fifteen options before the player wants any) was downstream of that single absence.

An independent source-derived analysis in the prior repository reached the same diagnosis from the code side: the mid-tier production chain was a dead end and one material had become a de facto universal currency. Two independent paths to the same conclusion is the strongest evidence available that the read was correct.

**That diagnosis was right, and the fix that followed it was wrong by one word: the old game did not fail because it was persistent, it failed because its products were terminal.** The run-based structure supplied the missing demand, but it did so by deleting the factory every few minutes rather than by giving the factory somewhere to send its output. That is a fix that happens to work, not the actual cause treated.

**The rig is the consumer.** It sits at the top, wants specific material in specific quantity, and answers "then what?" the way Factorio's science packs do — a demand that always wants more, and wants new kinds as the player goes deeper. Nothing has to be lost to make that demand real; it has to be satisfied.

That answers the demand side. It does not, by itself, answer what pulls play in the minutes between demands being satisfied — see §12.

---

## 4. The four rules

### R1. Down is free, up is powered

Gravity moves material downward at zero cost, through excavated space. All upward movement consumes fuel per unit per meter, forever.

This is the central asymmetry. It makes the factory necessary (you cannot hand-carry enough), makes depth expensive (haul cost scales with distance), makes fuel the universal constraint, and gives the instrument a legible cost model to score against.

**Implementation note.** The prior codebase had no precedent for this: every upward mechanism used a proportional power throttle, a rate or capacity gate, never a per-unit or per-distance charge. New economic construction, not a tuning pass.

**Scope, decided 2026-08-26:** R1 governs every upward movement in principle, but the cost mechanism is wired only to the shaft-to-surface lift for now — internal in-shaft lifts stay free until this is revisited. The mechanism itself (per-unit-per-meter cost) is built general from the start so that extending the charge to internal movement is a data change, not a rewrite; see `docs/adr/0002-r1-scope-boundary-only.md` for the constraint this is meant to preserve.

**Corollary that is easy to get wrong.** If fuel is found above the player, gravity delivers it free and fuel logistics becomes trivial. Fuel must be found within or below the layer being worked, so the interesting problem is lateral distribution and metering.

### R2. Deep material is required, not more valuable

No exponential per-unit value by depth. Tier-N upgrades require tier-N material *and* large quantities of tier-1 material. The exponential lives in quantity required, which produces the idle-game curve while keeping every layer permanently relevant.

Ruled out: roughly 5x value per layer. It makes shallow material worthless, strands the surface refinery on deep material only, makes the early game — before hard rock is even reachable — feel like pure overhead rather than real progress, and kills all shallow content.

**Implementation note.** No value or price concept existed in the prior data model. R2 is greenfield recipe-quantity design.

### R3. Water is continuous upkeep, not a countdown

Groundwater seeps into every excavated section, always. Pump capacity is infrastructure the player builds and maintains, not a one-time purchase that buys more minutes before an ending. A well-pumped section stays dry indefinitely. A starved one floods, and the machines in it are wrecked — recovered as scrap at a fraction of their value, not simply lost.

**Why upkeep and not a timer.** A literal timer that unlocks longer sessions reads as artificial and feels like being told to stop playing. Water rising for a physical reason the player can push back against with infrastructure is still the right mechanism — it no longer forces play itself to end, it forces a *section* to be defended or written off. Pumping stays a continuous fuel sink that scales with depth, depth stays a real decision rather than a formality, and a section fighting its own waterline is still the game's best screenshot.

**Water kills machines, not the player.** It rises from the bottom of whatever section is under-pumped, so it eats that section's factory from the bottom up, which means the deepest, richest, most expensive production in a given section is always the first thing at risk. That tension is local and continuous now rather than a single curve per run, which is the right shape for something that never ends. Diving into a rising section to grab one last thing, or to pull a machine out before it drowns, is a voluntary risk that needs no health system.

**Implementation note.** The prior fluid system's design contract explicitly guarantees total water is invariant across a tick. Local flooding is a controlled source. Contain that violation to one clearly named function gated by section/pump state; do not thread it through the existing passes.

### R4. Every tool tier removes one skill and introduces another

Upgrades change the shape of the problem, not the numbers. A dug chute is free, lossy, and spills at junctions. A lined chute is lossless but rigid, so routes must be planned. A sorted chute introduces filtering decisions and jams. Each tier makes the old problem trivial and adds a new failure mode.

This is what gets twenty hours out of eight machines, and it is the mechanical expression of the no-multipliers prohibition in §2.

**This rule is closer to done than any other.** The prior repository already shipped a two-axis tool model along exactly these lines: a tier axis gating what material can be cut at all, and an interchangeable head axis changing what one action does, plus directional grain in the terrain. The mechanic does not need redesigning. Only its acquisition model moves, from research and shop purchase to rig upgrades and artifacts.

---

## 5. Meta-progression

Two axes. Neither is a multiplier.

| Axis | Currency | Effect |
|---|---|---|
| Verbs | Artifacts | Changes what layouts are possible |
| Surface rig | Material | Offline processing, the idle hook |

### Verbs, not tiers

Unlocks are new capabilities: the feeder, the pump, filtering, a chute liner, rope upgrades. Twenty verbs is a deep game. Twenty multipliers is a spreadsheet.

Where tiers exist at all, two per family maximum, with variants inside each tier that trade off against each other rather than strictly dominating. A strict tier ladder is a multiplier wearing a costume.

**Eight upgrade families**, roughly three to four items each, about twenty-eight unlocks total: extraction, routing, vertical transport, buffering, fuel, water, body, survey.

Two notes on specific families. **Body upgrades** (pack size, dig speed, climb speed, air, lantern radius) are the most satisfying early unlocks and should cap early, so that late game forces automation rather than making hauling viable at 200m. **Survey upgrades** (ore ping, strata map, ruin locator, waterline forecast) are the cheapest depth this design will ever get: information changes your entire build order and costs almost nothing to implement.

### The two currencies do different jobs

Material buys verbs, through rig demands: deliver what is asked for, unlock the next capability. Artifacts, found in deep ruins, unlock verbs too, through a different door.

This creates a second viable strategy rather than one optimal line. Sometimes mining straight down *is* correct: you spot a ruin at 140m, skip everything you could have extracted on the way, sprint, and grab the schematic instead. That is an **expedition** — a dive without building, trading a haul's worth of material for a verb you would otherwise wait on. It has a real cost rather than being a degenerate exploit, because you still need drills to punch through hard rock to get there.

### The idle loop

The surface rig processes raw material on a real clock while you are not playing, capped at a few hours' worth. You return to a full output buffer. This is the return hook.

Capped deliberately: uncapped offline production teaches players to wait instead of dig, which is the opposite of what this game wants.

**Unlock cadence must be decoupled from run cadence.** Three separate clocks so something is always resolving: purchases, artifacts found mid-run that apply immediately, and rig construction that completes on its own schedule. A structure where the player waits two hours for one dopamine event is a structure that loses the player.

---

## 6. Where the depth comes from

Recipe-tree depth alone isn't the source of complexity here, by choice — not because there isn't time to build one now that the shaft is persistent. Three sources are available here that Factorio does not have, and they are what let a shallow recipe graph feel deep anyway.

**The spine.** A vertical factory is a sequence, not a plane. Everything shares the same few vertical lines, so every new consumer at 90m contends with everything below it, and contention worsens as you descend rather than staying flat. Contention on a shared spine is a genuinely different puzzle from planar routing. This is the strongest mechanical asset in the design and it is currently unexploited.

**Depreciation.** Infrastructure has a lifespan wherever local water pressure outruns local pump capacity, because water is always coming for it from below. Every build decision is therefore an investment question: *is this drill deep enough to be at real flood risk, and will it pay back its fuel before the water reaches it?* A drill placed just past the current pump wall is a great investment. The same drill three unpumped sections deeper is resource that should have been spent hauling instead. No factory game asks this, because their structures are permanent and therefore always worth building. This turns a build order into an economics problem whose answer changes with how far the pump wall has been pushed, not with a clock.

Note that this property depends on whether machines can be carried out (see §8, open). Full retrieval collapses the calculus entirely.

**Labor.** Early, the player *is* a machine in their own factory. Every second hauling is a second not building. The point of automation is firing yourself from your own supply chain, which is a real allocation problem and makes automation emotionally legible in a way a research tree never does.

**Recipe depth is deliberately shallow and wide.** Three or four processing steps maximum. The unifying rule is that **every machine is a consumer, not just a producer**, so the factory is a distribution network under time pressure on a contended spine rather than a tree of recipes. That is deep with eight machines instead of eighty, which is the only version buildable solo.

**One decision carries more weight than any other in the material economy:** refined material is lighter per unit value than raw. So the player chooses between spending fuel and time below to reduce haul weight, or hauling raw and refining safely up top. That single choice makes the forge a logistics decision rather than a processing step.

---

## 7. Locked

Decided. Treat as requirements.

**Persistent, one shaft.** There is no session boundary and no reset. The shaft the player is digging today is the same shaft they started on.

**One permanent rig over one shaft.** The rig sits over a single bore that deepens and widens as the player digs. No fiction is needed for terrain regeneration, because nothing regenerates — the shaft is exactly what has been excavated, once, and stays that way.

**Material, not score.** What reaches the surface is physical material, spent as material. No abstract points, no currency, no shop. If you haul forty iron up, you have forty iron.

**Two currencies.** Material buys verbs, through rig demands. Artifacts unlock verbs too, through ruins. Nothing else.

**Progress is demand satisfied.** Not what was mined, not what is in a chute. What actually arrived at the rig and was consumed by a demand. The throughput of the haul chain is what drives that progress.

**The Sinkforge is a stratum, not an object.** At the bottom of the shaft, the player breaks through into a manufactured plane: machined metal extending past view in every direction, no center and no edges. It is the bottom of the world, and it is built. It has been consuming the crust from underneath for a long time — that is the sinkhole's origin, and the reason deposits get richer with depth: everything below has been in its collection longer. Its one interaction is the ending: it is the only material nothing in the toolset can cut, so the final unlock is not a better drill but a breach built from deep material, and reaching it is the endgame. It takes no action before then.

**No combat, no enemies, no health bar.** Danger is environmental and systemic. Scope decision as much as design decision.

---

## 8. Open

Do not architect around a specific answer. Each must be expressible as configuration or data. If switching would require touching logic, that is a design leak and should be reported.

**Whether lateral variety survives losing re-rolled geology.** §1 claims "the terrain is the factory" independent of runs, and that claim is true — but part of what made it a *differentiator* was that procedural geology used to reshuffle on every run. One persistent shaft rolls its geology once. Lateral variety now has to come from the un-mined extent of the one world — new material kinds forcing search sideways as much as down — rather than from re-rolled terrain. Whether that sustains interest the way the old differentiator did is unverified. This is the largest open question the reversal itself introduces, and it should be treated as one rather than assumed away. §12's Reveal layer is the first concrete, testable proposal against this question — not a resolution, a hypothesis with a cheap test attached; see `claims/C004-reveal-raises-dig-persistence.md`.

**Surface rig form.** A vertical factory built upward, mirroring the shaft, versus a small fixed deck with slots. The upward version is more distinctive, gives the game a silhouette (a growing tower above, a growing scar below), and uses the same puzzle language as the shaft with inverted economics: on the rig you have power, so up is cheap. It is also a second layout system, and its machine set must stay small, perhaps six.

**Machine retrieval, now a local question rather than a run-ending one.** Local flooding wrecks submerged machines into scrap recovered at a fraction of value (§6, depreciation). Whether a player can pull a machine out of a section before the water reaches it — full salvage, versus reduced scrap regardless of timing — determines how much the flood pressure actually bites. Full retrieval risks the same collapse the old run-ending version of this question named: if nothing is ever really lost, only delayed, depreciation stops being a real cost. The likely answer falls out of how expensive salvage/scrap recovery is tuned to be, which is a tunable rather than a fork — but it still needs a decision once the flood mechanics are actually built, not before.

**Branching.** See §9.

---

## 9. Dead, and why

Recorded so they are not reinvented. Each of these is the obvious first answer to a real problem.

**Global multipliers and percentage upgrades.** See §2. This is the one most likely to be reintroduced by good intentions, because it is what every idle game does and it is easy.

**The Sinkforge as a continuous consumer.** The idea: it sits at the bottom, eats material forever, and feeding it opens the way down. Fails on four counts. It is invisible from anywhere the player stands, so it cannot carry emotional weight. If everything sinks uniformly, nothing sinks. A continuous open column to the bottom is a ladder past every gate. And it fights the lateral relocation pressure that finite deposits create. It existed to solve the missing-sink problem in a persistent world; the run-based structure solved that without it, and its replacement (see below) solves it a different way. A consumer at the top of the shaft is a different object from a consumer at the bottom — it answers the same objections by sitting where the player already stands, above every gate instead of below it — and does not reintroduce this idea.

**A void with no floor.** The alternative to a physical Sinkforge: the shaft simply never ends, nothing is ever found at the bottom. Rejected — a limit a player can descend into forever without ever reaching it risks reading as unfinished content rather than a genuine boundary, since from inside the game the two are indistinguishable.

**The sinkhole itself is the Sinkforge, with nothing underneath.** The surface sinkhole the rig sits over and the Sinkforge would be the same fact, not two things — no deeper structure to find, the hole simply is it. Tonally strong: it explains itself the moment a player looks up from the bottom. But mechanically empty — there is nothing left to reach, nothing to describe, no shape for an ending. A destination has to be a place, not a fact already known.

**Chutes as the bulk path to the surface.** Physically impossible: chutes fall downward. This error invalidated a chain of dependent conclusions before it was caught.

**Exponential ore value by depth.** See R2.

**Combat, enemies, and guardians.** A second game with its own animation, balance, AI, and feel budget. It would move the identity from excavation and logistics to action, and it is not what makes this distinct.

**Per-run contracts and objectives.** Adds pressure and specificity; also turns the game into a chore list. Artifacts give the second axis without this cost.

**Terminal products with no standing demand, a one-time descent gate as the only material sink, a research-tree menu gating one-tier-deep tech, the Bazaar (as shop and as physical structure), currency, electricity as an early automation tier, waste and tailings, the mid-tier production chain with no demand behind it, horizontal boring.** Named by mechanism, not by property, on purpose (2026-08-27): this list used to open with "persistent-world progression," and a property name is exactly the kind of dead-list entry that eventually gets read as killing the property itself. **Persistence was never the defect — see §3.** What's dead here is the specific pre-pivot economy those mechanisms describe: terminal output, a single one-time gate, a shallow research-tree menu. The 2026-08-27 reversal (below) returned to a persistent shaft deliberately, and this entry does not contradict that.

**The seven-layer depth plan.** Reduced to three layers plus the core. It was never actually seven in the prior code; that number came from a document, not an implementation.

**Two items need a decision rather than automatic removal:**

*Branching.* The prior Splitter was the only branching mechanism and was documented in-repo as intentionally ungated core-loop infrastructure. Under the hole-is-a-conveyor philosophy, two carved chutes are a splitter and no machine is needed. That may be right, but it must be a stated decision, not a silent capability loss.

*Power gating.* The prior Generator was the only power source, and every upward-transport mechanism's cost depended on reading a nonzero power field. Removing power without deciding what replaces it does not break those machines; it silently freezes them at their unpowered throughput with no error. That is the worst failure class this project has. Power removal is entangled with R1's design and must happen in the same decision.

**One thing should be repurposed rather than deleted.** The prior long-distance haul machine's underlying mechanism, a throttled per-trip capacity plus a fixed transit duration linking two arbitrary cells, is the closest existing analog to the shaft-to-surface haul this design needs.

**Run-based roguelite structure, 2026-08-28.** Adopted to supply demand. It deleted the factory it was meant to serve and created five of seven open design holes. Replaced by rig-as-consumer. The diagnosis it responded to was correct; the fix was not. Keep "Sinkforge as continuous consumer" dead, and note that a consumer at the top is a different object from a consumer at the bottom. Constraint variety (per-shaft modifiers — floods fast, no fuel above 50m, hard rock starts early) does not survive as the primary source of long-tail variety it was under this structure; it might still exist as a post-breach mechanic once the game has an ending to build past, but that is unexplored, not designed.

---

## 10. The target first experience

This is the product. Everything else serves it.

**First five minutes.** The player moves and digs with no tutorial text. They find a Forge that already exists in the world, cold and ancient, with a mouth on top and a chute out the bottom, with one fuel unit already burning and one ore on the ground beside it. They pick up the ore, drop it in the mouth, get an ingot, and the fire goes out. Zero UI opened. The demonstration is a physical act they performed, not a message they read. Then they need both fuel and ore and have neither.

**First ten minutes.** They haul fuel by hand. Fine once, annoying twice. Then they realize they can dig a hole from the fuel source down to the Forge's intake and let gravity do it.

**That moment, discovering that a hole is a conveyor belt, is the single most important thing this design can produce.** It cannot happen if routing is a purchasable machine. Free excavated routing is therefore not a convenience, it is the core. Never place a tutorial prompt near it.

The first logistics failure follows immediately and is self-inflicted: fuel and ore down the same hole, jamming the intake. Visible in the world as a physical pile, with an obvious fix. (This is the Flow want-layer's first description, before it had that name — see §12.)

**Rules that fall out of this:**

- No machine exists that answers a pain the player has not personally felt, twice.
- The first automation is free and dug, not purchased.
- Recipes are excavated from ruins, not researched in a menu. Descending *is* the tech tree, and the player can never see options they have no reason to want.
- Every item on the ground is collectible by walking over it. An uncollectible pile is a broken promise about physicality, and it was the single most damaging defect in the prior build.
- Starved, jammed, and running are three distinct animations. Starved is the most important animation in the game.

**A worked sketch of how the curve should feel, for calibration only, not specification:**

*Hour 1.* Hand-dig to the shale/rock boundary. Find the forge. Learn the hole trick. Feel the first jam. Scrape together enough iron by hand, slowly, to satisfy the drill demand. Hard rock stops being a wall.

*Hour 5.* A small automated line feeds the forge, but haul is still mostly manual — every trip up the shaft is a decision, not a background process. Enough iron and copper cross the surface to satisfy the pump demand. The first section gets sealed dry.

*Hour 12.* Several pump-walled sections, a fuel chute that is functionally the entire economy, and a flood event that costs real material when it wins — a drill wrecked into scrap, a section that has to be re-dug rather than re-flooded. You understand the fuel chain is the game, the same realization the old run-based curve produced at its own equivalent point — the curve is slower now and has no artificial end, but the shape is the same.

Same shape at a different scale, which is precisely why idle games work.

---

## 11. Depth structure

Three layers plus the core. Each earns its existence with one physical rule and one economic consequence.

**Layers are rule sets, not destinations.** Depth is continuous and always increasing; there is no discrete jump from one layer to the next, only a depth threshold where the physical rule underfoot changes. A shaft does not "reach Stonereach" the way a level select reaches a zone — it just keeps getting deeper until hand-mining stops working. The same shaft can sit in the same layer at very different points in its own history: early on it might hand-dig to 60m and stall inside Topsoil/shale, while much later, with real infrastructure behind it, it carries on past 240m still inside that same rule set, because what changed is the infrastructure, not the layer. Meters measure how far the shaft has actually gotten. Layers describe which physical rules apply at the depth it currently is.

| Layer | Physical rule | Teaches |
|---|---|---|
| Topsoil / shale | Soft, fast digging. Fuel and first ore. Water seeps. | Gravity routing |
| Stonereach | Hard rock, hand-mining ineffective. Flooding is a real threat. Richer ore. | Pumping and fuel routing |
| The Deep Works | Engineered, not natural. Someone built here. Heat and pressure. | Long-distance haul |
| The Sinkforge | Manufactured, not natural — the true floor. Unreached in normal play. | Nothing, except an endgame breach. |

Three layers authored well beats seven gestured at.

**Why not just mine straight down?** Because hands stop working. Rock hardness is tiered and each tier is impassable without infrastructure, so depth is a function of how far down your supply chain reaches, not how long you hold the dig button. And depth is not the goal; material delivered is. Reaching the bottom with an empty pack is worth nothing.

**One gate on meta-progression, not two.** Material delivered buys verbs, through rig demands. There is no separate "deepest layer reached" gate anymore — it is implicit in what a demand requires: you cannot deliver copper without having gone through hard rock, so depth-gating falls out of the demand chain itself rather than a second currency layered on top of it. This kills the grind-shallow-forever exploit the same way as before: shallow material alone cannot satisfy a demand that needs a deeper material, at any quantity.

**Reaching the bottom and igniting it are one goal, not two.** Two endings in a game without a writer makes both feel thin.

---

## 12. The micro-loop: three want-layers underneath the macro-goal

**Finding, 2026-08-28: the design had a macro-loop and no micro-loop underneath it, and that gap — not anything in §§1-7 — is why an otherwise-correct rig-as-consumer structure would still not have been fun to play.** "Feed the rig" fires as a transaction: minutes apart, satisfying only at the moment of delivery. Between deliveries nothing pulls the player toward any particular next action over another, because nothing renews on a shorter cadence than the macro-goal itself. This does not revise §§1-7 — the rig is still the consumer, R1-R4 still hold — it names what those rules leave silent: a want, unlike a transaction, resolves and regenerates on its own cadence, independent of how far off the next delivery is, so there is always a small live question in front of the player. The macro-goal's job shrinks to giving those small wants a direction; it does not have to generate the wanting itself, any more than the ender dragon generates Minecraft's minute-to-minute pull. §3 diagnosed the previous design's actual defect correctly (terminal products, not persistence) and the rig-as-consumer fix was right as far as it went; this is the same kind of one-step-further correction, not a reversal.

**Pull-cadence reference points, not new parent genres.** §2 fixes two parent genres, factory and idle, for what this game takes and refuses mechanically. Minecraft and Factorio are cited below only for their pull CADENCE — how often a small want resolves and re-forms — not as a third genre to synthesize from. Compare: Minecraft's want ("what's in that cave / one more iron / night is coming") renews every 30-90 seconds on exploration, crafting, and threat. Factorio's ("that line's backed up / if I just fix this ratio") renews on watching an imperfect system. Sinkforge's, as designed through §7, renews only on "haul enough to satisfy the rig" — minutes apart, with a dead stretch between. §2's two-parent-genre decision is unchanged; this section is about tempo, not taxonomy.

**Three want-layers, stated with the confidence each currently deserves — hypotheses, like §5 and §6, not measurements:**

- **Reveal** ("what's behind this wall") — **cheapest, and the one under test now.** Procedural geology means every dig can expose something. This is §8's own largest open question ("whether lateral variety survives losing re-rolled geology... new material kinds forcing search sideways as much as down") given a concrete, testable form for the first time — see `claims/C004-reveal-raises-dig-persistence.md`. The terrain generator and debug renderer already exist; this needs content variety in generation and a reason to keep digging into the unknown, not a new system.
- **Flow** ("that's jammed, fix it") — **reframes, rather than solves, the throughput-survives-deletion question §6 leaves open.** §10 already describes this layer's first instance without naming it: "fuel and ore down the same hole, jamming the intake... Starved, jammed, and running are three distinct animations. Starved is the most important animation in the game." If gravity-routing can jam and back up, the satisfaction is in fixing the jam NOW, not in the factory surviving to the end of anything — so a persistent shaft's lack of a reset costs this layer nothing it depended on. Unbuilt: no routing-contention model exists yet beyond one hole into one intake.
- **Pressure** ("push deeper, or shore up") — **open, and the one most likely to be built wrong by default.** Water as a live threat, R3's mechanism, makes each stretch a small push-or-consolidate decision — Minecraft's nightfall, structurally. It only works with RHYTHM: arrives, gets dealt with, recedes, grants a calm stretch. Constant undifferentiated pressure is not tension, it is nagging, and it drowns the other two layers' claim on the player's attention. Whether water pulses or grinds is genuinely undecided — do not resolve it by building the grind version because it is simpler to implement. Unbuilt, and not scoped by this section.

**Why Reveal goes first and alone.** It is the one layer testable with what already exists — the terrain generator, `SplitRng`-seeded and deterministic, and the debug renderer — with no dependency on Flow or Pressure existing first. If digging-to-discover does not pull even with programmer-art placeholders, that is learned before a single demand is authored against the assumption that it does. Flow and Pressure stay hypotheses, named and confidence-marked, until it is their turn.

---

## 13. Automation progression

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

## 14. What must remain true regardless

- Embodied movement through the world.
- Vertical descent as the main structural progression.
- Gravity-based physical logistics.
- Factories that occupy and reshape real underground space.
- The relationship between personal traversal and automation.
- The game being evaluable by autonomous agents as part of its development process.

Machine names, UI structure, progression trees, lore, visual language, and economy are all open to revision. The untouchable part is the relationship between body, depth, excavation, and automation.
