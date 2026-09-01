class_name DebugSceneCommon
extends RefCounted

## Shared by `tests/body/play_scene.gd` and `tests/body/reveal_scene.gd`. Both debug scenes record one
## PackedStringArray row per tick (four fixed fields plus one mode-specific field -- `mantle_hold` for
## play_scene, `dig_pressed` for reveal_scene) and flush-and-quit identically on `_notification`'s
## `NOTIFICATION_WM_CLOSE_REQUEST`. Extracted once `tools/quality_check/duplication.py`'s own gate
## caught both as an exact-shape duplicate cluster (`docs/DECISIONS_LEDGER.md` D0116) -- reveal_scene.gd
## was deliberately modeled closely on play_scene.gd's own shape, which is exactly the case this gate
## exists to catch, so the fix is real deduplication, not a new exclusion.


static func record_row(tick: int, move_dir: int, jump_pressed: bool, jump_held: bool, last_field: bool) -> PackedStringArray:
	return PackedStringArray([str(tick), str(move_dir), str(jump_pressed), str(jump_held), str(last_field)])


## "no aim this tick", written into BOTH aim columns. A sentinel row rather than a ninth boolean column,
## and an out-of-world value rather than a plausible one like -1 or 0: cell (0,0) is a legitimate aim, and
## a sentinel a real cell could equal is the guard-that-cannot-be-false trap this ledger keeps recording.
const NO_AIM_ROW: int = -2147483648

## The draught's four numbers, all legacy's (`legacy/scenes/main.gd:1607-1609`). Fractions and counts, not
## pixels, so none of them needs a scale conversion: the offset is a fraction OF THE CELL and the amount
## is a particle count.
const NEAR_FACE_FRAC: float = 0.4      ## back along the swing from the cell's centre -- the face you are hitting
const DRAUGHT_LIGHTEN: float = 0.25    ## dust reads lighter than the rock it came off
const DRAUGHT_BASE: int = 1            ## legacy's `1 + int(2.0 * hollow)`: always one puff...
const DRAUGHT_PER_HOLLOW: float = 2.0  ## ...and up to two more as the void behind the face gets closer


## `reveal_scene.gd`'s V2 dialect (Slice 1, D0195): the five V1 fields plus the mining hold and the aimed
## cell. Aim is state-affecting input under cursor-aim -- which cell a hold charges depends on it -- so a
## recording that omitted it could not be replayed. Kept beside `record_row` rather than replacing it:
## `play_scene.gd` still writes the five-field shape and has no aim to record.
static func record_reveal_row(tick: int, move_dir: int, jump_pressed: bool, jump_held: bool,
		dig_pressed: bool, mine_held: bool, has_aim: bool, aim_col: int, aim_row: int) -> PackedStringArray:
	var col: int = aim_col if has_aim else NO_AIM_ROW
	var row: int = aim_row if has_aim else NO_AIM_ROW
	return PackedStringArray([str(tick), str(move_dir), str(jump_pressed), str(jump_held),
		str(dig_pressed), str(mine_held), str(col), str(row)])


## Counts DISTINCT colours in a coarse sample of a captured image and pushes an error if the frame is
## effectively uniform. Distinct-count, not a mean: a mean brightness reads a nearly-black frame with one
## bright corner as "dark but fine", while the failure this guards (nothing drawn yet) is specifically that
## every pixel is the SAME. Threshold is 4 rather than 1 so an almost-empty frame -- background plus a
## couple of stray cells -- still trips it. Reported via `push_error` so `tools/run_gd_test.sh` and a human
## both see it; it deliberately does not fail the run, because a legitimately blank capture (a camera
## pointed off-world) is a real thing to want to look at.
##
## MOVED HERE from `reveal_scene.gd` (D0197) when that file crossed gate 3's 400-line limit, and it belongs
## here regardless: it is a property of the capture format, not of one scene.
##
## WHAT IT CANNOT CATCH, stated because a guard trusted past its range is worse than none: "not blank" is
## not "shows its subject". A mis-aimed camera pointed at a wall of textured clay reported 159 distinct
## colours while the body and the whole mined shaft sat outside the frame (D0197). That is why the caller
## also prints its camera and body position.
static func warn_if_blank(img: Image, path: String) -> void:
	var seen: Dictionary = {}
	var step: int = maxi(1, img.get_width() / 64)
	for x: int in range(0, img.get_width(), step):
		for y: int in range(0, img.get_height(), step):
			seen[img.get_pixel(x, y).to_rgba32()] = true
	if seen.size() < 4:
		push_error(("capture: the frame has only %d distinct colour(s) -- it is blank or near-blank. The " +
			"screenshot was still written to %s, but do not read it as a picture of the world. Likeliest " +
			"cause: the capture tick is too early for the renderer, or the camera is pointed off-world " +
			"(docs/DECISIONS_LEDGER.md D0121, D0189, D0197).") % [seen.size(), path])
	else:
		print("reveal_scene: capture has %d distinct colours in a %d-px sample grid" % [seen.size(), step])


