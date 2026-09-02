# PORT_ORDER — the dependency-ordered port sequence

**Written 2026-09-01 on the director's sequential-port directive.** One complete vertical at a time, in
dependency order, each RUNNING and verified before the next begins.

## What this file is, and what the other two are not

Three documents describe the legacy migration and they cut it three different ways. They do not compete:

| Doc | Cut | Answers |
|---|---|---|
| `LEGACY_MIGRATION_MAP_2026-08-29.md` | file-level, 265 rows | *does this file come over* |
| `LEGACY_GAP.md` | capability-level, ~667 rows, ranked by impact × portability | *what is the most valuable next thing* |
| **this file** | **component-level, ordered by dependency** | ***what may be ported next without porting something before its dependencies*** |

The gap doc's ranking is by payoff. This file's ordering is by what is *possible*. Where they disagree,
this file wins on sequence and the gap doc wins on what to do inside a component — a high-payoff row
whose dependency is not in yet cannot be first, however high it ranks.

## The rule

A component may be ported only when everything it depends on is merged and green. A component is
LOGIC + VIEW + DATA together, so it works end-to-end before the next begins. Nothing is "ported" until
it runs.

---

## Measured foundation — what is already in, verified in the tree 2026-09-01

Not taken from any document; each was enumerated from the working tree at `d76bd938`.

```
core/        Fx, Seams, SplitRng, BitOps, EntityIdPool                     422 lines
sim/         TileGrid, Materials, ShaftGenerator, CavePasses, ValueNoise,
             Body (+gait, resolve, dig, heightfield), Mining, HollowTell  2928 lines
interface/   Interface.observe / apply, Envelope                           446 lines
view/        Frame, WorldView, PaintLayer, CameraRig, Controls            5865 lines
             painters: sky wall veil glint seam crack crumble backdrop
                       terrain, miner_look, material_look
             hud:      ui_theme(18/36) hud_layer depth_chip arrival_plate
                       key_legend
             audio:    score sfx(168/1125) sfx_bank
             fx:       particles light_layer
shell/       settings, settings_bindings                                   497 lines
data/        materials(8 yaml) strata bands progression                    — machines/ and
                                                                             recipes/ are
                                                                             README-only
```

**The four L0–L2 layers are done.** Every component below is view, systems, or content. This is why
sequential porting is now possible and was not three weeks ago: the substrate a port lands *into* exists.

## The three open prerequisites, and exactly what each blocks

Named here because a component blocked on one of these must not be started, not because it is hard but
because it cannot be finished.

| # | Prerequisite | Verified | Blocks |
|---|---|---|---|
| **PRE-2** | `Fx` has no `normalize` / `dot` / `limit_length` | `core/fixed_point.gd` has `mul div lerp isqrt length length_sq` and nothing else — confirmed 2026-09-01 | **V9** only |
| **WATER-FIELD** | `TileGrid` has `_blocks`, `_walls`, `_dig_extent` and no water plane | confirmed 2026-09-01 | **V5** only |
| **WG-2** | the cave-shelf assertion is `shelf_frac > 0.0` against a noise floor (`NEEDS_DIRECTOR.md` P028) | open ruling | nothing structurally — it makes every *visual verdict* provisional, see below |

**WG-2 does not gate the sequence.** `LEGACY_GAP.md` Tier 0 argues the generator defects should precede
any visual port, because a visual judgement against a broken world is a judgement about a broken world.
That argument is about *when to trust a screenshot*, not about what depends on what. The port order
below stands; what WG-2 costs is that a look verdict taken before it closes is provisional and may need
re-taking. Recorded so a later session does not mistake a provisional verdict for a settled one.

---

## The order

Each component names its legacy source, what it depends on, and what makes it *done*. Estimates are
legacy lines to port, not effort.

### V1 · The bake — static terrain drawn once, not every frame

| | |
|---|---|
| **Legacy** | `world_renderer.gd:303-312, 410-435, 703-748, 1370-1377`; `erase.gdshader` (11) |
| **Depends on** | the painters (all landed) |
| **Lines** | ~250 |
| **Done when** | `WorldView` draws one textured quad; a dig re-bakes only its chunks; a capture is pixel-identical to the per-frame path |

**First, and not because it is the most visible.** It is the performance floor. This build re-issues
every per-cell painter loop on every rendered frame; legacy bakes the static terrain into a world-sized
`SubViewport` once and replays one quad, and states the reason itself at `world_renderer.gd:698` —
*"The bottleneck was GDScript re-issuing the whole world's draw commands every frame; the sim itself
costs almost nothing."* Legacy measured the terrain pass at ~72% of frame draw calls, ~11,882 of them,
issued once rather than per frame.

