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
## `speck_color`/`is_speck` below do with the nugget: legacy scattered N crystals inside one cell, and here a
## deterministic fraction of CELLS carry the nugget colour instead. Same statistical read, one grid
## finer. The measured basis for that claim is in D0189.

const CELLS_PER_METRE: int = 4  ## ShaftGenerator.TERRAIN_CELLS_PER_METER -- 4px cells, 16px/m.

## THE SURFACE DATUM, in rows. Mirrors `ShaftGenerator.SKY_ROWS` (P017/D0292), which is the authority:
## `view/` may not name a `sim/` symbol, so this is a copy, and `tests/test_material_palette.gd`
## asserts the two are equal rather than trusting the comment. Same arrangement, and the same reason,
## as `CELLS_PER_METRE` above.
const SURFACE_ROW: int = 80

## Legacy `world_renderer.gd:1506-1512 ZONE_TINTS` and `:1573-1629 _cell_tone/_strata/_cell_jitter`,
## ported in METRES (D0252). Everything below this line arrived together because legacy computes them
## together: `_cell_fill_color = apply_tone(_cell_base_color(...), _cell_tone(...))`.
##
## THE ZONE TINTS ARE NOT `data/bands`, and the near-miss is worth stating because both are
## eight-or-fewer rows of `{depth, colour}` and this file already holds the other one. `data/bands` is
## legacy's `strata.gd:BANDS` -- EIGHT bands carrying the name and colour the HUD *announces* a depth in.
## This is `world_renderer.gd:ZONE_TINTS` -- FOUR terrain tints with their own boundaries and their own
## quieter colours. Three of the four rows prove they are separate tables rather than one table copied:
## the neutral middle starts at 28 m where SHALE REACH starts at 24, and its colour is (0.55,0.58,0.66)
## against that band's (0.58,0.64,0.74). Legacy's own comment says the topsoil has NO entry here --
## "Topsoil keeps its warm material colours, since no entry means no tint" -- while the band ladder
## does carry a TOPSOIL row. Merging them would silently retune the depth readout to match the rock, or
## the rock to match the readout.
##
## Kept as a `const` here rather than promoted to `data/`, because that is the form legacy gave it: the
## bands were a `.tres`-backed table and became `data/bands`, and these were renderer constants and stay
## renderer constants. Promoting them would be an unrequested design change, not a port.
##
## Legacy rows are 32px logic cells with `SURFACE_ROW = 20`, so `metres = row - 20` -- exactly the
## conversion `data/bands/*.yaml` already documents for the other ladder.
const ZONE_TINTS: Array[Dictionary] = [
	{"from_m": 10.0, "to_m": 26.0, "color": Color(0.86, 0.58, 0.30), "strength": 0.22},  # Clayband warmth to lose
	{"from_m": 28.0, "to_m": 42.0, "color": Color(0.55, 0.58, 0.66), "strength": 0.16},  # the honest neutral middle
	{"from_m": 44.0, "to_m": 64.0, "color": Color(0.40, 0.30, 0.62), "strength": 0.26},  # the approach to the seal
	{"from_m": 66.0, "to_m": 98.0, "color": Color(0.42, 0.55, 0.90), "strength": 0.34},  # Stonereach, below the seal
]


## Legacy's own `_cell_base_color` normalises depth by `FactorySim.GRID_ROWS` (128 rows == 128 m) before
## applying `depth_darken`. Kept as metres so it survives the grid change; this world runs to 256 m, so
## a cell at 128 m darkens exactly as legacy's bottom row did, and everything below sits at the clamp.
const DEPTH_DARKEN_FULL_M: float = 128.0


## Nugget-bearing materials: the fraction of cells that carry the nugget colour rather than the host.
## Derived, not picked -- see `is_speck`. Legacy's `nugget_count` is crystals per 32px cell; one 32px
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


## The band's own tint, as a `Color`. The record carries `color` as a three-float ARRAY straight out of
## `data/bands/*.yaml`, and every consumer would otherwise repeat that unpacking -- which is how a
## palette ends up with two conversions that disagree about whether the fourth element is alpha.
## D0271: added for `view/hud/depth_chip.gd`, the band ladder's first renderer.
func band_color(row: int) -> Color:
	return _to_color(band_at(row)["color"])


