extends "res://tests/test_base.gd"

## `MinerLook` is the miner-sprite port (D0268) from `legacy/scenes/player.gd:664-793`. `sprite_key` is a
## pure function of five primitives, so the whole state table is assertable without building a world, a
## body, or a texture -- which is why it takes loose ints rather than a `Body` in the first place.

func _initialize() -> void:
	_test_the_state_table_matches_legacys_priority_order()
	_test_dig_and_walk_cycle_through_their_frames()
	_test_every_key_the_table_can_emit_resolves_to_a_texture()
	_test_the_fallback_chain_terminates_and_reaches_a_real_file()
	_test_feet_sit_on_the_aabb_bottom()
	_finish("miner_look")


## Legacy's order is digging > airborne > walking > idle, and the order is the assertion: a state that
## satisfies TWO conditions must pick the higher one. Each row below deliberately sets a lower-priority
## condition true as well, so a table that lost its ordering returns the wrong key rather than passing on
## rows that only ever satisfy one branch.
func _test_the_state_table_matches_legacys_priority_order() -> void:
	var fast: int = MinerLook.WALK_SPEED_MIN * 4
	var cases: Array = [
		# digging outranks everything, including being airborne AND moving fast
		{"dig": true, "floor": false, "vx": fast, "vy": 500, "t": 0, "want": "miner_dig_0"},
		# airborne outranks walking: moving fast horizontally while falling is still a fall
		{"dig": false, "floor": false, "vx": fast, "vy": 500, "t": 0, "want": "miner_fall"},
		{"dig": false, "floor": false, "vx": fast, "vy": -500, "t": 0, "want": "miner_jump"},
		# on the floor, speed decides
		{"dig": false, "floor": true, "vx": fast, "vy": 0, "t": 0, "want": "miner_walk_0"},
		{"dig": false, "floor": true, "vx": 0, "vy": 0, "t": 0, "want": "miner_idle"},
		# exactly AT the threshold is idle, not walking -- legacy's test is strictly greater-than
		{"dig": false, "floor": true, "vx": MinerLook.WALK_SPEED_MIN, "vy": 0, "t": 0, "want": "miner_idle"},
		# and direction must not matter: leftward at speed still walks
		{"dig": false, "floor": true, "vx": -fast, "vy": 0, "t": 0, "want": "miner_walk_0"},
	]
	for c: Dictionary in cases:
		var got: String = MinerLook.sprite_key(c["dig"], c["floor"], c["vx"], c["vy"], c["t"])
		_check(got == c["want"],
			"sprite_key(dig=%s, floor=%s, vx=%d, vy=%d, t=%d) = %s (want %s)"
			% [c["dig"], c["floor"], c["vx"], c["vy"], c["t"], got, c["want"]])


## The two cycles must actually CYCLE. A frame index that never advanced would pass every single-tick
## assertion above, so this walks the clock and asserts the set of distinct frames, not one sample.
func _test_dig_and_walk_cycle_through_their_frames() -> void:
	var dig_seen: Dictionary = {}
	var walk_seen: Dictionary = {}
	var ticks: int = MinerLook.WALK_TICKS_PER_FRAME * 4 * 3
	for t: int in ticks:
		dig_seen[MinerLook.sprite_key(true, true, 0, 0, t)] = true
		walk_seen[MinerLook.sprite_key(false, true, MinerLook.WALK_SPEED_MIN * 4, 0, t)] = true
	_check_over(ticks, dig_seen.size() == 2,
		"the dig cycle emits both of its frames over %d ticks (got %d distinct: %s)"
		% [ticks, dig_seen.size(), dig_seen.keys()])
	_check_over(ticks, walk_seen.size() == 4,
		"the walk cycle emits all four of its frames over %d ticks (got %d distinct: %s)"
		% [ticks, walk_seen.size(), walk_seen.keys()])


## THE POPULATION CHECK THAT MATTERS. Enumerating the table by hand would only assert the keys someone
## remembered to list. This drives `sprite_key` across the real state space and resolves whatever it
## actually emits, so a key added to the selector but missing from `assets/sprites/` (or from the fallback
## table) fails here rather than showing up as an invisible miner in a capture nobody screenshots.
func _test_every_key_the_table_can_emit_resolves_to_a_texture() -> void:
	Art.clear_cache()
	var emitted: Dictionary = {}
	var fast: int = MinerLook.WALK_SPEED_MIN * 4
	for t: int in 64:
		for dig: bool in [true, false]:
			for floor_state: bool in [true, false]:
				for vx: int in [0, fast, -fast]:
					for vy: int in [-500, 0, 500]:
						emitted[MinerLook.sprite_key(dig, floor_state, vx, vy, t)] = true
	_check(emitted.size() >= 8,
		"sanity: the sweep actually reached a spread of states (%d distinct keys: %s)"
		% [emitted.size(), emitted.keys()])
	var unresolved: Array[String] = []
	for key: String in emitted:
		if MinerLook.resolve(key) == null:
			unresolved.append(key)
	_check_over(emitted.size(), unresolved.is_empty(),
		"every key the state table can emit resolves to a real texture (%d unresolved: %s)"
		% [unresolved.size(), unresolved])


## `resolve` walks a fallback chain, and a chain is a place a cycle can hide. Asserts termination on a key
## that is NOT in the table at all (must return null, not spin) and that a chained key lands on a file.
func _test_the_fallback_chain_terminates_and_reaches_a_real_file() -> void:
	Art.clear_cache()
	_check(MinerLook.resolve("no_such_sprite_key") == null,
		"a key outside the fallback table resolves to null rather than looping")
	_check(MinerLook.resolve("miner_idle") != null,
		"the chain's own root resolves -- without this the check above passes on a loader that is simply broken")


## Feet on the AABB bottom is the placement claim, and it is checkable arithmetic rather than a look call:
## the rect's bottom edge must land exactly on the body's own half-height, in the body's local space.
func _test_feet_sit_on_the_aabb_bottom() -> void:
	var tex: Texture2D = MinerLook.resolve("miner_idle")
	_check(tex != null, "sanity: an idle texture exists to place")
	if tex == null:
		return
	var r: Rect2 = MinerLook.dest_rect(tex, Body.HEIGHT_PX)
	_check(is_equal_approx(r.position.y + r.size.y, float(Body.HEIGHT_PX) * 0.5),
		"the sprite's bottom edge sits on the AABB bottom (%.2f vs %.2f)"
		% [r.position.y + r.size.y, float(Body.HEIGHT_PX) * 0.5])
	_check(is_equal_approx(r.position.x, -r.size.x * 0.5),
		"and it is horizontally centred on the body (%.2f vs %.2f)" % [r.position.x, -r.size.x * 0.5])
	_check(r.size.y > float(Body.HEIGHT_PX),
		"the art deliberately OVERHANGS the collision box (%.0fpx art against a %dpx body) -- legacy's own "
		% [r.size.y, Body.HEIGHT_PX] + "arrangement, not a scaling bug; a box is not a silhouette")
