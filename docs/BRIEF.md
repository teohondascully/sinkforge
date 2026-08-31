# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-30. This round: P013 ruled and enforced, `sky_painter` lifted and DRAWING, Bin A
run to exhaustion — and then you played it, which found more than the run did.**
`docs/DECISIONS_LEDGER.md` D0243–D0250. **NO OPEN PRs**: #6, #7 and #8 are merged as one rebase of 17
commits, P012 closed with them. **STOPPED at P015, the ◆** — and P015 should now be ruled together with
**P017**, because you found that the sky has no air in it.

**Headline: the sky is on the screen, and you cannot jump into it.** `sky_painter` runs through the
`Frame` contract, draws to its own canvas, and is layer-clean. Then you played it and found that row 0 is
the surface, the top of the world, and the horizon simultaneously — so the backdrop this run lifted is
drawn into a region the player is physically barred from entering (D0249, P017).

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

### The invariant guarding the ceiling is indistinguishable from the defect

You could not jump above the surface. `test_reveal_spawn_bounds` measures that exact region on every run
— it holds JUMP from every spawn and asserts the head never reaches y=0 — and **passes**. "The player
cannot leave the world" and "the player cannot leave the ground" are the same measurement taken from
opposite intents, so no amount of test-writing would have surfaced this. Only someone trying to jump
could. Row 0 is the surface datum, the top of the grid, and `HORIZON_Y` at once; legacy had 20 rows of
air and re-keying the band ladder to metres-below-surface dropped them silently, because nothing had ever
been drawn up there to notice.

### Nothing in this repository had ever opened a window

42 suites, 16 gates, three CI checks — all `--headless`. So a scene could boot, render, satisfy every
assertion here, and still not do what its own header tells a human to type. That is what you hit. The
deepest of the three defects was that `_test_every_flag_is_reachable` **could not see** the missing
`--play`: it drew its population from the parser's own keys, making it complete about what the parser
declares and blind to what it omits — the same shape as the vacuous-population class I'd spent the run
building a guard for, one level up.

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

**`docs/NEEDS_DIRECTOR.md`, 10 items.** P011 and P013 closed by your rulings; **P012 closed by the merge**
(D0250).

- **P017 — new, and I'd rule it WITH P015.** There is no air above the surface: row 0 is the surface, the
  grid's ceiling, and the horizon. Your jump has a 74px apex (~18 rows) and nowhere to spend it. Whether
  the sky is enterable decides several of P015's look calls — the ridges' angular size, the crown's
  anchor, whether `--sky` defaults on. Three options in the entry; I picked none, because adding air rows
  changes what every existing capture, recording and spawn-row derivation means.

- **P015 — THE ◆.** Two images and your eye. Four things I noticed and deliberately did **not** tune: the
  pinned dusk values, the ridges' angular size in this world's tighter camera, the Sinkforge crown
  anchored at a spawn plateau this build doesn't have, and whether `--sky` should be on by default.
- **P016 — new.** The fuzz sweep measures `grounded_no_floor=46` against a bound of **59**, and
  `bounds=1179015` against a recorded 805,397. **Measured twice, byte-identical** — a stable count at a
  moved trajectory, not noise. Nothing is red, which is the point: 13 counts of slack is 13 counts of
  regression the gate won't catch. Not ratcheted, because D0184 is your own ruling that 59 is provisional.
- **P014 — `core/MODULE.md` at exactly 100, zero headroom.** One number. 120 restores the margin 100 meant.
- **P001, P004, P007, P008, P009, P010** unchanged.

## Anything that felt wrong even though it passed

**Everything I shipped this round was green, and you found two real things in about ten minutes of
playing.** Not by reading the code — by typing the command I documented and then trying to jump. Both
findings are in classes this repository has written extensively about, and both sat under a full green
board: one because no instrument opened a window, one because the test covering the region reads the
defect and the invariant identically. The lesson I'd carry is not "write more tests" — it is that **a
green board is evidence about the instruments, and the instruments here had a shared blind spot that only
a person at the keyboard could stand outside of.**

**I also dated two ledger entries 2026-08-31**, taken from GitHub timestamps and from recording filenames
Godot writes in UTC. `date` says 2026-08-30 23:16 PDT and every other entry follows the local commit
date. Corrected before they hardened — but it is the same class as the path I invented earlier in the
run: a constant that *feels* derived rather than looked up.


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
