class_name Grapple
extends RefCounted

## A piton on a winch line, the traversal verb of a game about going down: the trip back up is where a
## game like this turns into tedium. Legacy's `scenes/grapple.gd` rewritten under `Fx` (A' step 5b,
## D0359); the physics is unchanged and its prose is condensed here.
##
## A ninja rope, not Terraria's hook (which winches the body along a line and discards its velocity at
## both ends): the constraint removes only the OUTWARD component of velocity, so everything tangential is
## conserved through the arc -- release at the bottom and the speed is kept, at the top and the height is
## kept, reel in mid-arc and the arc speeds up. One position-based distance constraint, solved once per
## tick after the body's own integrate-and-collide:
##
##     d = pos - hitch;  if |d| > free:  pos = hitch + normalize(d) * free;  v -= n * max(0, v.n)
##
## Unconditionally stable, because a projection cannot add energy: under `Fx` that claim is only as good
## as the roundings, which is why `Fx.normalize` divides by a ceiling root and every scaling here truncates
## toward zero (D0358). Reeling adds energy on purpose, see `pump`. The line wraps: a polyline (the
## anchor, a pivot at every corner it has caught on, then the body) with the constraint acting from the
## last of those, so it goes around rock rather than through it; wrapping spends line, and conserved
## tangential speed over a shorter radius is a faster rotation.
##
## UNITS. `Fx` pixels against the 4 px terrain cell. The body's pixel constants ported unchanged (plan
## §3.2) and the winch is calibrated against them (the body runs at 150 px/s and strides at 232; 420 px/s
## of reel is decisively faster than the legs and still a commitment), so the grapple's speeds and range
## port as identical pixels too: legacy's 15 cells of 32 px are 480 px here, the x2 of D0325.

const CELL_FX: int = Heightfield.TERRAIN_CELL_PX * Fx.SCALE

## The probe step: one terrain cell. The flying hook, the aiming ghost and the line-catch scan all walk a
## shot in fixed steps of this size from the origin, which is what lets them agree cell for cell (legacy
## measured a ghost disagreeing with its hook three times in forty-eight when the step depended on the
## frame). A corner clip thinner than a probe can still be missed, as legacy accepted at its quarter-cell.
const PROBE: int = CELL_FX
const FLY_PER_TICK: int = (1800 * Fx.SCALE) / Body.TICK_HZ   ## 30 px a tick: a ceiling 14 legacy cells up bites in 15 ticks
const MAX_RANGE: int = 480 * Fx.SCALE                      ## px of line on the winch; beyond this the hook falls short
const REEL_PER_TICK: int = (420 * Fx.SCALE) / Body.TICK_HZ   ## 7 px a tick while up is held: the ascent verb
const PAY_PER_TICK: int = (520 * Fx.SCALE) / Body.TICK_HZ    ## paid out under down; rope falls easily
const MIN_LENGTH: int = (128 * Fx.SCALE) / 5               ## 25.6 px (legacy 0.8 cell): never winched into the anchor
const MIN_FREE: int = MIN_LENGTH / 4
## On a fresh plant the line is set to this fraction of the distance, so the hook bites and takes up a
## little slack instead of hanging loose. A CHAINED plant takes the distance as it is (see `advance`).
const SLACK_TAKEUP_NUM: int = 9
const SLACK_TAKEUP_DEN: int = 10
## The most one tick may multiply tangential speed by, either direction, as ONE ratio: 21/20 is 1.05 and
## 20/21 its reciprocal, never two literals that could drift apart. The same ratio is the body's
## `RELEASE_KICK`.
const PUMP_CLAMP_NUM: int = 21
const PUMP_CLAMP_DEN: int = 20
const MAX_PIVOTS: int = 6                                  ## a safety cap; runaway pivots would be a bug
const PIVOT_NUDGE: int = 2 * Fx.SCALE                      ## px a pivot sits off its corner, so the line does not re-catch itself
const NO_CATCH := Vector2i(-2147483648, -2147483648)       ## `_catch`'s "the run is clear"; no world point is here

