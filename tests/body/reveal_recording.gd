class_name RevealRecording
extends RefCounted

## Writes `tests/body/reveal_scene.gd`'s input recording to disk.
##
## Split out of the scene (D0244) for the same reason `RevealArgs` was: the file sat at its 400-line cap
## and this is not scene work. A recording is a FILE FORMAT -- a header line, a column header, and one
## row per tick -- and the format is what `RevealReplayDriver` reads back. Keeping it beside the scene
## that happens to produce it made the writer and the reader live in different kinds of file.

## `bite=` is as load-bearing as `site=`/`seed=` (D0200): the same inputs at a different bite radius
## diverge on the first break, so a log that cannot restate it cannot be replayed as played.
static func write(rows: Array[PackedStringArray], play_mode: bool, site_id: StringName,
		seed_value: int, bite_radius: int) -> void:
	if rows.is_empty():
		return
	var dir_path: String = "res://tests/body/recordings"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var prefix: String = "play" if play_mode else "agent"
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var path: String = "%s/reveal_%s_%s.log" % [dir_path, prefix, stamp]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("reveal_recording: could not open %s for writing (%s)"
			% [path, error_string(FileAccess.get_open_error())])
		return
	f.store_line("# sinkforge reveal-scene input recording -- mode=%s ticks=%d site=%s seed=%d bite=%d" %
		[prefix, rows.size(), site_id, seed_value, bite_radius])
	f.store_line(RevealReplayDriver.COLUMN_HEADER_V2)
	for row: PackedStringArray in rows:
		f.store_line(",".join(row))
	f.close()
	print("reveal_scene: wrote %d ticks to %s" % [rows.size(), path])
