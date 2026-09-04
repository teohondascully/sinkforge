extends "res://tests/test_base.gd"
## D0366. `view/audio/bed_bank.gd`, the ten looping beds. As `test_sfx_bank` says, almost every assertion
## about a synthesized sound is true of any noise, so the claims here are the ones a bed can fail
## silently: it is exactly its stated length once the seam is closed (a bed at the wrong length loops at
## the wrong period), the seam IS closed (a click once a second under a bed that never stops), the tonal
## beds carry their stated partials and the broadband beds do not (each the other's control), the rush
## is brighter than the wind (the one reason two wind-like beds exist), and one seed makes one bed.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_bed_bank.gd


func _initialize() -> void:
	_test_every_bed_is_its_stated_length_and_not_silent()
	_test_loopify_blends_the_tail_into_the_head()
	_test_the_tonal_beds_carry_their_partials()
	_test_the_broadband_beds_do_not()
	_test_the_rush_is_brighter_than_the_wind()
	_test_one_seed_makes_one_bed()
	_test_the_loop_stream_loops()
	_finish("bed_bank")


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("beds")


func _test_every_bed_is_its_stated_length_and_not_silent() -> void:
	for name: StringName in Ordering.ids(BedBank.SECONDS.keys()):
		var buf: PackedFloat32Array = BedBank.generate(name, _rng(1))
		var want: int = int(float(BedBank.RATE) * float(BedBank.SECONDS[name]))
		_check(buf.size() == want, "%s closes at exactly %.1f s (%d of %d samples)" % [name, float(BedBank.SECONDS[name]), buf.size(), want])
		_check(SfxBank.peak(buf) > 0.05, "%s is not silence (peak %.3f)" % [name, SfxBank.peak(buf)])
	_check(BedBank.SECONDS.size() == 10, "ten beds in the table (%d)" % BedBank.SECONDS.size())


func _test_loopify_blends_the_tail_into_the_head() -> void:
	var ramp := PackedFloat32Array()
	ramp.resize(BedBank.RATE)
	for i: int in ramp.size():
		ramp[i] = float(i) / float(ramp.size())
	var fade: int = int(float(BedBank.RATE) * BedBank.LOOP_FADE_SECONDS)
	var closed: PackedFloat32Array = BedBank.loopify(ramp.duplicate())
	_check(closed.size() == ramp.size() - fade, "the seam eats exactly the fade (%d = %d - %d)" % [closed.size(), ramp.size(), fade])
	_check(is_equal_approx(closed[0], ramp[ramp.size() - fade]), "sample 0 is the old tail's first sample (%.4f vs %.4f)" % [closed[0], ramp[ramp.size() - fade]])
	_check(absf(closed[fade - 1] - ramp[fade - 1]) < 0.002, "the last faded sample is back on the head (%.4f vs %.4f)" % [closed[fade - 1], ramp[fade - 1]])
	# The real claim: on every bank bed the wrap from last sample to first is no bigger a step than the
	# bed takes between neighbours in its own body, so nothing is heard at the seam.
	var worst: String = ""
	for name: StringName in Ordering.ids(BedBank.SECONDS.keys()):
		var buf: PackedFloat32Array = BedBank.generate(name, _rng(3))
		var seam: float = absf(buf[0] - buf[buf.size() - 1])
		var typical: float = 0.0
		for i: int in range(1, 2000):
			typical = maxf(typical, absf(buf[i] - buf[i - 1]))
		if seam > typical:
			worst += " %s(seam %.3f > step %.3f)" % [name, seam, typical]
	_check(worst == "", "every bed's wrap step is within its own largest neighbour step%s" % worst)


## A partial's magnitude against the bed's RMS, so beds of different levels compare on one scale.
func _tone_ratio(buf: PackedFloat32Array, hz: float) -> float:
	return SfxBank.tone_magnitude(buf, hz) / maxf(1e-6, SfxBank.rms(buf, 0, buf.size()))


