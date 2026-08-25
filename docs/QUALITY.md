# Quality Standard

**Status:** normative. **Last revised:** 2026-08-25. **Replaces:** the A+ Program.

---

## Why this replaces the A+ Program

The prior A+ Program was a good body of standards with one structural flaw: it was a **program with an exit**. All six areas were marked closed, and then work continued, and quality drifted again, because a program that can be completed stops constraining anything the day it completes.

Most of its content was right and is carried forward here, in some cases verbatim in substance. What changes is the shape: **these are continuous gates, not milestones.** There is no closed state. A gate either holds on every commit or it does not exist.

Two things are added that the prior program lacked, and both target the specific failure that produced the previous codebase, where instrumentation grew 90% in five days while the game grew 9%:

- Every harness layer must trace to a claim.
- Instrument LOC may not exceed game LOC.

---

## 1. The gates

Every gate is CI-enforced. A PR that fails any gate does not merge. No gate is lowered to make CI green; that rule is itself a gate.

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

---

## 3. Reliability

- Transactional, durable saves. Atomic write, temp file plus rename.
- Explicit save versions with a tested migration chain.
- No test fixture may overwrite a real save. Harness runs use isolated save and config directories, verified by a sentinel that hashes the real save before and after every sweep.
- Save restoration is validated, not assumed.
- A corrupt run save never takes down the meta save.

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
