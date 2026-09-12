class_name SeatInput
extends RefCounted

## THE SEAT'S INPUT DISPATCH, split from `shell/main.gd` on the same seam as SeatHud/SeatSession
## (the file was at its function cap): which modal is open, the hands read deaf while one is, the
## HUD-key edges, the scripted hand's answer, and the settings page's two input doors -- a key routed
## through `HudBridge.key`, and a row Control's click arriving on `settings_ctl`'s `payload` signal
## (D0632). THE MUTATION PATH STAYS EXACTLY ONE: `HudBridge.apply`, then the verb -- a click and a key
## land on it identically, so the page and the settings can only disagree in `HudBridge` itself.
## Each function takes the seat as `main`, the way `SeatSession.open` does -- the door, the stack, the
## hands and the camera stay the node's.


## The settings page is the modal the keys and the hands defer to.
static func page_open(main: Main) -> bool:
	return main.stack != null and main.stack.settings != null and main.stack.settings.open


## The large map is a modal too (D0410): it deafens the hands the same way.
static func map_open(main: Main) -> bool:
	return main.stack != null and main.stack.minimap != null and main.stack.minimap.large


## A script owns the seat under `--perf-drive`, `--act=` or `--route=`: the verbs and the HUD keys
## then come from it, never from a real keyboard (D0535 -- the human is inside the measurement).
static func scripted(main: Main) -> bool:
	return main.drive or String(main.flags["act"]) != "" or main.route != null


## The scripted hand as the `pressed` Callable `hands` wants -- bound here so a Callable can be
## handed to it. Under a route the answer is never: the route speaks in whole frames and applies its
## own verb commands, so nothing it does may reach the key-driven edges in `verbs` or `hud_keys`.
static func scripted_pressed(main: Main) -> Callable:
	return func(a: StringName) -> bool: return SeatDrive.driven(main.flags, main.tick, a) if main.route == null else false


## The hands, read once a tick, deaf while a modal is open: the modal takes the keys and the body
## stands still. A scripted hand poses its own pointer; a real one reads `Controls.pressed`.
static func read_hands(main: Main, modal: bool) -> InputFrame:
	var cell_px: int = Interface.Units.CELL_PX
	if modal:
		return main.hands.read(func(_a: StringName) -> bool: return false, Vector2.ZERO, cell_px, func(_c: Vector2i) -> bool: return false)
	var grid: TileGrid = (main.door.services()["world"] as World).grid
	var grid_ok: Callable = func(c: Vector2i) -> bool: return grid.in_bounds(c)
	if main.drive or String(main.flags["act"]) != "":
		if SeatDrive.poses_pointer(main.flags):   # the scripted hand's own pointer (`SeatDrive.feet_aim`)
			Controls.pose_pointer(SeatDrive.feet_aim(main.flags, main.door.services()["body"], main.tick))
		return main.hands.read(scripted_pressed(main), Controls.pointer_world(main), cell_px, grid_ok)
	return main.hands.read(Controls.pressed, Controls.pointer_world(main), cell_px, grid_ok)


## A hotbar digit held this tick: the tenth well is the 0 key (D0412); an action now, so it remaps
## and it deafens (D0615). The suites name `Main._digit_down`, which delegates here.
static func digit_down(i: int) -> bool:
	return Controls.pressed(Controls.SLOTS[i])


## The HUD keys -- the settings page, the large map, the save -- decided in ONE place
## (`HudBridge.hud_toggles`, D0446), then written back. While the page is open it is re-fed its
## snapshot and the lessons' keys are pushed again: a rebinding rewrites every lesson's key on the
## next frame (D0411).
static func hud_keys(main: Main) -> void:
	var keys: Dictionary = main.hands.hud_keys(Controls.pressed)
	if main.stack.settings != null and main.stack.minimap != null:
		var next: Dictionary = HudBridge.hud_toggles(keys, main.stack.settings.open, main.stack.minimap.large)
		if bool(next["settings"]) != main.stack.settings.open:
			main.stack.settings.open = bool(next["settings"])
			main.stack.settings.capture = &""
			main.stack.settings.armed = ""
		main.stack.minimap.large = bool(next["map"])
	if bool(keys["save"]):
		main.save()
	if main.stack.settings != null and main.stack.settings.open:
		main.stack.settings.state = HudBridge.snapshot()
		SeatHud.push_bindings()


## `--act=map|settings`: the HUD key as the scripted hand presses it.
static func hud_keys_driven(main: Main) -> void:
	var keys: Dictionary = main.hands.hud_keys(scripted_pressed(main))
	if bool(keys["settings"]) and main.stack.settings != null:
		main.stack.settings.open = not main.stack.settings.open
		if String(main.flags["act"]) == "game":
			main.stack.settings.set_cat(SettingsPage.CAT_GAME)
	if bool(keys["map"]) and main.stack.minimap != null:
		main.stack.minimap.large = not main.stack.minimap.large
	if main.stack.settings != null and main.stack.settings.open:
		main.stack.settings.state = HudBridge.snapshot()
		SeatHud.push_bindings()


## The page's own input, called from the seat's `_unhandled_input`: a capture takes the next key, a
## key routed through `HudBridge.key` moves the focus or activates the row. ESC is the SETTINGS
## action's own key and closes the page through `hud_keys`' edge (D0446); closing it here as well
## re-toggled it open the same tick, and no stranger could leave the page by ESC.
static func unhandled(main: Main, ev: InputEvent) -> void:
	if not main.booted or main.stack.settings == null or not main.stack.settings.open:
		return
	var page: SettingsPage = main.stack.settings
	if page.capture != &"":
		if HudBridge.finish_capture(page, ev):
			main.get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if (ev as InputEventKey).keycode != KEY_ESCAPE:
			var payload: Dictionary = HudBridge.key(page, (ev as InputEventKey).keycode)
			if not payload.is_empty():
				game_verb(main, HudBridge.apply(payload, page, -1.0))
		main.get_viewport().set_input_as_handled()


## Click routing, wired once the stack exists (D0632): the modal page is a real Control tree whose
## rows emit their payloads on a signal. Each lands on the same path a key takes -- `HudBridge.apply`,
## then the verb.
static func wire_page(main: Main) -> void:
	if main.stack.settings_ctl == null:
		return
	main.stack.settings_ctl.payload.connect(func(p: Dictionary) -> void: page_payload(main, p))
	main.stack.settings_ctl.apply_skin(String(main.flags.get("skin", "instrument")))


static func page_payload(main: Main, p: Dictionary) -> void:
	game_verb(main, HudBridge.apply(p, main.stack.settings, 0.0))


## The GAME face's two doors and the FEEL page's zoom, applied to the seat (D0396, D0410). RETURN TO
## SURFACE stands the body on the spawn with the line stowed and the world kept; NEW GAME moved the
## slot aside and reloads. `zoom` the rig reads every tick.
static func game_verb(main: Main, verb: StringName) -> void:
	if verb == &"surface":
		main.return_to_surface()
	elif verb == &"new_game":
		main.new_game()
	elif verb == &"zoom":
		main.zoom = CameraRig.ZOOM_LEVELS[clampi(Settings.zoom_idx, 0, CameraRig.ZOOM_LEVELS.size() - 1)]
