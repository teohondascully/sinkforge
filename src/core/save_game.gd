class_name SaveGame
extends RefCounted

## SAVE / LOAD. The sim is PLAIN DATA (node-free dicts + an array of MachineState),
## so a save is a straight capture of its authoritative state into one versioned Dictionary, written
## with Godot's binary Variant serializer (Vector2i keys + StringNames round-trip natively — no JSON
## key-mangling). Machines serialize as def-ID + runtime fields; defs are flyweight .tres reloaded by
## the id↔filename convention. DERIVED/transient state (grid, power, flow_events, terrain_dirty, the
## rate ring buffer, the tick accumulator) is deliberately NOT saved — it's a pure function of the
## authoritative state and rebuilds on the next tick, which is what makes the save format this small.
## Determinism is the verifier: capture → restore → tick both N times → identical signatures
## (tests/_test_save_load). Restore mutates a sim IN PLACE so live references (Player, renderer,
## HUD) stay valid; the caller repaints the view (WorldRenderer.repaint_world).
##
## ---------------------------------------------------------------------------------------------------
## DURABILITY, and why v2 exists. The original writer opened the player's one and only save file in
## WRITE mode and streamed into it. That is the single most destructive shape a save can have: the
## instant `FileAccess.open(path, WRITE)` returns, the previous save is GONE — truncated to zero — and
## everything after that point (a full disk, a crash, a kill, a Variant that fails to encode) leaves the
## player with a file that is empty or half a game. There was no temporary file, no verification that
## what landed on disk could be read back, no backup, and no recovery path. One bad moment ate the
## save, silently, and the next boot said "no save to load".
##
## So a write now goes: encode to `.tmp` → close it → READ IT BACK and prove it decodes to a real
## envelope → copy the current good save aside to `.bak` → atomically rename `.tmp` over the slot. The
## ordering is chosen so that at NO point does the slot fail to hold a complete, readable game:
##
##   crash during the tmp write   → slot untouched, still the old good save
##   crash during the readback    → slot untouched (the tmp is discarded)
##   crash during the backup copy → slot untouched
##   crash during the rename      → POSIX rename is atomic; the slot is old-or-new, never in between
##
## Reading is the mirror: a slot that is missing, truncated, or not a well-formed envelope falls back to
## `.bak`, and `last_read` tells the caller which of those happened so the UI can distinguish "you have
## no save" from "your save was damaged and this is the previous one" — two very different sentences to
## read after losing an hour of work.
##
## RESTORE IS TRANSACTIONAL. It used to resolve machine defs up front (all-or-nothing, correctly) and
## then assign the twenty terrain/economy fields straight into the live sim with unguarded `data["x"]`
## indexing. A save missing any one of those keys therefore errored PART WAY THROUGH, leaving the running
## game with new terrain and old inventory — the "bad file can never eat a running game" promise in the
## comment above was true only for the two failures it checked and false for every other one. Now every
## field is validated and duplicated into a staging dictionary FIRST, and the live sim is not touched
## until the whole envelope is known good.

const VERSION: int = 2
## The oldest envelope `_migrate` can carry forward. v1 saves (no `seep_tick`) still load.
const OLDEST_READABLE: int = 1
const DEF_DIR: String = "res://src/data/machines/"

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

## The keys the restore path REQUIRES — the ones it used to index unguarded, so a save without them was
## a crash mid-mutation rather than a clean refusal. Everything not listed here is additive: absent in an
## older save, defaulted on the way in, and that is the whole reason it is not listed.
const REQUIRED_KEYS: Array[String] = [
	"version", "solid", "wall", "deposits", "inventory", "ground", "sink",
	"produced", "consumed", "conduit", "rope", "torch", "research", "machines",
]

## What the last `read()` actually found. The caller needs this to say the right thing out loud: NONE is
## a new player, CORRUPT is an hour of work that is gone, and RECOVERED is an hour of work that is not.
enum Read { NONE, OK, RECOVERED, CORRUPT }
static var last_read: Read = Read.NONE


