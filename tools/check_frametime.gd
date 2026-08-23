extends "res://tools/check_base.gd"

## NOTHING MAY HITCH. And on named hardware, it has to run at 120.
##
## THE NAME WAS A LIE FOR THIS LAYER'S WHOLE LIFE. It was registered in the runner as `check_frametime
## (120fps)`, it printed "the game does not hold 120fps" when it failed, and it never once compared
## anything to 8.33ms. What it asserts (and the reasons are below, and they are good ones) is a RATIO:
## a busy frame's p95 against a quiet frame's median. That ratio is the portable, honest property, and it
## is kept exactly as it was. But a ratio cannot tell you the frame rate, so the claim moved to where it
## can be true: an absolute 8.33ms budget that runs ONLY when SF_PERF_HOST names the machine (see
## FRAME_BUDGET_MS). Everywhere else this layer says what it measured and asserts only the ratio.
##
## Every other layer in this suite judged what the game DOES and not one judged how fast it does it, which is
## a strange gap for a 2D game whose whole pitch is movement. A swing that measures beautifully and hitches
## twice on the way down is not a good swing, and no layer here could tell the difference. (This sentence
## used to open with a COUNT of those layers. It was written at 49 and read 49 at 66; a number in prose is
## a claim with no runner, and the suite grows faster than anybody re-reads a docstring.)
##
## WALL-CLOCK, not `Performance.TIME_PROCESS`. The engine's process timer counts script time and misses the
## command buffer, the submit and everything the driver does. And on this renderer that is most of a frame.
## Ticks around `frame_post_draw` count what a player waits for.
##
## FOUR PHASES, because the costs are not the same shape and a single average hides the one that matters:
##   IDLE : standing still on the surface: the floor cost of drawing the world at all
##   RUN  : moving, so chunks stream, the veil chases and the speed streaks draw
##   DIG  : mining, which triggers the fine-terrain REGION rebake; the known hot path (#102)
##   SWING: on the rope at speed: particles, streaks, the rope, the fastest camera in the game
##
## THE BAR IS RELATIVE, and that took a round to get right. Two things make an absolute millisecond budget
## unmeasurable here:
##   * VSYNC. When it is on, every frame that fits inside the refresh interval measures as exactly the
##     refresh interval. A game with 4ms of headroom and one with 0.1ms both report a perfect 8.33, and
##     the number says nothing. This is why the absolute budget refuses to assert on a paced run.
##     MEASURED, and the older claim here was wrong: this file used to say "asking for it off does not
##     reliably get it off on macOS", and a boot-time override.cfg fight was planned around that
##     sentence. On macOS arm64 (M4 Pro, Godot 4.6.2) the VSYNC_DISABLED call in _run() DOES take effect,
##     proven by samples arriving FASTER than the panel can present, which vsync makes impossible. See
##     _fastest. Treat the claim as machine-specific and re-derive it from the samples, not from prose.
##   * THE MACHINE. A background reindex can put whole SECONDS into a frame that the game had no part in.
##     A layer that fails when Spotlight is busy is a layer people learn to ignore.
## Both move the quiet frames and the busy frames together, so the RATIO between them survives MUCH of what
## the absolute numbers do not: a dig may cost a few times a quiet frame, never twenty times one. That is
## also the honest statement of the property, "mining must not hitch", rather than a number copied off a
## spec sheet. The absolutes are still printed, because when the machine IS quiet they are what you want.
##
## THAT PARAGRAPH USED TO SAY THE RATIO "SURVIVES" LOAD, FULL STOP, AND IT IS NOT TRUE. Measured: with five
## unlocked Godot processes beside it the quiet frame rose 2.4x and the DIG ratio rose from 3.9-4.4x to
## 4.7-6.7x (through a 6.0x cap) because a longer frame has more wall-clock in which to be descheduled,
## so the numerator pays more for contention than the denominator. The ratio is a PARTIAL correction: it
## absorbs load for cheap phases and stops absorbing it as a phase gets expensive. It turned up from the
## opposite end, a sweep failing RUN at 2.1x that passed three times standalone. There is no
## fix inside the layer (see `_load_caveat`, which records the detector that failed and why its whole
## family must), so the defence is `tools/with_machine.sh`: anything that boots Godot takes the lock.
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

## A quiet frame (the median of the IDLE phase) is the unit everything else is measured in. With vsync on
## it is the refresh interval; with vsync off it is the game's real floor cost. Either way it is what the
## machine can do when the game is asking for nothing.
##
## HOW MUCH A DIG MAY COST, as a multiple of that quiet frame. Set from measurement with room to spare, and
## its job is to stop the hitch coming back: before #S14 a dig cost 13.6x a quiet frame (114ms against 8.4)
## and the game visibly stalled once a second while mining. It now costs 3.7x. The bar is 6x, comfortably
## clear of where the code is, nowhere near where it was.
const DIG_HITCH_RATIO: float = 6.0
## Movement must not hitch AT ALL: nothing about running or swinging changes the world, so there is no bake
## to pay for and no excuse for a slow frame.
const MOVE_HITCH_RATIO: float = 2.0

## THE ABSOLUTE BUDGET, and the one place in this project where 120fps is an assertion rather than an
## ambition. 120 frames per second is 8.33ms per frame, so every measured phase's p95 must fit inside it.
##
## IT RUNS ONLY WHERE THE NUMBER MEANS SOMETHING. `SF_PERF_HOST` names the machine; set it to whatever
## identifies the box you are calibrating on, e.g. `SF_PERF_HOST=m4max-16in`. Naming it is an assertion by
## whoever set it that this is controlled hardware and vsync is genuinely off. On anything else the budget
## is not merely noisy, it is meaningless (see VSYNC above: a vsync-pinned run reports the refresh interval
## no matter how fast the game is), and a threshold that fails for reasons the game did not cause is a
## threshold someone deletes within a month. So: unset means the absolute is measured, printed, and NOT
## asserted, which is stated in the output so no one reads the pass as a frame-rate claim.
const FRAME_BUDGET_MS: float = 1000.0 / 120.0

## How close the quiet frame has to sit to the display's refresh interval before the run counts as
## vsync-pinned and the absolute goes unasserted. Frames landing on the refresh within a fifth of a
## millisecond are being paced by the display, not by the game.
const VSYNC_PINNED_MS: float = 0.2

