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
## The seat's flags (`shell/seat_flags.gd`): `--quit-after=N` is the smoke's (`tools/check_headed_boot.sh`
## boots with it, so "the game runs" is a checked claim); the meter, the warp and the screenshot are the
## instrument's. A player passes none.
var flags: Dictionary = SeatFlags.parse(PackedStringArray())
var quit_after: int = -1
## `--perf`: the wall-clock frame meter (`shell/frame_meter.gd`) prints a PERF line every five seconds
## and at quit. Off by default; costs two clock reads a frame when on.
var meter: FrameMeter = null
## `--perf-drive`: with the meter, a scripted hand -- 240 ticks right, 240 left, a jump every 90 -- so
## the meter measures a MOVING camera. Standstill numbers flatter every window-keyed cache (2026-09-04).
var drive: bool = false
## The landing's own memory: the on-floor edge and the speed the fall carried into it (D0403).
var _was_on_floor: bool = true
var _fall_speed: int = 0
const LAND_DUST_SPEED: int = 120   ## px/s of fall below which a landing raises no dust


func _ready() -> void:
	flags = SeatFlags.parse(OS.get_cmdline_user_args())
	quit_after = flags["quit_after"]
	if flags["perf"]:
		meter = FrameMeter.new()
	drive = flags["drive"]
	if autoboot:
		boot(not bool(flags["fresh"]))


## Kept as the smoke's own entry point; `SeatFlags.parse` is the parser.
static func parse_quit_after(args: PackedStringArray) -> int:
	return SeatFlags.parse(args)["quit_after"]


## Build the session and the seat. Returns false when the start refuses.
func boot(load_save: bool) -> bool:
	var phases: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	Settings.persist = load_save
	Controls.register()
	Settings.load_settings()
	var env: Dictionary = _open_session(load_save, phases)
	if door == null:
		push_error("boot: the start refused: %s" % WorldSeeder.last_refusal)
		return false
	camera = Camera2D.new()
	add_child(camera)
	if camera.is_inside_tree():
		camera.make_current()
	zoom = CameraRig.ZOOM_LEVELS[clampi(Settings.zoom_idx, 0, CameraRig.ZOOM_LEVELS.size() - 1)]
	if float(flags["zoom"]) > 0.0:
		zoom = float(flags["zoom"])
	camera.zoom = Vector2(zoom, zoom)
	var t1: int = Time.get_ticks_msec()
	stack = ViewStack.build_stack(self, door, look, camera, true, falling, payouts)
	view = stack.view
	phases["stack"] = Time.get_ticks_msec() - t1
	if not env.is_empty() and stack.hints != null and env.get(KEY_HINTS) is Array:
		stack.hints.restore_taught(env[KEY_HINTS])   # the shell's own key, once the HUD exists to take it
	var body: Body = door.services()["body"]
	_warp(body)
	# The camera may not show past the world (D0333's clamp; the reveal scene set it, the seat never did --
	# VISUAL_QUEUE v2 V05: a quarter of the frame was void from most of a 64 m world).
	var grid: TileGrid = (door.services()["world"] as World).grid
	rig.set_world_limits(Rect2(0.0, 0.0, float(grid.width * Interface.Observation.CELL_PX), float(grid.height * Interface.Observation.CELL_PX)))
	rig.warp_to(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE))
	camera.position = rig.step(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE), Vector2.ZERO, zoom, 1280.0, 0.0)
	var t3: int = Time.get_ticks_msec()
	audio = SceneAudio.new()
	add_child(audio)
	audio.setup_async(SEED)   # the synthesis on a worker thread; the players attach on the first settled frame (D0397)
	phases["audio"] = Time.get_ticks_msec() - t3
	phases["total"] = Time.get_ticks_msec() - t0
	if is_inside_tree():
		get_tree().root.title = "Sinkforge"
	booted = true
	print("%s site=%s seed=%d start=%s" % [BOOT_LINE, SITE, SEED, START])
	print("%s phases_ms %s" % [BOOT_LINE, phases])
	return true


## The session: from the slot when it reads (D0397 -- generating a shaft only to swap it out was most of
## the load), else a new game, the way a missing slot always was. Returns the envelope read, {} for none;
## `door` is null when both refuse. `phases` takes each step's milliseconds for the boot line.
func _open_session(load_save: bool, phases: Dictionary) -> Dictionary:
	var env: Dictionary = {}
	var t: int = Time.get_ticks_msec()
	if load_save and FileAccess.file_exists(save_path):
		env = SaveGame.read(save_path)
		phases["read"] = Time.get_ticks_msec() - t
	if not env.is_empty():
		t = Time.get_ticks_msec()
		door = Session.from_save(env)
		phases["restore"] = Time.get_ticks_msec() - t
		if door == null:
			push_warning("boot: the slot was refused (%s); a new game instead" % SaveGame.last_invalid)
	if door == null:
		t = Time.get_ticks_msec()
		door = Session.new_game(StrataData.get_site(SITE), SEED, START)
		phases["new_game"] = Time.get_ticks_msec() - t
	return env