func _test_the_tonal_beds_carry_their_partials() -> void:
	# name, stated partial, an off-frequency control between the stated partials
	for spec: Array in [[&"hum", 55.0, 80.0], [&"hum", 110.0, 80.0], [&"cave", 38.0, 47.0], [&"cave", 57.0, 47.0],
			[&"pump", 62.0, 77.0], [&"winch", 88.0, 110.0], [&"winch", 132.0, 110.0], [&"hum_mid", 110.5, 140.0]]:
		var buf: PackedFloat32Array = BedBank.generate(spec[0], _rng(5))
		var on: float = _tone_ratio(buf, spec[1])
		var off: float = _tone_ratio(buf, spec[2])
		_check(on > off * 3.0, "%s has its %.1f Hz partial, 3x over %.0f Hz (%.4f vs %.4f)" % [spec[0], spec[1], spec[2], on, off])
	# The creak is the exception by design: its fibre tone rides a +-9% wow, so the 143 Hz partial is
	# SPREAD over about 130..156 Hz and a single bin at 143 sees a fraction of it (the first draft of
	# this row asserted the bin and measured 0.0044 against a 0.0131 rustle floor at 180 Hz). The claim
	# that holds is the band: the wow band carries at least twice the energy of the same-width band
	# just above it, where only the rustle lives.
	var creak: PackedFloat32Array = BedBank.generate(&"creak", _rng(5))
	var wow_band: float = _band(creak, 130.0, 156.0, 2.0)
	var above: float = _band(creak, 170.0, 196.0, 2.0)
	_check(wow_band > above * 2.0, "the creak's wowed 143 Hz band carries twice the band above it (%.4f vs %.4f)" % [wow_band, above])


func _test_the_broadband_beds_do_not() -> void:
	var hum: PackedFloat32Array = BedBank.generate(&"hum", _rng(6))
	var hum_at_55: float = _tone_ratio(hum, 55.0)
	for name: StringName in [&"wind", &"rush", &"pour", &"hum_top"]:
		var buf: PackedFloat32Array = BedBank.generate(name, _rng(6))
		var most: float = 0.0
		for hz: float in [55.0, 110.0, 165.0, 220.0, 330.0, 440.0]:
			most = maxf(most, _tone_ratio(buf, hz))
		_check(most < hum_at_55 * 0.25, "%s has no partial where the hum's 55 Hz stands (worst %.4f vs %.4f)" % [name, most, hum_at_55])


## Band energy by a comb of tones, the same single-bin DFT the bank suite uses, so the claim is about
## where the energy sits and not about two generators' loudness.
func _band(buf: PackedFloat32Array, lo: float, hi: float, step: float) -> float:
	var sum: float = 0.0
	var hz: float = lo
	while hz <= hi:
		sum += SfxBank.tone_magnitude(buf, hz)
		hz += step
	return sum


func _test_the_rush_is_brighter_than_the_wind() -> void:
	var wind: PackedFloat32Array = BedBank.generate(&"wind", _rng(7))
	var rush: PackedFloat32Array = BedBank.generate(&"rush", _rng(7))
	var wind_ratio: float = _band(wind, 1000.0, 3000.0, 250.0) / maxf(1e-6, _band(wind, 60.0, 300.0, 30.0))
	var rush_ratio: float = _band(rush, 1000.0, 3000.0, 250.0) / maxf(1e-6, _band(rush, 60.0, 300.0, 30.0))
	_check(rush_ratio > wind_ratio * 2.0, "the rush's high-to-low band ratio is at least twice the wind's (%.3f vs %.3f)" % [rush_ratio, wind_ratio])


func _test_one_seed_makes_one_bed() -> void:
	var a: PackedFloat32Array = BedBank.generate(&"pour", _rng(9))
	var b: PackedFloat32Array = BedBank.generate(&"pour", _rng(9))
	var c: PackedFloat32Array = BedBank.generate(&"pour", _rng(10))
	_check(a == b, "the same seed makes the same pour, sample for sample")
	_check(a != c, "control: seed 10 makes a different pour")
	_check(BedBank.generate(&"no_such_bed", _rng(1)).is_empty(), "an unknown bed name is an empty buffer, not a crash")


func _test_the_loop_stream_loops() -> void:
	var buf: PackedFloat32Array = BedBank.generate(&"hum", _rng(2))
	var w: AudioStreamWAV = BedBank.to_loop_stream(buf)
	_check(w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the stream loops forward")
	_check(w.loop_end == buf.size(), "and its loop end is the closed length (%d)" % w.loop_end)
