class_name SeatDrive
extends RefCounted

## THE SEAT'S SCRIPTED HAND AND ITS METER TICK (split out of `shell/main.gd` at the file cap, D0397). The
## instrument's half of the seat: `--perf-drive` walks the body so the meter measures a MOVING camera
## (standstill numbers flatter every window-keyed cache, 2026-09-04), `--act=` presses one key for a
## capture, and the meter's physics sample is split by whether the tick ran the hub. A player reaches none of it.
##
## THE NAMED WORKLOADS exist because a still seat and a walking seat were the only two shapes the meter
## could measure, and neither is the shape the director complained about: "the world freezes every single
## time i mine a block", "if i jump down a shaft and go down its like it glitches as it quickly loads
## another part of the world" (2026-09-07). Those are the terrain bake's two hot paths -- a dirty region
## repainted under the hand, and the streaming lane admitting chunks under a fast camera -- and a fixture
## that cannot pose them cannot measure the thing that was wrong.

const STILL: String = "still"
const WALK: String = "walk"
const DIG: String = "dig"
const FALL: String = "fall"
const WORKLOADS: PackedStringArray = [STILL, WALK, DIG, FALL]

## The `fall` cycle, in ticks at 60 Hz: dig from tick 20 of the cycle to `FALL_MINE_UNTIL`, then release
## the hand, then return the body to where the run began and let it fall down its own shaft.
const FALL_CYCLE: int = 480
const FALL_MINE_UNTIL: int = 380
const FALL_DROP_AT: int = 382

## Where the `fall` workload returns the body to, in fixed-point pixels: the position at the first tick,
## before any digging, which is the top of every shaft this run cuts.
static var _fall_from: Vector2i = Vector2i.ZERO
static var _fall_armed: bool = false


## `--unfocused`: the seat's window refuses keyboard focus. PARTIAL, and measured as partial -- the
## window stayed out of the way for the first three or four seconds of a run and macOS then activated the
## process anyway (sampled once a second against `System Events`' frontmost process, 2026-09-08). It is
## kept because those seconds are the ones a boot spends stealing a keystroke mid-sentence, and because
## the flag costs one line; the thing that actually works is hiding the process, which the fixture runner
## does by PID after launch. `--display-driver headless` is not an alternative: it forces the dummy
## rendering driver, and then the terrain bake's SubViewport renders nothing at all.
static func apply_window(flags: Dictionary, win: Window) -> void:
	BakeCost.capture_bursts = bool(flags.get("perf", false))
	if bool(flags.get("unfocused", false)) and win != null:
		win.set_flag(Window.FLAG_NO_FOCUS, true)


## The scripted hand for `--perf-drive` and `--act=`, a pure function of the tick.
static func driven(flags: Dictionary, tick: int, action: StringName) -> bool:
	var act: String = flags["act"]
	if act != "":
		if (act == "mine" or act == "far") and action == Controls.MINE:
			return tick >= 20
		if act == "map" and action == Controls.MAP:
			return tick == 20
		if (act == "settings" or act == "game") and action == Controls.SETTINGS:
			return tick == 20
		return false
	var work: String = String(flags.get("workload", WALK))
	# `still` is a workload and not the bare `--perf` flag, because a workload seat is DEAF to the real
	# keyboard and mouse (`no_digit`, the posed pointer) and a bare `--perf` seat is not. A standstill
	# measured while the machine's owner is using it is the one window a stray keypress can ruin without
	# leaving a mark in the numbers.
	if work == STILL:
		return false
	if work == DIG:
		return action == Controls.MINE and tick >= 20
	if work == FALL:
		return action == Controls.MINE and tick >= 20 and tick % FALL_CYCLE < FALL_MINE_UNTIL
	# THE WALK PATROLS, and does not stream. The world is 256 cells wide and the camera shows 160 of
	# them at play zoom, so a one-way walk crosses it in one window and then stands against the east
	# edge for the rest of the run -- measured: body cell 130 -> 254 by tick 400, then still. There is no
	# sustained horizontal streaming to pose in a world this narrow; the axis that streams is the 1024-cell
	# vertical one, which `dig` and `fall` are for. So this workload measures PAINTERS UNDER A MOVING
	# CAMERA -- which invalidates the window-keyed plane cache (D0340) every tick -- and nothing else.
	if action == Controls.RIGHT:
		return tick % 480 < 240
	if action == Controls.LEFT:
		return tick % 480 >= 240
	if action == Controls.JUMP:
		return tick % 90 < 4
	return false


## True when the scripted hand poses the pointer: every scripted seat, which is all of them that reach
## here. Nothing about a measurement may be left to where the OS happened to leave the mouse.
static func poses_pointer(_flags: Dictionary) -> bool:
	return true


## No digit is held on a scripted seat, whatever the real keyboard says.
##
## THE FIXTURE'S THIRD RUN TAUGHT THIS. A headed seat window takes focus, and `PlayInput.verbs` read
## `Controls.pressed` and `Input.is_physical_key_pressed` -- the REAL hardware -- even when the seat was
## being driven by a script. So the director typing on their own laptop pressed a digit in my
## measurement, `Command.select` changed the held item, and the held item changes what MINE snaps to
## (D0490: "one clay in the pack set BUILD's flag and MINE stopped snapping"). The miner stopped digging
## at the surface and the fixture reported `bake prep=0.000ms/tick` for four consecutive windows -- twice,
## reproducibly enough that I spent two runs testing a stale-script theory that was wrong.
##
## `[[the-human-is-inside-the-measurement]]`. The seat is now deaf to hardware while a script drives it.
static func no_digit(_i: int) -> bool:
	return false


