class_name FactorySim
extends RefCounted

## The authoritative factory simulation: node-free, fixed-tick, deterministic. Runs headless with no
## scene tree, as tests/test_sim.gd does. The representation layer reads from this and never writes to
## it; all production math lives here.
##
## Topology: machines occupy cells on a grid (x = column, y = row, row increasing DOWNWARD). A machine's
## output falls straight down its column to the next machine below, or into the sink. The grid size and
## the straight-down-only rule are provisional; chutes, splitters and lateral routing are later slices.

## Domain-logic modules: per-tick algorithms extracted so tick() reads as a list of named subsystems.
## Each is a stateless helper operating on this sim's grids; the state and the public API stay on
## FactorySim. Preloaded by PATH rather than class_name so the headless --script test drivers resolve
## them without a refreshed global-class cache.
const WaterFlow := preload("res://src/core/water_flow.gd")
const PowerFlow := preload("res://src/core/power_flow.gd")
const Flora := preload("res://src/core/flora.gd")
const FineTerrain := preload("res://src/core/fine_terrain.gd")

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)
## Sized so a zoomed-out (3x) camera has terrain to scroll through. Provisional.
const GRID_COLS: int = 128
const GRID_ROWS: int = 128
## Items/tick a lift carries UP its column with no power. Below this rate a backlog piles at the lift.
## A fully-powered lift reaches LIFT_POWERED_THROUGHPUT, scaled by the power reaching its cell;
## under-supplied it labours back toward the baseline, which is brownout. The baseline is non-zero so
## the lift still works before power exists.
const LIFT_THROUGHPUT: int = 2          ## unpowered baseline, also the floor under brownout
const LIFT_POWERED_THROUGHPUT: int = 6  ## items/tick at full power
const LIFT_POWER_DEMAND: float = 4.0    ## power at the lift's cell for the full boost (less is proportional)
## The pump. Water floods down into a dig for free (the _flow_water gravity rule); getting it back out
## costs power, the same "down free, UP costs power" contract as the lift. A powered pump removes water
## from its own cell and the cells straight below it in its column, a power-scaled amount per tick, so a
## flooded pocket drains over time. Unpowered it is idle: there is no free drain. remove_water is an
## explicit accounted drain, so total_water drops; it sits outside _flow_water's move-only conservation.
const PUMP_REACH: int = 4               ## cells straight down (incl. its own) a pump can pull from this tick
const PUMP_RATE: int = 3                ## units drained per tick at full power (0 unpowered)
const PUMP_POWER_DEMAND: float = 4.0    ## power at the pump's cell for full drain rate (less is proportional)
## Power. A fueled generator burns coal and pours power into the cells around it, its innate aura;
## conduits extend the reach down and lateral. Consumers draw from the field to run. The field is
## derived, recomputed every tick from machine placement and fuel, never stored authoritative state, so
## it can never desync.
const GENERATOR_POWER: float = 6.0      ## power units a fueled generator emits at its source
const GENERATOR_FUEL_TICKS: int = 100   ## ticks one coal burns (5s @20Hz) before the generator refuels
const DRILL_FUEL_TICKS: int = 60        ## ticks one coal runs a Drill (3s @20Hz)

## The horizontal drill, the Borer: bores sideways through rock.
const H_DRILL_RANGE: int = 8            ## cells of gallery one placement reaches; relocate it to bore further
const H_DRILL_CYCLE: float = 1.5        ## seconds per bite (slower than the vertical drill)
const H_DRILL_FUEL_TICKS: int = 60      ## ticks one coal burns: ~2 bites/coal vs the vertical drill's 3
const H_DRILL_COAL_STOCK: int = 8       ## its self-feeding fuel bunker's cap (bored coal beyond it → belly)
const H_DRILL_BELLY_STACKS: int = 5     ## distinct item stacks the belly holds
const H_DRILL_BELLY_TOTAL: int = 40     ## total items across those stacks
const H_DRILL_TIER: int = 2             ## chews what a stone pick could; harder rock ends the gallery

## The drift rig (docs/DRIFT.md §3), the Borer's successor: it cuts a walkable 2-high gallery, it
## sorts pay from spoil at the face into two drop columns, and it eats power rather than coal. That
## appetite is what forces a power network instead of a fed box.
##
## Deviation from the spec: the spec has the rig advance instead of sitting at a fixed range. Here the
## FACE advances, 24 cells from one placement and three times the Borer's reach, but the MACHINE stays
## put. A machine that walks takes its two drop columns with it, and then every drain already dug is
## behind it within one cycle. Extraction is lateral; logistics stays gravity-vertical, which only works
## while the drains hold still.
const DRIFT_RANGE: int = 24             ## a gallery, not a stub
const DRIFT_CYCLE: float = 0.9          ## seconds per bite AT FULL POWER (browned out, proportionally slower)
## More than a lone generator can deliver anywhere. A generator pours GENERATOR_POWER at its own cell
## and its aura attenuates with distance, so the most any machine standing beside one reads is 4.0:
## auras take the max, they never sum. Only a conduit trunk sums (two feeders merging into one tube),
## and a tube bleeds 0.6 of what it carries to the machine beside it. Measured: a lone adjacent
## generator gives this rig 0.67 speed, a two-generator trunk 0.93, a three-generator trunk full.
## Under-supplied the rig labours rather than refusing.
const DRIFT_POWER_DEMAND: float = 6.0
const DRIFT_BELLY: int = 48             ## per stream. Each jams on its own, and the status says which.
const DRIFT_TIER: int = 2               ## same bit as the Borer: a logistics upgrade, not a drive one
## The crusher (docs/DRIFT.md §4): spoil in, gravel out. It is the sink for a gallery's ~8:1 spoil
## stream and the only source of gravel, the one material that PACKS (see the fill layer below). Two
## units of spoil, any mix of them, become one of gravel, so the stream halves passing through. Pay is
## never crushed: ore-like items fall straight through to the output.
const CRUSH_CYCLE: float = 1.1          ## seconds per crush at full power
const CRUSH_POWER_DEMAND: float = 3.0   ## a lone generator's aura (4.0) runs ONE crusher flat out
const CRUSH_RATIO: int = 2              ## units of spoil consumed per gravel produced
const CRUSH_BELLY: int = 60             ## gravel held before it jams on a sealed column
## Packing (docs/DRIFT.md §4): the difference between rock stacked back and rock that was always there.
## Every hand-placed block is LOOSE fill and weeps: a wet cell pressing on one side pushes a unit
## through to the open side every SEEP_INTERVAL ticks. Packed gravel does not, so a gallery backfilled
## with the stone dug out of it is a sieve and the same gallery packed with crushed gravel is a
## bulkhead. Undisturbed strata never seeps: seeping is a property of construction, not of the world.
const SEEP_INTERVAL: int = 12           ## ticks between weeps: a seep, not a flow
const SEEP_PRESSURE: int = 4            ## water level on the wet side before it finds a way through
const FILL_LOOSE: StringName = &"loose"
const FILL_PACKED: StringName = &"packed"
## Hopper: stockpiles what falls into it (input_buffer is the store, unbounded) and meters it back down
## to a machine below with back-pressure, feeding only while the consumer's buffer is under
## HOPPER_FEED_CAP, so the stockpile stays in the hopper instead of overflowing the forge. With no
## consumer below it just holds.
const HOPPER_RELEASE: int = 1           ## items released downward per tick when the consumer has room
const HOPPER_FEED_CAP: int = 3          ## hold releasing once the machine below is backed up to this many
const POWER_AURA: int = 2               ## innate radius (cells) a generator powers WITHOUT any conduit
## Conduits carry power further than the aura: DOWN and LATERAL, never UP (a U-shape delivers as an L).
## The no-up rule makes the network acyclic top-to-bottom, so the field resolves in a SINGLE downward
## sweep, with no iterative solver. Vertical feeders SUM (two trunks merge into a thicker one), clamped
## by the tube's capacity for its tier; the clamp also bounds any branch-relattice amplification, so
## additive merge can never run away. Horizontal spread is a lossy MAX delivery, carrying power across
## e.g. the bottom of an L. Per-step keep factors set the reach a single tier covers before it fades.
const CONDUIT_CAPACITY: float = 12.0    ## max power a tier-1 tube carries (caps the additive merge)
const CONDUIT_V_KEEP: float = 0.92      ## fraction kept crossing ONE cell DOWN (sets vertical reach)
const CONDUIT_H_KEEP: float = 0.80      ## fraction kept crossing ONE cell SIDEWAYS (lateral is lossier)
const CONDUIT_BLEED: float = 0.6        ## fraction a conduit shares to adjacent cells (so machines draw it)

## The behavior registry: the one sim-side table wiring a MachineDef.behavior tag into the tick.
## Entries (all optional):
##   run          its per-tick work (method name, called with the MachineState)
##   status       the derivation machine_status() reads; MUST mirror run's gates
##   dests        where _flow routes its output (absent = the default, straight down its column)
##   updraft      true: a clear open column above it is a rideable updraft (the lift)
##   power_source true: while fueled it pours GENERATOR_POWER into the network (the generator)
## A def with no entry (empty tag) is the default named recipe-runner. A new machine behavior is its
## functions plus one entry here plus a Visuals.MACHINE_STYLE entry for its look.
## Entries hold method NAMES dispatched via call(), not bound Callables: a Callable bound to self and
## stored on self gives every RefCounted sim a reference cycle, leaking one per session or test.
const _BEHAVIORS: Dictionary = {
	&"lift": {"run": &"_run_lift", "status": &"_status_mover", "dests": &"_destinations_lift",
		"updraft": true},
	&"splitter": {"run": &"_run_splitter", "status": &"_status_mover",
		"dests": &"_destinations_splitter"},
	&"drill": {"run": &"_run_drill", "status": &"_status_drill"},
	&"generator": {"run": &"_run_generator", "status": &"_status_generator", "power_source": true},
	&"hopper": {"run": &"_run_hopper", "status": &"_status_mover"},
	&"descent": {"run": &"_run_descent", "status": &"_status_descent"},
	&"h_drill": {"run": &"_run_h_drill", "status": &"_status_h_drill", "dests": &"_destinations_h_drill"},
	&"drift": {"run": &"_run_drift", "status": &"_status_drift", "dests": &"_destinations_drift",
		"flow": &"_flow_drift"},
	&"pump": {"run": &"_run_pump", "status": &"_status_pump"},
	&"crush": {"run": &"_run_crush", "status": &"_status_crush"},
	&"spur": {"run": &"_run_spur", "status": &"_status_spur"},
}

## The descent engine, the L1 to L2 gate (docs/PROGRESSION.md §2): placed over the seal, it eats
## gravity-fed ingots as a true sink and at its quota breaches the seal below, boring the shaft into
## Stonereach. The quota is a throughput wall to out-produce, not a hand-carryable toll: hand-feeding 64
## ingots means 128 hand-mined ore from finite deposits, smelted and hauled one trip at a time, which
## the finite-deposit system makes punishingly slow. An automated drill-to-forge line clears it
## passively; _test_descent_automation proves the line out-produces the wall. Kept modest so the game
## never turns grindy.
const DESCENT_QUOTA: int = 64
const DESCENT_EATS: StringName = &"ingot"

## cell (Vector2i) -> MachineState. Authoritative placement + flow topology.
var grid: Dictionary = {}
## Solid terrain cells (cell -> material StringName, e.g. &"earth" / &"ore"): the ground the player
## stands on and digs through. Authoritative world state like `grid`; placement is blocked in solid
## cells. Mutated ONLY by discrete calls (set_solid / mine), never as a side effect of the real-time
## avatar moving, so the sim stays deterministic and serializable. The avatar lives in the
## representation layer and never enters the tick.
var solid: Dictionary = {}
## Background wall layer (cell -> material id): what sits behind a cell, independent of whether the
## cell is solid. Mining a block leaves its wall. Read-only to the view (wall_at); written only by
## load_world / set_wall. Not collision (walls are walked through), not "items present".
var wall: Dictionary = {}
## Ore-vein yield (cell -> remaining extractable units) over SOLID ore/coal cells: the richness of a
## visible ore block. A drill placed above it bores straight down, draining one unit per cycle and
## clearing the cell (carving its shaft) when the cell runs dry. Hand-mining an ore block instead grabs
## a loose burst of 3-6 and clears the whole block, so a drill on the vein is worth far more. Latent
## world resource, NOT "items present": conservation-neutral, realized into total_produced only as a
## drill or hand actually pulls it. An ore cell with no entry defaults to DEFAULT_ORE_DEPOSIT, so there
## is no "empty vein" case.
var deposits: Dictionary = {}
## Drill-yield of an ore cell with no explicit richness seeded, so every ore block is worth drilling
## near spawn and deep alike. Seeded deposits run in the hundreds near spawn and the thousands deep.
const DEFAULT_ORE_DEPOSIT: int = 250
## The lode (cell -> ore item id): ore in the BACKGROUND plane, over cells whose solid block is gone
## (`docs/LODE.md`). Terrain is what is carved; the lode is what is extracted. Hand-mining an ore block
## takes its 3-6 burst and OPENS the vein rather than ending it: what the burst did not take stays in
## the cell as a lode that can keep being worked, instead of being erased from `deposits`. Not
## collision, not "items present": latent like `deposits`, which holds the remaining amount for solid
## ore blocks and lodes alike. Cleared only by load_world and by being worked dry; placing a block back
## over a lode covers it, it does not destroy it.
var lode: Dictionary = {}
## What each lode held when it was opened (cell -> units): the denominator `lode_fraction` thins the
## fleck field against. Measuring remaining units against DEFAULT_ORE_DEPOSIT instead answers "how rich
## is this vein compared to a standard one" rather than "how much of THIS vein is left", and the two
## come apart badly at the small end: the untouched 45-unit starter adit drew one fleck in six and read
## as stripped. Extent already carries richness (a big body covers more wall); density carries
## depletion.
var lode_max: Dictionary = {}
## What the player is carrying (item StringName -> count). Session state owned by the sim so it stays
## deterministic and serializable; the avatar only triggers discrete mine/deposit calls. Counted as
## "items present" for conservation. Rendered as the inventory hotbar (see `inventory_slots`).
var inventory: Dictionary = {}
## How many distinct stacks the carried pack shows as hotbar slots. Sized to hold the current resources
## plus craftable machine types at once (ore/ingot/wood/coal plus the machines). Distinct from the BULK
## cap below: slots are what the hotbar draws, the cap is what the pack weighs.
const INVENTORY_SLOTS: int = 10
## THE BULK CAP: units of BULK freight the pack holds at once, the limit that makes hauling a repeated
## job instead of one trip. Ore, rock and refined goods are bulk; tools, bits and machine items are not,
## so the kit and the buildings stay convenient and only the freight is taxed. The tax is INTERRUPTION,
## and nothing on this path touches movement: a full pack ends a trip, it never slows a body down.
##
## THE CAPABILITY IS HERE AND THE ENFORCEMENT IS NOT. `mine()` and every machine path keep banking what
## the world gives them, uncapped, so a fixture that builds scenery by calling mine() in a loop is
## untouched. The player verb asks `can_carry` before it takes something into the pack; see
## `is_bulk_item`.
##
## 90 is measured. A spike drove a held-input actor at a generated lateral lode face holding 263 workable
## units and counted full trips per candidate: uncapped 1 trip, cap 130 three, cap 90 three, cap 65 five.
## 90 and 130 sit on the same step of that staircase, and 90 is the low end of the step, so a leaner face
## than 263 units still splits into more than one trip. 65 overshoots the 2-4 trip band.
##
##   THAT SPIKE COUNTED RAW ORE ONLY. `is_bulk_item` charges rock and refined goods to the same pool, so
##   a mixed face fills the pack sooner than the spike's three trips and never later. Three is a floor on
##   the trip count, not an estimate of it.
const PACK_BULK_CAP: int = 90
## Placed machines in insertion order, for deterministic iteration.
var machines: Array[MachineState] = []
## Product piles resting on the dug floor: cell (Vector2i) -> {item -> count}. A machine spits its
## output downward; gravity carries it down the column and it lands on top of the first solid cell, or
## cascades into a machine below. Walking over a pile scoops it into the pack. Authoritative sim state,
## mutated only in _flow and by collect_ground, counted as "items present" for conservation.
var ground: Dictionary = {}
## Items that fell off the bottom of the world, from a column dug clear through with no floor. A void
## sink kept only so conservation accounting never silently loses an item.
var sink: Dictionary = {}
## Conservation bookkeeping: items are created and destroyed ONLY by a recipe. Holds while no machine
## is removed mid-run; removing a machine intentionally discards its buffered items.
var total_produced: Dictionary = {}
var total_consumed: Dictionary = {}
## Cosmetic output channel: item movements logged during _flow for the view to animate as falling
## sprites. The sim NEVER reads this back, so clearing it changes no production; the representation
## layer drains it each frame. Each entry: {item, from: Vector2i, to: Vector2i, count}.
var flow_events: Array[Dictionary] = []
## Where the last drop_item() landed (the pile cell): a transient hint the controller reads to grant a
## brief no-auto-pickup grace, so a just-dropped item is not instantly sucked back up. Not
## authoritative state, like flow_events: reset per drop, never saved.
var last_drop_landing: Vector2i = Vector2i(-1, -1)
## Cosmetic channel like flow_events: cells whose terrain (solid/wall) changed since the view last
## drained this. The chunked terrain renderer repaints ONLY the affected chunks instead of the whole
## 7700-cell world, which cost a ~300ms freeze per dig. The sim writes on every terrain edit
## (mine/place/drill-bore/fell/set_solid); the view reads and clears it each frame; the sim never reads
## it back, so clearing changes no production.
var terrain_dirty: Array[Vector2i] = []
## Derived power field (cell -> available power units), rebuilt from scratch every tick by
## _compute_power from fueled generators and conduits. NOT authoritative state: a pure function of
## placement and fuel, so it can never desync. Consumers read it via power_at(); the view tints it.
var power: Dictionary = {}
## Placed power conduits: cell -> tier (int). A third world layer alongside `solid` and `wall`, NOT a
## machine, so item-flow, collision and the tick never touch it and the player walks through tubes.
## Carries power down and lateral in _compute_power. Authoritative state, mutated only by
## place_conduit/remove_conduit.
var conduit: Dictionary = {}
## Placed rope: cell -> true. A placed layer like `conduit`: NOT solid, NOT a machine, so item-flow,
## collision, updrafts and the tick never see it, and falling ore pours straight through a roped shaft.
## The avatar reads is_climbable() to climb it. Authoritative state, mutated only by
## place_rope/remove_rope (discrete player calls).
var rope: Dictionary = {}
## Mounted torches: cell -> true. A placed layer like `rope`: not solid, not a machine, and items fall
## straight through. The sim owns placement and the item ledger; the light pool is representation.
## Mutated only by place_torch/remove_torch (discrete player calls).
var torch: Dictionary = {}
## Water: a discrete-cell fluid layer, cell -> INTEGER level (0..WATER_MAX). Integer only, never
## floats: float drift would break the deterministic-tick invariant. Water falls for free, then settles
## laterally toward a flat top, and never enters solid rock (it is displaced when a cell becomes
## solid). _flow_water() only MOVES water between cells, with no source or drain, so total_water() is
## invariant across a tick. Authoritative world state like `solid` and `conduit`; mutated by the
## discrete add_water/remove_water and by the per-tick _flow_water sweep.
var water: Dictionary = {}
const WATER_MAX: int = 8                       ## units of water a full cell holds (integer levels only)
## Fill: cell -> FILL_LOOSE | FILL_PACKED, for solid cells the player built rather than ones the world
## laid down. A property of construction, not of material: the same stone reads as strata where the
## generator put it and as loose fill where it was stacked back. Written only by place_block (loose, or
## packed for gravel) and by the erasures that take a cell away; read only by the seep step and the
## renderer, so a mis-tracked cell can do nothing worse than weep or not weep.
var fill: Dictionary = {}
## Researched techs (tech id -> true), the demand-side pull (docs/PROGRESSION.md §5). The tree lives in
## ResearchRules as static data; this is the per-session unlock state. Mutated ONLY by research_tech, a
## discrete player call at the Bazaar bench, and read by the craft gate: deterministic and
## serializable.
var research: Dictionary = {}
## Planted saplings: cell -> growth ticks so far. A placed layer like `torch`, except the tick grows
## it: at SAPLING_GROW_TICKS the cell sprouts a real tree (trunk plus canopy, the worldgen shape) into
## whatever space is still open. Saplings drop from chopped canopies as a deterministic per-cell share
## of leaves, so wood renews instead of dead-ending when the worldgen trees run out. Authoritative,
## mutated by plant_sapling and the tick's growth sweep.
var sapling: Dictionary = {}

