class_name Mining
extends RefCounted

## Cursor-aim hold-to-charge mining. Slice 1, `docs/DECISIONS_LEDGER.md` D0195. Re-derived from
## `legacy/scenes/main.gd::_update_mining` (lines 1522-1624) rather than lifted: that loop is float,
## `delta`-driven and frame-rate dependent, and this layer is a fixed 60Hz integer tick with no clock
## (`CONTEXT.md`, "Determinism"). Every accumulator here is an integer.
##
## THE SEAM. `mine()` below is `Command.Mine(target_cell)` in everything but its type. `interface/` does
## not exist until Slice 2, so the reveal scene calls this directly; at Slice 2 the call becomes an
## `apply(Command.Mine(cell))` and this signature is what that command's payload has to carry. It is
## deliberately dependency-light -- a `TileGrid`, the body's centre as two `Fx` scalars, and a target cell
## -- so that formalising it later is a wrapper, not a refactor. It takes no `Body`: the two constants it
## reads from `sim/body` are the published cell and tile sizes, referenced rather than re-typed here
## because a second literal 4 or 16 is exactly the duplicated-constant trap this ledger already records.
##
## WHAT SUPERSEDES WHAT. `docs/DECISIONS_LEDGER.md` D0110 deferred the aim-direction question ("which key
## means down, does it compete with mantle_hold's up-key") and scoped digging to horizontal-only as a
## result. Cursor-aim answers it: aim is a point against a radius, so "down" is just a cell below the body
## and no key has to mean it. `sim/body/body_dig.gd`'s horizontal column dig still exists alongside this
## through Slice 1 -- the reveal metric and every committed recording run on it -- and is not removed here.

const CELL_PX: int = Heightfield.TERRAIN_CELL_PX  ## 4
const LOGIC_TILE_PX: int = Body.LOGIC_TILE_PX     ## 16 -- one metre, on both sides of the migration

## REACH. Legacy `REACH_CELLS = 3.2` at its own 32px cell is 102.4px -- but legacy's 32px cell and this
## world's 16px logic tile are both ONE METRE, so the portable quantity is 3.2 METRES, not 102.4 pixels.
## That is 51.2px here, or 12.8 terrain cells. Held as a rational so the squared comparison below stays in
## exact integers: 3.2 == 16/5.
const REACH_NUM: int = 16
const REACH_DEN: int = 5

## CHARGE. Legacy accumulates `delta * speed * (1 + rhythm * RHYTHM_SPEED)` seconds and breaks at the
## material's hardness, also in seconds. `speed` is always exactly 1.0 there -- legacy's own
## `mining_rules.gd` header states the speed axis is deleted and every pick cuts at 1.0, tier being a gate
## rather than a rate -- so one held tick is one tick of charge, and the unit below is a tick scaled up to
## leave room for the rhythm multiplier without integer division losing it.
const CHARGE_UNIT: int = 1024  ## charge added per held tick at zero rhythm

## HARDNESS -> TICKS. The two codebases do not share a hardness scale: legacy's numbers ARE seconds
## (earth 0.28, stone 0.85, deepslate 2.80) and this project's are unitless (clay 1.0, hardrock 3.0,
## deepstone 5.0), and no single factor maps one onto the other -- their shapes genuinely differ at the
## deep end. This constant is the one dial that relates them, and it is DERIVED from the shallow end,
## where a player actually starts: at 17 ticks per hardness point, clay (1.0) breaks in 17 ticks =
## 0.283s against legacy earth's 0.28s, and hardrock (3.0) in 51 ticks = 0.850s against legacy stone's
## 0.850s -- the second one exact, and neither fitted to. The deep end comes out faster than legacy
## (deepstone 1.42s against deepslate's 2.80s) purely because this project's hardness scale compresses
## there; that is a tuning question for the director, not a porting error. `tests/test_mining.gd` prints
## the whole table in seconds so the trade is visible rather than buried in a constant.
const TICKS_PER_HARDNESS: int = 17

