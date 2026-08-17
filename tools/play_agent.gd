class_name PlayAgent
extends RefCounted

## PlayAgent — the embodied test-driver. It PLAYS the real game: it moves the real Player body with
## real platformer physics and triggers the real, reach-gated verbs on MainView (try_mine / try_build /
## try_deposit / try_craft / select) — the SAME surface a human drives with mouse + keys. Nothing here
## reaches past the verb layer to fake a result; if the body can't walk to a cell, it can't mine it,
## exactly like a player. That's what makes a passing play-test mean "a person could actually do this".
##
## Actions are async (await the tree's physics_frame) so a goal reads as a linear script:
##   await agent.dig_down_to(ore); await agent.deposit_into_forge(); ...
## with generous frame budgets and a give() hatch to INJECT resources for setup (e.g. top up ingots
## before testing crafting) — the user-sanctioned shortcut for "arrange the situation, then play it".
##
## Used by tools/play_tests.gd (the scripted test TYPE).

const CELL: int = 32

var tree: SceneTree
var main: MainView
var sim: FactorySim
var player: Player

## A running narration of what the agent did — printed by the harness so a failure is legible.
var trace: Array[String] = []

## Behaviour instrumentation (printed per goal so we ANALYZE how the agent moved, not just pass/fail):
## how many times it jumped, bridged a gap, built a stair, and how many frames it spent making no progress.
## Runaway counts here are a red flag (e.g. thrashing/jumping in place) even when a goal passes.
var jumps: int = 0
var builds: int = 0
var stuck_frames: int = 0
## FRICTION metrics — the byproduct-effort a real player spends getting places (not just did-the-goal-happen).
## A high count here is the friction the user feels: mines = blocks broken, places = blocks laid (staircases/
## pillars to get back up), frames = time spent. The mobility tools (rope/lift) should make these PLUMMET.
var mines: int = 0
var places: int = 0
var frames: int = 0
var _jump_cool: int = 0


## Jump, rate-limited + counted — so the agent can't thrash by jumping every frame (and so we can SEE it).
func _do_jump() -> void:
	if _jump_cool > 0:
		return
	player.request_jump()
	jumps += 1
	_jump_cool = 14


## One-line behaviour summary for the harness to log + me to read.
func stats() -> String:
	return "jumps=%d builds=%d stuck_frames=%d" % [jumps, builds, stuck_frames]


## Friction summary — the byproduct effort spent this journey (the play-FEEL numbers, not pass/fail).
func friction() -> String:
	return "mines=%d places=%d jumps=%d frames=%d stuck=%d | PEAKBULK=%d HANDED=%d MINED=%d%s | peak carried: %s" % [mines, places, jumps, frames, stuck_frames, peak_bulk, handed_bulk, maxi(0, peak_bulk - handed_bulk), ("" if unclassified.is_empty() else " UNCLASSIFIED=" + str(unclassified.keys())), peaks()]


## PEAK CARRIED QUANTITY PER ITEM, across this agent's whole journey.
##
## Measured because a bulk carry cap is being designed (T1.0) and nobody knows what the fixtures actually
## hold. `factory_sim.gd:207` records that no capacity is enforced "yet — a knob to turn when trip-friction
## is the thing being tuned", which is exactly now; the risk of turning it blind is that a fixture which has
## always relied on infinite pockets goes red and is indistinguishable from a real regression. That
## attribution problem is what made check_frametime expensive, so the number comes first this time.
##
## Sampled rather than hooked into the sim: the sim is not mine to instrument, and every accumulation this
## project cares about passes through a frame boundary or a mine, both of which are here.
var peak: Dictionary = {}

## WHAT COUNTS AS BULK — the set the carry cap would govern.
##
## The user's shape is that tools and construction components stay convenient while raw ore and bulk
## freight consume cargo capacity, so the two lists are separate and BOTH are enumerated. Anything in
## neither is reported as UNCLASSIFIED rather than silently assumed harmless: a hand-kept list that fails
## open is the defect this project has found in the icon list, the CI job list and the worktree count, and
## a new material appearing here would otherwise vanish from the measurement that picks the cap.
const BULK: Array[StringName] = [&"ore", &"rich_ore", &"ingot", &"earth", &"stone", &"deepslate",
	&"coal", &"iron", &"plate", &"gravel", &"sand", &"clay"]
