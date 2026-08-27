# Lead handoff — drive the visual-triage program to completion

You are the lead engineer responsible for turning SINKFORGE’s visual-triage program into shipped,
evidence-backed improvements. This is a director-approved active workstream. Do not treat it as a reading
exercise, an optional polish backlog, or permission for one giant art rewrite.

Your outcome is a game whose normal play frames prioritise player action, route, material mass, and visible
machine causality over tutorials, labels, target telemetry, and undifferentiated texture.

## Read before assigning or changing anything

Read these in this order and completely:

1. `docs/ORCHESTRATOR.md`
2. `docs/PEER_SESSIONS.md`
3. `docs/PRIORITY.md` — the milestone decision queue
4. `docs/FEEL_GAP.md` — visual history and prior decisions
5. `docs/DIRECTOR_BRIEF.md` — experience-evaluation constraints
6. `docs/VISUAL_TRIAGE.md` — root causes, evidence, sequencing, acceptance rules
7. `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` — 45 concrete UI, grapple, terrain, surface, machine, and
   pixel-craft tickets
8. `docs/handoff/VISUAL_TRIAGE_ENGINEER_BRIEF.md` — what to read, where this fits, immediate assignment,
   constraints, reporting format

Then inspect the current `git status`, active worktrees, `docs/tracelog/`, and the director bus. Trace logs
are read-only except your own. Do not assume a claimed fix is on `origin/main`; verify the commit and remote
state.

## Sources of truth — do not create a competing queue

The project already has different documents for different jobs. Preserve that division:

| Question | Source of truth | Your responsibility |
|---|---|---|
| What is important now / what milestone may run | `docs/PRIORITY.md` | Add or update only small parent milestones, preserving its ordering and rationale. |
| What exact visual tickets exist | `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` | Select, assign, and mark each ticket through its evidence lifecycle. |
| Why a class of work matters / what success means | `docs/VISUAL_TRIAGE.md` | Enforce its root-cause reasoning and acceptance rules. |
| How an assigned engineer should work | `docs/handoff/VISUAL_TRIAGE_ENGINEER_BRIEF.md` | Give it with every scoped visual assignment. |
| What agents did and what remains uncertain | Each agent’s own `docs/tracelog/<id>.md` | Require evidence-rich entries; do not rewrite peer traces. |
| Cross-agent direction / halt / ownership | Director bus | Use it for material redirections, conflicts, and completion acknowledgements. |

Do not make a fourth “master visual todo” file. The ticket document is the granular execution queue;
`PRIORITY.md` is the concise milestone map. Keep their links bidirectional when an item becomes active.

## Current director ordering

The program is intentionally sequenced. Work may be parallel inside a selected phase, but later phases may
not use “prettier screenshots” to waive earlier functional gates.

### Phase 0 — establish the execution baseline

Before changing pixels:

1. Reproduce and archive named baseline frames for normal surface play, sapling help, active grapple,
   map-open, first machine, and representative underground play.
2. Map every selected ticket to an owner, affected files, named screenshot state, hypothesis, and
   regression guard.
3. Add a compact status annotation to each selected ticket in `VISUAL_RECOMMENDATIONS_SURFACE.md` using:
   `OPEN`, `IN FLIGHT`, `PROVED`, `SHIPPED`, `REJECTED`, `BLOCKED`, or `INVALID`.
4. Record *why* an item is blocked. “Waiting” is not a state.

**Completion:** baseline evidence exists without overwriting canonical captures; every started ticket has an
owner and a testable claim.

### Phase 1 — quiet enough to play: T2.1 / V1

Execute the guidance and attention-hierarchy queue first:

- `UI-01` through `UI-08` are the core; the SAPLING lesson is the required opening treatment.
- `UI-09` through `UI-15` may run in parallel only after the helper inventory shows what each label/ring/
  arrow actually means.

**Non-negotiable design rule:** only one of immediate player action, genuinely new discoverable opportunity,
or critical danger may be primary in a frame. Non-critical teaching is source-bound, contextual, and retires
after demonstrated use.

**Completion evidence:** before/after captures of all Phase-0 states; HUD collision/state tests where
relevant; a brief human/director review that the player and route are now the first read. Do not call a
green layout test proof that the frame is pleasant.

### Phase 2 — functional underground legibility: T3.1

T3.1’s unresolved flat-interior rock/void failure is a functional prerequisite. The contact-edge result is
green; do not reopen edge treatment simply because it is visually tempting. Any treatment must target flat
interiors, use the corrected pooled capture procedure, and preserve the existing floors.

