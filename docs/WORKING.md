# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first. **Reset 2026-09-03**: the previous 500-line accumulation (the overnight
queue, lane tables, Slice 1.5, D0139) is in `git log -p -- docs/WORKING.md`; everything durable in it
is in the ledger.

**Last updated: 2026-09-03.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date.

## CURRENT STAGE — A′: lift legacy's sim hub onto the substrate (approved 2026-09-03; steps 0 and 2 done, step 1 ruled, step 3 next)

**The director approved `docs/FLIP_ANALYSIS_2026-09-02.md`'s recommendation** (FINISH, amended to lift
`FactorySim` whole; D0341). **The execution plan is `docs/A_PRIME_REFACTOR_PLAN.md`** and it is
self-contained: a session executing A′ needs only that file, the analysis, and the tree.

**Executed so far (2026-09-03), each step's status line is in the plan's §4:**
- **Step 0 — done (D0343).** `tests/test_base.gd::_finish` refuses a green that asserted nothing and prints
  the asserted count on every verdict line; `tools/test_test_base.sh` mutation-tests it (observed failing
  on the pre-fix base first) and CI runs it before the suites under gate 28. Full local sweep after:
  67/67, 0 VACUOUS. The harness-protocol transfer is scoped to that piece; the rest port with their
  subjects (list in D0343). The cross-platform probe: legacy's worldgen tallies identical on all 48 rows,
  macOS arm64 vs Linux x86_64 (emulated in a container, not native — re-run on CI before quoting).
- **Step 2 — done (D0344).** `sim/fluid/water_flow.gd` (legacy's algorithm verbatim), `sim/fluid/water_plane.gd`
  (the owner, 4 px terrain cell, running signature), two water invariants, `tests/test_water_flow.gd`
  (45 assertions, 10,000 fuzzed ticks conserved). The mixer `TileGrid` hashed with is now
  `core/state_hash.gd` (`StateHash`), shared by every plane, arithmetic unchanged, pins in
  `tests/test_state_hash.gd`. CI: 67 → 69 suites.
- **Step 1 — RULED (D0345).** Water at the 4 px terrain grid, §9 stands ("water follows the dug shape").
  The hub's 20 Hz cadence on every third 60 Hz tick and `BRANCHING.md`'s main-only rule both approved.
  Nothing blocks step 4.

- **Step 3a — done (D0346).** `data/machines` (15 records) and `data/recipes` (6) as schema-validated,
  codegen'd data carrying legacy's per-type constants as integers; `craft_cost`/`craft_count` refused by
  the validator's new `forbidden:` rule, which got the validator its first mutation test; `MachineDef`,
  `RecipeDef`, `MachineState` in `sim/machines`; `sim/machines/MODULE.md`'s must-not amended to what is
  lifted. **Finding:** `StringName` sorts by pointer, not text — `core/ordering.gd` is now the one way to
  sort ids, and every "sort keys" row of the hub goes through it.

### Next action

Step 3b onward, in the plan's order inside the step: the `sim/world` plane verbs (`set_solid`, `set_wall`,
`place_block`, conduits, ropes, torches, saplings, `block_supported`, `cell_occupied`, `surface_row`,
`ramp_dir`, `updraft_at`, foliage — `factory_sim.gd` 585-1240) against a temporary dictionary owner; this
is where `set_solid`/`place_block` call `WaterPlane.displace`. Then items; then machines + power; then
transport; then economy; then save v3; then `world_seeder`; then the `main.gd` state-logic blocks. Each
sub-step merged green on `main`. The hub keeps legacy's 20 Hz cadence on every third 60 Hz body tick
(`HUB_TICK_DIVISOR = 3`, approved D0345; ledger entry when the runner lands). `WaterFlow.step` is not
called from `Interface.apply` until step 4 opens the door. Every lifted `sort` goes through `Ordering`.

### Waiting on the director

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
