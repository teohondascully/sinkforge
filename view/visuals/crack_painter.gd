class_name CrackPainter
extends RefCounted

## SPIDER CRACKS ON ROCK BEING WORKED. Ported from `legacy/scenes/world_renderer.gd:944-968`
## (`_draw_mine_cracks`), `docs/LEGACY_GAP.md` T1 #5.
##
## Legacy's own reason for it: "so hand-mining reads as effortful work on a specific block rather than an
## instant pop." **Mining in this build currently has no feedback at all** — rock is solid, then it is
## gone. The sim side was already computed and thrown away until D0274 opened the L2 door; this is the
## first consumer of what came through it.
##
## DETERMINISTIC, NO RNG, exactly as legacy: the crack angles come from the cell's own coordinates, so
## two runs of the same seed paint identically and a capture can be compared against a previous one.
## That is not a stylistic preference here — `docs/QUALITY.md`'s whole screenshot-comparison discipline
## depends on the renderer being a function of state.
##
## **THE ONE NUMBER THAT IS NOT LEGACY'S, AND WHY.** Legacy sizes every crack as a fraction of `CELL`,
## which is **32px** there and **4px** here (`Observation.cell_px`). Ported literally, a crack
## would be 0.7 to 2 pixels long: invisible. That is `docs/LEGACY_GAP.md` WG-4, "cell-denominated
## constants never converted, every feature 4x undersized", and WG-4 is parked for the director.
##
## So the RATIO is ported and the unit it multiplies is stated instead of assumed. Legacy's crack spans a
## fraction of the area **one blow destroys**, and one legacy blow destroys one 32px cell. One blow here
## destroys a disc of `bite_radius` cells, so the honest analogue is the blow's own footprint in pixels,
## which the caller passes in. At the default radius 2 that is 20px, giving 3.6–10.4px cracks — legacy's
## proportions at this build's scale. If WG-4 is ruled on and the grid is re-denominated, this file needs
## no change: it is already expressed against the blow, not against the cell.

## Legacy's constants, unchanged. Every one of them is a fraction or a colour; none is a pixel count,
## which is why they transfer while the size above does not.
const SHADE_ALPHA: float = 0.22        ## the weakening darkening over the whole worked cell
const CRACK_MIN: int = 2               ## `2 + int(frac * 5)` fractures
const CRACK_PER_FRAC: float = 5.0
const LEN_BASE: float = 0.18           ## of the blow footprint
const LEN_PER_FRAC: float = 0.34
const ELBOW_TURN: float = 0.4          ## radians the second segment kinks by -- what makes it read as a fracture
const SHADOW_ALPHA: float = 0.45
const SHADOW_WIDTH: float = 3.0
const CRACK_WIDTH: float = 1.5
const PIP_BASE: float = 1.5
const PIP_PER_FRAC: float = 2.0

## Light fractures over a dark underlay, so they read on ANY material in the dark underground — legacy's
## note, and the reason there are two draws per segment rather than one.
const SHADOW: Color = Color(0.0, 0.0, 0.0, 1.0)
const CRACK: Color = Color(0.92, 0.94, 1.0, 1.0)
const CRACK_ALPHA_BASE: float = 0.30
const CRACK_ALPHA_PER_FRAC: float = 0.6
const PIP: Color = Color(1.0, 0.96, 0.85, 1.0)
const PIP_ALPHA: float = 0.5

## Below this there is nothing to show and drawing would be noise on every cell the player brushed past.
## Legacy's own `_mine_frac <= 0.001` guard, in per mille.
const MIN_VISIBLE: int = 1


## The deterministic base angle for a cell. Legacy's `x * 0.7 + y * 1.3`, kept because it is the thing
## that makes two adjacent cracked cells look different rather than stamped.
##
## NOT a hash and not trying to be. It is a plane, so nearby cells get nearby angles — which is what
## legacy wanted (a fracture field, not confetti). Worth naming because the shape looks like the
## `linear-sequence-as-hash` mistake and is not one: nothing here needs uniformity, only variety.
static func base_angle(cell: Vector2i) -> float:
	return float(cell.x) * 0.7 + float(cell.y) * 1.3


