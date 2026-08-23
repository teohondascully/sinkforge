# One catalog, one schema, one owner per fact

`docs/DECISIONS.md` §"Adding content is a data file, not a class" is marked LOCKED, and it is half true.
A machine really is a `.tres`. The sim really is generic over it. What the entry concedes in its second
paragraph is the part this document is about: *"the known cost is registration"*. This is a plan to pay
that cost down to what the decision already promises, and to make the schema behind it something that can
refuse bad content instead of rendering it as dirt.

Nothing here is implemented. It is a specification, ordered so each step can land and be integrated on its
own.

**Frame for every number below.** Everything here was read at `f446b26`. `factory_sim.gd`, `hud.gd` and
`world_renderer.gd` move constantly, so treat a line number as a pointer to the symbol beside it and trust
the symbol, not the number.

---

## 1. The measurement: what one machine costs today

The test this work has to pass is that a fresh piece of content can be added without editing an arbitrary
list of unrelated files. So the first thing to do is count, and the honest way to count is to read the
commits that actually added the last four machines rather than to reason about what ought to be necessary.

| Machine | Commit | Game files touched | Of those, new |
|---|---|---|---|
| Pump | `07287ce` | 4 | 1 |
| Spur | `3ddffe8` | 7 | 1 |
| Crusher, with gravel | `d2f0042` | 9 | 2 |
| Blast Furnace, with rich ore | `d9e6550` | 11 | 3 |

Counts exclude `tools/`, `tests/` and `docs/`, which are the guard rather than the feature. The bottom two
rows each added a material as well as a machine, which is why they are the wide ones; the Spur is the
cleanest single-machine sample and the most recent.

**The Pump's 4 is the interesting row, because the Pump shipped broken.** It got its `.tres`, its
`_BEHAVIORS` entry, its `MACHINE_STYLE` glyph and a `drainage` research rung, and it was missing from
`MainView._craftable`, so a player who researched Drainage could neither craft it nor place it. That is
recorded in the header of `tools/check_craftable_registry.gd:5` — the layer exists because of this machine.
The correct cost for the Pump was 5, and the fifth file was in `scenes/`.

**The current cost, for a machine with a new behaviour, a face of its own and a research gate, is seven
files.** Named, in the order a person doing the work hits them:

| # | File | What has to change | What happens if you forget |
|---|---|---|---|
| 1 | `src/data/machines/<id>.tres` | the def itself (new file) | nothing exists |
| 2 | `src/core/factory_sim.gd:124` | a `_BEHAVIORS` row | falls through to the recipe runner, silently |
| 3 | `scenes/visuals.gd:16` | a `MACHINE_STYLE` row | draws as a generic gear or a furnace |
| 4 | `scenes/main.gd:260` | a `load()` line in `_craftable` | uncraftable **and** unplaceable (the Pump) |
| 5 | `src/data/research_rules.gd:11` and `:101` | `TECHS` unlock, `ORDER` | craftable from the start, ungated |
| 6 | `scenes/hud.gd:406` | an `ITEM_PURPOSE` line | the tooltip has a name and no purpose line |
| 7 | `scenes/hints.gd:35` | a `_defs` row | no first-acquisition bubble |

Rows 2 and 3 carry real work (a tick hook, a glyph) and are not the problem. **Rows 4, 5, 6 and 7 are pure
registration**: four hand-maintained lists in four files across both sides of the sim/representation seam,
none of which can be derived from the others today, and three of which fail soft.

The floor, for a plain recipe-runner with no new behaviour and no new glyph, is 5: two new `.tres` files
(machine + recipe) and three edits (`main.gd`, `visuals.gd`, `research_rules.gd`).

A material is cheaper but wider: `src/data/materials/<id>.tres`, plus the path list at
`scenes/world_renderer.gd:348`, the colour ladder at `scenes/visuals.gd:984`, the glyph match at
`scenes/visuals.gd:1047`, `MiningRules.HARDNESS` / `REQUIRED_TOOL` / `REQUIRED_TIER`, `ITEM_PURPOSE`,
`MainView.BUILD_MATERIALS` if it is placeable, and the strike/step tables at `scenes/sfx.gd:29` and `:39`.

---

## 2. Where content lives today

Twenty machine defs, sixteen material defs, six recipe defs, all under `src/data/`. Every one of them has
an `id` that matches its filename stem. Nothing asserts that, and `SaveGame` depends on it: `save_game.gd:151`
rebuilds a saved machine as `DEF_DIR + entry["def"] + ".tres"`, and a mismatch makes the whole save
unloadable at `:153`, not partially loadable. That is the correct failure, and it is undefended.

Around those directories sit eighteen registration surfaces, carrying twenty-one hand-maintained tables
between them. This is the full map.

