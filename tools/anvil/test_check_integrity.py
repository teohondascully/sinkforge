#!/usr/bin/env python3
"""ANVIL step 2d, extended after an external (Codex) audit found real coverage gaps. One function per
branch, each REQUIRED to observe its target failure actually firing before the branch counts as covered.

    python3 tools/anvil/test_check_integrity.py

Per the director's own instruction: "a checker whose branches have not each been seen to fire is exactly
the 'real green that meant nothing' failure the retrospective documented" -- so every case below writes a
BROKEN fixture, asserts check_integrity() actually reports it, then (where the branch has one) writes the
corresponding FIXED fixture and asserts it does not. A branch that never gets a broken fixture to fail on
is not tested, it is decorated.

Uses tempfile so this never touches the real .anvil/log/, and check_integrity.check_integrity(log_dir) is
called as a function (imported), not via subprocess -- covered directly, not through the CLI wrapper.
"""
import contextlib
import io
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_integrity as ci_module  # noqa: E402
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
    event = {**UNIVERSAL, "id": event_id, "type": "FINDING", "observation": "o", "evidence": ["e1"],
              "severity": "low", "confidence": "high", "source_class": "artifact-instrument",
              "invalidates": [], "independent_of": []}
    event.update(overrides)
    return event


def _valid_measurement(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "MEASUREMENT", "claim_id": _id(1), "value": 1,
              "unit": "sec", "method": "m", "source": "measured", "host": "h", "ttl": 3600}
    event.update(overrides)
    return event


def _valid_assumption(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "ASSUMPTION", "statement": "s", "held_by": [],
              "challenged_by": []}
    event.update(overrides)
    return event


def _valid_content_link(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "CONTENT_LINK", "path": "CONTEXT.md",
              "serves_claims": [], "assumes": []}
    event.update(overrides)
    return event


def _valid_override(event_id: str, **overrides) -> dict:
    event = {**UNIVERSAL, "id": event_id, "type": "OVERRIDE", "target_event": _id(1), "reason": "r",
              "expiry": "2026-09-01"}
    event.update(overrides)
    return event


RESULTS: list[tuple[str, bool]] = []


def check(name: str, log_dir: Path, expect_fail: bool, expect_substring: str | None = None) -> None:
    errors, _count = check_integrity(log_dir)
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
        _write(log_dir, "a.json", _valid_assumption(_id(1)))
        _write(log_dir, "b.json", _valid_claim(_id(2), assumes=[_id(1)]))
        check("dangling assumes (fixed: target exists)", log_dir, expect_fail=False)


def branch_dangling_content_link_path() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_content_link(_id(1), path="this/path/does/not/exist.gd"))
        check("dangling CONTENT_LINK.path (broken)", log_dir, expect_fail=True, expect_substring="does not exist")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_content_link(_id(1)))
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
        _write(log_dir, "claim.json", _valid_claim(_id(1)))
        broken = _valid_measurement(_id(2), claim_id=_id(1))
        del broken["source"]
        _write(log_dir, "a.json", broken)
        check("unstated MEASUREMENT.source (broken, non-defaulting)", log_dir, expect_fail=True,
              expect_substring="source")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        # claim_id must resolve to a real CLAIM_AUTHORED now that references are typed -- a single
        # MEASUREMENT event with a self-pointing default claim_id (this branch's original single-event
        # form) would itself now be a self-reference violation, not a clean "fixed" case.
        _write(log_dir, "a.json", _valid_claim(_id(1)))
        _write(log_dir, "b.json", _valid_measurement(_id(2), claim_id=_id(1)))
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


def branch_multi_violation() -> None:
    """One fixture, several simultaneous violations -- each check runs independently over the same
    event list (check_integrity.py's own loop structure), so this should report ALL of them, not just
    the first one found. The director's own instruction: "each check scans independently is almost
    certainly right" is exactly the sentence that precedes an instrument failure in this project's
    history (memory: two-instruments-are-not-a-cover, count-without-membership) -- verified here rather
    than trusted.
    """
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_decision(_id(1), supersedes=_id(99))
        del broken["reversal_cost"]
        _write(log_dir, "a.json", broken)
        _write(log_dir, "b.json", _valid_finding(_id(1), invalidates=[_id(98)]))
        errors, _count = check_integrity(log_dir)
        expected_substrings = ["reversal_cost", "supersedes", "duplicate id", "invalidates"]
        found = {s: any(s in e for e in errors) for s in expected_substrings}
        ok = all(found.values()) and len(errors) >= 4
        RESULTS.append(("multi-violation fixture reports every violation, not just the first", ok))
        status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
        print(f"[{status}] multi-violation fixture -- {len(errors)} error(s) found, per-kind hits: {found}")
        if errors:
            for e in errors:
                print(f"    {e}")


def branch_dangling_serves_claims() -> None:
    """Codex's specific finding: CONTENT_LINK.serves_claims was in the schema and never traversed --
    a dangling reference passed. Now part of the typed-reference table (schema.REFERENCE_FIELDS).
    """
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_content_link(_id(1), serves_claims=[_id(99)]))
        check("dangling CONTENT_LINK.serves_claims (broken -- Codex's finding)", log_dir, expect_fail=True,
              expect_substring="serves_claims")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_claim(_id(1)))
        _write(log_dir, "b.json", _valid_content_link(_id(2), serves_claims=[_id(1)]))
        check("CONTENT_LINK.serves_claims (fixed: target exists and is a CLAIM_AUTHORED)", log_dir,
              expect_fail=False)


