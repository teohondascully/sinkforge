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
static func sprite_key(digging: bool, on_floor: bool, vel_x: int, vel_y: int, anim_ticks: int) -> String:
	if digging:
		return "miner_dig_0" if (anim_ticks / DIG_TICKS_PER_FRAME) % 2 == 0 else "miner_dig_1"
	if not on_floor:
		# Up and down are different beats: the rise is a tuck, the drop streams the legs out behind.
		# `vel_y > 0` is DOWNWARD here, as it is in legacy -- y grows toward the world's bottom.
		return "miner_fall" if vel_y > 0 else "miner_jump"
	if absi(vel_x) > WALK_SPEED_MIN:
		return "miner_walk_%d" % ((anim_ticks / WALK_TICKS_PER_FRAME) % 4)
	return "miner_idle"


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
static func draw_sprite(canvas: CanvasItem, tex: Texture2D, centre: Vector2,
		body_height_px: int, facing: int) -> void:
	var dst: Rect2 = dest_rect(tex, body_height_px)
	dst.position += centre
	if facing > 0:
		dst.position.x += dst.size.x
		dst.size.x = -dst.size.x
	for d: Vector2 in RIM_OFFSETS:
		canvas.draw_texture_rect(tex, Rect2(dst.position + d, dst.size), false, RIM_COLOR)
	canvas.draw_texture_rect(tex, dst, false)
