extends "res://tools/check_base.gd"

## Harness layer: LOOP HEALTH, scored (an AUTOMATED proxy for a human early-game playtest). check_agility
## turned "does MOVEMENT feel awkward?" into a number; this turns "does the FIRST-AUTOMATION LOOP feel good
## to play?" into a number. A PlayAgent boots a FRESH game and plays the real RUNG-1 arc (dig ore → smelt →
## chop wood → claim the Bazaar → research → craft → build → fuel → automate) through the same public,
## reach-gated verbs a human drives (try_mine/try_build/try_drop/try_research/…), following the on-screen
## objective ladder (scenes/objectives.gd) exactly like RUNG 1 in play_tests.gd. The arc itself lives in
## tools/arc_driver.gd so this layer and check_pacing are provably scoring the SAME opening.
##
## While it plays it SAMPLES per physics frame and scores three feel-penalties (mirrors check_agility's
## style: a printed breakdown, a ratcheting floor, component caps that a real regression trips):
##   1. COMPLETION, a GATE, not a score: the arc MUST reach first automation within a frame budget, else
##      the whole layer FAILS (the non-negotiable "the loop is playable to its first goal").
##   2. PACE: total frames to completion vs a generous per-step par. Over par → the loop drags.
##   3. FRICTION: stall frames (the body steered/acted but went nowhere) accumulated across the play. The
##      literal "this is awkward" feel, reusing the agent's own stuck_frames instrumentation.
##   4. GUIDANCE-GAP, the KEY new signal: frames where the current objective is UNMET yet the game offers
##      NO reachable world guide target for a step that is SUPPOSED to point somewhere (MainView._guide_targets
##      is empty on a spatial step). That's the "what do I do now?" / lost feeling; weighted heaviest.
##   score = max(0, 100 - pace_pen - friction_pen - guidance_gap_pen).
##
## Real-time physics + heuristic navigation make the numbers slightly noisy, so (like play_tests' friction
## ceilings) the floor keeps generous headroom under the measured baseline. RATCHET the floor UP as the loop
## improves. If the arc can't complete at all, that's a hard FAIL: the loop dead-ended, the worst outcome.
##   godot --headless --path . --script res://tools/check_loop_health.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const ARC := preload("res://tools/arc_driver.gd")     ## the opening, shared with check_pacing


## A tiny sampler Node parented into the live tree so it ticks EVERY physics frame (SceneTree isn't a Node,
## and the arc runs deep inside PlayAgent coroutines with no per-frame hook). Each frame it calls back into
## the check with the live MainView, which reads the same guide-target surface the renderer draws.
class Sampler extends Node:
	var on_frame: Callable
	func _ready() -> void:
		process_priority = 1000        # sample AFTER MainView._process has pushed the frame's guide targets
	func _physics_process(_delta: float) -> void:
		if on_frame.is_valid():
			on_frame.call()

## The steps that MainView is DESIGNED to point at with a world-space guide cell (mine/smelt/wood/bazaar/build
## return a target from _guide_targets; research/craft/fuel/auto are legitimately text-only). A guidance-gap
## frame = the current step is one of THESE yet no target is offered: the game promised a "do it HERE" and
## has none. (A regression that empties the guide overlay lights every spatial frame → the score drops.)
const SPATIAL_STEPS: Array[StringName] = [&"mine", &"smelt", &"wood", &"bazaar", &"build"]

## Frame allowance per objective step at 1× time scale, generous (walking + mining + smelting take real
## time, and each step boots from wherever the last left the body). par = steps × this. The clean run lands
## well under it; the pace penalty only bites when the loop genuinely drags.
const FRAMES_PER_STEP_PAR: int = 700

## Score floor + component caps: headroom under today's MEASURED baseline so real-time variance passes but
## a REGRESSION (the loop drags, the body thrashes, or the game stops signposting) trips the layer. RATCHET
## the floor UP as the loop improves, exactly like the friction ceilings in play_tests. (Ratcheted 2026-08-09:
## floor 70→90: the arc measured 98.7 dead-stable across 3 runs, so a SMALLER dip now trips; 8.7 of margin
## still absorbs the per-frame stall/guidance jitter. The component *_PEN_CAP bounds stay generous CLAMP
## bounds: the SCORE_FLOOR is the meaningful ratchet; tightening the clamps risks flaking the score math.)
const SCORE_FLOOR: float = 90.0       ## baseline 98.7, floor 90.0
const PACE_PEN_CAP: float = 25.0
const FRICTION_PEN_CAP: float = 25.0
const GUIDANCE_PEN_CAP: float = 40.0