const CARRIED_FREE: Array[StringName] = [&"rope", &"conduit", &"torch", &"wood", &"sapling", &"leaves"]

## Peak of the SUM over BULK, which is the quantity a PACK actually limits.
##
## The first version of this recorded only per-item peaks, and a curve built on those models a per-item
## cap — under which you could carry 20 of each of eight bulk items and never trip a "20 limit", which is
## not a limited pack, it is eight limited packs. Peaks of different items also need not co-occur, so the
## per-item numbers cannot be re-sliced into this one; it has to be sampled at the same instant.
var peak_bulk: int = 0
var handed_bulk: int = 0              ## bulk held at the FIRST sample — the loadout, before any mining
var _sampled_once: bool = false
var unclassified: Dictionary = {}


func _sample_peak() -> void:
	var total: int = 0
	for item: StringName in main.sim.inventory:
		var n: int = int(main.sim.inventory[item])
		if n > int(peak.get(item, 0)):
			peak[item] = n
		if BULK.has(item):
			total += n
		elif not CARRIED_FREE.has(item) and not String(item).contains("pickaxe"):
			unclassified[item] = n
	if total > peak_bulk:
		peak_bulk = total
	if not _sampled_once:
		_sampled_once = true
		handed_bulk = total


## The peaks as a printable line, biggest first. Empty if the journey never carried anything.
func peaks() -> String:
	var items: Array = peak.keys()
	items.sort_custom(func(a: StringName, b: StringName) -> bool: return int(peak[a]) > int(peak[b]))
	var parts: PackedStringArray = PackedStringArray()
	for i: StringName in items:
		parts.append("%s=%d" % [String(i), int(peak[i])])
	return " ".join(parts) if parts.size() > 0 else "(carried nothing)"


## A COUNTED frame-wait (used by journey code so `frames` measures how long a byproduct step really took).
func step() -> void:
	await tree.physics_frame
	frames += 1
	_sample_peak()


## Mine a cell through the real verb, counting it as friction. Returns whether the strike landed.
func do_mine(cell: Vector2i) -> bool:
	var ok: bool = main.try_mine(cell)
	if ok:
		mines += 1
		_sample_peak()
	return ok


## Place the selected item at a cell through the real verb, counting it as friction. Returns success.
func do_build(cell: Vector2i) -> bool:
	var ok: bool = main.try_build(cell)
	if ok:
		places += 1
	return ok


func _init(scene_tree: SceneTree, main_view: MainView) -> void:
	tree = scene_tree
	main = main_view
	sim = main.sim
	player = main._player
	player.auto_input = false   # the agent, not the keyboard, drives the body


func _note(msg: String) -> void:
	trace.append(msg)


# --- primitive motion -----------------------------------------------------------------------------

## Advance the live game by N physics frames (the sim ticks, the body integrates, ground auto-collects).
func wait(frames: int) -> void:
	for _i: int in frames:
		await tree.physics_frame


## Hold a jump for a couple of frames.
func jump() -> void:
	player.request_jump()
	jumps += 1
	await wait(2)