## Fraction of samples sitting on a refresh multiple above which the run LOOKS vsync-paced. Measured, not
## guessed: forcing VSYNC_ENABLED on this machine drives every phase p95 to ~16.5ms (two refresh intervals,
## uniform across four phases that otherwise differ by 2x) while a genuine VSYNC_DISABLED run spreads them
## 13.6 / 15.6 / 16.4 / 32.6. Clustering is the signal; individual frames are not. A handful of samples DO
## come in under the interval even with vsync requested on, which is why "was any frame faster than the
## panel" looked decisive and is not.
const PACED_FRACTION: float = 0.6

var _main: MainView = null
## Non-empty = controlled hardware, named by whoever set it, and the absolute budget applies.
var _perf_host: String = OS.get_environment("SF_PERF_HOST")
## LET THE GAME HEAR THE DIG BUTTON, and make sure the button means DIG.
##
## `Controls.deaf` gates `Controls.pressed()`, which is what `_update_mining` consults. It is true for the
## whole run because a stray PAUSE keystroke once landed DIG 0 of 40 with the world in perfect condition.
## Clearing it here does not bring that back: `_deafen(_main)` disabled `_unhandled_input` across the tree
## and PAUSE is an event handler. Only one of the two doors is being opened.
##
## WITH A PLACEABLE SELECTED, LMB BUILDS -- IT DOES NOT MINE. `_effective_aim` returns the raw cell for a
## build and the click goes to placement, so a run reaching this phase holding a pack of stone would quietly
## place blocks and report a DIG distribution over zero breaks. No `try_mine` fixture can meet this, because
## none of them has a hotbar; converting to the real path inherits the hotbar and this hazard with it.
func _arm_real_dig() -> void:
	var slots: Array[Dictionary] = _main.sim.inventory_slots()
	var picked: int = -1
	for si: int in slots.size():
		var item: StringName = slots[si]["item"]
		if _main._machine_defs_by_id.has(item) or item in MainView.BUILD_MATERIALS:
			continue
		picked = si
		break
	if picked >= 0:
		_main._inv_selected = picked
	else:
		printerr("    !! every pack slot is placeable (%d) — holding LMB would BUILD, not mine" % slots.size())
	Controls.deaf = false


## The cell the cursor was aimed at last frame. `_update_mining` breaks on its own clock, so the only honest
## way to count a break is to look at what the previous aim did, one frame later.
var _dig_prev_target: Vector2i = Vector2i(-1, -1)

## Per-phase proof that the phase did the work its name claims; filled by _phase, judged by _workload.
var _work: Dictionary = {}

## The display's refresh interval in ms, 0 if unreported. A machine constant that contention cannot move,
## which is what makes it the yardstick `_load_caveat` holds the quiet frame against.
var _interval: float = 0.0


func _initialize() -> void:
	# Exit 42 AND a reason line: the runner requires both before it will call this a skip rather than a
	# failure. Twelve seconds with a display, one second without; that gap is what made the old quit(0)
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
	# `_unhandled_input` on Controls.PAUSE: KEY_P or JOY_BUTTON_START. `_paused` is the FIRST gate
	# `try_mine` tests, so one stray keystroke, or a joypad that enumerates START, silently pauses the run
	# and every mine for the rest of it returns false with the world in perfect condition.
	#
	# That fits an otherwise unexplained failure: DIG landed 0 of 40 in a sweep, the body correctly
	# placed over 44 rows of solid rock, all six cells beneath it solid, and fifteen isolated runs plus a
	# second full sweep could not reproduce it. It is the only candidate whose intermittency does not depend
	# on the world, which is exactly what ten byte-identical placements demand.
	#
	# `capture_moments.gd` learned this the hard way when an E and a P arrived mid-capture and it
	# photographed the Bazaar modal. It deafens; NO check_* layer did, including this one, and
	# `check_input_deafness` exists to prove the mechanism works while nothing was using it.
	#
	# AFTER a frame, not before: a SceneTree script's `_initialize` runs before the tree is up, so `_ready`
	# is deferred. And Godot re-arms unhandled-input delivery as part of it. Deafen first and `_ready`
	# turns the ears back on behind you.
	Controls.deaf = true
	_deafen(_main)
	await RenderingServer.frame_post_draw

	var player: Player = _main._player
	player.auto_input = false
	# FINISH THE BOOT BAKE BEFORE THE CLOCK STARTS. #17 made the fine bake progressive: a fresh scene paints
	# the visible rect and then fills the rest off-camera at 4ms a frame for about a second. That is real
	# work the game really does. And it happens once, at boot, and never again. A phase that caught the tail
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
	# NOT exempt from the absolute: a game that cannot draw a still frame in 8.33ms does not run at 120.
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

	# THE GATES ARE RECORDED AS ASSERTIONS, NOT ONLY ACCUMULATED INTO A BOOLEAN.
	#
	# This layer decided with `ok`, printed its own sentence and `quit()`, so nothing counted what it
	# asserted and `_verdict()`'s refusal of a green-that-asserted-nothing could never apply to it. `_gate`,
	# `_workload` and `_absolute` each print "      PASS:" and "      FAIL:" lines of their own, which LOOK
	# like assertions and are not: they never touch `_passes` or `_failures`. That is the shape 55 other
	# layers were converted off on 2026-08-23, and it is worse here, because a layer printing PASS-shaped
	# lines that no counter has ever seen is harder to notice than one printing none.
	#
	# The helpers are left exactly as they are and their detail lines stay. `_check` beneath each call is
	# what makes the count real; the terse label names the phase, the helper's own line carries the numbers.
	var run_ms: PackedFloat32Array = await _phase(&"run")
	_check(_gate("RUN   moving, chunks streaming", run_ms, quiet, MOVE_HITCH_RATIO),
		"RUN holds its hitch gate")
	# Stand the body over rock before the clock starts; see _stand_over_rock. Without this the DIG phase
	# inherits wherever RUN happened to stop, which varies by several columns run to run, and lands over a
	# void about half the time.
	var seam: int = _stand_over_rock(_main._player)
	for _s: int in 12:
		await physics_frame                          # let the body settle onto the ground it was placed on
	print("      (dig site: %d rows of solid rock under the body, needs %d)" % [seam, DIG_MINES])
	# until_mines 0: a fixed WINDOW, not a fixed quantity of work. See DIG_MIN_MINES.
	var dig_ms: PackedFloat32Array = await _phase(&"dig", 0, SAMPLE * 2)
	_check(_gate("DIG   mining, region rebakes", dig_ms, quiet, DIG_HITCH_RATIO),
		"DIG holds its hitch gate")
	var swing_ms: PackedFloat32Array = await _phase(&"swing")
	_check(_gate("SWING on the rope at speed", swing_ms, quiet, MOVE_HITCH_RATIO),
		"SWING holds its hitch gate")

	print("  draw calls in the last frame: %d   objects: %d"
		% [int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])

	# BEFORE any verdict about the timings: did the phases do their work at all? A timing distribution
	# gathered while nothing happened is not a slow result or a fast one, it is a mislabelled one.
	_check(_workload(), "every phase did the work it is named for")

	var phases: Array[PackedFloat32Array] = [idle, run_ms, dig_ms, swing_ms]
	_check(_absolute(PackedStringArray(["IDLE", "RUN", "DIG", "SWING"]), phases, quiet),
		"every phase meets the absolute frame SLO, where one applies")

	if _perf_host == "":
		_verdict("check_frametime", "nothing hitches; a dig costs a few quiet frames, not twenty."
			+ " Frame RATE is unasserted here (set SF_PERF_HOST on controlled hardware for that)")
	else:
		_verdict("check_frametime", "nothing hitches, and every phase fits in %.2fms on %s"
			% [FRAME_BUDGET_MS, _perf_host])


