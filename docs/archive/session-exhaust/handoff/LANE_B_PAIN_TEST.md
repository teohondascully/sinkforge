# The pain test — modelling the friction rung that can observe a capped trip

UNTRACKED (`.git/info/exclude:11` excludes `docs/handoff/`). Written 2026-08-23 in Lane B, at `defdc44`.
**Nothing here is built and nothing here was measured.** No engine was booted for this document: every
number below is arithmetic over constants read out of the source at that commit, and each one is labelled
as a prediction. The companion half is `docs/handoff/T1_0_SINK_DESIGN.md`, which models the SINK; this
document models only the INSTRUMENT that its acceptance contract point 1 asks for, and deliberately does
not restate the sink options.

**What is established and not re-argued here:** `PACK_BULK_CAP = 90` is live at
`src/core/factory_sim.gd:226`; the four friction rungs are the only instruments that measure what a trip
costs; the heaviest reaches 38 bulk; the cap cannot bind in any of them even in principle
(`docs/PRIORITY.md:380-384`).

---

## 1. What the rung must pose

### 1.1 How the existing four rungs are built

All four live under the `# --- FRICTION journeys ---` banner at `tools/play_tests.gd:1293`, and they share
one fixture and one shape.

**The fixture** is `_bury_vein(agent, col, depth)` at `tools/play_tests.gd:1302-1309`. It stamps a clean
earthen column from `MainView.SURFACE` down, puts one ore block at the bottom, seeds that block's latent
yield, and lays a stone floor under it:

| line | what it does |
|---|---|
| `play_tests.gd:1304-1305` | `set_solid(Vector2i(col, y), &"earth")` for `y` in `range(SURFACE, target.y)` — exactly `depth` earth cells |
| `play_tests.gd:1306` | `set_solid(target, &"ore")` — one ore block at row `SURFACE + depth` |
| `play_tests.gd:1307` | `agent.sim.deposits[target] = 40` |
| `play_tests.gd:1308` | a stone floor at `target.y + 1` |

`MainView.SURFACE` is `HeightmapWorldGen.FLAT_SURFACE_ROW` (`scenes/main.gd:566`), which is **20**
(`src/core/heightmap_world_gen.gd:59`).

**The shape** of a round-trip rung is three verbs: `agent.dig_down_to(vein)`, then read the ore delta out
of `sim.inventory`, then `agent.climb_to_surface(MainView.SURFACE - 1)`, then print `agent.friction()` and
assert `_within_ceilings`.

**The grants** are the setup hatch `agent.give(item, n)` (`tools/play_agent.gd:801-802`), sanctioned at
`tools/play_tests.gd:9-10` ("Resource INJECTION (agent.give) is allowed to ARRANGE a situation"). Note that
`give` writes `sim.inventory` directly and therefore **does not go through `can_carry`** — a grant is not a
capped acquisition, and §4.6 makes that a screen.

| rung | line | col | vein | grant | ceilings asserted |
|---|---|---|---|---|---|
| round-trip | `play_tests.gd:1315` | 34 | depth 8 | 12 earth, 25 rope | `mines 12 · places 5 · jumps 4 · frames 100` (`:1330`) |
| deep round-trip | `play_tests.gd:1339` | 62 | depth 14 | 20 earth, 25 rope | `mines 20 · places 8 · jumps 4 · frames 165` (`:1354`) |
| escape a deep pit | `play_tests.gd:1363` | 37 | no vein (a 6-deep pit) | 12 stone | `places 9 · jumps 9 · frames 175` (`:1382`) |
| jagged tunnel | `play_tests.gd:1389` | 57 | no vein (a lumpy corridor) | 8 stone | `jumps 5 · stuck_frames 20` (`:1416`) |

