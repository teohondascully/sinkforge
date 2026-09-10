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
	_test_a_wider_span_answers_identically_for_the_cells_it_contains()
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


## THE PREMISE OF SHARING ONE NEIGHBOURHOOD ACROSS A DIG RECT'S PIECES (D0549). `plan_tick` cuts one dig
## rect along chunk boundaries and each piece builds its own `RockNeighborhood` over its own dilated span,
## so ~50% of the dilated work is halo computed twice. Sharing one is only worth proposing if a WIDER span
## answers exactly what a narrower one does for the cells they share.
##
## It is not obvious that it does. `_scan` starts its distance at 7 at the SPAN'S OWN EDGE and walks, so a
## span that starts further away carries a different history into the same cell. What rescues it is that
## the distance is capped at 7 and the halo is exactly `FORM_REACH` (6): a piece's topmost row is 6 rows
## from its own span edge, so its distance is already the cap, and a wider span walking the same rows
## reaches the cap too. This asserts that rather than trusting the argument -- if `FORM_REACH` and the cap
## ever stop matching, this goes red and the sharing treatment must not ship.
func _test_a_wider_span_answers_identically_for_the_cells_it_contains() -> void:
	var obs := Interface.Observation.new()
	obs.window = Rect2i(-9, 90, 35, 31)
	obs.legend = PackedStringArray(["", "hardrock"])
	obs.materials.resize(obs.window.get_area())
	var tone := RockTone.new(17)
	var solid: Callable = func(c: int, r: int) -> bool: return obs.solid_at(Vector2i(c, r))
	var piece := Rect2i(2, 100, 6, 5)          # one chunk-sized partial
	var union := Rect2i(-4, 94, 26, 22)        # the whole tick's dig rect, containing it
	var checked: int = 0
	var equal: bool = true
	for pattern: int in range(5):
		for i: int in obs.materials.size():
			obs.materials[i] = 1 if pattern == 0 or (pattern != 1 and (i * 13 + i / 35) % (pattern + 2) != 0) else 0
		var narrow := RockNeighborhood.new(obs, piece)
		var wide := RockNeighborhood.new(obs, union)
		for y: int in range(piece.position.y, piece.end.y):
			for x: int in range(piece.position.x, piece.end.x):
				# NARROW == WIDE is not enough on its own: both could be wrong the same way. The wide one
				# is also held against the REFERENCE probe path, which reads the observation directly and
				# is the ground truth `_test_region_edges` above uses.
				equal = (narrow.at(x, y) == wide.at(x, y)) and equal
				for grammar: int in range(3):
					var base := Color(0.3, 0.4, 0.5)
					equal = (tone.shade(base, x, y, grammar, solid)
						== tone.shade(base, x, y, grammar, solid, wide.at(x, y))) and equal
					checked += 1
				checked += 1
	_check_over(checked, equal,
		"a neighbourhood over the whole dig rect answers the same code as one over a single piece, "
		+ "and matches the direct probe for those cells")
