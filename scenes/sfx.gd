class_name Sfx
extends Node

## Procedural AUDIO — audio-lite (the missing sense). Every sound is SYNTHESIZED at boot
## (no assets): short 16-bit mono WAVs built from noise/sine primitives, played through a small pool of
## positional players, plus a stack of looping BEDS whose levels follow the world — the factory hum, the
## sky, the cave air, the water, the rope. Pure representation: MainView pokes play()/ui() from the same
## verb hooks that already fire particles, and the set_*() drivers each frame. Headless-safe (the Dummy
## audio driver swallows playback silently, so the harness runs unchanged).
##
## Three things this layer does that a bank of one-shots cannot:
##
##   IT KNOWS WHAT YOU HIT.  A dig blow and a footstep are RESOLVED against the sim at the point they
##                           happen (see _resolve), so soil, coal, ore, timber and the deep band each
##                           have their own voice instead of one crunch with the pitch nudged.
##   IT KNOWS WHERE YOU ARE. Every positional voice runs through one reverb whose size and wetness are
##                           measured off the rock around the listener (see _update_space) — open sky
##                           is dry, a crawlway slaps, a chamber rings.
##   IT DOES NOT REPEAT.     The sounds you trigger by the hundred are drawn from a bank of separate
##                           renders, peak-matched so they vary in grain without bouncing in level.

const RATE: int = 22050
const POOL: int = 10
const CELL: int = 32                          # world cells — so a sound can ask what it just hit

## THE SPACE BUS. Every positional voice runs through one reverb whose size and wetness follow how
## ENCLOSED the listener actually is (see _probe_space). UI dings and the beds stay dry on Master:
## the beds already ARE the room, and a reverbed interface sound reads as a bug.
const SPACE_BUS: StringName = &"Space"

## WHAT THE PICK IS BITING. Terrain material -> the strike that material makes. This is the single
## biggest thing the mixer was missing: one crunch with a pitch wobble on it meant a session of hitting
## soil, coal, ore and the deep band produced one noise, several hundred times, and the ear stopped
## reporting any of it. Rock is not one substance and a pick does not lie about which one it found.
##
## Absent = the plain `crunch`, which IS the stone voice (dry fracture) — the family grew around it
## rather than replacing it, so every existing call site keeps working and stone still sounds like stone.
const STRIKE: Dictionary = {
	&"earth": &"hit_earth", &"gravel": &"hit_earth",
	&"coal": &"hit_coal",
	&"ore": &"hit_metal", &"iron": &"hit_metal", &"rich_ore": &"hit_metal",
	&"wood": &"hit_wood", &"leaves": &"hit_wood",
	&"deepslate": &"hit_slate", &"sealrock": &"hit_slate",
}

## ...and what the boot is standing ON. Unlike the strike, a footstep on dirt and a footstep on rock are
## the SAME event with a different surface under it, so these are shades rather than named voices: they
## live only in the grain bank and are deliberately NOT asserted as distinct sounds (check_voice judges
## events, and claiming two footsteps must be 0.16 apart would be a lie about what a footstep is).
const GROUND: Dictionary = {
	&"wood": &"step_wood", &"leaves": &"step_wood",
	&"stone": &"step_rock", &"shale": &"step_rock", &"deepslate": &"step_rock",
	&"sealrock": &"step_rock", &"ore": &"step_rock", &"iron": &"step_rock",
	&"rich_ore": &"step_rock", &"coal": &"step_rock",
}

## Separate RENDERS of each sound you trigger hundreds of times a session. Pitch jitter alone cannot hide
## repetition — the grain of the noise is identical every time, and the ear locks onto the grain, not the
## pitch. Four renders from four noise streams, picked without immediate repeats, is the cheap fix.
const GRAINS: int = 4

