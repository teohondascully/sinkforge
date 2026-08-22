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
	130) meaning="INTERRUPTED (SIGINT) partway through -- a partial sweep, not a verdict"
	    bad=1 ;;
	143) meaning="TERMINATED (SIGTERM) partway through: a job timeout, an OOM, or a kill. Not a verdict"
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
# SUBSET RUNS ARE CHECKED TOO. The exemption that stood here read "SF_ONLY selects a handful of layers, so
# the set legitimately will not match and firing here would train people to ignore it", and that was true
# when it was written -- before `sd_absent` existed. It is not true now: a registered layer that did not
# run in this job is named and held out BY ID, so the comparison is already restricted to the layers that
# actually reported, which is exactly what the exemption was hand-waving.
#
# What it cost is the reason it is gone. The one job whose stand-downs most needed checking is the display
# job, and the display job selects by SF_GL_ONLY, prints `SUBSET RUN`, and therefore had its stand-downs
# unexamined on every run it has ever made. An exemption written for ad-hoc SF_ONLY runs was silently
# covering a permanent CI job.
#
# Verified in both directions on a three-layer subset before removing it. Clean, it reports `exactly the
# registered ones, 2 id(s)` and names the six registered layers that did not run. With one invented
# `SKIP: [grapple.invented-row]` appended to a layer log, it reports NOT REGISTERED and exits 1. A gate
# that has not been shown to fail is not a gate.
SD_REG="$(dirname "$0")/stand_downs.txt"
if [ ! -s "$SD_REG" ]; then
	note "!! the stand-down registry at $SD_REG is missing or empty, so 'exactly these and no others' was"
	note "   not checked. That is an unverified run, not a clean one."
	bad=1
