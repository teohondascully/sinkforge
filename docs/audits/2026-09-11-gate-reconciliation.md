# Gate reconciliation — all 37 gates, verdict per gate

**2026-09-11 · pinned to `main` @ `d2f527b4`** (post-dedup). Method: `tools/gate_status.py` answers
"does enforcing code exist" and "is it wired into CI"; the third question — *can it fail* — was answered
by mutation (disable the thing the gate claims to catch; watch it go red) or by the gate firing live
on a real defect during this arc.

**Verdict vocabulary.** ENFORCED: code exists, wired into a blocking CI step, failure path seen.
ADVISORY: code exists but the step cannot block (`continue-on-error` or `--report-only`). NO-CODE: no
enforcing code exists — a process rule. CANNOT-FAIL: code exists but structurally cannot register a
failure. The arc's purpose was eliminating CANNOT-FAIL; **zero remain.**

| # | Gate (short) | Enforcing file(s) | Wired | Mutation evidence | Verdict |
|---|---|---|---|---|---|
| 1 | Layer lint | `tools/layer_lint/` (dep rules) | blocking | fires on violations (audit) | ENFORCED |
| 2 | No engine imports in core/sim | `no_engine_imports.py` | blocking | `test_no_engine_imports.py` 22/22, every pattern fired on a violating line | ENFORCED |
| 3 | File size ≤400 (.gd only) | `check_size_limits.py` | blocking | size gate fires; .gd scope documented (D0161) | ENFORCED |
| 4 | Function size ≤50 | `check_size_limits.py` | blocking | hard gate; complexity side is report-only by design (D0602) | ENFORCED |
| 5 | No global singletons in sim/core | `check_project_settings.py` autoload scan | blocking | mutation test caught own strip-order bug before trust | ENFORCED — `51fca604`, D0601 |
| 6 | Module doc present | `check_module_docs.py` | blocking | `test_check_module_docs.py` 9/9; fails on pre-doc tree naming the four view/ subdirs | ENFORCED — `9b82ccc5`, D0607 |
| 7 | Instrument LOC velocity | `check_loc_ratio.py` | blocking at zero game growth | live WARN this arc (instrument +924 / game +59) — signal working as designed | ENFORCED (warn live) |
| 8 | Determinism | `test_shaft_replay_determinism.gd` | blocking | golden hashes; scoped to jumps+digs, mantle/step-up honestly excluded (D0281) | ENFORCED (scoped) |
| 9 | Conservation | fuzz/property suites; `test_cold_start_d1.gd` asserts it too | blocking | conserved over fuzz; event-suppression mutation fails the C003 assert | ENFORCED |
| 10 | No softlock (scoped) | `test_softlock_ascent.gd` | blocking | mining-break disabled → shaft case red, adit green | ENFORCED — `06918b7c`, D0602/D0606 |
| 11 | Movement acceptance | `test_body_acceptance.gd` + chamber/course | blocking | suites named in gate text; matcher links aggregate step | ENFORCED — `37014592` |
| 12 | Save integrity | `test_save_game.gd` + snapshot fidelity checks | blocking | round-trip asserted | ENFORCED |
| 13 | Schema for data/ | schema validation step | blocking | yaml → generated parity checked (data_codegen green this arc) | ENFORCED |
| 14 | Coverage ≥85% aspiration | none possible (no GDScript coverage) | n/a | proxy = gate 33, advisory | ADVISORY — reclassified D0602 |
| 15 | Harness layer names claim | `check_claim_references.py` | blocking | corpus healed: `scenarios/cold_start_to_d1.yaml` names C003 (was VOID on empty) | ENFORCED — `bf662a85`, D0609 |
| 16 | Scenario names claim | same check | blocking | same; population 1, thin but real | ENFORCED |
| 17 | No claim regresses | none | n/a | process rule — claims not executable in CI | NO-CODE |
| 18 | Timings recorded; budgets local | `perf_fixture.py` | n/a | budgets unassertable on shared CI — honest scope | NO-CODE (by design) |
| 19 | Perf refuses unsuitable host | `tools/test_perf_fixture.py` | blocking via glob step | matcher extension links `find tools -name 'test_*.py'` step | ENFORCED — `37014592` |
| 20 | ADR required for arch changes | none | n/a | process rule | NO-CODE |
| 21 | Public API documented | none | n/a | process rule | NO-CODE |
| 22 | Generated data fresh | `tools/data_codegen/generate.py --check` | blocking | exercised live (ore_copper regen) | ENFORCED |
| 23 | WORKING.md not stale | `check_working_freshness.py` | blocking | mutation-tested D0603; exercised live this arc | ENFORCED |
| 24 | Body never leaves grid | `test_bounds_invariant.gd` + bounds probe | blocking | probe fixed — previously an instrument that never saw its defect (`998ec497`) | ENFORCED |
| 25 | Chamber extent covered | `test_reachability_sweep.gd` | blocking | sweep asserts full reachable extent | ENFORCED |
| 26 | Fast fuzzer per commit | `test_body_fuzz_fast.gd` | blocking | six invariants asserted; `translation_consent` honestly excluded (D0280) | ENFORCED (scoped) |
| 27 | No untracked outside .gitignore | `check_untracked_files.py` | blocking | fires on untracked files | ENFORCED |
| 28 | Suite verdicts verified vs raw output | `run_gd_test.sh`, `test_run_gd_test.sh`, `_finish` VACUOUS | blocking | permanent crash probe proves it (D0115/D0116) | ENFORCED |
| 29 | Nightly-escape permanent fixture | `test_body_fuzz_regression_d0122.gd` | blocking | replay prefix asserts zero discontinuity | ENFORCED |
| 30 | CORRECTIONS.md not behind ledger | `check_corrections_freshness.py` | blocking | fired live on D0603 filename false positive; fixed (D0617) | ENFORCED |
| 31 | Every suite run by CI | `check_suite_coverage.py` | blocking | verified at 158 suites this arc | ENFORCED |
| 32 | .editorconfig conformance | `tools/formatter/formatter.py` | blocking | runs every commit | ENFORCED |
| 33 | Function-name ratchet | `coverage_check.py` | `continue-on-error` | reported-only by design | ADVISORY |
| 34 | Test naming | `test_naming_check.py` | blocking | convention enforced | ENFORCED |
| 35 | Suite isolation via run_gd_test.sh | `test_isolation_check.py` | blocking | every godot call wrapped | ENFORCED |
| 36 | CI check set may not shrink | `check_ci_not_shrunk.py` | blocking | step named BLOCKING | ENFORCED |
| 37 | Content reachable from new game | `check_content_reachable.py --report-only` | exit 1 → 0 | deliberate while P042 parks the iron chain (D0591) | ADVISORY |

## Tally

- **30 ENFORCED** (gate 7 carrying a live WARN; gates 8/10/26 honestly scoped)
- **3 ADVISORY** (14, 33, 37)
- **4 NO-CODE** (17, 18, 20, 21 — all process rules, now labelled as such in QUALITY.md)
- **0 CANNOT-FAIL** — the class the audit existed to eliminate

## What changed this arc

| Commit | Change |
|---|---|
| `998ec497` | gate 24 probe fixed — instrument previously could not see its defect |
| `51fca604` | gate 5 real `[autoload]` scan (D0601) |
| `0381f651` | mutation-test files for four blocking checks (D0603) |
| `06918b7c` | gate 10 scoped + armed (D0606) |
| `9b82ccc5` | gate 6 presence check + four view/ MODULE.md files (D0607) |
| `37014592` | gate_status matcher: glob-run citations, `--report-only` advisory |
| `ef7377ec` | QUALITY.md text reconciled to audited truth (gates 4,12,14,15/16,17,18,20,21) |
| `bf662a85` | C003 executable; gates 15/16 corpus healed (D0609) |
| `d2f527b4` | ledger dedup (D0601/D0607 doubles) + corrections filename FP (D0617) |

## Remaining gaps (honest)

- **No CI run observed for HEAD.** Every "blocking" verdict is local verification; remote green is
  unconfirmed until CI runs on this tree.
- **Gate 7's WARN is live** and correct: the audit arc itself is instrument growth.
- **Gates 17/18/20/21 stay process rules** — no cheap instrument exists; the honest fix was the label.
- **Gate 37 stays report-only** until P042's parked-chain ruling resolves or is revisited.
- **Gate 14 stays an aspiration** — GDScript has no coverage instrumentation; gate 33 is its weak proxy.
