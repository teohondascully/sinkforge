# Needs director

Things a session stopped on rather than plowed through. **Nothing here has been applied.** Each entry
is a diagnosis plus a proposed remedy, held because the call is a judgment the director owns: a feel
decision, a policy decision, or a trade with no obviously right side.

Created 2026-08-30 for the presentation run. Read this before `docs/WORKING.md` if you are picking the
run up cold — WORKING.md says what happened, this says what is waiting on you.

**How to close one:** rule on it, then delete the entry and record the ruling in
`docs/DECISIONS_LEDGER.md`. An entry that stays here after a ruling is worse than no entry, because
the next session cannot tell a live question from a settled one.

**Closed 2026-08-30 by the gate-hygiene run, ruled and applied:** P002 (the recorded-session replay is
now `tests/test_recorded_sessions.gd` and runs in CI — D0228), P003 (the size gate's two populations are
one — D0225), P005 (the unblocked lifts landed and the batch is genuinely dry — D0227), P006 (the
MODULE.md cap is 100 and enforced — D0226), and P007's two free sub-items (D0229, D0230). Their entries
are deleted per the rule above; the ledger carries the rulings.

---

## P001 · The fast fuzz suite gates 5 of its 7 violation types

**Status:** open · **Cost to apply:** ~20 minutes · **Raised by:** Codex audit, 2026-08-30

`tests/test_body_fuzz_fast.gd` counts seven violation types and asserts hard-zero on five of them.
`bounds` and `floor_selection` are printed and not gated — the suite says so out loud on its own line
52, `"(reported, not gated)"`, so this is a documented choice rather than an oversight. Codex's
reading is still fair: the suite passes while reporting hundreds of bounds violations, and a reader
who sees a green suite does not see that number.

**Why it was left ungated, and why that reasoning only half holds.** Under uniform random input the
body walks into the world edge constantly, and the bounds clamp is the designed recovery — the fuzz
oracle itself grants a bounds tick arbitrary displacement (`fixture_body_fuzz_probe.gd`'s
`_max_legit_displacement`). So the count is expected to be large and has no principled zero. That
argues against a hard-zero assertion. It does **not** argue against a ceiling.

**Proposed remedy: ratchet, do not zero.** The fast sweep is 100 seeds x 500 ticks with a fixed
terrain seed and a fixed input RNG, so its bounds count is *deterministic*, not statistical — the same
commit produces the same number every time. **Measured on this run's tip: `bounds=922`,
`floor_selection=0`.** Pin 922 as a maximum, with that number and the commit that set it written
beside the assertion. A change that makes the body escape the world more often then fails loudly; a
change that reduces it fails too, which is the correct prompt to lower the pin deliberately rather
than let it drift. Evidence it is a real pin and not a coincidence: this run changed the resolver and
the count did not move in the fast window, while the full 1.5M-tick sweep moved by exactly 1
(1,179,016 → 1,179,015).

**Why this is yours and not mine.** A ratchet is a policy: it makes every future change carry the
burden of explaining a number nobody chose on purpose. `docs/QUALITY.md` gate 7 is already one of
those and is already red. Adding a second ratchet without a ruling is how a project acquires gates it
resents.

---

## P004 · The per-commit fuzzer is pointed at a world that poses neither the corner nudge nor the defect

**Status:** open · **Cost to apply:** ~2 hours · **Raised by:** this session, 2026-08-30 (D0213)

Wiring D0213's consent invariant into `fixture_body_fuzz_probe.gd` produced a green that means
nothing, and finding out why produced a fact about the fuzzer worth ruling on.

**Measured, not reasoned.** Over the fast window (100 seeds x 500 ticks = 50,000 ticks) the new
`translation_consent` counter reports **0 with the D0213 defect present and 0 with it fixed**. The
count path is not broken: wiring the same line to `bounds_violation_this_tick` prints **922**. What is
never reached is the *condition*. The same run fires `corner_corrected_this_tick` **0 times** — the
fuzzer does not pose the mechanic at all, never mind the defect in it.

