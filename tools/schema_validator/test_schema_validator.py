#!/usr/bin/env python3
"""Mutation tests for schema_validator.py (QUALITY gate 13) -- the first it has had (D0346).

    python3 tools/schema_validator/test_schema_validator.py

The validator ran for eleven days with no test observing any of its branches fire. A' step 3 added a
`forbidden:` rule so `data/machines` can REJECT `craft_cost`/`craft_count` (the dead one-time-purchase
economy, ruled out "as a craft_cost data field"), and a rule that has never been seen refusing anything is
documentation, not enforcement -- the exact gap `data/materials/SCHEMA.yaml`'s own comment admitted. So
this observes every branch of `validate_file`: the new forbidden rule firing and NOT firing, and the two
pre-existing rules (missing required, wrong type) as positive controls, plus the stated boundary that an
UNKNOWN field is still accepted -- recorded so nobody reads "forbidden works" as "strict".
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layer_lint"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_test_support import Observations  # noqa: E402
from schema_validator import ROOT, validate_file  # noqa: E402

LOG = Observations("test_schema_validator")

SCHEMA = {
    "fields": {"id": {"required": True, "type": "str"}, "fuel_ticks": {"required": False, "type": "int"}},
    "forbidden": {"craft_cost": "the one-time-purchase economy is dead"},
}


def errors_for(body: str) -> list[str]:
    # validate_file prints paths relative to ROOT, so the scratch file lives under ROOT's own tmp-safe
    # scratch area rather than /tmp (a path outside ROOT makes relative_to raise, which is not a branch
    # of the validator this file is about).
    scratch = ROOT / "tools" / "scratch"
    scratch.mkdir(exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", dir=scratch, delete=False, encoding="utf-8") as f:
        f.write(body)
        path = Path(f.name)
    try:
        return validate_file(path, SCHEMA)
    finally:
        path.unlink()


def main() -> int:
    e = errors_for("id: drill\ncraft_cost: {ingot: 2}\n")
    LOG.observe("a forbidden field FAILS the record", len(e) == 1 and "FORBIDDEN" in e[0], "; ".join(e))
    LOG.observe("...and the failure carries the schema's stated reason",
                bool(e) and "one-time-purchase economy is dead" in e[0])
    e = errors_for("id: drill\nfuel_ticks: 60\n")
    LOG.observe("the same record without the forbidden field passes", e == [], "; ".join(e))
    e = errors_for("id: drill\nunlisted_field: 7\n")
    LOG.observe("BOUNDARY: a field the schema neither lists nor forbids is still accepted (not strict)",
                e == [], "; ".join(e))
    e = errors_for("fuel_ticks: 60\n")
    LOG.observe("positive control: a missing required field fails", len(e) == 1 and "missing required" in e[0],
                "; ".join(e))
    e = errors_for("id: drill\nfuel_ticks: sixty\n")
    LOG.observe("positive control: a wrong-typed field fails", len(e) == 1 and "should be int" in e[0],
                "; ".join(e))
    e = errors_for("- not\n- a\n- mapping\n")
    LOG.observe("a non-mapping document fails before any field rule runs", len(e) == 1 and "mapping" in e[0])
    no_forbidden = {"fields": SCHEMA["fields"]}
    scratch = ROOT / "tools" / "scratch"
    scratch.mkdir(exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", dir=scratch, delete=False, encoding="utf-8") as f:
        f.write("id: drill\ncraft_cost: {ingot: 2}\n")
        path = Path(f.name)
    try:
        e = validate_file(path, no_forbidden)
    finally:
        path.unlink()
    LOG.observe("a schema with no forbidden block accepts craft_cost (the rule is opt-in per kind)", e == [])
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
