class_name VoiceCues
extends RefCounted

## THE ONE-SHOT CUES (A' step 6f (ii), D0367): which voices this frame calls for, as data. Legacy fired
## its one-shots from verb hooks scattered through `main.gd` (838-963, 1595, 1940-2095, 2159, 2655-2670);
## here every one is an EDGE READ OFF TWO OBSERVATIONS, the last and this, so the rules are posable and
## the sim gains no write. The decision is here and the actuation is `Sfx.play`, the split
## `legacy/tools/check_pump.gd` taught: the two fail separately and only this half is assertable
## without a device.
##
## A cue is `{voice, at (world px), pitch, db, ui}`. Positional pitches and levels are legacy's own
## numbers; body distances (a stride) are body pixels, which port identical; world offsets halve.

const STRIDE_PX: float = 22.0            ## one footstep per this much travelled
const STEP_MIN_SPEED: float = 20.0       ## px/s: below this a body is standing, not walking
const LAND_HARD_PX_S: float = 240.0      ## an impact under this is a step-off, not a landing
const GAIN_PITCH: float = 1.4
const DRIP_MIN_CAVE: float = 0.3
const DRIP_GAP_MIN: float = 3.0
const DRIP_GAP_MAX: float = 9.0
const LOGIC_PX: float = float(Interface.Observation.LOGIC_PX)
const CELL_PX: float = float(Interface.Observation.CELL_PX)

var _rng: SplitRng
## The last frame, as the three scalars the edges need rather than the observation itself: holding the
## object would alias a reused one, and an edge against yourself never fires.
var _had_prev: bool = false
var _prev_pivots: int = 0
var _prev_on_floor: bool = true
var _prev_vel_y: int = 0
var _step_dist: float = 0.0
var _seen_cells: Dictionary = {}
var _machines_primed: bool = false
var _ever_worked: bool = false
var _prev_pack: Dictionary = {}
var _pack_primed: bool = false
var _drip_in: float = 4.0


func _init(seed_value: int = 20260901) -> void:
	_rng = SplitRng.new(seed_value).split("cues")


static func px(fx: Vector2i) -> Vector2:
	return Vector2(float(fx.x), float(fx.y)) / float(Fx.SCALE)


static func body_px(o: Interface.Observation) -> Vector2:
	return Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)


static func feet_px(o: Interface.Observation) -> Vector2:
	return Vector2(float(o.pos_x), float(o.bottom_y)) / float(Fx.SCALE)


static func terrain_centre(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL_PX


static func logic_centre(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * LOGIC_PX


static func terrain_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL_PX), floori(p.y / CELL_PX))


static func hardness(material: StringName) -> float:
	return float((MaterialsRecords.RECORDS.get(material, {}) as Dictionary).get("hardness", 1.0))


## The blow's pitch: harder rock strikes lower. Legacy added a cadence term this build has no reading for.
static func blow_pitch(material: StringName) -> float:
	return clampf(1.25 - hardness(material) * 0.1, 0.8, 1.4)


## The footstep's pitch: harder ground scuffs higher and drier, on the same hardness-to-pitch idea.
static func scuff_pitch(material: StringName) -> float:
	return clampf(1.35 - hardness(material) * 0.09, 0.85, 1.35)


## What the boots are standing on. Probe just under the feet, then half a logic cell down: a body
## standing exactly on a cell boundary reads its own empty cell first.
static func ground_under(o: Interface.Observation) -> StringName:
	var feet: Vector2 = feet_px(o)
	var m: StringName = o.material_at(terrain_cell(feet + Vector2(0.0, 2.0)))
	if m == &"":
		m = o.material_at(terrain_cell(feet + Vector2(0.0, LOGIC_PX * 0.5)))
	return m


## The downward speed the body arrived with, px/s: zero unless this frame is the one it touched down on.
static func landing_impact(had_prev: bool, prev_on_floor: bool, prev_vel_y: int, o: Interface.Observation) -> float:
	if not had_prev or prev_on_floor or not o.on_floor:
		return 0.0
	return float(prev_vel_y) / float(Fx.SCALE)


func _cue(voice: StringName, at: Vector2, pitch: float = 1.0, db: float = 0.0, ui: bool = false) -> Dictionary:
	return {"voice": voice, "at": at, "pitch": pitch, "db": db, "ui": ui}


