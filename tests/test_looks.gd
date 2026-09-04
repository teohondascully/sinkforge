extends "res://tests/test_base.gd"

## THE THREE LOOK REGISTRIES (A' step 6b, D0363), pinned against the DATA rather than against memory:
## `view/visuals/machine_look.gd` + `machine_glyphs.gd`, `status_look.gd`, `item_look.gd`. What legacy's
## `check_status_reads` and `check_item_reads` guarded, at the level a headless suite can: every machine
## record has a style, a kind with a drawer and a flat-footed profile whose face is one of its parts;
## every status the sim can return has a colour and a mark, and two statuses calling for different fixes
## never share a mark; every item this build can carry has a colour that is not the white fallback and a
## drawer; and every glyph, casing and item draws to completion in a real redraw. It cannot say whether
## any of them LOOK right -- that is the director's eye, and the taste queue.

## The statuses the sim returns today: `MachineStatus.of` and the winch's `Movers.status_winch_head`.
const STATUSES: Array[StringName] = [&"working", &"idle", &"spent", &"no_fuel", &"no_input", &"no_power",
	&"blocked", &"unlinked"]
## What a pack can hold: every material a bore yields (D0349: the material id IS the item id), every
## recipe input and output, the placeables, wood and coal.
const PLACEABLES: Array[StringName] = [&"rope", &"torch", &"conduit", &"sapling", &"wood"]


func _initialize() -> void:
	_test_every_machine_record_has_a_look()
	_test_profiles_stand_on_a_flat_foot()
	_test_every_status_has_a_colour_and_a_mark_under_the_fix_rule()
	_test_every_carried_item_has_a_colour_and_a_purpose()
	_test_cold_iron_and_the_glyph_scale()
	await _test_everything_draws_in_a_real_redraw()
	_finish("looks")


func _items() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: String in MaterialsRecords.RECORDS:
		ids.append(StringName(id))
	for id: String in RecipesRecords.RECORDS:
		var r: Dictionary = RecipesRecords.RECORDS[id]
		for item: String in r.get("inputs", {}):
			if not ids.has(StringName(item)):
				ids.append(StringName(item))
		for item: String in r.get("outputs", {}):
			if not ids.has(StringName(item)):
				ids.append(StringName(item))
	for id: StringName in PLACEABLES:
		if not ids.has(id):
			ids.append(id)
	if not ids.has(&"coal"):
		ids.append(&"coal")
	return ids


func _test_every_machine_record_has_a_look() -> void:
	var missing: Array = []
	var no_drawer: Array = []
	for id: String in MachinesRecords.RECORDS:
		var r: Dictionary = MachinesRecords.RECORDS[id]
		var behavior := StringName(str(r.get("behavior", "")))
		var kind: String = MachineLook.kind(behavior, StringName(id), false)
		if not MachineLook.STYLE.has(behavior) and id != "processor":
			missing.append(id)
		if not MachineGlyphs.KINDS.has(kind):
			no_drawer.append(id + ":" + kind)
	_check(MachinesRecords.RECORDS.size() >= 15, "control: the machine data has its fifteen records (%d)" % MachinesRecords.RECORDS.size())
	_check(missing.is_empty(), "every machine record but the base Forge has a style entry (missing: %s)" % [missing])
	_check(no_drawer.is_empty(), "...and every kind the registry names has a glyph drawer (%s)" % [no_drawer])
	var dead: Array = []
	for behavior: StringName in MachineLook.STYLE:
		var found: bool = false
		for id: String in MachinesRecords.RECORDS:
			if StringName(str(MachinesRecords.RECORDS[id].get("behavior", ""))) == behavior:
				found = true
		if not found:
			dead.append(behavior)
	_check(dead.is_empty(), "no style entry names a machine the data does not have (dead: %s)" % [dead])
	_check(MachineLook.kind(&"", &"processor", false) == "furnace" and MachineLook.color(&"", &"processor", false) == MachineLook.FURNACE_BODY,
		"the base Forge is a furnace by id")
	_check(MachineLook.kind(&"", &"anything", true) == "furnace" and MachineLook.kind(&"", &"anything", false) == "gear",
		"a no-input source is a furnace, any other unstyled runner a gear")


func _test_profiles_stand_on_a_flat_foot() -> void:
	var floating: Array = []
	var off_face: Array = []
	# Legacy's own prose says every profile keeps a flat foot; its own conduit is a bar mid-cell and does
	# not, correctly (a pipe is not bolted down). The rule that holds: every profile WITH A BODY has one.
	for kind: String in MachineLook.PROFILE:
		var parts: Array = MachineLook.profile(kind)
		var foot: bool = false
		for r: Rect2 in parts:
			if absf(r.end.y - 1.0) < 0.001:
				foot = true
		if parts.has(MachineLook.BODY) and not foot:
			floating.append(kind)
		if not parts.has(MachineLook.face(kind)):
			off_face.append(kind)
	_check(floating.is_empty(), "every profile with a body keeps a flat foot at y=1.0 (floating: %s)" % [floating])
	_check(off_face.is_empty(), "every face is one of its own kind's parts (%s)" % [off_face])
	_check(MachineLook.profile("no_such_kind") == MachineLook.FULL_PROFILE, "an unknown kind keeps the full square")
	_check(MachineLook.face("furnace") == MachineLook.BODY, "a furnace's face is its body, not its chimney")
	var live_kinds: Array = []
	for behavior: StringName in MachineLook.STYLE:
		var k: String = MachineLook.STYLE[behavior]["kind"]
		if not live_kinds.has(k):
			live_kinds.append(k)
	var unprofiled: Array = []
	for k: String in live_kinds:
		if not MachineLook.PROFILE.has(k):
			unprofiled.append(k)
	_check(unprofiled.is_empty(), "every live kind has its own silhouette (%s)" % [unprofiled])


