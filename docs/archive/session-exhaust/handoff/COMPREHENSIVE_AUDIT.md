# SINKFORGE comprehensive audit handoff

**Audit completed:** 2026-08-17  
**Audited main:** `1d18edfe261faefae3d32eb16368e476db021ecc`  
**Purpose:** Return an evidence-backed, whole-project audit to the original SINKFORGE session before more implementation or worktree integration.

> **PARTLY SUPERSEDED — read `docs/handoff/AUDIT_UPDATE.md` alongside this.** The save-safety veto below
> has since been CLEARED: `check_saveload.gd` is isolated, two guards enforce it, and the full harness is
> now safe to run (and has been, green but for a true positive that is also fixed). Every other veto,
> finding, and recommendation in this document still stands unchanged. The update also lists three agents
> in flight whose work is unreviewed.

## Read this first: the old first move is unsafe

This document supersedes the instruction in `docs/handoff/NEW_SESSION_PROMPT.md` and `docs/ORCHESTRATOR.md` to run the full local harness immediately.

**Do not run `tools/run_harness.sh` locally until `check_saveload.gd` is isolated from the production save slot.**

The advertised harness can overwrite and then delete the developer's real save:

- Production uses `user://sinkforge.save` (`scenes/main.gd:21`).
- `tools/check_saveload.gd:43` calls the real `_save_game()`.
- `tools/check_saveload.gd:74` deletes `MainView.SAVE_PATH`.
- `tools/run_harness.sh:6-8` incorrectly promises that every layer writes only a unique `user://` file.

During this audit, the full main harness was run before this defect was discovered. It reported 58/58, then its save/load layer removed:

`/Users/thondascully/Library/Application Support/Godot/app_userdata/Sinkforge/sinkforge.save`

No save exists there now. It is not possible to determine whether a pre-existing player save was present before the run. If one was present, the harness overwrote and deleted it. No second `SF_HEADLESS=1` run was performed after discovery.

## Executive verdict

SINKFORGE has a real and marketable core: an embodied miner building a gravity-fed factory through geology. “Explore freely; produce vertically” is distinctive, systemic, and trailer-readable. The best current surface and underground moments already look like a real game.

It is nevertheless a strong prototype/vertical slice, not yet a coherent or release-safe campaign. The code proves the opening embodied loop and parts of L2/L3. The documents promise a roughly 40-hour game, but the sustained economy, fully differentiated layers, canonical ending, combat model, replay structure, and win condition are mostly proposals.

The immediate risk is not lack of content. It is false confidence:

1. The full local harness can destroy a real save.
2. The sole production save is non-atomic and has no recovery path.
3. Several harness assertions are vacuous or cannot exercise the behavior they claim.
4. CI calls itself full while four render/performance checks pass by skipping.
5. The lode cutover can report 98.6/100 while its opening arc is incomplete and its process exits 1.
6. Automated play proves possibility and friction, not delight, comprehension, fatigue, or an enjoyable hour.

The correct production order is therefore:

> **Make testing and saves safe → repair evaluation truth → complete the lode cutover → validate the first hour with humans → polish one complete demo arc → only then expand the campaign.**

No aggregate “project score” is reported because data-integrity and completion vetoes currently fail. A high average must never hide a destructive test, incomplete core loop, or invalid evidence.

## Audit provenance and limits

Three parallel read-only audits covered:

- Game design, progression, lore, demand-pull, fun, and commercial promise.
- Engineering architecture, correctness, performance, test validity, CI, saves, and contributor readiness.
- Visual readability, art coherence, UI, movement foundations, feedback, audio, accessibility, onboarding, and screenshot appeal.

The orchestrator independently:

- Read the full orchestration and handoff documentation.
- Inspected current main, CI, captures, and all eight worktrees.
- Ran the full main harness once: **58/58 in 155 seconds**. This result is technically green but safety-contaminated by the save defect.
- Ran targeted checks in the lode cutover worktree.
- Inspected current boot, stain, and delve captures.

Important limits:

- There is no observed first-time-player cohort, retention cohort, store-page test, or sales evidence.
- Still images cannot validate controller feel, motion comfort, or the audio mix.
- Worktree self-reports are not treated as shipped evidence.
- CodeRabbit's CLI was unavailable, so review was performed by the local engineering audit rather than CodeRabbit.

