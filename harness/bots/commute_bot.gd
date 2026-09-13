class_name CommuteBot
extends RouteBot

## The commute probe's policy (D0647): stand at the mouth of a 100 m bore, fall in, mine the face at
## its foot, climb back out the way a player does -- the grapple, one chained bite at a time -- and
## feed the surface forge. Built for `commute_200`, the fixture that asks the minute-25 question's
## commute half: what fraction of the minute is traversal, what fraction is the work at the ends.
##
## `ascend_grapple` is the one leg kind this probe owns, a four-phase hop loop read entirely off the
## observation's grapple fields (a player sees the same): aim the hook at the shaft's west wall
## ~HOP_M up, wait out the flight, hold UP to reel to `Grapple.MIN_LENGTH`, and throw again -- the
## chained fire keeps the old line until the new bite, so the body is never released into the shaft.
## Within MANTLE_ROWS of the rim the reel also holds toward-and-up so the lip mantle (D0631) tops
## out onto the ledge the hitch sits in; the spent line then goes taut as the body walks off and a
## jump cuts it -- the input the sim actually wires (body.gd's jump-on-taut), not a reach-in.
##
## THE OBSERVABLE THE LOOP READS: a chained shot never drops `grapple_anchored` -- the old line
## holds until the new one bites -- so "the shot resolved" is `grapple_throwing` going false, and
## "the shot FOUND something" is `grapple_length` jumping back out past MIN_LENGTH (a chained plant
## sets length to the new distance; a miss leaves the reeled-out line). The first version of this
## leg read `anchored` for "bite" and re-fired the hook every other tick, which the probe showed as
## the tip sawtoothing at the hand and the body hanging at the same depth forever.

const HOP_CELLS: int = 80          ## terrain cells up the wall a throw aims for (20 m of a 30 m line)
const RIM_GUARD_CELLS: int = 1     ## the last bite may not sit closer than this under the rim
const MANTLE_ROWS: int = 6         ## this near the target row, toward-and-up rides the reel
const RIM_HOLD: int = 90           ## ticks of toward-and-up the lip gets before another throw
const REEL_EPS: int = 2 * Fx.SCALE ## line past MIN_LENGTH that still reads "not yet reeled out"
const THROW_CAP: int = 16          ## throws an ascent gets before the leg fails
const WAIT_CAP: int = 240          ## ticks one shot gets to fly before the leg fails
const CUT_CAP: int = 360           ## ticks spent shaking the spent line loose before it fails


func _route(anchor: Vector2i) -> Array:
	var shaft: Vector2i = anchor + Vector2i(8, 0)      ## the mouth's west cell
	var face: Vector2i = anchor + Vector2i(10, 99)     ## the ore face in the shaft's east wall
	var forge: Vector2i = anchor + Vector2i(-3, 0)     ## the well west of spawn
	return [
		## Park on the mouth's west lip; the descent then steers itself over the edge.
		{"kind": &"walk_to", "col": anchor.x + 7, "slack": 0, "max_row": anchor.y},
		{"kind": &"descend", "col": shaft.x, "row": anchor.y + 100},
		{"kind": &"mine", "item": &"ore", "want": 4,
			"metres": [face, face + Vector2i(0, 1)]},
		{"kind": &"ascend_grapple", "col": anchor.x + 7, "row": anchor.y,
			"wall_col": (shaft.x - 1) * 4 + 3},
		{"kind": &"deliver", "item": &"ore", "at": forge},
		{"kind": &"deliver", "item": &"coal", "at": forge},
	]


func _step_custom(leg: Dictionary, out: Dictionary) -> int:
	match StringName(leg["kind"]):
		&"ascend_grapple":
			return _step_ascend_grapple(out, leg)
	return 2


## One tick of the grapple ascent: THROW aims a bite up the wall, WAIT lets the hook fly (the old
## line holds, so `anchored` never drops -- resolution is `throwing` ending, a find is `length`
## growing), REEL holds up until the line is out, and the loop repeats. Near the rim, toward-and-up
## rides the reel so the lip mantle can take the last gap; on the ledge the spent line is walked
## taut and jumped loose.
func _step_ascend_grapple(out: Dictionary, leg: Dictionary) -> int:
	var f: InputFrame = out["frame"]
	var p: Vector2i = pos()
	var row: int = int(leg["row"])
	match _phase:
		0:  ## THROW -- aim up the wall face; a chained shot keeps the line it replaces.
			var bite_row: int = maxi(p.y * 4 - HOP_CELLS, row * 4 + RIM_GUARD_CELLS)
			f.has_aim = true
			f.aim_col = int(leg["wall_col"])
			f.aim_row = bite_row
			f.grapple_pressed = true
			_phase = 1
			_waited = 0
			_stall += 1
			if _stall > THROW_CAP:
				return 2
		1:  ## WAIT for the shot to resolve -- a find grows the line back out, a miss leaves it.
			## `o` is a tick stale, so resolution counts only once the throw has actually been SEEN
			## (`_since_scoop` doubles as the flag; it is free per-leg state like `_waited`).
			_waited += 1
			if _waited > WAIT_CAP:
				return 2
			if o.grapple_throwing:
				_since_scoop = 1
			elif _since_scoop == 1:
				_since_scoop = 0
				## A find goes to the reel. So does ANY resolution near the rim: the last bite lands
				## inside a body's reach of the lip, where "line already out" reads like a miss --
				## the rim hold in REEL is what gives the mantle its window instead of a re-bite loop.
				var short: bool = o.grapple_length <= Grapple.MIN_LENGTH + REEL_EPS
				_phase = 0 if short and p.y - row > MANTLE_ROWS else 2
				_waited = 0
		2:  ## REEL -- up held until the line is out. Near the rim toward-and-up rides too, and a
			## reeled-out line holds it for RIM_HOLD before another throw: the last bite lands a
			## body's reach under the lip, so "line out" there is the mantle's window, not a miss.
			f.climb_dir = 1
			var near_rim: bool = p.y - row <= MANTLE_ROWS
			if near_rim:
				f.mantle_hold = true
				f.move_dir = signi(int(leg["col"]) - p.x)
			if body.on_floor and p.y <= row:
				_phase = 3
				_waited = 0
			elif o.grapple_length <= Grapple.MIN_LENGTH + REEL_EPS:
				_waited += 1
				if not near_rim or _waited >= RIM_HOLD:
					_phase = 0
					_waited = 0
			else:
				_waited = 0
		3:  ## CUT -- walk off the lip so the spent line goes taut, and hop: a jump cuts a taut line.
			_waited += 1
			f.move_dir = signi(int(leg["col"]) - 4 - p.x)
			var hop: bool = body.on_floor and _waited % 12 == 0
			f.jump_pressed = hop
			f.jump_held = hop
			if not o.grapple_anchored:
				if p.y <= row and body.on_floor:
					return 1
			elif _waited > CUT_CAP:
				return 2
	return 0
