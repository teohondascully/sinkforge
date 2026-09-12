# Sinkforge — the vision, and an invitation to break it

**Written 2026-09-12 for an incoming agent. Companion to
`docs/audits/2026-09-11-devin-onboarding-handoff.md`, which is the engineering handoff. That one tells
you how the machine works. This one tells you what we are trying to make, and asks you to attack it.**

**Pinned: `main` = `2a30e1ca`.**

---

## 0. What this document wants from you

Not agreement. We have plenty of that — this design has been argued mostly by the people who wrote it,
which is the worst possible peer review. What we want is the thing a cold reader can do that we cannot:
tell us which of these claims only *sounds* right.

Specifically, respond with:

1. **Counters.** Where does the logic not close? Name the step, not the vibe.
2. **Gap fills.** What must exist that no document here mentions? We are more worried about the things
   we have not thought to ask than the things we have got wrong.
3. **An audit** of five properties, each defined in §6: **pacing**, **narrative**, **the loop**,
   **addictability**, and **dimensionality**.
4. **Your own read** of the 5/10/20/40 ladders in §5 — where do they break?
5. **A verdict on §8's contradictions.** We know they are there. We want to know which way to resolve
   them, and why.

You are allowed — encouraged — to say a pillar is wrong. Two pillars have already been retired after
exactly that kind of argument (§8). The only thing we ask is that you argue from the documents and the
tree rather than from genre convention, because "most factory games do X" is the reasoning that produced
the parts we are least happy with.

**One framing rule, because it is the difference between useful and useless feedback here:** this project
does not lack *ideas*. It lacks *pressure on the ideas it has*. A response that adds five new mechanics is
less valuable than one that shows why the existing five do not compose.

---

## 1. The bar, and what it forbids

The whole design reduces to one sentence, from `docs/NORTH_STAR.md`:

> **Everything the player does to the world produces a physical consequence in the world, and that
> consequence is the whole explanation.**

The director's framing behind it: *"I'm more concerned about the entire Tiny Glade / Noita north star for
design feel and uniqueness. This game doesn't pass as 2026, it passes as 2016."*

Two hard consequences, both already enforced:

- **If the answer to a playtest finding is a new sentence on screen, it is the wrong answer.** Six
  batches of blind playtesters produced labels, rings, distance readouts and reworded lessons. Each fix
  was individually defensible; measured delivery went from 0-of-6 to 4-of-6. And the result was seven
  dark rounded rectangles on screen simultaneously, with "MOUTH" drawn on top of "FORGE". New HUD text
  of any kind is now permanently deferred.
- **The world explains itself by behaving.** We measured the opposite and wrote it down: *remove 42
  cells of earth in one blow → nothing. Undercut a mass of rock → it hangs. Cut the ground from under
  your own boots → you stand on air. Dig a hole → it looks exactly like a cave that was always there.*
  That table is what "2016" means here, concretely.

**Question 1 for you:** is that sentence actually achievable for a *factory* game? Tiny Glade has about
four verbs and no economy. Noita has no construction. We are claiming a game with throughput ratios,
fuel budgets and a demand economy can be as wordless as those. **We may be claiming something false.**
If it is false, we would rather know now than after another six batches.

---

## 2. Status — argue with the right things

The single most useful thing in this document. Confidence is not uniform and you should not spend effort
attacking a load-bearing constraint or defending a guess.

| Claim | Status | Where |
|---|---|---|
| Persistent single shaft, no reset | **LOCKED** | GDD §7 |
| One permanent surface rig as the standing consumer | **LOCKED** | GDD §7 |
| Material, not score — no currency, no shop | **LOCKED** | GDD §7 |
| Progress = demand *satisfied*, not material mined | **LOCKED** | GDD §7 |
| No combat, no enemies, no health bar | **LOCKED** | GDD §7 |
| R1 down is free / up is powered | **LOCKED** | GDD §4 |
| R2 deep material required, not more valuable | **LOCKED** | GDD §4 |
| R3 water is continuous upkeep, not a countdown | **LOCKED** | GDD §4 |
| R4 every tool tier removes one skill, adds another | **LOCKED** | GDD §4 |
| No global multipliers, ever | **LOCKED** (strongest prohibition in the doc) | GDD §2 |
| The Sinkforge is a stratum, not an object | **LOCKED** | GDD §7 |
| Three layers + the core | **LOCKED** | GDD §11 |
| The factory economy and machine set | **PROVISIONAL** — expect the first real session to revise it | GDD §5, §6, §12 |
| The three want-layers (Reveal / Flow / Pressure) | **HYPOTHESES**, confidence-marked | GDD §12 |
| Whether lateral variety survives one non-reshuffling world | **OPEN — the largest** | GDD §8 |
| Surface rig form (tower vs deck) | **OPEN** | GDD §8 |
| Machine retrieval before flooding | **OPEN** | GDD §8 |
| The bore lore (crust as gun barrel) | **PROPOSED, never signed off** | memory only |
| Per-layer physics twists as the antagonist | **AGREED 2026-08-07, then partly superseded** | §8 below |

