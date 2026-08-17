class_name WorldData
extends RefCounted

## THE HANDSHAKE ARTIFACT. What a WorldGen PRODUCES and the FactorySim
## INGESTS — plain data with no engine/scene/sim dependency, so a generator can be built and tested
## in isolation. Two material grids (the bounded, two-layer world) plus the provenance that made it.
##
## Cells store material IDS (StringName); the appearance of an id lives in its MaterialDef (the
## visualiser's registry). Improve generation (fill these grids differently) or the look (edit
## MaterialDefs) without either side knowing about the other.

var cols: int = 0
var rows: int = 0
## The seed that produced this world — stored for determinism/repro (same seed → identical grids).
var seed: int = 0
## Foreground solid layer: cell (Vector2i) -> material id. The ground you stand on and dig.
var blocks: Dictionary = {}
## Background layer: cell (Vector2i) -> material id. Walls behind dug-out cells (Terraria-style).
var walls: Dictionary = {}
## Ore deposit richness: cell (Vector2i) -> remaining yield (how many ore the cell holds). Sparse —
## only ore cells appear, and an ore cell ABSENT here is read as amount 1 by the sim (so a generator
## that doesn't fill this still produces today's one-hit ore). The gen→sim channel for finite,
## depth-scaled deposits: generation decides how rich each vein cell is.
var amounts: Dictionary = {}
## THE LODE PLANE: cell (Vector2i) -> ore material id. Ore that lives in the BACKGROUND plane, behind
## whatever rock the `blocks` grid puts in front of it. Sparse; a cell absent here simply has no vein.
##
## This is the gen→sim channel the lode was missing, and its absence was not a degree of wrongness but a
## structural one. `FactorySim` has carried a full lode system for two strikes — `take_lode`, the Drill
## Head, Spur chaining, the drain fraction, the through-rock stain — and the ONLY thing that ever wrote to
## it outside save/load was `factory_sim.gd`'s mining branch, the blow that OPENS a vein. So lode was
## *derived from mining an ore block* and never generated: a fresh world held exactly zero, the Borer and
## the Drift Rig cut rock with nothing behind it to expose, and every fixture that appeared to prove
## otherwise injected its own lode through `world_seeder`. The seeded path was green for months while the
## generated path was false BY CONSTRUCTION, and nothing in the harness could tell the two apart.
##
## THE INVARIANT THAT MATTERS, because `blocks` and this grid address the same cells: a lode may sit under
## solid HOST ROCK — that is the entire point, you clear rock to expose a vein — but it must never share a
## cell with a solid ORE-LIKE block. That cell would be double-sourced: mining the ore block writes its own
## lode there and would overwrite this one's richness. The generator enforces it (see `_grow_lode`);
## `load_world` ingests faithfully rather than silently dropping, so a violation shows up as a test failure
## instead of as quietly missing ore.
var lodes: Dictionary = {}
## Aquifer water (L3): cell (Vector2i) -> level (1..FactorySim.WATER_MAX). Sparse — only
## watered cells appear, and only in CARVED-OPEN cells deep in the rock (a generator seeds sealed pressurized
## pockets you BREACH). Ingested by FactorySim.load_world into `sim.water`; an older WorldData without this
## just yields a dry world (default empty). The gen→sim channel for the deep aquifers.
var water: Dictionary = {}
## PROVENANCE, not content: cell (Vector2i) -> true for every cell a DELIBERATE vertical route carved —
## the rifts, and the sinkhole throats that connect them to daylight. The sim never reads it and it is
## never saved; it exists so a test can tell designed structure apart from undirected cave.
##
## That distinction is not bookkeeping. The dig-your-factory identity guard asks whether the underground
## is solid-dominant — whether caves are the MEDIUM you traverse or punctuation in rock you carve — and a
## chasm cut on purpose to give the world a vertical dimension is the opposite of the thing that guard is
## defending against, while being indistinguishable from it in a raw open-cell count. Without this, the
## only way to keep the number honest is to stop building routes.
var routes: Dictionary = {}


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows
