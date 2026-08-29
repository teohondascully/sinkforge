class_name DebugSceneCommon
extends RefCounted

## Shared by `tests/body/play_scene.gd` and `tests/body/reveal_scene.gd`. Both debug scenes record one
## PackedStringArray row per tick (four fixed fields plus one mode-specific field -- `mantle_hold` for
## play_scene, `dig_pressed` for reveal_scene) and flush-and-quit identically on `_notification`'s
## `NOTIFICATION_WM_CLOSE_REQUEST`. Extracted once `tools/quality_check/duplication.py`'s own gate
## caught both as an exact-shape duplicate cluster (`docs/DECISIONS_LEDGER.md` D0116) -- reveal_scene.gd
## was deliberately modeled closely on play_scene.gd's own shape, which is exactly the case this gate
## exists to catch, so the fix is real deduplication, not a new exclusion.


static func record_row(tick: int, move_dir: int, jump_pressed: bool, jump_held: bool, last_field: bool) -> PackedStringArray:
	return PackedStringArray([str(tick), str(move_dir), str(jump_pressed), str(jump_held), str(last_field)])


## `what` is passed in and compared by the caller (Godot's `NOTIFICATION_WM_CLOSE_REQUEST` constant is a
## `Node` member, not visible from this `RefCounted` static context) -- this only shares the two-line
## flush-and-quit action itself.
static func finish_and_quit(flush: Callable, tree: SceneTree) -> void:
	flush.call()
	tree.quit(0)
