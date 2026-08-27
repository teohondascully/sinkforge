# SINKFORGE audit response

**Prepared:** 2026-08-17

**Purpose:** Independent, read-only response to `docs/handoff/AUDIT_UPDATE.md` and the governing `docs/handoff/COMPREHENSIVE_AUDIT.md`.

**Current source snapshot:** `main` at `0c73c89e5f41ec8f5aca74b24aac359f8100349f`, aligned with `origin/main` when this response was written.

**Audit-update snapshot:** 1,049 lines, SHA-256 `37932b742a0ddfac64b7949db5b4311f509ed1fad83ba535a51fc14c7f93a850`.

**Working-tree caveat:** `tools/check_frametime.gd` was being edited concurrently during review; `tools/run_harness.sh` also became dirty during the final integrity pass. Neither live diff was treated as settled evidence.
**Filename note:** `AUDIT_REPONSE.md` preserves the spelling requested by the user.

> **Continuation notice:** `docs/handoff/AUDIT_UPDATE.md` continued through Strikes 9–15 after the first
> response was stamped. The addendum at the end of this file reviews that complete delta against a second
> source snapshot. Where statuses conflict, the addendum supersedes the earlier response; the earlier text
> remains intact as an audit trail rather than being silently rewritten.

## Scope and method

This was a read-only audit. I changed no product source, test, configuration, worktree, save, capture, or git state. This response is the only file I wrote. I did not run Godot or the harness: the tree was live, the user requested read-only work, and the audit update itself establishes that results from a changing tree are void. Findings below come from direct source review, current diffs, current git state, the audit records, and the three independent design/lore, engineering, and experience reviews commissioned for the comprehensive audit.

CodeRabbit was unavailable locally, so no claim below relies on an external automated reviewer.

Verdict terms:

- **Confirmed:** the claim is supported by current source or reproducible recorded evidence.
- **Partly confirmed:** the direction is right, but the stated guarantee or scope is too broad.
- **Rejected:** current source provides a concrete counterexample.
- **Unproven:** plausible, but the available evidence cannot establish it.
- **Historical:** true of an earlier snapshot but no longer describes current source.

## Executive judgment

The audit-update session did high-value work. Save-path injection, transactional staging, explicit save versioning, seed/phase ownership, three-state harness reporting, headed pixel CI, multi-seed corpus tooling, capture state checks, worktree triage, and documentation repair are all material improvements. The author also corrected several of their own conclusions when better evidence arrived; that is a strength.

The work is not yet an auditable closure of the comprehensive audit. Four guarantees are currently broader than the implementation:

1. **The harness still does not prove that it never touches the player's production save.** Its static scan is non-recursive and syntactically bypassable; its sentinel detects net byte changes only and itself writes the production slot when the slot is absent.
2. **The save writer is not “safe on any failure.”** It ignores backup-copy failure and can replace a valid last-known-good backup with a corrupt primary before promoting a new save.
3. **Captures are not isolated from live input.** `_deafen()` disables callbacks, but `Player` and `MainView` poll `Input` directly during physics/update processing.
4. **The 120 fps result remains unknown.** The committed instrument prints phase numbers before deciding whether they are valid; its driven phases do not prove that running, digging, or swinging actually occurred; and the uncommitted “fastest frame” heuristic is not sufficient evidence that presentation pacing is absent.

The current suite should therefore be reported as:

> **63 layers registered; current main is unverified as a full suite on an immutable tree.** A recorded 62/1 run found a real save-frontier omission, that omission is now statically repaired, and no later clean frozen-tree full run is established here.

Do not call current main green, red, 120 fps, release-safe, or fun-validated. The accurate status is **functionally promising, substantially safer than the audited baseline, and still blocked on evidence integrity and save durability**.

## Release-blocking findings

### P0 — the production-save guard can be defeated, and the sentinel violates its own boundary

`tools/check_save_isolation.gd:56-67` reads only the immediate files in `tools/` and `tests/`; a fixture in a subdirectory is invisible. The scan also recognizes literal spellings such as `MainView.save_path`, `_save_game(`, and `user://sinkforge.save`. A fixture can assemble the path (`"user://" + "sinkforge.save"`), globalize an equivalent path, or use another helper without matching those strings.

`tools/save_sentinel.gd:43-89` hashes before and after. That catches deletion or a net rewrite, but not transient access. A fixture can copy the bytes, overwrite or delete the slot, then restore the original bytes before verification. Both guards pass even though the “may never touch” invariant was violated.

When no save exists, the sentinel writes its marker to the real production slot (`tools/save_sentinel.gd:48-55`). That is not safe merely because the bytes are an invalid envelope. A real game launched concurrently can observe the marker, suppress Continue, report corruption, or race the sentinel's cleanup. The harness lock coordinates harness processes, not the shipped game.

**Disposition:** the original destructive fixture is fixed, but the data-safety veto is only mitigated, not cleared.

**Required shape:** run the complete harness under a temporary, isolated project-data namespace that cannot address the real `user://` slot. Treat the real slot as outside the test sandbox. If a belt-and-braces sentinel remains, the absent case must assert absent-before and absent-after without planting anything. Make source discovery recursive, but do not mistake a better grep for isolation.

### P0 — save backup rotation can discard the last known good generation

`SaveGame.write()` says any failure leaves the existing save unchanged (`src/core/save_game.gd:283-285`), but `DirAccess.copy_absolute(path, path + ".bak")` has a return value and it is ignored (`src/core/save_game.gd:305-309`). Godot documents that `copy_absolute()` returns an `Error`. If the copy fails and the subsequent rename succeeds, the old primary is replaced without a valid backup. That directly contradicts the guarantee.

There is a second recovery defect. `SaveGame.read()` can recover from a valid `.bak` when the primary is corrupt (`src/core/save_game.gd:331-343`). The next save unconditionally copies the existing primary over `.bak` before promotion. That can overwrite the known-good backup with the corrupt primary. The new primary may be valid, but the recovery generation has been poisoned; one later corruption leaves no good fallback.

Closing a `FileAccess` flushes Godot's buffer, but the current implementation does not establish OS-level power-loss durability for the file and containing directory. “Atomic” should be scoped to replacement visibility, not advertised as crash/power-loss durability without platform-specific evidence. Godot's official `DirAccess` documentation confirms overwrite and `Error` semantics for copy/rename; it does not turn an ignored error into a guarantee: <https://docs.godotengine.org/en/stable/classes/class_diraccess.html>.

**Disposition:** transactional restore is largely real; durable last-known-good save rotation is not complete.

**Required shape:** validate which generation is good before rotating; fail promotion when backup preservation is required and copy fails; never overwrite a valid backup with an invalid primary; retain structured generation/checksum metadata; test permission failure, full-disk/short-write simulation, corrupt-primary-plus-good-backup resave, and interruption boundaries on every supported platform.

### P1 — a harness result is not bound to one source tree

