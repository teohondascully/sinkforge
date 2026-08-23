extends "res://tools/check_base.gd"

## DOES THE GAME TEACH WHAT IT ACTUALLY DOES?
##
## The winch has quietly grown three techniques. You can chain a throw instead of landing, so an arc need
## never end (tools/check_traverse measures the rope crossing a gallery half again as fast as a full
## stride, but only for a player who knows that). The line bends around corners and whips you round them
## (tools/check_wrap measures four times the turn rate). And it will catch a fall you are already
## committed to. None of the three was mentioned anywhere in the game, which means the measured depth was
## real and unreachable: a build can be strictly better and play strictly worse.
##
## None of them can be taught up front, either. "The rope bends around corners" is noise to someone who
## has never swung one. They are situational lessons, so they are triggered by the situation, and that
## is the thing a harness can actually judge. Four properties:
##
##   IT FIRES WHEN IT'S TRUE.   Drive a real body into each situation (a release at speed in mid-air, a
##                              line caught on a spur, a drop that takes your footing), and the matching
##                              bubble must appear. A hint whose condition never occurs in play is not a
##                              lesson, it is a comment in a shipped file.
##   IT FIRES ONCE.             Repeat the situation and it must stay silent. A tip that re-teaches every
##                              swing is the reason players learn to ignore tips.
##   IT NAMES A REAL KEY.       Every key a hint tells you to press must be bound in the live InputMap.
##                              This is the failure no other layer can see: rebind GRAPPLE off F and the
##                              game keeps confidently telling a new player to press F forever.
##   YOU CAN READ IT IN TIME.   A bubble lives Hints.SHOW_SECONDS. Text longer than you can read twice in
##                              that window is text the player skips, which is the same as no hint.
##
##   godot --headless --path . --script res://tools/check_teaching.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## A bubble is shown for Hints.SHOW_SECONDS. Reading prose off a HUD runs about 200 wpm ≈ 5 chars/word,
## so ~17 chars/second, and a hint wants to be read TWICE (once to notice, once to understand). That
## puts the ceiling at a little over 150 characters for a 9-second bubble.
const TEXT_MAX: int = 150

## Single capital letters that are English words rather than key names, and so are not checked as keys.
## Everything else standing alone in caps in these strings is an instruction to press something.
const PROSE_LETTERS: Array[String] = ["A", "I"]

## THE HOOK AND THE LEDGE, borrowed from tools/check_wrap: a hook planted high, a spur jutting out below
## and to one side, and a body starting beyond the spur's tip and above its level, so the swing, not the
## plant, drives the line onto the corner.
const HOOK_COL: int = 36
const HOOK_ROW: int = 26
const SPUR_ROW: int = 31
const SPUR_FROM: int = 38
const SPUR_TO: int = 44
const BODY_COL: int = 48
const BODY_ROW: int = 29
const HALL_TOP: int = 20
const HALL_BOTTOM: int = 46
const HALL_LEFT: int = 30
const HALL_RIGHT: int = 58

const SWING_FRAMES: int = 150
const DROP_ROWS: int = 22            ## a fall tall enough to cost the landing (see Player.STAGGER_MAX)
const DROP_FRAMES: int = 180

func _initialize() -> void:
	print("== does the game teach what it actually does ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_teaching", "every technique is taught, once, in real keys, in time to read")


## A SLOT OF THIS LAYER'S OWN, SET BEFORE THE SCENE EXISTS.
##
## `_judge_persistence` drives the real F5/F9 verbs, and `MainView.save_path` defaults to the game's
## canonical slot, so the first version of that test **rewrote the slot `save_sentinel` had just planted a
## canary in**, and the harness correctly declared the whole run moot. It was the isolated `user://` and
## never the player's real save, but the rule is not "do not destroy player data", it is "no layer writes
## the save slot", and the sentinel exists precisely so that a layer which starts writing saves cannot do
## it quietly. **The guard caught a new writer on its first run**, which is the only useful moment to catch
## one.
##
## Static and read at call time, so it must be set before anything can read it, and cleaned up after:
## a layer that tidies only the file it first thought of leaves litter for the next run to trip over.
const TEST_SLOT: String = "user://check_teaching.save"

func _run() -> void:
	MainView.save_path = TEST_SLOT
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var hints: Hints = main._hints

	_judge_texts(hints)
	await _judge_rope(main, hints)
	await _judge_sapling(main, hints)
	await _judge_persistence(main, hints)

	main.queue_free()
	await physics_frame
	for leftover: String in [TEST_SLOT, TEST_SLOT + SaveGame.BAK_SUFFIX]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))


