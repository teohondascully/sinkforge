# Quality Standard

**Status:** normative. **Last revised:** 2026-08-26. **Replaces:** the A+ Program.

---

## Why this replaces the A+ Program

The prior A+ Program was a good body of standards with one structural flaw: it was a **program with an exit**. All six areas were marked closed, and then work continued, and quality drifted again, because a program that can be completed stops constraining anything the day it completes.

Most of its content was right and is carried forward here, in some cases verbatim in substance. What changes is the shape: **these are continuous gates, not milestones.** There is no closed state. A gate either holds on every commit or it does not exist.

Two things are added that the prior program lacked, and both target the specific failure that produced the previous codebase, where instrumentation grew 90% in five days while the game grew 9%:

- Every harness layer must trace to a claim.
- Instrument LOC may not exceed game LOC.

---

## 1. The gates

The numbered list below is the declared contract. It is not the current status — an external audit found
gates declared here with no enforcing code at all, and this document is exactly the kind of hand-typed
claim that drifts. **Run `python3 tools/gate_status.py` for the real, current answer to "is gate N
enforced right now"**: it enumerates this list programmatically, cross-references it against
`.github/workflows/harness.yml`, and reports NO-CODE, ADVISORY, PASS, or FAIL per gate — never a prose
assertion. `docs/DECISIONS_LEDGER.md` D0143.

Every gate below is intended to be CI-enforced. A PR that fails any gate does not merge. No gate is lowered to make CI green; that rule is itself a gate.

### Structure

1. **Layer lint.** The dependency rules in `docs/ARCHITECTURE.md` §3 hold. Zero violations. Custom check in `tools/layer_lint`.
2. **No engine imports in `core/` or `sim/`.** Grep-level, hard fail.
3. **File size.** No file over 400 lines. Warn at 300.
4. **Function size.** No function over 50 lines. Cyclomatic complexity ≤ 10.
5. **No global singletons.** No autoloads in `sim/`.
6. **`MODULE.md` present and current** in every module directory.
7. **Instrument LOC ≤ game LOC.** `harness/ + experiment/ + tools/ + tests/` may not exceed `core/ + sim/ + interface/ + view/ + shell/`. When the ratio inverts, the next unit of work is game.

### Correctness

8. **Determinism.** `replay_determinism_test` green.
9. **Conservation.** Property test: over 10,000 random ticks with fuzzed commands, total material is conserved modulo declared sinks.
10. **No softlock.** From any reachable state, the player can reach the surface.
11. **Movement acceptance suite** green against the hostile chamber. See `docs/ARCHITECTURE.md` §9.
12. **Save migration.** Every historical save version loads, tested against stored fixtures.
13. **Schema.** Every file in `data/` validates.
14. **Coverage.** ≥ 85% line coverage on `core/` and `sim/`. `view/` and `shell/` exempt; chasing coverage in rendering code is theater.

### Claims

15. **Every harness layer names a claim.** A check that cannot state which claim it serves does not merge. This is the single most important process gate in this document.
16. **Every scenario names a claim.**
17. **No claim regresses.** A change that moves a passing claim to failing fails the build and names the claim.

### Performance

18. **Benchmark scenarios within budget**, with a documented tolerance band for CI noise (15%).
19. **Perf checks refuse to report on an unsuitable host.** A contended machine produces VOID, not PASS and not FAIL.

### Process

