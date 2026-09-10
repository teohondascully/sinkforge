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

## THE DEEP'S AMBIENT (D0577), and the story of the constant it replaces is the reason it is shaped
## this way. D0569 put a FLOOR here -- `max(s, 0.55)` on the COMBINED output -- because our underground
## sat in the bottom sixth of the value range against a reference whose darkest point anywhere is 0.116:
##
##                          ours (frame_0030)   the reference
##     deep / unlit rock          0.0195           0.15 - 0.19
##     rock beside a lamp         0.158            0.377
##     a lamp's pool              none             0.515
##     a cave's void              0.053            0.116
##
## The brightness reading was right. The instrument was not. Underground `sky` is `1 - AMBIENT_DARK` =
## 0.34 and `shade` tops out at `1 + KEY_STRENGTH` = 1.30, so the combined output cannot exceed 0.442 --
## strictly under a floor of 0.55. Every solid cell, every cave, every void below the scatter band
## therefore clamped to exactly one value. Measured on this tree, five structurally different things all
## returned rgb (0.5500, 0.5610, 0.6382): buried rock, mid rock, a lit cut face, cave air and true void.
## D0569's own header said "this does NOT flatten depth" and it flattened everything, not merely depth.
## Astra found it; the arithmetic is three constants and I did not do it. `tests/test_flat_planes.gd`
## now pins distinctness directly, so no successor to this constant can go quiet the same way.
##
## WHAT REPLACES IT: an ambient the deep is LIFTED BY rather than clamped TO, which is what ambient
## light actually is -- `lit = DEEP_AMBIENT + DEEP_GAIN * s`, an affine remap that moves the whole range
## up and keeps every ordering inside it. `DEEP_GAIN` is a second dial because one is not enough: a pure
## `F + (1-F)s` fixes contrast at `1-F`, and at the brightness this scene needs that compresses to 45%.
##
## AND IT IS RAMPED BY DEPTH, so it cannot reach the surface. `veil.gdshader` already computes `d`, the
## depth darkening, and `d / AMBIENT_DARK` is exactly "how underground is this pixel" -- 0 above the
## surface line, 1 in the deep. The lift is mixed in by that ramp, so surface rock is bit-identical to
## the pre-D0569 build. This is the failure D0575 hit from the other direction: a uniform brightening
## that landed the deep correctly blew the surface out to 0.194 against a reference of 0.148.
##
## THE NUMBERS ARE A MEASURED POINT ON A SWEEP, not a taste call. Held fixed: materials, lights, the
## scene. Varied: F over [0.40, 0.60] and G over [0.45, 0.77]. Read off hardrock's base at 60 m (0.2763):
##
##     model                    mid rock   cut face   cave air    void    spread
##     no floor (pre-D0569)      0.0439     0.1261     0.0975    0.0341   0.0953
##     clamp to 0.55 (D0569)     0.1559     0.1559     0.1559    0.1559   0.0000
##     THIS (F 0.48, G 0.69)     0.1657     0.2196     0.2007    0.1592   0.0626
##     the reference             0.15 - 0.19 on rock, ~0.074 of spread across the underground
##
## Two-thirds of the contrast D0569 destroyed, at the brightness D0569 was reaching for. It is not the
## closest point on the sweep to the reference's spread (F 0.44, G 0.77 gives 0.0700) -- it is the one
## that keeps mid rock in the MIDDLE of the reference's band rather than at its edge, and the remaining
## difference is for the frame-judged loop in `docs/WORKING.md` item 49 to close, not for a number fitted
## to one lossy JPEG.
##
## `view/visuals/veil.gdshader` carries both as uniforms with the same defaults; they must move together
## or the shader and this file disagree about the same pixel.
const DEEP_AMBIENT: float = 0.48
const DEEP_GAIN: float = 0.69

## THE SURFACE IS LIT FOR NOON UNDER A NIGHT SKY, and this is the factor that ends that (D0583).
## Measured on the real tutorial frame: the sky reads 0.086 at the top and 0.254 at the horizon -- night
## -- while the ground beside the player reads **0.344** and a tree canopy reads **0.479**, the
## brightest, most saturated thing in the frame. The reference's surface rock at night is 0.148. Nothing
## was wrong with any one painter: the sky is drawn as night, terrain takes `sky_light` = 1.0 above the
## surface line, and `leaves`/`wood` carry `depth_darken: 0.0` because "a tree stands in the sky". Three
## correct decisions that never met.
##
## RAMPED OUT WITH DEPTH, so D0577's tuning is untouched: at `deep_t` 1 this is exactly 1.0 and the deep
## is bit-identical. It only ever darkens what the sky can still see, which is the only place a night
## level means anything. 0.45 puts surface ground at 0.155 against the reference's 0.148.
const NIGHT_LEVEL: float = 0.45


## Legacy `_light_level(darkness)`: white at no darkness, `AMBIENT_LIGHT` at `AMBIENT_DARK`, and the same
## hue scaled down past it (mass shading and the void floor take a cell below the ambient).
## `deep_t` is `d / AMBIENT_DARK` from the shader: 0 at the surface, 1 in the deep. It defaults to the
## deep because that is the case this file exists to document; pass 0.0 to ask what the surface does.
static func level_rgb(s: float, deep_t: float = 1.0) -> Color:
	var t: float = clampf(deep_t, 0.0, 1.0)
	var lifted: float = DEEP_AMBIENT + DEEP_GAIN * s
	var lit: float = clampf(lerpf(s, lifted, t) * lerpf(NIGHT_LEVEL, 1.0, t), 0.0, 1.0)
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
## RAISED FROM 0.38 (D0571). T012's ruling was "keep it warm, and if it reads more campfire than headlamp
## ease it toward 0.38", made when the deep was near black and any warmth read as a lot. Against the
## reference the pool is not warm enough by a wide margin: its rock beside a lamp is rgb (0.553, 0.340,
## 0.226), a strongly amber 0.377 luma, where ours reads (0.237, 0.211, 0.171) -- nearly neutral. 0.38
## toward LAMP_COLOR lands on (1.00, 0.93, 0.81), which is white with a hint. The director's standing
## instruction is now to match that reference, which supersedes the easing rather than contradicting the
## ruling behind it: the ruling was "keep it warm" and this is warmer.
const LAMP_TINT: float = 0.62


## The colour the lamp reveals rock in: legacy `_light_tint(LAMP_COLOR)` at this build's own lean.
static func lamp_tint() -> Color:
	return Color.WHITE.lerp(LAMP_COLOR, LAMP_TINT)
