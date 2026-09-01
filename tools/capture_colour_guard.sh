#!/usr/bin/env bash
# The distinct-colour floor that decides whether a capture is a picture or a flat frame -- SOURCED, not
# executed, by `tools/capture_moments.sh` and by its test. `docs/DECISIONS_LEDGER.md` D0316.
#
# WHY THIS IS ITS OWN FILE. The check needs to be driven with producer output that no real run would
# ever emit -- in particular, output with no colour line in it at all -- and the only honest way to do
# that is to call the same code the tool calls. A test that restated the parse would be checking a copy
# and would have agreed with the broken original.
#
# THE DEFECT IT WAS SPLIT OUT TO FIX (found by a Codex audit). The floor read:
#
#     if [ -n "$colours" ] && [ "$colours" -lt "$MIN_COLOURS" ]; then ... fail
#
# An ABSENT count -- the producer stopped printing its evidence, the message was renamed, the run died
# before the shutter -- made `-n` false, skipped the floor entirely, and PASSED. **No measurement was
# read as a good measurement.** That is the sixth instance of this run's dominant failure class, and the
# only one of the six that was in a GATE rather than in a test: `[[instrument-cannot-register-subject]]`,
# arriving as the quiet green it always arrives as.
#
# The fix is to fail closed. `tools/check_headed_boot.sh` already had this exact shape correct --
# "Refusing to call the frame non-blank on the strength of the file merely existing" -- so the repair is
# also a de-duplication of a rule this repository had already written down once and then, one directory
# over, written down wrong. `[[repair-reaches-one-instance]]`.

## The count the producer reported, or the empty string if it reported none. The empty string is a REAL
## answer here and callers must treat it as one -- that is the whole finding.
capture_colour_count() {  # <producer-output>
	printf '%s\n' "$1" | grep -o "capture has [0-9]* distinct colours" | grep -o "[0-9]*" | head -1
}


## 0 if the capture cleared the floor, 1 otherwise, with the reason on stderr.
##
## THREE OUTCOMES, NOT TWO. A count above the floor passes; a count below it fails; and NO COUNT fails,
## because a floor that was never applied has not been cleared. The third case is the one that used to
## be silently indistinguishable from the first.
capture_colour_guard() {  # <producer-output> <min-colours> <capture-name>
	local out="$1" min="$2" name="$3" colours
	colours="$(capture_colour_count "$out")"
	if [ -z "$colours" ]; then
		echo "capture_colour_guard: FAIL -- $name reported NO distinct-colour count, so the floor of" >&2
		echo "capture_colour_guard:        $min was never applied to it. This is not the same as a" >&2
		echo "capture_colour_guard:        frame that passed: nothing was measured. The producer is" >&2
		echo "capture_colour_guard:        tests/body/reveal_shutter.gd and the line it must print is" >&2
		echo "capture_colour_guard:        \"capture has N distinct colours\" -- if that message was" >&2
		echo "capture_colour_guard:        renamed, rename it here too rather than removing this check." >&2
		return 1
	fi
	if [ "$colours" -lt "$min" ]; then
		echo "capture_colour_guard: FAIL -- $name has only $colours distinct colours (floor $min)." >&2
		echo "capture_colour_guard:        A frame this flat is not a picture. The usual cause is a STALE" >&2
		echo "capture_colour_guard:        IMPORT CACHE after a branch switch or rebase, which makes every" >&2
		echo "capture_colour_guard:        class_name global fail to resolve so no painter draws:" >&2
		echo "capture_colour_guard:            godot --headless --path . --import" >&2
		echo "capture_colour_guard:        and re-run. The PNG has been left in place so it can be looked at." >&2
		return 1
	fi
	return 0
}
