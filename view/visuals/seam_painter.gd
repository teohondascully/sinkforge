class_name SeamPainter
extends RefCounted

## THE ROCK PARTS ALONG A GRAIN, AND THE CURSOR IS WHAT SHOWS YOU WHERE. Ported from
## `legacy/scenes/world_renderer.gd:2262-2344` — `_draw_seams`, `_seam_wander`, `_stroke_seam`, `_aim_run`.
## `docs/LEGACY_GAP.md` PRE-4 and Lane A. `docs/DECISIONS_LEDGER.md` D0308.
##
## `core/seams.gd` has been in this repository since D0227: fully ported, integer-exact over all 196,608
## inputs, with its own suite — and **called by nothing** except `sky_painter`'s starfield hash. Its own
## header says so out loud. What kept it unwired was not difficulty; it was one `int`. `Seams.at` needs
## the world seed, `TileGrid.seed` had it, and `view/` may not reach into `sim/` to fetch it. D0308 puts
## `world_seed` on the `Observation` and this file is the first thing to call `Seams.at` at all.
##
## **WHY THERE IS NO AMBIENT PASS, WHICH IS THE LOAD-BEARING DECISION HERE AND IS LEGACY'S, NOT MINE.**
## Its header argues it better than a paraphrase would: `Seams.at` keys bedding to the ROW and joints to
## the COLUMN, so one plane spans the entire world; each cell lays its stroke on its own edge, so a run of
## them is a ruled line lying exactly on a cell boundary. At `RATE_HORIZONTAL` 0.18 and `RATE_VERTICAL`
## 0.12 that is 18% of rows and 12% of columns ruled on the grid in ink — *"which reads as graph paper: a
## renderer drawing its own storage layout."* Drawing the grain everywhere is the obvious implementation
## and it is the wrong one, and it is wrong in a way that a screenshot of a small window would not reveal.
##
## So the cursor answers instead: the cell being worked lights its own plane and the run it would shear.
## More information than an ambient hairline carried, at the moment it is worth having, and it costs the
## rest of the screen nothing.
##
## **ONE NARROWING FROM LEGACY, AND IT IS STATED RATHER THAN SILENT.** Legacy lights the grain on HOVER
## (`_aim`, gated by `_aim_in_reach and _aim_bites`). This build has no hover on the `Observation` — what
## it exposes is `mining_charging_cell`, set only on a tick where a hold actually advanced a cell
## (`sim/mining/mining.gd:301`). So the grain lights while you are WORKING a cell rather than while you
## are merely pointing at one. That is a narrowing of legacy's trigger and it keeps legacy's purpose: the
## grain has to be readable *before* the blow lands or the calve mechanic is a slot machine. When a hover
## target reaches L2, this reads it instead and nothing else here changes.
##
## **THE STROKE IS A PARTING, NOT A LINE.** A shadow with a lit lip just past it, and it WANDERS off the
## nominal cell boundary — because a parting that ran straight down a boundary would put the grid back on
## screen for exactly as long as the cursor sat there, which is the same defect the ambient pass has.
##
## **THE WANDER IS TWO SINES AND NOT A HASH**, which is legacy's own note and matters: a hash steps at
## every cell, and a plane has to BEND rather than jump. Sampled per cell INDEX, so neighbouring cells
## along a plane share an endpoint exactly and the polyline is continuous. `_test_the_polyline_is_continuous`
## asserts that rather than trusting it.

## Legacy's are absolute pixels in a world where one 32px cell was one metre. This build is 16px/metre
## (`MaterialLook.CELLS_PER_METRE` 4 at a 4px terrain cell), so every legacy pixel is 0.5 here — the same
## conversion WG-4 applies to legacy's absolute lengths (D0305). Legacy 2.2 / 2.4 / 1.7 become these.
const STROKE_W: float = 1.1
const LIP_W_RATIO: float = 0.62
const LIP_W_MIN: float = 0.5
const PERP_ORTHO: float = 1.2
const PERP_DIAG: float = 0.85

## Dimensionless (it is in CELLS), so it crosses the scale change untouched.
const WANDER: float = 0.30

const DARK: Color = Color(0.02, 0.03, 0.05, 0.60)
const LIP: Color = Color(1.0, 0.96, 0.86, 0.32)

