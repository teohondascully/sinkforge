# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-29. This round: the control-plane ruling's two items. Item 1 landed as ADR 0006.
Item 2 could not be done as prescribed — its premise was mis-transcribed from the audit it came from — so
it was reported, on the branch the ruling itself pre-authorized.** `docs/DECISIONS_LEDGER.md` D0140, D0141.
**Headline: writing the episode-log constraint before the format sets immediately found that the format
already exists AND is already broken — two recording dialects that each drop a different `InputFrame` field
into positionally identical columns, guarded only by an unrelated header check.**

---

## The one that matters most: the constraint written "before the format sets" found the format already set, and wrong

The director's item 1 was to record a requirement for a log that does not exist yet: it must carry the full
replayable prefix, not just an observation trace, so forking is not foreclosed. Writing it down turned up
two things the ruling did not anticipate.

**The required format already exists, and `docs/ARCHITECTURE.md` §5 already makes it mandatory.**
`reveal_replay_driver.gd` (D0129) already parses `(site, seed)` plus a per-tick input sequence and replays
through the real `Body.tick()`. §5 forbids the alternative outright: "A second, incompatible input-replay
format built for pre-interface testing would be a design leak." So the episode log is that format's
descendant, not a new sibling — a much sharper constraint than "record enough."

**And that format is already not a complete prefix.** `InputFrame` has five input fields.
`play_scene.gd` records `…,mantle_hold`; `reveal_scene.gd` records `…,dig_pressed`. Each drops a different
field; both emit five positionally identical columns; the shared writer's fifth parameter is literally named
`last_field`. `RevealReplayDriver` validates `fields.size() != 5` — which both dialects pass. What actually
stops a misparse today is that play_scene logs lack `site=`/`seed=` and fail an unrelated check first. That
guard is a coincidence, and its expiry has a name: the day `site=`/`seed=` is retrofitted onto
`play_scene.gd` (already done once, for reveal_scene, by D0129), `mantle_hold` starts replaying as
`dig_pressed` silently. Filed as an Anvil FINDING with that trigger named. Not fixed — four files and every
recording on disk, including whatever `claims/C004`'s pending session produces.

## What landed

1. **D0140 / `docs/adr/0006-episode-log-replayable-prefix.md`** — the fork-context requirement, plus the two
   findings above, plus one thing recorded as explicitly NOT demonstrated: real-sim replay determinism.
   `test_replay_determinism.gd` proves the mechanism against a stub its own docstring says is "NOT `sim/`
   and never will be." No test asserts real `Body` + `TileGrid` replay bit-identically. Named as an unproven
   prerequisite so a future fork inherits the gap instead of discovering it. Nothing forks; no log built.
2. **D0141** — item 2 reported rather than routed around, with three verified corrections to its premise.

## Anything that felt wrong even though it passed

- **A ruling's premise can be mis-transcribed from the audit it came from, and the paraphrase can invert
  which side of a boundary the problem is on.** Item 2 said the builder "reaches into a test helper for grid
  access." It reaches into `Body._px_to_cell` — a `sim/` private — for a coordinate conversion; grid access
  is already through `TileGrid`'s real public API. Codex said this precisely and drew the opposite
  conclusion: "the slice has no test-internal dependency, but its eventual L2 placement needs a deliberate
  public sim boundary." Worth keeping: read the audit, not the summary of the audit, before acting on it.
- **"Fix it, while it is one reference" was the wrong scale.** `Body._px_to_cell` has call sites in 21 files,
  17 under `tests/`. The builder's use of it is this repo's established convention, not a lapse. The real
  fix is deciding where a *public* position-to-cell conversion lives — a `sim/` change to the highest-risk
  module, not a cleanup.
- **The shortcut was available and is worth naming as rejected**: re-typing `floor(px / (CELL_PX * Fx.SCALE))`
  inline would satisfy the letter of the ruling while duplicating a load-bearing conversion into a second
  unlinked site. Strictly worse than the honest private reference.
- **One precision point, since the director explicitly asked Codex for it.** The ruling opens "Codex
  confirmed the contract is genuinely model-agnostic." Codex's actual verdict was narrower and said so
  twice: "This permits model-agnostic adapters; it does not demonstrate them," and "It is not yet a
  demonstrated model-agnostic control plane." No second policy exists. The contract is structurally neutral;
  neutrality is not yet a measured property.

## Gates

All `layer_lint` gates PASS **except two, both pre-existing and both traced to the uncommitted D0139 work,
not to this round**: `check_size_limits` FAILs on `sim/body/vertical_resolve.gd::resolve_floor()` at 59 lines
(limit 50) — verified PASS at HEAD, where it is 49 — and `check_untracked_files` FAILs on
`tests/test_vertical_resolve.gd`. Both clear the moment D0139 is ruled on. `schema_validator.py`,
`data_codegen --check`, `check_working_freshness.py`, `anvil/check_integrity.py` (15 events, +2 this round)
— all PASS. No `sim/` or `core/` file was touched this round.

**Commits this round: 1, pushed.**

## Claims

`C004-reveal-raises-dig-persistence.md`: unchanged, `BLOCKED` on the hands-on-keyboard `--play` session —
and note that session's output is one of the recordings the dialect finding above would invalidate if the
format is repaired afterward. `C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **D0139 / `resolve_floor`** — unchanged from the pre-compaction checkpoint. Two hard-stop findings
  reported, un-ruled: the acceptance signal did not drop (59 → 59, mechanism flipped entirely to
  `grid_floor_backstop`, which has the identical criterion flaw — the "second bug" the ruling anticipated),
  and a real regression against `test_body_acceptance.gd` traced to an authored rubble notch. **New this
  round:** the attempt also breaks `check_size_limits` (`resolve_floor` 49 → 59 lines against a 50 limit),
  so it is not shippable as written even if both findings resolve. Working tree still dirty on purpose.
- **The dropped Codex finding — CONSTRAINED restricts distance, not discovery.** Codex ranked it first
  ("the most important divergence"); the ruling accepted two findings and did not address it. The envelope
  hands out the material of undug rock inside its radius, so it cannot measure the discoverability
  `docs/ARCHITECTURE.md` §5 says it exists to measure. Disclosed in the slice's own comment as a deferral,
  so this is a question, not a defect: is a radius-only CONSTRAINED acceptable as the first envelope, or
  does the name need earning before the contract is declared to stand? Anvil FINDING `ed491e83`.
- **Where a public position-to-cell conversion lives** — the actual liftability decision (D0141).
- **The persistent-world GDD reversal** — untouched. Its text exists only in pre-compaction history and
  must be re-supplied before `docs/GDD.md` is touched.
- **The hands-on-keyboard `--play` session** — unchanged, still the sole remaining blocker on `claims/C004`.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **`data/economy/`, D1-D6** — unchanged, yours.

## Taste queue

0 fixtures. Unchanged.
