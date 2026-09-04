class_name Main
extends Node2D

## THE GAME'S ENTRY POINT (A' step 6q, D0380): `godot --path .` runs this. The plan's last step 6 item --
## "a main scene in `shell/` so the game runs (today nothing does; `project.godot` has no main scene)".
##
## WHAT IT OWNS: the session (`Session.new_game`, or the slot restored over it), the tick (60 Hz: the hands
## read once, the body moved through the door, the verbs applied, the view refreshed), the camera rig, the
## scene-side effects (particles, drips, landings, the audio rig), the HUD bridge (the settings page fed
## and answered, the map key, the save key), and the save on the close box. WHAT IT DOES NOT: anything a
## painter, the sim or the door already decides. The debug scene (`tests/body/reveal_scene.gd`) keeps its
## agent mode and its flags; this is the human's seat only.
##
## `autoboot` is true in the scene file and false in a test, which calls `boot(false)` itself so a real
## save on the machine is never loaded into a fixture.

const SITE: StringName = &"shallow_clay"   ## the site the tutorial start is authored for
const START: StringName = &"tutorial"
const SEED: int = 20260826
const KEY_HINTS: String = "hints"
const COLOR_BODY := Color(0.85, 0.25, 0.25)
const COLOR_BODY_GROUNDED := Color(0.95, 0.75, 0.15)
const BOOT_LINE: String = "SINKFORGE_BOOT"

var autoboot: bool = true
var booted: bool = false
var door: Interface = null
var stack: ViewStack = null
var view: WorldView = null
var tick: int = 0
var camera: Camera2D = null
var rig: CameraRig = CameraRig.new()
var zoom: float = 1.0
var look: MaterialLook = MaterialLook.new()
var falling: FallingItems = FallingItems.new()
var payouts: Payouts = Payouts.new()
var particles: Particles = Particles.new()
var audio: SceneAudio = null
var hands: PlayInput = PlayInput.new()
var last_input: InputFrame = InputFrame.new()
var save_path: String = SaveGame.SLOT
## `--quit-after=N`: run N ticks and exit 0, printing the boot line with the count -- the smoke
## `tools/check_headed_boot.sh` boots `godot --path .` with, so "the game runs" is a checked claim.
var quit_after: int = -1


func _ready() -> void:
	quit_after = parse_quit_after(OS.get_cmdline_user_args())
	if autoboot:
		boot(true)


## The one flag the seat takes, as a pure function of the argv so a test can pose it.
static func parse_quit_after(args: PackedStringArray) -> int:
	for a: String in args:
		if a.begins_with("--quit-after="):
			return maxi(int(a.substr("--quit-after=".length())), 0)
	return -1


## Build the session and the seat. Returns false when the start refuses.
func boot(load_save: bool) -> bool:
	Settings.persist = load_save
	Controls.register()
	Settings.load_settings()
	door = Session.new_game(StrataData.get_site(SITE), SEED, START)
	if door == null:
		push_error("boot: the start refused: %s" % WorldSeeder.last_refusal)
		return false
	camera = Camera2D.new()
	add_child(camera)
	if camera.is_inside_tree():
		camera.make_current()
	zoom = CameraRig.ZOOM_LEVELS[clampi(Settings.zoom_idx, 0, CameraRig.ZOOM_LEVELS.size() - 1)]
	camera.zoom = Vector2(zoom, zoom)
	stack = ViewStack.build_stack(self, door, look, camera, true, falling, payouts)
	view = stack.view
	if load_save and FileAccess.file_exists(save_path):
		restore(SaveGame.read(save_path))
	var body: Body = door.services()["body"]
	rig.warp_to(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE))
	camera.position = rig.step(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE), Vector2.ZERO, zoom, 1280.0, 0.0)
	audio = SceneAudio.new()
	add_child(audio)
	audio.setup(SEED)
	if is_inside_tree():
		get_tree().root.title = "Sinkforge"
	booted = true
	print("%s site=%s seed=%d start=%s" % [BOOT_LINE, SITE, SEED, START])
	return true


## The session with the shell's own key: the lessons the hints have taught.
func capture_session() -> Dictionary:
	var env: Dictionary = Session.capture(door)
	if stack != null and stack.hints != null:
		env[KEY_HINTS] = stack.hints.taught_ids()
	return env


