class_name SurfaceTone
extends RefCounted

## THE GROUND IS GROUND, NOT A FILL COLOUR. Ported from `legacy/scenes/fine_terrain.gd`: the soil profile
## (`_soil`, `:231-320`), the moss on exposed tops and the hanging tufts under lips (`:208-230`,
## `:1074-1091`, `_moss_life`), and from `legacy/scenes/terrain_painter.gd:408-434` the surface cap's
## ragged slices, roots and blades. A' step 6o (D0378). These are the neighbour- and surface-aware terms
## `RockTone`'s header names as its follow-up; they live here so `RockTone.shade` stays a pure function of
## `(col, row, grammar, solid probe)` and this one adds the column's surface.
##
## LEGACY'S FINDING, kept in its words: "the opening frame's bottom half is the band directly under the
## grass, and it was painted with exactly the same rules as rock ninety metres down ... so the most-looked-
## at region in the game was also its least specific one." Real soil is banded (dark humus, warm subsoil,
## weathered rock), has things in it (pale cobbles, dark clasts), and roots reach down from what grows
## above. All of it keyed to depth below the COLUMN'S OWN surface, so a hillside's profile follows the hill.
##
## THE QUANTUM IS LEGACY'S FINE CELL (D0327): every row count below is legacy's fine-row count unchanged
## (SOIL_ROWS 40 = 10 m in both). The moss's life is in METRES below the datum, where legacy wrote world
## rows against its own surface row. The cap: legacy laid 3-6 px of cap colour on a 32 px cell, under a
## quarter of a metre, so here the walked surface cell IS the cap; its roots finger one cell down in one
## column in five and a blade overhangs one in three, by the same per-slice hash at one slice per cell.
##
## THE WALKED LINE IS BAND-GATED. `surface_y` names the first solid cell scanning down, so a dug shaft's
## floor is a "surface" too; legacy's `walked_surface` rejects rows below the band its generator can
## produce. A column surface deeper than `CAP_BAND_M` below the datum is a hole floor: no cap, no profile.

const SOIL_ROWS: int = 40            ## cells below the surface the profile spans (10 m)
const HUMUS_ROWS: int = 5
const HUMUS_DARKEN: float = 0.26
const SUBSOIL_ROWS: int = 20         ## legacy's shipped 20; its own note records the fade wakes at 23
const SUBSOIL_WARM: float = 0.13
const SUBSOIL_POLE := Color(0.52, 0.35, 0.18)   ## iron-stained ochre
const COBBLE_SCALE: float = 1.0
const COBBLE_THRESH: float = 0.26
const COBBLE_GAIN: float = 0.942
const CLAST_THRESH: float = -0.30
const CLAST_DARKEN: float = 0.20
const STONE_RAMP: float = 1.6
const ROOT_FREQ: float = 0.14
const ROOT_GATE: float = 0.34        ## per-cell coverage (1 - gate) / 2; legacy holds it, measured, not sparse
const ROOT_MAX: int = 26
const ROOT_DARKEN: float = 0.30
const MOSS_COLOR := Color(0.25, 0.36, 0.15)
const MOSS_DEPTH: int = 3
const MOSS_FREQ: float = 0.15
const MOSS_LUSH_M: float = 2.0       ## legacy MOSS_LUSH_ROW 22 against its surface row 20
const MOSS_DEAD_M: float = 14.0      ## legacy MOSS_DEAD_ROW 34: "roots and daylight end"
const HANG_DEPTH: int = 3
const HANG_GATE: float = 0.30
const CAP_BAND_M: float = 8.0        ## a column surface deeper than this is a hole floor, not the walked line
const CAP_ROOT_DARKEN: float = 0.34
const CAP_ROOT_MIX: float = 0.5
const NONE: int = -1

var _moss: FastNoiseLite
var _root: FastNoiseLite
var _stone: FastNoiseLite


func _init(world_seed: int) -> void:
	_moss = RockTone.field(world_seed, 0x9e3779b1, FastNoiseLite.TYPE_SIMPLEX, MOSS_FREQ)
	_root = RockTone.field(world_seed, 0x7feb352d, FastNoiseLite.TYPE_SIMPLEX, ROOT_FREQ)
	_stone = RockTone.field(world_seed, 0x1b873593, FastNoiseLite.TYPE_SIMPLEX, RockTone.STONE_FREQ)


## The column's walked surface as a terrain row, or NONE: the observation's height read back to a row,
## then the band gate.
static func column_surface_row(o: Interface.Observation, col: int) -> int:
	var y: int = o.surface_y_at_terrain_col(col)
	if y == Interface.Observation.NO_FLOOR or o.cell_px <= 0:
		return NONE
	var row: int = y / (o.cell_px * Fx.SCALE)
	return row if is_walked(row) else NONE


## Within the band the generator's ground can occupy: hills above the datum, and down to CAP_BAND_M.
static func is_walked(row: int) -> bool:
	return row >= 0 and MaterialLook.depth_m_exact(row) <= CAP_BAND_M


