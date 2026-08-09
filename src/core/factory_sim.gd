class_name FactorySim
extends RefCounted

## THE SOURCE OF TRUTH. A node-free, fixed-tick, deterministic factory simulation. It could
## run headless with no scene tree (and does, in tests/run_tests.gd). The representation layer
## reads FROM this; it never writes to it. All production math lives here and nowhere else.
##
## TOPOLOGY: machines occupy cells on a grid (x = column, y = row, row increasing DOWNWARD).
## Gravity = a machine's output falls straight down its column to the next machine below; if
## none, it lands in the sink. The grid size and the "straight-down only" rule are PROVISIONAL
## (chutes / splitters / lateral routing are later slices — see docs/RISKS.md "Spatial model").

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)
## A larger world so a zoomed-out (3×) camera has real terrain to show and scroll through — hills,
## depth, room to explore (presentation sprint). Provisional size; real worldgen is still deferred.
const GRID_COLS: int = 96
const GRID_ROWS: int = 80
## Items/tick a LIFT carries UP its column with NO power — its hand-cranked baseline (the L1 rate, before
## power exists). Below this rate, a backlog piles at the lift. Power is what lifts it past this baseline:
## a fully-powered lift reaches LIFT_POWERED_THROUGHPUT, scaled by the power reaching its cell (docs/POWER.md
## — fighting gravity UP is the canonical "costs power" case). Under-supplied, it labours back toward
## baseline = brownout. Baseline kept non-zero so the lift still works pre-power and L1 is unaffected.
const LIFT_THROUGHPUT: int = 2          ## unpowered baseline (L1), also the floor under brownout
const LIFT_POWERED_THROUGHPUT: int = 6  ## items/tick at FULL power — the governed deep-frontier rate
const LIFT_POWER_DEMAND: float = 4.0    ## power at the lift's cell for the full boost (less → proportional)
## --- POWER (the L2 twist, docs/POWER.md): power FALLS on the hook. A fueled GENERATOR burns coal and
## pours power into the cells around it (its innate aura — conduits will extend the reach down+lateral
## in a later slice); consumers draw from the field to run. The field is a DERIVED quantity recomputed
## every tick from machine placement + fuel — never stored authoritative state, exactly like updraft_at —
## so determinism is untouched and it can never desync.
const GENERATOR_POWER: float = 6.0      ## power units a fueled generator emits at its source
const GENERATOR_FUEL_TICKS: int = 100   ## ticks one coal burns (5s @20Hz) before the generator refuels
const DRILL_FUEL_TICKS: int = 60        ## ticks one coal runs a Drill (3s @20Hz) — the drill burns coal to mine (docs/MINING.md)

## THE HORIZONTAL DRILL / the Borer (FABLE_50 #46 — the user's spec): bores SIDEWAYS through rock.
const H_DRILL_RANGE: int = 8            ## cells of gallery one placement can reach — move it to bore on
const H_DRILL_CYCLE: float = 1.5        ## seconds per bite (slower than the vertical drill)
const H_DRILL_FUEL_TICKS: int = 60      ## ticks one coal burns — with the slower cycle, ~2 bites/coal
                                        ## vs the vertical drill's 3 (laterality is priced in coal)
const H_DRILL_COAL_STOCK: int = 8       ## its self-feeding fuel bunker's cap (bored coal beyond it → belly)
const H_DRILL_BELLY_STACKS: int = 5     ## distinct item stacks the belly holds (the "5 slots")
const H_DRILL_BELLY_TOTAL: int = 40     ## total items across those stacks
const H_DRILL_TIER: int = 2             ## chews what a stone pick could; harder rock ends the gallery
## HOPPER (storage): it STOCKPILES what falls into it (input_buffer = the store, unbounded) and meters it
## back DOWN to a machine below with BACK-PRESSURE — only feeding while the consumer's buffer is under
## FEED_CAP, so the stockpile stays in the hopper (a visible bank) instead of overflowing the forge. No
## consumer below → it just holds. The missing 'chest': drills funnel here, it buffers bursts, feeds steady.
const HOPPER_RELEASE: int = 1           ## items released downward per tick when the consumer has room
const HOPPER_FEED_CAP: int = 3          ## hold releasing once the machine below is backed up to this many
const POWER_AURA: int = 2               ## innate radius (cells) a generator powers WITHOUT any conduit
## CONDUITS carry power further than the aura — DOWN + LATERAL, never UP (a U-shape delivers as an L).
## That "no up" rule makes the network acyclic top-to-bottom, so the field resolves in a SINGLE downward
## sweep (no iterative solver — docs/POWER.md §7). Vertical feeders SUM (merge two trunks → thicker),
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
}

