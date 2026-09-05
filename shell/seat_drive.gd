class_name SeatDrive
extends RefCounted

## THE SEAT'S SCRIPTED HAND AND ITS METER TICK (split out of `shell/main.gd` at the file cap, D0397). The
## instrument's half of the seat: `--perf-drive` walks the body so the meter measures a MOVING camera
## (standstill numbers flatter every window-keyed cache, 2026-09-04), `--act=` presses one key for a
## capture, and the meter's physics sample is split by whether the tick ran the hub. A player reaches none of it.


## The scripted hand for `--perf-drive` and `--act=`, a pure function of the tick.
static func driven(flags: Dictionary, tick: int, action: StringName) -> bool:
	var act: String = flags["act"]
	if act != "":
		if act == "mine" and action == Controls.MINE:
			return tick >= 20
		if act == "map" and action == Controls.MAP:
			return tick == 20
		if (act == "settings" or act == "game") and action == Controls.SETTINGS:
			return tick == 20
		return false
	if action == Controls.RIGHT:
		return tick % 480 < 240
	if action == Controls.LEFT:
		return tick % 480 >= 240
	if action == Controls.JUMP:
		return tick % 90 < 4
	return false


## The meter's physics sample, split by whether this tick ran the hub; a report every 300 ticks.
static func meter_tick(main: Main, began: int) -> void:
	var frame: Frame = main.view.current_frame()
	var hub: bool = frame != null and frame.obs != null and frame.obs.tick % HubTick.HUB_TICK_DIVISOR == 0
	main.meter.note_physics(Time.get_ticks_usec() - began, hub)
	if main.tick % 300 == 0:
		print(main.meter.report())
		print(main.view.draw_cost_report())
		for line: String in main.meter.slow:
			print(line)
		main.meter.reset()
