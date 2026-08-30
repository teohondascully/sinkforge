# Corrections

The "when we were confidently wrong" page. A projection over `docs/DECISIONS_LEDGER.md`'s own
resolves/corrects/supersedes links — not a new instrument, not hand-curated judgment, just every place
the ledger's own append-only record shows an entry naming an earlier one as wrong, overstated, or
falsified. Numbers are permanent addresses; nothing here edits the ledger, it only re-reads it.

**The rule this page follows:** a correction earns a place here only if it names the entry it corrects.
Where a correction's own chain runs deeper than the entry it directly cites — the ORIGIN of the claim,
not just its most recent restatement — that deeper origin is traced below explicitly, per the standing
instruction that a correction naming only its immediate predecessor while the real origin sits further
back is itself an incomplete citation.

Regenerate this by re-reading `docs/DECISIONS_LEDGER.md` for entries whose own text says "corrects,"
"correction," "FALSIFIED," "was wrong," "superseding," or similar — this file is a snapshot, not a live
query; re-derive it rather than hand-edit it when the ledger grows further corrections. First generated at
`docs/DECISIONS_LEDGER.md` D0170; `tools/check_corrections_freshness.py --check` catches when the ledger's
own candidate set has grown past what's written here (it cannot regenerate the prose itself — reading each
candidate in context to write it up stays a judgment call, per D0170's own account).

## The deepest chain: `grounded_no_floor`'s mechanism, D0059 → D0137

The longest-running correction chain in the ledger, spanning six weeks and five corrections. Traced in
full because the audit that prompted D0133/D0135 flagged exactly this: a correction citing only its
immediate predecessor when the claim's real origin sits further back.

1. **D0059** (2026-08-26) — `JUMP_CORNER` embedding root-caused to four separate controller defects.
   Establishes `_grid_floor_backstop` (D0059f) as an accepted design trade-off: rests a body on the
   topmost solid row in its footprint when that's the only real ground available (a pit's own lip).
2. **D0060** (2026-08-26) — the fuzzer's standing allowlist for D0059's residual, framed as ONE
   undifferentiated bucket.
3. **D0061** (2026-08-27) — **corrects D0060's own framing**: splits the allowlist into two different
   KINDS of thing — `RESIDUAL` (a genuine unresolved leftover, should trend to zero) vs. `DESIGN_TRADEOFF`
   (`grid_floor_backstop`'s own accepted behavior, D0059f) — conflating them was D0060's mistake, corrected
   here for the first time.
4. **D0122/D0127/D0128** (2026-08-28 – 2026-08-29) — dig raises `grounded_no_floor` from 32 to 59.
   D0127 explicitly cites the pre-dig bound as "D0061" by number. D0128 attributes the entire 27-violation
   excess to "the SAME `_grid_floor_backstop`/D0059f pit-lip trade-off" — a claim that cites D0059's own
   mechanism directly, but adds no new measurement of its own between D0127's hedged version and D0128's
   unqualified one.
5. **D0133/D0135** (2026-08-29) — **correct D0127/D0128**: D0132's own telemetry (built specifically to
   settle this) measures the real split — 84/91 violations trace to `resolve_floor`, only 7/91 to
   `_grid_floor_backstop`/D0059f. D0135 goes further: the 32→59 raise wasn't merely unproven, it was
   **FALSIFIED** by an instrument built specifically to check it. Both corrections cite D0059f directly;
   neither re-cites D0061's own distinct act (splitting residual from trade-off) — that citation gap is
   what this section closes by tracing the chain here rather than leaving D0059 as the only cited
   ancestor.
6. **D0137** (2026-08-29) — the actual mechanism, diagnosed after D0133/D0135 opened the question:
   `resolve_floor` takes `mini()` of three heightfield samples, so `Heightfield.NO_FLOOR`'s sentinel value
   never wins even when a real gap exists — measured across all 84 non-backstop occurrences, 100% show
   this exact shape. Not fixed (explicit instruction); the attempted fix and its own further complications
   are `docs/WORKING.md`'s own "OPEN, MID-INVESTIGATION" section, unresolved as of this queue.

## Other corrections, chronological

- **D0035** (2026-08-25) — `body.gd`'s `STEP_UP_PX`/`MANTLE_PX` used the wrong unit (a 4px terrain cell
  instead of a 16px logic tile). Caught before anything was built on top of it, not a correction to a
  standing claim so much as a same-session catch — included for completeness.
- **D0044** — corrects **D0043**: a floor-selection guard shared `_resolve_floor`'s own 6-row scan
  window, which could not see the 16-row gap its own test fixture was built to require — "a zero that
  cannot be nonzero is not evidence." Widened to 48 rows.
- **D0050** — corrects **D0006**'s claim that `SplitRng.split()`'s order-independence was "verified in
  the same test suite" — every existing test called `.split()` on a freshly-constructed RNG with zero
  prior draws; none tested what the claim actually asserted. An external audit demonstrated the gap
  directly.
