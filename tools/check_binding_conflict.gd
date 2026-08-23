extends "res://tools/check_base.gd"

## Harness layer: NO TWO ACTIONS MAY ANSWER TO ONE KEY, and a rebind may not cost you the bindings you
## did not touch. Headless, no scene: `Settings`, `Controls` and `Hud._binding_clashes` are reachable
## without rendering, so the whole contract checks in milliseconds.
##   godot --headless --path . --script res://tools/check_binding_conflict.gd
##
## WHY THIS FILE REPLACED A LONGER ONE. An earlier 371-line draft of this layer was written, counted as
## the "knockout-proven" evidence that the defect was closed, and never registered: `git ls-files`
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
##    events; rebind grapple to a key and middle-mouse and right-bumper grapple were gone. That one fires
##    on a player who never picks a used key at all, and it had no ticket. `check_gamepad` cannot see it,
##    because it reads the static defaults TABLE and never asks `InputMap` what is live.
## 3. **The label that was a developer identifier.** `event_label`'s fallback was a bare
##    `OS.get_keycode_string(code)`, and `OS.get_keycode_string(KEY_PERIOD)` is `"Period"`: TitleCase,
##    three times the width of every cap beside it, shipped on the CONTROLS page as the game-speed key in
##    a column of `M`, `T`, `Z`, `X`, `F5`. The cosmetic half is the half you can see. The load-bearing
##    half is that these strings are IDENTITY: `rebind` decides two bindings are the same physical input
##    by comparing labels (`settings.gd`), so any two keycodes that share a label are ONE key to
##    the conflict detector; it stands down on a real duplicate and the page never marks it. §7 sweeps
##    every keycode `KEY_CAPS` names plus A-Z, 0-9, F1-F12 and the keypad digits for both halves.
##
## EVERY ASSERTION IN §1-§6 IS AT PER-EVENT GRAIN, because that is the grain the defects live at. The
## `_the_old_predicate_is_blind` arm exists so that claim is proven rather than asserted: it recomputes the
## SUPERSEDED first-event comparison beside the new one, on the same state, in the same process. A control
## that travels inside the measurement cannot disagree about the state it was taken from, and without it,
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

## How wide a keycap chip is, in characters. The CONTROLS page lays the caps out in one column beside the
## action names, so width is a layout constraint and not a taste: `"NUM ENT"` is the widest label the table
## ships and it is exactly at the line. The thing that blows the column out is the fallback: a key the cap
## table has not learned comes back as the engine's whole word for it, and `"BACKSPACE"` is nine.
const CAP_CHARS: int = 7


func _labels(action: StringName) -> Array[String]:
	return Settings.event_labels(action)


## THE KEYCODE POPULATION the label rules are swept over: every code `KEY_CAPS` has an opinion about, plus
## the ordinary keys a player rebinds to. The second half is not padding. Those codes are exactly the ones
## with no table entry, so every one of them exercises the `OS.get_keycode_string` fallback, which is the
## line `"Period"` came out of, and the line any future leak will come out of too.
func _keycodes() -> Array[int]:
	var codes: Array[int] = []
	for code: Variant in Settings.KEY_CAPS:
		if not codes.has(int(code)):
			codes.append(int(code))
	for band: Array in [[KEY_A, KEY_Z], [KEY_0, KEY_9], [KEY_F1, KEY_F12], [KEY_KP_0, KEY_KP_9]]:
		for code: int in range(int(band[0]), int(band[1]) + 1):
			if not codes.has(code):
				codes.append(code)
	return codes


## Every one of them labelled through the SHIPPED function and the SHIPPED spec path, keyed by the engine's
## own name for the key so a failure names the offender rather than printing a keycode number at a human.
func _cap_table() -> Dictionary:
	var out: Dictionary = {}
	for code: int in _keycodes():
		out[OS.get_keycode_string(code)] = Settings.event_label(Controls.event_from_spec({"key": code}))
	return out


## INJECTIVITY, written as a function OF a name -> label table rather than of the keyboard, so the control
## in §8 can hand it a table that violates the property and watch it fire. Returns the offending pair as a
## sentence, or `""` when every label belongs to exactly one key.
func _shared_label(caps: Dictionary) -> String:
	var owner: Dictionary = {}
	for name: Variant in caps:
		var label: String = String(caps[name])
		if owner.has(label):
			return "%s and %s BOTH label \"%s\"" % [owner[label], name, label]
		owner[label] = name
	return ""


## A KEYCAP OR A LINE OF SOURCE. Lowercase ASCII is the whole tell, and it is a sharp one: neither the cap
## table nor the fallback's `.to_upper()` can produce a lowercase letter, while the engine's identifier
## table produces almost nothing else. `"Period"` fails here; `"."`, `"SPACE"` and `"NUM ENT"` do not.
func _looks_like_source(label: String) -> bool:
	for i: int in label.length():
		var c: int = label.unicode_at(i)
		if c >= 0x61 and c <= 0x7A:
			return true
	return false


