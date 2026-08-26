class_name HostileChamber
extends RefCounted

## The fixed hostile-geometry chamber `docs/ARCHITECTURE.md` §9's acceptance suite runs against.
## `docs/DECISIONS_LEDGER.md` D0036 has the full layout reasoning and the "verified present" check for
## every required feature. Column ranges below are the addresses that check reads, and that the
## acceptance driver's scripted route is built against -- keep them in sync if the layout changes.
##
## All terrain columns; `FLOOR_ROW` is where the spawn platform sits. One logic tile (`Body.LOGIC_TILE_PX`,
## 16px) is 4 terrain columns -- section widths below are stated in both for readability.

const FLOOR_ROW: int = 20
const CELL: int = Heightfield.TERRAIN_CELL_PX

## Section boundaries (terrain-column indices), in traverse order. Each is the FIRST column of its
## section; the previous section's END is implicit (the next section's START minus one).
const SPAWN_START: int = 0
const PIT_START: int = 16          ## 1 tile (4 cols) wide, no floor at all
const PIT_END: int = 20
const POST_PIT_START: int = 20     ## same height as spawn -- a pure gap-jump, not also a height change
## The pit jump's own natural landing distance, measured on a flat floor with the real ARCHITECTURE §9
## constants (JUMP_VELOCITY/GRAVITY/APEX_FLOAT), not assumed -- it lands around column 46, ~30 columns
## past the jump, because APEX_FLOAT's floaty hangtime carries it far past what the ORIGINAL, much
## shorter POST_PIT-to-LEDGE runway (this constant's predecessor put LEDGE_START at 36) assumed. With
## that runway, the jump sailed clean over the ledge -- and the platform and rubble past it -- landing for
## the first time deep in the rubble section with the ledge's own step-up never exercised at all. Moving
## LEDGE_START (and every section after it) out by the same margin gives the jump room to land and the
## body room to walk a settled, grounded approach into the ledge, rather than clip it mid-flight.
const POST_PIT_RUNWAY_COLS: int = 24
## A single solid cell in the pit jump's own rising arc (docs/DECISIONS_LEDGER.md D0039 has the
## trajectory math this is placed against): first contact is an EXIT-side graze -- the body's box has
## already flown past this column by the time its rising top edge reaches this row, so only a sliver of
## the box's trailing edge still overlaps it. That shape is what `CORNER_NUDGE_PX` can actually resolve
## (a forward nudge shrinks a trailing graze); a leading-edge graze, or a full-width overhang the body is
## still walking INTO, grows under the same forward nudge instead of clearing -- corner correction cannot
## rescue either, no matter how tight the margin. `_place_ceiling_corner`, this constant's predecessor,
## was exactly that unrescuable shape (a full-corridor-width overhang over the walking path); it never
## verified traversal, only presence, which is why the acceptance suite -- not the presence check -- is
## what caught it.
const JUMP_CORNER_COL: int = 15
const JUMP_CORNER_ROW: int = 2
const LEDGE_START: int = 36 + POST_PIT_RUNWAY_COLS        ## hard 1-tile (16px) step UP -- auto step-up
const PLATEAU_START: int = 40 + POST_PIT_RUNWAY_COLS
const RUBBLE_START: int = 56 + POST_PIT_RUNWAY_COLS       ## jagged, actually-dug surface -- 1-3px sub-pixel rubble slopes
const RUBBLE_END: int = 64 + POST_PIT_RUNWAY_COLS
const MACHINE_CLUSTER_START: int = 64 + POST_PIT_RUNWAY_COLS
const MACHINE_CLUSTER_END: int = 68 + POST_PIT_RUNWAY_COLS
const MANTLE_START: int = 72 + POST_PIT_RUNWAY_COLS       ## 2-tile (32px) step -- too tall to auto-step, needs a mantle hold
const MANTLE_END: int = 80 + POST_PIT_RUNWAY_COLS
const SHAFT_START: int = 80 + POST_PIT_RUNWAY_COLS        ## outer bound of the shaft SECTION -- includes the confining walls
const SHAFT_WALL_COLS: int = 6     ## either side of the opening, so the walls have a real width rather
## The opening's width. A 3-logic-tile (12-column) shaft, "roughly 3 cells" per the original chamber
## spec, is narrower than the body's OWN natural rightward drift over the full fall under continuous
## forward input -- measured (with the walls removed, not guessed) at 77.5px total, against 12 columns *
## 4px - WIDTH_PX(16px) = 32px of lateral room. A first attempt at 16 columns (48px of room) still fell
## well short for the same reason: 48 < 77.5, it just moved WHERE in the fall contact happened, not
## whether it happened. A shaft this deep needs the FULL measured drift of room, not a guess at it, or
## it isn't "narrow", it's "too narrow to fall through cleanly" -- 28 columns (96px of room) clears the
## measured 77.5px with margin.
const SHAFT_OPEN_COLS: int = 28
const SHAFT_END: int = SHAFT_START + SHAFT_WALL_COLS * 2 + SHAFT_OPEN_COLS
const SHAFT_OPEN_START: int = SHAFT_START + SHAFT_WALL_COLS  ## the actual open (fall-through) columns,
const SHAFT_OPEN_END: int = SHAFT_OPEN_START + SHAFT_OPEN_COLS              ## not the section's outer bound
const SHAFT_FLOOR_ROW: int = 32
const END_START: int = SHAFT_END
const END_COL: int = SHAFT_END + 16

