# Audit request: the 2026-09-10 overnight queue

**To Astra. From the overnight session. Not normative -- this is a request, and every claim in it is one
I would like checked rather than believed.**

Head at writing: `6980ac25`. Twelve of a 49-item director queue are landed
(`docs/WORKING.md`, "## Overnight queue"). This file is in two halves: **what to audit in what already
shipped**, and **what to audit in what is planned**, both framed around the failure classes this repo
actually suffers from rather than around a feature list.

I have led with what I think is most likely to be wrong. Three of my own findings were already refuted by
measurement inside the same session -- see §0 -- so the prior that some of the rest are wrong is high.

---

## 0. Three claims I made and then measured false, in one night

Listed first because they set the calibration for everything below.

1. **"Add edge occlusion at cut faces" (queue item 10).** The AO and rim light are already implemented and
   correct at legacy's own 0.125 per open neighbour (`rock_tone.gd:229-246`). Probed directly: luma 0.26
   interior to 0.06 fully carved, a 4.1x range. `rock_tone.gd`'s header still says those terms are
   "deliberately not here" -- superseded prose above its own amendment, and it is what I believed first.
2. **"The grapple is never named on screen."** It is. The lesson fires at depth, not at the surface,
   and I had only ever played the surface. Visible in `docs/media/moments/2026-09-10-lighting-bench.png`.
3. **"Machines do not light the rock."** They do. I measured it on `beacon_probe`, whose one machine has
   no input -- and `VeilSources.machine_strength` returns **0.0 for an unfuelled burner by design**. The
   instrument could not register its subject; the subject was correctly absent.

**And a fourth, found while writing this file.** See §2.4: the rock-texture premise does not survive a
corrected population either.

---

## 1. Highest audit priority: `sim/body`, D0567

**The change.** `BodySwing.step` used to refuse the line's constrained position outright whenever the
projected box would overlap rock. It now takes as much of the move as fits -- full, then vertical-only,
then horizontal-only -- via `BodySwing._slide`.

**Why it is first.** It is the only change tonight inside the body's collision-adjacent path, it is the
one with the largest blast radius, and its correctness argument is mine rather than legacy's.

**What I claim.** Every candidate is a strict subset of a move the constraint already wanted, and each is
checked with `_blocked_at`, which is `body._box_blocked` -- the same predicate the axis resolvers use. So
no candidate can place the body inside rock.

**What I want checked, specifically.**
- Does `_slide` open any path to a position the two-axis resolvers would have rejected for a reason
  `_box_blocked` does not encode? I believe not; I did not prove it.
- The parked resolver ruling (plan §8) is untouched, and I claim this is strictly *less* refusal than
  before rather than a partial implementation of it. Is that framing right?
- Determinism: 149 suites pass, including `test_shaft_replay_determinism` and
  `test_body_fuzz_regression_d0122`. That is evidence, not proof, over the interleavings the fuzz reaches.
- `_test_a_swing_into_a_wall_stops_at_the_wall` still passes, so the flat-wall yield is unchanged. Is
  there a corner case where the old "hold" was load-bearing for something else?

**Reproduce.** `tools/run_gd_test.sh <godot> res://tests/test_grapple_body.gd` -- the shaft cases are
`_test_it_climbs_out_of_a_shaft_it_dug` and `_test_it_chains_hooks_the_whole_way_out`. The before number
is 0 px in 300 ticks; after is 82.

---

## 2. The measurement discipline, which is where I most want a second pair of eyes

### 2.1 A before/after across two different scenes (D0569)

D0569 quotes "deep rock 0.0195 -> 0.0765" and its own ledger entry carries an **HONEST LIMIT** paragraph
saying the two captures are different scenes at different positions. I would rather you judged whether
that entry overstates anyway. What is exact is the arithmetic in `VeilLight.level_rgb`, pinned on both
sides of the floor by `tests/test_flat_planes.gd`.

### 2.2 The bench, and what it cannot do (D0570, reverted -- see P037)

A fixed-scene lighting bench was the fix for 2.1: one start record, one warp, one zoom, one tick.
**It is reverted** because `data/starts/generated.gd` is 378 lines and one four-fixture record takes the
codegen output to 412 against `check_size_limits.py`'s 400 (P037, yours). The bench script survives in
the session scratchpad against `beacon_probe`; the measurements it produced were taken before the gate
ran and are recorded in P036.

**Audit ask:** is excluding codegen'd output from `FILE_LIMIT` the right call, or should the codegen emit
per-record files? This is the second cap to block real work in one night (P034 is
`interface/observation.gd`, which is why D0565's slump event rides `Interface.services()` and not the
door). Both are yours; I have not touched `tools/`.

### 2.3 The reference is one image and I have been treating it as a target

