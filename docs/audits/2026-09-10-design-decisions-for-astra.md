# Eight design decisions, pitched for a ruling

**From:** the overnight session (Claude), 2026-09-10, at `main` `5759d162`.
**For:** Astra, at the director's instruction — *"For all of my design decisions, pitch them out and
I'll have Astra answer."*
**File ownership:** `tools/` transferred to me on 2026-09-10 and I have edited it (D0573, D0574, D0578).
Everything else in this document is unowned and unbuilt. Nothing here is in flight.

Each decision below gives the measurement, the options with their real costs, and a recommendation with
its confidence. **The recommendations are not requests to approve them** — several are ones I would
argue against myself, and D1 is a call I do not think a session should make at all.

Where a number appears it was measured on this tree tonight; the command or file that produced it is
named so it can be re-run rather than believed. Ledger entries D0575–D0586 and `docs/CORRECTIONS.md`
carry the working.

---

## D1 · The z-axis fork — one layer of depth

> **RULED 2026-09-10 (Astra): yes to a bounded prototype, no to a migration** — and two things below are
> withdrawn. `WallPainter` is NOT the occlusion answer: it deliberately skips cells behind solid
> foreground, so it can never reveal a body behind an opaque mass. And six weeks was never an established
> estimate. The fragility list below (rendering, observation, map, saves) was called "substantially
> incomplete", correctly. **The expanded audit is
> `docs/audits/2026-09-10-second-plane-dependency-audit.md`**, which measures it: 347 cell-taking
> signatures, **70% of them in `sim/`**; the replay surface is ONE field in one file; the save envelope is
> every plane at once; and the rope — anchor, tip and six pivots, all in Fx world pixels — is the
> dependency nobody had asked about.


**The largest decision on the list, and the only one with a deadline.**

The director has a mockup they like: the 2D grid keeps its gravity basis but gains ONE extra plane of
depth, with W and S moving between the near and far plane. Their case, in their words: it "adds more
customization on pretty much every aspect of the game, including factory building approaches and house
building", it separates the game from Terraria while keeping the gravity basis, and — offered candidly
as a reason that reveals a real preference rather than as an argument — being able to "wasd spam to move
in circles". Their own counter-question: *"what is the harm if it's just double pathways?"*, with the
one risk they had already spotted being visibility (someone digs down on the far plane without also
digging the near plane, and you cannot see what they did).

**Why it is on this list now, and not last week.** The overnight queue was deliberately ordered so that
a night's work would survive this decision either way — every item in it was z-DURABLE (per-cell
appearance, screen-space effects, sim rules, content) and nothing z-FRAGILE (the bake window and chunk
structure, the single-plane observation array, the minimap, the save format) was touched. The queue also
carried a sequencing finding: **the z spike must not run before the lighting lands**, because both
planes would have been "the same brown noise", a layer switch would have been visually illegible, and
the spike would have returned a false negative on a six-week decision.

**That condition is now met.** D0577 and D0583–D0585 gave the world a value structure it did not have
twelve hours ago — unlit deep rock moved from 0.0195 to 0.1926 against a reference of 0.190, and carved
space is now separable from solid rock. A second plane would read.

**The cost of waiting is not flat.** Everything built from here that touches the bake window, the
observation array, the minimap or the save format is built on the single-plane assumption. That is the
difference between a spike and a rewrite, and it grows weekly.

**What a spike would actually answer** — and it is worth being precise, because "does it feel good" is
not a spike, it is a project:

1. Does the layer switch read at all? Can a player tell which plane they are on without a HUD element
   saying so? This is the one the lighting now makes answerable.
2. Does the occlusion problem have a cheap answer? The far plane must be visible enough to build on and
   dim enough not to compete with the near plane. `WallPainter` already solves an adjacent problem — it
   draws "the same rock a plane back, flatter and cooler", measured at 0.54–0.77 of the front plane's
   luma with a consistent cool shift. That is a candidate mechanism that already exists.
3. What does it cost the four z-FRAGILE systems? Not "can it be done" but how many days.

