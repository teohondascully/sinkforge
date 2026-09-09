class_name SeatFlags
extends RefCounted

## THE SEAT'S COMMAND LINE, as a pure function of the argv so a test can pose it (D0390). `godot --path .`
## takes no flags for a player; every flag here is for a smoke, a meter or a capture of the REAL seat --
## the reveal scene (`tests/body/reveal_scene.gd`) is the agent's debug scene and its camera flag moves the
## camera away from the body and its lamp, which is how a "deep" capture of the game came out black
## (2026-09-04): 70 m from the only light, of course it did. A capture of the game has the miner IN it.
##
##   --quit-after=N          run N ticks and exit 0, printing the boot line (the smoke's flag)
##   --perf / --perf-drive   the wall-clock frame meter, still or on a scripted walk (`FrameMeter`)
##   --perf-drive=walk|dig|fall  the meter on one NAMED workload (`SeatDrive.WORKLOADS`): the walk, a
##                           sustained excavation straight down, or a dig phase followed by a free fall
##                           back down the shaft it just cut. Bare `--perf-drive` is `walk`.
##   --warp=col,row          stand the body on the nearest floor to a terrain cell before the first tick
##   --zoom=Z                the camera zoom, overriding the saved setting
##   --screenshot-tick=N     at tick N save the viewport to --screenshot-out, then quit unless
##   --screenshot-out=PATH   --quit-after says otherwise
##   --fresh                 a new game: the slot on disk is neither loaded nor written
##   --mute=a,b,...          hide every world layer whose cost-report label starts with a listed stem, and
##                           `post` for the lens: the ablation profile for a frame the script cannot time (D0418)
##   --act=mine|far|map|settings|game  a scripted hand for a capture: hold MINE at the rock ahead from tick 20
##                           with the pointer posed (far: six metres ahead, a refused press, D0488), or press
##                           the map / settings key once at tick 20 (game: the GAME face)
##   --lamp-occlusion=K      the veil lamp's loss per solid cell crossed (D0427); 0 is legacy's pass, the
##                           control of a lighting comparison. Unset: `VeilOcclusion.K`.
##   --muted                 the Master bus muted for this boot, whatever the settings file says: a
##                           scripted seat on a machine somebody is using (D0437)
##   --shader-tone           the terrain's molded tone from a per-chunk data texture in
##                           `view/visuals/rock_tone.gdshader` instead of per-cell on the CPU (D0528,
##                           T040's evidence). NOT PARSED HERE, and that is the layer rule rather than an
##                           omission: its only consumer is `BakeChunk.shader_tone()`, and `view` may
##                           depend on `interface`, `core` and `data` alone, so it reads the flag off
##                           `OS.get_cmdline_args()` directly. Listed here because this header is the
##                           seat's command-line manual and a flag missing from it is a flag nobody finds.

const NO_WARP: Vector2i = Vector2i(-1, -1)


