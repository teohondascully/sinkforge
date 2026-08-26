# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

**Stage 3 (`sim/world`, `sim/terrain_gen`) landed AND its post-landing review is closed.** The director
ran a direct resolution-split test before clearing stage 4 (`sim/body`): pick three `sim/world` functions
at random, say from name/signature alone whether each is unambiguous about 4px terrain vs. 16px logic
grid. 2 of 3 were clean; `occupied_cells() -> Array` was not (bare, untyped, name didn't say "terrain"
either) — fixed to `occupied_terrain_cells() -> Array[Vector2i]` (`c9742ef`, D0027). Two other findings
from stage 3 were generalized into normative rules rather than left as ledger-only lessons:
`tools/layer_lint/no_engine_imports.py` rewritten from a full `ClassDB` audit instead of accumulated-by-
tripping-on-it patterns (`db8e448`, D0026), and both this and the mutation-testing-at-integration-scale
finding (D0024) are now `docs/QUALITY.md` §2 rules, not just ledger entries. Also this round: the 7
declared-but-unconsumed generation constants nested under `pending_sim_economy` so "unread" is structural
(`46a470e`), and `legacy/tools/*.uid` gitignored (`2605315`, housekeeping). Stage 4 has not started.
`docs/DECISIONS_LEDGER.md` D0016-D0027 carry every judgment call's full reasoning; this section is the
pointer, not the record.

## Landed and closed, with commit references

- Stages 1 and 2 (`core/`'s `Fx`/`SplitRng`/`EntityIdPool`, `tests/test_replay_determinism.gd`) —
  `560ee78`, `f51d722`. Detail in `docs/DECISIONS_LEDGER.md` D0005-D0015.
- **Stage 3 landed and reviewed**: `sim/world` (`TileGrid`, sparse and not chunked on purpose — D0019 —
  plus `WorldMaterials`) and `sim/terrain_gen` (`ShaftGenerator`, `StrataData`, `ValueNoise`) —
  depth-banded base rock into the three `docs/GDD.md` §11 layers, cave carving, ore/coal/iron vein
  scattering, one empty ruin chamber. Port scope is a real subset of legacy (D0017): 29 of the cited 118
  tuning constants carried over by value, 22 consumed by the generator today, the other 7 marked
  structurally pending rather than left as an unread comment (D0025, D0025-followup this round). Two
  real architectural gaps were found and closed, not worked around: `no_engine_imports.py` never checked
  for entire categories of engine coupling — first patched ad hoc for `FastNoiseLite`/
  `RandomNumberGenerator` (D0023), then rewritten wholesale from Godot's actual `ClassDB` (D0026) after
  the director asked "what else is it missing." A pre-stage-4 resolution-split test found one real gap
  in `sim/world`'s API (`occupied_cells`'s untyped return) and it's now fixed (D0027). Mutation-testing
  this stage surfaced its own finding (D0024, now a `docs/QUALITY.md` rule): a full-generation
  integration test can pass even with a real safety guard removed, if the guard's own trigger condition
  is rare at generation scale.
- Task 0 (repository restructuring), context-compaction protocol, claim-rot mechanisms, movement/
  collision architecture decisions, Freight Winch gate, Sinkforge-as-stratum/layers-as-rule-sets/9-run
  curve/R1 scope ADR-0002, review-bandwidth and playable-fixtures protocols, doc triage, the LOC-ratio
  gate's rewrite as a trailing-window trend measure, clone-size Phase 1 (withdrawn), `docs/handoff/`
  (deferred) — all from earlier this session. Detail in those commits' messages and
  `docs/DECISIONS_LEDGER.md` D0001-D0004, D0016, not repeated here.

## Discoveries not yet written anywhere durable

None outstanding. Everything found this round is already in `docs/DECISIONS_LEDGER.md` (D0026, D0027),
`docs/QUALITY.md` §2, or the relevant `MODULE.md`'s Gotchas. D0019 and D0020 (chunk size, coordinate type
scheme) remain open EXPENSIVE questions — the resolution-audit fix closed the one concrete instance the
test found, not the underlying naming-only enforcement risk both entries already named. Anything found
during stage 4 gets logged here or to the ledger immediately, not batched.
