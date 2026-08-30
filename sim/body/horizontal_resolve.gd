class_name HorizontalResolve
extends RefCounted

## `body.gd`'s own horizontal-axis collision resolver, extracted to mirror `vertical_resolve.gd`'s
## existing split (that file already holds the VERTICAL axis; this was the missing HORIZONTAL half,
## still inline in `body.gd` itself until now) -- a pure Extract Class, no logic reordered or changed,
## done specifically to give `sim/body/body.gd` size headroom back (it was at 399/400 lines,
## `check_size_limits.py`'s own `FILE_LIMIT`) before the `resolve_floor` diagnosis
## (docs/DECISIONS_LEDGER.md D0135) needs to instrument near it without fighting that gate at the same
## time. Every function here takes `body: Body` explicitly, exactly like `vertical_resolve.gd`'s own
## static functions already do -- GDScript's underscore convention is not enforced access control, so
## calling `body._left_x()`/`body._box_blocked(...)` from outside `Body` is the same pattern this
## project's own vertical resolver already relies on.


## Iterates every blocked cell the body's own box overlaps and resolves each one via `_resolve_cell` --
## the classification/step/mantle/depenetration logic itself lives there (originally extracted
## 2026-08-28, D0100, to bring this function's own cyclomatic complexity down from 24; still a pure
## Extract Method, now additionally moved out of `body.gd` itself, D0135).
static func resolve(body: Body, grid: TileGrid, input: InputFrame) -> void:
	var moving_right: bool = body.vel_x > 0
	var lo: Vector2i = Vector2i(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._top_y()))
	var hi: Vector2i = Vector2i(Body._px_to_cell(body._right_x() - 1), Body._px_to_cell(body._bottom_y() - 1))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			_resolve_cell(body, grid, input, moving_right, cx, cy)


## Ledge-vs-ceiling classifier: shallower in Y than in X, AND the blocking cell's centre is BELOW the
## body's centre, means the body is clipping the TOP of a block under it -- a ledge to land on, not a
## wall. The identical overlap shape with the cell ABOVE the body's centre is a ceiling clip, which is
## NOT exempted -- `legacy/scenes/player.gd`'s own fixed bug (docs/ARCHITECTURE.md §9's design lineage)
## was this classifier missing the second half of that comparison.
##
## D0100's own original extraction note, preserved: every `continue` in the original doubly-nested loop
## became a `return` here, behaviorally identical since this is called once per (cx, cy) with nothing
## after the call.
static func _resolve_cell(body: Body, grid: TileGrid, input: InputFrame, moving_right: bool, cx: int, cy: int) -> void:
	var cell := Vector2i(cx, cy)
	if not body._blocked(grid, cell):
		return
	var cell_left: int = cx * Body.CELL_PX * Fx.SCALE
	var cell_top: int = cy * Body.CELL_PX * Fx.SCALE
	var cell_right: int = cell_left + Body.CELL_PX * Fx.SCALE
	var cell_bottom: int = cell_top + Body.CELL_PX * Fx.SCALE
	var left: int = body._left_x(); var right: int = body._right_x()
	var top: int = body._top_y(); var bottom: int = body._bottom_y()
	if left >= cell_right or right <= cell_left or top >= cell_bottom or bottom <= cell_top:
		return
	var ov_x: int = mini(right, cell_right) - maxi(left, cell_left)
	var ov_y: int = mini(bottom, cell_bottom) - maxi(top, cell_top)
	if ov_x > ov_y and (cell_top + cell_bottom) / 2 > body.pos_y:
		return  # a ledge beneath the body -- the vertical resolve lands it, not a wall
	var lift: int = bottom - cell_top
	# D0059: a real ledge has more solid material continuing forward; an isolated single-cell
	# obstruction (HostileChamber.JUMP_CORNER) does not -- stepping/mantling onto one anyway
	# leaves nothing supporting most of the body's width, and `on_floor` reverts the same tick.
	var extends_forward: bool = body._blocked(grid, Vector2i(cx + (1 if moving_right else -1), cy))
	if _try_climb(body, grid, input, extends_forward, lift):
		return
	body.pos_x += (cell_left - right) if moving_right else (cell_right - left)
	body.depenetrated_this_tick = true
	body.vel_x = 0


