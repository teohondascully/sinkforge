# Needs director

Things a session stopped on rather than plowed through. **Nothing here has been applied.** Each entry
is a diagnosis plus a proposed remedy, held because the call is a judgment the director owns: a feel
decision, a policy decision, or a trade with no obviously right side.

Created 2026-08-30 for the presentation run, which was briefed to park rather than decide. Read this
before `docs/WORKING.md` if you are picking the run up cold — WORKING.md says what happened, this says
what is waiting on you.

**How to close one:** rule on it, then delete the entry and record the ruling in
`docs/DECISIONS_LEDGER.md`. An entry that stays here after a ruling is worse than no entry, because
the next session cannot tell a live question from a settled one.

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

## P002 · The recorded-session replay is scratch, not a test

**Status:** open · **Cost to apply:** ~1 hour · **Raised by:** Codex audit, 2026-08-30

Four of the director's own play sessions are committed under `tests/body/recordings/`, and the thing
that replays them and checks them — `tools/scratch/trace_lift.gd` — is gitignored. It has caught
three real defects (D0209, D0212, D0213's verification) and it runs nowhere. Every claim made from it,
including this run's, rests on a session having chosen to run it by hand.

**Proposed remedy.** Promote it to `tests/test_recorded_sessions.gd`: replay every
`tests/body/recordings/play_*.log`, assert 0 bad ticks, 0 airborne climbs, and 0 unconsented corner
nudges per session. About 7,000 ticks total across the four, so it costs a second or two. Two things
it has to carry over, both learned the hard way: the air-control ratio comes from the log's own header
and never from the current default, and `chamber=` is only believable in a log that also carries
`air_control=` (one commit introduced both, so the co-field is the evidence the first was measured
rather than hardcoded).

**Why this is yours.** It makes every recording the director makes into a **binding regression test**.
That is exactly what you want while the body is frozen, and exactly what you do not want the first
time a deliberate feel change legitimately invalidates an old session — at which point the suite fails
for the right reason and someone has to decide whether the recording or the game is wrong. That policy
("a recording is binding until the director retires it") is the ruling, not the code.

---

## P003 · Local and CI runs of the size gate measure different populations

**Status:** open · **Cost to apply:** ~10 minutes · **Raised by:** this session, 2026-08-30

`tools/layer_lint/gd_scan.py::gd_files_excluding` enumerates with `root.rglob("*.gd")` and denies only
top-level `legacy/` and dotted directories. Git's ignore rules are never consulted. So
`check_size_limits.py` lints every gitignored `.gd` under `tools/scratch/` on a developer's machine and
lints none of them in CI, where a fresh checkout has no scratch directory at all.

**It is not only noise.** It means a local gate run can FAIL for a reason CI can never see, and — the
sharper half — a local run can be made to PASS by deleting an untracked file. This run hit both:
`trace_lift.gd::_replay` crossed the 50-line function limit while being edited, and the fix was to
reshape a throwaway tool to satisfy a gate that will never see it. The same gate name reports on two
different populations depending on where it runs, which is the thing `docs/QUALITY.md` exists to stop.

**Proposed remedy.** Filter the enumeration through `git check-ignore --stdin` (one subprocess, cheap)
so both runs see the tracked set. Fallback for a non-git checkout: keep today's behaviour.

**Why this is yours.** The alternative reading is that scratch tools *should* be linted, on the grounds
that a scratch tool that produced a shipped number is not really scratch — this session's own
`trace_lift.gd` is the argument for that. Which population the gate is *supposed* to cover is a
QUALITY.md question, and changing an enforcement's population is exactly the kind of change that
should not happen quietly inside an unattended run.

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

## P005 · The "63 clean LIFT batch" is mostly blocked by this run's own non-negotiable

**Status:** open · **Cost to apply:** a slice, not a session · **Raised by:** this session, 2026-08-30 (D0215)

The presentation run was briefed to work through the migration map's 63 LIFT files, with "no coordinator
rebuilds (world_renderer/hud splits) — parked, judgment-dense" as a non-negotiable. Those two
instructions are in direct tension, and measurement rather than reading is what shows it.

**The measurement.** All 21 code files in the LIFT set, scanned for the legacy `class_name`s they
reference **in code with comments stripped** — a raw text scan is useless here, because these files'
comments are full of capitalised prose that reads as type names.

| Blocked on | Files | Lines |
|---|---|---|
| `WorldRenderer` / `MainView`, the coordinator | sky_painter, terrain_painter, water_view, rope_view, falling_items | ~1,540 |
| `FactorySim`, legacy's sim | fine_terrain, sfx, water_flow, power_flow | ~2,700 |
| `MachineDef` / `RecipeDef`, entities that do not exist here | visuals (1,850) + 13 machine records | ~2,050 |
| One hop: needs `Visuals`' keycap metrics only | ui_theme, page_surface, payouts | ~394 |
| Nothing — liftable today | art, particles, light_layer, settings, seams, score | ~945 |

**So roughly 900 of 8,539 lines are reachable without building a coordinator, and `score.gd` was one of
them** (now lifted, D0215). `visuals.gd` — the single largest file and the one everything HUD-flavoured
hangs off — is not blocked on a renderer at all; it is 1,850 lines of machine and item glyphs for
entities this build does not have.

**Three ways forward, and the choice is yours.**

1. **Lift the rest of the unblocked ~900 and stop.** `art`, `particles`, `light_layer`, `settings`,
   `seams`, plus `ui_theme` if the three keycap metrics are extracted out of `visuals.gd` first. Real,
   cheap, and it does not touch the fork below. Ends with the batch genuinely dry.
2. **Lift the ~394 one-hop files by extracting a `Visuals` subset.** `ui_theme.gd` is "what makes the UI
   read as 2026" and needs exactly three members (`keycap_height`, `KEYCAP_BASE`, `KEYCAP_DROP`). The
   catch: there is no UI in this build to theme yet, so the value is banked, not realised.
3. **Un-park the coordinator.** ~1,540 lines of world rendering unblock at once, and it is the only
   route to the thing that would actually change how the game looks. This is the judgment-dense work the
   run was told not to do, and `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` §10 names it as the risk most
   likely to bite: `world_renderer.gd` is 3,656 lines against a 400-line gate.

**One thing that is already ruled and worth re-reading before option 3.** `docs/WORKING.md` records the
Q1 finding that **the palette reads at 16px but the FLECK does not**, and that `terrain_painter.gd` is
"not portable as written". That is 438 of the 1,540, and it needs an art pass, not a port.

---

## P006 · The MODULE.md 60-line cap is violated by every module that has one

**Status:** open · **Cost to apply:** ~1 hour, or one sentence · **Raised by:** this session, 2026-08-30

`CONTEXT.md`'s five-file rule states a 60-line maximum for a `MODULE.md`. Measured across every tracked
one: **10 of 10 exceed it.**

```
core/MODULE.md              98      sim/mining/MODULE.md        77
sim/terrain_gen/MODULE.md   91      sim/world/MODULE.md         70
sim/body/MODULE.md          82      sim/meta/MODULE.md          70
sim/run/MODULE.md           69      interface/MODULE.md         65
sim/invariants/MODULE.md    63      sim/commands/MODULE.md      61
```

The cold-read audit flagged this on 2026-08-29 with four files over; it is now ten, and two of the ten
(`interface`, `commands`) are this session's own — written at 65 and 61 because the gotchas they carry
are load-bearing and trimming them would have deleted the reason each file exists. **Recorded rather
than quietly complied with or quietly ignored**, because both of those are how a rule becomes decoration.

**A rule no instance obeys is not a cap, it is a comment.** The two honest resolutions:

1. **Raise it to a number the tree can meet** — 100 clears every current file with headroom — and add it
   to `check_size_limits.py`, which already walks `.md`-adjacent structure and would make it real.
2. **Keep 60 and mean it**, which means a trimming pass over ten files and accepting that a module's
   gotchas move somewhere else. `core/MODULE.md` at 98 is the test case: read it and decide whether the
   38 lines over budget are worth keeping.

**Why this is yours.** Either answer costs something the session cannot weigh: option 1 relaxes a
deliberate constraint on how much a module is allowed to explain about itself, option 2 spends an hour
deleting prose that somebody wrote on purpose. What is not defensible is the current state, where the
number exists and nothing checks it.

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

**Two more items in the same measurement. Both were first written down here as cheap and needing no
ruling; measuring them made both statements wrong, so they are restated against tool output.**

**`test_reveal_spawn_bounds` regenerates the same worlds four times over.** Counted with a temporary
call counter inside `ShaftGenerator.generate`, not by reading the file:

```
[TEMP] ShaftGenerator.generate called 517 times, 77198.0 ms total, 149.3 ms each
```

517 generations, **77.2s of the suite's 81.1s — 95%, not the "at least twice" first written here.** Four
passes cover the identical 128 `(site, seed)` pairs: two read-only (`find_spawn` only) and two through
`RevealSessionSetup.build`. **But the cheap half and the valuable half are not the same half.** Merging
the two read-only passes is provably safe and saves 128 generations, ~19s. Getting the other ~19s means
sharing one *carved* grid between the walk test and the jump test — and that is an aliasing decision
inside the suite that guards bounds violations, resting on "neither run mutates the grid" staying true
forever. In this repository that is the house failure class with a fuse in it, so it is parked rather
than done: **~23% is free, the other ~23% is a ruling.**

**The fuzz probe cannot be sharded, and the reason is not the one first written here.** The claim was
that each seed is fully independent because of `SplitRng.new(seed)`. The RNG is per-seed; the **world is
not** — `HostileChamber.build()` is called once, above the loop, and every seed shares that object,
which digging then mutates mid-run (P004: seed 45 excavates a cell and seeds 46-99 inherit it). A
`--seed-start=` is still about four lines plus the summary line, and it would be **inexact the day it
lands**, not merely fragile later. Sharding needs the world rebuilt per seed first — which is a change to
what gate 26 and gate 29 measure, so their standing numbers (922 and 440,652) would both move and both
need re-baselining. That is the ruling, and it is entangled with P004's own remedy rather than separate
from it.

**A trap worth recording separately.** A local battery built by grepping `harness.yml` for
`res://tests/test_*.gd` picks up `test_body_fuzz.gd` — which is `if: github.event_name == 'schedule'` and
runs 1.5M ticks. This session's own battery ran it every time, ~4 minutes each. Parse the YAML and take
the `tests` job's steps; the file now parses, and D0217 made that a gate.
