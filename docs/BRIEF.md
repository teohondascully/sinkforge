# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stage 3 (`sim/world`, `sim/terrain_gen`) landed AND its post-landing review
is closed. Stopped deliberately before stage 4 (`sim/body`).**

---

## EXPENSIVE, awaiting you

None carried over as blocking. Two EXPENSIVE items stay deliberately open, not resolved unilaterally:

- **Chunk size** (D0019) — `TileGrid` is a sparse `Dictionary`, correct regardless of what fixed size (if
  any) a later pass picks. Revisit once `sim/fluid` and `view/` exist enough to measure the three real
  costs it trades against.
- **Coordinate type scheme** (D0020) — working choice is naming-only (`terrain_cell` vs. `logic_cell`,
  both plain `Vector2i`), two stronger typed alternatives proposed and NOT adopted. The resolution-split
  test below found and fixed the one place this naming-only enforcement had actually failed
  (`occupied_cells`), but the underlying risk D0020 accepted — nothing at the type level stops a
  cross-grid mismatch — is unchanged. Still open.

## What landed

- **Stage 3 build**: `sim/world` (`TileGrid`, `WorldMaterials`), `sim/terrain_gen` (`ShaftGenerator`,
  `StrataData`, `ValueNoise`), the constant-count report (29 of 118 legacy tuning constants ported by
  value, D0025). Reported in full in the prior brief; unchanged this round.
- **Two findings generalized into normative rules, not left ledger-only** (your explicit ask):
  `docs/QUALITY.md` §2 gained "a gate is only as good as its pattern list" (the `no_engine_imports.py`
  gap) and "mutation-testing a guard at integration scale is not sufficient" (D0024), the second
  naming its connection to stage 2's frozen-no-op check explicitly.
- **`no_engine_imports.py` rewritten from a full audit, not accumulation** (`db8e448`, D0026): dumped
  Godot's actual `ClassDB`/singleton list (1,040 classes, 37 singletons), categorized every one by hand
  against the gate's six rule categories plus new ones the audit justified. Scene-tree coverage now
  matches all 282 Node-derived classes (`extends X` and `X.new()`), not four hand-picked stems —
  `extends Timer` would have passed silently before. New categories: input devices, engine subsystem
  servers (render/audio/physics/nav), threading, network IO, OS subprocess/UI side effects, resource
  loading, broader wall-clock coverage, `Crypto` as a second RNG-source risk. Considered and rejected:
  `Geometry2D`/`Geometry3D`/`Marshalls` (pure deterministic utilities), `ProjectSettings` (deterministic
  given a fixed project file, not named forbidden anywhere). Verified by injecting one violation per new
  category into a throwaway file and confirming all 11 fire, then deleting it.
- **The 7 declared-but-unconsumed generation constants marked structurally pending** (`46a470e`): nested
  under `pending_sim_economy` in both `data/strata/shallow_clay.yaml` and its `strata_data.gd` mirror,
  instead of sitting flat next to consumed fields with only a comment saying they're unread.
- **`legacy/tools/*.uid` gitignored** (`2605315`) — 192 files of working-tree noise from Godot's
  `--import` regenerating resource IDs in a tree nobody edits. Same reasoning as the existing `tools/*.uid`
  rule.
- **The resolution-split test, run honestly** (`c9742ef`, D0027): three `sim/world` functions drawn at
  random (Python `random.sample`, not hand-picked) — `exists()` (no coordinate, N/A), `get_material()`
  (yes, `terrain_cell` names it), `occupied_cells()` — **no**, a bare untyped `Array` from a function
  whose name didn't say "terrain" either. 2 of 3 clean, reported as such rather than rounded up to a
  clean pass. Audited every other signature in `sim/world`/`sim/terrain_gen` for the same gap before
  fixing anything — this was the only public-API instance. Fixed: `occupied_terrain_cells() ->
  Array[Vector2i]`, three call sites, `MODULE.md`, all green after.

## Gates

All PASS or ADVISORY. `check_loc_ratio`: ADVISORY, game LOC (738) still under the 2,000-line floor;
trailing-10-commit velocity check would PASS if it were gating (instrument +371, game +357).
`check_claim_references`: PASS, 0 of 2 claims proven — unchanged.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- Stage 4 (`sim/body`) — not started. Stage 3 and its review are both closed; this is the actual next
  decision point.
- `sim/transport` / Freight Winch — downstream of stage 4+, unchanged.
- Chunk size and the coordinate type scheme (above) — waiting on measurement, not a missing decision.

## LOC ratio

Instrument 1,965 (tools 1,073, tests 892) / game 738 (core 273, sim 465). Absolute ratio 2.663,
informational only, ADVISORY under the 2,000-line game-LOC floor. Trailing 10 commits: instrument
1,594 → 1,965 (+371), game 381 → 738 (+357) — velocity check would PASS.

## Taste queue

0 fixtures. Unchanged — the first ones are still wanted at stage 4 (hostile chamber fresh-dig slopes,
rope traversal segment), per `ONBOARDING.md`.