## Metres below the surface datum. Negative above it, deliberately, exactly as legacy: "standing on a
## hilltop reads as a negative depth rather than a clamped zero, so the number is never fudged."
static func depth_m(row: int) -> int:
	return int(floor(float(row - SURFACE_ROW) / float(CELLS_PER_METRE)))


## The fill colour for one solid terrain cell. Deterministic in (material, col, row) and free of any
## RNG, so two runs of the same seed paint identically -- this is a debug scene, not the sim, but a
## renderer whose output moves between runs cannot be screenshot-compared, which Slice 0's whole
## deliverable depends on.
## Legacy's order exactly (`_cell_fill_color` -> `_cell_base_color` -> `apply_tone`): base, darkened with
## depth, zone-tinted, then the (jitter, bedding) tone. The nugget lift is applied LAST and UNTONED,
## because in legacy the crystal is a polygon drawn ON TOP of the finished fill rather than part of it --
## toning it would shade a mineral face with the bedding of the rock behind it.
##
## ORE-BEARING ROCK IS NOT ZONE-TINTED, and this is the one place the port had to decide something legacy
## never had to. Legacy tints the country rock and then draws the ore as SEPARATE untinted crystal
## polygons over the top (`world_renderer.gd:1181 _draw_lode`, `:1223 _draw_grain`) -- so a vein keeps its
## own mineral colour however deep it sits. This world's terrain cell is 4px and legacy's smallest nugget
## mark is 6.4px, so there is no room to draw a crystal ON a cell; the cell IS the mark, which is the
## whole basis of `is_speck`/`speck_color`. That leaves the ore's own body colour going through the tint, and the
## measured consequence was severe: at 252 m all four zone bands are clamped at full strength and only
## 32% of a material's own colour survives (0.78*0.84*0.74*0.66), which collapsed glimmer-vs-deepstone
## separation from 0.25 to **0.061** and would have made a vein unfindable in Stonereach.
##
## So the exemption is not a workaround for a failing test -- it is the same rule legacy enforced by
## drawing order, re-expressed as the only mechanism this grid has. The predicate is legacy's own
## `MaterialDef.has_nuggets()` (`material_def.gd:45`), NOT `glitters`: `glitters` gates the glint FLARE
## and is true of plain deepstone and hardrock, which are country rock and must keep tinting. Four
## materials are exempt (coal, glimmer, ore_copper, ore_iron); three are not (clay, deepstone, hardrock).
## `tests/test_material_palette.gd`'s distinctness floor is what holds this honest.
func cell_color(material: StringName, col: int, row: int) -> Color:
	if is_speck(material, col, row):
		return speck_color(material, col, row)
	return matrix_color(material, col, row)


## The rock at this cell WITHOUT the mineral mark on it: base, depth-darkened, zone-tinted, toned. This
## is what legacy calls the matrix, and it is a separate function from the mark for one reason — the wall
## plane tones the matrix and does NOT tone the mark (`world_renderer.gd:1204` "the matrix is baked into
## the wall plane; what is left for the live pass is the metal in it"). While `cell_color` was the only
## way in, `wall_painter.wall_color` had no way to honour that ordering and put both through the recess.
## Public for `WallPainter`; the split changes nothing about what `cell_color` returns (D0299).
func matrix_color(material: StringName, col: int, row: int) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if rec.is_empty() or not rec.has("base_color"):
		return Color(0.42, 0.34, 0.24)  # the pre-Slice-0 debug brown: an unmapped material stays visible
	var base: Color = _to_color(rec["base_color"])
	base = _depth_darkened(base, rec, row)
	var country_rock: bool = not rec.has("nugget_color")
	return BeddingTone.apply_tone(base, BeddingTone.cell_tone(col, row, country_rock, grammar_of(material)))


## The rock's colour with NO bedding tone on it: base, depth-darkened, nothing per cell. The back wall
## takes this (D0422, rank 7): the laminae are what a FACE wears, and a wall wearing the same stripes a
## plane back read to a blind judge as "striped solid earth". Flatter is legacy's own word for the wall.
func flat_color(material: StringName, row: int) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if rec.is_empty() or not rec.has("base_color"):
		return Color(0.42, 0.34, 0.24)
	return _depth_darkened(_to_color(rec["base_color"]), rec, row)


