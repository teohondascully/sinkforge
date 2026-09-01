extends "res://tests/test_base.gd"

## `view/audio/sfx_bank.gd` — the hollow ring and the breach (D0296, LEGACY_GAP T1 #6 / Lane G).
##
## **THE HARD PART OF TESTING A SYNTHESISED SOUND is that almost every assertion you can write is true of
## any noise.** "It produced samples", "it is not silent", "it does not clip" — a `randf()` loop passes
## all three. So the suite is built around the property that actually distinguishes these two voices from
## each other and from noise: the ring is TONAL at three stated frequencies, and the breach, which legacy
## calls "the answer to the hollow ring", is deliberately BROADBAND. Each is the other's control.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_sfx_bank.gd


func _initialize() -> void:
	_test_both_voices_are_the_stated_length_and_are_not_silent()
	_test_both_decay_rather_than_ringing_forever()
	_test_the_ring_is_tonal_on_legacys_stretched_series()
	_test_the_breach_is_broadband_where_the_ring_is_tonal()
	_test_the_same_seed_makes_the_same_sound()
	_test_the_limiter_is_a_soft_knee_and_never_reaches_full_scale()
	_test_the_stream_conversion_clamps_rather_than_wrapping()
	_test_a_bigger_space_answers_lower_and_louder()
	_finish("sfx_bank")


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("sfx")


## Length is the one thing a generator gets wrong silently — a buffer sized from the wrong constant plays
## at the wrong length and sounds like a shorter version of itself. Derived from the constants rather than
## written down, so changing a duration fails here and nowhere else.
func _test_both_voices_are_the_stated_length_and_are_not_silent() -> void:
	var ring: PackedFloat32Array = SfxBank.hollow(_rng(1))
	var breach: PackedFloat32Array = SfxBank.breach(_rng(1))
	_check(ring.size() == int(float(SfxBank.RATE) * SfxBank.HOLLOW_SECONDS),
		"the ring is %.2f s at %d Hz (%d samples)" % [SfxBank.HOLLOW_SECONDS, SfxBank.RATE, ring.size()])
	_check(breach.size() == int(float(SfxBank.RATE) * SfxBank.BREACH_SECONDS),
		"the breach is %.2f s (%d samples)" % [SfxBank.BREACH_SECONDS, breach.size()])
	_check(breach.size() > ring.size(),
		"and the breach is the longer of the two -- rock giving way takes longer than rock answering")
	_check(SfxBank.peak(ring) > 0.05 and SfxBank.peak(breach) > 0.05,
		"neither is silence (peaks %.3f, %.3f)" % [SfxBank.peak(ring), SfxBank.peak(breach)])
	# THE BREACH OVERDRIVES ON PURPOSE and the limiter is what catches it -- see `SfxBank.limited`. So the
	# claim is not "it stays under 1.0", which would be false and which the first version of this row
	# asserted; it is that the overdrive is MODEST (a voice peaking at 10 would be a defect the limiter
	# would turn into a square wave) and that the ring, which is not built to overdrive, does not.
	_check(SfxBank.peak(ring) <= 1.0,
		"the ring stays inside full scale (%.3f)" % SfxBank.peak(ring))
	_check(SfxBank.peak(breach) > 1.0 and SfxBank.peak(breach) < 1.5,
		"and the breach overdrives into the limiter, modestly and by design (%.3f) -- `lp * 1.5` with a "
		% SfxBank.peak(breach) + "noise source reaching full scale is what does it")


## A sound that never decayed would pass every peak check and ring under the whole game. Measured as an
## RMS ratio between the first and last tenth, because a peak says the sound STARTED and only an energy
## comparison says it ended.
func _test_both_decay_rather_than_ringing_forever() -> void:
	for named: Array in [["ring", SfxBank.hollow(_rng(2))], ["breach", SfxBank.breach(_rng(2))]]:
		var buf: PackedFloat32Array = named[1]
		var tenth: int = buf.size() / 10
		var head: float = SfxBank.rms(buf, 0, tenth)
		var tail: float = SfxBank.rms(buf, buf.size() - tenth, buf.size())
		_check(head > 0.0, "sanity: the %s has energy at its start (%.5f)" % [named[0], head])
		_check(tail < head * 0.25,
			"the %s's last tenth is far quieter than its first (%.5f vs %.5f) -- it ENDS"
			% [named[0], tail, head])


