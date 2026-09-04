class_name OrePainter
extends RefCounted

## THE ORE SEAMS AND THE LODE'S METAL. Ported from `legacy/scenes/world_renderer.gd:1028-1241`, the S4
## seam: `_exposed_ore_cells`, `_cluster_seams`, `_crystal_seams_cached`, `_seam_glow_color`, the seam
## glow and pips of `_paint_lights`, and `_draw_lode`'s draining prefix. A' step 6l (D0374).
##
## Two passes in one file because both are "what ore does that the wall bake cannot": the ADDITIVE pass
## (`paint_frame`, on the light canvas) clusters exposed ore into a few cohesive seams and glows each one
## in its own mineral colour, gated by depth as the glint is; the MIX pass (`paint_lode`, over the wall
## bake) draws the metal left in an opened lode and lets it thin as the lode drains.
##
## LEGACY'S TWO RULES, KEPT. Coloured light "reads as a feature when it is big and cohesive and as
## confetti when it is scattered dots", so the glow is per SEAM, never per cell; and "the accent is
## deliberately tight and dim. A wide soft radial halo of any colour impersonates a light source" -- the
## glow radius is 0.42 of the seam's and its intensity a tenth of a lamp's.
##
## THE POPULATION IS THE GLINT'S. Legacy's `_exposed_ore_cells` and `_draw_glint_flares` test the same
## four things (solid, nuggets, glitters, an open neighbour); `GlintPainter.can_glint` already is that
## predicate and `glint_cells` already caches it, so this asks the glint painter rather than restating it.
##
## THE LINK IS IN METRES. Legacy joins cells within 3 of ITS cells, which are a metre each; ours are a
## quarter of one, so the same 3 m is 12 cells here. The noise floor moved with the quantum: legacy dropped
## a seam under two of its cells; here one metre of face (four cells) is the floor. The radius formula is
## legacy's in metres and is CAPPED, which legacy's own note asked for: "nothing bounds it ... a drift
## gallery run along a vein reaches 16" cells, past every cull margin. The cap is the torch's reach.
##
## THE LODE'S METAL IS A LIVE PASS OVER A BAKED MATRIX -- legacy's own split ("the matrix is baked into
## the wall plane; what is left for the live pass is the metal in it, and how much of it is left"). The
## bake cannot see a lode drain: `WorldView` rebakes chunks on `mining_broke_cells`, and a rig chewing a
## vein breaks no cell. So `WallPainter` paints a lode cell's socket and this draws its speck on top,
## per frame, only while the cell's stable rank is under the lode's remaining per mille: flecks vanish one
## by one as the vein is worked and never reshuffle, and a half-worked vein looks like the same vein, half
## worked.

const CRYSTAL_COLOR := Color(0.34, 0.86, 1.0)   ## the fallback: a seam of a material without nuggets
const SEAM_LIGHT := Color(0.46, 0.86, 1.0)      ## legacy: "exposed-ore seams answer in cold cyan"
const LINK_M: float = 3.0
const LINK_CELLS: int = int(LINK_M) * MaterialLook.CELLS_PER_METRE
## Any value >= LINK_CELLS works; at a bucket per 4 m a frontier pop searches at most three per axis.
const BUCKET_CELLS: int = LINK_CELLS + MaterialLook.CELLS_PER_METRE
const MIN_CELLS: int = MaterialLook.CELLS_PER_METRE   ## one metre of face; under it a seam is noise
const MAX_SEAMS: int = 6
const RADIUS_BASE_M: float = 2.2
const RADIUS_PER_EXTENT: float = 0.55
const RADIUS_MAX_M: float = 7.6                       ## legacy TORCH_GLOW_R, the widest pool it culls for
const GLOW_R_FRAC: float = 0.42
const GLOW_BASE: float = 0.11
const GLOW_BREATH: float = 0.07
const SATURATE: float = 0.20                          ## emitted light is a purer hue than the fleck
const PIP_PICK: int = 4                               ## one pip per this many face cells (a legacy cell)
const PIP_MIN_PX: float = 0.9
const SCALE: float = 0.5                              ## legacy px to ours, WG-4
const CELL: float = float(Interface.Observation.CELL_PX)

