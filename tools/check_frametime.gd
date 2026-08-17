extends "res://tools/check_base.gd"

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
## Every other layer in this suite judged what the game DOES and not one judged how fast it does it, which is
## a strange gap for a 2D game whose whole pitch is movement. A swing that measures beautifully and hitches
## twice on the way down is not a good swing, and no layer here could tell the difference. (This sentence
## used to open with a COUNT of those layers. It was written at 49 and read 49 at 66 — a number in prose is
## a claim with no runner, and the suite grows faster than anybody re-reads a docstring.)
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
## Both move the quiet frames and the busy frames together, so the RATIO between them survives MUCH of what
## the absolute numbers do not: a dig may cost a few times a quiet frame, never twenty times one. That is
## also the honest statement of the property — "mining must not hitch" — rather than a number copied off a
## spec sheet. The absolutes are still printed, because when the machine IS quiet they are what you want.
##
## THAT PARAGRAPH USED TO SAY THE RATIO "SURVIVES" LOAD, FULL STOP, AND IT IS NOT TRUE. Measured: with five
## unlocked Godot processes beside it the quiet frame rose 2.4x and the DIG ratio rose from 3.9-4.4x to
## 4.7-6.7x — through a 6.0x cap — because a longer frame has more wall-clock in which to be descheduled,
## so the numerator pays more for contention than the denominator. The ratio is a PARTIAL correction: it
## absorbs load for cheap phases and stops absorbing it as a phase gets expensive. A later pass found
## this from the opposite end, a sweep failing RUN at 2.1x that passed three times standalone. There is no
## fix inside the layer — see `_load_caveat`, which records the detector that failed and why its whole
## family must — so the defence is `tools/with_machine.sh`: anything that boots Godot takes the lock.
##
## PERCENTILES, not the mean. A hitch is one frame in a hundred and a mean of two hundred cannot see it.
## p95 carries the gate rather than p99 or max, because under background load the top one percent belongs
## to the operating system and gating on it would measure the machine instead of the game.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 90                 ## frames to let worldgen, the first full bake and the caches land
const SAMPLE: int = 200                ## frames measured per phase (IDLE/RUN/SWING: work is continuous)
## DIG measures a fixed amount of WORK instead, and stops when it has done it. 40 is under the 42-47 that
## four observed runs fitted into SAMPLE frames, so it is reachable on a slower machine without hitting the
## cap; the cap is 2x SAMPLE, and failing to reach 40 within it is a workload FAIL rather than a quiet
## short measurement.
const DIG_MINES: int = 40

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

var _main: MainView = null
## Non-empty = controlled hardware, named by whoever set it, and the absolute budget applies.
var _perf_host: String = OS.get_environment("SF_PERF_HOST")

## Per-phase proof that the phase did the work its name claims — filled by _phase, judged by _workload.
var _work: Dictionary = {}

