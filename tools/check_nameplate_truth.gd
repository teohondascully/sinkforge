extends "res://tools/check_base.gd"

## A NAMEPLATE'S COUNT IS A CLAIM ABOUT THE FACTORY, NOT ABOUT WHERE YOU ARE STANDING.
##
## A row of identical machines collapses to one plate carrying `×N`. That number was measured over the
## wrong population: `_plan_machine_labels` filtered its `named` dictionary through `mview` and
## `_label_visible` BEFORE taking the run length, and `_label_visible` is a radius around the PLAYER. So
## the count described the machines near the body and was printed as the machines in the run. Three
## generators read `GENERATOR ×2` from one step too far back, with the third drawn, lit and plainly on
## screen beside the plate undercounting it, and walking two cells changed the number while nothing in the
## world changed.
##
## The straddling case was worse than a wrong number and is the one this layer exists for. A run whose
## MIDDLE machine falls outside the radius breaks the westward continuity test that decides who owns a
## plate, so one run of three publishes TWO plates, each reading `GENERATOR`, neither carrying a count.
## The run is not miscounted there; it is reported as two runs.
##
## WHY NOTHING CAUGHT IT. No layer in this suite reads a nameplate. `check_machine_identity` is the one
## that sounds like it should and it is explicitly the opposite: its whole subject is whether a SILHOUETTE
## carries identity, and it excludes the label channel by design, because the ticket it serves is about
## the name not being how you know what a thing is. A layer that excluded the label cannot be the layer
## that checks the label.
##
## THE EXPERIMENT, AND WHY THE CAMERA DELIBERATELY DOES NOT MOVE. The plan is read twice from ONE posed
## world. Between the readings the body is teleported away from the run and `_plan_machine_labels` is
## called again immediately, with no frame awaited in between — so the camera has not followed, the view
## rectangle is identical to the byte, and `_label_visible`'s distance test is the only input that has
## changed. Moving the camera as well would have measured two different views and left it open which of
## the two inputs moved the number. This is the control travelling inside the measurement: same world,
## same machines, same frame, one observer moved.
##
## Needs no display and no pixels. `_plan_machine_labels` is arithmetic over the sim and a font metric, so
## it runs correctly under the dummy renderer and this is a plain `add`.

const MACHINE_DIR: String = "res://src/data/machines"
## Long enough that a straddling body can put part of the run inside `LABEL_NEAR_CELLS` and part outside.
## Three is also the smallest run for which the split case exists at all: a run of two cannot have a middle.
const RUN_LEN: int = 3
## Where the body is teleported for the far reading, in cells left of the run's western end. Derived from
## the radius it has to defeat rather than chosen: `LABEL_NEAR_CELLS` is 6.4 cells, so standing this far
## west puts the run's east end past it while its west end stays inside, which is the straddle.
const FAR_WEST_CELLS: int = 5


