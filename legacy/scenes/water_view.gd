class_name WaterView
extends RefCounted

## HOW WATER LOOKS: its surface line, its depth shading, its ripples and caustics, the meniscus where it
## meets rock, the drips it sheds, and the packed-cell and fill tells that say a cell is holding some.
##
## Extracted from `world_renderer.gd` along a seam that was measured first. Of the four candidates
## compared, water has the smallest footprint of all and ties for the cleanest boundary:
##
##     candidate        lines   outbound   inbound   vars read   consts   written BOTH sides
##     lighting/veil      639          8         5          23       35                    2
##     machines           460          1         4          11       17                    0
##     water              214          1         3           3       19                    0
##     terrain bake       223          1         9          12       12                    1
##
## Seventeen of those nineteen constants are the `WATER_*` family and nothing else reads them, so they
## came with the block. What actually crosses the line is three renderer fields, one function
## (`_view_world_rect`, a view query), and two constants: `CELL`, which is read by 156 sites in the parent
## and 55 elsewhere, and `WATER_DEEP`, which one other file names.
##
## THE POINT OF EXTRACTING SOMETHING THIS SMALL is not the 214 lines. It is that the water look is now a
## thing with a name and a boundary you can read in one screen, instead of six functions interleaved with
## terrain and machinery in a file of four thousand. The constants moving with it matter more than the
## functions: a `WATER_CAUSTIC_SPEED2` sitting among a hundred unrelated constants is a tuning knob nobody
## can find, and the same value beside the code that reads it is a tuning knob with a home.

var _wv: WorldRenderer


func _init(renderer: WorldRenderer) -> void:
	_wv = renderer


## The render of sim.water. Each watered cell holds an integer level 1..WATER_MAX and draws a translucent
## blue fill whose height is level/WATER_MAX of the cell, anchored at the cell's bottom, so a partially-full
## cell reads a low water line and a settled pool reads a flat surface across its top. Translucent enough
## that the terrain and back wall behind show through. Read each frame, never cached, because water flows
## every tick and the sim is authoritative; this pass never writes it. Drawn in the main world pass, below
## the z 50 veil, so deep water reads dark and daylit water reads bright like all world content. Clipped to
## the camera view, since most water cells are off-screen.
const WATER_COLOR := Color(0.16, 0.42, 0.72)          ## deep cool blue: reads as water, stays see-through


const WATER_ALPHA: float = 0.58                       ## translucent (mid of the 0.5-0.65 window)


const WATER_SURFACE := Color(0.42, 0.72, 0.95)        ## a brighter waterline so the top edge reads


## The surface y (top of the water) a cell would draw for a given integer level, anchored at the cell
## bottom. Higher level means a higher surface and so a smaller y; level 0 is the cell floor.
func _water_surface_y(cell: Vector2i, level: int) -> float:
	var frac: float = clampf(float(level) / float(FactorySim.WATER_MAX), 0.0, 1.0)
	return float(cell.y) * float(WorldRenderer.CELL) + float(WorldRenderer.CELL) * (1.0 - frac)


## Water motion cue, representation only. A pouring water cell, meaning one with open non-solid non-full
## space directly below it, occasionally sheds a cool-blue drip into the particle layer, and where the drop
## lands there is a small splash. Rate-limited so a steady waterfall shimmers with the odd drop rather than
## running as a firehose: each on-screen pouring cell is gated by a per-cell staggered phase so only a
## fraction spawn on any frame, and a hard per-frame cap bounds the total. View-culled, so off-screen water
## costs one has_point() and skips. Never touches the sim: it reads water and solid, and writes only the
## cosmetic `particles` layer.
const WATER_DRIP_PERIOD: float = 0.9                  ## a cell sheds at most one drip per this window


const WATER_DRIP_MAX_PER_FRAME: int = 6               ## hard cap so a wide sheet can't flood the pool


