#!/bin/bash
# HUNT-F006: .githooks/pre-commit base-namespace silent no-op reproduction.
#
# .githooks/pre-commit at the pin (lines ~58-70): the base-namespace block is
# behind `[ -x tools/check_base_namespace.sh ] || [ -r tools/check_base_namespace.sh ]`.
# If check_base_namespace.sh goes missing, the block silently no-ops (the
# D0117/D0119 hole structurally retained). Local-only; CI covers the check
# directly via its own step.
#
# This script reproduces the silent no-op by running the pre-commit hook's
# base-namespace block in scratch with check_base_namespace.sh missing.
#
# Usage: bash repro/hunt-f006-pre-commit.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f006-pre-commit.txt}"
REPO="/Users/thondascully/Projects/sinkforge"
SCRATCH="/tmp/m1-hunt-f006"

rm -rf "$SCRATCH"
git -C "$REPO" worktree add "$SCRATCH" 70f8a785 >/dev/null 2>&1

cd "$SCRATCH"

echo "=== .githooks/pre-commit base-namespace block (lines 58-70 at pin) ===" > "$OUT"
# Show the actual code
git show 70f8a785:.githooks/pre-commit | sed -n '58,70p' >> "$OUT" 2>&1 || true
# The actual line numbers may differ; grep for the block
echo "---" >> "$OUT"

# Reproduce: simulate a .gd file staged and check_base_namespace.sh missing.
# The block is:
#   if git diff --cached --name-only --diff-filter=ACM -- '*.gd' | grep -q .; then
#       if [ -x tools/check_base_namespace.sh ] || [ -r tools/check_base_namespace.sh ]; then
#           if ! sh tools/check_base_namespace.sh ...
#               exit 1
#           fi
#       fi
#   fi
# If check_base_namespace.sh is missing, the inner [ -x ... ] || [ -r ... ] is false,
# and the entire block is skipped. The hook continues to the next section.

echo "=== Reproduction: check_base_namespace.sh present ===" >> "$OUT"
if [ -x tools/check_base_namespace.sh ] || [ -r tools/check_base_namespace.sh ]; then
    echo "Block ACTIVE: check_base_namespace.sh found, guard would fire" >> "$OUT"
else
    echo "Block SKIPPED: check_base_namespace.sh missing, guard silently no-ops" >> "$OUT"
fi

echo "---" >> "$OUT"
echo "=== Reproduction: check_base_namespace.sh missing (simulated) ===" >> "$OUT"
# Temporarily rename the file
mv tools/check_base_namespace.sh tools/check_base_namespace.sh.bak
if [ -x tools/check_base_namespace.sh ] || [ -r tools/check_base_namespace.sh ]; then
    echo "Block ACTIVE: check_base_namespace.sh found, guard would fire" >> "$OUT"
else
    echo "Block SKIPPED: check_base_namespace.sh missing, guard silently no-ops" >> "$OUT"
    echo "The hook continues past this block with no warning." >> "$OUT"
fi
# Restore
mv tools/check_base_namespace.sh.bak tools/check_base_namespace.sh

echo "---" >> "$OUT"
echo "=== CI coverage (separate step in harness.yml) ===" >> "$OUT"
git show 70f8a785:.github/workflows/harness.yml | grep -A1 'check_base_namespace' >> "$OUT" 2>&1 || true

echo "Reproduction complete. Output saved to $OUT" >&2

git -C "$REPO" worktree remove --force "$SCRATCH" >/dev/null 2>&1
