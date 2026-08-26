# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stage 4 (`sim/body`), steps (a)-(g), CLOSED and reported. This round: three
director corrections to last round's work (ADR-0005 reframed, the invariants guard rate-limited,
EntityIdPool confirmed correct), then (f)/(g) — the minimal debug renderer and `--play` mode. Holding
here per the director's explicit "stop after (g)" instruction; rope (step e) is not started.**

**To play it:** `godot --path . tests/body/play_scene.tscn -- --play`. Left/Right or A/D to move, Space
to jump (hold for full height, tap for a short hop), Up/W toward a ledge for `mantle_hold`. Closing the
window writes the session's recording to `tests/body/recordings/play_<timestamp>.log`.

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

- **"The number is stale" and "the number was never real" are different findings, and only one of them
  is safe to act on without re-checking.** D0046 measured 0/4,800 reachable multi-level-floor columns
  after calibrating `ValueNoise` — the natural read is "the accepted-limitation figure went down." The
  sharper read, per the director's own correction (D0051): the terrain shape D0042's 0.85%/12% measured
  was substantially an artifact of the calibration bug, not a smaller instance of a real design cost.
  Conflating the two would have let a future reader credit this ADR's own trade-off for a fix (D0045)
  it had nothing to do with. Also stated explicitly now: 0/4,800 is a null result below this sample's
  resolution, not proof the case cannot occur — a distinction worth naming every time a measurement
  reaches exactly zero, not just this once.
- **An informal "measured: ~N" guess in a code comment is itself an unverified claim.** `body.gd`'s
  pre-fix comment guessed the unratelimited guard logged "~390 lines" from a 400-tick settle — one per
  tick, the obvious mental model. Mutation-testing the actual fix (temporarily reverting the new gate)
  found the real number: **778**, because `_move_and_resolve_vertical` calls `_resolve_floor` twice on
  most resting ticks (once in its substep loop, once via its own trailing catch-all), not once. The
  guess wasn't wrong about the problem, only about its size — caught only by measuring the mutant
  directly rather than trusting a comment that sounded plausible. Every place that number was cited
  (`body.gd`, `invariants.gd`, the ADR, the new test) was corrected to the measured figure in the same
  pass, per this project's own "verify a numeric claim against actual tool output" rule.
- **Rate-limiting state belongs at the caller, not inside a module whose contract says stateless —
  and the director's reasoning for that generalizes.** `sim/invariants` documents itself as producing
  "no gameplay state" (D0052's own instruction was explicit: don't put the memory there even though
  de-duplication needs memory somewhere). `body.gd` already tracks the body's position every tick, so
  that's where "have I already reported this pair" belongs. Worth remembering as a pattern the next
  time a stateless checking module needs de-duplication: push the memory to whichever caller already
  carries the relevant context, don't compromise the module's own contract to save it a line of state.
- **A non-headless engine launch can silently rewrite a config file's own semantics, not just its
  formatting.** One `godot --path .` window launch this round left `project.godot` with every doc
  comment stripped AND `gdscript/warnings/enable=true` gone — the parent flag `docs/DECISIONS.md` names
  as the whole typed-everywhere rule's own enforcement tripwire. Caught by routine `git status` before
  committing, not by any gate (`project.godot` is unpoliced). Could not reproduce it on a second
  attempt with the same command, so it's flagged as an unroot-caused hazard (`docs/WORKING.md`) rather
  than chased to a mechanism — but it's a concrete argument for treating `git diff project.godot` as a
  standing pre-commit check on any session that runs Godot non-headlessly, not just this one.

## What landed this round

Full detail and mutation-test evidence: `docs/DECISIONS_LEDGER.md` D0051-D0053; commits `322bba2`
(follow-ups) and `9ea21f7` ((f)/(g)).

