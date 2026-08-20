extends "res://tools/check_base.gd"

## Harness layer: ONE WORKS ROW IS ONE MACHINE, AND BOTH FUNCTIONS THAT ANSWER "WHICH ONE" MUST NAME IT.
##   godot --headless --path . --script res://tools/check_row_identity.gd
##
## THE DEFECT THIS HOLDS. Two functions in hud.gd answer the question "which thing is WORKS row i", by two
## different rules:
##
##   `_craft_id(i)`  returns `craft_ids[i]` when the row is in range, and otherwise falls back to
##                   `machine_icons.keys()[i]` — a defensive path from before MainView supplied craft_ids.
##   `_unlocked()`   walks `craft_options.size()` rows reading `ids[i] if i < ids.size() else &""`, and
##                   decides each row's locked-ness from whatever that read produced.
##
## The counter resolves a row's IDENTITY through the first and its LOCKED-NESS through the second. Past the
## end of `craft_ids` they answer differently on purpose — one falls back to a real machine id, the other
## reads the empty name — and `ResearchRules.locking_tech(&"")` is `&""`, which means "freely craftable".
## So a short `craft_ids` does not produce an error or a blank row. It produces a row that draws as a
## machine you have not researched, over a filter that decided it was yours because it was looking at
## nothing. There is no visible symptom at the moment of the mistake.
##
## WHY THERE IS NOTHING TO FIX AND STILL SOMETHING TO GUARD. main.gd builds `craft_opts`, `craft_ids` and
## `machine_icons` in ONE loop over `_craftable`, so the three come out the same length and the fallback
## never fires. That is a property of one loop in one function, held up by nothing but the fact that
## nobody has yet had a reason to append to one of those lists without the others — a filtered subset, a
## second source of rows, a tools/machines split of the kind `rack_ids` already is. The `LOCKED` branch in
## `_draw_bazaar_detail` is unreachable today by exactly this coincidence, which is why it is commented as
## kept rather than deleted. This layer is what turns the coincidence into a checked invariant.
##
## WHAT IS ASSERTED, AND WHY IT IS NOT THE LENGTH CHECK. `craft_ids.size() >= craft_options.size()` is the
## REASON the two agree today; row-by-row agreement is the PROPERTY. They are not the same statement — a
## future build could legitimately resolve rows some other way and keep the property while losing the
## reason, and a build could also keep the lengths equal while the two lists hold different machines in
## the same slot. So §2 probes the property directly and §3 records the reason underneath it.
##
## HOW A DECISION IS COMPARED WITH AN IDENTITY. `_unlocked` returns row indices and never says which id it
## read, so there is no id to compare against `_craft_id`'s. What it does expose is a decision per row, and
## a decision moves under the research state. So the layer POSES a research state, asks `open_machines()`
## which rows the filter opens, and compares that against the rows `_craft_id`'s own ids say should open
## under the same state. One tech is granted at a time, so each locked row is closed in every probe but
## its own: the row that responds to a machine's tech is required to be the row `_craft_id` calls that
## machine. Both halves go through the shipped `ResearchRules.locking_tech`, so the comparison is between
## two resolvers and not between the game and a table retyped in here.
##
## THE VACUITY GUARDS, which are the assertions that matter most, because every green below is the shape
## of a green that can be produced by measuring nothing. An agreement over zero rows, an agreement between
## two empty strings, and an agreement between two constant sets all print the same word.
##   §1 proves there are rows, that every id the resolver handed back is a real machine MainView can
##      place, and that no two rows resolve to the same one.
##   §2 requires every locked row to have been observed BOTH open and closed across the probes. A row that
##      was open in all of them was never actually filtered, and its agreement means nothing.
##   §4 hands the comparator an expectation it must reject, on the same state, in the same run. Without it
##      the whole file is compatible with a comparator that returns "agreed" unconditionally.
##
## WHAT WOULD HAVE TO BE TRUE FOR THIS LAYER TO GO RED, stated once so a future reader can weigh a green:
## a row whose identity and whose locked-ness are decided from different machines. In practice that means
## `craft_ids` and `craft_options` diverging in main.gd — a filtered list, an early return, an append to
## one of the three structures and not the others — or `_craft_id` and `_unlocked` being changed apart.
## Nothing else in the tree can move these numbers.
##
## WHAT THIS DOES NOT COVER. The RACK half (`rack_ids` / `rack_options`) resolves through the same
## `_unlocked` but its ids come back through `bazaar_action`'s own in-range expression rather than through
## a `_craft_id`-shaped fallback, so it has no second rule to disagree with and nothing here would catch a
## short `rack_ids`. That is a real gap and it is a different layer's to close.

