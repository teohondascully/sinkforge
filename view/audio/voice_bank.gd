class_name VoiceBank
extends RefCounted

## THE ONE-SHOT VOICES (A' step 6f (ii), D0367): legacy `scenes/sfx.gd`'s short sounds, verbatim in
## their arithmetic on the split RNG, each with the caller it has in this build named beside it. Every
## generator returns float samples and the bank's own `norm` pins the peak, for legacy's reason: four
## takes of one voice off four stretches of noise land up to 4 dB apart, and a footstep that bounces in
## level every stride reads as a bug. `SfxBank` keeps the hollow ring, the breach and the strike family;
## this file is the rest of the library that has a verb to fire it.
##
## Not here, and why: `ding` and `chime` (craft, research and sonar -- no verb of any of the three
## exists), `boom` (the descent breach, dead by the plan), `skid` (steel glancing off rock it cannot
## bite: the sim has no cannot-bite state, so nothing could fire it).

const RATE: int = SfxBank.RATE

## Name -> stated length in seconds, the one thing a generator gets wrong silently. The suite walks it.
const SECONDS: Dictionary = {
	&"step": 0.055, &"step_rock": 0.042, &"step_wood": 0.060, &"crunch": 0.11, &"thump": 0.16,
	&"clunk": 0.12, &"pop": 0.07, &"drip": 0.34, &"ignite": 0.95, &"vein": 0.38, &"catch": 0.20,
}

## The voices that fire often enough to need a bank of separate renders: pitch jitter alone cannot hide
## repetition, because the noise grain is identical every time and the ear locks onto the grain.
const GRAINED: Array[StringName] = [&"crunch", &"step", &"step_rock", &"step_wood"]
const GRAINS: int = 4


static func _noise(rng: SplitRng) -> float:
	return rng.next_float() * 2.0 - 1.0


static func generate(name: StringName, rng: SplitRng) -> PackedFloat32Array:
	match name:
		&"step": return step(rng)
		&"step_rock": return step_rock(rng)
		&"step_wood": return step_wood(rng)
		&"crunch": return crunch(rng)
		&"thump": return thump(rng)
		&"clunk": return clunk(rng)
		&"pop": return pop()
		&"drip": return drip()
		&"ignite": return ignite(rng)
		&"vein": return vein(rng)
		&"catch": return catch(rng)
	return PackedFloat32Array()


## Scale a buffer so its loudest sample lands exactly on `peak`; a silent buffer is returned as is.
static func norm(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var most: float = SfxBank.peak(samples)
	if most <= 1e-6:
		return samples
	var gain: float = peak / most
	for i: int in samples.size():
		samples[i] *= gain
	return samples


static func _buf(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(float(RATE) * seconds))
	return out


## Footstep on soft ground: a very short noise burst low-passed hard over a small body thud. Quiet and
## dull because it fires several times a second. The grit arrives with an edge and dulls as the boot
## settles, a contour rather than a lucky draw.
static func step(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"step"])
	var n: int = out.size()
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		lp += lerpf(0.30, 0.06, pow(t, 0.55)) * (_noise(rng) - lp)
		phase += TAU * lerpf(150.0, 78.0, t) / float(RATE)
		out[i] = (lp * 1.7 + sin(phase) * 0.5) * pow(1.0 - t, 2.8)
	return norm(out, 0.88)


## The boot on rock: shorter and drier, a heel click where the thud went.
static func step_rock(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"step_rock"])
	var n: int = out.size()
	var lp: float = 0.0
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		lp += 0.34 * (_noise(rng) - lp)
		phase += TAU * lerpf(255.0, 150.0, t) / float(RATE)
		out[i] = (lp * 1.25 + sin(phase) * 0.26) * pow(1.0 - t, 3.4)
	return norm(out, 0.80)


## The boot on wood: a hollow board answering underfoot, the only footstep with a note in it.
static func step_wood(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"step_wood"])
	var n: int = out.size()
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.22 * (_noise(rng) - lp)
		out[i] = lp * 0.9 * pow(1.0 - t, 3.0) + sin(TAU * 172.0 * s) * exp(-s * 42.0) * 0.44 \
			+ sin(TAU * 258.0 * s) * exp(-s * 58.0) * 0.18
	return norm(out, 0.84)


