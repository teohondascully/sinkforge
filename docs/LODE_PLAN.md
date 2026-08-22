# The lode migration: plan, blast radius, and the eval gate

Companion to `docs/LODE.md`, which is the design. This document is the how: what breaks, in what order it
gets fixed, what has to be true before each phase is allowed to land, and how to get back.

Rollback marker: tag `pre-lode` = `27fe6a3`, pushed. The harness was green at that commit with a clean
working tree. `git reset --hard pre-lode` returns the game to the pre-migration model in one command.

The table below cites files and symbols rather than line numbers. `factory_sim.gd` alone is over two
thousand lines and moves constantly, so a line number in a plan is stale before the plan is finished.

## 1. Why this needs a plan

Ore is the oldest system in the game and the most depended upon. It is read by the sim, the generator,
the renderer, the HUD, the sonar, the tutorial ladder, the hint table, four machines, the play harness
and a large fraction of the harness suite. Changing what an ore cell *is* changes the meaning of
assertions written across nine months of work, including at least one that inverts: `tests/test_sim.gd`
used to assert that a hand-mined ore cell is no longer a vein, which is precisely the behaviour being
deleted.

The failure mode to design against is not a bug. It is a half-migrated world: two ore models coexisting,
where the generator believes one and the drill believes the other, with a green harness because every
layer was updated to agree with whichever model it happened to touch. That state is unbisectable, and it
is how this kind of change goes wrong.

## 2. Blast radius

| System | Where | What breaks |
|---|---|---|
| Ore identity | `factory_sim.gd` `_is_ore_like` | the predicate that makes a *block* special stops being about blocks |
| Hand-mining | `factory_sim.gd` `mine()`, the ore-like branch | the destructive path, which is the whole point |
| Drill | `factory_sim.gd` `drill_column_remaining`, `_run_drill` | "bore down through solid ore" has no referent |
| Borer | `factory_sim.gd` `h_drill_target`, `_run_h_drill` | the same, laterally |
| Drift Rig | `factory_sim.gd` `drift_target`, `drift_is_pay`, `_run_drift` | its pay stream comes from eating ore blocks |
| Generator | `layered_world_gen.gd` `_scatter_veins`, `_scatter_coal`, `_grow_vein`, `_scatter_iron`, `_seed_aquifer_treasure`, `_mineralize` | every vein, coal patch, iron body and aquifer reward is authored as `blocks` plus `amounts` |
| World data | `world_data.gd` | needs a `lodes` grid alongside `blocks` / `walls` / `amounts` |
| Spawn fixtures | `world_seeder.gd` `_seed_starter_vein`, `_seed_tutorial_coal`, `_seed_starter_adit`, the mineshaft vein | the entire opening |
| Sonar | `main.gd` `try_scan()` | it guards on `sim.is_solid(cell)`, so prospecting would find nothing |
| Aim and hover | `main.gd` `_hover_info_at`, `hover_info.gd` `describe`, `world_renderer.gd` `_draw_aim` | "a rich vein reads as a thing" is keyed on solid |
| Glints | `world_renderer.gd` `_exposed_ore_cells`, `_draw_glint_flares` | both iterate `deposits` and require `is_solid` |
| Terrain paint | `terrain_painter.gd` | richness-tinted rock reads `sim.deposits` |
| Minimap | `hud.gd` `_draw_minimap` | ore blocks colour the map |
| Tutorial | `objectives.gd` steps 38, 44, 45 | "Dig ore, hold LMB on the metal-flecked rock by spawn" and "Drop the Drill into the shaft just ABOVE the ore vein" both go false the instant worldgen flips |
| Hints | `hints.gd` | scanner, rich ore and borer copy |
| Save | `save_game.gd` | a new layer to persist |
| Play harness | `arc_driver.gd` `_step_mine`, `play_agent.gd` | step 1 is "hand-dig 4 ore", and `PlayAgent` has no verb for working a lode |

The layers that touch ore or drilling at all: `test_sim`, `play_tests`, `test_stress`, `arc_driver`,
`test_power_water`, `test_worldgen`, `check_saveload`, `check_bits`, `check_drift`, `check_spoil`,
`capture_moments`, `mock_bazaar`, `check_underground`, `check_pack_layout`, `check_controls`. An earlier
draft of this section carried per-file reference counts. They were produced by counting lines matching
`ore|drill`, which also matches "more", "before" and "stored", so the counts measured the word and not
the system. They are omitted rather than corrected.

