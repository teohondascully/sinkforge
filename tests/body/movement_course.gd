class_name MovementCourse
extends RefCounted

## A SURFACE agility course, built to be played rather than measured -- the director's own ask: "how does
## the mid-air dir change feel for agile movement." Open sky above every section, so no jump is ever cut
## short by a ceiling, and a continuous catch floor under everything, so a missed jump is a fall and a
## walk back rather than a soft-lock. `HostileChamber` is the acceptance fixture and is shaped for
## `ScriptedTraverse`'s one known route; this is the opposite -- no required route, no scripted policy,
## no metric attached.
##
## EVERY DISTANCE HERE IS MEASURED, NOT CHOSEN. `tools/scratch/measure_agility.gd` ticks the real `Body`
## against a real `TileGrid` and reports what it can do; the closed form from the feel constants is wrong,
## because `APEX_FLOAT` cuts gravity near the top and the jump-cut ratio changes the arc. On 2026-08-30,
## at the constants in `sim/body/body.gd`:
##
##   standing jump   71.4 px high (17.9 cells, 1.79 body-heights), 0.87 s airborne, 0.15 s of it near apex
##   running jump    carries 132.5 px (33.1 cells, 8.3 body-widths)
##   widest gap      28 cells (112 px) cleared from a full-speed run
##   air reversal    vel_x crosses zero 14 ticks (0.23 s) after the stick flips, and reaches 60% of run
##                   speed the other way at 22 ticks (0.37 s) -- against 52 ticks of airtime, so a full
##                   reversal costs 42% of one jump. It overshoots 15.4 px (3.9 cells, ~one body width)
##                   past the flip point before coming back.
##   air control     11.25 px/s per tick, against 18.75 on the ground (AIR_CONTROL 3/5)
##
## Re-run that probe and update these if a feel constant moves. The gaps below are stated as fractions of
## the measured 28-cell maximum, so they stay meaningful under a re-tune even before the numbers are
## refreshed.

## The two measurements every dimension below is derived from, so a re-tune moves the course instead of
## silently changing what it asks. Both from `tools/scratch/measure_agility.gd`, rounded away from zero.
const MEASURED_APEX_PX: int = 72          ## 71.4 measured
const MEASURED_MAX_GAP_CELLS: int = 28    ## 112 px

## THE SKY IS A DERIVED QUANTITY, NOT A CHOICE, and getting it wrong is not theoretical: the first build
## of this course put the plateau at row 24 with 96px of air above it, and the body jumped clean out of
## the top of the world -- `_enforce_grid_bounds` clamping a head at y=-15.4px. A jump from the HIGHEST
## surface needs the apex PLUS the body's own height, because it is the head that leaves, not the feet.
## The suite's own first sky assertion made the identical mistake (`headroom > 71`), so the constant and
## the check agreed with each other and both were wrong -- which is why this is computed here and the
## test asserts against the same derivation rather than against a second typed number.
const PLATEAU_LIFT: int = 16              ## cells above the surface: STAIR_COUNT * STAIR_RISE
const SKY_ROWS: int = (MEASURED_APEX_PX + Body.HEIGHT_PX) / Heightfield.TERRAIN_CELL_PX + 4
const PLATEAU_ROW: int = SKY_ROWS         ## the highest solid thing on the course
const SURFACE_ROW: int = PLATEAU_ROW + PLATEAU_LIFT   ## the walking surface
const CATCH_ROW: int = SURFACE_ROW + 12   ## 12 cells under it -- a fall, but 12 < the 17.9-cell jump,
                                          ## so always recoverable without walking back to a ramp
const GRID_HEIGHT: int = CATCH_ROW + 8

## Section 1: enough flat ground to reach RUN_SPEED (measured: ~40 ticks of ground accel) before the
## first commitment, so the first gap is a test of the jump and not of the runway.
const RUNWAY_START: int = 0
const RUNWAY_END: int = 44

## Section 2: three gaps at rising fractions of the measured 28-cell maximum. The point of the ladder is
## that the third one cannot be taken casually -- it needs full speed AND a late jump.
const GAP_EASY_START: int = 44        ## 12 cells -- 43% of max, clearable from a standstill run-up
const GAP_EASY_END: int = 56
const LANDING_A_END: int = 76
const GAP_MED_START: int = 76         ## 20 cells -- 71% of max
const GAP_MED_END: int = 96
const LANDING_B_END: int = 116
const GAP_COMMIT_START: int = 116     ## 26 cells -- 93% of max, two cells of margin
const GAP_COMMIT_END: int = 142
const LANDING_C_END: int = 166

## Section 3: four steps of exactly one logic tile (STEP_UP_PX = 16px = 4 cells), so each is auto
## step-up territory and the whole flight can be walked at speed without a single jump. It exists to
## contrast with the jumps either side of it.
const STAIRS_START: int = 166
const STAIR_RISE: int = 4
const STAIR_RUN: int = 4
const STAIR_COUNT: int = 4                ## STAIR_COUNT * STAIR_RISE == PLATEAU_LIFT, asserted by the suite
const STAIRS_END: int = STAIRS_START + STAIR_COUNT * STAIR_RUN
const PLATEAU_END: int = STAIRS_END + 24

## Section 4: THE ONE THE DIRECTOR ASKED FOR. A 30-cell pit -- deliberately two cells WIDER than the
## measured 28-cell maximum, so it cannot be crossed in one jump at any speed. The only way across is the
## perch in the middle, which is exactly `Body.WIDTH_PX` wide. You arrive at full run speed and have to
## kill that speed in the air to stop on it: the reversal is not optional here, it is the mechanic.
const PIT_START: int = PLATEAU_END
const PIT_WIDTH: int = 30
const PIT_END: int = PIT_START + PIT_WIDTH
const PERCH_WIDTH: int = 4            ## == Body.WIDTH_PX / TERRAIN_CELL_PX
const PERCH_START: int = PIT_START + (PIT_WIDTH - PERCH_WIDTH) / 2
const PERCH_END: int = PERCH_START + PERCH_WIDTH
const PERCH_ROW: int = PLATEAU_ROW + 6   ## below the lip, so it is a drop-and-arrest, not a hop up

