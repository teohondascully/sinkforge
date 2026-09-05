class_name Beds
extends Node

## THE BED DRIVER (A' step 6f, D0366): ten looping players under the game whose levels follow the
## world. Legacy `scenes/sfx.gd`'s `set_hum`, `set_rush`, `set_ambience`, `set_water` and `set_line`,
## with their arithmetic split out as STATIC maps that return numbers -- an `AudioStreamPlayer` cannot
## be read back, so a test against the setters could assert only that they did not crash, which is
## exactly what a bed stuck at -60 dB does. `hum_mix` and its siblings are the assertable half.
##
## Every level arrives 0..1 already derived (`BedLevels` does that from the observation) and is
## smoothed here on its own clock: the winch snaps with the key, the rope sings up and dies away, the
## factory breathes. Legacy read its ambience slider off a `Settings` global; that belongs in `shell/`,
## so the level is INJECTED as `ambience_db`, the same one-line diff `Score` carries.
##
## Headless-safe on `Score`'s terms: synthesis runs so the code path stays warm, nothing plays, because
## the Dummy driver never reaps a started voice and trips the leak warning at quit.

const SILENT_DB: float = -60.0

## The factory heartbeat: three layers ride ONE smoothed level, each with its own threshold, so the bed
## gains colour as well as level -- one machine is a sub you barely notice, three put belts and gears
## in the room, a full floor clatters with parts you cannot see.
const HUM_RATE: float = 0.8
const HUM_SUB_DB: float = -22.0
const HUM_MID_FROM: float = 0.22
const HUM_MID_SPAN: float = 0.48
const HUM_MID_DB: float = -25.0
const HUM_TOP_FROM: float = 0.56
const HUM_TOP_SPAN: float = 0.44
const HUM_TOP_DB: float = -32.0
## The rush rides pitch as well as level: a bed that only gets louder reads as more wind, one that also
## climbs reads as the body itself going faster.
const RUSH_RATE: float = 3.2
const RUSH_DB: float = -19.0
const RUSH_PITCH_LO: float = 0.78
const RUSH_PITCH_HI: float = 1.34
const AMBIENCE_RATE: float = 0.6
const WIND_DB: float = -26.0
const CAVE_DB: float = -21.0
const WATER_RATE: float = 0.9
const POUR_DB: float = -24.0
const POUR_PITCH_LO: float = 0.92
const POUR_PITCH_HI: float = 1.06
const PUMP_DB: float = -23.0
## The winch and the line rise and fall on different clocks: a winch starts and stops with the key, so
## it snaps; a rope under load sings up and dies away, so it drags.
const WINCH_RATE: float = 7.0
const CREAK_RATE: float = 2.4
const WINCH_DB: float = -17.0
const WINCH_PITCH_LO: float = 0.82
const WINCH_PITCH_HI: float = 1.22
const CREAK_DB: float = -22.0
const CREAK_PITCH_LO: float = 0.88
const CREAK_PITCH_HI: float = 1.30

var ambience_db: float = 0.0          ## the shell's ambience slider, injected
var _players: Dictionary = {}         ## bed name -> AudioStreamPlayer
var _level: Dictionary = {}           ## bed name -> smoothed 0..1
var _muted: bool = DisplayServer.get_name() == "headless"


## The sub/mid/top decibels and the mid pitch for one smoothed hum level.
static func hum_mix(level: float) -> Dictionary:
	var mid: float = clampf((level - HUM_MID_FROM) / HUM_MID_SPAN, 0.0, 1.0)
	var top: float = clampf((level - HUM_TOP_FROM) / HUM_TOP_SPAN, 0.0, 1.0)
	return {"sub_db": lerpf(SILENT_DB, HUM_SUB_DB, level), "mid_db": lerpf(SILENT_DB, HUM_MID_DB, mid),
		"mid_pitch": lerpf(0.97, 1.02, level), "top_db": lerpf(SILENT_DB, HUM_TOP_DB, top)}


static func rush_mix(level: float) -> Dictionary:
	return {"db": lerpf(SILENT_DB, RUSH_DB, level), "pitch": lerpf(RUSH_PITCH_LO, RUSH_PITCH_HI, level)}


static func ambience_mix(surface: float, cave: float) -> Dictionary:
	return {"wind_db": lerpf(SILENT_DB, WIND_DB, surface), "cave_db": lerpf(SILENT_DB, CAVE_DB, cave)}


static func water_mix(pour: float, pump: float) -> Dictionary:
	return {"pour_db": lerpf(SILENT_DB, POUR_DB, pour), "pour_pitch": lerpf(POUR_PITCH_LO, POUR_PITCH_HI, pour),
		"pump_db": lerpf(SILENT_DB, PUMP_DB, pump)}


