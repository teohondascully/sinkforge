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
const LEDGE_START: int = 36        ## hard 1-tile (16px) step UP -- auto step-up
const PLATEAU_START: int = 40
const RUBBLE_START: int = 56       ## jagged, actually-dug surface -- 1-3px sub-pixel rubble slopes
const RUBBLE_END: int = 64
const MACHINE_CLUSTER_START: int = 64
const MACHINE_CLUSTER_END: int = 68
const CEILING_CORNER_START: int = 68
const CEILING_CORNER_END: int = 72
const MANTLE_START: int = 72       ## 2-tile (32px) step -- too tall to auto-step, needs a mantle hold
const MANTLE_END: int = 80
const SHAFT_START: int = 80        ## outer bound of the shaft SECTION -- includes the confining walls
const SHAFT_WALL_COLS: int = 6     ## either side of the 3-tile (12-col) opening, so the walls have a
const SHAFT_OPEN_COLS: int = 12    ## real width rather than degenerating to zero when the section's
const SHAFT_END: int = SHAFT_START + SHAFT_WALL_COLS * 2 + SHAFT_OPEN_COLS  ## outer bound exactly matched the opening's own width
const SHAFT_OPEN_START: int = SHAFT_START + SHAFT_WALL_COLS  ## the actual open (fall-through) columns,
const SHAFT_OPEN_END: int = SHAFT_OPEN_START + SHAFT_OPEN_COLS              ## not the section's outer bound
const SHAFT_FLOOR_ROW: int = 32
const END_START: int = SHAFT_END
const END_COL: int = SHAFT_END + 16


## Builds the chamber deterministically from a fixed seed -- the fresh-dig section is carved by an
## actual excavation walk (`_carve_rubble`), not authored to look jagged, so its irregularity is a real
## byproduct of digging rather than hand-placed geometry.
static func build() -> TileGrid:
	var grid: TileGrid = TileGrid.new(END_COL + 4, SHAFT_FLOOR_ROW + 10, 20260825)
	_fill_flat(grid, SPAWN_START, PIT_START, FLOOR_ROW)
	_fill_flat(grid, POST_PIT_START, LEDGE_START, FLOOR_ROW)
	_fill_flat(grid, LEDGE_START, PLATEAU_START, FLOOR_ROW - 4)  ## 1 tile (16px) higher
	_fill_flat(grid, PLATEAU_START, RUBBLE_START, FLOOR_ROW - 4)
	_carve_rubble(grid, RUBBLE_START, RUBBLE_END, FLOOR_ROW - 4)
	_fill_flat(grid, MACHINE_CLUSTER_START, CEILING_CORNER_START, FLOOR_ROW - 4)
	_place_machine_cluster(grid, MACHINE_CLUSTER_START, FLOOR_ROW - 4)
	_fill_flat(grid, CEILING_CORNER_START, MANTLE_START, FLOOR_ROW - 4)
	_place_ceiling_corner(grid, CEILING_CORNER_START, FLOOR_ROW - 4)
	_fill_flat(grid, MANTLE_START, SHAFT_START, FLOOR_ROW - 4 - Body.MANTLE_PX / CELL)  ## 2 tiles higher
	_place_shaft_walls(grid, SHAFT_START, SHAFT_END, FLOOR_ROW - 4 - Body.MANTLE_PX / CELL, SHAFT_FLOOR_ROW)
	_fill_flat(grid, SHAFT_END, END_COL, SHAFT_FLOOR_ROW)
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


## A low overhang directly over the walkable path, deliberately a few px TOO tight to clear a full
## walk-through cleanly (`Body.HEIGHT_PX` minus a small margin, not plus one) -- a body entering or
## leaving its span partially overlaps the blocking column while the rest of its box has already
## cleared, exactly the "ceiling contact near a corner" case `CORNER_NUDGE_PX` exists to slip past.
static func _place_ceiling_corner(grid: TileGrid, from_col: int, top_row: int) -> void:
	var clearance_rows: int = (Body.HEIGHT_PX - 4) / CELL
	var overhang_bottom: int = top_row - clearance_rows
	# Only 3 of this section's 4 columns carry the overhang -- the 4th (this section's last) stays
	# clear, so a caller sampling "the column right before the next section" doesn't read the overhang
	# instead of the floor. A real design choice, not an accident: it also gives the body a moment of
	# full headroom right before the mantle step, matching how a real chamber would breathe between
	# hostile features rather than stacking them with zero transition.
	for col: int in range(from_col, from_col + 3):
		for row: int in range(overhang_bottom - 6, overhang_bottom):
			grid.set_material(Vector2i(col, row), &"hardrock")


## A 3-logic-tile-wide (`SHAFT_OPEN_COLS` terrain cells) vertical shaft: solid walls either side (the
## `SHAFT_WALL_COLS`-wide margins between `from_col`/`to_col` and the open span), open in between,
## descending from `top_row` to `bottom_row`, with a floor at the bottom of the open span.
static func _place_shaft_walls(grid: TileGrid, from_col: int, to_col: int, top_row: int, bottom_row: int) -> void:
	for row: int in range(top_row - 4, bottom_row + 4):
		for col: int in range(from_col, SHAFT_OPEN_START):
			grid.set_material(Vector2i(col, row), &"hardrock")
		for col: int in range(SHAFT_OPEN_END, to_col):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for row: int in range(bottom_row, bottom_row + 4):
		for col: int in range(SHAFT_OPEN_START, SHAFT_OPEN_END):
			grid.set_material(Vector2i(col, row), &"hardrock")
