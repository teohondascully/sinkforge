# T1.0 — the sink: a design spike, not an implementation

UNTRACKED, like `docs/PRIORITY.md`. Written 2026-08-23 in Lane B under the director's parallel programme.
**Nothing here is built.** The deliverable is a recommendation and an acceptance contract; the sink and the
Freight Winch stay unimplemented until the recommendation is explicitly accepted.

## The finding that reframes the question

**A sink mechanic is not missing. Three landing outcomes already exist, and the trunk hits the wrong one.**
`FactorySim.drop_item` routes a dropped stack through `_column_landing`, which walks down the column and
returns the first of:

    a machine below        -> its `input_buffer`          the material leaves the world
    a solid floor          -> a re-collectable ground pile the material waits for you
    the bottom of the grid -> `sink`                       the material is gone

So *"the gravity trunk is not a sink"* is not a statement about a missing feature. It is a statement about
**what stands at the bottom of the trunk**: with no machine in the column, outcome two fires, the ore
becomes a pile, and the player walks back into their own delivery. The design question is therefore much
narrower and much cheaper than "build a sink", and the rest of this document is about which consumer earns
that position rather than what a consumer would be.

**And the game already contains a true terminal sink.** `_run_descent`: the Descent Engine eats
`DESCENT_EATS = &"ingot"` up to `DESCENT_QUOTA = 64`, adds them to `total_consumed`, and never returns
them. It is real, it is shipped, and it is **temporary by design** — past its quota it passes ingots
straight through to its output buffer. It is a gate, not a permanent destination.

## The arithmetic that decides the comparison

`is_bulk_item` returns **true by default**. Only tools and placeable machines are exempt. So an ingot costs
pack space exactly like ore does, and "smelt it before you carry it" is only a saving where the recipe
compresses:

| consumer | recipe | in : out | effect on the haul |
|---|---|---:|---|
| Forge (`processor`) | `smelt_ingot` | 2 ore : 1 ingot | **halves** the bulk |
| Iron Forge | `smelt_iron` | 2 iron : 1 iron_ingot | **halves** the bulk |
| Blast Furnace | `smelt_rich` | 1 rich_ore : 2 ingot | **doubles** it |
| Descent Engine | n/a | 64 ingots : nothing | **terminal**, then inert |
| Hopper | none | pass-through | **none**; it is a queue |

**The Blast Furnace is an anti-sink and that is not a defect.** It is a value multiplier and it is correct
as designed. It is listed because putting it at the bottom of a trunk to "process the ore" would make the
carrying problem strictly worse, and the mistake is available to a player and to us.

## The five options against the director's criteria

Read the first column as "what physically consumes the material", which is the criterion that separates
these more than any other.

### 1. Hopper

**Consumes nothing.** `_run_hopper` releases at `HOPPER_RELEASE` into whatever it feeds; `recipe = null`.
Transfer is visible and it is a good mouth. It preserves lateral relocation and survives depletion
trivially because it holds no world position of its own. **But it is a queue, so the material still exists
and the player can still take it back**, and a full hopper backs pressure up the trunk. It is the cheapest
thing to build and the only one on this list that does not answer the question. **Reject as the sink;
keep as the mouth in front of one.**

### 2. Furnace / Forge mouth

