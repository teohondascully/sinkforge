extends SceneTree

## IT HAS TO RUN AT 120.
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
##   * VSYNC. Asking for it off does not reliably get it off on macOS, and when it is on every frame that
##     fits inside the refresh interval measures as exactly the refresh interval. A game with 4ms of
##     headroom and one with 0.1ms both report a perfect 8.33, and the number says nothing.
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

var _main: MainView = null


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("check_frametime: SKIP — no display; the dummy renderer draws nothing, so its frames are free")
		quit(0)
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

	print("== it has to run at 120 ==  (%d frames per phase, %s)"
		% [SAMPLE, DisplayServer.get_name()])

	# IDLE first and ungated: it defines the quiet frame the others are judged against.
	var idle: PackedFloat32Array = await _phase(&"idle")
	var quiet: float = _pct(idle, 0.50)
	_report("IDLE  standing on the surface", idle)
	print("      -> a quiet frame is %.2fms; everything below is judged against it" % quiet)

	var ok: bool = true
	ok = _gate("RUN   moving, chunks streaming", await _phase(&"run"), quiet, MOVE_HITCH_RATIO) and ok
	ok = _gate("DIG   mining, region rebakes", await _phase(&"dig"), quiet, DIG_HITCH_RATIO) and ok
	ok = _gate("SWING on the rope at speed", await _phase(&"swing"), quiet, MOVE_HITCH_RATIO) and ok

	print("  draw calls in the last frame: %d   objects: %d"
		% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])

	if not ok:
		printerr("check_frametime: FAIL — the game does not hold 120fps")
		quit(1)
		return
	print("check_frametime: PASS — nothing hitches; a dig costs a few quiet frames, not twenty")
	quit(0)


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