## THE DESCENT ENGINE (the L1→L2 gate — docs/PROGRESSION.md §2): placed over THE SEAL, it EATS
## gravity-fed ingots (a true sink) and, at its quota, BREACHES the seal below — boring the shaft into
## Stonereach. The quota is a THROUGHPUT WALL you out-PRODUCE, not a hand-carryable toll (Belongs F1,
## docs/DESIGN_REVIEW.md): hand-feeding 64 ingots (128 finite-deposit hand-mined ore, smelted, hauled one
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
## avatar lives in the representation layer and never enters the tick (docs/RISKS.md "embodied").
var solid: Dictionary = {}
## Background WALL layer (cell -> material id): what sits BEHIND a cell, independent of whether the
## cell is solid. Mining a block leaves its wall (Terraria-style). Read-only to the view (wall_at);
## written only by load_world / set_wall. Not collision (you walk through walls), not "items present".
var wall: Dictionary = {}
## Ore-vein YIELD (cell -> remaining extractable units), over SOLID ore/coal cells (docs/MINING.md). The
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
## (docs/FABLE_50.md #26). Mutated only by place_torch/remove_torch (discrete player calls).
var torch: Dictionary = {}
## RESEARCHED techs (tech id -> true) — the demand-side PULL (docs/PROGRESSION.md §5). The tree lives in
## ResearchRules (static data); this is the per-session unlock state. Mutated ONLY by research_tech (a
## discrete player call at the Bazaar bench), read by the craft gate — deterministic + serializable.
var research: Dictionary = {}
## Planted SAPLINGS: cell -> growth ticks so far (FABLE_50 #38 — the renewable-wood answer). A placed
## layer like `torch`, but the TICK grows it: at SAPLING_GROW_TICKS the cell sprouts a real tree
## (trunk + canopy, the worldgen shape) into whatever space is still open. Saplings drop from chopped
## canopies (a deterministic per-cell share of leaves), so wood — which ropes, torches and tool
## handles all eat — renews instead of dead-ending when the worldgen trees run out. Authoritative,
## mutated by plant_sapling + the tick's growth sweep.
var sapling: Dictionary = {}

## --- FINE TERRAIN (the dual-grid Noita overhaul, docs/FINE_TERRAIN.md P2) -----------------------
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
const FINE_EDGE_FREQ: float = 0.34                 ## boundary erosion/accretion — clumps ~3 fine cells wide
const FINE_EDGE_AMP: float = 0.62                  ## how hard the edge noise bends the boundary band
const FINE_GRIT_FREQ: float = 1.10                 ## dense per-fine-cell grit that pits/protrudes near faces
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


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


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
	var t: Vector2i = drill_target(machine.cell)
	if t.x < 0:
		return &"no_input"                                    # no solid ore below to bore (spent/relocate)
	if _drill_blocked(t):
		return &"blocked"                                     # ore has no drain below — "dig a drain below"
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


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
	rebuild_fine_terrain()   # derive the fine grid from the freshly loaded coarse terrain (deterministic)


## --- FINE TERRAIN accessors + build (docs/FINE_TERRAIN.md P2) ----------------------------------
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
	_ensure_fine_noise()
	var fw: int = fine_w()
	var fh: int = fine_h()
	if _fine_solid.size() != fw * fh:
		_fine_solid.resize(fw * fh)
	for fy: int in fh:
		for fx: int in fw:
			_fine_solid[fy * fw + fx] = 1 if _fine_cell_solid(fx, fy) else 0


