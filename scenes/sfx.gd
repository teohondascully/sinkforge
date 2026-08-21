class_name Sfx
extends Node

## Procedural audio. Every sound is synthesized at boot rather than loaded: short 16-bit mono WAVs built
## from noise and sine primitives, played through a small pool of positional players. Under them sits a
## stack of looping beds whose levels follow the world: factory hum, sky, cave air, water, rope.
## Representation only. MainView pokes `play()` and `ui()` from the same verb hooks that fire particles.
##
## Three properties a bank of one-shots would not have:
##
##   It knows what was hit.   A blow or a footstep is resolved against the sim where it lands
##                            (`_resolve`): soil, coal, ore, timber and the deep band each get a voice.
##   It knows where you are.  Every positional voice runs through one reverb sized off the rock around
##                            the listener (`_probe_space`).
##   It does not repeat.      Often-triggered sounds draw from a bank of separate renders, peak-matched
##                            so they vary in grain without bouncing in level.

const RATE: int = 22050
const POOL: int = 10
const CELL: int = 32                          # world px per cell: a sound can ask what it just hit

## The space bus. Every positional voice runs through its one reverb. UI dings and the beds stay dry on
## Master: the beds already are the room, and a reverbed interface sound reads as a bug.
const SPACE_BUS: StringName = &"Space"

## Terrain material -> the strike that material makes, so an hour of digging soil, coal, ore and the deep
## band is not one noise several hundred times over. An absent material falls back to the plain `crunch`,
## which is itself the stone voice: a dry fracture.
const STRIKE: Dictionary = {
	&"earth": &"hit_earth", &"gravel": &"hit_earth",
	&"coal": &"hit_coal",
	&"ore": &"hit_metal", &"iron": &"hit_metal", &"rich_ore": &"hit_metal",
	&"wood": &"hit_wood", &"leaves": &"hit_wood",
	&"deepslate": &"hit_slate", &"sealrock": &"hit_slate",
}

## What the boot is standing on. A footstep on dirt and one on rock are the same event over a different
## surface, so these are shades rather than named voices: nothing holds them as far apart as the strikes.
const GROUND: Dictionary = {
	&"wood": &"step_wood", &"leaves": &"step_wood",
	&"stone": &"step_rock", &"shale": &"step_rock", &"deepslate": &"step_rock",
	&"sealrock": &"step_rock", &"ore": &"step_rock", &"iron": &"step_rock",
	&"rich_ore": &"step_rock", &"coal": &"step_rock",
}

## Separate renders of each frequently triggered sound. Pitch jitter alone cannot hide repetition: the
## noise grain is identical every time and the ear locks onto the grain. Four streams, never twice running.
const GRAINS: int = 4

