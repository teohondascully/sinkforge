# Engineer brief — visual triage adoption

You are the main engineer receiving a director-level visual-quality brief for SINKFORGE. Your task is to
fit the work into the existing priority system without turning it into a broad aesthetic rewrite.

Read, in order:

1. `docs/ORCHESTRATOR.md`
2. `docs/PEER_SESSIONS.md`
3. `docs/PRIORITY.md`
4. `docs/FEEL_GAP.md`
5. `docs/VISUAL_TRIAGE.md`
6. `docs/VISUAL_RECOMMENDATIONS_SURFACE.md`
7. `docs/DIRECTOR_BRIEF.md`

## Director decision

The visual backlog is real. It has **four root systems** and a deliberately granular ticket queue; agents
may execute many of its narrow tickets quickly when their parent workstream is selected:

1. **V1 — guidance quietness and state hierarchy**: current T2.1 follow-through.
2. **T3.1 — rock/void functional readability**: existing prerequisite; flat interiors remain red.
3. **V2/V3 — terrain material grammar and surface/subsoil continuity**: one future T3 parent item.
4. **V4 — grapple visual language**: one future T3 parent item adjacent to T3.10.

The order is intentional. Do not start terrain polish while screen-blocking teaching still dominates the
frame, and do not treat beautiful terrain as a substitute for navigable underground space.

## Immediate assignment

Take **V1 only** after checking current ownership and in-flight HUD work. Your first deliverable is an
evidence packet and a bounded implementation proposal—not code.

1. Inventory every tutorial panel, label, pointer, ring, selected-item panel, and grapple helper:
   trigger, duration, dismissal condition, screen/world position, and priority.
2. Reproduce the supplied failure shape: a sapling tutorial while ordinary surface interaction remains
   visible. Take a named capture through the machine lock; do not overwrite canonical captures.
3. State which helpers are redundant, which are actually critical, and what remains if the central tutorial
   panel is removed.
4. Propose one bounded first treatment: make the SAPLING lesson source-bound and contextual, suppressing
   it during active movement/aiming and retiring it after demonstrated use. Do not redesign all tutorials in
   one change.
5. Define the proof: before/after captures plus the relevant HUD collision/state checks. A green structural
   test does not prove the screen is pleasant; capture review is required.
6. Send the proposal for director review before implementation.

## Later assignments, only after explicit direction

### Terrain material grammar

Do not globally repaint or refactor terrain. Build one controlled dirt-to-stone cross-section experiment
with a single stated material rule. It must preserve/improve T3.1 legibility and be reviewed at normal play
scale, 1×, and 4×. More grain, global brightness, or per-tile hand edits are not acceptable hypotheses.

### Grapple visual language

Do not change movement input as part of visual work. Compare the current dashed guide with two reversible
state-based treatments in motion. The rope should be quiet while aiming and physically legible when
attached/tensioned. Direct movement reliability is a hard regression guard.

## Priority-list instructions

`docs/PRIORITY.md` is the decision queue. Keep it short:

- extend **T2.1** with V1 when its first treatment is selected;
- leave **T3.1** intact as functional work;
- add a single future **T3 terrain-material grammar** item only when V2/V3 is selected;
- add a single future **T3 grapple visual-language** item only when V4 is selected.

Do not add every symptom as a priority item. Link the parent entry to `docs/VISUAL_TRIAGE.md`, where the
full screenshot-led symptom table and rejected-treatment history belong.

## Constraints

- No global “polish” commit and no art rewrite.
- No lowered readability, HUD, or performance thresholds.
- No canonical-capture overwrite; diagnostic output must stay out of the canonical namespace.
- Do not run Godot/captures without the shared machine lock.
- Treat trace logs as read-only except your own; declare file ownership before edits.
- Keep observation separate from inference. A nicer still image does not prove better play.
- Do not copy Noita’s visuals. Borrow only world-first composition, information restraint, and material
  hierarchy.

## Required report format

End every phase with:

1. hypothesis;
2. exact files/states inspected;
3. before/after evidence or explicit absence of evidence;
4. functional regressions checked;
5. what the result supports, what it does not support;
6. one next recommendation: `SHIP`, `REVERT`, `RUN ONE MORE CONTROL`, or `DEFER`.
