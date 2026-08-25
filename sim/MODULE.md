# sim

The gameplay simulation. Fourteen submodules, each with its own MODULE.md:
`world`, `terrain_gen`, `body`, `items`, `machines`, `behaviors`,
`transport`, `fluid`, `economy`, `run`, `meta`, `commands`, `telemetry`,
`invariants`.

## Sim-wide rules (apply to every submodule below)

- Fixed timestep, 60Hz. The sim never sees `delta` — no submodule takes a
  variable frame time as an argument or reasons about wall-clock elapsed
  time. Time is tick count.
- Fixed tick phase order, every tick:
  `input -> body -> machines -> transport -> items -> fluid -> economy ->
  invariants -> telemetry`.
  A submodule's own MODULE.md says which phase (if any) its logic runs in.
  Not every submodule is itself a phase — see `commands` and `telemetry`.
- No engine imports (no Godot types/nodes/singletons) anywhere under `sim/`.
- No file IO anywhere under `sim/`.
- No wall clock anywhere under `sim/`.
- No global mutable state anywhere under `sim/`.
- Deterministic: same seed + same command log -> same resulting state,
  bit-for-bit, every time. This is what makes the harness's replay and
  state-hash comparisons meaningful.

## Dependencies

`core`, always. Cross-submodule dependencies are declared individually in
each submodule's own MODULE.md and are directional only — `sim/` has no
internal cycles.

## Consumers

`interface` (L2) is the only thing outside `sim/` allowed to touch it
directly, via `apply(Command)` / `observe(envelope)`. Nothing above
`interface` calls into `sim/` directly.

## Public API

None yet. This directory and its submodules are skeletons — no code has
been written.

## Gotchas

None yet.
