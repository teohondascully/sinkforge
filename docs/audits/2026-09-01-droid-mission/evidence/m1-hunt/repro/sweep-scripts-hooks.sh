#!/bin/bash
# Sweep capture/wait/probe scripts and both hooks for fail-open shapes.
#
# Scans for: [ -n ... ] guards that skip on absence, || true swallows,
# grep-on-output verdicts, wait-conditions that time out into silence.
#
# Population (at the pin):
#   tools/ .sh/.gd files: 19 total, 13 non-test
#   .githooks/: 2 files (commit-msg, pre-commit; NO pre-push)
# Re-derive:
#   git ls-tree -r --name-only 70f8a785 -- tools | grep -cE '\.(sh|gd)$'  (19)
#   git ls-tree --name-only 70f8a785 -- .githooks/ | grep -c .  (2)
#
# Usage: bash repro/sweep-scripts-hooks.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/sweep-scripts-hooks.txt}"
REPO="/Users/thondascully/Projects/sinkforge"

cd "$REPO"

echo "=== Capture/wait/probe + hooks sweep ===" > "$OUT"
echo "Population:" >> "$OUT"
echo "  tools/ .sh/.gd files: $(git ls-tree -r --name-only 70f8a785 -- tools | grep -cE '\.(sh|gd)$') total" >> "$OUT"
echo "  Non-test tools/ .sh/.gd: $(git ls-tree -r --name-only 70f8a785 -- tools | grep -E '\.(sh|gd)$' | grep -vE 'test_' | wc -l | tr -d ' ')" >> "$OUT"
echo "  .githooks/ files: $(git ls-tree --name-only 70f8a785 -- .githooks/ | grep -c .) (commit-msg, pre-commit)" >> "$OUT"
echo "  NO pre-push: $(git ls-tree --name-only 70f8a785 -- .githooks/ | grep -c 'pre-push' || true) (confirmed absent)" >> "$OUT"
echo "" >> "$OUT"

# Minimum population per VAL-HUNT-010
echo "Minimum scanned set (per VAL-HUNT-010):" >> "$OUT"
echo "  tools/capture_moments.sh" >> "$OUT"
echo "  tools/capture_colour_guard.sh" >> "$OUT"
echo "  tools/check_headed_boot.sh" >> "$OUT"
echo "  tools/surface_row.sh" >> "$OUT"
echo "  tools/probe_facing_flip.gd" >> "$OUT"
echo "  .githooks/commit-msg" >> "$OUT"
echo "  .githooks/pre-commit" >> "$OUT"
echo "" >> "$OUT"

# Scan each file for fail-open shapes
echo "=== Per-file scan ===" >> "$OUT"

for f in \
    tools/capture_moments.sh \
    tools/capture_colour_guard.sh \
    tools/check_headed_boot.sh \
    tools/surface_row.sh \
    tools/probe_facing_flip.gd \
    tools/run_gd_test.sh \
    tools/run_suites.sh \
    tools/run_local_battery.sh \
    tools/check_trailers.sh \
    tools/check_base_namespace.sh \
    tools/check_fork_completion.sh \
    tools/gate_status.py \
    tools/gate_status_ci.py \
    tools/spot_audit.sh \
    .githooks/commit-msg \
    .githooks/pre-commit
do
    echo "" >> "$OUT"
    echo "--- $f ---" >> "$OUT"
    content="$(git show "70f8a785:$f" 2>/dev/null || echo '(file not found at pin)')"

    # Shape: [ -n ... ] guards that skip on absence
    echo "  [ -n ... ] guards (skip on absence):" >> "$OUT"
    echo "$content" | grep -n '\[ -n ' >> "$OUT" 2>&1 || echo "    (none)" >> "$OUT"

    # Shape: || true swallows
    echo "  || true swallows:" >> "$OUT"
    echo "$content" | grep -n '|| true' >> "$OUT" 2>&1 || echo "    (none)" >> "$OUT"

    # Shape: grep-on-output verdicts (grep -q used as pass/fail)
    echo "  grep-on-output verdicts (grep -q):" >> "$OUT"
    echo "$content" | grep -n 'grep -q' >> "$OUT" 2>&1 || echo "    (none)" >> "$OUT"

    # Shape: exit 0 on absent/empty
    echo "  exit 0 on absent/empty:" >> "$OUT"
    echo "$content" | grep -n 'nothing to check\|exit 0\|return 0' >> "$OUT" 2>&1 | head -5 >> "$OUT" || echo "    (none)" >> "$OUT"

    # Shape: wait/timeout patterns
    echo "  wait/timeout patterns:" >> "$OUT"
    echo "$content" | grep -n 'wait\|timeout\|sleep\|await' >> "$OUT" 2>&1 | head -5 >> "$OUT" || echo "    (none)" >> "$OUT"
done

echo "" >> "$OUT"
echo "=== Untracked-but-permanent gate-or-test-shaped files ===" >> "$OUT"
echo "Checking for untracked files matching test_/check_/gate_/capture_/probe_ prefixes:" >> "$OUT"
git ls-files --others --exclude-standard | grep -E '(^|/)(test_|check_|gate_|capture_|probe_)' >> "$OUT" 2>&1 || echo "(none found: grep exit 1 is PASS per C10)" >> "$OUT"
echo "" >> "$OUT"
echo "Known baseline: tests/body/recordings/reveal_play_2026-09-01T16-32-34.log" >> "$OUT"
echo "  matches none of the prefixes (reveal_play_ does not match test_/check_/gate_/capture_/probe_)" >> "$OUT"
echo "  and is off-limits per AGENTS.md." >> "$OUT"

echo "" >> "$OUT"
echo "=== Triage ===" >> "$OUT"
echo "capture_moments.sh: already guarded (D0316, capture_colour_guard.sh + test_capture_moments.sh)" >> "$OUT"
echo "capture_colour_guard.sh: already guarded (the guard itself, D0316)" >> "$OUT"
echo "check_headed_boot.sh: fail-closed (MIN_COLOURS floor, agent-mode discriminator)" >> "$OUT"
echo "surface_row.sh: fail-closed (exits non-zero on failure)" >> "$OUT"
echo "probe_facing_flip.gd: partial (HUNT-F010, runs outside wrapper, hang caught by timeout)" >> "$OUT"
echo "run_gd_test.sh: already guarded (D0115/D0116, detector controls)" >> "$OUT"
echo "run_suites.sh: already guarded (D0262, exit-code-only, zero-suite refusal)" >> "$OUT"
echo "run_local_battery.sh: HUNT-F002 (gate drop, GATE_FAILED not in exit code)" >> "$OUT"
echo "check_trailers.sh: already guarded (shallow-clone refusal, 100-commit floor)" >> "$OUT"
echo "check_base_namespace.sh: already guarded (floors + population reconciliation)" >> "$OUT"
echo "commit-msg: fail-closed (refuses trailers, requires ledger entry)" >> "$OUT"
echo "pre-commit: HUNT-F006 (base-namespace block silent no-op if check_base_namespace.sh missing)" >> "$OUT"

echo "Sweep complete. Output saved to $OUT" >&2
