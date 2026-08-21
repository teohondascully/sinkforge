extends RefCounted

## The parallax celestial backdrop: sky gradient, stars, sun and moon, clouds, the Sinkforge crown and
## the ridgeline silhouettes. Stateless; it paints onto the backdrop CanvasItem the renderer hands it and
## reads the renderer's cosmetic clock and day/night phase. Tuning constants live as WorldRenderer consts
## (RIDGES, SINKFORGE_*, SURFACE_LINE). Cosmetic only, never the sim.

## The two star tints, both taken from the sky paint() lays down below. STAR_COLD is the night zenith
## Color(0.045, 0.06, 0.105) held at its own hue 225.0 and saturation 0.571 and carried up to full value.
## STAR_WARM is the dusk ember Color(0.62, 0.42, 0.34) that blushes the horizon, held at hue 17.1 and
## saturation 0.452 with its value solved so both tints land on the same Rec.709 luma of 145.8 in 255.
## The warm minority differs from the cold in hue alone. Neither tint is ever the brighter speck.
const STAR_COLD := Color(0.429, 0.571, 1.0)
const STAR_WARM := Color(0.776, 0.526, 0.426)


## Paint the whole backdrop for the far parallax layer `ci`: sky gradient + stars + sun/moon + clouds +
## the Sinkforge crown + the far-to-near ridgelines.
static func paint(r: WorldRenderer, ci: CanvasItem) -> void:
	var view: Rect2 = (ci.get_canvas_transform().affine_inverse() * ci.get_viewport_rect()).grow(96.0)
	var cam: Vector2 = view.get_center()
	var horizon: float = float(WorldRenderer.SURFACE_LINE) * float(WorldRenderer.CELL)
	var dl: float = r.daylight()
	# Sky palette: a moody night eased toward a subdued day blue (overcast underworld, not beach
	# postcard) by the daylight level. Dusk and dawn pass through a brief warm blush at the horizon.
	var top_c: Color = Color(0.045, 0.06, 0.105).lerp(Color(0.21, 0.32, 0.50), dl)
	var hor_c: Color = Color(0.125, 0.135, 0.185).lerp(Color(0.46, 0.55, 0.66), dl)
	var blush: float = clampf(1.0 - absf(dl - 0.5) * 2.0, 0.0, 1.0)     # peaks mid-transition
	hor_c = hor_c.lerp(Color(0.62, 0.42, 0.34), blush * 0.35)           # dusk/dawn ember at the horizon
	var grad_top: float = horizon - 420.0
	ci.draw_rect(Rect2(view.position, Vector2(view.size.x, maxf(0.0, grad_top - view.position.y))), top_c)
	var quad := PackedVector2Array([Vector2(view.position.x, grad_top), Vector2(view.end.x, grad_top),
		Vector2(view.end.x, horizon), Vector2(view.position.x, horizon)])
	ci.draw_polygon(quad, PackedColorArray([top_c, top_c, hor_c, hor_c]))
	if view.end.y > horizon:
		ci.draw_rect(Rect2(Vector2(view.position.x, horizon),
			Vector2(view.size.x, view.end.y - horizon)), hor_c)
	# Stars, once the daylight has died back far enough for any of them to carry. Palette rationale for the
	# field is over _stars.
	if dl < 0.85:
		_stars(r, ci, view, cam, grad_top, horizon, dl)
	# Sun and moon: each rides a low arc across the view during its half of the cycle, pinned to the
	# camera like any celestial thing. The sun is a warm bloom; the moon a small pale disc.
	var p: float = r.day_phase()
	var arc: float = (p + 0.05) / 0.60 if p < 0.55 else (p - 0.55) / 0.45   # 0..1 across its transit
	var is_sun: bool = p < 0.55
	if arc >= 0.0 and arc <= 1.0:
		var body := Vector2(cam.x + (arc - 0.5) * 760.0,
			(horizon - 130.0) - sin(arc * PI) * 240.0 + cam.y * 0.05)
		if is_sun:
			ci.draw_circle(body, 46.0, Color(1.0, 0.88, 0.62, 0.10 + 0.10 * dl))
			ci.draw_circle(body, 22.0, Color(1.0, 0.92, 0.70, 0.30 + 0.25 * dl))
			ci.draw_circle(body, 13.0, Color(1.0, 0.97, 0.85, 0.85))
		else:
			ci.draw_circle(body, 18.0, Color(0.80, 0.85, 0.95, 0.12))
			ci.draw_circle(body, 10.0, Color(0.88, 0.91, 0.97, 0.85))
			ci.draw_circle(body + Vector2(3.5, -2.5), 8.0, top_c.lerp(Color(0.82, 0.86, 0.94), 0.25))  # the shadowed limb
	# Clouds: soft lozenges drifting with the wind, barely lighter than the sky. Each wraps through the
	# visible span on its own phase so the cover never visibly loops. Lit by the daylight.
	var span: float = view.size.x + 500.0
	for i: int in 5:
		# `h` is one scalar driving six properties: parallax, x, y, alpha, drift rate and radius. It has to
		# scatter. `(i * K) % 1000` is linear and does not. Sorted, its five values ran
		# 0.000 / 0.044 / 0.283 / 0.522 / 0.761, whose four gaps are 0.044 / 0.239 / 0.239 / 0.239. Three
		# identical gaps to six decimals is the three-distance theorem at n=5 rather than a scatter, and
		# the one lattice was replicated through every property it drove: `22.0 + h * 24.0` gave radii
		# 22.0 / 23.1 / 28.8 / 34.5 / 40.3, stepping 5.736 three times running. Through Seams.grain the
		# radii have four distinct gaps.
		var h: float = float(Seams.grain(Vector2i(i, 505)) % 1000) / 1000.0
		var p2: float = 0.10 + h * 0.06                                 # nearly pinned = far away
		var cx: float = view.position.x - 250.0 + fposmod(
			h * 4000.0 + r._anim_time * (4.0 + h * 3.0) + cam.x * (1.0 - p2) - view.position.x, span)
		var cy: float = horizon - 300.0 - h * 130.0 + cam.y * (1.0 - p2) * 0.25
		var cc: Color = Color(0.42, 0.47, 0.58, 0.05 + h * 0.02) \
			.lerp(Color(0.78, 0.82, 0.88, 0.10 + h * 0.03), dl)
		var rad: float = 22.0 + h * 24.0
		# A wide flat lozenge (one smooth ellipse plus a smaller upper puff for form) reads as a drifting
		# cloud. A round three-circle puff reads instead as a bokeh orb or a lens flare, and overlapping
		# translucent circles scallop their edges and build alpha hotspots. Flat-fill polygons keep the
		# alpha even, so the cover stays continuous and is denser only where the two puffs cross.
		_cloud_puff(ci, Vector2(cx, cy), rad * 2.1, rad * 0.52, cc)
		_cloud_puff(ci, Vector2(cx - rad * 0.35, cy - rad * 0.30), rad * 1.15, rad * 0.5, cc)
	# The Sinkforge crown sits between the sky and the hills, drawn before the ridges so the near hill
	# occludes its base and grounds the colossus rising from behind the landscape.
	_sinkforge(r, ci, view, cam, horizon, dl, hor_c)
	# Ridgelines: far-to-near silhouettes. Sampled in feature space, with x shifted by the camera's
	# unparallaxed remainder, so crests slide slower than the terrain. That is the whole depth illusion.
	# By day they haze toward the sky (aerial perspective), by night they sink back to silhouette.
	for ridge: Dictionary in WorldRenderer.RIDGES:
		var f: float = float(ridge["factor"])
		var amp: float = float(ridge["amp"])
		var freq: float = float(ridge["freq"])
		var base_y: float = horizon - float(ridge["drop"]) + cam.y * (1.0 - f) * 0.30
		# Deep underground the camera drags base_y below the polygon's fixed bottom edge, which dips the
		# crest line under the floor line into a self-intersecting polygon that fails to triangulate.
		# Clamping the crests above the floor is invisible either way, since walls cover it down there.
		var floor_y: float = horizon + 320.0
		var pts := PackedVector2Array()
		var x: float = view.position.x
		while x <= view.end.x + 24.0:
			var u: float = (x - cam.x * (1.0 - f)) * freq
			var crest: float = sin(u * TAU) * 0.55 + sin(u * TAU * 2.31 + 1.7) * 0.30 \
				+ sin(u * TAU * 0.47 + 0.6) * 0.35
			pts.append(Vector2(x, minf(base_y - (crest * 0.5 + 0.5) * amp, floor_y - 4.0)))
			x += 24.0
		pts.append(Vector2(view.end.x + 24.0, floor_y))
		pts.append(Vector2(view.position.x, floor_y))
		# Aerial perspective. A falloff topping out a third of the way to the sky is too little air for a
		# range on the horizon, and leaves every ridge a hard dark cut-out. This curve is stronger and much
		# steeper in the parallax factor, so the farthest range nearly dissolves into the sky while the
		# nearest stays a silhouette. The steepness carries the depth: an even haze across all three would
		# only make one flat plane paler.
		ci.draw_colored_polygon(pts, (ridge["color"] as Color).lerp(hor_c, dl * maxf(0.88 - f * 1.5, 0.0)))


