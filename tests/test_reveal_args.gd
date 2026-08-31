extends "res://tests/test_base.gd"

## `tests/body/reveal_args.gd`, D0244. The reveal scene's flags, which until this run could not be tested
## at all: parsing read `OS.get_cmdline_user_args()` from inside the scene, so the only way to ask what
## `--camera=3,4` did was to launch a process and look at a screenshot.
##
## The two branches worth guarding are the ones that fail QUIETLY. `--camera=` converts CELLS to PIXELS,
## and a version that forgot the multiply would put the camera at cell coordinates -- a frame 4x too close
## to the origin, which reads as "the capture is framed oddly" rather than as a parse bug. And a flag the
## parser does not know must be IGNORED, because this scene shares its command line with Godot's own.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_reveal_args.gd


func _initialize() -> void:
	_test_defaults_are_what_the_scene_would_have_used()
	_test_camera_converts_cells_to_pixels()
	_test_unknown_arguments_are_ignored_not_rejected()
	_test_every_flag_is_reachable()
	_finish("reveal_args")


func _test_defaults_are_what_the_scene_would_have_used() -> void:
	var cfg: Dictionary = RevealArgs.parse(PackedStringArray([]))
	_check(cfg["site_id"] == &"reveal_test_dense" and int(cfg["seed"]) == 20260826,
		"an empty argv gives the shipped site and seed (%s, %d)" % [cfg["site_id"], cfg["seed"]])
	_check(int(cfg["screenshot_tick"]) == -1 and not bool(cfg["has_fixed_camera"]),
		"no shutter and no pinned camera by default -- a plain run must not write files")
	_check(int(cfg["bite_radius"]) == -1,
		"bite defaults to -1 (`leave the mining verb alone`), NOT 0 -- 0 is a real, meaningful radius "
		+ "(Slice 1's single-cell blow), so defaulting to it would silently change the game")
	_check(not bool(cfg["sky"]), "and the sky is OFF unless asked for")


## The conversion that would fail quietly. `--camera=col,row` is stated in CELLS and stored in PIXELS.
func _test_camera_converts_cells_to_pixels() -> void:
	var cfg: Dictionary = RevealArgs.parse(PackedStringArray(["--camera=24,4"]))
	var want := Vector2(24.0 * RevealArgs.CELL, 4.0 * RevealArgs.CELL)
	_check(bool(cfg["has_fixed_camera"]), "--camera= pins the camera")
	_check(cfg["fixed_camera"] == want,
		"and converts cells to pixels: got %s, want %s (the raw cell pair would be (24, 4))"
		% [cfg["fixed_camera"], want])
	## A malformed value must not half-apply. `has_fixed_camera` exists as a real bool precisely so a
	## caller never infers "pinned" from a Vector2 that happens to be non-zero (D0194's note).
	var bad: Dictionary = RevealArgs.parse(PackedStringArray(["--camera=24"]))
	_check(not bool(bad["has_fixed_camera"]),
		"a one-part --camera= does not pin anything rather than pinning half of one")


func _test_unknown_arguments_are_ignored_not_rejected() -> void:
	var cfg: Dictionary = RevealArgs.parse(PackedStringArray(
		["--headless", "--path", ".", "--", "--seed=99", "--not-a-flag"]))
	_check(int(cfg["seed"]) == 99,
		"a real flag is still read when surrounded by Godot's own arguments (seed=%d)" % cfg["seed"])
	_check(cfg["site_id"] == &"reveal_test_dense",
		"and the unknown ones changed nothing -- this parser shares a command line and must not refuse it")


## The population check. Every key `defaults()` declares must be reachable by some flag, or the scene has
## a setting nobody can set -- the same shape as a gate with no enforcing code.
func _test_every_flag_is_reachable() -> void:
	var cfg: Dictionary = RevealArgs.parse(PackedStringArray([
		"--screenshot-tick=7", "--screenshot-out=/tmp/x.png", "--site=reveal_test_sparse",
		"--seed=5", "--zoom=2.5", "--camera=1,2", "--bite=3", "--mine-down", "--wide-view", "--sky"]))
	var unmoved: Array = []
	var defaults: Dictionary = RevealArgs.defaults()
	for key: String in defaults:
		if cfg[key] == defaults[key]:
			unmoved.append(key)
	_check(unmoved.is_empty(),
		"every one of the %d settings moved off its default when its flag was passed (unmoved: %s)"
		% [defaults.size(), unmoved])
