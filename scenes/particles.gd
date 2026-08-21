class_name Particles
extends RefCounted

## Cosmetic particle layer. MainView emits bursts on world verbs and on the body's landing and
## footsteps; WorldRenderer draws them. It never touches the sim, so randf() is safe here: these are
## outside the deterministic tick. Capped so it cannot grow without bound.

const MAX: int = 240

# Each particle carries pos/vel/life/max_life/color/size/grav.
var _p: Array[Dictionary] = []


## Spawn `count` particles at `pos` (world px) flung within a cone of half-width `spread` radians,
## each fading and falling under `grav`.
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


# --- named emitters, so call sites read as intent ---

## A puff of material-coloured dust for digging, landing and footsteps. Flung low and sideways.
func dust(pos: Vector2, color: Color, amount: int = 8) -> void:
	burst(pos, amount, color, 90.0, PI * 0.55, 3.0, 0.42, 260.0)


## The draught: a thin slow drift of dust along `dir`, marking a face with a void behind it. Nearly
## weightless and long-lived, so it hangs in the lamp pool as moving air. The silent half of the cue.
func draught(pos: Vector2, color: Color, dir: Vector2, amount: int = 2) -> void:
	for _i: int in amount:
		if _p.size() >= MAX:
			return
		var v: Vector2 = dir.normalized().rotated(randf_range(-0.4, 0.4)) * randf_range(14.0, 34.0)
		_p.append({
			"pos": pos + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)),
			"vel": v, "life": 1.5, "max_life": 1.5, "color": color.lightened(randf_range(-0.1, 0.2)),
			"size": randf_range(1.2, 2.2), "grav": 6.0,
		})


## A bright outward spark spray for placing a machine: fast and short, with little gravity.
func spark(pos: Vector2, color: Color) -> void:
	burst(pos, 12, color, 150.0, PI, 2.4, 0.30, 60.0, PI * 0.5)


## A small upward pop for collecting a pile.
func pop(pos: Vector2, color: Color) -> void:
	burst(pos, 6, color, 70.0, 0.5, 2.6, 0.45, -40.0)


## A tight chip off a struck rock face, once per blow: a few quick flecks flung along `dir_ang` in
## radians, usually back toward the digger. Smaller than a break.
func chip(pos: Vector2, color: Color, dir_ang: float) -> void:
	burst(pos, 3, color, 110.0, 0.7, 2.2, 0.28, 260.0, -PI * 0.5 - dir_ang)


## Debris kicked out of a shattered block along `dir_ang`. Chunkier and faster than dust, and layered
## over the settling dust puff rather than replacing it.
func debris(pos: Vector2, color: Color, dir_ang: float) -> void:
	burst(pos, 7, color, 150.0, 0.5, 2.8, 0.38, 300.0, -PI * 0.5 - dir_ang)


## A single droplet shed off pouring water: mostly down with a hair of sideways drift, short-lived
## under strong gravity. The renderer rate-limits and view-culls the calls, so a waterfall shimmers.
func water_drip(pos: Vector2) -> void:
	if _p.size() >= MAX:
		return
	var col := Color(0.55, 0.78, 0.98).lightened(randf_range(-0.08, 0.12))
	_p.append({
		"pos": pos + Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)),
		"vel": Vector2(randf_range(-14.0, 14.0), randf_range(30.0, 70.0)),
		"life": 0.42, "max_life": 0.42, "color": col,
		"size": randf_range(1.4, 2.2), "grav": 420.0,
	})


## A splash where falling water lands: a few flecks kicked up and outward, so a pour reads as hitting
## the surface below rather than vanishing into it.
func water_splash(pos: Vector2) -> void:
	burst(pos, 4, Color(0.62, 0.82, 0.98), 60.0, PI * 0.6, 1.8, 0.26, 340.0, PI * 0.5)


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
