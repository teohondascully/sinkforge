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
# Two more filters, and they exist because CI got this wrong in a way nobody could see:
#   SF_GL_ONLY=1   select exactly the layers registered `add_gl`/`add_excl` — the ones that need a surface
#   SF_NOT='regex' drop layers whose name matches, ON TOP of whatever else selected them
# The display job used to name its four pixel layers by hand. `add_gl` grew to six, and the two that
# arrived after that list was written ran in NO CI JOB AT ALL: they skip in the headless job because they
# need a window, and the display job never selected them. Deriving the selection from the REGISTRATION
# closes that permanently, and `SF_NOT` makes the one deliberate exclusion a statement rather than an
# omission — because in a hand-kept list "left out on purpose" and "forgotten" look identical.
# `tools/check_ci_coverage.gd` holds the workflow to this, both directions.
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
#
# THEY ARE ORDERED BY SEVERITY AND THAT MEANS 1 MASKS 4. A run that both fails a layer AND stands an
# assertion group down exits 1, so the exit code alone cannot say the run was also incomplete — the words
# are printed ("PASSED WITHOUT VERIFYING EVERYTHING", "this run does not count as a full sweep") and only
# the words carry it. A caller that reads the integer and not the summary will record a failing run as a
# COMPLETE failing run, and the day the failure is fixed it will record a green that was never full.
# Found the hard way on 2026-08-17, when two separate runs reported "exit 0" for sweeps that exited 4 and 1 —
# in both cases because the status being read belonged to the `tail`/`grep` at the end of the command, not
# to the harness. Put the harness LAST, or grep the exit line out of the file, before saying anything.
set -uo pipefail

# THIS SCRIPT'S OWN CONTENT, CHECKSUMMED BEFORE IT DOES ANYTHING. Bash reads a script incrementally from a
# byte offset, so editing this file while a sweep is in flight makes the running shell resume inside the
# NEW text at the OLD offset. It does not crash cleanly; it produces a plausible error about something
# else — a real run of mine died on `lock_claim: command not found` for a function that is defined a
# hundred lines above its use, and the obvious reading was "the change I just made is broken". The change
# was fine. The runner had been rewritten underneath it.
#
# Parallel work shares this repo and this file is edited from more than one place, so the hazard is not hypothetical and the
# damage is not the crash — it is a sweep that finishes and gets believed. Checked again at exit; if the
# bytes moved, the run says so in the summary, loudly, whatever its verdict was.
SELF_SUM="$(cksum < "$0" 2>/dev/null || echo unknown)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ISOLATE `user://`, WHICH IS THE ONLY REAL FIX FOR THE HAZARD DESCRIBED AT THE LOCK BELOW.
# Godot keys `user://` on the project NAME, so every checkout of Sinkforge on this machine — worktrees
# included — reads and writes one ~/Library/Application Support/Godot/app_userdata/Sinkforge/. The lock
# makes runs take turns in it; it does not stop the harness from being IN the player's save directory at
# all, which is why the sentinel has to plant a marker at the player's real slot to prove it left again.
#
# Measured on this box before choosing, because all three candidates are plausible and two do not work:
# Godot READS XDG_DATA_HOME and XDG_CONFIG_HOME on macOS and IGNORES them (user:// stayed at Library/
# Application Support with both set); there is no command-line flag for the user directory; and the
# project-settings route (`use_custom_user_dir`) would move the SHIPPED GAME's save too, which is the one
# thing that must not change. HOME works: user:// follows it, per process, with no file on disk for two
# runs to fight over — which `override.cfg` would have been, and that file is spoken for anyway.
#
# Keyed on the ROOT PATH, not on a run id: the same checkout wants the same fixtures and a warm shader
# cache across runs, while a second worktree gets its own namespace and stops colliding with this one.
# Deliberately NOT under $DIR — surviving the run is the point, and a cold first boot is a one-time cost.
#
# BOTH knobs are set, and that is not belt-and-braces, it is the platform difference. macOS ignores XDG and
# derives the path from HOME; Linux — which is what CI runs — honours XDG_DATA_HOME and would otherwise
# keep using a container-provided one, leaking the isolation on the only machine nobody watches.
sf_hash() { if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi; }
if [ "${SF_REAL_HOME:-0}" != "1" ]; then
	SF_HOME="${SF_HOME:-${TMPDIR:-/tmp}/sinkforge-home-$(printf '%s' "$ROOT" | sf_hash | cut -c1-12)}"
	mkdir -p "$SF_HOME/.local/share" "$SF_HOME/.config" \
		|| { echo "!! could not create the isolated home at $SF_HOME"; exit 2; }
	# Hand the sentinel the REAL slot before we lose the path, so it can witness production read-only.
	# Isolation makes "the harness never touched your save" true; this is what makes it PROVED.
	if [ "$(uname -s)" = "Darwin" ]; then
		export SF_PRODUCTION_SLOT="$HOME/Library/Application Support/Godot/app_userdata/Sinkforge/sinkforge.save"
	else
		export SF_PRODUCTION_SLOT="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Sinkforge/sinkforge.save"
	fi
	export HOME="$SF_HOME"
	export XDG_DATA_HOME="$SF_HOME/.local/share"
	export XDG_CONFIG_HOME="$SF_HOME/.config"
	# Declares the isolation to fixtures that write `user://`. See the same line in with_machine.sh for
	# why it is a positive marker rather than a check for SF_PRODUCTION_SLOT (which only THIS file sets,
	# so a guard keyed on it would refuse under with_machine.sh, which is isolated and legitimate).
	export SF_ISOLATED_HOME="$SF_HOME"
