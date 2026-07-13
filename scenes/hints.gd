class_name Hints
extends RefCounted

## JUST-IN-TIME teaching (FABLE_50 #35): the first time an item that carries a non-obvious USE lands in
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

var sim: FactorySim
var _had: Dictionary = {}           ## item -> true if the pack held it last frame (edge detection)
var _done: Dictionary = {}          ## hint id -> true once shown (latched for the session)
var _queue: Array[StringName] = []  ## fired-but-waiting hint ids (one bubble at a time)
var _active: StringName = &""
var _life: float = 0.0


func _init(factory: FactorySim) -> void:
	sim = factory
	_snapshot()                     # what's already in the pack at construction never fires


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
	_snapshot()


func _snapshot() -> void:
	for def: Dictionary in _defs:
		_had[def["item"]] = int(sim.inventory.get(def["item"], 0)) > 0
