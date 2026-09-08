# Iteration efficiency implementation plan

Status: director approved execution in sequence; no gameplay or test-policy changes.

**Goal:** shorten iteration without confusing cached evidence, blind play, and fresh verification.
**Architecture:** extend the existing Python/Bash tools; keep all runtime changes opt-in.
**Spec:** `docs/BACKLOG.md`, iteration inspection at 41d31df6.
**Constraints:** canonical-tree authorship; preserve concurrent work; no GPU benchmarks alongside seats;
full verification before push; Gmail commit identity; do not expose evaluator state to blind actors.

For agentic workers: execute inline with the executing-plans skill, test-first, one slice at a time.

- [x] 1. `playtest/timing_report.py` and `tools/test_timing_report.py`: read existing batch/session
  artifacts, aggregate seat time separately from interval-union wall time, retain provenance and warnings.
  Test overlapping intervals, missing/malformed rows, duplicates, incomplete runs and build mismatch.
- [x] 2. `tools/run_suites.sh`, `tools/run_local_battery.sh`, `tools/test_runner_contracts.py`:
  reproduce missing-worker/duplicate-suite false-green paths using an isolated fake engine; enforce
  complete result identities; delegate the battery suite list with bounded optional jobs (default one).
  Preserve actual wrapper behavior, failure logs, population and return codes.
- [x] 3. `tools/verification_receipt.py`, `tools/test_verification_receipt.py`, `tools/gate_status.py`:
  opt-in local receipts with source, command, environment, age and tool identity; reject dirty, stale,
  malformed or mismatched evidence. Reused results remain informational alongside fresh CI status.
- [x] 4. Harden battery parser exit handling and use unique gate logs. Test partial parser output and
  simultaneous isolated batteries; retain all failures. Add no shared mutable global cache.
- [x] 5. `playtest/step_tool.py` and `tools/test_step_tool.py`: opt-in stdio tool returning original
  PNG content plus the player-only receipt through existing command.py. Test protocol negotiation,
  payload filtering, image confinement, command failure and missing/invalid captures. No live seats
  used without explicit ownership; synthetic protocol verification is not a live-agent speed claim.

For each slice: observe red tests, implement, observe green, inspect diff and record limitations here.
Final: run focused tool tests, relevant existing runner/gate tests, check docs and source boundaries;
do not claim a full battery or measured speedup unless it actually ran on an appropriate idle host.

## Implementation evidence (2026-09-08)

All five code slices implemented. New tests are in `tools/` for the existing CI discovery glob.
Observed red-to-green: duplicate suite requests, same-basename result collisions, partial suite parser
output, shared gate-log overwrite, receipt/report integration and image response protocol.
Focused tests: timing 1, runner 9, receipts 2, image tool 3; existing gate-status cases 26/26.
Real Godot `test_fixed_point` and `test_items` passed through the updated runner at jobs=2.
S109-114's existing evidence reads with zero warnings: 7,332,142 summed seat ms, 1,912,020 ms observed
interval span/union. This excludes boot/shutdown and does not establish a full feature-cycle split.
No full-suite speedup or live-model latency improvement is claimed. Pilot client adoption and an idle-host
whole-battery concurrency comparison remain the rollout checks. Fresh verification is still the default;
receipts omit documented shell bookkeeping from environment identity and cannot snapshot external state.
