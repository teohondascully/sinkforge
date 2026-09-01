#!/usr/bin/env bash
# Run test suites, optionally in parallel, and report by EXIT CODE.
#
# Usage: tools/run_suites.sh <godot-binary> [jobs] [suite ...]
#   jobs defaults to 1. With no suites listed, runs exactly the suites CI's `tests` job runs.
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
#
# WHY A FAILING SUITE'S OUTPUT IS DUMPED WHOLE, AND NOT FILTERED TO ITS `FAIL` LINES. It was filtered,
# for two commits, and that silently disabled a diagnostic built specifically to be read from the CI log.
# `test_shaft_replay_determinism.gd` prints its full observed hash sequence on a golden mismatch --
# unconditionally, not behind a verbose flag -- because D0167 cost an extra commit-and-push round trip
# for want of exactly that. It is a bare `print()`, so it matched neither `^  FAIL` nor `FAILURE(S)`, and
# the first CI run under the parallel runner reported the mismatch with **the sequence nowhere in the
# log**.
#
# The general rule this is an instance of: a runner must not decide which lines of a FAILING suite's
# output are interesting. It cannot know -- the interesting line is usually the one the suite author
# added precisely because the failure was hard to diagnose. Verbosity costs nothing here, because this
# path only runs when something is already red.
#
# WHY THE NO-ARGUMENT DEFAULT PARSES ONE JOB INSTEAD OF GREPPING EVERY WORKFLOW (D0283). The header
# above claims this runner's default is what CI runs. It was not. The default used to be
#
#     grep -ohE 'res://tests/test_[a-z0-9_]+\.gd' .github/workflows/*.yml | sort -u
#
# -- every `res://tests/...` string in every file under .github/workflows/, regardless of which job it
# belongs to or whether that job fires on a push at all. Measured on this tree: that grep selected 48
# suites where CI's `tests` job runs 47, and the extra one was `test_body_fuzz.gd`, which lives in
# `fuzz_nightly` -- a `schedule`-only job that sweeps 1000x1500 and takes ~114s (D0060). So the LOCAL
# default silently ran a nightly-sized sweep as though it were the per-commit set, and a local green
# meant something different from a CI green while claiming to mean the same thing. CI itself was never
# affected: it passes an explicit list. Only the header's claim was false.
#
# It now reads `tools/list_ci_suites.py`, the same parser `tools/run_local_battery.sh` uses -- one
# source, read twice -- which loads the YAML and walks the `tests` job's own steps. The job name is not
# a parameter there, on purpose (its own docstring): making the caller name a job is exactly how someone
# eventually passes the wrong one, which is the defect above.
#
# If that parser fails, this aborts with exit 2 rather than falling back to the grep. A fallback here
# would reintroduce the whole problem class: the fallback's answer and the real answer are both a list
# of suites, both plausible, and nothing downstream can tell which one it got.
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
  # Assigned first and checked second: `X="$(cmd)"` carries `cmd`'s status into `$?`, whereas the
  # process substitution this replaced (`done < <(...)`) discards it entirely -- a parser that exited 2
  # and printed nothing would have read as "no suites" rather than as "the parser broke".
  CI_SUITES="$(python3 "$ROOT/tools/list_ci_suites.py" "$ROOT/.github/workflows/harness.yml")"
  LIST_RC=$?
  if [ "$LIST_RC" -ne 0 ]; then
    echo "run_suites: tools/list_ci_suites.py exited $LIST_RC -- refusing to guess a suite list." >&2
    exit 2
  fi
  # Herestring, not a pipe: a pipe runs the loop in a subshell and SUITES would be empty on the far
  # side of it. Blank lines are skipped so a trailing newline cannot become an empty suite path.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    SUITES+=("$line")
  done <<< "$CI_SUITES"
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
    echo "FAIL  $suite -- its FULL output follows:"
    sed 's/^/        /' "$OUT/$(basename "$suite").log"
  fi
done

# The slowest suites, because with parallelism the sweep is bounded by its longest single suite, not by
# total work -- so this list, not the total, is what says where the next second comes from.
echo "run_suites: slowest suites:"
sort -rn "$OUT/timings" 2>/dev/null | head -6 | sed 's/^/    /'
echo "run_suites: ${PASSED} passed, ${FAILED} failed, of ${#SUITES[@]} in ${ELAPSED}s (jobs=${JOBS})"
[ "$FAILED" -eq 0 ]
