class_name SeatSession
extends RefCounted

## THE SEAT'S SESSION VERBS, split from `shell/main.gd` at the file cap on the SeatHud/SeatEffects seam:
## capture and restore the save envelope (with the shell's own keys on the HUD), write the slot, retire
## it for NEW GAME, and stand the body back on the spawn for RETURN TO SURFACE. Each takes the seat as
## `main` the way `SeatDrive.meter_tick` does -- the door, the stack and the rig stay the node's.
## The session: from the slot when it reads (D0397 -- generating a shaft only to swap it out was most of
## the load), else a new game, the way a missing slot always was. Returns the envelope read, {} for none;
## `main.door` is null when both refuse. `phases` takes each step's milliseconds for the boot line.
static func open(main: Main, load_save: bool, phases: Dictionary) -> Dictionary:
	var env: Dictionary = {}
	var t: int = Time.get_ticks_msec()
	if load_save and FileAccess.file_exists(main.save_path):
		env = SaveGame.read(main.save_path)
		phases["read"] = Time.get_ticks_msec() - t
	if not env.is_empty():
		t = Time.get_ticks_msec()
		main.door = Session.from_save(env)
		phases["restore"] = Time.get_ticks_msec() - t
		if main.door == null:
			push_warning("boot: the slot was refused (%s); a new game instead" % SaveGame.last_invalid)
	if main.door == null:
		t = Time.get_ticks_msec()
		main.door = Session.new_game(StrataData.get_site(Main.SITE), main.world_seed(), SeatFlags.start_id(main.flags, Main.START), phases)   # its sub-phases too (D0518)
		phases["new_game"] = Time.get_ticks_msec() - t
	return env


static func capture(main: Main) -> Dictionary:
	var env: Dictionary = Session.capture(main.door)
	SeatHud.capture(main.stack, env)
	return env


static func restore(main: Main, env: Dictionary) -> bool:
	if env.is_empty() or not Session.restore(main.door, env):
		return false
	SeatHud.restore(main.stack, env)
	return true


static func save(main: Main) -> bool:
	return SaveGame.write(main.save_path, capture(main))


## Move the slot aside rather than delete it: `.bak` is where `SaveGame.write` keeps the previous good
## save, so a NEW GAME leaves one generation to recover by hand. Returns whether a slot was there.
static func retire_slot(main: Main) -> bool:
	if not (Settings.persist and FileAccess.file_exists(main.save_path)):
		return false
	var dir: DirAccess = DirAccess.open(main.save_path.get_base_dir())
	if dir == null:
		return false
	return dir.rename(main.save_path, main.save_path + SaveGame.BAK_SUFFIX) == OK


static func new_game(main: Main) -> void:
	retire_slot(main)
	print("%s new game: the slot moved to %s, the scene reloads" % [Main.BOOT_LINE, SaveGame.BAK_SUFFIX])
	main.get_tree().reload_current_scene()


## The spawn's own metre may have changed hands since the new game (a machine, a dig), so the body stands
## on the nearest floor to it that fits, the way `--warp` does; the raw spawn only if nothing fits.
static func return_to_surface(main: Main) -> void:
	var body: Body = main.door.services()["body"]
	var grid: TileGrid = (main.door.services()["world"] as World).grid
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS[String(SeatFlags.start_id(main.flags, Main.START))])
	var cell_px: int = Interface.Units.CELL_PX
	var n: int = LogicGrid.TERRAIN_PER_LOGIC
	var feet: Vector2i = SeatFlags.stand_near(grid, Vector2i(spawn.x * n + n / 2, spawn.y * n + n - 1), (Body.HEIGHT_PX + cell_px - 1) / cell_px + 1)
	body.grapple.cut()
	if feet == SeatFlags.NO_WARP:
		body.place(spawn.x * Aim.LOGIC_FX + Aim.LOGIC_FX / 2, (spawn.y + 1) * Aim.LOGIC_FX - Body.HEIGHT_PX * Fx.SCALE / 2)
	else:
		body.place((feet.x * cell_px + cell_px / 2) * Fx.SCALE, ((feet.y + 1) * cell_px - Body.HEIGHT_PX / 2) * Fx.SCALE)
	body.vel_x = 0
	body.vel_y = 0
	main.rig.warp_to(Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE))
	if main.stack != null and main.stack.settings != null:
		main.stack.settings.open = false
	print("%s returned to surface: feet %s" % [Main.BOOT_LINE, feet])