Measured here before the port: **22.5 ticks/s at the 40-metre framing against a 120 Hz bar, 5.3x out of
budget**, on a world legacy ran at speed. Every component after this one adds draw work. Ordering it
first is what makes each later component's performance verdict mean anything — and it is the reason a
component whose only defect is "it made the game slower" can be attributed to itself rather than to the
accumulated weight of everything before it.

The camera framing fix folds in here: `CameraRig`'s zoom ladder is ported and tested and cannot become
the default while the frame costs what it currently costs (`D0325`).

### V2 · Molded rock — the terrain stops being squares

| | |
|---|---|
| **Legacy** | `scenes/fine_terrain.gd` — the SHADING only, `:380-505` and `:993-1085` |
| **Depends on** | **V1** — it bakes into the same target and is unaffordable per-frame |
| **Lines** | ~560 of shading, **not** the 1,402-line file |
| **Status** | **LANDED 2026-09-01 as `view/visuals/rock_tone.gd` (D0327)** |

**RE-SCOPED BY A MEASUREMENT, and the original estimate here was wrong.** This row was written to port
that file whole. It should not be: legacy renders on a fine grid of 8px cells against a 32px/1-metre
coarse cell, so its fine cell is 1/4 metre — and **this build's 4px terrain cell against 16px/metre is
also 1/4 metre**. The two grids are the same physical granularity. Porting the subdivision would have
produced 1/16-metre cells, four times finer than legacy ever rendered at sixteen times the cost, which is
D0305's regime trap in its sharpest form.

So the ~435 lines of subdivision bookkeeping do not come over, and every frequency constant ports
UNCHANGED because both grids sample at the same scale. Three of the file's five over-limit functions were
in the half that was dropped. The `grammar:` field in `data/materials/*.yaml`, carried since Slice 0 and
read by nothing, got its first consumer here.

Still open, and deliberately: every term needing a NEIGHBOUR — carved-edge AO, rim light, sky-form
gradient, moss, hanging tufts, the soil profile. All reachable through `Observation.material_at`.

Two halves and both are required for the vertical to be complete. The view half (1402) takes its shape
from the sim as injected `Callable`s and its 11 noise fields are purely cosmetic, so `FastNoiseLite` is
legal there. The sim half (114) is on the deterministic path and **must** swap `FastNoiseLite` for
`core/SplitRng` — gate 2 bans the engine class by name in `sim/`.

**The migration map's own risk note applies here and is the reason this is one component rather than
two:** do the sim-side noise swap *before* any golden hash or fixture is authored against lifted
terrain, or the reseeding cost is paid twice.

### V3 · The shader pass — the look through glass

| | |
|---|---|
| **Legacy** | `post_fx.gdshader` (85), `rock_tooth.gdshader` (69), `rock_grit.gdshader` (44), `heat_haze.gdshader` (24) |
| **Depends on** | **V1, V2** — each shader targets a surface those two define |
| **Lines** | ~222 |
| **Done when** | the four are on their surfaces and a capture shows the grade |

**LANDED: `post_fx` (D0328) and `rock_grit` (D0331).** Still open: `rock_tooth` and `heat_haze`.

**`rock_tooth` NEEDS A GRAMMAR MAP FIRST, and legacy's own header says why in numbers.** It is the one
rock pass that draws ABOVE the darkness veil, adding absolute value levels — which is exactly what keeps
deep rock readable now that D0332's skylight multiplies it down. But legacy shipped it isotropic and
measured the cost: `hash(floor(world_pos))` is *"per-world-pixel white noise: the highest-frequency, most
isotropic signal available, added on top of everything else at the largest amplitude any rock mark gets.
It raised the horizontal and vertical gradients by the same amount everywhere and flattened the grammar
underneath it."* Measured — stone's rendered anisotropy at +0.019 against earth's +0.022, indistinguishable
from that layer's own earth-vs-earth null, while **with the pass disabled the gap was 0.038, six times
wider.** Two materials whose seam sampling differs by 3.40 against 1.00 were rendering as one isotropic
field.

Legacy's fix is `gram_tex`: the coarse grammar map as a texture on the same world rect as the bake, so
the hash cell can be stretched per material — soil square, bedded flat, massive steep. **This build has
no equivalent yet.** The clean route is a second `SubViewport` target in `TerrainBake` holding one byte
per cell, invalidated by exactly the same dig path the colour target already uses; a per-frame GDScript
map would rebuild every tick for data that only changes when the terrain does.

*Checked and clear:* the shipped `rock_grit` (D0331) does **not** carry this defect — legacy's grit is
isotropic too, and only the tooth was made direction-aware.