The machine/user-data lock in `tools/run_harness.sh:261-335` prevents concurrent harnesses. It does not stop editors, agents, or git operations from changing files between the 63 Godot launches. Pre/post `git status` detects persistent dirt but misses a change that is reverted before the final check. It also cannot prove which source each already-launched process loaded.

The two void runs in Strike 8 are therefore correctly void. Process inspection (`pgrep`) is intrinsically insufficient because the runner has gaps between processes.

**Required shape:** run from a clean, detached, disposable worktree or packaged immutable source snapshot pinned to one commit. Record the commit and a manifest digest in the summary. Refuse a dirty source tree. If a shared checkout must be supported, hash every loadable source/resource before the run and verify it before each launch and at completion; this is still weaker than a snapshot.

### P1 — capture input suppression is not airtight

`capture_moments.gd:97-102` disables `_input`, `_unhandled_input`, and `_unhandled_key_input` delivery. It does not disable polling:

- `scenes/player.gd:239-246` reads `Input.get_axis()` and `Input.is_action_pressed()` while `auto_input` is true.
- `scenes/main.gd:1296-1304` polls the mining action directly.

A real key, controller, or mouse button can therefore move, jump, climb, or mine during a long capture without reopening a modal. `_contamination()` checks modal fields and one callback-processing flag, so it will not detect those changes.

**Disposition:** injected callback contamination is fixed; live-device isolation is rejected.

**Required shape:** add a fixture-owned capture/input mode that disables all live polling, or inject an input adapter and substitute a null/fixture adapter. Set `Player.auto_input = false` where appropriate. Assert semantic moment state immediately before shutter.

### P1 — the performance instrument can label idle work as RUN/DIG/SWING

`tools/check_frametime.gd:217-227` supplies input or calls a verb, but the layer does not assert that the intended work occurred:

- RUN does not require a minimum distance or streamed-chunk revision.
- DIG discards `try_mine()`'s result and does not require successful mines or terrain rebakes.
- SWING does not require an anchored/taut grapple or meaningful arc motion.

A fixture drift can produce green timing ratios for idle or failed phases. This is the same assertion-vacuity class the update asks to find elsewhere.

**Required shape:** each performance phase needs an independent precondition and outcome count: distance moved/chunks crossed, successful mine count plus terrain revision/region bake, and anchored/taut duration plus arc distance. Fail the layer if the workload did not happen.

## Response to every Strike 8 question

### Was the `c7590e5` green valid?

**Rejected.** Source changed during the run, and no prefix can be certified because processes overlapped. The later frozen-tree attempt was also contaminated. The update is correct to retract both.

### Is current main red because of `_ruins_cache`?

**Historical.** The 62 PASS / 1 FAIL result was a genuine failure at that snapshot. Current `tools/check_save_frontier.gd:48` declares `_ruins_cache` as derived, and `src/core/factory_sim.gd:1171` confirms the field is a cache. That static repair is appropriate. It does not establish a current full-suite green.

### Does the tree-freeze protocol close the concurrency problem?

**Partly confirmed.** It catches persistent mutation and is much better than checking processes. It does not catch change-then-revert, cannot freeze the shared index, and does not bind every layer to identical bytes. Use an immutable snapshot, not a social freeze, as the evidence boundary.

The shared-index incident is correctly analyzed: two sessions in the same checkout can complete one another's pending merge even when both stage explicit paths. `.git/MERGE_HEAD` checks and post-commit parent inspection reduce risk, but the durable fix is one writer per checkout/index. Worktrees are appropriate for this; remember that they still share project-named `user://` unless separately configured.

### Does `check_frametime` establish a 120 fps failure?

**Unproven.** The recorded ratio results are valid only as hitch-shape observations if their phases occurred. The absolute milliseconds were declared presentation-pacing-contaminated by the committed detector, so the claimed 62 fps DIG result and the comparison to a historical 19.8 ms number cannot be used.

The current uncommitted edit changes the test to infer “not paced” when the fastest sample beats the refresh interval. One fastest sample is an outlier statistic and is not sufficient proof: scheduling jitter, signal placement, timestamp resolution, compositor behavior, and refresh-rate reporting can all yield a short observed interval. Require a sustained distribution below the panel interval and an independent platform/presentation check, or establish pre-window vsync-off configuration on a controlled host. Do not audit an uncommitted detector as a result.

### Is the “caveated bad number” finding correct?

**Confirmed.** `_report()` prints all phase milliseconds before `_absolute()` decides whether they are meaningful (`check_frametime.gd:120-138`). The invalidity warning arrives after the tempting data. Suppress or clearly replace absolute outputs when the clock is invalid; do not print comparable-looking p50/p95/fps values and then rely on prose to quarantine them.

### Is `SF_PERF_HOST` a real gate?

**Implemented but operationally dormant.** It exists, but repository search finds no committed caller that sets it. A never-enabled optional assertion is not project coverage. A named, controlled host should set it automatically in a documented performance job; otherwise the layer must say it is a portable hitch test, not a 120 fps test.

### Is the worktree triage sound?

**Useful, not dispositive.** Introduced-symbol presence is better than byte identity after rebases and later edits. Its own document correctly calls matches an upper bound because generic names collide. Missing introduced symbols strongly demonstrate missing work; present symbols do not prove semantic landing. The dispositions are reasonable:

- CI branch `ab86dfe`: landed by content.
- Bazaar HUD plate and presentation/audio branches: review individually after rebasing; do not infer mergeability from symbol ratios.
- Rock bedding/lighting: preserve and defer until blind comparative review.
- Lode cutover: hold while gates are red.
- Union assertion branch `a3be74d0`: use instead of the smaller assertion branch, but it is still unreviewed/unmerged work.
- Superseded/inert branches: archive, do not delete.

Every “live” worktree still needs a normal diff review, current-base rebase, focused tests, frozen full suite, and visual/play evidence appropriate to its surface.

## Response to every Strike 7 question

### Does the unreachable-floor disease exist elsewhere?

**Unproven as an exhaustive claim; confirmed as a general risk.** `CONTRAST_FLOOR` was a concrete example of a floor above the old model's structural maximum, accidentally passing on noisy material tone. The repaired model now has a theoretical mass-only maximum of about `1 / (1 - 0.55) = 2.22×` against a 2.0× floor. That is reachable but leaves only about 10% theoretical margin; the perceptual threshold remains provisional until blind review.

A bounded static sweep found no second proof as clean as the old room-contrast contradiction, but it did find adjacent validity failures:

- performance phases without workload proof;
- optional absolute budgets with no committed enabler;
- `FRAMES_PER_STEP_PAR` so loose that the pace signal is effectively off;
- default-seed-only claims and self-derived/clamped values in the assertion-union work.

Do not treat “we did not find another” as a completed sweep of 63 layers. Classify every threshold as:

1. a mathematical invariant, derived from independent production behavior;
2. a measured regression ratchet, with baseline distribution and mutant proof;
3. a perceptual/design target, requiring human evidence.

For each floor, document the structural range, current distribution, intended failure, and a hostile mutation. A floor derived from the same clamped value it checks is not independent.

### Was raising `MASS_SHADE` instead of lowering the floor defensible?

**Partly confirmed.** It repaired the model/floor contradiction without buying green by weakening the test, and the corpus evidence is meaningful. It remains a visual design change justified by a narrow fixture, not by player perception. Keep it provisional until multi-depth, multi-light, blind solid/void/stain classification passes.

### Did the multi-seed corpus close seed monoculture?

**Partly confirmed.** Six layers across eight committed seeds is a good regression corpus and the all-green sweep is useful. Eight seeds do not establish generator quality, tail behavior, replay variety, or a fun distribution. Keep the shipping-seed embodied gate, expand statistical worldgen analysis to more seeds, and use humans to judge whether layouts actually differ.

## Response to every Strike 6 question

### Are other layers vacuous or headless-stubbed?

**Yes; at least one current additional class is confirmed.** `check_frametime` does not prove its named phase workloads occurred. The audit-update already identified several invalid assertions, and the larger `a84c049` worktree adds non-vacuity guards that current main still lacks. For example, current main's `check_wrap.gd` compares wrapped spin against `free_spin` without first asserting that a free arc was measured; the worktree version adds `free_spin > 0.0`.

The static review did not establish an exhaustive 63-layer sweep. The correct closure criterion is not “all scripts read”; it is a per-layer evidence table covering fixture preconditions, independent oracle, headless semantics, mutation result, seed coverage, and skipped sub-assertions.

### Is `SYNC_BAND = 1` sufficient?

**Confirmed for current code by static dependency radius.** `src/core/fine_terrain.gd`'s fine-cell solidity decision reads the parent coarse cell and its eight immediate neighbors; the maximum coarse radius is one. The renderer reads the shared `SYNC_BAND` and adds its paint margin. One ring is therefore sufficient for the present algorithm.

This should still be protected by a systematic property/mutation test over edits at centers, edges, corners, and multi-cell ranges. Static sufficiency becomes stale when the sampling kernel changes.

### Is the 3.0 per-cell ratio the right gate?

**Reasonable as a catastrophic-regression alarm; too loose as a normal performance ratchet.** With measured healthy ratios of 1.19–1.28 and a mutant at 3.385, the gate detects roughly a 2.5× regression and intentionally misses 1.5×. That is honest headroom for smaller dirty regions and a shared fixed upload, but the label should say what it is.

Keep 3.0 if its purpose is “the fast path did not secretly become near-full work.” Add a controlled-host absolute region budget and historical trend if the purpose is “mining performance did not materially regress.” Do not tighten 3.0 from one machine without measuring region-size sensitivity.

The assertion text should also stop saying “no more per cell than a full bake” while permitting three times as much.

### Does the ratio close absolute-cost regression?

**Rejected.** A common per-cell slowdown moves numerator and denominator together. Printing microseconds is observability, not enforcement, and `SF_DIG_BUDGET_MS` is unset everywhere. The approximately 1.7 second full bake and any shared texture-cost increase remain ungated.

### Are one seed and one verb adequate?

**No.** The current dig fixture now covers multiple sites and a multi-cell range, which is good, but it remains one seed and one mutation path. Placement, boring, tree felling, surface shifts, ore/lode transitions, and other dirty-terrain producers need coverage derived from the production mutation frontier.

### Is CI now truthful?

**Substantially improved, not complete.** The runner has PASS/FAIL/SKIP/PASS-with-partial-skip accounting, strict mode, summaries, and durable logs. The pixel job supplies Xvfb plus software Vulkan and runs the four surface-dependent layers strictly. That is a real rendered surface, not a real GPU/performance host; its naming and claims should preserve that distinction. `check_frametime` is deliberately absent from software-rendered CI, so performance remains a local/manual controlled-host gate.

## Response to every Strike 5 question

### Is `_deafen` airtight?

**Rejected.** It closes callback delivery, not `Input` polling. See P1 capture finding above. A real-device contamination attempt is no longer required to prove the hole; current source contains direct polling paths.

### Is `EXPECT` complete?

**No.** It covers modal/UI contamination but not the semantic subject. It does not assert expected zoom, seed, player/body region, objective step, terrain geometry/revision, lode/stain presence, grapple state, visible machine count, or hint/arrival overlays. The manifest prints some values but does not make them gates.

Define a contract per moment. Examples:

- boot: seed/default-profile contract, title state, player spawn region, expected objective, no modal, intended zoom;
- delve: minimum descent, excavated shaft/chamber geometry, player visible/in-region, no modal;
- stain: staged lode exists behind the intended wall, illumination range, player/camera region;
- swing: grapple anchored/taut and body moving through a defined arc;
- Bazaar moments: expected tab/modal plus selected row/item.

### Does boot need a contract?

**Yes.** “Calm” is necessary but insufficient. Boot is the most reused marketing/evaluation moment and must assert what opening state it represents. The contract can be smaller than authored deep fixtures, but it cannot be implicit.

### Is one crop enough to close rock legibility?

**No.** The experience review confirms the problem in multiple current/history frames, which makes it credible, but acceptance still needs randomized depths, lights, seeds, zooms, and blind classification. Keep rock/void and rock/contact-edge as separate problems.

## Response to every Strike 4 question

### Are discrete items the source of truth and rates derived?

**Confirmed with scope correction.** For material production and transport, `_flow()` moves integer buffers and `production_rate()` derives a readout from production counters. The corrected architecture is right for item logistics. Do not generalize this to all simulation: power and water have their own authoritative continuous/network state and rate-like calculations.

### Is the Drift Rig `flow` hook documented accurately?

**Confirmed.** `_BEHAVIORS` maps `"flow"` to `_flow_drift` (`src/core/factory_sim.gd:146`), `_flow()` calls behavior-specific flow when present (`:2521-2528`), and `_flow_drift()` routes pay and spoil separately (`:2416`). The architectural explanation is sound.

### What stale architecture/documentation claims remain?

At least these:

- `docs/ARCHITECTURE.md` overstates save guarantees: backup failure and malformed nested fields are not fully handled.
- “Adding content is data, not code” is true for new declarative instances within existing mechanics, not for new behavior, rendering, save schema, or registry participation.
- `docs/DECISIONS.md:30-39` calls `FactorySim` free of engine dependencies. It is scene-tree/node-free, not engine-independent; it uses Godot types/classes and executes under Godot.
- The decision that `_grow_vein` is the single funnel for every ore body is false. `scenes/world_seeder.gd`, `src/core/heightmap_world_gen.gd`, and non-birth ore transformations in `layered_world_gen.gd` write ore directly.
- The lode decision says no solid ore is generated while current source still generates solid ore in multiple paths. The target may be locked; implementation status is partial.
- “Darkness means walkable space” is an intended visual grammar, not an accomplished fact while solid rock and void still collapse perceptually in dark regions.
- Historical handoffs that state 58/61-layer counts should be labeled snapshots rather than read as current instructions.

