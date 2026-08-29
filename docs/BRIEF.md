# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the director's response to the reveal-layer report — fix D0115
first, hunt for the same class everywhere, fix the density screenshots, then the replay driver.**
`docs/DECISIONS_LEDGER.md` D0116–D0122. **Headline: a real, confirmed, already-shipped regression in
`sim/body` (D0122), found by this round's own gate diligence, not fixed yet — read that section first.**

---

## The one that matters most: D0122, a confirmed regression already on `main`

Running the FULL (nightly-only) fuzzer for the first time since the dig mechanic landed this session
found real defects the per-commit fast fuzzer cannot see: `embedded` violations at 187 against an
established bound of 1, `grounded_no_floor` at 95 against 32, and a brand-new `discontinuity` class at 4
(previously always exactly zero). **Causation confirmed by controlled A/B, not inferred**: re-ran the
identical 1000×1500 sweep with dig forced off in the fuzz probe, and every count returned to its EXACT
pre-dig baseline. `sim/body` is this project's own documented highest-risk module; this was not patched
under this round's authorization — flagged for you rather than hastily fixed. Plausible but *unverified*
mechanism: dig removing supporting geometry inside the same tick it's read for collision/floor-selection.
Already shipped (`3181c30`), invisible to every gate CI runs per-commit.

## What landed

1. **D0116 — `tools/run_gd_test.sh`, the D0115 fix, TDD-verified.** Root cause precisely determined (not
   assumed): a crash directly in `_initialize()` hangs; a crash in any function it calls — every real
   suite's actual shape — silently continues instead, invisible to `_check()`/`_finish()`. The wrapper
   greps raw output for `SCRIPT ERROR:` on top of the exit code. `tests/fixture_harness_crash_probe.gd` +
   `tools/test_run_gd_test.sh` prove the pre-fix bug, then the fix, then a negative control (a suite that
   legitimately calls `push_error()` as PASSING behavior stays green) — your own bar, met exactly. Wired
   into all 18 CI suite invocations; `test_reveal_metric.gd` was found never wired into CI at all, fixed
   in the same pass.
2. **D0117/D0119/D0120 — the hunt, with two more real instances found AND fixed, not just logged.**
   `.githooks/pre-commit`'s base-namespace gate had silently no-op'd for 119 commits since the pivot moved
   its target file to `legacy/` — re-ported to `tests/test_base.gd` (a real extraction bug found and
   fixed while porting: the first draft matched local variables inside function bodies, not just
   class-level members), wired into CI too since `--no-verify` skips local hooks. The fuzz probes'
   "did it crash?" check couldn't see a non-hanging crash in `_check_tick()` — fixed with the same
   `SCRIPT ERROR:` guard, confirmed by actually injecting a crash and watching every pre-existing check
   stay falsely green while only the new one caught it.
3. **D0118 — the tautological-test-oracle class named, separately from sweep-blindness.** A test whose
   expected value is derived by calling the function under test can't catch that function's own bugs.
   Three same-day instances (D0112, D0113, D0114), all found only by actually running the real thing, not
   by the unit tests that shipped alongside them.
4. **D0121 — the density screenshots were a capture bug, not a density bug.** The real counts were
   already a strong ~4x contrast (dense=312/sparse=78, already measured and passing). The zoom-6,
   body-following camera showed only ~28% of the topsoil band in one frame — a noisy local sample.
   Fixed with a new `--wide-view` capture mode; `history/154-reveal-density-*.png` replaced in place
   (this round's own first draft superseded, not kept alongside it — 168 images, count unchanged).

## Anything that felt wrong even though it passed

- **My own gate-verification had the identical masking bug the hunt was looking for.** A
  `| tail -N; echo "EXIT=$?"` pattern silently reported `duplication.py` as passing when it had actually
  failed — `$?` after a pipeline is the last command's exit code, not the one that matters. Filed as
  D0117's instance 6, in the same entry as the harness's own version of the same class.
- **The wide-view camera's first attempt centered on the full grid height (~1024 rows) instead of the
  drawn band's own midpoint (180) and produced a blank screenshot.** Caught by actually looking at the
  captured image, not trusted from the math.

## Gates

All layer_lint gates, `schema_validator.py`, `data_codegen --check`, `anvil/check_integrity.py`,
`duplication.py` (0 clusters, 230 GDScript / 164 Python functions), `check_trailers.sh`, and the new
`check_base_namespace.sh` (19/19 subclasses, 0 collisions) — all PASS, real exit codes reconfirmed without
a pipe in the way. All 17 CI-scoped Godot suites PASS through `tools/run_gd_test.sh`. The FULL nightly
fuzzer (`test_body_fuzz.gd`, not CI-scoped) is RED — see D0122 above; this is real, not a harness artifact,
confirmed by the wrapper working correctly and by the A/B control.

**Commits this round: in progress, staying within budget.**

## Claims

`C004-reveal-raises-dig-persistence.md`: `BLOCKED`, unchanged — replay driver still needed.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **D0122 (the `sim/body` regression)** — waits on you: attempt a fix now, or hold for dedicated
  attention given the module's own risk profile.
- **The replay driver** — correctly sequenced after D0115/D0117 (done) and now also logically after
  D0122, since building more on `sim/body` while it has a known live defect is worth a explicit call.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **The hands-on-keyboard `--play` test** — stays open and owed, explicitly not closed by this round.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
