#!/bin/bash
# HUNT-F010: headed-boot probe step reproduction (static analysis).
#
# The headed-boot probe step (harness.yml:548-549 at the pin) runs
# `xvfb-run -a ./godot --path . tools/probe_facing_flip.tscn` directly,
# outside run_gd_test.sh. The verdict comes from the scene's own
# get_tree().quit(code) (tools/probe_facing_flip.gd:47 at the pin).
# A hang (the documented core/MODULE.md hazard: an unguarded runtime error
# inside _ready() does not crash, it hangs) is caught only by the job's
# 10-min timeout, not by the wrapper's SCRIPT ERROR detection.
# (D0115/D0116).
#
# This script verifies the probe's exit-code path and the lack of
# run_gd_test.sh wrapping by examining the CI step and the probe source.
#
# Usage: bash repro/hunt-f010-headed-probe.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f010-headed-probe.txt}"
REPO="/Users/thondascully/Projects/sinkforge"

cd "$REPO"

echo "=== CI step: probe_facing_flip.tscn (harness.yml) ===" > "$OUT"
git show 70f8a785:.github/workflows/harness.yml | grep -n 'probe_facing_flip' >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "--- Step context (lines around the probe invocation) ---" >> "$OUT"
git show 70f8a785:.github/workflows/harness.yml | sed -n '545,552p' >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "=== Probe source: exit-code path ===" >> "$OUT"
echo "--- get_tree().quit() calls in probe_facing_flip.gd ---" >> "$OUT"
git show 70f8a785:tools/probe_facing_flip.gd | grep -n 'get_tree().quit' >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "--- _failed flag and quit logic ---" >> "$OUT"
git show 70f8a785:tools/probe_facing_flip.gd | grep -n '_failed' >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "=== Comparison: run_gd_test.sh wrapping ===" >> "$OUT"
echo "Other suites run via: bash tools/run_gd_test.sh ./godot res://tests/test_x.gd" >> "$OUT"
echo "The probe runs via: xvfb-run -a ./godot --path . tools/probe_facing_flip.tscn" >> "$OUT"
echo "(no run_gd_test.sh wrapper, no SCRIPT ERROR detection)" >> "$OUT"
echo "" >> "$OUT"

echo "=== check_headed_boot.sh: uses run_gd_test.sh? ===" >> "$OUT"
git show 70f8a785:tools/check_headed_boot.sh | grep -n 'run_gd_test' >> "$OUT" 2>&1 || echo "(no: check_headed_boot.sh invokes godot directly)" >> "$OUT"
echo "" >> "$OUT"

echo "=== Assessment ===" >> "$OUT"
echo "The probe_facing_flip.tscn step runs outside run_gd_test.sh. The verdict" >> "$OUT"
echo "comes from the scene's own get_tree().quit(1 if _failed else 0). A hang" >> "$OUT"
echo "(unguarded runtime error in _ready()) is caught only by the job's" >> "$OUT"
echo "10-min timeout-minutes, not by the wrapper's SCRIPT ERROR detection." >> "$OUT"
echo "However: the probe has explicit blank-frame and empty-band checks" >> "$OUT"
echo "(_failed = true on empty bands), and check_headed_boot.sh has its" >> "$OUT"
echo "own controls (agent-mode discriminator, MIN_COLOURS floor). The probe" >> "$OUT"
echo "is fail-closed on the paths it knows about; the gap is the hang path" >> "$OUT"
echo "only. Not the seventh; a disclosed architectural choice." >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