## Re-mold ONE coarse cell's SUBDIV×SUBDIV fine block PLUS the one-cell boundary band around it (its
## edge molding reads the coarse neighbours, so a dig must re-mold the neighbours' rims to stay organic).
## O(local): (SUBDIV+2)² fine cells per edit — the cheap incremental path used on mine/place/bore/fell.
func _sync_fine_block(coarse: Vector2i) -> void:
	_ensure_fine_noise()
	var fw: int = fine_w()
	var fh: int = fine_h()
	if _fine_solid.size() != fw * fh:
		rebuild_fine_terrain()
		return
	# Cover this cell's SUBDIV block and one coarse cell of margin on every side (the boundary band).
	var fx0: int = maxi(0, (coarse.x - 1) * SUBDIV)
	var fy0: int = maxi(0, (coarse.y - 1) * SUBDIV)
	var fx1: int = mini(fw, (coarse.x + 2) * SUBDIV)
	var fy1: int = mini(fh, (coarse.y + 2) * SUBDIV)
	for fy: int in range(fy0, fy1):
		for fx: int in range(fx0, fx1):
			_fine_solid[fy * fw + fx] = 1 if _fine_cell_solid(fx, fy) else 0


## Decide whether a single fine cell is solid — the FINE WORLDGEN, deterministic in (world_seed, fx, fy).
## Base solidity = its parent coarse cell's solidity. In the INTERIOR (all coarse neighbours agree) it
## stays as-is — deep rock stays solid, open air stays open, so the hook's terrain is never punched. Only
## at a solid/air BOUNDARY does fine detail apply: a bilinear ramp of coarse solidity is perturbed by
## seeded edge noise (organic curves) then grit (crunch/protrusions near faces) and thresholded — so
## rock reads Noita-crunchy, not smooth, WITHOUT any change to the coarse authority.
func _fine_cell_solid(fx: int, fy: int) -> bool:
	var pcx: int = fx / SUBDIV
	var pcy: int = fy / SUBDIV
	var parent: bool = solid.has(Vector2i(pcx, pcy))
	# Is this fine cell in a boundary band? (any coarse neighbour differs from the parent) — only then mold.
	var boundary: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if solid.has(Vector2i(pcx, pcy) + d) != parent:
			boundary = true
			break
	if not boundary:
		return parent    # deep interior / deep air — untouched, the base stays solid by construction
	# Bilinear solidness at the fine cell centre (coarse-cell units) → a smooth 0..1 ramp across the edge.
	var wx: float = (float(fx) + 0.5) / float(SUBDIV)
	var wy: float = (float(fy) + 0.5) / float(SUBDIV)
	var solidness: float = _fine_bilinear(wx, wy)
	# EDGE noise bends the boundary (organic erosion/accretion); a slight net-erode opens cave mouths.
	var band: float = 1.0 - absf(solidness - 0.5) * 2.0     # full swing at the 0.5 edge, 0 deep in either
	var edge: float = _fine_edge.get_noise_2d(float(fx), float(fy)) * FINE_EDGE_AMP - FINE_EROSION_BIAS
	solidness = clampf(solidness + edge * band, 0.0, 1.0)
	# GRIT: near a face the rock crumbles/protrudes — high-freq noise adds bite that fades toward interior,
	# so exposed rock gets little pits + nubs (crunch), deep rock stays whole.
	var grit: float = _fine_grit.get_noise_2d(float(fx), float(fy)) * FINE_GRIT_BITE * band
	solidness = clampf(solidness + grit, 0.0, 1.0)
	return solidness >= 0.5


## Bilinear sample of coarse solidity (0/1 per cell, out-of-bounds = 0/air) at a fractional coarse
## position — turns the hard solid/air step into the smooth ramp the fine noise then bends.
func _fine_bilinear(wx: float, wy: float) -> float:
	var gx: float = wx - 0.5
	var gy: float = wy - 0.5
	var x0: int = int(floor(gx))
	var y0: int = int(floor(gy))
	var tx: float = gx - float(x0)
	var ty: float = gy - float(y0)
	var s00: float = 1.0 if solid.has(Vector2i(x0, y0)) else 0.0
	var s10: float = 1.0 if solid.has(Vector2i(x0 + 1, y0)) else 0.0
	var s01: float = 1.0 if solid.has(Vector2i(x0, y0 + 1)) else 0.0
	var s11: float = 1.0 if solid.has(Vector2i(x0 + 1, y0 + 1)) else 0.0
	return lerpf(lerpf(s00, s10, tx), lerpf(s01, s11, tx), ty)


