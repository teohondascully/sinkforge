extends "res://tools/check_base.gd"

## DOES THE SAPLING LESSON ACTUALLY WAIT FOR GROUND THAT WOULD TAKE A SAPLING?
##
## `UI-02` gave one lesson a relevance gate. *"RMB plants it on grass"* is an INSTRUCTION, and an
## instruction with nowhere to point is just words on the screen; it used to arrive on the pickup wherever
## the player happened to be standing and run its nine seconds out over a rock face. So the bubble now
## waits in the queue until `main.gd` pokes `note_relevant(SAPLING_GATE, ...)` true, which happens only
## while the cursor is on a cell `can_plant_sapling` accepts and the body can reach it.
##
## `check_teaching` already asks whether the lesson FIRES and whether it is said ONCE. Neither question can
## see the gate: a gate wired to a constant `true` fires exactly the same lesson at exactly the same moment
## and passes that layer whole, and a gate wired to a constant `false` removes the lesson entirely while
## every acquisition assertion over there keeps passing, because the latch is written at FIRE time and
## `check_teaching` reads the latch, not the screen. **The two failure modes of a gate are invisible to
## every layer that only asks whether the lesson exists.** So this one asks the other question, and it has
## to ask it in BOTH directions inside one run: a layer that only proves the bubble arrives is satisfied by
## a gate that is not there at all, and a layer that only proves it is held is satisfied by a gate that
## never opens. Either half alone is a green light over the bug it was written for.
##
## THE FOUR PHASES, in this order, because the lesson latches the moment it is shown and there is exactly
## one chance to watch it being held:
##
##   HELD, WRONG GROUND    cursor in reach, on an open cell whose floor is STONE. `can_plant_sapling`
##                         refuses; the bubble must stay in the queue. This is the rock face from the
##                         ticket, and it is the one the old build got wrong.
##   HELD, OUT OF REACH    cursor on a cell that WOULD take a seed (`can_plant_sapling` says yes) parked
##                         far enough out that `_can_reach` says no. The reach term is `main.gd`'s own
##                         addition ("the sim owns no avatar") and no sim-level test can see it.
##   HELD, EMPTY PACK      cursor on the good cell, in reach, with the seed taken back out of the pack.
##                         The third conjunct, isolated the same way.
##   SHOWN                 cursor on the good cell, in reach, seed in the pack. The bubble arrives.
##
## Each negative satisfies the other two conjuncts, so a phase that holds tells you WHICH term did the
## refusing rather than merely that something did: a control that travels inside the measurement instead
## of beside it.
##
## AND THEN THE FIFTH, which is the design decision `hints.gd` argues for at length and which a naive
## repair of either failure mode would break: the gate gates ARRIVAL, not DISPLAY. Once the bubble is up,
## walking the cursor back off the soil must not take it away: *"the cursor moves every frame of normal
## play, so the bubble would strobe as the aim crossed the edge of the soil, and a lesson explaining where
## to point cannot flicker every time you point somewhere."* A layer that proved only the first four would
## be perfectly happy with a build that suppressed the display on the same flag.
##
## EVERYTHING IS DRIVEN THROUGH THE REAL PATH. The cursor is posed with `Controls.pose_pointer`, which is
## the seam the game already reads its aim through, so `_process` re-derives `_aim` from it and `main.gd`
## computes the gate from the same `can_plant_sapling` the click obeys. **The one field this layer never
## writes is `Hints._relevant`**: it is the subject, and it is also recomputed every `_process`, so a
## fixture that assigned it would have posed nothing and photographed a note left for a frame that was
## never read (`check_posed_fields` is the standing guard for that class). The pack, the queue and the
## ground are set up directly; the gate is only ever read.
##
## SEED-BLIND ON PURPOSE, AND THEREFORE NOT A SEED-CORPUS LAYER. `docs/HARNESS_LAYERS.md` is explicit that
## a layer building its own fixture must stay out of `tools/seed_corpus.sh`, because its columns come out
## identical on every seed and the corpus would count that as coverage it does not have. The shelf here is
## carved rather than found precisely so that "the gate opened" cannot depend on what the terrain happened
## to put under the cursor: the subject is a boolean in a controller, not a landscape.
##
##   godot --headless --path . --script res://tools/check_hint_gate.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40                ## physics frames for the body to fall onto the shelf and stop

