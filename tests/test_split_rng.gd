extends "res://tests/test_base.gd"

## Golden vectors computed from a from-scratch Python reference implementation of SplitMix64 and
## FNV-1a 64-bit -- not from memory, not from the GDScript under test. See the commit message for how.
## If `core/split_rng.gd`'s constants or shift/mask logic ever change, regenerate these the same way;
## do not hand-edit a golden value to make a test pass.

func _initialize() -> void:
	_test_known_sequences()
	_test_split_matches_reference()
	_test_split_is_deterministic()
	_test_split_labels_diverge()
	_test_state_roundtrip()
	_test_two_seeds_diverge()
	_finish("split_rng")


func _test_known_sequences() -> void:
	var cases: Array = [
		{"seed": 0, "draws": [-2152535657050944081, 7960286522194355700, 487617019471545679,
			-537132696929009172, 1961750202426094747], "final_state": 1663341875487337577},
		{"seed": 1, "draws": [-7995527694508729151, -4689498862643123097, -534904783426661026,
			8196980753821780235, 8195237237126968761], "final_state": 1663341875487337578},
		{"seed": 42, "draws": [-4767286540954276203, 2949826092126892291, 5139283748462763858,
			6349198060258255764, 701532786141963250], "final_state": 1663341875487337619},
		{"seed": 12345, "draws": [2454886589211414944, 3778200017661327597, 2205171434679333405,
			3248800117070709450, -9096454462216767253], "final_state": 1663341875487349922},
	]
	for c: Dictionary in cases:
		var rng: SplitRng = SplitRng.new(c["seed"])
		var draws: Array = c["draws"]
		for i in draws.size():
			var got: int = rng.next_u64()
			_check(got == draws[i], "seed %d draw %d = %d (expected %d)" % [c["seed"], i, got, draws[i]])
		var final_state: int = rng.get_state()["state"]
		_check(final_state == c["final_state"], "seed %d final state = %d (expected %d)" %
			[c["seed"], final_state, c["final_state"]])


func _test_split_matches_reference() -> void:
	var cases: Array = [
		{"root": 0, "label": "world", "child_seed": -932880468218820628,
			"draws": [950350810158142478, 6925910946424990813, 9003764850293445208]},
		{"root": 0, "label": "terrain_gen", "child_seed": 2628886745778239403,
			"draws": [-2183291685244678997, 741353873456682785, -7637842268059572556]},
		{"root": 12345, "label": "world", "child_seed": -4005599522955233094,
			"draws": [-8816358801561845920, -4432292028866122576, -4535899437668111017]},
		{"root": 12345, "label": "terrain_gen", "child_seed": 4523720883151395993,
			"draws": [-7256445238304442820, -2688406660449827970, -6762640387698985681]},
	]
	for c: Dictionary in cases:
		var parent: SplitRng = SplitRng.new(c["root"])
		var child: SplitRng = parent.split(c["label"])
		var got_seed: int = child.get_state()["state"]
		_check(got_seed == c["child_seed"], "split(%d, %s) child seed = %d (expected %d)" %
			[c["root"], c["label"], got_seed, c["child_seed"]])
		var draws: Array = c["draws"]
		for i in draws.size():
			var got: int = child.next_u64()
			_check(got == draws[i], "split(%d, %s) draw %d = %d (expected %d)" %
				[c["root"], c["label"], i, got, draws[i]])


func _test_split_is_deterministic() -> void:
	var a: SplitRng = SplitRng.new(777).split("world")
	var b: SplitRng = SplitRng.new(777).split("world")
	_check(a.next_u64() == b.next_u64(), "split() from the same (seed, label) draws identically")


func _test_split_labels_diverge() -> void:
	var a: SplitRng = SplitRng.new(777).split("world")
	var b: SplitRng = SplitRng.new(777).split("body")
	_check(a.next_u64() != b.next_u64(), "split() from different labels draws differently")


func _test_state_roundtrip() -> void:
	var rng: SplitRng = SplitRng.new(999)
	rng.next_u64()
	rng.next_u64()
	var saved: Dictionary = rng.get_state()
	var expected: int = rng.next_u64()
	var restored: SplitRng = SplitRng.new(0)
	restored.set_state(saved)
	var got: int = restored.next_u64()
	_check(got == expected, "set_state(get_state()) resumes the exact same sequence")


func _test_two_seeds_diverge() -> void:
	var a: SplitRng = SplitRng.new(1)
	var b: SplitRng = SplitRng.new(2)
	_check(a.next_u64() != b.next_u64(), "different seeds draw differently")
