class_name ScriptedTraverse
extends RefCounted

## A reactive, deterministic "oracle" traversal policy driving a `Body` through `HostileChamber`: hold
## right, jump a few columns before the pit, hold mantle through the mantle section. Everything else
## (the ledge's auto step-up, the rubble, the machine cluster, the ceiling corner, falling through the
## shaft) needs no scripted input beyond holding right -- that is the acceptance suite's whole point:
## those mechanics have to work from continuous forward input alone, not from a bot compensating for
## them. Landmark-aware (reads `HostileChamber`'s own column constants) rather than a generic
## look-and-react heuristic, matching `docs/ARCHITECTURE.md` §5's "oracle" envelope (perfect
## information) rather than "constrained" -- this is a controller acceptance check, not a discoverability
## measurement. Deterministic given a fixed `Body`+`TileGrid`, so its own tick-by-tick output IS a
## recorded input log, `docs/ARCHITECTURE.md` §5's raw action level, not a throwaway test-only shim.

const JUMP_RUNWAY_COLS: int = 3  ## columns before the pit's edge the policy presses jump


static func next_input(body: Body, _grid: TileGrid) -> InputFrame:
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	input.jump_held = true
	var col: int = Body._px_to_cell(body.pos_x)
	if col >= HostileChamber.PIT_START - JUMP_RUNWAY_COLS and col < HostileChamber.PIT_START and body.on_floor:
		input.jump_pressed = true
	# The shaft is a pure vertical drop -- nothing about falling through it needs rightward progress, and
	# holding right while airborne there only drifts the body into whichever confining wall is downstream
	# of its entry point, generating wall contact the drop itself never asked for. Releasing it here isn't
	# compensating for a mechanic (the falling itself still needs no scripted help); it's not applying an
	# input the "hold right" baseline has no reason to apply in a section with no lateral objective.
	# `col` tracks the body's CENTRE, but its leading edge is `Body.WIDTH_PX / 2` (2 terrain cells) ahead of
	# it -- that edge reaches the mantle wall two columns before the centre's own column number does. One
	# more column of lead time on top of that covers the tick this same input is READ for: it reflects the
	# body's position at the START of the tick, one tick stale relative to the crossing itself, so a bare
	# 2-column margin still holds `mantle_hold` false for exactly the tick contact begins.
	var half_width_cols: int = (Body.WIDTH_PX / Heightfield.TERRAIN_CELL_PX) / 2
	if col >= HostileChamber.MANTLE_START - half_width_cols - 1 and col < HostileChamber.MANTLE_END:
		input.mantle_hold = true
	return input