| Registry | File:line | Keyed on | Entries | Behaviour on a miss |
|---|---|---|---|---|
| Behaviour dispatch | `src/core/factory_sim.gd:124` `_BEHAVIORS` | behaviour tag | 11 | falls through to the recipe runner (deliberate, documented at `:120`) |
| Machine look | `scenes/visuals.gd:16` `MACHINE_STYLE` | behaviour tag | 19 | falls back to furnace/gear by recipe shape (`:165`, `:176`) |
| Status look | `scenes/visuals.gd:72` `STATUS_LOOK` | status | 10 | falls back to `idle`; guarded by `check_status_reads` |
| Craftable/placeable | `scenes/main.gd:260` `_craftable` | `load()` path | 19 | the machine does not exist for the player |
| Material registry | `scenes/world_renderer.gd:348` | `load()` path | 16 | **resolves to `earth`, and paints as dirt** |
| Item colour | `scenes/visuals.gd:984` `item_color` | item id | 23 arms | `Color.WHITE` |
| Item glyph | `scenes/visuals.gd:1047` `draw_item` | item id | 27 ids / 23 branches | flat rect in `item_color` |
| Item purpose | `scenes/hud.gd:406` `ITEM_PURPOSE` | item id | 43 | no purpose line |
| Item label | `scenes/hud.gd:4778` `_item_label` | item id | derived | `String(id).capitalize()` |
| Research tree | `src/data/research_rules.gd:11` `TECHS` | tech id | 11 | unlock names nothing, silently |
| Bench order | `src/data/research_rules.gd:101` `ORDER` | tech id | 11 | tech unreachable via the R key |
| Hardness / tool gate | `src/data/mining_rules.gd:12`, `:26`, `:38` | material id | 9/4/9 | hand-mineable at `DEFAULT_HARDNESS` |
| Tool + bit recipes | `src/data/mining_rules.gd:73`, `src/data/bit_rules.gd:53` | item id | 3 + 4 | not craftable |
| First-acquisition hints | `scenes/hints.gd:35` `_defs` | item id | 12 item-keyed | no bubble |
| Strike / step audio | `scenes/sfx.gd:29`, `:39` | material id | 10 / 10 | plain `crunch` (deliberate, documented at `:27`) |
| Craft tools + bits | `scenes/main.gd:158` `CRAFT_TOOLS` | item id | 7 | absent from the Rack |
| Build materials | `scenes/main.gd:80` `BUILD_MATERIALS` | material id | 5 | not placeable from the pack |
| Icon compare set | `tools/check_item_reads.gd:40` `ITEMS` | item id | hand-kept | the icon is never compared to anything |

Two of the soft fallbacks are argued for in their own source and should stay: `_BEHAVIORS` at
`factory_sim.gd:120` (an unknown tag is a future machine, not a bug) and `Sfx.STRIKE` at `sfx.gd:27` (the
stone voice is the right default). One is a bug generator and is named as such in
`tools/check_material_registry.gd:9`: `WorldRenderer._material()` resolving an unknown id to `earth` is how
`rich_ore` painted as dirt for its entire existence.

### The tell nobody has looked at

`Visuals.item_color` returns `Color.WHITE` for 22 ids the game can actually produce: the four bits, and
eighteen of the twenty machine items. `world_renderer.gd:3245` knows this and guards its own use of it with
`_item_ink`, which swaps white for chrome, and its comment says *"Nothing shipped reaches the fallback
today."* That sentence is about world marks, and it is true there.

There is a second guard, and it is only in one of the three HUD call sites. `hud.gd:1429` checks
`machine_icons.has(item)` before falling back to `item_color`, so the craft-cost chips are safe for the
nineteen craftable machines and exposed only for the four bits. `hud.gd:2344` and `hud.gd:3712` have no
branch at all: the second is the production dashboard's throughput bar.

That one is reachable. `FactorySim.production_rates()` (`factory_sim.gd:1824`) iterates `total_produced`, and
`craft_item` (`:1584`) writes `total_produced[output]` for machines and bits alike, so crafting a Drill or a
Broad Bit puts an id with no colour into the dashboard's population and it draws as a white bar.

This is traced in source, not observed on a screen; §10 says how to settle it. It is written here because it
is exactly the shape the catalog is meant to end: a table that is complete today, a guard written against
one door into it, and a second door nobody checked.

---

## 3. What the catalog derives, and what it does not

The proposal is one module, `src/data/catalog.gd` (`class_name Catalog`, `extends RefCounted`), that reads
the three `.tres` directories once and answers the questions those tables currently answer by hand.
It is not a nineteenth surface. It adds no content file and invents no new id namespace; it reads the
directories that already are the content and exposes what the existing lists spell out longhand.

```gdscript
class_name Catalog
extends RefCounted

## The content directories, read once. Every derived view below is a QUESTION ABOUT THE DIRECTORY, never a
## second list that has to agree with it: the failure this replaces is a hand-kept array drifting from the
## .tres files beside it, and a cached array would just move the drift in here.
const MACHINE_DIR: String = "res://src/data/machines/"
const MATERIAL_DIR: String = "res://src/data/materials/"
const RECIPE_DIR: String = "res://src/data/recipes/"

static var _machines: Dictionary = {}    ## id -> MachineDef
static var _materials: Dictionary = {}   ## id -> MaterialDef
static var _recipes: Dictionary = {}     ## id -> RecipeDef
static var _built: bool = false
```