## Baseline truth

### Current main

- Branch: `main`, aligned with `origin/main` at `1d18edf`.
- CI: latest main run is green.
- Local functional harness: 58/58, 155 seconds.
- Focused `tests/test_sim.gd`: pass.
- Focused `tests/test_worldgen.gd`: pass.
- Working tree audit artifacts: `_crop_boot.png` and `_crop_stain.png` are untracked. They are review crops, not product assets.

The green state does **not** establish release readiness because the harness itself is destructive, several assertions are invalid, and CI skips headed checks.

### Lode cutover worktree `0d9655d`

Fresh targeted results:

| Check | Result | Meaning |
|---|---|---|
| `tests/test_sim.gd` | Pass | Focused sim unit behavior is green. |
| `check_loop_health.gd` | Exit 1 | `completed=false`; nevertheless printed **98.6/100**. The scalar is invalid for an incomplete arc. |
| `check_pacing.gd` | Exit 1 | Opening incomplete; 38% quiet share against 20%; density 19.6 against 24. Downstream cadence is partly contaminated by the incomplete opening. |
| `play_tests.gd` | Exit 1 | Rungs 1–5 pass; Rungs 6–7 fail because 15 generated pockets contain no qualifying deep-aquifer/rich-low-rim pocket. |

The cutover is not a merge candidate. Do not lower selectors or thresholds merely to make it green. Fix the game/worldgen contract and the scoring model.

### CI parity

The workflow advertises the full harness, but opening, underground, water-readability, and frametime layers require GL. On the Linux CI path they invoke headless behavior and exit successfully as skipped. Skip is counted as pass.

The “120 fps” test is also relative-only: it compares busy p95 to quiet median but never asserts an 8.33 ms absolute frame time. The ratio is useful; the name and claim are not.

## Hard veto gate status

These gates are evaluated before any score or merge recommendation.

| Gate | Current status | Evidence / consequence |
|---|---|---|
| Player-data safety | **FAIL** | Harness can overwrite/delete the production save. |
| Save durability and recovery | **FAIL** | One slot; direct non-atomic write; no checksum, backup, or recovery. |
| Core sim focused tests | PASS | Current main sim/worldgen suites pass. |
| Full local harness safety | **FAIL** | Functional result green, execution unsafe. |
| Cutover opening completion | **FAIL** | `completed=false`. |
| Cutover pacing/world contract | **FAIL** | Pacing and deep-pocket play checks red. |
| CI render/performance coverage | **UNPROVEN** | Four headed layers skip as pass. |
| Canonical capture validity | **FAIL** | Delve capture contains Bazaar and pause rather than gameplay. |
| First-hour human enjoyment | **UNPROVEN** | No cohort exists. |
| Export/release reproducibility | **FAIL** | No committed export presets or release workflow. |

Rule: if any safety, crash, completion, conservation, save, navigation, or evidence-validity veto fails, publish **no aggregate score**. Raw diagnostics may still be shown.

## Product truth: shipped versus proposed

### Shipped on current main

- Embodied digging and building.
- Physical falling items and vertical machine chains.
- Grapple/winch traversal, sinkholes/rifts, seams, and five mining-bit verbs.
- Power, water, pumps, Drift Rig, spoil, crusher, and packed versus loose fill.
- Named strata, a 64-ingot Seal, L2 iron chain, aquifer pockets, and 11 research rungs.
- Hand-worked lodes, Drill Head, Spur, buried stain, and one authored starter lode pocket.
- Guided objectives through the Seal.

### Proposed, not shipped as a coherent campaign

- A canonical reason to descend.
- A real victory/end state.
- Combat, bosses, health/damage, and frontier defense.
- Magma, Hollow/gravity fluctuation, Sinkforge Core, chassis modules, home descent, and offline progression.
- Ignition siege/cannon ending.
- A unified lode-only generated world.

The current fiction has three competing macro-games: conquest/boss progression, factory-as-weapon/cannon, and restoration of an abandoned cold foundry. These imply different mechanics, tone, enemy model, and ending.