## Walk toward a cell until it's within reach — and when walking alone fails, BUILD the way there
## (Terraria dig-and-build, the behaviour the play-tester expects a smart agent to have): bridge a gap the
## body would fall into, and build a stair up a wall / out of a pit. Uses the dirt the agent has dug (every
## mined block is now a placeable item). Returns whether the cell ended up reachable — a real failure only
## when even building can't get there (out of blocks, or genuinely walled).
func approach(cell: Vector2i, budget: int = 600) -> bool:
	var last_x: float = player.position.x
	var still: int = 0                                 # consecutive frames with ~no horizontal progress
	var t: int = 0
	while t < budget:
		if main._can_reach(cell):
			player.input_dir = 0.0
			return true
		var dx: float = main._cell_center(cell).x - player.position.x
		var dir: int = signi(int(dx)) if absf(dx) > 3.0 else 0
		player.input_dir = float(dir)
		_jump_cool = maxi(0, _jump_cool - 1)
		# Only ever jump/build for a REASON (a gap or a wall in the way) — never blindly, so the agent
		# can't thrash by hopping in place. Everything is on a jump cooldown + counted.
		if player.on_floor and dir != 0:
			var here: Vector2i = main._cell_at(player.position)
			var ahead: Vector2i = here + Vector2i(dir, 0)
			var ahead_floor: Vector2i = here + Vector2i(dir, 1)
			var progressing: bool = absf(player.position.x - last_x) > 0.4
			if not sim.is_solid(ahead) and not sim.is_solid(ahead_floor):
				# A GAP ahead: jump it if there's a landing within a short hop, else bridge it with a block.
				if sim.is_solid(here + Vector2i(dir * 2, 1)) or sim.is_solid(here + Vector2i(dir * 3, 1)):
					_do_jump()
				elif _select_block() and main._can_reach(ahead_floor) and main._placeable(ahead_floor):
					main.try_build(ahead_floor)
					builds += 1
			elif not progressing and sim.is_solid(ahead):
				# A WALL/step ahead we're not getting past.
				var up: Vector2i = here + Vector2i(dir, -1)     # the cell diagonally up-forward
				if not sim.is_solid(up):
					_do_jump()                             # 1-tall step → the AABB step-up lands it
				elif _select_block():
					if main._can_reach(up) and main._placeable(up):
						_do_jump()                         # taller step → build a stair up-forward and hop on
						await wait(3)
						main.try_build(up)
						builds += 1
					elif cell.y <= here.y:
						# Boxed in below the target (a pit whose side is solid ground) → PILLAR straight up:
						# jump, then drop a block into the cell just vacated under the feet, and land on it.
						_do_jump()
						await wait(5)
						var under: Vector2i = main._cell_at(player.position) + Vector2i(0, 1)
						if main._can_reach(under) and main._placeable(under):
							main.try_build(under)
							builds += 1
		if absf(player.position.x - last_x) < 0.3 and player.on_floor:
			still += 1
			stuck_frames += 1
		else:
			still = 0
		last_x = player.position.x
		await tree.physics_frame
		t += 1
		if still > 150:                                    # ~2.5s of genuinely no progress → stop wasting budget
			break
	player.input_dir = 0.0
	return main._can_reach(cell)


## Select any placeable BLOCK the agent is carrying (dug dirt/stone/wood), so it can bridge/pillar. Returns
## whether one got selected. Prefers plentiful dirt/stone over the scarcer wood.
func _select_block() -> bool:
	for item: StringName in [&"earth", &"stone", &"deepslate", &"wood"]:
		if int(sim.inventory.get(item, 0)) > 0:
			return select_item(item)
	return false


# --- game verbs (each goes through MainView's reach-gated surface) ---------------------------------

## Walk to a solid cell and mine it (genuinely — must be reachable). Returns whether it's now clear.
func mine_cell(cell: Vector2i, budget: int = 720) -> bool:
	if not await approach(cell, budget):
		_note("could not reach %s to mine it" % cell)
		return false
	var t: int = 0
	while sim.is_solid(cell) and t < 30:
		if main.try_mine(cell):
			mines += 1
		await wait(2)
		t += 1
	return not sim.is_solid(cell)