**Everything in the bottom third is fair game. Everything marked LOCKED has an argument behind it in
GDD §9 ("Dead, and why"), and that section exists because several dead ideas are the obvious first
answer to a real problem.** If you want to reopen one, read its entry first and beat the actual
argument. That is not gatekeeping — we have reopened locked things before — it is asking you not to
spend a paragraph re-deriving a conclusion we already have written down.

---

## 3. The premise, compressed

You bore a shaft down from a permanent surface rig. You build extraction and routing *inside the shaft*.
You haul refined material back up to satisfy demands waiting at the rig. Satisfying a demand unlocks the
next capability, which is what lets the shaft go deeper.

**The terrain is the factory.** The shape you dig *is* the routing. An aquifer where you wanted your main
chute; a shale band eight tiles thick instead of two; ore forty metres further than the last vein. This
is the central identity claim.

Four things make it not-Factorio:

- **The spine.** A vertical factory is a sequence, not a plane. In Factorio, if two things need a belt,
  you build a second belt — space is free. Here everything shares a few vertical lines and contention
  *worsens with depth* rather than staying flat. We think this is the strongest mechanical asset in the
  design and it is currently **unexploited**.
- **Depreciation.** Water is always coming from below. Infrastructure past the pump wall has a lifespan.
  So every build is an investment question: *will this drill pay back its fuel before the water reaches
  it?* No factory game asks this, because their structures are permanent and therefore always worth
  building.
- **Labor.** Early, you *are* a machine in your own factory. Every second hauling is a second not
  building. The point of automation is firing yourself from your own supply chain.
- **Recipes are deliberately shallow and wide.** Three or four processing steps, maximum. Eight machines,
  not eighty. Depth comes from the three sources above, not from a recipe graph.

**Question 2:** we refuse recipe-tree depth and claim spine-contention + depreciation + labor replaces
it. That is a *big* claim and it is untested. Does it actually compose into twenty hours, or are we
describing three interesting hours and then a plateau?

---

## 4. The loop — and the thing we got wrong once already

Worth telling you as a story, because it is the best evidence about how this team fails.

The design had a macro-loop: *feed the rig*. It was coherent, it satisfied the economy, and it would
have shipped a game nobody played for more than an hour. The finding, written 2026-08-28:

> "Feed the rig" fires as a **transaction**: minutes apart, satisfying only at the moment of delivery.
> Between deliveries nothing pulls the player toward any particular next action, because nothing renews
> on a shorter cadence than the macro-goal itself.

The fix was not a new mechanic. It was noticing that **a want and a transaction are different objects.**
A want resolves and *regenerates on its own cadence*, independent of how far off the next delivery is.

The GDD's own line, which the director's phrasing in this request echoes: *the macro-goal does not have
to generate the wanting itself, any more than the ender dragon generates Minecraft's minute-to-minute
pull.*

So there are three want-layers under the macro-goal:

| Layer | The question it puts in front of you | Renews every | Status |
|---|---|---|---|
| **Reveal** | "what's behind this wall" | seconds | cheapest, under test now (`claims/C004`) |
| **Flow** | "that's jammed — fix it *now*" | tens of seconds | reframed, unbuilt |
| **Pressure** | "push deeper, or shore up" | minutes | open, most likely to be built wrong |

**The warning we wrote ourselves about Pressure, which we would like you to hold us to:** it only works
with **rhythm** — arrives, gets dealt with, recedes, grants a calm stretch. *Constant undifferentiated
pressure is not tension, it is nagging*, and it drowns the other two layers' claim on attention. Whether
water pulses or grinds is genuinely undecided, and the risk is that we build the grind version because
it is simpler to implement.