- **D0051** — corrects **D0042/D0046**'s own reading of a 0/4,800 result: not "an accepted documented
  limitation" but a bug in an adjacent module (`ValueNoise` over-carving) — the two are different claims,
  and the ADR previously blurred them together.
- **D0061** — see the chain above.
- **D0068** — self-correction: the "unreconciled snapshot" framing applied to two archived files in
  **D0062** was wrong, disclosed plainly rather than quietly fixed.
- **D0070** — language correction: **an earlier claim** that "contradictions [are] unrepresentable" was
  false, per external audit judgment 11 — the director's own words adopted verbatim as the corrected
  claim.
- **D0098 → D0104** — D0098's own FINDING corrected via a superseding FINDING (Anvil's own
  `--supersedes` mechanism), the same append-only discipline as the ledger itself: the original stays,
  unedited, in the log.
- **D0109** — the director's correction to a prior operationalization of the reveal metric ("bias toward
  unrevealed features") that was circular by `docs/EXPERIENCE_EVALUATION.md`'s own Readiness Gate 6.
- **D0112** — **D0110**'s dig mechanic had a real off-by-one in its right-facing case, invisible to its
  own mutation tests because they were self-referential (derived their own "expected" value by calling the
  same function under test) — found only by actually running the scene end to end.
- **D0128 → D0133/D0135** — see the chain above.
- **D0152** — `tests/test_body_fuzz.gd`'s own doc-comment still told **D0128**'s falsified story after
  D0135 corrected it; fixed to match D0135/D0137 (comment only, no bound changed).
- **D0157** — corrective: an earlier commit's own message claimed a harness.yml fix and three ledger
  entries that were never actually staged, due to a `git add` with an invalid pathspec silently aborting
  the whole invocation — caught by re-reading real CI state, not by trusting the prior commit message.
- **D0161** — this queue's own E6 instruction assumed the size gate covered `tools/**/*.py`; it never
  covered Python at all, GDScript-only, at any point in its history. Corrected the premise, then answered
  the actual ask anyway.
- **D0165 → D0167/D0168/D0169** — this queue's own Part G work: a first "prove sim/ deletion turns the
  test red" attempt was itself invalid (an in-tree rename let Godot's importer silently rediscover the
  same code, D0165's own account has the full finding). Corrected methodology confirmed the real closure
  proof. D0167 then found the committed golden hashes were captured on the wrong platform (macOS, not
  CI's own canonical Linux build) — corrected by sourcing golden hashes from CI directly. D0168/D0169
  found a further real gap (the golden scenario never mantles on CI regardless of spawn placement) and
  downgraded that specific assertion from gated to reported, rather than force a fix neither queue
  authorized.
- **D0180** — a Codex certification pass disproved `test_shaft_replay_determinism.gd`'s own docstring
  claim exactly as it was written ("moving sim/ aside" turns the real test red, the stub stays green):
  removing ALL of `sim/` reds BOTH, because `test_base.gd`'s shared `_flat_grid()` needs `TileGrid` too.
  The real isolating methodology (D0165's own second, corrected attempt) was already right, just never
  made it into the docstring — rebuilt and re-verified in a scratch clone, docstring corrected to match.
- **D0182** — `project.godot`'s own pin comment said CI "replaced" the Godot-installing job with pure
  static analysis needing no engine at all; the real `tests` job (harness.yml:199) boots Godot and
  checksum-verifies this exact pin before running every suite. Same class as the retired roguelite
  description corrected earlier this session (D0177) — shipped metadata nobody re-read before quoting it.
- **D0183** — five docs framed `ValueNoise.sample()` as "the one place" `sim/` departs from fixed-point;
  a certification pass found float arithmetic on the same terrain-generation/RNG state path in three more
  places (two in `shaft_generator.gd`, one in `core/split_rng.gd`). The direction of D0171/D0172's own
  correction (proven within-platform, not across) was right; the SCOPE was still an undercount — corrected
  to name all four sites, enumerated in D0183 itself.

**D0185, read and deliberately excluded, not silently dropped:** it trips this page's own keyword scan
because its header says "docs/CORRECTIONS.md updated with ... real corrections" — but D0185 IS the update,
not a correction of anything. Listing it here would make the page cite itself. Noted so the freshness gate
stops re-flagging it, and noted with the same reasoning as D0181 below rather than by widening the gate's
pattern, which would blind it to real entries.

**D0181, read and deliberately excluded, not silently dropped:** its own header matches this page's
keyword scan ("7 files corrected"), but it is drift cleanup — annotating already-true comments as
"parked, see D0153-D0155" — not a correction of a claim that was ever WRONG. Noted here so the freshness
gate (`tools/check_corrections_freshness.py`) doesn't keep re-flagging it as unreviewed drift.

## What this page is not

Not every ledger entry that says "found" or "fixed" is a correction — most entries describe new work,
not a repudiation of a prior claim. This page exists only for entries whose own text names an earlier
entry as wrong. A finding that was simply incomplete (e.g., D0139's own still-open investigation) is not
a correction until something explicitly supersedes its claim; it stays in `docs/WORKING.md` instead.
