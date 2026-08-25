extends "res://tools/check_base.gd"

## ONLY ONE PRIMARY ATTENTION STATE MAY BE UP AT A TIME, AND THE PREDICATE FOR IT HAS TO BE THE ONE THAT
## DRAWS.
##
## `Hud` keeps two facts about the arrival plate and they are not the same fact. `announcing()` is the
## plate's LIFETIME: an announcement is owed. `plate_on_screen()` is its VISIBILITY: the plate is being
## painted. They agree except while something HOLDS the plate, and holding is deliberate. A plate already
## in flight when the minimap opens or a line goes live has its clock STOPPED rather than dropped, so the
## announcement survives to be shown properly instead of being deleted mid-sentence.
##
## WHY THIS LAYER EXISTS, and it is not hypothetical. `main.gd` gated just-in-time lessons on
## `announcing()`, under a comment instructing the reader to take the predicate from the HUD rather than
## mirror it BECAUSE "only one of them draws" -- and then took the one that does not. The consequence:
## for as long as a rope was out, a held and completely invisible plate silenced every lesson in the
## game. The lesson that suffered most was the one about ropes, because `wrapped` can only fire while a
## line is live, which is precisely the condition that freezes the plate. A player who crossed a stratum
## shortly before grappling could not be taught the technique at the moment it happened, ever.
##
## That was fixed by giving the visibility question its own predicate and sharing it with `_draw_arrival`.
## The fix had no tracked guard: its evidence lived in a gitignored scratch that no sweep runs, which is
## the same "a rule with no runner is a preference" this repository keeps rediscovering. This is the
## runner for it.
##
## PURE, AND THAT IS WHY IT IS A HEADLESS LAYER. `announce()`, `_announce_held()` and the release branch
## of `_process()` touch no tree and no drawing, so the whole channel can be driven directly. Nothing here
## needs a display, a world or a frame.
##
##   godot --headless --path . --script res://tools/check_announce_channel.gd

const HOLD: float = 3.4          ## must equal Hud.ARRIVAL_HOLD; asserted below rather than trusted
const FRAME: float = 0.016


func _initialize() -> void:
	# THE CONSTANT THIS FILE REASONS WITH MUST BE THE ONE THE GAME USES. Two unrelated literals that have
	# to agree is a defect waiting for someone to change one of them.
	_check(absf(Hud.ARRIVAL_HOLD - HOLD) < 0.0001,
		"this layer's HOLD matches Hud.ARRIVAL_HOLD (%.2f)" % Hud.ARRIVAL_HOLD)

	_held_while_rope_live()
	_released_with_life_intact()
	_clock_stops_when_rope_starts()
	_visibility_is_not_lifetime()
	_control_fires_without_hold()

	_verdict("check_announce_channel",
		"a held plate keeps its announcement, draws nothing, and no longer silences lessons")


func _hud() -> Hud:
	var h: Hud = Hud.new()
	h.minimap_large = false
	h.rope_active = false
	return h


## Announcing while the line is live must HOLD the ceremony: not fire it, and not drop it.
func _held_while_rope_live() -> void:
	var h: Hud = _hud()
	h.rope_active = true
	h.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	_check(h.announcing() == false, "a rope on screen holds the plate, so it does not draw")
	_check((h.get("_pending_arrival") as Array).size() == 3,
		"...and the announcement is retained rather than dropped")
	h.free()


## Cutting the line must release the held plate worth what it would have been worth had it never waited.
## ASSERTING AN ABSOLUTE 3.4 HERE WAS WRONG and failed at 3.384: the release and the first decrement land
## in the same `_process` call, so one frame of delta is spent. A plate that fires normally spends that
## same frame. The defect-free quantity is the DIFFERENCE against an unheld plate, so the control travels
## inside the measurement instead of the threshold being slackened to fit.
func _released_with_life_intact() -> void:
	var held: Hud = _hud()
	held.rope_active = true
	held.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	held.rope_active = false
	held._process(FRAME)

	var fresh: Hud = _hud()
	fresh.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	fresh._process(FRAME)

	var lh: float = held.get("_arrival_life")
	var lf: float = fresh.get("_arrival_life")
	_check(held.announcing(), "cutting the line releases the held plate")
	_check(absf(lh - lf) < 0.0005,
		"...and it is worth exactly what an unheld one is worth (%.4f against %.4f)" % [lh, lf])
	_check(lh > HOLD - 0.02, "...which is full life bar the current frame (%.4f of %.1f)" % [lh, HOLD])
	_check((held.get("_pending_arrival") as Array).is_empty(), "...and the pending slot is cleared")
	held.free()
	fresh.free()


## The other direction, and the one a one-sided guard misses: a plate ALREADY up when the line goes live.
## Its clock must stop, or the announcement burns down behind something the player cannot see.
func _clock_stops_when_rope_starts() -> void:
	var h: Hud = _hud()
	h.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	h._process(0.5)
	var before: float = h.get("_arrival_life")
	h.rope_active = true
	for _i: int in 20:
		h._process(0.05)
	var after: float = h.get("_arrival_life")
	_check(before < HOLD, "the plate's clock runs while nothing holds it (%.3f)" % before)
	_check(absf(after - before) < 0.001,
		"...and stops the moment a line goes live (%.3f to %.3f over 1.0s)" % [before, after])
	h.free()


## THE FIX'S OWN CASE. Both directions, plus the two states where the predicates must AGREE: a
## `plate_on_screen()` that simply never returns true would satisfy the interesting assertion on its own.
func _visibility_is_not_lifetime() -> void:
	var h: Hud = _hud()
	h.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	h._process(0.5)
	h.rope_active = true
	_check(h.announcing(), "a held plate still has life, because the announcement is owed")
	_check(h.plate_on_screen() == false,
		"...and is NOT on screen, so a lesson gated on visibility no longer waits behind it")
	h.rope_active = false
	_check(h.plate_on_screen(), "...and cutting the line puts it back on screen")
	h.free()

	var c: Hud = _hud()
	c.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	_check(c.announcing() and c.plate_on_screen(),
		"CONTROL: unheld, lifetime and visibility agree and are both TRUE")
	c.free()

	var e: Hud = _hud()
	_check((not e.announcing()) and (not e.plate_on_screen()),
		"CONTROL: with no plate at all, both are FALSE")
	e.free()

	# AND THE MINIMAP REACHES THE SAME PREDICATE, which is the reason `_announce_held()` exists as one
	# function rather than two conditions. A guard written only against ropes would pass a build where the
	# big map silenced every lesson instead.
	var m: Hud = _hud()
	m.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	m._process(0.5)
	m.minimap_large = true
	_check(m.announcing() and not m.plate_on_screen(),
		"CONTROL: the big map holds the plate the same way a rope does")
	m.free()


## CONTROL. Without this every assertion above is satisfied by a plate that never fires under any
## condition, and the layer would read green on a feature that had been deleted.
func _control_fires_without_hold() -> void:
	var h: Hud = _hud()
	h.announce("THE DEEPSLATE", "760 m", Color.WHITE)
	_check(h.announcing(), "CONTROL: with nothing holding it, the plate fires")
	h._process(0.5)
	_check(float(h.get("_arrival_life")) < HOLD, "CONTROL: ...and its clock decrements normally")
	h.free()
