> **Archived from `docs/DIRECTOR_BRIEF.md`, extracted 2026-08-26.** The Freight Winch product design and
> the 18-part experience-evaluation program (§4, referenced by `docs/EXPERIENCE_EVALUATION.md`); the
> priority-sweep and active-agent tactical sections were left in the untracked original since they key off
> a pre-pivot ticket numbering that no longer applies. This entire document describes future work — the
> Freight Winch is gated behind `sim/commands` and `sim/run` landing (see `sim/commands/MODULE.md`,
> `sim/run/MODULE.md`) and is explicitly out of scope for the current one-month vertical-slice push.
>
> **Path update, 2026-08-27:** "the untracked original" above now has an address —
> `docs/archive/DIRECTOR_BRIEF-postpivot-edit-2026-08-25.md`, moved there while closing the
> `.git/info/exclude` hole (ANVIL step 1). Same file, same extraction relationship; it just stopped being
> untracked.

# Freight Winch and experience evaluation — director's design brief

**Originally:** approved product direction, 2026-08-17.

## 1. The directive

SINKFORGE's operative identity is **kinetic industrial descent**:

> The player excavates their own topology, moves through it expressively by grapple and winch, and builds
> gravity-driven industry that permanently changes what their body has to do.

`Factorio × Terraria, with gravity that matters` remains useful ancestry and market shorthand. It is not a
substitute for a design test. The internal test is whether excavation, embodied movement, gravity logistics,
and automation cause one another.

The Freight Winch / Skipway is a player-placeable, relocatable cargo network whose moving skip carries bulk
goods between extraction sites, processing rooms, and construction fronts. It is the first major logistics
payoff that turns a player-dug shaft into infrastructure, and the first hero machine whose function and
state are readable without a nameplate.

## 2. The correction: "first automation" was carrying too many milestones

The prior direction compressed too much into one ceremony: retire labor, change the world, reveal a
bottleneck, and begin the factory game immediately. That risks teaching the completed answer before the
player has experienced the problems that make it desirable.