## `what` is passed in and compared by the caller (Godot's `NOTIFICATION_WM_CLOSE_REQUEST` constant is a
## `Node` member, not visible from this `RefCounted` static context) -- this only shares the two-line
## flush-and-quit action itself.
static func finish_and_quit(flush: Callable, tree: SceneTree) -> void:
	flush.call()
	tree.quit(0)


## D0215. How far down the body is, 0 at the row it spawned on and 1 at the world's floor -- the one
## number `view/audio/score.gd` needs, and the reason that file could be lifted before any renderer
## exists. It lives HERE rather than in `Score` because `tools/layer_lint/layer_lint.py` gives `view`
## access to `interface` and `core` only: a `view/` file may not read `Body` or `TileGrid`, so the scene
## derives the fraction and hands over a float. That is the same shape every remaining lift will need.
##
## Measured from the SPAWN row, not from row 0. A shaft site spawns the body partway down already, so
## against row 0 the score would start halfway through its own arc and the descent would move it barely
## at all -- the mix has to span the part of the world the player actually travels.
static func depth_fraction(body_row: int, spawn_row: int, grid_rows: int) -> float:
	var span: int = maxi(1, grid_rows - spawn_row)
	return clampf(float(body_row - spawn_row) / float(span), 0.0, 1.0)


## D0216. Turns one tick of `sim/mining`'s own event flags into particle bursts. It lives here rather
## than in `view/fx/particles.gd` for the same reason `depth_fraction` does: a `view/` file may read
## `interface` and `core` and nothing else (`tools/layer_lint/layer_lint.py`), and this needs `Mining`'s
## flags and `MaterialLook`'s palette. `Particles` itself stays a dumb emitter that takes pixels and
## colours, which is what made it liftable unchanged.
##
## Two events, deliberately different in character, because they are cues for different things:
##   * a BREAK throws chips of the broken material's own colour, outward from each cell that went. It
##     confirms the hit landed and says what it was made of.
##   * a BREACH is the hollow tell's visual half (`sim/mining/hollow_tell.gd` is the audible half's
##     source). A slow, nearly weightless DRAUGHT drifting into the opened void, not more chips --
##     the point of the cue is that it reads as air moving, so it cannot look like debris.
static func step_mining_feedback(particles: Particles, mining: Mining, obs: Interface.Observation,
		look: MaterialLook, cell_px: int, delta: float) -> void:
	particles.advance(delta)
	if not mining.broke_this_tick:
		return
	for cell: Vector2i in mining.broke_cells:
		var at: Vector2 = Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * float(cell_px)
		var tint: Color = look.cell_color(mining.broke_material, cell.x, cell.y)
		particles.chip(at, tint, randf_range(-PI, PI))
	draught_for(particles, obs, look, cell_px)