## The display's refresh interval in ms, 0 if unreported. A machine constant that contention cannot move,
## which is what makes it the yardstick `_load_caveat` holds the quiet frame against.
var _interval: float = 0.0


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
	# TAKE THE SCENE'S EARS OFF, AFTER A FRAME HAS PASSED.
	#
	# This layer opens a REAL WINDOW with live input callbacks, and `main.gd:991` toggles `_paused` from
	# `_unhandled_input` on Controls.PAUSE — KEY_P or JOY_BUTTON_START. `_paused` is the FIRST gate
	# `try_mine` tests, so one stray keystroke, or a joypad that enumerates START, silently pauses the run
	# and every mine for the rest of it returns false with the world in perfect condition.
	#
	# That fits a failure I could not otherwise explain: DIG landed 0 of 40 in a sweep, the body correctly
	# placed over 44 rows of solid rock, all six cells beneath it solid, and fifteen isolated runs plus a
	# second full sweep could not reproduce it. It is the only candidate whose intermittency does not depend
	# on the world — which is exactly what ten byte-identical placements demand.
	#
	# `capture_moments.gd` learned this the hard way when an E and a P arrived mid-capture and it
	# photographed the Bazaar modal. It deafens; NO check_* layer did, including this one, and
	# `check_input_deafness` exists to prove the mechanism works while nothing was using it.
	#
	# AFTER a frame, not before: a SceneTree script's `_initialize` runs before the tree is up, so `_ready`
	# is deferred — and Godot re-arms unhandled-input delivery as part of it. Deafen first and `_ready`
	# turns the ears back on behind you.
	Controls.deaf = true
	_deafen(_main)
	await RenderingServer.frame_post_draw

	var player: Player = _main._player
	player.auto_input = false
	# FINISH THE BOOT BAKE BEFORE THE CLOCK STARTS. #17 made the fine bake progressive: a fresh scene paints
	# the visible rect and then fills the rest off-camera at 4ms a frame for about a second. That is real
	# work the game really does — and it happens once, at boot, and never again. A phase that caught the tail
	# of it would be reporting the BOOT cost under the name IDLE, and every ratio below divides by IDLE. This
	# is fixture setup for the same reason _stand_over_rock is: controlling a nuisance variable, not hiding a
	# cost. Whatever the fill costs belongs in a layer named for it, not in this one's denominator.
	var fine: FineTerrain = _main._renderer._fine
	if fine != null:
		fine.finish_pending()
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	_interval = (1000.0 / refresh) if refresh > 0.0 else 0.0

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
	# The quiet frame in refresh intervals, printed on EVERY run and not only on a failure. It is the one
	# number that says whether this box was busy, and a reader who only ever sees it beside a red gate has
	# no idea what it reads when things are fine. See _load_caveat.
	print("      -> a quiet frame is %.2fms" % quiet
		+ (" (%.2fx the display's %.2fms refresh interval)" % [quiet / _interval, _interval]
			if _interval > 0.0 else "")
		+ "; everything below is judged against it")

	var ok: bool = true
	var run_ms: PackedFloat32Array = await _phase(&"run")
	ok = _gate("RUN   moving, chunks streaming", run_ms, quiet, MOVE_HITCH_RATIO) and ok
	# Stand the body over rock before the clock starts — see _stand_over_rock. Without this the DIG phase
	# inherits wherever RUN happened to stop, which varies by several columns run to run, and lands over a
	# void about half the time.
	var seam: int = _stand_over_rock(_main._player)
	for _s: int in 12:
		await physics_frame                          # let the body settle onto the ground it was placed on
	print("      (dig site: %d rows of solid rock under the body, needs %d)" % [seam, DIG_MINES])
	var dig_ms: PackedFloat32Array = await _phase(&"dig", DIG_MINES, SAMPLE * 2)
	ok = _gate("DIG   mining, region rebakes", dig_ms, quiet, DIG_HITCH_RATIO) and ok
	var swing_ms: PackedFloat32Array = await _phase(&"swing")
	ok = _gate("SWING on the rope at speed", swing_ms, quiet, MOVE_HITCH_RATIO) and ok

	print("  draw calls in the last frame: %d   objects: %d"
		% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])

	# BEFORE any verdict about the timings: did the phases do their work at all? A timing distribution
	# gathered while nothing happened is not a slow result or a fast one, it is a mislabelled one.
	ok = _workload() and ok

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
## A MISSED DEADLINE, which is what "120fps" actually MEANS on a vsync-paced display, and the number this
## layer should have been reporting all along.
##
## Under pacing the frame delta is QUANTISED. A frame that fits presents at the refresh interval; a frame
## that misses waits for the next one and presents at twice it. There is nothing in between. So "is p95
## under 8.33ms" is very nearly unanswerable here: on a paced run p95 IS the interval by construction, and
## a p95 a hair above it does not mean the game is slow — it means roughly one frame in twenty presented
## late. Those are extremely different claims and the old output could not tell them apart.
##
## HOW OFTEN a deadline is missed is answerable, is what a player actually feels, and cannot be faked by
## pacing in either direction. 1.5x the interval is the threshold because there is no legitimate value
## there: a paced frame lands on 1.0x or on 2.0x, so anything past the midpoint waited for another refresh.
##
## This also exists because the alternative on the table was to assert the budget against
## `viewport_get_measured_render_time_cpu`, which reads 0.12-0.16ms on this machine. A gate comparing
## 0.16ms to 8.33ms cannot fail, and would have been vacuity shape 3 — an unreachable floor passing on
## noise — installed in the one place this project has been fighting exactly that. The render-CPU number is
## real and worth PRINTING; it is not a gate.
##
## THE CAP IS MEASURED, over EIGHT runs, and the number moved once while measuring it. Written first as 5%
## off two runs; a third read RUN at 6.0% and tripped it. That is the exact moment a threshold gets quietly
## nudged to fit, so instead of nudging, five more runs. The full distribution:
##
##   IDLE   0.0 - 6.0%
##   RUN    0.0 - 13.0%
##   SWING  1.5 - 4.0%
##   DIG    62.9 - 68.1%      <- eight runs, spread of five points
##
## The movement phases are dominated by MACHINE NOISE on this box, exactly as the VSYNC/THE MACHINE
## paragraphs at the top of this file predict, and nothing near 5% is assertable about them. DIG is not
## noise: it is five times the worst noise reading and its own spread is five points wide across eight runs.
##
## So 25%: about twice the worst healthy observation, and about two and a half times below the unhealthy
## one. It gates the one phase where the signal is real and stays silent where the number belongs to the
## operating system. A layer that fails when Spotlight is busy is a layer people learn to ignore.
##
## AND THEN THE MACHINE MOVED UNDER THE MEASUREMENT, WHICH IS WHY THERE IS NO GATE HERE YET.
##
## Immediately after the eight runs above, three more read IDLE 41%, RUN 37.5%, SWING 50%, DIG 89.7% —
## every phase five to ten times worse. That was not the game. `pgrep` found EIGHT Godot processes and a
## load average of 7.64: a neighbouring session was running captures without taking the harness lock, so
## the eight-run distribution and the three that contradict it were taken on two different computers that
## happen to share a case.
##
## The threshold is therefore NOT SET. A cap derived from data whose provenance collapsed mid-derivation
## is a number with a story, not a measurement, and the honest state of this is "measured twice, disagreed,
## needs a verified-quiet box". Setting one anyway — at 25%, which is where the arithmetic was heading —
## would have shipped exactly the thing this file's own header warns about: a threshold that fails for
## reasons the game did not cause is a threshold someone deletes within a month.
##
## So `_drop_rate` REPORTS and does not assert. Reporting is immune to the contention that ruined the
## derivation: a printed number carries its own conditions, and the reader can see IDLE at 41% and know to
## look at the load average. An assertion cannot do that.
##
## What survives the contamination anyway, because it is a RATIO between phases measured in the same run
## rather than an absolute: DIG misses roughly ten to a hundred times as many deadlines as the phases that
## do no terrain work, on every run, contended or not. That comparison is the finding — the game holds its
## frame rate except when it edits terrain — and it is the shape this layer's ratio gates were built around
## in the first place. See the audit notes, Strike 12.
##
## WHOEVER SETS THIS: take it on a quiet box with the harness lock held and `pgrep Godot` returning one
## process, over at least eight runs, and write the distribution here. Do not derive it from a suite run.
const DROP_AT: float = 1.5
func _drop_rate(ms: PackedFloat32Array, interval: float) -> float:
	if ms.is_empty() or interval <= 0.0:
		return 0.0
	var late: int = 0
	for v: float in ms:
		if v > interval * DROP_AT:
			late += 1
	return float(late) / float(ms.size())


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

	var interval: float = _interval
	var paced: bool = false
	if interval > 0.0:
		var fastest: float = _fastest(phases)
		var quiet_paced: float = _paced_fraction(phases[0], interval)
		paced = quiet_paced > PACED_FRACTION
		print("  absolute: vsync evidence — fastest frame %.2fms against a %.2fms refresh; %.0f%% of QUIET"
			% [fastest, interval, quiet_paced * 100.0]
			+ " samples land on a refresh multiple."
			+ (" The quiet frame is %.2fms, ON the interval." % quiet
				if absf(quiet - interval) < VSYNC_PINNED_MS else ""))
		if paced:
			print("  absolute: PACED — the quiet phase is waiting on the panel, so a frame that fits inside"
				+ " the refresh reports as the refresh and its true cost is invisible. On a 120Hz display"
				+ " the interval (%.2fms) IS the budget, which makes 'we hit 120fps' and 'we are pinned at" % interval
				+ " 120fps' the same number. Under-budget phases below therefore STAND DOWN rather than"
				+ " pass. Over-budget phases still FAIL, and that is sound: pacing only ever makes a frame"
				+ " report the same or SLOWER, so a phase that exceeded the budget really did exceed it.")

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
		# The missed-deadline rate alongside the p95, always, whichever way the budget goes. On a paced run
		# it is the only one of the two that distinguishes "slow" from "occasionally late", and a reader
		# comparing 8.81ms to 8.33ms without it will conclude the wrong thing — as happened here twice.
		var drops: float = _drop_rate(ms, interval)
		print("      %s: p95 %.2fms · %.1f%% of frames missed their %.2fms slot (>%.2fms)"
			% [labels[i], p95, drops * 100.0, interval, interval * DROP_AT])
		if p95 > FRAME_BUDGET_MS:
			printerr("      FAIL: %s p95 %.2fms is over the %.2fms budget — that phase is under 120fps on %s"
				% [labels[i], p95, FRAME_BUDGET_MS, _perf_host]
				+ (". NOTE: it missed only %.1f%% of its slots, so on a paced display this p95 is consistent"
					% (drops * 100.0)
					+ " with a phase that is comfortably fast and occasionally late rather than a slow one —"
					+ " read the drop rate before acting on this number."
					if drops <= 0.10 else ""))
			ok = false
		elif paced:
			# Deliberately a stand-down and not a pass. A paced under-budget number is consistent with a
			# game costing 0.2ms and with one costing 8.3ms, and the harness counts this line, so the run
			# reports "passed without verifying everything" rather than banking a green nobody earned.
			print("  SKIP: %s p95 %.2fms is inside the %.2fms budget, but the run is vsync-paced — a frame"
				% [labels[i], p95, FRAME_BUDGET_MS]
				+ " that fits inside the refresh reports AS the refresh, so this number cannot tell a fast"
				+ " phase from a pinned one. Not asserted.")
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
## MEASURED ON THE QUIET PHASE ALONE, and pooling every phase was a real defect in the first version.
## Pacing is only visible where the game is FASTER than the panel: a DIG frame at 33ms is not waiting on
## anything, so its samples land wherever they like and dilute the signal. Pooled over four phases this
## reported 18-39% on a machine the peer's independent profiler measured at 72.5% of STILL frames on a
## multiple — under the 0.6 threshold, so the pooled version said "not paced" about a run that was.
func _paced_fraction(ms: PackedFloat32Array, interval: float) -> float:
	if interval <= 0.0 or ms.is_empty():
		return 0.0
	var on: int = 0
	for s: float in ms:
		var off: float = fmod(s, interval)
		if minf(off, interval - off) < VSYNC_PINNED_MS:
			on += 1
	return float(on) / float(ms.size())


