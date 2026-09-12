#!/usr/bin/env python3
"""Mutation tests for tools/check_corrections_freshness.py -- the candidate-set regex is the gate.

    python3 tools/test_corrections_freshness.py

`candidate_ids` is a pure function over ledger text, so the mutation cases are synthetic headers: a
header whose text carries a correction keyword must be collected, one that does not must not be, and a
header that only NAMES "CORRECTIONS.md" must not false-positive on the substring "correct" inside the
filename (the live false positive found when this gate was dogfooded -- it flagged the two entries that
only ever mentioned the page).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_corrections_freshness import candidate_ids  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parent / "layer_lint"))
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_corrections_freshness")


def main() -> int:
    LOG.observe("a correction-keyword header is collected",
                candidate_ids("## D0100 · corrects D0099's claim\n") == ["D0100"])
    LOG.observe("'superseded' is collected",
                candidate_ids("## D0101 · supersedes the earlier ruling\n") == ["D0101"])
    LOG.observe("'FALSIFIED' is collected case-insensitively",
                candidate_ids("## D0102 · claim FALSIFIED by measurement\n") == ["D0102"])
    LOG.observe("a header with no correction keyword is not collected",
                candidate_ids("## D0103 · the lamp dial is not connected\n") == [])
    LOG.observe("a header merely NAMING CORRECTIONS.md is not collected (the live false positive)",
                candidate_ids("## D0104 · wrote docs/CORRECTIONS.md for the audit\n") == [])
    LOG.observe("a header naming the tool's own .py files is not collected (the D0603 false positive)",
                candidate_ids("## D0107 · tools/test_corrections_freshness.py, tools/check_corrections_freshness.py get tests\n") == [])
    LOG.observe("a non-header line carrying the keyword is not collected (headers only)",
                candidate_ids("body text: this corrects nothing in the header sense\n") == [])
    LOG.observe("mixed set: only the real correction header comes back",
                candidate_ids("## D0105 · added a test\n## D0106 · was wrong about the ratio\n")
                == ["D0106"])
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
