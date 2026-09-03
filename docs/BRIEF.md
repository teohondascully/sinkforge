# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-09-03, third round. A′: steps 0 and 2 done, step 1 ruled, step 3a (the data
leaves) done; step 3b (the world plane verbs) is next.** Ledger: D0343, D0344, D0345, D0346.

**Headline: the hub lift has begun on its leaves — every machine and recipe is now a validated data
record carrying legacy's numbers, `craft_cost` is refused at the gate, and a determinism trap that every
"sort keys" row of the lift would have carried was found and closed before the first runner moved:
`StringName` sorts by pointer, not text.** Earlier today: water on the substrate verbatim (D0344), the
vacuous-green refusal (D0343), and your one-line step 1 ruling (D0345).

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
   reasoning attached rather than silently ignored.

---

## The decisions this round is waiting on

**Step 1: ruled (D0345).** Water at the 4 px grid, §9 stands. Both executor calls approved (20 Hz hub
cadence on every third tick; `BRANCHING.md` main-only). Nothing is waiting on you for steps 3 or 4.

**Plan §8's other rulings:** unchanged — Splitter, Ore Vent, power gating, the Crusher chain,
`press_plate`/`mill_gear`, `earth` 5.6 → 6 ticks, ramps vs `Heightfield`, the resolver (P-28); the 36
untracked recordings (gate 27 red); the `history/` cull. **Standing:** P004, P015/P017, P026–P029,
T001–T004. **Pushed** on your instruction; CI's verdict on the six commits is the next thing to read.

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

**The hub cadence is stated, not made.** It lives in the plan and this brief until step 3's runner lands
with its ledger entry.

**`Ordering`'s baseline test asserts the engine's bug.** If a Godot update makes `StringName <` lexical,
`test_ordering.gd` goes red on purpose so the header gets rewritten rather than the helper deleted. That
is D0115's pattern, and it means one green suite depends on an engine defect persisting.

---

## Blocked, and what it's waiting on

Nothing blocks step 3b (the `sim/world` plane verbs against a temporary owner, where rock placement
starts calling `WaterPlane.displace`) or step 4's water wiring.

## Taste queue

**4 open**, unchanged. T001, T002, T003, T004.
