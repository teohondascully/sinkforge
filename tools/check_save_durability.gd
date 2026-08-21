extends "res://tools/check_base.gd"

## Harness layer: A SAVE YOU CANNOT LOSE. `check_saveload` proves the happy path: save, damage, load,
## everything came back. This layer proves the UNHAPPY ones, which is where saves actually die: the disk
## fills, the process is killed mid-write, the file is truncated, the envelope is from an older build, the
## world was loaded from one seed and then re-saved under another. None of those were covered by anything,
## and every one of them ended with the player's game gone.
##
## The rule this layer enforces is a single sentence: **AT NO POINT MAY A FAILURE LEAVE THE PLAYER WITH
## LESS THAN THEY HAD.** A failed save keeps the previous save. A damaged slot falls back to the backup. A
## malformed envelope refuses whole rather than half-restoring a running game. An older save opens.
##
## NON-VACUITY. Every assertion here is preceded by the damage it is asserting against (the file really is
## truncated, the envelope really is missing a key, the def really is unresolvable), so none of these can
## pass by never happening. Where an assertion could be satisfied trivially (a "restore refused" that
## refused because the sim was empty to begin with) the layer first proves the state it is protecting is
## non-empty and distinctive.
##
## Runs entirely on `user://check_save_durability*.save`. No scene, no window: this is the save format
## and a bare FactorySim, so it is a couple of seconds.
##   godot --headless --path . --script res://tools/check_save_durability.gd

const SLOT: String = "user://check_save_durability.save"

func _sweep() -> void:
	for suffix: String in ["", SaveGame.TMP_SUFFIX, SaveGame.BAK_SUFFIX]:
		DirAccess.remove_absolute(SLOT + suffix)


## A small world with something distinctive in every field the save covers, so "it came back" is a claim
## about real content rather than about two empty dictionaries comparing equal.
##
## It is also deliberately a world where TIME DOES SOMETHING: a flooded shaft over a column of LOOSE
## backfill, which is the one configuration that weeps (docs/DRIFT.md §4). Without that, every "the two
## futures agree" assertion below would be comparing two worlds in which nothing was ever going to
## happen: true, and worth nothing.
func _world(mark: int) -> FactorySim:
	var sim := FactorySim.new()
	for col: int in range(8, 14):
		for row: int in range(20, 32):
			sim.set_solid(Vector2i(col, row), &"stone")
	for row2: int in range(22, 26):
		sim.solid.erase(Vector2i(10, row2))          # the flooded shaft…
	for row3: int in range(27, 31):
		sim.solid.erase(Vector2i(10, row3))          # …and the dry gallery under it
	sim.add_water(Vector2i(10, 24), FactorySim.WATER_MAX)
	sim.add_water(Vector2i(10, 25), FactorySim.WATER_MAX)
	# THE ONE CELL BETWEEN THEM is your own backfill, packed loose, the exact configuration that weeps:
	# a wet cell above, your fill, open space below. Packed gravel here would hold and nothing would move.
	sim.set_solid(Vector2i(10, 26), &"earth")
	sim.fill[Vector2i(10, 26)] = FactorySim.FILL_LOOSE
	sim.world_seed = mark
	sim.inventory[&"ore"] = mark
	sim.total_produced[&"ore"] = mark
	sim.deposits[Vector2i(9, 27)] = mark * 2
	sim.lode[Vector2i(9, 27)] = &"ore"
	sim.research[&"seal"] = true
	sim._seep_tick = mark % FactorySim.SEEP_INTERVAL
	return sim


func _initialize() -> void:
	_sweep()
	_atomic_write()
	_backup_recovery()
	_transactional_restore()
	_version_migration()
	_no_defaults()
	_phase_equivalence()
	_seed_ownership()
	_backup_generation()
	_sweep()
	if _failures == 0:
		print("check_save_durability: PASS")
		quit(0)
	else:
		printerr("check_save_durability: %d FAILURE(S)" % _failures)
		quit(1)