## Run one phase for SAMPLE drawn frames, driving the body as that phase requires and timing each frame
## from the end of one draw to the end of the next. Returns the sorted millisecond samples.
## `until_mines` makes the WORK the constant and the frame count the variable, which is the only way a
## before/after on the dig path means anything. Left at 0 the phase runs a fixed SAMPLE frames, which is
## right for IDLE/RUN/SWING because their work is continuous. DIG's is not: it lands a mine, falls, lands
## another, and how many it fits into 200 frames depends on how fast it fell. That put 42-47 mines and a
## 33-40ms p95 spread on honest runs — wide enough to swallow a real 15% win whole.
func _phase(kind: StringName, until_mines: int = 0, cap: int = SAMPLE) -> PackedFloat32Array:
	var player: Player = _main._player
	var ms := PackedFloat32Array()
	if kind == &"swing":
		_fire_rope()
	var moved: float = 0.0
	var mined: int = 0
	var anchored: int = 0
	var prev: Vector2 = player.position
	var last: int = Time.get_ticks_usec()
	for i: int in cap:
		if until_mines > 0 and mined >= until_mines:
			break
		if _drive(kind, player, i):
			mined += 1
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		ms.append(float(now - last) / 1000.0)
		last = now
		# Evidence that this phase did the work its NAME claims — gathered inside the timed loop because
		# that is the only place it is true of the frames actually measured. See _workload.
		moved += player.position.distance_to(prev)
		prev = player.position
		if player.grapple.state == Grapple.State.ANCHORED:
			anchored += 1
	player.input_dir = 0.0
	player.input_climb = 0.0
	_work[kind] = {"moved": moved, "mined": mined, "anchored": anchored, "frames": ms.size(),
		"at": _main._cell_at(player.position)}
	ms.sort()
	return ms