## Fine terrain: a second, finer terrain layer at SUBDIV times the coarse resolution (8px fine cells
## against 32px coarse). Additive and derived. The coarse `solid` dict stays the ONE authority for ALL
## logistics: is_solid, surface_row, ramp_dir, mining, collision inputs, _column_landing, machines, flow
## and power all read `solid`, and the fine layer never feeds them. The fine grid is for the molded
## render (scenes/fine_terrain.gd bakes from it) and, in later slices, fine collision and brush digging.
## Because it is a pure function of `solid` and `world_seed` it is NOT saved: rebuild_fine_terrain()
## rebuilds it deterministically after load_world or a save-restore, so it can never desync and the save
## envelope stays small. Stored as one flat PackedByteArray (1 = solid, 0 = air), sized
## fine_w × fine_h (~120 KB at 384×320), indexed fy * fine_w + fx.
const SUBDIV: int = 4                              ## fine cells per coarse cell side (8px fine @ 32px cell)
## Fine-detail worldgen tuning. Deterministic: seeded FastNoiseLite and coordinates ONLY, no time or
## RNG. The molding bends only the ~1-cell boundary band between solid and air; deep interior stays
## solid and open stays open. Edge noise erodes and accretes the boundary into organic curves; grit
## speckle and thin protrusions near surfaces add crunch. See _sync_fine_block / rebuild_fine_terrain.
const FINE_EDGE_FREQ: float = 0.22                 ## boundary erosion/accretion; bends over ~4 fine cells
const FINE_EDGE_AMP: float = 0.62                  ## how hard the edge noise bends the boundary band
## Sampled on the integer fine grid, so a frequency at or above 1.0 has a period under two samples and
## every fine cell gets an uncorrelated value: white noise, not grit. At 1.10 the boundary alternated
## in and out on EVERY cell, and a rock lip that should read as a rough edge printed as a one-pixel
## dither along the whole floor. Grit has to bite in clumps, so keep this well under 1.0: it then
## clusters across a couple of cells, which is what a chipped edge looks like.
const FINE_GRIT_FREQ: float = 0.34                 ## grit that pits/protrudes near faces, in clumps
const FINE_GRIT_BITE: float = 0.42                 ## grit strength at an exposed face (fades inward)
const FINE_EROSION_BIAS: float = 0.04              ## tiny net-erode so cave mouths open rather than seal
var world_seed: int = 0                            ## the seed the terrain was generated from (drives fine detail)
var _fine_solid: PackedByteArray = PackedByteArray()   ## 1 = solid, 0 = air; size fine_w()*fine_h()
var _fine_edge: FastNoiseLite                      ## boundary-molding noise (built lazily on first rebuild)
var _fine_grit: FastNoiseLite                      ## grit/protrusion noise

var _tick_accumulator: float = 0.0

## Production-rate sampling: a ring buffer of total_produced snapshots on a fixed tick cadence, so
## production_rate() can answer how fast the factory is making an item over a sliding ~60s window.
## Deterministic and derived; production logic never reads it back.
const RATE_SAMPLE_TICKS: int = 20        # one snapshot per simulated second
const RATE_WINDOW_SAMPLES: int = 61      # ~60s of history
var _rate_tick: int = 0
var _rate_samples: Array[Dictionary] = []   # each: {"tick": int, "totals": Dictionary}
var _seep_tick: int = 0                     # counts ticks between seep passes (see _seep_step)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


## Coal-burners: the behaviors whose runner spends `fuel` and refills it from buffered coal. Kept
## beside machine_status so what a box eats cannot drift from the runners that eat it.
const _COAL_BURNERS: Array[StringName] = [&"drill", &"h_drill", &"generator"]


## Would this machine consume `item` if fed it? True for a recipe machine's ingredients, a
## coal-burner's coal and the descent engine's ingots; false for everything else, so a mis-aimed
## handful cannot disappear into a box that will sit on it forever. Read-only derivation. `deposit`
## itself stays unfiltered so a test rig may prime any buffer; this is the player-facing question.
func machine_eats(machine: MachineState, item: StringName) -> bool:
	if machine == null:
		return false
	var behavior: StringName = machine.def.behavior
	if behavior == &"descent":
		return item == DESCENT_EATS
	if item == &"coal" and _COAL_BURNERS.has(behavior):
		return true
	var recipe: RecipeDef = machine.def.recipe
	return recipe != null and recipe.inputs.has(item)


## Read-only status of a machine this tick, mirroring the run-gates in _run_machine so the two cannot
## drift. Pure derivation, no mutation. The representation draws it as a status dot plus a needs-X
## glyph. One of:
##   &"working"  actively doing its job: producing, moving or burning
##   &"no_fuel"  a drill or generator with no fuel and no coal to burn
##   &"no_input" a recipe machine (forge) starved of ingredients, or a drill with nothing borable below
##   &"blocked"  a drill whose ore has no drain below (rock or floor directly under the vein)
##   &"idle"     a mover (lift/hopper/splitter) with nothing in it right now; benign, not broken
func machine_status(machine: MachineState) -> StringName:
	var entry: Dictionary = _BEHAVIORS.get(machine.def.behavior, {})
	if entry.has("status"):
		var status: StringName = call(entry["status"], machine)
		return status
	# ordinary recipe machine (e.g. the forge)
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return &"idle"
	return &"working" if _has_inputs(machine, recipe) else &"no_input"


## Drill status: mirrors _run_drill's gates, in order: something to bore, then a drain, then fuel.
func _status_drill(machine: MachineState) -> StringName:
	var on_lode: Vector2i = drill_lode_target(machine.cell)
	if on_lode.x < 0:
		# Spent is not starved. A Head standing on a vein it has finished is known by the Head having
		# pulled something and there being no lode left under it, so a drill that was simply misplaced
		# still reads as starved.
		if machine.fed > 0 and not _coverage_has_ore(machine.cell):
			return &"spent"
	var t: Vector2i = on_lode if on_lode.x >= 0 else drill_target(machine.cell)
	if t.x < 0:
		return &"no_input"                                    # no solid ore below to bore (spent/relocate)
	if on_lode.x < 0 and _drill_blocked(t):
		return &"blocked"                                     # ore has no drain below: dig a drain below
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## The Spur: a cheap module that extends a Head's reach across the vein it is standing on.
##
## It has no cycle of its own; it is one more mouth on the SAME drill (`docs/LODE.md` §5). One Head,
## many Spurs, one column, one drain.
##
## A Spur eats what it STANDS ON, exactly like the Head, so it must be in an open cell whose backing is
## a lode, orthogonally touching a Head or another Spur that chains back to one. Which cells a chain
## covers is therefore visible in the world without a readout.
##
## _coverage_has_ore answers whether anything is left anywhere in this Head's reach. A Head whose own
## cell is finished but whose Spurs are not is still working and must not say `spent`, which means
## "pick me up and move me".
##
## _live_mouths counts how many cells in this Head's reach still hold ore. The fuel bill is the LIVE
## reach, not the built one: a chain half worked out costs half as much to run.
func _live_mouths(head_cell: Vector2i) -> int:
	var n: int = 0
	for c: Vector2i in head_coverage(head_cell):
		if lode.has(c) and int(deposits.get(c, 0)) > 0:
			n += 1
	return maxi(n, 1)


func _coverage_has_ore(head_cell: Vector2i) -> bool:
	for c: Vector2i in head_coverage(head_cell):
		if lode.has(c) and int(deposits.get(c, 0)) > 0:
			return true
	return false


func _run_spur(_machine: MachineState) -> void:
	pass                                   # driven by its Head; see `_run_drill`


func _status_spur(machine: MachineState) -> StringName:
	if spur_head(machine.cell).x < 0:
		return &"unlinked"                 # placed on a vein but reaching nothing
	if not lode.has(machine.cell):
		return &"spent"                    # its own cell is worked out; the chain past it still runs
	return &"working"


## Orthogonal neighbours, in a FIXED order. Coverage order decides which cell of a chain is drained first
## when a Head cannot afford all of them, so it has to be a property of the layout and never of iteration.
const _ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]


