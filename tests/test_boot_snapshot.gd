extends "res://tests/test_base.gd"

## `shell/session.gd`'s `new_game` phases and the world snapshot (D0518). Two pins. (1) `Session.new_game`
## composes `WorldSeeder.load_world`'s steps itself so the boot line can clock each one; the world it makes
## must be `load_world`'s world, stamped the same way, and the settle tick count it reports must be the
## seeder's own -- the composition and the sim's door may not drift apart. (2) The director's gate on a
## boot snapshot: a fresh game captured, written, read back and rebuilt through `Session.from_save` signs
## identically to the generated one -- the restored world agreeing with its own rebuild -- and stays
## identical 600 ticks on, with the signature having MOVED over those ticks so the equality is not a no-op.
## Every disk write is a scratch path; the real slot is never touched.

const SEED: int = 20260826
const START: StringName = &"tutorial"
const SCRATCH: String = "user://test_boot_snapshot_scratch.save"
const TICKS: int = 600

var phases: Dictionary = {}
var door: Interface = null


func _initialize() -> void:
	_test_new_game_clocks_its_phases_and_composes_load_world()
	_test_a_fresh_game_snapshot_restores_to_the_same_session_and_future()
	_finish("boot_snapshot")


func _test_new_game_clocks_its_phases_and_composes_load_world() -> void:
	door = Session.new_game(StrataData.SHALLOW_CLAY, SEED, START, phases)
	_check(door != null, "the tutorial start takes the real site (%s)" % WorldSeeder.last_refusal)
	var missing: Array[String] = []
	for key: String in Session.PHASES:
		if not (phases.get(key) is int) or int(phases[key]) < 0:
			missing.append(key)
	_check(missing.is_empty(), "every phase is clocked in milliseconds, none negative (missing %s; got %s)" % [missing, phases])
	_check(int(phases.get(Session.PHASE_SETTLE_TICKS, 0)) > 0, "the settle reports its tick count (%d)" % int(phases.get(Session.PHASE_SETTLE_TICKS, 0)))
	print("BOOT_SNAPSHOT phases_ms %s" % phases)
	# The sim's own door, stamped the same way: the shell's composition must be this world exactly.
	var theirs: World = WorldSeeder.load_world(StrataData.SHALLOW_CLAY, SEED)
	var items: Items = Items.new(theirs)
	var machines: Machines = Machines.new()
	machines.attach_to(items)
	_check(WorldSeeder.stamp(theirs, items, machines, START, &"shallow_clay"), "load_world's world takes the same start")
	var mine: World = door.services()["world"]
	_check(mine.state_signature() == theirs.state_signature(),
		"Session.new_game's world IS WorldSeeder.load_world's, by signature (%s vs %s)" % [_short(mine.state_signature()), _short(theirs.state_signature())])
	_check(int(phases[Session.PHASE_SETTLE_TICKS]) == WorldSeeder.settled_ticks,
		"...and it settled the aquifers for the seeder's own count of ticks (%d vs %d)" % [int(phases[Session.PHASE_SETTLE_TICKS]), WorldSeeder.settled_ticks])


func _test_a_fresh_game_snapshot_restores_to_the_same_session_and_future() -> void:
	if door == null:
		_check(false, "no fresh game to snapshot")
		return
	var env: Dictionary = Session.capture(door)
	DirAccess.remove_absolute(SCRATCH)   # a stale file from an aborted run would make this write keep a .bak
	_check(SaveGame.write(SCRATCH, env) and FileAccess.file_exists(SCRATCH), "the fresh game's envelope is written to the scratch path")
	var back: Dictionary = SaveGame.read(SCRATCH)
	var bytes: int = FileAccess.get_file_as_bytes(SCRATCH).size()
	DirAccess.remove_absolute(SCRATCH)   # the envelope is in hand; nothing of this suite stays on disk
	_check(SaveGame.last_read == SaveGame.Read.OK and not FileAccess.file_exists(SCRATCH), "...and reads back OK (%d bytes), the scratch file removed" % bytes)
	var restored: Interface = Session.from_save(back)
	_check(restored != null, "Session.from_save rebuilds the session without generating (%s)" % SaveGame.last_invalid)
	if restored == null:
		return
	var rw: World = restored.services()["world"]
	_check(rw.state_signature() == rw.recomputed_signature(), "the restored world's running signature agrees with a rebuild from its planes")
	var at_boot: String = door.state_signature()
	_check(restored.state_signature() == at_boot,
		"the restored session signs as the generated one, every part (%s vs %s)" % [_short(at_boot), _short(restored.state_signature())])
	# The grid's seed is a LABEL after generation (the observation's `world_seed`, the envelope, the
	# invariants' records) that no signature covers and no tick draws from: a restore that mislabelled
	# it survived both pins here, so it is checked by name.
	var fresh_seed: int = (door.services()["world"] as World).grid.seed
	_check(rw.grid.seed == fresh_seed, "the restored grid carries the generated seed (%d vs %d)" % [rw.grid.seed, fresh_seed])
	for _i: int in TICKS:
		door.apply(Command.move(InputFrame.new()))
		restored.apply(Command.move(InputFrame.new()))
	_check(door.state_signature() != at_boot, "%d empty-input ticks moved the generated session (the equality below is not a no-op)" % TICKS)
	_check(restored.state_signature() == door.state_signature(),
		"...and the restored session moved to the same place (%s vs %s)" % [_short(door.state_signature()), _short(restored.state_signature())])


func _short(sig: String) -> String:
	return sig.sha256_text().substr(0, 12)
