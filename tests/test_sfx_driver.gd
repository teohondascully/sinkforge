extends "res://tests/test_base.gd"

## `view/audio/sfx.gd` — THE DRIVER, as distinct from the bank it plays (D0303).
##
## `tests/test_sfx_bank.gd` asserts the SOUNDS are right: real signal, the stated length, tonal where they
## should be tonal, identical from the same seed. It says nothing about whether anything ever plays one.
## That gap is the exact shape `legacy/tools/check_pump.gd` records and calls the lesson that generalises
## past audio: *"every generator, every stream and the whole `set_line` driver shipped and went green in
## check_voice, which called `set_line` by hand — while the controller never called it once."*
##
## So this suite is about `note_frame`'s five branches and nothing else. Its four questions:
##
##   IT FIRES WHEN IT SHOULD.    A charging blow into hollow rock rings; a breach cracks.
##   IT IS SILENT WHEN IT SHOULD BE. Not swinging, not charging, or under the threshold — nothing.
##   IT IS AN EDGE, NOT A LEVEL. The ring fires once per BLOW. `mining_swing` is documented as an edge
##                               (D0279) and this asserts the driver actually depends on it: a driver that
##                               read a level would ring sixty times a second and every other assertion
##                               here would still pass.
##   THE ACTUATOR ACTUALLY MOVES. `play` reaching a real pooled player, not just returning true.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_sfx_driver.gd

const CELL_PX: int = 4
const CHARGING := Vector2i(7, 40)


func _initialize() -> void:
	_test_a_hollow_blow_rings_and_a_solid_one_does_not()
	_test_the_breach_outranks_everything_and_fires_on_its_own_tick()
	_test_it_is_silent_on_every_frame_that_is_not_a_blow()
	_test_the_ring_is_an_edge_so_a_held_charge_rings_once_per_blow()
	_test_the_voice_mapping_moves_the_whole_way_and_stays_in_its_stops()
	await _test_the_pool_is_built_and_the_actuator_moves()
	await _test_play_refuses_rather_than_lying_when_it_cannot_play()
	_finish("sfx_driver")


## An `Sfx` with its pool built and GENUINELY INSIDE THE TREE.
##
## The `await` is the whole point and is not ceremony: in `_initialize` the SceneTree's own root is not
## yet inside the tree, so `get_root().add_child(x)` leaves `x.is_inside_tree()` FALSE and every
## `AudioStreamPlayer2D.play()` fails with an engine-level error that never touches the exit code. One
## processed frame later the root is in the tree and so is everything under it. Every `extends SceneTree`
## suite that parents a node in `_initialize` has this property, whether or not it depends on it.
func _driver() -> Sfx:
	var sfx: Sfx = Sfx.new()
	get_root().add_child(sfx)
	await process_frame
	sfx.setup()
	return sfx


## One observation posed directly. The driver reads six fields and nothing else, so a whole world would
## add confounds without adding coverage — and posing the fields is the only way to reach the branch
## combinations a real playthrough visits rarely.
func _frame(swing: bool, charging: bool, hollow: int, breach: bool) -> Frame:
	var obs: Interface.Observation = Interface.Observation.new()
	obs.cell_px = CELL_PX
	obs.mining_swing = swing
	obs.mining_is_charging = charging
	obs.mining_hollow = hollow
	obs.mining_breach = breach
	obs.mining_charging_cell = CHARGING
	var f: Frame = Frame.new()
	f.obs = obs
	return f


## True when this frame should make a sound. The pure half -- no device, no tree, no pool.
func _fires(frame: Frame) -> bool:
	return not Sfx.voice_for_frame(frame).is_empty()


func _test_the_pool_is_built_and_the_actuator_moves() -> void:
	var sfx: Sfx = await _driver()
	var players: int = 0
	for child: Node in sfx.get_children():
		if child is AudioStreamPlayer2D:
			players += 1
	_check(players == Sfx.VOICES, "setup built the whole pool (%d of %d)" % [players, Sfx.VOICES])
	# The actuator, reached directly: a real stream on a real player at a real position. Without this the
	# branch assertions below could all pass against a `play` that returns true and does nothing.
	var played: bool = sfx.play(&"hollow", Vector2(12.0, 34.0), 1.0, -12.0)
	_check(played, "play() reports it took a voice")
	var loaded: int = 0
	for child: Node in sfx.get_children():
		var p := child as AudioStreamPlayer2D
		if p != null and p.stream != null and p.position == Vector2(12.0, 34.0):
			loaded += 1
	_check(loaded == 1, "...and exactly one pooled player carries the stream and the position (%d)" % loaded)
	_check(not sfx.play(&"no_such_voice", Vector2.ZERO, 1.0, 0.0),
		"an unknown voice is refused rather than played silently")


func _test_a_hollow_blow_rings_and_a_solid_one_does_not() -> void:
	_check(_fires(_frame(true, true, Interface.HOLLOW_FULL, false)),
		"a blow into fully hollow rock rings")
	_check(_fires(_frame(true, true, Interface.HOLLOW_RING, false)),
		"...and so does one exactly AT the threshold, which is the boundary the constant names")
	_check(not _fires(_frame(true, true, Interface.HOLLOW_RING - 1, false)),
		"...and one just under it does not -- the threshold is where it says it is")
	_check(not _fires(_frame(true, true, 0, false)),
		"a blow into solid rock is silent")


