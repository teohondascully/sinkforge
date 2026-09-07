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
## A BUSY BODY CANNOT HOLD THE PLATE FOR A LESSON WHILE ANOTHER WAITS (D0424, stranger 3). The third
## stranger fell twenty metres down the shaft beside the pad while TOO FAR was on the plate; the body was
## busy the whole way, so the calm countdown never ran, and the GRAPPLE lesson -- the way back up --
## waited behind a stale lesson for the full linger. Now the seconds a lesson spends HIDDEN (busy, not
## being read) are capped at QUEUE_LINGER whenever a ready lesson waits behind it; the calm reading time
## is untouched, so three lessons arriving at once on a still body still each get their read.
const QUEUE_LINGER: float = 5.0
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
	{"id": &"too_far", "text": "TOO FAR — the red slashed square means the rock is past your reach. Your reach is about a body length: step closer, then hold [MINE]."},
	{"id": &"aim_air", "text": "NOTHING THERE — the red slashed square is on open air: no rock under the pointer. Point at the rock or trunk itself; a trunk is thin, so aim at its middle."},
	{"id": &"aim_sight", "text": "BEHIND ROCK — that rock is in reach, but another rock is in the way of your pick. Cut the near one first, or point at a face you can see."},
	{"id": &"aim_machine", "text": "THAT IS A MACHINE — [MINE] cuts rock, not machines. Stand beside it and press [DROP] to feed it what it takes; what it makes comes to you as you stand there."},
	{"id": &"mined_wrong", "text": "NOT ORE — that was {broke}, and the task wants ore. The ore is the silver-flecked rock inside the WHITE RING: cut that one."},
	{"id": &"dropped_wrong", "text": "WRONG STACK — you dropped {dropped}; the machine beside you takes {wanted}. Press the number over the {wanted} in your bar to hold it, then [DROP]."},
	{"id": &"dropped_floor", "text": "DROPPED — the stack fell at your feet, and you pick up what lies there as you stand. A machine takes a drop only when you stand BESIDE it: a body length."},
	{"id": &"in_water", "text": "AQUIFER — water slows you. A POWERED PUMP drains it."},
	{"id": &"way_down", "text": "THE WAY DOWN — the ground is rock you can cut. Point at the ground under you and hold [MINE]: the metre opens and you drop into it. One metre at a time is a safe fall."},
	{"id": &"deep_enough", "text": "GRAPPLE — POINT at rock above you and press [GRAPPLE] to throw your line there. Hold [REEL] to climb it, press [GRAPPLE] again to let go and fly."},
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
var _far_ticks: int = 0
var _air_ticks: int = 0
var _machine_ticks: int = 0
## THE WAY DOWN (T037 taken provisionally, D0440). Stranger 15, sent to descend, mined four ore in the first
## hold and then walked the pad for a minute looking for an entrance to the caverns drawn below it; nothing
## on screen said the ground is rock you can cut. Once the body has ranged WAY_DOWN_RANGE_M across the
## surface without ever standing WAY_DOWN_DEPTH_M below the datum, and has broken rock once (the verb is
## known), the lesson names the floor. The tutorial's fourth rung says the same thing later, to the player
## who got there.
const WAY_DOWN_RANGE_M: float = 24.0
const WAY_DOWN_DEPTH_M: float = 4.0
## THE WRONG STACK (D0443, stranger 16). Q drops the SELECTED stack; the sixteenth stranger, holding clay
## from the pit they had dug, pressed Q beside the forge a dozen times, read DROPPED each time ("stand
## BESIDE it"), stepped closer and dropped clay again. When a floor drop's item is one no machine within
## the drop's own far range takes, and the pack holds one such a machine does, the lesson names both.
const WANTED_RANGE_M: float = 12.0        ## `Verbs.FAR_EATER_M`, the range the drop's TOO FAR already uses
var _prev_counts: Dictionary = {}
var _subs: Dictionary = {}                ## lesson id -> {placeholder: text}, filled when the moment is noted
var _min_x_m: float = INF
var _max_x_m: float = -INF
var _deepest_m: float = -INF
var _broke_once: bool = false
const FAR_TICKS: int = 20
var _sight_ticks: int = 0
const AIR_TICKS: int = 90           ## a second and a half: past any re-aim after a metre breaks under the pointer
var _thrown: bool = false           ## a line has been live once this session; the grapple is known


