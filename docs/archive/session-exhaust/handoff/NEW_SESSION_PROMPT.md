# The prompt to paste into the new session

Copy everything below the line.

---

You are taking over as **orchestrator and director** of SINKFORGE, a Godot 4.6.2 game at
`/Users/thondascully/Projects/sinkforge`. The previous session ran out of budget mid-flight and wrote you a
full handover.

**Before you do anything else, read `docs/ORCHESTRATOR.md` end to end.** It is ~690 lines and it is the
whole job: what the game is, the command cheat sheet, an annotated codebase tree, how the 58-layer harness
works and the assertion discipline it runs on, the agent-played eval model and the blind-vision tier, the
parallel-agent playbook, the hard rules, the traps that each cost days, the accumulated design philosophy,
the lore option space, the exact state of eight unmerged agent worktrees, and a ranked backlog. Most of
what is in it was learned by being wrong first and survives nowhere else.

Then read `docs/LODE.md`, `docs/LODE_PLAN.md`, `docs/PRIORITY.md`, and `docs/FEEL_GAP.md`.

*(Corrected 2026-08-17: this line sent every new session to `docs/VIBE_GAP.md`, which has never existed —
no add, no contents, no deletion, in reachable or unreachable history. The live priority list is
`docs/PRIORITY.md`; the presentation audit behind it is `docs/handoff/VIBE_AUDIT_RESPONSE.md`.)*

## Your role

Game engineer **and director**. Own the vision, make implementation decisions, choose the best option
rather than presenting a menu. Reserve questions for true vision-level forks — what the game is *about*,
not how a thing is built. Work in autonomous sprints: one goal, executed end to end. Judge by **feel**,
holistically, against "Factorio × Terraria with gravity" — not by whether the tests pass.

Each strike should be **3–5 real implementations**, not one tweak. When a strike lands, take the next item
off the backlog and keep going. Do not stop and do not ask permission to begin.

## Three rules that are not negotiable

1. **Commits carry no Claude/Anthropic/co-author trailer, ever.** Author is `teohondascully` only:
   ```
   git add -A && git -c user.name="teohondascully" -c user.email="121736842+teohondascully@users.noreply.github.com" commit -q --no-verify -m "..."
   git log -1 --format='%B' | grep -icE "claude|co-authored|anthropic"   # must print 0
   git push -q origin main
   ```
2. **Never `rm`, `git rm`, or purge anything the user created or curates** without explicit per-item
   confirmation. `history/` (their screenshot archive), `assets/sprites/` (hand-authored art), saves, notes
   — all sacred. To exclude something from the repo use `.gitignore` or `git rm --cached`, never `rm`.
3. **The full harness must be green before you commit**, and a green harness bought by lowering a threshold
   is worse than a red one. Fix the code, not the assertion. `docs/ORCHESTRATOR.md` §5 explains why at
   length, and it matters more than anything else in this project.

## Use parallel agents aggressively — it is the main lever

The previous session ran twelve at once. `docs/ORCHESTRATOR.md` §7 is the playbook, and the short version
is: isolate every code agent in its own git **worktree**, give each a hard file contract naming what it
owns *and* what it must not touch, warn them that concurrent harness runs make the timing layers flaky,
and let **you** do all the committing to main.

Read-only "tech lead" agents are free and safe and were the highest-value thing in the whole session — a
senior-staff repo review found that CI had been red for 33 consecutive pushes plus a live rendering bug in
one pass; a harness audit found six assertions that could not fail; a blind first-time-player agent judging
only screenshots produced the single most important finding of the session.

## Where things stand right now

- **Main is green: 58/58 locally and CI is passing** (it had been red for 33 pushes; that is fixed).
- Working tree is clean. Last commit `10641ac`.
- **Eight agent worktrees hold unmerged work at very different levels of trust.** `git worktree list`.
  `docs/ORCHESTRATOR.md` §12 documents each one precisely — including which self-reported "57/57" you
  should not believe and exactly which layers were never re-run. **Verify before merging; merge one at a
  time with a full harness run after each.**
- **The lode cutover (the main line of work) is committed in a worktree but NOT verified.** Its own handover
  is at `docs/handoff/CUTOVER_HANDOVER.md`.

## Suggested first moves

1. Run `GODOT=/opt/homebrew/bin/godot bash tools/run_harness.sh` and confirm 58/58. Then run it again with
   `SF_HEADLESS=1` — that reproduces CI, and local green does not imply CI green.
2. Take a capture and actually look at it, cropped in. Form your own opinion of the game before trusting
   anyone else's, including mine.
3. Triage the eight worktrees.
4. Then pick from the backlog in §13. My ranking puts **"light the rock so solid reads as different from
   empty"** first — a first-time player could not tell floor from wall and could not navigate — and
   **"pull the camera in"** second. You are the director; re-rank it if you see it differently.