## `--warp=col,row`: stand the body on the nearest floor to the cell, for a capture of the game at depth.
func _warp(body: Body) -> void:
	var at: Vector2i = flags["warp"]
	if at == SeatFlags.NO_WARP:
		return
	var grid: TileGrid = (door.services()["world"] as World).grid
	var cell_px: int = Interface.Observation.CELL_PX
	var feet: Vector2i = SeatFlags.stand_near(grid, at, (Body.HEIGHT_PX + cell_px - 1) / cell_px + 1)
	if feet == SeatFlags.NO_WARP:
		push_warning("--warp=%s: no floor within reach; the body stays at the spawn" % at)
		return
	body.place((feet.x * cell_px + cell_px / 2) * Fx.SCALE, ((feet.y + 1) * cell_px - Body.HEIGHT_PX / 2) * Fx.SCALE)
	print("%s warped to feet cell %s" % [BOOT_LINE, feet])


## `--screenshot-tick=N --screenshot-out=PATH`: the frame after tick N, saved; quits unless the smoke's
## own flag is running the clock.
func _shutter() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(flags["screenshot_out"])
	var body: Body = door.services()["body"]
	print("%s screenshot %s tick=%d zoom=%.2f body_cell=(%d,%d)" % [BOOT_LINE, flags["screenshot_out"], tick, zoom,
		Body._px_to_cell(body.pos_x), Body._px_to_cell(body.pos_y)])
	if quit_after < 0:
		get_tree().quit(0)


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


func _process(_delta: float) -> void:
	if meter != null:
		meter.note_process()
		if meter.last_was_slow() and booted:
			meter.note_slow("tick=%d %s" % [tick, view.draw_cost_report().left(160)])


func _physics_process(delta: float) -> void:
	if not booted:
		return
	var began: int = Time.get_ticks_usec()
	var page_open: bool = stack.settings != null and stack.settings.open
	var frame_in: InputFrame = _read_hands(page_open)
	door.apply(Command.move(frame_in))
	if not page_open:
		for c: Command in hands.verbs(Controls.pressed, _digit_down, PlayInput.aim_logic_of(frame_in)):
			door.apply(c)
	_hud_keys(page_open) if String(flags["act"]) == "" else _hud_keys_driven()
	last_input = frame_in
	view.refresh()
	_effects(delta)
	tick += 1
	if meter != null:
		SeatDrive.meter_tick(self, began)
	if tick == int(flags["screenshot_tick"]) and String(flags["screenshot_out"]) != "":
		_shutter()
	if quit_after >= 0 and tick >= quit_after:
		print("%s ticked=%d" % [BOOT_LINE, tick])
		if meter != null:
			print(meter.report())
			print(view.draw_cost_report())
		get_tree().quit(0)
		return
	var body: Body = door.services()["body"]
	camera.position = rig.step(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE),
		Vector2(float(body.vel_x), float(body.vel_y)) / float(Fx.SCALE), zoom, float(get_viewport().get_visible_rect().size.x), delta)
	queue_redraw()


## `--act=map|settings`: the HUD key as the scripted hand presses it.
func _hud_keys_driven() -> void:
	var keys: Dictionary = hands.hud_keys(_driven)
	if bool(keys["settings"]) and stack.settings != null:
		stack.settings.open = not stack.settings.open
		if String(flags["act"]) == "game":
			stack.settings.set_cat(SettingsPage.CAT_GAME)
	if bool(keys["map"]) and stack.minimap != null:
		stack.minimap.large = not stack.minimap.large
	if stack.settings != null and stack.settings.open:
		stack.settings.state = HudBridge.snapshot()


## The hands, deaf while the settings page is open: a modal takes the keys, and the body stands still.
func _read_hands(page_open: bool) -> InputFrame:
	var cell_px: int = Interface.Observation.CELL_PX
	if page_open:
		return hands.read(func(_a: StringName) -> bool: return false, Vector2.ZERO, cell_px, func(_c: Vector2i) -> bool: return false)
	var grid: TileGrid = (door.services()["world"] as World).grid
	var grid_ok: Callable = func(c: Vector2i) -> bool: return grid.in_bounds(c)
	if drive or String(flags["act"]) != "":
		if String(flags["act"]) == "mine":   # aim half a metre ahead and just under the feet: the ground he stands on
			var body: Body = door.services()["body"]
			Controls.pose_pointer(Vector2(float(body.pos_x) / float(Fx.SCALE) + 8.0 * float(body.facing),
				float(body.pos_y) / float(Fx.SCALE) + float(Body.HEIGHT_PX) / 2.0 + 4.0))
		return hands.read(_driven, Controls.pointer_world(self), cell_px, grid_ok)
	return hands.read(Controls.pressed, Controls.pointer_world(self), cell_px, grid_ok)


