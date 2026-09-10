#!/usr/bin/env python3
"""Mutation tests for check_size_limits.py's MODULE.md cap (D0226, NEEDS_DIRECTOR P006).

    python3 tools/layer_lint/test_check_size_limits.py

`CONTEXT.md` stated a 60-line target for `MODULE.md` that **10 of the 18 tracked files exceeded, with no
gate reading it at all**. The director ruled the number up to 100 rather than spending an hour deleting
prose written on purpose. A raised cap that still nothing checks would be the same non-rule with a
friendlier number, so the cap is enforced here and the enforcement is tested at its boundary.

Boundary cases are the point. An off-by-one in a size cap is invisible in ordinary use -- every file
either sits far below or far above -- and it surfaces the first time somebody lands exactly on the line.
`core/MODULE.md` is 98 against a limit of 100, so "exactly at the limit" is two edits away from being
the live case, not a hypothetical.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_size_limits import MODULE_DOC_LIMIT, module_doc_violations, is_generated  # noqa: E402
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_check_size_limits")


def scratch_with(line_count: int, ignored: bool = False) -> tuple[list, int, Path]:
    root = Path(tempfile.mkdtemp())
    (root / "sim" / "world").mkdir(parents=True)
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    if ignored:
        (root / ".gitignore").write_text("sim/world/\n", encoding="utf-8")
    (root / "sim" / "world" / "MODULE.md").write_text("x\n" * line_count, encoding="utf-8")
    violations, count = module_doc_violations(root)
    return violations, count, root


def run_checks(trees: list) -> None:
    limit = MODULE_DOC_LIMIT
    for count, want_fail, label in ((limit - 1, False, "one under the limit passes"),
                                    (limit, False, "EXACTLY at the limit passes (the cap is >, not >=)"),
                                    (limit + 1, True, "one over the limit FAILS")):
        violations, checked, root = scratch_with(count)
        trees.append(root)
        LOG.observe(f"{label} ({count} lines)",
                    bool(violations) == want_fail and checked == 1,
                    f"{checked} checked, {len(violations)} violation(s)")

    # The population control: this gate shares `files_named`'s gitignore filter (D0225), so a MODULE.md
    # git ignores must not be counted. Without this, the cap would police a developer's scratch tree and
    # not CI -- the exact two-population defect P003 was raised for.
    violations, checked, root = scratch_with(limit + 50, ignored=True)
    trees.append(root)
    LOG.observe("an IGNORED MODULE.md is not checked, however long it is",
                checked == 0 and not violations, f"{checked} checked, {len(violations)} violation(s)")


def check_generated_exemption() -> None:
    """D0574: codegen output is exempt from FILE_LIMIT, and the exemption must not be able to widen.

    The risk is not that it fails to fire -- a gate that stops exempting turns red loudly. The risk is
    that it exempts something it should not, which is silent forever. So both halves are pinned: what
    IS generated, and the near misses that must not be."""
    for rel, want, why in (
        ("data/starts/generated.gd", True, "the real one, and the file that forced this"),
        ("data/materials/generated.gd", True, "any data kind, not a hard-coded list of them"),
        ("data/starts/tutorial.gd", False, "a hand-written file under data/ is NOT exempt"),
        ("view/hud/generated.gd", False, "generated.gd outside data/ is NOT exempt"),
        ("generated.gd", False, "at the tree root it is not under data/ and is NOT exempt"),
        ("data/generated.gd", False, "directly under data/ is not a data KIND's output"),
        ("data/starts/generated.gd.uid", False, "a sibling that merely starts with the name"),
        ("interface/observation.gd", False, "the other file at the cap stays capped (P034)"),
    ):
        LOG.observe(f"is_generated({rel}) is {want}: {why}", is_generated(rel) is want, str(is_generated(rel)))


def main() -> int:
    trees: list = []
    try:
        run_checks(trees)
        check_generated_exemption()
    finally:
        for root in trees:
            shutil.rmtree(root, ignore_errors=True)
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
