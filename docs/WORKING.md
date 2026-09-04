# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first. **Reset 2026-09-03**: the previous 500-line accumulation (the overnight
queue, lane tables, Slice 1.5, D0139) is in `git log -p -- docs/WORKING.md`; everything durable in it
is in the ledger.

**Last updated: 2026-09-03.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date.

## CURRENT STAGE — A′: lift legacy's sim hub onto the substrate (approved 2026-09-03; steps 0–5 done; step 6, the views and the boot scene, in progress: 6a water, 6b the look registries, 6c the machine painter, 6d payouts, 6e falling items and 6f (i) the beds done)

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

- **Step 5a — done (D0358).** `Fx.normalize`/`dot`/`limit_length`: `Vector2i` pairs of `Fx`, a ceiling
  root and truncated components so neither division can add energy; the i32 minimum clamped on entry.
  17 assertions.

- **Step 5b — done (D0359).** `sim/body/grapple.gd`, legacy's ninja rope under `Fx`: identical pixels
  (480 px of line, 30 px/tick flight, 7 px/tick reel), the probe one terrain cell so the ghost and the
  hook agree, the wrapping polyline, projection and radial cancel through the raw delta over a ceiling
  root (a 16-bit unit vector fell a hundred units short at a 100 px radius), the pump as one 21/20 ratio.
  63 assertions. The coordinate gate gained the `fx` tag for fixed-point pixel points (mutation-tested).

- **Step 5c — done (D0360).** `Surroundings` (bare terrain) / `WorldSurroundings` (machines, ropes,
  water, drafts) as the body's only window on the world beyond terrain; `body_swing.gd` couples the line
  after both axes collide, with the COLLISION STAND-IN (a projected position into rock is refused, the
  line reads slack for the tick) pending the resolver ruling; `body_medium.gd` is water, rope climb and
  the lift's draft; the coast above top speed; the step-down snap in the resolver; a machine is ground and
  wall alike (the heightfield and the floor diagnostic take the body's predicate); `place()`. The ramp
  glide is NOT ported (§8 ruling). Legacy's rope floors pass with room (swing 419 px/s vs 172; lift 240 px
  vs 96; the chasm crossed; 0.89 kept on release). 69 assertions in two suites. The body corpus held
  without a re-pin; the shaft-replay golden moved at checkpoint 0 with identical coverage (a re-pin).

- **Step 5d — done (D0361). STEP 5 COMPLETE.** `view/visuals/rope_painter.gd` on the `Frame` contract:
  placed ropes, the bowed cord (legacy's `rope_sag`), the hook wedge, the aim ghost from the door's own
  trace, three observation booleans so the view never names the sim's enum; `carry_look.gd`. 20
  structural assertions; the look itself is the director's call at the play scene (`ROPE_Z = -10`).

- **Step 6a — done (D0362).** `view/visuals/water_painter.gd` (legacy's water look on `Frame`, layout
  split from paint, world textures at ×0.5), `view/fx/water_drips.gd` (the drips write the particle
  layer from the observation), `Observation.wet_cells` (the sparse walk). 33 assertions. The capture
  pair waits on a start record with water in frame; the look is unverdicted.

- **Step 6b — done (D0363).** The three look registries as four view files, dead entries out, the
  machine record's `source` flag so the view never sees a def, the ground's colours off the material
  records, purposes re-authored; pinned against the data (27 assertions).

- **Step 6c — done (D0364).** `machine_painter.gd` + `machine_labels.gd`: legacy's machine view on
  `Frame`, stateful for the construction flash and the per-frame nameplate plan; the record carries
  `name`/`recipe`; cell-sized casing and glyph, chrome at `CHROME_SCALE = 0.5`; the load well and the
  guide rule not ported (stated). 35 assertions. Machines draw in the play scene at `MACHINE_Z = -30`.
- **Steps 6d and 6e — done (D0365).** `view/fx/payouts.gd` reads gains off the PACK (a rise between two
  observations; a spend is not a payout; the first frame primes), merges nearby-soon ticks, 21
  assertions. `view/fx/falling_items.gd` on the consumed flow channel: drops at the fine-detail scale,
  landings merged by cell and consumed once, the cull box derived and stable; the SCENE owns the
  instance (painted at `FALLING_Z = -25`, landings popped into the particle layer), 25 assertions. Both
  suites first reported ALL PASS with their real-frame test unawaited (memory:
  unawaited-test-counts-before-it-runs); fixed. No eye verdict on either visual yet.
- **Step 6f (i) — done (D0366).** The ten beds: `view/audio/bed_bank.gd` (legacy's loops on the split
  RNG, every buffer padded so the loop closes on whole cycles, 44 assertions), `beds.gd` (the driver;
  mix maps static, rates named, `ambience_db` injected, 23), `bed_levels.gd` (the eight levels off the
  observation; depth against `Observation.SKY_ROWS`, the generated datum; the haul stateful, 37). The
  play scene's audio moved into `tests/body/reveal_audio.gd`. Pending under (ii): the one-shot voices
  and the space bus. No ear verdict.

### Next action

**Step 6, the views the systems unblock and the boot main scene** (plan §4 step 6, §3.2's view table in
`PORT_ORDER.md`'s sequence): `water_painter.gd` (no water painter exists), the machine look/painter and
the item/status looks, `payouts.gd`, `falling_items.gd` on the consumed flow-event channel, the sfx
beds, the HUD split (hotbar, inspector, minimap, objective card, alerts), hints/hover/objectives with
every content table re-authored, the settings page; and the boot main scene in `shell/` (no main scene
exists; `--play` is a debug scene; the view never calls `apply`). Look verdicts are the director's. Then
step 7 (economy, director-scoped rulings) and step 8 (cross-platform determinism). **Open rulings from
step 5 (plan §8):** the resolver (the swing's collision stand-in), the ramp glide.
