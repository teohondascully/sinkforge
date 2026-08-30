#!/usr/bin/env python3
"""Layer dependency lint. See docs/ARCHITECTURE.md §3.

    python3 tools/layer_lint/layer_lint.py [--root DIR]

Checks dependency direction: layer X may only reference layers in its allowed set (below). A reference
the wrong way is a build failure, not a smell. Two kinds of reference are resolved:

  1. `res://...gd` paths -- preload, load, and `extends "res://...gd"`.
  2. `class_name` globals -- the identifier a file declares with `class_name`, used anywhere in another
     file's CODE (comments and string literals removed first, `gd_source.py`).

(2) was added 2026-08-30, D0224. Before it, **this gate reported PASS having checked ZERO references**:
it saw only `res://` paths, and this codebase couples exclusively through `class_name`. Its own docstring
said so ("do not report a PASS from this tool as 'the dependency graph holds'") and the caveat did not
protect anything -- the gate ran in CI as a required check, printed PASS, and had never once evaluated an
edge. That is why `check_edges_were_resolved` below exists and why this file has a mutation test.

SIBLING REACH-IN IS NOT EVALUATED OVER `class_name` EDGES, and the count that is skipped is printed
every run rather than described here. ARCHITECTURE §3 says "each module exposes exactly one public
interface file" and the path-based rule reads that as `sim/<module>/<module>.gd`. The tree does not
follow that convention -- `sim/world` publishes `TileGrid` and `WorldMaterials` from `tile_grid.gd` and
`materials.gd`, and there is no `world.gd` -- so applying the rule to `class_name` edges would report 14
violations that are all the codebase's ordinary structure. Which types are a module's public surface is
a design decision, parked as `docs/NEEDS_DIRECTOR.md` P008. The path-based sibling rule below is
unchanged and still runs.

Exit 0 = no violation found. Exit 1 = at least one violation, printed above the summary. Exit 2 = this
tool's own control failed (the tree is unreadable, or it resolved no edges at all), which is a report
about the tool, not the codebase.
"""
import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_excluding  # noqa: E402
from gd_source import declared_class_name, referenced_identifiers  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

# docs/ARCHITECTURE.md §3 -- the allowed dependency set for each layer. A layer may always reference
# itself (internal cross-references are a sibling-reach-in question, handled separately).
ALLOWED = {
    "core": set(),
    "sim": {"core"},
    "interface": {"sim", "core"},
    "harness": {"interface", "sim", "core"},
    "experiment": {"harness"},
    "view": {"interface", "core"},
    "shell": {"core", "sim", "interface", "harness", "experiment", "view", "data"},
}
# Directories the lint does not police: not part of the dependency graph, or explicitly excluded
# (legacy/ is pre-pivot code, frozen and out of scope per ARCHITECTURE's build-path exclusion).
UNPOLICED = {"legacy", "data", "docs", "tools", "tests", "scenarios", "claims", "incoming"}

RES_PATH_RE = re.compile(r'res://([\w./-]+\.gd)')


def layer_of(rel_path: Path) -> str | None:
    top = rel_path.parts[0]
    return top if top in ALLOWED else None


def module_of(rel_path: Path) -> str | None:
    """For sim/<module>/..., returns <module>. Else None."""
    if len(rel_path.parts) >= 2 and rel_path.parts[0] == "sim":
        return rel_path.parts[1]
    return None


def build_class_map(root: Path, files) -> dict:
    """`class_name` -> the policed file declaring it. Built from the policed tree only: a global
    declared under legacy/ or tests/ is not part of the layer graph this gate polices."""
    class_map = {}
    for rel in files:
        name = declared_class_name((root / rel).read_text(encoding="utf-8", errors="replace"))
        if name is not None:
            class_map[name] = rel
    return class_map


def _layer_violation(rel: Path, src_layer: str, shown: str, dst: Path) -> str | None:
    dst_layer = layer_of(dst)
    if dst_layer is None or dst_layer == src_layer:
        return None
    if dst_layer in ALLOWED.get(src_layer, set()):
        return None
    return (f"{rel}: references {shown} -- layer '{src_layer}' may not depend on layer '{dst_layer}' "
            f"(allowed: {sorted(ALLOWED.get(src_layer, set())) or 'nothing'})")


