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
## The lesson's landing is a LONG drop: terminal speed, a fall of eleven metres or more (D0471). The
## thud's threshold (`VoiceCues.LAND_HARD_PX_S`, 240) is a two-metre step; a plain jump lands at 365 and
## taught the grapple to three strangers who had only hopped.
const LAND_HARD_PX_S: float = float(Interface.Units.MAX_FALL_PX_S)

## The lesson tables live in `HintTexts` (D0469); these aliases keep every reader's name.
const DEFS: Array[Dictionary] = HintTexts.DEFS
const MOMENTS: Array[Dictionary] = HintTexts.MOMENTS

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
var _refusals: Refusals = Refusals.new()   ## the held verb's refusals and the slot (D0488)
## THE WAY DOWN (T037 taken provisionally, D0440). Stranger 15, sent to descend, mined four ore in the first
## hold and then walked the pad for a minute looking for an entrance to the caverns drawn below it; nothing
## on screen said the ground is rock you can cut. Once the body has ranged WAY_DOWN_RANGE_M across the
## surface without ever standing WAY_DOWN_DEPTH_M below the datum, and has broken rock once (the verb is
## known), the lesson names the floor. The tutorial's fourth rung says the same thing later, to the player
## who got there.
const WAY_DOWN_RANGE_M: float = 24.0
const WAY_DOWN_DEPTH_M: float = 4.0
## THE EDGE (D0526, strangers 103-126): the world is 256 cells wide with the spawn at its centre and every
## machine but the forge to the right of it; fourteen of twenty-four strangers walked to the right edge, where
## the camera clamps (D0333) and the body sits at the screen's side, and kept pressing D -- S104 and S120
## dropped their ingots into the pond there with the ring 30 m behind them. The lesson fires when the body's
## cell is among the EDGE_CELLS outermost on either side of `world_cells` -- the field that exists so a
## consumer can tell the edge of the world from a hole in it (D0302). The cell test alone: the observation
## carries no camera, and at the closest zoom the view is 160 cells wide, so a body this near the edge sits
## 76 or more cells off the view's centre under the clamp. A bare observation with no world size never fires.
const EDGE_CELLS: int = 4
## THE DROP'S OUTCOMES live in `DropLessons` (D0443's WRONG STACK, D0517's short lesson and receipt); this
## class applies what it decides to the plate, the queue and the slot.
var _drops: DropLessons = DropLessons.new()
var _subs: Dictionary = {}                ## lesson id -> {placeholder: text}, filled when the moment is noted
var _min_x_m: float = INF
var _max_x_m: float = -INF
var _deepest_m: float = -INF
var _broke_once: bool = false
const FAR_TICKS: int = Refusals.FAR_TICKS          ## the counts live in `Refusals`; the suites' names stay
const AIR_TICKS: int = Refusals.AIR_TICKS
const CUT_TICKS: int = Refusals.CUT_TICKS
const BELOW_CELLS: int = Refusals.BELOW_CELLS
var _coming_prev: int = 0
var _ingots_prev: int = 0
var objectives: Objectives = null   ## the ladder, for the rung-gated lessons; a bare Hints reads the pack instead
var _thrown: bool = false           ## a line has been live once this session; the grapple is known


## A cell broken whose yield is not ore while the MINE rung is open (D0450, stranger 26): the pointer was
## three metres right of the ring, the clay ticked "+1 clay", and the stranger read the verb as spent and
## left to search the caves. The rung, not the pack (D0458): the ore is spent in the forge by the wood rung,
## and "that was wood, and the task wants ore" fired on the ceiling run's felling. Nothing after THE WAY
## DOWN, which asks for exactly this cut; the yield must be known (a fixture's bare break names no material).
func _mined_wrong(o: Interface.Observation, counts: Dictionary) -> bool:
	var rung_open: bool = objectives.current_id() == &"mine" if objectives != null else int(counts.get(&"ore", 0)) == 0
	if not o.mining_broke or not rung_open or _done.has(&"way_down"):
		return false
	var rec: Dictionary = MaterialsRecords.RECORDS.get(String(o.mining_broke_material), {})
	var got := StringName(String(rec.get("yields", String(o.mining_broke_material))))   # D0409's contract, read as data
	if got == &"" or got == &"ore":
		return false
	_subs[&"mined_wrong"] = {"{broke}": Hotbar.item_label(got).to_lower()}
	return true


## Walked out of reach of a machine still holding the player's ore (D0461, strangers 37 and 38): the
## first ingot came at two seconds, the second was two seconds behind it, and both left with "1/2". What
## was coming last tick (`Payouts.coming`: output plus the batches the held input makes, within reach) is
## nothing this tick, and the pack did not rise: the body left, the machine did not finish.
## D0469 (stranger 51): a drill standing anywhere but on the line while the BUILD rung is open -- it was
## set in the stranger's own tunnel, fuelled, bored the adit's ore into nothing, and the rung never ticked.
func _wrong_spot(o: Interface.Observation) -> bool:
	if objectives == null or objectives.current_id() != &"build":
		return false
	var placed: bool = false
	for rec: Dictionary in o.machines:
		placed = placed or rec.get("behavior", &"") == &"drill"
	return placed and not Objectives.drill_on_line(o)