## THE CRACK BANK. Legacy banks partial progress per cell so a mis-aim costs travel time, never progress,
## and lets it bleed away only after a grace window. `CRACK_HOLD` 2.5s and `CRACK_HEAL` 0.5 charge-seconds
## per second, converted: one charge-second is 60 ticks x CHARGE_UNIT, so 0.5/s is 512 units per tick.
const CRACK_HOLD_TICKS: int = 150
const CRACK_HEAL_PER_TICK: int = 512

## RHYTHM. Legacy's `_rhythm` runs 0..1, gains 0.34 per block broken, and after a 1.1s grace bleeds at
## 0.55/s; it multiplies the charge rate by up to 1.60. Scaled to 1200 rather than 1024 for one reason:
## 1200 is the smallest scale on which the 0.55/s decay is an EXACT integer per tick (11), so the mechanic
## needs no rounding and no accumulated drift. Gain lands exact too (0.34 * 1200 == 408).
const RHYTHM_FULL: int = 1200
const RHYTHM_GAIN: int = 408
const RHYTHM_GRACE_TICKS: int = 66  ## 1.1s
const RHYTHM_DECAY_PER_TICK: int = 11  ## 0.55/s, exactly
## `1 + rhythm * 0.60 / RHYTHM_FULL`, rearranged so the whole multiplier is one integer division:
## `CHARGE_UNIT + (CHARGE_UNIT * rhythm) / RHYTHM_SPEED_DEN`, with RHYTHM_SPEED_DEN = RHYTHM_FULL / 0.60.
const RHYTHM_SPEED_DEN: int = 2000

## Legacy's swing cadence, converted rather than re-picked. `SWING_PERIOD` is 0.28 s and the sim runs at
## a fixed 60 Hz, so the base period is 16.8 ticks -- carried x100 so the division below stays integer
## and the same on every machine. `RHYTHM_SWING = 0.55` is the rational 11/20.
##
## `period = BASE / (1 + rhythm_fraction * 11/20)`, and `rhythm_fraction` is `_rhythm / RHYTHM_FULL`.
## Multiplied out to keep it in integers, that is the expression in `swing_period_ticks()`. Measured at
## the two ends: **16 ticks at rest, 10 ticks at full rhythm** -- a blow every 0.27 s becomes one every
## 0.17 s, which is the speed-up legacy wanted to be "visible and audible".
const SWING_TICKS_X100: int = 1680
const SWING_RHYTHM_NUM: int = 11
const SWING_RHYTHM_DEN: int = 20

## THE BITE (Slice 1.5, D0200). How far the breaking blow reaches around the cell that was charged,
## in TERRAIN CELLS, as a Euclidean disc: `dx*dx + dy*dy <= r*r`. 0 clears exactly the target and is
## bit-for-bit the Slice 1 behaviour, which is what makes it the probe's own control.
##
## DERIVED from legacy's volumetric rate, not picked. Legacy's `CELL` is 32px and `sim.mine(cell)` removes
## ONE of them per charge -- one square METRE, at `hardness` seconds. This world's metre is the 16px logic
## tile, which is 16 terrain cells, and Slice 1 charged a full metre's worth of hardness-seconds to remove
## ONE of those 16. That is the porting error D0195 did not catch: it checked seconds-per-CELL against
## legacy and got 0.283s vs 0.28s, but the two codebases' cells are different sizes, so the portable
## quantity was never seconds-per-cell -- it was seconds-per-METRE, and on that axis Slice 1 mines
## **16x slower than legacy**. The disc radii are 1, 5, 13, 29 cells for r = 0, 1, 2, 3; r = 2's 13 cells
## is 81% of a metre and the closest disc to legacy's rate without exceeding it.
const DEFAULT_BITE_RADIUS: int = 2
const CONTROL_BITE_RADIUS: int = 0  ## named rather than a bare 0 at the call sites that mean "as Slice 1"

const NO_CELL: Vector2i = Vector2i(-2147483648, -2147483648)  ## `mine()`'s "nothing broke" return

## cell -> Vector2i(banked charge units, ticks since last worked). Legacy's `_cracks`, one grid finer.
var _cracks: Dictionary = {}
var _rhythm: int = 0
var _rhythm_idle: int = 0

