# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stage 3 (`sim/world`, `sim/terrain_gen`) closed; the director's pre-stage-4
punch list (four prioritized items, two smaller items, one README correction) is now fully closed.
Stage 4 (`sim/body`) has not started.**

---

## EXPENSIVE, awaiting you

None carried over as blocking. Two stay deliberately open, not resolved unilaterally:

- **Chunk size** (D0019) — `TileGrid` is a sparse `Dictionary`, correct regardless of what fixed size (if
  any) a later pass picks. Revisit once `sim/fluid` and `view/` exist enough to measure the three real
  costs it trades against.
- **Coordinate type scheme** (D0020) — working choice is naming-only (`terrain_` / `logic_` prefixes on
  plain `Vector2i`), now mechanically enforced by `check_coordinate_naming.py` (D0028). Two stronger
  typed alternatives remain proposed and NOT adopted — `RefCounted` wrapper types would cost a heap
  allocation per coordinate conversion, a bad trade against the sweep-loop perf budget (D0019/D0020
  addendum). Still open.

## What landed this round (the post-audit punch list, in the director's priority order)

1. **`Fx.length()`/`Fx.length_sq()`'s real 181px overflow, fixed** (`297b6aa`, D0029, supersedes D0011's
   scope decision — D0011 left as written). D0011 scoped these as "local-neighborhood only," justified as
   sufficient for `sim/body`'s needs; that justification was wrong, not just narrow — a grapple, a rope,
   and camera-relative queries have no reason to stay under 11.3m, and the failure mode is a silently
   wrong distance, not an error. Cause: squared terms were reduced through `mul()`'s i32 wrap before
   summing. Fix: accumulate raw `dx*dx+dy*dy` in a native i64, `isqrt()` directly — verified in Python
   that the absolute worst case across `Fx`'s entire representable range (`2*(2^31-1)²`) stays under i64
   max with room to spare. Mutation-tested against D0011's exact old formula before trusting it: 12
   assertions failed on the old code, confirming the new tests catch the regression.
2. **`data/materials`/`data/strata`'s hand-mirrored YAML dual-source problem, resolved** (`348a79c` ADR
   0004, `bbc18fe` D0021→D0030). `tools/data_codegen/generate.py` reads `data/<kind>/*.yaml` for every
   kind whose schema requires an `id: str` field, and emits a checked-in `data/<kind>/generated.gd`.
   `--check` mode is the new gate (`docs/QUALITY.md` gate 22) — mutation-tested in both directions
   (source edited without regenerating; generated file hand-edited directly) before trusting it.
   `sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` now read from the generated records;
   their public APIs are unchanged, so nothing outside these two files needed to change. One verified-
   inert leaf change: string fields nested inside a record are `String` now, not `StringName` — grepped
   `sim/` and `tests/` first to confirm nothing reads those specific fields today.
3. **LOC ratio given a target and a date, not a feeling.** `docs/WORKING.md` now states: absolute ratio
   under 1.5 by the time `C001` passes. See Gates below for the current number, stated plainly rather
   than smoothed.
4. **Spot-audit methodology fixed** (`5cbc2ab`). The original instruction (`git log | shuf -n 1`) samples
   the entire history, not just the ledger-covered portion — the first draw landed on a pre-ledger commit
   and tested nothing. `tools/spot_audit.py` derives `docs/DECISIONS_LEDGER.md`'s own creation commit
   from git history (not a hardcoded hash) and samples uniformly from commits after it. `CONTEXT.md` now
   states explicitly that this is run by the director, never by the session being audited.
5. **Ledger numbering rule added** (`f3a8c05`). D0004 appears twice under the same number; the header now
   states that a resolution or follow-up always gets a fresh number pointing back, never reuses one. The
   existing D0004 pair and the compound "D0019/D0020" addendum are left exactly as written — the ledger
   is append-only.
6. **`docs/BRIEF.md` regenerates at the last action before reporting, not an arbitrary session boundary**
   (`5cbc2ab`) — this brief is itself the first one written under that rule.
7. **README stage line corrected** (`e24cbd9`). "Stage 3 of 12" understated where the project is; now
   "stage 3 of 7 toward `C001`, the first playable milestone," with the remaining stages (5 through 12)
   named separately rather than folded into one count. Note: `ONBOARDING.md`'s own text names stage 12
   itself "Close C001" — your framing that "stages 8-12 are past the C001 milestone" isn't fully
   reconciled with that, and the README's wording sidesteps rather than resolves the tension by not
   asserting which stages are or aren't "part of" C001. Flagging this rather than picking a side quietly.

## Also landed this round, before the punch list (already reported, unchanged since)

- Stage 3 build: `sim/world` (`TileGrid`, `WorldMaterials`), `sim/terrain_gen` (`ShaftGenerator`,
  `StrataData`, `ValueNoise`); the resolution-split test and its one real fix (`occupied_cells` →
  `occupied_terrain_cells`, D0027); `no_engine_imports.py` rewritten from a full `ClassDB` audit (D0026);
  `check_coordinate_naming.py` added as a gate (D0028); the full README rewrite (`906c40e`); the
  audit-dump review (README, ledger, `git ls-files`, gate status, LOC numbers, the spot-audit that found
  its own methodology bug).

## Gates

All 8 PASS. `layer_lint`, `no_engine_imports`, `check_coordinate_naming`, `check_size_limits` (19 files),
`schema_validator` (7 data files), `check_claim_references` (2 claims, 0 proven) — all clean.
`data_codegen --check` (new, gate 22) — PASS, both generated files fresh.

**LOC ratio** (measured just now, not from memory — reported in full per item 3's standing rule):
instrument 2,384 (tools 1,452, tests 932) / game 685 (core 286, sim 399). **Absolute ratio 3.480** —
more than double the 1.5-by-`C001` target stated this round. Trailing 10 commits: instrument 1,965 →
2,384 (+419), game 738 → 685 (−53) — velocity check would **FAIL** (game shrank, from the codegen
refactor collapsing hand-written mirrors; `tools/` grew faster, from this round's lint and codegen work).
Still ADVISORY only — game LOC is under the 2,000-line floor where the gate would actually block. Stated
plainly per the standing rule: this is the wrong direction on both the absolute number and the trend, and
stage 4 (a real game module, not tooling) is the next chance to move it back.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- Stage 4 (`sim/body`) — not started. The full pre-stage-4 punch list is now closed; this is the actual
  next decision point.
- `sim/transport` / Freight Winch — downstream of stage 4+, unchanged.
- Chunk size and the coordinate type scheme (above) — waiting on measurement, not a missing decision.

## Taste queue

0 fixtures. Unchanged — the first ones are still wanted at stage 4 (hostile chamber fresh-dig slopes,
rope traversal segment), per `ONBOARDING.md`.
