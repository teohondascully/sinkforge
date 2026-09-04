class_name WaterDrips
extends RefCounted

## Water motion cue, representation only (A' step 6a, D0362; legacy `scenes/water_view.gd`'s
## `_spawn_water_drips`). A pouring water cell -- one with open, non-solid, non-full space directly below
## it -- occasionally sheds a cool-blue drip into the particle layer, and where the drop lands there is a
## small splash. Rate-limited so a steady waterfall shimmers with the odd drop rather than running as a
## firehose: each on-screen pouring cell is gated by a per-cell staggered phase so only a fraction spawn on
## any frame, and a hard per-frame cap bounds the total. View-culled. Reads the OBSERVATION (water and
## solid), writes only the cosmetic particle layer; `randf` is safe here for the reason `particles.gd`
## states -- nothing here is ever read back by the sim.

const CELL: float = float(Interface.Observation.CELL_PX)
const WATER_MAX: int = Interface.Observation.WATER_MAX
const DRIP_PERIOD: float = 0.9                       ## a cell sheds at most one drip per this window
const DRIP_MAX_PER_FRAME: int = 6                    ## hard cap so a wide sheet cannot flood the pool
const SPLASH_REACH: int = 32                         ## cells a pour is followed down for its splash (legacy 8 of 32 px)


## "Pouring" is the sim's own fall rule: the cell below is in the window, not solid, and has room.
static func pouring(o: Interface.Observation, c: Vector2i) -> bool:
	var below: Vector2i = c + Vector2i(0, 1)
	return o.in_window(below) and o.material_at(below) == &"" and o.water_at(below) < WATER_MAX


## A stable per-cell phase in 0..1, so the cells of a sheet do not all pop on the same frame.
static func phase(c: Vector2i) -> float:
	var h: int = ((c.x * 73856093) ^ (c.y * 19349663)) & 0x7fffffff
	return float(h % 997) / 997.0


## Where a drop from `c` lands: the first blocker down the open column, rock or a full surface, within reach.
static func landing_cell(o: Interface.Observation, c: Vector2i) -> Vector2i:
	var land: Vector2i = c + Vector2i(0, 1)
	var steps: int = 0
	while steps < SPLASH_REACH:
		var next: Vector2i = land + Vector2i(0, 1)
		if not o.in_window(next) or o.material_at(next) != &"" or o.water_at(next) >= WATER_MAX:
			break
		land = next
		steps += 1
	return land


## Spawn this frame's drips; returns how many. The chance scales with `delta` so the rate is frame-rate
## independent, roughly one drip per DRIP_PERIOD per pouring cell.
static func spawn(o: Interface.Observation, particles: Particles, view: Rect2, delta: float) -> int:
	if o == null or particles == null or o.wet_cells.is_empty():
		return 0
	var spawned: int = 0
	for c: Vector2i in o.wet_cells:
		if spawned >= DRIP_MAX_PER_FRAME:
			break
		var base := Vector2(c) * CELL
		if not view.has_point(base) or not pouring(o, c):
			continue
		if randf() > delta / DRIP_PERIOD * (0.7 + 0.6 * phase(c)):
			continue
		particles.water_drip(Vector2(base.x + CELL * 0.5, WaterPainter.surface_y(c, o.water_at(c)) + 1.0))
		spawned += 1
		if randf() < 0.5:                             # half the drips splash, so it stays subtle
			var land: Vector2i = landing_cell(o, c)
			if view.has_point(Vector2(land) * CELL):
				particles.water_splash(Vector2(land) * CELL + Vector2(CELL * 0.5, CELL))
	return spawned
