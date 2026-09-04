extends Node2D

## The reveal-layer debug scene (docs/GDD.md §12, claims/C004) -- same shape and same director-flagged
## rendering discipline as `tests/body/play_scene.gd` (flat colors, no shaders/sprites, so an unfinished
## look can't be mistaken for a verdict on feel), spawning real `ShaftGenerator` output against one of
## the two reveal-test sites instead of the hand-authored `HostileChamber`.
##
##   godot --path . tests/body/reveal_scene.tscn -- --site=reveal_test_dense
##   godot --path . tests/body/reveal_scene.tscn -- --play --site=reveal_test_sparse
##
## **`--play` IS WHAT GIVES YOU A WINDOW TO SIT IN.** Without it this scene drives itself for ~12 ticks
## and exits, which looks like a broken launch if you were expecting to play (D0248 -- the director hit
## exactly this following a line in `docs/NEEDS_DIRECTOR.md` that omitted the flag). To look at the sky:
##
##   godot --path . tests/body/reveal_scene.tscn -- --play --sky --zoom=6.5 --camera=24,84
##   (the camera row is relative to the surface, which is `ShaftGenerator.SKY_ROWS` -- P017/D0292)
##
## Agent mode (default) drives a short, deterministic walk-and-dig sequence toward the nearest shallow
## glimmer pocket the generated seed actually placed -- built for this scene's own verification and for
## producing a reproducible screenshot, NOT a claims/C004 measurement driver: C004 needs recorded,
## unscripted human play (`--play`), because a scripted digger that knows where glimmer is would be
## exactly the circular metric C004's own docstring rejects. `--seed=N` overrides the default seed.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const MAX_TICKS: int = 3000  ## agent-mode-only safety cap, matching play_scene.gd's own
## `--wide-view` (D0121): both reveal-test sites' topsoil_shale_end is 40m = 160 rows
## (TERRAIN_CELLS_PER_METER=4), plus margin. Since D0276 this FRAMES the camera; it no longer bounds the
## draw, which the painter does from the observation's own window.
const WIDE_VIEW_ROW_CAP: int = 180

## D0189 (Slice 0): terrain and glimmer are no longer flat constants -- `MaterialLook` derives each
## cell's fill from `data/materials`' lifted appearance records. The two removed constants were
## `COLOR_TERRAIN = Color(0.42, 0.34, 0.24)` (kept as `MaterialLook`'s unmapped-material fallback, so an
## id with no appearance block still draws) and `COLOR_GLIMMER = Color(0.35, 0.85, 0.85)`.
##
## COLOR_GLIMMER carried a real claim in its own comment -- "deliberately far from COLOR_TERRAIN's brown
## and COLOR_BG's near-black, so 'distinct from plain rock and from dug space' is a color-distance claim
## the renderer actually backs, not just an assertion". Replacing it with a data-driven colour would have
## retired that claim silently. It is instead re-measured against the new records, over the real
## depth range and both nugget branches, by `tests/test_material_palette.gd`.
const COLOR_BG: Color = BackdropPainter.COLOR_BG  ## D0276: one definition, in the painter that fills it
const COLOR_BODY: Color = Color(0.85, 0.25, 0.25)
const COLOR_BODY_GROUNDED: Color = Color(0.95, 0.75, 0.15)
## `--mine-down` (D0195). The scan window only has to cover the reach itself -- 51.2px is 12.8 terrain
## cells -- so 16 rows is the reach plus margin, not an arbitrary depth.
const MINE_DOWN_SCAN_ROWS: int = 16
## How far the scripted shaft sinks before the run is done, in terrain cells. 24 cells is 96px, six logic
## tiles, six metres: deep enough that descending is unambiguous rather than a single ledge step.
const MINE_DOWN_TARGET_ROWS: int = 24

