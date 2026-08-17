class_name FactorySim
extends RefCounted

## THE SOURCE OF TRUTH. A node-free, fixed-tick, deterministic factory simulation. It could
## run headless with no scene tree (and does, in tests/test_sim.gd). The representation layer
## reads FROM this; it never writes to it. All production math lives here and nowhere else.
##
## TOPOLOGY: machines occupy cells on a grid (x = column, y = row, row increasing DOWNWARD).
## Gravity = a machine's output falls straight down its column to the next machine below; if
## none, it lands in the sink. The grid size and the "straight-down only" rule are PROVISIONAL
## (chutes / splitters / lateral routing are later slices "Spatial model").

## --- Domain-logic modules: heavy per-tick ALGORITHMS extracted from this god-object so the tick() reads
## as a list of named subsystems. Each is a STATELESS helper operating on this sim's grids — the STATE and
## the public API stay on FactorySim. Preloaded by PATH (not class_name) so the headless --script test
## drivers resolve them without a refreshed global-class cache. ---
const WaterFlow := preload("res://src/core/water_flow.gd")
const PowerFlow := preload("res://src/core/power_flow.gd")
const Flora := preload("res://src/core/flora.gd")
const FineTerrain := preload("res://src/core/fine_terrain.gd")

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)
## A larger world so a zoomed-out (3×) camera has real terrain to show and scroll through — hills,
## depth, room to explore (presentation sprint). Provisional size; real worldgen is still deferred.
const GRID_COLS: int = 128
const GRID_ROWS: int = 128
## Items/tick a LIFT carries UP its column with NO power — its hand-cranked baseline (the L1 rate, before
## power exists). Below this rate, a backlog piles at the lift. Power is what lifts it past this baseline:
## a fully-powered lift reaches LIFT_POWERED_THROUGHPUT, scaled by the power reaching its cell
## (fighting gravity UP is the canonical "costs power" case). Under-supplied, it labours back toward
## baseline = brownout. Baseline kept non-zero so the lift still works pre-power and L1 is unaffected.
const LIFT_THROUGHPUT: int = 2          ## unpowered baseline (L1), also the floor under brownout
const LIFT_POWERED_THROUGHPUT: int = 6  ## items/tick at FULL power — the governed deep-frontier rate
const LIFT_POWER_DEMAND: float = 4.0    ## power at the lift's cell for the full boost (less → proportional)
## --- THE PUMP (the L3 Aquifer answer): the flood-drain that falls on the LOCKED hook.
## Water floods DOWN into your dig for FREE (the _flow_water gravity rule); getting it back OUT costs POWER —
## exactly the lift's "down free, UP costs power" contract, cast onto fluid. A POWERED pump removes water
## from its own cell + the cells straight below it (its column, a bounded reach), a power-scaled amount per
## tick, so a flooded pocket drains over time and you RECLAIM the space for your factory. Unpowered → idle
## (does nothing — no free drain). remove_water is an explicit accounted drain (total_water drops), NOT part
## of _flow_water's move-only conservation — the pump is a legit sink, like a source would be.
const PUMP_REACH: int = 4               ## cells straight down (incl. its own) a pump can pull from this tick
const PUMP_RATE: int = 3                ## units drained per tick at FULL power (0 unpowered → the cost rule)
const PUMP_POWER_DEMAND: float = 4.0    ## power at the pump's cell for full drain rate (less → proportional)
## --- POWER (the L2 twist): power FALLS on the hook. A fueled GENERATOR burns coal and
## pours power into the cells around it (its innate aura — conduits will extend the reach down+lateral
## in a later slice); consumers draw from the field to run. The field is a DERIVED quantity recomputed
## every tick from machine placement + fuel — never stored authoritative state, exactly like updraft_at —
## so determinism is untouched and it can never desync.
const GENERATOR_POWER: float = 6.0      ## power units a fueled generator emits at its source
const GENERATOR_FUEL_TICKS: int = 100   ## ticks one coal burns (5s @20Hz) before the generator refuels
const DRILL_FUEL_TICKS: int = 60        ## ticks one coal runs a Drill (3s @20Hz) — the drill burns coal to mine

## THE HORIZONTAL DRILL / the Borer (the user's spec): bores SIDEWAYS through rock.
const H_DRILL_RANGE: int = 8            ## cells of gallery one placement can reach — move it to bore on
const H_DRILL_CYCLE: float = 1.5        ## seconds per bite (slower than the vertical drill)
const H_DRILL_FUEL_TICKS: int = 60      ## ticks one coal burns — with the slower cycle, ~2 bites/coal
                                        ## vs the vertical drill's 3 (laterality is priced in coal)
const H_DRILL_COAL_STOCK: int = 8       ## its self-feeding fuel bunker's cap (bored coal beyond it → belly)
const H_DRILL_BELLY_STACKS: int = 5     ## distinct item stacks the belly holds (the "5 slots")
const H_DRILL_BELLY_TOTAL: int = 40     ## total items across those stacks
const H_DRILL_TIER: int = 2             ## chews what a stone pick could; harder rock ends the gallery

## --- THE DRIFT RIG (docs/DRIFT.md §3) — the Borer's successor, and a change of KIND rather than a bigger
## number. Three things separate it: it cuts a 2-HIGH gallery you can walk, it SORTS pay from spoil at the
## face into two drop columns, and it eats POWER rather than coal — which is what makes it the machine that
## forces a power NETWORK instead of a fed box.
##
## DEVIATION FROM THE SPEC, recorded because it is a design finding rather than a shortcut: the spec says the
## rig "advances" instead of sitting at a fixed range. Its FACE advances — 24 cells from one placement, three
## times the Borer's reach — but the MACHINE stays put, because a machine that walks takes its two drop
## columns with it, and then every drain you dug is behind you within one cycle. Extraction may be lateral;
## logistics stays gravity-vertical, and gravity-vertical only works if the drains hold still.
const DRIFT_RANGE: int = 24             ## a gallery, not a stub
const DRIFT_CYCLE: float = 0.9          ## seconds per bite AT FULL POWER (browned out, proportionally slower)
## More than a lone generator can DELIVER anywhere. A generator pours GENERATOR_POWER at its own cell and
## its aura attenuates with distance, so the most any machine standing beside one ever reads is 4.0 — auras
## take the max, they never sum. Only a CONDUIT TRUNK sums (two feeders merging into one tube), and a tube
## bleeds 0.6 of what it carries to the machine beside it. Measured, not guessed: a lone adjacent generator
## gives this rig 0.67 speed, a two-generator trunk 0.93, a three-generator trunk full. So the rig is the
## first appetite in the game a single fed box cannot satisfy — you build a network or you run it slow, and
## it still runs, because a machine that refuses is a wall and a machine that labours is a decision.
const DRIFT_POWER_DEMAND: float = 6.0
const DRIFT_BELLY: int = 48             ## PER STREAM. Each jams on its own, and the status says which.
const DRIFT_TIER: int = 2               ## same bit as the Borer: this is a logistics upgrade, not a drive one
## --- THE CRUSHER (docs/DRIFT.md §4): spoil in, GRAVEL out. The sink that makes a gallery's ~8:1 spoil
## stream survivable, and the only source of the one material that PACKS (see the fill layer below).
## Two units of spoil — any mix of them — become one of gravel, so the stream halves as it passes through.
## Pay is never crushed: ore-like items fall STRAIGHT THROUGH to the output, because a crusher that ate the
## thing you were mining for would be a trap wearing a machine's face.
const CRUSH_CYCLE: float = 1.1          ## seconds per crush AT FULL POWER
const CRUSH_POWER_DEMAND: float = 3.0   ## a lone generator's aura (4.0) runs ONE crusher flat out
const CRUSH_RATIO: int = 2              ## units of spoil consumed per gravel produced
const CRUSH_BELLY: int = 60             ## gravel held before it jams on a sealed column
## --- PACKING (docs/DRIFT.md §4): the difference between rock you STACKED BACK and rock that was always
## there. Every hand-placed block is LOOSE fill and WEEPS — a wet cell pressing on one side pushes a unit
## through to the open side every SEEP_INTERVAL ticks. Packed gravel does not. So a gallery backfilled with
## the stone you dug out of it is a sieve, and the same gallery packed with crushed gravel is a BULKHEAD.
## Undisturbed strata never seeps: this is a property of your own construction, not a leak in the world.
const SEEP_INTERVAL: int = 12           ## ticks between weeps — a seep, not a flow
const SEEP_PRESSURE: int = 4            ## water level on the wet side before it finds a way through
const FILL_LOOSE: StringName = &"loose"
const FILL_PACKED: StringName = &"packed"
## HOPPER (storage): it STOCKPILES what falls into it (input_buffer = the store, unbounded) and meters it
## back DOWN to a machine below with BACK-PRESSURE — only feeding while the consumer's buffer is under
## FEED_CAP, so the stockpile stays in the hopper (a visible bank) instead of overflowing the forge. No
## consumer below → it just holds. The missing 'chest': drills funnel here, it buffers bursts, feeds steady.
const HOPPER_RELEASE: int = 1           ## items released downward per tick when the consumer has room
const HOPPER_FEED_CAP: int = 3          ## hold releasing once the machine below is backed up to this many
const POWER_AURA: int = 2               ## innate radius (cells) a generator powers WITHOUT any conduit
## CONDUITS carry power further than the aura — DOWN + LATERAL, never UP (a U-shape delivers as an L).
## That "no up" rule makes the network acyclic top-to-bottom, so the field resolves in a SINGLE downward
## sweep (no iterative solver). Vertical feeders SUM (merge two trunks → thicker),
## clamped by the tube's CAPACITY (tier); the clamp also bounds any branch-relattice amplification, so
## additive merge can never run away. Horizontal spread is a lossy MAX delivery (carry power across, e.g.
## the bottom of an L). Per-step keep factors set the reach a single tier covers before it fades.
const CONDUIT_CAPACITY: float = 12.0    ## max power a tier-1 tube carries (caps the additive merge)
const CONDUIT_V_KEEP: float = 0.92      ## fraction kept crossing ONE cell DOWN (sets vertical reach)
const CONDUIT_H_KEEP: float = 0.80      ## fraction kept crossing ONE cell SIDEWAYS (lateral is lossier)
const CONDUIT_BLEED: float = 0.6        ## fraction a conduit shares to adjacent cells (so machines draw it)

## --- THE BEHAVIOR REGISTRY ---------------------------------------------------------------------
## The ONE sim-side table wiring a MachineDef.behavior tag into the tick (was ~5 scattered
## if-ladders that each had to be found + extended per new machine). Entries (all optional):
##   run          — its per-tick work (method name, called with the MachineState)
##   status       — the legibility derivation machine_status() reads (MUST mirror run's gates)
##   dests        — where _flow routes its output (absent = the default: straight down its column)
##   updraft      — true: a clear open column above it is a rideable updraft (the lift)
##   power_source — true: while fueled it pours GENERATOR_POWER into the network (the generator)
## A def with no entry (empty tag) is the default named recipe-runner. Adding a machine behavior =
## its functions + ONE entry here + a Visuals.MACHINE_STYLE entry for its look — never a new ladder.
## Entries hold method NAMES (dispatched via call()), not bound Callables: a Callable bound to self
## stored on self would give every RefCounted sim a reference cycle (a leak per session/test).
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

## THE DESCENT ENGINE (the L1→L2 gate — docs/PROGRESSION.md §2): placed over THE SEAL, it EATS
## gravity-fed ingots (a true sink) and, at its quota, BREACHES the seal below — boring the shaft into
## Stonereach. The quota is a THROUGHPUT WALL you out-PRODUCE, not a hand-carryable toll (Belongs F1):
## hand-feeding 64 ingots (128 finite-deposit hand-mined ore, smelted, hauled one
## trip at a time) aches by design — the finite-deposit system makes hand-mining that tonnage punishingly
## slow (§2). An automated drill→forge line clears it passively while you do nothing: the factory is the
## intended path down, and _test_descent_automation proves the line out-produces the wall. (Kept modest so
## the game/tests never turn grindy.)
const DESCENT_QUOTA: int = 64
const DESCENT_EATS: StringName = &"ingot"