What derives, and from what:

| Today | Derived from | Note |
|---|---|---|
| `WorldRenderer._materials` (16 paths) | the material directory | exact; the load order does not matter |
| `MainView._craftable` (19 `load()` lines) | machine defs with a non-empty `craft_cost`, ordered by a new `sort_order` on `MachineDef` | order is load-bearing; see S3 |
| `MainView._machine_defs_by_id` | already derived from `_craftable` | no change |
| `Hud.machine_icons` | already derived at `main.gd:338` | no change |
| `Hud.craft_ids` / `craft_options` | already derived at `main.gd:336-337` | no change |
| the item universe | materials (non-wall, minus `leaves` and `sealrock`) ∪ recipe inputs and outputs ∪ `MiningRules.TOOLS` ∪ `BitRules.BITS` ∪ machine ids | **this function already exists**, see below |
| `MainView.CRAFT_TOOLS` costs | `MiningRules.TOOL_RECIPES` ∪ `BitRules.BIT_RECIPES` | already merged at `main.gd:2655`; only the display names are hand-kept |

**The item derivation is already written, in the wrong place.** `tools/check_item_reads.gd:468`
(`_ids_the_pack_can_hold`) builds the item universe from the data by exactly the rule the pack is filled by,
with each exclusion argued in the comment above it at `:422`. It lives in a harness layer, so the game cannot
call it, and it reaches back into `MainView.CRAFT_TOOLS` at `:493` to finish the job — a check layer reading
a content list out of a `Node2D`. Lifting that function into `Catalog.items()` and having the layer call it
is behaviour-preserving by construction and closes the boundary crossing in the same move.

**What must NOT be derived.** `MACHINE_STYLE`, `ITEM_PURPOSE`, `Hints._defs` and the sfx tables are authored
content: a glyph kind, a casing hue, a sentence of copy, a lesson. There is no honest derivation of a
sentence. The catalog's job for those is **coverage**, not generation: it supplies the population, and a
harness layer asserts the table covers it. That is the split in the map above. Three of those surfaces are
transcriptions of the directory and should go — `MainView._craftable`, `WorldRenderer._materials`, and
`check_item_reads.ITEMS`. Everything else on it is authored content and should stay, with a gate.

`_BEHAVIORS` also stays. A behaviour is a method on the sim, and the tag exists precisely so a machine can
have one without a type enum (`DECISIONS.md` 2026-06-27, PROVISIONAL). Deriving it would mean inventing the
enum that entry declined to invent.

---

## 4. There is no item catalog, and that is the deeper gap

`docs/ARCHITECTURE.md:299` says it plainly: *"Items are referenced by `StringName` id (e.g. `&"ore"`,
`&"ingot"`); no `ItemDef` yet (added when needed)."*

The consequence is that `&"ingot"`, `&"iron_ingot"`, `&"plate"`, `&"gear"` and `&"sapling"` are defined
nowhere. They exist only as literals inside recipe outputs and craft costs. Every property they have — a
colour, a glyph, a tooltip, whether they are bulk — is decided by a table keyed on a string that no schema
knows about. `FactorySim.is_bulk_item` (`:1658`) handles this well and is the model to copy: it derives
bulk-ness from the *exempt* side (tools and machine defs), so a material added tomorrow is capped by default
and cannot be left off a list.

**This plan does not propose an `ItemDef`.** Adding one now would force every existing id to declare fields
nobody has needed yet, which is the premature commitment the behaviour-tag decision was written to avoid.
`Catalog.items()` gives the schema a universe to validate against without creating a directory of item files.
When an item genuinely needs a field that cannot be derived — a stack size, a category — that is the moment
to add `ItemDef`, and the catalog is the place it will slot into.

The doc is also stale and should be corrected as part of this work: `ARCHITECTURE.md:296` lists `MachineDef`
without `craft_cost` or `craft_count`, and does not list `MaterialDef` at all.

---

## 5. Schema validation

One static entry point, `Catalog.validate() -> Array[String]`, returning one sentence per violation. Empty
means clean. It is a pure function of the directories plus the two rules modules, so it needs no scene, no
window and no tick — the same class of layer as `tools/check_progression_payable.gd`, which already walks
the machine and material directories headless in milliseconds (`:28`, `:40`).

### The rules