else
	# WHAT FIRED, BY ID. `_stand_down()` prints `SKIP: [id] ...`; the bracket is the machine-readable part
	# and the `SKIP:` prefix is unchanged so the runner's own counter still sees these lines.
	sd_ids="$(cat "$LOGDIR"/*.log 2>/dev/null \
		| sed -nE 's/^[[:space:]]*SKIP:[[:space:]]*\[([^]]+)\].*/\1/p' | sort -u)"
	sd_count="$(cat "$LOGDIR"/*.log 2>/dev/null | grep -cE '^[[:space:]]*SKIP:')"
	# THE OTHER TWO RESOLUTIONS. A `SKIP:` line says an assertion was DECLINED, and for the life of this
	# registry that was the only thing a row could ever say. Absence meant nothing, so an `env` row -- a row
	# permitted but conditional -- could not fail in either direction and half the file was documentation
	# with a tab in it. `_asserted()` and `_not_reached()` in tools/check_base.gd close it from the other
	# side: the layer now says when it MADE the assertion and when it knows a sibling branch will not be
	# entered, and this gate derives the third state from the two.
	held_ids="$(cat "$LOGDIR"/*.log 2>/dev/null \
		| sed -nE 's/^[[:space:]]*HELD:[[:space:]]*\[([^]]+)\].*/\1/p' | sort -u)"
	unre_ids="$(cat "$LOGDIR"/*.log 2>/dev/null \
		| sed -nE 's/^[[:space:]]*UNREACHED:[[:space:]]*\[([^]]+)\].*/\1/p' | sort -u)"
	# WHICH REGISTERED LAYERS ACTUALLY RAN. A layer with no display prints `<name>: SKIP - no display` --
	# `: SKIP` MID-LINE, which is deliberately not the `^SKIP:` marker, so it contributes no ids. Treating
	# its absence as "stood down zero" is a missing measurement read as a measured zero, and it would have
	# failed CI's headless job while reporting a debt paid.
	sd_ran() {
		_lg="$(ls "$LOGDIR"/*-"$1".log 2>/dev/null | head -1)"
		[ -n "$_lg" ] || return 1
		grep -qE "^$1: SKIP" "$_lg" && return 1
		return 0
	}
	sd_rows="$(awk -F'\t' '!/^#/ && NF > 3 { print $1 "\t" $2 "\t" $3 }' "$SD_REG")"
	sd_nrows="$(printf '%s\n' "$sd_rows" | grep -c .)"
	sd_bad=""; sd_absent=""; sd_env=""; sd_unknown=""
	# THE CONDITIONS AN `iff:` ROW MAY NAME, AND EVERY ONE OF THEM IS READ FROM THE RUN BEING JUDGED.
	#
	# That sentence was here before it was true. `no-display` came from the summary; `perf-host-unset` came
	# from THIS SHELL'S OWN ENVIRONMENT, which is a different frame, and the comment claiming otherwise sat
	# directly above both -- the same shape as the guards on this branch that a comment kept green.
	#
	# Locally the two frames agree, because the gate runs from `run_harness.sh`'s EXIT trap in the same
	# shell. IN CI THEY NEED NOT: the harness is one step with its own `env:` block, this gate is a separate
	# composite-action step, and step-level `env:` does not propagate. A perf job would have produced a run
	# where the budget correctly did not stand down and a gate insisting it must have -- the diagnosis
	# exactly backwards. Found in review, which also established why M9 could not have caught it: setting the variable
	# locally sets it for the sweep AND the gate at once, so the mutant cannot produce the divergence. A
	# MUTANT INHERITS THE TOPOLOGY OF THE RUN THAT HOSTS IT, and a fault in the topology is invisible to
	# every mutant run inside it.
	#
	# The runner now writes `perf-host=<name|unset>` into its header, so both conditions come from `$SUM`.
	_nodisplay=0
	grep -q 'NO DISPLAY' "$SUM" 2>/dev/null && _nodisplay=1
	# ABSENT IS NOT UNSET. A summary with no `perf-host=` token is an OLD one, from before the runner wrote
	# it, and the honest answer for a row that depends on it is "not checked" rather than a guess in either
	# direction. Named, never silent, on the same rule as an absent layer.
	_perfhost=""; _perfknown=0
	if grep -q 'perf-host=' "$SUM" 2>/dev/null; then
		_perfknown=1
		_perfhost="$(sed -n 's/.*perf-host=\([^,)]*\).*/\1/p' "$SUM" | head -1)"
		[ "$_perfhost" = "unset" ] && _perfhost=""
	fi
	if [ "$sd_nrows" -lt 1 ]; then
		note "!! the stand-down registry parsed to 0 rows -- its columns are TAB-separated and something"
		note "   has flattened them. Nothing was compared."
		bad=1
	else
		# 1. NOTHING UNREGISTERED, IN ANY OF THE THREE. This is the direction that matters most: an
		# assertion silently stopped. It now covers `HELD` and `UNREACHED` too, so an id that appears in
		# code and in no row of the registry is caught whichever way the code resolves it -- previously a
		# layer could invent an id and stay clean simply by not standing it down.
		for _id in $(printf '%s\n%s\n%s\n' "$sd_ids" "$held_ids" "$unre_ids" | grep -v '^$' | sort -u); do
			printf '%s\n' "$sd_rows" | cut -f1 | grep -qx "$_id" \
				|| sd_bad="$sd_bad ${_id}(NOT REGISTERED)"
		done
		# 2. EVERY `always` ID WHOSE LAYER RAN MUST BE THERE, so the list is tightened when a debt is paid.
		# EVERY registered layer is tested for having run, not only the ones carrying an `always` row.
		# Checking only `always` rows would leave a layer whose entries are all `env` -- check_frametime is
		# exactly that -- silently exempt, which is the licence the naming exists to prevent: it would stop
		# running one day and no line anywhere would say so.
		while IFS="$(printf '\t')" read -r _id _layer _kind; do
			[ -n "$_id" ] || continue
			if ! sd_ran "$_layer"; then
				case " $sd_absent " in *" $_layer "*) ;; *) sd_absent="$sd_absent $_layer" ;; esac
				continue
			fi
			_fired=0
			printf '%s\n' "$sd_ids" | grep -qx "$_id" && _fired=1
			# 2a. WAS THE ROW ACCOUNTED FOR AT ALL? Declared minus resolved, derived HERE rather than at
			# the site, because a branch that is not taken cannot announce that it was not taken -- put
			# the third state at the site and its absence is the original defect wearing a new label.
			# Caught in review before it shipped. The gate always runs; a branch may not.
			#
			# NOTE THE ONE PLACE THIS COULD NOT LIVE. The first attempt derived it in `_verdict()`, which
			# reads as the universal exit and is not: 29 of the 86 layers inheriting check_base.gd call
			# it and 57 print their own line and quit, including three of the seven layers that own rows
			# here. A hook on a path most of the population does not take is the same defect one level up.
			_resolved=0
			for _r in $sd_ids $held_ids $unre_ids; do
				[ "$_r" = "$_id" ] && { _resolved=1; break; }
			done
			if [ "$_resolved" != "1" ]; then
				sd_bad="$sd_bad ${_id}(UNACCOUNTED: $_layer ran and nothing in its log declined it,"
				sd_bad="$sd_bad asserted it, or said it was out of reach)"
				continue
			fi
			case "$_kind" in
				always)
					[ "$_fired" = "1" ] \
						|| sd_bad="$sd_bad ${_id}(REGISTERED always, NOT SEEN and $_layer ran)" ;;
				# 3. AN `iff:` ROW NAMES THE CONDITION THAT GATES IT, and is then a real assertion in BOTH
				#    directions: fired without the condition, or absent with it, are both a red. This
				#    exists because `env` rows CANNOT FAIL -- the presence check skipped them and the
				#    registration check passes anything listed -- so half the registry was a comment with
				#    a tab in it, inside the file built to stop assertions going missing. Found in review.
				#
				#    Only rows whose condition can be STATED get one, and that is the useful part: the
				#    rows that resist a condition are exactly the rows worth being suspicious of.
				iff:no-display)
					if [ "$_nodisplay" = "1" ] && [ "$_fired" != "1" ]; then
						sd_bad="$sd_bad ${_id}(headless and $_layer ran, so it MUST stand down)"
					elif [ "$_nodisplay" != "1" ] && [ "$_fired" = "1" ]; then
						sd_bad="$sd_bad ${_id}(fired WITH a display, where it must not)"
					fi ;;
				iff:perf-host-unset)
					if [ "$_perfknown" != "1" ]; then
						sd_unknown="$sd_unknown ${_id}(the summary predates perf-host= and cannot say)"
					elif [ -z "$_perfhost" ] && [ "$_fired" != "1" ]; then
						sd_bad="$sd_bad ${_id}(the RUN had SF_PERF_HOST unset and $_layer ran, so it MUST"
						sd_bad="$sd_bad stand down)"
					elif [ -n "$_perfhost" ] && [ "$_fired" = "1" ]; then
						sd_bad="$sd_bad ${_id}(fired on a run with SF_PERF_HOST=${_perfhost}, where it"
						sd_bad="$sd_bad must not)"
					fi ;;
				env)
					# NOT AN ASSERTION, AND SAID SO OUT LOUD. Reporting every `env` id that fired costs
					# nothing and is the difference between a conditional stand-down quietly becoming
					# permanent and a human noticing one appear between two runs. It is how the
					# headless-only `dig-hitch.byte-identity` would have been found months earlier.
					# REPORTED IN WHICHEVER STATE IT LANDED, not only when it fires. The point of
					# the third state is that an `env` row now says something on every run, so the line
					# below is how a conditional stand-down quietly becoming permanent -- or quietly
					# becoming unreachable -- shows up between two sweeps instead of after a season.
					if [ "$_fired" = "1" ]; then
						sd_env="$sd_env ${_id}=stood-down"
					elif printf '%s\n' "$held_ids" | grep -qx "$_id"; then
						sd_env="$sd_env ${_id}=ASSERTED"
					else
						sd_env="$sd_env ${_id}=out-of-reach"
					fi ;;
			esac
		done <<EOF
