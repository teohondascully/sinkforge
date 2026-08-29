# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the micro-loop design finding lands (`docs/GDD.md` §12), the
Reveal want-layer's first test built end to end — dig mechanic, terrain extension, debug scene, dig-rate
metric with mutation tests, screenshots — closed, no hard stop.** `docs/DECISIONS_LEDGER.md`
D0107–D0116. Three screenshots attached to the report. `data/economy/` and flow/pressure untouched.

---

## What landed

1. **`docs/GDD.md` §12: the micro-loop finding (D0107).** The rig-as-consumer macro-loop had no
   micro-loop underneath it — feeding the rig is a transaction, minutes apart, with nothing renewing
   interest between deliveries. Three want-layers named: Reveal ("what's behind this wall," cheapest,
   tested this round), Flow ("that's jammed, fix it," unbuilt), Pressure ("push deeper or shore up,"
   unbuilt, deliberately not resolved by building the simpler grind version). Inserted, not
   renumbered-around (grep-verified zero external cross-references to old §12/§13 first).
2. **`claims/C004-reveal-raises-dig-persistence.md` filed BLOCKED, metric corrected before building
   (D0108/D0109).** The brief's original framing ("does the player travel toward an unrevealed feature")
   was circular against `docs/EXPERIENCE_EVALUATION.md`'s own Readiness Gate 6 — measuring it needs
   feature-location knowledge the player doesn't have either. Corrected, director-confirmed, to:
   dig-events-per-session, plus the change in dig rate in a 300-tick window after a reveal versus before
   it, using only information visible at the moment of a dig. The anti-cheat property is stated explicitly
   in the metric's own docstring, not just in prose that could drift from the code.
3. **Legacy checked before writing new generation code, per the director's explicit ask (D0111).**
   `legacy/src/core/layered_world_gen.gd`'s vein/pocket placement algorithm is genuinely reusable — its
   shape (seeded RNG walk, size-bounded growth) matches `ShaftGenerator`'s existing `_grow_vein`, reused
   directly rather than reinvented. Its persistent-world-tied distribution structure was correctly NOT
   ported wholesale — this build's Reveal layer is a bounded dig-test area, a different fit, named as a
   real finding rather than glossed over.
4. **The dig mechanic (D0110), plus two real bugs found only by running the scene (D0112/D0113).**
   Horizontal-only, edge-triggered, whole-body-height column, no hardness gate — smallest thing that
   tests the hypothesis, not R4's eventual tool-tier system. Both bugs (a right-facing target-cell
   off-by-one; a single-row dig too short to walk through a 10-cell body) were invisible to that commit's
   own first-draft unit tests because those tests derived their expected values by calling the function
   under test — the same tautological-test class this project has now named three times in one day.
   Rewritten to derive expected values independently; the rewrites are confirmed (by mutation) to catch
   the reverted bugs where the originals would not have.
5. **`RevealMetric.compute` built and mutation-tested (D0114).** Its own first-draft test suite had 2
   test-authoring bugs (a strict `>` sitting on an exact computed boundary; an under-sized synthetic
   array denying the second of two reveals a full window) — both root-caused as test bugs, not
   `compute()` bugs, before touching either. The window-boundary exclusion guard itself was then
   mutation-tested: both boundary-operator mutations (`<`→`<=`, `>=`→`>`) produce real, unambiguous
   failures, reverted immediately after confirming.
6. **A real, unrelated FINDING surfaced by that mutation testing (D0115): the shared test harness doesn't
   register a mid-test crash.** A `SCRIPT ERROR` (uncaught out-of-bounds read, from one of the mutations
   above) aborted a test function mid-run — the harness kept going, printed `ALL PASS`, and exited 0.
   Flagged, not fixed: `tests/test_base.gd` is shared by every suite in the project, and deciding how it
   should behave on an uncaught error is a real design decision, not a parameter this round owns.
7. **Reveal-layer terrain extension**: `data/materials/glimmer.yaml` (inert, no economy meaning),
   `reveal:` added to `data/strata/SCHEMA.yaml`, `ShaftGenerator._scatter_reveal_material`, two test-only
   density sites (`reveal_test_sparse`/`reveal_test_dense`). 4 new `test_shaft_generator.gd` cases,
   including a measured density contrast at the same seed: dense=312 glimmer cells, sparse=78.
8. **`tests/body/reveal_scene.gd`, a new debug scene** modeled on `play_scene.gd`'s own flat-color,
   no-shader discipline. Producing it surfaced a real, incidental duplication-gate failure — see below.
9. **Screenshots captured, `history/` updated honestly.** `153-the-glimmer-in-the-wall.png` (the
   mechanism working: a dug column next to several glimmer pockets), `154-reveal-density-sparse.png` /
   `154-reveal-density-dense.png` (the same seed, both test sites — density is the swept variable).
   Captured via `reveal_scene.gd`'s agent mode, **not** literal `--play` — no human keyboard was
   available to this session, stated plainly in `history/README.md` rather than glossed over; the
   renderer code is identical regardless of input source, so the pixels are representative. `history/`'s
   unapplied cap-of-12 policy (set 2026-08-25) is still unapplied (168 images now) — the 3 additions were
   made without a swap-one-out, flagged rather than either silently violating the policy or unilaterally
   running the 165-image pre-pivot cull, which isn't this session's call.

## Full-tree duplication result

