extends SceneTree

## Harness layer: THE SAVE FRONTIER — no authoritative field may quietly fall outside the envelope.
##
## WHY THIS IS THE MOST LOAD-BEARING GUARD IN THE SUITE. The project's determinism canary is literally
## the save envelope:
##
##     tests/test_base.gd:  func _state_signature(sim) -> String:  return _canon(SaveGame.capture(sim))
##
## So a field that `capture` does not write is not merely unsaved — it is INVISIBLE TO EVERY DETERMINISM
## TEST IN THE PROJECT. One omission causes two failures, and the second one hides the first: the field
## is dropped from saves, and the tests that exist to notice drift can no longer see it drift. Every
## "identical state after 200 ticks", every "restored sim stays in LOCKSTEP", every stress-run signature
## comparison is silently scoped to whatever `capture` happens to mention.
##
## That is exactly how `_seep_tick` was lost. Loose backfill weeps on a fixed tick cadence, so where the
## world sits in that cycle decides when the next weep lands — authoritative by any definition. It was
## never captured, so an in-process F9 resumed mid-cycle while the same file in a fresh process resumed
## at phase zero, and no canary could report it because the canary could not see the field.
##
## Two halves, because a table and a property catch different things.
##
##   A. THE PARTITION (a table you have to write in). Every script variable on FactorySim is either IN
##      the envelope or listed in NOT_SAVED with a stated reason. A newly added field belongs to neither
##      and turns this red — which is the entire point. "Derived" stops being an assumption and becomes
##      a claim somebody typed.
##
##   B. THE PROPERTY (which does not care what the table says). After `restore`, a sim's state must be
##      INDEPENDENT OF WHAT IT HELD BEFORE. Restore an envelope into a sim that has been running a
##      different world, restore the same envelope into a brand-new sim, and compare all 34 fields: any
##      difference is a value that leaked across the load. This subsumes the table — saved fields must
##      round-trip, derived fields must rebuild, reset fields must reset — and it is why a wrong entry in
##      NOT_SAVED cannot buy a green run. It found `last_drop_landing` surviving a load on its first run.
##
## Run: godot --headless --path . --script res://tools/check_save_frontier.gd

## NOT IN THE ENVELOPE, AND WHY. Two different kinds of "not saved" live here and the difference matters:
## DERIVED means the value is a pure function of saved state and is rebuilt; RESET means it is not
## derivable but is deliberately normalized on load so that every path into a world agrees about it.
## Calling a RESET field "derived" would be a lie that half B catches.
const NOT_SAVED: Dictionary = {
	"grid": "DERIVED — cell → MachineState, rebuilt from `machines` during the commit.",
	"power": "DERIVED — the power field is recomputed by the next tick from conduits + generators.",
	"flow_events": "TRANSIENT — a one-tick channel the view drains; a saved backlog would replay old flows.",
	"terrain_dirty": "TRANSIENT — the renderer's rebake queue; a load repaints everything wholesale anyway.",
	"last_drop_landing": "TRANSIENT — one-shot view channel (the controller's pickup grace). RESET on load.",
	"_bazaars_cache": "DERIVED — lazily rescanned from the restored terrain; `_bazaars_dirty` forces it.",
	"_bazaars_dirty": "DERIVED — set true on load precisely so the cache above rebuilds.",
	"_fine_solid": "DERIVED — the fine grid is a pure function of (solid, world_seed); rebuild_fine_terrain().",
	"_fine_edge": "DERIVED — molding noise, built from world_seed on the first rebuild.",
	"_fine_grit": "DERIVED — grit noise, likewise.",
	"_fine_seed_built": "DERIVED — bookkeeping for the two noise fields above.",
	"_tick_accumulator": "RESET — sub-tick phase. Not derivable, but zeroed on load so both paths agree.",
	"_rate_tick": "RESET — drives the production-rate readout only; never read by production logic.",
	"_rate_samples": "RESET — the rate ring buffer, cleared with the counter that indexes it.",
}

## Envelope keys that are not spelled the same as the field they carry, plus the keys that describe the
## envelope rather than the sim.
const ALIASES: Dictionary = {
	"produced": "total_produced", "consumed": "total_consumed", "seep_tick": "_seep_tick",
}
const META_KEYS: Array[String] = ["version"]

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _initialize() -> void:
	var fields: Array[String] = _script_fields()
	_check(fields.size() >= 30, "FactorySim's field list was read (%d script variables)" % fields.size())
	_partition(fields)
	_no_leak(fields)
	if _failures == 0:
		print("check_save_frontier: PASS")
		quit(0)
	else:
		printerr("check_save_frontier: %d FAILURE(S)" % _failures)
		quit(1)


