extends "res://tools/check_base.gd"

## THE SESSION HAS TO HAVE A SHAPE. THE GAME IS NOT ALLOWED TO GO QUIET.
##
## Every other layer in this harness measures a MOMENT: does the body step up, does the rock read, does the
## swing land, does the arc complete. None of them measures the thing the word "addicting" is actually about,
## which is what the minutes feel like end to end — whether the game keeps handing you something, or whether
## there are stretches where you are just... doing it, and nothing answers.
##
## So this plays a real session and writes down the NEWS. An event here is anything the game itself tells
## the player, through a channel the player can actually perceive: an objective ticks over, a stratum is
## announced, a kind of thing enters your hands for the first time, a machine goes down, a tech opens, the
## depth record moves. Not internal state changes — things with a plate, a sound, a slot, or a light.
##
## Two numbers come out, and they fail in opposite directions:
##
##   THE LONGEST SILENCE — measured as a SHARE of the session, not in seconds. An agent plays six times
##       faster than a person, so absolute gaps here would only be measuring the agent; a share is scale
##       free, and a dead stretch is dead at any speed. This is the one that catches "I dug for ages and
##       nothing happened."
##   THE DENSITY — events per thousand frames. Catches the opposite failure: a session that never goes
##       quiet for long because it is uniformly thin, dribbling out one small thing at a time. A game can
##       be evenly paced and still have nothing in it.
##
## The session played is the real one: the first-automation arc (tools/arc_driver.gd — the SAME opening
## check_loop_health scores) and then the descent that follows it, which is where the game is most likely
## to go quiet and where the strata are. No fixture, no shortcut, no dev kit.
##
##   godot --headless --path . --script res://tools/check_pacing.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const ARC := preload("res://tools/arc_driver.gd")

## ACT TWO — how deep the descent that follows first automation goes, and how long it gets. Row 62 is into
## THE LONG DARK: it crosses three announced strata, which is what a player who decides to "go down" for a
## few minutes actually does.
const DESCENT_ROW: int = 62
const DESCENT_BUDGET: int = 6000

## Mirrors `PlayAgent.ARRIVE_SLACK`: the body settles a couple of rows above the deepest cell it cut,
## because `_cell_at` reports the centre and the miner stands ON the floor.
const ARRIVE_SLACK: int = 3

## Every this many rows of new personal depth counts as news — the depth readout moving is the quietest
## real signal the game has, and it is what keeps a long dig from being a blank.
const DEPTH_STEP: int = 6

## THE CAPS, ratcheted to what this build actually measures. The play is deterministic — three consecutive
## runs landed on the same frame counts to the frame — so these can sit close without flaking, and they
## should be RATCHETED whenever the shape genuinely improves, the way the friction ceilings are.
## Measured 2026-08-16: longest silence 15%, density 30.6 (26.6 before the earth was made worth digging
## through and the pick was given a beat for finding a seam — see tools/check_richness).
const QUIET_SHARE_CAP: float = 0.20   ## no single silence may be this much of the whole session
const DENSITY_FLOOR: float = 24.0     ## events per 1000 frames, across the session

const BAR: int = 76                   ## characters of printed session shape

## The timeline, and the last-seen state each event is derived from.
var _events: Array[Dictionary] = []
var _f0: int = 0
var _seen_steps: Dictionary = {}
var _seen_items: Dictionary = {}
var _seen_machines: int = 0
var _seen_band: int = -1
var _seen_depth: int = -9999
var _seen_research: bool = false
var _seen_current: StringName = &""
var _seen_hail: bool = false
var _seen_veins: int = 0


## Ticks inside the live tree so the session is sampled every physics frame, not only at the points the
## driver happens to come up for air.
class Sampler extends Node:
	var on_frame: Callable
	func _ready() -> void:
		process_priority = 1000
	func _physics_process(_delta: float) -> void:
		if on_frame.is_valid():
			on_frame.call()


