extends "res://tools/check_base.gd"

## DOES THE SCANNER ANSWER IN A COLOUR YOU CAN SEE?
##
## The Scanner had NO harness layer at all before this one — nothing in tools/ referenced `try_scan`,
## `start_scan` or `_scan_dings`. It is the prospecting verb, and after T0.2 phase 3a it is the verb that
## answers the question the lode plane created: *where do I dig?*
##
## THE DEFECT THIS WAS WRITTEN TO CATCH, and it is mine. Phase 3a put ~378 generated lode cells into
## `world.lodes` per world; `FactorySim.load_world` copies their richness into the shared `deposits` grid.
## The sonar walks `sim.deposits` (`main.gd`) and keeps any cell that is SOLID and returns a positive
## `ore_deposit_at` — and `ore_deposit_at` has a `lode.has(cell)` branch (`factory_sim.gd`), so a vein
## buried under stone qualifies. That much is correct and wanted: a scanner that cannot find buried ore is
## not a scanner.
##
## The echo then carries `sim.material_at(cell)` as its material — and `material_at` returns the SOLID
## there, which for a buried lode is `stone`. `stone.tres` sets `nugget_color = Color(0, 0, 0, 0)`, and the
## renderer paints all three parts of the return from that one colour: the ringing arc, the diamond pip
## (`world_renderer.gd`) and the through-rock glow. At alpha 0 the arc, the pip and the glow
## are all nothing. What survives is a hardcoded 1.6px white core (:686) — so the echo is not invisible,
## it is DEGRADED to a dot that neither rings nor names its ore.
##
## The glow is the one that matters and the code says so itself, two lines above it:
##
##     "Sonar echoes GLOW through the darkness veil (#27) — an answer from inside unlit rock must read
##      in the black, or the scanner is useless exactly where prospecting matters."
##
## A buried lode IS the answer from inside unlit rock. The comment states the requirement that the code
## fails for the exact case it was written about.
##
## WHY THIS ASSERTS ON THE ECHO AND NOT ON PIXELS. The renderer's three draws all read one value —
## `_material(e["material"]).nugget_color` — so that value is the whole defect, and reading it needs no
## window, no capture and no differ. A pixel test here would be slower, flakier, and would prove less: it
## could not distinguish "drawn in an invisible colour" from "drawn off-screen" or "not drawn at all".
##
## NON-VACUITY IS THE HALF THAT KEEPS THIS HONEST. Every assertion below passes perfectly on a run where
## the scanner found nothing, so the fixture proves FIRST that there is a buried vein in range and that
## the pulse fired, and it carries a CONTROL — an ordinary solid ore block, which has always answered in
## its own colour. If the control ever goes dark, the layer is measuring the material table rather than
## the scanner and its verdict about the lode means nothing.
##
##   godot --headless --path . --script res://tools/check_scan.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

## Cells from the body to the planted subjects. Well inside SCAN_RANGE_CELLS (14) so a body that drifts a
## little during settle does not put the subject out of range and turn a verdict into an empty sweep.
const NEAR: int = 5

## Richness planted on both subjects. Any positive number qualifies; this one is unmistakable in a log.
const YIELD: int = 7


func _initialize() -> void:
	print("== does the scanner answer in a colour you can see ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_scan", "a buried vein answers in its own ore colour, not in the rock's")


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame

	var sim: FactorySim = main.sim
	var body: Vector2i = main._body_cell()

	# --- plant the two subjects in solid rock beside the body ---
	# BURIED LODE: ore in the background plane with stone still in front of it. This is what a generated
	# world is full of after 3a and it is the case the sonar exists to answer.
	var buried := Vector2i(body.x + NEAR, body.y + 2)
	# CONTROL: an ordinary solid ore BLOCK, the pre-3a shape, which has always answered in its own colour.
	var block := Vector2i(body.x - NEAR, body.y + 2)

	sim.solid[buried] = &"stone"
	sim.lode[buried] = &"ore"
	sim.deposits[buried] = YIELD
	sim.solid[block] = &"ore"
	sim.deposits[block] = YIELD

	# --- the preconditions, so a quiet run cannot read as a clean one ---
	_check(sim.is_solid(buried) and sim.material_at(buried) == &"stone",
		"the buried subject is ore behind STONE, not an exposed face (%s reads '%s')"
			% [buried, sim.material_at(buried)])
	_check(sim.lode_at(buried) == &"ore",
		"...and the lode plane holds ore there ('%s')" % sim.lode_at(buried))
	_check(sim.ore_deposit_at(buried) > 0,
		"...and it reports a positive yield, so the sonar's own filter admits it (%d)"
			% sim.ore_deposit_at(buried))

	sim.inventory[&"scanner"] = 1
	main._scan_cooldown = 0.0
	var fired: bool = main.try_scan()
	_check(fired, "the pulse fired (scanner carried, not paused, off cooldown)")

	var echoes: Array[Dictionary] = main._renderer._scan_echoes
	_check(not echoes.is_empty(), "the pulse returned echoes at all (%d)" % echoes.size())

	# --- the subject, and the control, judged by the ONE value all three draws read ---
	var buried_mat: StringName = _echo_material(echoes, buried)
	var block_mat: StringName = _echo_material(echoes, block)
	_check(buried_mat != &"", "the buried vein came back as an echo — the sonar can see through rock")
	_check(block_mat != &"", "the solid ore block came back as an echo (the CONTROL)")

	var rend: WorldRenderer = main._renderer
	var block_col: Color = rend._material(block_mat).nugget_color
	_check(block_col.a > 0.0,
		"CONTROL: a solid ore block answers in a visible colour (%s, a=%.2f) — the assertion below CAN pass"
			% [block_mat, block_col.a])

	var buried_col: Color = rend._material(buried_mat).nugget_color
	_check(buried_col.a > 0.0,
		"a buried vein answers in a visible colour, so its arc, pip and through-rock glow all draw "
			+ "(material '%s', a=%.2f)" % [buried_mat, buried_col.a])

	# --- the companion property, asserted directly on the sim so it cannot drift back apart ---
	# `ore_deposit_at` and `deposit_material_at` are the amount and the identity of the same yield. The
	# defect above was those two answers coming from different planes, so pin them as one question: over
	# every cell the sonar walks, either both say "there is ore here" or neither does.
	var mismatched: int = 0
	for cell_v: Variant in sim.deposits:
		var c: Vector2i = cell_v
		if (sim.ore_deposit_at(c) > 0) != (sim.deposit_material_at(c) != &""):
			mismatched += 1
	_check(mismatched == 0,
		"amount and identity agree on every one of the %d deposit cells (%d disagreed)"
			% [sim.deposits.size(), mismatched])
	_check(sim.deposits.size() > 0, "...and there were deposit cells to walk (%d)" % sim.deposits.size())

	main.queue_free()
	await physics_frame


## The material an echo carried for `cell`, or &"" if the sonar never returned that cell. Looked up by
## cell rather than by index because the sonar sorts its echoes by true distance.
func _echo_material(echoes: Array[Dictionary], cell: Vector2i) -> StringName:
	for e: Dictionary in echoes:
		if e.get("cell", Vector2i(-9999, -9999)) == cell:
			return e["material"] as StringName
	return &""