## Product scorecard

A 10 means validated commercial-demo quality in the named dimension. Scores are provisional and cannot override veto failures.

| Dimension | Score | Highest-leverage improvement |
|---|---:|---|
| Clarity | 7 | Rewrite the opening around the enduring lode loop rather than the disposable solid-ore exception. |
| Depth | 6 | Build one complete post-Seal layer where power, water, spoil, lodes, shallow goods, and iron all interact. |
| Fun | 6 provisional | Observe 8–12 first-time 60-minute sessions; fix the three most repeated frustrations. |
| Novelty | 8 | Put the gravity-factory decision and lode coverage visibly inside the first ten minutes and demo climax. |
| Coherence | 6 | Canonize one premise and remove conflicting near-term promises. |
| Pacing | 5 | Author and human-test a deliberate 2/10/60-minute beat map. |
| Onboarding | 6 | Teach “open pocket → work face → cover with Head/Spur” as the first durable mental model. |
| Replayability | 4 | Validate whether geology produces genuinely different bases before adding meta-progression. |
| Commercial promise | 6 | Ship a polished 60–90-minute demo ending at Seal breach plus Stonereach reveal. |

## Experience scorecard

| Category | Score | Core evidence |
|---|---:|---|
| Readability | 5.5 | Strong player/lit-center read; weak rock/void/stain separation; labels carry machines. |
| Art coherence | 6.0 | Terrain, lighting, and miner cohere; procedural machine/UI language does not yet match. |
| Atmosphere | 7.5 | Surface vista and lamp chambers have identity and scale. |
| UI | 6.5 | Bazaar and hotbar architecture are competent; HUD layers collide and copy has drifted. |
| Movement foundations | 7.0 | Variable jump, coyote/buffer, stride, grapple, lead, water, and impact systems are serious; hands-on feel remains unverified. |
| Feedback / juice | 7.0 | Broad feedback exists but composition is uneven and first-run silence removes half of it. |
| Audio as experienced | 3.5 | Rich procedural audio exists, but a clean profile defaults to muted. |
| Accessibility | 4.0 | Remap/audio/shake/zoom exist; no gamepad defaults, UI scale, visual-accessibility suite, or cue captions. |
| Onboarding presentation | 6.0 | Strong objective/hint foundation; stale copy, collisions, silence, and invalid evidence weaken trust. |
| Screenshot appeal | 6.0 | Boot is attractive; underground and machines are not store-ready. |
| Perceived production value | 6.0 | Clearly beyond prototype, but visible art/QA seams remain. |

### Capture findings

- `_moment_boot.png`: valid and attractive. Strong sky, ruin, mountain layers, surface cutaway, and miner accents. Still wide and HUD-heavy; the miner is roughly 6% of frame height.
- `_moment_stain.png`: central lamp chamber reads; outer rock and void collapse toward the same near-black. The staged right-wall lode tell does not answer “where do I dig next?” reliably.
- `_moment_delve.png`: invalid. It shows the full Bazaar/Pack modal and `PAUSED (P)`.

Likely capture cause: `capture_moments.gd` boots the live input-responsive main scene and never disables `MainView._unhandled_input` or asserts clean modal state. Ambient `E`/`P` input can contaminate a long fixture. The evidence proves missing isolation/validation, not which device emitted the events.

### Highest-priority experience failures

1. A clean first profile starts muted (`scenes/settings.gd:16`).
2. Rock, excavated void, and buried stain lose semantic separation outside the lamp core.
3. Machines read as labeled UI cells rather than installed hardware (`scenes/world_renderer.gd:2302-2415`).
4. Machine states become color-only at survey zoom.
5. HUD layers draw independently and collide (`scenes/hud.gd:251-285`).
6. Camera framing remains too wide/HUD-heavy for action marketing.
7. No gamepad defaults or complete visual-accessibility controls exist.
8. Player-facing tool/binding text has drifted from current mechanics (`scenes/hud.gd:188`, `:2005`; `scenes/main.gd:983`).
9. The buried-lode tell is a measurable tint but not a reliably understood geological affordance.
10. Canonical review captures fail open rather than fail closed.

## Engineering scorecard