func _initialize() -> void:
	print("== nameplates: the count is about the factory ==")
	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 8:
		await physics_frame

	var sim: FactorySim = main.sim
	var wr: WorldRenderer = main._renderer
	if sim == null or wr == null:
		_check(false, "the scene came up with a sim and a renderer to read")
		_verdict("check_nameplate_truth")
		return

	var def: MachineDef = _a_named_def()
	if def == null:
		_verdict("check_nameplate_truth")
		return

	# The run is laid beside the body, in cells cleared first because `cell_occupied` refuses solid ones.
	var home: Vector2i = main._cell_at(main._player.position)
	var row: int = home.y
	var x0: int = home.x + 2
	var placed: Array[Vector2i] = []
	for k: int in RUN_LEN:
		var c := Vector2i(x0 + k, row)
		sim.solid.erase(c)
		if sim.place_machine(def, c) != null:
			placed.append(c)
	# A SECOND RUN, of one, separated by a gap. Without it every assertion below could be satisfied by a
	# planner that emits exactly one plate for the whole world, which is a different bug wearing this one's
	# green. The lone machine is also the only case that must print no count at all.
	var lone := Vector2i(x0 + RUN_LEN + 2, row)
	sim.solid.erase(lone)
	var lone_ok: bool = sim.place_machine(def, lone) != null

	_check(placed.size() == RUN_LEN and lone_ok,
		"the fixture stood %d machines in a run and %d alone (a plan over nothing proves nothing)"
			% [placed.size(), 1 if lone_ok else 0])
	if placed.size() != RUN_LEN or not lone_ok:
		_verdict("check_nameplate_truth")
		return

	# --- reading one: the body beside the run, every machine inside the radius ---
	main._player.position = main._cell_center(Vector2i(x0, row))
	var view: Rect2 = wr._view_world_rect()
	wr._plan_machine_labels(view)
	var near_plan: Dictionary = _snapshot(wr)

	# --- reading two: the body walked west, the run now straddling the radius ---
	main._player.position = main._cell_center(Vector2i(x0 - FAR_WEST_CELLS, row))
	var far_view: Rect2 = wr._view_world_rect()
	wr._plan_machine_labels(far_view)
	var far_plan: Dictionary = _snapshot(wr)

	# THE TREATMENT HAS TO HAVE BEEN APPLIED. Every assertion after this compares two readings and they are
	# all satisfied by two readings taken under identical conditions — which is exactly what happens if the
	# teleport did not move the body far enough to put any machine outside the radius. Assert the straddle
	# exists before asserting anything about it.
	var reach: float = WorldRenderer.LABEL_NEAR_CELLS * float(WorldRenderer.CELL)
	var outside: int = 0
	for c: Vector2i in placed:
		if main._cell_center(c).distance_to(main._player.position) > reach:
			outside += 1
	_check(outside > 0 and outside < RUN_LEN,
		"the far reading actually straddles the label radius (%d of %d machines outside it)"
			% [outside, RUN_LEN])
	_check(is_equal_approx(view.size.x, far_view.size.x) and is_equal_approx(view.position.x, far_view.position.x),
		"both readings were taken through the same view, so distance is the only variable")

	# --- the claims, checked against runs re-derived from the sim ---
	# NOT against an expected multiset of counts. The first version of this layer asserted the plan read
	# exactly `[1, 3]` and it failed on its own fixture, because the opening world already stands a Forge
	# near spawn and that is a named machine and a run of one. The expectation was a statement about a world
	# this layer had invented rather than about the world it was standing in. Walking the sim costs nothing
	# and cannot be wrong about what is there.
	_check(near_plan.size() > 0 and far_plan.size() > 0,
		"both readings produced plates (%d near, %d far)" % [near_plan.size(), far_plan.size()])

	for label: String in ["standing beside them", "from %d cells west" % FAR_WEST_CELLS]:
		var plan: Dictionary = near_plan if label.begins_with("standing") else far_plan
		var wrong: Array[String] = []
		var owners: Dictionary = {}
		var doubled: Array[String] = []
		for key: Variant in plan:
			var cell: Vector2i = key
			var claimed: int = int(plan[cell])
			var run: Vector2i = _run_at(sim, cell)          # x = the run's west end, y = its true length
			if run.y != claimed:
				wrong.append("%s claims %d, the run is %d" % [cell, claimed, run.y])
			var id: String = "%d:%d:%s" % [run.x, cell.y, _name_at(sim, cell)]
			if owners.has(id):
				doubled.append(id)
			owners[id] = true
		_check(wrong.is_empty(),
			"%s, every plate counts its whole run%s" % [label, "" if wrong.is_empty() else " — " + ", ".join(wrong)])
		_check(doubled.is_empty(),
			"%s, one run publishes one plate%s" % [label, "" if doubled.is_empty() else " — " + ", ".join(doubled)])

	# NON-VACUITY, and it is the assertion that matters most here. Every check above is satisfied by a plan
	# in which every plate reads 1, because a run of one is trivially counted correctly — and a plan of all
	# ones is exactly what the defect produced when it split a run. The posed run has to be found, collapsed,
	# and counted, in BOTH readings, or the run above proved nothing.
	var posed := Vector2i(x0, row)
	_check(_claim_for(near_plan, sim, posed) == RUN_LEN,
		"the posed run of %d is collapsed and counted from beside it (read %d)"
			% [RUN_LEN, _claim_for(near_plan, sim, posed)])
	_check(_claim_for(far_plan, sim, posed) == RUN_LEN,
		"...and still reads %d from %d cells west, where part of it is outside the label radius (read %d) "
			% [RUN_LEN, FAR_WEST_CELLS, _claim_for(far_plan, sim, posed)]
			+ "— this is the assertion the defect failed")

	main.queue_free()
	await physics_frame
	_verdict("check_nameplate_truth", "a plate counts its run, not the machines you happen to be near")


