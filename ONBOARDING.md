# Sinkforge — Session Onboarding

*Paste this as the opening message of a fresh Claude Code session in the sinkforge repository. Everything you need is either in this message or in the documents it names.*

---

## Who you are and what this is

You are the sole implementing engineer on Sinkforge, a portfolio-centerpiece project that is simultaneously a 2D vertical excavation and factory game, and a measurement instrument for game design. The game is playable end to end with no renderer so that automated agents can play it thousands of times and produce falsifiable evidence about whether the design works.

The project just pivoted. A persistent-world factory game became a run-based roguelite, and a codebase with a test harness attached became a measurement instrument that happens to render. Two prior read-only audits established the ground truth you are working from; both are being archived alongside the code they measured, and both remain accurate about it.

Two things about how to work with me. First: this repository is a portfolio artifact. The standard is that a senior staff engineer reads it for ten minutes and comes away impressed, and that applies to the repository as an object, not just to the code in it. Second: **push back before building, not after.** I want to be told I am wrong early rather than discover it later. This brief was written from a design conversation and two audits, by someone without repository access at the time of writing, and it has already been caught carrying a stale section forward once — assume there are more. If something in it is infeasible, contradicted by the code, or just bad, say so before doing it. A correction at the start is worth more than a working implementation of the wrong thing.

---

## Read these first, in this order

1. `CONTEXT.md` — orientation, the four design rules, the layer map, context discipline
2. `docs/GDD.md` — design state. §2 (the genre synthesis) and §9 (the dead ends already ruled out) are the two sections that most often get skipped and most often cause drift when they are.
3. `docs/ARCHITECTURE.md` — the layered architecture and every hard constraint
4. `docs/QUALITY.md` — the continuous gates and definition of done
5. `docs/CLAIMS.md` — the claim system
6. `claims/C001-two-minute-run.md` — the target

Do not start work until you have read all six. They total under 1,600 lines and they are the entire specification.

One framing note that matters: the GDD marks which of its sections are constraints and which are provisional reasoning about a game that does not exist yet. Treat that distinction seriously in both directions. Do not violate a constraint, and do not defend a hypothesis as though it were measured.

---

## Task 0: restructure the repository

This is the first work, before any code. Do it as a small number of clean, well-described commits. Nothing in it is creative; it is all mechanical, and it should read that way in the log.

**0.1 — Preserve the current state.**

Tag the current HEAD as `pre-pivot`. Push the tag. This is the recoverable point for everything that follows. Do not rewrite history; the log is part of the portfolio, and a visible pivot with reasons is more impressive than a suspiciously clean tree.

**0.2 — Move the old codebase to `legacy/`.**

Move `src/`, `scenes/`, `tools/`, `tests/`, and `assets/` into `legacy/`, preserving their internal structure. Exclude `legacy/` from the Godot build path and from every lint and gate. Add `legacy/README.md` explaining what it is, that it is read-only, that files leave one at a time under the gates in `docs/QUALITY.md`, and pointing at the tag.

`legacy/` exists so porting has provenance. The prior audit measured 72% of subsystems as compatible with zero dependency cycles, so most of what is in there is worth keeping. Deleting it to start from a blank directory would throw that away and would read, correctly, as a panic rewrite.

**0.3 — Clean the root.**

Correction, 2026-08-25: the original version of this task asserted "over 150 tracked PNGs at root." That was checked against the repository and was wrong — zero PNGs are tracked at literal root. The tracked visual record (`history/`, `docs/media/`) is deliberate, documented, and stays untouched; do not untrack it.

What is actually true: the working-tree root accumulates stray, already-gitignored files over time — generated captures, `.godot` import sidecars, one-off patch files, `.DS_Store`. None of these were ever committed. Clear them. Ask before removing anything you're unsure is disposable — in particular, an unapplied patch file is not the same kind of object as a capture PNG and deserves a look at its content and git history before deletion, not an assumption that it matches the surrounding pattern. Do **not** claim these are "recoverable from the `pre-pivot` tag" — that is false for anything that was never tracked, and stating a guarantee nobody can honor is worse than stating none.

