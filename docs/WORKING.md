# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first.

## Current stage

Between Task 0 (repository restructuring) and Task 1 (`core/`). Task 0 is committed and done. Not
yet building code — resolving three decisions the director wants closed first, plus two batches of
doc changes, before touching `core/`.

## Done

- Task 0, all 6 sub-tasks, 5 commits (`4758d5a` legacy move, `056a515` root cleanup, `cf00607` doc
  triage, `e06da90` skeleton, `9572aa4` gates). `pre-pivot` tag pushed to origin. Local `main` is
  36 commits ahead of `origin/main`, not yet pushed (see open question below).
- Confirmed: repo is public on GitHub (`teohondascully/sinkforge`), 1 fork, 1 star, 0 watchers,
  created 2026-08-10. Director's quick answer was "stays public, push what I have" — full reasoning
  still owed (see open questions).

## In flight right now

- Fork triaging the 8 local-only documents (`PRIORITY.md`, `DIRECTOR_BRIEF.md`, `ORCHESTRATOR.md`,
  `AGENT_PLAY_EVALUATION_PROTOCOL.md`, `FEEL_GAP.md`, `MENU_MATRIX.md`,
  `VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md`, `VISUAL_RECOMMENDATIONS_SURFACE.md`) into three
  buckets: stays-local, promote-to-archive, genuinely-private. Recommend only, don't act. Not yet
  reported back.
- Not yet started: claim-rot mechanisms doc changes (docs/CLAIMS.md), Godot version pin
  (project.godot + README.md), movement/collision resolution-split doc changes (ARCHITECTURE.md §9,
  CONTEXT.md, GDD.md, one new BLOCKED claim), QUALITY.md note on gates being subject to themselves.

## Open questions (director owes/awaits an answer, or I owe one back)

1. **Clone size (349 MB).** Director wants a plan: ~10 curated images stay in `docs/media/`, the
   rest of the curated visual record moves out of the default clone, a pointer left explaining
   where. Must report honestly whether this shrinks the actual `.git` clone transfer or only the
   working-tree checkout — early analysis says: without a history rewrite, moving files out now
   only shrinks the checkout, not the `.git` pack, because every historical blob stays reachable
   from old commits regardless of what HEAD currently contains. Real clone-size reduction needs
   either a history rewrite (deferred, gated on public/private + fork/star exposure) or GitHub
   Release assets (genuinely outside git's object model, not gated on a rewrite).
2. **31-commit audit — DONE.** Clean fast-forward confirmed (`merge-base origin/main pre-pivot`
   == `origin/main` tip; `git log pre-pivot..origin/main` empty). Single author throughout, no
   divergence risk, safe to push whenever. Content: 100% of the 31 commits touch code now in
   `legacy/`, none ported yet. Two clusters worth flagging rather than silently absorbing:
   **Freight Winch (5 commits)** is real, design-approved work (a working verb stub already existed
   in the old `main.gd`) that `docs/archive/COMPAT_AUDIT_2026-08-25.md`'s own risk register #1 says
   needs `sim/commands`/`sim/run` built first so it has a real home rather than regrowing as ad hoc
   verbs — treat that as a prerequisite gate before resuming Winch work, not a suggestion. **Bazaar
   (5 commits)** is confirmed sunk cost on the core mechanic (the audit names `scenes/bazaars.gd` an
   explicit DELETE); the surrounding shop-panel mouse-click UX pattern may still be worth referencing
   when porting generic shop/menu infra, but the Bazaar concept itself is cut. Remaining 21 commits
   (tutorial/teaching content, HUD/UX polish, docs/housekeeping) are orthogonal or genuinely portable
   per the existing compat audit's subsystem scores — nothing else blocks starting `core/`.
3. **8-document triage** — pending fork above.
4. **Public vs. private, with reasoning** — leaning public: already public since 2026-08-10 with
   deliberate prior investment (MIT decomposition, per memory), portfolio purpose requires
   visibility, local-only docs are already correctly protected regardless of repo visibility. Low
   fork/star count (1/1) means a future history rewrite's blast radius is currently small if one
   is ever warranted. Full write-up still owed to the director.

## Decisions made this session

- Repo stays public (director-confirmed, quick answer; full reasoning still being written).
- The four `.rc-prose-*.patch` files were fully superseded by existing commits — zero net change
  after resolving all conflicts in favor of HEAD. No action needed beyond deleting the patch files
  (done).
- `PRIORITY.md` and `DIRECTOR_BRIEF.md` restored to their original untracked, local-only state after
  being accidentally tracked mid-pass. Do not re-attempt archiving them without a fresh decision.
- `check_loc_ratio.py` counts `.gd` + `.py` + `.sh`, not `.gd` alone (was blind to its own source).

## Discoveries not yet written anywhere durable (write before compaction if this list grows)

- None outstanding — the case-collision bug (`docs/ADR/` vs `docs/adr/`), the LOC-ratio
  self-blindness bug, and the `.git/info/exclude` path drift after the `legacy/` move are all
  already fixed in place and described in commit messages (`9572aa4`, `cf00607`). Nothing currently
  lives only in this session's context except the two forks' not-yet-returned results and the
  reasoning above — both captured here now.
