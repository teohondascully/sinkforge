extends "res://tools/check_base.gd"

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
##   COST      — the region bake must actually be CHEAP IN TIME, not merely small in extent.
##
## That last one was missing for a long time and its absence is worth writing down. This layer is
## registered as "check_dig_hitch (friction)" and every assertion in it counted CELLS. Extent is a proxy
## for cost, and it is a proxy that breaks exactly where it matters: the tile-texture work adds ~2 extra
## noise samples per solid fine cell, which makes every bake more expensive while touching precisely the
## same number of cells. The measured original defect — DIG p95 33.8ms → 19.8ms — could have walked back
## in and this gauge would have printed PASS the whole way.
##
## An ABSOLUTE millisecond budget is not the answer on arbitrary hardware; it flakes, and someone deletes
## it. So the always-on assertion is a RATIO measured twice on the same machine in the same process: bake
## the full grid, bake one region, and compare their per-cell costs. A region bake is allowed to be dearer
## per cell (fixed setup amortised over few cells, worse cache locality) but not wildly so — that is what
## "the fast lane is genuinely a fast lane" means in time rather than in cell count. The per-cell µs of
## both is always PRINTED, so drift is visible to a human even when the ratio holds, and an absolute
## budget can be switched on for one named machine via SF_PERF_HOST.
##
## It boots the REAL scene and digs through the real sim, so it measures the path the game actually runs.
## HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_dig_hitch.gd

const SCENE: String = "res://scenes/main.tscn"
const FINE_SEED: int = 1337                 ## must match WorldRenderer's FineTerrain.new(..., 1337)
## A single 32px dig dilated by REGION_MARGIN(6) is a ~16×16 fine patch (256 cells). Allow generous slack
## for a dig that dirties a small cluster, but far below the ~120k full grid — the freeze is unmistakable.
const MAX_DIG_CELLS: int = 4096
## Each bake is timed BEST-OF-N. The minimum is the right statistic here: we are asking "what does this work
## cost", and every sample is that cost plus some amount of scheduler noise ≥ 0. Taking the min subtracts as
## much of the noise as the samples let us, which is what keeps a ratio gate usable on a loaded CI box.
const TIME_SAMPLES: int = 3
## THE PORTABLE COST GATE — per-cell, not total. A region bake's cost PER FINE CELL may exceed a full
## bake's per-cell cost, but only by this factor. Per-cell is the right normalisation: it does not care how
## many cells the dig happened to dirty, so changing REGION_MARGIN or SYNC_BAND does not silently re-tune
## the gate the way a raw total-time ratio would.
##
## Derivation, measured on an M4 Pro over four runs (every run PRINTS these numbers, so anyone can redo it):
##   full bake    6.47 / 6.54 / 6.75 / 7.01 us per cell   (262144 cells, ~1.7 s)
##   dig region   7.68 / 7.93 / 8.31 / 9.00 us per cell   (576 cells, ~4.6 ms)
##   ratio        1.19 / 1.21 / 1.23 / 1.28
## The absolutes drift together as the machine warms; the RATIO barely moves. That is exactly the property
## that makes it portable, and the reason the gate is a ratio rather than a millisecond count.
##
## Confirmed on foreign hardware AND a foreign renderer, which is the claim that actually needed testing:
## measured 1.175 on x86 Linux under xvfb + lavapipe (software rasterisation) against 1.19-1.28 on an M4
## Pro under Metal. Two architectures, two drivers, one number. A millisecond budget would have had to be
## re-derived for each; the ratio did not move.
##
## Why the ratio exceeds 1.0 at all, and why the gate is not tighter: both paths end with the SAME fixed
## full-image set_data + texture upload of the whole 512x512 image. Call it U. Then
##   region per-cell = U/576 + p        full per-cell = U/262144 + p ~= p
## and from the measured pair, U/576 ~= 1.4 us so U ~= 0.8 ms — about a fifth of the region bake. The
## consequence worth knowing: the ratio RISES as the dirty region SHRINKS, because U is spread over fewer
## cells. If a future change halved the region to ~288 cells the ratio would climb to ~1.5 with no
## regression at all. The gate is set at 3.0 to survive that, which still catches a doubling of the region
## path's real per-cell work.
##
## PROVED NON-VACUOUS, not assumed to be. Injecting the exact bug class this gate exists for — a full-grid
## _tone refresh inside rebake_region, which does hidden 262144-cell work while last_baked_cells stays 576 —
## moved the region bake 4.73 -> 13.19 ms and the ratio 1.19 -> 3.385, and the layer went RED. Every OTHER
## assertion here stayed green through that injection: the cell-count gate still saw 576 cells and the
## byte-identity check still matched, because the output was correct, only ruinously expensive. That is the
## whole point of the gate. It fires at roughly a 2.5x per-cell regression; a 1.5x one would slip through,
## and that is the honest limit of a ratio with this much headroom.
##
## WHAT THIS GATE CANNOT SEE, stated plainly so nobody trusts it further than it goes: a change that makes
## EVERY bake more expensive — more noise samples per solid cell, say — moves both numbers together and the
## ratio does not budge. That is why the absolute us/cell is printed on every run, and why SF_DIG_BUDGET_MS
## exists below for anyone who has characterised a specific machine.
const MAX_PERCELL_RATIO: float = 3.0
## Optional ABSOLUTE gate: set SF_DIG_BUDGET_MS to a millisecond ceiling for the region bake on a machine
## you have characterised (CI runner, your desktop) and it is asserted too. Unset, the cost is only printed.
## The budget lives in the environment rather than in a constant here because "how many ms is acceptable"
## is a property of the machine, and this file is read on machines nobody controls.
const BUDGET_ENV: String = "SF_DIG_BUDGET_MS"