## The absolute 120fps budget, and the whole of its refusal to run anywhere it would not mean anything.
##
## Three outcomes, and the middle one is the point: assert it on named hardware; state plainly that it is
## unasserted on everything else; and FAIL on named hardware whose frames are being paced by the display,
## because a vsync-pinned run reports the refresh interval whether the game has four milliseconds of
## headroom or none; passing on that measurement would be the same species of lie as counting a skip as a
## pass.
## A MISSED DEADLINE, which is what "120fps" actually MEANS on a vsync-paced display, and the number this
## layer should have been reporting all along.
##
## Under pacing the frame delta is QUANTISED. A frame that fits presents at the refresh interval; a frame
## that misses waits for the next one and presents at twice it. There is nothing in between. So "is p95
## under 8.33ms" is very nearly unanswerable here: on a paced run p95 IS the interval by construction, and
## a p95 a hair above it does not mean the game is slow; it means roughly one frame in twenty presented
## late. Those are extremely different claims and the old output could not tell them apart.
##
## HOW OFTEN a deadline is missed is answerable, is what a player actually feels, and cannot be faked by
## pacing in either direction. 1.5x the interval is the threshold because there is no legitimate value
## there: a paced frame lands on 1.0x or on 2.0x, so anything past the midpoint waited for another refresh.
##
## This also exists because the alternative on the table was to assert the budget against
## `viewport_get_measured_render_time_cpu`, which reads 0.12-0.16ms on this machine. A gate comparing
## 0.16ms to 8.33ms cannot fail, and would have been vacuity shape 3 (an unreachable floor passing on
## noise), installed in the one place this project has been fighting exactly that. The render-CPU number is
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
## Immediately after the eight runs above, three more read IDLE 41%, RUN 37.5%, SWING 50%, DIG 89.7%.
## Every phase five to ten times worse. That was not the game. `pgrep` found EIGHT Godot processes and a
## load average of 7.64: a neighbouring run was taking captures without holding the harness lock, so
## the eight-run distribution and the three that contradict it were taken on two different computers that
## happen to share a case.
##
## The threshold is therefore NOT SET. A cap derived from data whose provenance collapsed mid-derivation
## is a number with a story, not a measurement, and the honest state of this is "measured twice, disagreed,
## needs a verified-quiet box". Setting one anyway (at 25%, which is where the arithmetic was heading)
## would have shipped exactly the thing this file's own header warns about: a threshold that fails for
## reasons the game did not cause is a threshold someone deletes within a month.
##
## So `_drop_rate` REPORTS and does not assert. Reporting is immune to the contention that ruined the
## derivation: a printed number carries its own conditions, and the reader can see IDLE at 41% and know to
## look at the load average. An assertion cannot do that.
##
## What survives the contamination anyway, because it is a RATIO between phases measured in the same run
## rather than an absolute: DIG misses roughly ten to a hundred times as many deadlines as the phases that
## do no terrain work, on every run, contended or not. That comparison is the finding: the game holds its
## frame rate except when it edits terrain, and it is the shape this layer's ratio gates were built around
## in the first place.
##
## WHOEVER SETS THIS: take it on a quiet box with the harness lock held and `pgrep Godot` returning one
## process, over at least eight runs, and write the distribution here. Do not derive it from a suite run.
const DROP_AT: float = 1.5


## THE FRAME SLO. Two terms, because one of them cannot express what the other measures.
##
## This replaces `p95 <= FRAME_BUDGET_MS`, which was the only 120fps assertion in the project and was
## invalid on the one kind of display it would ever run on. Under vsync a frame lands on 1.0x or 2.0x the
## interval and nothing between, so p95 measures the PACING and not the work -- the section above this
## function has said so in prose since it was written. Turned on for the first time on 2026-08-22 it
## failed all four phases, including RUN at p95 9.46ms with 0.0% of frames missing their slot and a mean
## of 8.31ms. A phase comfortably holding 120fps, marked as under it. That is a false positive, not a bar.
##
## WHY TWO TERMS. `_drop_rate` answers how often a deadline is missed, which is what a player feels and
## which pacing cannot fake in either direction. It is necessary and it is not sufficient: fixing the
## bazaar rescan on 2026-08-22 took the DIG p99 from 30.5ms to 17.1ms, halving how LATE the stalls were,
## and the miss RATE did not move at all -- the same six to eight frames still missed, by less. A contract
## written on rate alone would have scored that fix as nothing. So severity is a term of its own.
##
## THESE ARE RATCHETS, NOT TARGETS, and the distinction is the honest part. Nobody has decided what frame
## behaviour this game owes a player; what the registry holds is measured behaviour with margin, so that a
## REGRESSION is caught while nothing is claimed about what is good enough.
##
## AND THEY ARE PER-HOST, WHICH THEY WERE NOT UNTIL 2026-08-23. Three global constants held them --
## MISS_QUIET 1.0%, MISS_WORKING 6.0%, SEVERITY_X 3.0x -- ratcheted onto five runs of one Mac16,8 and
## applied unchanged to any box whose operator set SF_PERF_HOST. Naming a second machine would have
## asserted the first machine's numbers on it, and the green would have meant "this box behaves like that
## one" while reading as "this box holds the contract". A ratchet is only meaningful over the thing it was
## ratcheted on, and Area 4 asks for exactly the opposite property: a number that means the same thing on
## two machines. They live in `tools/perf_hosts.txt` now, one row per host per phase, each carrying the
## measurement it came from, and a host with no rows is a hard refusal rather than a borrowed default.
##
## The severity bound is worth keeping in view wherever it is written down: at 3.0x the pre-fix bazaar
## rescan FAILS -- DIG worst ran 31.4 to 34.1ms against a 25.0ms bar -- and the fixed build passes at 17.7
## to 20.8ms. A bound that would have caught the largest stall this project has measured, and that clears
## it afterwards.