## Per-frame input for a phase. Everything here goes through the same fields the keyboard drives, so the
## body does exactly what a player's body would — no teleporting, no synthetic load.
##
## Returns whether this frame did the phase's characteristic WORK — currently only meaningful for dig,
## whose `try_mine` reports success. The return value used to be discarded, which is how a DIG phase that
## mined nothing would still have reported a timing distribution under the name DIG.
func _drive(kind: StringName, player: Player, i: int) -> bool:
	match kind:
		&"run":
			# Reverse periodically so the run stays inside the generated world instead of hitting its edge.
			player.input_dir = 1.0 if (i / 60) % 2 == 0 else -1.0
		&"dig":
			var target: Vector2i = _dig_target(player)
			var hit: bool = _main.try_mine(target)
			if hit:
				_dig_refusals_running = 0
			else:
				_dig_refusals_running += 1
				if _dig_refusals_running >= STUCK_REFUSALS and not _dig_refusal_reported:
					_dig_refusal_reported = true
					_report_refusal(player, target)
			player.input_dir = 0.0
			return hit
		&"swing":
			player.input_climb = 1.0 if (i / 30) % 2 == 0 else -1.0
		_:
			player.input_dir = 0.0
	return false


## THE FIRST SOLID CELL AT OR BELOW THE BODY, rather than blindly the one row down.
##
## The blind version made this phase depend on the body's exact sub-pixel position at the moment RUN handed
## over, which is not a stable thing to depend on. Same commit, same machine, measured: an isolated run
## landed 46 mines and finished 53 rows deeper; a full-suite run landed ONE and never moved, because RUN
## had ended 10px further along and the cell under the feet was already open. The phase then timed 200
## frames of a body standing still and reported the distribution under the name DIG — and reported it as
## 9.36ms p95 against the honest 33.37ms, so the broken fixture looked like a 3.5x performance win.
##
## Searching downward for real rock is what check_dig_hitch already does, for exactly this reason. Bounded
## by DIG_REACH so that a body genuinely standing over a void still fails the workload floor rather than
## silently teleporting its dig to the bottom of the world — the failure must stay visible.
## PERSISTENT refusals, not the first one — and the difference is the whole value of the instrument.
##
## The first version reported the FIRST refusal and was immediately useless: every healthy run refuses once,
## on the frame after a successful mine, when the cell below is the hole you just made and the next solid
## rock is further than the reach. Benign, self-correcting, and it would have consumed the one-shot before
## anything interesting could happen — a diagnostic spent on the normal case is a diagnostic that is not
## there for the abnormal one.
##
## The failure this is for is 400 consecutive refusals. So the trigger is a RUN of them: long enough that a
## body falling between strikes cannot produce it, short enough to fire well before the phase gives up.
const STUCK_REFUSALS: int = 30
var _dig_refusals_running: int = 0
var _dig_refusal_reported: bool = false


