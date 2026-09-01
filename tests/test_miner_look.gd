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
	_test_dug_headroom_covers_the_sprites_overhang()
	_test_the_struck_frame_shows_on_the_tick_the_rock_takes_damage()
	_test_the_free_running_fallback_is_the_at_rest_swing_by_construction()
	_test_a_shorter_swing_makes_the_pick_swing_faster()
	_finish("miner_look")


## D0287. The pick's two frames are `dig_up` and `dig_down` (`legacy/tools/bake_miner.gd:448-449`), and
## the whole point of phase-locking them is that `dig_down` is on screen on the tick the rock actually
## takes damage. Phase 0 IS that tick — `Mining` zeroes its swing counter as it fires.
func _test_the_struck_frame_shows_on_the_tick_the_rock_takes_damage() -> void:
	_check(MinerLook.dig_key(0, 0) == "miner_dig_1",
		"at phase 0, the tick the blow lands, the pick is DOWN (got %s)" % MinerLook.dig_key(0, 0))
	_check(MinerLook.dig_key(999, 0) == "miner_dig_0",
		"and at the top of the wind-up it is UP (got %s)" % MinerLook.dig_key(999, 0))
	# Both frames over the whole range, and each covering half of it. A mapping that returned one frame
	# everywhere would satisfy either row above on its own.
	var struck: int = 0
	for p: int in range(0, 1001):
		if MinerLook.dig_key(p, 0) == "miner_dig_1":
			struck += 1
	_check_over(1001, absi(struck - 500) <= 1,
		"and the stroke is split evenly -- %d of 1001 phases show the struck frame" % struck)
	# The sentinel is not a phase. Passing it must reach legacy's clock, not be read as "just struck".
	_check(MinerLook.dig_key(MinerLook.SWING_PHASE_NONE, 0)
			!= MinerLook.dig_key(MinerLook.SWING_PHASE_NONE, MinerLook.DIG_TICKS_PER_FRAME),
		"CONTROL: with no swing to read, the frames still alternate on the clock -- the sentinel falls "
		+ "back rather than freezing on one frame")


## CONSTANT MUST DOMINATE CONSTANT. Legacy's free-running 8 Hz alternation is not arbitrary: it is a
## half-cycle of 0.125 s against its own 0.28 s swing. Ported here, `DIG_TICKS_PER_FRAME * 2` must equal
## the at-rest period `Mining` computes, or the fallback path and the phase-locked path draw two different
## cadences from the same rest state. Read off a real `Mining` rather than written down, so moving
## `SWING_TICKS_X100` fails here instead of silently desynchronising the animation.
func _test_the_free_running_fallback_is_the_at_rest_swing_by_construction() -> void:
	var at_rest: int = Mining.new().swing_period_ticks()
	_check(MinerLook.DIG_TICKS_PER_FRAME * 2 == at_rest,
		"the fallback's full cycle (%d ticks) is the at-rest swing period (%d)"
		% [MinerLook.DIG_TICKS_PER_FRAME * 2, at_rest])
	# And the two paths really do agree over a run, not merely in their arithmetic.
	var disagreements: int = 0
	for t: int in at_rest * 4:
		var phase: int = ((t % at_rest) * 1000) / at_rest
		# The clock's cycle starts on the UP frame and the swing's starts on the DOWN one -- the blow
		# lands at phase 0 -- so the clock is compared half a period out of step, which is what the two
		# being the same cadence means.
		if MinerLook.dig_key(phase, 0) != MinerLook.dig_key(MinerLook.SWING_PHASE_NONE,
				t + MinerLook.DIG_TICKS_PER_FRAME):
			disagreements += 1
	_check_over(at_rest * 4, disagreements == 0,
		"and the phase-locked and free-running frames match tick for tick at rest (%d differ)"
		% disagreements)


## THE PAYOFF, AND THE REASON THIS IS NOT A CLOCK. `Mining`'s period shortens as rhythm builds (D0279,
## asserted against real breaks in `tests/test_mining.gd`); legacy's animation could not follow, because
## nothing told it. Asserted as a property over a range of periods rather than at two measured values, so
## it is a claim about the mapping and not about the two numbers D0279 happened to measure.
func _test_a_shorter_swing_makes_the_pick_swing_faster() -> void:
	var window: int = 240
	var last_flips: int = -1
	var readings: Array[int] = []
	for period: int in [Mining.new().swing_period_ticks(), 14, 12, 10]:
		var flips: int = 0
		var previous: String = ""
		for t: int in window:
			var key: String = MinerLook.dig_key(((t % period) * 1000) / period, t)
			if previous != "" and key != previous:
				flips += 1
			previous = key
		readings.append(flips)
		_check(flips > last_flips,
			"a %d-tick swing flips the pick more often over %d ticks than the longer one before it "
			% [period, window] + "(%d vs %d)" % [flips, last_flips])
		last_flips = flips
	_check(readings[0] > 0,
		"CONTROL: the at-rest swing flips at all (%d over %d ticks) -- a mapping that never changed frame "
		% [readings[0], window] + "would make every row above vacuously ordered at zero")


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


## THE ONE ASSERTION THAT TIES THE TWO HALVES OF P022 TOGETHER, and the reason it lives in this suite
## rather than in `tests/test_body_dig.gd`: it is the only place that can see both numbers at once.
##
## Two constants in different layers must be ORDERED against each other. `Heightfield.DIG_HEADROOM_CELLS`
## decides how much rock a dig clears above the head; the authored PNG's height decides how far the art
## rises above the collision box. Neither file may reference the other -- `sim/` must not know what
## `view/` draws -- so nothing in the shipping code can hold them in the same expression, and each looks
## individually reasonable while the pair is wrong. That is exactly how P022 shipped: `0` headroom
## against `8px` of overhang, and the miner's helmet spent every frame inside the ceiling.
##
## Derived, not restated. The overhang is READ from the texture rather than written as `8`, so re-baking
## the art to a different height fails here instead of silently re-opening the bug. `>=`, not `==`: extra
## clearance is a look decision, too little is a defect.
func _test_dug_headroom_covers_the_sprites_overhang() -> void:
	var tex: Texture2D = MinerLook.resolve("miner_idle")
	_check(tex != null, "sanity: a texture exists to measure -- without this the comparison below is vacuous")
	if tex == null:
		return
	var overhang_px: int = tex.get_height() - Body.HEIGHT_PX
	var carved_px: int = Heightfield.DIG_HEADROOM_CELLS * Heightfield.TERRAIN_CELL_PX
	_check(overhang_px > 0,
		"sanity: the art really does overhang the box (%dpx art, %dpx body) -- if it did not, the check "
		% [tex.get_height(), Body.HEIGHT_PX] + "below would pass on any headroom at all, including none")
	_check(carved_px >= overhang_px,
		"a dug tunnel clears the sprite's overhang: %d cells x %dpx = %dpx carved, against %dpx of art "
		% [Heightfield.DIG_HEADROOM_CELLS, Heightfield.TERRAIN_CELL_PX, carved_px, overhang_px]
		+ "above the collision box")
