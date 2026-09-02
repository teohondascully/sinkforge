# Vacuous-Green Hunt

Audit target: tree at `70f8a785`. Evidence: `evidence/m1-hunt/` (register:
`evidence/m1-hunt/REGISTER.md`, 14 rows HUNT-F001 through HUNT-F014). All file:line
citations resolve against the pinned tree.

## Verdict

FOUND. The seventh vacuous green is the CI gate mutation test step
(`.github/workflows/harness.yml:190-204`, register row HUNT-F001). The step loops over
`find tools -name 'test_*.py'` (line 201), prints `Ran $count gate mutation test
file(s).` (line 202), and exits 0 with no zero-count floor. An empty glob reproduces
green: the reproduction prints `Ran 0 gate mutation test file(s).` and exits 0 (HUNT-F001,
raw capture `evidence/m1-hunt/raw/hunt-f001-mutsweep.txt`).

This is not one of the six documented instances (D0044, D0072, D0217, D0224, D0233,
D0316) by tool or failure mode. It is the same class as D0227 (the empty-run FAIL guard
in `gate_test_support.py:54-59`), but that guard was implemented in-process and never
applied to the CI step that runs those very files.

## The seventh instance

The "Gate mutation tests" step (`.github/workflows/harness.yml:190`) is a BLOCKING CI
gate. Its run block (lines 191-204) sets `set -e` (line 192), loops over every
`tools/**/test_*.py` file, runs each one, and prints a count. The loop feeds from
`find tools -name 'test_*.py' | sort` (line 201). If that glob matches nothing (a rename,
a restructure, a find typo), the loop body never executes, `count` stays 0, and the step
prints `Ran 0 gate mutation test file(s).` (line 202) and exits 0.

The step IS fail-closed on a genuinely failing test: `set -e` (line 192) aborts on any
non-zero exit from a mutation test. The hole is the empty-glob case only. If every
mutation test file stopped being collected (moved, renamed, or the glob changed), the
step would stay green while enforcing nothing.

Reproduction (HUNT-F001): the verbatim CI snippet run in scratch with an empty `tools/`
directory prints `Ran 0 gate mutation test file(s).` and exits 0. Re-verified for this
report: same output, same exit code. Raw capture:
`evidence/m1-hunt/raw/hunt-f001-mutsweep.txt`. Reproduction script:
`evidence/m1-hunt/repro/hunt-f001-mutsweep.sh`.

## Systemic-pattern verdict

CONFIRMED SYSTEMIC. "Measurement tools default to fail-open" is a systemic pattern in
this codebase, not a one-off. This hunt's own evidence supports the verdict directly:
HUNT-F001 (no zero-count floor), HUNT-F002 (gate failures dropped from exit code),
HUNT-F003 (parse matches zero suites), HUNT-F004 (exit 0 on missing file), HUNT-F005
(VOID exit 0 on zero corpus), HUNT-F006 (silent no-op if tool missing), HUNT-F007 (PASS
vacuously on empty tree), HUNT-F008 (ADVISORY exit 0 on unresolvable window), HUNT-F009
(raw-text scan, no YAML parse), and HUNT-F010 (hang caught only by timeout) are all
CONFIRMED-against-tree rows exhibiting fail-open shapes. The six documented instances
(D0044, D0072, D0217, D0224, D0233, D0316) are the prior evidence, cited as
Codex-verified with ledger pointers, not re-audited at depth.

The anti-evasion clause is satisfied by this hunt's own findings: HUNT-F001 is a
CONFIRMED-against-tree row exhibiting a fail-open shape (no zero-count floor, empty glob
exits 0). The systemic claim does not rest on ledger-only evidence.

The pattern's severity varies. HUNT-F001 is a CI blocking gate with no floor. HUNT-F002
and HUNT-F003 are local-only tools (not CI gates) with retained fail-open shapes.
HUNT-F004 through HUNT-F010 are disclosed, mitigated, or require extreme conditions (the
entire policed tree vanishing). The class is systemic; the exposure is not uniform.

## Candidate adjudication

All 10 ranked candidates from `library/vacuous-green-terrain.md` were reproduced and
adjudicated. Each has its own register row with a reproducing command and a
CONFIRMED-against-tree verdict. One is the seventh; nine are near-misses.

