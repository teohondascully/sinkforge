# Q1 — what exact manual transport pain does the first Freight Winch retire?

UNTRACKED, like `docs/PRIORITY.md`. Written 2026-08-24 per the director's explicit permission to document
design alternatives and tradeoffs while `DIRECTOR_BRIEF.md` §7 Q1 remains open. **This is a brief, not an
answer.** Q1 is named a five-option brainstorm; this document tries to earn that shape rather than funnel
to one conclusion. Nothing here is a decision, and nothing here authorizes implementation.

## RULING, 2026-08-24 — Q1 ANSWERED

**"Choose Option A, implemented with Option B's relocatable route geometry."** The first Freight Winch
retires repeated vertical cargo ascent from an active extraction face to a receiver above. It is not a
fixed "send everything to spawn" structure — the player establishes a trunk near whichever face they
choose, moves laterally to that trunk, and the Winch handles the repeated upward haul.

> The first Freight Winch retires repeated upward cargo hauling from a deep active face, using a
> relocatable trunk and receiver. It moves freight, not the player.

Reasoning on record: real measured pain (ascent dominates and grows with depth); a strong expression of
"gravity matters"; compatible with relocating to better worldgen sites; preserves grappling as player
movement; a machine that visibly changes the world; a natural path toward later lateral routing without
overbuilding a logistics network up front. **C, D and E are deferred, not rejected** — each depends on a
system that barely exists yet: C needs a meaningful mobile construction front, D needs deep machines with
recurring fuel/parts demand, E needs concurrent multi-face extraction to be normal play.

**Three additions requested before this is an implementation brief** (added below, in their own section):
the exact manual action retired, the first visible payoff, and the failure/relocation rules.

**One more measurement requested before implementation, MEASURED 2026-08-24** — not because Option A lacks
support but because it decides where the Winch's lower endpoint should live: split lateral carry from
vertical ascent, across several seeds. Deferred once for the visual-work-first re-sequence, picked back up
once that sequence ran out of autonomously-actionable items. Result and full method in the "Evidence
against / open questions" note under Option B below, and in `docs/handoff/OVERNIGHT_RUN_STATE.md`'s
"Lateral-vs-vertical: answered" entry — short version: an 8-column lateral branch's walking-only lower bound
(174 frames, five seeds, stable) already lands inside the existing `climb_frames` reference range
(114-232), before excavation cost is even added.

## What's actually been measured, stated once so the rest of this doc can just cite it

`docs/handoff/T1_0_SINK_DESIGN.md` and `docs/handoff/LANE_B_PAIN_TEST.md` (both read in full for this
brief) plus this session's `aa7f8ad` (`tools/play_tests.gd`, `trip_frames` instrumentation):

- A capped pack (`PACK_BULK_CAP=90`) is real and reachable — `685646d`/`b0e3348` proved a fixture that
  fills it and completes multi-trip deliveries.
- **Trip count does not reliably create pain.** A 2026-08-20 three-seed measurement (memory:
  `director-brief-freight-winch.md`) found the same cap buys 1, 3–5, or 5–8 trips depending on how much of
  an ore body is exposed — geology sets the trip count more than the cap does.
- **Without a sink, a capped player goes permanently full rather than doing a repeated job** — one seed's
  101-unit face should buy two trips and buys one, because the player dumps at the spine, walks back into
  their own spilled pile, and auto-pickup refills the pack before trip 2 can mine anything.
- **A third of a capped pack is not freight.** On the measured rung, 90 bulk was `ore=60 earth=30`; the
  earth is granted kit plus incidental spoil, not cargo the player wanted to carry.
- **`trip_frames` (`aa7f8ad`, this session): climb/ascent cost dominates a capped trip and grows trip over
  trip** — `[197, 313, 318]` frames across 3 trips, climb share `58%→73%`, against a `134`-frame climb-only
  baseline from an unrelated deep rung. A 2:1 sink (e.g. a Forge) cannot touch this at all — it only
  reduces what's carried, and carrying is the smaller, shrinking share of the cost in this reading.
  **Caveat, not buried:** one seed, and the fixture that produced it isn't `T1_0_SINK_DESIGN.md`'s exact
  "configuration A" (peak 77 of 90, mixed cargo, not pure ore at peak 90). Directionally strong — later
  trips climbing from a deeper face is structural, not fixture noise — but not corpus-verified.

## Candidate options, cross-referenced against `DIRECTOR_BRIEF.md` §3.2's own list

§3.2 already names four candidate "natural problems" and flags one as more likely *as a hypothesis*. What
follows keeps that list's shape and attaches what evidence exists for each, so the five-option brainstorm
starts from where the project already is rather than from a blank page.

