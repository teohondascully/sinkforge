class_name Relief
extends RefCounted
## The surface as legacy shaped it: `legacy/src/core/heightmap_world_gen.gd` `ground_row` (:122-135),
## `terrace`/`_terrace_raw` (:145-155) and `on_scarp` (:158-163). A flat pad about the spawn, one wave of
## long-wavelength roll fading in over the first ramp beyond it, two more fading in over the second, and
## authored scarps that step the ground between terraces. Ported in A' step 8b (D0382) onto the
## deterministic generator: every quantity is an integer, and the three sines are read from `SIN_MILLI`,
## a 256-entry table of `round(sin(2*pi*i/256) * 1000)`, because `sin` is a libm call and the generation
## path may not make one (D0381). The angle unit is 1/65536 of a turn; a table entry is 256 units, so a
## phase resolves to 1.4 degrees, which at these amplitudes (at most 6.4 cells) is under a hundredth of
## a cell.
##
## Everything reads a `relief` site config (`data/strata/*.yaml`); a site without one is flat at the
## datum, which is exactly the generator before this pass existed. The record's units are legacy's own
## (metres, radians) so each number can be checked against its source line; they are converted ONCE here
## with IEEE basic operations (a multiply, a divide, a round -- no libm), and from there it is integers.
##
## Evaluated per terrain column (a quarter metre) rather than per legacy column (a metre), so the hills
## legacy rounded to metre steps come out as quarter-metre steps here: the wave slopes are at most 0.76
## cells a column, so off a scarp face no two neighbouring columns differ by more than one cell.

const TURN: int = 65536       ## angle units in a full turn
const TABLE_SHIFT: int = 8    ## TURN / SIN_MILLI.size(): 256 angle units per table entry
const MILLI: int = 1000

## round(sin(2*pi*i/256) * 1000) for i in 0..255. Generated, then checked in `tests/test_relief.gd`
## against the values a sine must have (the quarter points, the octant, odd symmetry).
const SIN_MILLI: PackedInt32Array = [
	0, 25, 49, 74, 98, 122, 147, 171, 195, 219, 243, 267, 290, 314, 337, 360,
	383, 405, 428, 450, 471, 493, 514, 535, 556, 576, 596, 615, 634, 653, 672, 690,
	707, 724, 741, 757, 773, 788, 803, 818, 831, 845, 858, 870, 882, 893, 904, 914,
	924, 933, 942, 950, 957, 964, 970, 976, 981, 985, 989, 992, 995, 997, 999, 1000,
	1000, 1000, 999, 997, 995, 992, 989, 985, 981, 976, 970, 964, 957, 950, 942, 933,
	924, 914, 904, 893, 882, 870, 858, 845, 831, 818, 803, 788, 773, 757, 741, 724,
	707, 690, 672, 653, 634, 615, 596, 576, 556, 535, 514, 493, 471, 450, 428, 405,
	383, 360, 337, 314, 290, 267, 243, 219, 195, 171, 147, 122, 98, 74, 49, 25,
	0, -25, -49, -74, -98, -122, -147, -171, -195, -219, -243, -267, -290, -314, -337, -360,
	-383, -405, -428, -450, -471, -493, -514, -535, -556, -576, -596, -615, -634, -653, -672, -690,
	-707, -724, -741, -757, -773, -788, -803, -818, -831, -845, -858, -870, -882, -893, -904, -914,
	-924, -933, -942, -950, -957, -964, -970, -976, -981, -985, -989, -992, -995, -997, -999, -1000,
	-1000, -1000, -999, -997, -995, -992, -989, -985, -981, -976, -970, -964, -957, -950, -942, -933,
	-924, -914, -904, -893, -882, -870, -858, -845, -831, -818, -803, -788, -773, -757, -741, -724,
	-707, -690, -672, -653, -634, -615, -596, -576, -556, -535, -514, -493, -471, -450, -428, -405,
	-383, -360, -337, -314, -290, -267, -243, -219, -195, -171, -147, -122, -98, -74, -49, -25,
]


## sin(angle) in thousandths, any integer angle: `>>` is arithmetic, so a negative angle lands on the
## right entry after the mask, and a full turn past it lands on the same one.
static func sin_milli(angle_units: int) -> int:
	return SIN_MILLI[(angle_units >> TABLE_SHIFT) & (SIN_MILLI.size() - 1)]


## Legacy's radians to angle units, once, at load.
static func units(rad: float) -> int:
	return int(round(rad / TAU * float(TURN)))


## Legacy's radians per metre to angle units per terrain column.
static func units_per_cell(freq_rad_per_m: float, cells_per_m: int) -> int:
	return int(round(freq_rad_per_m / float(cells_per_m) / TAU * float(TURN)))


## Legacy's metres to thousandths of a cell.
static func milli_cells(metres: float, cells_per_m: int) -> int:
	return int(round(metres * float(cells_per_m) * float(MILLI)))


## Thousandths to whole, rounding half away from zero (legacy's `int(round(h))`); integer `/` truncates
## toward zero, so the half is added on the side of the sign.
static func round_milli(v: int) -> int:
	return (v + MILLI / 2) / MILLI if v >= 0 else (v - MILLI / 2) / MILLI


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
