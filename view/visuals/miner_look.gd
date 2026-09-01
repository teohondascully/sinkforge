class_name MinerLook
extends RefCounted

## Which miner frame the body's motion state calls for, and how to draw it. Ported from
## `legacy/scenes/player.gd:664-793` (`_sprite_key`, `SPRITE_FALLBACKS`, `_resolve_tex`, and the draw
## block) -- the algorithm is legacy's, re-expressed against this build's `Body` and against `Art`, which
## was already lifted from `legacy/scenes/art.gd` (D0227) and until now had **no consumer at all**.
##
## The body is currently one `draw_rect`. `docs/LEGACY_GAP.md` ranks this the single most
## player-visible gap in the project, and it is cheap because there is no art backlog behind it:
## `legacy/assets/sprites/` already holds 16 authored 32x48 PNGs.
##
## PORTED, NOT INVENTED -- and the parts deliberately NOT ported are as load-bearing as the parts that
## were. Legacy's key list also carries `miner_swing`, `miner_haul`, `miner_climb_0/1` and `miner_hang`,
## selected by `grapple.taut`, `grapple.state`, and `climbing`. **This build has no grapple and no rope**,
## so those branches are omitted rather than stubbed: a branch that can never be true is a branch nobody
## can test, and it would read as supported. They come back with the grapple (`docs/LEGACY_GAP.md` T1
## #12, resolver-parked). `miner_land` is likewise omitted -- legacy selects it on `_land_hold`, a
## landing-impact timer this `Body` does not have, and inventing one to fill the slot would be building a
## feel mechanic to satisfy a sprite table.
##
## What IS ported: dig alternation, the airborne rise/fall split, the four-frame walk cycle, idle, the
## full fallback chain, feet-on-the-AABB-bottom placement, the facing flip, and the rim halo.

const SPRITE_FALLBACKS: Dictionary = {
	"miner_fall": "miner_jump", "miner_jump": "miner_idle",
	"miner_walk_0": "miner_idle", "miner_walk_1": "miner_idle",
	"miner_walk_2": "miner_idle", "miner_walk_3": "miner_idle",
	"miner_dig_0": "miner_idle", "miner_dig_1": "miner_idle",
	"miner_idle": "miner",
}

## Legacy's own thresholds, converted to this build's units rather than re-tuned. Legacy compared a
## float `velocity.x` in px/s against 10.0; `Body.vel_x` is `Fx` fixed-point px/s, so the same physical
## speed is `10 * Fx.SCALE`. Converting rather than re-picking is the point -- a number chosen by feel in
## another codebase is a measurement here, and re-tuning it would silently drop legacy's judgment.
const WALK_SPEED_MIN: int = 10 * Fx.SCALE

## Frames per second of the two cycles, from legacy's `int(_anim_time * 8.0) % 2` and its walk clock.
## Expressed in TICKS here because this build has no float animation clock on the draw path.
const DIG_TICKS_PER_FRAME: int = 8
const WALK_TICKS_PER_FRAME: int = 6

## Passed when the caller has no swing to read — a preview, a fixture, a caller written before D0287 —
## and the dig frames fall back to legacy's free-running alternation. A sentinel rather than 0, because 0
## is a REAL phase (the tick a blow lands) and the two must not be the same value.
const SWING_PHASE_NONE: int = -1

## Which half of the stroke shows the struck frame. Half, as legacy's alternation is, so the cadence
## reads as a steady chop rather than a twitch.
const DIG_STRUCK_UNTIL: int = 500


## `digging` MUST come from the player's INPUT, not from `Body.dig_event_this_tick`. The event is true
## only on the tick a cell was actually excavated, so animating from it would flash one dig frame at the
## instant rock breaks and show idle for the whole swing leading up to it. The input is what the player is
## doing; the event is what the world did about it.
##
## The caller also keeps its primitive path: `Art.tex` returns null for every key when
## `assets/sprites/` is empty, which is its designed contract, and every capture and milestone image
## taken before sprites landed was made against that rectangle.
##
## The logical frame key for a motion state, in legacy's own priority order: digging, airborne, walking,
## idle. A pure function of its arguments -- no `Body`, no textures, no clock -- so
## `tests/test_miner_look.gd` can assert the whole table without building a world.
static func sprite_key(digging: bool, on_floor: bool, vel_x: int, vel_y: int, anim_ticks: int,
		swing_phase: int = SWING_PHASE_NONE) -> String:
	if digging:
		return dig_key(swing_phase, anim_ticks)
	if not on_floor:
		# Up and down are different beats: the rise is a tuck, the drop streams the legs out behind.
		# `vel_y > 0` is DOWNWARD here, as it is in legacy -- y grows toward the world's bottom.
		return "miner_fall" if vel_y > 0 else "miner_jump"
	if absi(vel_x) > WALK_SPEED_MIN:
		return "miner_walk_%d" % ((anim_ticks / WALK_TICKS_PER_FRAME) % 4)
	return "miner_idle"