## Where the scripted hand points, in logic pixels. Half a metre ahead and just under the feet for
## `--act=mine` (the ground he is standing on), six metres ahead for `--act=far` (a refused press past
## the reach, D0488) -- and for the digging workloads, a SWEEP across the body's own width.
##
## The sweep is not decoration. A hand that held one point cut a single sub-cell notch under the miner,
## and the game itself said why he then stopped: "a hole has to be a little wider than you before you
## drop in". He mined air for the next six hundred ticks and the fixture reported `bake prep=0.000ms/tick
## chunks=0` for two whole windows -- a workload named `dig` that did no digging, which is `docs/PERF_PLAN.md`'s
## own rule 10 ("prove the fixture did the work it is named for, inside the timed loop") arriving as a
## quiet zero rather than a failure. `DIG_SWEEP` spans 20 logic pixels against a 16-pixel body, so the
## shaft it cuts is wider than the miner and he falls down it.
const DIG_SWEEP: PackedInt32Array = [-10, -5, 0, 5, 10]
## Ticks the pointer rests on one offset. A blow takes several ticks to land, so a sweep faster than the
## swing would charge five cells and break none.
const DIG_SWEEP_TICKS: int = 12


static func feet_aim(flags: Dictionary, body: Body, tick: int) -> Vector2:
	var x: float = float(body.pos_x) / float(Fx.SCALE)
	var y: float = float(body.pos_y) / float(Fx.SCALE) + float(Body.HEIGHT_PX) / 2.0 + 4.0
	var act: String = String(flags["act"])
	if act == "far":
		return Vector2(x + 96.0 * float(body.facing), y)
	if act == "mine":
		return Vector2(x + 8.0 * float(body.facing), y)
	if String(flags.get("workload", WALK)) in [STILL, WALK]:
		return Vector2(x + 8.0 * float(body.facing), float(body.pos_y) / float(Fx.SCALE))
	# THE FLOOR CELLS THEMSELVES, not the row beneath them. `--act=mine`'s +4 aims one terrain cell (4
	# logic pixels) below the feet, which for a capture is the rock in front of the pick and for a shaft
	# is a cell the miner is not standing on: he cut the row under his own floor, kept a one-cell shelf,
	# and the game said "NOTHING THERE" for a thousand ticks while the bake reported zero work.
	return Vector2(x + float(DIG_SWEEP[(tick / DIG_SWEEP_TICKS) % DIG_SWEEP.size()]), y - 2.0)


## The `fall` workload's one scripted act. At the end of each cycle's digging phase the body is PLACED
## back where the run started, so the ticks that follow are a real free fall down the shaft it just cut --
## the camera moving down at the body's own terminal speed through terrain the bake has already painted,
## with new chunks entering the window at the bottom. A dig descends far slower than a fall does, so the
## dig workload cannot pose this even though it also goes down.
##
## NOT A DETERMINISM-SAFE PATH, and it must never be used under a golden: it teleports the body exactly
## as `--warp` does at boot, and the sim did not decide to. It is a measurement pose and nothing else.
static func workload_tick(main: Main) -> void:
	var body: Body = main.door.services()["body"]
	if String(main.flags.get("workload", WALK)) != FALL:
		return
	if not _fall_armed:
		_fall_from = Vector2i(body.pos_x, body.pos_y)
		_fall_armed = true
	elif main.tick % FALL_CYCLE == FALL_DROP_AT:
		body.place(_fall_from.x, _fall_from.y)


## The meter's per-RENDERED-frame sample and the context it keeps for a slow one. Lives here rather than
## in `shell/main.gd` because that file is at its 400-line cap and this one is the instrument's half of
## the seat; `meter_tick` below is its per-sim-tick sibling.
static func meter_frame(main: Main) -> void:
	main.meter.note_process()
	if main.meter.last_was_slow() and main.booted:
		main.meter.note_slow("tick=%d %s" % [main.tick, main.view.draw_cost_report()])


## The meter's physics sample, split by whether this tick ran the hub; a report every 300 ticks.
##
## The window's four lines are the phase split `docs/PERF_PLAN.md` asks for and each is measured by a
## DIFFERENT instrument, which is the point: the frame meter times the frame, the draw phase and the
## host-speed control; `DrawCost` ranks the dynamic painters; `BakeCost` carries the terrain preparation
## and the upload, which no other clock in the build can see (a chunk paints inside a `_draw` callback
## the meter's `draw=` field does not attribute -- a 417 ms mining frame read `draw=0.8`).
static func meter_tick(main: Main, began: int) -> void:
	var frame: Frame = main.view.current_frame()
	var hub: bool = frame != null and frame.obs != null and frame.obs.tick % HubTick.HUB_TICK_DIVISOR == 0
	main.meter.note_physics(Time.get_ticks_usec() - began, hub)
	workload_tick(main)
	if main.tick % 300 == 0:
		var at: Body = main.door.services()["body"]
		# THE BODY'S OWN CELL closes the window, so the runner can assert that the workload moved (or, for
		# `still`, that it did not). Every zero this fixture has produced so far was a workload that had
		# quietly stopped doing its own work, and none of them was visible in a timing number.
		print("WINDOW tick=%d workload=%s body=(%d,%d)" % [main.tick, String(main.flags.get("workload", WALK)),
			at.pos_x / (Fx.SCALE * Interface.Units.CELL_PX), at.pos_y / (Fx.SCALE * Interface.Units.CELL_PX)])
		print(main.meter.report())
		print(main.view.draw_cost_report())
		print(BakeCost.report(300))
		print("BURST " + JSON.stringify(BakeCost.slowest))
		for line: String in main.meter.slow:
			print(line)
		main.meter.reset()
		BakeCost.reset()