## The breach is checked BEFORE the swing gate, so it fires on the tick the wall opens whether or not that
## tick also carried a blow. Asserted in both directions, because "it happens to be first in the function"
## is not the same claim as "it outranks the others".
func _test_the_breach_outranks_everything_and_fires_on_its_own_tick() -> void:
	_check(_fires(_frame(false, false, 0, true)),
		"a breach fires with no swing, no charge and no hollow reading at all")
	_check(_fires(_frame(true, true, Interface.HOLLOW_FULL, true)),
		"...and also on a tick that would otherwise have rung")


func _test_it_is_silent_on_every_frame_that_is_not_a_blow() -> void:
	_check(not _fires(null), "a null frame says nothing")
	_check(not _fires(Frame.new()), "a frame with no observation says nothing")
	var no_cell: Frame = _frame(true, true, Interface.HOLLOW_FULL, false)
	no_cell.obs.cell_px = 0
	_check(not _fires(no_cell), "an observation with no cell size says nothing")
	_check(not _fires(_frame(false, true, Interface.HOLLOW_FULL, false)),
		"CHARGING but not on the swing tick is silent -- this is the between-blows case")
	_check(not _fires(_frame(true, false, Interface.HOLLOW_FULL, false)),
		"swinging but not charging is silent")


## THE ASSERTION THAT WOULD CATCH THE EDGE BECOMING A LEVEL. A charge is many ticks long and exactly one
## of them is the blow (D0279). Sixty rings a second is not a louder version of the right behaviour, it is
## a different game — and every other assertion in this file passes either way, because each of them poses
## a single frame.
func _test_the_ring_is_an_edge_so_a_held_charge_rings_once_per_blow() -> void:
	var ticks: int = 40
	var rang: int = 0
	for i: int in ticks:
		# One blow lands in the middle of a held charge; every other tick is charging and silent.
		var is_blow: bool = i == ticks / 2
		if _fires(_frame(is_blow, true, Interface.HOLLOW_FULL, false)):
			rang += 1
	print("  [OBSERVED] %d ring(s) over %d charging ticks carrying 1 blow" % [rang, ticks])
	_check(rang == 1,
		"a held charge with one blow in it rings exactly ONCE (%d over %d ticks) -- a driver reading a "
		% [rang, ticks] + "level rather than the edge would ring %d times and pass every other test here"
		% ticks)


## The mapping is static and returns data precisely so it is assertable without an audio device. Both
## ENDS and the DIRECTION, because a mapping that moved the wrong way would still span the same range.
func _test_the_voice_mapping_moves_the_whole_way_and_stays_in_its_stops() -> void:
	var solid: Dictionary = Sfx.voice_for_hollow(0, Interface.HOLLOW_FULL)
	var hollow: Dictionary = Sfx.voice_for_hollow(Interface.HOLLOW_FULL, Interface.HOLLOW_FULL)
	print("  [OBSERVED] solid pitch %.3f db %.1f  ->  hollow pitch %.3f db %.1f"
		% [solid["pitch"], solid["db"], hollow["pitch"], hollow["db"]])
	_check(float(hollow["db"]) > float(solid["db"]),
		"hollower rock is LOUDER (%.1f -> %.1f dB)" % [solid["db"], hollow["db"]])
	_check(float(hollow["pitch"]) < float(solid["pitch"]),
		"...and LOWER (%.3f -> %.3f) -- a bigger cavity rings deeper"
		% [solid["pitch"], hollow["pitch"]])
	# Over-range inputs must clamp rather than run off: `mining_hollow` is a sim integer and a future
	# change to `HOLLOW_FULL` must not put the pitch somewhere a player has never heard.
	var over: Dictionary = Sfx.voice_for_hollow(Interface.HOLLOW_FULL * 4, Interface.HOLLOW_FULL)
	_check(is_equal_approx(float(over["pitch"]), float(hollow["pitch"]))
			and is_equal_approx(float(over["db"]), float(hollow["db"])),
		"a reading past full clamps to the full-hollow voice rather than continuing")
	_check(float(solid["pitch"]) <= Sfx.PITCH_MAX and float(hollow["pitch"]) >= Sfx.PITCH_MIN,
		"both ends sit inside the stated pitch stops")
	# A zero `full` would divide by zero; the mapping guards it with maxi(1, ...) and this is that guard.
	var degenerate: Dictionary = Sfx.voice_for_hollow(500, 0)
	_check(degenerate.has("pitch") and degenerate.has("db"),
		"a zero denominator returns a voice rather than dividing by zero")


## The honest-refusal half, and the defect it was written for. `AudioStreamPlayer2D.play()` needs the node
## INSIDE the tree; outside it, the engine prints an error and plays nothing — and an engine error never
## changes an exit code, so `play`'s return value was the only signal there was. It returned `true`.
##
## A pool built before the tree is running is exactly the state every `extends SceneTree` suite is in
## during `_initialize`, so this is not a contrived case; it is the case that produced four engine errors
## under a line reading ALL PASS.
func _test_play_refuses_rather_than_lying_when_it_cannot_play() -> void:
	var detached: Sfx = Sfx.new()
	detached.setup()   ## a full pool, never parented — every player outside the tree
	_check(not detached.play(&"hollow", Vector2.ZERO, 1.0, -12.0),
		"play() REFUSES when its player is not inside the tree, rather than reporting a playback that "
		+ "the engine declined")
	# ...and the same driver, once genuinely in the tree, plays. Both directions, or "always false" passes.
	get_root().add_child(detached)
	await process_frame
	_check(detached.play(&"hollow", Vector2.ZERO, 1.0, -12.0),
		"...and the SAME driver plays once it is in the tree, so the guard is not simply always-false")
	detached.queue_free()
