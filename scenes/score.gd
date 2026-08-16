class_name Score
extends Node

## THE SCORE. Sinkforge had a full ambience layer — wind, cave-air, drips, a factory hum that swells
## with nearby machinery — and no TONE. Ambience tells you where you are. Tone tells you how to feel
## about it, and a game whose whole subject is a long patient descent into somewhere older and colder
## than you is a game that lives or dies on that.
##
## THE ONE IDEA: THE MUSIC DESCENDS WITH YOU. There is no track list and no cue system, because a
## cue system would need something to cue off and the only thing that reliably means anything here is
## depth. Three synthesized beds run continuously in parallel, always in tune with each other, and the
## mix between them is a pure function of how far down the body is:
##
##   OPEN   — root, fifth, octave, twelfth. No third at all, so it is neither major nor minor: this is
##            the bed that carries "air", and it is loudest at the surface and thins as you descend.
##   MINOR  — the minor third and minor seventh. Fading this in is what turns the same harmony sad,
##            without a key change, a transition, or a second recording.
##   SUB    — a very low sine under a breath of filtered noise. Weight. It grows the whole way down and
##            is most of what the deep sounds like.
##
## and the whole stack is PITCHED DOWN with depth, all three players by the same factor, so they stay
## in tune while the tonal centre physically falls. That is the trick the entire system rests on: you
## are not hearing four tracks fade between each other, you are hearing one thing sink.
##
## WHY IT IS BUILT THIS WAY. Naively this wants one long recording per depth zone, which is 4 x 20s of
## additive synthesis — tens of millions of sin() calls in GDScript at boot, i.e. seconds of black
## screen. Three short loops mixed and pitch-shifted give more variety than four fixed beds for a
## fraction of the cost, and every intermediate depth gets its own blend rather than snapping between
## presets. The pads are also synthesized at a much LOWER RATE than the effects: the top partial here is
## 220 Hz, so 8 kHz is far above Nyquist for anything audible in them — and it is a third of the work.
##
## Headless-safe on the same terms as Sfx: synthesis still runs (the code path stays warm) but nothing
## is ever played, because the Dummy driver never reaps a started voice and trips the leak warning.

const RATE: int = 8000              ## top partial is 220 Hz; 8 kHz is far above Nyquist and a third the work
const LOOP_SECONDS: float = 6.0     ## every partial below is a whole number of cycles in this window
const ROOT: float = 55.0            ## A1 — the tonal floor everything is built on

## Depth → mix. `t` is 0 at the surface and 1 at the bottom of the world, and every curve here is
## deliberately gentle: the point is that you cannot name the moment it changed.
const OPEN_AT_TOP: float = 0.62
const OPEN_AT_BOTTOM: float = 0.20
const MINOR_AT_TOP: float = 0.00
const MINOR_AT_BOTTOM: float = 0.70
const SUB_AT_TOP: float = 0.12
const SUB_AT_BOTTOM: float = 0.85
const PITCH_AT_TOP: float = 1.00
const PITCH_AT_BOTTOM: float = 0.68  ## a bit over a fifth down by the bottom of the world

const BASE_DB: float = -17.0         ## a bed at full mix, before the music slider — just under the ambience beds
const FADE_RATE: float = 0.25        ## per-second travel of the depth mix — slower than walking on purpose

var _open: AudioStreamPlayer
var _minor: AudioStreamPlayer
var _sub: AudioStreamPlayer
var _depth: float = 0.0              ## smoothed 0..1
var _muted: bool = DisplayServer.get_name() == "headless"


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816                        # fixed seed — the same "recording" every boot
	_open = _bed(_gen_open())
	_minor = _bed(_gen_minor())
	_sub = _bed(_gen_sub(rng))
	set_depth(0.0, 1.0)                        # start settled at the surface rather than fading up into it


## Stop every bed on teardown, same as Sfx: a stream still playing at quit leaves its playback object
## alive in the mixer and trips the ObjectDB leak warning on exit.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_open, _minor, _sub]:
		if bed != null:
			bed.stop()
			bed.stream = null