func _too_wide(label: String) -> bool:
	return label.length() > CAP_CHARS


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
	# THE ARROW'S CAP IS `"UP"`, NOT `"Up"`. These three literals were written against the old fallback,
	# `OS.get_keycode_string(KEY_UP)`, and the cap table respells it. Two of them simply went red when the
	# table landed, which is the harmless way for a stale literal to fail. The third, `not ... has("Up")`,
	# went the other way and kept passing: the new labeller cannot emit `"Up"` at all, so the assertion was
	# true whether or not the arrow still climbed. A literal that no longer names anything the code can
	# produce does not fail; it stops being an assertion, and it is silent about it.
	Settings.reset_bindings()
	var displaced: Array[StringName] = Settings.rebind(Controls.JUMP, {"key": KEY_UP})
	_check(displaced.has(Controls.UP),
		"taking the arrow named climb up as displaced, so the page can say so %s" % str(displaced))
	_check(not _labels(Controls.UP).has("UP"), "the arrow no longer climbs %s" % str(_labels(Controls.UP)))
	_check(_labels(Controls.UP).has("W"), "climb up KEPT W — displacement took one event, not the binding")
	_check(_labels(Controls.JUMP).has("UP") and _labels(Controls.JUMP).has("PAD A"),
		"jump answers the arrow and still answers its pad %s" % str(_labels(Controls.JUMP)))

	# --- 3. KNOCKOUT: the detector must FIRE on a non-first-event duplicate ---------------------
	# Forced through the path `load_settings` uses, an override applied with no conflict resolution,
	# because that is the state a player who rebound anything before the fix actually boots into.
	Settings.reset_bindings()
	Settings.bindings[Controls.JUMP] = [{"key": KEY_UP}]
	Settings._apply_action(Controls.JUMP, [{"key": KEY_UP}])
	var clash: Dictionary = hud._binding_clashes()
	_check(clash.has(Controls.JUMP) and clash.has(Controls.UP),
		"a duplicate on a SECOND event is detected, on both rows %s" % str(clash.keys()))
	_check(str(clash.get(Controls.JUMP, [])).contains("UP"),
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

	# --- 7. ONE KEY, ONE CAP, AND THE CAP LOOKS LIKE A CAP -------------------------------------
	var caps: Dictionary = _cap_table()
	var swept: int = _keycodes().size()
	_check(swept >= 90, "the label sweep is 90+ distinct keycodes wide (%d)" % swept)
	_check(caps.size() == swept,
		"and every code reaches the checker under its own name (%d codes -> %d rows)" % [swept, caps.size()])
	_check(not caps.has(""),
		"no code in the sweep is one the engine cannot name — a band with a hole in it would sweep junk")

	# The load-bearing one. Two keycodes sharing a label are the same key to `rebind`, which is a silent,
	# shipped, invisible conflict: the detector declines to fire and the page has nothing to draw.
	var pair: String = _shared_label(caps)
	_check(pair.is_empty(),
		"NO TWO KEYCODES ANSWER TO ONE LABEL, so no two keys can merge in the conflict check (%s)"
			% ("all %d caps distinct" % caps.size() if pair.is_empty() else pair))

	var source_like: PackedStringArray = []
	var oversize: PackedStringArray = []
	for name: Variant in caps:
		var label: String = String(caps[name])
		if _looks_like_source(label):
			source_like.append("%s -> \"%s\"" % [name, label])
		if _too_wide(label):
			oversize.append("%s -> \"%s\" (%d chars)" % [name, label, label.length()])
	_check(source_like.is_empty(),
		"NOT ONE label on the CONTROLS page is a developer identifier (%s)"
			% ("all %d read as keycaps" % caps.size() if source_like.is_empty() else ", ".join(source_like)))
	_check(oversize.is_empty(),
		"and none is wider than the %d characters the chip holds (%s)"
			% [CAP_CHARS, "widest cap fits" if oversize.is_empty() else ", ".join(oversize)])

	# The row the defect actually shipped on, named, so a regression is reported as the thing a player saw
	# rather than as an index into a sweep.
	_check(Settings.binding_label(Controls.SPEED) == ".",
		"the game-speed row shows the glyph printed on the key, not the engine's word for it (%s)"
			% Settings.binding_label(Controls.SPEED))

	# --- 8. AND BOTH RULES CAN FAIL, DEMONSTRATED IN THIS RUN ----------------------------------
	# Through the SAME predicates §7 runs on. A control that re-states the rule in its own code proves the
	# restatement works and nothing whatever about the guard above it.
	var twinned: Dictionary = {"Enter": "ENTER", "Kp Enter": "ENTER"}
	_check(not _shared_label(twinned).is_empty(),
		"the injectivity check FIRES on the near-miss the cap table exists to avoid — %s"
			% _shared_label(twinned))
	_check(_shared_label({"Enter": "ENTER", "Kp Enter": "NUM ENT"}).is_empty(),
		"and stands down the moment the two are told apart — it is not simply always-on")
	_check(_looks_like_source("Period"),
		"the identifier check REJECTS \"Period\", the exact string that shipped onto the page")
	_check(not _looks_like_source("NUM ENT") and not _looks_like_source("."),
		"and accepts \"NUM ENT\" and \".\" — it is not rejecting every label it is handed")
	_check(_too_wide("BACKSPACE"),
		"the width check REJECTS \"BACKSPACE\", nine characters, what the fallback yields for a key the table forgets")
	_check(not _too_wide("NUM ENT"), "and passes \"NUM ENT\", the widest cap the table ships")

	hud.free()
	DirAccess.remove_absolute(TEST_PATH)
	_verdict("check_binding_conflict",
		"per-event: a rebind moves one event, no action answers twice, and no two keys answer to one cap")