**The cause is the world, not the input.** `fixture_shaft_replay_probe.gd` runs the identical goalless
driver over 20,000 ticks of a **generated shaft** and hits the unconsented case **twice** (`corner_ok=18,
corner_unconsented=2` with the defect; `11` and `0` with the gate). A shaft is walls, every wall contact
depenetrates and zeroes `vel_x`, and a ceiling is always overhead — so the precondition is common there
and rare in the open `HostileChamber` the fuzzer runs in. `docs/DECISIONS_LEDGER.md` D0055 already
recorded that the chamber's one hand-placed corner tile stopped being reached once the held-jump bug it
had been fitted against was fixed; nobody re-placed it, and nothing has exercised corner correction in
this fixture since.

**Proposed remedy, and it is cheaper than the one this entry first proposed.** Not a new input
distribution — a second *world*. Run the existing fuzz driver against `ShaftGenerator` output as an
additional seed band, reusing `fixture_shaft_replay_probe.gd`'s own construction. The input generator,
the violation types and the determinism all stay exactly as they are; only the geometry the body is
dropped into changes, and the geometry is the thing that was missing.

**The corner mechanic is not the only thing the per-commit fuzzer barely poses — it excavates once in
50,000 ticks.** Counted with `body.dig_event_this_tick` inside the probe's own loop, at the
configurations that actually ship (D0223; an earlier six-seed sample read as "never" and is corrected
there):

| configuration | ticks | `dig_pressed` | dig events | rate |
|---|---|---|---|---|
| 100 x 500 — **gate 26, per commit** | 50,000 | 25,261 | **1** | 1 per 25,261 |
| 498 x 1500 — gate 29, D0122 regression | 747,000 | 372,959 | **107** | 1 per 3,486 |

`FuzzDriverCommon.random_input` rolls `dig_pressed` true on about half of all ticks; almost none of
those presses land on anything. **The per-commit fuzzer's total mining exposure is one excavation.** It
is not blind to dig by construction, but nothing dig-caused is meaningfully gated per commit — only
gate 29 and the nightly sweep have real exposure, and D0127's full-sweep A/B (`bounds` **805,397**
dig-on against **18,157** dig-off) shows how large the effect is once there *is* exposure.

**And the seeds are not independent.** The grid is built once *outside* the seed loop
(`fixture_body_fuzz_probe.gd:171`) and every seed shares that one object. Printing its solid-cell count
at each seed's entry over the real per-commit window:

```
TEMP_SOLID_CHANGED at entry to seed=0  solid=1285 (was -1)
TEMP_SOLID_CHANGED at entry to seed=46 solid=1284 (was 1285)
```

Seed 45 digs one cell at tick 349, and **seeds 46-99 run against a different world than they would run
against alone.** So `--seeds=N` is already order-dependent: a seed reproduced in isolation does not
match its own behaviour inside the full run, and sharding the sweep would not be exact (P007).

**A note for whoever reads a `--no-dig` result.** At 100 x 500 the flag reports **922 violations dig-on
and 922 dig-off** — one excavation moves nothing. The control is real (D0127 used it at full-sweep scale
to attribute an 805,397/18,157 split) but its domain at the per-commit scale is a single event, so a null
from it there carries no information about dig.

**Why this is yours.** It roughly doubles the nightly sweep, which is already the longest job in the
harness, and it introduces a second population whose numbers are not comparable with the first — a
permanent complication to every "the fuzzer says N" statement made afterward. It also raises a question
nobody has answered: whether `HostileChamber` should be *repaired* instead (its corner tile has been
unreachable since D0055, so it is carrying a feature it no longer tests), which is a fixture-design call
rather than a harness-throughput one. The dig measurement above sharpens that question rather than
answering it: the chamber now demonstrably fails to pose *two* mechanics, which is an argument for
replacing it and an argument for repairing it in equal measure.

---