## WHICH DIG FRAME, AND WHY IT IS NOT A CLOCK. Legacy alternates on `int(_anim_time * 8.0) % 2` — a
## free-running 8 Hz that has no idea when the pick actually lands. It gets away with it because 8 Hz is
## a half-cycle of 0.125 s against its own `SWING_PERIOD` of 0.28 s, so at rest the two very nearly
## agree; they drift apart exactly as `RHYTHM_SWING` speeds the swing up and the animation does not
## follow. **This build computes the real period** (D0279: 16 ticks at rest, 10 at full rhythm) and
## `Mining.swing_phase_per_mille()` reports where in the stroke the arms are, so the frame is a function
## of the swing rather than of a clock that resembles it.
##
## `miner_dig_1` is the STRUCK pose (`legacy/tools/bake_miner.gd:449`, arms `dig_down`) and it shows from
## phase 0 — the tick the rock takes damage — through the follow-through; `miner_dig_0` (`dig_up`) covers
## the wind-up and ends at the next impact. That the two agree at rest is a check, not a coincidence:
## `DIG_TICKS_PER_FRAME` is 8 and the at-rest period is 16, so the fallback below and the phase-locked
## path draw the same cadence when rhythm is zero. `tests/test_miner_look.gd` asserts exactly that.
static func dig_key(swing_phase: int, anim_ticks: int) -> String:
	if swing_phase == SWING_PHASE_NONE:
		return "miner_dig_0" if (anim_ticks / DIG_TICKS_PER_FRAME) % 2 == 0 else "miner_dig_1"
	return "miner_dig_1" if swing_phase < DIG_STRUCK_UNTIL else "miner_dig_0"


## The best drawn texture for a key: walk the fallback chain until something resolves. Returns null when
## nothing in the chain exists, so a caller keeps its primitive path -- `Art`'s own designed contract.
##
## The loop is bounded by the chain's length rather than by `while true`: a fallback table that ever gained
## a cycle would otherwise hang the renderer, and a hang in a draw call is far worse than a missing sprite.
static func resolve(key: String) -> Texture2D:
	var k: String = key
	for _i: int in SPRITE_FALLBACKS.size() + 1:
		var tex: Texture2D = Art.tex(k)
		if tex != null:
			return tex
		if not SPRITE_FALLBACKS.has(k):
			return null
		k = SPRITE_FALLBACKS[k]
	return null


## Where the sprite goes, in the body's own local space: horizontally centred, **feet on the AABB
## bottom**, at 1:1 pixels. Legacy's `Rect2(-w*0.5, (HEIGHT*0.5) - h + bob, w, h)`, minus the bob (a
## float animation offset this build has no clock for).
##
## The art is 32x48 against a 16x40 collision box, so it deliberately OVERHANGS -- wider than the body and
## taller than it. That is legacy's own arrangement and not a scaling bug: a collision box is not a
## silhouette, and shrinking the art to the box would make the miner read as a chip rather than a person.
## `docs/LEGACY_GAP.md` records the eventual 48 -> 56 re-bake for this build's 40px body; until that
## happens 1:1 is the honest placement and reads slightly squat, which the gap doc also says.
static func dest_rect(tex: Texture2D, body_height_px: int) -> Rect2:
	var w: float = float(tex.get_width())
	var h: float = float(tex.get_height())
	return Rect2(-w * 0.5, (float(body_height_px) * 0.5) - h, w, h)


## Legacy's rim halo, ported with its reasoning intact because the reasoning is the finding.
##
## COOL AND BRIGHT ON PURPOSE: the miner's art is warm leather and amber, the same family as the dirt and
## the UI, so a warm outline deepens that collision. A cool bright edge is the one thing in this
## warm-brown world nothing else wears.
##
## ONE RING, NOT TWO: the authored pixel art already carries its own one-pixel near-black outline, so a
## second inner ring at 1.4px in eight directions printed up to two solid pixels of black around every
## limb -- legacy's own comment records that the legs came out as black boxes with boots inside them.
const RIM_COLOR: Color = Color(0.80, 0.93, 1.0, 0.85)
const RIM_WIDTH: float = 1.5  ## about 1.5 art pixels: read, but not seen

