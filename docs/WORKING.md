# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round (E4, queue Part E):** the full history through this date — every CLOSED round back to
the acceptance-suite stage — moved verbatim to `docs/archive/working/WORKING-2026-08-29.md`. Read it for
detail behind anything below; nothing was deleted, only relocated, per this file's own header requiring
it stay under 150 lines.

## IN PROGRESS — 5-hour autonomous queue #2, director still away, 2026-08-29

Director's two rulings from queue #1's report applied first (Part 0), then a self-audit of queues #1/#2's
own repair work (Part F — "does this fix verify a population or fire on a constructed case"), then Phase
2 items (Part G: gate 8 tests the real sim, additive-only, reading state never altering resolve logic;
Part H: diagnosis-only `.py` size-gate report, not extended; Part I: drift cleanup + a generated
`docs/CORRECTIONS.md`). **Nothing certified closed — Codex verifies both queues' whole batch on the
director's return.** Hard stops unchanged: collision logic/`resolve_floor`/`grid_floor_backstop`/fuzz
population, `data/economy/`, any resolve-logic change in G1, extending the size gate in H1, any design
decision, 5 hours/30 commits.

## CLOSED (pending Codex re-verify) — 5-hour autonomous queue, director away, 2026-08-29

All of Parts A-E landed, 14 commits, well inside the 5-hour/30-commit budget. **Codex verifies the whole
batch on the director's return before anything closes for real — this session does not certify its own
work**, per the queue's own explicit instruction. Full queue text and this round's own report:
`docs/archive/working/WORKING-2026-08-29.md`'s own top section. Each item its own commit, each with
pasted tool-output evidence in `docs/DECISIONS_LEDGER.md`:

- **Part A** (D0146) — `tools/gate_status.py`'s three real defects fixed (skipped-CI-promoted-to-PASS;
  gate 1's directory-blanket false attribution; population-union framing) plus two contract closures
  (empty-corpus VOID, not PASS; a harness.yml step deletion changes the table with no other edit).
- **Part B** (D0147) — the director's LOC ruling applied: velocity check stays a real gate; absolute
  ratio's "gate" language struck from `QUALITY.md`/`CONTEXT.md`, reported as a metric with a diagnosis.
- **Part C** (D0148) — `BRIEF.md`'s Gates/Claims sections reduced to pure tool pointers; `wrap.md` step 7
  checked, already compliant.
- **Part D** — D1 (D0149) gate mutation tests wired into CI, BLOCKING. D2 (D0150) `run_gd_test.sh`'s
  masked-crash sibling (a plain `ERROR:` from an engine-level native call, not `SCRIPT ERROR:`) fixed,
  TDD'd against a real crash fixture. D3 (D0151) ledger-header rule now requires a genuinely NEW `D0NNN`
  number; trailer pattern broadened. D4 (D0152) `test_body_fuzz.gd`'s falsified DESIGN_TRADEOFF comment
  corrected to match D0135/D0137 (comment only, bound untouched).
- **Part E** — E1 (D0153-D0155) parked `tools/economy_check/`, `tools/anvil/`+`.anvil/`,
  `tests/control_plane/` — removed from tree, git preserves each at `4ec12bb0d642e88abc88a521e64ef2707c975125`.
  A process error in staging this (D0157) meant the harness.yml cleanup didn't land until a follow-up
  commit — caught by re-reading `gh run list`, not trusted from the commit message; corrected before any
  CI run actually failed on it. E2 (D0156) project.godot description no longer says "roguelite." **E3
  (D0158) archived nine of the ten named legacy docs — `docs/DECISIONS.md` was NOT archived: `ONBOARDING.md`
  explicitly forbids it ("stays and is normative... Do not archive it") and it's cited by two live CI
  gates. Reported to the director as a direct conflict, not resolved unilaterally.** E4 (D0159) WORKING.md
  reset to 84 lines. E5 (D0160) "capped at 12" pointers fixed to state the real count (168); the cull
  itself left as director-action, unchanged from three prior sessions' own stance. E6 (D0161) — the
  queue's own premise was wrong (`check_size_limits.py` never covered `.py` files at all, GDScript-only,
  a real finding in its own right); answered the actual ask anyway — `gate_status.py` (431 lines) split
  into `gate_status.py`+`gate_status_ci.py` (371+74); `test_quality_check.py` (404) given a named, dated
  exemption instead of a split, reasoned explicitly.

**Verified, not assumed, at the final commit (`b572a5c`):** real CI run `33268950458`, `conclusion=success`.
`tools/gate_status.py`'s own table: `FAIL gate numbers: []`, `ADVISORY gate numbers: []`, `SKIPPED gate
numbers: []`, `unnumbered steps currently FAIL: []` — every gate and every unnumbered CI step green.
`check_loc_ratio.py`'s velocity gate — red since D0144 armed it — now genuinely PASSes (instrument -1424
lines from Part E1's parking, vs game's +28). **`main` is unprotected** (`gh api .../branches/main/
protection` → 404 "Branch not protected") — flagged for the director, the single biggest gap this round
did not close (a permission the director holds, not this session).

**Still open from this queue's own hard stops, unchanged:** `data/economy/`; any change to
`resolve_floor`/`grid_floor_backstop`/collision logic (see D0139 below); any design decision.

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
- **The hands-on-keyboard `--play` session** — still the sole remaining blocker on `claims/C004`.
- **A Codex finding on THE CONTROL PLANE** (parked, D0155, but the finding stands regardless of whether
  the slice is in the tree): CONSTRAINED restricts distance, not discovery — Anvil FINDING `ed491e83`
  existed only inside the now-parked `.anvil/log/`; recoverable via `git show 4ec12bb:.anvil/log/2026-08-29T095108.038191Z-ed491e83.json`.