## The sim's authoritative state as one plain Dictionary (the envelope). Callers may add their own
## representation keys (e.g. "player_pos") beside these; restore ignores keys it doesn't know.
static func capture(sim: FactorySim) -> Dictionary:
	var machines: Array = []
	for m: MachineState in sim.machines:
		machines.append({
			"def": String(m.def.id), "cell": m.cell,
			"in": m.input_buffer.duplicate(), "out": m.output_buffer.duplicate(),
			"spoil": m.spoil_buffer.duplicate(),
			"progress": m.progress, "route_toggle": m.route_toggle,
			"fuel": m.fuel, "power_factor": m.power_factor, "fed": m.fed,
			"facing": m.facing, "mode": m.mode, "filter": String(m.filter),
		})
	return {
		"version": VERSION,
		"world_seed": sim.world_seed,   # the fine terrain derives from this — restore rebuilds it (not stored)
		"solid": sim.solid.duplicate(),
		"wall": sim.wall.duplicate(),
		"deposits": sim.deposits.duplicate(),
		"lode": sim.lode.duplicate(),
		"lode_max": sim.lode_max.duplicate(),
		"inventory": sim.inventory.duplicate(),
		"ground": sim.ground.duplicate(true),
		"sink": sim.sink.duplicate(),
		"produced": sim.total_produced.duplicate(),
		"consumed": sim.total_consumed.duplicate(),
		"conduit": sim.conduit.duplicate(),
		"rope": sim.rope.duplicate(),
		"torch": sim.torch.duplicate(),
		"water": sim.water.duplicate(),
		"fill": sim.fill.duplicate(),
		"research": sim.research.duplicate(),
		"sapling": sim.sapling.duplicate(),
		# THE SEEP PHASE (v2). Loose backfill weeps every SEEP_INTERVAL ticks, so WHERE IN THAT CYCLE the
		# world is decides which tick the next weep lands on. Leaving it out meant an F9 in the same
		# process resumed mid-cycle while the same file loaded in a fresh process resumed at phase zero —
		# one file, two different futures, from a system that stakes its correctness on determinism.
		"seep_tick": sim._seep_tick,
		"machines": machines,
	}


## Why the last envelope was refused. Not diagnostics for their own sake: the PRESENCE loop below and the
## TYPE loop under it both refuse an envelope that is missing a key, so deleting the presence loop changes
## nothing any assertion could see — the per-key ablation in `check_save_durability` passes either way.
## It is not redundant, though. Without it the type loop reaches `data[key2]` on a key that isn't there,
## and Godot answers with an engine error per miss: refusing a holed save went from 2 error lines to 16
## when the presence loop was deleted to test exactly this (2026-08-17). So the guard's real job is to
## refuse CLEANLY, and this string is what makes that job visible to a test.
static var last_invalid: String = ""

## Does this dictionary look like a save at all? Cheap structural gate, run on anything coming off disk
## BEFORE it is allowed near the sim — a truncated file decodes to null, a foreign file decodes to
## something without these keys, and both must be told apart from a good save without a crash.
static func _valid_envelope(data: Dictionary) -> bool:
	last_invalid = ""
	if data.is_empty():
		last_invalid = "empty"
		return false
	var v: int = int(data.get("version", -1))
	if v < OLDEST_READABLE or v > VERSION:
		last_invalid = "version %d outside [%d, %d]" % [v, OLDEST_READABLE, VERSION]
		return false
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			last_invalid = "missing key: %s" % key
			return false
	if not (data["machines"] is Array):
		last_invalid = "machines is not an Array"
		return false
	for key2: String in REQUIRED_KEYS:
		if key2 == "version" or key2 == "machines":
			continue
		if not (data[key2] is Dictionary):
			last_invalid = "wrong type: %s" % key2
			return false
	return true


