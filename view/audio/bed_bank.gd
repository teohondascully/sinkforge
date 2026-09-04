class_name BedBank
extends RefCounted

## THE BEDS (A' step 6f, D0366): the ten looping ambiences under the game, synthesized at boot from
## legacy `scenes/sfx.gd`'s generators, verbatim in their arithmetic. Every bed is a level-driven loop
## rather than a one-shot -- the factory in three layers, the surface wind, the cave air, the rush of
## speed, the pouring water and the pump's drain, the winch and the line -- and each follows a system
## that is LIVE by the GDD (the plan's §3.2 row: only legacy's `boom` was dead and it is not here).
##
## The noise source is the split RNG, so the bank is deterministic per seed and two boots sound alike
## (the bank suite rests on that). Legacy's `randf_range(-1, 1)` is `_noise`.
##
## Every generator returns FLOAT samples; `to_loop_stream` is the only line that touches an engine
## type, so everything above it is assertable without a device: length, tone, the closed seam.

const RATE: int = SfxBank.RATE
const LOOP_FADE_SECONDS: float = 0.09   ## the crossfade that closes a noise loop without a click
## Every raw buffer is padded by the fade, so the CLOSED loop is exactly its stated seconds and every
## sine partial in it (38, 55, 57, 62, 88, 93, 110, 132, 143, 219 Hz...) lands on a whole number of
## cycles at the seam. Legacy padded only the three hum layers and let the crossfade smear the rest.

## The ten beds by name, with the length of each in seconds AFTER the seam is closed. Derived from the
## generators' own buffer sizes rather than written twice: the suite reads this table.
const SECONDS: Dictionary = {
	&"hum": 1.0, &"hum_mid": 2.0, &"hum_top": 2.0, &"wind": 3.0, &"cave": 3.0,
	&"rush": 2.0, &"pour": 3.0, &"pump": 3.0, &"winch": 2.0, &"creak": 3.0,
}


## The raw length for a bed of `seconds`: the loop plus the fade the seam will eat.
static func padded(seconds: int) -> int:
	return RATE * seconds + int(float(RATE) * LOOP_FADE_SECONDS)


static func _noise(rng: SplitRng) -> float:
	return rng.next_float() * 2.0 - 1.0


## The bed by name. One entry point so the driver builds its players from `SECONDS`' keys, and the bank
## suite walks the same keys so a bed named there without a generator fails in the suite, not in play.
static func generate(name: StringName, rng: SplitRng) -> PackedFloat32Array:
	match name:
		&"hum": return hum(rng)
		&"hum_mid": return hum_mid(rng)
		&"hum_top": return hum_top(rng)
		&"wind": return wind(rng)
		&"cave": return cave(rng)
		&"rush": return rush(rng)
		&"pour": return pour(rng)
		&"pump": return pump(rng)
		&"winch": return winch(rng)
		&"creak": return creak(rng)
	return PackedFloat32Array()   # an unknown name is an empty buffer; the suite asserts every table key generates


