extends "res://tests/test_base.gd"

## `sim/world/seams.gd`, lifted from legacy with its three rates and `_plane` converted from float to
## integer (`docs/DECISIONS_LEDGER.md` D0227). The port is only safe if that conversion changed no
## answer, so the first test does not spot-check the new code -- it recomputes LEGACY'S OWN FLOAT
## EXPRESSION alongside the integer one and asserts they agree on every input it tries.
##
## That is the assertion that matters here. A rewritten hash comparison is exactly the kind of change
## that looks obviously equivalent and is off by one on a boundary nobody samples: `v < int(0.18 *
## 65535)` flips a single input out of 65,536, which no random sample would ever find and which would
## silently re-grain one plane of every world. So the boundary is swept exhaustively rather than
## sampled, and the near-miss form is included as a control that FAILS the same sweep.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_seams.gd

const SAMPLES: int = 4000
const SEED: int = 20260826


func _initialize() -> void:
	_test_the_integer_comparison_matches_legacys_float_one_on_every_sampled_plane()
	_test_the_naive_rounding_would_have_differed_which_is_why_the_sweep_exists()
	_test_a_seam_is_a_pure_function_of_cell_and_seed()
	_test_axis_and_alignment_read_a_seam_as_an_undirected_line()
	_test_grain_is_stable_and_non_negative()
	_finish("seams")


## Legacy's expression, written out rather than imported: `float(h) / 65535.0 < rate_as_float`.
func _legacy_under(numerator: int, rate_float: float) -> bool:
	return float(numerator) / 65535.0 < rate_float


func _test_the_integer_comparison_matches_legacys_float_one_on_every_sampled_plane() -> void:
	var pairs: Array = [
		[Seams.RATE_HORIZONTAL, 0.18], [Seams.RATE_VERTICAL, 0.12], [Seams.RATE_DIAGONAL, 0.07],
	]
	var disagreements: int = 0
	var first: String = ""
	var trues: int = 0
	# The whole 0..65535 domain, not a sample: this is the one sweep that can prove an off-by-one absent.
	for numerator: int in range(0, Seams.PLANE_MAX + 1):
		for pair: Array in pairs:
			var got: bool = Seams._under(numerator, int(pair[0]))
			if got:
				trues += 1
			if got != _legacy_under(numerator, float(pair[1])):
				disagreements += 1
				if first == "":
					first = "numerator=%d rate=%d" % [numerator, pair[0]]
	# The discriminating quantity first: a sweep that answered `false` everywhere would also report zero
	# disagreements, so the count of TRUE answers is what proves the comparison was actually exercised.
	print("  [OBSERVED] %d integer/float comparisons over the full domain, %d answered true, %d disagreed"
		% [(Seams.PLANE_MAX + 1) * pairs.size(), trues, disagreements])
	_check(trues > 0,
		"the sweep actually exercised the comparison -- %d of %d inputs are under a rate (0 would mean the sweep proved nothing)"
		% [trues, (Seams.PLANE_MAX + 1) * pairs.size()])
	_check(disagreements == 0,
		"the integer comparison agrees with legacy's float one on all %d inputs x 3 rates (%d disagreements%s)"
		% [Seams.PLANE_MAX + 1, disagreements, "" if first == "" else ", first at " + first])


## The control for the test above, and the reason it sweeps instead of sampling: the OBVIOUS conversion
## -- truncating the rate to an integer threshold -- is wrong, and wrong on exactly one input per rate.
## If this ever reports 0, the sweep above has stopped being able to tell the two forms apart.
func _test_the_naive_rounding_would_have_differed_which_is_why_the_sweep_exists() -> void:
	var pairs: Array = [
		[Seams.RATE_HORIZONTAL, 0.18], [Seams.RATE_VERTICAL, 0.12], [Seams.RATE_DIAGONAL, 0.07],
	]
	var naive_disagreements: int = 0
	var witness: String = ""
	for pair: Array in pairs:
		var threshold: int = int(float(pair[1]) * 65535.0)  # the tempting one-liner
		for numerator: int in range(0, Seams.PLANE_MAX + 1):
			if (numerator < threshold) != _legacy_under(numerator, float(pair[1])):
				naive_disagreements += 1
				if witness == "":
					witness = "numerator=%d rate=%.2f threshold=%d" % [numerator, pair[1], threshold]
	print("  [OBSERVED] the naive `v < int(rate * 65535)` form disagrees with legacy on %d input(s) (%s)"
		% [naive_disagreements, witness])
	_check(naive_disagreements > 0,
		"CONTROL: the naive rounding really does differ, so the exhaustive sweep above is discriminating between two live candidates rather than confirming a tautology (%d disagreement(s))"
		% naive_disagreements)


