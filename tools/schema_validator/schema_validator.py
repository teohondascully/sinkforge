#!/usr/bin/env python3
"""Schema validation for data/. docs/QUALITY.md gate 13, docs/ARCHITECTURE.md §8.

    python3 tools/schema_validator/schema_validator.py

Every `.yaml` file under `data/<kind>/` is validated against
`data/<kind>/SCHEMA.yaml` if one exists. A schema is a flat list of field
rules:

    fields:
      id:       {required: true, type: str}
      tier:     {required: true, type: int}
      build_cost: {required: false, type: dict}

Supported types: str, int, float, bool, list, dict. A schema may also carry a
`forbidden:` mapping of field name -> reason; a record naming one of those
fields FAILS, and the reason is printed with the failure (D0346 -- the first
use is `craft_cost`/`craft_count` in data/machines, the dead one-time-purchase
economy the director ruled must not come back "as a craft_cost data field").
Fields the schema neither lists nor forbids are still accepted: this validator
does not reject unknown fields, and that boundary is stated here rather than
assumed closed. This is deliberately not
a full JSON-Schema implementation — docs/ARCHITECTURE.md §8 asks for
"schema-validated at build time" so a malformed data file fails the build,
not a general-purpose validation framework. If nested-structure validation
is ever needed, that is a real extension, not a workaround to add here
silently.

A `data/<kind>/` directory with no SCHEMA.yaml is reported, not silently
skipped: an unvalidated data kind is a gap, and this tool says so out loud
rather than converting "no schema" into "nothing to check."
"""
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("schema_validator: PyYAML is not installed. `pip install pyyaml`.", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"

TYPE_MAP = {"str": str, "int": int, "float": (int, float), "bool": bool, "list": list, "dict": dict}


def validate_file(data_path: Path, schema: dict) -> list[str]:
    errors = []
    try:
        doc = yaml.safe_load(data_path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        return [f"{data_path.relative_to(ROOT)}: invalid YAML — {e}"]
    if not isinstance(doc, dict):
        return [f"{data_path.relative_to(ROOT)}: top level must be a mapping"]

    forbidden = schema.get("forbidden", {}) or {}
    for name in sorted(forbidden):
        if name in doc:
            errors.append(
                f"{data_path.relative_to(ROOT)}: field '{name}' is FORBIDDEN by the schema -- {forbidden[name]}"
            )
    fields = schema.get("fields", {})
    for name, rule in fields.items():
        if rule.get("required") and name not in doc:
            errors.append(f"{data_path.relative_to(ROOT)}: missing required field '{name}'")
            continue
        if name not in doc:
            continue
        expected = TYPE_MAP.get(rule.get("type"))
        if expected and not isinstance(doc[name], expected):
            errors.append(
                f"{data_path.relative_to(ROOT)}: field '{name}' should be {rule.get('type')}, "
                f"got {type(doc[name]).__name__}"
            )
    return errors


def main() -> int:
    if not DATA_DIR.is_dir():
        print("schema_validator: data/ does not exist yet — nothing to check.")
        print("schema_validator: PASS (vacuously)")
        return 0

    kinds = [d for d in DATA_DIR.iterdir() if d.is_dir()]
    if not kinds:
        print("schema_validator: data/ has no subdirectories yet — nothing to check.")
        print("schema_validator: PASS (vacuously)")
        return 0

    all_errors = []
    unvalidated_kinds = []
    checked_files = 0

    for kind_dir in sorted(kinds):
        schema_path = kind_dir / "SCHEMA.yaml"
        data_files = sorted(
            p for p in kind_dir.glob("*.yaml") if p.name != "SCHEMA.yaml"
        )
        if not data_files:
            continue
        if not schema_path.is_file():
            unvalidated_kinds.append(kind_dir.relative_to(ROOT).as_posix())
            continue
        schema = yaml.safe_load(schema_path.read_text(encoding="utf-8")) or {}
        for data_path in data_files:
            checked_files += 1
            all_errors.extend(validate_file(data_path, schema))

    print(f"schema_validator: {checked_files} data file(s) checked against a schema")
    if unvalidated_kinds:
        print(f"schema_validator: {len(unvalidated_kinds)} data kind(s) have files but no SCHEMA.yaml:")
        for k in unvalidated_kinds:
            print(f"  GAP   {k} — files present, unvalidated")

    if all_errors:
        print(f"schema_validator: FAIL — {len(all_errors)} error(s)")
        for e in all_errors:
            print(f"  FAIL  {e}")
        return 1

    if unvalidated_kinds:
        # docs/QUALITY.md gate 13 is "every file in data/ validates" — a file with no
        # schema to check it against has not validated, it has merely not been examined.
        # Reporting that as PASS would be exactly the "nothing measured silently becomes
        # PASS" failure docs/QUALITY.md §2 names as the thing this project refuses to do.
        print("schema_validator: FAIL — data files exist with no schema to validate them against")
        return 1

    print("schema_validator: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