### Option A — Vertical ascent from a capped trip (climb-back-up cost)

**What it retires:** the repeated, growing cost of climbing out of a mine shaft under load, specifically
the way that cost gets worse the deeper the current face is.

**Evidence for:** the strongest evidence gathered so far — `trip_frames` directly measures this and shows
it dominating and growing. It also matches §3.2's own words: *"downward cargo already has gravity, chutes,
and galleries. The first differentiated use is therefore more likely to be upward movement... That remains
a hypothesis until players exhibit the pain before seeing the solution."* This reading is one such
exhibition, not the required human one.

**Evidence against / open questions:** single seed, wrong fixture (peak 77 not 90). Does the pain scale
with how the game is actually played, or only with this fixture's specific shaft geometry? A shallower,
wider dig pattern (more lateral, less vertical) would feel this pain much less — is vertical descent
actually how players approach ore, or an artifact of this rung's design?

**What would strengthen this into a real answer:** the corpus-seed version of the same reading (item 7 of
`T1_0_SINK_DESIGN.md`'s acceptance contract already asks for this, for a different reason — it could serve
both). Ultimately, T0.1 human observation, which the brief's own §5 keeps at "the true Tier 0."

### Option B — Horizontal-face collection into a vertical trunk

**What it retires:** carrying ore from a lateral dig (a face reached sideways off the main shaft) back to
the spine before it can even start the vertical trip.

**Evidence for:** named explicitly in §3.2. `T1_0_SINK_DESIGN.md`'s Forge-mouth analysis assumed lateral
relocation "is preserved" as a property of any bottom-consumer design, implying this is already treated as
a real axis of the problem, just not yet measured on its own.

**Evidence against / open questions — MEASURED 2026-08-24, updated in place rather than left stale.**
`tools/_scratch_lateral_split.gd`: a lateral branch OFFSET=8 columns off a main shaft, DEPTH=12, five seeds,
walking-only lower bound (tunnel pre-opened, excavation cost of the branch excluded) = **174-176 frames,
mean 174, dead stable across every seed**. Compared against the existing `climb_frames` reference
(`trip_frames`, `aa7f8ad`, three trips on a 24-deep face): `[114, 227, 232]`. **174 sits inside that range**,
closer to its low end than its high end, and this is a LOWER bound — the real cost, including digging the
branch, is higher still. **An 8-column lateral branch is already the same order of magnitude as a real
vertical climb, before accounting for excavation.** This doesn't overturn the ruling below (which already
commits to keeping the lateral walk manual) — it means that commitment was made without evidence lateral
cost is small, and now the evidence exists. Full methodology, including two earlier failed rig designs and
why they failed, in `docs/handoff/OVERNIGHT_RUN_STATE.md`'s "Lateral-vs-vertical: answered" entry.

### Option C — Deep processed goods to an active construction front

**What it retires:** carrying smelted/processed output from a deep processor back up to wherever the
player is currently building, which moves as the player relocates.

**Evidence for:** named in §3.2 as a candidate; connects naturally to §3.4's mobility requirements (no
fixed coordinate should own progress) — a winch serving a *moving* front is a stronger answer to "why does
this need to be relocatable" than a winch serving a fixed spine.

**Evidence against / open questions:** entirely unmeasured — no rung has modeled "the player relocates
their build site" as a variable. This is the most speculative of the five and the hardest to cheaply
falsify with a harness probe; it may need a human session before it's worth measuring at all.

### Option D — Fuel or parts moved upward against gravity

**What it retires:** feeding a deep operation (a drill, a pump, a deep-placed machine) with fuel or parts
that currently must be hand-carried down, trip after trip, to keep it running.

**Evidence for:** named in §3.2. Distinct from A–C in one important way: the pain here is *recurring
supply*, not *one-time extraction* — it doesn't go away as a face depletes, which makes it a different
shape of problem (steady-state logistics vs. a depleting-resource haul).

**Evidence against / open questions:** unmeasured, and depends on which machines actually need fuel/parts
deep underground today. A quick grep-level check (`src/core/factory_sim.gd`) found the premise is real but
weaker than it first looks: **generators burn coal and have no other fuel source, so they're a clean case**
for Option D. **But the deep-mining drill (`H_DRILL`) is explicitly designed to be self-sustaining** —
"bored COAL feeds its OWN fuel bunker first" (`factory_sim.gd:2447`) — so the machine most likely to sit
deep, where climb cost is worst, is also the one least likely to need the player to haul fuel down to it.
That doesn't kill Option D (generators still need it, and a player-placed generator could sit anywhere),
but it means the "fuel to a deep operation" story is stronger for power than for extraction, which narrows
what this option is actually about.

### Option E — Serving multiple faces from one processing room

