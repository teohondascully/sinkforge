# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

**Stage 3 (`sim/world`, `sim/terrain_gen`) landed. Stopped here, deliberately, per explicit instruction:
do not begin stage 4 (`sim/body`) even with budget remaining.** 7 of 12 commits used:
`sim/world` (`c3fb970`), `SplitRng.next_float()`/`.next_range()` (`b30eeab`), a real gap closed in
`no_engine_imports.py` before it could matter (`d68ba29`, D0023), `ValueNoise` (`8b8097a`),
`ShaftGenerator`/`StrataData` (`1a585a7`), the constant-count report (`250063f`, D0025) — plus the data
layer from before this stage's code (`b2142e2`). `docs/DECISIONS_LEDGER.md` D0016-D0025 carry every
judgment call's full reasoning; this section is the pointer, not the record. Next session (or next
instruction) starts stage 4 fresh, or redirects.

## Landed and closed, with commit references

- Stages 1 and 2 (`core/`'s `Fx`/`SplitRng`/`EntityIdPool`, `tests/test_replay_determinism.gd`) —
  `560ee78`, `f51d722`. Detail in `docs/DECISIONS_LEDGER.md` D0005-D0015.
- **Stage 3 landed**: `sim/world` (`TileGrid`, sparse and not chunked on purpose — D0019 — plus
  `WorldMaterials`) and `sim/terrain_gen` (`ShaftGenerator`, `StrataData`, `ValueNoise`) — depth-banded
  base rock into the three `docs/GDD.md` §11 layers, cave carving, ore/coal/iron vein scattering, one
  empty ruin chamber. Port scope is a real subset of legacy (D0017): 29 of the cited 118 tuning constants
  carried over by value, 22 of those actually consumed by the generator today (D0025) — reported, not
  smoothed over. A real architectural gap was found and closed mid-stage, not worked around:
  `tools/layer_lint/no_engine_imports.py` didn't catch `FastNoiseLite`/`RandomNumberGenerator`, both real
  Godot engine classes legacy's generator depends on and `sim/` cannot (D0023) — `ValueNoise` is the
  from-scratch, engine-free replacement, calibrated to the same [-1, 1] output range so the ported
  threshold constants keep their original meaning. `SplitRng` gained `next_float()`/`next_range()`,
  needed by any RNG consumer, not just this one. Mutation-testing this stage surfaced its own finding
  (D0024): a full-generation integration test can pass even with a real safety guard removed, if the
  guard's own trigger condition is rare at generation scale — two guards needed a targeted unit test
  built specifically to force them, not just a test that runs code containing them.
- Task 0 (repository restructuring), context-compaction protocol, claim-rot mechanisms, movement/
  collision architecture decisions, Freight Winch gate, Sinkforge-as-stratum/layers-as-rule-sets/9-run
  curve/R1 scope ADR-0002, review-bandwidth and playable-fixtures protocols, doc triage, the LOC-ratio
  gate's rewrite as a trailing-window trend measure, clone-size Phase 1 (withdrawn), `docs/handoff/`
  (deferred) — all from earlier this session. Detail in those commits' messages and
  `docs/DECISIONS_LEDGER.md` D0001-D0004, D0016, not repeated here.

## Discoveries not yet written anywhere durable

None outstanding. Everything found during Stage 3 is already in `docs/DECISIONS_LEDGER.md` (D0016-D0025)
or `sim/terrain_gen/MODULE.md`'s/`sim/world/MODULE.md`'s Gotchas. Anything found during stage 4 gets
logged here or to the ledger immediately, not batched.
