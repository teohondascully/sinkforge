# Product recovery pass — full source material, 2026-08-24

This file preserves the actual material `docs/PRIORITY.md`'s "Product recovery pass" section summarizes,
so that section's citations are checkable rather than paraphrase-of-paraphrase. Nothing here is edited for
tone; it is copied as given.

## 1. The live playtest report (the user, in-session, verbatim, images omitted)

> Im playing the game, and: [screenshot of a shaft with a Drill/Forge/Hopper stack and scattered ground
> piles]; There's just piles of stuff i cant pick up. not sure why. Also, if i have ores and coals next to
> each other and just have a single drill and put lodes everywhere, theres no way to make it so that the
> coal somehow doesnt go to the drill but can somehow feed back into the drill for energy. That might be
> too easy if we can just have a drill dirll coal to put back into itself for permanent drilling tbh. I
> forgot how it works in factorio. But like how does the hopper work, and once we have the hopper, what do
> we do? how can we somehow send the coal back up into the drill to power the drill? and if we just have 1
> drill and like 10 lodes, is that the best approach? i basically dont even know what to do at this point.
> I have 1 drill, 1 forge, 10 lodes, and i just lose coal really fast, and the items fall and i cant pick
> them up for some reason. The game is over idk what to even do. I have no incentive to go down. You know
> what i mean? like theres just no incentive to even play the game. WE need a massive brainstorm.
>
> Also the lighting is really weird and its just so pixelated still. And the main character totally doesnt
> fit. The movement is still kind of annoying to just operate normally and move around. We either need much
> better feature engineering or much better testing to catch these nuances. This game is unplayable, which
> makes me feel like we've been focusing on the wrong thing. I really want to go for a noita movement
> update. Noita feels so sleek to move around. Terraria too. This game feels so blocky and just annoying,
> you always get caught on random edges and just cant move and it feels counterintuitive and also theres
> just no incentive to play the game. Like its weird that the bazaar is the same menu as the inventory,
> these should be two separate things imo. Inventory could be e and bazaar could be b or something, but
> they should be separate. Also i liked the fixed inventory hotbar count so we know how much space we have.
> Im just confused because in the bazaar we have all of these items: [screenshot of the BAZAAR WORKS/RACK
> grid] but we have no reason to use any of them. the pacing is off so much. Its annoying that the sapling
> tutorial is so adamant and we just need better game quality all around so we definitely need brainstorms.
> Its annoying that the mouse cant be used to buy things in bazaar, and its annoying that we have to use
> arrow keys and numbers to move around. Weird gameplay. The "12 more wait behind..." is overlapping in the
> bazaar, the bazaar text quality is so pixelated too. Im just really unhappy with a lot of the game vision
> tbh.

Two direct follow-ups during the same session, on a review packet with different subject matter (Winch/ITM
visual options), that also apply as general workflow correction:

> im not sure what im seeing also when i click zoom its still blurry. What am i looking for? i cant see any
> winch

> Isnt it problematic that at the standard zoom level you cant see anything? lolol

> I feel like theres a massive oversight in our harness if you werent able to catch those issues

## 2. This session's own code investigation (read-only, before the PM review below existed)

Dispatched as a background agent, read-only, against three concrete claims in the playtest report:

**Piles that can't be picked up.** Ground piles are real sim state (`factory_sim.gd:249`, the `ground`
dict), drawn distinctly from decorative floor speckle (`world_renderer.gd:2397-2416` vs `:1645`). Auto-pickup
walks the player over `sim.ground` within 2.5 cells and calls `collect_ground` (`main.gd:2281-2299`), gated
only by `Settings.auto_pickup` (default true). The real mechanism: `collect_ground`
(`factory_sim.gd:3155-3180`) caps bulk items at `PACK_BULK_CAP = 90` (`factory_sim.gd:242`) via
`pack_room()`. What does not fit **stays in the pile**, and nothing in `hud.gd` surfaced that state — zero
hits for `pack_room`/`carried_bulk` anywhere in the HUD before this session's fix (`10d01e3`).