var _streams: Dictionary = {}                 # name -> AudioStreamWAV: the canonical voice of each event
var _bank: Dictionary = {}                    # name -> Array[AudioStreamWAV]: its GRAINS alternates
var _bank_last: Dictionary = {}               # name -> last grain index, so no draw repeats it
var _pool: Array[AudioStreamPlayer2D] = []
var _pool_idx: int = 0
var _ui_player: AudioStreamPlayer
var _hum_player: AudioStreamPlayer
var _hum_mid_player: AudioStreamPlayer        # factory bed: belts and gears, the middle of the machine
var _hum_top_player: AudioStreamPlayer        # factory bed: the distant clatter of moving parts
var _hum_level: float = 0.0                   # smoothed 0..1
var _winch_player: AudioStreamPlayer          # rope bed: the drum ratcheting line in
var _creak_player: AudioStreamPlayer          # rope bed: the line singing under load
var _winch_level: float = 0.0                 # smoothed 0..1
var _creak_level: float = 0.0
var _rush_player: AudioStreamPlayer           # speed bed: the air going past you
var _rush_level: float = 0.0                  # smoothed 0..1
var _wind_player: AudioStreamPlayer           # ambience bed: surface wind
var _cave_player: AudioStreamPlayer           # ambience bed: deep cave-air
var _wind_level: float = 0.0                  # smoothed 0..1
var _cave_level: float = 0.0
var _pour_player: AudioStreamPlayer           # ambience bed: nearby pouring water (docs/DECISIONS.md)
var _pump_player: AudioStreamPlayer           # ambience bed: a working pump's wet mechanical drain
var _pour_level: float = 0.0                  # smoothed 0..1: how much pouring water is near the listener
var _pump_level: float = 0.0                  # smoothed 0..1: how hard a nearby pump is draining
var _drip_in: float = 4.0                     # seconds until the next cave drip
## The room. Probed on a slow clock rather than per frame and smoothed hard. `_closed` below is how much
## solid rock surrounds the listener: 0 under open sky and 1 walled in. `_room` is how far off it is.
var _reverb: AudioEffectReverb
var _owns_bus: bool = false                   # this instance created SPACE_BUS and must remove it again
var _probe_dirs: PackedVector2Array = PackedVector2Array()
var _probe_in: float = 0.0                    # seconds until the next enclosure probe
var _closed: float = 0.0
var _room: float = 0.35
var _world: FactorySim = null                 # the sim, found lazily from the parent; see _sim()
## Under the headless Dummy driver the mixer never steps, so a started voice is never reaped and trips
## the ObjectDB leak warning at quit. Playback is a no-op there; synthesis still runs.
var _muted: bool = DisplayServer.get_name() == "headless"


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712                        # fixed: the same "recording" every boot
	_streams[&"crunch"] = _wav(_gen_crunch(rng))
	_streams[&"thump"] = _wav(_gen_thump(rng))
	_streams[&"clunk"] = _wav(_gen_clunk(rng))
	_streams[&"ding"] = _wav(_gen_ding())
	_streams[&"chime"] = _wav(_gen_chime())
	_streams[&"pop"] = _wav(_gen_pop())
	_streams[&"drip"] = _wav(_gen_drip())
	_streams[&"boom"] = _wav(_gen_boom(rng))
	_streams[&"step"] = _wav(_gen_step(rng))
	_streams[&"hollow"] = _wav(_gen_hollow(rng))
	_streams[&"breach"] = _wav(_gen_breach(rng))
	_streams[&"ignite"] = _wav(_gen_ignite(rng))
	_streams[&"vein"] = _wav(_gen_vein(rng))
	_streams[&"catch"] = _wav(_gen_catch(rng))
	_streams[&"skid"] = _wav(_gen_skid(rng))
	# The strike family: each voice is its own event, as far from the others as any two sounds here.
	_streams[&"hit_earth"] = _wav(_gen_hit_earth(rng))
	_streams[&"hit_coal"] = _wav(_gen_hit_coal(rng))
	_streams[&"hit_metal"] = _wav(_gen_hit_metal(rng))
	_streams[&"hit_wood"] = _wav(_gen_hit_wood(rng))
	_streams[&"hit_slate"] = _wav(_gen_hit_slate(rng))
	# Grain banks for the voices that fire often, so two blows in a row are never the same waveform.
	_grains(&"crunch", _gen_crunch, rng)
	_grains(&"hit_earth", _gen_hit_earth, rng)
	_grains(&"hit_coal", _gen_hit_coal, rng)
	_grains(&"hit_metal", _gen_hit_metal, rng)
	_grains(&"hit_wood", _gen_hit_wood, rng)
	_grains(&"hit_slate", _gen_hit_slate, rng)
	_grains(&"step", _gen_step, rng)
	_grains(&"step_rock", _gen_step_rock, rng)
	_grains(&"step_wood", _gen_step_wood, rng)
	_make_space_bus()
	for _i: int in POOL:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1500.0
		p.volume_db = -8.0
		if _reverb != null:
			p.bus = SPACE_BUS
		add_child(p)
		_pool.append(p)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.volume_db = -10.0
	add_child(_ui_player)
	var hum := AudioStreamWAV.new()
	var hum_samples: PackedFloat32Array = _gen_hum(rng)
	hum.format = AudioStreamWAV.FORMAT_16_BITS
	hum.mix_rate = RATE
	hum.data = _to_pcm(hum_samples)
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = hum_samples.size()
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = hum
	_hum_player.volume_db = -60.0
	add_child(_hum_player)
	# The factory bed is a stack of three rather than one drone on a knob: a sub you feel, a belt-and-gear
	# middle once a line is running, a distant clatter when a floor is busy. Thresholds are in `set_hum`.
	_hum_mid_player = _make_loop_player(_gen_hum_mid(rng))
	_hum_top_player = _make_loop_player(_gen_hum_top(rng))
	# Ambience beds: surface wind and deep cave-air, crossfaded by where the body is (`set_ambience`).
	_wind_player = _make_loop_player(_gen_wind(rng))
	_cave_player = _make_loop_player(_gen_cave(rng))
	# The rope's beds, the speed bed and the water beds. The winch is held down for seconds at a time, and
	# a continuous verb with no continuous sound reads as a thing that is not happening.
	_winch_player = _make_loop_player(_gen_winch(rng))
	_creak_player = _make_loop_player(_gen_creak(rng))
	_rush_player = _make_loop_player(_gen_rush(rng))
	_pour_player = _make_loop_player(_gen_pour(rng))
	_pump_player = _make_loop_player(_gen_pump(rng))
	# Twelve fixed directions for the enclosure probe, built once so the probe loop allocates nothing.
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		_probe_dirs.append(Vector2(cos(a), sin(a)))
	if not _muted:
		_hum_player.play()
		_hum_mid_player.play()
		_hum_top_player.play()
		_wind_player.play()
		_winch_player.play()
		_creak_player.play()
		_rush_player.play()
		_cave_player.play()
		_pour_player.play()
		_pump_player.play()


## Stop every voice on teardown: a stream still playing at quit leaves its playback object alive in the
## mixer and trips the ObjectDB leak warning. Dropping the stream reference matters too under headless.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_hum_player, _hum_mid_player, _hum_top_player, _wind_player,
			_cave_player, _rush_player, _pour_player, _pump_player, _winch_player, _creak_player,
			_ui_player]:
		bed.stop()
		bed.stream = null
	for p: AudioStreamPlayer2D in _pool:
		p.stop()
		p.stream = null
		p.bus = &"Master"                      # off the space bus before it is removed, never after
	_reverb = null
	if _owns_bus:
		_owns_bus = false
		var idx: int = AudioServer.get_bus_index(SPACE_BUS)
		if idx > 0:
			AudioServer.remove_bus(idx)


