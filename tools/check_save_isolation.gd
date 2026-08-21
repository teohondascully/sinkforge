extends "res://tools/check_base.gd"

## Harness layer: NO TEST MAY WRITE THE PLAYER'S SAVE. This is a data-safety gate, not a
## behaviour check, and it is deliberately the cheapest layer in the suite (a source scan, no scene, no
## engine boot) because a gate that costs three minutes gets skipped.
##
## The defect it exists to stop actually happened: `check_saveload.gd` drove the real `_save_game()` at
## the real `user://sinkforge.save` and then `DirAccess.remove_absolute`d it, so running the advertised
## harness on a developer machine overwrote and then DELETED that developer's game. The runner's own
## header promised the opposite ("layers write only uniquely-named user:// files"), which is the worst
## kind of comment: a test with no runner, asserting a safety property nobody checked.
##
## Three properties, all provable from source alone:
##   1. `MainView` still SAVES TO THE PRODUCTION SLOT by default. The fix must not be "move where players
##      save": that would trade one data-loss bug for another, silently orphaning every existing save.
##   2. Nothing under tools/ or tests/ NAMES the production slot. A layer cannot delete a path it cannot
##      spell, and a literal is the only way to reach it now that the constant is an overridable static.
##   3. Any layer that boots the real scene AND reaches the save path OVERRIDES `MainView.save_path`
##      first. This is the one that catches the next check_saveload: a new layer that calls `_save_game()`
##      inherits the production default unless it says otherwise, and here is where it gets told.
##
## WHAT THE SCAN CAN AND CANNOT SEE, because a gate that oversells its reach is how the last one came to
## be trusted. It reads every .gd under those trees INCLUDING SUBDIRECTORIES (it did not, once, which
## meant the first `tools/perf/` layer would have been invisible while the gate kept passing), and it
## reads them with adjacent string splicing collapsed, so `"user://" + "sinkforge.save"` is caught. It
## still cannot see a path built from a variable or a format string at runtime. Nothing that reads source
## ever will; `save_sentinel.gd` is the half that hashes the real file and does not care how it was named.
##
## Non-vacuity: a source scan that matches nothing passes trivially, so this asserts the scan found files,
## found the slot literal where it MUST appear (scenes/main.gd), proved the splice-flattener actually
## fires on a sample built for it, and found at least one real save-driving layer to hold to property 3.
##   godot --headless --path . --script res://tools/check_save_isolation.gd

## The player's slot. Matched WHOLE: `user://test_sinkforge.save` (test_sim's own isolated round-trip
## file) ends with the production filename and is entirely legitimate, so a filename-only match would
## have condemned it. This file necessarily spells the literal it hunts for, so it is excluded from its
## own scan; honestly, because the matcher's non-vacuity is proved against scenes/main.gd instead.
const SLOT: String = "user://sinkforge.save"
const SELF: String = "res://tools/check_save_isolation.gd"

## The ONE file under tools/ that is allowed to name the slot, and it earns it: `save_sentinel.gd` is not
## a harness layer at all: it is the runner's own instrument, whose entire job is to hash that exact path
## before and after a sweep and shout if it moved. Exempting it would be a hole, so the exemption is paid
## for below: this layer asserts the runner actually invokes it in BOTH modes, and that it is never
## registered as a layer. An exemption that has to prove it is being used is not much of an exemption.
const SENTINEL: String = "res://tools/save_sentinel.gd"

const SCAN_DIRS: Array[String] = ["res://tools", "res://tests"]

## Counted rather than assumed: an exclusion nobody can see is indistinguishable from a scan that missed.
var _scratch_skipped: int = 0
const MAIN_SRC: String = "res://scenes/main.gd"
const RUNNER: String = "res://tools/run_harness.sh"
const SAVE_SRC: String = "res://src/core/save_game.gd"