**What it retires:** re-walking between several open extraction faces and one fixed processing point,
rather than the vertical climb specifically.

**Evidence for:** named in §3.2. Complementary to B rather than competing with it — this is about *routing
between many sources*, where B is about *one source's lateral offset from the spine*.

**Evidence against / open questions:** unmeasured, and depends on whether players in practice work one
face at a time or several concurrently — closer to a design/observation question than a harness question.

## What the measured evidence actually supports, stated plainly

**Option A has the only real measurement behind it right now, and it's a genuine, non-trivial finding: a
2:1 sink cannot address the dominant, growing cost of a capped trip.** That's a real constraint on the
Forge-mouth recommendation regardless of which option Q1 eventually selects — even if the answer is B, C,
D, or E, a partial ore-compression sink still can't touch vertical transit time on its own. Options B and E
are the cheapest to make equally rigorous (both are small, targeted extensions of instrumentation that
already exists). C and D are the least measured and most likely to need human observation (T0.1) before a
harness probe would even be measuring the right thing.

This is not a recommendation to pick A. It's a statement of where the evidence currently sits, offered so
the five-option brainstorm doesn't have to start from nothing.

## The three additions, 2026-08-24

### The exact manual action retired

**Climb from the active face to the receiver while carrying mined bulk.** In `trip_frames` terms
(`aa7f8ad`): the `climb_frames` bucket of each capped trip — the part measured at 58%→73% of trip cost and
growing as the face recedes. Not the descent, not the mining, not the lateral walk to the trunk (that's
Option B's axis and stays a manual, expressive action under this ruling — grappling to and around a face is
kept, not retired). Only the vertical return-with-cargo leg is being taken out of the player's hands.

### The first visible payoff

**Ore enters the Winch, rises through the shaft, arrives at a receiver, and becomes available without the
player making the ascent.** Concretely, against `_column_landing`'s three outcomes
(`docs/handoff/T1_0_SINK_DESIGN.md` §"the finding that reframes the question"): today, ore dropped with no
machine below becomes a re-collectable ground pile the player walks back into. The Winch's receiver is a
fourth outcome at the TOP of the trunk instead of the bottom — deposit at the face-side skip, and the same
ore is waiting at the receiver on the next surface trip, without the player having climbed for it. The
legible version of the payoff (per §3.5, "the bottleneck must be visible in the world") is: the player
digs, deposits into the skip, does something else (digs more, explores, grapples) while the skip travels,
and finds ore already at the receiver when they arrive — the climb they used to make now happens without
them in it.

### Failure and relocation rules

Drafted against `DIRECTOR_BRIEF.md` §3.4 (mobility) and §3.6 (failure/recovery), which this session read in
full before writing this — not invented independently. Proposed, not decided; the numbers in it (pack cost,
recommissioning time) are explicitly open per §3.9's own "define an economic envelope... before graybox
implementation."

- **The face depletes.** This is a property of the *source*, not the machine — the Winch does not enter a
  broken or alarmed state, it simply has nothing new arriving at its input. Matches §3.6: "a depleted
  source should become an understandable relocation problem, not a broken save." A player should be able to
  (a) extend the trunk laterally to a newly opened face nearby — the cheapest response, consistent with
  Option B's relocatable-route geometry, or (b) pick up the Winch head and re-place it near a new face, or
  (c) abandon it if neither is worth the cost. Which of (a)/(b)/(c) is cheapest is exactly the "pack/rebuild
  cost, cable recovery, recommissioning time" §3.9 asks to define before implementation — not answered here.
- **The trunk is obstructed** (new rock, a collapse, a player-dug change to the shaft geometry). Per §3.6:
  "a blockage should preserve items and expose its cause." The skip should stop rather than lose cargo,
  whatever it was carrying stays recoverable, and the stoppage should be legible at the blockage itself
  (matching §3.7's "status readable through motion and shape before color or text") — a stalled drum and a
  visibly obstructed shaft, not a menu error. Recovery is an ordinary dig-it-out verb, not a special repair
  tool, per §3.6's "maintenance must be a design decision, not incidental fuel chores."
- **The player moves to a new site.** Per §3.4: "no unique mandatory mechanism may exist only at spawn" and
  "progress should belong primarily to the player and their network, not a coordinate." A second Winch
  elsewhere must be buildable without the first one losing its value as a still-functioning trunk, and
  campaign progress (capability, unlocks, network reach — not a coordinate) must survive the player
  choosing not to return to the first site. This is the same invariant §3.9 step 7 already states as an
  acceptance condition for the prototype slice ("the player extends, moves, or abandons the source endpoint
  without losing campaign progress"); this ruling doesn't need to re-derive it, only confirm the Winch
  design doesn't violate it.