## Every cue for this frame. `cave` is the beds' smoothed cave level, the drip's gate.
func cues(o: Interface.Observation, delta: float, cave: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if o == null:
		return out
	_blow(o, out)
	_break(o, out)
	_line(o, out)
	_body(o, delta, out)
	_machines(o, out)
	_pack(o, out)
	_drip(o, delta, cave, out)
	_had_prev = true
	_prev_pivots = o.grapple_pivots.size()
	_prev_on_floor = o.on_floor
	_prev_vel_y = o.vel_y
	return out


## Every blow strikes: the material's own voice at the struck cell, the ring layered on by `Sfx`.
func _blow(o: Interface.Observation, out: Array[Dictionary]) -> void:
	if o.mining_swing and o.mining_is_charging:
		var m: StringName = o.material_at(o.mining_charging_cell)
		out.append(_cue(Sfx.strike_voice(m), terrain_centre(o.mining_charging_cell), blow_pitch(m)))


func _break(o: Interface.Observation, out: Array[Dictionary]) -> void:
	if not o.mining_broke or o.mining_broke_cells.is_empty():
		return
	var at: Vector2 = terrain_centre(o.mining_broke_cells[0])
	var metal: bool = Sfx.STRIKE.get(o.mining_broke_material, &"") == &"hit_metal"
	out.append(_cue(&"thump", at, 1.1 if metal else 1.0, 2.0 if metal else 0.0))
	if metal:
		out.append(_cue(&"vein", at, 1.16 if o.mining_broke_material == &"glimmer" else 1.0, 1.0))


## The line: a plant strikes the rock it bit (the voice is that rock's), a cut is a soft whip of
## nothing, and a catch is the rising edge of the pivot count -- the one rope event with no other tell.
func _line(o: Interface.Observation, out: Array[Dictionary]) -> void:
	if o.grapple_just_planted:
		var anchor: Vector2 = px(o.grapple_anchor)
		out.append(_cue(Sfx.strike_voice(o.material_at(terrain_cell(anchor))), anchor, 1.6, -4.0))
	elif o.grapple_just_cut:
		out.append(_cue(&"pop", body_px(o), 1.7, -12.0))
	if _had_prev and o.grapple_pivots.size() > _prev_pivots:
		out.append(_cue(&"catch", px(o.grapple_hitch), 1.0, -7.0))


## Landing juice scales with impact; footsteps one every stride, over the material underfoot.
func _body(o: Interface.Observation, delta: float, out: Array[Dictionary]) -> void:
	var impact: float = landing_impact(_had_prev, _prev_on_floor, _prev_vel_y, o)
	if impact >= LAND_HARD_PX_S:
		var imp: float = clampf((impact - LAND_HARD_PX_S) / (float(Interface.Observation.MAX_FALL_PX_S) - LAND_HARD_PX_S), 0.0, 1.0)
		out.append(_cue(&"thump", feet_px(o), 0.6 + imp * 0.5, -5.0))
	var vx: float = absf(float(o.vel_x)) / float(Fx.SCALE)
	if o.on_floor and vx > STEP_MIN_SPEED:
		_step_dist += vx * delta
		if _step_dist >= STRIDE_PX:
			_step_dist = 0.0
			var ground: StringName = ground_under(o)
			out.append(_cue(Sfx.step_voice(ground), feet_px(o), scuff_pitch(ground), -19.0))
	else:
		_step_dist = 0.0


## A machine set down clunks, one picked up pops, and the FIRST machine ever to run ignites the line.
## The first observation primes the set, so a loaded base does not clunk twenty times.
func _machines(o: Interface.Observation, out: Array[Dictionary]) -> void:
	var now: Dictionary = {}
	var any_working: bool = false
	for rec: Dictionary in o.machines:
		now[rec["cell"]] = true
		if rec.get("status", &"") == &"working":
			any_working = true
			if _machines_primed and not _ever_worked:
				_ever_worked = true
				out.append(_cue(&"ignite", logic_centre(rec["cell"]), 1.0, -4.0))
				out.append(_cue(&"ignite", Vector2.ZERO, 1.0, 0.0, true))
	if _machines_primed:
		for cell: Vector2i in Ordering.cells(now):
			if not _seen_cells.has(cell):
				out.append(_cue(&"clunk", logic_centre(cell), 1.9, -10.0))
		for cell: Vector2i in Ordering.cells(_seen_cells):
			if not now.has(cell):
				out.append(_cue(&"pop", logic_centre(cell), 0.8))
	elif any_working:
		_ever_worked = true          # a loaded base already running has had its ignition
	_seen_cells = now
	_machines_primed = true


func _pack(o: Interface.Observation, out: Array[Dictionary]) -> void:
	var now: Dictionary = Payouts.pack_counts(o)
	if _pack_primed and not Payouts.gains_between(_prev_pack, now).is_empty():
		out.append(_cue(&"pop", px(o.hand), GAIN_PITCH))
	_prev_pack = now
	_pack_primed = true


## Past a cave level of 0.3 the dark starts dripping: a blip every 3 to 9 seconds, placed at random
## around the listener. Legacy's offsets were screen-ish px at its scale; halved with the world.
func _drip(o: Interface.Observation, delta: float, cave: float, out: Array[Dictionary]) -> void:
	_drip_in -= delta
	if _drip_in > 0.0:
		return
	_drip_in = lerpf(DRIP_GAP_MIN, DRIP_GAP_MAX, _rng.next_float())
	if cave > DRIP_MIN_CAVE:
		var off := Vector2(lerpf(-80.0, 80.0, _rng.next_float()), lerpf(-45.0, 45.0, _rng.next_float()))
		out.append(_cue(&"drip", body_px(o) + off, lerpf(0.85, 1.25, _rng.next_float()), -6.0))
