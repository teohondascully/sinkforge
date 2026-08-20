extends RefCounted
class_name FixturePointer

## A HUMAN AT THE KEYBOARD IS A CONTAMINANT, AND OUR AIM LAYERS CANNOT CURRENTLY TELL.
##
## Every layer that checks aim poses the cursor with `Viewport.warp_mouse(...)` — which moves the REAL OS
## pointer — and then reads the aim back out of `get_global_mouse_position()`. `main.gd:1349` derives the
## player's aim from that same call. So the chain from "what the fixture asked for" to "what the renderer
## did" runs straight through a device that belongs to a person.
##
## When that person is using their computer, the fixture warps the pointer, their hand moves it somewhere
## else, and the readback disagrees by however far their hand went. `check_grapple_reads` reported exactly
## that: `CONTROL: the renderer's cursor is where the fixture put it (132.3 px off)` twice in one run, then
## a different assertion at `97.2 px off` in the next. I diagnosed it as a posed field the game recomputes
## and I was wrong — and the disconfirming evidence was already in my hand, because **a `_process`
## recompute is deterministic and those two numbers were not**.
##
## Measured on this box while its owner was working, sampling passively for four seconds:
##
##     samples that MOVED : 11 of 40
##     largest single jump: 21154.6 px
##     net displacement   : 20433.0 px
##     focused            : false
##
## Note the last line. **The window did not have focus and the game was still tracking the pointer**, so
## parking the window elsewhere does not fix this — it only stops us covering the user's work. The
## telemetry fix has to happen here.
##
## WHAT THIS IS FOR. A layer whose control was disturbed by a person did not measure a defect; it did not
## measure anything. That is a VOID run, and this repo already has the vocabulary — exit 42 / SKIP, and the
## rule that giving up is not a pass. Reporting FAIL instead is worse than reporting nothing, because it
## sends someone to fix a projection that was never broken. It has already cost real edits.
##
##   var eye := FixturePointer.new(get_root())
##   ... eye.sample() inside the wait loop, once per frame ...
##   if eye.contaminated():
##       print("  SKIP: %s" % eye.reason())
##   else:
##       _check(_aim_lands_on().distance_to(target) < 3.0, "CONTROL: ...")
##
## THE REAL FIX IS UPSTREAM AND IS NOT THIS FILE. Aim should not read the OS pointer at all under a
## fixture: `main.gd` wants one accessor for "where is the player aiming" that a fixture can set directly,
## so a capture never touches the user's mouse and never depends on it. This guard is what keeps us honest
## until that lands — and it stays useful afterwards for anything that still has to warp.

## Pointer motion below this is measurement noise, not a hand. Sub-pixel jitter shows up on an idle box.
const TOL_PX: float = 1.0

var _root: Window
var _last: Vector2
var _first: Vector2
var _moves: int = 0
var _travel: float = 0.0
var _worst: float = 0.0
var _samples: int = 0


func _init(root: Window) -> void:
	_root = root
	_first = _read()
	_last = _first


## Called once per frame inside whatever loop the layer already awaits. Cheap: one position read.
func sample() -> void:
	_feed(_read())


## The same accounting, fed a position from outside. THIS EXISTS SO THE GUARD CAN BE PROVEN WITHOUT
## GRABBING THE USER'S CURSOR: a self-test drives synthetic points through here rather than warping a real
## pointer around the screen of the person we are trying to stop bothering.
func _feed(now: Vector2) -> void:
	# THE FIRST SAMPLE ESTABLISHES THE BASELINE; IT CANNOT ITSELF BE A MOVE. There is nothing to have moved
	# from yet, and seeding `_last` in `_init` made the opening sample a 733 px jump away from a
	# constructor-time read — which the self-test caught by asserting that forty identical positions are
	# quiet. A contamination detector whose very first act is to report contamination would void every run
	# it was asked to judge, and it would have looked like vigilance.
	_samples += 1
	if _samples == 1:
		_last = now
		_first = now
		return
	var d: float = now.distance_to(_last)
	if d > TOL_PX:
		_moves += 1
		_travel += d
		_worst = maxf(_worst, d)
	_last = now


func _read() -> Vector2:
	return _root.get_mouse_position() if _root != null else Vector2.ZERO


## Did a hand touch the box while we were measuring?
func contaminated() -> bool:
	return _moves > 0


## Say what happened in the words a skim will understand, with the numbers that justify the call.
func reason() -> String:
	if not contaminated():
		return "the pointer held still for all %d samples — an aim failure here is OURS" % _samples
	return ("a human moved the pointer under this run (%d of %d samples moved, %.0f px travelled, "
		+ "largest jump %.0f px) — the aim readback is VOID, not failed") % [
		_moves, _samples, _travel, _worst]