## Frame of the first dig, and how many frames apart the digs are spaced (the renderer consumes
## terrain_dirty and takes the fast lane on a later frame, so each dig needs room to land).
const MINE_FRAME: int = 13
const MINE_STEP: int = 6

var _main: MainView
var _frames: int = 0
var _dig_cell: Vector2i
## THE DIG SITES. Each entry is the set of coarse cells mined in ONE frame, so the last entry exercises a
## MULTI-CELL dirty range (cmin != cmax) — the generalisation where the stale-ring bug actually lived and
## which a single-cell test cannot reach. Sites are spread far apart in x on purpose: each dig's rebake
## window is only ~5 coarse cells wide, so no dig can accidentally repaint (and thus repair) another's
## staleness before the comparison at the end.
var _sites: Array = []
var _max_dig_cells_seen: int = 0


func _initialize() -> void:
	Engine.max_fps = 120
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	process_frame.connect(_on_frame)


## The first SOLID cell in `col` at or below `surface_row(col) + drop`, searching down. Returns the
## starting cell unchanged if the column is hollow all the way — the caller asserts solidity, so a hollow
## column fails loudly rather than silently digging air.
func _rock(sim: FactorySim, col: int, drop: int) -> Vector2i:
	var start: int = sim.surface_row(col) + drop
	for y: int in range(start, FactorySim.GRID_ROWS):
		if sim.is_solid(Vector2i(col, y)):
			return Vector2i(col, y)
	return Vector2i(col, start)


## Two horizontally ADJACENT solid cells near `col`, for the multi-cell dirty range. Searches down for a
## row where both columns are rock; a single-cell dig cannot exercise cmin != cmax and that is exactly the
## generalisation the stale-ring bug lived in.
func _rock_pair(sim: FactorySim, col: int, drop: int) -> Array:
	var start: int = sim.surface_row(col) + drop
	for y: int in range(start, FactorySim.GRID_ROWS):
		if sim.is_solid(Vector2i(col, y)) and sim.is_solid(Vector2i(col + 1, y)):
			return [Vector2i(col, y), Vector2i(col + 1, y)]
	return [Vector2i(col, start), Vector2i(col + 1, start)]

