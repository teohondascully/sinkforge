class_name Hints
extends RefCounted

## Just-in-time teaching. The first time an item with a non-obvious use lands in the pack, a small bubble
## near the body says how to use it, then never again. It carries the Objectives chain's signposting out of
## the tutorial and into the open game, so a Generator unlocked two hours in is still explained.
##
## Representation only, like Objectives: it reads the sim's inventory, never mutates it, never enters the
## tick. Pack lessons trigger on an acquisition edge, a count crossing 0 to >0 this run. The `_init`
## snapshot keeps a pre-stocked dev pack or a loaded save from firing a wall of bubbles at boot, and
## `resync()` re-arms it after a load. Shown hints latch, and the latches persist through a save
## (`taught_ids`), so a lesson is given once per world rather than once per boot. One bubble is up at a
## time and later triggers queue behind it, except a lesson that named a relevance gate (SAPLING_GATE),
## which waits in the queue for its situation and lets the ones behind it go first.

const SHOW_SECONDS: float = 9.0     ## how long a bubble lingers, long enough to read twice

## Reading time, not wall time. The rope lessons fire mid-arc at several hundred pixels a second, which is
## when the player is least able to read them and exactly why they fire there. The countdown runs only
## while the body is calm. MAX_LINGER caps the wait so a frozen bubble cannot hold the screen or block the
## queue behind it.
const MAX_LINGER: float = SHOW_SECONDS * 3.0
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.6

## The relevance gate a lesson may wait on. An optional `when` on a def names a situation id, and the
## bubble is held in the queue until the controller pokes that id true (`note_relevant`). Acquisition says
## the lesson exists; the gate says the moment has come.
const SAPLING_GATE: StringName = &"plantable_ground"

## The teachable items, scanned in order (order is priority when several fire on the same frame). Each
## entry pairs the pack item whose first acquisition triggers it with the bubble text. Two omissions are
## deliberate: the drill belongs to the Objectives chain as its automation capstone, and recipe machines
## like the forge need no bubble because drop-feed in / product falls out is the verb that chain taught.
var _defs: Array[Dictionary] = [
	{"id": &"rope", "item": &"rope",
		"text": "ROPE — RMB above a drop. W/S climbs, SPACE leaps off."},
	{"id": &"torch", "item": &"torch",
		"text": "TORCH — RMB on a wall-backed cell. Its light stays."},
	{"id": &"scanner", "item": &"scanner",
		"text": "SCANNER — RMB pulses. Veins in range echo back."},
	# The pickup says a sapling exists. "RMB plants it on grass" is an instruction, and an instruction with
	# nowhere to point runs its nine seconds out over whatever rock face the player happened to stop at.
	# The gate holds it until a seed is in the pack and the cursor is on ground that would take one. The
	# renewability claim is a second concept and lives on `planted` below, where it is a payoff.
	{"id": &"sapling", "item": &"sapling", "when": SAPLING_GATE,
		"text": "SAPLING — RMB plants it on grass."},
	# "Too dense for the Forge" is the immediate consequence of what just entered the pack. The Blast
	# Furnace is a research path rather than a consequence. A plan belongs on the bench.
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
	{"id": &"drift_rig", "item": &"drift_rig",
		"text": "DRIFT RIG — bores sideways on POWER, not coal, and sorts pay from spoil at the face."},
	{"id": &"crusher", "item": &"crusher",
		"text": "CRUSHER — packs spoil into gravel, 2:1. Ore passes through untouched."},
	{"id": &"descent_engine", "item": &"descent_engine",
		"text": "DESCENT ENGINE — stand it on the violet seal, then toss " + str(FactorySim.DESCENT_QUOTA)
			+ " ingots down its shaft."},
]

