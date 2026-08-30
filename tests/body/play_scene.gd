extends Node2D

## Stage-4 (g): "--play flag + recorded-input plumbing... one fixture: the hostile chamber traverse."
## Not `harness/`'s eventual real driver (`docs/ARCHITECTURE.md` §6 -- `sinkforge run --agent/--play`,
## a real scenario YAML, the full `result.json`/`telemetry.jsonl`/`input.log`/... output set) -- that
## needs `interface/` (stage 5+), which doesn't exist yet. This is a narrower, explicit precursor, the
## same shape as `sim/body` itself being built as the raw input-frame path before `interface` existed
## (`docs/ONBOARDING.md`). Lives under `tests/body/`, not `view/` or `harness/`: both of those already
## have `layer_lint`-enforced dependency contracts (`view` -> only `interface`+`core`; `harness` -> not
## `view`) this file would violate by reading `sim/body`/`sim/world` directly -- `tests/` is unpoliced,
## and this is the same shape as `tests/body/hostile_chamber.gd`/`scripted_traverse.gd` already reading
## them directly.
##
## Two run modes, chosen by a trailing `-- --play` (Godot ignores args after a bare `--` by default;
## `OS.get_cmdline_user_args()` returns exactly those, letting this file read a custom flag without any
## project-wide argument-parsing infrastructure):
##
##   godot --path . tests/body/play_scene.tscn                  # agent mode: ScriptedTraverse drives it
##   godot --path . tests/body/play_scene.tscn -- --play        # play mode: real keyboard input
##
## Agent mode exists so this file's own rendering and recording plumbing can be verified -- screenshot,
## tick-by-tick correctness -- without a human at a keyboard: the same scripted policy the acceptance
## suite already trusts (`ScriptedTraverse`), watched instead of only measured. It auto-quits once the
## traversal reaches the chamber's own scripted end column, matching `test_body_acceptance.gd`'s own
## reached-the-end criterion, or after `MAX_TICKS` as a safety cap.
##
## Controls (play mode): Left/Right or A/D to move, Space to jump (hold for full height, tap for a
## short hop -- `docs/ARCHITECTURE.md` §9's variable jump cut), Up/W held while moving toward a ledge
## for `mantle_hold` (`InputFrame`'s own field comment: "toward-and-up held"). No project-wide input map
## exists yet (nothing needed one before this), so this reads raw physical keys directly rather than
## named actions -- a real, later-revisitable choice, not an oversight (`docs/DECISIONS_LEDGER.md` D0053).
##
## Rendering is deliberately flat: terrain cells and the body are solid-color rects, no shaders, no
## lighting, no sprites, on the director's own explicit instruction -- a renderer that looks unfinished
## cannot be mistaken for a verdict on feel, only the controller can be.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const MAX_TICKS: int = 3000  ## agent-mode-only safety cap, matching test_body_acceptance.gd's own

const COLOR_BG: Color = Color(0.16, 0.16, 0.18)
const COLOR_TERRAIN: Color = Color(0.42, 0.34, 0.24)
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
var _course: bool = false
var _zoom: float = 3.0
var _look: MaterialLook = MaterialLook.new()