## 1. THE WRITE IS ATOMIC AND KEEPS THE PREVIOUS SAVE.
func _atomic_write() -> void:
	print("== the write ==")
	var first: Dictionary = SaveGame.capture(_world(11))
	_check(SaveGame.write(SLOT, first), "a first save writes")
	_check(FileAccess.file_exists(SLOT), "…and the slot exists on disk")
	_check(not FileAccess.file_exists(SLOT + SaveGame.TMP_SUFFIX),
		"…with no .tmp left behind (the temp file was promoted, not abandoned)")
	_check(not FileAccess.file_exists(SLOT + SaveGame.BAK_SUFFIX),
		"…and no backup yet, because there was nothing to back up")

	var second: Dictionary = SaveGame.capture(_world(22))
	_check(SaveGame.write(SLOT, second), "a second save writes")
	_check(FileAccess.file_exists(SLOT + SaveGame.BAK_SUFFIX),
		"…and the FIRST save survives as the backup — one bad moment no longer costs two games")
	_check(int(SaveGame.read(SLOT).get("world_seed", -1)) == 22, "the slot holds the newer save")
	var bak: Dictionary = SaveGame._read_file(SLOT + SaveGame.BAK_SUFFIX)
	_check(int(bak.get("world_seed", -1)) == 11, "…and the backup holds the older one, intact")

	# THE DISK-FULL SHAPE, as close as a test can get to it: hand `write` a path it cannot open, and
	# assert the existing save is byte-identical afterwards. The old writer opened the real slot in WRITE
	# mode as its FIRST act, so this exact scenario truncated the player's game to zero before failing.
	var before: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	_check(before.size() > 0, "there is a real save on disk to protect (%d bytes)" % before.size())
	var blocked: String = "user://check_save_durability_nodir/deeper/still.save"
	_check(not SaveGame.write(blocked, SaveGame.capture(_world(33))),
		"a save into an unopenable path FAILS rather than half-succeeding")
	_check(FileAccess.get_file_as_bytes(SLOT) == before,
		"…and the existing save is byte-for-byte untouched by that failure")

	# A VARIANT THAT LANDS SHORT. Write something that is not an envelope and prove `write` catches it on
	# the readback instead of promoting it over the good save. This is the guard against the readback
	# being decorative: remove the `_valid_envelope` check in `write` and this assertion goes red.
	_check(not SaveGame.write(SLOT, {"version": 2, "junk": true}),
		"an envelope that fails its own readback validation is NOT promoted")
	_check(FileAccess.get_file_as_bytes(SLOT) == before,
		"…and again the real save is untouched")
	_check(not FileAccess.file_exists(SLOT + SaveGame.TMP_SUFFIX),
		"…and the rejected temp file was cleaned up, not left to rot in user://")


## 2. A DAMAGED SLOT RECOVERS FROM THE BACKUP, AND SAYS SO.
func _backup_recovery() -> void:
	print("== recovery ==")
	_sweep()
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(11))), "an older save is written")
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(22))), "…then a newer one, demoting it to backup")

	# TRUNCATION is the realistic corruption: a process killed mid-write, a disk that filled. Half a
	# binary Variant decodes to null, which the old reader returned as {}, indistinguishable from "this
	# player has never saved", which is exactly the sentence you must not show somebody who just lost an
	# hour.
	var whole: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	var f: FileAccess = FileAccess.open(SLOT, FileAccess.WRITE)
	f.store_buffer(whole.slice(0, whole.size() / 3))
	f.close()
	_check(FileAccess.get_file_as_bytes(SLOT).size() < whole.size(), "the slot is now genuinely truncated")

	var got: Dictionary = SaveGame.read(SLOT)
	_check(int(got.get("world_seed", -1)) == 11, "a truncated slot RECOVERS the previous save from backup")
	_check(SaveGame.last_read == SaveGame.Read.RECOVERED, "…and reports it as a recovery, not as a clean load")

	# BOTH GONE is the one case where the answer really is "you have no save", and it must still not be
	# confused with a player who never had one.
	DirAccess.remove_absolute(SLOT + SaveGame.BAK_SUFFIX)
	_check(SaveGame.read(SLOT).is_empty(), "with the backup gone too, the damaged slot yields nothing")
	_check(SaveGame.last_read == SaveGame.Read.CORRUPT,
		"…reported as CORRUPT, because a file that exists and will not open is not an absent save")
	_sweep()
	_check(SaveGame.read(SLOT).is_empty(), "a slot that was never written yields nothing")
	_check(SaveGame.last_read == SaveGame.Read.NONE, "…reported as NONE — the new player, told the truth")