var _grid: TileGrid
var _body: Body
var _play_mode: bool = false
var _tick_count: int = 0
var _was_jump_held: bool = false
var _was_dig_held: bool = false  ## D0188: dig needs the same edge latch jump has -- see `_dig_edge()`.
var _recording: Array[PackedStringArray] = []
var _camera: Camera2D
var _finished: bool = false
var _screenshot_tick: int = -1
## Set for the duration of the shutter's awaits, so the world holds still while the pixels are read.
var _shutter_held: bool = false
var _screenshot_path: String = ""
var _target_glimmer_col: int = -1
var _camera_zoom: float = 6.0  ## D0325: see reveal_args.gd for why not the ported ladder yet
var _wide_view: bool = false
var _site_id: StringName = &""
var _seed_value: int = 0
var _look: MaterialLook = MaterialLook.new()  ## D0189: the lifted palette (Slice 0)
var _mining: Mining = Mining.new()  ## D0195: the cursor-aim mining verb (Slice 1)
## D0215: the first sound this build makes -- a pure function of depth. Constructed in `_ready`, NOT at
## declaration: `tests/test_reveal_scene_dig_edge.gd` does `RevealScene.new()` without adding it to the
## tree, and a `Node` built there would never be freed, leaking into the ObjectDB warning at exit that
## `tools/run_gd_test.sh` reads as a bare ERROR.
var _score: Score = null
var _particles: Particles = Particles.new()  ## D0216: chips on a break, a draught on a breach
var _falling: FallingItems = FallingItems.new()  ## 6e, D0365: the cosmetic drops off the flow channel
var _payouts: Payouts = Payouts.new()  ## 6d, D0365: the "+N" tick when the pack gains
var _audio: SceneAudio = null  ## D0296 voices + the beds (6f, D0366); view/audio/scene_audio.gd
var _mine_down: bool = false  ## `--mine-down`: agent mode sinks a shaft instead of walking to glimmer
var _last_input: InputFrame = InputFrame.new()  ## what `_draw` should draw the reticle from
var _spawn_row: int = 0  ## the row the body started on -- `--mine-down`'s descent is measured against it
var _fixed_camera: Vector2 = Vector2.ZERO  ## `--camera=col,row`, for comparable milestone frames
var _has_fixed_camera: bool = false  ## a real bool, not a Vector2 compared against null (D0194's note)
var _sky: bool = false  ## `--sky` (D0244): draw the lifted SkyPainter behind the world
var _sky_view: WorldView = null  ## the real coordinator, so this proves the whole contract
var _rig: CameraRig = CameraRig.new()  ## D0273: the ported follow; warped to the spawn in `_ready`