## A floor drop of an item no machine in range takes, while the pack holds one a machine does: the dropped
## item is the one whose count fell this frame; the wanted one is the first recipe input a machine within
## WANTED_RANGE_M asks for that the pack still holds. Fills the lesson's placeholders.
func _wrong_stack(o: Interface.Observation, counts: Dictionary) -> bool:
	var dropped: StringName = &""
	for item: StringName in _prev_counts:
		if int(counts.get(item, 0)) < int(_prev_counts[item]):
			dropped = item
	_prev_counts = counts
	if o.drop_went != &"floor" or dropped == &"":
		return false
	var body := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	var wanted: StringName = &""
	for rec: Dictionary in o.machines:
		var at: Vector2 = (Vector2(rec["cell"]) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
		if at.distance_to(body) > WANTED_RANGE_M * float(Interface.Observation.LOGIC_PX):
			continue
		var inputs: Dictionary = RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {}).get("inputs", {})
		for need: Variant in inputs:
			var item := StringName(String(need))
			if item == dropped:
				return false                         # the machine takes what fell: that is the BESIDE lesson's case
			if wanted == &"" and int(counts.get(item, 0)) > 0:
				wanted = item
	if wanted == &"":
		return false
	_subs[&"dropped_wrong"] = {"{dropped}": Hotbar.item_label(dropped).to_lower(), "{wanted}": Hotbar.item_label(wanted).to_lower()}
	return true


## A cell broken whose yield is not ore while the pack holds none (D0450, stranger 26): the pointer was
## three metres right of the ring, the clay ticked "+1 clay", and the stranger read the verb as spent and
## left to search the caves. Nothing after THE WAY DOWN, which asks for exactly this cut; the yield must be
## known (a fixture's bare break names no material).
func _mined_wrong(o: Interface.Observation, counts: Dictionary) -> bool:
	if not o.mining_broke or int(counts.get(&"ore", 0)) > 0 or _done.has(&"way_down"):
		return false
	var rec: Dictionary = MaterialsRecords.RECORDS.get(String(o.mining_broke_material), {})
	var got := StringName(String(rec.get("yields", String(o.mining_broke_material))))   # D0409's contract, read as data
	if got == &"" or got == &"ore":
		return false
	_subs[&"mined_wrong"] = {"{broke}": Hotbar.item_label(got).to_lower()}
	return true


## The surface walked from edge to edge with the verb known and nothing dug down (T037).
func _way_down_wanted(o: Interface.Observation) -> bool:
	var x_m: float = float(o.pos_x) / float(Fx.SCALE) / float(Interface.Observation.LOGIC_PX)
	_min_x_m = minf(_min_x_m, x_m)
	_max_x_m = maxf(_max_x_m, x_m)
	_deepest_m = maxf(_deepest_m, MaterialLook.depth_m_exact(o.cell.y))
	_broke_once = _broke_once or o.mining_broke
	return _broke_once and _max_x_m - _min_x_m >= WAY_DOWN_RANGE_M and _deepest_m < WAY_DOWN_DEPTH_M