## 3. RESTORE IS ALL-OR-NOTHING.
func _transactional_restore() -> void:
	print("== the restore ==")
	var live: FactorySim = _world(44)
	var fingerprint: Array = [live.solid.size(), int(live.inventory.get(&"ore", 0)),
		live.world_seed, live.water.size(), live.deposits.size()]
	_check(fingerprint[0] > 0 and fingerprint[1] > 0, "the live sim has real state to protect %s" % [fingerprint])

	# A save from another data set: the terrain would restore fine, the machine def does not exist. The
	# old code caught this one (it resolved defs first), so it is here to stay caught.
	var alien: Dictionary = SaveGame.capture(_world(55))
	alien["machines"] = [{"def": "no_such_machine", "cell": Vector2i(5, 30), "in": {}, "out": {},
		"spoil": {}, "progress": 0.0, "route_toggle": 0, "fuel": 0, "power_factor": 0.0, "fed": 0}]
	_check(not SaveGame.restore(live, alien), "a save naming a machine that no longer exists is refused")
	_check([live.solid.size(), int(live.inventory.get(&"ore", 0)), live.world_seed,
		live.water.size(), live.deposits.size()] == fingerprint, "…and the running game is untouched")

	# THE ONE THE OLD CODE GOT WRONG. `restore` indexed `data["solid"]`, `data["wall"]`, `data["ground"]`
	# and thirteen others with no guard, AFTER it had already assigned `sim.world_seed`. An envelope
	# missing any one of them therefore errored PART WAY IN, leaving the live game with a new seed and
	# old terrain. Each required key is removed in turn and the sim is fingerprinted after every attempt.
	var ablated: int = 0
	for key: String in SaveGame.REQUIRED_KEYS:
		if key == "version":
			continue
		ablated += 1
		var holed: Dictionary = SaveGame.capture(_world(66))
		holed.erase(key)
		var refused: bool = not SaveGame.restore(live, holed)
		var intact: bool = [live.solid.size(), int(live.inventory.get(&"ore", 0)), live.world_seed,
			live.water.size(), live.deposits.size()] == fingerprint
		_check(refused and intact, "an envelope missing \"%s\" is refused WHOLE — nothing was written" % key)
		# …and refused by the PRESENCE gate specifically. Both the presence loop and the type loop under
		# it reject a missing key, so the assertion above passes with the presence loop deleted, which
		# makes it blind to the thing that loop is actually for. It is what refuses CLEANLY: without it
		# the type loop indexes `data[key]` on a key that is not there, and Godot answers with an engine
		# error per miss (measured 2026-08-17: 2 error lines became 16). Naming the reason is what lets a
		# test tell the two guards apart.
		_check(SaveGame.last_invalid == "missing key: %s" % key,
			"…caught by the presence gate, not by an index into a hole (reason: %s)" % SaveGame.last_invalid)

	# The ablation above is driven BY SaveGame.REQUIRED_KEYS, which is also the thing it is testing. Empty
	# that constant and the production presence-gate and this entire loop vanish together, silently, green.
	# A floor is the difference between "every required key is gated" and "there are no required keys".
	# 13 today (REQUIRED_KEYS is 14, less "version" which is skipped). The floor is 10, not 13: dropping a
	# key or two from the envelope is a legitimate schema change and should not turn this red, while gutting
	# the list -- the case that makes both guards evaporate -- cannot get past it.
	_check(ablated >= 10, "the ablation really ran, over the whole required-key set (%d of 13)" % ablated)

	# …and a well-formed one still goes in, so the refusals above are not just "restore never works".
	_check(SaveGame.restore(live, SaveGame.capture(_world(77))), "a complete envelope restores")
	_check(live.world_seed == 77 and int(live.inventory.get(&"ore", 0)) == 77, "…and the state really moved")


