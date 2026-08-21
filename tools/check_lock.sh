#!/usr/bin/env bash
# THE LOCK ITSELF, HELD TO THE FOUR THINGS EVERYTHING ELSE ASSUMES OF IT.
#
#   bash tools/check_lock.sh
#
# `with_machine.sh` is the reason two runs can share one machine, and until now nothing tested it. That
# is a bad place for an untested tool, but it is not the reason this file exists. The reason is that one of
# its paths, GIVE UP, is a run that never happened, and a run that never happened is the single most
# dangerous thing a test harness can report, because the shape it reports it in is silence. A backgrounded
# call came back "completed (exit code 0)" after waiting fifteen minutes and never booting Godot, and the
# only thing standing between that and a false green was a human reading the log text.
#
# Needs no Godot and no display: a stub stands in for the engine so the exit codes can be chosen here. Runs
# in about five seconds.
#
#   GIVE UP IS NOT SUCCESS.  A lock that never frees ends the run with 5 and says so in words, on stdout,
#                            where a log skim will find it even if the exit code has been thrown away.
#   STALE LOCKS CLEAR.       A holder that was killed cannot release its own lock. If a dead pid wedged the
#                            lock, one crashed run would cost every future run on the box.
#   THE INNER CODE SURVIVES.  The harness protocol is three-state: 0 pass, 1 fail, 42 skip. And all three
#                            travel through the wrapper. A wrapper that flattened 42 to 0 would turn every
#                            skipped layer into a passing one.
#   ONE AT A TIME.           The whole point. Two runs racing for the lock must not overlap.
#   A HANG IS NOT A RUN.     A fixture that errors before its `quit()` idles forever holding the lock. The
#                            holder is alive and healthy, so no check above can see it; a wall-clock cap
#                            kills it and exits 6.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so the guards can be proven against a MUTATED COPY rather than by editing the tool the rest
# of the machine is currently relying on. A guard nobody has watched go red is a guess.
WITH="${SF_WITH:-$ROOT/tools/with_machine.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOCK="$TMP/lock"
fails=0

# A stand-in for Godot. `with_machine` always injects `--path <root>`, so drop those two and run the rest;
# which lets a case below choose its own exit code and its own timing.
cat > "$TMP/fake_godot" <<'EOF'
#!/bin/sh
shift 2
exec "$@"
EOF
chmod +x "$TMP/fake_godot"
# SF_ALLOW_POSITIONAL, because the cases below drive a STUB and not Godot, so their first argument is a
# path (`/bin/sh`) rather than a Godot flag. The refusal that flag disables gets its own case at the end,
# tested WITHOUT the escape hatch; otherwise this file would be the one place the guard never fires.
run() { SF_LOCK="$LOCK" SF_ALLOW_POSITIONAL=1 GODOT="$TMP/fake_godot" bash "$WITH" "$@"; }

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

echo "== the lock is the reason two runs can share one machine =="

# --- GIVE UP IS NOT SUCCESS ---
rm -rf "$LOCK"; mkdir -p "$LOCK"
sleep 30 & holder=$!
disown "$holder" 2>/dev/null
printf '%s\n/elsewhere\n' "$holder" > "$LOCK/owner"
out="$(SF_LOCK="$LOCK" SF_LOCK_WAIT=2 SF_ALLOW_POSITIONAL=1 GODOT="$TMP/fake_godot" bash "$WITH" /bin/sh -c 'exit 0' 2>/dev/null)"
code=$?
kill "$holder" 2>/dev/null
[ "$code" -eq 5 ]; check $? "a lock that never frees ends the run with 5, not 0 (got $code)"
# ...and says so where a reader will see it. The exit code is the half that gets discarded: by a
# background runner, by a trailing `; echo done`, by a pipeline. The words are the half that survives.
case "$out" in *"NOTHING RAN"*) r=0 ;; *) r=1 ;; esac
check $r "...and says NOTHING RAN on stdout, for every caller that drops the code"

# --- STALE LOCKS CLEAR ---
# A pid that is certainly gone: start something and reap it. Reusing a live pid here would test the wait
# path instead, and pass for the wrong reason.
rm -rf "$LOCK"; mkdir -p "$LOCK"
sleep 0 & dead=$!
wait "$dead" 2>/dev/null
printf '%s\n/elsewhere\n' "$dead" > "$LOCK/owner"
SF_LOCK="$LOCK" SF_LOCK_WAIT=3 SF_ALLOW_POSITIONAL=1 GODOT="$TMP/fake_godot" bash "$WITH" /bin/sh -c 'exit 0' >/dev/null 2>&1
[ $? -eq 0 ]; check $? "a lock left behind by a killed run is cleared, not waited on"