fi

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
# Holds the CI workflow against THIS list. It reads both files, which is the only way to see a layer that
# needs a surface and is selected by no job — two were, and both jobs reported green over them.
add "check_ci_coverage (every layer runs)" "res://tools/check_ci_coverage.gd"
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
# add_excl, not add_gl: this layer MEASURES TIME, and a timing layer cannot share the box. It compares a
# bulk fine-grid bake against the per-cell Callable path, and CI proved the comparison inverts under load —
# green on the display job (JOBS=1, runs alone) and red on the headless job (JOBS=4) on the SAME commit,
# twice, with bulk 2.2% then 8.2% slower where it is 12% FASTER on an idle box under both renderers. The
# advantage is memory bandwidth the contending processes were eating; nothing about the code changed.
# `check_frametime` already carries this verb for the same reason, and its own docstring records the effect:
# a still frame costs one refresh interval idle and 2.4x that with five Godot processes beside it.
add_excl "check_dig_hitch (friction)"   "res://tools/check_dig_hitch.gd"
# Headless on purpose, unlike its neighbour: this one compares the baker's CPU-side bytes rather than a
# texture read back from the driver, so it is the same test in both and belongs in CI.
add "check_progressive_bake (#17)"    "res://tools/check_progressive_bake.gd"
add "check_fall"                      "res://tools/check_fall.gd"
add "check_climb"                     "res://tools/check_climb.gd"
add "check_saveload"                  "res://tools/check_saveload.gd"
add "check_settings"                  "res://tools/check_settings.gd"
add "check_water_audio (L3 sound)"    "res://tools/check_water_audio.gd"
add "check_score (the descent)"       "res://tools/check_score.gd"
add "check_scan (sonar's colour)"     "res://tools/check_scan.gd"
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
add "check_vein_guard (rock only)"    "res://tools/check_vein_guard.gd"
add "check_head (stand it on it)"     "res://tools/check_head.gd"
add "check_bazaar_ruin (it has art)"  "res://tools/check_bazaar_ruin.gd"
add "check_draw_cull (offscreen)"     "res://tools/check_draw_cull.gd"
add_gl "check_opening (no dead space)" "res://tools/check_opening.gd"
add_gl "check_underground (lit rock)"  "res://tools/check_underground.gd"
add_gl "check_water_reads (fluid)"     "res://tools/check_water_reads.gd"
# REGISTERED 2026-08-18, ON THE CONDITION THIS NOTE ITSELF SET: "register it the day it passes." It was
# unregistered while 6a was open, because a layer that fails every run by design catches no regression and
# trains everyone to skim past the summary. The floor never moved to make this happen; it is 75% today and
# it was 75% then. What changed is the picture.
#
#   cue                       tooth OFF    tooth ON     floor
#   pooled VALUE                   51%         70%        --
#   pooled GRAIN                   61%         87%        75%
#   plain interior ON GRAIN        53%         86%        75%
#   plain BOUNDARY ON GRAIN        90%         95%        75%
#   layer exit                       1           0
#
# Four runs on the fixed tree: VALUE 70/70/70, GRAIN 88/87/87, CHROMA 94/94/94, interior 66/66/66 on value.
# The OFF column is a temporary knockout of rock_tooth.gdshader's two amplitudes -- never a shipped switch,
# same rule that removed SF_DEAD_HORIZ_ONLY -- and it reproduces the recorded pre-tooth pooled figures (50%
# value, 62% grain), which is what proves this configuration is the one that produced them. So the layer has
# a demonstrated red state and is not merely green.
#
# 6a IS CLOSED ON MEASUREMENT AND NOT ON PERCEPTION, and this layer cannot tell the difference. Rock's patch
# grain is 3.01 against air's 1.65 at a median luma of 11; a statistic can separate at 86% on a difference an
# eye cannot use. The blind vision tester is the instrument that rules on the ticket. What this gate buys is
# narrower and still worth having: the renderer encodes the distinction TODAY, and if that stops being true
# the suite says so.
#
# check_contact_edge (6b) is unregistered for the SAME reason and on the same terms:
#   bash tools/with_machine.sh --script res://tools/check_contact_edge.gd
#
# CURRENT READING (generated world, repaired capture geometry, three pooled viewpoints). 6b PASSES, and
# for the first time every arm is non-vacuous, so the per-orientation numbers are reportable:
#   detectability 86%   polarity 95%      floor 75% for both, and the floor did not move
#   rock TOP (lit lip)     n=75  step 13.09  polarity 100%
#   rock UNDER (ceiling)   n=65  step  6.47  polarity  92%
#   rock SIDE (wall)       n=75  step  8.16  polarity  92%
#   against a rock-interior texture of 1.8
# Three clean runs: detect 86 / 85 / 86, polarity 95 / 95 / 95, arm sizes identical every run. The margin is
# 10-11 points, not the ONE point the single-viewpoint reading cleared by -- pooling did not merely raise the
# number, it made the gate sound. Positive control, side mutant on the pooled fixture: SIDE step 8.16 -> 10.99
# and RED rock SIDE +1:68 +5:65 +9:60 +17:40, a decay curve on the rock side of side faces and nowhere else.
#
# SO THE QUESTION THIS LAYER WAS BUILT TO ASK IS ANSWERED, AND THE ANSWER IS THE OPPOSITE OF THE PREMISE.
# A rock/air contact IS visible, in all three orientations, at 86% against a 75% floor. The lane began from
# "the contact carries very nearly no information"; that was an instrument reading its own interior.
#
# THAT MECHANICAL BLOCKER EXPIRED AND THE NUMBERS ABOVE ARE WITHDRAWN -- c1, 2026-08-18.
#
# This note said check_contact_edge could not be registered because it reads FineTerrain._side_mutant_cells,
# from the SF_SIDE_MUTANT patch directive 0031 keeps unmerged. There is nothing left to decouple:
#   grep -nE "mutant|_side_|SF_" tools/check_contact_edge.gd   -> empty
#   grep -n  "_side_mutant_cells" scenes/fine_terrain.gd       -> empty
# The coupling came off with the patch (3df923c) and directive 0031 still holds. A blocker made of text.
#
# THE 86%/95% ABOVE WAS NEVER TRUE OF main. That reading came from the peer's branch, where c6f23b8's
# projection repair had been applied; it never reached this file -- absent from its own git log -- so main
# was still running `(face - cam) * zoom + image_size * 0.5` and reproduced the WITHDRAWN numbers on demand,
# 51% with steps 1.26-4.49. Repaired and pooled across three standings in 3b161b6: detectability 95/95/95,
# polarity 98/97/97, edge step median 10.4 against a flat-rock step of 1.5, 116 faces against a floor of 40.
#
# REGISTERED once the rationale was corrected rather than merely noticed. The layer credited
# TerrainPainter._draw_edge_ao for the contact it measures and that pass does not reach the frame it judges:
# it draws into the COARSE bake at z=-10 under fine_terrain's alpha 255 at z=-9. Liveness control on the
# coarse fill -- 7398 magenta pixels at the surface, ZERO underground. c2 then mutated _draw_edge_ao ALONE
# and ran it both ways, which is the part that matters: surface 621 unpatched against 4741 patched, and
# underground 7098 against 7082 -- minus sixteen, i.e. nothing. The pass puts ZERO pixels on screen
# underground. Knocking it out leaves this layer byte-identical.
#
# What it actually measures is the rock-versus-back-wall MATERIAL step, and the numbers were always sound --
# it was the prose that was wrong. Corrected at the head of check_contact_edge.gd before this line moved.
#
# Red states, demonstrated rather than assumed: the broken lens fails it at 51%; the non-vacuity floor fires
# at 33 faces against 40 and refuses to report; and it moves 95% -> 91% with the rock tooth removed, so it is
# sensitive to the renderer rather than merely stable.
#
# EVERYTHING THIS NOTE PREVIOUSLY REPORTED IS WITHDRAWN, AND SO IS THE THEORY IT USED TO EXPLAIN ITSELF.
# It has now been wrong twice in opposite directions, and the second correction voids the first:
#   1st  "detectability 52%, polarity 51% ... the contact carries very nearly no information at all"
#   2nd  TOP n=60 step 3.71 62% / UNDER n=63 step 3.01 62% / SIDE n=70 step 1.38 57%
#
# Both were taken through a broken lens. This project renders the canvas at 1280x720 and composites it 1.5x
# into the 1920x1080 framebuffer that get_texture().get_image() returns; the fixture projected world to
# pixel by hand as though those were one space, so a face at offset D from the camera centre was sampled at
# the pixel belonging to the world point at 2/3 D -- always inboard, toward the middle of the view, where
# rock is most ordinary. An instrument asking whether an EDGE reads was handed the interior beside it, which
# is precisely why SIDE appeared to "step BELOW the material own texture": it was interior rock compared
# against interior rock. Repaired with get_final_transform() * get_canvas_transform().
#
# THE EXPLANATION WAS WRONG TOO, AND THAT IS THE PART WORTH KEEPING. The 2nd reading argued that pooled
# polarity is invalid for this subject -- that _draw_edge_ao and _sky_form are a KEY LIGHT, so a perfect one
# scores ~50% on a pooled measure BY CONSTRUCTION, and the number was "not small, it was CANCELLED". Clean,
# plausible, checkable -- and the repaired measurement refutes it. Pooled polarity is 91%, and the UNDER arm,
# the one the theory said must run dark, reads 81% rock-brighter. Nothing was cancelling. A mechanism was
# built to explain an artifact, and it was convincing enough that it nearly justified replacing the
# statistic. A theory that explains a broken instrument is worse than no theory, because it makes the
# instrument look understood.
#
# REMOVED, per directive 0027: this note used to assert that "sides are the majority of contacts in a dug
# world". The fixture MANUFACTURES its orientation mix by carving a chamber and a gallery, so it cannot
# establish how often anything occurs in a world a player actually digs. It never could, at any reading.
#
# Correcting it here because a correction that lives only where it was noticed is compliance rather than a
# correction — a reader greps the harness, not somebody's tracelog. (c2 made the same catch against their
# own docs at the same hour, from the other direction.)
#
# Same rule as above — the floor does not move, and the layer joins the suite the day the picture clears it
# rather than the day the bar is lowered to meet the picture.
# add_gl and NOT add_excl: it renders every item icon and compares silhouettes and CIELab means. Contention
# changes how LONG that takes and not one pixel of what comes back, and exclusivity is the scheduler's most
# expensive favour — it is for layers whose ANSWER is a duration. This one's answer is a shape.
add_gl "check_rock_reads (rock vs void)" "res://tools/check_rock_reads.gd"
add_gl "check_contact_edge (rock meets air)" "res://tools/check_contact_edge.gd"
# TR-02: dirt and stone have to be different MATERIALS, not one material in two colours. Registered only
# once it passed, the way check_rock_reads was held out through 6a — a layer that is red on arrival is a
# ticket with a runner attached.
#
# Reads a controlled dirt->stone cross-section: mirrored window pairs matched on lamp-distance and depth,
# pooled over three independent rig placements, judged on STRUCTURE with colour removed (grain as a
# coefficient of variation, because the fine layer applies grain multiplicatively and raw std would
# separate the materials on brightness while printing GRAIN over it). Four arms, three of which exist to
# invalidate the fourth: a NULL rig with the same material both sides, a BASELINE with stone's grammar
# flattened, and the treatment with the tooth pass off.
#
# Verdict cues DISQUALIFY THEMSELVES: any cue that separates the null rig above the ceiling is dropped by
# rule. ANISO currently reads 80% on the null and is excluded — the per-grammar seam DIRECTION does not
# reach the frame, which is the multiplicative constraint at the head of fine_terrain.gd costing the half
# of the grammar it costs most.
#
# Reads (3 runs, stable): structure 86/86/86, colour control 93, null 53/53/51, baseline 61/63/61.
# Proved red by knockout: setting stone.tres grammar = 0 drops structure to 63% and the layer FAILS.
add_gl "check_material_grammar (dirt vs stone)" "res://tools/check_material_grammar.gd"
add_gl "check_item_reads (icons)"      "res://tools/check_item_reads.gd"
# Named for what it asserts everywhere, which is a RATIO — a dig may cost a few quiet frames, never twenty.
# It read "120fps" for its whole life and never once asserted 8.33ms; that absolute now exists, but only on
# hardware someone has named with SF_PERF_HOST, and a layer name cannot say "sometimes".
add_excl "check_frametime (hitch+budget)" "res://tools/check_frametime.gd"
add "check_stride (the run)"          "res://tools/check_stride.gd"
add "check_tells (hollow rock)"       "res://tools/check_tells.gd"
add "check_controls"                  "res://tools/check_controls.gd"
add "check_input_deafness (shutter)"  "res://tools/check_input_deafness.gd"
add "check_seam_flood (same picture)" "res://tools/check_seam_flood.gd"
add "check_paint_terms (per-texel)" "res://tools/check_paint_terms.gd"
# A pure source scan — no scene, no display, no save. It reads scenes/ and src/ for fields the game
# recomputes every frame and tools/ for fixtures that write one, which is the class that put ten menu
# captures of a counter nobody was standing at into the archive.
add "check_posed_fields (poses hold)" "res://tools/check_posed_fields.gd"
add "check_casing_light (machines lit)" "res://tools/check_casing_light.gd"
add "check_status_reads (every state)" "res://tools/check_status_reads.gd"
# add_gl: its whole answer is pixels. check_status_reads asks whether the STATUS LAMP names the state and
# check_casing_light asks whether a casing has a top face — neither one ever asks the question a player
# actually asks from across a room, which is whether the HARDWARE looks like it is running. That question
# has no headless form; the light pool it measures is drawn, not modelled.
add_gl "check_machine_state (running reads)" "res://tools/check_machine_state.gd"
# add_gl for the same reason as its sibling, and one more: it measures OCCUPANCY, and the dummy renderer
# occupies nothing. Twenty empty masks are perfectly identical, which is the one input that would make this
# layer's central assertion pass for the worst possible reason.
add_gl "check_machine_identity (which box)" "res://tools/check_machine_identity.gd"
# add_gl: `check_grapple` scores what the rope DOES and every number in it is a velocity; this one scores
# what the rope LOOKS like, and none of its numbers exist without a surface to draw on.
#
# ...AND add_excl, WHICH IS NOT A TIMING CLAIM. This layer went red on 2 of 4 sweeps and green on every
# standalone run of the same commit, which is the worst shape a layer has: an intermittent red that lands
# on whoever's change happens to be in the tree. Measured rather than reasoned about — twelve concurrent
# copies of it, five failed, all five on the same assertion:
#
#   a slack rope and a taut one are different pictures (4410..4604 px vs a 2845..4765 px clock baseline)
#   the same three runs, alone:                        (4622..4748 px vs a    1..4    px clock baseline)
#
# **THE SIGNAL IS STABLE AND THE CONTROL IS NOT.** ~4400-4750 px of rope difference either way; the noise
# floor it must clear goes from THREE pixels to four THOUSAND. That floor is two untouched captures
# differenced, and the world's animation advances on `delta` — on wall time — while the fixture counts
# frames between them. Contended, far more animation phase elapses per frame, and the layer's own estimate
# of "how much moves when nothing is asked to move" grows until it swallows a signal that never moved.
# A control that fails for the same reason as its subject says nothing; this one is worse, because it
# fails HARDER than its subject and takes the assertion down with it.
#
# The other observed contention red — `the renderer's cursor is where the fixture put it (415..435 px off)`
# on two sweeps — is NOT explained. It did not reproduce in twelve concurrent runs, the mouse warp lands at
# 1.0 px with `window_is_focused=false` so it is not focus, and the camera-lerp story is two orders of
# magnitude short of the number (and `main.gd:731` snaps rather than lerps the large jumps that could
# produce it). **`add_excl` removes the condition, not the cause**, and that is worth saying out loud
# because the layer will now be green without anybody having found out why it was not.
add_excl "check_grapple_reads (tool not geometry)" "res://tools/check_grapple_reads.gd"
add "check_tool_text (says=does)" "res://tools/check_tool_text.gd"
add "check_binding_text (keys=jobs)" "res://tools/check_binding_text.gd"
add "check_gamepad (playable on a pad)" "res://tools/check_gamepad.gd"
# add_gl: it measures the boxes the HUD actually DREW, and the dummy renderer draws none of them — so
# headless every state reports zero panels and every overlap assertion passes on an empty screen.
add_gl "check_hud_layout (no collisions)" "res://tools/check_hud_layout.gd"
add "check_pack_layout"               "res://tools/check_pack_layout.gd"
add "check_pixel_snap"                "res://tools/check_pixel_snap.gd"
# add_gl, and the other half of check_pixel_snap. That layer proves snap_to_pixel is correct AS A FUNCTION;
# its docstring then claimed the end-to-end frame-diff lived in tools/capture_pixel_snap.gd, which has never
# existed in any object in this repository. So nothing checked that correct snap arithmetic reaches the
# framebuffer. This renders two frames and diffs them, which the dummy renderer cannot do at all.
add_gl "check_snap_frame (snap on screen)" "res://tools/check_snap_frame.gd"