## One positional sound at a world position. `pitch` jitters a little on top so repeats do not machine-gun.
##
## Two things happen to `name` on the way in. `_resolve` turns it into the voice of whatever is actually
## there, so the caller says what happened and this layer knows what it sounded like. Then `_pick` draws
## a grain, one of several renders of that voice, so the four hundredth swing is not the first again.
func play(name: StringName, pos: Vector2, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if _muted:
		return
	var voice: StringName = _resolve(name, pos)
	var stream: AudioStreamWAV = _pick(voice)
	if stream == null:
		return
	var p: AudioStreamPlayer2D = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL
	p.stream = stream
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = -8.0 + vol_db + Settings.sound_db()
	p.play()


## The material voice, chosen from the world itself. The controller fires one verb hook, `crunch` at the
## struck cell or `step` at the boots, and this layer asks the sim what is under it: no call site has to
## know about materials. Empty air falls through to the canonical voice.
func _resolve(name: StringName, pos: Vector2) -> StringName:
	if name == &"crunch":
		return STRIKE.get(_material_at(pos), name)
	if name == &"step":
		# The boots are at the body's bottom edge, so the floor is the next cell down. Probe both: a body
		# standing exactly on a cell boundary reads its own empty cell first.
		var under: StringName = _material_at(pos + Vector2(0.0, 3.0))
		if under == &"":
			under = _material_at(pos + Vector2(0.0, float(CELL) * 0.6))
		return GROUND.get(under, name)
	return name


## Draw a grain of `voice`, never the same one twice running. Falls back to the canonical stream for
## every sound that does not fire often enough to need a bank.
func _pick(voice: StringName) -> AudioStreamWAV:
	var grains: Array = _bank.get(voice, [])
	if grains.is_empty():
		return _streams.get(voice, null)
	var last: int = int(_bank_last.get(voice, -1))
	var i: int = randi() % grains.size()
	if i == last:
		i = (i + 1) % grains.size()
	_bank_last[voice] = i
	return grains[i]


## The material at a world point. Terrain first, then the lode behind it: a swing can land on a vein in
## an already-carved cell. Empty when there is nothing there or nothing to ask.
func _material_at(pos: Vector2) -> StringName:
	var sim: FactorySim = _sim()
	if sim == null:
		return &""
	var cell := Vector2i(floori(pos.x / float(CELL)), floori(pos.y / float(CELL)))
	if not sim.in_bounds(cell):
		return &""
	var mat: StringName = sim.material_at(cell)
	return mat if mat != &"" else sim.lode_at(cell)


## The world. Found by asking the parent rather than being handed it, so nothing upstream has to wire it.
## Re-checked until it answers: it resolves on the first blow and never looks again.
func _sim() -> FactorySim:
	if _world != null:
		return _world
	var parent: Node = get_parent()
	if parent == null:
		return null
	_world = parent.get(&"sim") as FactorySim
	return _world


## A non-positional interface sound (craft ding, research chime).
func ui(name: StringName, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(name, null)
	if stream == null or _muted:
		return
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch
	_ui_player.volume_db = -10.0 + Settings.sound_db()
	_ui_player.play()


## The factory heartbeat. `level` is 0..1 by how much machinery is working nearby, smoothed so machines
## starting and stopping breathe rather than snap. Three layers ride that one smoothed `_hum_level`, each
## with its own threshold, so the bed gains colour as well as level: one machine is a sub you barely
## notice, three put belts and gears in the room, a full floor clatters with parts you cannot see.
func set_hum(level: float, delta: float) -> void:
	_hum_level = move_toward(_hum_level, clampf(level, 0.0, 1.0), delta * 0.8)
	var amb: float = Settings.ambience_db()
	_hum_player.volume_db = lerpf(-60.0, -22.0, _hum_level) + amb
	var mid: float = clampf((_hum_level - 0.22) / 0.48, 0.0, 1.0)
	_hum_mid_player.volume_db = lerpf(-60.0, -25.0, mid) + amb
	_hum_mid_player.pitch_scale = lerpf(0.97, 1.02, _hum_level)   # the line loads up as the floor fills
	var top: float = clampf((_hum_level - 0.56) / 0.44, 0.0, 1.0)
	_hum_top_player.volume_db = lerpf(-60.0, -32.0, top) + amb


## The rush: the air going past the body, `level` 0..1 by how fast it is moving. Every other bed here
## says where you are; this is the only one that says how fast. It rides pitch as well as level, because
## a bed that only gets louder reads as more wind, where one that also climbs reads as the body itself
## going faster.
func set_rush(level: float, delta: float) -> void:
	_rush_level = move_toward(_rush_level, clampf(level, 0.0, 1.0), delta * 3.2)
	_rush_player.volume_db = lerpf(-60.0, -19.0, _rush_level) + Settings.ambience_db()
	_rush_player.pitch_scale = lerpf(0.78, 1.34, _rush_level)


## The ambience crossfade. `surface` 0..1 drives the wind bed and `cave` 0..1 the cave-air bed, both
## derived upstream from how deep the body sits below its column's surface. Past a cave level of 0.3
## the dark starts dripping too: a blip every 3 to 9 seconds, placed at random around the listener.
func set_ambience(surface: float, cave: float, listener: Vector2, delta: float) -> void:
	_wind_level = move_toward(_wind_level, clampf(surface, 0.0, 1.0), delta * 0.6)
	_cave_level = move_toward(_cave_level, clampf(cave, 0.0, 1.0), delta * 0.6)
	_wind_player.volume_db = lerpf(-60.0, -26.0, _wind_level) + Settings.ambience_db()
	_cave_player.volume_db = lerpf(-60.0, -21.0, _cave_level) + Settings.ambience_db()
	_drip_in -= delta
	if _drip_in <= 0.0:
		_drip_in = randf_range(3.0, 9.0)
		if _cave_level > 0.3:
			play(&"drip", listener + Vector2(randf_range(-160.0, 160.0), randf_range(-90.0, 90.0)),
				randf_range(0.85, 1.25), -6.0)
	_update_space(listener, delta)


const PROBE_REACH: int = 16                   ## cells a ray searches before calling it open
const PROBE_PERIOD: float = 0.16              ## seconds between probes
## `_update_space` measures the world rather than picking a preset: twelve rays out from the body, how
## many hit rock and how far off it was.
##
##   nothing hits          -> open sky, dry, only the sound itself
##   everything hits close -> a crawl: a short damped slap right behind the blow
##   everything hits far   -> a cavern: a long tail with the walls audibly out there
##
## Six probes a second, 192 dictionary lookups at worst and no allocation. Smoothed hard, so walking out
## of a tunnel into a chamber opens rather than switches.
func _update_space(listener: Vector2, delta: float) -> void:
	if _reverb == null:
		return
	_probe_in -= delta
	if _probe_in <= 0.0:
		_probe_in = PROBE_PERIOD
		_probe_space(listener)
	_reverb.wet = _closed * 0.40
	_reverb.room_size = lerpf(0.24, 0.88, _room)
	# Damping is what makes a tight earthen hole and a big stone chamber read as different places rather
	# than as the same place at two tail lengths.
	_reverb.damping = lerpf(0.82, 0.30, _room)
	_reverb.predelay_msec = lerpf(4.0, 30.0, _room)


func _probe_space(listener: Vector2) -> void:
	var sim: FactorySim = _sim()
	if sim == null:
		return
	var origin := Vector2i(floori(listener.x / float(CELL)), floori(listener.y / float(CELL)))
	var hits: int = 0
	var reach: float = 0.0
	for d: Vector2 in _probe_dirs:
		var dist: int = PROBE_REACH
		for s: int in range(1, PROBE_REACH + 1):
			var c := origin + Vector2i(roundi(d.x * float(s)), roundi(d.y * float(s)))
			if not sim.in_bounds(c):
				break                          # off the world edge reads as open, not as a wall
			if sim.is_solid(c):
				dist = s
				hits += 1
				break
		reach += float(dist)
	var closed: float = float(hits) / float(_probe_dirs.size())
	# Mean free path. 2 cells is a crawlway and 12 or more is a hall, weighted by how closed the space is
	# so that a surface stroll where every ray runs to its limit cannot read as a cavern.
	var room: float = clampf((reach / float(_probe_dirs.size()) - 2.0) / 10.0, 0.0, 1.0) * closed
	_closed = lerpf(_closed, closed, 0.18)
	_room = lerpf(_room, room, 0.12)


## Build the reverb bus once and only once: several Sfx instances can exist in one process.
func _make_space_bus() -> void:
	var idx: int = AudioServer.get_bus_index(SPACE_BUS)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SPACE_BUS)
		AudioServer.set_bus_send(idx, &"Master")
		var fx := AudioEffectReverb.new()
		fx.dry = 1.0                           # send-style mix: the blow itself never loses its edge
		fx.wet = 0.0
		fx.spread = 0.85
		fx.hipass = 0.18                       # keep the tail off the sub, so weight stays in the hit
		AudioServer.add_bus_effect(idx, fx)
		_owns_bus = true
	if AudioServer.get_bus_effect_count(idx) > 0:
		_reverb = AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb


## The water beds. `pour` 0..1 is how much pouring water is near the listener, `pump` 0..1 how hard a
## nearby pump is draining, both smoothed so approaching water, or a pump spinning up, breathes rather
## than snaps. They top out under the cave bed, and the pour rides pitch as it swells, so a bigger fall
## reads brighter as well as louder.
func set_water(pour: float, pump: float, delta: float) -> void:
	_pour_level = move_toward(_pour_level, clampf(pour, 0.0, 1.0), delta * 0.9)
	_pump_level = move_toward(_pump_level, clampf(pump, 0.0, 1.0), delta * 0.9)
	_pour_player.volume_db = lerpf(-60.0, -24.0, _pour_level) + Settings.ambience_db()
	_pour_player.pitch_scale = lerpf(0.92, 1.06, _pour_level)
	_pump_player.volume_db = lerpf(-60.0, -23.0, _pump_level) + Settings.ambience_db()


## The winch and the line, driven together because they are two halves of one instrument. `haul` is how
## hard the drum is pulling, 0 at rest to 1 at full `Grapple.REEL_SPEED`; `load` is how hard the rope
## itself is working, which is speed on a taut line. They rise and fall on different clocks: a winch
## starts and stops with the key, so it snaps, and a rope under load sings up and dies away, so it drags.
func set_line(haul: float, load: float, delta: float) -> void:
	_winch_level = move_toward(_winch_level, clampf(haul, 0.0, 1.0), delta * 7.0)
	_creak_level = move_toward(_creak_level, clampf(load, 0.0, 1.0), delta * 2.4)
	_winch_player.volume_db = lerpf(-60.0, -17.0, _winch_level) + Settings.ambience_db()
	_winch_player.pitch_scale = lerpf(0.82, 1.22, _winch_level)
	_creak_player.volume_db = lerpf(-60.0, -22.0, _creak_level) + Settings.ambience_db()
	_creak_player.pitch_scale = lerpf(0.88, 1.30, _creak_level)


## The winch drum: a geared motor under a pawl clicking over ratchet teeth. The clicks are what make it
## read as a winch rather than as a machine; a smooth motor tone alone sounds like the factory hum.
func _gen_winch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var motor: float = sin(TAU * 88.0 * t) * 0.30 + sin(TAU * 132.0 * t) * 0.14
		var tooth: float = fmod(t * 19.0, 1.0)                # nineteen pawl clicks a second
		lp += 0.55 * (rng.randf_range(-1.0, 1.0) - lp)        # bright metallic edge on each click
		var click: float = lp * pow(maxf(0.0, 1.0 - tooth * 9.0), 2.2) * 0.85
		out[i] = (motor + click) * 1.15
	return _loopify(out)


## The line under load: two fibre tones at 143 and 219 Hz on a slow wow over a heavily filtered rustle.
## `set_line` rides its level and pitch, so the rope sings up as it takes the weight of a body.
func _gen_creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var wow: float = 1.0 + 0.06 * sin(TAU * 0.37 * t) + 0.03 * sin(TAU * 1.13 * t)
		var fibre: float = sin(TAU * 143.0 * wow * t) * 0.26 + sin(TAU * 219.0 * wow * t) * 0.11
		lp += 0.06 * (rng.randf_range(-1.0, 1.0) - lp)        # heavily filtered rustle: hemp, not metal
		out[i] = (fibre + lp * 2.4) * 1.1
	return _loopify(out)


## The catch: rope coming down onto a rock edge and biting there. It must not resemble the crunch, which
## is a bright short burst of stone breaking. This is soft against hard: a dull woody knock with a fibre
## rasp over it, low-passed far harder and running 200ms against the crunch's 110. The rasp swells before
## it decays, the way a line does as it slides onto a corner, so the two differ in attack as well as in
## colour.
func _gen_catch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.20)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		lp += 0.055 * (rng.randf_range(-1.0, 1.0) - lp)      # heavy roll-off: hemp on stone
		var swell: float = pow(sin(PI * clampf(u * 1.35, 0.0, 1.0)), 1.4)
		var knock: float = (sin(TAU * 165.0 * t) + sin(TAU * 244.0 * t) * 0.45) * exp(-t * 21.0) * 0.42
		out[i] = (lp * 5.5 * swell + knock) * 1.1
	return out


