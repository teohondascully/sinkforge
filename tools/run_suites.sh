#!/usr/bin/env bash
# Run test suites, optionally in parallel, and report by EXIT CODE.
#
# Usage: tools/run_suites.sh <godot-binary> [jobs] [suite ...]
#   jobs defaults to 1. With no suites listed, runs every tests/test_*.gd that CI runs.
#
# WHY EXIT CODE AND NOT OUTPUT MATCHING. The obvious check is `grep -q 'ALL PASS'`, and it is wrong in
# the one direction that matters: `tools/run_gd_test.sh`'s own failure message is
#
#     run_gd_test: FAIL - res://tests/x.gd never printed its own ALL PASS line
#
# which CONTAINS the substring `ALL PASS`. A sweep built on that grep reports every such failure as a
# pass. This is not hypothetical -- it produced a "43/43 PASS" for a tree whose determinism golden was
# genuinely red, and that false green was reported to the director before it was caught
# (`docs/DECISIONS_LEDGER.md` D0262). The detector could not distinguish its own subject from its own
# failure text, which is this project's house failure class wearing the harness's clothes.
#
# `run_gd_test.sh` already exits non-zero on every failure shape it knows about, so the exit code is the
# verdict and no string matching is needed at all.
set -uo pipefail

GODOT="${1:?usage: run_suites.sh <godot-binary> [jobs] [suite ...]}"
JOBS="${2:-1}"
shift 2 2>/dev/null || shift 1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# `mapfile` is bash 4+; macOS ships bash 3.2, and this must run in both places.
SUITES=()
if [ "$#" -gt 0 ]; then
  SUITES=("$@")
else
  while IFS= read -r line; do
    SUITES+=("$line")
  done < <(grep -ohE 'res://tests/test_[a-z0-9_]+\.gd' .github/workflows/*.yml | sort -u)
fi
[ "${#SUITES[@]}" -gt 0 ] || { echo "run_suites: no suites found -- refusing to report a green over an empty population" >&2; exit 2; }

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

run_one() {
  local suite="$1" out="$2" godot="$3"
  local name; name="$(basename "$suite")"
  local t0; t0=$(date +%s)
  if "$ROOT/tools/run_gd_test.sh" "$godot" "$suite" > "$out/$name.log" 2>&1; then
    echo "PASS $(( $(date +%s) - t0 )) $suite" > "$out/$name.result"
  else
    echo "FAIL $(( $(date +%s) - t0 )) $suite" > "$out/$name.result"
  fi
}
export -f run_one
export ROOT

START=$(date +%s)
printf '%s\n' "${SUITES[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {} "$OUT" "$GODOT"
ELAPSED=$(( $(date +%s) - START ))

PASSED=0; FAILED=0
for f in "$OUT"/*.result; do
  read -r verdict secs suite < "$f"
  echo "$secs $suite" >> "$OUT/timings"
  if [ "$verdict" = "PASS" ]; then
    PASSED=$((PASSED+1))
  else
    FAILED=$((FAILED+1))
    echo "FAIL  $suite"
    grep -E '^  FAIL|FAILURE\(S\)' "$OUT/$(basename "$suite").log" | head -3 | sed 's/^/        /'
  fi
done

# The slowest suites, because with parallelism the sweep is bounded by its longest single suite, not by
# total work -- so this list, not the total, is what says where the next second comes from.
echo "run_suites: slowest suites:"
sort -rn "$OUT/timings" 2>/dev/null | head -6 | sed 's/^/    /'
echo "run_suites: ${PASSED} passed, ${FAILED} failed, of ${#SUITES[@]} in ${ELAPSED}s (jobs=${JOBS})"
[ "$FAILED" -eq 0 ]
