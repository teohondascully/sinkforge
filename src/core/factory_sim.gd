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
## Ore-block RICHNESS (cell -> total yield), over SOLID ore cells (docs/MINING.md). Absent ore cell = 1.
## When you HAND-mine an ore block you get a burst of it (3-8) and the REMAINDER is revealed as a wall
## deposit (`ore_deposits`) a drill taps. Latent world resource, NOT "items present" — conservation-neutral.
var deposits: Dictionary = {}
## Exposed wall DEPOSITS (cell -> remaining yield), the cavity model: hand-mining an ore block clears the
## block and, if richness was left over, reveals a glittering deposit IN THE WALL of the now-open cell. A
## Drill placed on that open cell drains the pool, ejecting ore down its column until it runs dry. Also a
## latent pool (conservation-neutral); the ore is total_produced only as the drill actually extracts it.
var ore_deposits: Dictionary = {}
## What each exposed deposit YIELDS (cell -> item, &"ore"/&"coal"). Set when the block is mined, read by the
## Drill so it ejects the right material — so a drill on a coal cavity makes coal, on an ore cavity makes ore.
var deposit_item: Dictionary = {}
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
## DERIVED power field (cell -> available power units), rebuilt from scratch every tick by _compute_power
## from fueled generators (+ conduits, later). NOT authoritative state — a pure function of placement +
## fuel, like updraft_at — so it can never desync. Consumers read it via power_at(); the view tints it.
var power: Dictionary = {}
## Placed POWER CONDUITS: cell -> tier (int). A THIRD world layer alongside `solid` and `wall` — NOT a
## machine (so item-flow, collision, and the tick never touch it; the player walks through tubes). Carries
## power down+lateral in _compute_power. Authoritative state, mutated only by place_conduit/remove_conduit.
var conduit: Dictionary = {}

var _tick_accumulator: float = 0.0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


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
			return m.def.behavior == &"lift"  # first machine below is a lift → in its updraft
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


## Ingest a generated world (the gen→sim handshake): replace terrain with the WorldData's two grids.
## Only cells in bounds are taken. The avatar/machines are unaffected; this is the start-of-world
## seeding step that replaces the old hand-coded _seed_world terrain loop.
func load_world(world: WorldData) -> void:
	solid.clear()
	wall.clear()
	deposits.clear()
	ore_deposits.clear()
	deposit_item.clear()
	for cell: Vector2i in world.blocks:
		if in_bounds(cell):
			solid[cell] = world.blocks[cell]
	for cell: Vector2i in world.walls:
		if in_bounds(cell):
			wall[cell] = world.walls[cell]
	for cell: Vector2i in world.amounts:
		if in_bounds(cell):
			deposits[cell] = int(world.amounts[cell])


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the
## cell was already open. Mining an ORE vein yields one ore into the player's pack — and that ore is
## genuinely produced from the world, so it counts toward total_produced (conservation stays true).
## The cell's background WALL is left intact (you carve the block, the wall stays behind).
func mine(cell: Vector2i) -> StringName:
	if not solid.has(cell):
		return &""
	var material: StringName = solid[cell]
	if _is_ore_like(material):
		# CAVITY model (docs/MINING.md): one strike breaks the whole ORE-LIKE block (ore or coal — both drop
		# their own item the same way). You pocket a juicy BURST (3-8, capped by the vein's richness), the
		# block clears (wall kept), and any RICHNESS left over is revealed as a glittering wall DEPOSIT a
		# drill can tap (it remembers the material via deposit_item). Thin surface veins are a pure hand-grab
		# (no remainder → no deposit); deep rich veins leave a big deposit to automate (deeper = richer).
		var richness: int = int(deposits.get(cell, 1))
		var burst: int = mini(richness, _ore_burst(cell))
		inventory[material] = int(inventory.get(material, 0)) + burst
		total_produced[material] = int(total_produced.get(material, 0)) + burst
		deposits.erase(cell)
		solid.erase(cell)
		var remainder: int = richness - burst
		if remainder > 0:
			ore_deposits[cell] = remainder
			deposit_item[cell] = material
		_resettle_pile_above(cell)          # the floor under any resting pile just vanished — it falls
		return material
	if _is_foliage(material):
		# Foliage chops BLOCK-BY-BLOCK (Terraria/Minecraft), never flood-felling the whole tree on one hit —
		# you carve a tree down trunk by trunk. Wood yields one wood per block (a built structure, e.g. the
		# bazaar frame, behaves identically — mirrors place_block's consume, so conservation holds); leaves
		# yield nothing. The whole-tree fell was removed (it read as "broke one block, the whole thing broke").
		solid.erase(cell)
		if material == &"wood":
			inventory[&"wood"] = int(inventory.get(&"wood", 0)) + 1
			total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + 1
		_resettle_pile_above(cell)
		return material
	# Plain terrain (earth/stone/deepslate): Terraria dig-and-carry — pocket the block as a placeable item
	# so you can re-place it to bridge a gap, backfill, or PILLAR out of a hole. Produced from the world +
	# consumed on placement (place_block) → conservation holds, symmetric with mining a placed block back.
	solid.erase(cell)
	inventory[material] = int(inventory.get(material, 0)) + 1
	total_produced[material] = int(total_produced.get(material, 0)) + 1
	_resettle_pile_above(cell)               # gravity: a pile that rested on this block now falls
	return material


