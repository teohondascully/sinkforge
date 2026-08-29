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
const SHALLOW_ROW_LIMIT: int = 30  ## how far down the scan looks for a "near-surface" glimmer pocket
const APPROACH_OFFSET_COLS: int = 6  ## spawn this many columns left of the found pocket

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
	_grid = ShaftGenerator.generate(StrataData.get_site(site_id), seed_value)
	var spawn_col: int = _find_spawn_column()
	_carve_entry_shaft(spawn_col)
	var spawn_row: int = Body.HEIGHT_PX / CELL / 2  # shallowest row whose top edge isn't already past row 0
	_body = Body.new(spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE, Fx.from_int(spawn_row * CELL))
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_camera.zoom = Vector2(6.0, 6.0)  ## play_scene.gd never set this either (an open legibility gap,
	## docs/WORKING.md's "camera zoom so the chamber fills more of the frame" item) -- 6x makes CELL's
	## 4px cells ~24 screen-px, close enough to read a glimmer pocket's shape without the window mostly
	## showing background
	get_tree().root.title = "Sinkforge -- reveal (%s, %s mode)" % [site_id, "play" if _play_mode else "agent"]


## `ShaftGenerator` output is solid rock/clay from row 0 down -- pure geology, no pre-existing opening
## (the real game's fiction is a shaft the player already bored, which this scene doesn't model). Carves
## a small, explicit entry pocket the width of the body, standing height only, so the scene has somewhere
## to spawn a body without it starting embedded -- the same shape `tests/body/hostile_chamber.gd` uses
## for its own SPAWN_START, scoped down to just enough headroom to stand.
func _carve_entry_shaft(col: int) -> void:
	var rows: int = Body.HEIGHT_PX / CELL + 2
	for dc: int in range(0, 4):  # Body.WIDTH_PX/CELL cells wide
		for row: int in rows:
			_grid.excavate(Vector2i(col + dc, row))


## First shallow (row < SHALLOW_ROW_LIMIT) glimmer cell found, scanning columns left to right --
## deterministic given a deterministic grid, so the same (site, seed) always picks the same demo column.
## Skips any candidate closer to the left edge than APPROACH_OFFSET_COLS: a spawn column clamped to 0
## would start with the body's own CENTER (used for the col comparison below) already past a too-close
## target, ending the approach on tick 1 with nothing dug -- found by actually running this scene, not
## reasoned out in advance.
func _find_spawn_column() -> int:
	for col: int in _grid.width:
		if col < APPROACH_OFFSET_COLS:
			continue
		for row: int in SHALLOW_ROW_LIMIT:
			if _grid.get_material(Vector2i(col, row)) == &"glimmer":
				_target_glimmer_col = col
				return col - APPROACH_OFFSET_COLS
	return _grid.width / 2  # no shallow glimmer this seed/site -- park in the middle rather than crash


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
	_camera.position = Vector2(float(_body.pos_x) / float(Fx.SCALE), float(_body.pos_y) / float(Fx.SCALE))


func _draw() -> void:
	draw_rect(Rect2(-4000, -4000, 12000, 12000), COLOR_BG, true)
	var view_center_col: int = Body._px_to_cell(_body.pos_x)
	var col_lo: int = maxi(0, view_center_col - 60)
	var col_hi: int = mini(_grid.width, view_center_col + 60)
	for col: int in range(col_lo, col_hi):
		for row: int in range(0, mini(_grid.height, 120)):
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
## has no mantle content to test). tick,move_dir,jump_pressed,jump_held,dig_pressed.
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
	f.store_line("# sinkforge reveal-scene input recording -- mode=%s ticks=%d" % [prefix, _recording.size()])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,dig_pressed")
	for row: PackedStringArray in _recording:
		f.store_line(",".join(row))
	f.close()
	print("reveal_scene: wrote %d ticks to %s" % [_recording.size(), path])