## Crossfade a buffer's tail into its head over about 90 ms so a noise-based loop closes without a
## click. Pure sines loop on exact cycles; filtered noise never lands back where it started.
static func loopify(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade: int = mini(int(float(RATE) * LOOP_FADE_SECONDS), samples.size() / 4)
	var n: int = samples.size() - fade
	for i: int in fade:
		var t: float = float(i) / float(fade)
		samples[i] = lerpf(samples[n + i], samples[i], t)
	samples.resize(n)
	return samples


## A silent-by-default looping stream from a buffer. All the beds share this shape.
static func to_loop_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var w: AudioStreamWAV = SfxBank.to_stream(samples)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = samples.size()
	return w


## The factory's sub: one second of low drone at 55 and 110 Hz over a whisper of noise floor. The tones
## close on exact cycles across a second; noise does not, so the noise is loop-closed FIRST and the
## tones go on after, where the arithmetic still holds.
static func hum(rng: SplitRng) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(padded(1))
	var lp: float = 0.0
	for i: int in out.size():
		lp += 0.05 * (_noise(rng) - lp)
		out[i] = lp * 0.20
	out = loopify(out)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		out[i] += sin(TAU * 55.0 * t) * 0.30 + sin(TAU * 110.0 * t) * 0.15
	return out


## The factory's middle: belts and gearing. A 110.5 Hz shaft note half a hertz off the sub's 110 so the
## pair throbs once every two seconds; 165.5 and 221 over it, a belt slapping at 2.5 Hz, a gear train
## ticking twelve teeth a second. 165.5 is a flat fifth so every partial closes on whole cycles across
## exactly two seconds; the tooth is phase-offset so none lands on the loop point.
static func hum_mid(rng: SplitRng) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(padded(2))
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in out.size():
		lp += 0.30 * (_noise(rng) - lp)
		slow += 0.05 * (lp - slow)
		out[i] = (lp - slow) * 0.14
	out = loopify(out)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var shaft: float = sin(TAU * 110.5 * t) * 0.26 + sin(TAU * 165.5 * t) * 0.13 + sin(TAU * 221.0 * t) * 0.07
		var belt: float = 0.82 + 0.18 * sin(TAU * 2.5 * t)
		var tooth: float = fmod(t * 12.0 + 0.37, 1.0)
		out[i] = shaft * belt + out[i] * (0.6 + 3.4 * pow(maxf(0.0, 1.0 - tooth * 6.0), 3.0))
	return out


## The factory's top: the clatter from across a busy floor. Band-passed noise gated by three tick rates
## that share no beat inside the loop (5, 7 and 11 a second), phase-offset so they never strike
## together: several machines rather than one metronome. The quietest bed, heard when it stops.
static func hum_top(rng: SplitRng) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(padded(2))
	var lp: float = 0.0
	var slow: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		lp += 0.58 * (_noise(rng) - lp)
		slow += 0.14 * (lp - slow)
		var gate: float = 0.0
		for spec: Vector2 in [Vector2(5.0, 0.13), Vector2(7.0, 0.46), Vector2(11.0, 0.79)]:
			gate += pow(maxf(0.0, 1.0 - fmod(t * spec.x + spec.y, 1.0) * 8.0), 2.6) * (11.0 / spec.x) * 0.30
		out[i] = (lp - slow) * (0.10 + gate) * 1.5
	return loopify(out)


## Surface wind: gusting noise. Two chained one-pole lowpasses roll it down to the breathy low-mids,
## under a slow two-sine gust LFO.
static func wind(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp1 += 0.12 * (_noise(rng) - lp1)
		lp2 += 0.20 * (lp1 - lp2)
		var gust: float = 0.6 + 0.25 * sin(TAU * 0.13 * t) + 0.15 * sin(TAU * 0.071 * t + 1.7)
		out[i] = lp2 * gust * 2.6
	return loopify(out)


## Deep cave-air: a sub drone at 38 Hz with its fifth at 57, over a whisper of brownish noise under a
## very slow swell so the dark seems to breathe.
static func cave(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp += 0.03 * (_noise(rng) - lp)
		var swell: float = 0.75 + 0.25 * sin(TAU * 0.09 * t)
		out[i] = (sin(TAU * 38.0 * t) * 0.30 + sin(TAU * 57.0 * t) * 0.16 + lp * 0.5) * swell
	return loopify(out)


## The rush bed: brighter and thinner than the surface wind, so the two never read as one sound. A
## gentler low-pass keeps the hiss, a high-pass cuts the rumble, a faint whistle rides on top.
static func rush(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(2)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var hp: float = 0.0
	var prev: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp += 0.42 * (_noise(rng) - lp)
		hp = 0.86 * (hp + lp - prev)
		prev = lp
		var whistle: float = 0.14 * sin(TAU * 1180.0 * t) * (0.5 + 0.5 * sin(TAU * 0.9 * t))
		out[i] = (hp * 1.9 + whistle) * (0.85 + 0.15 * sin(TAU * 0.31 * t))
	return loopify(out)


## Water pour: a soft continuous trickle. One one-pole lowpass minus a slower one keeps the airy
## mid-highs and drops the rumble; a 3 and 7 Hz flutter shimmers the sheet instead of hissing.
static func pour(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp_fast: float = 0.0
	var lp_slow: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		lp_fast += 0.55 * (_noise(rng) - lp_fast)
		lp_slow += 0.06 * (lp_fast - lp_slow)
		var flutter: float = 0.72 + 0.20 * sin(TAU * 3.1 * t) + 0.08 * sin(TAU * 7.3 * t + 0.9)
		out[i] = (lp_fast - lp_slow) * flutter * 1.9
	return loopify(out)


## Pump drain: a wet mechanical gurgle. A sub at 62 Hz with its fifth at 93, pulsing on a 1.7 Hz drain
## rhythm with a bubbly noise burst at the head of each pulse as water sucks through the tube.
static func pump(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var pulse: float = fmod(t * 1.7, 1.0)
		var chug: float = pow(maxf(0.0, 1.0 - pulse * 1.6), 1.8)
		var sub: float = sin(TAU * 62.0 * t) * 0.30 + sin(TAU * 93.0 * t) * 0.16
		lp += 0.22 * (_noise(rng) - lp)
		var burst: float = lp * pow(maxf(0.0, 1.0 - pulse * 3.0), 2.0) * 0.9
		out[i] = (sub * (0.35 + 0.65 * chug) + burst) * 1.4
	return loopify(out)


## The winch drum: a geared motor under a pawl clicking over ratchet teeth, nineteen a second. The
## clicks are what make it read as a winch rather than as the factory hum.
static func winch(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(2)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var motor: float = sin(TAU * 88.0 * t) * 0.30 + sin(TAU * 132.0 * t) * 0.14
		var tooth: float = fmod(t * 19.0, 1.0)
		lp += 0.55 * (_noise(rng) - lp)
		var click: float = lp * pow(maxf(0.0, 1.0 - tooth * 9.0), 2.2) * 0.85
		out[i] = (motor + click) * 1.15
	return loopify(out)


## The line under load: two fibre tones at 143 and 219 Hz on a slow wow over a heavily filtered
## rustle -- hemp, not metal. The driver rides its level and pitch as the rope takes the body's weight.
static func creak(rng: SplitRng) -> PackedFloat32Array:
	var n: int = padded(3)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var wow: float = 1.0 + 0.06 * sin(TAU * 0.37 * t) + 0.03 * sin(TAU * 1.13 * t)
		var fibre: float = sin(TAU * 143.0 * wow * t) * 0.26 + sin(TAU * 219.0 * wow * t) * 0.11
		lp += 0.06 * (_noise(rng) - lp)
		out[i] = (fibre + lp * 2.4) * 1.1
	return loopify(out)