## Every lode cell one Head works: its own, plus every Spur chained to it. Breadth-first from the Head,
## so the order is by chain DISTANCE: the near end of a spur line drains before the far end.
func head_coverage(head_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [head_cell]
	var seen: Dictionary = {head_cell: true}
	var queue: Array[Vector2i] = [head_cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for step: Vector2i in _ORTHO:
			var n: Vector2i = c + step
			if seen.has(n):
				continue
			var m: MachineState = machine_at(n)
			if m == null or m.def.behavior != &"spur":
				continue
			seen[n] = true
			out.append(n)
			queue.append(n)
	return out


## The Head a Spur reports to, or (-1, -1) if its chain reaches none. Walked from the Spur rather than
## read off a stored link, so a chain broken by picking a middle Spur up goes dead the same frame.
func spur_head(from: Vector2i) -> Vector2i:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for step: Vector2i in _ORTHO:
			var n: Vector2i = c + step
			if seen.has(n):
				continue
			var m: MachineState = machine_at(n)
			if m == null:
				continue
			if m.def.behavior == &"drill" and lode.has(n):
				return n
			if m.def.behavior != &"spur":
				continue
			seen[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


## Generator status: burning, or holding coal to burn, is working; otherwise it needs coal.
func _status_generator(machine: MachineState) -> StringName:
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## A mover (lift/hopper/splitter): working while goods are in it, idle when empty.
func _status_mover(machine: MachineState) -> StringName:
	return &"working" if not machine.input_buffer.is_empty() else &"idle"


## Does this def's behavior entry set `flag`? The registry read for one-off behavior queries such as
## updraft_at and the power sweep, so a second lift-like or generator-like machine needs no change.
func _behavior_flag(def: MachineDef, flag: StringName) -> bool:
	return bool((_BEHAVIORS.get(def.behavior, {}) as Dictionary).get(flag, false))


## Is this cell solid (any material)? The representation reads this for collision; the sim mutates it
## only via set_solid / mine.
func is_solid(cell: Vector2i) -> bool:
	return solid.has(cell)


## Is `cell` inside a lift's updraft, i.e. is there a clear column straight DOWN to a lift machine? The
## lift inverts gravity in the open shaft above it and the avatar reads this to ride UP. Pure query, no
## sim mutation.
func updraft_at(cell: Vector2i) -> bool:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var here := Vector2i(cell.x, row)
		if solid.has(here):
			return false  # a floor breaks the draft
		var m: MachineState = grid.get(here, null)
		if m != null:
			return _behavior_flag(m.def, &"updraft")  # first machine below an updraft source → in its draft
	return false


## The material in a cell (&"earth" / &"ore"), or &"" if open. Lets the view tint veins.
func material_at(cell: Vector2i) -> StringName:
	return solid.get(cell, &"")


## Surface silhouette: the ONE authority for the walkable-top shape, shared by renderer and player.
## The diagonal slope of the ground is a property of terrain topology alone: independent of material
## (earth, stone and ore all ramp the same) and EXCLUDING machines (a placed machine is a box to bump
## or jump onto, never a hill). Both the renderer, which draws the diagonal, and the avatar, which
## glides it, call these, so what is drawn is exactly what is walked.

## Topmost solid terrain row in a column (the exposed surface), or GRID_ROWS if the column is all air.
## Foliage (wood/leaves) is SKIPPED: it is solid for collision and mineable, but it is not walkable
## ground and must not become the silhouette, or a tree draws a grass cap on its canopy and the avatar
## tries to ramp up the trunk. Machines get the same exclusion: present, but not the terrain top.
func surface_row(col: int) -> int:
	for row: int in range(0, GRID_ROWS):
		var cell := Vector2i(col, row)
		if solid.has(cell) and not _is_foliage(solid[cell]):
			return row
	return GRID_ROWS


## Tree materials: solid and mineable, but excluded from the walkable surface silhouette (surface_row).
func _is_foliage(material: StringName) -> bool:
	return material == &"wood" or material == &"leaves"


## The same test, public: passes that describe ROCK have to exclude the trees standing in it. The
## renderer's seam grain is one, since a tree has no bedding planes.
func is_foliage_material(material: StringName) -> bool:
	return _is_foliage(material)


## After a cell clears, fell any foliage that just lost its root. A tree stands because its base rests
## on solid ground; cut the base trunk or dig the earth under it and everything above falls. FOLIAGE
## only, NOT terrain: caves do not collapse. A connected foliage component (8-way, wood and leaves
## together) is rooted iff some cell in it sits directly on non-foliage solid; an unrooted component is
## felled block-by-block into the pack, with accounting identical to hand-chopping each cell, so
## conservation holds exactly.
func _settle_foliage(around: Vector2i) -> void:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	var handled: Dictionary = {}
	for d: Vector2i in dirs:
		var seed: Vector2i = around + d
		if handled.has(seed) or not (solid.has(seed) and _is_foliage(solid[seed])):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [seed]
		var seen: Dictionary = {seed: true}
		var rooted: bool = false
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			handled[c] = true
			var below: Vector2i = c + Vector2i(0, 1)
			if solid.has(below) and not _is_foliage(solid[below]):
				rooted = true
			for nd: Vector2i in dirs:
				var nb: Vector2i = c + nd
				if not seen.has(nb) and solid.has(nb) and _is_foliage(solid[nb]):
					seen[nb] = true
					stack.append(nb)
		if not rooted:
			for c: Vector2i in comp:
				_fell_foliage_cell(c)


## Remove one un-rooted foliage cell and award its yield the SAME way hand-chopping does: wood → pack,
## a share of leaves → a sapling, so conservation stays exact.
func _fell_foliage_cell(c: Vector2i) -> void:
	var mat: StringName = solid.get(c, &"")
	if mat == &"" or not _is_foliage(mat):
		return
	solid.erase(c)
	_dirty_terrain(c)
	# Through the cap, like every other path that DESTROYS what held the material. This is the cascade — the
	# rest of a tree coming down after its base was cut — and it is a separate write from `mine`'s own
	# foliage branch, which is exactly why it was missed: a fixture that fells a lone block never reaches it,
	# and a full pack was taking a four-block trunk three units past the cap.
	if mat == &"wood":
		take_into_pack(&"wood", 1, c)
		total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + 1
	elif mat == &"leaves" and leaf_drops_sapling(c):
		take_into_pack(&"sapling", 1, c)
		total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
	_resettle_pile_above(c)


## Slope of the exposed surface at a column: +1 rising to the right, -1 rising to the left, 0 flat.
## A neighbour exactly ONE tile higher reads as a 45° ramp; a bigger step is a wall, returning 0, so the
## avatar's square-collision blocks it and the renderer draws no diagonal. Terrain only: machines and
## material never enter.
func ramp_dir(col: int) -> int:
	var here: int = surface_row(col)
	var left: int = surface_row(col - 1)
	var right: int = surface_row(col + 1)
	if right == here - 1 and left >= here:
		return 1
	if left == here - 1 and right >= here:
		return -1
	return 0


## Seed or clear a terrain cell, used to build the starting world. Discrete edit; in-bounds only.
## Pass &"" to clear, otherwise the material (&"earth" default).
func set_solid(cell: Vector2i, material: StringName = &"earth") -> void:
	if not in_bounds(cell):
		return
	if material == &"":
		solid.erase(cell)
	else:
		solid[cell] = material
		water.erase(cell)          # rock displaces water: the two layers never coexist in a cell
	fill.erase(cell)               # strata, not construction: what set_solid writes is the world's own rock
	_dirty_terrain(cell)
	_bazaars_dirty = true


## The background wall material in a cell (e.g. &"stone_wall"), or &"" if none. View reads this to
## draw the carved-room backing behind dug-out cells.
func wall_at(cell: Vector2i) -> StringName:
	return wall.get(cell, &"")


## Set or clear a background wall cell (in-bounds; &"" clears). Discrete edit like set_solid.
func set_wall(cell: Vector2i, material: StringName = &"") -> void:
	if not in_bounds(cell):
		return
	if material == &"":
		wall.erase(cell)
	else:
		wall[cell] = material
	terrain_dirty.append(cell)


## Ingest a generated world: replace terrain with the WorldData's grids. Only in-bounds cells are
## taken. The avatar and machines are unaffected; this is the start-of-world seeding step.
func load_world(world: WorldData) -> void:
	solid.clear()
	wall.clear()
	deposits.clear()
	lode.clear()
	lode_max.clear()
	water.clear()
	fill.clear()                       # a fresh world has no construction in it
	world_seed = world.seed
	for cell: Vector2i in world.blocks:
		if in_bounds(cell):
			solid[cell] = world.blocks[cell]
	for cell: Vector2i in world.walls:
		if in_bounds(cell):
			wall[cell] = world.walls[cell]
	for cell: Vector2i in world.amounts:
		if in_bounds(cell):
			deposits[cell] = int(world.amounts[cell])
	# THE LODE PLANE: ore born in the wall rather than derived from mining an ore block. Ingested AFTER
	# `amounts`, because a lode's richness IS its deposit: `lode_max`, the denominator the fleck field
	# thins against, has to read the amount actually loaded rather than the default. A generated lode has
	# never been worked, so what it holds now is what it held when it was opened.
	#
	# Ingested faithfully: bounds-checked and nothing else. A lode sharing a cell with a solid ore-like
	# block would be double-sourced; that is a generator-side invariant caught by a test, because silently
	# dropping it here would turn a generator bug into missing ore nobody can see. A lode under ordinary
	# rock is not illegal, it is the design: clear the rock to expose the vein.
	#
	# Do NOT wrap these two loops in `if world.lodes != null:` / `if world.water != null:`. `lodes` and
	# `water` are `Dictionary` (world_data.gd:43,48) and `{} != null` is TRUE in GDScript, so such a guard
	# can never be false and protects nothing. Compatibility with an older WorldData that predates either
	# grid comes from the DEFAULT: it arrives as `{}`, and iterating an empty Dictionary is a no-op.
	for cell: Vector2i in world.lodes:
		if in_bounds(cell):
			lode[cell] = world.lodes[cell]
			lode_max[cell] = maxi(1, int(deposits.get(cell, DEFAULT_ORE_DEPOSIT)))
	# Aquifers: seeded water in carved-open pockets; the generator guarantees no watered cell is solid.
	# An older WorldData has no water grid, arrives as `{}`, and falls through this loop into a dry world.
	for cell: Vector2i in world.water:
		if in_bounds(cell) and not solid.has(cell):
			water[cell] = clampi(int(world.water[cell]), 1, WATER_MAX)
	rebuild_fine_terrain()   # derive the fine grid from the freshly loaded coarse terrain (deterministic)


## Fine terrain accessors and build. The fine grid is DERIVED render/collision data, not authoritative
## logistics state: every accessor reads the flat byte array and the sim's production math never
## touches it.

func fine_w() -> int:
	return GRID_COLS * SUBDIV


func fine_h() -> int:
	return GRID_ROWS * SUBDIV


## The whole fine solid/air grid at once, for consumers that would otherwise call fine_is_solid() a
## quarter of a million times. The renderer's boot bake did exactly that and spent 1.67s on it; handing
## the array over turns that loop into a memcpy. Empty when the grid has not been built, so callers can
## fall back.
func fine_solid_bytes() -> PackedByteArray:
	if _fine_solid.size() != fine_w() * fine_h():
		return PackedByteArray()
	return _fine_solid


## Is the fine cell at (fx, fy) solid? Out of bounds reads AIR, so world edges mold as carved faces.
func fine_is_solid(fx: int, fy: int) -> bool:
	if fx < 0 or fy < 0 or fx >= fine_w() or fy >= fine_h():
		return false
	if _fine_solid.size() != fine_w() * fine_h():
		return false
	return _fine_solid[fy * fine_w() + fx] == 1


## Rebuild the ENTIRE fine terrain array from the coarse `solid` grid and deterministic fine worldgen.
## Called after load_world or a save-restore: the fine grid is not saved, it derives from `solid` and
## the seed. Deterministic in (world_seed, coords) ONLY, no time and no RNG, so two loads of the same
## world produce an identical fine array. O(fine cells); incremental edits use _sync_fine_block.
func rebuild_fine_terrain() -> void:
	FineTerrain.rebuild(self)


## The seed the fine noise fields were built for (so a reused sim rebuilds them when world_seed changes).
var _fine_seed_built: int = -0x7fffffff


## Mark a coarse terrain cell dirty: queue the chunk repaint and re-mold its fine block plus boundary
## band. The ONE place terrain edits announce a solid/wall change, so the fine grid cannot drift from
## `solid`.
func _dirty_terrain(cell: Vector2i) -> void:
	terrain_dirty.append(cell)
	FineTerrain.sync_block(self, cell)


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the cell
## was already open. Ore that enters the pack is genuinely produced from the world, so it counts toward
## total_produced. The cell's background wall is left intact: the block is carved, the wall stays.
## `keep` false PULVERISES: the block still breaks and the world still opens, but nothing enters the
## pack and nothing counts as produced, since a pulverised block was never produced at all. It is the
## Broad bit's price (`BitRules`), and the same accounting the ore vein's discarded latent yield uses.
func mine(cell: Vector2i, keep: bool = true) -> StringName:
	if not solid.has(cell):
		return &""
	_bazaars_dirty = true               # a mined block can break a bazaar frame → rescan lazily
	fill.erase(cell)                    # dug back out: it is no longer anybody's fill
	var material: StringName = solid[cell]
	if _is_ore_like(material):
		# Hand-mining an ore-like block (ore or coal) clears the whole block in one strike and pockets a 3-6
		# burst of loose ore. The block's larger latent yield in `deposits` is NOT hand-extractable: a drill
		# placed ABOVE a visible vein bores DOWN through the solid ore, draining each cell dry. The burst
		# counts as produced when it enters the pack; a discarded latent yield was never produced, so
		# conservation holds.
		var latent: int = int(deposits.get(cell, DEFAULT_ORE_DEPOSIT))
		var burst: int = mini(_ore_burst(cell) if keep else 0, latent)
		if burst > 0:
			# Through the cap. `total_produced` still counts the whole burst: what will not fit is on the
			# floor, not discarded, and `collect_ground` does not count production.
			take_into_pack(material, burst, cell)
			total_produced[material] = int(total_produced.get(material, 0)) + burst
		var left: int = latent - burst
		if left > 0:
			lode[cell] = material          # the blow OPENED the vein; the rest of it is still there to work
			deposits[cell] = left
			lode_max[cell] = left          # full for this vein: the blow is what opened it
		else:
			deposits.erase(cell)           # a thin seam the burst took whole: nothing left to open
			lode.erase(cell)
			lode_max.erase(cell)
		solid.erase(cell)
		_dirty_terrain(cell)                # repaint the chunk + re-mold the fine block now the cell is air
		_resettle_pile_above(cell)          # the floor under any resting pile just vanished: it falls
		return material
	if _is_foliage(material):
		# Foliage chops BLOCK-BY-BLOCK, never flood-felling a whole tree on one hit. Wood yields one wood
		# per block; a built structure such as the bazaar frame behaves identically, mirroring place_block's
		# consume so conservation holds. A share of leaves hide a sapling, deterministic per cell with no
		# RNG: plant it on soil and a new tree grows.
		solid.erase(cell)
		_dirty_terrain(cell)
		if not keep:
			pass                                       # pulverised: the tree still falls, the wood is dust
		elif material == &"wood":
			take_into_pack(&"wood", 1, cell)
			total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + 1
		elif material == &"leaves" and leaf_drops_sapling(cell):
			take_into_pack(&"sapling", 1, cell)
			total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
		_resettle_pile_above(cell)
		_settle_foliage(cell)          # cut the base/trunk → the rest of the tree loses its root and FALLS
		return material
	# Plain terrain (earth/stone/deepslate): dig-and-carry, pocketing the block as a placeable item to
	# bridge a gap, backfill or pillar out of a hole. Produced from the world and consumed on placement in
	# place_block, so conservation holds, symmetric with mining a placed block back.
	solid.erase(cell)
	_dirty_terrain(cell)
	if keep:
		take_into_pack(material, 1, cell)
		total_produced[material] = int(total_produced.get(material, 0)) + 1
	_resettle_pile_above(cell)               # gravity: a pile that rested on this block now falls
	_settle_foliage(cell)                    # dug the earth under a tree → the whole tree loses its root
	return material


## Can a building block be placed here? The adjacency rule: yes if a wall backs the cell, or an
## orthogonal neighbour is something to build off (solid terrain, a machine, or a conduit). A dug room
## can be backfilled and a structure extended, but a block cannot go into isolated open sky. A pure
## read. The CONTROLLER gates block placement on it rather than place_block, because machines are exempt
## (a lift is legitimately placed in an open shaft) and worldgen and the harness still place freely.
func block_supported(cell: Vector2i) -> bool:
	if wall_at(cell) != &"":
		return true
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nb: Vector2i = cell + d
		if is_solid(nb) or machine_at(nb) != null or has_conduit(nb):
			return true
	return false


## Every placed layer (solid rock, a machine in `grid`, a conduit, a rope, a torch) is MUTUALLY
## EXCLUSIVE per cell: no two may share one. This is the SINGLE occupancy gate every placement checks,
## so the layers can never overlap. Per-function guards each checking a different subset let a cell
## become solid AND piped at once, corrupting state. A new placed layer adds ONE check here.
##
## Known exception: the sapling gate (`can_plant_sapling`, the guards `plant_sapling` runs on) still
## hand-rolls its own set, omitting `conduit` and adding `sapling`. So a sapling may be planted into a
## piped cell, and every placement here will bury a planted one. Closing that changes real placement
## behaviour in both directions and wants its own test.
func cell_occupied(cell: Vector2i) -> bool:
	return solid.has(cell) or grid.has(cell) or conduit.has(cell) or rope.has(cell) or torch.has(cell)


## Player action: place a building-material block from the pack into an open cell, the inverse of mine.
## Consumes one `material` from the pack and the cell becomes solid. Like crafting, the spent item counts
## as CONSUMED and mining it back counts as produced, so conservation holds across build and dig;
## terrain is not "items present". Refuses solid, occupied and out-of-bounds cells.
func place_block(cell: Vector2i, material: StringName) -> bool:
	if not in_bounds(cell) or cell_occupied(cell):
		return false          # every placed layer is mutually exclusive: clear the cell first
	if int(inventory.get(material, 0)) <= 0:
		return false
	_take_from_pack(material, 1)
	total_consumed[material] = int(total_consumed.get(material, 0)) + 1
	solid[cell] = material
	# What is stacked back is FILL, and fill is either packed or it weeps (docs/DRIFT.md §4). Gravel is
	# the one material that packs; everything else, the stone out of this gallery included, is loose.
	fill[cell] = FILL_PACKED if material == &"gravel" else FILL_LOOSE
	water.erase(cell)                   # placing rock into a watered cell displaces that cell's water
	_dirty_terrain(cell)
	_bazaars_dirty = true               # a placed block can COMPLETE a bazaar frame → rescan lazily
	return true


## Power conduits: a placed layer, not a machine. The carried &"conduit" item is crafted at the
## bazaar/forge like a machine; placing it routes here instead of into `grid` (the controller branches
## on the def's &"conduit" behavior), so conduits never enter item-flow or collision.

func has_conduit(cell: Vector2i) -> bool:
	return conduit.has(cell)


## The tier of the conduit at a cell (0 = none). One tier for now; deeper materials raise it later.
func conduit_tier(cell: Vector2i) -> int:
	return int(conduit.get(cell, 0))


## Place a carried conduit into an open cell, spending one &"conduit" from the pack like
## build_from_pack. Refuses solid, occupied, already-piped and out-of-bounds cells. Returns whether it
## went down. The spent item counts as CONSUMED and removal counts as PRODUCED, the same symmetric
## accounting as place_block/mine, so a placed layer never silently leaks the conservation invariant.
func place_conduit(cell: Vector2i) -> bool:
	if not in_bounds(cell) or cell_occupied(cell):
		return false
	if int(inventory.get(&"conduit", 0)) <= 0:
		return false
	_take_from_pack(&"conduit", 1)
	total_consumed[&"conduit"] = int(total_consumed.get(&"conduit", 0)) + 1
	conduit[cell] = 1                       # tier 1 (the only tier for now)
	return true


## Pick a placed conduit back up into the pack (mirrors pickup_machine). Returns whether one was there.
func remove_conduit(cell: Vector2i) -> bool:
	if not conduit.has(cell):
		return false
	conduit.erase(cell)
	inventory[&"conduit"] = int(inventory.get(&"conduit", 0)) + 1
	total_produced[&"conduit"] = int(total_produced.get(&"conduit", 0)) + 1
	return true


## Rope: a placed layer like the conduit, read by the avatar to climb.

func is_climbable(cell: Vector2i) -> bool:
	return rope.has(cell)


## Player action: hang a rope at `anchor` and let it unroll DOWN the open column, one carried &"rope"
## item per segment, until it hits solid ground, a machine, an existing rope or the world floor, or the
## pack runs out. One placement ropes a whole shaft, and because the anchor can be any open in-reach
## cell above, a player stranded at the bottom of their own dig aims up and the rope unrolls down to
## them. Each segment counts as CONSUMED, symmetric with remove_rope's produced. Returns the number of
## segments hung; 0 means refused, for a bad anchor or no rope.
func place_rope(anchor: Vector2i) -> int:
	var hung: int = 0
	var c: Vector2i = anchor
	while in_bounds(c) and not cell_occupied(c) and int(inventory.get(&"rope", 0)) > 0:
		_take_from_pack(&"rope", 1)
		total_consumed[&"rope"] = int(total_consumed.get(&"rope", 0)) + 1
		rope[c] = true
		hung += 1
		c += Vector2i(0, 1)
	return hung


## The topmost segment of the connected rope through `cell`: its ANCHOR end. Ropes are vertical runs.
func rope_anchor(cell: Vector2i) -> Vector2i:
	var c: Vector2i = cell
	while rope.has(c + Vector2i(0, -1)):
		c += Vector2i(0, -1)
	return c


## How many segments hang in the connected rope through `cell` (0 = no rope there).
func rope_length(cell: Vector2i) -> int:
	if not rope.has(cell):
		return 0
	var c: Vector2i = rope_anchor(cell)
	var n: int = 0
	while rope.has(c):
		n += 1
		c += Vector2i(0, 1)
	return n


## Player action: retract the whole rope through `cell`, walking up to its anchor and taking every
## segment back. One action recovers the entire hang whichever segment is aimed at; cutting to keep the
## upper half is covered by retract plus re-place. Returns segments recovered.
func retract_rope(cell: Vector2i) -> int:
	if not rope.has(cell):
		return 0
	return remove_rope(rope_anchor(cell))


## Player action: cut the rope at `cell`. A rope hangs, so cutting a segment takes that segment and
## every connected segment BELOW it, since the tail cannot float. All return to the pack as produced,
## the mirror of place_rope's consumed. Returns how many segments came back.
func remove_rope(cell: Vector2i) -> int:
	var cut: int = 0
	var c: Vector2i = cell
	while rope.has(c):
		rope.erase(c)
		inventory[&"rope"] = int(inventory.get(&"rope", 0)) + 1
		total_produced[&"rope"] = int(total_produced.get(&"rope", 0)) + 1
		cut += 1
		c += Vector2i(0, 1)
	return cut


## Torches: placeable light, another placed layer like rope and conduit. Not solid, not a machine, so
## items fall through and collision never sees it. The sim owns placement and the ledger; the pool it
## casts is representation, drawn by the renderer at torch cells.

func has_torch(cell: Vector2i) -> bool:
	return torch.has(cell)


## Mount a carried &"torch" on an open cell. Needs a backing to hang from: a wall behind the cell or any
## solid neighbour, so no torch floats in open sky. Consumed into the ledger; removal produces it back,
## so the total ledger holds.
func place_torch(cell: Vector2i) -> bool:
	if not in_bounds(cell) or cell_occupied(cell):
		return false
	if int(inventory.get(&"torch", 0)) <= 0:
		return false
	var backed: bool = wall_at(cell) != &""
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
		backed = backed or solid.has(cell + d)
	if not backed:
		return false
	_take_from_pack(&"torch", 1)
	total_consumed[&"torch"] = int(total_consumed.get(&"torch", 0)) + 1
	torch[cell] = true
	return true


## Take a mounted torch back into the pack (the mirror of place_torch).
func remove_torch(cell: Vector2i) -> bool:
	if not torch.has(cell):
		return false
	torch.erase(cell)
	inventory[&"torch"] = int(inventory.get(&"torch", 0)) + 1
	total_produced[&"torch"] = int(total_produced.get(&"torch", 0)) + 1
	return true


## Water: a discrete-cell integer fluid layer. Mirrors the other layer APIs (conduit/rope/torch): one
## read, two mutators and a conservation probe. INTEGER levels only; _flow_water, run each tick, MOVES
## water between cells and never creates or destroys it.

## The water level (0..WATER_MAX) at a cell, or 0 if none.
func water_at(cell: Vector2i) -> int:
	return int(water.get(cell, 0))


## Add up to WATER_MAX water into a cell; returns the amount ACTUALLY added, leaving the caller to
## decide what to do with the overflow. Never adds into a solid cell, since water cannot occupy rock,
## and never creates water from nothing: a 0-level cell drops out of the dict, so total_water is exact.
func add_water(cell: Vector2i, amount: int) -> int:
	if amount <= 0 or not in_bounds(cell) or solid.has(cell):
		return 0
	var here: int = int(water.get(cell, 0))
	var added: int = mini(amount, WATER_MAX - here)
	if added <= 0:
		return 0
	water[cell] = here + added
	return added


## Drain up to `amount` water from a cell; returns the amount actually removed. A cell drained to 0 is
## erased (no 0-level ghosts), so water_at/total_water read exactly.
func remove_water(cell: Vector2i, amount: int) -> int:
	if amount <= 0:
		return 0
	var here: int = int(water.get(cell, 0))
	var removed: int = mini(amount, here)
	if removed <= 0:
		return 0
	if removed >= here:
		water.erase(cell)
	else:
		water[cell] = here - removed
	return removed


## Total water in the world: the conservation probe. _flow_water is invariant in this sum per tick.
func total_water() -> int:
	var sum: int = 0
	for v: Variant in water.values():
		sum += int(v)
	return sum


## Packing and seepage (docs/DRIFT.md §4). What was stacked back is not what was always there.

## Is this cell packed fill, the watertight kind? Pure read; the renderer and the harness both use it.
func is_packed(cell: Vector2i) -> bool:
	return fill.get(cell, &"") == FILL_PACKED


## Is this cell loose fill: rock stacked back, which weeps under pressure?
func is_loose_fill(cell: Vector2i) -> bool:
	return fill.get(cell, &"") == FILL_LOOSE


## The seep step, run every SEEP_INTERVAL ticks. For each cell of LOOSE fill, a wet neighbour at or
## above SEEP_PRESSURE pushes ONE unit through to the open cell on the far side. Down first, since a
## flooded gallery over a backfilled floor is the case that matters, then the two lateral pairs.
##
## Water is MOVED, never made: the sum is invariant across this step exactly as across WaterFlow. The
## pass is deterministic (cells sorted, one unit per cell per pass) and it iterates `fill`, the built
## cells, not the world, so its cost is the size of the construction and nothing else.
func _seep_step() -> void:
	if fill.is_empty() or water.is_empty():
		return
	var cells: Array[Vector2i] = []
	for cv: Variant in fill:
		if fill[cv] == FILL_LOOSE:
			cells.append(cv)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for c: Vector2i in cells:
		for pair: Array in [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)],
				[Vector2i(1, 0), Vector2i(-1, 0)]]:
			var wet: Vector2i = c + (pair[0] as Vector2i)
			var dry: Vector2i = c + (pair[1] as Vector2i)
			if int(water.get(wet, 0)) < SEEP_PRESSURE:
				continue
			if not in_bounds(dry) or solid.has(dry):
				continue
			if int(water.get(dry, 0)) >= WATER_MAX:
				continue
			water[wet] = int(water[wet]) - 1
			if int(water[wet]) <= 0:
				water.erase(wet)
			water[dry] = int(water.get(dry, 0)) + 1
			break                                  # one unit per loose cell per pass: a weep, not a breach


## Saplings: the renewable-wood loop. Chopped canopies hide seeds; plant one on soil and the tick grows
## it into a real tree in the worldgen shape, so wood never dead-ends. A placed layer like `torch`: not
## solid, not a machine, items fall through, and the sprout is drawn by the view.

const SAPLING_GROW_TICKS: int = 2400          ## 20 Hz × 120 s: a tree in two minutes
const SAPLING_SOILS: Array[StringName] = [&"earth"]   ## what a sapling can root in

## Does chopping this LEAVES cell yield a sapling? Deterministic per cell from a stable hash, no RNG, so
## the same canopy always hides its seeds in the same corners: about one leaf in three. Public so tests
## and the mine() drop share one answer.
func leaf_drops_sapling(cell: Vector2i) -> bool:
	return ((int(cell.x) * 73856093) ^ (int(cell.y) * 19349663)) % 3 == 0


## Would a sapling go in here? The cell must be open (no solid, machine, rope or torch, and no sapling
## already), you have to be carrying one, and it must sit ON soil (SAPLING_SOILS).
##
## These are plant_sapling's own guards, lifted out rather than copied: the representation wants to ask
## the question BEFORE the click — the aim cursor knows whether the plant is on offer, and the lesson
## about planting is only an instruction where one could actually go — and a second copy of the rules is
## a second thing to keep in step with this one. The verb below is the only gate; this is what it refuses
## on, so an answer of true here and a refusal there cannot happen.
func can_plant_sapling(cell: Vector2i) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or rope.has(cell) \
			or torch.has(cell) or sapling.has(cell):
		return false
	if int(inventory.get(&"sapling", 0)) <= 0:
		return false
	return SAPLING_SOILS.has(solid.get(cell + Vector2i(0, 1), &""))


## Plant a carried &"sapling" on open ground (can_plant_sapling decides where). Consumed into the ledger;
## the eventual tree is world matter and yields produced wood when chopped, like worldgen trees, so the
## ledger stays total.
func plant_sapling(cell: Vector2i) -> bool:
	if not can_plant_sapling(cell):
		return false
	_take_from_pack(&"sapling", 1)
	total_consumed[&"sapling"] = int(total_consumed.get(&"sapling", 0)) + 1
	sapling[cell] = 0
	return true


## Take a planted sapling back into the pack, the mirror of plant_sapling. Growth so far is forfeit.
func remove_sapling(cell: Vector2i) -> bool:
	# A FULL PACK LEAVES IT PLANTED. Same rule as the lode face and for the same reason: refusing here
	# destroys nothing — the sapling stays in the ground and keeps growing — so there is no homeless
	# material needing a floor to land on, and the player loses nothing by being told to come back.
	if not can_carry(&"sapling", 1):
		return false
	if not sapling.has(cell):
		return false
	sapling.erase(cell)
	inventory[&"sapling"] = int(inventory.get(&"sapling", 0)) + 1
	total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
	return true


## The bazaar (crafting hub): detected as a structure in the world, not a machine. A bazaar is a wood
## frame with an open interior, sitting on solid ground:
##     W W W W      top beam (all wood)
##     W . . W      posts + open interior
##     W . . W      posts + open interior
##     . G G .      interior floor must be solid ground
## Active is DERIVED from the world: a valid frame is active. No persistent state, so it stays
## deterministic and node-free, and a bazaar rebuilt elsewhere just works. The open interior and the
## exact shape are what stop a plain wall or house from matching.
const BAZAAR_W: int = 4
const BAZAAR_H: int = 3

## True if a valid bazaar frame has its top-left corner at `o`. Pure read of `solid`.
func is_bazaar_at(o: Vector2i) -> bool:
	if not in_bounds(o) or not in_bounds(o + Vector2i(BAZAAR_W - 1, BAZAAR_H)):
		return false
	for dx: int in BAZAAR_W:                                   # top beam: all wood
		if solid.get(o + Vector2i(dx, 0), &"") != &"wood":
			return false
	for dy: int in range(1, BAZAAR_H):                         # posts wood, interior open
		if solid.get(o + Vector2i(0, dy), &"") != &"wood":
			return false
		if solid.get(o + Vector2i(BAZAAR_W - 1, dy), &"") != &"wood":
			return false
		for ix: int in range(1, BAZAAR_W - 1):
			if solid.has(o + Vector2i(ix, dy)):
				return false
	for ix: int in range(1, BAZAAR_W - 1):                     # interior floor: real solid ground
		var floor_cell: Vector2i = o + Vector2i(ix, BAZAAR_H)
		if not solid.has(floor_cell) or _is_foliage(solid[floor_cell]):
			return false
	return true


## All valid bazaar frames in the world (their top-left origins), in deterministic order.
## CACHED: this is a full-grid scan (~7700 cells × a 4×3 window) and the representation calls it several
## times PER FRAME, for the bazaar transform view and the near-bazaar craft gate, costing ~10ms/frame
## and a steady-state stutter. Bazaars are made of blocks, so the result changes only on a terrain edit:
## the mutators flip `_bazaars_dirty` and the rescan is lazy. O(1) amortized between digs.
var _bazaars_cache: Array[Vector2i] = []
var _ruins_cache: Array[Dictionary] = []       ## {origin, gap}: frames ONE block short (find_bazaar_ruins)
var _bazaars_dirty: bool = true
func find_bazaars() -> Array[Vector2i]:
	if _bazaars_dirty:
		_rescan_bazaars()
	return _bazaars_cache


## Frames that are exactly ONE wood block short of being a bazaar, each with the cell that is missing.
## The world stamps one near spawn as the first thing a player is asked to build
## (layered_world_gen._stamp_bazaar_ruin lays the frame minus its bottom-right post). An unfinished
## frame is not a bazaar, so this is what lets the representation draw it as a derelict stall with a
## marked gap rather than as four loose wood blocks.
##
## Same scan and same dirty flag as find_bazaars: one pass fills both caches.
func find_bazaar_ruins() -> Array[Dictionary]:
	if _bazaars_dirty:
		_rescan_bazaars()
	return _ruins_cache


func _rescan_bazaars() -> void:
	_bazaars_cache = []
	_ruins_cache = []
	for y: int in range(0, GRID_ROWS - BAZAAR_H):
		for x: int in range(0, GRID_COLS - BAZAAR_W + 1):
			var o := Vector2i(x, y)
			if is_bazaar_at(o):
				_bazaars_cache.append(o)
				continue
			var gap: Vector2i = bazaar_gap_at(o)
			if gap.x >= 0:
				_ruins_cache.append({"origin": o, "gap": gap})
	_bazaars_dirty = false


## The single missing FRAME cell at `o`, or (-1,-1) if `o` is not a one-block-short frame.
##
## Deliberately strict: everything a finished bazaar needs must already hold (interior open, interior
## floor real ground, every other frame cell wood) and the one hole must be genuinely EMPTY rather than
## occupied by stone that would have to be dug first. A positive answer therefore means "place one wood
## block here and it activates", the only claim the view may make. A complete bazaar answers (-1,-1)
## too: complete is not one-short.
func bazaar_gap_at(o: Vector2i) -> Vector2i:
	if not in_bounds(o) or not in_bounds(o + Vector2i(BAZAAR_W - 1, BAZAAR_H)):
		return Vector2i(-1, -1)
	var gap := Vector2i(-1, -1)
	for dx: int in BAZAAR_W:                                   # top beam: all wood but at most one hole
		var c: Vector2i = o + Vector2i(dx, 0)
		if solid.get(c, &"") != &"wood":
			if gap.x >= 0 or solid.has(c):                     # a second hole, or something else in the way
				return Vector2i(-1, -1)
			gap = c
	for dy: int in range(1, BAZAAR_H):
		for px: int in [0, BAZAAR_W - 1]:                      # posts: same rule
			var pc: Vector2i = o + Vector2i(px, dy)
			if solid.get(pc, &"") != &"wood":
				if gap.x >= 0 or solid.has(pc):
					return Vector2i(-1, -1)
				gap = pc
		for ix: int in range(1, BAZAAR_W - 1):                 # interior must already be open
			if solid.has(o + Vector2i(ix, dy)):
				return Vector2i(-1, -1)
	for ix: int in range(1, BAZAAR_W - 1):                     # interior floor: real solid ground
		var floor_cell: Vector2i = o + Vector2i(ix, BAZAAR_H)
		if not solid.has(floor_cell) or _is_foliage(solid[floor_cell]):
			return Vector2i(-1, -1)
	return gap


## True if `cell` is a wood frame cell (post or top beam) of a COMPLETED bazaar: the walls of the stall.
## The body passes through these, since the bazaar is a walk-through shop and not a solid box, while the
## interior FLOOR (plain ground, not a frame cell) stays solid to stand on. O(1): only wood cells can
## qualify, and a cell can belong to at most a BAZAAR_W×BAZAAR_H window of candidate origins.
func is_bazaar_frame_cell(cell: Vector2i) -> bool:
	if solid.get(cell, &"") != &"wood":
		return false
	for oy: int in range(cell.y - BAZAAR_H + 1, cell.y + 1):
		for ox: int in range(cell.x - BAZAAR_W + 1, cell.x + 1):
			if not is_bazaar_at(Vector2i(ox, oy)):
				continue
			var rx: int = cell.x - ox
			var ry: int = cell.y - oy
			if ry == 0 or rx == 0 or rx == BAZAAR_W - 1:   # top beam, or a side post
				return true
	return false


## The interior-centre cell of a bazaar at origin `o` (where the NPC stands / the "here" marker sits).
func bazaar_center(o: Vector2i) -> Vector2i:
	return o + Vector2i(BAZAAR_W / 2, BAZAAR_H - 1)


## Where to place ONE wood block to claim a near-complete bazaar: scans for a frame valid in every
## respect EXCEPT a single empty frame cell and returns that cell. Returns (-1,-1) if none is one block
## from done. Drives the objective pointer and lets a play-test claim the bazaar without hardcoding
## worldgen geometry. Pure read of `solid`.
func bazaar_completion_cell() -> Vector2i:
	for y: int in range(0, GRID_ROWS - BAZAAR_H):
		for x: int in range(0, GRID_COLS - BAZAAR_W + 1):
			var o := Vector2i(x, y)
			var cell: Vector2i = _bazaar_missing_one(o)
			if cell.x >= 0:
				return cell
	return Vector2i(-1, -1)


## If the frame at `o` would be a valid bazaar with exactly ONE empty frame cell filled with wood, return
## that cell; else (-1,-1). Mirrors is_bazaar_at's checks but tolerates a single open frame slot.
func _bazaar_missing_one(o: Vector2i) -> Vector2i:
	if not in_bounds(o) or not in_bounds(o + Vector2i(BAZAAR_W - 1, BAZAAR_H)):
		return Vector2i(-1, -1)
	var missing := Vector2i(-1, -1)
	var frame: Array[Vector2i] = []
	for dx: int in BAZAAR_W:
		frame.append(o + Vector2i(dx, 0))                      # top beam
	for dy: int in range(1, BAZAAR_H):
		frame.append(o + Vector2i(0, dy))                      # left post
		frame.append(o + Vector2i(BAZAAR_W - 1, dy))           # right post
		for ix: int in range(1, BAZAAR_W - 1):
			if solid.has(o + Vector2i(ix, dy)):
				return Vector2i(-1, -1)                         # interior must stay open
	for fc: Vector2i in frame:
		var mat: StringName = solid.get(fc, &"")
		if mat == &"wood":
			continue
		if mat == &"" and missing.x < 0:
			missing = fc                                        # the single allowed gap
		else:
			return Vector2i(-1, -1)                             # a non-wood block, or a second gap
	if missing.x < 0:
		return Vector2i(-1, -1)                                 # already complete: nothing to place
	for ix: int in range(1, BAZAAR_W - 1):                     # interior floor must be solid ground
		var floor_cell: Vector2i = o + Vector2i(ix, BAZAAR_H)
		if not solid.has(floor_cell) or _is_foliage(solid[floor_cell]):
			return Vector2i(-1, -1)
	return missing


## True if any active bazaar's interior is within `radius` cells of `cell`: the crafting gate, since
## crafting happens at the bazaar. Scans the detected frames; cheap on demand.
func near_bazaar(cell: Vector2i, radius: int) -> bool:
	for o: Vector2i in find_bazaars():
		var c: Vector2i = bazaar_center(o)
		if absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return true
	return false


## Materials that mine as a vein: a hand-burst plus a drillable wall deposit, dropping their own item.
## Ore and coal alike.
func _is_ore_like(material: StringName) -> bool:
	return material == &"ore" or material == &"coal" or material == &"iron" or material == &"rich_ore"


## The hand-mined BURST size for an ore cell: deterministic per cell from a stable hash, no RNG, so a
## given vein always drops the same amount. The actual drop is capped by the vein's richness, so a thin
## vein gives less.
func _ore_burst(cell: Vector2i) -> int:
	var h: int = (int(cell.x) * 73856093) ^ (int(cell.y) * 19349663)
	return 3 + (absi(h) % 4)   # 3..6 loose ore grabbed by hand; the rest is the drill's job


## Remaining drill-yield of the SOLID ore/coal vein at `cell`, or 0 if the cell is not ore. Read by the
## hover inspector to show a visible vein's richness. An ore cell with no explicit seed reads the
## default.
func ore_deposit_at(cell: Vector2i) -> int:
	if solid.has(cell) and _is_ore_like(solid[cell]):
		return int(deposits.get(cell, DEFAULT_ORE_DEPOSIT))
	if lode.has(cell):
		return int(deposits.get(cell, 0))
	return 0


## WHICH ore the yield at `cell` belongs to: `ore_deposit_at`'s companion, branch for branch.
##
## `deposits` is one grid shared by the solid-ore blocks and the background lode, so a caller must take
## the AMOUNT and the IDENTITY from this pair and never the identity from `material_at`. For a buried
## vein `material_at` returns the SOLID standing in front of it, which is stone; the renderer paints an
## echo's arc, pip and through-rock glow from that material's `nugget_color`, and stone's is fully
## transparent, so the vein answers with a colour that draws nothing. Held by `tools/check_scan.gd`.
##
## Returns &"" when the cell holds no yield of either kind, so `ore_deposit_at(c) > 0` and
## `deposit_material_at(c) != &""` are the same question asked twice, which the layer asserts.
func deposit_material_at(cell: Vector2i) -> StringName:
	if solid.has(cell) and _is_ore_like(solid[cell]):
		return solid[cell]
	if lode.has(cell):
		return lode[cell]
	return &""


## The ore in the background at `cell`, or &"": an EXPOSED vein to work by hand or cover with a drill
## (`docs/LODE.md` §10). A lode under a solid block still exists; it is simply behind rock.
func lode_at(cell: Vector2i) -> StringName:
	return lode.get(cell, &"")


## Is there a lode here whose face is open? The lode survives being built over, since it is background
## and covering it is not destroying it, so "there is ore here" and "it can be worked" are two different
## questions; the mining loop wants the second.
func lode_workable(cell: Vector2i) -> bool:
	return lode.has(cell) and not solid.has(cell) and int(deposits.get(cell, 0)) > 0


## Take ONE UNIT from an exposed lode: the hand verb. Deliberately one unit per call, so the vein does
## not break and nothing is cleared. Returns the item taken, or &"" if nothing here was workable.
## Realises latent world resource into production exactly as the drill does, so conservation reads the
## same either way.
func take_lode(cell: Vector2i) -> StringName:
	if not lode_workable(cell):
		return &""
	var item: StringName = lode[cell]
	# THE CAP, AND THIS VERB REFUSES WHERE `mine` SPILLS. The difference is not an inconsistency: `mine`
	# DESTROYS a block, so the material it frees has nowhere to be except the world and refusing the swing
	# would read as a broken pick. A lode face is not destroyed by being worked — it stays exactly where it
	# was — so there is no homeless material, and a full pack simply does not take the unit. That also keeps
	# the vein intact rather than letting a full player drain it onto the floor one click at a time.
	#
	# This is the ORE verb. Missed on the first pass, which capped `mine`, `collect_ground` and the foliage
	# yields and left the one path the lode migration made central writing the pack inline — so the cap bound
	# on rock and not on ore, and the pack could pass the cap by one unit per click.
	if not can_carry(item, 1):
		return &""
	var left: int = int(deposits.get(cell, 0)) - 1
	inventory[item] = int(inventory.get(item, 0)) + 1
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	if left > 0:
		deposits[cell] = left
	else:
		deposits.erase(cell)               # worked dry: the vein is spent and stops drawing as one
		lode.erase(cell)
		lode_max.erase(cell)
	terrain_dirty.append(cell)
	return item


## How much of a lode is left, as a fraction of what it held when opened: the number the renderer thins
## the fleck field by, so a worked-out vein LOOKS worked out instead of being pixel-identical to a full
## one.
func lode_fraction(cell: Vector2i) -> float:
	if not lode.has(cell):
		return 0.0
	var full: float = float(lode_max.get(cell, deposits.get(cell, 1)))
	return clampf(float(deposits.get(cell, 0)) / maxf(full, 1.0), 0.0, 1.0)


## The carried pack as an ordered list of {item, count} for the inventory hotbar. Dictionaries preserve
## insertion order, so the slot layout is stable as items are picked up. Pure read over `inventory`.
func inventory_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for item: StringName in inventory:
		slots.append({"item": item, "count": int(inventory[item])})
	return slots


## Player action: hand items from the pack into the input buffer of the machine at `cell`. Returns the
## number actually deposited, capped by what is carried. The avatar triggers this when standing in reach
## of a machine.
func deposit(cell: Vector2i, item: StringName, count: int) -> int:
	var machine: MachineState = grid.get(cell, null)
	if machine == null or count <= 0:
		return 0
	var have: int = int(inventory.get(item, 0))
	var moved: int = mini(have, count)
	if moved <= 0:
		return 0
	machine.input_buffer[item] = int(machine.input_buffer.get(item, 0)) + moved
	var left: int = have - moved
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)
	return moved


