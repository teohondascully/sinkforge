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

## THE THREE-VALUED ACCOUNTING FOR EVERY REGISTERED STAND-DOWN, and the reason it is three and not two.
##
## `tools/stand_downs.txt` lists every assertion this suite is permitted not to make. Until now a row in it
## could only be OBSERVED FIRING: the gate saw `SKIP: [id]` lines and checked they were registered. Absence
## meant nothing at all, so a row marked `env` -- permitted but conditional -- COULD NOT FAIL IN EITHER
## DIRECTION. Six of twelve rows were documentation wearing a registry's clothes. c1's finding.
##
## Two-valued accounting does not fix it, because "did not stand down" is ambiguous between two states that
## want opposite responses:
##
##   HELD         the branch ran and the assertion WAS made. The debt is paid; the row should be deleted.
##   NOT REACHED  control flow never arrived. The row is intact and this environment cannot exercise it.
##
## `check_frametime` is the case that forces the distinction: with SF_PERF_HOST unset, `_absolute()` returns
## before its loop, so `frametime.paced-phase` is neither asserted nor declined -- it is unreachable, and a
## registry that could only say "absent" reported an unreachable row identically to a paid one. The gate
## previously guessed between them from a condition it read out of the summary, which worked for the two
## conditions a summary happens to record and could not be written for the rest.
##
## So the layer RESOLVES what it reached and nothing more; the third state is DERIVED by
## `tools/harness_verdict.sh` as "registered against this layer, and nothing in its log resolved it".
##
##   _sd_stood   ids `_stand_down()` declined this run
##   _sd_held    ids `_asserted()` made this run
##   _sd_why     optional prose, from a branch that knows why a SIBLING branch will not be entered
##
## THE DERIVATION LIVES IN THE GATE BECAUSE THE GATE IS THE ONLY PARTY THAT ALWAYS RUNS, and the obvious
## alternative was measured before it was rejected. The first version derived it in `_verdict()`, which
## reads as universal and is not: of the 86 layers inheriting this file, **29 call `_verdict()` and 57
## print their own line and `quit()` directly** — including `check_frametime`, `check_dig_hitch` and
## `check_save_durability`, three of the seven layers that own registered rows. The accounting was invisible
## to all three on its first run, which is how the number came to be counted at all. A hook on a path most
## of the population does not take is the same defect one level up: an instrument that cannot register its
## subject. Two dictionaries and a print are what a layer can be trusted to do.
var _sd_stood: Dictionary = {}
var _sd_held: Dictionary = {}
var _sd_why: Dictionary = {}


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
	# A VOID MUST CARRY ITS WITNESS, AND UNTIL THIS BRANCH EXISTED THE RULE WAS ONLY PROSE.
	#
	# The doc comment above says a layer may not void itself to escape a red. Nothing enforced it: `why`
	# was a free string that nothing inspected, so `_void_layer("check_aim", "contaminated")` satisfied
	# the rule completely. A guard stated where nothing evaluates it is not a guard.
	#
	# It could not bite yet only because the runner did not know 43, so a VOID reported as an ordinary
	# FAIL and nobody had any reason to reach for it. It goes live the moment the runner honours the code
	# — which is the same commit as this one — and at that instant a doc comment would have become the
	# only thing between a red layer and a re-run verdict. Assertions already made are DISCARDED by
	# design, so a layer sitting on three genuine failures could void them away.
	#
	# The bar is deliberately crude and deliberately cheap: the reason must contain a NUMBER. Every real
	# contamination detector in this repository reports one — `FixturePointer.reason()` quotes the pixels
	# it saw move — and a sentence with no measurement in it is an excuse rather than evidence. Refusing
	# is reported as a FAILURE rather than a skip, so voiding without a witness is never the cheaper exit.
	var has_measurement: bool = false
	for c: String in why:
		if c >= "0" and c <= "9":
			has_measurement = true
			break
	if not has_measurement:
		printerr("%s: FAIL — a VOID must quote the measurement that shows the run was disturbed, and" % layer
			+ " \"%s\" carries no number. Refusing to void without a witness." % why)
		quit(1)
		return
	print("%s: VOID — %s" % [layer, why])
	if _passes > 0 or _failures > 0:
		print("  (discarding %d assertion(s) made before the contamination was detected — a disturbed run"
			% (_passes + _failures) + " does not keep its green half)")
	quit(VOID)