func _spawn_water_drips(delta: float) -> void:
	if _wv.particles == null or _wv.sim.water.is_empty():
		return
	var view: Rect2 = _wv._view_world_rect()
	var cell_f: float = float(WorldRenderer.CELL)
	var spawned: int = 0
	for key: Variant in _wv.sim.water:
		if spawned >= WATER_DRIP_MAX_PER_FRAME:
			break
		var c: Vector2i = key
		var level: int = int(_wv.sim.water[c])
		if level <= 0:
			continue
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		# "Pouring" means the cell below is in-bounds, not solid, and has room for more water, which is the
		# sim's own fall rule. A cell sitting on a full pool or on rock is settled, so no drip.
		var below: Vector2i = c + Vector2i(0, 1)
		if not _wv.sim.in_bounds(below) or _wv.sim.is_solid(below) or _wv.sim.water_at(below) >= FactorySim.WATER_MAX:
			continue
		# Per-cell staggered probabilistic gate: a stable hash phase spreads the cells across the period so
		# they do not all pop on the same frame, and the chance scales with delta so the rate is frame-rate
		# independent, at roughly one drip per WATER_DRIP_PERIOD per pouring cell.
		var h: int = ((int(c.x) * 73856093) ^ (int(c.y) * 19349663)) & 0x7fffffff
		var phase: float = float(h % 997) / 997.0
		if randf() > delta / WATER_DRIP_PERIOD * (0.7 + 0.6 * phase):
			continue
		# The drip is shed at the water's own surface line, mid-cell, and then falls under gravity.
		var surf_y: float = _water_surface_y(c, level)
		_wv.particles.water_drip(Vector2(base.x + cell_f * 0.5, surf_y + 2.0))
		spawned += 1
		# A small splash where the pour lands: scan down the open column to the first blocker, rock or a
		# full-water surface. Only if it is close and on-screen, so this never chases a bottomless shaft or
		# splashes off-view. Half the drips, so it stays subtle.
		if randf() < 0.5:
			var land: Vector2i = below
			var steps: int = 0
			while steps < 8 and _wv.sim.in_bounds(land + Vector2i(0, 1)) \
					and not _wv.sim.is_solid(land + Vector2i(0, 1)) \
					and _wv.sim.water_at(land + Vector2i(0, 1)) < FactorySim.WATER_MAX:
				land += Vector2i(0, 1)
				steps += 1
			var lpos := Vector2(land) * cell_f + Vector2(cell_f * 0.5, cell_f)
			if view.has_point(Vector2(land) * cell_f):
				_wv.particles.water_splash(lpos)


const WATER_DEPTH_CELLS: float = 7.0                  ## cells down over which the gradient runs out


## Deliberately short of opaque. Depth is carried by colour, toward WATER_DEEP, rather than by density,
## because the rock behind a pool is where a body of water gets most of its visible structure: shut it out
## and the interior is a flat field again, just a darker one. At 0.80 the body measured 60% featureless by
## the shared dead-space standard, and the rock showing through is what fixes that, not more caustics.
const WATER_ALPHA_DEEP: float = 0.66                  ## ...and the density it reaches there


const WATER_RIPPLE_AMP: float = 1.5                   ## px the waterline travels


## Authored at 46px and drawn at 105px, knowingly. The waterline is displaced at the two corners of each
## cell, so it is sampled every CELL px exactly as the caustics are, and 46px is under the two-cell floor:
## it advances 0.696 cycles per sample and folds to 0.304, which puts the drawn crests 105px apart.
##
## The second caustic below has the same problem for a different reason. A caustic is a flat fill with no
## sub-cell resolution available at any price. This is vertex geometry, and one extra sample on the top
## edge would put the sampling at 16px and make 46.0 mean what it says, but that touches the surface
## polygon, the bright line and the meniscus, all of which have to agree about where the water is. Raising
## this to 96px instead would make the number honest and the water worse, since a 1.5px swell every 96px
## is close to no ripple at all.
const WATER_RIPPLE_LEN: float = 46.0                  ## px between ripple crests; drawn at 105, see above


const WATER_RIPPLE_SPEED: float = 1.7                 ## crests per second


const WATER_MENISCUS: float = 3.0                     ## px of soft edge hung under the bright line


const WATER_CAUSTIC_LEN: float = 78.0                 ## px between caustic bands


const WATER_CAUSTIC_SPEED: float = 0.55


const WATER_CAUSTIC: float = 0.15                     ## how much a band lifts the fill


