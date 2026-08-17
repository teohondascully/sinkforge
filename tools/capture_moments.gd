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
##   pack  — THE WALL THAT WEEPS: one reservoir, two galleries, one plugged with loose stone and one with
##           packed gravel — the only shot whose subject is a difference rather than a thing
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

## The moments whose whole claim is "this is underground" — every one of them is built on `_dig_in`, and
## every one of them is a lie if the shaft was never sunk. Named here rather than inferred so that adding a
## moment which delves and forgetting to list it is the only way to escape the guard.
const DELVED: Array[String] = ["delve", "room", "swing"]

## Rows the body actually descended during `_dig_in`, measured against the surface as it stood BEFORE the
## shaft was cut. -1 = no delve was attempted, which is correct for the moments that do not need one and is
## why the guard below only consults it for DELVED.
var _delve_rows: int = -1

## WHAT EACH MOMENT IS ALLOWED TO LOOK LIKE. This fixture boots the real, input-responsive scene and
## then takes minutes to reach its subject, so anything the window receives in that time lands in the
## photograph. It did: `_moment_delve.png` — one of the three canonical frames the 2026-08-17 audit
## reviewed — came back showing the full Bazaar/Pack modal and `PAUSED (P)` instead of a lamp-lit shaft.
## An `E` and a `P` arrived mid-run. The audit threw the image out, but nothing else did: the contaminated
## PNG had already overwritten the good one and the process exited 0, so the capture FAILED OPEN and the
## bad frame became the evidence.
##
## Two fixes, because either alone is insufficient. `_deafen` stops device input reaching any node, so the
## picture is a pure function of this script. This table is the belt to that brace: before a single byte is
## written the scene is checked against what the moment CLAIMS to be showing, and a mismatch refuses the
## write and exits non-zero. A stale good capture beats a fresh bad one, because only the fresh one gets
## believed.
##
## Empty override = the default contract: no modal, not paused, no title veil. The Bazaar moments are the
## interesting case — they open the pack deliberately, so for them an OPEN modal is the pass condition and
## a closed one is the failure.
const CALM: Dictionary = {
	"_inventory_open": false, "_paused": false, "_settings_open": false,
	"_show_help": false, "_title_open": false,
}
const EXPECT: Dictionary = {
	"counter": {"_inventory_open": true},
	"works": {"_inventory_open": true},
	"bench": {"_inventory_open": true},
	"map": {"_minimap_mode": 2},
}


func _initialize() -> void:
	var uargs := OS.get_cmdline_user_args()
	var moment := (uargs[0] if uargs.size() > 0 else "boot")
	var zoom_idx := (int(uargs[1]) if uargs.size() > 1 else 0)
	var ore_nug := (uargs[2] if uargs.size() > 2 else "")     # optional hex to override ore nugget colour
	var suffix2 := (uargs[3] if uargs.size() > 3 else "")     # optional filename suffix for A/B variants
	if ore_nug != "":
		var ore := load("res://src/data/materials/ore.tres") as MaterialDef
		ore.nugget_color = Color(ore_nug)                     # in-memory only (resource cache); never saved
	var code: int = await _capture(moment, zoom_idx, suffix2)
	quit(code)


## Take every node's ears off. `_unhandled_input`, `_input` and `_unhandled_key_input` are the three doors
## a keystroke can walk through to reach MainView's verb router, and this shuts all of them on every node
## in the tree — the scripted fixture below is then the ONLY thing that can change the scene. Done by
## recursion rather than by naming MainView, because the HUD, the settings page and anything added later
## have doors too, and a list of them would rot.
##
## MUST BE CALLED AFTER A FRAME HAS PASSED, and it is worth knowing why, because calling it in the obvious
## place does nothing at all. A SceneTree script's `_initialize()` runs before the tree is up, so the
## `_ready()` triggered by `add_child` is deferred — and Godot re-arms unhandled-input delivery for a node
## whose script defines `_unhandled_input` as part of that. Deafen first and `_ready` quietly turns the ears
## back on behind you. Measured 2026-08-17 with an E/P injection: deafened-before-ready left
## `is_processing_unhandled_input() == true` and the modal opened and the game paused exactly as if nothing
## had been done. Deafened after one frame: flag false, injection lands on the floor. `_contamination`
## re-checks the flag at the shutter, so a future re-arm fails the capture instead of quietly photographing
## whatever the keyboard did.
func _deafen(n: Node) -> void:
	# THE CALLBACK PATH — and it is only half the hardware. Turning these off stops _input/_unhandled_input
	# being delivered; it does nothing whatsoever to POLLING, which reads the driver's live state every
	# physics frame regardless. player.gd asks for the move axis, the climb axis and the jump button that
	# way, and main.gd asks for MINE, so before this a hand resting on W or a held mouse button would walk
	# or MINE the miner through a capture that takes seconds — and the check below could not see it,
	# because it inspected modal state and a callback flag, and polling is neither.
	Controls.deaf = true
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	for c: Node in n.get_children():
		_deafen(c)