**Hopper/coal routing.** The feature the user asked for already exists, undocumented in-game. `drill` /
`h_drill` / `generator` are all `_COAL_BURNERS` (`factory_sim.gd:380`); `machine_eats`
(`factory_sim.gd:387-394`) confirms any of them accepts coal into `input_buffer` as fuel, checked directly
in `_status_drill` (`factory_sim.gd:441`). A hopper auto-filters: it banks the first item type it tastes and
passes everything else through (`_run_hopper`, `factory_sim.gd:2280-2296`) — so chaining hoppers is the
(undocumented) way to split a mixed ore+coal stream. `h_drill` additionally self-feeds up to
`H_DRILL_COAL_STOCK = 8` (`factory_sim.gd:64`) — a self-fueling drill variant already exists in the game.

**Bazaar UI.** The "N more wait behind research" line collided with the WORKS grid's own last row of item
cards — not the tab bar as first guessed — because the content box's height was sized purely from grid row
count and never budgeted for that line. Fixed at `ca39870`. Bazaar navigation confirmed keyboard-only
(arrows/WASD + Enter, `main.gd:1048-1055`) with no mouse-buy path into the grid. Bazaar and inventory
confirmed to be the same menu on one shared `_inventory_open` flag.

## 3. The PM design review (external, ~39 minutes, two parts, verbatim)

### Part one — reading the playtest against the code

