#!/usr/bin/env bash
# One-command harness: runs EVERY verification layer and exits non-zero if ANY fails.
# The whole safety net behind autonomous sprints, in one invocation:
#   tools/run_harness.sh
#
# PARALLEL by default: the layers are independent Godot processes, so wall-clock is max(layers), not
# sum(layers). Concurrency is bounded to the CPU count.
#
# YOUR SAVE IS SAFE, AND THAT IS CHECKED, NOT PROMISED. These three lines used to claim that every layer
# "writes only uniquely-named user:// files" — a comment asserting a safety property with nothing behind
# it. It was false: check_saveload drove the real F5 slot and then deleted it, so the one command this
# project tells everyone to run destroyed the developer's game. Two things now hold it:
#   * `check_save_isolation` (a layer, first in the list) proves from source that no fixture can even
#     name the production slot, and that anything reaching the save verbs redirects them first.
#   * `save_sentinel` (below, wrapped around the sweep) hashes the real slot before and after. A run
#     that rewrites or deletes it fails LOUDLY even if every layer passed.
#   JOBS=1   tools/run_harness.sh   # serialize (debug; old behavior)
#   JOBS=4   tools/run_harness.sh   # cap at 4 concurrent layers
#   GODOT=/path/to/Godot            # override the engine path
#
# THREE STATES, BECAUSE A SKIP IS NOT A PASS. A layer used to be a bit: exit 0 or not. That bit could not
# express the thing four of these layers do every time CI runs — `add_gl` layers judge PIXELS, they detect
# that there is no display, and they stop. They stopped by calling `quit(0)`, so a layer that ran nothing
# was counted alongside layers that ran everything, and the run printed ALL <n> HARNESS LAYERS PASS with
# four of them unexecuted. It printed that for as long as CI has been green. The measurement that caught
# it is the wall-clock: `check_opening` takes 12s with a display and 1s without, and one second is not a
# test run. So the outcome is now PASS / FAIL / SKIP, the summary reports the three separately, and it
# never again says "ALL" when the count of things that ran is smaller than the count of things there are.
#
# HOW A LAYER DECLARES A SKIP — the whole contract, and it is opt-in, so the other layers need no edit:
#   1. exit 42 (`quit(SKIP)` in GDScript), and
#   2. print one line containing `: SKIP` saying WHY.
# Both halves are required. A bare 42 with no reason is reported as a FAILURE, because a layer that opts
# out without saying why is indistinguishable from one that opted out by accident — which is exactly the
# defect above, one level up. 42 is reserved: no layer may use it to mean anything else.
#
# AND A PASS IS NOT A VERIFICATION. The same lie has a smaller form, and it was live on main at the same
# time: `check_dig_hitch` read a texture back from the DUMMY renderer, which uploads nothing, compared one
# blank surface to another blank surface, found them identical and exited 0 — while the stale-cache defect
# it exists to catch was shipping. Full size, one distinct byte value; an emptiness check would not have
# seen it. Nothing out here can detect an assertion that could not fail. What the runner CAN do is refuse
# to let a layer stand an assertion down in silence:
#   a layer that passes but skipped PART of itself prints a line beginning `SKIP:` for each part
# and it is then reported as PASS* with the count, listed by name in the summary, and treated exactly like
# a whole-layer skip by strict mode. `SKIP:` at the start of a line is the marker; `: SKIP` mid-line is the
# whole-layer one; they do not collide.
#
# FAIL CLOSED WHERE A FULL RUN IS CLAIMED. A skip is honest on a machine with no display. On a machine
# that HAS one it means a layer quietly opted out, and that must be red:
#   SF_STRICT=1   tools/run_harness.sh   # any skip, whole-layer or partial, fails the run (exit 4)
#   SF_STRICT=0   tools/run_harness.sh   # skips are tolerated even with a display
# Unset is the honest default: strict when there is a display (we are claiming a full-fidelity run), lax
# when there is not (CI cannot render, and failing for that would just be the 33 red pushes again).
#
# THE LOGS OUTLIVE THE RUN. Every layer's output used to go to a mktemp dir that the EXIT trap deleted, so
# the evidence for a CI failure died with the job and all anyone got was the 14 tail lines printed inline.
# Now the directory survives any run that was not perfectly clean, and is named up front so CI can collect
# it:
#   SF_LOG_DIR=/path   tools/run_harness.sh   # keep every log there, always (what the workflow does)
# With no SF_LOG_DIR the dir is still printed, and is deleted only when every layer passed.
#
# A SUBSET IS NEVER A HARNESS RUN. `SF_ONLY` selects layers by extended regex against their name — for
# running the pixel layers on a display job, or one layer through the runner's own plumbing:
#   SF_ONLY='check_opening|check_frametime'   tools/run_harness.sh
# A filtered run prints what it selected out of how many and refuses to print the all-pass line, because
# the sentence "ALL LAYERS PASS" is only true of the whole list.
#
# EXCLUSIVE BY DEFAULT, because a worktree does not isolate `user://` — Godot keys it on the project NAME,
# so every checkout on this machine shares one save slot and one set of fixtures, and two runs at once
# produce two results neither of which means anything. The runner now takes a machine-wide lock before it
# touches any of it (see LOCK below for the whole story, which is a real afternoon):
#   SF_LOCK_WAIT=900   seconds to wait for a run already in flight before giving up (exit 5)
#   SF_NO_LOCK=1       run anyway, concurrently, and own the consequences
#
# EXIT CODES, because there are five now and a caller that treats "not 0" as "a test failed" will
# misdiagnose four of them:
#   0  everything that ran passed, and anything skipped is named in the summary
#   1  a layer failed
#   2  could not start — the sentinel would not arm, or SF_ONLY matched nothing
#   3  the production save slot was touched (layer results are moot)
#   4  something was skipped while SF_STRICT was on: not a full sweep
#   5  another harness run holds the lock
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Default concurrency = CPU count (bounds memory too); overridable via JOBS.
NCPU="$( (sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8) )"
JOBS="${JOBS:-$NCPU}"

