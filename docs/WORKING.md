# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round:** the fix queue's own CLOSED section moved to
`docs/archive/working/WORKING-2026-08-29.md` alongside queues #2 and #3. Nothing deleted, only relocated,
per this file's own 150-line cap.

## GATED — LEGACY REVIVAL, Slice 0 done, STOPPED for the director's look before Slice 1

The Phase 1 map is approved and committed. Slice 0 landed in 4 commits (`b8e9b59..`); evidence
`docs/DECISIONS_LEDGER.md` D0187-D0191. **Slice 1 is NOT started and must not be — Slice 0 is the gate.**

- **Map committed** (D0187) as `docs/LEGACY_MIGRATION_MAP_2026-08-29.md`, pinned at legacy `666e551` /
  current `0be151f`. It carries 265 legacy-side verdicts, not 432: the current-side 167 were behind a
  second tab and are not in the text handed over. Said so in the file rather than implying coverage.
- **Defect B fixed** (D0188) — `dig_pressed` is edge-triggered again. 9 assertions, mutation-tested; the
  mutant reproduces the director's own recorded number (a 30-tick hold reading as 30 events, not 1).
  Corrects the map's wording: that session was UNCOMMITTED, a 7th recording. It is committed now.
- **Slice 0 shipped** (D0189) — 8 band records in `data/bands/`, appearance on all 7 materials, painted
  in the reveal scene. Screenshots: `$CLAUDE_JOB_DIR/tmp/shots/slice0_reveal_test_{dense,sparse}.png`.
- **Screenshot tool was lying** (D0190) — it saved BLACK PNGs and printed "saved". Fixed, plus a
  distinct-colour check so a recurrence is loud. Every prior low-tick capture from it is suspect.
- **The map's coverage gap closed** (D0191) — five full reads of the files it admits it never read.
  Eleven corrections, one of which points a whole future slice at the wrong file (the lighting is in
  `world_renderer.gd`, not `main.gd`; the map inherited a stale docstring).

**THE Q1 ANSWER, which is what gates the expensive slices: the palette reads at 16px; the FLECK does not.**
Legacy distinguishes every ore by bright crystals scattered inside a dull host. Its nugget is 6.4px; this
world's whole terrain cell is 4px, so a cell is either host or fleck and ~81% are bare host. Measured, not
predicted — glimmer authored in the strict legacy idiom came out **0.028** from deepstone against a
**0.087** rock-vs-rock noise floor, i.e. less distinct than two rocks are from each other, and broke a
colour-distance claim the scene already had. Retuned per the Q1 ruling (art adapts, world does not):
**0.286**. Six of seven records lift verbatim. **For Slices 3-4: any material whose identity lives in its
flecks needs its base retuned.** Separately, `terrain_painter.gd` is not portable as written — its
`h % int(CELL - 12.0)` collapses to a 4px band at CELL=16 and is a division by zero at CELL=12.

**Waiting on the director:** approve Slice 0 → Slice 1 (cursor-aim mining, supersedes D0110). Two taste
calls in `docs/TASTE_QUEUE.md` (T001 copper reads silver, T002 band tint). And a Slice 1 candidate found
in passing: legacy's `STRIDE_GAIN = 0.55` takes top speed 150 → 232 px/s. The feel constants were ported;
the stride mechanic was not, which is a concrete answer to "it feels barebones."

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
