extends "res://tests/test_base.gd"

## `sim/terrain_gen/relief.gd` -- legacy's surface (`heightmap_world_gen.gd` `ground_row`/`terrace`/
## `on_scarp`) on the deterministic generator, A' step 8b (D0382). Two things this suite exists for:
## the sine TABLE is a sine (a table pasted wrong is a hill shape nobody would notice), and the pad the
## start record is stamped onto is dead flat at the datum while the ground beyond it is not.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_relief.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const DATUM: int = ShaftGenerator.SKY_ROWS
const W: int = 256


func _initialize() -> void:
	_test_the_table_is_a_sine()
	_test_sin_milli_wraps_and_takes_a_negative_angle()
	_test_legacys_constants_convert_to_the_numbers_worked_by_hand()
	_test_round_milli_rounds_half_away_from_zero()
	_test_no_relief_key_is_flat_at_the_datum()
	_test_the_pad_is_dead_flat_and_the_ground_beyond_it_is_not()
	_test_off_a_scarp_no_two_neighbours_differ_by_more_than_a_cell()
	_test_a_scarp_steps_the_terrace_by_the_authored_amount_over_its_span()
	_test_the_terraces_lie_where_legacy_put_them()
	_test_every_row_stays_inside_the_authored_rise_and_fall()
	_test_the_generator_fills_from_each_columns_own_surface()
	_test_the_cave_band_is_protected_under_every_column_not_just_the_datum()
	_test_the_same_site_and_seed_make_the_same_relief()
	_finish("relief")


## Legacy's numbers verbatim (`heightmap_world_gen.gd:10-59`), on this build's 64 m world: the pad is
## the start's spawn column (`data/starts/tutorial.yaml` spawn_col_m 32) and legacy's -9/+10 m about it;
## the two scarps keep legacy's shape (uphill toward the left edge, a lowland past the right one) at
## half its distances, and its third scarp fell beyond where this world ends.
func _cfg() -> Dictionary:
	return {
		"pad_centre_m": 32, "pad_half_m": 10, "ramp_m": 16,
		"waves": [
			{"amp_m": 0.85, "freq_rad_per_m": 0.21, "phase_rad": 0.5, "ramp": "near"},
			{"amp_m": 1.60, "freq_rad_per_m": 0.30, "phase_rad": 0.0, "ramp": "far"},
			{"amp_m": 0.90, "freq_rad_per_m": 0.11, "phase_rad": 1.7, "ramp": "far"},
		],
		"scarps": [{"at_m": 10, "step_m": 5}, {"at_m": 52, "step_m": 4}],
		"scarp_span_m": 2, "max_rise_m": 9, "max_fall_m": 11,
	}


func _site() -> Dictionary:
	return {"relief": _cfg()}


func _rows() -> PackedInt32Array:
	return Relief.surface_rows(_site(), W, DATUM, CPM)


func _test_the_table_is_a_sine() -> void:
	var t: PackedInt32Array = Relief.SIN_MILLI
	_check(t.size() == 256, "256 entries (%d)" % t.size())
	_check(t[0] == 0 and t[128] == 0, "zero at 0 and half a turn (%d, %d)" % [t[0], t[128]])
	_check(t[64] == 1000 and t[192] == -1000, "the quarter points are +-1000 (%d, %d)" % [t[64], t[192]])
	_check(t[32] == 707, "the octant is sin(45 deg) = 0.707 (%d)" % t[32])
	var odd: int = 0
	for i: int in 256:
		if t[i] != -t[(i + 128) % 256]:
			odd += 1
	_check(odd == 0, "odd about the half turn at every entry (%d off)" % odd)
	var falls: int = 0
	for i: int in range(1, 65):
		if t[i] < t[i - 1]:
			falls += 1
	_check(falls == 0, "rising through the first quarter (%d falls)" % falls)