## 4. AN OLDER SAVE STILL OPENS, AND THE VERSION GATE STILL BITES.
func _version_migration() -> void:
	print("== versions ==")
	var v1: Dictionary = SaveGame.capture(_world(88))
	v1["version"] = 1
	v1.erase("seep_tick")          # a v1 save predates the field entirely
	var sim := FactorySim.new()
	_check(SaveGame.restore(sim, v1), "a v1 save — written before any of this existed — still loads")
	_check(sim.world_seed == 88 and int(sim.inventory.get(&"ore", 0)) == 88, "…with its world intact")
	_check(sim._seep_tick == 0, "…and the missing seep phase migrates to zero rather than to garbage")

	var future: Dictionary = SaveGame.capture(_world(99))
	future["version"] = SaveGame.VERSION + 1
	var untouched := FactorySim.new()
	_check(not SaveGame.restore(untouched, future),
		"a save from a NEWER build is refused (v%d) — forward compatibility is not free" % [SaveGame.VERSION + 1])
	_check(untouched.solid.is_empty(), "…without touching the sim")

	# EVERY READABLE VERSION HAS A BRANCH THAT ARRIVES. `_valid_envelope` bounds the version to
	# [OLDEST_READABLE, VERSION]; it does not say a migration exists to carry an old one the rest of the
	# way. Bump VERSION to 3 without writing the v2→v3 branch and `_migrate` returns every v2 save
	# unchanged — the gate already said yes, so it loads under v3 semantics with no branch having run and
	# nothing red. The loop is driven by the two constants rather than by a list written here, so the day
	# the next bump lands without its branch this is what says so, and it says which version stalled.
	_check(SaveGame.VERSION > SaveGame.OLDEST_READABLE,
		"there is an older version for the chain to carry at all (v%d..v%d) — the loop is not vacuous"
			% [SaveGame.OLDEST_READABLE, SaveGame.VERSION])
	var unmigrated: Array[String] = []
	for v: int in range(SaveGame.OLDEST_READABLE, SaveGame.VERSION + 1):
		var old: Dictionary = SaveGame.capture(_world(v))
		old["version"] = v
		var landed: int = int(SaveGame._migrate(old).get("version", -1))
		if landed != SaveGame.VERSION:
			unmigrated.append("v%d stops at v%d" % [v, landed])
	_check(unmigrated.is_empty(), "every readable version migrates all the way to v%d%s"
		% [SaveGame.VERSION, "" if unmigrated.is_empty() else " — " + ", ".join(unmigrated)])


