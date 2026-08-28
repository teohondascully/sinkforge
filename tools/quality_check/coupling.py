#!/usr/bin/env python3
"""Module fan-in/fan-out for `sim/`'s and `tools/`'s own submodules -- the level `docs/ARCHITECTURE.md`
§3's layer-direction rule (already enforced by `tools/layer_lint/layer_lint.py`) does not reach. That
gate asks "does this reference cross a LAYER boundary the wrong way." This asks a different question:
"is any one submodule quietly becoming a hub everything else routes through," which a correct-direction
graph can still have.

    python3 tools/quality_check/coupling.py

**Scope decision, stated rather than silently assumed:** this measures fan-in/fan-out and reports the
distribution + IQR outliers (director's instruction: data before threshold). It does NOT attempt to
parse `sim/*/MODULE.md`'s or `tools/*/README.md`'s prose "Consumers"/"Must not" sections into a formal
expected graph and diff against them -- that text is free-form prose (e.g. "Read input devices; know
about rendering" names no `sim/` module at all), not structured data, and reliably extracting one would
be a much larger, fuzzier problem than this dashboard's budget or this property's actual computability
supports. What's measured here is real, from code; what a MODULE.md *says* is a separate, human-read
cross-check, not something this instrument verifies.

**Two measurement methods, one blind spot closed rather than just inherited:**
- `sim/`: TWO sources of edges, unioned. First, `tools/layer_lint/layer_lint.py`'s own `res://`
  path-scanning (`module_of`, `references_in`). Second -- because this instrument's real subject is
  `sim/`'s own architecture, and shipping it blind to that architecture's dominant coupling mechanism
  would make it report a near-vacuous "no coupling" on a codebase that plainly has some (a real check
  against this exact tree found ZERO res://-based sim/ references but 13 `class_name` declarations) --
  a scan for GLOBAL `class_name` usage: any file using a name declared `class_name` in a DIFFERENT sim/
  module, with no `preload`/`load` in sight, is a real edge this closes. What remains unclosed: a
  reference via some THIRD mechanism neither scanner recognizes, and any class_name usage this regex's
  word-boundary match misses (e.g. inside a string, which would be a false positive in the other
  direction, not a missed edge).
- `tools/`: Python `import`/`from...import` statements, resolved by filename against `tools/<subdir>/`
  directories. A name resolves LOCALLY first (matching how `sys.path.insert(0, .../parent)`, this
  codebase's own convention, actually resolves it at runtime) -- `tools/economy_check/schema.py` and
  `tools/anvil/schema.py` share a filename, and without local-first resolution this would wrongly count
  every `from schema import ...` in `economy_check` as a reference to `anvil`. A name matching MULTIPLE
  other subdirectories with no local match is ambiguous and is not counted, not guessed.

Carries a yield counter from day one (`dashboard.py`'s YIELD section, this file's own outlier count) --
stated here, not only in the dashboard wrapper, so it is not exempted from the project's standing
retire-what-never-fires rule by feeling virtuous.
"""
import ast
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layer_lint"))
from layer_lint import module_of, references_in  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import ROOT, iqr_outlier_fence, run_cli, summarize  # noqa: E402

_CLASS_NAME_RE = re.compile(r'^\s*class_name\s+(\w+)', re.MULTILINE)


def _sim_modules(root: Path) -> list[str]:
    base = root / "sim"
    if not base.is_dir():
        return []
    return sorted(p.name for p in base.iterdir() if p.is_dir())


def _tools_modules(root: Path) -> list[str]:
    base = root / "tools"
    if not base.is_dir():
        return []
    return sorted(p.name for p in base.iterdir() if p.is_dir() and p.name != "scratch")


def _sim_path_edges(root: Path) -> list[tuple[str, str]]:
    """(src_module, dst_module) via explicit res:// preload/load/extends references."""
    edges = []
    for p in (root / "sim").rglob("*.gd"):
        rel = p.relative_to(root)
        src = module_of(rel)
        if src is None:
            continue
        for ref in references_in(p):
            dst = module_of(Path(ref))
            if dst is not None and dst != src:
                edges.append((src, dst))
    return edges


def _class_name_declarations(root: Path) -> dict[str, Path]:
    """class_name -> declaring file (relative to root), across every .gd file (a class_name is globally
    visible project-wide, not scoped to sim/), legacy/ excluded."""
    declared = {}
    for p in root.rglob("*.gd"):
        rel = p.relative_to(root)
        if rel.parts[0] == "legacy" or rel.parts[0].startswith("."):
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for m in _CLASS_NAME_RE.finditer(text):
            declared[m.group(1)] = rel
    return declared