## P007 · The determinism suite is 93% string-building, and the fix touches the determinism contract

**Status:** open · **Cost to apply:** ~2 hours + a golden re-capture · **Raised by:** a measurement pass, 2026-08-30

The per-commit suite takes ~307s locally. Where it goes, timed per suite:

| suite | time | share |
|---|---|---|
| `test_body_fuzz_regression_d0122` | 120.0s | 39% |
| `test_reveal_spawn_bounds` | 82.6s | 27% |
| `test_shaft_replay_determinism` | 74.4s | 24% |
| the other 31 | 30.1s | 10% |

**Only one of those three is sim-bound.** Benchmarked inside the determinism suite's own world:

```
world gen                  :    149.9 ms
20,000 body ticks          :   1650.0 ms   (12,121 ticks/sec)
200 grid.state_signature() :  23357.6 ms   (116.79 ms each)
200 body.state_signature() :      0.2 ms
```

`TileGrid.state_signature()` formats one string per occupied cell and joins them — 46,805 cells x 200
checkpoints x 3 processes is **28 million string formats to checkpoint 60,000 ticks.** The simulation is
7% of that suite; the rest is building strings to hash.

**Proposed remedy: a running hash**, updated in `set_material` / `excavate` /
`extend_terrain_dig_extent`, making `state_signature()` O(1). Takes the suite from ~74s to ~5s.

**Why this is yours and not a session's.** `state_signature()` **is** the determinism contract — gate 8,
the golden array, the cross-process replay and every "byte-identical" claim in the ledger all rest on it.
Making it cheaper must not make it weaker, and "weaker" here is subtle: a running hash must be updated on
every mutation path, and a path that forgets to update it produces a signature that agrees when the
worlds differ, which is the exact failure this project's own house class is about. It also costs a golden
re-capture from CI Linux. Worth doing, and worth doing deliberately.

**Its two sub-items are DONE and are not waiting on you** (D0229, D0230). The read-only worldgen
passes in `test_reveal_spawn_bounds` are merged -- **the suite went 81.1s -> 61.3s, measured, against a
predicted ~19s** -- and the local-battery trap is closed by `tools/run_local_battery.sh`, which parses
the workflow and reads the `tests` job's own steps (37 suites) instead of grepping the file for
`res://tests/test_*.gd` (38, the extra being the schedule-only 1.5M-tick sweep). What remains here is
only the running-hash change to `state_signature()`, which is the determinism contract itself.

**The aliasing half stays parked and the reason is unchanged:** sharing one CARVED grid between the walk
and jump tests would save another ~19s and rests on "neither run mutates the grid" holding forever, in
the suite that guards bounds violations. That is the house failure class with a fuse in it.

---

## P008 · The layer lint sees `class_name` edges now, but cannot judge 14 of them

**Status:** open · **Cost to apply:** ~1 hour, or one sentence · **Raised by:** this session, 2026-08-30 (D0224)

`layer_lint.py` had never evaluated a dependency edge — 38 now resolve where 0 did, and **no layer
direction is violated**. That half is done and plant-proven. This is the half that could not be answered
without you.

`docs/ARCHITECTURE.md` §3 says "no module imports a sibling's internal files. Each module exposes exactly
one public interface file", and the path-based rule reads that as `sim/<module>/<module>.gd`. **The tree
does not follow that convention.** Applying the rule to `class_name` edges reports **14 violations that
are all ordinary structure**:

```
sim/body/*.gd, sim/mining/*.gd, sim/invariants, sim/terrain_gen, interface/  ->  TileGrid  (11 edges)
sim/mining/*.gd                                                             ->  Heightfield (2)
sim/mining/mining.gd -> WorldMaterials      sim/commands/command.gd -> InputFrame
```

`sim/world` publishes `TileGrid` from `tile_grid.gd` and `WorldMaterials` from `materials.gd`, and there
is no `world.gd` at all. So the rule as written is either violated everywhere or means something other
than what the filename convention says.