## Walk along the surface until the body's own column is `col` (and it's standing, not mid-air). The
## prerequisite for sinking a straight shaft — you have to be standing over it first.
func walk_to_column(col: int, budget: int = 600) -> bool:
	var col_x: float = main._cell_center(Vector2i(col, 0)).x
	var last_x: float = player.position.x
	var still: int = 0
	var t: int = 0
	while t < budget:
		var here_cell: Vector2i = main._cell_at(player.position)
		if here_cell.x == col and player.on_floor:
			if await _settle(col):
				return true
			# Coasted a cell too far. That is a miss, not an arrival — fall back into the loop and walk
			# it off, exactly as a player who overshot a doorway would.
			last_x = player.position.x
			continue
		var dir: int = signi(int(col_x - player.position.x))
		# ARRIVE STOPPED (#S9). The body now builds a RUN over a long hold, and a long hold is exactly what
		# walking across the map is — so the agent used to reach its column at 222 px/s and be carried off
		# the spot by its own momentum before it could act on it. (It cost RUNG 4 the borer socket: the
		# floor came out from under a sliding body and the step-up put it two rows higher and a column
		# over, out of reach of the hole it had just started.) A player brakes on approach without being
		# told to; the agent has to be. Release inside the last cell and coast in — friction alone kills a
		# full stride in about that distance, so it lands on the mark instead of skidding past it.
		if absf(col_x - player.position.x) < BRAKE_DIST and absf(player.velocity.x) > Player.RUN_SPEED:
			dir = 0
		player.input_dir = float(dir)
		_jump_cool = maxi(0, _jump_cool - 1)
		if player.on_floor and dir != 0:
			var ahead: Vector2i = here_cell + Vector2i(dir, 0)
			var ahead_floor: Vector2i = here_cell + Vector2i(dir, 1)
			var progressing: bool = absf(player.position.x - last_x) > 0.4
			# Gap ahead → hop it (there's almost always a near landing on the surface); wall ahead + stuck → hop.
			if not sim.is_solid(ahead) and not sim.is_solid(ahead_floor):
				_do_jump()
			elif not progressing and sim.is_solid(ahead):
				_do_jump()
		if absf(player.position.x - last_x) < 0.3 and player.on_floor:
			still += 1
			stuck_frames += 1
		else:
			still = 0
		last_x = player.position.x
		await tree.physics_frame
		t += 1
		if still > 150:
			break
	player.input_dir = 0.0
	return main._cell_at(player.position).x == col


## How close to the target column the agent stops pushing, and how settled "arrived" means. A stride is
## worth 232 px/s and friction rubs that off in about 24 px, so one cell of coast is the honest number.
const BRAKE_DIST: float = 28.0
const SETTLE_SPEED: float = 8.0        ## px/s under which the body counts as standing still
const SETTLE_FRAMES: int = 40          ## ...and how long it is given to get there


## Come to rest on the arrival column before reporting arrival. Returns whether the body is actually
## still there once it has stopped — coasting a cell too far is a miss, and must read as one.
func _settle(col: int) -> bool:
	player.input_dir = 0.0
	for _i: int in SETTLE_FRAMES:
		if absf(player.velocity.x) <= SETTLE_SPEED and player.on_floor:
			break
		await tree.physics_frame
	return main._cell_at(player.position).x == col


## Dig a straight vertical shaft down to `cell`, the by-hand "go get the buried vein" loop: stand over
## the column, mine the cell under the feet, FALL into it, repeat — exactly how a player sinks a shaft.
## Digging is GATED on staying centred over the column (so it sinks plumb, never carving off sideways),
## and the vein itself is mined the moment it's in reach. Returns whether the target got mined.
##
## TWO CONTRACTS LIVE HERE, and until the first eight-seed corpus sweep only one of them was true.
##
##   require_arrival = false (default) — "MAKE THIS CELL NOT SOLID". The buried-vein case, and what almost
##     every caller wants: the ore goes in the pack and where the body ends up is nobody's business.
##   require_arrival = true — "PUT THE BODY DOWN THERE". For callers that use the shaft to reach a PLACE,
##     not a resource: a capture, a frame to judge, a descent to time.
##
## They differ on exactly one world: the one where the target is ALREADY open. A cave, a void, an old
## shaft — `is_solid` is false on the first iteration, and this returned true immediately, having dug
## nothing and gone nowhere. For contract one that is correct and even efficient. For contract two it is a
## silent no-op that leaves the body standing in daylight while the caller believes it is 16 rows down.
##
## That is not hypothetical. `check_underground` spent its whole life this way on seed 99, which has a void
## under the spawn column: it judged a sunlit surface frame against a dead-space standard written for
## lamp-lit deep rock, scored 23%, and reported it as the rock failing. Seven other seeds dug their shaft
## and scored 0%. See the audit notes, Strike 11.
##
## The default is unchanged on purpose. Twenty-two call sites use this and most of them mean contract one;
## quietly giving all of them a new meaning to fix one caller would be trading a known bug for an unknown
## number of them.
##
## ARRIVE_SLACK is measured, not chosen: across the committed corpus every successful descent settles the
## body two rows above the deepest cell it cut, because `_cell_at` reports the centre and the miner stands
## ON the floor. Three leaves one row of margin.
const ARRIVE_SLACK: int = 3

