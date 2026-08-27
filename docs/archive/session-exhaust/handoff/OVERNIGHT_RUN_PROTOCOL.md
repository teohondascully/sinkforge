# Overnight Autonomous Run Protocol

This file is the durable operating contract for an unattended Claude Code run. Re-read it after every context compaction, session resume, or process restart, together with `docs/handoff/OVERNIGHT_RUN_STATE.md`.

## Required context ingest

Before selecting work, and again after any context compaction or restart, read these four documents in
order:

1. `docs/PRIORITY.md` — the authoritative product and engineering queue;
2. `docs/A_PLUS_STATUS.md` — what the quality programme actually closed and what remains advisory;
3. `docs/A_PLUS_PROGRAM.md` — the evidence, limits, and exit criteria behind those dispositions;
4. `docs/handoff/OVERNIGHT_RUN_STATE.md` — the live queue, red ledger, blockers, and last receipts.

Use the documents together. Do not let a stale transcript, an old commit message, or a single failing
layer silently replace the current priority and status records.

## Mission

Continue the highest-priority safe, unblocked SINKFORGE work autonomously until the run ends. Do not stop merely because a milestone, checkpoint, review point, or ordinary ambiguity was reached.

## Continuation rules

- Finish the current safe item, record its evidence, then select the next highest-priority unblocked item.
- If an item is genuinely blocked, record the precise blocker, preserve useful artifacts, and immediately move to the next independent item.
- Make ordinary engineering, measurement, sequencing, and documentation decisions autonomously.
- Never repeat an item already completed or re-run an unexplained failure indefinitely.
- Before each major transition, update `docs/handoff/OVERNIGHT_RUN_STATE.md`.

## Evidence rules

- Never lower a threshold, weaken an assertion, convert a failure into a skip, or manufacture a green result.
- A contaminated, partial, incomplete, or unexplained run is not evidence; classify it as `VOID` and retain the log.
- Every new guard needs a positive control, a negative control, and a mutation control where applicable.
- Report configured sweeps precisely: include PASS, FAIL, SKIP, and documented stand-down counts. Do not call a configured sweep fully asserted when rows stood down.
- Use `tools/with_machine.sh` for every engine, capture, profiler, and harness run — **including a bare
  `--check-only` parse-check.** It still boots Godot, so it still needs the lock; the wrapper's own header
  says why ("ANYTHING THAT BOOTS GODOT TAKES THE LOCK"). Confirmed the hard way, 2026-08-24: a subagent
  brief that carved out `--check-only` as lock-exempt caused a real collision with a concurrently running
  full sweep, invisible to `ps`-based checks until it was already happening. No exceptions for "it's fast"
  or "it's read-only" — the lock is about the process existing on the machine, not about what it changes.
- Preserve both green and red receipts when they materially inform a decision.

## Scoped red disposition

A red is not automatically a global stop, and it is never silently ignored. Classify every red before
choosing the next item:

- `P0_SAFETY` — save corruption, data loss, false-green release protection, or destructive integrity
  failure. Blocks all work.
- `P1_TOUCHED_FEATURE` — a player-visible correctness failure in the subsystem currently being changed.
  Blocks that subsystem and its dependents, not unrelated work.
- `P2_ENVIRONMENTAL` — contention, host, renderer, or infrastructure behavior that is not reproducible in
  the valid target domain. Quarantine with evidence, owner, next experiment, and expiry.
- `P3_SUBJECTIVE` — visual, feel, motivation, or design evidence requiring a player-facing decision.
  Blocks only the change it evaluates, not unrelated development.
- `P4_INSTRUMENTATION_DEBT` — a measurement weakness without a current player-facing regression. Backlog
  it; it cannot become a new release blocker by itself.

Maintain a red ledger in the live state/handoff containing the ID, severity, affected subsystem,
reproduction conditions, baseline and latest result, owner, next bounded experiment, expiry/review point,
and blocking scope. A red without an owner, next experiment, or expiry is not properly deferred.

Before a feature or presentation change, record the relevant baseline and acceptance contract. After the
change, rerun the same relevant checks. A feature is not complete if it introduces a new red, worsens a
known red in its affected subsystem, fails its own contract, or lacks required journey/visual evidence.
An unchanged, documented red may remain quarantined while unrelated work proceeds.

## Loop breaker and debt budget

Bound each investigation to two experiments unless it produces a new mechanism, changed player-facing
behavior, narrower hypothesis, valid new population, or priority/disposition decision. If it produces none,
classify it as unresolved with evidence and move on. Do not repeat idle runs for a failure that occurs only
under contention; reproduce once in the valid domain, then quarantine if still unsettled.

Keep the debt bounded: zero unresolved P0 items; no more than two unresolved P1 items; no more than five
quarantined P2/P3 items without director review; and no new harness-expansion item unless attached to a
real player-facing failure or selected visible change. The A+ programme is closed when its evidence says it
is closed; a newly discoverable imperfection does not reopen the entire programme automatically.

## Repository and ownership rules

- Work only in the canonical checkout. Do not create additional worktrees or feature branches.
- Keep one source of truth and keep the tree clean or document intentional uncommitted work.
- Do not edit another agent's owned files without first recording and resolving the ownership conflict.
- Treat `docs/tracelog/` as read-only except where a file's explicit ownership rule permits an update.
- Do not force-push, rewrite history, delete recovery artifacts, delete branches, or change public refs without explicit director authorization. Queue those actions and continue with safe work.
- Do not change gameplay intent, thresholds, or acceptance floors merely to clear a red.

## Current queue discipline

Use the four ingested documents as the planning sources. Prefer the highest-priority item that is both
independent and safe. Once A+ is closed, advance player-facing work whenever it is not genuinely blocked;
do not let harness perfection consume the whole queue. Keep the state file's “next three unblocked items”
current so a resumed session can continue without reconstructing context.

The calibrated agent-journey work is governed by:

- `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`
- `docs/handoff/AGENT_JOURNEY_EVALUATION_ENGINEER_PROMPT.md`

Do not treat an actor failure as a game finding until world validity, driver validity, actor capability, and loop status have been classified.

## Per-item receipt

For every completed item, record in the state file or its linked handoff:

1. Exact files changed.
2. Invariant or behavior preserved.
3. Verification command and result.
4. Positive, negative, and mutation-control results.
5. Remaining risk or limitation.
6. The next selected item.

For every blocked item, record:

1. Precise blocker.
2. Why it cannot be solved safely now.
3. Evidence gathered.
4. Any authorization required.
5. The next independent item selected instead.

## End-of-run behavior

Do not end early because a milestone was reached. Before the process exits or the overnight window ends:

- finish the current safe slice;
- update the state file;
- run the strongest relevant verification available;
- leave the tree clean or clearly document intentional changes;
- write a concise handoff with completed, blocked, skipped, and next items.

The goal is continuous, evidence-backed progress—not waiting at checkpoints and not optimizing the report instead of the product.
