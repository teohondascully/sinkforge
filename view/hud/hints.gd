class_name Hints
extends RefCounted

## JUST-IN-TIME TEACHING (A' step 6h (ii), D0370): the first time an item with a non-obvious use lands in
## the pack, a bubble near the body says how to use it, then never again; and a handful of STATE-EDGE
## lessons fire on a body or world condition rather than on a pickup. Legacy `scenes/hints.gd`'s
## mechanism lifts whole -- the acquisition edge against a snapshot so a loaded pack fires nothing, shown
## hints latch, one bubble up at a time with later triggers queued behind it, a relevance gate a lesson
## may wait on, a countdown that runs only while the body is calm, and a ceremony that owns the announce
## channel. Every content row is re-authored: legacy's taught the scanner, the splitter, the borer, the
## drift rig, the crusher and the Descent Engine. Verbs are named where a key is not bound.
##
## Off the OBSERVATION: the pack, the wet flag, the depth, the grapple's state and pivots, the landing.
## Legacy's controller pokes (`note_busy`, `note_ceremony`, `note_depth`...) are computed here from the
## observation or handed in by the chip (the ceremony is the plate's `on_screen`).

const SHOW_SECONDS: float = 9.0          ## how long a bubble lingers, long enough to read twice
## Reading time, not wall time: the countdown runs only while the body is calm, and MAX_LINGER caps the
## wait so a frozen bubble cannot hold the screen or block the queue behind it.
const MAX_LINGER: float = SHOW_SECONDS * 3.0
const FADE_IN: float = 0.25
const FADE_OUT: float = 0.6
const DEPTH_HINT_M: float = 10.0         ## metres below the datum that make the climb a real trip
## Busy hysteresis: arms at 1.25x a run, releases below 0.9x, or the bubble strobes on a body cruising
## near one threshold.
const BUSY_ARM: float = 1.25
const BUSY_RELEASE: float = 0.9
const CHAIN_SPEED_MULT: float = 1.4      ## a release below 1.4x a run was not going anywhere
const PUMP_DOWN: float = 0.85            ## cos(~32 degrees): near enough the bottom of the arc
const LAND_HARD_PX_S: float = VoiceCues.LAND_HARD_PX_S

## The teachable items, scanned in order (order is priority when several fire on one frame). The drill
## belongs to the Objectives chain as its capstone; recipe machines need no bubble because drop in /
## product out is the verb that chain taught.
const DEFS: Array[Dictionary] = [
	{"id": &"rope", "item": &"rope", "text": "ROPE — set it above a drop. Climb it up and down; leap off."},
	{"id": &"torch", "item": &"torch", "text": "TORCH — set it on a wall-backed cell. Its light stays."},
	{"id": &"generator", "item": &"generator", "text": "GENERATOR — set it down with [BUILD], stand by it and press [DROP] with coal selected. It powers what is near."},
	{"id": &"conduit", "item": &"conduit", "text": "CONDUIT — lays a power line. Power flows down and sideways, never up."},
	{"id": &"hopper", "item": &"hopper", "text": "HOPPER — banks what falls in, meters it down. Its filter is the first thing it tastes."},
	{"id": &"lift", "item": &"lift", "text": "LIFT — hauls goods and YOU up its column."},
	{"id": &"pump", "item": &"pump", "text": "PUMP — set it in the wet. Powered, it drains the water under it."},
	{"id": &"winch_head", "item": &"winch_head", "text": "WINCH HEAD — the machine, not your line. Stand it on a lode with [BUILD], then [LINK] it to a Station. The vein climbs on its own."},
	{"id": &"winch_station", "item": &"winch_station", "text": "WINCH STATION — the head's drain. Collect from it."},
]

## State-edge hints: the rising edge fires once and latches like a pack hint. `in_water` sits above the
## swing techniques so a player who is wading is told about the pump before being told how to swing.
const MOMENTS: Array[Dictionary] = [
	{"id": &"in_water", "text": "AQUIFER — water slows you. A POWERED PUMP drains it."},
	{"id": &"deep_enough", "text": "GRAPPLE — press [GRAPPLE] to throw your line at rock above. Hold [REEL] to climb it, press [GRAPPLE] again to let go and fly."},
	{"id": &"pump", "text": "PUMP IT — hold [REEL] at the bottom of the arc, [LOWER] at the top."},
	{"id": &"chain", "text": "CHAIN IT — press [GRAPPLE] again in mid-air to plant the next line, and the speed you left with is the speed you keep."},
	{"id": &"wrapped", "text": "THE LINE CAUGHT — it bent around the rock instead of through it. A short line whips you round harder."},
	{"id": &"hard_landing", "text": "HARD LANDING — a long drop costs your footing. A line fired on the way DOWN takes the fall instead of your legs."},
]

var _had: Dictionary = {}           ## item -> held last frame; the acquisition edge
var _done: Dictionary = {}          ## hint id -> shown (latched)
var _queue: Array[StringName] = []
var _active: StringName = &""
var _life: float = 0.0
var _lingered: float = 0.0
var _busy: bool = false
var _ceremony: bool = false
var _now: Dictionary = {}           ## moment id -> condition true THIS frame
var _was: Dictionary = {}           ## ...and last frame
var _relevant: Dictionary = {}      ## situation id -> live this frame (no def names one today)
var _gate_of: Dictionary = {}
var _primed: bool = false
var _was_anchored: bool = false
var _prev_on_floor: bool = true
var _prev_vel_y: int = 0