## HAS THIS HINT LATCHED YET? Waits a bounded number of frames for it, and says how long it took.
##
## THIS IS A FIX FOR A CI-ONLY RED, AND THE RACE IS STRUCTURAL RATHER THAN UNLUCKY. The hints are noted in
## MainView._process (main.gd:1205, via :749). This layer drives the body with `await physics_frame`, and
## the drop loop below breaks on the very frame `on_floor and worst > 0.0` first holds, then asserted the
## hint on the next line. A GDScript coroutine resumes synchronously when the signal fires, so at that
## point ZERO process frames have necessarily run since the landing, and whether the hint has been noted
## depends entirely on whether `on_floor` happened to lag `stagger` by a frame. It did on both dev boxes.
## It did not on CI, and the layer failed there while passing everywhere else it was tried.
##
## Waiting is safe rather than lenient because the window is real: stagger is set to STAGGER_MAX = 0.26s and
## decays by delta per physics frame, so there are ~15 frames in which _process can legitimately observe it.
## Twelve is inside that and nowhere near it: a hint that has not latched in twelve process frames has not
## latched, and still fails.
##
## All three hint assertions go through here, not just the one that turned red. `chain` breaks out of its
## loop after two physics frames and `wrapped` after a full one, which are the same bug with more slack:
## the kind that waits for a slower machine. Fixing the instance and leaving the class is how this comes
## back next month as somebody else's afternoon.
const HINT_SETTLE: int = 12

func _latched(hints: Hints, id: StringName) -> bool:
	for i: int in HINT_SETTLE:
		if hints._done.has(id):
			if i > 0:
				print("    (%s latched %d process frame(s) after the situation)" % [id, i])
			return true
		await process_frame
	return hints._done.has(id)


## --- what the hints SAY -------------------------------------------------------------------------

## Every bubble in the game, pack-acquisition and state-edge alike, on one list.
func _all_hints(hints: Hints) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(hints._defs)
	out.append_array(hints._moments)
	return out


func _judge_texts(hints: Hints) -> void:
	var all: Array[Dictionary] = _all_hints(hints)
	var bound: Dictionary = _bound_labels()

	# Ids must be unique across BOTH tables: active_text() resolves by id, so a collision means one hint
	# silently shows the other's text and the shadowed one can never be seen.
	var seen: Dictionary = {}
	var dupes: int = 0
	for h: Dictionary in all:
		var id: StringName = h["id"]
		if seen.has(id):
			dupes += 1
			printerr("    two hints share the id %s" % id)
		seen[id] = true
	print("  %d hints (%d on pickup, %d on the situation); %d bound key labels"
		% [all.size(), hints._defs.size(), hints._moments.size(), bound.size()])
	_check(dupes == 0, "every hint has its own id (%d collisions)" % dupes)

	# ...and every key any of them tells you to press is a key the game is actually listening for.
	var re: RegEx = RegEx.create_from_string("\\b(LMB|RMB|MMB|SPACE|ESC|F5|F9|[A-Z])\\b")
	var unbound: int = 0
	var named: Dictionary = {}
	for h: Dictionary in all:
		var text: String = str(h["text"])
		for m: RegExMatch in re.search_all(text):
			var key: String = m.get_string(1)
			if PROSE_LETTERS.has(key):
				continue
			named[key] = true
			if not bound.has(key):
				unbound += 1
				printerr("    hint %s tells you to press %s, which is bound to nothing" % [h["id"], key])
	var keys: Array = named.keys()
	keys.sort()
	print("  the hints tell you to press: %s" % ", ".join(keys))
	_check(unbound == 0, "every key a hint names is really bound (%d dead)" % unbound)

	# ...and every bubble is short enough to read inside its own lifetime.
	var longest: int = 0
	var longest_id: StringName = &""
	var over: int = 0
	for h: Dictionary in all:
		var n: int = str(h["text"]).length()
		if n > longest:
			longest = n
			longest_id = h["id"]
		if n > TEXT_MAX:
			over += 1
			printerr("    hint %s is %d chars — too long to read twice in %.0fs"
				% [h["id"], n, Hints.SHOW_SECONDS])
	print("  the longest bubble is %s at %d chars (a %.0fs read allows about %d)"
		% [longest_id, longest, Hints.SHOW_SECONDS, TEXT_MAX])
	_check(over == 0, "...and every bubble is readable in the time it is shown (%d too long)" % over)

	# A hint with no text queues an invisible bubble and eats a slot for SHOW_SECONDS.
	var blank: int = 0
	for h: Dictionary in all:
		hints._active = h["id"]
		if hints.active_text().strip_edges().is_empty():
			blank += 1
			printerr("    hint %s resolves to nothing" % h["id"])
	hints._active = &""
	_check(blank == 0, "...and every id resolves to real text (%d blank)" % blank)

	# NON-VACUITY. Every one of the four assertions above counts a fault among the hints that EXIST, and all
	# four are satisfied perfectly by a game that teaches nothing at all: no duplicate ids, no dead keys, no
	# overlong bubbles and no blank text, over an empty table. The population is `hints._defs` +
	# `hints._moments`, which is to say it is defined by the thing under test, so every hint that goes
	# missing removes a chance to fail, and the layer gets quieter as the teaching gets worse.
	#
	# Both tables are floored SEPARATELY. A single combined floor is satisfied by the larger one surviving
	# alone, and they teach different things: `_defs` fires when you pick something up, `_moments` when the
	# world does something to you. Losing either is losing half the teaching.
	#
	# The numbers are deliberately under today's counts (12 and 6). Their job is to catch a table that
	# vanished or halved, not to police the count: pruning a hint is a design decision and should not have
	# to argue with a test.
	_check(hints._defs.size() >= 8,
		"%d pickup hints exist to be judged" % hints._defs.size())
	_check(hints._moments.size() >= 4,
		"%d situation hints exist to be judged" % hints._moments.size())
	# ...and the key sweep found keys. A regex that stopped matching empties `named`, and the "every key a
	# hint names is really bound" assertion above would then pass over nothing and report perfect health.
	_check(named.size() >= 4,
		"the hints were found to name %d distinct keys" % named.size())


