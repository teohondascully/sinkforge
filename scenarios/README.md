# scenarios

## Purpose

Declarative test fixtures — the actual scenario files referenced by
`harness/scenario`'s format. Each one names a claim ID. This directory
holds the fixtures themselves; `harness/scenario/` holds the
format/schema/loader code that reads them.

## Consumers

`harness/driver` (loads and runs a fixture from here), `experiment/*`
(everything in `experiment/` ultimately points at scenarios living in this
directory).

## Public API

None yet. No fixture files exist yet, and `harness/scenario`'s format
isn't finalized.

## Gotchas

None yet.
