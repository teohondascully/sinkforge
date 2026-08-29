# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

**Last updated: 2026-08-29.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date, so a session that lands commits without touching this file is
caught mechanically rather than relying on someone noticing later.

**Reset this round (queue #2's own wrap):** the full history through this date — both 5-hour queues'
own CLOSED sections — moved verbatim to `docs/archive/working/WORKING-2026-08-29.md`. Read it for detail
behind anything below; nothing was deleted, only relocated, per this file's own header requiring it stay
under 150 lines.

## CLOSED (pending Codex re-verify) — 5-hour autonomous queue #2, director away, 2026-08-29

Parts 0/F/G/H/I all landed, 10 commits, well inside the 5-hour/30-commit budget. **Codex verifies the
whole batch (both queues) on the director's return — this session does not certify its own work.** Full
queue text and detailed report: `docs/archive/working/WORKING-2026-08-29.md`'s own appended section.
Each item its own commit, evidence in `docs/DECISIONS_LEDGER.md`:

- **Part 0** — both director rulings confirmed already correct in the tree (DECISIONS.md stayed
  normative; D0157's harness.yml fix landed) — verification only, no fix needed.
- **Part F** (self-audit, D0162-D0164) — re-attacking the status tool found one real, previously-
  undiscovered gap: `${{ env.KEY }}` in a step name was never resolved before matching CI's own expanded
  name, permanently UNKNOWN (never a false PASS) for the Godot-download step. Fixed, mutation-tested.
  D1's own CI wiring had a real glob-depth gap (one directory level only); fixed with a genuinely
  recursive `find`, mutation-tested against a synthetic nested probe. Broader re-sweep of the parking
  claim found one more real drift (`tools/README.md` still listed `economy_check/` as live); fixed.
- **Part G** (D0165-D0169) — gate 8's real subject: a live `ShaftGenerator`+`TileGrid`+`Body` sim,
  20,000 ticks, replayed across two OS processes, golden hashes committed. **The closure proof itself was
  wrong on the first attempt** (an in-tree `sim/` rename let Godot's importer silently rediscover the same
  code — caught before being reported, not after); corrected by moving `sim/` fully outside the project.
  **CI (Linux) then failed against locally-captured (macOS) golden hashes** — a real cross-platform
  finding, not a regression: `sim/terrain_gen/value_noise.gd`'s cave-noise uses real floats, not `Fx`
  fixed-point, and IEEE 754 doesn't guarantee bit-identical results across architectures. Golden hashes
  re-sourced from CI directly (the project's own canonical platform); the scenario's own `mantles > 0`
  check downgraded from gated to reported after two spawn-tuning attempts still couldn't force a mantle
  on CI's own platform. **Confirmed green on real CI** (`godot test suites` job, run `33274168286`+).
- **Part H** (diagnosis only) — exactly one `.py` file exceeds 400 lines post-parking
  (`tools/quality_check/test_quality_check.py`, 404), already exempted by D0161. Not extended (director
  decision, per the queue's own hard stop).
- **Part I** — I1 (D0166): all four of the queue's own named drift targets were undercounted by its own
  premise — "capped at 12" had 2 more stale instances beyond E5's fix; MODULE.md's "60 lines maximum" is
  violated by 7 files, not 4 (softened to an unenforced target); README's "13 suites, 96 test functions"
  (real count 22+) and ONBOARDING's "under 1,600 lines" (real: 1,669) both replaced with pointers instead
  of fresh numbers that would re-drift. I2 (D0170): `docs/CORRECTIONS.md` generated, tracing the D0059→
  D0137 chain in full (the citation gap the audit flagged between D0133/D0135 and D0061).

**Verified, not assumed, at the final commit (`51de4a3`):** real CI, `godot test suites` job green
(`33274168286`). The ONLY red: `check_loc_ratio.py`'s velocity gate — instrument +423 lines against
game's +38 over the last 10 commits, more than 2x (`docs/CLAIMS.md`: "the next unit of work is game").
This is real, intentional (D0147's own ruling keeps it a gate), and a direct, unavoidable consequence of
two full queues of tooling/test work under a hard stop that forbade touching `data/economy/` — flagged
for the director as a genuine tension between this queue's own scope and its own velocity gate, not
something this session can resolve unilaterally. **`main` is still unprotected** (`gh api .../branches/
main/protection` → 404) — unchanged, still the director's own permission to grant.

**Still open from both queues' hard stops, unchanged:** `data/economy/`; any change to
`resolve_floor`/`grid_floor_backstop`/collision logic (see D0139 below); any design decision; the
`ValueNoise` cross-platform float gap (D0167 — real, unfixed, an architecture question, not a Part G fix).

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
