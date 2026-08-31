class_name MaterialLook
extends RefCounted

## Slice 0's palette adapter: `data/materials` + `data/bands` records -> one Color per terrain cell.
## `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` §9, `docs/DECISIONS_LEDGER.md` D0189.
##
## WHERE THIS LIVES. Appearance is a view concern. It spent Slices 0-2 in `tests/body/` beside the one
## scene that used it, under a header that called that "a seam to formalise, not a home" and said it
## would move to `view/` behind the real coordinator at Slice 3. **This is that move** (D0240): it is
## `view/visuals/material_look.gd` now, and `Frame.look` is the seam it was waiting for.
##
## It had to move rather than merely being referenced from `view/`, and the reason is worth keeping:
## `class_name` is path-independent, so a `view/` file could have gone on using `MaterialLook` from
## `tests/` forever -- and `tools/layer_lint/layer_lint.py` would never have said a word, because its
## `UNPOLICED` set contains `tests` and its class map is built "from the policed tree only". A shipped
## renderer depending on a test file is a real defect the layer gate is structurally blind to.
##
## It touches nothing in `sim/` or `core/`. It DOES read `data/` (`BandsRecords`, `MaterialsRecords`),
## which `view/README.md`'s dependency line does not currently grant -- see that file's note.
##
## WHAT IT DOES NOT DO, which matters more than what it does. Legacy paints a cell in TWO passes: a
## coarse `terrain_painter.gd` pass (chamfers, fillets, edge AO, a 3-polygon faceted nugget crystal, a
## fissure line) and a fine `fine_terrain.gd` bake (11 noise fields, per-fine-cell grain, seams, rim
## light, form shading). Neither is ported here. Slice 0 draws ONE `draw_rect` per cell, exactly as the
## debug scene already did, and only changes the colour that rect is filled with.
##
## That is not a shortcut -- it is what the grid can actually carry. Legacy authored for a 32px logic
## cell subdivided into 8px fine cells; this world is 16px subdivided into 4px. Legacy's nugget quad is
## 6.4px tall, so **legacy's smallest sub-cell mark is larger than this world's entire terrain cell.**
## Its per-cell interior detail has nowhere to go but into the cell colour itself, which is what
## `_speck_lift` below does with the nugget: legacy scattered N crystals inside one cell, and here a
## deterministic fraction of CELLS carry the nugget colour instead. Same statistical read, one grid
## finer. The measured basis for that claim is in D0189.

const CELLS_PER_METRE: int = 4  ## ShaftGenerator.TERRAIN_CELLS_PER_METER -- 4px cells, 16px/m.

## Legacy's own `_cell_base_color` normalises depth by `FactorySim.GRID_ROWS` (128 rows == 128 m) before
## applying `depth_darken`. Kept as metres so it survives the grid change; this world runs to 256 m, so
## a cell at 128 m darkens exactly as legacy's bottom row did, and everything below sits at the clamp.
const DEPTH_DARKEN_FULL_M: float = 128.0

## Nugget-bearing materials: the fraction of cells that carry the nugget colour rather than the host.
## Derived, not picked -- see `_speck_lift`. Legacy's `nugget_count` is crystals per 32px cell; one 32px
## cell is 64 of this world's 4px cells, so `count / 64` is the same areal density one grid finer.
const LEGACY_CELL_SUBCELLS: float = 64.0

var _bands: Array[Dictionary] = []  ## sorted shallow -> deep by `from_m`


func _init() -> void:
	# Codegen keys RECORDS by id and emits in FILENAME order, which is alphabetical and not depth order
	# ("open_sky" before "shale_reach" before "stonereach"...). Sorting by `from_m` here is what makes the
	# ladder a ladder; reading RECORDS in its natural order would silently interleave the bands.
	for id: String in BandsRecords.RECORDS:
		_bands.append(BandsRecords.RECORDS[id])
	_bands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["from_m"]) < int(b["from_m"]))


## The band a terrain row is in. Mirrors legacy `Strata.band_at`: a row belongs to the LAST band whose
## `from_m` it has reached, so the first band catches everything above and the last catches everything
## below -- which matters here, because legacy's ladder stops at 66 m and this world runs to 256 m.
func band_at(row: int) -> Dictionary:
	var out: Dictionary = _bands[0]
	for band: Dictionary in _bands:
		if depth_m(row) >= int(band["from_m"]):
			out = band
	return out