func _on_frame() -> void:
	_frames += 1
	var sim: FactorySim = _main.sim
	if _frames == 10:
		# The boot bake has run. It used to paint the WHOLE grid in one call and this assertion said so;
		# since #17 it paints the visible rect and owes the rest to `bake_pending`, so the baseline is now
		# "much more than a dig, and still nowhere near the whole grid in one go".
		var rend: WorldRenderer = _main._renderer
		var fine: FineTerrain = rend._fine
		var whole: int = FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV
		# `opening_baked_cells`, NOT `last_baked_cells`. The first version of this assertion read the latter
		# and reported 1024 cells: by frame 10 the off-screen fill had already overwritten it with the size
		# of its most recent 4ms slice. It failed, which is the only reason the wrong number was ever seen —
		# had the range happened to fit, this layer would have been asserting on a fill slice under the name
		# "the boot bake" for as long as anyone cared to read it.
		var boot: int = fine.opening_baked_cells
		var rect: Rect2i = fine.opening_rect()
		print("  boot bake: %d of %d fine cells (%.0f%%), rect %s" % [boot, whole,
			100.0 * float(boot) / float(whole), rect])
		# THE CONTRACT, NOT A NUMBER NEAR IT. The challenge raised later, and it is right: the previous
		# floor here was `boot > MAX_DIG_CELLS`, picked because 4096 was already in scope, and a regression
		# that painted one row and stalled would sit above it and pass. What item 17 actually promises is
		# that THE GROUND AROUND THE BODY is finished before the first frame — so assert exactly that. It is
		# also the assertion that fails on the defect this change really had: an opening rect built from a
		# camera that had not yet moved onto the player, clipped to the world corner, containing nothing
		# anyone was looking at.
		var body: Vector2i = _main._cell_at(_main._player.position) * FactorySim.SUBDIV
		_check(rect.has_point(body), "the boot bake's rect %s contains the body's fine cell %s" % [rect, body])
		_check(boot < whole, "...and it is still a SPLIT, not the whole grid (%d of %d)" % [boot, whole])
		_check(fine.pending_rows() > 0, "the boot bake left rows outstanding (%d)" % fine.pending_rows())

		# ITEM 17'S OWN WORST CASE, BEFORE IT IS DRAINED AWAY. The change trades a boot freeze for a
		# possible mid-play stutter: a dig landing while off-screen fill is still outstanding. Everything
		# below this block drains the fill first — necessarily, because a not-yet-filled cell is transparent
		# in the region-baked image and painted in the reference, which this layer would report as a stale
		# ring — and that drain arranges for the one new risk never to be measured. So measure it here.
		var owed: int = fine.pending_rows()
		var probe: Vector2i = _rock(sim, maxi(FactorySim.GRID_COLS / 3, 4), 6)
		_check(sim.is_solid(probe), "the pending-fill probe site %s is solid rock" % probe)
		_main.try_mine(probe)
		rend._bake_fine_region(probe, probe)       # the exact call _process makes for a dig
		_check(fine.last_baked_cells <= MAX_DIG_CELLS,
			"a dig stays a SMALL region even with %d rows of fill outstanding (%d cells)"
			% [owed, fine.last_baked_cells])
		_check(fine.pending_rows() == owed,
			"...and the dig did not drag the outstanding fill along with it (%d rows before, %d after)"
			% [owed, fine.pending_rows()])
		# NOT ASSERTED HERE, and written down so green is not misread as coverage: that the renderer never
		# runs a dig bake and a fill slice in the SAME frame. It cannot — `_process` reaches the fill through
		# an `elif` after the dig branch — but that is a structural argument about a file this layer does not
		# read, not a measurement. The bounded thing above is the region bake's own extent.

		# EVERY ASSERTION BELOW NEEDS A WHOLE GRID, for the transparent-vs-painted reason given above.
		_check(fine.finish_pending() > 0 and fine.pending_rows() == 0,
			"finish_pending drained the outstanding fill and left the grid whole")
		# Pick dig sites at several depths and columns. The first is a deep interior solid cell, so mining it
		# dirties exactly one cell (no tree-fell / ore-collapse / surface shift) — the cleanest single-dig
		# friction measurement, and the one the cost gate is timed against.
		var mid: int = FactorySim.GRID_COLS / 2
		_dig_cell = Vector2i(mid, sim.surface_row(mid) + 10)
		var far: int = maxi(FactorySim.GRID_COLS / 5, 4)
		var near: int = mini(FactorySim.GRID_COLS - 5, mid + far)
		# Depth offsets are a STARTING point, not an answer: a fixed offset lands in a cave often enough to
		# make the layer seed-fragile, so each site searches downward for real rock from there.
		_sites = [
			[_dig_cell],                                     # deep interior, single cell — the timed one
			[_rock(sim, far, 18)],                           # deeper, a different column
			[_rock(sim, mid - far, 3)],                      # shallow — inside the surface molding band
			_rock_pair(sim, near, 12),                       # MULTI-CELL: cmin != cmax
		]
		for site: Array in _sites:
			for c: Vector2i in site:
				_check(sim.is_solid(c), "dig site %s is solid rock" % c)
		return
	# Mine each site on its own frame, spaced so the renderer takes the fast lane between them.
	for i: int in _sites.size():
		if _frames == MINE_FRAME + i * MINE_STEP:
			for c: Vector2i in _sites[i]:
				sim.mine(c)   # the real dig verb — appends the cell to sim.terrain_dirty
			return
	if _frames == MINE_FRAME + 3:
		# The renderer has consumed terrain_dirty and taken the fine fast lane for the FIRST dig by now.
		var cells: int = _main._renderer._fine.last_baked_cells
		print("  dig rebaked %d fine cells (limit %d, full grid ~%d)" % [cells, MAX_DIG_CELLS,
			FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV])
		_check(cells > 0, "a dig triggered a fine rebake")
		_check(cells <= MAX_DIG_CELLS, "a single dig rebakes a SMALL region, not the whole grid (no freeze)")
		return
	if _frames > MINE_FRAME and _frames < MINE_FRAME + _sites.size() * MINE_STEP:
		_max_dig_cells_seen = maxi(_max_dig_cells_seen, _main._renderer._fine.last_baked_cells)
		return
	if _frames == MINE_FRAME + _sites.size() * MINE_STEP + 3:
		_check(_max_dig_cells_seen <= MAX_DIG_CELLS,
			"the DEAREST dig of the set, including the multi-cell one, still rebakes a small region (%d <= %d)"
				% [_max_dig_cells_seen, MAX_DIG_CELLS])

		# CORRECTNESS: a full rebake of the SAME post-dig world must be byte-identical to the region bakes the
		# renderer has accumulated — reuse the renderer's exact palette/wall/surface authorities so only the
		# bake PATH differs, not the inputs. One reference bake covers every site: a region bake that left
		# stale solidity behind has no later chance to repair it, because the sites do not overlap.
		var r: WorldRenderer = _main._renderer
		var ref := FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, FINE_SEED)
		ref.rebake(
			func(c: Vector2i) -> bool: return r.sim.is_solid(c),
			func(fx: int, fy: int) -> bool: return r.sim.fine_is_solid(fx, fy),
			func(c: Vector2i) -> Color: return r._cell_base_color(c, r._material(r.sim.material_at(c))),
			r._wall_base_color,
			func(col: int) -> int: return r.sim.surface_row(col),
			r._cell_tone,
			r._has_wall)
		var got: PackedByteArray = r._fine.texture().get_image().get_data()
		var want: PackedByteArray = ref.texture().get_image().get_data()

		# BEFORE trusting `got == want`, establish that the comparison COULD have failed.
		#
		# This assertion spent its whole life vacuous and nobody could tell. Under --headless the dummy
		# rendering driver never uploads texture data, so get_image() hands back a BLANK surface — full
		# size, one repeated value. Two blank surfaces are byte-identical, so the check passed. And
		# --headless was the only way the harness ever ran this layer, because it was registered with `add`
		# rather than `add_gl`. The result: the guard reported PASS while the very bug it exists to catch
		# was live on main. Measured, not inferred — same commit, same layer: 115 distinct sampled values
		# and a real FAIL with a window, 1 distinct value and a PASS headless.
		if DisplayServer.get_name() == "headless":
			print("  SKIP: byte-identity NOT verified — no rendering surface. The headless driver returns a")
			print("        blank image, so this comparison cannot fail and asserting it would be a lie.")
			print("        Extent and cost below still assert for real. Run with a window to verify it.")
		else:
			var want_bytes: int = FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS \
				* FactorySim.SUBDIV * 4
			_check(got.size() == want_bytes and want.size() == want_bytes,
				"both textures read back at full size (got %d, ref %d, expected %d)"
					% [got.size(), want.size(), want_bytes])
			# Uniformity is how this goes vacuous even at full size. Real molded terrain is never one value.
			var distinct: Dictionary = {}
			for i: int in range(0, got.size(), 997 * 4):   # coprime stride — samples the whole image cheaply
				distinct[got[i]] = true
			_check(distinct.size() > 4, "the baked texture carries real variation, so the comparison below "
				+ "could actually fail (%d distinct sampled values)" % distinct.size())
			_check(got == want,
				"region bake is byte-identical to a full bake of the same world (margin is safe)")

		_cost(r, ref)

		if _failures == 0:
			print("check_dig_hitch: PASS")
			quit(0)
		else:
			printerr("check_dig_hitch: %d FAILURE(S)" % _failures)
			quit(1)