## Source with adjacent string-literal splicing collapsed, so the scan reads what a program will actually
## SPELL rather than how the file happens to be laid out. `"user://" + "sinkforge.save"` is a path to the
## player's game, and a plain `contains()` looks straight through it.
##
## HONEST LIMIT, stated here because a gate that oversells itself is exactly how the last one came to be
## trusted: this closes literal splicing, not computation. A path assembled from a variable, a format
## string, or a name resolved at runtime still walks past, and no source scan will ever catch that one.
## What stands behind this is the sentinel, which hashes the real slot before and after and does not care
## how anybody spelled anything.
static func _flatten(src: String) -> String:
	var re: RegEx = RegEx.create_from_string("\"\\s*\\+\\s*\"")
	return re.sub(src, "", true)


## Every .gd under `dir` AND its subdirectories, as path → flattened source text.
##
## RECURSIVE on purpose. This read `get_files()` alone, so the day anybody filed layers under `tools/perf/`
## the gate would have gone on passing while seeing none of them. A safety gate that quietly stops covering
## new code is worse than no gate at all, because the runner's header keeps promising it.
## SCRATCH COPIES ARE EXCLUDED, AND THE COUNT IS PRINTED, because a silent exclusion is how a sample
## becomes a different sample. `tools/_scratch_*.gd` is this repository's convention for a throwaway probe;
## `.gitignore:92` ignores the whole glob, so none of them exist in a clean clone or in CI, and none of them
## is registered in `tools/run_harness.sh` — grep it, the count is zero — so none can ever run in a sweep.
##
## They break this layer for a reason that is real and harmless: a scratch probe is usually a COPY of the
## layer it is investigating, so it necessarily names that layer's slot. Two files, one slot, no possible
## collision, because only one of them is a layer. Left unexcluded, anybody's local experiment reddens the
## suite for everybody, which teaches people to stop trusting it.
##
## The narrow risk this accepts: a scratch file that writes a REAL slot would no longer be caught here. That
## is bounded by the same facts — it cannot be scheduled, and the production slot is guarded separately by
## the sentinel, which is the instrument that actually stands between a fixture and the player's save.
const SCRATCH_PREFIX: String = "_scratch_"


func _sources(dir: String) -> Dictionary:
	var out: Dictionary = {}
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for name: String in d.get_files():
		if not name.ends_with(".gd"):
			continue
		if name.begins_with(SCRATCH_PREFIX):
			_scratch_skipped += 1
			continue
		var path: String = dir + "/" + name
		out[path] = _flatten(FileAccess.get_file_as_string(path))
	for sub: String in d.get_directories():
		out.merge(_sources(dir + "/" + sub))
	return out


## Every `user://….save` path literal in one (already flattened) source, de-duplicated. A fixture naming
## its own slot twice is one fixture, not two. Deliberately narrow — a real path, no `*`, no spaces — so
## the prose in a docstring cannot be read as a slot somebody writes to.
func _slots(src: String) -> Array[String]:
	var out: Array[String] = []
	var re: RegEx = RegEx.create_from_string("\"(user://[A-Za-z0-9_%./-]+\\.save)\"")
	for m: RegExMatch in re.search_all(src):
		var s: String = m.get_string(1)
		if not out.has(s):
			out.append(s)
	return out