## Legacy's `_seam_wander` verbatim: amplitudes 0.62/0.38, rates 0.73/0.31, and the second salt doubled to
## 2.1 so the two components never re-phase into one sine.
const W_A: float = 0.62
const W_B: float = 0.38
const W_RATE_A: float = 0.73
const W_RATE_B: float = 0.31
const W_SALT_SCALE: float = 1.37
const W_SALT_B: float = 2.1


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or ci == null:
		return
	var obs: Interface.Observation = frame.obs
	if obs.cell_px <= 0:
		return
	var s: float = float(obs.cell_px)
	var seam: int = Seams.at(obs.mining_charging_cell, obs.world_seed)
	for c: Vector2i in aim_run(obs):
		_stroke(ci, c, seam, s)


## The cells the worked cell's plane runs through, within one blow's reach along it.
##
## Walked with the CALVE's own gates — contiguous, same seam, still solid — so what lights up is what
## would actually shear rather than a decoration that resembles it. Legacy's `_aim_run` is explicit that
## the HEADING gate is deliberately NOT applied here: this says which way the rock parts, which is what
## you need in order to choose a heading at all.
##
## Returns an `Array`, and the order is the walk's: the worked cell first, then outward along `+axis`,
## then outward along `-axis`. Separated from the drawing because Godot exposes no way to read a
## `CanvasItem`'s draw commands back, so a decision inside `_draw` is a decision no test can see.
static func aim_run(obs: Interface.Observation) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if obs == null or not obs.mining_is_charging:
		return out
	var aim: Vector2i = obs.mining_charging_cell
	if not obs.solid_at(aim):
		return out
	var seam: int = Seams.at(aim, obs.world_seed)
	if seam == Seams.NONE:
		return out
	out.append(aim)
	var axis: Vector2i = Seams.terrain_axis(seam)
	for side: int in [1, -1]:
		for step: int in range(1, Seams.RUN_CAP):
			var c: Vector2i = aim + axis * (step * side)
			if not obs.solid_at(c) or Seams.at(c, obs.world_seed) != seam:
				break
			out.append(c)
	return out


## A smooth ±1 wander along a plane, sampled per cell index so neighbouring cells share an endpoint
## exactly. Public because continuity is the property worth asserting and it cannot be asserted through
## a `draw_line` call.
static func wander(i: int, salt: float) -> float:
	return W_A * sin(float(i) * W_RATE_A + salt) + W_B * sin(float(i) * W_RATE_B + salt * W_SALT_B)


## One cell's stretch of parting, as `{a, b, perp}` in world pixels. Split out of `_stroke` for the same
## reason `aim_run` is split out of `paint`: the geometry is the decision, `draw_line` is not.
static func stroke_geometry(c: Vector2i, seam: int, s: float) -> Dictionary:
	match seam:
		Seams.HORIZONTAL:
			var salt_h: float = float(c.y) * W_SALT_SCALE
			return {
				"a": Vector2(float(c.x) * s, (float(c.y) + wander(c.x, salt_h) * WANDER) * s),
				"b": Vector2(float(c.x + 1) * s, (float(c.y) + wander(c.x + 1, salt_h) * WANDER) * s),
				"perp": Vector2(0.0, PERP_ORTHO),
			}
		Seams.VERTICAL:
			var salt_v: float = float(c.x) * W_SALT_SCALE
			return {
				"a": Vector2((float(c.x) + wander(c.y, salt_v) * WANDER) * s, float(c.y) * s),
				"b": Vector2((float(c.x) + wander(c.y + 1, salt_v) * WANDER) * s, float(c.y + 1) * s),
				"perp": Vector2(PERP_ORTHO, 0.0),
			}
		_:
			# The diagonal runs (1,-1), so it is parameterised by x ALONE: the cell up-right of this one
			# recomputes this cell's far endpoint as its own near one, and the line joins exactly. Salting
			# by (x + y) rather than by x is what makes every cell on one anti-diagonal share a wander.
			var salt_d: float = float(c.x + c.y) * W_SALT_SCALE
			var d0: float = wander(c.x, salt_d) * WANDER * s
			var d1: float = wander(c.x + 1, salt_d) * WANDER * s
			return {
				"a": Vector2(float(c.x) * s + d0, float(c.y + 1) * s + d0),
				"b": Vector2(float(c.x + 1) * s + d1, float(c.y) * s + d1),
				"perp": Vector2(PERP_DIAG, PERP_DIAG),
			}


static func _stroke(ci: CanvasItem, c: Vector2i, seam: int, s: float) -> void:
	var g: Dictionary = stroke_geometry(c, seam, s)
	var a: Vector2 = g["a"]
	var b: Vector2 = g["b"]
	var perp: Vector2 = g["perp"]
	ci.draw_line(a, b, DARK, STROKE_W)
	ci.draw_line(a + perp, b + perp, LIP, maxf(STROKE_W * LIP_W_RATIO, LIP_W_MIN))
