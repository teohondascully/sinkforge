extends SceneTree

## WHERE DOES THE FRAME GO?
##
## check_frametime says a frame costs 39.59ms during a dig against an 8.33ms budget. It does not say WHY,
## and the project has never had a tool that does — `_crystal_seams_cached()` carries a comment reading
## "the profiler measures it in isolation", and there is no profiler and never was. So every optimisation
## decision so far has been taken against a total, which is how you end up tuning the wrong thing
## confidently.
##
## This measures the two costs the dig path pays every frame, ON A REAL WORLD, AT DEPTH:
##
##   _exposed_ore_cells()  scans sim.deposits — EVERY deposit in the world, not the ones in view — and
##                         view-culls each one. Its cost is a property of the world, not of the screen.
##   _crystal_seams()      floods those survivors into clusters with an inner `for other in cells` rescan
##                         per frontier pop. That is O(n^2) in exposed ore, and a dig EXPOSES ore, so n
##                         climbs exactly where the budget already fails.
##
## and one structural fact that decides whether the cache in front of them does anything at all:
##
##   THE CACHE.  _crystal_seams_cached() refloods when `view != _crystal_seams_view` — exact float Rect2
##               equality. If the camera moves at all, that is a miss. Standing still it is a hit. So the
##               cache may be protecting IDLE and doing nothing whatsoever for RUN, DIG and SWING, which
##               are three of the four phases that have to make budget. This counts the misses instead of
##               reasoning about them.
##
## WHAT THIS IS NOT: it is not a pass/fail layer and it asserts nothing. It prints numbers to attribute a
## budget failure. Absolute milliseconds are only worth quoting from an otherwise idle machine — the same
## caveat add_excl exists for — and the RATIOS and the COUNTS below survive contention regardless, which
## is deliberate: the load-bearing outputs of this tool are `n` and `misses`, not the ms.
##
##   godot --path . --script res://tools/profile_frame.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 8
const SKIP: int = 42

## Depth samples. The dig starts at the surface where there is almost no ore and descends into it, so a
## single number would average away the only interesting part of the curve.
const PROBE_FRAMES: int = 60      ## frames of digging between probes
const PROBES: int = 5             ## how many depths to sample
const REPEATS: int = 12           ## calls per probe, medianed — one call is noise

## How far below the body to look for real rock. This tool originally aimed each dig blindly at the cell
## one row down, which is the defect found on a later pass in check_frametime's DIG phase (8d72dae): on
## frames where that cell is already open the dig lands on air, the frame costs nothing, and the profile
## prices a body standing still. A profiler with that bug is worse than none — it reports its cheapest
## numbers exactly when it is measuring the least, so the wrong thing looks fast. Every table below
## therefore also prints the mines that actually LANDED.
const DIG_REACH: int = 6

var _main: MainView = null


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("profile_frame: SKIP — no display; the dummy renderer draws nothing, so its frames are free")
		quit(SKIP)
		return
	await _run()
	quit(0)