## 4b. A FIELD WHOSE ABSENCE WOULD CHANGE THE FUTURE IS REFUSED, NOT DEFAULTED.
##
## `world_seed` used to default to 0 and `seep_tick` to 0, and neither is a truthful reading of "absent".
## Seed 0 does not say "this world had no seed", it says "this world was seeded 0" — and `_commit` then
## re-molds the fine terrain from a number the world was never built with, which is invisible until the
## rock comes back subtly different. Phase 0 does not say "this world had no phase", it says "the next weep
## lands now", which `_phase_equivalence`'s control proves is a different future.
##
## Both were the failure this project keeps finding: THE ERROR PATH RETURNED THE PASSING VALUE. A key went
## missing and the restore SUCCEEDED, so the player opens a world that is quietly not theirs, plays it, and
## saves over the only record of which world it was. A refusal is strictly the safer branch — the file
## stays on disk, where a later build can still read it.
func _no_defaults() -> void:
	print("== no silent defaults ==")
	_check(SaveGame.NO_DEFAULT_KEYS.size() >= 2,
		"there are fields declared un-defaultable (%s) — the loop below is not vacuous"
			% ", ".join(SaveGame.NO_DEFAULT_KEYS))
	for key: String in SaveGame.NO_DEFAULT_KEYS:
		var live: FactorySim = _world(101)
		var mark: Array = [live.solid.size(), live.world_seed, live._seep_tick,
			int(live.inventory.get(&"ore", 0))]
		var holed: Dictionary = SaveGame.capture(_world(202))
		holed.erase(key)
		_check(not SaveGame.restore(live, holed),
			"an envelope with no \"%s\" is REFUSED rather than defaulted" % key)
		_check(SaveGame.last_invalid.contains(key),
			"…and names the field it refused on (%s)" % SaveGame.last_invalid)
		_check([live.solid.size(), live.world_seed, live._seep_tick,
			int(live.inventory.get(&"ore", 0))] == mark,
			"…leaving the running game exactly as it was")

	# THE CONTROL, and the reason this is a LIST rather than a blanket rule. A field whose absence HAS a
	# truthful empty reading must still default, or every older save stops opening. A capture from before
	# the lode and the water existed genuinely had neither, and `{}` says exactly that.
	var pre_lode: Dictionary = SaveGame.capture(_world(303))
	pre_lode.erase("lode")
	pre_lode.erase("lode_max")
	pre_lode.erase("water")
	var older := FactorySim.new()
	_check(SaveGame.restore(older, pre_lode),
		"…while a save from before the lode and the water existed still opens")
	_check(older.lode.is_empty() and older.water.is_empty(),
		"…holding neither of them, which is the truth about that world")

	# THE CASE THAT EXISTS ON SOMEBODY'S DISK: a v1 envelope written before `world_seed` was captured at
	# all (it entered `capture` without a version bump, so the version gate cannot tell those apart from
	# any other v1). There is no honest migration — a seed cannot be invented — so it is refused by name
	# rather than loaded into a world that molds differently and then saved over.
	var ancient: Dictionary = SaveGame.capture(_world(404))
	ancient["version"] = 1
	ancient.erase("seep_tick")      # a v1 save predates the phase: the v1→v2 branch supplies this one
	ancient.erase("world_seed")     # …and predates the seed, which nothing can supply
	var target := FactorySim.new()
	_check(not SaveGame.restore(target, ancient),
		"a v1 save from before the seed was captured is refused, not molded from seed 0")
	_check(SaveGame.last_invalid.contains("world_seed"),
		"…naming the seed as the reason (%s)" % SaveGame.last_invalid)
	_check(target.solid.is_empty(), "…without touching the sim")


## 5. THE SAME FILE PRODUCES THE SAME FUTURE, WHICHEVER WAY YOU GOT TO IT.
## Same-process F9 restores into a sim that has been running; a fresh process restores into a brand new
## one. If any phase counter survives the first path and not the second, one file has two futures, and
## the whole determinism argument this project rests on stops being true at the exact moment a player
## reloads. `_seep_tick` is authoritative and is SAVED; the rate/accumulator readouts are derived and are
## RESET. Either policy is defensible; leaving them wherever the last game happened to stop is not.
func _phase_equivalence() -> void:
	print("== phase ==")
	var envelope: Dictionary = SaveGame.capture(_world(7))
	var saved_phase: int = int(envelope.get("seep_tick", -1))
	_check(saved_phase == 7 % FactorySim.SEEP_INTERVAL,
		"the seep phase is captured (%d), not silently dropped" % saved_phase)

	# The same-process path: a sim that has been ticking, mid-cycle, with a warm rate buffer.
	var warm: FactorySim = _world(3)
	for _i: int in range(40):
		warm.advance(FactorySim.SECONDS_PER_TICK)
	_check(warm._seep_tick != saved_phase or warm._tick_accumulator != 0.0 or warm._rate_tick != 0,
		"the warm sim really is out of phase before the load (seep=%d rate=%d)" % [warm._seep_tick, warm._rate_tick])
	_check(SaveGame.restore(warm, envelope), "the warm sim loads the file")

	# The fresh-process path: a sim that has never ticked.
	var cold := FactorySim.new()
	_check(SaveGame.restore(cold, envelope), "a cold sim loads the same file")

	_check(warm._seep_tick == cold._seep_tick and warm._seep_tick == saved_phase,
		"both paths resume at the SAVED seep phase (%d / %d)" % [warm._seep_tick, cold._seep_tick])
	_check(warm._tick_accumulator == cold._tick_accumulator and warm._tick_accumulator == 0.0,
		"both paths start the sub-tick accumulator at zero")
	_check(warm._rate_tick == cold._rate_tick and warm._rate_samples.size() == cold._rate_samples.size(),
		"both paths start the derived rate readout from the same place")

	# The property all of that exists for: tick them together and they stay together.
	var before: Dictionary = cold.water.duplicate()
	for _j: int in range(FactorySim.SEEP_INTERVAL * 4):
		warm.advance(FactorySim.SECONDS_PER_TICK)
		cold.advance(FactorySim.SECONDS_PER_TICK)
	# NON-VACUITY: a world where nothing was going to happen has two identical futures for free. Prove the
	# clock actually moved this world before claiming the two agree about where it moved to.
	_check(cold.water != before and not cold.water.is_empty(),
		"the water really did seep over that stretch (%d cells → %d)" % [before.size(), cold.water.size()])
	_check(warm.water == cold.water,
		"…so after four seep cycles the two futures are still identical — one file, one future")

	# AND THE CONTROL, which is what makes persisting the phase a fact rather than a preference: two sims
	# holding the same world at DIFFERENT points in the seep cycle must diverge. If this passes trivially
	# (if phase never mattered) then everything above is ceremony and should be deleted rather than
	# believed.
	var phase_a: FactorySim = _world(7)
	var phase_b: FactorySim = _world(7)
	phase_b._seep_tick = phase_a._seep_tick + FactorySim.SEEP_INTERVAL / 2
	var diverged: bool = false
	for _k: int in range(FactorySim.SEEP_INTERVAL * 4):
		phase_a.advance(FactorySim.SECONDS_PER_TICK)
		phase_b.advance(FactorySim.SECONDS_PER_TICK)
		if phase_a.water != phase_b.water:
			diverged = true
	_check(diverged, "…and the seep phase genuinely decides the future — two phases, two worlds")