| Area | Score | Core evidence |
|---|---:|---|
| Architecture | 7.0 | Strong deterministic node-free sim and extracted subsystems; reduced by god files, manual registries, and view consumption of sim dirty state. |
| Correctness confidence | 5.5 | Broad deterministic/conservation coverage; save and canary blind spots remain. |
| Test validity | 4.5 | Ambitious 58-layer suite; destructive fixture, invalid assertions, and representative-state gaps. |
| Performance | 6.0 | Retained chunks/fine regions are strong; controlled absolute target and mature-base profile are missing. |
| Maintainability | 5.5 | Subsystem extraction helps; four 2K–3.5K-line files and duplicated test infrastructure hurt. |
| Observability/tooling | 4.5 | Good prose diagnostics; logs are deleted, skip accounting/artifacts/lint/schema coverage are weak. |
| Documentation | 4.5 | Rich rationale, materially stale executable claims. |
| Contributor readiness | 3.5 | Fresh contributor can run code but cannot safely follow advertised test workflow. |
| Release readiness | 2.5 | Save, CI parity, cutover, and export blockers. |

## Prioritized engineering findings

### P0 — destructive test path

Inject a unique save path before scene construction. Add a sentinel test that proves a pre-existing production-slot byte sequence remains unchanged. Make the runner fail if any test selects the production path.

### P0 — non-atomic sole save

`SaveGame.write` opens the final path directly in write mode (`src/core/save_game.gd:116`). There is no temporary file, flush/close verification, atomic replace, checksum, backup, or last-known-good recovery.

Required behavior:

- Encode and schema-validate complete state before promotion.
- Write a temporary file, close/flush, read-validate, then atomically replace.
- Retain a backup and distinguish no-save from corrupt-save in UI.
- Preserve the old good save under injected write, rename, permission, or disk-full failure.

### P0/P1 — non-transactional restore and seed corruption

Restore promises all-or-nothing but mutates the live sim field by field (`src/core/save_game.gd:56-101`). Malformed later data can leave earlier fields changed.

Continue also restores `sim.world_seed` without synchronizing controller `_world_seed`. The next save overwrites the correct captured seed with stale controller state (`scenes/main.gd:2043-2055`). A rerolled title followed by Continue can therefore resave a world under the wrong seed and rebuild fine collision terrain incorrectly.

Decode into a temporary complete state, validate it, and commit once. Remove duplicate seed authority or synchronize it after load. Add a cross-seed Continue/resave/fine-grid regression.

### P1 — save version and authoritative phase drift

Save `VERSION` remains 1 while new fields silently default. `_rate_tick` and `_seep_tick` are not persisted or explicitly reset, so same-process F9 and fresh-process restore can produce different futures. Use explicit v1→v2 migration and define phase semantics.

### P1 — invalid harness assertions

Verified defects:

1. `check_pack_layout` asserts a row count is `>= 0`.
2. `check_mining`'s LOS-blocked branch is unreachable through its aim path.
3. `check_plunge` asserts no mining while the driver never attempts mining.
4. `check_loop_health` clamps penalty components, then checks that they do not exceed those clamps.
5. `check_seam` compares one call to the same call.
6. Save/determinism and conservation canaries share hand-maintained omissions, including lode/fill/sink/consumed/machine fields and the live Drift `flow` hook.

Every repaired guard needs a negative or mutation test proving it fails when the regression is introduced.

### P1 — invalid scalar scoring

The cutover's loop score computes pace as elapsed frames divided by full-run par. Early failure therefore appears artificially fast. The score is printed before the completion veto. Publish `N/A` or zero when incomplete; keep raw diagnostics; remove tautological cap checks.

### P1 — CI is not full

Add explicit PASS/FAIL/SKIP accounting, a real display/GPU job for pixels and rendering performance, and durable artifacts. Keep portable relative hitch ratios. Add an absolute budget only on named controlled hardware; if the target is 120 fps, require busy p95 ≤8.33 ms there.

### P2 — scaling cliffs to profile, not guess at

- Full 128×128 veil upload and iteration over all machines/torches/conduits.
- Global water dictionary scan before view culling.
- Roughly 49K `surface_row` probes per godray redraw.
- All machine problems recomputed each frame.
- HUD redraw every frame.