## Build the fine-detail noise fields once, seeded off world_seed (deterministic; rebuilt if the seed
## changed under a reused sim, e.g. a title reroll → new load_world).
func _ensure_fine_noise() -> void:
	if _fine_edge != null and _fine_seed_built == world_seed:
		return
	_fine_seed_built = world_seed
	_fine_edge = FastNoiseLite.new()
	_fine_edge.seed = world_seed ^ 0x1f83d9ab
	_fine_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_fine_edge.frequency = FINE_EDGE_FREQ
	_fine_grit = FastNoiseLite.new()
	_fine_grit.seed = world_seed ^ 0x5be0cd19
	_fine_grit.noise_type = FastNoiseLite.TYPE_VALUE       # blocky value noise = crisp per-fine-cell grit
	_fine_grit.frequency = FINE_GRIT_FREQ


## The seed the fine noise fields were built for (so a reused sim rebuilds them when world_seed changes).
var _fine_seed_built: int = -0x7fffffff


## Mark a coarse terrain cell dirty: queue the chunk repaint AND re-mold its fine block (+ boundary band).
## The ONE place terrain edits announce a solid/wall change, so the fine grid can never drift from `solid`.
func _dirty_terrain(cell: Vector2i) -> void:
	terrain_dirty.append(cell)
	_sync_fine_block(cell)


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the
## cell was already open. Mining an ORE vein yields one ore into the player's pack — and that ore is
## genuinely produced from the world, so it counts toward total_produced (conservation stays true).
## The cell's background WALL is left intact (you carve the block, the wall stays behind).
func mine(cell: Vector2i) -> StringName:
	if not solid.has(cell):
		return &""
	_bazaars_dirty = true               # a mined block can break a bazaar frame → rescan lazily
	var material: StringName = solid[cell]
	if _is_ore_like(material):
		# HAND-mining an ore-like block (ore or coal) is a quick, inefficient grab: one strike clears the whole
		# block and pockets a handful of LOOSE ore (a 3-6 burst). The block's larger latent yield (`deposits`) is
		# NOT hand-extractable — that's the DRILL's job. You place a drill ABOVE a visible ore vein and it bores
		# DOWN through the solid ore, draining each cell dry (docs/MINING.md). So hand-mining is how you grab your
		# FIRST few ore (to craft the drill); the drill is how you mine the vein. The burst counts as produced
		# when it enters the pack; the discarded latent yield was never produced, so conservation holds.
		var burst: int = _ore_burst(cell)
		inventory[material] = int(inventory.get(material, 0)) + burst
		total_produced[material] = int(total_produced.get(material, 0)) + burst
		deposits.erase(cell)
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
		if material == &"wood":
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


func place_block(cell: Vector2i, material: StringName) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or rope.has(cell) or torch.has(cell):
		return false          # a roped cell refuses rock (cut the rope first — no rope-in-stone)
	if int(inventory.get(material, 0)) <= 0:
		return false
	_take_from_pack(material, 1)
	total_consumed[material] = int(total_consumed.get(material, 0)) + 1
	solid[cell] = material
	_dirty_terrain(cell)
	_bazaars_dirty = true               # a placed block can COMPLETE a bazaar frame → rescan lazily
	return true


## --- POWER CONDUITS (docs/POWER.md) — a placed layer, not a machine. The carried &"conduit" item is
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
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or conduit.has(cell):
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
	while in_bounds(c) and not solid.has(c) and not grid.has(c) and not rope.has(c) \
			and int(inventory.get(&"rope", 0)) > 0:
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


## Player action (FABLE_50 #39): RETRACT the whole rope through `cell` — walk up to its anchor, then
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


## --- TORCHES (FABLE_50 #26) — placeable LIGHT, another placed layer like rope/conduit. Not solid,
## not a machine: items fall through, collision never sees it. The sim only owns placement + the
## ledger; the WARM POOL it casts is pure representation (the renderer lights torch cells). Light is
## claimed territory in the black — the first light you can leave behind, before power arrives. ---

func has_torch(cell: Vector2i) -> bool:
	return torch.has(cell)


## Mount a carried &"torch" on an open cell. Needs a BACKING to hang from — a real wall behind the
## cell or any solid neighbour (no torches floating in open sky). Consumed into the ledger; removal
## produces it back, so the total ledger holds.
func place_torch(cell: Vector2i) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or torch.has(cell):
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


## --- SAPLINGS (FABLE_50 #38) — the renewable-wood loop. Chopped canopies hide seeds; plant one on
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


