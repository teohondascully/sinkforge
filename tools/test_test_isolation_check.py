#!/usr/bin/env python3
"""Mutation tests for tools/test_isolation_check.py.

    python3 tools/test_test_isolation_check.py
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[0] / "layer_lint"))
from gate_test_support import Observations, init_scratch, write_file  # noqa: E402

import test_isolation_check as I  # noqa: E402

LOG = Observations("test_test_isolation_check")


def branch_all_through_wrapper() -> None:
    """A workflow where godot invocations go through run_gd_test.sh passes."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        wf = root / ".github" / "workflows" / "harness.yml"
        wf.parent.mkdir(parents=True, exist_ok=True)
        wf.write_text(
            "jobs:\n  tests:\n    steps:\n"
            "      - run: bash tools/run_gd_test.sh ./godot res://tests/test_body.gd\n",
            encoding="utf-8")
        exit_code = I.run(root)
        LOG.observe("all_through_wrapper: godot via run_gd_test.sh passes",
                    exit_code == 0, detail=f"exit={exit_code}")


def branch_bare_godot_fails() -> None:
    """A bare `godot --script res://tests/...` invocation fails."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        wf = root / ".github" / "workflows" / "harness.yml"
        wf.parent.mkdir(parents=True, exist_ok=True)
        wf.write_text(
            "jobs:\n  tests:\n    steps:\n"
            "      - run: ./godot --headless --script res://tests/test_body.gd\n",
            encoding="utf-8")
        exit_code = I.run(root)
        LOG.observe("bare_godot: bare godot --script invocation fails",
                    exit_code == 1, detail=f"exit={exit_code}")


def branch_run_suites_passes() -> None:
    """res://tests/ paths passed as arguments to run_suites.sh pass (it calls run_gd_test.sh internally)."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        wf = root / ".github" / "workflows" / "harness.yml"
        wf.parent.mkdir(parents=True, exist_ok=True)
        wf.write_text(
            "jobs:\n  tests:\n    steps:\n"
            "      - run: |\n"
            "          bash tools/run_suites.sh ./godot 4 \\\n"
            "            res://tests/test_body.gd \\\n"
            "            res://tests/test_shaft.gd\n",
            encoding="utf-8")
        exit_code = I.run(root)
        LOG.observe("run_suites: res://tests/ args to run_suites.sh pass",
                    exit_code == 0, detail=f"exit={exit_code}")


def branch_void_no_workflow() -> None:
    """No harness.yml exits 2 (VOID)."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        exit_code = I.run(root)
        LOG.observe("void: no harness.yml exits 2", exit_code == 2, detail=f"exit={exit_code}")


def main() -> int:
    for branch in (branch_all_through_wrapper, branch_bare_godot_fails,
                   branch_run_suites_passes, branch_void_no_workflow):
        branch()
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
