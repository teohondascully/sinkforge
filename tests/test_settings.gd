extends "res://tests/test_base.gd"

## `shell/settings.gd` and `shell/settings_bindings.gd`, lifted from `legacy/scenes/settings.gd` and
## SPLIT IN TWO on the way over (`docs/DECISIONS_LEDGER.md` D0227). A split is the porting change most
## likely to be silently wrong, and its characteristic failure is not a parse error: it is **two copies
## of what was one piece of state.** `SettingsBindings` reading its own `bindings` dict instead of
## `Settings.bindings` would parse, run, pass any single-file test, and quietly lose every rebind the
## moment the other half saved. So the first test writes through one class and reads through the other.
##
## `persist` is left FALSE throughout and `path` is pointed at `user://` scratch anyway, so nothing here
## can read or clobber a real settings file -- the property the original file was built around
## ("a scripted run works from pure defaults"), asserted rather than assumed.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_settings.gd

const SCRATCH_PATH: String = "user://test_settings_scratch.cfg"


func _initialize() -> void:
	_test_the_two_halves_share_one_bindings_map()
	_test_persist_false_writes_no_file_at_all()
	_test_audio_levels_are_dB_offsets_with_full_meaning_zero()
	_test_level_resolves_every_row_the_page_draws()
	_test_event_labels_are_unique_because_collision_detection_compares_them()
	_test_specs_of_falls_back_to_defaults_and_hands_back_a_copy()
	_finish("settings")


## The assertion the split exists to be checked by.
func _test_the_two_halves_share_one_bindings_map() -> void:
	Settings.bindings = {}
	Settings.bindings[&"sf_jump"] = [{"key": KEY_W}]
	var seen: Array = SettingsBindings.specs_of(&"sf_jump")
	_check(seen.size() == 1 and (seen[0] as Dictionary).get("key") == KEY_W,
		"SettingsBindings reads the override written through Settings -- one map, not two (got %s)" % [seen])
	# And the other direction, which is the one a duplicated dict would actually break.
	Settings.bindings = {}
	SettingsBindings.reset_bindings()
	_check(Settings.bindings.is_empty(),
		"reset_bindings clears the map Settings owns, so a later save writes no stale override (%d left)"
		% Settings.bindings.size())


func _test_persist_false_writes_no_file_at_all() -> void:
	var was_persist: bool = Settings.persist
	var was_path: String = Settings.path
	Settings.persist = false
	Settings.path = SCRATCH_PATH
	if FileAccess.file_exists(SCRATCH_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PATH))
	Settings.save_settings()
	var wrote: bool = FileAccess.file_exists(SCRATCH_PATH)
	_check(not wrote,
		"save_settings with persist=false writes nothing -- a scripted run can never clobber the real settings file (file exists: %s)" % wrote)

	# The control. Without it, "no file" is equally explained by a broken path or a broken writer, and
	# the assertion above would pass on a save_settings() that could not write at all.
	Settings.persist = true
	Settings.save_settings()
	var wrote_now: bool = FileAccess.file_exists(SCRATCH_PATH)
	_check(wrote_now,
		"CONTROL: with persist=true the same call DOES write, so the line above measures the gate and not a broken writer (file exists: %s)" % wrote_now)
	if wrote_now:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_PATH))
	Settings.persist = was_persist
	Settings.path = was_path


func _test_audio_levels_are_dB_offsets_with_full_meaning_zero() -> void:
	var was: float = Settings.music
	Settings.music = 1.0
	_check(absf(Settings.music_db()) < 0.001,
		"a full slider is 0 dB, an OFFSET of nothing -- not an absolute level (got %.4f)" % Settings.music_db())
	Settings.music = 0.0
	var floored: float = Settings.music_db()
	_check(floored < -50.0,
		"a slider at zero floors near silence rather than at -inf, which would be an invalid bus value (got %.2f)" % floored)
	Settings.music = 0.5
	var half: float = Settings.music_db()
	_check(half < 0.0 and half > floored,
		"a half slider sits strictly between the two, so the curve is monotone and not a two-state switch (got %.2f)" % half)
	Settings.music = was


func _test_level_resolves_every_row_the_page_draws() -> void:
	var was := [Settings.master, Settings.sound, Settings.ambience, Settings.music]
	Settings.master = 0.11
	Settings.sound = 0.22
	Settings.ambience = 0.33
	Settings.music = 0.44
	var got := [Settings.level("master"), Settings.level("sound"),
		Settings.level("ambience"), Settings.level("music")]
	# Four DISTINCT values on purpose: with equal ones, a `level()` that returned the same field for
	# every id would pass. The whole risk in that function is a mis-wired match arm.
	_check(got == [0.11, 0.22, 0.33, 0.44],
		"each id resolves to its OWN field -- distinct values so a match arm returning the wrong one cannot pass (got %s)" % [got])
	Settings.master = was[0]
	Settings.sound = was[1]
	Settings.ambience = was[2]
	Settings.music = was[3]


## Not cosmetics: `rebind` and `reconcile` both decide whether two bindings collide by comparing these
## strings, so two keycodes sharing a label silently become the same key to the resolver.
func _test_event_labels_are_unique_because_collision_detection_compares_them() -> void:
	var labels: Dictionary = {}
	var collisions: Array[String] = []
	for code: int in Settings_key_codes():
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		var label: String = SettingsBindings.event_label(ev)
		if labels.has(label):
			collisions.append("%s shared by %d and %d" % [label, labels[label], code])
		labels[label] = code
	print("  [OBSERVED] %d keycap labels, %d collision(s)" % [labels.size(), collisions.size()])
	_check(collisions.is_empty(),
		"no two keycodes in the table share a label (%d collision(s)%s)"
		% [collisions.size(), "" if collisions.is_empty() else ": " + collisions[0]])
	# The pair the original file calls out by name as the reason the table exists at all.
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	var num_enter := InputEventKey.new()
	num_enter.physical_keycode = KEY_KP_ENTER
	_check(SettingsBindings.event_label(enter) != SettingsBindings.event_label(num_enter),
		"ENTER and the keypad's are distinct labels (%s vs %s) -- merging them would make one unbindable"
		% [SettingsBindings.event_label(enter), SettingsBindings.event_label(num_enter)])


func Settings_key_codes() -> Array:
	var codes: Array = []
	for code: Variant in SettingsBindings.KEY_CAPS:
		codes.append(int(code))
	return codes


func _test_specs_of_falls_back_to_defaults_and_hands_back_a_copy() -> void:
	Settings.bindings = {}
	var defaults: Dictionary = Controls.defaults()
	var action: StringName = Controls.JUMP
	var from_defaults: Array = SettingsBindings.specs_of(action)
	_check(defaults.has(action) and not from_defaults.is_empty(),
		"an action with no override reports its DEFAULT specs, not an empty list that would erase the binding on write-back (%d spec(s))" % from_defaults.size())
	# A returned reference rather than a copy is the other way this function erases a binding: the
	# caller mutates the list, and `Controls.defaults()` itself is what changed.
	from_defaults.clear()
	_check(not SettingsBindings.specs_of(action).is_empty(),
		"the returned array is a COPY -- clearing it does not empty the defaults every later call reads")
