class_name Bazaars
extends RefCounted

## REPRESENTATION-ONLY view of the Bazaar structures the sim detects. The sim has no
## bazaar STATE — "active" is derived from the world (a valid wood frame == active, FactorySim.find_bazaars).
## This layer remembers which frames we've already seen so it can fire a one-shot, block-by-block COSMETIC
## TRANSFORMATION the instant a frame completes — plain wood visibly becoming a decorated market stall
## (awning, banners, lantern, a shopkeeper NPC walking in) — so it's obvious "a transformation happened".
## Pure draw + timers; it never writes the sim. Delete it and production numbers are identical.

const CELL: int = 32
## The block-by-block reveal: each frame cell lights up CELL_STAGGER after the previous; a cell's bright
## "pop" lasts POP. After the sweep + SETTLE the sign + NPC fade in. Tuned for an unmistakable beat.
const CELL_STAGGER: float = 0.12
const POP: float = 0.30
const SETTLE: float = 0.45

var _time: float = 0.0
var _seen: Dictionary = {}                 ## origin (Vector2i) -> activation _time (when the frame completed)


## Advance + reconcile against the sim's currently-valid frames. Returns the origins that BECAME active
## this update (so the controller can fire particles / shake — the juice that sells the transform).
func update(sim: FactorySim, dt: float) -> Array[Vector2i]:
	_time += dt
	var current: Dictionary = {}
	for o: Vector2i in sim.find_bazaars():
		current[o] = true
	var newly: Array[Vector2i] = []
	for o: Vector2i in current:
		if not _seen.has(o):
			_seen[o] = _time                # a frame just completed → start its transform animation
			newly.append(o)
	for o: Vector2i in _seen.keys():
		if not current.has(o):
			_seen.erase(o)                  # broken/rebuilt elsewhere → forget it (re-animates if rebuilt)
	return newly


## The interior-centre world position of an active bazaar (for the controller's "here" cues).
func center_of(origin: Vector2i) -> Vector2:
	return Vector2(origin.x * CELL + FactorySim.BAZAAR_W * CELL * 0.5,
			(origin.y + FactorySim.BAZAAR_H) * CELL)


func draw(canvas: CanvasItem) -> void:
	for o: Vector2i in _seen:
		_draw_bazaar(canvas, o, _time - float(_seen[o]))


# --- the structure's decorated look + its reveal -----------------------------------------------------

## Ordered frame cells (rel to origin) + role, sweeping left post → top beam → right post (a wave).
func _frame_cells() -> Array:
	return [
		{"rel": Vector2i(0, 1), "kind": "post"}, {"rel": Vector2i(0, 2), "kind": "post"},
		{"rel": Vector2i(0, 0), "kind": "beam"}, {"rel": Vector2i(1, 0), "kind": "beam"},
		{"rel": Vector2i(2, 0), "kind": "beam"}, {"rel": Vector2i(3, 0), "kind": "beam"},
		{"rel": Vector2i(3, 1), "kind": "post"}, {"rel": Vector2i(3, 2), "kind": "post"},
	]


func _draw_bazaar(canvas: CanvasItem, origin: Vector2i, age: float) -> void:
	var cells: Array = _frame_cells()
	var full: float = float(cells.size()) * CELL_STAGGER + POP
	var prog: float = clampf(age / full, 0.0, 1.0)
	var base := Vector2(origin.x * CELL, origin.y * CELL)
	# Warm hearth glow behind the stall, swelling as it forms — "this place is alive/inviting".
	var glow_c := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, FactorySim.BAZAAR_H * CELL * 0.5)
	canvas.draw_circle(glow_c, float(FactorySim.BAZAAR_W * CELL) * 0.7,
			Color(1.0, 0.82, 0.5, 0.10 * prog))

	for i: int in cells.size():
		var rt: float = age - float(i) * CELL_STAGGER
		if rt < 0.0:
			continue                                       # not revealed yet — the bare wood block shows
		var cell: Vector2i = origin + (cells[i]["rel"] as Vector2i)
		var p := Vector2(cell.x * CELL, cell.y * CELL)
		_draw_decor(canvas, p, String(cells[i]["kind"]), cell.x, cell.y == origin.y + 1)
		if rt < POP:                                       # the pop: a bright frame snapping in
			var f: float = 1.0 - rt / POP
			var grow: float = f * 6.0
			canvas.draw_rect(Rect2(p - Vector2(grow, grow), Vector2(CELL + grow * 2.0, CELL + grow * 2.0)),
					Color(1.0, 0.95, 0.72, 0.6 * f), false, 2.0 + 3.0 * f)

	if age > full:
		var a: float = clampf((age - full) / SETTLE, 0.0, 1.0)
		_draw_sign(canvas, base, a)
		_draw_keeper(canvas, base, a)


