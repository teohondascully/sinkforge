# LEGACY_GAP — the ranked backlog

**Generated 2026-08-30 per `docs/MASTER_PLAN_AUG30.md` §3.** The complete capability-level gap between
`legacy/` (a finished game, 28,522 lines of game code in 55 files) and the current build (4,574 lines in
32 files). This is a *living worklist*: pull the highest-ranked open item each cycle, and mark rows as
they land.

## What this is, and what the migration map is not

`docs/LEGACY_MIGRATION_MAP_2026-08-29.md` is **file-level**: 265 rows, each a verdict on a legacy file
(LIFT / MERGE / REBUILD / DEAD / SKIP). It answers "does this file come over". It cannot answer "what is
the next thing to build", because a single file holds dozens of independent capabilities at wildly
different ranks — `world_renderer.gd` alone carries 74, ranging from the veil (the single largest visual
gap in the project) to a bird that crosses the sky on a 47-second cycle.

This file is **capability-level** and ranked. It was produced by reading all 28,522 lines of legacy game
code in nine parallel passes, each closing its findings against the current tree rather than against the
map's verdicts. Two of the map's own claims did not survive that (see *Corrections*).

**Read depth: every legacy game file was read in full or near-full.** The map's §12 named two files never
read by any audit — `main.gd` (3,003) and `world_renderer.gd` (3,656), 6,659 lines between them, with
every `view`/`shell` estimate inheriting the gap. **Both are now read in full**, and closing the first of
them immediately corrected a wrong attribution the map had been propagating.

## The honest fraction

| | legacy | current | |
|---|---|---|---|
| Game code | 28,522 lines / 55 files | 4,574 lines / 32 files | **16.0%** |
| Instrument | ~51,800 lines (its own 108-layer harness) | ~15,900 lines, 42 suites, 30 declared gates | the current build wins here outright |

16% by line count overstates the play gap and understates the substrate. What actually exists today: a
deterministic fixed-point body with an acceptance suite, a two-process replay check, a goalless fuzzer, a
cursor-aim mining verb with a hollow tell, a shaft generator, an L2 interface, a painter coordinator with
one painter on it, and a palette. What does not exist: **any HUD, any audio beyond one unwired music bed,
any machine, any item, any inventory, any fluid, any light, any sprite, any grapple, and any goal-seeking
agent.** The body is a red rectangle.

---

## Baseline, measured 2026-08-30 at `9ed8417`

Captured before any of this run's work, so later claims have something to be measured against.

- `tools/capture_moments.sh` at seed 20260826, site `reveal_test_dense`: surface 192 / delve 178 / aim 149
  / horizon 168 distinct colours.
- `test_shaft_replay_determinism` **74.4 s**, `test_replay_determinism` 9.5 s, `test_body_fuzz_fast` 5.8 s.
  This confirms `MASTER_PLAN_AUG30.md` §6's number exactly, and `TileGrid.state_signature()` is the cause:
  it re-serialises every occupied cell into a `String` per checkpoint.
- All structural gates PASS. `check_claim_references` is VOID by design.
- One deliberately-untracked file: `tests/body/recordings/play_2026-08-31T05-14-20.log`, the director's
  own 676-tick recorded session. Not committed, because committing it makes it binding in CI under P002.

---

## Corrections to the migration map

Both were found by reading, and both would have sent a porting ticket to the wrong file.

