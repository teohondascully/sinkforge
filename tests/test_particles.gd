extends "res://tests/test_base.gd"

## D0216. `view/fx/particles.gd`, lifted unchanged. Its own header makes one claim that is a LAYER claim
## rather than a behaviour claim -- "it never touches the sim, so randf() is safe here" -- and that is
## the claim worth a test, because it is the one that would be expensive and silent to get wrong. A
## `view/` file drawing from the same random stream the sim draws from would make every replay diverge by
## an amount that depends on how many particles happened to be on screen.
##
## The other two checks are the cap and the retirement, which together are what stop a cosmetic layer
## becoming an unbounded allocation in a session that runs for an hour.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_particles.gd

const FLOOR_ROW: int = 40  ## deep enough that the control run's jump has real headroom: the body's apex is
## ~71px and it is 40px tall, so a shallower floor puts its head through the top of the world
const GRID_W: int = 80  ## wide enough that the oscillating drive below never reaches a wall --
## a bounds clamp would be real sim work triggered by the test's own fixture, not by its subject
const GRID_H: int = 60
const TICKS: int = 400


func _initialize() -> void:
	_test_the_cap_actually_caps()
	_test_particles_retire_and_the_layer_empties()
	_test_a_busy_particle_layer_cannot_move_the_sim()
	_test_a_real_break_actually_reaches_the_particle_layer()
	_test_the_draught_warns_during_the_charge_not_after_the_break()
	_finish("particles")


func _test_the_cap_actually_caps() -> void:
	var p: Particles = Particles.new()
	for _i: int in 40:
		p.dust(Vector2(10.0, 10.0), Color.WHITE, 100)
	_check(p.size() == Particles.MAX,
		"4,000 particles requested, %d held (cap is %d)" % [p.size(), Particles.MAX])


## `advance` is what retires them, so the cap alone is not enough: a layer that capped but never expired
## would sit permanently full and every later burst would be silently dropped. The intermediate check is
## the one that distinguishes those two worlds.
func _test_particles_retire_and_the_layer_empties() -> void:
	var p: Particles = Particles.new()
	p.dust(Vector2(10.0, 10.0), Color.WHITE, 50)
	var spawned: int = p.size()
	_check(spawned > 0, "control: the burst actually spawned something (%d)" % spawned)
	p.advance(0.1)
	_check(p.size() == spawned, "still alive a tenth of a second in (%d)" % p.size())
	for _i: int in 20:
		p.advance(0.1)
	_check(p.size() == 0, "and all of them are retired two seconds later (%d left)" % p.size())


## THE LAYER BOUNDARY, tested rather than asserted in prose. Two identical sims, one of them driven with
## a particle layer thrashing `randf()` between every tick. If anything in `sim/` ever drew from the
## global random stream -- which `tools/layer_lint/no_engine_imports.py` bans by name in `core/` and
## `sim/`, and which this test is the behavioural half of -- the two signatures would part company.
##
## The particle work is deliberately heavy and irregular (a burst whose count depends on the tick) so a
## divergence would compound rather than cancel, and the control below proves the comparison can fail at
## all: the same sim run with one different input tick does produce a different signature.
func _test_a_busy_particle_layer_cannot_move_the_sim() -> void:
	var quiet: String = _run(false)
	var busy: String = _run(true)
	_check(quiet == busy,
		"400 ticks with a particle layer thrashing randf() every tick end byte-identical to 400 without")
	_check(_run(false, 200) != quiet,
		"control: this comparison CAN fail -- changing one input tick changes the signature")


