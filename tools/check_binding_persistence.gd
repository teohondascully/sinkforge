extends "res://tools/check_base.gd"

## Harness layer: A SETTINGS FILE MAY NOT REINSTATE A DUPLICATE BINDING ON EVERY BOOT. Headless, no scene:
## `Settings` and `Controls` are pure statics over ConfigFile and InputMap, so the whole contract checks
## in milliseconds against the REAL load path.
##   godot --headless --path . --script res://tools/check_binding_persistence.gd
##
## WHAT IT GUARDS. `rebind` guards the door: since MNU-29a it cannot create a duplicate, because it takes
## the colliding event off whoever held it. Nothing counted what was already in the room. `load_settings`
## read the `bindings` section off disk and handed it straight to `apply_bindings` with no conflict check
## anywhere on that path, so a config written by the PRE-FIX build (or hand-edited, or carried over from
## another machine) put its duplicate back on every launch, and both actions fired on every press. The
## CONTROLS page would draw the clash if the player opened it, which makes the defect visible rather than
## silent; nothing anywhere resolved it.
##
## THE FIXTURE IS A FILE, NOT A DICTIONARY, and that distinction is the whole reason this layer exists.
## Asserting against a hand-built `Settings.bindings` would demonstrate the RESOLVER and say nothing about
## whether a config on disk can reach it. `_pose` writes the bytes with a bare `ConfigFile` (bypassing
## `save_settings`, and therefore bypassing the door), and every case then goes through
## `Settings.load_settings()` exactly as a boot does. The mechanism was confirmed by reading the code; this
## is what makes it a REACHABLE fact.
##
## EVERY CASE POSES ITS DEFECT AND THEN PROVES THE POSE, before loading anything. A fixture that quietly
## failed to write the duplicate prints the identical green to a build that repairs one, and this repo has
## been bitten by that exact shape more than once: §1 asserts the file is complete, that it really does
## imply two actions on one key, and that the collision sits where the defect lives.
##
## §1 IS ON A NON-FIRST EVENT ON PURPOSE. The original fix's own demonstration (`jump` -> `W`) passed only
## because `W` happens to be `sf_up`'s FIRST event, so it was run on the one input where the bug was
## visible to the instrument measuring it. Here `jump` takes the UP ARROW, which is `sf_up`'s SECOND event,
## and `_first_event_clashes` recomputes the SUPERSEDED `binding_label` comparison on the same file in the
## same run to show it reports nothing at all. A control that travels inside the measurement cannot
## disagree about the state it was taken from.
##
## WHAT THIS LAYER DOES NOT COVER, stated so it is not mistaken for coverage:
## * Whether the CONTROLS page draws a clash it still has. That is `check_binding_conflict` (rows) and
##   `check_hud_layout` (pixels). Everything here is asserted against `InputMap` through
##   `Settings.event_labels`, at the per-event grain both the detector and the resolver compare at.
## * `check_binding_conflict`'s §5 says in prose that it PINS the load path's old permissiveness. It does
##   not, and never did: it poses its duplicate by calling `Settings._apply_action` directly and never
##   calls `load_settings`, so it pins the behaviour of the applier and is untouched by the reconciliation
##   this layer asserts. Its green is unchanged and unweakened, but the sentence in its docstring about
##   the load path is now stale, and only a human editing that file can fix it.

const TEST_PATH: String = "user://binding_persistence_check.cfg"

## The key order §4 wrote its two overrides in, kept so §6 can prove the OPPOSITE order resolves the same
## duplicate the same way. Captured from the file rather than from the literal, because the question is
## what `ConfigFile` handed back, not what was passed to it.
var _order_first: PackedStringArray = []


func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


