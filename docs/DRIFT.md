# THE DRIFT RIG & SPOIL — horizontal extraction, vertical logistics

> **Status: §3 SHIPPED as STRIKE 35, §4 SHIPPED as STRIKE 36** (2026-08-16) — the Drift Rig is in the game, researched under
> **Galleries**, asserted by `check_drift` (harness layer 53) and photographed at
> `history/115-a-gallery-that-sorts-itself.png`. §4's **Crusher** and **packing** followed as Strike 36 —
> researched under **Packing**, asserted by `check_spoil` (harness layer 54), photographed at
> `history/116-the-wall-that-weeps.png`. What is still SPEC: the per-layer packing payoffs BELOW L3 (magma
> insulation, Hollow ballast) and the §7 play-test rung that runs a whole gallery end to end. Pairs with
> `docs/BITS.md` (the Lance is this machine's hand-held half) and `docs/BAZAAR.md`.
>
> **Recorded deviations from the spec as written.**
> * **The FACE advances; the MACHINE stays put.** §3 says the rig "advances". It does not move: it reaches
>   up to `DRIFT_RANGE` 24 cells along its facing and cuts the two-cell face at the end of its own gallery.
>   A walking machine would take its two drop columns with it, and the drop columns are the player's half of
>   the bargain — they are dug by hand, in advance, where the player chose. A rig that walked would either
>   drag its shafts along behind it (impossible) or start pooling the moment it left them (a machine that
>   breaks itself by working). So the gallery grows and the rig sits at its mouth, which is also what a real
>   drift head does.
> * **Power demand is 6.0, not "more than a lone generator can give".** Auras take the MAX and never sum, so
>   the most a machine standing beside one generator ever reads is 4.0. Measured: lone generator 4.00, a
>   two-generator trunk 5.61, three 6.09. 6.0 puts a lone generator at a 0.67 throttle — it LABOURS rather
>   than refuses — and makes a real conduit trunk the thing that buys full speed. A higher number would have
>   been a demand no achievable network could meet.
> * **§4's payoff is a PROPERTY OF YOUR OWN CONSTRUCTION, not of the material.** The table says packed
>   spoil "holds water back", but any solid cell already does — water never enters rock. So the shipped
>   rule is the other half of that sentence: **everything you stack back is LOOSE FILL and WEEPS**, and
>   packed gravel is the one thing that doesn't. A gallery backfilled with the stone you dug out of it is a
>   sieve; crush that stone and pack it and the same gallery is a bulkhead. Undisturbed strata never seeps
>   — the leak is a property of construction, which is why the sim tracks a `fill` layer and not a material.
> * **8:1 was not implemented as a ratio.** It did not need to be: a gallery's face is mostly rock and the
>   rig already produces whatever the geology gives it. The Crusher halves the stream at 2 spoil → 1 gravel,
>   which is the volume answer the ratio was reaching for, and pay is never crushed — ore-like items fall
>   straight through the machine, so a crusher under a mixed stream costs you nothing.
> * **Two new status words, not one.** "output blocked" is not an answer on a machine with two outputs, so
>   the rig says `blocked_pay` ("dig a drain UNDER it") or `blocked_spoil` ("dig a drain BEHIND it"), plus
>   `no_power` for the dark case.

## 1. What is already there

More than either of us assumed, and it is worth being exact so the spec adds rather than reinvents.

**The Borer (`h_drill`) already works, and it already obeys the hook.** It bores sideways along its row
(`H_DRILL_RANGE` 8), burns coal, self-feeds when it cuts a coal seam, holds a 5-slot / 40-item belly, and
— the good part — `_destinations_h_drill` enforces the **ON-HOOK rule**: the haul exits **straight down its
own column only**, and if there is no drain the belly pools until it stalls with *"dig a drain"*. The source
states the thesis plainly: *"Extraction may be lateral; logistics stays gravity-vertical."* That is the GDD's
division of labour already implemented.

**Nothing is deleted when you dig.** Bored rock yields its block-item (*"bored earth/stone feed
block-building — nothing is waste"*), hand-mined blocks land in your pack, and `place_block` already lets
you *"backfill a dug room or extend a structure"*.

**The pay/spoil distinction already exists** as `_is_ore_like(material)` — ore, coal, iron, rich_ore.

**Sorting already exists** as verbs: the splitter routes a falling stream down + right at a tunable ratio,
and the hopper keeps the first item it tastes (`R` re-tastes).

So the "spoil" idea as originally stated — *"what you dig has to go somewhere"* — is largely already true.
What is missing is a **reason to care** and a **volume that makes it a problem**.

## 2. What is actually missing

1. **One mixed stream.** The Borer drops pay and spoil down the same column, into the same hopper, into the
   same forge. Today that is invisible because volumes are small. At gallery scale it is the whole problem.
2. **No throughput reason to prefer lateral extraction.** The Borer is a novelty next to a Drill.
3. **Spoil has no job that grows with depth.** You can backfill; you have no reason to.
4. **Nothing makes power matter yet.** PROGRESSION §9 wants L2's first build slice to be the one that makes
   power a real constraint. The Borer burns coal, which is the old constraint wearing a new hat.

## 3. THE DRIFT RIG

A powered gallery machine: the Borer's successor, and a genuine change of kind rather than a bigger number.

- **It cuts a 2-high gallery** and **advances**, rather than sitting at range 8 and needing to be carried.
- **It separates pay from spoil at the face** and delivers them to **two adjacent drop columns** — pay down
  one, spoil down the other. Both still fall. The on-hook rule is not bent; it is used twice.
- **It draws POWER, not coal.** This is the machine that makes the L2 twist bite: a gallery is the first
  thing in the game whose appetite outruns a lone generator, so the Drift Rig is what makes you build a
  power network instead of feeding a box.
- **It stalls the way the Borer stalls** — no drain under a column, that column's stream pools until it
  jams. Two columns means two ways to jam, and the status must say **which**.

**Why this is the upgrade and not a stat.** The Borer gives you one mixed stream and leaves you to sort it
with splitters and hoppers. The Drift Rig sorts at the face. You buy your way out of a logistics problem
you have personally felt — which is the demand-pull rule (GDD, "never hand the player an automation they
haven't first missed by hand") applied exactly as written.

## 4. SPOIL

Introduce **spoil** as a *class*, not a new item: everything `_is_ore_like()` says no to — earth, clay,
stone, gravel. It keeps stacking in your pack and keeps being placeable, exactly as today. Two things change.

**Volume.** A gallery produces far more spoil than pay — placeholder ~8:1. That single ratio is what turns
a solved problem into an interesting one: run both streams into one shaft and your forge chokes on rock.

**A job that grows with depth.** This is the part that makes spoil worth having, and it must land or the
whole idea is an errand:

> **Packed spoil is how you make the deep habitable.**

A gallery backfilled with spoil is not empty space — it is *fill*, and fill does work:

| Layer | What packing spoil buys |
|---|---|
| L2 Stonereach | a floor you can build on where there was a void |
| L3 The Aquifer | **it holds water back.** A packed gallery is a bulkhead |
| L4 The Magma Belt | **it insulates.** Packed rock between you and the heat |
| L5 The Hollow | ballast — mass where gravity is unreliable |

So spoil is not waste you dispose of, it is the material the frontier is made of, and its use *specialises
per layer* — which is PROGRESSION §10's "novelty propagates into the whole kit" rather than a stat bump.
It also gives the worked-out gallery behind you a second life instead of leaving a dead strip-mine, which is
the living-column thesis.

**One new module: the Crusher.** Spoil in, gravel out; gravel is the packing material and the feedstock for
foundations. One machine, one clearly-readable job — the legibility thesis. It is also the sink that makes
an 8:1 ratio survivable instead of overwhelming.

## 5. The rule that keeps this from becoming an errand

`docs/BITS.md` §9 says it and it applies double here: **nothing may add a chore.**

> **Spoil must never need to be disposed of.** Every unit has a use, and the pressure is *routing and
> throughput*, never housekeeping. A player who ignores spoil entirely must still be able to play the whole
> game — they simply build slower and cannot seal a gallery.

Concretely that forbids: a spoil meter that fills, a rig that refuses to run until you clear tailings, and a
"dump" that deletes matter for you. If the design ever needs one of those to work, it does not work.

## 6. What could go wrong

- **Two drop columns is twice the geometry to get wrong.** Placement legibility must be excellent — the aim
  preview already shows a drill's bore and pour before you commit (`check_aim` guards it); the Drift Rig
  needs the same, for both columns, or it will be placed wrong every time.
- **8:1 could simply be miserable.** It is a placeholder. The honest test is a play-test that runs a gallery
  for ten minutes and asks whether the spoil stream felt like a system or like litter.
- **Power could arrive too early.** If the Drift Rig is the first powered machine a player meets, it lands
  before generators are comfortable. It should sit *after* the power research rung, not be its tutorial.
- **The Borer must not become dead content.** It stays the cheap, coal-fed, mixed-stream option. If nobody
  ever places a Borer again once the Rig exists, the upgrade was a replacement, not a choice.

## 7. What the harness must say

- `check_drift` — the rig advances; it cuts 2-high; **pay lands in one column and spoil in the other**, with
  zero cross-contamination; each column jams independently and the status names which one.
- The on-hook rule holds: **neither stream ever moves sideways**. This is the one property that must never
  regress, because it is the GDD's whole division of labour.
- `check_pack` (spoil) — a gallery of known composition produces the expected pay:spoil ratio, and total
  matter is conserved (the stress layer already asserts conservation; this extends it through the rig).
- A **play-test rung**, not just a unit check: run a gallery, sort the streams, pack a worked-out section,
  and confirm the packed section actually holds water in L3. That last clause is the whole design; if it is
  not play-tested it is a paragraph.

## 8. What this deliberately does not do

- **No new inventory pressure.** Spoil stacks like everything else. No weight, no encumbrance.
- **No sideways item transport.** Spoil does not get a belt. Extraction is lateral, logistics is vertical,
  and this spec exists partly to prove that rule scales.
- **No tailings, no pollution, no cleanup.** See §5.
- **No replacement of the Borer.** See §6.
