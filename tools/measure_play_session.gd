extends "res://tests/test_base.gd"

## Replays a recorded reveal-scene session and reports what the mining verb actually did -- built to decode
## the director's own `--play` feel report ("the world reads coarse, mining feels weird, each bite is huge")
## against the session that produced it, rather than theorising a mechanism from the words. This is what
## produced D0200's numbers. It moved out of `tools/scratch/` under that directory's own rule -- a scratch
## script worth keeping becomes a real tool -- because the standing milestone discipline means there will be
## more recorded sessions, and a number nobody can re-derive is a quotation rather than a measurement.
##
## Deliberately NOT `RevealReplayDriver.replay()`: that returns `RevealMetric.TickEvent`s, which carry only
## `dig_event`/`dug_material` by design (its anti-cheat contract). This needs the body's position, the aim,
## the crack bank and the workability verdict per tick, none of which a `TickEvent` may see.
##
## Run: godot --headless --path . --script res://tools/measure_play_session.gd -- <res:// log path> [radius]

const CELL: int = Heightfield.TERRAIN_CELL_PX
const TICK_HZ: int = 60
## `project.godot` renders 2D at 1280x720 and upscales; the reveal scene's default camera zoom is 6.0.
## Literals rather than engine reads because this runs headless, where the window is not the shipped one --
## D0197's own trap, stated instead of silently re-derived wrong.
const RENDER_W: int = 1280
const RENDER_H: int = 720
const ZOOM: float = 6.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: ... -- res://tests/body/recordings/<log>")
		quit(1)
		return
	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(args[0])
	if parsed == null:
		_check(false, "log parsed")
		_finish("measure_play_session")
		return
	# An optional second argument overrides the radius the log names. This is the probe's own
	# counterfactual and the strongest evidence available without a second human session: the SAME
	# recorded human inputs, replayed at a different bite, so the only thing that differs between the two
	# readings is the quantity under test. An agent trace cannot pose that question -- a scripted digger
	# re-aims perfectly and would hide exactly the re-aiming cost this is about.
	if args.size() > 1:
		parsed.bite_radius = int(args[1])
	var session: Dictionary = RevealSessionSetup.build(parsed.site_id, parsed.seed_value)
	var stats: Dictionary = _scan(parsed, session)
	_report(parsed, stats)
	_geometry(session["grid"], int(stats["broke"]))
	# The assertions are about the INSTRUMENT, not the session: a replay that broke nothing, or that
	# diverged into a bounds violation, would make every number above describe something other than what
	# was played. They are what makes this measurement quotable rather than merely printed.
	_check(int(stats["broke"]) > 0, "the replay actually mined -- a session that broke nothing makes every rate above 0/0")
	_check(int(stats["violations"]) == 0, "the replay produced no bounds violation")
	_check(int(stats["held"]) > 0, "the recording carries a held MINE button -- a V1 log would replay silently with none")
	_finish("measure_play_session")


func _scan(parsed: RevealReplayDriver.ParsedLog, session: Dictionary) -> Dictionary:
	var grid: TileGrid = session["grid"]
	var body: Body = session["body"]
	var mining: Mining = Mining.new()
	mining.bite_radius = parsed.bite_radius
	var spawn_row: int = Body._px_to_cell(body.pos_y)
	var s: Dictionary = {"held": 0, "working": 0, "oob": 0, "air": 0, "reach": 0, "broke": 0, "cleared": 0,
		"violations": 0, "aim_changes": 0, "longest_run": 0, "first_break": -1, "last_break": -1,
		"spawn_row": spawn_row, "min_row": spawn_row, "max_row": spawn_row, "materials": {}, "aim_cells": {}}
	var prev_aim: Vector2i = Mining.NO_CELL
	var run_len: int = 0
	var tick: int = 0
	for input: InputFrame in parsed.inputs:
		body.tick(input, grid)
		var target: Vector2i = Vector2i(input.aim_col, input.aim_row)
		var want: bool = input.mine_held and input.has_aim
		if input.mine_held:
			s["held"] += 1
		if want:
			(s["aim_cells"] as Dictionary)[target] = true
			if target != prev_aim:
				s["aim_changes"] += 1
				run_len = 0
			run_len += 1
			s["longest_run"] = maxi(int(s["longest_run"]), run_len)
			prev_aim = target
			_classify(s, grid, body, target)
		else:
			run_len = 0
			prev_aim = Mining.NO_CELL
		mining.mine(grid, body.pos_x, body.pos_y, target, want)
		if mining.broke_this_tick:
			s["broke"] += 1
			s["cleared"] += mining.broke_cells.size()
			var mats: Dictionary = s["materials"]
			mats[mining.broke_material] = int(mats.get(mining.broke_material, 0)) + 1
			if int(s["first_break"]) < 0:
				s["first_break"] = tick
			s["last_break"] = tick
		if body.bounds_violation_this_tick:
			s["violations"] += 1
		var row: int = Body._px_to_cell(body.pos_y)
		s["min_row"] = mini(int(s["min_row"]), row)
		s["max_row"] = maxi(int(s["max_row"]), row)
		tick += 1
	s["ticks"] = tick
	return s


