#!/usr/bin/env python3
"""ANVIL step 2d. Mutation tests for check_integrity.py, one function per branch, each REQUIRED to
observe its target failure actually firing before the branch counts as covered.

    python3 tools/anvil/test_check_integrity.py

Per the director's own instruction: "a checker whose branches have not each been seen to fire is exactly
the 'real green that meant nothing' failure the retrospective documented" -- so every case below writes a
BROKEN fixture, asserts check_integrity() actually reports it, then (where the branch has one) writes the
corresponding FIXED fixture and asserts it does not. A branch that never gets a broken fixture to fail on
is not tested, it is decorated.

Uses tempfile so this never touches the real .anvil/log/, and check_integrity.check_integrity(log_dir) is
called as a function (imported), not via subprocess -- covered directly, not through the CLI wrapper.
"""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_integrity import check_integrity  # noqa: E402

UNIVERSAL = {"id": "aaaaaaaa-0000-0000-0000-000000000001", "timestamp": "2026-08-27T00:00:00+00:00",
             "author": "test", "commit": "deadbeef"}


def _id(n: int) -> str:
    return f"aaaaaaaa-0000-0000-0000-{n:012d}"


def _write(log_dir: Path, name: str, event: dict) -> None:
    (log_dir / name).write_text(json.dumps(event), encoding="utf-8")


def _valid_decision(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "DECISION", "choice": "x", "alternative": "y",
              "rationale": "z", "reversal_cost": "CHEAP"}
    event.update(overrides)
    return event


def _valid_claim(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "CLAIM_AUTHORED", "statement": "s", "threshold": "t",
              "method": "m", "instrument_class": "artifact", "decidability": "machine", "assumes": [],
              "ttl": 3600}
    event.update(overrides)
    return event


def _valid_finding(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "FINDING", "observation": "o", "evidence": [],
              "severity": "low", "confidence": "high", "source_class": "artifact-instrument",
              "invalidates": [], "independent_of": []}
    event.update(overrides)
    return event


def _valid_measurement(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "MEASUREMENT", "claim_id": _id(1), "value": 1,
              "unit": "sec", "method": "m", "source": "measured", "host": "h", "ttl": 3600}
    event.update(overrides)
    return event


RESULTS: list[tuple[str, bool]] = []


def check(name: str, log_dir: Path, expect_fail: bool, expect_substring: str | None = None) -> None:
    errors = check_integrity(log_dir)
    fired = bool(errors)
    matched_substring = expect_substring is None or any(expect_substring in e for e in errors)
    ok = (fired == expect_fail) and matched_substring
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- expect_fail={expect_fail}, got {len(errors)} error(s)"
          + (f": {errors}" if errors and not ok else ""))


def branch_dangling_supersedes() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1), supersedes=_id(99)))
        check("dangling supersedes (broken)", log_dir, expect_fail=True, expect_substring="supersedes")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(2), supersedes=_id(1)))
        check("dangling supersedes (fixed: target exists)", log_dir, expect_fail=False)


def branch_dangling_invalidates() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), invalidates=[_id(99)]))
        check("dangling invalidates (broken)", log_dir, expect_fail=True, expect_substring="invalidates")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_claim(_id(1)))
        _write(log_dir, "b.json", _valid_finding(_id(2), invalidates=[_id(1)]))
        check("dangling invalidates (fixed: target exists)", log_dir, expect_fail=False)


def branch_dangling_assumes() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_claim(_id(1), assumes=[_id(99)]))
        check("dangling assumes (broken)", log_dir, expect_fail=True, expect_substring="assumes")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", {**UNIVERSAL, "id": _id(1), "type": "ASSUMPTION", "statement": "s",
                                     "held_by": [], "challenged_by": []})
        _write(log_dir, "b.json", _valid_claim(_id(2), assumes=[_id(1)]))
        check("dangling assumes (fixed: target exists)", log_dir, expect_fail=False)


def branch_dangling_content_link_path() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", {**UNIVERSAL, "id": _id(1), "type": "CONTENT_LINK",
                                     "path": "this/path/does/not/exist.gd", "serves_claims": [],
                                     "assumes": []})
        check("dangling CONTENT_LINK.path (broken)", log_dir, expect_fail=True, expect_substring="does not exist")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", {**UNIVERSAL, "id": _id(1), "type": "CONTENT_LINK",
                                     "path": "CONTEXT.md", "serves_claims": [], "assumes": []})
        check("CONTENT_LINK.path (fixed: real file, CONTEXT.md)", log_dir, expect_fail=False)


def branch_duplicate_id() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(1)))
        check("duplicate id (broken)", log_dir, expect_fail=True, expect_substring="duplicate id")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(2)))
        check("duplicate id (fixed: distinct ids)", log_dir, expect_fail=False)


def branch_missing_required_field() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_decision(_id(1))
        del broken["reversal_cost"]
        _write(log_dir, "a.json", broken)
        check("missing required field, DECISION.reversal_cost (broken)", log_dir, expect_fail=True,
              expect_substring="reversal_cost")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        check("missing required field (fixed: all present)", log_dir, expect_fail=False)


def branch_unstated_source() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_measurement(_id(1))
        del broken["source"]
        _write(log_dir, "a.json", broken)
        check("unstated MEASUREMENT.source (broken, non-defaulting)", log_dir, expect_fail=True,
              expect_substring="source")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_measurement(_id(1)))
        check("MEASUREMENT.source (fixed: stated)", log_dir, expect_fail=False)


def branch_unstated_independent_of() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_finding(_id(1))
        del broken["independent_of"]
        _write(log_dir, "a.json", broken)
        check("unstated FINDING.independent_of (broken, non-defaulting)", log_dir, expect_fail=True,
              expect_substring="independent_of")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1)))
        check("FINDING.independent_of (fixed: stated, empty list is a valid statement)", log_dir,
              expect_fail=False)


def main() -> int:
    for branch in (branch_dangling_supersedes, branch_dangling_invalidates, branch_dangling_assumes,
                   branch_dangling_content_link_path, branch_duplicate_id, branch_missing_required_field,
                   branch_unstated_source, branch_unstated_independent_of):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_integrity: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_integrity: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_integrity: PASS -- every branch (dangling supersedes/invalidates/assumes/"
          "CONTENT_LINK path, duplicate id, missing required field, unstated source, unstated "
          "independent_of) was observed failing on a broken fixture and passing on the fixed one.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