## State-edge hints, as against the pack-acquisition ones above: a teaching moment triggered by a body or
## world condition rather than by picking something up. The controller pokes each id's condition every
## frame with `note()`. The rising edge fires the bubble once and latches it like a pack hint. Only the
## predicate differs between the two kinds and it lives in the controller, so what is left here is data.
## Order is priority when several fire on the same frame: `in_water` sits above the three swing techniques
## so a player who is drowning is told about the pump before being told how to swing.
##
##   in_water     the aquifer. Wading is slowed and buoyant (Player water impedance) with no on-screen
##                reason, so this names the powered Pump the instant it is actionable.
##   deep_enough  the winch is in the kit from the first frame, which means nothing if nobody presses F.
##                Ten rows down is where a player starts thinking about the climb.
##   pump         a shorter line carries the same angular momentum at a higher speed, so reeling at the
##                bottom of an arc winds it up and paying out at the top costs nothing. Fired at the
##                bottom of a fast arc, when the hands are already there.
##   chain        the rope crosses a gallery about half again as fast as a full stride, but only for a
##                player who knows the arc does not have to end. Fired the frame a line is released at
##                speed in mid-air, which is the frame the next throw would have paid off.
##   wrapped      the line has just bent around a corner. Unannounced that reads as the rope glitching;
##                named, it is the sharpest manoeuvre in the game, roughly 4x the turn rate.
##   hard_landing the fall took the player's footing (Player.stagger). The lesson is that the rope
##                answers a drop already in progress, not that a fall happened.
var _moments: Array[Dictionary] = [
	{"id": &"in_water",
		"text": "AQUIFER — water slows you. A POWERED PUMP drains it."},
	{"id": &"deep_enough",
		"text": "GRAPPLE — F fires the winch. W reels you up, SPACE leaps off."},
	{"id": &"pump",
		# The mechanism is in the table above and deliberately not in the bubble: a third concept
		# between the two halves of the one input this line exists to give.
		"text": "PUMP IT — reel W at the bottom of the arc, pay S out at the top."},
	{"id": &"chain",
		"text": "CHAIN IT — F again in mid-air plants the next line, and the speed you left with "
			+ "is the speed you keep."},
	{"id": &"wrapped",
		# The first clause explains what just happened on screen, which is why this lesson exists.
		"text": "THE LINE CAUGHT — it bent around the rock instead of through it. "
			+ "A short line whips you round harder."},
	{"id": &"hard_landing",
		"text": "HARD LANDING — a long drop costs your footing. F on the way DOWN catches you: "
			+ "the line takes the fall instead of your legs."},
	# The payoff half of the sapling lesson. It fires on the first sapling that actually roots, so the
	# renewability claim arrives attached to the thing it is a claim about.
	{"id": &"planted",
		"text": "It takes root. Give it time and it is a whole tree — wood is the one thing "
			+ "down here that grows back."},
]

const DEPTH_HINT_ID: StringName = &"deep_enough"
const DEPTH_HINT_ROWS: int = 10     ## rows below the local surface that make the climb a real trip

var sim: FactorySim
var _had: Dictionary = {}           ## item -> true if the pack held it last frame; the acquisition edge
var _done: Dictionary = {}          ## hint id -> true once shown (latched)
var _queue: Array[StringName] = []  ## fired-but-waiting hint ids; one bubble is up at a time
var _active: StringName = &""
var _life: float = 0.0              ## readable seconds left on the bubble, frozen while the body is busy
var _lingered: float = 0.0          ## wall seconds it has been up, which is what MAX_LINGER caps
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


## The controller pokes each state-edge condition here every frame. These are Player and world predicates
## (wet, deep, airborne, wrapped, staggered) rather than pack items, so they ride poked flags instead of an
## inventory scan. Everything defaults to false until the controller starts playing, so nothing fires at spawn.
func note(id: StringName, on: bool) -> void:
	_now[id] = on


## A ceremony owns the announce channel while it is up, so only one primary attention state is on screen at
## a time. Without it an arrival plate and a hint bubble share pixels and both become unreadable.
##
## The held lesson is not dropped. A queued lesson is not promoted while a ceremony runs. An active one
## keeps its text, stops both clocks and draws nothing, then returns with its full remaining life. Nothing
## here latches, expires or forgets. Only the moment the lesson becomes legible changes.
func note_ceremony(on: bool) -> void:
	_ceremony = on


## Poked with whether the body is moving too fast to read a bubble. It freezes the active hint's countdown
## and hides the bubble (see `active_alpha`), so a lesson fired mid-swing returns intact once the body
## settles.
func note_busy(on: bool) -> void:
	_busy = on