README images were correctly deferred while canonical captures were invalid. They should remain deferred until capture semantics and blind visual sign-off are trustworthy, then publish only current, traceable frames.

## Response to every Strike 3 question

### Is `SaveGame.last_invalid` as a static mutable diagnostic sound?

**Tolerable for today's synchronous single-threaded use; not a sound general API.** It does not alter deterministic sim state, but concurrent validations can overwrite one another's diagnostic, and callers cannot associate a reason with a particular result. Return a structured validation result (`ok`, `reason`, staged value) or pass diagnostics through the call. Do not rely on process-global mutable state as the long-term save-validation contract.

### Are there other overlapping guards whose removal is invisible?

**Likely, and not closed.** The invalid-assertion union found several adjacent examples: clamped outputs checked against their clamps, fixture-owned zero counters, ratios without proving both journeys, and baselines that may stay zero. The current main branch does not contain the full larger union. A systematic guard table plus mutations is still required.

### Is the save failure matrix complete?

**No.** It is substantially better, but important cases remain:

- backup-copy failure;
- corrupt primary plus valid backup followed by a new save;
- destination permission/locking failure;
- short write/full disk between encoding and close;
- process kill/power loss at each copy/rename boundary;
- malformed nested machine buffers and numeric ranges;
- NaN/Inf or unreasonable numeric values;
- platform overwrite behavior on supported Windows/macOS/Linux filesystems;
- concurrent save/load attempts;
- backup generation/version compatibility.

`_valid_envelope()` validates top-level presence/types, while `_stage()` converts/defaults many nested fields. Documentation must not claim “every malformed field refuses” until nested schema validation proves it.

### Is transactional restore real?

**Largely confirmed.** The staging/commit split prevents partial live-sim assignment for the fields it stages, and seed/seep/rate reset semantics are explicit. Its guarantee is bounded by the shallow validation above and should be described that way.

## Response to every Strike 2 question

### Is everything in `DECISIONS.md` attested?

**Rejected.** Concrete overclaims include:

- “FactorySim has no engine dependencies” instead of “no scene-tree/node ownership.”
- “Adding content is a data file, not a class” without limiting it to existing content kinds/behaviors.
- “`_grow_vein` is the single funnel every ore body is born through” despite direct ore writes elsewhere.
- “Nothing generates solid ore any more” while current worldgen/seeding still does.

Attestation should identify whether a source proves a current fact, a target decision, or historical intent. A citation to an orchestrator statement does not turn an inaccurate current-code claim into fact.

### Are the statuses right?

**Not consistently.** The environment-as-antagonist direction is marked locked and combat deferred, while `docs/GDD.md` and `docs/PROGRESSION.md` still present boss-gated progression, frontier defense, and a factory-as-weapon siege as active structure. “The Works Are Cold” is correctly marked PROPOSED. Until the user resolves the macro-fiction, combat/cannon/boss commitments should be REOPENED or explicitly superseded in the other docs, not simultaneously treated as active and deferred.

The lode target can be **LOCKED / implementation PARTIAL**. Conflating decision status with shipped status caused the false “nothing generates solid ore” sentence.

### Are there more drifted numbers?

**Almost certainly; no exhaustive numeric-doc sweep is established.** The Seal row/quota repair demonstrates the class. Prefer named constants or generated tables for executable facts. Historical documents should include a commit/snapshot header, and living docs should avoid handwritten counts, positions, timings, and layer indices.

### Are design and lore settled?

**No.** The strongest coherent option remains “The Works Are Cold,” with environmental antagonism and a Seal/Stonereach demo ending, but that is a director decision. Do not silently convert it to canon through implementation or documentation tone.

## Response to every Strike 1 question

### Do the two save guards close the destructive-harness class?

**Rejected.** They close the original literal/direct path and detect net mutation. They do not prevent access, detect transient restore-to-same-bytes behavior, scan recursively, or isolate the namespace. See P0.

A defeating fixture need not be written to prove this; doing so would violate the read-only assignment and unnecessarily touch the most sensitive path. The source-level counterexample is sufficient.

### Is planting a sentinel in an absent production slot safe?

**No.** A safety tool should not create the state it promises tests will never touch. The concurrent-real-game race is enough to reject the design even if harness scripts suppress their own title screens.

## Comprehensive-audit status ledger

| Original audit item | Current status | Senior disposition |
|---|---|---|
| Destructive `check_saveload` path | **Direct defect fixed** | Keep injected path; replace production-slot sentinel with namespace isolation. |
| Atomic save + backup + recovery | **Partial** | Temp/readback/rename exists; backup rotation defects remain P0. |
| Transactional restore/seed/phase | **Substantially done** | Preserve; strengthen nested validation and result diagnostics. |
| Save v2 migration | **Done for current phase change** | Maintain explicit future migration chain and compatibility fixtures. |
| Six invalid assertions | **Partial on main** | Main has version A; larger union has unique fixes and remains unmerged/unverified. |
| Invalid incomplete-run score | **Fixed in current main** | `N/A` is correct; pace term remains effectively disabled by an uncalibrated par. |
| PASS/FAIL/SKIP and CI pixels | **Substantially done** | CI pixel truth improved; performance remains outside representative CI. |
| Canonical captures fail closed | **Partial** | Modal failure closes; live polling and semantic contracts remain. |
| Multi-seed corpus | **Tooling and 8-seed sweep done** | Useful regression set, not generator/fun validation. |
| Architecture/README truth | **Improved, still stale** | Correct remaining overclaims listed above. |
| Worktree triage | **Documented** | Preserve all; use dispositions as routing, not merge proof. |
| 120 fps gate | **Unproven** | Fix workload validity and clock validity on controlled hardware. |
| Full immutable-tree suite | **Not established for current main** | Must precede any green claim. |
| Lode cutover | **Hold** | Completion, pacing, and deep-world contracts remain the gating evidence. |
| First-hour fun | **Unproven** | Requires observed humans; automation cannot certify it. |
| Export/release reproducibility | **Still open** | No evidence here changes the comprehensive audit's release veto. |

## Product, lore, and experience judgment

The comprehensive audit's product judgment remains sound: SINKFORGE is a strong vertical slice with a distinctive embodied gravity-logistics premise, not yet a coherent campaign. The most original systems are the body inside the factory, falling-item logistics, geology-driven routes, lode coverage, and demand-pull automation. The highest risk is adding more campaign content before the first hour is understood.

Current senior score bands remain approximately:

| Dimension | Current band | Why it is capped |
|---|---:|---|
| Novelty | 8/10 | The gravity-factory/geology combination is distinctive. |
| Clarity | 6–7/10 | Strong pitch and objectives; opening still teaches transitional solid-ore semantics. |
| Depth | 6/10 | Good interacting systems, incomplete sustained post-Seal economy. |
| Fun | **Unscored / provisional** | No first-time human cohort; automated completion is not delight. |
| Coherence | 5–6/10 | Competing boss/cannon/restoration macro-games remain in active docs. |
| Pacing | 5/10 | The validated natural arc is short; later tests inject equipment and geometry. |
| Replayability | 4/10 | Seed variation exists; materially different human base stories are unproven. |
| Commercial demo readiness | 5–6/10 | Strong moments, but capture truth, machine physicality, rock semantics, HUD, and ending are not ready. |

The experience audit's major findings also remain valid:

- first-run audio has now been changed on main, so the original “starts muted” defect is historical and should be re-verified rather than repeated as current fact;
- rock/void/stain readability needs blind, randomized evidence;
- machines often read as labeled UI cells rather than installed hardware;
- HUD arbitration, controller defaults, visual accessibility, and binding-copy truth remain product work;
- still frames and automated agents cannot validate movement feel, mix fatigue, or voluntary continuation.

### Lore recommendation

Keep “The Works Are Cold” PROPOSED until the user decides. My recommendation agrees with the comprehensive audit: prefer restoration of an abandoned foundry, environmental antagonism through L3, and a first demo ending at Seal breach plus Stonereach reveal. It aligns the title and mechanics better than committing now to bosses and a weapon siege. But this is a vision fork, not an engineering inference.

## Scoring and evaluation parameters

The layered evaluation model in the comprehensive audit is good and should be retained with one correction: thresholds are **decision targets awaiting calibration**, not evidence that the game is fun.

### Veto layer

Publish no aggregate score when any of these fail:

- data loss, save corruption, crash, or non-transactional authoritative state;
- incomplete required arc;
- invalid/contaminated test or capture evidence;
- conservation/determinism failure;
- trapping without an understandable recovery;
- critical affordance unreadability.

### Addition gate

Score a feature only after vetoes pass:

| Dimension | Range | Senior question |
|---|---:|---|
| Pillar leverage | 0–3 | Does it strengthen embodiment, gravity logistics, or geology? |
| Demand-pull | 0–3 | Did players feel and name the problem before the unlock? |
| Decision depth | 0–3 | Does it create recurring tradeoffs or viable layouts? |
| Column reuse | 0–2 | Does old infrastructure or shallow supply remain relevant? |
| Perceptible payoff | 0–2 | Is the consequence legible and memorable without explanation? |
| Testability | 0–2 | Can correctness and readability fail non-vacuously? |

- 11–15: prioritize after prototype evidence.
- 8–10: prototype narrowly.
- 0–7: decline or redesign.

Keep cost/risk separate from value. A high feature score never overrides a veto.

### Funness evidence

Do not produce a “fun score” from harness metrics. Use 8–12 first-time, observed 60-minute sessions as an initial directional cohort, then expand before making commercial claims. Track:

- voluntary continuation beyond the requested stop;
- unaided memorable moments;
- repeated optional optimization;
- task success and median/P90 time;
- longest dead stretch;
- repeated frustration by incidence, not average alone;
- whether the player can explain gravity flow and choose a next goal;
- layout revisions and self-directed decisions.

The comprehensive audit's proposed percentages are reasonable pilot targets, not statistically stable truths with a cohort of 8–12. Report denominators and individual severe failures. Never average away trapping, motion sickness, a destroyed save, or a critical unreadable gate.

### Automated loop scores

Use automated scores only as regression summaries after completion/precondition gates pass. The current `FRAMES_PER_STEP_PAR` leaves pace effectively inactive; calibrate it from observed play rather than tightening it to make the number look useful. Always publish raw completion, steps reached, time, stalls, guidance gaps, and seeds. `N/A` on incomplete runs is correct.

## Recommended execution order

1. **Establish immutable evidence.** One clean detached snapshot, isolated user-data namespace, no shared index, recorded commit/manifest, no concurrent edits.
2. **Close save safety for real.** Remove production-slot planting, fix backup-copy handling and corrupt-primary rotation, expand failure injection.
3. **Land/review the assertion union.** Preserve unique fixes from both versions; require independent negative tests and a current frozen suite.
4. **Make performance measurable.** Prove phase workloads, validate the clock on named hardware, suppress invalid numbers, add controlled absolute budgets and history.
5. **Finish capture isolation/contracts.** Null live polling, assert semantic subjects, retain manifest and fail-before-write behavior.
6. **Correct living documentation.** Separate locked target, shipped status, proposal, and historical snapshot; fix concrete DECISIONS/ARCHITECTURE overclaims.
7. **Only then resume product work.** Hold the lode cutover until its real arc and world contracts pass; run observed first-hour sessions before expanding campaign scope.
8. **Run the cleanliness sprint as actual cleanup.** Deduplicate the 49 semantic `_check` variants carefully, document layer creation, and decompose god files only behind immutable-suite evidence. Do not let “120 fps audit” displace the cleanup content or let cleanup proceed without a valid performance clock.

## What the original session should not claim

- Do not claim the harness cannot touch the production save.
- Do not claim save failure always preserves the previous good generation.
- Do not claim captures are pure functions of fixtures.
- Do not claim current main is full-suite green.
- Do not claim 120 fps pass or fail from the recorded paced/uncertain numbers.
- Do not claim the 63 layers have been exhaustively proved non-vacuous.
- Do not claim the lode-only world is shipped.
- Do not claim combat/lore is settled.
- Do not infer fun, retention, or commercial readiness from automated completion.
- Do not merge or delete legacy worktrees based only on symbol-presence triage.

## What is safe to claim

- The original `check_saveload` production-path defect has been directly removed.
- Save capture/restore is versioned and substantially more transactional than the audited baseline.
- CI now distinguishes skips and runs surface-dependent pixel checks under Xvfb/software Vulkan.
- The multi-seed corpus exposed and helped repair a real fixture/model contradiction.
- The save-frontier guard caught a real new authoritative-field classification omission.
- Capture tooling now rejects several modal/UI contaminations before overwriting canonical output.
- Current source has meaningful regression infrastructure and an unusually strong culture of recording failed assumptions.
- SINKFORGE's core product premise is differentiated and worth protecting from premature scope expansion.

## Handoff prompt

> Continue SINKFORGE from `/Users/thondascully/Projects/sinkforge`. Read `docs/ORCHESTRATOR.md`, then `docs/handoff/COMPREHENSIVE_AUDIT.md`, `docs/handoff/AUDIT_UPDATE.md`, and `AUDIT_REPONSE.md` end to end. Treat `AUDIT_REPONSE.md` as the independent senior review of the live audit update, stamped to audit-update SHA-256 `37932b742a0ddfac64b7949db5b4311f509ed1fad83ba535a51fc14c7f93a850` and main snapshot `0c73c89e5f41`. Re-check current git status and any newer audit-update delta before acting. Do not trust any prior full-green or 120 fps claim unless it came from one immutable source snapshot with an isolated user-data namespace. First close the production-slot/sentinel and save-backup findings, then review the assertion union and performance/capture validity. Preserve all worktrees and user files; do not lower thresholds to buy green.

