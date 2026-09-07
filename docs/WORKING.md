# Working state

Not a log. Current stage, what's actually happening, and what would be lost if this session ended
right now. Updated as work happens. Resets when a stage closes — durable content moves to an ADR,
a MODULE.md, or a claim first. **Reset 2026-09-03**: the previous 500-line accumulation (the overnight
queue, lane tables, Slice 1.5, D0139) is in `git log -p -- docs/WORKING.md`; everything durable in it
is in the ledger.

**Last updated: 2026-09-07.** Bump this date whenever this file changes — a CI gate fails if it's
older than `HEAD`'s own commit date.

## CURRENT STAGE — A′: lift legacy's sim hub onto the substrate (approved 2026-09-03; steps 0–5 done; step 6, the views and the boot scene, in progress: 6a water, 6b the look registries, 6c the machine painter, 6d payouts, 6e falling items, 6f the audio, 6g the hotbar, 6h the inspector, objectives and hints, 6i the minimap, 6j the settings page, 6k the lights, 6l the ore seams and the veil's sources, 6m the marks, 6n the ambience, 6o the surface, 6p the shaders, 6q the boot done -- step 6 complete; step 8, the worldgen content, in progress: 8a the determinism half closed by measurement, 8b relief and scarps, 8c rifts and sinkhole mouths, 8d ledges/spires/rubble/droughts, 8e aquifers and lodes, 8f the richness field, 8g trees, 8h the switch-on done -- step 8 complete)

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
  play scene's audio moved into `tests/body/reveal_audio.gd`. No ear verdict.
- **Step 6f (ii) — done (D0367).** `voice_bank.gd` (eleven one-shots, 39), `voice_cues.gd` (every
  one-shot as an edge over two observations, three scalars remembered rather than the object, 39),
  `sfx_space.gd` (the room and occlusion off the observation, 20); `Sfx` gains grain banks, `ui()`,
  `sound_db`, `step_voice` off the data's hardness; the fallback is legacy's `crunch` (D0313's `hollow`
  stood in while no crunch existed). Not ported with reasons: ding/chime, boom, skid. No ear verdict.
- **Step 6g — done (D0368).** `view/hud/hotbar.gd`: legacy's hotbar, chevrons, tooltip and PACK FULL
  chip on the layout/paint split, legacy's rules (a window that contains the selection, digits that
  stop with the keys) and geometry under `UiTheme.px`; 35 assertions. Mounted via `_mount_hud`. The
  selection verb is shell work; the inventory overlay is the bazaar's and stays dead. No eye verdict.
