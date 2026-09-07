#!/usr/bin/env bash
# Boot one playtest seat at foreground priority (D0452).
#
#     bash playtest/seat.sh <absolute session dir> [path-to-godot]
#
# A seat started with `nohup godot ... &` from an agent's shell inherits BACKGROUND quality of service
# (`ps -o nice` reads 5, state `SN`): the moment the director's own foreground app is busy, the seat is
# starved and its frame sleep stretches from milliseconds to seconds -- strangers 28-30 fell to half a tick
# a second for two minutes and their agents' commands timed out. LaunchServices (`open -n -a`) starts the
# same binary at nice 0. The window stays always-on-top at the screen's corner, vsync off, the engine's
# log in the session directory. The seat itself caps its frame rate (idle CPU 2.5%, not 50-70%).
set -euo pipefail
DIR="${1:?session dir}"
GODOT="${2:-${GODOT:-/opt/homebrew/bin/godot}}"
SEED_ARG=""
[ -n "${SEED:-}" ] && SEED_ARG="--seed=$SEED"      # SEED=<n> boots another world (the holdout, D0460)
case "$DIR" in /*) ;; *) echo "seat.sh: the session dir must be absolute" >&2; exit 2 ;; esac
mkdir -p "$DIR"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
open -n -a "$GODOT" --args --path "$ROOT" --resolution 1280x720 --disable-vsync --position 0,0 --always-on-top \
	--log-file "$DIR/seat.out" --script res://playtest/seat.gd -- "--session-dir=$DIR" --launcher=launchservices $SEED_ARG
for _ in $(seq 1 60); do
	[ -f "$DIR/frame_0000.png" ] && exit 0
	sleep 1
done
echo "seat.sh: no first frame after 60 s; read $DIR/seat.out" >&2
exit 1
