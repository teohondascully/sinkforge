class_name BakeData
extends RefCounted

## THE SHADER'S INPUT: one texel a cell, built per paint rect from the observation's own bytes (D0528,
## T040's evidence). The CPU tone (`TerrainPainter.cell_fill` -> `MaterialLook.cell_color` ->
## `RockTone.shade` -> `SurfaceTone.shade`) costs 18-25 us a solid cell because every cell probes its
## neighbours through a `Callable`; this writes the same facts as bytes and `rock_tone.gdshader` reads
## them. Behind `BakeChunk.shader_tone()`, OFF by default: the shipped picture is the CPU painter's.
##
## THE FOUR CHANNELS, per cell:
##   R  the material's index in `MaterialsRecords.RECORDS` order (1..N; 0 is air; N + 1 the `unknown`
##      slot, a solid legend entry no record knows, which `MaterialLook.matrix_color` paints as its debug
##      brown). The palette texture (`palette()`) is indexed by it: row 0 the base colour with
##      `depth_darken` in alpha, row 1 the nugget colour with "has a nugget" in alpha, row 2 the cap.
##   G  bits 0-1 the grammar (`RockTone.GRAM_*`); bit 2 the speck (`MaterialLook.is_speck`), bit 3 the lit
##      facet. THE SPECK IS DECIDED HERE, NOT IN THE SHADER: `MaterialLook._hash01` is 64-bit integer
##      arithmetic and GLSL has 32-bit ints, so the shader could not reproduce it -- the CPU decides, the
##      shader only colours. That is also why this file CALLS `MaterialLook._hash01` for the facet rather
##      than copying its three multipliers: a second copy of a hash is how two renderers come to disagree
##      about which cells glint, and `material_look.gd` is the reference this ticket may not move.
##   B  the Manhattan distance to the nearest open cell, clamped to `DIST_MAX` = FORM_REACH + 1. Every
##      neighbour term the CPU tone has is dead past its own reach -- `_air_weight` needs air within L1 2
##      (a diagonal), the rim within 2 rows, the moss within 3, `_sky_form` within 6 -- so a cell at
##      DIST_MAX skips all of them and the shader only probes R around a cell when B says one may be live.
##   A  the soil-depth code: 0 for a column with no walked surface (`SurfaceTone.column_surface_row` is
##      NONE) and for any row at or above the surface, else `row - surface_row + 1` clamped to `A_BEYOND`
##      -- so 1 IS THE SURFACE ROW (the cap), 2 the row under it, and the shader's soil depth is
##      `code - 2`. Bit 7 flags a ROOT column (`SurfaceTone.root_here`, `Seams.grain`, 64-bit again).
##
## THE MARGIN IS THE CLAMP: the image covers the paint rect grown by `MARGIN` = DIST_MAX cells, so a rect
## cell whose nearest air is within reach sees it inside the image, and the shader's farthest neighbour
## fetch (FORM_REACH rows) lands inside it too. The observation is always wider than that --
## `WorldView.WINDOW_MARGIN_CELLS` is 9 against this 7 -- so no rect cell's probe reads an unseen cell.
## A MARGIN cell's own B may read long, because its own neighbours past the image are not looked at; the
## shader never reads a margin cell's B, only its R.

const DIST_MAX: int = RockTone.FORM_REACH + 1
const MARGIN: int = DIST_MAX
const A_NONE: int = 0
const A_SURFACE: int = 1
## Past the soil profile: `SurfaceTone.soil` returns its input at depth >= SOIL_ROWS, and depth is code - 2.
const A_BEYOND: int = SurfaceTone.SOIL_ROWS + 2
const A_ROOT_BIT: int = 0x80
const G_GRAM_MASK: int = 0x03
const G_SPECK_BIT: int = 0x04
const G_FACET_BIT: int = 0x08
## `MaterialLook.speck_color`'s facet draw, beside its salt. The CPU's own line stays the reference.
const FACET_SALT: int = 3391
const FACET_SHARE: float = 0.34
const PALETTE_ROWS: int = 3
## A distance no cell can hold, for the chamfer's "not yet reached".
const FAR: int = 1 << 20

## Material id -> its palette index (1..N), in record order; `_unknown` is the N + 1 slot.
var _index: Dictionary = {}
var _unknown: int = 0
var _palette: ImageTexture = null
## The last build's span (the image's cells: the paint rect grown by MARGIN), for the caller and a suite.
var span: Rect2i = Rect2i()