## WHY DID `try_mine` SAY NO — asked at the first refusal, answered from the three gates it actually has.
##
## This exists because the failure it is for happened ONCE, in a sweep, and could not be reproduced in
## fifteen isolated runs, a loaded-box arm, or a second full sweep. A defect at that rate cannot be chased
## by re-running; the only affordable move is to make sure the NEXT occurrence arrives with its own answer
## attached. "DIG landed 0 of 40" plus a dig-site print already eliminated placement — the body stood over
## 44 rows of solid rock — so what remains is `try_mine` refusing a target it should have taken, and the
## three reasons it can are paused, reach/line-of-sight, and no tool for this material.
##
## Printed rather than asserted. Adding a gate here would guess at the mechanism, and the whole reason this
## function exists is that nobody knows it yet.
func _report_refusal(player: Player, target: Vector2i) -> void:
	var here: Vector2i = _main._cell_at(player.position)
	var mat: StringName = _main.sim.material_at(target)
	printerr("    !! try_mine REFUSED %d TIMES IN A ROW at %s (body at %s, %d cells away)"
		% [_dig_refusals_running, target, here, target.y - here.y])
	printerr("       paused=%s  solid=%s  material=%s"
		% [_main._paused, _main.sim.is_solid(target), String(mat) if mat != &"" else "(none)"])
	printerr("       can_mine=%s  pack=%s"
		% [MiningRules.can_mine(mat, _main.sim.inventory), _main.sim.inventory])
	# EVERY GATE, NAMED SEPARATELY. The previous line said "if solid and can_mine, it was REACH or LINE OF
	# SIGHT" — a two-way guess that was also incomplete, because `_mineable` has a fourth clause. Each gate
	# is now reported as itself, so the next occurrence arrives with the answer rather than a shortlist.
	var bit: StringName = BitRules.equipped(_main._selected_item())
	printerr("       reach=%s  line_of_sight=%s  bit=%s grain_only=%s bites=%s"
		% [_main._can_reach(target), _main._line_of_sight_clear(_main._body_cell(), target),
			String(bit), BitRules.grain_only(bit), _main._bit_bites(bit, target)])
	printerr("       body px=%s  target centre px=%s  distance=%.1f cells (reach is %.1f)"
		% [player.position, _main._cell_center(target),
			player.position.distance_to(_main._cell_center(target)) / float(WorldRenderer.CELL),
			MainView.REACH_CELLS])


## DERIVED FROM THE GAME'S OWN REACH, not typed. It was 4 and the body can mine 3.2 cells, so
## `_dig_target` could return a cell the verb is FORBIDDEN to service and `try_mine` refused it every
## frame for as long as the body stayed there.
##
## Caught by the refusal reporter on a PASSING run — one refusal at (42, 23) with the body at (42, 19),
## four cells away — which is the argument for printing a diagnostic on the first failure rather than only
## when the layer goes red. The run was green; the defect was live; nothing would ever have said so.
##
## Whether this is THE mechanism behind the one 0-mines sweep is not established and I am not claiming it:
## a transient four-cell gap self-corrects as the body falls, and the failing run would have needed the
## body held there for 400 frames. What is established is that the fixture could select an unreachable
## target at all, which is a fixture that can fail for a reason having nothing to do with what it measures.
##
## `floori`, not `roundi`: 3.2 cells of reach means three whole cells, and rounding up would restore the
## bug with a derivation in front of it.
const DIG_REACH: int = int(floor(MainView.REACH_CELLS))