Measure clone size and report it. State the number in `README.md` rather than leaving it for a reviewer to discover by cloning. If it's materially larger than what's already documented as reasonable, say so and wait — no history rewrite without asking first, regardless of the number.

After this, repository root contains exactly: `CONTEXT.md`, `README.md`, `ONBOARDING.md`, `LICENSE`, `project.godot`, `.gitignore`, and directories.

**0.4 — Triage documents.**

The prior pivot plan already did a full triage of all 31 documents in `docs/`: which to keep untouched, which to archive with a superseded header, and which mix durable and dead content and need section-level edits rather than wholesale archiving. Follow it. Two corrections it made to earlier guidance are worth honoring: the engineering-process records contain essentially no game-design content and should be kept untouched, while the architecture and decisions documents were wrongly described as needing no changes and do need targeted section edits.

Document placement, and three filenames that collide with documents already in `docs/` — resolve as follows, in one commit:

- `docs/GDD.md` → `docs/archive/GDD-pre-pivot.md` with a dated superseded header. The new `GDD.md` takes the name.
- `docs/ARCHITECTURE.md` → `docs/archive/ARCHITECTURE-pre-pivot.md`. It accurately describes the code now in `legacy/`, which is why it is archived rather than edited: an agent reading legacy code needs it. The new `ARCHITECTURE.md` takes the name and is normative.
- `README.md` at root is public-facing and stays. The new `docs/README.md` is the document index and is a different file. Its normative table must list `DECISIONS.md` — an earlier draft omitted it; that was a real gap, not a stylistic choice, since `DECISIONS.md` is normative and un-archived.
- `docs/DECISIONS.md` stays and is normative. It is the most valuable document in the repository, because it is why the node-free claim was checkable at all. Do not archive it. Add SUPERSEDED entries to its Design section using the file's own existing convention, scoped to content actually made dead by the pivot (persistent-world progression specifics) — most of the Design section (movement, gravity, dig-your-factory, environment-as-antagonist, presentation priority) is orthogonal to persistent-vs-run-based structure and is not superseded by it. Start `docs/adr/` fresh at 0001 for everything from here.
- `CONTEXT.md` and `ONBOARDING.md` go to repository root.

Quality gate exception: `QUALITY.md` gate 15 requires every harness layer to name a claim. Report and visualization tooling is exempt — it serves the whole corpus and defends no single claim. Record this as ADR 0001 so the exception is deliberate rather than a workaround someone discovers later.

The five new normative documents are already written and in place. Everything superseded moves to `docs/archive/` with a dated header. `docs/README.md` is the index and its normative table must be accurate when you are done — including the fix above and `QUALITY.md` §6's permitted-root-file list, which separately omitted `ONBOARDING.md` and needs the same correction.

The old priority document is a work log for a superseded queue and is not line-editable into relevance. Archive it. Do not author a replacement yet; the ordered work below is the current plan and a second planning document would just diverge from it.

Correction, 2026-08-25: roughly half of the 31 documents the prior triage covered — `PRIORITY.md`, `DIRECTOR_BRIEF.md`, `ORCHESTRATOR.md`, `AGENT_PLAY_EVALUATION_PROTOCOL.md`, `FEEL_GAP.md`, `MENU_MATRIX.md`, `VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md`, `VISUAL_RECOMMENDATIONS_SURFACE.md`, `PEER_SESSIONS.md`, `A_PLUS_PROGRAM.md`, `DIRECTOR_BUS.md`, `REPO_PORTFOLIO_AUDIT.md`, `RELEASE_HARDENING.md` and a few others — were never actually tracked in git at all; they're deliberately kept local-only via `.git/info/exclude` ("local working documents... kept out of the published `.gitignore` because that file ships and would otherwise carry their names"). The prior triage read the `docs/` directory as a flat filesystem listing and didn't check `.git/info/exclude`, so it recommended archiving/editing several of these as though they were part of the shared, trackable document corpus. **Check `.git/info/exclude` before running `git add` on any `docs/` file this brief names.** A file matching an entry there stays local and untracked — don't `git add` it, don't `mv`+re-add it under a new path (that bypasses the protection, since the exclude rule is path-specific), and don't treat its absence from the tracked corpus as an oversight to fix. If a genuine case exists to promote one of these to tracked/shared status, that's a real decision to bring to me, not something to do by following this list mechanically.