Column collisions between rungs do not matter: `_boot()` (`play_tests.gd:1749`) instantiates a fresh
`main.tscn` per try and `_teardown` (`:1758`) frees it. What the columns must avoid is the **worldgen
fixture band the rungs' own comments name as cols 40-56**, and the plateau bounds `FLAT_START = 30` /
`FLAT_END = 66` (`src/core/heightmap_world_gen.gd:10-11`) — off the plateau, `_bury_vein` would start its
column at row 20 while the real ground row is somewhere else.

### 1.2 What the metrics mean, and the one that does not mean what it looks like

Declared at `tools/play_agent.gd:30-38`, printed by `friction()` at `tools/play_agent.gd:57-58`.

- **`mines`** — successful `try_mine` calls. Incremented in `do_mine` (`play_agent.gd:162-167`), in
  `mine_cell` (`:332-342`), and inline in `dig_down_to` at `:557` and `:560`.
- **`places`** — successful `try_build` calls, via `do_build` (`play_agent.gd:171-175`): staircases,
  pillars and rope anchors.
- **`jumps`** — rate-limited jumps, `_do_jump` (`play_agent.gd:43-48`).
- **`stuck_frames`** — frames of no progress; four sites (`play_agent.gd:265, 428, 651, 705`).
- **`peak carried`** — the per-item peaks from `_sample_peak` (`play_agent.gd:101-115`), rendered by
  `peaks()` (`:119`). `PEAKBULK` is the peak of the SUM over the `BULK` list (`play_agent.gd:85-86`), which
  is the quantity a pack actually limits (`:89-94`); `HANDED` is the bulk at the FIRST sample, i.e. the
  loadout before any mining (`play_agent.gd:96`).

- **`frames` IS NOT A TRIP COST. It is a CLIMB cost.** `frames += 1` appears exactly once in the file, in
  `step()` at `tools/play_agent.gd:158`, and every `await step()` call site — `:646`, `:658`, `:672`,
  `:691`, `:698` — is inside `climb_to_surface` (`:614-710`). Everything else in the file waits on
  `_tick()` (`:150-152`), which the docstring at `:146-149` says deliberately does not count a frame.
  `dig_down_to` waits at `:561` on `_tick` and counts its own local `t`; `walk_to_column` waits at `:432`;
  `approach` at `:269`. **So the descent, the walking, the mining and any delivery are all invisible to
  `frames`.** The deep rung's `frames = 134` is the cost of climbing out of a 14-deep shaft and nothing
  else. This is the single most important fact for §2: a rung asked to report "what a capped trip costs"
  cannot answer with `frames`.

### 1.3 Why the pack cannot fill today — sharpened

The established figure is that the deepest rung's arithmetic ceiling is about 74 (20 granted + 14 shaft
earth + the vein's 40). **The hand-realisable ceiling is much lower than that, and the difference is the
reason no rung is close.**

