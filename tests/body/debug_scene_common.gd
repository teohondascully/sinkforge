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


## "no aim this tick", written into BOTH aim columns. A sentinel row rather than a ninth boolean column,
## and an out-of-world value rather than a plausible one like -1 or 0: cell (0,0) is a legitimate aim, and
## a sentinel a real cell could equal is the guard-that-cannot-be-false trap this ledger keeps recording.
const NO_AIM_ROW: int = -2147483648


## `reveal_scene.gd`'s V2 dialect (Slice 1, D0195): the five V1 fields plus the mining hold and the aimed
## cell. Aim is state-affecting input under cursor-aim -- which cell a hold charges depends on it -- so a
## recording that omitted it could not be replayed. Kept beside `record_row` rather than replacing it:
## `play_scene.gd` still writes the five-field shape and has no aim to record.
static func record_reveal_row(tick: int, move_dir: int, jump_pressed: bool, jump_held: bool,
		dig_pressed: bool, mine_held: bool, has_aim: bool, aim_col: int, aim_row: int) -> PackedStringArray:
	var col: int = aim_col if has_aim else NO_AIM_ROW
	var row: int = aim_row if has_aim else NO_AIM_ROW
	return PackedStringArray([str(tick), str(move_dir), str(jump_pressed), str(jump_held),
		str(dig_pressed), str(mine_held), str(col), str(row)])


## Counts DISTINCT colours in a coarse sample of a captured image and pushes an error if the frame is
## effectively uniform. Distinct-count, not a mean: a mean brightness reads a nearly-black frame with one
## bright corner as "dark but fine", while the failure this guards (nothing drawn yet) is specifically that
## every pixel is the SAME. Threshold is 4 rather than 1 so an almost-empty frame -- background plus a
## couple of stray cells -- still trips it. Reported via `push_error` so `tools/run_gd_test.sh` and a human
## both see it; it deliberately does not fail the run, because a legitimately blank capture (a camera
## pointed off-world) is a real thing to want to look at.
##
## MOVED HERE from `reveal_scene.gd` (D0197) when that file crossed gate 3's 400-line limit, and it belongs
## here regardless: it is a property of the capture format, not of one scene.
##
## WHAT IT CANNOT CATCH, stated because a guard trusted past its range is worse than none: "not blank" is
## not "shows its subject". A mis-aimed camera pointed at a wall of textured clay reported 159 distinct
## colours while the body and the whole mined shaft sat outside the frame (D0197). That is why the caller
## also prints its camera and body position.
static func warn_if_blank(img: Image, path: String) -> void:
	var seen: Dictionary = {}
	var step: int = maxi(1, img.get_width() / 64)
	for x: int in range(0, img.get_width(), step):
		for y: int in range(0, img.get_height(), step):
			seen[img.get_pixel(x, y).to_rgba32()] = true
	if seen.size() < 4:
		push_error(("capture: the frame has only %d distinct colour(s) -- it is blank or near-blank. The " +
			"screenshot was still written to %s, but do not read it as a picture of the world. Likeliest " +
			"cause: the capture tick is too early for the renderer, or the camera is pointed off-world " +
			"(docs/DECISIONS_LEDGER.md D0121, D0189, D0197).") % [seen.size(), path])
	else:
		print("reveal_scene: capture has %d distinct colours in a %d-px sample grid" % [seen.size(), step])


## `what` is passed in and compared by the caller (Godot's `NOTIFICATION_WM_CLOSE_REQUEST` constant is a
## `Node` member, not visible from this `RefCounted` static context) -- this only shares the two-line
## flush-and-quit action itself.
static func finish_and_quit(flush: Callable, tree: SceneTree) -> void:
	flush.call()
	tree.quit(0)


## D0215. How far down the body is, 0 at the row it spawned on and 1 at the world's floor -- the one
## number `view/audio/score.gd` needs, and the reason that file could be lifted before any renderer
## exists. It lives HERE rather than in `Score` because `tools/layer_lint/layer_lint.py` gives `view`
## access to `interface` and `core` only: a `view/` file may not read `Body` or `TileGrid`, so the scene
## derives the fraction and hands over a float. That is the same shape every remaining lift will need.
##
## Measured from the SPAWN row, not from row 0. A shaft site spawns the body partway down already, so
## against row 0 the score would start halfway through its own arc and the descent would move it barely
## at all -- the mix has to span the part of the world the player actually travels.
static func depth_fraction(body_row: int, spawn_row: int, grid_rows: int) -> float:
	var span: int = maxi(1, grid_rows - spawn_row)
	return clampf(float(body_row - spawn_row) / float(span), 0.0, 1.0)
