extends "res://tools/check_base.gd"

## YOU CAN PLAY THIS GAME WITH A CONTROLLER.
##
## COMPREHENSIVE_AUDIT §198: no gamepad defaults exist. They did not — `grep -rn JOY_ scenes src` returned
## nothing at all. That is not a missing convenience. A player who plugs in a pad, presses everything, and
## gets nothing has no way to tell that the game does not support controllers rather than that the game is
## broken; and for a player who cannot use a mouse, that is the whole product.
##
## WHAT THIS LAYER CAN AND CANNOT JUDGE, stated up front because the gap matters. It cannot tell you the
## layout feels good — no harness can, and nobody here has a pad plugged into CI. What it CAN do is hold the
## binding table to the four properties that make a scheme coherent rather than a pile of assignments, all
## of which are decidable from the table alone:
##
##   COMPLETE.    Every verb a player needs during normal play is reachable from the pad. The essential set
##                is listed below and argued for, rather than being "all of them" — a pad has about
##                fourteen inputs and this game has twenty-four actions, so binding everything means
##                binding things badly.
##   UNAMBIGUOUS. No pad input drives two different actions. This is the one that has already earned its
##                keep: the first draft of the layout bound the D-pad to BOTH movement and the hotbar
##                cycle, so changing tool would have walked the body sideways. The comment above the table
##                said the D-pad was free for the hotbar "because movement lives on the stick" — and the
##                code three lines below it did the other thing. Prose and table disagreed and the table
##                was wrong.
##   AXES SPLIT.  A stick axis is two bindings wearing one number: left and right are the same axis with
##                opposite signs. An action bound to the axis without a sign fires on both halves, which
##                reads as a body that walks right when you pull left. Every motion spec must pick a half.
##   ADDITIVE.    The keyboard and mouse defaults are untouched. A gamepad scheme that silently costs the
##                keyboard a binding is a regression wearing a feature's clothes.
##
## Runs headless — InputMap needs no display and no physical controller.
##
##   godot --headless --path . --script res://tools/check_gamepad.gd

## THE VERBS A PAD MUST REACH, and why this list stops where it does. Everything here is either used in the
## moment-to-moment loop or is the way out of a screen; nothing here can be reached another way while
## holding a pad. Deliberately absent: SAVE, LOAD, TECH, DASHBOARD, SPEED, MUTE, RESEARCH, CLEAR_MARKS,
## HELP — every one reachable from a menu or a convenience, and each one bound would cost a chord or a
## long-press, which is how a control scheme becomes something you need a diagram for.
const ESSENTIAL: Array[StringName] = [
	&"sf_left", &"sf_right", &"sf_up", &"sf_down", &"sf_jump",
	&"sf_mine", &"sf_build", &"sf_grapple",
	&"sf_drop", &"sf_craft", &"sf_map", &"sf_pause", &"sf_close",
	&"sf_cycle_next", &"sf_cycle_prev",
]


func _initialize() -> void:
	print("== you can play this game with a controller ==")
	_run()
	_verdict("check_gamepad", "every verb the loop needs is on the pad, once each")


func _run() -> void:
	var specs: Dictionary = Controls.defaults()

	# --- COMPLETE ---
	var unreachable: Array[String] = []
	var pad_actions: int = 0
	for action: StringName in ESSENTIAL:
		if not specs.has(action):
			unreachable.append("%s (no such action)" % action)
			continue
		if _pad_specs(specs[action]).is_empty():
			unreachable.append(String(action))
		else:
			pad_actions += 1
	_check(unreachable.is_empty(),
		"every essential verb is reachable from the pad%s"
			% ["" if unreachable.is_empty() else " — UNREACHABLE: " + ", ".join(unreachable)])

	# --- UNAMBIGUOUS ---
	# Keyed by the LABEL rather than the raw spec, because that is what the player experiences: two specs
	# that render the same on a remap page are the same input to the hand holding the pad.
	var owner: Dictionary = {}
	var clashes: Array[String] = []
	for action: Variant in specs:
		for spec: Dictionary in _pad_specs(specs[action]):
			var label: String = Settings.event_label(Controls.event_from_spec(spec))
			if owner.has(label):
				clashes.append("%s drives both %s and %s" % [label, owner[label], action])
			else:
				owner[label] = action
	_check(clashes.is_empty(),
		"no pad input drives two verbs%s" % ["" if clashes.is_empty() else " — " + "; ".join(clashes)])

	# --- AXES SPLIT ---
	var unsigned: Array[String] = []
	for action: Variant in specs:
		for spec: Dictionary in _pad_specs(specs[action]):
			if not spec.has("axis"):
				continue
			if not spec.has("dir") or absf(float(spec["dir"])) < 0.5:
				unsigned.append("%s binds axis %s without picking a half" % [action, spec["axis"]])
	_check(unsigned.is_empty(),
		"every stick and trigger binding picks one half of its axis%s"
			% ["" if unsigned.is_empty() else " — " + "; ".join(unsigned)])

	# --- ADDITIVE ---
	# The pad is an addition, never a replacement. Any essential verb losing its keyboard or mouse binding
	# would be a regression dressed as a feature, and the diff that introduces it would look like progress.
	var stranded: Array[String] = []
	for action: StringName in ESSENTIAL:
		if not specs.has(action):
			continue
		var human: int = 0
		for spec_v: Variant in specs[action]:
			var spec: Dictionary = spec_v
			if spec.has("key") or spec.has("button"):
				human += 1
		if human == 0:
			stranded.append(String(action))
	_check(stranded.is_empty(),
		"every essential verb still works on keyboard and mouse%s"
			% ["" if stranded.is_empty() else " — PAD-ONLY: " + ", ".join(stranded)])

	# --- and the specs actually build into events of the right kind ---
	# event_from_spec falls through to a MOUSE BUTTON for anything it does not recognise, which is the exact
	# failure that made one builder out of two worth doing: a typo'd key name would come back as a click and
	# nothing downstream would notice.
	var miscast: Array[String] = []
	for action: Variant in specs:
		for spec: Dictionary in _pad_specs(specs[action]):
			var ev: InputEvent = Controls.event_from_spec(spec)
			var ok: bool = (ev is InputEventJoypadButton) if spec.has("pad") else (ev is InputEventJoypadMotion)
			if not ok:
				miscast.append("%s: %s became %s" % [action, spec, ev.get_class()])
	_check(miscast.is_empty(),
		"every pad spec builds into a pad event%s"
			% ["" if miscast.is_empty() else " — " + "; ".join(miscast)])

	# NON-VACUITY. Every assertion above is satisfied perfectly by a table with no pad bindings at all —
	# COMPLETE would fail, but the other four would each pass over an empty set and report health. Assert
	# there was something to judge, and that it is spread across the pad rather than piled on one button.
	_check(pad_actions >= 12, "%d essential verbs have pad bindings" % pad_actions)
	_check(owner.size() >= 12, "%d distinct pad inputs are in use" % owner.size())
	var labels: Array = owner.keys()
	labels.sort()
	print("  the pad drives: %s" % ", ".join(labels))


## The pad-flavoured specs in one action's list — buttons and axes, not keys or mouse buttons.
func _pad_specs(list: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec_v: Variant in (list as Array):
		var spec: Dictionary = spec_v
		if spec.has("pad") or spec.has("axis"):
			out.append(spec)
	return out
