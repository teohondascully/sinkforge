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
## condition rather than picking an item up. The first is the AQUIFER — the moment the body wades into
## water it's slowed + buoyant (Player water impedance) with no on-screen reason; this teaches the L3
## loop (a powered Pump drains it, then mine the rich walls) the instant it's actionable. Same latching:
## fires ONCE on the rising edge (was-dry → wet), never re-teaches, and never fires at boot/load (the
## controller only pokes note_in_water while playing, so a body that spawns dry starts un-triggered).
const WATER_HINT_ID: StringName = &"in_water"
const WATER_HINT_TEXT: String = \
	"AQUIFER — water floods your dig and slows you. A POWERED PUMP drains it; then mine the rich walls."

## The GRAPPLE edge. The tool is in the miner's kit from the first frame, which means nothing at all if
## nobody ever presses F — and the moment it becomes obviously worth pressing is the first time the way
## back up is a real trip. Ten rows down is where a player stops thinking about the hole and starts
## thinking about the climb, so that is where the game mentions the winch. Latched like every other hint.
const DEPTH_HINT_ID: StringName = &"deep_enough"
const DEPTH_HINT_ROWS: int = 10
const DEPTH_HINT_TEXT: String = \
	"GRAPPLE — F fires the winch at whatever you're aiming at. W reels you UP it, SPACE leaps off. " \
	+ "The climb back is the swing."

var sim: FactorySim
var _had: Dictionary = {}           ## item -> true if the pack held it last frame (edge detection)
var _done: Dictionary = {}          ## hint id -> true once shown (latched for the session)
var _queue: Array[StringName] = []  ## fired-but-waiting hint ids (one bubble at a time)
var _active: StringName = &""
var _life: float = 0.0
var _in_water: bool = false         ## body wet this frame (poked by note_in_water; drives the water edge)
var _was_in_water: bool = false     ## body wet last frame — the rising-edge detector for the water hint
var _depth_rows: int = 0            ## rows below the local surface this frame (poked; drives the grapple hint)


func _init(factory: FactorySim) -> void:
	sim = factory
	_snapshot()                     # what's already in the pack at construction never fires


## The controller pokes this each frame with whether the body is currently wading (player._in_water()).
## Kept out of the sim: water impedance is a Player predicate, not a pack item, so the water hint rides
## a poked flag instead of an inventory scan. Off (false) at boot/load until the controller starts
## playing, so a dry spawn never fires the hint retroactively.
func note_in_water(wet: bool) -> void:
	_in_water = wet


## Poked with how far below its own column's surface the body currently is. Like note_in_water this is a
## Player/world predicate rather than a pack item, so it rides a poked value instead of an inventory scan.
func note_depth(rows_below_surface: int) -> void:
	_depth_rows = rows_below_surface


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
	# The AQUIFER state-edge: dry → wet fires the water hint once, latched exactly like a pack hint.
	if _in_water and not _was_in_water and not _done.has(WATER_HINT_ID):
		_done[WATER_HINT_ID] = true
		_queue.append(WATER_HINT_ID)
	_was_in_water = _in_water
	# The DEPTH edge: the first time the shaft is deep enough that the climb is a chore, name the tool.
	if _depth_rows >= DEPTH_HINT_ROWS and not _done.has(DEPTH_HINT_ID):
		_done[DEPTH_HINT_ID] = true
		_queue.append(DEPTH_HINT_ID)
	if _active != &"":
		_life -= delta
		if _life <= 0.0:
			_active = &""
	if _active == &"" and not _queue.is_empty():
		_active = _queue.pop_front()
		_life = SHOW_SECONDS


## The bubble to show right now ("" = none). The HUD anchors it near the body.
func active_text() -> String:
	if _active == &"":
		return ""
	if _active == WATER_HINT_ID:
		return WATER_HINT_TEXT
	if _active == DEPTH_HINT_ID:
		return DEPTH_HINT_TEXT
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
	# Re-arm the water edge to the CURRENT wet state so a body restored already IN water is old news, not
	# a fresh entry (mirrors the pack snapshot). The controller feeds the true flag next frame via
	# note_in_water; leaving _was_in_water == _in_water here means no spurious rising edge on the resume.
	_was_in_water = _in_water
	_snapshot()


func _snapshot() -> void:
	for def: Dictionary in _defs:
		_had[def["item"]] = int(sim.inventory.get(def["item"], 0)) > 0