## 6. THE SEED IS OWNED ONCE.
## Load a world saved under one seed into a session generated under another, re-save, and the file must
## carry the seed its terrain was actually molded with. This is the bug that made a Continue-then-save
## silently rewrite the world's identity, and it is invisible until the NEXT load rebuilds the fine grid
## from the wrong number and the rock comes back subtly different.
func _seed_ownership() -> void:
	print("== the seed ==")
	_sweep()
	var authored: FactorySim = _world(4242)
	_check(SaveGame.write(SLOT, SaveGame.capture(authored)), "a world saved under seed 4242")

	# A different session: a sim generated under another seed, which then loads that file.
	var session: FactorySim = _world(1337)
	_check(session.world_seed == 1337, "…opened by a session built on seed 1337")
	_check(SaveGame.restore(session, SaveGame.read(SLOT)), "…which loads it")
	_check(session.world_seed == 4242, "the loaded world's seed is the one it was BUILT with, not the session's")

	# Re-save immediately, exactly as pressing F5 after Continue does.
	_check(SaveGame.write(SLOT, SaveGame.capture(session)), "…and is re-saved")
	_check(int(SaveGame.read(SLOT).get("world_seed", -1)) == 4242,
		"the re-saved file STILL claims seed 4242 — the session's stale copy did not overwrite it")

	# And the consequence that made it matter: the fine grid derives from the seed, so a wrong seed means
	# a world that molds differently after a round trip. Prove the derived terrain survives too.
	var reloaded := FactorySim.new()
	_check(SaveGame.restore(reloaded, SaveGame.read(SLOT)), "…reloaded once more")
	_check(reloaded._fine_solid == session._fine_solid and not reloaded._fine_solid.is_empty(),
		"…and the fine terrain rebuilds identically (%d cells), because the seed came through" % reloaded._fine_solid.size())
	_sweep()


