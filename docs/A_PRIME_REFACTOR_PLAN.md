# A′ refactor plan — lift legacy's sim hub onto the substrate, then finish the game

**Status:** normative execution plan, written 2026-09-03 on the director's approval of
`docs/FLIP_ANALYSIS_2026-09-02.md`'s recommendation. **Execution began 2026-09-03: step 0 done (D0343),
step 2 done (D0344), step 1 ruled (D0345). Each step in §4 carries a status line; a step with none has not
started.**
The tree it describes is `6f0d894e` (`main`); legacy is `legacy/` in that tree, byte-identical to tag
`pre-pivot` (`666e5518`).

## 0. The compaction contract

**This document is self-contained. A session executing A′ should need only this file, the flip analysis,
and the tree. If executing this plan requires knowledge not in this document, that is a defect in the
plan — fix the plan, don't rely on memory.** Every file:line below was read from the tree by the
analysis's 17 workers (491 of 491 code files, coverage self-checked) or measured by the orchestrator.
Where a number came from a worker's estimate rather than a measurement it says "est."

How to use it: read §1–§2 once, then work §4 top to bottom. §3 is the map of the tree you are working
in. §5, §6, §7 and §9 are what you check before and after each step. §8 is what only the director can
answer; do not guess those.

---

## 1. The decision, and why the executor does not re-litigate it

**A′ = FINISH the rebuild, but lift `FactorySim` whole.** Not the flip (legacy as the base), and not
the per-component rebuild that has been running since 2026-08-25.

Why, in one paragraph. Legacy's `FactorySim.tick()` is already node-free, fixed-tick at 20 Hz and
integer-shaped: a complete read found 24 live determinism-breaker rows in its 3,259 lines, 77 estimated
changed lines, all mechanical, and its own header says "node-free, fixed-tick, deterministic". Its
water is integer-only and sorted. Its world generator, power field, flora and save have zero
within-platform breakers. The non-determinism the substrate was built to eliminate lives in legacy's
*scene* layer (`main.gd`, `player.gd`, `grapple.gd`: two clocks and state decided at frame rate), and
the rebuild has already replaced the two largest pieces of that layer with `sim/body` and `sim/mining`
and must write the third (the grapple under `Fx`) in any direction. So lifting the hub whole is a type
pass on code that already works, it keeps every guarantee the substrate has (layer boundaries, size
caps, the L2 door, the 4 px world, the gate suite), and it removes the measured cause of the slowness:
the rebuild spent its sim-side effort building body and terrain from scratch and treating the machine
half of legacy as a rewrite target when it has no current equivalent at all. Ledger: D0341.

**The one thing that killed legacy, the terminal economy, is not ported.** It is redesigned as
rig-as-consumer (`docs/GDD.md` §3, §7; `PORT_ORDER.md` V13). That is step 7 and it is the director's
to scope. Everything else legacy did that is not on GDD §9's dead list comes over.

**The rule the whole plan runs on**, from `docs/archive/MASTER_PLAN_AUG30.md` §0: port the logic,
refactor the form, never rewrite from scratch. Read the legacy block, keep the algorithm and its
constants, re-express it against the current interface, name the legacy source in the file header.
Rewriting is banned unless the logic itself is wrong, and the only thing wrong is the economy.

---

## 2. The goal state

One working, playable, exciting game at 120 Hz: the full mining loop (dig, haul, forge, descend);
machines that are fed, run, and show it; water that floods and is pumped; the winch hauling to the
rig; the rig-as-consumer economy that keeps wanting past fifteen minutes; legacy's atmosphere (the
veil, the lights, the marks, the water surface, the synthesized audio, the HUD) and feel (the
grapple); all of it on the deterministic substrate with its gates, its two-process replay, and agent
playthroughs that enter through the same door a human does.

Acceptance, stated so it can fail:
- A human plays it from a cold start for thirty minutes and wants to keep playing. The director's
  judgement, not a number, recorded as a taste-queue verdict.
- `claims/C003-cold-start-reaches-d1.md` moves from BLOCKED to measured: a scripted agent reaches the
  rig's first demand headless.
- Gate 8 green: two OS processes, bit-identical, goldens pinned from CI Linux, after every step below.
- `view/draw_cost.gd` reports a frame under 8.33 ms at the default framing and at the widest zoom rung,
  on the director's machine, during a dig.
- Every structural gate green on the tree as it stands, not waived.

---

## 3. The file map

The tree has 491 code files (`.gd .py .sh .gdshader .tscn .yaml .yml`), 281 in the current build and
210 under `legacy/`, plus 44 legacy `.tres` records and the non-code corpus (§3.7). Every legacy file
below carries one of four labels. Every current-build file is LIVE.

| label | meaning | legacy count |
|---|---|---|
| **LIVE** | current, authoritative, in the game or substrate now | 281 (all current-build code) |
| **LIFT** | legacy code A′ ports, with its destination | 48 files + 44 `.tres` |
| **REFERENCE** | legacy kept as the worked reference while porting; the port reads it, never ships it | 112 files |
| **DEAD** | confirmed dead by GDD §9 or superseded; removed in a later cleanup wave, listed here, **not removed by this plan** | 50 files + in-file ranges |
| **STALE-DOC** | documents amended or archived on 2026-09-03 | §3.6 |

48 + 112 + 50 = 210. The counts are from the analysis's per-file verdicts, re-bucketed for A′.

### 3.1 LIVE — the current build (281 files, all authoritative)

| directory | files | what it is | the plan touches it in |
|---|---|---|---|
| `core/` | 5 `.gd` (422 lines) | `Fx` i32/16-bit fixed point, `SplitRng`, `EntityIdPool`, `Seams` (integer-exact port), `BitOps` | step 5 adds `Fx` vectors |
| `sim/world/` | 2 | `TileGrid` (4 px terrain planes, running state hash with self-check), `WorldMaterials` | step 4 adds planes |
| `sim/terrain_gen/` | 4 | `ShaftGenerator`, `CavePasses`, `ValueNoise`, `StrataData` — carries the 4 D0183 float sites (§5.4) | step 8 |
| `sim/body/` | 8 | tick-only `Fx` kinematics, gait, heightfield, resolvers, dig | step 5 adds grapple |
| `sim/mining/` | 2 | integer charge, hardness→ticks, bite, cracks, rhythm, hollow tell | step 3 adds aim snap, LOS, dig plan, lode cycle |
| `sim/commands/` | 1 | `Command` (MOVE, MINE) | step 4 adds the 28 verbs |
| `sim/invariants/` | 1 | floor-selection check, bounds | step 3 adds conservation |
| `sim/{machines,items,transport,fluid,economy,behaviors,telemetry,run,meta}/` | 0 `.gd`, `MODULE.md` only | the empty half of L1 — **this is what the hub lift fills** | steps 2–4 |
| `interface/` | 4 (622) | `observe()`/`apply()`, 34-field `Observation`, `Envelope`, window cache | step 4 |
| `view/` | 36 (5,706) | coordinator, 20 painters, HUD chips, audio, fx; 36 of 36 layer-clean | step 6 |
| `shell/` | 2 | settings + bindings (lifted from legacy). **No boot, no main scene.** | step 6 adds the boot and save |
| `data/` | 24 | materials (8), strata (3 sites), bands (8); `machines/` and `recipes/` are README-only | step 3 |
| `tests/` | 100 (16,438) | 446 `_test_` functions; the two-process golden, fuzzers, acceptance chamber, recorded sessions, vacuity guard | every step adds suites |
| `tools/` | 74 py+sh (8,709 py) | 35 numbered gates, mutation tests, runners, captures | step 0 adds the harness protocol |
| `.github/workflows/harness.yml` | 1 | 39 steps: 24 process, 11 structural, 2 sim-bound (68 suites), 2 headed | unchanged |

### 3.2 LIFT — legacy code that comes over, and where it lands

The 48 files are the whole-file lifts. Three rows below are BLOCK lifts out of files that stay REFERENCE
(`main.gd`'s state-logic blocks, `player.gd`'s nine mechanisms, `fine_terrain.gd:768-812`) and are not
counted in the 48.

Legacy's unit regime differs from ours and every port crosses it. **What is conserved is metres.**

```
terrain cell     legacy 32 px = 1 m  ->  this build 4 px, four per metre
logic cell       legacy 32 px = 1 m  ->  this build 16 px = 1 m (the SAME metre)
body constants   RUN_SPEED 150, GRAVITY 900, JUMP -365, MAX_FALL 560: identical pixels, port unchanged
field-of-view    converts x2 (D0325); fine-detail sizes in px convert x0.5; per-cell rates x4/x16 (WG-4)
```

**Sim hub (step 3 unless noted):**

