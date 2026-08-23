#!/usr/bin/env bash
# THE RUNNER'S EXIT TABLE AND THE GATE THAT INTERPRETS IT, HELD TO EACH OTHER.
#
#   bash tools/check_exit_codes.sh
#
# Two hand-maintained lists in two files that must agree, with nothing in the repository relating them:
#
#   tools/run_harness.sh       the documented table -- what each exit code MEANS
#   tools/harness_verdict.sh   a `case` over the same codes -- what a caller should DO about each
#
# BOTH HALVES HAVE ALREADY GONE STALE, separately, which is why this is a layer and not a comment.
#
#   The runner's own preamble said "there are FIVE" for long enough to outlive two additions, and then
#   said SEVEN while the list under it held eight. A count beside a list is a second copy of the list.
#
#   The gate handled 0 through 5 and nothing else, so a VOID run (43) and a capped run (6) both fell to
#   its `UNDOCUMENTED CODE` branch, which printed "run_harness.sh's own table does not list 43" about a
#   code that table had listed since the day VOID shipped. The guard against undocumented codes was the
#   thing out of date, and it reported its own blind spot as a defect in the file it was reading.
#
# So the count is gone from the prose and this derives the agreement instead. Needs no Godot and no
# display; it reads two files and runs in well under a second.
#
# WHAT IT WOULD TAKE TO FAIL, asked of every property here, because a structural check that cannot go red
# is decoration. Watched red for each: add a code to the runner's table (property 1 fails), delete a case
# label from the gate (1 fails), add a case label for a code nobody documented (2 fails), make the `*)`
# branch fall through without setting `bad` (3 fails), and point either path at a file that does not exist
# (4 fails, and it is FIRST for that reason -- see below).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
RUNNER="${SF_XC_RUNNER:-tools/run_harness.sh}"
GATE="${SF_XC_GATE:-tools/harness_verdict.sh}"

fails=0
ok() { echo "  PASS  $1"; }
no() { echo "  FAIL  $1" >&2; fails=$((fails + 1)); }

# THE INSTRUMENT ASSERTS ITSELF BEFORE IT ASSERTS ANYTHING ELSE, and this is the property the rest depend
# on. Both lists below are produced by matching a pattern against a file. A file that cannot be read, a
# block that got renamed, a pattern that stopped matching -- every one of those yields an EMPTY list, and
# an empty list agrees with an empty list. This layer would print two passes and a clean exit having
# compared nothing, which is the precise failure it was written to catch, one level up.
#
# A ZERO-RESULT SEARCH IS EVIDENCE ABOUT THE SEARCH. Both counts are floored here, and the floors are
# deliberately concrete rather than `> 0`: the table has held at least eight codes since VOID landed, and
# a drop below that is a parse failure wearing a plausible number.
codes_documented() {
	awk '/^# EXIT CODES/,/^# 0 IS THE MOST DANGEROUS/' "$RUNNER" \
		| sed -nE 's/^#[[:space:]]+([0-9]+)[[:space:]][[:space:]]+[A-Za-z].*$/\1/p' | sort -n | uniq
}
codes_handled() {
	sed -nE 's/^[[:space:]]+([0-9]+)\).*$/\1/p' "$GATE" | sort -n | uniq
}

doc="$(codes_documented)"
got="$(codes_handled)"
n_doc="$(printf '%s\n' "$doc" | grep -c '[0-9]' || true)"
n_got="$(printf '%s\n' "$got" | grep -c '[0-9]' || true)"

echo "check_exit_codes: $RUNNER documents $n_doc codes; $GATE handles $n_got"
if [ "$n_doc" -lt 8 ]; then
	no "(setup) the runner's exit table parsed to $n_doc codes, below the 8 it has carried since VOID -- \
this layer cannot compare lists it failed to read"
elif [ "$n_got" -lt 8 ]; then
	no "(setup) the gate's case table parsed to $n_got codes, below 8 -- same reason"
else
	ok "(setup) both tables parsed: $n_doc documented, $n_got handled"
fi

# 1. EVERY DOCUMENTED CODE IS INTERPRETED. This is the direction that hurts: a code the runner can return
#    and the gate has never heard of reaches the `*)` branch and is called undocumented, which is a false
#    statement about the runner rather than a true one about the gate.
missing=""
for c in $doc; do
	# NO PIPE HERE, AND THE REASON IS TWELVE LINES BELOW UNDER `_calls_gate`: `producer | grep -q` under
	# `pipefail` reports FAILURE when the match is found EARLY, because the producer takes SIGPIPE and 141
	# is promoted over grep's 0. That note was written for `_calls_gate` and the fix was applied only
	# there; these two loops kept the pattern and are the ones it bites, because a sorted list matches its
	# first entries first. It cost a red in the sweep at 97f1c7a -- code 0, line 1 of `got`, and code 4,
	# line 5 of `doc` -- while the same tree passed standalone with 11 documented and 11 handled.
	grep -qx "$c" <<< "$got" || missing="$missing $c"
