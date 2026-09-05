extends "res://tests/test_base.gd"
## D0398. `view/visuals/rock_tone.gd`'s parting planes and `view/visuals/bedding_tone.gd`: bedded rock is
## laminated at bed thickness on the same warped coordinate as the hue bands, and no other grammar is.
## Split from `tests/test_rock_tone.gd` at the file cap.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_rock_laminae.gd

const SEED: int = 20260826


func _initialize() -> void:
	_test_the_laminae_part_bedded_rock_only_at_bed_thickness()
	_test_the_bedding_coordinate_is_shared()
	_finish("rock_laminae")


## The hue bands and the parting lines read one coordinate, so a line is always on a bed: asserted by
## the coordinate being monotone in the row at a fixed column and continuous along the column at a fixed row.
func _test_the_bedding_coordinate_is_shared() -> void:
	var mono: bool = true
	for row: int in range(100, 600):
		if BeddingTone.bedding_metres(128.0, float(row + 1)) <= BeddingTone.bedding_metres(128.0, float(row)):
			mono = false
	_check(mono, "the bedding coordinate deepens with the row at every row")
	var max_step: float = 0.0
	for col: int in range(0, 255):
		max_step = maxf(max_step, absf(BeddingTone.bedding_metres(float(col + 1), 300.0) - BeddingTone.bedding_metres(float(col), 300.0)))
	_check(max_step < 0.1, "...and dips no more than a tenth of a metre a cell along a row (%.3f), so a parting is a line and not a stair" % max_step)
## D0398 (T017, "more bedding"): bedded rock carries parting planes -- one row in four at the metre bed,
## one in eight at the thick, one in two at the fine lamination -- and no other grammar does. Asserted on
## the term itself and on the shaded colour, so a grammar table that silently zeroed the term (the class
## `_test_no_grammar_table_is_silently_uniform` guards) would fail here on the colour too.
func _test_the_laminae_part_bedded_rock_only_at_bed_thickness() -> void:
	var tone := RockTone.new(SEED)
	_check(RockTone.lamina_period_m(-0.5) == 2.0 and RockTone.lamina_period_m(0.0) == 1.0 and RockTone.lamina_period_m(0.6) == 0.5,
		"the fade field picks 2 m, 1 m or 0.5 m beds")
	var partings: int = 0
	var rows: int = 0
	for col: int in range(100, 400, 7):
		for row: int in range(200, 600):
			rows += 1
			if tone.lamina(float(col), float(row)) > 0.0:
				partings += 1
	var share: float = float(partings) / float(rows)
	_check(share > 0.12 and share < 0.40, "partings are a minority of rows across every facies (%.3f of %d)" % [share, rows])
	_check(RockTone.GRAM_LAMINA[RockTone.GRAM_BEDDED] > 0.0 and RockTone.GRAM_LAMINA[RockTone.GRAM_CLASTIC] == 0.0 and RockTone.GRAM_LAMINA[RockTone.GRAM_MASSIVE] == 0.0,
		"bedded rock alone is laminated: soil is aggregate, massive rock is plates")
	var base := Color(0.4, 0.38, 0.35)
	var lum: Callable = func(c: Color) -> float: return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var darker: int = 0
	var n: int = 0
	for col: int in range(100, 400, 7):
		for row: int in range(300, 340):
			if tone.lamina(float(col), float(row)) > 0.0 and tone.lamina(float(col), float(row) + 1.0) == 0.0:
				n += 1
				if lum.call(tone.shade(base, col, row, RockTone.GRAM_BEDDED)) < lum.call(tone.shade(base, col, row + 1, RockTone.GRAM_BEDDED)):
					darker += 1
	_check_over(n, n > 40 and darker == n, "every parting row shades darker than the bed row under it (%d of %d)" % [darker, n])
	var massive_darker: int = 0
	for col: int in range(100, 400, 7):
		for row: int in range(300, 340):
			if tone.lamina(float(col), float(row)) > 0.0 and tone.lamina(float(col), float(row) + 1.0) == 0.0:
				if lum.call(tone.shade(base, col, row, RockTone.GRAM_MASSIVE)) < lum.call(tone.shade(base, col, row + 1, RockTone.GRAM_MASSIVE)):
					massive_darker += 1
	_check(n > 40 and massive_darker < n * 3 / 4, "control: on the same rows massive rock shows no such rule (%d of %d darker, chance-level)" % [massive_darker, n])