## Player action: drop items from the pack into a column. Gravity is the conveyor: items are not
## inserted into a machine, they are let go and FALL. Reuses _column_landing, so the dropped items
## cascade straight down `cell`'s column from the player's row and land in the first machine below,
## feeding its input, else on the first floor as a re-collectable ground pile, else the void sink.
## Returns how many dropped. Conservation holds: items only MOVE pack→(machine|ground|sink).
## `from_cell` is the VISUAL launch origin for the cosmetic toss, e.g. the body's cell when tossing ore
## into the next column over. It only colours the flow_event's `from`, which the sim never reads back,
## so the production landing is unaffected. The default sentinel (-1,-1) means launch from `cell`.
func drop_item(cell: Vector2i, item: StringName, count: int, from_cell: Vector2i = Vector2i(-1, -1)) -> int:
	var have: int = int(inventory.get(item, 0))
	var n: int = mini(have, count)
	if n <= 0:
		return 0
	_take_from_pack(item, n)
	var origin: Vector2i = cell if from_cell == Vector2i(-1, -1) else from_cell
	var dest: Dictionary = _column_landing(cell.x, cell.y)
	dest["target"][item] = int(dest["target"].get(item, 0)) + n
	flow_events.append({"item": item, "from": origin, "to": dest["to_cell"], "count": n})
	last_drop_landing = dest["to_cell"]     # controller graces this cell so it isn't auto-collected at once
	return n


