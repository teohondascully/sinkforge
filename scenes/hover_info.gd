extends RefCounted

## Builds the hover readout: the dictionary the HUD's info panel renders for whatever cell the cursor or
## the pinned config panel is over. That is a machine's mode / buffers / rate / knobs; on bare terrain it
## is the ore vein, seal, rope and too-hard-rock hints. Pure read: it queries the sim and never mutates it,
## and returns the {name, in, out, holding, mode, …} shape hud.gd consumes. Two pieces of context cannot
## be computed here and reach it from MainView: whether the cell is in reach (`_can_reach` is the gate the
## verbs use) and the current drill rate (`_drill_rate` reads the machine-def table).

## Describe an explicit cell. Called for the live cursor, and for the latched machine while the config
## panel is pinned and the cursor is off over its knobs. An empty dict means nothing to show: out of
## reach, or a bare cell with no hint.
static func describe(sim: FactorySim, aim: Vector2i, reachable: bool, drill_rate: float) -> Dictionary:
	if not reachable:
		return {}
	var m: MachineState = sim.machine_at(aim)
	if m == null:
		# A solid ore vein reports how much ore is left plus the nudge to automate it. An exposed lode
		# (docs/LODE.md) is answered first: the rock in front of it is gone, so there is nothing to drop a
		# drill above and you work the face instead. Within the lode branch the tier line comes before the
		# amount, because "you cannot touch this yet" outranks "there is a lot of it".
		var vein: StringName = sim.lode_at(aim)
		if vein != &"" and not sim.is_solid(aim):
			if not MiningRules.can_mine(vein, sim.inventory):
				return {"name": "%s Lode" % String(vein).capitalize(), "in": [], "out": [], "holding": [],
					"mode": "too hard — the %s (tier %d) bites it" % [
						MiningRules.tool_name(MiningRules.drive_for(vein)), MiningRules.required_tier(vein)]}
			return {"name": "%s Lode" % String(vein).capitalize(), "in": [], "out": [], "holding": [],
				"mode": "%d left — work it by hand, or stand a Drill ON it (%s)" % [
					sim.ore_deposit_at(aim), _rate_eta(drill_rate, sim.ore_deposit_at(aim))]}
		var dep: int = sim.ore_deposit_at(aim)
		if dep > 0:
			return {"name": "Ore Vein", "in": [], "out": [], "holding": [],
				"mode": "%d ore — drop a Drill just above it (%s)" % [dep, _rate_eta(drill_rate, dep)]}
		# The seal is its own answer: no pick ever opens it, the Descent Engine does (docs/PROGRESSION.md).
		if sim.material_at(aim) == &"sealrock":
			return {"name": "The Seal", "in": [], "out": [], "holding": [],
				"mode": "no pick will breach it — research DESCENT, stand an Engine on it, feed it %d ingots" % FactorySim.DESCENT_QUOTA}
		# A hanging rope: its coil count and the one-action recovery.
		if sim.is_climbable(aim):
			return {"name": "Rope", "in": [], "out": [], "holding": [],
				"mode": "%d segments hung — RMB takes the whole rope back" % sim.rope_length(aim)}
		# Rock your current tools cannot break: the depth gate's explanation of itself.
		if sim.is_solid(aim):
			var rock: StringName = sim.material_at(aim)
			if not MiningRules.can_mine(rock, sim.inventory):
				# Name the drive this rock wants. Never hardcode a tool here: `drive_for` derives it from
				# the same table the gate reads, so a new rock band cannot end up telling the player to
				# craft a pick they already own.
				return {"name": String(rock).capitalize(), "in": [], "out": [], "holding": [],
					"mode": "too hard — the %s (tier %d) bites it" % [
						MiningRules.tool_name(MiningRules.drive_for(rock)), MiningRules.required_tier(rock)]}
		return {}
	var info: Dictionary = {"name": m.def.display_name}
	var recipe: RecipeDef = m.def.recipe
	var ins: Array = []
	var outs: Array = []
	if recipe != null:
		for it: StringName in recipe.inputs:
			ins.append({"item": it, "count": int(recipe.inputs[it])})
		for it: StringName in recipe.outputs:
			outs.append({"item": it, "count": int(recipe.outputs[it])})
	info["in"] = ins
	info["out"] = outs
	match m.def.behavior:
		&"lift":
			info["mode"] = "lifts goods + you UP" + ("  (POWERED ×%.1f)" % (1.0 + (float(FactorySim.LIFT_POWERED_THROUGHPUT) / float(FactorySim.LIFT_THROUGHPUT) - 1.0) * m.power_factor) if m.power_factor > 0.05 else "  (unpowered baseline)")
		&"splitter":
			info["mode"] = ["splits DOWN + RIGHT evenly",
				"splits 2:1 favouring DOWN",
				"splits 1:2 favouring RIGHT"][m.mode % 3]
			# The config panel's clickable ratio chips. R still cycles, for keyboard hands.
			info["knobs"] = [{"kind": "choice", "label": "ratio",
				"options": ["1:1", "2:1 v", "1:2 >"], "current": m.mode % 3}]
		&"hopper":
			var stock: int = 0
			for it: StringName in m.input_buffer:
				stock += int(m.input_buffer[it])
			if m.filter == &"":
				info["mode"] = "stockpiles %d — keeps the FIRST thing it tastes, passes the rest" % stock
			else:
				info["mode"] = "banks %s (%d) — passes everything else" % [String(m.filter), stock]
				info["knobs"] = [{"kind": "action", "id": "clear_filter",
					"label": "[ clear filter — re-taste ]"}]
		&"generator":
			info["mode"] = "burns coal → POWER" + ("  (running)" if m.fuel > 0 else "  (out of fuel)")
		&"descent":
			if m.fed >= FactorySim.DESCENT_QUOTA:
				info["mode"] = "BREACHED — the way down is open"
			elif sim.machine_status(m) == &"blocked":
				info["mode"] = "stand it ON the seal (nothing to breach below)"
			else:
				info["mode"] = "drop ingots in — gravity feeds it"
				info["bar"] = {"frac": float(m.fed) / float(FactorySim.DESCENT_QUOTA),
					"label": "quota %d / %d ingots" % [m.fed, FactorySim.DESCENT_QUOTA]}
		&"h_drill":
			var btgt: Vector2i = sim.h_drill_target(m.cell, m.facing)
			var belly: int = 0
			for it2: StringName in m.output_buffer:
				belly += int(m.output_buffer[it2])
			var bcoal: int = int(m.input_buffer.get(&"coal", 0))
			match sim.machine_status(m):
				&"no_input":
					info["mode"] = "gallery spent — carry it to a new rock face"
				&"blocked":
					info["mode"] = "belly FULL (%d) — dig a drain below it, or pick it up" % belly
				&"no_fuel":
					info["mode"] = "OUT OF COAL — it burns coal to bore (drop some on it)"
				_:
					info["mode"] = "boring %s %s — belly %d · coal %d" % [
						String(sim.material_at(btgt)), ("→" if m.facing > 0 else "←"), belly, bcoal]
		&"drill":
			var tgt: Vector2i = sim.drill_target(m.cell)         # the solid ore vein it bores below
			var dep2: int = sim.drill_column_remaining(m.cell) if tgt.x >= 0 else 0
			var coal: int = int(m.input_buffer.get(&"coal", 0))
			var fueled: bool = m.fuel > 0 or coal > 0
			if dep2 <= 0:
				info["mode"] = "idle — no ore below (drop it into a shaft above an ore vein)"
			elif not fueled:
				info["mode"] = "OUT OF COAL — drop coal on it to run  (%d ore left)" % dep2
			else:
				info["mode"] = "drilling %s — %d ore left  ·  coal %d" % [_rate_eta(drill_rate, dep2), dep2, coal]
		_:
			if recipe != null and recipe.inputs.is_empty():
				info["mode"] = "ore source"
			elif recipe != null:
				info["mode"] = "smelts (%.1fs/cycle)" % recipe.time
	var hold: Dictionary = {}
	for it: StringName in m.input_buffer:
		hold[it] = int(hold.get(it, 0)) + int(m.input_buffer[it])
	for it: StringName in m.output_buffer:
		hold[it] = int(hold.get(it, 0)) + int(m.output_buffer[it])
	var holding: Array = []
	for it: StringName in hold:
		holding.append({"item": it, "count": int(hold[it])})
	info["holding"] = holding
	# The factory-wide make-rate of this machine's product, in items per minute. Recipe machines rate
	# their first output; a drill rates the material it is boring.
	var rate_item: StringName = &""
	if recipe != null and not recipe.outputs.is_empty():
		rate_item = recipe.outputs.keys()[0]
	elif m.def.behavior == &"drill":
		var bore: Vector2i = sim.drill_target(m.cell)
		if bore.x >= 0:
			rate_item = sim.material_at(bore)
	if rate_item != &"":
		var per_min: float = sim.production_rate(rate_item)
		if per_min > 0.05:
			info["rate"] = "factory makes %.1f %s/min" % [per_min, String(rate_item)]
	return info


## Format a rate and an ETA-to-empty for a deposit, as "1.0/s · ~4m left", so throughput and how long
## the patch lasts are both readable. A rate of 0 formats the amount alone.
static func _rate_eta(rate: float, amount: int) -> String:
	if rate <= 0.0:
		return "%d left" % amount
	var secs: int = int(round(float(amount) / rate))
	var span: String = ("~%dm left" % (secs / 60)) if secs >= 90 else ("~%ds left" % secs)
	return "%.1f/s · %s" % [rate, span]