func _run() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	MainView.dev_start = false
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame
	await RenderingServer.frame_post_draw

	var player: Player = _main._player
	player.auto_input = false
	var renderer: WorldRenderer = _main._renderer

	print("== where does the frame go ==")
	print("  world: %d deposits total (this is what _exposed_ore_cells scans, every call)"
		% _main.sim.deposits.size())
	print("")
	print("  depth  mines   n(exposed)   exposed_ore_cells   crystal_seams   seams   frame   seams as %% of frame")

	for p: int in PROBES:
		# Dig down PROBE_FRAMES cells, timing the real frames as we go — the same drive check_frametime uses.
		var frames: PackedFloat32Array = PackedFloat32Array()
		var mined: int = 0
		var last: int = Time.get_ticks_usec()
		for i: int in PROBE_FRAMES:
			if _main.try_mine(_dig_target(player)):
				mined += 1
			player.input_dir = 0.0
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			frames.append(float(now - last) / 1000.0)
			last = now
		frames.sort()

		# ...then price the two suspects on the world as it now stands, with the body held still so the
		# measurement is not itself racing the dig it just did.
		var cells: Array[Vector2i] = renderer._exposed_ore_cells()
		var t_cells: float = _median_ms(renderer, &"cells", REPEATS)
		var t_seams: float = _median_ms(renderer, &"seams", REPEATS)
		var seams: Array[Dictionary] = renderer._crystal_seams()
		var frame: float = _pct(frames, 0.50)
		print("  %5d  %5d   %10d   %17.3f   %13.3f   %5d   %5.2f   %18.1f%%"
			% [_main._cell_at(player.position).y, mined, cells.size(), t_cells, t_seams, seams.size(), frame,
				100.0 * (t_cells + t_seams) / maxf(frame, 0.001)])
		if mined == 0:
			printerr("      ^ THIS ROW IS VOID: the phase mined nothing, so its frame time is a body standing still")

	# --- the cache: is it ever hit while the camera moves? ---
	# Counted, not argued. A view-rect that differs by a float between consecutive frames is a miss, and a
	# miss means the whole flood above runs again.
	print("")
	var misses: int = 0
	var prev: Rect2 = renderer._view_world_rect()
	for i: int in 60:
		_main.try_mine(_dig_target(player))
		await RenderingServer.frame_post_draw
		var now_view: Rect2 = renderer._view_world_rect()
		if now_view != prev:
			misses += 1
		prev = now_view
	print("  view-rect cache: %d/60 frames of digging saw a MOVED view (each one refloods)" % misses)

	# And the control — standing perfectly still, which is the only case the cache was ever measured in.
	player.input_dir = 0.0
	for _i: int in 20:
		await RenderingServer.frame_post_draw
	var still: int = 0
	prev = renderer._view_world_rect()
	for i: int in 60:
		await RenderingServer.frame_post_draw
		var now_view: Rect2 = renderer._view_world_rect()
		if now_view != prev:
			still += 1
		prev = now_view
	print("  view-rect cache: %d/60 frames STANDING STILL saw a moved view" % still)

	# --- THE COST OF ONE DIG, TIMED DIRECTLY ---
	#
	# Wall-clock frame deltas are the wrong instrument on this machine (see the pacing report below): the
	# panel refreshes every 8.333ms, which is also the budget, so a frame time tells you what the display
	# did and not what the game did. A usec timer wrapped around the work itself does not care about
	# presentation at all.
	#
	# So this does the renderer's own job under a stopwatch. `try_mine` leaves its edits in
	# `sim.terrain_dirty`; we take that list, CLEAR it so _process does not also bake it, and then run the
	# exact three passes _process would have run — the chunk repaint, the fine-region patch, and the veil —
	# timing each. Same work, same order, once, measured.
	print("")
	print("  --- the cost of ONE dig, timed directly (immune to presentation pacing) ---")
	# The depth probes above leave the body at the bottom of the shaft it just dug, with nothing solid
	# within reach below it. Measuring here without moving first prices forty failed swings at air — which
	# is precisely the fixture defect that voided every DIG number this project has ever quoted, so the
	# body gets planted on fresh ground and the guard at the end stays in regardless.
	var fresh_col: int = _main._cell_at(player.position).x + 40
	var fresh_row: int = _main.sim.surface_row(fresh_col)
	player.position = Vector2((float(fresh_col) + 0.5) * float(WorldRenderer.CELL),
		(float(fresh_row) - 3.0) * float(WorldRenderer.CELL))
	for _i: int in 30:
		await physics_frame
	# ...and then DOWN, before measuring anything. Planting on the surface and pricing a dig there was a
	# confound of my own making: the DIG phase this is meant to explain runs at row ~77, and the surface is
	# the cheap case — thin rock, no ore, few lights, a veil that has barely anything to cut. A per-dig cost
	# measured in daylight does not describe the frame that is failing the budget.
	for _i: int in 70:
		_main.try_mine(_dig_target(player))
		await RenderingServer.frame_post_draw
	print("    planted on fresh ground at column %d (surface row %d), then dug down to row %d"
		% [fresh_col, fresh_row, _main._cell_at(player.position).y])
	var mine_us := PackedFloat32Array()
	var chunk_us := PackedFloat32Array()
	var fine_us := PackedFloat32Array()
	var veil_us := PackedFloat32Array()
	var landed: int = 0
	var last_cell := Vector2i.ZERO
	for _i: int in 40:
		var target: Vector2i = _dig_target(player)
		if not _main.sim.is_solid(target):
			await RenderingServer.frame_post_draw
			continue
		var t0: int = Time.get_ticks_usec()
		var hit: bool = _main.try_mine(target)
		mine_us.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if not hit:
			await RenderingServer.frame_post_draw
			continue
		landed += 1
		last_cell = target
		# Take the renderer's work away from it and do it here, under the clock.
		var cells_dirty: Array[Vector2i] = _main.sim.terrain_dirty.duplicate()
		_main.sim.terrain_dirty.clear()
		var dirty: Dictionary = {}
		var rmin := Vector2i(1 << 30, 1 << 30)
		var rmax := Vector2i(-(1 << 30), -(1 << 30))
		for cell: Vector2i in cells_dirty:
			rmin.x = mini(rmin.x, cell.x); rmin.y = mini(rmin.y, cell.y)
			rmax.x = maxi(rmax.x, cell.x); rmax.y = maxi(rmax.y, cell.y)
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var idx: int = renderer._chunk_index(cell + Vector2i(dx, dy))
					if idx >= 0:
						dirty[idx] = true
		t0 = Time.get_ticks_usec()
		renderer._bake_terrain_chunks(dirty)
		chunk_us.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		t0 = Time.get_ticks_usec()
		renderer._bake_fine_region(rmin, rmax)
		var fine_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		fine_us.append(fine_ms)
		# Per dig, not per run: `_shape` and `_calve` can take cells that are not adjacent, and the region
		# is the BOUNDING BOX of everything the blow dirtied. One blow that calves a ledge sideways spans a
		# far larger box than one that takes a single cell, so a p50 over ten digs can describe no dig that
		# actually happened. Printed as a table for that reason.
		print("        dig %2d: %2d cells dirty, box %dx%d coarse -> %d fine cells painted, %6.3f ms"
			% [landed, cells_dirty.size(), rmax.x - rmin.x + 1, rmax.y - rmin.y + 1,
				(renderer._fine as FineTerrain).last_baked_cells, fine_ms])
		t0 = Time.get_ticks_usec()
		renderer._update_veil()
		veil_us.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		await RenderingServer.frame_post_draw
	mine_us.sort(); chunk_us.sort(); fine_us.sort(); veil_us.sort()
	print("    %d digs landed. Per dig, p50 / p95:" % landed)
	print("      try_mine (sim + fx)      %6.3f / %6.3f ms" % [_pct(mine_us, 0.50), _pct(mine_us, 0.95)])
	print("      _bake_terrain_chunks     %6.3f / %6.3f ms" % [_pct(chunk_us, 0.50), _pct(chunk_us, 0.95)])
	print("      _bake_fine_region        %6.3f / %6.3f ms" % [_pct(fine_us, 0.50), _pct(fine_us, 0.95)])
	print("      _update_veil             %6.3f / %6.3f ms" % [_pct(veil_us, 0.50), _pct(veil_us, 0.95)])
	print("      -> one dig costs %6.3f ms of work against an %.2fms frame budget"
		% [_pct(mine_us, 0.50) + _pct(chunk_us, 0.50) + _pct(fine_us, 0.50) + _pct(veil_us, 0.50),
			1000.0 / 120.0])
	if landed == 0:
		printerr("      ^ VOID: nothing was mined, so the numbers above are not about digging")

	# WHERE INSIDE THE REGION BAKE?
	#
	# `rebake_region` exists to paint only the cells a dig touched — and `last_baked_cells` says it does.
	# But it finishes by handing the WHOLE buffer to set_data and the whole image to the texture, so the
	# dirty-region fast lane covers the paint and not the upload. These two calls are timed here exactly as
	# rebake_region makes them, with no edit pending, so whatever they cost is what they cost per dig no
	# matter how few cells changed.
	var ft: FineTerrain = renderer._fine
	if ft != null:
		var set_ms := PackedFloat32Array()
		var up_ms := PackedFloat32Array()
		for _i: int in 12:
			var t0: int = Time.get_ticks_usec()
			ft._img.set_data(ft._fcols, ft._frows, false, Image.FORMAT_RGBA8, ft._data)
			set_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
			t0 = Time.get_ticks_usec()
			ft._tex.update(ft._img)
			up_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		set_ms.sort(); up_ms.sort()
		print("    fine texture is %d x %d = %.1f MB; last region painted %d fine cells"
			% [ft._fcols, ft._frows, float(ft._data.size()) / 1048576.0, ft.last_baked_cells])
		print("      _img.set_data (whole buffer)  %6.3f ms" % _pct(set_ms, 0.50))
		print("      _tex.update   (whole texture) %6.3f ms" % _pct(up_ms, 0.50))
		print("      -> %.3f ms of the %.3f ms region bake is re-uploading unchanged texels"
			% [_pct(set_ms, 0.50) + _pct(up_ms, 0.50), _pct(fine_us, 0.50)])

		# So it is the PAINT, not the upload. _paint_fine runs once per fine cell in the dilated region and
		# costs ~4.7us each, which is a great deal for one texel. Its most suspicious ingredient is two
		# FastNoiseLite lookups for the rock-hue pole — and those are PURE FUNCTIONS OF (fx, fy), exactly
		# like the `_tone` field the same file already caches and deliberately never refreshes on a dig.
		# If they dominate, they are cacheable by the argument the file has already made once. Timed here
		# over the same 1024-cell region a dig actually repaints.
		var cells_painted: int = maxi(ft.last_baked_cells, 1)
		var t0: int = Time.get_ticks_usec()
		for i: int in cells_painted:
			var _hx: float = ft._huex.get_noise_2d(float(i % 32), float(i / 32))
			var _hy: float = ft._huey.get_noise_2d(float(i % 32), float(i / 32))
		var noise_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		print("      the 2 hue-noise lookups alone, over %d cells: %6.3f ms (%.0f%% of the region bake)"
			% [cells_painted, noise_ms, 100.0 * noise_ms / maxf(_pct(fine_us, 0.50), 0.001)])

		# Not the upload, not the noise. rebake_region has exactly two loops big enough to matter, so both
		# get timed rather than a third guess: the per-fine-cell solidity refresh, which reaches back into
		# the sim through a Callable for every cell, and the paint itself over the margin-dilated region.
		# THE EXACT TEXELS THE LAST DIG REPAINTED, and not a same-sized rectangle somewhere else. Timing
		# (0,0)-(23,23) first put _paint_fine at 5% of the bake, which was wrong by nearly 20x: that corner
		# of the world is SKY, and _paint_fine early-returns on air and on the surface cap. A micro-benchmark
		# that runs the cheap branch of the function it is pricing reports the function as cheap.
		var band: int = FactorySim.FineTerrain.SYNC_BAND
		var sub: int = FineTerrain.SUBDIV
		var mar: int = FineTerrain.REGION_MARGIN
		var fx0: int = maxi((last_cell.x - band) * sub - mar, 0)
		var fy0: int = maxi((last_cell.y - band) * sub - mar, 0)
		var fx1: int = mini((last_cell.x + 1 + band) * sub - 1 + mar, ft._fcols - 1)
		var fy1: int = mini((last_cell.y + 1 + band) * sub - 1 + mar, ft._frows - 1)
		var n_rect: int = (fx1 - fx0 + 1) * (fy1 - fy0 + 1)
		t0 = Time.get_ticks_usec()
		for fy: int in range(fy0, fy1 + 1):
			for fx: int in range(fx0, fx1 + 1):
				ft._paint_fine(fx, fy)
		var paint_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		for fy: int in range(fy0, fy1 + 1):
			for fx: int in range(fx0, fx1 + 1):
				var _s: bool = _main.sim.fine_is_solid(fx, fy)
		var solid_direct_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		print("      over the REAL dug rect (%d,%d)-(%d,%d), %d texels:" % [fx0, fy0, fx1, fy1, n_rect])
		print("        _paint_fine                %6.3f ms  (%.0f%% of the region bake, %.2f us each)"
			% [paint_ms, 100.0 * paint_ms / maxf(_pct(fine_us, 0.50), 0.001),
				paint_ms * 1000.0 / float(maxi(n_rect, 1))])
		print("        fine_is_solid              %6.3f ms" % solid_direct_ms)

		# NO SINGLE TERM DOMINATES — stubbing six of the nine noise fields to a constant moved 7.25us/texel
		# to 6.40, which is 12%. So the next candidate is not a term at all but the SHAPE of the function:
		# _paint_fine makes roughly twenty helper calls per texel, and a GDScript call is expensive relative
		# to the arithmetic inside it. If these few add up to a large fraction, the fix is inlining, which
		# is mechanical and can be held byte-identical. If they do not, the cost is spread and only the GPU
		# will fix it. Measured over the same real dug rect.
		var helpers: Array = [
			["_air_weight", func(fx: int, fy: int) -> void: ft._air_weight(ft._fine_solid, fx, fy)],
			["_top_air_distance", func(fx: int, fy: int) -> void: ft._top_air_distance(ft._fine_solid, fx, fy)],
			["_bottom_air_distance", func(fx: int, fy: int) -> void: ft._bottom_air_distance(ft._fine_solid, fx, fy)],
			["_tone_at_fine", func(fx: int, fy: int) -> void: ft._tone_at_fine(fx, fy)],
			["_sky_form", func(fx: int, fy: int) -> void: ft._sky_form(fx, fy)],
			["_moss_life", func(_fx: int, fy: int) -> void: ft._moss_life(fy)],
		]
		var helper_total: float = 0.0
		for h: Array in helpers:
			var fn: Callable = h[1]
			t0 = Time.get_ticks_usec()
			for fy: int in range(fy0, fy1 + 1):
				for fx: int in range(fx0, fx1 + 1):
					fn.call(fx, fy)
			var hm: float = float(Time.get_ticks_usec() - t0) / 1000.0
			helper_total += hm
			print("          %-22s %6.3f ms" % [h[0], hm])
		print("          (a bare Callable loop over the same rect costs about %6.3f ms of the above)"
			% solid_direct_ms)
		print("        -> %d helpers total %6.3f ms of the %6.3f ms paint"
			% [helpers.size(), helper_total, paint_ms])

	# --- THE STILL FRAME ---
	#
	# WHAT THIS SECTION USED TO CLAIM, AND WHY IT WAS WRONG. It said: a frame that mines NOTHING still costs
	# ~8.4ms against a budget of 8.33, so the game is at 120fps and no better even standing still, so the dig
	# path is the smaller half of the problem. That reading was refuted by the drop-rate instrument built
	# session built afterwards — an idle frame misses its deadline 0-6% of the time, and a digging frame
	# misses 63-68%. The 8.4ms was the PANEL handing us frames at 120Hz, not the game filling them. See the
	# pacing detection immediately below, which is the part of this file that was right.
	#
	# The lesson is kept here rather than deleted, because the trap is still live: on this display "makes
	# budget" and "is paced" produce the same p50, so a wall-clock number can NEVER distinguish a fast frame
	# from a throttled one. Only missed deadlines can.
	#
	# What survives is the split: when a frame IS slow, the first question is WHICH MACHINE is busy. The
	# viewport reports its render cost split into the CPU that builds the command stream and the GPU that
	# executes it. Those are two different problems with two different fixes, and guessing which one you
	# have is how a week gets spent making the wrong one faster.
	print("")
	print("  --- the still frame: which machine is actually busy ---")
	var vp_rid: RID = get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	player.input_dir = 0.0
	for _i: int in 30:
		await RenderingServer.frame_post_draw          # let the measurement settle before reading it

	var cpu := PackedFloat32Array()
	var gpu := PackedFloat32Array()
	var whole := PackedFloat32Array()
	var t_last: int = Time.get_ticks_usec()
	for _i: int in 120:
		await RenderingServer.frame_post_draw
		var t_now: int = Time.get_ticks_usec()
		whole.append(float(t_now - t_last) / 1000.0)
		t_last = t_now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
	cpu.sort(); gpu.sort(); whole.sort()
	print("    whole frame        p50 %5.2fms   p95 %5.2fms" % [_pct(whole, 0.50), _pct(whole, 0.95)])
	print("    render CPU         p50 %5.2fms   p95 %5.2fms   (building the command stream)"
		% [_pct(cpu, 0.50), _pct(cpu, 0.95)])
	# A GPU timer that reads exactly zero is an unimplemented timer, not an idle GPU. Metal does not fill
	# these timestamp queries in this build, and printing "0.00ms (executing it)" invites the reader to
	# conclude the GPU is free — which is a claim nobody measured. Say which it is.
	if _pct(gpu, 0.50) <= 0.0 and _pct(gpu, 0.95) <= 0.0:
		print("    render GPU         NOT MEASURED — this backend does not fill the timestamp query")
	else:
		print("    render GPU         p50 %5.2fms   p95 %5.2fms   (executing it)"
			% [_pct(gpu, 0.50), _pct(gpu, 0.95)])
	# THE SCRIPT ROW IS GONE ON PURPOSE. It read `Performance.TIME_PROCESS` and reported p50 21.89ms inside
	# frames whose whole duration was 8.4ms — our own per-frame code taking two and a half times the frame
	# it runs in. That is not a slow number, it is an impossible one, and I quoted it in a conclusion before
	# noticing. I do not know what that monitor is counting here; until I do, it does not belong in a table
	# people make decisions from. An unexplained number is worse than a missing one, because it gets used.
	print("    draw calls %d · objects %d · vertices %d"
		% [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])

	# IS THIS THE GAME OR IS IT THE PANEL?
	#
	# This machine's display refreshes at 120Hz, so its frame interval is 8.333ms — which is EXACTLY the
	# 120fps budget. That coincidence is poison for the measurement: "the game makes budget" and "the game
	# is pinned to the panel and its real cost is invisible" produce the same p95, and only the SHAPE of
	# the distribution tells them apart. Paced frames pile onto multiples of the interval; frames doing
	# real work spread out. Requesting VSYNC_DISABLED is not proof it took, either — the report below is.
	var interval: float = 1000.0 / maxf(DisplayServer.screen_get_refresh_rate(), 1.0)
	var pinned: int = 0
	for s: float in whole:
		var off: float = fmod(s, interval)
		if minf(off, interval - off) < 0.2:
			pinned += 1
	print("    refresh %.2fHz (interval %.3fms) · vsync mode %d · %d/%d still frames sit ON a multiple"
		% [DisplayServer.screen_get_refresh_rate(), interval,
			DisplayServer.window_get_vsync_mode(), pinned, whole.size()])
	var deciles: String = ""
	for d: int in range(1, 10):
		deciles += "%5.2f " % _pct(whole, float(d) / 10.0)
	print("    still-frame deciles: %s" % deciles)

	_main.queue_free()
	await physics_frame


## The first solid cell at or below the body — the same search check_frametime uses, and for the same
## reason: aiming one row down blindly makes the measurement depend on the body's sub-pixel position.
func _dig_target(player: Player) -> Vector2i:
	var here: Vector2i = _main._cell_at(player.position)
	for dy: int in range(1, DIG_REACH + 1):
		var c: Vector2i = here + Vector2i(0, dy)
		if _main.sim.is_solid(c):
			return c
	return here + Vector2i(0, 1)


## Median of REPEATS calls, in milliseconds. Median and not mean: one call landing next to a GC pause or a
## neighbouring process should not become the number anyone quotes.
func _median_ms(renderer: WorldRenderer, what: StringName, n: int) -> float:
	var ms := PackedFloat32Array()
	for _i: int in n:
		var t0: int = Time.get_ticks_usec()
		if what == &"cells":
			var _c: Array[Vector2i] = renderer._exposed_ore_cells()
		else:
			var _s: Array[Dictionary] = renderer._crystal_seams()
		ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	ms.sort()
	return _pct(ms, 0.50)


func _pct(ms: PackedFloat32Array, q: float) -> float:
	if ms.is_empty():
		return 0.0
	return ms[clampi(int(float(ms.size()) * q), 0, ms.size() - 1)]
