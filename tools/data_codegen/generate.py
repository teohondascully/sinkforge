#!/usr/bin/env python3
"""Build-time codegen: data/<kind>/*.yaml -> data/<kind>/generated.gd. docs/adr/0004-data-codegen.md.

    python3 tools/data_codegen/generate.py          # (re)writes every generated.gd that is missing or stale
    python3 tools/data_codegen/generate.py --check  # gate mode (docs/QUALITY.md gate 22): writes nothing,
                                                     # fails if any generated.gd would change

For every data/<kind>/ directory whose SCHEMA.yaml declares a required `id: str` field, reads every
sibling *.yaml file (excluding SCHEMA.yaml itself) and emits one data/<kind>/generated.gd: a
`<Kind>Records` class holding one `const RECORDS: Dictionary`, keyed by each record's own `id`, valued by
that record's full YAML content translated 1:1 into GDScript literal types (str/int/float/bool/list/dict,
recursively, same structure as the source). No field renaming, no StringName conversion, no computed
defaults -- this stays a literal, mechanical translation on purpose. Anything a consumer needs beyond the
raw record belongs in a thin, hand-written adapter reading from RECORDS (see sim/world/materials.gd,
sim/terrain_gen/strata_data.gd), not in this script.

A data/<kind>/ directory with files but no SCHEMA.yaml, or a SCHEMA.yaml without a required `id: str`
field, is simply not codegen-eligible -- reported as skipped, not silently ignored.
"""
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("data_codegen: PyYAML is not installed. `pip install pyyaml`.", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"


def to_pascal_case(kind: str) -> str:
    return "".join(part.capitalize() for part in kind.split("_"))


def gdscript_literal(value, indent: int) -> str:
    pad = "\t" * indent
    inner_pad = "\t" * (indent + 1)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    if value is None:
        return "null"
    if isinstance(value, list):
        if not value:
            return "[]"
        items = ",\n".join(f"{inner_pad}{gdscript_literal(v, indent + 1)}" for v in value)
        return "[\n" + items + f",\n{pad}]"
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = ",\n".join(
            f'{inner_pad}"{k}": {gdscript_literal(v, indent + 1)}' for k, v in value.items()
        )
        return "{\n" + items + f",\n{pad}}}"
    raise TypeError(f"data_codegen: unsupported YAML value type {type(value)!r} for {value!r}")


def id_field_is_eligible(schema: dict) -> bool:
    id_rule = schema.get("fields", {}).get("id", {})
    return bool(id_rule.get("required")) and id_rule.get("type") == "str"


def load_records(kind_dir: Path) -> dict | None:
    schema_path = kind_dir / "SCHEMA.yaml"
    if not schema_path.is_file():
        return None
    schema = yaml.safe_load(schema_path.read_text(encoding="utf-8")) or {}
    if not id_field_is_eligible(schema):
        return None

    data_files = sorted(p for p in kind_dir.glob("*.yaml") if p.name != "SCHEMA.yaml")
    if not data_files:
        return None

    records: dict = {}
    for data_path in data_files:
        doc = yaml.safe_load(data_path.read_text(encoding="utf-8"))
        if not isinstance(doc, dict) or "id" not in doc:
            raise ValueError(f"{data_path.relative_to(ROOT)}: no top-level 'id' field to key RECORDS by")
        records[doc["id"]] = doc
    return records


def render(kind: str, records: dict) -> str:
    class_name = f"{to_pascal_case(kind)}Records"
    lines = [
        "# GENERATED FILE -- do not edit by hand.",
        f"# Source: data/{kind}/*.yaml. Regenerate with:",
        "#   python3 tools/data_codegen/generate.py",
        "# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if",
        "# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.",
        f"class_name {class_name}",
        "extends RefCounted",
        "",
        "const RECORDS: Dictionary = {",
    ]
    for record_id in sorted(records):
        value = gdscript_literal(records[record_id], 1)
        lines.append(f'\t"{record_id}": {value},')
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    check_mode = "--check" in sys.argv[1:]

    if not DATA_DIR.is_dir():
        print("data_codegen: data/ does not exist yet -- nothing to generate.")
        return 0

    kind_dirs = sorted(d for d in DATA_DIR.iterdir() if d.is_dir())
    eligible = 0
    skipped = []
    stale = []
    written = []

    for kind_dir in kind_dirs:
        kind = kind_dir.name
        try:
            records = load_records(kind_dir)
        except ValueError as e:
            print(f"data_codegen: FAIL -- {e}", file=sys.stderr)
            return 2
        if records is None:
            if (kind_dir / "SCHEMA.yaml").is_file() and list(kind_dir.glob("*.yaml")):
                skipped.append(kind)
            continue

        eligible += 1
        rendered = render(kind, records)
        out_path = kind_dir / "generated.gd"
        current = out_path.read_text(encoding="utf-8") if out_path.is_file() else None
        if current == rendered:
            continue
        if check_mode:
            stale.append(out_path.relative_to(ROOT).as_posix())
        else:
            out_path.write_text(rendered, encoding="utf-8")
            written.append(out_path.relative_to(ROOT).as_posix())

    print(f"data_codegen: {eligible} codegen-eligible data kind(s) found under data/")
    if skipped:
        print(f"data_codegen: {len(skipped)} kind(s) have data files but no eligible SCHEMA.yaml "
              f"(no required 'id: str' field): {', '.join(skipped)}")

    if check_mode:
        if stale:
            print(f"data_codegen: FAIL -- {len(stale)} generated file(s) stale or missing:")
            for p in stale:
                print(f"  STALE {p}")
            print("data_codegen: run `python3 tools/data_codegen/generate.py` and commit the result.")
            return 1
        print("data_codegen: PASS -- all generated files match their source")
        return 0

    if written:
        print(f"data_codegen: wrote {len(written)} file(s): {', '.join(written)}")
    else:
        print("data_codegen: nothing to regenerate, already up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
