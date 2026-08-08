# PROGRESSION — the Sinkforge spine

> **Update 2026-07-11:** §5's research engine is BUILT (first slice) — the Bazaar bench + the L1 tech
> ladder (`automation` → `power` → `descent`), analyze-the-new + ingot price, sim-gated crafting, in the
> tutorial chain. **§2/§9's first GATE is BUILT too:** THE SEAL (unbreakable worldgen band at rows 56-57)
> + the DESCENT ENGINE (feed it 40 gravity-dropped ingots on the seal → it breaches into Stonereach,
> where IRON waits) — the throughput wall is live and RUNG-2 play-tested. See `ResearchRules`,
> `_run_descent`, DECISIONS 2026-07-11. The rest below remains design.

> **Status: DESIGNED (2026-06-28), via a guided brainstorm with the user. Not yet built.** This is the
> progression backbone the whole game hangs on — the resolution of the long-open "what is the Sinkforge /
> tech graph / endgame" questions (GDD Open Questions; DECISIONS same date). It UNBLOCKS the crafter
> modules and ore quality (both were waiting on a recipe graph). Two sub-systems are deliberately still
> open and get their own brainstorm before they're built: **combat feel** and **power mechanics** (below).
> Everything here is provisional/reversible per our working model — names, counts, and per-layer twists can
> change; the SHAPE is what's locked.

## 1. Destination — "Forge & ignite the Sinkforge"

The Sinkforge is a colossal final machine at the very bottom of the world — a world-spanning gravity-
foundry. You spend the game descending toward it, and the climax is not a sword fight but a **factory-as-
weapon siege**: assembling the Sinkforge and *igniting* it wakes a world-threat, and your fully-automated
empire must feed / power / defend the ignition through a final throughput crescendo to win. Fuses three
endings — build-the-megastructure (Factorio rocket), boss-gated descent (Minecraft), and factory-as-weapon
— into one. (Chosen over: pure descent-to-core, pure build-the-machine, endless sandbox.)

## 2. The core loop — and why the factory is MANDATORY (the anti-speedrun lock)

The failure mode we explicitly designed against: if a depth gate opened for a *sample* of the new material,
the optimal play would be to hand-mine the minimum and speedrun down — gutting the factory premise. Fix:
descending **demands throughput and continuity**, the way Factorio's rocket + biters + science do. Three
drivers; the first two are core (they kill the speedrun with pure logistics, no combat needed):

1. **Gates are throughput WALLS, not sample checks.** Analyzing the new material unlocks the *recipe*;
   *opening the gate* consumes **volume** — you build and feed a **Descent Engine** (a drill-rig / pressure-
   lock) thousands of refined goods to breach to the next layer. A guardian is a siege you out-produce, not
   a token check. The **finite-deposit system already enforces this**: deep deposits are rich but hand-
   mining is punishingly slow per cell, so only **drill arrays + automation** pull the tonnage a gate
   demands. The speedrun is mechanically impossible.
2. **Depth is a continuous SUPPLY problem.** From L2 (power) on, staying deep costs upkeep — power, cooling
   (L4), waterproofing (L3), gravity-stabilization (L5), light. The deeper your frontier, the bigger the
   **supply line your factory feeds down to it.** And the hook does the work: **gravity carries your output
   DOWN for free**, so *your factory's reach literally is how deep you can survive.* Stop producing and the
   frontier becomes untenable and you're pushed back up. You don't visit the factory — you live off it.
3. **Resistance scales with greed** (the threat model — see §6).

So the loop is: **establish a production base → it powers/supplies/defends your descent and produces the
volume to breach the gate → push the frontier deeper → the new layer's twist demands more & harder
production → expand the factory → repeat, richer each time.** The factory is the engine of survival and
descent. *Why do you need a factory? Because the gate won't open for a sample, and the deep won't let you
stay without a supply line you can't hand-carry.* This also makes **factory-as-weapon present from L2
onward**, setting up the finale instead of springing it.

## 3. The driver — depth-spine, research + boss locks

Of the three woven strands (depth · research · bosses), **depth leads**; research and a boss are the two
**locks on each gate**. You're always descending toward the Sinkforge; to breach a layer you must both
**research its key tech** (built from its new materials) AND **out-produce its guardian**. Every research
unlock and every boss exists to open the next depth. (Chosen over research-spine / boss-spine / parallel.)

## 4. The ladder — each layer rewrites the gravity/logistics puzzle

~5 physics-twist layers + the core. The **twist** is the creative engine: each layer forces the factory to
evolve, which no other factory game does. (Chosen over a danger-only ladder, a 4-dense hybrid, a tight
3-zone arc.) Names/materials provisional.