## How many fractures a cell at `progress` per mille shows. Legacy's `2 + int(frac * 5.0)`.
static func crack_count(progress_per_mille: int) -> int:
	return CRACK_MIN + int(float(progress_per_mille) / 1000.0 * CRACK_PER_FRAC)


## One cell's cracks, in WORLD pixels. Returns the segments and the pip as data rather than drawing them,
## for the same reason `view/hud/depth_chip.gd` splits `layout` out of `paint`: Godot exposes no way to
## read back a `CanvasItem`'s draw commands, so a painter tested only by being called can assert nothing
## beyond "it did not crash" — and an early return does exactly that while drawing nothing.
##
## `blow_px` is the diameter of what one blow destroys. See the header for why that, and not the cell.
static func segments(cell: Vector2i, progress_per_mille: int, cell_px: int, blow_px: float) -> Array:
	if progress_per_mille < MIN_VISIBLE:
		return []
	var frac: float = clampf(float(progress_per_mille) / 1000.0, 0.0, 1.0)
	var centre := Vector2(cell) * float(cell_px) + Vector2(cell_px, cell_px) * 0.5
	var n: int = crack_count(progress_per_mille)
	var length: float = blow_px * (LEN_BASE + LEN_PER_FRAC * frac)
	var out: Array = []
	for i: int in n:
		var ang: float = TAU * float(i) / float(n) + base_angle(cell)
		var elbow: Vector2 = centre + Vector2(cos(ang), sin(ang)) * length * 0.5
		var tip: Vector2 = centre + Vector2(cos(ang + ELBOW_TURN), sin(ang + ELBOW_TURN)) * length
		out.append([centre, elbow])
		out.append([elbow, tip])
	return out


## Draws every cracked cell in the observation. Takes the crack map as a plain `Dictionary` of
## `Vector2i -> per-mille`, exactly as `Interface.Observation.mining_cracks` carries it, so this is
## callable from a test without an `Interface` at all.
static func paint(cracks: Dictionary, ci: CanvasItem, cell_px: int, blow_px: float) -> void:
	for cell: Vector2i in cracks:
		var progress: int = int(cracks[cell])
		var segs: Array = segments(cell, progress, cell_px, blow_px)
		if segs.is_empty():
			continue
		var frac: float = clampf(float(progress) / 1000.0, 0.0, 1.0)
		var pos := Vector2(cell) * float(cell_px)
		ci.draw_rect(Rect2(pos, Vector2(cell_px, cell_px)), Color(0.0, 0.0, 0.0, SHADE_ALPHA * frac))
		var shadow := Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW_ALPHA * frac)
		var crack := Color(CRACK.r, CRACK.g, CRACK.b, CRACK_ALPHA_BASE + CRACK_ALPHA_PER_FRAC * frac)
		# Every shadow first, then every bright line, rather than shadow-then-bright per segment: with
		# the per-segment order a later fracture's underlay prints over an earlier one's bright line and
		# the star reads as broken spokes.
		for s: Array in segs:
			ci.draw_line(s[0], s[1], shadow, SHADOW_WIDTH)
		for s: Array in segs:
			ci.draw_line(s[0], s[1], crack, CRACK_WIDTH)
		var centre := pos + Vector2(cell_px, cell_px) * 0.5
		ci.draw_circle(centre, PIP_BASE + PIP_PER_FRAC * frac, Color(PIP.r, PIP.g, PIP.b, PIP_ALPHA * frac))


## The `(frame, ci)` painter form, for a `PaintLayer` on the coordinator. Everything it needs arrives
## through `Interface.Observation` -- the crack fractions and the blow footprint both -- which is the
## point rather than an implementation detail: driving this from the sim objects directly would draw the
## same picture while proving none of the L2 contract that D0274 opened.
static func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var blow: float = float(frame.obs.mining_blow_px)
	if blow <= 0.0 or frame.obs.cell_px <= 0:
		return   ## a zero-radius bite, or an observation that carries no scale: nothing to size against
	paint(frame.obs.mining_cracks, ci, frame.obs.cell_px, blow)
