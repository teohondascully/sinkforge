extends SceneTree

## NOTHING MAY HITCH — and on named hardware, it has to run at 120.
##
## THE NAME WAS A LIE FOR THIS LAYER'S WHOLE LIFE. It was registered in the runner as `check_frametime
## (120fps)`, it printed "the game does not hold 120fps" when it failed, and it never once compared
## anything to 8.33ms. What it asserts — and the reasons are below, and they are good ones — is a RATIO:
## a busy frame's p95 against a quiet frame's median. That ratio is the portable, honest property, and it
## is kept exactly as it was. But a ratio cannot tell you the frame rate, so the claim moved to where it
## can be true: an absolute 8.33ms budget that runs ONLY when SF_PERF_HOST names the machine (see
## FRAME_BUDGET_MS). Everywhere else this layer says what it measured and asserts only the ratio.
##
## Forty-nine harness layers judged what the game DOES and not one of them judged how fast it does it, which
## is a strange gap for a 2D game whose whole pitch is movement. A swing that measures beautifully and hitches
## twice on the way down is not a good swing, and no layer here could tell the difference.
##
## WALL-CLOCK, not `Performance.TIME_PROCESS`. The engine's process timer counts script time and misses the
## command buffer, the submit and everything the driver does — and on this renderer that is most of a frame.
## Ticks around `frame_post_draw` count what a player waits for.
##
## FOUR PHASES, because the costs are not the same shape and a single average hides the one that matters:
##   IDLE  — standing still on the surface: the floor cost of drawing the world at all
##   RUN   — moving, so chunks stream, the veil chases and the speed streaks draw
##   DIG   — mining, which triggers the fine-terrain REGION rebake; the known hot path (#102)
##   SWING — on the rope at speed: particles, streaks, the rope, the fastest camera in the game
##
## THE BAR IS RELATIVE, and that took a round to get right. Two things make an absolute millisecond budget
## unmeasurable here:
##   * VSYNC. When it is on, every frame that fits inside the refresh interval measures as exactly the
##     refresh interval. A game with 4ms of headroom and one with 0.1ms both report a perfect 8.33, and
##     the number says nothing. This is why the absolute budget refuses to assert on a paced run.
##     MEASURED, and the older claim here was wrong: this file used to say "asking for it off does not
##     reliably get it off on macOS", and a boot-time override.cfg fight was planned around that
##     sentence. On macOS arm64 (M4 Pro, Godot 4.6.2) the VSYNC_DISABLED call in _run() DOES take effect —
##     proven by samples arriving FASTER than the panel can present, which vsync makes impossible. See
##     _fastest. Treat the claim as machine-specific and re-derive it from the samples, not from prose.
##   * THE MACHINE. A background reindex can put whole SECONDS into a frame that the game had no part in.
##     A layer that fails when Spotlight is busy is a layer people learn to ignore.
## Both move the quiet frames and the busy frames together, so the RATIO between them survives what the
## absolute numbers do not: a dig may cost a few times a quiet frame, never twenty times one. That is also
## the honest statement of the property — "mining must not hitch" — rather than a number copied off a spec
## sheet. The absolutes are still printed, because when the machine IS quiet they are what you want to read.
##
## PERCENTILES, not the mean. A hitch is one frame in a hundred and a mean of two hundred cannot see it.
## p95 carries the gate rather than p99 or max, because under background load the top one percent belongs
## to the operating system and gating on it would measure the machine instead of the game.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 90                 ## frames to let worldgen, the first full bake and the caches land
const SAMPLE: int = 200                ## frames measured per phase

## A quiet frame — the median of the IDLE phase — is the unit everything else is measured in. With vsync on
## it is the refresh interval; with vsync off it is the game's real floor cost. Either way it is what the
## machine can do when the game is asking for nothing.
##
## HOW MUCH A DIG MAY COST, as a multiple of that quiet frame. Set from measurement with room to spare, and
## its job is to stop the hitch coming back: before #S14 a dig cost 13.6x a quiet frame (114ms against 8.4)
## and the game visibly stalled once a second while mining. It now costs 3.7x. The bar is 6x — comfortably
## clear of where the code is, nowhere near where it was.
const DIG_HITCH_RATIO: float = 6.0
## Movement must not hitch AT ALL: nothing about running or swinging changes the world, so there is no bake
## to pay for and no excuse for a slow frame.
const MOVE_HITCH_RATIO: float = 2.0

