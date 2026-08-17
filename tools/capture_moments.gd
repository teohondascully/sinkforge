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
##   teach — a line caught on a corner WITH the bubble the game raises for it, so the one thing a still
##           frame can say about onboarding — does the lesson arrive on the moment it explains? — is
##           answerable from the picture
##   counter / works / bench — THE BAZAAR panel on each of its three tabs, over a real world with a real
##           pack, so the one question a still frame can answer about a menu — can you read it, and can you
##           tell what it wants you to press? — is answerable. Three moments rather than one because the
##           tabs are three different layout problems (a grid, two priced columns, a graph).
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
		"aim":
			await _aiming(main)
		"land":
			await _landing(main)
		"bend":
			await _bending(main)
		"haul":
			await _hauling(main)
		"scarp":
			await _at_the_scarp(main)
		"teach":
			await _teaching(main)
		"counter", "works", "bench":
			await _at_the_counter(main, moment)
		"drift":
			await _at_the_drift(main)
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

## THE BEND. A line caught on a corner — the one state that was, until now, drawn as rope passing straight
## through solid rock. Built on the same geometry check_wrap measures: a hook in a high roof, a shelf
## jutting out below it, and a body swung under the shelf so the line has no choice but to catch.
func _bending(main: MainView) -> void:
	await _bending_geometry(main)
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0


