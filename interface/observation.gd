## `Interface.Observation`, split into its own file at A' step 4 (D0356) exactly as `Envelope` was at
## D0294: reached through `Interface.Observation` and nowhere else, so there is one name. No
## `class_name`, on purpose -- a global `Observation` would be a second door.
##
extends RefCounted

## One tick's readable state, as a value. Holds no reference into `sim/`.
##
## The body's box edges travel as their own fields rather than being recomputed by the consumer from
## `pos` and `Body.WIDTH_PX`: those constants are `sim/body`'s, a `view/` file may not reach for them
## (`tools/layer_lint/layer_lint.py`'s own table gives `view` only `interface` and `core`), and two
## copies of the same half-width arithmetic is exactly the drift this layer exists to prevent.
var tick: int
var pos_x: int  ## Fx, all six of these
var pos_y: int
var left_x: int
var right_x: int
var top_y: int
var bottom_y: int
var vel_x: int
var vel_y: int
var on_floor: bool
var facing: int
var cell: Vector2i  ## the terrain cell the body's centre is in
var window: Rect2i
## THE WORLD'S OWN SIZE IN CELLS, so a consumer can tell the EDGE OF THE WORLD from a hole in it
## (D0302). `window` may extend past the world — the margin is added without clamping — and every
## plane accessor answers `&""` outside the data it was given, so "outside the world" and "open air"
## arrive as the same byte. That is fine for a painter drawing one cell at a time and wrong for any
## consumer that AVERAGES over a neighbourhood: `VeilPainter` blurs openness over 8 cells, read the
## out-of-world ring as air, and lit a false halo along the world's own left, right and bottom edges.
##
## A copy like every other field here, never a reference to the grid (ARCHITECTURE §3).
var world_cells: Vector2i
## THE WORLD SEED, and the whole of `docs/LEGACY_GAP.md` PRE-4 (D0308). `core/seams.gd` is fully
## ported, integer-exact over all 196,608 inputs, and `Seams.at(cell, world_seed)` could not be called
## by anything in `view/` because the seed was on `TileGrid` and `TileGrid` is `sim/`. One `int`.
##
## It is a SEED, not a handle: a painter may hash it and must never treat it as a key back into the
## sim. `Seams` is a pure function of `(coordinate, world_seed)` and never saved, which is exactly why
## this field is enough to draw the grain without the renderer reaching across the L2 boundary.
var world_seed: int = 0
## Row-major over `window`, one byte per cell: an index into `legend`. 0 is always the empty
## material, so `solid_at` is a byte comparison and not a string one.
var materials: PackedByteArray
var legend: PackedStringArray
## THE BACKGROUND WALL PLANE, same shape and same encoding as `materials`/`legend` (D0238). This is
## the layer `TileGrid.get_wall()` holds -- what `excavate()` REVEALS rather than erases, and where
## the lode migration put ore. A renderer needs it to draw a mined-out room as a recessed back wall
## instead of a hole in a sheet; without it there is no depth behind the player at all.
var walls: PackedByteArray
var wall_legend: PackedStringArray
## Whether the wall plane above was actually built (D0338). False means the envelope declined it and
## `wall_at` will refuse rather than answer air. Defaults TRUE so an Observation built by hand in a
## test behaves exactly as it did before this flag existed.
var has_walls: bool = true
## One entry per COLUMN of `window`, left to right: the walkable surface height as an `Fx` world-y,
## or `Heightfield.NO_FLOOR`. Derived here rather than by the consumer because `Heightfield` takes a
## `TileGrid` and `view/` may not hold one.
##
## `_y`, never `_row`: this is a pixel height in `Fx`, not a cell index, and `heightfield.gd` names
## it that way for the same reason -- "so a caller can't mistake one for the other."
##
## SCANNED WITHIN THE WINDOW ONLY. A column whose only solid cell sits above the window reads
## `NO_FLOOR`, because the observer was not given those cells. That is the envelope working, not a
## bug: an observation must never answer from data it did not hand over.
var surface_y: PackedInt32Array