**Question 3:** three want-layers at three cadences is a tidy theory. Is it *complete*? Minecraft has at
least a fourth — *accretion*, the slow pleasure of a base getting nicer, which renews over sessions
rather than seconds. Do we have one of those, and if not, is its absence why nobody would come back on
day two?

---

## 5. The timelines

The director asked for 5 / 10 / 20 / 40. That doubling maps onto two different scales here and both
matter, so both are below. **Minutes** is the first-session arc, where the GDD is most specific and most
tested. **Hours** is the long tail, where it is mostly hypothesis.

### 5.1 The minute ladder — the first session

**These are targets, not descriptions. The build currently fails most of them and we know it.**

**At 5 minutes — the wordless demonstration.**
You move and dig with no tutorial text. You find a Forge that already exists in the world: cold, ancient,
a mouth on top, a chute out the bottom, **one fuel unit already burning and one ore on the ground beside
it.** You pick up the ore, drop it in the mouth, get an ingot, and the fire goes out. **Zero UI opened.**
The demonstration is a physical act you performed, not a message you read. Then you need both fuel and
ore and have neither.

*The design intent: the game's first teaching moment is a machine someone else left running, and its
last breath is the tutorial.*

**At 10 minutes — the discovery the whole design is built to produce.**
You haul fuel by hand. Fine once, annoying twice. Then you realise **you can dig a hole from the fuel
source down to the Forge's intake and let gravity do it.**

> That moment — discovering that a hole is a conveyor belt — is the single most important thing this
> design can produce. It cannot happen if routing is a purchasable machine. Free excavated routing is
> therefore not a convenience, it is the core. **Never place a tutorial prompt near it.**

Immediately after, the first logistics failure, and it is self-inflicted: fuel and ore down the *same*
hole, jamming the intake. Visible in the world as a physical pile, with an obvious fix.

**At 20 minutes — the first thing you build because you felt the pain twice.**
A second hole. A buffer. The rule: *no machine exists that answers a pain the player has not personally
felt, twice.* You start separating streams because you jammed one, not because a menu offered filtering.

**At 40 minutes — the shaft becomes a place rather than a hole.**
You have a route down, a route for material, and the beginnings of a reason to go back up. The first rig
demand is in sight. Hard rock is visible below and your hands do not work on it — the wall that turns
"dig deeper" into "build something".

**What we are least sure of:** the gap between 20 and 40. Reveal is renewing every few seconds, Flow
every few tens of seconds, but the *macro* payoff — a satisfied demand — may be twenty minutes away.
**Is minute 25 boring?** We think this is where a first-session drop-off would happen and we have no
instrument pointed at it.

### 5.2 The hour ladder — the long tail

From the GDD, marked explicitly as *"a worked sketch of how the curve should feel, for calibration only,
not specification."*

**Hour 1.** Hand-dig to the shale/rock boundary. Find the forge. Learn the hole trick. Feel the first
jam. Scrape together enough iron by hand, slowly, to satisfy the drill demand. **Hard rock stops being a
wall.**

**Hour 5.** A small automated line feeds the forge, but haul is still mostly manual — every trip up the
shaft is a *decision*, not a background process. Enough iron and copper cross the surface to satisfy the
pump demand. **The first section gets sealed dry.**

**Hour 20.** Several pump-walled sections. A fuel chute that is functionally the entire economy. A flood
event that costs real material when it wins — a drill wrecked into scrap, a section that has to be
re-dug rather than re-flooded. **You understand the fuel chain is the game.**

**Hour 40.** The intended shape of the far tail, and the least defensible part of this document. The
vertical column is still *employed* — deeper materials are new **inputs that still consume shallow ones**
(steel = iron + heat), so the whole column stays alive rather than becoming a strip-mined commute. The
Sinkforge is a **lighthouse**: a direction on the horizon, deliberately *not* a charge-bar you watch for
forty hours, because watching a bar demoralises. The ending is a **breach you assemble in a final act**.

**Question 4, and it is the one we would most like attacked:** *hour 40 is asserted, not designed.* We
have validated roughly **fifteen minutes** of real play. Everything past hour 1 is a paragraph of
argument. The "living column" claim in particular — that deeper recipes keep shallow layers employed —
is the load-bearing assumption of the entire long tail, and it is exactly the kind of claim that is true
in a spreadsheet and false in a session, because *nobody wants to walk back up*.