## THE DRAUGHT, RE-WIRED (D0293). `docs/LEGACY_GAP.md` T1 #6 called the old version "lifted and
## MIS-WIRED", and it was wrong in four separate ways at once, each of which reads as a plausible cue on
## its own:
##
##   * it fired on BREACH, **after** the rock broke — legacy fires it during the CHARGE, while you are
##     still hitting a face that has a void behind it. That is the whole cue: it is a warning, not a
##     result. Firing it afterwards tells you something you have already found out;
##   * direction hardcoded DOWN, where legacy uses the true swing direction;
##   * amount hardcoded 6, where legacy's is `1 + int(2 * hollow)` — **volume rides the reading**, which
##     `sim/mining/mining.gd` quotes legacy on directly: "closing on a cavity is a crescendo you can act
##     on rather than a flag that flips". A fixed 6 is the flag;
##   * placed on the broken cell's centre, where legacy places it on the NEAR FACE, offset back along the
##     swing by `CELL * 0.4`, so the air reads as being drawn INTO the wall rather than puffing out of it.
##
## Gated on the SWING rather than on the tick, for the reason D0279 records: the ring, the draught and
## the pick animation all fire per blow in legacy, and per charging tick would be sixty a second.
##
## Reads the OBSERVATION, not the `Mining` object, even though this file may see both: `mining_swing_dir`
## exists precisely so the view does not re-derive a direction the sim already decided.
## Where the puff goes, which way it drifts and how much of it there is — as DATA, so all four of the
## things the old wiring got wrong are assertable. `Particles` reports only its own size, so a test
## written against the emitter could check that something was emitted and nothing about what.
## Returns an empty dictionary when no draught is owed, which is the difference between "no cue" and
## "a cue at the origin, pointing down".
static func draught_plan(obs: Interface.Observation, cell_px: int) -> Dictionary:
	if obs == null or cell_px <= 0 or not obs.mining_swing or not obs.mining_is_charging:
		return {}
	if obs.mining_hollow < Interface.HOLLOW_RING:
		return {}
	var cell: Vector2i = obs.mining_charging_cell
	var dir: Vector2i = obs.mining_swing_dir
	var centre: Vector2 = Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * float(cell_px)
	var hollow: float = float(obs.mining_hollow) / float(Interface.HOLLOW_FULL)
	return {
		"at": centre - Vector2(dir) * (float(cell_px) * NEAR_FACE_FRAC),
		"dir": Vector2(dir),
		"amount": DRAUGHT_BASE + int(DRAUGHT_PER_HOLLOW * hollow),
		"cell": cell,
	}


static func draught_for(particles: Particles, obs: Interface.Observation, look: MaterialLook,
		cell_px: int) -> void:
	var plan: Dictionary = draught_plan(obs, cell_px)
	if plan.is_empty():
		return
	var cell: Vector2i = plan["cell"]
	particles.draught(plan["at"],
		look.cell_color(obs.material_at(cell), cell.x, cell.y).lightened(DRAUGHT_LIGHTEN),
		plan["dir"], plan["amount"])


## The camera follow, for the debug scenes: D0273's soft follow + look-ahead + pixel-snap, replacing the
## per-tick `camera.position = body.position` that made `docs/LEGACY_GAP.md` T1 #11 "the single largest
## concentrated feel gap outside the resolver".
##
## `CameraRig` is pure `view/` and so cannot see a `Body`; this is the conversion at the boundary --
## position and velocity out of `Fx` into world px and px/s. It lives here rather than inline in
## `tests/body/reveal_scene.gd`, which sat at 397 of a 400-line cap: shaving a WHY-comment to fit is
## exactly what `docs/QUALITY.md` §2 exists to stop, so the code moved to where the reasoning has room.
##
## `screen_width` comes from the live viewport rather than a constant: the cut threshold is half a screen,
## and a hardcoded width would silently stop matching the window the moment anything resized it.
static func follow_camera(rig: CameraRig, body: Body, zoom: float, vp: Viewport, delta: float) -> Vector2:
	var screen_width: float = float(vp.get_visible_rect().size.x) if vp != null else 1920.0
	return rig.step(
		Vector2(float(body.pos_x) / float(Fx.SCALE), float(body.pos_y) / float(Fx.SCALE)),
		Vector2(float(body.vel_x) / float(Fx.SCALE), float(body.vel_y) / float(Fx.SCALE)),
		zoom, screen_width, delta)