## 3. Strategy: build it fully, then cut over once

Three candidate shapes were considered.

- **Big bang.** Flip everything in one commit. Rejected: the harness is red for a long stretch, which is
  exactly when the working rule ("if red, revert, don't patch") stops being usable, and nothing is
  bisectable.
- **Permanent bridge.** Keep solid ore and lodes forever. Rejected: two ore models is the failure mode in
  §1 wearing a friendly face.
- **Build, cut over, clean up.** Chosen.

What makes the chosen shape safe is that the entire lode mechanic (the layer, the verbs, the rendering,
drill coverage, the tells) can be built, played and asserted while ore is still solid, because hand-mining
an ore block is a natural way to *create* a lode. Phases 1 and 2 are therefore purely additive: the game
stays playable and the harness stays green throughout. The cutover in phase 3 then reduces to a data
change, where the generator emits lodes instead of ore blocks, plus deleting a path that by then has no
users. Small, reviewable, revertable on its own.

## 4. Phases

Each phase is one commit or a tight run, lands green, and is independently revertable.

### Phase 1: the lode exists, and the trap is gone (SHIPPED)

Player-visible change: mining ore stops destroying the vein. Nothing is removed.

- `factory_sim.gd`: a `lode` dictionary (cell to ore id) plus `lode_max`; `lode_at`, `lode_workable`,
  `lode_fraction`, `take_lode`. `mine()` takes the burst *out of* the deposit and leaves the remainder as
  a lode; `ore_deposit_at` reads both; `load_world` clears it.
- `save_game.gd`: persist and restore additively, matching the `fill` and `spoil` precedent. `lode` is
  deliberately absent from `REQUIRED_KEYS`, so an old save loads with an empty lode layer.
- `main.gd`: `_lode_workable`, the hold-to-work cycle inside `_update_mining` (a short repeating cycle
  that yields and cracks nothing), the `try_work_lode` verb, and `_refuses` / `_drive_bites` extended so
  the existing crossed cursor and skid answer an over-tier lode for free.
- `world_renderer.gd`: `_draw_lode`, a persistent fleck field on the back wall thinned by `lode_fraction`
  so a worked-out vein looks worked out; the glint pass extended to lodes.
- `hover_info.gd`: an exposed lode reads as a vein with what is left in it.

New layer `tools/check_lode.gd`, 53 assertions when this phase shipped. Two existing assertions changed and were argued in
place: `test_sim`'s finite-deposit inversion, and the save round-trip. The lode's rendering wanted to be
part of the wall bake rather than an overlay, which the plan had not anticipated; `docs/LODE.md` records
the deviation. One assertion in `check_lode` was caught passing vacuously, because the Wedge never landed
a blow and so "nothing was destroyed" meant nothing; the fixture was rebuilt as a real ore body.

### Phase 2a: the Drill Head (SHIPPED)

Player-visible change: drills can be placed on an exposed lode. The old placement still works.

Split out from phase 2 deliberately. The Head is a complete, playable, assertable unit, and the Spur is a
separate design commitment: a new machine, a research rung, and a coverage model. Not one existing drill
assertion needed to change, which is the additive claim in §3 holding rather than being asserted.

- The Drill accepts a cell whose backing is a lode, drains it in place, and still pours down its own
  column. The on-hook rule is asserted rather than assumed. The old bore-down-through-solid path is
  untouched.
- `drill_preview` over a lode shows one cell rather than a column, which is a placement legibility win
  taken by deleting geometry rather than drawing more of it. `drill_column_remaining` reports the face it
  stands on.
- A `spent` status with its own words and a cool (not alarmed) lamp, distinct from `no_input`. Choosing
  between them requires the Head to remember it has pulled something, so a misplaced drill still reads as
  starved.
- A Head is never `blocked`. With no shaft under it the ore piles at its feet, like every other item in
  this game when it lands; refusing to run to prevent a pile would invent a chore (`docs/DRIFT.md` §5).

New layer `tools/check_head.gd`, 40 assertions when this phase shipped.

### Phase 2b: the Spur (SHIPPED)

Player-visible change: one Head can work a whole vein.

`src/data/machines/spur.tres` is a passive coverage extender placed adjacent to a Head or another Spur,
adding its own cell's lode to that Head's draw. Passive on purpose: no power question, and the Head keeps
owning the fuel. `MainView.spur_fits` gates placement on a lode with a reachable Head. It is behind its
own research rung rather than unlocking with the drill, because otherwise you never feel that a Head
covers one cell.