func _ready() -> void:
	# **VSYNC OFF, BECAUSE A TIMING HARNESS MUST NOT MEASURE THE PANEL** (D0340). Legacy states the trap at
	# `legacy/tools/check_frametime.gd:29`: *"When it is on, every frame that fits inside the refresh
	# interval measures as exactly the refresh interval. A game with 4ms of headroom and one with 0.1ms
	# both report a perfect 8.33, and the number says nothing."* This session walked into it — three
	# consecutive optimisations measured 15.9 ms/tick, which is the 60 Hz interval, while the per-painter
	# instrument showed the work inside the frame still falling. The wall-clock number had stopped moving
	# because it had stopped measuring us.
	#
	# Safe to do unconditionally here: this scene is a harness, never the shipped game, and every frame it
	# renders is either a screenshot or a tick it is deliberately timing.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var site: Dictionary = _parse_args()  ## sets `_play_mode` too, before the title below reads it
	var site_id: StringName = site["site_id"]
	var seed_value: int = site["seed"]
	_site_id = site_id
	_seed_value = seed_value
	Controls.register()  ## D0194: idempotent; MINE has to exist in InputMap before the first poll
	var session: Dictionary = RevealSessionSetup.build(site_id, seed_value)
	_grid = session["grid"]
	_body = session["body"]
	_target_glimmer_col = session["target_glimmer_col"]
	_spawn_row = Body._px_to_cell(_body.pos_y)
	_score = Score.new()
	add_child(_score)
	# THE FRAMING IS DERIVED FROM THE WORLD, not from a constant (D0335). Done here rather than in
	# `RevealArgs` because argv is parsed before the world exists and the right zoom depends on how wide
	# the world turned out to be -- P031's whole finding was that one hardcoded number cannot be right for
	# a 64-metre play site and a 12-metre test site at once.
	if _camera_zoom <= 0.0:
		_camera_zoom = CameraRig.default_zoom_for(float(_grid.width * CELL))
	_camera = RevealCamera.build(self, _rig, _grid, _camera_zoom, _wide_view)
	_build_view()
	# THE GLOBAL RNG IS SEEDED FROM THIS RUN'S OWN SEED (D0304), and it is the last thing standing
	# between a capture and being reproducible. `view/fx/particles.gd` uses `randf_range` and its header
	# argues correctly that this is safe: a particle never feeds back into the sim, so it cannot make a
	# replay diverge. That argument names the SIM as its frame and is silent about the other one -- an
	# unseeded global RNG also means no two screenshots of the same commit at the same tick can ever be
	# compared, and capture-diffing is the instrument that found the crumble painter never drawing
	# (D0289) and the glint's population being 93% short (D0300). Measured: 33,572 pixels of the `aim`
	# moment moved between two runs of one commit, all of it chip debris.
	#
	# Seeded here rather than in `particles.gd`, because the file is a verbatim lift and `randf` is where
	# legacy put it. What was missing was not a different RNG; it was anyone deciding where it starts.
	seed(hash(_seed_value))
	_audio = SceneAudio.new()
	add_child(_audio)
	_audio.setup(_seed_value)
	get_tree().root.title = "Sinkforge -- reveal (%s, %s mode)" % [site_id, "play" if _play_mode else "agent"]


## The render stack lives in `view/view_stack.gd` (D0276), which carries the painter order
## and why it is the picture. This scene keeps only the call, because WHEN to build it is scene work.
func _build_view() -> void:
	_sky_view = ViewStack.build(self, Interface.new(_grid, _body, _mining), _look, _camera, _sky,
		_falling, _payouts)


## Applies `RevealArgs.parse()` to this scene's fields, and returns the two the caller needs by name.
##
## PARSING left this file (D0244): it was 37 lines of non-scene work in a file at 398 against a 400 cap,
## and it could not be tested where it was because it read `OS.get_cmdline_user_args()` directly.
## Applying stays, because deciding what a flag DOES to a scene is scene work.
func _parse_args() -> Dictionary:
	var cfg: Dictionary = RevealArgs.parse(OS.get_cmdline_user_args())
	_screenshot_tick = cfg["screenshot_tick"]
	_screenshot_path = cfg["screenshot_path"]
	_camera_zoom = cfg["camera_zoom"]
	_fixed_camera = cfg["fixed_camera"]
	_has_fixed_camera = cfg["has_fixed_camera"]
	_mine_down = cfg["mine_down"]
	_wide_view = cfg["wide_view"]
	_sky = cfg["sky"]
	_play_mode = cfg["play"]
	if int(cfg["bite_radius"]) >= 0:
		_mining.bite_radius = int(cfg["bite_radius"])
	return {"site_id": cfg["site_id"], "seed": cfg["seed"]}


