# T1.9 / T5.11 — scoping the cheapest real path to one manual pilot

This is the "scoping" step `docs/PRIORITY.md`'s T1.9/T5.11 entry asks for, not the pilot itself and not
new gate-closure infrastructure. **No code changed to produce this.** It is a read-only synthesis across
three existing documents that each answered part of the readiness question at a different time, so the
current, reconciled picture has never been in one place:

- `docs/handoff/BLIND_EVAL_READINESS.md` (2026-08-20, head `c7f3898`) — the original six-gate audit and
  the manual-pilot plan, including gate 5's already-specified out-of-repo procedure.
- `/private/tmp/sinkforge-agent-journey-eval/tools/eval/READINESS_GATES_1_AND_5.md` (2026-08-23, lane A
  worktree) — a stricter re-measurement of gates 1 and 5, with `VERIFIED`/`SOURCE`/`UNVERIFIED` labels.
- `docs/PRIORITY.md`'s "RECONCILED 2026-08-24" block under T1.9/T5.11 — the standing gate table as of
  `HEAD` `39d924e`, and the one that supersedes the other two wherever they disagree.

## The six gates, as of today, ordered by what actually blocks the pilot

| gate | status | who/what closes it | new code needed? |
|---|---|---|---|
| 6 actor boundary | **DONE** | closed in the lane worktree (`player_feed.gd` + `check_actor_boundary.gd`) | no — already shipped |
| 1 safe isolation | NARROWER-THAN-CLAIMED | redirection, not confinement; per-invocation lock | no — see below |
| 5 evidence feed | FAILS (as repo capability) | — | no, if run manually — see below |
| 3 unmanufactured desire | UNMEASURED | needs an actual attempt | no — needs play, not code |
| 2 truthful route | UNMEASURED | needs an actual attempt | no — needs play, not code |
| 4 legible route | NARROWER-THAN-CLAIMED | **T3.1 / P2, peer `c1`'s work, "interior legibility"** | not mine to write |

**The one genuine external blocker left is gate 4, and it is not this session's to close.**
`docs/PRIORITY.md:1759` assigns "P2 interior legibility" to `T3.1 (6a)`, owner `c1` — a different peer
session, confirmed by the director ruling quoted at `docs/PRIORITY.md:1785` ("C1's priority is T3.1
interior legibility, then terrain grammar"). The parenthetical `(6a)` there is that ticket's own internal
sub-label from 2026-08-17, predating this session; it is not a reference to `sinkforge-6a`, this session's
identity — checked directly to rule out a false lead before writing this down. Nothing about gate 4 is
implementable by writing test-harness code; it clears when `c1`'s legibility work does.

**Gates 1 and 5 do not need a harness commit — they need a careful manual run.** Both audits already
concluded the honest close is procedural, not code:

- **Gate 1.** The isolation is real (`user://` genuinely follows `HOME` under `with_machine.sh`, verified
  from artifacts on disk) but it is a *redirect*, not a *sandbox*, and the lock is per-invocation rather
  than session-long. For a single, closely-supervised manual pilot — one operator, one machine, nobody else
  touching the box, `with_machine.sh` for every boot, no `SF_NO_LOCK`/`SF_REAL_HOME` bypass — this is
  sufficient in practice even though it would not pass a written assertion. It fails as a *general repo
  guarantee*, not as a *precondition for one watched run*.
- **Gate 5.** `docs/handoff/BLIND_EVAL_READINESS.md` §5.6 (referenced at its gate-5 section) already
  specifies the zero-code path: OS-level screen recording, an operator-kept input log, and a hand-written
  `git rev-parse` / settings / seed / sentinel header, all in one gitignored bundle directory outside the
  repo's tracked capture paths. This is explicitly *"satisfiable by procedure"*, not by a new tool — kill
  list #8/#12 forbid the tool before two or three manual runs justify it, which is exactly the ordering
  this memo is respecting.

**Gates 2 and 3 are not blocked on anything — they are simply untried.** Nobody has yet: generated a fresh
seed, hidden the objective rail for that one session, and checked by hand whether the research → drill
route is completable through ordinary player verbs with no injected inventory, no pre-dug path, and no
sim-state peek. That is not an engineering task; it is the first five minutes of the pilot itself.

## What this means, concretely

The pilot is not blocked on more harness work. It is blocked on two things outside this session's
authority to close alone:

1. **Gate 4 clearing** — peer `c1`'s T3.1/P2 interior-legibility work reaching its own completion bar.
2. **A human (or a director-designated actor) actually sitting down** for the five-minute blind pilot the
   protocol's own rollout plan calls for first (`docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`
   "Rollout and ownership", step 2) — gates 1/3/5 as scoped above are already cheap enough to satisfy by
   procedure once someone is doing that run, and gate 3 in particular can only be evaluated *during* it
   (hide the rail, then watch what happens), not diagnosed from source beforehand.

**No further gate-closure infrastructure is recommended by this memo.** That is the standing rule
(`docs/PRIORITY.md`'s "Then stop" sentence, and the lane worktree's own "THE ASK, IF A DIRECTOR WANTS GATE
5 CLOSED" costing) and this synthesis does not find a reason to revisit it. If the director wants to
proceed, the next concrete action is either (a) check whether `c1`'s T3.1/P2 has since cleared, or (b)
schedule the five-minute pilot itself with the procedural gate-1/5 workarounds above, accepting that gate 4
may still return `INVALID` for any route that dips into un-cleared interior terrain — which the protocol
already treats as a pre-registered, reportable outcome, not a failure of this scoping.