## Cell -> the count its plate claims. `×N` is parsed back out of the drawn string rather than read off a
## field, because the string is what a player sees and a field agreeing with itself proves nothing about it.
func _snapshot(wr: WorldRenderer) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in wr._label_plan:
		var cell: Vector2i = key
		var text: String = String(wr._label_plan[cell]["text"])
		var n: int = 1
		var at: int = text.rfind(" ×")
		if at >= 0:
			n = text.substr(at + 2).to_int()
		out[cell] = n
	return out


func _counts(plan: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for key: Variant in plan:
		out.append(int(plan[key]))
	return out


## Any machine carrying a display name will do — the property under test is about runs, not about which
## machine. Named rather than assumed: a def with an empty name is skipped by the planner entirely, so
## picking one blind would produce an empty plan and a green run over nothing.
func _a_named_def() -> MachineDef:
	var d: DirAccess = DirAccess.open(MACHINE_DIR)
	if d == null:
		_check(false, "the machine registry directory opens")
		return null
	var files: PackedStringArray = d.get_files()
	files.sort()
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var def: MachineDef = load("%s/%s" % [MACHINE_DIR, f]) as MachineDef
		if def != null and not def.display_name.is_empty():
			print("  the run is built from %s" % def.display_name)
			return def
	_check(false, "the registry holds at least one machine with a display name")
	return null


## The run containing a cell, walked over the sim and consulting nothing the renderer computed: x is the
## run's west end, y is its true length. This is the independent answer the plate is judged against, and it
## has to stay independent — deriving it from `_label_plan` would produce a layer that agrees with the thing
## it is testing no matter what either of them says.
func _run_at(sim: FactorySim, cell: Vector2i) -> Vector2i:
	var nm: String = _name_at(sim, cell)
	if nm.is_empty():
		return Vector2i(cell.x, 0)
	var x0: int = cell.x
	while _name_at(sim, Vector2i(x0 - 1, cell.y)) == nm:
		x0 -= 1
	var n: int = 1
	while _name_at(sim, Vector2i(x0 + n, cell.y)) == nm:
		n += 1
	return Vector2i(x0, n)


func _name_at(sim: FactorySim, c: Vector2i) -> String:
	if not sim.grid.has(c):
		return ""
	var m: MachineState = sim.grid[c]
	if m == null or m.def == null or m.def.display_name.is_empty():
		return ""
	return String(m.def.display_name).to_upper()


## What the plan claims about the run containing `cell`, whichever machine of that run happens to own the
## plate. Returns 0 when the run has no plate at all, which is a distinct failure from claiming the wrong
## number and must not be allowed to read as one.
func _claim_for(plan: Dictionary, sim: FactorySim, cell: Vector2i) -> int:
	var want: Vector2i = _run_at(sim, cell)
	for key: Variant in plan:
		var c: Vector2i = key
		if c.y != cell.y:
			continue
		if _run_at(sim, c) == want:
			return int(plan[c])
	return 0