func _physics_process(delta: float) -> void:
	if _finished or _shutter_held:
		return
	if _sky_view != null:
		_sky_view.refresh()
	_score.set_depth(DebugSceneCommon.depth_fraction(
		Body._px_to_cell(_body.pos_y), _spawn_row, _grid.height), delta)
	var input: InputFrame = _read_play_input() if _play_mode else _scripted_approach_input()
	_body.tick(input, _grid)
	# Mining runs AFTER the body moves, so the reach test uses this tick's own position rather than the
	# previous one's -- the same reason `_handle_jump` sits after the vertical resolve in `body.gd`. The
	# replay driver runs the two in this same order; if they ever diverge, a replay stops matching its
	# own live session and `test_reveal_replay_driver.gd` says so.
	_mining.mine(_grid, _body.pos_x, _body.pos_y, Vector2i(input.aim_col, input.aim_row),
		input.mine_held and input.has_aim)
	_step_mining_feedback(delta)
	_last_input = input
	_record_tick(input)
	_tick_count += 1
	_update_camera(delta)
	queue_redraw()

	if _screenshot_tick >= 0 and _tick_count == _screenshot_tick:
		# Held across the shutter's awaits so the world stops while the pixels are read; the reason,
		# and the numbers, are in `tests/body/reveal_shutter.gd` (D0304).
		_shutter_held = true
		RevealShutter.report_subject(_sky_view.current_frame() if _sky_view != null else null, _tick_count)
		await RevealShutter.capture(self, _screenshot_path, _tick_count, _camera, _camera_zoom, _body,
			_sky_view)
		_flush_recording()
		get_tree().quit(0)
		return

	if not _play_mode and (_tick_count >= MAX_TICKS or _agent_run_is_done()):
		_finish_and_quit()


## Both halves of the mining tell, from ONE frame. Split out of `_physics_process` at QUALITY gate 4's
## 50-line limit, and the seam is the right one: everything else in that function advances the world,
## and this only reads what it did.
##
## Legacy fires the ring and the draught from a single site and calls the draught "the same tell for a
## player with the sound off" (D0293, D0296). They read one observation here for the same reason: two
## paths to one cue can disagree about which tick they are describing, and this one cannot.
##
## The OBSERVATION, not the `_mining` object, even though this scene holds both -- see `draught_for`.
func _step_mining_feedback(delta: float) -> void:
	var frame: Frame = _sky_view.current_frame() if _sky_view != null else null
	DebugSceneCommon.step_mining_feedback(_particles, _mining,
		frame.obs if frame != null else null, _look, CELL, delta)
	if frame != null and _sky_view != null:
		WaterDrips.spawn(frame.obs, _particles, _sky_view.view_world_rect(), delta)   # 6a, D0362
	var landings: Dictionary = _falling.take_landings()   # 6e, D0365: consumed once; one pop per landed cell
	for cell: Vector2i in landings:
		_particles.pop(landings[cell]["pos"], landings[cell]["color"])
	if _audio != null:
		_audio.note_frame(frame, delta)


## Agent mode's own stopping condition. `--mine-down` runs until the body has actually DESCENDED the target
## depth -- measured against the spawn row, not against how many cells were broken, because breaking rock
## the body then fails to fall into is exactly the outcome this run exists to rule out.
func _agent_run_is_done() -> bool:
	if not _mine_down:
		return _target_glimmer_col < 0
	return Body._px_to_cell(_body.pos_y) - _spawn_row >= MINE_DOWN_TARGET_ROWS


func _read_play_input() -> InputFrame:
	var input: InputFrame = InputFrame.new()
	var left: bool = Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)
	var right: bool = Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)
	if left and not right:
		input.move_dir = -1
	elif right and not left:
		input.move_dir = 1
	var jump_held: bool = Input.is_physical_key_pressed(KEY_SPACE)
	input.jump_held = jump_held
	input.jump_pressed = jump_held and not _was_jump_held
	_was_jump_held = jump_held
	input.dig_pressed = _dig_edge(Input.is_physical_key_pressed(KEY_E))
	# Cursor-aim mining (Slice 1). `Controls.pressed`/`Controls.pointer_world` rather than `Input.*`
	# directly: both go through the deafness switch, and the pointer goes through the posable accessor, so
	# a harness can aim this scene without touching the OS cursor and a measurement can assert it didn't.
	input.mine_held = Controls.pressed(Controls.MINE)
	_set_aim(input, Controls.pointer_world(self))
	return input