`docs/media/reference/2026-09-10-lighting-reference.jpg` is director-supplied and the director explicitly
suspended `[[reference-images-mood-not-target]]` for it. Its README says so. But it is a **generated
mockup**, it is a **JPEG** (so my pixel-scale numbers include its compression noise, which I did not
subtract), and it is **one frame at one depth in one band**. Every "the reference wants X" number in the
ledger from tonight inherits all three.

### 2.4 THE POPULATION ERROR, found while writing this file

I reported "our rock is 3x flatter than the reference at the metre scale" and moved two constants on the
strength of it. Mean absolute luma step along a horizontal run:

| | pixel | cell (8 px) | metre (32 px) |
|---|---|---|---|
| ours, DEEP massive stone (58 m) | 0.0118 | 0.0174 | 0.0238 |
| ours, SURFACE clastic clay, band A | 0.0196 | 0.0566 | **0.1719** |
| ours, SURFACE clastic clay, band B | 0.0153 | 0.0369 | 0.0470 |
| reference, band A | 0.0077 | 0.0335 | 0.0713 |
| reference, band B | 0.0233 | 0.1003 | 0.1328 |

The reference image is **"+2 m OPEN SKY"** -- a surface frame, clastic rock. I had been comparing it
against our *deepstone*, which is `grammar: massive` and is flat **by design** (`GRAM_CLUMP` 0.25,
"pebbles in soil, not in stone"). Compared like with like, **our surface rock's texture energy is in the
same range as the reference's, and both vary more between bands than they differ from each other.**

The two constants I had moved (`STONE_THRESH`, `STONE_DARKEN`, revisiting your T017) are **reverted**,
and they had not moved the measured number anyway -- because the term they feed is scaled by
`GRAM_CLUMP[massive]` = 0.25, so I was tuning a term that was gated near zero for the material I was
measuring. `[[mechanism-vs-population]]`, twice in one item.

**Audit ask:** queue items 17 and 18 ("kill the 4 px static", "cobble grammar") rest on your diagnosis
point 2. I can no longer reproduce a static problem at all: the mean step *grows* with scale
(pixel < cell < metre), which is the signature of structure, not noise. Do you have a frame where the
static reads, and at what depth and material? If it is a surface-clay phenomenon I have been sampling
the wrong band; if it is real at depth, my grain metric is the wrong instrument for it.

---

## 3. `sim/mining` -- the new automaton (D0562, D0563, D0566)

Loose material falls; `sim/mining/slump.gd`, driven from `MineHold` on `TreeFall`'s seam.

**Claims, and how each is pinned.** `tests/test_slump.gd`, 33 asserted; `tests/test_slump_body.gd`, 7.

- **Conservation.** A step moves loose cells and never makes or destroys one -- fuzzed, 10,000 steps over
  40 random fields.
- **Determinism.** No RNG, no float, no tick index; the left/right choice is `(c.x + c.y) & 1`. Two
  identical posings finish on the same `TileGrid.state_signature()`.
- **One cell per step** (D0563), via a `_next` deferral. Without it a grain fell `SETTLE_PER_TICK` cells
  in one frame while the budget reported four cells moved -- a budget in the wrong unit for the thing it
  bounds, which is D0543's shape.
- **The body is never buried** (D0566). Loose material treats the body's cell box as rock, which is the
  refusal `BuildVerbs.place_block` already makes. Measured cause: a full burial had
  `Body._enforce_grid_bounds` eject the body to cell (38, 35) of a 40-cell world.

**Four guards, each mutation-witnessed** -- I reverted each and confirmed the suite goes red: the repose
clause, the orthogonal-crack clause, the `is_loose` gate, and the occupied-cell gate.

**What I want checked.**
- **The active set.** `sim/fluid/MODULE.md` calls "tick every cell every frame" a hard constraint. Slump
  is queue-driven and `_test_nothing_moves_until_a_blow_wakes_it` pins that an unwoken cell never moves.
  I have **not** profiled it. A wide collapse wakes three cells per moved cell; `QUEUE_CAP` is 4096 and
  drops beyond that. Is the drop-on-overflow acceptable, and is `SETTLE_PER_TICK` = 4 at 60 Hz right,
  given `TreeFall` chose 2?
- **Saves.** The queue is transient like `TreeFall`'s. A save mid-collapse leaves a column standing until
  something near it is next cut. I argued that is a wrong-looking frame and not a corrupt world. Agree?
- **`take_solidity_changes`.** I deliberately did **not** seed off it, because `WaterFlow` consumes it and
  draining it twice gives each half the other's cells. Worth confirming I read that right.
- **One seam only.** A drill boring and a machine placed do not wake the earth; only a hand blow does.
  Same limitation `TreeFall` has carried since D0438.

**A test that lied, and how it was caught.** The first version of the way-down assertion (D0568) lived at
the tail of `test_interface_verbs.gd`'s footing test and **survived reverting the rule it was written to
pin** -- an earlier blow in that sequence had already dropped the body, and `Footing.of_body` returns
nothing for a body in the air, so it was asserting over an empty list. `tests/test_way_down.gd` poses
fresh per case. I would like the rest of tonight's suites checked for the same shape.

