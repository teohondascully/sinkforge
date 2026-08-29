#!/usr/bin/env python3
"""Mutation tests for check_claim_references.py's VOID-vs-PASS contract closure (A4, the audit response
queue, `docs/DECISIONS_LEDGER.md` D0146). Builds a disposable scratch tree per case (`tempfile.
TemporaryDirectory()`) and calls `check_claim_references.run(scratch_root)` directly -- matching
`tools/layer_lint/test_check_untracked_files.py`'s own pattern, never touches the real repository.

    python3 tools/layer_lint/test_check_claim_references.py
"""
import io
import sys
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_claim_references as ccr  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def _write_claim(root: Path, cid: str, first_failed_at: str = "never", status: str = "ACTIVE") -> None:
    (root / "claims").mkdir(exist_ok=True)
    (root / "claims" / f"{cid}-scratch.md").write_text(
        f"---\nfirst_failed_at: {first_failed_at}\nstatus: {status}\n---\nbody\n", encoding="utf-8",
    )


def _run(root: Path) -> tuple[int, str]:
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = ccr.run(root)
    return code, buf.getvalue()


def check(name: str, root: Path, expect_code: int, expect_substring: str) -> None:
    code, out = _run(root)
    ok = (code == expect_code) and (expect_substring in out)
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- code={code}, expect={expect_code}, wanted substring={expect_substring!r}")
    if not ok:
        print(f"    --- actual output ---\n{out}")


def branch_no_dirs_at_all() -> None:
    """Neither scenarios/ nor harness/ exist -- VOID, exit 0, per the queue's own A4 case."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        check("no scenarios/ or harness/ at all: VOID", root, 0, "VOID")


def branch_dirs_exist_but_empty() -> None:
    """The real, present bug this fixes: BOTH dirs exist but hold nothing that qualifies (scenarios/ has
    only a README, harness/ has .gd files but none register `func run(`) -- the exact live state of this
    repository right now. Must be VOID, not the PASS the pre-fix code gave it."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / "scenarios").mkdir()
        (root / "scenarios" / "README.md").write_text("not a .yaml\n", encoding="utf-8")
        (root / "harness").mkdir()
        (root / "harness" / "support.gd").write_text("# a helper, not a check layer\nfunc helper():\n\tpass\n",
                                                       encoding="utf-8")
        check("scenarios/+harness/ both exist, zero qualifying files: VOID (was PASS pre-fix)", root, 0, "VOID")


def branch_real_population_clean() -> None:
    """A nonzero population, fully compliant -- must be a real PASS, not VOID."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write_claim(root, "C900", first_failed_at="2026-01-01")
        (root / "scenarios").mkdir()
        (root / "scenarios" / "s1.yaml").write_text("claim: C900\nother: 1\n", encoding="utf-8")
        check("real nonzero population, compliant: PASS", root, 0, "PASS")


def branch_real_population_violating() -> None:
    """A nonzero population with a real violation (unproven claim cited) -- must FAIL, exit 1, distinct
    from VOID -- proves VOID and FAIL are not the same exit path wearing different print statements."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write_claim(root, "C901", first_failed_at="never")
        (root / "scenarios").mkdir()
        (root / "scenarios" / "s1.yaml").write_text("claim: C901\n", encoding="utf-8")
        check("real nonzero population, unproven claim cited: FAIL, exit 1", root, 1, "FAIL")


def branch_harness_layer_counts_toward_population() -> None:
    """A single real, compliant harness check-layer file alone (no scenarios/) must be enough to make
    the population nonzero and produce PASS, not VOID -- proves the population count is scenarios OR
    harness, not scenarios only."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write_claim(root, "C902", first_failed_at="2026-01-01")
        (root / "harness").mkdir()
        (root / "harness" / "layer.gd").write_text(
            "# claim: C902\nfunc run():\n\tpass\n", encoding="utf-8",
        )
        check("one real harness check-layer file, no scenarios/: PASS", root, 0, "PASS")


def branch_cap_violation_independent_of_population() -> None:
    """The active-claim cap must still FAIL even with zero scenarios/harness population -- proves the
    cap check is not accidentally short-circuited by the VOID path."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        for i in range(ccr.ACTIVE_CLAIM_CAP + 1):
            _write_claim(root, f"C{100 + i}", status="ACTIVE")
        check("cap exceeded, zero scenarios/harness population: FAIL, not VOID", root, 1, "FAIL")


def main() -> int:
    for branch in (
        branch_no_dirs_at_all,
        branch_dirs_exist_but_empty,
        branch_real_population_clean,
        branch_real_population_violating,
        branch_harness_layer_counts_toward_population,
        branch_cap_violation_independent_of_population,
    ):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_claim_references: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_claim_references: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_claim_references: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