## THE MATERIAL'S TEXTURE GRAMMAR, as a `RockTone.GRAM_*` index. Reads the `grammar:` field that
## `data/materials/*.yaml` has carried since Slice 0 and that **nothing has read until now** — the same
## shape as the depth chip before D0271, where the data was entirely present and only the consumer was
## missing. D0327.
##
## Defaults to CLASTIC for a material with no `grammar:` key, which is what legacy does when its own
## `grammar_at` callable is unset — and legacy warns that this default is silent, so an unmapped material
## reads as soil rather than erroring. `tests/test_rock_tone.gd` asserts every shipped material resolves
## to a grammar its own YAML names, so the default cannot quietly absorb a typo.
func grammar_of(material: StringName) -> int:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	match String(rec.get("grammar", "clastic")):
		"bedded": return RockTone.GRAM_BEDDED
		"massive": return RockTone.GRAM_MASSIVE
		_: return RockTone.GRAM_CLASTIC


## True when this cell carries the mineral mark rather than the matrix around it. Public so a test can
## NAME the population it is measuring: "ore vs rock" pooled over both branches compares an ore's own
## matrix against country rock and demands they differ, which is asking for the opposite of what the
## matrix is for — the first version of `test_wall_painter`'s ore assertion did exactly that and its
## worst case was coal's matrix against deepstone's, two country rocks that are supposed to be alike.
func is_speck(material: StringName, col: int, row: int) -> bool:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if not rec.has("nugget_color"):
		return false
	var density: float = float(int(rec.get("nugget_count", 0))) / LEGACY_CELL_SUBCELLS
	return _hash01(col, row, 7717) < density


## The mark itself, at full strength, independent of whatever it is drawn over — which is what makes it
## portable to the wall plane. Legacy draws socket / body / facet as three polygons; at one cell there is
## room for one value, so the cell takes the crystal body and a hash decides whether it is the lit facet
## or the seated socket.
func speck_color(material: StringName, col: int, row: int) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if not rec.has("nugget_color"):
		return matrix_color(material, col, row)
	var nug: Color = _to_color(rec["nugget_color"])
	return nug.lightened(0.22) if _hash01(col, row, 3391) < 0.34 else nug.darkened(0.18)


## Legacy `world_renderer.gd:1516-1523 _zone_tinted`. Ease `base` toward every zone tint whose band this
## depth has ENTERED, cumulatively -- so a cell deep in the world carries the sum of every band above it,
## and a band is a stretch you travel rather than a step you cross.
##
## Public because the wall plane needs the identical answer: legacy applies this to terrain AND walls so
## the whole stratum shifts together, and two copies of the ladder is exactly how the foreground and the
## background come to disagree about what depth they are at.
func zone_tinted(base: Color, row: int) -> Color:
	var m: float = depth_m_exact(row)
	var out: Color = base
	for z: Dictionary in ZONE_TINTS:
		var lo: float = float(z["from_m"])
		if m <= lo:
			continue
		var t: float = clampf((m - lo) / (float(z["to_m"]) - lo), 0.0, 1.0)
		out = out.lerp(z["color"] as Color, float(z["strength"]) * smoothstep(0.0, 1.0, t))
	return out


## Depth in metres as a FLOAT. `depth_m` floors to an int because a depth READOUT is a whole number; a
## tint that stepped on integer metres would band at four-cell intervals, which is the stripe artefact
## `_strata`'s comment above is about.
##
## **IT MUST SUBTRACT `SURFACE_ROW`, AND FOR TWENTY METRES IT DID NOT** (D0301). Written under D0252 as
## `row / CELLS_PER_METRE`, which was correct while the surface datum sat at row 0 — and P017/D0292 moved
## it to row 80 the same day, updating `depth_m` and not this. The two then disagreed by exactly the sky
## band, 20 m, while presenting themselves as the same measurement at two precisions. `zone_tinted` reads
## this one, so every terrain tint was applied twenty metres too shallow: rock at the surface was already
## 62% of the way through a Clayband warmth that should not begin until 10 m down, and the colour bands
## no longer lined up with the ladder the depth chip announces. `test_material_palette` now asserts the
## two agree at every row rather than trusting this comment (memory: a caveat in prose does not protect).
static func depth_m_exact(row: int) -> float:
	return float(row - SURFACE_ROW) / float(CELLS_PER_METRE)


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