## Indexes the materials in record order and bakes the palette.
func setup() -> void:
	_index.clear()
	var ids: PackedStringArray = PackedStringArray([""])
	for id: String in MaterialsRecords.RECORDS:
		_index[StringName(id)] = ids.size()
		ids.append(id)
	_unknown = ids.size()
	var img: Image = Image.create_empty(_unknown + 1, PALETTE_ROWS, false, Image.FORMAT_RGBAF)
	for i: int in range(1, _unknown):
		var rec: Dictionary = MaterialsRecords.RECORDS[ids[i]]
		var base: Color = OrePainter.record_color(rec["base_color"])
		base.a = float(rec.get("depth_darken", 0.0))
		img.set_pixel(i, 0, base)
		var nug: Color = Color(0.0, 0.0, 0.0, 0.0)
		if rec.has("nugget_color"):
			nug = OrePainter.record_color(rec["nugget_color"])
			nug.a = 1.0
		img.set_pixel(i, 1, nug)
		img.set_pixel(i, 2, SurfaceTone.cap_color(StringName(ids[i])))
	_palette = ImageTexture.create_from_image(img)


## The palette texture the shader indexes by R; null before `setup`.
func palette() -> ImageTexture:
	return _palette


## The `unknown` slot's index. The shader takes it as a uniform and returns the debug brown FLAT there,
## because `MaterialLook.matrix_color` returns it before it tones anything -- without the uniform the
## shader would tone a colour the CPU leaves alone. No shipped legend entry lands here today (all nine
## `data/materials` records carry `base_color`); it exists so an unmapped one cannot read as air.
func unknown_index() -> int:
	return _unknown


## The palette index of a material id: 0 for air, N + 1 for a solid id no record knows.
func index_of(material: StringName) -> int:
	if material == &"":
		return 0
	return int(_index.get(material, _unknown))


## The world seed as the shader's `int` uniform can carry it: the low 32 bits, as a signed value, so
## `uint(world_seed)` in GLSL recovers the same bit pattern `BedSequence._unit` masks to. Its hashes are
## `& 0xFFFFFFFF` at every step and the low 32 bits of a product depend only on the low 32 bits of its
## factors, so this truncation costs the port nothing.
static func seed32(world_seed: int) -> int:
	var low: int = world_seed & 0xFFFFFFFF
	return low - 0x100000000 if low >= 0x80000000 else low


## Builds the image for `cells` (the cells the quad will cover): `cells` grown by MARGIN, one RGBA8 texel
## a cell, filled from `obs.materials` by byte -- never through `material_at`, whose per-call cost is part
## of what the CPU tone pays. Null when the observation cannot pose it.
func build(obs: Interface.Observation, cells: Rect2i, look: MaterialLook) -> Image:
	if obs == null or look == null or cells.size.x <= 0 or cells.size.y <= 0 or obs.legend.is_empty():
		return null
	span = cells.grow(MARGIN)
	var w: int = span.size.x
	var h: int = span.size.y
	var solid: PackedByteArray = solid_bytes(obs, span)
	var dist: PackedInt32Array = distance_to_air(solid, w, h)
	var legend: Array = _legend_table(obs, look)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w * h * 4)
	for x: int in w:
		_fill_column(obs, look, solid, dist, legend, bytes, x)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


## Per LEGEND ENTRY, once a build: the palette index, the grammar, the id and whether it can carry a
## speck. The per-cell loop then touches no string and no record. Returned as `[idx, gram, nug, names]`.
func _legend_table(obs: Interface.Observation, look: MaterialLook) -> Array:
	var n: int = obs.legend.size()
	var idx: PackedInt32Array = PackedInt32Array()
	var gram: PackedInt32Array = PackedInt32Array()
	var nug: PackedByteArray = PackedByteArray()
	var names: Array[StringName] = []
	idx.resize(n)
	gram.resize(n)
	nug.resize(n)
	for b: int in n:
		var id: StringName = StringName(obs.legend[b])
		names.append(id)
		idx[b] = index_of(id) if b > 0 else 0
		gram[b] = look.grammar_of(id) if b > 0 else 0
		nug[b] = 1 if b > 0 and MaterialsRecords.RECORDS.get(String(id), {}).has("nugget_color") else 0
	return [idx, gram, nug, names]


