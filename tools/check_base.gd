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
##
## And the partial case, which has no exit code because the layer really did pass: a line beginning
## `SKIP:` inside otherwise-green output means some assertions were stood down. The runner counts those
## separately and refuses to call the run a full sweep. Use `_stand_down()` for it rather than printing by
## hand — the prefix is a contract with the runner, not a convention.
##
## HOW TO ADD A LAYER: docs/HARNESS_LAYERS.md.

## The runner's reserved "I did not run" code (tools/run_harness.sh, SKIP_CODE).
const SKIP: int = 42

var _failures: int = 0


## Assert, and say so either way. Every layer's output is read by a human at least as often as by the
## runner, so the label is a SENTENCE about the property, not a variable name — "the backup holds the older
## save, intact" rather than "bak_seed == 11".
func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


## Print the layer's verdict and exit with the code the runner expects. `note` is the sentence some layers
## append to a green result to say what was actually proved; omit it for a bare PASS.
func _verdict(layer: String, note: String = "") -> void:
	if _failures == 0:
		print("%s: PASS%s" % [layer, "" if note.is_empty() else " — " + note])
		quit(0)
	else:
		printerr("%s: %d FAILURE(S)" % [layer, _failures])
		quit(1)


## Stand the WHOLE layer down: it did not run, and it must not be counted as a pass. `why` is printed
## because a skip nobody can explain is indistinguishable from a skip nobody noticed.
func _skip_layer(layer: String, why: String) -> void:
	print("%s: SKIP — %s" % [layer, why])
	quit(SKIP)


## Stand down PART of a layer that otherwise passed. The `SKIP:` prefix is what the runner greps for to
## report "passed without verifying everything", so this exists to stop that contract being retyped.
func _stand_down(what: String, why: String) -> void:
	print("  SKIP: %s was NOT asserted — %s" % [what, why])
