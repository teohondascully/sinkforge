class_name ShaftMouth
extends RefCounted

## THE SHAFT'S MOUTH, the BUILD rung's target once the drill is in hand (D0459), out of `TargetGuide` for the
## size gate (D0492). Pure over the observation; ranked by the guide's own band rule.

const SHAFT_ABOVE_M: int = 4              ## how far above a forge the shaft's vein and mouth are looked for


## THE SHAFT'S MOUTH (D0459): "the line" is a drill over a vein over a forge in one column, and the seeded
## shaft is the one place with a forge under ore under open air. The mouth is the open metre right above
## the topmost ore-like metre that stands over a processor within SHAFT_ABOVE_M; the nearest such mouth to
## the body by the ring's own ranking. NONE when the window holds no forge with ore over it.
static func find(o: Interface.Observation, body: Vector2) -> Vector2:
	var best: Vector2 = TargetGuide.NONE
	var best_d: float = 1.0e18
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") != &"processor":
			continue
		var col: int = (rec["cell"] as Vector2i).x
		var row: int = (rec["cell"] as Vector2i).y - 1
		var vein_row: int = -1
		for _step: int in SHAFT_ABOVE_M:
			var c := Vector2i(col * 4 + 2, row * 4 + 2)
			if not o.in_window(c):
				break
			if o.is_ore_like_at(c):
				vein_row = row
			elif vein_row >= 0 and not o.solid_at(c):
				break
			row -= 1
		if vein_row < 0:
			continue
		var mouth := Vector2i(col * 4 + 2, (vein_row - 1) * 4 + 2)
		if not o.in_window(mouth) or o.solid_at(mouth):
			continue
		var at: Vector2 = (Vector2(col, vein_row - 1) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		var d: float = TargetGuide.ranked(at, body)
		if d < best_d:
			best_d = d
			best = at
	return best