Profile a mature water-heavy, machine-heavy base first. Likely remedies are revision-driven updates, cached surface profiles, and spatial buckets.

### P2 — manual extension seams

Machine/content registration is split across main, renderer, sim behavior, visuals, save filename construction, and hand-maintained test frontiers. Build one validated content catalog and derive runtime maps, serializer resolution, and coverage tests from it.

### P2 — documentation and release drift

`docs/ARCHITECTURE.md` contains stale quota, richness, save, resource, and scene-tree claims. It references missing `DECISIONS.md`. README claims desktop targets while `export_presets.cfg` is ignored and absent. Add contributor/release instructions only after the workflow is safe and reproducible.

## First 2 / 10 / 60 minutes

### 0–2 minutes

The horizon colossus, ruin, depth chip, and downward direction establish atmosphere well. The opening instead teaches a temporary solid-ore exception while the authored lode pocket sits nearby. Bazaar, tree, forge, ore, coal, and adit compete for attention. A clean profile is silent.

Targets:

- Control within 10 seconds.
- First meaningful action within 20 seconds.
- First visible and audible payoff within 45 seconds.
- At least 80% of first-time players know that down is the direction.

### 2–10 minutes

Dig → toss → forge → chop → repair → research → craft is understandable, but it delays the unique gravity-automation payoff behind familiar resource chores. The objective ladder is instruction-led rather than discovery-led.

Targets:

- At least 80% can explain “gravity moves output down.”
- At least one self-directed action.
- First automation begun or clearly desired.
- Lode exposure/coverage, not disposable solid ore, becomes the durable mental model.

### 10–60 minutes

Evidence is weak. Objectives end at the Seal. Seal/rung tests inject equipment, resources, and prepared geometry; they prove isolated verbs, not a natural hour-long economy. The repository itself concedes only about 15 minutes are agent-validated (`docs/PROGRESSION.md:134-145`).

Targets:

- At least 75% can always name a personally chosen next goal.
- At least three meaningful layout revisions.
- No dead stretch over three minutes without discovery, decision, or payoff.
- Intended cohort reaches/breaches the Seal after tuning.

## Evaluation framework

### Layer 0 — non-negotiable vetoes

- No crash or data loss.
- Deterministic authoritative state.
- Conservation and transactional failure behavior.
- Safe, recoverable saves and explicit migrations.
- Core arc completes through real verbs.
- Player cannot become trapped without an understandable recovery.
- Capture/test evidence represents the state it claims.
- Critical affordances are readable without contradictory text.

No scalar is published when a veto fails.

### Layer 1 — objective ratchets

Keep raw, named metrics rather than hiding them in one score:

- Task success and median/P90 time.
- Repeated friction counts and stuck frames.
- Longest quiet gap and event density.
- Encounter richness and drought.
- p95 frame ratio and controlled-hardware absolute time.
- Rock/void, stain-direction, player, machine, and state recognition.
- Audio audibility, clipping, distinctness, and voice drops.
- UI overlap, clipping, contrast, and binding truth.

### Layer 2 — feature addition score

Only score a feature after all vetoes pass and a human reviewer says it belongs specifically in SINKFORGE.

| Dimension | Range | Question |
|---|---:|---|
| Pillar leverage | 0–3 | Does it strengthen embodiment, gravity logistics, or geology as gameplay? |
| Demand-pull | 0–3 | Do players encounter and articulate the problem before receiving the solution? |
| Decision depth | 0–3 | Does it create repeated meaningful tradeoffs or viable layouts? |
| Column reuse | 0–2 | Does it reconfigure old infrastructure and keep shallow inputs relevant? |
| Perceptible payoff | 0–2 | Is the consequence visible/audible and memorable without explanation? |
| Testability | 0–2 | Can correctness, readability, and regression be checked non-vacuously? |

Interpretation:

- **11–15:** prioritize after prototype evidence.
- **8–10:** prototype narrowly; do not commit campaign scope.
- **0–7:** decline or redesign.

Separate cost/risk from value. A cheap feature does not become valuable, and a high score does not excuse a safety or belonging veto.

