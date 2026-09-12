class_name Relief
extends RefCounted
## The surface as legacy shaped it: `legacy/src/core/heightmap_world_gen.gd` `ground_row` (:122-135),
## `terrace`/`_terrace_raw` (:145-155) and `on_scarp` (:158-163). A flat pad about the spawn, one wave of
## long-wavelength roll fading in over the first ramp beyond it, two more fading in over the second, and
## authored scarps that step the ground between terraces. Ported in A' step 8b (D0382) onto the
## deterministic generator: every quantity is an integer, and the three sines are read from
## `Angle.SIN_MILLI`, a 256-entry table of `round(sin(2*pi*i/256) * 1000)`, because `sin` is a libm
## call and the generation path may not make one (D0381). The table lived here until P044 --
## `core/bedding_dip.gd` needed the same sine where `view/` could reach it, and `Relief` is the wrong
## address for that (view may not depend on sim), so the deterministic trig kit moved to
## `core/angle.gd` and these names now delegate. The angle unit is 1/65536 of a turn; a table entry
## is 256 units, so a phase resolves to 1.4 degrees, which at these amplitudes (at most 6.4 cells) is
## under a hundredth of a cell.
##
## Everything reads a `relief` site config (`data/strata/*.yaml`); a site without one is flat at the
## datum, which is exactly the generator before this pass existed. The record's units are legacy's own
## (metres, radians) so each number can be checked against its source line; they are converted ONCE here
## with IEEE basic operations (a multiply, a divide, a round -- no libm), and from there it is integers.
##
## Evaluated per terrain column (a quarter metre) rather than per legacy column (a metre), so the hills
## legacy rounded to metre steps come out as quarter-metre steps here: the wave slopes are at most 0.76
## cells a column, so off a scarp face no two neighbouring columns differ by more than one cell.

const MILLI: int = 1000


## sin(angle) in thousandths -- delegates to `Angle.sin_milli`, the one table the project shares.
static func sin_milli(angle_units: int) -> int:
	return Angle.sin_milli(angle_units)


## Legacy's radians to angle units, once, at load.
static func units(rad: float) -> int:
	return Angle.units(rad)


## Legacy's radians per metre to angle units per terrain column.
static func units_per_cell(freq_rad_per_m: float, cells_per_m: int) -> int:
	return int(round(freq_rad_per_m / float(cells_per_m) / TAU * float(Angle.TURN)))


## Legacy's metres to thousandths of a cell.
static func milli_cells(metres: float, cells_per_m: int) -> int:
	return int(round(metres * float(cells_per_m) * float(MILLI)))


## Thousandths to whole, rounding half away from zero -- `Angle.round_milli`, kept under the name the
## pass was written against.
static func round_milli(v: int) -> int:
	return Angle.round_milli(v)


## A surface at one row across the width: the generator before relief, and every site without the key.
static func flat(width: int, datum: int) -> PackedInt32Array:
	var rows := PackedInt32Array()
	rows.resize(width)
	rows.fill(datum)
	return rows


## Every row shifted by `delta`: a per-column floor some cells under a per-column surface.
static func offset(rows: PackedInt32Array, delta: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(rows.size())
	for i: int in rows.size():
		out[i] = rows[i] + delta
	return out


## The surface row of every column for a site, `datum` where the site has no `relief`.
static func surface_rows(site: Dictionary, width: int, datum: int, cells_per_m: int) -> PackedInt32Array:
	if not site.has("relief"):
		return flat(width, datum)
	var cfg: Dictionary = site["relief"]
	var rows := PackedInt32Array()
	rows.resize(width)
	for col: int in width:
		rows[col] = ground_row(cfg, col, datum, cells_per_m)
	return rows


## The flat pad's first and last column, inclusive: legacy `BASE_PAD_START`/`BASE_PAD_END`, authored
## here as a centre (the start's spawn column) and a half-width.
static func terrain_pad(cfg: Dictionary, cells_per_m: int) -> Vector2i:
	var centre: int = int(cfg["pad_centre_m"]) * cells_per_m
	var half: int = int(cfg["pad_half_m"]) * cells_per_m
	return Vector2i(centre - half, centre + half)


## How far outside the pad a column sits, in cells; 0 anywhere on it.
static func outside(cfg: Dictionary, col: int, cells_per_m: int) -> int:
	var p: Vector2i = terrain_pad(cfg, cells_per_m)
	return maxi(0, maxi(p.x - col, col - p.y))


## Legacy `ground_row`: the datum on the pad; beyond it the near wave fades in over the first ramp and
## the far waves over the second, and the terraces step it. Clamped to the authored rise and fall.
static func ground_row(cfg: Dictionary, col: int, datum: int, cells_per_m: int) -> int:
	var out: int = outside(cfg, col, cells_per_m)
	if out <= 0:
		return datum
	var ramp: int = maxi(1, int(cfg["ramp_m"]) * cells_per_m)
	var near_pm: int = clampi(out * MILLI / ramp, 0, MILLI)
	var far_pm: int = clampi((out - ramp) * MILLI / ramp, 0, MILLI)
	var h: int = 0   # thousandths of a cell below the datum; negative is uphill
	for wave: Dictionary in cfg["waves"]:
		var weight: int = near_pm if str(wave.get("ramp", "far")) == "near" else far_pm
		var amp: int = milli_cells(float(wave["amp_m"]), cells_per_m)
		var angle: int = col * units_per_cell(float(wave["freq_rad_per_m"]), cells_per_m) \
			+ units(float(wave.get("phase_rad", 0.0)))
		h -= amp * sin_milli(angle) * weight / (MILLI * MILLI)
	var row: int = datum + round_milli(h) + terrace(cfg, col, cells_per_m)
	return clampi(row, datum - int(cfg["max_rise_m"]) * cells_per_m,
		datum + int(cfg["max_fall_m"]) * cells_per_m)


## The accumulated scarp offset at a column, measured from the pad's first column so the pad itself is
## at the datum (legacy `terrace`: "accumulating from column zero would leave the fixtures' flat ground
## five rows below the terrain either side").
static func terrace(cfg: Dictionary, col: int, cells_per_m: int) -> int:
	return _terrace_raw(cfg, col, cells_per_m) - _terrace_raw(cfg, terrain_pad(cfg, cells_per_m).x, cells_per_m)


static func _terrace_raw(cfg: Dictionary, col: int, cells_per_m: int) -> int:
	var span: int = maxi(1, int(cfg["scarp_span_m"]) * cells_per_m)
	var out: int = 0
	for s: Dictionary in cfg["scarps"]:
		var at: int = int(s["at_m"]) * cells_per_m
		if col <= at:
			continue
		# Fall over the span so the face is a face rather than one cliff edge, and still past a jump.
		var step: int = int(s["step_m"]) * cells_per_m
		out += round_milli(step * clampi((col - at) * MILLI / span, 0, MILLI))
	return out


## Is this column on a scarp face, the marked exception to the walkable-step contract?
static func on_scarp(cfg: Dictionary, col: int, cells_per_m: int) -> bool:
	var span: int = maxi(1, int(cfg["scarp_span_m"]) * cells_per_m)
	for s: Dictionary in cfg["scarps"]:
		var at: int = int(s["at_m"]) * cells_per_m
		if col > at and col <= at + span:
			return true
	return false