## Attempts to climb over `lift`: step-up first (smaller, no input gate), then mantle (larger, requires
## `input.mantle_hold`), falling back to flagging `edge_caught_this_tick` if step-up's own conditions
## held but head clearance refused it. Extracted 2026-08-28 (D0100) from `body.gd`'s own
## `_resolve_horizontal_cell` -- returns true iff a climb succeeded (caller should stop, this cell is
## resolved), false otherwise (caller falls through to depenetration).
## D0209: the auto step-up is a WALKING affordance and only fires with the feet already on the ground.
## Without that gate it also fired in mid-air, which is a different move entirely: the body is translated
## up to a full `STEP_UP_PX` in ONE tick -- 16px at 60Hz is 960 px/s, 1.7x `MAX_FALL_PX_S` -- so jumping
## alongside a ledge snapped the body onto it instead of letting the jump carry it there. The director's
## own words, on a session where 12 of 17 step-ups happened while airborne: "it feels like I teleport on
## top of the high step instead of jumping straight up and needing to move right onto the platform."
##
## This is the reference implementation's rule, not a new one, and it is the SECOND precondition of
## `_try_step` that was left behind when the function itself was ported -- D0205 was the first (the
## `_stepped` gravity-skip). `legacy/scenes/player.gd` line 367 sets `_step_grounded = grounded` with the
## comment "let the horizontal resolve auto-step <=1-tile walls when grounded", and line 531 gates on it.
## **Porting a function is not porting its preconditions**, and this module has now paid for that twice.
##
## The MANTLE is deliberately NOT gated the same way: it already requires `input.mantle_hold`, so it is a
## thing the player asks for rather than something that happens to them, and climbing while airborne is
## the move. Gating the edge-catch report alongside the step-up matters too -- an airborne near-miss is
## not a ledge the body "should have been able to walk up", and counting it as one would report a feel
## failure that never happened.
static func _try_climb(body: Body, grid: TileGrid, input: InputFrame, extends_forward: bool, lift: int) -> bool:
	# COYOTE, not raw `on_floor`, and the difference is not cosmetic. `on_floor` is whatever the PREVIOUS
	# tick's vertical pass left, and `move_and_resolve` clears it on any tick with vertical movement, so a
	# body running over even slightly uneven ground reads airborne on scattered ticks and would skip a
	# step it is plainly walking into. Measured: with raw `on_floor` the 20,000-tick shaft replay produced
	# ZERO step-ups (down from 3), which is the scenario losing the path rather than the path behaving.
	#
	# `_coyote_ticks_left` is exactly "grounded within the last COYOTE_TICKS and has not jumped since" --
	# `_handle_jump` zeroes it on launch. So a deliberate jump still cannot auto-step, which is the whole
	# point of the gate, while a body that merely left the ground for a tick or two still can.
	var recently_grounded: bool = body.on_floor or body._coyote_ticks_left > 0
	var may_step: bool = (recently_grounded and extends_forward and body.vel_x != 0
		and lift <= Body.STEP_UP_PX * Fx.SCALE)
	if may_step and _try_step(body, grid, lift):
		body.stepped_up_this_tick = true
		return true
	# D0212: the mantle is gated the same way, and the reasoning that first exempted it was wrong. "It
	# requires `input.mantle_hold`, so the player asked for it" -- except `mantle_hold` is toward-and-UP,
	# and holding up while jumping is not a request to climb. Measured on the director's own session, all
	# three occurrences at the same cell (217,33): the body jumping UP past the movement course's perch
	# (`vel_y` -35, -140, -125) with its leading edge in the perch's column, yanked 17.4 / 26.8 / 24.7 px
	# in ONE tick -- up to 1605 px/s, nearly 3x terminal velocity. It bypassed the jump and made the
	# perch, which exists to demand a precise landing, free.
	#
	# There is no reference implementation for this one: `legacy/scenes/player.gd` has no mantle at all,
	# and `docs/ARCHITECTURE.md` §9 specifies it in one line ("2 tiles on toward-and-up hold") that says
	# nothing about grounding. So this is a judgment call rather than a port, made to match the sibling
	# mechanic: a climb is something the body does FROM THE GROUND. That is also what makes an instant
	# translation tolerable at all -- a 16px pop while walking reads as stepping onto a kerb, the same pop
	# mid-flight reads as a teleport, because in the air there was an expected trajectory to violate.
	if (recently_grounded and extends_forward and body.vel_x != 0
			and lift <= Body.MANTLE_PX * Fx.SCALE and input.mantle_hold
			and _try_step(body, grid, lift)):
		body.mantled_this_tick = true
		return true
	if may_step:
		body.edge_caught_this_tick = true  # should have been walkable; head clearance refused it
	return false


## Auto step-up (1 tile) and mantle (2 tiles): raise the body by `lift` if the space it would occupy at
## that height is clear. Both call this identically -- the only difference is which caller allows a
## larger `lift` and under what input condition, per docs/ARCHITECTURE.md §9.
## D0055: refuses a lift crossing row 0, BEFORE moving -- correcting after alone left the body
## oscillating forever (measured: 258 ticks); falls through to the normal stop path instead.
static func _try_step(body: Body, grid: TileGrid, lift: int) -> bool:
	if body._top_y() - lift < 0:
		return false
	if body._box_blocked(grid, body._left_x(), body._top_y() - lift, body._right_x(), body._bottom_y() - lift):
		return false
	body.pos_y -= lift
	body.on_floor = true
	body.floor_source_this_tick = &"try_step"
	body.vel_y = 0
	return true