## A silent looping non-positional bed from a sample buffer. All the beds share this shape.
func _make_loop_player(samples: PackedFloat32Array) -> AudioStreamPlayer:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = _to_pcm(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = samples.size()
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.volume_db = -60.0
	add_child(p)
	return p


## Crossfade a buffer's tail into its head over about 90ms so a noise-based loop closes without a click.
## Pure sines loop on exact cycles. Filtered noise never lands back where it started.
func _loopify(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade: int = mini(int(RATE * 0.09), samples.size() / 4)
	var n: int = samples.size() - fade
	for i: int in fade:
		var t: float = float(i) / float(fade)
		samples[i] = lerpf(samples[n + i], samples[i], t)
	samples.resize(n)
	return samples


# --- synthesis, all of it at boot: nothing here is loaded from disk ----------------------------

## Footstep: a soft scuff. A very short noise burst low-passed hard, over a small body thud. Kept quiet
## and dull because it fires several times a second and anything bright becomes a machine gun.
func _gen_step(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.055)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		# The grit arrives with an edge and dulls as the boot settles, a contour rather than a lucky draw.
		lp += lerpf(0.30, 0.06, pow(t, 0.55)) * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(150.0, 78.0, t) / float(RATE)  # the weight of a boot landing
		out[i] = (lp * 1.7 + sin(phase) * 0.5) * pow(1.0 - t, 2.8)
	return _norm(out, 0.88)


## Mining crunch: stone, and the head of the strike family. A decaying noise burst through a one-pole
## lowpass gives the dry fracture. Under it a short low body keeps the strike from reading as a click;
## it is gone in 25ms of a 110ms sound, so the fracture still arrives first and stays the loudest part.
func _gen_crunch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.11)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		var env: float = pow(1.0 - t, 2.2)
		lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * env * 1.5 + sin(TAU * 74.0 * s) * exp(-s * 66.0) * 0.52
	return _norm(out, 0.92)


# --- the strike family: one blow, five substances -----------------------------------------------
# The same question as the crunch, asked of materials that do not fracture like stone. Same event, same
# 0.1 to 0.2s window; what differs is the physics and the rung on the loudness ladder.

## Loose ground (earth and gravel). The pick sinks rather than fracturing: a crumble with no crack in
## it at all, over a soft low pack as the face gives way. The dullest thing in the library on purpose.
func _gen_hit_earth(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.10)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.16 * (rng.randf_range(-1.0, 1.0) - lp)     # grit rather than fracture: nothing above the mids
		out[i] = lp * 2.4 * pow(1.0 - t, 1.4) + sin(TAU * 66.0 * s) * exp(-s * 27.0) * 0.66
	# The bottom of the family's loudness ladder: soil gives way where slate has to be beaten out.
	return _norm(out, 0.58)


## Coal: brittle. It does not break once but shatters, four grains letting go over 54ms and each drier
## and brighter than rock. Band-passed so there is no rumble in it.
func _gen_hit_coal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	const SHARDS: Array[float] = [0.0, 0.011, 0.029, 0.054]
	var n: int = int(RATE * 0.13)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in n:
		var s: float = float(i) / float(RATE)
		lp += 0.36 * (rng.randf_range(-1.0, 1.0) - lp)   # kept down out of the fizz: a seam worked for
		slow += 0.05 * (lp - slow)                       # minutes cannot be the shrillest thing here
		var band: float = lp - slow                        # the dry crackle band, rumble removed
		var env: float = 0.0
		for k: int in SHARDS.size():
			var d: float = s - SHARDS[k]
			if d >= 0.0:
				env += exp(-d * (120.0 + float(k) * 45.0)) * (1.0 - float(k) * 0.19)
		out[i] = band * env * 1.6 + sin(TAU * 92.0 * s) * exp(-s * 60.0) * 0.20
	return _norm(out, 0.84)


## Ore-bearing rock (ore, iron, rich ore): stone with something in it that does not want to break. The
## same dry fracture on the front, and a short damped metal tick off the back. The tick stays dull and
## quiet because the `vein` bell is the sound that means a find, and a per-blow ring loud enough to
## compete would spend that moment hundreds of times before it arrived.
func _gen_hit_metal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.34 * (rng.randf_range(-1.0, 1.0) - lp)
		var tick: float = sin(TAU * 436.0 * s) * exp(-s * 23.0) * 0.30 \
			+ sin(TAU * 655.0 * s) * exp(-s * 32.0) * 0.15 \
			+ sin(TAU * 1310.0 * s) * exp(-s * 62.0) * 0.07
		out[i] = lp * pow(1.0 - t, 4.0) * 1.5 + tick \
			+ sin(TAU * 74.0 * s) * exp(-s * 30.0) * 0.40
	return _norm(out, 0.90)


## Wood (trunks and leaves). A chop rather than a crack: a hollow knock on a stretched, unmusical set of
## partials at 186, 287 and 438 Hz, a splintery rasp on the front, and no sub at all, because wood is the
## one thing down here with no weight to it.
func _gen_hit_wood(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.24 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * pow(1.0 - t, 1.1) * 1.05 \
			+ sin(TAU * 186.0 * s) * exp(-s * 30.0) * 0.62 \
			+ sin(TAU * 287.0 * s) * exp(-s * 40.0) * 0.28 \
			+ sin(TAU * 438.0 * s) * exp(-s * 62.0) * 0.10
	return _norm(out, 0.82)


## Deepslate and the seal: the dense band the game asks you to work at. A hard tight transient with
## almost no spray off it, then a long low ring as the mass takes the blow. At 220ms, the longest strike
## in the family.
func _gen_hit_slate(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.26 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * pow(1.0 - t, 6.0) * 1.7 \
			+ sin(TAU * 52.0 * s) * exp(-s * 10.0) * 0.52 \
			+ sin(TAU * 79.0 * s) * exp(-s * 16.0) * 0.25 \
			+ sin(TAU * 127.0 * s) * exp(-s * 25.0) * 0.10
	return _norm(out, 0.98)


## The boot on rock: shorter and drier than the soft-ground scuff, a heel click where the thud went.
func _gen_step_rock(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.042)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		lp += 0.34 * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(255.0, 150.0, t) / float(RATE)
		out[i] = (lp * 1.25 + sin(phase) * 0.26) * pow(1.0 - t, 3.4)
	return _norm(out, 0.80)


## The boot on wood: a hollow board answering underfoot, the only footstep with a note in it.
func _gen_step_wood(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.060)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.22 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * 0.9 * pow(1.0 - t, 3.0) \
			+ sin(TAU * 172.0 * s) * exp(-s * 42.0) * 0.44 \
			+ sin(TAU * 258.0 * s) * exp(-s * 58.0) * 0.18
	return _norm(out, 0.84)

## The skid (docs/BITS.md): steel glancing off rock it cannot bite. It must not resemble the crunch,
## which is a 110ms fracture meaning a bite was taken, so it takes the opposite shape: almost no impact
## transient, a bright band-passed scrape sliding down in pitch as the edge runs off the face, and a
## thin metallic ring hanging after it. At 300ms it is far too long to read as a slow first blow.
func _gen_skid(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.30)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp: float = 0.0
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		# A band that starts bright and slides down: the edge running along the face and losing it.
		var k: float = lerpf(0.72, 0.20, pow(t, 0.7))
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += k * (noise - lp)
		hp = lp - (lp * 0.42)
		var env: float = minf(1.0, t * 6.0) * pow(1.0 - t, 1.4)
		# The tool rings thinly on top at 1240 down to 880 Hz, well clear of the hollow ring's 96.
		phase += TAU * lerpf(1240.0, 880.0, t) / float(RATE)
		out[i] = hp * env * 1.5 + sin(phase) * pow(1.0 - t, 3.0) * 0.20
	return out


## The hollow ring: the pick striking rock with a void behind it. Struck over solid ground the blow is a
## dead thud; struck over a cavity it rings, because the void is a resonator and the face is a drum skin.
##
## The crunch's noise burst gated into a short decaying tone: a low fundamental with two partials, long
## enough to read as a ring at 260ms against the crunch's 110, and quiet enough that hearing it is
## something you do on purpose.
func _gen_hollow(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.26)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var strike: float = pow(maxf(0.0, 1.0 - t * 7.0), 2.0)     # the impact itself, over in a moment
		lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
		# 96, 154 and 233 Hz sit on a stretched series, so this reads as an empty space and not as a note.
		var s: float = float(i) / float(RATE)
		var ring: float = sin(TAU * 96.0 * s) * 0.6 \
			+ sin(TAU * 154.0 * s) * 0.28 \
			+ sin(TAU * 233.0 * s) * 0.12
		out[i] = lp * strike * 1.5 + ring * pow(1.0 - t, 2.6) * 0.42
	return out


## The breach: the face gives way and the void behind it opens. Air moving rather than rock, a burst of
## noise swept bright to dark by a closing filter under a low swell. The answer to the hollow ring above.
func _gen_breach(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.55)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var k: float = lerpf(0.42, 0.03, pow(t, 0.55))            # the filter closing is the air settling
		lp += k * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(74.0, 38.0, t) / float(RATE)
		out[i] = lp * pow(1.0 - t, 1.5) * 1.5 + sin(phase) * pow(1.0 - t, 2.4) * 0.30
	return out


## The line runs: the factory has started working without you, so it must not be mistakable for anything
## else. Three motions in one: a low spin-up sweeping 52 to 124 Hz that fades in rather than starting, a
## metallic knock of engagement, and a major triad locking in note by note under a long tail. Kept large
## and warm, where the research chime is small and bright.
func _gen_ignite(rng: RandomNumberGenerator) -> PackedFloat32Array:
	const LOCK: float = 0.34                                       # fraction of the sound where the triad takes over
	var n: int = int(RATE * 0.95)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	var notes: Array = [131.0, 262.0, 330.0, 392.0, 523.0]         # C3, a C-major triad, and its octave
	for i: int in n:
		var t: float = float(i) / float(n)
		# 1. the spin-up: rising, fading in over its first fifth and gone by three quarters through
		phase += TAU * lerpf(52.0, 124.0, minf(t / 0.55, 1.0)) / float(RATE)
		var spin: float = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.30, 0.75, t))
		out[i] = (sin(phase) + sin(phase * 2.0) * 0.28) * spin * 0.34
		# 2. the knock of engagement: one short filtered noise hit right at the lock
		var k: float = (t - LOCK) * 26.0
		if k >= 0.0 and k < 1.0:
			lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
			out[i] += lp * pow(1.0 - k, 2.0) * 0.55
		# 3. the chord, arriving note by note and holding
		if t > LOCK:
			var u: float = (t - LOCK) / (1.0 - LOCK)
			for j: int in notes.size():
				var onset: float = float(j) * 0.055
				if u <= onset:
					continue
				var v: float = (u - onset) / maxf(1.0 - onset, 0.001)
				out[i] += sin(TAU * float(notes[j]) * float(i - int(float(n) * LOCK)) / float(RATE)) \
					* smoothstep(0.0, 0.10, v) * pow(1.0 - v, 1.6) * (0.24 - float(j) * 0.028)
	return out


## The vein: the pick finding metal in the dark. Struck bronze rather than a chime: 587 against 593 Hz
## beat six times a second the way struck metal does. Bright on purpose, because a find is good news.
func _gen_vein(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.38)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		var strike: float = rng.randf_range(-1.0, 1.0) * pow(maxf(0.0, 1.0 - u * 22.0), 2.0) * 0.30
		var body: float = (sin(TAU * 587.0 * t) + sin(TAU * 593.0 * t) * 0.85) * exp(-t * 9.0) * 0.26
		var shimmer: float = sin(TAU * 1760.0 * t) * exp(-t * 15.0) * 0.10
		out[i] = strike + body + shimmer
	return out


## Break thump: a sine gliding 120 to 55 Hz with a click of noise on the front, the block giving way.
func _gen_thump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(120.0, 55.0, t)
		phase += TAU * f / float(RATE)
		var s: float = sin(phase) * pow(1.0 - t, 1.4) * 0.9
		if i < RATE / 200:
			s += rng.randf_range(-0.5, 0.5)
		out[i] = s
	return out

## Machine clunk: a dull metallic knock, a low tone plus an odd harmonic plus a breath of noise.
func _gen_clunk(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.12)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / float(n)
		var w: float = TAU * float(i) / float(RATE)
		var env: float = pow(1.0 - t, 1.8)
		out[i] = (sin(w * 96.0) * 0.6 + sin(w * 288.0) * 0.25 + rng.randf_range(-0.08, 0.08)) * env
	return out

## Craft ding: two bright partials ringing down, the anvil note.
func _gen_ding() -> PackedFloat32Array:
	var n: int = int(RATE * 0.32)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / float(RATE)
		out[i] = (sin(TAU * 1244.0 * t) * exp(-t * 13.0) + sin(TAU * 1866.0 * t) * exp(-t * 9.0)) * 0.5
	return out

## Research chime: a rising three-note arpeggio with soft tails.
func _gen_chime() -> PackedFloat32Array:
	var n: int = int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes: Array = [660.0, 880.0, 1320.0]
	for k: int in notes.size():
		var start: int = int(float(k) * RATE * 0.11)
		for i: int in range(start, n):
			var t: float = float(i - start) / float(RATE)
			out[i] += sin(TAU * float(notes[k]) * t) * exp(-t * 7.0) * 0.30
	return out

## Collect pop: a quick upward sine sweep.
func _gen_pop() -> PackedFloat32Array:
	var n: int = int(RATE * 0.07)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(350.0, 950.0, t) / float(RATE)
		out[i] = sin(phase) * (1.0 - t) * 0.55
	return out

## Surface wind: gusting noise. Two chained one-pole lowpasses roll it down to the breathy low-mids,
## under a slow two-sine gust LFO. Loop-closed.
func _gen_wind(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp1 += 0.12 * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += 0.20 * (lp1 - lp2)
		var gust: float = 0.6 + 0.25 * sin(TAU * 0.13 * t) + 0.15 * sin(TAU * 0.071 * t + 1.7)
		out[i] = lp2 * gust * 2.6
	return _loopify(out)


## The rush bed: brighter and thinner than the surface wind, so the two never read as one sound.
func _gen_rush(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 2
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var hp: float = 0.0
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var white: float = rng.randf_range(-1.0, 1.0)
		lp += 0.42 * (white - lp)                      # gentler low-pass than the wind: keeps the hiss
		hp = 0.86 * (hp + lp - prev)                   # and a high-pass to cut the rumble entirely
		prev = lp
		var whistle: float = 0.14 * sin(TAU * 1180.0 * t) * (0.5 + 0.5 * sin(TAU * 0.9 * t))
		out[i] = (hp * 1.9 + whistle) * (0.85 + 0.15 * sin(TAU * 0.31 * t))
	return _loopify(out)


## Deep cave-air: a sub drone at 38 Hz with its fifth at 57, over a whisper of brownish noise under a
## very slow swell so the dark seems to breathe. Loop-closed.
func _gen_cave(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp += 0.03 * (rng.randf_range(-1.0, 1.0) - lp)
		var swell: float = 0.75 + 0.25 * sin(TAU * 0.09 * t)
		out[i] = (sin(TAU * 38.0 * t) * 0.30 + sin(TAU * 57.0 * t) * 0.16 + lp * 0.5) * swell
	return _loopify(out)


## Water pour: a soft continuous trickle. One one-pole lowpass minus a slower one keeps the airy
## mid-highs and drops the rumble; a 3 and 7 Hz flutter over it shimmers the sheet instead of hissing.
func _gen_pour(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp_fast: float = 0.0
	var lp_slow: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var white: float = rng.randf_range(-1.0, 1.0)
		lp_fast += 0.55 * (white - lp_fast)          # keeps up to the airy mids
		lp_slow += 0.06 * (lp_fast - lp_slow)        # rolls off the low rumble
		var band: float = lp_fast - lp_slow          # the breathy trickle band
		var flutter: float = 0.72 + 0.20 * sin(TAU * 3.1 * t) + 0.08 * sin(TAU * 7.3 * t + 0.9)
		out[i] = band * flutter * 1.9
	return _loopify(out)


## Pump drain: a wet mechanical gurgle. A sub at 62 Hz with its fifth at 93, pulsing on a 1.7 Hz drain
## rhythm with a bubbly noise burst at the head of each pulse as water sucks through the tube.
func _gen_pump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var pulse: float = fmod(t * 1.7, 1.0)                 # 0..1 within each drain cycle
		var chug: float = pow(maxf(0.0, 1.0 - pulse * 1.6), 1.8)   # a firm gulp on the downstroke
		var sub: float = sin(TAU * 62.0 * t) * 0.30 + sin(TAU * 93.0 * t) * 0.16
		lp += 0.22 * (rng.randf_range(-1.0, 1.0) - lp)         # wet noise bubbling through the tube
		var burst: float = lp * pow(maxf(0.0, 1.0 - pulse * 3.0), 2.0) * 0.9
		out[i] = (sub * (0.35 + 0.65 * chug) + burst) * 1.4
	return _loopify(out)


## A cave drip: a fast pitch-falling blip and its fainter echo, water finding the floor in the dark.
func _gen_drip() -> PackedFloat32Array:
	var n: int = int(RATE * 0.34)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(1500.0, 620.0, clampf(t / 0.05, 0.0, 1.0)) / float(RATE)
		var s: float = sin(phase) * exp(-t * 26.0) * 0.7
		if t > 0.14:                                    # the echo: the same blip, further away
			var te: float = t - 0.14
			s += sin(TAU * 900.0 * te) * exp(-te * 30.0) * 0.22
		out[i] = s
	return out


## The breach stinger: a sub-bass glide from 85 down to 26 Hz under a rock-burst of noise on the front.
## Big on purpose, because it marks a once-per-world event.
func _gen_boom(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 1.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var tt: float = float(i) / float(RATE)
		phase += TAU * lerpf(85.0, 26.0, sqrt(t)) / float(RATE)
		var s: float = sin(phase) * pow(1.0 - t, 1.2)
		lp += 0.35 * (rng.randf_range(-1.0, 1.0) - lp)
		s += lp * exp(-tt * 9.0) * 0.9                  # the shattering front, gone in about a third of a second
		out[i] = s                                      # _to_pcm's soft knee catches the overshoot
	return out


## The factory's middle: belts and gearing, the layer that says a line is running rather than a box
## being powered. A 110.5 Hz shaft note sits half a hertz off the sub layer's 110, so the pair throbs
## once every two seconds. Over it sit 165.5 and 221 Hz, a belt slapping at 2.5 Hz, and a gear train
## ticking twelve teeth a second. The noise is loop-closed before the tones go on top, so every partial
## closes on a whole number of cycles across exactly two seconds. 165.5 is a flat fifth for that reason:
## the true 165.75 would not close, and crossfading a strong sine smears the seam into an audible beat.
func _gen_hum_mid(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RATE * 2 + int(RATE * 0.09))
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in out.size():
		lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
		slow += 0.05 * (lp - slow)
		out[i] = (lp - slow) * 0.14                        # a dry mechanical rustle, no rumble in it
	out = _loopify(out)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var shaft: float = sin(TAU * 110.5 * t) * 0.26 + sin(TAU * 165.5 * t) * 0.13 \
			+ sin(TAU * 221.0 * t) * 0.07
		var belt: float = 0.82 + 0.18 * sin(TAU * 2.5 * t)
		# Phase-offset so no tooth lands on the loop point: a tick at the seam is what no crossfade hides.
		var tooth: float = fmod(t * 12.0 + 0.37, 1.0)
		out[i] = shaft * belt + out[i] * (0.6 + 3.4 * pow(maxf(0.0, 1.0 - tooth * 6.0), 3.0))
	return out


## The factory's top: the clatter from across a busy floor, parts moving rather than tones. Band-passed
## noise gated by three tick rates that share no beat inside the loop (5, 7 and 11 a second), so it reads
## as several machines rather than one metronome. At -32 dB it is the quietest bed, heard when it stops.
func _gen_hum_top(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RATE * 2 + int(RATE * 0.09))
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		lp += 0.58 * (rng.randf_range(-1.0, 1.0) - lp)
		slow += 0.14 * (lp - slow)
		# Phase-offset so they never strike together: simultaneous ticks read as one hammer, not a floor.
		var gate: float = 0.0
		for spec: Vector2 in [Vector2(5.0, 0.13), Vector2(7.0, 0.46), Vector2(11.0, 0.79)]:
			gate += pow(maxf(0.0, 1.0 - fmod(t * spec.x + spec.y, 1.0) * 8.0), 2.6) \
				* (11.0 / spec.x) * 0.30
		out[i] = (lp - slow) * (0.10 + gate) * 1.5
	return _loopify(out)


## The factory's sub: one second of low drone at 55 and 110 Hz over a whisper of noise floor.
##
## The tones close on exact cycles across a second. Noise does not: it ends wherever it ends and jumps
## the seam by several times its own sample step, a soft tick once a second under a bed that never
## stops. So the noise is loop-closed first and the tones go on after, where the arithmetic still holds.
func _gen_hum(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RATE + int(RATE * 0.09))            # the crossfade eats the surplus; RATE samples survive
	var lp: float = 0.0
	for i: int in out.size():
		lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * 0.20
	out = _loopify(out)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		out[i] += sin(TAU * 55.0 * t) * 0.30 + sin(TAU * 110.0 * t) * 0.15
	return out


const KNEE: float = 0.72
const CEIL: float = 0.985                     ## the asymptote: nothing ever reaches full scale
## `_to_pcm` takes float samples to 16-bit through a soft limiter rather than a hard clamp. Several
## generators run their peaks past full scale, and a hard clamp flat-tops them: a burst of odd harmonics
## on the biggest sounds in the game. Below `KNEE` nothing is touched; above it the curve bends to `CEIL`.
func _to_pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i: int in samples.size():
		var v: float = samples[i]
		var over: float = absf(v) - KNEE
		if over > 0.0:
			v = signf(v) * (KNEE + (CEIL - KNEE) * tanh(over / (1.0 - KNEE)))
		pcm.encode_s16(i * 2, int(v * 32767.0))
	return pcm


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = _to_pcm(samples)
	return w


## Scale a buffer so its loudest sample lands exactly on `peak`. Two reasons. Grain alternates have to
## match: four takes of one voice off four stretches of noise land up to 4 dB apart, and a footstep that
## bounces in level every stride reads as a bug. And a short burst's identity is otherwise hostage to the
## stretch it draws, the same recipe peaking 0.94 one build and 0.74 the next, which is enough to move
## one sound onto another. Fixing the peak makes a sound's place in the mix a decision.
func _norm(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var most: float = 0.0
	for v: float in samples:
		most = maxf(most, absf(v))
	if most <= 1e-6:
		return samples
	var gain: float = peak / most
	for i: int in samples.size():
		samples[i] *= gain
	return samples


## Fill `name`'s grain bank: `GRAINS` takes of one recipe, each off a fresh stretch of the noise stream.
## The canonical take from `_streams` goes in first wherever there is one, so the render measured offline
## is also one a player actually hears.
func _grains(name: StringName, gen: Callable, rng: RandomNumberGenerator) -> void:
	var takes: Array[AudioStreamWAV] = []
	var canonical: AudioStreamWAV = _streams.get(name, null)
	if canonical != null:
		takes.append(canonical)
	while takes.size() < GRAINS:
		takes.append(_wav(gen.call(rng)))
	_bank[name] = takes
