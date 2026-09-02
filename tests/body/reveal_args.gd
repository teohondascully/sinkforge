class_name RevealArgs
extends RefCounted

## Every `--flag` `tests/body/reveal_scene.gd` takes, parsed as a PURE FUNCTION of an argv array.
##
## WHY IT LEFT THE SCENE (D0244). Two reasons, and the second is the one that matters. The scene sat at
## **398 lines against a 400-line cap** with nothing left to spend, and `docs/QUALITY.md` §2 records what
## comes next -- `sim/body/body.gd` at exactly 400 for three commits, trimmed rather than split. Argument
## parsing is the clearest thing in that file that is not scene work, so it is the thing that leaves.
##
## And it was **untestable where it was**, because it read `OS.get_cmdline_user_args()` directly: there
## was no way to ask "what does `--camera=3,4` do" without launching a process. Here `parse()` takes its
## argv, so `tests/test_reveal_args.gd` can pose a flag and read the answer. The scene keeps APPLYING the
## result -- that half genuinely is scene work, and splitting parse from apply is the real seam rather
## than a line-count convenience.
##
## Defaults live here, once. A caller reads a key it did not pass and gets the same value the scene would
## have used, so a test never has to restate them.

const CELL: int = Heightfield.TERRAIN_CELL_PX


## What the scene uses when a flag is absent. Its own function so a test can assert a default without
## restating it, and so `parse()` stays under the 50-line function gate.
static func defaults() -> Dictionary:
	return {
		"site_id": &"reveal_test_dense",
		"seed": 20260826,
		"screenshot_tick": -1,
		"screenshot_path": "",
		# STILL 6.0, AND THE LADDER BESIDE IT SAYS WHY. `CameraRig.ZOOM_LEVELS` ports legacy's framing
		# (index 0 = 40 metres, legacy's own "40x22-cell field"), but two measured facts block using it:
		# the play site is 48 cells = 12 METRES wide, so 40 metres frames 28 metres of void; and at that
		# framing the per-frame painter loops measure 22.5 ticks/s against a 120Hz bar. Both are fixed by
		# `TerrainBake` + a wider world, not by this constant. D0325.
		"camera_zoom": 6.0,
		"fixed_camera": Vector2.ZERO,
		"has_fixed_camera": false,
		"bite_radius": -1,   ## -1 means "leave whatever the mining verb defaults to"
		"mine_down": false,
		"wide_view": false,
		"sky": false,
		"play": false,   ## the MODE flag -- see `parse()`'s note on why it arrived late
	}


## Parse `argv` into a flat config. Unknown arguments are IGNORED rather than rejected: the scene shares
## its command line with Godot's own (`--path`, `--headless`, `--`), and a parser that refused what it did
## not recognise would refuse those too.
static func parse(argv: PackedStringArray) -> Dictionary:
	var cfg: Dictionary = defaults()
	for arg: String in argv:
		if arg.begins_with("--screenshot-tick="):
			cfg["screenshot_tick"] = int(arg.trim_prefix("--screenshot-tick="))
		elif arg.begins_with("--screenshot-out="):
			cfg["screenshot_path"] = arg.trim_prefix("--screenshot-out=")
		elif arg.begins_with("--site="):
			cfg["site_id"] = StringName(arg.trim_prefix("--site="))
		elif arg.begins_with("--seed="):
			cfg["seed"] = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--zoom="):
			cfg["camera_zoom"] = float(arg.trim_prefix("--zoom="))
		elif arg.begins_with("--camera="):
			# `--camera=col,row` pins the camera to a stated terrain cell and leaves it there. Milestone
			# captures need a FIXED frame across commits -- a body-following camera makes two shots of the
			# same world incomparable, which defeats the whole point of a before/after pair.
			var parts: PackedStringArray = arg.trim_prefix("--camera=").split(",")
			cfg["has_fixed_camera"] = parts.size() == 2
			if parts.size() == 2:
				cfg["fixed_camera"] = Vector2(float(parts[0]) * CELL, float(parts[1]) * CELL)
		elif arg.begins_with("--bite="):
			# D0200 (Slice 1.5). The probe's own dial, and its own control: `--bite=0` is exactly the
			# Slice 1 single-cell blow, so a director sweeping this flag is running the experiment rather
			# than reading a verdict on it.
			cfg["bite_radius"] = int(arg.trim_prefix("--bite="))
		elif arg == "--mine-down":
			cfg["mine_down"] = true  ## D0195: agent mode aims straight down and holds, so the mining verb
			## has a deterministic, headless, reproducible proof that needs no human at the keyboard
		elif arg == "--wide-view":
			cfg["wide_view"] = true  ## D0121: camera centers on the whole generated area (grid midpoint),
			## not the body -- the body-following camera at zoom 6.0 shows ~28% of the topsoil band's own
			## vertical extent in one frame, which is why the first density-contrast screenshots (D0109's
			## round) read as nearly identical regardless of the real underlying count difference.
		elif arg == "--play":
			# THE MODE FLAG, and it lived outside this parser until 2026-08-31 (D0248) -- the scene read
			# `"--play" in OS.get_cmdline_user_args()` directly, from before the D0244 split, and the split
			# did not notice because it was moving a FUNCTION rather than enumerating a surface. Found when
			# the director ran the documented command and got an agent-mode run that drove itself 12 ticks
			# and quit. Without it this scene scripts its own approach; with it, a human drives.
			cfg["play"] = true
		elif arg == "--sky":
			cfg["sky"] = true  ## D0244: draw the lifted `SkyPainter` behind the world. OFF by default,
			## deliberately -- every existing milestone shot, replay and suite was taken without it, and a
			## backdrop that appeared unasked would change what those captures mean.
	return cfg
