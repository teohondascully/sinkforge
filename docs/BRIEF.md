# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: D0122 closed for good (D0128), then the claims/C004 replay
driver built (D0129).** `docs/DECISIONS_LEDGER.md` D0128–D0129. **Headline: `test_body_fuzz.gd` is ALL
PASS again with an honestly re-baselined bound, and a recorded reveal session now feeds `RevealMetric`
end to end — proven against a synthetic trace, with real-human validation explicitly still owed, not
smoothed over.**

---

## The one that matters most: D0122's arc is fully closed, and the replay driver plumbs end to end

**D0128.** `grounded_no_floor`'s bound raised 32→59, documented (not patched) — every one of the 59
violations is the same D0059f pit-lip mechanism D0127 already proved, just reachable at more
player-carved locations now that dig exists. `bounds`'s +11.4% water-mark-fix cost accepted as a real,
attributed consequence. Full sweep re-run: `test_body_fuzz.gd` ALL PASS. D0122 itself closed in the
ledger — seven entries (D0122-D0128), nothing left open.

**D0129.** `RevealReplayDriver` takes a recorded `reveal_scene.gd` session and replays it through the
real `Body.tick()`, feeding only `dig_event_this_tick`/`dug_material_this_tick` to `RevealMetric.compute`
— the anti-cheat property (no feature location) held by construction, not convention. Proven: a live
session and its own replay match EXACTLY (0/713 ticks mismatched). Explicitly NOT proven: claims/C004
itself, since the trace is agent-generated (scripted), not real human play, which C004's own design
requires. The hands-on-keyboard `--play` session is still the open next step — this build does not
substitute for it.

## What landed

1. **D0128** — the bound raise + docstring, `test_body_fuzz_fast.gd`'s stale "seed>=98" claim corrected.
2. **D0129** — `tests/body/reveal_session_setup.gd` (extracted so the live scene and an offline replay
   build the identical session), `tests/body/reveal_replay_driver.gd` (parse/replay/compute), `tests/
   body/replay_reveal_scene.gd` (CLI front end), `tests/test_reveal_replay_driver.gd` (4 tests, 2
   mutation-tested). `reveal_scene.gd`'s recording header gained `site=`/`seed=`, previously absent and
   load-bearing for replay correctness.
3. **Two parallel forks used for genuinely disjoint work** (debug/mutation-test the 5 driver files vs.
   wire CI + audit stale docs), both in the single shared working tree — no worktree isolation, nothing
   to merge afterward. One fork's first pass silently under-delivered (reported "completed" having
   touched neither of its two target files); caught by directly verifying the diff against the actual
   working tree rather than trusting the completion summary, then resumed to actually do the work.

## Anything that felt wrong even though it passed

- **A real gate failure neither fork's own narrower test run surfaced**: a 54-line function against the
  50-line function-length fence. Found by this session's own full local gate sweep, not by either fork —
  worth naming as a general risk of fork/subagent verification scoped only to "does the target test
  pass," not the full commit-readiness gate list.
- **A subagent's "completed" status didn't mean "did the assigned work."** One fork reported finishing
  without having touched `harness.yml` or `docs/QUALITY.md` at all. Caught immediately by checking
  `git diff` directly rather than trusting the summary text, then resumed successfully. Reinforces the
  standing practice of verifying subagent claims against the actual tree, not the report.

## Gates

All layer_lint gates, `schema_validator.py`, `data_codegen --check`, `anvil/check_integrity.py`,
`duplication.py` (0 clusters, 248 GDScript functions), `check_untracked_files.py`,
`check_base_namespace.sh` (21/21 subclasses), `check_trailers.sh`, `check_claim_references.py` — all
PASS. `test_body_fuzz.gd` (full 1000×1500 sweep, previously red against a stale bound) now ALL PASS.
`test_reveal_replay_driver.gd` — new, ALL PASS, mutation-tested.

Instrument/game LOC ratio: not re-measured this round — no `core/`/`sim/` change (D0128 touched only
`tests/`; D0129 is entirely `tests/body/`). Last measured 5.735 absolute, still ADVISORY.

**Commits this round: in progress, staying within budget.**

## Claims

`C004-reveal-raises-dig-persistence.md`: `BLOCKED`, unchanged in status — the plumbing it needs now
exists (D0129), but the blocking condition (real recorded human play) is still unmet.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **The hands-on-keyboard `--play` session** — now the SOLE remaining blocker on `claims/C004` (the
  replay driver is built and proven against a synthetic trace); stays open and owed, unchanged in nature
  but sharper in consequence now that everything downstream of it is ready.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
