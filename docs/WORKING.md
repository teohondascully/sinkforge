# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first. **Reset 2026-09-03**: the previous 500-line accumulation (the overnight
queue, lane tables, Slice 1.5, D0139) is in `git log -p -- docs/WORKING.md`; everything durable in it
is in the ledger.

**Last updated: 2026-09-03.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date.

## CURRENT STAGE — A′: lift legacy's sim hub onto the substrate (approved 2026-09-03; steps 0–4 done; step 5, the grapple, next)

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
- **Step 2 — done (D0344).** `sim/fluid/water_flow.gd` (legacy's algorithm verbatim), `sim/world/water_plane.gd`
  (the owner, 4 px terrain cell, running signature; moved from `sim/fluid` in 3b), two water invariants, `tests/test_water_flow.gd`
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

- **Step 3b — done (D0347, ADR 0009).** `LogicGrid` (one `placed` plane, saplings, running signature),
  `World` (owner of the three planes; the metre-cell derivations: solid / air / half-dug, full-face
  support, soil; `set_solid` displaces water), `PlacedVerbs` (legacy's conduit/rope/torch/sapling verbs
  minus the pack), `WaterPlane` moved into `sim/world`, `check_placed_not_in_rock`. 89 assertions.
  Deferred with reasons in the ADR: `fill`, foliage/`Flora.grow`, `surface_row`/`ramp_dir`, `updraft_at`.

- **Step 3c — done (D0348).** `sim/items`: `Pack` (cap arithmetic; slots and cap from
  `data/player/pack.yaml`), `GroundPiles`, `Landing` (the column landing, machine below via a Callable),
  `Items` (take/spill/drop/collect/resettle/lode/deposit + the ledger), `BuildVerbs` (spend on place,
  recover on removal), `DepositPlane` as `World`'s fourth plane, `check_item_conservation`. 78 assertions (D0348 and its commit said 79; the verdict line says 78 -- corrected in D0350).

- **Step 3d — done (D0349).** `sim/machines`: `Machines` (the registry; placement order is state; the
  derived `power` field, `power_throttle` per-mille), `PowerFlow` (legacy's pass in milli-units off the
  records), `Runners` (recipe, generator, hopper, pump, drill), `MachineStatus`, `MachineVerbs`
  (build/pickup with the order fix/configure); `sim/run/hub_tick.gd` (`HubTick.step` in legacy's order,
  `advance` on every third body tick). 112 assertions. **Corrected:** the deposit default is 16 a 4 px
  cell (256 a metre), not D0348's 250 a cell — stocks per cell convert ÷16, rates ×16. **Finding for
  §8:** a bored `ore_iron` block yields `ore_iron`; the recipes take `ore`/`iron`/`rich_ore`.

- **Step 3e — done (D0350).** `sim/transport/flow.gd` (`Flow`: every output to its one destination,
  the hub tick's third phase; `column_rise`; `updraft_at`), `sim/machines/movers.gd` (the lift by the
  throttle; the Freight Winch: link, trip, 40-tick flight, landing, station hold, purge on pickup or
  removal, dead-route fallback), `winch_routes`/`winch_transit` on the registry and in the signature,
  transit counted as present. 58 assertions; the machines suite re-expressed where outputs now flow.

- **Step 3f — done (D0351).** `sim/economy/production_rate.gd`: legacy's production-rate ring buffer as
  integer centi-items a minute, derived and unsigned (the plan files it "not saved"), sampled last in
  `HubTick.step` when a `ProductionRate` is handed in. 19 assertions.

- **Step 3g — done (D0352, ADR 0010).** `shell/save_game.gd`: the v3 envelope (22 keys over every plane,
  the ledger, the registry, the winch tables; 12 per machine), staged through public mutators then
  committed in place at the service level, legacy's durability protocol and read verdicts, the
  dangling-winch reconciliation. **Deviation:** v3 is this game's first version; a pre-pivot v2 save is
  refused by name (§8 row). **Finding:** walls behind air are outside the terrain signature (D0261's rule);
  the save carries them through `TileGrid.wall_terrain_cells()`. 45 assertions.

- **Step 3h — done (D0353).** `data/starts/` (a new kind: `tutorial.yaml` is legacy's opening as a record
  of fixtures in metres from the spawn; `dev_kit.yaml` the opt-in stocked pack) and
  `sim/run/world_seeder.gd` (`load_world`, `stamp` with validation before any write, `spawn_logic_cell`).
  In `run`, not `terrain_gen`: it places machines and stocks the pack. The tree and the tool kit are not
  carried. 36 assertions. **For the director:** the layout is legacy's tutorial verbatim; re-authoring
  for the rig/Skipway opening is a diff of `data/starts/`.

- **Step 3i, mining half — done (D0354).** `sim/mining/line_of_sight.gd` (legacy's float DDA re-derived
  in exact integers; pinned against a port of the float walk off the ties, which legacy decided by
  rounding drift), `aim.gd`, `dig_plan.gd` (marks are state), `lode_work.gd` (33-tick cycle, rhythm),
  `Items.yield_break` (a burst a blow, the rest opens as lode, rubble sixteenths into blocks). LOS gates
  the verbs (`Interface._apply_mine` refuses `target_behind_rock`), not the primitive. 48 assertions.

- **Step 3i, verbs half — done (D0355). STEP 3 COMPLETE.** `sim/run/verbs.gd`: build/pick-up of every
  kind by what is selected, drop into an eater or forward or down with a 78-tick grace, scoop within
  2.5 m, configure, the two-press winch link; one reach rule through `Aim.in_reach_point`. 40 assertions.

- **Step 4a — done (D0356).** The door owns every service (optional trailing constructor args; the
  three-argument shape still works); `Observation` in its own file with the hub's planes as
  window-bounded copies and the consumed flow-event channel; `MOVE` runs the hub every third tick;
  `Interface.state_signature()` over the whole session. 20 assertions.

- **Step 4b — done (D0357). STEP 4 COMPLETE.** Nine `Command` kinds with details and named reasons;
  the mine hold rides the move frame's aim (no second input format); `Session.capture`/`restore` (shell)
  compose the session's save with the body's and the mining state's keys (the body required, checked
  before the sim is touched); `Session.new_game` stands the body on the seeder's spawn. 34 assertions.

### Next action

**Step 5, PRE-2 and the grapple** (plan §4): `core/fixed_point.gd` gains `normalize`, `dot`,
`limit_length` (~40 lines, tests over hostile inputs, both roundings toward less energy);
`sim/body/grapple.gd` from `legacy/scenes/grapple.gd` rewritten under `Fx` (`PUMP_CLAMP 1.05` stored as
`21/20`; the two `delta` sites become per-tick integers; the aim is a recorded world cell); the swing
coupling in `body.gd`; the nine missing body mechanisms from `player.gd` (rope climb, lift updraft,
water wading, over-speed coast, step-down snap, machines-block, ramp glide (ruling), `place()`, carry
weight); `view/visuals/rope_painter.gd`; `tests/test_grapple.gd` from legacy's rope checks. **Ruling
gate:** the grapple's collision half touches the resolver (P-28); build the `Fx` layer and the solver
first, the collision hookup waits. Golden re-pinned from CI Linux if body state changes. The plan's
original text for step 4 follows, for the record: `Command` gains `mine_point`/`work` (the mine-hold loop:
paint the plan, snap the aim, drain the plan, mine or work the lode, yield), `build`, `drop`, `collect`,
`configure`, `link_winch`, `select`, `clear_plan`, with named rejection reasons; `Interface.capture()`
/`restore()` add the body's and the mining state's keys over `SaveGame`; `Interface.new_game(site,
seed, start)` builds a session from the seeder with the body at the spawn. Then step 5. The plan's
original text for step 4 follows: `Interface` owns `World`, `Items`, `Machines`, `Mining`, `Verbs`, a
`ProductionRate` and the `HubTick` cadence; `Command` gains the verb kinds (`build`, `drop`, `collect`,
`configure`, `link_winch`, `select`, `paint_plan`, `work_lode`; the fixture primitives) with named
rejection reasons; `Observation` gains the accessors legacy's renderer reads (deposits, lode per mille,
machines and their status, water per cell, conduits and power, torches, piles, saplings, the pack, the
plan, climbable); `observe()` stays pure against `state_signature()`; the save grows the body's and the
mining state's keys (ADR 0010 §1); the golden re-pinned from CI Linux if the world's contents change
(the seeder in the probe would; keep the probe as it is unless step 4 needs it). Then step 5 (the
grapple; the resolver ruling gates its collision half), step 6 (views), step 7 (the economy, director-
scoped), step 8 (cross-platform). Old text follows for the record: **the `main.gd` blocks** (legacy's
seeded placement of lodes, deposits, water onto the generated shaft). Then the **`main.gd` state-logic
blocks** the plan's §3 lists. Each sub-step merged green on `main`. `HubTick.step` is not called from
`Interface.apply` until step 4 opens the door. Every lifted `sort` goes through `Ordering`; every lifted
`call(name)` becomes a `match`; every per-cell constant is asked "per what?".

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