## Carry an older envelope forward to VERSION. Written as a chain of single-step migrations so the next
## one appends a branch rather than editing this one — and so a v1 save from before any of this existed
## still opens, which is the only reason a version number is worth having.
static func _migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var v: int = int(out.get("version", -1))
	if v == 1:
		# v1 → v2: the seep phase became authoritative and saved. An old save has no record of where in
		# the cycle it was, and phase zero is the honest answer — not a guess dressed as continuity.
		out["seep_tick"] = 0
		v = 2
	out["version"] = v
	return out


## Validate and DUPLICATE the whole envelope into a ready-to-assign staging dictionary. Returns {} if
## anything is wrong, having touched nothing. This is the half of `restore` that is allowed to fail.
static func _stage(data: Dictionary) -> Dictionary:
	if not _valid_envelope(data):
		return {}
	var env: Dictionary = _migrate(data)

	# Resolve every machine def BEFORE anything else (a save from a different data set is refused whole).
	var rebuilt: Array[MachineState] = []
	for md: Variant in (env.get("machines", []) as Array):
		if not (md is Dictionary):
			return {}
		var entry: Dictionary = md
		if not (entry.get("cell") is Vector2i):
			return {}
		var path: String = DEF_DIR + String(entry.get("def", "")) + ".tres"
		if not ResourceLoader.exists(path):
			return {}
		var def: MachineDef = load(path) as MachineDef
		if def == null:
			return {}
		var m := MachineState.new(def, entry["cell"])
		m.input_buffer = (entry.get("in", {}) as Dictionary).duplicate()
		m.output_buffer = (entry.get("out", {}) as Dictionary).duplicate()
		m.spoil_buffer = (entry.get("spoil", {}) as Dictionary).duplicate()   # additive: the rig's 2nd belly
		m.progress = float(entry.get("progress", 0.0))
		m.route_toggle = int(entry.get("route_toggle", 0))
		m.fuel = int(entry.get("fuel", 0))
		m.power_factor = float(entry.get("power_factor", 0.0))
		m.fed = int(entry.get("fed", 0))
		m.facing = int(entry.get("facing", 1))   # additive fields: absent in older v1 saves → defaults
		m.mode = int(entry.get("mode", 0))
		m.filter = StringName(str(entry.get("filter", "")))
		rebuilt.append(m)

	return {
		"world_seed": int(env.get("world_seed", 0)),   # additive: absent in the oldest saves → 0 (default)
		"solid": (env["solid"] as Dictionary).duplicate(),
		"wall": (env["wall"] as Dictionary).duplicate(),
		"deposits": (env["deposits"] as Dictionary).duplicate(),
		"lode": (env.get("lode", {}) as Dictionary).duplicate(),     # additive: absent in older saves → empty
		"lode_max": (env.get("lode_max", {}) as Dictionary).duplicate(),
		"inventory": (env["inventory"] as Dictionary).duplicate(),
		"ground": (env["ground"] as Dictionary).duplicate(true),
		"sink": (env["sink"] as Dictionary).duplicate(),
		"produced": (env["produced"] as Dictionary).duplicate(),
		"consumed": (env["consumed"] as Dictionary).duplicate(),
		"conduit": (env["conduit"] as Dictionary).duplicate(),
		"rope": (env["rope"] as Dictionary).duplicate(),
		"torch": (env["torch"] as Dictionary).duplicate(),
		"water": (env.get("water", {}) as Dictionary).duplicate(),   # additive: absent in older saves → empty
		"fill": (env.get("fill", {}) as Dictionary).duplicate(),     # additive: an older save has no packing
		"research": (env["research"] as Dictionary).duplicate(),
		"sapling": (env.get("sapling", {}) as Dictionary).duplicate(),   # additive: absent in older saves
		"seep_tick": int(env.get("seep_tick", 0)),
		"machines": rebuilt,
	}