var _streams: Dictionary = {}                 # name -> AudioStreamWAV (the canonical voice of each event)
var _bank: Dictionary = {}                    # name -> Array[AudioStreamWAV] (its GRAINS alternates)
var _bank_last: Dictionary = {}               # name -> last grain index played, so a repeat never repeats
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
var _pour_player: AudioStreamPlayer           # ambience bed: nearby pouring/falling WATER (L3, docs/DECISIONS)
var _pump_player: AudioStreamPlayer           # ambience bed: a working PUMP's wet mechanical drain (L3)
var _pour_level: float = 0.0                  # smoothed 0..1 — how much pouring water is near the listener
var _pump_level: float = 0.0                  # smoothed 0..1 — how hard a nearby pump is draining
var _drip_in: float = 4.0                     # seconds until the next cave drip
## THE ROOM. `_closed` = how much solid rock surrounds the listener (0 under open sky, 1 walled in),
## `_room` = how far away that rock is (0 in a one-cell crawl, 1 in a cavern). Both are smoothed, both
## are re-probed on a slow clock rather than per frame, and together they set the reverb.
var _reverb: AudioEffectReverb
var _owns_bus: bool = false                   # this instance created SPACE_BUS and must take it away again
var _probe_dirs: PackedVector2Array = PackedVector2Array()
var _probe_in: float = 0.0                    # seconds until the next enclosure probe
var _closed: float = 0.0
var _room: float = 0.35
var _world: FactorySim = null                 # the sim, found lazily from the parent — see _sim()
## Headless (the harness): the Dummy audio driver never steps its mixer, so a started voice is never
## reaped and trips the ObjectDB leak warning at quit. Playback is a NO-OP there — synthesis still
## runs (keeps the code path warm), nothing ever plays. Real runs are untouched.
var _muted: bool = DisplayServer.get_name() == "headless"


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712                        # fixed seed — the same "recording" every boot
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
	# THE STRIKE FAMILY (material voice). Each is a named event in its own right — check_voice holds them
	# 0.16 apart in feature space exactly like every other sound, which is the honest test of the claim
	# that a player can hear WHAT they are digging.
	_streams[&"hit_earth"] = _wav(_gen_hit_earth(rng))
	_streams[&"hit_coal"] = _wav(_gen_hit_coal(rng))
	_streams[&"hit_metal"] = _wav(_gen_hit_metal(rng))
	_streams[&"hit_wood"] = _wav(_gen_hit_wood(rng))
	_streams[&"hit_slate"] = _wav(_gen_hit_slate(rng))
	# ...and the grain banks for everything you trigger by the hundred. The canonical render above stays
	# in _streams (it is what the harness judges and what plays with no world to ask); these are its
	# siblings from other noise, so two blows in a row are never the same waveform twice.
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
	# THE FACTORY, IN THREE LAYERS (the Factorio feeling). One drone that only gets LOUDER is a volume
	# knob, not a factory: two machines and twenty machines sounded identical in colour, so the bed said
	# nothing about the thing the whole game is about building. It is now a STACK — a sub drone you feel,
	# a belt-and-gear middle that arrives once there is a line running, and a distant clatter of moving
	# parts that only shows up when the floor is genuinely busy. Each layer has its own threshold on the
	# same 0..1, so the bed THICKENS as the factory grows instead of just rising.
	#
	# The middle carries 110.5 Hz against the sub's 110 Hz: a half-hertz beat, so stacking the layers
	# produces a slow throb that neither layer has alone. That is what "more machines" sounds like.
	_hum_mid_player = _make_loop_player(_gen_hum_mid(rng))
	_hum_top_player = _make_loop_player(_gen_hum_top(rng))
	# AMBIENCE BEDS (audio slice 2): two more loops — surface WIND and deep CAVE-AIR — crossfaded by
	# where the body is (set_ambience). Underground you hear the earth, on top you hear the sky.
	_wind_player = _make_loop_player(_gen_wind(rng))
	_cave_player = _make_loop_player(_gen_cave(rng))
	# WATER BEDS (L3 audio): two more silent-until-driven loops — a soft WATER-POUR/trickle you hear as
	# you near falling water (a small waterfall in the dark), and a working PUMP's wet mechanical drain.
	# Both level-driven from the controller (set_water) exactly like the factory hum, so they swell with
	# nearby activity and fade to silence when nothing's pouring/pumping — they blend under wind/cave/drips.
	# THE ROPE'S OWN VOICE. The line became the movement system across strikes 20-22 and it was very nearly
	# silent: a borrowed clunk on the throw, a borrowed crunch on the bite, a borrowed pop on the release,
	# and NOTHING for the winch — the one rope action you hold down for seconds at a time, hauling thirteen
	# cells a second. A continuous verb with no continuous sound reads as a thing that is not happening.
	_winch_player = _make_loop_player(_gen_winch(rng))
	_creak_player = _make_loop_player(_gen_creak(rng))
	_rush_player = _make_loop_player(_gen_rush(rng))
	_pour_player = _make_loop_player(_gen_pour(rng))
	_pump_player = _make_loop_player(_gen_pump(rng))
	# Twelve fixed directions for the enclosure probe, built once so the per-probe loop allocates nothing.
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


## Stop every voice on teardown — a stream still playing at quit leaves its playback object alive in
## the mixer and trips the ObjectDB leak warning on exit (harness noise we refuse to normalize).
## Dropping the stream refs too matters under the headless Dummy driver, whose mixer never steps and
## so never reaps a stopped voice on its own.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_hum_player, _hum_mid_player, _hum_top_player, _wind_player,
			_cave_player, _rush_player, _pour_player, _pump_player, _winch_player, _creak_player,
			_ui_player]:
		bed.stop()
		bed.stream = null
	for p: AudioStreamPlayer2D in _pool:
		p.stop()
		p.stream = null
		p.bus = &"Master"                      # off the space bus BEFORE it goes away, never after
	_reverb = null
	if _owns_bus:
		_owns_bus = false
		var idx: int = AudioServer.get_bus_index(SPACE_BUS)
		if idx > 0:
			AudioServer.remove_bus(idx)


## One positional sound at a world position. `pitch` jitters a hair on top so repeats don't machine-gun.
##
## Two things happen to `name` on the way in. First it is RESOLVED against the world: a dig blow becomes
## that material's own strike and a footstep becomes that ground's own scuff, because the caller says
## what happened and this layer is the one that knows what it sounded like. Then a GRAIN is drawn — one
## of several renders of that voice from different noise — so the fourth hundredth swing of a session is
## not, sample for sample, the first one again.
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


