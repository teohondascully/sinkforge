extends SceneTree

## P028's cheap resolution: is the shelf carve rate genuinely above zero, or is `shelf_frac > 0.0`
## sampling a noise floor? `tests/test_carve_fraction.gd` asks this over SIX seeds and gets 6 cells in
## 92,160. This asks it over two hundred.

const SEEDS: int = 200


func _initialize() -> void:
	var cave: Dictionary = StrataData.SHALLOW_CLAY["cave"]
	var shelf: Dictionary = StrataData.SHALLOW_CLAY["strata_shelf"]
	var seeds: Array = []
	for i: int in SEEDS:
		seeds.append(1 + i)
	var m: Dictionary = TestCarveProbe.measure(seeds, cave, shelf)
	var se: int = int(m["shelf_eligible"])
	var sc: int = int(m["shelf_carved"])
	var oe: int = int(m["open_eligible"])
	var oc: int = int(m["open_carved"])
	print("SHELF_RATE seeds=%d shelf_carved=%d shelf_eligible=%d rate=%.8f" % [SEEDS, sc, se, float(sc) / float(maxi(1, se))])
	print("SHELF_RATE open_carved=%d open_eligible=%d rate=%.8f" % [oc, oe, float(oc) / float(maxi(1, oe))])
	print("SHELF_RATE ratio_shelf_to_open=%.6f" % (float(sc) / float(maxi(1, se)) / maxf(0.000001, float(oc) / float(maxi(1, oe)))))
	print("SHELF_RATE seeds_with_any_shelf_carve=%d of %d" % [int(m["seeds_hit"]), SEEDS])
	quit(0)
