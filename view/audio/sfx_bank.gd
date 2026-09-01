class_name SfxBank
extends RefCounted

## THE SYNTHESISED VOICES, as pure functions. Ported from `legacy/scenes/sfx.gd:732-764`
## (`_gen_hollow`, `_gen_breach`). `docs/LEGACY_GAP.md` T1 #6 and Lane G's first row.
##
## `sim/mining/hollow_tell.gd` has been "written, tested, correct" since it landed and **`HollowTell.RING`
## is referenced by nothing** — the gap doc's own words. D0293 gave the reading its visual half back; this
## is the audible one it was written for in the first place, and legacy is explicit that the two are a
## pair: the draught is "the same tell for a player with the sound off".
##
## **SYNTHESIS, NOT ASSETS**, exactly as legacy: there are no sound files in `legacy/assets/` at all. The
## entire audio vocabulary is generated at boot from a few dozen lines of arithmetic per voice, which is
## why Lane G ports cleanly and why there is no art backlog behind it.
##
## **SPLIT FROM THE PLAYER, and the split is the whole reason this is testable.** Legacy's `sfx.gd` is
## 1,125 lines with a dozen ambience beds and its generators reach `self` for an `AudioStreamPlayer` pool.
## Here the arithmetic is static and returns a buffer, so `tests/test_sfx_bank.gd` can measure what the
## sound IS — its length, its decay, and whether it is tonal — with no audio device, no `Node`, and no
## scene. A generator that could only be checked by listening is one nobody checks.
##
## **DETERMINISTIC.** Legacy seeds its noise from a `RandomNumberGenerator`; this takes a `SplitRng`, so
## the same seed gives the same buffer on every machine. Not because audio is replayed — it is not — but
## because a test that asserts a spectral property against a buffer that changes per run is measuring the
## noise floor, and `docs/QUALITY.md`'s comparison discipline applies to anything a test reads back.

const RATE: int = 22050   ## legacy's own sample rate

## The hollow ring, `legacy/scenes/sfx.gd:732-748`. Legacy's own note on the three partials is the whole
## design and is ported with them: **"96, 154 and 233 Hz sit on a stretched series, so this reads as an
## empty space and not as a note."** A harmonic series would be a chime; the stretch is what makes it
## read as a room.
const HOLLOW_SECONDS: float = 0.26
const HOLLOW_PARTIALS: Array[float] = [96.0, 154.0, 233.0]
const HOLLOW_WEIGHTS: Array[float] = [0.6, 0.28, 0.12]
const HOLLOW_STRIKE_RATE: float = 7.0    ## the impact itself, over in a moment
const HOLLOW_STRIKE_POW: float = 2.0
const HOLLOW_LP: float = 0.30            ## one-pole low pass on the noise -- rock, not hiss
const HOLLOW_NOISE_GAIN: float = 1.5
const HOLLOW_RING_GAIN: float = 0.42
const HOLLOW_RING_DECAY: float = 2.6

## The breach, `legacy/scenes/sfx.gd:751-764`. Legacy's note: "the face gives way and the void behind it
## opens. Air moving rather than rock, a burst of noise swept bright to dark by a closing filter under a
## low swell. **The answer to the hollow ring above.**" So it is deliberately the ring's opposite — broad
## noise where the ring is tonal — and `tests/test_sfx_bank.gd` asserts exactly that difference.
const BREACH_SECONDS: float = 0.55
const BREACH_LP_OPEN: float = 0.42       ## the filter closing IS the air settling
const BREACH_LP_SHUT: float = 0.03
const BREACH_LP_CURVE: float = 0.55
const BREACH_SWELL_HI: float = 74.0      ## the low swell under it, falling
const BREACH_SWELL_LO: float = 38.0
const BREACH_NOISE_DECAY: float = 1.5
const BREACH_NOISE_GAIN: float = 1.5
const BREACH_SWELL_DECAY: float = 2.4
const BREACH_SWELL_GAIN: float = 0.30


## A noise sample in [-1, 1). `SplitRng.next_float` is [0, 1) and exact, so this is too.
static func _noise(rng: SplitRng) -> float:
	return rng.next_float() * 2.0 - 1.0