# --- THE INNER CODE SURVIVES ---
for want in 0 1 42; do
	rm -rf "$LOCK"
	run /bin/sh -c "exit $want" >/dev/null 2>&1
	got=$?
	[ "$got" -eq "$want" ]; check $? "exit $want travels through the wrapper unchanged (got $got)"
done

# --- and the lock is RELEASED on the way out, including on failure ---
rm -rf "$LOCK"
run /bin/sh -c 'exit 1' >/dev/null 2>&1
[ ! -d "$LOCK" ]; check $? "the lock is released even when the run inside it failed"

# --- RELEASE ONLY WHAT YOU STILL OWN ---
# The sixth property, and the five above are all blind to it, because every one of them runs a single
# holder. This one needs two, and it is the failure that turns a serialised box back into a parallel one.
#
# `LOCK_HELD=1` used to be the whole release condition. It records that a run ACQUIRED the lock once; it
# does not record that the run still holds it, and the stale sweep pulls those apart on purpose:
#
#   A is killed hard, so its trap never runs and its lock directory outlives it.
#   B waits, sees A's pid is gone, clears the lock as stale, and takes it. The directory is B's now.
#   A's trap fires late -- a slow SIGTERM, a reaped subshell -- and deletes the directory. It is B's.
#   C finds no lock, takes it, and boots Godot alongside B's still-running Godot.
#
# ONE hard kill is enough to make every honest release after it delete a stranger's lock. Worse, nothing
# reports it: both runs exit 0, both look healthy, and the only trace is that every duration either of
# them measured was measured next to the other. Silent, and corrupting rather than failing.
#
# Staged directly: start a run, retitle the lock under it to a different LIVE pid, and see whether it
# takes something that is not its own on the way out. The paired case above ("released even when the run
# inside it failed") is what stops this being satisfied by a wrapper that never releases anything.
rm -rf "$LOCK"
started="$TMP/started"; : > "$started"
run /bin/sh -c "echo up > '$started'; sleep 3" >/dev/null 2>&1 &
a=$!
waited=0
while [ ! -s "$started" ] && [ "$waited" -lt 40 ]; do sleep 0.25; waited=$((waited + 1)); done
[ -s "$started" ]; check $? "(setup) the holder started and took the lock"
# A different owner, and a LIVE one: a dead pid would be cleared by the stale sweep and prove nothing.
sleep 30 >/dev/null 2>&1 & other=$!
printf '%s\n%s\n%s\n%s\n' "$other" "/elsewhere" "another run" "0" > "$LOCK/owner"
wait "$a"
[ -d "$LOCK" ] && [ "$(sed -n 1p "$LOCK/owner" 2>/dev/null)" = "$other" ]
check $? "a run that no longer owns the lock leaves it alone on the way out (owner $other)"
kill "$other" 2>/dev/null; wait "$other" 2>/dev/null
rm -rf "$LOCK"

# --- A STALE LOCK IS NOT SWEPT BY A WAITER THAT DECIDED EARLIER ---
# The seventh property, and the second one that needs two runs. STALE LOCKS CLEAR (above) proves a dead
# holder does not wedge the box forever. This proves the cure is not worse than the disease.
#
# Sweeping is a removal of shared state, and the decision to sweep is not the removal. A waiter reads a
# dead owner, and by the time it is scheduled again somebody else has cleared the same lock and taken the
# machine. Its `rm` then lands on a LIVE holder's directory and it walks straight in beside them.
#
# In the wild the gap is microseconds, which is why a symmetric staging of this never reproduced: run two
# waiters at once and they sweep together, harmlessly. It needs one waiter to act LATE. So one is made
# late here, deliberately, by pausing it inside the sweep -- and then the fix has to be correct by
# construction rather than by timing, which is the property worth having.
DELAYED="$TMP/with_machine_delayed.sh"
# The pause goes between the caller DECIDING the holder is dead and the sweep ACTING on it, which is the
# gap the defect lives in. The copy also needs the protocol library beside it, because the wrapper sources
# that relative to its own location.
cp "$ROOT/tools/lock_lib.sh" "$TMP/lock_lib.sh"
awk '{print} /kill -0 "\$holder"/ {print "\t\tsleep \"${SF_TEST_SWEEP_DELAY:-0}\""}' \
	"$WITH" > "$DELAYED"
# THE SETUP IS ASSERTED, because if the anchor ever drifts the copy is simply identical to the original,
# both waiters sweep at once, and this case goes green while testing nothing at all.
[ "$(grep -c 'SF_TEST_SWEEP_DELAY' "$DELAYED")" -eq 1 ]
check $? "(setup) the delayed copy carries the sweep pause, so this case is not vacuous"

