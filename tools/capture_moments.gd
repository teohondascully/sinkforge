extends SceneTree

## LOCAL DEV TOOL — the "Sees" blind-vision instrument's renderer (NOT committed; _moment_*.png is
## gitignored). Renders canonical game MOMENTS to _moment_<name>.png so a zero-context vision agent can
## judge legibility from pixels the way a first-time player would. Run WITHOUT --headless (needs a real
## GL context — headless is the dummy renderer and saves blank frames):
##   godot --path . --script res://tools/capture_moments.gd -- boot
##   godot --path . --script res://tools/capture_moments.gd -- boot 1   # optional zoom-index (Z levels)
## Moments:
##   boot  — the clean new-player opening (the surface, first frame a player ever sees)
##   delve — standing at the bottom of a dug shaft, lamp-lit, rock on every side
##   swing — mid-arc on a live grapple line, so the rope, the hook and the pose can be judged together
##   map   — the LARGE minimap over a dug world: the one view that shows the world's whole shape, and
##           so the only way to judge whether the descent reads as a journey rather than as a grid
##   room  — a torch-lit WORK CHAMBER: the only view that shows the back wall as a plane rather than as a
##           sliver, so it is the instrument for judging whether a carved-out space reads as a ROOM (a
##           recessed second plane with rock in front of it) or as a hole punched in a flat sheet. A
##           one-cell shaft can't answer that question, and the underground is played in rooms.
##
## `delve` exists because the surface is only half the game and it is the EASY half to judge: the sky
## does most of the composition and daylight does most of the lighting. Everything the underground
## depends on — the shadow veil, the head-lamp pool, carved-edge form, whether rock reads as mass or as
## fog — is invisible in a boot shot. It is dug by the real PlayAgent through the real verbs, so the
## shaft in frame is a shaft a player could actually have cut.

const SCENE := "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const SETTLE := 60
const DELVE_ROWS := 14            ## how far below the surface the delve shot digs


func _initialize() -> void:
	var uargs := OS.get_cmdline_user_args()
	var moment := (uargs[0] if uargs.size() > 0 else "boot")
	var zoom_idx := (int(uargs[1]) if uargs.size() > 1 else 0)
	var ore_nug := (uargs[2] if uargs.size() > 2 else "")     # optional hex to override ore nugget colour
	var suffix2 := (uargs[3] if uargs.size() > 3 else "")     # optional filename suffix for A/B variants
	if ore_nug != "":
		var ore := load("res://src/data/materials/ore.tres") as MaterialDef
		ore.nugget_color = Color(ore_nug)                     # in-memory only (resource cache); never saved
	await _capture(moment, zoom_idx, suffix2)
	quit(0)


func _capture(moment: String, zoom_idx: int, name_suffix: String = "") -> void:
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i in SETTLE:
		await physics_frame

	match moment:
		"boot":
			pass                              # the untouched clean opening
		"delve":
			await _dig_in(main)
		"room":
			await _dig_in(main)
			await _hollow_room(main)
		"swing":
			await _dig_in(main)
			await _hollow_room(main)
			await _swing(main)
		"line":
			await _the_line(main)
		"mouth":
			await _at_the_mouth(main)
		"plunge":
			await _plunging(main)
		"map":
			await _dig_in(main)
			main._minimap_mode = 2       # MainView owns the mode and pushes it to the HUD each frame
			for _i in 8:
				await physics_frame
		_:
			push_warning("unknown moment '%s' — capturing boot" % moment)

	var suffix := ""
	if zoom_idx > 0:
		for _c in zoom_idx:
			main._cycle_zoom()
		suffix = "_z%d" % zoom_idx
		for _j in 12:
			await physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw    # the veil/light layers repaint a frame behind a camera move
	var img := get_root().get_texture().get_image()
	var path := "res://_moment_%s%s%s.png" % [moment, suffix, name_suffix]
	img.save_png(path)
	print("CAPTURED %s -> %s (%dx%d)" % [moment, ProjectSettings.globalize_path(path), img.get_width(), img.get_height()])