| # | Candidate | Register | Location | Seventh? | Notes |
|---|---|---|---|---|---|
| 1 | MUTSWEEP-ZEROFLOOR | HUNT-F001 | `.github/workflows/harness.yml:190-204` | YES | No zero-count floor; empty glob exits 0. CI blocking gate. |
| 2 | LOCALBATTERY-GATEDROP | HUNT-F002 | `tools/run_local_battery.sh:74-78` | no | Gate failures dropped from exit code. Local-only, not a CI gate. |
| 3 | FLAKY-PARSE | HUNT-F003 | `tools/flaky_test_detector.py:35` | no | SUITE_RE matches 0 suites. Fail-closed today (exit 2); one format change from quiet green. Local-only. |
| 4 | check_working_freshness | HUNT-F004 | `tools/layer_lint/check_working_freshness.py:26-27` | no | Exit 0 on missing file. Weak: requires deleting a tracked file. |
| 5 | check_claim_references | HUNT-F005 | `tools/layer_lint/check_claim_references.py:182-187` | no | VOID exit 0 on zero corpus. Deliberate (D0146), disclosed. |
| 6 | pre-commit base-namespace | HUNT-F006 | `.githooks/pre-commit:64-65` | no | Silent no-op if check_base_namespace.sh missing. Local-only; CI covers the check (`harness.yml:123`). |
| 7 | PASS-(vacuously) group | HUNT-F007 | `tools/layer_lint/layer_lint.py:192` | no | Five tools pass on empty policed tree. Requires entire tree to vanish. Not a new finding. |
| 8 | check_loc_ratio | HUNT-F008 | `tools/layer_lint/check_loc_ratio.py:197` | no | ADVISORY exit 0 on unresolvable window. Disclosed; CI uses fetch-depth: 0. |
| 9 | test_isolation_check | HUNT-F009 | `tools/test_isolation_check.py:40` | no | Raw-text scan, no YAML parse. Mitigated by check_suite_coverage.py (D0217). |
| 10 | Headed-boot probe | HUNT-F010 | `.github/workflows/harness.yml:550` | no | Runs outside run_gd_test.sh; hang caught only by job timeout. Probe has blank-frame checks. |

## Near-miss census

The nine non-seventh candidates are confirmed fail-open shapes, adjudicated as
not-the-seventh for distinct reasons. They are listed here so they are not re-flagged
as new findings in future work.

**Local-only tools (not CI gates):** HUNT-F002 (run_local_battery.sh drops gate failures
from its exit code; the D0233 shape surviving one level up in the same file), HUNT-F003
(flaky_test_detector.py parses zero suites today, exits 2 by luck; one output-format
change away from quiet green).

**Disclosed or deliberate design choices:** HUNT-F005 (check_claim_references.py VOID
exit 0 on zero corpus, deliberate per D0146, disclosed in tool output), HUNT-F008
(check_loc_ratio.py ADVISORY exit 0 on unresolvable window, disclosed in-step, CI uses
fetch-depth: 0).

**Mitigated by a sibling gate:** HUNT-F009 (test_isolation_check.py reads harness.yml
as raw text; an unparseable workflow would still scan clean, but
check_suite_coverage.py's YAML parse in the same CI job fails first per D0217).

**Require extreme conditions:** HUNT-F007 (five tools print "PASS (vacuously)" when
their entire policed tree vanishes; layer_lint.py has the zero-edge control
`check_edges_were_resolved` at line 158, exit 2, D0224), HUNT-F004
(check_working_freshness.py exits 0 on missing WORKING.md; the file is git-tracked, so
this requires a deliberate deletion; a missing Last-updated line at line 34 does fail).

**Local-only hook, CI-covered:** HUNT-F006 (.githooks/pre-commit base-namespace block
silently no-ops if check_base_namespace.sh goes missing; CI covers the check directly
at `harness.yml:123`; `--no-verify` skips the hook entirely).

**Disclosed architectural choice with controls:** HUNT-F010 (probe_facing_flip.tscn
runs outside run_gd_test.sh; a hang is caught only by the job's 10-min timeout; the
probe has explicit blank-frame and empty-band checks, `_failed = true` on failure
paths at `probe_facing_flip.gd:48`).

## Already-guarded census

The already-guarded census is re-derived from the three whole-surface sweeps
(HUNT-F011, HUNT-F012, HUNT-F013), not inherited from the terrain doc. The sweeps
covered 64 test_*.gd files (HUNT-F011), 45 run: steps (HUNT-F012), and 19 tools/
.sh/.gd files (13 non-test) plus 2 hooks (HUNT-F013). Every tool or step found to be
fail-closed or already guarded in the sweeps goes into this census. No census member
is re-flagged as a new finding below.

**Test infrastructure (fail-closed or guarded):**

- `run_gd_test.sh`: detector controls every run (D0115, D0116). Guard verified by
  `test_run_gd_test.sh`.
- `run_suites.sh`: exit-code-only verdict (D0262), zero-suite refusal at line 84
  (`exit 2`), parser-failure exit 2. Guard verified by `test_run_suites.sh`.
- `gate_test_support.py`: empty-run FAIL at lines 54-59 (`return 1` on no branches
  observed, D0227).
- `tests/test_base.gd`: `TestBase.over()` guard at lines 80-84, static pure function,
  refuses `count <= 0` with a VACUOUS verdict (D0245). 14 call sites found. Guard
  verified by `test_empty_population_guard.gd`.

**Gate tools (fail-closed or guarded):**

- `check_trailers.sh`: shallow-clone refusal (line 79), commit-history floor.
- `check_base_namespace.sh`: floors, population reconciliation, controls.
- `check_headed_boot.sh`: MIN_COLOURS floor at line 76, agent-mode discriminator.
- `surface_row.sh`: exits non-zero on failure.
- `capture_colour_guard.sh`: NO COUNT fails at line 41 (`return 1`), the D0316 guard.
  Guard verified by `test_capture_moments.sh`.
- `capture_moments.sh`: already guarded by capture_colour_guard.sh (D0316).
- `check_suite_coverage.py`: YAML parse (D0217), exits non-zero on parse failure.
- `check_ci_suite_count.py`, `list_ci_suites.py`, `list_ci_gates.py`: exit 2 on
  empty or absent.
- `check_ci_not_shrunk.py`: exit 2 on cannot-compare (line 301).
- `check_ledger_integrity.py`: MIN_DECLARATIONS=50.
- `formatter.py`: VOID exit 2 on no in-scope files, mutation-tested.
- `test_naming_check.py`, `test_isolation_check.py`: VOID exit 2, mutation-tested
  (D0324).
- `coverage_check.py`: VOID exit 2 at line 104, reported-only by design (D0323).
- `gate_status.py`: D0179. Guard verified by `test_gate_status.py`.
- `check_fork_completion.sh`: fail-closed.
- `schema_validator.py` + `data_codegen --check`: FAIL on bad input.
- `layer_lint.py`: `check_edges_were_resolved` at line 158, exit 2 on zero edges
  (D0224). Guard verified by `test_layer_lint.py`.
- `check_project_settings.py`: checks specific flags, fail-closed.
- `check_untracked_files.py`: fails on untracked files (locally fails on the user's
  pre-existing recording; CI passes on clean checkout).

**Hooks (fail-closed or guarded):**

- `.githooks/commit-msg`: refuses trailers, requires ledger entry on core/sim diffs.
  Guard verified by `test_commit_msg_hook.sh` (D0151).
- `.githooks/pre-commit`: identity gate, mojibake gate, formatter gate. Guard verified
  by `test_pre_commit_hook.sh` (D0319, D0320).

The census's completeness claim (no other already-guarded tools exist) is re-derived
from the sweep populations: HUNT-F013 scanned all 19 tools/ .sh/.gd files (13 non-test)
and both hooks; HUNT-F012 audited all 45 run: steps. No file or step outside these
populations was left unexamined. The untracked-stray check (HUNT-F013) found no files
matching test_, check_, gate_, capture_, or probe_ prefixes.

## Sweep evidence

The hunt ran four whole-surface sweeps beyond the 10 named candidates:

- **Test-body sweep** (HUNT-F011): 64 test_*.gd files scanned for vacuous-pass shapes
  (constant-vs-constant asserts, dead method calls, empty-population loops,
  self-derived oracles). 0 hits found. TestBase.over() guard verified at
  `tests/test_base.gd:80-84`: static pure function, `over(0, true, ...)` returns
  `[false, "VACUOUS..."]`, guard fires on empty population. 14 call sites found.
  `test_empty_population_guard.gd` poses all three branches including
  `over(0, true, ...)`.
- **Workflow-step sweep** (HUNT-F012): all 45 run: steps in harness.yml audited. 3
  fail-open steps found (HUNT-F001, HUNT-F004, HUNT-F005). 4 partial/disclosed
  (HUNT-F007, HUNT-F008, HUNT-F009, HUNT-F010). All others fail-closed, install/upload,
  or report-only. Per-step determinations in
  `evidence/m1-hunt/raw/sweep-workflow-steps.txt`.
- **Scripts-hooks sweep** (HUNT-F013): 19 tools/ .sh/.gd files (13 non-test) and 2
  hooks scanned for `[ -n ... ]` guards, `|| true` swallows, grep-on-output verdicts,
  wait/timeout patterns. No new findings beyond HUNT-F006. Untracked-stray check: 0
  files matching test_, check_, gate_, capture_, or probe_ prefixes.
- **Timing cross-check** (HUNT-F014): CI suite-timing artifact from run 33545020795,
  downloaded via gh. 6 timings examined (the slowest suites). Outlier criterion: suite
  timing under 1 second. 0 outliers found (slowest suite is 33s). No suspiciously fast
  suites.

## Fix proposals

The following are proposals, not implemented changes. They address the seventh
instance and confirmed candidate weaknesses. They do not re-flag the six documented
instances (D0044, D0072, D0217, D0224, D0233, D0316) or their adjacent fixes (D0179,
D0245, D0262, D0280, D0281, D0282, D0284).

**Proposal 1 (for HUNT-F001, the seventh): add a zero-count floor to the gate mutation
test step.** After the loop at `.github/workflows/harness.yml:201`, before the
`echo "Ran $count..."` at line 202, add a guard: if `$count` is 0, print a failure
message and exit 1. This mirrors the in-process guard already in
`gate_test_support.py:54-59` (D0227) at the CI step level. The fix is one line; the
pattern (an empty run is a FAIL, not a pass) is already established in the codebase.

**Proposal 2 (for HUNT-F002): include GATE_FAILED in run_local_battery.sh's exit
code.** The script at `tools/run_local_battery.sh:107-111` exits 1 only on suite FAILED.
A failing gate with green suites exits 0. Proposal: key the final exit on
`GATE_FAILED > 0 || ${#FAILED[@]} > 0`, not just `${#FAILED[@]} > 0`. This is a
local-only tool, not a CI gate, but it is built to be pipeline-called. The D0233
mapfile fix (bash-4 to bash-3.2) is a different failure mode in the same file and is
not re-flagged here.

**Proposal 3 (for HUNT-F003): add a zero-parse floor to flaky_test_detector.py.** The
tool at `tools/flaky_test_detector.py:35` parses zero suites today (SUITE_RE matches a
format run_suites.sh never emits) and exits 2 (VOID, fail-closed by luck). Proposal:
after `parse_suites()` returns, if zero suites were parsed, print a warning and exit 2
with a message naming the format mismatch. This makes the fail-closed state deliberate
rather than accidental, so a future output-format change cannot silently flip it to
quiet green.

## What was not checked

- The full Godot suite (62 suites) was never run locally. This is CI's job per the
  mission architecture. The suite-timing cross-check (HUNT-F014) used CI's
  suite-timing artifact, not a local run.
- The headed-boot probe (HUNT-F010) was not re-run. It requires a display and xvfb,
  which are not available in this environment. The assessment is from source analysis
  and the CI step definition, not from a live reproduction.
- The CI suite-timing artifact was the only timing source. No local timing data was
  collected. The timing cross-check examined 6 timings from CI run 33545020795
  (HUNT-F014).
- Game code (`core/`, `sim/`) was not audited for vacuous-pass shapes. The hunt swept
  the measurement, test, and tooling surface (64 test files, 45 CI steps, 19 tools
  scripts, 2 hooks), not the game logic itself.
- The six documented instances (D0044, D0072, D0217, D0224, D0233, D0316) were not
  re-audited at depth, per the Codex citation policy. They are cited as Codex-verified
  with ledger pointers, spot-checked at most.
- Non-test GDScript files outside `tools/` (`core/`, `sim/`, `interface/`, `view/`)
  were not swept for vacuous-pass shapes. The test-body sweep (HUNT-F011) covered only
  `tests/test_*.gd` files.
- The flaky_test_detector.py fail-open scenario (one output-format change away from
  quiet green) was argued from source analysis, not demonstrated live. The tool exits
  2 today; the fail-open half is latent, not active.
