#!/usr/bin/env python3
"""docs/WORKING.md must not be older than HEAD. docs/QUALITY.md gate 23.

    python3 tools/layer_lint/check_working_freshness.py

Parses the "Last updated: YYYY-MM-DD" line docs/WORKING.md states about itself and fails if that date is
older than the date of HEAD's own commit. This is a proxy, not a guarantee -- a session can still bump
the date without saying anything true, the same way any self-reported field can lie -- but a stale date
is a cheap, mechanical signal that a working-tree summary was not touched even though commits landed
on top of it, which is exactly the failure mode CONTEXT.md's "Review bandwidth" section exists to catch
before it compounds across a session.
"""
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKING_MD = ROOT / "docs" / "WORKING.md"
DATE_RE = re.compile(r"Last updated:\s*(\d{4}-\d{2}-\d{2})")


def main() -> int:
    if not WORKING_MD.is_file():
        print("check_working_freshness: docs/WORKING.md does not exist -- nothing to check.")
        return 0

    text = WORKING_MD.read_text(encoding="utf-8")
    match = DATE_RE.search(text)
    if not match:
        print("check_working_freshness: FAIL -- docs/WORKING.md has no \"Last updated: YYYY-MM-DD\" "
              "line for this gate to read.")
        return 1
    stated = date.fromisoformat(match.group(1))

    head_date_str = subprocess.run(
        ["git", "log", "-1", "--format=%cd", "--date=short", "HEAD"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.strip()
    if not head_date_str:
        print("check_working_freshness: no HEAD commit to compare against -- nothing to check.")
        return 0
    head_date = date.fromisoformat(head_date_str)

    print(f"check_working_freshness: docs/WORKING.md states {stated}, HEAD's commit is dated {head_date}")
    if stated < head_date:
        print(f"check_working_freshness: FAIL -- docs/WORKING.md ({stated}) is older than HEAD "
              f"({head_date}). Update it and bump its \"Last updated\" line.")
        return 1

    print("check_working_freshness: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
