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
	var strong: int = 0
	var strong_darker: int = 0
	for col: int in range(100, 400, 7):
		for row: int in range(300, 340):
			var w: float = tone.lamina(float(col), float(row))
			if w > 0.0 and tone.lamina(float(col), float(row) + 1.0) == 0.0:
				n += 1
				var is_darker: bool = lum.call(tone.shade(base, col, row, RockTone.GRAM_BEDDED)) < lum.call(tone.shade(base, col, row + 1, RockTone.GRAM_BEDDED))
				if is_darker:
					darker += 1
				if w >= 0.25:
					strong += 1
					if is_darker:
						strong_darker += 1
	# D0406: partings vary in strength down to a faint few; a faint one can meet a dark speck in the bed
	# under it. Every parting above a quarter strength shades darker than its bed; the whole population does
	# at 95%, with the exceptions being those faint ones.
	_check_over(strong, strong > 30 and strong_darker == strong, "every parting at or above a quarter strength shades darker than the bed row under it (%d of %d)" % [strong_darker, strong])
	_check_over(n, n > 40 and darker * 20 >= n * 19, "and the whole population does at 95%% or better (%d of %d)" % [darker, n])
	var massive_darker: int = 0
	for col: int in range(100, 400, 7):
		for row: int in range(300, 340):
			if tone.lamina(float(col), float(row)) > 0.0 and tone.lamina(float(col), float(row) + 1.0) == 0.0:
				if lum.call(tone.shade(base, col, row, RockTone.GRAM_MASSIVE)) < lum.call(tone.shade(base, col, row + 1, RockTone.GRAM_MASSIVE)):
					massive_darker += 1
	_check(n > 40 and massive_darker < n * 3 / 4, "control: on the same rows massive rock shows no such rule (%d of %d darker, chance-level)" % [massive_darker, n])
	_test_the_beds_are_a_succession_not_a_period()


## D0406 (V71/T018, the "ruled paper"): down one column the partings come at UNEQUAL gaps and UNEQUAL
## strengths, and the facies changes the rhythm -- fewer partings a metre where the fade field runs low
## than where it runs high. Asserted on `BedSequence` with the field value posed directly, so the facies is
## the treatment and not a location, and on the real column through the tone. A period would give one gap
## and one strength (the class `linear-sequence-as-hash` names: sort, count distinct, flag few).
func _test_the_beds_are_a_succession_not_a_period() -> void:
	var beds := BedSequence.new(SEED)
	var gaps: Dictionary = {}
	var strengths: Dictionary = {}
	var last_row: int = -1
	var on_parting: bool = false
	for i: int in 2400:                              # 600 m of warped depth at the quarter-metre cell
		var b: float = i * 0.25
		var w: float = beds.weight(b, 12.0, 0.0)
		if w > 0.0 and not on_parting:
			if last_row >= 0:
				gaps[i - last_row] = true
			last_row = i
			strengths[snappedf(w, 0.01)] = true
		on_parting = w > 0.0
	_check(gaps.size() >= 4, "the gaps between partings take at least four distinct values, not one: %s" % [gaps.keys()])
	_check(strengths.size() >= 6, "the partings take at least six distinct strengths, not one: %d" % strengths.size())
	var per_m: Callable = func(n: float) -> float:
		var count: int = 0
		var on: bool = false
		for i: int in 4000:
			var w: float = beds.weight(i * 0.25, 12.0, n)
			if w > 0.0 and not on:
				count += 1
			on = w > 0.0
		return count / 1000.0
	var thick: float = per_m.call(-0.8)
	var mid: float = per_m.call(0.0)
	var fine: float = per_m.call(0.8)
	_check(thick < mid and mid < fine and thick > 0.15 and fine < 3.0,
		"the facies is a rhythm: %.2f partings a metre where the field runs low, %.2f through the middle, %.2f where it runs high" % [thick, mid, fine])
	var tone := RockTone.new(SEED)
	var col_gaps: Dictionary = {}
	var prev: int = -1
	var was: bool = false
	for row: int in range(200, 1200):
		var w: float = tone.lamina(160.0, float(row))
		if w > 0.0 and not was:
			if prev >= 0:
				col_gaps[row - prev] = true
			prev = row
		was = w > 0.0
	_check(col_gaps.size() >= 4, "and the real column through the tone parts at unequal gaps: %s" % [col_gaps.keys()])
	var same := BedSequence.new(SEED)
	var other := BedSequence.new(SEED + 1)
	var diff: int = 0
	for i: int in 400:
		if same.weight(i * 0.25, 3.0, 0.0) != other.weight(i * 0.25, 3.0, 0.0):
			diff += 1
	_check(same.weight(7.3, 3.0, 0.0) == beds.weight(7.3, 3.0, 0.0) and diff > 20, "seeded: the same seed beds the same, another seed differently (%d of 400 rows differ)" % diff)