## ASK THE VERB, DO NOT MODEL IT. The scan now tests `_main._mineable(c)` — the exact predicate
## `try_mine` gates on — instead of `is_solid`, which was only ever one of its four clauses.
##
## Deriving `DIG_REACH` from `REACH_CELLS` fixed the gross case (it was a typed 4 against a 3.2 reach) and
## I wrote a docstring claiming the fixture could no longer select a cell the verb was forbidden to service.
## That claim was too strong and this is the retraction. `_can_reach` is a EUCLIDEAN PIXEL distance from
## the body's centre to the cell's centre (main.gd:2439); `dy <= DIG_REACH` is a ROW COUNT. They disagree
## by up to a cell depending on where in its own cell the body is standing: sitting high in row 19, the
## centre of row 22 is ~3.5 cells away and REFUSED, while `dy == 3` waves it through. A row count is not a
## radius, and rounding the radius down does not turn it into one — it only shrinks how often they differ.
##
## And `_mineable` has a fourth clause the proxy never modelled at all: `_bit_bites`, the Wedge grain rule.
## A grain-only bit facing a misaligned seam refuses that cell PERMANENTLY — the body is not falling, so
## nothing self-corrects, and the refusal repeats every frame for as long as the phase runs. That is the
## only mechanism I have found whose signature actually matches the one unreproduced failure (400
## consecutive refusals, body over 44 rows of solid rock). I am NOT claiming it is that failure's cause:
## the failing run's bit is not in the record and this fixture has never been seen to equip a grain-only
## one. It is a candidate that the old proxy was structurally incapable of surfacing, which is reason
## enough to stop using the proxy.
##
## `DIG_REACH` survives as the SEARCH BOUND — how far down to look — which is the one job a row count is
## right for. The reach decision itself now belongs to the code that owns it.
##
## The fallback is deliberately still an unmineable cell rather than the best near-miss. If nothing within
## reach is mineable, the honest outcome is `try_mine` refusing, the refusal reporter naming which gate
## said no, and the workload floor failing the layer. Substituting a cell the verb would accept would
## convert "this fixture had nothing to dig" into a passing measurement of somewhere else.
func _dig_target(player: Player) -> Vector2i:
	var here: Vector2i = _main._cell_at(player.position)
	for dy: int in range(1, DIG_REACH + 1):
		var c: Vector2i = here + Vector2i(0, dy)
		if _main._mineable(c):
			return c
	return here + Vector2i(0, 1)


## How far either side of the body to look for a column worth digging.
const COLUMN_SEARCH: int = 12


## PUT THE BODY OVER ROCK BEFORE TIMING A DIG.
##
## `_dig_target` widened the search downward and that was only the DETECTION half. The cause is stated in
## its own docstring and was never addressed: the DIG phase measured whatever happened to be under the feet
## when the previous phase handed over, and RUN's stopping point is not stable — measured across runs on
## one machine it varies from 210px to 323px, which is several columns. On roughly half of all runs the
## body finished over a void, nothing was within DIG_REACH, and the phase timed a body standing still.
##
## The workload guard added last session catches that and fails the layer, which is correct — and which
## also meant the whole suite went red on a coin flip. A layer that fails half the time is a layer people
## learn to ignore, which this file's own header warns about in the paragraph about background load.
##
## THIS IS SETUP, NOT A MEASURED FRAME, and that is the whole reconciliation with `_drive`'s "no
## teleporting, no synthetic load". That rule governs the frames being TIMED: every input inside the loop
## goes through the fields a keyboard drives, and that is untouched. Where the body stands when the clock
## starts is a nuisance variable, and controlling a nuisance variable is what a fixture is for. Leaving it
## to chance is not neutrality, it is just a noisier experiment.
##
## Picks the DEEPEST solid column within reach so all DIG_MINES cuts land in real rock rather than breaking
## through into a cave halfway and timing air. Returns the depth found, so a world with nowhere to dig
## still fails the workload floor loudly instead of being quietly relocated somewhere useless.
func _stand_over_rock(player: Player) -> int:
	var here: Vector2i = _main._cell_at(player.position)
	var best_col: int = here.x
	var best_depth: int = -1
	for dx: int in range(-COLUMN_SEARCH, COLUMN_SEARCH + 1):
		var col: int = here.x + dx
		var top: int = _main.sim.surface_row(col)
		var depth: int = 0
		while depth < DIG_MINES + DIG_REACH and _main.sim.is_solid(Vector2i(col, top + depth)):
			depth += 1
		if depth > best_depth:
			best_depth = depth
			best_col = col
	var surf: int = _main.sim.surface_row(best_col)
	player.position = _main._cell_center(Vector2i(best_col, surf - 1))
	player.velocity = Vector2.ZERO
	# SAY WHERE IT STOOD AND WHAT WAS UNDER IT, every run, not only on failure.
	#
	# This fixture fails intermittently — 40 mines and 37 rows deeper on one run, 0 mines and the body
	# unmoved on the next, same tree — and when it failed there was nothing in the output to tell WHICH
	# assumption broke. "DIG landed 0 of 40" says the phase did no work; it does not say whether the body
	# was placed somewhere wrong, placed right and then moved, or placed right over rock that was not
	# there. Three different bugs, one message.
	#
	# The column under the feet is the whole premise: `_dig_target` searches DIG_REACH rows down and returns
	# an AIR cell if it finds nothing, which `try_mine` then refuses forever. So print the thing that
	# decides it. A fixture that cannot explain its own failure makes every run after it a re-run rather
	# than an investigation, and this one has already cost a full sweep.
	var under: String = ""
	# `_paused` printed every run, because it is the one gate that does not depend on world state and the
	# falsifier for the input hypothesis above: a recurrence with paused=true confirms it, a recurrence with
	# paused=false eliminates the last non-world gate. One field, in a line already being printed.
	for d: int in range(0, DIG_REACH + 2):
		under += "#" if _main.sim.is_solid(Vector2i(best_col, surf + d)) else "."
	print("    dig site: col %d, surface_row %d, body at row %d, %d solid rows found, under the feet [%s], paused=%s, deaf=%s"
		% [best_col, surf, surf - 1, best_depth, under, _main._paused, Controls.deaf])
	return best_depth


