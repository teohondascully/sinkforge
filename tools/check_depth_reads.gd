extends "res://tools/check_base.gd"

## DOES THE RUNNING GAME KNOW HOW DEEP YOU ARE?
##
## There is a unit test (tests/test_worldgen.gd::_test_ground_survives_digging) that pins the two
## AUTHORITIES apart: `FactorySim.surface_row` follows you down a shaft, `HeightmapWorldGen.ground_row`
## does not. It is a good test and it does not cover the thing that was actually broken. Revert both
## consumers in main.gd to `sim.surface_row` and that test stays green, because it never asks the game
## anything — it asks the two functions. The bug was never in the functions. It was in what read them.
##
## So this layer boots the real scene, sinks a real shaft with a real pickaxe through the real mining
## path, and then asks the SHIPPED code what it believes:
##
##   THE HINT CAN FIRE.     `Hints.DEPTH_HINT_ID` fires at DEPTH_HINT_ROWS, "rows below the local surface
##                          that make the climb a real trip". Fed from `surface_row` the number it saw was
##                          about -1 however far down you went, so the one hint about climbing out of your
##                          own hole was unreachable by digging a hole. It must latch down here.
##   THE BEDS CROSSFADE.    Wind belongs to the sky and cave-air to the earth. Fed the same -1 they sat at
##                          full surface wind with the cave bed silent at the bottom of a shaft — the bed
##                          whose whole job is to sell descent was loudest exactly where descent happened.
##
## AND THE COUNTERFACTUAL IS ASSERTED, which is the half that keeps this from going quietly vacuous. A
## layer that only checks the new path passes just as well on a world where nothing was ever wrong — it
## would have passed before the fix if the shaft had happened to be shallow, or if the body had stopped
## short, or if some later change made the fixture never reach depth at all. So it also measures what the
## OLD expression would have returned right here, and requires it to be wrong. If that assertion ever
## stops holding, this layer is no longer standing where the bug was and its green means nothing.
##
##   godot --headless --path . --script res://tools/check_depth_reads.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const SETTLE: int = 30

## Rows below the column's ground the shaft is sunk. DEPTH_HINT_ROWS is 10 and the ambience cave bed is
## full at 10, so this clears both with room. It is deliberately NOT the boundary depth — the unit test
## owns the boundary (an eleven-row shaft floors inside the legal surface band, which is where the old
## band guard's excuse still holds). Here the fixture wants slack, because an agent that stops one row
## short of a threshold produces a red that is about the agent.
const SHAFT: int = 14

## Physics frames to let `Sfx.set_ambience` arrive. Both beds move at `delta * 0.6` per frame, so a full
## 1 -> 0 traverse needs ~1.7s ≈ 100 frames. This is that with margin; the beds are smoothed on purpose
## (a bed that snaps reads as a bug) and a fixture that reads them early is measuring the smoothing.
const CONVERGE: int = 150

## How deep the fixture must get before its readings mean anything. Above DEPTH_HINT_ROWS by a margin, so
## a body that stops short FAILS THIS LAYER rather than quietly asserting nothing.
const DEPTH_MIN: int = 12


func _initialize() -> void:
	print("== does the running game know how deep you are ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_depth_reads", "the shipped consumers read the ground, not the floor of your shaft")


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame

	var sim: FactorySim = main.sim
	var col: int = main._body_cell().x
	var ground: int = HeightmapWorldGen.ground_row(col)

	# THE PRECONDITION THE WHOLE DEFECT NEEDS. Before anybody digs, the two authorities agree — which is
	# exactly how the wrong one came to be adopted everywhere. If they disagree up here the spawn column
	# is not what this fixture thinks it is (a rift, a cave mouth) and every reading below is off a
	# different world than the one being described.
	_check(sim.surface_row(col) == ground,
		"before the dig both authorities agree on the spawn column (surface_row=%d, ground_row=%d)"
			% [sim.surface_row(col), ground])

	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var sank: bool = await agent.dig_down_to(Vector2i(col, ground + SHAFT), 2400, true)
	_check(sank, "the shaft was actually sunk (the agent reports arrival, not just an open target)")
	for _i: int in CONVERGE:
		await physics_frame

	# WHERE THE BODY ACTUALLY IS, measured rather than assumed. `dig_down_to` can decline to dig and a
	# fixture that reads its own intentions instead of the world is how a layer grades daylight as a delve.
	var body: Vector2i = main._body_cell()
	var depth: int = body.y - HeightmapWorldGen.ground_row(body.x)
	_check(depth >= DEPTH_MIN,
		"the body is %d rows below its column's ground (needs >= %d for the readings to mean anything)"
			% [depth, DEPTH_MIN])

	# THE COUNTERFACTUAL. What the reverted expression would compute standing right here. If this is not
	# below the hint threshold then the fixture is not standing where the bug was, and everything that
	# follows is green for the wrong reason.
	var was: int = body.y - sim.surface_row(body.x)
	_check(was < Hints.DEPTH_HINT_ROWS,
		("standing here, the OLD expression reads %d — still under the %d-row threshold %d rows down. "
			+ "This is the defect, and the assertions below are only meaningful while it holds")
			% [was, Hints.DEPTH_HINT_ROWS, depth])

	# --- and now the two shipped consumers, in the running game ---
	_check(main._hints._done.has(Hints.DEPTH_HINT_ID),
		"the depth hint latched %d rows down — the climb out of your own shaft is teachable" % depth)

	var wind: float = main._sfx._wind_level
	var cave: float = main._sfx._cave_level
	_check(wind <= 0.1, "the surface wind has died at the bottom of the shaft (wind=%.2f)" % wind)
	_check(cave >= 0.8, "the cave bed has arrived at the bottom of the shaft (cave=%.2f)" % cave)

	main.queue_free()
	await physics_frame
