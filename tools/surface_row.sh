#!/usr/bin/env bash
# Prints the world's SURFACE ROW — the first row of rock, which is not row 0.
#
#   SURFACE_ROW="$(tools/surface_row.sh)" || exit 1
#
# P017 (`docs/DECISIONS_LEDGER.md` D0292) put twenty metres of air above the rock, so every tool that
# names a camera row in cells names a row RELATIVE TO THE SURFACE. Two of them did not, and both failed
# the same way: `tools/capture_moments.sh`'s four moments all pointed into the sky and captured blank
# frames, and `tools/check_headed_boot.sh`'s `--camera=24,4` did the same and turned CI red with "could
# not read a distinct-colour count", which says nothing about what actually moved.
#
# ONE DERIVATION, HERE, rather than the same two greps copied into each caller — the second copy is where
# they drift, and a camera that has drifted off the world reports "blank frame" rather than "wrong row".
#
# IT FAILS CLOSED. A missing constant exits non-zero and prints nothing, because `$(( ))` on an empty
# string is zero — a perfectly plausible surface row that would put every camera back in the sky without
# saying so. `docs/DECISIONS_LEDGER.md`'s `existence-probe-has-no-witness` rule: a bare exit code reports
# ABSENT for every failure including your own quoting, so this says which constant it could not read.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEN="$ROOT/sim/terrain_gen/shaft_generator.gd"

read_const() {
	local name="$1"
	local value
	value="$(grep -oE "^const ${name}: int = [0-9]+" "$GEN" | grep -oE '[0-9]+$')"
	if [ -z "$value" ]; then
		echo "surface_row: FAIL - could not read '$name' out of $GEN" >&2
		return 1
	fi
	printf '%s' "$value"
}

SKY_M="$(read_const SKY_ROWS)" || exit 1
CPM="$(read_const TERRAIN_CELLS_PER_METER)" || exit 1
printf '%s\n' "$(( SKY_M * CPM ))"
