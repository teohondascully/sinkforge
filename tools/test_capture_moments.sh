#!/usr/bin/env bash
# Mutation test for the capture colour floor (`tools/capture_colour_guard.sh`), the D0316 fix for a
# fail-open guard a Codex audit found in `tools/capture_moments.sh`.
#
#   bash tools/test_capture_moments.sh
#
# THE DEFECT. The floor read `[ -n "$colours" ] && [ "$colours" -lt "$MIN_COLOURS" ]`. A capture whose
# producer emitted NO colour line made `-n` false, skipped the comparison, and passed -- the floor was
# never applied and the run said nothing was wrong. **No measurement was reported as a good
# measurement.** `[[instrument-cannot-register-subject]]`, inside a gate.
#
# THE THREE DIRECTIONS, because two of them are not enough. A guard that failed on everything would
# satisfy rows 1 and 2 while making the tool useless, and a guard that failed on nothing (the defect)
# would satisfy row 3. Only all three together pin it:
#
#   1. a count BELOW the floor       -> FAIL   (the check that already worked)
#   2. NO count at all               -> FAIL   (the fix; this row PASSED before it)
#   3. a count ABOVE the floor       -> PASS   (the control: the guard is not simply always-fail)
#
# Rows 4-6 are the boundary and the parser, because "below the floor" and "no count" are both claims
# about a `grep` that could be wrong in ways rows 1-3 cannot see: a parser that matched nothing would
# turn every row into row 2 and still satisfy 1 and 2.
#
# NEEDS NO GODOT AND NO DISPLAY. It drives the guard with synthetic producer text, which is the point --
# the failure it exists to catch is output no real run emits, so no real run can be the fixture.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# shellcheck source=tools/capture_colour_guard.sh
. "$ROOT/tools/capture_colour_guard.sh"

MIN=100
fails=0

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

# A producer line as `tests/body/reveal_shutter.gd` actually emits it, so the fixtures below differ from
# a real run only in the number and in whether the line is there at all.
line() { printf 'reveal_scene: capture has %s distinct colours\n' "$1"; }
noise() { printf 'Godot Engine v4.6.2.stable\nreveal_scene: wrote 12 ticks\n'; }

guard_says() {  # guard_says <producer-output> -> prints "pass" or "fail"
	if capture_colour_guard "$1" "$MIN" "fixture" 2>/dev/null; then echo pass; else echo fail; fi
}

echo "test_capture_moments: the colour floor, driven with output no real run emits (floor $MIN)"

# --- 1. a real count below the floor still fails. The check that already worked. ----------------------
got="$(guard_says "$(noise; line 45)")"
check "$([ "$got" = fail ] && echo 0 || echo 1)" \
	"a count BELOW the floor fails (45 < $MIN, guard said $got)"

# --- 2. THE FIX. No colour line at all -- and this is the row that PASSED before D0316. ---------------
got="$(guard_says "$(noise)")"
check "$([ "$got" = fail ] && echo 0 || echo 1)" \
	"NO count at all fails (guard said $got) -- the fail-open path, dead"

# --- 3. THE CONTROL. Without this, a guard that failed on everything satisfies rows 1 and 2. ----------
got="$(guard_says "$(noise; line 592)")"
check "$([ "$got" = pass ] && echo 0 || echo 1)" \
	"a count ABOVE the floor passes (592 >= $MIN, guard said $got) -- the guard is not always-fail"

# --- 4-5. The boundary, in both directions. `-lt` and `-le` are one keystroke apart and the floor is
# documented as "below the floor fails", so the value AT the floor must pass. ------------------------
got="$(guard_says "$(noise; line "$MIN")")"
check "$([ "$got" = pass ] && echo 0 || echo 1)" \
	"exactly AT the floor passes ($MIN, guard said $got)"
got="$(guard_says "$(noise; line $((MIN - 1)))")"
check "$([ "$got" = fail ] && echo 0 || echo 1)" \
	"one below the floor fails ($((MIN - 1)), guard said $got)"

# --- 6. THE PARSER HAS A POSITIVE CONTROL. Rows 1 and 5 fail for the right reason only if the count was
# actually READ; a grep that matched nothing would make them fail as row 2 does, and every assertion
# above would still be green. So read the number back and compare it. -------------------------------
got="$(capture_colour_count "$(noise; line 592)")"
check "$([ "$got" = "592" ] && echo 0 || echo 1)" \
	"the parser reads the number back out (got '${got:-empty}', want 592) -- otherwise rows 1 and 5 "\
"would be failing as row 2 and nothing above could tell"
got="$(capture_colour_count "$(noise)")"
check "$([ -z "$got" ] && echo 0 || echo 1)" \
	"...and reports the empty string when there is no line (got '${got:-empty}')"

# --- 7. A SECOND COUNT MUST NOT BE ABLE TO RESCUE A FIRST ONE. `head -1` is load-bearing: the shutter
# prints once per capture, but the run's stdout carries every capture's output when a caller batches
# them, and a guard that picked the LAST match would judge one moment by another's frame. ------------
got="$(capture_colour_count "$(line 45; line 592)")"
check "$([ "$got" = "45" ] && echo 0 || echo 1)" \
	"with two counts present the FIRST is taken (got '${got:-empty}', want 45)"

if [ "$fails" -eq 0 ]; then
	echo "test_capture_moments: PASS."
	exit 0
fi
echo "test_capture_moments: FAIL -- $fails assertion(s)." >&2
exit 1
