# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03, tenth round. A′: steps 0 and 2 done, step 1 ruled, step 3a (data leaves),
3b (world planes and verbs), 3c (items), 3d (machines + power), 3e (transport), 3f (the economy's live
remainder), 3g (save v3), 3h (the world seeder) and 3i (the main scene's blocks) done. STEP 3, THE
HUB LIFT, IS COMPLETE, AND SO IS STEP 4, THE DOOR; step 5, the grapple, is next.** Ledger:
D0343–D0357; ADR 0009, ADR 0010.

**Headline: the factory moves.** Items flow between machines every hub tick: down a column by the
landing rule, up it by a lift that pays in power, across a Freight Winch that queues a trip, flies it
for forty ticks and lands it in its Station. A hopper's trickle now arrives in the forge below and the
forge's ingots fall on to the floor. That sits on this morning's machines (a drill that bores, a
generator that lights a milli-unit power field, a pump, a hopper, a forge), all on the metre cell, in
legacy's order, on every third 60 Hz tick, with the item ledger balanced through every buffer and
every trip in flight. One number in yesterday's step was wrong and is corrected: the ore deposit default was written
per 4 px cell at legacy's per-metre value, which would have made a metre sixteen times richer and a
drill sixteen times slower; it is 16 a cell now, 256 a metre against legacy's 250 (D0349). Earlier
today: the metre-cell planes (D0347, ADR 0009), items (D0348), the data leaves (D0346), water (D0344),
the vacuous-green refusal (D0343), your step 1 ruling (D0345).

---

## What landed

- **Step 0 (D0343).** `tests/test_base.gd::_finish` prints `VACUOUS` and exits 1 on zero assertions,
  and `-- N asserted` on every verdict line; `tools/test_test_base.sh` mutation-tests it and was seen
  failing on the pre-fix base first (5 of 7). CI runs it before the suites (gate 28). Full sweep after:
  67/67, 0 VACUOUS. The 15-file harness-protocol transfer is scoped to this piece; the rest port with
  their subjects (the list is in D0343). Probe: legacy's worldgen tallies identical on 48/48 rows,
  macOS arm64 vs Linux x86_64 — **emulated in a container, not native; re-run on CI before quoting.**
- **Step 2 (D0344).** `sim/fluid/water_flow.gd` (legacy line for line), `sim/fluid/water_plane.gd`
  (the owner, 4 px terrain cell, running signature, `displace()`), two invariants with positive
  controls, `tests/test_water_flow.gd` (45 assertions, 3.9 s). The hash mixer moved out of `TileGrid`
  into `core/state_hash.gd`, arithmetic unchanged, outputs pinned in `tests/test_state_hash.gd`; the
  golden did not move. CI 67 → 69 suites.
- **Step 3a (D0346).** `data/machines` (15 LIFT records) and `data/recipes` (6), schema-validated and
  codegen'd, with legacy's per-type constants as integer fields (power in milli, fractions in percent,
  recipe time in 20 Hz ticks, all exact). The validator grew a `forbidden:` rule — `craft_cost` and
  `craft_count` fail with the reason printed — and its first mutation test (8 branches). `MachineDef`,
  `RecipeDef`, `MachineState` in `sim/machines`; `core/ordering.gd` for lexical id order. The population
  is pinned: the four ruling machines and three dead ones are not records. CI 69 → 71 suites.
- **Step 3b (D0347, ADR 0009).** `sim/world/logic_grid.gd` (one `placed` plane, saplings, running
  signature), `world.gd` (the owner; the derivations; `set_solid` displaces water and returns the units),
  `placed_verbs.gd` (legacy's verbs minus the pack), `WaterPlane` moved beside the other planes,
  `check_placed_not_in_rock`, a `soil` flag on materials. 89 assertions. Deferred with reasons: `fill`,
  foliage, `surface_row`/`ramp_dir`, `updraft_at`. CI 71 → 72.
- **Step 3c (D0348).** `sim/items`: the pack and its cap (the two numbers now `data/player/pack.yaml`),
  ground piles and the sink, the landing rule (lifted here, not transport; a machine below via a
  Callable so items never imports machines), `Items` with the ledger, `BuildVerbs` (spend on place,
  recover on removal), the `DepositPlane` as `World`'s fourth plane, `check_item_conservation`. 78
  assertions (recorded as 79 at the time; corrected, D0350). CI 72 → 73.
- **Step 3d (D0349).** `sim/machines`: `Machines` (the registry — placement order is state; the derived
  `power` field; `power_throttle` per-mille is the one cost rule), `PowerFlow` (legacy's pass, milli-int,
  every constant a record field), `Runners` (recipe, generator, hopper, pump, drill), `MachineStatus`,
  `MachineVerbs` (build; pickup salvages, removes, THEN spills — legacy's order fix); `sim/run/hub_tick.gd`
  (`HubTick.step` in legacy's order, `advance` on every third body tick, D0345's cadence made).
  `World.bore_one`/`logic_ore_body` for the drill at the metre; `Items.eject`. 112 assertions. CI 73 → 74.
- **Step 3e (D0350).** `sim/transport/flow.gd` (`Flow`: the flow phase, `column_rise`, `updraft_at`),
  `sim/machines/movers.gd` (the lift by the throttle; the Freight Winch: link, trip, flight, landing,
  station hold, purge on pickup or removal, dead-route fallback), `winch_routes`/`winch_transit` on the
  registry and in the signature, transit counted as present. The splitter waits on your ruling. 58
  assertions. CI 74 → 75.
- **Step 3f (D0351).** `sim/economy/production_rate.gd`: the production-rate ring buffer, the one live
  piece of legacy's economy, as integer centi-items a minute over a 61-sample window; derived, never
  signed; `HubTick` samples it when handed one. 19 assertions. CI 75 → 76.
- **Step 3g (D0352, ADR 0010).** `shell/save_game.gd`: one v3 envelope over every plane, the ledger, the
  registry and the winch tables, staged through public mutators and committed in place; legacy's
  tmp/readback/bak/rename protocol and its four read verdicts; the dangling-winch reconciliation. A
  lived-in world round-trips signature-identical, through memory and through disk, and stays identical
  over 100 ticks on both sides. 45 assertions. CI 76 → 77.
- **Step 3h (D0353).** `data/starts/`: legacy's tutorial opening as a record (fourteen layout constants
  become cells in metres from the spawn; materials and per-cell stocks translated) and an opt-in dev
  kit; `sim/run/world_seeder.gd` generates, wraps, validates and stamps, and hands back the spawn. The
  real `shallow_clay` site takes it. The tree and the tool kit are not carried. 36 assertions. CI 77 → 78.
- **Step 3i, mining half (D0354).** The main scene's mining blocks into `sim/mining`: line of sight
  re-derived in exact integers and pinned against legacy's float walk, the aim snap, the dig plan
  (state), the hand on a lode, and the break's yield on the ledger (a burst a blow, the rest opening as a
  lode, rubble into blocks). Line of sight gates every player-facing path, never the primitive. 48
  assertions. CI 78 → 79.
- **Step 3i, verbs half (D0355).** `sim/run/verbs.gd`: the situated verbs, build and pick up of every
  kind by what the hotbar selects, drop into a machine that wants it or forward or down with a grace,
  scoop within reach, configure, the two-press winch link; one reach rule shared with mining. 40
  assertions. CI 79 → 80. **Step 3 is complete.**
- **Step 4a (D0356).** The door owns the session: every hub plane reaches the observation as a
  window-bounded copy (water, lodes and yields, the placed layers, machine records with status and
  power, piles, the pack, rates, winch tables, the plan, the aim), a MOVE runs the hub on every third
  tick, flow events arrive on a consumed channel, and one signature covers the whole session. 20
  assertions. CI 80 → 81.
- **Step 4b (D0357).** Nine command kinds with details and named reasons; the mine hold rides the move
  frame's aim rather than becoming a second input format; the session saves and loads through the door's services from the shell
  with the body's and the mining state's keys, signature-identical and ticking on; a new game stands
  the body on the seeder's spawn. 34 assertions. CI 81 → 82. **Step 4 is complete.**
- **Plan and state docs** amended under the plan's own compaction contract: status lines per step,
  `BRANCHING.md`'s main-only rule over the plan's "branch per step", the probe is not zero-code,
  step 1 re-framed, the hub's 20 Hz cadence stated for step 3. `WORKING.md` says step 3 is next.

---

## What was learned

1. **I re-opened a decided question.** Step 1's proposal (water on the metre cell) contradicted §9's
   own table, which I had not re-read against the proposal. Screen before asking for a ruling: grep the
   normative docs for the nouns in the question. The tree agreed with §9 too: a 13-cell bite at 4 px
   never aligns to metres.
2. **Legacy's float noise does not diverge across arm64/x86_64** (in the emulated frame). The current
   build's proven crack (gate 8, checkpoint 3) is therefore not "noise diverges"; the suspects narrow to
   libm transcendentals (`cave_passes.gd:86-91`) and the `lerpf`/hash-to-float roundings. Hypothesis.
3. **A gate steered a design, correctly.** The coordinate-naming gate refused the mixer as a `TileGrid`
   method with non-coordinate `Vector2i` parameters; the mixer belonged in `core/`, and moving it also
   shrank `TileGrid` by 99 lines.
4. **A legacy branch was unreachable.** `WaterFlow`'s cap-overflow branch cannot fire through legacy's
   public API (gravity never fills past the cap, `add_water` clamps). Kept verbatim because our owner's
   `set_level` can reach it, and pinned through that door.
5. **The refusal found no live vacuous suite** (0 of 67). Its value is forward: step 3 adds twenty-odd
   suites and every one will have to have asserted something.
6. **`StringName <` is a pointer compare.** `Array[StringName].sort()`, `sort_custom(<)` and
   `keys().sort()` over ids return creation order reversed; a three-key dictionary in the same probe came
   out alphabetical by coincidence. Found because a suite pinned a sorted population and the pin failed —
   a sort claim about ids needs a pin of the actual order, never an `is_sorted` pass. `Ordering.ids` is
   now the one door; nothing in the live tree sorted a `StringName` before today.
7. **A module contract from before the code existed was wrong, and the plan overrides it.**
   `sim/machines/MODULE.md` forbade per-type runners; the approved plan lifts them. Amended with the
   reasoning attached rather than silently ignored. Same shape in `sim/world`: "know nothing of
   machines" became "know no machine TYPE", because occupancy has to be one plane.
8. **A metre cell has three states.** Legacy's `solid.has(cell)` answered every question; over a 4 px
   grid a metre is rock, air, or half-dug, and every lifted consumer has to say which it means. The
   suite pins each on a half-dug metre and the support rule on a half floor. I put the water plane in
   `sim/fluid` yesterday and moved it today: an owner in one module holding a plane in another, whose
   algorithm reads the first, is a cycle — planes live with planes, phases with phases.
9. **The unit-regime rule has a mirror I had not stated.** §3.2 says per-cell RATES convert ×16 to the
   4 px plane (the pump did, D0344). Per-cell STOCKS convert ÷16, or a metre holds sixteen times what
   it did. D0348 carried `DEFAULT_ORE_DEPOSIT = 250` across unchanged; the drill's arithmetic exposed it
   the moment a bore was timed against legacy's. Screen every lifted constant by asking "per what?".
10. **Twelve of thirteen first-run failures in the machines suite were the fixture, not the runner.**
    An unwalled pool leaked sideways out of the pump's reach (water flows in tests too); a coal counted
    twice; gears are bulk; the generator burns then refuels so a lit coal reads 100; the hopper latches
    before it looks for a consumer; and the typed-array cast inside a comparison, for the fourth time.
    Legacy's runners came over and behaved; what had to be learned was legacy's ORDER inside a tick.
11. **The materials and the items no longer share a name.** Legacy's `ore` block yielded `ore`; the
    current world has `ore_iron`, and the recipes take `ore`/`iron`/`rich_ore`. The automated line cannot
    close until a material says what it yields — filed under §8, it is the economy's call (step 7).
12. **A phase that lands later re-writes the tests of the phase before.** Six of 3d's assertions read
    an output buffer that 3e's flow now empties on the same tick. They were true of a world without
    flow and false of the game; re-expressed to read where the items land. A suite written against a
    half-built tick order pins the half, and the header now says so.
13. **A count I wrote from memory was wrong by one.** D0348 and its commit say the items suite has 79
    assertions; the verdict line has said 78 since the file was written. The standing rule is "verify a
    numeric claim against actual tool output" and I did not, for the one number that is easiest to
    verify. Corrected in D0350; every count in this brief was read off a verdict line today.
14. **The terrain signature is blind to walls behind air, by its own rule.** The first capture walked
    occupied cells, dropped every wall behind an open cell, and the round-trip signatures still agreed:
    the instrument that was supposed to catch the loss cannot register that subject (`set_wall`'s comment
    says so). The renderer draws those walls. The save now walks the wall plane itself; the golden's
    blindness to such edits is recorded (D0352), not changed.
15. **Legacy's line of sight was not deterministic at ties.** Its float DDA accumulated `t_max +=
    t_delta`, so a ray through a cell corner was decided by rounding drift, which differs by platform.
    The integer walk decides ties by rule and the oracle comparison excludes them, which is the only
    honest way to pin an exact re-derivation against an inexact original.
16. **Where a gate lives is a design decision the tests encode.** Line of sight inside the mining
    primitive turned sixteen charge-mechanic assertions red on bodies posed in rock. Legacy gated it at
    the verb, never in the sim's `mine()`; the port now does the same, and the primitive keeps its posed
    fixtures.
17. **A runner that counts engine errors as crashes bounds what a durability test may do.** Truncating a
    save file makes `get_var` print an engine-level error, which the masked-crash guard rightly refuses
    to ignore. The test damages the file with a decodable non-envelope instead and says which branch it
    therefore does not exercise.
16. **The transport contract's weakest call answered itself.** Its author could not decide whether
    transport moves items or only prices routes. The lift decided: transport moves buffers the registry
    owns, and the things that fill a buffer are machine behaviours. The dependency now runs
    `transport → machines`, declared, with the old note replaced rather than left as a live question.

---

## The decisions this round is waiting on

**Step 1: ruled (D0345).** Water at the 4 px grid, §9 stands. Both executor calls approved (20 Hz hub
cadence on every third tick; `BRANCHING.md` main-only). Nothing is waiting on you for steps 3 or 4.

**Plan §8's other rulings:** Splitter, Ore Vent, power gating, the Crusher chain, `press_plate`/
`mill_gear`, `earth` 5.6 → 6 ticks, ramps vs `Heightfield`, the resolver (P-28), and new today: the
material-id/item-id map (`ore_iron` yields `ore_iron`; recipes take `ore`); the 36 untracked
recordings (gate 27 red); the `history/` cull. **Standing:** P004, P015/P017, P026–P029, T001–T004.
**CI:** green on every push so far (3c's `e7435707`: all four jobs); 3d's verdict is the next to read.

---

## Anything that felt wrong even though it passed

**The Linux probe frame is emulation.** Rosetta is instruction-exact, but "identical under emulation" is
not "identical on CI". Named as such everywhere it is quoted.

**I wrote a `_check(... or true)` while drafting the water suite** and caught it by reading, not by a
gate. No gate here refuses a constant-true condition; legacy's `check_vacuous_assertions` had two other
shapes, not this one. The asserted-count refusal would not have caught it either — it counts, it does
not read.

**`Invariants._reported` returns `Variant` into typed `report_*` returns.** Legal GDScript, runs green,
but the type system is not checking that path. Chosen to satisfy the duplication gate; a typed pair of
one-line twins would have been clearer.

**`match` where legacy had `call(name)`.** The behaviour table no longer names its runners; a new
behaviour is a `match` arm in two files (run and status) rather than one table row. Chosen because a
static class has no instance to call by name and a `match` cannot name a method that does not exist;
the cost is that the table now lists only flags, and the dispatch is read from the code.

**`head_coverage` is the head alone.** The drill's Spur reach is a one-line stub until Spur is ruled;
the lode-head path is exercised through it, so the ruling changes one function, not the runner.

**The dead-route fallback is pinned by posing a field.** The only live path to "the Station vanished
without a purge" is a save that outlived it, which save v3 will test; until then the suite writes the
route to nowhere by hand. A posed field is a weaker witness than a reached one.

**The lift and the winch take items in text order where legacy took insertion order.** Which item rides
first under a cap is state-affecting, so the sort rule applies; it is a documented deviation, and a
replay of a legacy save would not match here on that detail. Nothing replays legacy saves.

**The opening is legacy's tutorial, verbatim.** It teaches the bootstrap-forge loop of a game whose
economy you retired. It is a data record now, so re-authoring it for the rig is a diff of
`data/starts/`, not code; I did not guess at the new opening.

**Pre-pivot saves are refused, where the plan asked for a migration.** A v2 envelope is a metre-cell
world with dead systems; converting it is a world converter for saves nobody holds. The refusal names
itself and leaves the file. It is a deviation from your plan and sits in §8 for you to overrule.

**The deposit correction moves a number a committed ledger entry stated.** D0348 is append-only and
still says 250; D0349 corrects it with the reasoning. A reader of D0348 alone gets the wrong number.

**`Ordering`'s baseline test asserts the engine's bug.** If a Godot update makes `StringName <` lexical,
`test_ordering.gd` goes red on purpose so the header gets rewritten rather than the helper deleted. That
is D0115's pattern, and it means one green suite depends on an engine defect persisting.

---

## Blocked, and what it's waiting on

Nothing blocks the last of step 3 (the `main.gd` blocks: mining's aim, line of sight, dig plan and lode
cycle into `sim/mining`; the verbs into `sim/commands`) or step 4's wiring of `HubTick.step`, `SaveGame`
and `WorldSeeder` behind `Interface.apply`. The splitter waits on §8.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
