> **ARCHIVED 2026-08-27, as a second dated snapshot.** `docs/archive/DIRECTOR_BRIEF.md` already exists
> (the pre-pivot original, archived with a superseded header at pivot time). This copy sat untracked at
> `docs/DIRECTOR_BRIEF.md` and diverges from that one by 738 lines — a later edit pass, timestamped the
> same second as several other pivot-adjacent files (2026-08-25 14:49:16). Which edit pass is
> authoritative was not reconciled; guessing would have been worse than two dated files with this note.
> Moved here while closing the `.git/info/exclude` hole (ANVIL step 1).

---

# SINKFORGE director brief — progression, Freight Winch, and experience evaluation

**Status:** approved product direction, 2026-08-17. This is a director's brief, not an implementation
spec. It records why the direction changed, what the next prototype must prove, and what active agents must
not accidentally build around. Exact recipes, timings, machine dimensions, and persistence semantics remain
design work.

**Read with:** `docs/PRIORITY.md`, `docs/MATERIAL_SPINE.md`, `docs/LODE.md`, and
`docs/handoff/VIBE_AUDIT_RESPONSE.md`.

---

## 1. The directive

SINKFORGE's operative identity is **kinetic industrial descent**:

> The player excavates their own topology, moves through it expressively by grapple and winch, and builds
> gravity-driven industry that permanently changes what their body has to do.

`Factorio × Terraria, with gravity that matters` remains useful ancestry and market shorthand. It is not a
substitute for a design test. The internal test is whether excavation, embodied movement, gravity logistics,
and automation cause one another.

The next systemic target is the **Freight Winch / Skipway**. It is a player-placeable, relocatable cargo
network whose moving skip carries bulk goods between extraction sites, processing rooms, and construction
fronts. It is the approved next progression design target and the first candidate for both:

1. the first major logistics payoff that turns a player-dug shaft into infrastructure; and
2. the first hero machine whose function and state are readable without a nameplate.

This supersedes the immediate Descent Engine previously named in `docs/PRIORITY.md` T1.1. The Descent Engine,
water control, lighting grid, mobile rockbreaker, and traveling foundry remain valuable later consumers;
they are not deleted.

---

## 2. The correction: "first automation" was carrying too many milestones

The prior direction compressed too much into one ceremony: retire labor, change the world, reveal a
bottleneck, and begin the factory game immediately. That risks teaching the completed answer before the
player has experienced the problems that make it desirable.

Factorio's developers describe the early order as:

> Manual mining → automated mining → automated logistics → automated production and science.

They explicitly say the order matters because every step automates something the player previously did,
allowing the player to understand and appreciate the upgrade. Their attempt to force assembly into the
first five minutes broke that progression badly enough that they discarded a polished tutorial.

