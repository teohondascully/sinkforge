# TURNING "FOREVER" INTO "BOUNDED", IN ONE PLACE.
#
# A Godot fixture that errors before reaching its own `quit()` does not fail. The error aborts the
# function, the SceneTree comes up normally, and the process idles at 0.6% CPU holding whatever it was
# holding, looking healthy to `ps`, to elapsed time, and to every check written to notice a crash. One such
# run sat for thirty-nine minutes and its caller was told "completed (exit code 0)".
#
# WHY THIS IS A LIBRARY AND NOT A COPY. `with_machine.sh` grew this watchdog and `run_harness.sh` did not,
# so the runner's three calls to `save_sentinel.gd` -- the guard on the player's real save file, the one
# thing in the suite whose failure costs a person their data -- ran through a bare engine with no bound at
# all. Two of them run while the machine lock is HELD, so a hang there wedges the box for every later run
# as well. The runner cannot route them through `with_machine.sh` for exactly that reason: that script's
# first act is to take the lock the runner already holds. The bound has to be separable from the lock.
#
# THE WATCHDOG'S OWN HISTORY IS THE REASON IT IS COPIED NOWHERE. The obvious version, `sleep "$CAP"` in a
# subshell killed on completion, CAUSED the failure it was written to prevent: killing the subshell leaves
# its `sleep`, which is a separate process, which gets reparented and keeps the wrapper's stdout open. A
# fast successful run then returned nothing to a piped caller for the whole cap -- measured, with an
# instantly-exiting child, at exactly 20s under `SF_RUN_CAP=20` and 5s under `SF_RUN_CAP=5`. It cost four
# abandoned runs and left seven orphans on the box. So the loop polls in one-second steps and ENDS ITSELF
# when the child is gone, `>/dev/null` guarantees it never holds the caller's pipe, and this file exists so
# that reasoning lives once instead of being re-derived by whoever needs a cap next.
#
#   cap_watch <pid> <seconds> <label>   start the dog. 0 seconds means no cap. Sets CAP_DOG and CAP_MARK.
#   cap_done                            reap the dog after `wait`. Sets CAP_HIT=1 if the cap fired.
#
# `cap_done` must run after the caller has waited on the child, and CAP_HIT must be read before the next
# `cap_watch`. Both are reset by `cap_watch` so a second use in one process cannot inherit the first's
# verdict -- the runner arms, then verifies, then disarms, and a stale CAP_HIT would report the arm's
# outcome for the verify.

CAP_DOG=""
CAP_MARK=""
CAP_HIT=0

cap_watch() {
	_cw_pid="$1"
	_cw_secs="$2"
	_cw_label="${3:-a run}"
	CAP_DOG=""
	CAP_HIT=0
	CAP_MARK="$(mktemp "${TMPDIR:-/tmp}/sinkforge-cap.XXXXXX")"
	[ "$_cw_secs" -gt 0 ] || return 0
	(
		_left="$_cw_secs"
		while [ "$_left" -gt 0 ]; do
			kill -0 "$_cw_pid" 2>/dev/null || exit 0
			sleep 1
			_left=$((_left - 1))
		done
		if kill -0 "$_cw_pid" 2>/dev/null; then
			# MARK BEFORE KILLING, so the caller can tell a cap from a fixture that chose to die on a
			# signal. Without the mark both arrive as 143 and the cap is invisible in the log.
			printf 'capped\n' > "$CAP_MARK"
			echo "cap: REACHED after ${_cw_secs}s — killing $_cw_label (pid $_cw_pid)" >&2
			echo "cap: it was still alive but may not have been WORKING; a fixture that errors before" >&2
			echo "cap: its quit() idles here forever. Check for _init vs _initialize." >&2
			kill -TERM "$_cw_pid" 2>/dev/null
			sleep 5
			kill -KILL "$_cw_pid" 2>/dev/null
		fi
	) >/dev/null &
	CAP_DOG=$!
}

cap_done() {
	if [ -n "$CAP_DOG" ]; then
		kill "$CAP_DOG" 2>/dev/null
		wait "$CAP_DOG" 2>/dev/null
		CAP_DOG=""
	fi
	CAP_HIT=0
	if [ -n "$CAP_MARK" ] && [ -s "$CAP_MARK" ]; then
		CAP_HIT=1
	fi
	[ -n "$CAP_MARK" ] && rm -f "$CAP_MARK"
	CAP_MARK=""
	return 0
}
