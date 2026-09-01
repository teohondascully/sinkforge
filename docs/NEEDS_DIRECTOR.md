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

**Closed 2026-08-30 by the merge and the ruling that followed it:** **P012** (the three stacked PRs merged as one arc; gate 7 judged the whole trajectory at +742/+717 and passed on its merits, with no override — D0250). **P018** (gate 7's window now counts only commits that TOUCHED either population, so documentation stops moving a verdict it contributes nothing to — D0251, mutation-tested with an instrument-only window that must still FAIL).

**Closed 2026-08-30 by the coordinator rebuild, ruled and applied:** P011 (the painter contract — all five questions answered; `Seams` to `core/` is D0237, the two L2 doors are D0238, the skeleton is D0240, Phase 2 is confirmed as `sky_painter` + `terrain_painter`, and the day/night clock is pinned). **P013** (view/ may read appearance data; `data` is a modelled layer now and the edge is enforced with a laundering guard rather than merely permitted — D0243).

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

## P007 · CLOSED 2026-08-31 by D0261 · The determinism suite is 93% string-building, and the fix touches the determinism contract

**CLOSED.** Measured at 91% (65.7s of 72s), fixed by an O(1) running hash, 72s -> 8.8s. The contract
concern this entry raised is answered by `recomputed_signature()` plus a mutation test on all four paths.
The separate aliasing question about sharing a carved grid is still open and is NOT this entry -- it is
referenced by D0267, which sidesteps it by cloning.

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
the workflow and reads the `tests` job's own steps (38 suites) instead of grepping the file for
`res://tests/test_*.gd` (39, the extra being the schedule-only 1.5M-tick sweep). What remains here is
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

**Update, 2026-08-30 (D0234): `art.gd` now has a known consumer.** Phase 0's dependency scan finds
`terrain_painter.gd` calling `Art.tex`, so the file stops being consumerless in Phase 2. That is evidence
on `art.gd`'s side of the question below; it says nothing about `light_layer.gd`, whose lighting math is
still in the parked coordinator.

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

---

## P014 · `core/MODULE.md` is at exactly its 100-line cap, so the next class added to `core/` is blocked

**Status:** open · **Cost to apply:** a number, or a restructure · **Raised by:** this session,
2026-08-30 (D0237)

Two of your rulings collided, quietly and cheaply, and this is the record of how it was resolved.

P006 set the `MODULE.md` cap at 100 (D0226) when `core/MODULE.md` was at **98** — a margin that ledger
entry noted at the time. This run's Q3 ruling moved `Seams` into `core/`, and documenting a fifth public
class does not fit in two lines.

**Resolved by writing less, not by moving the cap.** I removed one genuine duplication (the D0097
extraction story appeared nearly verbatim in both the `BitOps` API entry and its Gotcha) and wrote the
`Seams` entry as a pointer, with its full rationale in `core/seams.gd`'s own header where a reader of
that file will actually meet it. The file is now at **exactly 100**.

**Which is the shape `docs/QUALITY.md` §2 warns about** — `sim/body/body.gd` sat at exactly 400 for
three commits because it was trimmed rather than split — so it is debt, not comfort. **The next public
class added to `core/` forces this open again**, with no duplication left to reclaim. Worth a number now
rather than a scramble then; 120 would restore roughly the headroom 100 was meant to give.

---

## P015 · sky_painter draws — and every remaining question about it is a look call

**Status:** open, THE ◆ · **Cost to apply:** your eye on two images · **Raised by:** this session,
2026-08-30 (D0244)

`view/visuals/sky_painter.gd` is lifted, wired to the `Frame`, layer-clean, and **drawing**. Run it:

```
open docs/milestones/slice3_horizon_23b0ec4.png docs/milestones/slice3_horizon_sky_23b0ec4.png

# or drive it yourself -- --play IS WHAT OPENS A WINDOW, and without it the scene runs itself for
# ~12 ticks and exits (D0248: this line originally omitted it, and that is how the class was found):
godot --path . tests/body/reveal_scene.tscn -- --play --sky --zoom=6.5 --camera=24,4

SKY=1 bash tools/capture_moments.sh <label>     # or re-capture the whole set
```

The `--zoom`/`--camera` pin is not decoration: the reveal sites spawn the body at row ~13 with the
horizon off the top of the frame, so the default framing shows no sky at all. That is itself one of the
four look calls below.

The pair to compare is `slice3_horizon_<sha>.png` (no backdrop) against `slice3_horizon_sky_<sha>.png`,
same seed, same camera, same tick — the backdrop is the only difference.

**What the suite can and cannot say.** `tests/test_sky_painter.gd` proves the starfield is non-empty (42
of 42 stars clear the horizon), that it scatters (14 distinct x-gaps where legacy's linear form gave
three), that the scale is derived from the world's cell size rather than typed in, and that `paint()`
completes inside a real draw pass. **None of that is a claim that it looks right**, and the difference
matters here more than usual: the first capture of this painter was structurally perfect and visually
blank.

**Four things I noticed and deliberately did not tune**, because tuning them is the judgment this gate
exists for:

1. **The pinned clock's VALUES.** Q5 ruled "pin it", which settles that the sky does not move. It does
   not settle WHICH sky. `DAYLIGHT = 0.35` / `DAY_PHASE = 0.70` is dusk with the moon mid-transit,
   chosen to put the most of the painter in one frame — stars need `dl < 0.85` to draw at all, so full
   day would hide the one feature that proves the scatter. That is a reason to pick a value, not a claim
   that it is the right one. Full night, overcast noon and dawn are all one constant away.
2. **The ridges subtend a large angle.** Proportionally they are close to legacy's (they span ~44% of the
   view height where legacy's spanned ~54%), but this world's camera shows ~111 world px against
   legacy's ~720, so they read as *near* hills crowding the horizon rather than distant ranges. Whether
   that is wrong depends on what you want the surface to feel like.
3. **The Sinkforge crown is anchored at nothing.** `SINKFORGE_ANCHOR_X` is legacy's value scaled; it
   pointed at the centre of legacy's spawn plateau, and this build has no authored surface for it to
   point at. It currently lands near the middle of a 48-cell world by arithmetic, not by placement.
4. **The sky is only visible near the surface**, and the reveal sites spawn the body at row ~13 with the
   horizon off the top of the frame. The `horizon` moment (camera row 4) exists so the backdrop is in
   shot at all. If the surface is going to matter, the default framing probably should too.

**And one thing that is a real question rather than a taste one:** `--sky` is OFF by default. Every
existing milestone shot, replay and suite was taken without it, and a backdrop appearing unasked would
change what those captures mean. Turning it on by default is your call, and it is the difference between
"the sky exists" and "the game has a sky".

---

## P016 · The fuzz bound is 13 above what the sweep now measures, and its sibling counter grew 46%

**Status:** open · **Cost to apply:** a number, or a decision to leave it · **Raised by:** this session,
2026-08-30 (D0247)

Found while retrofitting the empty-population guard into the fuzz suites (D0245), not by looking for it.

**Measured twice, byte-identical, both runs full 1000x1500 sweeps:**

| | recorded | measured 2026-08-30 |
|---|---|---|
| `grounded_no_floor` | **59** — the `DESIGN_TRADEOFF` bound | **46** |
| `bounds` (reported, not gated) | 805,397 | **1,179,015** |
| `embedded` | 1 — the `RESIDUAL` bound | 0 |
| `discontinuity` / `deadlock` / `overflow` | 0 | 0 |

The 59 was calibrated in D0122/D0127/D0128 and appears as 59 in every prior record I can find
(`docs/DECISIONS_LEDGER.md:5362`, `docs/archive/working/WORKING-2026-08-29.md:261`). Nothing is red: 46
is under 59 and 0 is under 1, so the gate passes. **That is the point — a bound 13 above the measurement
is 13 counts of regression it will not catch.**

**Two things I did NOT do, and why.**

I did not ratchet it to 46. D0184 is your own ruling that 59 is *"a cumulative-trajectory count at this
seed ORDER, not an independent-trial resolver rate"* and *"provisional as a regression baseline pending
fuzz restructure"* — a count conditioned on the trajectory can move for reasons that are not regressions,
and tightening it would hand the next session a red CI over an unrelated game change. Ratcheting what
shipping decided is usually right; ratcheting a number you explicitly labelled provisional is your call,
not mine.

I did not diagnose the `bounds` growth. A plausible mechanism is sitting right there — D0184 notes the
1,000 seeds share ONE `TileGrid` built outside the seed loop, so more excavation over one cumulative
trajectory means more ticks spent where the world used to be — and it is plausible enough that asserting
it without measuring would be the exact move this project's ledger is full of corrections for. It is
reported-not-gated, so nothing is blocked either way.

**What you might rule:** (a) ratchet to 46 and accept occasional false reds, (b) leave 59 and record that
it is now slack, (c) do the fuzz restructure D0184 deferred (decorrelate seeds from cumulative
demolition), which makes the number mean what everyone reads it as meaning and is the only option that
fixes the cause rather than the symptom. (c) is a real design cycle, not a Bin A task.

---

## P017 · The world has no sky to jump into — row 0 is the surface, the ceiling, and the horizon at once

**Status:** open · **Cost to apply:** a band-ladder decision, then a regeneration · **Raised by:** the
director in play, 2026-08-30 (D0249)

**Reported from the chair, not from a test:** *"it wont let me jump up beyond the surface. like my head
bumps at the surfaceline and i cant jump higher."* Correct, and it is two things stacked.

**The rock lid is intentional.** D0199 made `carve_entry_shaft` leave row 0 SOLID (`CEILING_ROWS = 1`)
and derived the spawn row from that ceiling, so your head is stopped by rock rather than by the
world-edge clamp. Before it, the shaft was carved from row 0 and the FIRST JUMP of any session put the
body's box at y = -3.4px, outside the world — found in your own `--play` recording. That fix is sound and
is not what to undo.

**What is NOT a decision anyone made is that there is no air above the surface at all.** Row 0 is
simultaneously the surface datum, the top of the `TileGrid`, and `sky_painter.HORIZON_Y`. Legacy had
`SURFACE_ROW = 20` — twenty rows of sky you could rise into. Re-keying the band ladder to metres-below-
surface (`data/bands/topsoil.yaml`, `from_m: 0`) made the ladder scale-free, which was right, and dropped
the headroom on the way, which nobody noticed because nothing above the surface had ever been drawn.

**Measured, not inferred.** `_enforce_grid_bounds` clamps `_top_y() < 0` and zeroes upward velocity.
Jump is 365px/s against 900px/s² — a **74px apex, ~18 rows** at this world's 4px cell. The capability is
already there; the world ends one row above your head.

**Why it lands now.** This is the run that put a sky on the screen. Ridges, stars, a moon arc, and the
Sinkforge crown on the horizon are all drawn into a region the player cannot enter. `docs/GDD.md` §9
rejected Sinkforge-as-consumer partly because it *"is invisible from anywhere the player stands, so it
cannot carry emotional weight"* — legacy's answer was to put it on the horizon, and P015 asks you to
judge how it reads. **A backdrop you can see but never rise toward is a different design object from one
you can leave the ground into**, and which of the two this is decides several of P015's look calls with
it (the ridges' angular size, the crown's anchor, whether `--sky` defaults on).

**What you might rule:** (a) add N rows of air above the surface to the band ladder and regenerate — the
`CEILING_ROWS` lid then sits at the top of the AIR rather than on the player's head, and D0199's
invariant is preserved unchanged; (b) leave it: the game is about going DOWN, the sky is a backdrop, and
headroom is content nobody will use; (c) something between — a few rows, enough that a jump reads as a
jump rather than as a bump.

I did not pick. (a) is cheap mechanically and changes what every existing capture, recording and spawn-row
derivation means, which is exactly the kind of change that is yours.

## P019 · The depth tint is ported and unapplied, because Stonereach slate-blue and glimmer teal are the same hue

**What it is.** `world_renderer.gd:1506-1523 ZONE_TINTS` — legacy's four-entry depth-tint ladder, the thing
that gives the descent "a four-beat colour arc a player can feel without reading a depth gauge": warm
ochre clay, a neutral middle, cold violet at the approach to the seal, slate-blue in Stonereach. It is
ported, converted to metres, sitting in `view/visuals/material_look.gd` as `ZONE_TINTS` + `zone_tinted()`,
and `cell_color()` does not call it (D0252).

**Why it is parked, measured rather than asserted.** It collides with the glimmer-legibility floor that
`tests/test_material_palette.gd` has enforced since D0189 — glimmer must stay >= 0.25 from every host rock
at every depth. Three attempts, all measured over 64 rows x both nugget branches:

| tint applied to | worst glimmer-vs-rock separation |
|---|---|
| everything | **0.061** (vs deepstone at 252 m) |
| country rock only, ore exempt | **0.178** (vs deepstone at 152 m) |
| country rock only, ore exempt from bedding too | **0.216** (vs deepstone at 212 m) |
| **not applied (shipped)** | **0.273** |

No exemption scheme reaches the floor, and the reason is not a bug: at 252 m all four bands clamp at full
and only 32% of a material's own colour survives (`0.78 x 0.84 x 0.74 x 0.66`), and the deepest tint is
Stonereach slate-BLUE `(0.42, 0.55, 0.90)` against glimmer's TEAL `(0.16, 0.52, 0.55)`. They are hue
neighbours. The tint pulls all country rock toward the exact hue the ore already occupies.

**Legacy never hit this**, and that is the whole explanation: glimmer is this build's own material and
legacy had no teal ore. Legacy also had somewhere to put the difference that this grid does not — ore was
drawn as separate untinted crystal polygons OVER the tinted rock (`_draw_lode`, `_draw_grain`), and
legacy's smallest nugget mark is 6.4px, larger than this world's entire 4px terrain cell.

**The call is a colour choice, not an engineering one, which is why it is here.** Three options:

1. **Move glimmer off teal.** Cheapest, and it is a one-line data edit in `data/materials/glimmer.yaml`.
   But glimmer's cyan is itself a measured claim (D0189 kept it "deliberately far from COLOR_TERRAIN's
   brown and COLOR_BG's near-black") and it is the colour of the thing the player is hunting.
2. **Move Stonereach's tint off slate-blue.** Keeps the ore, changes the deepest band's identity. Legacy
   picked blue as the cold end of a warm-to-cold descent, so the arc's shape is at stake, not just a hue.
3. **Ship without the tint.** What is in the tree now. The descent loses its colour arc and keeps only the
   band ladder's announcement colours, which the HUD does not draw yet either.

**What did NOT get resolved by lowering the floor**, and deliberately: the 0.25 is a measured legibility
claim about whether a player can find ore, not a convenience. Landing the tint by relaxing it would have
been the shipped-claim-retired-silently failure this project keeps finding.

## P020 · RULED AND DONE 2026-08-31 by D0258 · The cave field is single-octave where legacy's is five

**One ruling. It unblocks WG-2, WG-3 and PR #10 together.**

Legacy left `FastNoiseLite.fractal_type` at Godot's default. Confirmed by printing it rather than
trusting the plan: `FRACTAL_FBM`, **octaves 5**, lacunarity 2.0, gain 0.5. Corroborated twice inside
legacy itself — `src/core/fine_terrain.gd:102` and `scenes/fine_terrain.gd:488` both explicitly set
`FRACTAL_NONE` *because* the default is 5-octave FBM. `ValueNoise.sample()` is one octave.

**What that costs today, now measured** (`tests/test_shaft_generator.gd`, six seeds):

| partition | carved / eligible | fraction |
|---|---|---|
| shelf bands | **0 / 97,920** | **0.0000** |
| non-shelf | 10,488 / 195,264 | 0.0537 |
| overall | 10,488 / 293,184 | 0.0358 |

against legacy's own stated target of "near 15% of the underground". Shelf bands need 0.65–0.81 to carve
and the calibrated field is hard-bounded to ±0.574 **by construction**, so no seed and no coordinate ever
breaches one. Legacy's shelf was a resistance gradient. Ours is a wall, and nothing said so.

**Why this is yours and not mine.** The port itself is mechanical — five octaves, halving amplitude,
doubling frequency, a different seed per octave, FastNoiseLite's own `fractalBounding` normalisation.
The problem is `FASTNOISELITE_SD_CALIBRATION = 0.574`. It was measured against the *single-octave*
distribution, and a 5-octave field has a different one, so the port forces re-deriving it — and that
constant is what makes **every threshold ported from legacy** clear at the rate it was tuned for. Changing
it moves cave density, shelf permeability and ore exposure at once. That is a threshold move in effect if
not in spelling, and the overnight queue reserves those for you.

**Three ways to go:**

1. **Port the octaves and re-derive the calibration by measurement**, then re-pin the ratchets to whatever
   the numbers turn out to be. Faithful to legacy, biggest blast radius, needs a golden re-capture.
2. **Port the octaves and re-derive the calibration to hold the current carve fraction**, so the field
   gains legacy's character without changing how much rock is removed. Smaller blast radius; declines the
   3.58%-vs-15% question rather than answering it.
3. **Rule that ~3.6% is the game you want** and delete the 15% target as a legacy artefact. Cheapest,
   and WG-2 still needs a separate answer because a shelf that never carves is a bug either way.

I would take (1): the 15% gap and the impermeable shelf are the same defect wearing two faces, and (2)
fixes the face rather than the cause. But it re-rolls every fixture pinned to a generated world — this run
has already re-pinned two of them (D0255, D0256) — so it is worth your explicit yes.

## P021 · CLOSED 2026-08-31 by D0285 · Measured: the thresholds are right and "15%" was never a measurement

**P020 is DONE and this is what it did not fix.** Porting legacy's 5 octaves and re-deriving the
calibration by measurement (D0258) made the shelf permeable — 0 → 15 cells of 97,920 — and moved overall
carve **0.0358 → 0.0329**. It went slightly *down*, not up to legacy's stated "near 15% of the
underground".

**That is the correct outcome, and it means the 15% figure was never a noise-field problem.** The field
now matches FastNoiseLite's crossing rates at legacy's own thresholds — 0.31 at 0.1157 vs 0.1214, 0.47 at
0.0230 vs 0.0276, 0.65 at 0.0021 vs 0.0012. The field is right. So if legacy really carved 15%, the
difference is in the thresholds, the depth lerp, or in what "15%" counted — cave carving alone, or cave
plus ruins plus chambers plus entry shafts.

**Three candidates, and I cannot pick between them without your ruling** because every one is a threshold
move, which the queue reserves for you:

1. **The thresholds are cell-denominated too (WG-4's sibling).** `threshold_top 0.47` / `threshold_deep
   0.31` came over verbatim. If legacy's 15% was measured at one-cell-per-metre, our 4x-finer grid
   changes what fraction those numbers select. This is the explanation I find most likely and it merges
   with WG-4 rather than competing with it.
2. **"Near 15%" counted more than cave carving.** Ruins, chambers and the entry shaft all excavate. If
   legacy's figure was total void rather than cave void, 3.3% cave + everything else may already be it,
   and there is nothing to fix.
3. **The number is legacy's aspiration, not its measurement.** It appears in a comment. `range-read-as-
   observations` applies: I have not found the measurement behind it in legacy's own source.

**My recommendation: rule (2)/(3) first by measuring, not by moving thresholds.** Before touching a
single constant, the cheap decision-free step is to instrument TOTAL void fraction (caves + ruins +
chambers + shafts) and compare that against 15%. If it lands near 15%, this item closes with no threshold
move at all. I will run that measurement in the decision-free lane and report it — but the *remedy*, if
one is needed, is yours.

**Nothing is blocked on this.** WG-2 and WG-3 are closed, PR #10 is unblocked on its merits.

## P022 · RULED AND LANDED 2026-08-31 by D0269 · The miner's head is 8px inside the ceiling

**You spotted this in the D0268 capture. It is real, it is measured, and the placement code is not the
cause.** Probed directly: the sprite's bottom edge and horizontal centre land on the body's AABB to
**0.00 px on both axes**. The sprite is exactly where the red rectangle was.

The defect is vertical clearance:

```
body top = 8.0   bottom = 48.0     ceiling (first solid above) = 8.0
HEADROOM above the body            = 0.0 px
sprite is 48 px tall vs a 40 px body, feet on the AABB bottom
=> the top 8 px of helmet and pickaxe sits INSIDE solid rock, on every frame
```

At `--zoom=6.5` that is ~52 screen pixels of miner buried in the ceiling, which is why it reads as
"not even in the right spot".

**Legacy had the same overhang and it did not show.** Legacy's body was 14x34 with 32x48 art — a **14 px**
overhang, worse than our 8. What differed is the world: legacy's `CELL` was **32 px**, so any dug tunnel
had a full cell of headroom. Our terrain cell is 4 px and the dig carves exactly body height, leaving
**zero**. The art was sized to legacy's tunnel, not to legacy's body.

**This also means `docs/LEGACY_GAP.md`'s own recommendation makes it worse.** That doc proposes re-baking
`H: 48 -> 56` to keep the art proportional to our taller 40 px body. Proportionally right, and it takes
the overhang from 8 px to 16 px.

**Three ways out, and all three are yours:**

1. **Carve headroom.** Give the dig one terrain cell (4 px) or two of clearance above the body. Fixes it
   for every future sprite too, and is closest to what legacy actually did. It is a `sim/` change to dig
   extents and re-pins the world, so it is a threshold move by another name.
2. **Re-bake the miner at 40 px tall** via `legacy/tools/bake_miner.gd`, which composes all 15 frames from
   ASCII tables against a 19-entry palette — a two-constant edit and a re-run, not a repaint. Changes the
   character's proportions, which is a look call.
3. **Accept it.** A miner whose hat brushes the ceiling in a hand-dug tunnel is arguably correct, and
   nobody would question it in a wider chamber.

**I recommend (1).** It is the difference that actually exists between the two builds, it fixes every
sprite rather than this one, and (2) spends art work compensating for a world that is too tight.

**Meanwhile the port is landed and green** — `MinerLook` is tested, the state table is exhaustive over the
keys it emits, and the rectangle fallback survives. This is a placement question, not a port defect.


---

## P023 · Every milestone capture mints a binding session recording

**Status:** open · **Cost to apply:** one sentence, or a two-line change · **Raised by:** this session,
2026-08-31, while capturing D0271's HUD.

`tests/body/reveal_scene.gd`'s screenshot path calls `_flush_recording()` before it quits. So a
`--screenshot-out` run — whose entire purpose is a PNG — also writes a session log into
`tests/body/recordings/`. Eight capture attempts while tuning the HUD shot produced **eight** of them in
two minutes.

**Why that is your call and not mine.** `docs/NEEDS_DIRECTOR.md` P002 / D0228 says **every director
recording is binding until retired**, and `tests/test_recorded_sessions.gd` enforces it. Whether an
agent-mode capture's incidental log counts as one of those is a question about what the recording
corpus is FOR, which is the thing that rule protects. I deleted the eight from this session — verified
by mtime as my own, all within two minutes of my capture loop, none older than the newest tracked
recording — but I am not changing the behaviour or touching anything already committed.

**What I would do:** make the flush conditional on the run having been a real session — `--play`, or
agent-drive without `--screenshot-out`. A capture is not a play session, and a corpus that fills with
throwaway 13-tick agent runs makes "binding until retired" mean less every time someone takes a
screenshot.

**What it would cost to leave:** nothing today. The count grows by one per capture, and the corpus's
signal-to-noise falls slowly enough that nobody notices until a `test_recorded_sessions` failure points
at a log nobody meant to keep.


---

## P024 · The hollow ring needs a SWING, and this build only has a hold

**Status:** open · **Cost to apply:** one ruling, then ~1 hour · **Raised by:** this session, 2026-08-31
(D0274, closing the rest of `docs/LEGACY_GAP.md` PRE-3).

PRE-3 asked for two things beyond the plumbing: the hollow reading as an **int** rather than a boolean,
and a **swing edge**. The first landed. The second cannot, without a decision from you.

**Why.** Legacy fires the ring once per BLOW — a discrete swing of the pick — and the repetition is what
makes the tell rise rather than flip. This build has no blow. `Mining.mine()` is a per-tick hold:
`charging_cell` advances every one of the 60 ticks a second you hold the button, and the only discrete
event in the whole verb is the break at the end. Firing the ring on every charging tick would be 60
rings a second; firing it only on the break gives one note where legacy gives a crescendo.

**The three candidates, with what each costs.**

1. **A fixed swing period** — the pick lands every N ticks while held; the ring, the dust and (later) the
   swing pose all fire on that edge. Simplest, and it gives mining an audible tempo it currently lacks.
   Cost: N is a feel number nobody has played against yet.
2. **Rhythm-driven period** — `Mining._rhythm` already exists and already makes consecutive breaks
   faster. Deriving the swing period from it means the pick visibly speeds up as you get into a groove,
   which is the mechanic the rhythm system was ported for and which currently has **no outward sign at
   all**. Cost: more moving parts, and the period becomes a function rather than a constant.
3. **Charge-fraction edges** — fire at each 1/N of the way to a break. The number of swings per cell is
   then constant regardless of hardness, so hard rock swings slower, which is arguably the most physical.
   Cost: the edge count is fixed by the fraction, not by time, so a very fast break fires them all at once.

**My recommendation: (2), rhythm-driven.** The rhythm system is already ported, already tested, and
currently affects nothing the player can see or hear — this would be its first outward expression, and
"the pick speeds up as you find a groove" is a feel the other two cannot produce. If that reads as too
much for a first pass, (1) with the period later replaced by (2) is a clean sequence, because both put
the edge in the same place.

**What it blocks:** `docs/LEGACY_GAP.md` T1 #6 (the hollow ring + breach + draught) in its ported form.
The magnitude and the breach flag are both available now, so a build that rings only on the BREAK is
possible today without this ruling — it would just be a flag that flips, which is the thing legacy's own
comment says not to do.


---

## P025 · `Frame.anim_time` is pinned to 0.0, and 28+ backlog rows are inert until it moves

**Status:** open · **Cost to apply:** ~3 lines and one ruling · **Raised by:** this session, 2026-08-31
(hit while porting D0275's cracks; it is `docs/LEGACY_GAP.md` PRE-1, the highest-leverage prerequisite
in the whole document).

`view/world_view.gd:28` — `const ANIM_TIME: float = 0.0`. **You ruled this correctly** (Q5, "pin it"),
and the reasoning was right at the time: this build starts underground, no time system was authored, and
a wall clock in the frame would have been a field nothing could use. It is a `const` rather than a `var`
specifically so "the clock does not advance" is a property of the type.

**What has changed since is that the animated backlog arrived.** Every one of these ports and then sits
frozen: crumble chunks (T1 #5's other half, the part I did NOT land in D0275), the status pulse, working
machine glyphs, the construction overlay, the need bubble, rope sway, payout rise, godrays, glint flares,
the lamp flicker, surface life. `LEGACY_GAP` counts 28+ rows. Each would be lifted, be correct, and show
nothing — which is `view/visuals/art.gd` again: shipped, tested, referenced by nothing for four sessions.

**The three candidates.**

1. **A cosmetic tick counter.** `anim_time` becomes the render tick count / 60.0. Monotonic, deterministic
   given a tick count, and it cannot desync from the sim because it IS the sim's clock. Captures stay
   comparable if the capture pins the tick, which `--screenshot-tick` already does.
2. **A wall clock** (`Time.get_ticks_msec()`). What legacy used. Simplest, and **it breaks screenshot
   comparison**: two captures of the same tick would differ. Against this project's whole capture
   discipline, so I would not take it.
3. **Depth-driven rather than time-driven.** Your own earlier note on the sky says variation should be
   "depth-driven, not wall-clock-driven". That works for ambience and not for a crumble that must play
   out over 0.24s after a specific event.

**My recommendation: (1), the cosmetic tick counter, and keep the `const`-becomes-`var` narrow** — one
value on `WorldView`, advanced by whoever already calls `refresh()`, with the existing `ANIM_TIME`
retained as the value a test poses. It preserves determinism, preserves capture comparability, and is
the only one of the three that can carry a timed one-shot like crumble.

**What it blocks right now:** the crumble half of T1 #5, which is otherwise ready — the sim already
reports `broke_cells` through the door as of D0274, so the four quadrant chunks over `CRUMBLE_DUR 0.24`
are a straight port the moment there is a clock to run them against.

---

## P026 · `cave.frequency` — the metre-correct answer may be the wrong answer, and it is arithmetic rather than taste

**The one WG-4 constant that is not a mechanical conversion**, held out of Batch A (D0305) on your own
ruling that it is a FEEL target. The arithmetic is not in doubt; what it implies for *this* world is.

Legacy authored `CAVE_FREQ = 0.11` for a **128 m-wide open world**. This build is a **12 m-wide shaft**.
Frequency is 1/length, so the metre-correct value scales the other way: **0.11 → 0.0275**.

**Measured, across 48 columns at `x_stretch 2.1`:**

| | lateral periods across the shaft | vertical periods |
|---|---|---|
| current `0.11` | 2.51 | 112.6 |
| metre-correct `0.0275` | **0.63** | 28.2 |

**At the metre-correct value the entire shaft width sits inside less than ONE noise period.** The field
becomes essentially monotone across x: lateral cave structure disappears completely while vertical
structure stays rich. That is arithmetically right and may still be the wrong number for a world ten
times narrower than the one it was tuned in.

**Three options, and the middle one is mine.**

1. **Take `0.0275`.** Defensible on its own terms — "the player's own shaft is the vertical structure
   now" (D0017) — and it accepts a world with no lateral cave structure at all.
2. **Derive an intermediate from THIS world's width.** Periods scale linearly with frequency, so
   `freq = 0.11 × N / 2.51` for N lateral periods across the shaft. One and a half periods across 12 m
   gives **0.066**; one period gives **0.044**. A stated choice about this world rather than a value
   inherited from a different one.
3. **Leave `0.11`.** Rejected: it is four times too fine in metres, and it is what makes the caves
   fragment into the many small pockets `docs/LEGACY_GAP.md` already describes.

**My recommendation is (2) at N = 1.5, `freq ≈ 0.066`** — enough lateral variation that a cave reads as a
room you can move sideways through, without the 2.5-period churn that fragments them today.

**This is BUILT-PARKED work, not blocked work**: I will build (2), capture it beside the current field,
and put both images in front of you. If you prefer (1) it is a one-line change to the same commit.

---

## P027 · The veil is shipped and half-lit, and the two missing halves are different KINDS of missing

D0302 landed the veil (T1 #2) and D0306 landed the lamp that cuts it. The deep is legible around the
miner now and dark beyond, which is what a lamp does. Two things legacy has that this does not, and they
are not the same kind of gap:

**1. The amber TINT — known remedy, deliberately not guessed.** Legacy's `_veil_cut` lifts each channel
toward `255 × tint`, "so lamp-lit rock comes out amber and lift-lit rock comes out teal through the
multiply, each carrying its own material hue underneath". That needs a light layer with
`BLEND_MODE_MUL`; this build's veil is a black-alpha overlay, so the cut here is a pure luminance
reveal. **The remedy is known and scoped** — change the veil layer's blend mode and draw a colour
instead of an alpha — and it is a rendering change I would rather land on its own commit with a capture
than fold into a port.

**2. `_skylight_alpha` — I do not know where it goes, and I am not going to assert an answer.** Legacy's
constants are `AMBIENT_DARK 0.66`, `SKY_REACH 12`, `SKY_FADE 16`. But **all three of its call sites scale
light SOURCES** (`glint_dark`, the lamp's own `lamp_scale`, `seam_dark`) — none of them is the veil's
base darkness, which comes from `_bake_veil_base`'s tint times the openness multiplier. So "port
`_skylight_alpha` into the veil" is a sentence I can write and cannot currently justify. Reading
`_bake_veil_base`'s colour source properly is the next step, and it is a reading job rather than a
ruling.

**No decision is needed from you on either** unless you want the tint sooner than the reading. Recorded
so the gap is visible rather than implied by a screenshot that is darker than you expected.