func _init() -> void:
	for def: Dictionary in DEFS:
		if def.has("when"):
			_gate_of[def["id"]] = def["when"]


func note(id: StringName, on: bool) -> void:
	_now[id] = on


func note_ceremony(on: bool) -> void:
	_ceremony = on


func note_relevant(id: StringName, on: bool) -> void:
	_relevant[id] = on


func busy() -> bool:
	return _busy


func _ready_to_show(id: StringName) -> bool:
	if not _gate_of.has(id):
		return true
	return bool(_relevant.get(_gate_of[id], false))


## Read the frame's conditions off the observation: the body's speed (busy), the wet flag, the depth,
## the rope moments, the landing. Then the ordinary refresh.
func observe(o: Interface.Observation, delta: float, ceremony: bool = false) -> void:
	if o == null:
		return
	var run: float = float(Interface.Observation.RUN_SPEED_PX_S)
	var speed: float = Vector2(float(o.vel_x), float(o.vel_y)).length() / float(Fx.SCALE)
	_busy = speed > run * (BUSY_RELEASE if _busy else BUSY_ARM)
	_ceremony = ceremony
	note(&"in_water", o.wet)
	note(&"deep_enough", float(MaterialLook.depth_m(o.cell.y)) >= DEPTH_HINT_M)
	var fast: bool = speed > run * CHAIN_SPEED_MULT
	note(&"chain", _was_anchored and not o.grapple_anchored and not o.on_floor and fast)
	_was_anchored = o.grapple_anchored
	var d: Vector2 = VoiceCues.body_px(o) - VoiceCues.px(o.grapple_hitch)
	note(&"pump", o.grapple_taut and fast and d.length() > 1.0 and d.y / d.length() > PUMP_DOWN)
	note(&"wrapped", not o.grapple_pivots.is_empty())
	note(&"hard_landing", VoiceCues.landing_impact(_primed, _prev_on_floor, _prev_vel_y, o) >= LAND_HARD_PX_S)
	_prev_on_floor = o.on_floor
	_prev_vel_y = o.vel_y
	var counts: Dictionary = Payouts.pack_counts(o)
	if not _primed:
		for def: Dictionary in DEFS:
			_had[def["item"]] = int(counts.get(def["item"], 0)) > 0
		_primed = true
	refresh(counts, delta)


## Detects acquisition edges against `counts` ({item: n}), fires the moments' rising edges, advances the
## active bubble's life, promotes the queue.
func refresh(counts: Dictionary, delta: float) -> void:
	for def: Dictionary in DEFS:
		var id: StringName = def["id"]
		var item: StringName = def["item"]
		var has: bool = int(counts.get(item, 0)) > 0
		if has and not _had.get(item, false) and not _done.has(id):
			_done[id] = true                          # latch at fire time, so a re-acquisition cannot re-queue
			_queue.append(id)
		_had[item] = has
	for m: Dictionary in MOMENTS:
		var id: StringName = m["id"]
		var on: bool = _now.get(id, false)
		if on and not _was.get(id, false) and not _done.has(id):
			_done[id] = true
			_queue.append(id)
		_was[id] = on
	if _active != &"" and not _ceremony:
		_lingered += delta
		if not _busy:
			_life -= delta          # only calm seconds count as read
		if _life <= 0.0 or _lingered >= MAX_LINGER:
			_active = &""
	if _active == &"" and not _queue.is_empty() and not _ceremony:
		for i: int in _queue.size():
			if not _ready_to_show(_queue[i]):
				continue
			_active = _queue[i]
			_queue.remove_at(i)
			_life = SHOW_SECONDS
			_lingered = 0.0
			break


func active_id() -> StringName:
	return _active


func active_text() -> String:
	if _active == &"":
		return ""
	for m: Dictionary in MOMENTS:
		if m["id"] == _active:
			return String(m["text"])
	for def: Dictionary in DEFS:
		if def["id"] == _active:
			return String(def["text"])
	return ""


func active_gate() -> StringName:
	return _gate_of.get(_active, &"")


## Fade envelope 0..1, quick in and gentle out; hidden as well as frozen while busy or under a ceremony.
func active_alpha() -> float:
	if _active == &"" or _ceremony or _busy:
		return 0.0
	var shown: float = SHOW_SECONDS - _life
	return clampf(minf(shown / FADE_IN, _life / FADE_OUT), 0.0, 1.0)


func queued() -> int:
	return _queue.size()


## Which lessons have been given, sorted so two saves of one state are byte-identical.
func taught_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _done.keys():
		out.append(String(k))
	out.sort()
	return out


## The mirror: unknown ids are dropped, or a stale id would suppress a future lesson that reused its name.
func restore_taught(ids: Array) -> void:
	var known: Dictionary = {}
	for d: Dictionary in DEFS:
		known[d["id"]] = true
	for m: Dictionary in MOMENTS:
		known[m["id"]] = true
	for v: Variant in ids:
		var id := StringName(String(v))
		if known.has(id):
			_done[id] = true


## Re-arm after a load: what the restored state already has is old news. Latches survive.
func resync() -> void:
	_queue.clear()
	_active = &""
	_was = _now.duplicate()
	_primed = false