Source: [Factorio Friday Facts #327](https://www.factorio.com/blog/post/fff-327).

SINKFORGE should therefore name five different thresholds:

1. **First machine — extraction.** A Head or drill performs a mining job the player understands.
2. **First route — passive logistics.** Gravity, chutes, or galleries retire simple downward bulk
   movement.
3. **First complete line — processing.** Material reaches a processor and emerges useful without the
   player's hands.
4. **First major logistics payoff — Freight Winch.** Processed parts construct and extend an active route
   upward or from horizontal faces into the gravity trunk.
5. **First external consumer — purpose.** A later world-facing system such as the Descent Engine, Seal,
   drainage, or another physical mechanism consumes or depends on the transported output. A cargo mover is
   not itself consumption.

The first line may make ingots. The problem was never the word `ingot`; the problem was that ingots did not
enter a durable system of appetites.

### The Factorio lessons to retain

- **Experience labor before automating it.** Demand-pull requires felt friction, not an objective claiming
  friction exists.
- **Teach one automation layer at a time.** Extraction, transport, processing, and consumption are
  separate lessons.
- **Consumption gives production purpose.** Factorio names research, construction, and defense as its
  three sinks. It also records that static costs cause players to build the minimum and wait.
  Source: [Friday Facts #284](https://www.factorio.com/blog/post/fff-284).
- **Recipes are curriculum.** A progression recipe should require the systems the player is now ready to
  connect, not merely expensive ingredients. Source:
  [Friday Facts #275](https://www.factorio.com/blog/post/fff-275).
- **The compulsion is a living bottleneck.** Factorio's own postmortem describes its "always a
  bottleneck" loop and criticizes an ending that exits it into "now what?" Source:
  [Friday Facts #187](https://www.factorio.com/blog/post/fff-187).
- **Protect onboarding from worldgen without fixing the player's home.** A dependable starting resource
  envelope can coexist with wild generation beyond it. Source:
  [Friday Facts #258](https://www.factorio.com/blog/post/fff-258).

These are not instructions to copy science packs, belts, enemies, or Factorio's pacing. They explain the
causal structure SINKFORGE's own systems need.

---

## 3. Freight Winch / Skipway — product design

### 3.1 Player-facing promise

> Build a machine that takes bulk hauling out of your hands, then watch its moving cable turn the shaft you
> carved into infrastructure.

The machine should produce three beats, but not necessarily in the same ten seconds:

1. **Liberation:** a repeated bulk-transport job is no longer the player's job.
2. **Consequence:** a large drum, cable, counterweight, and skip begin moving through the excavated world.
3. **Hunger:** visible queues, empty destinations, or competing stops reveal that the first winch is
   insufficient.

The winch is not a fixed relic at spawn. It is built where the player chooses and must tolerate a player
who dislikes the starting area, travels horizontally, or moves after deposits deplete.

### 3.2 What it transports

The first version should be **cargo-first**. Its primary job is predictable bulk movement between player-
chosen endpoints. It can eventually carry ore, processed materials, construction parts, fuel, spoil, or
water containers, but the prototype should prove one material flow before becoming a universal inventory
teleporter.

The design must answer a real route problem. Do not create a contrived detour solely to make the winch
useful. Candidate natural problems include:

- lifting deep processed goods back to an active construction front;
- moving output from horizontal lodes to a vertical gravity trunk;
- moving fuel or parts upward against gravity;
- serving multiple depleted and newly opened extraction faces from one processing room.

Downward cargo already has gravity, chutes, and galleries. The first differentiated use is therefore more
likely to be upward movement, horizontal-face collection into a vertical trunk, or service between a deep
processor and a changing construction front. That remains a hypothesis until players exhibit the pain
before seeing the solution.

The winch also needs a downstream reason to exist. Its parts may expand a trunk, serve a moving construction
front, or connect a relocatable industrial room, but network construction is only a bounded sink. If
nothing continues to want the delivered material, the winch has not solved the post-line void. A modest
later world-facing consumer remains required; the Descent Engine or Seal is still a strong candidate once
the logistics layer is proven.

### 3.3 Relationship to grapple movement

The winch must **transform** grapple play, not replace it.

- Cargo movement should be safe and predictable.
- Player movement should remain faster, riskier, and more expressive.
- The cable, counterweight, and moving skip may become grapple geometry.
- Riding the skip can be possible and playful, but must not become a safe elevator menu that deletes the
  shaft.
- Powered anchors, launches, and moving attachment opportunities are preferable to passive fast travel.

The design fails if factory growth causes players to use the grapple less because traversal has become a
floor selector.

### 3.4 Mobility and depleted deposits

The world supplies resources and terrain; it does not dictate the canonical base coordinate.

- No unique mandatory mechanism may exist only at spawn.
- Winch heads and stations must be packable, reproducible, extendable, or cheap enough to abandon.
- Progress should belong primarily to the player and their network, not a coordinate.
- Old lines may remain useful as a trunk, but relocation must be viable.
- A player must be able to choose a home for beauty or convenience without invalidating the campaign.

The current opening is still coordinate-led through the ruined Bazaar near spawn and the fixed Seal
ladder. The Seal can remain a world band; player capability, Bazaar access, and ordinary production cannot
quietly make the starting ruin a mandatory permanent home. Reproducibility or portability must be explicit
before relocation is claimed.

This also reopens the meaning of **the Sinkforge**. A single fixed abandoned megamachine is no longer the
recommended default. Later direction should choose among a player-built machine, a distributed network
state, repeatable buried nodes, a mobile core, or a geological process. The strongest current constraint is:

> The world may supply bones, but no coordinate may own the player's organs.

The campaign invariant is locked now even though the fiction is not:

> Campaign progress accumulates in player-owned capability and network reach; no unique coordinate owns
> progression.

### 3.5 The bottleneck must be visible in the world

The winch should tell on itself without a dashboard:

- input piles up while the skip is away;
- the destination waits empty;
- a heavily loaded skip moves differently or takes longer;
- the drum, brake, and counterweight expose whether the system is idle, starved, blocked, or saturated;
- competing stations make routing priority visible.

Do not begin with a complicated scheduler. One skip, two stations, one material, and a visible queue are
enough to test whether the system generates a self-authored improvement desire.

An under-capacity route may generate a logistics improvement desire. It does **not** prove the production
economy has a durable appetite. Score those as separate questions.

### 3.6 Failure and recovery

- A stopped winch must not strand the player.
- A depleted source should become an understandable relocation problem, not a broken save.
- Recovering cargo must be possible manually, though less convenient.
- A blockage should preserve items and expose its cause.
- Buffers should prevent the machine from demanding constant babysitting.
- Maintenance must be a design decision, not incidental fuel chores.

The desired player reaction is: **"I see why it stopped, and I already know what I want to change."**

### 3.7 The hero-machine standard

The Freight Winch should be the first machine designed from action outward. Factorio's drill redesign used
the action component as the silhouette's defining feature and made working state visible at distance;
SINKFORGE should apply that principle rather than copy the art.

The winch needs:

- an unmistakable drum and cable silhouette;
- visible tension, braking, and counterweight motion;
- material visibly entering and leaving the skip;
- a strong startup and catch sequence;
- status readable through motion and shape before color or text;
- a positional mechanical voice distinct from the ambient factory hum;
- a scale large enough to own a frame without filling the traversal space.

Source for the design principle: [Factorio Friday Facts #350](https://www.factorio.com/blog/post/fff-350).

### 3.8 Anti-goals

The first Freight Winch must not become:

- a player elevator that obsoletes grappling;
- a universal item teleporter;
- a fixed spawn landmark;
- a static ingot payment disguised as machinery;
- an always-hungry chore that recalls the player every minute;
- an automatic miner that consumes the digging fantasy;
- a menu-driven scheduler before one physical route is fun;
- the entire endgame premise before the opening loop is human-proven.

### 3.9 First prototype slice

The minimum honest slice is:

1. The player performs the target haul manually enough times to understand it.
2. The player chooses two endpoints and installs one winch route.
3. The skip moves one real material without teleportation or item loss.
4. The player can grapple with or around the moving mechanism.
5. A deliberate under-capacity setup produces a visible queue.
6. With objectives suppressed, the player recognizes the queue and changes the route, capacity, or supply.
7. The source depletes; the player extends, moves, or abandons the source endpoint without losing campaign
   progress.

Exact timing remains a hypothesis for human testing. Do **not** encode the old "complete conversion inside
60 seconds" target as doctrine. The opening should be brisk, but appreciation requires prior labor.

Before graybox implementation, define an economic envelope: expected deposit life, expected useful trips
before depletion, pack/rebuild cost, cable recovery, loaded-cargo recovery, recommissioning time, and what
progress survives abandonment. A hero machine that never amortizes is a setup tax; one that is free to move
is disposable scenery.

Packing semantics are architectural invariants, not late polish: specify what happens to a loaded skip,
station buffers, extended cable, operating power/fuel, route references, and a player currently grappled to
the mechanism before accepting a persistence model.

---

## 4. Experience integration evaluations

### 4.1 Use three evidence tiers

1. **Deterministic harness — per commit.** Conservation, save safety, item ownership, machine states,
   routing, frame cost, and input correctness.
2. **Agent-play experience evaluations — milestone builds.** A playing agent receives only player-visible
   information; separate blind evaluators judge behavior, captures, and the action transcript against
   anchored rubrics.
3. **Human sessions — authority on fun.** Compulsion, fatigue, tactility, surprise, frustration, and
   willingness to continue cannot be certified by an agent score.

The project should define the experience evaluations now, but **not build another large harness subsystem
now**. Run the first versions manually from committed prompts and save evidence. Automate orchestration only
after two or three runs demonstrate that the evaluation finds useful differences.

### 4.2 Common protocol

Every experience evaluation must:

- run from a named commit, seed, save state, and player-visible settings profile;
- declare the actor's exact audiovisual feed, frame cadence, allowed controls, and any state unavailable to
  a human player;
- prove its required state before scoring, otherwise return `INVALID`, never zero or green;
- keep the acting agent blind to the intended solution and score;
- never name the evaluated bottleneck, desired emotion, or expected next action in the actor prompt;
- keep evaluators blind to the design documents and implementation intent;
- separate **observation**, **inference**, **confidence**, and **missing evidence**;
- register the director's prediction before the run;
- preserve video or ordered captures, inputs, world events, and actor statements;
- use at least two independent evaluators for subjective judgments;
- do not call evaluators independent when they share a model family, prompt wording, and transcript order;
- report a score vector, never one 0–100 headline;
- retain severe outliers instead of averaging them away;
- periodically calibrate agent judgments against human sessions.

### 4.3 Anchored scoring

Use 0–4 behavioral anchors rather than a freeform 1–10 feeling score:

- **0 — absent or contradicted.** The intended experience does not occur.
- **1 — prompt-dependent.** It occurs only after explicit instruction or evaluator charity.
- **2 — legible but inert.** The player understands it but forms no action or desire.
- **3 — self-directed.** The player correctly infers the issue and begins a reasonable response.
- **4 — generative.** The response creates a new plan, tradeoff, or voluntary optimization beyond the
  immediate repair.

A prompt evaluator should return structured fields such as:

```json
{
  "validity": "VALID | INVALID",
  "observed_evidence": [],
  "player_visible_cause": "",
  "inference": "",
  "score": 0,
  "confidence": "low | medium | high",
  "missing_evidence": [],
  "counterexample": "what would have changed the judgment"
}
```

The evaluator must cite moments in the recording or transcript. "It seemed fun" is not evidence.

### 4.4 Evaluation A — Desire formation / the "now what?" test

**Fixture:** Reach the first complete line naturally, clear transient tutorials, and provide no next
objective for 90 seconds.

**Actor instruction:** "Continue playing for up to 90 seconds. You may stop whenever you no longer have a
preferred action." Do not ask what the actor wants until after the run; that question itself manufactures
a desire. A post-run interview may ask what the actor believed it was doing, but prompted explanation is
scored separately from spontaneous behavior.

**Judge:** Whether the player forms a specific, world-grounded, actionable desire without recovering the
developer's intended task from UI.

**Score anchors:**

- 0: idles, stops, or asks for an objective;
- 1: follows residual instruction or performs arbitrary busywork;
- 2: notices a condition but does not form a plan;
- 3: names a bottleneck/opportunity and begins addressing it;
- 4: compares alternatives or voluntarily revises the factory.

This is the highest-priority subjective integration evaluation.

### 4.5 Evaluation B — Labor Retirement Integrity

**Fixture:** Record the manual task instances before automation, then play ten minutes after its solution
for the immediate check and a longer depletion/relocation session for maintenance burden.

**Judge:** Whether the exact labor is genuinely retired, and whether later related labor is qualitatively
different rather than the same action at a larger number.

**Veto:** If normal progression silently requires the original repeated task again, the feature fails
regardless of ceremony or throughput. Optional manual recovery does not fail the design unless it becomes
the normal efficient path.

**Score anchors:** 0 means automation adds maintenance without removing labor; 4 means the retired labor
stays retired and the freed attention creates a new kind of play.

### 4.6 Evaluation C — Bottleneck Legibility

**Fixture:** Under-supply or over-subscribe the Freight Winch without showing an explanatory alert.

**Actor instruction, detection run:** "Continue playing this save for five minutes." Nothing else. Score
whether the actor notices and responds without being told that a fault exists.

**Actor instruction, diagnostic run:** only after the detection run, ask: "Inspect the running system.
Describe what is happening, predict the cause, and change anything you think would improve it." This
second run measures comprehensibility after attention is directed; it cannot earn spontaneous-detection
credit.

**Judge:** Correct identification from piles, motion, sound, machine state, and spatial context; correctness
of the predicted repair; whether the actor succeeds without privileged state.

**Score anchors:** 0 means no problem is perceived even when prompted; 1 means prompted symptom recognition;
2 means spontaneous symptom detection but a wrong root cause; 3 means spontaneous detection, correct
diagnosis and repair; 4 means the player identifies a tradeoff or anticipates the next limit.

### 4.7 Evaluation D — Depletion and Relocation Freedom

**Fixture:** Deplete the active source in an ordinary generated world containing multiple discoverable sites
with different terrain and route costs; do not label an intended aesthetic-versus-efficiency tradeoff or
tell the actor to relocate.

**Judge:** Whether the player understands that moving or extending is viable; whether sunk cost feels like
an interesting constraint rather than a prohibition; whether progress survives abandoning spawn. Record
relocation completion, abandoned value, recovery time, stranded cargo, and stated regret after the action.

**Hard failures:** unique spawn dependency, irreplaceable machine, lost research, unrecoverable cargo, or a
required return to a depleted coordinate.

### 4.8 Evaluation E — Grapple Preservation

**Fixture:** Fork one save into pre- and post-winch variants with matched endpoints and terrain, including
one cargo trip and one personal trip; do not assume routes remain comparable after topology changes.

**Judge:** Whether cargo becomes predictable while the player still voluntarily uses grapple momentum for
speed, expression, or route choice.

Agent behavior can detect obvious replacement or pathing drift. Voluntary grapple use is not sufficient:
habit can preserve a verb after its pleasure disappears. Only human hands can rate expression, control,
route choice, desire to repeat, and whether post-winch movement remains pleasurable, so this evaluation is
advisory until human-calibrated.

### 4.9 Evaluation F — Hero Machine Causality

**Fixture:** Separate continuous clips of the Freight Winch starting, working, starving, and receiving
material, plus one wide full-route clip, all with labels hidden. Repeat key judgments with audio off and in
grayscale so sound and status hue cannot conceal weak silhouette causality.

**Blind questions:** What enters? What leaves? What part performs the work? Is it operating or stalled?
What changed in the surrounding world?

Score each answer independently. Do not ask whether the art is attractive until causal reading passes.

### 4.10 Evaluation G — Novelty half-life

**Fixture:** A 30–60-minute natural session with no injected inventory and no pre-dug route.

**Judge log:** timestamp each genuinely new decision, rule, consequence, or voluntary plan; separately log
repetition where the response is already solved.

**Result:** report the first five-minute window containing no new decision and the player's activity during
it. Do not convert event count into "fun": stable execution may be satisfying, and a language model may
invent endless verbal plans. Pair the log with human flow/boredom reports, voluntary continuation, and stop
reason. The useful output is where the mental model stops changing.

### 4.11 Evaluation H — Failure comprehension and recovery

**Fixture:** Create a reversible blockage, starvation, or later flood consequence without naming it.

**Judge:** Can the player identify cause, predict consequence, and recover without save reload or inventory
loss? Does recovery produce engineering or merely repeated labor? Humans additionally rate surprise,
frustration, perceived responsibility, recovery fatigue, fairness, and willingness to continue. Blockage,
starvation, and flood are separate fixtures, not one averaged score.

The target sentence is: **"My plan failed; I know why; I already have an idea for fixing it."**

### 4.12 Evaluation I — Pre-reveal demand

**Fixture:** Let the player perform the candidate manual transport job in a build that does not expose the
Freight Winch recipe, objective, silhouette, or name.

**Judge:** Whether the player independently complains about, avoids, redesigns around, or asks to automate
that transport. If the desire appears only after the winch is advertised, the machine is a supplied answer
rather than demand-pull.

### 4.13 Evaluation J — Construction and commissioning

**Fixture:** Give a first-time player the unlocked winch parts and a natural route problem, without a
placement objective.

**Judge:** Can they choose endpoints, understand the cable path, load cargo, read invalid placement, and
commission the first trip? Separate discoverability from execution difficulty; an objective rail that
places the machine for them invalidates the test.

### 4.14 Evaluation K — Payoff delight

**Fixture:** Record first startup, first loaded trip, acceleration, catch, unload, and the player's immediate
next thirty seconds.

**Human judge:** remembered image, desire to watch again, perceived weight, sound satisfaction, surprise,
and whether the event feels earned. Agent vision can flag composition and causality; it cannot certify
delight.

### 4.15 Evaluation L — Capacity appetite

**Fixture:** Present a naturally saturated one-skip route with at least two viable responses.

**Judge:** Does under-capacity create an interesting routing/capacity decision, or only the obvious tax
"build another identical winch"? A generative score requires a tradeoff among route, schedule, buffer,
capacity, or source placement.

### 4.16 Evaluation M — Accessibility and redundant state

Repeat commissioning, causality, and bottleneck diagnosis in grayscale, sound-off, reduced-motion, and
larger-UI profiles. Evaluate cable-motion comfort and ensure working, starved, blocked, and saturated states
do not depend on one channel.

### 4.17 Evaluation N — Long-tail network burden

**Fixture:** A mature save with several exhausted and active sites, stranded cargo opportunities, and more
than one winch route.

**Judge:** relocation frequency, packing friction, recommissioning time, recovery burden, route
comprehensibility, and whether the network feels like accumulated authorship or oppressive upkeep.

### 4.18 When to run these

- A–C: every milestone that changes the opening or Freight Winch loop.
- D–E: before accepting the Freight Winch as progression architecture.
- F: every major hero-machine art pass.
- G: before adding another material tier or stratum.
- H: before shipping any environmental punishment.
- I–J: before accepting the Freight Winch as the first major logistics payoff.
- K: before hero art is considered successful.
- L–N: before scaling beyond one winch route.

Do not run them on every commit. They are director/evaluation gates, not unit tests.

---

## 5. Director-level priority sweep

### Keep active

1. **Human observation (`PRIORITY` T0.1).** Still the true Tier 0.
2. **Lode cutover (`T1.6`).** Deposit depletion and extraction topology are foundations for a mobile freight
   network. Finish honestly; never merge its red 98.6 score.
3. **DIG stall (`T2.3`).** The manual verb must be tolerable before the player can appreciate retiring it.
4. **Rock/void legibility (`T3.1`).** The player cannot design routes through space they cannot parse.
5. **HUD subtraction (`T2.1`).** Preserve contextual guidance but stop the objective rail from manufacturing
   desire.

### Reframe immediately

1. **T1.1 Descent Engine → Freight Winch desirability/route prototype.** The Winch is the first major
   logistics payoff, not the external consumer. Preserve Descent Engine/Seal as candidates for the later
   world-facing appetite.
2. **T1.2 "first line retires ore haul" → staged labor retirement.** Extraction, logistics, and processing
   each retire their own previously experienced task.
3. **T1.4 "complete conversion inside 60s" → a human-tested pacing hypothesis.** Do not force production
   before the player understands its demand.
4. **T2.2 hero machine → Freight Winch as first hero machine.** Do not build hero art before the route is
   mechanically desirable, but design action and silhouette together.
5. **T4.4 fixed recurring Sinkforge structure → unresolved mobile/distributed macro premise.** A mandatory
   fixed coordinate conflicts with depletion, relocation, and player authorship.

### Move to backlog, do not delete

1. **T1.3 early waste-output machine.** Strong later complexity, premature before the simple logistics loop
   creates desire.
2. **T1.5 flood consequence.** Strong first environmental antagonist, but it should follow stable
   logistics and recovery language.
3. **Lighting grid, mobile rockbreaker, traveling foundry.** Retain as candidate consumers after the
   Freight Winch proves the progression shape. Descent Engine/Seal remains the leading candidate for the
   first later external consumer, but is not cleared for implementation.
4. **Full campaign lore and endgame.** Define constraints, not content, until the loop is human-proven.
5. **Catalogue-wide machine resprite.** Freight Winch sets the standard first.
6. **New subjective harness infrastructure.** Write and run the evaluations manually before automating
   them.

### Continue only on demand

All infrastructure debt in `PRIORITY` Tier 5 remains real. Pick it up only when it protects one of the
chosen changes above or invalidates evidence being used for a decision.

---

## 6. Immediate instruction to active agents

1. Finish or safely checkpoint an in-flight bounded change; do not discard work.
2. Read this brief before starting the next product item.
3. Do **not** begin the immediate Descent Engine from the old queue, the early waste machine, a fixed buried Sinkforge, or a
   60-second full-line rewrite from the old priority wording.
4. The lode cutover remains active foundation work, subject to its existing red vetoes.
5. Rock legibility and DIG performance remain valuable parallel lanes.
6. The Freight Winch is approved as the next major-logistics design target, not yet approved for blind
   implementation. First settle its actual manual task, endpoints, item flow, packing/relocation behavior,
   amortization, and interaction with the grapple.
7. Do not add an experience harness layer yet. Preserve evidence from manual prompt-driven runs and compare
   it with human sessions.

---

## 7. Decisions still requiring direction

These are the next five-option brainstorms, one at a time:

1. ~~What exact manual transport pain does the first Freight Winch retire?~~ **ANSWERED 2026-08-24.**
   *"The first Freight Winch retires repeated upward cargo hauling from a deep active face, using a
   relocatable trunk and receiver. It moves freight, not the player."* Ruling made against
   `docs/handoff/Q1_FREIGHT_WINCH_PAIN_OPTIONS.md`'s five-option brief (Option A — vertical ascent —
   selected, implemented with Option B's relocatable-route geometry as its constraint: the Winch serves an
   active, player-chosen trunk, not a fixed spawn structure). C, D and E explicitly deferred, not rejected:
   each depends on a system that doesn't exist yet at meaningful scale (a mobile construction front,
   recurring deep fuel/parts demand, concurrent multi-face extraction). Full ruling and its three requested
   implementation-brief additions are in `Q1_FREIGHT_WINCH_PAIN_OPTIONS.md`. Kept struck rather than
   deleted so the original five-option framing stays legible next to its answer.
2. Is its first route vertical lift, horizontal collection, or a junction between them?
3. What expansion parts or operating resources does it use without creating maintenance, and how many
   useful trips amortize one installation?
4. What can the player do physically with the moving skip and cable?
5. What later world-facing consumer gives the transported output purpose: Descent Engine/Seal, drainage,
   lighting, construction front, or another physical system?

The coordinate-independent campaign invariant is already decided. The exact meaning of **Sinkforge**—
machine, network state, mobile core, repeated node, or geological process—remains a later five-option
brainstorm.

The first question must be answered before an implementation spec is written.