| legacy file | lines | destination | what changes on the way |
|---|---|---|---|
| `legacy/src/core/water_flow.gd` | 100 | `sim/fluid/water_flow.gd` | **verbatim** (step 2). Integer levels, snapshot + total-order sort, zero rows. Its `sim.water` dict becomes a `TileGrid` plane in step 4. |
| `legacy/src/core/factory_sim.gd` | 2,591 live of 3,259 | split across `sim/machines/`, `sim/items/`, `sim/transport/`, `sim/economy/`, `sim/world/` (§4 step 3 has the seam map) | 21 dead ranges dropped (668 lines); 24 rows fixed (§5.1); `machines` Array insertion order kept as state; hopper latch kept |
| `legacy/src/core/machine_state.gd` | 45 | `sim/machines/machine_state.gd` | `progress: float` → `progress_ticks: int`; `power_factor: float` → per-mille int; `fed` comment names dead Descent |
| `legacy/src/core/power_flow.gd` | 89 | `sim/machines/power_flow.gd` | all-float field → milli-int, 8 rows (§5.2). Mechanism only; the tier is NOT wired (GDD §9, V11) |
| `legacy/src/core/flora.gd` | 64 | `sim/world/flora.gd` | sort `sapling` keys before iterating (1 row); delete line 43's `invalidate_bazaars()` |
| `legacy/src/core/save_game.gd` | 455 | `shell/save_game.gd` | v3 schema: the two floats → ints, `research` dropped from `REQUIRED_KEYS`, `player_pos` as `Fx`; one `keys()` sort. The 23 top-level keys and 13 per-machine keys are listed in §5.3 |
| `legacy/src/data/machine_def.gd` | 21 | `data/machines/SCHEMA.yaml` + `generated.gd` via `tools/data_codegen` | `craft_cost`/`craft_count` stripped; the schema validator must REJECT them |
| `legacy/src/data/recipe_def.gd` | 14 | `data/recipes/SCHEMA.yaml` + `generated.gd` | `time: float` seconds → `time_ticks: int` (20/40/50/60/44/50 at 20 Hz, all exact) |
| `legacy/src/data/machines/*.tres` | 22 records | `data/machines/*.yaml` | LIFT 15: `iron_forge blast_furnace drill generator conduit lift pump hopper torch rope processor winch_head winch_station plate_press gear_mill`. DEAD 3: `descent_engine h_drill drift_rig`. RULING 4: `spur splitter ore_vent crusher` (§8) |
| `legacy/src/data/recipes/*.tres` | 6 | `data/recipes/*.yaml` | LIFT 4: `mine_ore smelt_iron smelt_ingot smelt_rich`. RULING 2: `press_plate mill_gear` (terminal products; the machines survive, their outputs' consumer does not) |
| `legacy/src/data/materials/*.tres` | 16 | — | REFERENCE only: `data/materials/*.yaml` exists (8); add records as systems need them |
| `legacy/scenes/world_seeder.gd` | 152 | `sim/terrain_gen/world_seeder.gd` | all-integer, fixed order; its 14 `MainView.*` layout reads become a data record; drop `_seed_starter_kit` :135-142 (dead tool ladder) |
| `legacy/scenes/main.gd` STATE-LOGIC blocks | 749 of 3,003 | `sim/mining/` (aim snap 1839-1877, LOS DDA 2877-2915, dig plan 1801-1838, lode cycle 216-236 + 1957-1979, `_workable` 1783-1800) and `sim/commands/` (the verbs: `try_build` 2645-2726, `_placeable*` 2778-2823, `try_drop`/`_reachable_eater` 2534-2587, collect + drop grace 2237-2348, `try_configure`/`_apply_knob` 2148-2161 + 2460-2477, `try_link_winch` 1487-1514) | float distance/rect gates → `Fx`/int; the DDA re-derived in integers (~35 lines, absent from both trees); `_can_reach` = `Mining.in_reach`; `Player.note_dig` sets `facing`, which is STATE (a drop's target cell), not cosmetic |
| `legacy/tests/test_power_water.gd` | 322, 5 live | `tests/test_water_flow.gd`, `tests/test_power_flow.gd` | port as the acceptance spec for steps 2–3 |
| `legacy/tests/test_sim.gd` | 2,015, 35 live of 45 | `tests/test_machines*.gd`, `tests/test_items*.gd`, `tests/test_transport*.gd`, `tests/test_save_game.gd` | delete the 10 dead tests (bazaar, research, craft, descent, borer); 10 live tests fixture on `ore_vent` and 4 on the splitter (§8) |
| `legacy/tests/test_stress.gd` | 1,044, 3 live of 4 | `tests/test_machines_stress.gd` | delete `_test_stress_research` 818-1044; ~12 dead op lines re-sequence its RNG |
| `legacy/tests/test_worldgen.gd` | 1,153, 11 live | `tests/test_shaft_generator*.gd` additions | the 13 same-seed regen equalities and the 60-world fuzz; ~25 dead sub-block lines |
| `legacy/tests/test_base.gd` | 128 | `tests/test_base.gd::_finish` | LIFT its `_verdict` asserted-count refusal (`check_base.gd:145-160` is the model); the rest is already the ancestor of the current base (step 0) |

**Body (step 5):**

| legacy file | lines | destination | what changes |
|---|---|---|---|
| `legacy/scenes/grapple.gd` | 389 | `sim/body/grapple.gd` | REWRITE under `Fx`: `normalized()`/`dot()`/divide-by-length → `Fx` vectors (PRE-2, ~40 lines in `core/fixed_point.gd`); `PUMP_CLAMP 1.05` stored as `21/20`, never as two reciprocal literals; the same literal is `RELEASE_KICK` at `player.gd:316`; the two `delta` sites (`_carry += FLY_SPEED*delta` :145, reel :201-210) become per-tick integers; the aim is a recorded world cell, not the raw pointer |
| `legacy/scenes/player.gd` (9 mechanisms only) | ~200 est | `sim/body/*` | rope climb :302-306/:337-343, lift updraft :330, water wading :259 + 5 multipliers, over-speed coast :285-293, step-down floor snap, machines-block/wood-passes :566-570, authored-ramp glide :365/:480 (ruling: superseded by `Heightfield`?), `place()`, carry weight (visual). The core kinematics are ALREADY in `sim/body` (6 of 19 rows at 0 lines) |

**View (step 6), in `PORT_ORDER.md`'s sequence:**

| legacy file | live lines to port | destination |
|---|---|---|
| `legacy/scenes/water_view.gd` | 362 | `view/visuals/water_painter.gd` — no water painter exists |
| `legacy/scenes/visuals.gd` | 1,535 of 1,850 | `view/visuals/machine_look.gd`, `item_look.gd`, `status_look.gd` (registries: `MACHINE_STYLE` 21 entries, 7 dead; `STATUS_LOOK` 11, 3 dead; `MACHINE_PROFILE` 16, 5 dead; `ITEM_PURPOSE` 45, 12 dead) |
| `legacy/scenes/machine_view.gd` | ~620 of 726 | `view/visuals/machine_painter.gd` — rebind its 22 private `WorldRenderer` reach-ins (7 fields: `_aim _anim_time _zoom _font _construct _guide_targets _cell_center`) to `Frame` |
| `legacy/scenes/rope_view.gd` | 274 | `view/visuals/rope_painter.gd` — 2 reach-ins (`_view_world_rect()`, `_anim_time`) |
| `legacy/scenes/payouts.gd` | 77 | `view/hud/payouts.gd` |
| `legacy/scenes/falling_items.gd` | 210 | `view/fx/falling_items.gd` — view-only; its one sim write (`flow_events.clear()`) becomes a consumed-events channel on the Observation |
| `legacy/scenes/sfx.gd` | ~1,030 of 1,125 | `view/audio/sfx_bank.gd` — the 11 beds (pump, water, hum, wind, cave, rope) follow systems that are LIVE by GDD; only `boom` (18 lines, descent breach) is dead |
| `legacy/scenes/hud.gd` | 1,673 of 2,189 unported | `view/hud/hotbar.gd`, `inspector.gd`, `minimap.gd`, `objective_card.gd`, `alerts.gd` — `HELPER_TAGS` is asserted total, so a split must keep every `_draw_*` registered; three surfaces stand down inside themselves because each owns a hit region |
| `legacy/scenes/hints.gd`, `hover_info.gd`, `objectives.gd` | 308 / 148 / 182 live | `view/hud/` — MERGE: mechanisms lift whole, every content table is re-authored (they teach dead machines). `objectives.gd:182` calls PRIVATE `sim._first_machine_below`, the one boundary violation; `hints_taught` is frame-sampled into the save (BRK-L7-001) and must be tick-sampled |
| `legacy/scenes/settings_page.gd`, `page_surface.gd`, `ui_theme.gd` | 862 / 77 / 23 tokens | `view/hud/settings_page.gd`, `page_surface.gd`, `ui_theme.gd` — the current theme carries 13 of 36 declarations; the settings page needs 15 of the missing 23 |
| `legacy/scenes/world_renderer.gd` by seam | ~2,260 of 3,656 | S2 lighting (12 of 18 functions unported: `_paint_lights`, machine pools, godrays, `_draw_glow`, torches, lamp easing) → `view/visuals/light_painter.gd` + `LightLayer` blend modes on `add_painter(z, blend)`; S4 ore (6 of 8: seam clustering, lode grains) → `ore_painter.gd`; S5 marks (24 of 31: the mark and cursor grammar) → `mark_painter.gd`; S6 ambience (16 of 17) → `ambience_painter.gd`; S1 bake remainder (7 of 13) → `terrain_bake.gd`; S3 palette (4 of 15) → `material_look.gd`. Seam line ranges: coordination 361, S1 432, S2 947, S3 317, S4 305, S5 820, S6 474 |
| `legacy/scenes/terrain_painter.gd` | ~350 of 438 | `view/visuals/terrain_painter.gd` — chamfers, fillets, AO, cap, ramp not ported |
| `legacy/scenes/fine_terrain.gd:768-812` | 45 | `view/visuals/terrain_bake.gd` — the progressive, time-budgeted bake slice (§7) |
| `legacy/scenes/heat_haze.gdshader`, `rock_tooth.gdshader` | 24 / 69 | `view/visuals/` — `rock_tooth` needs a grammar map texture first (`PORT_ORDER.md` V3) |

**Harness protocol (step 0, transfer regardless of anything else):** 15 of legacy's 24 hygiene tools →
`tools/harness/`: `run_harness.sh`'s verdict protocol pieces `harness_verdict.sh` (407), `cap_lib.sh`
(79), `check_exit_codes.sh` (159), `with_machine.sh` (199), `assert_skip_route.sh` (217),
`assert_floors.sh` (194), `lock_lib.sh` (153), `check_lock.sh` (360), `save_sentinel.gd` (265),
`check_save_isolation.gd` (322), `check_verdict_claims.gd` (267), `check_verdict_route.gd` (289),
`check_posed_fields.gd` (558), `check_shared_constants.gd` (341), `check_hash_mixing.gd` (982). What
they give: three-state + VOID verdicts with reason lines, `PASS*` stand-downs, HOME-keyed `user://`
isolation that fails closed, a machine lock, a save sentinel, a wall-clock cap, post-sweep quotability
gates, and `check_base._verdict`'s refusal of a green that asserted nothing (`legacy/tools/check_base.gd:145-160`).
`tools/run_suites.sh` (124 lines) has none of it; `tests/test_base.gd::_finish` has no pass counter.

### 3.3 REFERENCE — keep, read, do not ship (112 files)

| group | files | why it stays a reference |
|---|---|---|
| `legacy/scenes/player.gd` (818) | 1 | `sim/body` is the port; §3.2 lists the 9 mechanisms still to take from it |
| `legacy/scenes/main.gd` (3,003) | 1 | the coordinator: `view/world_view.gd` + `frame.gd` replaced it (D0240); its STATE-LOGIC blocks are LIFT-BY-BLOCK (§3.2); its 373 dead lines are DEAD; the rest is view/juice already re-expressed or not wanted |
| `legacy/src/core/layered_world_gen.gd`, `heightmap_world_gen.gd`, `world_gen.gd`, `world_data.gd` | 4 | `sim/terrain_gen` is the deterministic equivalent for caves, caverns, veins, `_density_count`; ~420 lines of content have no current equivalent and are not dead: relief and scarps (`heightmap:122-163`), rifts, sinkhole throats, ledges, spires, rubble, droughts, lodes, aquifers, trees, the richness field. Port them in step 8 with the `Fx` noise cycle, not before |
| `legacy/src/core/fine_terrain.gd`, `legacy/scenes/fine_terrain.gd` | 2 | render-side molding; `view/visuals/rock_tone.gd` ported the shading. Zero state readers. Only `:768-812` (progressive bake) is LIFT |
| `legacy/src/data/material_def.gd`, `mining_rules.gd`, `seams.gd` | 3 | materials → `data/materials`; HARDNESS is already hardness→ticks in `sim/mining` (`earth` 0.28 s = 5.6 ticks needs one re-tune); `core/seams.gd` is the exact integer port |
| `legacy/scenes/controls.gd`, `strata.gd`, `settings.gd`, `sky_painter.gd`, `light_layer.gd`, `particles.gd`, `art.gd`, `score.gd`, `erase.gdshader`, `post_fx.gdshader`, `rock_grit.gdshader`, `main.tscn` | 12 | already ported (`view/controls.gd`, `data/bands`, `shell/settings*`, `view/visuals/sky_painter.gd`, `view/fx/light_layer.gd`, `view/fx/particles.gd`, `view/visuals/art.gd`, `view/audio/score.gd`, the three shaders), diff-verified by the analysis |
| `legacy/tools/` 83 RETAIN + 6 hygiene | 89 | each is the acceptance spec for a subject that arrives with a step; port the ASSERTION into `tests/` when the subject lands (§4 names them per step). The 6: `check_prose.sh`, `capture_manifest.sh`, `check_capture_manifest.sh`, `profile.sh`, `sweep_drift.py`, `seed_corpus.sh` |

The 83 RETAIN tools, grouped by the step whose subject they test (all `legacy/tools/`):
- **step 2–3, machines/items/water/power:** `check_pile_reach check_hopper_status check_hopper_objective
  check_machine_state check_machine_identity check_nameplate_truth check_status_reads check_item_reads
  check_water_move check_water_reads check_lift check_carry_cap check_head check_save_frontier
  check_save_durability check_saveload check_vein_guard check_lode check_richness check_seam_flood
  check_scan check_descent(partial) check_room_reads check_underground check_opening frontier_corpus
  ore_reach`
- **step 5, body and grapple:** `check_grapple check_grapple_reads check_pump check_traverse check_teaching
  check_climb check_stride check_step check_contact_edge check_wrap check_plunge check_aim
  fixture_pointer check_fixture_pointer check_input_deafness check_controls check_gamepad
  check_binding_text check_binding_conflict check_binding_persistence`
- **step 6, view and HUD:** `check_casing_light check_paint_terms check_material_grammar check_texture
  check_rock_reads check_ceremony_reads check_selection_reads check_lesson_occlusion check_hint_gate
  check_text_contrast check_hud_layout check_depth_reads check_announce_channel check_relief check_grid
  check_snap_frame check_draw_cull check_shaders check_bake_idempotent check_progressive_bake
  check_dig_hitch measure_bake_noise measure_voice icon_sheet machine_sheet dead_space bake_miner zoom`
- **step 7 and the 120 Hz acceptance:** `check_frametime profile_frame check_pacing`
- **the agent driver, as a pattern:** `play_agent.gd play_tests.gd run_harness.sh check_base.gd
  capture_moments.gd` — legacy's whole-loop driver (~2,230 live lines). It enters BELOW the input map
  (writes `player.input_dir`, calls `try_mine` directly and breaks a cell per call where a human waits
  `hardness` seconds). Rebuild it on `Interface.apply` with per-tick commands; do not port it as-is

### 3.4 DEAD — confirmed dead, listed, NOT removed by this plan (50 files + in-file ranges)

Whole files: `legacy/scenes/bazaar_bench.gd bazaar_catalogue.gd bazaar_costs.gd bazaar_pack.gd
bazaar_page.gd bazaar_surface.gd bazaar_works.gd bazaars.gd` (2,641 lines; deleting them dangles
`BazaarPage` in `hud.gd`/`main.gd` and `Bazaars` in `main.gd`/`world_renderer.gd`),
`legacy/src/data/research_rules.gd` (129), `legacy/src/data/bit_rules.gd` (110).

Legacy tools, 40: dead subject — `check_craftable_registry check_bazaar_ruin check_rules_registry
check_loop_health check_refusal check_spoil check_bits check_drift check_tool_text
check_progression_payable check_bazaar_cache check_fastforward arc_driver check_row_identity
mock_settings check_pack_layout mock_bazaar check_seal_desire`; superseded by a current suite —
`check_fall check_stepup check_walk check_agility check_body_stress check_impact` (→ `tests/test_body_*`,
`test_gait`), `measure_player` (→ `test_body_acceptance`), `check_tells check_rhythm check_mining` (→
`test_mining`), `check_settings`, `check_score`, `check_seam`, `check_voice`, `check_water_audio`,
`check_pixel_snap` (→ `test_camera_rig`), `check_material_registry`, `check_ci_coverage` (→
`check_suite_coverage.py`), `check_base_namespace.sh`; hygiene superseded — `check_trailers.sh`,
`check_encoding.gd`, `check_doc_counts.gd`.

In-file dead ranges (drop on the way in, never port): `factory_sim.gd` 21 ranges / 668 lines
(Borer/h_drill 60-67, Drift 69-88, registry 157-160, Descent 168-176, research 303-307, 392-393, bazaar
flags 713/747/843/948/2610, bit plumbing 837-839/853/879-880/895, Bazaar scan 1246-1461, craft/research
1613-1678, craft_item 1681-1708, Descent 2339-2391, h_drill 2621-2727, Drift 2730-2867); `main.gd` 373
lines in 46 ranges; `hud.gd` 271; `visuals.gd` 233 (+82 conditional); `machine_view.gd` 103;
`world_renderer.gd` 142; `hover_info.gd` 40; `objectives.gd` 29; `sfx.gd` 18; `hints.gd` 9;
`ui_theme.gd` 52 by sole consumer; `layered_world_gen.gd` ~55 (seal + ruin); `mining_rules.gd` ~165;
`machine_def.gd` 5; `save_game.gd` the `research` key at 41/101/229/261; `strata.gd` 29-31;
`controls.gd` RESEARCH/BAZAAR bindings; the `.tres` and recipes named in §3.2. Legacy total ≈ 5,100
dead lines of 28,522.

Not on GDD §9's list and needing a ruling before it is called dead: the Crusher + gravel + packing +
seep chain (`factory_sim.gd` 89-103, 297-302, 1142-1185, 2870-2937, 133 lines), which exists to sink
the Drift Rig's spoil.

### 3.5 What the current build has that the plan changes nothing about

`core/`, `sim/body`, `sim/mining`, `sim/terrain_gen`, `sim/world`, `interface/`, `view/`, `tests/`,
`tools/`, CI. Nothing in the current tree is DEAD. Four current files carry the cross-platform float
sites (§5.4); they are LIVE and step 8's subject.

### 3.6 STALE-DOC — handled 2026-09-03

Archived with a dated header: `docs/MASTER_PLAN_AUG30.md` (the overnight lane plan; its cardinal rule
survives in §1 above), `docs/WG4_CONVERSION_PLAN.md` (executed, D0305/D0307). Marked **reference,
superseded in sequence by this plan**: `docs/LEGACY_GAP.md` (its measurements stand; its "15 call sites
in five surfaces" is 23 in 6 and its 16% is 35.9%), `docs/PORT_ORDER.md` (its component notes stand;
its KEEP-CURRENT line on `factory_sim.gd` is reversed by D0341), `docs/PERF_PLAN.md`,
`docs/COORDINATOR_CONTRACT.md` (its "Nothing here is built" was true on 2026-08-30; the coordinator
landed as D0240). Amended in place: `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` (KEEP-CURRENT reversed),
`ONBOARDING.md` (stage sequence superseded), `CONTEXT.md` (current state), `docs/WORKING.md` (reset),
`README.md` (rewritten). `CONTRIBUTING.md` already declares itself stale in its own header.

### 3.7 The non-code corpus, so nobody counts it as fog

| path | tracked files | what it is | action |
|---|---|---|---|
| `history/` | 170 | curated captures, policy-capped at 12, currently 168 images | cull is the director's own call, not automatic |
| `docs/media/` | 72 | the canonical visual record of named moments | keep |
| `docs/audits/`, `docs/archive/session-exhaust/` | ~2,700 logs and evidence | audit evidence | keep; never read them to orient |
| `docs/archive/` | 38 `.md` | superseded docs with dated headers | keep |
| `tests/body/recordings/` | 16 tracked + 36 untracked `.log` | the recorded-session corpus; gate 27 is red until the 36 are committed or ignored | director: commit as corpus or gitignore |
| `legacy/assets/` | sprites (16 PNG, procedural from `bake_miner.gd`) | LIFT with the miner (already landed, D0268) | — |
| `assets/` | 32 | current sprites | LIVE |

---

## 4. The ordered execution steps

Each step: what, which files, the acceptance signal, what re-pins, and whether it needs the director.
**Run the two-process golden (`tests/test_shaft_replay_determinism.gd`) after every step; pin goldens
from CI Linux, never from a Mac (D0167).** Work lands on `main` in small green commits, one per sub-step:
`docs/BRANCHING.md`'s rule is main only, no feature branches, temporary worktrees allowed for comparisons
— an earlier line here said "branch per step" and contradicted it (corrected 2026-09-03, D0343). Every
judgment call gets a ledger entry in the same commit.

### Step 0 — orient, and transfer the harness protocol (no ruling needed)

1. Read this file, `docs/FLIP_ANALYSIS_2026-09-02.md`, then `CONTEXT.md`. Run `python3
   tools/gate_status.py` and confirm no FAIL. Confirm gate 8 green on the last CI run of `main`.
2. Port the 15 harness-protocol files (§3.2) into `tools/harness/`, and add an asserted-count refusal to
   `tests/test_base.gd::_finish` modelled on `legacy/tools/check_base.gd:145-160`. Mutation-test it: a
   suite with zero `_check` calls must print VACUOUS and exit non-zero.
3. Run the cross-platform probe: `legacy/tools/frontier_corpus.gd` prints integer worldgen tallies for
   12 seeds headless. **`legacy/` has no `project.godot`**, so run it from a scratch worktree at tag
   `pre-pivot` (import first); the Linux half runs in a `linux/amd64` container or on CI. Diff, record.
Acceptance: gates green, the new refusal caught by its mutation test, the probe result recorded.

**Status (2026-09-03): DONE — D0343.** The refusal is in `tests/test_base.gd::_finish` with the count on
every verdict line; `tools/test_test_base.sh` was observed failing on the pre-fix base (5 of 7) then
passing (7 of 7); CI runs it before the suites under gate 28; the full sweep was 67/67 with 0 VACUOUS. Item
2's "15 files" is scoped to the refusal now and the rest port with their subjects (the list is in D0343).
The probe: **48 of 48 rows identical**, macOS arm64 vs Linux x86_64 (emulated, not native — re-run on CI
before quoting as settled). Legacy's `FastNoiseLite` generator does not diverge across that pair; the
current build's divergence (gate 8 checkpoint 3) is therefore likely the libm transcendental sites
(`cave_passes.gd:86-91`) and the `lerpf`/hash-to-float roundings, not noise as such — a step 8 hypothesis.

### Step 1 — the grid planes: RULED 2026-09-03 (D0345), nothing blocks step 4

**Re-read against the tree on 2026-09-03 (D0343): two of this step's three parts were already ruled and
the third is forced.** `docs/ARCHITECTURE.md` §9's resolution table rules that machines, items, power,
conduits, ropes, torches and saplings live on the **16 px metre cell**, and that water "flows through"
the **fine 4 px grid**. D0019/D0020 and `TileGrid`'s own header rule that the 16 px grid is not a second
array of terrain; new planes are new state, not a copy, so they break neither, and `TileGrid` at 312 of
400 lines forces them into a sibling class regardless. The tree agrees with §9 on water: `Mining` clears a
13-cell disc at 4 px, so hand-dug tunnels never align to metres, and metre-cell water would either refuse
a tunnel the body walks through or draw over rock. The plan's original proposal here (water on the metre
cell) contradicted §9 and is withdrawn.

**What the executor builds under that, without asking:** `sim/world/logic_grid.gd` — the metre-cell
planes (machine index, ground piles, conduit, rope, torch, sapling, power, fill) keyed `logic_cell:
Vector2i`, with `TileGrid`'s two-lane running signature via `StateHash.term` (`core/state_hash.gd`); the water plane is
`sim/world/water_plane.gd` at the terrain cell (step 2, moved beside the other planes in 3b); every plane's signature folds into the
golden's checkpoint hash. Written up as an ADR (gate 20) before step 4 touches `TileGrid`/`Interface`.
Reversible: moving a plane between classes later is mechanical and re-pins a golden that re-pins anyway.

**Ruled (director, 2026-09-03, D0345): water at the 4 px grid; §9 stands.** "Water follows the dug shape
— the hole-as-conveyor premise wins over the compute saving; 120hz is optimizable, a broken water
mechanic isn't." Also approved: the hub's 20 Hz cadence on every third 60 Hz tick, and `BRANCHING.md`'s
main-only rule. Step 2's plane stands as built; step 4 wires it; the `LogicGrid` ADR records this ruled
state at the start of step 4.

### Step 2 — water, verbatim (no ruling needed)

Files: `legacy/src/core/water_flow.gd` → `sim/fluid/water_flow.gd`; `legacy/tests/test_power_water.gd`
water tests → `tests/test_water_flow.gd`; conservation added to `sim/invariants`.
What changes: nothing in the algorithm. The `sim` parameter becomes the water plane's owner. Name the
legacy source in the header. `WaterFlow.step` runs in the `fluid` phase of the tick order.
Acceptance: legacy's water tests pass; the conservation property ("no source, no drain, sum invariant")
holds over 10,000 fuzzed ticks; two-process golden green (no re-pin, water is not in the golden's world
yet). Gate 3: 100 lines, fine.

**Status (2026-09-03): DONE — D0344.** `sim/fluid/water_flow.gd` (algorithm verbatim, `_settle_run` split
for the 50-line cap), `sim/world/water_plane.gd` (the owner: legacy's `water` dict + accessors, running
signature, `displace()`; written to `sim/fluid` in D0344 and moved beside the other planes in D0347), `Invariants.check_water_conservation` / `check_water_not_in_rock`,
`tests/test_water_flow.gd` (45 assertions; 10,000 fuzzed ticks conserved). Keyed on the 4 px terrain cell
(step 1). **Landed in 3b (D0347):** the `set_solid`/`place_block` → `displace()` coupling, in `World.set_solid`; **left for step 4:** `WaterFlow.step` is not yet called from `Interface.apply` (no fluid phase runner
exists until step 3's tick order lands).

### Step 3 — lift the hub (no ruling needed for the lift; §8's rulings decide four records)

Files in: `legacy/src/core/factory_sim.gd` (live 2,591), `machine_state.gd`, `power_flow.gd`,
`flora.gd`, `save_game.gd`, `machine_def.gd`, `recipe_def.gd`, the `.tres` records, `world_seeder.gd`,
`main.gd`'s STATE-LOGIC blocks, the four legacy test files.
Files out, split at the seams L1 measured (function groups with legacy line ranges; each file ≤ 400
lines, each function ≤ 50, so the groups below become several files each):
- `sim/machines/`: registry and lifecycle (`place_machine` 1887, `remove_machine` 1901, `build_from_pack`
  1715, `pickup_machine` 1752, `machine_at` 374, `machine_eats` 388, `configure_machine` 3014,
  `set_split_mode` 3029, census/problems 1996-2046, the `_status_*` read API), `machine_state.gd`,
  `power_flow.gd` + `power_at`/`power_throttle` 2055-2066, the runners (`_run_machine` dispatch
  2071-2076, `_run_recipe` 2081-2117, `_run_generator` 2946-2956, `_run_hopper` 2301-2336, `_run_pump`
  2150-2161, `_run_drill` 2532-2618 with `drill_target`/`head_coverage`, `_run_splitter` 2289-2292 if
  ruled live).
- `sim/transport/`: `_run_lift` 2124-2138, the winch (`_run_winch_head` 2184-2219,
  `_advance_winch_transit` 2229-2244, `link_winch` 3042, `_purge_winch_route` 1733), and the gravity
  flow (`_flow` 2963-2995, `_destinations*` 3068-3089, `_split_pattern` 3004-3007, `_deliver` 3057-3063,
  `_column_landing`/`_settle_on_slope`/`_column_rise` 3095-3142). This is R1: down is free, up is powered.
- `sim/items/`: inventory and pack (`inventory_slots` 1564, `deposit` 1574, `drop_item` 1599,
  `take_into_pack` 1860, `can_carry`/`pack_room`/`carried_bulk` 1822-1859, `is_bulk_item` 1809 — replace
  `ResourceLoader.exists` with a data flag), ground piles (`collect_ground` 3176, `_ground_pile` 3147,
  `_resettle_pile_above` 3158, `_prune_empty_ground` 2047, `pile_reachable` 3224), lode
  (`lode_at`/`lode_workable`/`take_lode` 1509-1560, `ore_deposit_at` 1481).
- `sim/economy/`: `total_produced`/`total_consumed` accounting, `_sample_production` 1959 (derived, not
  saved), recipes as data. The demand side (rig-as-consumer) is step 7.
- `sim/world/`: the plane verbs (`set_solid` 703, `set_wall` 723, `place_block` 935, conduits 956-991,
  ropes 1002-1060, torches 1062-1099, water accessors 1100-1160, saplings 1198-1240, `block_supported`
  908, `cell_occupied` 927, `surface_row` 611, `ramp_dir` 690, `updraft_at` 585, foliage 620-689),
  `flora.gd`, `world_seeder.gd`, `load_world` 735.
- `sim/mining/`: `mine` 840 merges into the existing `Mining` (the current integer charge loop is the
  authority; legacy's `mine()` contributes `_ore_burst`, foliage settle, keep/spill); aim snap, LOS DDA,
  dig plan, lode cycle from `main.gd` (§3.2).
- `sim/commands/`: one typed command per live verb (28 mutators, 20 player-facing; the list is
  `FLIP_ANALYSIS` §3.5 and L1's mutator table: `mine place_block place_conduit remove_conduit place_rope
  retract_rope remove_rope place_torch remove_torch plant_sapling remove_sapling take_lode deposit
  drop_item build_from_pack pickup_machine configure_machine set_split_mode link_winch collect_ground`
  + the 8 world/fixture/save primitives).
- `shell/save_game.gd`: v3 (§5.3).
- `data/machines/*.yaml`, `data/recipes/*.yaml` + schemas + `generated.gd` via `tools/data_codegen`.
What changes on the way (all of §5.1 and §5.2): `progress` → ticks; power → milli-int; the recipe
`time` → ticks; sort before every state-affecting dictionary iteration except the hopper latch;
`advance(delta)` is NOT ported (the tick is driven by `Interface.apply`); `MAX_TICKS_PER_ADVANCE` and
`_tick_accumulator` do not come over; **the hub keeps legacy's 20 Hz cadence** — the body ticks at 60 Hz
(`Body.TICK_HZ`, ARCHITECTURE §4) and the machine/transport/items/fluid/economy phases run on every third
body tick (`HUB_TICK_DIVISOR = 3`), so every legacy tick constant ports verbatim and the hub's per-tick
cost lands at a third of the frequency; record the ledger entry when the runner lands; `terrain_dirty` and `flow_events` become Observation channels,
not sim fields the view clears; `_fine_solid`, `_fine_edge`, `_fine_grit` and `FineTerrain` do not come
over at all (render-only; the current bake owns the fine look).
Order inside the step: `machine_state` + data records first (they are leaves); then `sim/world` planes
against a temporary dictionary owner; then items; then machines + power; then transport; then economy;
then save; then `world_seeder`; then the `main.gd` blocks. Each sub-step merged green.
Acceptance: legacy's 54 live tests, ported, pass against the lifted modules; conservation holds over
fuzzed commands; every structural gate green (no file over 400, no function over 50, layer lint clean:
`sim/` imports nothing from `view/`, no engine class in `sim/`); the two-process golden green with the
new modules in its world, **re-pinned from CI Linux** because the world's contents change.
Ledger: one entry reversing the migration map's KEEP-CURRENT on `factory_sim.gd` (cite D0341), one per
judgment call inside the split.

**Status (2026-09-03):** 3a the leaves — DONE (D0346: 15 machine + 6 recipe records with legacy's
constants as integer fields, `craft_cost` refused at the gate, `MachineDef`/`RecipeDef`/`MachineState`,
`core/ordering.gd` after the `StringName` finding). 3b the world planes and verbs — DONE (D0347, ADR
0009: `LogicGrid`, `World`, `PlacedVerbs`, `WaterPlane` moved to `sim/world`; the deferred items are
listed in the ADR). 3c items — DONE (D0348: `Pack` with its two numbers in `data/player/`, `GroundPiles`, `Landing` — lifted
here rather than transport, with the machine buffer as a Callable — `Items`, `BuildVerbs`, the
`DepositPlane` as `World`'s fourth plane, `check_item_conservation`). 3d machines + power — DONE
(D0349: `Machines`, `PowerFlow` in milli-units, `Runners` for recipe/generator/hopper/pump/drill,
`MachineStatus`, `MachineVerbs`, `HubTick` at `HUB_TICK_DIVISOR = 3`; the deposit default corrected to
16 a 4 px cell; the drill bores the metre cell by cell; 112 assertions). 3e transport — DONE (D0350:
`Flow` as the hub tick's third phase, `column_rise`, `updraft_at`, `Movers` for the lift and the
Freight Winch with routes and transit on the registry and in the signature; the splitter waits on §8;
58 assertions). 3f economy's live remainder — DONE (D0351: `ProductionRate`, centi-items a minute over a
61-sample window, derived and unsigned, sampled by `HubTick` when handed one; 19 assertions). 3g save v3
— DONE (D0352, ADR 0010: `shell/save_game.gd`, 22 keys over every plane, the ledger and the registry;
staged then committed in place; legacy's durability protocol; 45 assertions). **Deviation from §5.3:** v3
is this game's first version and a pre-pivot v2 envelope is refused by name, not migrated — listed
under §8. 3h `world_seeder` — DONE (D0353: `data/starts/` with legacy's tutorial opening as a record,
`sim/run/world_seeder.gd` stamping it through the sim's verbs — in `run`, not `terrain_gen`, because it
places machines and stocks the pack; the tree and the tool kit not carried; 36 assertions). 3i the
`main.gd` blocks, mining half — DONE (D0354: `LineOfSight` in exact integers pinned against legacy's
float walk off the ties, `Aim`, `DigPlan`, `LodeWork`, `Items.yield_break`; LOS gates the verbs, not the
primitive; 48 assertions). 3i verbs half — DONE (D0355: `sim/run/verbs.gd`, the situated verbs over the
four services; one reach rule through `Aim`; 40 assertions). **STEP 3 COMPLETE.**

**Status (2026-09-03), step 4:** 4a — DONE (D0356: the door owns every service; `Observation` in its own
file with the hub's planes as window-bounded copies; the hub cadence inside `MOVE`; the consumed
flow-event channel; one session signature; 20 assertions). 4b — DONE (D0357: nine `Command` kinds
with details and reasons, the mine hold on the move frame, the session captured and restored through
the door with the body's and the mining state's keys, `new_game` on the spawn; 34 assertions). **STEP 4
COMPLETE.** Next: step 5 (the `Fx` vector layer and the grapple; the resolver ruling gates its
collision half).

**Status (2026-09-03), step 5:** 5a — DONE (D0358: `Fx.normalize`/`dot`/`limit_length`, both divisions
toward less energy; 17 assertions). 5b — DONE (D0359: `sim/body/grapple.gd`, the solver under `Fx`
with exact one-cell probes, the wrapping polyline, projection and radial cancel through the raw delta;
63 assertions; the coordinate gate's `fx` tag). 5c — DONE (D0360: `Surroundings`/`WorldSurroundings`,
the swing coupled in `body_swing.gd` with the collision stand-in, the medium in `body_medium.gd` — rope
climb, updraft, water — the coast, the step-down snap, machines block and wood passes on every side of
the body, `place()`; the ramp glide left out pending the ruling; 69 assertions across two suites; the
replay golden re-pinned from CI Linux). 5d — DONE (D0361: `view/visuals/rope_painter.gd` on the `Frame`
contract — placed ropes, the bowed cord, the hook, the aim ghost from the door's own trace — and
`carry_look.gd`; 20 assertions). **STEP 5 COMPLETE.** Next: step 6 (the views the systems unblock and
the boot main scene in `shell/`); open rulings from step 5 in §8 (the resolver, the ramp glide).

**Status (2026-09-03), step 6:** 6a — DONE (D0362: `view/visuals/water_painter.gd` with the layout split
from the paint, `view/fx/water_drips.gd`, `Observation.wet_cells`; 33 assertions; the capture pair
waits on a start record with water in frame). 6b — DONE (D0363: `machine_look.gd`, `machine_glyphs.gd`,
`status_look.gd`, `item_look.gd`, dead entries out, pinned against the data; 27 assertions). 6c — DONE
(D0364: `machine_painter.gd` + `machine_labels.gd`, stateful, chrome at `CHROME_SCALE`, the flash from
watching records appear; 35 assertions). 6d, 6e — DONE (D0365; `payouts.gd` reads gains off the pack, 21 assertions; `falling_items.gd` on the consumed channel, landings merged by cell and consumed once, the scene owns it, 25 assertions). 6f (i) the beds — DONE (D0366; `bed_bank.gd` ten loops closed on whole cycles, 44 assertions; `beds.gd` static mix maps, 23; `bed_levels.gd` off the observation against the generated datum, 37; the scene's audio in `reveal_audio.gd`). 6f (ii) — DONE (D0367; `voice_bank.gd` eleven one-shots 39, `voice_cues.gd` edges over two observations 39, `sfx_space.gd` the room 20; the fallback restored to legacy's crunch, the driver suite's rows moved with it). 6g the hotbar — DONE (D0368; `hotbar.gd` on the layout/paint split, the PACK FULL chip, 35 assertions; the inventory overlay is the bazaar's and stays dead). 6h (i) the inspector — DONE (D0369; `inspector.gd` merges hover_info and _draw_hover, content re-authored, `aim_in_reach` on the observation, stands down under the plate, 43 assertions). 6h (ii) — DONE (D0370; `objectives.gd` 25, `hints.gd` 26, `objective_line.gd` 16, `hint_bubble.gd` 18; mechanisms whole, every row re-authored). 6i the minimap — DONE (D0371; the grid's coarse class plane at the mutators, the observation's `map`, `minimap.gd` keyed on the version, 24 + 49). 6j the settings page — DONE (D0372; `settings_page.gd` + `settings_draw.gd` on legacy's split with the values as a snapshot, `page_draw.gd`, the theme's eighteen tokens; 32 + 9). 6k lights S2 — DONE (D0373; `light_painter.gd` on an ADD canvas over the veil, the lamp bloom on the veil's own centre and scale, pools grouped by light, godrays, torches, conduits, motes, the water sheen; 31 assertions). 6l (i) ore S4 — DONE (D0374; `ore_painter.gd`: the flood in metres held byte-identical to the quadratic reference, the seam glow from its own hue on a second ADD canvas, the lode's flecks a live pass over the wall's baked socket; 43 assertions). 6l (ii) — DONE (D0375; `veil_sources.gd`: legacy's source loop as cuts with a colour, `light_rgb_at` composing per channel, the map's texel tinted; 37 assertions). 6m marks S5 — DONE (D0376; `mark_painter.gd` the shapes, `mark_layout.gd` the list, `interface/aim_planes.gd` the affordances from the verbs' own predicates; 43 assertions). 6n ambience S6 — DONE (D0377; `ambience_painter.gd`: tubes and beads, torches, saplings, piles, updrafts, guides under the machines, streaks, every rule a function; 40 assertions). 6o terrain remainder — DONE (D0378; the coarse chamfers/fillets/AO ruled not portable at the cell; `surface_tone.gd`: soil profile, moss, tufts, the cap on the band-gated walked line; 29 assertions). Next: the two shaders (heat haze, rock tooth).

### Step 4 — the grid planes, the door, the verbs (needs step 1's ruling)

Files: `sim/world/tile_grid.gd` (planes per the ruling; each plane enters `state_signature()` and
`recomputed_signature()`, with a mutation test per plane), `interface/interface.gd` (`Observation` gains
the 20 accessors legacy's renderer reads that the current 34 fields do not carry: `deposits
ore_deposit_at lode lode_fraction machine_at machines water water_at fill conduit has_conduit power_at
torch ground sapling inventory is_foliage_material is_climbable ramp_dir terrain_dirty`; `apply` gains
the 28 verbs as `Command` kinds with named rejection reasons), `sim/commands/command.gd`,
`tests/test_interface.gd`, `tests/test_tile_grid.gd`.
Acceptance: `observe()` stays pure (asserted against `state_signature()` as `test_interface.gd:287-289`
does today); every new field is int/`Fx`/per-mille ("a float in an observation is a float in a
replay"); the running hash self-check passes after 400 randomised mutations across every plane; golden
re-pinned. **The vacuous-gate trap:** `layer_lint`, `no_engine_imports`, `check_coordinate_naming`, the
`MODULE.md` rule and `schema_validator` print `PASS (vacuously)` when their policed directories are
empty or unmapped; after adding modules, read each gate's own count line and confirm it is non-zero.

### Step 5 — PRE-2 and the grapple (needs a resolver ruling before its collision half)

Files: `core/fixed_point.gd` (+`normalize`, `dot`, `limit_length`, ~40 lines, with tests over hostile
inputs; both roundings fail toward less energy), `sim/body/grapple.gd` (from `legacy/scenes/grapple.gd`,
§3.2), `sim/body/body.gd` swing coupling (`player.gd:172-183, 271-274, 393-406`), the 9 missing body
mechanisms from `player.gd`, `view/visuals/rope_painter.gd`, `tests/test_grapple.gd` (port the
assertions of `check_grapple`, `check_pump`, `check_traverse`, `check_teaching`: 2,916 lines of legacy
rope-feel checks with no current equivalent).
Ruling: the grapple's collision half touches the resolver, which is parked (`NEEDS_DIRECTOR.md` P-28);
the `Fx` layer and the solver can be built before it, the collision hookup cannot.
Acceptance: `test_body_acceptance` and every body suite still green (the body corpus is numerically
calibrated to the current body: `hostile_chamber` and `movement_course` constants); rope suite green;
golden re-pinned (body state changes).

### Step 6 — the views the systems unblock (no ruling needed; look verdicts are the director's)

In this order: water painter (needs step 2+4) → machine look/item look/status look registries →
machine painter → payouts → falling items → sfx beds → hotbar and inventory HUD → inspector, objectives,
hints (content re-authored against what exists) → minimap → settings page → lights S2 with `(z, blend)`
on `add_painter` → ore S4 → marks S5 → ambience S6 → terrain painter remainder → the two shaders → the
boot: a main scene in `shell/` so `godot --path .` runs the game (today nothing does; `project.godot`
has no main scene). Every painter is static, reads only `Frame`/`Observation`, and splits its layout
decision from its `paint()` so a test can fail on it (the pattern every current painter follows).
Acceptance per painter: a capture pair before/after on the same recorded input, pixel-diffed with the
histogram method (`capture-diffing-noise-floor`: a diff of 0 has two causes; use an ungated full-fill
control); `draw_cost` report stays under budget at both framings; a look verdict goes to
`TASTE_QUEUE.md` as BUILT-PARKED, never "done".

### Step 7 — the economy, rig-as-consumer (the director scopes it)

Not a port. `docs/GDD.md` §3, §7, §11: the rig at the top wants specific material in specific quantity
per unlock; D1 currently drafted as 30 iron ingot unlocking the drill; every demand requires at least
one material inaccessible before the previous unlock. Files: `data/economy/*.yaml`, `sim/economy/`
demand and delivery, the rig in `sim/meta/` or `sim/world/`, `claims/C003` threshold set from a first
real playthrough. `tools/economy_check/` is parked (D0153) and waits for it.
Acceptance: C003 measured; a thirty-minute human session that still wants something.

### Step 8 — cross-platform determinism and the worldgen content (when it matters)

Files: `sim/terrain_gen/value_noise.gd`, `shaft_generator.gd`, `cave_passes.gd`, `core/split_rng.gd`
(the four D0183 sites, §5.4) → `Fx` noise, integer range draw, calibration re-derived, thresholds in
`data/strata/*.yaml` re-tuned, every golden re-pinned (D0172). Then the ~420 lines of legacy worldgen
content (§3.3) ported on top of the deterministic generator, its four transcendental shapes
(`heightmap:129-135`, `layered:416-420, 460-463, 547-549`) as integer tables.
Acceptance: gate 8's golden identical on macOS-arm64 and Linux-x86_64 for a run that walks generated
terrain (today it diverges at checkpoint 3).

---

## 5. The determinism specifics

**The rule:** two-process golden green after every step; goldens from CI Linux; determinism is never
deferred and never silently broken. A determinism divergence pauses everything else.

### 5.1 The 24 live rows in `factory_sim.gd` (fix on the way in)

| row | legacy line | what | fix |
|---|---|---|---|
| 001 | 2095-2098 | `progress += SECONDS_PER_TICK` vs `recipe.time` | `progress_ticks += 1` vs `time_ticks` |
| 002 | 2567-2570 | drill cycle, same pattern | same |
| 003 | 2892-2902 | crusher `power_factor <= 0.0`, `progress += 0.05*pf` | milli-int; or leaves with the crusher (§8) |
| 004 | 2055-2056 | `power_at` float read | milli-int plane read |
| 005 | 2063-2066 | `power_throttle = clampf(power/demand, 0, 1)` | integer per-mille: `clampi(power_milli * 1000 / demand_milli, 0, 1000)` |
| 006 | 2125-2126 | lift cap `2 + int(round(4.0 * pf))` | `2 + (4 * pf_permille + 500) / 1000` |
| 007 | 2151-2152 | pump budget `int(round(3.0 * pf))` | same shape |
| 008 | 2185, 2192 | winch trip cap `int(round(8.0 * pf))` | same shape |
| 009 | 22, 43, 51, 56, 94, 119-122, 135 | float constants on the state path (`SECONDS_PER_TICK`, power demands, `GENERATOR_POWER`) | integer constants in `data/machines/*.yaml` |
| 010 | 2095, 2125, 2151, 2185, 2892 (+ `machine_state.gd:16,25`, `save_game.gd:79-80,202,205`) | saved float fields `progress`, `power_factor` | ints; save v3 |
| 011 | 358, 1930-1938 | `advance(delta)` wrapper, drops backlog past 6 ticks | do not port; the tick is driven by `apply` |
| 012 | 2089, 2099, 2107 | `_run_recipe` dict order → output order | sort keys |
| 013 | 2128 | `_run_lift`: which items move under the cap | sort keys |
| 014 | 2206, 2240, 2243 | winch load composition and delivery order | sort keys |
| 015 | 2290 | splitter pass-through order | sort keys (if ruled live) |
| 016 | 2309, 2310, 2326 | hopper latch "first thing it tastes" | **KEEP insertion order — it is the designed rule**; guarantee the insertion sequence is tick-ordered instead |
| 017 | 2887, 2904 | crusher pass-through and 2:1 consumption order | sort keys, or leaves with the crusher |
| 018 | 2987 | `_flow` deal order → `route_toggle` → splitter column | sort keys |
| 019 | 3060 | `_deliver` insertion order | sort keys |
| 020 | 3165 | `_resettle_pile_above` re-insertion order | sort keys |
| 021 | 1768-1779 | `pickup_machine` salvage order vs pack cap | sort keys |
| 022 | 3187-3188 | `collect_ground` which items fit | sort keys |
| 023 | 1815 | `ResourceLoader.exists(...tres)` decides bulk class | a `bulk: bool` field in `data/machines` |
| 024 | 355-356, 829-831 | `FineTerrain.sync_block` samples `FastNoiseLite` inside tick (render-only output) | do not port |

Godot 4 dictionaries preserve insertion order, so every HASH-ITER row is deterministic today; the sort
is the ARCHITECTURE rule's cost and each one changes the golden. **"Sort keys" means `Ordering.ids(dict)`
(text order), never `keys().sort()`: `StringName` sorts by pointer (D0346, §9).** Insertion order of the `machines`
Array is real state (placement order is unrecoverable from the grid) and the save preserves it.

### 5.2 The 8 rows in `power_flow.gd` and the 6 elsewhere

`power_flow.gd:12,88` `GENERATOR_POWER 6.0`; `:28-29` aura `amount*(1-dist/3)`; `:54-57` inflow ×0.92,
cap 12.0; `:63` and `:67` lateral keep ×0.80; `:70-74` merge with `v <= 0.0` membership; `:78` bleed
×0.6; `:85` feeder read. Convert the field to milli-int (6000, ×92/100, cap 12000, ×80/100, ×60/100),
~16 lines here plus ~15 at the consumers in the hub. `machine_state.gd:16,25` the two fields.
`recipe_def.gd:14` `time`. `mining_rules.gd:38-49` HARDNESS seconds (already ticks in `sim/mining`;
`earth` 0.28 s = 5.6 ticks, re-tune to 6 or 5 with the director). `flora.gd:15` sort. `save_game.gd:321`
sort. `world_seeder.gd` one literal-dict loop.

### 5.3 The save (v3)

Legacy v2 keys, 23 top-level: `version world_seed solid wall deposits lode lode_max inventory ground
sink produced consumed conduit rope torch water fill research sapling winch_routes winch_transit
seep_tick machines`; 13 per machine: `def cell in out spoil progress route_toggle fuel power_factor fed
facing mode filter`; the caller adds `player_pos`. v3: `progress` → `progress_ticks`, `power_factor` →
`power_permille` (or drop it: it is derived and recomputed before any consumer reads it), `research`
removed from `REQUIRED_KEYS` (41), `player_pos` as two `Fx` ints, `_tick_accumulator` gone, `_fine_solid`
gone. Keep the atomic tmp+bak write, the transactional stage/commit, the refuse-on-missing chain, and
the `machines` Array order. Migration v2→v3 unit-tested against a stored v2 fixture (gate 12).

### 5.4 The scene-layer rows, and what A′ does with them

The 23 within-platform rows of the analysis (`main.gd` 17, `player.gd` 2, `grapple.gd` 2,
`factory_sim.gd` 1, `hints.gd` 1) are the two-clock defect. Under A′ `main.gd` and `player.gd` are
REFERENCE, so most of those rows are not ported; the ones that are (the mining shell blocks, the grapple
clocks, `hints_taught`) land as tick-driven integers by construction because everything in `sim/` is
driven by `Interface.apply` per tick.

### 5.5 The current build's own crack (step 8)

Four sites, still present at HEAD, line numbers drifted from D0183: `sim/terrain_gen/value_noise.gd`
`_corner_value` hash-to-float; `shaft_generator.gd` `depth_frac`/`lerpf` threshold (~157-158) and
`_density_count` (~184-185); `core/split_rng.gd:58-60` `next_range` multiply. Plus
`cave_passes.gd:86-91`. Within-platform exact; macOS-arm64 vs Linux-x86_64 diverges at checkpoint 3 of
the golden. Every worldgen change until step 8 re-pins from CI Linux.

---

## 6. What transfers as code, and what as pattern

**Lift as code (it exists, use it):** `core/fixed_point.gd` (`Fx`), `core/split_rng.gd`,
`core/entity_id_pool.gd`, `core/seams.gd` (exact over 196,608 inputs, wrong conversion kept as a
failing control), `sim/body/*` (1,169 lines, 102 tests), `sim/mining/mining.gd` (the integer charge
loop), `sim/world/tile_grid.gd`'s running hash with `recomputed_signature()`,
`tests/test_shaft_replay_determinism.gd` + `tests/fixture_shaft_replay_probe.gd` (the two-process
golden), `tests/test_body_fuzz*.gd` (the goalless fuzzer), `tests/test_recorded_sessions.gd`,
`tests/test_base.gd::over()` (the vacuity guard), `tools/run_gd_test.sh` (masked-crash guard),
`tools/layer_lint/check_ci_not_shrunk.py`, `tools/formatter/`, `tools/gate_status.py`.

**Use as the worked reference for converting legacy (do not rebuild):** `sim/body` is the template
for float-kinematics → `Fx`; `sim/mining/mining.gd` for float accumulator → tick counter with legacy's
order of operations preserved; `tests/test_seams.gd:34-83` for the proof pattern (legacy float
expression as oracle, all inputs swept, the tempting wrong conversion as a control that must fail);
`tests/test_cave_passes.gd:209-233` for `cos/sin` → integer heading tables; `tests/test_mining.gd` for
anchoring tick counts to legacy's seconds.

**Legacy patterns worth copying:** `legacy/tools/check_pile_reach.gd` is already the shape of a
deterministic sim test (`FactorySim.new()` + `tick()` × 400, no scene, no delta);
`legacy/tools/play_agent.gd`'s two arrival rules (two axes; stopped) are bugs already paid for;
`water_view.gd`'s header carries its own extraction-seam table; legacy's `HELPER_TAGS` asserted-total
pattern for a split HUD.

---

## 7. Performance rules the executor holds to (120 Hz)

Measured 2026-09-01 at the default framing: painters 4.01 ms (`veil 2.99 sky 0.97 glint 0.03 bake
0.01`), sim tick 1.58 ms, frame ≈ 5.6 ms against 8.33. The rules, from `docs/PERF_PLAN.md` and D0340:
- Nothing loops per cell per frame. Per dirty chunk or per screen at metre resolution only. The
  quarter-metre grid is for digging and collision; per-frame code reads it only through the bake.
- Machines, items and power live on the metre cell; water flows through the 4 px terrain cell
  (ARCHITECTURE §9; step 1 as re-read in D0343). Legacy's 128×128 world is 16k water cells at a metre and
  262k at a quarter-metre, but `WaterFlow` iterates WET cells only, so its cost follows flooded volume,
  not world size; the water painter (step 6) is where quarter-metre resolution has to be paid for, and it
  pays the way D0336's veil did — one texture, one draw.
- Measure with `view/draw_cost.gd` inside the frame. A wall-clock slope under `_physics_process` is the
  clock below ~16.7 ms (D0340). Vsync makes a millisecond number unanswerable (`check_frametime.gd:29`).
- Budget the widest zoom rung (9.2× the default area), not the default. Unmeasured since D0336; the
  veil scales with visible metres.
- **Two hypotheses to measure before touching anything else in this section:** (1) D0335 widened the
  play site to 256 × 1,024 = 262,144 quarter-metre cells and the one-shot bake was predicted to hitch
  near 289k (`WORKING.md`, 2026-09-01); the progressive bake (`fine_terrain.gd:768-812`) is the fix
  and is LIFT. (2) The wide rung. Run `draw_cost` at the framing the director plays, on a dig.
- Flat `PackedByteArray` planes instead of `Vector2i`-keyed dictionaries when a plane is walked per
  frame (`PERF_PLAN` item 1; touches `state_signature` storage, so it re-pins).
- If a benchmark scenario at `docs/ARCHITECTURE.md` §10's load still misses, that is the §12 trigger for
  a GDExtension hot loop, and not before.

---

## 8. Rulings only the director can make (do not guess these)

| ruling | blocks | proposal on the table |
|---|---|---|
| ~~Grid planes~~ **RULED 2026-09-03 (D0345):** water at the 4 px terrain cell, §9 stands; machines/items/power at 16 px on a `LogicGrid` sibling; ADR written at the start of step 4 | nothing | — |
| Splitter (GDD §9: "two carved chutes are a splitter… must be a stated decision") | 4 legacy tests, `_run_splitter`, `_split_pattern`, `split_mode` | — |
| Ore Vent (an infinite free source; fights R2) | 10 legacy tests fixture on it | — |
| Power gating (R1-entangled; removing power silently freezes upward machines) | 2 legacy tests, V11 wiring | port the mechanism, do not wire the tier (Q3) |
| Crusher + gravel + packing + seep (133 lines, exists for the Drift Rig) | step 3 | not on §9's list; rule before calling it dead |
| `press_plate`, `mill_gear` (terminal products) | 2 recipes | machines survive; outputs need a consumer or go |
| Material id vs item id (D0349): a bored `ore_iron` block yields the item `ore_iron`; the recipes take `ore`, `iron`, `rich_ore` | the automated line end to end; step 7 | a `yields:` field on the material record, or recipes renamed to the material ids |
| Pre-pivot (v2) saves (D0352, ADR 0010): refused by name, not migrated — §5.3 asked for a migration | nothing: no player holds one, the current build never saved | keep the refusal; a converter is a later migration branch if you want legacy worlds to open |
| HARDNESS `earth` 0.28 s = 5.6 ticks | `sim/mining` | 6 ticks |
| `sim.ramp_dir` authored ramps vs `Heightfield` | nothing now: step 5c ported the other eight mechanisms and left the ramp glide out (D0360) | superseded by the heightfield; confirm, or the glide is a small lift onto `Heightfield` |
| The resolver (P-28) | the swing's re-resolve: step 5c shipped a STAND-IN (D0360: a projected position whose box would overlap rock is refused and the line reads slack for the tick; same outcome at a flat wall, holds instead of sliding at a corner) | rule on the resolver, then the stand-in becomes legacy's re-resolve of both axes |
| `tests/body/recordings/` 36 untracked logs | gate 27 | commit as corpus or gitignore |
| `history/` cull to 12 | nothing | director-action |

---

## 9. Traps, each already paid for once

- **Vacuous gates.** Five structural gates exit 0 with `PASS (vacuously)` when their policed set is empty.
  After every new module, read the gate's own count line.
- **Two clocks.** Never let anything in `sim/` see a frame delta. Everything advances through
  `Interface.apply` per tick. Fast-forward is ticks-per-frame in the shell.
- **The hopper latch** (5.1 row 016) is designed insertion-order semantics; sorting it changes the game.
- **`Player.note_dig` is labelled "Cosmetic only" and sets `facing`**, which decides a drop's target cell
  and a placed machine's direction (`main.gd`). `FallingItems` clears a sim array. Do not trust
  comments about what is cosmetic; trust the state trace.
- **`StringName` sorts by pointer, not text** (D0346). `.sort()` / `sort_custom(<)` / `keys().sort()` over
  ids return creation order — a within-platform breaker that reads as "sorted". Every "sort keys" row in
  §5.1 goes through `core/ordering.gd` (`Ordering.ids`); grep `sort` on every lifted block.
- **The reciprocal literal**: `1.05*65536 = 68812` and `1/1.05*65536 = 62415` are not inverses. Store
  `21/20` and use integer mul/div, as `AIR_CONTROL_NUM/DEN` and `Mining.REACH_NUM/DEN` do.
- **Unit regime** (§3.2): ask which of three regimes a constant is in before converting. Body constants
  port in pixels unchanged; per-cell rates convert ×4/×16; fields of view ×2.
- **A count without membership** (`hud.gd`'s minimap cache keyed on `sim.solid.size()`): use a version
  counter, never a size comparison.
- **A capture diff of zero has two causes**: use an ungated full-fill control from the same layer.
- **Goldens from CI Linux**, never from the Mac. A harness failure notice and a completion notice are
  both claims; the artifact is the evidence.
- **Legacy tests' `_state_signature` renders two floats through `str()`**, so legacy's own determinism
  greens cannot see sub-print drift. The lifted sim has no floats, so the ported tests can use the exact
  `state_signature()`.
- **The `FineTerrain` name shadow**: `factory_sim.gd:19` declares a local `const FineTerrain` that shadows
  the global painter class. A token-based dependency graph draws a false sim→view edge from it.

---

## 10. Definition of done

Per step: tests written and passing; invariants hold; `MODULE.md` updated; telemetry added where a
measured behaviour changed; at least one scenario exercises the path and names a claim; no new lint,
layer, size or ratio violation; balance numbers in `data/`, not code; the ADR merged first where the
step touches an ADR-gated area (`docs/QUALITY.md` §8). Plus this plan's own rule: two-process golden
green, re-pinned from CI Linux when the world changed, and a ledger entry per judgment call.

Overall: §2's acceptance, all five lines.
