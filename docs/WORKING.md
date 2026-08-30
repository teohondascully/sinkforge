# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round (fix queue's own wrap):** queue #2 and queue #3's own CLOSED sections moved verbatim
to `docs/archive/working/WORKING-2026-08-29.md`. Read it for detail behind anything below; nothing was
deleted, only relocated, per this file's own header requiring it stay under 150 lines.

## CLOSED (pending Codex re-verify) — FIX QUEUE, Codex certification findings, 2026-08-29

R1-R6 landed, 9 commits (well under the 20-commit budget). **Nothing certified — Codex re-verifies R1-R4
specifically on return.** Evidence: `docs/DECISIONS_LEDGER.md` D0179-D0185.

- **R1** (D0179) — `gate_status.py`'s absent-CI-as-PASS sibling bug (3rd find on this tool) fixed; three
  cases proven explicit (success→PASS, skipped→SKIPPED, absent→UNKNOWN), mutation-tested. Attacking the
  tool a 4th time found no further PASS-promotion path, but a real mirror bug in `gate_status_ci.py`
  (unconcluded step read as confident FAIL) — fixed too.
- **R2** (D0180) — gate 8's closure proof rebuilt: the old "moving sim/ aside" claim was disproved by
  Codex's own naive full-removal (breaks the shared test base too). Real isolating removal re-verified in
  a scratch clone of HEAD (the dirty local tree would have contaminated it — confirmed directly).
- **R3** (D0181) — 7 more stale `economy_check`/`anvil` references swept beyond Codex's one example.
- **R4** (D0182) — `project.godot`'s stale "CI needs no engine" comment corrected.
- **R5** (D0183) — ValueNoise's "one place" framing corrected to the true scope: 4 float sites enumerated
  (`value_noise.gd`, 2× `shaft_generator.gd`, `core/split_rng.gd`), 6 docs fixed.
- **R6** (D0184) — `grounded_no_floor`'s bound relabeled per the director's Finding-B ruling (cumulative
  trajectory, not independent-trial rate) — comment only, no value/logic change.
- **D0185** — the fix queue's own work drifted `docs/CORRECTIONS.md`'s freshness gate (D0180/182/183 are
  real corrections, added; D0181 is drift cleanup, excluded and noted). Gate re-runs clean.

**New this round, not investigated further (collision-adjacent, out of this queue's scope):** the director
recorded 4 real `reveal_scene.gd --play` sessions. Two produced real dig events; all four still show
`qualifying_reveals=0` for `claims/C004`. The `reveal_test_sparse` site reproducibly throws a real
`body ... left the world` bounds violation on replay — same exact position across two independent
sessions with different input. Not yet known whether this is a live physics bug or a replay-fidelity gap
(D0173's own "proven end-to-end" claim was only tested against a synthetic run). Director agreed: build a
flag-gated verbose diagnostic capture (velocity, position deltas, touching-surface per tick) plus a
replay-fidelity checker as the next piece of work, after this queue. New recordings not yet committed.

## OPEN, MID-INVESTIGATION — D0139's Option-2 `resolve_floor` fix hit a SECOND hard stop, uncommitted,
awaiting the director's ruling

**Do not touch `sim/body/vertical_resolve.gd` or `tests/test_vertical_resolve.gd` without reading the full
account first** — `docs/archive/working/WORKING-2026-08-29.md`'s own "OPEN, MID-INVESTIGATION" section has
the complete detail (tick traces, exact grid dumps). Working tree is dirty on purpose: `vertical_resolve.gd`
carries an uncommitted `_full_footprint_solid` attempt; `tests/test_vertical_resolve.gd`(`.uid`) are new,
untracked, 6 passing unit tests, one mutation-tested.

Two real findings, reported, neither acted on: (1) the full 1000×1500 sweep's `grounded_no_floor` did NOT
drop toward ~4 — it stayed at 59, mechanism flipped entirely to `grid_floor_backstop`, which has the
identical criterion flaw (the director's own anticipated "second bug"). (2) A real regression against
`test_body_acceptance.gd`'s own HARD gate — the golden traverse stalls at tick 133, traced to an authored
1-row rubble notch the new exact-same-row check can't distinguish from a real gap. Also breaks
`check_size_limits` (`resolve_floor` 49→59 lines against the 50-line limit). Not shippable as written even
if both findings resolve. Waiting on the director; nothing here resolves unilaterally.

## OPEN, NOT STARTED — the persistent-world GDD reversal

A director brief reversing the 2026-08-25 run-based-roguelite pivot back to a persistent single shaft +
rig-as-consumer (further than the already-closed 2026-08-27 reversal `docs/GDD.md` §9 already records) —
its full text exists only in prior conversation history, not in any tracked doc. A fresh session needs the
brief re-supplied (asked of the director, not reconstructed from a summary) before touching `docs/GDD.md`.

## Standing, unchanged, all reserved for the director

- **`data/economy/`, D1-D6** — the demand-chain content itself; `tools/economy_check/` (parked, D0153)
  waits for it.
- **`history/`'s pre-pivot image cull** — waits on the director, unchanged.
- **`claims/C004`** — no longer blocked on getting a session at all (4 real ones exist now, see above);
  blocked on one that actually produces a qualifying reveal with real dig events on both sides.
- **A Codex finding on THE CONTROL PLANE** (parked, D0155, but the finding stands regardless of whether
  the slice is in the tree): CONSTRAINED restricts distance, not discovery — Anvil FINDING `ed491e83`
  existed only inside the now-parked `.anvil/log/`; recoverable via `git show 4ec12bb:.anvil/log/2026-08-29T095108.038191Z-ed491e83.json`.