## THE ABSOLUTE BUDGET, and the one place in this project where 120fps is an assertion rather than an
## ambition. 120 frames per second is 8.33ms per frame, so every measured phase's p95 must fit inside it.
##
## IT RUNS ONLY WHERE THE NUMBER MEANS SOMETHING. `SF_PERF_HOST` names the machine — set it to whatever
## identifies the box you are calibrating on, e.g. `SF_PERF_HOST=m4max-16in`. Naming it is an assertion by
## whoever set it that this is controlled hardware and vsync is genuinely off. On anything else the budget
## is not merely noisy, it is meaningless (see VSYNC above: a vsync-pinned run reports the refresh interval
## no matter how fast the game is), and a threshold that fails for reasons the game did not cause is a
## threshold someone deletes within a month. So: unset means the absolute is measured, printed, and NOT
## asserted, which is stated in the output so no one reads the pass as a frame-rate claim.
const FRAME_BUDGET_MS: float = 1000.0 / 120.0

## How close the quiet frame has to sit to the display's refresh interval before we call the run
## vsync-pinned and refuse to assert an absolute. Frames landing on the refresh within a fifth of a
## millisecond are being paced by the display, not by the game.
const VSYNC_PINNED_MS: float = 0.2

## Fraction of samples sitting on a refresh multiple above which the run LOOKS vsync-paced. Measured, not
## guessed: forcing VSYNC_ENABLED on this machine drives every phase p95 to ~16.5ms — two refresh intervals,
## uniform across four phases that otherwise differ by 2x — while a genuine VSYNC_DISABLED run spreads them
## 13.6 / 15.6 / 16.4 / 32.6. Clustering is the signal; individual frames are not. A handful of samples DO
## come in under the interval even with vsync requested on, which is why "was any frame faster than the
## panel" looked decisive and is not.
const PACED_FRACTION: float = 0.6

## The runner's reserved "I did not run" exit code (tools/run_harness.sh, SKIP_CODE). This used to be 0,
## which is how a layer that measured nothing got counted in "ALL 61 HARNESS LAYERS PASS".
const SKIP: int = 42

var _main: MainView = null
## Non-empty = controlled hardware, named by whoever set it, and the absolute budget applies.
var _perf_host: String = OS.get_environment("SF_PERF_HOST")


func _initialize() -> void:
	# Exit 42 AND a reason line: the runner requires both before it will call this a skip rather than a
	# failure. Twelve seconds with a display, one second without — that gap is what made the old quit(0)
	# a lie every time CI ran.
	if DisplayServer.get_name() == "headless":
		print("check_frametime: SKIP — no display; the dummy renderer draws nothing, so its frames are free")
		quit(SKIP)
		return
	_run()


func _run() -> void:
	# Uncap everything. A capped run measures the cap.
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

	var claim: String = "the hitch ratio only — no absolute budget on unnamed hardware"
	if _perf_host != "":
		claim = "hitch ratio AND the %.2fms budget, on SF_PERF_HOST=%s" % [FRAME_BUDGET_MS, _perf_host]
	print("== nothing may hitch ==  (%d frames per phase, %s, asserting %s)"
		% [SAMPLE, DisplayServer.get_name(), claim])

	# IDLE first and ungated by the ratio: it defines the quiet frame the others are judged against. It is
	# NOT exempt from the absolute — a game that cannot draw a still frame in 8.33ms does not run at 120.
	var idle: PackedFloat32Array = await _phase(&"idle")
	var quiet: float = _pct(idle, 0.50)
	_report("IDLE  standing on the surface", idle)
	print("      -> a quiet frame is %.2fms; everything below is judged against it" % quiet)

	var ok: bool = true
	var run_ms: PackedFloat32Array = await _phase(&"run")
	ok = _gate("RUN   moving, chunks streaming", run_ms, quiet, MOVE_HITCH_RATIO) and ok
	var dig_ms: PackedFloat32Array = await _phase(&"dig")
	ok = _gate("DIG   mining, region rebakes", dig_ms, quiet, DIG_HITCH_RATIO) and ok
	var swing_ms: PackedFloat32Array = await _phase(&"swing")
	ok = _gate("SWING on the rope at speed", swing_ms, quiet, MOVE_HITCH_RATIO) and ok

	print("  draw calls in the last frame: %d   objects: %d"
		% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])

	var phases: Array[PackedFloat32Array] = [idle, run_ms, dig_ms, swing_ms]
	ok = _absolute(PackedStringArray(["IDLE", "RUN", "DIG", "SWING"]), phases, quiet) and ok

	if not ok:
		printerr("check_frametime: FAIL — see the phase(s) marked FAIL above")
		quit(1)
		return
	if _perf_host == "":
		print("check_frametime: PASS — nothing hitches; a dig costs a few quiet frames, not twenty."
			+ " Frame RATE is unasserted here (set SF_PERF_HOST on controlled hardware for that)")
	else:
		print("check_frametime: PASS — nothing hitches, and every phase fits in %.2fms on %s"
			% [FRAME_BUDGET_MS, _perf_host])
	quit(0)