## The measured machines. See the file's own header for why the allowances cannot be constants.
const PERF_HOSTS: String = "res://tools/perf_hosts.txt"

## Rows for `_perf_host`, {phase: {"miss": float, "severity": float}}, filled by `_load_host()`.
var _host_rows: Dictionary = {}

## Why the registry could not be used, if it could not. Empty means it was.
var _host_error: String = ""


## Read `perf_hosts.txt` and keep the rows for this host. Returns false, with `_host_error` set, on any
## reason the allowances cannot be trusted.
##
## EVERY FAILURE HERE IS A REFUSAL AND NOT A FALLBACK. The tempting shape is "no rows for this host, so
## use the defaults", and the defaults ARE one machine's measurements -- which is the defect this file
## exists to remove, reintroduced as an error path. See `error-path-returns-the-passing-value`: for every
## early return, ask whether it passes or fails.
func _load_host() -> bool:
	var src: String = FileAccess.get_file_as_string(PERF_HOSTS)
	if src.is_empty():
		_host_error = "%s is empty or unreadable, so no host's allowances are available" % PERF_HOSTS
		return false
	var seen_any: bool = false
	var models: Dictionary = {}
	var line_no: int = 0
	for line: String in src.split("\n"):
		line_no += 1
		if line.begins_with("#") or line.strip_edges().is_empty():
			continue
		var col: PackedStringArray = line.split("\t")
		if col.size() < 6:
			_host_error = "%s line %d has %d tab-separated fields, needs 6" % [PERF_HOSTS, line_no, col.size()]
			return false
		seen_any = true
		if col[0] != _perf_host:
			continue
		models[col[1]] = true
		if col[5].strip_edges().is_empty():
			_host_error = "%s line %d sets an allowance with no measurement behind it" % [PERF_HOSTS, line_no]
			return false
		_host_rows[col[2]] = {"miss": col[3].to_float(), "severity": col[4].to_float()}
	if not seen_any:
		_host_error = "%s has no rows at all; the registry parsed to nothing" % PERF_HOSTS
		return false
	if _host_rows.is_empty():
		_host_error = ("SF_PERF_HOST=%s names a machine this repository has never measured." % _perf_host
			+ " Add rows to %s -- five quiet runs, an allowance with margin over the worst reading, and" % PERF_HOSTS
			+ " a sentence saying what you saw. Refusing rather than borrowing another box's numbers.")
		return false
	# ONE HOST, ONE MACHINE. An environment variable travels; the wrong allowances applied silently on
	# uncalibrated hardware is the quietest possible way for this claim to go wrong.
	var here: String = OS.get_model_name()
	if not models.has(here):
		_host_error = ("SF_PERF_HOST=%s was measured on %s and this box reports %s."
			% [_perf_host, ", ".join(models.keys()), here]
			+ " A ratchet means nothing off the hardware it was ratcheted on.")
		return false
	return true


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
		# itself down"; see run_harness.sh:43. It matters here more than anywhere: this is the project's
		# ONLY 120fps assertion, SF_PERF_HOST was unset everywhere for the whole life of the code, and so
		# the budget had never once run while the summary said ALL PASS. An opt-in assertion is fine; a
		# SILENT opt-in assertion is decoration. It can no longer pass without saying it did not assert.
		# THROUGH THE HELPER, and it used to print this line by hand. The text was identical, so the
		# runner's `grep -c '^[[:space:]]*SKIP:'` counted it correctly and nothing was ever wrong -- which
		# is exactly why it survived: the tally rested on two spellings happening to agree. It now carries
		# an id, which the release gate in `tools/stand_downs.txt` keys on.
		_stand_down("frametime.absolute-budget", "the %.2fms/frame (120fps) budget" % FRAME_BUDGET_MS,
			"SF_PERF_HOST is unset, so this is arbitrary hardware and the p95s above are a measurement,"
			+ " not a claim. Set SF_PERF_HOST=<machine-id> on a quiet, controlled box to turn it on.")
		# AND THE OTHER ROW IS NOT STOOD DOWN, IT IS UNREACHABLE, which the registry could not previously
		# distinguish. `frametime.paced-phase` lives inside the loop below and this return is above it, so
		# on an unset SF_PERF_HOST nothing ever DECIDES about it -- reporting that as a stand-down would
		# invent a design decision nobody owes, and reporting it as absent (what happened before) let an
		# `env` row mean nothing in either direction.
		_not_reached("frametime.paced-phase", "_absolute() returns above the phase loop while"
			+ " SF_PERF_HOST is unset, so the paced branch is never evaluated on this machine")
		return true

	var interval: float = _interval

	# A BUSY BOX IS A SPOILED SAMPLE, NOT A FAILING GAME -- AND THIS LAYER CANNOT TELL THE TWO APART.
	# Written down because I shipped a guard that claimed it could, and the guard was wrong.
	#
	# The problem is real. Both terms are ratchets onto behaviour measured on an idle machine; run them
	# while something else owns the box and they measure that instead. Observed here while four unrelated
	# processes held ~100% CPU each at load average 11.3: IDLE 13.5% missed, RUN 38.5%, and RUN 4.5% on the
	# very next run of the same build. A number that moves eightfold between consecutive runs of identical
	# code is not a verdict about the code.
	#
	# THE GUARD I WROTE FOR IT stood the SLO down when the quiet-phase median sat off the refresh interval
	# by more than `VSYNC_PINNED_MS`, on the theory that a quiet box paces on the panel. Checked afterwards
	# against the 146 quiet medians in the retained sweep logs, that guard declines on HALF of all runs:
	#
	#     min 7.37  p05 7.76  p25 8.02  median 8.31  p75 8.34  p95 9.35  max 29.41   (interval 8.33ms)
	#     below the window 55 (38%)  ·  asserts 73 (50%)  ·  above the window 18 (12%)
	#
	# Two faults there, both worth keeping. First, 38% of runs sit BELOW the interval, which is the
	# direction contention cannot produce -- those frames finished early, and `absf()` spent half the
	# budget on a reading that is evidence of health. Second, and fatal: the contended runs measured that
	# day read 8.67, 9.35 and 9.44, while ordinary sweep runs in the same log set read 9.23, 9.31, 9.49,
	# 9.69 and 9.86. The distributions OVERLAP, so no bar on this quantity separates them at all. It was
	# the wrong constant besides -- `VSYNC_PINNED_MS` answers "is this run vsync-pinned", a different
	# question, and its margin against the worst clean reading was 0.01ms.
	#
	# WHY NOTHING ELSE IN REACH WORKS EITHER. The quiet phases' own miss rate is the obvious discriminator
	# and is disqualified twice: it IS the subject of the IDLE term, so a guard keyed on it would stand the
	# assertion down exactly when it was about to fail, and it has false negatives anyway -- the first
	# contended run read IDLE 0.5% / RUN 0.0% while both working phases fell over. A CPU-starvation probe
	# is blind to it too, because what breaks frame pacing on this platform is largely compositor-side:
	# WindowServer was the top process on the box, ahead of any of the hogs.
	#
	# SO THE CONTRACT IS THE OPERATOR'S, WHICH IS WHAT `SF_PERF_HOST` ALREADY MEANS -- setting it is a
	# promise that this is controlled, quiet hardware. The layer cannot verify that promise, so it does not
	# pretend to. It prints the evidence a reader needs in order to classify a red, and lets the red stand.
	# A stand-down that fires on half of all runs is not caution, it is a gate that runs nowhere.
	_asserted("frametime.absolute-budget")

	# THE ALLOWANCES COME FROM THE REGISTRY OR THE RUN FAILS. There is no default and there must not be:
	# the default WAS one machine's numbers, and reinstating it as a fallback would put the defect back on
	# the error path where it is harder to see. A named host with no rows is an operator asserting
	# something this repository has never measured, which is a red rather than a skip -- answering "we have
	# never measured this" with a stand-down files it under "nothing to report".
	if not _load_host():
		printerr("      FAIL: %s" % _host_error)
		return false
	for lab: String in labels:
		if not _host_rows.has(lab):
			printerr("      FAIL: %s has no %s row for the %s phase, so there is no allowance to judge it"
				% [PERF_HOSTS, _perf_host, lab] + " against")
			return false
	print("  absolute: allowances read from %s for host %s (%d phase rows)"
		% [PERF_HOSTS, _perf_host, _host_rows.size()])

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

	# THE SLO NEEDS AN INTERVAL, and without one neither term means anything: "missed its slot" and
	# "three intervals late" are both defined against the refresh. A run that cannot report the refresh
	# has not measured the contract, so it declines rather than passing on a zero.
	if interval <= 0.0:
		_stand_down("frametime.paced-phase", "the frame SLO on %s" % _perf_host,
			"the display did not report a refresh interval, and both SLO terms are defined against it;"
			+ " a rate of frames past 1.5x of nothing is not a measurement")
		return true

	print("  absolute: SF_PERF_HOST=%s — the frame SLO, against a %.2fms refresh. TWO terms: how OFTEN a"
		% [_perf_host, interval]
		+ " deadline is missed (a frame past %.1fx the interval), and how LATE the worst one is," % DROP_AT
		+ " both from %s." % PERF_HOSTS
		+ " Rate alone cannot see a stall getting shallower; severity alone cannot see one getting more"
		+ " frequent. Both are ratchets on measured behaviour, not a claim about what is good enough.")
	var ok: bool = true
	var red: int = 0
	for i: int in labels.size():
		var ms: PackedFloat32Array = phases[i]
		if ms.is_empty():
			printerr("      FAIL: %s produced no samples — the SLO was not measured" % labels[i])
			ok = false
			continue
		var p95: float = _pct(ms, 0.95)
		var drops: float = _drop_rate(ms, interval)
		var worst: float = _worst(ms)
		# NO `.get(..., default)` HERE, DELIBERATELY. A missing phase used to fall back to the quiet
		# allowance, which is a silent decision about the phase this layer knows least about; `_load_host`
		# has already refused a host whose rows do not cover every judged phase.
		var row: Dictionary = _host_rows[labels[i]]
		var allow: float = float(row["miss"])
		var severity: float = float(row["severity"])
		var late_x: float = worst / interval
		print("      %s: %.1f%% missed (allow %.1f%%) · worst %.2fms = %.1fx interval (allow %.1fx)"
			% [labels[i], drops * 100.0, allow * 100.0, worst, late_x, severity]
			+ " · p95 %.2fms, reported and NOT asserted" % p95)
		# NO PACED BRANCH ANY MORE, and its absence is the point. Pacing cannot fake either term: a frame
		# that fits presents at 1.0x and one that misses at 2.0x, so both numbers read the same whether
		# the panel is waiting or the game is. That was the whole reason p95 had to go.
		_asserted("frametime.paced-phase")
		var bad: bool = false
		if drops > allow:
			printerr("      FAIL: %s missed %.1f%% of its deadlines, over the %.1f%% allowed on %s"
				% [labels[i], drops * 100.0, allow * 100.0, _perf_host]
				+ " — a RATE regression: the phase is late more often than it was measured to be.")
			bad = true
		if late_x > severity:
			printerr("      FAIL: %s stalled %.2fms, %.1fx the %.2fms refresh, over the %.1fx allowed"
				% [labels[i], worst, late_x, interval, severity]
				+ " — a SEVERITY regression: something in that phase is doing several frames of work"
				+ " inside one. Profile the phase and not the frame; the last one of these was a"
				+ " full-grid rescan in the sim, and nothing the renderer was doing.")
			bad = true
		if bad:
			ok = false
			red += 1
		else:
			print("      PASS: %s holds the SLO" % labels[i])

	# A RED HERE IS NOT AUTOMATICALLY A DEFECT, and whoever classifies it needs the evidence in the same
	# place as the verdict rather than in a comment forty lines up. This layer cannot decide between a
	# contended box and a slower game -- the note at the top of this function records the discriminators
	# that were tried and why each one failed -- so it hands over the two facts that do separate them in
	# practice, and names the classification as work still owed rather than leaving the red to be dismissed.
	if not ok:
		printerr("      ^ CLASSIFY THIS BEFORE RECORDING IT AS A REGRESSION. %d of %d phases are red, and"
				% [red, labels.size()]
			+ " the quiet-phase reference was %.2fms against a %.2fms refresh." % [quiet, interval]
			+ " A GAME regression is confined to the phase whose code changed and REPEATS on a re-run; a"
			+ " contended box moves unrelated phases together and reads differently the very next run."
			+ " Check what else holds the cores, then re-run: a spoiled sample is void, not failed.")
	return ok


