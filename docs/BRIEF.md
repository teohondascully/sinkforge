# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-31. This round: the legacy gap read and ranked, four generator defects found, and
the instrument built that should have caught them years ago.** `docs/DECISIONS_LEDGER.md` D0252–D0257.
**One open PR (#10), parked on gate 7, not bypassed.** **STOPPED at P020, the ◆** — one ruling, and it
unblocks WG-2, WG-3 and the PR together.

**Headline: shelf bands carve 0 of 97,920 cells, and the test that was supposed to notice asserted
"at least one cell".** Cave coverage was `open_count > 0`. That floor cannot separate legacy's intended
~15% carve from our 3.58%, and it cannot see a band that carves exactly zero at every seed and every
coordinate. Four defects sat behind it. Nothing in this repository measured carve fraction until this run.

---

## What landed

**`docs/LEGACY_GAP.md` (D0253)** — the complete ranked backlog `docs/MASTER_PLAN_AUG30.md` §3 asked for.
The honest fraction is **16.0%**: of roughly 667 legacy capabilities, ~527 still live, and the migration
map overstated what had crossed. Four measured generator defects outrank everything in it.

**WG-1 · Only 65,536 distinct worlds existed (D0254).** `_lattice_hash` masked `seed & 0xFFFF`. Any two
seeds congruent mod 65,536 produced a bit-identical world; `SplitRng` hands out 64 bits and 48 were
discarded before reaching a cell. The existing divergence test compared seeds **1 and 2** — the defect
lived entirely in the high bits, and a test that only ever moves the bottom bit can never see it.

It carried a second, older bug out with it: `_grow_vein` had a floor and no ceiling, so topsoil glimmer
could grow past `topsoil_end`. That test was green on a coincidence of the old 16-bit field.

**D0257 · The carve-fraction instrument.** Partitioned, not pooled — 3.58% overall is equally consistent
with "carving is uniformly thin" and "carving is normal except impossible inside shelves", which are
different bugs with different fixes:

| partition | carved / eligible | fraction |
|---|---|---|
| shelf bands | **0 / 97,920** | **0.0000** |
| non-shelf | 10,488 / 195,264 | 0.0537 |
| overall | 10,488 / 293,184 | 0.0358 |

Both ratchets mutation-tested before being trusted. Two of the three assertions pin a **defect** on
purpose, so the octave port turns the suite red instead of improving the world silently.

**D0252 · Legacy's bedding and cell jitter, ported in metres.** The depth-zone tint came with them and is
**parked, not shipped** — it collided with glimmer legibility (P019). Final palette: 0.273 against a
0.244 baseline, all three metrics improved.

**D0255, D0256 · Two fixtures re-pinned**, both broken by the seed fix, both green beforehand on
coincidence.

---

## What was learned

**A divergence test is only as wide as the bits it actually moves.** `_test_different_seeds_diverge`
compared 1 against 2. The defect was a 16-bit mask. Four months of green. The replacement walks a bit up
through the word — 2^16, 2^20, 2^32 — and asserts the results are **pairwise distinct**, because the
weaker "each differs from the base" form passes on a hash that maps every offset to one single value.

**A fixture can be green on a coincidence, and the legible numbers stay green when it stops being one.**
`test_reveal_replay_driver` still reached its target column and still fired **6 dig events** after the
seed fix. Only `dug_material == glimmer` moved, from some to **zero**. The real finding is not the new
seed: only **37 of 59 seeds (63%)** qualify at all, because `find_spawn` picks a glimmer COLUMN and the
scripted approach digs at the body's ROW, and nothing in the setup makes them meet.

**Measure what the code computes, not what the constant is named after.** Checking WG-2, the first probe
called `ValueNoise.sample()` without the calibration, measured ±0.999, and appeared to *refute* the claim.
The calibration is applied by the caller — which `value_noise.gd:25` states in its own header. Re-measured
correctly: `[-0.5734, +0.5732]` over 288,000 samples. The claim was right and the check was wrong.

**An empty result is indistinguishable from a passing one without a positive control** — and this session
proved it on itself. The first local golden capture invoked `run_gd_test.sh` without its required
godot-binary argument. The wrapper printed usage and exited; the harvest pipeline found nothing; piped
through `grep`, the shell reported **exit 0**. That is `existence-probe-has-no-witness`, reproduced by the
session that had just written the memory. The same shape is why the carve instrument asserts
`shelf_eligible > 0` **before** reporting a fraction: 0.0 over an empty population is not a small number,
it is no number.

**The useful half of a mutation test can be the assertion that did NOT move.** Removing the shelf
resistance failed WG-2's ratchet and left the non-shelf figure at **exactly 0.0537** — which is what
proves the two partitions are independent measurements rather than one number wearing two hats.

**Divergence shape is evidence about cause.** The golden diverged at checkpoint **0**, not partway
through — correct for a seed that reaches the field before the first cell is written. A D0213-style
mid-run divergence would have been evidence *against* the stated cause. Coverage stayed byte-identical
across both platforms (`jumps=895 digs=261 corner_ok=9`), which separates "the world changed" from "the
probe stopped exercising the same surface".

---

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md` is at 12 items. P020 is THE ◆ and it is one ruling.**

**P020 · Port legacy's 5 octaves — and re-derive the constant that governs every ported threshold.**
Confirmed by printing it, not by trusting the plan: `FastNoiseLite` defaults to `FRACTAL_FBM`, **octaves
5**, lacunarity 2.0, gain 0.5, and legacy left it there. Ours is single-octave. The port is mechanical;
`FASTNOISELITE_SD_CALIBRATION = 0.574` is not — it was measured against the single-octave distribution, so
porting forces re-deriving it, and that constant sets the rate at which **every** legacy-ported threshold
clears. Three options are written out in full in P020. I would take (1), port faithfully and re-derive by
measurement, because the 15% gap and the impermeable shelf are the same defect wearing two faces.

**P019 · The depth tint is ported and unapplied**, because Stonereach slate-blue and glimmer teal are
hue neighbours. Two images and your eye.

**P015, P017** still open and still worth ruling together.

---

## Anything that felt wrong even though it passed

**The overnight queue did not exist.** `.claude/commands/loop.md` requires it in `docs/WORKING.md` before
a `/loop` run starts and **forbids the running session from authoring it** — the safety property is that
the queue comes from a spec you handed down. There was no such section. I transcribed Tier 0 with its
provenance stated and closed it to extension rather than inventing one, and your own message named the
same work. **It does not fully satisfy the rule.** Confirm or replace it.

**Gate 7 is red on PR #10 and I did not merge.** Instrument +1148 against game +542. §10 says park, never
bypass, so it is held open with the reason recorded on the PR. The gate's own message names the remedy —
"the next unit of work is game, not another check" — and that unit is WG-3, which is blocked on P020.
Same shape that unblocked #6: let the gate judge the whole arc, no override.

**WG-4 is untouched on purpose.** `data/strata/shallow_clay.yaml` converted its metre-denominated fields
and left every cell-denominated one verbatim, so at 0.25 m/cell every feature is 4x smaller in length and
16x in area than the constant was tuned for — while the file's own header claims "SAME ratios/behavior".
It is squarely inside the EXPENSIVE list. It is yours.

---

## Blocked, and what it's waiting on

**PR #10** — 7 commits, green on authorship, all 43 suites and headed boot. Gate 7 only. Waiting on P020.

**43 of 43 suites pass locally**; every structural gate except 7 passes locally and on CI.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
