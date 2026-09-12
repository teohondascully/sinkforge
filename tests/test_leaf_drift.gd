extends "res://tests/test_base.gd"

## Queue item 30. `view/fx/leaf_drift.gd` -- the ambient leaf emitter keyed to canopies.
##
## WHAT THE SUITE PINS. The plan half (`shedding_edges`) is asserted as DATA -- which cells a crown
## sheds from -- because a test that only counts particles can pass against an emitter spawning from
## the wrong cells entirely (grass_painter.gd's D0595 header is the post-mortem of exactly that). The
## spawn half pins the cap, the view cull, and that the leaf is the canopy's own green.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_leaf_drift.gd

const GRID_W: int = 80
const GRID_H: int = 60
const FLOOR_ROW: int = 40
const TRUNK_COL: int = 40
const CROWN_TOP: int = 32
const CROWN_BOTTOM: int = 34
const CROWN_HALF: int = 2
const CELL: float = float(Interface.Units.CELL_PX)


func _initialize() -> void:
	_test_the_plan_finds_the_crowns_open_underside()
	_test_spawn_caps_culls_and_colours_the_leaf()
	_test_a_leaf_sways_rather_than_falls_straight()
	_finish("leaf_drift")


## A clay floor with one tree on it, observed whole -- the tree is a wood trunk under a five-cell-wide
## crown, `tree_pass`'s T in miniature.
func _obs(with_tree: bool) -> Interface.Observation:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	if with_tree:
		for row: int in range(CROWN_BOTTOM + 1, FLOOR_ROW):
			grid.set_material(Vector2i(TRUNK_COL, row), &"wood")
		for col: int in range(TRUNK_COL - CROWN_HALF, TRUNK_COL + CROWN_HALF + 1):
			for row: int in range(CROWN_TOP, CROWN_BOTTOM + 1):
				grid.set_material(Vector2i(col, row), &"leaves")
	var body: Body = Body.new(
		Fx.from_int(TRUNK_COL * Heightfield.TERRAIN_CELL_PX),
		Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	var iface: Interface = Interface.new(grid, body, Mining.new())
	return iface.observe(Interface.Envelope.covering(
		Rect2(0.0, 0.0, GRID_W * CELL, GRID_H * CELL), 0))


func _test_the_plan_finds_the_crowns_open_underside() -> void:
	var edges: Array[Vector2i] = LeafDrift.shedding_edges(_obs(true))
	var expected: Array[Vector2i] = []
	for col: int in range(TRUNK_COL - CROWN_HALF, TRUNK_COL + CROWN_HALF + 1):
		expected.append(Vector2i(col, CROWN_BOTTOM))
	_check(edges == expected,
		"the crown's open underside is exactly its bottom row (%s vs %s)" % [edges, expected])
	_check(LeafDrift.shedding_edges(_obs(false)).is_empty(),
		"and bare ground sheds nothing")


func _test_spawn_caps_culls_and_colours_the_leaf() -> void:
	var particles: Particles = Particles.new()
	var view := Rect2(0.0, 0.0, GRID_W * CELL, GRID_H * CELL)
	# A delta at twice the shed period puts every edge's gate over randf's range, so the count is
	# deterministic: exactly the per-frame cap, not "probably some".
	_check(LeafDrift.spawn(_obs(true), particles, view, LeafDrift.SHED_PERIOD * 2.0) ==
		LeafDrift.LEAF_MAX_PER_FRAME,
		"a full-rate frame spawns exactly the cap (%d)" % particles.size())
	var leaf: Dictionary = particles.snapshot()[0]
	_check(float(leaf["pos"].y) >= (CROWN_BOTTOM + 1) * CELL - 1.0 and
		float(leaf["pos"].y) <= (CROWN_BOTTOM + 1) * CELL + 1.0,
		"and the leaf lets go at the underside's own row (y=%s)" % leaf["pos"].y)
	_check(leaf["color"].g > leaf["color"].r and leaf["color"].g > leaf["color"].b,
		"and carries a green, not a rock tone (%s)" % leaf["color"])
	var off_view := Rect2(0.0, 0.0, (TRUNK_COL - CROWN_HALF - 4) * CELL, GRID_H * CELL)
	_check(LeafDrift.spawn(_obs(true), particles, off_view, LeafDrift.SHED_PERIOD * 2.0) == 0,
		"a view that cannot see the tree spawns nothing")
	_check(LeafDrift.spawn(_obs(true), particles, view, 0.0) == 0,
		"and a zero delta spawns nothing -- the rate scales with frame time")


func _test_a_leaf_sways_rather_than_falls_straight() -> void:
	var particles: Particles = Particles.new()
	var view := Rect2(0.0, 0.0, GRID_W * CELL, GRID_H * CELL)
	LeafDrift.spawn(_obs(true), particles, view, LeafDrift.SHED_PERIOD * 2.0)
	_check(particles.snapshot().all(func(q: Dictionary) -> bool: return q.has("sway")),
		"every leaf carries a sway phase")
	# `snapshot()` returns the live array by design (D0304) -- pinning the fields makes the sway term
	# itself the assertion rather than a random phase that could land near zero and flake.
	var leaf: Dictionary = particles.snapshot()[0]
	leaf["vel"] = Vector2.ZERO
	leaf["sway"] = 0.0
	var before: Vector2 = leaf["pos"]
	particles.advance(0.05)
	var moved: Vector2 = leaf["pos"] - before
	_check(moved.y > 0.0, "the leaf is falling on its low gravity (dy=%.3f)" % moved.y)
	var expected_x: float = sin(0.05 * 4.5) * 16.0 * 0.05
	_check(absf(moved.x - expected_x) < 0.01,
		"and its x is the sway term exactly (dx=%.4f vs %.4f)" % [moved.x, expected_x])
