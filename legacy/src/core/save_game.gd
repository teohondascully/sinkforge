class_name SaveGame
extends RefCounted

## Save and load. A save is a straight capture of the sim's authoritative state into one versioned
## Dictionary, written with Godot's binary Variant serializer (Vector2i keys and StringNames round-trip
## natively, no JSON key-mangling). Machines serialize as def id plus runtime fields; defs are flyweight
## .tres reloaded by the id/filename convention. Derived and transient state (grid, power, flow_events,
## terrain_dirty, the rate ring buffer, the tick accumulator) is not saved and rebuilds on the next tick.
## Determinism is the verifier: capture, restore, tick both N times, compare signatures
## (tests/_test_save_load). Restore mutates a sim in place so live references stay valid; the caller
## repaints (WorldRenderer.repaint_world).
##
## Durability (v2). Opening the real path for writing truncates the previous save to zero the instant
## `FileAccess.open(path, WRITE)` returns, so a write instead encodes to `.tmp`, closes it, reads it back
## and proves it decodes to a real envelope, copies the current good save aside to `.bak`, then renames
## `.tmp` over the slot. That order leaves the slot holding a complete, readable game at every point:
##
##   crash during the tmp write   -> slot untouched, still the old good save
##   crash during the readback    -> slot untouched, the tmp is discarded
##   crash during the backup copy -> slot untouched
##   crash during the rename      -> POSIX rename is atomic; the slot is old-or-new, never in between
##
## Reading mirrors it: a slot that is missing, truncated or malformed falls back to `.bak`, and
## `last_read` says which happened, so the UI can distinguish no save from a damaged one.
##
## Restore is transactional. Every field is validated and duplicated into a staging dictionary first, and
## the live sim is untouched until the whole envelope is known good. Unguarded `data["x"]` indexing into
## the live sim would leave a running game with new terrain and old inventory whenever a key went missing.

const VERSION: int = 2
## The oldest envelope `_migrate` can carry forward. v1 saves (no `seep_tick`) still load.
const OLDEST_READABLE: int = 1
const DEF_DIR: String = "res://src/data/machines/"

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

## The keys the restore path requires. Everything else is additive: absent in an older save, defaulted.
const REQUIRED_KEYS: Array[String] = [
	"version", "solid", "wall", "deposits", "inventory", "ground", "sink",
	"produced", "consumed", "conduit", "rope", "torch", "research", "machines",
]

## FIELDS WHOSE ABSENCE CHANGES THE FUTURE, AND WHICH THEREFORE MAY NOT BE DEFAULTED.
##
## "Additive, so default it" is right for a field whose absence has a TRUTHFUL empty reading: a save from
## before the lode existed genuinely had no lode, and `{}` says exactly that. It is wrong for a field whose
## default is a DIFFERENT SPECIFIC VALUE dressed up as a missing one. `world_seed` defaulting to 0 does not
## say "this world had no seed"; it says "this world was seeded 0", and `_commit` then re-molds the fine
## terrain from a number the world was never built with. `seep_tick` defaulting to 0 does not say "this
## world had no phase"; it says "the next weep lands at phase 0", which `check_save_durability`'s phase
## control proves is a different future.
##
## Both defaults are the failure this project keeps finding: AN ERROR PATH THAT RETURNS THE PASSING VALUE.
## A key went missing and the restore SUCCEEDED, so the player loads a world that is subtly not theirs,
## plays on, saves, and the original identity is gone with nothing having reported anything. Refusing is
## the strictly safer branch. A refused load leaves the file on disk, where a later build can still read it.
##
## Checked AFTER `_migrate`, not before, because supplying a field an older envelope predates is exactly
## what a migration branch is for: v1 has no `seep_tick` and the v1→v2 branch fills it in, so a v1 save
## still opens. What cannot pass is arriving at the current version still missing one.
const NO_DEFAULT_KEYS: Array[String] = ["world_seed", "seep_tick"]

## What the last `read()` found. NONE is a new player, CORRUPT is lost work, RECOVERED is work the backup
## saved; the caller needs the distinction.
enum Read { NONE, OK, RECOVERED, CORRUPT }
static var last_read: Read = Read.NONE