## Its own function because `_pct` indexes a SORTED array and this must not care: the phase buffers reach
## `_absolute` in capture order, and a max read off an unsorted array by index is exactly the kind of
## quietly-wrong number this layer exists to catch.
func _worst(ms: PackedFloat32Array) -> float:
	var out: float = 0.0
	for v: float in ms:
		out = maxf(out, v)
	return out


## THE FASTEST FRAME IN THE RUN, and the reason this function exists is worth more than the function.
##
## The pin test used to be `quiet median ~= refresh interval`, and that is a guard that fires exactly when
## its target is MET. It cannot separate "vsync is holding the game at 120fps" from "genuinely rendering
## at 120fps". On a 120Hz panel both produce a quiet frame of 8.33ms. The first time anyone set
## SF_PERF_HOST, it refused to assert on a run that was not vsync-paced at all, and an evening went into
## planning an OS-level fight that was never needed.
##
## What actually separates the two: under vsync the loop blocks on present, so NO frame can come in faster
## than the refresh interval. A single sample below it is proof the pacing is ours. The evidence that
## settled it was already sitting in the output nobody had read this way: an IDLE median of 8.27ms and a
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


## What share of samples land on a multiple of the refresh interval: the actual vsync signature, and the
## reason the two simpler tests before it both failed.
##
## Test one was `quiet median ~= interval`. It fires exactly when the target is MET, and worse, it cannot
## fire at all once the game is slower than one refresh: forcing vsync on drove the quiet frame to 8.96ms,
## not 8.33, because pacing rounds a too-slow frame UP to the next interval rather than holding it at one.
##
## Test two was `did any frame beat the panel`. That looked decisive (under pacing nothing should present
## faster than the refresh), and it is not: a VSYNC_ENABLED run still produced a 5.65ms sample. A single
## outlier disables the whole detection, which is the worst property a guard can have.
##
## What survives both is CLUSTERING. Paced frames pile up on multiples of the interval; unpaced ones spread.
## Forced on: four phase p95s at 16.56 / 16.51 / 16.61 / 16.59. Forced off: 15.59 / 13.60 / 32.58 / 16.42.
## MEASURED ON THE QUIET PHASE ALONE, and pooling every phase was a real defect in the first version.
## Pacing is only visible where the game is FASTER than the panel: a DIG frame at 33ms is not waiting on
## anything, so its samples land wherever they like and dilute the signal. Pooled over four phases this
## reported 18-39% on a machine an independent profiler measured at 72.5% of STILL frames on a
## multiple, under the 0.6 threshold, so the pooled version said "not paced" about a run that was.
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
## 33-40ms p95 spread on honest runs, wide enough to swallow a real 15% win whole.
func _phase(kind: StringName, until_mines: int = 0, cap: int = SAMPLE) -> PackedFloat32Array:
	var player: Player = _main._player
	var ms := PackedFloat32Array()
	if kind == &"swing":
		_fire_rope()
	if kind == &"dig":
		_arm_real_dig()
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
		# Evidence that this phase did the work its NAME claims, gathered inside the timed loop because
		# that is the only place it is true of the frames actually measured. See _workload.
		moved += player.position.distance_to(prev)
		prev = player.position
		if player.grapple.state == Grapple.State.ANCHORED:
			anchored += 1
	if kind == &"dig":
		# Hand the ears back before anything else runs. A latched MINE would carry a held button into the
		# SWING phase measured immediately after this one.
		Input.action_release(Controls.MINE)
		Controls.deaf = true
		_dig_prev_target = Vector2i(-1, -1)
	player.input_dir = 0.0
	player.input_climb = 0.0
	_work[kind] = {"moved": moved, "mined": mined, "anchored": anchored, "frames": ms.size(),
		"at": _main._cell_at(player.position)}
	ms.sort()
	return ms


