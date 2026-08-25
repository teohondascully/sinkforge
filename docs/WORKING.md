# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

Task 0 (repository restructuring) is done and committed. This session also closed three
director-requested decisions and two batches of doc changes before touching `core/`. **Task 1
(`core/`) has not started** — flagged as its own stage/session per the one-stage-per-session rule
this same session added to `CONTEXT.md`, rather than starting real implementation at the tail of an
already very long session. Awaiting the director's confirmation to either start Task 1 now or treat
this as the handoff point.

## Done, this session, all committed

- Task 0, all 6 sub-tasks, 5 commits (`4758d5a`, `056a515`, `cf00607`, `e06da90`, `9572aa4`).
- Context-compaction protocol: `CLAUDE.md`, `docs/WORKING.md`, `CONTEXT.md` section (`46a4ae5`).
- Claim-rot mechanisms + data-version history + Godot pin + QUALITY.md self-subject note (`8891977`).
- Movement/collision architecture: resolution split, rope/grapple promoted to the traversal
  primitive, extended hostile chamber, claim C002 (`a775e78`).
- `pre-pivot` tag pushed to origin. Local `main` NOT yet pushed — 8 commits ahead of `origin/main`
  as of this write (31 pre-existing + 5 Task 0 + 2 this batch), confirmed clean fast-forward, safe
  to push, director said to (see decisions below). Push this before ending the session if not
  already done.

## Decisions closed this session

- **Repo stays public.** Reasoning: already public since 2026-08-10 with deliberate prior investment
  (MIT + decomposition, per memory), the project's stated purpose (portfolio piece) requires
  visibility, local-only docs are already correctly protected via `.git/info/exclude` independent of
  repo visibility, and current exposure is low (1 fork, 1 star, 0 watchers) so a future history
  rewrite's blast radius stays small if one is ever warranted.
- **31 pre-existing commits: clean fast-forward, no divergence risk, safe to build on.** Two clusters
  flagged rather than silently absorbed: Freight Winch (5 commits, real design-approved work with a
  working verb stub already in the old `main.gd`) needs `sim/commands`/`sim/run` built first per the
  compat audit's own risk register before resuming; Bazaar (5 commits) is confirmed sunk cost on the
  core mechanic, only the shop-panel UX pattern might be worth referencing later.
- **8 local-only documents triaged, recommend-only, nothing moved.** `PRIORITY.md` stays local
  (Bucket A, cleanly). `AGENT_PLAY_EVALUATION_PROTOCOL.md` promote to archive, or even normative —
  strongest candidate (Bucket B, cleanly). Six are mixed A/B splits; `ORCHESTRATOR.md` is the one
  that needs a rewrite before archiving (valuable methodology entangled with second-person
  address-to-an-AI voice, the same commissioner-voice pattern this project already did one history
  rewrite to scrub). Full detail in the response given to the director; not reproduced here.
- **Clone size (349 MB): plan proposed, not executed.** Moving the non-curated visual record to a
  GitHub Release asset (no history rewrite) shrinks working-tree/checkout size (~332 MB → ~25-30 MB)
  but does **not** shrink what a plain `git clone` actually downloads (`.git` stays ~349 MB, since
  every historical blob remains reachable from old commits regardless of what HEAD contains). Real
  clone-size reduction needs a history rewrite (`git filter-repo`), explicitly deferred, now
  low-blast-radius given the public/private answer above (1 fork). Awaiting director go/no-go on
  Phase 1 (Release asset move) before doing anything.
- The four `.rc-prose-*.patch` files were fully superseded by existing commits — zero net change.
- `PRIORITY.md` and `DIRECTOR_BRIEF.md` restored to original untracked, local-only state after being
  accidentally tracked mid-Task-0. Do not re-attempt archiving without a fresh decision.
- `check_loc_ratio.py` counts `.gd` + `.py` + `.sh`, not `.gd` alone.

## Open questions for next session

- Does the director want Phase 1 of the clone-size plan (Release asset move) executed now, or held
  until the filter-repo question is also decided, so it's one clean pass instead of two?
- Does any of the 8-document triage get acted on (especially `ORCHESTRATOR.md`'s rewrite), or held?
- Confirm: start Task 1 (`core/`) next session, or does the director want to redirect first?

## Discoveries not yet written anywhere durable

- None outstanding. Everything found this session (case-collision bug, LOC-ratio self-blindness,
  `.git/info/exclude` path drift, the local-only-docs discovery, the dead patch files) is already in
  commit messages or in this file.