## THE SITE IS BUILT, NOT FOUND, and it is built OFF the spawn plateau on purpose. Columns 39-58 are the
## tutorial cluster (bazaar, forge, starter vein, tree, coal, mineshaft) and three of those put a machine
## or a trunk in cells this layer needs open. A fixture that quietly lands on the forge would fail its own
## preconditions with a message about saplings.
const SITE_COL: int = HeightmapWorldGen.BASE_PAD_END + 6
## How far out the out-of-reach cell sits. `_can_reach` is 3.2 cells, so 10 is not merely over the line: it
## is past TWICE the reach, which is the number that matters. Inside 2x, `_effective_aim`'s fallback can
## find a solid cell that is within reach of the body AND within a reach-radius of the cursor, and would
## snap the aim onto it; the phase would still hold, but it would be holding because the aim moved to a
## solid block rather than because the reach term refused. That is the wrong reason with the right result,
## which is the shape this repository keeps finding. Asserted below rather than trusted.
const FAR_DX: int = 10
const SPAN_PAD: int = 4               ## columns of shelf carved either side of the cells under test
const CHAMBER_UP: int = 10            ## rows of headroom carved above the shelf floor
## The natural surface wanders by a row or two out here, and the shelf is levelled to the LOWEST of it, so
## the carve has to be deep enough to clear the highest. Three rows of slack over the measured spread.
const RELIEF_SLACK: int = 3

## How long a lesson is watched NOT arriving. Promotion happens inside a single `Hints.refresh`, so one
## frame would technically do; this is a window wide enough that a human reading the log believes it.
const HOLD_FRAMES: int = 24
## ...and how long it is given to arrive once the situation turns up. Twelve, for `check_teaching`'s
## reason: the gate is poked in `_process` and this layer drives `process_frame`, so a hint asserted on the
## same frame the pose lands is asserting that two orderings happened to agree. Twelve is far inside the
## window and nowhere near it.
const SHOW_FRAMES: int = 12
const ALPHA_FRAMES: int = 30          ## ...and to leave alpha 0 once it is on screen
## The opening TOPSOIL plate owns the announce channel for a few seconds and a queued lesson is HELD while
## it does. A negative phase measured under the ceremony would pass without the gate existing at all.
##
## COUNTED IN PHYSICS FRAMES, AND THAT IS NOT A DETAIL. The plate's life is 3.4 SECONDS, decayed by delta,
## and every other wait in this layer counts PROCESS frames, which is right for them, because promotion
## happens once per `refresh` and the question is how many chances it got. It is wrong here: headless Godot
## runs the process loop as fast as the box will go, so a few hundred process frames can be a fraction of a
## second and the cap would expire with the plate still up. Physics ticks at a fixed 60 Hz, so this cap is
## eight seconds of wall clock no matter whose machine it runs on. `capture_moments` waits out the same
## ceremony the same way.
const CEREMONY_CAP: int = 480

## Assertions ATTEMPTED. `_failures == 0` is the report a layer that asserted nothing also files -- the
## vacuity this repository keeps finding -- so the tally is printed beside the verdict and an exit code
## never has to be taken on trust.
##
## RENAMED FROM `_asserted` BECAUSE THE BASE CLASS TOOK THAT NAME, and the collision is worth a line. A
## member added to `tools/check_base.gd` lands in the namespace of all 86 layers that inherit it, and
## GDScript rejects the SUBCLASS ("the member already exists in parent class") -- so `--check-only` on the
## edited base file is clean and a layer nobody touched stops loading. The runner then reported it as a
## PASS, because `godot --script` exits 0 when a script fails to load; only `tools/harness_verdict.sh`
## caught it, by reading the log rather than the code. Parse-check the SUBCLASSES after touching a base.
##
## The base now counts this itself (`_passes` + `_failures`), so this tally is redundant and could go. Left
## alone deliberately: collapsing it changes what this layer reports, and that is a separate change from
## unbreaking it.
var _attempted: int = 0