## Assign a staged envelope into the live sim. Cannot fail — every value here has already been validated
## and duplicated, which is exactly what makes the restore all-or-nothing.
static func _commit(sim: FactorySim, s: Dictionary) -> void:
	sim.world_seed = s["world_seed"]
	sim.solid = s["solid"]
	sim.wall = s["wall"]
	sim.deposits = s["deposits"]
	sim.lode = s["lode"]
	sim.lode_max = s["lode_max"]
	sim.inventory = s["inventory"]
	sim.ground = s["ground"]
	sim.sink = s["sink"]
	sim.total_produced = s["produced"]
	sim.total_consumed = s["consumed"]
	sim.conduit = s["conduit"]
	sim.rope = s["rope"]
	sim.torch = s["torch"]
	sim.water = s["water"]
	sim.fill = s["fill"]
	sim.research = s["research"]
	sim.sapling = s["sapling"]
	var rebuilt: Array[MachineState] = s["machines"]
	sim.machines = rebuilt
	sim.grid.clear()
	for m: MachineState in rebuilt:
		sim.grid[m.cell] = m
	# AUTHORITATIVE PHASE (v2) — restored, because the next weep's timing is part of the world's future.
	sim._seep_tick = s["seep_tick"]
	# Transient/derived state resets — the next tick rebuilds power; the view drains fresh channels;
	# the bazaar cache rescans the restored terrain.
	sim.power.clear()
	sim.flow_events.clear()
	sim.terrain_dirty.clear()
	sim._bazaars_dirty = true
	# …and the one-shot view channels. `last_drop_landing` used to survive a load, so the controller
	# granted its pickup grace at a cell from the session BEFORE the one you just loaded into.
	sim.last_drop_landing = Vector2i(-1, -1)
	# DERIVED PHASE, reset EXPLICITLY rather than left wherever the previous game happened to leave it.
	# These three used to survive an in-process F9 untouched while a fresh process started them at zero,
	# so the same file produced a different sub-tick offset and a different rate readout depending on how
	# you got there. They are pure readouts and accumulators, so zero is the correct value for both paths
	# — the point is that both paths now agree.
	sim._tick_accumulator = 0.0
	sim._rate_tick = 0
	sim._rate_samples.clear()
	# The FINE TERRAIN grid is DERIVED (not saved) — rebuild it deterministically from the restored
	# coarse terrain + seed, so a loaded game molds identically to when it was saved.
	sim.rebuild_fine_terrain()


## Load a capture back into `sim` (in place). Refuses an unknown version, a malformed envelope, or a
## machine whose def no longer exists (a save from a different data set) — on refusal the sim is left
## UNTOUCHED, because nothing is written until the entire envelope has been validated and staged.
## Returns whether the restore happened.
static func restore(sim: FactorySim, data: Dictionary) -> bool:
	var staged: Dictionary = _stage(data)
	if staged.is_empty():
		return false
	_commit(sim, staged)
	return true