## The sim's authoritative state as one plain Dictionary (the envelope). Callers may add their own
## representation keys (e.g. "player_pos"); restore ignores keys it does not know.
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
		"world_seed": sim.world_seed,   # the fine terrain derives from this; restore rebuilds it
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
		# The Freight Winch (additive, like water/fill/sapling above): absent in a pre-Winch save, which
		# genuinely had no routes, so `{}` on load says exactly that -- no version bump needed.
		"winch_routes": sim.winch_routes.duplicate(),
		"winch_transit": sim.winch_transit.duplicate(true),   # deep: each entry holds its own "items" dict
		# The seep phase (v2). Loose backfill weeps every SEEP_INTERVAL ticks, so the phase decides which tick
		# the next weep lands on. Omit it and a reload resumes mid-cycle while a fresh process starts at zero.
		"seep_tick": sim._seep_tick,
		"machines": machines,
	}


## Why the last envelope was refused. The presence loop below refuses nothing the type loop would not and
## the per-key ablation in `check_save_durability` passes either way, but without it the type loop reaches
## `data[key2]` on an absent key and Godot logs an engine error per miss, taking a holed save from two
## error lines to sixteen.
static var last_invalid: String = ""

## Cheap structural gate run on anything off disk before it goes near the sim: a truncated file decodes
## to null and a foreign file lacks these keys, and both must be told from a good save without crashing.
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


## Carry an older envelope forward to VERSION as a chain of single-step migrations, so the next one
## appends a branch. A v1 save still opens.
static func _migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var v: int = int(out.get("version", -1))
	if v == 1:
		# v1 -> v2: the seep phase became authoritative and saved. An old save has no record of its phase.
		out["seep_tick"] = 0
		v = 2
	out["version"] = v
	return out


## Validate and duplicate the whole envelope into a ready-to-assign staging dictionary, or {} if anything
## is wrong, having touched nothing. The half of `restore` that is allowed to fail.
static func _stage(data: Dictionary) -> Dictionary:
	if not _valid_envelope(data):
		return {}
	var env: Dictionary = _migrate(data)

	# THE CHAIN HAS TO ARRIVE. `_valid_envelope` bounds the version to [OLDEST_READABLE, VERSION]; it does
	# not say a branch exists to carry an old one forward. Bump VERSION to 3 without writing the v2→v3
	# branch and every v2 save on disk migrates to itself, then loads under v3 semantics with no branch
	# having run, silently, because the version gate already said yes. Refuse instead: unreachable today
	# (v1→v2 is the whole chain), and it is the next bump this is written for.
	if int(env.get("version", -1)) != VERSION:
		last_invalid = "migration stopped at version %s — no branch carries it to %d" \
			% [str(env.get("version", "?")), VERSION]
		return {}

	# A migration that did not reach the current version has not done its job, and neither has one that
	# left a no-default field behind. Both are refusals rather than defaults; see NO_DEFAULT_KEYS.
	for key: String in NO_DEFAULT_KEYS:
		if not env.has(key):
			last_invalid = "missing key: %s (no default: its absence would change the world's future)" % key
			return {}

	# Resolve every machine def before anything else (a save from a different data set is refused whole).
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
		"world_seed": int(env["world_seed"]),   # NO_DEFAULT_KEYS: gated above, so this may index directly
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
		# Additive, like sapling above. A value's own "items"/"ticks_remaining" fields are read defensively
		# by the reconciliation pass _reconcile_winch_routes runs after commit, not validated here, matching
		# how a malformed `lode`/`water` entry is handled today -- no new validation infrastructure for one
		# more additive key.
		"winch_routes": (env.get("winch_routes", {}) as Dictionary).duplicate(),
		"winch_transit": (env.get("winch_transit", {}) as Dictionary).duplicate(true),
		"seep_tick": int(env["seep_tick"]),     # NO_DEFAULT_KEYS: likewise
		"machines": rebuilt,
	}