## LEGACY'S OWN DESIGN NOTE, ASSERTED: "96, 154 and 233 Hz sit on a stretched series, so this reads as an
## empty space and not as a note." Two claims in one sentence, and both are checked — the partials are
## really there, and they are really NOT a harmonic series, which is what would make it a chime.
func _test_the_ring_is_tonal_on_legacys_stretched_series() -> void:
	var ring: PackedFloat32Array = SfxBank.hollow(_rng(3))
	# A frequency the design does not name, sitting between two that it does, as the floor to beat. Without
	# it "there is energy at 96 Hz" is true of any low-passed noise.
	var between: float = 125.0
	var floor_mag: float = SfxBank.tone_magnitude(ring, between)
	var weakest: float = 1.0e9
	for hz: float in SfxBank.HOLLOW_PARTIALS:
		weakest = minf(weakest, SfxBank.tone_magnitude(ring, hz))
	_check(floor_mag > 0.0, "sanity: the off-tone probe reads something at all (%.6f)" % floor_mag)
	_check(weakest > floor_mag * 2.0,
		"every stated partial beats an unstated frequency between them by 2x (weakest %.6f vs %.6f)"
		% [weakest, floor_mag])
	# NOT A HARMONIC SERIES. 154/96 is 1.60 and 233/154 is 1.51; a harmonic series would put both ratios
	# at whole-number steps off the fundamental. This is what "stretched" means and it is the difference
	# between a room and a bell.
	var first: float = SfxBank.HOLLOW_PARTIALS[1] / SfxBank.HOLLOW_PARTIALS[0]
	var second: float = SfxBank.HOLLOW_PARTIALS[2] / SfxBank.HOLLOW_PARTIALS[1]
	_check(absf(first - second) > 0.03,
		"and the two partial ratios differ (%.3f vs %.3f) -- a stretched series, not a harmonic one"
		% [first, second])
	_check(absf(SfxBank.HOLLOW_PARTIALS[1] - SfxBank.HOLLOW_PARTIALS[0] * 2.0) > 20.0,
		"the second partial is not the octave of the first (%.0f vs %.0f Hz), which is what would make "
		% [SfxBank.HOLLOW_PARTIALS[1], SfxBank.HOLLOW_PARTIALS[0] * 2.0] + "it read as a note")


## THE PAIR. Legacy calls the breach "the answer to the hollow ring" and builds it the opposite way: air
## rather than rock, broadband rather than tonal. Asserted as a comparison BETWEEN the two voices rather
## than as a threshold on either, so it measures the difference legacy designed and not a level.
func _test_the_breach_is_broadband_where_the_ring_is_tonal() -> void:
	var ring: PackedFloat32Array = SfxBank.hollow(_rng(4))
	var breach: PackedFloat32Array = SfxBank.breach(_rng(4))
	var ring_peak: float = _tonality(ring)
	var breach_peak: float = _tonality(breach)
	_check(ring_peak > breach_peak,
		"the ring's energy concentrates on its partials more than the breach's does (%.2fx vs %.2fx of "
		% [ring_peak, breach_peak] + "their own off-tone floors)")
	_check(breach_peak < 2.0,
		"and the breach really is broadband (%.2fx) rather than merely quieter -- it is the ANSWER to the "
		% breach_peak + "ring, not a duller copy of it")