*Attested: `src/data/machines/spur.tres`; `factory_sim.gd` `_run_spur` / `_status_spur`;
`scenes/main.gd` `spur_fits`, `spur_head`; `tools/check_head.gd` `_a_spur_is_one_more_mouth`,
`_a_spur_must_reach_something`.*

### Phase 3: the cutover

Originally planned as one commit that both moves the generator and deletes the solid-ore path. It was
split on 2026-08-17 and only the first half has landed.

**3a shipped in `303d1f5` and `8498ae3`, and is deliberately additive.** `WorldData.lodes` exists.
`LayeredWorldGen._seed_lodes` and `_grow_lode` write lode bodies into the background plane behind rock
that stays solid; `_grow_lode` writes only `world.lodes` and `world.amounts`, reads `world.blocks` purely
as a host-rock guard, and `_seed_lodes` runs last in `generate`, immediately before it returns.
`FactorySim.load_world` ingests them after `amounts`, because a lode's richness is its deposit and
`lode_max` has to read what was loaded. Determinism holds. `tests/test_worldgen.gd` runs the overlap
guards over every lode cell rather than a sample, and the chain is proven end to end on a generated
world: buried is not workable; clear the rock and it becomes workable; work it and it yields its ore.

**What 3a is not.** It does not make every vein, patch, body and reward emit a lode plus host rock
*instead of* an ore block. Nothing above it in `generate` was touched. `_grow_vein` still writes
`world.blocks[cell]` for `ore`, `rich_ore`, `coal` and `iron`, and `_mineralize` still writes `rich_ore`
and `ore` directly, so the existing ore blocks, the whole current economy, and every richness assertion
and ore fixture keep their previous meaning. 3a adds a new class of deposit and converts nothing. That is
why it could land without the tutorial rewrite and without touching a single fixture.

What it bought is that "a generated world contains usable extraction sites" stopped being false by
construction. That was the blocking half, and it blocked because `sim.lode`'s only writer outside
save/load was the blow that opens a vein: lode was derived from destroying an ore block and never
generated, so the Borer and the Drift Rig cut rock with nothing behind it while every lode fixture in the
suite injected its own and stayed green.

3a also does not establish that the pay chute works. An empty world means everything downstream of it was
never exercised, so that path is untested rather than exonerated, and it may hold defects that only
become visible now there is lode to draw.

**3b is still open, and it is the dangerous half.** Everything below is 3b, and the deletions are what
make it dangerous:

- `layered_world_gen.gd`: every vein, patch, body and reward emits a lode plus host rock instead of an
  ore block. Determinism preserved (same seed, same lodes).
- `world_seeder.gd`: the starter vein, the tutorial coal, the mineshaft vein.
- `objectives.gd`: the tutorial ladder rewritten, so the `mine`, `build` and `fuel` steps describe
  clearing rock to expose a vein, working it, and covering it. Non-negotiable: shipping a tutorial that
  describes the old game is worse than shipping the old game.
- `hints.gd`, `hud.gd` minimap, `terrain_painter.gd`, `world_renderer.gd` aim.
- Sonar re-pointed at lodes through rock, so prospecting stops being decoration and becomes the way you
  find what to clear.
- Borer and Drift Rig re-sourced: they cut rock and *expose* lode, and the pay chute draws from what they
  opened.
- Deletions: `mine()`'s ore-like branch, the drill's bore-through, and `_is_ore_like`'s block role.
- Changed: `test_worldgen`, `arc_driver`, `play_agent`, `play_tests`, `check_richness`, `mock_bazaar`,
  `capture_moments`, and every remaining ore fixture.

### Phase 4: the stain, and the shot

The stain half landed ahead of phase 3.

- **The through-rock tell: code landed, perceptually unverified.** `WorldRenderer._stain()` is shared by
  the exposed face and the buried tell, with an asymmetry in the value channel: the face holds value and
  the buried cell darkens by `LODE_STAIN_BURIED_DARK`, which is 0.78. Held by `check_lode`'s
  `_the_rock_tells_on_itself`, `history/124-the-rock-tells-on-itself.png`, and `docs/LODE.md` §10.

  What is established: the stain path runs over buried lode cells and lowers their measured on-screen
  luma by 13.2% against a noise floor of about 2%. That is an instrumented pixel-difference claim about
  the renderer, and it stands.

  What is not established: that a player looking at the screen can locate a vein by it. A luma delta a
  differ can resolve is not the same quantity as a tell a person notices, and no capture has yet been
  taken under controlled HUD state. The motivating line, that after the cutover a world without the stain
  is featureless stone and nobody can tell where to dig, is the design argument for building it rather
  than a finding about the built thing.

  Gate, unmet: a diagnostic capture that sets and records the tutorial and objective state so the vein is
  unoccluded. Phase 3a shipped without it. See §5e.
