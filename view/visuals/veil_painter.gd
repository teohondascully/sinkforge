class_name VeilPainter
extends RefCounted

## THE VEIL: mass occlusion and the key light. Ported from `legacy/scenes/world_renderer.gd:3002-3051
## `_bake_openness`. `docs/LEGACY_GAP.md` T1 #2 — "the single largest visual gap in the project".
##
## WHAT IT IS FOR, in legacy's own terms. Rock is not uniformly dark; it is dark in proportion to how
## BURIED it is, and a face at an opening is nearly as bright as the air beside it. Without that, carved
## space does not read as space: the gap doc measures the ported version at 0.182 vs 0.052 luma against a
## row-gradient's 0.148 vs 0.127 — a 3.5x separation where a naive depth ramp gives 1.2x.
##
## Two halves, and the second is the one a depth ramp cannot fake:
##
##   * **Mass.** A blurred openness field. How much air is near a cell decides how much light reaches it.
##   * **The key.** Burial says how much light reaches a cell and NOTHING about which way its mass faces,
##     "so a floor and a ceiling at the same burial depth come out at the same brightness and a cavern
##     reads as a dark patch rather than as a space with a lit floor and a shadowed roof". The VERTICAL
##     GRADIENT of the openness field is that missing information — positive where the air is above (an
##     up-facing surface), negative where it is below (an overhang), and already smooth because the field
##     was blurred. Light in a mine comes down, so up-facing mass gains and down-facing mass loses.
##
## **THIS IS WHERE DARKNESS LIVES.** `view/visuals/wall_painter.gd` records legacy's own regression on
## exactly this point: the wall was darkened in its own paint AND again by the veil, so a lit chamber came
## out as a black rectangle. The wall paints what the wall IS; this decides how lit it is. Neither file
## may take the other's job, and both say so.
##
## THE WINDOW QUESTION, WHICH WAS A MEASUREMENT AND NOT A DECISION. `docs/LEGACY_GAP.md` listed T1 #2 as
## blocked on a "window-vs-world scope decision" — legacy bakes over the whole world and `view/` holds
## only a window. The blur has a bounded reach, so the question has a number: see `REACH_CELLS` and
## `MARGIN_CELLS` below, and `WorldView.WINDOW_MARGIN_CELLS`, which now covers it.

## Legacy's four constants. Three are dimensionless and come over untouched; only the reach is a length.
const MASS_SHADE: float = 0.55       ## light a fully-buried cell loses against one at an opening
const KEY_STRENGTH: float = 0.30     ## brightening of fully up-facing mass, and dimming of an overhang
const KEY_GAIN: float = 3.0          ## how fast the vertical openness gradient saturates the key
const OPENNESS_SATURATE: float = 2.2 ## legacy's `clampf(_open_field[i] * 2.2, 0, 1)` — a face barely dims

## Legacy's `MASS_REACH = 2` is 2 of ITS cells, and its cell is one metre. Held in metres so the grid can
## change under it — the same discipline `WallPainter.AO_DEPTH_M` and `CrackPainter` follow, and the
## reason WG-4's re-denomination cannot silently rescale the veil.
const MASS_REACH_M: float = 2.0
const REACH_CELLS: int = int(MASS_REACH_M) * MaterialLook.CELLS_PER_METRE

## HOW FAR OUTSIDE A DRAWN CELL THIS PAINTER READS — the number that answers T1 #2's scope question.
##
## The two blur passes are on DIFFERENT AXES, so they do not add along one: `field[r][c]` is the vertical
## blur of the horizontal blur, which reads `raw` over rows `r ± REACH` and columns `c ± REACH` — a box of
## radius REACH, not 2*REACH. (Stated because the first arithmetic here doubled it and would have widened
## the observation window for nothing.) The key then reads `field` one row either side, so the total
## dependency is REACH + 1.
##
## `WorldView.WINDOW_MARGIN_CELLS` must be at least this, or the outermost drawn cells blur against cells
## the observation was never given — `solid_at` answers false for those, so every screen edge would grow a
## false halo of openness. `tests/test_veil_painter.gd` derives the margin from this rather than restating
## it, for the same reason `test_wall_painter` derives it from the AO ramp.
const MARGIN_CELLS: int = REACH_CELLS + 1


