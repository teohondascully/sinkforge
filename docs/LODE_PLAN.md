# THE LODE MIGRATION — plan, blast radius, and the eval gate

> **Companion to `docs/LODE.md`** (the design). This document is the *how*: what breaks, in what order it
> gets fixed, what has to be true before each phase is allowed to land, and how to get back.
>
> **Before-marker: tag `pre-lode` = `27fe6a3`** (pushed). The harness is **55/55 green** at that commit and
> the working tree was clean. `git reset --hard pre-lode` returns the game to the pre-migration model in one
> command. A slice-1 code sketch written before this plan is preserved in `git stash` ("wip: lode slice-1
> sketch") and is **superseded** — it is a reference, not a starting point.

## 1. Why this needs a plan and not a strike

Ore is the oldest system in the game and the most-depended-upon. It is read by the sim, the generator, the
renderer, the HUD, the sonar, the tutorial ladder, the hint table, four machines, the scripted play-harness
and **15 of the 55 harness layers**. Changing what an ore cell *is* changes the meaning of assertions written
across nine months of strikes — including at least one that **inverts** (`test_sim.gd:534` currently asserts
that a hand-mined ore cell is *no longer* a vein; that is precisely the behaviour being deleted).

The failure mode to design against is not "a bug". It is **a half-migrated world**: two ore models coexisting
where the generator believes one and the drill believes the other, with a green harness because every layer
was updated to agree with whichever model it happened to touch. That is unbisectable and it is how this kind
of change goes wrong.

## 2. Blast radius (measured, not estimated)

| System | File(s) | What breaks |
|---|---|---|
| Ore identity | `factory_sim.gd:1134` `_is_ore_like` | the predicate that makes a *block* special stops being about blocks |
| Hand-mining | `factory_sim.gd:625-637` | the destructive path — **the whole point** |
| Drill | `factory_sim.gd:1731-1860` `drill_column_remaining`, `_run_drill` | "bore DOWN through solid ore" has no referent |
| Borer | `factory_sim.gd:1926` | same, laterally |
| Drift Rig | `factory_sim.gd:2025-2055` | its pay stream comes from eating ore blocks |
| Generator | `layered_world_gen.gd:654-664, 740, 814, 845-891, 910, 1006` | every vein, coal patch, iron body and aquifer reward is authored as `blocks` + `amounts` |
| World data | `world_data.gd:23` | needs a `lodes` grid alongside `blocks`/`walls`/`amounts` |
| Spawn fixtures | `world_seeder.gd:25-45, 83` | starter vein, tutorial coal, mineshaft vein — the entire opening |
| Sonar | `main.gd:1797-1815` | `if not sim.is_solid(cell)` — prospecting would find nothing |
| Aim / hover | `main.gd:1572`, `hover_info.gd:23`, `world_renderer.gd:1334` | "a rich vein reads as a THING" is keyed on solid |
| Glints | `world_renderer.gd:793, 886-925` | iterates `deposits` and requires `is_solid` |
| Terrain paint | `terrain_painter.gd:117` | richness-tinted rock |
| Minimap | `hud.gd:1025` | ore blocks colour the map |
| **Tutorial** | `objectives.gd:38, 44, 45` | *"hold LMB on the metal-flecked rock"*, *"drop the Drill just ABOVE the ore vein"* — **false the instant worldgen flips** |
| Hints | `hints.gd:43, 51, 56` | scanner / rich ore / borer copy |
| Save | `save_game.gd:37, 83` | new layer to persist |
| Play harness | `arc_driver.gd:73-83, 126-140`, `play_agent.gd` | step 1 *is* "hand-dig 4 ore"; the agent has no verb for working a lode |

**Harness layers touching ore/drill, by reference count:** `test_sim` (273), `play_tests` (77),
`test_stress` (66), `arc_driver` (25), `test_power_water` (19), `test_worldgen` (17), `check_saveload` (10),
`check_bits` (10), `check_drift` (9), `check_spoil` (8), `capture_moments` (6), `mock_bazaar` (4),
`check_underground` / `check_pack_layout` / `check_controls` (1 each).

## 3. Strategy: build it fully, then cut over once

Three candidate shapes were considered.

- **Big bang** — flip everything in one commit. Rejected: the harness is red for a long stretch, which is
  exactly when our working rule ("if RED, revert, don't patch") stops being usable, and nothing is bisectable.
- **Permanent bridge** — keep solid ore *and* lodes forever. Rejected: two ore models is the failure mode in
  §1 wearing a friendly face.
- **Build → cut over → clean up.** ✅ **Chosen.**

The insight that makes it safe: **the entire lode mechanic — layer, verbs, rendering, drill coverage, tells —
can be built, played and asserted while ore is still solid**, because hand-mining an ore block is a natural
way to *create* a lode. So phases 1 and 2 are purely additive, the game stays playable and the harness stays
green throughout. The cutover (phase 3) then reduces to a **data change** — the generator emits lodes instead
of ore blocks — plus deleting a path that by then has no users. Small, reviewable, revertable on its own.

## 4. Phases

Each phase is one commit (or a tight run), lands green, and is independently revertable.

### Phase 1 — the lode exists, and the trap is gone ✅ SHIPPED as STRIKE 38
*Player-visible change: mining ore stops destroying the vein. Nothing is removed.*

> Landed green at **56/56** with all seven §5c invariants passing unchanged. `check_lode` (39 assertions)
> is the new layer; `test_sim`'s flagged inversion and the save round-trip were the two existing assertions
> changed, both argued in place. One thing the plan did not anticipate: the lode's *rendering* wanted to be
> part of the wall bake rather than an overlay — see `docs/LODE.md`'s recorded deviations. One assertion in
> `check_lode` was caught passing **vacuously** (the Wedge never landed a blow, so "nothing was destroyed"
> meant nothing) and the fixture was rebuilt as an ore body so every bit in the set really bites.

- `factory_sim.gd`: `lode` dict (cell → ore id); `lode_at` / `lode_workable` / `lode_fraction` / `take_lode`;
  `mine()` takes the burst **out of** the deposit and leaves the remainder as a lode; `ore_deposit_at` reads
  both; `load_world` clears it.
- `save_game.gd`: persist + additive restore (matches the `fill`/`spoil` precedent — no version bump).
- `main.gd`: `_lode_workable`, the hold-to-work cycle inside `_update_mining` (a short repeating cycle that
  yields and cracks nothing), `try_work_lode` verb, `_refuses`/`_drive_bites` extended so **#S37's crossed
  cursor and skid answer an over-tier lode for free**.
- `world_renderer.gd`: `_draw_lode` — a persistent fleck field on the back wall, **thinned by
  `lode_fraction`** so a worked-out vein looks worked out; glint pass extended to lodes.
- `hover_info.gd`: an exposed lode reads as a vein with what is left in it.
- **New layer `check_lode`.** **Changed:** `test_sim` finite-deposit section (§5).

### Phase 2a — the Drill Head ✅ SHIPPED as STRIKE 39
*Player-visible change: drills can be placed ON an exposed lode. The old placement still works.*

> Split out from phase 2 deliberately: the Head is a complete, playable, assertable unit, and the Spur is a
> separate design commitment (a new machine, a research rung, a coverage model). Bisectable beats bundled on
> the one migration where a bad commit is expensive. Landed green at **57/57** with `check_head` (23
> assertions) passing on its first run and — the real result — **not one existing drill assertion needed to
> change**, which is the phase-1/2 additive claim in §3 actually holding rather than being asserted.

- Drill accepts a cell whose backing is a lode; drains it in place; still pours down its own column
  (**on-hook rule asserted, not assumed**). Old bore-down-through-solid path untouched.
- `drill_preview` over a lode shows ONE cell, not a column — the placement legibility win, taken by deleting
  geometry rather than drawing more of it. `drill_column_remaining` reports the face it stands on.
- `spent` status with its own words and a cool (not alarmed) lamp, distinct from `no_input`. Deciding between
  them needs the Head to remember it has pulled something, so a *misplaced* drill still reads as starved.
- **A Head is never `blocked`.** With no shaft under it the ore piles at its feet, like every other item in
  this game when it lands; refusing to run to prevent a pile would invent a chore (`docs/DRIFT.md` §5).

### Phase 2b — the Spur
*Player-visible change: one Head can work a whole vein.*

- `spur.tres`: a passive coverage extender placed adjacent to a Head or another Spur, adding its own cell's
  lode to that Head's draw. Passive on purpose — no power question, and the Head keeps owning the fuel.
- A new research rung: the Spur must NOT unlock with the drill, or you never feel that a Head covers one cell
  (demand-pull). Coverage set, drain order, placement preview, `check_head` extensions.
- **Changed:** `test_sim` drill cases, `test_stress` finite-deposit/drill cases, `check_drift`, `check_spoil`.

### Phase 3 — THE CUTOVER (the dangerous one)
*One commit. Ore is born in the wall; the solid-ore path is deleted in the same breath.*

- `world_data.gd`: `lodes` grid. `layered_world_gen.gd`: every vein/patch/body/reward emits a **lode + host
  rock** instead of an ore block. Determinism preserved (same seed → same lodes).
- `world_seeder.gd`: starter vein, tutorial coal, mineshaft vein.
- **`objectives.gd`: the tutorial ladder rewritten** — the `mine`, `build` and `fuel` steps describe clearing
  rock to expose a vein, working it, and covering it. Non-negotiable: shipping a tutorial that describes the
  old game is worse than shipping the old game.
- `hints.gd`, `hud.gd` minimap, `terrain_painter.gd`, `world_renderer.gd:1334`.
- **Sonar re-pointed at lodes through rock** — prospecting stops being decoration and becomes the way you
  find what to clear.
- Borer + Drift Rig re-sourced: they cut rock and *expose* lode; the pay chute draws from what they opened.
- Delete: `mine()`'s ore-like branch, the drill's bore-through, `_is_ore_like`'s block role.
- **Changed:** `test_worldgen`, `arc_driver`, `play_agent`, `play_tests`, `check_richness`, `mock_bazaar`,
  `capture_moments`, and every remaining ore fixture.

### Phase 4 — the stain, and the shot
- The through-rock tell, measured against the `check_tells` honesty contract (climbs near a lode, ~0 in dead
  rock). Spent-vein look. Capture moments + `history/` archive. Doc status updates across LODE/DRIFT/BITS.

## 5. The eval gate

Nothing lands unless its column is satisfied. `≠` marks an assertion whose *meaning* changes — each one is a
deliberate design decision that must be re-argued in the commit, never silently updated to match new output.

### 5a. Existing assertions that MUST change

| Layer | Assertion today | New contract | Phase |
|---|---|---|---|
| `test_sim:534` | ≠ "a hand-mined (now-open) cell is **no vein**" | "a hand-mined cell **IS** a vein you can keep working" — the inversion that *is* the migration | 1 |
| `test_sim:518-542` | hand-mining discards the pool | the burst comes **out of** the pool; the remainder survives | 1 |
| `test_sim:1511` | save round-trips solid+wall+deposits | …+ `lode` | 1 |
| `test_sim:1029, 1165, 1712` | drill bores a solid vein | Head covers a lode | 2 |
| `test_stress:303-322` | ≠ "finite — the drill drains it and STOPS" | still finite, still stops — via coverage, not via boring through | 2 |
| `test_stress:514` | no negative deposit | unchanged, **extended to lodes** | 1 |
| `test_worldgen:337-353` | rich_ore **cells** carry deposits | rich **lodes** carry deposits | 3 |
| `test_worldgen:546` | same seed → identical `amounts` | …identical `amounts` **and** `lodes` | 3 |
| `check_richness` | density/drought over solid ore | over lodes | 3 |
| `arc_driver:73-83` | dig to an ore cell, mine it | clear the rock, **work** the exposed lode | 3 |
| `check_drift` / `check_spoil` | pay stream from eaten ore blocks | pay from opened lode | 2→3 |

### 5b. New layers

- **`check_lode`** — the spec's own harness (`docs/LODE.md` §9). Its headline case is the one that justifies
  the whole migration: **clear an N-cell room over a seeded lode with every bit in the set, and assert the
  deposit total is unchanged.** Plus: hand-drain and Head-drain pull from the same pool; a lode survives
  being built over; a spent lode stops drawing and stops reading as a vein; save round-trip.
- **`check_head`** (phase 2) — coverage never crosses to a cell with no lode; a spent Head says so; a Spur
  extends exactly what it claims; neither hand yield nor Head output ever moves sideways.
- **`check_stain`** (phase 4) — the `check_tells` honesty contract, applied to the through-rock tell.

### 5c. Invariants that must NOT move (the regression guard)

These are the reason to be careful, and none of them is allowed to be "updated to match":

1. **Conservation.** `take_lode` realises latent→produced exactly as the drill does. `test_stress`'s
   conservation and `check_spoil`'s ledger must pass **unchanged**.
2. **Determinism.** Same seed → same world, same lodes, same amounts.
3. **The on-hook rule.** Extraction may be lateral; logistics stays gravity-vertical. Nothing here bends it.
4. **Save round-trip** (`check_saveload`), including old saves loading (additive read → empty lode layer).
5. **Frametime** (`check_frametime`, 120fps) — a per-cell fleck field over a new dictionary is the obvious
   place to regress. Measure it, don't assume it.
6. **The opening still plays.** `check_loop_health`, `check_pacing`, `play_tests` — scores must not fall.
7. **#S37 still holds.** `check_refusal` green, and its tells now cover lodes too.

### 5d. Feel evals (not assertable, still required)

- **Captures** for: a stained face, a freshly-opened lode, a half-worked lode, a spent lode, a Head+Spur
  covering a vein. Archived to `history/` per the standing rule.
- **The blind-vision pass** — a fresh zero-context agent judges from pixels alone: *can it tell where the ore
  is, whether that vein is worth covering, and whether that one is used up?* If it cannot, phase 4 is not done.
- **A play-test rung**: walk in with a pick, find a stain, clear a face, cover it, leave with a line running —
  no step explained by anything but the screen.

### 5e. Go / no-go per phase

Green harness (all 55 + new layers) · the changed assertions argued in the commit body · a capture proving the
player-visible change · `history/` archived · docs updated in the same commit.

## 6. Risk register

| Risk | Mitigation |
|---|---|
| **Half-migrated world** (§1) | phases 1–2 additive with both models valid by construction; the cutover is one commit that flips the generator and deletes the old path together |
| Conservation quietly breaks | conservation asserted **unchanged**, not rewritten; `take_lode` mirrors the drill's ledger exactly |
| The opening arc stalls (agent can't get 4 ore) | `arc_driver` + a `work_lode` agent verb land **with** the cutover, in the same commit |
| Tutorial describes the old game | tutorial rewrite is in the cutover commit, listed as non-negotiable |
| Frametime regression from the fleck field | view-culled like `_draw_water`/`_draw_ore_glints`; `check_frametime` is a gate |
| Discovery gets flatter (§7 of LODE) | the stain says *something is here*, never *400 iron is here*; judged by the blind-vision pass |
| Old saves | additive read; absent → empty lode layer; asserted in `check_saveload` |
| Scope creep into the Spur | the Spur is phase 2 and may be deferred without blocking the cutover |

## 7. Rollback

- **Whole migration:** `git reset --hard pre-lode` (tag pushed).
- **One phase:** each phase is one commit; `git revert <sha>`.
- **Abort triggers** — stop and reassess rather than patch forward if: conservation cannot be kept without
  rewriting the invariant; the opening arc cannot be driven to first automation; frametime falls below the
  120fps gate and the fleck field is the cause; or the blind-vision pass cannot locate ore after phase 4.

## 8. Calls made (reversible, flagged for your eyes)

1. **Coal moves too.** Same rule, no exception — it keeps the drill→coal demand web intact and avoids a
   second ore model for one material.
2. **Working a lode obeys the drive/tier gate.** The tool ladder is the tool ladder; this also means #S37's
   crossed cursor and skid answer lodes with no new code.
3. **Bits do not gate lode work.** Bits shape *holes*; working a vein cuts no hole. A Wedge never refuses ore.
4. **No solid ore survives** (LODE §8). A "massive ore" exception would rebuild the muddle being deleted.
5. **No save version bump.** Additive read, matching the `fill`/`spoil` precedent.

The one I would most want you to look at is **#4** — it is the only one that is hard to walk back after the
cutover, and it is the difference between "ore is in the wall" and "ore is *usually* in the wall".
