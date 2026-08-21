# The material spine — what actually ships today

**Written 2026-08-17.** This is a MAP, not a proposal. It is the whole economy read off the `.tres` data
and `research_rules.gd`, with nothing rounded up and nothing aspirational included. §7 is the only part
that argues for anything, and it is fenced off deliberately.

It exists because the 2026-08-17 audit recommended settling the game's canon — what the descent is
ultimately *for* — partly on the evidence of the FORGED counter. That reasoning was rejected, correctly:
the forge is tier one of an intended much larger tree, so indexing the ending on it is reasoning from a
placeholder. The order was inverted instead. Work out the materials and factory progression first; the
ending is a consequence of the tree's shape, not an input to it.

You cannot do that without knowing the tree's real shape. It is smaller than the documentation implies.

---

## 1. The entire production graph

Six recipes. That is not a summary; that is the complete list.

| Recipe | In | Out | Time | Machine |
|---|---|---|---|---|
| `mine_ore` | — | 1 ore | 1.0s | Ore Vent, Drill |
| `smelt_ingot` | 2 ore | 1 ingot | 2.0s | Processor |
| `smelt_rich` | 1 rich_ore | **2** ingot | 2.2s | Blast Furnace |
| `smelt_iron` | 2 iron | 1 iron_ingot | 2.5s | Iron Forge |
| `mill_gear` | 1 iron_ingot + 1 ingot | 2 gear | 2.5s | Gear Mill |
| `press_plate` | 2 iron_ingot | 1 plate | 3.0s | Plate Press |

As a graph:

```
ore ──2:1──► ingot ─────────────┐
                                ├──1+1:2──► gear
rich_ore ──1:2──► ingot         │
                                │
iron ──2:1──► iron_ingot ───────┤
                                └──2:1──► plate
```

**Depth: four tiers.** raw → ingot → iron_ingot → gear/plate. Nothing is five deep.

## 2. What the machines cost

| Priced in | Machines |
|---|---|
| **ingot only** | conduit 1 · spur 1 · drill 2 · splitter 2 · generator 3 · hopper 3 · processor 3 · lift 4 · pump 4 · descent_engine 6 |
| **ingot + raw** | iron_forge (4 ingot + 2 iron) · torch (1 wood + 1 coal) · rope (1 wood) |
| **iron_ingot** | gear_mill (2+2) · plate_press (2+2) |
| **gear / plate** | blast_furnace (1g 2p) · h_drill (2g 2p 2i) · crusher (2g 3p) · drift_rig (4g 4p 4 iron_ingot) |

## 3. The research tree, as it actually branches

```
automation ──┬── prospecting          (scanner)
             ├── crosscutting         (spur)
             └── power ── descent ── ironworks ── machining ──┬── galleries ── packing
                                                              └── enrichment ── drainage
```

Eleven rungs. **No rung has two prerequisites.** Nothing in the tree converges — every node has exactly
one parent, which makes this a spine with stubs rather than a web.

## 4. Materials that never enter the economy

Sixteen materials exist. **Five feed a recipe** (ore, rich_ore, iron, coal, wood). The other eleven —
earth, stone, gravel, shale, deepslate, sealrock, leaves, and the four `*_wall` background types — are
terrain, spoil, or structure. They are things you dig through, not things you make anything from.

Two of them are load-bearing in other systems (gravel packs a gallery, stone is the Drift Rig's spoil),
so this is not eleven wasted materials. But the world is materially far richer than the economy is.

## 5. The findings

**F1 — `gear` and `plate` are terminal.** Nothing consumes them except one-off machine construction.
There is no ongoing demand for anything at the deep end of the graph. Once you own one of each machine,
**the factory has nothing left to make.** This is the largest structural gap in the game and it is why
the automation fantasy runs out: you build a production line whose product is a line you have already
built.

**F2 — `ingot` is a universal currency, and that is why the FORGED counter looked like a thesis.**
Ten of twenty machines are priced in ingots alone; seven of eleven research rungs are priced in ingots.
Everything costs the same thing, so a counter of that thing looks like a progress bar for the whole game.
It is not a design statement. It is a consequence of the tree being one tier deep in most directions.

**F3 — the only bulk demand in the game is a door.** `DESCENT_QUOTA = 64` ingots, fed to the Descent
Engine, to breach the Seal. That is the single largest sink in the economy by an order of magnitude, and
it is the only demand that cannot be satisfied by building one of something. It is also, not
coincidentally, the moment the game forces you to automate: 64 hand-carried ingots is untenable and 64
gravity-fed ones are not.

**F4 — one quality axis exists and it is a leaf.** `rich_ore` yields 1→2 against ore's 2→1: a 4× density
improvement, the only place in the game where a better input beats more input. It sits on
`enrichment`, a branch tip, so it is optional and terminal.

**F5 — the logistics vocabulary is three verbs.** Items fall (default), split two ways (Splitter), and
rise (Lift). Everything else — Hopper, Conduit, Pump, Spur, Drift Rig, Crusher — is production or
utility, not routing. The comparison that gets made is Factorio, whose spatial vocabulary is belts,
inserters, splitters, undergrounds, trains and bots. **The automation depth this project wants lives
here, in the routing verbs, and not in more recipes.** Six recipes arranged by three verbs is a small
puzzle no matter how many more recipes get added.

**F6 — the tree is 11 rungs and roughly 15 minutes of validated play.** `docs/PROGRESSION.md` concedes
the arc the scripted pilot can reach is about that long. The 40-hour figure elsewhere in the docs is not
supported by
anything in this table.

## 6. What this means for the canon question

The ending does not need deciding yet, and the reason is now concrete rather than a preference.

**F3 is the whole game in miniature.** The Seal works — as a design, as a pacing device, as the thing
that forces automation — because the sink is *depth itself*, and depth is the one demand that cannot be
satisfied once. Every other sink in the economy is a one-off purchase.

That means the tree's length is a design variable you can set later. If each layer gate is priced in the
previous layer's terminal product, in bulk, then the number of gates is the length of the game and the
ending is simply whatever the last gate opens onto. **You can build three more layers before you are
forced to answer "what is this all for", and each one you build tells you more about what the answer
should be.** Deciding it now would be deciding it with the least information you will ever have.

---

## 7. Proposal — fenced off, and only one idea

Everything above is the map. This is the argument, kept short so it is easy to reject.

**Make the gate the sink, everywhere, and gear/plate stop being terminal the same day.**

1. **Every layer gate is priced in the previous layer's deepest product, in quantity.** L1→L2 already
   costs 64 ingots. L2→L3 should cost plates or gears in the dozens. This single change repairs F1
   without adding a maintenance chore (the audit explicitly rules those out) — demand becomes bounded,
   large, and tied to the thing the player already wants.
2. **Give one rung two prerequisites.** The tree is a spine because nothing converges. A gate that needs
   both the fluid branch and the machining branch turns two stubs into a structure, and makes the side
   branches non-optional without making them mandatory-feeling.
3. **Spend the next tier on routing verbs, not recipes** (F5). One new way to move an item is worth more
   than three new things to make.

What this deliberately does NOT decide: what is at the bottom, whether there is combat, and who the
miner is. Those get easier to answer with three more layers built, and none of them block the work above.