enum State {
	IDLE,       ## stowed
	FLYING,     ## the hook is in the air, no constraint yet
	ANCHORED,   ## planted in rock; the line is live
}

var state: State = State.IDLE
var tip: Vector2i = Vector2i.ZERO          ## where the hook head is right now
var anchor: Vector2i = Vector2i.ZERO       ## where it bit, valid while ANCHORED
var anchor_cell: Vector2i = Vector2i.ZERO  ## the terrain cell it bit
var length: int = 0                        ## live line length
var taut: bool = false                     ## whether the constraint did work last tick (drives the render)
## Px of line taken in by the last `reel`, zero when paying out or idle. The body converts this into
## approach speed: the constraint only clamps a position, and a winch does work on what it hauls.
var hauled: int = 0
var just_planted: bool = false             ## one-shot for the impact puff; cleared by `begin_tick`
var just_cut: bool = false                 ## one-shot for the release whoosh
var pivots: Array[Vector2i] = []           ## corners the line is currently caught on, anchor-first
var _flown: int = 0                        ## px the hook has travelled this shot (a multiple of PROBE)
var _carry: int = 0                        ## sub-PROBE remainder of this tick's flight, kept for the next
var _dir: Vector2i = Vector2i(Fx.SCALE, 0)
## A new hook is in the air while the old line is still holding (see `fire`). The constraint stays live
## the whole time, so a chained shot never costs the arc already being ridden.
var _chain: bool = false


## Clear the one-shots, once per tick BEFORE the flight: a plant must survive until the observation reads it.
func begin_tick() -> void:
	just_planted = false
	just_cut = false


## Launch toward a world point. Firing while anchored CHAINS instead of cutting: the new hook flies while
## the old line holds, and the anchor swaps only when the new one bites, so nothing is released into empty
## air and the old arc's speed carries over. Deliberate release has no key: a jump cuts a taut line.
func fire(from_fx: Vector2i, toward_fx: Vector2i) -> void:
	if state == State.FLYING:
		return                       # a hook is already out; let it land or fall short first
	var d: Vector2i = Fx.normalize(toward_fx.x - from_fx.x, toward_fx.y - from_fx.y)
	_dir = d if d != Vector2i.ZERO else Vector2i(Fx.SCALE, 0)
	tip = from_fx
	_flown = 0
	_carry = 0
	if state == State.ANCHORED:
		_chain = true
	else:
		state = State.FLYING
		taut = false


func cut() -> void:
	just_cut = state == State.ANCHORED
	state = State.IDLE
	taut = false
	_chain = false
	pivots.clear()


func live() -> bool:
	return state != State.IDLE


## True while a hook is in the air, on its own or thrown from a line still being ridden.
func throwing() -> bool:
	return state == State.FLYING or _chain


## Fly the hook one tick, or retire a shot that found nothing. `from` is the body's centre this tick, so a
## shot fired while running trails from the runner. PROBE bites with the remainder carried: `trace`'s points.
func advance(grid: TileGrid, from_fx: Vector2i) -> void:
	if state != State.FLYING and not _chain:
		return
	_carry += FLY_PER_TICK
	while _carry >= PROBE:
		_carry -= PROBE
		tip = _step(tip, _dir)
		_flown += PROBE
		var cell: Vector2i = _cell_of(tip)
		if grid.is_solid(cell):
			_plant(from_fx, cell)
			return
		if _flown >= MAX_RANGE:
			# Out of line. A fresh shot falls short and stows; a chained one stops flying and leaves the
			# body on the rope it was already on, so a chained shot is always worth trying.
			if not _chain:
				state = State.IDLE
			_chain = false
			return