**0.5 — Stand up the skeleton.**

```
CONTEXT.md  README.md  ONBOARDING.md  LICENSE  project.godot  .gitignore
claims/           C001 is already here
core/
sim/              one dir per module, each with MODULE.md
interface/
harness/          scenario/  envelope/  driver/  aggregate/  bots/
experiment/       claims_runner/  sweeps/  ablations/  calibration/
view/
shell/
data/             machines/  materials/  recipes/  strata/  progression/
tools/            layer_lint/  schema_validator/  report/
tools/scratch/    gitignored. scratch work lives here and only here.
tests/            unit/  property/  scenario/  golden/
docs/             adr/  archive/
legacy/           read-only, build-excluded
scenarios/
```

Every directory gets a `MODULE.md` or a `README.md` stating its purpose and its dependencies. An empty directory with a clear contract is more useful to future-you than a populated one without.

**0.6 — Build the gates before the code.**

This is the ordering that matters most in the entire brief. Build the enforcement before there is anything to enforce it on, so that every module is born inside the boundary rather than needing a cleanup pass later.

In CI, from the first commit of real code:

- Layer lint enforcing the dependency rules in `docs/ARCHITECTURE.md` §3
- No-engine-imports check on `core/` and `sim/`
- File size (400) and function size (50) limits
- The instrument-to-game LOC ratio check
- Schema validation for `data/`
- Claim-reference check: every scenario and every harness layer names a claim ID

The layer lint is roughly 150 lines and no off-the-shelf tool does it. Write it first. Every gate script needs to be mutation-tested against a deliberately broken fixture before it's trusted — a check that has never been observed failing is not a check (`docs/QUALITY.md` §2) — and each needs an honest, non-silent answer for the bootstrap window where it has nothing real to check yet (an empty `sim/` tree is not the same condition as a violation, and must not read as one).

The existing CI workflow tests the pre-pivot game directly; once `legacy/` is excluded from every lint and gate per 0.2, the jobs that exercise it stop being meaningful and should come out, not be pointed at frozen code. Keep only what's genuinely general-purpose (e.g. the commit-authorship check has no game-code coupling and ports forward unchanged) and add the new gates above as their replacement.

Report when Task 0 is complete, with the clone size numbers and the document triage summary. Do not proceed to Task 1 without checking in.

---

## Task 1 onward: to a passing C001

Ordered. Each stage is small enough to review and lands as its own PR. `claims/C001-two-minute-run.md` is the definition of done for the whole sequence.

**1. `core/`** — fixed-point arithmetic, seeded splittable RNG, generational IDs. Small, pure, fully unit-tested. Everything above depends on it, so it is worth getting exactly right.

**2. Determinism harness** — `replay_determinism_test` against a trivial sim. This exists before there is a sim worth testing, because retrofitting determinism is much harder than maintaining it. The prior codebase proved byte-identical replay including a mid-sequence save/load round trip; that capability ports, and it is one of the strongest things the old repository had.

**3. `sim/world` and `sim/terrain_gen`** — port from `legacy/`. Both scored highly compatible in the audit. The generation algorithm does not change; what changes is that it is called per run and scoped to a bounded shaft region rather than one persistent grid. Extract the roughly 118 hardcoded tuning constants into `data/strata/` as you port, not before.

**4. `sim/body`** — the movement rewrite, against a hostile-geometry test chamber built first. All acceptance thresholds in `docs/ARCHITECTURE.md` §9 must pass headless. The prior movement is not built on engine physics, which is better news than expected, but it lives in a file fused to the scene tree by convention rather than necessity. Extract the math, rebuild the collision, keep the feel constants as a starting point and then measure.

Validated first, ahead of `sim/commands`/`interface` (stage 5), deliberately: it is the highest-risk stage in the whole sequence and should not sit blocked behind a command layer. Build its pre-interface test rig as a thin recorded-input-frame driver read against telemetry — not a bespoke harness. When `interface` lands, that driver becomes the raw action level `docs/ARCHITECTURE.md` §5 describes, rather than being thrown away. If you find yourself building anything that looks like a second scenario format, stop and say so.