var _glint: GlintPainter
var _seams: Array[Dictionary] = []
var _cached_rect: Rect2i = Rect2i()
var _cached_hash: int = 0
var _has_cache: bool = false


func _init(glint: GlintPainter = null) -> void:
	_glint = glint if glint != null else GlintPainter.new()


## Cluster exposed-ore cells into cohesive seams: greedy flood over a spatial hash, in sorted order, so the
## same cells always make the same seams. Returns [{pos (cells, Vector2), radius (cells), cells}].
## Legacy's own shape, including the re-sort of each pop's candidates that reproduces the linear scan's
## absorption order: "without the sort this is still a correct clustering and a different picture".
## `tests/test_ore_painter.gd` holds it byte-identical to the obvious quadratic flood.
static func cluster(from_cells: Array[Vector2i]) -> Array[Dictionary]:
	var cells: Array[Vector2i] = from_cells.duplicate()
	cells.sort()
	var buckets: Dictionary = {}
	for c: Vector2i in cells:
		var key: Vector2i = _bucket(c)
		if not buckets.has(key):
			buckets[key] = ([] as Array[Vector2i])
		(buckets[key] as Array[Vector2i]).append(c)
	var seams: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for start: Vector2i in cells:
		if claimed.has(start):
			continue
		var group: Array[Vector2i] = [start]
		claimed[start] = true
		var i: int = 0
		while i < group.size():
			var g: Vector2i = group[i]
			i += 1
			var near: Array[Vector2i] = _near(buckets, claimed, g)
			near.sort()
			for other: Vector2i in near:
				if claimed.has(other):
					continue
				claimed[other] = true
				group.append(other)
		if group.size() < MIN_CELLS:
			continue
		seams.append(seam_of(group))
		if seams.size() >= MAX_SEAMS:
			break
	return seams


static func _bucket(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / float(BUCKET_CELLS)), floori(float(c.y) / float(BUCKET_CELLS)))


## The unclaimed cells within LINK_CELLS (chebyshev) of `g`, from the buckets its reach can touch.
static func _near(buckets: Dictionary, claimed: Dictionary, g: Vector2i) -> Array[Vector2i]:
	var near: Array[Vector2i] = []
	var b0: Vector2i = _bucket(g - Vector2i(LINK_CELLS, LINK_CELLS))
	var b1: Vector2i = _bucket(g + Vector2i(LINK_CELLS, LINK_CELLS))
	for by: int in range(b0.y, b1.y + 1):
		for bx: int in range(b0.x, b1.x + 1):
			var key := Vector2i(bx, by)
			if not buckets.has(key):
				continue
			for other: Vector2i in (buckets[key] as Array[Vector2i]):
				if claimed.has(other):
					continue
				if absi(other.x - g.x) <= LINK_CELLS and absi(other.y - g.y) <= LINK_CELLS:
					near.append(other)
	return near


## One seam from its member cells: the centroid, and a radius that grows with the diagonal span, capped.
static func seam_of(group: Array[Vector2i]) -> Dictionary:
	var sum := Vector2.ZERO
	var lo := Vector2(group[0])
	var hi := Vector2(group[0])
	for gc: Vector2i in group:
		sum += Vector2(gc)
		lo = lo.min(Vector2(gc))
		hi = hi.max(Vector2(gc))
	var per_m: float = float(MaterialLook.CELLS_PER_METRE)
	var extent_m: float = (hi - lo).length() / per_m
	var radius_m: float = minf(RADIUS_BASE_M + RADIUS_PER_EXTENT * extent_m, RADIUS_MAX_M)
	return {"pos": sum / float(group.size()) + Vector2(0.5, 0.5), "radius": radius_m * per_m, "cells": group}


## The seams for this observation, from the cache when nothing that feeds them has changed. Keyed as the
## glint's population is (window + materials hash): which cells are exposed ore is a pure function of
## those two, and legacy refloods only on a dig near ore or a pan for the same reason.
func seams_for(look: MaterialLook, obs: Interface.Observation) -> Array[Dictionary]:
	var h: int = hash(obs.materials)
	if _has_cache and _cached_rect == obs.window and _cached_hash == h:
		return _seams
	_seams = cluster(_glint.glint_cells(look, obs))
	_cached_rect = obs.window
	_cached_hash = h
	_has_cache = true
	return _seams