# THE BAKE MUST BE RE-DRAWN, NOT RE-PROCESSED. The coarse terrain bake retains its render target between
# updates, and while it also inherited the WorldEnvironment the colour grade was re-applied to those stored
# pixels on every dig -- saturation compounding 1.18^n until the walked surface line read as a neon band
# across the whole frame. Eighty layers passed that frame, because every one of them photographs a freshly
# booted world and 1.18^1 is not a defect: the population excluded the state the bug lives in. This layer
# digs first and asserts second, which is why it is registered here rather than folded into a frame check.
add_gl "check_bake_idempotent (bake holds)" "res://tools/check_bake_idempotent.gd"
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
add "check_depth_reads (how deep)"    "res://tools/check_depth_reads.gd"
add "check_pump (wind it up)"         "res://tools/check_pump.gd"
add "check_plunge (ride it down)"     "res://tools/check_plunge.gd"
add "check_aim (honest marker)"       "res://tools/check_aim.gd"
add "check_impact (a fall costs)"     "res://tools/check_impact.gd"
add "play-tests (scripted + friction)" "res://tools/play_tests.gd"

DECLARED="${#NAMES[@]}"

# SF_ONLY narrows the list. Everything downstream then talks about "selected of declared", never about
# "all", because a filtered sweep that printed the all-pass line would be a new way to claim coverage
# nobody ran — the exact bug this file was opened to fix.
if [ -n "${SF_ONLY:-}" ] || [ "${SF_GL_ONLY:-0}" = "1" ] || [ -n "${SF_NOT:-}" ]; then
	fn=(); fs=(); fg=(); fe=()
	i=0
	while [ "$i" -lt "$DECLARED" ]; do
		keep=1
		[ -n "${SF_ONLY:-}" ] && ! printf '%s' "${NAMES[$i]}" | grep -Eq -- "$SF_ONLY" && keep=0
		# SF_GL_ONLY reads the REGISTRATION, not a list of names. That is the whole point of it: the display
		# job used to name its four layers by hand, `add_gl` grew to six, and the two that arrived after the
		# list was written ran in NO ci job at all — they skip headless because they need a surface, and the
		# display job never selected them. A hand-kept list of the things that need special treatment is a
		# snapshot with an expiry date and nothing prints the date. Ask the runner instead.
		[ "${SF_GL_ONLY:-0}" = "1" ] && [ "${GLFLAG[$i]}" != "1" ] && keep=0
		# ...and SF_NOT is how a job states an exclusion OUT LOUD rather than by omitting a name from a list,
		# where the difference between "deliberately left out" and "forgotten" is invisible.
		[ -n "${SF_NOT:-}" ] && printf '%s' "${NAMES[$i]}" | grep -Eq -- "$SF_NOT" && keep=0
		if [ "$keep" = "1" ]; then
			fn+=("${NAMES[$i]}"); fs+=("${SCRIPTS[$i]}"); fg+=("${GLFLAG[$i]}"); fe+=("${EXCL[$i]}")
		fi
		i=$((i + 1))
	done
	NAMES=(${fn[@]+"${fn[@]}"}); SCRIPTS=(${fs[@]+"${fs[@]}"}); GLFLAG=(${fg[@]+"${fg[@]}"})
	EXCL=(${fe[@]+"${fe[@]}"})
	if [ "${#NAMES[@]}" -eq 0 ]; then
		echo "!! the filter (SF_ONLY='${SF_ONLY:-}' SF_GL_ONLY='${SF_GL_ONLY:-0}' SF_NOT='${SF_NOT:-}')" \
			"matched none of the $DECLARED layers — refusing to report a run of nothing"
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
# The ORIGINAL reason is now handled upstream and the history is worth keeping, because it explains why
# this lock is drawn tighter than the remaining hazard needs. Godot keys `user://` on the project NAME, so
# a git worktree did NOT isolate it: every checkout of Sinkforge on this machine read and wrote one
# ~/Library/Application Support/Godot/app_userdata/Sinkforge/, sharing one save slot and one set of test
# fixtures. That cost an afternoon on 2026-08-17, twice and in opposite directions: two concurrent sweeps
# each reported "THE SAVE SLOT WAS DELETED BY THE HARNESS", because the other one's `verify` had removed
# the planted marker mid-sweep. Both were false alarms — but the same collision had a quieter form, where a
# neighbour clobbers a fixture and a layer passes for a reason that has nothing to do with the code, and
# that one nobody would ever notice.
#
# The per-root HOME above ends that class: two worktrees now hold two namespaces and cannot see each
# other's fixtures at all. What the lock still buys is the thing isolation CANNOT give, and it is the
# reason not to relax it — a timing layer measures the box, not the directory, so `add_excl` is meaningless
# if another Godot process is running at the same time. Contention was worth 12% on `check_dig_hitch` and
# inverted its verdict. `mkdir` is the atomic primitive: it succeeds for exactly one caller.
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
	# See SELF_SUM. A runner that changed mid-flight produced a result from two different scripts.
	if [ "$SELF_SUM" != "unknown" ] && [ "$(cksum < "$0" 2>/dev/null || echo unknown)" != "$SELF_SUM" ]; then
		echo "!! THE RUNNER WAS EDITED WHILE THIS SWEEP WAS RUNNING — $0 changed between start and exit."
		echo "   bash resumes an edited script at its old byte offset, so part of this run came from one"
		echo "   version and part from another. WHATEVER THIS RUN REPORTED, IT IS NOT A RESULT. Re-run it."
		[ -n "${DIR:-}" ] && [ -w "${DIR:-}/summary.txt" ] \
			&& echo "!! THE RUNNER WAS EDITED MID-RUN — this is not a result, re-run it" >>"$DIR/summary.txt"
	fi
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
# WHICH TREE THIS RAN IN, printed because cwd is an UNMEASURED INPUT to every result this script produces
# and no result line has ever named it. Parallel work runs in separate git worktrees, and a
# `cd` that silently resets to the repo root makes a sweep report on somebody else's checkout while looking
# exactly like a normal green -- that is not hypothetical, it cost a false green on 2026-08-17. `pwd -P`
# resolves symlinks, and the branch is printed beside it because "which tree" and "which branch" are
# different questions and both have been wrong.
say "== Sinkforge harness (parallel, JOBS=$JOBS, layers=$total$subset, $mode, $strictness) =="
say "   tree: $(pwd -P)  branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')  head: $(git rev-parse --short HEAD 2>/dev/null || echo '?')"

