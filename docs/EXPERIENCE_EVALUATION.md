# Agent-play opening evaluation protocol

**Status:** normative, promoted from a local-only working document 2026-08-26. It is the concrete "how"
underneath the proxy-metric requirement in `docs/CLAIMS.md` §5 (no `engagement` claim kind exists;
engagement claims must decompose into structural, balance, or legibility claims with a stated proxy) and
`docs/ARCHITECTURE.md` §7's calibration corpus. This is not a harness layer, a release gate, or authority on
fun. It operationalises the first 20 minutes of the experience-evaluation program in
[`docs/archive/DIRECTOR_BRIEF.md`](archive/DIRECTOR_BRIEF.md#4-experience-integration-evaluations). An agent
may implement it only after the readiness gates below pass and after the director assigns a scoped
implementation task.

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

## Question

> _[Section removed 2026-08-25, pivot: the opening-loop question (resource discovery, research, a first
> automated extractor) was specific to the persistent-world progression. See git history for the original
> text.]_

## Evaluation portfolio: do not make one harness answer every question

The current deterministic harness is strongest when it answers narrow technical questions: does a state
transition conserve resources, did the real input path perform an action, did the renderer expose the
relevant state, and did the frame stay inside the declared host budget? Those checks remain the release
and regression layer. They should not be stretched until they pretend to measure curiosity, motivation, or
fun.

The experience program therefore has six deliberately separate layers:

1. **Deterministic system checks** — simulation invariants, save/load, worldgen, caches, timing, exit codes,
   assertion floors, and harness self-integrity.
2. **Real-engine encounter checks** — controlled scenes that ask whether an ore lode, machine state,
   resource flow, recovery route, or UI affordance is actually perceivable through the player path.
3. **Calibrated agent journeys** — blind, self-directed, constrained, and recovery play against a
   reachable scenario, with actor capability separated from game evidence.
4. **Screenshot-only criticism** — a separate observer sees frames or ordered captures without code,
   simulation state, objectives, or design intent and reports what a first-time viewer cannot explain.
5. **Counterfactual A/B evaluation** — the same pinned actor, seed family, route, and goal compare one
   treatment at a time: quieter terrain, reduced tutorial chrome, a different grapple cue, or a more
   legible machine payoff.
6. **Human calibration** — a small, fixed human sample calibrates whether an agent's confusion or
   continuation behaviour resembles a player's. It is calibration, not a requirement for every commit.

No layer may certify all six questions. A technical pass cannot certify fun; an actor failure cannot certify
a game defect without capability and reachability controls; and a screenshot critic cannot establish that a
route is mechanically possible. Keep these layers in separate receipts and run them at different cadences:
deterministic checks per change, encounter checks for selected visible changes, and journey/A-B/human work
as a slower corpus-level evaluation.

### What the journey layer must discover

Completion is only one signal. A valid journey should record whether the actor independently formed the
intended next desire after a payoff: seeking fuel after building a machine, looking for processing after
finding ore, choosing a route after depletion, or recovering from a self-created hole. Also record time to
understanding, dead-end actions, reversals, voluntary continuation, and whether the actor can state what
it was trying to do after the run. Do not supply these desired answers in the prompt.

### Three-stage adoption

- **Keep extending deterministic checks** only for stable regressions and controlled encounter contracts.
- **Build the journey subsystem as a separate corpus runner** after its readiness gates pass. It owns
  scenario rotation, actor calibration, oracle reachability, assistance levels, loop detection, and raw
  receipts; it is not another per-commit green/red layer.
- **Defer adaptive self-play** until the corpus has two or three manual runs that produce repeatable,
  actionable differences. Adaptive goal generation is an explicit later experiment because it can reward-
  hack the evaluator and mistake actor exploitation for game quality.

## The actor is a calibrated instrument, not a neutral judge

An agent can fail because the game is unclear, because the fixture is impossible, because the input adapter
is broken, or because the actor is not competent at the basic verbs. A failed journey is therefore never a
game verdict by itself. The run must separate these classes before scoring:

| Class | Meaning | Counts as game evidence? |
|---|---|---|
| `WORLD_INVALID` | The required resource, route, or state does not exist | No; generator/fixture finding |
| `DRIVER_INVALID` | Input, pointer, timing, audio, capture, or lock contract failed | No; infrastructure finding |
| `ACTOR_INVALID` | The actor cannot perform a basic verb even when explicitly instructed | No; capability finding |
| `COMMUNICATION_FINDING` | A minimal in-world cue or hint resolves the problem | Yes; discoverability/onboarding finding |
| `DESIGN_FINDING` | A calibrated actor repeatedly cannot infer or execute the path from ordinary cues | Yes |
| `MOTIVATION_FINDING` | The actor understands the available path but does not want to continue | Yes; subjective evidence |
| `ACTOR_LOOP` | Repeated actions/states with no meaningful progress | Diagnostic first; game evidence only when replicated by capable actors |

The actor profile, model/version, prompt, control adapter, frame cadence, and audiovisual feed are part of
the experiment and must be recorded. Absolute scores from different actor profiles are not comparable.
Before/after comparisons should use the same pinned profile, prompt, scenario, and seed family.

### Capability calibration suite

Before a blind journey, run an explicit, non-discoverability calibration against the same build and adapter:

1. move left and right;
2. jump and land;
3. aim at a visible target;
4. mine one clearly marked block;
5. grapple a visible anchor;
6. open and navigate a menu;
7. place one machine in an obvious valid location;
8. recover from a simple, clearly marked hole.

These tasks may give direct instructions because they test the instrument, not the game. If the actor cannot
complete the capability suite, the journey is `ACTOR_INVALID`; do not use it to grade onboarding or desire.
The calibration result is retained with the journey receipt and pinned to the actor profile.

### Reachability oracle

Use a separate privileged oracle only to establish that a scenario is physically possible. The oracle may
inspect state, coordinates, inventory, and world events, and may answer questions such as:

- does the required lode/resource exist;
- can the route be completed through legal player verbs;
- can the machine be built and produce output;
- does the intended state transition occur?

The oracle is never evidence of player comprehension, fun, or desire. The evidence chain is:

`oracle proves path exists → capability control proves actor can operate → blind actor tests communication and motivation`.

### Assistance ladder

Repeat a failed scenario under pre-registered escalating conditions:

- **L0 — blind:** no objective or hint; audiovisual stream and ordinary controls only;
- **L1 — affordance:** the game's own ordinary cue is made visible or replayed;
- **L2 — minimal hint:** one plain-language hint, without coordinates or hidden state;
- **L3 — explicit instruction:** direct controls and target are stated.

Interpret the transition, rather than using assistance to manufacture a pass:

- L0 → L1 success: discoverability problem;
- L1 → L2 success: contextual or wording problem;
- L2 → L3 success: onboarding/control-mapping problem;
- failure at L3 after capability calibration: likely world, driver, or game defect;
- success at L0 followed by voluntary stopping: motivation/payoff problem.

### Loop detection

The supervisor must detect and terminate a probable actor loop instead of allowing it to consume the whole
run and masquerade as a game failure. A loop candidate includes repeated action n-grams, repeated camera or
position states, oscillation between controls, repeated failed attempts at one target, or no meaningful
world-state change over a declared window. Terminate as `ACTOR_LOOP`, preserve the raw trace, and run the
assistance ladder. One model looping is not a product verdict; multiple calibrated profiles reproducing the
same loop may become a design finding.

## Decision use

The output can:

- identify a concrete opening bottleneck for design work;
- veto a claim that an automation payoff, lode route, or Freight Winch premise is player-legible;
- compare a changed opening with its recorded baseline.

The output cannot:

- certify fun, addiction, tactile feel, or commercial readiness;
- turn a score average into a design verdict;
- authorize a Freight Winch, capacity limit, or new objective by itself;
- replace human play evidence.

Human reactions remain authority for enjoyment. Agent evidence is directional and must be labelled with its
limits.

## Readiness gates

Do not run or score the 20-minute evaluation until all are true:

1. **Safe isolation:** the run cannot read, overwrite, or delete a real player save and it owns the machine
   lock for its whole session.
2. **Truthful route:** an unmodified generated seed contains usable lode and the first research → drill
   route can be completed through player-facing verbs. No injected inventory, pre-dug path, direct sim call,
   map-coordinate oracle, or objective-step driver is allowed.
3. **Unmanufactured desire:** the permanent objective rail is absent after the opening lesson. Contextual
   world guidance may remain, but an on-screen command cannot supply the answer being judged.
4. **Legible route:** every underground region required by the route has passed the current rock/void
   readability requirement. A route that requires navigating chance-level dark interiors returns `INVALID`,
   not a low agency score.
5. **Evidence feed:** video or ordered captures, audio status, exact input cadence, commit, settings, seed,
   and save state can all be retained without overwriting canonical captures.
6. **Actor boundary:** the actor can be given only player-visible information. If the implementation still
   exposes `FactorySim`, target cells, inventories, resource lists, objective IDs, or world-event state to
   its decision policy, the evaluation is `INVALID`.

The first manual pilot may stop at the five-minute orientation checkpoint; it must not be presented as a
20-minute result if any later readiness gate fails.

## Experimental design

> _[Section removed 2026-08-25, pivot: this section's seed-selection rule, actor prompt, and run shape were
> written for the 20-minute persistent-world opening (including its explicit Freight Winch exclusion), which
> is dead design. See git history for the original text.]_

## Judging protocol

The actor is blind to the rubric. At least two judges review the evidence without design documents,
implementation intent, target bottleneck, or each other's verdicts. They must declare model family,
prompt, evidence order, and any shared context; shared family or shared prompting means their agreement is
correlated, not independent corroboration.

Each judge returns this vector, with 0–4 anchored scores and cited timestamps:

| Dimension | 0 | 2 | 4 |
|---|---|---|---|
| Orientation | Cannot form a workable first action | Understands local verbs but needs a cue | Forms a self-directed opening plan |
| Opportunity legibility | Does not notice a useful visible opportunity | Notices it but cannot turn it into action | Notices, acts, and updates plan from result |
| Friction fairness | Repeated opaque/accidental failure | Work is understood but interruption is dull | Cost is understood, bounded, and creates a choice |
| Automation payoff | Never reaches or cannot read it | Reads output but treats it as a checkbox | Recognises retired labour and changes behaviour |
| Desire continuity | Stops/asks for direction after a payoff | Performs arbitrary busywork | Forms a specific, world-grounded next plan |
| Route/world coherence | Route appears arbitrary or broken | Traversal works without contextual meaning | Terrain, resources, and machinery imply a useful next place |

For every score, include:

```json
{
  "validity": "VALID | INVALID",
  "observed_evidence": ["timestamped player-visible event"],
  "inference": "separate from observation",
  "score": 0,
  "confidence": "low | medium | high",
  "missing_evidence": [],
  "counterexample": "what would have changed this judgment"
}
```

Never average the vector into a headline fun score. Preserve severe outliers and disagreement. The director
interprets patterns only after reviewing the raw timeline, captures/video, and the actor's post-run account.

### Evidence quality and evaluator independence

Each result must preserve the raw timeline, input trace, audiovisual artifact, actor transcript, prompt
history, validity classification, and stop reason. A prose summary without those artifacts is not a journey
receipt. The actor's narration is secondary to spontaneous input and visible action; an actor can describe a
plausible plan it never enacted.

Two judges with different names are not independent if they share a model family, prompt wording, transcript
order, or design context. Declare those correlations. Agreement is corroboration only to the extent the
inputs are independent.

## Validity and stop rules

Return `INVALID`—never pass, fail, or zero—when any of these occurs:

- a save, machine-lock, capture, audio, input, or recording contract is violated;
- the actor accesses privileged state or a scripted objective/target solution;
- a required route is visually illegible under the current accepted legibility standard;
- a selected seed violates its declared world-generation contract;
- an external failure, not game behavior, ends the session;
- a judge receives intent-contaminating material before submitting a first verdict.

An invalid run is still useful diagnosis. Its report must name the exact broken contract and distinguish it
from an opening-design claim.

## Rollout and ownership

1. **Now:** retain this specification; make no new harness subsystem.
2. **First adoption:** run one manually orchestrated five-minute blind pilot after readiness gates 1, 3, 5,
   and 6. Its job is to validate the evidence process, not grade the game.
3. **Second adoption:** run the three-seed 20-minute evaluation only after the full opening route is
   player-visible and uncheated.
4. **Automation decision:** only after two or three manual runs have detected a repeatable, actionable
   difference may an agent propose minimal orchestration support. Automation must preserve the same actor
   boundary and raw evidence; it may not become a green per-commit harness score.
5. **Milestone reuse:** use a forked-save, matched-route variant for Freight Winch comparisons. Do not
   pretend a changed topology is the same route merely because both sessions reached a machine.

The director owns interpretation and priority changes. An implementation agent owns only the explicitly
assigned fixture/orchestration slice and must not change gameplay thresholds or use evaluation results to
lower gates.

## Journey corpus and scenario registry

The experience layer must not become one enormous script that repeats the same three milestones. Keep the
deterministic harness for stable regression, and maintain a separate journey corpus whose scenarios rotate
across meaningful axes:

- seed and world-generation family;
- depth and lighting;
- resource distribution and depletion state;
- terrain geometry and route shape;
- machine adjacency and targeting ambiguity;
- starting inventory and research state;
- objective visibility mode;
- recovery, blockage, starvation, and relocation conditions.

Every scenario record should declare:

```yaml
id: opening.manual_to_automation
question: Does a player-authored desire survive the first automation payoff?
seed_rule: named corpus rule, selected before the run
phase: blind | self_directed | constrained | recovery
inputs: ordinary keyboard/mouse, declared cadence
feed: resolution, frame cadence, audio state
privileged_state: false
oracle_fixture: named reachability check
capability_profile: pinned actor and adapter
holdout: true | false
stop_window: declared no-progress duration
evidence: ordered captures, trace, transcript, receipt
```

The scheduler should rotate scenario axes and preserve hidden holdout seeds. A scenario that produces no new
information across several commits should be retired or rewritten; repetition remains for regression, but
not as the only source of player evidence. Do not add a new scenario merely to increase a count.

### Journey receipts

Each receipt records:

- commit, scenario ID, seed, actor profile, model/version, prompt hash, and settings;
- capability calibration result and oracle reachability result;
- exact controls, frame/audio feed, and machine-lock status;
- timestamps for first action, first confusion, first discovery, first research/craft, first automation,
  plan changes, loops, voluntary continuation, and stop;
- raw artifacts and their checksums;
- validity class and the evidence supporting it;
- dimension vector with timestamped observations, inferences separated, confidence, missing evidence, and
  counterexample;
- whether the result is eligible for comparison or is diagnostic-only.

No single scalar may erase disagreement, severe outliers, invalid runs, or actor capability failures.

## Future integration-test portfolio

The journey layer supplements, rather than replaces, these existing test questions:

| Layer | Question |
|---|---|
| Simulation contract | Does the state transition conserve resources and obey invariants? |
| Real-input integration | Can the actual player input path perform the action? |
| Rendering/readability | Can a viewer distinguish the relevant state? |
| Performance | Does it fit the measured host budget? |
| Goal-directed play | Can a calibrated actor reach a constrained outcome without privileged state? |
| Blind observation | What cannot a first-time viewer explain? |
| Human calibration | Is the result pleasurable, frustrating, or worth repeating? |

No layer is allowed to answer all seven questions. In particular, a technical milestone pass cannot certify
fun, and an actor failure cannot certify a game defect without capability and reachability controls.

## Known oversights to revisit before first run

- Agent audiovisual and input capability may not model human latency, dexterity, attention, motion comfort,
  or sound perception. Declare these gaps rather than compensating silently.
- Twenty minutes may be too short for depletion, relocation, or late maintenance. Those belong to later
  Evaluation B/D/N sessions, not an inflated opening score.
- A generated seed may conflate worldgen variance with onboarding quality. Report both populations separately.
- An actor may narrate a plausible plan it never enacted. Spontaneous input and visible action outrank prose.
- Two AI judges with different names can still share a prior. Correlation is a limitation, not a quorum.
- A clean technical path can still be boring. Human voluntary continuation and stop reason remain the
  eventual calibration data.