## Bite at the hook's actual contact point, not the cell centre (a hook planted mid-block floats in rock).
## A fresh plant takes up a little slack; a chained one must not: yanking a tenth of the radius out at the
## swap cancels part of the arc's velocity as outward motion.
func _plant(from: Vector2i, cell: Vector2i) -> void:
	anchor_cell = cell
	anchor = tip
	var dist: int = _dist(from, anchor)
	length = maxi(MIN_LENGTH, dist if _chain else (dist * SLACK_TAKEUP_NUM) / SLACK_TAKEUP_DEN)
	pivots.clear()               # a fresh bite starts a fresh line, whatever the last one caught on
	state = State.ANCHORED
	just_planted = true
	_chain = false


## Where a shot would land right now, without firing one: the aiming ghost's single source of truth, the
## same bites, predicate and range as `advance`. `tests/test_grapple.gd` holds the two in step.
func trace(grid: TileGrid, from_fx: Vector2i, toward_fx: Vector2i) -> Dictionary:
	var d: Vector2i = Fx.normalize(toward_fx.x - from_fx.x, toward_fx.y - from_fx.y)
	var dir: Vector2i = d if d != Vector2i.ZERO else Vector2i(Fx.SCALE, 0)
	var at: Vector2i = from_fx
	var flown: int = 0
	while flown < MAX_RANGE:
		at = _step(at, dir)
		flown += PROBE
		var cell: Vector2i = _cell_of(at)
		if grid.is_solid(cell):
			return {"hit": true, "at": at, "cell": cell}
	return {"hit": false, "at": at, "cell": Vector2i.ZERO}


## Shorten or pay out the line one tick. `axis` is +1 for up (reel in), -1 for down (pay out): the same
## axis that climbs a rope.
func reel(axis: int) -> void:
	hauled = 0
	if state != State.ANCHORED or axis == 0:
		return
	var before: int = length
	if axis > 0:
		length = maxi(MIN_LENGTH, length - REEL_PER_TICK)
	else:
		length = mini(MAX_RANGE, length + PAY_PER_TICK)
	hauled = before - length


## What the body pivots around: the last corner the line caught on, or the hook itself.
func hitch_fx() -> Vector2i:
	return pivots[pivots.size() - 1] if not pivots.is_empty() else anchor


func spent() -> int:
	var total: int = 0
	var at: Vector2i = anchor
	for p: Vector2i in pivots:
		total += _dist(at, p)
		at = p
	return total


## The part of the line the body is actually swinging on.
func free_length() -> int:
	return maxi(MIN_FREE, length - spent())


## Catch the line on corners and let it off them again: once per tick while ANCHORED, before the
## constraint. Unwrap first, so a line that came off a corner this tick does not re-catch on it; a pivot
## is dropped when the run from the PREVIOUS hitch to the body is clear again (wrapping is reversible).
func update_line(grid: TileGrid, pos_fx: Vector2i) -> void:
	if state != State.ANCHORED:
		return
	while not pivots.is_empty():
		var prev: Vector2i = pivots[pivots.size() - 2] if pivots.size() >= 2 else anchor
		if _blocked(grid, prev, pos_fx):
			break
		pivots.remove_at(pivots.size() - 1)
	while pivots.size() < MAX_PIVOTS:
		var corner: Vector2i = _catch(grid, hitch_fx(), pos_fx)
		if corner == NO_CATCH:
			break
		pivots.append(corner)


## Where the run from `from` to `to` first meets rock, as the corner of the blocking cell nearest the last
## clear point, or NO_CATCH if the run is clear; the same PROBE steps the hook and the ghost use. The line
## legitimately BEGINS inside rock (the hook bites at the first solid sample, a pivot is a corner), so a
## catch counts only once the run has been in open air: rock re-entered, not rock left. Legacy measured
## the alternative pinning the body to the roof it had just thrown at.
func _catch(grid: TileGrid, from: Vector2i, to: Vector2i) -> Vector2i:
	var span: int = _dist(from, to)
	if span < PROBE:
		return NO_CATCH
	var dir: Vector2i = Fx.normalize(to.x - from.x, to.y - from.y)
	var at: Vector2i = from
	var last: Vector2i = from
	var flown: int = 0
	var airborne: bool = false
	while flown < span:
		at = _step(at, dir)
		flown += PROBE
		var cell: Vector2i = _cell_of(at)
		if not grid.is_solid(cell):
			last = at
			airborne = true
			continue
		if not airborne:
			continue
		return _nearest_corner(cell, last)
	return NO_CATCH