## The material voice, chosen from the world itself. The controller fires the same verb hook it always
## did (`crunch` at the struck cell, `step` at the boots) — asking the sim what is THERE keeps every call
## site untouched and puts the knowledge in the layer that needs it. No sim (a bare Sfx in a fixture, a
## sound played over empty air) simply falls through to the canonical voice.
func _resolve(name: StringName, pos: Vector2) -> StringName:
	if name == &"crunch":
		return STRIKE.get(_material_at(pos), name)
	if name == &"step":
		# The boots are AT the body's bottom edge, so the floor is the next cell down — probe both, since
		# a body standing exactly on a cell boundary reads its own empty cell first.
		var under: StringName = _material_at(pos + Vector2(0.0, 3.0))
		if under == &"":
			under = _material_at(pos + Vector2(0.0, float(CELL) * 0.6))
		return GROUND.get(under, name)
	return name


## Draw a grain of `voice`: a different render each time, never the same one twice running. Falls back to
## the canonical stream for every sound that does not fire often enough to need a bank.
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


## What material sits at a world point (terrain first, then the LODE behind it — you can be swinging at a
## vein in an already-carved cell). Empty when there is nothing there, or nothing to ask.
func _material_at(pos: Vector2) -> StringName:
	var sim: FactorySim = _sim()
	if sim == null:
		return &""
	var cell := Vector2i(floori(pos.x / float(CELL)), floori(pos.y / float(CELL)))
	if not sim.in_bounds(cell):
		return &""
	var mat: StringName = sim.material_at(cell)
	return mat if mat != &"" else sim.lode_at(cell)


## The world, found by asking the parent for it rather than being handed it — nothing upstream has to know
## the mixer got curious. Re-checked until it answers (the sim exists long before the first sound, so this
## resolves on the first blow and never runs again), and null-safe forever if there is no world at all.
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


## The factory heartbeat: 0..1 how much machinery works near the player; the hum fades between
## near-silence and a felt presence, smoothed so machines starting/stopping breathe rather than snap.
##
## Three layers on one number, each with its own threshold, so the bed gains COLOUR as it gains level.
## A single working machine is a sub you barely notice; three put belts and gears in the room; a full
## floor adds the clatter of parts you cannot see. A drone that only got LOUDER was a volume knob, not
## a factory — two machines and twenty sounded identical, which is the one thing this game's bed must
## never do. All three ride the already-smoothed `_hum_level`, so the factory grows INTO audibility.
func set_hum(level: float, delta: float) -> void:
	_hum_level = move_toward(_hum_level, clampf(level, 0.0, 1.0), delta * 0.8)
	var amb: float = Settings.ambience_db()
	_hum_player.volume_db = lerpf(-60.0, -22.0, _hum_level) + amb
	var mid: float = clampf((_hum_level - 0.22) / 0.48, 0.0, 1.0)
	_hum_mid_player.volume_db = lerpf(-60.0, -25.0, mid) + amb
	_hum_mid_player.pitch_scale = lerpf(0.97, 1.02, _hum_level)   # the line loads up as the floor fills
	var top: float = clampf((_hum_level - 0.56) / 0.44, 0.0, 1.0)
	_hum_top_player.volume_db = lerpf(-60.0, -32.0, top) + amb


## THE RUSH — the air going past you, 0..1 by how fast you are actually moving.
##
## Everything else in this mixer is a bed you stand IN: the factory hum, the surface wind, the cave air.
## They tell you where you are. None of them tell you how fast you are, and after the winch got geared up
## and the sinkholes opened, going fast became the point — a forty-row drop and a standing start sounded
## exactly alike, which is the surest way to make speed feel like nothing.
##
## Rides pitch as well as level, because that is what actually sells velocity: a bed that only gets LOUDER
## reads as "more wind", while one that also climbs reads as "you, going faster". Ceiling deliberately sits
## under the ambience beds — it should be the thing you notice stop when you land, not a howl.
func set_rush(level: float, delta: float) -> void:
	_rush_level = move_toward(_rush_level, clampf(level, 0.0, 1.0), delta * 3.2)
	_rush_player.volume_db = lerpf(-60.0, -19.0, _rush_level) + Settings.ambience_db()
	_rush_player.pitch_scale = lerpf(0.78, 1.34, _rush_level)


## The AMBIENCE crossfade (audio slice 2): `surface` 0..1 drives the wind bed, `cave` 0..1 the
## cave-air bed — the controller derives both from how deep the body sits below its column's surface,
## so descending trades sky for earth across a few rows. Deep enough, the dark starts DRIPPING:
## intermittent water blips placed randomly around the listener, more frequent the deeper you are.
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