## Per-frame input for a phase. Everything here goes through the same fields the keyboard drives, so the
## body does exactly what a player's body would: no teleporting, no synthetic load.
##
## Returns whether this frame did the phase's characteristic WORK; currently only meaningful for dig,
## whose `try_mine` reports success. The return value used to be discarded, which is how a DIG phase that
## mined nothing would still have reported a timing distribution under the name DIG.
func _drive(kind: StringName, player: Player, i: int) -> bool:
	match kind:
		&"run":
			# Reverse periodically so the run stays inside the generated world instead of hitting its edge.
			player.input_dir = 1.0 if (i / 60) % 2 == 0 else -1.0
		&"dig":
			# THE REAL INPUT PATH, not `try_mine`. What stood here called `_main.try_mine(target)` once per
			# frame, which skips `_update_mining` entirely -- and with it the hardness, tool-speed, rhythm and
			# recovery rules that decide WHEN a player's hold is allowed to break a block. Measured against a
			# probe driving the real path in the same world, same tree, three runs:
			#
			#     arm                            broken   blocks/s   p50 ms        p95 ms
			#     direct try_mine                    64       9.15   30.5-32.1     34.5-34.9
			#     the real input path                 8       1.14   16.60-16.63   24.0-25.0
			#
			# The fixture broke blocks EIGHT TIMES faster than the game lets a player break them, so the DIG
			# distribution was the cost of a workload no play can produce. The withdrawn 32-35ms "DIG stall"
			# is almost exactly the direct arm's p50/p95 above.
			#
			# Warping the cursor and holding MINE is safe here for reasons that are each load-bearing:
			#   * `_deafen(_main)` has already cleared `_unhandled_input` across the tree, so the PAUSE key --
			#     the intermittent that once landed DIG 0 of 40 with the world in perfect condition -- cannot
			#     fire whatever `Controls.deaf` says. Polling and events are separate doors.
			#   * `player.auto_input = false`, and Player polls `Controls` only when it is true, so a held key
			#     cannot walk the body out from under the dig.
			#   * this layer QUITS on a headless display (exit 42), so `warp_mouse` is never a no-op when this
			#     code runs, and no stand-down is needed.
			#
			# A break is OBSERVED rather than returned: `_update_mining` finishes on its own clock, so the
			# cell that was solid when it was aimed at is checked on the following frame.
			var broke: bool = _dig_prev_target.x >= 0 and not _main.sim.is_solid(_dig_prev_target)
			var target: Vector2i = _dig_target(player)
			_dig_prev_target = target
			# POSED, NOT WARPED, AND THE TRANSFORM QUESTION GOES WITH IT. This used to build the full
			# `get_final_transform() * get_canvas_transform()` chain and move the real OS cursor every frame.
			# The chain was correct for `Input.warp_mouse`, which takes WINDOW pixels, unlike
			# `Viewport.warp_mouse`, which takes viewport ones and needs only the half chain. This repository
			# has had that pair wrong in both directions on different days. Posing a WORLD point needs neither.
			#
			# The reason it matters here is not tidiness. `_update_mining` re-reads the pointer every frame, so
			# a hand on the physical mouse took the aim off `target`, `_workable` failed, and the phase recorded
			# zero mines while every field of `_report_refusal` read healthy: it prints the INTENDED cell and
			# never the aim, so it cannot tell "the rock refused" from "the aim was moved".
			#
			# NOT claimed: that this explains the historical `DIG landed 0 of 40`. `git log -S warp_mouse` puts
			# the first warp in this file at c844596 on 2026-08-18, and that red was already written down on
			# 2026-08-17, when the DIG arm called `try_mine(target)` directly with no cursor in the path. The
			# mechanism is real and was reachable from the day the warp landed; the old failure is still
			# unexplained and this comment must not be read as having closed it.
			#
			# AND IT MADE THIS LAYER EASIER, WHICH HAS TO BE SAID OUT LOUD. `_drive` is called INSIDE the timed
			# interval (between `last` and `now` below), so the per-frame `warp_mouse` SYSCALL was part of every
			# DIG sample. **The detector was inside the population it measured.** Removing it, same box, same
			# `add_excl` isolation:
			#
			#     DIG p95   12.30ms -> 9.45ms        ratio 1.5x -> 1.1x
			#     IDLE p50   8.30ms -> 8.29ms        the denominator did not move
			#
			# The denominator holding is what makes the drop attributable. **That is the instrument getting
			# cheaper, not the game getting faster**, and every p95 recorded in this file's prose predates it and
			# is no longer comparable. The caps are deliberately NOT retightened on this: it is one run per arm,
			# and a threshold re-derived from a single pair would be the same mistake in the other direction.
			# STILL OPEN: `_arm_real_dig` sets `Controls.deaf = false` for this phase on purpose, so the human's
			# physical mouse BUTTONS remain live on the same `sf_mine` action the fixture is holding. The seam
			# does not close that door, and deafening would defeat what the phase exists to measure.
			Controls.pose_pointer(_main._cell_center(target))
			Input.action_press(Controls.MINE)
			if broke:
				_dig_refusals_running = 0
			else:
				_dig_refusals_running += 1
				if _dig_refusals_running >= STUCK_REFUSALS and not _dig_refusal_reported:
					_dig_refusal_reported = true
					_report_refusal(player, target)
			player.input_dir = 0.0
			return broke
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
## frames of a body standing still and reported the distribution under the name DIG, and reported it as
## 9.36ms p95 against the honest 33.37ms, so the broken fixture looked like a 3.5x performance win.
##
## Searching downward for real rock is what check_dig_hitch already does, for exactly this reason. Bounded
## by DIG_REACH so that a body genuinely standing over a void still fails the workload floor rather than
## silently teleporting its dig to the bottom of the world: the failure must stay visible.
## PERSISTENT refusals, not the first one, and the difference is the whole value of the instrument.
##
## The first version reported the FIRST refusal and was immediately useless: every healthy run refuses once,
## on the frame after a successful mine, when the cell below is the hole you just made and the next solid
## rock is further than the reach. Benign, self-correcting, and it would have consumed the one-shot before
## anything interesting could happen: a diagnostic spent on the normal case is a diagnostic that is not
## there for the abnormal one.
##
## The failure this is for is 400 consecutive refusals. So the trigger is a RUN of them: long enough that a
## body falling between strikes cannot produce it, short enough to fire well before the phase gives up.
const STUCK_REFUSALS: int = 30
var _dig_refusals_running: int = 0
var _dig_refusal_reported: bool = false