$sd_rows
EOF
		if [ -n "$sd_unknown" ]; then
			note "stand-downs: conditions this summary cannot answer, so not checked:$sd_unknown"
		fi
		if [ -n "$sd_env" ]; then
			note "stand-downs: conditional (env) rows and how each resolved this run:$sd_env"
			# ASSERTED IS NOT A DELETION NOTICE, and the line that said so was inviting the wrong edit.
			# An `env` row resolves ASSERTED on the machines that CAN reach the assertion; several of
			# these exist precisely FOR the machines that cannot. `save-durability.failed-backup` has never fired on
			# macOS because the platform refuses the write that forces the path. Deleting either on the
			# strength of an ASSERTED here would remove the protection exactly where it is needed and
			# leave a green sweep saying nothing about it.
			note "   ASSERTED means this run reached the assertion. Before deleting a row, read it:"
			note "   several exist for the machines where they do NOT resolve ASSERTED."
		fi
		if [ -n "$sd_absent" ]; then
			# NAMED, NEVER SILENT. An exemption nobody prints is a licence: a layer that quietly stopped
			# running would be excused forever instead of noticed.
			note "stand-downs: registered layers that did not run in this job, so not checked:$sd_absent"
		fi
		if [ -z "$sd_bad" ]; then
			note "stand-downs: exactly the registered ones, $(printf '%s\n' "$sd_ids" | grep -c .) id(s),"\
				"$sd_count line(s) in total"
		else
			note "!! THE STAND-DOWNS ARE NOT THE REGISTERED ONES:$sd_bad"
			note "   An id not in the registry means something stopped asserting and nobody said so."
			note "   An 'always' id missing while its layer RAN means the debt was paid and the registry"
			note "   is stale. An 'iff:' id on the wrong side of its own condition means the condition"
			note "   moved. UNACCOUNTED means the layer ran and said nothing at all about a row the"
			note "   registry gives it -- add _asserted() to the branch that makes the assertion, or"
			note "   _not_reached() to the branch that skips past it. None is a pass."
			bad=1
		fi
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