## Assign a staged envelope into the live sim. Cannot fail: every value is already validated and
## duplicated, which is what makes the restore all-or-nothing.
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
	sim.winch_routes = s["winch_routes"]
	sim.winch_transit = s["winch_transit"]
	var rebuilt: Array[MachineState] = s["machines"]
	sim.machines = rebuilt
	sim.grid.clear()
	for m: MachineState in rebuilt:
		sim.grid[m.cell] = m
	# Authoritative phase (v2), restored: the next weep's timing is part of the world's future.
	sim._seep_tick = s["seep_tick"]
	# Transient and derived resets: the next tick rebuilds power, the view drains fresh channels, the bazaar
	# cache rescans.
	sim.power.clear()
	sim.flow_events.clear()
	sim.terrain_dirty.clear()
	sim.invalidate_bazaars()
	# One-shot view channels. Left alone, `last_drop_landing` survives a load and grants pickup grace at a
	# cell from the previous session.
	sim.last_drop_landing = Vector2i(-1, -1)
	# Derived phase, reset explicitly. Left alone these three survive an in-process reload while a fresh
	# process starts them at zero, so one file gives a different sub-tick offset and rate readout per route.
	sim._tick_accumulator = 0.0
	sim._rate_tick = 0
	sim._rate_samples.clear()
	# The fine terrain grid is derived and not saved. It is rebuilt from the restored coarse terrain plus
	# the seed, so a loaded game molds identically to when it was saved.
	sim.rebuild_fine_terrain()


## Load a capture back into `sim`, in place. Refuses an unknown version, a malformed envelope, or a machine
## whose def no longer exists, leaving the sim untouched. Returns whether the restore happened.
static func restore(sim: FactorySim, data: Dictionary) -> bool:
	var staged: Dictionary = _stage(data)
	if staged.is_empty():
		return false
	_commit(sim, staged)
	_reconcile_winch_routes(sim)
	return true


## THE SEMANTIC HALF OF THE WINCH'S ADDITIVE KEYS, run once after `_commit` (grid is populated by then;
## `_stage` cannot do this -- machine lookups need `sim.grid`, which only exists post-commit). A
## well-typed but DANGLING route -- an endpoint cell that no longer holds the expected machine -- is not
## save corruption, it is an ordinary consequence of a save file outliving the machines it was written
## against (docs/handoff/FREIGHT_WINCH_GRAYBOX_PLAN.md's "Route reference storage"), so it is dropped
## rather than refusing the whole save, matching every other additive key's "structural corruption gets
## the blind cast, semantic dangling gets a targeted fix" split.
##
## Dropping a dangling route may NOT silently drop cargo that was mid-trip: conservation is locked
## architecture, and a loader that destroys items would be the load-time twin of the runtime bug
## `pickup_machine`/`_purge_winch_route` already guard against. So a dropped route's transit, if it was
## carrying anything, is materialized rather than erased:
##   - the Head still exists (only the Station went missing) -> the cargo returns to the Head's OWN
##     input_buffer, the same place a dead-route delivery already lands at runtime (`_advance_winch_transit`).
##   - the Head itself is gone -> nothing in this sim can hold it as a buffer, so it lands on the world
##     floor at the Head's last-known cell, through `_spill_to_world`, the SAME mechanism `take_into_pack`
##     already uses for pack overflow -- not a new one.
## Either branch prints a line saying so; a print is what a graybox slice needs here.
static func _reconcile_winch_routes(sim: FactorySim) -> void:
	for head_cell: Vector2i in sim.winch_routes.keys():
		var station_cell: Vector2i = sim.winch_routes[head_cell]
		var head: MachineState = sim.machine_at(head_cell)
		var station: MachineState = sim.machine_at(station_cell)
		var head_ok: bool = head != null and head.def.behavior == &"winch_head"
		var station_ok: bool = station != null and station.def.behavior == &"winch_station"
		if head_ok and station_ok:
			continue
		sim.winch_routes.erase(head_cell)
		print("save: winch route %s -> %s dropped on load (head_ok=%s station_ok=%s)"
			% [head_cell, station_cell, head_ok, station_ok])
		var transit: Dictionary = sim.winch_transit.get(head_cell, {})
		sim.winch_transit.erase(head_cell)
		var items: Dictionary = transit.get("items", {}) as Dictionary
		if items.is_empty():
			continue
		if head_ok:
			for item: StringName in items:
				head.input_buffer[item] = int(head.input_buffer.get(item, 0)) + int(items[item])
			print("save: winch cargo at %s (dropped route) returned to the Head's own input_buffer"
				% [head_cell])
		else:
			for item: StringName in items:
				sim._spill_to_world(head_cell, item, int(items[item]))
			print("save: winch cargo at %s (Head itself missing) spilled to the world floor" % [head_cell])