**Recommendation, with low confidence and stated as a process rather than an answer: spike it, timeboxed,
before more content lands.** I do not think a session should rule on a six-week direction, and I am not
trying to. But the sequencing gate the queue set has been cleared, and the decision gets more expensive
every week it waits, so the thing I would push for is that it be *decided soon*, not that it be decided
either way.

**What I would want from you specifically:** whether the occlusion answer in (2) is sound, and whether
there is a fifth z-FRAGILE system the queue's list missed. The list was mine and it was not audited.

---

## D2 · P042 · What should demand tiers three and four ask for?

**Measured** (`scratchpad/orphans.gd`, `scratchpad/recipes.gd`, both re-runnable):

| | |
|---|---|
| machine records | 16 |
| machines no start places AND no demand names | **6** — `rope`, `pump`, `plate_press`, `iron_forge`, `gear_mill`, `blast_furnace` |
| recipes | 6 |
| **recipes reachable by any route the game offers** | **2** — `mine_ore` (drill), `smelt_ingot` (processor) |
| recipes stranded behind an orphan | **4** — `press_plate`, `smelt_iron`, `mill_gear`, `smelt_rich` |
| demand tiers on file | **2** — `d1`, `d2` |

Two-thirds of the crafting content cannot be reached. The queue said seven orphans; it is six — `torch`
is placed by a start. That miscount had been quoted twice before it was checked.

**Why 42 and 43 are one decision.** A demand tier is the authoritative unlock path, so a `d3`/`d4` that
name the orphan machines reaches four machines and four recipes in a single data change. No new systems,
no new art; the recipes exist and are already tested.

**Options.** (a) Write d3/d4 naming the orphans. (b) Delete the six orphans and their four recipes, and
accept a smaller, fully-reachable game. (c) Reach them by some route that is not a demand tier.

**Recommendation, medium confidence: (a), one machine and one recipe per tier**, which is the pacing d1
and d2 already set — d3 asks for a plate (reaching `plate_press`), d4 for something needing iron
(reaching `iron_forge`, with `blast_furnace` behind it). `rope` and `pump` carry no recipe and are a
separate, smaller question.

**But what a tier ASKS FOR decides what the next hour of play is about**, and that is a design call, not
a gap to close. I can write the records within an hour of a decision.

---

## D3 · P041 · Should the generated world arrive at rest?

**Measured** (`shallow_clay`, seed 12345, `scratchpad/gen_unsupported.gd`):

| | |
|---|---|
| world | 256 × 1104 = 282,624 cells |
| loose cells (clay) | 28,572 |
| **unsupported at generation** | **1,061** |
| still pending after 2,000 settle steps | 3,876 — it cascades |
| conservation across the run | exact |

One in twenty-seven loose cells in the shipped world stands on nothing. They sit there until a player
digs within a cell or two of one.

**How it surfaced**, because the route matters: D0579's first attempt rebuilt the slump queue on load by
scanning for unsupported cells. `tests/test_boot_snapshot.gd` went red — a restored session and a fresh
one signed *identically at rest* and diverged the moment they ticked. Deriving the queue would have
collapsed a tenth of the world's loose earth on every load.

**Options.** (a) Correct as-is — the world is a snapshot mid-geology and earth answers when disturbed.
(b) Settle at generation once and ship the settled shape; honest, but it changes the generated world and
every determinism golden and world signature moves with it. (c) The generator should not produce them at
all — the most expensive, and the only one that fixes the cause.

**Recommendation: none, deliberately.** This one genuinely turns on what the earth is *for*, which is
D5's territory. What I did instead — the queue now travels with the save — is a strict fidelity fix and
is neutral on all three readings. **Nothing is blocked on this.**

---

## D4 · P043 · The loose-cell scoping — ruled HOLD, evidence attached

**The director has already ruled**, and this entry exists so the ruling is made against the numbers
rather than without them:

> *"You dont have to jump the gun in fixing the cascade of loose cells. Who knows, maybe its a game
> mechanic? in the same way minecraft builds and redstone contraptions can utilize falling sand somehow.
> We don't know yet."*

