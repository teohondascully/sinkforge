extends "res://tests/test_base.gd"

## `view/hud/key_legend.gd` — the bottom-left legend that teaches itself out of existence (D0297,
## LEGACY_GAP Lane H).
##
## The whole design is a DISAPPEARANCE, so the suite is about it happening at the right time and not
## before: one row retires per verb demonstrated, the others survive, and the line goes away entirely only
## when the last one has. Each of those is an absence, so each carries the positive control that makes it
## a measurement rather than a chip that never drew.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_key_legend.gd


func _initialize() -> void:
	_test_every_row_names_a_binding_that_actually_exists()
	_test_a_fresh_legend_shows_every_row()
	_test_each_verb_retires_its_own_row_and_only_its_own()
	_test_the_line_disappears_once_there_is_nothing_left_to_teach()
	_test_a_nudge_does_not_count_as_having_walked()
	_test_an_incomplete_frame_teaches_nothing()
	_finish("key_legend")


func _obs() -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.on_floor = true
	return o


func _frame(o: Interface.Observation) -> Frame:
	var f := Frame.new()
	f.obs = o
	f.look = MaterialLook.new()
	return f


## THE ROW THAT KEEPS THE TABLE HONEST. Legacy's five hints are grapple, drop, craft, map and help — not
## one of which exists here — so this table had to be re-authored, and a re-authored table is exactly
## where a label for a key nothing is bound to survives forever. Every id must be a real `Controls`
## action, checked against `Controls`' own binding map rather than against a list written here.
func _test_every_row_names_a_binding_that_actually_exists() -> void:
	var bound: Dictionary = Controls.defaults()
	_check(not bound.is_empty(), "sanity: Controls reports its bindings (%d actions)" % bound.size())
	var orphans: Array[String] = []
	for row: Dictionary in KeyLegend.ROWS:
		if not bound.has(row["id"]):
			orphans.append(String(row["id"]))
	_check_over(KeyLegend.ROWS.size(), orphans.is_empty(),
		"every legend row names a bound action (%d orphan: %s)" % [orphans.size(), orphans])
	_check(KeyLegend.ROWS.size() > 0 and KeyLegend.ROWS.size() < bound.size() + 1,
		"and there are rows to check (%d against %d bound actions)" % [KeyLegend.ROWS.size(), bound.size()])


func _test_a_fresh_legend_shows_every_row() -> void:
	var legend := KeyLegend.new()
	_check(legend.remaining().size() == KeyLegend.ROWS.size(),
		"a fresh legend offers all %d rows (%d)" % [KeyLegend.ROWS.size(), legend.remaining().size()])
	var l: Dictionary = legend.layout(_frame(_obs()), ThemeDB.fallback_font)
	_check(not l.is_empty(), "and it lays out (got %s)" % l)
	_check(String(l["text"]).contains(KeyLegend.SEPARATOR),
		"with legacy's separator between the rows (%s)" % l["text"])
	_check((l["at"] as Vector2).y > UiTheme.CANVAS.y * 0.5 and (l["at"] as Vector2).x < UiTheme.CANVAS.x * 0.5,
		"in the bottom-LEFT of the canvas (%s of %s)" % [l["at"], UiTheme.CANVAS])