| Layer | Signature material | The twist | Guardian | Analyzing it unlocks |
|---|---|---|---|---|
| **L1 Topsoil** *(built)* | earth · wood · copper ore | baseline free-fall conveyor; by-hand → first drill/lift; the Bazaar | — (tutorial) | the basics + block-building |
| **L2 Stonereach** | iron ore · coal | **POWER arrives** — drills/lifts/machines draw power; build & route a generator | **the Stonewarden** | the power branch + plate/gear press modules |
| **L3 The Aquifer** | tideglass · water · lava | **fluid logistics** — channel/pump liquids; steam power; flooding | **a leviathan** | pumps/pipes, steam power, waterproofing |
| **L4 The Magma Belt** | emberite · obsidian | **heat** — ambient heat damages gear; cooling; superalloys only forgeable here | **a forge-titan** | heat shielding + superalloys |
| **L5 The Hollow** | voidstone (anti-grav) | **gravity fluctuates** — items drift, don't fall straight; gravity-stabilizers | **a void guardian** | gravity-tech (to build & run the Sinkforge) |
| **L6 Sinkforge Core** | forgeheart | assemble the **Sinkforge**, then **ignite** → the factory-as-weapon siege | **the ignition siege** | victory |

**Power stops being deferred** — it is the L2 twist, the first real wall, and the lift's long-intended
throughput governor lands here. (Its exact mechanics are an open sub-brainstorm — see §7.)

## 5. Research + crafting

- **Research engine — analyze-the-new (discovery-driven).** Each layer's signature material is the key:
  bring/produce a sample to a **research bench** (folded into the Bazaar, your hub) and it **unlocks that
  layer's tech branch** — the crafter modules + the drill/suit that survive the *next* twist. Loop: descend
  → find new material → analyze → unlock. Binds research to depth; reuses the structure/detection tech we
  built for the Bazaar; makes every new material an event. (Boss-drop keystones and a light research-item
  chain can coexist as accents on specific tiers.)
- **Chain depth — medium (accessible-but-deep).** `ore → ingot → {plate, gear} → assembly`, ~2-3 stages per
  tier. Enough Factorio puzzle to satisfy; each **crafter module makes one clearly-readable thing** (the
  legibility thesis). The per-item, gravity-fed crafter modules (docs/CRAFTING.md) are the hands that run
  these chains; this spine is the recipe GRAPH they were waiting on. **Ore quality** also gets its meaning
  here: a deeper ore tier feeds higher-tier recipes (the demand-pull deferral in docs/MINING.md resolves —
  build quality WITH these tiers).

## 6. Threat model — frontier pressure

Drivers 1 & 2 (§2) are pure logistics. On top, an **active threat concentrated at the descent FRONTIER**,
scaling with how aggressively you push (greed = heat). It pressures the deep edge you are *choosing* to
carve and the supply line down to it — but **never migrates up into your established base**, which stays
**safe by construction** (the locked "danger located/opt-in" pillar, preserved exactly). This gives the
factory a real **defense** job (produced turrets/walls/ammo at the frontier) and runs the factory-as-weapon
theme all game. (Chosen over logistics-only and a full ambient biters-analog.) *What the threat physically
IS, and how you fight it, is the combat sub-brainstorm — §7.*

## 7. Open sub-brainstorms (do before building the relevant tier)

- **Combat feel** (load-bearing for bosses + frontier defense): how the body fights, and how the factory
  fights — melee/ranged/tools-as-weapons for the body; turrets/traps/automated defenses for the frontier;
  what a boss-siege actually plays like. Its own session before L2's guardian or the frontier threat ships.
- **Power mechanics** (the L2 twist, the first buildable tier): how power is generated and distributed —
  does it flow DOWN with gravity (on-hook) or via a placed network? burner→steam→…? how it governs the lift
  and drills. A focused mini-brainstorm when we build L2.
- **Narrative stakes** (deferred, non-blocking): *why* you must reach the Sinkforge — escape home, reignite
  it, stop it, answer a call. Better discovered than forced; the abandoned-bazaar "someone came before"
  thread + the painted prologue seed it.

## 8. The narrative frame (the intro)