## The absolute 120fps budget, and the whole of its refusal to run anywhere it would not mean anything.
##
## Three outcomes, and the middle one is the point: assert it on named hardware; state plainly that it is
## unasserted on everything else; and FAIL on named hardware whose frames are being paced by the display,
## because a vsync-pinned run reports the refresh interval whether the game has four milliseconds of
## headroom or none — passing on that measurement would be the same species of lie as counting a skip as a
## pass.
func _absolute(labels: PackedStringArray, phases: Array[PackedFloat32Array], quiet: float) -> bool:
	if _perf_host == "":
		# `SKIP:` at the start of the line is the harness contract for "this layer passed but stood part of
		# itself down" — see run_harness.sh:43. It matters here more than anywhere: this is the project's
		# ONLY 120fps assertion, SF_PERF_HOST was unset everywhere for the whole life of the code, and so
		# the budget had never once run while the summary said ALL PASS. An opt-in assertion is fine; a
		# SILENT opt-in assertion is decoration. It can no longer pass without saying it did not assert.
		print("  SKIP: the %.2fms/frame (120fps) budget was NOT asserted — SF_PERF_HOST is unset, so this"
			% FRAME_BUDGET_MS
			+ " is arbitrary hardware and the p95s above are a measurement, not a claim. Set"
			+ " SF_PERF_HOST=<machine-id> on a quiet, controlled box to turn the budget on.")
		return true

	var refresh: float = DisplayServer.screen_get_refresh_rate()
	var interval: float = (1000.0 / refresh) if refresh > 0.0 else 0.0
	if interval > 0.0:
		var fastest: float = _fastest(phases)
		var paced: float = _paced_fraction(phases, interval)
		print("  absolute: vsync evidence — fastest frame %.2fms against a %.2fms refresh; %.0f%% of all"
			% [fastest, interval, paced * 100.0]
			+ " samples land on a refresh multiple."
			+ (" The quiet frame is %.2fms, ON the interval: the game renders AT the panel's rate, so" % quiet
				+ " there is no headroom before it drops under it."
				if absf(quiet - interval) < VSYNC_PINNED_MS else ""))
		if paced > PACED_FRACTION:
			print("  absolute: CAUTION — that clustering is what vsync pacing looks like, so a FAIL below"
				+ " may be inflated. The budget is asserted anyway, and that is deliberate: vsync makes a"
				+ " frame WAIT for the next refresh, so it can only report times that are the same or"
				+ " SLOWER, never faster. A paced run can therefore produce a false FAIL but never a false"
				+ " PASS — and refusing to measure is exactly how this budget went unrun for its whole"
				+ " life. An honest red beats a silent nothing.")

	print("  absolute: SF_PERF_HOST=%s — every phase p95 must fit in %.2fms (120fps); the display refreshes"
		% [_perf_host, FRAME_BUDGET_MS]
		+ (" every %.2fms" % interval if interval > 0.0 else " at an unreported rate"))
	var ok: bool = true
	for i: int in labels.size():
		var ms: PackedFloat32Array = phases[i]
		if ms.is_empty():
			printerr("      FAIL: %s produced no samples — the budget was not measured" % labels[i])
			ok = false
			continue
		var p95: float = _pct(ms, 0.95)
		if p95 > FRAME_BUDGET_MS:
			printerr("      FAIL: %s p95 %.2fms is over the %.2fms budget — that phase is under 120fps on %s"
				% [labels[i], p95, FRAME_BUDGET_MS, _perf_host])
			ok = false
		else:
			print("      PASS: %s p95 %.2fms fits in %.2fms" % [labels[i], p95, FRAME_BUDGET_MS])
	return ok


## THE FASTEST FRAME IN THE RUN, and the reason this function exists is worth more than the function.
##
## The pin test used to be `quiet median ~= refresh interval`, and that is a guard that fires exactly when
## its target is MET. It cannot separate "vsync is holding us at 120fps" from "we are genuinely rendering
## at 120fps" — on a 120Hz panel both produce a quiet frame of 8.33ms. The first time anyone set
## SF_PERF_HOST, it refused to assert on a run that was not vsync-paced at all, and this cost an
## evening planning an OS-level fight that was never needed.
##
## What actually separates the two: under vsync the loop blocks on present, so NO frame can come in faster
## than the refresh interval. A single sample below it is proof the pacing is ours. The evidence that
## settled it was already sitting in the output nobody had read this way — an IDLE median of 8.27ms and a
## worst frame of 12.95ms, one below the 8.33ms interval and the other stranded between 8.33 and 16.67
## where a vsync-paced frame cannot land.
##
## `_phase` returns its samples sorted, so the fastest frame is ms[0] and costs nothing to read.
func _fastest(phases: Array[PackedFloat32Array]) -> float:
	var best: float = INF
	for ms: PackedFloat32Array in phases:
		if not ms.is_empty():
			best = minf(best, ms[0])
	return best