`mine()` at `src/core/factory_sim.gd:781` handles an ore-like block at `:787-812`. The comment at
`:788-792` states it: hand-mining clears the block and pockets a **3-6 burst**; "the block's larger latent
yield in `deposits` is NOT hand-extractable". The code is `var burst: int = mini(_ore_burst(cell) if keep
else 0, latent)` (`:794`), and `_ore_burst` (`:1414-1416`) returns `3 + (absi(h) % 4)`. The remainder is
converted into a background **lode** (`:801-804`).

A lode is worked one unit at a time by `take_lode` (`src/core/factory_sim.gd:1465`), reached through the
player verb `MainView.try_work_lode` (`scenes/main.gd:1860`) — **a different verb from `try_mine`, and
`tools/play_agent.gd` has no wrapper for it.** `do_mine` goes to `main.try_mine` (`play_agent.gd:163`) and
that is the pilot's only extraction verb.

So the deepest rung's realisable ceiling is `20 + 14 + (3..6)` = **37 to 40**, and the sweep printed
38/37/37 (`docs/PRIORITY.md:382-383`). The rungs are not near the cap; they are at their own ceiling.

**And spoil alone cannot reach the cap inside L1.** The seal is an unbroken full-width band of unmineable
sealrock at `SEAL_TOP = 84`, `SEAL_ROWS = 2` (`src/core/layered_world_gen.gd:171-172`). Keeping
`_bury_vein`'s stone floor above it means `20 + depth + 1 <= 83`, i.e. `depth <= 62`, so at most 62 earth
cells. With the deep rung's 20-earth loadout and the best possible burst that is `20 + 62 + 6 = 88`, one
short of 90. Going further: binding the cap on spoil needs `20 + depth + 3 > 90`, i.e. `depth >= 68`,
whose ore cell would sit at row 88 — below the seal, with the earth column stamped straight through rows
84-85. **Any spoil-only shaft that would bind the cap has to be stamped through the L1/L2 gate.** Nothing
in `_bury_vein` stops that (it calls `set_solid` unconditionally), so this is a constraint I am imposing on
the fixture, not one the code enforces — but a fixture that erases the seal is not measuring this game.

**Conclusion: the fifth rung must fill the pack with ORE, not with spoil.**

### 1.4 The rung: an ore-bottomed shaft

The proposal is the smallest change to the existing fixture vocabulary that can bind the cap: keep
`_bury_vein`'s clean vertical column, and make the bottom `K` cells of it **ore** instead of one ore block
at the end.

**Add a defaulted parameter rather than a new helper**, so the four existing call sites are unchanged in
behaviour and in reading:

    _bury_vein(agent, col, depth, ore_rows: int = 1, per_cell: int = 40)

with `ore_rows = 1, per_cell = 40` reproducing today's fixture exactly (`play_tests.gd:1306-1307`).

**Pin each ore cell's `deposits` to 3.** `mini(_ore_burst(cell), latent)` (`factory_sim.gd:794`) with
`latent = 3` yields exactly 3 for every cell regardless of the hash, and `left = 3 - 3 = 0` sends the code
down the `deposits.erase(cell)` branch at `:806` — "a thin seam the burst took whole: nothing left to
open". This matters for two independent reasons:

1. **No lode residue.** Any leftover becomes a lode the pilot has no verb for (§1.3), so it would silently
   cap the rung's yield below its own arithmetic — the fixture would promise material the instrument
   cannot take.
2. **The hash leaves the instrument.** `_ore_burst` is a pure function of the cell coordinates
   (`factory_sim.gd:1415`), so a fixture at a fixed column samples one burst pattern forever. Pinning to 3
   makes the yield exact and column-independent, and 3 is the *minimum* burst, so the arithmetic below is
   the conservative end.

#### Recommended parameters (configuration A — answers the first question cheaply)

| parameter | value | why |
|---|---|---|
| column | **32** | on the plateau (`FLAT_START = 30`), clear of the 40-56 fixture band |
| depth | **40** | target row 60; above `DEEPSLATE_ROW = 76` (`layered_world_gen.gd:165`) and far above `SEAL_TOP = 84` |
| ore rows | **30** | rows 31-60, `deposits = 3` each |
| earth rows | **11** | rows 20-30, i.e. `depth - ore_rows + 1` |
| stone floor | row **61** | as `_bury_vein` already does |
| grant | **20 earth, 25 rope** | byte-identical to the deep rung (`play_tests.gd:1343-1344`), so the loadout is held fixed as a control |

**The arithmetic:**

    granted earth                 20
    earth from the shaft          11      (rows 20-30, one unit per cell, factory_sim.gd:837)
    ore from the run              90      (30 cells x 3, pinned)
    ------------------------------------
    arithmetic ceiling           121      against PACK_BULK_CAP = 90
    excess over the cap           31

Against the deepest current rung's realisable **37-40**. The ceiling exceeds the cap by 31 units, and —
unlike the 74 figure — every unit of it is realisable by the verbs the pilot already has, because it is
either granted or a hand burst.

**Where the cap binds, predicted:** bulk entering the ore run is `20 + 11 = 31`, so `pack_room()`
(`factory_sim.gd:1745`) is 59. After 19 ore cells the pack holds `31 + 57 = 88` with room 2; the **20th
strike of the ore run** takes 2 units and spills 1 through `take_into_pack` (`factory_sim.gd:1773-1783`).
Cells 21-30 spill 3 each. Predicted trip-1 payload **59 ore**, predicted spill **31**, which reconciles
with the excess above.

**Predicted trips: 2.** Trip 1 carries 59 ore of the 90; the remaining 31 sit on the floor of the shaft;
trip 2 descends an already-open shaft with an empty pack and takes all 31.

#### Configuration B — the reading that is directly comparable with the spike

`factory_sim.gd:218-219` records the measurement the cap was chosen on: a 263-unit lateral lode face gave
**three** full trips at cap 90. A rung whose predicted trip count is also 3 makes a divergence meaningful.

    column 32, depth 62 (target row 82, stone floor row 83 — the seal at 84 untouched)
    ore rows 56 (rows 27-82), earth rows 7 (rows 20-26), grant 20 earth + 25 rope

    granted 20 + earth 7 + ore 168  =  195 ceiling against 90; excess 105
    trip 1: room 63 entering the run, binds exactly on ore strike #21 (27 + 21*3 = 90)
    trips: 63 + 90 + 15  ->  3

**Its two honest costs.** A 56-row solid ore column is scenery worldgen would never produce (though the
existing fixture's "clean earthen column (no caves/gaps to complicate)", `play_tests.gd:1306`, is
artificial on the same grounds and is defended in-comment for the same reason: comparability). And a
62-deep climb is roughly 4.4x the deep rung's 14, so the rung's wall time and its `frames` are large.

**A single legal column cannot do better than 3 trips**: 62 cells at 3 is 186 ore, and
`1 + ceil((186 - 69) / 90) = 3`. A 4-trip reading would need a lateral gallery, which costs new navigation
(`mine_cell`, `play_agent.gd:332`) and is bounded by the 10 free plateau columns either side of the
fixture band. **Recommendation: build A first — it answers "does the cap bind, and is the trip still a
trip" — and treat B as a widening once A is green.** Which one ships is a director call, not mine.

**The general formula**, so the rung is tunable without re-deriving:

    payload of trip 1   P1     = 90 - granted_bulk - earth_rows
    total ore                  = 3 * ore_rows
    trips                      = 1 + ceil((3 * ore_rows - P1) / 90)
    arithmetic ceiling         = granted_bulk + earth_rows + 3 * ore_rows

### 1.5 What has to be added, and what does not

**Does not** need adding: the extraction verb (`dig_down_to` already mines straight down the column,
`play_agent.gd:529-565`), the climb (`climb_to_surface`, `:614-710`), the delivery verb (`deposit_selected`,
`:765-771`, approaches `sim.machines[0]` and calls `main.try_deposit()`), the peak sampler
(`_sample_peak`, `:101`), or a lode verb — the pinned `deposits = 3` removes the need for one.

**Does** need adding: the `_bury_vein` parameters (§1.4); a `trips` counter and a whole-trip frame count
(§2, and **neither exists anywhere in the tree** — `grep -rn "trips\b" --include="*.gd"` finds only the
word "trips" as a verb in unrelated comments); and the derived `spilled` reconciliation (§2).

---

## 2. What it must report

Contract point 1 asks for "frames and trips together". The reason the two must be in one row is stated at
`docs/PRIORITY.md:387-390`: one existing measurement counts trips-per-face and does not measure cost
(`factory_sim.gd:218-219`), the four rungs measure cost-per-trip and cannot reach the cap, **and the two do
not overlap**. A reading that answers "trip or job" has to be one line about one journey.

| quantity | status | why it is needed |
|---|---|---|
| **`peak_bulk`** | exists, `play_agent.gd:95`, printed at `:57` | The proof the cap bound. It must read **exactly 90**. 89 means the fixture never filled the pack and the whole rung measured nothing; 91 means some path bypassed `can_carry` (`factory_sim.gd:1752`) and the *sim* is the finding. |
| **`handed_bulk`** | exists, `play_agent.gd:96` | The sampler's positive control. It must read **20** (the grant). See §4.2 — this is the one number that distinguishes "the pack was empty" from "the sampler never ran". |
| **`trips`** | NEW | The question is *how many* interruptions the face costs. Must be incremented by an **observed** delivery event, never computed from the face size (§4.5). |
| **predicted trips** | NEW, printed beside the observed | Two numbers side by side, so a divergence is visible rather than impossible. Never one number derived from the other. |
| **`trip_frames`, per trip and summed** | NEW | Because `frames` is climb-only (§1.2). This is the actual cost of a capped trip and today there is no counter that spans one. |
| **`frames`** | exists, `play_agent.gd:158` | Keep printing it **unchanged**, so the new row stays commensurable with the four existing rows and so no number a ceiling judges moves (`play_agent.gd:146-149` states that rule for the sampler; it applies to any new instrumentation). |
| **`payload` at the cap, as `ore/90`** | NEW, derived | In configuration A, 31 of the 90 is grant plus spoil: the first trip's freight is **59, not 90**. A sink that consumes ore cannot touch the 34% of the cap that is not ore, and without this number the row would silently attribute spoil cost to freight. |
| **`spilled`** | NEW, derived twice | The material the cap refused. Compute it **two ways and reconcile**: (a) `total_produced[&"ore"]` minus ore in the pack minus ore delivered; (b) the sum of `sim.ground` piles in the shaft column. They must agree; if they do not, the population is wrong and neither is a measurement. |
| **`mines`, `places`, `jumps`, `stuck_frames`** | exist | The standard friction vector, so the row can be read next to the other four. |

The row's own single-line conclusion, in the existing `friction()` idiom:

    pain: trips=2 (pred 2) | bound at ore strike 20 | peak=90 handed=20 payload=59/90 spilled=31
          trip_frames=[..,..] sum=.. | frames=.. (climb only) mines=.. places=.. jumps=..

**Where `trip_frames` should live.** The clean form is a new counter incremented inside `_tick()`
(`play_agent.gd:150-152`), the one place every wait in the file passes through. That is a strict superset
of `frames`, it is judged by nothing, and it changes no existing number — which is exactly the separation
the `_tick` docstring argues for at `:146-149`. The rung then snapshots it at each trip boundary and
reports deltas, so no counter reset is needed. A zero-change alternative is an
`Engine.get_physics_frames()` delta taken by the rung itself; it costs nothing in `play_agent.gd` but is
not comparable with any existing metric.

---

## 3. The ratchet problem

Every existing friction rung asserts a ceiling, and `frames` is one of the metrics they assert on
(`play_tests.gd:1330`, `:1354`, `:1382`). `_within_ceilings` (`play_tests.gd:1780-1788`) fails the harness
on a breach, and the convention above it (`:1776-1779`) is that ceilings sit "~1.6x above today's
baseline". A fifth rung inherits the expectation of a ceiling, and **nobody has a justified bound for it**:
its depth, its load and its trip structure are all new, so no existing number transfers.

The two rules in tension are that three positive readings with no negative population cannot locate a
bound, and that refusing to guess a bound is not a reason to refuse to ratchet what shipping already
decided. Both survive, in this order:

### First run: assert the POSING, not the cost

Assert only things whose value is a consequence of the fixture's arithmetic or of a shipped rule, and
assert them **directionally** — a claim that would pass if the subject were absent is not an assertion:

1. `agent.peak_bulk == FactorySim.PACK_BULK_CAP` — the cap bound, exactly. Equality, not `<=`: `<=` is
   satisfied by a rung that never filled the pack, which is precisely today's state.
2. `agent.handed_bulk == 20` — the sampler ran at least once and saw the grant (§4.2).
3. `spilled > 0` — the cap actually refused material. A `>= 0` here would be true by construction.
4. `trips >= 2` — a consequence of `121 > 90`, not a guess.
5. `sim.carried_bulk() < FactorySim.PACK_BULK_CAP` immediately after the grants (§4.6).
6. The goal itself: the face is cleared and the body is on the surface.

And explicitly **no** ceiling on `frames`, `trip_frames`, `mines` or `places`. Print them. The comment
should say, in the idiom the other rungs use for their own history, that the ceilings are deliberately
absent and why.

### Later: ratchet what shipping decided, with a negative population

The ratchet is earned when three things exist, not when three green runs exist:

- **A member list, not a count.** Record the actual readings per seed and per configuration — the three
  corpus seeds 1337/512/7 — as a table in the rung's comment, the way `:1328-1329` and `:1352-1353` do. A
  count of green runs cannot be re-measured; a list can be diffed.
- **A negative control that the ceiling catches.** A mutant that makes the trip genuinely more expensive
  must breach the proposed ceiling: drop the 25 rope from the loadout and force the pillar-jump path
  (`play_agent.gd:667-711`), or halve `PACK_BULK_CAP` so trips double. A ceiling never observed to fail is
  decoration, and this is the difference between ratcheting a shipped fact and guessing a bound.
- **The 1.6x convention applied to the observed maximum**, not to a hoped-for number, exactly as
  `play_tests.gd:1778` prescribes.

### One trap specific to this rung

Its `frames` will be dominated by **depth**, not by the load: configuration A climbs 40 rows where the deep
rung climbs 14. Putting an early `frames` ceiling on it would lock in a depth and call it a friction, and
the next person to tune the ore run would breach a ceiling that was never about their change. If a ceiling
is wanted early, put it on **`trip_frames` per unit of ore delivered** — a cost per freight, which is
invariant to depth in a way the raw climb is not — and even that only after the negative control exists.

---

## 4. What would make the reading a lie

Five ways this instrument could print a healthy number while measuring nothing, each with the screen that
catches it.

### 4.1 A posed field the game recomputes

`deposits` is safe: `mine()` reads it at strike time (`factory_sim.gd:793`) and nothing re-derives it. But
`lode_max` is written by `mine()` itself (`:804`) and `lode_fraction` (`:1496-1500`) reads it, so a fixture
that pre-wrote `lode_max` would be posing a field the game overwrites on first contact. The pinned
`deposits = 3` avoids the lode path entirely (`:806`), which is a second reason for it.

**The screen:** after setup and after **at least one physics frame has run**, read every seeded cell back
through the sim's own accessor — `sim.ore_deposit_at(cell)` (`factory_sim.gd:1422-1427`) — and assert it
is 3. Reading the dictionary you just wrote proves nothing; reading it through the game's accessor after a
frame proves the game agrees.

### 4.2 A journey that walks without mining, so the sampler never fires

**This exact defect was found and fixed here**, and the fix is documented at `tools/play_agent.gd:128-149`.
`_sample_peak()` was reachable only from `step()` and `do_mine()`; `walk_to_column` waits on a bare physics
frame and the jagged-tunnel rung never mines, so it printed

    PEAKBULK=0 HANDED=0 MINED=0 | peak carried: (carried nothing)

while holding 8 stone (`:131-139`). Those were the counters' initial values, and the docstring's own
verdict is that it "read exactly like a measurement". The fix moved the observation into `_tick()`
(`:150-152`), the one wait every action in the file passes through — and the docstring at `:141-144` names
the two worst sites, `wait()` and `collect_below()`, as the ones whose own docstrings say they
*accumulate*.

The new rung is more exposed to this than any existing one, because it adds a delivery-and-return loop and
therefore new wait sites.

**Three screens, and the first is the important one:**

1. **A positive control that travels inside the measurement.** Assert `handed_bulk == 20` on every run.
   `handed_bulk` is set at the first sample (`play_agent.gd:96-97`); if the sampler never fires it stays
   at its initial 0, and `0 != 20` fails loudly. **No existing rung has this witness** — they assert on
   metrics whose healthy value and whose never-ran value are not distinguishable.
2. Grep the new rung and any new agent code for `physics_frame`. The only legal occurrence in
   `play_agent.gd` is inside `_tick()` at `:151`; a direct `await tree.physics_frame` anywhere else
   reintroduces the defect verbatim.
3. Assert `peak_bulk >= handed_bulk`, which is free and catches a sampler that fires once and then stops.

### 4.3 A deterministic fixture that draws once

`_bury_vein` is fully deterministic and `_ore_burst` is a pure hash of the cell (`factory_sim.gd:1415`), so
a fixture pinned to column 32 holds fixed every axis the defect could vary over: one column, one burst
pattern, one shaft length. Pinning `deposits = 3` removes the hash — which is right for the arithmetic and
*also* removes an axis, so it must be replaced by variation the rung chooses deliberately.

**The screen:** run it on the three corpus seeds (1337/512/7) **and at two columns** — one either side of
the fixture band, e.g. 32 and 64 — and **diff the sets of readings, not their counts**. Two runs that both
report "2 trips" can differ in where the cap bound, how much spilled and how many frames each trip took.
Record the members.

A second, subtler axis: `_bury_vein` starts its column at the constant row 20 regardless of the column's
generated ground row. On the plateau (cols 30-66) those coincide; off it they do not, and the realised
earth count would silently differ from 11. **Assert the realised earth count** rather than assuming it —
the rung should read back how many earth units entered the pack and compare with `depth - ore_rows + 1`.

### 4.4 The retry throws away the sample

`_attempt` (`play_tests.gd:121-135`) runs each goal up to `TRIES = 3` times (`:119`) on a fresh scene, and
prints the friction line only from whichever try the goal itself prints it in. For a pass/fail rung that is
correct flake handling. **For a measurement rung it means a reading can be silently replaced by a second
draw**, and the printed number is the surviving one, with no record that an earlier attempt read
differently.

**The screen:** the rung must print its full pain line on **every** try, tagged with the try index, before
`_finish` (`play_tests.gd:1793-1798`) tears the agent down. If try 1 and try 2 disagree by more than
run-to-run variance, that disagreement is the finding.

### 4.5 A trip counter that counts the fixture

If `trips` were computed as `ceil(ore / cap)` it would be arithmetic wearing a counter's clothes: it would
report the correct-looking number on a run where the body never moved, and it would agree with the
prediction by construction.

**The screen:** `trips` increments on an **observed** event — a delivery actually landing, i.e.
`sim.machines[0].input_buffer` (or the surface pile) growing after a `deposit_selected` — and the
prediction is printed as a **separate** number derived from the fixture. The rung asserts on the observed
one and prints both. A third check for free: the per-trip payloads must sum to the ore actually delivered.

### 4.6 The grant is not a capped acquisition

`give` writes `sim.inventory` directly (`play_agent.gd:801-802`) and never consults `can_carry`
(`factory_sim.gd:1752`). A rung whose grants already exceeded 90 would start above the cap; every
subsequent take would spill, `peak_bulk` would read whatever the grant was, and the row would report a
bound cap that was never crossed in play.

**The screen:** assert `sim.carried_bulk() < FactorySim.PACK_BULK_CAP` immediately after the grants and
before the first strike. In configuration A that reads 20 against 90.

### 4.7 Two mechanical hazards worth pre-empting

Not "the reading is a lie" but "the rung fails for a reason that is not the subject":

- **A pack full of ore cannot pillar.** `_select_block` (`play_agent.gd:312-326`) holds `ore` back via
  `KEEP` (`:309-310`), and its fallback takes only non-`KEEP` bulk. A full ore pack with no earth left
  would hit the "out of blocks" note at `:674-681`. The 25-rope grant means strategy 1 (`:625-630`) runs
  and the pillar path is not reached — **rope is not bulk** (`is_bulk_item`, `factory_sim.gd:1722-1731`,
  exempts anything resolving to a def under `MACHINE_DEF_DIR`, which the comment at `:1729` says includes
  rope), so a full pack still has its rope. Keep the 25-rope grant; do not "simplify" it away.
- **The spill pile follows the digger down.** `_spill_to_world` (`factory_sim.gd:1791-1795`) routes through
  `_column_landing` (`:2872`) to the first solid below, which during a top-down dig is the next un-mined
  ore cell. The body then stands beside it and `_collect_ground_under_player` (`scenes/main.gd:2189-2207`,
  reach `COLLECT_REACH_CELLS = 2.5` at `:2129`, gated on `Settings.auto_pickup`, default true at
  `scenes/settings.gd:25`) tries to scoop it — but `collect_ground` respects the cap
  (`factory_sim.gd:2957-2962`: "THE CAP APPLIES TO PICKING UP TOO"), so a full pack takes 0 and the pile
  stays. Net: the spill cascades ahead of the digger and comes to rest on the stone floor. **The rung must
  therefore locate the piles at the end, not assume they are where they spilled**, and it should assert
  `Settings.auto_pickup` is true rather than inherit it from a config file (`settings.gd:46`), because if
  it is false, trips 2+ collect nothing and the rung measures a stranded player.

---

## 5. The decision the reading would unlock

Read against the acceptance contract in `docs/handoff/T1_0_SINK_DESIGN.md` (points 1-8), which this table
cross-references rather than restates.

| reading | what it implies |
|---|---|
| `peak_bulk = 90`, `trips = 2-3`, `trip_frames` per trip within ~1.6x the deep rung's climb cost | The cap creates **interruption**, which is the designed tax. Contract point 1 is satisfied and the Forge's 2:1 compression is the likely sufficient answer: halving the freight turns 3 trips into 2 and the loop stays a trip. Build nothing new; place the Forge and re-measure. |
| `peak_bulk = 90` but `trips >= 5` | The face is being drained a spill-pile at a time. `factory_sim.gd:219` puts cap 65 at five trips and `:220-221` calls that an overshoot of the 2-4 band, so five trips at cap 90 means the effective cap is far below its nominal value. 2:1 compression cannot recover a band that far out. **The trunk needs a full sink**, and the design work T1.1 is parked for becomes live. |
| `trip_frames` per trip is dominated by the **re-descent** rather than the carry | The cost is vertical transit, not capacity. A sink of any strength does not touch it; the answer is the lift/winch. Contract point 5 (lateral relocation) is then the wrong axis to be optimising, and the sink question should be deferred behind the Winch rather than answered. |
| `spilled > 0` and the piles rest in the shaft column on the player's return path | Contract point 2 fails against the trunk **as it currently stands** — this is the `_column_landing` outcome-two case the sink document opens on. Whichever consumer is chosen must stand **in** the column, not beside it, and that is a placement constraint on the recommendation, not a new mechanic. |
| `peak_bulk = 90`, `trips = 2`, but payload fraction below ~0.6 | The cap is being spent on spoil and kit rather than freight (configuration A predicts exactly this: 59 ore in a 90 pack). A sink that consumes **ore** cannot help the other 34%. The lever is the spoil — backfill, or exempting dug rock from `is_bulk_item` — which is outside the sink's scope and must not be smuggled into it. Contract point 3's ratio should then be stated over freight, not over bulk. |
| `peak_bulk < 90` on any corpus seed | **The instrument, not the game.** Something in §4 fired. Go back to §1 and re-derive the arithmetic for that seed before any of the rows above may be read. |
| `peak_bulk > 90` on any run | A live path into the pack bypasses `can_carry`. That is a sim finding that outranks T1.0 entirely, and it retires the "the cap is live and gates the player verbs" premise the row currently rests on (`docs/PRIORITY.md:370`). |

**What the reading does not decide.** None of the rows above chooses between the Forge mouth and the
collection basin; that comparison is `T1_0_SINK_DESIGN.md`'s and turns on criteria this instrument cannot
see (contract points 4, 6 and 8 — legibility, depletion and recoverability). This rung decides only how
much sink is needed, not which one.