## Per-component weights.
const PACE_PEN_PER_OVER: float = 25.0        ## penalty for each 1.0× the frames run OVER par (clamped by cap)
const FRICTION_PEN_PER_STALL: float = 0.10   ## per stall-frame (mirrors check_agility's stall weighting, capped)
const GUIDANCE_PEN_PER_GAP: float = 0.20     ## per lost-frame — the heaviest per-frame weight (the lost feeling)

var _agent: PlayAgent = null

## Per-play sampled tallies (reset each play).
var _guidance_gap_frames: int = 0
var _sampled_frames: int = 0

func _initialize() -> void:
	print("== loop-health check ==")
	MainView.dev_start = false      # score a CLEAN boot (no dev kit) — the real new-player early game
	await _run()
	if _failures == 0:
		print("LOOP HEALTH OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	var agent: PlayAgent = await _boot()
	var obj: Objectives = agent.main._objectives
	# The scored arc runs THROUGH "auto" (first automation); the gentle handoff steps after it are RUNG 2's.
	# Par must reflect the steps actually played, so ask the driver how many of them it will run.
	var step_count: int = ARC.step_count(obj)
	var par: int = step_count * FRAMES_PER_STEP_PAR

	# Install the per-physics-frame sampler INTO the live tree (ticks after MainView pushes its guide
	# targets each frame), so the guidance-gap + sample-frame tallies cover the WHOLE play, not just the
	# outer loop's latch-waits. It reads the same surface the renderer draws (_guide_targets).
	_guidance_gap_frames = 0
	_sampled_frames = 0
	var sampler := Sampler.new()
	sampler.on_frame = func() -> void: _sample(agent)
	agent.main.add_child(sampler)

	# --- play the RUNG-1 arc; the sampler runs every frame throughout --------------------------------
	var frames0: int = Engine.get_physics_frames()
	var completed: bool = await ARC.new().play(agent, obj)
	var frames: int = maxi(1, int(Engine.get_physics_frames() - frames0))
	var stalls: int = agent.stuck_frames
	sampler.queue_free()

	# --- the LOOP-HEALTH SCORE -----------------------------------------------------------------------
	var pace: float = float(frames) / float(par)                          # 1.0 = exactly at par
	var pace_pen: float = clampf((pace - 1.0) * PACE_PEN_PER_OVER, 0.0, PACE_PEN_CAP)
	var friction_pen: float = clampf(float(stalls) * FRICTION_PEN_PER_STALL, 0.0, FRICTION_PEN_CAP)
	var guidance_pen: float = clampf(float(_guidance_gap_frames) * GUIDANCE_PEN_PER_GAP, 0.0, GUIDANCE_PEN_CAP)
	var score: float = maxf(0.0, 100.0 - pace_pen - friction_pen - guidance_pen)

	print("  arc: completed=%s steps=%d  |  frames=%d par=%d pace=%.2fx stalls=%d guidance_gap=%d/%d frames"
		% [completed, step_count, frames, par, pace, stalls, _guidance_gap_frames, _sampled_frames])
	# THE SCORE IS N/A ON AN INCOMPLETE ARC, and the reason is not fastidiousness. `pace` is elapsed frames
	# over FULL-RUN par, so an arc that dead-ends at step 3 elapses very few frames and scores as
	# gloriously fast: the earlier it fails, the better it looks. This layer printed **98.6 / 100** for a
	# run whose arc never completed and whose process exited 1, and that number was then read as evidence
	# that a worktree was ready to merge. Raw diagnostics stay (they are what you debug from); the scalar
	# is withheld, because a scalar computed from a truncated run is not a small error, it is backwards.
	print("  penalties: pace=-%.1f (cap %.0f) friction=-%.1f (cap %.0f) guidance=-%.1f (cap %.0f)  =>  LOOP-HEALTH SCORE = %s"
		% [pace_pen, PACE_PEN_CAP, friction_pen, FRICTION_PEN_CAP, guidance_pen, GUIDANCE_PEN_CAP,
			("%.1f / 100" % score) if completed else "N/A — the arc did not complete"])

	# GATE first: an incomplete arc is a hard fail regardless of the number (the loop dead-ended).
	_check(completed, "the first-automation arc COMPLETES (the loop is playable to its first goal)")

	# AND THE SAMPLER HAS TO HAVE WATCHED IT. Two of the three penalties are per-frame tallies that start at
	# zero and only ever go up, so a sampler that never ticked (freed early, never added, its Node dropped
	# by a refactor) hands back stalls=0 and guidance_gap=0, which is a PERFECT 100 for a play nobody
	# observed. The failure is silent and it moves the score the wrong way, which is the worst combination
	# available: the layer reports its best number ever at the moment it stops measuring, and a ratcheting
	# floor cannot catch a value that went UP. `_sampled_frames` was already printed on the line above and
	# was the only figure here nothing asserted. Measured 2026-08-17: 1099 sampled against 1099 played (
	# exact), so the floor is the played count less the single frame the sampler Node is added on.
	#
	# `> 0` as well as the ratio, and this is the guard applied to itself. `frames` is `maxi(1, …)`, so a
	# play that did nothing reports one frame and `_sampled_frames >= frames - 1` becomes `0 >= 0`: the
	# non-run passing its own attendance check, which is the exact shape this assertion was added to close.
	# It cannot co-occur with `completed` today, and it costs one clause to stop depending on that.
	# NON-VACUITY: an unwatched play scores a perfect 100.
	_check(_sampled_frames > 0 and _sampled_frames >= frames - 1,
		"the per-frame sampler watched the whole play (%d frames sampled of %d played)"
			% [_sampled_frames, frames])

	# THESE THREE USED TO READ `clampf(x, 0.0, CAP) <= CAP`. That is not a test, it is the definition of
	# clampf: three assertions that could not fail, inflating the pass count and making the layer look
	# like it watched three things it never watched. What a cap actually hides is SATURATION: a component
	# pinned at its ceiling has stopped measuring, the total is being carried by the other two, and the
	# score can still clear the floor while one whole dimension of the loop is as bad as it is allowed to
	# get. So the question is not "is it within the cap" (always) but "has it hit the cap" (a real event).
	# Current margins on main are wide (pace 0.0, friction 0.9, guidance 0.4 against caps of 25/25/40),
	# so these bite only on a genuine collapse.
	_check(pace_pen < PACE_PEN_CAP,
		"the pace penalty is not SATURATED (-%.1f of %.0f) — the run is not simply over budget"
			% [pace_pen, PACE_PEN_CAP])
	_check(friction_pen < FRICTION_PEN_CAP,
		"the friction penalty is not SATURATED (-%.1f of %.0f) — the body is not stuck for the whole arc"
			% [friction_pen, FRICTION_PEN_CAP])
	_check(guidance_pen < GUIDANCE_PEN_CAP,
		"the guidance penalty is not SATURATED (-%.1f of %.0f) — the game is not silent about what to do next"
			% [guidance_pen, GUIDANCE_PEN_CAP])
	_check(completed and score >= SCORE_FLOOR,
		"LOOP-HEALTH SCORE %s >= floor %.1f"
			% [("%.1f" % score) if completed else "N/A", SCORE_FLOOR])

	agent.main.queue_free()
	await physics_frame


## Sample the CURRENT-frame feel signal: if the active objective is a spatial step (one MainView is designed
## to point at) but offers no reachable guide cell, that's a "what do I do now?" frame. Read through the same
## public surface the renderer does (_guide_targets), so this measures exactly what the player would see.
func _sample(agent: PlayAgent) -> void:
	_sampled_frames += 1
	var obj: Objectives = agent.main._objectives
	if obj == null or obj.all_done():
		return
	var id: StringName = obj.current_id()
	if id in SPATIAL_STEPS and agent.main._guide_targets().is_empty():
		_guidance_gap_frames += 1


# --- scaffolding ----------------------------------------------------------------------------------

## Boot a fresh game scene and let the body settle, then hand back a PlayAgent driving it.
func _boot() -> PlayAgent:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:                       # _ready runs on add; let the body fall + land
		await physics_frame
	_agent = AGENT.new(self, main)
	return _agent