func _script_fields() -> Array[String]:
	var out: Array[String] = []
	var sim := FactorySim.new()
	for p: Dictionary in sim.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(p["name"]))
	return out


## A. Every field is accounted for, in exactly one place, and the table has not rotted in either
## direction — no field missing from both lists, no entry naming a field that no longer exists.
func _partition(fields: Array[String]) -> void:
	print("== the partition ==")
	var env: Dictionary = SaveGame.capture(FactorySim.new())
	var saved: Dictionary = {}
	var dead: Array[String] = []
	for k: Variant in env.keys():
		var key: String = String(k)
		if META_KEYS.has(key):
			continue
		var field: String = String(ALIASES.get(key, key))
		if fields.has(field):
			saved[field] = true
		else:
			dead.append("%s→%s" % [key, field])
	_check(saved.size() >= 15, "the envelope carries real sim fields (%d of them)" % saved.size())
	_check(dead.is_empty(), "no envelope key names a field that no longer exists%s"
		% ("" if dead.is_empty() else " — " + ", ".join(dead)))

	var orphans: Array[String] = []
	for f: String in fields:
		if not saved.has(f) and not NOT_SAVED.has(f):
			orphans.append(f)
	# THE FORCING FUNCTION. A new field on FactorySim lands here until somebody either captures it or
	# writes down why it does not need capturing. There is no third option, and there is no default.
	_check(orphans.is_empty(),
		"every FactorySim field is either SAVED or declared NOT_SAVED with a reason%s"
			% ("" if orphans.is_empty() else " — unaccounted: " + ", ".join(orphans)))

	var stale: Array[String] = []
	var double: Array[String] = []
	for k2: Variant in NOT_SAVED.keys():
		var name: String = String(k2)
		if not fields.has(name):
			stale.append(name)
		elif saved.has(name):
			double.append(name)
	_check(stale.is_empty(), "no NOT_SAVED entry names a field that has been deleted%s"
		% ("" if stale.is_empty() else " — " + ", ".join(stale)))
	_check(double.is_empty(), "no field is both saved and declared unsaved%s"
		% ("" if double.is_empty() else " — " + ", ".join(double)))
	print("  (%d saved · %d declared not-saved · %d total)" % [saved.size(), NOT_SAVED.size(), fields.size()])


## B. THE PROPERTY. Restore the same envelope into a sim that has been living a different life and into
## a brand-new one, and every field must agree. Whatever the table claims, a value that survives from
## the dirty sim's past is a leak — and a leak is precisely how one save file grows two futures.
func _no_leak(fields: Array[String]) -> void:
	print("== no leak across a load ==")
	var source: FactorySim = _world(7, 24)
	for _i: int in range(60):
		source.advance(FactorySim.SECONDS_PER_TICK)
	var envelope: Dictionary = SaveGame.capture(source)

	# The dirty sim: a DIFFERENT world, run for a different length of time, so every field it holds is
	# both populated and wrong for the envelope about to land on it.
	var dirty: FactorySim = _world(1337, 40)
	for _j: int in range(137):
		dirty.advance(FactorySim.SECONDS_PER_TICK)
	# …and the one-shot view channels stamped by hand. A running session sets these through gameplay
	# paths this fixture does not reach (an item has to actually land somewhere), and a field left at its
	# default in BOTH sims is a field this layer would be claiming to check while checking nothing —
	# which is exactly what happened: the `last_drop_landing` leak passed until it was stamped here.
	dirty.last_drop_landing = Vector2i(99, 99)
	var fresh := FactorySim.new()

	# NON-VACUITY: prove the two sims really are far apart before the restore. If they already agreed,
	# every assertion below would pass without the restore doing anything at all.
	var apart: int = 0
	for f: String in fields:
		if _canon(dirty.get(f)) != _canon(fresh.get(f)):
			apart += 1
	_check(apart >= 12, "the dirty sim and a fresh one disagree about %d fields before the load" % apart)

	_check(SaveGame.restore(dirty, envelope), "the envelope restores into the dirty sim")
	_check(SaveGame.restore(fresh, envelope), "…and into the fresh one")

	var leaked: Array[String] = []
	for f2: String in fields:
		if _canon(dirty.get(f2)) != _canon(fresh.get(f2)):
			leaked.append(f2)
	_check(leaked.is_empty(),
		"after the load both sims hold IDENTICAL state in all %d fields — nothing leaked from the past%s"
			% [fields.size(), "" if leaked.is_empty() else " — leaked: " + ", ".join(leaked)])

	# …and the consequence, stated as the thing a player would actually notice: they run the same.
	var before: String = _canon(fresh.water)
	for _k: int in range(FactorySim.SEEP_INTERVAL * 4):
		dirty.advance(FactorySim.SECONDS_PER_TICK)
		fresh.advance(FactorySim.SECONDS_PER_TICK)
	_check(_canon(fresh.water) != before, "the loaded world is one where time does something (water moved)")
	var still: Array[String] = []
	for f3: String in fields:
		if _canon(dirty.get(f3)) != _canon(fresh.get(f3)):
			still.append(f3)
	_check(still.is_empty(), "…and four seep cycles later they are STILL identical%s"
		% ("" if still.is_empty() else " — diverged: " + ", ".join(still)))


