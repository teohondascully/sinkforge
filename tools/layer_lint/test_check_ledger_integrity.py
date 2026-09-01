#!/usr/bin/env python3
"""Mutation tests for check_ledger_integrity.py -- `docs/DECISIONS_LEDGER.md` D0298.

    python3 tools/layer_lint/test_check_ledger_integrity.py

Every case writes a whole disposable ledger into a `tempfile.TemporaryDirectory()` and calls
`find_violations(scratch_root)`, never the real one -- same shape as
`tools/layer_lint/test_check_untracked_files.py`.

The two cases that matter most are the NEGATIVE ones. This gate's whole risk is over-firing: it exists to
let `.gitattributes` resolve ledger conflicts automatically, and a gate that faulted the ledger's own
`-- RESOLVED` and `D00NN/D00MM · addendum` heading forms would block every commit while looking correct,
because those forms genuinely do repeat a number. `branch_resolved_continuation_is_not_a_duplicate` and
`branch_joint_addendum_is_not_a_duplicate` are transcribed from the real file's D0004 and D0019/D0020.
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_ledger_integrity import LEDGER, MIN_DECLARATIONS, find_violations  # noqa: E402

RESULTS: list[tuple[str, bool]] = []

# Enough real-shaped declarations to clear MIN_DECLARATIONS, so a case never passes or fails for the
# incidental reason that the scratch ledger was too short.
FILLER = "\n".join(
    f"## D{n:04d} · 2026-08-26 · filler entry {n}\n\nBody.\n" for n in range(100, 100 + MIN_DECLARATIONS)
)


def _write(root: Path, body: str) -> None:
    (root / LEDGER).parent.mkdir(parents=True, exist_ok=True)
    (root / LEDGER).write_text(f"# Decisions ledger\n\n{FILLER}\n{body}\n", encoding="utf-8")


def check(name: str, body: str, expect_violation: bool, expect_substring: str | None = None) -> None:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write(root, body)
        violations = find_violations(root)
    fired = bool(violations)
    matched = expect_substring is None or any(expect_substring in v for v in violations)
    ok = (fired == expect_violation) and matched
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- expect_violation={expect_violation}, got {violations}")


def branch_duplicate_declaration() -> None:
    """Two declarations of one number -- what a union merge produces if append-only is ever broken."""
    check("positive control: the same number declared twice (broken)",
          "## D0300 · 2026-08-31 · lane\n\nOne.\n\n## D0300 · 2026-08-31 · other lane\n\nTwo.\n",
          expect_violation=True, expect_substring="declared a second time")


def branch_clean_ledger() -> None:
    """Ordinary appended entries, all distinct."""
    check("negative control: distinct declarations (fixed)",
          "## D0300 · 2026-08-31 · lane\n\nOne.\n\n## D0301 · 2026-08-31 · lane\n\nTwo.\n",
          expect_violation=False)


def branch_resolved_continuation_is_not_a_duplicate() -> None:
    """The real D0004 form. A `-- RESOLVED` heading revisits an address; it does not open one."""
    check("core property: `## D0300 -- RESOLVED` is a continuation, not a duplicate (fixed)",
          "## D0300 · 2026-08-26 · core/ -- NOT DECIDED\n\nOne.\n\n"
          "## D0300 -- RESOLVED, 2026-08-26\n\nTwo.\n",
          expect_violation=False)


def branch_joint_addendum_is_not_a_duplicate() -> None:
    """The real D0019/D0020 form: one heading revisiting two existing addresses at once."""
    check("core property: `## D0300/D0301 · addendum` is a reference, not a duplicate (fixed)",
          "## D0300 · 2026-08-26 · lane\n\nOne.\n\n## D0301 · 2026-08-26 · lane\n\nTwo.\n\n"
          "## D0300/D0301 · 2026-08-26 · addendum -- the cost, made explicit\n\nThree.\n",
          expect_violation=False)


def branch_dangling_reference() -> None:
    """An addendum whose entry is missing -- what a merge that DROPPED a block looks like."""
    check("positive control: addendum names an entry that was never declared (broken)",
          "## D0300 · 2026-08-26 · lane\n\nOne.\n\n"
          "## D0300/D0399 · 2026-08-26 · addendum\n\nTwo.\n",
          expect_violation=True, expect_substring="which is never declared")


def branch_conflict_marker_committed() -> None:
    """A hand-resolved conflict that left a marker behind. The file still renders; only a scan sees it."""
    check("positive control: an unresolved conflict marker was committed (broken)",
          "<<<<<<< HEAD\n## D0300 · 2026-08-31 · lane\n=======\n## D0301 · 2026-08-31 · lane\n"
          ">>>>>>> other\n\nBody.\n",
          expect_violation=True, expect_substring="conflict marker")


def branch_truncated_ledger() -> None:
    """The green-by-absence case: a ledger with almost nothing in it must FAIL, not pass for having
    no entries to fault. Written directly rather than through _write, which always adds the filler."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / LEDGER).parent.mkdir(parents=True, exist_ok=True)
        (root / LEDGER).write_text("# Decisions ledger\n\n## D0300 · 2026-08-31 · lane\n\nOne.\n",
                                    encoding="utf-8")
        violations = find_violations(root)
    ok = any("below the floor" in v for v in violations)
    RESULTS.append(("core property: a truncated ledger FAILs rather than passing empty", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] "
          f"core property: a truncated ledger FAILs rather than passing empty -- got {violations}")


def branch_missing_file() -> None:
    """No ledger at all must fault, for the same reason as the truncated case."""
    with tempfile.TemporaryDirectory() as d:
        violations = find_violations(Path(d))
    ok = any("does not exist" in v for v in violations)
    RESULTS.append(("positive control: no ledger file at all FAILs", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] "
          f"positive control: no ledger file at all FAILs -- got {violations}")


def branch_real_ledger_passes() -> None:
    """The gate must be green against the ledger actually in this tree. A gate that faults the real file
    is not a gate, it is a blocked repository -- and this is the only case that reads it."""
    root = Path(__file__).resolve().parents[2]
    violations = find_violations(root)
    ok = not violations
    RESULTS.append(("the real docs/DECISIONS_LEDGER.md passes", ok))
    print(f"[{'OBSERVED' if ok else 'NOT OBSERVED -- BRANCH UNTESTED'}] "
          f"the real docs/DECISIONS_LEDGER.md passes -- got {violations}")


def main() -> int:
    for branch in (branch_duplicate_declaration, branch_clean_ledger,
                   branch_resolved_continuation_is_not_a_duplicate,
                   branch_joint_addendum_is_not_a_duplicate, branch_dangling_reference,
                   branch_conflict_marker_committed, branch_truncated_ledger, branch_missing_file,
                   branch_real_ledger_passes):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_ledger_integrity: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed "
          f"correctly.")
    if failed:
        print("test_check_ledger_integrity: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_ledger_integrity: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