20. **ADR required** for any change to: tick phase order, save schema, layer boundaries, the behavior primitive set, the determinism strategy, the four design rules, or the language decision.
21. **Public API documented.** Every symbol in a module interface file has a doc comment stating contract and invariants.
22. **Generated data records are fresh.** Every `data/<kind>/generated.gd` matches what `tools/data_codegen/generate.py` would produce right now from its `data/<kind>/*.yaml` source. `tools/data_codegen/generate.py --check`, `docs/adr/0004-data-codegen.md`. Appended here rather than inserted near gate 13 ("Schema") — several gate scripts cite their own number in their own docstrings, and renumbering would make those citations wrong; gate numbers are addresses, same reason `docs/DECISIONS_LEDGER.md` entries are.
23. **`docs/WORKING.md` is not stale.** Its stated "Last updated" date is not older than `HEAD`'s own commit date. `tools/layer_lint/check_working_freshness.py`. A proxy, not a guarantee — a session can bump the date without saying anything true — but it catches the specific, common failure of commits landing on top of a working-tree summary nobody touched.
24. **The body never leaves the grid.** Its own collision box stays inside the grid's declared `[0,width)x[0,height)` extent every tick, not just along `HostileChamber`'s scripted traversal route. `tests/test_bounds_invariant.gd`, `docs/DECISIONS_LEDGER.md` D0055. Appended here rather than near gate 11 ("Movement acceptance suite") for the same reason gate 22 sits here — gate numbers are addresses.
25. **Movement acceptance covers the chamber's full reachable extent, not only the scripted route.** A real out-of-bounds launch found in play was invisible to gate 11's own scripted-input run because the traversal path and the reachable space are different sets. `tests/test_reachability_sweep.gd`, `docs/DECISIONS_LEDGER.md` D0055.
26. **A goalless input fuzzer runs every commit, at a bounded fast size.** `ScriptedTraverse` proves one known route still works; it cannot find a defect that route never triggers (`docs/DECISIONS_LEDGER.md` D0055-D0059, four of which were exactly this). `tests/test_body_fuzz_fast.gd` (100 seeds x 500 ticks, ~5s) asserts every invariant hard-zero on every push/PR; `tests/test_body_fuzz.gd` (the full 1000x1500 sweep) runs nightly and gates against a named, counted residual (`docs/DECISIONS_LEDGER.md` D0060/D0061) rather than a hard zero the known residual would otherwise make permanently red.
27. **No untracked file exists outside the shipped `.gitignore`.** A local-only exclusion (`.git/info/exclude`, the global excludesfile) is invisible to a fresh clone; anything the project actually depends on staying hidden must be a real, tracked `.gitignore` pattern instead. `tools/layer_lint/check_untracked_files.py`, `docs/DECISIONS_LEDGER.md` D0062/D0063 — found fifteen real document paths, one of them 3,447 lines, hidden this way since before this gate existed.
28. **Every `tests/test_*.gd` suite's own PASS/FAIL verdict is verified against its raw output, not trusted at face value.** GDScript has no try/catch: a runtime error inside any called function (every real `_test_*()` function, since `_initialize()` is always just a flat list of calls to them) logs a `SCRIPT ERROR:` and lets execution continue, invisible to `_check()`/`_finish()`'s own counters — `test_base.gd`'s "ALL PASS" can print and the process can exit 0 over a suite that silently lost part of its own coverage mid-run. `tools/run_gd_test.sh` (D0116) wraps every suite invocation and fails on a `SCRIPT ERROR:` line regardless of exit code; `tools/test_run_gd_test.sh` proves it against a real, permanent, reproducible crash (`tests/fixture_harness_crash_probe.gd`) before any other suite is allowed to trust it. `docs/DECISIONS_LEDGER.md` D0115/D0116 — found by accident, mutation-testing an unrelated guard, not sought deliberately.
29. **A nightly-only fuzzer escape gets its own permanent per-commit regression fixture, not just a wider allowlist.** `docs/DECISIONS_LEDGER.md` D0122/D0123 found a real `discontinuity` defect (a dig-created staircase fragment) inside the full 1000×1500 sweep that the fast per-commit subset's own 100-seed/500-tick window could never reach. `tests/test_body_fuzz_regression_d0122.gd` replays the minimal known-reproducing prefix — seeds 0-497 on one shared `TileGrid`, matching the fuzzer's own accumulation structure — and asserts zero `discontinuity` there specifically, so this exact class is caught on every commit going forward, not only by the nightly job. `docs/DECISIONS_LEDGER.md` D0125.

---

## 2. Harness truth

Carried forward from the prior program largely intact. This body of standards was the best thing in it.

- **Every registered check must visibly fail when its subject is deliberately broken.** Mutation-tested. A check that has never been observed failing is not a check.
- **A check cannot pass merely because it ran without crashing.**
- **Every layer reports how much it actually asserted.** No layer may silently convert "nothing measured" into PASS.
- **PASS, FAIL, SKIP, PARTIAL, VOID have explicit meanings.** Contaminated or invalid evidence is VOID, which is neither success nor failure.
- **A layer may not void itself to escape a red.** Stand-downs require an explicit written reason.
- **Failures are classified**: code defect, instrument defect, environmental issue, or design decision. An unclassified failure is not triaged.
- **Provenance on every result**: raw logs, captures, metrics, seed, commit SHA, worktree identity, host and environment.
- **Layers are protected from self-matching their own source.**
- **Registries and counts are checked for set equality, not matching totals.**
- **Visual checks prove the subject was actually drawn.** A screenshot is not evidence that a thing exists.
- **Collision checks demonstrate both the collision and the non-collision control.**
- **Headless correctness, headed visual checks, performance checks, and agent playtests remain distinct.** They fail for different reasons and must not be merged into one verdict.

**New, and load-bearing:** a check whose subject is scheduled for deletion is retired with its subject, not maintained. A green check for a deleted mechanic is a worse failure than a missing check.

**New, and load-bearing:** where a gate measures a property of the codebase, the gate is itself part of the codebase and is not exempt from its own property. A gate that quietly excludes itself reports green forever regardless of what it's supposed to be watching — worse than no gate, because it looks like coverage. Live example: `check_loc_ratio.py` (`docs/QUALITY.md` gate 7) originally counted only `.gd` files, which made its own several hundred lines of Python instrument code invisible to the ratio it exists to enforce — caught only because it was mutation-tested against its own source directory, not only against fixtures standing in for game code. Every gate's mutation test must include a case where the gate's own file (or its own output directory, its own line count, whatever property it measures) is the thing that trips it.

**New, and load-bearing:** the same discipline applies to playable fixtures (`docs/ARCHITECTURE.md` §6), which are the feel/design equivalent of a scenario. A fixture must be derived — a seed, a config, and where relevant a replayable input log, always reproducible from a run the game actually produced — never hand-authored to represent a state the game cannot reach on its own. A hand-crafted fixture is a mutation test with no mutation: it proves a reviewer's reaction to a scene, not whether the game produces that scene. Treat "is this fixture derived?" as a checkable property the same way "does this check fail when broken?" is.

**New, and load-bearing:** a gate is only as good as its pattern list, and a missing pattern is a gate that reports green on the exact thing it exists to catch. Every gate's coverage is itself subject to review: when a gate passes on code you expected it to flag, the gate is the suspect, not the code. Live example: `tools/layer_lint/no_engine_imports.py` grew its pattern list by accumulation — a class got added the session someone happened to write the line that needed it (`FastNoiseLite`, `RandomNumberGenerator` — `docs/DECISIONS_LEDGER.md` D0023) — which means every category nobody had tripped on yet was a silent gap, not a clean bill of health. Fixed by deriving the scene-tree category directly from Godot's own `ClassDB` (every Node-descended class, walked from the engine's own class list, not from memory) instead of continuing to accumulate one name at a time (D0026). The general rule: an allow/deny list gate needs its coverage audited against the actual universe of things it's supposed to police, on a schedule, not only every time something slips through it.

**New, and load-bearing:** mutation-testing a guard at integration scale is not sufficient. A guard whose trigger condition normal execution rarely reaches will survive being deliberately broken with the full suite still reporting green — the mutation is real, but nothing in the run happens to exercise it. `sim/terrain_gen`'s depth-floor guard and its never-fill-a-carved-cave rule both passed a full-scale generation test with the guard removed, because the condition each one protects against is rare at real generation scale (`docs/DECISIONS_LEDGER.md` D0024). Every safety guard needs a targeted test built to force its condition directly — seed the exact state that should trip it — in addition to whatever integration coverage already exists around it. This is the same failure class as a check that passes because nothing changed (`replay_determinism_test`'s frozen-no-op check, stage 2 of this pivot): both are a green that means "the code ran," not "the thing the code exists to catch was actually exercised."

**New, and load-bearing:** a fixture tuned until the test passes is no longer independent of the code it tests. When a fixture constant is positioned by observing what the controller does — rather than derived from a spec, or measured to establish reachability with real margin — the resulting threshold measures agreement between two things that were fitted to each other, not correctness. Live example: `HostileChamber.JUMP_CORNER_ROW` (`docs/DECISIONS_LEDGER.md` D0055/D0056) was positioned by watching where a specific jump's rising arc happened to be — first the OLD, buggy held-forever jump's ~18-cell apex, then, after that bug was fixed, the corrected tap-jump's ~4-cell apex, re-measured and re-placed the same way. `corner_correction_success_rate` went green against a jump the real controller could never make, and stayed green after being re-tuned to a jump the corrected controller actually makes — the chamber, the policy, and the controller were fitted to each other on both occasions, and the number that resulted measured that fit, not whether corner correction generically works. The test for which method is which: does the constant define geometry the body must physically REACH (a landing distance, a fall-through gap width) — watching real behavior to size it, WITH a stated safety margin above the measured minimum, is the correct method there, since the goal is reachability, not a razor's-edge threshold. Or does the constant ITSELF define the pass/fail boundary a test asserts against, with no margin — an exact placement, a graze, a tangent? That is circular no matter how carefully it's measured, because the measurement and the assertion are drawing on the same run. `docs/DECISIONS_LEDGER.md` D0056 has the constant-by-constant audit this finding produced.

**New, and load-bearing:** a file that meets the size gate only by removing comments is being satisfied,
not served. The line limit exists so a file stays readable within a bounded context; stripping the
explanation to fit the count moves in the opposite direction — the file gets shorter and harder to
understand at the same time. When a WHY-comment has to be cut (not reworded, cut) to land under the
limit, that is the signal to split the file, not to trim it further. Live example: `sim/body/body.gd`
landed at exactly 400 lines across three separate commits in a row (`e755dff`, `2ea7c70`, `c7826cd`,
verified via `git show <sha>:sim/body/body.gd | wc -l`) — each one added real functionality and was
trimmed back to the limit rather than split, and the pattern repeated a fourth time
(`docs/DECISIONS_LEDGER.md` D0059) before the file was finally split into `body.gd` +
`sim/body/vertical_resolve.gd`. The split should have happened at the first trim, not the third.

---

## 3. Reliability

- Transactional, durable saves. Atomic write, temp file plus rename.
- Explicit save versions with a tested migration chain.
- No test fixture may overwrite a real save. Harness runs use isolated save and config directories, verified by a sentinel that hashes the real save before and after every sweep.
- Save restoration is validated, not assumed.
- A corrupt save file never takes down another one — the two-file `run.save`/`meta.save` split this rule was written against is itself an open question again (`docs/ARCHITECTURE.md` §11, `docs/DECISIONS_LEDGER.md` D0076); the isolation property survives regardless of how many files the eventual schema ends up being.

---

## 4. Performance discipline

- Profile before optimizing. Never optimize from comments or intuition.
- Fix confirmed scaling cliffs only.
- Measure before and after on the same workload.
- Thresholds have reproducible semantics and a named host class. Host-specific allowances are explicit, never borrowed from another machine.
- Full-grid scans and per-frame work are identified and budgeted, including cosmetic scanning for audio and HUD.
- Cache invalidation is event-driven and tested.
- Preserve a control path that proves the optimization mattered.

---

## 5. Documentation

- Documentation matches executable behavior. A doc that contradicts the code is a defect in one of them; find out which.
- Every document has a status: normative, archived, or ADR.
- `docs/README.md` lists the normative set. If a document is not in it, it is not normative.
- Superseded documents get a dated header and move to `docs/archive/`. They are not deleted; the code often still reflects them, and an agent reading old code needs to find out why it exists.
- Historical process documents do not pollute the public surface.
- **Do not build automated checks that count things in documents.** The prior repository did this and it is exactly the meta-instrumentation that consumed it. Docs are reviewed by humans.

---

## 6. Repository hygiene

The portfolio surface is part of the product.

- `main` equals `origin/main`. Clean working tree.
- No forgotten worktrees. No unreviewed divergent branches. Every branch declares owner, purpose, base, and expiry.
- Work returns to canonical main before the next slice. No long-lived feature branches.
- **The repository root contains only: `CONTEXT.md`, `README.md`, `ONBOARDING.md`, `LICENSE`, `project.godot`, `.gitignore`, and directories.** Generated captures, scratch scripts, patch files, and working artifacts never land at root. This is not cosmetic; the previous root's working tree had ~96 stray, already-gitignored capture and sidecar files sitting in it, and it was the first thing a reviewer would have seen.
- No tracked ignored files. No absolute local paths in tracked files.
- Tracked media has an intentional rationale, documented. Clone size is documented in `README.md`.
- **Scratch work is untracked and lives in `tools/scratch/`, which is gitignored.** If a scratch script is worth keeping, it becomes a real tool with a claim ID and moves out.

---

## 7. Working rules

- One canonical source of truth. One active implementation lane per subsystem.
- Parallel work only on disjoint files. Agents propose; integration happens at canonical main.
- Preserve failed experiments and rejected alternatives with reasons. `docs/GDD.md` §9 is the design-side version of this and it is not optional.
- Separate evidence from product judgment. A measurement is not a recommendation.
- Human review is required for taste, visual quality, and progression decisions. The instrument informs those; it does not decide them.
- **Do not trust a status document without re-deriving its claims from the repository.** The prior repository had a decision marked LOCKED that was accurate, and a design doc claiming a layer count that did not exist in code. Both were only discoverable by measuring.
- Gameplay changes are evaluated through real runs, not only unit-like checks.

---

## 8. Definition of done

For any task:

- Tests written and passing.
- Invariants hold.
- `MODULE.md` updated if the contract changed.
- Telemetry added if the change affects a measured behavior.
- At least one scenario exercises the new path, and it names a claim.
- No new lint, layer, size, or ratio violations.
- Balance numbers in `data/`, not code.
- If the change touched an ADR-gated area, the ADR exists and is merged first.

---

## 9. What this standard deliberately does not include

Named so they are not reintroduced by good intentions:

- **A completion state.** There is no A+ certification to achieve. There are gates that hold or do not.
- **Doc-count and doc-drift automation.** Reviewed by humans.
- **A visual ticket backlog.** Visual work is driven by legibility claims, not by an enumerated defect list. The prior repository accumulated roughly ninety visual tickets, most of them attached to systems that are now dead.
- **Broad refactor mandates.** Files are split when a measured boundary justifies it, never because a file is large. A large file with documented evidence for why it was not split is acceptable; an unexplained one is not.