## Resolves a world point to the terrain cell the player is aiming at. `has_aim` is false off the edge of
## the world rather than clamping to the nearest valid cell -- clamping would silently mine the rim
## whenever the cursor left the window.
func _set_aim(input: InputFrame, world: Vector2) -> void:
	var cell: Vector2i = Vector2i(floori(world.x / float(CELL)), floori(world.y / float(CELL)))
	input.aim_col = cell.x
	input.aim_row = cell.y
	input.has_aim = _grid.in_bounds(cell)


## The dig half of the same edge latch the two jump lines above implement (D0188, Defect B). Until this
## existed, line 127 assigned the RAW held state straight into `dig_pressed`, which `InputFrame` documents
## as edge-triggered ("true only on the tick the button transitioned to held ... not a
## hold-to-clear-a-wall auto-repeat", D0110) -- so one physical hold recorded as one event per held tick.
## Measured, not inferred: the director's own 807-tick session recorded a single unbroken 30-tick hold as
## 30 events (`tests/body/recordings/reveal_play_2026-08-30T02-04-24.log`, the only dig input in it).
##
## Extracted as a named function rather than written inline like jump's, for one reason: `_read_play_input()`
## polls real hardware and so cannot run headless, which would leave the fix untestable. This function is
## the whole state machine and `tests/test_reveal_scene_dig_edge.gd` drives it over hold PATTERNS, asserting
## event COUNTS -- rather than re-deriving `held and not was_held` in the test, which would be the
## self-referential mutation test D0112 records as having hidden a real off-by-one.
func _dig_edge(dig_held: bool) -> bool:
	var pressed: bool = dig_held and not _was_dig_held
	_was_dig_held = dig_held
	return pressed


## Agent mode's own verification driver -- NOT a claims/C004 measurement tool (see module docstring).
## Holds move+dig together every tick: body.tick()'s own order (horizontal resolve, THEN BodyDig.handle)
## means each tick either advances into space dug on the previous tick, or digs the wall now blocking
## it, so the two naturally alternate without a separate walk/dig state machine. Simple and knows the
## target column because it exists only to prove the scene renders and the dig-into-reveal path works,
## not to produce a trustworthy pull measurement.
func _scripted_approach_input() -> InputFrame:
	if _mine_down:
		return _mine_down_input()
	var input: InputFrame = InputFrame.new()
	if _target_glimmer_col < 0:
		return input
	var body_col: int = Body._px_to_cell(_body.pos_x)
	if body_col >= _target_glimmer_col:
		_target_glimmer_col = -1  # arrived -- agent-mode run is done
		return input
	input.move_dir = 1
	input.dig_pressed = true
	return input


## `--mine-down` agent mode: sink a shaft straight down through the body's own footprint. This exists to
## give the Slice 1 mining verb a deterministic, headless proof -- an agent trace is NOT a human `--play`
## session and the two are different evidence (`tests/body/recordings/README.md`), but it is mechanically
## reproducible, which a human session is not.
##
## It aims at the SHALLOWEST solid cell under the body's own width, not at one column: the body is 16px
## wide, four terrain cells, so a one-cell-wide hole is something it can never descend into. Clearing the
## shallowest cell across the footprint first means the shaft comes down layer by layer and the body falls
## into each one as it opens -- which is precisely the acceptance question, "can the body descend into what
## it mined", answered by construction rather than by hoping.
func _mine_down_input() -> InputFrame:
	var input: InputFrame = InputFrame.new()
	var left_col: int = Body._px_to_cell(_body._left_x())
	var right_col: int = Body._px_to_cell(_body._right_x() - 1)
	var feet_row: int = Body._px_to_cell(_body._bottom_y() - 1)
	var best_row: int = 1 << 30
	var best_col: int = -1
	for col: int in range(left_col, right_col + 1):
		for row: int in range(feet_row, feet_row + MINE_DOWN_SCAN_ROWS):
			var cell: Vector2i = Vector2i(col, row)
			if not _grid.in_bounds(cell):
				break
			if not _grid.is_solid(cell):
				continue
			if _grid.is_solid(cell) and Mining.in_reach(_body.pos_x, _body.pos_y, cell) and row < best_row:
				best_row = row
				best_col = col
			break  # only the shallowest solid cell in this column is a candidate
	if best_col < 0:
		return input
	input.has_aim = true
	input.aim_col = best_col
	input.aim_row = best_row
	input.mine_held = true
	return input