func _initialize() -> void:
	print("== the sapling lesson waits for ground that would take a sapling ==")
	await _run()
	# Hand the pointer back whatever happened above. A layer that poses and forgets leaves `Controls._posed`
	# set for anything sharing this process, and `pointer_posed()` exists precisely so that "posed and
	# forgotten" cannot masquerade as a passing hardware test somewhere else.
	Controls.release_pointer()
	print("  %d assertions: %d PASS / %d FAIL" % [_attempted, _attempted - _failures, _failures])
	_verdict("check_hint_gate", "the lesson arrives on plantable ground in reach and on nothing else")


## The base's `_check`, plus the attempt count. Thin on purpose: the pass/fail line, the failure counter and
## the exit protocol all stay where they belong, and only the denominator is added.
func _judge(cond: bool, label: String) -> void:
	_attempted += 1
	_check(cond, label)


func _run() -> void:
	MainView.dev_start = false
	# `_is_scripted_boot()` already keeps the title screen shut under `--script`, so this is the second lock
	# rather than the first. A fixture whose setup depends on how the process happened to be launched is a
	# fixture that breaks the day somebody runs it another way.
	MainView.boot_skip_title = true
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame

	var sim: FactorySim = main.sim
	var player: Player = main._player
	var hints: Hints = main._hints
	_judge(sim != null and player != null and hints != null,
		"the scene came up with a sim, a body and a hint system to drive")
	if sim == null or player == null or hints == null:
		return

	# --- the gate exists in the DEFINITIONS, before anything is driven ---------------------------------

	# `_gate_of` is built once in `Hints._init` from the `when` keys. If the `when` were dropped from the
	# def, `_ready_to_show` would return true for everything and all four phases below would still run:
	# three of them would fail, but they would fail with a story about the cursor. This says it plainly and
	# says it first.
	var gated: int = 0
	for def: Dictionary in hints._defs:
		if def.has("when"):
			gated += 1
	_judge(hints._gate_of.get(&"sapling", &"") == Hints.SAPLING_GATE,
		"the sapling lesson declares the gate %s (it waits on '%s')"
			% [Hints.SAPLING_GATE, hints._gate_of.get(&"sapling", &"nothing")])
	_judge(gated == hints._gate_of.size() and gated >= 1,
		"%d lesson(s) name a `when` and %d made it into the gate table — the two agree"
			% [gated, hints._gate_of.size()])
	# THE OTHER DIRECTION OF THE SAME QUESTION, and it is the control that keeps the three HELD phases
	# honest. A `_ready_to_show` that returned false unconditionally would satisfy every negative below
	# perfectly; only this and the SHOWN phase can tell that apart from a working gate.
	var ungated: StringName = _ungated_id(hints)
	_judge(ungated != &"", "there is an UNGATED lesson to compare against (%s)"
		% ("none — every lesson is gated, so a stuck-shut gate would look like this layer passing"
			if ungated == &"" else ungated))
	if ungated != &"":
		_judge(hints._ready_to_show(ungated),
			"CONTROL: the ungated lesson '%s' is showable with nothing poked relevant" % ungated)

	# --- build the shelf ------------------------------------------------------------------------------

	var span_left: int = SITE_COL - SPAN_PAD
	var span_right: int = SITE_COL + FAR_DX + SPAN_PAD
	var lowest: int = HeightmapWorldGen.ground_row(span_left)
	var highest: int = lowest
	for col: int in range(span_left, span_right + 1):
		var g: int = HeightmapWorldGen.ground_row(col)
		lowest = maxi(lowest, g)      # "lowest" on screen = the largest row index
		highest = mini(highest, g)
	var floor_row: int = lowest
	print("  the natural surface across cols %d-%d runs rows %d-%d; the shelf is levelled to row %d"
		% [span_left, span_right, highest, lowest, floor_row])
	_judge(floor_row - highest <= CHAMBER_UP - RELIEF_SLACK,
		"the carve is deep enough to clear the highest ground on the span (%d rows of relief, %d carved)"
			% [floor_row - highest, CHAMBER_UP])

	# MINED WITH `keep = false`, AND THAT ARGUMENT IS NOT TIDINESS. `mine()` defaults to pocketing what it
	# breaks, and `factory_sim.gd` is explicit that felled leaves hide a sapling: *"a share of leaves hide a
	# sapling, deterministic per cell with no RNG"*. A carve that runs through a worldgen tree would
	# therefore drop a SAPLING into the pack (the exact item whose acquisition edge fires the exact lesson
	# under test), and it would do it before the fixture had established that the pack was empty. The
	# fixture would be firing the subject at itself.
	for col: int in range(span_left, span_right + 1):
		for row: int in range(floor_row - CHAMBER_UP, floor_row):
			sim.mine(Vector2i(col, row), false)
		sim.set_solid(Vector2i(col, floor_row), &"stone")

	var good := Vector2i(SITE_COL + 1, floor_row - 1)      # open, in reach, earth underneath
	var stone := Vector2i(SITE_COL - 1, floor_row - 1)     # open, in reach, STONE underneath
	var far := Vector2i(SITE_COL + FAR_DX, floor_row - 1)  # open, earth underneath, and out of reach
	# `SAPLING_SOILS` is read rather than spelled: the layer must ask for whatever the sim will accept, or
	# it starts testing its own copy of the rule the moment somebody adds a second soil.
	var soil: StringName = FactorySim.SAPLING_SOILS[0]
	sim.set_solid(good + Vector2i(0, 1), soil)
	sim.set_solid(far + Vector2i(0, 1), soil)

	player.auto_input = false            # a body that walks itself walks out of its own reach mid-phase
	player.input_dir = 0.0
	player.grapple.cut()
	player.place(main._cell_center(Vector2i(SITE_COL, floor_row - 3)))
	for _i: int in SETTLE:
		await physics_frame

	_judge(player.on_floor, "the body is standing on the shelf it was dropped onto")
	_judge(main._can_reach(good) and main._can_reach(stone),
		"both in-reach cells really are in reach (%.2f and %.2f of the %.1f-cell limit)"
			% [_reach_cells(main, good), _reach_cells(main, stone), MainView.REACH_CELLS])
	_judge(not main._can_reach(far),
		"...and the far cell really is out of it, at %.2f cells — past twice the reach, so the aim cannot "
			% _reach_cells(main, far) + "snap to a block between the two")

	# --- arm the lesson -------------------------------------------------------------------------------

	# WHAT THE OPENING ALREADY TAUGHT IS CLEARED, NOT LEFT TO CHANCE. Promotion only happens while nothing
	# is on screen (`Hints.refresh`: `if _active == "" and not _queue.is_empty()`), so one leftover bubble
	# from the boot holds the channel for nine seconds and every HELD phase below would pass without the
	# gate doing anything at all. The `_done` latches survive (a lesson already taught cannot re-queue, and
	# that is exactly the quiet this fixture wants) while the sapling's own latch is dropped so its
	# acquisition edge can fire for real.
	hints._queue.clear()
	hints._active = &""
	hints._done.erase(&"sapling")
	# ESTABLISH "YOU DO NOT HAVE ONE" BEFORE ACQUIRING ONE. `Hints._init` snapshots the pack deliberately,
	# so anything held at construction is not a fresh acquisition; `check_teaching` measured a dev kit that
	# already contained a sapling and found the pickup lesson unable to fire at all. Emptying the slot and
	# re-arming the snapshot the way a load does is the state a real opening player is in.
	sim.inventory.erase(&"sapling")
	hints._snapshot()

	# THE CURSOR GOES ON THE ROCK FACE FIRST, before the seed exists, so the very first frame on which the
	# lesson could be promoted is a frame the gate is supposed to refuse. Arming the other way round would
	# let it through and there would be nothing left to watch.
	Controls.pose_pointer(main._cell_center(stone))
	sim.inventory[&"sapling"] = 1
	await process_frame
	await process_frame

	# THE CEREMONY HAS TO BE OFF THE CHANNEL BEFORE ANY OF THIS MEANS ANYTHING. A lesson held by the arrival
	# plate is indistinguishable, from outside, from a lesson held by the gate, and the plate is up at boot
	# for several seconds by design. Waited out through the game's own flag rather than a frame count.
	var waited: int = 0
	while hints._ceremony and waited < CEREMONY_CAP:
		await physics_frame
		waited += 1
	print("  the opening ceremony released the announce channel after %d physics frame(s) (%.1fs)"
		% [waited, float(waited) / 60.0])
	_judge(not hints._ceremony,
		"CONTROL: nothing else is holding the announce channel — a lesson held by the arrival plate would "
			+ "look exactly like a lesson held by the gate")
	# WHY THIS NAMES THE OTHER OUTCOME RATHER THAN JUST COUNTING THE QUEUE. An empty queue has two causes
	# that want opposite repairs: the lesson never fired (a fixture fault: no seed edge, wrong latch), or
	# it fired and went STRAIGHT to the screen because the gate did not hold it. The second is the exact
	# defect this layer exists to catch, and under a gate stuck open it is what actually happens; the
	# mutation run proved it, and the first version of this message read "has FIRED and is waiting in the
	# queue (0 queued)" for it, which points a reader at the acquisition edge instead of at the gate. A
	# failure message that names the wrong half of its own disjunction sends the next person to the wrong
	# file, so the shown-already case is checked first and says so.
	if not hints._queue.has(&"sapling") and hints._active == &"sapling":
		_judge(false,
			"the gate did NOT hold the lesson: it went straight to the screen on the frame it fired, with "
				+ "the cursor still on ground that refuses a seed. This is UI-02's defect exactly, not a "
				+ "fixture fault — the queue is empty because the bubble is already up.")
	else:
		_judge(hints._queue.has(&"sapling"),
			"the sapling lesson has FIRED and is waiting in the queue (%d queued: %s, active: %s)"
				% [hints._queue.size(), ", ".join(_ids(hints._queue)), str(hints._active)])
	if not hints._queue.has(&"sapling"):
		# Without a queued lesson every phase below is a measurement of nothing, and three of them would
		# report green. Stop here rather than file that.
		printerr(("  the lesson is already on screen, so there is nothing left to hold; " if hints._active
			== &"sapling" else "  the lesson never entered the queue, so there is nothing to gate; ")
			+ "the phases below would all pass vacuously and are not run")
		return

	# THE THREE CELLS SIDE BY SIDE, printed before anything is judged. Each negative below satisfies both
	# terms the others refuse on, and that is the whole design of this layer: a reader has to be able to
	# see it rather than take it from the assertion labels.
	var probes: Array[Array] = [[good, "good"], [stone, "stone floor"], [far, "far earth"]]
	for probe: Array in probes:
		var c: Vector2i = probe[0]
		print("    %-12s %-11s in reach: %-5s  plantable: %-5s  %s"
			% [probe[1], str(c), str(main._can_reach(c)), str(sim.can_plant_sapling(c)),
				_refusal(sim, c)])

	# --- HELD: the cursor is on a rock face -----------------------------------------------------------

	_judge(main._aim == stone, "the posed cursor really put the aim on the rock face (aim is %s, wanted %s)"
		% [main._aim, stone])
	_judge(not sim.can_plant_sapling(stone),
		"CONTROL: the sim refuses a seed there — %s" % _refusal(sim, stone))
	_judge(not _gate_open(hints), "...so the controller pokes the gate SHUT")
	_judge(not hints._ready_to_show(&"sapling"), "...and the lesson is not ready to show")
	_judge(await _held_off(hints, &"sapling", HOLD_FRAMES),
		"THE LESSON IS HELD over ground that would not take a seed — the rock face UI-02 was written for")

	# --- HELD: the ground is right and the body cannot reach it ---------------------------------------

	Controls.pose_pointer(main._cell_center(far))
	await process_frame
	_judge(main._aim == far, "the posed cursor put the aim on the far cell without snapping (aim is %s)"
		% main._aim)
	_judge(sim.can_plant_sapling(far),
		"CONTROL: the SIM would take a seed there, so reach is the only term left to refuse")
	_judge(not _gate_open(hints),
		"...and the gate is still shut, which can only be main.gd's own `_can_reach` doing it")
	_judge(await _held_off(hints, &"sapling", HOLD_FRAMES),
		"THE LESSON IS HELD over ground it cannot get to — the half of the rule the sim cannot see")

	# --- HELD: the ground is right, in reach, and the pack is empty -----------------------------------

	Controls.pose_pointer(main._cell_center(good))
	sim.inventory.erase(&"sapling")
	await process_frame
	_judge(not sim.can_plant_sapling(good),
		"CONTROL: with the seed out of the pack the same good cell is refused — %s" % _refusal(sim, good))
	_judge(await _held_off(hints, &"sapling", HOLD_FRAMES),
		"THE LESSON IS HELD when there is nothing to plant, on the very cell that will show it next")

	# --- SHOWN: seed in the pack, cursor on ground that would take it ---------------------------------

	sim.inventory[&"sapling"] = 1
	await process_frame
	_judge(main._aim == good, "the posed cursor put the aim on the plantable cell (aim is %s)" % main._aim)
	_judge(sim.can_plant_sapling(good) and main._can_reach(good),
		"CONTROL: both halves of the situation now hold — a seed in the pack and reachable soil")
	_judge(_gate_open(hints), "...so the controller pokes the gate OPEN")
	_judge(hints._ready_to_show(&"sapling"), "...and the lesson is ready to show")
	var shown: bool = await _await_shown(hints, &"sapling", SHOW_FRAMES)
	_judge(shown,
		"THE LESSON ARRIVES the moment the cursor finds ground that would take the seed (`_active` is %s)"
			% ("'" + String(hints._active) + "'" if hints._active != &"" else "nothing"))
	if not shown:
		return
	var want: String = _def_text(hints, &"sapling")
	_judge(not want.is_empty() and hints.active_text() == want,
		"...and what is on screen is the sapling's own text, not another lesson wearing its slot")
	_judge(hints.active_gate() == Hints.SAPLING_GATE,
		"...and it reports the gate it waited on, so the bubble can be pointed at the cell that opened it")
	# Not a legibility claim: `active_alpha` is a fade envelope and one frame of it is a very small number.
	# What this asks is whether anything is CLAMPING it to zero: the envelope returns a flat 0.0 under a
	# ceremony or a body moving too fast to read, so a lesson that is promoted and drawn at nothing is a
	# lesson the player never got. Reported with the two suppressors beside it so a failure says which.
	var lit: bool = await _await_visible(hints, ALPHA_FRAMES)
	_judge(lit, "...and nothing is clamping it to invisible (alpha %.3f, busy=%s, ceremony=%s)"
		% [hints.active_alpha(), str(hints._busy), str(hints._ceremony)])

	# --- AND IT DOES NOT STROBE -----------------------------------------------------------------------

	# The gate gates ARRIVAL. `hints.gd` argues the alternative down explicitly: suppressing the DISPLAY on
	# the same flag would make the bubble flicker every time the aim crossed the edge of the soil, and a
	# lesson explaining where to point cannot flicker every time you point somewhere. It is also the repair
	# somebody reaching for "make the gate stricter" would write, so it is worth a standing assertion.
	Controls.pose_pointer(main._cell_center(stone))
	var survived: bool = true
	for _i: int in HOLD_FRAMES:
		await process_frame
		if hints._active != &"sapling":
			survived = false
			break
	_judge(not _gate_open(hints),
		"CONTROL: the cursor is back on the rock face and the gate has shut again")
	_judge(survived,
		"...and the lesson already on screen STAYS there — the gate holds arrival, it does not strobe "
			+ "the display")

	main.queue_free()
	await physics_frame


