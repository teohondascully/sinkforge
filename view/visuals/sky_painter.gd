class_name SkyPainter
extends RefCounted

## The parallax celestial backdrop: sky gradient, stars, sun and moon, clouds, the Sinkforge crown and
## the ridgeline silhouettes. Stateless; it paints onto the `CanvasItem` the coordinator hands it and
## reads nothing but the `Frame`. Cosmetic only, never the sim.
##
## THE FIRST PAINTER LIFTED (D0244). Lifted from `legacy/scenes/sky_painter.gd`, which reached into six
## private fields on a 3,656-line coordinator; this one takes `(frame, ci)` and can be drawn by anything
## that can build a `Frame`. It reads **nothing from `observe()`** -- measured, 0 sim reads -- which is
## what makes it the proof-of-contract rather than merely the prettiest file.
##
## TWO ADAPTATIONS, BOTH DERIVED RATHER THAN PICKED. Legacy authored this in a world with 32px cells and
## its surface 22 rows down; this world has 4px cells and its surface datum at row 0. Neither number was
## tuned by eye -- see `SCALE` and `HORIZON_Y` below, each of which carries its derivation.
##
## THE CLOCK IS PINNED AND THE SKY DOES NOT MOVE (Q5, ruled). There is no time system: `Frame.anim_time`
## is a constant, so the clouds do not drift, the stars do not twinkle and the ember does not breathe.
## Every expression that reads the clock is kept exactly as legacy wrote it rather than folded away,
## because the day this build grows a clock the sky should start moving without anyone re-deriving it.
## **The pinned VALUES are a look decision the director has not made** -- see `DAYLIGHT`/`DAY_PHASE`.

## Legacy world-pixels -> this world's. Legacy's cell was 32px and this one is `TERRAIN_CELL_PX` (4), so
## a length scaled by this subtends the same fraction of a screenful of CELLS as it did there. Derived,
## not dialled: the sky is composed against the terrain grain, and the grain is the cell.
const LEGACY_CELL_PX: float = 32.0
const SCALE: float = float(Interface.TERRAIN_CELL_PX) / LEGACY_CELL_PX

## Frequencies are 1/length, so they scale the OTHER way. Writing `freq * SCALE` would have stretched
## every ridge wavelength 64x instead of shrinking it 8x, and it would have looked like a deliberate
## art choice rather than an arithmetic slip.
const INV_SCALE: float = LEGACY_CELL_PX / float(Interface.TERRAIN_CELL_PX)

## The world-y of the surface. Legacy's was `SURFACE_LINE(22) * CELL(32)` = 704, because its world had
## sky rows above the datum. This world's grid STARTS at the surface: `data/bands/topsoil.yaml` is
## `from_m: 0` and `MaterialLook.depth_m(0)` is 0, so the datum is row 0 and the horizon is y = 0.
## (`open_sky` runs to `from_m: -119`, which is the air above -- not rows in the grid.)
const HORIZON_Y: float = 0.0

## THE PINNED CLOCK, AND THIS IS THE ONE KNOB THE DIRECTOR MAY WANT TO TURN.
##
## Q5 ruled "pin it, do not author a clock", which fixes that the sky does not move. It does not fix
## WHICH sky. These two values were chosen to show the director the MOST of this painter in one frame,
## which is a defensible reason to pick them and not a claim that they look right:
##
##   * `DAYLIGHT` 0.35 is dusk. Stars need `< 0.85` to draw at all, so full day would hide the starfield
##     -- the one feature that exists to prove `Seams.grain` scatters. The dusk blush peaks at 0.5, so
##     0.35 carries most of it. Full night (0.0) would show stars but flatten the horizon to one colour.
##   * `DAY_PHASE` 0.70 puts the MOON mid-transit (`p >= 0.55` selects the moon), at `arc` 0.33 -- up and
##     clear of the horizon rather than clipped at the edge of its arc.
##
## A single frame cannot show both sun and moon, and a value that shows neither would waste the gate.
## Parked for the ◆ as a look call: `docs/NEEDS_DIRECTOR.md` P015.
const DAYLIGHT: float = 0.35
const DAY_PHASE: float = 0.70

