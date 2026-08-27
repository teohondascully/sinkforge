# Sinkforge — start here

Auto-loaded every session, including after compaction. Its only job is to point at what isn't.

## Every session

1. Read, in order: `CONTEXT.md` → `docs/GDD.md` → `docs/ARCHITECTURE.md` → `docs/QUALITY.md` →
   `docs/CLAIMS.md` → `claims/C003-cold-start-reaches-d1.md` → `docs/WORKING.md`.
2. If this is a fresh session or you just resumed from a compaction: run `/handoff` before touching
   anything.
3. Before reporting to the director: run `/wrap`.

## Commands

- `/handoff` — post-compaction re-orientation. `.claude/commands/handoff.md`.
- `/wrap` — end-of-session checklist (WORKING.md, ledger, BRIEF.md, gates). `.claude/commands/wrap.md`.
- `/audit` — ledger spot-audit. Director-run only, never by the session being audited.
  `.claude/commands/audit.md`.
- `/loop` — a fixed, director-authored queue driven to completion or a hard stop. Only exists when a
  specific run needs it; read `.claude/commands/loop.md` for the current scope, if present.

## Normative docs

`docs/DECISIONS_LEDGER.md` (append-only judgment calls), `docs/BRIEF.md` (this session's digest, with a
"What was learned" section — findings, not a work log), `docs/WORKING.md` (current state), `docs/adr/`
(architecture decisions), `docs/TASTE_QUEUE.md` (feel/visual judgment calls), `history/` (curated
images, capped at 12 — an image earns its place by illustrating a finding, not by marking a date).

## Standing rules

- Never a Claude/Anthropic/co-author commit trailer.
- Every judgment call not dictated by a normative doc gets a ledger entry, in the same commit for
  anything touching `core/` or `sim/` (enforced by `.githooks/commit-msg`; override with a
  `No-Ledger-Entry:` trailer only when there genuinely was no judgment call).
- Verify a numeric claim against actual tool output before writing it into a commit, doc, or report.
- Mutation-test a new guard or gate before trusting it — reaching the check is not the same as the
  check firing.

Full protocol: `CONTEXT.md`.