## Called every frame with how far down the body is, 0 (surface) .. 1 (bottom of the world). The mix
## eases toward it, so a fast fall does not slam the score — a descent should sound like a descent even
## when it takes two seconds.
func set_depth(t: float, delta: float) -> void:
	_depth = move_toward(_depth, clampf(t, 0.0, 1.0), delta * FADE_RATE)
	var d: float = smoothstep(0.0, 1.0, _depth)
	var pitch: float = lerpf(PITCH_AT_TOP, PITCH_AT_BOTTOM, d)
	_apply(_open, lerpf(OPEN_AT_TOP, OPEN_AT_BOTTOM, d), pitch)
	_apply(_minor, lerpf(MINOR_AT_TOP, MINOR_AT_BOTTOM, d), pitch)
	_apply(_sub, lerpf(SUB_AT_TOP, SUB_AT_BOTTOM, d), pitch)


## The mix levels are LINEAR gains, not dB positions — three beds of one chord have to balance against
## each other the way a mixer balances them, and lerping in dB would make the quiet end vanish long
## before the curve says it should.
func _apply(p: AudioStreamPlayer, level: float, pitch: float) -> void:
	p.pitch_scale = pitch
	p.volume_db = -80.0 if level <= 0.01 else linear_to_db(level) + BASE_DB + Settings.music_db()


## One looping bed: a seamless WAV on its own player, started at boot and never stopped. Mixing is done
## entirely with volume, so the three stay sample-locked forever and can never drift out of phase.
func _bed(samples: PackedFloat32Array) -> AudioStreamPlayer:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = samples.size()
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i: int in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	w.data = pcm
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.volume_db = -80.0
	add_child(p)
	if not _muted:
		p.play()
	return p


## Additive sine stack with a slow amplitude LFO per partial, so the chord BREATHES instead of sitting
## still. Every partial frequency and every LFO rate is a whole number of cycles across the loop window,
## which is the entire reason the loop is seamless — no crossfade, no click, no fade envelope eating the
## ends. `partials` is [[harmonic_ratio, gain, lfo_cycles_per_loop], ...].
func _stack(partials: Array) -> PackedFloat32Array:
	var n: int = int(RATE * LOOP_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	for p: Array in partials:
		var freq: float = ROOT * float(p[0])
		# Snap to the nearest frequency that completes whole cycles in the window — inaudible at these
		# ratios (well under a cent) and it is what makes the seam vanish.
		var cycles: float = round(freq * LOOP_SECONDS)
		freq = cycles / LOOP_SECONDS
		var gain: float = float(p[1])
		var lfo: float = float(p[2])
		for i: int in n:
			var t: float = float(i) / float(RATE)
			var breathe: float = 0.62 + 0.38 * sin(TAU * lfo / LOOP_SECONDS * t + freq)
			out[i] += sin(TAU * freq * t) * gain * breathe
	return out


## OPEN: root, fifth, octave, twelfth — a stack with no third in it, so it states a key without stating
## a mood. Everything the score does later is a modification of this.
func _gen_open() -> PackedFloat32Array:
	return _stack([
		[1.0, 0.30, 1.0],      # root
		[1.5, 0.20, 2.0],      # fifth
		[2.0, 0.16, 3.0],      # octave
		[3.0, 0.09, 5.0],      # twelfth
		[4.0, 0.05, 7.0],      # double octave — just enough air to not be a drone
	])


## MINOR: the third and the seventh. Alone it is thin and unresolved; over OPEN it is the whole mood.
func _gen_minor() -> PackedFloat32Array:
	return _stack([
		[1.2, 0.22, 1.0],      # minor third (6:5)
		[1.8, 0.15, 2.0],      # minor seventh (9:5)
		[2.4, 0.10, 3.0],      # minor third, octave up
		[3.6, 0.05, 4.0],      # minor seventh, octave up
	])


## SUB: weight. A very low sine, its own octave, and a breath of low-passed noise so the bottom of the
## mix moves. This is most of what the deep sounds like, and at the surface it is barely present.
func _gen_sub(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out: PackedFloat32Array = _stack([
		[0.5, 0.34, 1.0],      # an octave below the root
		[1.0, 0.14, 2.0],
	])
	# The breath is noise through a one-pole low-pass, faded across the seam so the loop stays silent at
	# the join. Noise cannot be made periodic the way a sine can, so it gets the envelope instead.
	var n: int = out.size()
	var lp: float = 0.0
	for i: int in n:
		lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)     # one-pole, ~64 Hz corner at this rate
		var edge: float = minf(float(i), float(n - 1 - i)) / (float(RATE) * 0.35)
		out[i] += lp * 1.6 * clampf(edge, 0.0, 1.0)
	return out
