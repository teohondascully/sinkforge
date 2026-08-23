extends "res://tools/check_base.gd"

## Harness layer: LIVE save/load. Boots the REAL scene, saves via the same method F5
## drives, damages the world (digs cells, moves the body, spends items), loads via F9's method, and
## asserts the world + body came back EXACTLY — the in-scene proof the sim tests can't give (renderer
## repaint, player restore, the user:// file round-trip inside a running game). HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_saveload.gd
##
## RUNS ON ITS OWN FILE. It used to drive the real slot and then delete it, so the one command the
## project told everyone to run destroyed the developer's game. The isolation is one assignment, made
## before the scene is instantiated so no boot-time read can see the production default; the layer that
## keeps it that way is `tools/check_save_isolation.gd`.

const SCENE: String = "res://scenes/main.tscn"
const TEST_SLOT: String = "user://check_saveload.save"

var _main: MainView
var _frames: int = 0
var _solid_before: int = 0
var _inv_before: int = 0
var _pos_before: Vector2


func _initialize() -> void:
	Engine.max_fps = 120
	MainView.save_path = TEST_SLOT          # BEFORE the scene exists: nothing may read the real slot
	_sweep()                                # a stale file from a previous run must not be mistaken for this one's
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	process_frame.connect(_on_frame)


## The isolated slot AND its two companions. An atomic write leaves a `.bak` beside the save and can
## leave a `.tmp` if it failed, so "delete the save file" is no longer one path — and a fixture that
## tidies only the file it first thought of leaves litter in `user://` for the next run to trip over.
func _sweep() -> void:
	for suffix: String in ["", SaveGame.TMP_SUFFIX, SaveGame.BAK_SUFFIX]:
		DirAccess.remove_absolute(TEST_SLOT + suffix)

func _on_frame() -> void:
	_frames += 1
	if _frames == 10:                                     # let the body land + the world settle
		var sim: FactorySim = _main.sim
		sim.inventory[&"ore"] = 7
		sim.total_produced[&"ore"] = int(sim.total_produced.get(&"ore", 0)) + 7
		_solid_before = sim.solid.size()
		_inv_before = int(sim.inventory.get(&"ore", 0))
		_pos_before = _main._player.position
		_main._save_game()
		return
	if _frames == 14:
		# Damage everything the save covers: dig a scar, spend the pack, move the body far away.
		var sim: FactorySim = _main.sim
		var dug: int = 0
		for cell: Variant in sim.solid.keys():
			if sim.mine(cell) != &"":
				dug += 1
			if dug >= 12:
				break
		sim.inventory.erase(&"ore")
		_main._player.position = _pos_before + Vector2(300.0, -200.0)
		_check(sim.solid.size() == _solid_before - 12, "the scar landed (world changed)")
		return
	if _frames == 18:
		_main._load_game()
		return
	if _frames == 26:                                     # a few frames later: repaint done, state settled
		var sim: FactorySim = _main.sim
		_check(sim.solid.size() == _solid_before, "the dug scar healed — terrain restored exactly")
		_check(int(sim.inventory.get(&"ore", 0)) == _inv_before, "the pack restored")
		_check(_main._player.position.distance_to(_pos_before) < 48.0, "the body is back where it saved")
		var made: int = int(sim.total_produced.get(&"ore", 0)) - int(sim.total_consumed.get(&"ore", 0))
		var present: int = int(sim.inventory.get(&"ore", 0))
		for pile: Variant in sim.ground.values():
			present += int((pile as Dictionary).get(&"ore", 0))
		present += int(sim.sink.get(&"ore", 0))
		for m: MachineState in sim.machines:
			present += int(m.input_buffer.get(&"ore", 0)) + int(m.output_buffer.get(&"ore", 0))
		_check(present == made, "conservation holds across the live round-trip (present=%d net=%d)" % [present, made])
		# The round-trip must have gone through a FILE, not just memory — otherwise this layer proves
		# nothing about the on-disk format, and it would still pass if the path override had quietly
		# sent the save somewhere that never got written.
		_check(FileAccess.file_exists(TEST_SLOT), "the round-trip went through the isolated slot on disk")
		_check(not FileAccess.file_exists(TEST_SLOT + SaveGame.TMP_SUFFIX),
			"the atomic write left no .tmp behind — the temp file was promoted, not abandoned")

		# THE CONTROLLER DOES NOT OWN THE SEED. `check_save_durability` proves SaveGame carries a loaded
		# world's seed through a re-save; it cannot prove that the SCENE doesn't stamp its own copy over
		# it afterwards, which is exactly where the bug lived — `_save_game()` wrote `data["world_seed"]
		# = _world_seed` from a controller field that a load never updated. So: move the sim's seed out
		# from under the controller, press the real save verb, and read the file back.
		var moved: int = sim.world_seed + 4242
		sim.world_seed = moved
		_main._save_game()
		_check(int(SaveGame.read(TEST_SLOT).get("world_seed", -1)) == moved,
			"F5 saves the seed the SIM was built with, not a second copy the controller kept")
		_sweep()
		_verdict("check_saveload")
