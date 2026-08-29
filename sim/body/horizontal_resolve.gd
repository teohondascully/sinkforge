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
static func _try_climb(body: Body, grid: TileGrid, input: InputFrame, extends_forward: bool, lift: int) -> bool:
	if extends_forward and body.vel_x != 0 and lift <= Body.STEP_UP_PX * Fx.SCALE and _try_step(body, grid, lift):
		body.stepped_up_this_tick = true
		return true
	if (extends_forward and body.vel_x != 0 and lift <= Body.MANTLE_PX * Fx.SCALE and input.mantle_hold
			and _try_step(body, grid, lift)):
		body.mantled_this_tick = true
		return true
	if extends_forward and body.vel_x != 0 and lift <= Body.STEP_UP_PX * Fx.SCALE:
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