## The material's cap colour, or a transparent colour for a material that grows nothing on top.
static func cap_color(material: StringName) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if not rec.has("cap_color"):
		return Color(0.0, 0.0, 0.0, 0.0)
	return OrePainter.record_color(rec["cap_color"])


## Legacy's per-slice fringe hash, one slice per cell here: which columns root down and which blade up.
static func root_here(col: int) -> bool:
	return Seams.grain(Vector2i(col, 0)) % 5 == 0


static func tuft_here(col: int) -> bool:
	return (Seams.grain(Vector2i(col, 0)) >> 3) % 3 == 0


## How alive moss is at a row: full in the damp shallows, gone in the deep. A pure function of the row.
static func moss_life(row: int) -> float:
	return clampf((MOSS_DEAD_M - MaterialLook.depth_m_exact(row)) / (MOSS_DEAD_M - MOSS_LUSH_M), 0.0, 1.0)


## Cells between this one and the nearest open air in `dir` (up or down), or NONE within `reach`.
static func air_distance(solid_at: Callable, col: int, row: int, dir: int, reach: int) -> int:
	for d: int in range(reach):
		if not bool(solid_at.call(col, row + dir * (d + 1))):
			return d
	return NONE


## The surface terms over a shaded cell: the soil profile by depth below the column's surface, then moss
## on an exposed top or a tuft under a lip. `surface_row` NONE means a hole column: no profile.
func shade(base: Color, col: int, row: int, surface_row: int, solid_at: Callable) -> Color:
	var out: Color = base
	if surface_row != NONE:
		out = soil(out, col, row, row - (surface_row + 1))
	if not solid_at.is_valid():
		return out
	var alive: float = moss_life(row)
	if alive <= 0.0:
		return out
	var top: int = air_distance(solid_at, col, row, -1, MOSS_DEPTH)
	if top != NONE:
		var patch: float = _moss.get_noise_2d(float(col), float(row) * 0.6)
		if patch > -0.28:
			var band: float = (1.0 - float(top) / float(MOSS_DEPTH)) * clampf((patch + 0.28) * 1.5, 0.0, 1.0)
			return out.lerp(MOSS_COLOR, 0.55 * band * alive)
		return out
	var hang: int = air_distance(solid_at, col, row, 1, HANG_DEPTH)
	if hang != NONE:
		var hp: float = _moss.get_noise_2d(float(col) * 0.9, float(row) * 0.9 + 90.0)
		if hp > HANG_GATE:
			var hband: float = (1.0 - float(hang) / float(HANG_DEPTH)) * clampf((hp - HANG_GATE) * 3.0, 0.0, 1.0)
			return out.lerp(MOSS_COLOR.darkened(0.12), 0.55 * hband * alive)
	return out


## Legacy's `_soil`: humus ramped in and out under the cap, the warm subsoil below it, inclusions of both
## signs, roots reaching down; the whole profile fading over its last third so it ends in rock, not a rule.
func soil(c: Color, col: int, row: int, depth: int) -> Color:
	if depth < 0 or depth >= SOIL_ROWS:
		return c
	var strength: float = clampf(float(SOIL_ROWS - depth) / (float(SOIL_ROWS) * 0.34), 0.0, 1.0)
	var out: Color = c
	if depth < HUMUS_ROWS:
		var d: float = float(depth) / float(HUMUS_ROWS)
		out = out.darkened(HUMUS_DARKEN * smoothstep(0.0, 0.4, d) * (1.0 - d))
	elif depth < HUMUS_ROWS + SUBSOIL_ROWS:
		var t: float = float(depth - HUMUS_ROWS) / float(SUBSOIL_ROWS)
		out = out.lerp(SUBSOIL_POLE, SUBSOIL_WARM * (1.0 - t) * strength)
	var peb: float = _stone.get_noise_2d(float(col) * COBBLE_SCALE, float(row) * COBBLE_SCALE)
	if peb > COBBLE_THRESH:
		var gain: float = 1.0 + COBBLE_GAIN * smoothstep(0.0, 1.0, (peb - COBBLE_THRESH) * STONE_RAMP) * strength
		out = Color(minf(out.r * gain, 1.0), minf(out.g * gain, 1.0), minf(out.b * gain, 1.0), out.a)
	elif peb < CLAST_THRESH:
		out = out.darkened(CLAST_DARKEN * smoothstep(0.0, 1.0, (CLAST_THRESH - peb) * STONE_RAMP) * strength)
	var rn: float = _root.get_noise_2d(float(col) * 1.9, float(row) * 0.18)
	if rn > ROOT_GATE:
		# Legacy's 3.0 is coupled to ROOT_GATE (its note); kept as written, not rewritten as a quotient.
		var reach: float = float(ROOT_MAX) * clampf((rn - ROOT_GATE) * 3.0, 0.0, 1.0)
		if float(depth) < reach:
			out = out.darkened(ROOT_DARKEN * (1.0 - float(depth) / reach))
	return out