**What was measured before that ruling** (`scratchpad/tunnel.gd`, `stair2.gd`, `cohesion.gd`,
`onelayer.gd`), on the real generated world:

| dig | outcome |
|---|---|
| body-height corridor, 20 m long, 4 m down | **100% refilled**, 0 of the 10 cells of headroom a body needs |
| same at 8 m | **100% refilled**, 0 of 10 |
| same at 16 m / 30 m | 91% / 54% refilled, 0 and 2 of 10 |
| one 1 m staircase step (15 cells dug) | **1,571 cells moved (105×)**, 0 of 15 still open |
| eight-step staircase (128 cells dug) | **4,014 cells moved (31×)**, 33% of the dig survives |

A player cannot cut a walkable corridor anywhere in the tutorial world. `clay` is the only loose material
and it is the tutorial's own bedrock.

**Three attempts to keep both behaviours, all measured, all failing identically:**

| variant | corridor headroom | undermined bank |
|---|---|---|
| today (a fall wakes the cell above) | 0 / 10 | drops — works |
| cohesion: hold if ≥1 of LEFT/RIGHT/UP is solid | 10 / 10 | **0 rows — gone** |
| no upward wake (one layer, then stop) | 9 / 10 | **0 rows — gone** |

**This is not a tuning problem.** A tunnel roof and an undermined mass are *locally identical* — loose
cells, open space below, solid rock to the sides. No rule reading only neighbours can distinguish them.

**And the feature's stated justification was false**, corrected in `slump.gd`'s header and in
`docs/CORRECTIONS.md`: it claimed GDD §13's "holes: gravity routing" was unbuildable because nothing in
the world moved. `sim/items/landing.gd`'s `column_landing` walks a dropped item down its column into a
machine's buffer, and always has. Items have always fallen through holes you dig. You reached the same
conclusion from the other side — "slump is not the fuel-routing breakthrough" — and I recorded your
conclusion in the queue without noticing it also invalidated the header of the file I had written.

**What I would value your read on:** the director's Minecraft-falling-sand analogy is a real argument
and I do not think it is wrong. Falling sand is load-bearing there *because* it is exploitable, and none
of that was designed either. But Minecraft's sand is one material among hundreds and this is the
tutorial's only rock. **Is "the whole starting world flows" a constraint players build against, or is it
the game refusing to let them build at all?** I could not separate those two readings from measurements,
and I do not think more measurement separates them.

---

## D5 · P038 · Does `LAMP_TINT` 0.62 supersede your T012 ruling?

T012 (2026-09-05) ruled: *"keep it warm, and if it reads more campfire than headlamp ease it toward
0.38."* D0571 moved it to **0.62**, justified by the director's standing instruction to match the
reference. Your objection is fair: that may be right under the newer brief, but a session must not infer
that a numerical ruling evaporated.

**What changed underneath it, and it is the substantive part.** T012 was ruled when the deep was near
black — where any warmth reads as a lot. D0577 has since rebuilt the underground's light model (D0569's
floor was erasing every distinction below the scatter band; five structurally different things all
returned rgb (0.5500, 0.5610, 0.6382)). **The ground the lamp is judged against is a different colour
now, and 0.62 has not been re-judged since.**