## Put the body on a rope so the SWING phase measures a real swing rather than a fall.
func _fire_rope() -> void:
	var player: Player = _main._player
	player.grapple.fire(player.hand(), player.hand() + Vector2(96.0, -192.0))


## DID THE PHASES ACTUALLY DO THEIR WORK? An external audit found that they might not, and that the layer
## could not tell:
##
##   "RUN does not require a minimum distance. DIG discards try_mine()'s result and does not require
##    successful mines. SWING does not require an anchored grapple. A fixture drift can produce green
##    timing ratios for idle or failed phases."
##
## That is exactly right, and it is the vacuity shape this project keeps finding, arriving in a perf
## fixture instead of an assertion: the numbers were real measurements OF SOMETHING, and nothing checked
## that the something was digging. A DIG phase whose mines all failed against bedrock would report a
## beautiful flat distribution and pass every ratio gate, and the greener it looked the more wrong it
## would be.
##
## THE FLOORS ARE HALF THE OBSERVED MINIMUM, and they were set after measuring rather than before, because
## guessing a floor before observing the thing has been wrong every time it was tried in this repo. Four
## consecutive runs on m4pro-arm64-local, same commit:
##
##   RUN moved       205 · 208 · 208 · 210 px          (spread ~2%)
##   DIG landed       47 ·  47 ·  42 ·  46 mines/200   (spread ~11%)
##   SWING anchored  195 · 196 · 200 · 200 frames/200  (spread ~3%)
##
## Every floor sits at roughly half the smallest observed value, which is 20-25x the measured run-to-run
## spread in each case. That is deliberately loose: this guard's job is to catch a phase that stopped doing
## its work — a body that cannot move, mines that all fail, a rope that never takes — and NOT to police
## small changes in how far the fixture happens to travel. A tight floor here would fail on honest fixture
## edits and teach everyone to raise it, which is how a guard becomes a formality.
## DIG's floor is not half-the-observed like the other two: the phase now stops AT DIG_MINES, so anything
## short of it means the cap was hit and the fixed work did not complete. Exact, and it cannot pass vacuously.
const RUN_MIN_PX: float = 100.0
const DIG_MIN_MINES: int = DIG_MINES
const SWING_MIN_ANCHORED: int = 100
func _workload() -> bool:
	var run_moved: float = float(_work.get(&"run", {}).get("moved", 0.0))
	var dig_mined: int = int(_work.get(&"dig", {}).get("mined", 0))
	var swing_anchored: int = int(_work.get(&"swing", {}).get("anchored", 0))
	print("  workload: RUN moved %.0fpx · DIG landed %d mines in %d frames (fixed work) · SWING anchored"
		% [run_moved, dig_mined, int(_work.get(&"dig", {}).get("frames", 0))]
		+ " %d frames of %d" % [swing_anchored, SAMPLE]
		+ "   (body ended RUN at %s, DIG at %s, SWING at %s)"
			% [_work.get(&"run", {}).get("at", Vector2i.ZERO),
				_work.get(&"dig", {}).get("at", Vector2i.ZERO),
				_work.get(&"swing", {}).get("at", Vector2i.ZERO)])
	var ok: bool = true
	if run_moved < RUN_MIN_PX:
		printerr("      FAIL: RUN moved the body %.0fpx, under the %.0fpx floor — the phase is timing a"
			% [run_moved, RUN_MIN_PX]
			+ " body that is stuck or standing still, under the name RUN")
		ok = false
	if dig_mined < DIG_MIN_MINES:
		printerr("      FAIL: DIG landed only %d of its %d fixed mines before the %d-frame cap — the phase"
			% [dig_mined, DIG_MIN_MINES, SAMPLE * 2]
			+ " did not complete its work, so this distribution is not comparable to any other run's and"
			+ " is not the cost of mining")
		ok = false
	if swing_anchored < SWING_MIN_ANCHORED:
		printerr("      FAIL: SWING was anchored for %d of %d frames, under the %d floor — the rope did not"
			% [swing_anchored, SAMPLE, SWING_MIN_ANCHORED]
			+ " take the body, so the phase timed a fall rather than a swing")
		ok = false
	return ok


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