## The two star tints, both taken from the sky paint() lays down below. STAR_COLD is the night zenith
## Color(0.045, 0.06, 0.105) held at its own hue 225.0 and saturation 0.571 and carried up to full value.
## STAR_WARM is the dusk ember Color(0.62, 0.42, 0.34) that blushes the horizon, held at hue 17.1 and
## saturation 0.452 with its value solved so both tints land on the same Rec.709 luma of 145.8 in 255.
## The warm minority differs from the cold in hue alone. Neither tint is ever the brighter speck.
const STAR_COLD := Color(0.429, 0.571, 1.0)
const STAR_WARM := Color(0.776, 0.526, 0.426)

## Far-to-near ridgelines. `drop`/`amp` are legacy world-pixels (scaled at use), `freq` is 1/px (inverse
## scaled), `factor` and `color` are dimensionless and carry over untouched.
const RIDGES: Array[Dictionary] = [
	{"factor": 0.12, "drop": 205.0, "amp": 185.0, "freq": 0.004, "color": Color(0.235, 0.290, 0.400)},
	{"factor": 0.24, "drop": 150.0, "amp": 150.0, "freq": 0.006, "color": Color(0.145, 0.165, 0.225)},
	{"factor": 0.44, "drop": 55.0, "amp": 110.0, "freq": 0.010, "color": Color(0.062, 0.072, 0.112)},
]

## The Sinkforge: the endgame landmark. A colossal dormant ancient machine whose crown breaches the
## surface, a broken cog-ring on a dead industrial pylon buttressed by leaning pillars. The tip of a
## colossus spanning the depth layers, with its heart many layers down, and you descend alongside it.
## Purely cosmetic: the sim never knows it exists.
##
## `ANCHOR_X` is legacy's, scaled -- it pointed at the centre of legacy's spawn plateau, and this build
## has no authored surface yet for it to point at. It is a placeholder that puts the crown near the
## middle of a small world rather than a considered placement, and it is named in P015 with the rest.
const SINKFORGE_ANCHOR_X: float = 1552.0
const SINKFORGE_FACTOR: float = 0.20
const SINKFORGE_SCALE: float = 1.28


## Paint the whole backdrop for the far parallax layer `ci`: sky gradient + stars + sun/moon + clouds +
## the Sinkforge crown + the far-to-near ridgelines.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	var view: Rect2 = (ci.get_canvas_transform().affine_inverse() * ci.get_viewport_rect())\
		.grow(96.0 * SCALE)
	var cam: Vector2 = view.get_center()
	var dl: float = DAYLIGHT
	# Sky palette: a moody night eased toward a subdued day blue (overcast underworld, not beach
	# postcard) by the daylight level. Dusk and dawn pass through a brief warm blush at the horizon.
	var top_c: Color = Color(0.045, 0.06, 0.105).lerp(Color(0.21, 0.32, 0.50), dl)
	var hor_c: Color = Color(0.125, 0.135, 0.185).lerp(Color(0.46, 0.55, 0.66), dl)
	var blush: float = clampf(1.0 - absf(dl - 0.5) * 2.0, 0.0, 1.0)     # peaks mid-transition
	hor_c = hor_c.lerp(Color(0.62, 0.42, 0.34), blush * 0.35)           # dusk/dawn ember at the horizon
	var grad_top: float = HORIZON_Y - 420.0 * SCALE
	ci.draw_rect(Rect2(view.position, Vector2(view.size.x, maxf(0.0, grad_top - view.position.y))), top_c)
	var quad := PackedVector2Array([Vector2(view.position.x, grad_top), Vector2(view.end.x, grad_top),
		Vector2(view.end.x, HORIZON_Y), Vector2(view.position.x, HORIZON_Y)])
	ci.draw_polygon(quad, PackedColorArray([top_c, top_c, hor_c, hor_c]))
	if view.end.y > HORIZON_Y:
		ci.draw_rect(Rect2(Vector2(view.position.x, HORIZON_Y),
			Vector2(view.size.x, view.end.y - HORIZON_Y)), hor_c)
	if dl < 0.85:
		_stars(frame, ci, view, cam, grad_top, dl)
	# Sun and moon: each rides a low arc across the view during its half of the cycle, pinned to the
	# camera like any celestial thing. The sun is a warm bloom; the moon a small pale disc.
	var p: float = DAY_PHASE
	var arc: float = (p + 0.05) / 0.60 if p < 0.55 else (p - 0.55) / 0.45   # 0..1 across its transit
	var is_sun: bool = p < 0.55
	if arc >= 0.0 and arc <= 1.0:
		var body := Vector2(cam.x + (arc - 0.5) * 760.0 * SCALE,
			(HORIZON_Y - 130.0 * SCALE) - sin(arc * PI) * 240.0 * SCALE + cam.y * 0.05)
		if is_sun:
			ci.draw_circle(body, 46.0 * SCALE, Color(1.0, 0.88, 0.62, 0.10 + 0.10 * dl))
			ci.draw_circle(body, 22.0 * SCALE, Color(1.0, 0.92, 0.70, 0.30 + 0.25 * dl))
			ci.draw_circle(body, 13.0 * SCALE, Color(1.0, 0.97, 0.85, 0.85))
		else:
			ci.draw_circle(body, 18.0 * SCALE, Color(0.80, 0.85, 0.95, 0.12))
			ci.draw_circle(body, 10.0 * SCALE, Color(0.88, 0.91, 0.97, 0.85))
			# the shadowed limb
			ci.draw_circle(body + Vector2(3.5, -2.5) * SCALE, 8.0 * SCALE,
				top_c.lerp(Color(0.82, 0.86, 0.94), 0.25))
	_clouds(frame, ci, view, cam, dl)
	# The Sinkforge crown sits between the sky and the hills, drawn before the ridges so the near hill
	# occludes its base and grounds the colossus rising from behind the landscape.
	_sinkforge(frame, ci, view, cam, dl, hor_c)
	_ridges(ci, view, cam, dl, hor_c)