## Player action: craft a machine item into the pack, spending its `craft_cost` from inventory. Yields
## `def.craft_count` per craft: 1 for machines, a bundle for cheap consumables such as rope.
## Research-gated: a machine still locked behind an unresearched tech refuses, because the unlock must
## first be bought at the Bazaar bench (docs/PROGRESSION.md §5).
func craft(def: MachineDef) -> bool:
	if not craft_unlocked(def.id):
		return false
	return craft_item(def.id, def.craft_cost, def.craft_count)


## Is this craftable unlocked, meaning free of a locking tech or with its tech researched?
func craft_unlocked(item_id: StringName) -> bool:
	var lock: StringName = ResearchRules.locking_tech(item_id)
	return lock == &"" or research.has(lock)


func is_researched(tech_id: StringName) -> bool:
	return research.has(tech_id)


## Player action: research a tech at the Bazaar bench; proximity is the controller's gate, like reach.
## Consumes ONE unit of the tech's signature SAMPLE material, which must already have been found, plus
## its refined-goods cost. Both are ledgered as consumed, so conservation holds and research is a real
## sink. Refuses when the tech is unknown, already researched, missing a prereq, or short of
## ingredients.
func research_tech(tech_id: StringName) -> bool:
	var t: Dictionary = ResearchRules.tech(tech_id)
	if t.is_empty() or research.has(tech_id) or not ResearchRules.prereq_met(tech_id, research):
		return false
	var sample: StringName = t.get("sample", &"")
	if sample != &"" and int(inventory.get(sample, 0)) < 1:
		return false
	var cost: Dictionary = t.get("cost", {})
	for item: StringName in cost:
		if int(inventory.get(item, 0)) < int(cost[item]):
			return false
	if sample != &"":
		_take_from_pack(sample, 1)
		total_consumed[sample] = int(total_consumed.get(sample, 0)) + 1
	for item: StringName in cost:
		var n: int = int(cost[item])
		_take_from_pack(item, n)
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	research[tech_id] = true
	return true


## The generic craft primitive: spend `cost` (item -> count) from the pack, add `count` `output` items.
## Returns true if crafted, i.e. if the ingredients were there. THE LEDGER IS TOTAL: spent items count
## as consumed and the output counts as produced, so every item id (resources, machine items, tools)
## satisfies present == produced − consumed at all times and conservation can be asserted on anything.
## The output, a machine id or a tool id, lives in the same pack as ore and ingots. One path for both
## machines (craft) and tools (MiningRules.TOOL_RECIPES), so the Bazaar screen crafts them identically.
func craft_item(output: StringName, cost: Dictionary, count: int = 1) -> bool:
	if cost.is_empty() or count <= 0:
		return false
	if not craft_unlocked(output):
		return false                # the research gate, same as machine-craft (tools with no locking tech pass)
	for item: StringName in cost:
		if int(inventory.get(item, 0)) < int(cost[item]):
			return false
	for item: StringName in cost:
		var n: int = int(cost[item])
		_take_from_pack(item, n)
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	inventory[output] = int(inventory.get(output, 0)) + count
	total_produced[output] = int(total_produced.get(output, 0)) + count
	return true


## Player action: place a carried machine, consuming one machine item (def.id) from the pack. Returns
## the MachineState, or null if none is carried or the cell is blocked. The spent item counts as
## CONSUMED, since a placed machine is not "present"; pickup_machine mirrors it back as produced, the
## same symmetric accounting as blocks and conduits, so the ledger stays total.
func build_from_pack(def: MachineDef, cell: Vector2i) -> MachineState:
	if int(inventory.get(def.id, 0)) <= 0:
		return null
	var state: MachineState = place_machine(def, cell)
	if state == null:
		return null
	_take_from_pack(def.id, 1)
	total_consumed[def.id] = int(total_consumed.get(def.id, 0)) + 1
	return state


## Player action: pick a placed machine back up into the pack, as one machine item by its def.id.
## Returns true if a machine was there. Any items the machine was holding are SALVAGED into the pack
## rather than discarded, so picking up a mid-work forge never silently destroys ore: the items move
## machine→pack, both "present", so conservation holds.
func pickup_machine(cell: Vector2i) -> bool:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return false
	# THROUGH THE CAP, and this one is the largest single transfer in the game: a hopper is an unbounded
	# store, so salvaging a loaded one used to hand the player its entire contents in one call regardless of
	# what they could carry. The machine is leaving the world, so its buffer has nowhere to be except the
	# pack or the floor — spill, not refuse, on the same rule as mining.
	#
	# THE ORDER MATTERS AND THE FIRST VERSION GOT IT WRONG. Spilling while the machine was still in the grid
	# sent the overflow down its own column, where `_column_landing` found THIS MACHINE and fed the units
	# straight back into the buffer being emptied — and the `clear()` below then destroyed them. The pack
	# stayed under the cap and the ore simply ceased to exist, which is the one outcome this whole mechanism
	# is supposed to make impossible. So the contents are taken out first, the machine is removed, and only
	# then is anything spilled into a column that no longer has a machine at the top of it.
	var salvaged: Dictionary = {}
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			salvaged[item] = int(salvaged.get(item, 0)) + int(buffer[item])
		buffer.clear()   # salvaged out either way, and cleared so remove_machine has nothing to destroy
	remove_machine(cell)
	for item: StringName in salvaged:
		take_into_pack(item, int(salvaged[item]), cell)
	inventory[state.def.id] = int(inventory.get(state.def.id, 0)) + 1
	total_produced[state.def.id] = int(total_produced.get(state.def.id, 0)) + 1  # mirrors build's consume
	return true


func _take_from_pack(item: StringName, n: int) -> void:
	var left: int = int(inventory.get(item, 0)) - n
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)


## Where a machine item's flyweight def lives, by the id/filename convention `SaveGame` reloads saved
## machines through. The directory is the one authority on what a machine item is.
const MACHINE_DEF_DIR: String = "res://src/data/machines/"
## Memo for `is_bulk_item`: item -> bool. A pure function of the static tables and the def directory, so
## it is a cache and never state: not saved, not ticked, and clearing it changes no answer.
var _bulk_class: Dictionary = {}


## Is this item BULK freight, the class `PACK_BULK_CAP` counts? Ore, coal, rock, ingots, plates, gears
## and saplings are; tools, bits and machine items are not.
##
## DERIVED FROM THE EXEMPT SIDE, and that direction is the point. Gear is whatever `MiningRules` calls a
## tool (its TOOLS table plus `BitRules.BITS`); a machine item is whatever id resolves to a def under
## MACHINE_DEF_DIR. Everything else is bulk, so a material added tomorrow is capped by default and cannot
## be left off a list. The two exempt sets are the same tables the craft screen and the save file read.
func is_bulk_item(item: StringName) -> bool:
	if _bulk_class.has(item):
		return bool(_bulk_class[item])
	var bulk: bool = true
	if MiningRules.is_tool_item(item):
		bulk = false                # equipment: picks, the scanner, the bits
	elif ResourceLoader.exists(MACHINE_DEF_DIR + String(item) + ".tres"):
		bulk = false                # a placeable machine, conduit, rope or torch
	_bulk_class[item] = bulk
	return bulk


## How much BULK the pack holds right now, the number measured against `PACK_BULK_CAP`.
func carried_bulk() -> int:
	var total: int = 0
	for item: StringName in inventory:
		if is_bulk_item(item):
			total += int(inventory[item])
	return total


## Bulk units the pack still has room for, 0 when it is full. Clamped at 0 so a pack the uncapped sim
## paths overfilled reads as "no room" rather than as a negative every caller has to remember to clamp.
func pack_room() -> int:
	return maxi(0, PACK_BULK_CAP - carried_bulk())


## THE PREDICATE THE PLAYER VERB ASKS. Would taking `n` of `item` leave the pack within the cap?
## Gear and machine items always fit: the cap is on freight, not on the kit. `n` at or below zero always
## fits, because taking nothing cannot overfill anything.
func can_carry(item: StringName, n: int) -> bool:
	if n <= 0 or not is_bulk_item(item):
		return true
	return carried_bulk() + n <= PACK_BULK_CAP


## THE ONE DOOR INTO THE PACK for anything the cap counts, and the reason the cap did nothing until now.
## `PACK_BULK_CAP`, `is_bulk_item`, `carried_bulk`, `pack_room` and `can_carry` have all existed and been
## tested for weeks, and NO live path called any of them: every yield site wrote `inventory[x] =
## inventory.get(x, 0) + n` inline, twelve of them, so there was no seam to enforce a cap at. That is why
## the designed pain never reached the player — not a missing rule, a missing place to put it.
##
## THE RULE, stated once here rather than at each call site. A full pack does not refuse the swing: the
## block still breaks, the world still gives up its material, and whatever will not fit FALLS instead of
## vanishing. Refusing the dig would make a full pack feel like a broken control, and destroying the excess
## would break the conservation this file argues for everywhere else. Spilling makes the cost a TRIP —
## which is the pain the cap exists to create — while leaving every unit recoverable.
##
## Returns how many units actually entered the pack. Callers that record `total_produced` should keep
## counting the FULL amount: material on the floor was still extracted from the world, and `collect_ground`
## does not count production, so nothing is double-counted when it is picked back up.
func take_into_pack(item: StringName, n: int, spill_at: Vector2i) -> int:
	if n <= 0:
		return 0
	# Gear and machine items are never capped, so they take the whole amount without consulting room.
	var taken: int = n if not is_bulk_item(item) else mini(n, pack_room())
	if taken > 0:
		inventory[item] = int(inventory.get(item, 0)) + taken
	var rest: int = n - taken
	if rest > 0:
		_spill_to_world(spill_at, item, rest)
	return taken


## The overflow half of `take_into_pack`. This is `drop_item`'s tail with the pack half removed: the units
## never entered the pack, so there is nothing to take out of it, but they land exactly the way dropped
## items land — down the column, into the first machine below, else a re-collectable floor pile, else the
## sink. Sharing the landing rather than reimplementing it is what keeps a spilled unit indistinguishable
## from a dropped one to every consumer downstream.
func _spill_to_world(cell: Vector2i, item: StringName, n: int) -> void:
	var dest: Dictionary = _column_landing(cell.x, cell.y)
	dest["target"][item] = int(dest["target"].get(item, 0)) + n
	flow_events.append({"item": item, "from": cell, "to": dest["to_cell"], "count": n})
	last_drop_landing = dest["to_cell"]


## Place a machine in a cell. Returns the new MachineState, or null if out of bounds / occupied /
## inside solid earth.
func place_machine(def: MachineDef, cell: Vector2i) -> MachineState:
	if not in_bounds(cell) or cell_occupied(cell):
		return null           # every placed layer is mutually exclusive: clear the cell first
	var state: MachineState = MachineState.new(def, cell)
	grid[cell] = state
	machines.append(state)
	return state


## Remove the machine at a cell, if any. Items still in its buffers are DESTROYED with the machine and
## credited to total_consumed, so the conservation invariant present == produced - consumed holds. The
## player-facing pickup_machine SALVAGES buffers into the pack and clears them first, so it reaches here
## with empty buffers and destroys nothing; a raw remove_machine credits whatever it discards. Fuel and
## progress are not items, so they are not credited.
func remove_machine(cell: Vector2i) -> void:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			total_consumed[item] = int(total_consumed.get(item, 0)) + int(buffer[item])
	grid.erase(cell)
	machines.erase(state)


## The most whole ticks one advance() will run, so a slow frame cannot trigger a catch-up spiral: a long
## frame makes delta big, bigger still under the fast-forward clock, which queues many ticks, which take
## longer, which grows the next delta. Past the cap the excess sim-time is dropped by trimming the
## accumulator rather than chased, so the factory momentarily runs in slow motion instead of locking up.
## 6 ticks is 3× the ~2.66 ticks/frame an 8× clock needs at 60fps, so normal fast-forward is unaffected
## and only a genuine hitch reaches the cap. Determinism per tick is untouched.
const MAX_TICKS_PER_ADVANCE: int = 6

## Advance by real elapsed time, running only whole fixed ticks (deterministic, framerate-
## independent). The game loop calls this; tests call tick() directly.
func advance(delta: float) -> void:
	_tick_accumulator += delta
	var ran: int = 0
	while _tick_accumulator >= SECONDS_PER_TICK and ran < MAX_TICKS_PER_ADVANCE:
		_tick_accumulator -= SECONDS_PER_TICK
		tick()
		ran += 1
	if _tick_accumulator > SECONDS_PER_TICK:
		_tick_accumulator = 0.0        # fell behind the cap → drop the backlog, don't spiral chasing it