def branch_wrong_target_type() -> None:
    """A reference resolving to a REAL event of the WRONG type -- structurally valid, semantically
    nonsensical. This is the core of the typed-reference fix: existence alone is not enough.
    """
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))  # a DECISION, not a CLAIM_AUTHORED
        _write(log_dir, "b.json", _valid_measurement(_id(2), claim_id=_id(1)))
        check("MEASUREMENT.claim_id points at a real event of the WRONG type (broken)", log_dir,
              expect_fail=True, expect_substring="not one of the legal target types")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_claim(_id(1)))
        _write(log_dir, "b.json", _valid_measurement(_id(2), claim_id=_id(1)))
        check("MEASUREMENT.claim_id points at the right type (fixed)", log_dir, expect_fail=False)


def branch_supersedes_type_rules() -> None:
    """supersedes' legal targets depend on the SOURCE event's type: same-type by default, except
    DECISION -> ASSUMPTION (architecture doc §8.6, explicit). All three shapes checked.
    """
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "claim.json", _valid_claim(_id(9)))
        # id(1) is a MEASUREMENT, valid on its own (claim_id points at id(9)'s real claim) -- isolates
        # the DECISION.supersedes violation this case is actually testing, not a second unrelated one.
        _write(log_dir, "a.json", _valid_measurement(_id(1), claim_id=_id(9)))
        _write(log_dir, "b.json", _valid_decision(_id(2), supersedes=_id(1)))
        check("DECISION.supersedes -> MEASUREMENT (broken, not a legal target)", log_dir, expect_fail=True,
              expect_substring="not one of the legal target types")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_assumption(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(2), supersedes=_id(1)))
        check("DECISION.supersedes -> ASSUMPTION (fixed: the documented §8.6 exception)", log_dir,
              expect_fail=False)
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(2), supersedes=_id(1)))
        check("DECISION.supersedes -> DECISION (fixed: the default same-type case)", log_dir,
              expect_fail=False)


def branch_self_reference() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_decision(_id(1))
        broken["supersedes"] = _id(1)
        _write(log_dir, "a.json", broken)
        check("self-supersession (broken)", log_dir, expect_fail=True, expect_substring="own id")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_finding(_id(1))
        broken["invalidates"] = [_id(1)]
        _write(log_dir, "a.json", broken)
        check("self-reference via invalidates, not just supersedes (broken)", log_dir, expect_fail=True,
              expect_substring="own id")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        _write(log_dir, "b.json", _valid_decision(_id(2), supersedes=_id(1)))
        check("supersedes a DIFFERENT event (fixed)", log_dir, expect_fail=False)


def branch_malformed_uuid() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_decision(_id(1))
        broken["id"] = "notuuid"
        _write(log_dir, "a.json", broken)
        check("malformed id, not UUID-shaped (broken -- Codex's exact probe)", log_dir, expect_fail=True,
              expect_substring="not a valid UUID")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        broken = _valid_decision(_id(1), supersedes="also-not-a-uuid")
        _write(log_dir, "a.json", broken)
        check("malformed supersedes value, not UUID-shaped (broken)", log_dir, expect_fail=True,
              expect_substring="not a valid UUID")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_decision(_id(1)))
        check("well-formed UUID id (fixed)", log_dir, expect_fail=False)


def branch_empty_required_array() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), evidence=[]))
        check("FINDING.evidence = [] (broken -- empty is not a meaningful finding)", log_dir,
              expect_fail=True, expect_substring="evidence")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), evidence=["real evidence"]))
        check("FINDING.evidence non-empty (fixed)", log_dir, expect_fail=False)
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        # Regression guard: independent_of=[] must STAY valid -- this is not the same fix as evidence.
        _write(log_dir, "a.json", _valid_finding(_id(1), independent_of=[]))
        check("FINDING.independent_of = [] still PASSES (deliberate, not a regression)", log_dir,
              expect_fail=False)


def branch_source_class_values() -> None:
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), source_class="made-up-class"))
        check("FINDING.source_class outside the closed set (broken)", log_dir, expect_fail=True,
              expect_substring="source_class")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), independent_of=["made-up-class"]))
        check("FINDING.independent_of entry outside the closed set (broken)", log_dir, expect_fail=True,
              expect_substring="independent_of entry")
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        _write(log_dir, "a.json", _valid_finding(_id(1), independent_of=["human-play"]))
        check("FINDING.independent_of entry in the closed set (fixed)", log_dir, expect_fail=False)


def branch_empty_log_reports_count_not_pass() -> None:
    """The director's own instruction: an empty log must report '0 events', never PASS -- zero is a fine
    bootstrap state, but PASS-over-nothing is exactly the vacuous-green class this project documents
    repeatedly (D0072). Tests main() itself, not check_integrity(), since that's where the string lives.
    """
    with tempfile.TemporaryDirectory() as d:
        log_dir = Path(d)
        original = ci_module.DEFAULT_LOG_DIR
        ci_module.DEFAULT_LOG_DIR = log_dir
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                exit_code = ci_module.main()
        finally:
            ci_module.DEFAULT_LOG_DIR = original
        output = buf.getvalue()
        ok = exit_code == 0 and "0 events" in output and "PASS" not in output
        RESULTS.append(("empty log reports '0 events', never PASS", ok))
        status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
        print(f"[{status}] empty log message -- exit={exit_code}, output={output!r}")


def main() -> int:
    for branch in (branch_dangling_supersedes, branch_dangling_invalidates, branch_dangling_assumes,
                   branch_dangling_content_link_path, branch_duplicate_id, branch_missing_required_field,
                   branch_unstated_source, branch_unstated_independent_of, branch_multi_violation,
                   branch_dangling_serves_claims, branch_wrong_target_type, branch_supersedes_type_rules,
                   branch_self_reference, branch_malformed_uuid, branch_empty_required_array,
                   branch_source_class_values, branch_empty_log_reports_count_not_pass):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_integrity: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_integrity: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_integrity: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