## Write an envelope to disk, keeping the previous good save as `<path>.bak`. On any failure the existing
## save is left exactly as it was: every early return removes the temp file.
##
## "Atomic" here means replacement visibility only. A reader sees the whole old save or the whole new one,
## because the bytes are staged in a temp file and the slot is swapped with one rename. Nothing fsyncs, so
## it is not a power-loss durability claim; the backup generation covers that case.
##
## Cost: the existing save is decoded once per write to decide whether it may become the backup, on top of
## the readback below. Saves are user- or interval-triggered and the envelope is small.
##
## A fixture may not write `user://` unless something has declared a sandbox. Isolation lives in the two
## wrapper scripts, so a bare `godot --script res://tests/...` inherits the real HOME and writes into the
## player's own Godot data directory, where nothing watches for it. The check keys on a positive marker
## exported by both wrappers rather than on recognising the dangerous state: absence of proof of isolation
## is the refusal condition. `SF_REAL_HOME=1` is honoured, being that declaration itself, and `--script`
## is the fixture tell, since the game proper never carries it.
static func _fixture_may_not_write(path: String) -> bool:
	if not path.begins_with("user://"):
		return false
	if not OS.get_environment("SF_ISOLATED_HOME").is_empty():
		return false
	if OS.get_environment("SF_REAL_HOME") == "1":
		return false
	return OS.get_cmdline_args().has("--script")


static func write(path: String, data: Dictionary) -> bool:
	if _fixture_may_not_write(path):
		push_error("save: REFUSING to write %s — this is a --script fixture and no isolated home was "
			% path + "declared, so user:// is the player's real directory. Run it through "
			+ "tools/with_machine.sh (or tools/run_harness.sh), or set SF_REAL_HOME=1 to say you mean it.")
		return false
	var tmp: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s (err %d) — the existing save is untouched"
			% [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data)
	# Close before reading back: Godot flushes on free, and the readback would otherwise race the writer.
	f.close()

	# Prove it landed. A disk that filled mid-write leaves a truncated file `get_var` returns null for, and
	# a Variant that failed to encode leaves something that is not an envelope. Either way the temp goes.
	if not _valid_envelope(_read_file(tmp)):
		push_warning("save: %s did not read back as a valid envelope — the existing save is untouched" % tmp)
		DirAccess.remove_absolute(tmp)
		return false

	# Last known good, copied rather than renamed, so the slot stays occupied throughout and a crash between
	# these lines still finds a complete game at the real path. Two conditions guard opposite failure
	# directions of the same three lines:
	#
	# 1. Only a valid primary may become the backup. `read()` recovers from the backup when the primary is
	#    damaged, so copying a damaged primary across would destroy the last recovery generation.
	# 2. A failed copy must abort the write. `copy_absolute()` returns an Error; discarding it lets a failed
	#    copy followed by a successful rename replace the save with no valid backup behind it.
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
			# The slot is damaged. Whatever sits in .bak is older but intact and the only good generation left.
			push_warning("save: %s is damaged — keeping the existing backup rather than overwriting it "
				% path + "with a corrupt primary")
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("save: could not promote %s over %s — the existing save is untouched" % [tmp, path])
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Decode one file, or {} if missing, unreadable or truncated. No validation and no fallback: the recovery
## policy lives in `read()`.
static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	return v if v is Dictionary else {}


## Read an envelope, falling back to the backup if the slot is missing or damaged. `{}` still means no game
## to load; `last_read` says why.
static func read(path: String) -> Dictionary:
	var primary: Dictionary = _read_file(path)
	if _valid_envelope(primary):
		last_read = Read.OK
		return primary
	var backup: Dictionary = _read_file(path + BAK_SUFFIX)
	if _valid_envelope(backup):
		# The slot is damaged and the backup is not. Say so: the player is being handed an older game.
		push_warning("save: %s is missing or damaged — recovered the previous save from %s"
			% [path, path + BAK_SUFFIX])
		last_read = Read.RECOVERED
		return backup
	# A file that exists but will not decode is a corrupt save, not an absent one, and only one of those may
	# be shown to somebody who definitely had a save yesterday.
	last_read = Read.CORRUPT if (FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)) \
		else Read.NONE
	return {}