## Metres below the surface datum. Negative above it, deliberately, exactly as legacy: "standing on a
## hilltop reads as a negative depth rather than a clamped zero, so the number is never fudged."
static func depth_m(row: int) -> int:
	return int(floor(float(row) / float(CELLS_PER_METRE)))


## The fill colour for one solid terrain cell. Deterministic in (material, col, row) and free of any
## RNG, so two runs of the same seed paint identically -- this is a debug scene, not the sim, but a
## renderer whose output moves between runs cannot be screenshot-compared, which Slice 0's whole
## deliverable depends on.
func cell_color(material: StringName, col: int, row: int) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if rec.is_empty() or not rec.has("base_color"):
		return Color(0.42, 0.34, 0.24)  # the pre-Slice-0 debug brown: an unmapped material stays visible
	var base: Color = _to_color(rec["base_color"])
	base = _depth_darkened(base, rec, row)
	base = _speck_lift(base, rec, col, row)
	if bool(rec.get("grain", false)):
		base = _grained(base, col, row)
	return base


## Legacy `_cell_base_color`: `base.darkened(depth_frac * depth_darken)`, linear, clamped at 1.0.
##
## Reproduced faithfully AND reported as near-inert, which is a finding rather than a caveat. Legacy's
## own comment measures that `depth_darken` is outweighed by the zone tints applied after it -- authored
## luma from row 24 to row 88 RISES in every material spanning bands (coal +39.8, deepslate +33.7), and
## deleting `depth_darken` makes those slopes STEEPER, not flatter. What actually darkens legacy's deep
## is the shadow veil, a separate multiply layer that never touches these bytes and is not in Slice 0.
## So: this line is correct, and it is not what makes the deep look deep. Do not tune it expecting that.
func _depth_darkened(base: Color, rec: Dictionary, row: int) -> Color:
	var frac: float = clampf(float(depth_m(row)) / DEPTH_DARKEN_FULL_M, 0.0, 1.0)
	return base.darkened(frac * float(rec.get("depth_darken", 0.0)))


## The nugget, re-expressed at this grid. Legacy scatters `nugget_count` faceted crystals INSIDE a 32px
## cell; at 4px a crystal is bigger than a cell, so the scatter moves up one level: a deterministic
## fraction of cells take the nugget colour outright. `count / 64` preserves areal density exactly,
## because one 32px legacy cell covers 64 of these.
func _speck_lift(base: Color, rec: Dictionary, col: int, row: int) -> Color:
	if not rec.has("nugget_color"):
		return base
	var density: float = float(int(rec.get("nugget_count", 0))) / LEGACY_CELL_SUBCELLS
	if _hash01(col, row, 7717) >= density:
		return base
	# Legacy draws socket / body / facet as three polygons; at one cell there is room for one value, so
	# the cell takes the crystal body and a hash decides whether it is the lit facet or the seated socket.
	var nug: Color = _to_color(rec["nugget_color"])
	return nug.lightened(0.22) if _hash01(col, row, 3391) < 0.34 else nug.darkened(0.18)


## Legacy's `grain` is a BOOLEAN gate, not an amount (material_def.gd:19), enabling a per-cell speckle
## pass. Here it gates a small deterministic value jitter -- the cheapest possible stand-in for the
## thing that stops rock reading as a flat fill, and at 4px the only one the grid can express. The
## +/-0.06 range is legacy's own `_cell_jitter` amplitude (3 sines / 3 * 0.06), carried over rather
## than picked; the depth boost legacy multiplies onto it is NOT carried, because that boost exists to
## survive the shadow veil, which Slice 0 does not have.
func _grained(base: Color, col: int, row: int) -> Color:
	var j: float = (_hash01(col, row, 5501) - 0.5) * 0.12
	return base.lightened(j) if j > 0.0 else base.darkened(-j)


func _to_color(v: Variant) -> Color:
	var a: Array = v
	return Color(float(a[0]), float(a[1]), float(a[2]))


## An integer hash in [0,1). Three odd multipliers then a final mix, rather than `i * BIG_CONST`, which
## is a lattice and lands on a handful of distinct values (`docs/DECISIONS_LEDGER.md`'s own
## linear-sequence-as-hash finding). `salt` separates the three independent draws above so the nugget
## mask, the facet pick and the grain do not correlate into visible banding.
static func _hash01(col: int, row: int, salt: int) -> float:
	var h: int = (col * 73856093) ^ (row * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h) % 65536) / 65536.0
