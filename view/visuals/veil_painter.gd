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


## --- THE LAMP -------------------------------------------------------------------------------------
##
## **"LIGHT REVEALS, IT DOES NOT PAINT"** — `world_renderer.gd:3221 _veil_cut`, and legacy states the
## consequence as a measured regression: the lamp's job is to CUT A HOLE IN THE VEIL, "which is what
## actually makes rock visible", and the amber bloom on top is halo. "An additive term strong enough to
## swamp the reveal repaints the rock the veil just uncovered: three overlapping pools summed past 1.0,
## tripped the glow threshold and blew the centre of the frame to a white smear."
##
## So the lamp lands here, in the veil, and not as a glow painter over it. D0302 shipped the veil and made
## the deep correctly and unusably dark, because legacy's veil never worked without this.
##
## THREE CUTS, legacy's own radii and strengths — `world_renderer.gd:3163-3165`. Radii are legacy CELLS,
## and a legacy cell is one metre, so they are held in METRES here like every other length in this file.
## THE SKYLIGHT CEILING — legacy `world_renderer.gd:3263-3270 _skylight_alpha` (D0332).
##
## **THE VEIL DARKENS BY BURIAL AND, UNTIL NOW, NOT BY DEPTH.** `MASS_SHADE` decides how much light a
## fully-buried cell loses relative to one at an opening, and that is a purely local quantity — so a
## buried cell two metres down and one two hundred metres down came out at exactly the same brightness,
## and the whole underground read as evenly lit at every depth. A capture at 7 m showed it plainly: the
## frame is legible everywhere and nothing is dark, where legacy's entire identity is light pools in
## blackness.
##
## Legacy's answer is a second, independent term: how much SKY reaches this row at all. It attenuates with
## depth past the surface line, is blocked by the first solid rock, and scatters a little way under it.
##
## **COMPOSED AS A CEILING, NOT AS ANOTHER DARK RECT**, and that ordering is legacy's own rule (quoted in
## `_paint_with` below): a light raises the light LEVEL rather than lowering an opacity, so a lit cell
## trends toward full light and can never overshoot. The skylight caps how bright a cell can be before the
## lamp is considered; the lamp then lifts what is left. Drawing a second black rect on top would be the
## regression `view/visuals/wall_painter.gd` records — the wall darkened in its own paint AND again by the
## veil, so a lit chamber came out as a black rectangle. **There is one darkness in this renderer.**
##
## IN METRES, like `lamp_scale` above and for the same reason: legacy's tiles are one metre and this
## build's are a quarter of one, so a constant copied as ROWS would be four times too shallow.
const AMBIENT_DARK: float = 0.66      ## legacy `:79` — light a fully sky-cut cell has lost
const SKY_REACH_M: float = 12.0       ## legacy `SKY_REACH 12` tiles of open air sunlight reaches
const SKY_FADE_M: float = 16.0        ## legacy `SKY_FADE 16` — how far light scatters under solid rock
const SURFACE_LINE_M: float = 2.0     ## legacy `SURFACE_LINE 22` against its `SURFACE_ROW 20`

## The most light a cell at this row can receive, before mass, key or lamp. 1.0 at the surface, falling to
## `1 - AMBIENT_DARK` in the deep.
##
## **LEGACY'S `daylight()` TERM IS DELIBERATELY ABSENT.** Legacy blends a `NIGHT_DARK` floor from a day
## cycle; this build has none and D0277 ruled sky variation depth-driven rather than clock-driven, so that
## term would be a constant 1.0 and is omitted rather than written as a factor that can never move — the
## same treatment `view/camera_rig.gd` gives legacy's stride multiplier.
static func skylight_ceiling(row: int) -> float:
	var depth_m: float = MaterialLook.depth_m_exact(row)
	var sky: float = AMBIENT_DARK * clampf((depth_m - SURFACE_LINE_M) / SKY_REACH_M, 0.0, 1.0)
	# Legacy also scatters light a further `SKY_FADE` under the first solid rock. Without a per-column
	# surface row on the observation this build cannot ask "is this cell under rock", so the scatter is
	# folded into the reach above rather than approximated — stated so the difference is not mistaken for
	# a porting slip. `Observation` carries `surface_y` per column and wiring it is the follow-up.
	return 1.0 - sky


const LAMP_BEAM_M: float = 9.0        ## the aimed beam: wide reveal, open core
const LAMP_BEAM_STRENGTH: float = 0.99
const LAMP_THROAT_M: float = 5.0      ## the beam throat, between the head and the cast pool
const LAMP_THROAT_STRENGTH: float = 0.8
const LAMP_BODY_M: float = 3.4        ## the close body glow
const LAMP_BODY_STRENGTH: float = 0.5
const LAMP_LEAD_M: float = 1.9        ## how far the pool leads toward what the miner is working

