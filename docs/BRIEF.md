# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: P013 ruled and enforced, `sky_painter` lifted and DRAWING, and
Bin A run to exhaustion.** `docs/DECISIONS_LEDGER.md` D0243–D0247. **STOPPED at P015, the ◆** — Phase 2
(`terrain_painter`) does not start until you look at two images. Three PRs open and stacked: **#6**
(Phase 0's contract, parked on gate 7 alone), **#7** (prerequisites + skeleton), and this round's branch
off #7.

**Headline: the sky is on the screen.** `view/visuals/sky_painter.gd` runs through the `Frame` contract,
draws to its own canvas, and is layer-clean. Acceptance was deliberately *"it draws, it is clean, it is
captured"* — **not** *"it is correct"*, which is the one thing only your eye decides.

---

## What landed

**P013 · ruled AND enforced** (D0243). `view/` may read appearance data from `data/`. The ruling is the
cheap half; the load-bearing half is that `data` is now a **modelled** layer — an unmodelled edge cannot be
enforced, which is the vacuous-gate shape this project keeps finding. Mutation-tested both directions: a
legal `view→data` edge passes, a planted `view→sim` edge fails. `data: set()` is the line that stops
`data` laundering a dependency onward. ADR 0008; the lint's suite went 8 → 11 branches.

**`sky_painter` lifted** (D0244). ~341 lines, split for the 50-line gate. Two adaptations, both **derived
rather than dialled**: `SCALE = TERRAIN_CELL_PX / LEGACY_CELL_PX` (this world's cell is 4px, legacy's was
32), and the horizon pinned to the surface datum rather than legacy's `SURFACE_LINE * CELL`. Four
before/after milestone pairs at `docs/milestones/slice3_*_23b0ec4.png`; the horizon pair goes 168 → 199
distinct colours over the same world. Two seams also left `tests/body/reveal_scene.gd`, which was at
398/400 — `RevealArgs` (now a pure function of argv, and therefore testable at all) and `RevealRecording`.

**The empty-state class, caught** (D0245). It had landed **four times**, each time in a test written by
someone being careful. `TestBase.over()` / `_check_over()` refuse an assertion whose population is EMPTY
even when the condition is true, and say VACUOUS rather than reporting an ordinary red — *"your fixture
built nothing"* and *"your code is wrong"* must not read alike in a log. **14 call sites, 7 suites.**

**Bin A verification pass** (D0246). P014 confirmed; refs/t3 verified; two stale `seams.gd` addresses and
`sky_painter`'s "8 private fields" caveat fixed in the migration map; one null result.

**Evidence:** 42/42 suites pass, determinism included. **16 gates green**, each run bare so the exit code
is the gate's own.

## What was learned

### The guard found a live instance of its own bug on its first outing

The three fuzz suites gate on `counts[kind] == 0` across the probe's whole output. Their only population
guard was `summary_line != ""` — a **presence** check. A probe that simulated nothing *still prints a
summary line*, so `total_ticks=0` passes it and then satisfies every hard-zero assertion beneath it. The
full sweep now reads `over 1500000 item(s)` where it previously reported nothing at all. This is the house
failure class (an instrument that cannot register its subject) sitting inside the fuzzer, found only
because something made the population print.

### Two rules that stop a guard becoming decoration

Both came out of the retrofit and both now live in the guard's own docstring. **Direction:** only
assertions that PASS on empty need it. `gaps.size() > 3` already fails on an empty field, so wrapping it
adds a guard that can never fire — one retrofit was reverted on this ground, with the reason left at the
call site so it doesn't read as an oversight. **Counted, not computed:** `SEEDS * SITES.size()` is a
product of two constants and cannot register a loop body that never executed.

### Mutation-testing the guard is what made it a guard

Disabling `if count <= 0` turned the new suite red on 3 assertions — and flipped its *deliberately
failing* line to PASS, which is the vacuous pass made visible. Reaching a check is not the check firing.

### A stale number in a gate's own header is worse than one in a doc

`check_size_limits.py` still read *"`core/MODULE.md` is 98, so the headroom is two lines."* It is at
**exactly 100** and the headroom is **zero**. Someone reading the gate to decide whether they could add a
class to `core/` would have been told yes by the thing enforcing no.

## The decisions this round is waiting on

**`docs/NEEDS_DIRECTOR.md`, 10 items.** P011 and P013 are closed — both your rulings, both applied.

- **P015 — THE ◆.** Two images and your eye. Four things I noticed and deliberately did **not** tune: the
  pinned dusk values, the ridges' angular size in this world's tighter camera, the Sinkforge crown
  anchored at a spawn plateau this build doesn't have, and whether `--sky` should be on by default.
- **P016 — new.** The fuzz sweep measures `grounded_no_floor=46` against a bound of **59**, and
  `bounds=1179015` against a recorded 805,397. **Measured twice, byte-identical** — a stable count at a
  moved trajectory, not noise. Nothing is red, which is the point: 13 counts of slack is 13 counts of
  regression the gate won't catch. Not ratcheted, because D0184 is your own ruling that 59 is provisional.
- **P014 — `core/MODULE.md` at exactly 100, zero headroom.** One number. 120 restores the margin 100 meant.
- **P012 — PR #6 still parked on gate 7.** Unchanged.
- **P001, P004, P007, P008, P009, P010** unchanged.

## Anything that felt wrong even though it passed

**I wrote two capture paths into `WORKING.md` that did not exist**, from memory rather than from the tree
(`history/` instead of `docs/milestones/`), and caught it only because I ran `ls` before shipping the
sentence. The colour counts beside them were right; the addresses were not. Nothing downstream consumed
them, but a doc that names a path nobody checks is exactly the drift this round spent a commit fixing —
the D0246 pass found the same shape in the migration map, written by an earlier session for the same
reason. **The rule that catches it is cheap: resolve every path you type against the filesystem, in the
same breath as typing it.**

## Blocked, and what it's waiting on

- **Phase 2 is `terrain_painter`, and then dry.** `water_view`, `rope_view` and `falling_items` need
  `sim/fluid`, `sim/transport` and `sim/items` — still zero lines of code.
- **`data/economy/` D1-D6**, **line of sight**, the **`ValueNoise` float gap**, **three GDD
  contradictions**, **`history/`'s 168-image cull** — all unchanged, all yours.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
