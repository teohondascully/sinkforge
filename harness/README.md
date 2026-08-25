# harness

## Purpose

Makes runs happen, and makes them comparable across agents, humans, and
seeds. This is where "an automated agent plays the sim headlessly to
produce evidence about design decisions" actually happens — everything
under this directory drives the sim through `interface`, the same door a
human player uses via `view`.

## Dependencies

`interface`, `sim`, `core`. May do file IO and process control (this layer
boots headless processes and writes result artifacts to disk — that's its
job).

## Must-not

- Depend on `view`. Harness runs headless; nothing here should require a
  renderer to exist.

## Two clocks

- **Fast loop**: deterministic scripted bots, small scenarios, runs on
  every PR, gates CI, under 60 seconds total.
- **Slow loop**: thousands of runs across seeds/envelopes, runs nightly,
  statistical, non-gating. The slow loop must never be allowed to gate CI —
  if a fast-loop check ever depends on a slow-loop result, that's a bug in
  the harness, not a reason to make the slow loop faster.

## Subdirectories

- `scenario/` — declarative fixture format (seed, rig state, goal, budget).
- `envelope/` — agent capability definitions (oracle/constrained/language).
- `driver/` — headless boot, tick loop, budget enforcement.
- `aggregate/` — telemetry -> metrics -> report artifacts.
- `bots/` — the scripted/planner/language agents themselves.

Each has its own README.md.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