## Clouds: soft lozenges drifting with the wind, barely lighter than the sky. Each wraps through the
## visible span on its own phase so the cover never visibly loops. Lit by the daylight.
##
## Split out of `paint` (legacy had it inline) only to keep that function under the 50-line gate. The
## body is legacy's, unchanged but for scale.
static func _clouds(frame: Frame, ci: CanvasItem, view: Rect2, cam: Vector2, dl: float) -> void:
	var span: float = view.size.x + 500.0 * SCALE
	for i: int in 5:
		# `h` is one scalar driving six properties: parallax, x, y, alpha, drift rate and radius. It has
		# to scatter. `(i * K) % 1000` is linear and does not. Sorted, its five values ran
		# 0.000 / 0.044 / 0.283 / 0.522 / 0.761, whose four gaps are 0.044 / 0.239 / 0.239 / 0.239. Three
		# identical gaps to six decimals is the three-distance theorem at n=5 rather than a scatter, and
		# the one lattice was replicated through every property it drove: `22.0 + h * 24.0` gave radii
		# 22.0 / 23.1 / 28.8 / 34.5 / 40.3, stepping 5.736 three times running. Through Seams.grain the
		# radii have four distinct gaps.
		var h: float = float(Seams.grain(Vector2i(i, 505)) % 1000) / 1000.0
		var p2: float = 0.10 + h * 0.06                                 # nearly pinned = far away
		var cx: float = view.position.x - 250.0 * SCALE + fposmod(
			h * 4000.0 * SCALE + frame.anim_time * (4.0 + h * 3.0)
			+ cam.x * (1.0 - p2) - view.position.x, span)
		var cy: float = HORIZON_Y - (300.0 + h * 130.0) * SCALE + cam.y * (1.0 - p2) * 0.25
		var cc: Color = Color(0.42, 0.47, 0.58, 0.05 + h * 0.02) \
			.lerp(Color(0.78, 0.82, 0.88, 0.10 + h * 0.03), dl)
		var rad: float = (22.0 + h * 24.0) * SCALE
		# A wide flat lozenge (one smooth ellipse plus a smaller upper puff for form) reads as a drifting
		# cloud. A round three-circle puff reads instead as a bokeh orb or a lens flare, and overlapping
		# translucent circles scallop their edges and build alpha hotspots. Flat-fill polygons keep the
		# alpha even, so the cover stays continuous and is denser only where the two puffs cross.
		_cloud_puff(ci, Vector2(cx, cy), rad * 2.1, rad * 0.52, cc)
		_cloud_puff(ci, Vector2(cx - rad * 0.35, cy - rad * 0.30), rad * 1.15, rad * 0.5, cc)