## Not part of the scripted traversal (`ScriptedTraverse` stops once `col >= END_START`, well before
## here) -- a standalone fixture proving the documented multi-level-floor limitation behaves
## predictably, not proving it's solved (`docs/adr/0005-heightfield-local-window.md`, D0043). A real
## tunnel (rock above AND below, unlike every other section here, which is open-topped) with one
## overhang: the tunnel's own floor continues as a shelf over a lower, separately-floored pocket,
## connected back to the tunnel by a gap in the shelf -- reachable from the side, not a sealed bubble,
## matching the shape the measured 0.85%/12% figures describe.
const CAVE_START: int = END_COL
const CAVE_FLOOR_ROW: int = 20
const CAVE_CEILING_CLEARANCE_ROWS: int = 15  ## > Body.HEIGHT_PX / CELL (10) -- a normally walkable tunnel
const CAVE_TUNNEL_COLS: int = 8
const CAVE_OVERHANG_COLS: int = 4    ## the shelf: floor-height material with nothing below it in reach
const CAVE_GAP_COLS: int = 4         ## no shelf here -- the tunnel level drops straight to the lower floor
const CAVE_OVERHANG_START: int = CAVE_START + CAVE_TUNNEL_COLS
const CAVE_GAP_START: int = CAVE_OVERHANG_START + CAVE_OVERHANG_COLS
const CAVE_END: int = CAVE_GAP_START + CAVE_GAP_COLS
## The shelf is a `_fill_flat` slab like any other floor -- 6 rows thick, [CAVE_FLOOR_ROW,
## CAVE_FLOOR_ROW + 6). Open air needs a full body-height (10 rows) below that before the lower
## floor, or the lower pocket isn't genuinely walkable.
const CAVE_LOWER_FLOOR_ROW: int = CAVE_FLOOR_ROW + 6 + 10


## Builds the chamber deterministically from a fixed seed -- the fresh-dig section is carved by an
## actual excavation walk (`_carve_rubble`), not authored to look jagged, so its irregularity is a real
## byproduct of digging rather than hand-placed geometry.
static func build() -> TileGrid:
	var grid: TileGrid = TileGrid.new(CAVE_END + 4, maxi(SHAFT_FLOOR_ROW + 10, CAVE_LOWER_FLOOR_ROW + 10), 20260825)
	_fill_flat(grid, SPAWN_START, PIT_START, FLOOR_ROW)
	_fill_flat(grid, POST_PIT_START, LEDGE_START, FLOOR_ROW)
	_place_jump_corner(grid, JUMP_CORNER_COL, JUMP_CORNER_ROW)
	_fill_flat(grid, LEDGE_START, PLATEAU_START, FLOOR_ROW - 4)  ## 1 tile (16px) higher
	_fill_flat(grid, PLATEAU_START, RUBBLE_START, FLOOR_ROW - 4)
	_carve_rubble(grid, RUBBLE_START, RUBBLE_END, FLOOR_ROW - 4)
	_fill_flat(grid, MACHINE_CLUSTER_START, MANTLE_START, FLOOR_ROW - 4)
	_place_machine_cluster(grid, MACHINE_CLUSTER_START, FLOOR_ROW - 4)
	_fill_flat(grid, MANTLE_START, SHAFT_START, FLOOR_ROW - 4 - Body.MANTLE_PX / CELL)  ## 2 tiles higher
	_place_shaft_walls(grid, SHAFT_START, SHAFT_END, FLOOR_ROW - 4 - Body.MANTLE_PX / CELL, SHAFT_FLOOR_ROW)
	_fill_flat(grid, SHAFT_END, END_COL, SHAFT_FLOOR_ROW)
	_place_cave_geometry(grid)
	return grid


static func _fill_flat(grid: TileGrid, from_col: int, to_col: int, top_row: int) -> void:
	for col: int in range(from_col, to_col):
		for row: int in range(top_row, top_row + 6):
			grid.set_material(Vector2i(col, row), &"hardrock")


