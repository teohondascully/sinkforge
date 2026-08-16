extends SceneTree

## Harness layer: THE DIG-HITCH FRICTION GAUGE (#103, the mining micro-freeze guard).
##
## The reported bug: every hand-dig micro-froze the frame because the fine-terrain baker
## (scenes/fine_terrain.gd) re-processed the WHOLE ~120k-cell fine grid on EVERY terrain change — a
## Callable + ~9 noise samples per cell — even though a single dig only changes one 32px cell. This gauge
## makes that friction EXECUTABLE so it can never silently come back:
##
##   FRICTION  — after a single dig the renderer's fine rebake must touch <= MAX_DIG_CELLS fine cells (the
##               dirty-chunk fast lane), not the whole grid. Before #102 this reads the full grid → FAIL.
##   CORRECT   — the dirty-chunk region bake must be BYTE-IDENTICAL to a full rebake of the same post-dig
##               world (guards the dilation margin: too small a margin would leave stale AO/moss seams).
##
## It boots the REAL scene and digs through the real sim, so it measures the path the game actually runs.
## HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_dig_hitch.gd

const SCENE: String = "res://scenes/main.tscn"
const FINE_SEED: int = 1337                 ## must match WorldRenderer's FineTerrain.new(..., 1337)
## A single 32px dig dilated by REGION_MARGIN(6) is a ~16×16 fine patch (256 cells). Allow generous slack
## for a dig that dirties a small cluster, but far below the ~120k full grid — the freeze is unmistakable.
const MAX_DIG_CELLS: int = 4096

var _main: MainView
var _frames: int = 0
var _failures: int = 0
var _dig_cell: Vector2i


func _initialize() -> void:
	Engine.max_fps = 120
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	process_frame.connect(_on_frame)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _on_frame() -> void:
	_frames += 1
	var sim: FactorySim = _main.sim
	if _frames == 10:
		# The initial full bake has run (renderer inits _fine_dirty=true). Confirm the baseline reads the
		# WHOLE grid — this is the cost a per-dig rebake must NOT pay.
		var full: int = _main._renderer._fine.last_baked_cells
		_check(full == FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV
			or full > MAX_DIG_CELLS, "initial full bake touched the whole grid (%d cells)" % full)
		# Pick a deep interior solid cell so mining it dirties exactly one cell (no tree-fell / ore-collapse
		# / surface shift) — the cleanest single-dig friction measurement.
		var mid: int = FactorySim.GRID_COLS / 2
		_dig_cell = Vector2i(mid, sim.surface_row(mid) + 10)
		_check(sim.is_solid(_dig_cell), "chosen dig cell is solid interior rock %s" % _dig_cell)
		return
	if _frames == 13:
		sim.mine(_dig_cell)   # the real dig verb — appends the cell to sim.terrain_dirty
		return
	if _frames == 18:
		# The renderer has consumed terrain_dirty and taken the fine fast lane by now.
		var cells: int = _main._renderer._fine.last_baked_cells
		print("  dig rebaked %d fine cells (limit %d, full grid ~%d)" % [cells, MAX_DIG_CELLS,
			FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV])
		_check(cells > 0, "a dig triggered a fine rebake")
		_check(cells <= MAX_DIG_CELLS, "a single dig rebakes a SMALL region, not the whole grid (no freeze)")

		# CORRECTNESS: a full rebake of the SAME post-dig world must be byte-identical to the region bake the
		# renderer just did — reuse the renderer's exact palette/wall/surface authorities so only the bake
		# PATH differs, not the inputs.
		var r: WorldRenderer = _main._renderer
		var ref := FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, FINE_SEED)
		ref.rebake(
			func(c: Vector2i) -> bool: return r.sim.is_solid(c),
			func(fx: int, fy: int) -> bool: return r.sim.fine_is_solid(fx, fy),
			func(c: Vector2i) -> Color: return r._cell_base_color(c, r._material(r.sim.material_at(c))),
			r._wall_fill_color,
			func(col: int) -> int: return r.sim.surface_row(col),
			r._cell_tone)
		var got: PackedByteArray = r._fine.texture().get_image().get_data()
		var want: PackedByteArray = ref.texture().get_image().get_data()
		_check(got == want, "region bake is byte-identical to a full bake of the same world (margin is safe)")

		if _failures == 0:
			print("check_dig_hitch: PASS")
			quit(0)
		else:
			printerr("check_dig_hitch: %d FAILURE(S)" % _failures)
			quit(1)