| # | Rule | Why it is not academic |
|---|---|---|
| V1 | every def's `id` is non-empty | an empty id silently overwrites the previous empty-id def in the registry dictionary |
| V2 | every def's `id` is unique within its kind | second one wins; the first vanishes with no error |
| V3 | every def's `id` equals its filename stem | `save_game.gd:151` builds the path from the id; a mismatch makes every save containing it unloadable |
| V4 | every `MachineDef.behavior` is either empty, a `_BEHAVIORS` key, or a `MACHINE_STYLE` key | a typo'd tag is a machine with no tick and no face, and both fallbacks are silent |
| V5 | every `MACHINE_STYLE` key is some def's `behavior` | a dead style entry reads like coverage; this is the reverse drift `check_status_reads:29` guards for statuses |
| V6 | every `_BEHAVIORS` hook name resolves to a sim method | partly exists; see the gap below |
| V7 | `MachineDef.recipe` is non-null unless the machine has a `_BEHAVIORS` entry | a recipe-runner with no recipe does nothing forever and says `idle` |
| V8 | every id in `inputs`, `outputs`, `craft_cost` is in `Catalog.items()` | a typo'd ingredient is a machine nobody can build, discoverable only by trying |
| V9 | every quantity in `inputs`, `outputs`, `craft_cost` is `>= 1`; `craft_count >= 1` | a zero or negative count runs `craft_item`'s loop into a free craft or an inverted ledger |
| V10 | `RecipeDef.time > 0.0` | `progress` never reaches a non-positive threshold, or reaches it every tick |
| V11 | `MaterialDef.layer` is `&"block"` or `&"wall"` | anything else is a material the renderer's two planes both ignore |
| V12 | every key in `MiningRules.REQUIRED_TOOL` / `REQUIRED_TIER` / `HARDNESS` is a real material id | a table keyed on a material that was renamed is dead weight that reads as a rule |
| V13 | every `ResearchRules.TECHS[*].unlocks` id is a machine, tool or bit id; every `sample` is a real item | an unlock naming nothing is a rung that grants nothing, and `locking_tech` returns `&""` so it never complains |
| V14 | `ResearchRules.ORDER` is a permutation of `TECHS.keys()` | a tech absent from ORDER is unreachable through the bench key |
| V15 | every craftable machine id has an `ITEM_PURPOSE` entry | coverage, not derivation; the population comes from the catalog |

V15 is currently **satisfied**: all 19 craftable machines and every carriable material have a purpose line,
and the two materials that do not (`leaves`, `sealrock`) are ones the pack can never hold. This rule is a
ratchet against drift, not a repair of a hole. Saying so matters — the point of writing a rule is not that
it is red today.

### The one live gap V6 closes

`tests/test_sim.gd:1203` (`_test_behavior_registry`) already checks that `_BEHAVIORS` hook names resolve, and
it checks `["run", "status", "dests"]` at `:1208`. There are four method-name hooks. The fourth, `"flow"`, was
added for the Drift Rig at `factory_sim.gd:135` and is dispatched by `call()` at `:2702`. It is not in the
test's list. `_flow_drift` exists, so nothing is broken; a typo in a future `flow` entry would be a runtime
error in the tick with no guard above it.

That same test asserts every `_BEHAVIORS` tag has a `MACHINE_STYLE` look (`:1211`), which is V4 in one
direction only. V5 is the direction nothing checks.

### Where it hooks, and how it fails loudly

Two hooks, because they answer different questions.

**The gate** is a new `tools/check_catalog.gd` extending `check_base.gd`, registered with plain `add` in
`tools/run_harness.sh`: `add "check_catalog (content schema)" "res://tools/check_catalog.gd"`. It is a
headless layer with no display need, so it goes in the `add` block with the other data guards, next to
`check_progression_payable`. It calls `Catalog.validate()`, prints one `FAIL` line per violation, and
exits 1. It must also print its own non-vacuity counts — how many machines, materials and recipes it read —
because every assertion in the list above is perfectly satisfied by a directory it failed to open. And it
must carry a knockout control in the same run: construct a `MachineDef` in memory with an empty id and a
negative craft cost, push it through the same `validate` path, and assert that it comes back with exactly
two more violations than the clean set. A validator that cannot be shown catching a planted fault is a
validator nobody has tested.

**The developer's fast feedback** is `Catalog.build()` calling `validate()` and `push_error()`-ing each
violation at boot. Not `assert`, and never a silent default: a boot that carries on with bad content is the
current behaviour, and the whole point is that a violation should be impossible to miss while the editor is
open. The harness layer is what makes it impossible to merge.

The two hooks must share one implementation. A validator that runs one set of rules at boot and a different
set in the harness is two validators, and the one nobody looks at is the one that rots.

---

## 6. The two `FineTerrain`s

There are two files named `fine_terrain.gd` and they are unrelated.

`src/core/fine_terrain.gd` (114 lines) is the sim's molding module. It is stateless, it fills
`sim._fine_solid` from the coarse grid plus seeded noise, and it owns `SYNC_BAND` — the contract for how wide
an edit re-molds. It declares **no** `class_name`. It is reached as `FactorySim.FineTerrain`, a `preload`
const at `factory_sim.gd:19`.