## One deterministic logical step: derive the power field, every machine runs (consumers read the field),
## then items fall one stage downward.
func tick() -> void:
	PowerFlow.compute(self)
	for machine: MachineState in machines:
		_run_machine(machine)
	_flow()
	WaterFlow.step(self)
	_seep_tick += 1
	if _seep_tick % SEEP_INTERVAL == 0:
		_seep_step()                      # loose backfill weeps; packed gravel holds (docs/DRIFT.md §4)
	Flora.grow(self)
	_prune_empty_ground()
	_sample_production()


## Push a total_produced snapshot into the rate ring buffer once per RATE_SAMPLE_TICKS. Hand-mined
## bursts land in total_produced too, so the rate covers income by hand as well as by machine.
func _sample_production() -> void:
	_rate_tick += 1
	if _rate_tick % RATE_SAMPLE_TICKS != 0:
		return
	_rate_samples.append({"tick": _rate_tick, "totals": total_produced.duplicate()})
	while _rate_samples.size() > RATE_WINDOW_SAMPLES:
		_rate_samples.pop_front()


## How fast `item` is being produced right now, in items PER MINUTE, measured over the sampling
## window (up to ~60s). 0.0 until a second of history exists. Pure read on the ring buffer.
func production_rate(item: StringName) -> float:
	if _rate_samples.is_empty():
		return 0.0
	var oldest: Dictionary = _rate_samples[0]
	var span_ticks: int = _rate_tick - int(oldest["tick"])
	if span_ticks < RATE_SAMPLE_TICKS:
		return 0.0
	var made: int = int(total_produced.get(item, 0)) - int((oldest["totals"] as Dictionary).get(item, 0))
	return float(made) / (float(span_ticks) * SECONDS_PER_TICK) * 60.0


## Every item with a live production rate, sorted fastest-first: [{item, rate}, ...]. The HUD's
## "making ore 8.2/min · ingot 4.1/min" summary reads this.
func production_rates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in total_produced:
		var r: float = production_rate(item)
		if r > 0.05:
			out.append({"item": item, "rate": r})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["rate"]) > float(b["rate"]))
	return out


