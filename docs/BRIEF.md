# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: the director's own prescribed fix for D0137's mechanism was
implemented exactly as specified, mutation-tested, and PROVEN mathematically incapable of changing
anything — reverted, hard stop honored, real candidates offered for a ruling.** `docs/DECISIONS_LEDGER.md`
D0138. **Headline: excluding a sentinel that already loses every comparison it's part of cannot change a
`min()`'s result, for any input — the full 1000x1500 sweep confirms every metric byte-identical to the
pre-fix baseline (`grounded_no_floor=59`, `bounds=805397`, all others unchanged). Nothing shipped.**

---

## The one that matters most: a mutation test proved the prescribed fix couldn't work, before the sweep confirmed it

**The director's ruling on D0137: exclude `Heightfield.NO_FLOOR` samples before taking `resolve_floor`'s
own minimum, with the bound dropping as the acceptance signal.** Implemented exactly as specified
(`VerticalResolve._min_real_surface`). Mutation-testing it — reverting to the bare `mini(mini(a,b),c)` and
re-running its own unit tests — found **no test could tell the two apart**, because none can: `NO_FLOOR`
(i32 max) already loses every `mini()` comparison it's ever part of, so excluding an already-guaranteed
loser changes nothing, for any input, provably. Confirmed against the real acceptance signal anyway: the
full 1000x1500 sweep came back with `grounded_no_floor=59`, `bounds=805397`, and every other metric
byte-identical to the pre-fix baseline. Not "didn't drop enough" — literally unchanged.

**This is the director's own explicit hard stop, honored.** Reverted cleanly (nothing had been committed
before the revert); real candidates for what WOULD change behavior (require all three samples real before
`resolve_floor` succeeds; check full-footprint solidity inline) offered in D0138 for the director's own
ruling, not built or decided here.

## What landed

1. **D0138** — the fix, its mutation-test proof of mathematical equivalence to the original, the full-sweep
   confirmation, and the clean revert, all in one ledger entry. `sim/body/vertical_resolve.gd` is back to
   its exact pre-attempt state; nothing shipped.

## Anything that felt wrong even though it passed

- **A specified fix can look completely reasonable in English and still be mathematically incapable of
  changing anything — and a mutation test catches this cheaply, before an expensive full sweep has to.**
  Worth keeping: when a fix's own unit tests survive being reverted to the pre-fix code unchanged, that is
  not a weak test suite, it is proof the transformation was a no-op, and it is worth checking BEFORE
  spending the sweep's own wall-clock to confirm it.
- **The real defect is a criterion problem, not a tie-breaking problem** — `resolve_floor` treats "one of
  three samples found ground" as sufficient for the WHOLE footprint, and no amount of correctly excluding
  a sentinel from a `min()` touches that criterion. The fix that would actually matter has to change what
  counts as "grounded," not how ties among samples are broken.

## Gates

All `layer_lint` gates, `schema_validator.py`, `check_untracked_files.py`, `check_working_freshness.py`,
`anvil/check_integrity.py` (13 events, unchanged) — all PASS. Golden `traverse_time` unchanged (225 ticks),
`test_replay_determinism` unchanged, D0122 regression fixture's own violation count unchanged (67,119).

**Commits this round: 1 (`dc322f6`, plus this wrap), pushed.**

## Claims

`C004-reveal-raises-dig-persistence.md`: unchanged, `BLOCKED` on the hands-on-keyboard `--play` session.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **THE CONTROL PLANE, next piece** — untouched this round, per explicit ordering ("a dominant undiagnosed
  grounding path in the highest-risk module outranks new instrument architecture"). Still waiting on the
  director's review of D0134's canonical types before any Policy/Adapter gets wired.
- **A real decision on `resolve_floor`'s own NO_FLOOR-vs-real-height gap** — precisely described (D0137),
  one candidate fix proven not to work (D0138), two more candidates offered, not decided. Whether/how to fix
  it, and whether the bound should then come down, is open — waiting on the director's own ruling.
- **The persistent-world GDD reversal** — untouched, unchanged from prior rounds.
- **The hands-on-keyboard `--play` session** — unchanged, still the sole remaining blocker on `claims/C004`.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
