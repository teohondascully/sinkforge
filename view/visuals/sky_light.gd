class_name SkyLight
extends RefCounted

## WHAT THE SKY DELIVERS, as against `SkyPainter`, which is what the sky LOOKS LIKE (D0589). The same
## split `VeilPainter`/`VeilLight` already draws: one file paints, one file answers questions about the
## light, and the second is pure and testable over its inputs.
##
## IT EXISTS BECAUSE A NIGHT SKY WAS POURING NOON SUNLIGHT DOWN EVERY HOLE. `LightPainter` held the
## godray's colour and its strength as literals -- a warm `RAY` at `Color(1.0, 0.95, 0.76)` and no level
## at all -- and its header stated the reason plainly: "day/night -- this build has no day clock, so the
## godrays run at full day". D0583 gave the ground a night level and moved `SkyPainter.DAYLIGHT` to 0.15;
## the shafts were the half that did not move. A beam and the floor it lands on disagreed about the hour.
##
## Astra's D6 ruling is the general form: "A night sky should not coexist with sunlight-like shafts merely
## because separate painters use unrelated constants." So a beam's colour and level are DERIVED here, from
## the sky, and no painter holds a second opinion about the weather.

## Legacy's warm beam, kept exactly. `ray_tone` returns it unchanged at `DAYLIGHT` 1.0, so this is a night
## fix and not a re-tune of the daylight look.
const RAY_SUN := Color(1.0, 0.95, 0.76)

## The two ends of the sky gradient, at night and at full day. `SkyPainter.paint` draws its gradient from
## these and nothing else, so the beam and the backdrop cannot drift apart.
const ZENITH_NIGHT := Color(0.045, 0.06, 0.105)
const ZENITH_DAY := Color(0.21, 0.32, 0.50)
const HORIZON_NIGHT := Color(0.125, 0.135, 0.185)
const HORIZON_DAY := Color(0.46, 0.55, 0.66)


## The sky's colour overhead at a daylight level.
static func zenith_tone(dl: float) -> Color:
	return ZENITH_NIGHT.lerp(ZENITH_DAY, dl)


## The sky's colour at the horizon at a daylight level, before `SkyPainter`'s dusk blush.
static func horizon_tone(dl: float) -> Color:
	return HORIZON_NIGHT.lerp(HORIZON_DAY, dl)


## THE HUE OF THE LIGHT COMING DOWN, and a hue is all it is: the zenith carried to full value.
##
## The level is carried separately by `ray_level`, and multiplying a dark night sky by a small alpha as
## well would dim the beam twice over and it would not be visible at all.
##
## AT FULL NIGHT THIS IS `SkyPainter.STAR_COLD`, EXACTLY. That constant was authored by a different route
## -- the night zenith "held at its own hue 225.0 and saturation 0.571 and carried up to full value"
## (`sky_painter.gd`) -- and normalising the same colour by its own maximum channel reproduces it to four
## places: (0.4286, 0.5714, 1.0) against (0.429, 0.571, 1.0). Two derivations of one blue that agree,
## which is why `tests/test_sky_light.gd` pins this one against that constant rather than against a
## number I would otherwise have written down myself.
static func sky_tint(dl: float) -> Color:
	var zenith: Color = zenith_tone(dl)
	var peak: float = maxf(maxf(zenith.r, zenith.g), zenith.b)
	if peak <= 0.0:
		return zenith
	return Color(zenith.r / peak, zenith.g / peak, zenith.b / peak)


## The colour a shaft admits: the sky's own hue at night, legacy's warm sun beam at full day.
static func ray_tone(dl: float = SkyPainter.DAYLIGHT) -> Color:
	return sky_tint(dl).lerp(RAY_SUN, dl)


## HOW MUCH OF FULL DAYLIGHT THE SKY DELIVERS, and it is DERIVED rather than chosen
## (`[[constant-must-dominate-constant]]`): it runs from `VeilLight.NIGHT_LEVEL` at full night to 1.0 at
## full day, which is the SAME factor the ground above the surface already takes through
## `VeilLight.level_rgb`. A beam and the floor it lands on therefore cannot disagree about the hour.
##
## Two constants survive and they are now ORDERED rather than independent: `SkyPainter.DAYLIGHT` says how
## the sky LOOKS, `VeilLight.NIGHT_LEVEL` says what it DELIVERS when `DAYLIGHT` is 0. Neither is a second
## opinion about the other.
static func ray_level(dl: float = SkyPainter.DAYLIGHT) -> float:
	return lerpf(VeilLight.NIGHT_LEVEL, 1.0, dl)