func dig_down_to(cell: Vector2i, budget: int = 2400, require_arrival: bool = false) -> bool:
	var col: int = cell.x
	var col_x: float = main._cell_center(Vector2i(col, 0)).x
	if not await walk_to_column(col):
		_note("could not walk over column %d" % col)
		return false
	var t: int = 0
	while t < budget:
		if not sim.is_solid(cell) and _arrived(cell, require_arrival):
			player.input_dir = 0.0
			return true                              # the vein is mined → in the pack
		var dx: float = col_x - player.position.x
		var centred: bool = absf(dx) < 6.0
		player.input_dir = 0.0 if centred else signf(dx)
		# Only sink while plumb over the column. The cell to cut is the first SOLID cell straight DOWN
		# the column from the body — asking the COLUMN, not the toes: a feet-probe lies whenever the
		# body is held up by a surface ramp or a straddled ledge (the walkable surface can float the
		# body a full row above the column's own solid, and the probe reads open air forever).
		if centred and player.on_floor:
			var work := Vector2i(col, main._cell_at(player.position).y + 1)
			while work.y < cell.y and not sim.is_solid(work):
				work.y += 1
			if sim.is_solid(work) and main._can_reach(work):
				if main.try_mine(work):
					mines += 1
			if main._can_reach(cell):
				if main.try_mine(cell):
					mines += 1
		await tree.physics_frame
		t += 1
	player.input_dir = 0.0
	_note("ran out of budget digging to %s (stuck near %s)" % [cell, main._cell_at(player.position)])
	return not sim.is_solid(cell) and _arrived(cell, require_arrival)


## Whether the descent counts as finished. Under contract one it always does — the cell is open, which was
## the whole ask. Under contract two the BODY has to be down there too.
func _arrived(cell: Vector2i, require_arrival: bool) -> bool:
	if not require_arrival:
		return true
	return main._cell_at(player.position).y >= cell.y - ARRIVE_SLACK


