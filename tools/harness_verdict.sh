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
# THIS LIVES UNDER `tools/` AND NOT UNDER `.github/`, AND THAT IS THE POINT. It began as a CI-only script,
# which left the one gate against a green over layers that never ran unreachable from the command line, so
# `tools/run_harness.sh` carried a comment saying, accurately, "CI is gated against that; a local run is
# not." The reader most exposed to that green is whoever is running the sweep by hand to decide whether to
# commit, and they were the only one it did not protect. Both callers now run THIS file:
#
#   .github/actions/harness-verdict/action.yml   after each CI job
#   tools/run_harness.sh                          from its EXIT trap, before the log directory is removed
#
# Usage: harness_verdict.sh <log-dir> <label> [notes-file]
#
# `notes-file`, when given, receives the plain verdict lines: no markdown, no second copy of the table. The
# local runner points it at the sweep's own summary.txt, so a RETAINED log directory carries the answer to
# "was this a result" beside the result itself, for the later reader who has nothing but the directory.
set -uo pipefail
LOGDIR="${1:?log-dir}"
LABEL="${2:-harness}"
NOTES="${3:-}"
SUM="$LOGDIR/summary.txt"
bad=0
OUT="${GITHUB_STEP_SUMMARY:-/dev/null}"

## Every verdict line goes to the terminal, to the CI step summary, and to the notes file when there is one.
## The trailing `return 0` is not decoration: under `set -e` in a caller, a `note` whose final command is a
## failed append would take the gate down mid-verdict and report nothing.
note() {
	printf '%s\n' "$*"
	printf '%s\n' "$*" >>"$OUT"
	[ -n "$NOTES" ] && printf '%s\n' "$*" >>"$NOTES" 2>/dev/null
	return 0
}

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
	# THESE THREE WERE MISSING, AND THE FALLTHROUGH BELOW SAID SOMETHING FALSE ABOUT THEM. It printed
	# "run_harness.sh's own table does not list 43" for a code that table has listed since the day VOID
	# shipped. The guard against undocumented codes was itself the thing out of date, and it reported its
	# own staleness as a defect in the runner: an instrument blaming its subject for its own blind spot.
	6)  meaning="KILLED BY THE WALL-CLOCK CAP (tools/with_machine.sh): a truncated sweep, not a verdict"
	    bad=1 ;;
	43) meaning="VOID: a layer ran and could not measure its subject. Neither a pass nor a failure, because"
	    meaning="$meaning the sample was spoiled from outside the code. RE-RUN IT."
	    bad=1 ;;
	7)  meaning="a previous run of THIS gate rejected that sweep; the table below is the rejected one"
	    bad=1 ;;
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

# ZERO LOGS IS NOT ZERO PROBLEMS, and until this branch existed it scored as zero problems. `n_died` and
# `n_empty` are both 0 over an empty set, neither branch below fires, and the gate printed "every layer log
# carries the output of a layer that executed" -- vacuously true of no logs, and phrased as a positive
# verification. A gate written to catch 103 layers reporting PASS without running was issuing its own
# all-clear when it had read nothing at all.
#
# NOT LIVE WHEN IT WAS FOUND, AND THE REACHABILITY IS WORTH STATING RATHER THAN INFLATING. `SUM` is inside
# `LOGDIR`, so a missing or misdirected directory dies at the `[ ! -s "$SUM" ]` check above, before the log
# loop; and in CI `SF_LOG_DIR` and the action's `log-dir` are the same expression in the same file. What is
# real is the coupling: the `*.log` glob agrees with `run_harness.sh`'s log naming by CONVENTION, in a
# different file, with nothing relating them. Change the extension or push per-layer logs into a
# subdirectory and `summary.txt` stays exactly where it is, so every check above still passes while this
# loop reads an empty set.
#
# It is fixed here rather than later because this file is now also the LOCAL gate, and the precondition
# that kept it latent -- one log path, written once -- is precisely what does not hold on a workstation
# with worktrees, `SF_LOG_DIR` overrides and retained directories from older naming schemes.
if [ "$n_logs" -eq 0 ]; then
	note "!! NO LAYER LOGS WERE READ. Whatever the table says, this gate verified nothing: the checks"
	note "   below for load failures and silent layers were run over an empty set and passed by default."
	bad=1
fi
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

