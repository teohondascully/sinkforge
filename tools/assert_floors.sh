#!/bin/bash
# HAS ANY LAYER QUIETLY STOPPED ASSERTING THINGS?
#
# Not a harness layer, and named so it cannot be mistaken for one: it needs a finished sweep's per-layer
# logs, which no layer has. The runner calls it from `harness_cleanup`, beside the verdict gate, and a
# non-zero status here means the sweep above is not quotable for the same reason the gate's is not.
#
# `_verdict()` already refuses a green that asserted NOTHING. Between zero and everything there was no
# floor: the widest layer in this suite makes 112 assertions and could have fallen to one, silently, and
# still printed PASS. An early `return` after a guard, a loop whose population went empty, a block moved
# behind a condition that is now always false -- all of them leave a green.
#
# Usage:
#   bash tools/assert_floors.sh <log-dir> <summary-file>     judge
#   bash tools/assert_floors.sh --write <log-dir>            regenerate the floors from that sweep
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLOORS="$ROOT/tools/assert_floors.txt"

# TWO RULES, BECAUSE THE SUITE SPEAKS TWO DIALECTS. `_verdict()` prints "(N asserted)", which is the exact
# count and is preferred wherever it exists. The shell layers and the four `tests/test_*.gd` rows have no
# `_check` to count and print one PASS line per claim instead, which is the same quantity arrived at
# differently. Counting those brings in the four largest bodies of assertions in the suite: `sim` at 526,
# `stress` at 447, `power_water` at 203 and `worldgen` at 147, none of which anything held before.
#
# LAST match on the asserted form: a layer that prints an intermediate tally must not have it read as the
# verdict.
count_in() {
	local c
	c="$(grep -o '([0-9]\+ asserted)' "$1" 2>/dev/null | grep -o '[0-9]\+' | tail -1)"
	if [ -n "$c" ]; then printf '%s\tasserted' "$c"; return; fi
	# A LAYER THAT FAILED STILL ASSERTED. `_verdict()` prints "(N asserted)" only on the passing path; a
	# failing one prints "check_x: 1 FAILURE(S) of 13 asserted", with no parentheses. The pattern above
	# misses it, the pass-line rule below then counts 12 PASS lines, and the gate compares a pass-line
	# count against a floor set from an asserted count and reports a drop that did not happen. That is
	# exactly what it did to `check_grapple_reads` on the 2026-08-23 sweep: "asserted 12, floor is 13",
	# against a layer whose own summary line said 13.
	c="$(grep -o 'of [0-9]\+ asserted' "$1" 2>/dev/null | grep -o '[0-9]\+' | tail -1)"
	if [ -n "$c" ]; then printf '%s\tasserted' "$c"; return; fi
	c="$(grep -cE '^[[:space:]]*(PASS|ok|OK)[: ]' "$1" 2>/dev/null)"
	[ "${c:-0}" -gt 0 ] && printf '%s\tpasslines' "$c"
}