func restore(env: Dictionary) -> bool:
	if env.is_empty() or not Session.restore(door, env):
		return false
	if stack != null and stack.hints != null and env.get(KEY_HINTS) is Array:
		stack.hints.restore_taught(env[KEY_HINTS])
	return true


func save() -> bool:
	return SaveGame.write(save_path, capture_session())


func _physics_process(delta: float) -> void:
	if not booted:
		return
	var page_open: bool = stack.settings != null and stack.settings.open
	var frame_in: InputFrame = _read_hands(page_open)
	door.apply(Command.move(frame_in))
	if not page_open:
		for c: Command in hands.verbs(Controls.pressed, _digit_down, PlayInput.aim_logic_of(frame_in)):
			door.apply(c)
	_hud_keys(page_open)
	last_input = frame_in
	view.refresh()
	_effects(delta)
	tick += 1
	if quit_after >= 0 and tick >= quit_after:
		print("%s ticked=%d" % [BOOT_LINE, tick])
		get_tree().quit(0)
		return
	var body: Body = door.services()["body"]
	camera.position = rig.step(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE),
		Vector2(float(body.vel_x), float(body.vel_y)) / float(Fx.SCALE), zoom, float(get_viewport().get_visible_rect().size.x), delta)
	queue_redraw()


## The hands, deaf while the settings page is open: a modal takes the keys, and the body stands still.
func _read_hands(page_open: bool) -> InputFrame:
	var cell_px: int = Interface.Observation.CELL_PX
	if page_open:
		return hands.read(func(_a: StringName) -> bool: return false, Vector2.ZERO, cell_px, func(_c: Vector2i) -> bool: return false)
	var grid: TileGrid = (door.services()["world"] as World).grid
	var grid_ok: Callable = func(c: Vector2i) -> bool: return grid.in_bounds(c)
	return hands.read(Controls.pressed, Controls.pointer_world(self), cell_px, grid_ok)


static func _digit_down(i: int) -> bool:
	return Input.is_physical_key_pressed(KEY_1 + i)


func _hud_keys(page_open: bool) -> void:
	var keys: Dictionary = hands.hud_keys(Controls.pressed)
	if bool(keys["settings"]) and stack.settings != null:
		stack.settings.open = not stack.settings.open
		stack.settings.capture = &""
	if bool(keys["map"]) and stack.minimap != null and not page_open:
		stack.minimap.large = not stack.minimap.large
	if bool(keys["save"]):
		save()
	if stack.settings != null and stack.settings.open:
		stack.settings.state = HudBridge.snapshot()


func _effects(delta: float) -> void:
	var frame: Frame = view.current_frame()
	particles.advance(delta)
	if frame != null and frame.obs != null:
		var o: Interface.Observation = frame.obs
		if o.mining_broke:
			for cell: Vector2i in o.mining_broke_cells:
				particles.chip((Vector2(cell) + Vector2(0.5, 0.5)) * float(o.cell_px), look.cell_color(o.mining_broke_material, cell.x, cell.y), randf_range(-PI, PI))
		WaterDrips.spawn(o, particles, view.view_world_rect(), delta)
	var landings: Dictionary = falling.take_landings()
	for cell: Vector2i in landings:
		particles.pop(landings[cell]["pos"], landings[cell]["color"])
	if audio != null:
		audio.note_frame(frame, delta)


## The settings page's own input: a capture takes the next key, a click lands on a control, the arrows
## and Enter drive the focus.
func _unhandled_input(ev: InputEvent) -> void:
	if not booted or stack.settings == null or not stack.settings.open:
		return
	var page: SettingsPage = stack.settings
	if page.capture != &"":
		if HudBridge.finish_capture(page, ev):
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = get_viewport().get_mouse_position()
		HudBridge.apply(page.click(at), page, at.x)
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var payload: Dictionary = HudBridge.key(page, (ev as InputEventKey).keycode)
		if not payload.is_empty():
			HudBridge.apply(payload, page, -1.0)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not booted:
		return
	MinerDraw.draw(self, view.current_frame(), tick, COLOR_BODY, COLOR_BODY_GROUNDED)
	particles.draw(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and booted and Settings.persist:
		save()
		get_tree().quit(0)