**Consumes: 2 ore per ingot, permanently, into `total_consumed`.** This is the strongest candidate and it
is already shipped. The transfer is visible (the Forge's own working animation and its status line), the
material leaves the floor, and what comes back is half the bulk and sitting in a machine's output buffer
rather than lying on the ground in the player's path. Lateral relocation is preserved: the Forge sits at
the spine, and the face can move as far as it likes. Depletion does not break the route because the Forge
does not care where its ore came from. A different worldgen location changes nothing.

**Its weakness is honest and should not be papered over: it is a HALF sink.** 90 bulk of ore becomes 45
bulk of ingots, which the player can collect and carry. If the Freight Winch's payoff is "the trip stops
existing", a half sink makes the trip half as frequent rather than unnecessary.

### 3. Machine intake generally

Any consumer with a compressing recipe is a sink by the same mechanism; the Forge is the instance of it
that exists at the depth the opening route reaches. **This option is not distinct from 2 in mechanism, only
in which machine.** Recorded so the comparison is total rather than to be chosen.

### 4. Storage receiver

Does not exist and would be a hopper with a bigger mouth. **Consumes nothing.** It converts "walk into your
own pile" into "walk into your own chest", which is a tidier floor and the same loop. It also introduces the
one failure mode this design cannot recover from gracefully: a full store with a queue behind it, at the
bottom of a shaft, with the player at the top. **Reject.**

### 5. Gravity-fed processing structure

The Descent Engine is this, already built, and it is the only true terminal sink in the game. Its behaviour
is exactly right for the feeling T1.0 wants — you feed it and the material is *gone* — and its quota is
deliberately a throughput wall rather than a toll: 64 ingots is 128 hand-mined ore, which the comment at
`factory_sim.gd:154` says is punishingly slow by hand and passive with an automated line. **That is the
Freight Winch's payoff already written down in the sim.**

**But it is a gate, and a gate consumed is a gate opened.** Past `DESCENT_QUOTA` it passes ingots through
and stops being a sink. A permanent version would need either a repeating quota or a different consumer,
and inventing one is a change to gameplay intent.

### 6. Explicit collection basin

Named separately by the director and it is worth separating, because the obvious reading of it is option 4
with better fiction and the interesting reading is not.

**As a container it consumes nothing** and inherits every objection to the storage receiver: the material
still exists, the player can still take it back, and a full basin at the bottom of a shaft with the player
at the top is the one failure mode this design cannot recover from gracefully.

**As the trunk's designed terminus it is the only option here that is new.** A basin that does not HOLD but
DISTRIBUTES, routing what lands in it to whichever consumer the factory currently needs, moves the material
out of the player's problem and into the factory's without needing a recipe of its own. That is a
meaningfully different claim from "put a Forge at the bottom": it survives the Forge being full, it
survives the Forge not being the right consumer yet, and it gives the trunk a mouth that reads as
infrastructure rather than as a machine that happens to be standing there.

**It is also the most expensive thing on this list**, and the cost is coupling rather than lines. Routing
needs a destination policy, and this codebase already has one in the conduit and spur network; a basin that
invents a second policy is a second thing to keep true. **The honest version of this option is "extend the
existing distribution network to accept a gravity drop", not "add a basin".** That framing should be tested
against the recommendation below rather than instead of it.

## The six against the pain, in one table

The criterion that matters most is the last column, because T1.0 is a feel row and not a throughput row.

| option | pain it retires | what stays manual, on purpose | how the payoff is physically felt |
|---|---|---|---|
| hopper | none; it is a mouth | everything | nothing changes |
| Forge mouth | the return trip carries half as much | walking the face-to-spine leg | the pile stops being on the floor |
| machine intake | same as the Forge | same | same |
| storage receiver | none; a tidier floor | everything | nothing changes |
| Descent Engine | the material is GONE | feeding it, until a line does | the seal breaks and a new layer opens |
| collection basin | the spine accepts anything | choosing what to mine and where | the trunk reads as infrastructure |

**Only two rows retire anything, and one of them expires.** The Descent Engine is the strongest feeling in
the list and it is a gate: past `DESCENT_QUOTA` it stops being a sink. The Forge is permanent and partial.
That pair is the whole design space that currently exists, and it is why the recommendation below is to
measure the partial one before building a permanent full one.

## Recommendation

**Do not build a new sink. Place the Forge at the bottom of the trunk and measure whether a partial sink
is enough, before anyone designs a full one.** *(Amended 2026-08-23: this said "a half sink". The
measurement says a Forge saves a third of a real trip rather than a half, because a third of the pack is
spoil the recipe never touches. The recommendation is unchanged and its expected payoff is smaller.)*

**AMENDED AGAIN, 2026-08-24 — the `trip_frames` reading this document's own §5 decision table asked for
now exists (`docs/handoff/LANE_B_PAIN_TEST.md` §5, `docs/handoff/OVERNIGHT_RUN_STATE.md`'s dated entry for
today), and it argues against proceeding with this recommendation as written, not for it.** Climb/ascent
cost dominates and grows trip-over-trip (58%→73% of trip cost across 3 trips, one seed, one non-canonical
fixture) as the mined face recedes deeper within a fixed shaft. A 2:1 Forge compression cannot touch climb
cost at all — it only reduces what is carried, and carrying is now the smaller, shrinking share of each
trip's cost. **This recommendation is NOT withdrawn — the reading has real caveats (wrong fixture, one
seed) and is not the corpus-verified measurement contract item 7 wants — but it should not be acted on
(no Forge fixture, no acceptance-contract items 2-8) until `docs/DIRECTOR_BRIEF.md` §7 Q1 is engaged.**
That question — "what exact manual transport pain does the first Freight Winch retire?" — is where this
finding actually belongs; it is a candidate answer (climb-back-up cost, growing with depth), not a
resolution of it.