## A second set crossing the first the other way. One band pattern is a stripe; two at different scales
## drifting in opposite directions interfere, and interference is what light on moving water looks like.
##
## It is the finer of the two on paper only. Caustics are evaluated once per cell and the fill is flat
## across it, so this is a sampled signal whose shortest representable period is two cells, meaning 64px.
## The authored 29.0 is under that by a factor of two: along y the argument advances 1.103 cycles per
## sample and folds to 0.103, and along x the 0.7 coefficient puts the period at 41.4px, which folds to
## 0.233. The band written as 29px and 41px is drawn at 309px and 141px. Not as noise, because
## undersampling a single sinusoid destroys its frequency and not its structure, but as a coarse moire
## slower and wider than the 78px primary it is meant to detail, crawling the wrong way at a speed
## unrelated to WATER_CAUSTIC_SPEED2.
##
## The primary is legal on the same test: 78px is 0.410 cycles per sample and its 0.6 y coefficient makes
## 130px, both comfortably under the limit. A period this one could be read at is any multiple of CELL of
## two or more, and three samples per cycle rather than the bare two Nyquist allows is the first that
## reads as a band instead of a checker, which puts it at 96px. Moving it would also change how much
## visible texture WATER_CAUSTIC2 lifts, and that is a look decision wanting eyes on moving water rather
## than arithmetic on a constant.
const WATER_CAUSTIC_LEN2: float = 29.0


const WATER_CAUSTIC_SPEED2: float = -0.9


const WATER_CAUSTIC2: float = 0.09


## How far inside the body this cell sits: 0 at the surface, growing downward, capped where the gradient has
## run out anyway, so a deep aquifer costs no more to draw than a puddle.
func _water_depth(c: Vector2i) -> float:
	var d: int = 0
	while d < int(WATER_DEPTH_CELLS):
		if _wv.sim.water_at(c - Vector2i(0, d + 1)) <= 0:
			break
		d += 1
	return float(d) / WATER_DEPTH_CELLS


## What the player built, and whether it holds. Two tells over one pass, because they are two halves of one
## fact (`docs/DRIFT.md` §4):
##
##   packed fill draws as aggregate: a compacted stipple with a hairline seam around the cell. The molded
##     terrain layer blends a one-cell material into its neighbours, which is what makes rock read as rock
##     rather than as tiles, and is wrong for a wall whose whole value is being a different material from
##     the rock beside it. So packing is drawn on top, as construction rather than as strata.
##   loose fill weeps when water leans on it: a bead runs down the dry face and fades, phased per cell so a
##     wall reads as a weeping surface rather than as one blinking light. Without it water appears on the
##     dry side out of nowhere and the player never learns which wall is the leak.
##
## Iterates `fill`, the cells the player built, so the cost is the size of their own construction, culled to
## the view. Pure representation: reads the sim, never writes it.
func _draw_fill_tells() -> void:
	if _wv.sim.fill.is_empty():
		return
	var view: Rect2 = _wv._view_world_rect()
	var cell_f: float = float(WorldRenderer.CELL)
	for key: Variant in _wv.sim.fill:
		var c: Vector2i = key
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		if _wv.sim.fill[c] == FactorySim.FILL_PACKED:
			_draw_packed_cell(base, c, cell_f)
			continue
		if _wv.sim.water.is_empty():
			continue
		for pair: Array in [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)],
				[Vector2i(1, 0), Vector2i(-1, 0)]]:
			var wet: Vector2i = c + (pair[0] as Vector2i)
			var dry: Vector2i = c + (pair[1] as Vector2i)
			if _wv.sim.water_at(wet) < FactorySim.SEEP_PRESSURE or _wv.sim.is_solid(dry):
				continue
			var face := base + Vector2(cell_f, cell_f) * 0.5 + Vector2(pair[1] as Vector2i) * cell_f * 0.44
			# The face goes wet first, a cool sheen down the dry side, which is what is noticeable from across
			# a gallery; the beads then run down it.
			_wv.draw_line(face + Vector2(0.0, -cell_f * 0.46), face + Vector2(0.0, cell_f * 0.46),
				Color(0.55, 0.78, 0.94, 0.26), 3.0)
			for b: int in 2:
				var phase: float = fmod(_wv._anim_time * 0.5 + float(c.x * 7 + c.y * 13) * 0.11
					+ 0.5 * float(b), 1.0)
				var at: Vector2 = face + Vector2(0.0, -cell_f * 0.42) + Vector2(0.0, cell_f * 0.9) * phase
				var fade: float = (1.0 - phase * 0.7)
				_wv.draw_circle(at, 2.3, Color(0.52, 0.76, 0.94, 0.85 * fade))
				_wv.draw_circle(at + Vector2(-0.6, -1.0), 1.1, Color(0.86, 0.95, 1.0, 0.85 * fade))
			break


