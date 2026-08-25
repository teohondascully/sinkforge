# core

## Purpose

Fixed-point arithmetic (i32, 16 fractional bits), a seeded splittable RNG (one
stream per subsystem; streams are serialized state, not wall-clock seeded),
and generational-index entity IDs. Small, pure, fully unit-tested. Every
other layer in the stack (sim, interface, harness, experiment, view, shell)
depends on this one; this one depends on nothing.

## Dependencies

None. This is the floor of the stack.

## Consumers

Every other layer: sim, interface, harness, experiment, view, shell.

## Invariants

- No engine imports (no Godot types, nodes, or singletons).
- No file IO.
- No wall clock — no `OS.get_ticks_*`, no `Time` singleton, nothing that
  reads real-world time on any path that affects state.
- No global mutable state. RNG streams are values the caller owns and
  threads through explicitly, not statics.
- No `sin`/`cos`/`pow` (or any other transcendental/floating-point-only
  function) on a path that affects simulation state. Determinism across
  platforms depends on this module staying pure fixed-point integer math.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