**Q1 IS NOW ANSWERED, 2026-08-24, same day — this paragraph's blocker is cleared, but the tension it raised
is not, and that is a new open question rather than a resolved one.** `docs/DIRECTOR_BRIEF.md` §7 Q1:
*"The first Freight Winch retires repeated upward cargo hauling from a deep active face... It moves
freight, not the player."* Ruling made, Winch graybox shipped (`3222939`, `9c6bb42`). **Read against this
paragraph's own finding rather than past it**: the Winch is explicitly scoped to move FREIGHT, not the
player — so a player who descends to a face the Winch serves still climbs themself, by the same
`trip_frames` mechanism this paragraph measured, and the Winch does nothing to the share of trip cost that
was found to be growing (58%→73% across 3 trips) and immune to bulk-reduction. **Whether the shipped Winch
design actually retires the pain this document measured, or leaves it standing beside a solved freight
problem, has not been checked and is not something this document can settle by itself** — it needs either a
re-run of the `trip_frames` rung against a world with a working Winch route, or an explicit director read on
whether "moves freight, not the player" was already understood to leave climb cost untouched by design.
Recorded rather than assumed either way, per this document's own standing rule.

The reasoning is that every option above that is a true sink already exists, and the one gap is whether 2:1
compression converts a trip into a job. That is a measurement, it is cheap, and the answer decides whether
the remaining design work is "nothing" or "a permanent terminal consumer". Designing the permanent consumer
first would be answering a question nobody has asked yet, which is the error `T1.1` is already parked for.

## RESOLVED, 2026-08-24 — no Forge at the trunk bottom for the first Freight version

