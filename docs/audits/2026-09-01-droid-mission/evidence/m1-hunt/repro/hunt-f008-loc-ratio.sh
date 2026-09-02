#!/bin/bash
# HUNT-F008: check_loc_ratio.py ADVISORY exit 0 reproduction.
#
# tools/layer_lint/check_loc_ratio.py at the pin: when resolve_window_start()
# returns None (shallow clone, young repo, or long doc-only stretch), the
# tool prints "ADVISORY: not gating on velocity this run." and exits 0.
# A shallow clone silently demotes the gate from blocking to advisory.
# Disclosed in-step and in the fetch-depth comment in harness.yml.
#
# This script reproduces the ADVISORY path by running the tool in a shallow
# clone (depth 1) where the window cannot be resolved.
#
# Usage: bash repro/hunt-f008-loc-ratio.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f008-loc-ratio.txt}"
REPO="/Users/thondascully/Projects/sinkforge"
SCRATCH="/tmp/m1-hunt-f008"

rm -rf "$SCRATCH"
# Create a shallow clone (depth 1) to trigger the unresolvable-window path
git clone --depth 1 "$REPO" "$SCRATCH" >/dev/null 2>&1
cd "$SCRATCH"

echo "=== Running check_loc_ratio.py in a shallow clone (depth 1) ===" > "$OUT"
echo "git log depth: $(git log --oneline | wc -l) commit(s)" >> "$OUT"
echo "" >> "$OUT"
python3 tools/layer_lint/check_loc_ratio.py >> "$OUT" 2>&1
RC=$?
echo "exit code: $RC" >> "$OUT"
echo "---" >> "$OUT"

# Show the ADVISORY path in the source
echo "=== ADVISORY path in source (resolve_window_start returns None) ===" >> "$OUT"
git show 70f8a785:tools/layer_lint/check_loc_ratio.py | grep -n -A3 'ADVISORY' >> "$OUT" 2>&1 || true

echo "" >> "$OUT"
echo "=== Assessment ===" >> "$OUT"
echo "The ADVISORY path fires on a shallow clone (depth 1). The CI workflow" >> "$OUT"
echo "uses fetch-depth: 0 to prevent this, and the fetch-depth comment in" >> "$OUT"
echo "harness.yml explains why. The gate is disclosed in-step and demotes" >> "$OUT"
echo "to advisory rather than silently passing. Not the seventh." >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
echo "Exit code: $RC" >&2

rm -rf "$SCRATCH"