## cell (Vector2i) -> MachineState. Authoritative placement + flow topology.
var grid: Dictionary = {}
## Solid terrain cells (cell -> material StringName, e.g. &"earth" / &"ore"). The ground the
## player stands on and digs through. Authoritative world state, like `grid`: placement is blocked
## in solid cells, and it is mutated ONLY by discrete calls (set_solid / mine) — never as a side
## effect of the real-time avatar moving — so the sim stays deterministic and serializable. The
## avatar lives in the representation layer and never enters the tick ("embodied").
var solid: Dictionary = {}
## Background WALL layer (cell -> material id): what sits BEHIND a cell, independent of whether the
## cell is solid. Mining a block leaves its wall (Terraria-style). Read-only to the view (wall_at);
## written only by load_world / set_wall. Not collision (you walk through walls), not "items present".
var wall: Dictionary = {}
## Ore-vein YIELD (cell -> remaining extractable units), over SOLID ore/coal cells. The
## richness of a visible ore block: a DRILL placed above it bores STRAIGHT DOWN, draining one unit per cycle
## and clearing the cell (carving its shaft) when the cell runs dry. HAND-mining an ore block instead grabs a
## quick loose burst (3-6) and clears the whole block — inefficient by hand, so you WANT a drill on the vein.
## Latent world resource, NOT "items present" — conservation-neutral (realized as total_produced only as the
## drill/hand actually pulls it). Absent ore cell defaults to DEFAULT_ORE_DEPOSIT (no "empty vein" case).
var deposits: Dictionary = {}
## Default drill-yield of an ore cell with no explicit richness seeded — so EVERY ore block is worth drilling,
## near-spawn and deep alike. Factorio-scale: seeded deposits run HUNDREDS near spawn, THOUSANDS deep — the
## factory feeds off a vein for a long time (the 3-6 hand burst is just a taste; the drill mines the patch).
const DEFAULT_ORE_DEPOSIT: int = 250
## THE LODE (cell -> ore item id): ore in the BACKGROUND plane, over cells whose solid block is gone.
## `docs/LODE.md` — terrain is what you CARVE, the lode is what you EXTRACT, and they stopped being the
## same object. Before this, hand-mining an ore block pocketed a 3-6 burst and then `deposits.erase()`d the
## other ~245 units out of existence: swinging your pick at ore was the most destructive act in the game and
## nothing said so, which punished exactly the free room-clearing the bit set exists to enable. Now the blow
## OPENS the vein instead of ending it — what the burst did not take stays in the cell as a lode you can keep
## working. Not collision (you walk through it), not "items present" (latent, like `deposits`, which holds
## the remaining amount for solid ore blocks and lodes alike). Cleared only by load_world and by being
## worked dry; placing a block back over a lode covers it, it does not destroy it.
var lode: Dictionary = {}
## What each lode held when it was OPENED (cell -> units) — the denominator the fleck field thins against.
## `lode_fraction` first measured remaining units against DEFAULT_ORE_DEPOSIT, which quietly says "how rich
## is this vein compared to a standard one" when the question the picture has to answer is "how much of THIS
## vein is left". The two come apart badly at the small end: the starter adit holds 45 units, untouched, and
## drew with one fleck in six — a fresh vein that looked stripped, on the first face a new player ever sees.
## Extent already carries richness (a big body covers more wall); density carries depletion.
var lode_max: Dictionary = {}
## What the player is carrying (item StringName -> count). Session state owned by the sim (so it is
## deterministic + serializable); the avatar only triggers discrete mine/deposit calls. Counted as
## "items present" for conservation. Rendered as the inventory hotbar (see `inventory_slots`).
var inventory: Dictionary = {}
## How many distinct stacks the carried pack shows as hotbar slots. The pack is intentionally small
## (GDD: a limited pack forces hauling trips). No hard capacity is ENFORCED yet — that's a feel/
## economy knob to turn when trip-friction is the thing being tuned (with the build economy). Sized to
## hold the current resources + craftable machine types at once (ore/ingot/wood/coal + the machines).
const INVENTORY_SLOTS: int = 10
## Placed machines in insertion order, for deterministic iteration.
var machines: Array[MachineState] = []
## Physical product piles resting on the dug floor: cell (Vector2i) -> {item -> count}. A machine
## SPITS its output downward; gravity carries it down the column and it lands on top of the first
## solid cell (or cascades into a machine below). The player walks over a pile to scoop it into the
## pack — the embodied collect half of the loop. Authoritative sim state (mutated only in _flow and
## by collect_ground), counted as "items present" for conservation.
var ground: Dictionary = {}
## Items that fell off the bottom of the world (a column dug clear through, no floor). A void sink
## kept only so conservation accounting never silently loses an item.
var sink: Dictionary = {}
## Conservation bookkeeping: every item is created/destroyed ONLY by a recipe (holds while no
## machine is removed mid-run; removing a machine intentionally discards its buffered items).
var total_produced: Dictionary = {}
var total_consumed: Dictionary = {}
## Cosmetic output channel: item movements logged during _flow, for the view to animate as
## falling sprites. The sim NEVER reads this back — clearing it changes no production. The
## representation layer drains it each frame. Each entry: {item, from: Vector2i, to: Vector2i, count}.
var flow_events: Array[Dictionary] = []
## Where the LAST drop_item() landed (the pile cell) — a transient hint the controller reads to grant a
## brief no-auto-pickup grace so a just-dropped item isn't instantly sucked back up (playtest fix). Not
## authoritative state (like flow_events): reset per drop, never saved.
var last_drop_landing: Vector2i = Vector2i(-1, -1)
## Cosmetic channel like flow_events: cells whose TERRAIN (solid/wall) changed since the view last drained
## this. The chunked terrain renderer repaints ONLY the affected chunks instead of the whole 7700-cell world
## (the ~300ms per-dig freeze). The sim writes on every terrain edit (mine/place/drill-bore/fell/set_solid);
## the view reads + clears it each frame; the sim never reads it back (clearing changes no production).
var terrain_dirty: Array[Vector2i] = []
## DERIVED power field (cell -> available power units), rebuilt from scratch every tick by _compute_power
## from fueled generators (+ conduits, later). NOT authoritative state — a pure function of placement +
## fuel, like updraft_at — so it can never desync. Consumers read it via power_at(); the view tints it.
var power: Dictionary = {}
## Placed POWER CONDUITS: cell -> tier (int). A THIRD world layer alongside `solid` and `wall` — NOT a
## machine (so item-flow, collision, and the tick never touch it; the player walks through tubes). Carries
## power down+lateral in _compute_power. Authoritative state, mutated only by place_conduit/remove_conduit.
var conduit: Dictionary = {}
## Placed ROPE: cell -> true. Another placed layer like `conduit` — NOT solid, NOT a machine, so
## item-flow, collision, updrafts, and the tick never see it (falling ore pours straight through a
## roped shaft). The avatar reads is_climbable() to CLIMB it — the manual answer to "digging down
## strands you", and the first rung of the manual→automated ladders→lifts→elevators arc. Authoritative
## state, mutated only by place_rope/remove_rope (discrete player calls — determinism untouched).
var rope: Dictionary = {}
## Mounted TORCHES: cell -> true. A placed layer like `rope` — not solid, not a machine; items fall
## straight through. The sim owns placement + the item ledger; the warm light pool is representation
##. Mutated only by place_torch/remove_torch (discrete player calls).
var torch: Dictionary = {}
## WATER (the first slice of L3 Aquifer/fluids): a discrete-cell fluid layer —
## cell -> INTEGER level (0..WATER_MAX). INTEGER only, never floats: float drift would break the
## deterministic-tick invariant. Water FALLS on the hook (down for free), then settles laterally toward
## a flat top; it never enters solid rock (displaced when a cell becomes solid). _flow_water() only MOVES
## water between cells (no source/drain in this slice), so total_water() is invariant across a tick.
## Authoritative world state like `solid`/`conduit`; mutated by add_water/remove_water (discrete) + the
## per-tick _flow_water sweep. No system reads it yet (sim-only, reversible); the render is a later slice.
var water: Dictionary = {}
const WATER_MAX: int = 8                       ## units of water a full cell holds (integer levels only)
## FILL: cell -> FILL_LOOSE | FILL_PACKED, for the solid cells YOU built rather than the ones the world
## laid down. It is a property of construction, not of material: the same stone reads as strata where the
## generator put it and as loose fill where you stacked it back. Only two things write it — place_block
## (loose, or packed for gravel) and the erasures that take a cell away — and only the seep step and the
## renderer read it, so a mis-tracked cell can never do anything worse than weep or not weep.
var fill: Dictionary = {}
## RESEARCHED techs (tech id -> true) — the demand-side PULL (docs/PROGRESSION.md §5). The tree lives in
## ResearchRules (static data); this is the per-session unlock state. Mutated ONLY by research_tech (a
## discrete player call at the Bazaar bench), read by the craft gate — deterministic + serializable.
var research: Dictionary = {}
## Planted SAPLINGS: cell -> growth ticks so far (the renewable-wood answer). A placed
## layer like `torch`, but the TICK grows it: at SAPLING_GROW_TICKS the cell sprouts a real tree
## (trunk + canopy, the worldgen shape) into whatever space is still open. Saplings drop from chopped
## canopies (a deterministic per-cell share of leaves), so wood — which ropes, torches and tool
## handles all eat — renews instead of dead-ending when the worldgen trees run out. Authoritative,
## mutated by plant_sapling + the tick's growth sweep.
var sapling: Dictionary = {}

## --- FINE TERRAIN (the dual-grid Noita overhaul) -----------------------
## A SECOND, FINER terrain layer at SUBDIV× the coarse resolution (8px fine cells vs 32px coarse). It
## is ADDITIVE and DERIVED: the coarse `solid` dict stays the ONE authority for ALL logistics (is_solid,
## surface_row, ramp_dir, mining, collision inputs, _column_landing, machines, flow, power all read
## `solid` exactly as before — the fine layer never feeds them), so the locked gravity hook and every
## existing test are byte-for-byte unaffected. What the fine grid IS for: a crunchier, molded, real-DATA
## render now (scenes/fine_terrain.gd bakes from it), and — in later slices — fine collision (P3) and
## brush digging (P4). Because it is a pure function of `solid` + `world_seed`, it is NOT saved: it is
## rebuilt deterministically by rebuild_fine_terrain() after load_world / save-restore (so it can never
## desync, and the save envelope stays small). Stored as one flat PackedByteArray (1 = solid, 0 = air),
## sized fine_w × fine_h (~120 KB at 384×320), indexed fy * fine_w + fx.
const SUBDIV: int = 4                              ## fine cells per coarse cell side (8px fine @ 32px cell)
## Fine-detail worldgen tuning (deterministic — seeded FastNoiseLite + coords ONLY, no time/RNG). The
## molding only bends the ~1-cell BOUNDARY band between solid and air; deep interior stays solid and open
## stays open. EDGE noise erodes/accretes the boundary into organic curves; GRIT speckle + thin
## PROTRUSIONS near surfaces add the Noita crunch. See _sync_fine_block / rebuild_fine_terrain.
const FINE_EDGE_FREQ: float = 0.22                 ## boundary erosion/accretion — bends over ~4 fine cells
const FINE_EDGE_AMP: float = 0.62                  ## how hard the edge noise bends the boundary band
## Sampled on the integer fine grid, so a frequency at or above 1.0 has a period under two samples and
## every fine cell gets an uncorrelated value — white noise, not grit. At 1.10 the boundary therefore
## alternated in/out on EVERY cell, and a rock lip that should read as a rough edge printed as a
## one-pixel dither along the whole floor. Real grit bites in clumps: 0.52 clusters it across a
## couple of cells, which is what a chipped edge actually looks like.
const FINE_GRIT_FREQ: float = 0.34                 ## grit that pits/protrudes near faces, in clumps
const FINE_GRIT_BITE: float = 0.42                 ## grit strength at an exposed face (fades inward)
const FINE_EROSION_BIAS: float = 0.04              ## tiny net-erode so cave mouths open rather than seal
var world_seed: int = 0                            ## the seed the terrain was generated from (drives fine detail)
var _fine_solid: PackedByteArray = PackedByteArray()   ## 1 = solid, 0 = air; size fine_w()*fine_h()
var _fine_edge: FastNoiseLite                      ## boundary-molding noise (built lazily on first rebuild)
var _fine_grit: FastNoiseLite                      ## grit/protrusion noise