## Stand down PART of a layer that otherwise passed. The `SKIP:` prefix is what the runner greps for to
## report "passed without verifying everything", so this exists to stop that contract being retyped.
## `id` IS A STABLE NAME FOR THIS PARTICULAR STAND-DOWN, and it exists because the release gate could not
## be keyed on anything else. `tools/stand_downs.txt` registers which assertions this suite is permitted not
## to make; the first version keyed on (layer, count), and a count cannot answer either question that
## matters. A layer that swaps WHICH of its two it stands down keeps the same count. And a count cannot
## distinguish "an assertion is now being made" from "a different machine took a different branch" --
## `check_frametime` returns early on an unset SF_PERF_HOST, so its count is 1 here and something else
## entirely on a box where the budget is switched on. Both present as 2 -> 1.
##
## Format it as `<layer>.<what>`, lowercase, stable across rewordings: the id is the thing the registry
## holds, so changing it is changing the claim. The reason text may be edited freely.
##
## THE BRACKETS ARE THE MACHINE-READABLE PART and the `SKIP:` prefix is deliberately unchanged, because
## `run_harness.sh` counts stand-downs with `grep -c '^[[:space:]]*SKIP:'` and `harness_verdict.sh` reads
## the same lines. Moving the marker would silently zero both counts.
func _stand_down(id: String, what: String, why: String) -> void:
	# A STAND-DOWN WITHOUT AN ID IS A STAND-DOWN THE GATE CANNOT NAME, so it is refused outright rather than
	# printed with an empty bracket. Same rule as `_void_layer` requiring a digit in its reason: the layer
	# does not get to opt out of an assertion without saying which one.
	if id.strip_edges().is_empty():
		printerr("  FAIL: _stand_down was called with no id, for \"%s\". The release gate keys on the id;"
			% what + " an unnamed stand-down cannot be registered, permitted, or noticed when it changes.")
		_failures += 1
		return
	print("  SKIP: [%s] %s was NOT asserted — %s" % [id, what, why])
	_sd_stood[id] = true


## THE ASSERTION WAS MADE. Call this on the branch where a registered stand-down did NOT happen, so that
## the row's absence from the SKIP lines means something.
##
## PRINTS ON FIRST CALL ONLY. Several of these sites sit inside loops over phases or drawing sites, and the
## line is a statement about the RUN rather than about the iteration, so the second one would say nothing
## the first did not. An id that is both stood down and asserted across a loop still prints both lines,
## deliberately: "asserted on three phases of four" is a third state and neither line may swallow the other.
##
## THIS IS THE HALF THAT IS EASY TO FORGET, and forgetting it is loud rather than quiet. An assert path with
## no `_asserted()` on it leaves its registered id resolved by nothing, and the gate reports an unresolved
## id on every run of the layer. A false "unresolved" is a visible wrong claim; the alternative was the
## silence this mechanism exists to end.
func _asserted(id: String) -> void:
	if id.strip_edges().is_empty():
		printerr("  FAIL: _asserted was called with no id. The gate keys on the id; an unnamed accounting"
			+ " entry cannot be matched to a row in tools/stand_downs.txt.")
		_failures += 1
		return
	if _sd_held.has(id):
		return
	_sd_held[id] = true
	print("  HELD: [%s] this run asserted it" % id)


## CONTROL FLOW NEVER GOT HERE — an OPTIONAL annotation that attaches a REASON to the third state.
##
## THE THIRD STATE IS NOT PRODUCED HERE AND MUST NOT BE. A branch that is not taken cannot announce that it
## was not taken, so "nothing resolved this id" is DERIVED by `tools/harness_verdict.sh`, from the registry
## and the layer's log, by a party guaranteed to run. This only lets a branch that knows why a SIBLING
## branch will not be entered say so — the early return standing above the site is the usual caller.
##
## Left uncalled, the gate still reports the id as unresolved; it just cannot say why. That is the correct
## degradation: an explanation is a nicety, and the state itself may never depend on somebody remembering.
func _not_reached(id: String, why: String) -> void:
	if id.strip_edges().is_empty():
		printerr("  FAIL: _not_reached was called with no id, for \"%s\"." % why
			+ " The gate keys on the id; an unnamed accounting entry cannot be matched to a row.")
		_failures += 1
		return
	if _sd_why.has(id):
		return
	_sd_why[id] = why
	print("  UNREACHED: [%s] nothing here will assert it — %s" % [id, why])
