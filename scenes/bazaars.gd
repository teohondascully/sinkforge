class_name Bazaars
extends RefCounted

## REPRESENTATION-ONLY view of the Bazaar structures the sim detects. The sim has no
## bazaar STATE. "active" is derived from the world (a valid wood frame == active, FactorySim.find_bazaars).
## This layer remembers which frames we've already seen so it can fire a one-shot, block-by-block COSMETIC
## TRANSFORMATION the instant a frame completes: plain wood visibly becoming a decorated market stall
## (awning, banners, lantern, a shopkeeper NPC walking in), so it's obvious "a transformation happened".
## Pure draw + timers; it never writes the sim. Delete it and production numbers are identical.

const CELL: int = 32
## The block-by-block reveal: each frame cell lights up CELL_STAGGER after the previous; a cell's bright
## "pop" lasts POP. After the sweep + SETTLE the sign + NPC fade in. Tuned for an unmistakable beat.
const CELL_STAGGER: float = 0.12
const POP: float = 0.30
const SETTLE: float = 0.45

## How thoroughly a derelict frame has lost its dressing. One knob so the ruin and the live stall are drawn
## by the SAME code: the transformation the player sets off is then literally this value going to zero.
const RUIN_WEAR: float = 1.0

var _time: float = 0.0
var _seen: Dictionary = {}                 ## origin (Vector2i) -> activation _time (when the frame completed)
var _ruins: Array[Dictionary] = []         ## {origin, gap} for frames one block short (FactorySim.find_bazaar_ruins)


## Advance + reconcile against the sim's currently-valid frames. Returns the origins that BECAME active
## this update (so the controller can fire particles / shake: the juice that sells the transform).
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
	_ruins = sim.find_bazaar_ruins()        # ...and the not-yet-bazaars, which are the ones worth pointing at
	return newly


## The interior-centre world position of an active bazaar (for the controller's "here" cues).
func center_of(origin: Vector2i) -> Vector2:
	return Vector2(origin.x * CELL + FactorySim.BAZAAR_W * CELL * 0.5,
			(origin.y + FactorySim.BAZAAR_H) * CELL)


func draw(canvas: CanvasItem) -> void:
	for r: Dictionary in _ruins:            # the unfinished ones first, because a live stall may sit on top of one
		_draw_ruin(canvas, r["origin"], r["gap"])
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
	# Warm hearth glow behind the stall, swelling as it forms. "This place is alive/inviting".
	var glow_c := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, FactorySim.BAZAAR_H * CELL * 0.5)
	canvas.draw_circle(glow_c, float(FactorySim.BAZAAR_W * CELL) * 0.7,
			Color(1.0, 0.82, 0.5, 0.10 * prog))

	for i: int in cells.size():
		var rt: float = age - float(i) * CELL_STAGGER
		if rt < 0.0:
			continue                                       # not revealed yet; the bare wood block shows
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
##
## `wear` (0 = a working stall, 1 = the derelict) fades the cloth toward dust, rots the fringe off and puts
## the lantern out. The ruin and the finished bazaar go through THIS function rather than each having their
## own look, which is the whole point: the player sees one object in two states, so finishing it reads as
## the stall coming back rather than a different prop being swapped in.
func _draw_decor(canvas: CanvasItem, p: Vector2, kind: String, col: int, upper: bool,
		wear: float = 0.0) -> void:
	var dust := Color(0.34, 0.31, 0.28)                                             # what everything fades to
	var left: float = 1.0 - wear * 0.4                                              # ...and how much is still there
	if kind == "beam":
		var cloth := Color(0.93, 0.84, 0.60) if col % 2 == 0 else Color(0.80, 0.35, 0.26)
		cloth = cloth.lerp(dust, wear * 0.7)
		cloth.a = left
		canvas.draw_rect(Rect2(p + Vector2(0.0, 2.0), Vector2(CELL, CELL * 0.62)), cloth)
		canvas.draw_rect(Rect2(p, Vector2(CELL, 3.0)), cloth.darkened(0.25))         # valance rail
		# Scalloped fringe hanging off the bottom of the awning, the first thing to rot off a dead canopy,
		# so its ABSENCE is most of what makes the ruin read as abandoned rather than merely dim.
		if wear < 0.5:
			for s: int in 2:
				var cx: float = p.x + float(s) * CELL * 0.5 + CELL * 0.25
				var fy: float = p.y + CELL * 0.62
				canvas.draw_colored_polygon(PackedVector2Array([
					Vector2(cx - CELL * 0.25, fy), Vector2(cx + CELL * 0.25, fy),
					Vector2(cx, fy + 7.0)]), cloth)
	else:
		var banner := Color(0.30, 0.62, 0.60).lerp(dust, wear * 0.7)                # teal drape (palette)
		banner.a = left
		var side: float = 4.0 if col % 4 == 0 else CELL - 10.0                      # inner edge of the post
		var drop: float = CELL - 6.0 - wear * CELL * 0.45                           # a torn drape hangs short
		canvas.draw_rect(Rect2(p + Vector2(side, 3.0), Vector2(6.0, drop)), banner)
		canvas.draw_rect(Rect2(p + Vector2(side, 3.0), Vector2(6.0, 3.0)), banner.lightened(0.2))
		if upper:
			var l := p + Vector2(CELL * 0.5, CELL * 0.5)
			if wear >= 0.5:                                                         # the lantern is still hung
				canvas.draw_circle(l, 3.4, Color(0.17, 0.15, 0.14, left))           # ...and nothing burns in it
			else:                                                                   # a glowing lantern
				canvas.draw_circle(l, 6.0, Color(1.0, 0.78, 0.4, 0.5))
				canvas.draw_circle(l, 3.0, Color(1.0, 0.86, 0.55))


