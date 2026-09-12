# harness/scenario

## Purpose

The declarative fixture format for a run: seed, rig state, goal, budget.
Schema-validated at build time — a malformed scenario fails before it ever
reaches the driver, not partway through a run.

Every scenario names a claim ID. A scenario with no claim does not merge.
This is the mechanism that keeps `scenarios/` (where the fixture files
themselves live) tied to `claims/` (where design claims live) rather than
drifting into a pile of ad hoc test levels nobody remembers the purpose of.

## Dependencies

`interface`, `sim`, `core` (a scenario's `rig state` and `goal` fields are
expressed in terms of sim/interface types).

## Consumers

`harness/driver` (loads and runs a scenario), `experiment/claims_runner`
(resolves a claim ID to the scenario(s) that exercise it).

## Relationship to `scenarios/`

This directory holds the format: schema, loader, validator. `scenarios/`
(top-level, sibling to `harness/`) holds the actual fixture files written
against that format. Format and content are deliberately separated so the
format can be versioned independently of the (much larger, faster-growing)
set of fixtures.

## Public API

The loader is codegen, not a parser: `tools/data_codegen/generate.py` translates
`scenarios/*.yaml` into `scenarios/generated.gd` (`ScenarioRecords.RECORDS`, keyed by `name`),
the same way `data/` records are generated -- gate 22's freshness check covers it, and
`scenarios/SCHEMA.yaml` is validated by `tools/schema_validator` (gate 13). No GDScript YAML
parser exists or is wanted.

## Gotchas

None yet.
