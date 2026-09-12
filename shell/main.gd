class_name Main
extends Node2D

## THE GAME'S ENTRY POINT (A' step 6q, D0380): `godot --path .` runs this. The plan's last step 6 item --
## "a main scene in `shell/` so the game runs (today nothing does; `project.godot` has no main scene)".
##
## WHAT IT OWNS: the session (`Session.new_game`, or the slot restored over it), the tick (60 Hz: the hands
## read once, the body moved through the door, the verbs applied, the view refreshed), the camera rig, the
## scene-side effects (particles, drips, landings, the audio rig), and the save on the close box. The input
## dispatch the tick consults -- the modals, the deaf hands, the HUD-key edges, the page's key/click doors --
## is `SeatInput`'s (`shell/seat_input.gd`, split at the function cap). WHAT IT DOES NOT: anything a
## painter, the sim or the door already decides. The debug scene (`tests/body/reveal_scene.gd`) keeps its
## agent mode and its flags; this is the human's seat only.
##
## `autoboot` is true in the scene file and false in a test, which calls `boot(false)` itself so a real
## save on the machine is never loaded into a fixture.

const SITE: StringName = &"shallow_clay"   ## the site the tutorial start is authored for
const START: StringName = &"tutorial"
const SEED: int = 20260826
const KEY_HINTS: String = SeatHud.KEY_HINTS   ## kept for the suites that name it; the key itself is SeatHud's (D0411)
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
## `--route=NAME`: the seat driven by a route policy (`shell/seat_route.gd`) instead of the keyboard --
## the playthrough as an instrument, one `decide()` per physics tick (D0625, queue item 44).
var route: SeatRoute = null
## The landing's own memory: the on-floor edge and the speed the fall carried into it (D0403).
var effects: SeatEffects = SeatEffects.new()   ## the per-tick particles, the shake (D0410)


func _ready() -> void:
	flags = SeatFlags.parse(OS.get_cmdline_user_args())
	quit_after = flags["quit_after"]
	SeatDrive.apply_window(flags, get_window())
	if flags["perf"]:
		meter = FrameMeter.new()
		meter.measure_render(get_viewport().get_viewport_rid())
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)     # the seat's own methods: dropped with the node
		RenderingServer.frame_post_draw.connect(_on_post_draw)
	drive = flags["drive"]
	if flags["route"] != &"":
		route = SeatRoute.build(flags["route"])
		if route == null:
			push_error("--route=%s: no such route" % flags["route"])
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
	Settings.load_settings(bool(flags["muted"]))   # --muted: this boot only, never saved (D0437)
	var env: Dictionary = SeatSession.open(self, load_save, phases)
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
	if float(flags["lamp_occlusion"]) >= 0.0:
		VeilLayer.lamp_occlusion = float(flags["lamp_occlusion"])   # the lighting comparison's dial (D0427)
	var t1: int = Time.get_ticks_msec()
	stack = ViewStack.build_stack(self, door, look, camera, true, falling, payouts)
	SeatInput.wire_page(self)   # D0632's Control page emits payloads; SeatInput lands them on HudBridge.apply
	view = stack.view
	phases["stack"] = Time.get_ticks_msec() - t1
	SeatHud.restore(stack, env)   # the shell's own keys, once the HUD exists to take them (D0411)
	SeatHud.push_bindings()
	var body: Body = door.services()["body"]
	_warp(body)
	# The camera may not show past the world (D0333's clamp; the reveal scene set it, the seat never did --
	# VISUAL_QUEUE v2 V05: a quarter of the frame was void from most of a 64 m world).
	var grid: TileGrid = (door.services()["world"] as World).grid
	rig.set_world_limits(Rect2(0.0, 0.0, float(grid.width * Interface.Units.CELL_PX), float(grid.height * Interface.Units.CELL_PX)))
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
	_boot_report(phases)
	return true


## The boot line the smoke greps for (`tools/check_headed_boot.sh`), the ablation profile's mute
## label (D0418), and the phase timings -- the report half of boot(), split at the function cap.
func _boot_report(phases: Dictionary) -> void:
	print("%s site=%s seed=%d start=%s" % [BOOT_LINE, SITE, world_seed(), SeatFlags.start_id(flags, START)])
	var mute: PackedStringArray = flags["mute"]
	if not mute.is_empty():
		print("%s muted=%s" % [BOOT_LINE, ",".join(DrawCost.mute(view, mute))])
	print("%s phases_ms %s" % [BOOT_LINE, phases])


## `--warp=col,row`: stand the body on the nearest floor to the cell, for a capture of the game at depth.
func _warp(body: Body) -> void:
	var at: Vector2i = flags["warp"]
	if at == SeatFlags.NO_WARP:
		return
	var grid: TileGrid = (door.services()["world"] as World).grid
	var cell_px: int = Interface.Units.CELL_PX
	var feet: Vector2i = SeatFlags.stand_near(grid, at, (Body.HEIGHT_PX + cell_px - 1) / cell_px + 1)
	if feet == SeatFlags.NO_WARP:
		push_warning("--warp=%s: no floor within reach; the body stays at the spawn" % at)
		return
	body.place((feet.x * cell_px + cell_px / 2) * Fx.SCALE, ((feet.y + 1) * cell_px - Body.HEIGHT_PX / 2) * Fx.SCALE)
	print("%s warped to feet cell %s" % [BOOT_LINE, feet])


## `--screenshot-tick=N --screenshot-out=PATH`: the frame after tick N, saved; quits unless the smoke's
## own flag is running the clock.
func _shutter() -> void:
	shot(String(flags["screenshot_out"]), quit_after < 0)


