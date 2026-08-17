#!/usr/bin/env bash
# PROFILE THE FRAME, WITHOUT STANDING ON ANOTHER RUN.
#
# tools/profile_frame.gd boots a real window, digs a few hundred cells and does full-texture uploads. That
# is a genuine CPU+GPU load, so running it beside a harness makes BOTH results fiction — the harness times
# the profiler's contention, and the profiler times the harness's.
#
# This existed as a rule that a person had to remember, and it was broken within the hour by the person who
# wrote it: I checked the lock, saw another session holding it, said out loud that I was queued behind it,
# and then ran the profiler twice anyway. A convention only one of the two tools enforces is not a
# convention. So the profiler now takes the SAME machine-wide lock run_harness.sh takes, and waits.
#
#   GODOT=/opt/homebrew/bin/godot bash tools/profile.sh
#
# SF_LOCK overrides the lock path (must match the runner's). Exit 5 = gave up waiting for the lock.

set -uo pipefail
GODOT="${GODOT:-godot}"
LOCK="${SF_LOCK:-${TMPDIR:-/tmp}/sinkforge-harness.lock}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

waited=0
until mkdir "$LOCK" 2>/dev/null; do
	holder="$(cat "$LOCK/owner" 2>/dev/null | head -1)"
	# A run that was killed cannot release its own lock, so a holder whose pid is gone gets cleared rather
	# than wedging every future run. Same reasoning, and the same treatment, as the runner's.
	if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
		echo "  (clearing a stale lock: pid $holder is gone)"
		rm -rf "$LOCK"
		continue
	fi
	if [ "$waited" -ge 900 ]; then
		echo "profile: gave up after 900s waiting for the lock (held by pid ${holder:-?})" >&2
		exit 5
	fi
	[ $((waited % 30)) -eq 0 ] && echo "  waiting for the harness lock (held by pid ${holder:-?}) ..."
	sleep 1
	waited=$((waited + 1))
done
printf '%s\n%s\n' "$$" "$ROOT" > "$LOCK/owner"
trap 'rm -rf "$LOCK"' EXIT INT TERM

"$GODOT" --path "$ROOT" --script res://tools/profile_frame.gd