## THE ROOM YOU ARE IN, HEARD (audio slice: space).
##
## Everything this mixer made was DRY. A pick swung in open air on the surface and the same pick swung at
## the bottom of a forty-row shaft produced the same nine hundredths of a second of noise, which is the
## surest way to make a game about being underground feel like a game about being on a flat picture. The
## world already knows the answer — it is solid rock with holes in it — so the reverb is not a preset, it
## is a MEASUREMENT: twelve rays out from the body, how many hit rock and how far away it was.
##
##   nothing hits          -> open sky, dry, you hear only the sound itself
##   everything hits close -> a crawl: a short, damped slap right behind the blow
##   everything hits far   -> a cavern: a long tail with the walls audibly out there
##
## Re-probed six times a second (192 dictionary lookups, no allocation) and smoothed hard, so walking out
## of a tunnel into a chamber OPENS rather than switches. Representation only — no sim state is touched.
const PROBE_REACH: int = 16                   ## cells a ray searches before calling it open
const PROBE_PERIOD: float = 0.16              ## seconds between probes
func _update_space(listener: Vector2, delta: float) -> void:
	if _reverb == null:
		return
	_probe_in -= delta
	if _probe_in <= 0.0:
		_probe_in = PROBE_PERIOD
		_probe_space(listener)
	_reverb.wet = _closed * 0.40
	_reverb.room_size = lerpf(0.24, 0.88, _room)
	# A tight earthen hole eats the tail; a big stone chamber gives it back. Damping does the work that
	# makes "small" and "large" read as different PLACES rather than as the same place at two lengths.
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
	# Mean free path, normalised: 2 cells is a crawlway, 12+ is a hall. Weighted by how CLOSED the space
	# is so a surface stroll (where every ray runs to its limit) cannot read as the biggest cavern alive.
	var room: float = clampf((reach / float(_probe_dirs.size()) - 2.0) / 10.0, 0.0, 1.0) * closed
	_closed = lerpf(_closed, closed, 0.18)
	_room = lerpf(_room, room, 0.12)


## Build the reverb bus once, and only once — several fixtures construct an Sfx inside the same process.
func _make_space_bus() -> void:
	var idx: int = AudioServer.get_bus_index(SPACE_BUS)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SPACE_BUS)
		AudioServer.set_bus_send(idx, &"Master")
		var fx := AudioEffectReverb.new()
		fx.dry = 1.0                           # a send-style mix: the blow itself never loses its edge
		fx.wet = 0.0
		fx.spread = 0.85
		fx.hipass = 0.18                       # keep the tail off the sub, so weight stays in the hit
		AudioServer.add_bus_effect(idx, fx)
		_owns_bus = true
	if AudioServer.get_bus_effect_count(idx) > 0:
		_reverb = AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb


## The WATER beds (L3): `pour` 0..1 = how much pouring/falling water is near the listener (like the hum's
## working-machine count — a lone trickle whispers, a wide sheet is felt), `pump` 0..1 = how hard a nearby
## pump is draining. Both smoothed so approaching water / a pump spinning up breathes rather than snaps, and
## kept SUBTLE (their ceilings sit under wind/cave) so they layer INTO the ambience, never over it. The
## pour bed rides a hair higher in pitch as it swells so a bigger fall reads a touch louder AND brighter.
func set_water(pour: float, pump: float, delta: float) -> void:
	_pour_level = move_toward(_pour_level, clampf(pour, 0.0, 1.0), delta * 0.9)
	_pump_level = move_toward(_pump_level, clampf(pump, 0.0, 1.0), delta * 0.9)
	_pour_player.volume_db = lerpf(-60.0, -24.0, _pour_level) + Settings.ambience_db()
	_pour_player.pitch_scale = lerpf(0.92, 1.06, _pour_level)
	_pump_player.volume_db = lerpf(-60.0, -23.0, _pump_level) + Settings.ambience_db()


## THE WINCH and THE LINE, driven together because they are two halves of one instrument.
##
## `haul` is how hard the drum is pulling (0 at rest, 1 at full REEL_SPEED) and `load` is how hard the rope
## itself is working — speed on a taut line. They rise and fall on different clocks on purpose: a winch
## starts and stops with the key, so it snaps; a rope under load sings up and dies away, so it drags.
func set_line(haul: float, load: float, delta: float) -> void:
	_winch_level = move_toward(_winch_level, clampf(haul, 0.0, 1.0), delta * 7.0)
	_creak_level = move_toward(_creak_level, clampf(load, 0.0, 1.0), delta * 2.4)
	_winch_player.volume_db = lerpf(-60.0, -17.0, _winch_level) + Settings.ambience_db()
	_winch_player.pitch_scale = lerpf(0.82, 1.22, _winch_level)
	_creak_player.volume_db = lerpf(-60.0, -22.0, _creak_level) + Settings.ambience_db()
	_creak_player.pitch_scale = lerpf(0.88, 1.30, _creak_level)


## THE WINCH DRUM: a geared motor under a pawl clicking over the ratchet teeth. The clicks are what make it
## read as a WINCH rather than as a machine — a smooth motor tone alone sounds like the factory hum, and the
## rope already has a factory to not be confused with.
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


## THE LINE UNDER LOAD: a low fibre creak with a slow wow, and a thin harmonic that only shows up when the
## rope is really working. This is the sound that tells you the swing is carrying weight.
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