func _initialize() -> void:
	# --- 1. the production default is UNCHANGED -------------------------------------------------
	# Read it out of source rather than off the class: this layer must stay a source scan (no engine,
	# no scene), and the declaration is what a future edit would break. This doubles as the matcher's
	# non-vacuity proof: `contains(SLOT)` is shown to fire on a file that really does name the slot.
	var main_src: String = FileAccess.get_file_as_string(MAIN_SRC)
	_check(main_src.length() > 1000, "scenes/main.gd read (%d chars)" % main_src.length())
	_check(main_src.contains(SLOT), "MainView still names the production slot (players keep their saves)")
	_check(main_src.contains("static var save_path"),
		"MainView.save_path is an overridable static, not a const (the harness can point elsewhere)")

	# NON-VACUITY FOR THE FLATTENER. Prove on a synthetic sample that splicing is invisible to the naive
	# match and visible after normalising. Without this the regex could quietly become a no-op (matching
	# nothing, rewriting nothing), and every scan below would keep passing with the hole reopened.
	var spliced: String = "var p: String = \"user://\" + \"sinkforge.save\""
	_check(not spliced.contains(SLOT), "a spliced slot literal is invisible to a plain contains()")
	_check(_flatten(spliced).contains(SLOT), "…and visible once flattened — the normaliser really fires")

	# --- 2/3. no fixture reaches the production slot --------------------------------------------
	var scanned: int = 0
	var offenders: Array[String] = []
	var touchers: Array[String] = []
	var unguarded: Array[String] = []
	var unread: Array[String] = []
	var slots: Dictionary = {}          # "user://x.save" → the files that name it
	for dir: String in SCAN_DIRS:
		var srcs: Dictionary = _sources(dir)
		# A DIRECTORY THIS COULD NOT READ IS NOT A DIRECTORY WITH NOTHING WRONG IN IT. `_sources` answers
		# `{}` both for "opened, found nothing" and for "could not open, or is not there any more", and an
		# empty map contributes no offenders, which scores as clean. The total floor below cannot catch it
		# either: `res://tools` alone holds 115 .gd files against `res://tests`'s 5, so tests/ could be
		# renamed tomorrow and this gate would keep passing at 115 while covering none of it. Directories
		# moving is live work in this repo, which is what makes the quiet version of that unacceptable.
		_check(not srcs.is_empty(), "%s opened and yielded .gd files (%d)" % [dir, srcs.size()])
		for path_v: Variant in srcs.keys():
			var path: String = String(path_v)
			if path == SELF or path == SENTINEL:
				continue
			var src: String = srcs[path_v]
			scanned += 1
			# …and the same failure one level down. `get_file_as_string` answers "" for a file it could not
			# read, "" contains no slot literal, and the file scores clean while still counting toward the
			# floor: the file it could not READ arrives as the file with nothing WRONG in it. A .gd with no
			# bytes is the tell, not the norm.
			if src.is_empty():
				unread.append(path)
				continue
			if src.contains(SLOT):
				offenders.append(path)
			for slot: String in _slots(src):
				if not slots.has(slot):
					var first: Array[String] = []
					slots[slot] = first
				var owners_so_far: Array[String] = slots[slot]
				owners_so_far.append(path)
			# Anything that can REACH the slot (by naming the static, or by driving the controller's
			# save verbs, which read it) has to redirect it first. Deliberately broader than "boots
			# main.tscn": `DirAccess.remove_absolute(MainView.save_path)` in a fixture that never boots
			# the scene would delete the save just as dead.
			var touches: bool = src.contains("MainView.save_path") or src.contains("MainView.SAVE_PATH") \
				or src.contains("_save_game(") or src.contains("_load_game(")
			if touches:
				touchers.append(path)
				if not src.contains("MainView.save_path ="):
					unguarded.append(path)

	_check(scanned >= 40, "the scan actually read the harness (%d .gd files)" % scanned)
	_check(unread.is_empty(), "every scanned file gave up its source%s"
		% ("" if unread.is_empty() else " — read as empty: " + ", ".join(unread)))
	print("  %d scratch cop(ies) excluded (tools/_scratch_*.gd — gitignored, and registered nowhere)"
		% _scratch_skipped)
	_check(offenders.is_empty(), "no fixture names the production slot%s"
		% ("" if offenders.is_empty() else " — " + ", ".join(offenders)))
	_check(not touchers.is_empty(),
		"at least one layer reaches the save path (%s) — the override rule is not vacuous"
			% ", ".join(touchers))
	_check(unguarded.is_empty(), "every save-reaching layer overrides MainView.save_path%s"
		% ("" if unguarded.is_empty() else " — " + ", ".join(unguarded)))

	# --- 3b. AND NO TWO FIXTURES SHARE ONE SLOT -------------------------------------------------
	# Everything above holds the fixtures to not naming the PLAYER's slot. Nothing held them to not naming
	# EACH OTHER's, and the sweep runs JOBS layers at once inside a single `user://` — Godot keys it on the
	# project NAME, so the isolated home is one namespace for the whole run. Two layers on one save file do
	# not collide loudly; they sweep each other's `.tmp`, read each other's `.bak`, and each reports on
	# whichever one lost the race. Intermittent, and a property of the schedule rather than of the code.
	var shared: Array[String] = []
	for slot_v: Variant in slots.keys():
		var owners: Array[String] = slots[slot_v]
		if owners.size() > 1:
			shared.append("%s ← %s" % [String(slot_v), ", ".join(owners)])
	# NON-VACUITY IN BOTH DIRECTIONS. "No duplicates" over an empty set is free, so the extractor has to
	# have found real slots; and the extractor itself has to be shown to extract, on a sample built for it,
	# or a regex that quietly stops matching would buy a permanent green.
	_check(slots.size() >= 5, "the scan found %d distinct isolated save slots to compare" % slots.size())
	var sample: Array[String] = _slots("a = \"user://one.save\"\nb = \"user://two.save\"\nc = \"user://one.save\"")
	_check(sample.size() == 2 and sample.has("user://one.save") and sample.has("user://two.save"),
		"the slot extractor really extracts, and de-duplicates within a file (%s)" % ", ".join(sample))
	_check(shared.is_empty(), "no two fixtures write the same isolated slot%s"
		% ("" if shared.is_empty() else " — " + "; ".join(shared)))

	# --- 4. the sentinel's exemption is paid for ------------------------------------------------
	# save_sentinel.gd is skipped above. That is only defensible while it is doing the job it was
	# skipped for, so the runner is read here and held to actually calling it (both halves, since an
	# `arm` with no `verify` protects nothing), and to never registering it as a layer (a layer runs
	# under the parallel sweep, where planting a file at the production slot would race everything).
	var runner: String = FileAccess.get_file_as_string(RUNNER)
	_check(runner.length() > 1000, "tools/run_harness.sh read (%d chars)" % runner.length())
	# THE VERB IS NO LONGER ADJACENT TO THE SCRIPT NAME, and this guard went red the day that changed --
	# correctly, and for a reason worth recording. It matched the literal `save_sentinel.gd -- arm`, which
	# was one of three bare `"$GODOT" --headless ... | grep` invocations. Those had no wall-clock cap, in
	# the one part of the suite whose failure costs a person their save file, so they were collapsed into a
	# `sentinel()` helper that passes the verb as `"$1"` and watches the process. The literal went with
	# them.
	#
	# THAT IS A STRUCTURAL GUARD TRACKING A LITERAL THAT MOVED, and the direction it failed in is the whole
	# point: it went RED on a change that made the runner safer, which is annoying and honest. The same
	# shape resolved the other way -- greps that kept matching PROSE after the code moved -- accounted for
	# four guards on this branch that could not fail at all.
	#
	# So it now checks the helper AND the three call sites, which is a stronger claim than the old one: the
	# old form could be satisfied by three invocations that were never reached.
	_check(runner.contains("res://tools/save_sentinel.gd -- \"$1\""),
		"the runner drives the save sentinel through one capped helper, not a bare engine call")
	_check(runner.contains("sentinel arm"), "the runner ARMS the save sentinel before the sweep")
	_check(runner.contains("sentinel verify"), "the runner VERIFIES the save sentinel after the sweep")
	# …and takes the plant back on the ABORT path too. `verify` only runs when the sweep reaches the end;
	# a run killed at any point before that leaves a marker sitting at the player's real save path, which
	# is the exact species of litter this whole instrument exists to argue nobody drops. An arm with no
	# verify protects nothing; an arm with no disarm is a promise kept only when nothing goes wrong.
	_check(runner.contains("sentinel disarm"),
		"…and DISARMS it from the cleanup trap, so an aborted run does not leave a marker behind")
	_check(runner.contains("trap harness_cleanup EXIT"),
		"…with that cleanup actually installed as an EXIT trap, not merely defined")
	# WHICH VERBS REGISTER A LAYER IS DERIVED FROM THE RUNNER, not spelled here. This used to hunt for
	# `add ` and `add_gl ` by hand. `add_excl` was added to the runner afterwards, so on the day this was
	# read, the sentinel could have been registered through the third verb and walked straight past a gate
	# still looking for the other two. A list of names inside a test is a snapshot of the code on the day
	# it was written, and this particular snapshot had already gone stale without anything turning red.
	# Anything that appends to NAMES is a registration verb, by definition, so ask the runner.
	var verbs: Array[String] = []
	var appenders: int = 0
	for line: String in runner.split("\n"):
		var t: String = line.strip_edges()
		if not t.contains("NAMES+=("):
			continue
		appenders += 1
		var paren: int = t.find("() {")
		if paren > 0:
			verbs.append(t.substr(0, paren))
	# No floor of "3" here: that would be the same snapshot mistake one level up. The property is that
	# every line which can append a layer was attributed to a verb this checks. Refactor the runner into
	# a multi-line function and this goes RED asking to be taught, rather than silently covering less.
	_check(appenders > 0 and verbs.size() == appenders,
		"every layer-registering line in the runner resolved to a verb (%d/%d: %s)"
			% [verbs.size(), appenders, ", ".join(verbs)])

	var as_layer: Array[String] = []
	for line: String in runner.split("\n"):
		var t: String = line.strip_edges()
		if not t.contains("save_sentinel") or t.begins_with("#"):
			continue
		for verb: String in verbs:
			if t.begins_with(verb + " "):
				as_layer.append(t)
	_check(as_layer.is_empty(), "the sentinel is a runner instrument, not a harness layer%s"
		% ("" if as_layer.is_empty() else " — registered by: " + "; ".join(as_layer)))

	# --- 5. …and the sentinel refuses on the SAME terms the game's writer does -------------------
	# The exemption above is for a file that WRITES the production slot: `arm` plants a marker there when it
	# finds none. That is correct while `user://` is scratch and is the very damage this layer is about
	# everywhere else, so the sentinel carries its own copy of `SaveGame._fixture_may_not_write`'s rule —
	# it must, being the runner's first Godot call, where delegating would turn an un-imported checkout's
	# parse error into "could not arm the sentinel".
	#
	# Two copies of one rule drift. So the marker names are DERIVED from the game's copy rather than spelled
	# here: rename the variable in save_game.gd and this goes red asking the sentinel to be taught, instead
	# of the sentinel going on reading an environment variable that nothing sets any more — which is the
	# silent version, and would leave it planting at the real slot again.
	var game_src: String = FileAccess.get_file_as_string(SAVE_SRC)
	var sentinel_src: String = FileAccess.get_file_as_string(SENTINEL)
	_check(game_src.length() > 1000 and sentinel_src.length() > 1000,
		"save_game.gd (%d chars) and save_sentinel.gd (%d chars) both read"
			% [game_src.length(), sentinel_src.length()])
	var env_re: RegEx = RegEx.create_from_string("OS\\.get_environment\\(\"(SF_[A-Z_]+)\"\\)")
	var markers: Array[String] = []
	for m: RegExMatch in env_re.search_all(game_src):
		var n: String = m.get_string(1)
		if not markers.has(n):
			markers.append(n)
	_check(markers.size() >= 2, "the game's own write refusal keys on %d environment markers (%s)"
		% [markers.size(), ", ".join(markers)])
	var untaught: Array[String] = []
	for marker: String in markers:
		if not sentinel_src.contains(marker):
			untaught.append(marker)
	_check(untaught.is_empty(), "the sentinel consults every marker that refusal does%s"
		% ("" if untaught.is_empty() else " — never read by save_sentinel.gd: " + ", ".join(untaught)))
	_check(sentinel_src.contains("func _unguarded()"),
		"…through a named refusal of its own, not by hoping the runner always wraps it")

	if _failures == 0:
		print("check_save_isolation: PASS")
		quit(0)
	else:
		printerr("check_save_isolation: %d FAILURE(S)" % _failures)
		quit(1)