## The bite radius this instance mines at. Sim state in the sense that matters for replay: two runs of the
## same inputs at different radii diverge on the first break, so a recording that cannot restate it cannot
## be replayed (`tests/body/reveal_replay_driver.gd` reads it back out of the log header).
var bite_radius: int = DEFAULT_BITE_RADIUS

## Per-tick telemetry, read by the caller, not auto-cleared -- same contract `body.gd`'s own flags have.
var charging_cell: Vector2i = NO_CELL  ## the cell this tick's hold advanced, if any
var broke_this_tick: bool = false
var broke_material: StringName = &""
var breach_this_tick: bool = false  ## the break opened into a void -- `HollowTell.BREACH` or above

## THE HOLLOW READING AS A MAGNITUDE, not a flag. Per mille: 0 is solid to the horizon, 1000 is a void
## right behind the face. `docs/LEGACY_GAP.md` PRE-3 asked for exactly this, and the reason is in legacy's
## own comment at `main.gd:1600-1609`: **"volume rides the reading, so closing on a cavity is a crescendo
## you can act on rather than a flag that flips."** Both audio laws and the draught's particle count are
## functions of the magnitude; `breach_this_tick` is one threshold sampled from it and cannot reconstruct
## it.
##
## Set on EVERY charging tick, not only on a break. Legacy rings per swing while you work the face, which
## is what makes the tell RISE as you approach; computing it only at the moment rock gives way would
## deliver the whole crescendo as a single note at the end. 0 whenever nothing is being worked.
var hollow_this_tick: int = 0

## THE SWING EDGE: true on the tick the pick actually LANDS, false on the 9-to-15 ticks between blows.
##
## Ported from `legacy/scenes/main.gd:216`, `234` and `1587`, which is the point — `docs/LEGACY_GAP.md`
## PRE-3 asked for "a swing edge" and I nearly invented a cadence for it. Legacy already had one:
## `SWING_PERIOD 0.28s`, shortened by `1 / (1 + rhythm * RHYTHM_SWING)` with `RHYTHM_SWING = 0.55`, and
## the clock primed on release so the first blow of a fresh charge lands instantly.
##
## WHY IT MATTERS THAT THIS IS AN EDGE AND NOT `charging_cell != NO_CELL`. Legacy's hollow ring, its
## draught and its pick animation all fire per BLOW. Firing them per charging tick would be sixty rings a
## second; firing them only on the break gives one note where legacy gives a crescendo. The repetition IS
## the tell — it is what makes closing on a cavity read as "a crescendo you can act on rather than a flag
## that flips" (legacy's own words at `main.gd:1600-1609`).
##
## The director ruled the rhythm-driven option specifically, over a fixed period and over charge-fraction
## edges, because `_rhythm` is already ported and tested and until now had **no outward sign at all**.
## This is its first: the pick visibly speeds up as you find a groove.
var swing_this_tick: bool = false

## Ticks since the last blow landed. NOT in `state_signature()`, deliberately, and this is a judgment
## call rather than an oversight: it is a pure function of `_rhythm` and of whether a cell was workable,
## both of which the signature already covers, and it can change nothing about which cell breaks when.
## Including it would re-pin `GOLDEN_HASHES` for a counter that cannot cause a divergence it would be the
## only witness to.
##
## STARTS PRIMED, not at zero. Legacy sets `_swing_clock = SWING_PERIOD` on release so the first blow of
## a fresh charge lands instantly, and a freshly-constructed `Mining` is in exactly that state -- nothing
## has been released yet, but nothing is mid-swing either. Initialised at zero, the very first tap of the
## mine button swung at nothing for a quarter second, which a test caught before this shipped.
## `SWING_TICKS_X100 / 100` is the at-rest period, the longest one, so it primes at any rhythm.
var _swing_ticks: int = SWING_TICKS_X100 / 100

