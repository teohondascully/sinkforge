# THE LODE — ore lives in the wall, and mining stops being a trap

> **Status: SPEC (2026-08-16).** Opened by the user's question — *"is having ores that you put drills under
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

`factory_sim.gd:626-637` is explicit about the intent — hand-mining is "a quick, inefficient grab" and "the
block's larger latent yield is NOT hand-extractable". That reads fine as a sentence and plays terribly as a
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
mutated only by `set_wall`/`load_world`, serialised (`save_game.gd:36`), painted behind every dug cell
(`world_renderer.gd:1563` — "a dug-out cell reveals the carved-room backing behind it"), drawn on the
minimap (`hud.gd:1025`), fed into the fine-terrain bake, and **already authored per stratum by worldgen**
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