## "" when the scene really is showing what `moment` claims, otherwise what is wrong with it.
func _contamination(main: MainView, moment: String) -> String:
	var want: Dictionary = CALM.duplicate()
	for k: Variant in (EXPECT.get(moment, {}) as Dictionary):
		want[k] = (EXPECT[moment] as Dictionary)[k]
	var wrong: Array[String] = []
	# A DELVE SHOT MUST BE UNDERGROUND. Every moment built on `_dig_in` claims, by its name, to be a frame
	# from inside a shaft — and the shaft is cut by an agent that can silently decline to dig (see _dig_in).
	# Measured against the surface row recorded BEFORE the dig, never after: sinking a shaft down a column
	# moves that column's own `surface_row` to the bottom of the hole, so a body compared against the live
	# value reads as standing on the surface no matter how deep it went, and the guard would pass on the
	# one frame it exists to catch.
	if moment in DELVED and _delve_rows < DELVE_ROWS / 2:
		wrong.append(("this moment is cut from a shaft and the body is only %d rows below where the "
			+ "surface was — the delve did not happen, so the frame is of daylight") % _delve_rows)
	if main.is_processing_unhandled_input():
		wrong.append("the scene is still LISTENING to input — _deafen did not take, so this frame is not "
			+ "a pure function of the fixture")
	if not Controls.deaf:
		wrong.append("live input POLLING is still connected — player.gd reads the move/climb/jump state "
			+ "and main.gd reads MINE every physics frame, so a key held down during this capture walked "
			+ "or mined the miner and the shot is of the keyboard, not the fixture")
	for field: Variant in want.keys():
		var got: Variant = main.get(String(field))
		if got == null:
			wrong.append("%s: no such field (this guard has rotted)" % field)
		elif got != want[field]:
			wrong.append("%s is %s, expected %s" % [field, got, want[field]])
	return ", ".join(wrong)