## Every cell this tick's blow actually cleared, target first, in the deterministic scan order `_clear_bite`
## walks. A view wanting to spray debris per cleared cell reads this rather than re-deriving the disc, which
## would be a second copy of the shape free to drift from the one that ran.
var broke_cells: Array[Vector2i] = []
var broke_materials: Array[StringName] = []   # parallel to `broke_cells`: what each cell WAS (D0354)


## Canonical state signature, for the replay-determinism check. The crack bank is real sim state: two runs
## that banked different partial charges will break different cells on different ticks later. Sorted by
## cell rather than emitted in Dictionary order, because `CONTEXT.md` forbids iterating a hash map in
## state-affecting code and a signature that varied with insertion order would report a false divergence.
func state_signature() -> String:
	var keys: Array = _cracks.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	var parts: PackedStringArray = []
	for k: Vector2i in keys:
		var v: Vector2i = _cracks[k]
		parts.append("%d:%d=%d,%d" % [k.x, k.y, v.x, v.y])
	# `bite_radius` is configuration rather than evolving state, but it belongs here: a replay run at the
	# wrong radius diverges on its first break, and without it in the signature the divergence would surface
	# only as a mismatched GRID, several hundred cells later, attributed to whatever ran in between.
	return "b%d,r%d,i%d|%s" % [bite_radius, _rhythm, _rhythm_idle, ";".join(parts)]


## Ticks between pick-blows at the current rhythm. Integer throughout: a float period would put the
## swing cadence on the wrong side of the determinism line for the sake of a fraction of a tick.
##
## Public because it is the number a test has to compare against -- asserting "a blow every 16 ticks"
## with 16 written in the test would assert the test's own constant, not this conversion.
func swing_period_ticks() -> int:
	var scaled_rhythm: int = (_rhythm * SWING_RHYTHM_NUM) / SWING_RHYTHM_DEN
	return (SWING_TICKS_X100 * RHYTHM_FULL) / (100 * (RHYTHM_FULL + scaled_rhythm))


## HOW FAR THROUGH THE CURRENT SWING THE PICK IS, in per mille. 0 on the tick a blow lands and climbing
## back to 1000 as the next one winds up, so a two-frame pick animation driven from this has its STRUCK
## frame on the exact tick the rock takes damage (D0287).
##
## Per mille and integer for the reason every other number crossing L2 is: a float in an observation is a
## float in a replay. Between blows -- and while the pick is held against nothing workable -- `mine()`
## primes the counter to a full period, so this reads 1000, which is "raised", which is right.
func swing_phase_per_mille() -> int:
	var period: int = swing_period_ticks()
	if period <= 0:
		return 0   ## unreachable at any rhythm the constants allow, but a division that cannot be zero
	return clampi((_swing_ticks * 1000) / period, 0, 1000)


## How much charge a cell has banked, 0 if none. The renderer's crack overlay reads this.
func banked(cell: Vector2i) -> int:
	return (_cracks[cell] as Vector2i).x if _cracks.has(cell) else 0


## Every cell currently holding banked charge. For a renderer, which otherwise has no way to know which
## cells to draw cracks on without probing the whole visible grid every frame. Returns a fresh Array, so a
## caller cannot mutate the bank through it, and nothing in `sim/` iterates it -- a view drawing in
## Dictionary order affects no state.
func cracked_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in _cracks:
		out.append(cell)
	return out


## Charge needed to break this material, in units. Public so a view can draw a real progress fraction
## rather than guessing a denominator.
static func break_cost(material: StringName) -> int:
	return ticks_to_break(material) * CHARGE_UNIT


## Ticks of unbroken holding needed to break this material at zero rhythm.
##
## `hardness_halves` rather than the float directly: every authored hardness is a multiple of 0.5, so
## doubling is exact in binary and the integer conversion cannot silently truncate. If a future record
## authors 1.33, this rounds it and `tests/test_mining.gd` fails on the exactness check rather than the
## world quietly mining at a slightly wrong rate.
static func ticks_to_break(material: StringName) -> int:
	return maxi(1, (hardness_halves(material) * TICKS_PER_HARDNESS) / 2)


static func hardness_halves(material: StringName) -> int:
	return int(round(WorldMaterials.hardness(material) * 2.0))


