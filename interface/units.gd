## `Interface.Units`, reached through `Interface` and nowhere else for the same reason `Observation`
## has no `class_name` of its own (see observation.gd's header): one name, one door.
##
## THE RESTATED CONSTANTS. These are `sim/`'s numbers, restated here because `view/` may not reach
## into `sim/` for them (`tools/layer_lint/layer_lint.py`'s table gives `view` only `interface` and
## `core`). They lived on `Observation` until the 400-line cap closed that file to new fields (P034);
## the lift is mechanical -- every read site is a constant, the compiler catches every miss.
##
extends RefCounted

## Row-major plane reads are in these units: water runs 0..WATER_MAX over `window`, one byte per
## terrain cell.
const WATER_MAX: int = WaterPlane.WATER_MAX
const CELL_PX: int = Heightfield.TERRAIN_CELL_PX
const LOGIC_PX: int = LogicGrid.TERRAIN_PER_LOGIC * Heightfield.TERRAIN_CELL_PX   # the machine cell, 16 px
## The body's numbers the audio beds derive their levels from (A' step 6f, D0366), restated here for the
## same layer reason: a walk is the rush bed's zero and terminal fall its one; the line's load is read
## against gravity; a haul is a length delta per tick against the reel rate.
const TICK_HZ: int = Body.TICK_HZ
const HUB_HZ: int = ProductionRate.HUB_HZ   ## a recipe's `time_ticks` are HUB ticks: 20 a second, not 60 (D0461)
const RUN_SPEED_PX_S: int = Body.RUN_SPEED_PX_S
const MAX_FALL_PX_S: int = Body.MAX_FALL_PX_S
const GRAVITY_PX_S2: int = Body.GRAVITY_PX_S2
const REEL_PX_S: int = (Grapple.REEL_PER_TICK * Body.TICK_HZ) / Fx.SCALE
## The generator's surface datum in terrain rows. The cave bed measures depth against the GENERATED
## ground, never against a scanned surface: legacy learned that a scan answers with the floor of your
## own shaft the moment you dig, so the bed that exists to sell descent was loudest where descent had
## happened (`legacy/scenes/main.gd:883-889`).
const SKY_ROWS: int = ShaftGenerator.SKY_ROWS
## The "no walkable floor in this column" sentinel `surface_height_at` answers with, restated so a
## painter can compare against it without naming the sim class that owns it (A' step 6k, D0373).
const NO_FLOOR: int = Heightfield.NO_FLOOR
## Whether the aimed cell is within the mining reach of the body (`Mining.in_reach`), the gate every
## world verb uses, in world px.
const REACH_PX: int = (Mining.REACH_NUM * LOGIC_PX) / Mining.REACH_DEN   # that reach in world px, for the view
## The coarse map's class bytes (`map` over `map_cells`): TileGrid's four coarse classes, restated.
const MAP_VOID: int = TileGrid.COARSE_VOID
const MAP_WALL: int = TileGrid.COARSE_WALL
const MAP_ROCK: int = TileGrid.COARSE_ROCK
const MAP_ORE: int = TileGrid.COARSE_ORE
