class_name LeafDrift
extends RefCounted

## FALLING AND DRIFTING LEAVES, ambient only (queue item 30). A canopy cell whose underside is open
## lets a leaf go now and then; it sways down on a low gravity and fades. `WaterDrips`'s shape
## exactly: reads the OBSERVATION, writes only the cosmetic particle layer, view-culled, per-cell
## staggered phase, hard per-frame cap -- a grove shimmers, it does not snow.
##
## WHERE THE CANOPY COMES FROM. There is no canopy list on the observation and building one would
## scan a plane a frame for a cosmetic. `surface_y` already answers the question per column: the sky
## floor IS the canopy top where a tree stands (leaves are solid terrain cells), so each column's
## crown is the contiguous run of leaves down from its surface cell -- a walk of a handful of cells
## per column, and a column without a tree costs one material read. A crown broken into separate
## runs in a column (a tunnel cut through it) sheds only off the top run's underside, which is the
## right answer anyway: the view can only see the underside that has open air under it.
##
## THE LEAF IS ITS OWN TREE'S GREEN. `GrassPainter.blade_color`'s rule verbatim (D0584): `leaves`'
## `base_color` varied by `BeddingTone.foliage_tone`, so a leaf reads as coming off the crown it fell
## from, and "what plant looks like" still has one home.

const CELL: float = float(Interface.Units.CELL_PX)
const SHED_PERIOD: float = 9.0        ## an open edge lets a leaf go at most this often
const LEAF_MAX_PER_FRAME: int = 3     ## hard cap so a stand of trees cannot snow
const CROWN_SCAN: int = 12            ## cells under a canopy top walked for the open-under edge


## The open-under canopy cells of `o`'s window, as data (grass_painter.gd's D0595 lesson): a leaf
## detaches where a crown ends over air, so the edge is a leaves cell whose cell below is not. One
## edge per column -- the bottom of the contiguous run under the surface.
static func shedding_edges(o: Interface.Observation) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var col: int = o.window.position.x
	while col < o.window.end.x:
		var top: int = o.surface_y_at_terrain_col(col)
		if top == Interface.Units.NO_FLOOR:
			col += 1
			continue
		var row: int = int(floor(float(top) / float(Fx.SCALE) / CELL))
		var c := Vector2i(col, row)
		if o.in_window(c) and o.material_at(c) == &"leaves":
			var bottom := c
			while bottom.y - c.y < CROWN_SCAN and o.in_window(bottom + Vector2i(0, 1)) \
					and o.material_at(bottom + Vector2i(0, 1)) == &"leaves":
				bottom += Vector2i(0, 1)
			if o.material_at(bottom + Vector2i(0, 1)) != &"leaves":
				edges.append(bottom)
		col += 1
	return edges


## A stable per-cell phase in 0..1 (water_drips.gd's hash), so a crown's edges do not all let go on
## the same frame.
static func phase(c: Vector2i) -> float:
	var h: int = ((c.x * 73856093) ^ (c.y * 19349663)) & 0x7fffffff
	return float(h % 997) / 997.0


## The green a leaf off the crown at `c` carries -- `blade_color`'s rule without the grass's darken.
static func leaf_color(c: Vector2i) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(&"leaves", {})
	var base := Color(0.18, 0.40, 0.23)
	if rec.has("base_color"):
		var a: Array = rec["base_color"]
		base = Color(float(a[0]), float(a[1]), float(a[2]))
	return BeddingTone.apply_tone(base, BeddingTone.foliage_tone(c.x, c.y))


## Spawn this frame's leaves; returns how many. The chance scales with `delta` so the rate is
## frame-rate independent, roughly one leaf per SHED_PERIOD per open edge.
static func spawn(o: Interface.Observation, particles: Particles, view: Rect2, delta: float) -> int:
	if o == null or particles == null:
		return 0
	var spawned: int = 0
	for c: Vector2i in shedding_edges(o):
		if spawned >= LEAF_MAX_PER_FRAME:
			break
		var at := Vector2(c) * CELL + Vector2(CELL * 0.5, CELL)
		if not view.has_point(at):
			continue
		if randf() > delta / SHED_PERIOD * (0.7 + 0.6 * phase(c)):
			continue
		particles.leaf(at, leaf_color(c))
		spawned += 1
	return spawned