# --- the layers, in declaration order (order is cosmetic; results stream as they finish) ---
# A layer is normally headless. `add_gl` marks one that must render for real — the dummy renderer paints
# blank frames, so any layer that judges PIXELS has to own a window.
#
# THE SELF-SKIP ONLY WORKS IF WE LET IT RUN. Those layers guard themselves with
# `DisplayServer.get_name() == "headless"` and pass trivially when there is no display — but that line is
# GDScript, and GDScript never executes if Godot cannot bring up a DisplayServer in the first place. So
# handing an `add_gl` layer a window flag on a machine with no window does not produce an honest skip; it
# produces `Unable to create DisplayServer, all display drivers failed` and a dead process, which is
# exactly what CI had been reporting on every push for weeks while this comment claimed otherwise.
# The display test therefore lives out here, in the runner, where it can still choose the flag.
# Is there a real display for an `add_gl` layer to open a window on? macOS always has one (Godot uses the
# native driver, and there is no DISPLAY variable to consult); elsewhere, ask X11/Wayland. `SF_HEADLESS=1`
# forces the no-display path, which is how you reproduce a CI run on a developer machine.
HAVE_DISPLAY=0
if [ "${SF_HEADLESS:-0}" != "1" ]; then
	case "$(uname -s)" in
		Darwin) HAVE_DISPLAY=1 ;;
		*) [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && HAVE_DISPLAY=1 ;;
	esac
fi

# The reserved exit code a layer uses to say "I did not run, and here is why". Kept in one place here and
# hardcoded as `const SKIP: int = 42` in the four layers that can use it — the pair is load-bearing, so if
# you move it, move both.
SKIP_CODE=42

# Strict = any skip is a failure. Default: on wherever we have a display, because that is a run whose
# results get quoted as the full suite. Off with no display, where skipping is the correct behaviour and
# the alternative is the 33-red-push era (see the DisplayServer comment above).
STRICT="${SF_STRICT:-$HAVE_DISPLAY}"

NAMES=(); SCRIPTS=(); GLFLAG=(); EXCL=()
add() { NAMES+=("$1"); SCRIPTS+=("$2"); GLFLAG+=(0); EXCL+=(0); }
add_gl() { NAMES+=("$1"); SCRIPTS+=("$2"); GLFLAG+=(1); EXCL+=(0); }

# EXCLUSIVE — the scheduler drains every other layer before this one starts and launches nothing beside it.
#
# For a layer that measures MILLISECONDS this is not a nicety, it is the difference between a number and a
# rumour. The parallel sweep runs JOBS=NCPU Godot processes at once, so a frame-time layer sharing the box
# with a dozen neighbours is timing the contention, not the game. Measured, on this machine, same commit:
#
#            alone (SF_ONLY)      inside the parallel sweep
#   IDLE p95    15.59ms                 20.70ms
#   DIG  p95    32.58ms                 40.40ms
#
# A 33% inflation on IDLE and 24% on DIG, entirely manufactured by the harness. The file already warned
# about this for a SECOND concurrent run ("a dozen other Godot processes fight it for the GPU") without
# noticing the same sentence describes one run of itself. A 120fps gate read off the inflated column would
# fail a game that met it — and, worse, could not be trusted when it eventually passed.
add_excl() { NAMES+=("$1"); SCRIPTS+=("$2"); GLFLAG+=(1); EXCL+=(1); }
add "check_save_isolation (no harm)"  "res://tools/check_save_isolation.gd"
add "check_save_durability (P0)"      "res://tools/check_save_durability.gd"
add "check_save_frontier (envelope)"  "res://tools/check_save_frontier.gd"
add "sim (core/determinism)"          "res://tests/test_sim.gd"
add "stress (invariants/flow/power)"  "res://tests/test_stress.gd"
add "worldgen (gen/ore/fine)"         "res://tests/test_worldgen.gd"
add "power/water (field/flood)"       "res://tests/test_power_water.gd"
add "check_progression_payable"       "res://tools/check_progression_payable.gd"
add "check_craftable_registry"        "res://tools/check_craftable_registry.gd"
add "check_material_registry"         "res://tools/check_material_registry.gd"
add "measure_player (motion feel)"    "res://tools/measure_player.gd"
add "check_step"                      "res://tools/check_step.gd"
add "check_stepup"                    "res://tools/check_stepup.gd"
add "check_walk"                      "res://tools/check_walk.gd"
add "check_body_stress"               "res://tools/check_body_stress.gd"
add "check_water_move (L3 impedance)" "res://tools/check_water_move.gd"
add "check_lift"                      "res://tools/check_lift.gd"
add "check_fastforward"               "res://tools/check_fastforward.gd"
add "check_mining"                    "res://tools/check_mining.gd"
# add_gl, not add: it reads a rendered texture back and compares it, and the dummy renderer hands it two
# blank surfaces that match. Registered headless it passed on the identity of nothing.
add_gl "check_dig_hitch (friction)"   "res://tools/check_dig_hitch.gd"
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
add "check_bits (a bit is a verb)"    "res://tools/check_bits.gd"
add "check_drift (lateral/vertical)"  "res://tools/check_drift.gd"
add "check_spoil (crush/pack)"        "res://tools/check_spoil.gd"
add "check_refusal (rock says no)"    "res://tools/check_refusal.gd"
add "check_lode (vein outlives blow)" "res://tools/check_lode.gd"
add "check_head (stand it on it)"     "res://tools/check_head.gd"
add "check_bazaar_ruin (it has art)"  "res://tools/check_bazaar_ruin.gd"
add "check_draw_cull (offscreen)"     "res://tools/check_draw_cull.gd"
add_gl "check_opening (no dead space)" "res://tools/check_opening.gd"
add_gl "check_underground (lit rock)"  "res://tools/check_underground.gd"
add_gl "check_water_reads (fluid)"     "res://tools/check_water_reads.gd"
# add_gl and NOT add_excl: it renders every item icon and compares silhouettes and CIELab means. Contention
# changes how LONG that takes and not one pixel of what comes back, and exclusivity is the scheduler's most
# expensive favour — it is for layers whose ANSWER is a duration. This one's answer is a shape.
add_gl "check_item_reads (icons)"      "res://tools/check_item_reads.gd"
# Named for what it asserts everywhere, which is a RATIO — a dig may cost a few quiet frames, never twenty.
# It read "120fps" for its whole life and never once asserted 8.33ms; that absolute now exists, but only on
# hardware someone has named with SF_PERF_HOST, and a layer name cannot say "sometimes".
add_excl "check_frametime (hitch+budget)" "res://tools/check_frametime.gd"
add "check_stride (the run)"          "res://tools/check_stride.gd"
add "check_tells (hollow rock)"       "res://tools/check_tells.gd"
add "check_controls"                  "res://tools/check_controls.gd"
add "check_input_deafness (shutter)"  "res://tools/check_input_deafness.gd"
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

DECLARED="${#NAMES[@]}"

# SF_ONLY narrows the list. Everything downstream then talks about "selected of declared", never about
# "all", because a filtered sweep that printed the all-pass line would be a new way to claim coverage
# nobody ran — the exact bug this file was opened to fix.
if [ -n "${SF_ONLY:-}" ]; then
	fn=(); fs=(); fg=(); fe=()
	i=0
	while [ "$i" -lt "$DECLARED" ]; do
		if printf '%s' "${NAMES[$i]}" | grep -Eq -- "$SF_ONLY"; then
			fn+=("${NAMES[$i]}"); fs+=("${SCRIPTS[$i]}"); fg+=("${GLFLAG[$i]}"); fe+=("${EXCL[$i]}")
		fi
		i=$((i + 1))
	done
	NAMES=(${fn[@]+"${fn[@]}"}); SCRIPTS=(${fs[@]+"${fs[@]}"}); GLFLAG=(${fg[@]+"${fg[@]}"})
	EXCL=(${fe[@]+"${fe[@]}"})
	if [ "${#NAMES[@]}" -eq 0 ]; then
		echo "!! SF_ONLY='$SF_ONLY' matched none of the $DECLARED layers — refusing to report a run of nothing"
		exit 2
	fi
fi

total="${#NAMES[@]}"
[ "$JOBS" -gt "$total" ] && JOBS="$total"
[ "$JOBS" -lt 1 ] && JOBS=1

# Logs are named after their layer, not numbered `0.log`. These are uploaded as a CI artifact now, and a
# directory of bare integers is not evidence anyone is going to read.
LOGS=()
li=0
while [ "$li" -lt "$total" ]; do
	slug="${NAMES[$li]%% *}"
	printf -v LOGN '%02d' "$li"
	LOGS+=("$LOGN-${slug//\//_}.log")
	li=$((li + 1))
done

pass=0
fail=0
skip=0
partial=0
failed_names=()
skipped_names=()
partial_names=()
REPORTED=()
launched=0
done_count=0
T0=$SECONDS

# Where the per-layer logs live. Kept whenever the run was not perfectly clean — a failure whose output
# was deleted by our own EXIT trap is a failure nobody can diagnose, and that is what CI used to hand back.
if [ -n "${SF_LOG_DIR:-}" ]; then
	DIR="$SF_LOG_DIR"
	mkdir -p "$DIR"
	KEEP_LOGS=1
else
	DIR="$(mktemp -d)"
	KEEP_LOGS=0
fi
# The per-layer done-markers live somewhere else entirely and are always thrown away. They used to share
# the log dir, which was harmless while that dir was a fresh mktemp every run — but SF_LOG_DIR can point
# at a directory that already holds a previous run's markers, and a stale `0.done` would be read as this
# run's layer 0 finishing, with that run's exit code, before the layer had even started.
MARKS="$(mktemp -d)"

# ONE HARNESS AT A TIME ON A MACHINE, and this is not tidiness — it is correctness.
# Godot keys `user://` on the project NAME, not the project directory, so a git worktree does NOT isolate
# it: every checkout of Sinkforge on this machine reads and writes one
# ~/Library/Application Support/Godot/app_userdata/Sinkforge/. Two runs therefore share one production
# save slot AND one set of test fixtures. That cost an afternoon on 2026-08-17, twice and in opposite
# directions: two concurrent sweeps each reported "THE SAVE SLOT WAS DELETED BY THE HARNESS", because the
# other one's `verify` had removed the planted marker mid-sweep. Both were false alarms — but the same
# collision has a quieter form, where a neighbour clobbers a fixture and a layer passes for a reason that
# has nothing to do with the code, and that one nobody would ever notice. A result is only meaningful if
# the run was exclusive, so make it exclusive. `mkdir` is the atomic primitive: it succeeds for exactly
# one caller.
LOCK="${SF_LOCK:-${TMPDIR:-/tmp}/sinkforge-harness.lock}"
LOCK_WAIT="${SF_LOCK_WAIT:-900}"
LOCK_HELD=0

# Declared HERE, above the trap, not where they are first used. `set -u` is on, so an exit taken between
# installing the trap and arming the sentinel would run a cleanup handler that dies on an unset variable —
# and a cleanup that aborts halfway is worse than one that does nothing, because it stops before releasing
# the lock. Both start in the state "there is nothing to take back", which is true at this point.
SENTINEL=""
SENTINEL_ARMED=0

harness_cleanup() {
	local rc=$?
	# TAKE BACK THE SENTINEL FIRST, while its state file still exists — the log dir it lives in is removed
	# further down. A run that never reached `verify` (Ctrl-C, a crash, an early exit on any of the codes
	# above) has still left a marker at the player's REAL save path, and leaving it there is the one piece
	# of litter this whole instrument exists to argue nobody drops. Best-effort by construction: disarm
	# exits 0 on every path and removes only bytes still identical to what it planted, so a slot something
	# else wrote during the run survives as evidence instead of being tidied away.
	if [ "$SENTINEL_ARMED" = "1" ]; then
		"$GODOT" --headless --path . --script res://tools/save_sentinel.gd -- disarm "$SENTINEL" 2>&1 \
			| grep -E '^save_sentinel:' || true
	fi
	[ "$LOCK_HELD" = "1" ] && rm -rf "$LOCK"
	rm -rf "$MARKS"
	if [ "$KEEP_LOGS" = "1" ] || [ "$rc" != "0" ] || [ "$((fail + skip + partial))" -gt 0 ]; then
		printf '\nper-layer logs: %s\n' "$DIR"
	else
		rm -rf "$DIR"
	fi
}
trap harness_cleanup EXIT

# Every verdict goes to the terminal AND to summary.txt in the log dir, so the uploaded artifact carries
# the result table and not just a pile of logs to correlate by hand. Truncated, not appended: SF_LOG_DIR
# can name a directory that already has a previous run's table in it.
: >"$DIR/summary.txt"
say() {
	printf '%s\n' "$1"
	printf '%s\n' "$1" >>"$DIR/summary.txt"
}

# One line that says exactly what this run is, so a pasted transcript cannot be mistaken for another mode.
mode="display"; [ "$HAVE_DISPLAY" = "1" ] || mode="NO DISPLAY — the pixel layers will skip"
strictness="skips tolerated"; [ "$STRICT" = "1" ] && strictness="STRICT: any skip fails the run"
subset=""; [ "$total" -ne "$DECLARED" ] && subset=" of $DECLARED — SUBSET, SF_ONLY='${SF_ONLY:-}'"
say "== Sinkforge harness (parallel, JOBS=$JOBS, layers=$total$subset, $mode, $strictness) =="

# Take the machine-wide lock before anything touches user://. A run that was killed cannot release its own
# lock, so a holder whose pid is gone gets cleared rather than being allowed to wedge every future run —
# the cure must not be worse than the disease. SF_NO_LOCK=1 opts out for anyone who knows better.
if [ "${SF_NO_LOCK:-0}" != "1" ]; then
	waited=0
	while true; do
		if mkdir "$LOCK" 2>/dev/null; then
			printf '%s\n%s\n' "$$" "$ROOT" >"$LOCK/owner"
			LOCK_HELD=1
			break
		fi
		holder="$(head -1 "$LOCK/owner" 2>/dev/null || true)"
		if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
			echo "  (clearing a stale harness lock: pid $holder is gone)"
			rm -rf "$LOCK"
			continue
		fi
		# A lock directory that has named no owner for ten seconds is debris, not a run.
		if [ -z "$holder" ] && [ "$waited" -ge 10 ]; then
			echo "  (clearing a harness lock that never named an owner)"
			rm -rf "$LOCK"
			continue
		fi
		if [ "$waited" -ge "$LOCK_WAIT" ]; then
			echo "!! another harness has held $LOCK for ${waited}s (pid ${holder:-unknown}) — refusing to run"
			echo "   concurrently, because both results would then be worthless. SF_NO_LOCK=1 overrides."
			exit 5
		fi
		[ $((waited % 30)) -eq 0 ] && echo "  waiting for the harness lock (held by pid ${holder:-?}) ..."
		sleep 2
		waited=$((waited + 2))
	done
fi

# Arm the save sentinel BEFORE any layer launches. A failure here is fatal: running unguarded is exactly
# the situation that cost a developer their save.
SENTINEL="$DIR/save_sentinel.state"
if ! "$GODOT" --headless --path . --script res://tools/save_sentinel.gd -- arm "$SENTINEL" 2>&1 | grep -E '^save_sentinel:'; then
	echo "  !! could not arm the save sentinel — refusing to run the harness unguarded"
	exit 2
fi
# From here on an abort owes the player a disarm (see harness_cleanup). Set AFTER the arm succeeded: a
# failed arm planted nothing, and disarming on that path would be looking for litter nobody dropped.
SENTINEL_ARMED=1

while [ "$done_count" -lt "$total" ]; do
	# Fill free slots.
	while [ "$launched" -lt "$total" ] && [ "$((launched - done_count))" -lt "$JOBS" ]; do
		i="$launched"
		# An EXCLUSIVE layer gets the machine to itself: wait here until everything in flight has finished,
		# and once it launches, stop filling slots until it is done. See add_excl for why a timing layer
		# measured beside its neighbours reports the contention rather than the game.
		if [ "${EXCL[$i]}" = "1" ] && [ "$((launched - done_count))" -gt 0 ]; then
			break
		fi
		(
			s=$SECONDS
			# The EXACT exit code, not a boolean. Collapsing it to 0/1 is what made a skip indistinguishable
			# from a pass; 42 has to survive the trip back out here to mean anything.
			if [ "${GLFLAG[$i]}" = "1" ] && [ "$HAVE_DISPLAY" = "1" ]; then
				"$GODOT" --path . --script "${SCRIPTS[$i]}" >"$DIR/${LOGS[$i]}" 2>&1
			else
				"$GODOT" --headless --path . --script "${SCRIPTS[$i]}" >"$DIR/${LOGS[$i]}" 2>&1
			fi
			printf '%d %d' "$?" "$((SECONDS - s))" >"$MARKS/$i.done"
		) &
		launched=$((launched + 1))
		if [ "${EXCL[$i]}" = "1" ]; then
			break
		fi
	done

	# Report any newly-finished layers (index order within a poll; the [k/total] counter is truth).
	progressed=0
	i=0
	while [ "$i" -lt "$launched" ]; do
		if [ -f "$MARKS/$i.done" ] && [ "${REPORTED[$i]:-0}" != "1" ]; then
			REPORTED[$i]=1
			read -r r el <"$MARKS/$i.done"
			done_count=$((done_count + 1))
			progressed=1
			log="$DIR/${LOGS[$i]}"
			if [ "$r" = "0" ]; then
				# A PASS IS NOT A VERIFICATION, and that is a second lie of the same family as the one this file
				# was opened for. `check_dig_hitch` compared two textures read back from the dummy renderer, which
				# uploads nothing: both surfaces were full-size and one byte value wide, they matched, and the layer
				# exited 0 while the stale-cache defect it guards was live on main. Nothing here can catch an
				# assertion that could not fail — but a layer that KNOWS it is standing an assertion down says so
				# with a line beginning `SKIP:`, and those have to reach the tally, or a per-layer PASS quietly
				# becomes the summary line's old lie in miniature.
				nskip="$(grep -c '^[[:space:]]*SKIP:' "$log")"
				pass=$((pass + 1))
				if [ "$nskip" -gt 0 ]; then
					part="$(grep -m1 '^[[:space:]]*SKIP:' "$log" | sed 's/^[[:space:]]*SKIP:[[:space:]]*//' | cut -c1-66)"
					say "$(printf '  [%2d/%2d] %-36s PASS* %3ds  %d skipped: %s' \
						"$done_count" "$total" "${NAMES[$i]}" "$el" "$nskip" "$part")"
					partial=$((partial + 1))
					partial_names+=("${NAMES[$i]}")
				else
					say "$(printf '  [%2d/%2d] %-36s PASS  %3ds' "$done_count" "$total" "${NAMES[$i]}" "$el")"
				fi
			elif [ "$r" = "$SKIP_CODE" ]; then
				# Half a contract is not a contract: 42 buys the SKIP state only together with a line saying why.
				# Without one there is no telling a deliberate opt-out from a layer that fell into a skip path it
				# had no business reaching — which is this same bug again, one level further down.
				why="$(grep -m1 ': SKIP' "$log" | sed 's/^[[:space:]]*//' | cut -c1-88)"
				if [ -z "$why" ]; then
					say "$(printf '  [%2d/%2d] %-36s FAIL  %3ds  exit %d (SKIP) with no reason line' \
						"$done_count" "$total" "${NAMES[$i]}" "$el" "$SKIP_CODE")"
					fail=$((fail + 1))
					failed_names+=("${NAMES[$i]}")
					sed 's/^/        | /' "$log" | tail -14
				else
					say "$(printf '  [%2d/%2d] %-36s SKIP  %3ds  %s' \
						"$done_count" "$total" "${NAMES[$i]}" "$el" "$why")"
					skip=$((skip + 1))
					skipped_names+=("${NAMES[$i]}")
				fi
			else
				say "$(printf '  [%2d/%2d] %-36s FAIL  %3ds  (exit %d)' \
					"$done_count" "$total" "${NAMES[$i]}" "$el" "$r")"
				fail=$((fail + 1))
				failed_names+=("${NAMES[$i]}")
				sed 's/^/        | /' "$log" | tail -14
			fi
		fi
		i=$((i + 1))
	done
	[ "$progressed" -eq 0 ] && sleep 0.2
done

wall=$((SECONDS - T0))
echo

# Verify the sentinel AFTER the sweep. This can turn an all-green run red, and it should: a suite that
# passes every assertion while eating the player's save has not passed.
#
# CONCURRENT RUNS, which cost time here once and no longer produce the same lie: two harness runs on one
# machine share one production slot, because user:// is keyed on the project NAME and worktrees do not
# separate it. Markers now carry the arming process's pid, so a neighbour's `verify` no longer matches its
# digest against OUR plant and no longer deletes it — what it reports instead is REWRITTEN, which is true.
# A run next to another run therefore gets an accurate accusation rather than a phantom deletion, but it
# is still an accusation about a neighbour and not about a layer. Check for a second `run_harness.sh`
# before believing this one. (The same neighbour also makes check_frametime hitch, since it measures
# milliseconds while a dozen other Godot processes fight it for the GPU.)
if ! "$GODOT" --headless --path . --script res://tools/save_sentinel.gd -- verify "$SENTINEL" 2>&1 | grep -E '^save_sentinel:'; then
	echo
	echo "!! THE HARNESS TOUCHED THE PRODUCTION SAVE SLOT. Layer results ($pass pass / $fail fail) are moot."
	exit 3
fi
# `verify` has already taken back anything it planted, so the abort-path disarm has nothing left to do.
# Clearing this is not cosmetic: disarm would otherwise run on a slot verify just removed, and the next
# thing it would find at that path is whatever a CONCURRENT run planted there a moment later.
SENTINEL_ARMED=0

# THE SUMMARY. Its only job is to be true. It printed "ALL 61 HARNESS LAYERS PASS" on runs where 57 layers
# ran and 4 returned in one second having drawn nothing, and every branch below exists to make that
# sentence impossible to print again: the tally always carries all four numbers, anything that did not run
# is named, and the word ALL is reserved for a full list that skipped nothing at any level.
tally="$pass PASS / $fail FAIL / $skip SKIP of $total"
[ "$partial" -gt 0 ] && tally="$tally ($partial of those passes stood assertions down)"
[ "$total" -ne "$DECLARED" ] && tally="$tally selected (of $DECLARED declared — SUBSET RUN)"

if [ "$skip" -gt 0 ]; then
	say "SKIPPED — NOT RUN, NOT PASSED: ${skipped_names[*]}"
fi
if [ "$partial" -gt 0 ]; then
	say "PASSED WITHOUT VERIFYING EVERYTHING — assertions stood down inside: ${partial_names[*]}"
fi

if [ "$fail" -gt 0 ]; then
	say "$tally — FAILED: ${failed_names[*]}  (${wall}s wall-clock)"
	exit 1
fi

if [ "$((skip + partial))" -gt 0 ] && [ "$STRICT" = "1" ]; then
	# Fail closed, at BOTH levels. A whole layer that opted out on a machine that could have run it is not a
	# full sweep; neither is a layer that ran, passed, and quietly left one of its assertions unmade. The
	# point of strict mode is that neither run is quotable as green.
	say "$tally — FAIL: $skip layer(s) and $partial assertion group(s) skipped while SF_STRICT is on; this run does not count as a full sweep  (${wall}s)"
	exit 4
fi

if [ "$((skip + partial))" -gt 0 ]; then
	say "$tally — $skip layer(s) DID NOT RUN and $partial pass(es) left assertions unmade  (${wall}s wall-clock)"
	exit 0
fi

if [ "$total" -ne "$DECLARED" ]; then
	say "$tally — subset green; the full harness has NOT been run  (${wall}s wall-clock)"
	exit 0
fi

say "ALL $pass HARNESS LAYERS PASS  (${wall}s wall-clock)"
exit 0
