# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-02. This round: the FLIP-vs-FINISH feasibility analysis you asked for —
Phase 1 only, analysis and recommendation, nothing executed.** Report: `docs/FLIP_ANALYSIS_2026-09-02.md`.
Ledger: D0341. Four doc files changed; no code, no branch, nothing under `legacy/` touched.

**Headline: legacy's sim was never the non-deterministic part.** `FactorySim.tick()` is already
node-free, fixed-tick at 20 Hz and integer-shaped — 24 live breakers, 77 lines, all mechanical. The
non-determinism is the *scene layer*: two clocks (`sim.advance(delta)` in `_process`, the body in
`_physics_process`) and state decided at frame rate in `main.gd`, `player.gd` and `grapple.gd`. That is
23 rows out of 172, one structural fix of ~250–350 lines plus ~55, and the rebuild has already
replaced its two largest pieces (`sim/body`, `sim/mining`). `FastNoiseLite` is not on legacy's state
path. So the flip does not buy determinism; it buys day-one playability at the cost of the architecture.

---

## What landed

**A complete read of every code file in the repository**, not a sample: 491 files (210 legacy, 281
current) enumerated by `git ls-files`, split into 17 disjoint slices, read by 17 read-only workers,
with a mechanical self-check — **491 of 491 accounted, 0 unaccounted, 0 duplicated** — before any
conclusion was drawn. 197 breaker rows aggregated (172 legacy, 22 current, 3 host-bound tests), each
with `file:line`, class, severity and conversion cost. 14 of 14 randomly sampled citations verified
against the tree. Control greps with a positive control.

**The determinism verdict:** within-platform, about one working week. Cross-platform: open in BOTH
trees — legacy carries 102 float rows (52 in the world generator), the current build carries 16 of the
same class on its own terrain path (D0171/D0183, still at HEAD). Same fix either way.

**The recommendation: FINISH, amended.** Lift `FactorySim` + `water_flow` + `power_flow` + `flora` +
`save_game` into `sim/` as a block, split at their own seams (A′, 4.5–5.5 weeks), instead of
per-component (A, 5.5–7) or the flip (B, 3.5–4 weeks, which forfeits the layer boundaries, size caps,
L2 door and the 4 px world). Low–medium confidence on every duration; the ratios are firmer.

---

## What was learned

1. **The brief's premises did not survive measurement, and each error ran in the same direction.**
   Legacy took 27 commit-days from 2026-06-27, not "under a week" (FactorySim is in commit 2). The
   rebuild's game-LOC/day is at parity with legacy's (1,146 vs 1,056). The port is 35.9% by raw lines,
   ~44% of live legacy. Legacy has 143 harness files and its own same-process determinism corpus. The
   "wall-clock `advance`" is a ten-line accumulator over a fixed tick. Measure the tree, not the story.
2. **What is actually slow, and why (C2's finding).** Three of the ledger's headline performance wins
   — D0330, D0336, D0337 — are restorations of architecture legacy already had and the port dropped;
   3,930 of `view/`'s 5,878 lines are smaller re-expressions of larger legacy originals. The rebuild has
   been re-deriving leaves without porting the architecture, and treating the sim hub as KEEP-CURRENT
   when its machines/items/water/power half has no current equivalent at all.
3. **The flip's real cost is structural, not determinism.** Of 39 CI steps, 24 drop onto legacy free
   and 11 are red on contact (15 game files over 400 lines, layer lint by construction, ~70 engine-import
   lines). And five structural gates print `PASS (vacuously)` on a tree with no `core/` or `sim/` — a
   flip that forgets the remap keeps a green CI with the architecture switched off.
4. **`sim/body` does not lift back onto legacy.** Every determinism-carrying `sim/` file takes a
   `TileGrid` (4 px terrain, 16 px logic); legacy's authoritative grid is a 32 px dictionary and its body
   is 0.44 cells wide. No facade exists in either tree. Converting `player.gd` in place is cheaper — and
   a flip therefore does not inherit the 102 body tests.
5. **Legacy has instrument discipline the current build lacks** (L10, L12): a runner protocol with
   VOID verdicts, stand-downs, a machine lock, a save sentinel and quotability gates (~1,850 lines of
   shell), and a `check_base._verdict` that refuses a green which asserted nothing. `tools/run_suites.sh`
   has none of it. Transfer regardless of the decision.
6. **My own probe returned zero for every pattern once**, including one I knew was there: zsh does
   not word-split a two-directory variable, so `git grep -- $G` searched a path that did not exist. Caught
   by the positive control, not by looking at the numbers. The house failure class, in my hands.
7. **Six workers "failed" per the harness (a session rate limit cut their final message) and all six
   had complete reports on disk.** Neither the failure notice nor a completion message was evidence;
   the mechanical 491/491 self-check was. Also: my dependency graph drew one edge that was a
   name-shadow artefact (`factory_sim.gd:19`'s local `FineTerrain` const); L3 caught it.

---

## The decisions this round is waiting on

**The go/no-go.** A′ (finish, lift the hub whole) is the recommendation; B (flip) is viable, planned in
the report, and roughly a week faster on this evidence at the price of the thesis. Phase 2 of either
does not start without your word.

**If A′: one EXPENSIVE ruling before the lift starts** — giving `TileGrid` the machine/item/water/power
planes at the 16 px logic cell (legacy's 32 px cell is one metre; so is this build's 16 px logic cell;
the 4 px terrain and heightfield collision stay). It shapes the tick order's data, which is your call.

**Three rulings the read surfaced regardless:** the Splitter, the Ore Vent and power gating (16 of
legacy's 54 live tests hinge on them); and the Crusher/packing/seep chain (133 lines that exist only for
the Drift Rig and are not on GDD §9's list).

**Standing:** P026–P029, P004, P015/P017, T001–T004, unchanged.

---

## Anything that felt wrong even though it passed

**The durations are estimates over a rate that is not stationary.** Aug 25–29 ran +235 game lines a
day; Aug 29–Sep 1 ran +2,665. The sequential model has one day of data. I committed to numbers because
a decision needs them, and stated the confidence; the ratios between directions are what I would
trust, not the absolutes.

**Nothing was run.** No test, no game, no probe. Everything in the report is a read of the tree, with
greps and a spot-check as the controls. Four questions in the report's §9 are only answerable by a run
— `randi_range`'s integer purity, `store_var`'s double round-trip, `str(float)`'s precision, and whether
IEEE ops actually diverge across the two CI platforms — and the last has a zero-code probe waiting
(`legacy/tools/frontier_corpus.gd` on both platforms).

**Three instruments in the current suite are quietly wrong today** (C5): `gate_status.py`
mis-addresses the double-numbered gate 30 and its NO-CODE docstring is stale; `flaky_test_detector.py`
can never parse `run_suites.sh`'s output; `run_local_battery.sh` exits 0 on failing gates unless
`GATES_ONLY=1`. And gate 27 is red on this machine (36 untracked recording logs). Reported, not fixed —
out of this task's scope.

---

## Blocked, and what it's waiting on

**Phase 2 — on your go.** The 120 Hz programme and the sequential port are paused where WORKING.md
left them; PR #47 merged 2026-09-02 and D0340 landed after it, so nothing is in flight.

**Determinism status unchanged:** gate 8 green on CI's Linux build at the last re-pin; the four
D0183 float sites confirmed still present at HEAD (three at drifted line numbers).

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