`scenes/fine_terrain.gd` (1,351 lines) is the renderer's bake. It declares `class_name FineTerrain`, so it
owns the global name, and it is what `world_renderer.gd:302`, `terrain_painter.gd`, `tests/test_worldgen.gd:75`,
`tools/check_grid.gd`, `tools/check_dig_hitch.gd` and `tools/check_frametime.gd` all mean by `FineTerrain`.

**This is not a compile error and never has been**, because only one of them claims the global name. It is a
comprehension hazard with one live consequence, visible five lines apart inside the bigger file:

```
scenes/fine_terrain.gd:859   #    coarse cells around each edit (src/core/fine_terrain.gd sync_block), ...
scenes/fine_terrain.gd:864   var band: int = FactorySim.FineTerrain.SYNC_BAND
```

A reader inside a file whose own class is `FineTerrain` sees the bare name resolve to *this* file and the
qualified `FactorySim.FineTerrain` resolve to a different one. The same line appears in
`tools/profile_frame.gd:285`.

**Resolution: rename the sim-side module, not the renderer.** The renderer's class is the one the global
name, the harness and the tests all use: `git grep -c -P 'FineTerrain' -- scenes tests tools` totals 66
references across twelve files, and 64 of them mean the renderer. The sim-side module has exactly one
consumer and a total blast radius of seven sites.

`src/core/fine_terrain.gd` → `src/core/terrain_mold.gd`, `class_name`-less as it is today, reached as
`FactorySim.TerrainMold`. The name is the file's own word for itself: its header calls the work "molding",
and `scenes/fine_terrain.gd:7` already says *"the molding itself lives in src/core/fine_terrain.gd"*.

Every site:

| # | File:line | Change |
|---|---|---|
| 1 | `src/core/fine_terrain.gd` | `git mv` to `src/core/terrain_mold.gd` |
| 2 | `src/core/fine_terrain.gd.uid` | `git mv` alongside it; `uid://bjtyt460ja6h0` is referenced by nothing |
| 3 | `src/core/factory_sim.gd:19` | `const TerrainMold := preload("res://src/core/terrain_mold.gd")` |
| 4 | `src/core/factory_sim.gd:745`, `:757` | `TerrainMold.rebuild` / `TerrainMold.sync_block` |
| 5 | `scenes/fine_terrain.gd:864` | `FactorySim.TerrainMold.SYNC_BAND` |
| 6 | `tools/profile_frame.gd:285` | same |
| 7 | `scenes/fine_terrain.gd:7`, `:859`; `src/core/fine_terrain.gd:24`; `docs/DECISIONS.md:503`, `:528` | prose references to the path |

Mechanical, no behaviour surface, and the existing suite is a complete safety net: `check_grid`,
`check_dig_hitch`, `check_bake_idempotent` and `test_worldgen` all fail immediately on a broken preload.

---

## 7. Module boundaries

### What holds

The sim/representation seam is real in the direction the README claims. At `f446b26`: `grep -rn "get_tree()"
src/` returns nothing, `grep -rn "res://scenes" src/` returns nothing, and every `extends` in `src/` resolves
to `RefCounted`, `Resource`, or another `src/` script — no `Node` anywhere in eighteen files. No file in
`scenes/` reads a `_`-prefixed member of the sim. That is enforced, not aspirational, and none of the work
below may weaken it.

### What is violated

**V-1. `scenes/world_seeder.gd` is sim content living in the presentation directory, and it writes
authoritative state directly.**

The file is a `RefCounted` with no nodes and no drawing. Its own header (`:7`) says *"Sim seeding only... every
edit goes through the sim's discrete API"*. That is true of the terrain — `set_solid`, `place_machine` — and
false of everything else. Thirteen lines write authoritative dictionaries by hand:

| Line | Write | The verb it bypasses |
|---|---|---|
| `:32`, `:40`, `:77`, `:86`, `:128` | `sim.deposits[cell] = n` | none exists; deposits have no setter |
| `:76`, `:85` | `sim.lode[cell] = &"ore"` | none exists |
| `:78`, `:87` | `sim.lode_max[cell] = n` | none exists |
| `:141`, `:151` | `sim.inventory[item] = ... + n` | `take_into_pack` (`factory_sim.gd:1709`) |
| `:142`, `:152` | `sim.total_produced[item] = ... + n` | — |

The pack writes are the ones that matter. `factory_sim.gd:1694` calls `take_into_pack` *"THE ONE DOOR INTO
THE PACK for anything the cap counts"*, and documents that the cap did nothing for weeks because twelve
yield sites wrote `inventory` inline. Here are two more of them, outside the sim entirely, where a source
scan over `src/` would not see them.

It is currently harmless, and the arithmetic is worth recording so the fix is not treated as urgent: the
starter kit is one `wood_pickaxe`, which `is_bulk_item` exempts as a tool; the dev kit at `:149` is 20 ore +
20 ingot + 10 wood + 20 coal = 70 bulk units against `PACK_BULK_CAP = 90`, with the six machine items exempt.
Neither would spill today. The defect is structural, not live.