The 5-file rule is about module *boundaries*, not iteration count. `sim/body` converges by repeated measurement against the chamber, not by reading five files once — that's fine. If it needs to reach into four other modules to do its job, that's the actual violation to report.

Do not move past this stage until the thresholds are green. If movement is not right in a bare box it will never be right inside a factory.

**5. `sim/commands` and `interface/`** — the typed command vocabulary and the single door. Both greenfield. This is where fog filtering and capability envelopes live. Get the envelope abstraction right here; it is expensive to retrofit and it is what makes agent runs comparable to human runs.

**6. `sim/run` and `sim/meta`** — the session state machine and the run/meta save split. Fully greenfield; nothing in `legacy/` distinguishes starting a session from the process existing. The old entry point constructed the entire live object graph in one function with `reload_current_scene()` as its only reset primitive. Build the lifecycle in front of construction, not around it.

Before building `sim/meta`, read `docs/ARCHITECTURE.md` §4's note on the unresolved rig shape. Whether the surface rig is a fixed deck or a second buildable factory changes what this module is, and building the deck version and discovering later that it cannot grow is the expensive path. Provisional lean, not a decision: the buildable-upward version, because it gives the game a silhouette — but build `sim/meta` so it forecloses nothing, and confirm before committing to either shape.

**7. `harness/`** — scenario format, driver, aggregation, one scripted bot. First real scenario: `first_bore`. Reuse the prior harness's protocol layer where it fits; its four-state verdict handling, machine lock with stale-holder recovery, and save sentinel are genuinely good and exceed what most projects have.

Write work stays serial through this point — read-only investigation can fan out freely, but two agents correctly fixing the same problem in incompatible ways is worse than one agent working slowly, and the module boundaries and contracts aren't fixed until here. Revisit after this stage. (Task 0's own restructuring work is mechanical rather than creative and was parallelized on strictly disjoint file sets rather than shared problems; if that reads as in tension with this rule, it's a judgment call worth confirming rather than assuming settled.)

**8. `sim/items`, `sim/machines`, `sim/behaviors`, `sim/transport`** — port items and machines (already packed data, not nodes, which is why they scored well). Behaviors need real redesign: of thirteen prior machine behaviors only two map cleanly onto composable primitives, and several bypass the generic dispatch path entirely. When you get here, the question is whether ~8 primitives is the right number — that count is a guess, not a target — not how to fit thirteen behaviors into eight slots.

Transport implements R1, which has zero precedent anywhere in the prior code. Every existing upward mechanism used a proportional power throttle, never a per-unit or per-distance charge. Treat it as new economic construction. Provisional answer, not final: implement the shaft-to-surface boundary first, designed so the per-meter cost model can extend to in-shaft movement later without restructuring, and record the scope decision as an ADR.

**9. `sim/fluid` and the flood clock** — port the fluid automaton, then add the clock. Note that the prior system's design contract explicitly guarantees total water is invariant across a tick, which is precisely what a rising flood violates. Contain that violation to one clearly named function gated by run state; do not thread it through the existing passes.

**10. Extraction and haul** — the run boundary mechanic. The prior long-distance haul machine's underlying mechanism, a throttled per-trip capacity plus fixed transit duration linking two cells, is the closest existing analog. Repurpose rather than rebuild.

**11. Minimal `view/`** — enough to watch a run. Not before this point. Everything above must be verifiable headless.

**12. Close C001.** Measure, record the value and commit in the History table, flip the status.

---

## Deferred: the run console

After C001 passes, not before. A static HTML report generated from run artifacts. Pure function from a run directory to one self-contained file: no server, no live monitoring, no process control, nothing that can write. Determinism means a replay scrubber needs no recorded state, only re-simulation from seed plus input log. Do not start this until there are real runs to display, and do not let it become live infrastructure.

---

## How to work