## Ridgelines: far-to-near silhouettes. Sampled in feature space, with x shifted by the camera's
## unparallaxed remainder, so crests slide slower than the terrain. That is the whole depth illusion.
## By day they haze toward the sky (aerial perspective), by night they sink back to silhouette.
static func _ridges(ci: CanvasItem, view: Rect2, cam: Vector2, dl: float, hor_c: Color) -> void:
	for ridge: Dictionary in RIDGES:
		var f: float = float(ridge["factor"])
		var amp: float = float(ridge["amp"]) * SCALE
		var freq: float = float(ridge["freq"]) * INV_SCALE
		var base_y: float = HORIZON_Y - float(ridge["drop"]) * SCALE + cam.y * (1.0 - f) * 0.30
		# Deep underground the camera drags base_y below the polygon's fixed bottom edge, which dips the
		# crest line under the floor line into a self-intersecting polygon that fails to triangulate.
		# Clamping the crests above the floor is invisible either way, since walls cover it down there.
		var floor_y: float = HORIZON_Y + 320.0 * SCALE
		var step: float = 24.0 * SCALE
		var pts := PackedVector2Array()
		var x: float = view.position.x
		while x <= view.end.x + step:
			var u: float = (x - cam.x * (1.0 - f)) * freq
			var crest: float = sin(u * TAU) * 0.55 + sin(u * TAU * 2.31 + 1.7) * 0.30 \
				+ sin(u * TAU * 0.47 + 0.6) * 0.35
			pts.append(Vector2(x, minf(base_y - (crest * 0.5 + 0.5) * amp, floor_y - 4.0 * SCALE)))
			x += step
		pts.append(Vector2(view.end.x + step, floor_y))
		pts.append(Vector2(view.position.x, floor_y))
		# Aerial perspective. A falloff topping out a third of the way to the sky is too little air for a
		# range on the horizon, and leaves every ridge a hard dark cut-out. This curve is stronger and
		# much steeper in the parallax factor, so the farthest range nearly dissolves into the sky while
		# the nearest stays a silhouette. The steepness carries the depth: an even haze across all three
		# would only make one flat plane paler.
		ci.draw_colored_polygon(pts, (ridge["color"] as Color).lerp(hor_c, dl * maxf(0.88 - f * 1.5, 0.0)))


## The star field: a hashed scatter in near-pinned sky space. It fades in as the daylight dies and each
## speck shimmers on its own phase -- though with the clock pinned, every speck holds one phase.
##
## Scenery must not wear the interface's colour. At Color(0.85, 0.88, 0.95) these 42 specks composited
## over the night zenith at peak twinkle to Rec.709 luma 165.6 of 255 at hue 222.6 and saturation 0.124.
## The aim cursor sits at 181.3 / hue 219.0 / saturation 0.160 and the guide chevron at 198.9. That is
## three and a half degrees of hue and 0.036 of saturation off the marker stack, with a peak sixteen luma
## steps under the dimmest permanent mark on screen. On STAR_COLD/STAR_WARM the peak composites to 109.3,
## which is 72.0 below the cursor -- a wider gap than the 42.2 separating the ghost border from the sonar
## core, so the sky sits outside the marker stack instead of one step inside it.
##
## `frame.marks` is where the interface has put something the stars must not compete with. It is EMPTY in
## this build -- no objectives, no build ghost -- and legacy handles that as its designed path: "with no
## marker in the sky none of this fires and the field is exactly what it was." It replaces five separate
## private fields legacy reached for, which is the whole shape of the `Frame` contract in one argument.
## The field's VISIBLE stars, as `{"i": index, "pos": Vector2}` in index order.
##
## PUBLIC so a test can assert the two properties that separate a starfield from nothing, neither of
## which a "paint() did not crash" check would notice. **That the field is non-empty at all** -- every
## star is culled if it lands below the horizon, and after the 32px->4px rescale that was a live
## possibility rather than a hypothetical. And **that it scatters**: legacy's original used a linear
## `i * K` sequence whose sorted x values had three distinct gaps, a three-distance lattice reading as a
## comb of evenly spaced dots. One definition, read by the painter and by the test.
static func visible_stars(view: Rect2, cam_x: float, grad_top: float) -> Array:
	var out: Array = []
	for i: int in 42:
		# One salt per axis keeps position, twinkle, size and tint independent; through `Seams.grain`
		# x alone goes to 38 distinct gaps where the linear form had three.
		var sx: float = view.position.x + fposmod(
			float(Seams.grain(Vector2i(i, 101)) % 4093) * SCALE + cam_x * 0.04, view.size.x)
		var sy: float = grad_top - 60.0 * SCALE + float(Seams.grain(Vector2i(i, 202)) % 380) * SCALE
		if sy > HORIZON_Y - 90.0 * SCALE:
			continue
		out.append({"i": i, "pos": Vector2(sx, sy)})
	return out