## THE HOLLOW RING. A short filtered-noise strike with a stretched three-partial tail under it.
static func hollow(rng: SplitRng) -> PackedFloat32Array:
	var n: int = int(float(RATE) * HOLLOW_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var strike: float = pow(maxf(0.0, 1.0 - t * HOLLOW_STRIKE_RATE), HOLLOW_STRIKE_POW)
		lp += HOLLOW_LP * (_noise(rng) - lp)
		var s: float = float(i) / float(RATE)
		var ring: float = 0.0
		for p: int in HOLLOW_PARTIALS.size():
			ring += sin(TAU * HOLLOW_PARTIALS[p] * s) * HOLLOW_WEIGHTS[p]
		out[i] = lp * strike * HOLLOW_NOISE_GAIN \
			+ ring * pow(1.0 - t, HOLLOW_RING_DECAY) * HOLLOW_RING_GAIN
	return out


## THE BREACH. Broadband noise under a closing filter, with a falling swell beneath it.
static func breach(rng: SplitRng) -> PackedFloat32Array:
	var n: int = int(float(RATE) * BREACH_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var k: float = lerpf(BREACH_LP_OPEN, BREACH_LP_SHUT, pow(t, BREACH_LP_CURVE))
		lp += k * (_noise(rng) - lp)
		phase += TAU * lerpf(BREACH_SWELL_HI, BREACH_SWELL_LO, t) / float(RATE)
		out[i] = lp * pow(1.0 - t, BREACH_NOISE_DECAY) * BREACH_NOISE_GAIN \
			+ sin(phase) * pow(1.0 - t, BREACH_SWELL_DECAY) * BREACH_SWELL_GAIN
	return out


## THE LIMITER, `legacy/scenes/sfx.gd:1073-1074` and `_to_pcm`. A SOFT KNEE, not a clamp, and the
## difference is the whole reason this is ported rather than written: **the breach deliberately
## overdrives** — it peaks near 1.15 by construction, because `lp * 1.5` with a low-passed noise source
## reaching ±1 does — and a hard clamp on that flat-tops every loud sample into audible distortion. Above
## `KNEE` the signal is compressed toward `CEIL` by `tanh`, which is smooth, and `CEIL` is 0.985 so
## nothing ever reaches full scale at all.
##
## The first version of this file clamped, and no assertion here could have told the difference: the
## PEAK is identical either way. It was caught by reading legacy's `_to_pcm` after the suite flagged the
## breach for exceeding 1.0 — the test found the overdrive, and legacy's source explained that the
## overdrive was the point and the limiter was the missing half.
const KNEE: float = 0.72
const CEIL: float = 0.985   ## the asymptote: nothing ever reaches full scale


## One sample through the soft knee. Public because it is the only nonlinearity in the chain and the one
## thing a test can assert exactly, at a stated input, without generating a sound at all.
static func limited(v: float) -> float:
	var over: float = absf(v) - KNEE
	if over <= 0.0:
		return v
	return signf(v) * (KNEE + (CEIL - KNEE) * tanh(over / (1.0 - KNEE)))


## A buffer as a playable stream. Split out because it is the only part that touches an engine type, so
## everything above stays assertable without one — and because `view/audio/score.gd` already does exactly
## this three times inline, which is one definition of "how a float buffer becomes 16-bit PCM" too many.
static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(limited(samples[i]) * 32767.0))
	wav.data = bytes
	return wav


## Peak absolute sample. Public because "did it produce a sound at all" is the first thing any consumer
## of a generator wants to know, and a silent buffer is the exact quiet green this project keeps finding.
static func peak(samples: PackedFloat32Array) -> float:
	var worst: float = 0.0
	for v: float in samples:
		worst = maxf(worst, absf(v))
	return worst


## Root-mean-square over a slice, `[from, to)`. The measurement decay is asserted with: a peak says the
## sound started, an RMS ratio between head and tail says it ENDED, and a voice that never decayed would
## satisfy every peak-based check while ringing forever.
static func rms(samples: PackedFloat32Array, from: int, to: int) -> float:
	var hi: int = mini(to, samples.size())
	var lo: int = maxi(0, from)
	if hi <= lo:
		return 0.0
	var sum: float = 0.0
	for i: int in range(lo, hi):
		sum += samples[i] * samples[i]
	return sqrt(sum / float(hi - lo))


## Magnitude of one frequency in a buffer, by direct correlation against a sine and cosine at that
## frequency (a single-bin DFT). Here rather than in the test because it is the only measurement that can
## tell the two voices apart — the ring is TONAL and the breach is BROADBAND, and every other property
## they share. A test that could not measure that would be asserting "it made a noise" twice.
static func tone_magnitude(samples: PackedFloat32Array, hz: float) -> float:
	var re: float = 0.0
	var im: float = 0.0
	for i: int in samples.size():
		var a: float = TAU * hz * float(i) / float(RATE)
		re += samples[i] * cos(a)
		im += samples[i] * sin(a)
	return sqrt(re * re + im * im) / float(maxi(1, samples.size()))