## ONE VERB, ONE ROW. A legend that retired everything on the first frame of movement would look correct
## for the rest of the session and teach nothing, and a `remaining()` count alone cannot tell that from
## the right behaviour — so each verb is posed alone and the OTHER rows are checked to be still there.
func _test_each_verb_retires_its_own_row_and_only_its_own() -> void:
	var cases: Array = [
		{"name": "walking", "id": Controls.LEFT, "pose": func(o: Interface.Observation) -> void:
			o.vel_x = KeyLegend.MOVED_PX_PER_S * 4},
		{"name": "leaving the floor", "id": Controls.JUMP, "pose": func(o: Interface.Observation) -> void:
			o.on_floor = false},
		{"name": "working rock", "id": Controls.MINE, "pose": func(o: Interface.Observation) -> void:
			o.mining_is_charging = true},
	]
	for c: Dictionary in cases:
		var legend := KeyLegend.new()
		var o: Interface.Observation = _obs()
		(c["pose"] as Callable).call(o)
		_check(legend.note_frame(_frame(o)),
			"%s retires a row, and the call SAYS it did" % c["name"])
		_check(legend.remaining().size() == KeyLegend.ROWS.size() - 1,
			"exactly one row goes (%d of %d left after %s)"
			% [legend.remaining().size(), KeyLegend.ROWS.size(), c["name"]])
		# And it is the RIGHT one. Checked by label, because "one fewer row" is true whichever went.
		var label: String = ""
		for row: Dictionary in KeyLegend.ROWS:
			if row["id"] == c["id"]:
				label = String(row["label"])
		_check(not legend.remaining().has(label),
			"and it is the one for %s (%s) rather than whichever came first" % [c["name"], label])
		# Idempotent: doing the same thing again retires nothing further, so the return value stays
		# meaningful as a "something new happened" signal.
		_check(not legend.note_frame(_frame(o)),
			"and doing it again reports nothing new")


## The point of the whole file. Checked with a CONTROL immediately before it, because "the layout is
## empty" is also what a chip that never worked returns.
func _test_the_line_disappears_once_there_is_nothing_left_to_teach() -> void:
	var legend := KeyLegend.new()
	var o: Interface.Observation = _obs()
	o.vel_x = KeyLegend.MOVED_PX_PER_S * 4
	o.on_floor = false
	o.mining_is_charging = true
	_check(not legend.layout(_frame(_obs()), ThemeDB.fallback_font).is_empty(),
		"CONTROL: with nothing demonstrated the legend is on screen")
	legend.note_frame(_frame(o))
	_check(legend.remaining().is_empty(),
		"after all three verbs there is nothing left (%s)" % [legend.remaining()])
	_check(legend.layout(_frame(o), ThemeDB.fallback_font).is_empty(),
		"and the line is GONE rather than drawn empty -- it has finished its job")


## The threshold is not decoration. A body is nudged by the resolver, shoved by a step-up, and carried a
## fraction of a pixel by rounding; retiring the movement hint on any of that would take the row away
## before the player had moved at all.
func _test_a_nudge_does_not_count_as_having_walked() -> void:
	var legend := KeyLegend.new()
	var o: Interface.Observation = _obs()
	o.vel_x = KeyLegend.MOVED_PX_PER_S / 2
	_check(not legend.note_frame(_frame(o)),
		"half the threshold retires nothing (%d of %d)" % [o.vel_x, KeyLegend.MOVED_PX_PER_S])
	o.vel_x = -KeyLegend.MOVED_PX_PER_S * 4
	_check(legend.note_frame(_frame(o)),
		"and moving LEFTWARD at speed does -- the threshold is on the magnitude, not the sign")


## Each is a real startup state. None may crash, and none may retire a row on nothing.
func _test_an_incomplete_frame_teaches_nothing() -> void:
	var canvas := Node2D.new()
	var legend := KeyLegend.new()
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	_check(not legend.note_frame(no_obs), "a frame with no observation teaches nothing")
	_check(not legend.note_frame(null), "and neither does no frame at all")
	legend.paint(no_obs, canvas)
	legend.paint(null, canvas)
	_check(legend.layout(_frame(_obs()), null).is_empty(), "and it lays out nothing without a font")
	_check(legend.layout(no_obs, ThemeDB.fallback_font).is_empty(),
		"and nothing without an observation either -- the rows would still be there to draw, which is\n		" + "exactly why `paint` reached `draw_string` outside `_draw()` before this guard existed")
	_check(legend.remaining().size() == KeyLegend.ROWS.size(),
		"CONTROL: after all of that every row is still offered (%d) -- an incomplete frame must not "
		% legend.remaining().size() + "quietly retire the legend")
	canvas.free()