## The tick's growth sweep: every sapling ages one tick; a sapling whose cell got built over is CRUSHED
## (gone), one whose soil vanished is dropped as a ground item (it falls with the pile physics); at
## SAPLING_GROW_TICKS it sprouts a TREE — trunk height from the cell hash, the worldgen canopy shape —
## stamped only into cells still open, then the sapling entry retires.
func _grow_saplings() -> void:
	if sapling.is_empty():
		return
	var grown: Array[Vector2i] = []
	var dead: Array[Vector2i] = []
	var uprooted: Array[Vector2i] = []
	for cv: Variant in sapling:
		var c: Vector2i = cv
		if solid.has(c) or grid.has(c):
			dead.append(c)                              # built over — crushed
		elif not SAPLING_SOILS.has(solid.get(c + Vector2i(0, 1), &"")):
			uprooted.append(c)                          # soil mined out — the seed drops free
		else:
			sapling[c] = int(sapling[c]) + 1
			if int(sapling[c]) >= SAPLING_GROW_TICKS:
				grown.append(c)
	for c: Vector2i in dead:
		sapling.erase(c)
	for c: Vector2i in uprooted:
		sapling.erase(c)
		var pile: Dictionary = ground.get(c, {})
		pile[&"sapling"] = int(pile.get(&"sapling", 0)) + 1
		ground[c] = pile
		total_produced[&"sapling"] = int(total_produced.get(&"sapling", 0)) + 1   # back in play → ledgered
	for c: Vector2i in grown:
		sapling.erase(c)
		_stamp_tree(c)


## Stamp a tree with its trunk base at `base` (the sapling's cell): a 2-3 tall &"wood" trunk (height
## from the cell hash — deterministic) under the worldgen's rounded 3-wide &"leaves" canopy. Only cells
## still OPEN are stamped (a roof/machine simply prunes the tree). Stamped cells are world matter —
## chopping them produces wood/saplings, exactly like a worldgen tree.
func _stamp_tree(base: Vector2i) -> void:
	var trunk: int = 2 + absi((int(base.x) * 40503) ^ int(base.y)) % 2
	for h: int in range(0, trunk):
		var t: Vector2i = base + Vector2i(0, -h)
		if in_bounds(t) and not solid.has(t) and not grid.has(t) and not rope.has(t) and not torch.has(t):
			solid[t] = &"wood"
			_dirty_terrain(t)
	var ttr: int = base.y - trunk + 1                   # row of the topmost trunk cell
	for leaf: Vector2i in [
			Vector2i(base.x, ttr - 1), Vector2i(base.x, ttr - 2),
			Vector2i(base.x - 1, ttr - 1), Vector2i(base.x + 1, ttr - 1),
			Vector2i(base.x - 1, ttr), Vector2i(base.x + 1, ttr)]:
		if in_bounds(leaf) and not solid.has(leaf) and not grid.has(leaf) \
				and not rope.has(leaf) and not torch.has(leaf):
			solid[leaf] = &"leaves"
			_dirty_terrain(leaf)


## --- The BAZAAR (crafting hub, docs/CRAFTING.md) — detected as a structure in the world, not a machine.
## A bazaar is a distinctive WOOD FRAME with an open interior, sitting on solid ground:
##     W W W W      top beam (all wood)
##     W . . W      posts + open interior
##     W . . W      posts + open interior
##     . G G .      interior floor must be solid ground
## "Active" is DERIVED from the world (a valid frame == active) — no persistent state, so it stays
## deterministic + node-free, and a bazaar you rebuild elsewhere just works. The open interior + exact
## shape is what stops a plain wall/house from matching. (A second `log` material for extra robustness +
## the cozy look, and the NPC walk-in, are deferred — see docs/CRAFTING.md.)
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
var _bazaars_dirty: bool = true
func find_bazaars() -> Array[Vector2i]:
	if not _bazaars_dirty:
		return _bazaars_cache
	_bazaars_cache = []
	for y: int in range(0, GRID_ROWS - BAZAAR_H):
		for x: int in range(0, GRID_COLS - BAZAAR_W + 1):
			if is_bazaar_at(Vector2i(x, y)):
				_bazaars_cache.append(Vector2i(x, y))
	_bazaars_dirty = false
	return _bazaars_cache


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
## own item. Ore and coal both. (Coal is mined the same painful way → the demand-web, docs/MINING.md.)
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
	return 0


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
	if not in_bounds(cell) or grid.has(cell) or solid.get(cell, false) or rope.has(cell) or torch.has(cell):
		return null           # a roped cell refuses a machine too (cut the rope first)
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
	_compute_power()
	for machine: MachineState in machines:
		_run_machine(machine)
	_flow()
	_grow_saplings()
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


