#!/usr/bin/env bash
# One-command harness: runs EVERY verification layer and exits non-zero if ANY fails.
# The whole safety net behind autonomous sprints, in one invocation:
#   tools/run_harness.sh
# Override the engine path with GODOT=/path/to/Godot if it isn't the default macOS bundle.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pass=0
fail=0
failed_names=()
log="$(mktemp)"

run() {  # <name> <script>
	local name="$1" script="$2"
	printf '  %-32s ' "$name"
	if "$GODOT" --headless --path . --script "$script" >"$log" 2>&1; then
		echo "PASS"
		pass=$((pass + 1))
	else
		echo "FAIL"
		fail=$((fail + 1))
		failed_names+=("$name")
		sed 's/^/      | /' "$log" | tail -14
	fi
}

echo "== Sinkforge harness =="
run "sim (determinism/conservation)" "res://tests/run_tests.gd"
run "measure_player (motion feel)"   "res://tools/measure_player.gd"
run "check_step"                     "res://tools/check_step.gd"
run "check_stepup"                   "res://tools/check_stepup.gd"
run "check_walk"                     "res://tools/check_walk.gd"
run "check_lift"                     "res://tools/check_lift.gd"
run "check_fastforward"              "res://tools/check_fastforward.gd"
run "check_mining"                   "res://tools/check_mining.gd"
run "check_fall"                     "res://tools/check_fall.gd"
run "check_climb"                    "res://tools/check_climb.gd"
run "check_saveload"                 "res://tools/check_saveload.gd"
run "check_settings"                 "res://tools/check_settings.gd"
run "check_controls"                 "res://tools/check_controls.gd"
run "check_pack_layout"              "res://tools/check_pack_layout.gd"
run "check_pixel_snap"               "res://tools/check_pixel_snap.gd"
run "check_agility (movement score)" "res://tools/check_agility.gd"
run "play-tests (scripted + friction)" "res://tools/play_tests.gd"

rm -f "$log"
echo
if [ "$fail" -eq 0 ]; then
	echo "ALL $pass HARNESS LAYERS PASS"
	exit 0
else
	echo "$fail LAYER(S) FAILED: ${failed_names[*]}"
	exit 1
fi