## THE CATCH: rope coming down onto a rock edge and biting there.
##
## Deliberately the OPPOSITE of the hook's own bite, which is a bright short burst of stone breaking. This
## is soft against hard: a dull woody knock with a fibre rasp over it, low-passed far harder and running
## longer. The first version was a noise slap with a little body under it and tools/check_voice put it
## 0.125 from `crunch` in feature space — near enough that a player would learn one sound for two events,
## which for the game's newest mechanic is the same as having no sound at all.
##
## The rasp also SWELLS before it decays, because that is what a line does: it slides onto the corner and
## then loads. That gives the two sounds different attack shapes as well as different colours, so they stay
## apart on more than one axis.
func _gen_catch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.20)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		lp += 0.055 * (rng.randf_range(-1.0, 1.0) - lp)      # heavy roll-off: hemp on stone, not stone on stone
		var swell: float = pow(sin(PI * clampf(u * 1.35, 0.0, 1.0)), 1.4)
		var knock: float = (sin(TAU * 165.0 * t) + sin(TAU * 244.0 * t) * 0.45) * exp(-t * 21.0) * 0.42
		out[i] = (lp * 5.5 * swell + knock) * 1.1
	return out


## A silent looping non-positional bed from a sample buffer (the ambience beds + the hum share this shape).
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