Suggested addition evidence:

- ≥80% infer the affordance without bespoke explanation.
- ≥70% predict its main consequence before use.
- It creates a repeated decision at least three times in 60 minutes.
- Removing it causes ≥20% task-success loss or ≥25% extra time/friction in the problem it solves.
- Reject additions that only add a resource, recipe, or stat without changing a decision.

### Layer 3 — demand-pull and fun evidence

Demand-pull:

- ≥60% verbalize the problem/desire before unlock.
- ≥70% use the solution within five minutes.
- Situational adoption roughly 30–80%. Below suggests dead content; persistent >90% suggests a mandatory tax.
- Major logistics problems retain at least two viable solutions.

Fun evidence for 8–12 observed first-time 60-minute sessions:

- ≥70% name an unaided memorable moment.
- Median “want to continue” ≥4/5.
- Median repeated-frustration rating ≤2/5.
- ≥50% voluntarily continue ten minutes beyond the requested stop.
- ≥60% voluntarily repeat or optimize an optional activity.
- Any recurring frustration seen in >25% of sessions becomes a top sprint issue.

Do **not** reduce these to one number:

- Whether a feature belongs in this world.
- Wonder, dread, surprise, or the emotional meaning of depth.
- Whether the player feels like a miner/engineer rather than an inventory clerk.
- Visual legibility in motion and sensory overload.
- Movement weight, responsiveness, comfort, or fatigue.
- Audio timbre and long-session mix fatigue.
- Stories players tell about bases and mistakes.
- Lore coherence and the meaning of the ending.
- Severe outliers such as trapping, motion sickness, or unreadable critical gates.

## Visual and experience acceptance ratchets

1. **Rock/void:** blind classification ≥95% across randomized depth/light crops.
2. **Buried stain:** ≥80% choose the intended dig direction; false positives at unstained walls ≤10%.
3. **Priority machines:** Forge, Drill/Head, Generator, Spur, and Hopper classify ≥85% at 1.0/0.70 zoom with text removed and grayscale applied.
4. **Machine state:** working/stalled/spent classify ≥90% without relying on hue.
5. **HUD:** scripted title/arrival/hint/alert/hover/pause/Bazaar matrix has zero bounding-box overlap or clipping.
6. **Accessibility:** body text 4.5:1; large text and essential glyphs 3:1; keyboard/mouse and controller reach every core verb/menu; reduced effects preserve event recognition.
7. **Player salience:** ≥90% locate the miner in a 100 ms frame; ≥80% identify the motion verb in a one-second clip.
8. **Capture validity:** injected `E`/`P` cannot alter gameplay captures; contaminated state exits non-zero and does not overwrite the canonical PNG.

Raw screenshot diff is noisy because animation and motes can change large pixel regions. Use repeated phase-controlled captures, threshold changes above 0.20, and localization maps. Geometry/contrast/clipping may be automated; “does this feel like solid geology/installed machinery/a gravity factory?” remains blind-human judgment.

## Recommended worktree disposition

| Worktree | Commit | Disposition |
|---|---|---|
| Lode cutover | `0d9655d` | **Hold.** Completion, pacing, and deep-world play are red; Borer/Drift pay path remains incomplete. Fix after test safety. |
| Tile/rock texture | `fa9cca3` | Promising response to rock/void problem. Re-profile dig hitch and frametime; margin is thin. Integrate only after safe harness and blind A/B. |
| Audio | `36f1e1f` | Most complete worktree. Rebase after deciding clean-profile sound-on; add enclosure-space ratchet. Verify safely before merge. |
| Bazaar UI | `172be3d` | Promising and mostly verified. Re-run after save isolation; refresh `docs/BAZAAR.md`; inspect world-layer clipped stubs. |
| Lighting | `1f68530` | Draft. High-value problem, but finish/review rather than merge as-is. |
| Particles | `56781dd` | Draft. Defer behind readability and safety; particles must not hide semantic state. |
| Miner/movement | `9dd8b9c` | Draft. Finish only with hands-on and motion-comfort evaluation. |
| Glyphs/inspector | `4d03f77` | Draft. Evaluate against machine silhouette/state ratchets. |

