# sim/commands

## Purpose

The complete typed command vocabulary — the only way anything mutates the
sim. This is the L2 interface's `apply(Command) -> Result` target: commands
are typed values, submitted from outside `sim/` (via `interface`), and
validated/applied by the submodules they target.

## Must-not

- Contain logic. Commands are typed values (structs/enums with payloads),
  not behavior. Validation and application happen in `interface` and in
  each target submodule, not here.

## Dependencies

`core` only. Command payloads reference `core` primitives (fixed-point
values, generational entity IDs) but do not depend on `items`/`machines`/
etc. for their own types — this is what keeps `commands` a leaf module that
every gameplay submodule can be matched against without a cycle.

## Consumers

`interface`, primarily — this is literally its `apply(Command)` parameter
type. Sim-internal: every submodule with mutating behavior (`world`,
`body`, `items`, `machines`, `transport`, `run`, `meta`, ...) matches
against the command types it cares about to implement its own mutations.

## Tick phase

Not tick-phase code. Commands are consumed during the `input` phase (or,
for out-of-run actions, via `apply()` outside the fixed tick loop
entirely) — they aren't a phase's logic themselves, just the vocabulary
that phase acts on.

## Public API

None yet.

## Gotchas

None yet.
