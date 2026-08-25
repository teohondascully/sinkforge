# view

## Purpose

Renderer. Hangs off L2 (`interface`) as a peer of agents (`harness`),
never above L1 (`sim`). Reads observations, emits commands, never calls a
sim mutator directly — a human playing through `view` and a bot playing
through `harness/bots` go through the identical `apply()`/`observe()` door.

Has exactly one narrow reverse channel: frame capture -> vision model, for
legibility claims only. This is the one place `view` is allowed to feed
data back toward the research layer, and it's scoped tightly (a captured
frame, not a state read) so it can't become a second way to read sim state
around the envelope filter.

## Dependencies

`interface`, `core`.

## Must-not

- Call a sim mutator directly. All state changes go through
  `interface.apply()`.
- Read sim state directly. All reads go through `interface.observe()`.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