func _record_tick(input: InputFrame) -> void:
	_recording.append(DebugSceneCommon.record_reveal_row(
		_tick_count, input.move_dir, input.jump_pressed, input.jump_held, input.dig_pressed,
		input.mine_held, input.has_aim, input.aim_col, input.aim_row))


func _update_camera(delta: float) -> void:
	if _wide_view:
		return  # camera stays fixed on the grid midpoint, set once in _ready() -- not the body
	_camera.position = _fixed_camera if _has_fixed_camera else DebugSceneCommon.follow_camera(
		_rig, _body, _camera_zoom, get_viewport(), delta)


func _draw() -> void:
	# The band-tinted backdrop moved to `view/visuals/backdrop_painter.gd` (D0276) -- it is the bottom of
	# the painter stack now, not a fill in this node's own draw call. It covered the terrain painter the
	# moment terrain moved, which is D0244's finding one layer down; the painter's header carries it.
	MinerDraw.draw(self, _sky_view.current_frame() if _sky_view != null else null, _tick_count,
		COLOR_BODY, COLOR_BODY_GROUNDED)
	# Drawn last so the reach ring and reticle sit over the terrain and the body rather than under them.
	MiningOverlay.draw(self, _grid, _mining, _body.pos_x, _body.pos_y,
		_last_input.has_aim, Vector2i(_last_input.aim_col, _last_input.aim_row))
	_particles.draw(self)  ## D0216: last, so chips and the draught sit over the terrain they came from


func _finish_and_quit() -> void:
	_finished = true
	_flush_recording()
	print("reveal_scene: agent-mode run finished at tick %d" % _tick_count)
	# D0248: say what just happened in the words of someone who expected a WINDOW. This exit is correct
	# behaviour and is indistinguishable from a crash -- the engine banner, a few lines, and the process
	# is gone. The director hit it twice from a documented command, and the second time is what makes this
	# a design defect rather than a typo: the mode that a human almost never wants is the default, and it
	# announced itself only in a vocabulary ("agent-mode run") that already assumes you knew.
	print("reveal_scene: this was AGENT mode (the default) -- it drives itself and exits. "
		+ "For a window you can play in, add --play:")
	# The camera row is COMPUTED, not typed. D0248 made this line exist because the director hit
	# agent mode twice from a documented command; a hint that hands them a camera pointing into the sky
	# (P017/D0292 moved the surface to row `SKY_ROWS`) would be the same class of defect one layer on --
	# a documented invocation that does not do what it says.
	print("  godot --path . tests/body/reveal_scene.tscn -- --play --sky --zoom=6.5 --camera=24,%d"
		% (ShaftGenerator.SKY_ROWS + 4))
	get_tree().quit(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DebugSceneCommon.finish_and_quit(_flush_recording, get_tree())


## Same format as play_scene.gd's own recording, plus dig_pressed in place of mantle_hold (this scene
## has no mantle content to test). tick,move_dir,jump_pressed,jump_held,dig_pressed. Unlike play_scene.gd
## (always the same fixed `HostileChamber`), this scene's grid varies by `(site, seed)` -- both are
## stored in the header comment (D0129) so `reveal_replay_driver.gd` can rebuild the exact grid a
## recording was played against; `play_scene.gd`'s own recordings need no such field.
func _flush_recording() -> void:
	RevealRecording.write(_recording, _play_mode, _site_id, _seed_value, _mining.bite_radius)
