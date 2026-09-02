#!/bin/bash
# HUNT-F001: MUTSWEEP-ZEROFLOOR reproduction.
#
# The CI "Gate mutation tests" step (.github/workflows/harness.yml:190-204 at the
# pin) loops over `find tools -name 'test_*.py' | sort` and prints
# "Ran $count gate mutation test file(s)." with NO zero-count floor. If the glob
# ever matches nothing (rename, restructure, find typo), the step stays green
# while every mutation test stops enforcing.
#
# This script reproduces the empty-glob case in scratch: it creates a directory
# with an empty tools/ tree, runs the EXACT step body (set -e preserved), and
# captures the output and exit code.
#
# Usage: bash repro/hunt-f001-mutsweep.sh [output-file]
# Default output: raw/hunt-f001-mutsweep.txt (relative to the pack root)

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f001-mutsweep.txt}"
SCRATCH="/tmp/m1-hunt-f001"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/tools"
cd "$SCRATCH"

# The EXACT step body from harness.yml:191-204, with set -e preserved.
# The only change is the working directory (scratch with an empty tools/ tree).
{
    set -e
    count=0
    echo "gate mutation test timing report" > gate_timing.txt
    while IFS= read -r f; do
        echo "=== $f ==="
        t0=$(date +%s)
        python3 "$f"
        echo "$(( $(date +%s) - t0 )) $f" >> gate_timing.txt
        count=$((count + 1))
    done < <(find tools -name 'test_*.py' | sort)
    echo "Ran $count gate mutation test file(s)."
    echo "slowest gate tests:"
    sort -rn -k1 gate_timing.txt | head -5
} > "$OUT" 2>&1
RC=$?

echo "exit code: $RC" >> "$OUT"
echo "---" >> "$OUT"
echo "Reproduction complete. Output saved to $OUT" >&2
echo "Key line:" >&2
grep 'Ran.*gate mutation' "$OUT" >&2 || true
echo "Exit code: $RC" >&2

# Clean up scratch
rm -rf "$SCRATCH"