## How much a buffer's energy concentrates on the ring's partials, as a multiple of an unstated frequency
## between them. Dimensionless, so two voices at different levels are comparable.
func _tonality(buf: PackedFloat32Array) -> float:
	var floor_mag: float = maxf(SfxBank.tone_magnitude(buf, 125.0), 1.0e-9)
	var strongest: float = 0.0
	for hz: float in SfxBank.HOLLOW_PARTIALS:
		strongest = maxf(strongest, SfxBank.tone_magnitude(buf, hz))
	return strongest / floor_mag


## Deterministic in the seed, so the assertions above measure the voice rather than one draw of it -- and
## paired with the opposite property, or a generator that ignored its RNG entirely would pass.
func _test_the_same_seed_makes_the_same_sound() -> void:
	var a: PackedFloat32Array = SfxBank.hollow(_rng(9))
	var b: PackedFloat32Array = SfxBank.hollow(_rng(9))
	var c: PackedFloat32Array = SfxBank.hollow(_rng(10))
	var same_differ: int = 0
	var seed_differ: int = 0
	for i: int in a.size():
		if not is_equal_approx(a[i], b[i]):
			same_differ += 1
		if not is_equal_approx(a[i], c[i]):
			seed_differ += 1
	_check_over(a.size(), same_differ == 0,
		"the same seed produces an identical buffer (%d of %d samples differ)" % [same_differ, a.size()])
	_check(seed_differ > a.size() / 10,
		"CONTROL: a different seed produces a different one (%d of %d differ) -- without this the row "
		% [seed_differ, a.size()] + "above passes on a generator that ignores its RNG")


## The one place a float buffer meets an engine type, and the one place a sample can wrap. A value past
## 1.0 encoded without clamping becomes a large NEGATIVE 16-bit sample -- an audible crack, and the
## loudest thing in the mix.
func _test_the_stream_conversion_clamps_rather_than_wrapping() -> void:
	var hot := PackedFloat32Array([0.0, 1.0, 2.5, -2.5, 0.5])
	var wav: AudioStreamWAV = SfxBank.to_stream(hot)
	_check(wav != null and wav.mix_rate == SfxBank.RATE,
		"the stream carries the bank's own sample rate (%d)" % wav.mix_rate)
	_check(wav.data.size() == hot.size() * 2, "and two bytes per sample (%d)" % wav.data.size())
	var over: int = wav.data.decode_s16(2 * 2)
	var under: int = wav.data.decode_s16(3 * 2)
	_check(over > 0 and under < 0,
		"a sample of 2.5 stays POSITIVE and -2.5 stays negative (%d, %d) -- wrapping would put them on "
		% [over, under] + "the wrong side of zero, which is the audible crack")
	_check(over < 32767 and under > -32767,
		"and neither reaches full scale (%d, %d), because the knee's asymptote is %.3f" % [over, under, SfxBank.CEIL])
	_check(wav.data.decode_s16(0) == 0, "and silence stays silence (%d)" % wav.data.decode_s16(0))


