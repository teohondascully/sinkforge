# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: answered an external (Codex) audit of the D0122 dig fix — a
masking-pattern sweep, real grounding-path telemetry, and two ledger corrections — then built THE CONTROL
PLANE's canonical obs/action types and stopped exactly at the explicit "show me those first" gate.**
`docs/DECISIONS_LEDGER.md` D0131–D0134. **Headline: the audit's two "unproven" flags turned out to be
worse than unproven — real telemetry shows the "one shared mechanism" ledger claim was actually wrong for
84/91 of the population, corrected without touching the original entries.**

---

## The one that matters most: an "unproven" claim turned out to be a wrong one, caught by building the instrument the audit asked for

**D0127/D0128 claimed all 91 `grounded_no_floor` violations shared one mechanism** (`_grid_floor_backstop`
/D0059f), based only on every occurrence sitting at the same height. An external audit correctly called
this correlation, not proof — the harness never recorded which code path actually set `on_floor=true`.
D0132 built that telemetry (`Body.floor_source_this_tick`), purely additive, mutation-tested. The first
real run: 55/59 dig-on violations and 29/32 dig-off violations trace to `resolve_floor` (the normal
ground-plane resolver), not `grid_floor_backstop` — 84/91 combined, the opposite of the claim. The measured
bounds (59/32) are unaffected; only the causal story was wrong. Corrected via two Anvil FINDINGs plus a
ledger entry (D0133), originals left untouched per the append-only convention and explicit instruction.

**D0134.** THE CONTROL PLANE brief's canonical obs/action types (`tests/control_plane/`), built exactly to
the gate the director set: simulate Boundary A inside `tests/` (not a real `interface/`, which doesn't
exist yet), prove the anti-cheat property (a Constrained-envelope observation never reads a cell outside
its own radius), and stop — no Policy/Adapter/Episode-Log/Goal/Scorer wired. Awaiting review before any
policy gets wired against these types.

## What landed

1. **D0131** — the D0115/D0117 masking gap (`exit_code==0` passing without checking for a captured
   `SCRIPT ERROR:`) fixed in the two instances Codex found (`test_bounds_invariant.gd`,
   `test_cave_geometry.gd`) plus a third this session's own sweep found (`test_fixed_point.gd`). All three
   mutation-tested by injecting a post-expected-behavior crash and confirming only the new guard caught it.
2. **D0132** — `Body.floor_source_this_tick`, naming which of `resolve_floor`/`grid_floor_backstop`/
   `try_step` last set `on_floor=true`. `sim/body/body.gd` now at 399/400 lines — one line of headroom
   left before the next change there must extract something first.
3. **D0133** — the ledger correction above, plus restoring D0127's own hedge on the water-mark fix's
   bounds contribution, which D0128 had silently hardened into an unqualified "accepted" fact.
4. **D0134** — `tests/control_plane/`: `CanonicalObservation`, `CanonicalAction` (Raw level only),
   `ObservationSpec` (Oracle/Constrained), a pure `ObservationBuilder`. Anti-cheat property proven and
   mutation-tested.

## Anything that felt wrong even though it passed

- **The ledger's own "same mechanism" claim wasn't just unproven — it was actively contradicted by the
  first real measurement.** Worth naming because it's the exact failure class this project keeps finding:
  a claim built on a proxy (shared height) that reads as confirmed until the actual causal instrument gets
  built. The audit named the gap; building the instrument is what turned "unproven" into "wrong."
- **`sim/body/body.gd` is now at the hard 400-line file cap with one line of headroom.** Not a defect, but
  worth surfacing rather than letting a future session discover it only when `check_size_limits.py` goes
  red without warning on an unrelated change.

## Gates

All `layer_lint` gates, `schema_validator.py`, `check_untracked_files.py`, `check_working_freshness.py`,
`check_claim_references.py`, `anvil/check_integrity.py` (12 events, referentially sound) — all PASS.
`quality_check/duplication.py`/`function_length.py`/`complexity.py`/`coupling.py` — no new violations,
existing advisories unchanged (D0098). Every touched/new suite independently re-run and green: `test_body`,
`test_body_acceptance`, `test_bounds_invariant`, `test_cave_geometry`, `test_fixed_point`,
`test_hostile_chamber`, `test_tile_grid`, `test_body_fuzz_fast`, `test_body_fuzz_regression_d0122`,
`test_floor_source_telemetry` (new), `test_observation_builder` (new).

Instrument/game LOC ratio: 6.235 absolute, still ADVISORY (game LOC 1625, under the 2000-line floor where
the ratio means anything).

**Commits this round: 5 (`16a5621`, `db09326`, `ea506de`, `abc2eae`, plus this brief's own), all pushed.**

## Claims

`C004-reveal-raises-dig-persistence.md`: unchanged, `BLOCKED` on the hands-on-keyboard `--play` session.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **THE CONTROL PLANE, next piece** — waiting on the director's review of D0134's canonical types before
  any Policy/Adapter gets wired against them. This round's own explicit stop point.
- **The persistent-world GDD reversal** — untouched this round. `docs/GDD.md` read in full in an earlier
  round, zero edits. The brief's full text is only in conversation history, not any tracked doc — a fresh
  session needs it re-supplied before touching `docs/GDD.md`.
- **The hands-on-keyboard `--play` session** — unchanged, still the sole remaining blocker on `claims/C004`.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