## WHAT A READER HAS TO CHECK BEFORE BELIEVING A RED RATIO — and the negative result behind it, which is
## the more useful half and is written here because deleted code leaves no trace of what it cost to learn.
##
## THE HEADER'S CENTRAL CLAIM IS WRONG AND HAS BEEN CORRECTED ABOVE. It said "both move the quiet frames
## and the busy frames together, so the RATIO between them survives what the absolute numbers do not". The
## a later pass hit the counterexample: this layer passed standalone three times (quiet 8.57/8.06/8.01ms,
## RUN 1.2-1.8x) and FAILED inside a sweep at RUN 2.1x against a 2.0x cap, on a quiet frame of 10.51ms.
##
## I TRIED TO BUILD A DETECTOR FOR IT AND IT DOES NOT WORK. The idea was sound on its face: measure the
## quiet frame TWICE, at the start and again at the end from the same fixture, and refuse to render a ratio
## verdict if the unit moved between them. Eight runs on an idle box, then three beside five deliberately
## unlocked Godot processes at load 7.89:
##
##                     idle box (8 runs)    5 unlocked neighbours (3 runs)
##   quiet frame       8.01 - 8.37 ms       18.31 - 21.10 ms
##   start-to-end drift  1.00 - 1.13x        1.03 - 1.17x     <- OVERLAPS. Not a discriminator.
##   IDLE p95/p50      1.05 - 1.68x          1.33 - 1.37x     <- also overlaps
##   DIG ratio         3.9 - 4.4x            4.7 - 6.7x       <- the failure, cap 6.0x
##
## SUSTAINED LOAD SCALES THE WHOLE DISTRIBUTION UNIFORMLY. The contended runs are not noisier in shape —
## their p95/p50 is indistinguishable from an idle box's — they are the same distribution multiplied by
## 2.4. So nothing INTERNAL to a run separates "this box is loaded" from "this box is slow", and every
## detector of that family is dead on arrival, not just the one I wrote. A drift threshold would have had
## to sit between 1.13 and 1.17 — inside the run-to-run noise of the idle box — which is vacuity shape 3,
## a floor no configuration reliably reaches, and I would have shipped it in the one file that warns about
## shape 3 twice, one commit after writing a strike about not doing that. It is deleted rather than tuned.
##
## WHAT THE RATIO ACTUALLY IS, then, stated correctly: a PARTIAL correction for machine load, not an
## invariant. It absorbs load for cheap phases (RUN read 1.4x contended, inside its idle-box 1.1-1.6x
## range) and fails to absorb it for expensive ones (DIG 3.9-4.4x idle, 4.7-6.7x contended, on one commit).
## A longer frame has more wall-clock in which to be descheduled, so the numerator pays more for contention
## than the denominator does, and the more expensive the phase the worse the correction holds.
##
## THE ONLY DEFENCE IS THE PROTOCOL, which is why `tools/with_machine.sh` exists (peer, `0cdb36a`):
## anything that boots Godot takes the machine lock. This function is what is left over — it cannot stop a
## contended run, so it tells whoever reads the failure how to recognise one.
func _load_caveat(quiet: float) -> String:
	if _interval <= 0.0:
		return ""
	return (". Before believing this: the quiet frame it divides by is %.2fx the display's %.2fms refresh"
		% [quiet / _interval, _interval]
		+ " interval. On THIS project's hardware a still frame costs almost exactly one interval on an idle"
		+ " box and 2.4x that with five unlocked Godot processes beside it, and the same commit's DIG ratio"
		+ " rose from 3.9-4.4x to 4.7-6.7x purely from the load. A quiet frame well above one interval means"
		+ " you are reading the machine and not the game — re-run it through tools/with_machine.sh, which"
		+ " takes the lock, before treating this as a regression")


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
			% [got, p95, quiet, ratio] + _load_caveat(quiet))
		return false
	print("      PASS: p95 is %.1fx a quiet frame (cap %.1fx)" % [got, ratio])
	return true


## Clear every input door on every node — `_input`, `_unhandled_input`, `_unhandled_key_input` — plus the
## POLLING path via `Controls.deaf`, which the callback flags do not touch. Recursive rather than naming
## MainView, because the HUD and anything added later have doors too and a list of them would rot. Lifted
## from `capture_moments.gd`, which is the only tool in the repo that had this right.
func _deafen(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	for c: Node in n.get_children():
		_deafen(c)