## The knee, asserted at stated inputs rather than through a generated sound — it is the only
## nonlinearity in the chain, and a sound-level assertion could not tell a soft knee from a hard clamp
## because the PEAK is the same under both. That is exactly how the first version of this file shipped a
## clamp where legacy has a limiter.
func _test_the_limiter_is_a_soft_knee_and_never_reaches_full_scale() -> void:
	_check(is_equal_approx(SfxBank.limited(0.5), 0.5) and is_equal_approx(SfxBank.limited(-0.5), -0.5),
		"below the knee a sample passes through untouched (%.4f)" % SfxBank.limited(0.5))
	_check(is_equal_approx(SfxBank.limited(SfxBank.KNEE), SfxBank.KNEE),
		"and it is continuous AT the knee (%.4f vs %.4f) -- a discontinuity here would be a click on "
		% [SfxBank.limited(SfxBank.KNEE), SfxBank.KNEE] + "every sample that crossed it")
	# SOFT, not hard. A clamp returns exactly the ceiling for every input above it; a knee keeps ordering,
	# so a louder input is still louder after limiting. That is the property, and it is what a peak
	# measurement cannot see.
	var a: float = SfxBank.limited(1.0)
	var b: float = SfxBank.limited(1.4)
	_check(a > SfxBank.KNEE and b > a,
		"above the knee it compresses but keeps ORDER (%.4f < %.4f) -- a hard clamp returns the same "
		% [a, b] + "value for both, which is the flat top")
	# The claim legacy actually makes is "nothing ever reaches FULL SCALE", and the ceiling is how. Written
	# as `<= CEIL` rather than `<`: `tanh` saturates to exactly 1.0 in floating point, so a loud enough
	# input lands ON the asymptote. Asserting strict inequality would have been a claim about float
	# precision dressed up as one about the limiter.
	_check(b <= SfxBank.CEIL and SfxBank.limited(100.0) <= SfxBank.CEIL,
		"and nothing ever exceeds the ceiling, however loud (%.4f, %.4f of %.3f)"
		% [b, SfxBank.limited(100.0), SfxBank.CEIL])
	_check(SfxBank.CEIL < 1.0,
		"and the ceiling itself is below full scale (%.3f), which is what legacy's asymptote is FOR"
		% SfxBank.CEIL)
	_check(is_equal_approx(SfxBank.limited(-1.4), -b),
		"and it is symmetric about zero (%.4f vs %.4f) -- an asymmetric limiter adds a DC offset"
		% [SfxBank.limited(-1.4), -b])


## `view/audio/sfx.gd`'s reading-to-voice mapping (D0296). Legacy's two lines at `main.gd:1602-1603`, and
## the claim they encode is a physical one: a bigger space answers LOWER and LOUDER. Asserted as that
## relationship over the whole range rather than at the two endpoints, because a mapping that was
## monotone at the ends and flat in the middle would satisfy a two-point check and carry no crescendo.
func _test_a_bigger_space_answers_lower_and_louder() -> void:
	var last_pitch: float = 999.0
	var last_db: float = -999.0
	var steps: int = 20
	var pitch_falls: bool = true
	var db_rises: bool = true
	for i: int in steps + 1:
		var reading: int = Interface.HOLLOW_FULL * i / steps
		var v: Dictionary = Sfx.voice_for_hollow(reading, Interface.HOLLOW_FULL)
		if float(v["pitch"]) > last_pitch:
			pitch_falls = false
		if float(v["db"]) < last_db:
			db_rises = false
		last_pitch = v["pitch"]
		last_db = v["db"]
	_check_over(steps + 1, pitch_falls, "the pitch never rises as the reading climbs")
	_check_over(steps + 1, db_rises, "and the volume never falls")
	var solid: Dictionary = Sfx.voice_for_hollow(0, Interface.HOLLOW_FULL)
	var open_space: Dictionary = Sfx.voice_for_hollow(Interface.HOLLOW_FULL, Interface.HOLLOW_FULL)
	_check(float(open_space["pitch"]) < float(solid["pitch"])
			and float(open_space["db"]) > float(solid["db"]),
		"and across the whole range a void answers lower (%.3f vs %.3f) and louder (%.1f vs %.1f dB)"
		% [open_space["pitch"], solid["pitch"], open_space["db"], solid["db"]])
	# The clamps are legacy's and they bound BOTH ends: a reading past full scale must not invert the
	# pitch, and a division by a zero scale must not produce a NaN that silently mutes the voice.
	var over: Dictionary = Sfx.voice_for_hollow(Interface.HOLLOW_FULL * 4, Interface.HOLLOW_FULL)
	_check(is_equal_approx(over["pitch"], open_space["pitch"]),
		"a reading past full scale clamps rather than inverting the pitch (%.3f)" % over["pitch"])
	var degenerate: Dictionary = Sfx.voice_for_hollow(500, 0)
	_check(degenerate["pitch"] >= Sfx.PITCH_MIN and degenerate["pitch"] <= Sfx.PITCH_MAX,
		"and a zero scale still gives a usable pitch (%.3f) rather than a NaN" % degenerate["pitch"])