- **Draining density: done.** `lode_max`, the per-vein denominator, plus the angular grain field, so a
  worked-out vein looks worked out and a fat one looks fat.
- **Open:** the spent-vein look at the host rock level (a cleared-out wall that still stains reads as a
  lie), the shot itself, and doc status updates across DRIFT and BITS.

## 5. The eval gate

Nothing lands unless its column is satisfied. `≠` marks an assertion whose *meaning* changes. Each one is
a deliberate design decision that has to be re-argued in the commit, never silently updated to match new
output.

### 5a. Existing assertions that must change

| Layer | Assertion before | New contract | Phase |
|---|---|---|---|
| `test_sim` finite-deposit | ≠ a hand-mined (now-open) cell is no vein | a hand-mined cell IS a vein you can keep working, less what the blow took. This inversion is the migration | 1 |
| `test_sim` finite-deposit | hand-mining discards the pool | the burst comes out of the pool; the remainder survives | 1 |
| `test_sim` save round-trip | solid, wall and deposits | plus `lode` and `lode_max` | 1 |
| `test_sim` `_test_machine_status`, `_test_automated_line`, `_test_descent_automation` | the drill bores a solid vein | the Head covers a lode | 2 |
| `test_stress` drill farm | ≠ finite, so the drill drains it and stops | still finite, still stops, via coverage rather than boring through | 2 |
| `test_stress` negative-deposit invariant | no negative deposit | unchanged, extended to lodes | 1 |
| `test_worldgen` rich-ore depth and tier | rich_ore **cells** carry deposits | rich **lodes** carry deposits | 3 |
| `test_worldgen` fuzz | same seed, identical `amounts` | identical `amounts` and `lodes` | 3 |
| `check_richness` | density and drought over solid ore | over lodes | 3 |
| `arc_driver` `_step_mine` | dig to an ore cell and mine it | clear the rock, then **work** the exposed lode | 3 |
| `check_drift`, `check_spoil` | pay stream from eaten ore blocks | pay from opened lode | 2 to 3 |

### 5b. New layers

- **`check_lode`**, the spec's own harness (`docs/LODE.md` §9). Its headline case is the one that
  justifies the migration: clear an N-cell room over a seeded lode with every bit in the set, and assert
  the deposit total is unchanged. Also: hand-drain and Head-drain pull from the same pool; a lode
  survives being built over; a spent lode stops drawing and stops reading as a vein; save round-trip.
- **`check_head`** (phase 2). Coverage never crosses to a cell with no lode; a spent Head says so; a Spur
  extends exactly what it claims; neither hand yield nor Head output ever moves sideways.
- **`check_stain`** (phase 4) was folded into `check_lode` as `_the_rock_tells_on_itself` rather than
  becoming a layer of its own. The contract is about one function's output, and an extra process launch
  to assert four colours is a worse trade than a case in the layer that already owns the lode's spec.

### 5c. Invariants that must not move

These are the reason to be careful, and none of them may be updated to match new output.

1. **Conservation.** `take_lode` realises latent to produced exactly as the drill does. `test_stress`'s
   conservation and `check_spoil`'s ledger must pass unchanged.
2. **Determinism.** Same seed, same world, same lodes, same amounts.
3. **The on-hook rule.** Extraction may be lateral; logistics stays gravity-vertical.
4. **Save round-trip** (`check_saveload`), including old saves loading, since an additive read gives them
   an empty lode layer.
5. **Frametime** (`check_frametime`, a 1000/120 ms budget). A per-cell fleck field over a new dictionary
   is the obvious place to regress. Measure it rather than assuming.
6. **The opening still plays.** `check_loop_health`, `check_pacing`, `play_tests`. Scores must not fall.
7. **Refusal still holds.** `check_refusal` green, with its tells now covering lodes too.

### 5d. Feel evals (not assertable, still required)

- **Captures** of a stained face, a freshly-opened lode, a half-worked lode, a spent lode, and a Head
  plus Spur covering a vein. Archived to `history/` per the standing rule.