## Is `cell`'s centre within reach of a body centred at (`body_x`, `body_y`)? Euclidean and inclusive,
## exactly as legacy (`_can_reach`: `position.distance_to(_cell_center(cell)) <= REACH_CELLS * CELL`).
##
## Squared, never `sqrt`: a square root would be the one float on this path, and the comparison is exact
## without it. The axis reject first is not an optimisation -- it BOUNDS the operands. Without it a body at
## the bottom of a 4096px world squaring a full-height delta in Fx runs to ~1.8e18, inside int64 but with
## less headroom than this is worth; after it, both terms are bounded by the reach itself.
static func in_reach(body_x: int, body_y: int, cell: Vector2i) -> bool:
	return Aim.in_reach_point(body_x, body_y, _cell_center_fx(cell.x), _cell_center_fx(cell.y))


static func _cell_center_fx(cell_axis: int) -> int:
	return cell_axis * CELL_PX * Fx.SCALE + (CELL_PX * Fx.SCALE) / 2


## The hollow reading behind `cell`, per mille. Delegates to `sim/mining/hollow_tell.gd`.
static func hollow_at(grid: TileGrid, cell: Vector2i, dir: Vector2i) -> int:
	return HollowTell.read(grid, cell, dir)


## ONE TICK OF THE MINING VERB -- the seam described at the top of this file.
##
## `target` is the cell the player is aiming at, already resolved from a pointer by `view/controls.gd`;
## this layer has no cursor and no viewport. `held` is the MINE button's raw held state, NOT an edge:
## hold-to-charge is the whole mechanic.
##
## Returns the cell broken this tick, or `NO_CELL`. Order follows legacy exactly, because the order is
## load-bearing: rhythm decays BEFORE it is read (so this tick charges at the already-decayed rate), and
## cracks heal BEFORE the bank is advanced (so the cell being worked is excluded from ageing in the same
## tick it is charged).
func mine(grid: TileGrid, body_x: int, body_y: int, target: Vector2i, held: bool) -> Vector2i:
	charging_cell = NO_CELL
	broke_this_tick = false
	broke_material = &""
	breach_this_tick = false
	hollow_this_tick = 0
	swing_this_tick = false
	broke_cells.clear()
	broke_materials.clear()

	_rhythm_idle += 1
	if _rhythm_idle > RHYTHM_GRACE_TICKS:
		_rhythm = maxi(0, _rhythm - RHYTHM_DECAY_PER_TICK)

	var working: bool = held and _workable(grid, body_x, body_y, target)
	_heal_cracks(grid, target if working else NO_CELL)
	if not working:
		# PRIMED, not zeroed -- legacy's `_swing_clock = SWING_PERIOD` on release, so the first blow of the
		# next charge lands instantly instead of the player waiting a quarter second for the pick to start.
		_swing_ticks = swing_period_ticks()
		return NO_CELL

	charging_cell = target
	hollow_this_tick = hollow_at(grid, target, swing_dir(body_x, body_y, target))
	_swing_ticks += 1
	if _swing_ticks >= swing_period_ticks():
		_swing_ticks = 0
		swing_this_tick = true
	var material: StringName = grid.get_material(target)
	var charge: int = banked(target) + CHARGE_UNIT + (CHARGE_UNIT * _rhythm) / RHYTHM_SPEED_DEN
	if charge < break_cost(material):
		_cracks[target] = Vector2i(charge, 0)
		return NO_CELL
	return _break(grid, target, material)


## Workable: a real solid cell inside the world, within reach. LINE OF SIGHT IS THE VERB'S GATE, not the
## primitive's, as legacy's was (`main.gd` `_mineable`, never `FactorySim.mine`): `Interface`, `Aim`,
## `DigPlan` and `LodeWork` all refuse through rock via `LineOfSight` (D0354), and fixtures may pose a
## body in rock. Legacy's tool-tier gate is the terminal economy, dead by the director's ruling.
func _workable(grid: TileGrid, body_x: int, body_y: int, cell: Vector2i) -> bool:
	return grid.in_bounds(cell) and grid.is_solid(cell) and in_reach(body_x, body_y, cell)


