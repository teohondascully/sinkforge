> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot despite `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 recommending KEEP as-is. The doc set that actually shipped (`docs/README.md`'s normative table) is
> smaller than the plan recommended — a later, real decision, not corrected here. Describes the
> multi-session coordination protocol (director bus, lanes) that ANVIL's own session registry (§8) is
> meant to subsume. Moved here while closing the `.git/info/exclude` hole (ANVIL step 1). Kept for
> provenance. See also `docs/archive/director-bus-plan-2026-08-17.md` and, for why `tools/director_bus.sh`
> itself stays untracked rather than merely archived, `docs/archive/session-exhaust/handoff/CONVERGENCE_LEDGER.md`.

---

# SINKFORGE Director Bus

**Status:** minimal coordination protocol, 2026-08-17.

## Purpose

The director needs to correct or pause active lanes without the project owner copying messages between independent agent sessions. The Director Bus is a small shared mailbox. It is deliberately not a daemon, task tracker, Git hook, or replacement for `docs/tracelog/`.

## Storage and authority

The bus lives at `$(git rev-parse --git-common-dir)/sinkforge-director`. Git worktrees share that directory, so a command remains visible while branches diverge. It is local operational state, not source-controlled project history.

Only the director issues, resolves, or supersedes directives. Agents may acknowledge, dispute, or report completion with evidence. An acknowledgement proves that the directive was seen; it never proves that the requested work occurred and never closes it.

The existing `docs/tracelog/c1.md` and `docs/tracelog/c2.md` remain agent-owned and read-only to the director. Do not put a directive or acknowledgement in either trace.

## Directive contract

Every directive must state all of the following:

- target: `c1`, `c2`, or `all`;
- severity: `INFO`, `WATCH`, `REDIRECT`, `HALT`, or `USER_DECISION`;
- associated `docs/PRIORITY.md` item or the explicit reason it has none;
- verified evidence, distinguished from inference;
- exact requested action and the evidence required to close it;
- authority: an approved user decision, the priority list, or a safety/integrity constraint.

`HALT` and `USER_DECISION` are blocking. An agent must stop the affected lane after seeing one and may continue only once the director resolves or supersedes it. `USER_DECISION` means the director cannot supply the missing product decision either. `REDIRECT` changes the active order but does not erase work; it must name what is now backlogged. `WATCH` and `INFO` are non-blocking.

## Agent protocol

An agent runs the absolute shared tool path supplied in its bootstrap message:

```sh
bash /Users/thondascully/Projects/sinkforge/tools/director_bus.sh poll c1
```

Run it at the start of every turn, before changing lanes, before a full harness run, and before committing or pushing. Replace `c1` with the assigned identity.

When a directive is new, acknowledge it with one of `ACCEPT`, `DISPUTE`, or `DONE`, including evidence:

```sh
printf '%s\n' 'I will add lodes to the fuzz population; the direct single-seed test is insufficient.' \
  | bash /Users/thondascully/Projects/sinkforge/tools/director_bus.sh ack c1 0001 ACCEPT
```

An acknowledgement does not close a directive. Continue reporting reasoning in the owned trace log; use the bus only for the acknowledgement or a dispute. Do not edit another agent's acknowledgement.

## Director protocol

The director uses `issue`, examines `status`, and calls `resolve` only after the requested closing evidence exists. Commands are immutable markdown records; resolution is a separate record. A later command may supersede an earlier one without rewriting it.

The bus is intentionally advisory except for an agent that observes a blocking directive. It has no Git hook and no background service in this first version. If missed directives or repeated drift persist after the protocol is used, add only the smallest measured enforcement needed.

## Command summary

```text
director_bus.sh init
director_bus.sh issue <c1|c2|all> <INFO|WATCH|REDIRECT|HALT|USER_DECISION> <priority> <title>
director_bus.sh poll <c1|c2>
director_bus.sh ack <c1|c2> <id> <ACCEPT|DISPUTE|DONE>
director_bus.sh status
director_bus.sh resolve <id> <reason>
```

`issue` and `ack` read their evidence body from standard input. `poll` exits `3` if a matching unresolved `HALT` or `USER_DECISION` directive exists; otherwise it exits `0`.