## Why a held tick did nothing, split by cause. "I held the button and nothing happened" has three very
## different explanations and lumping them would hide which one the session actually hit.
func _classify(s: Dictionary, grid: TileGrid, body: Body, target: Vector2i) -> void:
	if not grid.in_bounds(target):
		s["oob"] += 1
	elif not grid.is_solid(target):
		s["air"] += 1
	elif not Mining.in_reach(body.pos_x, body.pos_y, target):
		s["reach"] += 1
	else:
		s["working"] += 1


func _report(parsed: RevealReplayDriver.ParsedLog, s: Dictionary) -> void:
	var ticks: int = int(s["ticks"])
	var held: int = int(s["held"])
	var working: int = int(s["working"])
	var broke: int = int(s["broke"])
	print("=== SESSION: mode=%s site=%s seed=%d bite=%d ===" % [parsed.mode, parsed.site_id,
		parsed.seed_value, parsed.bite_radius])
	print("  ticks                 %d  (%.1f s at %d Hz)" % [ticks, float(ticks) / float(TICK_HZ), TICK_HZ])
	print("  mine button held      %d ticks  (%.1f s, %.0f%% of the session)"
		% [held, float(held) / float(TICK_HZ), 100.0 * float(held) / float(maxi(1, ticks))])
	print("  ... actually working  %d ticks  (%.0f%% of held)"
		% [working, 100.0 * float(working) / float(maxi(1, held))])
	print("  ... wasted: off-world %d | aimed at AIR %d | OUT OF REACH %d" % [s["oob"], s["air"], s["reach"]])
	print("  blows landed          %d   cells removed %d" % [broke, s["cleared"]])
	if broke > 0:
		print("  seconds per blow      %.2f s   first at tick %d (%.1f s in), last at %d"
			% [float(working) / float(broke) / float(TICK_HZ), s["first_break"],
			float(int(s["first_break"])) / float(TICK_HZ), s["last_break"]])
	for m: StringName in s["materials"]:
		print("      %-12s %d blows  (%d ticks each at zero rhythm)"
			% [m, (s["materials"] as Dictionary)[m], Mining.ticks_to_break(m)])
	print("  distinct cells aimed  %d  | aim changed cell %d times | longest hold on ONE cell %d ticks (%.2f s)"
		% [(s["aim_cells"] as Dictionary).size(), s["aim_changes"], s["longest_run"],
		float(int(s["longest_run"])) / float(TICK_HZ)])
	print("  bounds violations     %d" % s["violations"])
	print("  body rows %d..%d (spawn %d) -> NET DESCENT %d cells = %.2f m"
		% [s["min_row"], s["max_row"], s["spawn_row"], int(s["max_row"]) - int(s["spawn_row"]),
		float(int(s["max_row"]) - int(s["spawn_row"])) * float(CELL) / float(Body.LOGIC_TILE_PX)])


## The on-screen geometry the feel report is actually about. Printed, not asserted: these are properties of
## the world and the camera, not of the session, and the point is that they do not depend on the session.
func _geometry(grid: TileGrid, cleared: int) -> void:
	var view_w: float = float(RENDER_W) / ZOOM
	var view_h: float = float(RENDER_H) / ZOOM
	var body_cells: int = (Body.WIDTH_PX / CELL) * (Body.HEIGHT_PX / CELL)
	print("=== ON-SCREEN GEOMETRY (zoom %.1f, 2D render %dx%d) ===" % [ZOOM, RENDER_W, RENDER_H])
	print("  world             %d terrain cells wide = %d px = %.1f m"
		% [grid.width, grid.width * CELL, float(grid.width * CELL) / float(Body.LOGIC_TILE_PX)])
	print("  visible world     %.0f x %.0f px = %.0f x %.0f terrain cells"
		% [view_w, view_h, view_w / float(CELL), view_h / float(CELL)])
	print("  body              %d x %d px = %d x %d terrain cells"
		% [Body.WIDTH_PX, Body.HEIGHT_PX, Body.WIDTH_PX / CELL, Body.HEIGHT_PX / CELL])
	print("  body / screen     %.1f%% of width, %.1f%% of HEIGHT"
		% [100.0 * float(Body.WIDTH_PX) / view_w, 100.0 * float(Body.HEIGHT_PX) / view_h])
	print("  body / world      %.1f%% of the world's whole width"
		% [100.0 * float(Body.WIDTH_PX) / float(grid.width * CELL)])
	print("  cells per body    %d  -- a body-sized hole costs %d cells of removal" % [body_cells, body_cells])
	print("  session removed   %d cells = %.1f body-volumes" % [cleared, float(cleared) / float(body_cells)])