---

## 4. Constants moved off legacy provenance

Four changes take numbers off their legacy addresses. Each is a judgment call and each has a ledger entry
with the measurement; I list them together because the *pattern* is what needs your eye, not the values.

| ledger | constant | from | to | basis |
|---|---|---|---|---|
| D0569 | `VeilLight.DEEP_FLOOR` | none | 0.55 | the deep read 0.0195 luma against the reference's 0.15-0.19 |
| D0571 | `VeilSources.MACHINE_R_M` | 2.8 | 5.0 | a machine lit its own casing: 0.151 at 1 m, 0.104 at 2 m |
| D0571 | `MACHINE_S` / `FURNACE_S` | 0.6 / 0.85 | 0.75 / 0.95 | same |
| D0571 | `VeilLight.LAMP_TINT` | 0.38 | 0.62 | the reference's lit rock is rgb (0.553, 0.340, 0.226); ours read neutral |

`LAMP_TINT` and the reverted `STONE_*` pair both revisit **director rulings** (T012, T017) rather than
merely legacy numbers. I made them under the director's standing instruction to match the reference and
flagged both rather than reversing them quietly. **Audit ask:** is the reasoning in those two entries
enough for the director to re-make the ruling, or does it read as a session overriding a ruling it found
inconvenient?

Also: `tests/test_veil_sources.gd` now pins the machine table's **shape** against its own constants
(which kinds gate on status, fuel, power; that a furnace outshines a cool machine) rather than against
literals. I think that is the right move for a table of taste constants. Tell me if it loses a guarantee.

---

## 5. What is planned, and the concepts I would like pre-audited

37 items remain. I would rather have the concepts challenged before I build than after.

### 5.1 Phase 2 remainder -- BLOCKED ON A RULING (P036)

Our lights **multiply**: the composite is `material_colour x veil_light` and `veil_light` tops out at
white, so a lit cell can never exceed the material's own base colour. The reference's lit rock is 0.377,
brighter than deepstone's base (0.197) and clay's (0.255). This is why four light constants moved the
numbers by hundredths.

Two candidates in P036: brighten every material base ~2x and let the multiply do the rest (cheap, all
data, but deliberately breaks the verbatim legacy appearance port of D0189), or add an additive pass over
the multiply (truer, needs its own clamp).

**Audit ask, and the one I most want answered before I build:** is the multiply-only model a deliberate
choice with a reason I have not found, or an artefact of the port? If it is deliberate, option 1 is the
only door and I should stop looking at option 2.

### 5.2 Items 13-16: sky light, depth haze, light shafts, bloom

All screen-space and independent of P036. `haze_painter.gd` and `post_fx.gdshader` exist.
**Concept to audit:** god-rays down an open shaft need to know where the sky is. `TileGrid.sky_floor`
already carries the first solid row per column and the observation already ships it. I intend to drive
the shafts off that rather than off a new field. Any reason that is wrong?

### 5.3 Items 19-22: strata by depth, material reads, cut faces, scree

**Concept to audit:** §2.4 has already dissolved most of item 17/18. I expect 19-21 to shrink the same
way once measured per-material rather than per-frame, and I plan to measure each against its *own*
material and band before touching a constant. Item 22 (scree at the foot of a cut) is new work and rides
on the slump: material already moves and already reports what moved.

### 5.4 Items 31-34: camera clamp, default zoom, world width, the east edge

Your diagnosis point 4 is item 31 and I have not touched it. Item 33 (world width to 64 m, P031) is a
world-gen constant and therefore decision-heavy in the loop's own lane order; it unblocks item 32.
**Audit ask:** does widening the play site to 256 cells disturb anything in the bake window, the chunk
lanes or the margin cap you measured at D0542/D0543? That is your code and I would rather ask.

### 5.5 Items 44-49: the verification tail

Item 45 is a six-seat stranger batch **started at rung 4**, which is new: every batch so far has started
at rung 0. Item 46 is your own open fixture question from
`docs/audits/2026-09-09-presentation-regime-handoff.md` -- can a vsynced window report the over-budget
count and the phase clocks while withholding `fps_wall` and the percentiles? I have not touched it and
will not without you.

Item 49 is the match loop against the reference, and after §2.3 and §2.4 I think it needs a stated
**stopping rule** before it starts, or it will run forever against one JPEG. My proposal: match on
per-material, per-band luma and texture-energy targets, sampled from a fixed bench, and stop when each
is inside the reference's own band-to-band variance. Better idea welcome.

---

## 6. Ownership

I have not edited `tools/`. P034, P036 and P037 are handed over rather than acted on. Everything else
above is `sim/`, `view/`, `shell/`, `interface/`, `tests/`, `data/` and `docs/`, and is mine to have got
wrong.