> This is the first playtest that exposes the real problem: the game is not merely hard to understand; its
> central loop is not producing a compelling reason to continue.
>
> The current system is more complicated than the player-facing game teaches.
>
> ## What is actually happening
>
> The code confirms your confusion:
>
> - The Drill consumes coal directly.
> - The Generator also consumes coal, but produces the power network.
> - The Drill does not currently accept power as a replacement for coal.
> - The Hopper is a stockpile that releases items downward, but only while the next machine has room.
> - The Hopper latches onto the first material it receives and filters that material; everything else
>   passes through.
> - Ground piles are supposed to be collectible within roughly 2.5 cells, but items under machines, behind
>   collision, outside reach, or beyond the pack cap remain on the floor.
> - The progression tutorial teaches "manually feed coal to the Drill," then separately teaches "burn coal
>   in a Generator." It never gives the player a clear coal-to-power-to-production layout.
>
> So your mental model is not failing. The game is asking you to understand several interacting systems
> that have never been presented as one coherent machine language.
>
> ## The immediate product failures
>
> ### 1. The first automation is not really automation
>
> The game calls the Drill/Forge line "first automation," but the player must keep manually feeding coal
> into the Drill. That creates a bad contradiction: "The machine runs itself, except I have to keep
> hand-feeding its fuel." The player does not experience an automated factory. They experience a machine
> that converts one manual chore into another.
>
> ### 2. The Hopper has no obvious purpose
>
> The Hopper is technically a buffer/filter, but visually it looks like another machine in a vertical stack.
> A new player does not know whether it stores items, sorts items, feeds machines, separates coal from ore,
> increases throughput, or simply catches falling objects. The fact that its filter is implicit and latched
> from the first item is especially dangerous — a powerful rule hidden inside an object that does not
> communicate it.
>
> ### 3. The player has no reason to build the factory
>
> The Bazaar offers many things, but the player does not yet have a clear answer to "what problem does this
> machine solve for me right now?" The current system has machines before it has desires. A player should
> not see ten available machines. They should see one painful problem and one machine that solves it.
>
> ### 4. The economy ends too early
>
> Gear and plate are mostly terminal products; ingot is a universal currency; the major bulk sink is the
> Descent Engine. Once the player has built the obvious machines, most production has no continuing
> purpose. That explains "the game is over" — the player is not wrong; the economy has not yet created a
> next demand.
>
> ### 5. The depth does not create desire
>
> Currently the game mostly says "go deeper because the next layer is there." It needs to say "go deeper
> because you just discovered a problem that only the next layer can solve" — a machine upgrade gated on a
> deeper material, coal pressure making surface fuel unsustainable, a visible unreachable structure, a
> flooding/darkness/hauling problem.
>
> ### 6. Movement is actively taxing the player
>
> Not a cosmetic complaint — if ordinary traversal feels sticky, every other system becomes more
> frustrating. Needs a dedicated feel pass: snagging on one-pixel corners, block-edge catches, ledge
> step-up, collision depenetration, coyote time, acceleration/braking, air control, falling into shallow
> holes, recovering from bad terrain, grapple transitions, climbing out of excavated spaces. The goal is
> not to copy Noita — the goal is for movement to feel intentional rather than grid-bound. A player should
> never lose attention to the game because the character got trapped on an accidental collision seam.
>
> ### 7. The UI looks like debug instrumentation
>
> Grainy low-res text, generic dark rectangles behind every item, overlapping/floating labels, machine
> names competing with the machines themselves, unexplained downward light beams, a tree that reads as a
> dirt column with a green strip pasted on top, inconsistent material transitions, black square item
> backdrops, pixel treatment that feels accidental, a player character whose rendering language doesn't
> match the world, and Bazaar/inventory/objectives/machine-inspection all competing for the same visual
> grammar. The game needs a visual identity before it needs more decorative polish.
>
> ## Recommended coal and power model (first draft — corrected in part two below)
>
> I would not allow a normal Drill to become permanently self-feeding — that creates an obvious infinite
> loop (drill mines coal → coal powers drill → drill mines more coal → repeat forever). Instead, a
> two-stage system: Stage 1, a Burner Drill that accepts manually inserted coal (teaches what fuel is, how
> a machine consumes input, what running out looks like) — clearly temporary, not the final architecture.
> Stage 2, after Power research, a Powered Drill fed by Coal Hopper → Generator → Conduit network, so coal
> becomes power infrastructure rather than a second input hand-carried to every machine. The Drill could
> retain a small emergency coal slot, visibly marked as emergency fuel only.
>
> ## What the Hopper should become
>
> One clear identity: **a buffer and filter between a source and a consumer.** Its physical language should
> communicate where material enters, what it currently holds, and where it exits — mouse-configurable
> (click the Hopper, choose the material, see the icon in its body, see an arrow toward the target, see
> blocked/empty/feeding states). The current first-item auto-filter is an acceptable *default*, but it must
> be visible and reversible.
>
> ## What should happen to piles
>
> A dropped pile must never become silent failure. Every pile should be: collectible, deliberately
> redirectable, visibly blocked with a reason, returned to a nearby buffer, or marked as recoverable
> overflow — never lost merely because it landed on an inconvenient cell. Recommended: a short-range pickup
> magnet when the player looks toward a pile, a manual "collect" interaction for stubborn piles, a pile
> outline + material icon, an explicit PACK FULL state, a recoverable overflow bin below machines. The
> player should understand "I cannot pick this up because my pack is full," not "the game spawned junk that
> appears to be permanently broken."
>
> ## The first thirty minutes, redesigned (first draft)
>
> Phase 1 (make one thing): mine ore, feed the Forge, receive the first ingot, learn materials move
> downward. Phase 2 (automate extraction): research Automation, place one Burner Drill over a marked vein,
> feed it coal manually, watch ore travel into the Forge, get a clear "the line works" payoff. Phase 3
> (discover the problem): the Drill stops because coal is running out — the game should create the
> question "how do I stop hand-feeding this machine?" rather than just saying "out of coal." Phase 4 (build
> the power line): research Power, place Generator, route coal through a Hopper into the Generator, connect
> to the Drill, convert from burner to powered operation, watch the manual fuel requirement disappear.
> Phase 5 (create the descent desire): the Seal, a deeper-material preview, the next machine that requires
> iron, a visible landmark below, an explicit statement that the surface cannot supply the next tier.
>
> ## Separate the Bazaar and inventory
>
> Agreed completely: inventory answers "what am I carrying," Bazaar answers "what can I build/research/buy"
> — they should not be the same interaction surface. Recommended controls: E for inventory/pack, B for
> Bazaar, mouse for select/buy/inspect/configure, number keys as optional quick slots only, arrows as
> fallback navigation, not primary. The inventory should have a **fixed visible capacity** — the current
> variable-length row makes the pack feel like an arbitrary list rather than a constrained physical
> resource. The Bazaar should focus on: available machines, what problem each solves, the next recommended
> purchase, blocked requirements, a preview of the resulting capability.
>
> ## First-draft priority order
>
> 1. Movement feel pass (remove snagging/corner traps, ledge forgiveness, depenetration, measure stuck
>    events and recovery time, require a human feel review).
> 2. Pickup and overflow recovery (every dropped item recoverable, explain full-pack/blocked states, a
>    robust pickup interaction).
> 3. Separate inventory from Bazaar (fixed hotbar capacity, mouse-first Bazaar, clear machine
>    purpose/recommendation).
> 4. Rewrite the first automation loop (Burner Drill as a temporary teaching tool; Generator/Hopper/Conduit
>    as the real automation solution; remove the direct-fuel-vs-network-power ambiguity).
> 5. Give the Hopper an explicit visual and interaction language.
> 6. Add a genuine post-Forge desire (deeper materials, machine upgrades, a visible inaccessible target; do
>    not add more machines until existing ones have ongoing demand).
> 7. Depth and pacing pass (each layer introduces a new problem, not just a new material; show previews and
>    consequences before asking the player to descend).
> 8. World-material visual pass (replace pasted grass strips; coherent soil/rock transitions; deliberate
>    tree silhouettes; an authored material palette with strata rules).
> 9. Lighting pass (sources, bounce, occlusion, local atmospheric logic instead of arbitrary vertical
>    beams; light should reveal gameplay information, not just tint the scene).
> 10. Typography and panel language (fix pixel shimmer/grain; one display face, one readable body face;
>     fewer black rectangular backing plates; hierarchy from shape/spacing instead of boxing every label).
> 11. Machine identity pass (a recognizable silhouette per machine at gameplay scale; ports that physically
>     communicate inputs/outputs).
> 12. Journey evaluation (script a fresh player: can they collect a dropped item, build the first Drill,
>     understand coal, understand the Hopper, automate one useful chain, identify the next reason to
>     descend? Score stuck time, backtracking, unexplained pauses, abandoned goals, repeated failed
>     interactions).
>
> The important correction: we should not respond by adding more harness checks to the existing loop while
> the loop itself is failing. The harness has already done its job by preserving and surfacing this
> evidence. The next milestone should be a product recovery pass centered on movement, pickup, machine
> legibility, and the first meaningful desire. The game does not need more complexity right now. It needs a
> loop that a new player can feel, understand, and want to continue.