**Three ways to answer, and the choice is yours.**

1. **Declare the public surface per module** — a `PUBLIC` list in each `MODULE.md`, or a `## public`
   marker on the `class_name` line — and check `class_name` edges against that. Most faithful to the
   rule's intent; costs a decision per module about what is public.
2. **Say the convention is "one public FILE per module" and rename** so `sim/world/world.gd` exists and
   re-exports. Faithful to the letter; a lot of churn for a naming rule.
3. **Amend §3** to say a module's public surface is its `class_name` globals, and drop the sibling rule
   for `class_name` edges permanently. Cheapest, and honest about what the code already does.

Until then the exemption is **printed on every run** (`14 class_name edge(s) cross a sim module boundary
and are NOT checked for reach-in`) rather than described only here, so nobody reads the PASS as wider
than it is.

**One thing worth knowing before you weigh this.** `view/` currently has **zero outgoing `class_name`
edges** — `score.gd`, `particles.gd`, `controls.gd`, `art.gd` and `light_layer.gd` reference no sim,
interface or core type at all. "View is layer-clean" is therefore true in the strongest possible sense
and *also* the case the fixed lint has never had to discriminate on real code; only the planted violation
exercised it. The first view file that reads an `Observation` will be the real test.

---

## P009 · `light_layer.gd` was lifted, and it may contradict the ruling that lifted it

**Status:** open · **Cost to apply:** one sentence · **Raised by:** this session, 2026-08-30 (D0227)

P005 option 1 named `light_layer.gd` in the liftable set and it landed. But the same brief declined
option 2 — the ~394 one-hop files — on the grounds that they are **banked value theming a UI that does
not exist**. `light_layer.gd` is the same shape:

- It is 25 lines of canvas + blend mode + a painter `Callable`. Its own header, and the migration map's
  `[REASON CORRECTED]` row, both say lifting it gets **the canvas, not the lighting**.
- The lighting math lives in the coordinator, which is **parked**.
- This build draws in ONE flat `_draw` on one CanvasItem with **no blend modes anywhere**, and
  `tests/body/material_look.gd` states outright that the shadow veil "is not in Slice 0".

So it is banked against parked work, which is the criterion option 2 was declined by. **The two decisions
ought to agree and only you can say which way.** Landed as instructed rather than quietly skipped; it is
25 lines and `git rm` closes it if the answer is that option 2's reasoning applies here too.

`art.gd` (26 lines) is a weaker case of the same thing — it points at an `assets/` directory this tree
does not have — but it differs in a way that may matter to you: it is the **seam the art pass lands
through**, and its empty state is a designed behaviour (`has_any()` false keeps every renderer on its
code-drawn path) rather than a dependency on unbuilt code.

---

## P010 · The merge button is now load-bearing: rebase, never merge or squash

**Status:** open as an OPERATING RULE, not a task · **Raised by:** this session, 2026-08-30 (D0231)

Branch protection made `authorship` a required check, and the first PR failed it on a clean history:
**2 distinct committer identities**, the second being `noreply@github.com`. That is GitHub's own
synthetic `refs/pull/N/merge` commit, and the job now pins to the PR's real head, which fixes the PR
case.

**What is not fixed, and cannot be fixed in the gate:** a **merge commit** or a **squash commit** created
through GitHub's UI is also committed as `noreply@github.com`. Either one puts that identity
**permanently into `main`**, and `check_trailers.sh` reads `git log --all`, so authorship would fail on
**every commit afterwards** — with no remedy short of a history rewrite, which this project has already
paid for once.

**So: merge by REBASE.** It replays the commits under the merging account's identity and keeps `main`
linear, which is what `docs/BRANCHING.md` already describes. Recorded rather than "fixed" by relaxing the
committer assertion, because relaxing it is precisely the change that would let a real vendor trailer
through later.

The ruling you may want to make instead: disable merge-commit and squash-merge in the repository
settings, so the constraint is enforced by the button rather than by remembering.
