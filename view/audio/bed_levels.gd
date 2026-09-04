class_name BedLevels
extends RefCounted

## THE LEVEL DERIVATION (A' step 6f, D0366): what the world is doing near the body, as eight numbers in
## 0..1 for the bed driver. Legacy computed these inline in `main.gd`'s per-frame hook, reading the sim
## directly; here every one is read off the OBSERVATION, so the view holds no sim reference and the
## rules are static and posable. Only the haul is stateful: a haul is a length delta between two
## observations, so the derivation remembers the last one it saw.
##
## Legacy's radii were in its 32 px cells; a legacy cell is one logic cell here (16 px), so `NEAR_CELLS`
## is legacy's own count and the distance is measured in world px against it.

const NEAR_CELLS: int = 14          ## legacy's `14 * CELL`: how far a working machine or a pour is heard
const HUM_FULL: float = 5.0         ## working machines within reach for a full heartbeat
const SURFACE_FADE_M: float = 4.0   ## metres below the datum at which the wind has died
const CAVE_FULL_M: float = 10.0     ## metres below the datum at which the cave air is full
const POUR_FULL: float = 4.0        ## pouring cells within reach for a full pour bed
const PUMP_FULL: float = 2.0        ## working pumps within reach for a full drain bed
const TENSION_FULL: float = float(Interface.Observation.GRAVITY_PX_S2) * 2.6   ## the load at which the fibre sings flat out
const LOGIC_PX: float = float(Interface.Observation.LOGIC_PX)
const CELL_PX: float = float(Interface.Observation.CELL_PX)
const NEAR_PX_SQ: float = float(NEAR_CELLS) * LOGIC_PX * float(NEAR_CELLS) * LOGIC_PX

var _prev_length: int = -1
var _prev_tick: int = -1


static func body_px(o: Interface.Observation) -> Vector2:
	return Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)


static func logic_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * LOGIC_PX


static func terrain_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_PX


static func near(o: Interface.Observation, at_px: Vector2) -> bool:
	return body_px(o).distance_squared_to(at_px) < NEAR_PX_SQ


## The factory heartbeat: how much machinery is WORKING within reach, over the count for a full bed.
static func hum(o: Interface.Observation) -> float:
	var working: float = 0.0
	for rec: Dictionary in o.machines:
		if rec.get("status", &"") == &"working" and near(o, logic_centre(rec["cell"])):
			working += 1.0
	return clampf(working / HUM_FULL, 0.0, 1.0)


## Metres below the generated surface datum; negative in the sky.
static func depth_m(o: Interface.Observation) -> float:
	return float(o.cell.y - Interface.Observation.SKY_ROWS) * CELL_PX / LOGIC_PX


## Wind above ground, dying within a few metres of descent; cave air swelling to full ten metres down.
static func ambience(o: Interface.Observation) -> Dictionary:
	var below: float = depth_m(o)
	return {"surface": clampf(1.0 - below / SURFACE_FADE_M, 0.0, 1.0), "cave": clampf(below / CAVE_FULL_M, 0.0, 1.0)}


## The rush: speed from a run up, so a walk is the zero point and terminal fall the one. The sound has
## to mean faster than you can run, which only the rope and a drop ever give you.
static func rush(o: Interface.Observation) -> float:
	var speed: float = Vector2(float(o.vel_x), float(o.vel_y)).length() / float(Fx.SCALE)
	var run: float = float(Interface.Observation.RUN_SPEED_PX_S)
	var fall: float = float(Interface.Observation.MAX_FALL_PX_S)
	return clampf((speed - run) / (fall - run), 0.0, 1.0)


## Pouring water within reach: a wet cell whose cell below is open and not full, the same rule the
## water drips paint by, so what you see pour is what you hear.
static func pour(o: Interface.Observation) -> float:
	var pouring: float = 0.0
	for c: Vector2i in o.wet_cells:
		if not near(o, terrain_centre(c)):
			continue
		var under: Vector2i = c + Vector2i(0, 1)
		if o.in_window(under) and not o.solid_at(under) and o.water_at(under) < Interface.Observation.WATER_MAX:
			pouring += 1.0
	return clampf(pouring / POUR_FULL, 0.0, 1.0)


static func pump(o: Interface.Observation) -> float:
	var pumping: float = 0.0
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == &"pump" and rec.get("status", &"") == &"working" and near(o, logic_centre(rec["cell"])):
			pumping += 1.0
	return clampf(pumping / PUMP_FULL, 0.0, 1.0)


## How hard the drum is pulling: line taken in since the last observation, per second, over the reel
## rate. Paying out is not a haul. Stateful, and reset whenever the line is not anchored.
func haul(o: Interface.Observation) -> float:
	if not o.grapple_anchored:
		_prev_length = -1
		_prev_tick = -1
		return 0.0
	var out: float = 0.0
	if _prev_length >= 0 and o.tick > _prev_tick:
		var reeled_px: float = float(_prev_length - o.grapple_length) / float(Fx.SCALE)
		var seconds: float = float(o.tick - _prev_tick) / float(Interface.Observation.TICK_HZ)
		out = clampf((reeled_px / seconds) / float(Interface.Observation.REEL_PX_S), 0.0, 1.0)
	_prev_length = o.grapple_length
	_prev_tick = o.tick
	return out


## How hard the rope is working: centripetal pull plus the part of the body's weight hanging below the
## hitch, over the load at which the fibre sings flat out. Zero on a slack line.
static func line_load(o: Interface.Observation) -> float:
	if not o.grapple_taut:
		return 0.0
	var d: Vector2 = body_px(o) - Vector2(float(o.grapple_hitch.x), float(o.grapple_hitch.y)) / float(Fx.SCALE)
	var r: float = d.length()
	if r < 1.0:
		return 0.0
	var v: Vector2 = Vector2(float(o.vel_x), float(o.vel_y)) / float(Fx.SCALE)
	var centripetal: float = v.length_squared() / r
	var weight: float = float(Interface.Observation.GRAVITY_PX_S2) * maxf(0.0, d.y / r)
	return clampf((centripetal + weight) / TENSION_FULL, 0.0, 1.0)


## The eight levels for one observation, in the driver's vocabulary.
func levels(o: Interface.Observation) -> Dictionary:
	var amb: Dictionary = ambience(o)
	return {"hum": hum(o), "surface": amb["surface"], "cave": amb["cave"], "rush": rush(o),
		"pour": pour(o), "pump": pump(o), "haul": haul(o), "load": line_load(o)}