Do not merge several visual worktrees together. Establish a safe baseline, then rebase and evaluate one at a time so attribution remains possible. Never delete `history/`, `assets/`, user saves, or curated files.

## Dependency-ordered 30/60/90-day direction

### Days 0–7: restore safety and truth

1. Isolate `check_saveload` and add production-slot sentinel protection.
2. Implement atomic save + backup + recovery + transactional restore.
3. Fix seed ownership and create explicit save v2 migration/phase semantics.
4. Repair the six invalid checks with mutation/non-vacuity tests.
5. Make PASS/FAIL/SKIP explicit; stop calling skipped CI checks full coverage.
6. Make canonical captures fail closed and suppress live device input.

### Days 8–30: complete and validate the honest opening

1. Finish lode cutover end to end: generated lodes, tutorial, sonar/minimap, Borer/Drift resource path, solid-ore removal, and save migration.
2. Publish no loop score until the opening completes.
3. Resolve aquifer pocket generation contracts across a seed corpus without weakening the embodied shipping-seed gate.
4. Default clean-profile audio to audible or require an explicit first-run choice.
5. Repair rock/void/stain readability and current copy/binding truth.
6. Run 8–12 observed first-time 60-minute sessions; freeze campaign expansion until findings are ranked.

### Days 31–60: build one complete post-Seal layer

1. Make Aquifer a spatial regime with ingress, containment, pumping, and wet-only value.
2. Require a recurring shallow↔deep dependency so old infrastructure remains relevant.
3. Add bounded recurring demand without maintenance chores.
4. Turn five priority machines into installed, identifiable hardware.
5. Add HUD arbitration, controller defaults, UI scale, high-contrast/state redundancy, and reduced effects.

### Days 61–90: produce a falsifiable commercial demo

1. Polish a 60–90-minute arc: lode reveal → Head/Spur line → power → Seal → Stonereach reveal.
2. Ship a real temporary ending/result screen: “the works below are still cold.”
3. Validate 20+ seeds for materially different base layouts, not numerical variation.
4. Create store/trailer captures centered on falling-item chains, embodiment, geology, grapple descent, and Seal breach.
5. Instrument voluntary continuation and return before expanding the 40-hour roadmap.

## Director decisions required

The audit recommends defaults; these are genuine vision forks rather than implementation questions.

1. **Canon:** adopt **“The Works Are Cold”**—restoring an abandoned foundry—as the premise. It best aligns the title, Forge→Sinkforge scale, FORGED counter, environmental antagonist, and downward ending.
2. **Combat:** defer bosses/combat through L3. Prove environmental antagonism and factory logistics first.
3. **Near-term product:** commit to a polished 60–90-minute demo, not an open-ended systems sandbox.
4. **Demo victory:** Seal breach plus a short Stonereach reveal.
5. **Narrative density:** environmental clauses/signage first; defer explicit protagonist/portal exposition.
6. **Terrain direction:** decide crisp tiles versus the current molded rock after blinded comparative captures, not from implementation preference.

## Explicit things not to do

- Do not run the full local harness until save-path isolation lands.
- Do not call current CI full; four material layers skip.
- Do not merge cutover because it prints 98.6/100.
- Do not lower completion, pacing, density, or aquifer thresholds before fixing the underlying contract.
- Do not continue incompatible semantics under save version 1.
- Do not mutate live state while parsing an unvalidated save.
- Do not add more manual registries, serializer field lists, or conservation frontiers.
- Do not optimize renderer hot paths without profiling a mature representative base.
- Do not infer fun from automated completion.
- Do not merge multiple visual worktrees at once.
- Do not delete or modify user-created history, sprites, notes, saves, or curated assets.

## Recommended next-session first strike

The first implementation strike should contain only safety/truth work:

1. Inject a per-test save path and add a production-slot sentinel.
2. Add atomic save replacement with a last-known-good backup.
3. Make restore transactional and fix controller/sim seed ownership.
4. Add explicit save v2 migration and same-process/fresh-process equivalence tests.
5. Repair the invalid save/determinism canary fields touched by that work.

Only after those changes pass focused tests should the full local harness be run. Before that first safe run, back up any real player save outside `user://` and verify the test path in logs.
