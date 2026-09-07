# Project context

Status: current orientation, 2026-09-07.

Sinkforge is a persistent 2D excavation and factory game with reproducible agent playtesting.
The current game includes traversal, mining, machines, transport, water, saves, and presentation.
The surface-rig demand economy remains planned. See [README](README.md) for implemented scope,
[current work](docs/WORKING.md) for execution state, and [the backlog](docs/BACKLOG.md) for task routing.

## Sources of truth

- [GDD](docs/GDD.md): intended design and ruled constraints.
- [Architecture](docs/ARCHITECTURE.md): module boundaries and engineering contracts.
- [Quality](docs/QUALITY.md): verification policy.
- [Contributing](CONTRIBUTING.md): commands and setup.
- [Ledger](docs/DECISIONS_LEDGER.md) and [ADRs](docs/adr/README.md): decisions and rationale.
- [Documentation guide](docs/README.md): status and reference navigation.

The simulation is headless GDScript running in Godot, with explicit ticks and fixed-point body math.
`core/`, `sim/`, and `interface/` hold the computational boundary; `view/` and `shell/` supply
presentation and application IO. The working playtest adapter is in `playtest/`.
Replay evidence must name its build and platform; do not generalize a pinned test to all state.

## Operating rules

Preserve concurrent edits and historical evidence. No gameplay or verification policy changes are
implied by documentation cleanup. Follow the user's scoped task and record unresolved decisions.
The detailed existing operating rules below remain in force; completed implementation instructions
and stale build summaries were removed to [a historical snapshot](docs/archive/cleanup-2026-09-07/CONTEXT.md).

## Context discipline

The primary implementers here are agents with bounded context. These are architectural constraints, not style preferences.

- **The 5-file rule.** Any task must be completable by reading five files totalling 1,500 lines or fewer. If a task needs more, the module boundaries are wrong. Report that rather than working around it.
- **`MODULE.md` in every module**, a 100-line LIMIT enforced by `check_size_limits.py` (gate 3): purpose, public API, invariants, dependencies, consumers, tick phase, and the three things that have bitten people here. Read the `MODULE.md` for dependencies, the implementation only for the module you are editing. The number was 60 and unenforced until 2026-08-30, by which point 10 of the 18 tracked files exceeded it — a rule no instance obeys is a comment, so the director ruled it up to one the tree can meet rather than deleting prose written on purpose (`docs/DECISIONS_LEDGER.md` D0226). Headroom is real but thin: `core/MODULE.md` is 98.
- **One concept per file. Filename equals concept.** No file named `utils`, `helpers`, `common`, or `manager`.
- **No cross-module reach-in.** A module's internals are private. All access goes through its interface file.
- **No global singletons.** No Godot autoloads in `sim/`. State is passed explicitly.
- **No file over 400 lines. No function over 50.** Enforced.

---

## Surviving context compaction

The repository is the memory. A session's in-flight reasoning is not — it lives only in context and
is gone on compaction unless it was written down first. Documents are re-readable; a train of thought
is not.

- **`CLAUDE.md`** is auto-loaded every session and survives compaction by construction. It is a short
  pointer, not content: it names the reading order and sends you to `docs/WORKING.md`.
- **`docs/WORKING.md`** is current state, not a log: current stage, what's done, what's in flight,
  decisions made this session, open questions, discoveries not yet written anywhere durable. Under
  150 lines. Update it as you work, not at the end. When a stage closes, its durable content moves
  to an ADR, a `MODULE.md`, or a claim, and `docs/WORKING.md` resets for the next stage.
- **Write discoveries immediately, not at a natural pause.** The test: if this session ended right
  now, would this be lost? If yes, write it before continuing — an ADR for a decision, a `MODULE.md`
  gotcha for a trap, `docs/WORKING.md` for everything else.
- **After any compaction, re-read `CLAUDE.md` and `docs/WORKING.md` before touching anything**, and
  state in one paragraph what you're doing and why. If that paragraph doesn't match
  `docs/WORKING.md`, stop and say so rather than guessing forward.
- **One stage per session.** End deliberately at a stage boundary with a written handoff rather than
  drifting into a compaction mid-task. If a stage looks too large to fit one session, say so before
  starting it — the same signal as a task needing more than five files.

---

## Review bandwidth

Throughput regularly exceeds review capacity. Gates catch structural drift; they do not catch a design
decision quietly made in the wrong direction inside an otherwise-clean diff. That is what this section
exists to surface.

