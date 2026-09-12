#!/usr/bin/env python3
"""Mutation tests for check_working_freshness.py (QUALITY.md gate 23).

    python3 tools/layer_lint/test_check_working_freshness.py

The gate's decision is two halves: parse the stated date out of WORKING.md's text, compare it against
HEAD's commit date. Both are exercised by pointing the module's WORKING_MD at a scratch file and
calling main() -- HEAD's date is whatever this checkout's is, so the stale case writes a date far in
the past and the fresh case writes today-or-later. The missing-file and missing-date-line branches are
the gate's own refusal paths, pinned the same way.
"""
import subprocess
import sys
import tempfile
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_working_freshness as wf  # noqa: E402
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_check_working_freshness")

ORIGINAL = wf.WORKING_MD


def run_with(text: str | None) -> int:
    """Point WORKING_MD at a scratch file (or a nonexistent path when text is None) and run main()."""
    root = Path(tempfile.mkdtemp())
    scratch = root / "WORKING.md"
    if text is not None:
        scratch.write_text(text, encoding="utf-8")
    wf.WORKING_MD = scratch
    try:
        return wf.main()
    finally:
        wf.WORKING_MD = ORIGINAL


def main() -> int:
    head = subprocess.run(["git", "log", "-1", "--format=%cd", "--date=short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()

    LOG.observe("a stated date far older than HEAD FAILS",
                run_with("Last updated: 2000-01-01\n") == 1)
    LOG.observe("a stated date equal to HEAD's own passes",
                run_with(f"Last updated: {head}\n") == 0)
    LOG.observe("a stated date in the FUTURE passes (the gate only looks backward)",
                run_with(f"Last updated: {date.today() + timedelta(days=30)}\n") == 0)
    LOG.observe("a WORKING.md with NO Last updated line FAILS (nothing to read = not clean)",
                run_with("# Working notes, no date line.\n") == 1)
    LOG.observe("a missing WORKING.md passes vacuously-by-design (file absent, not file stale)",
                run_with(None) == 0)
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
