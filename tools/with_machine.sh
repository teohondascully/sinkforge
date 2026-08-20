#!/usr/bin/env bash
# RUN SOMETHING THAT BOOTS GODOT, HOLDING THE MACHINE-WIDE LOCK.
#
#   GODOT=/opt/homebrew/bin/godot bash tools/with_machine.sh --script res://tools/check_frametime.gd
#   GODOT=/opt/homebrew/bin/godot bash tools/with_machine.sh --script res://tools/capture_moments.gd -- delve
#
# Everything after the script name is passed to Godot; `--path <repo>` is supplied.
#
# WHY THIS EXISTS, stated plainly because I am the reason. `run_harness.sh` takes this lock and
# `profile.sh` takes this lock, and I still put eight concurrent Godot processes on this box three
# separate times — because a single layer run, or a capture, is `godot --script ...` typed straight
# into a shell, and that path never touched a lock at all. I fixed the profiler and thought the hole was
# closed; the hole was every OTHER ad-hoc invocation, which is most of them.
#
# The rule that survives is about tools and not about people: ANYTHING THAT BOOTS GODOT TAKES THE LOCK.
# A protocol that depends on remembering to check is not a protocol, and this is the third piece of
# evidence for that in one day. Run one-off scripts through here.
#
# Exit 5 = gave up waiting; exit 6 = killed by the wall-clock cap (see CAP below). Otherwise Godot's
# own exit code is passed through, so `SKIP_CODE=42` and the
# harness's three-state protocol survive the wrapper.

set -uo pipefail
GODOT="${GODOT:-godot}"
LOCK="${SF_LOCK:-${TMPDIR:-/tmp}/sinkforge-harness.lock}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# How long to wait before giving up, overridable so the GIVE-UP PATH IS TESTABLE. It was not: proving that
# a timeout exits 5 rather than 0 meant holding the lock for fifteen minutes, so nobody ever proved it, and
# the one path in this script that must never be mistaken for success was the one path never exercised.
WAIT="${SF_LOCK_WAIT:-900}"

# Same isolated `user://` the harness uses, by the same key, so a one-off probe and a full sweep land in
# one namespace and neither lands in the player's. Reasoning and the two mechanisms that DON'T work are
# written out once, at the top of run_harness.sh; this must stay in step with it. `SF_REAL_HOME=1` opts
# back into the real home for the rare tool that genuinely wants the player's slot.
sf_hash() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; }
if [ "${SF_REAL_HOME:-0}" != "1" ]; then
	SF_HOME="${SF_HOME:-${TMPDIR:-/tmp}/sinkforge-home-$(printf '%s' "$ROOT" | sf_hash | cut -c1-12)}"
	# IT FAILS CLOSED, AND IT USED TO FAIL OPEN — SILENTLY, INTO THE PLAYER'S REAL SAVE SLOT. This was
	# `if mkdir -p ...; then export HOME=...; fi`. If the mkdir failed for any reason — a full disk, a
	# stale root-owned $TMPDIR entry, a sandbox that will not let us write there — the exports simply did
	# not happen, `HOME` stayed the real one, and Godot booted against
	# `~/Library/Application Support/Godot/app_userdata/Sinkforge/sinkforge.save`. No message, no
	# non-zero status, no sentinel on this path to witness it: the one failure mode this whole mechanism
	# exists to prevent, reached by the mechanism failing rather than by anyone making a mistake.
	# `run_harness.sh:131-132` has always failed CLOSED here (`|| exit 2`); the two drifted, and the
	# comment above promising "the same isolated user:// the harness uses, by the same key" was true of
	# the happy path and false of every other. Found by the blind-evaluation readiness audit, gate 1.
	mkdir -p "$SF_HOME/.local/share" "$SF_HOME/.config" \
		|| { echo "!! could not create the isolated home at $SF_HOME — REFUSING to boot Godot against the" \
			"player's real save slot. Fix the path or set SF_REAL_HOME=1 if you genuinely mean it." >&2; exit 2; }
	export HOME="$SF_HOME"
	export XDG_DATA_HOME="$SF_HOME/.local/share"
	export XDG_CONFIG_HOME="$SF_HOME/.config"
	# THE POSITIVE MARKER a fixture checks before it writes to `user://`. The isolation above protects only
	# invocations that come through a wrapper, so a bare `godot --script res://tests/test_worldgen.gd`
	# inherits the real HOME and writes into the player's Godot directory — which is not hypothetical:
	# `test_fine_terrain.save` is sitting in it, 847K, from a bare run. Announcing isolation rather than
	# asking a fixture to RECOGNISE the dangerous state, because a guard that must recognise danger is
	# wrong for every state nobody thought of. Absence of this marker is the refusal condition.
	export SF_ISOLATED_HOME="$SF_HOME"
fi