## WHY DID `try_mine` SAY NO: asked at the first refusal, answered from the three gates it actually has.
##
## This exists because the failure it is for happened ONCE, in a sweep, and could not be reproduced in
## fifteen isolated runs, a loaded-box arm, or a second full sweep. A defect at that rate cannot be chased
## by re-running; the only affordable move is to make sure the NEXT occurrence arrives with its own answer
## attached. "DIG landed 0 of 40" plus a dig-site print already eliminated placement: the body stood over
## 44 rows of solid rock, so what remains is `try_mine` refusing a target it should have taken, and the
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
	# SIGHT", a two-way guess that was also incomplete, because `_mineable` has a fourth clause. Each gate
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
## Caught by the refusal reporter on a PASSING run (one refusal at (42, 23) with the body at (42, 19),
## four cells away), which is the argument for printing a diagnostic on the first failure rather than only
## when the layer goes red. The run was green; the defect was live; nothing would ever have said so.
##
## Whether this is THE mechanism behind the one 0-mines sweep is not established, and it is not claimed:
## a transient four-cell gap self-corrects as the body falls, and the failing run would have needed the
## body held there for 400 frames. What is established is that the fixture could select an unreachable
## target at all, which is a fixture that can fail for a reason having nothing to do with what it measures.
##
## `floori`, not `roundi`: 3.2 cells of reach means three whole cells, and rounding up would restore the
## bug with a derivation in front of it.
const DIG_REACH: int = int(floor(MainView.REACH_CELLS))