## Factory census: every placed machine tallied by type, with a live working-count from machine_status.
## A pure read over `grid`, one MachineState per cell; no state, and it never touches the tick. Returns
## [{id, name, count, working}, ...] sorted most-numerous-first. Total machines == grid.size().
func machine_census() -> Array[Dictionary]:
	var by_id: Dictionary = {}                                 # id -> {id, name, count, working}
	for cell: Vector2i in grid:
		var m: MachineState = grid[cell]
		var id: StringName = m.def.id
		if not by_id.has(id):
			by_id[id] = {"id": id, "name": m.def.display_name, "def": m.def, "count": 0, "working": 0}
		var e: Dictionary = by_id[id]
		e["count"] = int(e["count"]) + 1
		if machine_status(m) == &"working":
			e["working"] = int(e["working"]) + 1
	var out: Array[Dictionary] = []
	for id: StringName in by_id:
		out.append(by_id[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	return out


## Factory alerts: machines that were meant to RUN but stalled, because the output has no drain
## (`blocked`) or the fuel ran dry (`no_fuel`). Grouped by (id, status); each entry carries one
## representative cell so the HUD can ping the culprit as a beacon, since the camera is body-locked and
## cannot jump. Pure read over `grid`. Starvation (`no_input`) is deliberately OUT: it usually means
## "not hooked up yet" rather than a breakdown, and would fire on every just-placed machine.
## [{id, name, def, status, count, cell}], most-numerous first.
const _ALERT_STATUSES: Array[StringName] = [&"blocked", &"no_fuel"]
func machine_problems() -> Array[Dictionary]:
	var by: Dictionary = {}                                    # "id|status" -> entry
	for cell: Vector2i in grid:
		var m: MachineState = grid[cell]
		var st: StringName = machine_status(m)
		if not _ALERT_STATUSES.has(st):
			continue
		var key: String = "%s|%s" % [m.def.id, st]
		if not by.has(key):
			by[key] = {"id": m.def.id, "name": m.def.display_name, "def": m.def,
				"status": st, "count": 0, "cell": cell}
		var e: Dictionary = by[key]
		e["count"] = int(e["count"]) + 1
	var out: Array[Dictionary] = []
	for k: String in by:
		out.append(by[k])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	return out


## Drop any ground cell whose pile emptied. `_column_landing` and `_column_rise` create a pile dict
## EAGERLY for a landing they might not fill (a splitter routing all of a tick's items one way, or a
## resettle of an empty pile), leaving an empty `{}` in `ground`. An empty pile is a phantom: it crashes
## walk-over collect on `keys()[0]` and draws a ghost guide. Conservation-neutral at 0 items and not in
## the determinism signature, so pruning is safe. Ground is small, so this is cheap.
func _prune_empty_ground() -> void:
	for cell: Variant in ground.keys():
		if (ground[cell] as Dictionary).is_empty():
			ground.erase(cell)


## Available power at a cell, from the derived field; 0.0 where none reaches. Consumers read this to
## throttle and the view tints it. Pure read, no mutation.
func power_at(cell: Vector2i) -> float:
	return float(power.get(cell, 0.0))


## THE COST RULE, in one place: the fraction of full speed a power consumer at `cell` gets, as
## clamp(available power / its demand, 0..1). 1.0 when fully supplied, proportionally less as the supply
## falls short. Supply attenuates with distance from the source, so the deep frontier, furthest from
## generation, browns out first. Every consumer routes its draw through this and nothing else.
func power_throttle(cell: Vector2i, demand: float) -> float:
	if demand <= 0.0:
		return 1.0
	return clampf(power_at(cell) / demand, 0.0, 1.0)


## Dispatch a machine's per-tick work through THE BEHAVIOR REGISTRY (_BEHAVIORS); no entry = the
## default named recipe-runner.
func _run_machine(machine: MachineState) -> void:
	var entry: Dictionary = _BEHAVIORS.get(machine.def.behavior, {})
	if entry.has("run"):
		call(entry["run"], machine)
		return
	_run_recipe(machine)


## The DEFAULT machine, a named recipe-runner: consume the recipe's inputs over its cycle time and
## produce its outputs. The only place items are created or destroyed, so conservation holds.
func _run_recipe(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	# PASS-THROUGH: every machine is a filter for what its recipe WANTS; anything else moves through to
	# the output and falls on down the column. A mixed drill stream therefore sorts itself down a machine
	# stack (the forge keeps ore, the coal pours past into the generator below), and junk can never clog
	# an input buffer. Conservation-neutral.
	for item: StringName in machine.input_buffer.keys():
		if not recipe.inputs.has(item):
			machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + int(machine.input_buffer[item])
			machine.input_buffer.erase(item)
	if not _has_inputs(machine, recipe):
		return
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	for item: StringName in recipe.inputs:
		var n: int = int(recipe.inputs[item])
		var remaining: int = int(machine.input_buffer.get(item, 0)) - n
		if remaining > 0:
			machine.input_buffer[item] = remaining
		else:
			machine.input_buffer.erase(item)  # keep buffers free of dead zero-count keys
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	for item: StringName in recipe.outputs:
		var n: int = int(recipe.outputs[item])
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + n
		total_produced[item] = int(total_produced.get(item, 0)) + n


func _has_inputs(machine: MachineState, recipe: RecipeDef) -> bool:
	for item: StringName in recipe.inputs:
		if int(machine.input_buffer.get(item, 0)) < int(recipe.inputs[item]):
			return false
	return true


## A LIFT runs no recipe: it carries items UP its column, the paid inverse of gravity. Its throughput
## is power-governed: LIFT_THROUGHPUT at the unpowered baseline, scaling up to LIFT_POWERED_THROUGHPUT
## as power reaches its cell, via the power_throttle cost rule. The rest stays a backlog. No items are
## created or destroyed. Whatever falls onto a lift is hauled up.
func _run_lift(machine: MachineState) -> void:
	machine.power_factor = power_throttle(machine.cell, LIFT_POWER_DEMAND)
	var cap: int = LIFT_THROUGHPUT + int(round(float(LIFT_POWERED_THROUGHPUT - LIFT_THROUGHPUT) * machine.power_factor))
	var moved: int = 0
	for item: StringName in machine.input_buffer.keys():
		if moved >= cap:
			break
		var take: int = mini(int(machine.input_buffer[item]), cap - moved)
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + take
		var left: int = int(machine.input_buffer[item]) - take
		if left > 0:
			machine.input_buffer[item] = left
		else:
			machine.input_buffer.erase(item)
		moved += take


## THE PUMP, the fluid sibling of the lift. It runs no recipe and moves no items: while POWERED it
## DRAINS water out of its own cell and the cells straight below it. Water fell in for free; pumping it
## back out costs power. Its drain budget this tick is round(PUMP_RATE × power_factor), where
## power_factor is the same cost rule the lift uses, power_throttle at the pump's cell. Unpowered gives
## power_factor 0, so the budget is 0 and the pump idles. The budget is spent TOP-DOWN over PUMP_REACH
## cells (own cell first, then downward), taking up to what each cell holds; a solid cell or the world
## floor ends the reach, since rock is not watered and nothing in this column lies below it. remove_water
## is an explicit accounted drain, so total_water drops, and it sits OUTSIDE _flow_water's move-only
## rule. Integer-only and clamped, so no negative levels ever appear.
func _run_pump(machine: MachineState) -> void:
	machine.power_factor = power_throttle(machine.cell, PUMP_POWER_DEMAND)
	var budget: int = int(round(float(PUMP_RATE) * machine.power_factor))
	if budget <= 0:
		return                                   # unpowered → no free drain (the cost rule, one place)
	for dy: int in range(0, PUMP_REACH):
		if budget <= 0:
			break
		var c: Vector2i = machine.cell + Vector2i(0, dy)
		if not in_bounds(c) or solid.has(c):
			break                                # rock caps the column: nothing watered lies below it
		budget -= remove_water(c, budget)        # drain up to what's left of the budget from this cell


## Pump status, mirroring _run_pump's gates: no power is idle; powered but with the reachable column
## already dry is idle, benignly; powered with water in reach is working.
func _status_pump(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, PUMP_POWER_DEMAND) <= 0.0:
		return &"idle"                           # unpowered: no power is reaching this cell
	for dy: int in range(0, PUMP_REACH):
		var c: Vector2i = machine.cell + Vector2i(0, dy)
		if not in_bounds(c) or solid.has(c):
			break
		if water_at(c) > 0:
			return &"working"                    # water in reach → draining
	return &"idle"                               # powered but dry: nothing left to pump


## A splitter runs no recipe: it moves whatever has fallen into it from its input to its output, with
## no items created or destroyed, to be divided across two columns by _flow next. That costs one tick of
## pass-through latency and keeps it deterministic and order-independent.
func _run_splitter(machine: MachineState) -> void:
	for item: StringName in machine.input_buffer:
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + int(machine.input_buffer[item])
	machine.input_buffer.clear()


## A HOPPER stockpiles what falls into it: its input_buffer IS the store, and it is unbounded. It meters
## the store back DOWN to feed a machine below with BACK-PRESSURE, releasing only while the consumer
## below is under HOPPER_FEED_CAP, so the bulk stays banked instead of overflowing the forge. With no
## consumer below it holds everything. Items only MOVE, input → output → the machine below, so
## conservation holds; the stockpile counts as present, as machine buffers do. Many drills can funnel
## here, routed together with splitters: it absorbs the burst and feeds steady.
func _run_hopper(machine: MachineState) -> void:
	if machine.input_buffer.is_empty():
		return
	# THE FILTER: a hopper keeps the first thing it tastes. The filter auto-latches on the first item it
	# banks, is shown in the hover, and R clears it to re-taste. Everything ELSE passes straight through
	# to the output and falls on down, so a chain of hoppers unzips a mixed drill stream with no
	# configuration: each keeps a different ingredient as the stream pours past.
	if machine.filter == &"":
		machine.filter = machine.input_buffer.keys()[0]     # deterministic: insertion order
	for item: StringName in machine.input_buffer.keys():
		if item == machine.filter:
			continue                                        # the banked good, metered below
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + int(machine.input_buffer[item])
		machine.input_buffer.erase(item)
	if not machine.input_buffer.has(machine.filter):
		return
	var below: MachineState = _first_machine_below(machine.cell)
	if below == null:
		return                              # nothing to feed → hold the stockpile (storage)
	var load: int = 0
	for it: StringName in below.input_buffer:
		load += int(below.input_buffer[it])
	if load >= HOPPER_FEED_CAP:
		return                              # consumer backed up → hold (back-pressure keeps the bank full)
	var moved: int = 0
	for item: StringName in machine.input_buffer.keys():
		if moved >= HOPPER_RELEASE:
			break
		var take: int = mini(int(machine.input_buffer[item]), HOPPER_RELEASE - moved)
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + take
		var left: int = int(machine.input_buffer[item]) - take
		if left > 0:
			machine.input_buffer[item] = left
		else:
			machine.input_buffer.erase(item)
		moved += take


## The descent engine runner: eat DESCENT_EATS from the input buffer toward the quota, crediting
## total_consumed as a true sink, and pass every OTHER item through to the output so it falls on down.
## The engine is a filter, never a trap. At quota it BREACHES, opening the contiguous sealrock straight
## below and keeping the walls, which leaves a carved shaft into Stonereach. With no seal below, whether
## misplaced or already breached, it eats nothing and passes everything.
func _run_descent(machine: MachineState) -> void:
	var face: Vector2i = _seal_below(machine.cell)
	for item: StringName in machine.input_buffer.keys():
		var n: int = int(machine.input_buffer[item])
		var eat: int = 0
		if item == DESCENT_EATS and face.x >= 0:
			eat = mini(n, DESCENT_QUOTA - machine.fed)
		if eat > 0:
			machine.fed += eat
			total_consumed[item] = int(total_consumed.get(item, 0)) + eat
			machine.progress = 0.5                    # a short "chewing" window the status/anim reads
		var through: int = n - eat
		if through > 0:
			machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + through
		machine.input_buffer.erase(item)
	machine.progress = maxf(0.0, machine.progress - SECONDS_PER_TICK)
	if face.x >= 0 and machine.fed >= DESCENT_QUOTA:
		var c: Vector2i = face
		while in_bounds(c) and solid.get(c, &"") == &"sealrock":
			set_solid(c, &"")                         # the BREACH: bore the shaft through the seal band
			_resettle_pile_above(c)                   # goods that rested on the seal fall on down (gravity)
			c += Vector2i(0, 1)


## Descent engine status, mirroring _run_descent's gates: quota met is idle, because the way is open;
## no seal below is blocked, meaning stand it ON the seal; chewing is working; hungry is no_input, and
## the need bubble asks for its ingots.
func _status_descent(machine: MachineState) -> StringName:
	if machine.fed >= DESCENT_QUOTA:
		return &"idle"
	if _seal_below(machine.cell).x < 0:
		return &"blocked"
	if machine.progress > 0.0 or not machine.input_buffer.is_empty():
		return &"working"
	return &"no_input"


## The first SOLID cell straight below `cell`, scanning through open air and stopped by any machine, if
## that cell is sealrock: the seal face a Descent Engine breaches. (-1,-1) when the column's first solid
## is not the seal, meaning a misplaced engine or an already-bored shaft.
func _seal_below(cell: Vector2i) -> Vector2i:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var c := Vector2i(cell.x, row)
		if grid.has(c):
			return Vector2i(-1, -1)
		if solid.has(c):
			return c if solid[c] == &"sealrock" else Vector2i(-1, -1)
	return Vector2i(-1, -1)


## The first machine straight below `cell` before any solid floor: the hopper's consumer, or null if a
## floor or nothing is below. Used for the hopper's feed and back-pressure decision.
func _first_machine_below(cell: Vector2i) -> MachineState:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var c := Vector2i(cell.x, row)
		var m: MachineState = grid.get(c, null)
		if m != null:
			return m
		if solid.has(c):
			return null                     # a floor before any machine → nothing to feed
	return null


## The ore cell a Drill at `cell` bores, scanning STRAIGHT DOWN its own column for the first solid
## ore-like block. The drill is placed in the open cell ABOVE a visible ore vein and sinks a column into
## it, eating solid ore and carving its own shaft; many drills can line the top of an ore body, each
## sinking a parallel column.
##
## It UNDERMINES: it targets the DEEPEST solid ore in the column, the one just above open space or a
## collector, so draining eats the body BOTTOM-UP and each freed unit falls free into the shaft below
## instead of being trapped under still-solid ore above it. Skips already-carved open cells, which are
## the shaft it made. STOPS at solid rock, where the body bottomed out, and at another machine below,
## which is the collection point and must not be bored into. (-1,-1) if nothing is borable. Down-only,
## on the gravity hook: the taller and richer a vein, the longer the drill runs.
func drill_target(cell: Vector2i) -> Vector2i:
	var deepest := Vector2i(-1, -1)
	for dy: int in range(0, GRID_ROWS):
		var c := Vector2i(cell.x, cell.y + dy)
		if not in_bounds(c):
			break
		if solid.has(c):
			if _is_ore_like(solid[c]):
				deepest = c            # remember it, keep scanning deeper for the true bottom of the body
			else:
				break                  # solid rock caps the column: the body bottomed out here
		elif dy > 0 and grid.has(c):
			break                      # a machine below → collection point, stop scanning
		# else: an open cell, the drill's own shaft or an air gap; keep sinking through it
	return deepest


## True when the deepest ore has nowhere to DRAIN: the cell directly below it is solid rock or the world
## floor, so a freed unit cannot fall out of the shaft and would pile against the body. The drill stalls
## and reports &"blocked" rather than mine into a dead pocket. The cell below the deepest ore is never
## ore, since it would then be the deeper target, so it is open air, a machine, or rock.
func _drill_blocked(target: Vector2i) -> bool:
	if target.x < 0:
		return false
	var below := target + Vector2i(0, 1)
	if not in_bounds(below):
		return true                    # the world floor is directly under the ore → nowhere to drop
	if grid.has(below):
		return false                   # a machine sits below → it collects the ore (a valid drain)
	return solid.has(below)            # solid rock caps it → blocked; open air → drains free


## The drill HEAD (`docs/LODE.md` §5, `docs/LODE_PLAN.md` phase 2a). A drill standing IN a cell whose
## backing is a lode draws from that lode, in place: the machine goes ON the thing it eats. Returns the
## drill's own cell when there is a lode under it with something left, else (-1,-1), in which case the
## bore-down-the-column model answers instead (the bridge in `docs/LODE_PLAN.md` §3).
##
## Deliberately NOT checked: whether the cell is solid. It cannot be, since a machine only stands in an
## open cell, and the lode is background, so "the machine is here" and "the vein is here" are compatible
## facts rather than competing ones.
##
## A Head is NOT un-made by finishing the cell under it. Its reach is the chain, not the one cell, so
## this answers with the nearest link that still holds ore: own cell first, then outward by chain
## distance. With no Spur on it that is one cell, exactly the pre-Spur behaviour.
func drill_lode_target(cell: Vector2i) -> Vector2i:
	if lode.has(cell) and int(deposits.get(cell, 0)) > 0:
		return cell
	for c: Vector2i in head_coverage(cell):
		if lode.has(c) and int(deposits.get(c, 0)) > 0:
			return c
	return Vector2i(-1, -1)


## Read-only PLACEMENT PREVIEW for a drill hovered at `cell`: what the representation draws so which ore
## the drill will bore, and where it will pour, is visible before committing. Returns the ore cells it
## would extract (its whole column, top to bottom), the DROP cell just below the deepest ore, and whether
## that drop is blocked. Empty ore_cells means it is not over any ore. Pure derivation.
func drill_preview(cell: Vector2i) -> Dictionary:
	# ON A LODE the preview is one cell and its own column: the Head works THIS face and the ore goes down
	# from here, rather than boring a column and pouring at its foot (`docs/DRIFT.md` §6).
	if lode.has(cell) and int(deposits.get(cell, 0)) > 0:
		return {
			"ore_cells": [cell] as Array[Vector2i],
			"drop_cell": cell + Vector2i(0, 1),
			"blocked": false,
		}
	var ore_cells: Array[Vector2i] = []
	for dy: int in range(0, GRID_ROWS):
		var c := Vector2i(cell.x, cell.y + dy)
		if not in_bounds(c):
			break
		if solid.has(c):
			if _is_ore_like(solid[c]):
				ore_cells.append(c)
			else:
				break                  # solid rock caps the column
		elif dy > 0 and grid.has(c):
			break                      # a machine below → collection point, stop
	var deepest: Vector2i = ore_cells[-1] if not ore_cells.is_empty() else Vector2i(-1, -1)
	return {
		"ore_cells": ore_cells,
		"drop_cell": (deepest + Vector2i(0, 1)) if deepest.x >= 0 else Vector2i(-1, -1),
		"blocked": _drill_blocked(deepest),
	}


## Total ore a drill at `cell` can still bore from its whole column: the sum of every solid ore cell's
## remaining deposit straight down until rock or a machine stops it. The hover surfaces this, so a drill
## on a fat body reads its real remaining supply.
func drill_column_remaining(cell: Vector2i) -> int:
	if lode.has(cell):
		return int(deposits.get(cell, 0))     # a Head's supply is the face it stands on, not a column
	var total: int = 0
	for dy: int in range(0, GRID_ROWS):
		var c := Vector2i(cell.x, cell.y + dy)
		if not in_bounds(c):
			break
		if solid.has(c):
			if _is_ore_like(solid[c]):
				total += int(deposits.get(c, DEFAULT_ORE_DEPOSIT))
			else:
				break                       # solid rock → the column bottoms out
		elif dy > 0 and grid.has(c):
			break                           # a machine below → collection point, stop counting
	return total


## A DRILL automates the by-hand ore mine. It bores STRAIGHT DOWN its column into the first SOLID ore
## block below it, eating through solid ore and carving its shaft as it goes, so it is placed in the open
## cell ABOVE a visible ore vein rather than on an exact cell. Each cycle it drains ONE unit and ejects
## it DOWN; when a solid ore cell's deposit empties the cell is CLEARED, the shaft deepens, and the drill
## reaches the next ore below. It stops at rock or a machine and goes quiet when the body is spent.
## Fuel-gated on coal. The ore is genuinely produced from the world into total_produced, the same
## accounting as hand-mining, and is drawn from the WORLD rather than a buffer.
func _run_drill(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	var lode_cell: Vector2i = drill_lode_target(machine.cell)
	var target: Vector2i = lode_cell if lode_cell.x >= 0 else drill_target(machine.cell)
	if target.x < 0:
		return                          # nothing borable below: idle, hold progress
	# A HEAD IS NEVER "blocked". The column drill stalls when the ore it bored has rock right under it,
	# because a freed unit would have nowhere to fall and would pile against the body it came out of. A
	# Head instead pours down its own column and, with no shaft, the ore piles at its feet, which is what
	# every other item does when it lands and is a state that reads and is fixed by digging
	# (`docs/DRIFT.md` §5).
	if lode_cell.x < 0 and _drill_blocked(target):
		return                          # ore has no drain below: stall, and the status reads "blocked"
	# FUEL: the drill burns COAL to run, so automating ore creates demand for coal. Burn one tick of the
	# current coal; when it is spent, refuel from the coal in its input buffer. With no fuel and no coal
	# the drill goes quiet, idle and holding progress, until more coal is fed to it.
	if machine.fuel <= 0:
		if int(machine.input_buffer.get(&"coal", 0)) > 0:
			var left: int = int(machine.input_buffer[&"coal"]) - 1
			if left > 0:
				machine.input_buffer[&"coal"] = left
			else:
				machine.input_buffer.erase(&"coal")
			total_consumed[&"coal"] = int(total_consumed.get(&"coal", 0)) + 1
			machine.fuel = DRILL_FUEL_TICKS
		else:
			return                      # out of fuel, no coal → idle ("feed me coal")
	# FUEL SCALES WITH REACH. A Head with Spurs on it takes a unit out of every covered cell per cycle, so
	# it burns coal per cell too: coverage scales output and cost together and leaves the MACHINE COUNT
	# flat, which is the only one of the three that costs the player attention. Free reach would make a
	# Spur strictly better than not placing one.
	var mouths: int = _live_mouths(machine.cell) if lode_cell.x >= 0 else 1
	machine.fuel -= mouths
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	# A HEAD ON A LODE drains the vein in place and clears nothing: the same one-unit-per-cycle rate, off
	# the same pool the hand pulls from, poured down the same column. When it runs dry the vein is gone and
	# the machine reports &"spent"; the machine itself is untouched and can be picked up and moved.
	if lode_cell.x >= 0:
		# ONE COLUMN, ONE DRAIN. Every covered cell gives up a unit and ALL of it pours out of the Head's
		# own column, never each Spur's. Extraction is lateral; logistics stays gravity-vertical, so a Spur
		# is the Head reaching sideways and never a conveyor. It is also what makes reach worth building: cut
		# wide across the vein and still manage one drop.
		var pulled: int = 0
		for c: Vector2i in head_coverage(machine.cell):
			if not lode.has(c) or int(deposits.get(c, 0)) <= 0:
				continue                                      # a worked-out link; the chain past it still runs
			var vein: StringName = lode[c]
			var rest: int = int(deposits.get(c, 0)) - 1
			if rest > 0:
				deposits[c] = rest
			else:
				deposits.erase(c)
				lode.erase(c)
				lode_max.erase(c)
			terrain_dirty.append(c)                           # the fleck field thins on this
			pulled += 1
			total_produced[vein] = int(total_produced.get(vein, 0)) + 1
			var vdest: Dictionary = _column_landing(machine.cell.x, machine.cell.y + 1)
			vdest["target"][vein] = int(vdest["target"].get(vein, 0)) + 1
			flow_events.append({"item": vein, "from": c, "to": vdest["to_cell"], "count": 1})
		machine.fed += pulled                                 # what this Head has pulled; how `spent` is known
		return
	# Drain one unit from the target solid ore cell, which is CLEARED when its deposit empties, carving
	# the shaft. The freed material is produced and ejected DOWN.
	var item: StringName = solid[target]                      # the solid ore block the drill bores into
	var amt: int = int(deposits.get(target, DEFAULT_ORE_DEPOSIT)) - 1
	if amt > 0:
		deposits[target] = amt
	else:
		deposits.erase(target)
		solid.erase(target)                                   # cell bored out → the shaft deepens
		fill.erase(target)
		_dirty_terrain(target)                                # repaint the chunk + re-mold the fine block
		_bazaars_dirty = true                                 # solid changed → invalidate the bazaar cache
		_resettle_pile_above(target)                          # gravity: anything resting above now falls
	# Eject the freed material DOWN from the bored cell, still the drill's own column, where gravity
	# carries it to a hopper, forge or collection point. `from` is the bored cell, so the falling-item
	# visual pours from the vein.
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	var dest: Dictionary = _column_landing(target.x, target.y + 1)
	dest["target"][item] = int(dest["target"].get(item, 0)) + 1
	flow_events.append({"item": item, "from": target, "to": dest["to_cell"], "count": 1})


## The next solid cell the borer at `cell` (facing ±1) would chew: scan its row from the face outward to
## H_DRILL_RANGE, skipping the open cells of the gallery it already carved. (-1,-1) means nothing borable
## in range: the gallery is spent, another machine walls it, the rock is too hard for its bit, or the
## world edge is reached. Pure read, shared by the hover, the placement preview and the runner.
func h_drill_target(cell: Vector2i, facing: int) -> Vector2i:
	for k: int in range(1, H_DRILL_RANGE + 1):
		var c := Vector2i(cell.x + facing * k, cell.y)
		if not in_bounds(c) or grid.has(c):
			return Vector2i(-1, -1)
		if not solid.has(c):
			continue                                     # already carved: reach deeper
		if MiningRules.required_tier(solid[c]) > H_DRILL_TIER:
			return Vector2i(-1, -1)                      # too hard for the bit: the gallery ends here
		return c
	return Vector2i(-1, -1)


## Would one more `item` overflow the borer's belly? Full means at H_DRILL_BELLY_TOTAL, or already
## holding H_DRILL_BELLY_STACKS distinct stacks with this item starting another.
func _h_belly_full(machine: MachineState, item: StringName) -> bool:
	var total: int = 0
	for it: StringName in machine.output_buffer:
		total += int(machine.output_buffer[it])
	if total >= H_DRILL_BELLY_TOTAL:
		return true
	return machine.output_buffer.size() >= H_DRILL_BELLY_STACKS and not machine.output_buffer.has(item)


## The horizontal drill: a coal-hungry sideways borer. Each cycle it bites the next solid cell along its
## facing; ore-like cells drain one unit per bite, so a rich vein takes many, and plain rock clears in
## one bite yielding its block-item. Bored COAL feeds its OWN fuel bunker first, so it is self-sustaining
## while the seam lasts; everything else fills the belly. The on-hook rule lives in
## _destinations_h_drill: the haul exits DOWN its own column only, and with no drain below the belly
## pools until it stalls as `blocked`. Extraction is lateral; logistics stays gravity-vertical.
func _run_h_drill(machine: MachineState) -> void:
	var target: Vector2i = h_drill_target(machine.cell, machine.facing)
	if target.x < 0:
		return                                           # gallery spent: carry it to a new face (no_input)
	var item: StringName = solid[target]
	var to_bunker: bool = item == &"coal" and int(machine.input_buffer.get(&"coal", 0)) < H_DRILL_COAL_STOCK
	if not to_bunker and _h_belly_full(machine, item):
		return                                           # belly full, no drain taking it: stall (blocked)
	if machine.fuel <= 0:                                # the drill's coal-burn pattern, hungrier
		if int(machine.input_buffer.get(&"coal", 0)) > 0:
			var left: int = int(machine.input_buffer[&"coal"]) - 1
			if left > 0:
				machine.input_buffer[&"coal"] = left
			else:
				machine.input_buffer.erase(&"coal")
			total_consumed[&"coal"] = int(total_consumed.get(&"coal", 0)) + 1
			machine.fuel = H_DRILL_FUEL_TICKS
		else:
			return                                       # dark until coal lands on it (no_fuel)
	machine.fuel -= 1
	machine.progress += SECONDS_PER_TICK
	if machine.progress < H_DRILL_CYCLE:
		return
	machine.progress -= H_DRILL_CYCLE
	# THE BITE: ore-like cells drain unit by unit and are cleared when the pool empties; plain rock clears
	# in one bite yielding its block-item, so bored earth and stone feed block-building.
	if _is_ore_like(item):
		var amt: int = int(deposits.get(target, DEFAULT_ORE_DEPOSIT)) - 1
		if amt > 0:
			deposits[target] = amt
		else:
			deposits.erase(target)
			solid.erase(target)
			fill.erase(target)
			_dirty_terrain(target)
			_bazaars_dirty = true
			_resettle_pile_above(target)
	else:
		solid.erase(target)
		fill.erase(target)
		_dirty_terrain(target)
		_bazaars_dirty = true
		_resettle_pile_above(target)
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	if to_bunker:
		machine.input_buffer[&"coal"] = int(machine.input_buffer.get(&"coal", 0)) + 1
	else:
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + 1
	flow_events.append({"item": item, "from": target, "to": machine.cell, "count": 1})


## Borer status, mirroring _run_h_drill's gates exactly so the two cannot drift.
func _status_h_drill(machine: MachineState) -> StringName:
	var target: Vector2i = h_drill_target(machine.cell, machine.facing)
	if target.x < 0:
		return &"no_input"                               # gallery spent: move it
	var item: StringName = solid[target]
	var to_bunker: bool = item == &"coal" and int(machine.input_buffer.get(&"coal", 0)) < H_DRILL_COAL_STOCK
	if not to_bunker and _h_belly_full(machine, item):
		return &"blocked"                                # empty it, or dig a drain below
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## Borer routing, THE ON-HOOK RULE: its haul drops straight down its OWN column, and only when a drain
## exists, meaning the cell directly below is open air or a machine. Sitting sealed on solid rock the
## belly POOLS, conjuring no pile inside the tunnel floor, until the drop-shaft under it is dug.
func _destinations_h_drill(machine: MachineState) -> Array[Dictionary]:
	var below := machine.cell + Vector2i(0, 1)
	if solid.has(below) and not grid.has(below):
		return []
	return [_column_landing(machine.cell.x, machine.cell.y + 1)]


## THE DRIFT RIG'S FACE: the next COLUMN with something to cut, returned as the rig's own row. It cuts
## two cells at once, its row and the row above, so the gallery it leaves is walkable. Scans outward
## along the facing, skipping columns it has already cleared. (-1,-1) means nothing is left in range: the
## gallery is spent, a machine walls it, the rock is over its tier, or the world ends. Pure read, shared
## by the hover, the placement preview and the runner.
func drift_target(cell: Vector2i, facing: int) -> Vector2i:
	for k: int in range(1, DRIFT_RANGE + 1):
		var lo := Vector2i(cell.x + facing * k, cell.y)
		var hi := lo + Vector2i(0, -1)
		if not in_bounds(lo) or not in_bounds(hi) or grid.has(lo) or grid.has(hi):
			return Vector2i(-1, -1)
		var has_lo: bool = solid.has(lo)
		var has_hi: bool = solid.has(hi)
		if not has_lo and not has_hi:
			continue                                     # already cut: reach deeper into its own gallery
		if has_lo and MiningRules.required_tier(solid[lo]) > DRIFT_TIER:
			return Vector2i(-1, -1)                      # over-tier rock ends the drift, same as the Borer
		if has_hi and MiningRules.required_tier(solid[hi]) > DRIFT_TIER:
			return Vector2i(-1, -1)
		return lo
	return Vector2i(-1, -1)


## Which belly a material goes to. `_is_ore_like` already draws the line the whole game uses: ore, coal,
## iron and rich ore are PAY; earth, stone, shale and the rest are SPOIL. The rig acts on that existing
## class rather than inventing one (docs/DRIFT.md §4).
func drift_is_pay(material: StringName) -> bool:
	return _is_ore_like(material)


func _drift_belly_full(buffer: Dictionary) -> bool:
	var total: int = 0
	for it: StringName in buffer:
		total += int(buffer[it])
	return total >= DRIFT_BELLY


## THE DRIFT RIG. Each cycle it takes ONE cell of the two-cell face, the lower first then the upper, and
## files it by class: pay into `output_buffer`, spoil into `spoil_buffer`. Its speed is power-governed
## through the one cost rule, `power_throttle`: fully supplied it bites every DRIFT_CYCLE seconds, half
## supplied it takes twice as long, unpowered it does nothing at all. It burns no coal; its constraint is
## a network to build rather than fuel to carry, which is what separates it from the Borer.
##
## A stream whose belly is full stalls THAT STREAM ONLY. The rig keeps cutting as long as the cell it is
## about to take has somewhere to go, so a jammed spoil column does not stop ore coming out of a vein; it
## only means the gallery stops advancing once the rock in front of it is rock.
func _run_drift(machine: MachineState) -> void:
	machine.power_factor = power_throttle(machine.cell, DRIFT_POWER_DEMAND)
	if machine.power_factor <= 0.0:
		return                                           # dark: idle, and the status says "no power"
	var target: Vector2i = drift_target(machine.cell, machine.facing)
	if target.x < 0:
		return                                           # gallery spent: carry it to a new face
	var bite: Vector2i = target if solid.has(target) else target + Vector2i(0, -1)
	var item: StringName = solid[bite]
	if _drift_belly_full(machine.spoil_buffer if not drift_is_pay(item) else machine.output_buffer):
		return                                           # that stream is jammed; the status names which
	machine.progress += SECONDS_PER_TICK * machine.power_factor
	if machine.progress < DRIFT_CYCLE:
		return
	machine.progress -= DRIFT_CYCLE
	# THE BITE, the Borer's rule exactly: ore-like cells drain unit by unit, so a rich vein takes many
	# bites, and plain rock clears in one and yields its block-item. Nothing is deleted.
	if _is_ore_like(item):
		var amt: int = int(deposits.get(bite, DEFAULT_ORE_DEPOSIT)) - 1
		if amt > 0:
			deposits[bite] = amt
		else:
			deposits.erase(bite)
			solid.erase(bite)
			fill.erase(bite)
			_dirty_terrain(bite)
			_bazaars_dirty = true
			_resettle_pile_above(bite)
	else:
		solid.erase(bite)
		fill.erase(bite)
		_dirty_terrain(bite)
		_bazaars_dirty = true
		_resettle_pile_above(bite)
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	if drift_is_pay(item):
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + 1
	else:
		machine.spoil_buffer[item] = int(machine.spoil_buffer.get(item, 0)) + 1
	flow_events.append({"item": item, "from": bite, "to": machine.cell, "count": 1})


## Drift Rig status, mirroring _run_drift's gates in the same order. `no_power` means the machine is
## dark; the two BLOCKED variants exist because "output blocked" says nothing on a machine with two
## outputs.
func _status_drift(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, DRIFT_POWER_DEMAND) <= 0.0:
		return &"no_power"
	var target: Vector2i = drift_target(machine.cell, machine.facing)
	if target.x < 0:
		return &"no_input"                               # gallery spent: move it
	# A FULL BELLY IS REPORTED THE MOMENT IT IS FULL, not only when the next bite would go into it. This
	# is the one place the status deliberately says MORE than the stall gate does: the rig can be mid-vein
	# cutting ore happily with its spoil column dead behind it, where "working" would be true and useless.
	# A jam needs a drain dug, so the sooner it is named the better.
	if _drift_belly_full(machine.output_buffer):
		return &"blocked_pay"
	if _drift_belly_full(machine.spoil_buffer):
		return &"blocked_spoil"
	return &"working"


## THE TWO COLUMNS. Destination 0 is PAY: straight down the rig's own column. Destination 1 is SPOIL:
## straight down the column immediately BEHIND it, the mouth of the gallery, which is already dug.
##
## Each is gated separately on having a drain: a column whose next cell down is solid rock and not a
## machine takes nothing, and that stream pools in its belly instead. NEITHER STREAM EVER MOVES
## SIDEWAYS.
func _destinations_drift(machine: MachineState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for col: int in [machine.cell.x, machine.cell.x - machine.facing]:
		var below := Vector2i(col, machine.cell.y + 1)
		if not in_bounds(below) or (solid.has(below) and not grid.has(below)):
			out.append({})                               # no drain under this column: that stream pools
		else:
			out.append(_column_landing(col, machine.cell.y + 1))
	return out


## The rig's own delivery. The default multi-destination path DEALS items round-robin, which is the
## splitter's job and wrong here, because the rig's two columns mean two different THINGS: pay goes down
## one and spoil down the other, by class, with no cross-contamination.
func _flow_drift(machine: MachineState) -> void:
	var dests: Array[Dictionary] = _destinations_drift(machine)
	if dests.size() < 2:
		return
	if not machine.output_buffer.is_empty() and not dests[0].is_empty():
		_deliver(machine, dests[0], machine.output_buffer)
		machine.output_buffer.clear()
	if not machine.spoil_buffer.is_empty() and not dests[1].is_empty():
		_deliver(machine, dests[1], machine.spoil_buffer)
		machine.spoil_buffer.clear()


## Is this item SPOIL, the class the Crusher eats? Everything `_is_ore_like` says no to that is not a
## manufactured good: earth, stone, deepslate, gravel's own feedstock. One predicate, because spoil is a
## CLASS and not a new item (docs/DRIFT.md §4). Gravel itself is excluded: crushing gravel into gravel
## would be a loop with a machine in it.
func is_spoil(item: StringName) -> bool:
	return item in [&"earth", &"stone", &"deepslate", &"shale"]


## THE CRUSHER (docs/DRIFT.md §4). Two units of spoil, any mix of them, become one of GRAVEL, the only
## material that packs. Powered, like everything on this rung: unpowered it does nothing and says so.
##
## PAY IS NEVER CRUSHED. Ore-like items in the input fall straight through to the output and carry on
## down the column, so a crusher parked under a mixed stream is a filter that costs nothing: under the
## Drift Rig's SPOIL column it is pure gain, and under a mixed Borer stream the ore still reaches the
## forge.
func _run_crush(machine: MachineState) -> void:
	# Pass-through first, so pay never waits behind rock: anything that isn't spoil leaves immediately.
	for item: StringName in machine.input_buffer.keys():
		if not is_spoil(item):
			machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) \
				+ int(machine.input_buffer[item])
			machine.input_buffer.erase(item)
	machine.power_factor = power_throttle(machine.cell, CRUSH_POWER_DEMAND)
	if machine.power_factor <= 0.0:
		return
	if _spoil_held(machine) < CRUSH_RATIO:
		return
	if int(machine.output_buffer.get(&"gravel", 0)) >= CRUSH_BELLY:
		return
	machine.progress += SECONDS_PER_TICK * machine.power_factor
	if machine.progress < CRUSH_CYCLE:
		return
	machine.progress -= CRUSH_CYCLE
	var taken: int = 0
	for item: StringName in machine.input_buffer.keys():
		if not is_spoil(item):
			continue
		while taken < CRUSH_RATIO and int(machine.input_buffer[item]) > 0:
			machine.input_buffer[item] = int(machine.input_buffer[item]) - 1
			total_consumed[item] = int(total_consumed.get(item, 0)) + 1
			taken += 1
		if int(machine.input_buffer[item]) <= 0:
			machine.input_buffer.erase(item)
		if taken >= CRUSH_RATIO:
			break
	machine.output_buffer[&"gravel"] = int(machine.output_buffer.get(&"gravel", 0)) + 1
	total_produced[&"gravel"] = int(total_produced.get(&"gravel", 0)) + 1


## How much SPOIL a crusher is holding, and only spoil: the number its cycle and its status both gate on.
func _spoil_held(machine: MachineState) -> int:
	var total: int = 0
	for item: StringName in machine.input_buffer:
		if is_spoil(item):
			total += int(machine.input_buffer[item])
	return total


## Crusher status, mirroring _run_crush's gates in the same order. A crusher holding nothing but ore
## says `no_input`, correctly: it has no spoil, and the ore it holds is already on its way out.
func _status_crush(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, CRUSH_POWER_DEMAND) <= 0.0:
		return &"no_power"
	if _spoil_held(machine) < CRUSH_RATIO:
		return &"no_input"
	if int(machine.output_buffer.get(&"gravel", 0)) >= CRUSH_BELLY:
		return &"blocked"
	return &"working"


## A GENERATOR burns coal to pour power. Each tick it spends one tick of its current fuel; when that
## runs out it consumes one coal from its input buffer to reburn for GENERATOR_FUEL_TICKS. With no fuel
## left and no coal it goes dark: fuel stays 0, so _compute_power emits nothing for it. Coal is genuinely
## consumed into total_consumed, so conservation holds. The power it makes is NOT an item; it is the
## derived field, which _compute_power reads from this machine's fuel > 0 state at the top of the next
## tick.
func _run_generator(machine: MachineState) -> void:
	if machine.fuel > 0:
		machine.fuel -= 1
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) > 0:
		var left: int = int(machine.input_buffer[&"coal"]) - 1
		if left > 0:
			machine.input_buffer[&"coal"] = left
		else:
			machine.input_buffer.erase(&"coal")
		total_consumed[&"coal"] = int(total_consumed.get(&"coal", 0)) + 1
		machine.fuel = GENERATOR_FUEL_TICKS


## Gravity and routing: each machine's output is handed to its destinations. An ordinary machine has ONE
## destination, straight down its column. A splitter has TWO, straight down and down the column to its
## right, and divides its output evenly between them, alternating item by item so odd counts split
## fairly over time. Items are only moved here, never created or destroyed.
func _flow() -> void:
	for machine: MachineState in machines:
		# A machine whose outputs mean DIFFERENT THINGS routes them itself, such as the Drift Rig's pay and
		# spoil columns. The default path below deals items round-robin, which is the splitter's job and
		# wrong for a machine that sorted at the face.
		var entry: Dictionary = _BEHAVIORS.get(machine.def.behavior, {})
		if entry.has("flow"):
			call(entry["flow"], machine)
			continue
		if machine.output_buffer.is_empty():
			continue
		var dests: Array[Dictionary] = _destinations(machine)
		if dests.is_empty():
			continue                # no drain (a borer on solid rock): the haul POOLS in its belly
		if dests.size() == 1:
			_deliver(machine, dests[0], machine.output_buffer)
		else:
			# Split: deal each item unit along the machine's deal PATTERN via route_toggle. An even
			# round-robin by default; the splitter's R-cycled ratio mode weights it.
			var n: int = dests.size()
			var pattern: Array = _split_pattern(machine, n)
			var portions: Array[Dictionary] = []
			for _i: int in n:
				portions.append({})
			for item: StringName in machine.output_buffer:
				for _c: int in int(machine.output_buffer[item]):
					var idx: int = int(pattern[machine.route_toggle % pattern.size()])
					machine.route_toggle += 1
					portions[idx][item] = int(portions[idx].get(item, 0)) + 1
			for i: int in n:
				if not portions[i].is_empty():
					_deliver(machine, dests[i], portions[i])
		machine.output_buffer.clear()


## The splitter's three R-cycled ratios: even, favour DOWN 2:1, favour RIGHT 1:2. (Dest 0 = down.)
const _SPLIT_PATTERNS: Array = [[0, 1], [0, 0, 1], [0, 1, 1]]


## The deal pattern for a multi-destination machine: which destination each successive unit takes.
## The splitter reads its configured ratio; anything else deals evenly across its destinations.
func _split_pattern(machine: MachineState, n: int) -> Array:
	if machine.def.behavior == &"splitter" and n == 2:
		return _SPLIT_PATTERNS[machine.mode % _SPLIT_PATTERNS.size()]
	return range(n)


## Player action (R aimed at a machine): cycle its configuration, meaning the splitter's ratio or a
## hopper's filter reset, which clears the filter so it re-latches on the next item it banks. Returns a
## short label of the new state for the HUD toast, or "" when the machine has nothing to configure.
## Discrete and ledger-free.
func configure_machine(cell: Vector2i) -> String:
	var m: MachineState = grid.get(cell, null)
	if m == null:
		return ""
	match m.def.behavior:
		&"splitter":
			return set_split_mode(cell, (m.mode + 1) % _SPLIT_PATTERNS.size())
		&"hopper":
			m.filter = &""
			return "hopper: filter cleared — it keeps the next thing it tastes"
	return ""


## Set a splitter's ratio DIRECTLY, for the config panel's clickable chips; R still cycles through
## configure_machine above. A discrete call like every player mutation. "" means not a splitter.
func set_split_mode(cell: Vector2i, mode: int) -> String:
	var m: MachineState = grid.get(cell, null)
	if m == null or m.def.behavior != &"splitter":
		return ""
	m.mode = clampi(mode, 0, _SPLIT_PATTERNS.size() - 1)
	return ["splitter: even 1:1", "splitter: 2:1 DOWN", "splitter: 1:2 RIGHT"][m.mode]


## Move a bundle of items from `machine` into one destination, logging the cosmetic flow event.
func _deliver(machine: MachineState, dest: Dictionary, bundle: Dictionary) -> void:
	var target: Dictionary = dest["target"]
	var to_cell: Vector2i = dest["to_cell"]
	for item: StringName in bundle:
		var count: int = int(bundle[item])
		target[item] = int(target.get(item, 0)) + count
		flow_events.append({"item": item, "from": machine.cell, "to": to_cell, "count": count})


## Where a machine's output goes. Each destination is {to_cell: Vector2i, target: Dictionary}.
## Routed through THE BEHAVIOR REGISTRY (`dests`); no entry = the default: straight down its column.
func _destinations(machine: MachineState) -> Array[Dictionary]:
	var entry: Dictionary = _BEHAVIORS.get(machine.def.behavior, {})
	if entry.has("dests"):
		var routed: Array[Dictionary] = call(entry["dests"], machine)
		return routed
	return [_column_landing(machine.cell.x, machine.cell.y + 1)]


## LIFT routing, the inverse of gravity: its output goes UP its column.
func _destinations_lift(machine: MachineState) -> Array[Dictionary]:
	return [_column_rise(machine.cell.x, machine.cell.y - 1)]


## SPLITTER routing: down, plus the column to the RIGHT. Hard against the right wall it has no second
## column and degrades to a plain pass-through, down only. Provisional edge case.
func _destinations_splitter(machine: MachineState) -> Array[Dictionary]:
	var down: Dictionary = _column_landing(machine.cell.x, machine.cell.y + 1)
	var right_col: int = machine.cell.x + 1
	if right_col >= GRID_COLS:
		return [down]
	# Diverted items move sideways into the right column at the splitter's row, then fall.
	return [down, _column_landing(right_col, machine.cell.y)]


## Where a spat product lands, scanning down `col` from `start_row`: the first machine below catches it
## as a cascade, else it rests on top of the first solid floor as a physical ground pile. A column dug
## clear to the bottom drops it into the void sink, which exists for conservation only.
func _column_landing(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, GRID_ROWS):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := _settle_on_slope(Vector2i(col, row - 1))  # roll off a surface ramp to its base
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, GRID_ROWS), "target": sink}


## An item that lands on a 45° SURFACE ramp does not perch on it: it rolls downhill to the base. Only
## the outdoor surface has ramps, since interior and cave floors are square per ramp_dir/surface_row, so
## this fires ONLY when `rest` is a column's surface top; an item resting on a dug interior floor is
## untouched. Follows the slope column by column until it reaches flat ground or a wall, guarded against
## non-descending steps and any loop.
func _settle_on_slope(rest: Vector2i) -> Vector2i:
	var guard: int = 0
	while guard < GRID_COLS:
		guard += 1
		if rest.y != surface_row(rest.x) - 1:  # not the outdoor surface top → interior floor, no roll
			break
		var d: int = ramp_dir(rest.x)           # +1 rises right, -1 rises left; downhill is the opposite
		if d == 0:
			break
		var next_col: int = rest.x - d
		if next_col < 0 or next_col >= GRID_COLS:
			break
		var ns: int = surface_row(next_col)
		var next_rest := Vector2i(next_col, ns - 1)
		if ns <= 0 or next_rest.y <= rest.y or solid.has(next_rest):
			break                               # only ever descend into an open cell
		rest = next_rest
	return rest


## Where a LIFTED item goes, scanning UP `col` from `start_row`, the mirror of _column_landing: the
## first machine above catches it and is fed, else it rests against the first ceiling as a pile just
## below the solid cell, else, in an open shaft to the top, it rests at the top row.
func _column_rise(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, -1, -1):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := Vector2i(col, row + 1)  # the open cell just below the ceiling
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, 0), "target": _ground_pile(Vector2i(col, 0))}