# THESE ARE GODOT ARGUMENTS, NOT A COMMAND, and the difference cost 39 minutes of machine time.
# `bash tools/with_machine.sh bash tools/run_harness.sh` reads like a runner taking a command; it
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

# --- THE CLAIM FILE. The lock used to say a pid and a tree, and the waiter printed only the pid, so
# "waiting for the machine lock (held by pid 65489)" required a `ps` on another terminal to find out what
# was running and whether it was nearly done. A lock that makes you go and look is a lock that gets
# overridden. Four lines now: pid, tree, what is running, and when it started — so the message answers the
# three questions a waiting run actually has.
#
# APPEND-ONLY BY DESIGN. Line 1 stays the pid and line 2 stays the tree, because the stale-holder check is
# `head -1` and both scripts already read those; a lock written by an older copy of either script is
# missing lines 3 and 4 and the reader falls back rather than failing. Two checkouts do not upgrade at the
# same instant.
lock_claim_write() {
	printf '%s\n%s\n%s\n%s\n' "$$" "$ROOT" "${1:-?}" "$(date +%s)" > "$LOCK/owner"
}

# One line describing the current holder: pid, what it is running, which tree, how long. Every field is
# optional — a missing one is simply left out rather than printed as a question mark next to real data.
lock_claim() {
	_p="$(sed -n 1p "$LOCK/owner" 2>/dev/null)"
	_t="$(sed -n 2p "$LOCK/owner" 2>/dev/null)"
	_w="$(sed -n 3p "$LOCK/owner" 2>/dev/null)"
	_s="$(sed -n 4p "$LOCK/owner" 2>/dev/null)"
	_msg="held by pid ${_p:-?}"
	[ -n "$_w" ] && _msg="$_msg running ${_w}"
	[ -n "$_t" ] && _msg="$_msg in $(basename "$_t")"
	if [ -n "$_s" ]; then
		_e=$(( $(date +%s) - _s ))
		[ "$_e" -ge 0 ] && _msg="$_msg for ${_e}s"
	fi
	printf '%s' "$_msg"
}

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
		echo "with_machine: GAVE UP after ${waited}s waiting for the lock — $(lock_claim)" >&2
		echo "with_machine: NOTHING RAN — this is not a pass (exit 5)" >&2
		echo "with_machine: GAVE UP — NOTHING RAN. Not a pass."
		exit 5
	fi
	[ $((waited % 30)) -eq 0 ] && echo "  waiting for the machine lock — $(lock_claim)" >&2
	sleep 1
	waited=$((waited + 1))
done
# The claim reads better as "running check_walk.gd" than as the whole argv, and the script is the only part
# of it a waiting run cares about. Falls back to the full arguments when there is no --script, because a
# claim that cannot name what it is doing should say everything rather than nothing.
_claim="$*"
_prev=""
for _a in "$@"; do
	if [ "$_prev" = "--script" ]; then _claim="$(basename "$_a")"; break; fi
	_prev="$_a"
done
lock_claim_write "$_claim"
# THE WALL-CLOCK CAP, and the failure that bought it. A scratch fixture of mine put its work in `_init()`
# instead of `_initialize()`. `_init` is the Object CONSTRUCTOR: it runs before the tree is up, the error
# there aborted the function before it ever reached `quit(0)`, and the SceneTree then came up normally and
# idled — forever, holding this lock, at 0.6% CPU with 94% of samples parked in `OS::add_frame_delay`.
#
#   A FIXTURE THAT DIES BEFORE ITS `quit()` DOES NOT FAIL. IT HANGS, HOLDING THE LOCK.
#
# Nothing above catches that. The stale-lock sweep clears a holder whose PID is GONE; this holder's PID is
# very much alive, and a health check calls it healthy because it IS healthy. It is just never going to
# stop. The next run queued behind it for eight minutes and the only thing that eventually freed the
# box was a timeout in my terminal client — which is to say, nothing the harness owns.
#
# The alternative fix was a rule ("scratch scripts get `_initialize()` and a `quit()` on every path"). That
# only works on the days you remember, and this is the third lock hazard closed here that a rule was
# already supposed to prevent. So the cap goes in the tool, where it binds without being remembered.
#
# Deliberately GENEROUS rather than tight. The job is to turn "forever" into "bounded", not to police how
# long a fixture may legitimately take, so the default would not have interrupted any real run in this
# repo's history. `SF_RUN_CAP=0` disables it for a run that genuinely needs longer.
CAP="${SF_RUN_CAP:-1800}"
CAPMARK="$(mktemp "${TMPDIR:-/tmp}/sinkforge-cap.XXXXXX")"

