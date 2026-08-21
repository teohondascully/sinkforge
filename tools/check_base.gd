extends SceneTree

## Shared spine for the Sinkforge harness layers (tools/check_*.gd). Holds the failure counter, the
## assertion helper, and the three-state exit protocol every layer has to speak.
##
## Extended by PATH — `extends "res://tools/check_base.gd"` — deliberately, not `class_name`. A layer runs
## under a bare `godot --script res://tools/check_x.gd`, and that must not depend on the global class cache
## being current. `tests/test_base.gd` made the same call for the same reason; this is the tools/ half of a
## fix that only ever landed on one side of the house.
##
## WHAT THIS REPLACED: fifty layers re-declaring a byte-identical `_check`, in six cosmetic variants —
## `ok` or `cond`, `msg` or `label`, `_fails` or `_failures` — none of which differed in behaviour by so
## much as a character of output. Fifty copies of a function is fifty places for one of them to drift, and
## no test anywhere would have noticed: a layer whose `_check` forgot to increment its counter passes
## everything forever, and it is the layers themselves that are the tests here. There was nothing beneath
## them to catch it.
##
## THE EXIT PROTOCOL, which is the part worth getting right, because the runner reads exit codes and a
## layer that returns the wrong one is worse than a layer that does not run:
##
##   0   ran, asserted, everything held
##   1   ran, asserted, something failed
##   42  DID NOT RUN — the layer stood down whole (no display for a pixel layer, no named host for an
##       absolute budget). Never 0. A skip reported as a pass is how "ALL 61 HARNESS LAYERS PASS" got
##       printed over four layers that had drawn nothing.
##   43  RAN, AND MEASURED NOTHING USABLE — the measurement was CONTAMINATED from outside the code, so the
##       result is neither a pass nor a failure. See VOID below.
##
## And the partial case, which has no exit code because the layer really did pass: a line beginning
## `SKIP:` inside otherwise-green output means some assertions were stood down. The runner counts those
## separately and refuses to call the run a full sweep. Use `_stand_down()` for it rather than printing by
## hand — the prefix is a contract with the runner, not a convention.
##
## WHY VOID IS A FOURTH STATE AND NOT A FLAVOUR OF SKIP. A skip is a DECISION taken from the layer's own
## circumstances — no display, no named performance host — and it is reproducible: run it again on the same
## box and it skips again. Contamination is the opposite on both counts. `FixturePointer` exists because
## every aim layer here reads the REAL OS pointer, so a person moving their hand mid-run moves the number:
## `check_grapple_reads` reported `132.3 px off` and then `97.2 px off` on the next run, and that was
## diagnosed as a broken projection and nearly fixed. It was a hand.
##
## The three states could not say that. FAIL sends someone to repair code that was never broken. PASS is a
## lie. SKIP is the closest and is still wrong twice over: it says the layer DECLINED to run when it ran and
## was disturbed, and — because a skip on a machine that has a display is what SF_STRICT exists to fail —
## it turns a re-runnable nuisance into a red that a re-run cannot clear, so the honest response gets
## punished. VOID says the one thing a caller needs: nothing was measured, RUN IT AGAIN.
##
## A LAYER MAY NOT VOID ITSELF TO ESCAPE A RED. The contamination has to be witnessed and quoted — the
## `why` string carries the numbers, exactly as `FixturePointer.reason()` does — and a VOID never counts as
## a pass at any level. Voiding a run you simply did not like is the same offence as skipping one.
##
## HOW TO ADD A LAYER: docs/HARNESS_LAYERS.md.

## The runner's reserved "I did not run" code (tools/run_harness.sh, SKIP_CODE).
const SKIP: int = 42

## The runner's reserved "I ran and measured nothing usable" code (tools/run_harness.sh, VOID_CODE).
const VOID: int = 43

var _failures: int = 0

## HOW MANY ASSERTIONS THIS LAYER ACTUALLY MADE, because an exit code cannot mean anything without it.
## `_failures == 0` is the condition for printing PASS, and it is satisfied identically by a layer that
## proved forty properties and by a layer that proved none — a fixture that threw early, a scan whose glob
## matched nothing, a `_run()` that returned before its first `_check`. Both exit 0. This repo has shipped
## that failure in several shapes and the runner cannot see it from outside, because from outside the two
## are one integer. Counting here is the only place the difference exists.
var _passes: int = 0


