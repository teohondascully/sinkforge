extends "res://tests/test_base.gd"

## `core/state_hash.gd`: the two-lane mixer every plane's running signature uses (extracted from
## `TileGrid` in A' step 2, D0344). The literal pins below were computed OUTSIDE the engine with the same
## arithmetic (`h = (h * 31 + v) & 0x7FFFFFFF`, seeds 2166136261 / 486187739) and are what makes "the
## arithmetic is unchanged from D0261" a checked property rather than a sentence: any drift in a seed, a
## multiplier, the mask or the fold order moves one of these numbers. `test_shaft_replay_determinism.gd`
## is the end-to-end version of the same claim.


func _initialize() -> void:
	_test_fold_of_nothing_is_the_seed_and_fold_matches_the_pins()
	_test_mix_and_term_match_the_pins_and_the_lanes_differ()
	_test_negative_coordinates_stay_in_31_bits()
	_test_text_term_and_id_fold_agree_and_the_memo_fills()
	_test_a_plane_term_is_order_independent_and_self_inverting_under_xor()
	_finish("state_hash")


func _test_fold_of_nothing_is_the_seed_and_fold_matches_the_pins() -> void:
	_check(StateHash.fold("", StateHash.LANE_A) == StateHash.LANE_A and StateHash.fold("", StateHash.LANE_B) == StateHash.LANE_B,
		"fold of the empty string is the seed itself, on both lanes")
	_check(StateHash.fold("hardrock", StateHash.LANE_A) == 1020189589, "fold('hardrock') on lane A is the pinned 1020189589")
	_check(StateHash.fold("hardrock", StateHash.LANE_B) == 783903403, "fold('hardrock') on lane B is the pinned 783903403")
	_check(StateHash.fold("dig4:2,9", StateHash.LANE_A) == 787999356 and StateHash.fold("dig4:2,9", StateHash.LANE_B) == 551713170,
		"fold of a dig-extent record matches its pins on both lanes")


func _test_mix_and_term_match_the_pins_and_the_lanes_differ() -> void:
	_check(StateHash.mix(3, 5, 7, 11, StateHash.LANE_A) == 1113564171, "mix(3,5,7,11) on lane A is the pinned 1113564171")
	_check(StateHash.mix(3, 5, 7, 11, StateHash.LANE_B) == 115944993, "mix(3,5,7,11) on lane B is the pinned 115944993")
	var t: Vector2i = StateHash.term(3, 5, Vector2i(7, 13), Vector2i(11, 17))
	_check(t == Vector2i(1113564171, 115945185), "term feeds .x payloads to lane A and .y payloads to lane B (got %s)" % str(t))
	_check(t.x != t.y, "the two lanes of one term differ")
	_check(StateHash.term(3, 5, Vector2i(7, 7), Vector2i(1, 1)) != StateHash.term(5, 3, Vector2i(7, 7), Vector2i(1, 1)),
		"swapping x and y changes the term: the coordinate is part of it")
	_check(StateHash.term(3, 5, Vector2i(7, 7), Vector2i(1, 1)) != StateHash.term(3, 5, Vector2i(8, 8), Vector2i(1, 1)),
		"changing the payload by one changes the term")


func _test_negative_coordinates_stay_in_31_bits() -> void:
	var t: Vector2i = StateHash.term(-2, -9, Vector2i.ONE, Vector2i.ONE)
	_check(t == Vector2i(1113401566, 115782388), "a negative coordinate folds to the pinned pair (got %s)" % str(t))
	var all_in_range: int = 0
	var probes: int = 0
	for x: int in range(-40, 41, 8):
		for y: int in range(-40, 41, 8):
			var q: Vector2i = StateHash.term(x, y, Vector2i(x * 7, y * 3), Vector2i(x, y))
			probes += 1
			if q.x >= 0 and q.x <= 0x7FFFFFFF and q.y >= 0 and q.y <= 0x7FFFFFFF:
				all_in_range += 1
	_check_over(probes, all_in_range == probes, "every lane value lies in [0, 2^31) over %d probes incl. negatives" % probes)


func _test_text_term_and_id_fold_agree_and_the_memo_fills() -> void:
	_check(StateHash.text_term("hardrock") == Vector2i(1020189589, 783903403), "text_term is fold on both lanes")
	var id := &"a_material_only_test_state_hash_uses"
	var before: int = StateHash._id_folds.size()
	var first: Vector2i = StateHash.id_fold(id)
	_check(StateHash._id_folds.size() == before + 1 and StateHash._id_folds.has(id), "id_fold memoises the id on first use")
	_check(StateHash.id_fold(id) == first and StateHash._id_folds.size() == before + 1, "the memoised value is the same and nothing new was stored")
	_check(first == StateHash.text_term(String(id)), "id_fold equals text_term of the id's string")


## What a plane relies on: XOR-ing terms in any order gives one accumulator, and XOR-ing a term again
## removes it. Equal terms cannot occur for two live records because the coordinate is inside each.
func _test_a_plane_term_is_order_independent_and_self_inverting_under_xor() -> void:
	var t1: Vector2i = StateHash.term(1, 1, Vector2i(5, 5), Vector2i.ONE)
	var t2: Vector2i = StateHash.term(2, 1, Vector2i(5, 5), Vector2i.ONE)
	var t3: Vector2i = StateHash.term(1, 2, Vector2i(6, 6), Vector2i.ONE)
	var forward: int = (t1.x ^ t2.x) ^ t3.x
	var backward: int = (t3.x ^ t2.x) ^ t1.x
	_check(forward == backward, "XOR of three terms is order-independent")
	_check(((forward ^ t2.x) ^ t2.x) == forward, "XOR-ing a term twice is a no-op: removal without a rebuild")
	_check((forward ^ t2.x) == (t1.x ^ t3.x), "removing one term leaves exactly the other two")
