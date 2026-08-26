# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

**Stage 3 (`sim/world`, `sim/terrain_gen`) landed and closed; a director-set pre-stage-4 punch list is
being worked through now.** After the stage-3 review closed (resolution-split test, `no_engine_imports`
ClassDB audit, mutation-testing generalization — all below), a full audit dump (README, ledger,
`git ls-files`, gate status, LOC numbers) surfaced four more items, gated explicitly "before stage 4, not
after": `Fx.length()`'s real 181px overflow (fixed, D0029), `data/`'s hand-mirrored YAML dual-source
problem (fixed via codegen + an ADR, D0021→D0030), the LOC ratio needing a stated target instead of a
feeling (this section, below), and the spot-audit sampling method itself being wrong (in progress). Two
smaller items (a ledger numbering rule, `BRIEF.md`'s regeneration timing) and one README correction round
out the list. `sim/body` (stage 4) has not started.

**LOC ratio target, set 2026-08-26 (director's ask, item 3 of the post-audit list):** absolute ratio
under 1.5 by the time `C001` passes. Current absolute ratio is 3.399 (instrument 2,328 / game 685,
measured after `bbc18fe`) — well above target, and the trailing-10-commit window shows the wrong
direction (instrument +363, game −39: the YAML-codegen refactor net-shrank hand-written game code, which
is real and good, but the same window's `tools/` growth outpaced it). This is a finding stated plainly,
not smoothed: at stage 3's close, absolute ratio is more than double the target it needs to hit by
`C001`, and `check_loc_ratio.py` is still ADVISORY (game LOC under its 2,000-line floor) so nothing
gates on it yet. Every `docs/BRIEF.md` from now on reports absolute ratio plus trailing velocity, whether
or not the gate is advisory that session — this is a standing reporting obligation, not a one-time note.
If the ratio is still above 2 when stage 7 lands, that has to be stated as a finding in that session's
brief, not narrated around.

`docs/DECISIONS_LEDGER.md` D0016-D0030 carry every judgment call's full reasoning; this section is the
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
- **`Fx.length()`/`Fx.length_sq()`'s real 181px overflow, fixed** (`297b6aa`, D0029, supersedes D0011's
  scope decision): the director found D0011's "local-neighborhood only" scope was wrong, not just
  narrow — `sim/body`'s grapple, rope, and camera-relative queries have no reason to stay under 11.3m,
  and the failure mode is a silently wrong distance, not an error. Cause: squared terms were reduced
  through `mul()`'s i32 wrap before summing. Fix: accumulate raw `dx*dx+dy*dy` in a native i64, `isqrt()`
  directly — verified in Python that the absolute worst case across `Fx`'s entire range stays under i64
  max with room to spare. Mutation-tested against D0011's exact old formula (12 assertions failed on it,
  confirming the new tests catch the regression) before trusting the fix.
- **`data/materials`/`data/strata`'s hand-mirrored YAML dual-source problem, resolved** (`348a79c` ADR
  0004, `bbc18fe` D0021→D0030): `tools/data_codegen/generate.py` reads `data/<kind>/*.yaml` and emits a
  checked-in `data/<kind>/generated.gd`; `--check` mode is the new staleness gate (`docs/QUALITY.md` gate
  22), mutation-tested in both directions (source edited without regenerating; generated file hand-edited
  directly) before trusting it. `sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` now read
  from the generated records; their public APIs are unchanged. `data/` is the actual source of truth now.
- Task 0 (repository restructuring), context-compaction protocol, claim-rot mechanisms, movement/
  collision architecture decisions, Freight Winch gate, Sinkforge-as-stratum/layers-as-rule-sets/9-run
  curve/R1 scope ADR-0002, review-bandwidth and playable-fixtures protocols, doc triage, the LOC-ratio
  gate's rewrite as a trailing-window trend measure, clone-size Phase 1 (withdrawn), `docs/handoff/`
  (deferred) — all from earlier this session. Detail in those commits' messages and
  `docs/DECISIONS_LEDGER.md` D0001-D0004, D0016, not repeated here.

## Discoveries not yet written anywhere durable

The director's post-audit spot-audit-methodology finding (item 4): `git log | shuf -n 1` samples the
entire history, not just the ledger-covered portion, and the first attempt drew a commit that predates
`docs/DECISIONS_LEDGER.md`'s own creation — a null result, not a real audit. Fix in progress: a `tools/`
script constraining the sample to `bea703d..HEAD`, run by the director, never by this session. Remaining
after that: the ledger-numbering-rule header addition, `BRIEF.md`'s regeneration-timing rule, and the
README stage-count correction ("stage 3 of 12" → "stage 3 of 7 toward `C001`"). All are small and
already scoped; none are new findings requiring their own ledger entries. D0019 and D0020 (chunk size,
coordinate type scheme) remain open EXPENSIVE questions, unchanged this round. Anything found during
stage 4 gets logged here or to the ledger immediately, not batched.
