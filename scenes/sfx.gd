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


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712                        # fixed seed — the same "recording" every boot
	_streams[&"crunch"] = _wav(_gen_crunch(rng))
	_streams[&"thump"] = _wav(_gen_thump(rng))
	_streams[&"clunk"] = _wav(_gen_clunk(rng))
	_streams[&"ding"] = _wav(_gen_ding())
	_streams[&"chime"] = _wav(_gen_chime())
	_streams[&"pop"] = _wav(_gen_pop())
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
	_hum_player.play()


## Stop every voice on teardown — a stream still playing at quit leaves its playback object alive in
## the mixer and trips the ObjectDB leak warning on exit (harness noise we refuse to normalize).
func _exit_tree() -> void:
	_hum_player.stop()
	_ui_player.stop()
	for p: AudioStreamPlayer2D in _pool:
		p.stop()


## One positional sound at a world position. `pitch` jitters a hair on top so repeats don't machine-gun.
func play(name: StringName, pos: Vector2, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(name, null)
	if stream == null:
		return
	var p: AudioStreamPlayer2D = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL
	p.stream = stream
	p.global_position = pos
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = -8.0 + vol_db
	p.play()


## A non-positional interface sound (craft ding, research chime).
func ui(name: StringName, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(name, null)
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.pitch_scale = pitch
	_ui_player.play()


## The factory heartbeat: 0..1 how much machinery works near the player; the hum fades between
## near-silence and a felt presence, smoothed so machines starting/stopping breathe rather than snap.
func set_hum(level: float, delta: float) -> void:
	_hum_level = move_toward(_hum_level, clampf(level, 0.0, 1.0), delta * 0.8)
	_hum_player.volume_db = lerpf(-60.0, -22.0, _hum_level)


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
