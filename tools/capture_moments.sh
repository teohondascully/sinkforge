#!/usr/bin/env bash
# Milestone moment capture. Re-derived from `legacy/tools/capture_moments.gd`'s APPROACH -- scripted,
# fixed-frame, fixed-seed moment rendering -- and not from its code, which is 1,977 lines wired into the
# dead terminal economy (`docs/LEGACY_MIGRATION_MAP_2026-08-29.md` marks it SKIP-READ / worth re-deriving).
# `docs/DECISIONS_LEDGER.md` D0197.
#
#   tools/capture_moments.sh <slice-label> [output-dir]
#
# WHY THIS IS A SHELL SCRIPT AND NOT A GODOT TOOL. `tests/body/reveal_scene.gd` already owns every piece:
# the seeded world, the fixed camera (`--camera=`), the shutter (`--screenshot-tick=`/`--screenshot-out=`)
# and the blank-frame check D0190 added after that shutter was caught saving black PNGs and reporting
# success. A second Godot-side capture tool would be a second copy of all of it, free to drift. This drives
# the one that exists.
#
# THREE THINGS ARE HELD CONSTANT SO SHOTS ARE COMPARABLE ACROSS COMMITS, which is the only property that
# makes a before/after pair mean anything: the resolution (1920x1080, legacy's own), the camera (an explicit
# cell, never the body-follower), and the seed. Only the content is allowed to differ between milestones.
#
# NOT --headless. Legacy's own header states it and D0190 re-confirmed it here: the headless renderer is a
# dummy that saves blank frames. This fails closed on a blank capture rather than writing one.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

SLICE="${1:?usage: capture_moments.sh <slice-label> [output-dir]}"
OUT_DIR="${2:-docs/milestones}"
GODOT="${GODOT_BIN:-godot}"
SEED=20260826
SITE=reveal_test_dense
RES=1920x1080
# D0200. `BITE=n` pins the mining bite radius and stamps it into every filename, so the two halves of a
# bite before/after pair cannot be told apart only by which order they were taken in. Unset means "whatever
# the scene defaults to", which is what a milestone shot of the shipped build should be.
BITE="${BITE:-}"
BITE_ARG=""
BITE_TAG=""
if [ -n "$BITE" ]; then
	BITE_ARG="--bite=$BITE"
	BITE_TAG="_b${BITE}"
fi
# `TICKS=a,b,c` overrides the three capture ticks in MOMENTS order. A bite radius changes how fast the
# scripted shaft sinks, so a pair shot at one fixed tick needs a tick BOTH radii actually reach -- and the
# alternative (each half at its own tick) would compare two different moments and call it a before/after.
TICKS="${TICKS:-}"

SHA="$(git rev-parse --short HEAD)"
if ! git diff --quiet || ! git diff --cached --quiet; then
	# A shot is keyed to a commit; a shot taken over a dirty tree names a commit that cannot reproduce it.
	# Warn rather than refuse: during a slice the useful capture is often the uncommitted one, and the
	# caller is told exactly what the name will and will not mean.
	echo "capture_moments: WARNING - working tree is dirty; '$SHA' does not reproduce these frames" >&2
	SHA="${SHA}-dirty"
fi
mkdir -p "$OUT_DIR" || exit 1

# moment | extra scene args | capture tick
# `surface` is the world as a player first meets it. `delve` is the same seed after the scripted shaft has
# been sunk, framed so the whole descent is in one frame. `aim` is Slice 1's own subject: the reach ring,
# the reticle and a part-charged cell, caught mid-hold.
#
# THE ZOOMS ARE DERIVED FROM THE WORLD'S OWN WIDTH, and the basis is the BASE RENDER RESOLUTION, not the
# output resolution. `project.godot` renders 2D at 1280x720 and the window scales that up, so a camera at
# `zoom` shows `1280 / zoom` world pixels however large the PNG is. Getting this wrong is silent: an
# earlier version of this file divided 1920 by the zoom, framed every moment 1.5x tighter than intended,
# and produced a `delve` shot with the shaft and the body both outside the frame -- while still reporting
# 159 distinct colours, because a wall of textured clay is not a blank frame. Found by looking at the
# image and then printing the camera and body position, not by re-reading the arithmetic.
#
# These sites are 48 terrain cells wide, which is 192px, so zoom 6.5 (1280/6.5 = 197px) fills the frame
# with the whole world plus a small margin, with the camera on the middle column. `aim` goes tighter and
# accepts off-world background on one side: the body spawns one cell from the left wall and cannot be
# centred without it, and a 4px cell has to reach ~78 output px to read as a reticle at all.
MOMENTS=(
	"surface|--zoom=6.5 --camera=24,13|2"
	"delve|--mine-down --zoom=6.5 --camera=24,17|216"
	"aim|--mine-down --zoom=13.0 --camera=12,12|40"
)

fail=0
i=0
for entry in "${MOMENTS[@]}"; do
	name="${entry%%|*}"
	rest="${entry#*|}"
	args="${rest%%|*}"
	tick="${rest##*|}"
	# D0219. `delve`'s tick was 940, chosen when the bite radius default was 0 and the scripted shaft took
	# 991 ticks to reach its 24-cell target. At the shipped default of 2 the same run finishes at tick
	# **228** (measured, not estimated), so the shutter never fired and the moment silently wrote no file.
	# 216 is ~95% through the current run, matching where 940 sat in the old one.
	#
	# READ THIS BEFORE PAIRING TWO MILESTONES' `delve` SHOTS. They are only comparable if BITE and TICKS
	# were the same on both, and across the bite default change they were not: Slice 1's delve is bite 0 at
	# tick 940, Slice 2's is bite 2 at tick 216. Those are two different worlds at two different moments,
	# and putting them side by side would attribute the difference to whatever the newer slice changed.
	# For a real cross-milestone pair, pin both explicitly -- `BITE=0 TICKS=2,940,40` -- and re-capture the
	# OLDER commit too, which is what the filename's SHA exists to make possible.
	if [ -n "$TICKS" ]; then
		tick="$(printf '%s' "$TICKS" | cut -d, -f$((i + 1)))"
	fi
	png="$OUT_DIR/${SLICE}_${name}${BITE_TAG}_${SHA}.png"
	# shellcheck disable=SC2086
	out="$("$GODOT" --resolution "$RES" --path . tests/body/reveal_scene.tscn -- \
		--site="$SITE" --seed="$SEED" $args $BITE_ARG \
		--screenshot-tick="$tick" --screenshot-out="$png" 2>&1)"
	if printf '%s\n' "$out" | grep -q "is blank or"; then
		echo "capture_moments: FAIL - $name captured a blank frame; not counting it as a shot" >&2
		printf '%s\n' "$out" | grep "distinct colour" >&2
		fail=1
		continue
	fi
	if [ ! -s "$png" ]; then
		echo "capture_moments: FAIL - $name wrote no file at $png" >&2
		echo "capture_moments:        most likely the run ENDED before tick $tick -- a scripted --mine-down" >&2
		echo "capture_moments:        run quits when it reaches its target, and how fast it gets there" >&2
		echo "capture_moments:        depends on the bite radius. Re-run with TICKS= to pin a reachable tick." >&2
		fail=1
		continue
	fi
	colours="$(printf '%s\n' "$out" | grep -o "capture has [0-9]* distinct colours" | grep -o "[0-9]*" | head -1)"
	echo "capture_moments: $name -> $png (${colours:-?} distinct colours, tick $tick, bite ${BITE:-default})"
	i=$((i + 1))
done

if [ "$fail" -eq 0 ]; then
	echo "capture_moments: all moments captured at $SHA"
fi
exit $fail