func _test_sin_milli_wraps_and_takes_a_negative_angle() -> void:
	var q: int = Relief.TURN / 4
	_check(Relief.sin_milli(0) == 0, "sin 0")
	_check(Relief.sin_milli(q) == 1000, "sin of a quarter turn (%d)" % Relief.sin_milli(q))
	_check(Relief.sin_milli(-q) == -1000, "a negative quarter (%d)" % Relief.sin_milli(-q))
	_check(Relief.sin_milli(Relief.TURN + q) == 1000, "a full turn past it (%d)" % Relief.sin_milli(Relief.TURN + q))
	_check(Relief.sin_milli(-1) == -25 or Relief.sin_milli(-1) == 0,
		"just under zero reads the last entry, not an index error (%d)" % Relief.sin_milli(-1))


## Worked once by hand (and in Python) so a change to the conversions is a change to these.
func _test_legacys_constants_convert_to_the_numbers_worked_by_hand() -> void:
	_check(Relief.units_per_cell(0.21, 4) == 548, "NEAR_FREQ 0.21 rad/m is 548 units a column (%d)"
		% Relief.units_per_cell(0.21, 4))
	_check(Relief.units_per_cell(0.30, 4) == 782, "FAR_FREQ_A (%d)" % Relief.units_per_cell(0.30, 4))
	_check(Relief.units_per_cell(0.11, 4) == 287, "FAR_FREQ_B (%d)" % Relief.units_per_cell(0.11, 4))
	_check(Relief.units(0.5) == 5215, "a 0.5 rad phase (%d)" % Relief.units(0.5))
	_check(Relief.units(1.7) == 17732, "a 1.7 rad phase (%d)" % Relief.units(1.7))
	_check(Relief.milli_cells(0.85, 4) == 3400, "NEAR_AMP 0.85 m is 3.4 cells (%d)" % Relief.milli_cells(0.85, 4))
	_check(Relief.milli_cells(1.6, 4) == 6400, "FAR_AMP_A (%d)" % Relief.milli_cells(1.6, 4))


func _test_round_milli_rounds_half_away_from_zero() -> void:
	_check(Relief.round_milli(1499) == 1 and Relief.round_milli(1500) == 2, "1.499 -> 1, 1.5 -> 2")
	_check(Relief.round_milli(-1499) == -1 and Relief.round_milli(-1500) == -2, "-1.499 -> -1, -1.5 -> -2")
	_check(Relief.round_milli(0) == 0 and Relief.round_milli(-400) == 0, "small values round to 0")


func _test_no_relief_key_is_flat_at_the_datum() -> void:
	var rows: PackedInt32Array = Relief.surface_rows({}, W, DATUM, CPM)
	var off: int = 0
	for r: int in rows:
		if r != DATUM:
			off += 1
	_check(rows.size() == W and off == 0, "every one of %d columns at the datum without the key (%d off)"
		% [rows.size(), off])


func _test_the_pad_is_dead_flat_and_the_ground_beyond_it_is_not() -> void:
	var rows: PackedInt32Array = _rows()
	var pad: Vector2i = Relief.terrain_pad(_cfg(), CPM)
	_check(pad == Vector2i(88, 168), "the pad is columns 88..168, 22 m to 42 m (%s)" % str(pad))
	var off_pad: int = 0
	for col: int in range(pad.x, pad.y + 1):
		if rows[col] != DATUM:
			off_pad += 1
	_check(off_pad == 0, "every pad column is at the datum (%d off)" % off_pad)
	# CONTROL: beyond the pad the ground moves, or this whole file passes on a flat world.
	var moved: int = 0
	var extreme: int = 0
	for col: int in W:
		if rows[col] != DATUM:
			moved += 1
		extreme = maxi(extreme, absi(rows[col] - DATUM))
	_check(moved > 100, "CONTROL: more than a hundred columns are off the datum (%d)" % moved)
	_check(extreme >= 12, "CONTROL: the relief reaches at least 3 m somewhere (%d cells)" % extreme)


