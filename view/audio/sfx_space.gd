class_name SfxSpace
extends RefCounted

## THE ROOM (A' step 6f (ii), D0367): one reverb bus every positional voice runs through, sized off the
## rock around the listener. Legacy `scenes/sfx.gd`'s `_probe_space`, `_update_space`, `_occlusion` and
## `_make_space_bus`, measuring the OBSERVATION's terrain window rather than the sim. Legacy's reasons
## stand verbatim: "`_update_space` measures the world rather than picking a preset: twelve rays out
## from the body, how many hit rock and how far off it was. Nothing hits: open sky, dry. Everything hits
## close: a crawl, a short damped slap right behind the blow. Everything hits far: a cavern, a long tail
## with the walls audibly out there." UI sounds and the beds stay dry on Master: the beds already ARE
## the room, and a reverbed interface sound reads as a bug.
##
## The measurement half (`probe`, `occlusion`, `reverb_for`) is static and returns numbers; only
## `ensure_bus`/`apply`/`release` touch the audio server, and they are no-ops without a device.
##
## Reach is in LOGIC cells: legacy's 16 × 32 px is 16 of our 16 px cells, sampled one terrain cell at
## the centre of each step.

const BUS: StringName = &"Space"
const RAYS: int = 12
const PROBE_REACH: int = 16            ## logic cells a ray searches before calling it open
const PROBE_PERIOD: float = 0.16       ## seconds between probes: six a second, no allocation
const OCCLUSION_REACH: int = 24        ## logic cells walked at most between a source and the listener
## A placeholder, not a tuned value: how many dB a fully-occluded source loses on top of distance
## falloff. Conservative on purpose; the curve is a listening call and stays open for a tuning pass.
const OCCLUSION_DB_MAX: float = 10.0
const LOGIC_PX: float = float(Interface.Observation.LOGIC_PX)
const CELL_PX: float = float(Interface.Observation.CELL_PX)
## Mean free path: 2 cells is a crawlway and 12 or more a hall.
const ROOM_NEAR: float = 2.0
const ROOM_FAR_SPAN: float = 10.0

var closed: float = 0.0     ## how much solid rock surrounds the listener: 0 open sky, 1 walled in
var room: float = 0.35      ## how far off that rock is
var _probe_in: float = 0.0
var _reverb: AudioEffectReverb = null
var _owns_bus: bool = false


## The twelve fixed directions, built once.
static func directions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in RAYS:
		var a: float = TAU * float(i) / float(RAYS)
		out.append(Vector2(cos(a), sin(a)))
	return out


static func _terrain_cell(px: Vector2) -> Vector2i:
	return Vector2i(floori(px.x / CELL_PX), floori(px.y / CELL_PX))


## Twelve rays from the listener (world px): {closed, room} for this instant, unsmoothed. Off the
## window's edge reads as open, not as a wall.
static func probe(o: Interface.Observation, listener_px: Vector2) -> Dictionary:
	var hits: int = 0
	var reach: float = 0.0
	for d: Vector2 in directions():
		var dist: int = PROBE_REACH
		for s: int in range(1, PROBE_REACH + 1):
			var c: Vector2i = _terrain_cell(listener_px + d * float(s) * LOGIC_PX)
			if not o.in_window(c):
				break
			if o.solid_at(c):
				dist = s
				hits += 1
				break
		reach += float(dist)
	var closed_now: float = float(hits) / float(RAYS)
	# Weighted by how closed the space is, so a surface stroll where every ray runs to its limit cannot
	# read as a cavern.
	var room_now: float = clampf((reach / float(RAYS) - ROOM_NEAR) / ROOM_FAR_SPAN, 0.0, 1.0) * closed_now
	return {"closed": closed_now, "room": room_now}


## Fraction of solid cells on the straight line from the listener to a source, 0..1, in logic steps.
static func occlusion(o: Interface.Observation, source_px: Vector2, listener_px: Vector2) -> float:
	var from: Vector2 = listener_px / LOGIC_PX
	var to: Vector2 = source_px / LOGIC_PX
	var cells: int = mini(maxi(absi(int(floor(to.x)) - int(floor(from.x))), absi(int(floor(to.y)) - int(floor(from.y)))), OCCLUSION_REACH)
	if cells <= 0:
		return 0.0
	var hits: int = 0
	for s: int in range(1, cells + 1):
		var t: float = float(s) / float(cells)
		var p: Vector2 = from.lerp(to, t) * LOGIC_PX
		var c: Vector2i = _terrain_cell(p)
		if o.in_window(c) and o.solid_at(c):
			hits += 1
	return float(hits) / float(cells)


## The reverb settings for a smoothed {closed, room}. Damping is what makes a tight earthen hole and a
## big stone chamber read as different places rather than as the same place at two tail lengths.
static func reverb_for(closed_v: float, room_v: float) -> Dictionary:
	return {"wet": closed_v * 0.40, "room_size": lerpf(0.24, 0.88, room_v),
		"damping": lerpf(0.82, 0.30, room_v), "predelay_msec": lerpf(4.0, 30.0, room_v)}


## Probe on the slow clock and smooth hard, so walking out of a tunnel into a chamber opens rather
## than switches. Returns whether a probe ran this call.
func update(o: Interface.Observation, listener_px: Vector2, delta: float) -> bool:
	_probe_in -= delta
	var probed: bool = false
	if _probe_in <= 0.0:
		_probe_in = PROBE_PERIOD
		var p: Dictionary = probe(o, listener_px)
		closed = lerpf(closed, float(p["closed"]), 0.18)
		room = lerpf(room, float(p["room"]), 0.12)
		probed = true
	apply()
	return probed


## Build the reverb bus once and only once: several instances can exist in one process.
func ensure_bus() -> void:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, &"Master")
		var fx := AudioEffectReverb.new()
		fx.dry = 1.0                    # send-style mix: the blow itself never loses its edge
		fx.wet = 0.0
		fx.spread = 0.85
		fx.hipass = 0.18                # keep the tail off the sub, so weight stays in the hit
		AudioServer.add_bus_effect(idx, fx)
		_owns_bus = true
	if AudioServer.get_bus_effect_count(idx) > 0:
		_reverb = AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb


func has_bus() -> bool:
	return _reverb != null


func apply() -> void:
	if _reverb == null:
		return
	var r: Dictionary = reverb_for(closed, room)
	_reverb.wet = r["wet"]
	_reverb.room_size = r["room_size"]
	_reverb.damping = r["damping"]
	_reverb.predelay_msec = r["predelay_msec"]


## Drop the bus this instance made. Players must already be off it: never remove a bus under a voice.
func release() -> void:
	_reverb = null
	if _owns_bus:
		_owns_bus = false
		var idx: int = AudioServer.get_bus_index(BUS)
		if idx > 0:
			AudioServer.remove_bus(idx)
