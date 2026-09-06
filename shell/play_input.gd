class_name PlayInput
extends RefCounted

## THE PLAYER'S HANDS, READ ONCE A TICK (A' step 6q, D0380). Turns what is pressed into the body's
## `InputFrame` (with the edge latches a hold must not repeat through -- D0188's dig edge, applied to jump
## and the grapple too) and the one-shot verbs into `Command`s. Takes its "is this action down" as a
## Callable so a test can pose a hand without hardware, and the shell hands it `Controls.pressed`, which
## goes through the deafness switch and the posable pointer.

const NONE: Vector2i = Vector2i(-1, -1)

var _was_jump: bool = false
var _was_dig: bool = false
var _was_grapple: bool = false
var _was_verb: Dictionary = {}   ## action -> held last tick, for the one-shot verbs
var _was_digit: int = -1         ## the hotbar digit held last tick, so a held key selects once


## The body's frame: movement, jump with its edge, the climb axis, the grapple edge, mining held, the aim.
## `pointer_world` is the pointer in world pixels; `in_bounds(cell)` says whether the aimed terrain cell is
## a real one, else the frame has no aim rather than clamping to the rim.
func read(pressed: Callable, pointer_world: Vector2, cell_px: int, in_bounds: Callable) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	var left: bool = bool(pressed.call(Controls.LEFT))
	var right: bool = bool(pressed.call(Controls.RIGHT))
	f.move_dir = (-1 if left else 0) + (1 if right else 0)
	var jump: bool = bool(pressed.call(Controls.JUMP))
	f.jump_held = jump
	f.jump_pressed = jump and not _was_jump
	_was_jump = jump
	var up: bool = bool(pressed.call(Controls.CLIMB_UP))
	var down: bool = bool(pressed.call(Controls.CLIMB_DOWN))
	# `InputFrame.climb_dir` is +1 UP (the contract in `sim/body/input_frame.gd`; `Grapple.reel` and
	# `BodyMedium` both read it that way). This line had the sign flipped until 2026-09-05: W paid the line
	# out and S reeled it in, so "reel in to climb" did nothing on a slack line and the director sat anchored
	# at the bottom of a rift with a hint telling them the key that could not work (D0396).
	f.climb_dir = (1 if up else 0) + (-1 if down else 0)
	f.mantle_hold = up and f.move_dir != 0
	var grapple: bool = bool(pressed.call(Controls.GRAPPLE))
	f.grapple_pressed = grapple and not _was_grapple
	_was_grapple = grapple
	f.dig_pressed = false
	_was_dig = false
	f.mine_held = bool(pressed.call(Controls.MINE))
	var cell := Vector2i(floori(pointer_world.x / float(cell_px)), floori(pointer_world.y / float(cell_px)))
	f.aim_col = cell.x
	f.aim_row = cell.y
	f.has_aim = bool(in_bounds.call(cell))
	return f


## The one-shot verbs this tick, as commands, each on its press edge: build or pick up at the aimed metre,
## drop, configure, link a winch, clear the plan, and a hotbar digit. And, every tick while `auto_pickup`
## holds, COLLECT: legacy ran `_collect_ground_under_player()` from its main loop every frame with no key
## (`legacy/scenes/main.gd:677`, guarded by `Settings.auto_pickup`); this hand never issued the verb at all,
## so nothing a forge made could be picked up (D0409, the new-player review's second break). Walking over a
## pile is the pickup; the seat passes the setting in so the hand stays a function of its arguments.
func verbs(pressed: Callable, digit_down: Callable, aim_logic: Vector2i, auto_pickup: bool) -> Array[Command]:
	var out: Array[Command] = []
	if auto_pickup:
		out.append(Command.collect())
	if _edge(pressed, Controls.BUILD) and aim_logic != NONE:
		out.append(Command.build(aim_logic))
	if _edge(pressed, Controls.DROP):
		out.append(Command.drop())
	if _edge(pressed, Controls.CONFIGURE) and aim_logic != NONE:
		out.append(Command.configure(aim_logic))
	if _edge(pressed, Controls.LINK) and aim_logic != NONE:
		out.append(Command.link_winch(aim_logic))
	if _edge(pressed, Controls.CLEAR_PLAN):
		out.append(Command.clear_plan())
	var digit: int = -1
	for i: int in 9:
		if bool(digit_down.call(i)):
			digit = i
			break
	if digit >= 0 and digit != _was_digit:
		out.append(Command.select(digit))
	_was_digit = digit
	return out


## A press edge on one action: true on the tick it went down, false while it stays down.
func _edge(pressed: Callable, action: StringName) -> bool:
	var now: bool = bool(pressed.call(action))
	var was: bool = bool(_was_verb.get(action, false))
	_was_verb[action] = now
	return now and not was


## The HUD keys, on their edges: the settings page, the map, the save. Kept apart from `verbs` because
## none of them is a command to the sim.
func hud_keys(pressed: Callable) -> Dictionary:
	return {"settings": _edge(pressed, Controls.SETTINGS), "map": _edge(pressed, Controls.MAP), "save": _edge(pressed, Controls.SAVE)}


## The aimed logic cell from a frame's terrain aim, or NONE.
static func aim_logic_of(f: InputFrame) -> Vector2i:
	if f == null or not f.has_aim:
		return NONE
	return AimPlanes.logic_of(Vector2i(f.aim_col, f.aim_row))
