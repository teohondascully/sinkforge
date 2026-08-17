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
	if [ "$waited" -ge 900 ]; then
		echo "with_machine: gave up after 900s waiting for the lock (held by pid ${holder:-?})" >&2
		exit 5
	fi
	[ $((waited % 30)) -eq 0 ] && echo "  waiting for the machine lock (held by pid ${holder:-?}) ..." >&2
	sleep 1
	waited=$((waited + 1))
done
printf '%s\n%s\n' "$$" "$ROOT" > "$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT INT TERM

"$GODOT" --path "$ROOT" "$@"
