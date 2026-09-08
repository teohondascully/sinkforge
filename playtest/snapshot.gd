extends SceneTree
## The batch's fresh-game snapshot (D0519): ONE `Session.new_game` for a head, a seed and a start record,
## written as a save that every seat of the batch opens instead of generating its own world. D0518
## measured generation at 2.1 s of the 2.7 s `new_game` and proved a restored door signs identically to a
## generated one at t0 and after 600 ticks; D0462's `--load` lane is what the seat already opens it with.
##
## Nothing of the HUD is in the envelope (`Session.capture`, not `Main.capture_session`), so a loaded seat
## starts with the hints and the ladder as fresh as a new game's. The key is the batch's HEAD by construction:
## `batch.py` names the file by it and never reuses one across heads.
##
##     godot --headless --path . -s playtest/snapshot.gd -- --out=<path> [--seed=<n>] [--start=<id>]

func _initialize() -> void:
	var out: String = ""
	var seed: int = Main.SEED
	var start: StringName = Main.START
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--start="):
			start = StringName(arg.trim_prefix("--start="))
	if out == "":
		printerr("snapshot: --out=<path> is required")
		quit(2)
		return
	var t: int = Time.get_ticks_msec()
	var door: Interface = Session.new_game(StrataData.get_site(Main.SITE), seed, start)
	if door == null:
		printerr("snapshot: new_game refused (%s)" % WorldSeeder.last_refusal)
		quit(1)
		return
	var generated: int = Time.get_ticks_msec() - t
	t = Time.get_ticks_msec()
	var ok: bool = SaveGame.write(out, Session.capture(door))
	print("SINKFORGE_SNAPSHOT out=%s seed=%d start=%s signature=%s generate_ms=%d write_ms=%d ok=%s" % [
		out, seed, start, door.state_signature().md5_text(), generated, Time.get_ticks_msec() - t, ok])
	quit(0 if ok else 1)