var _tick_accumulator: float = 0.0

## PRODUCTION-RATE sampling (legibility, Factorio's "X/min" read): a ring buffer of total_produced
## snapshots taken on a fixed tick cadence, so production_rate() can answer "how fast is the factory
## making X right now" over a sliding ~60s window. Tick-driven bookkeeping — deterministic, derived,
## never read back by production logic (conservation/flow untouched).
const RATE_SAMPLE_TICKS: int = 20        # one snapshot per simulated second
const RATE_WINDOW_SAMPLES: int = 61      # ~60s of history
var _rate_tick: int = 0
var _rate_samples: Array[Dictionary] = []   # each: {"tick": int, "totals": Dictionary}
var _seep_tick: int = 0                     # counts ticks between seep passes (see _seep_step)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


## Coal-burners: the behaviors whose runner spends `fuel` and refills it from buffered coal. Kept beside
## machine_status so the "what does this box eat?" answer can't drift from the runners that eat it.
const _COAL_BURNERS: Array[StringName] = [&"drill", &"h_drill", &"generator"]


## Would this machine actually CONSUME `item` if you fed it? True for a recipe machine's ingredients, a
## coal-burner's coal, and the descent engine's ingots — false for everything else, so a mis-aimed
## handful never disappears into a box that will sit on it forever. Read-only derivation; `deposit`
## itself stays unfiltered (a test rig may prime any buffer), this is the PLAYER-facing question.
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


## Read-only status of a machine THIS tick, mirroring the run-gates in _run_machine (so legibility can't
## drift from reality). Pure derivation — no mutation, determinism untouched — the representation reads it to
## draw a Factorio-style status dot + a "needs-X" glyph. One of:
##   &"working"  — actively doing its job (producing / moving / burning)
##   &"no_fuel"  — a drill/generator with no fuel and no coal to burn (the load-bearing one: "feed me coal")
##   &"no_input" — a recipe machine (forge) starved of ingredients, or a drill with nothing borable below
##   &"blocked"  — a drill whose ore has no drain below (rock/floor directly under the vein): "dig a drain below"
##   &"idle"     — a mover (lift/hopper/splitter) with nothing in it right now (benign, not broken)
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


## DRILL status — mirrors _run_drill's exact gates, in order: something to bore → a drain → fuel.
func _status_drill(machine: MachineState) -> StringName:
	var on_lode: Vector2i = drill_lode_target(machine.cell)
	if on_lode.x < 0:
		# SPENT IS NOT STARVED, and a machine that says the wrong one sends you looking for a fix that does
		# not exist. A Head standing on a vein it has finished has nothing wrong with it — pick it up, move
		# it. It is known by the Head having pulled something and there being no lode left under it, so a
		# drill that was simply misplaced still reads as starved.
		if machine.fed > 0 and not _coverage_has_ore(machine.cell):
			return &"spent"
	var t: Vector2i = on_lode if on_lode.x >= 0 else drill_target(machine.cell)
	if t.x < 0:
		return &"no_input"                                    # no solid ore below to bore (spent/relocate)
	if on_lode.x < 0 and _drill_blocked(t):
		return &"blocked"                                     # ore has no drain below — "dig a drain below"
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## THE SPUR — a cheap module that extends a Head's reach across the vein it is standing on.
##
## It has no cycle of its own: it is not a small drill, it is one more mouth on the SAME drill. That is the
## whole reason it exists (`docs/LODE.md` §5). A vein is a shape now, not a number, and the shape is only
## worth reading if covering more of it is a BUILD rather than another machine to feed, another column to
## drain and another status bubble to watch. One Head, many Spurs, one column, one drain.
##
## A Spur eats what it STANDS ON, exactly like the Head — same rule, learned once — so it must be in an open
## cell whose backing is a lode, orthogonally touching a Head or another Spur that chains back to one.
## Everything about which cells a chain covers is therefore visible in the world without a readout.
## Is there anything left anywhere in this Head's reach? A Head whose own cell is finished but whose Spurs
## are not is still working, and must not say `spent` — the word means "pick me up and move me", and moving
## it would throw away a chain that is still paying.
## How many cells in this Head's reach still hold ore. The fuel bill is the LIVE reach, not the built one:
## a chain half of which is worked out costs half as much to run, because the alternative is charging a
## player for links that are producing nothing and calling it a trade.
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
		return &"unlinked"                 # placed on a vein but reaching nothing — the one way to get it wrong
	if not lode.has(machine.cell):
		return &"spent"                    # its own cell is worked out; the chain past it still runs
	return &"working"


## Orthogonal neighbours, in a FIXED order. Coverage order decides which cell of a chain is drained first
## when a Head cannot afford all of them, so it has to be a property of the layout and never of iteration.
const _ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]


## Every lode cell one Head works: its own, plus every Spur chained to it. Breadth-first from the Head, so
## the order is by chain DISTANCE — the near end of a spur line drains before the far end, which is the order
## a player would guess from looking at it.
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


## The Head a Spur reports to, or (-1, -1) if its chain reaches none. Walked from the Spur rather than read
## off a stored link: a chain that is broken by picking a middle Spur up has to go dead the same frame,
## without anyone remembering to tell it.
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


## GENERATOR status — burning (or holding coal to burn) = working, else the load-bearing "feed me coal".
func _status_generator(machine: MachineState) -> StringName:
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## A MOVER (lift/hopper/splitter) — "working" while goods are in it, benign "idle" when empty.
func _status_mover(machine: MachineState) -> StringName:
	return &"working" if not machine.input_buffer.is_empty() else &"idle"


## Does this def's behavior entry set `flag`? The registry-flag read for one-off behavior queries
## (updraft_at, the power sweep) — so a future second lift-like or generator-like machine works free.
func _behavior_flag(def: MachineDef, flag: StringName) -> bool:
	return bool((_BEHAVIORS.get(def.behavior, {}) as Dictionary).get(flag, false))


## Is this cell solid (any material)? (Representation reads this for collision; sim mutates it only
## via set_solid / mine.)
func is_solid(cell: Vector2i) -> bool:
	return solid.has(cell)


## Is `cell` inside a LIFT's updraft — i.e. is there a clear (unblocked) column straight DOWN to a
## lift machine? The lift inverts gravity in the open shaft above it; the avatar reads this to ride
## UP (representation only — pure query, no sim mutation, determinism untouched).
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


## --- Surface silhouette: the ONE authority for the walkable-top shape (renderer + player share it) ---
## The diagonal "slope" of the ground is a property of TERRAIN TOPOLOGY alone — independent of material
## (earth, stone, ore all ramp the same) and EXCLUDING machines (a placed machine is a box you bump or
## jump onto, never a hill). Both the renderer (draws the diagonal) and the avatar (glides it) call
## these, so what you SEE is exactly what you WALK — no phantom invisible ramps, no un-ramped stone.

## Topmost solid terrain row in a column (the exposed surface), or GRID_ROWS if the column is all air.
## FOLIAGE (trees: wood/leaves) is SKIPPED — it's solid for collision + mineable, but it is not walkable
## ground, so it must not become the silhouette (else a tree would draw a grass cap on its canopy and the
## avatar would try to ramp up the trunk). Same exclusion machines get: present, but not the terrain top.
func surface_row(col: int) -> int:
	for row: int in range(0, GRID_ROWS):
		var cell := Vector2i(col, row)
		if solid.has(cell) and not _is_foliage(solid[cell]):
			return row
	return GRID_ROWS


## Tree materials — solid + mineable, but excluded from the walkable surface silhouette (see surface_row).
func _is_foliage(material: StringName) -> bool:
	return material == &"wood" or material == &"leaves"


## The same test, public: passes that describe ROCK have to exclude the trees standing in it. The renderer's
## seam grain (#S31) is the first — a tree does not have bedding planes — and it will not be the last.
func is_foliage_material(material: StringName) -> bool:
	return _is_foliage(material)


## After a cell clears, FELL any foliage that just lost its ROOT. A tree stands because its base rests
## on solid ground; cut the base trunk (or dig the earth under it) and everything above no longer touches
## the ground — so in a gravity game it FALLS (Terraria; the user's "nothing floats" — FOLIAGE only, NOT
## terrain: caves do NOT collapse). A connected foliage component (8-way, wood+leaves together) is ROOTED
## iff some cell in it sits directly on non-foliage solid; an unrooted component is felled block-by-block
## into the pack (identical accounting to hand-chopping each cell, so conservation holds exactly).
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


## Remove one un-rooted foliage cell and award its yield the SAME way hand-chopping does (wood → pack; a
## share of leaves → a sapling), so a felled tree gives you its wood and conservation stays exact.
func _fell_foliage_cell(c: Vector2i) -> void:
	var mat: StringName = solid.get(c, &"")
	if mat == &"" or not _is_foliage(mat):
		return
	solid.erase(c)
	_dirty_terrain(c)
	if mat == &"wood":
		inventory[&"wood"] = int(inventory.get(&"wood", 0)) + 1
		total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + 1
	elif mat == &"leaves" and leaf_drops_sapling(c):
		inventory[&"sapling"] = int(inventory.get(&"sapling", 0)) + 1
		total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
	_resettle_pile_above(c)


## Slope of the exposed surface at a column: +1 rising to the right, -1 rising to the left, 0 flat.
## A neighbour exactly ONE tile higher reads as a 45° ramp; a bigger step is a wall (0 here → the
## avatar's square-collision blocks it, the renderer draws no diagonal). Terrain only — machines and
## material never enter, which is precisely what kills the two bugs the split authority caused.
func ramp_dir(col: int) -> int:
	var here: int = surface_row(col)
	var left: int = surface_row(col - 1)
	var right: int = surface_row(col + 1)
	if right == here - 1 and left >= here:
		return 1
	if left == here - 1 and right >= here:
		return -1
	return 0


## Seed or clear a terrain cell — used to build the starting world. Discrete edit; in-bounds only.
## Pass &"" to clear, otherwise the material (&"earth" default).
func set_solid(cell: Vector2i, material: StringName = &"earth") -> void:
	if not in_bounds(cell):
		return
	if material == &"":
		solid.erase(cell)
	else:
		solid[cell] = material
		water.erase(cell)          # rock displaces water — the two layers never coexist in a cell
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


## Ingest a generated world (the gen→sim handshake): replace terrain with the WorldData's two grids.
## Only cells in bounds are taken. The avatar/machines are unaffected; this is the start-of-world
## seeding step that replaces the old hand-coded _seed_world terrain loop.
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
	# AQUIFERS (L3): seeded water in carved-open pockets (generator guarantees no watered cell is solid).
	# Guard an older WorldData that predates the water grid (default empty → dry world).
	if world.water != null:
		for cell: Vector2i in world.water:
			if in_bounds(cell) and not solid.has(cell):
				water[cell] = clampi(int(world.water[cell]), 1, WATER_MAX)
	rebuild_fine_terrain()   # derive the fine grid from the freshly loaded coarse terrain (deterministic)


## --- FINE TERRAIN accessors + build (P2) ----------------------------------
## The fine grid is DERIVED render/collision data, NOT authoritative logistics state — every accessor
## reads the flat byte array; the sim's production math never touches it.

func fine_w() -> int:
	return GRID_COLS * SUBDIV


func fine_h() -> int:
	return GRID_ROWS * SUBDIV


## Is the fine cell at (fx, fy) solid? Out of bounds reads AIR (so world edges mold as carved faces).
func fine_is_solid(fx: int, fy: int) -> bool:
	if fx < 0 or fy < 0 or fx >= fine_w() or fy >= fine_h():
		return false
	if _fine_solid.size() != fine_w() * fine_h():
		return false
	return _fine_solid[fy * fine_w() + fx] == 1


## Rebuild the ENTIRE fine terrain array from the coarse `solid` grid + deterministic fine worldgen.
## Called after load_world / save-restore (the fine grid is not saved — it derives from `solid` + seed).
## Deterministic in (world_seed, coords) ONLY (no time, no RNG), so two loads of the same world produce
## an identical fine array. O(fine cells) — full rebuild; incremental edits use _sync_fine_block instead.
func rebuild_fine_terrain() -> void:
	FineTerrain.rebuild(self)