## The seat's capture, usable more than once a run: `--route-out=` calls it at every leg boundary.
## The two-frame await lets the renderer settle before the pixels are read -- the world is NOT held
## across it (the reveal scene's shutter is the held one); a seat capture is a frame, two ticks on.
func shot(path: String, quit_when_done: bool = false) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	var body: Body = door.services()["body"]
	print("%s screenshot %s tick=%d zoom=%.2f body_cell=(%d,%d)" % [BOOT_LINE, path, tick, zoom,
		Body._px_to_cell(body.pos_x), Body._px_to_cell(body.pos_y)])
	if quit_when_done:
		get_tree().quit(0)


## The route's visual record: one frame per leg boundary, `--route-out=PREFIX`_legN.png and _done.png.
func _route_shot(tag: String) -> void:
	var prefix: String = String(flags["route_out"])
	if prefix != "":
		shot("%s_%s.png" % [prefix, tag])


## The session verbs live in `SeatSession` (split at the file cap, the SeatHud/SeatEffects seam); these
## stay because the suites call them on the seat.
func capture_session() -> Dictionary:
	return SeatSession.capture(self)


func restore(env: Dictionary) -> bool:
	return SeatSession.restore(self, env)


## The world's seed: the shipped one unless `--seed=<n>` names another (the holdout run, D0460).
func world_seed() -> int:
	return int(flags["seed"]) if int(flags["seed"]) > 0 else SEED


func save() -> bool:
	return SeatSession.save(self)


func _on_pre_draw() -> void:
	if meter != null:
		meter.note_pre_draw()


func _on_post_draw() -> void:
	if meter != null:
		meter.note_post_draw()


func _process(_delta: float) -> void:
	if flags["interpolate"]:
		ViewStack.present(camera, rig)   # a frame between two sim ticks (D0537); off unless asked for
	if meter != null:
		SeatDrive.meter_frame(self)


func _physics_process(delta: float) -> void:
	if not booted:
		return
	var began: int = Time.get_ticks_usec()
	var page_open: bool = SeatInput.page_open(self)
	var map_open: bool = SeatInput.map_open(self)
	var scripted: bool = SeatInput.scripted(self)
	var frame_in: InputFrame
	if route != null and not (page_open or map_open):
		# The route's decide runs BEFORE the move applies: its commands (select, drop, collect) land
		# inside this tick exactly as they did inside the bot's own loop (D0625). It decides on the
		# LAST rendered frame's observation rather than observing itself -- `observe` owns a consumed
		# events channel the view's own refresh needs intact (seat_route.gd's docstring).
		var last: Frame = view.current_frame() if view != null else null
		route.tick(door, _route_shot, last.obs if last != null else null)
		frame_in = route.frame()
	else:
		frame_in = SeatInput.read_hands(self, page_open or map_open)
	door.apply(Command.move(frame_in))
	if not (page_open or map_open):
		for c: Command in hands.verbs(SeatInput.scripted_pressed(self) if scripted else Controls.pressed,
				SeatDrive.no_digit if scripted else _digit_down, PlayInput.aim_logic_of(frame_in), Settings.auto_pickup):
			door.apply(c)
	SeatInput.hud_keys_driven(self) if scripted else SeatInput.hud_keys(self)
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
	rig.kick(effects.shake_px)   # a break or a hard landing knocks the camera, when the FEEL page says so (D0410)
	camera.position = rig.step(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE),
		Vector2(float(body.vel_x), float(body.vel_y)) / float(Fx.SCALE), zoom, float(get_viewport().get_visible_rect().size.x), delta)
	queue_redraw()


## The seat's input dispatch lives in `shell/seat_input.gd` (split at the function cap, the same seam
## as SeatHud/SeatSession): which modal is open, the hands read deaf while one is, the HUD-key edges,
## and the settings page's key and click doors. What stays here is what a suite or the engine names on
## the node itself.
static func _digit_down(i: int) -> bool:
	return SeatInput.digit_down(i)


func _effects(delta: float) -> void:
	var frame: Frame = view.current_frame()
	effects.tick(frame, particles, look, falling, view.view_world_rect(), delta, Settings.screen_shake,
		(door.services()["hold"] as MineHold).slump)
	if audio != null:
		audio.note_frame(frame, delta)
		audio.set_levels(Settings.sound_db(), Settings.ambience_db(), Settings.music_db())   # every slider, live (D0410)


## The settings page's own input: a capture takes the next key, a click lands on a control, the arrows
## and Enter drive the focus. The engine names the callback on the node; the dispatch is SeatInput's.
func _unhandled_input(ev: InputEvent) -> void:
	SeatInput.unhandled(self, ev)


## The GAME face's verdicts, applied to the seat (D0396): RETURN TO SURFACE stands the body on the
## spawn with the line stowed and the world kept; NEW GAME moves the slot aside and reloads. Kept on
## the node because the suites name `main._game_verb`; the dispatch itself is `SeatInput.game_verb`.
func _game_verb(verb: StringName) -> void:
	SeatInput.game_verb(self, verb)


## RETURN TO SURFACE stands the body on the spawn with the line stowed and the world kept -- the same
## intervention `--warp` makes, for a player the shaft has. In `SeatSession` with the rest of the verbs.
func return_to_surface() -> void:
	SeatSession.return_to_surface(self)


func new_game() -> void:
	SeatSession.new_game(self)


func retire_slot() -> bool:
	return SeatSession.retire_slot(self)


func _draw() -> void:
	if not booted:
		return
	particles.draw(self)   # the miner is a layer of the stack now (`ViewStack.BODY_Z`), under the veil


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and booted and Settings.persist:
		save()
		get_tree().quit(0)