## Player action: PLACE a building-material block from the pack into an open cell (the Terraria build
## primitive — the inverse of mine). Consumes one `material` from the pack; the cell becomes solid. Like
## crafting, the spent item is counted as CONSUMED, and mining it back counts as produced, so conservation
## holds across build/dig (terrain isn't "items present"). Refuses solid/occupied/out-of-bounds cells.
func place_block(cell: Vector2i, material: StringName) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell):
		return false
	if int(inventory.get(material, 0)) <= 0:
		return false
	_take_from_pack(material, 1)
	total_consumed[material] = int(total_consumed.get(material, 0)) + 1
	solid[cell] = material
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
## Refuses solid/occupied/already-piped/out-of-bounds cells. Returns whether it went down.
func place_conduit(cell: Vector2i) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell) or conduit.has(cell):
		return false
	if int(inventory.get(&"conduit", 0)) <= 0:
		return false
	_take_from_pack(&"conduit", 1)
	conduit[cell] = 1                       # tier 1 (the only tier for now)
	return true


## Pick a placed conduit back up into the pack (mirrors pickup_machine). Returns whether one was there.
func remove_conduit(cell: Vector2i) -> bool:
	if not conduit.has(cell):
		return false
	conduit.erase(cell)
	inventory[&"conduit"] = int(inventory.get(&"conduit", 0)) + 1
	return true


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
func find_bazaars() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(0, GRID_ROWS - BAZAAR_H):
		for x: int in range(0, GRID_COLS - BAZAAR_W + 1):
			if is_bazaar_at(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


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
	return material == &"ore" or material == &"coal"


## The hand-mined BURST size for an ore cell — a juicy 3-8, deterministic per cell (a stable hash, no RNG
## → determinism-safe) so a given vein always drops the same amount. The actual drop is capped by the
## vein's richness (a thin vein gives less).
func _ore_burst(cell: Vector2i) -> int:
	var h: int = (int(cell.x) * 73856093) ^ (int(cell.y) * 19349663)
	return 3 + (absi(h) % 6)   # 3..8


## Remaining yield of the exposed wall deposit at `cell` (0 if none) — read by the Drill, the hover
## inspector, and the renderer's glitter so all three agree on "how much ore is left in this cavity".
func ore_deposit_at(cell: Vector2i) -> int:
	return int(ore_deposits.get(cell, 0))


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
	return n


## Player action: CRAFT one machine item into the pack, spending its `craft_cost` from inventory.
## Returns true if crafted. Spent items are counted as consumed so conservation holds (crafting is
## a real ingot sink). The machine item (keyed by def.id) lives in the same pack as ore/ingots.
func craft(def: MachineDef) -> bool:
	if def.craft_cost.is_empty():
		return false
	for item: StringName in def.craft_cost:
		if int(inventory.get(item, 0)) < int(def.craft_cost[item]):
			return false
	for item: StringName in def.craft_cost:
		var n: int = int(def.craft_cost[item])
		_take_from_pack(item, n)
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	inventory[def.id] = int(inventory.get(def.id, 0)) + 1
	return true


## Player action: place a machine you CARRY — consumes one machine item (def.id) from the pack and
## places it. Returns the MachineState, or null if you don't carry one or the cell is blocked.
func build_from_pack(def: MachineDef, cell: Vector2i) -> MachineState:
	if int(inventory.get(def.id, 0)) <= 0:
		return null
	var state: MachineState = place_machine(def, cell)
	if state == null:
		return null
	_take_from_pack(def.id, 1)
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
	inventory[state.def.id] = int(inventory.get(state.def.id, 0)) + 1
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
	if not in_bounds(cell) or grid.has(cell) or solid.get(cell, false):
		return null
	var state: MachineState = MachineState.new(def, cell)
	grid[cell] = state
	machines.append(state)
	return state


## Remove the machine at a cell (if any). Its buffered items are discarded.
func remove_machine(cell: Vector2i) -> void:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return
	grid.erase(cell)
	machines.erase(state)


## Advance by real elapsed time, running only whole fixed ticks (deterministic, framerate-
## independent). The game loop calls this; tests call tick() directly.
func advance(delta: float) -> void:
	_tick_accumulator += delta
	while _tick_accumulator >= SECONDS_PER_TICK:
		_tick_accumulator -= SECONDS_PER_TICK
		tick()


## One deterministic logical step: derive the power field, every machine runs (consumers read the field),
## then items fall one stage downward.
func tick() -> void:
	_compute_power()
	for machine: MachineState in machines:
		_run_machine(machine)
	_flow()


## Rebuild the power field from scratch (docs/POWER.md): every FUELED generator stamps its innate aura,
## then power floods further out through the conduit network (down+lateral, never up). Pure derived state —
## cleared and recomputed each tick so it never desyncs from placement/fuel.
func _compute_power() -> void:
	power.clear()
	for machine: MachineState in machines:
		if machine.def.behavior == &"generator" and machine.fuel > 0:
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
	if m != null and m.def.behavior == &"generator" and m.fuel > 0:
		return GENERATOR_POWER
	return 0.0


func _run_machine(machine: MachineState) -> void:
	if machine.def.behavior == &"lift":
		_run_lift(machine)
		return
	if machine.def.behavior == &"splitter":
		_run_splitter(machine)
		return
	if machine.def.behavior == &"drill":
		_run_drill(machine)
		return
	if machine.def.behavior == &"generator":
		_run_generator(machine)
		return
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
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


## A DRILL automates the by-hand ore mine (docs/MINING.md, cavity model): you hand-mine an ore block first
## (the friction that earns the automation), exposing a wall DEPOSIT; placed ON that open cavity cell, the
## drill taps `ore_deposits` AT ITS OWN CELL, draining one unit per cycle and ejecting one ore DOWN its
## column (gravity carries it to a forge/collection). Off a deposit → it idles. When the deposit runs dry
## the drill goes quiet ("patch exhausted — relocate it"). The ore is genuinely produced from the world →
## total_produced (same accounting as hand-mining); it draws from the WORLD, not an input buffer, so its
## output is ejected here, not via the normal output-buffer _flow.
func _run_drill(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	var pool: int = int(ore_deposits.get(machine.cell, 0))
	if pool <= 0:
		return                          # not on an exposed deposit — idle, hold progress
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
	var item: StringName = StringName(deposit_item.get(machine.cell, &"ore"))   # the deposit's own material
	pool -= 1
	if pool > 0:
		ore_deposits[machine.cell] = pool
	else:
		ore_deposits.erase(machine.cell)   # deposit spent — drill idles next cycle
		deposit_item.erase(machine.cell)
	# Eject the freed material DOWN the drill's own column, where gravity carries it to a forge/collection.
	total_produced[item] = int(total_produced.get(item, 0)) + 1
	var dest: Dictionary = _column_landing(machine.cell.x, machine.cell.y + 1)
	dest["target"][item] = int(dest["target"].get(item, 0)) + 1
	flow_events.append({"item": item, "from": machine.cell, "to": dest["to_cell"], "count": 1})


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
		if dests.size() == 1:
			_deliver(machine, dests[0], machine.output_buffer)
		else:
			# Split: deal each item unit to the next destination round-robin via route_toggle.
			var n: int = dests.size()
			var portions: Array[Dictionary] = []
			for _i: int in n:
				portions.append({})
			for item: StringName in machine.output_buffer:
				for _c: int in int(machine.output_buffer[item]):
					var idx: int = machine.route_toggle % n
					machine.route_toggle += 1
					portions[idx][item] = int(portions[idx].get(item, 0)) + 1
			for i: int in n:
				if not portions[i].is_empty():
					_deliver(machine, dests[i], portions[i])
		machine.output_buffer.clear()


## Move a bundle of items from `machine` into one destination, logging the cosmetic flow event.
func _deliver(machine: MachineState, dest: Dictionary, bundle: Dictionary) -> void:
	var target: Dictionary = dest["target"]
	var to_cell: Vector2i = dest["to_cell"]
	for item: StringName in bundle:
		var count: int = int(bundle[item])
		target[item] = int(target.get(item, 0)) + count
		flow_events.append({"item": item, "from": machine.cell, "to": to_cell, "count": count})


## Where a machine's output goes. Each destination is {to_cell: Vector2i, target: Dictionary}.
## Default: one destination straight down. Splitter: down + the column to the right. A splitter
## hard against the right wall has no second column, so it degrades to a plain pass-through (down
## only) — provisional edge behaviour, see docs/RISKS.md.
func _destinations(machine: MachineState) -> Array[Dictionary]:
	var x: int = machine.cell.x
	var y: int = machine.cell.y
	if machine.def.behavior == &"lift":
		return [_column_rise(x, y - 1)]  # the inverse of gravity: this machine's output goes UP
	var down: Dictionary = _column_landing(x, y + 1)
	if machine.def.behavior != &"splitter":
		return [down]
	var right_col: int = x + 1
	if right_col >= GRID_COLS:
		return [down]
	# Diverted items move sideways into the right column at the splitter's row, then fall.
	return [down, _column_landing(right_col, y)]


## Where a spat product lands, scanning down `col` from `start_row`: the first machine below catches
## it (cascade), else it rests on top of the first solid floor as a physical ground pile. A column
## dug clear to the bottom drops it into the void sink (conservation-only).
func _column_landing(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, GRID_ROWS):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := Vector2i(col, row - 1)  # the open cell on top of the floor
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, GRID_ROWS), "target": sink}


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