## A frame cell's market dressing: an awning segment on a beam cell, a draped banner (+ lantern on the
## upper cell) on a post. Drawn OVER the wood block the world renderer already painted.
func _draw_decor(canvas: CanvasItem, p: Vector2, kind: String, col: int, upper: bool) -> void:
	if kind == "beam":
		var cloth := Color(0.93, 0.84, 0.60) if col % 2 == 0 else Color(0.80, 0.35, 0.26)
		canvas.draw_rect(Rect2(p + Vector2(0.0, 2.0), Vector2(CELL, CELL * 0.62)), cloth)
		canvas.draw_rect(Rect2(p, Vector2(CELL, 3.0)), cloth.darkened(0.25))         # valance rail
		# Scalloped fringe hanging off the bottom of the awning.
		for s: int in 2:
			var cx: float = p.x + float(s) * CELL * 0.5 + CELL * 0.25
			var fy: float = p.y + CELL * 0.62
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(cx - CELL * 0.25, fy), Vector2(cx + CELL * 0.25, fy),
				Vector2(cx, fy + 7.0)]), cloth)
	else:
		var banner := Color(0.30, 0.62, 0.60)                                       # teal drape (palette)
		var side: float = 4.0 if col % 4 == 0 else CELL - 10.0                      # inner edge of the post
		canvas.draw_rect(Rect2(p + Vector2(side, 3.0), Vector2(6.0, CELL - 6.0)), banner)
		canvas.draw_rect(Rect2(p + Vector2(side, 3.0), Vector2(6.0, 3.0)), banner.lightened(0.2))
		if upper:                                                                   # a glowing lantern
			var l := p + Vector2(CELL * 0.5, CELL * 0.5)
			canvas.draw_circle(l, 6.0, Color(1.0, 0.78, 0.4, 0.5))
			canvas.draw_circle(l, 3.0, Color(1.0, 0.86, 0.55))


## A hanging shop sign under the awning centre.
func _draw_sign(canvas: CanvasItem, base: Vector2, a: float) -> void:
	var c := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, CELL * 0.7)
	var board := Color(0.42, 0.28, 0.16, a)
	canvas.draw_line(c + Vector2(0.0, -CELL * 0.7), c + Vector2(0.0, -2.0), Color(0.2, 0.15, 0.1, a), 1.5)
	canvas.draw_rect(Rect2(c + Vector2(-10.0, 0.0), Vector2(20.0, 11.0)), board)
	canvas.draw_rect(Rect2(c + Vector2(-10.0, 0.0), Vector2(20.0, 11.0)), Color(0.85, 0.7, 0.4, a), false, 1.0)
	canvas.draw_circle(c + Vector2(0.0, 5.5), 2.6, Color(0.95, 0.8, 0.45, a))       # a gold mark


## The shopkeeper NPC standing in the interior — a robed figure, distinct from the miner silhouette.
func _draw_keeper(canvas: CanvasItem, base: Vector2, a: float) -> void:
	var feet := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, FactorySim.BAZAAR_H * CELL - 2.0)
	var robe := Color(0.52, 0.38, 0.62, a)                                          # plum merchant robe
	var skin := Color(0.82, 0.64, 0.48, a)
	canvas.draw_colored_polygon(PackedVector2Array([                               # robe (trapezoid)
		feet + Vector2(-7.0, 0.0), feet + Vector2(7.0, 0.0),
		feet + Vector2(4.0, -16.0), feet + Vector2(-4.0, -16.0)]), robe)
	canvas.draw_circle(feet + Vector2(0.0, -20.0), 4.0, skin)                       # head
	canvas.draw_rect(Rect2(feet + Vector2(-4.5, -25.0), Vector2(9.0, 3.0)), Color(0.86, 0.52, 0.26, a))  # turban/cap
