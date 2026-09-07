extends SceneTree

## Alternate launcher; ordinary Main, no gameplay overrides. Files stay in --session-dir.
const Bridge = preload("res://playtest/input_bridge.gd")
const Events = preload("res://playtest/seat_events.gd")
var bridge: RefCounted = Bridge.new()
var game: Main
var session_dir: String = ""
var remaining: int = -1
var request_id: int = 0
var capturing: bool = false
var ready: bool = false
## THE FRAME IS TAKEN AT REST (D0436, stranger 10). A burst that ended mid-stride captured a body still
## sliding: the stranger aimed at the trunk where the frame showed it, the body slid a hand's width on,
## and eighteen seconds of MINE went into the air beside it. When the sequence is spent the seat releases
## every input and runs on, up to SETTLE_MAX ticks, until the body's velocity is zero -- a slide ends, a
## fall lands -- AND the camera has stopped: the rig eases after the body (`CameraRig.FOLLOW_SPEED`, the
## lead's own easing), so a frame taken the tick the body stopped still had the world sliding under the
## pointer by two metres. Then it captures. `settled_ticks` in the observation says how many it took and
## `still` whether it got there. A command with "settle": false keeps the raw cut.
const SETTLE_MAX: int = 120
const CAMERA_STILL_TICKS: int = 6   ## the pixel-snapped camera unmoved this long is at rest
var settling: int = -1              ## ticks spent settling this burst; -1 while the sequence still runs
var settle: bool = true
var _camera_prev: Vector2 = Vector2.INF
var _camera_still: int = 0
var _received_ms: int = 0
var _sent_ms: int = 0
## `"until": "event"` (D0448): the burst is cut at the first player-visible change (`seat_events.gd`).
var until_event: bool = false
var ended_by: String = "ticks"
var _events_prev: Dictionary = {}
var _airborne: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--session-dir="):
			session_dir = arg.trim_prefix("--session-dir=")
	if not session_dir.is_absolute_path() or not DirAccess.dir_exists_absolute(session_dir):
		printerr("playtest: supply an existing absolute --session-dir")
		quit(2)
		return
	if FileAccess.file_exists(session_dir.path_join("receipt.json")):
		printerr("playtest: session already used; create a new directory")
		quit(2)
		return
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1280, 720)
	Input.use_accumulated_input = false
	Settings.path = session_dir.path_join("settings.cfg")
	game = Main.new()
	game.autoboot = false
	game.save_path = session_dir.path_join("save.json")
	root.add_child(game)
	Settings.muted = true   # a seat plays on a machine somebody is using; the stranger reads a screen (D0437)
	if not game.boot(false):
		quit(2)
		return
	Settings.apply_audio()
	_write("receipt.json", {"engine": Engine.get_version_info(), "mode": "screen-only settled-between-bursts",
		"viewport": [1280, 720], "session_dir": session_dir, "pid": OS.get_process_id(), "muted": AudioServer.is_bus_mute(0)})
	ready = true
	remaining = 1


func _physics_process(_delta: float) -> bool:
	if not ready or paused:
		return false
	if remaining > 0:
		remaining -= 1
		if until_event and _event_now() != "":
			remaining = 0
			bridge.abandon()
		return false
	if settling < 0:
		# The next segment of a composed move (D0420), or the release when the sequence is spent.
		var next: int = bridge.next_segment(root)
		if next > 0:
			remaining = next - 1
			return false
		bridge.apply({}, root)
		settling = 0
	_camera_still = _camera_still + 1 if game.camera.position == _camera_prev else 0
	_camera_prev = game.camera.position
	if settle and settling < SETTLE_MAX and _moving():
		settling += 1
		return false
	paused = true
	_capture.call_deferred()
	return false


## The first player-visible change since the burst began, remembered as `ended_by`; "" while nothing has.
func _event_now() -> String:
	var o: Interface.Observation = game.view.current_frame().obs if game.view.current_frame() != null else null
	_airborne = 0 if o == null or o.on_floor else _airborne + 1
	var now: Dictionary = Events.snapshot(game.stack, game.view.current_frame(), _airborne)
	var e: String = Events.fired(_events_prev, now)
	if e != "":
		ended_by = e
	return e


## Whether the picture is still changing under a still hand: the body's velocity (the one sim fact the
## seat reads) and the camera's pixel position.
func _moving() -> bool:
	var body: Body = game.door.services()["body"]
	return body.vel_x != 0 or body.vel_y != 0 or _camera_still < CAMERA_STILL_TICKS


func _process(_delta: float) -> bool:
	if not ready or not paused or capturing:
		return false
	var path: String = session_dir.path_join("command.json")
	if not FileAccess.file_exists(path):
		return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		return false
	var command: Dictionary = value
	var next_id: int = int(command.get("id", 0))
	if next_id <= request_id:
		return false
	request_id = next_id
	if command.get("quit", false):
		bridge.apply({}, root)
		_write("response.json", {"id": request_id, "quit": true, "tick": game.tick})
		quit()
		return false
	var error: String = bridge.validate(command)
	if error != "":
		_write("response.json", {"id": request_id, "error": error})
		return false
	_write("input_%04d.json" % request_id, command)
	_received_ms = int(Time.get_unix_time_from_system() * 1000.0)   # the loop measured (D0446): pickup, play, capture
	_sent_ms = int(command.get("sent_at", 0))
	# Input callbacks must run unpaused, as in ordinary play. The first segment applies on the next
	# physics tick through `next_segment`, the rest at their boundaries (D0420).
	paused = false
	bridge.begin(command)
	settle = bool(command.get("settle", true))
	settling = -1
	_camera_still = 0
	until_event = String(command.get("until", "ticks")) == "event"
	ended_by = "ticks"
	_airborne = 0
	_events_prev = Events.snapshot(game.stack, game.view.current_frame(), 0)
	remaining = 0
	return false


func _capture() -> void:
	capturing = true
	await RenderingServer.frame_post_draw
	var path: String = session_dir.path_join("frame_%04d.png" % request_id)
	var result: Error = root.get_texture().get_image().save_png(path)
	var response: Dictionary = {"id": request_id, "tick": game.tick,
		"sim_seconds": float(game.tick) / 60.0, "screenshot": path, "capture_error": result,
		"settled_ticks": maxi(settling, 0), "still": not _moving(),
		"sent_at": _sent_ms, "received_at": _received_ms, "captured_at": int(Time.get_unix_time_from_system() * 1000.0),
		"ended_by": ended_by}
	_write("observation_%04d.json" % request_id, response)
	_write("response.json", response)
	capturing = false


func _write(name: String, data: Dictionary) -> void:
	var path: String = session_dir.path_join(name)
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
