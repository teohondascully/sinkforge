`schema_validator.py` validates every `.yaml` file under `data/<kind>/` against `data/<kind>/SCHEMA.yaml`
if one exists. A `data/<kind>/` directory holding files with no `SCHEMA.yaml` is a FAIL, not a skip —
an unvalidated file has not passed, it has merely not been examined, and this tool refuses to report
that as a pass (`docs/QUALITY.md` §2, "no layer may silently convert 'nothing measured' into PASS").

Deliberately not a full JSON-Schema implementation: a schema is a flat `fields:` map of
`{required, type}` per field. `docs/ARCHITECTURE.md` §8 asks for "schema-validated at build time," not
a general validation framework — if nested-structure validation is ever needed, that's a real
extension to propose, not something to smuggle in here.

Requires `pyyaml` (`pip install pyyaml`; CI installs it as a workflow step).