## Every key label the live InputMap will actually respond to.
func _bound_labels() -> Dictionary:
	var out: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		for e: InputEvent in InputMap.action_get_events(action):
			var k := e as InputEventKey
			if k != null:
				var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
				out[OS.get_keycode_string(code).to_upper()] = true
			var mb := e as InputEventMouseButton
			if mb != null:
				match mb.button_index:
					MOUSE_BUTTON_LEFT:
						out["LMB"] = true
					MOUSE_BUTTON_RIGHT:
						out["RMB"] = true
					MOUSE_BUTTON_MIDDLE:
						out["MMB"] = true
	return out


## --- when the hints FIRE ------------------------------------------------------------------------

## Drive one real body through all three rope situations in one run and watch what the game says.
func _judge_rope(main: MainView, hints: Hints) -> void:
	var sim: FactorySim = main.sim
	var p: Player = main._player
	_carve(sim)
	p.auto_input = false
	p.grapple.cut()
	p.place(Vector2(float(BODY_COL) * CELL + 16.0, float(BODY_ROW) * CELL))
	for _i: int in 4:
		await physics_frame
	# Forget anything the opening already taught, so what follows is measured and not inherited.
	hints._done.clear()
	hints._queue.clear()
	hints._active = &""

	p.grapple.fire(p.hand(), Vector2(float(HOOK_COL) * CELL + 16.0, float(HOOK_ROW) * CELL + 16.0))
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	if p.grapple.state != Grapple.State.ANCHORED:
		_failures += 1
		printerr("  FAIL: the hook never planted — nothing to teach")
		return

	# THE BEND. Swing in under the spur; the line has to catch, and the game has to say so.
	var fastest: float = 0.0
	var pivots: int = 0
	for _i: int in SWING_FRAMES:
		p.input_dir = -1.0
		await physics_frame
		fastest = maxf(fastest, p.velocity.length())
		pivots = maxi(pivots, p.grapple.pivots.size())
	print("  swung under the spur at up to %.0f px/s; the line took %d pivot(s) at its most bent"
		% [fastest, pivots])
	_check(await _latched(hints, &"wrapped"),
		"the first time the line BENDS, the game says what just happened")

	# THE CHAIN. Let go while airborne and moving: the frame a second throw would have paid off.
	var released: float = 0.0
	for _i: int in SWING_FRAMES:
		p.input_dir = 1.0
		await physics_frame
		# Well clear of the threshold, not a hair over it: a driver that releases at the first frame it
		# qualifies is measuring the tolerance of its own arithmetic rather than the game's rule.
		if not p.on_floor and p.velocity.length() > MainView.CHAIN_HINT_SPEED * 1.4:
			released = p.velocity.length()
			p.grapple.cut()
			await physics_frame
			await physics_frame
			break
	print("  released the line airborne at %.0f px/s (the hint wants over %.0f)"
		% [released, MainView.CHAIN_HINT_SPEED])
	_check(released > 0.0, "the swing got fast enough in the air to be worth chaining (%.0f px/s)" % released)
	_check(await _latched(hints, &"chain"),
		"...and letting go at speed is where the game mentions throwing again")

	# THE CATCH. Drop the body far enough that the landing costs its footing.
	p.grapple.cut()
	var floor_row: int = HALL_BOTTOM + 1
	var col: int = HALL_RIGHT - 2          # clear of both the spur and the hook's roof block
	p.place(Vector2(float(col) * CELL + 16.0, float(floor_row - DROP_ROWS) * CELL))
	var worst: float = 0.0
	for _i: int in DROP_FRAMES:
		p.input_dir = 0.0
		await physics_frame
		worst = maxf(worst, p.stagger)
		if p.on_floor and worst > 0.0:
			break
	print("  dropped %d rows and landed with %.2fs of stagger" % [DROP_ROWS, worst])
	_check(worst > 0.0, "the drop actually cost the landing (%.2fs stagger)" % worst)
	_check(await _latched(hints, &"hard_landing"),
		"...and a landing that costs your footing is where the game offers the rope")

	# ONCE. Everything above is now latched; doing it all again must produce nothing new.
	var taught: int = hints._done.size()
	var queued: int = hints._queue.size()
	p.place(Vector2(float(BODY_COL) * CELL + 16.0, float(BODY_ROW) * CELL))
	p.grapple.fire(p.hand(), Vector2(float(HOOK_COL) * CELL + 16.0, float(HOOK_ROW) * CELL + 16.0))
	for _i: int in SWING_FRAMES:
		p.input_dir = -1.0
		await physics_frame
	p.grapple.cut()
	p.place(Vector2(float(col) * CELL + 16.0, float(floor_row - DROP_ROWS) * CELL))
	for _i: int in DROP_FRAMES:
		await physics_frame
		if p.on_floor and p.stagger > 0.0:
			break
	print("  a second run through the same three moments taught %d more thing(s)"
		% (hints._done.size() - taught))
	_check(hints._done.size() == taught and hints._queue.size() == queued,
		"...and none of it is ever said twice (%d hints latched, %d queued)"
			% [hints._done.size(), hints._queue.size()])


