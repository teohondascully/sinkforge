#!/bin/bash
# HUNT-F007: PASS-(vacuously) exit-0 gates group reproduction.
#
# Multiple gate tools print "PASS (vacuously)" and exit 0 when their policed
# tree is empty: layer_lint.py, no_engine_imports.py, check_size_limits.py,
# check_coordinate_naming.py, schema_validator.py. These are loud in logs
# (print the word "vacuously"), require the entire policed tree to vanish, and
# layer_lint has the zero-edge control (exit 2 on check_edges_were_resolved).
# Low risk; not a new finding (the terrain doc says "do not re-flag as new").
#
# This script verifies each vacuously path exists at the pin by extracting the
# relevant code lines.
#
# Usage: bash repro/hunt-f007-vacuously-group.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f007-vacuously-group.txt}"
REPO="/Users/thondascully/Projects/sinkforge"

cd "$REPO"

echo "=== Vacuously-PASS paths at the pin (70f8a785) ===" > "$OUT"
echo "" >> "$OUT"

echo "--- layer_lint.py ---" >> "$OUT"
git show 70f8a785:tools/layer_lint/layer_lint.py | grep -n 'vacuously\|nothing to check' >> "$OUT" 2>&1 || echo "(no match)" >> "$OUT"
echo "" >> "$OUT"

echo "--- no_engine_imports.py ---" >> "$OUT"
git show 70f8a785:tools/layer_lint/no_engine_imports.py | grep -n 'vacuously\|nothing to check' >> "$OUT" 2>&1 || echo "(no match)" >> "$OUT"
echo "" >> "$OUT"

echo "--- check_size_limits.py ---" >> "$OUT"
git show 70f8a785:tools/layer_lint/check_size_limits.py | grep -n 'vacuously\|nothing to check' >> "$OUT" 2>&1 || echo "(no match)" >> "$OUT"
echo "" >> "$OUT"

echo "--- check_coordinate_naming.py ---" >> "$OUT"
git show 70f8a785:tools/layer_lint/check_coordinate_naming.py | grep -n 'vacuously\|nothing to check' >> "$OUT" 2>&1 || echo "(no match)" >> "$OUT"
echo "" >> "$OUT"

echo "--- schema_validator.py ---" >> "$OUT"
git show 70f8a785:tools/schema_validator/schema_validator.py | grep -n 'vacuously\|nothing to check' >> "$OUT" 2>&1 || echo "(no match)" >> "$OUT"
echo "" >> "$OUT"

echo "=== layer_lint.py zero-edge control (check_edges_were_resolved, exit 2) ===" >> "$OUT"
git show 70f8a785:tools/layer_lint/layer_lint.py | grep -n 'check_edges_were_resolved\|exit 2' >> "$OUT" 2>&1 || true

echo "" >> "$OUT"
echo "=== Assessment ===" >> "$OUT"
echo "All five tools have 'PASS (vacuously)' paths that fire when their policed" >> "$OUT"
echo "tree is empty. These require the ENTIRE policed tree to vanish (all .gd" >> "$OUT"
echo "files under core/+sim/ deleted, or data/ removed, etc). layer_lint.py" >> "$OUT"
echo "additionally has check_edges_were_resolved which exits 2 on zero edges" >> "$OUT"
echo "(the D0224 guard). These are loud (print 'vacuously'), disclosed, and" >> "$OUT"
echo "low-risk. Not the seventh; not a new finding." >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