rm -rf "$LOCK"; mkdir -p "$LOCK"
# An owner that is certainly dead: start something and reap it.
sh -c 'exit 0' & dead=$!; wait "$dead" 2>/dev/null
printf '%s\n%s\n%s\n%s\n' "$dead" "/gone" "a killed run" "0" > "$LOCK/owner"
log="$TMP/sweeporder"; : > "$log"
# A sweeps at once and then holds the box for three seconds.
run /bin/sh -c "echo inA >> '$log'; sleep 3; echo outA >> '$log'" >/dev/null 2>&1 &
# B makes the same decision and acts on it a second later, by which time the lock is A's.
SF_LOCK="$LOCK" SF_ALLOW_POSITIONAL=1 GODOT="$TMP/fake_godot" SF_TEST_SWEEP_DELAY=1 \
	bash "$DELAYED" /bin/sh -c "echo inB >> '$log'; sleep 1; echo outB >> '$log'" >/dev/null 2>&1 &
wait
got="$(tr '\n' ' ' < "$log")"
case "$got" in "inA outA inB outB "|"inB outB inA outA ") r=0 ;; *) r=1 ;; esac
check $r "a late sweeper does not clear a lock somebody else now holds (saw: $got)"
# NON-VACUITY: four stamps means both runs really happened. A waiter that died on startup, or one that
# gave up at SF_LOCK_WAIT, would leave the ordering trivially intact and prove nothing.
[ "$(grep -c . "$log")" -eq 4 ]; check $? "...and both runs actually ran (4 stamps)"
rm -rf "$LOCK" "$LOCK.gc"

# --- ONE AT A TIME ---
# Two runs race; each stamps the log on the way in and on the way out. If the lock works the stamps are
# strictly paired: in/out/in/out. An overlap shows up as two INs in a row, which is exactly the eight
# concurrent Godot processes this tool exists to prevent.
rm -rf "$LOCK"
log="$TMP/order"; : > "$log"
run /bin/sh -c "echo in >> '$log'; sleep 1; echo out >> '$log'" >/dev/null 2>&1 &
a=$!
run /bin/sh -c "echo in >> '$log'; sleep 1; echo out >> '$log'" >/dev/null 2>&1 &
b=$!
wait "$a"; wait "$b"
got="$(tr '\n' ' ' < "$log")"
[ "$got" = "in out in out " ]; check $? "two runs racing for the machine never overlap (saw: $got)"
# NON-VACUITY: the assertion above is satisfied by a log that was never written to, and by one run that
# died on startup; both of which would leave the pairing trivially intact.
[ "$(grep -c . "$log")" -eq 4 ]; check $? "...and both runs actually ran (4 stamps)"

# --- A COMMAND IS NOT AN ARGUMENT LIST ---
# The real incident, kept as a case. `with_machine.sh bash tools/run_harness.sh` reads like a runner taking
# a command and becomes `godot --path <repo> bash tools/run_harness.sh`: Godot ignores the positionals,
# boots the project and plays the game. It ran for 39 minutes, no layer executed, and the task notification
# said "completed (exit code 0)". Elapsed time and CPU looked healthy throughout, because a game genuinely
# was running. Only the argv would have shown it.
rm -rf "$LOCK"
out="$(SF_LOCK="$LOCK" GODOT="$TMP/fake_godot" bash "$WITH" bash tools/run_harness.sh 2>/dev/null)"
code=$?
[ "$code" -eq 2 ]; check $? "a shell command where Godot flags belong is REFUSED (exit 2, got $code)"
case "$out" in *"NOTHING RAN"*) r=0 ;; *) r=1 ;; esac
check $r "...and says NOTHING RAN, on stdout, before taking the lock"
[ ! -d "$LOCK" ]; check $? "...and a refused call never took the lock at all"

# --- A HANG IS NOT A RUN ---
# The fifth property, and the newest. A scratch fixture put its work in `_init()` rather than
# `_initialize()`; `_init` is the Object constructor, so the error there aborted the function before it
# ever reached `quit(0)`, and the SceneTree then came up normally and idled forever, holding this lock.
#
#   A FIXTURE THAT DIES BEFORE ITS `quit()` DOES NOT FAIL. IT HANGS.
#
# None of the four properties above can see that. GIVE UP guards the waiter, not the holder. STALE LOCKS
# CLEAR reads `kill -0` on the holder's pid and that pid is alive. THE INNER CODE SURVIVES needs an inner
# code, and there is never going to be one. The holder is healthy; it is simply never going to stop, and
# another run queued behind it for eight minutes at 0.6% CPU with 94% of samples in the frame delay.
runcap() { _c="$1"; shift; SF_LOCK="$LOCK" SF_ALLOW_POSITIONAL=1 GODOT="$TMP/fake_godot" SF_RUN_CAP="$_c" bash "$WITH" "$@"; }