## A world where time does something: a flooded shaft over one cell of LOOSE backfill over open gallery,
## which is the configuration that weeps. `mark` makes the two worlds distinguishable; `depth` moves the
## whole arrangement so the dirty sim's terrain does not accidentally match the source's.
func _world(mark: int, depth: int) -> FactorySim:
	var sim := FactorySim.new()
	for col: int in range(8, 14):
		for row: int in range(depth, depth + 12):
			sim.set_solid(Vector2i(col, row), &"stone")
	for r1: int in range(depth + 2, depth + 6):
		sim.solid.erase(Vector2i(10, r1))
	for r2: int in range(depth + 7, depth + 11):
		sim.solid.erase(Vector2i(10, r2))
	sim.add_water(Vector2i(10, depth + 4), FactorySim.WATER_MAX)
	sim.add_water(Vector2i(10, depth + 5), FactorySim.WATER_MAX)
	sim.set_solid(Vector2i(10, depth + 6), &"earth")
	sim.fill[Vector2i(10, depth + 6)] = FactorySim.FILL_LOOSE
	sim.world_seed = mark
	sim.inventory[&"ore"] = mark
	sim.total_produced[&"ore"] = mark
	sim.deposits[Vector2i(9, depth + 8)] = mark
	sim.lode[Vector2i(9, depth + 8)] = &"ore"
	sim.research[&"seal"] = true
	# A real machine, so `machines`/`grid` are populated and the comparison covers object state too.
	sim.place_machine(load("res://src/data/machines/generator.tres") as MachineDef,
		Vector2i(11, depth - 1))
	return sim


## A value as a comparable string. Objects have no useful `==` here (two restored MachineStates are
## different instances holding the same game), and PackedByteArray prints a quarter of a megabyte, so
## both get canonical forms instead of being skipped — a field that cannot be compared is a field this
## layer is not actually checking.
func _canon(v: Variant) -> String:
	if v == null:
		return "null"
	if v is PackedByteArray:
		var b: PackedByteArray = v
		return "bytes(%d,%d)" % [b.size(), hash(b)]
	if v is MachineState:
		var m: MachineState = v
		return "machine(%s@%s in=%s out=%s spoil=%s p=%.4f rt=%d fuel=%d pf=%.4f fed=%d f=%d mode=%d flt=%s)" % [
			m.def.id, m.cell, _canon(m.input_buffer), _canon(m.output_buffer), _canon(m.spoil_buffer),
			m.progress, m.route_toggle, m.fuel, m.power_factor, m.fed, m.facing, m.mode, m.filter]
	if v is FastNoiseLite:
		var n: FastNoiseLite = v
		return "noise(seed=%d,freq=%.6f,type=%d)" % [n.seed, n.frequency, n.noise_type]
	if v is Dictionary:
		var d: Dictionary = v
		var keys: Array = d.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var parts: PackedStringArray = []
		for k: Variant in keys:
			parts.append("%s=%s" % [str(k), _canon(d[k])])
		return "{%s}" % ",".join(parts)
	if v is Array:
		var items: PackedStringArray = []
		for e: Variant in (v as Array):
			items.append(_canon(e))
		return "[%s]" % ",".join(items)
	if v is Object:
		# Deliberately loud rather than silently equal: a new Object-typed field would otherwise compare
		# as its class name and this layer would stop checking it without saying so.
		return "UNCOMPARABLE-OBJECT(%s)" % (v as Object).get_class()
	return str(v)