## THE LINE RUNS — the frame the first-automation plate is on screen. Reached by PLAYING there: the same
## opening arc check_loop_health scores and check_pacing times, run to first automation, then paused a beat
## into the announcement so the plate, the sparks and the machine that earned them are all in the shot.
## Nothing is staged; if the ceremony ever stops firing, this capture goes blank and says so.
## The shutter has to be timed off the CEREMONY, not off the driver: the arc's last step stands back and
## waits out a fixed count while the line spins up, so by the time play() returns the plate has already
## come and gone. So the arc is run only as far as a fueled drill, and then we watch for the hail itself.
const ARC := preload("res://tools/arc_driver.gd")
const HAIL_WAIT := 2400              ## frames the fueled line is given to pour its first ingot
const HAIL_PEAK := 60                ## frames after the hail — inside the plate's full-opacity dwell

func _the_line(main: MainView) -> void:
	var agent: PlayAgent = AGENT.new(self, main)
	await ARC.new().play(agent, main._objectives, &"fuel")
	var guard := 0
	while not main._line_hailed and guard < HAIL_WAIT:
		await physics_frame
		guard += 1
	if not main._line_hailed:
		push_warning("the line never ran — capturing without the plate")
	for _i in HAIL_PEAK:
		await physics_frame


## THE MOUTH — a sinkhole seen from its lip. The hole is FOUND in the real generated world (the deepest
## plunge in the surface nearest the spawn) and walked to with the real body, so the shot is of terrain the
## generator actually made rather than a hole posed for the camera. If a world ever comes out without one,
## this warns and photographs the flat surface that replaced it.
const MOUTH_PLUNGE: int = 6          ## rows of surface drop that make a step a MOUTH rather than a hill
const MOUTH_STANDOFF: int = 2        ## columns back from the lip — close enough to see in, far enough to live
const MOUTH_SETTLE: int = 30

func _at_the_mouth(main: MainView) -> void:
	var agent: PlayAgent = AGENT.new(self, main)
	var sim: FactorySim = main.sim
	var here: int = main._cell_at(agent.player.position).x
	var lip: int = _mouth_lip(sim, here)
	if lip < 0:
		push_warning("no sinkhole mouth in this world — capturing the plain surface")
		return
	var stand: int = lip + (MOUTH_STANDOFF if lip < here else -MOUTH_STANDOFF)
	await agent.walk_to_column(clampi(stand, 2, FactorySim.GRID_COLS - 3), 1600)
	for _i: int in MOUTH_SETTLE:
		await physics_frame


## The standable side of the biggest break in the ground nearest `from` — the lip of a sinkhole.
func _mouth_lip(sim: FactorySim, from: int) -> int:
	var lip: int = -1
	for c: int in range(2, FactorySim.GRID_COLS - 2):
		var step: int = sim.surface_row(c) - sim.surface_row(c - 1)
		if absi(step) < MOUTH_PLUNGE:
			continue
		var edge: int = (c - 1) if step > 0 else c
		if lip < 0 or absi(edge - from) < absi(lip - from):
			lip = edge
	return lip


## THE PLUNGE — the body inside a sinkhole, hanging on the line, daylight overhead. Played, not posed:
## the same walk to the same found mouth, then off the lip, then a real fall arrested by a real hook bitten
## into the real shaft wall. If the rock ever stops offering purchase this capture comes back as a body
## lying at the bottom of a hole, which is the correct picture of that regression.
const PLUNGE_FALL: int = 15          ## rows down the shaft before reaching for the wall
const PLUNGE_HANG: int = 26          ## frames left hanging, so the line is taut and the dust has caught up