const SCENE: String = "res://scenes/main.tscn"
## MainView._ready builds craft_ids/craft_options/machine_icons and seeds the world; three frames is the
## settle every other scene-booting layer in tools/ uses, and the §1 guards would go red rather than green
## if it were ever short.
const SETTLE_FRAMES: int = 3

var _main: MainView
var _hud: Hud
var _frames: int = 0

## The row set, read ONCE off the booted HUD. `_rows` is the count `_unlocked` walks; `_ids[i]` is the
## machine `_craft_id` puts in row i; `_locks[i]` is that machine's gating tech through the shipped rule.
## Cached because `_craft_id` does not read the research state — posing a state cannot change these — and
## caching them makes it explicit that every expectation below descends from the RESOLVER's answer rather
## than from a list written out in this file.
var _rows: int = 0
var _ids: Array[StringName] = []
var _locks: Array[StringName] = []

## Per row, whether the filter was ever seen opening it and ever seen closing it, accumulated across every
## probe. This is §2's vacuity guard: agreement on a row the filter never had an opinion about is not a
## result.
var _seen_open: Array[bool] = []
var _seen_shut: Array[bool] = []

## The research state the boot left behind, restored before the verdict so nothing downstream inherits a
## world where the whole tech tree is already paid for.
var _boot_research: Dictionary = {}


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== works row identity ==")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return
	process_frame.disconnect(_on_frame)
	_run()


## Overwrite the live research set IN PLACE rather than by assignment, so anything else in the booted
## scene holding a reference to that dictionary keeps seeing the same object. The layer runs every probe
## inside one frame callback with no await in it, so no `_process` observes an intermediate state.
func _pose_research(granted: Dictionary) -> void:
	var live: Dictionary = _hud.sim.research
	live.clear()
	for tid: StringName in granted:
		live[tid] = true


