class_name Sfx
extends Node

## Procedural AUDIO — audio-lite (the missing sense). Every sound is SYNTHESIZED at boot
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
var _pour_player: AudioStreamPlayer           # ambience bed: nearby pouring/falling WATER (L3, docs/DECISIONS)
var _pump_player: AudioStreamPlayer           # ambience bed: a working PUMP's wet mechanical drain (L3)
var _pour_level: float = 0.0                  # smoothed 0..1 — how much pouring water is near the listener
var _pump_level: float = 0.0                  # smoothed 0..1 — how hard a nearby pump is draining
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
	_streams[&"step"] = _wav(_gen_step(rng))
	_streams[&"hollow"] = _wav(_gen_hollow(rng))
	_streams[&"breach"] = _wav(_gen_breach(rng))
	_streams[&"ignite"] = _wav(_gen_ignite(rng))
	_streams[&"vein"] = _wav(_gen_vein(rng))
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
	# WATER BEDS (L3 audio): two more silent-until-driven loops — a soft WATER-POUR/trickle you hear as
	# you near falling water (a small waterfall in the dark), and a working PUMP's wet mechanical drain.
	# Both level-driven from the controller (set_water) exactly like the factory hum, so they swell with
	# nearby activity and fade to silence when nothing's pouring/pumping — they blend under wind/cave/drips.
	_pour_player = _make_loop_player(_gen_pour(rng))
	_pump_player = _make_loop_player(_gen_pump(rng))
	if not _muted:
		_hum_player.play()
		_wind_player.play()
		_cave_player.play()
		_pour_player.play()
		_pump_player.play()


## Stop every voice on teardown — a stream still playing at quit leaves its playback object alive in
## the mixer and trips the ObjectDB leak warning on exit (harness noise we refuse to normalize).
## Dropping the stream refs too matters under the headless Dummy driver, whose mixer never steps and
## so never reaps a stopped voice on its own.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_hum_player, _wind_player, _cave_player, _pour_player, _pump_player, _ui_player]:
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
		lp += 0.18 * (rng.randf_range(-1.0, 1.0) - lp)      # duller than the crunch: this is grit, not fracture
		phase += TAU * lerpf(150.0, 78.0, t) / float(RATE)  # the weight of a boot landing
		out[i] = (lp * 1.5 + sin(phase) * 0.5) * pow(1.0 - t, 2.8)
	return out


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
