class_name WallPainter
extends RefCounted

## THE BACKGROUND WALL PLANE. Ported from `legacy/scenes/world_renderer.gd:2194-2260` (`_draw_background`,
## `_wall_fill_color`), `2685-2766` (`_wall_base_color`), `legacy/scenes/fine_terrain.gd:350-381`
## (`apply_wall_tone`) and `legacy/scenes/terrain_painter.gd:353-377` (`paint_wall_face`).
## `docs/LEGACY_GAP.md` T1 #3.
##
## `Interface.observe()` has shipped `walls`/`wall_legend` since D0238, `tests/test_interface.gd` asserts
## them, and until this file **zero renderers read either**. Every carved room in every capture is a flat
## fill — the same fill as the sky, so a tunnel and open air are the same picture.
##
## Legacy states the thesis better than a paraphrase can: "A tunnel rendered as a flat rectangle at
## roughly four percent grey does not read as dark, it reads as EMPTY, and no amount of work on the
## foreground plane fixes it." The second plane is the depth cue; the foreground is not.
##
## **DARKNESS BELONGS TO THE VEIL, NOT TO THIS.** Legacy records a measured regression here: the wall was
## darkened once in its own paint and again by the shadow veil, so the veil compounded a value that had
## already been crushed, and a lit chamber came out as a black rectangle. This file paints what the wall
## IS — the same rock a plane back, flatter and cooler — and takes no view on how lit it is. T1 #2 (the
## veil) owns that, and this must still be correct when it lands.
##
## **THE RECESS IS WHAT TURNS A HOLE INTO A ROOM.** Every edge where the wall meets solid rock takes an
## inward cast shadow, deepest under a ceiling because the world's key light comes from above, lightest
## over a floor because a floor stays open to it.

## Legacy's wall tone, unchanged: two fractions and a colour, none of them a pixel count, so all three
## transfer at any cell size.
const RECESS: float = 0.32                        ## how far the back plane sits behind the front, in value
const COOL: Color = Color(0.16, 0.19, 0.30)       ## the cool it drifts toward -- distance desaturates
const COOL_MIX: float = 0.30

## The cast's strengths, `world_renderer.gd:2220-2222`, unchanged and in legacy's own words:
const AO_UNDER: float = 0.62   ## on the wall under a solid ceiling; the deepest
const AO_SIDE: float = 0.34    ## ...beside a solid wall
const AO_ABOVE: float = 0.16   ## ...over a solid floor: light reaches a floor, so it stays open

## **THE ONE THING THAT IS NOT LEGACY'S SHAPE, AND WHY.** Legacy ramps the cast in six 2px bands INSIDE
## one cell, over 12 of its 32 pixels. Its cell is one metre; ours is a quarter of one
## (`MaterialLook.CELLS_PER_METRE`), so the same 0.375 m of falloff spans a cell and a half here and each
## of legacy's six bands would be a quarter of a pixel. Sub-pixel bands do not draw.
##
## So the ramp is kept in METRES and the quantum moved from the sub-cell band to the cell, which is what
## the cell became when it shrank: a wall cell is shaded by its DISTANCE to the nearest solid, and the
## gradient that legacy drew inside one cell is drawn across two of ours. Same falloff over the same
## distance in world terms; the grid underneath it changed and the constant did not.
##
## Denominated in metres rather than in cells for the same reason `view/visuals/crack_painter.gd` is
## denominated in the blow's footprint: `docs/LEGACY_GAP.md` WG-4 may re-denominate the grid, and a depth
## expressed in metres is already correct on the other side of that.
const AO_DEPTH_M: float = 12.0 / 32.0   ## legacy's 12px cast inside its 32px = 1 m cell

## `AO_DEPTH_M * MaterialLook.CELLS_PER_METRE` = 1.5, rounded up: the shadow reaches a cell and a half, so
## two cells carry it and the second carries half. Written out rather than computed because a `const`
## cannot call `roundi`, and asserted against its own derivation in `tests/test_wall_painter.gd` — a
## constant that must dominate another constant is derived by the test or it is a coincidence.
const AO_RAMP_CELLS: int = 2