## The seed the fine noise fields were built for (so a reused sim rebuilds them when world_seed changes).
var _fine_seed_built: int = -0x7fffffff


## Mark a coarse terrain cell dirty: queue the chunk repaint AND re-mold its fine block (+ boundary band).
## The ONE place terrain edits announce a solid/wall change, so the fine grid can never drift from `solid`.
func _dirty_terrain(cell: Vector2i) -> void:
	terrain_dirty.append(cell)
	FineTerrain.sync_block(self, cell)


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the
## cell was already open. Mining an ORE vein yields one ore into the player's pack — and that ore is
## genuinely produced from the world, so it counts toward total_produced (conservation stays true).
## The cell's background WALL is left intact (you carve the block, the wall stays behind).
## `keep` false PULVERISES: the block still breaks and the world still opens, but nothing enters the pack
## and nothing is counted as produced — which is exactly what conservation wants, since a pulverised block
## was never produced at all. It is the Broad bit's price (`BitRules`), and it is the same accounting the
## ore vein's discarded latent yield has always used.
func mine(cell: Vector2i, keep: bool = true) -> StringName:
	if not solid.has(cell):
		return &""
	_bazaars_dirty = true               # a mined block can break a bazaar frame → rescan lazily
	fill.erase(cell)                    # dug back out — it is no longer anybody's fill
	var material: StringName = solid[cell]
	if _is_ore_like(material):
		# HAND-mining an ore-like block (ore or coal) is a quick, inefficient grab: one strike clears the whole
		# block and pockets a handful of LOOSE ore (a 3-6 burst). The block's larger latent yield (`deposits`) is
		# NOT hand-extractable — that's the DRILL's job. You place a drill ABOVE a visible ore vein and it bores
		# DOWN through the solid ore, draining each cell dry. So hand-mining is how you grab your
		# FIRST few ore (to craft the drill); the drill is how you mine the vein. The burst counts as produced
		# when it enters the pack; the discarded latent yield was never produced, so conservation holds.
		var latent: int = int(deposits.get(cell, DEFAULT_ORE_DEPOSIT))
		var burst: int = mini(_ore_burst(cell) if keep else 0, latent)
		if burst > 0:
			inventory[material] = int(inventory.get(material, 0)) + burst
			total_produced[material] = int(total_produced.get(material, 0)) + burst
		var left: int = latent - burst
		if left > 0:
			lode[cell] = material          # the blow OPENED the vein; the rest of it is still there to work
			deposits[cell] = left
			lode_max[cell] = left          # …and this is full, for this vein: the blow is what opened it
		else:
			deposits.erase(cell)           # a thin seam the burst took whole — nothing left to open
			lode.erase(cell)
			lode_max.erase(cell)
		solid.erase(cell)
		_dirty_terrain(cell)                # repaint the chunk + re-mold the fine block now the cell is air
		_resettle_pile_above(cell)          # the floor under any resting pile just vanished — it falls
		return material
	if _is_foliage(material):
		# Foliage chops BLOCK-BY-BLOCK (Terraria/Minecraft), never flood-felling the whole tree on one hit —
		# you carve a tree down trunk by trunk. Wood yields one wood per block (a built structure, e.g. the
		# bazaar frame, behaves identically — mirrors place_block's consume, so conservation holds); a share
		# of LEAVES hide a SAPLING (deterministic per cell — no RNG), the seed of the renewable-wood loop
		# (#38): plant it on soil and a new tree grows. The whole-tree fell stays removed.
		solid.erase(cell)
		_dirty_terrain(cell)
		if not keep:
			pass                                       # pulverised: the tree still falls, the wood is dust
		elif material == &"wood":
			inventory[&"wood"] = int(inventory.get(&"wood", 0)) + 1
			total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + 1
		elif material == &"leaves" and leaf_drops_sapling(cell):
			inventory[&"sapling"] = int(inventory.get(&"sapling", 0)) + 1
			total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
		_resettle_pile_above(cell)
		_settle_foliage(cell)          # cut the base/trunk → the rest of the tree loses its root and FALLS
		return material
	# Plain terrain (earth/stone/deepslate): Terraria dig-and-carry — pocket the block as a placeable item
	# so you can re-place it to bridge a gap, backfill, or PILLAR out of a hole. Produced from the world +
	# consumed on placement (place_block) → conservation holds, symmetric with mining a placed block back.
	solid.erase(cell)
	_dirty_terrain(cell)
	if keep:
		inventory[material] = int(inventory.get(material, 0)) + 1
		total_produced[material] = int(total_produced.get(material, 0)) + 1
	_resettle_pile_above(cell)               # gravity: a pile that rested on this block now falls
	_settle_foliage(cell)                    # dug the earth under a tree → the whole tree loses its root
	return material


## Player action: PLACE a building-material block from the pack into an open cell (the Terraria build
## primitive — the inverse of mine). Consumes one `material` from the pack; the cell becomes solid. Like
## crafting, the spent item is counted as CONSUMED, and mining it back counts as produced, so conservation
## holds across build/dig (terrain isn't "items present"). Refuses solid/occupied/out-of-bounds cells.
## Can a building block be PLACED here — the Terraria ADJACENCY rule, the fix for "placing blocks in the
## middle of the air"? Yes if a WALL backs the cell, or an orthogonal neighbour is something to build off
## (solid terrain, a machine, or a conduit). So you can backfill a dug room or extend a structure, but
## can't plop a block in isolated open sky. A pure read; the CONTROLLER gates block placement on it —
## machines are exempt (you legitimately place a lift in an open shaft), so this lives beside place_block
## rather than inside it (worldgen + the harness still place freely).
func block_supported(cell: Vector2i) -> bool:
	if wall_at(cell) != &"":
		return true
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nb: Vector2i = cell + d
		if is_solid(nb) or machine_at(nb) != null or has_conduit(nb):
			return true
	return false


## Every placed layer — solid rock, a machine (grid), a conduit, a rope, a torch — is MUTUALLY EXCLUSIVE
## per cell: no two may share one. This is the SINGLE occupancy gate every placement checks, so the layers
## can never overlap. (A stress test caught the old per-function guards each checking a DIFFERENT subset —
## place_block ignored conduit, place_conduit ignored rope/torch, place_machine ignored conduit, … — which
## let a cell become solid AND piped at once, corrupting state.) A new placed layer adds ONE check here.
func _cell_occupied(cell: Vector2i) -> bool:
	return solid.has(cell) or grid.has(cell) or conduit.has(cell) or rope.has(cell) or torch.has(cell)


func place_block(cell: Vector2i, material: StringName) -> bool:
	if not in_bounds(cell) or _cell_occupied(cell):
		return false          # every placed layer is mutually exclusive — clear the cell first
	if int(inventory.get(material, 0)) <= 0:
		return false
	_take_from_pack(material, 1)
	total_consumed[material] = int(total_consumed.get(material, 0)) + 1
	solid[cell] = material
	# What you stacked back is FILL, and fill is either packed or it weeps (docs/DRIFT.md §4). Gravel is
	# the one material that packs; everything else — the stone out of this very gallery included — is loose.
	fill[cell] = FILL_PACKED if material == &"gravel" else FILL_LOOSE
	water.erase(cell)                   # placing rock into a watered cell displaces that cell's water
	_dirty_terrain(cell)
	_bazaars_dirty = true               # a placed block can COMPLETE a bazaar frame → rescan lazily
	return true


## --- POWER CONDUITS — a placed layer, not a machine. The carried &"conduit" item is
## crafted at the bazaar/forge like a machine; placing it routes here (the controller branches on the
## def's &"conduit" behavior) instead of into `grid`, so conduits never enter item-flow or collision. ---

func has_conduit(cell: Vector2i) -> bool:
	return conduit.has(cell)


## The tier of the conduit at a cell (0 = none). One tier for now; deeper materials raise it later.
func conduit_tier(cell: Vector2i) -> int:
	return int(conduit.get(cell, 0))


## Place a carried conduit into an open cell (mirrors build_from_pack: spend one &"conduit" from the pack).
## Refuses solid/occupied/already-piped/out-of-bounds cells. Returns whether it went down. The spent item
## counts as CONSUMED and removal counts as PRODUCED (the same symmetric accounting as place_block/mine),
## so a placed layer never silently leaks the conservation invariant.
func place_conduit(cell: Vector2i) -> bool:
	if not in_bounds(cell) or _cell_occupied(cell):
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


## --- ROPE (the placeable climb) — a placed layer like the conduit, read by the avatar to climb. ---

func is_climbable(cell: Vector2i) -> bool:
	return rope.has(cell)


## Player action: hang a rope at `anchor` and let it UNROLL DOWN the open column (one carried &"rope"
## item per segment) until it hits solid ground / a machine / an existing rope / the world floor, or the
## pack runs out. ONE placement ropes a whole shaft — and because the anchor can be any open in-reach
## cell ABOVE you, a player stranded at the bottom of their own dig aims up, places, and the rope
## unrolls down TO them. Each segment counts as CONSUMED (symmetric with remove_rope's produced), so
## the total ledger holds. Returns the number of segments hung (0 = refused: bad anchor / no rope).
func place_rope(anchor: Vector2i) -> int:
	var hung: int = 0
	var c: Vector2i = anchor
	while in_bounds(c) and not _cell_occupied(c) and int(inventory.get(&"rope", 0)) > 0:
		_take_from_pack(&"rope", 1)
		total_consumed[&"rope"] = int(total_consumed.get(&"rope", 0)) + 1
		rope[c] = true
		hung += 1
		c += Vector2i(0, 1)
	return hung


## The topmost segment of the connected rope through `cell` — its ANCHOR end (ropes are vertical runs).
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


## Player action: RETRACT the whole rope through `cell` — walk up to its anchor, then
## take every segment back. One action recovers the entire hang no matter which segment you aim at
## (the old top-segment aim demand was pure precision friction); the niche "cut here, keep the upper
## half" is covered by retract + re-place (rope crafts as a cheap bundle). Returns segments recovered.
func retract_rope(cell: Vector2i) -> int:
	if not rope.has(cell):
		return 0
	return remove_rope(rope_anchor(cell))


## Player action: cut the rope at `cell`. A rope HANGS, so cutting a segment takes that segment and
## every connected segment BELOW it (the tail can't float); all return to the pack (produced — the
## mirror of place_rope's consumed). Returns how many segments came back.
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


## --- TORCHES — placeable LIGHT, another placed layer like rope/conduit. Not solid,
## not a machine: items fall through, collision never sees it. The sim only owns placement + the
## ledger; the WARM POOL it casts is pure representation (the renderer lights torch cells). Light is
## claimed territory in the black — the first light you can leave behind, before power arrives. ---

func has_torch(cell: Vector2i) -> bool:
	return torch.has(cell)


## Mount a carried &"torch" on an open cell. Needs a BACKING to hang from — a real wall behind the
## cell or any solid neighbour (no torches floating in open sky). Consumed into the ledger; removal
## produces it back, so the total ledger holds.
func place_torch(cell: Vector2i) -> bool:
	if not in_bounds(cell) or _cell_occupied(cell):
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


## --- WATER (L3 Aquifer/fluids, first slice) — a discrete-cell integer fluid layer. Mirrors the other
## layer APIs (conduit/rope/torch): a small read + two mutators + a conservation probe. INTEGER levels
## only; _flow_water (run each tick) MOVES water between cells and never creates/destroys it. ---

## The water level (0..WATER_MAX) at a cell — 0 if none.
func water_at(cell: Vector2i) -> int:
	return int(water.get(cell, 0))


## Add up to WATER_MAX water into a cell; returns the amount ACTUALLY added (the overflow doesn't fit —
## the caller decides what to do with it). Never adds into a solid cell (water can't occupy rock), and
## never creates water from nothing: a 0-level cell drops out of the dict, so total_water stays exact.
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


## Total water in the world — the conservation probe (_flow_water is invariant in this sum per tick).
func total_water() -> int:
	var sum: int = 0
	for v: Variant in water.values():
		sum += int(v)
	return sum


## --- PACKING & SEEPAGE (docs/DRIFT.md §4). What you STACKED BACK is not what was always there. ---

## Is this cell packed fill — the watertight kind? Pure read; the renderer and the harness both use it.
func is_packed(cell: Vector2i) -> bool:
	return fill.get(cell, &"") == FILL_PACKED


