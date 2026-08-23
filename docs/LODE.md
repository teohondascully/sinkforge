# THE LODE — ore lives in the wall, and mining stops being a trap

> **Status: PHASE 1 SHIPPED as STRIKE 38, PHASE 2a as STRIKE 39, the STARTER POCKET as STRIKE 40
> (2026-08-16); 2b-4 SPEC.** The lode layer, the hand-work
> verb, the vein-in-the-wall rendering and the trap being gone are in the game — `FactorySim.lode` /
> `take_lode` / `lode_fraction`, `MainView.try_work_lode`, `WorldRenderer._draw_lode` and the lode's entry
> into `_wall_base_color` — held by `tools/check_lode.gd` and photographed
> at `history/118-the-vein-outlives-the-blow.png`. Ore is still authored SOLID by the generator in the BLOCK
> plane and converting it is phase 3b — but as of 2026-08-17 the generator also seeds a separate LODE plane,
> so "a generated world contains no lode" is no longer true. **§5's Drill Head shipped as #S39** — a drill placed ON a lode drains it in place and pours
> down its own column, held by `tools/check_head.gd` and photographed at
> `history/119-stand-it-on-the-thing-it-eats.png`. The Spur is 2b.
> Migration plan, blast radius and eval gate: `docs/LODE_PLAN.md`.
>
> **Recorded deviations so far.** **A lode is painted by the WALL BAKE, not by an overlay.** Three cuts were
> needed to learn why: a filled rect with a rim read as a poster stuck on the rock, soft blobs read as smoke,
> and routing it through `_wall_base_color` — the single authority the fine-terrain bake already uses — made
> it inherit the molding, bedding, recess shadow and veil every other wall gets, which is the thesis
> implemented literally rather than a trick. **And the wall is STAINED, not tinted the ore's colour.** An ore
> block's matrix is within a hair of stone's (ore reads as ore because of its pale flecks), so painting the
> wall the ore's own base colour is exactly correct and completely invisible; the wall is now the rock
> carried 42% of the way toward the metal, which derives per material — coal stains dark, iron rusty.
> **…but it stains in HUE, not in VALUE.** Ore's nugget is pale (v 0.85) against its matrix (v 0.34), so a
> 42% stain of the raw colour brightened the wall by 62% and a carved pocket came out LIGHTER than the rock
> around it — reading as more rock rather than as a hole with a face at the back of it. §11 already names the
> rule that breaks: brightness carries ATTENTION. The mix now sets what the wall is made of and the host rock
> keeps the say over how lit it is.
>
> **A vein's fullness is measured against ITSELF.** `lode_fraction` first read remaining units against
> `DEFAULT_ORE_DEPOSIT`, which answers *how rich is this vein compared to a standard one* when the picture has
> to answer *how much of THIS vein is left*. They come apart badly at the small end: the starter pocket holds
> 45 units, untouched, and drew one fleck in six — a fresh vein that looked stripped, on the first face a new
> player ever sees. `lode_max` records what each lode held when it was opened. **Extent carries richness (a
> big body covers more wall); density carries depletion.**
>
> **THE STARTER POCKET (#S40).** Every spawn opens with a small sealed cave a step under the surface, an ore
> lode showing in its back wall, and the same vein continuing richer behind the rock below it — the guaranteed
> first FACE, standing up before the generator learns to build one. The shape took three tries and both
> failures are load-bearing. It was **impassable**: it stepped down one row per column without keeping the row
> above open, so the body (34px against a 32px cell, always two rows) met rock with its head at every step,
> and the harness called it a corridor because the sim only asks whether the FLOOR is clear. And it was
> **open to the sky**, which took four playthrough layers down at once — twice, in two different columns. The
> plateau's surface is not spare ground: it is the corridor the opening walks AND the runway every motion
> fixture measures on. So the cave is SEALED and visible anyway, because this game draws the ground it has not
> dug. Getting in costs one swing at the roof, which is the whole of this document in one blow.
>
> **Original spec (2026-08-16).** Opened by one question — *"is having ores that you put drills under
> still valuable? it's odd that you can mine an ore and it disappears, but you can drill an ore and it might
> have 400 deposit."* It is odd, and chasing it down found a real contradiction at the centre of the loop
> rather than a balance wart. Provisional and reversible; numbers are placeholders that want play.
> **This deliberately overturns the oldest system in the game** — see §7. Pairs with `docs/DRIFT.md` (the
> Drift Rig gets re-sourced by this, §6) and `docs/BITS.md` (this is what the bit set is FOR, §4).

## 1. The contradiction

One cell is currently **both terrain and resource**, and two verbs act on it with wildly asymmetric returns.

| verb | what you get from one ore cell | what happens to the cell |
|---|---|---|
| `mine()` by hand | a **3–6** loose burst | destroyed, and `deposits.erase(cell)` throws the rest away |
| a drill above it | **250** (seeded: hundreds near spawn, thousands deep) | drained one unit at a time, then bored through |

`factory_sim.gd`'s `mine()` is explicit about the intent — a hand strike "clears the whole block in one
strike and pockets a 3-6 burst of loose ore", and "the block's larger latent yield in `deposits` is NOT
hand-extractable: a drill placed ABOVE a visible vein bores DOWN through the solid ore". That reads fine as a sentence and plays terribly as a
rule: **swinging your pick at ore is the single most destructive act in the game, and nothing tells you.**
A player who clears a room to build in it can annihilate a four-hundred-unit vein in six swings and never
learn that they did. There is no tell, no refusal, no cost on screen — the number was never visible in the
first place (§3).

It is worse than a trap in isolation, because it contradicts three things that are already shipped:

- **The bit set (#S31/#S32)** exists so you can clear rock freely, by shape. Clearing rock freely is punished
  precisely where it matters — beside ore — so the kit's whole premise has a hole cut in it.
- **Dig-your-factory** (the stated identity: solid ore-rich earth you carve INTO) says carve. The ore rule
  says *don't carve here*, in the exact places the identity says are worth carving to.
- **#S37** just spent a whole strike making rock honest about what it refuses. Ore stays silently punishing,
  which is the same crime with better manners.

## 2. The fix, in one line

> **Terrain is what you CARVE. The lode is what you EXTRACT. Same pool, three rates.**

Ore stops being a block. It becomes a property of the **background wall plane**, behind ordinary rock. You
clear the rock to expose it (freely, with whatever bit suits the rock), and then you take the lode — by hand
slowly, or by machine steadily. Nothing you swing at can ever destroy a deposit again.

## 3. What is already there (this is cheaper than it sounds)

**The second plane is built and load-bearing.** `sim.wall` is a full background layer: per-cell material,
mutated only by `set_wall`/`load_world`, serialised (`save_game.gd` carries `"wall"` in its env
dictionary), painted behind every dug cell (`world_renderer.gd`'s background wall layer — "a dug-out cell
reveals the carved-room backing behind it"), drawn on the minimap through `Hud.minimap_color`, fed into
the fine-terrain bake, and **already authored per stratum by worldgen**
(`stone_wall`, `deepslate_wall`, `shale_wall`). It is explicitly not collision: *"you walk through walls"*.

So the lode is not a new plane. It is a new material family in an existing one, plus a verb change.

**The tell machinery is built too.** `check_tells.gd` holds the hollow-ring contract — a face with a cavity
behind it reads differently, the reading climbs *before* the face breaks, and it is silent in dead mass. That
is exactly the honest-telegraph problem the stain has to solve, already solved once and asserted.

**And the glint is built.** `_draw_ore_glints` gives exposed ore its starfield across a dark cavern. Today it
fires on solid ore blocks; the same pass over wall cells is the reveal state for free.

**What is genuinely new:** ore-bearing wall materials, a stain tell over unbroken rock, the hand-extract
verb, deposit-as-visible-density, and the Head/Spur pair (§5).

## 4. Exposure: what the bit set is for

Clearing a room stops being housekeeping and becomes **prospecting**. You cut a chamber with the bit that
suits the rock, and what you have made is not an empty room — it is a *face*, and the face shows you what is
behind the whole area at once. Then you decide what to cover.

This is the demand-pull rule read forwards: the player who has just cleared a twelve-cell wall of ore they
cannot carry has personally felt the problem the drill solves, standing in front of the answer.

**Two tell states, and both already have machinery:**

- **Behind unbroken rock — the STAIN.** Mineral staining bleeding through the rock face over a lode: the
  honest-telegraph contract from `check_tells.gd`, in colour rather than in feel. It must climb near a lode
  and read ~0 in dead rock, or it is noise and gets tuned out.
- **Exposed — the GLINT.** `_draw_ore_glints`, unchanged in spirit, now permanent and buildable-on rather
  than a thing you punch out.

**The deposit becomes visible for the first time.** Fleck density falls as the lode drains, so a worked-out
vein *looks* worked out and a fat one looks fat. Today a 250-unit cell and a 4-unit cell are pixel-identical
— that is not a hypothetical, it broke the Drift Rig capture (`docs/DRIFT.md`: the rig chewed one cell
forever and the photograph had to seed thin seams by hand to show a full cycle). A number the player is
supposed to plan around has never once been on screen.

## 5. Extraction: the Head and the Spur

**By hand.** Hold on an open cell whose backing is a lode: it yields per swing, on a cadence, and **clears
nothing**. This is the Factorio verb — the patch is under you and you take from it — and it is a genuinely
different feel from breaking rock, which is a charge that ends in a burst and an absence. Hand rate stays
deliberately poor. It is how you get your first ore and how you top up in a pinch, never how you supply a
factory.

**The Drill Head.** Sits in the open cell, on the lode, and pours down its own column. The on-hook rule is
untouched (extraction may be lateral; logistics stays gravity-vertical). Placement legibility improves
enormously over today's bore-down-through-solid model: you put the machine *on the thing it eats*, which is
the one placement rule nobody needs taught. A Head whose cell runs dry goes **spent** — a status, with words,
not a silent stop.

**The Spur.** A cheap module that extends a Head's coverage to adjacent lode cells. This is the piece that
makes the whole design pay:

- **vein SHAPE becomes a build puzzle.** A long thin lode wants a chain; a blob wants a hub. Geology stops
  being a number and becomes a layout.
- **it scales passive income without scaling machines** — one Head, many Spurs, one column, one drain.
- **it gives the cleared room its second reason to exist.** You cut wide to see the vein; you cut wide again
  to reach across it.

Placeholder numbers, wanting play: hand ~1 unit per swing, Head 1 per cycle, a Spur reaching 1 cell and
costing a fraction of a Head. Whether a Spur draws its own power or leans on the Head is a §8 question.

## 6. What this re-sources (and what it must not break)

**The Drift Rig.** `docs/DRIFT.md` §3 shipped a machine that separates pay from spoil at the face. Under
this spec the rig cuts *rock* (spoil) and **exposes** lode rather than eating ore blocks; its pay chute draws
from the backing in the cells it opens. Small deviation, better story: the rig is the excavator, the Head is
the extractor, and the two-chute geometry the player already learned is unchanged.

**The Borer** keeps its mixed stream and its coal, per DRIFT §6 — it must not become dead content.

**Coal is ore-like and gets the same treatment**, which keeps the coal→drill demand web intact. Clay, shale
and foliage are terrain and stay terrain.

**Ore stops being an obstacle.** You can never again be walled in by rock you cannot afford to break. Counted
as pure gain: the "expensive block in my way" decision was never interesting.

## 7. What could go wrong

- **The stain could lie, or shout.** A tell that fires everywhere is worse than none — `check_tells.gd` says
  this in as many words about the hollow ring, and the same failure is available here. It must be measured
  the same way: climbing near a lode, ~0 in dead rock.
- **The hand verb could be a chore.** If hand-extraction is the *fastest* path to early ore it becomes a
  grind you are punished for skipping; if it is too slow the opening stalls before the first drill. This is
  the number most likely to need play, not argument.
- **It touches the oldest system in the game.** Conservation, `check_richness`, `test_worldgen`,
  `check_drift`, `check_spoil` and the save format all read ore-as-solid. This is three strikes, not one —
  which is the argument for doing it NOW, while twenty more strikes have not yet been built on the old model.
- **Discovery could get flatter.** Today breaking into a vein is a small event. If the stain telegraphs too
  well, every vein is known before it is reached and the reveal is bureaucratic. The stain wants to say
  *something is here*, not *four hundred units of iron are here*.
- **Save compatibility.** Existing saves hold solid ore blocks with deposits. Pre-release, so a migration
  that lifts ore blocks into the wall plane on load is acceptable; silently dropping them is not.

## 8. What this deliberately does not do

- **No hybrid.** No "massive ore" solid blocks alongside wall lodes. A sometimes-solid exception rebuilds
  exactly the two-verbs-one-cell muddle this spec exists to delete.
- **No inventory or hauling change.** Lodes yield the same items into the same pack.
- **No sideways transport.** A Head pours down its own column, like everything else.
- **No new chore.** Nothing about a lode ever needs clearing, resetting or maintaining, per `docs/BITS.md`
  §9 and `docs/DRIFT.md` §5.

## 9. What the harness must say

- `check_lode` — a lode is never destroyed by mining the rock in front of it; hand-extraction drains the
  same pool a Head drains, and total matter is conserved across both paths.
- **The trap is gone, asserted directly:** clear an N-cell room over a seeded lode with every bit in the set
  and assert the deposit total is unchanged. That single case is the whole spec.
- The stain obeys the `check_tells` contract — climbs approaching a lode, ~0 in dead rock.
- A Head covers its own cell, a Spur extends it, coverage never crosses to a cell with no lode, and a spent
  Head says so.
- The on-hook rule holds through both: neither hand yield nor Head output ever moves sideways.
- A **play-test rung**: walk in with a pick, find a stain, clear a face, cover it, and leave with a line
  running — with no step in that chain explained by anything but the screen.

## 10. Sequencing

Three strikes, each provable on its own and each leaving the game playable:

1. **The lode exists and cannot be destroyed.** Ore moves into the wall plane, worldgen authors it, the glint
   draws it, hand-extraction takes from it, and mining rock in front of it is safe. The Drift Rig and the
   drill keep working against a compatibility path.
2. **The Head and the Spur.** Drills re-based onto the lode, coverage, spent status, placement preview.
3. **The stain.** The through-rock tell, measured against the `check_tells` contract, plus draining density.

> **The stain landed early — before the cutover, not after it.** Written as strike 3 because it reads as
> polish, it is actually a precondition: after the cutover the world is stone with the ore *inside* it, and a
> player who cannot see where to dig is looking at featureless rock. So it shipped first, at 57/57.
>
> It is built as one function, `WorldRenderer._stain(host, vein, amount)`, used by both tell states with a
> deliberate asymmetry between them:
>
> | | amount | value | what it says |
> |---|---|---|---|
> | exposed face | `LODE_STAIN` 0.42 | held at the host's (never darkens) | *here it is* |
> | buried rock | `LODE_STAIN_BURIED` 0.26 | ×0.78 | *something is under this* |
>
> The value split is the whole trick, and it is forced by §11's rule rather than chosen. **An open face may
> not darken** — a hole that reads dark is indistinguishable from more rock, which is exactly the bug that
> made the starter adit look like a scuff. **Buried rock may not brighten** — a lit patch on a wall reads as
> a light source, and worse, underground the veil crushes saturation long before it touches brightness, so
> value is the only channel with any reach down there. Measured on-screen: **−13.2% luma** against a ~2%
> capture noise floor. **That is an instrumented pixel measurement, and it is all it is.** Whether it is
> "loud enough to steer a dig" — the claim this line used to make — is a statement about a person, and a
> luma delta a differ can resolve is not the same quantity as a tell a player notices. Unverified, behind
> the unmet capture gate in `LODE_PLAN.md` §5. The intent is loud enough to steer a dig and quiet enough
> that §7's reveal is still a reveal; nobody has yet established that it lands.
>
> `check_lode:_the_rock_tells_on_itself` holds all of it, including the one that is easy to lose: the buried
> tell must be **still**. `_draw_ore_glints` learned at cost that sparkling sealed cells read as a starfield,
> so a sealed cell is asserted not to be a glint candidate. And what an open face buys you is not a louder
> stain — it is the metal itself: only an exposed lode draws grain, and only an exposed lode is workable.

## 11. How ore should read under light

> Raised while phase 1 was landing: *"I want the lighting to make ores feel special but not so
> much so that it's hard to play the game from distractions and overstimulation."* This is phase 4 material
> — it belongs with the stain — but the principle is written down here because it decides how the stain is
> built, not the other way round.

**The rule: ore does not glow. It answers your lamp.**

One sentence solves both halves of the request, because distraction and specialness come from the same
property and it is the wrong one. Anything **self-luminous** competes with the light you placed, animates
regardless of whether you care, and pulls the eye by emission alone — and it does this everywhere at once,
which is overstimulation by construction. Anything **highly reflective but dark on its own** does the
opposite: it is quiet until you do something, and then it is dazzling.

That is also just true of metal in rock. It has no light in it. It catches yours.

### What this fixes that is already broken

`_draw_ore_glints` runs on a free-running **per-cell** timer (`PERIOD` 3.4s, each cell independently phased)
and gates on `_skylight_alpha` — *daylight*, so that a surface vein does not sparkle at noon. It therefore has
no idea where your lamp is or where your torches are. Every exposed ore cell on screen twinkles on its own
schedule, forever, which is exactly the **"ore reads as a floating starfield"** finding already recorded
against the game. The worry above is not hypothetical; it is the current behaviour.

### The five parts

1. **Specular, not emissive.** Fleck brightness becomes a steep function of the *artificial* light at the
   cell — lamp pool, torches, machine glow — not a timer. Steep on purpose (square it): unlit ore is a dull
   matte patch, lit ore is near-white pinpoints, and the gap between them is the whole effect. Cheap to
   compute without a light buffer: distance to the body's lamp pool and to the nearest `sim.torch`.
2. **A motion BUDGET, globally, not per cell.** At most one or two glints alive on screen at any instant —
   the sparkle is a token passed around the visible veins, not an independent clock in every cell. A wall of
   ore then reads as *something occasionally catching the light*, which is what a real vein does, instead of
   a Christmas tree. This single change is most of the anti-overstimulation ask.
3. **Richness reads as DENSITY, brightness reads as ATTENTION.** Already true as of #S38: how much is left is
   carried by how many flecks there are. Keep those two channels separate — density can be studied at
   leisure, brightness says *look here now*, and a vein should never shout its size at you.
4. **Emission is reserved for `rich_ore`, and nothing else.** One faintly self-lit material in the whole game
   means a glow across a dark cavern is genuine information and a genuine thrill. If everything glows, glow
   is noise — the same logic that keeps the cannon a lighthouse rather than a progress bar.
5. **Coal absorbs.** It should read as a matte, light-swallowing cluster, which anchors the low end of the
   palette and proves the system is "ore answers light", not "ore is bright".

### The payoff this buys for free

Placing a torch on a face becomes a small **reveal**: you light the wall and the wall answers. Torches are
already how you claim territory; this makes them also how you *appraise* a vein — and it means the moment
worth photographing is an action the player took, not an animation that was going to happen anyway.

### What the harness must say

- Fleck brightness is a function of local artificial light, and is near-floor with no light on it.
- The number of glints alive at once is capped, independent of how much ore is on screen — the assertion
  that keeps this from ever drifting back into a starfield.
- `rich_ore` is the only material with any emission at all.
