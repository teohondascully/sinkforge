extends SceneTree

## Runner instrument (NOT a harness layer — it asserts nothing on its own): brackets a harness run and
## proves the developer's real save came out the other side byte-identical.
##
## `tools/check_save_isolation.gd` proves no fixture can NAME the production slot. That is a source scan,
## so it cannot see a path assembled at runtime, a stray `DirAccess.remove_absolute` on a globalized
## path, or a crash mid-write. This is the empirical half: arm before the sweep, verify after.
##
##   godot --headless --path . --script res://tools/save_sentinel.gd -- arm    <statefile>
##   godot --headless --path . --script res://tools/save_sentinel.gd -- verify <statefile>
##
## When a real save is present it is READ ONLY — hashed, never rewritten, never moved. When none is
## present a sentinel is planted so the empty case is still covered (a harness that deletes an absent
## file is indistinguishable from one that leaves it alone), and `verify` removes what `arm` planted.
## The planted bytes are deliberately NOT a valid SaveGame envelope: if anything did try to load it,
## `SaveGame.read` returns {} and the game says "no save to load" rather than acting on garbage.

const SLOT: String = "user://sinkforge.save"
const PLANT: String = "SINKFORGE-HARNESS-SENTINEL // not a save; delete me freely"
## The leading bytes of PLANT, used to recognise OUR OWN marker in the slot. Matching a prefix rather than
## the whole string on purpose: a run killed mid-plant leaves a truncated marker, and that is still litter.
const MARKER_HEAD: String = "SINKFORGE-HARNESS-SENTINEL"


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
		# project NAME, so worktrees share one slot), exists — and arming on existence alone recorded it as
		# kind=real, which meant verify would never clean it up and every later run reported "REAL SAVE
		# PRESENT" for the harness's own litter. That happened, and it cost an investigation.
		# Our own bytes are recognisable, so recognise them: a marker is ours to own and ours to remove.
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
			f.store_string(PLANT)
			f.close()
		var digest: String = FileAccess.get_sha256(SLOT)
		var out: FileAccess = FileAccess.open(statefile, FileAccess.WRITE)
		out.store_line("planted" if planted else "real")
		out.store_line(digest)
		out.close()
		var what: String = "planted"
		if stale:
			what = "re-planted over stale marker"
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
		print("save_sentinel: verified — the production slot is untouched")
		quit(0)
		return

	printerr("save_sentinel: unknown mode '%s'" % mode)
	quit(2)
