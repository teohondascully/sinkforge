# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03, sixth round. A′: steps 0 and 2 done, step 1 ruled, step 3a (data leaves),
3b (world planes and verbs), 3c (items) and 3d (machines + power) done; step 3e (transport) is next.**
Ledger: D0343–D0349; ADR 0009.

**Headline: machines run on the substrate.** A drill bores ore, burns coal and pours the units down its
column; a generator lights a power field in milli-units that conduits carry down and sideways but never
up; a pump drains only while powered; a hopper tastes, filters and meters; a forge smelts — all on the
metre cell, in legacy's order, on every third 60 Hz tick, with the item ledger balanced through every
buffer. One number in yesterday's step was wrong and is corrected: the ore deposit default was written
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
  recover on removal), the `DepositPlane` as `World`'s fourth plane, `check_item_conservation`. 79
  assertions. CI 72 → 73.
- **Step 3d (D0349).** `sim/machines`: `Machines` (the registry — placement order is state; the derived
  `power` field; `power_throttle` per-mille is the one cost rule), `PowerFlow` (legacy's pass, milli-int,
  every constant a record field), `Runners` (recipe, generator, hopper, pump, drill), `MachineStatus`,
  `MachineVerbs` (build; pickup salvages, removes, THEN spills — legacy's order fix); `sim/run/hub_tick.gd`
  (`HubTick.step` in legacy's order, `advance` on every third body tick, D0345's cadence made).
  `World.bore_one`/`logic_ore_body` for the drill at the metre; `Items.eject`. 112 assertions. CI 73 → 74.
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

**The deposit correction moves a number a committed ledger entry stated.** D0348 is append-only and
still says 250; D0349 corrects it with the reasoning. A reader of D0348 alone gets the wrong number.

**`Ordering`'s baseline test asserts the engine's bug.** If a Godot update makes `StringName <` lexical,
`test_ordering.gd` goes red on purpose so the header gets rewritten rather than the helper deleted. That
is D0115's pattern, and it means one green suite depends on an engine defect persisting.

---

## Blocked, and what it's waiting on

Nothing blocks step 3e (transport: `_flow`, the lift, the winch, `updraft_at`; the splitter waits on §8)
or step 4's wiring of `HubTick.step` behind `Interface.apply`.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
