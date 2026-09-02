class_name RevealViewSetup
extends RefCounted

## THE RENDER STACK'S COMPOSITION, lifted out of `tests/body/reveal_scene.gd` (D0276). The fourth seam
## taken out of that file after `RevealArgs`, `RevealRecording` (D0244) and `RevealTerrainDraw`, and
## taken for the same reason each time: the scene ORCHESTRATES -- argv, ticks, recording, quitting --
## while this decides which painters exist and in what order. The file was at exactly 400 of a 400-line
## cap, and `docs/QUALITY.md` §2 records what happens when that is met by trimming instead of splitting:
## `sim/body/body.gd` sat at exactly 400 for three commits running.
##
## THE ORDER HERE IS THE PICTURE, which is why it lives in one place rather than being spread across the
## scene's `_ready`. Painters are drawn in `z_index` order and, within a tie, in the order they were
## added -- so this list reads back-to-front:
##
##   -200  backdrop   (the band-tinted fill; `--sky` REPLACES it, see below)
##   -100  sky        (only under `--sky`)
##    -60  wall       (D0286) -- the plane BEHIND the play space, so it is behind everything solid
##    -50  terrain    (D0276)
##    -45  veil       (D0302) -- mass occlusion + key light, and the lamp that cuts it (D0306)
##    -40  glint      (D0300) -- the discovery twinkle, ABOVE the veil for a measured reason below
##    -35  seam       (D0308) -- the grain at the worked cell, above the veil so it stays readable
##      0  cracks     (D0275) -- over the terrain it cracks, under the body doing the cracking
##      0  crumble    (D0278) -- debris from a cell that has just gone, so it sits over the hole
##      0  the scene's own `_draw`: the body sprite and the mining overlay
##     10  the HUD    (a `CanvasLayer`, so the camera does not move it): the depth chip, then the
##                     stratum arrival plate over it (D0288)
##
## Driven through the REAL coordinator rather than a hand-built `Frame`, which is the whole point and was
## D0244's own argument for `--sky`: `SkyPainter` reads nothing from `observe()`, so a shortcut frame
## would have drawn the same picture while proving none of the contract. Every painter added here is
## evidence that observe() -> Frame -> painter -> canvas works end to end.

const BACKDROP_Z: int = -200
const SKY_Z: int = -100
const WALL_Z: int = -60
const TERRAIN_Z: int = -50
## THE VEIL LANDED 2026-09-01 (D0302, lamp D0306); this paragraph used to say it had not, and said so
## twice in one block. The ordering it argued for is the ordering that shipped, so only the tense is
## corrected: the veil sits ABOVE the terrain and the wall and BELOW the glint. It is a light layer, so
## everything it dims has to already be on the canvas — and legacy draws the glint from `_paint_lights`
## POST-veil for a measured reason its own header records: drawn UNDER the veil, "every flare was scaled
## by `_dark`, the LightLayer with BLEND_MODE_MUL that makes rock dark", so the flare's own darkness
## compensation and the veil's attenuation were the same number and cancelled exactly.
const VEIL_Z: int = -45
const GLINT_Z: int = -40
## THE GRAIN SITS ABOVE THE VEIL, for the same reason the glint does and one more (D0308). It is an AIM
## READOUT, not scenery: it answers "which way will this rock part" at the moment of the blow, and a
## readout the veil can dim is a readout that stops working in the exact place the game is played. Below
## the cracks and the body, which are the things doing the parting.
const SEAM_Z: int = -35


## Builds the coordinator, attaches it to `scene`, and hangs every painter and the HUD off it.
##
## Returns the `WorldView` rather than storing it: the scene owns the reference, because the scene is
## what calls `refresh()` on the tick it decides to render.
static func build(scene: Node2D, iface: Interface, look: MaterialLook, camera: Camera2D,
		sky: bool) -> WorldView:
	var view: WorldView = WorldView.new()
	scene.add_child(view)
	view.setup(iface, look, camera)
	# `--sky` REPLACES the backdrop rather than layering over it (D0244): the fill is opaque and would
	# cover the starfield completely.
	if sky:
		view.add_painter(SkyPainter.paint).z_index = SKY_Z
	else:
		view.add_painter(BackdropPainter.paint).z_index = BACKDROP_Z
	# THE TWO STATIC PAINTERS GO INTO THE BAKE, not onto a per-frame layer (D0326, `docs/PORT_ORDER.md` V1).
	# They are the only two on this stack whose picture cannot change unless the terrain does, and they are
	# the expensive ones: legacy measured the terrain pass at ~72% of all frame draw calls. Registered in
	# draw order — wall behind terrain — and baked into ONE quad at `WALL_Z`, which preserves that order
	# inside the target while collapsing both layers to a single draw call per frame.
	#
	# `bake_static` falls back to mounting both as ordinary layers when no render target is available
	# (headless), so this call site is correct on both paths and the picture is the same either way.
	view.add_baked_painter(WallPainter.paint)
	view.add_baked_painter(TerrainPainter.paint)
	view.bake_static(WALL_Z)
	view.add_stateful_painter(VeilPainter.new(), &"paint_frame").z_index = VEIL_Z
	view.add_painter(GlintPainter.paint).z_index = GLINT_Z
	view.add_painter(SeamPainter.paint).z_index = SEAM_Z
	view.add_painter(CrackPainter.paint_frame)
	# CrumblePainter keeps state (a crumble outlives the tick that spawned it), so it goes in as an OBJECT
	# rather than as a bound Callable. D0289: `add_painter(CrumblePainter.new().paint)` freed the painter
	# at the end of that expression -- a Callable does not keep a RefCounted alive -- and this layer drew
	# nothing for four commits while every suite passed.
	view.add_stateful_painter(CrumblePainter.new(), &"paint")
	# The plate keeps state too: an arrival is one event and the ceremony is two hundred frames. Added
	# after the depth chip so the ceremony draws over the readout it is announcing, not under it.
	view.add_hud().add_chip(DepthChip.paint)
	view.add_hud().add_stateful_chip(ArrivalPlate.new(), &"paint")
	# The legend keeps state too -- which verbs the player has demonstrated -- and it is added LAST so a
	# ceremony never draws under it. It removes itself from the picture entirely once it is done.
	view.add_hud().add_stateful_chip(KeyLegend.new(), &"paint")
	return view
