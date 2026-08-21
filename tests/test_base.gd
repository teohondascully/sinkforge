extends SceneTree

## Shared base for the Sinkforge headless test suites (tests/test_*.gd). Holds the failure counter,
## the sim fixture, and the assertion + canonicalization helpers every suite uses. Each suite EXTENDS
## this, runs its _test_* methods from its own _initialize(), then calls _finish() to print the tally
## and exit. The node-free sim is testable with no scene tree, which is the whole point of the
## architecture.
##
## Suites extend this by PATH (`extends "res://tests/test_base.gd"`) rather than by class_name, so
## they load under a bare `--script` run without depending on a current global class cache.
##
## Run a suite: godot --headless --path . --script res://tests/test_<subject>.gd
## Exits 0 on all-pass, non-zero on any failure.

var _failures: int = 0


## Print the suite tally and exit: 0 on all-pass, non-zero on any failure.
func _finish(suite: String) -> void:
	if _failures == 0:
		print("ALL PASS (%s)" % suite)
		quit(0)
	else:
		printerr("%d FAILURE(S) (%s)" % [_failures, suite])
		quit(1)


# --- helpers -----------------------------------------------------------------

func _build_sim() -> FactorySim:
	# Vent on top of a column, processor lower in the SAME column: vent output falls down
	# the empty cells between them into the processor, then ingots fall to the sink.
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	sim.place_machine(vent_def, Vector2i(6, 0))
	sim.place_machine(proc_def, Vector2i(6, 3))
	return sim


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _items_present(sim: FactorySim, item: StringName) -> int:
	var total: int = int(sim.sink.get(item, 0))
	total += int(sim.inventory.get(item, 0))  # what the player is carrying counts as present too
	for pile: Variant in sim.ground.values():  # resting product piles on the floor
		total += int((pile as Dictionary).get(item, 0))
	for machine: MachineState in sim.machines:
		total += int(machine.input_buffer.get(item, 0))
		total += int(machine.output_buffer.get(item, 0))
	return total


func _dict_sig(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s=%d" % [k, int(d[k])])
	return ",".join(parts)


## The invariant behind the tree tests: every foliage cell is rooted, meaning its 8-connected foliage
## component contains a cell resting directly on non-foliage solid ground. Mirrors the rule in
## FactorySim._settle_foliage. A false return means a tree was left floating in the air.
func _no_floating_foliage(sim: FactorySim) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	var is_fol := func(m: StringName) -> bool: return m == &"wood" or m == &"leaves"
	var visited: Dictionary = {}
	for cell: Vector2i in sim.solid:
		if not is_fol.call(sim.solid[cell]) or visited.has(cell):
			continue
		var stack: Array[Vector2i] = [cell]
		visited[cell] = true
		var rooted: bool = false
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			var below: Vector2i = c + Vector2i(0, 1)
			if sim.solid.has(below) and not is_fol.call(sim.solid[below]):
				rooted = true
			for d: Vector2i in dirs:
				var nb: Vector2i = c + d
				if not visited.has(nb) and sim.solid.has(nb) and is_fol.call(sim.solid[nb]):
					visited[nb] = true
					stack.append(nb)
		if not rooted:
			return false
	return true


## The whole authoritative state as one canonical string. Built on SaveGame.capture, so the canary
## and the save format cannot drift apart: any field added to the envelope is automatically guarded
## here, and a field the envelope misses is a field this canary misses. One list, two guards.
## Dictionary keys are sorted, making the signature content-based and insertion-order-proof; machine
## ARRAY order is kept as-is because tick order is itself authoritative.
func _state_signature(sim: FactorySim) -> String:
	return _canon(SaveGame.capture(sim))


func _canon(v: Variant) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: PackedStringArray = []
			for k: Variant in keys:
				parts.append("%s=%s" % [str(k), _canon(d[k])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for e: Variant in (v as Array):
				parts.append(_canon(e))
			return "[%s]" % ",".join(parts)
		_:
			return str(v)