## THE COST GATE. `ref` has already been fully baked once by the caller, so its caches are sized and warm —
## which is the state the game is actually in when it bakes. Time a full bake and a region bake back to back
## on that same warm object: same machine, same process, same data, same moment. Only the PATH differs, so
## the ratio between them is a property of the code and not of the hardware it ran on.
func _cost(r: WorldRenderer, ref: FineTerrain) -> void:
	var solid_at := func(c: Vector2i) -> bool: return r.sim.is_solid(c)
	var fine_at := func(fx: int, fy: int) -> bool: return r.sim.fine_is_solid(fx, fy)
	var mat_at := func(c: Vector2i) -> Color: return r._cell_base_color(c, r._material(r.sim.material_at(c)))
	var surf_at := func(col: int) -> int: return r.sim.surface_row(col)

	var full_us: int = 1 << 62
	var full_cells: int = 0
	for i: int in TIME_SAMPLES:
		var t0: int = Time.get_ticks_usec()
		ref.rebake(solid_at, fine_at, mat_at, r._wall_base_color, surf_at, r._cell_tone, r._has_wall)
		full_us = mini(full_us, Time.get_ticks_usec() - t0)
		full_cells = ref.last_baked_cells

	# THE SAME FULL BAKE WITH THE FINE GRID HANDED OVER WHOLE — the boot/load path the game actually takes.
	# The loop above times the Callable path, which is what check_texture uses (it bakes a synthetic world
	# with no sim behind it) and what this file measured for its whole life. Timing only that was how a
	# 262144-dispatch loop stayed the dominant cost of every boot without ever appearing in a number.
	var bulk: PackedByteArray = r.sim.fine_solid_bytes()
	_check(bulk.size() == FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV,
		"the sim handed over a full fine grid to time the bulk path against (%d bytes)" % bulk.size())
	var bulk_us: int = 1 << 62
	for i: int in TIME_SAMPLES:
		var t0: int = Time.get_ticks_usec()
		ref.rebake(solid_at, fine_at, mat_at, r._wall_base_color, surf_at, r._cell_tone, r._has_wall, bulk)
		bulk_us = mini(bulk_us, Time.get_ticks_usec() - t0)

	var region_us: int = 1 << 62
	var region_cells: int = 0
	for i: int in TIME_SAMPLES:
		var t0: int = Time.get_ticks_usec()
		ref.rebake_region(_dig_cell, _dig_cell, solid_at, fine_at, mat_at, r._wall_base_color, surf_at,
			r._cell_tone, r._has_wall)
		region_us = mini(region_us, Time.get_ticks_usec() - t0)
		region_cells = ref.last_baked_cells

	# Always PRINT the cost, whether or not it is asserted, so drift is visible to a human reading a green
	# run and so the derivation above can be re-checked on any machine without editing anything.
	var full_pc: float = float(full_us) / float(maxi(full_cells, 1))
	var region_pc: float = float(region_us) / float(maxi(region_cells, 1))
	var ratio: float = region_pc / maxf(full_pc, 0.001)
	print("  COST full bake %.2f ms / %d cells (%.3f us/cell)" % [full_us / 1000.0, full_cells, full_pc])
	print("  COST full bake, BULK fine grid %.2f ms (%.3f us/cell) — %.2fx the per-cell Callable path"
		% [bulk_us / 1000.0, float(bulk_us) / float(maxi(full_cells, 1)),
			float(full_us) / maxf(float(bulk_us), 1.0)])
	_check(bulk_us <= full_us,
		"handing the fine grid over whole is not SLOWER than reading it a cell at a time (%.2f vs %.2f ms)"
			% [bulk_us / 1000.0, full_us / 1000.0])
	print("  COST dig region %.2f ms / %d cells (%.3f us/cell)" % [region_us / 1000.0, region_cells, region_pc])
	print("  COST per-cell region/full = %.3f (gate %.2f), best of %d each; total ratio %.4f"
		% [ratio, MAX_PERCELL_RATIO, TIME_SAMPLES, float(region_us) / float(maxi(full_us, 1))])

	# BOTH SIDES OF THE RATIO HAVE TO HAVE HAPPENED. `full_cells > region_cells` is satisfied by
	# `region_cells == 0`, and a region bake that painted nothing also costs almost no time — so `region_pc`
	# (which divides by `maxi(region_cells, 1)`) comes out near zero, `ratio` comes out near zero, and the
	# claim "the fast lane is fast in TIME" passes on a lane that did no work at all. That is the strongest
	# possible pass for the emptiest possible measurement, and the `maxi(…, 1)` divide-guard is what converts
	# the impossible case into a flattering one instead of a loud one.
	# NON-VACUITY — an empty region bake costs no time, so the ratio flatters it.
	_check(region_cells > 0 and full_cells > region_cells,
		"the timed pair really is full-grid vs region, and the region baked something (%d vs %d cells)"
			% [full_cells, region_cells])
	_check(ratio <= MAX_PERCELL_RATIO,
		"a dig's bake costs no more PER CELL than a full bake — the fast lane is fast in TIME, not just "
			+ "small in extent (%.3f <= %.2f)" % [ratio, MAX_PERCELL_RATIO])

	var budget: String = OS.get_environment(BUDGET_ENV)
	if budget.is_empty():
		print("  (absolute ms budget not asserted: %s unset — the per-cell ratio is what CI enforces)"
			% BUDGET_ENV)
	else:
		var ms: float = float(budget)
		_check(region_us / 1000.0 <= ms, "dig region within the %s=%s budget (%.2f <= %.2f ms)"
			% [BUDGET_ENV, budget, region_us / 1000.0, ms])