The correct target is **not** to route these through `take_into_pack`, which writes `inventory` but not
`total_produced` and would break the conservation invariant the seeder's own comment at `:8` is protecting.
It is a new sim verb — `FactorySim.spawn_into_pack(item: StringName, n: int) -> void` — that does both, and a
`seed_deposit(cell, amount)` / `seed_lode(cell, material, amount)` pair for the vein writes. Then the seeder
has no direct dictionary access at all, and a source scan can then assert that the door is the only door.

**V-2. The seeder's layout constants live on a `Node2D`.** `world_seeder.gd` reads `MainView.SURFACE`,
`MINESHAFT_COL`, `MINESHAFT_FORGE_CELL`, `MINESHAFT_DRILL_CELL`, `MINESHAFT_ORE_CELL`, `AUTO_FORGE_CELL`,
`MINESHAFT_ORE_RICHNESS`, `TUTORIAL_COAL_CELLS`, `TUTORIAL_TREE_COL`, `ADIT_COLS`, `ADIT_CHAMBER_COL`,
`ADIT_ROOF`, `ADIT_FACE_AMOUNT`, `ADIT_DEEP_AMOUNT` — the thirteen constants listed here, all declared
in the opening-seeding block of `scenes/main.gd` (which holds sixteen `const` lines in total). The opening of the game is authored in the controller. This is why the
seeder cannot simply move to `src/`: the constants have to go first.

A fifteenth constant shows what happens to a layout fact with no owner. `MainView.STARTER_VEIN_CELL` is
declared at `main.gd:588` and cited twice in `world_seeder.gd` as the authority — at `:9` in the file header
and at `:26` above the function that places it. Nothing reads it. `world_seeder.gd:30` writes
`Vector2i(47, MainView.SURFACE)` as a literal instead, so the constant is dead and the cell it names is
duplicated four lines under a comment claiming otherwise. Moving these into `src/data/spawn_layout.gd`
should delete the constant or start using it, and V-2 is the reason to decide which.

**V-3. A harness layer reads content out of the controller.** `tools/check_item_reads.gd:493` iterates
`MainView.CRAFT_TOOLS` to complete the item universe, and `tools/check_progression_payable.gd:33` preloads
`scenes/world_seeder.gd` with the comment *"Preloaded because WorldSeeder declares no class_name"*. Both are
correct workarounds for content sitting on the wrong side of the seam.

**V-4. Two tests reach across.** `tests/test_sim.gd:1211` reads `Visuals.MACHINE_STYLE` and
`tests/test_worldgen.gd:75` reads `FineTerrain.walked_surface`. Both are static reads of presentation
constants from a suite whose stated property is that it constructs `src/` with no scene tree. Both are
defensible — the first is deliberately checking the sim/view join — but they should be named rather than
discovered.

**V-5. Material classes are hardcoded predicates instead of `MaterialDef` fields.** `factory_sim.gd:1364`
(`_is_ore_like`) enumerates the ore family as a literal list. The rock family is enumerated five separate
times, all five spelling out the same four ids: `factory_sim.gd:2607` (`is_spoil`),
`layered_world_gen.gd:674` (`PLAIN_ROCK`), and inline at `:764`, `:820` and `:920`. Each of these is a
boolean that belongs on `MaterialDef` beside `grain` and `glitters`. This is content wearing a predicate's
clothes, and it is why `src/core/layered_world_gen.gd` carries 41 material-id literals.

### The coverage finding this surfaces

`shale` is generated as the hard shelf band (`layered_world_gen.gd:311`, *"cave-resistant"*), and it has no
entry in `MiningRules.REQUIRED_TOOL`, none in `REQUIRED_TIER`, and none in `HARDNESS`. It is therefore
hand-mineable with no pick at all, at `DEFAULT_HARDNESS = 0.50` — softer than surface `stone` at `0.85`,
which does require a pick. `gravel` is in the same position, which is probably right for crushed rock.

That is not being called a bug here: it may be a deliberate choice nobody wrote down. It is exactly the kind
of question a catalog coverage report answers by asking it out loud, and today nothing asks.

---

## 8. Staging

Nine steps. Each preserves behaviour under the existing suite, each can be integrated on its own, and the
order is a dependency order rather than a preference.