const RIM_OFFSETS: Array[Vector2] = [
	Vector2(-RIM_WIDTH, 0.0), Vector2(RIM_WIDTH, 0.0),
	Vector2(0.0, -RIM_WIDTH), Vector2(0.0, RIM_WIDTH),
	Vector2(-RIM_WIDTH, -RIM_WIDTH), Vector2(RIM_WIDTH, -RIM_WIDTH),
	Vector2(-RIM_WIDTH, RIM_WIDTH), Vector2(RIM_WIDTH, RIM_WIDTH),
]


## Draws the resolved frame: rim halo first, sprite over it. Takes PRIMITIVES, never a `Body` --
## `view/` may not reach `sim/` (`tools/layer_lint`), and that boundary is why `sprite_key` above also
## takes loose ints rather than the object they came from. The caller converts; this file never sees the
## simulation.
##
## The facing flip negates the rect's WIDTH rather than setting a canvas transform. Legacy used a
## transform and had to restore it; an un-restored transform inside a `_draw` leaks onto everything drawn
## afterwards, and the restore is one early return away from being skipped.
##
## **NEGATE THE SIZE AND LEAVE THE POSITION ALONE.** `Rect2` and Godot's rasterizer disagree about what a
## negative width means, and the disagreement is silent. To `Rect2`, `Rect2(x, -w)` and `Rect2(x - w, w)`
## describe the same interval, so the natural-looking "move the corner, then negate" is arithmetic that
## reads as correct. `RenderingServer.canvas_item_add_texture_rect` does neither: it sets a `FLIP_H` flag,
## takes the absolute value of the size, and **keeps `position` exactly where it was**. So pre-shifting
## the corner is never undone, and the sprite draws one full width to the right of where it belongs.
##
## MEASURED, NOT REASONED (D0315, `tools/probe_facing_flip.tscn`): drawing the same texture at the same
## centre under both facings put facing-1 at canvas x 305..337 and facing+1 at 335..366 -- both 31px wide,
## so nothing was clipped, and the turn translated the miner **+29.3px**. The director found it by playing:
## the miner "reflects around an offset center" every time it turns around.
##
## A unit test on this rect cannot see any of that ON ITS OWN. `Rect2(336, -32)` covers the same interval
## as `Rect2(304, 32)` by any assertion written against `position`/`size`/`abs()`, and the two draw 32px
## apart. That is why the evidence is a headed pixel capture -- and why the convention it measured is
## written down below as `drawn_span`, so the suite has something it CAN assert against.
static func draw_sprite(canvas: CanvasItem, tex: Texture2D, centre: Vector2,
		body_height_px: int, facing: int) -> void:
	var dst: Rect2 = placed_rect(tex, centre, body_height_px, facing)
	for d: Vector2 in RIM_OFFSETS:
		canvas.draw_texture_rect(tex, Rect2(dst.position + d, dst.size), false, RIM_COLOR)
	canvas.draw_texture_rect(tex, dst, false)


## The exact rect `draw_sprite` hands the rasterizer, as a value. Split out so the placement can be
## asserted without a canvas, a window or a GPU -- `draw_sprite` itself is untestable headless, which is
## how the flip defect survived to reach the director.
static func placed_rect(tex: Texture2D, centre: Vector2, body_height_px: int, facing: int) -> Rect2:
	var dst: Rect2 = dest_rect(tex, body_height_px)
	dst.position += centre
	if facing > 0:
		dst.size.x = -dst.size.x
	return dst


## **THE RASTERIZER'S CONVENTION FOR A NEGATIVE-WIDTH RECT, WRITTEN DOWN SO IT CAN BE ASSERTED.** Given a
## rect as passed to `draw_texture_rect`, the `[left, right]` the pixels actually land in.
##
## `RenderingServer.canvas_item_add_texture_rect` responds to a negative width by raising a horizontal-flip
## flag and taking the absolute value of the size. It does **not** move `position`. So the covered interval
## is `[position.x, position.x + |size.x|]` -- the position is the LEFT edge either way, and a negative
## width mirrors the content inside that same interval rather than reflecting the interval itself.
##
## This differs from the convention `Rect2` itself implies, where a negative size means the position is the
## far corner (`Rect2.abs()` moves the position; this does not). Two reasonable conventions, one of them
## silent, and the gap between them is the whole of D0315.
##
## NOT DERIVED FROM THE DOCS -- MEASURED. `tools/probe_facing_flip.tscn` draws one texture at one centre
## under both facings and reports the shift that best aligns the mirrored bands: the pre-fix code aligns at
## **+32px** (a full sprite width) with a cost of 1173.1 at zero, and the fix aligns at **+0px** with a
## cost of 30.7. Identical residual at each one's own best shift, so the mirror is intact in both and only
## the translation differs. Re-run that probe if this function is ever doubted; do not reason about it.
static func drawn_span(rect: Rect2) -> Vector2:
	return Vector2(rect.position.x, rect.position.x + absf(rect.size.x))
