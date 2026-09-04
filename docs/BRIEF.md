# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03, twelfth round. A′: steps 0–5 done (the eleventh round's brief is in
`git log -p -- docs/BRIEF.md`; D0343–D0361). THIS ROUND: STEP 6, THE VIEWS AND THE BOOT, IS COMPLETE
(6a–6q, D0362–D0380), AND STEP 8, THE WORLDGEN CONTENT, IS COMPLETE (8a–8h, D0381–D0388). Step 7, the
economy, is the director's to scope (plan §8). `godot --path .` runs the game on the ported stack over a
world that now has legacy's hills, rifts, sinkhole mouths, teeth, rubble, ledges, aquifers, lodes, a
richness gradient and trees.** No eye has seen any of it: eleven look verdicts are queued (T005–T011).

**Headline: the whole of legacy's world and view are on the deterministic substrate, and the plan's one
stated determinism crack was a stale sentence.** Gate 8's golden, pinned from CI Linux, matched a local
macOS run at 200 of 200 checkpoints on a dig through generated terrain before a line of step 8 was
written (D0381); the four float sites use only IEEE basic operations and stay. The content then came
over as seven config-gated passes, each committed with the golden unchanged, and one switch-on moved it
once. The switch-on is also where the real world spoke: no sinkhole mouth at the boot seed (legacy's
20 m keepout is most of a half-width world), rift-wall ore as four-pixel specks that collapsed the
ore-body pin (a metre-cell turned is a metre-square nugget here), and a CI-only rule that hardness is
whole halves. Every one was fixed at its cause and has a row that fails without it.

---

## What landed

- **Step 6 (D0362–D0380), the views and the boot.** Water painter and drips (6a); the three look
  registries pinned against the data (6b); the machine painter with nameplates planned per frame (6c);
  payouts and falling items on the consumed flow channel (6d, 6e); ten synthesized beds and the one-shot
  voices as edges over two observations (6f); the hotbar and PACK FULL chip (6g); the inspector,
  objectives and hints with every content row re-authored (6h); the minimap on a coarse class plane the
  grid maintains (6i); the settings page as a snapshot from the shell (6j); the additive light pass over
  the veil (6k); the ore seams and every light cutting the veil (6l); the mark grammar as a list a test
  can fail on (6m); the placed plane's clockwork (6n); the surface tone (6o); the heat haze and rock
  tooth shaders on the deterministic clock (6p); and the boot: `shell/main.tscn` is the main scene,
  `Main` the seat over the door, `PlayInput` and `HudBridge` its hands and its HUD, `ViewStack`,
  `SceneAudio` and `MinerDraw` moved into `view/` (6q). CI 86 → 115 suites.
- **Step 8a (D0381).** Measured, not built: the golden already identical across the pair. Plan §5.5 and
  step 8's acceptance amended to the measurement.
- **Step 8b (D0382).** `Relief`: legacy's pad, three waves and scarps, the sines an integer table; the
  generator's surface a row per column through every pass; `CavePasses` take per-column floors.
- **Step 8c (D0383).** `VerticalPasses`: rifts breathing on the sine table, ore in their walls, sinkhole
  mouths over the deepest falls with the `pow(x, 2.2)` flare as a table; `spawn_col_m` on the site.
- **Step 8d (D0384).** `StuddingPasses`: ledges a metre thick, teeth tapering from a metre to a cell,
  rubble only over what holds it, the drought pass planting a vug or a vein at 18 m of plain rock.
- **Step 8e (D0385).** `PlanePasses` through `ShaftGenerator.enrich(world, site, seed)`, called by
  `WorldSeeder.load_world`: aquifers flooded on the water plane with a vein off the rim, lodes on the
  deposit plane with per-cell amounts by the start record's rule (3 a cell shallow, 13 deep).
  `ContentPasses` holds the order and the splits.
- **Step 8f (D0386).** `Richness`: the frontier gradient as an integer band on a lattice from the
  stream's own split; the ore and coal scatters and the lodes read it.
