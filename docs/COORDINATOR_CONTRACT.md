# The coordinator→painter contract — Phase 0, awaiting the director's ruling

**Status: PROPOSED. Nothing here is built.** This is the Phase-0 deliverable of the coordinator-rebuild
brief: the measured reach-in surface, a proposed contract, and the honest split between what `observe()`
can answer today and what it cannot. The director rules on this before Phase 1 (the skeleton) starts.

Every number below is tool output over `legacy/scenes/`, not a reading. The scanner derives each painter's
binding name from its own source (`var _wv: WorldRenderer`, `static func paint(r: WorldRenderer, ...)`)
rather than assuming one — its first version hardcoded `r`, reported **0 reach-in for `water_view`,
`rope_view` and `machine_view`**, and all three bind under `_wv`/`_wr`. A scanner that cannot spell its
subject's name returns a quiet zero; the derived binding set is printed per file as the positive control.

---

## 1. The measured reach-in surface

Comments and strings blanked first (via `tools/layer_lint/gd_source.py`), so a field named in a
WHY-comment is not counted as an edge.

| painter | lines | binding | private reach-in | `sim.` reads | draws through coordinator |
|---|---|---|---|---|---|
| `sky_painter.gd` | 255 | `r` | **6 distinct, 8 sites** | **0** | no — takes its own `ci: CanvasItem` |
| `terrain_painter.gd` | 438 | `r` | 3 distinct, 10 sites | 31 sites, 8 distinct | no — takes its own `ci` |
| `water_view.gd` | 362 | `_wv` | 2 distinct, 5 sites | 22 sites, 5 distinct | **yes, 8 sites** |
| `rope_view.gd` | 275 | `_wr` | 2 distinct, 2 sites | 3 sites, 1 distinct | **yes, 13 sites** |
| `falling_items.gd` | 210 | none | 0 | 2 sites (`flow_events`) | no |
| `machine_view.gd` | 726 | `_wr` | 7 distinct, 22 sites | 4 sites, 4 distinct | **yes, 28 sites** |

**14 distinct private members across all six.** The brief's five (excluding `machine_view`) demand ten:
`_aim`, `_aim_in_reach`, `_anim_time`, `_cell_fill_color`, `_cell_speckles`, `_ghost_def`,
`_ghost_material`, `_guide_targets`, `_material`, `_view_world_rect`.

### They are not ten things. They are four kinds.

Sorting them by *what supplies them* rather than by name collapses the surface considerably:

| kind | members | who owns it after the rebuild |
|---|---|---|
| **cosmetic clock** | `_anim_time` (4 painters), `daylight()`, `day_phase()` | the new coordinator, trivially |
| **camera/viewport** | `_view_world_rect()` (2), `_zoom` | the new coordinator, from its own `Camera2D` |
| **palette** | `_cell_fill_color`, `_cell_speckles`, `_material` | `MaterialLook`, which already exists |
| **UI-marker positions** | `_guide_targets`, `_aim`, `_aim_in_reach`, `_ghost_def`, `_ghost_material` | see below — this collapses to one argument |

**The UI-marker group is the significant finding.** All five of `sky_painter`'s named fields feed one
local variable inside `_stars`: `marks`, a `PackedVector2Array` of screen positions where stars must fade
out so a UI marker over them stays legible. They are not sky state, and they are not five inputs — they
are one. `sky_painter` does not need to know that a guide chevron and a build ghost exist; it needs to
know *where not to put stars*. The contract passes `marks` and the five fields never cross the boundary.

Two of those five (`_ghost_def: MachineDef`, `_guide_targets` from the objective system) are the only
route by which `sky_painter` touches the dead economy at all. Collapsing them to `marks` severs it — and
`marks` is **empty in this build**, which the legacy code already handles as its designed path: *"With no
marker in the sky none of this fires and the field is exactly what it was."*

---

## 2. The proposed contract

```gdscript
## view/frame.gd — what a painter is given, and the only thing it may read.
class_name Frame
extends RefCounted

var obs: Interface.Observation   ## the sim half, verbatim — the ONLY route to sim state
var anim_time: float             ## free-running cosmetic clock; never feeds the sim
var view_world_rect: Rect2       ## camera-derived, in world px
var zoom: float
var look: MaterialLook           ## the palette, moved from tests/body/
var marks: PackedVector2Array    ## world-px positions where UI markers need clearance
```

Painters stay **static and stateless**, taking `(frame: Frame, ci: CanvasItem)` — `sky_painter` and
`terrain_painter`'s existing convention, not `water_view`'s.

### Three judgment calls inside that, stated rather than buried