**The director ruled directly, not gated on the re-run the previous section asked for: no Forge at the
bottom of the trunk for v1.** Rationale, as given: the Forge only reduces carried bulk (§"A THIRD OF THE
CAPPED PACK WAS NOT ORE" above — a 2:1 recipe compresses the ore third of the pack, not the whole load),
while `trip_frames`' own finding is that climb cost is the dominant AND GROWING share of a manual trip
(58%→73% across 3 trips). A Forge cannot touch that share at all. For v1: raw ore enters the Freight Head
at the face: the Winch removes the repeated climb, and processing happens at top-side receiver
infrastructure instead of at the bottom of the shaft. Revisit only if later evidence shows payload volume,
not vertical movement, is the bottleneck.

**This also closes the open question the previous section left standing** ("whether the shipped Winch
design actually retires the pain this document measured... has not been checked"). It has now been checked,
as confirming evidence for the director's call rather than as the gate it was waiting on
(`tools/_scratch_winch_climb_measure.gd`, one-off scratch rig, same fixture/seed/column as the `trip_frames`
reading — seed 1337, column 40, a 24-row ore face at depth 24):

    SETUP (one-time): descend=314 climb=464 total=784
    RETURN AND FEED: return_descend=117 target_mined=true fed=45 (deposited=true) head.input_buffer.ore=103
    CLIMB-COUNTER CROSS-CHECK: agent.frames after the return-and-feed pass=470, expected (setup climb only)=470, delta=0
    DELIVERY: 24 ore reached the Station's input_buffer after a 270-frame wait, zero further player travel

Two things this actually establishes, stated plainly rather than rounded up:

1. **The one-time setup cost (784 frames: one descend, one climb) is not cheaper than a single manual trip**
   (`trip_frames=[197,313,318]`, `aa7f8ad`). It is larger than any one of them. The Winch's value is not a
   cheaper first trip — it is that the setup is paid ONCE, and every trip after it costs the player nothing
   in climb frames at all, however many trips' worth of ore later flow through.
2. **`agent.frames` is a climb-only counter by construction** (`aa7f8ad`'s own finding — every `step()` call
   site lives inside `climb_to_surface`). The cross-check above descends back to the face (real movement,
   through the already-open shaft), mines the one remaining ore cell, hand-feeds the Head again, and waits
   out a delivery — a full return-mine-feed-deliver cycle — with `agent.frames` unmoved: zero additional
   climb frames were spent anywhere in that cycle. This is proof the shipped Winch design does retire the
   pain `trip_frames` measured, not an assumption from the absence of a climb call in the rig.

**A real bug this measurement surfaced and fixed in passing, not itself the point of the rig:** the first run
of this script found that a player cannot hand-feed a Winch Head at all — `try_drop()`'s reachable-eater scan
gates on `FactorySim.machine_eats()`, which had no case for `winch_head` (its `MachineDef.recipe` is `null`,
so the catch-all `recipe != null and recipe.inputs.has(item)` was always false for it). `_run_winch_head`
itself is item-agnostic — it hauls whatever sits in its own `input_buffer` — and the Winch's own design doc
(`docs/handoff/FREIGHT_WINCH_GRAYBOX_PLAN.md`) names "hand-drop" as a supported feed path. The only existing
harness coverage (`_goal_freight_winch_delivers`) never caught this because it injects ore straight into
`input_buffer` through the setup hatch, bypassing `try_drop`/`machine_eats` entirely. Fixed in
`src/core/factory_sim.gd`'s `machine_eats()`: a `winch_head` now accepts any `is_bulk_item` item (the same
classifier `PACK_BULK_CAP` already uses, so tools, bits, rope and other machine items stay excluded — a
mis-aimed toss cannot freight away carried equipment). Verified against the full 115-layer harness sweep
plus this rig, both clean.

## THE BLOCKER IS CLEARED, 2026-08-23, and the answer moves the question

The paragraph that stood here said the measurement was still the blocker: *"no friction rung fills the
pack. The heaviest reaches 38 bulk against a cap of 90."* **That is no longer true and it is kept only as
the thing that was repaired.** `685646d` added an ore-bottomed shaft, forty deep, thirty rows of ore at
three units each on top of a granted twenty:

    PEAKBULK=90 HANDED=20 MINED=70   room_at_end=0   down=true up=true   frames=361 stuck=2
    peak carried: ore=60 rope=50 earth=30 wood_pickaxe=1                 rope_left=8

### The headline: A CAPPED TRIP IS A SECOND TRIP, NOT A TRAP

The first run of that rung read `up=false stuck=128` and looked exactly like the cap stranding a player at
the bottom of their own shaft, which would have been a far more serious finding and a different design
problem. It was not. A control at four ore rows, nineteen bulk short of the cap, printed the SAME
`mines=41 places=11 jumps=2 frames=394 stuck=128`: every driver number identical while the load differed.
The rung had granted twenty-five rope for a forty-deep shaft and `place_rope` spends one unit per segment,
so the body rode to the top of its own hang and stalled. **Provisioned properly, ninety bulk climbs forty
rows and surfaces.** The cap charges trips. It does not strand.

### Two facts the measurement turned up that bear directly on the recommendation

**1. The climb is exempt from the cap; only the freight is charged.** Fifty rope rode down and back with a
pack that was already at ninety, because `is_bulk_item` exempts placeable machines. Forty-two segments were
spent on the round trip. So the cap never taxes the infrastructure that makes depth survivable, only the
reason you went down. That is a coherent design and it is worth stating out loud, because it means a sink
changes trip count and nothing else: it cannot make the descent itself cheaper.

**2. A THIRD OF THE CAPPED PACK WAS NOT ORE.** The ninety was `ore=60 earth=30`. Twenty of that earth was
the granted pillar-jumping loadout and ten was picked up on the way down. **Spoil and building material
compete with freight for the same ninety.** This is the number that most changes the arithmetic above:

    a 2:1 Forge at the bottom compresses the ORE HALF only
    60 ore -> 30 ingot, and the 30 earth is untouched
    the trip carries 60 instead of 90, a saving of a THIRD, not of a half

The payoff table earlier in this document says the Forge *"halves the bulk"*. That is true of the recipe
and **false of the trip**, on this rung's composition. Read it as a recipe ratio, not a haul ratio.

**Frame for both.** One rung, one seed, one loadout, chosen to make the cap bind. The earth fraction in
particular is partly an artifact of granting twenty earth for the pillar fallback, and a player who
descends on rope alone would carry less of it. The direction is solid, the magnitude is one sample.

## Acceptance contract

The sink is accepted as solved when all of these hold. Any one of them failing sends the design back rather
than lowering the bar:

1. **A friction rung exists that fills the pack. CLOSED at `685646d`.** It reaches `PACK_BULK_CAP` and
   hauls the full load back to the surface. Both of its assertions have a demonstrated negative, so
   neither passes by construction: `filled` is false at four ore rows, `up` is false at twenty-five rope.
   **And trips landed too, at `b0e3348`:** a 25-cell face holding 280 units takes TWO trips, 68 delivered
   then 43, with `produced 111 = delivered 111` and nothing spilled. Cost-per-trip and trips-per-face are
   one measurement now rather than two that never met.

   **Both numbers are ONE SEED.** The hand share reads 24.3% on one face and 39.6% on another, and the
   trip count is a single run. Item 7 of this contract asks for three corpus seeds, and a payoff argument
   built on one seed is a frame nobody named. Re-measuring across the corpus is queued.
2. **A delivered load does not return to the player's path.** After a full-pack delivery, the floor of the
   trunk column holds no re-collectable pile, measured through `_column_landing`'s outcome, not by eye.
3. **The bulk returned is strictly less than the bulk delivered**, and the ratio is stated, not assumed.
4. **The player can see the transfer.** The consumption is legible as an event at normal scale, judged from
   a capture, not from the fact that a counter moved.
5. **Lateral relocation survives.** Moving the extraction face away from the spine does not require moving
   the sink, and this is demonstrated with the face at two different offsets.
6. **Depletion does not strand the route.** A face that runs dry leaves a working sink and a reachable
   alternative, rather than a structure with nothing to eat.
7. **A different worldgen seed does not invalidate the arrangement.** Checked on the three corpus seeds,
   not on the one it was designed against.
8. **The failure mode is recoverable by a player.** A backed-up or starved sink is legible and can be
   cleared with ordinary verbs from where the player stands.

**Not accepted by this document, and explicitly out of scope:** any change to `DESCENT_QUOTA`, any new
machine, any recipe change, and the Freight Winch itself. Those are gameplay intent and need the director.
