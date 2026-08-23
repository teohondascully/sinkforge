#!/bin/bash
# DID A LAYER SAY IT DID NOT RUN, AND THEN GET COUNTED AS A PASS?
#
# Not a harness layer, and named so it cannot be mistaken for one: it needs a finished sweep's per-layer
# logs and its summary table, which no layer can see. The runner calls it from `harness_cleanup` beside
# `assert_floors.sh`, and a non-zero status here means the sweep above is not quotable.
#
# WHY IT EXISTS. `check_bake_idempotent` guarded itself for the display it needs, printed
#
#     check_bake_idempotent: SKIP — needs a display (the bake is a SubViewport render target)
#
# and then exited 0. The harness's skip contract is exit 42; 0 is a pass. So in the headless CI job that
# layer reported green having rendered nothing, and the sentence saying otherwise sat in a log nothing
# reads. Nothing in the suite noticed, which is this repository's own test for whether a rule exists: a
# rule with no runner is a preference. This is the runner for it.
#
# THE TWO SKIP SHAPES ARE NOT THE SAME THING and telling them apart is the whole difficulty. A layer that
# declines ONE assertion prints an indented `SKIP: [some.id] ...` and is otherwise passing honestly, which
# is a stand-down and is accounted for by `tools/stand_downs.txt`. A layer that declines to RUN prints
# `<name>: SKIP ...` hard against the left margin. Only the second is the subject here. Catching the first
# would turn every honest stand-down into a red, which is the fastest way to get a gate switched off.
#
# ONLY THE FALSE-GREEN DIRECTION. A layer that announced a skip and then FAILED is odd, and it is loud;
# nobody files a red. The dangerous asymmetry is a skip counted as a pass, so that is what is refused.
#
# Usage:
#   bash tools/assert_skip_route.sh <log-dir> <summary-file>
set -u

# Log files are named from the script, summary rows from the display name, and the two are not the same
# string: `power/water (field/flood)` is logged as `power_water.log`. Both sides are normalised rather than
# one side special-cased, because a special case is a list and a list goes stale.
norm() { printf '%s' "$1" | tr -cs 'a-zA-Z0-9' '_' | sed 's/^_*//; s/_*$//'; }

# The announcement, if the layer made one. Anchored at column 0: an indented `SKIP:` is a stand-down.
announce_of() {
	grep -m1 -E '^[A-Za-z0-9_./-]+: SKIP([^A-Za-z0-9]|$)' "$1" 2>/dev/null
}

# The verdict word the runner wrote for a row. Taken as the FIRST of the known tokens after the `]`, so the
# reason text echoed into the row's tail -- which for a skip row repeats the word SKIP -- cannot be read as
# the verdict.
verdict_of() {
	printf '%s' "$1" | sed 's/^[^]]*\]//' | grep -oE '[[:space:]](PASS\*?|FAIL|SKIP|VOID)([[:space:]]|$)' \
		| head -1 | tr -d '[:space:]'
}