## Is this cell loose fill — rock you stacked back, which weeps under pressure?
func is_loose_fill(cell: Vector2i) -> bool:
	return fill.get(cell, &"") == FILL_LOOSE


## THE SEEP STEP — run every SEEP_INTERVAL ticks. For each cell of LOOSE fill, a wet neighbour at or above
## SEEP_PRESSURE pushes ONE unit through to the open cell on the far side. Down first (a flooded gallery
## over your backfilled floor is the case that matters), then the two lateral pairs.
##
## Water is MOVED, never made: the sum is invariant across this step exactly as it is across WaterFlow. The
## pass is deterministic (cells sorted, one unit per cell per pass) and it iterates `fill` — the cells YOU
## built — not the world, so its cost is the size of your own construction and nothing else.
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
			break                                  # one unit per loose cell per pass — a weep, not a breach


## --- SAPLINGS — the renewable-wood loop. Chopped canopies hide seeds; plant one on
## soil and the TICK grows it into a real tree (the worldgen shape), so wood never dead-ends. A placed
## layer like `torch` — not solid, not a machine, items fall through; the sprout is drawn by the view. ---

const SAPLING_GROW_TICKS: int = 2400          ## 20 Hz × 120 s — a tree in two minutes (bank a grove)
const SAPLING_SOILS: Array[StringName] = [&"earth"]   ## what a sapling can root in

## Does chopping this LEAVES cell yield a sapling? Deterministic per cell (a stable hash, no RNG — the
## same canopy always hides its seeds in the same corners): about one leaf in three. Public so tests +
## the mine() drop share one truth.
func leaf_drops_sapling(cell: Vector2i) -> bool:
	return ((int(cell.x) * 73856093) ^ (int(cell.y) * 19349663)) % 3 == 0


## Plant a carried &"sapling" on open ground: the cell must be open (no solid/machine/rope/torch) and
## sit ON soil (SAPLING_SOILS). Consumed into the ledger; the eventual tree is world matter (yields
## produced wood when chopped, like worldgen trees), so the ledger stays total.
func plant_sapling(cell: Vector2i) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or rope.has(cell) \
			or torch.has(cell) or sapling.has(cell):
		return false
	if int(inventory.get(&"sapling", 0)) <= 0:
		return false
	if not SAPLING_SOILS.has(solid.get(cell + Vector2i(0, 1), &"")):
		return false
	_take_from_pack(&"sapling", 1)
	total_consumed[&"sapling"] = int(total_consumed.get(&"sapling", 0)) + 1
	sapling[cell] = 0
	return true


## Take a planted sapling back into the pack (the mirror of plant_sapling — growth so far is forfeit).
func remove_sapling(cell: Vector2i) -> bool:
	if not sapling.has(cell):
		return false
	sapling.erase(cell)
	inventory[&"sapling"] = int(inventory.get(&"sapling", 0)) + 1
	total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1
	return true


## --- The BAZAAR (crafting hub) — detected as a structure in the world, not a machine.
## A bazaar is a distinctive WOOD FRAME with an open interior, sitting on solid ground:
##     W W W W      top beam (all wood)
##     W . . W      posts + open interior
##     W . . W      posts + open interior
##     . G G .      interior floor must be solid ground
## "Active" is DERIVED from the world (a valid frame == active) — no persistent state, so it stays
## deterministic + node-free, and a bazaar you rebuild elsewhere just works. The open interior + exact
## shape is what stops a plain wall/house from matching. (A second `log` material for extra robustness +
## the cozy look, and the NPC walk-in, are deferred.)
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


## All valid bazaar frames in the world (their top-left origins). A whole-world scan — cheap enough to
## call on demand (e.g. when the player opens the craft screen), not per-frame. Deterministic ordering.
## CACHED: this is a full-grid scan (~7700 cells × a 4×3 window) and the representation calls it several
## times PER FRAME (the bazaar transform view + the near-bazaar craft gate) — ~10ms/frame of pure waste, a
## real steady-state stutter. Bazaars are made of blocks, so the result only changes on a terrain edit; the
## mutators flip `_bazaars_dirty` and we rescan lazily. O(1) amortized between digs.
var _bazaars_cache: Array[Vector2i] = []
var _ruins_cache: Array[Dictionary] = []       ## {origin, gap} — frames ONE block short (see find_bazaar_ruins)
var _bazaars_dirty: bool = true
func find_bazaars() -> Array[Vector2i]:
	if _bazaars_dirty:
		_rescan_bazaars()
	return _bazaars_cache


## Frames that are exactly ONE wood block short of being a bazaar, each with the cell that is missing.
##
## The world stamps one of these near spawn as the first thing a player is asked to build
## (layered_world_gen._stamp_bazaar_ruin lays the frame minus its bottom-right post). Until it is
## finished it is not a bazaar, so nothing downstream knew it existed, and the view drew nothing over it
## — the game's first landmark and its first build lesson looked like four loose wood blocks. This is
## what lets the representation draw it as a derelict stall with a marked gap.
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
## Deliberately strict: EVERYTHING a finished bazaar needs must already hold — interior open, interior
## floor real ground, every other frame cell wood — and the one hole must be genuinely EMPTY rather than
## occupied by stone you would have to dig first. So a positive answer means "place one wood block here
## and it activates", which is the only claim the view is allowed to make to the player. A complete
## bazaar answers (-1,-1) too: complete is not one-short.
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


## True if `cell` is a WOOD FRAME cell (post or top beam) of a COMPLETED bazaar — the walls of the stall you
## walk INTO. The body passes through these (the bazaar is a walk-through shop, not a solid box), while the
## bazaar's interior FLOOR (plain ground, not a frame cell) stays solid so you stand inside it. O(1): only
## wood cells can qualify, and a cell can belong to at most a BAZAAR_W×BAZAAR_H window of candidate origins.
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


## Where to place ONE wood block to CLAIM a near-complete bazaar (the ruin needs its last post): scans for
## a frame that is valid in every respect EXCEPT a single empty frame cell, and returns that cell (the
## "place wood here" target). Returns (-1,-1) if none is one block from done. Drives the objective pointer
## and lets the play-test claim the bazaar without hardcoding worldgen geometry. Pure read of `solid`.
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
		return Vector2i(-1, -1)                                 # already complete — nothing to place
	for ix: int in range(1, BAZAAR_W - 1):                     # interior floor must be solid ground
		var floor_cell: Vector2i = o + Vector2i(ix, BAZAAR_H)
		if not solid.has(floor_cell) or _is_foliage(solid[floor_cell]):
			return Vector2i(-1, -1)
	return missing


## True if any active bazaar's interior is within `radius` cells of `cell` — the gate for crafting
## (you craft AT the bazaar). Scans the detected frames; cheap on demand.
func near_bazaar(cell: Vector2i, radius: int) -> bool:
	for o: Vector2i in find_bazaars():
		var c: Vector2i = bazaar_center(o)
		if absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return true
	return false


## Materials that mine as a "vein" (cavity model): a hand-burst + a drillable wall deposit, dropping their
## own item. Ore and coal both. (Coal is mined the same painful way → the demand-web.)
func _is_ore_like(material: StringName) -> bool:
	return material == &"ore" or material == &"coal" or material == &"iron" or material == &"rich_ore"


## The hand-mined BURST size for an ore cell — a juicy 3-8, deterministic per cell (a stable hash, no RNG
## → determinism-safe) so a given vein always drops the same amount. The actual drop is capped by the
## vein's richness (a thin vein gives less).
func _ore_burst(cell: Vector2i) -> int:
	var h: int = (int(cell.x) * 73856093) ^ (int(cell.y) * 19349663)
	return 3 + (absi(h) % 4)   # 3..6 loose ore grabbed by hand (the chunk itself is the drill's job)


## Remaining drill-yield of the SOLID ore/coal vein at `cell` (0 if the cell isn't ore) — read by the hover
## inspector so it can show a visible vein's richness. An ore cell with no explicit seed reads the default.
func ore_deposit_at(cell: Vector2i) -> int:
	if solid.has(cell) and _is_ore_like(solid[cell]):
		return int(deposits.get(cell, DEFAULT_ORE_DEPOSIT))
	if lode.has(cell):
		return int(deposits.get(cell, 0))
	return 0


## The ore in the background at `cell`, or &"" — an EXPOSED vein you can work by hand or (from strike 2 of
## `docs/LODE.md` §10) cover with a drill. A lode under a solid block still exists; it is simply behind rock.
func lode_at(cell: Vector2i) -> StringName:
	return lode.get(cell, &"")


## Is there a lode here you can actually get at — one whose face is open? The lode survives being built over
## (it is background, and covering it is not destroying it), so "there is ore here" and "you can work it" are
## two different questions and the mining loop wants the second one.
func lode_workable(cell: Vector2i) -> bool:
	return lode.has(cell) and not solid.has(cell) and int(deposits.get(cell, 0)) > 0


## TAKE ONE UNIT from an exposed lode — the hand verb. Deliberately one unit per call: the vein does not
## break, nothing is cleared, and the cell is still there when you look up. Returns the item taken, or &""
## if there was nothing workable here. Realises latent world resource into production, exactly as the drill
## does, so conservation reads the same through either hand.
func take_lode(cell: Vector2i) -> StringName:
	if not lode_workable(cell):
		return &""
	var item: StringName = lode[cell]
	var left: int = int(deposits.get(cell, 0)) - 1
	inventory[item] = int(inventory.get(item, 0)) + 1
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	if left > 0:
		deposits[cell] = left
	else:
		deposits.erase(cell)               # worked dry — the vein is spent, and it stops drawing as one
		lode.erase(cell)
		lode_max.erase(cell)
	terrain_dirty.append(cell)
	return item


## How much of a lode is left, as a fraction of what a fresh one holds — the number the renderer thins the
## fleck field by, so a worked-out vein LOOKS worked out. Until now a 250-unit cell and a 4-unit cell were
## pixel-identical, which is a poor way to treat the one number the player is meant to plan around.
func lode_fraction(cell: Vector2i) -> float:
	if not lode.has(cell):
		return 0.0
	var full: float = float(lode_max.get(cell, deposits.get(cell, 1)))
	return clampf(float(deposits.get(cell, 0)) / maxf(full, 1.0), 0.0, 1.0)


## The carried pack as an ordered list of {item, count} for the inventory hotbar UI. Dictionaries
## preserve insertion order, so the slot layout is stable as items are picked up. Pure read over
## `inventory` — no behaviour or determinism change.
func inventory_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for item: StringName in inventory:
		slots.append({"item": item, "count": int(inventory[item])})
	return slots


## Player action: hand items from the pack into the machine at `cell` (its input buffer). Returns
## the number actually deposited (capped by what's carried). The avatar triggers this when standing
## in reach of a machine — the manual half of the manual→automated arc.
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


## Player action: DROP items from the pack into a column — gravity is the conveyor, so you don't
## "insert" into a machine, you let go and it FALLS. Reuses _column_landing: the dropped items cascade
## straight down `cell`'s column from the player's row and land in the first machine below (feeding its
## input), else on the first floor as a ground pile (re-collectable), else the void sink. Returns how
## many dropped. Conservation holds: items only MOVE pack→(machine|ground|sink), none made or destroyed.
## `from_cell` is the VISUAL launch origin for the cosmetic toss (the body's cell when you toss ore into
## the next column over) — it only colours the flow_event's `from`, which the sim never reads back, so
## the production landing is unaffected. Default sentinel (-1,-1) means "launch from `cell`" (straight drop).
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


## Player action: CRAFT a machine item into the pack, spending its `craft_cost` from inventory.
## Yields `def.craft_count` per craft (1 for machines; cheap consumables like rope yield a bundle).
## RESEARCH-GATED: a machine still locked behind an unresearched tech refuses (the PULL — your ingots
## must first buy the unlock at the Bazaar bench; docs/PROGRESSION.md §5).
func craft(def: MachineDef) -> bool:
	if not craft_unlocked(def.id):
		return false
	return craft_item(def.id, def.craft_cost, def.craft_count)


## Is this craftable unlocked — free (no locking tech), or its tech researched?
func craft_unlocked(item_id: StringName) -> bool:
	var lock: StringName = ResearchRules.locking_tech(item_id)
	return lock == &"" or research.has(lock)


