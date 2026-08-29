# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: the bound-raise justification wasn't refined, it was falsified —
filed plainly, then `resolve_floor` diagnosed to one exact, fully-characterized mechanism, not fixed.**
`docs/DECISIONS_LEDGER.md` D0135–D0137. **Headline: D0128's own reasoning for accepting 32→59 ("we know
what the excess is") was wrong, and the code actually responsible for 84/91 of the population is now
understood precisely for the first time — a heightfield sampling function treating "no floor" as if it
were just a very large floor.**

---

## The one that matters most: a decision's own justification was falsified, not just its prose

**D0128 ruled 32→59 acceptable because the excess was named as a known, already-accepted mechanism.**
D0132's telemetry (previous round) showed that claim was wrong: 84/91 of the population traces to
`resolve_floor`, not the mechanism named. This round filed that plainly as D0135 — not "the attribution was
refined," but that a decision's stated reasoning was asserted and then disproven by the instrument built to
check it. High severity, on purpose: the bound (59/32) is unaffected, but the REASON it was allowed to rise
without further investigation no longer holds.

**D0137 — `resolve_floor` traced the way D0123 traced the dig staircase, without touching it.** A one-off
diagnostic script (`tests/diag_resolve_floor.gd`) independently recomputes `resolve_floor`'s own three
heightfield samples from outside the function. Result, measured across all 84 real occurrences (55 dig-on +
29 dig-off), 100% consistent: `resolve_floor` picks `mini(s_left, s_right, s_center)` as the landing
surface, but `Heightfield.NO_FLOOR` (an i32-max sentinel meaning "no floor found") loses every `mini()`
comparison to any real height — so whenever even one of three foot samples finds real ground, the whole
body rests there, even when the other samples correctly reported open air beneath them. This also
short-circuits `grid_floor_backstop` (the DOCUMENTED backstop for exactly this geometry), since
`resolve_floor(...) or grid_floor_backstop(...)` never reaches the second call once the first succeeds.
Confirmed pre-existing (29 occurrences with dig fully disabled) — dig only amplifies frequency. **No fix
made or proposed** — diagnose-and-report only, per explicit instruction, since this is the highest-risk
code in the module.

## What landed

1. **D0135** — Anvil FINDING (`.anvil/log/2026-08-29T084009.244046Z-b497565f.json`) plus a ledger entry
   stating the bound-raise justification was falsified. Bound stays 59; status moves from "known mechanism"
   to "measured, mechanism under active diagnosis" (now "fully diagnosed," per D0137).
2. **D0136** — `sim/body/body.gd` (399/400 lines, one line of headroom) extracted: the horizontal collision
   resolver moved to a new `sim/body/horizontal_resolve.gd`, mirroring the existing vertical split. Pure
   Extract Class, mutation-tested (forcing the new call site into a no-op broke real tests for real
   reasons). `body.gd`: 399 → 313 lines. Done as its own commit, before the diagnosis touched anything near
   it, per explicit instruction.
3. **D0137** — the `resolve_floor` diagnosis above. `tests/diag_resolve_floor.gd`, not CI-run, not a
   permanent instrument — a one-off investigation, same convention as every other `fixture_*`/`diag_*.gd`
   in this project.

## Anything that felt wrong even though it passed

- **My own hypothesis about the mechanism (heightfield interpolation blending across a real column-height
  difference) was directly wrong.** `transition=false` in all 84 measured cases. The real mechanism —
  `NO_FLOOR` losing every `mini()` comparison — is simpler and, in hindsight, more obviously a sentinel-
  handling gap than an interpolation artifact. Worth naming: a plausible-sounding first guess still needs
  the actual instrument before it's reported as fact, exactly the discipline this whole round is about.
- **A decision's own justification, not just a description of it, can be false and stay false across two
  ledger entries until an instrument is built to check it.** That is the sharper, more expensive version of
  "the ledger's prose was imprecise" — it is why D0135 is filed at high severity, not low.

## Gates

All `layer_lint` gates, `schema_validator.py`, `check_untracked_files.py`, `check_working_freshness.py`,
`check_claim_references.py`, `anvil/check_integrity.py` (13 events, referentially sound) — all PASS. Every
body-collision-adjacent suite re-run green after the extraction: `test_body`, `test_body_acceptance`
(byte-identical golden traverse time), `test_bounds_invariant`, `test_cave_geometry`, `test_hostile_chamber`,
`test_reachability_sweep`, `test_floor_source_telemetry`, `test_body_fuzz_fast`,
`test_body_fuzz_regression_d0122` (identical 67,119-violation count), `test_replay_determinism`.

**Commits this round: 4 (`6790a82`, `2265548`, `aba9793`, plus this wrap), all pushed.**

## Claims

`C004-reveal-raises-dig-persistence.md`: unchanged, `BLOCKED` on the hands-on-keyboard `--play` session.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **THE CONTROL PLANE, next piece** — untouched this round, per explicit ordering ("a dominant undiagnosed
  grounding path in the highest-risk module outranks new instrument architecture"). Still waiting on the
  director's review of D0134's canonical types before any Policy/Adapter gets wired.
- **A real decision on `resolve_floor`'s own NO_FLOOR-vs-real-height gap** — now precisely described
  (D0137), not yet decided on. Whether/how to fix it, and whether the bound should then come down, is open.
- **The persistent-world GDD reversal** — untouched, unchanged from prior rounds.
- **The hands-on-keyboard `--play` session** — unchanged, still the sole remaining blocker on `claims/C004`.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
