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

# The count a layer's log reports, or empty when that log reports none. LAST match: a layer that prints an
# intermediate tally must not have it read as the verdict.
count_in() {
	grep -o '([0-9]\+ asserted)' "$1" 2>/dev/null | grep -o '[0-9]\+' | tail -1
}

# Every "<layer>\t<count>" a log directory reports, sorted. The one place the sweep is read, so the control
# below and the real comparison cannot disagree about what a sweep says.
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
		NR == FNR { if ($0 !~ /^#/ && NF == 2) { want[$1] = $2 }; next }
		{
			seen[$1] = $2
			if (!($1 in want)) { print "  UNFLOORED: " $1 " asserts " $2 " and has no row" ; next }
			if ($2 + 0 < want[$1] + 0) { print "  DROPPED: " $1 " asserted " $2 ", floor is " want[$1] }
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
printf '%s\t%s\n' "$ctl_layer" "$((ctl_count + 1))" > "$CTL"
ctl_hits="$(compare "$CTL" "$CTL_OBS" | grep -c 'DROPPED')"
printf '%s\t%s\n' "$ctl_layer" "$ctl_count" > "$CTL"
ctl_quiet="$(compare "$CTL" "$CTL_OBS" | grep -c .)"
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
