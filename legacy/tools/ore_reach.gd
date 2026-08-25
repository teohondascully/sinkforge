extends SceneTree

## HOW FAR IS YOUR FIRST ORE? One number per seed, and it exists to settle an argument that no amount of
## re-running the play harness could settle.
##
## `check_pacing` fails on five of the committed eight seeds, and on two of them the opening never reaches
## first automation at all. Two hypotheses predict that identically: the play driver is wasteful, or those
## two worlds start you a long way from anything you can smelt. Both produce the same 9632 dead frames on
## seed 512, so every further run of the play rig accumulates no evidence about which one it is. This is the
## measurement whose OUTPUT DIFFERS under the two, which is the only kind worth adding.
##
## It asserts nothing and is deliberately not a harness layer. It is a ruler.
##
## THE PREDICATE IS COPIED, NOT REINVENTED. `arc_driver.gd::_nearest_ore_not_shaft` searches `sim.solid` for
## cells equal to `&"ore"`, skipping the mineshaft column, and takes the euclidean nearest to the player. If
## this tool measured "nearest ore" some other way it would answer a question the driver never asks, so the
## scan below is that function with a print in place of a return. Two consequences fall straight out of
## copying it rather than improving it: `&"rich_ore"` is NOT ore to that search, and a lode is not ore to it
## either. Both are counted here separately, precisely because the driver cannot see them.
##
##     SF_SEED=512 godot --headless --path . --script res://tools/ore_reach.gd
##
## Headless-safe: it boots `main.tscn` exactly as `check_pacing` does, and that layer is registered with
## `add` rather than `add_gl`. Nothing here reads a SubViewport or awaits `frame_post_draw`, which are the
## two things that HANG rather than fail under the dummy renderer.

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")

## Radii to report a count at, in CELLS. The smallest is roughly a screen; the largest is far enough that
## reaching it is a journey rather than a detour.
const RADII: Array[int] = [10, 20, 40, 80]


func _initialize() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:
		await physics_frame
	var agent: PlayAgent = AGENT.new(self, main)
	var sim: FactorySim = agent.sim
	var from: Vector2 = agent.player.position
	var spawn: Vector2i = main._cell_at(from)
	var cell_f: float = float(WorldRenderer.CELL)

	# --- the driver's own search, verbatim except for what it returns -------------------------------
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	var n_ore: int = 0
	var within: Dictionary = {}
	for r: int in RADII:
		within[r] = 0
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		if sim.solid[c] != &"ore" or c.x == MainView.MINESHAFT_COL:
			continue
		n_ore += 1
		var d: float = main._cell_center(c).distance_to(from) / cell_f
		if d < best_d:
			best_d = d
			best = c
		for r: int in RADII:
			if d <= float(r):
				within[r] = int(within[r]) + 1

	# --- and the two planes the driver is blind to --------------------------------------------------
	var n_rich: int = 0
	var rich_d: float = INF
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		if sim.solid[c] != &"rich_ore" or c.x == MainView.MINESHAFT_COL:
			continue
		n_rich += 1
		rich_d = minf(rich_d, main._cell_center(c).distance_to(from) / cell_f)

	var n_lode: int = 0
	var lode_d: float = INF
	for cell: Variant in sim.lode:
		var c: Vector2i = cell
		n_lode += 1
		lode_d = minf(lode_d, main._cell_center(c).distance_to(from) / cell_f)

	# --- report -------------------------------------------------------------------------------------
	var seed_env: String = str(OS.get_environment("SF_SEED"))
	print("seed %s  spawn %s" % [seed_env if not seed_env.is_empty() else "(default)", str(spawn)])
	if best.x < 0:
		# The driver returns (-1,-1) here and its caller gives up immediately, so this is the one outcome
		# that does NOT produce a long silence. Worth distinguishing in the output, because "no ore at all"
		# and "ore a long way off" are opposite diagnoses that both end in a failed opening.
		print("  solid ore: NONE reachable by the driver's predicate (it would return -1 and give up)")
	else:
		print("  solid ore: %d cells, nearest %.1f cells away at %s" % [n_ore, best_d, str(best)])
	var parts: PackedStringArray = PackedStringArray()
	for r: int in RADII:
		parts.append("%d within %d" % [int(within[r]), r])
	print("    %s" % ", ".join(parts))
	print("  rich_ore:  %d cells, nearest %s   (invisible to the driver's search)"
		% [n_rich, "n/a" if is_inf(rich_d) else "%.1f cells" % rich_d])
	print("  lode:      %d cells, nearest %s   (invisible to the driver's search)"
		% [n_lode, "n/a" if is_inf(lode_d) else "%.1f cells" % lode_d])
	quit(0)