# --- THE CLAIM FILE, shared in shape with tools/with_machine.sh. The lock used to say a pid and a tree
# and the waiter printed only the pid, so "waiting for the harness lock (held by pid 65489)" required a
# `ps` on another terminal to learn what was running and whether it was nearly done. A lock that makes you
# go and look is a lock that gets overridden. Four lines: pid, tree, what is running, when it started.
# Line 1 stays the pid and line 2 the tree because the stale-holder check is `head -1`; an owner file
# written by an older copy simply has no lines 3-4 and the reader leaves those fields out.
lock_claim_write() {
	printf '%s\n%s\n%s\n%s\n' "$$" "$ROOT" "${1:-?}" "$(date +%s)" >"$LOCK/owner"
}
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

# Take the machine-wide lock before anything touches user://. A run that was killed cannot release its own
# lock, so a holder whose pid is gone gets cleared rather than being allowed to wedge every future run —
# the cure must not be worse than the disease. SF_NO_LOCK=1 opts out for anyone who knows better.
if [ "${SF_NO_LOCK:-0}" != "1" ]; then
	waited=0
	while true; do
		if mkdir "$LOCK" 2>/dev/null; then
			lock_claim_write "the harness ($total layers, JOBS=$JOBS)"
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
			# Two durations, and they are different questions: how long THIS run has waited, and how long
			# the holder has held. Printing them as one number is how "held for 900s" got read as a wedged
			# lock when it was a long layer that started ten seconds ago.
			echo "!! refusing to run — $(lock_claim); this run waited ${waited}s"
			echo "   concurrently, because both results would then be worthless. SF_NO_LOCK=1 overrides."
			exit 5
		fi
		[ $((waited % 30)) -eq 0 ] && echo "  waiting for the harness lock — $(lock_claim) ..."
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
			# WRITTEN ASIDE AND RENAMED, because `>` CREATES THE FILE BEFORE ANYTHING IS IN IT and the
			# poller below accepts a mark on `-f` alone. That window is small and it is real: a passing layer
			# read in it yields an EMPTY `r`, which is not "0", so it takes the FAIL branch — and `%d` renders
			# the empty string as 0, so the run reports `FAIL 0s (exit 0)` for a layer whose own log says it
			# passed every assertion. Observed on `check_pack_layout` and reproduced exactly from an empty
			# mark. `mv` within one directory is atomic, so the reader now sees the mark absent or complete,
			# never half-born.
			printf '%d %d' "$?" "$((SECONDS - s))" >"$MARKS/$i.part" && mv "$MARKS/$i.part" "$MARKS/$i.done"
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
			read -r r el <"$MARKS/$i.done"
			# A MARK THAT DOES NOT PARSE IS THE HARNESS'S FAULT, AND IT MUST SAY SO IN ITS OWN NAME.
			# The atomic rename above removes the only known way to get here, so this should be unreachable —
			# which is exactly why it is worth keeping. The failure it replaces was silent: an empty `r` fell
			# through to the generic FAIL branch and `%d` printed it as 0, so a layer that passed everything was
			# reported `FAIL 0s (exit 0)` and anyone reading that would go and debug the layer. Fail closed, but
			# name the right defendant.
			if [ -z "$r" ]; then
				REPORTED[$i]=1
				done_count=$((done_count + 1))
				progressed=1
				say "$(printf '  [%2d/%2d] %-36s HARNESS FAULT — unreadable mark file, layer verdict UNKNOWN' \
					"$done_count" "$total" "${NAMES[$i]}")"
				fail=$((fail + 1))
				failed_names+=("${NAMES[$i]} (harness fault, not the layer)")
				i=$((i + 1))
				continue
			fi
			REPORTED[$i]=1
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