- **A blind pass.** Judged from pixels alone: can a first-time viewer tell where the ore is, whether that
  vein is worth covering, and whether that one is used up? If not, phase 4 is not done.
- **A play-test rung.** Walk in with a pick, find a stain, clear a face, cover it, leave with a line
  running, with no step explained by anything but the screen.

### 5e. Go / no-go per phase

Green harness, the changed assertions argued in the commit body, a capture proving the player-visible
change, `history/` archived, and docs updated in the same commit.

Phase 3a met four of these five. The one it did not meet is the capture. Nothing was archived to
`history/`, and that gap is not cosmetic here, because 3a has a large player-visible change: the renderer
stains buried lode off `sim.lode` without asking whether the cell is solid, so through-rock tell appeared
across every generated world the moment the generator moved.

The one diagnostic frame taken since cannot settle it. Its subject is covered by the grapple tutorial
bubble, with the objective rail across the top, and it is not tracked. A frame that could settle the
question has to set and record the tutorial and objective state so the vein is unoccluded, and has to be
a diagnostic post-tutorial frame rather than a first-impression one. Until then the honest state of "can
a player see the tell" is unverified, and phase 3b's sonar work should not assume the stain covers it in
the meantime.

What is unaffected either way: the lode plane is correct, generated, deterministic, ingested and
workable. None of that rests on the tell.

One consequence for every other measurement in the project: luma readings now have a pre-lode and a
post-lode side, and the boundary is `303d1f5`.

## 6. Risk register

| Risk | Mitigation |
|---|---|
| Half-migrated world (§1) | see the note below; the original mitigation no longer applies |
| Conservation quietly breaks | conservation asserted unchanged rather than rewritten; `take_lode` mirrors the drill's ledger exactly |
| The opening arc stalls, and the harness cannot get 4 ore | `arc_driver` plus a `work_lode` verb on `PlayAgent` land with the cutover, in the same commit |
| Tutorial describes the old game | the tutorial rewrite is in the cutover commit, listed as non-negotiable |
| Frametime regression from the fleck field | view-culled like `_draw_water` and the glint pass; `check_frametime` is a gate |
| Discovery gets flatter (`docs/LODE.md` §7) | the stain says *something is here*, never *400 iron is here*; judged by the blind pass |
| Old saves | additive read, absent becomes an empty lode layer, asserted in `check_saveload` |
| Scope creep into the Spur | the Spur shipped separately and never blocked the cutover |

The top risk's original mitigation was "the cutover is one commit that flips the generator and deletes
the old path together", and the cutover is no longer one commit. That sentence is void. Whether the risk
is still mitigated is a separate question, and today the answer is yes, but by a different property.
Phase 3a is purely additive: ore blocks and lodes are both valid simultaneously, no conversion happened,
and nothing was deleted, so a world carries both models rather than being caught between them, exactly as
it did after phase 1.

What that costs is precision about when the risk returns. It returns the instant 3b starts deleting,
because the deletions are what make a world unable to hold both models, and 3b no longer has "it all
lands together" protecting it. Whoever picks up 3b inherits a real half-migration risk that this table
previously claimed was structurally impossible, and the mitigation it needs is its own.

## 7. Rollback

- **Whole migration:** `git reset --hard pre-lode`, tag pushed.
- **One phase:** each phase is one commit, so `git revert <sha>`.
- **Abort triggers.** Stop and reassess rather than patching forward if conservation cannot be kept
  without rewriting the invariant; if the opening arc cannot be driven to first automation; if frametime
  falls below its budget and the fleck field is the cause; or if a blind pass cannot locate ore after
  phase 4.

## 8. Calls made, all reversible

1. **Coal moves too.** Same rule, no exception. It keeps the drill-to-coal demand web intact and avoids a
   second ore model for one material.
2. **Working a lode obeys the drive and tier gate.** The tool ladder is the tool ladder, which also means
   the existing crossed cursor and skid answer lodes with no new code.
3. **Bits do not gate lode work.** Bits shape holes, and working a vein cuts no hole. A Wedge never
   refuses ore.
4. **No solid ore survives** (`docs/LODE.md` §8). A "massive ore" exception would rebuild the muddle
   being deleted.
5. **No save version bump.** Additive read, matching the `fill` and `spoil` precedent.

Call 4 is the one worth the most scrutiny. It is the only one that is hard to walk back after the
cutover, and it is the difference between "ore is in the wall" and "ore is usually in the wall".