## One column of the image. The column's walked surface and its root bit are read ONCE here, exactly as
## `TerrainPainter.paint` reads them once a column (6o, D0378), and the A code is then `base + y` floored
## at NONE and capped at BEYOND -- `code = row - srow + 1`, so `base = span.y - srow + 1`.
func _fill_column(obs: Interface.Observation, look: MaterialLook, solid: PackedByteArray,
		dist: PackedInt32Array, legend: Array, bytes: PackedByteArray, x: int) -> void:
	var idx: PackedInt32Array = legend[0]
	var gram: PackedInt32Array = legend[1]
	var nug: PackedByteArray = legend[2]
	var names: Array = legend[3]
	var w: int = span.size.x
	var col: int = span.position.x + x
	var srow: int = SurfaceTone.column_surface_row(obs, col)
	var root: int = A_ROOT_BIT if SurfaceTone.root_here(col) else 0
	var base: int = span.position.y - srow + 1
	for y: int in span.size.y:
		var o: int = y * w + x
		var b: int = solid[o]
		if b == 0:
			continue
		var g: int = gram[b]
		if nug[b] != 0:
			var row: int = span.position.y + y
			if look.is_speck(names[b], col, row):
				g |= G_SPECK_BIT
				if MaterialLook._hash01(col, row, FACET_SALT) < FACET_SHARE:
					g |= G_FACET_BIT
		var o4: int = o * 4
		bytes[o4] = idx[b]
		bytes[o4 + 1] = g
		bytes[o4 + 2] = mini(dist[o], DIST_MAX)
		bytes[o4 + 3] = (mini(maxi(base + y, A_NONE), A_BEYOND) if srow != SurfaceTone.NONE else A_NONE) | root


## The observation's legend byte at every cell of `span_cells`, 0 outside the window -- open air, which is
## what `Observation.material_at` answers there and what `RockTone`'s probes are told to assume. The one
## read of `obs.materials`, row by row. Public so a suite can pose a byte grid beside a built image.
static func solid_bytes(obs: Interface.Observation, span_cells: Rect2i) -> PackedByteArray:
	var w: int = span_cells.size.x
	var out: PackedByteArray = PackedByteArray()
	out.resize(w * span_cells.size.y)
	var win: Rect2i = obs.window
	var y0: int = maxi(span_cells.position.y, win.position.y)
	var y1: int = mini(span_cells.end.y, win.end.y)
	var x0: int = maxi(span_cells.position.x, win.position.x)
	var x1: int = mini(span_cells.end.x, win.end.x)
	for row: int in range(y0, y1):
		var src: int = (row - win.position.y) * win.size.x - win.position.x
		var dst: int = (row - span_cells.position.y) * w - span_cells.position.x
		for col: int in range(x0, x1):
			out[dst + col] = obs.materials[src + col]
	return out


## THE DISTANCE TO AIR, exact in the Manhattan metric by a two-pass chamfer: forward (up, left) then
## backward (down, right), unit steps. Air is 0; solid starts FAR; a cell beyond the image is UNSEEN (not
## a source), so a margin cell may read long -- the header says why that is safe. A span with no air in it
## at all (deep ground, the streaming case) is FAR everywhere and skips both passes. Static and public so
## a suite can drive it on a posed byte grid against a brute-force control.
static func distance_to_air(solid: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var n: int = w * h
	var d: PackedInt32Array = PackedInt32Array()
	d.resize(n)
	if solid.count(0) == 0:
		d.fill(FAR)
		return d
	for o: int in n:
		d[o] = 0 if solid[o] == 0 else FAR
	for y: int in h:
		var ro: int = y * w
		for x: int in w:
			var o: int = ro + x
			var v: int = d[o]
			if v == 0:
				continue
			if y > 0 and d[o - w] + 1 < v:
				v = d[o - w] + 1
			if x > 0 and d[o - 1] + 1 < v:
				v = d[o - 1] + 1
			d[o] = v
	for y: int in range(h - 1, -1, -1):
		var ro: int = y * w
		for x: int in range(w - 1, -1, -1):
			var o: int = ro + x
			var v: int = d[o]
			if v == 0:
				continue
			if y < h - 1 and d[o + w] + 1 < v:
				v = d[o + w] + 1
			if x < w - 1 and d[o + 1] + 1 < v:
				v = d[o + 1] + 1
			d[o] = v
	return d


## The soil depth the shader derives from an A byte: -1 on the surface row (the cap), 0 under it, and
## `SurfaceTone.SOIL_ROWS` for BEYOND, which is where `SurfaceTone.soil` stops. -2 for NONE, which is off
## the profile at the other end. Public so a suite can assert the encoding round-trips.
static func depth_of_a(a: int) -> int:
	return (a & 0x7f) - 2
