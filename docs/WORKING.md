# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

**Stages 1 and 2 both landed. Stopped here, deliberately, per explicit instruction: do not begin stage 3
(`sim/world`, `sim/terrain_gen`) even with budget remaining — those are judgment calls (worldgen
porting, scenario format) the director wants to be present for.** Stage 1: `560ee78`. Stage 2
(`tests/test_replay_determinism.gd`, a throwaway stub exercising all three `core/` primitives, full
20,000-tick/100-tick-interval replay check, mutation-checked): `f51d722`. No commits used toward stage 3
scope. Next session (or next instruction) starts stage 3 fresh, or redirects.

## Landed and closed, with commit references

- Task 0 (repository restructuring), context-compaction protocol, claim-rot mechanisms, movement/
  collision architecture decisions — all from the first half of this session, commits `4758d5a` through
  `51301a4`. Detail in those commit messages, not repeated here.
- Freight Winch gate on `sim/commands`/`sim/run` (`13960e9`); Sinkforge-as-stratum, layers-as-rule-sets,
  9-run curve, R1 scope ADR-0002 (`a76d851`); review-bandwidth and playable-fixtures protocols now in
  `CONTEXT.md` (`bea703d`).
- Doc triage closed with one discrepancy flagged (two mixed documents, not five — reported rather than
  forced to fit): `docs/EXPERIENCE_EVALUATION.md` promoted and cross-referenced from `CLAIMS.md` §5 and
  `docs/README.md`'s normative table; `docs/archive/DIRECTOR_BRIEF.md` and
  `docs/archive/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md` extracted (`57d2051`).
- LOC-ratio gate rewritten as a trailing-window trend measure, verified against four synthetic-repo
  controls (`4fbfb71`); Stage 1 core/ landed — `Fx`, `SplitRng`, `EntityIdPool`, 96 tests, all
  mutation-checked (`560ee78`).
- **Clone-size Phase 1 withdrawn**, made legible in `README.md`'s "On clone size" paragraph instead —
  `history/`/`docs/media/moments` are the LOCKED curated archive, not disposable bulk; a Release asset
  would be a step back to weaker protection than committing already gives them.
- **`docs/handoff/` reviewed and deliberately deferred** — untracked, confirmed via `git ls-files`, never
  a portfolio problem. Logged so it isn't re-triaged as an open question later.
- Note for whenever `README.md` gets its real post-pivot rewrite (not now): `docs/EXPERIENCE_EVALUATION.md`
  's "no layer may certify all six questions" and its six-layer evidence separation belong in it —
  marked directly in `README.md`'s stale-pivot banner so it isn't lost before then.

## Discoveries not yet written anywhere durable

None outstanding. Two real GDScript-runtime findings from Stage 1 are already in `core/MODULE.md`'s
Gotchas: an unguarded runtime error inside a bare `--headless --script` run hangs rather than crashes
(no `quit()` ever reached), and `>>`/`<<` reject a syntactically-negative left operand at parse time but
allow the identical runtime value through a variable. Anything found during Stage 2 gets logged here or
to `docs/DECISIONS_LEDGER.md` immediately, not batched.
