extends Node2D

## The reveal-layer debug scene (docs/GDD.md §12, claims/C004) -- same shape and same director-flagged
## rendering discipline as `tests/body/play_scene.gd` (flat colors, no shaders/sprites, so an unfinished
## look can't be mistaken for a verdict on feel), spawning real `ShaftGenerator` output against one of
## the two reveal-test sites instead of the hand-authored `HostileChamber`.
##
##   godot --path . tests/body/reveal_scene.tscn -- --site=reveal_test_dense
##   godot --path . tests/body/reveal_scene.tscn -- --play --site=reveal_test_sparse
##
## Agent mode (default) drives a short, deterministic walk-and-dig sequence toward the nearest shallow
## glimmer pocket the generated seed actually placed -- built for this scene's own verification and for
## producing a reproducible screenshot, NOT a claims/C004 measurement driver: C004 needs recorded,
## unscripted human play (`--play`), because a scripted digger that knows where glimmer is would be
## exactly the circular metric C004's own docstring rejects. `--seed=N` overrides the default seed.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const MAX_TICKS: int = 3000  ## agent-mode-only safety cap, matching play_scene.gd's own
const WIDE_VIEW_ROW_CAP: int = 180  ## `--wide-view` (D0121): both reveal-test sites' topsoil_shale_end
## is 40m = 160 rows (TERRAIN_CELLS_PER_METER=4); a little margin past it, not the whole grid.

const COLOR_BG: Color = Color(0.16, 0.16, 0.18)
const COLOR_TERRAIN: Color = Color(0.42, 0.34, 0.24)
const COLOR_GLIMMER: Color = Color(0.35, 0.85, 0.85)  ## flat cyan -- deliberately far from COLOR_TERRAIN's
## brown and COLOR_BG's near-black, so "distinct from plain rock and from dug space" is a color-distance
## claim the renderer actually backs, not just an assertion
const COLOR_BODY: Color = Color(0.85, 0.25, 0.25)
const COLOR_BODY_GROUNDED: Color = Color(0.95, 0.75, 0.15)

var _grid: TileGrid
var _body: Body
var _play_mode: bool = false
var _tick_count: int = 0
var _was_jump_held: bool = false
var _recording: Array[PackedStringArray] = []
var _camera: Camera2D
var _finished: bool = false
var _screenshot_tick: int = -1
var _screenshot_path: String = ""
var _target_glimmer_col: int = -1
var _camera_zoom: float = 6.0
var _wide_view: bool = false
var _site_id: StringName = &""
var _seed_value: int = 0


