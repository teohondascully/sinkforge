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
## hints LATCH for the session; one bubble at a time, later triggers queue behind it. Not saved — a hint
## re-teaching once after a fresh boot is fine, spam within a session is not.

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

## The teachable moments, scanned in order (order = priority when several fire the same frame). Each:
## the pack item whose first acquisition triggers it + what the bubble says. Deliberately ABSENT: the
## drill (the Objectives chain teaches it as the tutorial's automation capstone) and recipe machines like
## the forge/iron chain (drop-feed in, product falls out — the one verb the chain already taught).
var _defs: Array[Dictionary] = [
	{"id": &"rope", "item": &"rope",
		"text": "ROPE — RMB an open cell above a drop and it unrolls DOWN to you. W/S climbs it, SPACE leaps off."},
	{"id": &"torch", "item": &"torch",
		"text": "TORCH — RMB mounts it on a wall-backed cell (or beside rock). Its light STAYS — claim the dark."},
	{"id": &"scanner", "item": &"scanner",
		"text": "SCANNER — select it and RMB fires a sonar pulse: every vein in range echoes through the rock."},
	{"id": &"sapling", "item": &"sapling",
		"text": "SAPLING — RMB plants it on grassy ground. It grows into a NEW TREE: wood is renewable."},
	{"id": &"rich_ore", "item": &"rich_ore",
		"text": "RICH ORE — too dense for the Forge. Research ENRICHMENT: a Blast Furnace pours TWO ingots from one."},
	{"id": &"generator", "item": &"generator",
		"text": "GENERATOR — place it, then drop COAL on it (Q). It radiates POWER to machines nearby."},
	{"id": &"conduit", "item": &"conduit",
		"text": "CONDUIT — RMB lays power tube. Power flows DOWN and SIDEWAYS through it — never up."},
	{"id": &"hopper", "item": &"hopper",
		"text": "HOPPER — it banks what falls in and meters it DOWN. It keeps the FIRST item it tastes (R re-tastes)."},
	{"id": &"lift", "item": &"lift",
		"text": "LIFT — it hauls goods (and YOU) UP its column. Power multiplies its throughput."},
	{"id": &"splitter", "item": &"splitter",
		"text": "SPLITTER — it routes falling items DOWN + RIGHT. Aim R at it to cycle the ratio."},
	{"id": &"h_drill", "item": &"h_drill",
		"text": "BORER — it bores SIDEWAYS, the way YOU face when placing. Feed it coal; the haul drops down its own column."},
	{"id": &"descent_engine", "item": &"descent_engine",
		"text": "DESCENT ENGINE — stand it ON the violet seal, then toss " + str(FactorySim.DESCENT_QUOTA)
			+ " ingots down its shaft. Gravity feeds the breach."},
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
		"text": "AQUIFER — water floods your dig and slows you. A POWERED PUMP drains it; "
			+ "then mine the rich walls."},
	{"id": &"deep_enough",
		"text": "GRAPPLE — F fires the winch at whatever you're aiming at. W reels you UP it, "
			+ "SPACE leaps off. The climb back is the swing."},
	{"id": &"chain",
		"text": "CHAIN IT — you never have to land. F again in mid-air plants the next line, "
			+ "and the speed you left with is the speed you keep."},
	{"id": &"wrapped",
		"text": "THE LINE CAUGHT — it bent around the rock instead of through it. A short line whips "
			+ "you round harder; S pays out to swing wide."},
	{"id": &"hard_landing",
		"text": "HARD LANDING — a long drop costs your footing. F on the way DOWN catches you: "
			+ "the line takes the fall instead of your legs."},
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
var _now: Dictionary = {}           ## moment id -> condition true THIS frame (poked by note())
var _was: Dictionary = {}           ## moment id -> ...and last frame; the pair is the rising-edge detector


func _init(factory: FactorySim) -> void:
	sim = factory
	_snapshot()                     # what's already in the pack at construction never fires


## The controller pokes each state-edge condition here every frame. These are Player/world predicates
## (wet, deep, airborne, wrapped, staggered) rather than pack items, so they ride poked flags instead of
## an inventory scan — and they live in the controller because that is where the body and the rope are.
## Everything defaults to false until the controller starts playing, so a spawn never fires retroactively.
func note(id: StringName, on: bool) -> void:
	_now[id] = on


## Poked with whether the body is moving too fast to read a bubble. Freezes the active hint's countdown
## rather than its display, so a lesson fired mid-swing is still on screen when the swing ends.
func note_busy(on: bool) -> void:
	_busy = on


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
	if _active != &"":
		_lingered += delta
		if not _busy:
			_life -= delta          # only calm seconds count as read
		if _life <= 0.0 or _lingered >= MAX_LINGER:
			_active = &""
	if _active == &"" and not _queue.is_empty():
		_active = _queue.pop_front()
		_life = SHOW_SECONDS
		_lingered = 0.0


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


## Fade envelope: 0..1 over the bubble's life (quick in, gentle out).
func active_alpha() -> float:
	if _active == &"":
		return 0.0
	var shown: float = SHOW_SECONDS - _life
	return clampf(minf(shown / FADE_IN, _life / FADE_OUT), 0.0, 1.0)


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