A cold open of **hand-painted, semi-realistic sequential panels** telling the Sinkforge's ancient lore,
hard-cutting to present day; the protagonist crosses a **portal** and a **stylization transition** resolves
the realistic world *into* our 2D pixel underworld; the final beat tilts the camera down the shaft — the
way is **down**. This **diegetically justifies the pixel art** (it's the nature of the place you crossed
into, not a budget aesthetic — answering the user's old "2011 vs 2026 look" worry), plants the mission
wordlessly, and threads into the spawn ruin (others crossed before you).

## 9. First build slice (proposed)

**L2 Stonereach** is the natural first tier to build, because it introduces the spine's load-bearing
mechanics at once: a second ore (iron) + the analyze-the-new research at the Bazaar + the first crafter
modules (plate/gear press) + the first **throughput gate** (a Descent Engine you feed to open L3) + the
first **power** need. Gate on the **power mini-brainstorm** (§7) first, since power is the tier's twist.
Combat (the Stonewarden guardian + frontier threat) waits on the combat brainstorm and can land as a
follow-up slice — the logistics gate (throughput wall) is playable without it.

## 10. The addiction model — how the 80% stays fun for 40 hours

> Added 2026-08-08 (design synthesis, guided one-axis-at-a-time with the user; DECISIONS same date). §1-9
> answer *what the campaign IS*; this section answers *why the moment-to-moment loop keeps you playing* —
> the part that actually retains, and the part a beautiful campaign spine can't rescue if it's missing.

- **Addiction lives in the LOOP, not the endgame.** The Sinkforge/cannon is a **lighthouse** — a fixed
  direction on the horizon that gives every action meaning — **NOT a progress bar you watch fill for 40h**
  (a charge-meter you stare at demoralizes; it makes the 39 hours feel like waiting). The discharge is a
  climax you ASSEMBLE in the final act, not a number that ticks up all game. **Corollary — validate the
  loop FIRST:** prove ~2 hours of real, human, moment-to-moment fun *before* building campaign structure.
  Only ~15 min (RUNG 1–4, agent-validated) exists today. Content is cheap once the loop is proven; a gorgeous
  campaign bolted onto an unfun loop is wasted work. This is why #96/#97 (grow-world / build-L3) sit BEHIND
  a real 2-hour human playtest, not ahead of it.

- **The 4-axis interlocked web.** Progression is not one track but **four axes that only move by pulling each
  other** — this interlock is what stops any single axis from becoming a one-dimensional treadmill:
  - **Depth** — how far your frontier reaches (the spine, §3-4).
  - **Tools** — pickaxe/drill tiers, **SOFT-gated (the Minecraft-obsidian rule):** you *can* mine the next
    tier's rock, but it's so punishingly slow per cell it isn't worth it until you craft a better tool; a
    new tier then **retroactively trivializes** old rock (retroactive-relief dopamine). No hard "you
    literally cannot" walls — **except THE SEAL** (the one built L1→L2 hard gate, which is a *narrative*
    barrel-segment, not a material tier).
  - **Factory** — the sandbox engine that produces the tools, the throughput, and the descent-supply.
  - **Home** — your base **descends WITH you** (demand-pull: build the descending-home mechanic only once
    the long-walk-back pain is genuinely felt in play, not before).
  None advances alone: deeper needs better tools, better tools need more factory, more factory needs deeper
  inputs. Pull one, the others must follow.

- **Anti-restart: a persistent CHASSIS + slotted MODULES.** A new layer must **never feel like starting
  over** (the user's explicit fear — restart-feel demoralizes and makes people quit). Resolution: tools
  **harden monotonically** (a tier, once earned, is never lost — the carry-forward), and specialization to a
  layer's twist is **swappable MODULES** (sealed / heat-shielded / gravity-anchored) you keep forever and
  re-slot per frontier. This does harden-AND-specialize, **additive-never-substitutive**. The **shrine-camps
  are the roguelite "shop"** — checkpoints in the located-danger pockets where you kit out with modules;
  diegetically, the dead who descended before you.

- **Novelty = a new RULE per layer, not a bigger number.** power → fluids → heat → thin-gravity (§4). Tools
  and modules specialize to each medium, so the novelty **propagates into the whole kit** instead of being a
  stat bump — this is the direct answer to "a game built only on soft-gating better pickaxes loses novelty
  fast."

- **Deeper = new INPUTS that still consume shallow materials** (steel = iron + heat; every deep recipe
  reaches back up the column). So the vertical factory you already built **stays employed all 40 hours** — a
  **living column**, not an abandoned strip-mine you left behind. This is the mechanical face of the
  no-reset permanent-empire pillar.

- **Identity: DIG-YOUR-FACTORY, not follow-the-cave.** The world is **dominated by solid, molded, ore-rich
  earth** you MINE and CARVE your factory INTO (base safe by construction). **Solid ≫ cave.** Ore is
  **frequent and organic** — veins/blobs, never a grid. Caves are **kept** (they read great) but **recast**
  as the rarer, opt-in **punctuation**: located danger / reward / shrine-camp pockets you *choose* to breach
  (the locked "danger located & opt-in" pillar). The breach moment — a dug shaft suddenly opening a cave —
  **is** the located-danger beat. Lore fit: caves are voids/fractures in the buried cannon's body where
  danger nests and prior descenders sheltered. (Governs worldgen tuning — see #107; codified from the
  `dig-your-factory-identity` design memory.)
