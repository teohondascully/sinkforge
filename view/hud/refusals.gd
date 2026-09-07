class_name Refusals
extends RefCounted

## THE HELD VERB'S REFUSALS, READ OFF THE OBSERVATION (out of `Hints` in D0488, for the size gate). Each
## refusal keeps its own frame count so its LESSON fires after a deliberate hold and never for a tap that
## brushed past; and each names that lesson at once for the SLOT, the short plate that says the refusal's
## own headline on every press, latched by nothing.
##
## TOO FAR: a third of a second of holding MINE on rock past the reach (D0421): the mark shows the slash
## at once, the lesson says why once. TOO FAR DOWN: the same, on a buried target, where "step closer"
## cannot be done on foot (D0473). NOTHING THERE: the slash on AIR (D0436, stranger 10): TOO FAR had taught
## that the slashed square means "past your reach", so a pointer a hand's width off a thin trunk read as
## unreachable for eighteen seconds. A metre breaking under a held pointer leaves it on air too, for as
## long as the re-aim takes: the count restarts at a break and runs a second and a half, so ordinary
## digging never hears this; CUT THROUGH is the air run that began within half a second of your own bite
## (D0467). THAT IS A MACHINE: a machine under a held MINE is refused as "air" too (a machine is not
## terrain); it is not open air to the player (D0445, stranger 20 held MINE on the forge from six metres).
## BEHIND ROCK: the "sight" refusal (D0452): rock in reach behind other rock. STEP ASIDE, IN THE ROCK and
## BUILD's own TOO FAR ride the same channel, one observe wide (D0470, D0493).
##
## THE SLOT (D0488, strangers 61-75): the lessons are one-shots behind a hold. The second TOO FAR of a
## game, and every short press, showed the slashed square and nothing else; S66's report called a
## visible lesson "no feedback", S64 pressed the same pixel twice and got two different answers with no
## word for either. The slot is the lesson's headline (its words before the dash) from the first frame of
## the refusal, up while it is live and SLOT_LINGER after, and silent while that lesson itself is on the
## plate, since the plate's first words are the same headline.

const FAR_TICKS: int = 20
const AIR_TICKS: int = 90           ## a second and a half: past any re-aim after a metre breaks under the pointer
const CUT_TICKS: int = 30           ## half a second on air right after your own bite opened the pointer's cell (D0467)
const BELOW_CELLS: int = 8          ## two metres under the body's centre: past the feet and into the ground (D0473)
const SLOT_LINGER: float = 1.5      ## seconds the slot outlives the refusal: long enough to read after the release
const SLOT_FADE: float = 0.5        ## the last of those, fading

var far_ticks: int = 0
var air_ticks: int = 0
var machine_ticks: int = 0
var sight_ticks: int = 0
var since_break: int = 100000
var fired: Dictionary = {}          ## lesson id -> its hold has run long enough THIS frame
var slot_id: StringName = &""       ## the lesson whose headline names the refusal live now, or last live
var slot_since: float = 0.0         ## seconds since that refusal was last live


## One frame: advance the counts, decide which lessons' holds are long enough, and name the slot.
func read(o: Interface.Observation, delta: float) -> void:
	far_ticks = far_ticks + 1 if o.aim_refusal == &"far" else 0
	var below: bool = o.aim_cell.y - o.cell.y >= BELOW_CELLS          # a buried target: "step closer" cannot be done on foot (D0473)
	var on_machine: bool = o.aim_refusal == &"air" and not o.machine_at(Vector2i(o.aim_cell.x >> 2, o.aim_cell.y >> 2)).is_empty()
	air_ticks = 0 if o.mining_broke or on_machine else (air_ticks + 1 if o.aim_refusal == &"air" else 0)
	since_break = 0 if o.mining_broke else since_break + 1
	var own_cut: bool = since_break - air_ticks <= CUT_TICKS         # the air run began within half a second of a break: the pointer's cell went
	machine_ticks = machine_ticks + 1 if on_machine else 0
	sight_ticks = sight_ticks + 1 if o.aim_refusal == &"sight" else 0
	fired = {
		&"too_far": far_ticks >= FAR_TICKS and not below,
		&"far_below": far_ticks >= FAR_TICKS and below,
		&"cut_through": air_ticks >= CUT_TICKS and own_cut,
		&"aim_air": air_ticks >= AIR_TICKS and not own_cut,
		&"aim_machine": machine_ticks >= FAR_TICKS,
		&"aim_sight": sight_ticks >= FAR_TICKS,
		&"build_far": o.aim_refusal == &"build_far",
		&"build_here": o.aim_refusal == &"build_here",
		&"build_rock": o.aim_refusal == &"build_rock",
	}
	var live: StringName = lesson_of(o.aim_refusal, below, on_machine, own_cut)
	if live != &"":
		slot_id = live
		slot_since = 0.0
	else:
		slot_since += delta


## The lesson a refusal names on its FIRST frame, before any count: what the slot says.
static func lesson_of(refusal: StringName, below: bool, on_machine: bool, own_cut: bool) -> StringName:
	match refusal:
		&"far": return &"far_below" if below else &"too_far"
		&"air": return &"aim_machine" if on_machine else (&"cut_through" if own_cut else &"aim_air")
		&"sight": return &"aim_sight"
		&"build_far", &"build_here", &"build_rock": return refusal
	return &""


## A lesson's headline: its words before the dash ("TOO FAR"), authored once in `HintTexts`.
static func headline(id: StringName) -> String:
	for m: Dictionary in HintTexts.MOMENTS:
		if m["id"] == id:
			return String(m["text"]).get_slice(" — ", 0)
	return ""


## The slot's text, "" when no refusal is live or within its linger, or when `active` (the plate's lesson)
## is the refusal's own lesson.
func slot_text(active: StringName) -> String:
	if slot_id == &"" or slot_since > SLOT_LINGER or active == slot_id:
		return ""
	return headline(slot_id)


## Full while the refusal is live and through most of the linger; out over the last SLOT_FADE.
func slot_alpha(active: StringName) -> float:
	if slot_text(active) == "":
		return 0.0
	return clampf((SLOT_LINGER - slot_since) / SLOT_FADE, 0.0, 1.0)