## The scripted hand (`shell/seat_drive.gd`), bound here so a Callable can be handed to the hands.
func _driven(action: StringName) -> bool:
	return SeatDrive.driven(flags, tick, action)


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
			# A break is debris AND a settling puff, not three flecks (D0403, V31): the cell vanished and
			# nothing said so at play zoom. The colour is the broken material's own.
			for cell: Vector2i in o.mining_broke_cells:
				var at: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * float(o.cell_px)
				var col: Color = look.cell_color(o.mining_broke_material, cell.x, cell.y)
				particles.debris(at, col, atan2(float(o.mining_swing_dir.y), float(o.mining_swing_dir.x)) + PI)
				particles.dust(at, col, 5)
		elif o.mining_swing and o.aim_cell != Vector2i(-1, -1) and o.solid_at(o.aim_cell):
			# A blow that did not break the cell still chips it: a fleck per swing off the struck face.
			var struck: Vector2 = (Vector2(o.aim_cell) + Vector2(0.5, 0.5)) * float(o.cell_px)
			particles.chip(struck, look.cell_color(o.material_at(o.aim_cell), o.aim_cell.x, o.aim_cell.y), atan2(float(o.mining_swing_dir.y), float(o.mining_swing_dir.x)) + PI)
		# A hard landing raises the floor's dust at the feet (D0403, V37): the on-floor edge after a fall.
		if o.on_floor and not _was_on_floor and _fall_speed > LAND_DUST_SPEED:
			var feet: Vector2 = Vector2(float(o.left_x + o.right_x) * 0.5, float(o.bottom_y)) / float(Fx.SCALE)
			var ground: Vector2i = Vector2i(floori(feet.x / float(o.cell_px)), floori(feet.y / float(o.cell_px)))
			particles.dust(feet, look.cell_color(o.material_at(ground), ground.x, ground.y), mini(14, 6 + _fall_speed / 40))
		_was_on_floor = o.on_floor
		_fall_speed = o.vel_y / Fx.SCALE if not o.on_floor else 0
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
		_game_verb(HudBridge.apply(page.click(at), page, at.x))
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if (ev as InputEventKey).keycode == KEY_ESCAPE:
			page.open = false
			page.armed = ""
		else:
			var payload: Dictionary = HudBridge.key(page, (ev as InputEventKey).keycode)
			if not payload.is_empty():
				_game_verb(HudBridge.apply(payload, page, -1.0))
		get_viewport().set_input_as_handled()


## The GAME face's two doors (D0396). RETURN TO SURFACE stands the body on the spawn with the line
## stowed and the world kept: the same intervention `--warp` makes, for a player the shaft has. NEW
## GAME moves the slot aside to `.bak` (the previous good save's own place, so one generation survives)
## and reloads the scene, which boots a fresh world the way `--fresh` does.
func _game_verb(verb: StringName) -> void:
	if verb == &"surface":
		return_to_surface()
	elif verb == &"new_game":
		new_game()


## The spawn's own metre may have changed hands since the new game (a machine, a dig), so the body stands
## on the nearest floor to it that fits, the way `--warp` does; the raw spawn only if nothing fits.
func return_to_surface() -> void:
	var body: Body = door.services()["body"]
	var grid: TileGrid = (door.services()["world"] as World).grid
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS[String(START)])
	var cell_px: int = Interface.Observation.CELL_PX
	var n: int = LogicGrid.TERRAIN_PER_LOGIC
	var feet: Vector2i = SeatFlags.stand_near(grid, Vector2i(spawn.x * n + n / 2, spawn.y * n + n - 1), (Body.HEIGHT_PX + cell_px - 1) / cell_px + 1)
	body.grapple.cut()
	if feet == SeatFlags.NO_WARP:
		body.place(spawn.x * Aim.LOGIC_FX + Aim.LOGIC_FX / 2, (spawn.y + 1) * Aim.LOGIC_FX - Body.HEIGHT_PX * Fx.SCALE / 2)
	else:
		body.place((feet.x * cell_px + cell_px / 2) * Fx.SCALE, ((feet.y + 1) * cell_px - Body.HEIGHT_PX / 2) * Fx.SCALE)
	body.vel_x = 0
	body.vel_y = 0
	rig.warp_to(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE))
	if stack != null and stack.settings != null:
		stack.settings.open = false
	print("%s returned to surface: feet %s" % [BOOT_LINE, feet])


func new_game() -> void:
	retire_slot()
	print("%s new game: the slot moved to %s, the scene reloads" % [BOOT_LINE, SaveGame.BAK_SUFFIX])
	get_tree().reload_current_scene()


## Move the slot aside rather than delete it: `.bak` is where `SaveGame.write` keeps the previous good
## save, so a NEW GAME leaves one generation to recover by hand. Returns whether a slot was there.
func retire_slot() -> bool:
	if not (Settings.persist and FileAccess.file_exists(save_path)):
		return false
	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return false
	return dir.rename(save_path, save_path + SaveGame.BAK_SUFFIX) == OK


func _draw() -> void:
	if not booted:
		return
	particles.draw(self)   # the miner is a layer of the stack now (`ViewStack.BODY_Z`), under the veil


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and booted and Settings.persist:
		save()
		get_tree().quit(0)
