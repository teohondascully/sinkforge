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
	var breaks: int = 0
	for _i: int in Mining.ticks_to_break(&"clay") * 4:
		body.tick(InputFrame.new(), grid)
		mining.mine(grid, body.pos_x, body.pos_y, target, true)
		if mining.broke_this_tick:
			breaks += 1
		DebugSceneCommon.step_mining_feedback(particles, mining, look, Heightfield.TERRAIN_CELL_PX, 0.0)
		if breaks > 0:
			break
	_check(breaks > 0, "control: the cell really did break (%d breaks)" % breaks)
	_check(particles.size() > 0,
		"and the break reached the particle layer through the same call the scene makes (%d particles)" %
		particles.size())
