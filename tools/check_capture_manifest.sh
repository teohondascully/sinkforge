#!/bin/bash
# THE CAPTURE MANIFEST, CHECKED WHERE SOMEBODY WILL SEE IT.
#
# `tools/capture_manifest.sh --check` has existed and been correct for as long as the manifest has. It ran
# in ONE place: the CI authorship job. So the person running the sweep by hand to decide whether to commit
# was the one reader it could not reach. When it went red it stayed red: the local suite reported
# 112 PASS while the published head carried a failing check for days.
#
# This is the thin half of that fix. The runner registers a layer by path with no arguments, and the
# generator's DEFAULT mode rewrites a tracked file, so registering the generator itself would have a sweep
# mutate the tree. This wrapper exists to pass `--check` and nothing else.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/tools/capture_manifest.sh" --check
