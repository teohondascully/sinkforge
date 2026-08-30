class_name Score
extends Node

## The score. There is no track list and no cue system: the music is a pure function of depth. Three
## synthesized beds run continuously in parallel, always in tune with each other, and the mix between
## them is set by how far down the body is.
##
##   OPEN   root, fifth, octave, twelfth. No third, so it states a key without stating a mood. Loudest
##          at the surface, thinning as you descend.
##   MINOR  the minor third and minor seventh. Fading this in turns the same harmony sad without a key
##          change, a transition or a second recording.
##   SUB    a very low sine under a breath of filtered noise. Weight. Grows the whole way down.
##
## The whole stack is pitched down with depth, all three players by the same factor, so they stay in
## tune while the tonal centre falls. That is what makes it read as one thing sinking rather than as
## tracks crossfading. A per-zone bed would be tens of millions of sin() calls at boot and would snap
## between presets instead of blending. Headless-safe on the same terms as Sfx: synthesis still runs
## so the code path stays warm, but nothing plays, because the Dummy driver never reaps a started
## voice and trips the leak warning.
##
## LIFTED from `legacy/scenes/score.gd` (`docs/DECISIONS_LEDGER.md` D0215), unchanged except for one
## line. Legacy read the music slider straight off a `Settings` global; `Settings` belongs in `shell/`
## and `tools/layer_lint/layer_lint.py` gives `view` access to `interface` and `core` only, so the level
## is INJECTED as `music_db` instead. That is the whole diff, and it is the shape every remaining lift
## out of legacy needs: a global read becomes a property the layer above sets.
##
## WHAT IT NEEDS FROM THE SIM IS ONE FLOAT. `set_depth(t, delta)` takes 0 at the surface and 1 at the
## bottom, so this file never touches `TileGrid`, `Body` or even an `Observation` -- its caller derives
## `t` and hands it over. That is why it could be lifted before any renderer exists: it is not a
## renderer, it is a function of depth that happens to make noise.

const RATE: int = 8000              ## Hz; top partial is 220 Hz, so this is well above Nyquist at a third the work
const LOOP_SECONDS: float = 6.0     ## every partial below is a whole number of cycles in this window
const ROOT: float = 55.0            ## Hz, A1: the tonal floor everything is built on

## Depth to mix. `t` is 0 at the surface and 1 at the bottom of the world. The curves are gentle on
## purpose, so the change is never attributable to a moment.
const OPEN_AT_TOP: float = 0.62
const OPEN_AT_BOTTOM: float = 0.20
const MINOR_AT_TOP: float = 0.00
const MINOR_AT_BOTTOM: float = 0.70
const SUB_AT_TOP: float = 0.12
const SUB_AT_BOTTOM: float = 0.85
const PITCH_AT_TOP: float = 1.00
const PITCH_AT_BOTTOM: float = 0.68    ## just under a fifth down by the bottom of the world

const BASE_DB: float = -17.0                  ## dB at full mix, before the music slider; matches Sfx's loudest bed
const FADE_RATE: float = 0.25        ## per-second travel of the depth mix, slower than walking on purpose

var _open: AudioStreamPlayer
var _minor: AudioStreamPlayer
var _sub: AudioStreamPlayer
var _depth: float = 0.0              ## smoothed 0..1
var _muted: bool = DisplayServer.get_name() == "headless"
## The music slider, in dB, set by whoever owns settings. 0.0 means "no attenuation", which is the right
## default for a build with no settings screen yet -- NOT silence, so a caller that forgets this still
## hears the score rather than a silent bug that looks like the lift failed.
var music_db: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816                        # fixed: the same "recording" every boot
	_open = _bed(_gen_open())
	_minor = _bed(_gen_minor())
	_sub = _bed(_gen_sub(rng))
	set_depth(0.0, 1.0)                        # start settled at the surface, not fading up into it


## Stop every bed on teardown, as Sfx does: a stream still playing at quit leaves its playback object
## alive in the mixer and trips the ObjectDB leak warning on exit.
func _exit_tree() -> void:
	for bed: AudioStreamPlayer in [_open, _minor, _sub]:
		if bed != null:
			bed.stop()
			bed.stream = null