## --- helpers ----------------------------------------------------------------------------------------

## IS THE GATE LIVE THIS FRAME? Read, never written: `_relevant` is the subject and the controller
## rewrites it every `_process`, so a fixture that assigned it would be posing a recomputed field and
## proving nothing.
##
## The `bool()` is not decoration. `Dictionary.get` hands back a Variant, and in GDScript a Variant that
## happens to hold an Array, a Dictionary or a Callable compares `!= null` as TRUE; this repository has
## shipped three guards that could never be false for exactly that reason, one of them an unbounded leak.
## Converting once, here, means every call site is asking a bool a bool's question.
func _gate_open(hints: Hints) -> bool:
	return bool(hints._relevant.get(Hints.SAPLING_GATE, false))


## Watch a lesson NOT arrive, and refuse to call that a result unless there was something to arrive.
##
## THE FAILURE PATH IS THE WHOLE POINT OF THIS FUNCTION. "The bubble did not appear" is satisfied perfectly
## by a hint that was never queued, by a hint system that has been emptied, and by a lesson that latched
## and was consumed two phases ago: three states in which this layer is measuring nothing and would print
## green. So the queue membership is re-checked every frame rather than once, and losing it fails.
func _held_off(hints: Hints, id: StringName, frames: int) -> bool:
	for i: int in frames:
		if hints._active == id:
			printerr("    the lesson reached the screen on frame %d of a window it was meant to sit out" % i)
			return false
		if not hints._queue.has(id):
			printerr("    '%s' left the queue on frame %d — there was nothing left to hold back, so this "
				% [id, i] + "window measured nothing and must not be read as the gate working")
			return false
		await process_frame
	return hints._queue.has(id) and hints._active != id