func _run(with_particles: bool, jump_at: int = -1) -> String:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(
		Fx.from_int(GRID_W * Heightfield.TERRAIN_CELL_PX / 2),
		Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	var p: Particles = Particles.new()
	for t: int in TICKS:
		var input: InputFrame = InputFrame.new()
		input.move_dir = 1 if (t / 30) % 2 == 0 else -1
		input.jump_pressed = t == jump_at
		body.tick(input, grid)
		if with_particles:
			p.dust(Vector2(float(t), 4.0), Color.WHITE, 1 + t % 7)
			p.chip(Vector2(float(t), 8.0), Color.RED, float(t) * 0.01)
			p.advance(1.0 / float(Body.TICK_HZ))
	return body.state_signature() + "||" + grid.state_signature()


## D0216's wiring, end to end. The three checks above prove the emitter works; this proves the PATH does
## -- that `sim/mining`'s own break flags reach `DebugSceneCommon.step_mining_feedback` and come out as
## particles. Without it the scene could be wired to a flag that never fires and every unit check would
## still be green, which is this project's own recurring failure rather than a hypothetical.
func _test_a_real_break_actually_reaches_the_particle_layer() -> void:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(
		Fx.from_int(GRID_W * Heightfield.TERRAIN_CELL_PX / 2),
		Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	var mining: Mining = Mining.new()
	var particles: Particles = Particles.new()
	var look: MaterialLook = MaterialLook.new()
	var target: Vector2i = Vector2i(Body._px_to_cell(body.pos_x), FLOOR_ROW)
	# The draught half of the feedback reads the OBSERVATION now (D0293), so this drives the real door
	# rather than a hand-built one -- the same argument D0275 and D0287 make for their own consumers.
	var iface: Interface = Interface.new(grid, body, mining)
	var breaks: int = 0
	for _i: int in Mining.ticks_to_break(&"clay") * 4:
		body.tick(InputFrame.new(), grid)
		mining.mine(grid, body.pos_x, body.pos_y, target, true)
		if mining.broke_this_tick:
			breaks += 1
		var obs: Interface.Observation = iface.observe(
			Interface.Envelope.covering(Rect2(0.0, 0.0, float(GRID_W * Heightfield.TERRAIN_CELL_PX),
			float(GRID_H * Heightfield.TERRAIN_CELL_PX)), 0))
		DebugSceneCommon.step_mining_feedback(particles, mining, obs, look,
			Heightfield.TERRAIN_CELL_PX, 0.0)
		if breaks > 0:
			break
	_check(breaks > 0, "control: the cell really did break (%d breaks)" % breaks)
	_check(particles.size() > 0,
		"and the break reached the particle layer through the same call the scene makes (%d particles)" %
		particles.size())


## D0293. `docs/LEGACY_GAP.md` T1 #6 called the old draught "lifted and MIS-WIRED", and it was wrong four
## ways at once — each of which reads as a plausible cue on its own, which is why none of them was caught
## by looking at the screen. Every one of the four is a row here.
##
## Asserted against `draught_plan`, which returns the decision as data: `Particles` reports only its own
## size, so a test written against the emitter could tell that SOMETHING was emitted and nothing about
## where it went, which way it drifted, or how much of it there was.
func _test_the_draught_warns_during_the_charge_not_after_the_break() -> void:
	var cell := Vector2i(10, 20)
	var cp: int = Heightfield.TERRAIN_CELL_PX
	# (1) IT FIRES DURING THE CHARGE. The old wiring fired on `breach`, after the rock broke -- telling
	# the player something they had just found out for themselves. The cue is a WARNING or it is nothing.
	var charging: Interface.Observation = _hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_FULL / 2, true)
	_check(not DebugSceneCommon.draught_plan(charging, cp).is_empty(),
		"a swing into a hollow face during the charge produces a draught")
	var broken: Interface.Observation = _hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_FULL / 2, true)
	broken.mining_is_charging = false
	broken.mining_broke = true
	broken.mining_breach = true
	_check(DebugSceneCommon.draught_plan(broken, cp).is_empty(),
		"and the tick the rock BREAKS produces none -- the old wiring fired only here")
	# (2) THE DIRECTION IS THE SWING'S, not hardcoded down.
	var right: Dictionary = DebugSceneCommon.draught_plan(charging, cp)
	var up: Dictionary = DebugSceneCommon.draught_plan(
		_hollow_obs(cell, Vector2i(0, -1), Interface.HOLLOW_FULL / 2, true), cp)
	_check(right["dir"] == Vector2(1, 0) and up["dir"] == Vector2(0, -1),
		"the drift follows the swing direction (%s, %s), and is not hardcoded down"
		% [right["dir"], up["dir"]])
	# (3) IT SITS ON THE NEAR FACE, offset BACK along the swing from the cell's centre. A puff on the
	# cell's own centre reads as dust coming out of the rock; this has to read as air drawn INTO it.
	var centre: Vector2 = Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) * float(cp)
	_check((right["at"] as Vector2).x < centre.x and is_equal_approx((right["at"] as Vector2).y, centre.y),
		"a rightward swing places the puff LEFT of the cell's centre -- on the face being hit (%s vs %s)"
		% [right["at"], centre])
	_check((up["at"] as Vector2).y > centre.y,
		"and an upward swing places it BELOW the centre (%s)" % up["at"])
	_check((right["at"] as Vector2).distance_to(centre) < float(cp),
		"and within the cell it belongs to (%.2f px of %d)" % [(right["at"] as Vector2).distance_to(centre), cp])
	# (4) THE AMOUNT RIDES THE READING. `sim/mining/mining.gd` quotes legacy on exactly this: "closing on
	# a cavity is a crescendo you can act on rather than a flag that flips". A fixed 6 IS the flag.
	var faint: Dictionary = DebugSceneCommon.draught_plan(
		_hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_RING, true), cp)
	var loud: Dictionary = DebugSceneCommon.draught_plan(
		_hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_FULL, true), cp)
	_check(int(loud["amount"]) > int(faint["amount"]),
		"a nearly-open face throws more dust than a barely-hollow one (%d vs %d)"
		% [loud["amount"], faint["amount"]])
	_check(int(faint["amount"]) > 0, "and the faintest audible reading still shows something (%d)"
		% faint["amount"])
	# The threshold itself, and the tick gate. Both are absences, so both need the positive control above.
	_check(DebugSceneCommon.draught_plan(
		_hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_RING - 1, true), cp).is_empty(),
		"below the ring threshold there is no cue at all")
	_check(DebugSceneCommon.draught_plan(
		_hollow_obs(cell, Vector2i(1, 0), Interface.HOLLOW_FULL, false), cp).is_empty(),
		"and on a charging tick that is NOT the swing there is none either -- per blow, not per tick, or "
		+ "it is sixty a second")
	_check(DebugSceneCommon.draught_plan(null, cp).is_empty()
			and DebugSceneCommon.draught_plan(charging, 0).is_empty(),
		"and neither a missing observation nor a missing cell size produces a puff at the origin")


## An observation posing one charging swing at `cell`, hollow `reading`, swinging along `dir`.
func _hollow_obs(cell: Vector2i, dir: Vector2i, reading: int, swinging: bool) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.mining_is_charging = true
	o.mining_charging_cell = cell
	o.mining_swing_dir = dir
	o.mining_hollow = reading
	o.mining_swing = swinging
	return o
