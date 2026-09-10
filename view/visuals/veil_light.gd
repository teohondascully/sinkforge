class_name VeilLight
extends RefCounted

## THE VEIL'S COLOUR, legacy's `world_renderer.gd` terms the 6l port dropped (D0391): the dark end is a
## COLOUR, not black -- `_light_level` lerps white toward `AMBIENT_LIGHT`, a cool blue-grey, by darkness --
## the skylight scatters `SKY_FADE` under each column's own surface (`_skylight_alpha(row, surf)`), a true
## void (air with no wall behind it) sits `VOID_FLOOR` darker than the ambient, and the lamp lifts toward
## its own tint (`_light_tint(LAMP_COLOR)`) rather than toward white. Without them the underground was one
## flat grey at every depth with a grey pool in it (VISUAL_QUEUE v2 V03/V04). `veil.gdshader` evaluates
## these per pixel; the functions here are the same arithmetic as pure GDScript, so a test can pin the
## numbers the shader is fed and a reader can find legacy's addresses in one place.

const AMBIENT_LIGHT := Color(0.34, 0.35, 0.42)   ## legacy `:91` -- the deep's own colour
const VOID_FLOOR: float = 0.35                    ## legacy `:111` -- unlit nothing is the darkest thing down here
const LAMP_COLOR := Color(1.0, 0.82, 0.50)        ## legacy `:150` -- the miner's warm head-lamp
const SKY_FADE_M: float = VeilPainter.SKY_FADE_M  ## legacy `SKY_FADE 16`: rows of scatter under the first rock

## THE FLOOR THE DEEP NEVER GOES BELOW (D0569), and it is MEASURED rather than chosen. Both sides of the
## comparison were sampled the same way, a 5x5 mean luma off a real frame:
##
##                          ours (frame_0030)   the reference
##     deep / unlit rock          0.0195           0.15 - 0.19
##     rock beside a lamp         0.158            0.377
##     a lamp's pool              none             0.515
##     a cave's void              0.053            0.116
##
## Our whole underground lived in the bottom sixth of the range and the reference's never goes near
## black: its darkest rock is 0.15 and its DARKEST POINT ANYWHERE is a void at 0.116. Legacy's own ratios
## are all still here and unchanged above this floor -- `AMBIENT_DARK` 0.66 and `MASS_SHADE` 0.55 stack
## to about 0.08 of the material's own colour for buried rock, which is what put clay's 0.26 base at
## 0.02. The floor is the multiplier the deep bottoms out at: 0.55 puts that same clay at 0.147 against
## the reference's 0.15.
##
## This does NOT flatten depth, and the reference is the evidence: its deep rock (0.19) is BRIGHTER than
## its surface rock (0.148). Depth there is carried by hue and by contrast against warm light, never by
## crushing toward black -- which is Astra's diagnosis point 3 ("nothing in the frame is warm against
## anything cool") stated as a number.
##
## `view/visuals/veil.gdshader` carries the same floor as a `deep_floor` uniform with the same default;
## the two must move together or the shader and this file disagree about the same pixel.
const DEEP_FLOOR: float = 0.55


## Legacy `_light_level(darkness)`: white at no darkness, `AMBIENT_LIGHT` at `AMBIENT_DARK`, and the same
## hue scaled down past it (mass shading and the void floor take a cell below the ambient).
static func level_rgb(s: float) -> Color:
	var lit: float = clampf(maxf(s, DEEP_FLOOR), 0.0, 1.0)
	var toward: float = clampf((1.0 - lit) / VeilPainter.AMBIENT_DARK, 0.0, 1.0)
	var scale: float = lit / (1.0 - VeilPainter.AMBIENT_DARK)
	var cool := Color(AMBIENT_LIGHT.r * scale, AMBIENT_LIGHT.g * scale, AMBIENT_LIGHT.b * scale)
	return Color(lit, lit, lit).lerp(cool, toward)


## Legacy `_skylight_alpha(row, surf)` as a LIGHT level (1 - darkness): depth alone above the column's
## surface; under it, a lerp to the deep's ambient over `SKY_FADE_M`.
static func sky_light(row: float, surf: float) -> float:
	var depth_m: float = (row - float(MaterialLook.SURFACE_ROW)) / float(MaterialLook.CELLS_PER_METRE)
	var d: float = VeilPainter.AMBIENT_DARK * clampf((depth_m - VeilPainter.SURFACE_LINE_M) / VeilPainter.SKY_REACH_M, 0.0, 1.0)
	if row > surf:
		var t: float = clampf((row - surf) / (SKY_FADE_M * float(MaterialLook.CELLS_PER_METRE)), 0.0, 1.0)
		d = lerpf(d, VeilPainter.AMBIENT_DARK, t)
	return 1.0 - d


## How far under its column's surface a row is, 0..1 over the scatter band: the void floor's own ramp.
static func under_rock(row: float, surf: float) -> float:
	return clampf((row - surf) / (SKY_FADE_M * float(MaterialLook.CELLS_PER_METRE)), 0.0, 1.0)


## How far the lamp's reveal leans toward `LAMP_COLOR`. Legacy's `LIGHT_TINT` (0.28) gave (1.0, 0.95,
## 0.86), which on this build's cooler deep read as white (2026-09-04 capture at 67 m); 0.45 is the taste
## call queued in `docs/TASTE_QUEUE.md` -- an amber pool against a blue-grey dark is the warm-against-cool
## the frame had none of. THE DIRECTOR RULED (T012, 2026-09-05): keep it warm, and if it reads more
## campfire than headlamp ease it toward 0.38 -- so 0.38 it is, and the warmth stays the point.
const LAMP_TINT: float = 0.38


## The colour the lamp reveals rock in: legacy `_light_tint(LAMP_COLOR)` at this build's own lean.
static func lamp_tint() -> Color:
	return Color.WHITE.lerp(LAMP_COLOR, LAMP_TINT)