| # | Step | Class | Files | Guard |
|---|---|---|---|---|
| S0 | Rename `FineTerrain` → `TerrainMold` on the sim side | mechanical | 7 sites, §6 | `check_grid`, `check_dig_hitch`, `check_bake_idempotent`, `test_worldgen` |
| S1 | Add `src/data/catalog.gd` + `tools/check_catalog.gd`; nothing consumes them yet | mechanical | 2 new, 1 line in `run_harness.sh` | the layer's own planted-fault control |
| S2 | `WorldRenderer._materials` reads the catalog | low | `world_renderer.gd:348` | `check_material_registry`, and see the caveat |
| S3 | Add `sort_order: int` to `MachineDef`, write the current 19 indices into the defs, derive `MainView._craftable` | medium | `machine_def.gd`, 20 `.tres`, `main.gd:260` | `check_craftable_registry`, `check_row_identity`, plus a one-shot equality assertion |
| S4 | Move `Catalog.items()` in; `check_item_reads` calls it instead of owning it | mechanical | `catalog.gd`, `check_item_reads.gd:468` | the layer is its own guard; output must be identical |
| S5 | Turn V4–V15 on in `check_catalog` | low | `catalog.gd` only | the layer's own planted-fault control; every rule is satisfied by today's content, so a red here is a bug in the rule |
| S6 | Add `item_color` to `MaterialDef`; move the material literals into the defs; make `Visuals.item_color` fall back to `machine_color(def)` for a machine id and give the four bits an entry; assert old == new for all 23 existing arms; then delete the ladder | **risky** | `material_def.gd`, 16 `.tres`, `visuals.gd:984` | see below — needs a test that does not exist |
| S7 | Move the fourteen layout constants (and settle the dead fifteenth) from `MainView` to `src/data/spawn_layout.gd` | medium | `main.gd:566-628`, `world_seeder.gd`, `check_progression_payable.gd` | `check_teaching`, `check_mining`, `play-tests`, `test_worldgen` |
| S8 | Add `spawn_into_pack` / `seed_deposit` / `seed_lode` to the sim; move `world_seeder.gd` to `src/core/`; give it a `class_name` | medium | `factory_sim.gd`, `world_seeder.gd`, `main.gd:634`, `check_progression_payable.gd:32` | `test_sim` conservation, `check_carry_cap`, `check_teaching` |
| S9 | Promote `_is_ore_like`, `is_spoil` and `PLAIN_ROCK` to `MaterialDef` booleans | medium | `material_def.gd`, 16 `.tres`, `factory_sim.gd`, `layered_world_gen.gd` | `test_sim`, `check_spoil`, `check_lode`, `check_drift`, `test_worldgen` |

### Mechanical vs risky, stated plainly

**Mechanical (S0, S1, S4).** No behaviour surface. S0 is a rename with a compile-time failure mode. S1 adds
code nothing calls. S4 moves a function between files and the layer that calls it must print the same
population size before and after.

**Low risk (S2, S5).** S2 replaces a list of sixteen paths with a directory scan that produces the same
sixteen defs; the only way it differs is if a `.tres` exists on disk that the list omitted, which is the bug
it is fixing. S5 turns on assertions over content that is already correct.

**Medium (S3, S7, S8, S9).** Each moves a fact between files. S3's risk is ordering — the current
`_craftable` order drives the Bazaar rows and their keybindings, and a directory scan is alphabetical, which
is why `sort_order` goes on the def rather than a second ordered list living somewhere. S7 and S8 move the
opening of the game, which every play-goal walks through. S9 changes the meaning of four predicates the drill,
the crusher and the generator all branch on.

**Risky (S6).** This is the only step that can change pixels, and it can change them in two directions. The
23 ids that already have a colour must keep exactly the colour they have, and that half is guarded by
asserting the old ladder and the new lookup agree for all 23 before the ladder is deleted — a control that
travels inside the change. The other half is the 22 ids that return `Color.WHITE` today and would gain a
colour: the eighteen machines pick up their casing hue and the four bits pick up a steel. Nothing changes in
`_chips`, which already branches to `machine_icons` at `hud.gd:1429`; what changes is the dashboard bars at
`hud.gd:3712` and the demand bars at `:2344`. It is an improvement and it is still a change, and it has to
be looked at rather than argued.

### What cannot be done without a test that does not exist

**S6 has no instrument.** `check_item_reads` is the closest thing, and it renders `draw_item` glyphs and
compares them pairwise for shape and colour. It does not photograph the production dashboard, it does not
photograph the pack chips, and its population (`:468`) deliberately excludes machines because *"a carried
machine draws through `Hud.machine_icons`, not through `draw_item`"* — which is true of the hotbar and false
of `hud.gd:3712`. So the surface S6 changes is the one surface no layer looks at.

Before S6 can land, one of these has to exist:

1. A `check_dashboard_reads` layer that opens the production dashboard with a stocked `total_produced`
   covering every id in `Catalog.items()` and asserts no bar is drawn in `Color.WHITE`. This is the smaller
   and better option: it is the assertion that names the actual property, and it can be proved red today by
   crafting a Drill in the fixture.
2. Failing that, a full `_moment_*` capture baseline before the move and a magenta diff-map after, at the
   >0.20 threshold the project already uses, against the ~38% run-to-run animation-phase noise floor.

