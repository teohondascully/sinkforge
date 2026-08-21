#!/usr/bin/env bash
# IS THIS A RESULT AT ALL? Run after the harness, whatever the harness exited with.
#
# GitHub reports a job as red or green from one integer, and four of this runner's exit codes are neither
# "the tests passed" nor "a test failed". Worse, ONE of them is ambiguous in the direction that costs the
# most time: `exit 1` is what a layer returns when it asserted a property and found it false, and it is
# ALSO what a layer returns when it died before asserting anything — a parse error in a dependency, which
# in a checkout with an empty class-name cache is every layer at once. Same integer, opposite problems.
# One is a bug in the game; the other is a bug in the build, and only the second gets misread as the first.
#
# So the exit code is not allowed to mean anything until this has established that the run happened: that
# the runner finished, that every declared layer reported, and that no layer's log is the wreckage of a
# load failure. It fails the job on any of those even when the harness itself was green, because a green
# over layers that did not execute is the one outcome this whole harness exists to make impossible.
#
# Usage: verdict.sh <log-dir> <label>
set -uo pipefail
LOGDIR="${1:?log-dir}"
LABEL="${2:-harness}"
SUM="$LOGDIR/summary.txt"
bad=0
OUT="${GITHUB_STEP_SUMMARY:-/dev/null}"

note() { printf '%s\n' "$*"; printf '%s\n' "$*" >>"$OUT"; }

{
	printf '### %s\n\n' "$LABEL"
	printf '```\n'
	cat "$SUM" 2>/dev/null || printf 'no summary written — the runner produced no result table\n'
	printf '```\n\n'
	printf '**Was this a result?**\n\n```\n'
} >>"$OUT"

if [ ! -s "$SUM" ]; then
	note "!! NO SUMMARY TABLE at $SUM — the runner produced no result. This is not a failing run, it is"
	note "   an absent one: nothing here says which layers executed, so no verdict may be quoted from it."
	printf '```\n' >>"$OUT"
	exit 1
fi

grep -q '^== Sinkforge harness' "$SUM" || {
	note "!! the summary has no runner header — the harness died before it started its sweep."; bad=1; }

# `HARNESS_EXIT=` is written by the runner's EXIT trap, so its ABSENCE means the process was killed
# outright — job timeout, OOM, a cancelled run — and every number above it describes a partial sweep that
# nothing marked as partial.
rc="$(grep -m1 '^HARNESS_EXIT=' "$SUM" | cut -d= -f2)"
if [ -z "$rc" ]; then
	note "!! no HARNESS_EXIT line — the runner never reached its own cleanup, so it was killed rather than"
	note "   finished. Whatever the table shows, it is a truncated sweep and not a verdict."
	bad=1
fi
case "$rc" in
	0)  meaning="everything that ran passed" ;;
	1)  meaning="a layer FAILED — and 1 MASKS 4, so read the words for whether it was also incomplete" ;;
	2)  meaning="could not start: the sentinel would not arm, or a filter matched nothing" ;;
	3)  meaning="THE PRODUCTION SAVE SLOT WAS TOUCHED — layer results are moot" ;;
	4)  meaning="something was SKIPPED under SF_STRICT: this was NOT a full sweep" ;;
	5)  meaning="another harness run holds the machine lock; nothing ran" ;;
	"") meaning="UNKNOWN — no exit line" ;;
	# AN UNRECOGNISED CODE IS A RED, NOT A FOOTNOTE. This branch printed its warning and then fell through
	# to a clean exit while it was being written — the guard against codes nobody documented was passing
	# them. For every branch here, ask which way it exits.
	*)  meaning="UNDOCUMENTED CODE — run_harness.sh's own table does not list $rc"; bad=1 ;;
esac
note "harness exit ${rc:-<none>} — $meaning"

# EVERY DECLARED LAYER MUST HAVE REPORTED A ROW. A sweep that stopped halfway leaves an ordinary-looking
# table; only the count gives it away.
last="$(grep -oE '^ *\[ *[0-9]+/ *[0-9]+\]' "$SUM" | tail -1 | tr -d ' []')"
if [ -n "$last" ]; then
	got="${last%%/*}"; want="${last##*/}"
	note "layers reported: $got of $want"
	[ "$got" = "$want" ] || { note "!! the table stops at $got of $want — the sweep was truncated."; bad=1; }
else
	note "!! no layer rows in the summary at all — nothing executed."; bad=1
fi

# DELIBERATELY NOT A SEARCH FOR "PASS"/"FAIL". The first version of this did exactly that and flagged
# `measure_player`, which asserts perfectly well in its own words ("OK", "ALL WITHIN TOLERANCE") — fifteen
# of these layers extend SceneTree and each rolled its own vocabulary, so a pattern written against the
# base class is blind to a seventh of the suite. That is the same defect `fail_lines()` in the runner
# carries a paragraph about, reproduced one file away from it. So test for things no layer chooses: whether
# the ENGINE reported a load failure, and whether the log has any content at all.
#
# THE PATTERNS ARE TAKEN FROM MEASURED OUTPUT, NOT GUESSED, and the first draft proved why. It matched
# `Failed to load script`, which is what a PARSE error prints — and a script that does not exist at all
# prints `Failed loading resource` and `Can't load script` instead, three different sentences from three
# different source files. The gate against layers that did not run would have waved through the most
# complete way for a layer not to run: being deleted or renamed.
DEAD_RE="Parse Error|SCRIPT ERROR|Failed to load script|Can't load script|Failed loading resource"
DEAD_RE="$DEAD_RE|Attempt to open script|Cannot open file"
died=""; n_died=0; empty=""; n_empty=0; n_logs=0
for lg in "$LOGDIR"/*.log; do
	[ -f "$lg" ] || continue
	n_logs=$((n_logs + 1))
	if grep -qE "$DEAD_RE" "$lg"; then
		died="$died $(basename "$lg")"; n_died=$((n_died + 1)); continue
	fi
	if [ -z "$(grep -vE '^Godot Engine v|^$' "$lg")" ]; then
		empty="$empty $(basename "$lg")"; n_empty=$((n_empty + 1))
	fi
done
note "layer logs: $n_logs   engine-level load failures: $n_died   silent: $n_empty"

if [ "$n_died" -gt 0 ]; then
	note "!! THESE LAYERS DID NOT RUN — the engine could not load them. Their exit codes describe a BUILD"
	note "   failure, not a property failure, and are neither a pass nor a test result:"
	for s in $died; do note "     $s"; done
	bad=1
fi
if [ "$n_empty" -gt 0 ]; then
	note "!! THESE LAYERS PRODUCED NO OUTPUT AT ALL beyond the engine banner:"
	for s in $empty; do note "     $s"; done
	bad=1
fi

if [ "$bad" = "0" ]; then
	note "this run is a RESULT: the runner finished, every declared layer reported, and every layer log"
	note "carries the output of a layer that executed. The verdict above may be quoted."
else
	note ""
	note "THIS RUN IS NOT A RESULT. Do not read the harness's verdict as pass or fail — re-run it."
fi
printf '```\n' >>"$OUT"
exit "$bad"