**(a) An explicit `ci: CanvasItem`, not drawing through the coordinator.** Legacy has *both*
conventions — `sky_painter`/`terrain_painter` take a canvas; `water_view`/`rope_view`/`machine_view` call
`_wr.draw_line(...)` on the coordinator itself (49 sites between them). The rebuild has to pick one, and
the explicit parameter is better on three axes: parallax needs *several* CanvasItems and the coordinator
is only one (this is exactly what the already-lifted `view/fx/light_layer.gd` is — a separate canvas with
its own blend mode); a painter taking its canvas is testable with no coordinator at all; and it is the
convention of the two painters actually being lifted. Cost: the three `_wr.draw_*` painters need a
mechanical rewrite when their turn comes. Given §3, their turn is not close.

**(b) `Frame` holds `Observation` rather than flattening it.** Copying the observation's fields onto
`Frame` would put two definitions of the body's box edges in the tree, which is the drift `interface.gd`'s
own header says the layer exists to prevent.

**(c) `marks` is computed by the coordinator.** The alternative — passing the aim and guide state through
and letting each painter decide clearance — spreads a UI-legibility rule across every painter.

---

## 3. What `observe()` can and cannot answer — and this is the load-bearing part

`Interface.Observation` today carries: `tick`, `pos_x/y`, `left_x`, `right_x`, `top_y`, `bottom_y`,
`vel_x/y`, `on_floor`, `facing`, `cell`, `window`, `materials`, `legend`, and the methods `solid_at`,
`material_at`, `in_window`.

### 3a. `terrain_painter` — 8 demands, 3 map, 5 do not

| legacy demand | sites | maps to | verdict |
|---|---|---|---|
| `sim.is_solid(c)` | 18 | `obs.solid_at(c)` | **clean** |
| `sim.material_at(c)` | 2 | `obs.material_at(c)` | **clean** |
| `sim.solid` (raw) | 3 | `obs.solid_at(c)` | clean, via the method |
| `sim.in_bounds(c)` | 1 | `obs.in_window(c)` | ⚠ **not the same question** — see below |
| `sim.wall` | 1 | `TileGrid.get_wall` exists; **`Observation` does not expose it** | **GAP** |
| `sim.surface_row(x)` | 4 | nothing in `Observation` | **GAP** |
| `sim.ramp_dir(c)` | 1 | no ramps in this build | **absent** |
| `sim.deposits` | 1 | superseded by the lode/wall plane | **absent** |

**The `in_bounds`/`in_window` distinction is a real trap, not pedantry.** `in_bounds` asks "is this cell
in the world"; `in_window` asks "was I given this cell". `Observation.material_at` deliberately returns
`&""` outside the window — *not* "unknown" — and `interface.gd` says so explicitly, noting the difference
starts mattering as soon as fog exists. A painter that swaps one for the other reads the world's edge and
the window's edge as the same thing and draws a wall where the viewport stops.

**The wall-plane gap is the one worth ruling on.** `TileGrid` has `get_wall`/`set_wall` and the lode
migration put ore *into* that plane, so the data exists in the sim and simply has no door. Adding
`walls`/`wall_legend` to `Observation` mirrors the `materials`/`legend` pair exactly and is maybe 15 lines
— but it widens the L2 contract, which is an ADR-gated surface (`docs/adr/0007-l2-interface.md`), so it is
the director's to approve rather than a session's to slip in. **Without it, `terrain_painter` cannot draw
the background wall at all**, and the recessed back-wall plane is a large part of what makes legacy's
rooms read as rooms rather than as holes in a sheet (map, Finding 03).

### 3b. The other four painters — blocked on sim modules that do not exist

Nine of fifteen `sim/` modules are **empty directories holding only a `MODULE.md`**: `behaviors`,
`economy`, `fluid`, `items`, `machines`, `meta`, `run`, `telemetry`, `transport`. Measured, `.gd` files
and lines per module:

```
sim/body 5 files 921 lines      sim/mining 2 / 401      sim/terrain_gen 3 / 353
sim/world 3 / 254               sim/invariants 1 / 215   sim/commands 1 / 66
sim/behaviors 0/0   sim/economy 0/0   sim/fluid 0/0   sim/items 0/0
sim/machines 0/0    sim/meta 0/0      sim/run 0/0     sim/telemetry 0/0   sim/transport 0/0
```

| painter | needs | status |
|---|---|---|
| `water_view` | `sim.water`, `water_at`, `fill` | `sim/fluid` is **empty** — no water simulation exists |
| `rope_view` | `sim.rope`, `player.grapple`, `player.hand` | `sim/transport` **empty**; no grapple in `sim/body` |
| `falling_items` | `sim.flow_events` | `sim/items` **empty** |
| `machine_view` | `machines`, `lode_fraction`, `machine_status` | `sim/machines` **empty**, and the economy is OUT |