## --- THE MINING VERB'S OWN STATE -----------------------------------------------------------------
##
## `docs/LEGACY_GAP.md` PRE-3, and the finding it records: `sim/mining/mining.gd` computed all of this
## and `observe()` read `_grid` and `_body` **and never touched `_mining` at all**. Every mining
## feedback capability in the backlog -- cracks, crumble, the hollow ring, the breach payoff, the
## draught, payout ticks -- was blocked behind one door that had simply never been opened.
##
## Copied per observation rather than handed over as a reference to the `Mining` object, which is the
## same rule the body's fields above follow: an `Observation` is a COPY, so a view cannot reach back
## through it and mutate the sim (`docs/ARCHITECTURE.md` L2, `tests/test_interface.gd`).

## The cell this tick's hold advanced, and whether there was one. **The boolean is not redundant.**
## `Mining.NO_CELL` is the sentinel, and a view testing against it would have to name a `sim/` symbol
## to ask an ordinary question -- which `tools/layer_lint` forbids and which would make the sentinel
## part of the public contract. The door answers the question instead of handing over the key.
var mining_charging_cell: Vector2i = Vector2i.ZERO
var mining_is_charging: bool = false

## Cell -> **progress toward breaking it, per mille**, for every cell currently holding a crack. A
## crack overlay reads this instead of probing the whole visible grid every frame, which is what
## `Mining.cracked_cells()` was written for and what nothing had yet called.
##
## THE FRACTION, NOT THE RAW BANKED CHARGE, and the difference is a layer boundary rather than a
## convenience. What a renderer draws is how far gone the rock looks, which is `banked / break_cost`
## — and `break_cost` is a function of the MATERIAL, so a view holding the raw charge would have to
## call `Mining.break_cost()` to mean anything by it. That is a `sim/` symbol, and `view/` may not
## name one. Per mille to match `mining_hollow`, and integer for the same reason everything else here
## is: a float in the observation is a float in a replay.
var mining_cracks: Dictionary = {}

## What this tick's blow actually did. `broke_cells` is target-first in the deterministic scan order
## `_clear_bite` walks, so a view spraying debris per cleared cell reads it rather than re-deriving
## the disc -- a second copy of that shape would be free to drift from the one that ran.
var mining_broke: bool = false
var mining_broke_material: StringName = &""
var mining_broke_cells: Array[Vector2i] = []

## THE HOLLOW READING AS A MAGNITUDE (per mille), and `mining_breach` is one threshold sampled from
## it. Legacy's own reason for carrying the number rather than the flag: "volume rides the reading, so
## closing on a cavity is a crescendo you can act on rather than a flag that flips." A consumer given
## only the boolean cannot reconstruct the crescendo; one given the magnitude can derive the boolean.
var mining_hollow: int = 0
var mining_breach: bool = false

## True on the tick the pick LANDS, false on the ticks between blows (D0279). An edge, not a level:
## legacy's ring, draught and pick animation all fire per blow, and firing them per charging tick
## would be sixty a second. The period shortens as `Mining`'s rhythm builds, which is that system's
## first outward sign.
var mining_swing: bool = false

## THE SWING DIRECTION, as a unit cell step from the body toward what it is working. `Mining.swing_dir`
## has been public "specifically for this" since it was written and **nothing has ever called it** —
## `docs/LEGACY_GAP.md` T1 #6 names that directly. A draught puff has to be placed on the NEAR face and
## drift along the swing, and deriving the direction a second time in the view would be a second copy
## of a thing the sim already decided (D0293).
var mining_swing_dir: Vector2i = Vector2i.ZERO

## ...and how far through the CURRENT swing the pick is, per mille — 0 on the tick it lands, climbing
## to 1000 as the next blow winds up. The edge above says a blow happened; this says where in the
## stroke the arms are, which is what a two-frame pick animation needs to put its struck frame on the
## tick the rock takes damage rather than on a free-running clock of its own (D0287).
var mining_swing_phase: int = 0