## FACTORY ALERTS (legibility — the alert stack, FABLE_NEXT_50 #29): machines that were meant to RUN but
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


## Rebuild the power field from scratch (docs/POWER.md): every FUELED generator stamps its innate aura,
## then power floods further out through the conduit network (down+lateral, never up). Pure derived state —
## cleared and recomputed each tick so it never desyncs from placement/fuel.
func _compute_power() -> void:
	power.clear()
	for machine: MachineState in machines:
		if _behavior_flag(machine.def, &"power_source") and machine.fuel > 0:
			_emit_aura(machine.cell, GENERATOR_POWER)
	if not conduit.is_empty():
		_flow_power_through_conduits()


## Stamp a generator's innate aura: an attenuating diamond (manhattan radius POWER_AURA) of power around
## `origin`. Overlapping auras take the MAX (a supply reading, not a sum — two generators don't conjure
## double power at a shared cell). The strength fades to 0 at the rim so the lit zone reads as a falloff.
func _emit_aura(origin: Vector2i, amount: float) -> void:
	for dy: int in range(-POWER_AURA, POWER_AURA + 1):
		for dx: int in range(-POWER_AURA, POWER_AURA + 1):
			var dist: int = absi(dx) + absi(dy)
			if dist > POWER_AURA:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if not in_bounds(cell):
				continue
			var v: float = amount * (1.0 - float(dist) / float(POWER_AURA + 1))
			power[cell] = maxf(float(power.get(cell, 0.0)), v)


## Available power at a cell (the derived field; 0.0 where none reaches). Consumers read this to throttle;
## the view tints it. Pure read — no mutation, determinism untouched (mirrors updraft_at / material_at).
func power_at(cell: Vector2i) -> float:
	return float(power.get(cell, 0.0))


## THE COST RULE, in one place (docs/POWER.md §7): the fraction of full speed a power consumer at `cell`
## gets, = clamp(available power / its demand, 0..1). 1.0 when fully supplied, proportionally less as the
## supply (attenuated by distance from the source) falls short — so the deep frontier, furthest from
## generation, browns out first for free. Every consumer routes its draw through this and nothing else.
func power_throttle(cell: Vector2i, demand: float) -> float:
	if demand <= 0.0:
		return 1.0
	return clampf(power_at(cell) / demand, 0.0, 1.0)


## Flood power through the conduit network in ONE top-to-bottom sweep (docs/POWER.md §7). Because power
## only flows DOWN + LATERAL (never up), the network is acyclic by row, so each row is finalized before
## the next reads it — no iterative solver. Per row: (1) VERTICAL inflow = the SUM of the feeders in the
## row above (generators + conduits), so two trunks merging make a thicker stream, clamped to the tube's
## CAPACITY (which also bounds any branch amplification). (2) HORIZONTAL spread = a lossy MAX delivery
## both ways along the row's conduits (carry power across, e.g. the foot of an L) — the L→R then R→L
## order is the deterministic tie-break that stops two side-by-side tubes from forming a same-row loop.
## Finally each conduit cell writes into the field and BLEEDS to its neighbours so adjacent machines draw.
func _flow_power_through_conduits() -> void:
	var carried: Dictionary = {}                       # conduit cell -> power it carries this tick
	# Touch only ACTUAL conduit cells, grouped by row, so a sparse network costs O(conduits), not O(grid).
	var by_row: Dictionary = {}                         # y -> Array[int] of conduit x's in that row
	for cell: Variant in conduit:
		var c: Vector2i = cell
		if not by_row.has(c.y):
			by_row[c.y] = ([] as Array[int])
		(by_row[c.y] as Array[int]).append(c.x)
	var rows: Array = by_row.keys()
	rows.sort()                                         # top→bottom: each row finalized before the next reads it
	for y: int in rows:
		var xs: Array[int] = by_row[y]
		xs.sort()
		# (1) vertical inflow from the row above (additive merge, capacity-clamped).
		for x: int in xs:
			var vin: float = 0.0
			for dx: int in [-1, 0, 1]:
				vin += _power_out_of(Vector2i(x + dx, y - 1), carried) * CONDUIT_V_KEEP
			carried[Vector2i(x, y)] = minf(vin, CONDUIT_CAPACITY)
		# (2) horizontal spread within the row: L→R then R→L lossy MAX (the same-row tie-break), only
		# transferring between conduits that are actually adjacent in this row.
		for i: int in range(1, xs.size()):
			if xs[i] == xs[i - 1] + 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxf(float(carried.get(cell, 0.0)), float(carried[Vector2i(xs[i - 1], y)]) * CONDUIT_H_KEEP)
		for i: int in range(xs.size() - 2, -1, -1):
			if xs[i] == xs[i + 1] - 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxf(float(carried.get(cell, 0.0)), float(carried[Vector2i(xs[i + 1], y)]) * CONDUIT_H_KEEP)
	# Merge the carried power into the field, and bleed it to neighbours so a machine beside a tube draws.
	for cell: Vector2i in carried:
		var v: float = float(carried[cell])
		power[cell] = maxf(float(power.get(cell, 0.0)), v)
		for nb: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + nb
			if in_bounds(n):
				power[n] = maxf(float(power.get(n, 0.0)), v * CONDUIT_BLEED)