## Poked with whether a gated lesson's situation is live right now (SAPLING_GATE: a seed in the pack and
## the cursor over ground that would take it). A level rather than an edge. It lives in the controller with
## the cursor for the same reason the body predicates do.
##
## It gates arrival only, and only for a def that named it. The acquisition edge still fires and latches
## the lesson, the queue holds the bubble until the situation turns up, and once on screen the bubble lives
## its ordinary life. Gating the display on the same flag would strobe instead: the cursor moves every
## frame of normal play, so the bubble would flicker as the aim crossed the edge of the soil. Hysteresis
## settles the equivalent problem for body speed. Aim has no quiet state to settle into.
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
			_done[id] = true                          # latch at fire time, so a re-acquisition cannot re-queue
			_queue.append(id)
		_had[item] = has
	# The state edges, in table order: off to on fires once, latched exactly like a pack hint.
	for m: Dictionary in _moments:
		var id: StringName = m["id"]
		var on: bool = _now.get(id, false)
		if on and not _was.get(id, false) and not _done.has(id):
			_done[id] = true
			_queue.append(id)
		_was[id] = on
	if _active != &"" and not _ceremony:
		# Both clocks stop under a ceremony, not just `_life`: `_lingered` caps how long a frozen bubble
		# may hang around, and a bubble that is not being shown is not wearing out its welcome.
		_lingered += delta
		if not _busy:
			_life -= delta          # only calm seconds count as read
		if _life <= 0.0 or _lingered >= MAX_LINGER:
			_active = &""
	if _active == &"" and not _queue.is_empty() and not _ceremony:
		# The first hint whose situation is live, which is the front one unless it is gated. A gated
		# lesson lets the queue past rather than block it: its situation may be minutes away, while the
		# hints behind it are about things happening now.
		for i: int in _queue.size():
			if not _ready_to_show(_queue[i]):
				continue
			_active = _queue[i]
			_queue.remove_at(i)
			_life = SHOW_SECONDS
			_lingered = 0.0
			break


## The bubble to show right now, or "" for none. The HUD anchors it near the body.
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


## The situation the visible lesson is waiting on, or &"" when it shows on arrival. A gated lesson is about
## a place by construction: it is up only because the cursor is over a cell that answers its question, so
## the controller anchors the bubble to that cell. Ungated lessons stay over the miner.
func active_gate() -> StringName:
	return _gate_of.get(_active, &"")


## Fade envelope: 0..1 over the bubble's life, quick in and gentle out.
##
## `_busy` hides as well as freezes the clock. A bubble drawn through a swing is one more thing over the
## rope at the moment the rope is what to look at, and it was never being read anyway. Frozen and hidden,
## the lesson arrives with its full life the moment the body settles.
func active_alpha() -> float:
	if _active == &"" or _ceremony or _busy:
		return 0.0
	var shown: float = SHOW_SECONDS - _life
	return clampf(minf(shown / FADE_IN, _life / FADE_OUT), 0.0, 1.0)


## Which lessons have already been given, so a save can carry them. `_done` is the "never say this twice"
## record and `_init` rebuilds it empty on every boot, so without persisting it every state-edge lesson
## re-teaches itself in full on each launch. Written as a plain id list rather than the dictionary: the
## file carries the decision that these were taught, not this class's bookkeeping, and a list survives the
## dictionary being restructured.
func taught_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _done.keys():
		out.append(String(k))
	out.sort()                    # stable on disk, so two saves of the same state are byte-identical
	return out


## The mirror of taught_ids. Ids that no longer exist are dropped rather than kept: an unknown id left in
## `_done` would silently suppress any future lesson that reused that name.
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


## Re-arm the acquisition snapshot to the current pack. Call it after a load: whatever the restored save
## already carries is old news, not a fresh acquisition. Shown-hint latches survive, so nothing re-teaches.
func resync() -> void:
	_queue.clear()
	_active = &""
	# Re-arm every state edge to the current condition, mirroring the pack snapshot. A body restored in
	# water or already deep or hanging on a wrapped line is old news rather than a fresh entry. `_was`
	# equal to `_now` is what prevents a spurious rising edge on the resume frame.
	_was = _now.duplicate()
	_snapshot()


func _snapshot() -> void:
	for def: Dictionary in _defs:
		_had[def["item"]] = int(sim.inventory.get(def["item"], 0)) > 0