def _sibling_violation(rel: Path, src_module: str | None, shown: str, dst: Path) -> str | None:
    """Path-based only. See the module docstring for why `class_name` edges are exempt (P008)."""
    dst_module = module_of(dst)
    if layer_of(dst) != "sim" or dst_module is None or dst_module == src_module:
        return None
    if dst.name == f"{dst_module}.gd":
        return None
    return (f"{rel}: references {shown} -- reaches into sim/{dst_module}'s internals; "
            f"only sim/{dst_module}/{dst_module}.gd is public")


def scan_file(root: Path, rel: Path, class_map: dict) -> tuple[list, int, int]:
    """Returns (violations, path_edges_checked, class_edges_checked) for one file."""
    src_layer, src_module = layer_of(rel), module_of(rel)
    text = (root / rel).read_text(encoding="utf-8", errors="replace")
    violations, path_edges = [], 0
    for ref in RES_PATH_RE.findall(text):
        path_edges += 1
        dst = Path(ref)
        for found in (_layer_violation(rel, src_layer, ref, dst),
                      _sibling_violation(rel, src_module, ref, dst)):
            if found:
                violations.append(found)
    own = declared_class_name(text)
    class_edges = 0
    for ident in sorted(referenced_identifiers(text)):
        if ident not in class_map or ident == own:
            continue
        class_edges += 1
        found = _layer_violation(rel, src_layer, f"class_name {ident}", class_map[ident])
        if found:
            violations.append(found)
    return violations, path_edges, class_edges


def check_edges_were_resolved(class_map: dict, class_edges: int, path_edges: int) -> str | None:
    """The guard this gate did not have. A dependency lint that resolves NO edges is not a passing
    lint, it is an instrument that cannot register its subject -- which is exactly the state this file
    shipped in for weeks. If globals exist and none of them resolved, the resolver is broken."""
    if class_map and class_edges == 0 and path_edges == 0:
        return (f"{len(class_map)} class_name global(s) exist and NOT ONE reference to any of them "
                f"resolved, nor any res:// path. A lint that checked zero edges cannot pass; this is a "
                f"report about the resolver, not about the tree.")
    return None


def _skipped_sibling_edges(root: Path, files, class_map: dict) -> int:
    """How many `class_name` edges cross a sim module boundary and are NOT evaluated for reach-in.
    Printed every run so the exemption is a number in the output, never only a caveat in prose."""
    count = 0
    for rel in files:
        text = (root / rel).read_text(encoding="utf-8", errors="replace")
        own, src_module = declared_class_name(text), module_of(rel)
        for ident in referenced_identifiers(text):
            if ident not in class_map or ident == own:
                continue
            if _sibling_violation(rel, src_module, ident, class_map[ident]):
                count += 1
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(ROOT), help="tree to scan (default: the repository)")
    root = Path(parser.parse_args().root).resolve()

    files = [rel for rel in gd_files_excluding(root, UNPOLICED) if layer_of(rel) is not None]
    if not files:
        print("layer_lint: no .gd files under the layer tree -- nothing to check.")
        print("layer_lint: PASS (vacuously)")
        return 0

    class_map = build_class_map(root, files)
    violations, path_edges, class_edges = [], 0, 0
    for rel in sorted(files):
        found, paths, classes = scan_file(root, rel, class_map)
        violations += found
        path_edges += paths
        class_edges += classes

    print(f"layer_lint: {len(files)} files scanned, {path_edges} res:// reference(s) and "
          f"{class_edges} class_name reference(s) checked against {len(class_map)} global(s)")
    skipped = _skipped_sibling_edges(root, files, class_map)
    if skipped:
        print(f"layer_lint: {skipped} class_name edge(s) cross a sim module boundary and are NOT "
              f"checked for reach-in -- see this file's docstring and NEEDS_DIRECTOR P008")

    broken = check_edges_were_resolved(class_map, class_edges, path_edges)
    if broken:
        print(f"layer_lint: CONTROL FAILED -- {broken}")
        return 2
    if violations:
        print(f"layer_lint: FAIL -- {len(violations)} violation(s)")
        for violation in violations:
            print(f"  FAIL  {violation}")
        return 1
    print("layer_lint: PASS -- no layer violation found over the edges named above")
    return 0


if __name__ == "__main__":
    sys.exit(main())