## The rows the counter should open if `granted` were the whole of what is researched — worked out from
## `_craft_id`'s ids, through the same `ResearchRules.locking_tech` the filter consults. One half of the
## comparison; `open_machines()` is the other.
func _expected_open(granted: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i: int in _rows:
		var lock: StringName = _locks[i]
		if lock == &"" or granted.has(lock):
			out.append(i)
	return out


func _as_set(rows: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	for i: int in rows:
		out[i] = true
	return out


## Every row the two answers disagree about, as a sentence naming the row and the machine `_craft_id` puts
## in it. Empty means agreement. It reports the ROW because that is the thing a reader has to go and look
## at: an index into two lists that have drifted apart.
func _disagreements(expected: Array[int], filtered: Array[int]) -> PackedStringArray:
	var want: Dictionary = _as_set(expected)
	var got: Dictionary = _as_set(filtered)
	var out: PackedStringArray = []
	for i: int in _rows:
		if want.has(i) == got.has(i):
			continue
		var id: String = String(_ids[i]) if i < _ids.size() else "?"
		var lock: String = String(_locks[i]) if i < _locks.size() else "?"
		out.append("row %d is %s (gated by %s), which the counter %s and the filter %s"
			% [i, id, ("nothing" if lock == "" else lock),
				("would show" if want.has(i) else "would hide"),
				("shows" if got.has(i) else "hides")])
	return out


func _say(lines: PackedStringArray) -> String:
	return "; ".join(lines) if not lines.is_empty() else "none"


## One probe: pose a research state, ask both resolvers, require them to agree on every row. The observed
## decisions are recorded per row on the way through, so §2 can afterwards prove each row was genuinely
## filtered rather than waved past.
func _probe(what: String, granted: Dictionary) -> void:
	_pose_research(granted)
	var filtered: Array[int] = _hud.open_machines()
	var expected: Array[int] = _expected_open(granted)
	var got: Dictionary = _as_set(filtered)
	for i: int in _rows:
		if got.has(i):
			_seen_open[i] = true
		else:
			_seen_shut[i] = true
	var gap: PackedStringArray = _disagreements(expected, filtered)
	_check(gap.is_empty(),
		"with %s researched the filter opens %d of %d rows and every one of them is the machine `_craft_id` puts there (%s)"
			% [what, filtered.size(), _rows, _say(gap)])


func _run() -> void:
	_hud = _main._hud

	# --- 1. THE STATE IS REAL, AND SO ARE THE ROWS ---------------------------------------------
	# Nothing below this section means anything without it. Every id here comes off a HUD that MainView
	# built during its own `_ready`; the layer sets no field on it. The guards go red if the scene did not
	# finish booting, if the counter has no rows, if the resolver handed back the empty name, or if two
	# rows resolve to one machine — each of which would let the agreement in §2 hold over nothing.
	_check(_hud != null, "MainView built a HUD and it is the one the game draws")
	if _hud == null:
		_verdict("check_row_identity")
		return
	_check(_hud.sim != null, "the HUD holds the live sim — the filter reads `sim.is_researched` off it")
	_boot_research = _hud.sim.research.duplicate()

	_rows = _hud.craft_options.size()
	_check(_rows > 0, "the counter has rows to resolve (%d machines in WORKS)" % _rows)
	_check(_hud.machine_icons.size() > 0,
		"and `machine_icons` has entries in it (%d), so `_craft_id`'s fallback has material to return"
			% _hud.machine_icons.size())
	if _rows == 0:
		_verdict("check_row_identity")
		return

	var blank: PackedStringArray = []
	var unplaceable: PackedStringArray = []
	var seen: Dictionary = {}
	var duplicated: PackedStringArray = []
	var gated: int = 0
	var free: int = 0
	for i: int in _rows:
		var id: StringName = _hud._craft_id(i)
		_ids.append(id)
		_locks.append(ResearchRules.locking_tech(id))
		_seen_open.append(false)
		_seen_shut.append(false)
		if id == &"":
			blank.append("row %d" % i)
		elif not _main._machine_defs_by_id.has(id):
			unplaceable.append("row %d wants %s" % [i, String(id)])
		if seen.has(id):
			duplicated.append("rows %d and %d both resolve to %s" % [int(seen[id]), i, String(id)])
		seen[id] = i
		if _locks[i] == &"":
			free += 1
		else:
			gated += 1

	_check(blank.is_empty(),
		"THE RESOLVER RETURNED REAL IDS: every one of the %d rows names a machine, not the empty name (%s)"
			% [_rows, _say(blank)])
	_check(unplaceable.is_empty(),
		"and every one of them is a machine MainView can actually resolve and place (%s)" % _say(unplaceable))
	_check(duplicated.is_empty(),
		"no two rows resolve to the same machine — %d distinct ids across %d rows (%s)"
			% [seen.size(), _rows, _say(duplicated)])
	# BOTH POLARITIES HAVE TO EXIST for §2 to be a test at all. With no gated rows the filter can never
	# say no and every probe compares one full set against another; with no free rows the "all researched"
	# probe is the only one that opens anything.
	_check(gated > 0 and free > 0,
		"the row set spans both cases the filter decides between: %d gated by a tech, %d freely craftable"
			% [gated, free])

	# --- 2. THE PROPERTY: ROW BY ROW, UNDER EVERY STATE THAT SEPARATES THE ROWS ----------------
	# One tech at a time, so a locked row is open in exactly one probe and shut in the rest. A build whose
	# two lists have drifted opens rows it should not — `_unlocked` reads `&""` past the end of
	# `craft_ids` and `locking_tech(&"")` is "freely craftable" — and the probe names the row and the
	# machine `_craft_id` says is standing in it.
	var techs: Array[StringName] = []
	for i: int in _rows:
		if _locks[i] != &"" and not (_locks[i] in techs):
			techs.append(_locks[i])
	_check(techs.size() > 1,
		"the rows are gated by %d different techs, so a probe can separate them" % techs.size())

	_probe("nothing", {})
	for tid: StringName in techs:
		_probe("only " + String(tid), {tid: true})
	var everything: Dictionary = {}
	for tid: StringName in ResearchRules.TECHS:
		everything[tid] = true
	_probe("the whole tree", everything)

	# THE PROBES ACTUALLY FILTERED. A row the filter opened in every single probe was never gated by
	# anything it read, whatever `_craft_id` says about it — which is the exact state a short `craft_ids`
	# produces, and it would otherwise sail through every comparison above as an agreement.
	var never_shut: PackedStringArray = []
	var never_open: PackedStringArray = []
	for i: int in _rows:
		if _locks[i] != &"" and not _seen_shut[i]:
			never_shut.append("row %d (%s, gated by %s)" % [i, String(_ids[i]), String(_locks[i])])
		if not _seen_open[i]:
			never_open.append("row %d (%s)" % [i, String(_ids[i])])
	_check(never_shut.is_empty(),
		"EVERY GATED ROW WAS SEEN SHUT at least once — the agreement was tested at both polarities, not read off a constant (%s)"
			% _say(never_shut))
	_check(never_open.is_empty(),
		"and every row was seen open at least once, so no row is unreachable in the counter (%s)"
			% _say(never_open))

	# --- 3. THE REASON, RECORDED UNDER THE PROPERTY -------------------------------------------
	# `_craft_id`'s fallback is unreachable and `_unlocked` never reads past the end, because main.gd
	# appends to craft_opts, craft_ids and machine_icons in one loop over `_craftable`. This is why §2
	# holds today; it is deliberately NOT what §2 asserts, because the invariant is the agreement and the
	# lengths are one implementation of it.
	_check(_hud.craft_ids.size() >= _rows,
		"the reason it holds: craft_ids covers every row (%d ids for %d rows), so the fallback never fires and the filter never reads past the end"
			% [_hud.craft_ids.size(), _rows])
	# AND THE SHAPE A BREAK WOULD TAKE. `machine_icons` is keyed by the same def ids in the same order, so
	# the fallback would hand back the RIGHT machine while the filter was reading the empty name: a short
	# craft_ids costs the filter its id and not the counter its identity, and the rows it damages all move
	# the same way, from hidden to shown. Recorded because it is what makes §2's output predictable, and
	# it is a fact about main.gd that a future edit can take away without touching either resolver.
	var icon_keys: Array = _hud.machine_icons.keys()
	var fallback_gap: PackedStringArray = []
	for i: int in _rows:
		var fb: StringName = icon_keys[i] if i < icon_keys.size() else &""
		if fb != _ids[i]:
			fallback_gap.append("row %d: %s vs %s" % [i, String(fb), String(_ids[i])])
	_check(fallback_gap.is_empty(),
		"and the fallback derivation names the same machine on every row today (%s)" % _say(fallback_gap))

	# --- 4. THE COMPARATOR CAN SAY NO ---------------------------------------------------------
	# Everything above is a green printed by `_disagreements` returning empty, and a comparator that
	# always returns empty prints the identical run. So it is handed a WRONG expectation, on the same
	# state, in the same run: one row flipped out of the set it belongs in. It has to report exactly that
	# row, and it has to name it — a comparator that noticed but could not say which row would leave a
	# future reader with a red they cannot act on.
	#
	# The wrong answer is built from the FILTER'S OWN output rather than from `_expected_open`, so this
	# control holds whether or not §2 agreed. On a build where the two lists have drifted, §2 is already
	# red and the last thing its reader needs is a control that goes red alongside it and reads as a
	# second, separate defect.
	_pose_research({})
	var honest: Array[int] = _hud.open_machines()
	var flipped: Array[int] = []
	var dropped: int = -1
	for i: int in honest:
		if dropped < 0:
			dropped = i
			continue
		flipped.append(i)
	_check(dropped >= 0, "there was an open row to withhold from the comparator (row %d)" % dropped)
	var caught: PackedStringArray = _disagreements(flipped, honest)
	_check(caught.size() == 1 and caught[0].begins_with("row %d " % dropped),
		"AND IT REJECTS A WRONG ANSWER: withholding row %d from the expectation is reported, and only that row (%s)"
			% [dropped, _say(caught)])

	# Put the world back the way the boot left it — the tree runs at least one more frame after `quit()`.
	_pose_research(_boot_research)
	var restored: bool = _hud.sim.research.size() == _boot_research.size()
	for tid: StringName in _boot_research:
		restored = restored and _hud.sim.research.has(tid)
	_check(restored, "the boot research state is back (%d techs)" % _boot_research.size())

	_verdict("check_row_identity",
		"%d WORKS rows, and under %d research states the row the filter opens is the machine `_craft_id` puts there"
			% [_rows, techs.size() + 2])