func _ready() -> void:
	_play_mode = "--play" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-tick="):
			_screenshot_tick = int(arg.trim_prefix("--screenshot-tick="))
		elif arg.begins_with("--screenshot-out="):
			_screenshot_path = arg.trim_prefix("--screenshot-out=")
		elif arg.begins_with("--zoom="):
			_zoom = maxf(0.5, float(arg.trim_prefix("--zoom=")))
		elif arg == "--course":
			_course = true
	# `--course` swaps the terrain and the spawn, and nothing else: the input reading, the recording, the
	# screenshot path and the camera are all unchanged, because a movement playground and an acceptance
	# chamber differ only in what the ground is shaped like. Agent mode stays on `HostileChamber` --
	# `ScriptedTraverse` encodes that chamber's own route and would walk off the first gap here.
	_grid = MovementCourse.build() if _course else HostileChamber.build()
	if _course:
		_body = Body.new(MovementCourse.spawn_x(), MovementCourse.spawn_y())
	else:
		_body = Body.new(
			Fx.from_int(HostileChamber.SPAWN_START * CELL + Body.WIDTH_PX),
			Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	_camera = Camera2D.new()
	add_child(_camera)
	# Default zoom 1 shows 1280x720 world px, against a 16x40px body -- unreadable for a feel judgment,
	# which is what this scene is for. 3.0 shows 427x240px: the 71px jump apex and the 133px running-jump
	# span both sit inside the frame with room, so an arc can be watched whole rather than inferred.
	_camera.zoom = Vector2(_zoom, _zoom)
	_camera.make_current()
	get_tree().root.title = "Sinkforge -- %s (%s mode)" % [
		"movement course" if _course else "hostile chamber", "play" if _play_mode else "agent"]


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	var input: InputFrame = _read_play_input() if _play_mode else ScriptedTraverse.next_input(_body, _grid)
	_body.tick(input, _grid)
	_record_tick(input)
	_tick_count += 1
	_update_camera()
	queue_redraw()

	# Debug-only, not part of (f)/(g)'s own scope: `--screenshot-tick=N --screenshot-out=<path>` saves
	# one frame and quits, letting a renderer change be visually spot-checked without a human watching a
	# live window. Deferred one frame past the tick so `queue_redraw()` above has actually run. Flushes
	# the recording before quitting, same as every other exit path -- an early screenshot-triggered quit
	# silently discarding whatever was recorded up to that point would be exactly the kind of quiet data
	# loss this project treats as a defect, even though this path exists only for my own verification.
	if _screenshot_tick >= 0 and _tick_count == _screenshot_tick:
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		print("play_scene: screenshot saved to %s at tick %d" % [_screenshot_path, _tick_count])
		_flush_recording()
		get_tree().quit(0)
		return

	if not _play_mode:
		# The course has no scripted route and so no "reached the end" -- `ScriptedTraverse` encodes
		# HostileChamber's own. Agent mode on the course is only ever the plumbing check (screenshot,
		# recording), so MAX_TICKS is its only stop.
		var col: int = Body._px_to_cell(_body.pos_x)
		if (not _course and col >= HostileChamber.END_START) or _tick_count >= MAX_TICKS:
			_finish_and_quit()


## Raw physical keys, not the (nonexistent) project input map -- see this file's own header comment.
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
	var toward_and_up: bool = Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
	input.mantle_hold = toward_and_up and input.move_dir != 0
	return input


func _record_tick(input: InputFrame) -> void:
	_recording.append(DebugSceneCommon.record_row(
		_tick_count, input.move_dir, input.jump_pressed, input.jump_held, input.mantle_hold))


func _update_camera() -> void:
	_camera.position = Vector2(float(_body.pos_x) / float(Fx.SCALE), float(_body.pos_y) / float(Fx.SCALE))


func _draw() -> void:
	draw_rect(Rect2(-4000, -4000, 12000, 12000), COLOR_BG, true)
	var view_center_col: int = Body._px_to_cell(_body.pos_x)
	var col_lo: int = maxi(0, view_center_col - 200)
	var col_hi: int = mini(_grid.width, view_center_col + 200)
	for col: int in range(col_lo, col_hi):
		for row: int in range(0, _grid.height):
			var cell: Vector2i = Vector2i(col, row)
			if not _grid.is_solid(cell):
				continue
			# Per-material colour rather than one flat brown (D0189's `MaterialLook`, already used by
			# `reveal_scene`). It matters here specifically: the movement course marks every target that
			# has to be READ before it is jumped to -- the perch, the pillars -- in `hardrock` against
			# `clay` ground, and a single flat fill would throw that distinction away.
			draw_rect(Rect2(col * CELL, row * CELL, CELL, CELL),
				_look.cell_color(_grid.get_material(cell), col, row), true)
	var left: float = float(_body._left_x()) / float(Fx.SCALE)
	var top: float = float(_body._top_y()) / float(Fx.SCALE)
	draw_rect(Rect2(left, top, Body.WIDTH_PX, Body.HEIGHT_PX),
		COLOR_BODY_GROUNDED if _body.on_floor else COLOR_BODY, true)


func _finish_and_quit() -> void:
	_finished = true
	_flush_recording()
	print("play_scene: agent-mode traversal finished at tick %d (col %d)" %
		[_tick_count, Body._px_to_cell(_body.pos_x)])
	get_tree().quit(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DebugSceneCommon.finish_and_quit(_flush_recording, get_tree())


## `docs/ARCHITECTURE.md` §6: a real driver eventually writes `input.log` alongside `result.json`/
## `telemetry.jsonl`/... -- this is a narrower precursor of just that one file, so a session recorded now
## is directly readable once the real driver exists, not a throwaway format needing translation later.
## One line per tick: tick index, move_dir, jump_pressed, jump_held, mantle_hold, comma-separated. Written
## to `tests/body/recordings/`, prefixed by mode (`play_`/`agent_`) so provenance -- a real human session
## versus this file's own scripted self-test -- is visible from the filename alone, never ambiguous.
func _flush_recording() -> void:
	if _recording.is_empty():
		return
	var dir_path: String = "res://tests/body/recordings"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var prefix: String = "play" if _play_mode else "agent"
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var path: String = "%s/%s_%s.log" % [dir_path, prefix, stamp]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("play_scene: could not open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_line("# sinkforge input recording -- mode=%s chamber=hostile_chamber ticks=%d" %
		[prefix, _recording.size()])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,mantle_hold")
	for row: PackedStringArray in _recording:
		f.store_line(",".join(row))
	f.close()
	print("play_scene: wrote %d ticks to %s" % [_recording.size(), path])