## What share of samples land on a multiple of the refresh interval — the actual vsync signature, and the
## reason the two simpler tests before it both failed.
##
## Test one was `quiet median ~= interval`. It fires exactly when the target is MET, and worse, it cannot
## fire at all once the game is slower than one refresh: forcing vsync on drove the quiet frame to 8.96ms,
## not 8.33, because pacing rounds a too-slow frame UP to the next interval rather than holding it at one.
##
## Test two was `did any frame beat the panel`. That looked decisive — under pacing nothing should present
## faster than the refresh — and it is not: a VSYNC_ENABLED run still produced a 5.65ms sample. A single
## outlier disables the whole detection, which is the worst property a guard can have.
##
## What survives both is CLUSTERING. Paced frames pile up on multiples of the interval; unpaced ones spread.
## Forced on: four phase p95s at 16.56 / 16.51 / 16.61 / 16.59. Forced off: 15.59 / 13.60 / 32.58 / 16.42.
func _paced_fraction(phases: Array[PackedFloat32Array], interval: float) -> float:
	if interval <= 0.0:
		return 0.0
	var on: int = 0
	var total: int = 0
	for ms: PackedFloat32Array in phases:
		for s: float in ms:
			total += 1
			var off: float = fmod(s, interval)
			if minf(off, interval - off) < VSYNC_PINNED_MS:
				on += 1
	return (float(on) / float(total)) if total > 0 else 0.0


## Run one phase for SAMPLE drawn frames, driving the body as that phase requires and timing each frame
## from the end of one draw to the end of the next. Returns the sorted millisecond samples.
func _phase(kind: StringName) -> PackedFloat32Array:
	var player: Player = _main._player
	var ms := PackedFloat32Array()
	if kind == &"swing":
		_fire_rope()
	var last: int = Time.get_ticks_usec()
	for i: int in SAMPLE:
		_drive(kind, player, i)
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		ms.append(float(now - last) / 1000.0)
		last = now
	player.input_dir = 0.0
	player.input_climb = 0.0
	ms.sort()
	return ms


## Per-frame input for a phase. Everything here goes through the same fields the keyboard drives, so the
## body does exactly what a player's body would — no teleporting, no synthetic load.
func _drive(kind: StringName, player: Player, i: int) -> void:
	match kind:
		&"run":
			# Reverse periodically so the run stays inside the generated world instead of hitting its edge.
			player.input_dir = 1.0 if (i / 60) % 2 == 0 else -1.0
		&"dig":
			var c: Vector2i = _main._cell_at(player.position) + Vector2i(0, 1)
			_main.try_mine(c)
			player.input_dir = 0.0
		&"swing":
			player.input_climb = 1.0 if (i / 30) % 2 == 0 else -1.0
		_:
			player.input_dir = 0.0


## Put the body on a rope so the SWING phase measures a real swing rather than a fall.
func _fire_rope() -> void:
	var player: Player = _main._player
	player.grapple.fire(player.hand(), player.hand() + Vector2(96.0, -192.0))


## The value at a percentile of the already-sorted samples.
func _pct(ms: PackedFloat32Array, q: float) -> float:
	if ms.is_empty():
		return 0.0
	return ms[clampi(int(float(ms.size()) * q), 0, ms.size() - 1)]


func _report(label: String, ms: PackedFloat32Array) -> void:
	if ms.is_empty():
		printerr("  %s: no samples" % label)
		return
	var total: float = 0.0
	for v: float in ms:
		total += v
	var mean: float = total / float(ms.size())
	print("  %s\n      mean %5.2fms (%4.0f fps)   p50 %5.2f   p95 %5.2f   p99 %5.2f   worst %6.2f"
		% [label, mean, 1000.0 / maxf(mean, 0.001), _pct(ms, 0.50), _pct(ms, 0.95),
			_pct(ms, 0.99), ms[ms.size() - 1]])


## Report a phase and gate its p95 against the quiet frame. p95, not p99 — see the header: the top one
## percent belongs to whatever else the machine is doing.
func _gate(label: String, ms: PackedFloat32Array, quiet: float, ratio: float) -> bool:
	_report(label, ms)
	if ms.is_empty():
		return false
	var p95: float = _pct(ms, 0.95)
	var got: float = p95 / maxf(quiet, 0.001)
	if got > ratio:
		printerr("      FAIL: p95 is %.1fx a quiet frame (%.2fms vs %.2fms), cap %.1fx — this phase hitches"
			% [got, p95, quiet, ratio])
		return false
	print("      PASS: p95 is %.1fx a quiet frame (cap %.1fx)" % [got, ratio])
	return true