## Climb from the bottom of a shaft back UP to the surface — the BYPRODUCT step a player MUST do after
## digging down. TWO strategies, in the order a real player reaches for them:
##   1. THE ROPE (the placeable climb): hang a rope from the highest in-reach open cell straight above —
##      it UNROLLS down to the body — and RIDE it up, re-anchoring as the reach extends. A deep climb
##      costs a handful of places and ZERO jumps: the friction fix, measured.
##   2. PILLAR-JUMPING (the rope-less fallback): jump, drop a block into the cell just vacated under the
##      feet, land on it, repeat — kept so a rope-less loadout still escapes (never TRAPPED), and so the
##      pit journey still measures how bad the pre-rope loop is.
## Returns whether the body reached the surface.
func climb_to_surface(target_row: int, budget: int = 4000) -> bool:
	var t: int = 0
	var stall: int = 0
	var rope_stall: int = 0
	var prev: Vector2 = player.position
	while t < budget:
		var bc: Vector2i = main._cell_at(player.position)
		if bc.y <= target_row and player.on_floor:
			player.input_dir = 0.0
			player.input_climb = 0.0
			return true                                  # back on the surface
		# --- strategy 1: the rope. (Re-)anchor when the cell above the body isn't roped yet, then ride.
		if bc.y > target_row and int(sim.inventory.get(&"rope", 0)) > 0 and select_item(&"rope") \
				and not (sim.is_climbable(bc) and sim.is_climbable(bc + Vector2i(0, -1))):
			var anchor: Vector2i = _rope_anchor_above(bc)
			if anchor.y >= 0:
				do_build(anchor)                          # hang it — it unrolls down to us
		if sim.is_climbable(bc):
			# AT THE LIP — but only if there IS a lip. Reaching the target ROW is not the same as being
			# level with somewhere to stand: when a shaft's mouth sits flush with the ground beside it (a
			# rolling surface makes that common, and a 2-wide shaft makes it worse) the body would stop
			# climbing exactly one row short and leap sideways into the shaft's OWN second column, fall
			# back down, and do it again until the budget ran out. Keep riding until a floored side
			# actually exists; the rope-stall escape below still covers a top that can't be exited at all.
			if bc.y <= target_row and _floored_exit(bc) != 0.0:
				player.input_climb = 0.0                  # LEAP off toward the exit side (the human move;
				player.input_dir = _floored_exit(bc)      # walking can ping-pong between two adjacent
				if player.climbing:                        # roped shaft mouths)
					_do_jump()
			else:
				player.input_dir = 0.0
				player.input_climb = 1.0                  # ride up
			await step(); t += 1
			if (player.position - prev).length() > 0.8:
				rope_stall = 0
			else:
				rope_stall += 1
				stuck_frames += 1
				if rope_stall == 35:                      # pinned at a rope top that can't extend (e.g. a
					var d: float = _exit_dir(bc)           # tree trunk caps the column) → LEAP off sideways
					_do_jump()                             # and continue from wherever that lands
					for _r: int in 30:
						player.input_climb = 0.0
						player.input_dir = d
						await step(); t += 1
					player.input_dir = 0.0
					prev = player.position
					continue
				if rope_stall > 90:                       # ~1.5s pinned even after the leap → genuinely wedged
					_note("climb: rope-stalled at %s" % main._cell_at(player.position))
					return false
			prev = player.position
			continue
		player.input_climb = 0.0
		rope_stall = 0
		prev = player.position
		player.input_dir = 0.0                           # stay plumb so we land back on the pillar
		if not player.on_floor:
			await step(); t += 1
			continue
		if not _select_block():
			_note("climb: out of blocks to pillar with at %s" % bc)
			return false
		# PILLAR up one cell: jump, and the MOMENT the feet clear the cell we were standing in, drop a block
		# into it — the body then falls onto that block, one cell higher. This is the fiddly timing a player
		# fights by hand; the agent nails it, so the friction shows up as sheer COUNT (jumps/places), not luck.
		var stand: Vector2i = main._cell_at(player.position + Vector2(0.0, Player.HEIGHT * 0.5 - 2.0))
		player.request_jump()
		jumps += 1
		var placed: bool = false
		for _w: int in 24:
			await step(); t += 1
			var feet_y: float = player.position.y + Player.HEIGHT * 0.5
			if feet_y <= float(stand.y * CELL) - 4.0:    # feet risen clear above the stand cell → safe to fill it
				if main._placeable(stand) and main._can_reach(stand):
					placed = do_build(stand)
				break
		for _l: int in 16:                               # settle back down onto the new block
			await step(); t += 1
			if player.on_floor:
				break
		if main._cell_at(player.position).y < bc.y:
			stall = 0                                    # rose a cell → progress
		else:
			stall += 1
			stuck_frames += 1
			if stall > 8:                                # several cycles, no ascent → genuinely trapped
				_note("climb: STALLED at %s (placed=%s) — couldn't get back up (trapped)" % [bc, placed])
				return false
	_note("climb: ran out of budget at %s" % main._cell_at(player.position))
	return main._cell_at(player.position).y <= target_row