# THE ROW PATTERN TOLERATES THE PADDING, and the first version did not. The runner right-aligns the layer
# index, so a full sweep prints `[ 1/113]` and a one-layer subset prints `[ 1/ 1]` -- with a space after
# the slash. A pattern of `[0-9]+/[0-9]+` reads the second of those as no row at all, and a scan with no
# rows maps no logs, and a gate that maps no logs complains about nothing. The controls below caught it
# before this ever issued a verdict, which is the entire argument for running them every time.
#
# THE WHOLE JUDGEMENT, in one function, so the controls below and the real run cannot disagree about what a
# contradiction is. Prints one line per contradiction; prints nothing when there are none. Writes its
# population to $3 so the caller can refuse a scan that read nothing or could not map a log.
judge() {
	local dir="$1" sum="$2" tally="$3"
	local rows="" logs=0 mapped=0 unmapped=""
	rows="$(mktemp)"
	while IFS= read -r row; do
		local disp key v
		disp="$(printf '%s' "$row" | sed 's/^[^]]*\][[:space:]]*//; s/[[:space:]].*$//')"
		[ -z "$disp" ] && continue
		key="$(norm "$disp")"
		v="$(verdict_of "$row")"
		printf '%s\t%s\n' "$key" "$v" >>"$rows"
	done < <(grep -E '^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*[0-9]+[[:space:]]*\]' \
		"$sum" 2>/dev/null)

	local f
	for f in "$dir"/*.log; do
		[ -e "$f" ] || continue
		logs=$((logs + 1))
		local base name key ann v
		base="$(basename "$f" .log)"; name="${base#*-}"; key="$(norm "$name")"
		v="$(awk -F'\t' -v k="$key" '$1 == k { print $2; found = 1; exit } END { if (!found) print "" }' "$rows")"
		if [ -z "$v" ]; then unmapped="$unmapped $name"; continue; fi
		mapped=$((mapped + 1))
		ann="$(announce_of "$f")"
		[ -z "$ann" ] && continue
		case "$v" in
			PASS|PASS\*)
				printf '  %s reported %s while its own log says it did not run:\n' "$name" "$v"
				printf '      %s\n' "$ann"
				;;
		esac
	done
	printf '%d\t%d\t%s\n' "$logs" "$mapped" "$unmapped" >"$tally"
	rm -f "$rows"
}

# --- the controls, built from lines this suite actually printed --------------------------------------
# They run on every invocation and on synthetic dirs, because a gate that has never been shown failing is
# a gate nobody has tested. The positive control is the real historical line, not a paraphrase of it.
ctl_dir="$(mktemp -d)"
mkdir -p "$ctl_dir/a" "$ctl_dir/b" "$ctl_dir/c"

printf 'check_bake_idempotent: SKIP — needs a display (the bake is a SubViewport render target)\n' \
	>"$ctl_dir/a/00-check_bake_idempotent.log"
printf '  [ 1/ 1] check_bake_idempotent (bake holds)   PASS    1s\n' >"$ctl_dir/a/summary.txt"

printf '  SKIP: [ceremony.words-vs-sky] how well the words read against open sky was NOT asserted\n' \
	>"$ctl_dir/b/00-check_ceremony_reads.log"
printf '  [ 1/ 1] check_ceremony_reads (interrupt vs world) PASS*  14s  1 skipped: [ceremony.words-vs-sky]\n' \
	>"$ctl_dir/b/summary.txt"

printf 'check_opening: SKIP — no display; a picture cannot be judged by the dummy renderer\n' \
	>"$ctl_dir/c/00-check_opening.log"
printf '  [ 1/ 1] check_opening (no dead space)        SKIP    1s  check_opening: SKIP — no display\n' \
	>"$ctl_dir/c/summary.txt"

ctl_tally="$(mktemp)"
a_hits="$(judge "$ctl_dir/a" "$ctl_dir/a/summary.txt" "$ctl_tally" | grep -c 'reported')"
b_hits="$(judge "$ctl_dir/b" "$ctl_dir/b/summary.txt" "$ctl_tally" | grep -c 'reported')"
c_hits="$(judge "$ctl_dir/c" "$ctl_dir/c/summary.txt" "$ctl_tally" | grep -c 'reported')"
rm -rf "$ctl_dir"
if [ "$a_hits" != "1" ] || [ "$b_hits" != "0" ] || [ "$c_hits" != "0" ]; then
	echo "assert_skip_route: REFUSED -- the controls did not behave." >&2
	echo "  the real SKIP-then-PASS line produced $a_hits complaint(s) where 1 was due;" >&2
	echo "  a per-assertion stand-down produced $b_hits where 0 was due;" >&2
	echo "  an honest skip row produced $c_hits where 0 was due." >&2
	echo "  The instrument is broken, so a clean verdict here would mean nothing." >&2
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi

# --- the run ------------------------------------------------------------------------------------------
DIR="${1:-}"
SUM="${2:-}"
if [ -z "$DIR" ] || [ ! -d "$DIR" ] || [ -z "$SUM" ] || [ ! -r "$SUM" ]; then
	echo "usage: bash tools/assert_skip_route.sh <log-dir> <summary-file>" >&2
	exit 2
fi

tally="$(mktemp)"
BAD="$(judge "$DIR" "$SUM" "$tally")"
logs="$(cut -f1 "$tally")"; mapped="$(cut -f2 "$tally")"; unmapped="$(cut -f3 "$tally")"
rm -f "$tally"

# A SCAN THAT READ NOTHING IS NOT A CLEAN SWEEP, and a log it could not place in the table is not one it
# checked. Both are refusals rather than quiet passes: the population this gate covers has to equal the
# population the sweep ran, or the green describes a smaller run than the one that happened.
if [ "${logs:-0}" -eq 0 ]; then
	echo "assert_skip_route: REFUSED -- no per-layer logs were read, so nothing was checked."
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi
if [ -n "${unmapped// /}" ]; then
	echo "assert_skip_route: REFUSED -- $((logs - mapped)) of $logs log(s) match no row in the summary"
	echo "  table, so their verdicts were never read:$unmapped"
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi

if [ -n "$BAD" ]; then
	echo "assert_skip_route: FAIL -- a layer was counted as a pass after saying it did not run"
	echo "$BAD"
	echo "  A layer that declines to run exits 42 and the runner reports SKIP. Exiting 0 makes it a green"
	echo "  over a subject nothing looked at. If the layer cannot inherit \`_skip_layer()\`, it carries its"
	echo "  own \`const SKIP: int = 42\` -- see check_bake_idempotent."
	echo "HARNESS_QUOTABLE=no"
	exit 1
fi
echo "assert_skip_route: PASS -- $mapped layer(s) checked, none reported a pass over a skip"
exit 0
