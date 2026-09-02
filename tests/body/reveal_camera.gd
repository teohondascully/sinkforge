class_name RevealCamera
extends RefCounted

## THE CAMERA AND ITS BOUNDS, lifted out of `tests/body/reveal_scene.gd` (D0333). The sixth seam taken out
## of that file after `RevealArgs`, `RevealRecording`, `RevealTerrainDraw`, `RevealViewSetup` and
## `RevealShutter`, and taken for the same reason each time: the scene SEQUENCES a boot, while this
## decides one thing about framing. `_ready` had reached 53 lines against a 50 cap and the file 402
## against 400; `docs/QUALITY.md` §2 records what happens when that is met by trimming instead of
## splitting -- `sim/body/body.gd` sat at exactly 400 for three commits running.

## Both are the scene's own, restated here rather than reached for: `tests/body/` has no shared constants
## file and five sibling seams already carry their own `CELL` off `Heightfield` for exactly this reason.
const CELL: int = Heightfield.TERRAIN_CELL_PX
## Legacy's `--wide-view` row cap. The full grid runs to `max_depth_m`'s ~1024 rows and centring on that
## points the camera at empty rock far below the band the mode exists to show.
const WIDE_VIEW_ROW_CAP: int = 180


## Builds the camera, makes it current, frames it, and bounds the rig to the world. Returns the camera
## rather than storing it: the scene owns the reference, because the scene is what assigns to it per tick.
static func build(scene: Node2D, rig: CameraRig, grid: TileGrid, zoom: float,
		wide_view: bool) -> Camera2D:
	var cam := Camera2D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(zoom, zoom)  ## play_scene.gd never set this either (an open
	## legibility gap, docs/WORKING.md's "camera zoom so the chamber fills more of the frame" item) --
	## default 6x makes CELL's 4px cells ~24 screen-px, close enough to read a glimmer pocket's shape
	## without the window mostly showing background. Overridable (`--zoom=`) since a density-contrast
	## shot needs the opposite trade-off -- see `--wide-view` below.
	if wide_view:
		# Centered on the topsoil band's own midpoint, not the full grid height -- the full grid runs to
		# max_depth_m's ~1024 rows, and centering on that pointed the camera at empty rock far below the
		# band this mode exists to show, producing a blank screenshot. Found by looking at the image, not
		# assumed correct from the math. As of D0276 this frames the shot rather than bounding the draw:
		# `TerrainPainter` culls against the observation's window, so whatever the camera frames is drawn.
		var view_rows: int = mini(grid.height, WIDE_VIEW_ROW_CAP)
		cam.position = Vector2(float(grid.width * CELL) / 2.0, float(view_rows * CELL) / 2.0)
	# THE CAMERA MAY NOT SHOW PAST THE WORLD (D0333). Set here rather than in the rig's constructor
	# because the rig is `view/` and cannot see a `TileGrid`; the world's pixel bounds are this scene's to
	# supply. Only the FOLLOW path is limited -- `--wide-view` returns before the rig runs and `--camera=`
	# assigns directly, so both debug framings are untouched, which is what made the omission safe to
	# carry until the world got wide enough for the body to reach an edge.
	rig.set_world_limits(Rect2(0.0, 0.0, float(grid.width * CELL), float(grid.height * CELL)))
	return cam