Factorio's developers describe the early order as: Manual mining → automated mining → automated logistics →
automated production and science. They explicitly say the order matters because every step automates
something the player previously did, allowing the player to understand and appreciate the upgrade. Their
attempt to force assembly into the first five minutes broke that progression badly enough that they
discarded a polished tutorial. (Source: Factorio Friday Facts #327.)

SINKFORGE should therefore name five different thresholds: first machine (extraction), first route (passive
logistics), first complete line (processing), first major logistics payoff (Freight Winch), first external
consumer (purpose — a later world-facing system depends on the transported output; a cargo mover is not
itself consumption).

### The Factorio lessons to retain

- Experience labor before automating it. Demand-pull requires felt friction, not an objective claiming
  friction exists.
- Teach one automation layer at a time. Extraction, transport, processing, and consumption are separate
  lessons.
- Consumption gives production purpose (Friday Facts #284).
- Recipes are curriculum: a progression recipe should require the systems the player is now ready to
  connect, not merely expensive ingredients (Friday Facts #275).
- The compulsion is a living bottleneck; an ending that exits it into "now what?" is a known failure
  (Friday Facts #187).
- Protect onboarding from worldgen without fixing the player's home (Friday Facts #258).

These are not instructions to copy belts or science packs. They explain the causal structure SINKFORGE's
own systems need.

## 3. Freight Winch / Skipway — product design

### 3.1 Player-facing promise

> Build a machine that takes bulk hauling out of your hands, then watch its moving cable turn the shaft you
> carved into infrastructure.

Three beats, not necessarily in the same ten seconds: **Liberation** (a repeated bulk-transport job is no
longer the player's job), **Consequence** (a drum, cable, counterweight, and skip begin moving through the
excavated world), **Hunger** (visible queues, empty destinations, or competing stops reveal that the first
winch is insufficient).

The winch is built where the player chooses, not a fixed relic at spawn.

### 3.2 What it transports

Cargo-first: predictable bulk movement between player-chosen endpoints. Prove one material flow before
becoming a universal inventory teleporter. Downward cargo already has gravity, chutes, and galleries — the
first differentiated use is more likely upward movement, horizontal-face collection into a vertical trunk,
or service between a deep processor and a changing construction front. That remains a hypothesis until
players exhibit the pain before seeing the solution.

The winch needs a downstream reason to exist — a modest later world-facing consumer remains required, or it
has not solved the post-line void.

### 3.3 Relationship to grapple movement

The winch must **transform** grapple play, not replace it. Cargo movement should be safe and predictable;
player movement should remain faster, riskier, more expressive. Riding the skip can be possible and playful
but must not become a safe elevator menu that deletes the shaft. The design fails if factory growth causes
players to use the grapple less because traversal has become a floor selector.

### 3.4 Mobility and depleted deposits

The world supplies resources and terrain; it does not dictate the canonical base coordinate. No unique
mandatory mechanism may exist only at spawn. Winch heads and stations must be packable, reproducible,
extendable, or cheap enough to abandon.

> The world may supply bones, but no coordinate may own the player's organs.

Campaign invariant: progress accumulates in player-owned capability and network reach; no unique coordinate
owns progression.

### 3.5 The bottleneck must be visible in the world

Input piles up while the skip is away; the destination waits empty; a heavily loaded skip moves differently
or takes longer; the drum, brake, and counterweight expose idle/starved/blocked/saturated; competing
stations make routing priority visible. Start with one skip, two stations, one material, and a visible
queue — enough to test whether the system generates a self-authored improvement desire.

### 3.6 Failure and recovery

A stopped winch must not strand the player. A depleted source should become an understandable relocation
problem, not a broken save. Recovering cargo must be possible manually, though less convenient. Buffers
should prevent constant babysitting. Target reaction: **"I see why it stopped, and I already know what I
want to change."**

### 3.7 The hero-machine standard

Designed from action outward: an unmistakable drum and cable silhouette, visible tension/braking/
counterweight motion, material visibly entering and leaving the skip, status readable through motion and
shape before color or text, a scale large enough to own a frame without filling the traversal space.
(Design principle source: Factorio Friday Facts #350 — apply the principle, not the art.)

### 3.8 Anti-goals

The first Freight Winch must not become: a player elevator that obsoletes grappling; a universal item
teleporter; a fixed spawn landmark; a static ingot payment disguised as machinery; an always-hungry chore;
an automatic miner that consumes the digging fantasy; a menu-driven scheduler before one physical route is
fun; the entire endgame premise before the opening loop is human-proven.

### 3.9 First prototype slice

1. The player performs the target haul manually enough times to understand it.
2. The player chooses two endpoints and installs one winch route.
3. The skip moves one real material without teleportation or item loss.
4. The player can grapple with or around the moving mechanism.
5. A deliberate under-capacity setup produces a visible queue.
6. With objectives suppressed, the player recognizes the queue and changes the route, capacity, or supply.
7. The source depletes; the player extends, moves, or abandons the source endpoint without losing progress.

Do not encode a "complete conversion inside 60 seconds" target as doctrine. Before graybox implementation,
define an economic envelope: expected deposit life, useful trips before depletion, pack/rebuild cost, cable
recovery, loaded-cargo recovery, recommissioning time, and what progress survives abandonment.

## 4. Experience integration evaluations

### 4.1 Three evidence tiers

1. Deterministic harness — per commit.
2. Agent-play experience evaluations — milestone builds, blind evaluators, anchored rubrics.
3. Human sessions — authority on fun.

Define the evaluations now; do not build another large harness subsystem now. Run the first versions
manually from committed prompts. Automate orchestration only after two or three runs demonstrate the
evaluation finds useful differences.

### 4.2 Common protocol

Every experience evaluation must: run from a named commit/seed/save/settings profile; declare the actor's
exact feed, cadence, and any state unavailable to a human player; prove its required state before scoring,
otherwise return `INVALID`, never zero or green; keep the acting agent blind to the intended solution and
score; never name the evaluated bottleneck or expected next action in the actor prompt; keep evaluators
blind to design intent; separate observation/inference/confidence/missing-evidence; register the director's
prediction before the run; preserve raw evidence; use at least two independent evaluators for subjective
judgments; report a score vector, never one headline number; retain severe outliers instead of averaging
them away; periodically calibrate against human sessions.

### 4.3 Anchored scoring

0–4 behavioral anchors: **0** absent/contradicted, **1** prompt-dependent, **2** legible but inert, **3**
self-directed, **4** generative (creates a new plan/tradeoff beyond the immediate repair).

### 4.4–4.17 The evaluations

Eighteen named, fixture-defined evaluations, lettered A–N (some subdivided):

- **A — Desire formation / "now what?"** Reach the first complete line, clear tutorials, give no objective
  for 90 seconds. Judge whether a specific, world-grounded, actionable desire forms unprompted. Highest-
  priority subjective evaluation.
- **B — Labor Retirement Integrity.** Is the exact labor genuinely retired, and is later related labor
  qualitatively different? Veto: if normal progression silently requires the original task again, the
  feature fails regardless of ceremony or throughput.
- **C — Bottleneck Legibility.** Under-supply or over-subscribe the winch with no alert. Detection run
  (unprompted), then diagnostic run (prompted to inspect). Correct identification from piles, motion,
  sound, spatial context alone.
- **D — Depletion and Relocation Freedom.** Deplete the active source; measure whether relocating/extending
  reads as viable, whether sunk cost feels interesting rather than prohibitive. Hard failures: unique spawn
  dependency, irreplaceable machine, lost research, unrecoverable cargo.
- **E — Grapple Preservation.** Fork pre/post-winch saves; does cargo become predictable while the player
  still voluntarily uses grapple momentum? Advisory until human-calibrated — habit can preserve a verb
  after its pleasure disappears.
- **F — Hero Machine Causality.** Blind clips (labels hidden, audio off, grayscale) of starting/working/
  starving/receiving. What enters, what leaves, is it operating or stalled — read before asking if it's
  attractive.
- **G — Novelty half-life.** A 30–60 min natural session; timestamp every genuinely new decision; report
  the first five-minute window with none. The useful output is where the mental model stops changing.
- **H — Failure comprehension and recovery.** Reversible blockage/starvation/flood, unnamed. Target
  sentence: "My plan failed; I know why; I already have an idea for fixing it."
- **I — Pre-reveal demand.** Let the player perform the manual job before the winch is exposed at all. If
  the desire appears only after the winch is advertised, it's a supplied answer, not demand-pull.
- **J — Construction and commissioning.** First-time player, unlocked parts, no placement objective. Can
  they choose endpoints, read invalid placement, commission the first trip unassisted?
- **K — Payoff delight.** Human judge only: remembered image, desire to watch again, perceived weight,
  surprise, whether the event feels earned.
- **L — Capacity appetite.** A naturally saturated one-skip route with ≥2 viable responses — does
  under-capacity create a real routing/capacity decision, or only "build another identical winch"?
- **M — Accessibility and redundant state.** Repeat key evaluations in grayscale/sound-off/reduced-motion;
  no working/starved/blocked/saturated state may depend on one channel.
- **N — Long-tail network burden.** A mature save, several sites, more than one route — does the network
  feel like accumulated authorship or oppressive upkeep?

### 4.18 When to run these

A–C: every milestone changing the opening or Freight Winch loop. D–E: before accepting the Freight Winch as
progression architecture. F: every major hero-machine art pass. G: before adding another material tier. H:
before shipping any environmental punishment. I–J: before accepting the Freight Winch as the first major
logistics payoff. K: before hero art is considered successful. L–N: before scaling beyond one winch route.
Director/evaluation gates, not unit tests — do not run them on every commit.

## Decisions still requiring direction

**What exact manual transport pain does the first Freight Winch retire? ANSWERED, 2026-08-24.** *"The first
Freight Winch retires repeated upward cargo hauling from a deep active face, using a relocatable trunk and
receiver. It moves freight, not the player."* Selected against a five-option brief: vertical ascent, with
relocatable-route geometry as its constraint — the winch serves an active, player-chosen trunk, not a fixed
spawn structure. Alternatives (horizontal collection, a junction between them, and options depending on
systems that don't exist yet — a mobile construction front, recurring deep fuel demand, concurrent
multi-face extraction) were explicitly deferred, not rejected.

Still open, whenever Freight Winch work resumes:

1. Is its first route vertical lift, horizontal collection, or a junction between them?
2. What expansion parts or operating resources does it use without creating maintenance chores, and how
   many useful trips amortize one installation?
3. What can the player do physically with the moving skip and cable?
4. What later world-facing consumer gives the transported output purpose?

The exact meaning of the Sinkforge itself — machine, network state, mobile core, or geological process — is
now settled elsewhere (`docs/GDD.md` §7, "a stratum, not an object"), superseding this document's open
question on that point.
