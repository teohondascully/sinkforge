#!/usr/bin/env bash
# One-command harness: runs EVERY verification layer and exits non-zero if ANY fails.
# The whole safety net behind autonomous sprints, in one invocation:
#   tools/run_harness.sh
#
# PARALLEL by default: the 19 layers are independent Godot headless processes that
# write only uniquely-named user:// files (or none), so wall-clock is max(layers),
# not sum(layers). Concurrency is bounded to the CPU count.
#   JOBS=1   tools/run_harness.sh   # serialize (debug; old behavior)
#   JOBS=4   tools/run_harness.sh   # cap at 4 concurrent layers
#   GODOT=/path/to/Godot            # override the engine path
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Default concurrency = CPU count (bounds memory too); overridable via JOBS.
NCPU="$( (sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8) )"
JOBS="${JOBS:-$NCPU}"

# --- the layers, in declaration order (order is cosmetic; results stream as they finish) ---
NAMES=(); SCRIPTS=()
add() { NAMES+=("$1"); SCRIPTS+=("$2"); }
add "sim (determinism/conservation)"  "res://tests/run_tests.gd"
add "check_craftable_registry"        "res://tools/check_craftable_registry.gd"
add "measure_player (motion feel)"    "res://tools/measure_player.gd"
add "check_step"                      "res://tools/check_step.gd"
add "check_stepup"                    "res://tools/check_stepup.gd"
add "check_walk"                      "res://tools/check_walk.gd"
add "check_body_stress"               "res://tools/check_body_stress.gd"
add "check_water_move (L3 impedance)" "res://tools/check_water_move.gd"
add "check_lift"                      "res://tools/check_lift.gd"
add "check_fastforward"               "res://tools/check_fastforward.gd"
add "check_mining"                    "res://tools/check_mining.gd"
add "check_dig_hitch (friction)"      "res://tools/check_dig_hitch.gd"
add "check_fall"                      "res://tools/check_fall.gd"
add "check_climb"                     "res://tools/check_climb.gd"
add "check_saveload"                  "res://tools/check_saveload.gd"
add "check_settings"                  "res://tools/check_settings.gd"
add "check_water_audio (L3 sound)"    "res://tools/check_water_audio.gd"
add "check_controls"                  "res://tools/check_controls.gd"
add "check_pack_layout"               "res://tools/check_pack_layout.gd"
add "check_pixel_snap"                "res://tools/check_pixel_snap.gd"
add "check_agility (movement score)"  "res://tools/check_agility.gd"
add "check_loop_health (loop score)"  "res://tools/check_loop_health.gd"
add "play-tests (scripted + friction)" "res://tools/play_tests.gd"

total="${#NAMES[@]}"
[ "$JOBS" -gt "$total" ] && JOBS="$total"
[ "$JOBS" -lt 1 ] && JOBS=1

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

pass=0
fail=0
failed_names=()
REPORTED=()
launched=0
done_count=0
T0=$SECONDS

echo "== Sinkforge harness (parallel, JOBS=$JOBS, layers=$total) =="

while [ "$done_count" -lt "$total" ]; do
	# Fill free slots.
	while [ "$launched" -lt "$total" ] && [ "$((launched - done_count))" -lt "$JOBS" ]; do
		i="$launched"
		(
			s=$SECONDS
			if "$GODOT" --headless --path . --script "${SCRIPTS[$i]}" >"$DIR/$i.log" 2>&1; then r=0; else r=1; fi
			printf '%d %d' "$r" "$((SECONDS - s))" >"$DIR/$i.done"
		) &
		launched=$((launched + 1))
	done

	# Report any newly-finished layers (index order within a poll; the [k/total] counter is truth).
	progressed=0
	i=0
	while [ "$i" -lt "$launched" ]; do
		if [ -f "$DIR/$i.done" ] && [ "${REPORTED[$i]:-0}" != "1" ]; then
			REPORTED[$i]=1
			read -r r el <"$DIR/$i.done"
			done_count=$((done_count + 1))
			progressed=1
			if [ "$r" = "0" ]; then
				printf '  [%2d/%2d] %-36s PASS  %3ds\n' "$done_count" "$total" "${NAMES[$i]}" "$el"
				pass=$((pass + 1))
			else
				printf '  [%2d/%2d] %-36s FAIL  %3ds\n' "$done_count" "$total" "${NAMES[$i]}" "$el"
				fail=$((fail + 1))
				failed_names+=("${NAMES[$i]}")
				sed 's/^/        | /' "$DIR/$i.log" | tail -14
			fi
		fi
		i=$((i + 1))
	done
	[ "$progressed" -eq 0 ] && sleep 0.2
done

wall=$((SECONDS - T0))
echo
if [ "$fail" -eq 0 ]; then
	echo "ALL $pass HARNESS LAYERS PASS  (${wall}s wall-clock)"
	exit 0
else
	echo "$fail LAYER(S) FAILED: ${failed_names[*]}  (${wall}s wall-clock)"
	exit 1
fi