## THE SAPLING'S SECOND HALF: the one lesson whose situation is a PLAYER ACTION rather than a physics
## state, and therefore the one this layer's rope drills could never have reached.
##
## `UI-05` moved *"it grows into a NEW TREE: wood is renewable"* off the pickup bubble, where it was a
## second concept competing with the instruction, and onto the first sapling that actually roots, where
## it is a payoff rather than a promise. **That move is only honest if the payoff fires.** This layer's own
## standard: *"a hint whose condition never occurs in play is not a lesson, it is a comment in a shipped
## file"*, and a lesson relocated onto a condition nobody drives is exactly that, with the added insult
## that the text it replaced is gone.
##
## Driven through `try_build`, the real verb, with a real selection, not `sim.plant_sapling`, which would
## bypass the poke in `main.gd` that is the actual thing under test and pass while it was missing.
func _judge_sapling(main: MainView, hints: Hints) -> void:
	var sim: FactorySim = main.sim
	var soil := Vector2i(BODY_COL, HALL_BOTTOM)          # inside the carved hall, on its stone floor
	sim.set_solid(soil + Vector2i(0, 1), &"earth")       # SAPLING_SOILS is [&"earth"] — give it ground
	# ESTABLISH "YOU DO NOT HAVE ONE" BEFORE TESTING THE FIRST ONE, and this setup is itself a finding.
	# `Hints._init` snapshots the pack, deliberately: whatever you are already holding at construction is
	# not a fresh acquisition. This layer boots with `dev_start` at its default, and THE DEV KIT ALREADY
	# CONTAINS A SAPLING, so `_had[&"sapling"]` is true from frame zero and the pickup lesson can never
	# fire in this fixture. Measured, not assumed: the first version of this check failed with
	# `had_sapling=true` and `_done` holding five other ids.
	#
	# So the pre-state is constructed rather than assumed: empty the slot, re-arm the snapshot the same
	# way a load does, and only then acquire. That is the state a real opening player is in, and it is the
	# difference between testing the edge and testing the kit.
	sim.inventory.erase(&"sapling")
	hints._snapshot()
	sim.inventory[&"sapling"] = 2
	var idx: int = -1
	var slots: Array[Dictionary] = sim.inventory_slots()
	for i: int in slots.size():
		if StringName(slots[i]["item"]) == &"sapling":
			idx = i
	_check(idx >= 0, "the sapling is in the pack and selectable (slot %d)" % idx)
	if idx < 0:
		return
	main._inv_selected = idx
	_check(await _latched(hints, &"sapling"),
		"picking up a sapling teaches how to plant it")
	var before: bool = hints._done.has(&"planted")
	_check(not before,
		"CONTROL: the payoff has NOT fired before anything is planted (if it had, the check below is empty)")
	var rooted: bool = main.try_build(soil)
	_check(rooted, "the real place verb roots a sapling at %s" % soil)
	if not rooted:
		return
	_check(await _latched(hints, &"planted"),
		"...and the renewability lesson UI-05 moved off the pickup lands on the plant that earns it")
	# ONCE, the same standard the rope moments are held to.
	var taught: int = hints._done.size()
	var second: bool = main.try_build(soil + Vector2i(-1, 0))
	print("  a second plant (%s) taught %d more thing(s)"
		% ["rooted" if second else "refused", hints._done.size() - taught])
	_check(hints._done.size() == taught, "...and it is never said twice")