- **Step 6h (i) — done (D0369).** `view/hud/inspector.gd`: legacy's readout and panel merged, every
  content line re-authored for the machines here, `describe()` off the observation alone (new field
  `aim_in_reach`; the rate line off the economy's list), the panel under legacy's width rules with the
  ellipsis, standing down under a visible arrival plate; 43 assertions. Knobs and the tier line not
  ported (verb / dead gate). No eye verdict.
- **Step 6h (ii) — done (D0370).** `objectives.gd` (the ladder off the observation, nine steps
  re-authored, 25), `hints.gd` (nine pack lessons + six moments, the controller's pokes computed off
  the observation, 26), `objective_line.gd` (16) and `hint_bubble.gd` (18) in the chip shape, both
  consulting the plate. Taught ids exposed, not yet saved (shell). No eye verdict.
- **Step 6i — done (D0371).** `TileGrid.coarse`: a class byte per logic cell maintained at the three
  mutators, versioned on change, outside the signature; `Observation.map/map_cells/map_version/
  map_machines`; `view/hud/minimap.gd` keyed on the version (the plan's correction of legacy's
  count-keyed cache), corner form on by default; the inspector stacks under it. 24 + 49 assertions.
- **Step 6j — done (D0372).** `settings_page.gd` (legacy's pure half on the four actions, the values a
  shell snapshot, hits registered by the draw) + `settings_draw.gd` + `page_draw.gd` (legacy's page
  primitives) + eighteen theme tokens; mounted closed and last. 32 + 9 assertions. Opening key and the
  snapshot are shell work.
- **Step 6k — done (D0373).** `view/visuals/light_painter.gd`: legacy's S2 additive pass on an ADD
  canvas at `LIGHT_Z = -44` over the veil; the lamp bloom shares the veil's pool centre and depth scale;
  machine pools by kind/status grouped by light at the brightest member; godrays per logic column;
  torches, conduits, motes, the water skin's sheen. 31 assertions. No eye verdict yet.
- **Step 6l (i) — done (D0374).** `view/visuals/ore_painter.gd`: legacy's S4 flood with the link in
  metres (3 m = 12 cells, floor one metre of face, radius capped at the torch's 7.6 m), the population
  the glint's own cache, the seam glow in the seam's mineral hue on a second ADD canvas, pips one face
  cell in four; the lode's flecks a live pass at `LODE_Z` over the wall's baked socket, draining
  monotonically by per mille. 43 assertions.
- **Step 6l (ii) — done (D0375).** `view/visuals/veil_sources.gd`: every light but the lamp cuts the veil,
  legacy's table as data with a colour at 0.28 toward white; `VeilPainter.light_rgb_at` composes per
  channel (a cut only ever adds); `VeilMap` writes tinted texels. One glint, one ore painter, one
  falling-items layer shared across the veil, the light canvas and the glint. 37 assertions. The lamp's
  own cuts stay untinted (follow-up).
- **Step 6m — done (D0376).** `view/visuals/mark_painter.gd` + `mark_layout.gd`: legacy's mark grammar
  as a list a test fails on (square/corners/bar/dash/ghost/previews/feed lip/hint, the dig plan's region
  outline); `interface/aim_planes.gd` answers placeability, the feed mouth, the hint and the rope and
  drill previews from the verbs' own predicates; the stars step aside for a ghost. 43 assertions. Not
  here: the objective chevron (no cells), dead-machine previews, the tier refusal.
- **Step 6n — done (D0377).** `view/visuals/ambience_painter.gd`: legacy's S6 placed-plane clockwork
  (tubes with power beads that never flow up, torches, saplings, piles capped at four in name order,
  updrafts above lifts, guides under machines, speed streaks) as functions a test fails on, on two
  canvases around the machines. 40 assertions. Saplings never grow yet (no sim rule; step 7's).
- **Step 6o — done (D0378).** The terrain remainder in this regime: legacy's coarse chamfers, fillets
  and edge AO ruled not portable at the 4 px cell (sub-pixel; legacy ran them only where its fine layer
  did not cover). `view/visuals/surface_tone.gd` (owned by `RockTone`): the soil profile below the
  column's own surface, moss on shallow exposed tops, tufts under lips, and the cap on the band-gated
  walked line with roots and blades; `TerrainPainter.cell_fill` applies it. 29 assertions.
- **Step 6p — done (D0379).** The two shaders: `heat_haze.gdshader` (legacy's, on `anim_time`) with
  `haze_painter.gd` (plumes over working forges and burners; the painter feeds its layer's clock) at
  HAZE_Z; `rock_tooth.gdshader` (legacy's, 1/32 m cell kept) bound to `gram_map.gd`, a byte per cell the
  bake fills as it paints and refills on a dig, mounted by `tooth_layer.gd` as the baked quad drawn again
  over the veil. 18 + 22 assertions.
- **Step 6q — done (D0380).** `godot --path .` runs the game: `shell/main.tscn` + `main.gd` (the seat: the
  session on the tutorial start, the tick through the door, the verbs, the camera rig, the effects, the
  save on close and F5), `play_input.gd` (edges, aim, verbs), `hud_bridge.gd` (the settings snapshot and
  payloads, capture, keys). `ViewStack`, `SceneAudio`, `MinerDraw` moved into `view/`; the hints' lessons
  ride the save. 36 assertions; `check_headed_boot.sh` case C boots `godot --path .` to its thirtieth
  tick. Owed: the settings page's remap rows for the eleven new actions.
- **Step 8a — done by measurement (D0381).** Gate 8's golden, pinned from CI Linux, matched at all 200
  checkpoints by a local macOS-arm64 run that digs generated terrain 360 times (ALL PASS 21). The plan's
  "diverges at checkpoint 3" was D0167's world; the four float sites use IEEE basic ops only and stay.
- **Step 8b — done (D0382).** `sim/terrain_gen/relief.gd` (`Relief`): legacy's pad, three waves and
  scarps, the sines from `SIN_MILLI` (a 256-entry integer table), all integer; the generator's surface
  is a row per column through every pass (`CavePasses` take per-column floors). Config-gated on a site's
  `relief:` key — `shallow_clay` has none yet, so the golden is unchanged. 44 assertions.
- **Step 8c — done (D0383).** `sim/terrain_gen/vertical_passes.gd` (`VerticalPasses`): rifts that pinch
  and open on the sine table, ore in their walls by depth, the sinkhole mouths over the deepest falls
  with the `pow(x, 2.2)` flare as a table. Gated on a site's `vertical:` record; `spawn_col_m` is the
  new optional site field the keepouts measure from. 39 assertions; the golden unchanged.
- **Step 8d — done (D0384).** `sim/terrain_gen/studding_passes.gd` (`StuddingPasses`): ledges a metre
  thick from a wall with headroom, teeth tapering from a metre to a cell, rubble standing only over
  what holds it, and the drought pass that plants a vug or a vein wherever a column runs 18 m of plain
  rock. Gated on a site's `studding:` record. 33 assertions; the golden unchanged.
- **Step 8e — done (D0385).** `sim/terrain_gen/plane_passes.gd` (`PlanePasses`): aquifers carved and
  flooded on the water plane with a vein off the rim, lodes grown on the deposit plane with per-cell
  amounts by the start record's rule; `ShaftGenerator.enrich(world, site, seed)` runs them after the
  grid and `WorldSeeder.load_world` calls it. `ContentPasses` holds the order of every gated pass.
  Gated on `aquifer:`/`lode:` records. 31 assertions; the golden unchanged.
- **Step 8f — done (D0386).** `sim/terrain_gen/richness.gd` (`Richness`): legacy's per-column richness
  field as an integer band on a lattice from the stream's own split, mixed with the spawn-distance ramp;
  the ore and coal scatters' acceptance and size and the lodes' amounts read it. Gated on a `richness:`
  record. 17 assertions; the golden unchanged.
- **Step 8g — done (D0387).** `sim/terrain_gen/tree_pass.gd` (`TreePass`): trunks of `wood` two to three
  metres tall with an elliptical canopy of `leaves`, one at most every 3 m, none over a mouth or on the
  pad; the two materials with legacy's colours and hardness on this build's scale. Gated on a `tree:`
  record. 21 assertions; the golden unchanged.
- **Step 8h — done (D0388).** `data/strata/shallow_clay.yaml` carries `spawn_col_m` and the seven content
  records. The real world showed three things no fixture had: no mouth at the boot seed (legacy's 20 m
  keepout on a half-width world; now 12 m), rift-wall ore as 4-px specks collapsing the ore-body pin
  (now metre-square nuggets; the pin measures the scatter on the plain site), and CI's mining rule that
  hardness is whole halves (wood 2.0, leaves 0.5). The golden re-pinned from CI Linux. 17 assertions.

### Performance (the three-pass round, 2026-09-04; D0390)

**D0389's "100fps" was the Engine counter and was wrong; the director felt "20fps" and was right.** The
wall-clock meter (`godot --path . -- --perf` at standstill, `--perf-drive` on a scripted walk;
`shell/frame_meter.gd`) found one 30 ms stall per hub tick at standstill and 60-110 ms stalls on every
camera move. D0390 removed them at the cause: the water rest marker (hub tick 15 → 0.4 ms), per-plane
`HubCache` keys, `TileGrid`'s flat index planes (a window is row slices), the veil on the GPU
(`veil.gdshader` + `VeilLayer`, the CPU `VeilPainter` kept as the reference), and the glint/seam caches
keyed on the terrain version.

| moving camera (15 s) | before | after |
|---|---|---|
| frame p50 / p99 / max | 8.9 / 93 / 112 ms | 5.6-7.4 / 21 / 24 ms |
| frames over 16.7 ms per 5 s | 44 | 14-19 |
| physics p99 | 12.7 ms | ~5 ms |
| painters per frame | 6.0 ms | 2.0 ms |

Standstill: zero frames over 16.7 ms. **The honest ceiling:** 120 fps sustained, with one 120 Hz frame
dropped on each observation-window re-centre (about once a second walking): the lode plane's record build
(~1.5 ms), the metre field (~0.7 ms) and the glint scan (~1.2 ms) all rebuild on the snap; the sky painter
costs 1 ms every frame. Determinism untouched: `test_shaft_replay_determinism` ALL PASS 21 after every
change, the golden unmoved. Captures of the REAL seat: `godot --path . -- --fresh --warp=col,row --zoom=Z
--screenshot-tick=40 --screenshot-out=PATH [--act=mine|map|settings]` (`shell/seat_flags.gd`).

### The look pass (D0391–D0393)

`docs/VISUAL_QUEUE.md` v2: 55 entries from 22 captures of the real seat, four root causes (rock and void
at one value; a per-cell static with no form; a grey light; an unclamped camera). Executed here, each
one constant and reversible: legacy's light composition on the GPU veil (ambient dark, skylight scatter
under each column's `sky_floor`, the void floor, the amber lamp), the camera clamp wired, the miner and
the factory under the veil with the halo gone, the map unmarked of ore and modal when large, the arrival
plate primed for a second, the banner a step smaller, the horizon seam closed. **Before/after pairs are on
disk at `tests/body/recordings/look_pass_2026-09-04/{before,after}/`** (ignored, not shipped; the
director selects what moves into `history/`). Six taste forks queued, T012–T017; the three generation
forks (the pad, aquifer depth, Stonereach density) each move the golden and wait on the director.

### A+ state (D0394)

Instruments: `run_local_battery.sh` exits non-zero on a gate failure; `flaky_test_detector.py` parses
`run_suites.sh`'s real format; gate 27 green (recordings ignored); the second gate 30 is gate 36 and
`gate_status.py` runs end to end again (2 m 19 s, progress on stderr: 36 gates, 26 with enforcing code,
10 NO-CODE prose gates [5, 6, 10, 11, 12, 17-21], FAIL [], ADVISORY [14, 33]). The vacuous-green hunt
found one `_check(true)` outside the crash probes (the crack painter) and it now asserts a plan. Fifty
dead legacy files are gone; the in-file dead ranges stay for the line citations. Four files sit at
exactly 400 lines (the cap, not over it). Local gate battery on f3f39a59: 28 PASS, 0 FAIL.

### The two-phase round (2026-09-05; D0396–D0404, on main)

**Phase 1 (done).** F1: the director's slot, driven headless through the seat's hand, showed the stuck
state was the seat's: `PlayInput` built `climb_dir` with up = -1 against the +1 contract, so W paid the
line out and S reeled in (D0396). Fixed; the settings page gained a GAME face (RETURN TO SURFACE, NEW GAME
on a second press), the rail answers a click, digits pick a slot, ESC closes. F2: boot 7.6 → 1.8 s with a
save, 6.4 → 3.1 s fresh (D0397): `Session.from_save` skips the generation the restore discarded,
`TileGrid.load_cells` bulk-loads the planes, audio synthesizes on a worker thread, `ValueNoise.FbmField`
samples the cave noise a column at a time; the golden matched at every checkpoint after each.

**Phase 2 (done).** The six rulings: T012 lamp 0.38; T013 kept; T014 the status beacon (D0401); T015 seen
ore on the map, `SeenPlane` saved and outside every signature (D0400); T016 the three generation forks in
one data change, the golden re-pinned from CI Linux by the draft-PR route (D0402, PR #51); T017 hardrock
bedded with parting planes, deepstone's plates, the tooth's cell 1/8 m -- it was the static (D0398). The
depth ladder sits on the GDD's layers (THE DEEP WORKS at 140 m). The character: drawn at 0.85, a
three-beat stroke, a breathing idle, the rope poses wired (D0399). Feel: the lamp breathes, blows chip,
breaks throw debris, landings raise dust, the water's skin is a pixel (D0403). The round's perf check found
its own regression (the map rebuilding on every step of seeing) and fixed it (D0404): the 15 s walk reads
p50 8.1 / p99 21-22 / max 28 ms, 15-20 frames over 16.7 ms per 5 s, as before the round. Catalogue v3:
73 entries acknowledged, 17 executed this round, 14 recognised (`docs/VISUAL_QUEUE.md`); forks T018–T023.
Captures: `tests/body/recordings/phase2_2026-09-05/`.

**Known, named:** the first five seconds after a fresh boot run 13 ms hub ticks while the new aquifers pour
(V65: `WaterFlow.step` while water moves); a sealed pocket has no surface to skin (V62); the deep's pool at
200 m (V63, T020); the wall specks' starfield (V64).

### The A+ / signature-look round, then the integration pass (2026-09-06; D0405–D0414, on main)

**Part A of the A+ brief.** A1: the three instruments named by the brief were already fixed in D0394 and
re-confirmed (`gate_status.py` end to end, FAIL []); the `!= null` asserts are all on object types;
`CarryLook` was the one dead game file (removed). A2: **V65 closed (D0405)** -- the water's active set with
the lifted pass kept as `step_full` the oracle, the plane's row index, the aquifers settled in `load_world`;
seat first 5 s hub p50 13.3 → 1.25 ms, generation +490 ms. **The ruled beds closed (D0406)** -- `BedSequence`,
a seeded succession. **The beacon witnessed in the dark (D0407)** -- the `beacon_probe` start record, a
`room` fixture, the ring 2.3-2.8x the control's luminance at 10 m. **The water's ripple bound (D0408).**
**Part B (the signature look) was DEFERRED by the director's next brief and is not started.**

**The integration pass (Astra's review, ranks in order).** Rank 1 **(D0409)**: the opening loop had four
breaks (ore that yielded nothing, a scoop that reached 2.5 m where the forge stood at 3.2, the hopper
scooped through rock, the cache 10 m off the pad); `yields` on the material record, one reach, the `pile`
fixture; `tests/test_tutorial_playthrough.gd` drives a stranger through rungs 1-6 in 48 s of play through
the door's own verbs. Rank 2 **(D0410)**: every settings row has a consumer -- the three audio layers'
levels, the score mounted, the shake kicked and decayed, the zoom immediate, the large map a modal, fifteen
bindings listed, the footer's legend fitting. Rank 3 **(D0411)**: the tutorial teaches actionably -- the
bound key in every sentence (`BindingLabels`), the count on the goal, the how-to the moment a rung opens
and again on a stall (legacy's silence reversed), a finished rung acknowledged, the ring on the real
target (`TargetGuide`), the ladder in the save. Rank 4 **(D0412)**: the hotbar selection follows its item,
the tenth digit reaches slot 10, an empty pack draws no bar. Rank 5 landed inside D0405 (water errors 249
→ 0 at the 206 m warp). Rank 6 **(D0413)**: the lessons dock at one place, lower left above the hotbar
band, pinned clear of the action area round the miner at the closest zoom under the largest lead a
visible lesson can have; the depth chip quiet. Rank 8, first slice **(D0414)**: the observation's plane
rebuild 9.3 → 0.66 ms (the surface off the sky floor, and the old scan was wrong underground), the target
ring 3.0 → 0.04 ms a frame, the meter given a draw phase and named HUD chips; quiet-tick p99 on the walk
6.4 → 2.6 ms. **Ranks 7, 9-13 not reached.** The remaining frame drops on a walk carry a 4-12 ms draw phase at a
constant 230 draw calls: a rendering-side wait is the working hypothesis, unprofiled (Astra's audit).

**Two quiet reds this round, both mine, both fixed:** CI red on `test_objective_line` after D0411 -- three
pins encoded legacy's silence, and I never ran the suite that enumerated the rule I reversed (bbe37387);
and the meter's lambdas on the `RenderingServer` signals crashed Godot at exit on every perf run until the
seat node forwarded them (in D0414).

### Astra's audit order, taken (2026-09-06; D0416–D0434, on main)

**The audit (D0416)** tightened three conclusions -- the opening completes through first automation, not
"end to end"; the GPU is a working hypothesis; the water fix at the warp may be avoided, not repaired --
and set the order: an unscripted stranger, water under renewed flow, rank 7, a profile, one lighting
experiment. **Water (D0417):** the generated pool breached by a shaft and a gallery, 240 ticks, six ripple
phases: 574,248 of 574,248 shapes triangulate, the pre-fix ripple fails 8,918; pumping is named, not
posed. **The profile (D0418):** `--mute=<stems>` ablates world layers; the only GPU read under Metal is
0.0; twenty-three runs showed the machine's load, not the configuration, choosing between two regimes
(~95 vs ~300 frames over budget per 600), so the lens's cost is UNRESOLVED here; one change kept on its
own terms (the post lens's screen mip chain removed, `filter_linear`). A resolved profile needs a GPU
timer on an idle machine.

**The stranger protocol.** The other session's screen-led adapter (`playtest/`, 3a6d0d54 -- its hash moves with D0426's rewrite) fixed twice:
the bridge poses the seat's own pointer, never the OS cursor, and the seat runs with vsync off so an
unwatched window keeps stepping (**D0419**); composed moves -- timed segments inside one burst, one
screenshot at the end (**D0420**). A fresh-context haiku agent plays with no source, no coordinates and no
coaching, journals every burst, and reports; frames and inputs under
`tests/body/recordings/playtest_2026-09-06_strangerN/`, journals and reports under `docs/playtests/`.
**Stranger 1 (D0421):** first ore 10.7 s, ingots 26.1 s; three fruitless MINE holds from a step too far
with nothing on screen saying so. Fixed: `MineHold.refusal` (far/sight/air) rides the observation, the aim
square goes to the refusal red with the bar while held, a TOO FAR lesson docks; rungs 1-3 re-worded (the
ring is the pointer, no compass words, the trunk not the leaves). **Stranger 2 (D0423):** first ore 6.5 s,
ingots 11.4 s, then twenty-two bursts on trees and a stop at wood 0/1 -- sixteen blows, no hold long
enough for one, no progress shown. Fixed: the banked share of the cut fills the aim square from the floor
up. **Stranger 3 (D0424):** first ore 4.0 s; the forge never fed (every DROP 5 m or more from it, the
stack falling at the feet and coming back after the grace with nothing said); stopped 50 m down the shaft
beside the pad after a two-second walk right. Fixed: the grapple's landing ring waits to be known and is
hemp (it was the brightest ring on the opening frame, in the target ring's ink); the payout tick names
its item and a loss is a tick ("-7 ore"; T029 taken); the how-to wraps before it gives (the smelt
sentence was cut at "the ingo…"); a lesson hidden by a busy body yields after 5 s when one waits. Named:
T031 (the shaft beside the pad), T032 (four ring kinds). **Stranger 4 (D0425):** first ore 1.0 s, ingots
by 14.5 s (the drop read as feeding); then the same fall as stranger 3, looking for a tree the tutorial
never gave it -- the site keeps trees 12 m off the spawn and the ring searches 10 m. Fixed: legacy's
guaranteed tutorial tree is back as a `tree` start fixture planted by the world's own tree pass, 6 m left
of spawn. Tried and reversed: the ore socket (V32; the lever is legacy's richness-scaled nugget count).
No stranger has felled a tree yet. **Stranger 5 (D0428):** first ore 2.0 s; the forge never fed --
twenty-five DROPs from 5 m and then from 50 m down the chimney, with the ring and how-to faded for the
whole surface span. Fixed: the ring holds at a floor for the rung's life; the first floor-landing drop
docks DROPPED. **Astra's item 5 (D0427):** the lamp is occluded by the rock it crosses (a shader march,
`VeilOcclusion.K` 0.5, `--lamp-occlusion=K` the dial); captures at 46 m show light on faces and dark mass;
cost inside the noise on this machine. T031's mechanism named: the chimney at +14 m is the keepout clamp. **Rank 9 (D0430):** the corner map is
a local chart (the world's width by 48 m, scrolling) in a 128 x 96 box; the banner yields to it; the
two-line how-to is balanced. **D0426 executed (D0429).** **Stranger 6 (D0431):** ore 2.5 s, ingots 7-9 s
(the fastest); the wood rung opened 13 m from the tree, past the ring's ten-metre search; the search now
reaches the screen's half-width and is paid across frames. Six runs: the front has moved to the wood
rung and the chimney. **D0432:** every airborne source occluded like the lamp; seams exempt. **D0433:**
the target ring tightens as the body arrives. The smelt how-to now says the whole stack goes in (stranger
6's first hesitation). **Strangers 7-9 (D0434)** ran in parallel on 3cf6a5bd with three missions (uncoached; wood;
down and back): all three ended 51 m down the chimney; eight of nine have. T031 TAKEN provisionally: two
metres of clay cap the mouth in the tutorial start. The drop's TOO FAR flashes the machine it fell short
of; the GRAPPLE lesson says POINT; the smelt how-to says the whole stack goes in. **D0435:** pumping
posed in the water suite (the level falls from the top; conservation exact). **Strangers 10-12 (D0436)**
ran on the capped world: the cap held (none of three fell in); stranger 10 felled the tree (the first) and
reached BUILD at 49 s; strangers 11 and 12 never mined an ore, because one D press before the first
pointer moved the ring to the shaft's buried ore. The ring now prefers hits at the body's own level;
the slash on air teaches NOTHING THERE; the seat settles the body before every frame (`settled_ticks`,
`still`). Named: T034 the felled crown floats, T035 run speed against the pad, T036 the world's edge.
**D0437:** the playtest seat boots muted (the director was on the machine); `--muted` for any scripted
boot. **Strangers 13-15 (D0438)** on the muted seats: one of three mined ore quickly; S13 dug under their
own feet and never saw the nine-pixel ring; S14's smelt ring pointed into the shaft (the level rule now
covers machines and piles); S15 never dug (T037). Taken: the near chevron (NEAR_M 2.2 from the body's
centre), "a step to your LEFT", the camera in the seat's settle, NOTHING THERE at 90 ticks restarted by a
break, and T034 provisionally: a felled trunk's crown crumbles (`TreeFall`, grounded-wood support).
**D0439:** one call a burst (the journal rides the command; the mission template tracked). **D0440:** THE
WAY DOWN lesson (T037 taken provisionally). **D0441:** the large map is a tall window (64 x 106 m).
**D0442:** the arrival tick says what is still coming (T033 taken). **Strangers 16-18 (D0443)** on the
one-call build: 15-20 s a burst (from 21.5); S17 pointed at the chevron on air (reversed: the target's
metre is outlined); S16 dropped clay at the forge four times (WRONG STACK names both items; the smelt
how-to says hold ORE); S18 mined at 9 s and never dug (D0440's lesson was not on that build). The update
for Codex is `docs/audits/2026-09-06-update-for-codex.md` (D0416-D0438, with §10 on the loop's pace).
**Strangers 19-21 (D0444), the first batch ON D0443:** S19 ore 7.6 s, ingots 21.5 s, the crown fell live;
"hold ORE (its number key)" was read and acted on by both who reached the forge; THE WAY DOWN fired twice
and one dug on it; S20 overshot the vein by five metres on two presses and never mined (T035); S21 pressed
"under me" at screen centre at the world's east edge where the camera clamps (T036). The first rung's
sentence now leads with POINT and names no direction. 11.6-13.0 s a burst. **D0445:** a held MINE on a
machine says THAT IS A MACHINE. **Strangers 22-24 (D0446, D0447):** S22 is the best run yet (ore 3.4 s,
ingots 12.1 s, wood 40.5 s, stuck at BUILD on the word "spawn", T038); two strangers could not close the
settings page by ESC (handled twice a tick; fixed, pinned, measured live); two of three never mined ore,
pressing at the feet or a far rock while the outlined block sat 20 px off -- the ring's tightening
(D0433) is the one visual change common to every failing batch since, and D0447 restores the 0.9 m ring
with the outline inside it. The loop is measured per burst (`timing.jsonl`): the seat's share is ~1 s;
the agent's think time is the rest. Astra's queue is tracked at `docs/VISUAL_REVIEW_QUEUE_2026-09-07.md`.
**D0448:** `"until": "event"` cuts a burst at the first player-visible change (objective, pack, lesson,
refusal, drop, landing), `ended_by` in the receipt. **Strangers 25-27 (on 8e80cebc, D0447's big ring):
0 of 3 mined.** Two pressed a machine's gold need-bubble on the word RINGED (S25 the shaft's, nine metres
off; S27 the forge's foot, where the vein card said "stand a Drill just above it" and S27 spent forty
bursts placing one); S26 named the ring, pointed three metres right of it, cut clay, and left. **D0449
(landed while they played):** the target is the one white mark, a reticle with compass ticks over a dark
rim; every status that raises a bubble is chromatic (pinned); the two sentences say WHITE RING (T032 taken
provisionally). **D0450:** NOT ORE, once, on a break whose yield is not ore while the pack holds none,
naming what fell, never after THE WAY DOWN; the vein card says "hold to cut it, or stand a Drill just
above it". The rope painter's pin on the old gold ink went red on CI and was re-stated (1622a422).
Since D0433: 8 of 18 mined. **Strangers 28-30 (b0871cc4): VOID by the seat, not the game.** Every seat
this session ran at background priority (a child of the agent's shell: nice 5) and starved under the
director's foreground load: three seats at half a tick a second for two minutes, agents' commands timing
out. What the frames still show: S30 mined 11 ore at 2.2 s on the vein beside the forge (the reworded
vein card), not the ring; S28 read the white ring as a reach circle and pressed the shaft's bubble first;
S29 read NOT ORE, put the pointer inside the ring four times and was refused "sight" -- one clay in the
pack had set the BUILD flag that switches the mine aim to the exact cell. **D0452:** a held MINE snaps
whatever the hand holds, to the pointed material's visible face (pinned: material, occlusion, air, far;
through the door with clay selected; the mutation reproduces the refusal); BEHIND ROCK for the sight
refusal; `playtest/seat.sh` boots the seat at foreground priority and the receipt names launcher,
platform, engine, frame cap and priority. **D0453:** the commit identity is teohondascully@gmail.com from
51fe12d7 on (two-era gate). **D0454:** `playtest/stranger.py start|validate` (the pin and the VOID
classifier; first rung read from the pack) and `playtest/replay.py` (signatures per burst). **The
overnight loop runs under the director's fifteen amendments of 2026-09-07** (recorded in D0452-D0454 and
the batch reports): a batch counts only when every seat's run is VALID and on one build. **D0455:** the
stuck-seat supervisor. **Strangers 31-33 (25ebea81, the first pinned batch):** 31 and 32 VALID, 33 VOID
(the east edge: "left the world" three times). Four ore on the first press at 1.3-2.2 s, all three, every
press on the vein beside the forge, 80 px left of the ring; ingots 13.7-17.4 s; wood 42.5 s and 105.2 s
(33 never); BUILD stopped both who reached it (the how-to cut at "shaft m…"; the ring on a pile three
metres down). **D0456:** the scoop measures from the body head to feet (the ingots came only after a step
closer; found by the ceiling run `playtest/ceiling.py` and stranger 30). **D0457:** the world ends in a wall
(T036 taken provisionally); the every-rung wrap pin measures the live corner (the corner map's), BUILD and
HOPPER shortened to fit. **D0458:** the cut mark (a second white square on the surface over a buried
target, named by the BUILD and HOPPER how-tos); NOT ORE reads the rung (it had fired on the ceiling run's
felling once the ore was spent). **Strangers 34-36 (7708c8f5): 3 VALID, first rung 3 of 3** (2.2, 2.2,
21.6 s); ingots 17.6 s for one, two dropped their ore far from any forge (one down the chimney's dug cap);
wood 21.0 s for one; BUILD stops the one who reached it (before the cut mark). The ceiling on this build:
1.3 / 6.7 / 12.1 s. **D0459:** the drill in hand moves BUILD's ring to the shaft's mouth. **D0460:**
`--seed=<n>` for the holdout. **Strangers 37-39 (68cee3f4): 3 VALID, first rung 3 of 3** (1.3, 2.2,
5.9 s) -- the second consecutive 3-of-3, the provisional opening signal (rule 7); two left the forge at
"1/2" (the second ingot lands two seconds after the first; the card said 0.7 s) -> **D0461:** STILL
WORKING and the card in hub seconds. Wood failed both who tried (the trunk, two cells wide). Nobody
reached BUILD. **D0462:** the rung-N mission variant: a seat opened from a save the ceiling run wrote
after its third rung (`--load`, the seat's save command, the save's hash in the pin;
`tests/body/saves/rung4_f298443d.json`). **Strangers 40-42 (f298443d, THE HOLDOUT seed 20260907): 40 and
41 VALID, 42 VOID (a frame that never settles: the body swinging on the grapple; the harness's rule, not
the game's); first rung 1 of 2 valid** (36.9 s; S41 mined sixteen copper at 18 m and NOT ORE said "ore
copper"). The first presses cluster on the forge's column again (80 px left of the ring). The opening
signal did not transfer. **D0463:** an item's label is its material record's display name ("Copper ore").
**Strangers 43-45 (b580f563, THE RUNG-4 VARIANT): 3 VALID, the drill placed by 0 of 3;** S44 reached it
at 56.6 s. The frames gave three fixes: **D0464** the aim snap's tolerance is a metre once the cursor is
out of reach (S43 held on the WHITE SQUARE from 3.25 m and the ground at the feet went, 2.85 m from the
cursor, wordlessly; now refused "far" with TOO FAR; the far pin goes red under the old tolerance);
**D0465** a carried machine's icon is its casing and glyph (S44 carried five white squares and never
pressed a slot); **D0466** the BUILD how-to ends "press its slot's key, [BUILD] where the ring moves"
(S44 and S45 read "the shaft's mouth" as the pad's own open shaft at dx +7). Noted, not changed: the
how-to's 9 s hold (D0411) was gone when S45 pressed at open air; the grapple swing voids a run under the
non-settling rule; floor drops; the trunk's two-cell width against the agents' pointer. **Strangers 46-48 (0ed149e4, the variant
again): 46 VALID, 47 and 48 VOID by the swing (the grapple never settles; three of nine variant runs
now); none reached the drill.** Two pressed the WHITE SQUARE inside ten seconds and the first bite (a cone,
five cells wide at the top) took the metre's centre; the mark read the metre as open and vanished with
three quarters of it standing; both stopped. **D0467:** a metre is roof while any of its sixteen cells
stands (the mark stays until the hole is clear); CUT THROUGH for the air a hold runs on after its own
bite ("point at what is left of the WHITE SQUARE; a hole has to be a little wider than you"); the
ceiling's rung 4 (`--rung4`: the drill in hand 12.6 s, placed 14.1 s: four bites -- centre, bottom row,
the two rim columns the body's edges rest on -- the fall onto the pile, the slot key, a step, BUILD on
the ring); the receipts' `slots` in the bar's order (the pack dict is sorted; the script pressed the
coal's key for the drill once). One stranger read TOO FAR and walked past the square (the lesson says
closer, not which way). **Strangers 49-51 (10750f32): 3 VALID; the drill in hand 2 of 3
(9.9 s, 42.1 s), placed 1 of 3 (S51, 18.6 s, the first ever), fuelled 23.5 s** -- in its own tunnel, off
the line, so "First automation" never came. **D0468:** the cut mark is the metre and a cell either side
(the six columns a body a metre wide needs; S50 chewed the metre three times and stood on the rim).
**D0469:** the BUILD rung reads a drill over a smelter (`Objectives.drill_on_line`); WRONG SPOT for a
drill set elsewhere; the lesson tables moved to `HintTexts`. **D0470:** a BUILD that places nothing says
why (`build_far` / `build_here` on the refusal channel; TOO FAR for BUILD, STEP ASIDE). Noted: TOO FAR
sends strangers a 4.5 m stride past the square (T035); the shaft's mouth cannot be walked into (a body
a metre wide over a mouth a metre wide stands on both lips). **Strangers 52-54 (2739bed5): 3 VALID, the drill in
hand 0 of 3;** two aimed at the ring under the ground and read TOO FAR's "step closer"; TOO FAR for
BUILD fired with no drill in hand and with clay; a hop taught HARD LANDING. **D0471:** the landing
lesson at terminal speed. **D0472:** the BUILD refusal only with a machine in hand. **D0473:** TOO FAR
DOWN for a far target two metres or more under the body ("dig at the WHITE SQUARE first"). The variant's
tally: ten valid runs of twelve, the drill in hand 3, placed 1 (off the line), the ceiling 14.1 s.
**Strangers 55-57 (86ebbf60): 3 VALID, the drill in hand 0 of 3;** every press
got its refusal or its cells and every lesson was the right one for its press; two bit near the square
and walked off, two dropped the pack with Q "to the drill" (the smelt rung's verb). The variant over
five batches: 13 valid of 15, the drill in hand 3, placed 1 (off the line), the ceiling 14.1 s. Six
strangers ended in the sinkhole at dx +15 (a jump without a direction held does not leave it). **The variant
loop ends here** (rule 13: the remaining failures have no game-side frame cause). **Strangers 58-60 (8612f74a,
the shipped seed, a fresh game): 3 VALID, the first rung 2 of 3 at 12.8 and 16.8 s, S60 never** -- all
three first presses on the forge's open pocket 3.9 m off, refused "air" by D0464's metre where legacy's
reach had snapped them to the vein at 1.3-2.2 s. **D0474:** the metre applies to a pointed rock out of
reach; open air out of reach keeps legacy's reach (by hand the same presses cut 5 and 11 ore; recorded
in CORRECTIONS.md as an amendment of D0464). S58 reached BUILD from a fresh game at 80.6 s. **The
overnight loop closed there.** **The first-rung gate (the director's brief of 2026-09-07; D0475):
strangers 61-63 (77dd4655, the shipped seed, all uncoached) 3 VALID, four ore by the pack at 2.2 / 2.8 /
11.3 s; strangers 64-66 (the holdout seed 20260907) 3 VALID, at 8.7 / 7.0 / 4.3 s -- two consecutive
valid 3-of-3 batches, the gate passes; every success through the snap.** D0474 is legacy's reach rule
verbatim (durable, its in-reach/out-of-reach seam pinned: the machine's cell in reach exact and
refused, the pocket cell below it out of reach snapped) with one provisional line (the metre for a
pointed far rock). The forge rung 3 of 6 (15.9, 30.1, 17.4 s), wood 1 of 6 (47.5 s), BUILD reached
once, finished never. **Fixed on frame-and-input evidence: D0477** the dig plan lives while the button
is held (a mark from an early press was dug by a later refused hold in 3 of 6 runs, under TOO FAR /
NOTHING THERE; replay IDENTICAL, minimal pair on fresh seats, arm A breaks 9 cells on the old tree and
none on this one); **D0478** the cut mark's roof is ground, not the tree's own crown (the WHITE SQUARE
floated over the leaves on the wood rung, three frames); **D0476** the receipts carry the pointed cell
and `playtest/evidence.py` prints the per-burst table. Reports
`docs/playtests/2026-09-07_strangers{61-63_shipped,64-66_holdout}.md`. **For the director:** the
sinkhole mouths one stride east of the pad (cells 190 / 199; nine strangers; D0388's 12 m keepout vs a
9 m stride), the smelt lesson's BESIDE where the forge's own column takes the drop, the Q at the spawn
cell (4 of 6), the trunk cells behind the body's legs, the stride. **Next: the forge rung with the same
discipline (a rung-2 variant save, or the shipped seed read at the drop), then wood and BUILD
separately; a shipped-seed batch on this build re-measures the opening once more.**

**Rank 7, first slice (D0422).** A blind judge (fresh-context vision agent, eight 120x120 crops with the
grid's truth, three judges a condition): before, 13/24 spots right and 0/9 cavities seen; after the wall
stamped one alpha level below solid (254/255) so the tooth and grit passes skip it, the wall FLAT (no
bedding tone a plane back), and a one-world-pixel rim on every face bordering air or wall: 17/24 and 5/9.
One persistent misread: a solid spot beside the dug pit read as open in 5/6 across both conditions.
Not started: ore's sparkle (V32).

**Not touched since the wrap:** Part B (the signature look), the lighting experiment (Astra's item 5),
ranks 9-13.

**D0426 executed as D0429:** the fourteen commits rewritten and force-pushed under a lease on the director's word, the protection restored identically.

### Next action

**A′ is complete through step 8; the look pass, the two-phase round, Part A of the A+ round, ranks 1-6
and 8 of the integration pass, Astra's audit order through item 5, and five stranger runs are on main.**

**D0426 is executed (D0429):** every ref carries the one identity; the authorship job is green again from e2850726.

**The director's calls:** play the opening (`godot --path .`: the tree stands six metres left of spawn,
the forge's ring stays for the rung, a floor drop docks DROPPED, the lamp lights faces in the deep);
T031 (taken provisionally in D0434: the chimney capped; overrule by deleting two record lines); T032
(taken provisionally in D0449: the white reticle; overrule by two colours); T035 (RUN_SPEED), T036 (the
world's edge), T038 ("spawn"), T039 (the hotbar's capacity); whether the lamp's occlusion (D0427) is the first line of Part B or a switch to leave
at zero; the forks T024-T030.

**Cheap next steps that need no ruling:** keep cycling pinned stranger batches (the rung-4 variant for
BUILD, the shipped seed for the opening -- the first-rung gate passed twice on 77dd4655, D0475) and fix
only what a batch's frames and inputs show; the forge rung next, with the same discipline; decide the
forge's need-bubble and nameplate during the mine rung on shipped-seed evidence (14 of 23 first presses
since D0449 landed on the forge's column) and the sinkhole keepout against the strangers' stride (D0388's
12 m; nine strangers in the mouths at 15-17 m); the how-to's hold on a multi-step rung (D0411's 9 s); the
grapple swing against the non-settling void rule (a harness question); Astra's visual P0s in order (the
hotbar's content-aware width, the objective card's rest height, the refusal slot); the wood ring on the
miner's chest when the trunk stands behind the body; the blind-judge instrument re-run on the ore half of
rank 7 once the richness-scaled nugget count can be read from the bake (V32).