### Part two — the user's correction, and the PM's revised (final) progression

The user's pushback, verbatim:

> Well in factorio, power wasn't needed for a while. Like steam power is only needed later down the line,
> but you can get a lot of automation done with coal powered. So the goal isn't to automate with power and
> electricity ASAP. We need to really think through the automation frameworks available and pacing
> guidelines.

The PM's revised response, verbatim:

> Yes. I was conflating "automation" with "electricity," and that is the wrong design frame.
>
> Factorio's early game works because automation arrives in layers: hand work → small fuel-burning machines
> → burner logistics and routing → steam/electric power → high-throughput automation → trains, bots, and
> long-distance logistics. Sinkforge already has the ingredients for a similar progression, but they are
> not currently organized into a legible ladder.
>
> ## The corrected Sinkforge progression
>
> **Tier 0, hand-powered survival.** Mine the first ore, carry it to the Forge, make the first ingots,
> learn gravity and vertical space. Brief and satisfying, not the whole early game.
>
> **Tier 1, gravity automation.** One Drill over a vein feeds a Forge — ore vein → Drill → Forge → ingot.
> The first "the factory works without me" moment. The player still manually supplies coal, which is
> acceptable here because the purpose is to teach the machine, not complete the automation tree.
>
> **Tier 2, burner logistics.** The player solves the coal problem *without* electricity — coal vein →
> coal route/Hopper → burner Drill, ore route → Forge. This is where the Hopper and Spur should matter: the
> player learns machines need inputs, inputs can be routed, coal and ore are different streams, a machine
> can be supplied continuously, and spatial layout affects throughput. **This is the part the current game
> is missing** — it jumps from "manually put coal on the Drill" straight to "research a Generator," with no
> satisfying intermediate logistics problem.
>
> **Tier 3, sustainable burner networks.** A coal Drill can contribute to its own fuel chain, but should
> not become a magical infinite machine. Self-feeding can be good if it has real constraints: the coal
> lode is finite, the Drill consumes a measurable portion of its own output, routing requires a real
> filter/split, the same Drill cannot optimally mine and fuel itself without competing for throughput, the
> player must build a second machine or buffer to stabilize the loop, coal deposits eventually force
> expansion or relocation. The goal is not to forbid self-feeding — the goal is to make it an *earned
> automation puzzle* rather than an accidental exploit. One Drill plus ten lodes should not automatically
> be optimal; the player should discover tradeoffs between one flexible Drill vs. multiple specialized
> ones, fuel consumption, buffer size, route distance, lode richness, and machine downtime.
>
> **Tier 4, power.** Arrives after the player has felt the limitations of burner logistics — the Generator
> then solves a new problem ("my factory is becoming too large and too fuel-hungry to manage as individual
> burner machines"), providing longer-range operation, higher throughput, less manual fueling, new machines
> that cannot run on direct coal, and more scalable production. It should not be the first answer to every
> automation question. (There is also a progression contradiction worth reconciling deliberately: the
> design docs describe Power as an L2/Stonereach mechanic, while the current objective ladder teaches
> researching Power before breaching into Stonereach.)
>
> ## What this means for the Hopper
>
> The Hopper should not be "the thing you build before you know why." It should enter the game when the
> player has a visible routing problem — "coal and ore are falling through the same place, and I need to
> separate them." Role: buffer, filter, controlled release, back-pressure protection. The first useful
> Hopper scenario should be a coal route, not a generic item-storage tutorial. Its visual state should read
> something like `HOPPER / filter: COAL / stored: 18 / output: DRILL / state: FEEDING` — then the player
> understands why it exists.
>
> ## The early automation objective should change
>
> Instead of "craft a Drill, manually feed it coal, then research Power," use: make one Forge → place one
> Drill → keep it running manually → notice coal consumption → discover a coal vein → build a coal route →
> configure a Hopper to separate coal → sustain the Drill without hand-feeding → produce enough ingots to
> reach the descent gate → descend → discover that deeper machines require a larger, more scalable power
> system. That creates a natural desire chain: manual mining → one machine → fuel chore → burner logistics
> → throughput pressure → depth gate → power → larger factory.
>
> ## The important design principle
>
> Every new technology should answer a pain the player has personally experienced. Drill answers repetitive
> hand mining. Hopper answers uncontrolled falling output. Spur answers routing and branching. Burner
> logistics answers repeated coal feeding. Generator answers scaling beyond burner logistics. Freight
> answers hauling between depth layers. Power infrastructure answers large-scale machine coordination. If a
> machine arrives before its problem exists, it becomes inventory clutter — which is what the current
> Bazaar is doing: presenting solutions before the player has a reason to want them.
>
> ## Revised priority
>
> Not "switch the Drill to electricity" — the next gameplay milestone is **making the burner-era automation
> loop coherent**: (1) fix pickup and overflow so materials never become mysterious junk piles; (2) make
> the Drill → Forge line legible; (3) give coal a clear early routing path; (4) make the Hopper's purpose
> visible and interactive; (5) allow a deliberate, finite self-feeding coal setup; (6) make the player feel
> the limits of that setup; (7) only then introduce Generator and Power as the answer to scaling.
>
> The correct question is not "how do we automate the Drill with electricity?" It is "what is the smallest
> automation system that gives the player a satisfying problem, a visible solution, and a reason to build
> the next machine?" We should design that ladder before adding more machinery or expanding the harness
> around the wrong player experience.

## 4. What this session did with it

Adopted as-is — see `docs/PRIORITY.md`'s "Product recovery pass, 2026-08-24" section for the condensed,
governing version and the 12-item work order. Two items from priority #2 (pickup/overflow) shipped same
day, harness-verified: `ca39870` (bazaar text-overlap), `10d01e3` (PACK FULL indicator). Next: priority #1,
the movement feel pass, starting from a read of the actual collision/movement code in `scenes/player.gd`.