## Mining crunch: stone, the plain fracture and the head of the strike family. A decaying noise burst
## through a one-pole lowpass; under it a short low body, gone in 25 ms of 110, so the fracture still
## arrives first. The voice an unmapped material falls back to.
static func crunch(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"crunch"])
	var n: int = out.size()
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		var s: float = float(i) / float(RATE)
		lp += 0.30 * (_noise(rng) - lp)
		out[i] = lp * pow(1.0 - t, 2.2) * 1.5 + sin(TAU * 74.0 * s) * exp(-s * 66.0) * 0.52
	return norm(out, 0.92)


## Break thump: a sine gliding 120 to 55 Hz with a click of noise on the front, the block giving way.
## Also the landing, pitched by impact.
static func thump(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"thump"])
	var n: int = out.size()
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(120.0, 55.0, t) / float(RATE)
		var s: float = sin(phase) * pow(1.0 - t, 1.4) * 0.9
		if i < RATE / 200:
			s += _noise(rng) * 0.5
		out[i] = s
	return out


## Machine clunk: a dull metallic knock, a low tone plus an odd harmonic plus a breath of noise. A
## machine set down.
static func clunk(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"clunk"])
	var n: int = out.size()
	for i: int in n:
		var t: float = float(i) / float(n)
		var w: float = TAU * float(i) / float(RATE)
		out[i] = (sin(w * 96.0) * 0.6 + sin(w * 288.0) * 0.25 + _noise(rng) * 0.08) * pow(1.0 - t, 1.8)
	return out


## Collect pop: a quick upward sine sweep. The pack gaining, a machine picked up, the line cut.
static func pop() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"pop"])
	var n: int = out.size()
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(350.0, 950.0, t) / float(RATE)
		out[i] = sin(phase) * (1.0 - t) * 0.55
	return out


## A cave drip: a fast pitch-falling blip and its fainter echo, water finding the floor in the dark.
static func drip() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"drip"])
	var phase: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		phase += TAU * lerpf(1500.0, 620.0, clampf(t / 0.05, 0.0, 1.0)) / float(RATE)
		var s: float = sin(phase) * exp(-t * 26.0) * 0.7
		if t > 0.14:
			var te: float = t - 0.14
			s += sin(TAU * 900.0 * te) * exp(-te * 30.0) * 0.22
		out[i] = s
	return out


## The line runs: the factory has started working without you. A low spin-up sweeping 52 to 124 Hz
## that fades in, a knock of engagement, and a major triad locking in note by note under a long tail.
static func ignite(rng: SplitRng) -> PackedFloat32Array:
	const LOCK: float = 0.34
	var out: PackedFloat32Array = _buf(SECONDS[&"ignite"])
	var n: int = out.size()
	var phase: float = 0.0
	var lp: float = 0.0
	var notes: Array = [131.0, 262.0, 330.0, 392.0, 523.0]
	for i: int in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(52.0, 124.0, minf(t / 0.55, 1.0)) / float(RATE)
		var spin: float = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.30, 0.75, t))
		out[i] = (sin(phase) + sin(phase * 2.0) * 0.28) * spin * 0.34
		var k: float = (t - LOCK) * 26.0
		if k >= 0.0 and k < 1.0:
			lp += 0.30 * (_noise(rng) - lp)
			out[i] += lp * pow(1.0 - k, 2.0) * 0.55
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
static func vein(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"vein"])
	var n: int = out.size()
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		var strike: float = _noise(rng) * pow(maxf(0.0, 1.0 - u * 22.0), 2.0) * 0.30
		var body: float = (sin(TAU * 587.0 * t) + sin(TAU * 593.0 * t) * 0.85) * exp(-t * 9.0) * 0.26
		out[i] = strike + body + sin(TAU * 1760.0 * t) * exp(-t * 15.0) * 0.10
	return out


## The catch: rope coming down onto a rock edge and biting there. Soft against hard: a dull woody knock
## with a fibre rasp that swells before it decays, low-passed far harder than the crunch and twice as
## long, so the two differ in attack as well as in colour.
static func catch(rng: SplitRng) -> PackedFloat32Array:
	var out: PackedFloat32Array = _buf(SECONDS[&"catch"])
	var n: int = out.size()
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(n)
		lp += 0.055 * (_noise(rng) - lp)
		var swell: float = pow(sin(PI * clampf(u * 1.35, 0.0, 1.0)), 1.4)
		var knock: float = (sin(TAU * 165.0 * t) + sin(TAU * 244.0 * t) * 0.45) * exp(-t * 21.0) * 0.42
		out[i] = (lp * 5.5 * swell + knock) * 1.1
	return out