## 7. THE BACKUP GENERATION IS NOT SPENT TWICE.
## Section 2 proves a damaged slot recovers from the backup. This proves the recovery SURVIVES THE NEXT
## SAVE, which is where it used to die, one save later and out of sight of every test.
##
## `write` copied the primary to `.bak` on the sole condition that the primary EXISTED. So the first save
## after a recovery copied the wreckage that had just been recovered *from* over the only intact
## generation left. The player was warned "recovered", played on, saved once, and was then a single
## corruption away from nothing at all, with no sign that the net under them had been cut. Nothing here
## fails loudly; the damage is entirely in what is no longer there.
##
## The second half is the opposite direction of the same three lines: `copy_absolute` returns an Error and
## it was discarded, so a backup that could NOT be written was followed by a rename that could, replacing
## the save with nothing behind it, while `write`'s own docstring promised any failure leaves the
## existing save exactly as it was. Both were found by an external audit and both were release-blocking.
func _backup_generation() -> void:
	print("== the backup generation ==")
	_sweep()
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(11))), "an older save is written")
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(22))), "…then a newer one, demoting it to backup")

	# Damage the slot exactly as section 2 does. This whole section is about the state AFTER a recovery, so
	# a recovery that did not actually happen would make everything below true for the wrong reason.
	var whole: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	var f: FileAccess = FileAccess.open(SLOT, FileAccess.WRITE)
	f.store_buffer(whole.slice(0, whole.size() / 3))
	f.close()
	var wreck: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	_check(wreck.size() > 0 and wreck.size() < whole.size(),
		"the slot is genuinely damaged, not empty (%d bytes of %d)" % [wreck.size(), whole.size()])
	_check(int(SaveGame.read(SLOT).get("world_seed", -1)) == 11
		and SaveGame.last_read == SaveGame.Read.RECOVERED,
		"…and the player is now running on a RECOVERED save, with that damage still on disk")

	# THE SAVE THAT USED TO EAT THE NET. Everything about it succeeds (the new game lands in the slot),
	# and the only question is what it did to the generation standing behind it.
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(33))), "they save again, and the new save writes")
	_check(int(SaveGame.read(SLOT).get("world_seed", -1)) == 33, "…and the slot holds it")
	var bak: PackedByteArray = FileAccess.get_file_as_bytes(SLOT + SaveGame.BAK_SUFFIX)
	_check(bak != wreck,
		"…and the backup is NOT the corrupt primary it just recovered from (%d bytes vs the wreck's %d)"
			% [bak.size(), wreck.size()])
	_check(int(SaveGame._read_file(SLOT + SaveGame.BAK_SUFFIX).get("world_seed", -1)) == 11,
		"…it is still the intact seed-11 generation — the net that caught them is still under them")

	# THE CONTROL, without which the assertion above is equally satisfied by a `write` that simply stopped
	# backing anything up. An UNDAMAGED primary must still rotate into the backup on the very next save.
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(44))), "a save over an INTACT slot")
	_check(int(SaveGame._read_file(SLOT + SaveGame.BAK_SUFFIX).get("world_seed", -1)) == 33,
		"…DOES rotate the backup forward — the new guard is a validity check, not a disabled feature")

	# A BACKUP THAT CANNOT BE WRITTEN ABORTS THE PROMOTION. Occupying the backup path with a DIRECTORY is
	# the cleanest honest forcing function: the copy cannot open its destination, while the rename of the
	# temp file over the primary is entirely unaffected, which is precisely the shape that used to leave
	# a fresh save sitting on top of no backup at all.
	_sweep()
	_check(SaveGame.write(SLOT, SaveGame.capture(_world(55))), "a save exists to be protected")
	var guarded: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	_check(guarded.size() > 0, "…and it is real bytes (%d), so 'untouched' below compares something" % guarded.size())
	DirAccess.make_dir_absolute(SLOT + SaveGame.BAK_SUFFIX)
	if DirAccess.copy_absolute(SLOT, SLOT + SaveGame.BAK_SUFFIX) == OK:
		# The forcing function did not fire here, so the assertions it guards would pass without ever
		# exercising a failed copy. Stand them down out loud rather than bank them.
		print("  SKIP: the failed-backup path was NOT exercised — a directory at %s did not stop"
			% (SLOT + SaveGame.BAK_SUFFIX))
		print("        copy_absolute on this platform, so there is no way here to make the copy fail.")
	else:
		_check(not SaveGame.write(SLOT, SaveGame.capture(_world(66))),
			"a save whose backup copy FAILS is refused, not promoted over an unbacked slot")
		_check(FileAccess.get_file_as_bytes(SLOT) == guarded,
			"…and the existing save is byte-for-byte untouched, exactly as the docstring promises")
		_check(not FileAccess.file_exists(SLOT + SaveGame.TMP_SUFFIX),
			"…with the rejected temp file cleaned up rather than left to rot in user://")
	DirAccess.remove_absolute(SLOT + SaveGame.BAK_SUFFIX)
	_sweep()