## The four probes, as (offset, strength). One list rather than four `if`s so that "which directions cast"
## is a thing a test can read, and so the composite below cannot silently skip one.
const PROBES: Array[Dictionary] = [
	{"d": Vector2i(0, -1), "s": AO_UNDER},   ## solid ABOVE -> the deep cast, under a ceiling
	{"d": Vector2i(0, 1), "s": AO_ABOVE},    ## solid BELOW -> the light cast, over a floor
	{"d": Vector2i(-1, 0), "s": AO_SIDE},
	{"d": Vector2i(1, 0), "s": AO_SIDE},
]


## The wall's own colour: the same rock the foreground would paint here, pushed down in value and drifted
## cool, which are the two moves distance makes. Legacy's `apply_wall_tone`, minus its bedding argument —
## `MaterialLook.cell_color` already carries the bedding, because it is the same ground seen a plane back.
static func wall_color(look: MaterialLook, material: StringName, col: int, row: int) -> Color:
	if look == null:
		return COOL
	return look.cell_color(material, col, row).darkened(RECESS).lerp(COOL, COOL_MIX)


## How dark the cast is on one wall cell, in 0..1. Split out of `paint` and returned as a number for the
## reason this repo keeps rediscovering: Godot exposes no way to read back a `CanvasItem`'s draw commands,
## so a painter tested only by being called can assert nothing beyond "it did not crash" — which is
## exactly what a broken early return does while the screen stays flat.
##
## The four directions are composited the way overlapping translucent draws compose, `1 - Π(1 - a)`,
## because that is literally what legacy's four stacked `draw_rect` calls do. Summing them instead would
## put a corner past 1.0 and clip a pocket to black.
static func ao_alpha(obs: Interface.Observation, c: Vector2i) -> float:
	if obs == null:
		return 0.0
	var transmitted: float = 1.0
	for probe: Dictionary in PROBES:
		var strength: float = probe["s"]
		for k: int in range(1, AO_RAMP_CELLS + 1):
			if not obs.solid_at(c + (probe["d"] as Vector2i) * k):
				continue
			# `k - 1` rather than `k`, so the cell touching the occluder gets the constant undiminished
			# and the far end of the ramp gets a share of it rather than nothing.
			transmitted *= 1.0 - strength * (1.0 - float(k - 1) / float(AO_RAMP_CELLS))
			break   ## the nearest solid in a direction occludes; anything behind it is already blocked
	return 1.0 - transmitted


## THE WALL MATERIAL THAT SHOWS AT `c`, or `&""` for a cell this painter leaves alone. Two ways to be
## left alone, and they are opposites:
##
##   * the cell is SOLID — the terrain painter owns it, and anything drawn here would be covered;
##   * the cell has NO WALL BEHIND IT — open air, deliberately transparent so the backdrop shows through.
##     That is legacy's own rule ("cells with no wall stay transparent, so the parallax backdrop shows
##     through, which is what makes open sky read as sky") and it is what makes this painter already
##     correct for the air band `docs/NEEDS_DIRECTOR.md` P017 will generate above the surface.
##
## Split out of `paint` and returned as data, because "which cells does it decide to skip" is the half of
## this painter that can be wrong while the screen still looks plausible.
static func backs(obs: Interface.Observation, c: Vector2i) -> StringName:
	if obs == null:
		return &""
	if obs.material_at(c) != &"":
		return &""
	return obs.wall_at(c)


## Every cell in view that is open and has rock behind it. Sits between the sky and the terrain in the
## stack (`tests/body/reveal_view_setup.gd`): behind everything solid, in front of everything atmospheric.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var cell_px: int = frame.obs.cell_px
	var r: Rect2i = TerrainPainter.visit_rect(frame.obs, frame.view_world_rect, cell_px)
	for col: int in range(r.position.x, r.end.x):
		for row: int in range(r.position.y, r.end.y):
			var c := Vector2i(col, row)
			var wall: StringName = backs(frame.obs, c)
			if wall == &"":
				continue
			var box := Rect2(col * cell_px, row * cell_px, cell_px, cell_px)
			ci.draw_rect(box, wall_color(frame.look, wall, col, row), true)
			var ao: float = ao_alpha(frame.obs, c)
			if ao > 0.0:
				ci.draw_rect(box, Color(0.0, 0.0, 0.0, ao), true)