func _plunging(main: MainView) -> void:
	var agent: PlayAgent = AGENT.new(self, main)
	var sim: FactorySim = main.sim
	var p: Player = agent.player
	var here: int = main._cell_at(p.position).x
	var lip: int = _mouth_lip(sim, here)
	if lip < 0:
		push_warning("no sinkhole mouth in this world — capturing the plain surface")
		return
	var inward: float = 1.0 if lip > here else -1.0
	await agent.walk_to_column(clampi(lip - int(inward) * 2, 2, FactorySim.GRID_COLS - 3), 1600)

	var start: int = main._cell_at(p.position).y
	p.auto_input = false
	var guard: int = 0
	while guard < 600 and main._cell_at(p.position).y - start < PLUNGE_FALL:
		# Walk until the ground stops being there, then stop steering — a counted number of frames of input
		# is a guess about how far the lip is, and it guessed wrong: the body stood on the edge admiring it.
		p.input_dir = inward if p.on_floor else 0.0
		await physics_frame
		guard += 1
	p.input_dir = 0.0
	p.grapple.fire(p.hand(), p.hand() + Vector2(inward * MOUTH_STANDOFF * 32.0, -64.0))
	guard = 0
	while p.grapple.state == Grapple.State.FLYING and guard < 40:
		await physics_frame
		guard += 1
	for _i: int in PLUNGE_HANG:
		await physics_frame
	p.auto_input = true


## Sink a shaft under the spawn column and leave the body standing at the bottom of it. Driven through
## the PlayAgent — the same embodied driver the play-tests use — so the hole is one the real verbs cut
## with the real body, not a grid edit dressed up as one. The agent is handed a stone pickaxe first,
## because a shaft deep enough to be worth photographing runs into the tier-2 band.
func _dig_in(main: MainView) -> void:
	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var here: Vector2i = main._cell_at(agent.player.position)
	await agent.dig_down_to(Vector2i(here.x, main.sim.surface_row(here.x) + DELVE_ROWS))
	# Then hollow out a small CHAMBER at the bottom — the work pocket a player cuts when they stop to
	# set up a drill site. A one-cell shaft shows almost no back-wall, so a shaft-only shot is a bad
	# instrument for judging the second plane: this is the view the underground is actually played in.
	var floor_c: Vector2i = main._cell_at(agent.player.position)
	for dy: int in range(-2, 1):
		for dx: int in range(-2, 3):
			main.try_mine(floor_c + Vector2i(dx, dy))
			await physics_frame
	for _i in 20:                             # let the body settle and the veil re-cut around the lamp
		await physics_frame


## Widen the delve pocket into a proper CHAMBER and hang two torches in it. Cut through sim.mine rather
## than main.try_mine: try_mine enforces the player's 3.2-cell REACH, so a chamber wider than the miner's
## arms silently comes out as a small blob around them — which is exactly the bug that made the first
## three attempts at this shot unreadable. Reach is a gameplay rule, and a player builds this room by
## walking; the shot only needs the geometry that walking would leave.
const ROOM_W := 13
const ROOM_H := 7


func _hollow_room(main: MainView) -> void:
	var c: Vector2i = main._cell_at(main._player.position)
	var left: int = c.x - ROOM_W / 2
	for dy: int in range(-ROOM_H + 1, 1):
		for dx: int in range(ROOM_W):
			main.sim.mine(Vector2i(left + dx, c.y + dy))
		await physics_frame
	main.sim.torch[Vector2i(left + 2, c.y - 2)] = true
	main.sim.torch[Vector2i(left + ROOM_W - 3, c.y - 2)] = true
	main._renderer.repaint_world()
	for _i in 30:
		await physics_frame


## Hang the body off a live line in the middle of a swing. The grapple is the one thing in the game that
## cannot be judged from a still of it at rest — a rope reads as a rope only when it is under load — so
## the shot is taken mid-arc, with the body already moving.
func _swing(main: MainView) -> void:
	var p: Player = main._player
	var c: Vector2i = main._cell_at(p.position)
	p.auto_input = false
	p.grapple.fire(p.hand(), main._cell_center(Vector2i(c.x + 4, c.y - 6)))
	for _i in 90:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	p.position += Vector2(-40.0, -70.0)
	p.velocity = Vector2(240.0, 40.0)
	p.input_dir = 1.0
	for _i in 26:
		await physics_frame