## The rig both bend moments share: hook, shelf, and a body swung under it until the line catches.
func _bending_geometry(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var p: Player = main._player
	for x: int in range(30, 59):
		for y: int in range(20, 47):
			sim.mine(Vector2i(x, y))
	for y: int in range(24, 27):
		for x: int in range(34, 37):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(38, 45):
		sim.set_solid(Vector2i(x, 31), &"stone")
	p.auto_input = false
	p.place(Vector2(48.0 * 32.0 + 16.0, 29.0 * 32.0))
	for _i: int in 4:
		await physics_frame
	p.grapple.fire(p.hand(), Vector2(36.0 * 32.0 + 16.0, 26.0 * 32.0 + 16.0))
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	# Swing in until the line has actually caught, then hold that frame.
	for _i: int in 150:
		p.input_dir = -1.0
		await physics_frame
		if not p.grapple.pivots.is_empty():
			break
	p.input_dir = 0.0


## THE LESSON, in place. The bend from _bending, but with the bubble the game now raises the first time a
## line catches — the picture of a technique being taught at the moment it happens rather than in a manual.
## The hint is real: it is fired by the swing itself (asserted below), not painted on for the photograph.
## What is arranged is only WHICH of the fired hints is on screen, since a body this deep has also earned
## the depth hint and the queue would otherwise show that one first.
## THE BAZAAR, open. Stocks the pack first so the counter has something to price against — an empty pack
## makes every row unaffordable and the whole panel greys out, which judges the wrong thing.
func _at_the_counter(main: MainView, which: String) -> void:
	for item: StringName in [&"ingot", &"ore", &"coal", &"stone", &"wood", &"iron_ingot"]:
		main.sim.inventory[item] = 24
		main.sim.total_produced[item] = 24
	main._inventory_open = true
	main._hud.can_craft = true
	main._hud.set_bazaar_tab(1 if which == "works" else (2 if which == "bench" else 0))
	if which == "works":
		main._hud.bazaar_move(0, 2)
	elif which == "bench":
		main._hud.bazaar_move(0, 1)
	for _i in 6:
		await physics_frame


func _teaching(main: MainView) -> void:
	await _bending_geometry(main)
	if main._hints == null:
		return
	if not main._hints._done.has(&"wrapped"):
		push_warning("the swing never caught the corner — no lesson to photograph")
		return
	main._hints._queue.clear()
	main._hints._active = &"wrapped"
	main._hints._life = Hints.SHOW_SECONDS - 1.0    # past the fade-in, nowhere near the fade-out
	main._hints._lingered = 0.0
	for _i: int in 20:
		await physics_frame


## THE HAUL. A body mid-arc in a gallery, moving faster than it can run — the thing check_traverse measures
## and the one state no still frame in history/ has ever shown. Everything this strike added lands in the
## same picture: the taut line, the winch pulling along it, the streaks off the body, and the dust field
## blown backwards by the travel.
func _hauling(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var p: Player = main._player
	var floor_row: int = 46
	for x: int in range(20, 80):
		for y: int in range(floor_row - 7, floor_row):
			sim.mine(Vector2i(x, y))
		for y: int in range(floor_row - 10, floor_row - 7):
			if not sim.is_solid(Vector2i(x, y)):
				sim.set_solid(Vector2i(x, y), &"stone")
		if not sim.is_solid(Vector2i(x, floor_row)):
			sim.set_solid(Vector2i(x, floor_row), &"stone")
	p.auto_input = false
	p.place(Vector2(30.0 * 32.0, float(floor_row) * 32.0 - Player.HEIGHT))
	for _i: int in 8:
		await physics_frame
	# Swing until the body is genuinely quick and genuinely airborne, then stop the clock there.
	for _i: int in 420:
		p.input_dir = 1.0
		if not p.grapple.live():
			p.grapple.fire(p.hand(), p.hand() + Vector2(7.0 * 32.0, -6.0 * 32.0))
		elif p.grapple.state == Grapple.State.ANCHORED:
			p.input_climb = 1.0
			if p.position.x > p.grapple.anchor.x and p.velocity.x > 0.0:
				p.grapple.cut()
				p.input_climb = 0.0
		await physics_frame
		if p.grapple.taut and p.velocity.length() > Player.RUN_SPEED * 2.0:
			break
	p.input_climb = 0.0
	# The grapple HINT bubble is drawn across the middle of the frame, and this moment exists to photograph
	# the arc rather than the onboarding — the same reason check_water_reads hides the HUD before judging
	# pixels. Cleared HERE and not before the swing: the hint re-fires on depth every frame the body is
	# under the surface, so clearing it first just gives it four hundred frames to come back.
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0


## THE SCARP. Walk the body west out of the base until it is standing under the headland face — the one
## place on the surface where the ground stops being something you walk over. The terraces are the answer to
## a hard arithmetic limit (a walkable six-row hill needs sixty-three columns to rise over, and the world is
## a hundred and twenty-eight wide), so the relief that reads has to be a step rather than a slope. This is
## the shot that says whether that reads as a landscape or as a bug.
func _at_the_scarp(main: MainView) -> void:
	# PLACED rather than walked, and the reason is itself worth recording: the mouth ranked deepest in this
	# world opens at column 24, five columns off the headland's foot, so a body walking west out of the base
	# to look at the scarp falls down a sinkhole on the way and this shot came back from twenty-four metres
	# underground. That pair is good level design and a bad approach march. A photograph may stand where it
	# likes.
	var col: int = HeightmapWorldGen.SCARP_COLS[0] - 2
	var top: int = main.sim.surface_row(col)
	main._player.place(Vector2(float(col) * 32.0 + 16.0, float(top) * 32.0 - 24.0))
	for _i: int in 30:
		await physics_frame


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


## THE AIMING GHOST — the marker that says where the hook would bite, shot underground where it matters:
## a hollow with rock on several sides, the cursor parked on a far wall, the ring drawn on the cell the
## hook would actually take. Warps the mouse rather than the world, because the ghost reads the CURSOR and
## the whole question is whether what it draws matches where you are pointing.
const AIM_ROOM_W: int = 13
const AIM_ROOM_H: int = 7
const AIM_SETTLE: int = 12

func _aiming(main: MainView) -> void:
	await _dig_in(main)
	await _hollow_room(main)
	var p: Player = main._player
	var here: Vector2i = main._cell_at(p.position)
	# Point at the far wall of the chamber, high and to the side — the shot you would actually take to
	# leave a hole you have just finished digging.
	var target: Vector2 = main._cell_center(here + Vector2i(AIM_ROOM_W / 2, -AIM_ROOM_H))
	var vp: Viewport = main.get_viewport()
	vp.warp_mouse(vp.get_canvas_transform() * target)
	for _i: int in AIM_SETTLE:
		await physics_frame


## THE LANDING — the frame a real plunge arrives. Ride a found sinkhole all the way to whatever floor it
## has, and shoot a beat after touchdown, while the impact dust is still up and the body is still folded.
## The whole point of Strike 18 is that this moment now COSTS something, and a cost the player cannot see
## reads as the controller going vague, so this capture is the check on whether it reads.
const LAND_FALL: int = 900
const LAND_BEAT: int = 5              ## frames after touchdown — inside the held impact pose

func _landing(main: MainView) -> void:
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
	p.auto_input = false
	var guard: int = 0
	var airborne: bool = false
	while guard < LAND_FALL:
		p.input_dir = inward if p.on_floor and not airborne else 0.0
		await physics_frame
		guard += 1
		if not p.on_floor:
			airborne = true
		elif airborne:
			break                      # it has arrived
	for _i: int in LAND_BEAT:
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


## How far past the rig the gallery has actually been opened, both cells high — the number the shot's
## whole left-hand claim rests on.
func _drift_reach(sim: FactorySim, x0: int, row: int) -> int:
	var k: int = 0
	while k < 24 and not sim.solid.has(Vector2i(x0 + k + 1, row)) \
			and not sim.solid.has(Vector2i(x0 + k + 1, row - 1)):
		k += 1
	return k


## A DRIFT RIG mid-gallery: the one shot that can answer whether the machine's two claims read from pixels.
## The gallery behind it should look WALKABLE (two cells high, with the miner standing in it for scale), and
## the two streams should be visibly separate — ore falling down one shaft, spoil down the other — which is
## the whole thing you paid for and the whole thing a still frame can check.
func _at_the_drift(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 34
	# A level bench of rock for the gallery to run through, with a mixed face ahead of the rig.
	for x: int in range(x0 - 8, x0 + 40):
		for y: int in range(row - 8, row + 12):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(x0 - 8, x0 + 4):                       # the gallery already driven, two high
		for y: int in [row, row - 1]:
			sim.set_solid(Vector2i(x, y), &"")
	# The face, four cells ahead: rock banded with ore. The seams are THIN on purpose (a handful of units
	# where worldgen writes 30–200) so that seven seconds of real cutting puts both classes of material in
	# the shot — ore, then rock, then ore. A real vein would hold the rig on one cell for minutes, which is
	# the correct game and a useless photograph.
	for k: int in range(4, 26):
		for dy: int in [0, -1]:
			if (k + dy) % 3 == 0:
				var seam := Vector2i(x0 + k, row + dy)
				sim.set_solid(seam, &"ore")
				sim.deposits[seam] = 4
	# The two drop shafts, dug where the rig's two columns are — the player's half of the bargain — falling
	# into a lit SUMP. Both halves are for the photograph and both are what a player would build: short
	# shafts so the landed piles are in the same frame as the machine that sorted them, and a chamber at
	# the bottom because two piles at the foot of two unlit one-cell holes are two dark smudges.
	for y: int in range(row + 1, row + 6):
		sim.set_solid(Vector2i(x0, y), &"")
		sim.set_solid(Vector2i(x0 - 1, y), &"")
	for x: int in range(x0 - 4, x0 + 3):
		for y: int in [row + 5, row + 6]:
			sim.set_solid(Vector2i(x, y), &"")
	for x: int in [x0 - 3, x0 + 1]:
		sim.torch[Vector2i(x, row + 5)] = true
	var rig: MachineState = sim.place_machine(load("res://src/data/machines/drift_rig.tres") as MachineDef,
		Vector2i(x0, row))
	rig.facing = 1
	# Its network: three generators on a conduit trunk, which is what full speed actually costs. The pocket
	# they sit in has to be CUT first — place_machine refuses a cell that is still rock, which is how the
	# first pass at this shot ended up with three nulls and no power.
	for x: int in range(x0 - 2, x0 + 3):
		for y: int in range(row - 6, row - 1):
			sim.set_solid(Vector2i(x, y), &"")
	# The trunk has to come all the way DOWN to the ceiling cell over the rig: a conduit bleeds to ADJACENT
	# cells only, and a generator's aura is two, so a trunk that stops two cells short powers nothing at all
	# (the first build of this shot read `no_power` for exactly that reason). Same geometry check_drift
	# measures at a full 1.00 throttle.
	var gen: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
	for dx: int in [-1, 0, 1]:
		var g: MachineState = sim.place_machine(gen, Vector2i(x0 + dx, row - 4))
		g.input_buffer[&"coal"] = 200
		g.fuel = FactorySim.GENERATOR_FUEL_TICKS
	sim.inventory[&"conduit"] = 40
	for k: int in range(3, 0, -1):
		sim.place_conduit(Vector2i(x0, row - k))
	# Light the gallery. Underground, an unlit two-high tunnel reads as "dark" and nothing else — the first
	# pass at this shot was a black frame with a machine in the corner of it. A torch's strong pool is 4.4
	# cells, so they hang every three along the ceiling, with one down the shafts to light where the two
	# streams LAND. That is exactly the spacing a player who walked this drift would have left behind.
	for x: int in [x0 - 7, x0 - 4, x0 - 1]:
		sim.torch[Vector2i(x, row - 1)] = true
	sim.torch[Vector2i(x0 - 1, row + 3)] = true
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 4) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 900:                                        # let it cut, and let both streams fall
		await physics_frame
	# What the shot is claiming, printed. A still frame of a machine that did nothing looks a lot like a
	# still frame of a machine that worked, so the capture says out loud what the pixels should be showing.
	print("DRIFT  status=%s  pay=%s  spoil=%s  cut_to=+%d" % [
		sim.machine_status(rig), sim.ground.get(Vector2i(x0, row + 6), {}),
		sim.ground.get(Vector2i(x0 - 1, row + 6), {}), _drift_reach(sim, x0, row)])
	# One more torch on the FRESH face, hung in the deepest column the rig has actually opened. Placed after
	# the run, not before: the whole point of this lamp is to prove the gallery on the far side of the
	# machine was cut by the machine, and before the run there is nothing there to light.
	for k: int in range(8, 0, -1):
		if not sim.solid.has(Vector2i(x0 + k, row)) and not sim.solid.has(Vector2i(x0 + k, row - 1)):
			sim.torch[Vector2i(x0 + k, row - 1)] = true
			break
	main._renderer.repaint_world()
	for _i: int in 40:                                         # let the veil re-cut around the new lamp
		await physics_frame
	if main._hints != null:                                    # the tutorial bubble is not part of the shot
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0


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