## Assert, and say so either way. Every layer's output is read by a human at least as often as by the
## runner, so the label is a SENTENCE about the property, not a variable name — "the backup holds the older
## save, intact" rather than "bak_seed == 11".
func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


## Print the layer's verdict and exit with the code the runner expects. `note` is the sentence some layers
## append to a green result to say what was actually proved; omit it for a bare PASS.
##
## THE COUNT IS PART OF THE VERDICT, ALWAYS. A green line that does not say how many properties it stood on
## is a claim with its own evidence withheld, and the runner downstream is reading an exit code that cannot
## carry the difference. Printed on the failing line too: "1 FAILURE(S)" out of 40 assertions and out of 1
## are very different runs and the old line rendered them the same.
func _verdict(layer: String, note: String = "") -> void:
	if _failures == 0 and _passes == 0:
		# A GREEN THAT ASSERTED NOTHING IS NOT A GREEN. Nothing outside this function can tell it from a
		# real one: both are exit 0 over a log with no FAIL line in it. The layer reached its verdict
		# without testing anything, which is the house defect — an instrument that cannot register its
		# subject — and it must be loud rather than quiet.
		printerr("%s: FAIL — the layer made NO ASSERTIONS and reached its verdict anyway, so exit 0 would"
			% layer + " claim a property nobody tested. A layer that has nothing to assert must"
			+ " _skip_layer() or _void_layer() and say why.")
		# `quit()` DOES NOT RETURN. It asks the main loop to stop at the end of the current iteration and
		# execution carries straight on through this function, so without this `return` the branch below
		# ran too: the probe for this guard printed the FAIL line, then `PASS (0 asserted)`, and exited 0.
		# The guard against a green that asserted nothing was itself exiting green. Every `quit()` here is
		# either last in its function or followed by a return, and that is load-bearing rather than style.
		quit(1)
		return
	if _failures == 0:
		print("%s: PASS (%d asserted)%s" % [layer, _passes, "" if note.is_empty() else " — " + note])
		quit(0)
	else:
		printerr("%s: %d FAILURE(S) of %d asserted" % [layer, _failures, _failures + _passes])
		quit(1)


## Stand the WHOLE layer down: it did not run, and it must not be counted as a pass. `why` is printed
## because a skip nobody can explain is indistinguishable from a skip nobody noticed.
func _skip_layer(layer: String, why: String) -> void:
	print("%s: SKIP — %s" % [layer, why])
	quit(SKIP)


## VOID the layer: it RAN, and something outside the code spoiled the measurement, so neither PASS nor FAIL
## is a true report. The correct response is to run it again — which is why this is not a skip, and why
## SF_STRICT must not convert it into one.
##
## `why` MUST CARRY THE WITNESS, with numbers. A void with no evidence is a layer excusing itself, which is
## the same offence as a skip with no reason. Say what was seen — `FixturePointer.reason()` is the model:
## "a human moved the pointer under this run (11 of 40 samples moved, 20433 px travelled, largest jump
## 21155 px) — the aim readback is VOID, not failed".
##
## WHAT IS NOT WIRED UP YET, said here rather than left to be discovered. `tools/run_harness.sh` does not
## know 43. Until it does, a layer calling this is reported as an ordinary FAIL with `(exit 43)` beside it —
## which is safe (a void is never counted as a pass) and is not yet USEFUL (it cannot be told from a real
## failure, so nobody learns to re-run). The runner needs a VOID_CODE branch, a `voided` tally named in the
## summary, and a run-level exit that strict mode does not fold into its skip count. Two-thirds of a state
## is not a state, so do not adopt this in a layer expecting the re-run semantics until that lands.
##
## Assertions already made are DISCARDED, deliberately and loudly. A run whose inputs were disturbed does
## not get to keep the half of itself that happened to come out green: whatever contaminated the pointer,
## the clock or the box was present for those assertions too, and the whole point of this state is that
## nobody can tell which of them it reached.
func _void_layer(layer: String, why: String) -> void:
	print("%s: VOID — %s" % [layer, why])
	if _passes > 0 or _failures > 0:
		print("  (discarding %d assertion(s) made before the contamination was detected — a disturbed run"
			% (_passes + _failures) + " does not keep its green half)")
	quit(VOID)


## Stand down PART of a layer that otherwise passed. The `SKIP:` prefix is what the runner greps for to
## report "passed without verifying everything", so this exists to stop that contract being retyped.
func _stand_down(what: String, why: String) -> void:
	print("  SKIP: %s was NOT asserted — %s" % [what, why])