func _initialize() -> void:
	print("== the shape of a session ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_pacing: PASS — the session keeps talking")
		quit(0)
	else:
		print("check_pacing: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:
		await physics_frame
	var agent: PlayAgent = AGENT.new(self, main)

	_f0 = Engine.get_physics_frames()
	_seed(agent)
	var sampler := Sampler.new()
	sampler.on_frame = func() -> void: _sample(agent)
	main.add_child(sampler)

	# ACT ONE — the opening, exactly as check_loop_health plays it.
	var arc_ok: bool = await ARC.new().play(agent, main._objectives)
	var act1: int = Engine.get_physics_frames() - _f0

	# ACT TWO — and then you go down. The player's own answer to "what now": pick a column and dig.
	var col: int = main._cell_at(agent.player.position).x
	# `descend_to`, NOT `dig_down_to` — and the difference is this layer's whole validity. This call used to
	# pass contract one ("make the cell not solid") and DISCARD the result, while every number below is
	# about a session that contains a descent. On any world where row 62 is already open — a cave, a void,
	# an old shaft — contract one returns true on its first iteration having dug nothing and gone nowhere,
	# and act two becomes a walk to a column. The silence share and the density would still be computed,
	# still printed under the words "descent %d", and still pass. `play_agent.gd` names timing a descent as
	# its example of contract two, and this layer sat two files away doing the opposite.
	var from_row: int = main._cell_at(agent.player.position).y
	var sank: bool = await agent.descend_to(Vector2i(col, DESCENT_ROW), DESCENT_BUDGET)
	var reached: int = main._cell_at(agent.player.position).y
	var total: int = maxi(1, Engine.get_physics_frames() - _f0)
	sampler.queue_free()

	# --- the shape ----------------------------------------------------------------------------------
	print("  played %d frames (opening %d, descent %d to row %d of %d) and the game said %d things:"
		% [total, act1, total - act1, reached, DESCENT_ROW, _events.size()])
	for e: Dictionary in _events:
		print("    %5d  %s" % [int(e["at"]), str(e["what"])])
	print("    %s" % _shape(total))
	print("           ^ one column per %.0f frames; | = the game said something" % (float(total) / float(BAR)))

	_check(arc_ok, "the session is playable at all (the opening reached first automation)")
	# VETO, before any ratio is computed. A share and a density are statements about a session of a given
	# SHAPE; if act two did not happen, they are true statements about a different session than the one this
	# layer claims to have played. Reporting them anyway is how a gauge keeps passing while the thing it
	# measures stops occurring — so this returns rather than warns.
	# The veto is a DEPTH FLOOR, not `sank`, and the difference is a hole I found by trying to break this.
	# `PlayAgent._arrived` is one-sided — `body.y >= cell.y - ARRIVE_SLACK` — so it is satisfied by a body
	# that is already BELOW the target. Aim act two at a cell that is open and overhead and contract two
	# returns TRUE having moved nobody: measured, descent 0 frames, body parked at row 19, "arrival"
	# granted. A veto resting on that would have inherited the same blind spot from one file away, which is
	# precisely how this layer got into trouble the first time.
	var dropped: int = reached - from_row
	_check(sank and reached >= DESCENT_ROW - ARRIVE_SLACK,
		"the descent this layer times ACTUALLY HAPPENED (row %d → %d, %d rows, asked for %d)"
		% [from_row, reached, dropped, DESCENT_ROW])
	if not (sank and reached >= DESCENT_ROW - ARRIVE_SLACK):
		printerr("    ...so the silence and density below would describe a session with no descent in it.")
		return
	_check(not _events.is_empty(), "the game says something during a session")
	if _events.is_empty():
		return

	# A silence runs from one event to the next, and the two ends count: booting into nothing and finishing
	# into nothing are both real silences a player sits through.
	var worst: int = 0
	var worst_at: String = ""
	var prev: int = 0
	var prev_what: String = "the session began"
	for e: Dictionary in _events + [{"at": total, "what": "the session ended"}]:
		var gap: int = int(e["at"]) - prev
		if gap > worst:
			worst = gap
			worst_at = "%s → %s" % [prev_what, str(e["what"])]
		prev = int(e["at"])
		prev_what = str(e["what"])

	var share: float = float(worst) / float(total)
	var density: float = float(_events.size()) * 1000.0 / float(total)
	print("  longest silence %d frames = %.0f%% of the session  (%s)" % [worst, share * 100.0, worst_at])
	print("  density %.1f events / 1000 frames" % density)

	_check(share <= QUIET_SHARE_CAP,
		"no stretch of the session is dead air (%.0f%%, cap %.0f%%)" % [share * 100.0, QUIET_SHARE_CAP * 100.0])
	_check(density >= DENSITY_FLOOR,
		"...and it is not thin either (%.1f events/1000f, floor %.1f)" % [density, DENSITY_FLOOR])

	main.queue_free()
	await physics_frame


## Everything the game has ALREADY told you the instant you gain control — the pickaxe in the hotbar, the
## ruined forge on the hillside, the band you spawned in. None of it is news; a session that opened by
## reporting its own initial conditions would score itself a flurry it never delivered.
func _seed(agent: PlayAgent) -> void:
	var sim: FactorySim = agent.sim
	for item: Variant in sim.inventory:
		_seen_items[item] = true
	_seen_machines = sim.machines.size()
	_seen_research = sim.is_researched(&"automation")
	_seen_current = agent.main._objectives.current_id() if agent.main._objectives != null else &""
	_seen_hail = agent.main._line_hailed
	_seen_veins = agent.main.veins_struck
	var row: int = agent.main._cell_at(agent.player.position).y
	_seen_band = Strata.band_at(row)
	_seen_depth = row


## One frame of the session, read only through surfaces the PLAYER is shown.
func _sample(agent: PlayAgent) -> void:
	var main: MainView = agent.main
	var sim: FactorySim = main.sim

	# The objective ladder talks TWICE per step and both halves are on screen: the tick when one completes,
	# and the new line of text that replaces it. A step that completes into a fresh instruction is the
	# game handing you the next thing to want, which is the single most direct answer to "what now?".
	var obj: Objectives = main._objectives
	if obj != null:
		for step: Dictionary in obj.steps:
			var id: StringName = step["id"]
			if obj.is_done(id) and not _seen_steps.has(id):
				_seen_steps[id] = true
				_note("objective ✓ %s" % id)
		var now: StringName = obj.current_id()
		if now != _seen_current and not obj.all_done():
			_seen_current = now
			_note("now: %s" % str(obj.steps[obj.current_index()]["goal"]).to_lower())
	if not _seen_hail and main._line_hailed:
		_seen_hail = true
		_note("★ THE LINE RUNS")
	# Striking a seam is the best thing that happens while digging, and until the game marked it this
	# instrument could not see it: meeting more of a material already in the pack produced no event at
	# all, so enriching the entire world moved the session timeline by exactly nothing.
	if main.veins_struck > _seen_veins:
		_seen_veins = main.veins_struck
		_note("struck a vein (%d this session)" % _seen_veins)

	for item: Variant in sim.inventory:
		var key: StringName = item
		if int(sim.inventory[key]) > 0 and not _seen_items.has(key):
			_seen_items[key] = true
			_note("first %s in hand" % key)

	if sim.machines.size() > _seen_machines:
		_seen_machines = sim.machines.size()
		_note("a machine goes down (%d placed)" % _seen_machines)

	if not _seen_research and sim.is_researched(&"automation"):
		_seen_research = true
		_note("AUTOMATION opens")

	# The stratum plate, gated exactly as MainView._note_stratum gates it: the FIRST time this session the
	# player descends into a band, once, and never on the way back up. Counting raw band changes instead
	# would have scored fourteen announcements in the opening — the surface boundary runs through the row
	# you walk on, so it toggles constantly — for a plate the player is shown once. An instrument that
	# credits the game for banners it does not raise is worse than no instrument.
	var row: int = main._cell_at(agent.player.position).y
	var band: int = Strata.band_at(row)
	if band > _seen_band:
		for b: int in range(_seen_band + 1, band + 1):
			_note("▼ %s" % Strata.BANDS[b]["name"])
		_seen_band = band
	if row >= _seen_depth + DEPTH_STEP:
		_seen_depth = row
		_note("%d metres down" % Strata.depth_m(row))


func _note(what: String) -> void:
	_events.append({"at": Engine.get_physics_frames() - _f0, "what": what})


## The session as one printed strip, so the shape is legible at a glance in harness output and a dead
## stretch looks like what it is: a run of nothing.
func _shape(total: int) -> String:
	var cols: PackedStringArray = PackedStringArray()
	cols.resize(BAR)
	cols.fill(".")
	for e: Dictionary in _events:
		cols[clampi(int(float(e["at"]) / float(total) * float(BAR)), 0, BAR - 1)] = "|"
	return "".join(cols)