## Wait a bounded number of frames for a lesson to reach the screen, and say what got in the way if
## something else did. An unbounded wait would hang the box; a wait that returned true on a timeout would
## be the error path handing back the passing value.
func _await_shown(hints: Hints, id: StringName, frames: int) -> bool:
	for i: int in frames:
		if hints._active == id:
			if i > 0:
				print("    (%s reached the screen %d process frame(s) after the situation)" % [id, i])
			return true
		if hints._active != &"":
			# A different lesson holding the channel is not the gate refusing, and the difference matters:
			# one is the subject failing and the other is the fixture failing to clear the stage.
			printerr("    '%s' holds the announce channel, so '%s' could not be promoted — this is the "
				% [hints._active, id] + "fixture's stage, not the gate")
			return false
		await process_frame
	return hints._active == id


## ...and then for it to clear FADE_IN. Separate from `_await_shown` because "promoted" and "drawn" are
## different claims and `active_alpha` can be zero for reasons (a ceremony, a body moving too fast to read)
## that have nothing to do with the gate. Both are reported at the call site.
func _await_visible(hints: Hints, frames: int) -> bool:
	for _i: int in frames:
		if hints.active_alpha() > 0.0:
			return true
		await process_frame
	return hints.active_alpha() > 0.0


## The first lesson that names no gate: the comparison that keeps the HELD phases from being satisfied by
## a `_ready_to_show` stuck shut. Returns &"" when there is none, and the caller fails on that rather than
## skipping it: "every lesson is gated" is itself the state in which this layer stops being able to see.
func _ungated_id(hints: Hints) -> StringName:
	for def: Dictionary in hints._defs:
		if not def.has("when"):
			var id: StringName = def["id"]
			return id
	return &""