## The terrain cell's size in world pixels. **Not a mining field** — it belongs to whatever a painter
## does with `window`, `materials` and `walls`, all of which are cell-denominated while every draw
## call is in pixels. `view/` may not name `Heightfield.TERRAIN_CELL_PX`, and until now every painter
## that needed it either lived outside `view/` or worked in fractions. The layer lint caught the first
## one that did not (`view/visuals/crack_painter.gd`), which is the gate doing exactly its job.
var cell_px: int = 0

## The diameter, in world pixels, of what ONE blow destroys — `(2 * bite_radius + 1) * cell`. Carried
## because a crack overlay has to size itself against the blow rather than against the cell (see
## `view/visuals/crack_painter.gd`'s header on WG-4), and `Mining.bite_radius` is a `sim/` field a view
## may not read. Derived here rather than in the painter for the same reason `mining_cracks` is a
## fraction: the door converts, so no consumer has to name a sim symbol to interpret what it was given.
var mining_blow_px: int = 0

## True iff `c` holds solid material. Outside the window returns false -- NOT "unknown", and the
## distinction matters as soon as fog exists: a consumer asking about a cell it was not given should
## be reading `in_window` first. Deliberately not an error, because a renderer legitimately probes
## the ring just past its own window when deciding edges.
func solid_at(c: Vector2i) -> bool:
	return material_at(c) != &""

func material_at(c: Vector2i) -> StringName:
	return _plane_at(legend, materials, c)

## The BACKGROUND material at `c`, or `&""` -- both for "no wall here" and for "outside the window",
## exactly as `material_at` conflates them. Same reasoning, and the same warning applies: a consumer
## that needs to tell those apart asks `in_window` FIRST.
## FAILS LOUDLY WHEN THE PLANE WAS NOT REQUESTED (D0338), rather than answering `&""`. An absent plane
## and a world of air are the same answer, which is D0238's trap exactly -- and the consumer that would
## meet it, `WallPainter`, draws nothing for air, so the failure would arrive as a silently missing
## background rather than as an error. `has_walls` is the envelope's own `walls` flag carried through.
func wall_at(c: Vector2i) -> StringName:
	if not has_walls:
		push_error("Observation.wall_at: this observation was taken without the wall plane "
			+ "(Envelope.walls == false). Ask for it in the envelope rather than reading air.")
		return &""
	return _plane_at(wall_legend, walls, c)

## Shared body of the two plane readers. They are one function with two bindings, not two functions:
## written out separately they were byte-identical under identifier normalization and the BLOCKING
## duplication gate said so. Keeping the out-of-window `&""` in ONE place also means the two planes
## cannot drift on the question that matters most about them.
func _plane_at(plane_legend: PackedStringArray, bytes: PackedByteArray, c: Vector2i) -> StringName:
	if not in_window(c):
		return &""
	return plane_legend[bytes[_offset_of(c)]]

func in_window(c: Vector2i) -> bool:
	return window.has_point(c)

## The walkable surface height of one terrain column as an `Fx` world-y, or `Heightfield.NO_FLOOR`
## for a column outside the window or with no floor inside it.
##
## Takes a bare `int` column rather than a `Vector2i` on purpose: a surface is a property of a
## column, and passing a cell would invite a caller to believe the row mattered.
func surface_y_at_terrain_col(terrain_col: int) -> int:
	if terrain_col < window.position.x or terrain_col >= window.end.x:
		return Heightfield.NO_FLOOR
	return surface_y[terrain_col - window.position.x]

## Row-major offset of `c` within the window. Callers must have checked `in_window` first -- this
## does no bounds checking and would happily index a neighbouring row for a cell one column outside.
func _offset_of(c: Vector2i) -> int:
	return (c.y - window.position.y) * window.size.x + (c.x - window.position.x)