## ASK THE VERB, DO NOT MODEL IT. The scan now tests `_main._mineable(c)` (the exact predicate
## `try_mine` gates on) instead of `is_solid`, which was only ever one of its four clauses.
##
## Deriving `DIG_REACH` from `REACH_CELLS` fixed the gross case (it was a typed 4 against a 3.2 reach) and
## a docstring then claimed the fixture could no longer select a cell the verb was forbidden to service.
## That claim was too strong and this is the retraction. `_can_reach` is a EUCLIDEAN PIXEL distance from
## the body's centre to the cell's centre (main.gd:2439); `dy <= DIG_REACH` is a ROW COUNT. They disagree
## by up to a cell depending on where in its own cell the body is standing: sitting high in row 19, the
## centre of row 22 is ~3.5 cells away and REFUSED, while `dy == 3` waves it through. A row count is not a
## radius, and rounding the radius down does not turn it into one; it only shrinks how often they differ.
##
## And `_mineable` has a fourth clause the proxy never modelled at all: `_bit_bites`, the Wedge grain rule.
## A grain-only bit facing a misaligned seam refuses that cell PERMANENTLY; the body is not falling, so
## nothing self-corrects, and the refusal repeats every frame for as long as the phase runs. That is the
## only mechanism found so far whose signature actually matches the one unreproduced failure (400
## consecutive refusals, body over 44 rows of solid rock). It is NOT claimed as that failure's cause:
## the failing run's bit is not in the record and this fixture has never been seen to equip a grain-only
## one. It is a candidate that the old proxy was structurally incapable of surfacing, which is reason
## enough to stop using the proxy.
##
## `DIG_REACH` survives as the SEARCH BOUND (how far down to look), which is the one job a row count is
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
## when the previous phase handed over, and RUN's stopping point is not stable; measured across runs on
## one machine it varies from 210px to 323px, which is several columns. On roughly half of all runs the
## body finished over a void, nothing was within DIG_REACH, and the phase timed a body standing still.
##
## The workload guard added since catches that and fails the layer, which is correct, and which
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
	# This fixture fails intermittently (40 mines and 37 rows deeper on one run, 0 mines and the body
	# unmoved on the next, same tree), and when it failed there was nothing in the output to tell WHICH
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
## its work (a body that cannot move, mines that all fail, a rope that never takes) and NOT to police
## small changes in how far the fixture happens to travel. A tight floor here would fail on honest fixture
## edits and teach everyone to raise it, which is how a guard becomes a formality.
## DIG'S FLOOR CHANGED SUBJECT WHEN THE PHASE CHANGED ARM. This is not a floor lowered to buy green -- it
## is a floor whose old subject stopped existing.
##
## It read `DIG_MIN_MINES = DIG_MINES` and meant "the phase stops AT 40 mines, so fewer means the cap was hit
## and the fixed work did not complete". Exact and correct FOR A FIXTURE THAT CALLS `try_mine` ONCE A FRAME.
## The real input path breaks blocks at 1.14/s against that arm's 9.15/s, so 40 mines inside a 400-frame
## window is not merely unmet, it is unreachable by playing -- about 2100 frames. A floor nothing can
## satisfy fails every run and guards nothing.
##
## So the phase is now a FIXED WINDOW rather than a fixed quantity of work (`until_mines` is 0, every run
## measures exactly SAMPLE * 2 frames), and the mine count went from being the STOP CONDITION to being the
## workload WITNESS -- which is what the other two arms' floors already are. Strictly better for a timing
## distribution: the old phase ran a VARIABLE number of frames, stopping whenever 40 mines landed at about
## 260, so its sample size moved with dig speed. Now it does not.
##
## Set from measurement, not preference. Seven consecutive runs on the real path landed 10, 12, 10, 10, 11,
## 11, 10 mines in 400 frames. The floor is 6 -- 40% below the observed minimum, the same "leave room for
## honest fixture drift" reasoning the RUN floor above is written from, and far enough under that a run has
## to be genuinely not-mining to trip it. PROVEN ABLE TO FAIL: with the MINE hold removed the phase lands 0
## and this reddens by name, exit 1.
const RUN_MIN_PX: float = 100.0
const DIG_MIN_MINES: int = 6
const SWING_MIN_ANCHORED: int = 100
func _workload() -> bool:
	var run_moved: float = float(_work.get(&"run", {}).get("moved", 0.0))
	var dig_mined: int = int(_work.get(&"dig", {}).get("mined", 0))
	var swing_anchored: int = int(_work.get(&"swing", {}).get("anchored", 0))
	print("  workload: RUN moved %.0fpx · DIG landed %d mines in %d frames (window) · SWING anchored"
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
		printerr("      FAIL: DIG landed %d mines in its %d-frame window, under the floor of %d — the phase"
			% [dig_mined, SAMPLE * 2, DIG_MIN_MINES]
			+ " was not meaningfully mining, so this distribution is a picture of standing still under the"
			+ " name DIG")
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


## WHAT A READER HAS TO CHECK BEFORE BELIEVING A RED RATIO, and the negative result behind it, which is
## the more useful half and is written here because deleted code leaves no trace of what it cost to learn.
##
## THE HEADER'S CENTRAL CLAIM IS WRONG AND HAS BEEN CORRECTED ABOVE. It said "both move the quiet frames
## and the busy frames together, so the RATIO between them survives what the absolute numbers do not". The
## counterexample: this layer passed standalone three times (quiet 8.57/8.06/8.01ms, RUN 1.2-1.8x) and
## FAILED inside a sweep at RUN 2.1x against a 2.0x cap, on a quiet frame of 10.51ms.
##
## A DETECTOR FOR IT WAS ATTEMPTED AND IT DOES NOT WORK. The idea was sound on its face: measure the
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
## SUSTAINED LOAD SCALES THE WHOLE DISTRIBUTION UNIFORMLY. The contended runs are not noisier in shape;
## their p95/p50 is indistinguishable from an idle box's. They are the same distribution multiplied by
## 2.4. So nothing INTERNAL to a run separates "this box is loaded" from "this box is slow", and every
## detector of that family is dead on arrival, not just the one attempted. A drift threshold would have had
## to sit between 1.13 and 1.17 (inside the run-to-run noise of the idle box), which is vacuity shape 3,
## a floor no configuration reliably reaches, and it would have shipped in the one file that warns about
## shape 3 twice, one commit after writing a strike about not doing that. It is deleted rather than tuned.
##
## WHAT THE RATIO ACTUALLY IS, then, stated correctly: a PARTIAL correction for machine load, not an
## invariant. It absorbs load for cheap phases (RUN read 1.4x contended, inside its idle-box 1.1-1.6x
## range) and fails to absorb it for expensive ones (DIG 3.9-4.4x idle, 4.7-6.7x contended, on one commit).
## A longer frame has more wall-clock in which to be descheduled, so the numerator pays more for contention
## than the denominator does, and the more expensive the phase the worse the correction holds.
##
## THE ONLY DEFENCE IS THE PROTOCOL, which is why `tools/with_machine.sh` exists (`0cdb36a`):
## anything that boots Godot takes the machine lock. This function is what is left over; it cannot stop a
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


## Report a phase and gate its p95 against the quiet frame. p95, not p99; see the header: the top one
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


## Clear every input door on every node (`_input`, `_unhandled_input`, `_unhandled_key_input`) plus the
## POLLING path via `Controls.deaf`, which the callback flags do not touch. Recursive rather than naming
## MainView, because the HUD and anything added later have doors too and a list of them would rot. Lifted
## from `capture_moments.gd`, which is the only tool in the repo that had this right.
func _deafen(n: Node) -> void:
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	for c: Node in n.get_children():
		_deafen(c)