`rock_grit` hardcodes legacy's 8px fine cell and retunes to 4px — a constant, not a redesign (Q1 is
ruled: adapt the art, never coarsen the world).

### V4 · The visuals registry — what things ARE

| | |
|---|---|
| **Legacy** | `scenes/visuals.gd` (1850) |
| **Depends on** | `art.gd` (landed), `data/materials` (landed) |
| **Lines** | ~1,850, minus the dead-economy looks |
| **Done when** | every material, item and machine this build has a record for has a look, read through one registry |

The directive's "materials layer — everything reads it." `view/visuals/material_look.gd` (382) is the
terrain-cell subset of it; the item and machine look registries are absent, and V5, V6 and V7 all read
them.

**Ported here but consumed later, which is the one place this order deliberately breaks its own
"complete vertical" rule.** The alternative is worse: splitting the registry across three later
components means three sessions each porting a third of one file and reconciling the palette three
times. The guard against this becoming another `art.gd` — lifted, correct, referenced by nothing for
four sessions — is that **V5 follows immediately** and is its first consumer. If V5 slips, V4 waits.

### V5 · Water — the first system

| | |
|---|---|
| **Legacy** | `src/core/water_flow.gd` (100, sim) + `scenes/water_view.gd` (362, view) |
| **Depends on** | **WATER-FIELD** (a water plane on `TileGrid` + on the `Observation`), V1 |
| **Lines** | ~462 + the field |
| **Done when** | water flows, conserves, renders with its surface line and depth shading, and the conservation suite covers it |

The cleanest system port available. `water_flow.gd` is **integer levels only** — no float anywhere, so
no `Fx` conversion is needed, contrary to the migration map's first pass — snapshot-based with an
explicit deterministic sort, so its dict iteration is already order-stable. Its stated contract, *"no
source, no drain, sum invariant"*, is exactly what this build's conservation suite already checks for.

`water_view.gd` carries a measured extraction-seam table in its own header; use it for the split rather
than inventing boundaries.

### V6 · Items — mining yields something

| | |
|---|---|
| **Legacy** | `falling_items.gd` (210), `payouts.gd` (77), the item half of V4 |
| **Depends on** | **V4**, Mining (landed) |
| **Lines** | ~287 |
| **Done when** | a broken cell drops a visible item at item scale, and a payout tick rises off it |

The first component that makes mining *produce* rather than delete. GDD §13's *"every item always
visible at item scale"*; GDD §7 forbids abstract points, not showing the material you just got.

### V7 · Inventory + hotbar — somewhere to put them

| | |
|---|---|
| **Legacy** | `hud.gd` hotbar block, `ui_theme.gd` (the missing 18 of 36), `page_surface.gd` (81) |
| **Depends on** | **V6** — a container with nothing to contain is a stub |
| **Lines** | ~400 |
| **Done when** | picked-up items are held, shown, and selectable |

### V8 · Machines — the factory begins

| | |
|---|---|
| **Legacy** | `machine_state.gd` (45), `machine_view.gd` (726), the machine half of V4, 20 `.tres` records |
| **Depends on** | **V6, V7**, and `data/machines/` (README-only today) |
| **Lines** | ~1,100 |
| **Done when** | a machine can be placed, is fed, runs, and shows it |

**The contamination gate closes here, at conversion, not in review.** Every `.tres` carries
`craft_cost`/`craft_count`; those fields are stripped as the records become YAML and the schema
validator must *reject* them, so re-adding one fails a gate. `machine_state.gd`'s `fed` field is
overloaded by two legacy runners meaning different things — its own comment says *"check both before
splitting it"*.

### V9 · Grapple + rope — the traversal identity

| | |
|---|---|
| **Legacy** | `grapple.gd` (389), `rope_view.gd` (274) |
| **Depends on** | **PRE-2** (the `Fx` vector layer, ~40 lines + tests) — **and P-28 is RESOLVER-PARKED** |
| **Lines** | ~663 + 40 |
| **Done when** | not startable; the resolver is off-limits autonomously |