## Legacy's textured falloff, unchanged: two crossed sines under a window that peaks mid-falloff and
## vanishes at both ends, "so the bright centre is unbroken" and "light dissolves into the rock grain as
## it fades" rather than ending in a clean gaussian blob.
const LAMP_GRAIN: float = 0.13
const LAMP_WINDOW_GAIN: float = 2.2

## **THE LAMP IS SCALED BY HOW DARK THE MINER'S OWN SPOT IS**, and legacy records the regression it fixes:
## "at spawn the full-strength lamp washed out both the avatar and the starter ore it sits on, so every
## warm thing read as a lamp." A full blaze in the deep where it IS the light; a dim glow in daylight.
##
## Legacy scales by `_skylight_alpha(...) / AMBIENT_DARK`, and this build has no skylight term — the same
## missing quantity `GlintPainter.depth_gate` substitutes for, resolved the same way and for the same
## reason, so the two do not disagree about what "deep" means. Legacy's own floor is 0.30.
const LAMP_SURFACE_SCALE: float = 0.30   ## legacy's `lerpf(0.30, 1.0, ...)`
const LAMP_FULL_M: float = 12.0          ## at and below this depth the lamp is the light (SKY_REACH)
const LAMP_NONE_M: float = 0.0           ## at the surface datum it is at its floor, never off


## How much light one cut lifts at `cell`, 0..1. `centre` and `radius` are in CELLS.
static func cut_lift(centre: Vector2, radius: float, strength: float, cell: Vector2i) -> float:
	var d: Vector2 = Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) - centre
	var dist: float = d.length()
	if dist >= radius or radius <= 0.0:
		return 0.0
	var f: float = 1.0 - dist / radius
	var window: float = (1.0 - f) * clampf(f * LAMP_WINDOW_GAIN, 0.0, 1.0)
	var g: float = (sin(float(cell.x) * 1.7 + float(cell.y) * 2.3) * 0.62
		+ sin(float(cell.x) * 4.1 - float(cell.y) * 3.7) * 0.38) * LAMP_GRAIN * window
	return clampf(strength * f * f + g * strength, 0.0, 1.0)


## Where the lamp's beam points, in CELLS. Legacy leads toward the cursor's aim; nothing puts an aim on
## the observation (the cursor is the human's, and `docs/DECISIONS_LEDGER.md` records why that stays out
## of the sim), so the beam leads toward THE CELL BEING WORKED when there is one, and along `facing`
## otherwise. Same intent — the pool goes where the attention is — expressed in what crosses the L2 door.
static func lamp_head(obs: Interface.Observation) -> Vector2:
	var head: Vector2 = Vector2(obs.cell) + Vector2(0.5, 0.5)
	var lead_cells: float = LAMP_LEAD_M * float(MaterialLook.CELLS_PER_METRE)
	var toward: Vector2 = Vector2(float(obs.facing), 0.0)
	if obs.mining_is_charging:
		var to_cell: Vector2 = Vector2(obs.mining_charging_cell) + Vector2(0.5, 0.5) - head
		if to_cell.length() > 0.001:
			toward = to_cell.normalized()
	return head + toward * lead_cells


## The three cuts composited the way legacy composites them: each source lifts whatever the previous one
## left, `l -> l + (1 - l) * lift`, so overlapping pools brighten toward full light and can never
## overshoot it. Returns 0..1.
static func lamp_scale(row: int) -> float:
	var depth: float = MaterialLook.depth_m_exact(row)
	var t: float = clampf((depth - LAMP_NONE_M) / (LAMP_FULL_M - LAMP_NONE_M), 0.0, 1.0)
	return lerpf(LAMP_SURFACE_SCALE, 1.0, t)


static func lamp_lift(obs: Interface.Observation, cell: Vector2i) -> float:
	if obs == null:
		return 0.0
	var m: float = float(MaterialLook.CELLS_PER_METRE)
	var scale: float = lamp_scale(obs.cell.y)
	var head: Vector2 = lamp_head(obs)
	var body: Vector2 = Vector2(obs.cell) + Vector2(0.5, 0.5)
	var lit: float = 0.0
	for cut: Array in [[head, LAMP_BEAM_M, LAMP_BEAM_STRENGTH],
			[body.lerp(head, 0.45), LAMP_THROAT_M, LAMP_THROAT_STRENGTH],
			[body, LAMP_BODY_M, LAMP_BODY_STRENGTH]]:
		lit += (1.0 - lit) * cut_lift(cut[0], float(cut[1]) * m, float(cut[2]) * scale, cell)
	return clampf(lit, 0.0, 1.0)


## The openness field held between frames. `view/visuals/veil_field_cache.gd` owns the keying and the
## reason it is a hash rather than a tick; this owns only the field's definition.
var _cache: VeilFieldCache = VeilFieldCache.new()

## The lightmap this painter uploads to (D0336). Held per painter rather than per frame so the `Image` and
## its `ImageTexture` are allocated once and mutated in place.
var _map: VeilMap = VeilMap.new()


