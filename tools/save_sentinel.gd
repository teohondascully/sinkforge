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
		var planted: bool = not FileAccess.file_exists(SLOT)
		if planted:
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
		print("save_sentinel: armed (%s, sha=%s)" % ["planted" if planted else "REAL SAVE PRESENT", digest.substr(0, 12)])
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