static func line_mix(haul: float, load: float) -> Dictionary:
	return {"winch_db": lerpf(SILENT_DB, WINCH_DB, haul), "winch_pitch": lerpf(WINCH_PITCH_LO, WINCH_PITCH_HI, haul),
		"creak_db": lerpf(SILENT_DB, CREAK_DB, load), "creak_pitch": lerpf(CREAK_PITCH_LO, CREAK_PITCH_HI, load)}


## Build every bed from the bank, silent, and start the loops. The seed is explicit so two boots agree.
func setup(seed_value: int = 20260901) -> void:
	attach(synthesize(seed_value))


## Every bed from the seed, {name: AudioStreamWAV}; static and node-free so the seat may run it on a
## worker thread (D0397). Each bed splits its own stream off the root, so the order here moves nothing.
static func synthesize(seed_value: int) -> Dictionary:
	var rng: SplitRng = SplitRng.new(seed_value).split("beds")
	var out: Dictionary = {}
	for name: StringName in Ordering.ids(BedBank.SECONDS.keys()):
		out[name] = BedBank.to_loop_stream(BedBank.generate(name, rng.split(String(name))))
	return out


## Build a silent player per bed and start the loops; `drive` on a bed with no player yet is a no-op.
func attach(streams: Dictionary) -> void:
	for name: StringName in Ordering.ids(streams.keys()):
		var p := AudioStreamPlayer.new()
		p.stream = streams[name]
		p.volume_db = SILENT_DB
		add_child(p)
		_players[name] = p
		_level[name] = 0.0
		if not _muted:
			p.play()


func ready() -> bool:
	return not _players.is_empty()


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players.values():
		p.stop()
		p.stream = null


func level(name: StringName) -> float:
	return float(_level.get(name, 0.0))


func _toward(name: StringName, target: float, rate: float, delta: float) -> float:
	var v: float = move_toward(level(name), clampf(target, 0.0, 1.0), delta * rate)
	_level[name] = v
	return v


func _apply(name: StringName, db: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _players.get(name, null)
	if p == null:
		return
	p.volume_db = db + ambience_db
	p.pitch_scale = pitch


func set_hum(target: float, delta: float) -> void:
	var m: Dictionary = hum_mix(_toward(&"hum", target, HUM_RATE, delta))
	_level[&"hum_mid"] = level(&"hum")
	_level[&"hum_top"] = level(&"hum")
	_apply(&"hum", m["sub_db"])
	_apply(&"hum_mid", m["mid_db"], m["mid_pitch"])
	_apply(&"hum_top", m["top_db"])


func set_rush(target: float, delta: float) -> void:
	var m: Dictionary = rush_mix(_toward(&"rush", target, RUSH_RATE, delta))
	_apply(&"rush", m["db"], m["pitch"])


func set_ambience(surface: float, cave: float, delta: float) -> void:
	var m: Dictionary = ambience_mix(_toward(&"wind", surface, AMBIENCE_RATE, delta),
		_toward(&"cave", cave, AMBIENCE_RATE, delta))
	_apply(&"wind", m["wind_db"])
	_apply(&"cave", m["cave_db"])


func set_water(pour: float, pump: float, delta: float) -> void:
	var m: Dictionary = water_mix(_toward(&"pour", pour, WATER_RATE, delta), _toward(&"pump", pump, WATER_RATE, delta))
	_apply(&"pour", m["pour_db"], m["pour_pitch"])
	_apply(&"pump", m["pump_db"])


func set_line(haul: float, load: float, delta: float) -> void:
	var m: Dictionary = line_mix(_toward(&"winch", haul, WINCH_RATE, delta), _toward(&"creak", load, CREAK_RATE, delta))
	_apply(&"winch", m["winch_db"], m["winch_pitch"])
	_apply(&"creak", m["creak_db"], m["creak_pitch"])


## One frame: every bed pushed from one derived level set, including the frames where a level is zero,
## which is what lets a bed go quiet instead of hanging on.
func drive(levels: Dictionary, delta: float) -> void:
	set_hum(float(levels.get("hum", 0.0)), delta)
	set_rush(float(levels.get("rush", 0.0)), delta)
	set_ambience(float(levels.get("surface", 0.0)), float(levels.get("cave", 0.0)), delta)
	set_water(float(levels.get("pour", 0.0)), float(levels.get("pump", 0.0)), delta)
	set_line(float(levels.get("haul", 0.0)), float(levels.get("load", 0.0)), delta)