## Legacy's contract: "every step one the auto-step-up glides". At a quarter-metre column the wave slopes
## sum to at most 0.76 cells a column, so a neighbour differs by one cell at most; the scarps are the
## marked exception.
func _test_off_a_scarp_no_two_neighbours_differ_by_more_than_a_cell() -> void:
	var rows: PackedInt32Array = _rows()
	var worst: int = 0
	var where: int = -1
	for col: int in range(1, W):
		if Relief.on_scarp(_cfg(), col, CPM):
			continue
		var step: int = absi(rows[col] - rows[col - 1])
		if step > worst:
			worst = step
			where = col
	_check(worst <= 1, "the steepest off-scarp step is one cell (%d at column %d)" % [worst, where])
	# CONTROL: on a scarp face the step IS larger than a cell, so the exclusion above excludes something.
	var face: int = 0
	for col: int in range(1, W):
		if Relief.on_scarp(_cfg(), col, CPM):
			face = maxi(face, absi(rows[col] - rows[col - 1]))
	_check(face > 1, "CONTROL: a scarp face steps more than a cell a column (%d)" % face)


func _test_a_scarp_steps_the_terrace_by_the_authored_amount_over_its_span() -> void:
	var cfg: Dictionary = _cfg()
	var at: int = 52 * CPM
	var span: int = 2 * CPM
	var before: int = Relief.terrace(cfg, at, CPM)
	var after: int = Relief.terrace(cfg, at + span, CPM)
	_check(after - before == 4 * CPM, "the second scarp falls 4 m = 16 cells over its span (%d)" % (after - before))
	_check(Relief.terrace(cfg, at + span + 40, CPM) == after, "and stays fallen past the face")
	_check(Relief.terrace(cfg, Relief.terrain_pad(cfg, CPM).x, CPM) == 0, "the pad's first column is the zero of the terraces")
	_check(not Relief.on_scarp(cfg, at, CPM) and Relief.on_scarp(cfg, at + 1, CPM)
		and Relief.on_scarp(cfg, at + span, CPM) and not Relief.on_scarp(cfg, at + span + 1, CPM),
		"on_scarp is the half-open span (at, at + span]")


## Legacy's shape: the ground left of the first scarp is 5 m HIGHER than the pad (terrace -5 there,
## because the pad measures from the far side of that scarp); past the second it is 4 m LOWER.
func _test_the_terraces_lie_where_legacy_put_them() -> void:
	var rows: PackedInt32Array = _rows()
	var high: int = 0
	for col: int in range(0, 31):
		if rows[col] < DATUM - 10:
			high += 1
	_check(high == 31, "every column in the first 31 is more than 2.5 m above the datum (%d of 31)" % high)
	var low: int = 0
	for col: int in range(220, W):
		if rows[col] > DATUM + 8:
			low += 1
	_check(low == W - 220, "every column past 220 is more than 2 m below the datum (%d of %d)" % [low, W - 220])


func _test_every_row_stays_inside_the_authored_rise_and_fall() -> void:
	var rows: PackedInt32Array = _rows()
	var out: int = 0
	for r: int in rows:
		if r < DATUM - 9 * CPM or r > DATUM + 11 * CPM:
			out += 1
	_check(out == 0, "no column outside [datum - 9 m, datum + 11 m] (%d)" % out)


## A short world with the relief on: the generator's first pass fills from the authored row, so the top
## face of every column is where `Relief` said, and nothing is generated above it.
func _relief_site() -> Dictionary:
	var site: Dictionary = StrataData.SHALLOW_CLAY.duplicate(true)
	site["max_depth_m"] = 64
	site["layer_thresholds_m"] = {"topsoil_shale_end": 20, "stonereach_end": 40}
	site["relief"] = _cfg()
	return site