## The fresh-dig section: a small seeded random walk that removes one cell at a time from the top of an
## otherwise-solid block, biased to move sideways more often than down, so the result is a real
## excavated surface -- uneven, but never opening a true pit inside its own span -- rather than terrain
## authored to resemble one. `docs/DECISIONS_LEDGER.md` D0036 has the "verified present" check.
static func _carve_rubble(grid: TileGrid, from_col: int, to_col: int, top_row: int) -> void:
	_fill_flat(grid, from_col, to_col, top_row - 4)
	var rng: SplitRng = SplitRng.new(20260825).split(&"hostile_chamber_rubble")
	var row: int = top_row
	for col: int in range(from_col, to_col):
		var roll: int = rng.next_u64() % 3
		if roll == 0 and row > top_row - 3:
			row -= 1  ## dig one cell deeper here than the neighbour to the left
		elif roll == 1 and row < top_row + 2:
			row += 1  ## leave one cell proud of the neighbour to the left
		for dig_row: int in range(top_row - 4, row):
			grid.excavate(Vector2i(col, dig_row))


## A small clump standing in for a machine footprint (`sim/machines` doesn't exist yet) -- protrudes
## one tile above the floor, off to the side of the walkable path rather than blocking it outright, so
## the designed route steps past it rather than through it.
static func _place_machine_cluster(grid: TileGrid, from_col: int, top_row: int) -> void:
	for col: int in range(from_col + 1, from_col + 3):
		grid.set_material(Vector2i(col, top_row - 1), &"hardrock")  ## one cell (4px) above the floor


## A single solid cell, high above the pit, that only the jump's rising arc ever reaches -- see
## `JUMP_CORNER_COL`'s own comment for why this specific (column, row) is a corner correction can
## actually resolve rather than an unrescuable full-width overhang.
static func _place_jump_corner(grid: TileGrid, col: int, row: int) -> void:
	grid.set_material(Vector2i(col, row), &"hardrock")


## A 3-logic-tile-wide (`SHAFT_OPEN_COLS` terrain cells) vertical shaft: solid walls either side (the
## `SHAFT_WALL_COLS`-wide margins between `from_col`/`to_col` and the open span), open in between,
## descending from `top_row` to `bottom_row`, with a floor at the bottom of the open span. The LEFT wall
## runs the full height including below the floor (nothing exits that way); the RIGHT wall stops a full
## `Body.HEIGHT_PX` above the floor -- the body needs its own full height of clearance to walk out
## standing up, not just an opening at foot level. Stopping it only at the floor's own top (this
## function's second version) left a corridor tall enough for the body's feet but not its head, which
## `_resolve_horizontal` reads as a wall the moment the body is close enough to stand on the floor at all;
## stopping it at the floor level exactly (the first version) sealed the shaft into a box with no way out.
static func _place_shaft_walls(grid: TileGrid, from_col: int, to_col: int, top_row: int, bottom_row: int) -> void:
	var right_wall_bottom: int = bottom_row - Body.HEIGHT_PX / CELL
	for row: int in range(top_row - 4, bottom_row + 4):
		for col: int in range(from_col, SHAFT_OPEN_START):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for row: int in range(top_row - 4, right_wall_bottom):
		for col: int in range(SHAFT_OPEN_END, to_col):
			grid.set_material(Vector2i(col, row), &"hardrock")
	# Floor spans the open span AND the space the right wall used to occupy below `bottom_row` -- without
	# that margin, stopping the right wall early (above) leaves a gap with no floor at all between the
	# shaft's own floor and `END_COL`'s floor, which starts at `to_col`.
	for row: int in range(bottom_row, bottom_row + 4):
		for col: int in range(SHAFT_OPEN_START, to_col):
			grid.set_material(Vector2i(col, row), &"hardrock")


## See the `CAVE_*` constants' own comments. Ceiling runs the whole section -- tunnel, overhang, and
## gap alike -- so it reads as one continuous enclosed tunnel throughout, not another open-topped
## chamber section with a roof bolted onto part of it.
static func _place_cave_geometry(grid: TileGrid) -> void:
	var ceiling_bottom: int = CAVE_FLOOR_ROW - CAVE_CEILING_CLEARANCE_ROWS
	for col: int in range(CAVE_START, CAVE_END):
		for row: int in range(ceiling_bottom - 4, ceiling_bottom):
			grid.set_material(Vector2i(col, row), &"hardrock")
	_fill_flat(grid, CAVE_START, CAVE_OVERHANG_START, CAVE_FLOOR_ROW)  # tunnel: plain floor
	_fill_flat(grid, CAVE_OVERHANG_START, CAVE_GAP_START, CAVE_FLOOR_ROW)  # the shelf itself
	_fill_flat(grid, CAVE_OVERHANG_START, CAVE_END, CAVE_LOWER_FLOOR_ROW)  # the real floor beneath it
	# CAVE_GAP_START..CAVE_END deliberately gets no shelf at CAVE_FLOOR_ROW -- this is where the
	# tunnel's main level drops through to the lower floor, the side-entry the lower pocket needs to
	# be reachable rather than a sealed bubble.
