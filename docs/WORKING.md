# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first. **Reset 2026-09-03**: the previous 500-line accumulation (the overnight
queue, lane tables, Slice 1.5, D0139) is in `git log -p -- docs/WORKING.md`; everything durable in it
is in the ledger.

**Last updated: 2026-09-03.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date.

## CURRENT STAGE — A′: lift legacy's sim hub onto the substrate (approved 2026-09-03, not started)

**The director approved `docs/FLIP_ANALYSIS_2026-09-02.md`'s recommendation** (FINISH, amended to lift
`FactorySim` whole; D0341). **The execution plan is `docs/A_PRIME_REFACTOR_PLAN.md`** and it is
self-contained: a session executing A′ needs only that file, the analysis, and the tree.

**Nothing in the plan has been executed.** No code, no instrument, no dead code was touched on
2026-09-03; that session wrote the plan, rewrote `README.md`, and archived or re-headed the stale docs
(D0342).

### Next action

Step 0 of the plan: orient, transfer legacy's harness protocol into `tools/harness/`, add the
asserted-count refusal to `tests/test_base.gd`, and run the zero-code cross-platform probe
(`legacy/tools/frontier_corpus.gd` on the Mac and on CI Linux, diff the tallies). Then step 2 (water,
verbatim). Step 1 is the director's grid-planes ruling and gates step 4 only.

### Waiting on the director

- **Step 1, EXPENSIVE:** `TileGrid` planes for machines/items/water/power at the 16 px logic cell, or a
  separate `LogicGrid`. Needs an ADR. Gates step 4.
- **Rulings the analysis surfaced** (plan §8): Splitter, Ore Vent, power gating (16 of legacy's 54 live
  tests hinge on them); the Crusher/packing/seep chain (133 lines, not on GDD §9's list); the two
  terminal-product recipes; `earth` hardness 5.6 → 6 ticks; authored ramps vs `Heightfield`; the
  resolver (P-28) before the grapple's collision half.
- **Gate 27 is red on this machine:** 36 untracked `tests/body/recordings/*.log`. Commit as corpus or
  gitignore.
- **Standing, unchanged:** `docs/NEEDS_DIRECTOR.md` P004, P015/P017, P026–P029; `TASTE_QUEUE.md`
  T001–T004; the `history/` cull.

### Two performance hypotheses to measure before any perf work (plan §7)

1. D0335 widened the play site to 256 × 1,024 = 262,144 quarter-metre cells; the one-shot bake was
   predicted to hitch near 289k and the progressive bake (`legacy/scenes/fine_terrain.gd:768-812`) is
   not ported. 2. The widest zoom rung (9.2× area) is unmeasured since the veil lightmap (D0336). Run
   `view/draw_cost.gd` at the framing the director plays, on a dig. Last measured frame at the default
   framing: 5.6 ms against 8.33 (2026-09-01).

### Known instrument defects, reported not fixed (analysis §9)

`gate_status.py` mis-addresses the double-numbered gate 30 and its NO-CODE docstring is stale;
`flaky_test_detector.py` can never parse `run_suites.sh`'s output; `run_local_battery.sh` exits 0 on
failing gates unless `GATES_ONLY=1`; `view/fx/light_layer.gd:13`'s "NO CONSUMER" is stale;
`view/visuals/erase.gdshader` is an uncited lift. `LEGACY_GAP.md`'s "15 call sites in five surfaces" is
23 in 6; `PORT_ORDER.md`'s "18 of 36" tokens is 13.

### The 120 Hz programme

Paused where 2026-09-01 left it: painters 4.01 ms, tick 1.58 ms, observe cached (D0340). Its ranked
plan is `docs/PERF_PLAN.md` (reference). It resumes inside A′ step 6 and §7 of the plan.