func _test_a_seam_is_a_pure_function_of_cell_and_seed() -> void:
	var counts: Dictionary = {Seams.NONE: 0, Seams.HORIZONTAL: 0, Seams.VERTICAL: 0, Seams.DIAGONAL: 0}
	var unstable: int = 0
	for i: int in SAMPLES:
		var cell: Vector2i = Vector2i(i % 97, i / 97)
		var once: int = Seams.at(cell, SEED)
		if Seams.at(cell, SEED) != once:
			unstable += 1
		counts[once] += 1
	var grained: int = SAMPLES - int(counts[Seams.NONE])
	print("  [OBSERVED] over %d cells: none=%d horizontal=%d vertical=%d diagonal=%d (%.1f%% grained)"
		% [SAMPLES, counts[Seams.NONE], counts[Seams.HORIZONTAL], counts[Seams.VERTICAL],
		counts[Seams.DIAGONAL], 100.0 * float(grained) / float(SAMPLES)])
	_check(unstable == 0, "the same (cell, seed) returns the same seam every call (%d unstable)" % unstable)
	# The file's own claim is "roughly a third of the world is grained". Asserted as a wide band, not a
	# pinned number: this is a property of the hash, and pinning it would make a re-grain look like a bug.
	_check(grained > 0 and grained < SAMPLES,
		"the field is neither all-NONE nor all-grained -- %d of %d cells carry a seam; all-NONE would mean the rates never fire and the sweep above measured a dead function"
		% [grained, SAMPLES])


func _test_axis_and_alignment_read_a_seam_as_an_undirected_line() -> void:
	_check(Seams.terrain_axis(Seams.NONE) == Vector2i.ZERO, "NONE has no axis")
	_check(not Seams.aligned(Seams.NONE, Vector2i(1, 0)), "nothing aligns with NONE")
	_check(not Seams.aligned(Seams.HORIZONTAL, Vector2i.ZERO), "a still body's blow aligns with nothing")
	# Undirected: both signs of the same line must align, or half of every seam is dead.
	_check(Seams.aligned(Seams.HORIZONTAL, Vector2i(1, 0))
		and Seams.aligned(Seams.HORIZONTAL, Vector2i(-1, 0)),
		"a horizontal seam is cut along by a blow travelling either way down its line")
	_check(not Seams.aligned(Seams.HORIZONTAL, Vector2i(0, 1)),
		"a horizontal seam is NOT cut along by a vertical blow")
	_check(Seams.aligned(Seams.DIAGONAL, Vector2i(2, -2))
		and not Seams.aligned(Seams.DIAGONAL, Vector2i(2, 2)),
		"the anti-diagonal seam takes (1,-1) and rejects the other diagonal")


func _test_grain_is_stable_and_non_negative() -> void:
	var negatives: int = 0
	var distinct: Dictionary = {}
	for i: int in SAMPLES:
		var value: int = Seams.grain(Vector2i(i % 89, i / 89))
		if value < 0:
			negatives += 1
		distinct[value] = true
	print("  [OBSERVED] grain over %d cells: %d distinct values, %d negative" % [SAMPLES, distinct.size(), negatives])
	_check(negatives == 0, "grain is masked to 31 bits and never negative (%d negative)" % negatives)
	# A scramble that collapsed would still be stable and non-negative, so distinctness is the assertion
	# that can actually fail if the hash is broken.
	_check(distinct.size() > SAMPLES / 2,
		"grain scatters rather than collapsing -- %d distinct values over %d cells" % [distinct.size(), SAMPLES])
