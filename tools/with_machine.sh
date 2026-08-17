#!/usr/bin/env bash
# RUN SOMETHING THAT BOOTS GODOT, HOLDING THE MACHINE-WIDE LOCK.
#
#   GODOT=/opt/homebrew/bin/godot bash tools/with_machine.sh --script res://tools/check_frametime.gd
#   GODOT=/opt/homebrew/bin/godot bash tools/with_machine.sh --script res://tools/capture_moments.gd -- delve
#
# Everything after the script name is passed to Godot; `--path <repo>` is supplied.
#
# WHY THIS EXISTS, stated plainly because I am the reason. `run_harness.sh` takes this lock and
# `profile.sh` takes this lock, and I still put eight concurrent Godot processes on a busy box
# three separate times — because a single layer run, or a capture, is `godot --script ...` typed straight
# into a shell, and that path never touched a lock at all. I fixed the profiler and thought the hole was
# closed; the hole was every OTHER ad-hoc invocation, which is most of them.
#
# The rule that survives is about tools and not about people: ANYTHING THAT BOOTS GODOT TAKES THE LOCK.
# A protocol that depends on remembering to check is not a protocol, and this is the third piece of
# evidence for that in one session. Run one-off scripts through here.
#
# Exit 5 = gave up waiting. Otherwise Godot's own exit code is passed through, so `SKIP_CODE=42` and the
# harness's three-state protocol survive the wrapper.

set -uo pipefail
GODOT="${GODOT:-godot}"
LOCK="${SF_LOCK:-${TMPDIR:-/tmp}/sinkforge-harness.lock}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# How long to wait before giving up, overridable so the GIVE-UP PATH IS TESTABLE. It was not: proving that
# a timeout exits 5 rather than 0 meant holding the lock for fifteen minutes, so nobody ever proved it, and
# the one path in this script that must never be mistaken for success was the one path never exercised.
WAIT="${SF_LOCK_WAIT:-900}"

# THESE ARE GODOT ARGUMENTS, NOT A COMMAND, and the difference cost 39 minutes of machine
# time. `bash tools/with_machine.sh bash tools/run_harness.sh` reads like a runner taking a command; it
# actually becomes `godot --path <repo> bash tools/run_harness.sh`, which Godot accepts — it ignores the two
# junk positionals, boots the project, and PLAYS THE GAME until something kills it. No layer runs. Elapsed
# time and CPU both look perfect, because a game is genuinely running; only the argv shows it.
#
# So the malformed call is refused here rather than left to be spotted. Every real invocation starts with a
# Godot flag (`--headless`, `--script`, `--path`), so a first argument that is not a flag is this mistake
# every time. Refused BEFORE the lock is taken: a bad call must not queue behind anyone, and must not make
# anyone queue behind it.
if [ "$#" -eq 0 ] || { [ "${SF_ALLOW_POSITIONAL:-0}" != "1" ] && case "$1" in -*) false ;; *) true ;; esac; }; then
	echo "with_machine: REFUSED — these are GODOT arguments, not a shell command." >&2
	echo "with_machine:   you wrote:  with_machine.sh $*" >&2
	echo "with_machine:   which runs: $GODOT --path <repo> $*" >&2
	echo "with_machine:   ...and Godot would ignore those and just play the game." >&2
	echo "with_machine: try:  with_machine.sh --headless --script res://tools/check_thing.gd" >&2
	echo "with_machine: (run_harness.sh takes the lock itself — do not wrap it.)" >&2
	echo "with_machine: REFUSED — NOTHING RAN. Not a pass."
	exit 2
fi

waited=0
until mkdir "$LOCK" 2>/dev/null; do
	holder="$(head -1 "$LOCK/owner" 2>/dev/null)"
	# A run that was killed cannot release its own lock, so a holder whose pid is gone is cleared rather
	# than being allowed to wedge every future run.
	if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
		echo "  (clearing a stale lock: pid $holder is gone)" >&2
		rm -rf "$LOCK"
		continue
	fi
	if [ "$waited" -ge "$WAIT" ]; then
		# LOUD, and on stdout as well as stderr. A give-up is a run that NEVER HAPPENED, and the failure
		# mode is not that somebody misreads the exit code — it is that nothing downstream ever looks at
		# it. A backgrounded call reports "completed"; a shell that appends `; echo done` reports 0. So
		# say in words, in the output a human actually skims, that no test ran.
		echo "with_machine: GAVE UP after ${waited}s waiting for the lock (held by pid ${holder:-?})" >&2
		echo "with_machine: NOTHING RAN — this is not a pass (exit 5)" >&2
		echo "with_machine: GAVE UP — NOTHING RAN. Not a pass."
		exit 5
	fi
	[ $((waited % 30)) -eq 0 ] && echo "  waiting for the machine lock (held by pid ${holder:-?}) ..." >&2
	sleep 1
	waited=$((waited + 1))
done
printf '%s\n%s\n' "$$" "$ROOT" > "$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT INT TERM

"$GODOT" --path "$ROOT" "$@"
