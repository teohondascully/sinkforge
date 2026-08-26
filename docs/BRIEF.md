# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stage 4 (`sim/body`) closed and reported. This round: the director's
Codex-audit follow-up queue (items 1-7, `docs/WORKING.md`) is fully closed. Moving to (f)/(g) next,
per the director's explicit instruction.**

---

## EXPENSIVE, awaiting you

None new this round. Two carried over, unchanged, still open:

- **Chunk size** (D0019) — `TileGrid` is a sparse `Dictionary`, correct regardless of what fixed size
  (if any) a later pass picks. Revisit once `sim/fluid` and `view/` exist enough to measure the three
  real costs it trades against.
- **Coordinate type scheme** (D0020) — working choice is naming-only (`terrain_`/`logic_` prefixes on
  plain `Vector2i`), mechanically enforced (`check_coordinate_naming.py`, D0028). Two stronger typed
  alternatives remain proposed and NOT adopted. Still open.

## What was learned

- **A guard that cannot fire is not evidence, even when it's aimed at a real case.** The first
  `Invariants.check_floor_selection` wiring shared `_resolve_floor`'s 6-row window and reported zero
  on a fixture built to match its own target case — not because the case is absent, but because the
  window couldn't span it. Widened to a measured 48 rows (D0044); the earlier worry that widening
  would break normal falling turned out false once actually checked (`_bottom_y() < surface` gates
  landing regardless of window width) — a case where measuring first overturned a plausible-sounding
  intuition, not just confirmed one.
- **A fix to one measurement can silently invalidate another that shares its generator.** Calibrating
  `ValueNoise` to `FastNoiseLite`'s real distribution (D0045, item 3) changed cave density enough that
  the multi-level-floor incidence D0042 measured — 0.85%/12%, the number the director's item-1 decision
  was made against — dropped to 0/4,800 on re-measurement (D0046). Nobody would have thought to check
  this from either task's own description; it surfaced only because the two happened to touch the same
  generator. Worth watching for generally, not just this once.
- **An external audit's own numbers go stale the moment work continues.** The Codex audit's "57 test
  functions," "3.564 LOC ratio," and item 6's own "actual 59" were each correct at the commit they were
  measured against (`489e728`) and each wrong by the time they were acted on — five new test files and
  a full stage landed in between. Current, verified counts: 96 test functions across 13 suites, 2.896
  LOC ratio. Every number in this brief and the ledger entries below was re-measured against current
  state, not carried forward from the audit or from memory.
- **A "verified" claim in a ledger entry is itself an unverified claim until someone tries to break it.**
  D0006 stated `split()`'s order-independence was "verified in the same test suite" — no test ever
  actually varied the parent's draw count before splitting. The property itself was fine; the sentence
  claiming it was tested was not. D0050 corrects this without editing D0006, per the ledger's own
  append-only rule.
- **Measuring before shipping a "fix" caught one that would have been a no-op.** An audit finding that
  `EntityIdPool.pack()` needed a mask before shifting `generation` turned out, on direct measurement, to
  change no actual output — GDScript's `<<` already truncates equivalently. Added the mask anyway
  (defensive symmetry with `index`), but shipped the honest finding (D0048) rather than a commit message
  claiming a behavioral fix that isn't one.
- **A new multi-item task from the director needs a durable home before work starts, not just a chat
  message.** Items 3-7 of this round's queue existed only in chat for one exchange and didn't reach the
  session that needed to act on them. `CONTEXT.md` now states this as a standing rule; the list itself
  is logged verbatim in `docs/WORKING.md`.

## What landed this round (director's Codex-audit follow-up queue, items 1-7)

Full detail and commit hashes: `docs/WORKING.md`'s own queue section; ledger entries D0042-D0050.

1. **Heightfield rewrite → measured and accepted, not rewritten.** `docs/adr/0005` keeps three findings
   separate: the §9 spec's per-column heightfield genuinely can't represent a floor under a reachable
   overhang (Codex right to flag it); the implementation had already diverged toward a bounded local
   query before anyone noticed; measurement showed the residual (originally 0.85%/12%, now ~0% post-D0045)
   is rare enough to accept. `sim/invariants` gained its first real code, wired diagnostically.
2. **Cave-geometry chamber section**, proving the local-window query's real behavior against the
   limitation rather than asserting it's solved (`tests/test_cave_geometry.gd`).
   - **Guard-window correction, same round, on your review**: the guard's 6-row window couldn't see its
     own target case. Widened to a measured 48 (D0044), perf cost measured (37.2→55.3µs/tick,
     negligible), test suite rewritten to prove it now fires for real.
3. **`ValueNoise` calibrated to `FastNoiseLite`'s real distribution** (D0045) — independently reproduced
   Codex's SD mismatch before trusting it. `FASTNOISELITE_SD_CALIBRATION = 0.574`, applied at the one
   call site, not baked into `sample()` (would break its golden-vector tests). Distribution test added.
   Surfaced D0046 (see "What was learned").
4. **CI now runs all 13 Godot suites** (D0047) — a `tests` job downloading and SHA-512-verifying the
   exact pinned Godot build, importing first, one step per suite. Verified live on a real run, not just
   asserted: green in 40s.
5. **`split()` order-independence actually tested** (D0050), correcting D0006's false "verified" claim.
   Mutation-tested against the exact audit-described mutation.
6. **Batch of four**: README's stale counts/claims (D0049), `EntityIdPool`'s masking (D0048, see "What
   was learned"), `data_codegen`'s uncaught crash on malformed YAML now a controlled failure (D0049),
   `Fx.div`'s `push_error` now actually asserted via a real subprocess probe (D0049).
7. **LOC ratio's non-enforcement stated as fact** in `docs/WORKING.md`, current ratio 2.896 (not the
   audit's stale 3.564). Floor unchanged, per the director's explicit call.

## Gates

All 9 structural gates PASS (`layer_lint`, `no_engine_imports`, `check_coordinate_naming`,
`check_size_limits`, `check_loc_ratio`, `schema_validator`, `check_claim_references`,
`data_codegen --check`, `check_working_freshness`). CI's new `tests` job: 13/13 suites PASS, confirmed
on a live GitHub Actions run (`33011313382`), not only locally.

**LOC ratio** (measured just now): instrument 3,553 (tools 1,529, tests 2,024) / game 1,227 (core 296,
sim 931). **Absolute ratio 2.896** — improved from the audit's own 3.564 snapshot (stage 4's real game
code grew faster than instrument code in relative terms), still above the 1.5-by-`C001` target set
2026-08-25, still ADVISORY (game LOC under the 2,000-line floor).

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- (f)/(g) — minimal debug renderer, `--play` flag + recorded-input plumbing — not started. Next, per
  the director's explicit instruction this round.
- `sim/commands`+`interface` (stage 5) and beyond — downstream, unchanged.
- Chunk size and the coordinate type scheme (above) — waiting on measurement, not a missing decision.

## Taste queue

0 fixtures. Unchanged — the first ones are still wanted at (f)/(g) or shortly after (hostile chamber
fresh-dig slopes, rope traversal segment), per `ONBOARDING.md`.