## One packed cell: a hairline seam that says placed block rather than rock, plus a scatter of crushed
## aggregate inside it. Hashed off the cell so it never crawls, and drawn at low alpha so a packed bulkhead
## reads as a surface rather than as a decal.
func _draw_packed_cell(base: Vector2, c: Vector2i, cell_f: float) -> void:
	_wv.draw_rect(Rect2(base + Vector2(1.0, 1.0), Vector2(cell_f - 2.0, cell_f - 2.0)),
		Color(0.70, 0.76, 0.84, 0.16), false, 1.0)
	var seed: int = c.x * 73856093 ^ c.y * 19349663
	for i: int in 6:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var px: float = float(seed % 1000) / 1000.0
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var py: float = float(seed % 1000) / 1000.0
		_wv.draw_circle(base + Vector2(3.0 + px * (cell_f - 6.0), 3.0 + py * (cell_f - 6.0)), 1.5,
			Color(0.62, 0.66, 0.72, 0.30))


func _draw_water() -> void:
	if _wv.sim.water.is_empty():
		return
	var view: Rect2 = _wv._view_world_rect()
	var cell_f: float = float(WorldRenderer.CELL)
	var t: float = _wv._anim_time
	for key: Variant in _wv.sim.water:
		var c: Vector2i = key
		var level: int = int(_wv.sim.water[c])
		if level <= 0:
			continue
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		# Fill anchored at the bottom, filling upward from the floor. The top edge is smoothed: each side of
		# the surface is the average of this cell's surface y and the horizontal neighbour's surface y, so a
		# level pool draws a near-flat top and a level step tapers into a ramp instead of a hard stair. A side
		# with no water neighbour keeps this cell's own height, so pool edges stay crisp.
		var floor_y: float = base.y + cell_f
		var mid_y: float = _water_surface_y(c, level)
		var left_lvl: int = _wv.sim.water_at(c + Vector2i(-1, 0))
		var right_lvl: int = _wv.sim.water_at(c + Vector2i(1, 0))
		# Left edge = average with the left neighbour's surface (or this cell's own if there's none).
		var left_y: float = mid_y
		if left_lvl > 0:
			left_y = 0.5 * (mid_y + _water_surface_y(c + Vector2i(-1, 0), left_lvl))
		# Right edge = average with the right neighbour's surface (or this cell's own if there's none).
		var right_y: float = mid_y
		if right_lvl > 0:
			right_y = 0.5 * (mid_y + _water_surface_y(c + Vector2i(1, 0), right_lvl))

		var open_above: bool = _wv.sim.water_at(c - Vector2i(0, 1)) <= 0
		# THE WATERLINE IS SAMPLED AT THE CELL MIDPOINT AS WELL AS ITS EDGES, AND WITHOUT THAT THE RIPPLE
		# CONSTANT IS A LIE. The top edge used to carry two vertices per cell, both on cell boundaries, so
		# the drawn line was a polyline through points 32px apart no matter what `WATER_RIPPLE_LEN` said.
		# A 46px crest spacing sampled every 32px is below Nyquist, which needs period >= 2x spacing, and
		# a sinusoid under Nyquist does not turn into noise, it FOLDS to a lower frequency: 32/46 is 0.696
		# cycles per sample, folding to 0.304, so the ripple actually drew crests every 105px. Not a subtle
		# error and not a tuning matter: the water was rippling at better than twice the wavelength anyone
		# wrote down, and no amount of adjusting the constant would have found it, because every value below
		# 64px lands somewhere else on the same fold.
		#
		# One extra sample halves the spacing to 16px and makes 46.0 mean 46. The midpoint takes this cell's
		# OWN surface height, unsmoothed, which is right rather than merely convenient: the edges are averaged
		# with their neighbours precisely so a level step tapers across the boundary, and the midpoint is
		# interior to the cell, so a three-point top edge is a better piecewise-linear fit to the same surface
		# than the straight line it replaces. The base shape improves even where the water is still.
		var mid_top: float = mid_y
		if not open_above:
			# An interior cell is full. Its own level is a bookkeeping number about how much water lives here,
			# not a height: the water above is resting on it, so there is no air in this cell to draw.
			# Honouring the level everywhere terraced a settling body into horizontal slabs with gaps of rock
			# showing between them, which is what a large pool looks like for the several seconds the sim takes
			# to even out, and what an unevenly-fed aquifer looks like permanently.
			left_y = base.y
			right_y = base.y
			mid_top = base.y
		if open_above:
			# Only a cell with nothing above it owns a waterline, and only that line ripples.
			left_y += sin((base.x) / WATER_RIPPLE_LEN * TAU + t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP
			mid_top += sin((base.x + cell_f * 0.5) / WATER_RIPPLE_LEN * TAU
				+ t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP
			right_y += sin((base.x + cell_f) / WATER_RIPPLE_LEN * TAU
				+ t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP

		# Depth tint: toward WATER_DEEP and denser as the body closes over you.
		var depth: float = _water_depth(c)
		var body: Color = WATER_COLOR.lerp(WorldRenderer.WATER_DEEP, depth)
		var alpha: float = lerpf(WATER_ALPHA, WATER_ALPHA_DEEP, depth)
		# ...and slow caustic bands, so the interior is never one dead value.
		var caustic: float = 0.5 + 0.5 * sin((base.x + base.y * 0.6) / WATER_CAUSTIC_LEN * TAU
			- t * WATER_CAUSTIC_SPEED * TAU)
		var caustic2: float = 0.5 + 0.5 * sin((base.x * 0.7 - base.y) / WATER_CAUSTIC_LEN2 * TAU
			- t * WATER_CAUSTIC_SPEED2 * TAU)
		body = body.lightened((caustic * WATER_CAUSTIC + caustic2 * WATER_CAUSTIC2)
			* (1.0 - depth * 0.4))
		var fill := Color(body.r, body.g, body.b, alpha)

		var tl := Vector2(base.x, left_y)
		var tm := Vector2(base.x + cell_f * 0.5, mid_top)
		var tr := Vector2(base.x + cell_f, right_y)
		var br := Vector2(base.x + cell_f, floor_y)
		var bl := Vector2(base.x, floor_y)
		_wv.draw_colored_polygon(PackedVector2Array([tl, tm, tr, br, bl]), fill)

		if not open_above:
			continue
		# The meniscus: a soft band hung under the bright line so the surface has thickness. Without it the
		# waterline is a drawn stroke sitting on a fill; with it, the fill appears to end in a surface.
		var men := Color(WATER_SURFACE.r, WATER_SURFACE.g, WATER_SURFACE.b, 0.22)
		# Both of these hang off the SAME three points as the fill. A band that resampled the surface on its
		# own would drift off the fill it is supposed to cap: a bright line floating above its own water
		# reads as a rendering fault and would look worse than the aliasing this fixes.
		_wv.draw_colored_polygon(PackedVector2Array([
			tl, tm, tr, Vector2(tr.x, right_y + WATER_MENISCUS), Vector2(tm.x, mid_top + WATER_MENISCUS),
			Vector2(tl.x, left_y + WATER_MENISCUS)]), men)
		var line := Color(WATER_SURFACE.r, WATER_SURFACE.g, WATER_SURFACE.b,
			minf(1.0, WATER_ALPHA + 0.22))
		_wv.draw_colored_polygon(PackedVector2Array([
			tl, tm, tr, Vector2(tr.x, right_y + 1.5), Vector2(tm.x, mid_top + 1.5),
			Vector2(tl.x, left_y + 1.5)]), line)
