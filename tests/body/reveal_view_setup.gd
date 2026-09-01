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
##      0  cracks     (D0275) -- over the terrain it cracks, under the body doing the cracking
##      0  crumble    (D0278) -- debris from a cell that has just gone, so it sits over the hole
##      0  the scene's own `_draw`: the body sprite and the mining overlay
##     10  the HUD    (a `CanvasLayer`, so the camera does not move it)
##
## Driven through the REAL coordinator rather than a hand-built `Frame`, which is the whole point and was
## D0244's own argument for `--sky`: `SkyPainter` reads nothing from `observe()`, so a shortcut frame
## would have drawn the same picture while proving none of the contract. Every painter added here is
## evidence that observe() -> Frame -> painter -> canvas works end to end.

const BACKDROP_Z: int = -200
const SKY_Z: int = -100
const WALL_Z: int = -60
const TERRAIN_Z: int = -50


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
	view.add_painter(WallPainter.paint).z_index = WALL_Z
	view.add_painter(TerrainPainter.paint).z_index = TERRAIN_Z
	view.add_painter(CrackPainter.paint_frame)
	# CrumblePainter keeps state (a crumble outlives the tick that spawned it), so this is an INSTANCE
	# and a bound method rather than a static Callable. The instance is owned by the layer it is bound
	# to; nothing else needs to reach it, because it spawns from the frame rather than being poked.
	view.add_painter(CrumblePainter.new().paint)
	view.add_hud().add_chip(DepthChip.paint)
	return view
