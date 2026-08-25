# THE BIT SET — picks that differ in SHAPE, and rock that has a grain

> **Edited 2026-08-25** for the run-based pivot: sections specific to persistent-world design were
> removed or marked below. The rest of this document is unchanged and still describes current reality.

> **Status: SHIPPED (#S31 + #S32 + #S37, 2026-08-16).** Seams, the five bits, the drive/bit split and the
> deletion of the speed axis landed as #S31/#S32 — `src/data/seams.gd`, `src/data/bit_rules.gd`,
> `MainView._shape` / `_calve` / `_mineable`, `WorldRenderer._draw_seams` — held by `tools/check_seam.gd`
> and `tools/check_bits.gd`. **§5's refusal tells shipped as #S37**, the other half of the binary gate:
> `MainView._refuses` / `_drive_bites` / `_skid`, the crossed cursor in `WorldRenderer._draw_aim`, the
> synthesised `skid` scrape in `scenes/sfx.gd`, and `MiningRules.drive_for()` so the words come from the same
> table as the gate. Held by `tools/check_refusal.gd`, photographed at
> `history/117-the-rock-that-says-no.png`.
> Still spec: the Rack (bits are crafted at the Bazaar's existing counter for now, `docs/BAZAAR.md` §6) and
> §7's drives as research rather than as craftable picks.
>
> The **order** was load-bearing and is worth recording: seams shipped first because they are pure upside and
> cannot unbalance anything; the speed axis could only be flattened AFTER the bits existed, because without a
> relief bit that change is nothing but "the game is now slower", which §6 names as the failure mode.
>
> **Deviations from the spec below.** **Seams are planes, not per-cell rolls** — a 35%-dense per-cell
> sprinkle gives a contiguous run of three about once in six hundred cells, so the mechanic would have fired
> essentially never; a horizontal seam is now a ROW, a vertical a COLUMN, a diagonal one anti-diagonal, which
> is also how real bedding and jointing work and costs the same nothing to store. **The Wedge's refusal lives
> in `_mineable`, not in the verb** — the hold-loop charges on that predicate, so a cell that reads as
> mineable and then will not break spiders a full charge forever (the exact bug `check_mining`'s last case
> exists to prevent). Gating the predicate instead greys the cursor out before you press anything, which is
> also the better tell. **And the refusal is said by ONE tell, not by every tell at once** — §5 asked the
> skid to name the rung, but the hover inspector is already on screen whenever the cursor is on the rock, so
> the tier words live there ("too hard — the Stone Pickaxe (tier 2) bites it") and the skid's one line is
> reserved for the GRAIN refusal, which no other panel explains. Two panels saying one sentence is noise.
>
> **Original spec follows** (2026-08-16). Merging two ideas that turned out
> to be one design seen from either end: picks-as-shapes, and rock you can read. Provisional and reversible;
> the numbers are placeholders that want play, not a spec. **This deliberately overturns a documented
> decision** — see §6.

## 1. What is actually there today

Worth stating precisely, because it is not what either of us assumed.

**The tier gate is already binary.** `MiningRules.REQUIRED_TIER` maps deepslate/iron/rich_ore to tier 2 and
`sealrock` to 99, and `can_mine()` refuses outright. A wood pick does not slowly grind deepslate — it cannot
touch it. The "punishingly slow" soft-gate the docs describe (PROGRESSION §10, the Minecraft-obsidian rule)
is **not what the code does.**

What tiers *also* do is the problem. `MiningRules.TOOLS` gives each tier a speed multiplier:

```
wood_pickaxe   tier 1  speed 1.0
stone_pickaxe  tier 2  speed 1.7
iron_pickaxe   tier 3  speed 2.6
```

and the source is honest about what that buys: *"Its value today is SPEED (deepslate 1.65s -> 1.08s)."* So a
new pick is **mostly the old pick, faster**. That is the treadmill, and it is the axis worth deleting.

## 2. The change: two axes that do different jobs

Split the pick into the two things it is already secretly doing, and let each do only its own job.

| | What it is | How you get it | What it decides | Progression shape |
|---|---|---|---|---|
| **DRIVE** | your pick's power tier | **researched** at the Bench | what you can **bite** at all | monotonic, one track, never lost |
| **BITS** | interchangeable cutting heads | **bought** at the Rack | what one swing **takes** | horizontal, collect them all, keep them all |

**The speed multiplier goes away.** `TOOLS[...].speed` flattens to 1.0 across the ladder. A drive upgrade
unlocks new rock and nothing else; it is a key, not a stat. Everything that used to be "the same job,
faster" becomes "a different job", which is what a bit is for.

This is the chassis-plus-modules thesis (PROGRESSION §10, anti-restart) applied to the tool the player
touches most: the drive hardens forever, the bits are the swappable specialisation, and **a new layer never
takes a bit away from you.**

## 3. The bits

Five. Each is a verb, not a number, and each answers a situation this game actually has.

| Bit | Cut | The cost that makes it a choice |
|---|---|---|
| **Point** *(starter)* | 1 cell, any direction | none — it is the baseline, and it never stops being correct |
| **Broad** | 2x2 | **pulverises: no ore yield.** For hollowing chambers, not for veins |
| **Lance** | 1x5 driven horizontally, in the direction you face | long recovery between swings; cannot turn mid-drive |
| **Sinker** | 3 cells straight down, walls untouched | down only. Sinks the clean 1-wide shaft a gravity chain wants |
| **Wedge** | splits **along a seam** (see §4) | does *nothing at all* across the grain. The skill bit |

The Broad is the "2x2 for excavating" idea, priced so it is a decision rather than a strict upgrade: you
hollow a room with it and **swap to Point the moment you hit a vein**, because Broad would grind the ore to
nothing. That swap is the whole point — a bit you never take off is a stat.

The Lance is the hand-held half of horizontal mining; the **Drift Rig** (the powered adit machine, still an
idea) is its factory half. Exploration horizontal, production vertical — the GDD's division of labour holds.

**Swapping costs no new UI.** Bits are pack items, so they live in the hotbar and `1-9` / the mouse wheel
already select them. Selecting a bit equips it. Nothing to learn.

## 4. SEAMS — the rock has a grain

Every rock cell gets a **seam direction** — horizontal, vertical, diagonal, or none. Strike **along** a
seam and the break **propagates**: the whole contiguous run of same-seam cells calves off in one swing, up
to a cap. Strike **across** it and you break exactly the one cell, at exactly today's speed.

**Seams never punish.** This is the load-bearing rule and it is why the design is not slowness wearing a
hat: cutting across the grain costs *nothing extra*. It is today's mining, unchanged. Reading the rock is
pure upside, so a player who never notices seams plays the game we already have, and a player who does gets
paid for looking. Any version where the wrong swing is *slower* is the treadmill coming back in through the
window, and should be rejected.

This is also what finally gives the **scanner** a permanent job. Today it finds veins and then has nothing
to do; revealing seams makes it a tool you keep using for forty hours.

Placeholders to tune by play, not by argument: ~35% of rock cells carry a seam; propagation caps at 3 cells
for Point and 8 for Wedge; propagation only runs through cells your **drive** can bite, so a seam never
smuggles you past a depth gate.

**Storage cost: zero.** Seam direction is a pure function of `hash(x, y, world_seed)` — deterministic,
never saved, never in memory, and it costs nothing in `WorldData` or the save file. It is the same trick
the ore glints and the fine terrain already use.

## 5. Feedback — the wall has to be visible before you swing

A binary gate is only honest if you can see it coming. Three tells, none of them a tutorial:

- The **aim cursor** already reports reach and placeability. It grows one more state: *your drive will not
  bite this*, drawn before you press anything.
- A swing at rock over your drive **skids** — its own short, distinct sound (the audio library has room; see
  `check_voice`) and a spark, never a partial break bar. You must never be able to mistake "cannot" for
  "slow".
- The refusal **names the rung**: not "you need a better pick" but the drive tier and the research that
  grants it, the way locked craft rows already name their tech.

## 6. What this overturns, and what replaces it

PROGRESSION §10 states the Tools axis is **soft-gated** — *"you can mine the next tier's rock, but it is so
punishingly slow it isn't worth it"* — and that a new tier **"retroactively trivialises old rock
(retroactive-relief dopamine)."**

Both change (2026-08-16: *"maybe pickaxes shouldn't be super slow, just not strong enough for the next
layer"*):

- **Soft-gating is dropped for hard bite/no-bite.** In practice this documents what the code already does
  and removes the speed multiplier that was pretending to be the gate.
- **Retroactive relief moves from the drive to the bits.** It is not lost — it is *better*, because a Broad
  or a Lance trivialises old rock four and five cells at a time, and it is a choice you made rather than a
  number that went up. **This is the load-bearing replacement**: without it, hard gating removes a real
  dopamine beat and gives nothing back, and the design fails.

The one risk worth naming: §10 warns against *"no hard 'you literally cannot' walls."* Mitigation is that
the wall is always **downward**, never lateral — you are stopped from descending early, never trapped — and
§5's tells make it legible before the swing. THE SEAL is already precedent for a hard wall the game is
better for.

## 7. Where they come from

> _[Section removed 2026-08-25, pivot: the Bench-research/Rack-purchase acquisition model is dead design;
> only how bits are acquired changes, not the bit set or SEAMS themselves (see `docs/GDD.md` §4, R4). See
> git history for the original text.]_

## 8. What the harness must say

- `check_bits` — each bit cuts the geometry it claims; **no bit ever breaks a cell the drive cannot bite**
  (including through seam propagation); Broad yields no ore.
- `check_seam` — seams appear at the intended density and are deterministic for a seed; along-grain
  propagates and across-grain does not; propagation respects both the cap and the drive gate.
- `check_mining` grows the binary case: a swing at over-tier rock produces **no progress at all**, not slow
  progress.
- `check_rhythm` / `check_dig_hitch` must be re-measured after the speed multiplier flattens. If the dig
  groove depended on tier speed, that is worth knowing before, not after.

## 9. What this deliberately does not do

- **No durability.** Bits do not wear out. Nothing here should add an errand.
- **No hardness-vs-bit-material matrix.** One axis of "can I bite this" (the drive) is enough; two would be
  a spreadsheet.
- **No seam penalty.** Stated twice on purpose (§4).
- **No combat use.** Bits are digging verbs. Whether anything here is ever a weapon waits on the combat
  decision, which is parked until L4.