## The blurred openness field over `rect`, row-major, one float per cell in 0..1. Open cells start at 1.0
## and solid at 0.0; the two box-blur passes spread each into the other.
##
## Returned as data rather than drawn, for the reason this repo keeps rediscovering: Godot exposes no way
## to read back a `CanvasItem`'s draw commands, so a painter tested only by being called can assert
## nothing beyond "it did not crash" — which is exactly what a broken early return does.
##
## **Box-blurred by RUNNING SUM, not by re-summing a window per cell.** Legacy re-sums, which is
## `cells * (2R+1)` per pass and was affordable at R=2 on a 32px grid. At 4px cells R is 8, and this
## window is ~3,200 cells: re-summing is ~55,000 adds per pass per frame where the running sum is ~3,200.
## The two produce the same field — `tests/test_veil_painter.gd` asserts that against a direct
## transcription of legacy's own loop, so the optimisation is checked rather than argued.
static func openness(obs: Interface.Observation, rect: Rect2i) -> PackedFloat32Array:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var raw := PackedFloat32Array()
	raw.resize(w * h)
	# CLAMPED INTO THE WORLD, which is what legacy's own `clampi(col + d, 0, cols - 1)` does — its window
	# WAS the world, so the clamp was invisible there and is load-bearing here. `window` carries a margin
	# added without clamping, so it can hang past the world's edge, and every plane accessor answers `&""`
	# outside its data: without this line the out-of-world ring reads as AIR and the blur lights a false
	# halo along the world's left, right and bottom edges, brightest exactly where the world ends.
	var last := Vector2i(maxi(obs.world_cells.x - 1, 0), maxi(obs.world_cells.y - 1, 0))
	for row: int in range(h):
		for col: int in range(w):
			var c: Vector2i = rect.position + Vector2i(col, row)
			c = Vector2i(clampi(c.x, 0, last.x), clampi(c.y, 0, last.y))
			raw[row * w + col] = 0.0 if obs.solid_at(c) else 1.0
	var blur: PackedFloat32Array = _blur_axis(raw, w, h, true)
	return _blur_axis(blur, w, h, false)