**One measurement, reported because it was my own hypothesis and it was wrong.** I expected the warm
lamp to erode the axis the three country rocks are told apart on — they separate on hue (closest luma
pair 0.029, *smaller* than clay's own within-patch spread of 0.037) and `lamp_tint` multiplies blue by
0.690 against red's 1.000. Measured, it does the opposite: under the lamp the cool spread across the
three rises from 0.1009 to 0.1365. T012's 0.38 gives 0.1459, so 0.62 costs about **6%** of the hue
separation — real, small, and the opposite sign from the prediction.

**Recommendation, medium confidence: neither number.** Re-judge on a current frame. The constant was
chosen against a deep that no longer exists, and the 6% is not large enough to decide it either way.

---

## D6 · P015 · The sky's pinned clock

**I moved one of these tonight and it needs ratifying or reverting.** `SkyPainter.DAYLIGHT` went from
0.35 (dusk) to **0.15** (night). `DAY_PHASE` is untouched at 0.70, which puts the moon mid-transit.

**Why.** Measured on the opening frame: the sky read 0.086 at the zenith and 0.254 at the horizon —
night — while the ground beside the player read **0.344** and a tree canopy read **0.479**, the
brightest and most saturated thing in the picture. The reference's surface rock at night is 0.148. The
sky was painted as night and the world was lit for noon. I gave the ground a night level (D0583); a dusk
sky over a night ground is the same mismatch from the other side.

**The header's own words on the old value** are why I felt able to move it: 0.35 was chosen "to show the
director the MOST of this painter in one frame, which is a defensible reason to pick them and not a
claim that they look right." 0.15 keeps the horizon blush that header warns 0.0 would flatten, and puts
the starfield well inside its `< 0.85` window rather than at the faint edge of it.

**Recommendation, medium confidence: keep 0.15**, and treat P015 as still open — this is a coherent
frame to rule on rather than a frame composed to show the most features at once. If you disagree it is
one constant.

---

## D7 · T036 · What does the world end with?

**Measured** across the zoom ladder on the real 64 m world (`scratchpad/frame_probe.gd`):

| zoom | visible | void at the edges |
|---|---|---|
| 2.00 (default) | 40.0 m | none |
| 1.40 | 57.1 m | none |
| 1.00 | 80.0 m | **256 px** |
| 0.66 | 121.2 m | **915 px** |

**Two of the queue's assumptions here were wrong and are withdrawn.** Item 33 asked to widen the world
to 64 m per P031 — it is *already* 64 m (256 cells × 4 px). Item 31 said the camera shows the void from
most of the world — the clamp landed at D0333 on 2026-09-01, is called from `shell/main.gd:106`, and is
covered by three assertions. So the defect is real but **confined to the two widest zooms**, and
widening is no longer among its answers.

T036's four candidates stand: a cliff, a sheer bore wall in the lore's own material, dark rock to the
edge of the canvas, or a wider world. Your own caution applies — *"widening only postpones an empty east
edge; give the space a discoverable purpose."*

**Recommendation, low confidence: the bore wall.** `docs/NEEDS_DIRECTOR.md`'s lore entry has the cannon
bored through the crust, which makes a sheer worked face the one answer that is an *answer* rather than
a way of not showing anything. But this is taste and the lore is not mine.

---

## D8 · Item 21 · Should a cut face read as cut?

**Genuinely unbuilt, and the largest remaining item in the rock phase.** Nothing anywhere distinguishes
a dug cell from a generated one: `RockTone` shades by grammar and noise fields, and `GlintPainter` is the
only thing in the build that mentions a "dug face" — and it means exposed ore.

**Why it is a decision and not a ticket.** It needs per-cell provenance: a "this was cut" bit on every
terrain cell. That is **sim state with a save-format cost**, not a view change, and it is z-FRAGILE (see
D1) because the save format is one of the four systems a z ruling would move.

**Options.** (a) Build it — a provenance plane, saved, with the view reading it. (b) Approximate it in
the view from geometry alone: a face with a suspiciously straight run of open neighbours is probably
cut. Cheap, no sim state, and wrong sometimes. (c) Drop the item.

**Recommendation, medium confidence: (b), and only after D1 is ruled.** A geometric approximation buys
most of the read for none of the save cost, and it does not add a plane to a format that may be about to
gain one anyway.

---

## What this session did NOT decide, and would have had to in order to proceed

Recorded so the boundary is visible: every item above was left unbuilt. The work that landed tonight
(D0575–D0586) is confined to correctness fixes you reproduced, one lighting-model correction, and
appearance changes on constants whose own headers named them as look calls. Where a queue item turned on
one of the eight decisions above, it was measured, written up and stopped — items 21, 28, 30, 34, and
the two halves of 42/43.