**1. The lighting is not in `main.gd`.** The map says `main.gd` owns the head-lamp pool and darkness veil
(and `light_layer.gd`'s own header says the same, which is where the map got it). A full-text search of
`main.gd` for `lamp|light|dark|veil|glow` returns 40 hits and **every one is a comment, a z-index note, or
the 5-entry `LAMP_TINTS` palette**, plus one assignment `_renderer.lamp_color = ...`. `main.gd` owns the
lamp's *colour choice* and nothing else about light. The real lighting is `world_renderer.gd`:
`_paint_darkness:2769`, `_bake_veil_base:2915`, `_bake_openness:3002`, `_update_veil:3126`,
`_veil_cut:3221`, `_skylight_alpha:3263`, `_paint_lights:3458`.

**2. `hud.gd` reads 15 sim accessors, not 16.** The 16th, `sim.machine_problems()`, appears only inside a
`##` doc comment at `hud.gd:85`; the alerts array is pushed in by `MainView` and the HUD never calls it.
The count of *names* is 16 and the count of *call sites* is 15. More usefully: those 15 sites live in
exactly **five** surfaces, and the other eighteen `_draw_*` methods read the sim zero times — so the whole
world-furniture HUD set is buildable with **no new sim accessors at all**.

---

## The four prerequisites that gate everything else

Ranked before any feature, because each one blocks a large fraction of the backlog and each is small.

**Three of the four are now closed** (D0277, D0279/D0293, D0308) and this section had recorded none of
it — the closures were made by the sessions working those lanes, and updating the prerequisite list
belongs to no lane. **PRE-2, the `Fx` vector layer, is the only one still open**, and it is the one that
gates the grapple. Verified in the tree 2026-09-01: `core/fixed_point.gd` still has no `normalize`,
`dot` or `limit_length`.

### PRE-1 · CLOSED 2026-08-31 by D0277 · `Frame.anim_time` is a `const 0.0` — 28+ rows are inert until it moves

**CLOSED.** `WorldView.anim_time()` returns `_anim_ticks * SECONDS_PER_TICK`, with `reset_anim_clock()` preserving Q5's original guarantee for captures. Option (1) of `docs/NEEDS_DIRECTOR.md` P025, the cosmetic tick counter.

`view/world_view.gd:28`. Q5 was ruled "pin it", correctly, when nothing animated. Every animated
capability in the backlog — every working-machine glyph, the construction overlay, the status pulse, the
need bubble, rope sway, payout rise, godrays, glint flares, the lamp flicker, surface life — ports and
then sits frozen. This is ~3 lines and one director ruling to re-open. **It should land before any
animated port.**

### PRE-2 · `Fx` has no vector layer — the grapple cannot be written without it
`core/fixed_point.gd` has `mul/div/lerp/isqrt/length/length_sq` and no `normalize`, `dot`, or
`limit_length`. The grapple's entire constraint is `d.normalized()` and `vel.dot(n)`. ~40 lines plus
tests. Both roundings fail toward *less energy*, which is the safe direction for a swing.
**One trap found and worth writing down now:** do not store `PUMP_CLAMP 1.05` and its reciprocal as two
Fx literals — `1.05*65536 → 68812` and `1/1.05*65536 → 62415` are not inverses, and an alternating
reel/pay sequence biases tangential speed down by ~1.6e-5 per pair. Store the rational `21/20` and use
integer mul/div, exactly as `AIR_CONTROL_NUM/DEN` and `Mining.REACH_NUM/DEN` already do.

### PRE-3 · CLOSED 2026-08-31 by D0279/D0293 · The mining sim computes three things it throws away at L2

**CLOSED.** `observe()` reads `_mining`; the `Observation` carries the cracks, the break, the hollow reading as an **int**, the breach, and the swing as an **edge** with a direction and a phase. All three of the wanted extras landed with it.

`sim/mining/mining.gd` holds `charging_cell`, `banked(cell)`, `cracked_cells()`, `broke_this_tick`,
`broke_material`, `broke_cells`, `breach_this_tick` — and **`Interface.observe()` reads `_grid` and
`_body` and never touches `_mining`.** Every mining feedback capability in the backlog (cracks, crumble,
the hollow ring, the breach payoff, the draught, payout ticks) is blocked on the same three-line change.
Two more fields are wanted while that door is open: the hollow reading as an **int** rather than the
boolean `breach_this_tick` (both audio laws are functions of the magnitude), and a **swing edge**, because
legacy's ring fires per *blow* and the repetition is what makes the tell rise rather than flip.

### PRE-4 · CLOSED 2026-09-01 by D0308 · `world_seed` is not on the `Observation`

**CLOSED, and its first caller shipped with it.** `Observation.world_seed` is one `int` copied from `TileGrid.seed`, and `view/visuals/seam_painter.gd` is the first thing in this repository ever to call `Seams.at` — the grain reveal at the worked cell, ported from `world_renderer.gd:2262-2344`.

`core/seams.gd` is fully ported, integer-exact over all 196,608 inputs, and — by its own header —
**called by nothing** except `sky_painter`'s starfield hash. `Seams.at(cell, world_seed)` needs the seed;
`TileGrid.seed` exists and `Observation` does not carry it. One `int` field unblocks the seam-grain
reveal, the calve verb, and the Wedge mechanic.

---

## TIER 0 — the generator defects

**WG-1 … WG-4 below outrank everything in Tier 1.** WG-1/3 are CLOSED (D0254, D0258). **WG-2's closure is now in question** — its assertion is `shelf_frac > 0.0` against a quantity measured at 0/1/6/15/17 cells in 46,080, which is a noise floor, and the sentence declaring it closed rested on ONE carved cell (D0307, `docs/NEEDS_DIRECTOR.md` P028). **WG-4 is fully converted** (D0305, D0307): thirteen constants with per-site factors, ore bodies 477 → 42 and median size 32 → 550 cells, and `cave.frequency 0.11 → 0.0656` taking median cave pocket 7 → 15. The metre-correct `0.0275` would take it to **121** and is blocked only by that same WG-2 assertion; items 10/15/16/17-21 are held with the plan's own arguments. **Frequency is NOT the missing void** — void fraction is flat (0.0822–0.0871) across a 4× frequency sweep, excluding `docs/MASTER_PLAN_AUG30.md`'s stated most-likely explanation for P021. They are not ports; they are the current build being
measurably wrong. Three of the four are single-digit line counts, and until they are fixed every world
this build generates is one of 65,536, a third of it is an impermeable wall, and its caves are a quarter
of their authored size. Fix them **before** any visual port, because every visual judgement made against
the current terrain is a judgement about a broken world — and fix them **before** the `Fx` conversion
(W-56), because converting to fixed point changes generated terrain for every seed and doing it first
means paying the reseeding cost twice.

## TIER 1 — do these next

Ranked by (player-visible impact) × (portability), with every blocker named. Each row's mechanism is at
the legacy address given; the addresses are the durable artifact of this pass.

| # | Capability | Legacy address | Why it is first | Blocked on | Est. |
|---|---|---|---|---|---|
| **1** | **The miner sprite** | `player.gd:664-793`, `legacy/assets/sprites/*.png`, `legacy/tools/bake_miner.gd` | The body is a red rectangle. This is the single most player-visible gap in the project, and it is **far cheaper than anyone thought** — see below. | nothing | 120 | **LANDED (D0268/D0269); the discovery glint on it, D0300.**
| **2** | **The veil: mass occlusion + key light** | `world_renderer.gd:3002-3051 _bake_openness` | ~50 lines, four linear passes over a flat float array, no engine types. It is what makes carved space read AS space: measured 0.182 vs 0.052 luma against a row-gradient's 0.148 vs 0.127 — a 3.5x separation where the naive version gives 1.2x. | ~~window-vs-world scope decision~~ **NOT A DECISION — a measurement, and the answer is 9 cells** (D0302). The blur is separable with a bounded reach, so a drawn cell depends on the observation `REACH + 1` out; `WorldView.WINDOW_MARGIN_CELLS` went 3 → 9. | **LANDED 2026-09-01 (D0302), lamp D0306** |
| **3** | **The wall plane, drawn** | `world_renderer.gd:2194-2260 _draw_background`, `2685-2766 _wall_*` | `Interface.observe()` already ships `walls`/`wall_legend`, `test_interface.gd` asserts it, and **zero renderers read it**. The dug space in every capture is a flat fill. Recess AO is 4 neighbour lookups: `WALL_AO_UNDER 0.62`, `SIDE 0.34`, `ABOVE 0.16`. | a terrain painter on the coordinator | 65 | **LANDED (D0286); the mineral mark in that plane, D0299.**
| **4** | **Terrain painter onto `WorldView`** | `terrain_painter.gd` (438) | `reveal_scene._draw` draws one `draw_rect` per cell; `WorldView` carries exactly one painter (sky) and only under `--sky`. Moving terrain onto the coordinator is the structural unlock for every painter below it. | nothing | 90 | | **LANDED (D0276): `tests/body/reveal_view_setup.gd` builds the REAL coordinator and every painter since — wall, veil, glint, seam — hangs off it.**
| **5** | **Mine cracks + crumble** | `world_renderer.gd:944-968`, `2471-2502` | The sim side is *already computed and discarded*. Cracks are `2 + int(frac*5)` deterministic elbowed fractures per cell; crumble is four quadrant chunks over `CRUMBLE_DUR 0.24`. Mining currently has no feedback at all. | PRE-1, PRE-3 | 55 | **LANDED (D0275 cracks, D0289 crumble).**
| **6** | **The hollow ring + breach + draught** | `main.gd:1600-1609`, `1671-1678`; `sfx.gd:732-764` | `sim/mining/hollow_tell.gd` is written, tested, correct, and **`HollowTell.RING` is referenced by nothing.** `particles.gd::draught` is lifted and **mis-wired** (fires on breach after the break, direction hardcoded down, amount hardcoded 6, where legacy fires it during the charge at the near face along the true swing direction). `Mining.swing_dir()` is public *specifically* for this and nothing calls it. | PRE-3 | 45 | **LANDED (D0293/D0296).**
| **7** | **`UiTheme` + `PageSurface`** | `ui_theme.gd` (236), `page_surface.gd` (81) | 16 colour tokens, each carrying a measured WCAG ratio and a rejected alternative. This is a design asset a rewrite cannot recover by trying harder, and it is the whole of "the menus read 2026". One dependency, both LIFT. | a `CanvasLayer` host | 325 |
| **8** | **Depth readout + band banner** | `hud.gd:842-863`, `252-323`, `872-985` | The data is *entirely* present: `data/bands/*.yaml` has all 8 bands with `display_name`/`from_m`/`color`, `MaterialLook.band_at()` returns the record, `depth_m()` is the conversion, `Observation.cell.y` is the row. Only the chip is missing. The whole game is descent and nothing on screen says how deep you are. | H-01 (a HUD host) | 135 | **LANDED (D0271 depth chip, D0288 arrival plate).**
| **9** | **`FALL_START` + fall stagger + landing telemetry** | `player.gd:411-412`, `55-71`, `119-120` | A fall is currently *free*: ride terminal velocity into rock and sprint off the impact tick, so a forty-row hole is a strictly better staircase. Stagger is priced on distance (`> CELL*9`), not impact speed, because impact speed saturates. | nothing | 45 |
| **10** | **The stride** | `player.gd:49-53, 630-642` | One flat top speed today. `RUN_SPEED` is tuned for mining and is the wrong speed for crossing a world. `DELAY 0.9s`, `RAMP 1.2s`, `GAIN 0.55` (150→232 px/s), and a hard landing costs half of it. | nothing | 35 |
| **11** | **Camera: follow, lead, pixel-snap, shake** | `main.gd:310-333`, `683-706`, `966-969`, `2355-2358` | `reveal_scene` hard-assigns the camera to the body every tick — no smoothing, no lead, no snap, no shake, no limits. This is the single largest concentrated feel gap outside the resolver. Smooth the *follow*, snap the *render*: `(world_pos * zoom).round() / zoom`. | nothing | 90 | **follow/lead/pixel-snap LANDED (D0273); shake parks with its trigger.**
| **12** | **The grapple** | `grapple.gd` (389) | The traversal identity (memory: *grapple-centred movement*). ZERO dead references, `RefCounted`, zero engine API, one dependency (`is_solid`). The constraint is four lines and unconditionally stable. **But see PRE-2 and the resolver note.** | PRE-2, **and P-28 is RESOLVER-PARKED** | 350 |

### Why the sprite is cheaper than the map assumed

`legacy/assets/sprites/` holds 16 unique 32x48 RGBA PNGs — but they are **not hand-painted**.
`legacy/tools/bake_miner.gd` (566 lines) composes all 15 state frames from ASCII-art string tables
(`BASE` / `LEGS` / `ARMS` / `GEAR`) against a 19-entry named palette, and asserts strict 0-or-255 alpha
so the rim halo works. **Q1's "adapt the art to 16px" is therefore a two-constant text edit and a re-run,
not a repainting job.** `W=32, H=48` → `H: 48 → 56` (the collider went 34→40, so 48px on a 40px body reads
~15% squat and leaves the top 6px empty); do not resample, 1.167x is non-integer on 1px-outlined pixel art.

A stopgap worth taking on day one: blit the existing 32x48 files at 1:1 with feet on the AABB bottom,
exactly as legacy does. It reads slightly squat and is enormously better than a red rectangle.

There are **no machine, item, or tile sprites in legacy at all** — the entire machine and item vocabulary
is procedural. That is why the visuals batch ports so cleanly and why there is no art backlog behind it.

---

## The lanes, ranked

Each lane's rows are in the per-lane detail below. Counts are capabilities, not lines.

| Lane | Rows | Live / dead | State | The one thing that matters most |
|---|---|---|---|---|
| **A** · `world_renderer` — the coordinator, veil, marks, ore | 74 | 58 live, 16 dead | ABSENT | `_bake_openness` (T1 #2) |
| **M** · `main.gd` — camera, verbs, mining shell, boot | 66 | 47 live, 19 dead | mostly ABSENT | the camera block, and the aim snap |
| **H** · HUD / UI | 65 | 44 live, 21 dead | **wholly ABSENT** | `UiTheme` (T1 #7) |
| **V** · visuals, machines, entities | 72 | 60 live, 12 dead | ABSENT except particles/art | the miner sprite (T1 #1) |
| **E** · sim systems, machines, economy | 100 | 71 live, 29 dead | ABSENT | `water_flow.gd`, a near-direct integer port |
| **S** · audio | 53 | 45 live, 8 dead | one unwired music bed | the hollow ring (T1 #6) |
| **P** · movement, feel, harness | 64 | 52 live, 12 report-only | **the strongest current area** | the grapple, and the verb audit |
| **T** · terrain / water / sky render, shaders | 95 | 88 live, 7 dead | flat rects | the veil's coloured cut (`_veil_cut`) |
| **W** · world generation | 78 | 62 live, 16 dead/drop | bare shaft, **and measurably broken** | the four generator defects below |

**Total: ~667 capabilities across all nine lanes**, of which ~527 are live (not dead by GDD §9) and
currently ABSENT or PARTIAL.

---

## What is dead, consolidated

Every lane independently converged on the same set, which is a good sign for the GDD §9 list. Nothing
below comes over, in code **or as a data field**:

- **The Bazaar**, as shop and as physical structure — 8 files, ~2,400 lines, plus `hud.gd`'s entire
  delegation surface (~200 lines that delete outright).
- **The research tree** — `research_rules.gd` and every importer. Provably safe to excise: not one of its
  16 importers is on the lift side.
- **The one-time `craft_cost` purchase model** — and this is the dangerous one, because it is *data*.
  21 of 22 machine `.tres` records carry `craft_cost`/`craft_count`. `data/materials/SCHEMA.yaml` already
  documents the refusal and says out loud that "the validator does not currently reject unknown fields, so
  this is documentation, not enforcement." **Close that gate before the first machine record is converted.**
- **`save_game.gd`'s `"research"` key** — at three sites, one of them inside `REQUIRED_KEYS`. A save schema
  that *requires* the research dictionary re-imports the dead economy through the back door regardless of
  what the sim does with it.
- **The Descent Engine** and the sealrock gate. Note the collision: `_note_breach` (the hollow-tell breach,
  alive and half-ported) and the Descent Engine breach are **two different things sharing a word in one
  file**. Do not let a grep conflate them.
- **Horizontal boring** — the Borer and the Drift Rig. Two ideas worth salvaging separately: per-stream
  jamming with its own status, and `_flow_drift`'s class-routing override.
- **Electricity as an early tier** — but GDD §9 warns that removing power without deciding what replaces it
  "silently freezes every upward machine at unpowered throughput with no error… the worst failure class
  this project has." Q3 defers it; it is not a deletion.
- **Terminal products** — `plate` and `gear` are consumed by nothing except `craft_cost`. The machines
  survive the redesign; their outputs' only consumer does not.
- **The tool-tier ladder as purchased** — `MiningRules.can_mine`, `BitRules` in all forms. But note
  `_calve` is only *partly* dead: its cap comes from `BitRules`, and `core/seams.gd` is fully ported and
  integer-exact, so the grain mechanic survives with a fixed cap.

**One edge must be cut by hand:** `flora.gd:43` calls `sim.invalidate_bazaars()` — the only line in the
four FULL-port sim files that touches dead code. Its comment ("A TREE IS MADE OF WOOD, AND SO IS A
BAZAAR") is the only thing in that file that will not survive.

**Undecided, needing a ruling rather than a default** (GDD §9's own list): the **Splitter** ("two carved
chutes are a splitter… that may be right, but it must be a stated decision, not a silent capability
loss"), the **Ore Vent** (an infinite free source, which fights R2), and **power gating**.

---

## THE WORLD GENERATOR IS MEASURABLY BROKEN — four defects, all quiet greens

This is the most serious finding of the pass, and none of it is a porting gap: it is the current build
being wrong in ways nothing reports. Every number below was produced by reimplementing
`sim/terrain_gen/value_noise.gd`'s exact hash and interpolation and `ShaftGenerator._carve_caves`'s exact
loop and running them over the real shipped config. **These outrank everything in Tier 1.**

**WG-1 · Only 65,536 distinct worlds exist.** `value_noise.gd:50` masks the seed: `(seed & 0xFFFF) *
2246822519`. *Measured:* seeds `1337`, `1337 + 2^16` and `1337 + 2^20` produce **bit-identical** carve
sets. `SplitRng` hands out full 64-bit values and the top 48 bits are discarded. ~6 lines.

**WG-2 · One third of every shaft is an impermeable wall.** Shelf bands add `shelf_resist 0.34` to the
carve threshold, giving 0.81 at the top and 0.65 at the bottom. `_carve_caves:122` multiplies every sample
by `FASTNOISELITE_SD_CALIBRATION = 0.574`, and `_corner_value` returns [-1, 1] with bilinear interpolation
preserving that range — so **the carve field is hard-bounded to ±0.574 by construction and can never
reach 0.65.** This is analytic, not statistical: there is no seed and no coordinate at which a shelf cell
carves.

*Independently re-measured for this document* (288,000 samples over 20 seeds, calling the real
`ValueNoise.sample` with the real calibration): observed range **[-0.5734, +0.5732]**. The non-shelf
thresholds (0.31 deep, 0.47 top) are clearable; the shelf thresholds are not. Legacy's `FastNoiseLite`
measured a max around 0.78, so legacy's *deep* shelf was permeable and the resistance was a **gradient**.
Here it is a barrier, and nothing says so.

*(Worth recording how this was checked: the first verification probe called `ValueNoise.sample()` without
the calibration, got ±0.999, and appeared to refute the claim. The calibration is applied by the caller,
which `value_noise.gd:25` says in its own header. The claim was right and the check was wrong — measure
what the code computes, not what the constant is named after.)*

**WG-3 · The cave field is single-octave where legacy's is five.** `layered_world_gen.gd:344-346` sets
only seed / type / frequency and leaves `fractal_type` at Godot's default `FRACTAL_FBM`, 5 octaves,
lacunarity 2.0, gain 0.5 — corroborated **twice inside legacy itself**, at `src/core/fine_terrain.gd:102`
and `scenes/fine_terrain.gd:488`, both of which explicitly set `FRACTAL_NONE` *because* "FastNoiseLite
defaults to 5-octave FBM". `ValueNoise.sample()` is single-octave. (Before porting: print
`FastNoiseLite.new().fractal_octaves` once to confirm rather than trust — it is a one-line check and
getting octaves wrong changes the entire field character.)

**WG-4 · Cell-denominated constants were never converted, and the header claims they were.**
`data/strata/shallow_clay.yaml` correctly converted the *metre*-denominated fields and left every
*cell*-denominated one verbatim from a world where one cell was one metre: `frequency 0.11`,
`min_depth_cells 6`, `band_height_cells 4`, `radius_cells 4`, `size_min 8/6/10`,
`size_depth_bonus 44/30/30`. At 0.25 m per cell **every generated feature is 4x smaller in length and 16x
smaller in area than the constant was tuned for.** The yaml's own header says "SAME ratios/behavior" —
for a per-cell rate across a cell-size change, that is precisely the one thing not preserved.
`HollowTell`'s docstring diagnoses this exact class ("not a rescale, a rewrite") and fixes it by walking
16px logic tiles; this file did not.

### What it adds up to, measured

| | measured now | legacy's own stated target |
|---|---|---|
| Carve fraction, 48x1024 shaft, 6 seeds | **3.41 – 4.34%** | "near 15% of the underground" |
| Pockets, seed 1337, shipped `freq 0.11` | **40 pockets, median 21 cells (~1.3 m²), largest 295** | room-sized caverns |
| …at the metre-corrected `freq 0.0275` | **11 pockets, median 101 cells, largest 753** | |
| Per-decile carve rate within one seed | swings **0.06% – 16.95%** | depth-driven, monotone |

**The build does not over-cave — it under-caves and fragments.** The median pocket is *smaller than the
player*, so what exists reads as ragged wall texture rather than as rooms you choose to enter. Against the
dig-your-factory identity that is the worse of the two failures, because slightly-rotten-rock-everywhere
removes the choice that opt-in pockets exist to offer. And the per-decile swing shows depth is not driving
the variation at all — at 48 cells wide against `x_stretch 2.1` and `freq 0.11`, the shaft is only ~2.5
noise periods across, so lattice luck is.

**Where legacy genuinely over-caves, and the tell.** Not in `_carve_caves`, which is defensible. It is the
seven-pass stack: noise caves + 7 big caverns + **14 tunnel worms explicitly there "to link the noise
pockets into one connected system"** + 4 rifts 34-80 rows tall + 3 sinkhole throats + drought vugs + 9
aquifers. Tunnels and rifts exist to make the world traversable *by cave*, which is the follow-the-cave
medium this design rejects. The tell is in legacy's own guard: it had to invent `WorldData.routes` and
subtract its own deliberate carves from the identity metric to stay under 25%. **A guard that needs an
exemption carved into it to pass is telling you the design and the guard disagree.** D0017 already dropped
tunnels, rifts and sinkholes for the right reason — the player's own shaft is the vertical structure now.

### The trap that hid all of it

`FASTNOISELITE_SD_CALIBRATION = 0.574` matches *standard deviation* and does so **exactly** (measured
0.2477 against a 0.2487 target). Its own comment even states the limit: "same standard deviation does not
guarantee identical skew/kurtosis… only that a fixed threshold clears at approximately the same rate."
But a threshold reads a **tail**, not a spread — and SD-matching two differently-shaped *bounded*
distributions does not match tails. The instrument was correct about the thing it measured and silent
about the thing that mattered, which is this project's house failure class arriving, once again, as a
quiet green. **Re-derive both cave thresholds and `shelf_resist` from a measured tail of the replacement
field, and pin them with a test that asserts a carve-fraction band rather than a constant.**

---

## Findings that are defects in the CURRENT build

Found while closing legacy rows against the current tree. These are not ports — they are things wrong now.

1. **The deafness switch is 3/4 non-functional.** `view/controls.gd` lifted `deaf`/`axis`/`pressed`
   verbatim, and then `play_scene.gd:138-148` and `reveal_scene.gd:210-220` poll
   `Input.is_physical_key_pressed(KEY_A/D/SPACE/E)` **directly**. Only `MINE` goes through the gate.
   `Controls.deaf = true` today silences mining and leaves walking, jumping and digging fully connected —
   precisely the failure the docstring warns about, arrived at by exactly the mechanism it names ("a list
   of things to disable would require every future polling site to know it was supposed to add itself").
   Nothing sets `deaf` and nothing tests it; legacy had `check_input_deafness.gd` asserting three
   properties.

2. **The posable pointer has zero callers.** `pose_pointer`/`release_pointer`/`pointer_posed` are ported
   byte-equivalent. Legacy has ~40 call sites and `check_grapple_reads` *asserts* `pointer_posed()` before
   reading. Here, nothing has ever posed it. The mechanism the migration map called "a working answer to
   Q2" is a mechanism with no subject.

3. **The draught particle is mis-wired.** Fires on breach *after* the break, at the break site, direction
   hardcoded `(0,1)`, amount hardcoded 6. Legacy fires it *during* the charge, at the near face, along the
   true swing direction, scaled by the reading. `Mining.swing_dir()` is public with a header saying it is
   public "because the view needs the same direction to place a draught puff on the near face."

4. **The scale convention was applied inconsistently, and both halves are defensible.** Movement constants
   ported in **pixels** (`RUN_SPEED 150`, `GRAVITY 900`, `JUMP_VELOCITY -365` identical to legacy);
   `Mining.REACH` ported in **metres** (correctly reasoning "the portable quantity is 3.2 METRES, not
   102.4 pixels"). Since legacy's cell is 32px/m and this world's is 16px/m, identical pixel constants are
   **double speed and double gravity in metres**: 4.69 → 9.38 m/s, 28.1 → 56.3 m/s². Having made both
   choices is the finding. Every absolute px/s constant in the grapple needs the director to say which
   convention it ports under; constants stated relative to `RUN_SPEED` port unchanged either way.

5. **`_speck_lift` has no prefix property.** Legacy's `_cell_speckles` is prefix-stable — taking the first
   K of the list is what makes a draining vein lose flecks one by one rather than reshuffling. The current
   re-expression ("a `count/64` fraction of cells take the nugget colour") has the same areal density and
   no prefix, so a depleting lode cannot be drawn.

6. **`TileGrid`'s dirty-check pattern to avoid.** `hud.gd`'s minimap rebuilds its cache only when
   `sim.solid.size()` changes — a count-without-membership, and two different solid sets of equal size both
   read clean. If a revision counter is added to `TileGrid` for the same purpose, make it a counter, not a
   size comparison.

7. **The two-rows finding, still live.** `hover_info.gd:63-76` measured that legacy's 34px body against a
   32px cell **always covers two rows and never one**, and 2-4 cells total. The current body against a 4px
   terrain cell reproduces the class exactly, and `Interface._apply_mine` validates a single `cell`. A
   cell-addressed verb is never really about one cell.

---

## The determinism fast-track (§6), measured

`test_shaft_replay_determinism` is **74.4 s** — confirmed by measurement, matching the plan's estimate.
The cause is `TileGrid.state_signature()` (`sim/world/tile_grid.gd:115`), which formats every occupied
cell into a `String` per checkpoint. The sim itself is a small fraction.

The plan's O(1) running-hash proposal is sound and its own caution is the important part: **the hash IS
the determinism contract**, so it must update on every mutation path (`set_material`, `set_wall`,
`excavate`, `extend_terrain_dig_extent`) or it agrees when worlds differ. Mutation-test that a forgotten
update breaks a test *before* trusting it. And note from lane E: every new plane
(`_deposits`, `_lode`, `_water`, `_fill`, `_ground`, rope/torch/sapling) must enter the signature too —
`state_signature`'s own docstring already gives the rule, using `_dig_extent` as the worked example.

---

## Per-lane detail

The full mechanism for each row lives at its legacy address. What follows is the ranked index — enough to
pull an item and know what it costs, with the address to read for the algorithm.

### Lane A · `world_renderer.gd` — 74 rows

Six extraction seams, measured, with line ranges: **S1** layer construction & bake (~520), **S2** lighting
& the veil (~980, the largest coherent block and it barely touches anything else), **S3** terrain palette
authority (~330, pure functions), **S4** ore/lode (~300), **S5** the mark vocabulary (~640), **S6** ambience
(~450). Only ~120 lines genuinely coordinate. S2 and S5 each blow the 400-line gate alone and need a
second cut, both at stated boundaries.

Highest-ranked: `_bake_openness` (mass occlusion + key light) · the veil as a system (A-11..A-21, ~430
lines, and *three* decisions elsewhere in the file exist because of it and are wrong without it) · the
mark grammar (A-44..A-47, ~150 lines of primitives whose real asset is three long comment blocks ruling
what a shape may *mean*) · `_strata` (12 lines — **landed, D0252**) · `_zone_tinted` (9 lines — **ported,
parked, P019**) · the wall plane + recess AO · the seam-grain reveal (the ambient pass deliberately does
not exist: drawing every plane rules 18% of rows on exact cell boundaries and reads as graph paper).

`Frame` is missing, ranked by rows blocked: a live clock (26 rows) · a changed-cell channel (6) ·
`world_seed` (1) · mining state (2, both high impact) · an aim cell · per-cell ore amount · world bounds ·
a `(z, blend)` argument on `add_painter` — the veil *must* be MUL, lights ADD, marks MIX above the veil,
which was measured taking **69%** of every authored mark.

### Lane M · `main.gd` — 66 rows

Fifteen extraction seams named with line ranges. The one needing care is the mining split: `_workable`,
`_mineable`, `_refuses`, `_can_reach`, `_line_of_sight_clear` and `_bit_bites` are shared by six callers
across three proposed files, and `main.gd:1717` names the invariant — `_workable` and `_refuses` must
"assert the same sentence" or the charge spiders forever on a cell that never breaks. They go in **one**
file.

The mining *core* is already ported and faithful (`sim/mining/mining.gd` is a careful integer
re-derivation, including the reach-in-metres correction and a seconds-per-metre catch D0195 itself
missed). What is missing is the **shell**: the aim snap (`_effective_aim`, scans ±4 cells for a solid that
is reachable and LOS-clear, nearest the *cursor*), line-of-sight (Amanatides–Woo DDA), the swing cadence
(`SWING_PERIOD 0.28s`, and the clock is *primed* on release so the next charge's first blow lands
instantly), and the dig plan.

### Lane H · HUD — 65 rows

Every row is ABSENT: the current build draws **zero text**, has no `CanvasLayer`, no font handle, and no
main scene. So the value is in the mechanism and the rank, not the fidelity column.

`hud.gd` needs 8-10 files. Two constraints a naive split loses: `HELPER_TAGS` is **asserted total** (every
`_draw_*` on the class must appear in it, so splitting the class silently empties that population — the
archetypal instrument that cannot register its subject); and three surfaces stand down **inside**
themselves rather than at the call site, because each owns a hit region, and moving the stand-down
reintroduces a stale click target on an invisible control.

`UiTheme`'s palette has no fourth text rung, and that is a finding rather than an aside: one step below
`UI_TEXT_FAINT` measures 4.70/4.49/4.19 on the plates its sites land on and **cannot clear 4.5**. "The
quiet those sites were reaching for does not exist in this palette."

### Lane V · visuals — 72 rows

The miner (T1 #1). Then the casing grammar: a 16-kind profile table where identity lives in the **top band
only**, a per-part lighting model, and cold-iron idle that *subtracts* from idle rather than adding to
working "so the working state stays byte-identical to what every glyph was drawn against". Then the status
vocabulary — 11 statuses each carrying a *shape* as well as a hue, with the rule that two statuses with
different fixes may never share a mark.

Two porting hazards: `machine_view.gd` and `rope_view.gd` are **not files that reference a coordinator —
they are extensions of one**, with ~20 and ~8 reach-ins to private fields. Both must be rebound to
`(frame, canvas)` before a line moves.

### Lane E · sim systems — 100 rows

The tick order is eight named passes and **three of the orderings are load-bearing**: power before runners
(a generator on its last fuel tick still powers the network, then goes dark — a consequence of order, not
of any written rule); runners before flow (one tick of pass-through latency is what makes the splitter and
hopper order-independent); and iteration over the insertion-ordered `machines` array, never `grid` —
**placement order is real, unrecoverable sim state**, not derivable from the grid, and the save preserves it.

`water_flow.gd` is the highest yield per line in the whole backlog: 100 lines, **no float anywhere**,
already sorted for determinism, already conservation-invariant. One asymmetry to decide about rather than
inherit: the iteration list is built from a snapshot but levels are read live, so water falls 1 cell/tick
through dry space and instantly through wet columns.

The item model is not entities — an item is a `(StringName, int)` pair in one of seven dictionaries, and
the conservation invariant sums all seven. `core/entity_id_pool.gd` is not needed for it.

The known defect to **fix rather than inherit**: `pile_reachable` exists because a Drill above a vein and a
Forge below it in a one-column shaft — "the natural shape of hand-mining, and the shape the tutorial itself
teaches" — plug the only way back in, and the ore is permanently uncollectable. Legacy's own comment:
"Nothing here fixes that; it only lets the presentation layer say so."

### Lane S · audio — 53 rows

**Null result worth stating:** there is no audio file anywhere in this repository, tracked or untracked,
current or legacy. Every sound is synthesized at boot from `PackedFloat32Array` into a static
`AudioStreamWAV` — no generator, no playback thread. 32 generators off **one** RNG seeded `20260712`
threaded through `_ready` in a fixed order, so **generator order is part of the recipe**.

`view/audio/score.gd` is a verbatim port (three diff hunks: header prose, a `music_db` var, one line).
`shell/settings.gd::music_db()` is the real source and has zero callers because `shell/` has no boot.

`check_voice.gd` is the row to port alongside the library: it asserts no two sounds sit on top of each
other in a 6-D feature space, that beds do not click at the loop seam, and that level-driven beds actually
*move*. There are no files to listen to and no artist to catch a sign error — it is the only way anyone
knows a synthesized library is right. Its sibling `check_pump.gd` carries the lesson that generalises past
audio: "every generator, every stream and the whole `set_line` driver shipped and went green in
check_voice, which called `set_line` by hand — while the controller never called it once."

### Lane P · movement & harness — 64 rows

The strongest current area, and the audit is two-directional: **four current-only mechanics** legacy never
had (apex float, mantle, ceiling corner nudge, the `extends_forward` step-up gate) are reported alongside
the gaps, so the comparison is honest.

The verb table is the deliverable. Present and identical: run speed, gravity, terminal velocity, jump
velocity, jump buffer, wall depenetration, the ledge-vs-ceiling classifier (ported *with* legacy's own
fixed bug). Present and better: buffered-jump ordering, ceiling sweep, slope handling (D0206 proved
sub-pixel ground following and a flat-bottomed box are mutually exclusive). Absent and high-impact: the
grapple, the stride, step-down, over-speed coast, fall stagger, `FALL_START`, rope climb, wading.

**RESOLVER-PARKED**, reported not routed: step-down/floor snap (the largest single feel gap in the audit
sits behind the park — there is no seam, because both grounding paths only *land* a body whose feet
already reach a surface, and a step-down is by definition a snap onto ground the feet have not reached);
horizontal substepping (harmless at 150 px/s, **becomes reachable the moment the grapple lands** at 420
px/s = 1.75 cells/tick); walk-through materials; and body-width narrowing, which changes no resolver line
but re-baselines the entire acceptance/fuzz/reachability/golden corpus and is therefore
**parked-by-consequence rather than parked-by-rule** — the director should know the difference.

`check_mining.gd`'s 24 assertions are the mining test spec. **4 hold today, 8 fail outright, 4 pass
vacuously, 8 are about a mechanic that does not exist.** The current `test_mining.gd` covers a
*complementary* set legacy never asserts (hardness exactness, the crack bank resume, rhythm monotonicity,
hollow-tell floor/ceiling). The two suites should be unioned, not chosen between.

`play_agent.gd` is the reference pattern the plan asks for, and its two most valuable properties are both
**bugs already paid for**: arrival is two axes (a body that fell down a hole and kept walking reported
success, and the rung that followed mined downward for its whole budget from 53 rows too low), and arrival
is *stopped* (once the stride existed the agent reached its column at 222 px/s and was carried off the
spot before it could act). Copy both.

### Lane T · terrain / water / sky render — 95 rows

The veil dominates, and the single highest-value row is **`_veil_cut`** (`world_renderer.gd:3210-3256`),
which was under-rated on first read. The cut lifts each channel toward `255 * _light_tint(source)` and
only ever *adds* — so overlapping pools brighten toward full light and can never overshoot — and because
the lift carries the source's colour **through the multiply**, lamp-lit rock comes out amber and lift-lit
rock teal, each still carrying its own material hue underneath. *Revealing in colour beats repainting in
colour*, and that is precisely why legacy's additive pass is only `0.17` flicker rather than the thing
doing the work. **Build the coloured cut before the pools**, or reproduce legacy's own failure: three
overlapping pools summed past 1.0, tripped the glow threshold, and blew the centre of the frame to a white
smear.

**T-94, the buried lode stain, jumps to Tier 2 and is ten lines.** `if sim.lode.has(c)`, stain the rock
toward the vein at `LODE_STAIN_BURIED 0.26` and `v *= 0.78`. Rock with a vein *behind* it is mineralised
rock and should look it — "otherwise, once ore stops being a block, the world is uniform stone and the
only way to find anything is to dig at random." **This build already made the lode migration**; `obs.walls`
is where ore lives. The buried stain is the discoverability cue that migration was *for*, and it is
missing. Deliberately not a glint: sparkling cells sealed inside stone read as a floating starfield rather
than as a vein, so buried ore gets no motion at all.

**A trap that arms itself later.** `WorldEnvironment`'s grade (`saturation 1.18`) is a *viewport*
post-process. Legacy's retained terrain bake needed `own_world_3d = true` or the grade re-applied to the
same stored pixels every bake and compounded **1.18ⁿ** — grass measured `(87,130,47)` at boot and
`(42,255,0)` after one play arc, with the walked surface line reading as a neon band. 24 colour-change
events before, 0 after. This build has no `WorldEnvironment`, so the trap is **dormant, and it arms the
moment the glow pass and a retained bake both exist.**

Two latent legacy defects, reported not inherited: `_haze`'s z is 46 against a comment claiming it sits
above the veil at 50 (the shipped behaviour follows the z, so one of them is wrong); and
`VEIL_CULL_MARGIN` is derived as a max over four *bounded* pool radii while the crystal-seam pool is
`2.2 + 0.55 * span` with **nothing bounding `span`** — and because the cull drops *cells* rather than
seams, a vein straddling the view edge loses its outside cells, shrinking `extent` and so shrinking its
own glow. The size of the glow is partly a fact about where the camera is.

### Lane W · world generation — 78 rows

Dominated by the four defects above. Beyond them, the ranked gaps are: **per-cell deposit amounts**
(`amounts`, absent — `data/strata/*.yaml` parks the constants under `pending_sim_economy`); the **lode
plane** as a generated feature (72 bodies, accreting into the *background* plane so host rock stays
solid); the **drought pass**, whose entire purpose is anti-monotony — walk each column counting unbroken
plain rock and at 18 rows plant something back into the run, a vug 28% of the time — and which is the one
pass that **reads the world it writes**; the **horizontal richness field** (a per-column multiplier in
[0.45, 1.55] mixing a noise band with a distance-from-spawn ramp, the "frontier pull"); and the
**heightmap**, which the current build has no equivalent of at all — `_fill_base` fills row 0 downward, so
there is no surface, no sky, and no mouth.

The heightmap's walkability is worth recording because it is **arithmetic, not a post-pass**: the sum of
its three octaves' amplitude x frequency products is `0.179 + 0.579 + 0.156 = 0.914 < 1.0`, so `round()`
can never step more than one row. The designed exceptions are three named scarps, and `on_scarp()` exists
so a test can tell design from noise.

Two corrections to the brief's own numbers, re-checked against the files: `layered_world_gen.gd` declares
**99** constants and `heightmap_world_gen.gd` **19** — the 118 figure is right for the *stack*, not the
one file. And `legacy/src/data/strata` does not exist; the ladder is `legacy/scenes/strata.gd`.

`core/seams.gd`'s port was audited and is **faithful, provably**: all 42 added lines are comment, the
float→integer conversion is proven exact over the entire 196,608-input domain with 24,250 answering true,
and the naive conversion `v < int(0.18 * 65535)` — which disagrees on exactly 3 inputs — is kept in the
suite as a control that must keep failing. It is complete, correct, and **inert**: nothing calls `at()`.

---

## Open questions this pass raises

- **P019** — the depth tint vs glimmer's hue (raised, D0252).
- **PRE-1** — re-open Q5's clock pin. It was ruled correctly and the ground has moved.
- **The scale convention** — pixels or metres for the remaining absolute constants (finding 4 above).
- **The veil's scope** — `Observation` is window-scoped by construction, and the openness blur has wrong
  values at its own edges. Either the veil texture becomes window-sized with a margin, or `Observation`
  grows a world-size field. This is a real design decision, not a mechanical one.
- **Alerts and the minimap** are grid-wide by nature against a window-scoped envelope. Same shape.
- **The body proportion** — legacy's miner is 0.44 cells wide with 9px of slack in a one-cell shaft; the
  current body is 4.00 cells wide with **zero**. The honest minimum shaft here is 5 terrain cells, which
  is a corridor rather than a shaft. Vision-level; not a work item.
