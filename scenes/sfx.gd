class_name Sfx
extends Node

## Procedural AUDIO — audio-lite (FABLE_50 #8, the missing sense). Every sound is SYNTHESIZED at boot
## (no assets): short 16-bit mono WAVs built from noise/sine primitives, played through a small pool of
## positional players, plus one looping factory HUM whose level follows how much machinery is working
## near you (the factory-heartbeat). Pure representation: MainView pokes play()/ui() from the same verb
## hooks that already fire particles, and set_hum() each frame. Headless-safe (the Dummy audio driver
## swallows playback silently, so the harness runs unchanged).

const RATE: int = 22050
const POOL: int = 10

var _streams: Dictionary = {}                 # name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer2D] = []
var _pool_idx: int = 0
var _ui_player: AudioStreamPlayer
var _hum_player: AudioStreamPlayer
var _hum_level: float = 0.0                   # smoothed 0..1
var _wind_player: AudioStreamPlayer           # ambience bed: surface wind
var _cave_player: AudioStreamPlayer           # ambience bed: deep cave-air
var _wind_level: float = 0.0                  # smoothed 0..1
var _cave_level: float = 0.0
var _drip_in: float = 4.0                     # seconds until the next cave drip
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
	for _i: int in POOL:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1500.0
		p.volume_db = -8.0
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
	# AMBIENCE BEDS (audio slice 2): two more loops — surface WIND and deep CAVE-AIR — crossfaded by
	# where the body is (set_ambience). Underground you hear the earth, on top you hear the sky.
	_wind_player = _make_loop_player(_gen_wind(rng))
	_cave_player = _make_loop_player(_gen_cave(rng))
	if not _muted:
		_hum_player.play()
		_wind_player.play()
		_cave_player.play()


## Stop every voice on teardown — a stream still playing at quit leaves its playback object alive in
## the mixer and trips the ObjectDB leak warning on exit (harness noise we refuse to normalize).
## Dropping the stream refs too matters under the headless Dummy driver, whose mixer never steps and
## so never reaps a stopped voice on its own.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_hum_player, _wind_player, _cave_player, _ui_player]:
		bed.stop()
		bed.stream = null
	for p: AudioStreamPlayer2D in _pool:
		p.stop()
		p.stream = null


## One positional sound at a world position. `pitch` jitters a hair on top so repeats don't machine-gun.
func play(name: StringName, pos: Vector2, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(name, null)
	if stream == null or _muted:
		return
	var p: AudioStreamPlayer2D = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL
	p.stream = stream
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = -8.0 + vol_db + Settings.sound_db()
	p.play()


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
func set_hum(level: float, delta: float) -> void:
	_hum_level = move_toward(_hum_level, clampf(level, 0.0, 1.0), delta * 0.8)
	_hum_player.volume_db = lerpf(-60.0, -22.0, _hum_level) + Settings.ambience_db()


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

## Mining crunch: a decaying noise burst through a one-pole lowpass — dry rock fracture.
func _gen_crunch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = int(RATE * 0.09)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var env: float = pow(1.0 - t, 2.2)
		lp += 0.30 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * env * 1.6
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
		out[i] = clampf(s, -1.0, 1.0)
	return out


## The hum loop: one seamless second of low drone (55 + 110 Hz) with a whisper of noise floor.
func _gen_hum(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = RATE                              # exactly 1s → 55/110 Hz cycles close seamlessly
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = sin(TAU * 55.0 * t) * 0.30 + sin(TAU * 110.0 * t) * 0.15 + lp * 0.20
	return out


func _to_pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i: int in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, v)
	return pcm


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = _to_pcm(samples)
	return w