Placed by dependency, not by rank — it rates far higher in `LEGACY_GAP.md` (T1 #12) and in the
director's own stated direction (*grapple-centred movement*). It sits here because it cannot be
finished before PRE-2, and its collision half needs a resolver ruling this session may not make.

**The `Fx` vector layer itself (PRE-2) is decision-free and can be built at any point**, and carries a
trap worth stating before someone hits it: do not store `PUMP_CLAMP 1.05` and its reciprocal as two Fx
literals — `1.05*65536 = 68812` and `1/1.05*65536 = 62415` are not inverses, and an alternating
reel/pay sequence biases tangential speed down by ~1.6e-5 per pair. Store the rational `21/20` and use
integer mul/div, as `AIR_CONTROL_NUM/DEN` and `Mining.REACH_NUM/DEN` already do.

### V10 · Transport — the winch

| | |
|---|---|
| **Legacy** | `winch_head.tres`, `winch_station.tres`, `factory_sim.gd`'s winch block, `lift.tres` |
| **Depends on** | **V8** |
| **Done when** | a route hauls on a fixed transit duration with a throttled per-trip capacity |

GDD §9 kills the Bazaar and names this the one thing to *repurpose rather than delete*: *"a throttled
per-trip capacity plus a fixed transit duration linking two arbitrary cells."* That is the Freight Winch
and the director's brief already approved it.

### V11 · Power — deferred tier, ported mechanism

| | |
|---|---|
| **Legacy** | `power_flow.gd` (89), `generator.tres`, `conduit.tres` |
| **Depends on** | **V8, V10** |
| **Done when** | mechanism ported; **tier placement NOT wired** (Q3 ruled: defer to the economy work) |

GDD §9 dead-lists *"electricity as an early automation tier"* but also warns that removing power
silently freezes every upward machine at unpowered throughput — *"the worst failure class this project
has."* Port the mechanism, do not wire the tier.

### V12 · HUD furniture — hints, hover, objectives

| | |
|---|---|
| **Legacy** | `hints.gd` (317), `hover_info.gd` (188), `objectives.gd` (211) |
| **Depends on** | **V8, V10, V11** — each describes systems that must exist first |
| **Done when** | the mechanisms run against re-authored content |

All three are MERGE, not LIFT: the mechanisms lift whole and every content table teaches a dead machine
(`descent_engine`, BORER, spur, drift_rig, conduit, generator, "take it to the BENCH"). The content is
re-authored against what this build actually has, which is why it comes last among the view work.

### V13 · Economy / rig-as-consumer — **NOT A PORT**

**Director ruling territory. Do not autonomously build.** GDD §3 names legacy's defect: its refined
output was terminal. Rig-as-consumer is the redesign that fixes it, and a redesign is not a port. The
44 content records arrive here with `craft_cost` already stripped by V8's gate.

---

## What this order does not include, and why

- **`main.gd` (3003) and `world_renderer.gd` (3656) as files.** Both are REBUILD, and both are already
  being dissolved into the components above rather than ported whole — the coordinator spine landed as
  `view/world_view.gd` + `view/frame.gd` (D0240/D0244), and the camera as `view/camera_rig.gd` (D0273).
  There is no component called "port world_renderer"; there are components that take pieces of it.
- **`player.gd` (818), `factory_sim.gd` (3259), the two world generators.** KEEP-CURRENT. This build's
  sim wins outright and lifting them would delete gates 2, 8, 24, 25, 26 and the fuzzer.
- **The Bazaar (8 files, ~2,600 lines), `research_rules.gd`, `descent_engine`, `h_drill`.** Dead by
  GDD §9, by name.
- **Legacy's 151-layer harness.** Superseded by this build's substrate, which is the part of this
  project that already wins.

## Rules that hold for every component

1. **Port, don't rewrite.** Copy the legacy block; adapt only what the layer boundary or the unit regime
   forces. Name the legacy source in the file header.
2. **Its audio comes with it.** `sfx.gd` (1125) is not a component — every sound is synthesized at boot
   and belongs to the system that makes it. A vertical brings its own sounds or it is not complete.
3. **Determinism is never deferred.** The one thing "fix later" cannot do cleanly.
4. **Fail closed.** A new guard that cannot register its subject passes silently; seven such vacuous
   greens have been found in this repository. A new check must fail on an absent measurement.
5. **Size caps are met by splitting, never by trimming legacy's comments** (`QUALITY.md` §2). Legacy
   measured its own extraction seams for the two coordinators; use those tables.
6. **A feel/look item is BUILT-PARKED with a capture, never "done".**

## The unit regime, in one place

Every component crosses it, and getting it wrong is D0310's trap in both directions.

```
terrain cell     legacy 32px  ->  this build 4px
cells per metre  legacy 1     ->  this build 4          (TERRAIN_CELLS_PER_METER)
pixels per metre legacy 32    ->  this build 16
```

**What is conserved is METRES, not pixels.** A field-of-view constant converts ×2 (`D0325`). A BODY
constant is the opposite regime and ports unchanged, pixel-for-pixel (`D0310`). A fine-detail size in
world px converts ×(4/8) = ×0.5. Ask which of the three a constant is before touching it.