**S9 needs a diff before the move, and it is not covered either.** Promoting `_is_ore_like` to a
`MaterialDef` field cannot change what the predicate answers, and proving that is a cheap set comparison.
The rock family is the risk: `layered_world_gen.gd:764`, `:820` and `:920` each run the same four-material
test inline at a different point in generation, and collapsing three inline predicates into one call is only
safe if all three really were the same predicate. They read as identical. They should be diffed character by
character before the move, and the worldgen checksum on a fixed seed recorded on both sides of it.

The instrument for that half-exists. `tests/test_worldgen.gd:1035` (`_coarse_checksum`) folds the whole
coarse grid and its material ids into one integer, and `:963` uses it to compare two sims built inside the
same run. Nothing records its value across runs, so it cannot answer "is this the same world as before the
change". Printing it and pinning it for one seed, for the duration of S9, is a small addition and it is the
only thing that makes the collapse provable rather than plausible.

**S3 needs one throwaway assertion.** For the duration of the change, `check_craftable_registry` should
additionally assert that the derived list equals the old hardcoded literal, in order. That assertion is
deleted with the literal. It is not a permanent guard; it is the control that makes the deletion provable.

### Integration order and independence

S0 and S1 are disjoint from everything and from each other. S2 depends on S1. S3 depends on S1 and on S2
being settled (both touch registries the same two layers read, and running them together makes a red
unattributable). S4 depends on S1. S5 depends on S1 and S4. S6 depends on S5 and on the new dashboard layer.
S7 must precede S8. S9 is disjoint from all of it and can be scheduled anywhere after S1.

No two steps here should be in flight at once on the same file. The overlap set is small and explicit:
`main.gd` is touched by S3 and S7, `factory_sim.gd` by S0, S8 and S9, `material_def.gd` by S6 and S9, and
`visuals.gd` by S6 alone.

---

## 9. What this plan deliberately does not do

- **It does not add a registry.** `docs/DECISIONS.md:47` says *"any new hardcoded registry needs its own"*
  guard, which is the right rule and the wrong direction to keep travelling in: eighteen surfaces guarded is
  worse than three surfaces deleted. Every derived view in §3 is a question about the directory, not a
  cached copy of it.
- **It does not add `ItemDef`.** §4 says why, and says what would change the answer.
- **It does not touch `_BEHAVIORS`.** The tag model is `PROVISIONAL` on purpose and this is not the moment
  to resolve it.
- **It does not split a file because it is large.** `hud.gd` and `world_renderer.gd` are god files and that
  is a different piece of work with a different safety net.
- **It does not change any content value.** Every number, colour and string already in the game is the same
  after S9 as before S0. The only visible difference is the 22 ids in S6 that currently have no colour and
  would gain one.
- **It does not lower or move any harness threshold.**

One caveat that belongs here rather than buried in S2. Once `WorldRenderer._materials` *is* the directory
scan, the first half of `tools/check_material_registry.gd` — "every `.tres` on disk is in the array" — becomes
structurally incapable of failing, because the array is the disk. That is a cue being disqualified, and the
rule is that you say what it was the only instrument for. It was the only instrument for "somebody added a
`.tres` and forgot the `load()`", and after S2 that fault cannot be constructed. Its second half, which asks
the renderer `_material(id)` for the ids the generator actually emits and checks the ore family carries
flecks (`:90`, `:98`), is still a real question about resolution and must be kept. The layer should be
rewritten around that half, with a line recording why the first half went away.

---

## 10. Open questions

Three design calls this plan will not make on its own.

1. `shale` is hand-mineable at `DEFAULT_HARDNESS` while the shelf it forms is generated as hard and
   cave-resistant. Intent or oversight? V12 can be written either way and should not guess.
2. S6 gives 18 machine items and 4 bits a colour where they currently have none, so the pack chips and the
   dashboard bars change appearance. That is a look decision, not a refactor, and it wants a yes before S6
   is scheduled.
3. `ore_vent` is the twentieth machine def and the only one absent from `_craftable`, correctly — it is a
   world-placed source. `check_craftable_registry:94` covers it only for machines the world actually placed,
   and the seeder places none. If a future generator does, it enters the pack with no icon. Should the
   catalog carry an explicit `placeable_by_player: bool`, so this is declared rather than inferred from an
   empty `craft_cost`?

**And one measurement still to take.** §2's white-bar finding is traced through source and has not been
seen on a screen. The obvious command is the wrong one:

```
godot --path . --script res://tools/check_craftable_registry.gd
```

That layer reads `machine_icons`, which is populated for every craftable machine, so it would pass and prove
nothing. The finding needs a real frame — craft a machine, open the production dashboard, and read the bar
colour drawn at `hud.gd:3712`. If a fixture is wanted instead of an eye, it is the `check_dashboard_reads`
layer described under S6, and writing it is a prerequisite for S6 anyway. Until one of those runs, the last
paragraph of §2 is a mechanism and not a defect, and it should be read that way.