## Section 5: five body-width pillars at 14-cell gaps (half the maximum), alternating height. Each hop is
## easy on its own; the sequence is what tests holding a line in the air, because the landing target is
## never where the last one left you pointed.
const PILLARS_START: int = PIT_END + 8
const PILLAR_WIDTH: int = 4
const PILLAR_GAP: int = 14
const PILLAR_COUNT: int = 5
const PILLARS_END: int = PILLARS_START + PILLAR_COUNT * (PILLAR_WIDTH + PILLAR_GAP)

## Section 6: free play. A long flat apron with four blocks at 4/8/12/16 cells, no required route and
## nothing to clear -- somewhere to just move around, which is what a feel judgment actually needs.
const APRON_START: int = PILLARS_END + 8
const APRON_END: int = APRON_START + 90
const WIDTH: int = APRON_END + 8


## `clay` for ground you walk on, `hardrock` for every target that has to be READ before it is jumped to
## -- the perch and the pillars. Two materials, not five: `MaterialLook` derives their colours from
## `data/materials`, and the point is a legible figure/ground split, not decoration.
static func build() -> TileGrid:
	var grid: TileGrid = TileGrid.new(WIDTH, GRID_HEIGHT, 20260830)
	_fill(grid, 0, WIDTH, CATCH_ROW, GRID_HEIGHT, &"clay")
	_surface_and_gaps(grid)
	_stairs_and_plateau(grid)
	_perch(grid)
	_pillars(grid)
	_apron(grid)
	return grid


static func _fill(grid: TileGrid, col0: int, col1: int, row0: int, row1: int, material: StringName) -> void:
	for col: int in range(col0, col1):
		for row: int in range(row0, row1):
			grid.set_material(Vector2i(col, row), material)


## The three landings, each a solid slab from the surface down to the catch floor, with the gaps simply
## left out. Solid rather than a thin platform so a gap reads as a real hole in the ground.
static func _surface_and_gaps(grid: TileGrid) -> void:
	_fill(grid, RUNWAY_START, RUNWAY_END, SURFACE_ROW, CATCH_ROW, &"clay")
	_fill(grid, GAP_EASY_END, LANDING_A_END, SURFACE_ROW, CATCH_ROW, &"clay")
	_fill(grid, GAP_MED_END, LANDING_B_END, SURFACE_ROW, CATCH_ROW, &"clay")
	_fill(grid, GAP_COMMIT_END, LANDING_C_END, SURFACE_ROW, CATCH_ROW, &"clay")


static func _stairs_and_plateau(grid: TileGrid) -> void:
	for i: int in STAIR_COUNT:
		var col0: int = STAIRS_START + i * STAIR_RUN
		var top: int = SURFACE_ROW - (i + 1) * STAIR_RISE
		_fill(grid, col0, col0 + STAIR_RUN, top, CATCH_ROW, &"clay")
	_fill(grid, STAIRS_END, PLATEAU_END, PLATEAU_ROW, CATCH_ROW, &"clay")


## One body-width block, floating, with open air all round it. Four rows thick so its top face reads as a
## surface rather than a line.
##
## EXPECT ONE `ambiguous floor selection` push_error HERE, and it is not a defect. A floating platform
## with the catch floor visible below it inside the same 48-row scan window is precisely the multi-level
## case `docs/adr/0005-heightfield-local-window.md` documents and accepts, and `resolve_floor`'s report is
## rate-limited to one occurrence per (column, floor) pair. The section is therefore also a live exercise
## of that known limitation, which `test_cave_geometry.gd` otherwise only reaches through
## `HostileChamber`'s authored cave. Anything OTHER than that one line here is worth investigating.
static func _perch(grid: TileGrid) -> void:
	_fill(grid, PERCH_START, PERCH_END, PERCH_ROW, PERCH_ROW + 4, &"hardrock")
	_fill(grid, PIT_END, PIT_END + 24, PLATEAU_ROW, CATCH_ROW, &"clay")


static func _pillars(grid: TileGrid) -> void:
	for i: int in PILLAR_COUNT:
		var col0: int = PILLARS_START + i * (PILLAR_WIDTH + PILLAR_GAP)
		## Alternating 0 / -6 / -12 / -6 / 0 relative to the surface, so no two consecutive hops are the
		## same shape and the sequence cannot be memorised as one repeated input.
		var lift: int = [0, 6, 12, 6, 0][i]
		_fill(grid, col0, col0 + PILLAR_WIDTH, SURFACE_ROW - lift, CATCH_ROW, &"hardrock")


static func _apron(grid: TileGrid) -> void:
	_fill(grid, APRON_START, APRON_END, SURFACE_ROW, CATCH_ROW, &"clay")
	for i: int in 4:
		var col0: int = APRON_START + 14 + i * 20
		var lift: int = (i + 1) * 4
		_fill(grid, col0, col0 + PILLAR_WIDTH, SURFACE_ROW - lift, SURFACE_ROW, &"hardrock")


## Spawn on the runway, far enough from the first gap to reach full speed before it.
static func spawn_x() -> int:
	return Fx.from_int(8 * Heightfield.TERRAIN_CELL_PX)


static func spawn_y() -> int:
	return Fx.from_int(SURFACE_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2
