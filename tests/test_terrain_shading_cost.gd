extends "res://tests/test_base.gd"

## Guards wasted work, not elapsed time: clastic/massive rock must not evaluate zero-weight bedding.
## Optional --profile-shading prints repeatable CPU colour samples, not an end-to-end FPS claim.
class CountingTone extends RockTone:
	var lamina_calls: int = 0

	func lamina(x: float, y: float) -> float:
		lamina_calls += 1
		return super.lamina(x, y)


class CountingObservation extends Interface.Observation:
	var material_reads: int = 0

	func material_at(cell: Vector2i) -> StringName:
		material_reads += 1
		return super.material_at(cell)


func _initialize() -> void:
	var tone := CountingTone.new(20260826)
	for gram: int in [RockTone.GRAM_CLASTIC, RockTone.GRAM_MASSIVE]:
		tone.shade(Color(0.3, 0.4, 0.5), 18, 300, gram)
	_check(tone.lamina_calls == 0, "non-bedded materials do not evaluate discarded bedding")
	tone.shade(Color(0.3, 0.4, 0.5), 18, 300, RockTone.GRAM_BEDDED)
	_check(tone.lamina_calls == 1, "bedded material still evaluates its partings")
	_test_solid_probe()
	_test_region_edges()
	if "--profile-shading" in OS.get_cmdline_user_args():
		_profile()
	_finish("terrain_shading_cost")


func _test_solid_probe() -> void:
	var obs := CountingObservation.new()
	obs.window = Rect2i(-2, 9, 3, 2)
	obs.legend = PackedStringArray(["", "hardrock", "clay"])
	obs.materials = PackedByteArray([0, 1, 2, 2, 0, 1])
	var same: bool = true
	var visited: int = 0
	for row: int in range(7, 13):
		for col: int in range(-4, 3):
			same = (obs.solid_at(Vector2i(col, row)) == (obs.material_at(Vector2i(col, row)) != &"")) and same
			visited += 1
	_check_over(visited, same, "byte probe preserves material solidity including negative origin and all borders")
	obs.material_reads = 0
	_check(obs.solid_at(Vector2i(-1, 9)), "a real solid cell is detected")
	_check(obs.material_reads == 0, "solidity does not decode material names")


func _profile() -> void:
	var obs := Interface.Observation.new()
	obs.window = Rect2i(-8, 80, 64, 112)
	obs.legend = PackedStringArray(["", "hardrock"])
	obs.materials.resize(64 * 112)
	obs.materials.fill(1)
	for row: int in range(100, 120):
		for col: int in range(10, 20):
			obs.materials[(row - 80) * 64 + col + 8] = 0
	for region: Rect2i in [Rect2i(0, 90, 32, 80), Rect2i(0, 95, 16, 16), Rect2i(0, 145, 16, 16)]:
		for gram: int in range(3):
			for fast: bool in [false, true]:
				_measure_region(obs, region, gram, fast)


func _measure_region(obs: Interface.Observation, region: Rect2i, gram: int, fast: bool) -> void:
	var solid: Callable = func(c: int, r: int) -> bool: return obs.solid_at(Vector2i(c, r))
	var tone := RockTone.new(20260826)
	var colours := PackedColorArray()
	colours.resize(region.get_area())
	var times: Array[int] = []
	for repeat: int in range(5):
		var began: int = Time.get_ticks_usec()
		var neighbors: RockNeighborhood = RockNeighborhood.new(obs, region) if fast else null
		for row: int in range(region.position.y, region.end.y):
			for col: int in range(region.position.x, region.end.x):
				colours[(row - region.position.y) * region.size.x + col - region.position.x] = tone.shade(Color(0.3, 0.4, 0.5), col, row, gram, solid, neighbors.at(col, row) if fast else -1)
		times.append(Time.get_ticks_usec() - began)
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	hash_ctx.update(colours.to_byte_array())
	print("SHADING region=%s gram=%d fast=%s usec=%s hash=%s" % [region, gram, fast, times, hash_ctx.finish().hex_encode()])


## A missing halo, wrong distance convention or stale region must disagree with the original probes.
func _test_region_edges() -> void:
	var obs := Interface.Observation.new()
	obs.window = Rect2i(-9, 90, 35, 31)
	obs.legend = PackedStringArray(["", "hardrock"])
	obs.materials.resize(obs.window.get_area())
	var tone := RockTone.new(17)
	var solid: Callable = func(c: int, r: int) -> bool: return obs.solid_at(Vector2i(c, r))
	var region := Rect2i(-11, 88, 39, 35)
	var checked: int = 0
	var equal: bool = true
	for pattern: int in range(4):
		for i: int in obs.materials.size():
			obs.materials[i] = 1 if pattern == 0 or (pattern != 1 and (i * 13 + i / 35) % (pattern + 3) != 0) else 0
		var neighborhood := RockNeighborhood.new(obs, region)
		var interior := RockNeighborhood.new(obs, Rect2i(0, 100, 4, 4))
		for grammar: int in range(3):
			var base := Color(0.3, 0.4, 0.5)
			equal = (tone.shade(base, 1, 101, grammar, solid) == tone.shade(base, 1, 101, grammar, solid, interior.at(1, 101))) and equal
			checked += 1
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				for grammar: int in range(3):
					var base := Color(0.3, 0.4, 0.5)
					var expected: Color = tone.shade(base, x, y, grammar, solid)
					var actual: Color = tone.shade(base, x, y, grammar, solid, neighborhood.at(x, y))
					equal = (expected == actual) and equal
					checked += 1
	_check_over(checked, equal, "region shading is float-colour identical across solid, air, cuts and observation borders")