static func _stars(frame: Frame, ci: CanvasItem, view: Rect2, cam: Vector2,
		grad_top: float, dl: float) -> void:
	var clear_r: float = float(Interface.TERRAIN_CELL_PX) * 3.25   # a chevron's own lift over its cell
	var star_a: float = (1.0 - dl) * 0.9
	for star: Dictionary in visible_stars(view, cam.x, grad_top):
		var i: int = star["i"]
		var sx: float = (star["pos"] as Vector2).x
		var sy: float = (star["pos"] as Vector2).y
		var quiet: float = 1.0
		for m: Vector2 in frame.marks:
			quiet = minf(quiet, smoothstep(0.0, clear_r, Vector2(sx, sy).distance_to(m)))
		if quiet < 0.02:
			continue                          # under a marker there is no alpha left to draw with
		var tw: float = 0.72 + 0.28 * sin(
			frame.anim_time * (1.1 + float(Seams.grain(Vector2i(i, 303)) % 13) * 0.13) + float(i))
		var tint: Color = STAR_WARM if Seams.grain(Vector2i(i, 606)) % 5 == 0 else STAR_COLD
		ci.draw_circle(Vector2(sx, sy), (1.1 + float(Seams.grain(Vector2i(i, 404)) % 3) * 0.4) * SCALE,
			Color(tint.r, tint.g, tint.b, star_a * tw * quiet * 0.8))


