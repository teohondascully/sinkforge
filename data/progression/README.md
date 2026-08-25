# data/progression

## Purpose

Meta-progression / unlock data — what's unlocked, in what order, at what
cost. Read by `sim/meta`, which owns persistent rig state and unlocks but
must never mutate run state directly.

## Schema (informal, not yet fixed)

- `id` — stable identifier for an unlock.
- Prerequisites / ordering.
- Cost, in terms of `data/materials`/stockpile.
- What the unlock actually changes (a `data/machines` entry becomes
  available, a rig parameter changes, etc.).

## Consumers

`sim/meta` exclusively, as far as is known now.

## Public API

None yet. No schema has been finalized or validated yet.

## Gotchas

None yet.
