extends "res://tools/check_base.gd"

## Harness layer: NO TWO ACTIONS MAY ANSWER TO ONE KEY, and a rebind may not cost you the bindings you
## did not touch. Headless, no scene — `Settings`, `Controls` and `Hud._binding_clashes` are reachable
## without rendering, so the whole contract checks in milliseconds.
##   godot --headless --path . --script res://tools/check_binding_conflict.gd
##
## WHY THIS FILE REPLACED A LONGER ONE. An earlier 371-line draft of this layer was written, cited in
## `docs/MENU_MATRIX.md` as MNU-29a's "knockout-proven" evidence, and never registered — `git ls-files`
## returned nothing for it and `run_harness.sh` never named it, so **it had never run once.** Reviewed, its
## centrepiece "no duplicate exists" assertion compared `Settings.binding_label`, which is `events[0]`,
## which is exactly the predicate the defect hides behind. Its knockout could only fire in the half of the
## space that already worked, and registering it would have bought a green covering the wrong half.
##
## THE TWO DEFECTS THIS GUARDS, both live in shipped builds before the fix:
##
## 1. **The silent duplicate.** Bind `jump` to the up arrow. `sf_up` is `[W, Up, stick]`, so a first-event
##    comparison sees `"SPACE"` against `"W"` and reports nothing; the arrow then climbs AND jumps forever,
##    persisted, unannounced. Three inputs from the shipped page.
## 2. **The rebind that erased what it did not touch.** `rebind` wrote `bindings[action] = [spec]` and
##    `_apply_action` opens with `action_erase_events`, so EVERY rebind destroyed that action's other
##    events — rebind grapple to a key and middle-mouse and right-bumper grapple were gone. That one fires
##    on a player who never picks a used key at all, and it had no ticket. `check_gamepad` cannot see it,
##    because it reads the static defaults TABLE and never asks `InputMap` what is live.
##
## EVERY ASSERTION BELOW IS AT PER-EVENT GRAIN, because that is the grain the defects live at. The
## `_the_old_predicate_is_blind` arm exists so that claim is proven rather than asserted: it recomputes the
## SUPERSEDED first-event comparison beside the new one, on the same state, in the same process. A control
## that travels inside the measurement cannot disagree about the state it was taken from — and without it,
## "the new detector sees more" is a sentence rather than a result.
##
## WHAT THIS LAYER DOES NOT COVER, stated so it is not mistaken for coverage:
## * `Settings.load_settings()` still applies saved bindings with NO conflict resolution, so a config
##   written before the fix re-creates its duplicate on every boot. That is deliberate and not a bug being
##   hidden here: silently rewriting a player's bindings at boot is worse than showing them the clash on a
##   page that now marks it. `_the_load_path_admits_a_duplicate` PINS that behaviour so it is a decision on
##   the record rather than an oversight, and so the day someone changes it, this layer says so.
## * Whether the clash is legible on screen. That is pixels, and it belongs to `check_hud_layout`.

const TEST_PATH: String = "user://binding_conflict_check.cfg"


func _labels(action: StringName) -> Array[String]:
	return Settings.event_labels(action)


## The superseded comparison, kept verbatim so the blindness arm measures the real thing and not a
## paraphrase of it: one label per action, `events[0]`, compared across every pair.
func _old_predicate_finds_a_clash() -> bool:
	for a: StringName in Controls.defaults():
		for b: StringName in Controls.defaults():
			if a != b and Settings.binding_label(a) == Settings.binding_label(b):
				return true
	return false