## One lobe of a cloud lozenge: a filled ellipse at flat alpha, so it has no scalloped edge and no
## hotspot where lobes overlap.
static func _cloud_puff(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var poly := PackedVector2Array()
	const N: int = 16
	for k: int in N:
		var a: float = float(k) / float(N) * TAU
		poly.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(poly, col)


## Draw the Sinkforge crown: a dormant colossal machine on the far horizon -- a broken cog-ring on a dead
## pylon with leaning buttresses, and a warm ember at the cog core.
static func _sinkforge(frame: Frame, ci: CanvasItem, view: Rect2, cam: Vector2,
		dl: float, hor_c: Color) -> void:
	# Skip when the surface horizon isn't in view (deep underground the walls cover the backdrop anyway).
	if view.position.y > HORIZON_Y + 200.0 * SCALE:
		return
	var f: float = SINKFORGE_FACTOR
	var s: float = SINKFORGE_SCALE * SCALE
	var cx: float = cam.x + (SINKFORGE_ANCHOR_X * SCALE - cam.x) * f   # parallaxed world x of the crown
	var base_y: float = HORIZON_Y + 30.0 * SCALE + cam.y * (1.0 - f) * 0.30
	if cx < view.position.x - 360.0 * s or cx > view.end.x + 360.0 * s:
		return
	# Silhouette: a solid mass, so darker and more present than the ridges, but still hazed by daylight.
	# Its parallax factor sits between the far and mid ranges, and beside ridges carrying real aerial
	# perspective a near-unhazed black stops reading as distance and starts reading as a sticker pasted
	# on the sky. It takes less haze than an equidistant hill would, since it is the landmark and should
	# stay the most present thing on the horizon, but it stands in the same air as everything around it.
	var sil: Color = Color(0.050, 0.058, 0.098).lerp(hor_c, dl * 0.44)
	var pyl_top: float = base_y - 250.0 * s
	# Chains: titanic catenaries hanging from the pylon shoulders; the upper spans read above the hills.
	for k: int in 2:
		var off: float = (float(k) * 2.0 - 1.0) * 40.0 * s
		var top := Vector2(cx + off, pyl_top + 20.0 * s)
		var chpts := PackedVector2Array()
		for j: int in 8:
			var t: float = float(j) / 7.0
			chpts.append(Vector2(top.x + off * 0.5 * t,
				top.y + t * (base_y + 40.0 * s - top.y) + sin(t * PI) * 22.0 * s))
		ci.draw_polyline(chpts, sil.darkened(0.12), 5.0 * s)
	# Base mesa: a broad dark industrial footing on the horizon, mostly behind the near ridge.
	var bw: float = 150.0 * s
	var bh: float = 70.0 * s
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - bw, base_y), Vector2(cx + bw, base_y),
		Vector2(cx + bw * 0.72, base_y - bh), Vector2(cx - bw * 0.72, base_y - bh)]), sil)
	# Leaning buttress pillars flanking the tower. Dead and off-vertical is what reads as ancient.
	for dir: int in [-1, 1]:
		var px: float = cx + float(dir) * 96.0 * s
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(px - 14.0 * s, base_y - bh + 6.0 * s), Vector2(px + 14.0 * s, base_y - bh + 6.0 * s),
			Vector2(px + float(dir) * 22.0 * s + 8.0 * s, base_y - 150.0 * s),
			Vector2(px + float(dir) * 22.0 * s - 8.0 * s, base_y - 150.0 * s)]), sil.darkened(0.10))
	# The central pylon rising to the cog.
	var pw: float = 40.0 * s
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - pw, base_y - bh + 4.0 * s), Vector2(cx + pw, base_y - bh + 4.0 * s),
		Vector2(cx + pw * 0.6, pyl_top), Vector2(cx - pw * 0.6, pyl_top)]), sil)
	_cog(frame, ci, Vector2(cx, pyl_top - 30.0 * s), 78.0 * s, s, sil)


## The broken cog-ring crowning the pylon: the machine motif, ruined, with an arc and teeth missing --
## and the ember heart inside it, a faint deep-red glow so the machine reads as dormant rather than dead.
## Kept subtle enough to be a buried pulse rather than a second sun. Split from `_sinkforge` for the
## 50-line function gate; the body is legacy's.
static func _cog(frame: Frame, ci: CanvasItem, ring_c: Vector2, rr: float, s: float, sil: Color) -> void:
	var gap0: float = 2.15      # the broken arc (radians): ring + teeth absent here
	var gap1: float = 3.35
	ci.draw_arc(ring_c, rr, gap1, gap0 + TAU, 40, sil, 20.0 * s)
	var teeth: int = 16
	for i: int in teeth:
		var a: float = float(i) / float(teeth) * TAU
		if a > gap0 and a < gap1:
			continue
		var dv := Vector2(cos(a), sin(a))
		ci.draw_line(ring_c + dv * (rr + 6.0 * s), ring_c + dv * (rr + 22.0 * s), sil, 11.0 * s)
	ci.draw_circle(ring_c, 22.0 * s, sil)
	for i: int in 4:
		var a: float = float(i) / 4.0 * TAU + 0.4
		ci.draw_line(ring_c, ring_c + Vector2(cos(a), sin(a)) * (rr - 6.0 * s), sil, 7.0 * s)
	var pulse: float = 0.5 + 0.5 * sin(frame.anim_time * 0.55)
	for gi: int in 3:
		var gr: float = (13.0 + float(gi) * 15.0) * s
		var ga: float = (0.065 - float(gi) * 0.018) * (0.5 + 0.5 * pulse)
		ci.draw_circle(ring_c, gr, Color(0.85, 0.30, 0.12, ga))
	ci.draw_circle(ring_c, 6.0 * s, Color(1.0, 0.52, 0.26, 0.09 + 0.07 * pulse))
