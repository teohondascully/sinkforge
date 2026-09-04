extends "res://tests/test_base.gd"
## D0369. `view/hud/inspector.gd`: the readout for the aimed cell. `describe()` is posed on observations
## and every branch is a claim about what THIS build's machines and terrain say; `layout()`'s claims are
## legacy's panel rules -- the width between its floor and cap, the ellipsis, the row count, the
## top-right anchor, the stand-down under the plate, nothing out of reach.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_inspector.gd
const S: int = Fx.SCALE
const W: int = 64
const H: int = 64


func _initialize() -> void:
	_test_nothing_out_of_reach_or_off_the_hint_list()
	_test_the_terrain_answers()
	_test_the_drill_and_the_generator()
	_test_the_hopper_and_the_winch()
	_test_recipe_machines_and_the_rate()
	_test_the_panel_rules()
	await _test_paint_runs_through_the_hud_host()
	_finish("inspector")


func _obs(aim: Vector2i = Vector2i(30, 30)) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.window = Rect2i(0, 0, W, H)
	o.logic_window = Rect2i(0, 0, W / 4, H / 4)
	o.legend = PackedStringArray(["", "clay", "ore_iron"])
	o.materials = PackedByteArray()
	o.materials.resize(W * H)
	o.water = PackedByteArray()
	o.water.resize(W * H)
	o.ore_like_legend = PackedByteArray([0, 0, 1])
	o.ore_default = 12
	o.aim_cell = aim
	o.aim_in_reach = true
	return o