func _initialize() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Settings.persist = false
	Settings.path = TEST_PATH
	Controls.register()
	var hud: Hud = Hud.new()

	# --- 1. A REBIND MOVES ONE EVENT AND COSTS NOTHING ELSE -------------------------------------
	Settings.reset_bindings()
	var before: int = _labels(Controls.GRAPPLE).size()
	_check(before == 3, "grapple ships with three events, one per device (%d)" % before)
	Settings.rebind(Controls.GRAPPLE, {"key": KEY_G})
	var g: Array[String] = _labels(Controls.GRAPPLE)
	_check(g.size() == before,
		"a rebind did not change how many events grapple has (%d -> %d) %s" % [before, g.size(), str(g)])
	_check(g.has("G") and not g.has("F"), "the desk key moved F -> G %s" % str(g))
	_check(g.has("MMB"), "MIDDLE MOUSE SURVIVED the rebind — the destructive bug is closed")
	_check(g.has("PAD RB"), "and so did the pad button — remapping a keyboard is not asking to lose a pad")

	# The general form of the same property, over every action rather than the one that shows it best.
	Settings.reset_bindings()
	var kept: bool = true
	var lost: String = ""
	for act: StringName in Controls.defaults():
		var n: int = _labels(act).size()
		if n < 2:
			continue                        # nothing to preserve; the single-event actions cannot show this
		Settings.rebind(act, {"key": KEY_F13})
		if _labels(act).size() != n:
			kept = false
			lost = "%s went %d -> %d" % [String(act), n, _labels(act).size()]
		Settings.reset_bindings()
	_check(kept, "NO multi-event action loses an event to a rebind (%s)" % ("all held" if kept else lost))

	# --- 2. THE LIVE REPRO: CONTROLS -> jump -> press the UP ARROW ------------------------------
	Settings.reset_bindings()
	var displaced: Array[StringName] = Settings.rebind(Controls.JUMP, {"key": KEY_UP})
	_check(displaced.has(Controls.UP),
		"taking the arrow named climb up as displaced, so the page can say so %s" % str(displaced))
	_check(not _labels(Controls.UP).has("Up"), "the arrow no longer climbs %s" % str(_labels(Controls.UP)))
	_check(_labels(Controls.UP).has("W"), "climb up KEPT W — displacement took one event, not the binding")
	_check(_labels(Controls.JUMP).has("Up") and _labels(Controls.JUMP).has("PAD A"),
		"jump answers the arrow and still answers its pad %s" % str(_labels(Controls.JUMP)))

	# --- 3. KNOCKOUT: the detector must FIRE on a non-first-event duplicate ---------------------
	# Forced through the path `load_settings` uses — an override applied with no conflict resolution —
	# because that is the state a player who rebound anything before the fix actually boots into.
	Settings.reset_bindings()
	Settings.bindings[Controls.JUMP] = [{"key": KEY_UP}]
	Settings._apply_action(Controls.JUMP, [{"key": KEY_UP}])
	var clash: Dictionary = hud._binding_clashes()
	_check(clash.has(Controls.JUMP) and clash.has(Controls.UP),
		"a duplicate on a SECOND event is detected, on both rows %s" % str(clash.keys()))
	_check(str(clash.get(Controls.JUMP, [])).contains("Up"),
		"and the phrase names the COLLIDING key rather than the row's own chip %s"
			% str(clash.get(Controls.JUMP, [])))

	# --- 4. AND THE SUPERSEDED PREDICATE IS BLIND TO IT, MEASURED ------------------------------
	_check(not _old_predicate_finds_a_clash(),
		"the OLD first-event comparison reports NOTHING in this exact state — the upgrade is not cosmetic")

	# --- 5. PINNED: the load path still admits a duplicate, by decision -------------------------
	_check(hud._binding_clashes().has(Controls.JUMP),
		"a duplicate applied the way load_settings applies one SURVIVES and stays visible")

	# --- 6. NON-VACUITY: the shipped defaults must be clean ------------------------------------
	Settings.reset_bindings()
	var none: Dictionary = hud._binding_clashes()
	_check(none.is_empty(),
		"no clash on the shipped defaults — the detector is not simply always-on %s" % str(none.keys()))

	hud.free()
	DirAccess.remove_absolute(TEST_PATH)
	_verdict("check_binding_conflict", "per-event: a rebind moves one event and no action answers twice")