# Addendum — independent response to Strikes 9–15

**Prepared:** 2026-08-17

**Second source snapshot:** `main` at `e34da10576d48939b7129ec1dd3dd648da7e6526`, aligned with
`origin/main` and clean when this addendum was prepared.

**Second audit-update snapshot:** 1,795 lines, 22,115 words, SHA-256
`e13bf77a7a15f5bacdb3cc06e97126e54d9e2fe3b731be590b75a89166bf34bc`.

**Review boundary:** This remains a read-only review. I inspected the settled source and git metadata but did
not run Godot or the harness, mutate a save, modify product/test/configuration files, merge or delete a
worktree, or rewrite history. This response file is the only intended edit. Recorded executions in the audit
update are evidence about their named commits and conditions, not an automatic green claim for this later
snapshot.

## Updated executive judgment

Strikes 9–15 materially improve both the product and the quality of its evidence. The audit author accepted
and mutation-tested the two save P0s, made input deafness cover polling, proved the performance workload,
completed the multi-seed corpus, consolidated failure accounting, added progressive terrain painting, closed
the CI registration join, and merged the strongest assertion union. Those are real closures, not cosmetic
ones.

The correct current statement is narrower than the strike-log headline:

> **Current `main` contains 76 registered harness layers and substantially stronger non-vacuity controls,
> but this read-only review does not establish a full-suite result for `e3e0341`. Save generation replacement
> is now defensible. DIG terrain editing is demonstrably the dominant frame-time problem. A universal “holds
> 120 fps except DIG” claim, complete production-save namespace isolation, and the intended plunge payoff
> remain unproved.**

The first response's four principal blockers change as follows:

| Earlier finding | Second-snapshot disposition |
|---|---|
| backup-copy errors and corrupt-primary rotation can spend the last good generation | **Closed in implementation and mutation evidence** by the current `SaveGame.write_file` path |
| capture can still hear live polling | **Closed** by the `Controls` polling boundary and positive control |
| frame workload can pass without doing its named work | **Closed for the audited DIG layer**; the broader “non-run can pass” class remains a required review pattern |
| the harness proves it cannot touch the production save | **Improved, not proved**; recursive/splice-aware scanning and abort disarm reduce risk, but a runtime-computed path remains outside the static guard and the sentinel itself uses the production namespace |

## Strike 9 — instrument validity and the performance result

The strike correctly confirms the first response's most important performance critique. A broken DIG fixture
performed zero successful mines and looked dramatically faster; the repaired layer now requires a fixed
amount of successful work and fails when it cannot produce it. That is the right measurement boundary.
`_stand_over_rock()` also removes a seed/fixture dependency that could otherwise make the phase idle.

The capture-deafness response is also sound. Current gameplay polling is routed through `scenes/controls.gd`,
whose deaf mode covers `Input.get_axis()` and `Input.is_action_pressed()`, and the dedicated layer includes a
positive control. Raw polling remains inside that adapter, where it belongs. This supersedes the first
response's capture-purity blocker.

The pacing detector is improved but still not a general proof of presentation timing. The forced-vsync
mutation correctly disproved the “one fast frame means unpaced” heuristic. Clustering is stronger evidence,
but it is still an empirical classifier tied to a display/driver combination. It should select an
interpretation, not confer validity on arbitrary hardware by itself.

Running timing layers alone within the harness is correct. It removes self-inflicted contention from sibling
Godot processes. It does not make the host hermetic: an unrelated renderer, indexer, thermal event, capture,
or non-cooperating Godot process can still contaminate a run. `tools/with_machine.sh` serializes cooperating
commands; it cannot certify an otherwise quiet machine.

The honest performance conclusion from the recorded data is:

- the DIG workload now demonstrably occurred;
- DIG p95 around 33 ms and roughly 63–68% missed presentation slots is a real, severe hotspot on the named
  measurement setup;
- IDLE, RUN, and SWING are much cheaper than DIG;
- the quality bar for those other phases is not yet settled by a clean, repeated, immutable-snapshot run.

“All four phases fail 120 fps” is withdrawn. “All non-DIG phases are fine” is also too strong.

## Strike 10 — save P0s and the isolation guard

### Save durability verdict

The two concrete P0s are closed in current source. The writer decodes the existing primary before rotating
it, so a corrupt primary cannot replace the last known-good backup. It also checks `copy_absolute` and refuses
promotion when the required backup cannot be preserved. The corresponding mutant/control assertions are the
right kind of evidence because they show both that the defect fails and the repaired path succeeds.

Refusing promotion after a failed backup copy is the right default product decision for a single-slot,
one-backup design. A visible “save failed; previous generation retained” outcome is safer than silently
trading recoverability for freshness. If the product ever offers “save without a backup,” it should be an
explicit exceptional user decision, not an automatic fallback.

The extra full decode on every save is not, by itself, a reason to weaken the invariant. Saves are currently
small and infrequent relative to simulation frames. It should nevertheless be measured with a mature,
near-maximum save: report encode, existing-generation decode, temporary-file readback, copy, and total P50/P95
separately. Revisit architecture only if measured save latency becomes user-visible. A cached “previously
valid” bit must not replace revalidation after an external or partial write.

The file replacement is atomic in the limited and accurate sense that readers should observe an old or new
name after promotion. It is not power-loss durability: there is no demonstrated file or directory `fsync`.
Documentation should keep those terms separate.

### Isolation verdict

The recursive, adjacent-literal-splice-aware scanner is a substantial improvement. It closes the exact
flat-scan and literal-concatenation holes, and deriving helper verbs from `NAMES+=` reduces one source of drift.
It is not a complete sandbox.

Source-visible evasions remain straightforward without being malicious: a path can come from a constant in
another file, a helper return, a format string, character assembly, an environment/config value,
`ProjectSettings.globalize_path`, or an aliased removal function. The audit author correctly admits the
computed-path boundary. The scanner is therefore a useful tripwire, not proof that a layer cannot touch the
slot.

Deriving registration from lines containing `NAMES+=(` has the same character. It recognizes the current
three helper functions, but a multiline/refactored helper, sourced registry, alias, or generated registration
could evade it. The durable design is one declarative registry, or a runner `--list`/JSON manifest, consumed
by execution, CI coverage, and save-isolation checks. Text parsing can remain a secondary mutation-tested
guard.

The per-run marker and EXIT/HUP/TERM disarm correctly reduce abandoned-sentinel litter. They do not create an
isolated namespace, and SIGKILL cannot run cleanup. More importantly, the sentinel intentionally plants in
`user://sinkforge.save` when no save exists. That can detect write-then-delete behavior that a before/after
hash cannot, so the rationale is valid; it still means “the harness never touches production” is false.

