extends SceneTree

## D0129/claims/C004. Command-line front end for `RevealReplayDriver`:
##
##   godot --headless --path . --script tests/body/replay_reveal_scene.gd -- --log=<path>
##
## `<path>` is whatever `reveal_scene.gd` printed after "wrote N ticks to" -- a `res://tests/body/
## recordings/reveal_*.log` path by default; a bare relative path is treated as `res://`-relative for
## convenience. Prints one `REPLAY_METRIC` line (parseable, matching this project's own `FUZZ_SUMMARY`
## convention) and exits 1 on any parse failure rather than a silent empty result.

func _initialize() -> void:
	var log_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--log="):
			log_path = arg.trim_prefix("--log=")
	if log_path == "":
		push_error("replay_reveal_scene: --log=<path> is required")
		quit(1)
		return
	if not (log_path.begins_with("res://") or log_path.begins_with("user://") or log_path.begins_with("/")):
		log_path = "res://" + log_path

	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
	if parsed == null:
		quit(1)
		return
	if parsed.mode == "agent":
		print("replay_reveal_scene: WARNING -- this log is agent-mode (a scripted, deterministic walk),")
		print("  not real unscripted human play. claims/C004 needs the latter; this replay proves the")
		print("  plumbing works, not that the reveal layer's real effect on human play is measured.")

	var events: Array[RevealMetric.TickEvent] = RevealReplayDriver.replay(parsed)
	var result: Dictionary = RevealMetric.compute(events, &"glimmer")
	var lift_str: String = ("%.4f" % result["lift"]) if result.has("lift") else "n/a"
	print("REPLAY_METRIC site=%s seed=%d mode=%s total_ticks=%d dig_events=%d qualifying_reveals=%d lift=%s" % [
		parsed.site_id, parsed.seed_value, parsed.mode,
		result["total_ticks"], result["dig_events"], result["qualifying_reveals"], lift_str])
	quit(0)