func _left_working(o: Interface.Observation, counts: Dictionary) -> bool:
	var ingots: int = int(counts.get(&"ingot", 0))
	var coming: int = Payouts.coming(o, &"ingot")
	var left: bool = _coming_prev > 0 and coming == 0 and ingots == _ingots_prev
	if left:
		_subs[&"left_working"] = {"{more}": str(_coming_prev)}
	_coming_prev = coming
	_ingots_prev = ingots
	return left


## The surface walked from edge to edge with the verb known and nothing dug down (T037).
func _way_down_wanted(o: Interface.Observation) -> bool:
	var x_m: float = float(o.pos_x) / float(Fx.SCALE) / float(Interface.Units.LOGIC_PX)
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
	_subs.merge(HintTexts.fixed_subs())   # the placeholders that are known before the game starts


## The body among the EDGE_CELLS outermost cells of the world's right or left side, one moment a side (D0526).
func _note_edge(o: Interface.Observation) -> void:
	var known: bool = o.world_cells.x > 0                  # a bare observation names no world, so it has no edge
	note(&"world_edge_right", known and o.cell.x >= o.world_cells.x - EDGE_CELLS)
	note(&"world_edge_left", known and o.cell.x < EDGE_CELLS)


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
	var run: float = float(Interface.Units.RUN_SPEED_PX_S)
	var speed: float = Vector2(float(o.vel_x), float(o.vel_y)).length() / float(Fx.SCALE)
	_busy = speed > run * (BUSY_RELEASE if _busy else BUSY_ARM)
	_ceremony = ceremony
	_note_refusals(o, delta)
	var counts: Dictionary = Payouts.pack_counts(o)
	note(&"mined_wrong", _mined_wrong(o, counts))
	note(&"wrong_spot", _wrong_spot(o))
	var drop: Dictionary = _drops.read(o, counts, _subs)
	note(&"dropped_wrong", drop["wrong"])
	note(&"dropped_floor", o.drop_went == &"floor" and not drop["wrong"])   # no machine in sight takes it (D0428, stranger 5; D0517)
	note(&"dropped_short", drop["short"])
	_refresh_short(o)
	_refusals.drop(drop["slot"])                                              # the slot names every drop, not just the first (D0496)
	if o.drop_went == &"fed":
		_let_go(drop["receipt"])
	note(&"left_working", _left_working(o, counts))
	note(&"in_water", o.wet)
	_note_edge(o)
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


## KEEP THE STANDING "TOO FAR" HONEST, and let go of it the moment it stops being true (D0558). The
## lesson names metres and a direction, and it was substituted once -- at the drop -- so it went stale as
## soon as the player obeyed it. S131 walked with "the FORGE that takes ore is 8 m to your LEFT" on the
## dock and reported the message not updating. `active_text` re-substitutes every call, so the numbers
## only had to be kept fresh.
##
## AND WHEN THE BODY REACHES THE MACHINE THE LESSON GOES, which is the point rather than tidiness: a
## lesson that says TOO FAR while the drop would now succeed is teaching the wrong thing, and its
## disappearance is the "close enough" signal three strangers said nothing gave them (D0557 draws the
## same line on the ground). The queue is filtered too, exactly as `_let_go` does -- promoting a stale
## TOO FAR onto the plate one tick after the body arrived is the same defect through the other door.
func _refresh_short(o: Interface.Observation) -> void:
	if not _drops.refresh_short(o, _subs) and _subs.has(&"dropped_short"):
		_subs.erase(&"dropped_short")
		if _active == &"dropped_short":
			_active = &""
		_queue = _queue.filter(func(id: StringName) -> bool: return id != &"dropped_short")


## A drop that FED a machine (D0517): the plate lets go of any drop lesson -- the one up, and any queued,
## since the queue would promote a stale NO MACHINE HERE onto the plate this same tick -- and the slot gets
## the receipt. A receipt and a refusal never show together.
func _let_go(receipt: String) -> void:
	if _active in DropLessons.LESSONS:
		_active = &""
	_queue = _queue.filter(func(id: StringName) -> bool: return not DropLessons.LESSONS.has(id))
	if receipt != "":
		_refusals.receipt(receipt)
	else:
		_refusals.drop_done()


## The held verb's refusals, each on its own count in `Refusals`; BUILD's two ride the same channel (D0470).
func _note_refusals(o: Interface.Observation, delta: float) -> void:
	_refusals.read(o, delta)
	for id: StringName in _refusals.fired:
		note(id, _refusals.fired[id])


## THE REFUSAL SLOT (D0488, D0496): the live refusal's headline -- an aim's or a drop's -- on every press,
## latched by nothing; "" while that refusal's own lesson holds the plate.
func slot_text() -> String:
	return _refusals.slot_text(_active)


func slot_alpha() -> float:
	return _refusals.slot_alpha(_active)


## The slot entry's kind (D0517): `Refusals.RECEIPT` for a fed drop's words, `Refusals.REFUSAL` otherwise.
func slot_kind() -> StringName:
	return _refusals.slot_kind()


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
