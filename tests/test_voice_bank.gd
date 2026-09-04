extends "res://tests/test_base.gd"
## D0367. `view/audio/voice_bank.gd`, the eleven one-shots. Per `test_sfx_bank`'s rule that "it made a
## noise" is true of any noise, each claim is the property that makes the voice ITSELF: the stated
## length, the pinned peak on the normed voices (four takes that bounce in level read as a bug), the
## grains differing while sharing that peak, the vein's two-tone beat, the pop sweeping UP, the drip's
## echo arriving after its blip, the catch duller and longer than the crunch, one seed one voice.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_voice_bank.gd


func _initialize() -> void:
	_test_every_voice_is_its_stated_length_and_not_silent()
	_test_the_normed_voices_land_on_their_pinned_peaks()
	_test_grains_differ_and_share_the_peak()
	_test_the_vein_beats_between_its_two_tones()
	_test_the_pop_sweeps_up()
	_test_the_drip_echoes()
	_test_the_catch_is_duller_and_longer_than_the_crunch()
	_test_one_seed_makes_one_voice()
	_finish("voice_bank")


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("voices")


func _test_every_voice_is_its_stated_length_and_not_silent() -> void:
	for name: StringName in Ordering.ids(VoiceBank.SECONDS.keys()):
		var buf: PackedFloat32Array = VoiceBank.generate(name, _rng(1))
		var want: int = int(float(VoiceBank.RATE) * float(VoiceBank.SECONDS[name]))
		_check(buf.size() == want, "%s is %.3f s (%d of %d samples)" % [name, float(VoiceBank.SECONDS[name]), buf.size(), want])
		_check(SfxBank.peak(buf) > 0.05, "%s is not silence (%.3f)" % [name, SfxBank.peak(buf)])
	_check(VoiceBank.SECONDS.size() == 11, "eleven voices (%d)" % VoiceBank.SECONDS.size())
	_check(VoiceBank.generate(&"no_such_voice", _rng(1)).is_empty(), "an unknown name is an empty buffer")


func _test_the_normed_voices_land_on_their_pinned_peaks() -> void:
	for spec: Array in [[&"step", 0.88], [&"step_rock", 0.80], [&"step_wood", 0.84], [&"crunch", 0.92]]:
		var p: float = SfxBank.peak(VoiceBank.generate(spec[0], _rng(2)))
		_check(is_equal_approx(p, spec[1]), "%s peaks at exactly %.2f (%.4f)" % [spec[0], spec[1], p])


func _test_grains_differ_and_share_the_peak() -> void:
	var rng: SplitRng = _rng(3)
	var a: PackedFloat32Array = VoiceBank.crunch(rng)
	var b: PackedFloat32Array = VoiceBank.crunch(rng)
	_check(a != b, "two takes off one stream are different renders")
	_check(is_equal_approx(SfxBank.peak(a), SfxBank.peak(b)), "and they share the pinned peak (%.4f, %.4f)" % [SfxBank.peak(a), SfxBank.peak(b)])
	_check(VoiceBank.GRAINED.size() == 4 and VoiceBank.GRAINS == 4, "four grained voices at four takes each")


func _test_the_vein_beats_between_its_two_tones() -> void:
	var v: PackedFloat32Array = VoiceBank.vein(_rng(4))
	var at_587: float = SfxBank.tone_magnitude(v, 587.0)
	var at_593: float = SfxBank.tone_magnitude(v, 593.0)
	var off: float = SfxBank.tone_magnitude(v, 700.0)
	_check(at_587 > off * 3.0 and at_593 > off * 3.0, "587 and 593 Hz both stand 3x over 700 (%.4f, %.4f vs %.4f)" % [at_587, at_593, off])
	# The beat: with tones 6 Hz apart, the envelope over the first quarter second dips and rises. Measured
	# as the RMS over consecutive 1/12 s windows not being monotone in the first three.
	var w: int = VoiceBank.RATE / 12
	var r0: float = SfxBank.rms(v, 0, w)
	var r1: float = SfxBank.rms(v, w, 2 * w)
	var r2: float = SfxBank.rms(v, 2 * w, 3 * w)
	_check(r0 > r1 and r1 > r2, "control: the struck bronze decays across the first quarter second (%.3f > %.3f > %.3f)" % [r0, r1, r2])


func _zero_crossings(buf: PackedFloat32Array, from: int, to: int) -> int:
	var n: int = 0
	for i: int in range(maxi(from, 1), mini(to, buf.size())):
		if (buf[i] >= 0.0) != (buf[i - 1] >= 0.0):
			n += 1
	return n


func _test_the_pop_sweeps_up() -> void:
	var p: PackedFloat32Array = VoiceBank.pop()
	var half: int = p.size() / 2
	var early: int = _zero_crossings(p, 0, half)
	var late: int = _zero_crossings(p, half, p.size())
	_check(late > early, "the second half crosses zero more often than the first: the sweep goes UP (%d < %d)" % [early, late])


func _test_the_drip_echoes() -> void:
	var d: PackedFloat32Array = VoiceBank.drip()
	var echo_at: int = int(0.14 * float(VoiceBank.RATE))
	var before: float = SfxBank.rms(d, echo_at - 400, echo_at)
	var after: float = SfxBank.rms(d, echo_at, echo_at + 400)
	_check(after > before * 1.5, "the echo arrives at 0.14 s: energy jumps there (%.4f -> %.4f)" % [before, after])


func _test_the_catch_is_duller_and_longer_than_the_crunch() -> void:
	var catch: PackedFloat32Array = VoiceBank.catch(_rng(5))
	var crunch: PackedFloat32Array = VoiceBank.crunch(_rng(5))
	_check(catch.size() > crunch.size() * 1.5, "the catch runs longer than the crunch (%d vs %d samples)" % [catch.size(), crunch.size()])
	var catch_hi: float = SfxBank.tone_magnitude(catch, 3000.0) / maxf(1e-6, SfxBank.rms(catch, 0, catch.size()))
	var crunch_hi: float = SfxBank.tone_magnitude(crunch, 3000.0) / maxf(1e-6, SfxBank.rms(crunch, 0, crunch.size()))
	_check(catch_hi < crunch_hi, "and carries less at 3 kHz relative to its level: hemp on stone, not stone breaking (%.4f vs %.4f)" % [catch_hi, crunch_hi])


func _test_one_seed_makes_one_voice() -> void:
	_check(VoiceBank.thump(_rng(8)) == VoiceBank.thump(_rng(8)), "the same seed makes the same thump")
	_check(VoiceBank.thump(_rng(8)) != VoiceBank.thump(_rng(9)), "control: another seed does not")
