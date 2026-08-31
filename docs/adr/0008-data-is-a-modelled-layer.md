# ADR 0008: `data` is a modelled layer, and `view` may read appearance from it

**Status:** accepted, 2026-08-30. Ruled by the director as `docs/NEEDS_DIRECTOR.md` P013;
`docs/DECISIONS_LEDGER.md` D0243. Required because it amends `docs/ARCHITECTURE.md` §3, whose own header
states that changes to it need an ADR.

## Context

`view/visuals/material_look.gd` turns a material id into a `Color` by reading `MaterialsRecords` and
`BandsRecords` — generated records under `data/`, emitted by `tools/data_codegen` per ADR 0004. That is a
`view -> data` edge, and §3's dependency table granted `data` to `shell` alone.

**The edge was neither permitted nor forbidden, and that is the part worth recording.**
`tools/layer_lint/layer_lint.py` kept `data` in its `UNPOLICED` set, so `layer_of()` returned `None` for
every file under it and no edge to a generated record was ever constructed. The lint printed the same
`PASS` whether the edge existed or not. A rule that lives only in a table nothing evaluates is not a
weak rule — it is a rule whose gate cannot register its subject, which `docs/QUALITY.md` §2 names as this
project's dominant failure class.

The question surfaced when the coordinator rebuild moved `MaterialLook` into `view/` (D0240). It arrives
twice more in the same rebuild: `terrain_painter` needs the same palette, and `art.gd` reads sprites.

## Decision

**Three changes, and the second is what makes the first safe.**

1. **`data` becomes a modelled layer** — removed from `UNPOLICED`, added to `ALLOWED`. Its files are
   scanned, its `class_name` globals enter the class map, and edges to them are evaluated like any other.

2. **`data` depends on nothing.** `ALLOWED["data"] = set()`. This is the load-bearing line: a leaf cannot
   launder a dependency, so `view -> data` provably cannot become a route to `sim`. Measured at the time
   of writing, the three generated files reference only `Dictionary`, `RefCounted` and their own class
   names — and the property is enforced rather than observed, by a planted `data -> sim` edge that must
   fail.

3. **`view` and `sim` are granted `data`; the other layers are not.** `view` for appearance, which is the
   ruling. `sim` because `WorldMaterials` reads `MaterialsRecords` and `StrataData` reads
   `StrataRecords` — edges that already shipped, are documented in both MODULE.md files and in ADR 0004,
   and were simply never written into the table. Switching enforcement on while granting only `view`
   would have turned two legitimate edges red.

### Why a renderer reading colours is the right rule

The alternative is routing authored palette data through `interface` and into `Observation`. That puts
art inside the L2 door and buys nothing: the envelope exists to stop a consumer reading **sim state**
around the filter, and a static colour table is not sim state. It cannot be used to learn where the ore
is, because it is the same table for every world and every seed.

## What this does NOT decide

- **Appearance versus the rest, as a checkable distinction.** The ruling says *appearance* data.
  `MaterialsRecords` carries `base_color` and `hardness` in one record, so no class-granularity rule can
  separate "view reads colours" from "view reads hardness". That distinction is a convention carried by
  §3's prose, not a check. What is guaranteed is containment, not intent.
- **`interface`, `harness`, `experiment`.** None is granted `data`. If one needs it, that is a fresh
  ruling; a plant in the mutation suite proves each still fails today.
- **Whether `data` should be one layer or several.** `data/materials` and `data/economy` may deserve
  different treatment when the economy exists. Not now.

## Consequences

The lint scans 34 files where it scanned 31, and evaluates 54 `class_name` edges where it evaluated 50 —
the four new ones being the two `sim -> data` and two `view -> data` edges that were previously invisible.

`tools/layer_lint/test_layer_lint.py` grows from 8 branches to 11: a legal `view -> data` edge passes, a
planted `data -> sim` edge fails, and a planted `interface -> data` edge fails. The first was also
checked in the strongest form available — revoking the grant in `ALLOWED` makes the real
`material_look.gd` edges fail, which proves the grant is doing work rather than the edge being ignored.

**The reversibility that makes this cheap:** nothing about `data`'s contents changed, no generated file
moved, and no consumer was edited. If a later ruling narrows the grant, the cost is one entry in
`ALLOWED` and whatever it then makes red.