- **Every judgment call not dictated by a normative doc gets a `docs/DECISIONS_LEDGER.md` entry**,
  written when made, not at session end. Four lines: decided, alternative, why, reverse cost. Test:
  would a competent engineer with these documents have plausibly chosen differently? If yes, log it.
- **Reversibility gates whether to proceed.** CHEAP — proceed by default, log it, the director skims
  and reverts if wrong. EXPENSIVE — stop and wait; do not proceed on an assumption. EXPENSIVE means it
  shapes a public interface, a data schema, the tick order, a save format, or anything the four design
  rules touch — or, the more general test: would this make it a different game? When unsure, EXPENSIVE.
- **`docs/TASTE_QUEUE.md`** holds feel/visual/design judgment calls as playable fixtures (below), never
  mixed with correctness. Batched for review together; does not block unless also EXPENSIVE.
- **`docs/BRIEF.md`** regenerates as the last action before reporting to the director, not at an
  arbitrary session boundary — a brief regenerated mid-session goes stale the moment more decisions land.
  One screen, EXPENSIVE decisions awaiting the director listed first. If it takes more than 90 seconds to
  read, it's too long. Its "What was learned" section is findings, not a work log: what happened, what
  was learned, and pointers into the ledger and commits for detail — write it before the final
  regeneration, in the same terse style as a ledger entry. This absorbed what would otherwise be a
  separate `docs/JOURNAL.md`; folding it in means one fewer document to remember, and because `BRIEF.md`
  is committed every session, the running narrative lives in `git log -p -- docs/BRIEF.md`, not in an
  ever-growing file. Five documents carry the process now — ledger, brief, working state, taste queue,
  history — and if a sixth starts to seem necessary, that is a signal something else should retire.
- **Ledger spot-audits are sampled by the director, never by the session being audited.**
  `tools/spot_audit.py` picks one commit uniformly at random from those made after
  `docs/DECISIONS_LEDGER.md`'s own creation (an earlier version sampled the entire history and drew a
  pre-ledger commit — a null result, not an audit). The reviewer runs it, reads that commit's full diff,
  and checks it against the ledger entries claiming to cover it — a session selecting its own sample
  defeats the point, which is checking whether the session under-reported.
- **Every external audit is run against an explicit, pinned commit hash — never "the repo" or "the
  current state".** Local commits are routinely ahead of `origin/main` (sessions push rarely), so an
  auditor working from a clone or a stale checkout can genuinely be looking at a different tree than the
  one a session most recently reported on, with no signal to either party that this happened. Both the
  brief handed to the auditor and the report it returns must state the hash. Without this, a real
  finding about an old commit and a false contradiction of a current report are indistinguishable from
  the outside — resolving one from first principles (`git log`, `git ls-tree <hash>`, re-running the
  gate the audit cites, at the disputed hash) is possible but should never be necessary.
- **Any multi-item task the director hands a session lands in `docs/WORKING.md` before work starts, not
  only in the chat message that gave it.** Added 2026-08-26 after a numbered "items 1-7" list survived
  entirely in chat, outside the repo, across a chunk of session work — it never reached the session that
  went to act on it, because nothing durable carried it. The fix is mechanical, the same shape as the
  pinned-hash rule above: a list that only lives in a message is one compaction, one session boundary, or
  one summary away from gone, which is exactly the failure this protocol exists to prevent. The session
  receiving the list writes it into `docs/WORKING.md` verbatim (or a faithful summary that preserves
  every item's number and substance) before starting item 1, not after finishing it.
- Markdown and git only. If this starts to look like a subsystem, say so instead of building it.

## Playable fixtures

A scenario is a declarative fixture (seed, rig state, loadout, start depth, goal) whether a bot or a
human drives it. Full detail: `docs/ARCHITECTURE.md` §6, `docs/QUALITY.md` §2.

- Every stage ships at least one playable fixture demonstrating what it changed, in `scenarios/`,
  identical format to the bot ones.
- Fixtures are **derived, never authored** — reproducible from a real run, never hand-crafted to a state
  the game can't actually produce.
- Review unit is before/after on the **same** recorded input, presented blind, revealed after the
  director picks.
- Fixture ownership is the parallelism contract once parallel write work starts: two workers on
  disjoint fixtures cannot collide in a way the gates won't catch. Stronger than disjoint files alone,
  and the condition to meet before parallel write work starts on `sim/` or `view/`.

---