## The highest open, in-reach cell straight above `bc` that a rope could anchor at — or (x, -1) when
## there's nothing to add (sealed above, out of reach, or that whole reachable stretch is already roped).
func _rope_anchor_above(bc: Vector2i) -> Vector2i:
	var best := Vector2i(bc.x, -1)
	var c: Vector2i = bc
	while sim.in_bounds(c) and not sim.is_solid(c) and sim.machine_at(c) == null and main._can_reach(c):
		best = c
		c += Vector2i(0, -1)
	if best.y >= 0 and sim.is_climbable(best):
		return Vector2i(bc.x, -1)                        # the reachable stretch is already roped
	return best


## Which way to step OFF a rope at the lip: prefer an open side cell WITH A FLOOR under it (stepping
## into the open mouth of a neighbouring shaft would just drop you back down); fall back to any open
## side. Used once the body has climbed to the target row and needs to stand on ground.
## The side of `bc` you could actually LAND on: open to move into, with solid ground directly under it.
## 0.0 when neither side offers one — which is the whole point, because "no exit here" has to be
## distinguishable from "exit right", and _exit_dir's any-open-side fallback cannot express it.
func _floored_exit(bc: Vector2i) -> float:
	for d: int in [1, -1]:
		var side := Vector2i(bc.x + d, bc.y)
		if sim.in_bounds(side) and not sim.is_solid(side) and sim.machine_at(side) == null \
				and sim.is_solid(side + Vector2i(0, 1)):
			return float(d)
	return 0.0


func _exit_dir(bc: Vector2i) -> float:
	for d: int in [1, -1]:
		var side := Vector2i(bc.x + d, bc.y)
		if sim.in_bounds(side) and not sim.is_solid(side) and sim.machine_at(side) == null \
				and sim.is_solid(side + Vector2i(0, 1)):
			return float(d)
	for d: int in [1, -1]:
		var side := Vector2i(bc.x + d, bc.y)
		if sim.in_bounds(side) and not sim.is_solid(side) and sim.machine_at(side) == null:
			return float(d)
	return 1.0


## Select the carried slot holding `item_id`. Returns whether it's now the active slot.
func select_item(item_id: StringName) -> bool:
	var slots: Array[Dictionary] = sim.inventory_slots()
	for i: int in slots.size():
		if slots[i]["item"] == item_id:
			main._inv_selected = i
			return true
	return false


## Walk within reach of a machine and deposit the selected carried item into it.
func deposit_selected(budget: int = 720) -> bool:
	if sim.machines.is_empty():
		return false
	var machine: MachineState = sim.machines[0]
	if not await approach(machine.cell, budget):
		return false
	return main.try_deposit()


## Stand under a column and wait for product to fall + auto-collect into the pack (the spit→collect loop).
func collect_below(col: int, want_item: StringName, want: int, budget: int = 600) -> bool:
	var floor_row: int = sim.surface_row(col)
	await approach(Vector2i(col, maxi(floor_row - 1, 0)), budget)
	var t: int = 0
	while int(sim.inventory.get(want_item, 0)) < want and t < budget:
		await tree.physics_frame
		t += 1
	return int(sim.inventory.get(want_item, 0)) >= want


## Craft a machine item (spends carried ingots). Returns whether the craft happened.
func craft(def: MachineDef) -> bool:
	return main.try_craft(def)


## Walk within reach of `cell` and place the selected machine there. Returns whether it got built.
func build_at(cell: Vector2i, budget: int = 720) -> bool:
	if not await approach(cell, budget):
		return false
	return main.try_build(cell)


# --- setup hatch (user-sanctioned) ----------------------------------------------------------------

## Inject resources straight into the pack to ARRANGE a situation before playing it (e.g. top up ingots
## so a craft test isn't gated on first smelting 3 ore). Setup only — the verb under test stays real.
func give(item: StringName, n: int) -> void:
	sim.inventory[item] = int(sim.inventory.get(item, 0)) + n


## The nearest solid cell of a given material to the body (e.g. find an ore vein to go dig).
func nearest_material(material: StringName) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		if sim.solid[c] != material:
			continue
		var d: float = main._cell_center(c).distance_to(player.position)
		if d < best_d:
			best_d = d
			best = c
	return best