**A real cluster this round, found and fixed, not excluded.** `duplication.py` (CI's blocking gate)
caught `reveal_scene.gd`'s `_record_tick`/`_notification` as an exact-shape duplicate of `play_scene.gd`'s
own — expected, since `reveal_scene.gd` was deliberately modeled closely on `play_scene.gd`, which is
exactly the case this gate exists to catch. Fixed by extracting the shared logic into a new
`tests/body/debug_scene_common.gd`, used by both scenes. Re-run clean: 227 GDScript / 164 Python
functions considered, 0 clusters, both languages.

## Anything that felt wrong even though it passed

- **A `| tail -N; echo "EXIT=$?"` pattern silently reported `duplication.py` as passing when it had
  actually failed** — `$?` after a pipeline captures the last command's (`tail`'s) exit code, not the
  script's. Caught by re-running every gate this round without the pipe, which is what surfaced the real
  duplication-gate failure above. The exact "existence probe has no witness" class applied to my own
  gate-checking process this time, not to game code — worth a beat of self-suspicion whenever a check
  reports success and I didn't verify the check itself was watching the right exit code.
- **`RevealMetric.compute`'s own guard mutation testing produced a crash, not a clean FAIL line, and the
  harness's own final summary still said `ALL PASS`.** Recorded as D0115 rather than dismissed as a fluke
  of this one test — the crash was loud enough to notice by eye in this session, but wouldn't be in an
  unattended CI run that only checks the exit code and the last line.

## EXPENSIVE, awaiting you

- **The replay-driver piece was not built.** Reading a real recorded `tests/body/recordings/*.log`
  session into a `RevealMetric.TickEvent` array — the piece that lets `claims/C004` run against a real
  session instead of only synthetic test data — is the natural next step, honestly scoped out rather than
  rushed at the 50-minute mark of a 1-hour budget. The current recording-log header doesn't record
  site_id/seed, only mode/ticks; that'll need a small addition first.
- **D0115: the shared test harness (`tests/test_base.gd`) doesn't register a mid-test crash as a
  failure** — exits 0, prints `ALL PASS`, even after an uncaught `SCRIPT ERROR` aborts a test function.
  Affects every `test_*.gd` suite in the project, not just this round's. Deciding the right behavior
  (fail the enclosing test, track a global error count, something else) is a real design call, not
  something to default on without you.
- **`history/`'s cap-of-12 policy is still unapplied, now against 168 images (165 pre-pivot + 3 new).**
  Culling which of the 165 pre-pivot images still illustrate a finding that survives the pivot is a real,
  judgment-heavy, destructive-at-scale decision — still not this session's to make unilaterally.
- **The 3 new screenshots were captured via agent mode, not literal `--play`.** No human was at a
  keyboard for this session. If you want a literal `--play` capture for legibility judgment specifically,
  that needs you (or someone) actually driving `reveal_scene.tscn -- --play`.
- Flow and Pressure (the other two want-layers) remain named, confidence-marked, and unbuilt — Reveal was
  the only one in scope this round.

## What was learned

- **A test that derives its expected value by calling the function under test can't catch a wrong
  formula in that function — and it's easy to write by accident, twice in one feature.** Both dig-mechanic
  bugs (D0112, D0113) and the reveal-metric's first-draft tests all needed independent-arithmetic
  rewrites for the same reason. Worth checking for this shape specifically whenever a new test's
  "expected" value comes from anywhere other than a hand computation or an independently-known constant.
- **Actually running the thing found two real bugs the unit tests missed; actually mutation-testing the
  guard found a harness gap the unit tests couldn't have surfaced at all.** Both disciplines this project
  already mandates (run it, don't just test it in isolation; mutation-test a new guard) each paid for
  themselves independently in the same build round.
- **Recycled algorithm code and recycled rendering are different axes, and conflating them reads as
  "regression."** This round's screenshots use the same flat-color, no-art debug renderer every debug
  scene in this rebuild has used since the pivot — legacy's visual polish (sprites, lighting, shaders) was
  never in scope and was never ported. Worth stating plainly whenever a debug-render screenshot is shared,
  not just assumed obvious.

## Gates

All layer_lint gates PASS (real exit codes re-verified after an earlier pipe-masking near-miss, see
above): `layer_lint.py`, `check_claim_references.py`, `check_coordinate_naming.py`,
`check_project_settings.py`, `check_size_limits.py`, `no_engine_imports.py`. `check_untracked_files.py`
failed only on this round's own not-yet-committed new files — resolves at commit.
`schema_validator.py` (10 data files), `data_codegen/generate.py --check` (2 codegen kinds),
`tools/anvil/check_integrity.py` (9 events, referentially sound) all PASS. `duplication.py`: real failure
found and fixed (see above), re-run clean, 0 clusters. All 17 non-nightly Godot test suites (including
`test_body_fuzz_fast.gd` and `test_replay_determinism.gd`) re-run after the dedup refactor: **ALL PASS**,
exit 0, no regression. Full (nightly-only) fuzzer not run — out of scope for a per-commit gate pass.

**Commits this round: 6, within the 24-commit budget.**

## Claims

`C004-reveal-raises-dig-persistence.md`: `BLOCKED` — instrument built and tested, replay-driver and a
real recorded session still needed before a first measurement. `C001-two-minute-run.md`: `RETIRED`,
unchanged. `C002-traversal-over-rubble.md` / `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.

## Blocked, and what it's waiting on

- **`claims/C004`** — waits on the replay-driver and a real recorded `--play` session (human, not agent
  mode).
- **D0115 (test-harness crash-blindness)** — waits on a director decision about shared test
  infrastructure.
- **`history/`'s 165-image pre-pivot cull** — waits on you, explicitly, per the policy's own note.
- **`data/economy/`, D1-D6** — unchanged, waits for you, explicitly, with you present.
- **`sim/run`/`sim/meta`'s shape** — unchanged, waits for a real decision.

## Taste queue

0 fixtures. Unchanged.
