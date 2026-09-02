#!/bin/bash
# HUNT-F004: check_working_freshness.py missing-file reproduction.
#
# tools/layer_lint/check_working_freshness.py:29-31 at the pin:
#   if not WORKING_MD.is_file():
#       print("check_working_freshness: docs/WORKING.md does not exist -- nothing to check.")
#       return 0
#
# A missing docs/WORKING.md produces "nothing to check" and exit 0 (blocking
# gate green on absent subject). A missing Last-updated line DOES fail (line
# 34-36); only whole-file absence passes.
#
# This script runs the tool in a worktree at the pin with docs/WORKING.md
# temporarily renamed, capturing the "nothing to check" output and exit 0.
#
# Usage: bash repro/hunt-f004-working-freshness.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f004-working-freshness.txt}"
REPO="/Users/thondascully/Projects/sinkforge"
SCRATCH="/tmp/m1-hunt-f004"

rm -rf "$SCRATCH"
git -C "$REPO" worktree add "$SCRATCH" 70f8a785 >/dev/null 2>&1

cd "$SCRATCH"

# Temporarily rename WORKING.md to simulate its absence.
mv docs/WORKING.md docs/WORKING.md.bak

echo "=== Running check_working_freshness.py with docs/WORKING.md absent ===" > "$OUT"
python3 tools/layer_lint/check_working_freshness.py >> "$OUT" 2>&1
RC=$?
echo "exit code: $RC" >> "$OUT"
echo "---" >> "$OUT"

# Restore the file.
mv docs/WORKING.md.bak docs/WORKING.md

# Also show the normal (file present) behavior for contrast.
echo "=== Running check_working_freshness.py with docs/WORKING.md present ===" >> "$OUT"
python3 tools/layer_lint/check_working_freshness.py >> "$OUT" 2>&1
RC2=$?
echo "exit code: $RC2" >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
echo "Absent-file exit: $RC, present-file exit: $RC2" >&2

# Clean up worktree
git -C "$REPO" worktree remove --force "$SCRATCH" >/dev/null 2>&1