## One separable box-blur pass, horizontal or vertical, edge-clamped exactly as legacy's `clampi` is.
## O(cells) via a running sum: advance the window by adding the entering sample and dropping the leaving
## one, both clamped, so the divisor stays `2R+1` at the edges and the clamped samples are counted the
## same way legacy counts them.
static func _blur_axis(src: PackedFloat32Array, w: int, h: int, horizontal: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var n: int = w if horizontal else h
	var lines: int = h if horizontal else w
	var span: float = float(REACH_CELLS * 2 + 1)
	for line: int in range(lines):
		var acc: float = 0.0
		for d: int in range(-REACH_CELLS, REACH_CELLS + 1):
			acc += src[_at(w, line, clampi(d, 0, n - 1), horizontal)]
		for i: int in range(n):
			out[_at(w, line, i, horizontal)] = acc / span
			acc -= src[_at(w, line, clampi(i - REACH_CELLS, 0, n - 1), horizontal)]
			acc += src[_at(w, line, clampi(i + REACH_CELLS + 1, 0, n - 1), horizontal)]
	return out


static func _at(w: int, line: int, i: int, horizontal: bool) -> int:
	return line * w + i if horizontal else i * w + line


## The light multiplier for one cell: 1.0 for open air, and for solid mass the burial term times the key.
## Legacy's exact expression, with `field` indexed the way `openness` returns it.
##
## Above 1.0 is legitimate and is the key BRIGHTENING up-facing mass — legacy's LightLayer multiplies, so
## a factor over one lightens. `paint` below draws that half as a separate additive pass rather than
## clamping it away, because the brightening is precisely what makes a cavern floor read as a floor.
static func shade_at(obs: Interface.Observation, rect: Rect2i, field: PackedFloat32Array,
		col: int, row: int) -> float:
	var w: int = rect.size.x
	if not obs.solid_at(rect.position + Vector2i(col, row)):
		return 1.0
	var above: float = field[maxi(row - 1, 0) * w + col]
	var below: float = field[mini(row + 1, rect.size.y - 1) * w + col]
	var key: float = clampf((above - below) * KEY_GAIN, -1.0, 1.0)
	var mass: float = lerpf(1.0 - MASS_SHADE, 1.0,
		clampf(field[row * w + col] * OPENNESS_SATURATE, 0.0, 1.0))
	return mass * (1.0 + KEY_STRENGTH * key)


## --- THE CACHE ------------------------------------------------------------------------------------
##
## **RE-BAKING EVERY FRAME IS NOT AFFORDABLE, AND LEGACY SAYS SO IN ITS SIGNATURE.** `_bake_openness`
## takes `dug_from`/`dug_to` and returns the band it actually refreshed: it keeps the field and re-bakes
## only the columns whose solidity changed. Ported without that, this measured **3.63 ms per bake on a
## 68x46 window — 21.8% of a 16.67 ms frame** — for a field that is usually identical to last frame's.
##
## The field is a pure function of (window rect, solidity inside it), so the cache is keyed on exactly
## those two: the rect, and `hash(materials)`, which is one native pass over ~3,000 bytes against two
## blur passes plus a fill. A miss costs what it always cost; a hit costs the hash.
##
## Keyed on the MATERIALS HASH rather than on a dug-cell count or a tick number, because those answer a
## different question. A count is equal across a dig that removed one cell and added another, and a tick
## number re-bakes on every tick whether or not anything moved — the first is wrong and the second is the
## thing being fixed. `tests/test_veil_painter.gd` asserts a hit returns exactly what a fresh bake does
## and that a single excavated cell MISSES.
var _cached: PackedFloat32Array = PackedFloat32Array()
var _cached_rect: Rect2i = Rect2i()
var _cached_hash: int = 0
var _has_cache: bool = false


## The field for this observation's window, from the cache when nothing that feeds it has changed.
func field_for(obs: Interface.Observation) -> PackedFloat32Array:
	var h: int = hash(obs.materials)
	if _has_cache and _cached_rect == obs.window and _cached_hash == h:
		return _cached
	_cached = openness(obs, obs.window)
	_cached_rect = obs.window
	_cached_hash = h
	_has_cache = true
	return _cached


## Sits above the terrain and the wall, below the HUD: it is a light layer, so everything it dims must
## already be on the canvas. `tests/body/reveal_view_setup.gd` holds the order.
##
## An INSTANCE method, not a static one, because of the cache above — added through
## `WorldView.add_stateful_painter`, which exists because a `Callable` does not keep a `RefCounted` alive
## and D0289 lost a whole painter to exactly that.
func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	_paint_with(frame, ci, field_for(frame.obs))


## Split from `paint_frame` so the drawing half can be exercised against a field the caller supplies.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	_paint_with(frame, ci, openness(frame.obs, frame.obs.window))


## The drawing half. The field is baked over the window INCLUDING its margin and only the visible part is
## drawn: the margin exists precisely so the drawn cells blur against real neighbours rather than against
## the window's own edge.
static func _paint_with(frame: Frame, ci: CanvasItem, field: PackedFloat32Array) -> void:
	var obs: Interface.Observation = frame.obs
	var cell_px: int = obs.cell_px
	var baked: Rect2i = obs.window
	var draw_rect: Rect2i = TerrainPainter.visit_rect(obs, frame.view_world_rect, cell_px)
	for col: int in range(draw_rect.position.x, draw_rect.end.x):
		for row: int in range(draw_rect.position.y, draw_rect.end.y):
			var li: int = col - baked.position.x
			var lj: int = row - baked.position.y
			if li < 0 or lj < 0 or li >= baked.size.x or lj >= baked.size.y:
				continue
			var s: float = shade_at(obs, baked, field, li, lj)
			if is_equal_approx(s, 1.0):
				continue
			var box := Rect2(col * cell_px, row * cell_px, cell_px, cell_px)
			if s < 1.0:
				ci.draw_rect(box, Color(0.0, 0.0, 0.0, 1.0 - s), true)
			else:
				ci.draw_rect(box, Color(1.0, 1.0, 1.0, minf(s - 1.0, 1.0)), true)