## UI-04: "IT FIRES ONCE" HAD A PERIOD, AND THE PERIOD WAS ONE PROCESS.
##
## This layer already holds the game to *"none of it is ever said twice"* and the game passed, because both
## the assertion and the play session live inside a single boot. `Hints._done` was never written to disk,
## so **every state-edge lesson re-taught itself in full on every launch**: the grapple, the wrap, the
## chain, the hard landing, the aquifer. That is the same failure the layer's own docstring names (*"a tip
## that re-teaches every swing is the reason players learn to ignore tips"*) at a period long enough that
## nothing inside one process could see it.
##
## Driven through `_save_game` and `_load_game`, the real F5/F9 verbs, against a FRESH `Hints` standing in
## for a new launch. Testing `restore_taught` directly would prove the function works and prove nothing
## about the two lines in `main.gd` that call it, which is where a wrong key name lives.
func _judge_persistence(main: MainView, hints: Hints) -> void:
	var taught: Array[String] = hints.taught_ids()
	_check(taught.size() >= 5,
		"CONTROL: %d lessons have been given, so there is something for the save to carry (%s)"
			% [taught.size(), ", ".join(taught)])
	if taught.is_empty():
		return
	main._save_game()
	# A FRESH SESSION, as far as the hint system is concerned: `Hints.new` rebuilds `_done` empty, which is
	# exactly the state a relaunch produces and exactly the state that used to survive a load.
	var reborn := Hints.new(main.sim)
	main._hints = reborn
	_check(reborn.taught_ids().is_empty(),
		"CONTROL: a fresh hint system starts having taught nothing (this is what a relaunch is)")
	main._load_game()
	var after: Array[String] = reborn.taught_ids()
	var lost: Array[String] = []
	for id: String in taught:
		if not after.has(id):
			lost.append(id)
	_check(lost.is_empty(), "a save carries which lessons have already been given%s"
		% ("" if lost.is_empty() else " — RE-TEACHES: " + ", ".join(lost)))
	# ...and it must not invent any, which is the failure mode of restoring a list you did not write.
	var extra: Array[String] = []
	for id: String in after:
		if not taught.has(id):
			extra.append(id)
	_check(extra.is_empty(), "...and marks nothing taught that never was%s"
		% ("" if extra.is_empty() else " — INVENTED: " + ", ".join(extra)))
	# An id the game no longer has must not be able to suppress a future lesson that reuses its name.
	reborn.restore_taught(["a_lesson_that_does_not_exist"])
	_check(not reborn.taught_ids().has("a_lesson_that_does_not_exist"),
		"...and an unknown id in an old save is dropped rather than latched forever")
	main._hints = hints          # put the layer's own instance back for anything that follows


## The chamber, the hook's roof, the spur the line catches on, and a floor to land hard on.
func _carve(sim: FactorySim) -> void:
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		for y: int in range(HALL_TOP, HALL_BOTTOM + 1):
			sim.mine(Vector2i(x, y))
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		sim.set_solid(Vector2i(x, HALL_BOTTOM + 1), &"stone")
	for y: int in range(HOOK_ROW - 2, HOOK_ROW + 1):
		for x: int in range(HOOK_COL - 2, HOOK_COL + 1):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(SPUR_FROM, SPUR_TO + 1):
		sim.set_solid(Vector2i(x, SPUR_ROW), &"stone")
