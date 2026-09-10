extends "res://tests/test_base.gd"

## `view/visuals/sky_light.gd` -- WHAT THE SKY DELIVERS (D0589). The godrays used to run at full day
## under a night sky, because `LightPainter` held the beam's colour and strength as literals and nothing
## related them to `SkyPainter.DAYLIGHT`. These assertions pin the relationship, not the numbers: the
## beam follows the sky down, it agrees with the ground about the hour, and at full day it is byte for
## byte the warm beam legacy shipped.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_sky_light.gd

const EPS: float = 0.002


func _initialize() -> void:
	_test_the_night_tint_reproduces_a_constant_derived_by_another_route()
	_test_full_day_returns_legacys_beam_unchanged()
	_test_the_beam_follows_the_sky_down()
	_test_the_beam_and_the_ground_agree_about_the_hour()
	_test_the_tint_is_a_hue_and_carries_no_brightness()
	_test_the_gradient_and_the_beam_read_one_zenith()
	_finish("sky_light")


func _rgb_near(a: Color, b: Color, eps: float) -> bool:
	return absf(a.r - b.r) < eps and absf(a.g - b.g) < eps and absf(a.b - b.b) < eps


## THE CONTROL THAT TRAVELS INSIDE THE MEASUREMENT. `SkyPainter.STAR_COLD` was authored independently,
## by taking the night zenith to hue 225.0 / saturation 0.571 at full value. `sky_tint` reaches the same
## colour by dividing that zenith by its own largest channel. Two derivations, one blue -- so this pins
## the new function against a number the repo already believed rather than against one I chose.
func _test_the_night_tint_reproduces_a_constant_derived_by_another_route() -> void:
	var tint: Color = SkyLight.sky_tint(0.0)
	_check(_rgb_near(tint, SkyPainter.STAR_COLD, EPS),
		"the night sky's hue IS `STAR_COLD`: %.4f,%.4f,%.4f against %.4f,%.4f,%.4f" % [
			tint.r, tint.g, tint.b, SkyPainter.STAR_COLD.r, SkyPainter.STAR_COLD.g, SkyPainter.STAR_COLD.b])


## The night fix must not be a daylight re-tune: at `dl` 1.0 both answers are exactly what shipped.
func _test_full_day_returns_legacys_beam_unchanged() -> void:
	_check(_rgb_near(SkyLight.ray_tone(1.0), SkyLight.RAY_SUN, 0.0001),
		"at full day the beam is legacy's warm RAY, unchanged: %s" % SkyLight.ray_tone(1.0))
	_check(absf(SkyLight.ray_level(1.0) - 1.0) < 0.0001,
		"and at full day it is at full strength (%.4f), which is what the old literal meant" % SkyLight.ray_level(1.0))


## THE DEFECT ITSELF. A darker sky must send less light down a hole -- strictly, at every step.
func _test_the_beam_follows_the_sky_down() -> void:
	var last: float = -1.0
	var rose: int = 0
	for i: int in 11:
		var dl: float = float(i) / 10.0
		var lv: float = SkyLight.ray_level(dl)
		if lv > last:
			rose += 1
		last = lv
	_check(rose == 11, "the beam's level rises with the sky at every one of 11 steps (%d)" % rose)
	_check(SkyLight.ray_level(0.0) < SkyLight.ray_level(1.0) - 0.4,
		"and night is far below day, not a rounding difference: %.4f against %.4f" % [
			SkyLight.ray_level(0.0), SkyLight.ray_level(1.0)])
	# The beam is COOLER at night than at day: the sky's own blue, not the sun's amber.
	var night: Color = SkyLight.ray_tone(0.0)
	var day: Color = SkyLight.ray_tone(1.0)
	_check(night.b - night.r > 0.4 and day.r - day.b > 0.2,
		"and it is blue at night (b-r %.3f) and warm at noon (r-b %.3f)" % [night.b - night.r, day.r - day.b])


## COHERENCE, WHICH IS THE WHOLE POINT (Astra's D6). The factor the beam takes at full night is the
## factor the ground above the surface already takes, so a shaft cannot be brighter than the hour.
func _test_the_beam_and_the_ground_agree_about_the_hour() -> void:
	_check(absf(SkyLight.ray_level(0.0) - VeilLight.NIGHT_LEVEL) < 0.0001,
		"the beam's night level IS the ground's `NIGHT_LEVEL` (%.4f), derived and not chosen" % SkyLight.ray_level(0.0))
	# And at the value actually shipped, the beam is dimmed rather than left at noon.
	_check(SkyLight.ray_level(SkyPainter.DAYLIGHT) < 0.60,
		"at the shipped DAYLIGHT %.2f the beam runs at %.4f, not the 1.0 it ran at before" % [
			SkyPainter.DAYLIGHT, SkyLight.ray_level(SkyPainter.DAYLIGHT)])


## The tint carries hue only. If it ever carried brightness the beam would be dimmed twice and vanish.
func _test_the_tint_is_a_hue_and_carries_no_brightness() -> void:
	var off: int = 0
	for i: int in 11:
		var t: Color = SkyLight.sky_tint(float(i) / 10.0)
		if absf(maxf(maxf(t.r, t.g), t.b) - 1.0) > 0.0001:
			off += 1
	_check(off == 0, "every tint's largest channel is exactly 1.0 across the range (%d off)" % off)


## The gradient `SkyPainter` draws and the beam `LightPainter` draws must read ONE zenith. Pinned by
## reconstructing the painter's own lerp from the shared constants.
func _test_the_gradient_and_the_beam_read_one_zenith() -> void:
	var bad: int = 0
	for i: int in 11:
		var dl: float = float(i) / 10.0
		var expect: Color = SkyLight.ZENITH_NIGHT.lerp(SkyLight.ZENITH_DAY, dl)
		if not _rgb_near(SkyLight.zenith_tone(dl), expect, 0.0001):
			bad += 1
	_check(bad == 0, "the zenith is one function of daylight, shared by both painters (%d mismatches)" % bad)
	_check(_rgb_near(SkyLight.zenith_tone(0.0), SkyLight.ZENITH_NIGHT, 0.0001)
			and _rgb_near(SkyLight.horizon_tone(0.0), SkyLight.HORIZON_NIGHT, 0.0001),
		"and the night ends are the literals `SkyPainter.paint` used to hold inline")