## Whether the player has met the grapple: the lesson given (queued counts: it shows within QUEUE_LINGER),
## or a line thrown on their own. The rope painter's landing ring waits on this (D0424).
func grapple_known() -> bool:
	return _thrown or _done.has(&"deep_enough")


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
	# A third of a second of holding MINE on rock past the reach (D0421): the mark shows the slash at once,
	# the lesson says why once, and never for a tap that merely brushed past.
	_far_ticks = _far_ticks + 1 if o.aim_refusal == &"far" else 0
	note(&"too_far", _far_ticks >= FAR_TICKS)
	# The same slash on AIR (D0436, stranger 10): TOO FAR had taught that the slashed square means "past
	# your reach", so a pointer a hand's width off a thin trunk read as unreachable for eighteen seconds.
	# A metre breaking under a held pointer leaves it on air too, for as long as the re-aim takes: the
	# count restarts at a break and runs a second and a half, so ordinary digging never hears this.
	# A machine under a held MINE is refused as "air" too (a machine is not terrain); it is not open air to the
	# player (D0445, stranger 20 held MINE on the forge from six metres and read NOTHING THERE).
	var on_machine: bool = o.aim_refusal == &"air" and not o.machine_at(Vector2i(o.aim_cell.x >> 2, o.aim_cell.y >> 2)).is_empty()
	_air_ticks = 0 if o.mining_broke or on_machine else (_air_ticks + 1 if o.aim_refusal == &"air" else 0)
	note(&"aim_air", _air_ticks >= AIR_TICKS)
	_machine_ticks = _machine_ticks + 1 if on_machine else 0
	note(&"aim_machine", _machine_ticks >= FAR_TICKS)
	# The third refusal, "sight" (D0452): rock in reach behind other rock -- a dig-plan mark under a cut,
	# or a buried cell nothing visible stands near. Wordless before; stranger 29 met it four times.
	_sight_ticks = _sight_ticks + 1 if o.aim_refusal == &"sight" else 0
	note(&"aim_sight", _sight_ticks >= FAR_TICKS)
	var counts: Dictionary = Payouts.pack_counts(o)
	note(&"mined_wrong", _mined_wrong(o, counts))
	var wrong: bool = _wrong_stack(o, counts)
	note(&"dropped_wrong", wrong)
	note(&"dropped_floor", o.drop_went == &"floor" and not wrong)   # the drop's own TOO FAR (D0428, stranger 5)
	note(&"in_water", o.wet)
	note(&"way_down", _way_down_wanted(o))
	note(&"deep_enough", float(MaterialLook.depth_m(o.cell.y)) >= DEPTH_HINT_M)
	if o.grapple_live:
		_thrown = true
	var fast: bool = speed > run * CHAIN_SPEED_MULT
	note(&"chain", _was_anchored and not o.grapple_anchored and not o.on_floor and fast)
	_was_anchored = o.grapple_anchored
	var d: Vector2 = VoiceCues.body_px(o) - VoiceCues.px(o.grapple_hitch)
	note(&"pump", o.grapple_taut and fast and d.length() > 1.0 and d.y / d.length() > PUMP_DOWN)
	note(&"wrapped", not o.grapple_pivots.is_empty())
	note(&"hard_landing", VoiceCues.landing_impact(_primed, _prev_on_floor, _prev_vel_y, o) >= LAND_HARD_PX_S)
	_prev_on_floor = o.on_floor
	_prev_vel_y = o.vel_y
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
		var hidden: float = _lingered - (SHOW_SECONDS - _life)   # wall seconds the lesson was not being read
		if _life <= 0.0 or _lingered >= MAX_LINGER or (hidden >= QUEUE_LINGER and _has_ready_waiting()):
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


## Whether a queued lesson could take the plate now: gated lessons waiting on a situation do not count.
func _has_ready_waiting() -> bool:
	for id: StringName in _queue:
		if _ready_to_show(id):
			return true
	return false


func active_id() -> StringName:
	return _active


func active_text() -> String:
	if _active == &"":
		return ""
	for m: Dictionary in MOMENTS:
		if m["id"] == _active:
			var text: String = String(m["text"])
			for key: String in _subs.get(_active, {}):
				text = text.replace(key, String((_subs[_active] as Dictionary)[key]))
			return text
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
