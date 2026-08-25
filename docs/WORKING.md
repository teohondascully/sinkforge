# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

**Autonomous session, director away.** Authorized scope: ONBOARDING.md stage 1 (`core/`) and stage 2
(`replay_determinism_test` against a trivial stub sim) only. Hard stop before stage 3
(`sim/world`/`sim/terrain_gen`) regardless of remaining budget — those are judgment calls the director
wants to be present for. Budget: 8 commits or the stage boundary, whichever comes first. Hard stops that
mean halt-and-log-to-WORKING.md rather than work around: any gate red not fixable in one attempt (revert,
log, stop); any EXPENSIVE decision per the ledger protocol (log the analysis, pick nothing, stop — fixed-
point bit depth is named explicitly as EXPENSIVE); anything touching `sim/` beyond stubs; three
consecutive commits with no test moving red to green. `docs/BRIEF.md` gets overwritten at the true end of
this run: EXPENSIVE decisions first, then what landed, gates, what stopped, LOC ratio.

Everything below "Two observations" happened in the same session, before this autonomous grant arrived —
kept because it's still true and still open, not because it's today's active work.

## Two observations, logged not acted on (director directive)

1. **Clone-size Phase 1 has not run, and it's more than "hasn't run yet."** `history/` (228 MB tracked)
   and `docs/media/moments` (75 MB tracked) — together ~303 of the ~332 MB tracked total — are not the
   "non-curated visual record" the original instruction described. `.gitignore` lines 56-69 and
   `docs/DECISIONS.md`'s LOCKED "Never destroy a curated file" rule (added after 84 screenshots were once
   purged) both explicitly name this exact content as **the curated archive**, committed 2026-08-17
   specifically because committing was judged "the strongest available form of not destroying" — a
   stronger protection than `.gitignore` or `git rm --cached`, chosen over those on purpose. Moving it to
   a Release asset would reverse that specific, dated, reasoned decision, not just tidy up clutter. The
   rule's letter permits `git rm --cached` (it names that as the sanctioned way to exclude something
   without destroying it) — so this isn't a hard block — but reversing a LOCKED decision deserves an
   informed go/no-go with this history in view, not silent execution of an instruction that described the
   target inaccurately. Awaiting the director's call. `.git` pack staying at ~350 MB regardless (needs a
   history rewrite, separately deferred, not urgent) is unaffected either way.
2. **`docs/handoff/` (≈50 files, ~199 MB) is untracked, confirmed via `git ls-files` (0 results).**
   Protected by `.git/info/exclude`, same mechanism as the other local-only docs. Not a noise problem on
   the public repo — it was never on the public repo. `docs/` root does have ~31 loose files at that
   level (mix of tracked normative docs and untracked local-only ones); no action taken, per instruction.

## Doc triage: closed, with one discrepancy flagged

Re-derived from scratch this session (original reasoning lost to a compaction). Honest count differed
from what was asked for — **two mixed documents, not five** — reported as a discrepancy rather than
forced to fit. `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` promoted verbatim to `docs/EXPERIENCE_EVALUATION.md`
(normative now, cross-referenced from `CLAIMS.md` §5 and `ARCHITECTURE.md` §7). `docs/DIRECTOR_BRIEF.md`
and `docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md` each had one durable core, extracted to
`docs/archive/` with dated headers. Six candidates (`REPO_PORTFOLIO_AUDIT.md`, `FEEL_GAP.md`,
`MENU_MATRIX.md`, `VISUAL_RECOMMENDATIONS_SURFACE.md`, `RELEASE_HARDENING.md`, `A_PLUS_PROGRAM.md`) stay
local — no durable core left unclaimed in any of them. `docs/PRIORITY.md` and `docs/ORCHESTRATOR.md`
dispositions confirmed, unchanged. Full reasoning in commit `57d2051`.

## Design/process decisions closed this session

- Sinkforge is a stratum, not an object; layers are rule sets, not destinations; Draft A's run curve is
  9 runs not 25; R1's cost mechanism is per-unit-per-meter, boundary-only for now, built to extend by data
  change (`docs/adr/0002`). `docs/GDD.md`, commit `a76d851`.
- Freight Winch gated on `sim/commands` and `sim/run` having real implementations, not skeletons — noted
  in both MODULE.md files. Commit `13960e9`.
- Two new normative protocols, both markdown-and-git-only, no new tooling: review bandwidth
  (`docs/DECISIONS_LEDGER.md`, reversibility CHEAP/EXPENSIVE gating, `docs/TASTE_QUEUE.md`,
  `docs/BRIEF.md`) and playable fixtures (`--play` flag on the harness driver, fixtures derived never
  authored, blind before/after review, fixture ownership as the parallelism contract). Both in
  `CONTEXT.md` now. Commit `bea703d`.
- Repo stays public — settled earlier, unchanged.
- 31 pre-existing pre-pivot commits: clean fast-forward, no divergence risk. Bazaar confirmed sunk cost.

## Discoveries not yet written anywhere durable

None outstanding as of the start of the autonomous session — everything above is in a commit message or
this file. Anything found during stage 1/2 work gets logged here or to `docs/DECISIONS_LEDGER.md`
immediately, not batched.