My revised severity is precise: the original developer-save destruction P0 is closed; production-namespace
contact remains a **P1 tooling-safety and concurrency risk**, not demonstrated current data loss. The strong
end state remains an isolated Godot user-data directory/project name for every harness run, with the sentinel
testing the isolated slot. Static scanning and sentinel identity should remain defense in depth.

## Strike 11 — multi-seed corpus and arrival semantics

The 5-layer × 8-seed, 40/40 corpus is useful evidence, and the first red cell exposed an instrument contract
rather than a generator failure. That is exactly why a corpus is valuable. It does not prove worldgen outside
those eight seeds or validate human readability, but it materially improves confidence in the covered
properties.

`dig_down_to(..., require_arrival = false)` currently names two distinct operations:

1. make a target cell non-solid; and
2. put the player's body at the target depth.

Defaulting the boolean to false was a reasonable low-blast-radius repair, but it is an unsafe long-term API.
A caller can omit one argument and silently ask the wrong question. Prefer two named methods such as
`excavate_to(cell)` and `descend_to(cell)`, or require an explicit enum/mode at every call with no default.
Migrate based on what each test is actually trying to establish, not by adding `true` mechanically.

Current call-site dispositions:

- `capture_moments.gd` now requires arrival, reads the return value, and records the achieved depth. The
  historical capture concern is closed.
- `check_underground.gd` requires arrival and checks sufficient lit-rock evidence. This is correct.
- `check_pacing.gd` still omits arrival mode and discards the result. Its descent-dependent measurements are
  therefore not trustworthy until it asserts body arrival.
- `check_plunge.gd` reads the return value and its merged union checks shaft rows and actual leg descent, so
  its current outcome checks substantially cover the default's ambiguity. An explicit named arrival operation
  would still make the contract safer.
- resource-acquisition callers may legitimately want “cell became open/resource was obtained” rather than
  body arrival; those should use the excavation operation explicitly.

The 10% dead-space cap should not be tightened merely because seven runs happened to report 0%. Thresholds
need mutation sensitivity and perceptual rationale, not baseline worship. With a small observation set it is
also discrete: one dead tile may be about 8.3% and pass while two fail. Inject controlled dead tiles and
conduct blinded scene comparisons to determine whether one is acceptable. The corrected zero-denominator
behavior, minimum evidence count, and arrival precondition are all necessary non-vacuity guards.

## Strike 12 — shared assertions and the 120 fps headline

Consolidating 54 structurally equivalent layers onto `check_base.gd` is good cleanup because the migration
verified identical assertion counts. Leaving nine genuinely different counting/reporting layers alone is
also correct. Uniformity is not the objective; reliable failure propagation is. Each exceptional layer still
needs independent positive and negative protocol tests. Migrate it only if the base can express its semantics
without losing diagnostics or counting the wrong unit.

Report-only missed-slot rate is the correct temporary state while the host, workload, pacing classifier, and
product SLO are still being calibrated. It is not an acceptable permanent regression gate. Once the setup is
controlled, the project needs a declared performance contract and a mutation that proves the contract fails.

`DROP_AT = 1.5` is defensible only as a classifier for skipped presentation slots on a confirmed
refresh-paced display: a frame near twice the interval missed the next slot. It is not a universal 120 fps
deadline. On an unpaced run, a 10 ms frame is below 12.5 ms and would be counted “not late” even though it is
only 100 fps. Use missed-slot rate for confirmed paced presentation; use actual frame-time distribution on a
controlled unpaced host. Do not blend the two into one verdict.

Current `check_frametime.gd` is internally inconsistent with the corrected headline. It reports missed-slot
rate but still fails named hardware when any phase p95 exceeds 8.33 ms. A phase can therefore have very few
misses and still fail the old p95 rule, while the prose treats missed slots as the honest measure. Decide the
SLO first—for example, a stated percentage of frames delivered within one refresh interval plus a separate
hitch ceiling—then encode exactly that. A literal zero-miss “minimum 120 fps” bar is not a realistic
presentation-quality SLO on a general-purpose desktop.

The audit update's movement conclusion also overreaches its evidence. RUN recorded as much as 13% missed
slots in partly contaminated runs; that is not self-evidently “fine.” The defensible statement is that DIG is
unambiguously dominant and movement appears substantially cheaper, pending repeated quiet runs on one named,
locked, immutable snapshot.

## Strike 13 — progressive fine-terrain bake

Progressive painting is directionally the right trade. It reduces a roughly 1.2-second full initial paint to
the visible opening plus later fill while preserving byte-identical final output. The positive-control
identity test and shared paint function make the correctness argument credible.

It does not yet justify “slower machines take longer instead of dropping frames.” `bake_pending(4000)` times
the row paint loop, then performs `Image.set_data` and texture upload outside that budget. It always paints at
least one whole row, so a slow machine can overshoot by the cost of a row plus upload. Four milliseconds is
already about 48% of an 8.33 ms frame before other simulation/render work.

The renderer's `if`/`elif` ordering currently prevents a full bake, region/dig bake, and pending-fill slice
from being selected in the same `_process` pass. That structural property is good, but it deserves an
observable regression assertion: expose per-frame counters or phase IDs and prove no frame records both a dig
region bake and a pending fill. Also measure the complete frame with fill enabled versus disabled, including
upload, and report time to first presented frame and time to completed fine image.

The fill is row-major and merely skips the initially visible rectangle. A fast camera, teleport/load at depth,
or future camera behavior can reveal unpainted coarse fallback before the sweep arrives. Prefer a queue that
prioritizes the current camera neighborhood, or assert under worst-case travel/load that the camera cannot
reach an unpainted region. The inferred roughly 220 ms opening is a large improvement but still around 26
120 Hz frame budgets and was not directly measured as time-to-first-present. Queue item 17 is **partly
closed**: the catastrophic full-grid front-load is removed; boot presentation and background-fill frame cost
still require direct evidence.

The failed contention detector was appropriately deleted. Internal frame distributions cannot generally
distinguish expensive game work from OS descheduling. Protocol, exclusivity, repeated runs, thermal/host
metadata, and raw samples are the credible controls.

## Strike 14 — CI coverage and commit metadata

Deriving the display job from `SF_GL_ONLY=1`, representing the performance exclusion structurally, and checking
set equality closes the concrete defect where two surface-dependent layers belonged to no CI job. Reverse
coverage matters as much as forward coverage; the new layer checks both.

The implementation is still syntactically coupled to the shell registry. `MIN_LAYERS = 40` is only a weak
parser-non-vacuity floor against a current 76-layer registry; it is not proof of equality with what the runner
will execute. Replace the source parser with a machine-readable runner listing or shared registry, then have
CI compare selected job union/exclusions against that authoritative list. Keep mutation fixtures that add a
new `add`, `add_gl`, and `add_excl` layer and prove the join fails until scheduled.