## The field for this observation's window, from the cache when nothing that feeds it has changed.
func field_for(obs: Interface.Observation) -> PackedFloat32Array:
	return _cache.field_for(obs, openness)


## Sits above the terrain and the wall, below the HUD: it is a light layer, so everything it dims must
## already be on the canvas. `tests/body/reveal_view_setup.gd` holds the order.
##
## An INSTANCE method, not a static one, because of the cache above — added through
## `WorldView.add_stateful_painter`, which exists because a `Callable` does not keep a `RefCounted` alive
## and D0289 lost a whole painter to exactly that.
## THE LIGHTMAP PATH (D0336). One `draw_texture_rect` where this used to issue one `draw_rect` per visible
## cell — 14,080 of them at the 40-metre framing, measured at **41.47 ms of a 54.23 ms frame** against a
## 120 Hz budget of 8.33. Legacy's own shape, `world_renderer.gd:330` and `:2769`.
##
## `_paint_with` below is KEPT, and not as dead code: it is the per-cell reference this path is asserted
## byte-equivalent to, and `paint()` still mounts it for any caller without a render target. Legacy's own
## rule for a flattened hot path (`legacy/tools/check_paint_terms.gd:5`) is to keep the readable loop as
## the specification rather than delete it.
##
## The composition is unchanged and that is provable rather than hoped: the old path drew black at alpha
## `1 - s`, which composites to `dest * s`; a MULTIPLY blend against a texel of value `s` is `dest * s`.
## Same expression, one call instead of fourteen thousand.
func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	var obs: Interface.Observation = frame.obs
	var field: PackedFloat32Array = field_for(obs)
	var baked: Rect2i = obs.window
	# THE MAP COVERS WHAT IS DRAWN, NOT WHAT IS OBSERVED (D0340). The observation's window is deliberately
	# larger than the screen -- `WINDOW_MARGIN_CELLS` for the blur's neighbours, and since D0340 snapped
	# outward again so the plane cache can hold still while the camera moves. None of that extra needs a
	# TEXEL: it exists so the light FIELD has real neighbours to blur against, which `field_for` above has
	# already used. Building texels for it cost 4.73 ms against 3.58 for the visible rect alone.
	#
	# Clipped to the window rather than used raw, because `light_at` answers 1.0 outside it and a map that
	# reached past the observation would fade to full light at the screen edge.
	var drawn: Rect2i = TerrainPainter.visit_rect(obs, frame.view_world_rect, obs.cell_px).intersection(baked)
	if drawn.size.x <= 0 or drawn.size.y <= 0:
		return
	var tex: ImageTexture = _map.build(drawn, func(col: int, row: int) -> float:
		return light_at(obs, baked, field, col, row))
	if tex == null:
		return
	ci.draw_texture_rect(tex, _map.world_rect(obs.cell_px), false)


## The composed light level for one cell: the ceiling, then mass and key, then the lamp. Lifted out of
## `_paint_with`'s loop body unchanged so the lightmap and the per-cell reference evaluate the SAME
## expression rather than two that are believed to agree.
##
## Answers 1.0 — full light, no darkening — outside the baked window. That is the honest answer for a
## texel the observation cannot speak about, and it is the safe one: the alternative reads as a black bar
## at the screen edge (D0238's trap, where `material_at` answers `&""` outside the window exactly as it
## does for air).
static func light_at(obs: Interface.Observation, baked: Rect2i, field: PackedFloat32Array,
		col: int, row: int) -> float:
	var li: int = col - baked.position.x
	var lj: int = row - baked.position.y
	if li < 0 or lj < 0 or li >= baked.size.x or lj >= baked.size.y:
		return 1.0
	# THE CEILING FIRST, then mass and key, then the lamp. Multiplying rather than subtracting keeps the
	# composition monotone: a cell can lose light to depth and to burial independently and never go below
	# zero, which is what a subtractive stack would do in deep buried rock.
	var s: float = shade_at(obs, baked, field, li, lj) * skylight_ceiling(row)
	# THE LAMP LIFTS WHAT THE VEIL LEFT, legacy's own composition rule: a light raises the light level
	# rather than lowering an opacity, so a lit cell trends toward full light and can never overshoot it.
	return s + (1.0 - s) * lamp_lift(obs, Vector2i(col, row))


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
			# THE SAME EXPRESSION THE LIGHTMAP EVALUATES, called rather than restated (D0336). Two copies
			# of this composition would be two things believed to agree; one function is one thing.
			var s: float = light_at(obs, baked, field, col, row)
			if is_equal_approx(s, 1.0):
				continue
			var box := Rect2(col * cell_px, row * cell_px, cell_px, cell_px)
			if s < 1.0:
				ci.draw_rect(box, Color(0.0, 0.0, 0.0, 1.0 - s), true)
			else:
				ci.draw_rect(box, Color(1.0, 1.0, 1.0, minf(s - 1.0, 1.0)), true)