# WHERE THE WINDOW LANDS, because the box has an owner and they are using it. Layers that photograph the
# renderer need a real surface, so they open a real window — which on macOS arrives wherever the OS feels
# like putting it, frequently on top of whatever the human is doing. `SF_WINDOW_POS=X,Y` parks it.
#
# THIS FIXES THE ANNOYANCE AND NOT THE TELEMETRY, and the difference matters. A passive probe measured the
# pointer moving in 11 of 40 samples with the game window NOT FOCUSED — the game reads the OS pointer
# through `get_global_mouse_position()` regardless of focus, so a window parked in a corner is still
# reading the user's hand. Moving the window stops us covering their work; `tools/fixture_pointer.gd` is
# what stops their work corrupting our numbers. Both are needed and neither substitutes for the other.
#
# Deliberately UNSET by default: the right corner depends on a screen layout this script cannot see, and a
# guessed default that lands a window half off a laptop display would be worse than the status quo.
# TWO BRANCHES AND NOT AN ARRAY. The first version built `POSARG=()` and expanded `"${POSARG[@]}"`, which
# on macOS's bash 3.2 under `set -u` is an UNBOUND VARIABLE ERROR when the array is empty -- so every run
# through this wrapper aborted and returned 1. check_lock caught it immediately ("exit 0 travels through
# the wrapper unchanged (got 1)"), which is precisely the property it was written to hold.
if [ -n "${SF_WINDOW_POS:-}" ]; then
	"$GODOT" --path "$ROOT" --position "$SF_WINDOW_POS" "$@" &
else
	"$GODOT" --path "$ROOT" "$@" &
fi
_child=$!
# The child joins the trap: a SIGTERM to the wrapper must not leave an orphaned Godot holding the box after
# the lock directory it was blocking on has already been removed.
trap 'rm -rf "$LOCK"; kill "$_child" 2>/dev/null; rm -f "$CAPMARK"' EXIT INT TERM

_dog=""
if [ "$CAP" -gt 0 ]; then
	# POLLED IN ONE-SECOND STEPS, AND NOT `sleep "$CAP"`, because the obvious version of this watchdog
	# caused the exact failure the cap exists to prevent. `kill "$_dog"` below kills the SUBSHELL; the
	# `sleep` it is blocked in is a separate process, so it survives, gets reparented to init, and runs
	# out the rest of the cap. That orphan inherited the wrapper's stdout, which means it held the write
	# end of the caller's pipe: `bash tools/with_machine.sh ... | tail` printed nothing and returned
	# nothing for CAP seconds AFTER Godot had already exited 0. A clean, fast, SUCCESSFUL run was
	# indistinguishable from a hang, and at the default cap it looked like a thirty-minute one.
	#
	# It cost four abandoned runs, each retry restarting the work and leaving another orphan behind;
	# seven were alive on the box when this was finally read. Measured rather than reasoned: with a
	# child that exits immediately, `SF_RUN_CAP=20` made the piped call take twenty seconds and
	# `SF_RUN_CAP=5` five, which is the cap dialling the hang it was supposed to bound.
	#
	# So the watchdog now ENDS ITSELF the moment the child is gone instead of waiting to be killed, and
	# the longest-lived orphan it can leave is one second. `>/dev/null` is the belt to that braces: this
	# subshell never holds the caller's stdout at all, whatever it happens to be blocked in.
	(
		_left="$CAP"
		while [ "$_left" -gt 0 ]; do
			kill -0 "$_child" 2>/dev/null || exit 0
			sleep 1
			_left=$((_left - 1))
		done
		if kill -0 "$_child" 2>/dev/null; then
			# Mark BEFORE killing, so the status below can tell a cap from a fixture that chose to die on
			# a signal. Without the mark both arrive as 143 and the cap would be invisible in the log.
			printf 'capped\n' > "$CAPMARK"
			echo "with_machine: CAP REACHED after ${CAP}s — killing $_claim (pid $_child)" >&2
			echo "with_machine: it was still alive but may not have been WORKING; a fixture that errors" >&2
			echo "with_machine: before its quit() idles here forever. Check for _init vs _initialize." >&2
			kill -TERM "$_child" 2>/dev/null
			sleep 5
			kill -KILL "$_child" 2>/dev/null
		fi
	) >/dev/null &
	_dog=$!
fi

wait "$_child"
status=$?
if [ -n "$_dog" ]; then
	kill "$_dog" 2>/dev/null
	wait "$_dog" 2>/dev/null
fi

if [ -s "$CAPMARK" ]; then
	rm -f "$CAPMARK"
	# LOUD, on stdout as well as stderr, and for the same reason exit 5 is: a capped run is a run that did
	# not finish, and the failure mode is not a misread exit code but that nothing downstream ever looks.
	echo "with_machine: KILLED BY THE ${CAP}s CAP — this is not a pass (exit 6)" >&2
	echo "with_machine: CAPPED — the run did not finish. Not a pass."
	exit 6
fi
rm -f "$CAPMARK"
exit "$status"