func _test_the_generator_fills_from_each_columns_own_surface() -> void:
	var grid: TileGrid = ShaftGenerator.generate(_relief_site(), 20260826)
	var rows: PackedInt32Array = _rows()
	var wrong_top: int = 0
	var sky_block: int = 0
	for col: int in W:
		if not grid.is_solid(Vector2i(col, rows[col])):
			wrong_top += 1
		for row: int in rows[col]:
			if grid.is_solid(Vector2i(col, row)) or grid.get_wall(Vector2i(col, row)) != &"":
				sky_block += 1
				break
	_check(wrong_top == 0, "every column is solid at its authored surface row (%d not)" % wrong_top)
	_check(sky_block == 0, "and no block or wall is generated above it (%d columns have one)" % sky_block)


## THE ROW THE PER-COLUMN FLOOR EXISTS FOR. With one floor at the datum, the band under a valley floor
## is unprotected from its own depth down to the datum's. Here every cell in the protected band under
## EACH column's own surface is solid -- and the control carves the same disc under a valley with the
## scalar floor the passes used to take, and it breaches.
func _test_the_cave_band_is_protected_under_every_column_not_just_the_datum() -> void:
	var site: Dictionary = _relief_site()
	var grid: TileGrid = ShaftGenerator.generate(site, 20260826)
	var rows: PackedInt32Array = _rows()
	var band: int = int(site["cave"]["min_depth_cells"])
	_check(_breaches(grid, rows, band) == 0,
		"no column has an open cell in the %d rows under its own surface (%d do)" % [band, _breaches(grid, rows, band)])
	var open: int = 0
	for col: int in W:
		for row: int in range(rows[col] + band, grid.height):
			if not grid.is_solid(Vector2i(col, row)):
				open += 1
	_check(open > 0, "CONTROL: the world has %d open cells below the band" % open)
	# CONTROL THAT FAILS HARDER: the same disc, under a valley column, with the two floors. The datum's
	# scalar lets it open cells inside the valley's band; the per-column floor refuses every one.
	var col: int = 240
	_check(rows[col] > DATUM + 8, "the probe column is a valley (%d cells below the datum)" % (rows[col] - DATUM))
	var centre := Vector2i(col, DATUM + band + 6)
	var scalar_grid: TileGrid = _solid_hills(rows, grid.height)
	var opened_scalar: int = CavePasses.carve_disc(scalar_grid, centre, 4, Relief.flat(W, DATUM + band))
	var column_grid: TileGrid = _solid_hills(rows, grid.height)
	var opened_column: int = CavePasses.carve_disc(column_grid, centre, 4, Relief.offset(rows, band))
	_check(opened_scalar > 0 and _breaches(scalar_grid, rows, band) > 0,
		"CONTROL: the scalar floor opens %d cells and %d columns are breached inside their band"
		% [opened_scalar, _breaches(scalar_grid, rows, band)])
	_check(opened_column == 0 and _breaches(column_grid, rows, band) == 0,
		"the per-column floor opens %d cells there (%d breached)" % [opened_column, _breaches(column_grid, rows, band)])


## Columns with an open cell inside the `band` rows under their own surface.
func _breaches(grid: TileGrid, rows: PackedInt32Array, band: int) -> int:
	var breached: int = 0
	for col: int in W:
		for row: int in range(rows[col], mini(rows[col] + band, grid.height)):
			if not grid.is_solid(Vector2i(col, row)):
				breached += 1
				break
	return breached


## Solid rock from each column's surface down, nothing carved: the hills before any pass.
func _solid_hills(rows: PackedInt32Array, height: int) -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, height, 1)
	for col: int in W:
		for row: int in range(rows[col], height):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _test_the_same_site_and_seed_make_the_same_relief() -> void:
	var a: PackedInt32Array = _rows()
	var b: PackedInt32Array = _rows()
	_check(a == b, "surface_rows is a pure function of (site, width, datum)")
	var other: Dictionary = _cfg()
	other["pad_centre_m"] = 20
	var c: PackedInt32Array = Relief.surface_rows({"relief": other}, W, DATUM, CPM)
	_check(a != c, "CONTROL: moving the pad moves the surface")