## How much power a cell feeds DOWN into the conduit below it: a fueled generator pours its full output;
## a conduit passes the power it carries; anything else feeds nothing. Read during the top-down sweep, so
## a conduit feeder's `carried` value is already final (the row above was processed first).
func _power_out_of(cell: Vector2i, carried: Dictionary) -> float:
	if conduit.has(cell):
		return float(carried.get(cell, 0.0))
	var m: MachineState = grid.get(cell, null)
	if m != null and _behavior_flag(m.def, &"power_source") and m.fuel > 0:
		return GENERATOR_POWER
	return 0.0


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
	# PASS-THROUGH (FABLE_50 #49, the descent engine's rule generalized): every machine is a filter
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


## A LIFT runs no recipe: it carries items UP its column — the paid inverse of gravity (docs/POWER.md).
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
	# THE FILTER (FABLE_50 #49): a hopper KEEPS the first thing it tastes — the filter auto-latches on
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


## Read-only PLACEMENT PREVIEW for a drill hovered at `cell` — what the representation draws so a player
## sees, before committing, exactly which ore the drill will bore and where it will pour. Returns the ore
## cells it would extract (its whole column, top to bottom), the DROP cell just below the deepest ore (the
## out-point), and whether that drop is blocked. Empty ore_cells = not over any ore. Pure derivation.
func drill_preview(cell: Vector2i) -> Dictionary:
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


## A DRILL automates the by-hand ore mine (docs/MINING.md). It BORES STRAIGHT DOWN its column into the first
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
	var target: Vector2i = drill_target(machine.cell)
	if target.x < 0:
		return                          # nothing borable below — idle, hold progress
	if _drill_blocked(target):
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
	machine.fuel -= 1
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	# Drain one unit from the target solid ore cell (CLEARED when its deposit empties, carving the shaft). The
	# freed material is produced + ejected DOWN.
	var item: StringName = solid[target]                      # the solid ore block the drill bores into
	var amt: int = int(deposits.get(target, DEFAULT_ORE_DEPOSIT)) - 1
	if amt > 0:
		deposits[target] = amt
	else:
		deposits.erase(target)
		solid.erase(target)                                   # cell bored out → the shaft deepens
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


## THE HORIZONTAL DRILL (FABLE_50 #46, the user's spec): a coal-hungry sideways borer. Each cycle it
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
			_dirty_terrain(target)
			_bazaars_dirty = true
			_resettle_pile_above(target)
	else:
		solid.erase(target)
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


## A GENERATOR burns coal to pour power (docs/POWER.md). Each tick it spends one tick of its current fuel;
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
		if machine.output_buffer.is_empty():
			continue
		var dests: Array[Dictionary] = _destinations(machine)
		if dests.is_empty():
			continue                # no drain (a borer on solid rock): the haul POOLS in its belly
		if dests.size() == 1:
			_deliver(machine, dests[0], machine.output_buffer)
		else:
			# Split: deal each item unit along the machine's deal PATTERN via route_toggle — an even
			# round-robin by default; the splitter's R-cycled ratio mode weights it (FABLE_50 #49).
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


## Set a splitter's ratio DIRECTLY (the config panel's clickable chips, FABLE_50 #32 — R still cycles
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
## column, so it degrades to a plain pass-through (down only) — provisional edge, see docs/RISKS.md.
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