# Every "<layer>\t<count>\t<rule>" a log directory reports, sorted. The one place the sweep is read, so the
# control below and the real comparison cannot disagree about what a sweep says. The rule is carried in the
# row because two rules producing one number is exactly the kind of thing a reader has to be told.
counts_in() {
	local d="$1" f n c
	for f in "$d"/*.log; do
		[ -e "$f" ] || continue
		n="$(basename "$f" .log | sed 's/^[0-9]*-//')"
		c="$(count_in "$f")"
		[ -n "$c" ] && printf '%s\t%s\n' "$n" "$c"
	done | sort
}

# Every complaint about one (floors, observed) pair, one per line. Empty output means agreement.
compare() {
	local floors="$1" observed="$2"
	awk -F'\t' '
		NR == FNR { if ($0 !~ /^#/ && NF >= 2) { want[$1] = $2; rule[$1] = $3 }; next }
		{
			seen[$1] = $2
			if (!($1 in want)) { print "  UNFLOORED: " $1 " asserts " $2 " and has no row" ; next }
			# TWO RULES ARE TWO QUANTITIES, and a floor set under one cannot convict a count taken
			# under the other. The guard sits inside the complaint and not in front of it: the two
			# rules agree exactly for most passing layers, so refusing to judge every row whose rule
			# moved would silence the gate on whole sweeps to prevent an error that only ever happens
			# when it is about to accuse. A shortfall measured across a rule change is unjudged and
			# says so; a shortfall under the same rule is still a drop.
			if ($2 + 0 < want[$1] + 0) {
				if (rule[$1] != "" && $3 != "" && $3 != rule[$1]) {
					print "  RULE CHANGED: " $1 " has a floor of " want[$1] " set by the " \
						rule[$1] " rule and this run reported " $2 " by the " $3 \
						" rule; those are different quantities, so this row is unjudged"
				} else {
					print "  DROPPED: " $1 " asserted " $2 ", floor is " want[$1]
				}
			}
		}
		END { for (k in want) if (!(k in seen)) print "  MISSING: " k " has a floor of " want[k] " and reported no count" }
	' "$floors" "$observed" | sort
}

if [ "${1:-}" = "--write" ]; then
	dir="${2:?a log dir}"
	tmp="$(mktemp)"
	grep '^#' "$FLOORS" > "$tmp"
	counts_in "$dir" >> "$tmp"
	mv "$tmp" "$FLOORS"
	echo "assert_floors: wrote $(grep -c -v '^#' "$FLOORS") rows from $dir"
	exit 0
fi

DIR="${1:?a log dir}"
SUMMARY="${2:-}"

if [ ! -r "$FLOORS" ]; then
	echo "assert_floors: REFUSED -- $FLOORS is not readable, so there is nothing to hold the sweep to." >&2
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi

# A SUBSET HAS NO OPINION about layers it did not run, and a different stand-down set means different
# assertions were reached. Both say so rather than inventing a verdict.
# READ ONCE. Both questions below are asked of the summary, and asking a second time is only free when the
# argument is a real file: a caller who hands over a pipe gets the first grep and an empty string for the
# second, which reads here as "no stand-down line" and skips the check. Found by a control that passed for
# that reason and not the intended one.
SUMTEXT=""
[ -n "$SUMMARY" ] && [ -r "$SUMMARY" ] && SUMTEXT="$(cat "$SUMMARY")"
if printf '%s' "$SUMTEXT" | grep -q 'SUBSET RUN'; then
	echo "assert_floors: not judged -- a subset run says nothing about the layers it did not run."
	echo "HARNESS_QUOTABLE=unjudged"
	exit 0
fi
want_stands="$(grep -o '^# stand-downs: [0-9]*' "$FLOORS" | grep -o '[0-9]*$')"
if [ -n "$SUMTEXT" ]; then
	got_stands="$(printf '%s' "$SUMTEXT" | grep -o 'stand-downs: exactly the registered ones, [0-9]* id' \
		| grep -o '[0-9]*' | head -1)"
	if [ -n "$want_stands" ] && [ -n "$got_stands" ] && [ "$want_stands" != "$got_stands" ]; then
		echo "assert_floors: not judged -- floors were taken under $want_stands stand-down(s), this run had $got_stands."
		echo "HARNESS_QUOTABLE=unjudged"
		exit 0
	fi
fi

OBS="$(mktemp)"; trap 'rm -f "$OBS" "${CTL:-}" "${CTL_OBS:-}"' EXIT
counts_in "$DIR" > "$OBS"
rows="$(grep -c -v '^#' "$FLOORS")"
seen="$(wc -l < "$OBS" | tr -d ' ')"

# THE COMPARISON MUST BE ABLE TO COMPLAIN, shown on this run and not argued. Everything below reports
# health when `compare` returns nothing, and returning nothing is what a broken field separator, a floors
# file that failed to parse, or an empty observed set all produce. One row is raised by one against a copy
# of what this very sweep reported, and the same function has to catch it; the untouched copy has to stay
# quiet. If either control misbehaves the instrument is broken and no verdict is printed.
CTL="$(mktemp)"; CTL_OBS="$(mktemp)"
head -1 "$OBS" > "$CTL_OBS"
ctl_layer="$(cut -f1 "$CTL_OBS")"
ctl_count="$(cut -f2 "$CTL_OBS")"
ctl_rule="$(cut -f3 "$CTL_OBS")"
printf '%s\t%s\t%s\n' "$ctl_layer" "$((ctl_count + 1))" "$ctl_rule" > "$CTL"
ctl_hits="$(compare "$CTL" "$CTL_OBS" | grep -c 'DROPPED')"
printf '%s\t%s\t%s\n' "$ctl_layer" "$ctl_count" "$ctl_rule" > "$CTL"
ctl_quiet="$(compare "$CTL" "$CTL_OBS" | grep -c .)"
# AND A THIRD CONTROL, for the rule guard added after the gate mis-read a failing layer. The same row at
# the same count, with only the rule name changed, must come back as unjudged and NOT as a drop.
printf '%s\t%s\t%s\n' "$ctl_layer" "$((ctl_count + 1))" "not-${ctl_rule}" > "$CTL"
ctl_mixed="$(compare "$CTL" "$CTL_OBS")"
ctl_mixed_flag="$(printf '%s' "$ctl_mixed" | grep -c 'RULE CHANGED')"
ctl_mixed_drop="$(printf '%s' "$ctl_mixed" | grep -c 'DROPPED')"
printf '%s\t%s\t%s\n' "$ctl_layer" "$ctl_count" "$ctl_rule" > "$CTL"
if [ "$ctl_mixed_flag" != "1" ] || [ "$ctl_mixed_drop" != "0" ]; then
	echo "assert_floors: REFUSED -- the rule control did not behave: a floor above $ctl_layer's" >&2
	echo "  $ctl_count under a different rule name produced $ctl_mixed_flag unjudged line(s) and" >&2
	echo "  $ctl_mixed_drop drop(s), where exactly one and none were due." >&2
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi
if [ "$ctl_hits" != "1" ] || [ "$ctl_quiet" != "0" ]; then
	echo "assert_floors: REFUSED -- the control did not behave: a floor one above $ctl_layer's $ctl_count" >&2
	echo "  produced $ctl_hits complaint(s) where one was due, and a floor equal to it produced $ctl_quiet" >&2
	echo "  where none was. The instrument is broken, so a clean verdict here would mean nothing." >&2
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi

BAD="$(compare "$FLOORS" "$OBS")"
if [ -n "$BAD" ]; then
	echo "assert_floors: FAIL -- $rows floor(s) against $seen layer(s) that reported a count"
	echo "$BAD"
	echo "  A layer that asserts fewer things than it used to is not a smaller layer, it is a quieter one."
	echo "  Lower a floor only in a commit that says which assertion went and why."
	# AND IT RETRACTS THE SENTENCE ABOVE IT. `HARNESS_RESULT=yes` answers "did this run happen", and it did.
	# The sentence the verdict gate prints under it, that the verdict may be quoted, is what stops being
	# true here, so the retraction gets its own key rather than a second HARNESS_RESULT line: two lines with
	# one key is a reader taking whichever one grep hands them first.
	echo "HARNESS_QUOTABLE=no"
	echo "  the run happened and its layer table is real; it may NOT be quoted as a green while a layer is"
	echo "  asserting less than it did. HARNESS_RESULT above answers the prior question, not this one."
	exit 1
fi
echo "assert_floors: PASS -- $seen layers still assert at least what they did (control: $ctl_layer at $ctl_count)"
echo "HARNESS_QUOTABLE=yes"
exit 0
