class_name Particles
extends RefCounted

## Cosmetic particle layer (juice — audit #6). Pure representation: MainView emits bursts on world-verbs
## (dig / place / collect) and on the body's landing/footsteps; WorldRenderer draws them. Never touches
## the sim (uses randf — fine, it's cosmetic, not the deterministic tick). Capped so it can't unbound.

const MAX: int = 240

# Each particle: pos, vel, life, max_life, color, size, grav.
var _p: Array[Dictionary] = []


## Spawn `count` particles at `pos` flung within a cone/spread, each fading + falling under `grav`.
func burst(pos: Vector2, count: int, color: Color, speed: float, spread: float, size: float,
		life: float, grav: float = 220.0, up_bias: float = 0.0) -> void:
	for _i: int in count:
		if _p.size() >= MAX:
			return
		var ang: float = -PI * 0.5 - up_bias + randf_range(-spread, spread)
		var sp: float = speed * randf_range(0.5, 1.0)
		var c: Color = color.lightened(randf_range(-0.12, 0.18))
		_p.append({
			"pos": pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": life, "max_life": life, "color": c,
			"size": size * randf_range(0.7, 1.2), "grav": grav,
		})


# --- named emitters (so call sites read intent) ---

## A puff of material-coloured dust (digging, landing, footsteps) — flung low + sideways, settling.
func dust(pos: Vector2, color: Color, amount: int = 8) -> void:
	burst(pos, amount, color, 90.0, PI * 0.55, 3.0, 0.42, 260.0)


## A bright outward spark spray (placing a machine) — fast, short, little gravity.
func spark(pos: Vector2, color: Color) -> void:
	burst(pos, 12, color, 150.0, PI, 2.4, 0.30, 60.0, PI * 0.5)


## A small upward pop (collecting a pile) — rises + fades.
func pop(pos: Vector2, color: Color) -> void:
	burst(pos, 6, color, 70.0, 0.5, 2.6, 0.45, -40.0)


## A tight chip off a struck rock face (the per-blow mining tick, FABLE_50 #40): a few quick flecks
## flung along `dir_ang` (radians — usually back toward the digger). Smaller than a break.
func chip(pos: Vector2, color: Color, dir_ang: float) -> void:
	burst(pos, 3, color, 110.0, 0.7, 2.2, 0.28, 260.0, -PI * 0.5 - dir_ang)


## Break DEBRIS kicked out of a shattered block along `dir_ang` — chunkier + faster than dust, the
## "that blow landed" payoff layered over the settling dust puff.
func debris(pos: Vector2, color: Color, dir_ang: float) -> void:
	burst(pos, 7, color, 150.0, 0.5, 2.8, 0.38, 300.0, -PI * 0.5 - dir_ang)


func advance(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for q: Dictionary in _p:
		q["life"] = float(q["life"]) - delta
		if q["life"] <= 0.0:
			continue
		q["vel"] = Vector2(q["vel"]) + Vector2(0.0, float(q["grav"]) * delta)
		q["pos"] = Vector2(q["pos"]) + Vector2(q["vel"]) * delta
		kept.append(q)
	_p = kept


func size() -> int:
	return _p.size()


func draw(canvas: CanvasItem) -> void:
	for q: Dictionary in _p:
		var t: float = float(q["life"]) / float(q["max_life"])      # 1 → 0
		var col: Color = q["color"]
		col.a = clampf(t, 0.0, 1.0)
		var s: float = float(q["size"]) * (0.4 + 0.6 * t)           # shrink as it dies
		canvas.draw_rect(Rect2(Vector2(q["pos"]) - Vector2(s, s) * 0.5, Vector2(s, s)), col)