The display job provides a real display surface through Xvfb/software Vulkan, which is enough for the pixel
checks named here. It is not evidence about a real hardware GPU, compositor latency, or end-user presentation
performance. Documentation and job names should preserve that distinction.

The audit records 23 pushed commits containing the forbidden `Co-Authored-By: Claude Opus 5 (1M context)`
trailer; current all-ref history confirms 23 occurrences. Do **not** rewrite shared pushed history casually.
History rewriting risks both live sessions, worktree branches, and external clones for no product gain. Unless
a legal/compliance requirement explicitly demands removal, grandfather the existing commits and add a
versioned CI check over new commits plus documented local commit-message setup. If removal is mandatory, first
freeze all writers, inventory every affected ref, coordinate force-pushes, and preserve a recovery mapping.

## Strike 15 — worktrees, assertion union, and plunge intent

The new thirteen-worktree table supersedes the first response's symbol-presence routing. The six-assertion
union is now merged, including the larger unique fixes, and the intermediate worktree version is subsumed.
Two branches are upstream, two superseded, the lode cutover remains forbidden, and seven should be re-derived
against current source rather than merged wholesale. None should be deleted merely because it was triaged;
retain them until the user explicitly accepts the disposition and any unique patch has been archived or
re-derived.

The generalized finding is important: a threshold can pass because the run never reached the state whose
quality it purported to score. Completion, evidence count, required state transitions, and semantic arrival
must be vetoes before ratios or quality scores are computed. This should be a review checklist for every
counting/scoring layer, not treated as a one-time fix.

The follow-up correction in `e34da10` is necessary and accepted. The recorded sweep cleared two greppable
forms and enumerated three shared helpers; it did **not** non-vacuity-clear all 74 layers then present, nor the
76 now registered. A suite-wide clearance still requires the per-layer evidence table described earlier in
this response: fixture preconditions, independent oracle, headless semantics, mutation result, seed coverage,
and skipped sub-assertions. The sweep is a useful detector pass over roughly the first column, with an
approximately 85% false-positive rate and four real defects. It is evidence that the method pays, not evidence
that no other shapes exist.

The plunge result is a design failure against the stated intent, even if the current numeric gate passes.
The document says an under-roughly-2× route is scenery; measured alternate-route payoff is about 1.1× while
the floor is 1.0×. Do not lower or quietly reinterpret the prose to buy green, and do not raise the threshold
without tuning evidence. The user must choose between:

- making the plunge materially faster—targeting at least the intended roughly-2× advantage, then validating
  that players notice and voluntarily choose it; or
- revising the design intent after observed players demonstrate that a smaller advantage is still legible,
  useful, and fun.

Until that decision and validation, report the automated layer as **mechanically complete but design-red**.
This is exactly why scoring gates must remain subordinate to product intent.

## Updated priority order

1. **Freeze evidence before the next headline.** Use one pinned source snapshot and manifest, isolated
   user-data directory, exclusive timing protocol, named host, and raw artifacts. A dedicated worktree avoids
   shared source edits but does not isolate Godot `user://` by itself.
2. **Define the presentation SLO, then gate it.** Keep DIG as the first optimization target. Separate paced
   missed-slot rate from unpaced frame-time distribution, include progressive-fill overhead, and mutation-test
   the final metric.
3. **Finish semantic non-vacuity.** Split or require explicit arrival/excavation APIs; fix `check_pacing`; sweep
   all score/ratio layers for “no run still passes.”
4. **Make registries authoritative.** Replace `NAMES+=` source parsing with one runtime/declarative manifest
   consumed by runner, CI coverage, corpus selection, and safety guards.
5. **Harden harness isolation.** Move the entire run into a distinct user-data namespace. Retain recursive
   static scanning and sentinel mutation tests as secondary controls.
6. **Validate progressive presentation.** Measure time to first present, complete per-frame slice cost
   including uploads, mutual exclusion with dig work, and camera outrun behavior.
7. **Resolve the plunge design decision.** Do not let a 1.0 floor certify a mechanic whose own brief calls
   1.1× scenery.
8. **Preserve worktrees and history.** Re-derive the seven viable branches selectively; keep the lode cutover
   forbidden; prevent new prohibited trailers without rewriting published history absent an explicit mandate.

## Updated claims discipline

Safe to claim:

- the two identified save-generation P0s are repaired and mutation-tested;
- capture deafness now covers callback and polling paths through the current controls boundary;
- the DIG performance fixture proves successful work and shows terrain editing is the dominant measured
  hotspot;
- the 40-run seed corpus and merged assertion union found and closed genuine vacuity/fixture defects;
- progressive fine-terrain painting preserves final bytes and materially reduces full-grid boot front-load;
- every currently registered surface-dependent layer is structurally assigned to the display CI selection;
- current source has 76 registered harness layers.

Not safe to claim:

- `e3e0341` is full-suite green from this read-only response;
- the harness cannot touch `user://sinkforge.save` or is a hermetic save sandbox;
- the game universally holds 120 fps outside DIG;
- RUN and SWING quality are settled by contaminated or semantically mixed runs;
- progressive fill cannot drop a frame or be outrun by the camera;
- a 1.1× plunge satisfies the documented route-payoff intent;
- CI's Xvfb/software surface validates real-GPU performance;
- all future registration refactors are covered by parsing `NAMES+=`;
- the legacy worktrees are safe to delete.

## Replacement handoff prompt

> Continue SINKFORGE from `/Users/thondascully/Projects/sinkforge`. Before acting, read
> `docs/ORCHESTRATOR.md`, `docs/handoff/NEW_SESSION_PROMPT.md`, `docs/handoff/COMPREHENSIVE_AUDIT.md`,
> `docs/handoff/AUDIT_UPDATE.md`, and `AUDIT_REPONSE.md` end to end. The independent response now has two
> snapshots; its Strikes 9–15 addendum supersedes earlier statuses. It was stamped to audit-update SHA-256
> `e13bf77a7a15f5bacdb3cc06e97126e54d9e2fe3b731be590b75a89166bf34bc` and main
> `e34da10576d48939b7129ec1dd3dd648da7e6526`. Recompute both hashes and review any newer delta before making
> claims. Preserve all worktrees and do not rewrite pushed history. Treat save backup/corrupt-primary P0s and
> capture polling as closed; treat production user-data isolation, the performance SLO, `check_pacing` arrival,
> progressive-fill full-frame cost, and the 1.1× plunge/design mismatch as open. Do not claim current full-suite
> green or 120 fps without an immutable pinned source snapshot, isolated `user://`, an exclusive named host,
> raw artifacts, and a metric whose paced/unpaced semantics are explicit. Do not lower a threshold to buy
> green, merge the forbidden lode cutover, or delete any legacy worktree without the user's explicit decision.