func _capture(moment: String, zoom_idx: int, name_suffix: String = "") -> int:
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	await physics_frame               # let the deferred _ready() land before taking its ears off
	_deafen(main)
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
		"pack":
			await _at_the_packing(main)
		"refuse":
			await _at_the_refusal(main)
		"lode":
			await _at_the_lode(main)
		"adit":
			await _at_the_adit(main)
		"head":
			await _at_the_head(main)
		"chain":
			await _at_the_chain(main)
		"stain":
			await _at_the_stain(main)
		"map":
			await _dig_in(main)
			main._minimap_mode = 2       # MainView owns the mode and pushes it to the HUD each frame
			for _i in 8:
				await physics_frame
		_:
			# FAIL CLOSED. This used to `push_warning` and fall through, so a typo'd moment name captured
			# the boot screen and saved it as `_moment_<typo>.png` — a picture of the wrong thing, under
			# the right name, exit 0. The match arms above ARE the list of moments; keeping a second copy
			# in a constant to validate against would be one more hand-maintained registry to rot.
			printerr("capture_moments: unknown moment '%s' — refusing to save a boot frame under its name" % moment)
			return 2

	var suffix := ""
	if zoom_idx > 0:
		for _c in zoom_idx:
			main._cycle_zoom()
		suffix = "_z%d" % zoom_idx
		for _j in 12:
			await physics_frame

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw    # the veil/light layers repaint a frame behind a camera move
	var path := "res://_moment_%s%s%s.png" % [moment, suffix, name_suffix]

	# A moment's helper may have added nodes of its own since the first pass, and a new node arrives with
	# its ears on. Re-deafen, then let the gate below confirm it took.
	_deafen(main)

	# THE GATE. Checked BEFORE the image is taken, let alone written: a contaminated run must leave
	# whatever is already on disk exactly where it is. The audit's delve shot was believed precisely
	# because the bad frame replaced the good one and said nothing.
	var wrong: String = _contamination(main, moment)
	if wrong != "":
		printerr("capture_moments: REFUSED '%s' — the scene is not what this moment claims: %s" % [moment, wrong])
		printerr("capture_moments: %s left untouched (%s)"
			% [path, "no previous capture" if not FileAccess.file_exists(path) else "previous capture kept"])
		return 1

	# NOTHING OVERWRITES A CAPTURE THAT HAS NO COPY.
	#
	# WRITTEN ON A PREMISE THAT WAS TRUE FOR THREE HOURS. The original text here said the 44 `_moment_*.png`
	# are gitignored, so git holds no version of any of them — correct when this landed, and false by the
	# same afternoon: the captures and `history/` were committed (3c46c8c, 4047b4a), so git now holds every
	# one. The rationale is corrected rather than deleted, because the guard still earns its place and the
	# reason it does has changed.
	#
	# WHAT IT PROTECTS NOW is the UNCOMMITTED generation, which is the one the work actually happens in:
	# capture, look, disagree, recapture — all before any commit exists to fall back to. `git checkout` can
	# return you to the last committed frame; it cannot return you to the one you took twenty minutes ago
	# and have not yet decided about. The gate above stops a CONTAMINATED capture replacing a good one, and
	# does nothing about a perfectly valid capture of a moment you did not mean to retake.
	#
	# The `docs/DECISIONS.md` rule about never destroying the user's artifacts is why this exists at all,
	# and it was written while the tool that overwrites them was left unchanged — the same gap as a locked
	# commit trailer that 23 commits carried anyway. A rule in a document is enforced by whoever last read
	# the document.
	#
	# One generation is enough to be an undo. If the copy cannot be made, REFUSE — a capture is worth less
	# than the capture it would destroy, so the failing side is the side that keeps what already exists.
	if FileAccess.file_exists(path):
		var keep: String = "res://_moment_prev/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(keep))
		var prev: String = keep + path.get_file()
		var err: int = DirAccess.copy_absolute(ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(prev))
		if err != OK:
			printerr("capture_moments: REFUSED '%s' — could not back up the existing %s (error %d)."
				% [moment, path, err])
			printerr("capture_moments: nothing was written. The committed frame is recoverable with"
				+ " `git checkout -- %s`, but any UNCOMMITTED capture at that path is not." % path)
			return 1
		print("  kept the previous %s at %s" % [path.get_file(), prev])

	var img := get_root().get_texture().get_image()
	img.save_png(path)
	# THE MANIFEST. A reviewer looking at a folder of PNGs cannot tell a delve from a Bazaar screenshot,
	# which is how a Bazaar screenshot got reviewed as a delve. One line per capture, saying what was
	# actually in front of the camera.
	var cell: Vector2i = main._body_cell() if main.has_method("_body_cell") else Vector2i(-1, -1)
	print("CAPTURED %s -> %s (%dx%d) | settled=%d body=%s zoom=%.2f modal=%s paused=%s"
		% [moment, ProjectSettings.globalize_path(path), img.get_width(), img.get_height(),
			SETTLE, cell, main._current_zoom(),
			"pack" if main._inventory_open else ("settings" if main._settings_open else "none"),
			main._paused])
	return 0


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
	# THE SHAFT HAS TO ACTUALLY BE SUNK, and until now nothing here checked that it was.
	#
	# `dig_down_to` exits on `not sim.is_solid(cell)`, which means BOTH "I finished digging" and, on the
	# first iteration, "the target was already open" — the two-contracts bug found on a later pass in
	# `PlayAgent` (it is why `check_underground` graded a sunlit surface on seed 99 for its whole life).
	# A world with a void under the spawn column would return true immediately, and every frame below
	# would be a photograph of DAYLIGHT filed under `delve`, `room` and `swing`.
	#
	# So: `require_arrival` on, and the return value read rather than discarded. The depth is also recorded
	# for the shutter guard in `_contamination`, because a return value proves the agent believed it
	# arrived and the row it ends on proves it did.
	var target := Vector2i(here.x, main.sim.surface_row(here.x) + DELVE_ROWS)
	var surface_before: int = main.sim.surface_row(here.x)
	var sank: bool = await agent.dig_down_to(target, 2400, true)
	_delve_rows = main._cell_at(agent.player.position).y - surface_before
	if not sank:
		printerr("capture_moments: the delve shaft did not reach row %d (body %d rows down)"
			% [target.y, _delve_rows])
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