func _ready() -> void:
	_play_mode = "--play" in OS.get_cmdline_user_args()
	var site_id: StringName = &"reveal_test_dense"
	var seed_value: int = 20260826
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tick="):
			_screenshot_tick = int(arg.trim_prefix("--screenshot-tick="))
		elif arg.begins_with("--screenshot-out="):
			_screenshot_path = arg.trim_prefix("--screenshot-out=")
		elif arg.begins_with("--site="):
			site_id = StringName(arg.trim_prefix("--site="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--zoom="):
			_camera_zoom = float(arg.trim_prefix("--zoom="))
		elif arg == "--wide-view":
			_wide_view = true  ## D0121: camera centers on the whole generated area (grid midpoint), not
			## the body -- the body-following camera at zoom 6.0 shows ~28% of the topsoil band's own
			## vertical extent in one frame, which is why the first density-contrast screenshots (D0109's
			## round) read as nearly identical regardless of the real underlying count difference.
	_site_id = site_id
	_seed_value = seed_value
	var session: Dictionary = RevealSessionSetup.build(site_id, seed_value)
	_grid = session["grid"]
	_body = session["body"]
	_target_glimmer_col = session["target_glimmer_col"]
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.zoom = Vector2(_camera_zoom, _camera_zoom)  ## play_scene.gd never set this either (an open
	## legibility gap, docs/WORKING.md's "camera zoom so the chamber fills more of the frame" item) --
	## default 6x makes CELL's 4px cells ~24 screen-px, close enough to read a glimmer pocket's shape
	## without the window mostly showing background. Overridable (`--zoom=`) since a density-contrast
	## shot needs the opposite trade-off -- see `--wide-view` above.
	if _wide_view:
		# Centered on the DRAWN band's own midpoint (WIDE_VIEW_ROW_CAP), not the full grid height -- the
		# full grid runs to max_depth_m's ~1024 rows, and _draw() only ever paints the first
		# WIDE_VIEW_ROW_CAP of them in this mode. Centering on the true grid height pointed the camera at
		# an empty, undrawn region far below the topsoil band, producing a blank screenshot -- found by
		# actually looking at the captured image, not assumed correct from the math alone.
		var view_rows: int = mini(_grid.height, WIDE_VIEW_ROW_CAP)
		_camera.position = Vector2(float(_grid.width * CELL) / 2.0, float(view_rows * CELL) / 2.0)
	get_tree().root.title = "Sinkforge -- reveal (%s, %s mode)" % [site_id, "play" if _play_mode else "agent"]


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	var input: InputFrame = _read_play_input() if _play_mode else _scripted_approach_input()
	_body.tick(input, _grid)
	_record_tick(input)
	_tick_count += 1
	_update_camera()
	queue_redraw()

	if _screenshot_tick >= 0 and _tick_count == _screenshot_tick:
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		print("reveal_scene: screenshot saved to %s at tick %d" % [_screenshot_path, _tick_count])
		_flush_recording()
		get_tree().quit(0)
		return

	if not _play_mode and (_tick_count >= MAX_TICKS or (_target_glimmer_col < 0)):
		_finish_and_quit()


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
	input.dig_pressed = Input.is_physical_key_pressed(KEY_E)
	return input


## Agent mode's own verification driver -- NOT a claims/C004 measurement tool (see module docstring).
## Holds move+dig together every tick: body.tick()'s own order (horizontal resolve, THEN _handle_dig)
## means each tick either advances into space dug on the previous tick, or digs the wall now blocking
## it, so the two naturally alternate without a separate walk/dig state machine. Simple and knows the
## target column because it exists only to prove the scene renders and the dig-into-reveal path works,
## not to produce a trustworthy pull measurement.
func _scripted_approach_input() -> InputFrame:
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


func _record_tick(input: InputFrame) -> void:
	_recording.append(DebugSceneCommon.record_row(
		_tick_count, input.move_dir, input.jump_pressed, input.jump_held, input.dig_pressed))


func _update_camera() -> void:
	if _wide_view:
		return  # camera stays fixed on the grid midpoint, set once in _ready() -- not the body
	_camera.position = Vector2(float(_body.pos_x) / float(Fx.SCALE), float(_body.pos_y) / float(Fx.SCALE))


func _draw() -> void:
	draw_rect(Rect2(-4000, -4000, 12000, 12000), COLOR_BG, true)
	var view_center_col: int = Body._px_to_cell(_body.pos_x)
	var col_lo: int = maxi(0, view_center_col - 60)
	var col_hi: int = mini(_grid.width, view_center_col + 60)
	# 120-row cap only makes sense for the follow-the-body view -- `--wide-view` needs the WHOLE topsoil
	# band drawn (D0121), since the density contrast it exists to show is spread across it, not just the
	# top 120 of a band that runs 160 rows on both reveal-test sites. NOT the full grid height (up to
	# 1024 rows for max_depth_m=256): the reveal layer only ever places below row 0 and above
	# topsoil_end, so drawing past it would shrink the actually-relevant band to a sliver of a mostly
	# irrelevant screenshot. WIDE_VIEW_ROW_CAP is topsoil_end(160) + margin, not read from the site
	# config -- this scene already hardcodes plenty else about the two reveal-test sites specifically.
	var row_cap: int = mini(_grid.height, WIDE_VIEW_ROW_CAP) if _wide_view else mini(_grid.height, 120)
	for col: int in range(col_lo, col_hi):
		for row: int in range(0, row_cap):
			var material: StringName = _grid.get_material(Vector2i(col, row))
			if material == &"":
				continue
			var color: Color = COLOR_GLIMMER if material == &"glimmer" else COLOR_TERRAIN
			draw_rect(Rect2(col * CELL, row * CELL, CELL, CELL), color, true)
	var left: float = float(_body._left_x()) / float(Fx.SCALE)
	var top: float = float(_body._top_y()) / float(Fx.SCALE)
	draw_rect(Rect2(left, top, Body.WIDTH_PX, Body.HEIGHT_PX),
		COLOR_BODY_GROUNDED if _body.on_floor else COLOR_BODY, true)


func _finish_and_quit() -> void:
	_finished = true
	_flush_recording()
	print("reveal_scene: agent-mode run finished at tick %d" % _tick_count)
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
	if _recording.is_empty():
		return
	var dir_path: String = "res://tests/body/recordings"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var prefix: String = "play" if _play_mode else "agent"
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var path: String = "%s/reveal_%s_%s.log" % [dir_path, prefix, stamp]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("reveal_scene: could not open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_line("# sinkforge reveal-scene input recording -- mode=%s ticks=%d site=%s seed=%d" %
		[prefix, _recording.size(), _site_id, _seed_value])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,dig_pressed")
	for row: PackedStringArray in _recording:
		f.store_line(",".join(row))
	f.close()
	print("reveal_scene: wrote %d ticks to %s" % [_recording.size(), path])
