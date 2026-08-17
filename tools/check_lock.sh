#!/usr/bin/env bash
# THE LOCK ITSELF, HELD TO THE FOUR THINGS EVERYTHING ELSE ASSUMES OF IT.
#
#   bash tools/check_lock.sh
#
# `with_machine.sh` is the reason parallel runs can share one machine, and until now nothing tested it. That
# is a bad place for an untested tool, but it is not the reason this file exists. The reason is that one of
# its paths — GIVE UP — is a run that never happened, and a run that never happened is the single most
# dangerous thing a test harness can report, because the shape it reports it in is silence. A backgrounded
# call came back "completed (exit code 0)" after waiting fifteen minutes and never booting Godot, and the
# only thing standing between that and a false green was a human reading the log text.
#
# Needs no Godot and no display: a stub stands in for the engine so the exit codes are ours to choose. Runs
# in about five seconds.
#
#   GIVE UP IS NOT SUCCESS.  A lock that never frees ends the run with 5 and says so in words, on stdout,
#                            where a log skim will find it even if the exit code has been thrown away.
#   STALE LOCKS CLEAR.       A holder that was killed cannot release its own lock. If a dead pid wedged the
#                            lock, one crashed run would cost every future run on the box.
#   THE INNER CODE SURVIVES.  The harness protocol is three-state — 0 pass, 1 fail, 42 skip — and all three
#                            travel through the wrapper. A wrapper that flattened 42 to 0 would turn every
#                            skipped layer into a passing one.
#   ONE AT A TIME.           The whole point. Two runs racing for the lock must not overlap.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so the guards can be proven against a MUTATED COPY rather than by editing the tool the rest
# of the machine is currently relying on. A guard nobody has watched go red is a guess.
WITH="${SF_WITH:-$ROOT/tools/with_machine.sh}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOCK="$TMP/lock"
fails=0

# A stand-in for Godot. `with_machine` always injects `--path <root>`, so drop those two and run the rest —
# which lets a case below choose its own exit code and its own timing.
cat > "$TMP/fake_godot" <<'EOF'
#!/bin/sh
shift 2
exec "$@"
EOF
chmod +x "$TMP/fake_godot"
run() { SF_LOCK="$LOCK" GODOT="$TMP/fake_godot" bash "$WITH" "$@"; }

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

echo "== the lock is the reason parallel runs can share one machine =="

# --- GIVE UP IS NOT SUCCESS ---
rm -rf "$LOCK"; mkdir -p "$LOCK"
sleep 30 & holder=$!
disown "$holder" 2>/dev/null
printf '%s\n/elsewhere\n' "$holder" > "$LOCK/owner"
out="$(SF_LOCK="$LOCK" SF_LOCK_WAIT=2 GODOT="$TMP/fake_godot" bash "$WITH" /bin/sh -c 'exit 0' 2>/dev/null)"
code=$?
kill "$holder" 2>/dev/null
[ "$code" -eq 5 ]; check $? "a lock that never frees ends the run with 5, not 0 (got $code)"
# ...and says so where a reader will see it. The exit code is the half that gets discarded — by a
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
SF_LOCK="$LOCK" SF_LOCK_WAIT=3 GODOT="$TMP/fake_godot" bash "$WITH" /bin/sh -c 'exit 0' >/dev/null 2>&1
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

# --- ONE AT A TIME ---
# Two runs race; each stamps the log on the way in and on the way out. If the lock works the stamps are
# strictly paired — in/out/in/out. An overlap shows up as two INs in a row, which is exactly the eight
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
# died on startup — both of which would leave the pairing trivially intact.
[ "$(grep -c . "$log")" -eq 4 ]; check $? "...and both runs actually ran (4 stamps)"

echo
if [ "$fails" -eq 0 ]; then
	echo "check_lock: PASS — the machine lock holds, and giving up is not a pass"
	exit 0
fi
echo "check_lock: FAIL ($fails)" >&2
exit 1
