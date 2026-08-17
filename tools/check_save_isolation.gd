extends SceneTree

## Harness layer: NO TEST MAY WRITE THE PLAYER'S SAVE. This is a data-safety gate, not a
## behaviour check, and it is deliberately the cheapest layer in the suite (a source scan, no scene, no
## engine boot) because a gate that costs three minutes gets skipped.
##
## The defect it exists to stop actually happened: `check_saveload.gd` drove the real `_save_game()` at
## the real `user://sinkforge.save` and then `DirAccess.remove_absolute`d it, so running the advertised
## harness on a developer machine overwrote and then DELETED that developer's game. The runner's own
## header promised the opposite — "layers write only uniquely-named user:// files" — which is the worst
## kind of comment: a test with no runner, asserting a safety property nobody checked.
##
## Three properties, all provable from source alone:
##   1. `MainView` still SAVES TO THE PRODUCTION SLOT by default. The fix must not be "move where players
##      save" — that would trade one data-loss bug for another, silently orphaning every existing save.
##   2. Nothing under tools/ or tests/ NAMES the production slot. A layer cannot delete a path it cannot
##      spell, and a literal is the only way to reach it now that the constant is an overridable static.
##   3. Any layer that boots the real scene AND reaches the save path OVERRIDES `MainView.save_path`
##      first. This is the one that catches the next check_saveload — a new layer that calls `_save_game()`
##      inherits the production default unless it says otherwise, and here is where it gets told.
##
## Non-vacuity (see the architecture handover §5): a source scan that matches nothing passes trivially, so
## this asserts the scan found files, found the slot literal where it MUST appear (scenes/main.gd), and
## found at least one real save-driving layer to hold to property 3.
##   godot --headless --path . --script res://tools/check_save_isolation.gd

## The player's slot. Matched WHOLE: `user://test_sinkforge.save` (test_sim's own isolated round-trip
## file) ends with the production filename and is entirely legitimate, so a filename-only match would
## have condemned it. This file necessarily spells the literal it hunts for, so it is excluded from its
## own scan — honestly, because the matcher's non-vacuity is proved against scenes/main.gd instead.
const SLOT: String = "user://sinkforge.save"
const SELF: String = "res://tools/check_save_isolation.gd"

const SCAN_DIRS: Array[String] = ["res://tools", "res://tests"]
const MAIN_SRC: String = "res://scenes/main.gd"

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


## Every .gd under `dir`, as path → source text.
func _sources(dir: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for name: String in d.get_files():
		if not name.ends_with(".gd"):
			continue
		var path: String = dir + "/" + name
		out[path] = FileAccess.get_file_as_string(path)
	return out


func _initialize() -> void:
	# --- 1. the production default is UNCHANGED -------------------------------------------------
	# Read it out of source rather than off the class: this layer must stay a source scan (no engine,
	# no scene), and the declaration is what a future edit would break. This doubles as the matcher's
	# non-vacuity proof — `contains(SLOT)` is shown to fire on a file that really does name the slot.
	var main_src: String = FileAccess.get_file_as_string(MAIN_SRC)
	_check(main_src.length() > 1000, "scenes/main.gd read (%d chars)" % main_src.length())
	_check(main_src.contains(SLOT), "MainView still names the production slot (players keep their saves)")
	_check(main_src.contains("static var save_path"),
		"MainView.save_path is an overridable static, not a const (the harness can point elsewhere)")

	# --- 2/3. no fixture reaches the production slot --------------------------------------------
	var scanned: int = 0
	var offenders: Array[String] = []
	var touchers: Array[String] = []
	var unguarded: Array[String] = []
	for dir: String in SCAN_DIRS:
		var srcs: Dictionary = _sources(dir)
		for path_v: Variant in srcs.keys():
			var path: String = String(path_v)
			if path == SELF:
				continue
			var src: String = srcs[path_v]
			scanned += 1
			if src.contains(SLOT):
				offenders.append(path)
			# Anything that can REACH the slot — by naming the static, or by driving the controller's
			# save verbs, which read it — has to redirect it first. Deliberately broader than "boots
			# main.tscn": `DirAccess.remove_absolute(MainView.save_path)` in a fixture that never boots
			# the scene would delete the save just as dead.
			var touches: bool = src.contains("MainView.save_path") or src.contains("MainView.SAVE_PATH") \
				or src.contains("_save_game(") or src.contains("_load_game(")
			if touches:
				touchers.append(path)
				if not src.contains("MainView.save_path ="):
					unguarded.append(path)

	_check(scanned >= 40, "the scan actually read the harness (%d .gd files)" % scanned)
	_check(offenders.is_empty(), "no fixture names the production slot%s"
		% ("" if offenders.is_empty() else " — " + ", ".join(offenders)))
	_check(not touchers.is_empty(),
		"at least one layer reaches the save path (%s) — the override rule is not vacuous"
			% ", ".join(touchers))
	_check(unguarded.is_empty(), "every save-reaching layer overrides MainView.save_path%s"
		% ("" if unguarded.is_empty() else " — " + ", ".join(unguarded)))

	if _failures == 0:
		print("check_save_isolation: PASS")
		quit(0)
	else:
		printerr("check_save_isolation: %d FAILURE(S)" % _failures)
		quit(1)