## Crossfade a buffer's tail into its head (~90ms) so a noise-based loop closes without a click —
## pure sines loop on exact cycles, but filtered noise never lands back where it started.
func _loopify(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade: int = mini(int(RATE * 0.09), samples.size() / 4)
	var n: int = samples.size() - fade
	for i: int in fade:
		var t: float = float(i) / float(fade)
		samples[i] = lerpf(samples[n + i], samples[i], t)
	samples.resize(n)
	return samples


# --- synthesis (all at boot; ~1s of audio total) -----------------------------------------------

## FOOTSTEP: a soft scuff — a very short noise burst, low-passed hard, with a tiny body thud under it.
## Walking is the single most frequent thing a player does and it was silent, which is most of why the
## body read as a sprite sliding over a picture rather than a person standing on ground. Deliberately
## quiet and deliberately DULL: it is played several times a second, so anything bright becomes a
## machine gun. The material underfoot varies the pitch at the call site, not here — one sample, many
## surfaces, exactly like the crunch.
func _gen_step(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.055)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		# The grit arrives with an edge on it and DULLS as the boot settles — a contour that is decided
		# here rather than by whichever stretch of noise the draw happened to land on.
		lp += lerpf(0.30, 0.06, pow(t, 0.55)) * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(150.0, 78.0, t) / float(RATE)  # the weight of a boot landing
		out[i] = (lp * 1.7 + sin(phase) * 0.5) * pow(1.0 - t, 2.8)
	return _norm(out, 0.88)


## Mining crunch — STONE, and the head of the strike family. A decaying noise burst through a one-pole
## lowpass (dry rock fracture) over a short low BODY.
##
## The body is the change. Measured, the old crunch put 7.9% of its energy under 160 Hz and centred at
## 1873 Hz: the single most-triggered sound in the game was a mid-range hiss with no bottom in it, which
## is why a pick strike read as a click rather than as a tool hitting a planet. The thud is short enough
## (gone in ~25ms of a 110ms sound) that the fracture still arrives first and stays the loudest thing.
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


# --- THE STRIKE FAMILY: one blow, five other substances -----------------------------------------
#
# Everything below answers the same question the crunch answers — what did the pick just do? — for a
# material that does not fracture like stone. They are the same length, the same loudness and the same
# shape of event; what differs is the physics, which is the only thing that should differ.

## LOOSE GROUND (earth, gravel). The pick does not fracture it, it SINKS: a crumble with no crack in it
## at all, over a soft low pack as the face gives way. The dullest thing in the library on purpose —
## this is the sound of a player's first five minutes and of every jam they ever dig out of.
func _gen_hit_earth(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.10)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.16 * (rng.randf_range(-1.0, 1.0) - lp)     # grit, not fracture: nothing above the mids
		out[i] = lp * 2.4 * pow(1.0 - t, 1.4) + sin(TAU * 66.0 * s) * exp(-s * 27.0) * 0.66
	# The bottom of the family's loudness ladder. Soil gives way; slate has to be beaten out. Measured
	# rather than assumed — the first tuning had this the LOUDEST strike in the game, which is exactly
	# backwards for the material a player spends their first five minutes chewing through.
	return _norm(out, 0.58)


## COAL. Brittle black glass, and it does not break once — it SHATTERS, four grains letting go a few
## milliseconds apart, each drier and brighter than rock. Band-passed so there is no rumble in it: the
## weight of a coal seam is in how little weight each blow has.
func _gen_hit_coal(rng: RandomNumberGenerator) -> PackedFloat32Array:
	const SHARDS: Array[float] = [0.0, 0.011, 0.029, 0.054]
	var n: int = int(RATE * 0.13)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in n:
		var s: float = float(i) / float(RATE)
		lp += 0.36 * (rng.randf_range(-1.0, 1.0) - lp)   # brought DOWN out of the fizz: a seam you work
		slow += 0.05 * (lp - slow)                       # for minutes cannot be the shrillest thing here
		var band: float = lp - slow                        # the dry crackle band, rumble removed
		var env: float = 0.0
		for k: int in SHARDS.size():
			var d: float = s - SHARDS[k]
			if d >= 0.0:
				env += exp(-d * (120.0 + float(k) * 45.0)) * (1.0 - float(k) * 0.19)
		out[i] = band * env * 1.6 + sin(TAU * 92.0 * s) * exp(-s * 60.0) * 0.20
	return _norm(out, 0.84)


## ORE-BEARING ROCK (ore, iron, rich ore). Stone, with something in it that does not want to break: the
## same dry fracture on the front, and a short damped metal TICK hanging off the back. Deliberately dull
## and deliberately brief — the `vein` bell is the sound that means you FOUND it, and a per-blow ring
## loud enough to compete would spend that moment several hundred times before it arrived.
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


## WOOD (trunks, leaves). A chop, not a crack: a hollow low-mid knock on a stretched, deliberately
## unmusical set of partials, a splintery fibre rasp on the front, and NO sub underneath — wood is the
## one thing you swing at down here that has no weight, and the mix should say so.
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


## DEEPSLATE (and the seal). The deep band is the one material the game asks you to WORK at, and it is
## dense: a hard tight transient with almost no spray off it, then a long low ring as the mass takes the
## blow. This is the sound of hitting something that outweighs you, and the only strike in the family
## that is still going a fifth of a second later.
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


## The boot on ROCK: harder, drier and shorter than the soft-ground scuff, with a small heel CLICK where
## the body thud goes — bare stone gives nothing back.
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


## The boot on WOOD: a board answering under you — hollow, and the only footstep with a note in it.
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

## THE SKID (`docs/BITS.md` §5) — steel glancing off rock it cannot bite.
##
## The one thing this sound must never do is resemble the crunch. A crunch is a dead 90ms thud that says
## "you took a bite"; a skid says "nothing happened, and it is never going to". So it is the opposite
## shape: no impact transient to speak of, a bright band-passed scrape that SLIDES down in pitch as the
## edge runs off the face, and a thin metallic ring left hanging after it — the tool complaining, not the
## rock yielding. Long enough (0.3s) that you cannot mistake it for a slow first blow.
func _gen_skid(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.30)
	var out := PackedFloat32Array()
	out.resize(n)
	var hp: float = 0.0
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		# A band that starts bright and slides down — the edge running along the face and losing it.
		var k: float = lerpf(0.72, 0.20, pow(t, 0.7))
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += k * (noise - lp)
		hp = lp - (lp * 0.42)
		# The scrape swells rather than striking: a slow attack is what stops it reading as a hit.
		var env: float = minf(1.0, t * 6.0) * pow(1.0 - t, 1.4)
		# ...and the tool rings thinly on top, high and quiet, well clear of the hollow ring's 96 Hz.
		phase += TAU * lerpf(1240.0, 880.0, t) / float(RATE)
		out[i] = hp * env * 1.5 + sin(phase) * pow(1.0 - t, 3.0) * 0.20
	return out


## THE HOLLOW RING (#S11) — the pick striking rock with a VOID behind it.
##
## Real rock does this and every miner and caver on earth listens for it: struck over solid ground the
## blow is a dead thud, struck over a cavity it RINGS, because the void behind the face is a resonator and
## the face is a drum skin. It is the single best piece of information a game like this can give a player
## for free, and this game was giving none of it — you broke every block blind, so digging was a chore
## rather than a search, and the whole generated world of caverns, rifts, veins and aquifers might as well
## not have been there until you walked into it.
##
## Synthesised as the crunch's noise burst gated into a short decaying tone: a low fundamental with two
## partials, long enough to read as a RING against the 0.09s dead thud, and quiet enough that hearing it
## is a thing you do on purpose.
func _gen_hollow(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.26)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var strike: float = pow(maxf(0.0, 1.0 - t * 7.0), 2.0)     # the impact itself, over in a moment
		lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
		# ...and the cavity answering it. Three partials on a slightly stretched series, which is what
		# stops it reading as a musical note and keeps it reading as an empty space.
		var s: float = float(i) / float(RATE)
		var ring: float = sin(TAU * 96.0 * s) * 0.6 \
			+ sin(TAU * 154.0 * s) * 0.28 \
			+ sin(TAU * 233.0 * s) * 0.12
		out[i] = lp * strike * 1.5 + ring * pow(1.0 - t, 2.6) * 0.42
	return out


## THE BREACH — the moment the face gives way and the void behind it opens. Air moving, not rock: a burst
## of noise swept from bright to dark by a closing filter, under a low swell. The reward beat for the ring
## above; hear one, then the other, and the whole dig has a shape.
func _gen_breach(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.55)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var k: float = lerpf(0.42, 0.03, pow(t, 0.55))            # the filter closing = the air settling
		lp += k * (rng.randf_range(-1.0, 1.0) - lp)
		phase += TAU * lerpf(74.0, 38.0, t) / float(RATE)
		out[i] = lp * pow(1.0 - t, 1.5) * 1.5 + sin(phase) * pow(1.0 - t, 2.4) * 0.30
	return out


## THE LINE RUNS — the one sound in the game that means "your machine outgrew you", so it must not be
## mistakable for anything else. Three motions in one: a low SPIN-UP sweeping 52→124 Hz that fades in
## rather than starting (something getting up to speed, caught mid-way), a metallic KNOCK of engagement,
## and then a major triad that does not stab but LOCKS IN — each note fading up on its own soft attack
## and holding under a long tail. Deliberately not the research chime: research is a small bright idea,
## and this is a large warm one.
func _gen_ignite(rng: RandomNumberGenerator) -> PackedFloat32Array:
	const LOCK: float = 0.34                                       # when the triad takes over
	var n: int = int(RATE * 0.95)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	var lp: float = 0.0
	var notes: Array = [131.0, 262.0, 330.0, 392.0, 523.0]         # C3 + a C-major triad + its octave
	for i: int in n:
		var t: float = float(i) / float(n)
		# 1. the spin-up: rising, fading in over its first third, gone by the time the chord is full
		phase += TAU * lerpf(52.0, 124.0, minf(t / 0.55, 1.0)) / float(RATE)
		var spin: float = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.30, 0.75, t))
		out[i] = (sin(phase) + sin(phase * 2.0) * 0.28) * spin * 0.34
		# 2. the knock of engagement — one short filtered noise hit right at the lock
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