## The text a def carries, for comparing against what is on screen. Empty when the id is unknown, which the
## caller must treat as a failure: an empty expectation compared against an empty screen is a match.
func _def_text(hints: Hints, id: StringName) -> String:
	for def: Dictionary in hints._defs:
		if def["id"] == id:
			return str(def["text"])
	return ""


## Which term of `can_plant_sapling` refuses this cell, for the log. PRINTED, NEVER ASSERTED ON: it is a
## second copy of the sim's rule and a second copy is a second thing that can drift, so it explains an
## answer the sim has already given rather than standing in for it.
func _refusal(sim: FactorySim, cell: Vector2i) -> String:
	if not sim.in_bounds(cell):
		return "off the map"
	if sim.solid.has(cell):
		return "the cell is solid rock"
	if sim.grid.has(cell):
		return "a machine stands there"
	if sim.rope.has(cell) or sim.torch.has(cell) or sim.sapling.has(cell):
		return "something is already placed there"
	if int(sim.inventory.get(&"sapling", 0)) <= 0:
		return "no seed in the pack"
	var under: StringName = sim.solid.get(cell + Vector2i(0, 1), &"")
	if not FactorySim.SAPLING_SOILS.has(under):
		return "the floor under it is '%s', not soil" % (under if under != &"" else "open air")
	return "nothing refuses it"


## Distance from the body to a cell, in reach-units, so the log says how much margin a phase had rather
## than repeating the boolean the assertion already carries.
func _reach_cells(main: MainView, cell: Vector2i) -> float:
	return main._player.position.distance_to(main._cell_center(cell)) / float(MainView.CELL)


func _ids(queue: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in queue:
		out.append(String(id))
	return out
