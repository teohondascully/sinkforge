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
## Aquifer water (L3): cell (Vector2i) -> level (1..FactorySim.WATER_MAX). Sparse — only
## watered cells appear, and only in CARVED-OPEN cells deep in the rock (a generator seeds sealed pressurized
## pockets you BREACH). Ingested by FactorySim.load_world into `sim.water`; an older WorldData without this
## just yields a dry world (default empty). The gen→sim channel for the deep aquifers.
var water: Dictionary = {}


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows
