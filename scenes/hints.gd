class_name Hints
extends RefCounted

## JUST-IN-TIME teaching: the first time an item that carries a non-obvious USE lands in
## your pack, a small bubble near the body says how to use it — "RMB above a drop: the rope unrolls down
## to you" — exactly when the knowledge is actionable, then never again. It extends the Objectives chain
## (which signposts the tutorial PATH) into the open game: research unlocks a Generator two hours in and
## the game still teaches it, without a manual and without re-nagging veterans.
##
## REPRESENTATION-ONLY, the Objectives pattern: reads the sim (inventory), never mutates it, never enters
## the tick — delete this and every production number is identical. Triggers are ACQUISITION EDGES: an
## item's count crossing 0 → >0 THIS session (a snapshot at construction means a pre-stocked dev pack or
## a loaded save doesn't fire a wall of bubbles at boot; resync() re-arms the snapshot after F9). Shown
## hints LATCH for the session; one bubble at a time, later triggers queue behind it — except a lesson that
## named a relevance gate (SAPLING_GATE), which waits in the queue for its situation and lets the ones
## behind it go first. Not saved — a hint re-teaching once after a fresh boot is fine, spam within a
## session is not.

const SHOW_SECONDS: float = 9.0     ## how long a bubble lingers (long enough to read twice)

## READING TIME, not wall time. The rope hints fire at exactly the moment the player is least able to
## read them — mid-arc at four hundred pixels a second, which is the whole point of firing them there.
## Nine seconds of that is nine seconds of a bubble the player never once looked at, and then it is gone
## and the technique is never mentioned again. So the countdown only runs while the body is calm enough
## to read: the bubble still ARRIVES on the moment it is about to explain, and it waits for the landing.
## Capped, because a bubble that waits forever is a bubble stuck to the screen, and because the queue
## behind it deserves its turn.
const MAX_LINGER: float = SHOW_SECONDS * 3.0
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.6

## The relevance gate a lesson may WAIT on: an optional `when` on a def names a situation id, and the
## bubble is held in the queue until the controller pokes that id true (note_relevant). Acquisition says
## the lesson exists; the gate says the moment has come.
const SAPLING_GATE: StringName = &"plantable_ground"

## The teachable moments, scanned in order (order = priority when several fire the same frame). Each:
## the pack item whose first acquisition triggers it + what the bubble says. Deliberately ABSENT: the
## drill (the Objectives chain teaches it as the tutorial's automation capstone) and recipe machines like
## the forge/iron chain (drop-feed in, product falls out — the one verb the chain already taught).
var _defs: Array[Dictionary] = [
	{"id": &"rope", "item": &"rope",
		"text": "ROPE — RMB above a drop. W/S climbs, SPACE leaps off."},
	{"id": &"torch", "item": &"torch",
		"text": "TORCH — RMB on a wall-backed cell. Its light stays."},
	{"id": &"scanner", "item": &"scanner",
		"text": "SCANNER — RMB pulses. Veins in range echo back."},
	# UI-05, and this is the ticket's own example. "It grows into a NEW TREE: wood is renewable" is a
	# SECOND CONCEPT — an economics claim — competing with the one input instruction the bubble exists to
	# give. It is not deleted; it is moved to `planted`, where it lands on the moment it describes and is
	# a payoff instead of a promise. *One action, one immediate consequence.*
	# UI-02, and the `when` is the whole of it. The pickup told the player a sapling exists; "RMB plants it
	# on grass" is an INSTRUCTION, and an instruction with nowhere to point is just words on the screen —
	# it used to arrive on the pickup wherever the player happened to be standing and run its nine seconds
	# out over a rock face. The gate holds it until there is a seed in the pack and the cursor is on ground
	# that would take one, so the lesson opens on the answer to the question it is asking.
	{"id": &"sapling", "item": &"sapling", "when": SAPLING_GATE,
		"text": "SAPLING — RMB plants it on grass."},
	# Same cut. "Too dense for the Forge" is the immediate consequence of what just entered the pack and
	# answers the question the player is about to ask. The Blast Furnace is a research path, and a research
	# path is a plan rather than a consequence — it belongs on the BENCH, which is where the player goes
	# to make plans.
	{"id": &"rich_ore", "item": &"rich_ore",
		"text": "RICH ORE — too dense for the Forge. Take it to the BENCH."},
	{"id": &"generator", "item": &"generator",
		"text": "GENERATOR — place it, drop COAL on it. It powers what is near."},
	{"id": &"conduit", "item": &"conduit",
		"text": "CONDUIT — RMB lays tube. Power flows down and sideways, never up."},
	{"id": &"hopper", "item": &"hopper",
		"text": "HOPPER — banks what falls in, meters it down. R re-tastes."},
	{"id": &"lift", "item": &"lift",
		"text": "LIFT — hauls goods and YOU up its column."},
	{"id": &"splitter", "item": &"splitter",
		"text": "SPLITTER — routes falling items down and right. R cycles the ratio."},
	{"id": &"h_drill", "item": &"h_drill",
		"text": "BORER — bores sideways, the way you face. Feed it coal."},
	{"id": &"descent_engine", "item": &"descent_engine",
		"text": "DESCENT ENGINE — stand it on the violet seal, then toss " + str(FactorySim.DESCENT_QUOTA)
			+ " ingots down its shaft."},
]

## STATE-EDGE hints (vs the pack-acquisition ones above): a teaching moment triggered by a body/world
## condition rather than picking an item up. The controller pokes each id's condition every frame with
## note(); the RISING edge fires the bubble, exactly once, latched for the session like a pack hint.
##
## Why a table and not a const per hint: the first two of these (water, depth) were written as bespoke
## constants with bespoke edge-detector fields and a bespoke branch in active_text(), which was fine at
## two and became a copy-paste ritual at five. The predicate is the only part that differs between them,
## and the predicate lives in the controller — so what is left here is pure data.
##
## Ordering is priority when several fire on the same frame, and it is deliberate: the rope's three
## techniques sit below the two hazards, because a player who is drowning does not want a movement tip.
##
##   in_water     the AQUIFER. Wading is slowed + buoyant (Player water impedance) with no on-screen
##                reason; this names the L3 loop — a powered Pump drains it — the instant it is actionable.
##   deep_enough  the tool is in the miner's kit from the first frame, which means nothing at all if
##                nobody ever presses F. Ten rows down is where a player stops thinking about the hole
##                and starts thinking about the climb, so that is where the game mentions the winch.
##   pump         THE SKILL CEILING. A shorter line carries the same angular momentum at a higher speed,
##                so reeling at the bottom of an arc winds it up and paying out at the top costs nothing.
##                Fired at the bottom of a fast arc, which is the instant the hands are already there.
##   chain        THE ONE THAT MAKES IT A MOVEMENT SYSTEM. tools/check_traverse measures the rope
##                crossing a gallery half again as fast as a full stride — but only for a player who
##                knows the arc does not have to end. Fired the frame a line is released at speed in
##                mid-air, which is precisely the frame the next throw would have paid off.
##   wrapped      the line has just bent around a corner. Unannounced, that reads as the rope glitching;
##                named, it is the game's sharpest manoeuvre (check_wrap measures 4x the turn rate).
##   hard_landing the fall took your footing (Player.stagger). The hint is not "you fell" — the player
##                can see that — it is that the rope is the answer to a drop you are already in.
var _moments: Array[Dictionary] = [
	{"id": &"in_water",
		"text": "AQUIFER — water slows you. A POWERED PUMP drains it."},
	{"id": &"deep_enough",
		"text": "GRAPPLE — F fires the winch. W reels you up, SPACE leaps off."},
	{"id": &"pump",
		# Was four lines. "A shorter line swings faster" is the MECHANISM — true, and a third concept
		# between the two halves of the input it is explaining. The action and its consequence survive.
		"text": "PUMP IT — reel W at the bottom of the arc, pay S out at the top."},
	{"id": &"chain",
		# "You never have to land" is a slogan, and it arrives BEFORE the instruction that earns it.
		"text": "CHAIN IT — F again in mid-air plants the next line, and the speed you left with "
			+ "is the speed you keep."},
	{"id": &"wrapped",
		# The first clause stays: it explains the thing that just happened on screen, which is the whole
		# reason this lesson exists (unannounced, a wrap reads as the rope glitching). The second control
		# goes — one consequence.
		"text": "THE LINE CAUGHT — it bent around the rock instead of through it. "
			+ "A short line whips you round harder."},
	{"id": &"hard_landing",
		"text": "HARD LANDING — a long drop costs your footing. F on the way DOWN catches you: "
			+ "the line takes the fall instead of your legs."},
	# THE PAYOFF HALF OF THE SAPLING LESSON, and the reason UI-05's cut is a move rather than a deletion.
	# It fires on the first sapling that actually roots, so the claim arrives attached to the thing it is
	# a claim about — a player who has just watched one go into the ground is being told what they now
	# own, not what they might one day do.
	{"id": &"planted",
		"text": "It takes root. Give it time and it is a whole tree — wood is the one thing "
			+ "down here that grows back."},
]

const DEPTH_HINT_ID: StringName = &"deep_enough"
const DEPTH_HINT_ROWS: int = 10     ## rows below the local surface that make the climb a real trip

var sim: FactorySim
var _had: Dictionary = {}           ## item -> true if the pack held it last frame (edge detection)
var _done: Dictionary = {}          ## hint id -> true once shown (latched for the session)
var _queue: Array[StringName] = []  ## fired-but-waiting hint ids (one bubble at a time)
var _active: StringName = &""
var _life: float = 0.0              ## READABLE seconds left on the bubble (frozen while the body is busy)
var _lingered: float = 0.0          ## ...and wall seconds it has been up, which is what MAX_LINGER caps
var _busy: bool = false             ## body moving too fast to read anything (poked by note_busy)
var _ceremony: bool = false         ## the arrival plate owns the announce channel (poked by note_ceremony)
var _now: Dictionary = {}           ## moment id -> condition true THIS frame (poked by note())
var _was: Dictionary = {}           ## moment id -> ...and last frame; the pair is the rising-edge detector
var _relevant: Dictionary = {}      ## situation id -> live THIS frame (poked by note_relevant)
var _gate_of: Dictionary = {}       ## hint id -> the situation it waits for; no entry = shows on arrival


func _init(factory: FactorySim) -> void:
	sim = factory
	for def: Dictionary in _defs:
		if def.has("when"):
			_gate_of[def["id"]] = def["when"]
	_snapshot()                     # what's already in the pack at construction never fires


## The controller pokes each state-edge condition here every frame. These are Player/world predicates
## (wet, deep, airborne, wrapped, staggered) rather than pack items, so they ride poked flags instead of
## an inventory scan — and they live in the controller because that is where the body and the rope are.
## Everything defaults to false until the controller starts playing, so a spawn never fires retroactively.
func note(id: StringName, on: bool) -> void:
	_now[id] = on


## THE CEREMONY OWNS THE CHANNEL WHILE IT IS UP, AND THIS IS `P1`'S ONE RULE MADE ENFORCEABLE.
##
## *Only one primary attention state at a time.* The `P0` baseline caught the two announce systems sharing
## pixels three separate times, and the worst of them costs something real: in
## `docs/media/baseline/_moment_line.png` the first-automation plate — *"IT WORKS WITHOUT YOU / THE LINE
## RUNS"*, the single biggest emotional beat the opening has — is overlapped by a bubble explaining that
## wood is renewable.
##
## THE LESSON IS HELD, NOT DROPPED, and the distinction is the whole design. A queued lesson is not
## promoted while a ceremony runs; an already-active one keeps its text, stops its clock and draws nothing,
## then comes back with its full remaining life. Dropping it would be the cheap version of quietness — the
## screen gets calmer by teaching less — and `UI-04` asks for retirement on DEMONSTRATED USE, not on bad
## timing. Nothing here latches, expires or forgets: the only thing that changes is when it is legible.
func note_ceremony(on: bool) -> void:
	_ceremony = on


## Poked with whether the body is moving too fast to read a bubble. Freezes the active hint's countdown
## rather than its display, so a lesson fired mid-swing is still on screen when the swing ends.
func note_busy(on: bool) -> void:
	_busy = on


## Poked with whether a gated lesson's situation is live right now (SAPLING_GATE: a seed in the pack and
## the cursor over ground that would take it). A LEVEL, not an edge, and it lives in the controller with
## the cursor for the same reason the body predicates do.
##
## It gates ARRIVAL only, and only for a def that named it. Nothing here fires, latches or forgets a
## lesson: the acquisition edge still does that, the queue holds the bubble until the situation turns up,
## and once it is on screen it lives its ordinary life. Suppressing the DISPLAY on the same flag was the
## other option and it is the wrong one — the cursor moves every frame of normal play, so the bubble would
## strobe as the aim crossed the edge of the soil, and a lesson explaining where to point cannot flicker
## every time you point somewhere. UI-03 settled the same argument about speed with hysteresis; the aim
## has no equivalent quiet state to settle into.
func note_relevant(id: StringName, on: bool) -> void:
	_relevant[id] = on


## Can this hint be shown yet? True unless its def named a situation that has not been poked live. The
## `has` is the guard rather than a null test: an absent gate and a gate that is currently false are
## different answers and both have to be reachable.
func _ready_to_show(id: StringName) -> bool:
	if not _gate_of.has(id):
		return true
	return bool(_relevant.get(_gate_of[id], false))


## The wading edge, named. Kept as its own verb because the call site reads better for it.
func note_in_water(wet: bool) -> void:
	note(&"in_water", wet)


## Poked with how far below its own column's surface the body currently is.
func note_depth(rows_below_surface: int) -> void:
	note(DEPTH_HINT_ID, rows_below_surface >= DEPTH_HINT_ROWS)


## Call every frame. Detects acquisition edges, advances the active bubble's life, promotes the queue.
func refresh(delta: float) -> void:
	for def: Dictionary in _defs:
		var id: StringName = def["id"]
		var item: StringName = def["item"]
		var has: bool = int(sim.inventory.get(item, 0)) > 0
		if has and not _had.get(item, false) and not _done.has(id):
			_done[id] = true                          # latch at FIRE time, so a re-acquisition can't re-queue
			_queue.append(id)
		_had[item] = has
	# The state edges, in table order: off → on fires once, latched exactly like a pack hint.
	for m: Dictionary in _moments:
		var id: StringName = m["id"]
		var on: bool = _now.get(id, false)
		if on and not _was.get(id, false) and not _done.has(id):
			_done[id] = true
			_queue.append(id)
		_was[id] = on
	if _active != &"" and not _ceremony:
		# Both clocks stop under a ceremony, not just `_life`. `_lingered` is the cap on how long a frozen
		# bubble may hang around, and a bubble that is not being SHOWN cannot be wearing out its welcome.
		_lingered += delta
		if not _busy:
			_life -= delta          # only calm seconds count as read
		if _life <= 0.0 or _lingered >= MAX_LINGER:
			_active = &""
	if _active == &"" and not _queue.is_empty() and not _ceremony:
		# The first hint whose situation is live, which is the front one unless it is gated and waiting.
		# A gated lesson lets the rest of the queue past rather than blocking it: it is waiting for a
		# situation that may be minutes away, and the hints behind it are about things happening now.
		for i: int in _queue.size():
			if not _ready_to_show(_queue[i]):
				continue
			_active = _queue[i]
			_queue.remove_at(i)
			_life = SHOW_SECONDS
			_lingered = 0.0
			break


## The bubble to show right now ("" = none). The HUD anchors it near the body.
func active_text() -> String:
	if _active == &"":
		return ""
	for m: Dictionary in _moments:
		if m["id"] == _active:
			return str(m["text"])
	for def: Dictionary in _defs:
		if def["id"] == _active:
			return str(def["text"])
	return ""


## The situation the visible lesson is waiting on, or &"" when it shows on arrival and is about nothing in
## particular. A gated lesson is about a PLACE by construction: it is only up because the cursor is over a
## cell that answers its question, so the controller can point the bubble at that cell instead of at the
## body. Ungated lessons have no such place and stay over the miner.
func active_gate() -> StringName:
	return _gate_of.get(_active, &"")


## Fade envelope: 0..1 over the bubble's life (quick in, gentle out).
## UI-03: `_busy` now hides as well as freezes. The clock already stopped while the body was moving too
## fast to read — *"a lesson fired mid-swing is still on screen when the swing ends"* — but leaving it
## DRAWN through the swing is the half that fails the ticket: it is one more thing over the rope at the
## exact moment the rope is the thing to look at, and it was never being read anyway. Frozen and hidden is
## the same promise kept properly; the lesson arrives with its full life the moment the body settles.
func active_alpha() -> float:
	if _active == &"" or _ceremony or _busy:
		return 0.0
	var shown: float = SHOW_SECONDS - _life
	return clampf(minf(shown / FADE_IN, _life / FADE_OUT), 0.0, 1.0)


## UI-04 — WHICH LESSONS HAVE ALREADY BEEN GIVEN, so a save can carry them.
##
## **The latch was per-SESSION, and nothing wrote it down.** `_done` is the "never say this twice" record,
## `resync()` preserves it across an in-process load, and it is rebuilt empty by `_init` on every boot —
## so every state-edge lesson (the grapple, the wrap, the chain, the hard landing, the aquifer, the plant)
## **re-taught itself in full every time the player launched the game.** `check_teaching`'s own standard is
## *"a tip that re-teaches every swing is the reason players learn to ignore tips"*, and this was that
## failure with a longer period — long enough that neither the layer nor a play session could see it,
## because both live inside one process.
##
## Written as a plain id list rather than the dictionary: the file should carry the DECISION ("these have
## been taught"), not this class's bookkeeping, and a list survives the dictionary being restructured.
func taught_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _done.keys():
		out.append(String(k))
	out.sort()                    # stable on disk, so two saves of the same state are byte-identical
	return out


## The mirror. Ids that no longer exist are dropped rather than kept: a lesson deleted from the game must
## not be able to suppress a future lesson that reuses its name, and an unknown id in `_done` would do
## exactly that, silently, forever.
func restore_taught(ids: Array) -> void:
	var known: Dictionary = {}
	for d: Dictionary in _defs:
		known[d["id"]] = true
	for m: Dictionary in _moments:
		known[m["id"]] = true
	for v: Variant in ids:
		var id := StringName(String(v))
		if known.has(id):
			_done[id] = true


## Re-arm the acquisition snapshot to the CURRENT pack (call after a load): whatever the restored save
## already carries is old news, not a fresh acquisition. Shown-hint latches survive — no re-teaching.
func resync() -> void:
	_queue.clear()
	_active = &""
	# Re-arm every state edge to the CURRENT condition, so a body restored already IN water (or already
	# deep, or already hanging on a wrapped line) is old news rather than a fresh entry — mirroring the
	# pack snapshot. Leaving _was == _now here means no spurious rising edge on the resume frame.
	_was = _now.duplicate()
	_snapshot()


func _snapshot() -> void:
	for def: Dictionary in _defs:
		_had[def["item"]] = int(sim.inventory.get(def["item"], 0)) > 0
