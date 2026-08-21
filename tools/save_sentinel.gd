extends SceneTree

## Runner instrument (NOT a harness layer; it asserts nothing on its own): brackets a harness run and
## proves the developer's real save came out the other side byte-identical.
##
## `tools/check_save_isolation.gd` proves no fixture can NAME the production slot. That is a source scan,
## so it cannot see a path assembled at runtime, a stray `DirAccess.remove_absolute` on a globalized
## path, or a crash mid-write. This is the empirical half: arm before the sweep, verify after.
##
##   godot --headless --path . --script res://tools/save_sentinel.gd -- arm    <statefile>
##   godot --headless --path . --script res://tools/save_sentinel.gd -- verify <statefile>
##   godot --headless --path . --script res://tools/save_sentinel.gd -- disarm <statefile>
##
## When a real save is present it is READ ONLY: hashed, never rewritten, never moved. When none is
## present a sentinel is planted so the empty case is still covered, and `verify` removes what `arm`
## planted. The planted bytes are deliberately NOT a valid SaveGame envelope: if anything did try to load
## it, `SaveGame.read` returns {} and the game says "no save to load" rather than acting on garbage.
##
## WHY PLANT AT ALL. The question is worth answering, because this instrument writing the real save path
## is the one thing about it that looks wrong. Without a plant, the empty case reads "absent before,
## absent after: pass", and that is precisely the shape of the original defect, which drove the real slot
## and then DELETED it. Absent-to-absent cannot tell "nothing happened" from "written, then removed".
## The marker turns both halves of that into evidence: overwrite it and the hash moves, delete it and the
## file is gone. So the plant stays, and `disarm` is what pays for it, so an aborted run cannot leave the
## marker sitting at the player's path waiting for some later run to adopt it.
##
## WHAT DISARM ACTUALLY COVERS, measured 2026-08-17 by killing real runs mid-sweep rather than reasoning
## about it. The runner's EXIT trap fires on an untrapped fatal signal, so:
##   SIGHUP  (rc 129)  disarm ran, slot clean, lock released
##   SIGTERM (rc 143)  disarm ran, slot clean, lock released
##   SIGKILL (rc 137)  NOT COVERED, and cannot be: the trap never runs. Marker and lock both survive.
##   SIGINT            not exercised. Bash sets SIG_IGN on asynchronous jobs and `trap -` cannot reset a
##                     signal inherited as ignored, so a scripted Ctrl-C is swallowed and every attempt to
##                     test it produced a run that simply finished. Interactively (job control on) it is
##                     the same bash path as HUP/TERM, but that is an argument, not a measurement.
## SIGKILL is left uncovered on purpose. Both leftovers already have backstops that ARE tested: the next
## `arm` adopts a stale marker as litter, and the runner clears a lock whose owning pid is gone. And a
## `kill -9` that still tidied up after itself would mean trapping the one signal that must stay untrappable.

const SLOT: String = "user://sinkforge.save"
## The leading bytes of every marker, used to recognise A HARNESS marker in the slot. Matching a prefix
## rather than the whole string on purpose: a run killed mid-plant leaves a truncated marker, and that is
## still litter to be adopted rather than a save to be protected.
const MARKER_HEAD: String = "SINKFORGE-HARNESS-SENTINEL"


## The marker THIS run plants, carrying its pid, so no two runs ever plant the same bytes.
##
## It used to be a constant, and that made every run's marker byte-identical, which quietly broke the one
## thing the state file is for. `verify` and `disarm` decide what they may remove by comparing the slot's
## hash to the digest they armed with; against a fixed string that comparison says "these are the same
## BYTES", not "this marker is this run's". So a run finishing next to a neighbour would cheerfully delete the
## neighbour's live plant, and each would then accuse the harness of eating a save that never existed.
## The pid makes the digest a genuine identity. Two runs at once is still a thing the lock exists to stop;
## it should not also be a thing that produces false accusations when somebody overrides it.
static func _plant() -> String:
	return "%s // not a save; delete me freely (pid %d)" % [MARKER_HEAD, OS.get_process_id()]


# THE PRODUCTION WITNESS, and why it is a different instrument from everything above.
# Once `run_harness.sh` moved HOME, `user://` stopped being the player's directory, so the marker this
# file plants is planted in scratch, and the old claim "the harness never touches your save" became true
# by construction. True by construction is not proved: the isolation is three lines of shell that a future
# edit can drop without any test noticing. So the runner hands over the REAL path it just stopped using
# and it is hashed, before and after, WITHOUT EVER OPENING IT FOR WRITE. Absent is a legitimate reading
# and is recorded as such: the player having no save is not a failure, but "absent then present" is.
const NO_WITNESS: String = "-"


func _production_digest() -> String:
	var path: String = OS.get_environment("SF_PRODUCTION_SLOT")
	if path.is_empty():
		return NO_WITNESS          # not under the runner (a bare `--script` call); nothing claimed
	if not FileAccess.file_exists(path):
		return "absent"
	return FileAccess.get_sha256(path)


func _initialize() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() < 2:
		printerr("save_sentinel: usage: -- arm|verify <statefile>")
		quit(2)
		return
	var mode: String = argv[0]
	var statefile: String = argv[1]
	var real: String = ProjectSettings.globalize_path(SLOT)

	if mode == "arm":
		# "Is there a real save here?" is NOT the same question as "does the file exist". A marker left
		# behind by a run that was killed, or by a concurrent run on this machine (user:// is keyed on the
		# project NAME, so worktrees share one slot), exists, and arming on existence alone recorded it as
		# kind=real, which meant verify would never clean it up and every later run reported "REAL SAVE
		# PRESENT" for the harness's own litter. That happened, and it cost an investigation.
		# The harness's own bytes are recognisable, so recognise them: a marker it planted is its to remove.
		var existing: bool = FileAccess.file_exists(SLOT)
		var stale: bool = existing and FileAccess.get_file_as_string(SLOT).begins_with(MARKER_HEAD)
		var planted: bool = not existing or stale
		if stale:
			print("save_sentinel: adopting a stale marker left by an earlier run — it is litter, not a save")
		if planted and not existing:
			var f: FileAccess = FileAccess.open(SLOT, FileAccess.WRITE)
			if f == null:
				printerr("save_sentinel: cannot plant a sentinel at %s — refusing to run unguarded" % real)
				quit(1)
				return
			f.store_string(_plant())
			f.close()
		var digest: String = FileAccess.get_sha256(SLOT)
		var witness: String = _production_digest()
		var out: FileAccess = FileAccess.open(statefile, FileAccess.WRITE)
		out.store_line("planted" if planted else "real")
		out.store_line(digest)
		out.store_line(witness)
		out.close()
		var what: String = "planted"
		if stale:
			# ADOPTED, not re-planted. The bytes on disk are left exactly where they are and hashed as they
			# stand; nothing is rewritten on this path. Saying "re-planted" described a write that never
			# happened, in the log line of the one instrument whose whole subject is who wrote what.
			what = "adopted a stale marker"
		elif not planted:
			what = "REAL SAVE PRESENT"
		print("save_sentinel: armed (%s, sha=%s)" % [what, digest.substr(0, 12)])
		quit(0)
		return

	if mode == "verify":
		if not FileAccess.file_exists(statefile):
			printerr("save_sentinel: no armed state at %s" % statefile)
			quit(2)
			return
		var st: PackedStringArray = FileAccess.get_file_as_string(statefile).split("\n")
		var kind: String = st[0].strip_edges()
		var want: String = st[1].strip_edges()
		if not FileAccess.file_exists(SLOT):
			printerr("save_sentinel: THE SAVE SLOT WAS DELETED BY THE HARNESS — %s" % real)
			quit(1)
			return
		var got: String = FileAccess.get_sha256(SLOT)
		if got != want:
			printerr("save_sentinel: THE SAVE SLOT WAS REWRITTEN BY THE HARNESS — %s" % real)
			printerr("save_sentinel: armed sha=%s, now sha=%s. The file is LEFT IN PLACE for inspection." % [want, got])
			quit(1)
			return
		if kind == "planted":
			DirAccess.remove_absolute(SLOT)   # ours to remove: this run created it

		# The witness is checked AFTER the slot verdict and reported separately, because the two answer
		# different questions and a run can fail one while passing the other. `-` means the runner never
		# named a production slot, so this run claims nothing about one: printed, not silently skipped.
		var was: String = st[2].strip_edges() if st.size() >= 3 else NO_WITNESS
		var now: String = _production_digest()
		if was != NO_WITNESS and now != was:
			printerr("save_sentinel: THE PLAYER'S REAL SAVE CHANGED DURING THIS RUN — %s"
					% OS.get_environment("SF_PRODUCTION_SLOT"))
			printerr("save_sentinel: armed=%s, now=%s. Isolation did not hold." % [was, now])
			quit(1)
			return
		if was == NO_WITNESS:
			print("save_sentinel: verified — the run's own slot is untouched (no production slot named)")
		else:
			print("save_sentinel: verified — the run's own slot is untouched, and the player's real save is "
					+ "byte-identical (%s)" % ("absent throughout" if was == "absent" else was.substr(0, 12)))
		quit(0)
		return

	# DISARM: the abort path. `verify` is the normal way a plant comes back up, but a run that is killed by
	# Ctrl-C, a crashed runner, or a machine that goes down never reaches it, and the marker then sits at the
	# player's real save path until some later run happens to adopt it. The instrument whose entire subject
	# is "nothing wrote that path" must not itself be what leaves litter on it.
	#
	# Removes ONLY what this run planted, and only while it is still byte-identical to what was planted. If
	# the bytes moved, something wrote the slot during the run, and that is evidence; it stays on disk for
	# whoever comes to look at it.
	#
	# DISARM NEVER FAILS. It is a shell trap handler's last act, and cleanup that can abort the trap is how
	# one problem becomes two. Every path here exits 0; the loudest it gets is a line on stderr.
	if mode == "disarm":
		if not FileAccess.file_exists(statefile):
			quit(0)                     # never armed, or the log dir is already gone. Nothing to take back.
			return
		var dst: PackedStringArray = FileAccess.get_file_as_string(statefile).split("\n")
		if dst.size() >= 2 and dst[0].strip_edges() == "planted" and FileAccess.file_exists(SLOT):
			if FileAccess.get_sha256(SLOT) == dst[1].strip_edges():
				DirAccess.remove_absolute(SLOT)
				print("save_sentinel: disarmed — took back the marker this run planted")
			else:
				printerr("save_sentinel: NOT removing %s — it no longer matches what was planted, so " % real
					+ "something wrote it during the run. Left in place as evidence.")
		quit(0)
		return

	printerr("save_sentinel: unknown mode '%s'" % mode)
	quit(2)
