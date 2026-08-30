#!/usr/bin/env python3
"""QUALITY gate 31 (D0201): every `tests/test_*.gd` suite is actually RUN by CI.

The failure this exists for is the ledger's own "gate that runs nowhere" class, found four times over
in one reconciliation: `test_material_palette` (Slice 0), `test_mining`, `test_reveal_scene_dig_edge`
and `test_reveal_spawn_bounds` (Slice 1) were all written, all passing, all committed -- and none of
them appeared in `.github/workflows/harness.yml`. Every guard they carry, including two deliberately
mutation-tested bounds controls, had never once run outside the session that wrote it.

Neither side of that looks wrong when read alone. The workflow is a long, correct-looking list; the
tests directory is a long, correct-looking list. Only the SET DIFFERENCE says anything -- which is the
same reason `docs/DECISIONS_LEDGER.md` records "equal counts, different sets": a count of suites on
either side would have looked healthy throughout.

Reports the members, never just a total, so a failure can be acted on without re-deriving it.

Exit 0 clean, 1 on any suite that no CI step runs.
"""

import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "harness.yml"

# `test_base.gd` is the shared base class every suite extends, not a suite: it declares no `_test_*`
# entry point and running it would exercise nothing. Named here rather than filtered by a heuristic on
# the filename, so adding a real suite can never accidentally match an exemption.
NOT_A_SUITE = {"test_base.gd"}


def main() -> int:
    if not WORKFLOW.is_file():
        print(f"check_suite_coverage: FAIL - {WORKFLOW} not found; refusing to report a verdict")
        return 1

    # TRACKED suites, not files on disk. CI runs against a checkout, so an untracked suite is not
    # something CI could run even in principle -- counting it here would make this gate permanently red
    # for a reason it has no authority over, and untracked files are gate 27's subject, not this one.
    # (`sim/body/vertical_resolve.gd`'s parked companion `tests/test_vertical_resolve.gd` is exactly
    # that case, and it is deliberately uncommitted mid-investigation.)
    try:
        listing = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "tests/test_*.gd"],
            capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"check_suite_coverage: FAIL - could not list tracked suites ({exc}); refusing to report a verdict")
        return 1

    on_disk = {pathlib.PurePosixPath(line).name for line in listing.split()} - NOT_A_SUITE
    if not on_disk:
        # A positive control on the instrument itself: an empty population would make the set
        # difference empty too, and this gate would pass forever while checking nothing.
        print("check_suite_coverage: FAIL - found no tests/test_*.gd at all; the scan is broken, not the tree")
        return 1

    text = WORKFLOW.read_text(encoding="utf-8")
    in_ci = set(re.findall(r"res://tests/(test_[a-z0-9_]+\.gd)", text))

    unrun = sorted(on_disk - in_ci)
    missing = sorted(in_ci - on_disk)

    print(f"check_suite_coverage: {len(on_disk)} suites on disk, {len(in_ci)} referenced by CI")
    for name in unrun:
        print(f"  UNRUN   tests/{name} - exists and passes locally, but no CI step runs it")
    for name in missing:
        print(f"  DANGLING {name} - a CI step runs it, but the file does not exist")

    if unrun or missing:
        print(f"check_suite_coverage: FAIL - {len(unrun)} unrun, {len(missing)} dangling")
        return 1
    print("check_suite_coverage: PASS - every suite on disk is run by CI, and every step names a real file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