## --- THE HUB'S PLANES (A' step 4, D0356) ------------------------------------------------------------
##
## Everything legacy's renderer read off `FactorySim` that the door did not carry (plan §4 step 4's
## list), each a COPY bounded by the window: the terrain-cell planes (water, lodes, ore yield) over
## `window`, the metre-cell planes (placed layers, saplings, machines, power, piles) over
## `logic_window`, and the un-windowed session state (the pack, the rates, the winch tables, the plan,
## the aim). Integers and per-mille throughout: a float in an observation is a float in a replay.

## The metre cells `window` covers, in `logic_cell` units.
var logic_window: Rect2i
var hub_tick: int = 0
## Row-major over `window`, one byte per terrain cell: water units, 0..WATER_MAX. The two constants a
## painter needs are restated HERE, because the view may not reach into `sim/` for them (layer lint).
const WATER_MAX: int = WaterPlane.WATER_MAX
const CELL_PX: int = Heightfield.TERRAIN_CELL_PX
const LOGIC_PX: int = LogicGrid.TERRAIN_PER_LOGIC * Heightfield.TERRAIN_CELL_PX   # the machine cell, 16 px
## The body's numbers the audio beds derive their levels from (A' step 6f, D0366), restated here for the
## same layer reason: a walk is the rush bed's zero and terminal fall its one; the line's load is read
## against gravity; a haul is a length delta per tick against the reel rate.
const TICK_HZ: int = Body.TICK_HZ
const RUN_SPEED_PX_S: int = Body.RUN_SPEED_PX_S
const MAX_FALL_PX_S: int = Body.MAX_FALL_PX_S
const GRAVITY_PX_S2: int = Body.GRAVITY_PX_S2
const REEL_PX_S: int = (Grapple.REEL_PER_TICK * Body.TICK_HZ) / Fx.SCALE
## The generator's surface datum in terrain rows. The cave bed measures depth against the GENERATED
## ground, never against a scanned surface: legacy learned that a scan answers with the floor of your
## own shaft the moment you dig, so the bed that exists to sell descent was loudest where descent had
## happened (`legacy/scenes/main.gd:883-889`).
const SKY_ROWS: int = ShaftGenerator.SKY_ROWS
var water: PackedByteArray
## The wet terrain cells inside `window`, in `Ordering.cells` order: the sparse walk a per-frame painter
## takes instead of the whole window (A' step 6a, D0362).
var wet_cells: Array[Vector2i] = []
## terrain_cell -> {"material": StringName, "amount": int, "permille": int}, for lodes in the window.
var lodes: Dictionary = {}
## terrain_cell -> remaining yield, for SOLID ore cells in the window with an explicit yield; a solid
## ore cell absent here holds `ore_default`. `ore_like_legend[i]` says whether legend entry i is ore.
var ore_yield: Dictionary = {}
var ore_default: int = 0
var ore_like_legend: PackedByteArray
## logic_cell -> kind (`&"machine"`, `&"conduit"`, `&"rope"`, `&"torch"`) over `logic_window`.
var placed: Dictionary = {}
var conduit_tiers: Dictionary = {}
var saplings: Dictionary = {}     # logic_cell -> age
## One dictionary per machine in `logic_window`: cell, id, behavior, status, power_permille,
## progress_permille, facing, fuel, filter, input, output (the buffers duplicated).
var machines: Array[Dictionary] = []
var power: Dictionary = {}        # logic_cell -> milli-power
var piles: Dictionary = {}        # logic_cell -> {item: n}
var sink: Dictionary = {}
var pack: Array[Dictionary] = []  # [{item, count}] in hotbar order
var pack_selected: int = 0
var pack_bulk: int = 0
var pack_bulk_cap: int = 0
var pack_slots: int = 0
## THE CONSUMED CHANNEL: every flow event since the last `observe`, then cleared by the door -- the
## one thing `observe` empties, and not sim state (plan §3.2 on legacy's `FallingItems`).
var flow_events: Array[Dictionary] = []
var rates: Array[Dictionary] = []   # [{item, rate_centi}] fastest first
var winch_routes: Dictionary = {}
var winch_transit: Dictionary = {}
var winch_armed: Vector2i = Vector2i(-1, -1)
var dig_marks: Array[Vector2i] = []
var lode_target: Vector2i = Vector2i(-1, -1)
var lode_progress: int = 0        # per mille toward the next unit off the face
var aim_cell: Vector2i = Vector2i(-1, -1)
var aim_is_lode: bool = false
## --- the line and the medium (A' step 5c, D0360): the body's rope, for the painter, and its footing ---
var grapple_state: int = 0            # Grapple.State: 0 stowed, 1 flying, 2 anchored
var grapple_live: bool = false        # not stowed; the painter reads these three, never the enum
var grapple_anchored: bool = false
var grapple_throwing: bool = false    # a hook in the air, on its own or chained from a live line
var grapple_tip: Vector2i = Vector2i.ZERO      # Fx px, the hook head
var grapple_anchor: Vector2i = Vector2i.ZERO   # Fx px, where it bit (anchored)
var grapple_hitch: Vector2i = Vector2i.ZERO    # Fx px, what the body swings from (the last pivot or the hook)
var grapple_pivots: Array[Vector2i] = []       # Fx px, anchor-first
var grapple_length: int = 0           # Fx px of line on the winch
var grapple_taut: bool = false
var grapple_slack: int = 0            # per mille, 0 bar-taut .. 1000 hanging
var grapple_just_planted: bool = false
var grapple_just_cut: bool = false
var grapple_ghost: Dictionary = {}    # {hit, at, cell}: where a throw at the aim would land, while stowed
var hand: Vector2i = Vector2i.ZERO    # Fx px, where the line leaves the body
var climbing: bool = false
var wet: bool = false