## The corner of `cell` nearest `last`, nudged back toward it so the next step does not read the pivot
## itself as inside rock. Corners are enumerated in a fixed order and ties keep the first.
func _nearest_corner(cell: Vector2i, last: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var near: int = -1
	for cx: int in [0, 1]:
		for cy: int in [0, 1]:
			var c := Vector2i((cell.x + cx) * CELL_FX, (cell.y + cy) * CELL_FX)
			var far: int = Fx.length_sq(c.x - last.x, c.y - last.y)
			if near < 0 or far < near:
				near = far
				best = c
	var back: Vector2i = Fx.normalize(last.x - best.x, last.y - best.y)
	return best + _along(back, PIVOT_NUDGE)


func _blocked(grid: TileGrid, from: Vector2i, to: Vector2i) -> bool:
	return _catch(grid, from, to) != NO_CATCH


## The constraint. Returns the corrected position and sets `taut`; velocity is a separate call (no
## out-params). Projected through the raw delta over a CEILING-root distance, not a unit vector: a 16-bit
## unit vector's truncation times a 100 px radius fell a hundred units short of the circle (the suite
## found it); `d * free / ceil|d|` lands within a few units, still never outside (D0358's direction).
func constrain_position_fx(pos_fx: Vector2i) -> Vector2i:
	taut = false
	if state != State.ANCHORED:
		return pos_fx
	var pin: Vector2i = hitch_fx()
	var free: int = free_length()
	var d: Vector2i = pos_fx - pin
	var dist: int = Fx.isqrt_ceil(Fx.length_sq(d.x, d.y))
	if dist <= free or dist == 0:
		return pos_fx
	taut = true
	return pin + _scaled(d, free, dist)


## Cancel the outward radial component of velocity and nothing else; everything tangential survives,
## which is what makes the swing a swing. `v.d / |d|` is the radial speed (the products carry two scales,
## the distance one), safe in i64 while |d| is under the winch's range; both truncations shrink the
## removed part, so a few units of outward velocity can survive a tick, re-cancelled the next.
func resolve_velocity_fx(pos_fx: Vector2i, vx: int, vy: int) -> Vector2i:
	if not taut:
		return Vector2i(vx, vy)
	var d: Vector2i = pos_fx - hitch_fx()
	var dist: int = Fx.isqrt_ceil(Fx.length_sq(d.x, d.y))
	if dist == 0:
		return Vector2i(vx, vy)
	var radial: int = (vx * d.x + vy * d.y) / dist
	if radial <= 0:
		return Vector2i(vx, vy)
	return Vector2i(vx, vy) - _scaled(d, radial, dist)


## The pump. Angular momentum is conserved, so halving the radius doubles tangential speed; without this
## the winch is a lift and hauling at the bottom of an arc does nothing to how fast it goes. Symmetric on
## purpose: paying out scales tangential speed DOWN by the same law, so swinging wide is a brake. Driven
## off `hauled` rather than the radius, so a pivot appearing or releasing (a whole cell of free length in
## one tick) cannot be mistaken for a haul; clamped per tick because near the anchor the ratio runs away.
func pump_fx(pos_fx: Vector2i, vx: int, vy: int) -> Vector2i:
	if not taut or hauled == 0:
		return Vector2i(vx, vy)
	var d: Vector2i = pos_fx - hitch_fx()
	var r: int = Fx.isqrt_ceil(Fx.length_sq(d.x, d.y))
	var before: int = r + hauled     # hauled is negative while paying out, so this works both ways
	if r == 0 or before <= 0:
		return Vector2i(vx, vy)
	var radial: Vector2i = _scaled(d, (vx * d.x + vy * d.y) / r, r)
	var tx: int = vx - radial.x
	var ty: int = vy - radial.y
	var num: int = clampi(before, (r * PUMP_CLAMP_DEN) / PUMP_CLAMP_NUM, (r * PUMP_CLAMP_NUM) / PUMP_CLAMP_DEN)
	return Vector2i(radial.x + (tx * num) / r, radial.y + (ty * num) / r)


## The line's sag in permille: 0 bar-taut, 1000 fully slack. Pure representation, for the renderer to bow
## the rope by. Measured on the free part against the hitch: a wrapped rope is bar-taut around its corners
## by definition, and only the last segment can hang.
func slack_permille(from_fx: Vector2i) -> int:
	if state != State.ANCHORED:
		return 0
	var free: int = free_length()
	if free <= 0:
		return 0
	return clampi(1000 - (_dist(from_fx, hitch_fx()) * 1000) / free, 0, 1000)


## Every field a tick reads. The one-shots are not state: they are what the tick just did, read once.
func state_signature() -> String:
	return "%d,%s,%s,%s,%d,%s,%d,%s,%d,%d,%s,%s" % [state, tip, anchor, anchor_cell, length, taut,
		hauled, pivots, _flown, _carry, _dir, _chain]


func capture() -> Dictionary:
	var flat: Array[int] = []
	for p: Vector2i in pivots:
		flat.append(p.x)
		flat.append(p.y)
	return {"state": int(state), "tip": [tip.x, tip.y], "anchor": [anchor.x, anchor.y],
		"anchor_cell": [anchor_cell.x, anchor_cell.y], "length": length, "taut": taut, "hauled": hauled,
		"pivots": flat, "flown": _flown, "carry": _carry, "dir": [_dir.x, _dir.y], "chain": _chain}


func restore(d: Dictionary) -> void:
	state = int(d.get("state", 0)) as State
	tip = _pair(d.get("tip", [0, 0]))
	anchor = _pair(d.get("anchor", [0, 0]))
	anchor_cell = _pair(d.get("anchor_cell", [0, 0]))
	length = int(d.get("length", 0))
	taut = bool(d.get("taut", false))
	hauled = int(d.get("hauled", 0))
	pivots.clear()
	var flat: Array = d.get("pivots", [])
	for i: int in range(0, flat.size() - 1, 2):
		pivots.append(Vector2i(int(flat[i]), int(flat[i + 1])))
	_flown = int(d.get("flown", 0))
	_carry = int(d.get("carry", 0))
	_dir = _pair(d.get("dir", [Fx.SCALE, 0]))
	_chain = bool(d.get("chain", false))
	just_planted = false
	just_cut = false


static func _pair(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _cell_of(p: Vector2i) -> Vector2i:
	return Vector2i(Body._px_to_cell(p.x), Body._px_to_cell(p.y))


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return Fx.length(b.x - a.x, b.y - a.y)


## `n` (a unit vector) scaled to `len`, each component truncated toward zero: never longer than `len`.
static func _along(n: Vector2i, len: int) -> Vector2i:
	return Vector2i((n.x * len) / Fx.SCALE, (n.y * len) / Fx.SCALE)


## `d * num / den`, each component truncated toward zero: never longer than the real product.
static func _scaled(d: Vector2i, num: int, den: int) -> Vector2i:
	return Vector2i((d.x * num) / den, (d.y * num) / den)


## One probe along `dir`: PROBE is whole pixels, so this is exact.
static func _step(p: Vector2i, dir: Vector2i) -> Vector2i:
	return p + _along(dir, PROBE)