1. **ADR-0005 reframed** (D0051, resolves D0042): the multi-level-floor case was substantially an
   artifact of a `ValueNoise` calibration bug (D0045), not a property of the cave-generation design —
   stated as its own finding, not folded into "the number is stale." 0/4,800 stated explicitly as a
   null result below this sample's resolution. The guard's purpose reframed from "measure a known cost"
   to "watch for this case to reappear after a future generator change."
2. **The floor-selection guard rate-limited at the caller** (D0052): `body.gd::_resolve_floor()` now
   suppresses a repeat `Invariants.report_floor_selection` call while the resolved (column, floor) pair
   is unchanged, clearing on resolution so a later recurrence reads as fresh. `sim/invariants` itself is
   untouched — stays stateless per its own MODULE.md, per the director's explicit instruction. Mutation-
   tested: 778 push_errors from one ~400-tick settle without the gate, exactly 1 with it. New test
   `_test_a_real_settle_rate_limits_the_guard_to_one_report` proves it and fails on the reverted mutant.
3. **EntityIdPool no-op confirmed correct** — no action needed; the director confirmed last round's
   handling (ship the mask for defensive symmetry, correct the commit message rather than claim a
   behavioral fix) was the right call.
4. **(f) Minimal debug renderer**: `tests/body/play_scene.gd`/`.tscn` — flat-color terrain, body, and
   camera, no shaders or sprites, on the director's explicit instruction to resist polish. Verified via
   real windowed screenshot capture against the actual hostile-chamber geometry.
5. **(g) `--play` flag + recorded-input plumbing**: one `--play` cmdline flag switches the same file
   between `agent` mode (`ScriptedTraverse`, self-verifiable without a human) and `play` mode (real
   physical keys — no project input map, D0053, a reversible choice not an oversight). Both write a
   tick-by-tick log to `tests/body/recordings/` — the precursor of `docs/ARCHITECTURE.md` §6's real
   `input.log`, kept deliberately as the seed of a future golden corpus per the director's instruction.
   Verified: parses clean; a headless agent-mode run reaches the chamber's end column and writes a
   correctly-formatted log; a `--play`-mode smoke run initializes and records without crashing (no human
   input available to this session to exercise real key presses).

## Gates

All 9 structural gates PASS (`layer_lint`, `no_engine_imports`, `check_coordinate_naming`,
`check_size_limits`, `check_loc_ratio`, `schema_validator`, `check_claim_references`,
`data_codegen --check`, `check_working_freshness`), plus `check_trailers`. CI's `tests` job: 13/13 Godot
suites PASS, confirmed on the actual latest pushed commit (`gh run` `33023803888`, `9ea21f7`), not an
earlier one — the workflow's `cancel-in-progress` concurrency group means only the newest push's run is
the one that counts. Full local suite: 100 `_test_*` functions across 13 suites, re-counted via `grep`
just now (not carried forward from a prior brief).

**LOC ratio** (measured just now): instrument 3,789 (tools 1,529, tests 2,260) / game 1,264 (core 296,
sim 968). **Absolute ratio 2.998** — essentially flat against last round's 2.896 (this round added real
test/tool code — the new fixture probe, the play_scene renderer's own verification — alongside a modest
amount of real game code). Still above the 1.5-by-`C001` target, still ADVISORY (game LOC under the
2,000-line floor).

**Unpushed commits: 0.** Both of this round's commits are on `origin/main`.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- **Rope (stage 4, step e)** — deliberately not started. Held for a session the director is present
  for: it has no acceptance criteria yet, an agent building it unsupervised would optimize for whatever
  it could measure and risk masking a subtly wrong base controller. The director wants to play the bare
  controller first — see "To play it" above.
- `sim/commands`+`interface` (stage 5) and beyond — downstream, unchanged.
- Chunk size and the coordinate type scheme (above) — waiting on measurement, not a missing decision.

## Taste queue

0 fixtures. The first ones are still wanted once the director has played the bare controller — likely
around rope, or the hostile-chamber fresh-dig slopes already built for (a).