## The glow for a seam, from its own material: the first cell's nugget colour pushed toward saturation,
## "so ore glows warm orange, rich_ore gold and iron cold steel, and the light agrees with the flecks in
## the rock" rather than a cyan sticker on orange ore. A material without nuggets falls back to cyan.
static func glow_color(look: MaterialLook, obs: Interface.Observation, cells: Array) -> Color:
	if cells.is_empty() or look == null or obs == null:
		return CRYSTAL_COLOR
	var rec: Dictionary = MaterialsRecords.RECORDS.get(obs.material_at(cells[0]), {})
	if not rec.has("nugget_color"):
		return CRYSTAL_COLOR
	var nug: Color = record_color(rec["nugget_color"])
	return Color.from_hsv(nug.h, minf(1.0, nug.s + SATURATE), maxf(nug.v, 0.85))


## A record's `[r, g, b]` list as a colour.
static func record_color(v: Variant) -> Color:
	var a: Array = v
	return Color(float(a[0]), float(a[1]), float(a[2]))


## Legacy's breath, with its phase in metres rather than in its pixels.
static func breath(t: float, x_cells: float) -> float:
	return 0.55 + 0.45 * sin(t * 1.4 + x_cells / float(MaterialLook.CELLS_PER_METRE) * 0.64)


## How dark the seam sits: legacy's `seam_dark`, the same substitution the glint made (depth for skylight).
## "A vein in daylight reads as pure rock, since a glow of any strength there impersonates a lamp."
static func seam_dark(look: MaterialLook, row: int) -> float:
	return GlintPainter.depth_gate(look, row)


## Whether a lode cell's speck is still there at `permille` remaining. A stable per-cell rank against the
## fraction: monotone, so a fleck gone at 700 stays gone at 600, and a full lode shows every fleck.
static func lode_shows(c: Vector2i, permille: int) -> bool:
	return Seams.grain(c) % 1000 < permille


## THE ADDITIVE PASS: one tight glow per seam plus bright pips on a quarter of its face cells, both gated
## by depth. Mounted on the light canvas (`tests/body/reveal_view_setup.gd`), so it adds over the veil.
func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var o: Interface.Observation = frame.obs
	var t: float = frame.anim_time
	for seam: Dictionary in seams_for(frame.look, o):
		var pos: Vector2 = seam["pos"]
		var dark: float = seam_dark(frame.look, int(pos.y))
		if dark <= 0.02:
			continue
		var br: float = breath(t, pos.x)
		var glow: Color = glow_color(frame.look, o, seam["cells"])
		LightPainter.draw_glow(ci, pos * CELL, float(seam["radius"]) * CELL * GLOW_R_FRAC, glow, (GLOW_BASE + GLOW_BREATH * br) * dark)
		var pip: Color = glow.lightened(0.5)
		for c: Vector2i in seam["cells"]:
			if Seams.grain(c) % PIP_PICK != 0:
				continue
			var cb: float = 0.55 + 0.45 * sin(t * 1.4 + float(c.x) * 0.6 + float(c.y) * 0.4)
			ci.draw_circle((Vector2(c) + Vector2(0.5, 0.5)) * CELL, maxf((1.4 + 0.6 * cb) * SCALE, PIP_MIN_PX),
				Color(pip.r, pip.g, pip.b, (0.55 + 0.30 * cb) * dark))


## THE MIX PASS: the metal left in every opened lode in view, over the wall bake's socket. Static, because
## it keeps nothing: the lode plane on the observation is already sparse.
static func paint_lode(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var o: Interface.Observation = frame.obs
	var cell_px: int = o.cell_px
	var r: Rect2i = TerrainPainter.visit_rect(o, frame.view_world_rect, cell_px)
	for c: Vector2i in Ordering.cells(o.lodes):
		if not r.has_point(c) or o.solid_at(c):
			continue
		var mat: StringName = (o.lodes[c] as Dictionary).get("material", &"")
		if not frame.look.is_speck(mat, c.x, c.y) or not lode_shows(c, o.lode_permille(c)):
			continue
		ci.draw_rect(Rect2(c.x * cell_px, c.y * cell_px, cell_px, cell_px), frame.look.speck_color(mat, c.x, c.y), true)