- **Step 8g (D0387).** `TreePass`; `wood` and `leaves` as material records with legacy's colours.
- **Step 8h (D0388).** `shallow_clay` carries every record; `tests/test_shallow_clay_content.gd` (17)
  asserts the records agree with the tutorial start and the world carries what they promise; the golden
  re-pinned from CI Linux (PR #50, the draft harvest route). CI 115 → 122 suites.

---

## What was learned

1. **A plan sentence is a claim with a date.** "Diverges at checkpoint 3" described D0167's world; the
   golden had matched across the pair at every re-pin since. Measured before building the fix, and the
   fix was not built (D0381). The rule that keeps it true: nothing on the generation path calls
   `sin`/`cos`/`pow`/`exp`; a shape that needs one is an integer table (`Relief.SIN_MILLI`, `FLARE_MILLI`).
2. **`SplitRng.split` is keyed off the root seed, so a pass can be added without moving any other's
   draws.** The whole gating design — seven passes, each committed with the golden unchanged — rests on
   that one property, checked in the file before relying on it.
3. **`TileGrid.excavate` on air moves the running signature.** It XORs the cell's term; excavating an
   already-open cell corrupts the signature against the recomputed one. Every pass excavates only a
   solid cell. Found by reading `excavate`, not by a failure — the failure would have been a
   determinism red with no visible cause.
4. **A control that fails harder: the same disc, two floors.** Under a valley column the scalar floor
   opened 57 cells and breached 9 columns' bands; the per-column floor opened none (D0382). The first
   control ("some valley exists") had failed honestly on a seed with none — an expected null carries no
   conclusion.
5. **Fixtures at chance 1.0 chain.** A tooth's tip seeds the next tooth, a block's top is the next
   block's floor, a rift crossing another reports its cells twice (a one-cell "run"). Judge the rock at
   the roots, dedupe before a run analysis, and pose "every cell asks" as the rate times the cells a
   metre (4.0, not 1.0) — the rate is per metre of ground (D0384, D0387).
6. **Legacy's constants carry legacy's world size.** The sinkhole keepout of 20 m about spawn left 63% of
   legacy's 128 m world eligible and 37% of ours; all four rifts fell inside it and the boot seed had no
   mouth. Halved, like the scarp distances. A port keeps the ratio where the constant is a fraction of
   the world (D0388).
7. **A metre-cell turned is a four-pixel speck here.** Rift-wall ore as single cells took copper's median
   body from 550 cells to 2 and the ore-body pin went red. Each turn grows a metre-square nugget — the
   cell legacy turned — and the pin measures the scatter on the site WITHOUT its records, while the
   content world gets its own row (the median body at least a metre square) (D0388).
8. **A data change's neighbours are every suite that enumerates the records.** CI's `test_mining` refused
   `wood` 1.8 and `leaves` 0.35 (hardness converts through whole halves); the local run covered the tree
   suite, the palette and the looks, not mining. Main was red for one commit (8c16d31c).
9. **The depth fraction measures from the datum, not row zero.** Legacy divided the absolute row by the
   world's rows with its 20-row sky inside; this build's 80 rows of sky would have pushed every lode
   toward "deep". Attempt counts are taken from the datum too, so relief never changes how many veins a
   site seeds (D0382, D0385).
10. **The ore-body pin found the port's scale error and the content's population change at once, and
    they needed different answers.** One was a defect (the speck), the other a different subject (the
    content world). Splitting the population — plain site for the pin, content site for its own row — is
    what let both be stated (D0388).
11. **Step 6's mechanical rules, kept for the next porter:** a view file may not name a sim class
    (`Interface.Observation` restates the constants); `get_image()` reads nothing headless (byte
    accessors); a bare `Node2D` cannot be drawn on outside `_draw`; the duplication gate includes tests
    (shared fixtures live in `test_base`); `x == ([..] as Array[T])` needs the parentheses; every
    `_test_*` that awaits must be awaited; `Camera2D.make_current` before the node is in the tree errors.
12. **Verify a subagent-free session the same way.** Every count in this brief was read off a PASS line
    or a tool's output after the change, never from the plan's estimate; the two that were not (the
    "diverges at checkpoint 3" sentence, the sinkhole keepout's fit) were the two that were wrong.

---

## The decisions this round is waiting on

**Step 7, the economy.** The plan says the director scopes it (§8): the splitter, the Ore Vent, power
gating, the crusher chain, `press_plate`/`mill_gear`, the material-id/item-id map (D0349 — and now
`wood` and `leaves` bore as their own ids too), ore BLOCK amounts (`pending_sim_economy`, unread), the
resolver, the ramp glide, the 36 untracked recordings, the `history/` cull.

**The eye.** T005–T011: the shaped surface, the mouths at 12 m, the teeth and rubble at this scale, the
trees, the richness band's texture, an aquifer breached, and every step-6 look in one sitting.

**CI:** 6k, 6l, 6o, 6p, 6q green on all four jobs (6m, 6n superseded by the next push); 8a–8d green;
8e superseded; 8f's first run hit a connection reset downloading Godot and its re-run was superseded;
8g red on `test_mining` (the hardness halves), fixed on main as 8c16d31c (green on all four jobs); 8h
harvested on draft PR #50 (every suite green there but the golden's array match, as a world change must
be), then pushed to main as 8c1c2695 with the re-pin e47dfaa4 on top; PR closed, branch deleted. The
head's run (e47dfaa4) is the one to read.

---

## Anything that felt wrong even though it passed

**No eye, anywhere.** Twenty-seven commits of visual and world content and not one screenshot judged.
The plan says look verdicts are the director's; the queue is the whole of it.

**The widths are mine.** A tooth a metre wide, a trunk half a metre, a canopy 3 × 2.5 m, rubble a metre
square: legacy's were one metre-cell each and a four-pixel cell would not read. Each is a record field.

**Aquifers are full sealed pockets.** Legacy's were too; what the water phase does when a dig breaches
one is D0344's algorithm, unwatched on this world.

**Boot time is unmeasured.** The passes run over 256 × 1104 cells; D0326 measured 4 s before them.

---

## Blocked, and what it's waiting on

Nothing blocks the next step; the next step is the director's.

## Taste queue

**11 open.** T001–T004 unchanged; T005–T011 new this round (`docs/TASTE_QUEUE.md`).