## THE ROCK THAT SAYS NO (`docs/BITS.md` §5). A wall over your drive, with the cursor on it: cold, crossed,
## refusing BEFORE the press — and the line that names the rung. The one shot that can answer whether a hard
## gate reads as a locked door rather than as a broken click.
##
## The cursor has to be really ON the wall for this, and the mining loop derives the aim from the real mouse,
## so the shot WARPS the pointer (a real window exists — this capture never runs headless) to the screen
## position of the cell two to the body's right, and then actually holds the button down.
func _at_the_refusal(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 40
	for x: int in range(x0 - 12, x0 + 13):
		for y: int in range(row - 6, row + 6):
			sim.set_solid(Vector2i(x, y), &"deepslate")
	for x2: int in range(x0 - 6, x0):                          # the drift you cut to get here; the FACE is x0
		for y2: int in [row, row - 1]:
			sim.set_solid(Vector2i(x2, y2), &"")
	for x3: int in range(x0 - 6, x0):
		sim.set_solid(Vector2i(x3, row - 2), &"stone")
		sim.set_solid(Vector2i(x3, row + 1), &"stone")
	sim.inventory.erase(&"stone_pickaxe")                      # the starter drive only — that is the point
	sim.inventory.erase(&"iron_pickaxe")
	sim.inventory[&"wood_pickaxe"] = 1
	main._inv_selected = 0
	for x4: int in [x0 - 5, x0 - 1]:
		sim.torch[Vector2i(x4, row - 1)] = true
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 2) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 30:
		await physics_frame
	# The pointer, onto the face. HUD_SCALE-independent: the window is 1.5x the render viewport, one cell is
	# 32 world px, and the camera holds the body at the centre of the frame.
	Input.warp_mouse(Vector2(960.0 + 2.0 * 32.0 * 1.5, 540.0 - 8.0))
	for _i2: int in 6:
		await physics_frame
	Input.action_press(Controls.MINE)
	for _i3: int in 40:                                        # long enough to skid twice and say why
		await physics_frame
	Input.action_release(Controls.MINE)
	for _i4: int in 6:
		await physics_frame
	print("REFUSE  aim=%s  material=%s  refuses=%s  said: %s" % [main._aim,
		str(sim.material_at(main._aim)), str(main._refuses(main._aim)), main._hud._flash_text])
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0
	main._hud._arrival_life = 0.0      # the stratum plate fired on the way in; it isn't this shot's subject
	main._hud.objectives = null        # …and neither is the opening ladder. Staging, not a game change.