**Completion evidence:** accepted interior treatment, pooled legibility evidence, no threshold changes, and
normal-scale capture review. If the required route remains chance-level readable, later terrain-art work is
`BLOCKED`, not merely lower quality.

### Phase 3 — terrain material grammar: new T3 parent

Once Phase 2 is ready, drive `TR-01` through `TR-10` and `SF-01` through `SF-03` as a disciplined rapid
iteration batch. Start with one controlled dirt-to-stone cross-section; do not distribute a new texture rule
across the whole world before it works.

**Design rules:** broad mass before local texture; dirt and stone receive distinct variation languages;
bright accents carry ore/fresh fracture/wetness/light meaning; surface is the top of the same earth beneath
it.

**Completion evidence:** normal-scale, 1×, and 4× A/B comparisons; independent material-identification
review; no rock/void regression; a visible rule adopted across the selected material family. Rejected
treatments remain documented rather than silently replaced.

### Phase 4 — grapple visual language: new T3 parent adjacent to T3.10

Drive `GR-01` through `GR-07` from motion evidence. The goal is not to make grapple less useful; it is to
make its visual intensity follow player commitment: quiet aim, clear attachment, expressive tension/release.

**Completion evidence:** named motion captures for aim/attach/tension/release/miss; direct input reliability
is unchanged or better; player silhouette remains the first read; no permanent debug-looking guide remains
when it is not aiding a decision.

### Phase 5 — machines and surface composition: existing T3.2 / T3.11

Only after the frame is quiet and terrain coherent, select `PC-01`, `PC-05`, `SF-04`, `SF-05`, `SF-06`, and
`SF-07`. The machine must communicate its state through hardware before labels; landmarks/props must support
the world’s composition rather than compete with gameplay.

## How to dispatch an individual ticket

Give an engineer exactly one initial ticket or a tightly coupled pair. Their assignment must contain:

1. Ticket ID and named capture state.
2. The observed symptom, separated from the intended interpretation.
3. One proposed visual treatment—not a menu of optional changes.
4. Claimed files and explicit files they must not touch.
5. Required before/after evidence and relevant structural/functional guard.
6. A stop condition: `SHIP`, `REJECT`, `RUN ONE MORE CONTROL`, or `BLOCKED`.

No agent may respond to a failed screenshot with a larger unrelated “polish” pass. Revert or preserve the
failed experiment, report the cause, and dispatch the next hypothesis.

## Safety and quality constraints

- Use `tools/with_machine.sh` for Godot/capture work. Never run concurrent engine sessions.
- Never overwrite canonical captures; diagnostics belong in their own namespace.
- Never lower HUD, readability, input, or performance floors to make visual work pass.
- Do not change gameplay, save semantics, objectives, or grapple physics under a visual ticket without an
explicit director decision. If the visual defect exposes a design defect, report it and split the work.
- No source-wide refactor, renderer rewrite, mass resprite, texture-atlas replacement, or “make it like
  Noita” task. Borrow information restraint and material hierarchy, never another game’s assets or identity.
- Preserve user files and unrelated worktree changes. Never use `git add -A`.

## Reporting rhythm and completion control

After every meaningful ticket outcome, publish a director-style update containing:

- **Recently completed:** ticket IDs, commit(s), and visible result;
- **In flight:** owner, hypothesis, evidence expected, and risk;
- **Next up:** the next one to three tickets and why they precede others;
- **Milestone posture:** `BETWEEN MILESTONES`, `PHASE N IN PROGRESS`, `MILESTONE READY FOR REVIEW`, or
  `BLOCKED`, with concrete cause;
- **Truth status:** what was pixel-verified, test-verified, only inferred, or not yet reviewed.

At least once per phase, audit the queue:

1. no `IN FLIGHT` ticket lacks an owner or capture state;
2. no `PROVED` ticket lacks before/after evidence;
3. no `SHIPPED` ticket is only local when it is being described as remote/mainline work;
4. no selected ticket duplicates another’s hypothesis;
5. no low-value craft ticket has displaced T1.0, T2.1, T3.1, or other active functional prerequisites.

The program is complete only when every ticket is explicitly `SHIPPED`, `REJECTED`, `BLOCKED` with a named
external dependency, or intentionally superseded with a written reason. “The screenshots look better” is
not completion. Completion is a traceable set of reviewed visual improvements that leave the game more
legible, quieter to play, and more recognisably its own.