**This is a correction to the brief's Phase 2.** The brief lists "water_view, rope_view, falling_items —
each against the same contract" as the work after `terrain_painter`. None of the three is blocked on the
*contract*; all three are blocked on **subsystems that have no code**. No contract shape unblocks them.
Lifting them would mean writing a fluid simulation, a rope/transport system and an item-flow system
first — none of which is view work, and one of which (items/flow) is economy-adjacent and out.

So the reachable Phase 2 is **`sky_painter`, then as much of `terrain_painter` as the wall ruling allows**,
and then the batch is dry again for the same reason the last one was: the blocker is missing sim, not
missing view.

### 3c. `sky_painter` needs nothing from `observe()` at all — measured, 0 `sim.` reads

Which makes it a genuinely clean proof-of-contract, exactly as the brief guessed. Its full demand is
`anim_time`, `marks`, and two clock functions. But:

**There is no day/night clock in this build.** `daylight()` and `day_phase()` are `WorldRenderer` methods
with no counterpart here, and the world is a shaft that starts underground. The sky needs a cosmetic
clock invented — ~10 lines on the coordinator, cosmetic only, never touching the sim. Trivial to write;
worth *naming* because "lift sky_painter" sounds like pure porting and one small new thing is being
authored inside it.

---

## 4. One blocker the fixed layer lint will catch on the very first painter

`sky_painter` calls `Seams.grain(...)` **five times** — it is what makes the starfield a field and not a
lattice, and that hash is the reason the file was ported the way it was.

`Seams` lives in **`sim/world/seams.gd`** (we lifted it there last run, D0227). The layer table gives
`view` only `{interface, core}`. **So the first painter lifted trips a `view → sim` violation** — and
because D0224 taught the lint to resolve `class_name` edges, it will now actually be caught, on a real
file rather than a planted one. (P008 notes `view/` currently has zero outgoing `class_name` edges and
that the first real one would be the lint's first genuine test. This is that edge, arriving earlier than
expected.)

**`Seams` is `core/`-shaped and is in the wrong module.** Measured: it declares `class_name Seams`, and
the only capitalised identifiers it references are `RefCounted`, `Vector2i` and its own constants —
**zero project dependencies**. It is pure deterministic integer hashing. Its only consumer in the live
tree is `tests/test_seams.gd`.

**Recommendation: `git mv sim/world/seams.gd core/seams.gd`.** GDScript `class_name` globals are
path-independent, so the test needs no edit; the cost is one move plus `sim/world/MODULE.md` and
`core/MODULE.md`. Doing it now is near-free precisely because the file has no consumers yet — which is the
one advantage of last run's finding that three of four lifts landed unused.

*Alternative if the director prefers `Seams` stay put:* the coordinator owns its own hash and passes
star positions in. That is worse — it duplicates a hash whose exactness we proved over 196,608
comparisons — and it is offered only so the fork is visible.

---

## 5. What Phase 1 does to the LOC ratio (gate 7), and it is good news

**The entire current renderer lives in `tests/body/`**: `reveal_scene.gd` (398), `play_scene.gd` (247),
`material_look.gd` (136), `mining_overlay.gd`, `debug_scene_common.gd` (111). `view/` holds four files
totalling 388 lines, three of which have no consumer.

`tests/` is an **instrument** directory for gate 7; `view/` is a **game** directory. Moving the palette and
the overlay into `view/` therefore moves lines *from* the numerator *to* the denominator — it improves the
ratio from both ends at once. Two files have already declared this move in their own headers:

- `material_look.gd`: *"This is a seam to formalise, not a home — at Slice 3 it moves to `view/` behind
  the real coordinator."*
- `mining_overlay.gd`: *"the day `interface.observe()` lands, this moves to `view/` and takes an
  observation."*

Both were written by earlier sessions anticipating exactly this rebuild. Phase 1 should collect them.

---

## 6. What the director rules on before Phase 1

1. **The `Frame` contract** in §2 — and specifically the explicit-`CanvasItem` convention (a) over
   drawing through the coordinator.
2. **The wall plane in `Observation`** (§3a). Add `walls`/`wall_legend` — widening the ADR-gated L2
   surface — or accept that `terrain_painter` cannot draw the back wall and lift it without one?
3. **`Seams` to `core/`** (§4), or the coordinator owns a duplicate hash?
4. **Phase 2's real scope** (§3b): confirm it ends after `sky_painter` + `terrain_painter`, since the
   other three are blocked on empty sim modules rather than on the contract.
5. **The cosmetic day/night clock** (§3c) — is a sky with a day cycle wanted at all in a game that starts
   underground, or should `sky_painter` land with the clock pinned to one value?

Question 4 is the one that changes the shape of the run. The other four are answerable in a sentence each.
