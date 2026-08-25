# sim/run

## Purpose

Run lifecycle: `MetaIdle -> SiteSelect -> RunConfig -> RunActive ->
RunEnding -> RunResolved`. Owns the flood clock, which is driven by rig
state (implements the rule that run length is a purchased resource, R3),
termination, and extraction resolution.

## Must-not

- Know about menus. No UI concepts here — lifecycle state is data that
  `view`/`shell` render, not something this module presents.
- Know about saves. Persisting run/meta state across process launches is
  `shell`'s job; `run` just produces the state that gets saved.

## Dependencies

`core` and the gameplay submodules it sits above: `world`, `terrain_gen`
(generates the shaft at run start), `body`, `items`, `machines`,
`behaviors`, `transport`, `fluid`, `economy` (extraction resolution
converts hauled items to value).

Deliberately *not* declared as a dependency: `sim/meta`. R3's "flood clock
driven by rig state" implies `run` needs to read rig state that lives in
`meta`, but `meta` also needs to read run results (to update stockpile),
which would make `run -> meta` and `meta -> run` both true — a cycle.
Flagged as unresolved: the likely resolution is that rig state is handed
to `run` as data at `RunConfig` time (via a command), and run results are
read back out by whatever orchestrates the meta/run transition, so neither
sim submodule depends on the other directly. Not asserted as fact here,
just kept out of both dependency lists so nothing forecloses it.

## Consumers

`interface`, at minimum, which is what surfaces run phase and state via
`observe()`. No sim-internal consumer is declared — see the note above.

## Tick phase

Not itself a tick phase. `run` is the lifecycle state machine that governs
*whether* the fixed tick loop runs at all (only during `RunActive`), not a
phase within it.

## Public API

None yet.

## Gotchas

See the `meta` dependency note above — this is the most consequential open
question in `sim/`'s dependency graph.