## Write an envelope to disk, keeping the previous GOOD save as `<path>.bak`. Returns success.
##
## On ANY failure the existing save is left exactly as it was — that is the entire point of the dance,
## and every early return below removes the temp file rather than the player's game.
##
## "Atomic" here means REPLACEMENT VISIBILITY, and only that: a reader either sees the whole old save or
## the whole new one, never a half-written mixture, because the bytes are staged in a temp file and the
## slot is swapped with a single rename. It is NOT a power-loss durability claim — nothing here fsyncs,
## so a kernel that has acknowledged the write but not flushed it can still lose the tail on a hard cut.
## The backup generation, not the rename, is what covers that case.
##
## COST: this decodes the existing save once per write to decide whether it may become the backup. That
## is a second full decode on top of the readback below. Saves are user/interval-triggered and the
## envelope is small, so the price is paid deliberately — the alternative is trusting a file we have not
## looked at, which is exactly the bug this replaced.
static func write(path: String, data: Dictionary) -> bool:
	var tmp: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s (err %d) — the existing save is untouched"
			% [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data)
	# CLOSE BEFORE READING BACK. Godot flushes on free, but "the object goes out of scope eventually" is
	# not a durability guarantee, and the readback below would otherwise be racing the writer.
	f.close()

	# PROVE IT LANDED. A disk that filled up mid-write leaves a truncated file that `get_var` returns
	# null for; a Variant that failed to encode leaves something that is not an envelope. Either way the
	# temp file is discarded and the player keeps the save they already had.
	if not _valid_envelope(_read_file(tmp)):
		push_warning("save: %s did not read back as a valid envelope — the existing save is untouched" % tmp)
		DirAccess.remove_absolute(tmp)
		return false

	# LAST KNOWN GOOD. Copied, not renamed: a copy leaves the slot occupied the whole time, so a crash
	# between these two lines still finds a complete game at the real path.
	#
	# TWO CONDITIONS, both of which this code got wrong, and both found by an external audit as
	# release-blocking. They are opposite failure directions of the same three lines.
	#
	# 1. ONLY A VALID PRIMARY MAY BECOME THE BACKUP. The copy used to require merely that the file
	#    EXISTED. But `read()` recovers FROM the backup when the primary is damaged — so the very next
	#    save copied that damaged primary over the good backup which had just rescued the player, and
	#    the recovery generation was gone. The new save might be fine; the safety net behind it was not.
	#    One more corruption after that and there is nothing left to fall back to.
	# 2. A FAILED COPY MUST ABORT THE WRITE. `copy_absolute()` returns an Error and it was discarded.
	#    A copy that failed — permissions, a full disk — followed by a rename that succeeded replaced
	#    the player's save with NO valid backup behind it, while this function's own docstring promised
	#    that on ANY failure the existing save is left exactly as it was. The promise was the defect.
	if FileAccess.file_exists(path):
		if _valid_envelope(_read_file(path)):
			var backed: int = DirAccess.copy_absolute(path, path + BAK_SUFFIX)
			if backed != OK:
				push_warning("save: could not preserve %s as %s (err %d) — refusing to promote a new save "
					% [path, path + BAK_SUFFIX, backed]
					+ "over a generation we cannot back up; the existing save is untouched")
				DirAccess.remove_absolute(tmp)
				return false
		else:
			# The slot on disk is damaged. Whatever sits in .bak is older but INTACT, and it is the only
			# good generation left — overwriting it with this wreckage is the one thing we must not do.
			push_warning("save: %s is damaged — keeping the existing backup rather than overwriting it "
				% path + "with a corrupt primary")
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("save: could not promote %s over %s — the existing save is untouched" % [tmp, path])
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Decode one file, or {} if it is missing/unreadable/truncated. No validation, no fallback — the
## recovery policy lives in `read()`, this is just the bytes.
static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	return v if v is Dictionary else {}


## Read an envelope from disk, falling back to the backup if the slot is missing or damaged. `{}` still
## means "no game to load", but `last_read` now says WHY, so the caller can tell a new player apart from
## one whose save just failed to open.
static func read(path: String) -> Dictionary:
	var primary: Dictionary = _read_file(path)
	if _valid_envelope(primary):
		last_read = Read.OK
		return primary
	var backup: Dictionary = _read_file(path + BAK_SUFFIX)
	if _valid_envelope(backup):
		# The slot is damaged and the backup is not. Say so loudly: the player is about to be handed a
		# slightly older game than the one they saved, and silently rolling them back is how trust dies.
		push_warning("save: %s is missing or damaged — recovered the previous save from %s"
			% [path, path + BAK_SUFFIX])
		last_read = Read.RECOVERED
		return backup
	# A file that exists but will not decode is a CORRUPT save, not an absent one. The distinction is the
	# difference between "start a new game" and "something ate your hour", and only one of those should
	# ever be shown to somebody who definitely had a save yesterday.
	last_read = Read.CORRUPT if (FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)) \
		else Read.NONE
	return {}
