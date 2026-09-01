"""Shared reporting and fixtures for the gate mutation tests -- extracted 2026-08-30 (D0232).

`tools/quality_check/duplication.py` flagged two byte-identical `check()` helpers across
`test_gd_scan.py` and `test_check_size_limits.py`, written minutes apart. Unlike D0221's cluster, this
one is real copy-paste with nothing arithmetic about it, so it is deduplicated rather than excluded.

The vocabulary is deliberate and is not "assert". A gate mutation test does not ask whether a value is
right, it asks **whether a branch was ever seen to fire** -- so a case that does not hold is reported as
`NOT OBSERVED -- BRANCH UNTESTED` rather than as a failed assertion. `docs/QUALITY.md`'s standing line
is that a check which has never been observed failing is not a check, and these files exist to observe
exactly that.
"""

import subprocess
from pathlib import Path


def init_scratch(root: Path) -> None:
    """Initialise a git repo in a temp directory so gd_files_excluding's .git scan works."""
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "scratch@test"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "scratch"], cwd=root, check=True)
    (root / ".gitignore").write_text("scratch/\n", encoding="utf-8")


def write_file(root: Path, rel: str, content: str) -> None:
    """Write a file under root, creating parent directories as needed."""
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


class Observations:
    """One test file's branch log. Instantiated per file rather than kept module-global, so two suites
    imported into the same process cannot fold their results together."""

    def __init__(self, suite: str) -> None:
        self.suite = suite
        self.results: list[tuple[str, bool]] = []

    def observe(self, name: str, condition: bool, detail: str = "") -> None:
        self.results.append((name, condition))
        status = "OBSERVED" if condition else "NOT OBSERVED -- BRANCH UNTESTED"
        print(f"[{status}] {name}" + (f" -- {detail}" if detail else ""))

    def summarise(self) -> int:
        """Prints the tally and returns the process exit code."""
        failed = [name for name, ok in self.results if not ok]
        seen = len(self.results) - len(failed)
        print(f"\n{self.suite}: {seen}/{len(self.results)} branches observed")
        for name in failed:
            print(f"  UNTESTED: {name}")
        # An empty run is a failure, not a pass. A file whose cases all stopped being collected would
        # otherwise print "0/0 branches observed" and exit 0 -- the same quiet green that made
        # `layer_lint.py` itself worth fixing (D0224).
        if not self.results:
            print(f"{self.suite}: FAIL -- no branches were observed at all.")
            return 1
        print(f"{self.suite}: " + ("FAIL." if failed else "PASS."))
        return 1 if failed else 0
