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
# A layer is normally headless. `add_gl` marks one that must render for real — the dummy renderer paints
# blank frames, so any layer that judges PIXELS has to own a window. Those layers self-skip (green) when
# no display exists, which is how CI stays honest without pretending to have tested a picture.
NAMES=(); SCRIPTS=(); GLFLAG=()
add() { NAMES+=("$1"); SCRIPTS+=("$2"); GLFLAG+=(0); }
add_gl() { NAMES+=("$1"); SCRIPTS+=("$2"); GLFLAG+=(1); }
add "sim (core/determinism)"          "res://tests/test_sim.gd"
add "stress (invariants/flow/power)"  "res://tests/test_stress.gd"
add "worldgen (gen/ore/fine)"         "res://tests/test_worldgen.gd"
add "power/water (field/flood)"       "res://tests/test_power_water.gd"
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
add "check_score (the descent)"       "res://tools/check_score.gd"
add "check_rhythm (dig groove)"       "res://tools/check_rhythm.gd"
add "check_room_reads (2nd plane)"    "res://tools/check_room_reads.gd"
add "check_texture (no static)"       "res://tools/check_texture.gd"
add "check_grid (no tilemap)"         "res://tools/check_grid.gd"
add "check_seam (the grain)"          "res://tools/check_seam.gd"
add_gl "check_opening (no dead space)" "res://tools/check_opening.gd"
add_gl "check_underground (lit rock)"  "res://tools/check_underground.gd"
add_gl "check_water_reads (fluid)"     "res://tools/check_water_reads.gd"
add_gl "check_frametime (120fps)"      "res://tools/check_frametime.gd"
add "check_stride (the run)"          "res://tools/check_stride.gd"
add "check_tells (hollow rock)"       "res://tools/check_tells.gd"
add "check_controls"                  "res://tools/check_controls.gd"
add "check_pack_layout"               "res://tools/check_pack_layout.gd"
add "check_pixel_snap"                "res://tools/check_pixel_snap.gd"
add "check_agility (movement score)"  "res://tools/check_agility.gd"
add "check_grapple (swing score)"     "res://tools/check_grapple.gd"
add "check_loop_health (loop score)"  "res://tools/check_loop_health.gd"
add "check_pacing (session shape)"    "res://tools/check_pacing.gd"
add "check_richness (a rich earth)"   "res://tools/check_richness.gd"
add "check_descent (a way down)"      "res://tools/check_descent.gd"
add "check_relief (a landscape)"      "res://tools/check_relief.gd"
add "check_traverse (rope=travel)"    "res://tools/check_traverse.gd"
add "check_wrap (rope bends)"         "res://tools/check_wrap.gd"
add "check_voice (audio reads)"       "res://tools/check_voice.gd"
add "check_teaching (it teaches)"     "res://tools/check_teaching.gd"
add "check_pump (wind it up)"         "res://tools/check_pump.gd"
add "check_plunge (ride it down)"     "res://tools/check_plunge.gd"
add "check_aim (honest marker)"       "res://tools/check_aim.gd"
add "check_impact (a fall costs)"     "res://tools/check_impact.gd"
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
			if [ "${GLFLAG[$i]}" = "1" ]; then
				if "$GODOT" --path . --script "${SCRIPTS[$i]}" >"$DIR/$i.log" 2>&1; then r=0; else r=1; fi
			elif "$GODOT" --headless --path . --script "${SCRIPTS[$i]}" >"$DIR/$i.log" 2>&1; then r=0; else r=1; fi
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
