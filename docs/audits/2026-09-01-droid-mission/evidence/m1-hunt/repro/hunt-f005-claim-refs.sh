#!/bin/bash
# HUNT-F005: check_claim_references.py zero-corpus VOID reproduction.
#
# tools/layer_lint/check_claim_references.py at the pin: the CI step
# "Every scenario and harness layer names a claim" (harness.yml:164-165)
# runs this tool. When the corpus is empty (scenarios/ has only a README,
# harness/**/*.gd has zero files with `func run(`), the tool prints
# "VOID -- zero scenarios and zero harness check-layers exist" and exits 0
# (deliberate, D0146). The CI step is green over a zero corpus.
#
# This script runs the tool in a worktree at the pin and captures the output.
#
# Usage: bash repro/hunt-f005-claim-refs.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f005-claim-refs.txt}"
REPO="/Users/thondascully/Projects/sinkforge"
SCRATCH="/tmp/m1-hunt-f005"

rm -rf "$SCRATCH"
git -C "$REPO" worktree add "$SCRATCH" 70f8a785 >/dev/null 2>&1

cd "$SCRATCH"

echo "=== Running check_claim_references.py at the pin ===" > "$OUT"
python3 tools/layer_lint/check_claim_references.py >> "$OUT" 2>&1
RC=$?
echo "exit code: $RC" >> "$OUT"
echo "---" >> "$OUT"

# Also show the population: scenarios/ and harness/**/*.gd with func run(
echo "=== Population derivation ===" >> "$OUT"
echo "scenarios/*.yaml:" >> "$OUT"
ls scenarios/*.yaml 2>/dev/null >> "$OUT" || echo "(none)" >> "$OUT"
echo "harness/**/*.gd with 'func run(':" >> "$OUT"
grep -rl '^func run(' harness/ 2>/dev/null >> "$OUT" || echo "(none)" >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
echo "Exit code: $RC (VOID exit 0 on zero corpus)" >&2

git -C "$REPO" worktree remove --force "$SCRATCH" >/dev/null 2>&1