## The star field: a hashed scatter in near-pinned sky space. It fades in as the daylight dies and each
## speck shimmers on its own phase.
##
## Scenery must not wear the interface's colour. At Color(0.85, 0.88, 0.95) these 42 specks composited
## over the night zenith at peak twinkle to Rec.709 luma 165.6 of 255 at hue 222.6 and saturation 0.124.
## The aim cursor sits at 181.3 / hue 219.0 / saturation 0.160 and the guide chevron at 198.9. That is
## three and a half degrees of hue and 0.036 of saturation off the marker stack, with a peak sixteen luma
## steps under the dimmest permanent mark on screen. The old twinkle compounded it: alpha ran 0.072 to
## 0.720 and carried a speck from luma 30.4 to 165.6. An 82 percent modulation reads as a mark flashing
## rather than as air moving.
##
## On STAR_COLD/STAR_WARM the peak composites to 109.3. That is 72.0 below the cursor, a wider gap than
## the 42.2 separating the ghost border at 200.8 from the sonar core at 243.0, so the sky sits outside the
## marker stack instead of one step inside it. Presence at rest barely moves, because the trough comes up
## as the peak comes down: the mean over a twinkle cycle goes 98.0 to 83.0, a 15 percent drop against the
## peak's 34, at the same 42 specks and the same radii. Five of the 42 take the warm tint on salt 606.
##
## Density then answers to what the interface is doing. A guide chevron rides CELL * 3.25 above the cell
## it names and tethers back down to it, and a held build ghost puts a chrome box on the aim cell. Worked
## near the surface, both stand inside this field. Each clears a disc the size of that lift, so specks
## fade to nothing across the marker and the cell it points at and are untouched everywhere else. One
## radius covers both marks, sized on the taller rig. With no marker in the sky none of this fires and the
## field is exactly what it was.
static func _stars(r: WorldRenderer, ci: CanvasItem, view: Rect2, cam: Vector2,
		grad_top: float, horizon: float, dl: float) -> void:
	var cell_px: float = float(WorldRenderer.CELL)
	var half := Vector2(cell_px, cell_px) * 0.5
	var clear_r: float = cell_px * 3.25       # the chevron's own lift over the cell it points at
	var marks := PackedVector2Array()
	for t: Dictionary in r._guide_targets:
		marks.append(Vector2(t["cell"] as Vector2i) * cell_px + half - Vector2(0.0, clear_r))
	if r._aim_in_reach and (r._ghost_def != null or r._ghost_material != &""):
		marks.append(Vector2(r._aim) * cell_px + half)
	var star_a: float = (1.0 - dl) * 0.9
	for i: int in 42:
		# `i * 2654435761` is a linear sequence rather than a hash. Across these 42 stars the sorted x
		# values had three distinct gaps (76 / 241 / 317, a three-distance lattice); y had five, all under
		# 24px inside a 380px band; and the radii cycled 0-1-2-0-1-2 with the index. That is a comb of
		# evenly spaced dots with marching sizes, not a sky. One salt per axis keeps position, twinkle,
		# size and tint independent, and x alone goes to 38 distinct gaps.
		var sx: float = view.position.x + fposmod(
			float(Seams.grain(Vector2i(i, 101)) % 4093) + cam.x * 0.04, view.size.x)
		var sy: float = grad_top - 60.0 + float(Seams.grain(Vector2i(i, 202)) % 380)
		if sy > horizon - 90.0:
			continue
		var quiet: float = 1.0
		for m: Vector2 in marks:
			quiet = minf(quiet, smoothstep(0.0, clear_r, Vector2(sx, sy).distance_to(m)))
		if quiet < 0.02:
			continue                          # under a marker there is no alpha left to draw with
		var tw: float = 0.72 + 0.28 * sin(
			r._anim_time * (1.1 + float(Seams.grain(Vector2i(i, 303)) % 13) * 0.13) + float(i))
		var tint: Color = STAR_WARM if Seams.grain(Vector2i(i, 606)) % 5 == 0 else STAR_COLD
		ci.draw_circle(Vector2(sx, sy), 1.1 + float(Seams.grain(Vector2i(i, 404)) % 3) * 0.4,
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


## Draw the Sinkforge crown (see WorldRenderer.SINKFORGE_* constants). A dormant colossal machine on the
## far horizon: a broken cog-ring on a dead pylon + leaning buttresses, with a warm ember at the cog core.
static func _sinkforge(r: WorldRenderer, ci: CanvasItem, view: Rect2, cam: Vector2, horizon: float, dl: float, hor_c: Color) -> void:
	# Skip when the surface horizon isn't in view (deep underground the walls cover the backdrop anyway).
	if view.position.y > horizon + 200.0:
		return
	var f: float = WorldRenderer.SINKFORGE_FACTOR
	var s: float = WorldRenderer.SINKFORGE_SCALE
	var cx: float = cam.x + (WorldRenderer.SINKFORGE_ANCHOR_X - cam.x) * f      # parallaxed screen-world x of the crown
	var base_y: float = horizon + 30.0 + cam.y * (1.0 - f) * 0.30  # base seam just under the horizon
	if cx < view.position.x - 360.0 * s or cx > view.end.x + 360.0 * s:
		return
	# Silhouette: a solid mass, so darker and more present than the ridges, but still hazed by daylight.
	# Its parallax factor sits between the far and mid ranges, and beside ridges carrying real aerial
	# perspective a near-unhazed black stops reading as distance and starts reading as a sticker pasted on
	# the sky. It takes less haze than an equidistant hill would, since it is the landmark and should stay
	# the most present thing on the horizon, but it stands in the same air as everything around it.
	var sil: Color = Color(0.050, 0.058, 0.098).lerp(hor_c, dl * 0.44)
	var pyl_top: float = base_y - 250.0 * s
	# Chains: titanic catenaries hanging from the pylon shoulders, the upper spans read above the hills.
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
	# The broken cog-ring crowning the pylon: the machine motif, ruined, with an arc and teeth missing.
	var ring_c := Vector2(cx, pyl_top - 30.0 * s)
	var rr: float = 78.0 * s
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
	# The ember heart: a faint deep-red glow breathing in the cog hub, so the machine reads as dormant
	# rather than dead. Kept subtle enough to be a buried pulse rather than a second sun.
	var pulse: float = 0.5 + 0.5 * sin(r._anim_time * 0.55)
	for gi: int in 3:
		var gr: float = (13.0 + float(gi) * 15.0) * s
		var ga: float = (0.065 - float(gi) * 0.018) * (0.5 + 0.5 * pulse)
		ci.draw_circle(ring_c, gr, Color(0.85, 0.30, 0.12, ga))
	ci.draw_circle(ring_c, 6.0 * s, Color(1.0, 0.52, 0.26, 0.09 + 0.07 * pulse))