## THE VEIN — the pick finding metal in the dark. Struck bronze rather than a chime: two partials a shade
## out of tune with each other so they beat against one another the way real struck metal does, over a hard
## transient and under a long thin shimmer. Short, because it fires often; bright, because it is good news.
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


## Break thump: a sine gliding 120→55 Hz with a click of noise on the front — the block giving way.
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

## Machine clunk: a dull metallic knock (low tone + odd harmonic + a breath of noise).
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

## Craft ding: two bright partials ringing down — the anvil note.
func _gen_ding() -> PackedFloat32Array:
	var n: int = int(RATE * 0.32)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var t: float = float(i) / float(RATE)
		out[i] = (sin(TAU * 1244.0 * t) * exp(-t * 13.0) + sin(TAU * 1866.0 * t) * exp(-t * 9.0)) * 0.5
	return out

## Research chime: a rising three-note arpeggio with soft tails — insight.
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

## Collect pop: a quick upward sine sweep — the pickup blip.
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

## Surface WIND: gusting band-limited noise — two chained one-pole lowpasses (a soft band around the
## breathy low-mids) under a slow two-sine gust LFO, loopified. The sky as a sound.
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


## THE RUSH bed: brighter and thinner than the surface wind — less low-frequency body, a touch of whistle
## on top — so the two never read as the same sound when you are outdoors and moving. Loopified.
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
		hp = 0.86 * (hp + lp - prev)                   # ...and a high-pass to cut the rumble entirely
		prev = lp
		var whistle: float = 0.14 * sin(TAU * 1180.0 * t) * (0.5 + 0.5 * sin(TAU * 0.9 * t))
		out[i] = (hp * 1.9 + whistle) * (0.85 + 0.15 * sin(TAU * 0.31 * t))
	return _loopify(out)


## Deep CAVE-AIR: a sub drone (a slow-beating 38/57 Hz pair) over a whisper of brown-ish noise, with a
## very slow swell so the dark feels like it breathes. Loopified.
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


## WATER POUR: a soft continuous trickle — the "shhh" of a small waterfall. Band-limited noise (a one-pole
## lowpass minus a slower lowpass ≈ a band-pass keeping the airy mid-highs, not a rumble), gently amplitude-
## modulated by a slow two-sine flutter so the sheet shimmers instead of hissing flat. Loopified. Level-driven
## by set_water — silent until you're near falling water, then it swells like the factory hum.
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


## PUMP DRAIN: a wet mechanical gurgle cycle — a low sub (a slow-beating 62/93 Hz pair) pulsing on a ~1.7 Hz
## drain rhythm, with a bubbly noise burst on each pulse's downstroke (water sucking through the tube). The
## per-pulse envelope gives it the chugging "gulp… gulp" of a working pump. Loopified; level-driven by set_water
## so it fades in only while a pump near you is draining and dies when it's dry/unpowered.
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


## A cave DRIP: a fast pitch-falling blip and its fainter echo — water finding the floor in the dark.
func _gen_drip() -> PackedFloat32Array:
	var n: int = int(RATE * 0.34)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(1500.0, 620.0, clampf(t / 0.05, 0.0, 1.0)) / float(RATE)
		var s: float = sin(phase) * exp(-t * 26.0) * 0.7
		if t > 0.14:                                    # the echo: same blip, further away
			var te: float = t - 0.14
			s += sin(TAU * 900.0 * te) * exp(-te * 30.0) * 0.22
		out[i] = s
	return out


## The BREACH stinger: a sub-bass glide (85 -> 26 Hz) under a rock-burst of noise on the front — the
## seal giving way beneath a hundred tonnes of quota. Big on purpose; it marks a once-per-world event.
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
		s += lp * exp(-tt * 9.0) * 0.9                  # the shattering front, gone in ~a third of a second
		out[i] = s                                      # _to_pcm's soft knee catches the overshoot now
	return out