done
if [ -n "$missing" ]; then
	no "codes the runner documents and the gate does not interpret:$missing"
else
	ok "every documented exit code has a case in $(basename "$GATE")"
fi

# 2. AND THE REVERSE, which is the quieter one. A case label for a code the runner cannot return is not
#    harmless: it is a reader's evidence that the code exists, and it will be believed.
extra=""
for c in $got; do
	grep -qx "$c" <<< "$doc" || extra="$extra $c"      # same reason as the loop above
done
if [ -n "$extra" ]; then
	no "codes the gate interprets that the runner's table does not document:$extra"
else
	ok "every interpreted exit code appears in the runner's table"
fi

# 3. THE FALLTHROUGH MUST REJECT. An unrecognised code is the one case neither list can enumerate, so the
#    default branch is the only thing standing behind both properties above. It has already been wrong once
#    in this file's history: it printed its warning and then exited clean, so the guard against codes nobody
#    documented was passing them.
# THE FIRST VERSION OF THIS PROPERTY COULD NOT FAIL, and it took a mutant to show it. It read the default
# branch with `sed -nE '/\*\)/,/;;/p'`, which looks like "the lines of that case entry" and is not: a sed
# range looks for its end address starting at the line AFTER the start, so when `*)` and its `;;` are the
# SAME line the range never terminates and runs to end of file. It then found a `bad=1` from an unrelated
# branch three checks further down and reported the property satisfied. Watched red with `bad=1` deleted
# from the branch: it passed. The awk below stops at the first `;;` inclusive, same line included.
if awk '/^[[:space:]]*\*\)/{f=1} f{print} f && /;;/{exit}' "$GATE" | grep -q 'bad=1'; then
	ok "the gate's default branch sets bad=1 rather than warning and passing"
else
	no "the gate's \`*)\` branch does not set bad=1 -- an unrecognised exit code would be waved through"
fi

# 4. THE GATE IS REACHABLE FROM BOTH CALLERS, because one implementation is the whole reason it moved out
#    of `.github/`. If either caller stops running it, the rules diverge again the moment one is edited.
#    FULL-LINE COMMENTS ARE STRIPPED FIRST, and both of these were written without that and could not fail.
#    Each file EXPLAINS the arrangement in prose above the call -- run_harness.sh:112 opens "BOTH CI AND A
#    LOCAL RUN ARE NOW GATED AGAINST THAT, by the same file: `tools/harness_verdict.sh`" -- so deleting the
#    actual invocation and leaving the paragraph left both properties green. Found in review, by running
#    the mutant rather than reasoning about it, and checked the two neighbouring structural greps in the
#    other direction to bound the claim to exactly these.
#
#    THE SENTENCE ASSERTING AN INVARIANT WAS KEEPING THE TEST OF THAT INVARIANT GREEN, which is the nastier
#    of the two directions this repository has now found in one night. The cap library's case was a comment
#    WARNING AGAINST a bad pattern and matching the search for it; this is a comment CLAIMING a good one,
#    and that stays true-looking and keeps passing long after it stops being true.
#    IT IS ONE PROCESS ON PURPOSE, and the pipe it replaces was a live flake rather than a tidiness
#    point. `producer | grep -q` under `pipefail` reports the pipeline as FAILED when the match is
#    found EARLY: `grep -q` exits at the first hit, the upstream `grep -v` is still writing, it takes
#    SIGPIPE and exits 141, and `pipefail` promotes 141 over the consumer's 0. The layer then prints
#    "does not call the gate" precisely BECAUSE the call is there. Measured at 1 in 400 quiet and
#    2 in 400 under 12 spinners on the 22KB runner, 400 in 400 on a 300KB control whose match is on
#    line 1, upstream 141 and downstream 0 in every failing trial. It cost a red in one full sweep.
#    The CI action never showed it: 491 bytes fits the pipe buffer, so its producer finishes first.
#    An unreadable file still fails, which is the direction this property needs: awk exits 2.
_calls_gate() {
	awk '/^[[:space:]]*#/ { next } /tools\/harness_verdict\.sh/ { hit = 1 } END { exit hit ? 0 : 1 }' "$1"
}
if _calls_gate "$RUNNER"; then
	ok "the local runner calls the gate"
else
	no "$RUNNER does not call tools/harness_verdict.sh -- local sweeps are ungated again"
fi
if _calls_gate .github/actions/harness-verdict/action.yml; then
	ok "the CI action calls the gate"
else
	no "the CI action does not call tools/harness_verdict.sh"
fi

if [ "$fails" = "0" ]; then
	echo "check_exit_codes: PASS ($n_doc codes, 6 asserted)"
	exit 0
fi
echo "check_exit_codes: FAIL ($fails)" >&2
exit 1
