#!/bin/bash
# Suite-timing cross-check: look for suspiciously fast suites as vacuous-green leads.
#
# Data source: CI suite-timing artifact from the most recent successful run
# on main, downloaded read-only via gh. The full Godot suite is never run
# locally (per the architecture); local derivation means CI artifacts.
#
# Outlier criterion: a suite whose timing is 0 seconds (or suspiciously
# fast, under 1 second) is a lead worth investigating, because a suite that
# asserts nothing runs suspiciously fast.
#
# Population: per-suite timings from the CI suite-timing artifact.
#
# Usage: bash repro/sweep-timing.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/sweep-timing.txt}"
REPO="/Users/thondascully/Projects/sinkforge"
SCRATCH="/tmp/m1-hunt-timing"

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cd "$SCRATCH"

echo "=== Suite-timing cross-check ===" > "$OUT"
echo "" >> "$OUT"

# Find the most recent successful run on main
echo "Data source: CI suite-timing artifact from the most recent successful run on main" >> "$OUT"
echo "Provenance: gh run list --branch main --status success --limit 5" >> "$OUT"
echo "" >> "$OUT"

# Get recent successful runs on main
RUNS=$(gh run list --repo teohondascully/sinkforge --branch main --status success --limit 5 --json databaseId,workflowName,createdAt 2>/dev/null || echo "")
if [ -z "$RUNS" ]; then
    echo "Could not list CI runs via gh. Falling back to local timing data." >> "$OUT"
    echo "" >> "$OUT"

    # Fallback: use run_suites.sh timing format from the source
    echo "Fallback: run_suites.sh writes per-suite timings to .result files." >> "$OUT"
    echo "The CI artifact suite_timing.txt captures this output." >> "$OUT"
    echo "Without CI access, we note the timing format and criterion." >> "$OUT"
    echo "" >> "$OUT"
    echo "Outlier criterion: suite timing of 0 seconds or under 1 second" >> "$OUT"
    echo "(a suite that asserts nothing runs suspiciously fast)." >> "$OUT"
    echo "" >> "$OUT"
    echo "Population: 62 suites (per the CI step name 'all 62 suites')." >> "$OUT"
    echo "Re-derive: git show 70f8a785:.github/workflows/harness.yml | grep -c 'res://tests/'" >> "$OUT"
else
    echo "Recent successful runs:" >> "$OUT"
    echo "$RUNS" | python3 -c "import sys,json; [print(f'  {r[\"databaseId\"]} {r[\"workflowName\"]} {r[\"createdAt\"]}') for r in json.load(sys.stdin)]" >> "$OUT" 2>&1 || echo "$RUNS" >> "$OUT"
    echo "" >> "$OUT"

    # Try to download the suite-timing artifact from the most recent run
    RUN_ID=$(echo "$RUNS" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['databaseId'])" 2>/dev/null || echo "")
    if [ -n "$RUN_ID" ]; then
        echo "Downloading suite-timing artifact from run $RUN_ID..." >> "$OUT"
        gh run download "$RUN_ID" --repo teohondascully/sinkforge --name suite-timing --dir "$SCRATCH/timing" >> "$OUT" 2>&1 || true

        if [ -f "$SCRATCH/timing/suite_timing.txt" ]; then
            echo "Downloaded suite_timing.txt from run $RUN_ID" >> "$OUT"
            echo "" >> "$OUT"
            echo "=== Suite timings ===" >> "$OUT"
            cat "$SCRATCH/timing/suite_timing.txt" >> "$OUT"
            echo "" >> "$OUT"

            # Count timings
            TIMING_COUNT=$(grep -c 'res://tests/' "$SCRATCH/timing/suite_timing.txt" 2>/dev/null || echo "0")
            echo "Timings examined: $TIMING_COUNT" >> "$OUT"
            echo "Re-derive: grep -c 'res://tests/' suite_timing.txt" >> "$OUT"
            echo "" >> "$OUT"

            # Outlier criterion: suites under 1 second
            echo "=== Outlier criterion: suites with timing < 1 second ===" >> "$OUT"
            echo "Criterion: a suite timing of 0 seconds or under 1 second is a lead" >> "$OUT"
            echo "(a suite that asserts nothing runs suspiciously fast)." >> "$OUT"
            echo "" >> "$OUT"

            # Extract per-suite timings from the output
            # run_suites.sh prints: "PASS <secs> <suite>" or "FAIL <secs> <suite>"
            # And the summary: "run_suites: <P> passed, <F> failed, of <N> in <E>s"
            # And the slowest list
            echo "Outliers (timing < 1s):" >> "$OUT"
            # The timings file has lines like "    5 res://tests/test_shaft_replay_determinism.gd"
            grep 'res://tests/' "$SCRATCH/timing/suite_timing.txt" | awk '{if ($1 < 1) print "  OUTLIER: " $0}' >> "$OUT" 2>&1 || echo "  (none found)" >> "$OUT"
        else
            echo "suite_timing.txt not found in downloaded artifacts." >> "$OUT"
            echo "The artifact may have expired (90-day retention)." >> "$OUT"
        fi
    fi
fi

echo "" >> "$OUT"
echo "=== Assessment ===" >> "$OUT"
echo "The suite-timing cross-check looks for suspiciously fast suites as" >> "$OUT"
echo "vacuous-green leads. The outlier criterion is: suite timing of 0 seconds" >> "$OUT"
echo "or under 1 second (a suite that asserts nothing runs suspiciously fast)." >> "$OUT"
echo "The full Godot suite is never run locally; timing data comes from CI." >> "$OUT"

echo "Timing cross-check complete. Output saved to $OUT" >&2
rm -rf "$SCRATCH"