rm -rf "$LOCK"
pidf="$TMP/hangpid"; : > "$pidf"
out="$(runcap 3 /bin/sh -c "echo \$\$ > '$pidf'; while :; do sleep 1; done" 2>/dev/null)"
code=$?
[ "$code" -eq 6 ]; check $? "a fixture that hangs forever is KILLED by the cap (exit 6, got $code)"
case "$out" in *"CAPPED"*) r=0 ;; *) r=1 ;; esac
check $r "...and says CAPPED on stdout, for every caller that drops the code"
[ ! -d "$LOCK" ]; check $? "...and the lock is released, which is the whole point"
# NON-VACUITY, and the assertion that actually matters to the next run: exiting 6 while leaving the
# process alive would free the lock and keep the box. The stub records its own pid so this can be checked
# rather than assumed.
hp="$(cat "$pidf" 2>/dev/null)"
[ -n "$hp" ] && ! kill -0 "$hp" 2>/dev/null; check $? "...and the hung process is GONE, not merely disowned (pid $hp)"

# THE OTHER HALF, without which the cap would be free to fire on everything: a run that finishes inside its
# cap must be untouched. A watchdog that cannot tell work from a hang is worse than no watchdog, because it
# turns a slow honest layer into a red one.
rm -rf "$LOCK"
runcap 30 /bin/sh -c "sleep 2" >/dev/null 2>&1
code=$?
[ "$code" -eq 0 ]; check $? "a run that finishes inside its cap is untouched (exit 0, got $code)"
rm -rf "$LOCK"
runcap 0 /bin/sh -c "sleep 2; exit 42" >/dev/null 2>&1
code=$?
[ "$code" -eq 42 ]; check $? "SF_RUN_CAP=0 disables the cap and the inner code still survives (got $code)"

# --- THE PROTOCOL HAS ONE COPY ---
# The eighth property, and it is structural rather than behavioural: it does not test what the lock DOES,
# it tests that there is only one thing doing it.
#
# Every property above drives `with_machine.sh`. `run_harness.sh` and `seed_corpus.sh` take the same lock
# and share none of the wrapper's command-line contract, so pointing this file at them would establish that
# they can be invoked rather than that their locking is sound. For a long time the answer to "are the other
# two correct?" was that they held byte-identical copies — which is a snapshot, not an invariant, and the
# only thing keeping them equal was somebody remembering. Two safety defects were fixed by hand in three
# files each; the third hand-fix is where copies diverge. They already had: `seed_corpus.sh` wrote a
# two-line owner file where the others wrote four, so the waiter was told a run was in progress and never
# told what it was.
#
# So the protocol lives in `tools/lock_lib.sh` and this asserts that it still lives ONLY there. A future
# copy-paste is caught here rather than by the next person to lose a measurement to two engines.
lib_users=0
lib_dupes=""
for f in tools/with_machine.sh tools/run_harness.sh tools/seed_corpus.sh; do
	grep -q 'lock_lib\.sh' "$ROOT/$f" && lib_users=$((lib_users + 1))
	for fn in lock_claim_write lock_claim lock_release lock_steal; do
		grep -qE "^${fn}\(\)" "$ROOT/$f" && lib_dupes="$lib_dupes $f:$fn"
	done
done
[ "$lib_users" -eq 3 ]; check $? "all three lock takers source the shared protocol ($lib_users of 3)"
[ -z "$lib_dupes" ]; check $? "and none of them redefines it locally${lib_dupes:+ —$lib_dupes}"
# NON-VACUITY: the assertions above are satisfied by a repository where those files do not exist, and by a
# grep that silently matched nothing. The library must actually be there and actually define the protocol.
lib_defs=0
for fn in lock_claim_write lock_claim lock_release lock_steal; do
	grep -qE "^${fn}\(\)" "$ROOT/tools/lock_lib.sh" && lib_defs=$((lib_defs + 1))
done
[ "$lib_defs" -eq 4 ]; check $? "...and the shared protocol defines all four entry points ($lib_defs of 4)"

echo
if [ "$fails" -eq 0 ]; then
	echo "check_lock: PASS — the machine lock holds, and giving up is not a pass"
	exit 0
fi
echo "check_lock: FAIL ($fails)" >&2
exit 1