func is_researched(tech_id: StringName) -> bool:
	return research.has(tech_id)


## Player action: RESEARCH a tech at the Bazaar bench (proximity is the controller's gate, like reach).
## Analyze-the-new: consumes ONE unit of the tech's signature SAMPLE material (you must have found it)
## plus its refined-goods cost — both ledgered as consumed, so conservation holds and research is a real
## sink. Refuses when unknown / already researched / prereq missing / ingredients short.
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


## The generic craft primitive: spend `cost` (item->count) from the pack, add `count` `output` items.
## Returns true if crafted (enough ingredients). THE LEDGER IS TOTAL: spent items count as consumed and
## the output counts as produced — every item id (resources, machine items, tools) satisfies
## present == produced − consumed at all times, so conservation can be asserted on anything. The output
## (machine id OR a tool id) lives in the same pack as ore/ingots. One path for both machines (craft)
## and tools (MiningRules.TOOL_RECIPES) so the Bazaar screen crafts them identically.
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


## Player action: place a machine you CARRY — consumes one machine item (def.id) from the pack and
## places it. Returns the MachineState, or null if you don't carry one or the cell is blocked.
## The spent item counts as CONSUMED (a placed machine isn't "present"); pickup_machine mirrors it
## back as produced — the same symmetric accounting as blocks and conduits, so the ledger stays total.
func build_from_pack(def: MachineDef, cell: Vector2i) -> MachineState:
	if int(inventory.get(def.id, 0)) <= 0:
		return null
	var state: MachineState = place_machine(def, cell)
	if state == null:
		return null
	_take_from_pack(def.id, 1)
	total_consumed[def.id] = int(total_consumed.get(def.id, 0)) + 1
	return state


## Player action: pick a placed machine back up into the pack (one machine item by its def.id).
## Returns true if a machine was there. Any items the machine was holding are SALVAGED back into the
## pack rather than discarded — so picking up a mid-work forge never silently destroys your ore
## (items just move machine→pack, both "present" → conservation holds).
func pickup_machine(cell: Vector2i) -> bool:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return false
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			inventory[item] = int(inventory.get(item, 0)) + int(buffer[item])
		buffer.clear()   # salvaged into the pack — cleared so remove_machine has nothing left to destroy
	inventory[state.def.id] = int(inventory.get(state.def.id, 0)) + 1
	total_produced[state.def.id] = int(total_produced.get(state.def.id, 0)) + 1  # mirrors build's consume
	remove_machine(cell)
	return true


func _take_from_pack(item: StringName, n: int) -> void:
	var left: int = int(inventory.get(item, 0)) - n
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)


## Place a machine in a cell. Returns the new MachineState, or null if out of bounds / occupied /
## inside solid earth.
func place_machine(def: MachineDef, cell: Vector2i) -> MachineState:
	if not in_bounds(cell) or _cell_occupied(cell):
		return null           # every placed layer is mutually exclusive — clear the cell first
	var state: MachineState = MachineState.new(def, cell)
	grid[cell] = state
	machines.append(state)
	return state


## Remove the machine at a cell (if any). Any items still in its buffers are DESTROYED with the machine —
## credited to total_consumed so the conservation invariant (present == produced - consumed) holds. (The
## player-facing pickup_machine SALVAGES buffers into the pack and clears them first, so it reaches here
## with empty buffers and destroys nothing; a raw remove_machine — a test, a future demolish verb — credits
## whatever it discards. Fuel/progress aren't items, so they're not credited.)
func remove_machine(cell: Vector2i) -> void:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			total_consumed[item] = int(total_consumed.get(item, 0)) + int(buffer[item])
	grid.erase(cell)
	machines.erase(state)


## The most whole ticks one advance() will run, so a slow frame can't trigger a catch-up spiral: if the
## frame took long, delta is big (× the fast-forward clock, bigger still), which would queue many ticks,
## which take longer, which grows the next delta — a runaway. Past the cap we drop the excess sim-time
## (the accumulator is trimmed) rather than chase it: the factory momentarily runs slow-motion instead of
## locking up. 6 ticks = 3× the ~2.66 ticks/frame an 8× clock needs at 60fps, so normal fast-forward is
## unaffected — this only ever bites a genuine hitch. Determinism per tick is untouched (a tick is a tick).
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
## bursts land in total_produced too, so the rate reads your whole income — by hand AND by machine.
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


## FACTORY CENSUS (legibility — the production dashboard's machine side): every placed machine tallied
## by type, with a LIVE working-count off machine_status. A pure read over `grid` (one MachineState per
## cell), mirroring production_rates()'s role — no state, never touches the tick. Returns
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


## FACTORY ALERTS (legibility — the alert stack): machines that were meant to RUN but
## stalled — output has no drain (`blocked`) or fuel ran dry (`no_fuel`). Grouped by (id, status); each
## entry carries one representative cell so the HUD can ping the culprit (the camera is body-locked, so
## "take me there" = a beacon, not a jump). Pure read over grid — starvation (`no_input`) is deliberately
## OUT: it's usually "not hooked up yet", not a breakdown, and would fire on every just-placed machine.
## [{id, name, def, status, count, cell}], worst (most-numerous) first.
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


## Drop any ground cell whose pile emptied. `_column_landing`/`_column_rise` create a pile dict EAGERLY for
## a landing they might not fill — a splitter routing all of a tick's items one way, or a resettle of an empty
## pile — leaving an empty `{}` in `ground`. An empty pile is a phantom: it crashes walk-over collect
## (`keys()[0]`) and draws a ghost guide. Conservation-neutral (0 items) + not in the determinism signature,
## so pruning is safe. Ground is small, so this is cheap.
func _prune_empty_ground() -> void:
	for cell: Variant in ground.keys():
		if (ground[cell] as Dictionary).is_empty():
			ground.erase(cell)


## Available power at a cell (the derived field; 0.0 where none reaches). Consumers read this to throttle;
## the view tints it. Pure read — no mutation, determinism untouched (mirrors updraft_at / material_at).
func power_at(cell: Vector2i) -> float:
	return float(power.get(cell, 0.0))


## THE COST RULE, in one place: the fraction of full speed a power consumer at `cell`
## gets, = clamp(available power / its demand, 0..1). 1.0 when fully supplied, proportionally less as the
## supply (attenuated by distance from the source) falls short — so the deep frontier, furthest from
## generation, browns out first for free. Every consumer routes its draw through this and nothing else.
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