# --- THE STAND-DOWNS: EXACTLY THESE, AND EXACTLY THIS MANY ------------------------------------------
#
# A full sweep with a display CANNOT reach exit 0 and never will: four layers stand assertions down for
# structural reasons, each naming why a bound cannot responsibly be set. That makes "the full sweep is
# green" an unreachable gate, and an unreachable gate is met by deleting honest stand-downs or inventing
# bounds nobody earned. The reachable, checkable target is the one asserted here: EXIT 4, WITH EXACTLY
# THESE STAND-DOWNS AND NO OTHERS. See tools/stand_downs.txt for the registry and each reason.
#
# SYMMETRIC, and the second direction is the one that matters: an unregistered stand-down is a red because
# nobody may quietly stop asserting something, AND a registered layer standing down fewer is ALSO a red,
# because a list that is not tightened when the debt is paid stops being a bound and becomes a licence.
#
# SUBSET RUNS ARE EXEMPT, and this is a real exemption rather than a convenience: SF_ONLY selects a handful
# of layers, so the set legitimately will not match and firing here would train people to ignore it.
SD_REG="$(dirname "$0")/stand_downs.txt"
if grep -q 'SUBSET RUN' "$SUM" 2>/dev/null; then
	note "stand-downs: not checked (SUBSET RUN -- the registry describes a full sweep)"
elif [ ! -s "$SD_REG" ]; then
	note "!! the stand-down registry at $SD_REG is missing or empty, so 'exactly these four' was not"
	note "   checked. That is an unverified run, not a clean one."
	bad=1
else
	sd_seen=""; sd_total=0
	for lg in "$LOGDIR"/*.log; do
		[ -f "$lg" ] || continue
		_n="$(grep -cE '^[[:space:]]*SKIP:' "$lg" 2>/dev/null)"
		[ -n "$_n" ] && [ "$_n" -gt 0 ] 2>/dev/null || continue
		_slug="$(basename "$lg" .log | sed 's/^[0-9]*-//')"
		sd_seen="$sd_seen $_slug:$_n"
		sd_total=$((sd_total + _n))
	done
	# THE REGISTRY MUST HAVE PARSED. Its rows are TAB-separated and a file whose tabs became spaces yields
	# no rows, which agrees with a sweep that stood nothing down -- the empty-set-agrees-with-empty-set
	# failure this gate exists to refuse one level up.
	sd_rows="$(awk -F'\t' '!/^#/ && NF > 2 { print $1 ":" $2 }' "$SD_REG" | sort | tr '\n' ' ')"
	sd_nrows="$(printf '%s' "$sd_rows" | wc -w | tr -d ' ')"
	sd_have="$(printf '%s' "$sd_seen" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ')"
	if [ "$sd_nrows" -lt 1 ]; then
		note "!! the stand-down registry parsed to 0 rows -- its rows are TAB-separated and something has"
		note "   flattened them. Nothing was compared."
		bad=1
	elif [ "$sd_have" = "$sd_rows" ]; then
		note "stand-downs: exactly the $sd_nrows registered, $sd_total assertion group(s) in total"
	else
		note "!! THE STAND-DOWNS ARE NOT THE REGISTERED ONES. Both directions are a red: an unlisted layer"
		note "   stopped asserting something, or a listed one now asserts more and the registry is stale."
		note "     registered: $sd_rows"
		note "     this run  : $sd_have"
		note "   tools/stand_downs.txt is the list, with the reason each one carries no bound."
		bad=1
	fi
fi

# ONE GREPPABLE LINE BESIDE THE SENTENCES. `HARNESS_EXIT=` says what the SWEEP concluded; `HARNESS_RESULT=`
# says whether that conclusion may be quoted at all, and those are different questions that were previously
# answered by the same integer. Retained log directories are this repository's regression history -- the
# archive gets grepped to answer "was it already red at that commit" -- and a history whose rows cannot say
# "this row is not evidence" is one that will eventually have every row read as though it were.
if [ "$bad" = "0" ]; then
	note "HARNESS_RESULT=yes"
	note "this run is a RESULT: the runner finished, every declared layer reported, and every layer log"
	note "carries the output of a layer that executed. The verdict above may be quoted."
else
	note ""
	note "HARNESS_RESULT=no"
	note "THIS RUN IS NOT A RESULT. Do not read the harness's verdict as pass or fail — re-run it."
fi
printf '```\n' >>"$OUT"
exit "$bad"
