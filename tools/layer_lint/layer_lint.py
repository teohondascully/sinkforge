#!/usr/bin/env python3
"""Layer dependency lint. See docs/ARCHITECTURE.md §3.

    python3 tools/layer_lint/layer_lint.py

Checks two things, both grep-level over `res://...gd` references (preload,
load, and `extends "res://...gd"` — the only statically-visible cross-file
coupling GDScript has without a full parser):

  1. Dependency direction. Layer X may only reference layers in its allowed
     set (below). A reference the wrong way is a build failure, not a smell.
  2. No sibling reach-in. A module's internals are private; everything
     outside `sim/<module>/` must go through `sim/<module>/<module>.gd`, the
     one file whose name equals the module's directory name (the convention
     CONTEXT.md states: "One concept per file. Filename equals concept.").

WHAT THIS DOES NOT SEE, stated so a clean run is not mistaken for a proven
graph: GDScript's `class_name` mechanism makes every class globally visible
without an explicit `res://` reference, so a file that uses a class by its
global name alone (no preload, no load, no extends-by-path) is invisible to
this scan. That coupling is real and this tool cannot find it. Do not report
a PASS from this tool as "the dependency graph holds" — report it as "no
explicit path-based violation found."

Exit 0 = no violation found. Exit 1 = at least one violation, printed above
the summary. Exit 2 = the tree itself is unreadable (this tool's own control
failed), which is a report about the tool, not the codebase.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_excluding  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

# docs/ARCHITECTURE.md §3 — the allowed dependency set for each layer.
# A layer may always reference itself (internal cross-references are a
# sibling-reach-in question, handled separately, not a layer violation).
ALLOWED = {
    "core": set(),
    "sim": {"core"},
    "interface": {"sim", "core"},
    "harness": {"interface", "sim", "core"},
    "experiment": {"harness"},
    "view": {"interface", "core"},
    "shell": {"core", "sim", "interface", "harness", "experiment", "view", "data"},
}
# Directories the lint does not police: not part of the dependency graph,
# or explicitly excluded (legacy/ is pre-pivot code, frozen and out of scope
# per docs/ARCHITECTURE.md's build-path exclusion).
UNPOLICED = {"legacy", "data", "docs", "tools", "tests", "scenarios", "claims", "incoming"}

RES_PATH_RE = re.compile(r'res://([\w./-]+\.gd)')


def layer_of(rel_path: Path) -> str | None:
    top = rel_path.parts[0]
    if top in ALLOWED:
        return top
    return None


def module_of(rel_path: Path) -> str | None:
    """For sim/<module>/..., returns <module>. Else None."""
    if len(rel_path.parts) >= 2 and rel_path.parts[0] == "sim":
        return rel_path.parts[1]
    return None


def find_gd_files():
    return gd_files_excluding(ROOT, UNPOLICED)


def references_in(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    return RES_PATH_RE.findall(text)


def main() -> int:
    files = list(find_gd_files())
    if not files:
        print("layer_lint: no .gd files under the new layer tree yet — nothing to check.")
        print("layer_lint: PASS (vacuously — this is expected before Task 1 lands core/)")
        return 0

    violations = []
    checked_refs = 0

    for rel in files:
        src_layer = layer_of(rel)
        src_module = module_of(rel)
        if src_layer is None:
            continue  # a stray .gd not under a recognized layer root; not this lint's job
        abs_path = ROOT / rel
        for ref in references_in(abs_path):
            ref_path = Path(ref)
            checked_refs += 1
            dst_layer = layer_of(ref_path)
            if dst_layer is None:
                continue  # reference into data/, or something unpoliced — not a layer edge
            if dst_layer != src_layer and dst_layer not in ALLOWED.get(src_layer, set()):
                violations.append(
                    f"{rel}: references {ref} — layer '{src_layer}' may not depend on "
                    f"layer '{dst_layer}' (allowed: {sorted(ALLOWED.get(src_layer, set())) or 'nothing'})"
                )
            dst_module = module_of(ref_path)
            if (
                dst_layer == "sim"
                and dst_module is not None
                and dst_module != src_module
                and ref_path.name != f"{dst_module}.gd"
            ):
                violations.append(
                    f"{rel}: references {ref} — reaches into sim/{dst_module}'s internals; "
                    f"only sim/{dst_module}/{dst_module}.gd is public"
                )

    print(f"layer_lint: {len(files)} files scanned, {checked_refs} res://*.gd references checked")
    if violations:
        print(f"layer_lint: FAIL — {len(violations)} violation(s)")
        for v in violations:
            print(f"  FAIL  {v}")
        return 1

    print("layer_lint: PASS — no path-based layer violation found (see module docstring for scope)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