## The DEFAULT machine: a named recipe-runner — consume the recipe's inputs over its cycle time,
## produce its outputs (the only place items are created/destroyed, so conservation holds).
func _run_recipe(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	# PASS-THROUGH (the descent engine's rule generalized): every machine is a filter
	# for what its recipe WANTS — anything else moves on through to the output and falls on down the
	# column. A mixed drill stream sorts ITSELF down a machine stack (the forge keeps ore, the coal
	# pours past into the generator below); junk can never clog an input buffer. Conservation-neutral.
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


## A LIFT runs no recipe: it carries items UP its column — the paid inverse of gravity.
## Its throughput is POWER-GOVERNED: LIFT_THROUGHPUT at its unpowered baseline, scaling up to
## LIFT_POWERED_THROUGHPUT as power reaches its cell (the power_throttle cost rule). The rest stays a
## backlog. No items created or destroyed → conservation holds. Whatever falls onto a lift is hauled up.
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


## THE PUMP — the fluid sibling of the lift (the L3 flood answer). It runs no recipe
## and moves no items: while POWERED it DRAINS water out of its own cell and the cells straight below it,
## on the locked hook — water fell in for free, pumping it back out costs power. Its drain BUDGET this tick
## = round(PUMP_RATE × power_factor), where power_factor is the SAME cost rule the lift uses
## (power_throttle at the pump's cell). Unpowered → power_factor 0 → budget 0 → it does nothing (idle). The
## budget is spent TOP-DOWN over PUMP_REACH cells (own cell first, then downward), taking up to what each
## cell holds — a solid cell or the world floor ends the reach (rock isn't watered; nothing lies below it in
## this column). remove_water is an explicit accounted drain (total_water drops), OUTSIDE _flow_water's
## move-only rule, so the pump is a legit sink; integer-only and clamped, so no negative levels ever appear.
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
			break                                # rock caps the column — nothing watered lies below it
		budget -= remove_water(c, budget)        # drain up to what's left of the budget from this cell


## PUMP status — mirrors _run_pump's gates: no power → idle ("no power"); powered but the reachable column
## is already dry → idle (nothing to do, benign); powered with water in reach → working (draining).
func _status_pump(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, PUMP_POWER_DEMAND) <= 0.0:
		return &"idle"                           # unpowered — the load-bearing "no power" read
	for dy: int in range(0, PUMP_REACH):
		var c: Vector2i = machine.cell + Vector2i(0, dy)
		if not in_bounds(c) or solid.has(c):
			break
		if water_at(c) > 0:
			return &"working"                    # water in reach → draining
	return &"idle"                               # powered but dry — nothing left to pump


## A splitter runs no recipe: it just moves whatever has fallen into it from its input into its
## output (no items created or destroyed), to be divided across two columns by _flow next. This
## gives one tick of pass-through latency, which keeps it deterministic and order-independent.
func _run_splitter(machine: MachineState) -> void:
	for item: StringName in machine.input_buffer:
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + int(machine.input_buffer[item])
	machine.input_buffer.clear()


## A HOPPER stockpiles what falls into it (its input_buffer IS the store — unbounded, the missing 'chest')
## and meters it back DOWN to feed a machine below, with BACK-PRESSURE: it only releases while the consumer
## below is under HOPPER_FEED_CAP, so the bulk stays banked in the hopper instead of overflowing the forge.
## No consumer below → it holds everything (pure storage). Items only MOVE (input→output→the machine below),
## none created/destroyed → conservation holds; the stockpile counts as present (machine buffers do). Many
## drills funnel here (route their columns together with splitters), it absorbs the burst + feeds steady.
func _run_hopper(machine: MachineState) -> void:
	if machine.input_buffer.is_empty():
		return
	# THE FILTER: a hopper KEEPS the first thing it tastes — the filter auto-latches on
	# the first item it banks (shown in the hover; R clears it to re-taste). Everything ELSE passes
	# straight through to the output and falls on down. So a CHAIN of hoppers unzips a mixed drill
	# stream with zero configuration: each one keeps a different ingredient as the stream pours past.
	if machine.filter == &"":
		machine.filter = machine.input_buffer.keys()[0]     # deterministic: insertion order
	for item: StringName in machine.input_buffer.keys():
		if item == machine.filter:
			continue                                        # the banked good — metered below
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


## THE DESCENT ENGINE runner (the L1→L2 gate): eat DESCENT_EATS from the input buffer toward the quota
## (total_consumed — a true sink), pass every OTHER item through to the output so it falls on down (the
## engine is a filter, never a trap). At quota, BREACH: open the contiguous sealrock straight below
## (walls kept — a carved shaft into Stonereach). With no seal below (misplaced, or already breached) it
## eats nothing and passes everything.
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


## DESCENT ENGINE status — mirrors _run_descent's gates: quota met → idle (done, benign — the way is
## open), no seal below → blocked ("stand it ON the seal"), chewing → working, hungry → no_input (the
## need bubble asks for its ingots).
func _status_descent(machine: MachineState) -> StringName:
	if machine.fed >= DESCENT_QUOTA:
		return &"idle"
	if _seal_below(machine.cell).x < 0:
		return &"blocked"
	if machine.progress > 0.0 or not machine.input_buffer.is_empty():
		return &"working"
	return &"no_input"


## The first SOLID cell straight below `cell` (scanning through open air, stopped by any machine), IF it
## is sealrock — the seal face a Descent Engine breaches. (-1,-1) when the column's first solid isn't the
## seal (misplaced engine, or the shaft is already bored).
func _seal_below(cell: Vector2i) -> Vector2i:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var c := Vector2i(cell.x, row)
		if grid.has(c):
			return Vector2i(-1, -1)
		if solid.has(c):
			return c if solid[c] == &"sealrock" else Vector2i(-1, -1)
	return Vector2i(-1, -1)


## The first machine straight below `cell` before any solid floor — the hopper's consumer (or null if a
## floor/nothing is below). Used for the hopper's feed + back-pressure decision.
func _first_machine_below(cell: Vector2i) -> MachineState:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var c := Vector2i(cell.x, row)
		var m: MachineState = grid.get(c, null)
		if m != null:
			return m
		if solid.has(c):
			return null                     # a floor before any machine → nothing to feed
	return null


## The ore cell a Drill at `cell` bores — scanning STRAIGHT DOWN its own column for the first ore SOURCE:
## the first SOLID ore-like block straight down from `cell` (the boring drill eats solid ore, carving its
## own shaft — you place it in the open cell ABOVE a visible ore vein and it sinks a column into it; many
## drills line the top of an ore BODY and each sinks a parallel column). It UNDERMINES: it targets the
## DEEPEST solid ore in its column (the one just above open space / a collector), so draining eats the body
## BOTTOM-UP and each freed unit falls FREE into the shaft below — never trapped under still-solid ore above
## it (the old top-down bug). Skips already-carved open cells (the shaft it made); STOPS at solid ROCK (the
## body bottomed out) or another MACHINE below (the collection point — don't bore into your hopper/forge).
## (-1,-1) if nothing borable. Down-only = on the gravity hook. Design read: the deeper/taller & richer a
## vein is, the longer the drill runs — so you hunt VERTICAL, high-quality deposits for lasting automation.
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
				break                  # solid rock caps the column — the body bottomed out here
		elif dy > 0 and grid.has(c):
			break                      # a machine below → collection point, stop scanning
		# else: an open cell (the drill's own shaft, or an air gap) — keep sinking through it
	return deepest


## True when the deepest ore has nowhere to DRAIN — the cell directly below it is solid rock (or the world
## floor), so a freed unit can't fall out of the shaft and would pile against the body. The drill STALLS and
## reports &"blocked" ("dig a drain below") rather than mine into a dead pocket. (The cell below the deepest
## ore is never ore — if it were, it'd be the deeper target — so it's open air, a machine, or rock.)
func _drill_blocked(target: Vector2i) -> bool:
	if target.x < 0:
		return false
	var below := target + Vector2i(0, 1)
	if not in_bounds(below):
		return true                    # the world floor is directly under the ore → nowhere to drop
	if grid.has(below):
		return false                   # a machine sits below → it collects the ore (a valid drain)
	return solid.has(below)            # solid rock caps it → blocked; open air → drains free


## THE DRILL HEAD (`docs/LODE.md` §5, `docs/LODE_PLAN.md` phase 2a). A drill standing IN a cell whose
## backing is a lode draws from that lode, in place — you put the machine ON the thing it eats, which is the
## one placement rule nobody has to be taught. Returns the drill's own cell when there is a lode under it
## with something left, else (-1,-1) and the old bore-down-the-column model answers instead (the bridge
## `docs/LODE_PLAN.md` §3 keeps green until the phase-3 cutover).
##
## Note what is deliberately NOT checked: whether the cell is solid. It cannot be — a machine only stands in
## an open cell — and the lode is background, so "the machine is here" and "the vein is here" are compatible
## facts rather than competing ones. That is the whole point of moving ore off the terrain plane.
##
## A Head is NOT un-made by finishing the cell under it. Once Spurs exist its reach is the chain, not the one
## cell, so this answers with the nearest link that still holds ore — own cell first, then outward by chain
## distance. Without a Spur on it that is exactly the old behaviour, one cell, and the preview and every
## existing assertion see no difference.
func drill_lode_target(cell: Vector2i) -> Vector2i:
	if lode.has(cell) and int(deposits.get(cell, 0)) > 0:
		return cell
	for c: Vector2i in head_coverage(cell):
		if lode.has(c) and int(deposits.get(c, 0)) > 0:
			return c
	return Vector2i(-1, -1)


## Read-only PLACEMENT PREVIEW for a drill hovered at `cell` — what the representation draws so a player
## sees, before committing, exactly which ore the drill will bore and where it will pour. Returns the ore
## cells it would extract (its whole column, top to bottom), the DROP cell just below the deepest ore (the
## out-point), and whether that drop is blocked. Empty ore_cells = not over any ore. Pure derivation.
func drill_preview(cell: Vector2i) -> Dictionary:
	# ON A LODE the preview is a different sentence: not "it will bore this column and pour there", but
	# "it will work THIS face, and the ore goes down from here". One cell, its own column — which is the
	# placement legibility win `docs/DRIFT.md` §6 asks for, arrived at by deleting geometry rather than
	# drawing more of it.
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


## Total ore a drill at `cell` can still bore from its whole column — the sum of every solid ore cell's
## remaining deposit straight down until rock or a machine stops it. The "how much is left for this drill"
## the hover surfaces, so a drill on a fat body reads its real remaining supply.
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


## A DRILL automates the by-hand ore mine. It BORES STRAIGHT DOWN its column into the first
## SOLID ore block below it, eating through solid ore and carving its shaft as it goes — so you place it in
## the open cell ABOVE a visible ore vein and never hunt for the exact cell. Each cycle it drains ONE unit and
## ejects it DOWN; when a solid ore cell's deposit empties, the cell is CLEARED (the shaft deepens) and the
## drill reaches the next ore below. It stops at rock/a machine, and goes quiet when the body is spent
## ("relocate it"). Fuel-gated on COAL (the demand-web). The ore is genuinely produced from the world →
## total_produced (same accounting as hand-mining), drawn from the WORLD not a buffer.
func _run_drill(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	var lode_cell: Vector2i = drill_lode_target(machine.cell)
	var target: Vector2i = lode_cell if lode_cell.x >= 0 else drill_target(machine.cell)
	if target.x < 0:
		return                          # nothing borable below — idle, hold progress
	# A HEAD IS NEVER "BLOCKED". The old drill stalls when the ore it bored has rock right under it, because
	# a freed unit would have nowhere to fall and would pile against the body it just came out of. A Head
	# pours down its own column like anything else and, if there is no shaft, the ore piles at its feet —
	# which is what every other item in this game does when it lands, and is a state you can read and fix by
	# digging. Refusing to run would be inventing a chore (`docs/DRIFT.md` §5) to prevent a pile.
	if lode_cell.x < 0 and _drill_blocked(target):
		return                          # ore has no drain below — stall (status shows "blocked: dig a drain")
	# FUEL: the drill burns COAL to run (the demand-web — automating ore creates demand for coal). Burn one
	# tick of the current coal; when it's spent, refuel from the coal in its input buffer. No fuel + no coal
	# → the drill goes quiet (idle, holds progress) until you feed it more coal.
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
	# FUEL SCALES WITH REACH. A Head with Spurs on it takes a unit out of every covered cell per cycle, so it
	# burns coal per cell too. That is the trade the module is worth having for: coverage scales output and
	# cost together and leaves the MACHINE COUNT flat, which is the only one of the three that costs the
	# player attention. Free reach would make a Spur strictly better than not placing one, and a module you
	# always place is a tax with extra steps.
	var mouths: int = _live_mouths(machine.cell) if lode_cell.x >= 0 else 1
	machine.fuel -= mouths
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	# A HEAD ON A LODE drains the vein in place and clears nothing — the same one-unit-per-cycle rate, off the
	# same pool the hand pulls from, poured down the same column. When it runs dry the vein is gone and the
	# machine says so (&"spent"); the machine itself is untouched and can be picked up and moved.
	if lode_cell.x >= 0:
		# ONE COLUMN, ONE DRAIN. Every covered cell gives up a unit and ALL of it pours out of the Head's own
		# column, not each Spur's. The on-hook rule is intact and this is what it says: extraction may be
		# lateral, logistics stays gravity-vertical — a Spur is part of the Head reaching sideways, never a
		# conveyor. It is also the property that makes reach worth building: you cut wide across the vein and
		# still only manage one drop.
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
		machine.fed += pulled                                 # what this Head has pulled — and how `spent` is known
		return
	# Drain one unit from the target solid ore cell (CLEARED when its deposit empties, carving the shaft). The
	# freed material is produced + ejected DOWN.
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
	# Eject the freed material DOWN from the bored cell (still the drill's own column), where gravity carries
	# it to a hopper/forge/collection. `from` = the bored cell so the falling-item visual pours from the vein.
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	var dest: Dictionary = _column_landing(target.x, target.y + 1)
	dest["target"][item] = int(dest["target"].get(item, 0)) + 1
	flow_events.append({"item": item, "from": target, "to": dest["to_cell"], "count": 1})


## The next solid cell the borer at `cell` (facing ±1) would chew: scan its row from the face outward
## to H_DRILL_RANGE, skipping the open cells of the gallery it already carved. (-1,-1) = nothing
## borable in range — the gallery is spent, another machine walls it, rock too hard for its bit, or
## the world edge. Pure read (the hover + placement preview share it with the runner).
func h_drill_target(cell: Vector2i, facing: int) -> Vector2i:
	for k: int in range(1, H_DRILL_RANGE + 1):
		var c := Vector2i(cell.x + facing * k, cell.y)
		if not in_bounds(c) or grid.has(c):
			return Vector2i(-1, -1)
		if not solid.has(c):
			continue                                     # already carved — reach deeper
		if MiningRules.required_tier(solid[c]) > H_DRILL_TIER:
			return Vector2i(-1, -1)                      # too hard for the bit — the gallery ends here
		return c
	return Vector2i(-1, -1)


## Would one more `item` overflow the borer's 5-slot belly? Full = at the total cap, or already
## holding 5 distinct stacks and this would start a sixth.
func _h_belly_full(machine: MachineState, item: StringName) -> bool:
	var total: int = 0
	for it: StringName in machine.output_buffer:
		total += int(machine.output_buffer[it])
	if total >= H_DRILL_BELLY_TOTAL:
		return true
	return machine.output_buffer.size() >= H_DRILL_BELLY_STACKS and not machine.output_buffer.has(item)


## THE HORIZONTAL DRILL (the user's spec): a coal-hungry sideways borer. Each cycle it
## bites the next solid cell along its facing — ore-like cells drain one unit per bite (a rich vein
## takes many), plain rock clears in one bite yielding its block-item. Bored COAL feeds its OWN fuel
## bunker first (self-sustaining while the seam lasts); everything else fills the 5-slot belly. The
## ON-HOOK rule lives in _destinations_h_drill: the haul exits DOWN its own column only — no drain
## below and the belly pools until it stalls (`blocked`: "dig a drain"). Extraction may be lateral;
## logistics stays gravity-vertical.
func _run_h_drill(machine: MachineState) -> void:
	var target: Vector2i = h_drill_target(machine.cell, machine.facing)
	if target.x < 0:
		return                                           # gallery spent — carry it to a new face (no_input)
	var item: StringName = solid[target]
	var to_bunker: bool = item == &"coal" and int(machine.input_buffer.get(&"coal", 0)) < H_DRILL_COAL_STOCK
	if not to_bunker and _h_belly_full(machine, item):
		return                                           # belly full, no drain taking it — stall (blocked)
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
	# THE BITE: ore-like cells drain unit by unit (cleared when the pool empties); plain rock clears
	# in one, yielding its block-item (bored earth/stone feed block-building — nothing is waste).
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


## Borer status, mirroring _run_h_drill's gates exactly (legibility can't drift from reality).
func _status_h_drill(machine: MachineState) -> StringName:
	var target: Vector2i = h_drill_target(machine.cell, machine.facing)
	if target.x < 0:
		return &"no_input"                               # gallery spent — move it
	var item: StringName = solid[target]
	var to_bunker: bool = item == &"coal" and int(machine.input_buffer.get(&"coal", 0)) < H_DRILL_COAL_STOCK
	if not to_bunker and _h_belly_full(machine, item):
		return &"blocked"                                # "empty me / dig a drain below"
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


## Borer routing — THE ON-HOOK RULE: its haul drops straight down its OWN column, and only when a
## drain exists (the cell directly below is open air or a machine). Sitting sealed on solid rock the
## belly POOLS — no piles conjured inside the tunnel floor — until the player digs the drop-shaft
## under it (the borer's version of the vertical drill's "dig a drain below").
func _destinations_h_drill(machine: MachineState) -> Array[Dictionary]:
	var below := machine.cell + Vector2i(0, 1)
	if solid.has(below) and not grid.has(below):
		return []
	return [_column_landing(machine.cell.x, machine.cell.y + 1)]


## THE DRIFT RIG'S FACE: the next COLUMN with something to cut, as the rig's own row. It cuts two cells at
## once — its row and the row above — so the gallery it leaves is walkable, which is the difference between
## a bore-hole and a drift. Scans outward along the facing, skipping columns it has already cleared.
## (-1,-1) = nothing left in range: the gallery is spent, a machine walls it, the rock is over its tier, or
## the world ends. Pure read — the hover, the placement preview and the runner all share it.
func drift_target(cell: Vector2i, facing: int) -> Vector2i:
	for k: int in range(1, DRIFT_RANGE + 1):
		var lo := Vector2i(cell.x + facing * k, cell.y)
		var hi := lo + Vector2i(0, -1)
		if not in_bounds(lo) or not in_bounds(hi) or grid.has(lo) or grid.has(hi):
			return Vector2i(-1, -1)
		var has_lo: bool = solid.has(lo)
		var has_hi: bool = solid.has(hi)
		if not has_lo and not has_hi:
			continue                                     # already cut — reach deeper into its own gallery
		if has_lo and MiningRules.required_tier(solid[lo]) > DRIFT_TIER:
			return Vector2i(-1, -1)                      # over-tier rock ends the drift, same as the Borer
		if has_hi and MiningRules.required_tier(solid[hi]) > DRIFT_TIER:
			return Vector2i(-1, -1)
		return lo
	return Vector2i(-1, -1)


## Which belly a material goes to. `_is_ore_like` already draws the line the whole game uses — ore, coal,
## iron, rich ore are PAY; earth, stone, clay and the rest are SPOIL. The rig does not invent a new class,
## it acts on the one that was already there (docs/DRIFT.md §4).
func drift_is_pay(material: StringName) -> bool:
	return _is_ore_like(material)


func _drift_belly_full(buffer: Dictionary) -> bool:
	var total: int = 0
	for it: StringName in buffer:
		total += int(buffer[it])
	return total >= DRIFT_BELLY


## THE DRIFT RIG. Each cycle it takes ONE cell of the two-cell face — the lower first, then the upper — and
## files it by class: pay into `output_buffer`, spoil into `spoil_buffer`. Its speed is POWER-GOVERNED
## through the one cost rule (`power_throttle`): fully supplied it bites every DRIFT_CYCLE seconds, half
## supplied it takes twice as long, unpowered it does nothing at all. It burns no coal, which is the point —
## the Borer's constraint was fuel you could carry, and this one's is a network you have to build.
##
## A stream whose belly is full stalls THAT STREAM ONLY. The rig keeps cutting as long as the cell it is
## about to take has somewhere to go, so a jammed spoil column does not stop you pulling ore out of a vein —
## it just means the gallery stops advancing once the rock in front of it is rock.
func _run_drift(machine: MachineState) -> void:
	machine.power_factor = power_throttle(machine.cell, DRIFT_POWER_DEMAND)
	if machine.power_factor <= 0.0:
		return                                           # dark — idle, and the status says "no power"
	var target: Vector2i = drift_target(machine.cell, machine.facing)
	if target.x < 0:
		return                                           # gallery spent — carry it to a new face
	var bite: Vector2i = target if solid.has(target) else target + Vector2i(0, -1)
	var item: StringName = solid[bite]
	if _drift_belly_full(machine.spoil_buffer if not drift_is_pay(item) else machine.output_buffer):
		return                                           # that stream is jammed — the status names which
	machine.progress += SECONDS_PER_TICK * machine.power_factor
	if machine.progress < DRIFT_CYCLE:
		return
	machine.progress -= DRIFT_CYCLE
	# THE BITE — the Borer's rule exactly: ore-like cells drain unit by unit (a rich vein takes many bites),
	# plain rock clears in one and yields its block-item. Nothing is deleted; everything is matter.
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


## Drift Rig status, mirroring _run_drift's gates in the same order — legibility cannot be allowed to drift
## from reality. Two of these are new words: `no_power` (the machine is dark) and the two BLOCKED variants,
## because "output blocked" on a machine with two outputs is not an answer to anything.
func _status_drift(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, DRIFT_POWER_DEMAND) <= 0.0:
		return &"no_power"
	var target: Vector2i = drift_target(machine.cell, machine.facing)
	if target.x < 0:
		return &"no_input"                               # gallery spent — move it
	# A FULL BELLY IS REPORTED THE MOMENT IT IS FULL, not only when the next bite would go into it. This is
	# the one place the status deliberately says MORE than the stall gate does: the rig can be mid-vein,
	# cutting ore perfectly happily, with its spoil column dead behind it — and "working" would be true and
	# useless. A jam needs a drain dug; the sooner it is named, the sooner it is dug.
	if _drift_belly_full(machine.output_buffer):
		return &"blocked_pay"
	if _drift_belly_full(machine.spoil_buffer):
		return &"blocked_spoil"
	return &"working"


## THE TWO COLUMNS, and the ON-HOOK RULE used twice rather than bent once. Destination 0 is PAY — straight
## down the rig's own column. Destination 1 is SPOIL — straight down the column immediately BEHIND it, the
## mouth of the gallery you came in through, which is where you already had to dig to get here.
##
## Each is gated separately on having a drain: a column whose next cell down is solid rock and not a machine
## takes nothing, and that stream pools in its belly instead. Neither stream ever moves sideways. That is
## the one property in this whole machine that must never regress.
func _destinations_drift(machine: MachineState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for col: int in [machine.cell.x, machine.cell.x - machine.facing]:
		var below := Vector2i(col, machine.cell.y + 1)
		if not in_bounds(below) or (solid.has(below) and not grid.has(below)):
			out.append({})                               # no drain under this column — that stream pools
		else:
			out.append(_column_landing(col, machine.cell.y + 1))
	return out


## The rig's own delivery, because the default multi-destination path DEALS items round-robin (that is the
## splitter's job) and the rig's two columns mean two different THINGS. Pay goes down one, spoil down the
## other, by class, with zero cross-contamination — which is the machine's entire reason to exist.
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


## Is this item SPOIL — the class the Crusher eats? Everything `_is_ore_like` says no to and that isn't a
## manufactured good: earth, stone, deepslate, gravel's own feedstock. Named as its own question because
## docs/DRIFT.md §4 is explicit that spoil is a CLASS, not a new item, and one predicate is how that stays
## true. Gravel itself is excluded — crushing gravel into gravel is a loop with a machine in it.
func is_spoil(item: StringName) -> bool:
	return item in [&"earth", &"stone", &"deepslate", &"clay", &"shale"]


## THE CRUSHER (docs/DRIFT.md §4). Two units of spoil — any mix — become one of GRAVEL, the only material
## that packs. Powered, like everything on this rung: unpowered it does nothing and says so.
##
## PAY IS NEVER CRUSHED. Ore-like items in the input fall straight through to the output and carry on down
## the column, so a crusher parked under a mixed stream is a filter that costs you nothing — put one under
## the Drift Rig's SPOIL column and it is pure gain, put one under a mixed Borer stream and your ore still
## reaches the forge. A machine that ate the thing you were mining for would be a trap wearing a machine's
## face, and the one rule this whole rung is built on is that spoil never becomes housekeeping.
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


## How much SPOIL (only) a crusher is holding — the number its cycle and its status both gate on.
func _spoil_held(machine: MachineState) -> int:
	var total: int = 0
	for item: StringName in machine.input_buffer:
		if is_spoil(item):
			total += int(machine.input_buffer[item])
	return total


## Crusher status, mirroring _run_crush's gates in the same order. A crusher holding nothing but ore says
## `no_input` — correctly: it has no spoil, and the ore it is holding is already on its way out.
func _status_crush(machine: MachineState) -> StringName:
	if power_throttle(machine.cell, CRUSH_POWER_DEMAND) <= 0.0:
		return &"no_power"
	if _spoil_held(machine) < CRUSH_RATIO:
		return &"no_input"
	if int(machine.output_buffer.get(&"gravel", 0)) >= CRUSH_BELLY:
		return &"blocked"
	return &"working"


## A GENERATOR burns coal to pour power. Each tick it spends one tick of its current fuel;
## when that runs out it consumes one coal from its input buffer to reburn for GENERATOR_FUEL_TICKS. No
## fuel left and no coal → it goes dark (fuel stays 0, so _compute_power emits nothing for it). Coal is
## genuinely consumed (total_consumed) so conservation holds. The power it makes is NOT an item — it's the
## derived field, which _compute_power reads from this machine's fuel>0 state at the top of the next tick.
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


## Gravity + routing: each machine's output is handed to its destination(s). An ordinary machine
## has ONE destination — straight down its column. A splitter has TWO — straight down, and down
## the column to its right — and divides its output evenly between them (alternating item-by-item
## so odd counts split fairly over time). Items are only moved here, never created or destroyed.
func _flow() -> void:
	for machine: MachineState in machines:
		# A machine whose outputs mean DIFFERENT THINGS routes them itself (the Drift Rig's pay/spoil
		# columns). The default path below deals items round-robin, which is the splitter's job and exactly
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
			# Split: deal each item unit along the machine's deal PATTERN via route_toggle — an even
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


## Player action (R aimed at a machine): cycle its configuration — the splitter's ratio, a hopper's
## filter reset (clear → it re-latches on the next item it banks). Returns a short human label of the
## new state for the HUD toast, or "" when the machine has nothing to configure. Discrete + ledger-free.
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


## Set a splitter's ratio DIRECTLY (the config panel's clickable chips — R still cycles
## through configure_machine above). A discrete call like every player mutation. "" = not a splitter.
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


## LIFT routing: the inverse of gravity — its output goes UP its column.
func _destinations_lift(machine: MachineState) -> Array[Dictionary]:
	return [_column_rise(machine.cell.x, machine.cell.y - 1)]


## SPLITTER routing: down + the column to the RIGHT. Hard against the right wall it has no second
## column, so it degrades to a plain pass-through (down only) — provisional edge.
func _destinations_splitter(machine: MachineState) -> Array[Dictionary]:
	var down: Dictionary = _column_landing(machine.cell.x, machine.cell.y + 1)
	var right_col: int = machine.cell.x + 1
	if right_col >= GRID_COLS:
		return [down]
	# Diverted items move sideways into the right column at the splitter's row, then fall.
	return [down, _column_landing(right_col, machine.cell.y)]


## Where a spat product lands, scanning down `col` from `start_row`: the first machine below catches
## it (cascade), else it rests on top of the first solid floor as a physical ground pile. A column
## dug clear to the bottom drops it into the void sink (conservation-only).
func _column_landing(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, GRID_ROWS):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := _settle_on_slope(Vector2i(col, row - 1))  # roll off a surface ramp to its base
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, GRID_ROWS), "target": sink}


## An item that lands on a 45° SURFACE ramp doesn't perch on it — it rolls downhill to the base (playtest:
## "items falling on a slope should go downhill"). Only the outdoor surface has ramps (interior/cave floors
## are square, per ramp_dir/surface_row), so this fires ONLY when `rest` is a column's surface top; an item
## resting on a dug interior floor is untouched. Follows the slope column-by-column until it reaches flat
## ground or a wall, guarded against non-descending steps and any loop.
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


## Where a LIFTED item goes, scanning UP `col` from `start_row` (the mirror of _column_landing): the
## first machine above catches it (feed a higher machine), else it rests against the first ceiling
## (a pile just below the solid cell), else — an open shaft to the top — it rests at the top row.
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


## When the solid floor under a resting pile is removed (mined out, ore/vein exhausted, drilled), the
## pile can't hang in mid-air — gravity re-drops it. If a pile rests directly on top of `cell`, cascade
## it down `cell`'s now-open column to the next machine/floor below and emit a flow_event so it visibly
## streams. Conservation-neutral: items only MOVE pile→(machine|lower pile|sink). Call AFTER erasing cell.
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


## Player action: walk over a resting pile and scoop it all into the pack. Returns how many items
## were collected. The embodied collect half of spit-out → fall → collect (no abstract counter).
func collect_ground(cell: Vector2i) -> int:
	var pile: Dictionary = ground.get(cell, {})
	if pile.is_empty():
		return 0
	var collected: int = 0
	for item: StringName in pile:
		inventory[item] = int(inventory.get(item, 0)) + int(pile[item])
		collected += int(pile[item])
	ground.erase(cell)
	return collected