---

## 6. The five audits we want

Definitions, so your report and our reading of it are about the same thing.

**Pacing.** Does the density of decisions stay roughly constant as the shaft deepens, or does it thin
out? Specifically: the commute problem. At 200 m, how much of a minute is *traversal* rather than
*decision*? Factorio answers this with trains and personal roboports. Terraria answers it with the magic
mirror and a hellevator. **We have answered it with "the rope and grapple are the vertical traversal
primitive" and then not built them well** — the grapple currently reels 240 ticks for zero pixels
against a shaft lip. What *should* the answer be?

**Narrative.** There is no writer and there will not be one. The lore we have is proposed and unsigned
(§8). The question is not "what's the story" — it is **whether a game with no characters, no text and no
combat can carry forty hours of motivation on environmental fiction alone**, and if so, what carries it.
Our current answer is a silhouette: a growing tower above, a growing scar below.

**The loop.** Do Reveal / Flow / Pressure actually interlock, or are they three separate games running
on one screen? A specific worry: Pressure (water) *destroys* what Flow (routing) builds, and Reveal
(digging into the unknown) makes Pressure worse by opening more wet space. That could be an elegant
triangle or a punishment spiral. **We do not know which.**

**Addictability.** Deliberately the most uncomfortable one. This design borrows an idle game's
progression curve, and we have prohibited idle games' central tool (global multipliers) on aesthetic
grounds. So: what is the compulsion actually made of here? We think it is *craft* compulsion (Factorio's
"one more fix") rather than *number* compulsion (idle's "one more tick"). **If it is actually the latter
wearing a costume, we would like to be told.** There is also a values question we have not written down
anywhere: we are not sure we *want* the idle-game kind of hook, and we have never said so out loud.

**Dimensionality.** The director's word, and the sharpest of the five. A single vertical shaft is
structurally one-dimensional: one axis of progress, one direction of travel, one number that goes up.
Everything in the design that fights this is a deliberate counter-move:

- lateral search (ore forty metres *sideways*, not down)
- per-layer rule changes (a new **rule**, not a bigger number)
- two currencies with two doors (material→demands, artifacts→ruins) creating a second viable strategy
- the expedition (skip everything, sprint to a ruin at 140 m, trade a haul for a verb)

**Are those enough?** Or is this a game where, from ten thousand feet, you only ever do one thing? That
is the question we most want a cold reader to answer, because we are too close to it.

---

## 7. The inspirations — and why they are *actually* fun

The director's framing: pull out *why these games are really fun, i.e. not about the ender dragon.* For
each: the stated goal, then the real engine.

**Minecraft.** *Stated:* kill the Ender Dragon. *Actual:* a want that re-forms every 30–90 seconds —
"what's in that cave", "one more iron", "night is coming" — layered over slow accretion of a place you
made. Almost nobody who has played 200 hours did it for the dragon; most never fought it. **What we
take:** the cadence, and the principle that the endgame is a direction, not a motivator. **What we must
refuse:** infinite world as the answer to "what's new" — we have one shaft.

**Factorio.** *Stated:* launch a rocket. *Actual:* watching an imperfect system you built and knowing
exactly how to make it slightly better. The pull is **"that line's backed up"** — an itch generated by
the thing you already made, not by content someone authored. The rocket is a graduation certificate.
**What we take:** the self-generated itch — the factory manufactures its own problems. **What we refuse:**
planar routing and forty hours of recipe graph.

**Terraria.** *Stated:* beat the bosses. *Actual:* the world is dense with reasons to deviate. You set
out to mine and come back four hours later having built a house, fought a thing, found a chest, and
forgotten the mining. **What we take:** density of incident per metre travelled — this is the strongest
counter to our commute problem. **What we refuse:** combat as the incident generator.

**Noita.** *Stated:* reach the bottom. *Actual:* **the world is made of stuff and the stuff obeys rules
you can see.** Sand falls and piles. Water flows downhill. Burn a rope and what it held drops. You are
never told any of this and never need to be, because a single frame of the world behaving teaches it.
**What we take:** materiality, and the fact that identity is not pixel size or palette — it is that the
world *answers back*. **What we explicitly refuse, with an argument:** Noita's frictionless movement comes
from **flight**, which deletes ground friction rather than solving it. A flying player breaks R1 outright
— upward movement becomes free, lifts become pointless, the central asymmetry evaporates. Take the
material, refuse the flight.

**Tiny Glade.** *Stated:* nothing. There is no goal. *Actual:* **every input has a visible, immediate,
physical consequence, and the consequence IS the explanation.** You learn what a wall is by dragging one
and watching it thicken, sag around a rock, and grow a doorway where a path meets it. Almost no HUD,
almost no words. **What we take:** the entire teaching philosophy. **The honest catch:** Tiny Glade can do
this because it has ~4 verbs and no failure states. We have fuel budgets and throughput ratios. **This is
the tension at the heart of the whole north star and we have not resolved it.**

**Dome Keeper.** Structurally the closest existing game to ours: dig down, haul up, feed a persistent
thing at the top. *Actual engine:* a hard timer that makes every trip a gamble — *one more vein, or back
now?* **We have deliberately removed the timer** (R3 replaces a countdown with continuous upkeep). That
is a real loss and we should be honest about it: **we removed the thing that made the closest comparable
game tense, and our replacement is unbuilt.** If you attack one thing in this document, consider this.

**SteamWorld Dig 2.** The best-feeling dig platformer ever made, and our movement reference over Noita
and Terraria. *Actual:* traversal itself is the reward — each upgrade makes the *motion* better, not the
numbers. **What we take:** R4's shape (each tier changes the verb), and the principle that returning
through cleared space should feel like mastery rather than commute.

**Question 5:** we have cited seven games and taken something from each. **Is the synthesis coherent, or
have we assembled a creature?** The specific worry: Tiny Glade's wordlessness and Factorio's ratio depth
may be actively incompatible, and we may have written a north star that forbids the game we are building.

---

## 8. Contradictions we know about — tell us which way to resolve them

We would rather hand you these than have you find them and wonder if we are serious.

**8.1 The layer count and the antagonist model.** Two visions exist in our records.

- *2026-08-07, agreed enthusiastically:* **the environment is the antagonist.** Five iconic layers, each
  with a physics twist that is simultaneously a new toy and a new threat — Aquifer (water floods your
  shafts, flowing under gravity), Magma (heat cooks machines), Hollow (gravity flips, your conveyor logic
  inverts). The stated ambition was layers so iconic that *a community forms around them* — wikis, forum
  threads venting about the same levels.
- *2026-08-27, the current normative GDD:* **three layers plus the core** — Topsoil/shale, Stonereach,
  The Deep Works, then the Sinkforge. No Aquifer layer, no Magma, no Hollow. "Three layers authored well
  beats seven gestured at."

Both are defensible. They are not compatible. **The GDD wins today by being normative**, but nobody ever
explicitly retired the five-layer antagonist model, and the "one new *rule* per layer" principle — which
we think is genuinely good — came from the version that lost.

**8.2 Combat is dead in the GDD and alive in the older progression docs.** GDD §7: *"No combat, no
enemies, no health bar."* Older docs still carry a per-layer Guardian column and boss-gated capstones.
Our own memory notes the contradiction is *"knowingly left in place rather than resolved early."* It is
now a year stale in project time. **Resolve it.**

**8.3 The lore is proposed and unsigned.** The model: nobody manufactured a barrel — **someone bored a
shaft down through the crust and used the crust as the barrel.** Muzzle at the surface, breech at the
bottom, real geology between, which is why there is real ore in it. Each layer then hosts a system *for a
physical reason* — the coolant intake is at the water table because that is where the water is. And
**your factory becomes the missing crew**: these systems were built to be run by people who are gone,
your pumps *are* the coolant system. It is left open on purpose what the cannon fires, and at what.

We like this. It has never been signed off. **Is it worth making canon, or is the silhouette (tower up,
scar down) enough fiction for a game with no writer?**

**8.4 Persistence vs an ending.** The shaft is permanent and there is no reset. There is also an ending:
breach the Sinkforge. Factorio's rocket does not end the game. **What happens after the breach in a game
that has explicitly refused run structure?** We have no answer written anywhere.

**8.5 The idle hook fights the factory.** Offline processing is the return hook, capped at a few hours
deliberately *because uncapped offline production teaches players to wait instead of dig*. But it still
rewards absence in a game whose pleasure is presence. **Is a capped idle layer a hook, or a small,
constant instruction to log off?**

---

## 9. Fifteen questions nobody here has asked

Contributed by the session writing this, not drawn from the documents. Treat them as candidates, not
findings — several may be answered somewhere I did not look.

1. **The commute.** At 200 m, what fraction of a minute is traversal? Nothing in any document measures
   this, and it is the most likely quiet killer of the long tail.
2. **The strip-mine endgame.** One persistent shaft means the *interesting* terrain is consumed. Late
   game, you work in a wasteland of your own making. Minecraft solves this with an infinite world;
   Factorio with ore patches that scale outward forever. **We have no solution and I do not think we
   have noticed.**
3. **Day two.** The first session is specified beautifully, minute by minute. What is the *second*
   session's opening thirty seconds? A returning player faces a shaft they no longer hold in their head.
4. **Sound.** Not one design document mentions audio. For a game whose entire bar is "the world answers
   back", sound is at least half of the answer, and both cited north-star games lean on it heavily.
5. **Juice.** Every visual fix so far has been *static* rendering — palette, lighting, strata. Nothing
   addresses animation weight, easing, impact, screen shake, or the frame's response to a blow. **A lot
   of "2016" is motion, not colour.**
6. **The loss moment.** No combat, no death. Flooding wrecks machines into scrap. Is there any moment
   where a player feels they *lost* something? If not, does depreciation actually bite, or is it just
   slow accounting?
7. **Anxiety vs investment.** No reset plus permanent consequences can produce *investment* (this shaft
   is mine) or *anxiety* (I can never undo this). The same mechanic yields both depending on tuning.
   Which are we building, and how would we tell the difference before shipping?
8. **The zoom-out.** "Watch it thrum" — zoom out and witness your empire — is greenlit in our records
   and absent from the GDD. In a *vertical* factory, is the zoom-out even legible, or is it a tall thin
   ribbon nobody can read?
9. **Stories.** The stated ambition is a community that argues about layers. Communities form around
   *shareable stories*, which usually need either variance or failure. One deterministic shaft with no
   death may be structurally incapable of generating them.
10. **Difficulty.** Never discussed. A water system with no combat is either brutal or trivially
    avoidable, and which one is a tuning constant nobody owns.
11. **Can a factory game be wordless?** §7's unresolved tension, stated as a question. Factorio cannot.
    If we cannot either, the north star needs an explicit carve-out rather than quiet violation.
12. **Who is the player?** "An embodied engineer, not an omniscient factory planner." That is a camera
    decision. It is not yet a *character*, and we have no view on whether it needs to be.
13. **What does the rig want, emotionally?** Mechanically it is a demand queue. Is there any reason to
    care about satisfying it beyond the unlock? Factorio's science packs work partly because the rocket
    is *yours*.
14. **The second machine.** The first automation is free, dug, and brilliant. What is the *second* thing
    a player builds, and does it have anything like the same discovery quality — or is everything after
    the hole trick a downhill slope from the best moment in the game?
15. **Are we confusing "no multipliers" with "no growth"?** The prohibition is aesthetically right and
    mechanically strict. But idle curves *feel* good partly because the numbers move. If nothing ever
    multiplies, where does the sense of accelerating capability come from — and is "the same shape at a
    different scale" (GDD §10) actually true, or a comforting phrase?

---

## 10. What to send back

A document, against the pinned hash. Structure it however you like, but we want:

- **§6's five audits**, each with a verdict and the reasoning.
- **Your resolution for each of §8's five contradictions**, with a recommendation, not a survey.
- **Which of §9's fifteen are real**, which are already answered (say where), and which you would
  reprioritise.
- **The counters.** Every place the logic does not close. We would rather have ten sharp objections than
  a balanced assessment.
- **The gaps.** What is missing that none of this mentions.

Two things we do *not* want: a list of features to add, and a redesign. The design is not short of
ideas. It is short of pressure.

**And one specific request.** Somewhere in your response, answer this directly: *if you had to bet on
the single reason this game fails to hold a player for twenty hours, what is it?* We have our own
candidates — the commute, the strip-mine endgame, and minute 25 — and we would like to know whether a
cold reader picks any of them.