## THE VEIN IN THE WALL. A working cut into ore-rich rock, with the face opened at four different states of
## depletion side by side: full, two-thirds, a third, and worked dry. That progression IS the subject —
## `deposits` is the number the player is meant to plan around and until this strike it was never once on
## screen, so a fat vein and a spent one were the same pixels. Staged rather than played, for the same reason
## the Drift shot seeds thin seams: showing four states at once is a photograph of a rule, not of a session.
func _at_the_lode(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 40
	for x: int in range(x0 - 14, x0 + 15):
		for y: int in range(row - 8, row + 8):
			sim.set_solid(Vector2i(x, y), &"stone")
			sim.lode.erase(Vector2i(x, y))
			sim.deposits.erase(Vector2i(x, y))
	for x2: int in range(x0 - 8, x0 + 6):                      # the chamber you cleared to see the wall
		for y2: int in range(row - 3, row + 1):
			sim.set_solid(Vector2i(x2, y2), &"")
	# THE FACE: four cells of the same vein, opened, at four states of depletion. Left to right so the eye
	# reads it as one vein being worked rather than four different things.
	var states: Array[int] = [FactorySim.DEFAULT_ORE_DEPOSIT, 160, 70, 0]
	for i: int in states.size():
		for dy: int in [-1, -2]:                               # at eye level, and two cells tall, so it READS
			var c := Vector2i(x0 - 6 + i * 3, row + dy)
			sim.lode[c] = &"ore"
			if states[i] > 0:
				sim.deposits[c] = states[i]
			else:
				sim.lode.erase(c)                              # worked dry: it stops being a vein at all
	# …and one still BEHIND rock, untouched, so the shot also says what you have not got to yet.
	for dy2: int in [-1, -2]:
		var buried := Vector2i(x0 + 6, row + dy2)
		sim.set_solid(buried, &"ore")
		sim.deposits[buried] = FactorySim.DEFAULT_ORE_DEPOSIT
	for t: int in [x0 - 8, x0 - 3, x0 + 2]:
		sim.torch[Vector2i(t, row - 1)] = true
	sim.inventory[&"wood_pickaxe"] = 1
	main._inv_selected = 0
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 5) * 32.0, float(row) * 32.0 - Player.HEIGHT))
	for _i: int in 30:
		await physics_frame
	Input.warp_mouse(Vector2(960.0 + 2.0 * 32.0 * 1.5, 540.0 - 32.0))   # cursor on the half-worked face
	Input.action_press(Controls.MINE)
	for _i2: int in 30:
		await physics_frame
	Input.action_release(Controls.MINE)
	for _i3: int in 4:
		await physics_frame
	print("LODE  aim=%s  lode=%s  left=%d  frac=%.2f" % [main._aim, str(sim.lode_at(main._aim)),
		sim.ore_deposit_at(main._aim), sim.lode_fraction(main._aim)])
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0
	main._hud._arrival_life = 0.0
	main._hud.objectives = null