## Called every frame with how far down the body is, 0 at the surface to 1 at the bottom of the world.
## The mix eases toward it, so a fast fall does not slam the score.
func set_depth(t: float, delta: float) -> void:
	_depth = move_toward(_depth, clampf(t, 0.0, 1.0), delta * FADE_RATE)
	var d: float = smoothstep(0.0, 1.0, _depth)
	var pitch: float = lerpf(PITCH_AT_TOP, PITCH_AT_BOTTOM, d)
	_apply(_open, lerpf(OPEN_AT_TOP, OPEN_AT_BOTTOM, d), pitch)
	_apply(_minor, lerpf(MINOR_AT_TOP, MINOR_AT_BOTTOM, d), pitch)
	_apply(_sub, lerpf(SUB_AT_TOP, SUB_AT_BOTTOM, d), pitch)


## `level` is a linear gain, not a dB position. Three beds of one chord have to balance the way a mixer
## balances them; lerping in dB would make the quiet end vanish long before the curve says it should.
func _apply(p: AudioStreamPlayer, level: float, pitch: float) -> void:
	p.pitch_scale = pitch
	p.volume_db = -80.0 if level <= 0.01 else linear_to_db(level) + BASE_DB + music_db


## One looping bed: a seamless WAV on its own player, started at boot and never stopped. Mixing is done
## entirely with volume, so the three stay sample-locked and can never drift out of phase.
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


## Additive sine stack with a slow amplitude LFO per partial, so the chord breathes instead of sitting
## still. Every partial frequency and every LFO rate must be a whole number of cycles across the loop
## window: that alone is what makes the loop seamless. `partials` rows are `[ratio, gain, lfo_cycles]`.
func _stack(partials: Array) -> PackedFloat32Array:
	var n: int = int(RATE * LOOP_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	for p: Array in partials:
		var freq: float = ROOT * float(p[0])
		# Snap to the nearest frequency completing whole cycles in the window. Every ratio below already
		# lands exactly, so this moves nothing today; it is what stops a new ratio breaking the loop.
		var cycles: float = round(freq * LOOP_SECONDS)
		freq = cycles / LOOP_SECONDS
		var gain: float = float(p[1])
		var lfo: float = float(p[2])
		for i: int in n:
			var t: float = float(i) / float(RATE)
			var breathe: float = 0.62 + 0.38 * sin(TAU * lfo / LOOP_SECONDS * t + freq)
			out[i] += sin(TAU * freq * t) * gain * breathe
	return out


## OPEN: the no-third chord everything else in the score modifies.
func _gen_open() -> PackedFloat32Array:
	return _stack([
		[1.0, 0.30, 1.0],      # root
		[1.5, 0.20, 2.0],      # fifth
		[2.0, 0.16, 3.0],      # octave
		[3.0, 0.09, 5.0],      # twelfth
		[4.0, 0.05, 7.0],      # double octave: just enough air to not be a drone
	])


## MINOR: the third and the seventh. Alone it is thin and unresolved; over OPEN it is the whole mood.
func _gen_minor() -> PackedFloat32Array:
	return _stack([
		[1.2, 0.22, 1.0],      # minor third (6:5)
		[1.8, 0.15, 2.0],      # minor seventh (9:5)
		[2.4, 0.10, 3.0],      # minor third, octave up
		[3.6, 0.05, 4.0],      # minor seventh, octave up
	])


## SUB: weight. A very low sine with its own octave, under a breath of low-passed noise so the bottom
## of the mix moves. Most of what the deep sounds like, and barely present at the surface.
func _gen_sub(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out: PackedFloat32Array = _stack([
		[0.5, 0.34, 1.0],      # an octave below the root
		[1.0, 0.14, 2.0],
	])
	# The breath is noise through a one-pole low-pass, faded across the seam so the loop stays silent at
	# the join. Noise cannot be made periodic the way a sine can, so it needs the envelope instead.
	var n: int = out.size()
	var lp: float = 0.0
	for i: int in n:
		lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)     # one-pole, ~64 Hz corner at this rate
		var edge: float = minf(float(i), float(n - 1 - i)) / (float(RATE) * 0.35)
		out[i] += lp * 1.6 * clampf(edge, 0.0, 1.0)
	return out