## Write a settings file the way the pre-fix build wrote one: bindings straight into the section, no
## `save_settings`, no `rebind`, no conflict check. The point of the fixture is a file whose contents no
## current code path would produce.
func _pose(overrides: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for action: StringName in overrides:
		cfg.set_value("bindings", String(action), overrides[action])
	cfg.save(TEST_PATH)


## The order the `bindings` keys come back from the file in: the basis a resolver must NOT use.
func _disk_order() -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(TEST_PATH) != OK or not cfg.has_section("bindings"):
		return PackedStringArray()
	return cfg.get_section_keys("bindings")


## What the FILE says every action is bound to: its override where the file carries one, the shipped
## default where it does not, which is precisely the state `load_settings` is about to apply.
##
## The failed-load path returns an EMPTY map, which is the value that fails `_disk_is_whole` rather than
## the value that makes a duplicate assertion look satisfied. Every case calls that guard first.
func _disk_specs() -> Dictionary:
	var out: Dictionary = {}
	var cfg := ConfigFile.new()
	if cfg.load(TEST_PATH) != OK:
		return out
	var d: Dictionary = Controls.defaults()
	for action: StringName in d:
		var key: String = String(action)
		out[action] = cfg.get_value("bindings", key) if cfg.has_section_key("bindings", key) else d[action]
	return out


## Labels through the SHIPPED labeller and the SHIPPED spec path, so a fixture cannot be right about a key
## the game would read differently.
func _caps_of(specs: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for s: Variant in specs:
		out.append(Settings.event_label(Controls.event_from_spec(s as Dictionary)))
	return out


## action -> every cap the FILE gives it.
func _disk_caps() -> Dictionary:
	var out: Dictionary = {}
	var specs: Dictionary = _disk_specs()
	for action: StringName in specs:
		out[action] = _caps_of(specs[action] as Array)
	return out


## action -> every cap the LIVE InputMap gives it, read through `Settings.event_labels`: the same
## accessor `Hud._binding_clashes` and `rebind` compare, at the same per-event grain.
func _live_caps() -> Dictionary:
	var out: Dictionary = {}
	for action: StringName in Controls.defaults():
		out[action] = PackedStringArray(Settings.event_labels(action))
	return out


## TWO ACTIONS ON ONE KEY, written as a function OF a caps table rather than of the game, so the same
## predicate reads the file before the load and the InputMap after it and cannot drift between the two.
func _clashes(caps_by_action: Dictionary) -> PackedStringArray:
	var owner: Dictionary = {}
	var out: PackedStringArray = []
	for action: StringName in caps_by_action:
		var caps: PackedStringArray = caps_by_action[action]
		for label: String in caps:
			if owner.has(label):
				out.append("\"%s\" is both %s and %s" % [label, String(owner[label]), String(action)])
			else:
				owner[label] = action
	return out


## The SUPERSEDED comparison, kept verbatim in shape: one label per action, `events[0]`. It exists to be
## run beside the real one on the same state, so "the first-event predicate is blind to this" is a result
## and not a sentence.
func _first_event_clashes(caps_by_action: Dictionary) -> PackedStringArray:
	var trimmed: Dictionary = {}
	for action: StringName in caps_by_action:
		var caps: PackedStringArray = caps_by_action[action]
		var first: PackedStringArray = []
		if not caps.is_empty():
			first.append(caps[0])
		trimmed[action] = first
	return _clashes(trimmed)


func _say(caps: PackedStringArray) -> String:
	return ", ".join(caps) if not caps.is_empty() else "unbound"


func _live(action: StringName) -> PackedStringArray:
	return PackedStringArray(Settings.event_labels(action))


## One outcome list from the reconciliation report, as names. A mistyped `kind` would come back empty, so
## every list is asserted both ways somewhere in this file: §3 requires all three empty, §1/§4/§5 each
## require one of them to name an action.
func _report(kind: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var listed: Array = Settings.last_reconcile.get(kind, [])
	for a: Variant in listed:
		out.append(String(a))
	return out


## The fixture reached the checker at all: 25 actions, read back off the disk. Nothing below this line
## means anything without it.
func _disk_is_whole(where: String) -> void:
	var caps: Dictionary = _disk_caps()
	_check(FileAccess.file_exists(TEST_PATH), "%s: the posed config exists on disk" % where)
	_check(caps.size() == Controls.defaults().size(),
		"%s: and the file reads back as a whole binding set (%d of %d actions)"
			% [where, caps.size(), Controls.defaults().size()])


func _initialize() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Controls.register()
	Settings.path = TEST_PATH        # isolation: the dev's real settings.cfg is never opened or written
	Settings.persist = false
	Settings.reset_bindings()

	# --- 1. A CONFIG FROM BEFORE THE FIX, LOADED THE WAY A BOOT LOADS ONE -----------------------
	# `jump` on the UP ARROW is the live repro, and it is posed the way the pre-fix build wrote it: one
	# spec, because `rebind` used to replace the whole binding, so jump's pad button is already gone. The
	# arrow is `sf_up`'s SECOND event, which is the half of the space the original demonstration missed.
	_pose({Controls.JUMP: [{"key": KEY_UP}]})
	_disk_is_whole("posed pre-fix config")
	var posed: Dictionary = _disk_caps()
	var on_disk: PackedStringArray = _clashes(posed)
	_check(not on_disk.is_empty() and _say(on_disk).contains("\"UP\""),
		"THE FIXTURE IS REAL: the file itself puts two actions on one key before anything loads it (%s)"
			% _say(on_disk))
	var arrow: PackedStringArray = posed[Controls.UP]
	_check(arrow.size() > 1 and arrow[1] == "UP",
		"and the collision is on climb-up's SECOND event, not its first (%s)" % _say(arrow))
	_check(_first_event_clashes(posed).is_empty(),
		"the SUPERSEDED first-event comparison reports NOTHING about this file — the grain is the defect")

	var raw_posed: String = FileAccess.get_file_as_string(TEST_PATH)
	_check(not raw_posed.is_empty(), "the fixture has bytes in it (%d)" % raw_posed.length())

	Settings.load_settings()
	_check(InputMap.event_is_action(_key(KEY_UP), Controls.JUMP),
		"after the load the arrow does what the player bound it to: jump")
	_check(not InputMap.event_is_action(_key(KEY_UP), Controls.UP),
		"AND IT NO LONGER ALSO CLIMBS — one press, one action, which is the defect stated at the engine")
	_check(_live(Controls.UP).has("W"), "climb up KEPT W — one EVENT moved, not the binding (%s)"
		% _say(_live(Controls.UP)))
	_check(_live(Controls.UP).has("STICK UP"),
		"and kept its stick — a keyboard collision did not cost it the gamepad (%s)" % _say(_live(Controls.UP)))
	var live: PackedStringArray = _clashes(_live_caps())
	_check(live.is_empty(), "no two actions answer to one key anywhere in the live map (%s)"
		% ("all 25 clear" if live.is_empty() else _say(live)))
	_check(_report("moved").has("sf_up"), "the pass reports moving climb-up's arrow (%s)"
		% _say(_report("moved")))
	_check(_report("restored").is_empty() and _report("kept_duplicate").is_empty(),
		"and repaired nothing else — it resolves collisions, it does not rebuild bindings")

	# THE PERSIST GATE, which is the harness's own isolation and not a special case to route around: the
	# in-memory map above is already repaired, and the WRITE is the only thing `persist = false` withholds.
	_check(FileAccess.get_file_as_string(TEST_PATH) == raw_posed,
		"persist=false wrote NOTHING — the file still carries the duplicate the map no longer has")

	# --- 2. THE SAME FILE, THE SAME DUPLICATE, WITH THE GATE OPEN ------------------------------
	Settings.reset_bindings()        # still persist=false, so this cannot clobber the fixture
	_check(_live(Controls.UP).has("UP") and _live(Controls.JUMP).has("SPACE"),
		"back on the shipped defaults, so §2 measures a repair rather than re-reading §1's")
	Settings.persist = true
	Settings.load_settings()
	_check(InputMap.event_is_action(_key(KEY_UP), Controls.JUMP)
		and not InputMap.event_is_action(_key(KEY_UP), Controls.UP),
		"the same file resolves the same way on a second machine-state — the rule reads nothing that varies")
	_check(_clashes(_disk_caps()).is_empty(),
		"THE REPAIR IS PERSISTED: the file on disk no longer implies a duplicate (%s)"
			% _say(_clashes(_disk_caps())))
	_check(_say(_disk_caps()[Controls.UP]) == "W, STICK UP",
		"and it kept climb-up's other two events on the way through (%s)" % _say(_disk_caps()[Controls.UP]))
	_check(FileAccess.get_file_as_string(TEST_PATH) != raw_posed, "so the gate being open is what wrote it")

	Settings.load_settings()
	_check(_report("moved").is_empty(),
		"reloading the file it just wrote moves NOTHING — the repair converges instead of churning")
	_check(InputMap.event_is_action(_key(KEY_UP), Controls.JUMP)
		and not InputMap.event_is_action(_key(KEY_UP), Controls.UP),
		"and the second load leaves the same map as the first")

	# --- 3. NEGATIVE CONTROL: A CLEAN CONFIG IS APPLIED VERBATIM -------------------------------
	# Without this the layer passes on a reconciler that simply wipes every binding it does not like.
	Settings.reset_bindings()
	_pose({Controls.DROP: [{"key": KEY_J}, {"pad": JOY_BUTTON_Y}]})
	_disk_is_whole("posed clean config")
	var clean: Dictionary = _disk_caps()
	_check(_clashes(clean).is_empty(), "the clean fixture carries no duplicate (%s)" % _say(_clashes(clean)))
	_check(_say(clean[Controls.DROP]) == "J, PAD Y",
		"and it IS a config with a real override in it, not an empty file passing by default (%s)"
			% _say(clean[Controls.DROP]))
	var raw_clean: String = FileAccess.get_file_as_string(TEST_PATH)

	Settings.load_settings()
	var drift: PackedStringArray = []
	for action: StringName in Controls.defaults():
		var was: String = _say(clean[action])
		var now: String = _say(_live(action))
		if was != now:
			drift.append("%s: %s -> %s" % [String(action), was, now])
	_check(drift.is_empty(), "EVERY ONE of the 25 actions loaded exactly what the file said (%s)"
		% ("nothing moved" if drift.is_empty() else _say(drift)))
	_check(_report("moved").is_empty() and _report("restored").is_empty()
		and _report("kept_duplicate").is_empty(),
		"the pass reports doing nothing at all to a clean config")
	_check(Settings.bindings.size() == 1 and Settings.bindings.has(Controls.DROP),
		"and materialised no override for anyone else (%s)" % str(Settings.bindings.keys()))
	_check(FileAccess.get_file_as_string(TEST_PATH) == raw_clean,
		"a clean config comes out of a boot BYTE FOR BYTE as it went in, gate open")

	# --- 4. AN ACTION MAY NOT BOOT DEAD: the free default comes back ---------------------------
	# Both actions are overridden, so tier 1 of the precedence rule cannot separate them and the tie breaks
	# on `Controls.defaults()` order: `sf_left` is first in that table, so it keeps J. The dashboard is
	# left with nothing, and gets back its own default key, which nobody is holding.
	Settings.reset_bindings()
	_pose({Controls.LEFT: [{"key": KEY_J}], Controls.DASHBOARD: [{"key": KEY_J}]})
	_disk_is_whole("posed two-override collision")
	_order_first = _disk_order()
	var contested: PackedStringArray = _clashes(_disk_caps())
	_check(not contested.is_empty() and _say(contested).contains("\"J\""),
		"THE FIXTURE IS REAL: two overridden actions are both on J before the load (%s)" % _say(contested))

	Settings.load_settings()
	_check(_say(_live(Controls.LEFT)) == "J", "move left keeps the contested key (%s)"
		% _say(_live(Controls.LEFT)))
	_check(not _live(Controls.DASHBOARD).is_empty(),
		"THE DASHBOARD IS NOT LEFT UNBOUND — silence would be worse than the duplicate (%s)"
			% _say(_live(Controls.DASHBOARD)))
	_check(_say(_live(Controls.DASHBOARD)) == "G",
		"it is back on its own shipped default, which nothing else answers to (%s)"
			% _say(_live(Controls.DASHBOARD)))
	_check(_report("restored").has("sf_dashboard"),
		"and the pass says so, rather than a repair nobody can tell from an oversight (%s)"
			% _say(_report("restored")))
	_check(_clashes(_live_caps()).is_empty(), "the rescue introduced no second duplicate (%s)"
		% _say(_clashes(_live_caps())))

	# --- 5. ...AND WHEN NOTHING IS FREE, THE DUPLICATE STANDS, ON PURPOSE ----------------------
	# `sf_research` has exactly one default event, R, and the config hands R to move-left. There is nothing
	# to give it back. The decision is that it keeps firing on R (a duplicate the CONTROLS page can show
	# beats a verb with no key at all), and the decision has to be VISIBLE, because a live map holding a
	# duplicate looks identical whether the pass weighed it or never ran.
	Settings.reset_bindings()
	_pose({Controls.LEFT: [{"key": KEY_R}]})
	_disk_is_whole("posed unrescuable collision")
	var doomed: PackedStringArray = _clashes(_disk_caps())
	_check(not doomed.is_empty() and _say(doomed).contains("\"R\""),
		"THE FIXTURE IS REAL: move left is on research's only key before the load (%s)" % _say(doomed))

	Settings.load_settings()
	_check(_say(_live(Controls.RESEARCH)) == "R",
		"research still answers R — reconciling never takes an action's LAST event (%s)"
			% _say(_live(Controls.RESEARCH)))
	_check(Settings.binding_label(Controls.RESEARCH) != "unbound",
		"so the CONTROLS row shows a key rather than the word unbound")
	var standing: PackedStringArray = _clashes(_live_caps())
	_check(not standing.is_empty() and _say(standing).contains("\"R\""),
		"the duplicate SURVIVES, which is the outcome that was chosen (%s)" % _say(standing))
	_check(_report("kept_duplicate").has("sf_research"),
		"AND THE CHOICE IS ON THE RECORD — the only thing separating it from a pass that never looked (%s)"
			% _say(_report("kept_duplicate")))
	_check(not Settings.bindings.has(Controls.RESEARCH),
		"with research's entry left alone rather than rewritten with its own contents")

	# --- 6. PRECEDENCE DOES NOT COME FROM THE FILE'S KEY ORDER --------------------------------
	# The same two overrides as §4, written the other way round. A resolver that walked the config section
	# would hand J to the dashboard here and to move-left there, and the same player's profile would
	# resolve differently depending on the order a save, a hand edit or another machine left the keys in.
	Settings.reset_bindings()
	_pose({Controls.DASHBOARD: [{"key": KEY_J}], Controls.LEFT: [{"key": KEY_J}]})
	_disk_is_whole("posed collision, keys reversed")
	# The control on this case is the fixture itself: if `ConfigFile` handed both writes back in the SAME
	# order, the run cannot show that the order was ignored (only that the outcome held), and it says so
	# rather than printing the same green either way.
	var order_second: PackedStringArray = _disk_order()
	if _say(_order_first) == _say(order_second):
		_stand_down("bindings.file-order-control", "the file-order control",
			"ConfigFile returned the same key order for both writes (%s)" % _say(order_second))
	else:
		print("  NOTE: the two fixtures are in opposite key order (%s vs %s)"
			% [_say(_order_first), _say(order_second)])

	Settings.load_settings()
	_check(_say(_live(Controls.LEFT)) == "J" and _say(_live(Controls.DASHBOARD)) == "G",
		"SAME OUTCOME FROM THE REVERSED FILE: move left keeps J, the dashboard falls back to G (%s / %s)"
			% [_say(_live(Controls.LEFT)), _say(_live(Controls.DASHBOARD))])
	_check(_report("restored").has("sf_dashboard"),
		"resolved by the same rule and for the same reason as §4 (%s)" % _say(_report("restored")))

	# Pristine statics for anyone later in this process, and the temp file gone. `persist` goes off FIRST:
	# `reset_bindings` saves, and the line after it points `path` back at the player's real config.
	Settings.persist = false
	Settings.path = "user://settings.cfg"
	Settings.reset_bindings()
	DirAccess.remove_absolute(TEST_PATH)
	_verdict("check_binding_persistence",
		"a pre-fix config is reconciled through the real load path, a clean one survives byte for byte, "
			+ "and no action is left without a key")