## THE FIRST FACE. Nothing is staged: this is the real spawn, seeded by WorldSeeder exactly as a new player
## gets it, with the body walked over to the adit and the cursor on the vein. If the fixture ever stops being
## visible from the surface, this shot says so.
func _at_the_adit(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var probe := Vector2i(MainView.ADIT_CHAMBER_COL, MainView.SURFACE + MainView.ADIT_ROOF + 1)
	main._player.auto_input = false
	main._player.place(Vector2(float(MainView.ADIT_COLS[0] - 1) * 32.0,
		float(MainView.SURFACE) * 32.0 - Player.HEIGHT))
	for _i: int in 40:
		await physics_frame
	Input.warp_mouse(Vector2(960.0 + 3.0 * 32.0 * 1.5, 540.0 + 2.5 * 32.0 * 1.5))
	for _i2: int in 8:
		await physics_frame
	print("ADIT  lode=%s  left=%d  workable=%s" % [str(sim.lode_at(probe)),
		sim.ore_deposit_at(probe), str(sim.lode_workable(probe))])
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0
	main._hud._arrival_life = 0.0


## STAND IT ON THE THING IT EATS. A Head working a face it is standing on, pouring down its own column into
## the sump it was placed over — beside the same vein still being worked by hand. The subject is the
## PLACEMENT: one machine, one cell, on the ore. The old model needed three facts right (somewhere above it,
## same column, drain under the bottom) before anything happened at all.
## THE STAIN. A lit gallery with a fat ore BODY still buried in the rock past its far wall, and a second,
## poorer one below the floor. Nothing is exposed: the whole question this shot answers is whether a player
## standing in a room they have cleared can tell where to dig NEXT without a readout, a sonar or a swing.
## If the bodies cannot be picked out of the rock here, the stain is too quiet and the cutover would leave
## the world unreadable; if they read like map markers it is too loud and clearing rock stops meaning
## anything. Both failures are visible in this one frame.
func _at_the_stain(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 44
	var x0: int = 40
	for x: int in range(x0 - 18, x0 + 19):
		for y: int in range(row - 10, row + 14):
			sim.set_solid(Vector2i(x, y), &"stone")
			sim.lode.erase(Vector2i(x, y))
			sim.lode_max.erase(Vector2i(x, y))
			sim.deposits.erase(Vector2i(x, y))
	for x2: int in range(x0 - 8, x0 + 5):                      # the room you are standing in
		for y2: int in range(row - 3, row + 1):
			sim.set_solid(Vector2i(x2, y2), &"")
	# A FAT BODY, buried, just past the room's right-hand wall — the thing you are meant to notice.
	# It starts AT the room's wall, because that is where the question is actually asked: you are standing in
	# lamplight looking at the face in front of you, deciding which way to cut. Two cells further out it is in
	# the dark, and a tell that only answers your lamp cannot be seen where no lamp reaches — which is correct
	# behaviour and a useless photograph.
	for dx: int in range(0, 5):
		for dy: int in range(-4, 2):
			if absi(dx - 1) + absi(dy + 1) > 4:
				continue                                       # a blob, not a rectangle
			var c := Vector2i(x0 + 5 + dx, row + dy)
			if OS.has_environment("SF_NO_LODE"):
				continue            # the A/B half of the calibration rig — see the print at the end
			sim.lode[c] = &"ore"
			sim.deposits[c] = 200
			sim.lode_max[c] = 200
	# …and a poorer one in the FLOOR you are standing on, where the light is strongest of all.
	for dx2: int in range(0, 6):
		for dy2: int in range(1, 3):
			var c2 := Vector2i(x0 - 7 + dx2, row + dy2)
			if OS.has_environment("SF_NO_LODE"):
				continue
			sim.lode[c2] = &"coal"
			sim.deposits[c2] = 140
			sim.lode_max[c2] = 140
	for t: int in [x0 - 7, x0 - 2, x0 + 3]:
		sim.torch[Vector2i(t, row - 3)] = true
	sim.inventory[&"wood_pickaxe"] = 1
	main._inv_selected = 0
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 3) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 60:
		await physics_frame
	Input.warp_mouse(Vector2(300.0, 240.0))
	for _i2: int in 8:
		await physics_frame
	var buried: int = 0
	for key: Variant in sim.lode:
		if sim.is_solid(key):
			buried += 1
	# The calibration number, printed rather than eyeballed. WorldRenderer.LODE_STAIN_BURIED* were tuned by
	# capturing this moment twice — once with SF_NO_LODE=1 to suppress the bodies — and measuring the luma of
	# matched boxes in the two frames. Run-to-run noise from animation phase alone reaches ±8% in a bad run,
	# so the delta below is the honest read and anything under about 5% is not a signal.
	var r: WorldRenderer = main._renderer
	var probe := Vector2i(x0 - 5, row + 1)
	var near := Vector2i(x0 + 1, row + 1)
	var a: Color = r._cell_base_color(probe, r._material(sim.material_at(probe)))
	var b: Color = r._cell_base_color(near, r._material(sim.material_at(near)))
	var la: float = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
	var lb: float = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
	print("STAIN  buried=%d  probe=%s  stained luma %.3f vs plain %.3f (%+.1f%%)"
		% [buried, str(sim.lode.get(probe, &"-")), la, lb, 100.0 * (la - lb) / maxf(lb, 0.001)])
	if main._hints != null:
		main._hints._active = &""
	main._hud.objectives = null


## THE CHAIN. One Head, four Spurs, one seam, one drain — the picture `docs/LODE.md` §5 is describing when
## it says a vein stops being a number and becomes a layout. The seam is CONTIGUOUS on purpose (the `head`
## moment's is every other cell, which is the shape a chain cannot cross) and it thins left to right, so the
## bores widen along the line and the machine reads as a gauge of the thing it is standing on.
func _at_the_chain(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 40
	for x: int in range(x0 - 16, x0 + 17):
		for y: int in range(row - 9, row + 11):
			sim.set_solid(Vector2i(x, y), &"stone")
			sim.lode.erase(Vector2i(x, y))
			sim.deposits.erase(Vector2i(x, y))
	for x2: int in range(x0 - 9, x0 + 8):                      # the gallery you cut to reach across it
		for y2: int in range(row - 3, row + 1):
			sim.set_solid(Vector2i(x2, y2), &"")
	var seam_row: int = row - 1
	for i: int in 9:                                           # the seam, contiguous, thinning as it goes
		var c := Vector2i(x0 - 6 + i, seam_row)
		sim.lode[c] = &"ore"
		sim.deposits[c] = 220 - i * 24
		sim.lode_max[c] = 220
	var head_cell := Vector2i(x0 - 4, seam_row)
	for y3: int in range(row, row + 7):                        # the ONE sump the whole chain pours into
		sim.set_solid(Vector2i(head_cell.x, y3), &"")
	for t: int in [x0 - 9, x0 - 1, x0 + 6]:
		sim.torch[Vector2i(t, row - 3)] = true   # on the gallery's ROOF row: the seam row belongs to the chain
	var drill: MachineState = sim.place_machine(load("res://src/data/machines/drill.tres") as MachineDef,
		head_cell)
	if drill != null:
		drill.input_buffer[&"coal"] = 900
	var spurs: int = 0
	for dx: int in [-2, -1, 1, 2, 3]:
		if sim.place_machine(load("res://src/data/machines/spur.tres") as MachineDef,
				head_cell + Vector2i(dx, 0)) != null:
			spurs += 1
	sim.inventory[&"wood_pickaxe"] = 1
	main._inv_selected = 0
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 8) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 300:                                        # let it run, so the bores have widened unevenly
		await physics_frame
	Input.warp_mouse(Vector2(340.0, 250.0))     # OFF the chain: a name plate would cover the subject
	for _i2: int in 8:
		await physics_frame
	print("CHAIN  spurs=%d  reach=%d  produced=%d  status=%s" % [
		spurs, sim.head_coverage(head_cell).size(), int(sim.total_produced.get(&"ore", 0)),
		str(sim.machine_status(drill)) if drill != null else "none"])
	if main._hints != null:
		main._hints._active = &""
	main._hud.objectives = null


func _at_the_head(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 40
	for x: int in range(x0 - 14, x0 + 15):
		for y: int in range(row - 8, row + 10):
			sim.set_solid(Vector2i(x, y), &"stone")
			sim.lode.erase(Vector2i(x, y))
			sim.deposits.erase(Vector2i(x, y))
	for x2: int in range(x0 - 8, x0 + 5):                      # the chamber you cleared to find the vein
		for y2: int in range(row - 3, row + 1):
			sim.set_solid(Vector2i(x2, y2), &"")
	for i: int in 5:                                           # the vein, exposed across the back of it
		for dy: int in [-1, -2]:
			var c := Vector2i(x0 - 6 + i * 2, row + dy)
			sim.lode[c] = &"ore"
			sim.deposits[c] = 190 - i * 34
	var head_cell := Vector2i(x0 - 2, row - 1)
	for y3: int in range(row, row + 6):                        # the sump the Head pours into
		sim.set_solid(Vector2i(head_cell.x, y3), &"")
	for t: int in [x0 - 8, x0 - 4, x0 + 2]:
		sim.torch[Vector2i(t, row - 1)] = true
	var drill: MachineState = sim.place_machine(load("res://src/data/machines/drill.tres") as MachineDef,
		head_cell)
	if drill != null:
		drill.input_buffer[&"coal"] = 500
	sim.inventory[&"wood_pickaxe"] = 1
	main._inv_selected = 0
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 - 6) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 240:                                        # let it run, so there is a haul in the shaft
		await physics_frame
	Input.warp_mouse(Vector2(360.0, 260.0))     # OFF the machine: its name plate would cover the subject
	for _i2: int in 8:
		await physics_frame
	print("HEAD  status=%s  left=%d  produced=%d" % [
		str(sim.machine_status(drill)) if drill != null else "none",
		sim.ore_deposit_at(head_cell), int(sim.total_produced.get(&"ore", 0))])
	if main._hints != null:
		main._hints._active = &""
		main._hints._queue.clear()
		main._hints._life = 0.0
	main._hud._arrival_life = 0.0
	main._hud.objectives = null


## THE WALL THAT WEEPS, and the wall that doesn't. One reservoir with a gallery running out of either side
## of it: the left one plugged with the LOOSE stone you dug out of it, the right one plugged with PACKED
## GRAVEL. Run it, and the left gallery has a pool in its sump while the right one is bone dry. This is the
## only shot in the set whose subject is a DIFFERENCE, so it is built symmetrically on purpose — same rock,
## same gallery, same water, one variable.
func _at_the_packing(main: MainView) -> void:
	var sim: FactorySim = main.sim
	var row: int = 46
	var x0: int = 40
	for x: int in range(x0 - 24, x0 + 25):
		for y: int in range(row - 8, row + 10):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(x0 - 18, x0 + 19):                     # the two galleries + the reservoir between them
		for y: int in [row, row - 1]:
			sim.set_solid(Vector2i(x, y), &"")
	for y: int in range(row - 4, row + 1):                     # the reservoir: a tall pocket in the middle
		for x: int in range(x0 - 2, x0 + 3):
			sim.set_solid(Vector2i(x, y), &"")
	for y: int in range(row + 1, row + 4):                     # a sump on the left, so a weep reads as a POOL
		for x: int in range(x0 - 11, x0 - 6):
			sim.set_solid(Vector2i(x, y), &"")
	for y: int in range(row + 1, row + 4):                     # ...and its mirror on the right, still dry
		for x: int in range(x0 + 7, x0 + 12):
			sim.set_solid(Vector2i(x, y), &"")
	# The two plugs, PLACED BY HAND (place_block, not set_solid) — the whole difference lives in the fill
	# layer, and only construction writes it.
	sim.inventory[&"stone"] = 8
	sim.inventory[&"gravel"] = 8
	for y2: int in [row, row - 1]:
		sim.place_block(Vector2i(x0 - 3, y2), &"stone")
		sim.place_block(Vector2i(x0 + 3, y2), &"gravel")
	for y3: int in range(row - 4, row + 1):                    # fill the reservoir to the brim
		for x2: int in range(x0 - 2, x0 + 3):
			sim.add_water(Vector2i(x2, y3), FactorySim.WATER_MAX)
	# Torches either side of BOTH plugs: the whole shot is a comparison of two blocks, so both blocks
	# have to be lit well enough to tell apart.
	for x3: int in [x0 - 14, x0 - 8, x0 - 4, x0 + 4, x0 + 8, x0 + 14]:
		sim.torch[Vector2i(x3, row - 1)] = true
	main._renderer.repaint_world()
	main._player.auto_input = false
	main._player.place(Vector2(float(x0 + 6) * 32.0, float(row + 1) * 32.0 - Player.HEIGHT))
	for _i: int in 1500:                                       # ~25s: long enough for the left sump to fill
		await physics_frame
	var wet: int = 0
	var dry: int = 0
	for cell: Vector2i in sim.water:                           # count ONLY the two galleries: the world has
		if cell.y < row - 4 or cell.y > row + 4:               # aquifers of its own, and they are not the
			continue                                           # subject of this photograph
		if cell.x < x0 - 3 and cell.x > x0 - 19:
			wet += int(sim.water[cell])
		elif cell.x > x0 + 3 and cell.x < x0 + 19:
			dry += int(sim.water[cell])
	print("PACK  through the LOOSE plug: %d   ·   through the PACKED plug: %d" % [wet, dry])
	print("PACK  plugs: loose=%s/%s  packed=%s/%s" % [
		str(sim.material_at(Vector2i(x0 - 3, row))), str(sim.is_loose_fill(Vector2i(x0 - 3, row))),
		str(sim.material_at(Vector2i(x0 + 3, row))), str(sim.is_packed(Vector2i(x0 + 3, row)))])
	if main._hints != null:
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