def _sim_class_name_edges(root: Path) -> list[tuple[str, str]]:
    """(src_module, dst_module) via GLOBAL class_name usage -- no preload/load required for these to be
    real references. This is the specific coupling `_sim_path_edges` (and `layer_lint.py`, which it
    reuses) is documented as blind to; closing it here rather than shipping a coupling instrument that
    cannot see its own primary subject's real edges."""
    declared = _class_name_declarations(root)
    sim_declared = {name: path for name, path in declared.items()
                     if len(path.parts) >= 2 and path.parts[0] == "sim"}
    if not sim_declared:
        return []
    name_res = {name: re.compile(r'\b' + re.escape(name) + r'\b') for name in sim_declared}
    edges = []
    for p in (root / "sim").rglob("*.gd"):
        rel = p.relative_to(root)
        src = module_of(rel)
        if src is None:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for name, declaring_path in sim_declared.items():
            if declaring_path == rel:
                continue  # a file always "uses" its own name; not a cross-file edge
            dst = module_of(declaring_path)
            if dst is not None and dst != src and name_res[name].search(text):
                edges.append((src, dst))
    return edges


def _sim_edges(root: Path) -> list[tuple[str, str]]:
    return _sim_path_edges(root) + _sim_class_name_edges(root)


def _tools_edges(root: Path) -> list[tuple[str, str]]:
    modules = _tools_modules(root)
    by_module_files = {m: {f.stem for f in (root / "tools" / m).glob("*.py")} for m in modules}
    edges = []
    for m in modules:
        for p in (root / "tools" / m).glob("*.py"):
            try:
                tree = ast.parse(p.read_text(encoding="utf-8", errors="replace"))
            except SyntaxError:
                continue
            names = set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    names.update(alias.name.split(".")[0] for alias in node.names)
                elif isinstance(node, ast.ImportFrom) and node.module:
                    names.add(node.module.split(".")[0])
            for name in names:
                if name in by_module_files[m]:
                    continue  # resolves locally -- sys.path.insert(0, parent) means local always wins
                matches = [o for o in modules if o != m and name in by_module_files[o]]
                if len(matches) == 1:
                    edges.append((m, matches[0]))
                # zero matches: an external library, not this repo's own code -- not an edge.
                # more than one match: ambiguous by filename alone -- not counted, not guessed.
    return edges


def analyze(root: Path | None = None) -> dict:
    """`root` defaults to the real repository (ROOT) -- pointable at a scratch directory for tests, the
    same reason tools/anvil/check_integrity.py's check_integrity(log_dir) takes its directory as a
    parameter rather than hardcoding it."""
    root = ROOT if root is None else root
    result = {}
    for scope, module_list, edge_fn in (("sim", _sim_modules, _sim_edges),
                                          ("tools", _tools_modules, _tools_edges)):
        modules = module_list(root)
        edges = edge_fn(root)
        fan_out = {m: len({d for s, d in edges if s == m}) for m in modules}
        fan_in = {m: len({s for s, d in edges if d == m}) for m in modules}
        out_fence = iqr_outlier_fence(list(fan_out.values()))
        in_fence = iqr_outlier_fence(list(fan_in.values()))
        outliers = []
        for m in modules:
            reasons = []
            if fan_in[m] > in_fence:
                reasons.append(f"fan-in {fan_in[m]} > fence {in_fence:.1f}")
            if fan_out[m] > out_fence:
                reasons.append(f"fan-out {fan_out[m]} > fence {out_fence:.1f}")
            if reasons:
                outliers.append((m, reasons))
        result[scope] = {
            "modules": modules, "fan_in": fan_in, "fan_out": fan_out,
            "fan_in_stats": summarize(list(fan_in.values())),
            "fan_out_stats": summarize(list(fan_out.values())),
            "outliers": outliers,
        }
    return result


def format_report(result: dict) -> str:
    lines = ["coupling: fan-in/fan-out per submodule, real code references only -- see module docstring "
             "for the two scanners' distinct blind spots."]
    for scope, label in (("sim", "sim/"), ("tools", "tools/")):
        r = result[scope]
        lines.append(f"\n{label}: {len(r['modules'])} module(s)")
        for m in sorted(r["modules"], key=lambda m: -(r["fan_in"][m] + r["fan_out"][m])):
            lines.append(f"    {m:16s} fan-in {r['fan_in'][m]:2d}  fan-out {r['fan_out'][m]:2d}")
        if r["outliers"]:
            lines.append(f"  {len(r['outliers'])} module(s) drifting toward a hub:")
            for m, reasons in r["outliers"]:
                lines.append(f"    {m}: {', '.join(reasons)}")
        else:
            lines.append("  No module's fan-in or fan-out is an outlier against the rest of this scope.")
    return "\n".join(lines)


def main() -> int:
    return run_cli(analyze, format_report)


if __name__ == "__main__":
    sys.exit(main())