func _rec(o: Interface.Observation, id: String, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = MachinesRecords.RECORDS[id]
	var r: Dictionary = {"cell": Vector2i(7, 7), "id": StringName(id), "behavior": StringName(data["behavior"]),
		"source": false, "name": String(data["display_name"]), "recipe": StringName(String(data.get("recipe", ""))),
		"status": status, "power_permille": 0, "progress_permille": 0, "facing": 1, "fuel": 0, "filter": &"",
		"input": {}, "output": {}}
	for k: Variant in extra:
		r[k] = extra[k]
	o.machines.append(r)
	return r


func _test_nothing_out_of_reach_or_off_the_hint_list() -> void:
	var o: Interface.Observation = _obs()
	_check(Inspector.describe(o).is_empty(), "air in reach with nothing on it: nothing to say")
	_rec(o, "drill", &"working")
	_check(not Inspector.describe(o).is_empty(), "control: a drill under the aim answers")
	o.aim_in_reach = false
	_check(Inspector.describe(o).is_empty(), "the same drill out of reach: nothing")
	o.aim_in_reach = true
	o.aim_cell = Vector2i(-1, -1)
	_check(Inspector.describe(o).is_empty(), "no aim: nothing")
	_check(Inspector.describe(null).is_empty(), "no observation: nothing")


func _test_the_terrain_answers() -> void:
	var o: Interface.Observation = _obs()
	o.materials[30 * W + 30] = 2
	var d: Dictionary = Inspector.describe(o)
	_check(d.get("name", "") == "Ore Vein" and String(d["mode"]).begins_with("12 ore"), "a solid ore cell is a vein with its default yield (%s)" % str(d))
	o.ore_yield[Vector2i(30, 30)] = 5
	_check(String(Inspector.describe(o)["mode"]).begins_with("5 ore"), "an explicit yield overrides the default")
	o.materials[30 * W + 30] = 0
	o.lodes[Vector2i(30, 30)] = {"material": &"ore_iron", "amount": 40, "permille": 250}
	d = Inspector.describe(o)
	_check(d.get("name", "") == "Ore Iron Lode" and String(d["mode"]).begins_with("40 left") and String(d["mode"]).contains("25%"), "an exposed lode names itself with its amount and progress (%s)" % str(d))
	o.lodes.clear()
	o.placed[Vector2i(7, 7)] = &"rope"
	_check(Inspector.describe(o).get("name", "") == "Rope", "a rope cell (%s)" % str(Inspector.describe(o)))
	o.placed[Vector2i(7, 7)] = &"torch"
	_check(Inspector.describe(o).get("name", "") == "Torch", "a torch cell")
	o.placed.clear()
	o.water[30 * W + 30] = 3
	d = Inspector.describe(o)
	_check(d.get("name", "") == "Water" and String(d["mode"]).begins_with("3 of %d" % Interface.Observation.WATER_MAX), "water reports its units (%s)" % str(d))
	o.water[30 * W + 30] = 0
	o.ore_yield.clear()
	o.materials[30 * W + 30] = 1
	_check(Inspector.describe(o).is_empty(), "plain clay in reach says nothing, as legacy's did")


func _test_the_drill_and_the_generator() -> void:
	var o: Interface.Observation = _obs()
	var r: Dictionary = _rec(o, "drill", &"working", {"input": {&"coal": 4}})
	var d: Dictionary = Inspector.describe(o)
	_check(d["name"] == "Drill" and String(d["mode"]).contains("coal 4") and String(d["status"]) == "", "a working drill narrates its coal and carries no stall line (%s)" % str(d))
	_check((d["out"] as Array).size() == 1 and (d["out"] as Array)[0]["item"] == &"ore" and (d["in"] as Array).is_empty(), "its recipe reads as a source: nothing in, ore out")
	_check((d["holding"] as Array).size() == 1 and int((d["holding"] as Array)[0]["count"]) == 4, "it holds the four coal")
	r["status"] = &"no_fuel"
	r["input"] = {}
	_check(String(Inspector.describe(o)["mode"]).begins_with("OUT OF COAL"), "out of coal says so in the mode line")
	r["status"] = &"spent"
	_check(String(Inspector.describe(o)["mode"]).contains("worked out"), "spent says the vein is worked out")
	r["status"] = &"no_power"
	_check(String(Inspector.describe(o)["status"]).begins_with("no power"), "an unpowered drill gets the power line")
	o.machines.clear()
	var g: Dictionary = _rec(o, "generator", &"working", {"fuel": 3})
	_check(String(Inspector.describe(o)["mode"]).ends_with("(running)"), "a fuelled generator is running")
	g["fuel"] = 0
	g["status"] = &"no_fuel"
	d = Inspector.describe(o)
	_check(String(d["mode"]).ends_with("(out of fuel)") and String(d["status"]).begins_with("out of coal"), "an empty one says so twice: the mode and the stall line (%s)" % str(d))


func _test_the_hopper_and_the_winch() -> void:
	var o: Interface.Observation = _obs()
	var h: Dictionary = _rec(o, "hopper", &"working", {"input": {&"stone": 6}})
	_check(String(Inspector.describe(o)["mode"]).begins_with("stockpiles 6"), "an unfiltered hopper stockpiles")
	h["filter"] = &"stone"
	_check(String(Inspector.describe(o)["mode"]).begins_with("banks Stone (6)"), "a filtered one banks its item")
	h["status"] = &"blocked"
	_check(String(Inspector.describe(o)["mode"]).contains("BACKED UP"), "and backed up says so")
	o.machines.clear()
	var w: Dictionary = _rec(o, "winch_head", &"working")
	_check(String(Inspector.describe(o)["mode"]).contains("Station"), "the winch head bores toward the Station")
	w["status"] = &"blocked"
	_check(String(Inspector.describe(o)["mode"]).begins_with("the Station is full"), "blocked names the Station")
	o.machines.clear()
	_rec(o, "winch_station", &"idle", {"output": {&"ore": 9}})
	_check(String(Inspector.describe(o)["mode"]).contains("9 held"), "the station counts what it holds")
	o.machines.clear()
	_rec(o, "lift", &"working", {"power_permille": 800})
	_check(String(Inspector.describe(o)["mode"]).ends_with("(POWERED)"), "a powered lift says so")


func _test_recipe_machines_and_the_rate() -> void:
	var o: Interface.Observation = _obs()
	_rec(o, "gear_mill", &"working")
	var d: Dictionary = Inspector.describe(o)
	var recipe: Dictionary = RecipesRecords.RECORDS[String(MachinesRecords.RECORDS["gear_mill"]["recipe"])]
	var secs: float = float(recipe["time_ticks"]) / float(Interface.Observation.TICK_HZ)
	_check(String(d["mode"]).begins_with("makes") and String(d["mode"]).contains("%.1fs" % secs), "a recipe machine names its product and cycle from the data (%s)" % str(d["mode"]))
	_check((d["in"] as Array).size() == (recipe["inputs"] as Dictionary).size(), "its input chips are the recipe's")
	_check(not d.has("rate"), "no live rate, no rate line")
	var out_item := StringName((recipe["outputs"] as Dictionary).keys()[0])
	o.rates = [{"item": out_item, "rate_centi": 350}]
	d = Inspector.describe(o)
	_check(String(d.get("rate", "")) == "factory makes 3.5 %s/min" % String(out_item), "the rate line reads the economy's list in items a minute (%s)" % str(d.get("rate", "")))
	o.rates = [{"item": out_item, "rate_centi": 3}]
	_check(not Inspector.describe(o).has("rate"), "a trickle under 0.05/min is not reported")


func _frame(o: Interface.Observation) -> Frame:
	var f: Frame = Frame.new()
	f.obs = o
	return f


func _test_the_panel_rules() -> void:
	var font: Font = ThemeDB.fallback_font
	var o: Interface.Observation = _obs()
	_rec(o, "drill", &"working", {"input": {&"coal": 2}})
	var l: Dictionary = Inspector.layout(_frame(o), font)
	_check(not l.is_empty() and int(l["rows"]) == 4, "a working drill: name, recipe, mode, holds -- four rows (%d)" % int(l.get("rows", -1)))
	var rect: Rect2 = l["rect"]
	_check(rect.size.x >= UiTheme.px(Inspector.MIN_W) - 0.01 and rect.size.x <= UiTheme.px(Inspector.MAX_W) + 0.01, "the width sits between legacy's floor and cap (%.1f)" % rect.size.x)
	_check(is_equal_approx(rect.end.x, UiTheme.CANVAS.x - UiTheme.px(12.0)) and is_equal_approx(rect.position.y, UiTheme.px(Inspector.TOP)), "anchored top-right under the corner register")
	_check(is_equal_approx(rect.size.y, UiTheme.px(10.0 + 4.0 * Inspector.LINE_H + 4.0)), "and as tall as its rows (%.1f)" % rect.size.y)
	o.machines[0]["status"] = &"blocked"
	_check(int(Inspector.layout(_frame(o), font)["rows"]) == 4, "a stall the mode line narrates adds no row")
	o.machines.clear()
	_rec(o, "lift", &"no_power")
	_check(int(Inspector.layout(_frame(o), font)["rows"]) == 3, "a lift without power: name, mode, the stall line (%d)" % int(Inspector.layout(_frame(o), font)["rows"]))
	var long: String = "a sentence long enough to run past the cap of the panel by a wide margin, and then some more words after that"
	var fitted: String = Inspector.fit_text(font, long, UiTheme.pt(Inspector.LINE_SIZE), UiTheme.px(Inspector.MAX_W - 2.0 * Inspector.PAD))
	_check(fitted.ends_with("…") and fitted.length() < long.length(), "a line past the cap is ellipsized (%s)" % fitted)
	_check(Inspector.fit_text(font, "short", 11, 500.0) == "short", "a line that fits is untouched")
	_check(Inspector.layout(_frame(o), font, true).is_empty(), "the panel stands down under a visible arrival plate")
	_check(Inspector.layout(null, font).is_empty(), "no frame, no panel")


func _test_paint_runs_through_the_hud_host() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	machines.place(world, MachineDef.of(&"drill"), Vector2i(3, 14))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var plate: ArrivalPlate = ArrivalPlate.new()
	var inspector: Inspector = Inspector.new(plate)
	var ran: Array = [0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		inspector.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran inside the HUD host's draw pass with a plate to consult (%d)" % int(ran[0]))
	view.queue_free()