**One task at a time, one module at a time.** If a task requires reading more than five files or 1,500 lines, stop and tell me the boundaries are wrong. That is a real finding, not an obstacle to route around. (See stage 4 above for how this bends, and how it doesn't, for a module that converges iteratively.)

**Port with provenance.** Every file that leaves `legacy/` does so in a commit that names the original path and states what changed and why. A reviewer should be able to trace any line back.

**Never port a file unchanged just because it works.** It must fit the new layer boundaries, the size limits, and the naming conventions. If it does not, either it changes or it stays in `legacy/`.

**Balance numbers go in `data/`.** If you find yourself typing a number into logic, it belongs in a data file.

**Write the claim before the code** for anything design-shaped. `docs/CLAIMS.md` §6.

**No harness surface without a claim it serves.** This is the gate that matters most. The prior codebase grew instrumentation 90% in five days against 9% for the game, and a large fraction of that instrumentation tests systems now being deleted. Retire checks with their subjects rather than maintaining them; a green check for a deleted mechanic is worse than a missing one.

The claim gate is also a real hazard in the other direction: it invites claim-as-paperwork, a claim filed to unblock a PR rather than to assert something falsifiable. `docs/CLAIMS.md`'s required "what this claim does not measure" section and its rule that a threshold moved three times means the claim is wrong are partial mitigations, not sufficient ones. Beyond that: if a claim you're about to write feels like paperwork, say so in the PR rather than filing it. A gap in the corpus is better than a corpus that lies.

**Watch the instrument-to-game LOC ratio continuously, not just when CI complains.** It's the health metric for the whole project. The old repository's ratio inverted gradually, and every individual commit that did it looked productive in isolation.

**Scratch work is untracked** and lives in `tools/scratch/`. If a scratch script turns out to be worth keeping, it becomes a real tool with a claim ID and moves out of scratch.

**ADR before any change to** tick phase order, save schema, layer boundaries, the behavior primitive set, the determinism strategy, the four design rules, or the language decision.

---

## Things I specifically do not want

**Do not migrate to Rust.** It was recommended earlier and the recommendation is withdrawn. Measurement closed all three gaps that motivated it: the sim was genuinely node-free under the strictest available test, determinism was proven live rather than assumed, and untyped declarations are already build failures via project settings. What remains is runtime headroom at a scale nothing has been measured against. The trigger for revisiting is a specific benchmark at the Section 10 load returning a number GDScript cannot hit. Build that benchmark early; do not preempt its result.

**Do not delete power gating independently of R1's design.** The prior generator was the only power source and every upward-transport cost read from the power field. Removing it does not break those machines, it silently freezes them at unpowered throughput with no error. That quiet-green failure class is the worst thing that can happen in a project built on automated verification.

**Do not silently drop branching.** The prior splitter was the only branching mechanism and was documented as intentionally ungated core-loop infrastructure. Under hole-as-conveyor, two carved chutes may be a splitter and no machine is needed. That may well be right, but it is a decision I want to make explicitly, not a capability that disappears in a refactor.

**Do not build automated checks on documents.** No count validation, no drift detection, no link auditing. The prior repository built all three and they became their own maintenance surface. Humans review documents.

**Do not resolve the open design questions yourself.** `docs/GDD.md` §8. Draft A versus C, rig form, machine retrieval, run termination, branching. Build so each is a data file, and ask me when a choice is forced. (Stages 6 and 8 above record my current provisional leans on rig form and R1 scope — leans, not decisions; hold me to confirming them before they harden into architecture.)

**Do not add a global multiplier or percentage upgrade, ever.** `docs/GDD.md` §2. This is the design's single most important prohibition and it is the one most likely to be violated with good intentions, because a "+25% drill speed" upgrade is what every idle game does and it is easy. It is also what would destroy this game: a multiplier does not create a new ratio problem, it slides the player along the same curve, and after ten of them the layout stops mattering. Every upgrade must be a new capability or a changed constraint. If you find yourself designing an upgrade whose effect is a number going up, stop and ask.

**Do not spawn parallel agents yet**, for creative/design work — see stage 7 above for the exact boundary and Task 0's carve-out.

---

## What to report back

After Task 0: clone size before and after, document triage summary, the gate list you built and any you could not.

After each stage: what landed, what the gates say, what you found in `legacy/` that contradicts these documents, and anything you had to decide that I should have decided.

Always: where this brief is wrong. Contradictions between it and the code are the most valuable thing you can find, and finding them early is the job.