func water_at(c: Vector2i) -> int:
	if not in_window(c):
		return 0
	return water[_offset_of(c)]


func lode_at(c: Vector2i) -> StringName:
	return (lodes.get(c, {}) as Dictionary).get("material", &"")


func lode_permille(c: Vector2i) -> int:
	return int((lodes.get(c, {}) as Dictionary).get("permille", 0))


## The yield the hover shows: a lode's amount, a seeded ore cell's, or the default for unseeded ore.
func deposit_at(c: Vector2i) -> int:
	if lodes.has(c):
		return int(lodes[c]["amount"])
	if ore_yield.has(c):
		return int(ore_yield[c])
	return ore_default if is_ore_like_at(c) else 0


func is_ore_like_at(c: Vector2i) -> bool:
	if not in_window(c) or ore_like_legend.is_empty():
		return false
	return ore_like_legend[materials[_offset_of(c)]] != 0


## Every item carried, for the carry look (`view/visuals/carry_look.gd`).
func pack_total() -> int:
	var total: int = 0
	for slot: Dictionary in pack:
		total += int(slot.get("count", 0))
	return total


func placed_at(logic_cell: Vector2i) -> StringName:
	return placed.get(logic_cell, &"")


func has_conduit(logic_cell: Vector2i) -> bool:
	return placed_at(logic_cell) == &"conduit"


func is_climbable(logic_cell: Vector2i) -> bool:
	return placed_at(logic_cell) == &"rope"


func has_torch(logic_cell: Vector2i) -> bool:
	return placed_at(logic_cell) == &"torch"


func machine_at(logic_cell: Vector2i) -> Dictionary:
	for m: Dictionary in machines:
		if m["cell"] == logic_cell:
			return m
	return {}


func power_at(logic_cell: Vector2i) -> int:
	return int(power.get(logic_cell, 0))


func pile_at(logic_cell: Vector2i) -> Dictionary:
	return piles.get(logic_cell, {})


func sapling_age(logic_cell: Vector2i) -> int:
	return int(saplings.get(logic_cell, -1))
