extends "res://tools/check_base.gd"

## Harness layer: NO SOURCE FILE CARRIES MOJIBAKE. Headless, no scene, pure text.
##   godot --headless --path . --script res://tools/check_encoding.gd
##
## WHY THIS EXISTS. A byte-oriented editor — `perl -0777 -i -pe`, `sed` on some platforms — reads a file
## as Latin-1. Feed one a UTF-8 source containing an em dash and every `—` comes back as three characters
## whose bytes are `c3 a2 c2 80 c2 94`, silently. The only signal is `Wide character in print` on stderr,
## which is easy to read past when the command reports success.
##
## It happened here, across FIVE files and 925 characters, and was committed twice before an adversarial
## review found it. The damage was not cosmetic: corrupted text landed inside live `_check` and `print`
## strings, so the harness's own log was garbled — and **about 30% of one commit's diff turned out to be
## encoding noise**, which makes the history lie to whoever reads it next. A reviewer diffing that commit
## sees ninety-six deletions that never happened.
##
## U+0080..U+009F are C1 control characters. Nothing legitimate in prose or GDScript produces them, and one
## round of the Latin-1/UTF-8 confusion always does. That makes the test cheap and total.
##
## THE POPULATION IS EVERY TRACKED TEXT FILE THIS SCAN CAN REACH, walked from the project root rather than
## listed, so a file added tomorrow is covered without anyone remembering to add it. The non-vacuity arm
## below matters more than usual here: a scanner that walks the wrong directory finds nothing and passes,
## which looks exactly like a clean repository.

const EXTS: Array[String] = ["gd", "md", "sh", "cfg", "godot"]
const SKIP_DIRS: Array[String] = [".git", ".godot", "history"]
## The floor is far below the real count so a clean checkout cannot fail it, and the real non-vacuity
## carries in `CANARY`: named files that MUST be in the walk. A count alone passes on any 60 files at all.
const MIN_FILES: int = 60
const CANARY: Array[String] = [
	"res://scenes/main.gd", "res://tools/run_harness.sh", "res://docs/MENU_MATRIX.md",
]


func _walk(dir: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		var full: String = dir.path_join(name)
		if d.current_is_dir():
			if not name.begins_with(".") and not SKIP_DIRS.has(name):
				_walk(full, out)
		elif EXTS.has(name.get_extension()):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


## How many C1 control characters a file carries. Read as raw BYTES and decoded here, because
## `FileAccess.get_as_text()` would hand back replacement characters and hide the very fault being sought.
func _mojibake(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	var hits: int = 0
	var i: int = 0
	while i < bytes.size() - 1:
		# C1 in UTF-8 is exactly 0xC2 followed by 0x80..0x9F. Scanning the encoded form means this never
		# depends on how the engine chose to decode the file.
		if bytes[i] == 0xC2 and bytes[i + 1] >= 0x80 and bytes[i + 1] <= 0x9F:
			hits += 1
			i += 2
		else:
			i += 1
	return hits


func _initialize() -> void:
	var files: Array[String] = []
	_walk("res://", files)

	_check(files.size() >= MIN_FILES,
		"the walk reached the repository at all — %d text files scanned (floor %d)"
			% [files.size(), MIN_FILES])
	var missing: Array[String] = []
	for c: String in CANARY:
		if not files.has(c):
			missing.append(c)
	_check(missing.is_empty(),
		"and it reached the files it is named for, so an empty result cannot masquerade as a clean repo (%s)"
			% ("all three found" if missing.is_empty() else ", ".join(missing)))

	var bad: Array[String] = []
	var total: int = 0
	for path: String in files:
		var n: int = _mojibake(path)
		if n > 0:
			bad.append("%s (%d)" % [path.trim_prefix("res://"), n])
			total += n
	_check(bad.is_empty(),
		"no source file carries mojibake — %s" % ("clean" if bad.is_empty()
			else "%d characters across %d files: %s" % [total, bad.size(), ", ".join(bad)]))

	# THE DETECTOR MUST BE ABLE TO SEE ITS SUBJECT. Built here rather than committed as a fixture file,
	# because a mojibake file checked into the tree would be found by the scan above and fail the layer.
	var probe: String = "user://_mojibake_probe.gd"
	var w: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	w.store_buffer(PackedByteArray([0x78, 0x20, 0xC3, 0xA2, 0xC2, 0x80, 0xC2, 0x94, 0x0A]))
	w.close()
	_check(_mojibake(probe) > 0,
		"and it CAN see one: a synthesised mojibake em dash is detected (%d)" % _mojibake(probe))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))

	_verdict("check_encoding", "%d text files, no Latin-1/UTF-8 damage" % files.size())