func rhythm() -> int:
	return _rhythm


## Age every banked crack except the one being worked; past the grace window they bleed off and evict.
## `keys()` returns a fresh Array in GDScript, so erasing inside the loop is safe; a port using a live
## iterator would need a snapshot.
func _heal_cracks(grid: TileGrid, working: Vector2i) -> void:
	for cell: Vector2i in _cracks.keys():
		if cell == working:
			continue
		var c: Vector2i = _cracks[cell]
		c.y += 1
		if c.y > CRACK_HOLD_TICKS:
			c.x -= CRACK_HEAL_PER_TICK
		if c.x <= 0 or not grid.is_solid(cell):
			_cracks.erase(cell)
		else:
			_cracks[cell] = c


## The breaking blow. The hollow reading is sampled BEFORE the cell is excavated, deliberately: afterwards
## the probe box would be reading a world that already includes the hole it is meant to be predicting.
##
## Overshoot is discarded rather than carried into the next cell, as in legacy -- with a fixed tick that
## quantises break time upward by at most one tick, which is the honest cost of not carrying a remainder
## that would make two identical holds break at different times depending on where the previous one ended.
func _break(grid: TileGrid, cell: Vector2i, material: StringName) -> Vector2i:
	# `hollow_this_tick` was already set by `mine()` for this same cell and direction, so this reads it
	# rather than calling `hollow_at` a second time -- two calls would be two chances for the break's
	# threshold and the renderer's crescendo to disagree about the same blow.
	_clear_bite(grid, cell)
	_rhythm = mini(RHYTHM_FULL, _rhythm + RHYTHM_GAIN)
	_rhythm_idle = 0
	broke_this_tick = true
	broke_material = material
	breach_this_tick = hollow_this_tick >= HollowTell.BREACH
	return cell


## Clears the blow's whole disc, target first, then the rest in a fixed row-major scan -- a nested integer
## `range`, never a `Dictionary` iteration, so the order is the same on every machine and `broke_cells` is
## replay-stable (`CONTEXT.md`, "Determinism").
##
## Only SOLID, in-bounds cells are cleared and recorded, so `broke_cells.size()` is what the blow actually
## removed rather than the disc's nominal area -- a bite at a wall's edge honestly reports the smaller
## number. The disc is deliberately NOT reach-tested per cell: the charge was earned on the target, and at
## r = 2 the rim reaches 8px past it against a 51.2px reach, which is the blow's own radius rather than a
## way to mine further than the arm goes.
func _clear_bite(grid: TileGrid, target: Vector2i) -> void:
	_cracks.erase(target)
	broke_materials.append(grid.get_material(target))
	grid.excavate(target)
	broke_cells.append(target)
	for dy: int in range(-bite_radius, bite_radius + 1):
		for dx: int in range(-bite_radius, bite_radius + 1):
			if dx * dx + dy * dy > bite_radius * bite_radius:
				continue
			var cell: Vector2i = target + Vector2i(dx, dy)
			if cell == target or not grid.in_bounds(cell) or not grid.is_solid(cell):
				continue
			_cracks.erase(cell)  ## a cell that no longer exists may not keep banked charge
			broke_materials.append(grid.get_material(cell))
			grid.excavate(cell)
			broke_cells.append(cell)


## Which way the blow faces -- the axis the tell's probe box looks along. Axis-dominant from the body
## centre toward the cell centre, falling back to straight down when the two coincide, exactly as legacy
## (`main.gd::_swing_dir`). Ties go to the vertical, which is the axis this game is about. Public because
## the view places a draught puff on the near face and a second copy of this rule would be free to drift.
static func swing_dir(body_x: int, body_y: int, cell: Vector2i) -> Vector2i:
	var dx: int = _cell_center_fx(cell.x) - body_x
	var dy: int = _cell_center_fx(cell.y) - body_y
	if absi(dx) > absi(dy):
		return Vector2i(signi(dx), 0)
	return Vector2i(0, signi(dy)) if dy != 0 else Vector2i(0, 1)