# --- the ruin: a stall that is one block short, and the block-shaped hole saying so ------------------

## An unfinished frame, drawn in the finished stall's own vocabulary at full wear, plus a marked-out slot
## where the missing block goes. Before this, a near-complete frame drew NOTHING, so the ruin the world
## stamps beside spawn, which exists to teach "build a Bazaar", was four loose wood blocks on flat ground.
func _draw_ruin(canvas: CanvasItem, origin: Vector2i, gap: Vector2i) -> void:
	for spec: Dictionary in _frame_cells():
		var cell: Vector2i = origin + (spec["rel"] as Vector2i)
		if cell == gap:
			continue                                    # nothing to dress: that is the hole
		_draw_decor(canvas, Vector2(cell.x * CELL, cell.y * CELL), String(spec["kind"]),
				cell.x, cell.y == origin.y + 1, RUIN_WEAR)
	_draw_gap(canvas, gap)


## The missing block's slot: a faint wood-coloured ghost inside a pulsing dashed outline. Dashed rather
## than solid so it reads as a MEASURED-OUT space and not as a block already there, and pulsing because it
## is the only thing on screen asking the player to do something.
func _draw_gap(canvas: CanvasItem, gap: Vector2i) -> void:
	var p := Vector2(gap.x * CELL, gap.y * CELL)
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	canvas.draw_rect(Rect2(p, Vector2(CELL, CELL)), Color(0.62, 0.44, 0.24, 0.09 + 0.11 * pulse))
	var seg: float = float(CELL) / 7.0
	var ink := Color(1.0, 0.86, 0.55, 0.40 + 0.45 * pulse)
	for i: int in 7:
		if i % 2 == 1:
			continue                                    # every other run is left out, and that is the dash
		var t: float = float(i) * seg
		canvas.draw_line(p + Vector2(t, 0.0), p + Vector2(t + seg, 0.0), ink, 2.0)
		canvas.draw_line(p + Vector2(t, CELL), p + Vector2(t + seg, CELL), ink, 2.0)
		canvas.draw_line(p + Vector2(0.0, t), p + Vector2(0.0, t + seg), ink, 2.0)
		canvas.draw_line(p + Vector2(CELL, t), p + Vector2(CELL, t + seg), ink, 2.0)


## A hanging shop sign under the awning centre.
func _draw_sign(canvas: CanvasItem, base: Vector2, a: float) -> void:
	var c := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, CELL * 0.7)
	var board := Color(0.42, 0.28, 0.16, a)
	canvas.draw_line(c + Vector2(0.0, -CELL * 0.7), c + Vector2(0.0, -2.0), Color(0.2, 0.15, 0.1, a), 1.5)
	canvas.draw_rect(Rect2(c + Vector2(-10.0, 0.0), Vector2(20.0, 11.0)), board)
	canvas.draw_rect(Rect2(c + Vector2(-10.0, 0.0), Vector2(20.0, 11.0)), Color(0.85, 0.7, 0.4, a), false, 1.0)
	canvas.draw_circle(c + Vector2(0.0, 5.5), 2.6, Color(0.95, 0.8, 0.45, a))       # a gold mark


## The shopkeeper NPC standing in the interior: a robed figure, distinct from the miner silhouette.
func _draw_keeper(canvas: CanvasItem, base: Vector2, a: float) -> void:
	var feet := base + Vector2(FactorySim.BAZAAR_W * CELL * 0.5, FactorySim.BAZAAR_H * CELL - 2.0)
	var robe := Color(0.52, 0.38, 0.62, a)                                          # plum merchant robe
	var skin := Color(0.82, 0.64, 0.48, a)
	canvas.draw_colored_polygon(PackedVector2Array([                               # robe (trapezoid)
		feet + Vector2(-7.0, 0.0), feet + Vector2(7.0, 0.0),
		feet + Vector2(4.0, -16.0), feet + Vector2(-4.0, -16.0)]), robe)
	canvas.draw_circle(feet + Vector2(0.0, -20.0), 4.0, skin)                       # head
	canvas.draw_rect(Rect2(feet + Vector2(-4.5, -25.0), Vector2(9.0, 3.0)), Color(0.86, 0.52, 0.26, a))  # turban/cap
