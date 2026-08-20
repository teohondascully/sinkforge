class_name WorldData
extends RefCounted

## What a WorldGen produces and FactorySim ingests: plain data with no engine, scene or sim dependency, so a
## generator can be built and tested in isolation. Cells store material ids; the appearance of an id lives in
## its MaterialDef, in the visualiser's registry.

var cols: int = 0
var rows: int = 0
## The seed that produced this world, kept for repro: the same seed gives identical grids.
var seed: int = 0
## Foreground solid layer: cell (Vector2i) -> material id. The ground walked on and dug.
var blocks: Dictionary = {}
## Background layer: cell (Vector2i) -> material id. Walls behind dug-out cells (Terraria-style).
var walls: Dictionary = {}
## Ore deposit richness: cell -> remaining yield. Sparse; an ore cell absent here reads as
## FactorySim.DEFAULT_ORE_DEPOSIT, currently 250, which is what all seven consumers pass to `.get`.
## The gen->sim channel for finite, depth-scaled deposits.
var amounts: Dictionary = {}
## THE LODE PLANE: cell -> ore material id, in the BACKGROUND plane behind whatever rock `blocks` puts in front
## of it. Sparse. The gen->sim channel for lodes: without it the only writer of `sim.lode` outside save/load is
## `factory_sim.gd`'s mining branch, so a fresh world holds none.
##
## INVARIANT, since `blocks` and this grid address the same cells: a lode may sit under solid HOST ROCK, but
## never in the same cell as a solid ORE-LIKE block, which would be double-sourced because mining an ore block
## writes its own lode there and overwrites this one's richness. Enforced in `_grow_lode`; `load_world` ingests
## faithfully, so a violation fails a test rather than going missing.
var lodes: Dictionary = {}
## Aquifer water (L3): cell -> level (1..FactorySim.WATER_MAX). Sparse, and only in carved-open cells
## deep in the rock. Ingested by FactorySim.load_world; absent means a dry world.
var water: Dictionary = {}
## PROVENANCE, not content: cell -> true for every cell a deliberate vertical route carved, i.e. the rifts and
## the sinkhole throats. Never read by the sim, never saved. It lets the dig-your-factory identity guard exclude
## designed structure from its open-cell count, which cannot otherwise tell a cut chasm from undirected cave.
var routes: Dictionary = {}


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows
