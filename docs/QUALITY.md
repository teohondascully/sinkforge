# Quality Standard

**Status:** normative. **Last revised:** 2026-08-26. **Replaces:** the A+ Program.

---

## Why this replaces the A+ Program

The prior A+ Program was a good body of standards with one structural flaw: it was a **program with an exit**. All six areas were marked closed, and then work continued, and quality drifted again, because a program that can be completed stops constraining anything the day it completes.

Most of its content was right and is carried forward here, in some cases verbatim in substance. What changes is the shape: **these are continuous gates, not milestones.** There is no closed state. A gate either holds on every commit or it does not exist.

Two things are added that the prior program lacked, and both target the specific failure that produced the previous codebase, where instrumentation grew 90% in five days while the game grew 9%:

- Every harness layer must trace to a claim.
- Instrument LOC growth may not outpace game LOC growth (a trailing-window velocity check, not an
  absolute-totals gate — gate 7 below states the distinction, added `docs/DECISIONS_LEDGER.md` D0147).

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
3. **File size.** No file over 400 lines. Warn at 300. **`.gd` only — `tools/layer_lint/check_size_limits.py`
   has never scanned Python at any point in its history** (`docs/DECISIONS_LEDGER.md` D0161: found while
   answering a queue item that assumed otherwise). Not extended to `.py` here — doing so is a real
   scope-expansion decision (which Python files start failing a gate that's never gated them, whether test
   code gets a different fence per D0106) deliberately left for a dedicated future item, not decided as a
   side effect of documenting the gap.
4. **Function size.** No function over 50 lines. Cyclomatic complexity ≤ 10.
5. **No global singletons.** No autoloads in `sim/`.
6. **`MODULE.md` present and current** in every module directory.
7. **Instrument LOC growth may not outpace game LOC growth.** A trailing-10-commit velocity check —
   `harness/ + experiment/ + tools/ + tests/`'s net line growth may not exceed 2x `core/ + sim/ + interface/
   + view/ + shell/`'s, once growth clears a floor. `tools/layer_lint/check_loc_ratio.py`. **The ABSOLUTE
   instrument/game ratio is reported alongside this check's own output as a metric, never gated on its
   own** (`docs/DECISIONS_LEDGER.md` D0147, director's ruling on the external audit's item 3) — an
   external audit found this gate's own prose ("Instrument LOC ≤ game LOC... Enforced in CI") describing
   the absolute ratio while the only code that ever existed to enforce it (`check_loc_ratio.py`) has only
   ever gated on the velocity condition above, at any point in its history; the absolute ratio being
   >1 from the first commit of real code onward is not, on its own, evidence of anything this gate exists
   to catch.

   **The velocity condition WARNS; it BLOCKS only when game growth is zero** (D0259, director's ruling).
   Instrument outpacing game is a *pace* signal and stays visible on every run that trips it. Game LOC not
   moving at all is a *direction* signal, and that is the only one that fails the build. The distinction
   was paid for: PR #10 grew instrument +1148 against game +542 and was blocked by a gate whose own remedy
   line reads "the next unit of work is game" -- while the branch it blocked was doing exactly that, and
   the instrument it counted against itself was the measurement that found four generator defects. A gate
   that cannot tell "building the tools the game needs" from "no longer building the game" is measuring
   pace and reporting direction. When the velocity check **fails**, the next unit of work is game; when it
   **warns**, read it and carry on.

### Correctness

8. **Determinism.** `test_shaft_replay_determinism` green -- a real `ShaftGenerator`+`TileGrid`+`Body`
   sim run, replayed bit-identical across two separate OS processes, checked against committed golden
   hashes (`docs/DECISIONS_LEDGER.md` D0165).

   **The verbs this gate covers are JUMPS and DIGS.** Those are the two the suite asserts (`jumps > 0`,
   `digs > 0`), alongside a hard zero on unconsented corner nudges. **Mantle and step-up are NOT covered
   here**, and this line claimed they were until D0281: the suite prints a NOTE for each and asserts
   neither, because both measure zero on CI's own canonical run -- mantle to the platform-float gap
   D0167/D0168 found in `ValueNoise`, and step-up because D0209 established that all 11 step-ups this
   scenario had ever produced were the airborne defect, so asserting it would mean keeping the bug to keep
   the assertion green. Narrowed rather than repaired: a witness for either verb inside THIS scenario would
   have to be platform-independent, and the scenario's world comes from a generator already measured to
   differ between macOS and CI's Linux.

   Their real coverage, each verified green rather than cited from memory (D0281) -- **step-up**:
   `tests/test_step_up_grounding.gd`, `tests/test_floor_source_telemetry.gd`'s
   `_test_auto_step_up_names_try_step`, `tests/test_movement_course.gd`, and `tests/test_body_acceptance.gd`'s
   `step_up_success_rate`. **Mantle**: `tests/test_body_acceptance.gd`'s `_test_reached_the_end`, which is
   load-bearing rather than incidental -- mutation-tested in D0281, holding `mantle_hold` false in
   `ScriptedTraverse` takes that run to `mantles=0, reached_end=false` and the suite to 5 FAILURE(S) --
   over a step `tests/test_hostile_chamber.gd` asserts is exactly `MANTLE_PX` and taller than `STEP_UP_PX`,
   so only a mantle clears it. **No suite asserts a `mantled_this_tick` count directly**; that indirection
   is the shape of the remaining gap, named here so the next reader does not have to rediscover it.

   `test_replay_determinism`'s own stub remains a standing mechanism check for the hash-and-replay
   plumbing itself, not this gate's subject.
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
26. **A goalless input fuzzer runs every commit, at a bounded fast size.** `ScriptedTraverse` proves one known route still works; it cannot find a defect that route never triggers (`docs/DECISIONS_LEDGER.md` D0055-D0059, four of which were exactly this). `tests/test_body_fuzz_fast.gd` (100 seeds x 500 ticks, ~5s) asserts six invariants hard-zero on every push/PR — `embedded`, `grounded_no_floor`, `overflow`, `discontinuity`, `deadlock`, `translation_consent` — but **this gate COVERS only the first five, and `translation_consent` is not one of them** (`docs/DECISIONS_LEDGER.md` D0280). The assertion is real and stays; its green is not evidence. The only mechanism in `sim/body` that can produce an unconsented translation is the ceiling corner nudge, and this fixture fires it **0 times in 50,000 ticks** on the fast window and **0 times in 1,500,000 ticks** on the full nightly sweep — measured, and printed on every run as `corner_corrections=` on the probe's own `FUZZ_SUMMARY` line, so the claim is re-checkable from any run's output rather than trusted from this sentence. Restoring the D0213 defect leaves this suite ALL PASS while `tests/test_corner_consent.gd` goes to 4 FAILURE(S) on the same tree, which is what "asserts it but cannot register it" means here. **The real coverage for that class is `tests/test_corner_consent.gd`**, which builds its own grid from constants and so poses the mechanic identically on every platform; `tests/test_shaft_replay_determinism.gd` asserts it a second time in a world that actually produces corner corrections, platform permitting. **`bounds` and `floor_selection` are counted and printed but NOT gated** (`docs/DECISIONS_LEDGER.md` D0241): under random input the body walks into the world edge constantly and the bounds clamp is the intended recovery, so a hard zero there would assert against the design rather than against a defect. A principled bound for `bounds` is downstream of the fuzz-population work (`docs/NEEDS_DIRECTOR.md` P001/P004). Until then this gate's claim is six asserted of eight counted — and, per D0280 above, five COVERED, which is the number that matters when this gate is cited as evidence; `tests/test_body_fuzz.gd` (the full 1000x1500 sweep) runs nightly and gates against a named, counted residual (`docs/DECISIONS_LEDGER.md` D0060/D0061) rather than a hard zero the known residual would otherwise make permanently red.
27. **No untracked file exists outside the shipped `.gitignore`.** A local-only exclusion (`.git/info/exclude`, the global excludesfile) is invisible to a fresh clone; anything the project actually depends on staying hidden must be a real, tracked `.gitignore` pattern instead. `tools/layer_lint/check_untracked_files.py`, `docs/DECISIONS_LEDGER.md` D0062/D0063 — found fifteen real document paths, one of them 3,447 lines, hidden this way since before this gate existed.
28. **Every `tests/test_*.gd` suite's own PASS/FAIL verdict is verified against its raw output, not trusted at face value.** GDScript has no try/catch: a runtime error inside any called function (every real `_test_*()` function, since `_initialize()` is always just a flat list of calls to them) logs a `SCRIPT ERROR:` and lets execution continue, invisible to `_check()`/`_finish()`'s own counters — `test_base.gd`'s "ALL PASS" can print and the process can exit 0 over a suite that silently lost part of its own coverage mid-run. `tools/run_gd_test.sh` (D0116) wraps every suite invocation and fails on a `SCRIPT ERROR:` line regardless of exit code; `tools/test_run_gd_test.sh` proves it against a real, permanent, reproducible crash (`tests/fixture_harness_crash_probe.gd`) before any other suite is allowed to trust it. `docs/DECISIONS_LEDGER.md` D0115/D0116 — found by accident, mutation-testing an unrelated guard, not sought deliberately.
29. **A nightly-only fuzzer escape gets its own permanent per-commit regression fixture, not just a wider allowlist.** `docs/DECISIONS_LEDGER.md` D0122/D0123 found a real `discontinuity` defect (a dig-created staircase fragment) inside the full 1000×1500 sweep that the fast per-commit subset's own 100-seed/500-tick window could never reach. `tests/test_body_fuzz_regression_d0122.gd` replays the minimal known-reproducing prefix — seeds 0-497 on one shared `TileGrid`, matching the fuzzer's own accumulation structure — and asserts zero `discontinuity` there specifically, so this exact class is caught on every commit going forward, not only by the nightly job. `docs/DECISIONS_LEDGER.md` D0125.
30. **`docs/CORRECTIONS.md` has not fallen behind the ledger's own correction links.** Every `docs/DECISIONS_LEDGER.md` entry whose header matches the correction-keyword pattern D0170 used to first build the page (`corrects`/`correction`/`FALSIFIED`/`was wrong`/`superseding`/similar) has its own D-number appearing somewhere in `docs/CORRECTIONS.md`'s text — a coverage check, not a full regenerate-and-diff like gate 22, since writing the page's own prose (why a claim was wrong, what corrected it, whether a deeper origin exists) stays a judgment call this gate does not attempt to replace. `tools/check_corrections_freshness.py --check`, `docs/DECISIONS_LEDGER.md` D0174/D0175.

31. **Every tracked `tests/test_*.gd` suite is actually run by CI.** A suite that exists, passes locally and appears in no workflow step is the ledger's "gate that runs nowhere" class with the subject being the whole suite: four of them — `test_material_palette` (Slice 0), `test_mining`, `test_reveal_scene_dig_edge` and `test_reveal_spawn_bounds` (Slice 1) — were in exactly that state, including two deliberately mutation-tested bounds controls. Reconciles the tracked population against the workflow's own `res://tests/…` references and reports the MEMBERS of both set differences, because the counts on each side looked healthy throughout (`docs/DECISIONS_LEDGER.md`'s "equal counts, different sets"). `tools/layer_lint/check_suite_coverage.py`, `docs/DECISIONS_LEDGER.md` D0201.

32. **Every `.gd`/`.py`/`.sh`/`.yml`/`.yaml` file matches `.editorconfig`'s declared rules.** `.editorconfig` declared five properties for this tree and nothing checked one of them until this gate. Six rules (charset, trailing-whitespace, file-edges, blank-run, indent, comment-space), two rulesets (string-aware for `.gd`/`.py`, byte-level for `.sh`/`.yml`/`.yaml`), mutation-tested 76/76 and self-including. `tools/formatter/formatter.py`, `docs/DECISIONS_LEDGER.md` D0318. The `indent` rule refuses rather than guesses on ambiguous indentation (mixed tabs and spaces, or a space count not a multiple of 4) — a formatter that reshapes an indentation it cannot read unambiguously is changing program structure on a guess, and the refusal is reported with its line number so a human can fix it by hand.

33. **Function-name coverage for `core/` and `sim/` — ratchet, reported-only.** Gate 14 declares ≥ 85% line coverage but has no enforcing code — GDScript has no coverage instrumentation, and no pure-Python GDScript parser exists to build one. This gate reports a different, weaker metric: a function is "covered" if its name appears as an identifier in at least one `tests/test_*.gd` suite's code (comments and string literals blanked first, so a mention in prose doesn't count). Engine-called functions (`_init`, `_ready`, `_to_string`, etc.) are excluded from the denominator. **Three properties that must be stated wherever this gate is cited:** (1) it measures reference, not execution — a bare identifier, never called, counts as covered, and the gate can be taken to 100% with dead lines; (2) the denominator is keyed by name, not by definition — two functions sharing a name in different files are one unit, and one test reference covers both (156 declarations → 144 denominator); (3) the margin is thin — 60% of 144 needs 87, the ratchet sits at 89 (61.8%), and three new untested functions turns it red. This is reported-only (`continue-on-error: true`), not BLOCKING, because it is a ratchet against neglect, not a coverage guarantee. `tools/coverage_check.py`, `docs/DECISIONS_LEDGER.md` D0322/D0323.

34. **Test naming conventions.** Every `tests/test_*.gd` file must define at least one `func _test_*()` — a test file with no tests is dead weight that CI runs and reports green over. Every `func _test_*()` in the repository must be inside `tests/`. Fixture files (`fixture_*.gd`), diagnostic files (`diag_*.gd`), `test_base.gd`, `property_checks.gd`, and `test_recorded_sessions.gd` (which replays recordings in `_initialize()`, D0282) are exempt from the first rule. `tools/test_naming_check.py`, `docs/DECISIONS_LEDGER.md` D0324.

35. **Test isolation — every `godot` suite invocation goes through `run_gd_test.sh`.** A bare `godot --script res://tests/...` bypasses the `SCRIPT ERROR:` guard that `run_gd_test.sh` provides (D0115/D0116) and loses process-level isolation. This gate checks `harness.yml` for any `godot` command that references a `res://tests/` path without going through `run_gd_test.sh` or `run_suites.sh` (which calls `run_gd_test.sh` internally). `tools/test_isolation_check.py`, `docs/DECISIONS_LEDGER.md` D0324.

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
- **Do not build automated checks that count things in documents.** The prior repository did this and it is exactly the meta-instrumentation that consumed it. Docs are reviewed by humans. **The three exceptions already in CI are named here rather than left to contradict this line** (D0218): gate 23 fails if `WORKING.md` is older than `HEAD`, gate 30 fails if `CORRECTIONS.md` has fallen behind the ledger's correction links, and gates 15-16 parse `claims/*.md` for a reference and a cap. Each checks whether two artifacts AGREE, which a human cannot hold across sessions; none checks whether prose is true, which is the thing that consumed the prior repository. That is the line.

---

30. **The CI check set may not SHRINK without saying so.** A deleted check does not go red — it stops existing, and a run reports green over a smaller set. `docs/DECISIONS_LEDGER.md` D0265: a line-range edit to `harness.yml` deleted the `headed_boot` and `fuzz_nightly` jobs, CI reported **all green**, and the pull request reported `MERGEABLE / CLEAN`; three passing checks are indistinguishable from five passing checks unless something knows how many there should be, and it was caught only by a human noticing a job name had stopped appearing. This is the most dangerous shape in the repository, because every other gate answers "is this property true" while a deleted gate answers nothing at all in the same voice. `tools/layer_lint/check_ci_not_shrunk.py` compares the job set and the suite set of every workflow against the merge base: removal FAILS, addition passes, and a rename FAILS deliberately (indistinguishable from delete-plus-unrelated-add to anything but a human, and the cost of being wrong that way is one line). An intended removal is declared in the **commit message** — `CI-Check-Removed: <name> -- <why>`, one per name — and not in a file, because a file-based allowlist would be edited by the same careless range-replace that deletes the job and would then agree with it. `check_suite_coverage` (a neighbouring property) did NOT catch D0265, because all 43 suites were still named — one of them inside the job that had just been deleted. Two gates, two properties, neither evidence for the other. `docs/DECISIONS_LEDGER.md` D0266.

    Since D0284 it compares more than names, because comparing names only was its own stated hole: **a job that keeps its NAME but is gutted to `run: true` used to pass** — name intact, teeth gone, rollup still green. Each job now also carries an enforcement **fingerprint** that may not shrink: the set of **work tokens** its enforcing steps invoke (every `res://`/`https://` URI, every word ending `.py`/`.sh`/`.gd`/`.bash`/`.yml`/`.yaml`, every `./binary`, and every `uses:` action with its `with:` key names, action version stripped), the **count of enforcing run-steps that do work** (a step holding only comments, blanks, `true`, `:`, `exit`, `set`, `echo` or `printf` is not one), and whether the job has **gained a job-level `if:`**. A step counts as enforcing only if it has no `if:` and no truthy `continue-on-error:` — the third gutting vector, and the one invisible to any text comparison, since flipping a BLOCKING step to `continue-on-error: true` leaves the name, the step and the command all present and removes the enforcement entirely. The count exists because tokens alone cannot see every gutting: the `Gate mutation tests` step's real work is a `find`-driven loop containing no path-shaped token, and the Godot download step's is `curl`/`unzip`/`mv`/`chmod` — reduce either to `run: true` and the token sets are identical. Reordered steps, changed flags, changed positional arguments, a renamed step running the same tool, a split step, a bumped action version and a changed `with:` value all PASS; merging two steps into one fails, on the same policy as a rename and with the same one-line remedy. A deliberate enforcement change is declared in the commit message too — `CI-Enforcement-Changed: <job-name> -- <why>`, job-granular on purpose, because a token-granular marker would be a file-based allowlist wearing a disguise. What it still cannot see: whether the tools it names actually work, or a step rewritten to run a different tool of the same name. Mutation-tested against the real `harness.yml` (11 mutants, each with an `applied=True` witness and a byte-for-byte restore) and committed as `tools/layer_lint/test_check_ci_not_shrunk.py`, 21 branches, including the case where deleting the step that runs this gate is what trips this gate. `docs/DECISIONS_LEDGER.md` D0284.

---

## 6. Repository hygiene

The portfolio surface is part of the product.

- `main` equals `origin/main`. Clean working tree.
- No forgotten worktrees. No unreviewed divergent branches. Every branch declares owner, purpose, base, and expiry.
- Work returns to canonical main before the next slice. No long-lived feature branches.
- **The repository root contains only: `CLAUDE.md`, `CONTEXT.md`, `README.md`, `ONBOARDING.md`, `CONTRIBUTING.md`, `LICENSE`, `project.godot`, `.gitignore`, `.editorconfig`, and directories.** Generated captures, scratch scripts, patch files, and working artifacts never land at root. This is not cosmetic; the previous root's working tree had ~96 stray, already-gitignored capture and sidecar files sitting in it, and it was the first thing a reviewer would have seen. List corrected 2026-08-29 (queue #3 Part M2) — an external audit found three real root files (`CLAUDE.md`, `CONTRIBUTING.md`, `.editorconfig`) this line had never named, none of them stray.
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