## THE FACTORY'S MIDDLE — belts and gearing, the layer that says a LINE is running rather than a box is
## powered. A 110.5 Hz shaft note sitting half a hertz off the sub layer's 110 (stack them and the pair
## throbs once every two seconds, which is a thing neither layer can do alone), its fifth and octave, a
## belt slapping at 2.5 Hz, and a gear train ticking twelve teeth a second under all of it.
##
## The noise is loop-closed BEFORE the tones go on top, so every partial lands on a whole number of
## cycles across exactly two seconds and the seam is arithmetic instead of luck — the usual crossfade
## smears a strong sine into a beat, and a bed you stand in for an hour cannot afford one.
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
		# Twelve teeth a second, phase-offset so no tooth lands ON the loop point — a tick sitting exactly
		# at the seam is the one sample the crossfade cannot hide, and it is the loudest one in the bed.
		var tooth: float = fmod(t * 12.0 + 0.37, 1.0)
		out[i] = shaft * belt + out[i] * (0.6 + 3.4 * pow(maxf(0.0, 1.0 - tooth * 6.0), 3.0))
	return out


## THE FACTORY'S TOP — the clatter you hear from across a busy floor: parts moving, not tones. Band-passed
## noise gated by three tick rates that share no beat inside the loop (5, 7 and 11 a second), so it reads
## as several machines rather than one metronome. Kept far under everything else and gated behind a floor
## that is genuinely busy: this layer exists to be noticed only when it stops.
func _gen_hum_top(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(RATE * 2 + int(RATE * 0.09))
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		lp += 0.58 * (rng.randf_range(-1.0, 1.0) - lp)
		slow += 0.14 * (lp - slow)
		# Three rates, each phase-offset so they never all strike together and none strikes on the loop
		# point: simultaneous ticks read as one hammer, and a tick at the seam is an audible metronome.
		var gate: float = 0.0
		for spec: Vector2 in [Vector2(5.0, 0.13), Vector2(7.0, 0.46), Vector2(11.0, 0.79)]:
			gate += pow(maxf(0.0, 1.0 - fmod(t * spec.x + spec.y, 1.0) * 8.0), 2.6) \
				* (11.0 / spec.x) * 0.30
		out[i] = (lp - slow) * (0.10 + gate) * 1.5
	return _loopify(out)


## THE FACTORY'S SUB: one second of low drone (55 + 110 Hz) over a whisper of noise floor.
##
## The tones close on exact cycles across a second, but the noise floor did not — it starts from silence
## and ends wherever it ended, and the buffer measured a jump across the seam over four times its own
## typical sample step. That is a soft tick once a second, forever, under the one bed a player hears for
## an entire session. So the noise is loop-closed on its OWN first and the tones are laid on afterwards,
## where their arithmetic still holds: the seam becomes exact rather than nearly.
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


## Float samples to 16-bit PCM, through a SOFT limiter rather than a hard clamp.
##
## Several generators run their peaks past full scale and the old clamp simply squared them off: 265
## samples of the breach stinger and 172 of the rope catch were flat-topped, which is a burst of odd
## harmonics on top of what are meant to be the two biggest, roundest sounds in the game. Below the knee
## nothing is touched at all; above it the curve bends toward 1.0 and never arrives, so the peaks keep
## their level and stop being square. Cheaper than re-tuning fifteen generators and it cannot regress.
const KNEE: float = 0.72
const CEIL: float = 0.985                     ## the asymptote: nothing ever reaches full scale
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


## Scale a buffer so its loudest sample lands exactly on `peak`.
##
## Two reasons, both measured. First, the grain bank: four takes of the same voice drawn from four
## stretches of noise came out up to 4 dB apart, and a footstep that bounces in level every stride reads
## as a bug rather than as variation — alternates have to MATCH. Second, the identity of a short noise
## burst was hostage to which stretch it happened to draw: the same recipe measured peak 0.94 one build
## and 0.74 the next, which moved the footstep close enough to the cave drip to be confusable. Fixing the
## peak makes a sound's place in the mix a decision instead of a dice roll.
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


## Fill `name`'s grain bank: GRAINS takes of the same recipe, each on a fresh stretch of the noise stream,
## so a sound the player triggers by the hundred draws a different waveform every time instead of the same
## one with the pitch nudged.
##
## The canonical take from `_streams` goes in as the FIRST grain wherever there is one. That matters:
## check_voice judges the canonical render, and a render nothing ever plays is a measurement of a sound
## that does not exist. This way the take the harness holds to the floor is one the player actually hears.
func _grains(name: StringName, gen: Callable, rng: RandomNumberGenerator) -> void:
	var takes: Array[AudioStreamWAV] = []
	var canonical: AudioStreamWAV = _streams.get(name, null)
	if canonical != null:
		takes.append(canonical)
	while takes.size() < GRAINS:
		takes.append(_wav(gen.call(rng)))
	_bank[name] = takes