## The product pile resting in `cell`, created on first landing. Returned as a live Dictionary so
## _deliver adds straight into it.
func _ground_pile(cell: Vector2i) -> Dictionary:
	if not ground.has(cell):
		ground[cell] = {}
	return ground[cell]


## When the solid floor under a resting pile is removed, whether mined out, drilled, or its vein
## exhausted, the pile cannot hang in mid-air. If a pile rests directly on top of `cell`, cascade it down
## `cell`'s now-open column to the next machine or floor below and emit a flow_event so it visibly
## streams. Conservation-neutral: items only MOVE pile→(machine|lower pile|sink). Call AFTER erasing the
## cell.
func _resettle_pile_above(cell: Vector2i) -> void:
	var above := cell + Vector2i(0, -1)
	if not ground.has(above):
		return
	var pile: Dictionary = ground[above]
	ground.erase(above)
	var dest: Dictionary = _column_landing(cell.x, cell.y)
	for item: StringName in pile:
		var n: int = int(pile[item])
		if n <= 0:
			continue
		dest["target"][item] = int(dest["target"].get(item, 0)) + n
		flow_events.append({"item": item, "from": above, "to": dest["to_cell"], "count": n})
	_prune_empty_ground()   # _column_landing may have created an empty landing pile it didn't fill


## Player action: walk over a resting pile and scoop it all into the pack. Returns how many items were
## collected: the collect half of spit-out → fall → collect.
func collect_ground(cell: Vector2i) -> int:
	var pile: Dictionary = ground.get(cell, {})
	if pile.is_empty():
		return 0
	# THE CAP APPLIES TO PICKING UP TOO, and leaving it off here would have voided the whole mechanism:
	# a full pack that spills its overflow onto the floor would scoop the same units straight back on the
	# next step, so the trip would never happen and the cap would read as a cosmetic delay. What does not
	# fit STAYS in the pile rather than being lost, so the floor keeps it until there is room.
	# Keys are collected first because the pile is mutated below and a Dictionary must not be edited while
	# it is being iterated.
	var collected: int = 0
	var items: Array = pile.keys()
	for item: StringName in items:
		var want: int = int(pile[item])
		var got: int = want if not is_bulk_item(item) else mini(want, pack_room())
		if got > 0:
			inventory[item] = int(inventory.get(item, 0)) + got
			collected += got
		if got >= want:
			pile.erase(item)
		else:
			pile[item] = want - got
	if pile.is_empty():
		ground.erase(cell)
	else:
		ground[cell] = pile
	return collected