static func parse(args: PackedStringArray) -> Dictionary:
	var f: Dictionary = {"quit_after": -1, "perf": false, "drive": false, "warp": NO_WARP,
		"zoom": 0.0, "screenshot_tick": -1, "screenshot_out": "", "act": "", "fresh": false, "start": "",
		"mute": PackedStringArray(), "lamp_occlusion": -1.0, "muted": false, "seed": 0,
		"workload": SeatDrive.WALK, "unfocused": false}
	for a: String in args:
		if a.begins_with("--quit-after="):
			f["quit_after"] = maxi(int(a.substr("--quit-after=".length())), 0)
		elif a == "--perf":
			f["perf"] = true
		elif a == "--perf-drive" or a.begins_with("--perf-drive="):
			f["perf"] = true
			f["drive"] = true
			# An unknown name is REFUSED rather than silently walked: a typo that fell back to the walk
			# would report a walk's numbers under a dig's heading, which is the one failure a perf
			# fixture cannot survive. `workload` stays at its default and the seat prints the refusal.
			if a.begins_with("--perf-drive="):
				var name: String = a.substr("--perf-drive=".length())
				if SeatDrive.WORKLOADS.has(name):
					f["workload"] = name
				else:
					push_error("--perf-drive=%s: not one of %s" % [name, SeatDrive.WORKLOADS])
		elif a.begins_with("--warp="):
			var parts: PackedStringArray = a.substr("--warp=".length()).split(",")
			if parts.size() == 2:
				f["warp"] = Vector2i(int(parts[0]), int(parts[1]))
		elif a.begins_with("--zoom="):
			f["zoom"] = maxf(float(a.substr("--zoom=".length())), 0.0)
		elif a.begins_with("--screenshot-tick="):
			f["screenshot_tick"] = int(a.substr("--screenshot-tick=".length()))
		elif a.begins_with("--screenshot-out="):
			f["screenshot_out"] = a.substr("--screenshot-out=".length())
		elif a.begins_with("--mute="):
			f["mute"] = a.substr("--mute=".length()).split(",", false)
		elif a.begins_with("--act="):
			f["act"] = a.substr("--act=".length())
		elif a == "--fresh":
			f["fresh"] = true
		elif a.begins_with("--start="):
			f["start"] = a.substr("--start=".length())
		elif a.begins_with("--seed="):
			f["seed"] = maxi(int(a.substr("--seed=".length())), 0)   # 0 keeps the shipped seed (D0460, the holdout)
		elif a.begins_with("--lamp-occlusion="):
			f["lamp_occlusion"] = maxf(float(a.substr("--lamp-occlusion=".length())), 0.0)
		elif a == "--unfocused":
			f["unfocused"] = true
		elif a == "--muted":
			f["muted"] = true
	return f


## The start record a fresh game stamps: `--start=<id>` when it names a record in `data/starts/`, else
## `fallback` (the seat's authored start). A scenario record -- `beacon_probe`, a machine 60 m down in the
## dark -- is how a capture witnesses a state no start of play produces (D0407).
static func start_id(flags: Dictionary, fallback: StringName) -> StringName:
	var named: String = String(flags.get("start", ""))
	if named != "" and StartsRecords.RECORDS.has(named):
		return StringName(named)
	return fallback


## The nearest cell to `near` where a body can stand: air for the body's height above a solid floor,
## searched in growing rings so the warp lands in the cave the caller pointed at, not inside its wall.
## `NO_WARP` when nothing within `reach` cells qualifies.
static func stand_near(grid: TileGrid, near: Vector2i, body_cells_tall: int, reach: int = 96) -> Vector2i:
	for r: int in range(0, reach + 1):
		for dy: int in range(r, -r - 1, -1):          # below first: a floor is found by falling
			for dx_abs: int in range(0, r + 1):       # then the column closest to the one asked for
				for dx: int in ([dx_abs] if dx_abs == 0 else [dx_abs, -dx_abs]):
					if maxi(dx_abs, absi(dy)) != r:
						continue
					var c: Vector2i = near + Vector2i(dx, dy)
					if _standable(grid, c, body_cells_tall):
						return c
	return NO_WARP


## `c` is the cell the feet's left half stands in: solid under both feet cells, and air across the body's
## four-cell width (the body is a tile wide, `Body.WIDTH_PX`) from the feet up through its height. A
## one-cell slot passes a one-column test and then ejects the body sideways or up (2026-09-04, seen).
static func _standable(grid: TileGrid, c: Vector2i, tall: int) -> bool:
	for fx: int in range(0, 2):
		var under: Vector2i = c + Vector2i(fx, 1)
		if not grid.in_bounds(under) or not grid.is_solid(under):
			return false
	for dx: int in range(-1, 3):
		for i: int in range(0, tall):
			var cell: Vector2i = c + Vector2i(dx, -i)
			if not grid.in_bounds(cell) or grid.is_solid(cell):
				return false
	return true
