extends "res://tools/check_base.gd"

## A CAPTURE MUST PHOTOGRAPH THE FIXTURE, NOT THE KEYBOARD.
##
## `capture_moments._deafen()` cleared `_input`, `_unhandled_input` and `_unhandled_key_input` and was
## believed to have taken the hardware away. It had not. Those three are the CALLBACK path; POLLING is a
## separate mechanism that reads the driver's live state every physics frame and does not care whether a
## node is set to process input. `player.gd` polls the move axis, the climb axis and jump; `main.gd` polls
## MINE. A capture takes seconds. So a hand resting on W, or a mouse button left down, could walk, climb or
## MINE the miner through the shot — and `_contamination()` could not tell, because it inspected modal
## state and a callback flag and polling is neither of those.
##
## Every gameplay poll now goes through `Controls.axis()` / `Controls.pressed()`, gated on one static
## `Controls.deaf`, and this layer holds the three things that have to be true about it:
##
##   THE INJECTION IS REAL.  A pressed action must actually reach the game when the game is listening. This
##                           is the control, and without it every assertion below passes on a fixture where
##                           nothing was ever pressed — a test that presses no keys proves deafness
##                           perfectly.
##   DEAFNESS TAKES.         With the same action still held, the player must not move.
##   PLAYERS ARE NOT DEAF.   The default is off. A flag that silences the game shipping as ON would be a
##                           far worse bug than the one it fixes.
##
## Run: godot --headless --path . --script res://tools/check_input_deafness.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 8

func _initialize() -> void:
	print("== a capture photographs the fixture, not the keyboard ==")
	await _run()
	if _failures == 0:
		print("check_input_deafness: PASS — held keys reach a live game and cannot reach a deafened one")
		quit(0)
	else:
		printerr("check_input_deafness: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	# The shipped default, read before anything here touches it.
	_check(not Controls.deaf, "a real game is NOT deaf — the default is off, so players keep their hands")

	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var player: Player = main._player
	_check(player != null and player.auto_input,
		"the player is polling live input at all (auto_input) — else deafening it proves nothing")
	if player == null:
		return

	# --- THE CONTROL: a held action must reach a listening game ---
	Controls.deaf = false
	Input.action_press(Controls.RIGHT)
	for _i: int in 4:
		await physics_frame
	var live: float = player.input_dir
	_check(live > 0.5,
		"a held RIGHT reaches a listening game (input_dir %.2f) — the control this layer rests on" % live)
	_check(Controls.pressed(Controls.MINE) == false and Controls.pressed(Controls.RIGHT),
		"...and the poll wrapper reports exactly what is held, nothing more")

	# --- DEAFNESS: the same key, still down, no longer moves anything ---
	Controls.deaf = true
	for _i: int in 4:
		await physics_frame
	var deafened: float = player.input_dir
	_check(is_zero_approx(deafened),
		"...and with the key STILL HELD, a deafened game does not move (input_dir %.2f)" % deafened)
	_check(not Controls.pressed(Controls.RIGHT) and is_zero_approx(Controls.axis(Controls.LEFT, Controls.RIGHT)),
		"...the wrapper reports dead centre and nothing pressed, whatever the hardware says")

	# --- and it is reversible: deafness is a capture's business, not a permanent state ---
	Controls.deaf = false
	for _i: int in 4:
		await physics_frame
	_check(player.input_dir > 0.5,
		"...and hearing comes back when the capture is over (input_dir %.2f)" % player.input_dir)

	Input.action_release(Controls.RIGHT)
	Controls.deaf = false
	main.queue_free()
	await physics_frame