func _test_every_status_has_a_colour_and_a_mark_under_the_fix_rule() -> void:
	var missing: Array = []
	for s: StringName in STATUSES:
		if not StatusLook.LOOK.has(s):
			missing.append(s)
	_check(missing.is_empty(), "every status the sim returns has a look (missing: %s)" % [missing])
	_check(StatusLook.of(&"never_heard_of") == StatusLook.LOOK[&"idle"], "an unknown status falls back on idle's bar")
	var clash: Array = []
	for a: StringName in StatusLook.LOOK:
		for b: StringName in StatusLook.LOOK:
			if a < b and StatusLook.LOOK[a]["mark"] == StatusLook.LOOK[b]["mark"] and StatusLook.LOOK[a]["fix"] != StatusLook.LOOK[b]["fix"]:
				clash.append("%s/%s" % [a, b])
	_check(clash.is_empty(), "two statuses calling for different fixes never share a mark (%s)" % [clash])
	_check(StatusLook.LOOK[&"no_fuel"]["mark"] == StatusLook.LOOK[&"no_input"]["mark"], "...while the two 'put something in' statuses share one")
	var feeds: Array = []
	for s: StringName in StatusLook.LOOK:
		if StatusLook.LOOK[s]["feeds"]:
			feeds.append(s)
	_check(feeds == [&"no_fuel", &"no_input"], "only the two statuses an item can answer feed the bubble (%s)" % [feeds])


func _test_every_carried_item_has_a_colour_and_a_purpose() -> void:
	var ids: Array[StringName] = _items()
	_check(ids.size() >= 18, "control: the carried population is real (%d ids)" % ids.size())
	var blank: Array = []
	var mute: Array = []
	for id: StringName in ids:
		if ItemLook.color(id) == Color.WHITE:
			blank.append(id)
		if ItemLook.purpose(id) == "":
			mute.append(id)
	_check(blank.is_empty(), "every carried item has a colour that is not the white fallback (%s)" % [blank])
	_check(mute.is_empty(), "...and a purpose line (%s)" % [mute])
	_check(ItemLook.color(&"no_such_item") == Color.WHITE and ItemLook.purpose(&"no_such_item") == "", "an unknown item is white and silent")
	var dead: Array = []
	for id: StringName in ItemLook.PURPOSE:
		if not ids.has(id) and not MachinesRecords.RECORDS.has(String(id)):
			dead.append(id)
	_check(dead.is_empty(), "no purpose line names a thing this build does not have (%s)" % [dead])
	_check(ItemLook.terrain_dust(&"clay") != ItemLook.terrain_dust(&"hardrock"), "the dust colour follows the material")


func _test_cold_iron_and_the_glyph_scale() -> void:
	var warm := Color(0.72, 0.56, 0.30)
	var cold: Color = MachineLook.cold_iron(warm)
	_check(cold.r < warm.r and cold.g < warm.g and cold.b < warm.b, "cold iron is darker on every channel")
	_check(absf(cold.r - cold.b) < absf(warm.r - warm.b), "...and nearer grey")
	_check(is_equal_approx(MachineLook.glyph_cells_for(MachineLook.GLYPH_BOX_PX), 1.0), "a box the glyph was authored for is scale 1")
	_check(is_equal_approx(MachineLook.glyph_cells_for(10.0), 0.5), "half the box, half the scale")


## Every drawer runs inside a real draw pass: every machine kind at both states and both detail tiers,
## every status mark and fix glyph, every carried item. A missing member or a bad polygon is an engine
## ERROR the runner counts, which is what this exists to trip.
func _test_everything_draws_in_a_real_redraw() -> void:
	var grid: TileGrid = _flat_grid(30, 40)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(Interface.new(grid, Body.new(Fx.from_int(80), Fx.from_int(60)), Mining.new()), MaterialLook.new(), cam)
	var ids: Array[StringName] = _items()
	var drawn: Array = [0]
	view.add_painter(func(_f: Frame, ci: CanvasItem) -> void:
		var i: int = 0
		for kind: String in MachineGlyphs.KINDS:
			for active: bool in [true, false]:
				MachineLook.draw_casing(ci, Vector2(float(i) * 40.0, 0.0), 32.0, Color(0.5, 0.5, 0.5), active, i % 2 == 0, kind)
				MachineGlyphs.draw(ci, Vector2(float(i) * 40.0 + 16.0, 16.0), kind, 1.0, active, 0.37)
			i += 1
		for s: StringName in StatusLook.LOOK:
			StatusLook.draw_mark(ci, Vector2(float(i) * 12.0, 60.0), 4.0, StatusLook.LOOK[s]["mark"], StatusLook.LOOK[s]["color"])
			StatusLook.draw_fix_glyph(ci, Vector2(float(i) * 12.0, 80.0), 11.0, StatusLook.LOOK[s]["fix"], Color.WHITE)
			i += 1
		for id: StringName in ids:
			ItemLook.draw(ci, Vector2(float(i) * 24.0, 120.0), 20.0, id)
			i += 1
		drawn[0] = i)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(drawn[0]) >= MachineGlyphs.KINDS.size() + StatusLook.LOOK.size() + ids.size(),
		"every kind, status and item drew to completion inside a real draw pass (%d draws)" % int(drawn[0]))
	view.queue_free()
