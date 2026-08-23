# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. This file is the current disposition; an area is CLOSED only where the
evidence is named, and a partial area is stated as partial rather than rounded up.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Closed** | `world_renderer.gd` 4601 -> 3557 lines across three extractions, each cut against a measured ranking and each proven equivalent before it landed. Every candidate still in the file is rejected with its numbers rather than with a plan to get to it. `main.gd` and `factory_sim.gd` were measured and have no separable seam: their coupling is semantic, not a god-file boundary. Closed because the measurement says there is nothing left worth cutting, not because the time ran out. |
| 3. Harness quality | **Closed** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. A later audit found 58 of the 89 layers inheriting `check_base.gd` hand-rolling the verdict protocol, and so missing the base class's refusal of a green that asserted nothing. The measured before-state was **55 registered layers exiting 0 having asserted nothing at all**. All 90 inheritors now reach exit 0 only through `_verdict()`, none of them moves an assertion counter itself, and both rules are gated by `check_verdict_route` with a shrink-only exemption list that is empty. |
| 4. Performance and maintainability | **Closed** | a formal pass found seven full-grid loops, one of which ran every frame; both cliffs are fixed and the residual is measured at 2.74ms, which the charter's *fix confirmed cliffs only* answers rather than defers. The frame SLO has been evaluated on the host it was written for, and its allowances — one machine's numbers applied to any machine — are now a per-host registry that refuses rather than borrows. The hidden-coupling bullet found a live defect: a tree could grow inside a bazaar and the cache would not notice, reachable through an ordinary player verb. Fixed, and gated behaviourally plus by writer population. |
| 5. Documentation and contributor readiness | **Done** | architecture docs reconciled with executable behaviour, contributor and release workflow written, repository map present, and layer-count drift is now gated by the registry so a stated total cannot rot. |
| 6. Public presentation | **Complete** | the README explains the engineering system and the test-surface ratio accurately, history and media are retained deliberately with clone guidance, and the repository is legible to a reviewer in their first ten minutes. |

## Area 2 — closed

`world_renderer.gd` went 4601 -> 3557 lines. The three extractions are in history and are not new here:

| seam | class | commit | file after |
|---|---|---|---|
| machines | `scenes/machine_view.gd` | `097c769` | 4008 |
| water | `scenes/water_view.gd` | `8fa99a8` | 3727 |
| rope + grapple | `scenes/rope_view.gd` | `d1d5ab8` | 3557 |

**This entry closes the cumulative programme; it does not land those seams.** Each was proven
token-identical to its original after un-prefixing, with span logic written independently of the
extractor's, a one-token mutation as the negative control, and a check layer shown to go red on a
deliberate defect in the moved code.

Two line counts in the older record are wrong by small amounts and are corrected rather than quietly
replaced. The starting figure appears as both 4601 and 4602; 4601 is right, confirmed by `wc -l` and
`grep -c` agreeing on a file that ends in a newline. The finishing figure was written as 3555, which was
measured after the block came out and before the parent's field and constructor call went back in; the
file is 3557.

**What closes it is the rejection evidence, not the subtraction.** The ranking below scores every remaining
candidate, and the two files that were never measured have now been measured. Area 2 asked for oversized
files to be broken along real boundaries. Three real boundaries existed, all three were cut, and the
remaining ones are named with the numbers that disqualify them — which is the same claim as "the file is
the right size now", made in a form a reader can check.

## Area 2 — the seams, measured before they were cut

`world_renderer.gd` was 4601 lines. Candidate boundaries were ranked rather than eyeballed, on the size of
the interface that survives the move: outbound calls the block still needs, entry points the parent has to
keep, fields it reaches across for, and variables written on **both** sides of the line.

| candidate | lines | out | in | fields | BOTH | crossings | per 100 lines |
|---|---|---|---|---|---|---|---|
| water — **cut** | 220 | 1 | 3 | 3 | 0 | **7** | 3.2 |
| crystal seams | 96 | 2 | 1 | 4 | 1 | 7 | 7.3 |
| rope + grapple — **cut** | 119 | 2 | 2 | 4 | 0 | **8** | 6.7 |
| surface life + flora | 97 | 2 | 3 | 4 | 1 | 9 | 9.3 |
| conduits + power | 96 | 3 | 4 | 4 | 1 | 11 | 11.5 |
| machines — **cut** | 460 | 1 | 4 | 11 | 0 | **16** | 3.5 |
| ore + lode + grain | 259 | 4 | 5 | 8 | 1 | 17 | 6.6 |
| aim + build previews | 298 | 5 | 2 | 12 | 0 | 19 | 6.4 |
| terrain bake | 101 | 2 | 6 | 12 | 1 | 20 | 19.8 |
| mining tells | 110 | 5 | 5 | 11 | 0 | 21 | 19.1 |
| veil | 269 | 6 | 1 | 17 | 2 | 24 | 8.9 |

**The largest and most contiguous block is the worst candidate.** The veil runs nearly unbroken to the end
of the file, which is exactly what makes it look extractable. It reads seventeen of the file's mutable
fields and writes two dirty-flags the parent also writes, so moving it relocates 269 lines and leaves the
coupling where it was: a smaller file and the same design. Rejected.

**Read the count, not the rate.** The per-line column divides by the size of the thing being moved, so it
pays a candidate for being large — it ranks `machines`, at sixteen crossings, second best of everything.
What has to be maintained afterwards is the count. The veil is the control on that reading: it is the
largest candidate left, a size-flattering metric should favour it, and it finishes last on both columns.

**Terrain bake was re-measured and rejected.** An earlier note recorded it at 23 functions and 498 lines
and did not record *which* 23. A count without its membership cannot be re-measured: a later pass derives
a different set, and the two numbers read as a disagreement about the code when they are a disagreement
about the population. Every row above is reproducible — each candidate is seeded from named state or a
named draw family and grown by adding only file-private helpers whose sole callers are already inside.

**A coordinator welds the graph shut.** That growth rule has to hold out `setup`, `_process`, `_draw` and
`repaint_world` by name. Without the holdout the first terrain-bake run returned 21 functions including
`setup`, which is not a seam, it is the file.

**Two blind spots in the measuring code, both found by the compiler rather than by the scan.** The function
scan matched `^func` and not `^static func`, so a static helper was invisible and `rope + grapple` scored
seven crossings — tying the best row in the table — when it costs eight. And the check that clears a
constant for the move reads one file, so it cleared two constants that a test layer outside that corpus
reads. A declaration form a scan does not enumerate does not show up as a gap in the output; it shows up
as a better result.

### `main.gd` and `factory_sim.gd`: no separable seam, which is a finding

Both files were measured the same way, and neither yields a candidate worth cutting. That is the useful
answer, not a deferral.

`factory_sim.gd` is **68% single-group by touch and 55% by write** across nine state groups. The coupling
is not diffuse; it is six functions. `mine`, `place_block`, `set_solid` and the three `_run_*` diggers each
write three or four groups, and they are exactly the functions every clustering seed absorbed. Removing the
derived bazaar cache from the population — one plausible accidental crossing — takes the worst writers from
four groups to three and leaves the rest. The residual crossing is semantic: mining a flooded ore cell
removes terrain, spills water and yields an item, and that is one physical event rather than three
concerns. Splitting it would need an event bus, which is a larger change than this programme authorises.

`main.gd` is **72% single-group by touch and 77% by write**. Its best-scoring candidate is a fusion
artifact: seeded on juice state it absorbs mining, because mining writes the screenshake.

### The limit of the instrument, stated

The clustering rule finds seams around **state**, and `water` owned no mutable field of its own. Seeded on
its state the rule returns nothing; seeded on the shared fields it reads, it returns 51 functions and the
whole draw pass. The seam that scored best in the table is one this instrument could not have found. Draw
families were therefore enumerated by topic as a second, orthogonal pass — which is how `rope + grapple`
surfaced.

### A control that could not fail, found by mutation and corrected

Building a mutation control for the extracted block turned up a defect the extraction did not cause.
`check_grapple_reads` asserts *"CONTROL: the preview was actually drawn"* against a floor of **1.0 levels
of edge**. Delete every stroke the aim ghost makes and that measurement still reads **3.8 to 5.4**: the
head-lamp swings with the cursor, so the rock it lights is not identical between the reference capture and
the measured one, and the residual is not zero. The control passed on a frame with no preview in it, and
the comparison underneath it — the miner must out-read their own telemetry — then weighed the miner
against a 4.6-level nothing and passed too.

Measured from both sides, eight runs each, the removed side produced by returning from the draw call before
it draws anything:

| aim ghost | levels of edge |
|---|---|
| drawn | 13.0  13.7  17.9  19.6  26.7  28.3  29.7  31.7 |
| removed | 3.8  4.6  4.6  4.7  4.8  5.1  5.2  5.4 |

A floor of **8.0** separates those cleanly, fails on the mutant at 4.7 and passes clean at 13.5 — and it
**failed inside the configured sweep, on an honest frame, at 2.8 levels over 3982 pixels.** All sixteen samples
above were taken with the layer run on its own, where the mask settles around 700 to 1100 pixels. The
statistic is a mean over that mask, so a mask four times the size dilutes the same signal below what the
subject's own absence produces: in the sweep with the ghost drawn it reads lower than standalone with the
ghost removed. No fixed floor is valid across both conditions.

**The tightening is therefore withdrawn, not tuned down.** A bound chosen on a population that excludes the
condition the gate actually runs in is not a bound, and lowering it until the sweep went green would have
restored exactly the vacuity it was meant to remove. The floor returns to 1.0, the defect stays written
down in the layer beside the measurement, and the next attempt starts from a statistic that does not
dilute. One is already in the file: the body's own control uses a p90, which also means the comparison
underneath these two controls currently weighs a p90 against a mean.

The mistake worth keeping is the measurement frame. Sixteen samples looked like plenty; every one of them
came from the same condition, and the condition was the one the gate does not run in.

**A second control on the same subject is reported rather than adjusted.** The companion assertion — the
preview drew something against open sky, floor 60 pixels — discriminates on fifteen of those sixteen runs.
Its one miss is a heavy tail that appears on both sides: with the ghost removed the mask came back at 5922
pixels once, larger than any run with the ghost drawn, and the drawn side has its own tail at 1791, 2323
and 5496 against a median of 198. That single tail event is why the first mutation run left the whole layer
green. No bound can fix this: excluding 5922 would need a floor above every honest run. The tail has a
cause worth finding, and moving the number would only hide it, so the number stays and the instability is
recorded here with its samples.

### Duplication audit, over the tracked tree

The population is `git ls-files '*.gd'` and nothing else — 179 files, 1927 functions of twenty tokens or
more. An untracked scratch copy of a test layer exists in `tools/` and is deliberately excluded: it is not
shipped code, and counting it would report a duplicate the repository does not have.

| pass | groups | redundant copies |
|---|---|---|
| byte-identical bodies, literals preserved | 25 | 26 |
| identical once string literals are normalised | 37 | 61 |

**Both numbers are reported because the second one is easy to quote as the first.** Normalising literals is
what lets a scan see a copy that differs only in a constant, and it is also what makes two genuinely
different functions look the same. The twelve extra groups are the interesting ones and they are named
below rather than folded into a headline.

**Almost all of it is in the test layers, and most of that is deliberate.** `check_progressive_bake` says
in its own comment that it duplicates a converter *rather than* sharing it, because a test that borrows the
production code it judges cannot catch that code being wrong. That reasoning is correct and generalises:
consolidating a shared *judge* would make one bug break several layers in the same direction, and their
agreement would stop being evidence.

**Three findings survive that reasoning.**

1. **The boot preamble is copied across the layers instead of living in the base class.** Fifteen layers
   share one `_initialize()` shape and six more share another, differing only in a banner string, a pass
   message and the layer's own name. This is protocol, not judgement — it decides the exit code the runner
   reads — and `tools/check_base.gd` already exists to hold exactly that. Copies of a protocol are the
   thing most likely to drift out of step with the runner that reads them. Recorded as the next
   consolidation; it touches twenty-one layers and is not folded into another change.

2. **A copy documented as a copy, with nothing enforcing it.** `check_rock_reads._delve` carries the
   comment *"lifted from check_underground so the two layers judge the same place"*. The intent is that the
   two are identical; the mechanism is that somebody keeps them so. If either drifts, the stated invariant
   breaks silently and both layers keep passing — against two different places.

3. **One duplicate in shipping code, now removed.** `_nearest_ore_to_player` and `_nearest_tree_to_player`
   in `main.gd` had byte-identical bodies apart from one material literal. They are one
   `_nearest_material_to_player(material)`. Neither copy was wrong, which is how it lasted: a duplicate
   only announces itself when the two sides drift. Equivalence was checked in both directions — the new
   body with the parameter bound to each literal reproduces each original token for token, with the
   literals swapped as the negative control — and stubbing the search takes `check_loop_health` from 98.7
   to 76.5 against a floor of 90.0, so a layer does reach it. That change landed in `31698a7`, whose
   message describes only the control retraction it was committed beside; recorded here because the commit
   message does not, and the history is not rewritten to fix a message.

**Three categories came back clean, and the limits of each check are stated with it.** The nine
invalidation flags are each written from exactly one file, the file that owns them — though that scan
matches `= true` and `= false`, so an invalidation carried by an array or a counter is invisible to it and
`terrain_dirty` is exactly that case. There are four serializer entry points and no duplication among them.
Seventeen predicate names are defined in more than one place, and every one of them is a different body: a
facade delegating to the real implementation, or two bounds checks over two different objects. Same name is
not same logic, and none of these are a defect.

## Area 4 — the frame SLO, run on the host it was written for

The contract exists and is host-gated: it asserts only when `SF_PERF_HOST` names the machine, because a
frame-timing claim on arbitrary hardware is a statement about the box. Nothing sets that variable, so until
now the contract had never been evaluated. Set on the development host (M4 Pro, 120Hz), seven runs, the
layer running alone as a timing layer must:

| phase | p50 | p95 | p99 | worst | deadlines missed (allow) | worst as x interval (allow 3.0) |
|---|---|---|---|---|---|---|
| IDLE | 8.00 | 10.5 | 14.5 | 17.7 | 0.0–1.0% (1.0%) | 1.4–2.1x |
| RUN | 8.34 | 8.9 | 11.0 | 11.9 | 0.0% (1.0%) | 1.1–1.4x |
| DIG | 8.32 | 10.5 | 18.1 | 22.1 | 2.8–3.2% (6.0%) | 2.2–2.7x |
| SWING | 8.33 | 9.7 | 10.6 | 12.2 | 0.0% (1.0%) | 1.3–1.5x |

All four phases hold, and DIG — the phase doing work the player asked for mid-frame — has roughly twice the
headroom it needs on both terms.

**The interesting number is IDLE's, and it is a resolution problem rather than a performance one.** Two
hundred samples quantises the miss rate at 0.5%, so one late frame is the smallest reading there is and the
quiet allowance is exactly two of them. Six runs read one late frame five times and two once. The contract
is a single frame from red, on the phase that does the least work.

**The obvious remedy was tried and is wrong, which is why it is written down.** Tripling the window to 600
frames should sharpen the resolution to 0.17%. Measured, it does the opposite to the contract: DIG's miss
rate falls from 2.8–3.2% to 2.0%, and RUN and SWING flatten to a p99 of 8.74ms against a worst of 8.84 —
almost no variance at all. The hitches are not distributed across a phase, they are concentrated at its
start, where chunks stream and the first rebake lands. A longer window therefore grows the denominator and
leaves the numerator where it was. Keeping the same sensitivity at 600 frames would mean lowering every
allowance to match a diluted measurement, which is loosening a contract to make its arithmetic tidier. The
sample count stays at 200, and IDLE's one-frame margin is recorded here rather than papered over.

**A confound was tested and excluded.** Every measurement taken through the test wrapper runs with shader
caching disabled — the renderer initialises before the isolated home's user directory exists, and the engine
does not retry. That was a plausible source of the late IDLE frames. Re-run against a home pre-populated
with a copy of the real shader cache, the engine's complaint disappears, which proves the treatment reached
its subject, and the numbers do not move: IDLE 0.5% missed, DIG 3.2%. The hypothesis is retired with a
positive control rather than on argument.

## Area 4 — the bazaar cache, verified rather than assumed

`_rescan_bazaars` is the only genuine full-grid walk left in the tree: 16384 origins, consulted every frame
through the minimap draw and the bazaar view, and invalidated by nine event-driven sites including each
drill tick. A dig therefore invalidates the cache and the next frame pays a rescan, which is the shape the
original stutter had.

The source proved its own repair with a frame-level ceiling. That is the right evidence for "is the stutter
gone" and the wrong evidence for "what does one rescan cost", because a ceiling bounds the rescan without
measuring it. Measured directly, headless, 40 samples, invalidating before each:

    rescan   min 2.69   p25 2.72   median 2.74   mean 2.75   p95 2.82   max 2.86   ms
    cached   median 0.000                                              ratio ~27000x

The cached row is a control travelling inside the same run. If the two came back alike the timer would be
measuring call overhead and neither number would mean anything; they separate by four orders of magnitude.
The spread is 0.17 ms across 40 samples, so this is a stable cost rather than a sampled one.

No defect: the cache is correct and the repair holds at roughly six times. A dig costs a third of a 120fps
frame rather than two whole ones.

## Area 4 — hidden coupling: a tree could grow inside your bazaar and the game would not notice

The Area 4 charter asks to *reduce hidden coupling between renderer, sim and save state*. The residual
from the bazaar-cache work named a specific instance and deferred it: `solid` is mutated by direct
dictionary assignment, so an index of wood cells could not be maintained soundly, and *"an index that any
caller can silently invalidate is worse than the walk"*.

**That was already true of the cache that exists, without any index, and nothing said so.**

`find_bazaars()` is served from a cache refilled when `_bazaars_dirty` is set. `Flora.grow` runs inside
`FactorySim.tick()` and stamps a tree trunk straight into `sim.solid` — and set no flag. Probed directly
before anything was changed:

    is_bazaar_at(o) before: true      find_bazaars() warm:  [(40, 40)]
    is_bazaar_at(o) after:  false     find_bazaars() after: [(40, 40)]

**Reachable through an ordinary verb.** `can_plant_sapling` asks only for empty ground on soil, and a
bazaar's interior floor is earth, so a player can plant a sapling inside their own stall. Two minutes
later the trunk closes the interior: the structure stops being a bazaar, the stall stays drawn, and the
near-bazaar craft gate stays open — until an unrelated dig happens to invalidate the cache. The mirror is
worse: a trunk growing into a ruin's one missing cell **completes a bazaar nobody has been told about**.

A second instance, latent, from the same census: `load_world` writes `solid` in bulk and left the flag to
its caller. `main.gd` got away with it by loading into a fresh sim whose flag starts dirty, so the miss was
invisible from the only path anybody exercised, and `SaveGame` handled it by setting the private field by
name from outside the class. Both now go through `FactorySim.invalidate_bazaars()`, which `load_world`
calls itself.

### The gate is behavioural, and then it is a population

A grep for `_bazaars_dirty` beside every `solid[` write would have missed this one — the write is in
another file, through a preloaded reference — and it would pass a flag set in a branch that is not taken.
So `check_bazaar_cache` asserts the only thing that matters: after each way the world can change, does the
cached answer equal a scan of the world as it now is. Six cases, compared as **sets of origins rather than
counts**, with a brute-force walk of the grid as the control travelling inside each one. Every case also
asserts that the world really did change, so no case can pass by measuring nothing.

That covers the ways somebody thought of. `Flora.grow` was not one of them for as long as it existed, so
the **writer population** is asserted too: 55 `.gd` files under `src/` and `scenes/` are scanned with
comments and string literals stripped, and the set that writes the coarse grid must be exactly the two
with a case in the layer. Clearing a red there means adding a case, not adding a name.

| control | result |
|---|---|
| the scan sees a real `sim.solid[t] = &"wood"` | flagged |
| …does not mistake a `_fine_solid` write for one | silent |
| …does not mistake a read for a write | silent |
| mutation: flora forgets to invalidate | 3 of 35 red — and in **both** directions: `cache [] / world [(40,40)]`, and `cache [(40,40)] / world []` |
| mutation: `load_world` forgets | 1 of 35 red, on the load case alone |
| mutation: a third file starts writing `solid` | 1 of 35 red, naming the file |
| mutation: a known writer dropped from the list | 1 of 35 red |

### The residual, and why it stays

The coupling census, re-derived: **six external writes to a `FactorySim` private in game code** — three in
`src/core/fine_terrain.gd`, three in `src/core/save_game.gd` — across ten distinct private names. Those are
collaborator classes owning a slice of the sim's state by design, the same arrangement as `PowerFlow`,
`WaterFlow` and `Flora`. The one that was load-bearing for *correctness* rather than for construction was
the cache invalidation, and it is now a named method with a behavioural gate behind it.

**The first census of this returned zero and was wrong**, which is worth recording next to the number it
replaced. `git grep -E` silently drops `\b`, so a pattern anchored on a word boundary matched nothing and
reported a clean tree. Caught by running the same pattern against the previous commit, where a known
offender had to appear and did not.

**The wood-cell index is not built, and that is the charter's answer rather than a deferral.** Area 4 says
*fix confirmed scaling cliffs only*. The rescan was a cliff at 16.4ms and is not one now: measured directly
it is 2.74ms with a 0.17ms spread over 40 samples, and seven fresh `check_frametime` runs put DIG at
3.0–3.8% of deadlines missed against a 6.0% allowance and a worst of 2.2–2.7x against 3.0x. There is no
confirmed cliff left to fix here, so building an index would be optimising against a named correctness
risk with no measurement asking for it.

## Area 4 — the frame SLO's allowances were one machine's numbers, applied to any machine

Area 4 asks for reproducible performance semantics: *a number that means the same thing on two machines*.
The one place this project makes an absolute performance claim was the one place that property did not
hold, and nothing said so.

`MISS_QUIET` 1.0%, `MISS_WORKING` 6.0% and `SEVERITY_X` 3.0x were **global constants**, ratcheted onto five
runs of one `Mac16,8`, and they applied unchanged to any box whose operator set `SF_PERF_HOST`. Naming a
second machine would have asserted the first machine's behaviour on it. A green would have meant *this box
behaves like that one* while reading as *this box holds the contract*.

`tools/perf_hosts.txt` holds them now: one row per host per phase, each carrying the measurement it came
from and the **model** that measurement was taken on. A host with no rows is a hard FAIL —

- **not a fallback to the defaults**, because the defaults were the defect, and putting them back on the
  error path is where a defect goes to be hard to see;
- **not a stand-down**, because answering *we have never measured this machine* with a skip files it under
  *nothing to report*.

The model column is checked against `OS.get_model_name()`. An environment variable travels — a shell
profile, a CI secret, a copied command line — and the failure that causes is the quietest kind: the wrong
allowances applied silently on hardware nobody calibrated.

| path | result |
|---|---|
| `SF_PERF_HOST` unset | stands down exactly as before, `PASS (5 asserted)` |
| `SF_PERF_HOST=some-other-box` | FAIL — *a machine this repository has never measured* |
| `SF_PERF_HOST=mac16-8-120hz` | asserts, *allowances read from … (4 phase rows)* |
| model column changed to `MacIntel99,1` | FAIL — *measured on MacIntel99,1 and this box reports Mac16,8* |
| a tab removed from one row | FAIL — *line 56 has 5 tab-separated fields, needs 6* |

### A reading that did not fit, kept

Six runs on the named host at load average 3.1–5.3 — a working box, not the quiet one the original seven
were taken on. Five came back with every phase at 0.0% except DIG at 3.0–3.8%. The sixth read **SWING at
1.5% against its 1.0% allowance**: three late frames in a phase that read 0.0% in all five neighbours and
in all seven original runs.

**The allowance was not moved.** One run in six over a bar is either a contended box or a real tail, and
this layer cannot tell those apart — `_absolute`'s own note records every discriminator that was tried and
why each failed. Widening a bar to fit a reading converts *we cannot tell* into *this is fine*, which is
the one move a ratchet exists to prevent.

So the host stays unarmed, and now for two reasons rather than one: IDLE's known one-frame margin, and
SWING's exceedance measured today. All seven runs are retained under
`docs/tracelog/sweeps/2026-08-23-perf-hosts-registry-green/frametime-runs/`.

## Area 3 — the verdict protocol, audited

The duplication audit flagged a copied boot preamble across the test layers. Examined properly it is not a
tidiness problem: **the copies are missing a guard the original has.**

`check_base.gd` exposes `_verdict(layer, note)`, which refuses a green that asserted nothing —
"a layer that has nothing to assert must skip and say why" — and prints the assertion count as part of the
verdict. A hand-rolled tail does neither:

```
if _failures == 0:
    print("check_x: PASS — ...")
    quit(0)
```

Zero assertions and zero failures is a PASS.

**Proven with a paired mutation, not by reading.** The same treatment — overriding `_check` to a no-op, so
the layer runs normally and records nothing — was applied to one layer of each kind:

| layer | verdict style | clean | zero assertions |
|---|---|---|---|
| `check_paint_terms` | hand-rolled | exit 0, PASS | **exit 0, PASS, wording unchanged** |
| `check_shared_constants` | `_verdict()` | exit 0, PASS (80 asserted) | exit 1, FAIL naming the defect |

Identical mutation, opposite outcomes, which isolates the preamble as the cause rather than anything about
the two layers.

### The population, named — because two denominators were in the record

Three different sets could be meant by "the layers", and until this was written down the record carried two
different hand-roller counts with neither of them saying over what. Converting the wrong set is the failure
this prevents.

| population | definition | size |
|---|---|---|
| `P_REG` | rows the runner registers, from its `add`/`add_gl`/`add_excl`/`add_excl_hl` calls | 110 at the audit, **111** today (106 of them `.gd`) |
| `P_GLOB` | tracked files whose basename starts with `check_` | 100 at the audit, **101** today |
| **`P_INHERIT`** | **tracked `.gd` matching `^extends "res://tools/check_base.gd"`** | **89 at the audit, 90 today** |

`P_INHERIT` is the one the finding is about, and it is well-behaved: every inheritor is registered, and
every inheritor is named `check_*`. Both set differences are empty — checked as sets, not as counts. Eleven
`check_*` files do not inherit, which is why `P_GLOB` is larger: ten extend `SceneTree` directly, and the
eleventh is `check_base.gd` itself, which is a base class rather than a layer and is the one tracked
`check_*.gd` the runner does not register.

Over `P_INHERIT` the partition is complete, with nothing left over:

**89 inheritors = 31 calling `_verdict()` + 58 hand-rolling the verdict + 0 neither** — as it stood when
the audit was written. After the conversion below it is **86 + 3 + 0**, over the same population and by the
same rule, and **90 = 87 + 3 + 0** once `check_verdict_route` joined the population it audits. Every size
in this table is a snapshot with a date on it; the commands beneath are the record, not the numbers.

**A fifth denominator exists and is not an error.** `tools/check_base_namespace.sh` reports 108 subclasses
(it read 106 when this was written; the rule, not the number, is the record) because it searches with
`grep -r` and so sees the untracked, gitignored `tools/_scratch_*.gd` probes that `git grep` cannot. Its
population is deliberately the wider one — a scratch probe that shadows a base member is a real collision
— so the two numbers disagree correctly.

**And that layer had no way to fail.** It walked its subclasses looking for a member name colliding with
one the base already owns and reported none, every run, having never been shown finding one: a typo in the
comparison, a member list read off the wrong file, or an empty subclass set all report exactly that. The
comparison is a function now, `collisions_in`, and the real scan and the controls call the same one. The
positive control writes a subclass into a temp dir shadowing `_failures`, a member the base genuinely has,
and the negative twin writes the same file with the name left alone. If the control comes back clean or the
twin comes back dirty the layer says the instrument is broken and refuses to report a verdict at all,
because a green from a broken instrument is worse than a red.

    bash tools/check_base_namespace.sh
    PASS - 108 of 108 subclasses, none shadowing a base member (control: _failures)

**Reconciling the two numbers that were in the record.** `check_base.gd` states 86 = 29 + 57. That was true
when written and has drifted by three layers added since; measured now it is 89 = 31 + 58, and the comment
is corrected. The other figure, 40, came from this document and was the same population classified by a
narrower rule: it required the verdict tail to sit inside `_initialize()`. It does for 40 of them and lives
elsewhere in the other 18. **Same 58 files; the 40 was a statement about where the tail is, not about which
files have one.** The convertible set is 58.

**The stale comment is itself the defect this repository has a rule against.** `CONTRIBUTING.md` says a
comment stating a number is a test with no runner, and `check_doc_counts` enforces exactly that — over
`README.md`, `CONTRIBUTING.md` and `docs/ENGINEERING.md`. A count inside a `.gd` comment is outside that
gate's population, which is how 86/29/57 went stale unnoticed while the rule against it was being enforced
three files away.

**A second gap, from the same audit — since closed.** Nineteen layers printed a green line that never
named them — `AGILITY OK` rather than `check_agility: PASS` — so they sat outside `check_verdict_claims`'
population by construction. The conversion below puts all of them on `_verdict()`, which prints the layer
name, and the gate now reads notes as well as literals. Measured over the sweep logs afterwards: every one
of the 89 inheritors self-names.

**The independence check changed the recommended fix, which is why it was run first.** Only the trailing
verdict is protocol. Twenty-one of the forty carry real judgement inside `_initialize()` — `check_settings`
exercises the whole settings round-trip there, `check_pack_layout` runs its entire layout suite, and
`check_water_reads` makes its headless skip decision there. Converting `_initialize()` wholesale would
sweep layer-specific setup into shared code and silently change what other layers measure. The safe
transformation is the tail alone, leaving every other statement where it is.

**Blast radius, checked rather than assumed.** Nothing downstream parses the green line's text:
`harness_verdict.sh` states outright that it is "deliberately not a search for PASS/FAIL" and classifies on
exit codes and per-layer logs. So the tail conversion — which changes `PASS — note` to
`PASS (N asserted) — note` — cannot disturb the runner's verdict.

The conversion itself is the next slice and is deliberately not folded into the audit. **Evidence:** full
sweep retained at `docs/tracelog/sweeps/2026-08-22-area2-close/`, 112 per-layer logs, `summary.txt` stamped
`head: 793d834, worktree: clean`, `110 PASS / 0 FAIL / 0 SKIP`, `HARNESS_RESULT=yes`, exactly the six
registered stand-downs.

### The conversion, and the number the before-state turned out to be

Fifty-five of the fifty-eight are converted, in five batches, `97c62d8` through `9474ffd`. Only the tail
moved: every layer's `_initialize()` body, its fixtures and its assertions are untouched, and the one tail
that carried a comment kept it.

**The before-state was measured, once, over the whole population, and it is the reason the slice was worth
running.** With `_check` overridden to record nothing — assertions still executing, none of them counted —
the fifty-five hand-rollers returned:

    55 PASS / 0 FAIL / 0 SKIP of 55 selected

Fifty-five registered layers exited 0, reported green by the runner and quotable in a summary, having
tested nothing. Not one noticed. Confirmed rather than inferred: `grep -cE '^[[:space:]]*(PASS|FAIL):'`
over all fifty-five retained logs returns 0 for every one, and the same grep over the unmutated run returns
26 for `check_bits`, 21 for `check_drift`, 14 for `check_seam` — so the zero is a measured zero and not a
broken pattern. Retained at
`docs/tracelog/sweeps/2026-08-22-verdict-tail-00-baseline-noop-mutant/`.

After conversion the identical mutation turns every one of the fifty-five red, each naming the defect.

**Three controls per batch, all three run on every batch rather than argued from the base class:**

| control | mutation | required outcome |
|---|---|---|
| a real assertion still fails when broken | `_check` → `super._check(false, label)` | every layer red, and the count in `N FAILURE(S) of N asserted` equal to the clean run's count, layer for layer |
| a zero-assertion layer cannot pass | `_check` → records nothing | every layer red with *the layer made NO ASSERTIONS and reached its verdict anyway* |
| the exit code and verdict are still reported correctly | none | every layer green, each printing its own count |

The count equality is the part that does more than the exit code: it shows the same assertions ran under
the mutant and merely failed, rather than the layer having taken some other path to a red.

**What the conversion also fixed, found by counting rather than by intent.** Nineteen of the fifty-five
sent their FAIL verdict to `print` rather than `printerr`, so a real failure went to stdout. All nineteen
now go to stderr. And measured over the sweep's own logs rather than over source, **99 of 110 layers now
print a self-naming verdict line**, against 84 on the green sweep of the day before; the eleven that do not are the four `tests/test_*.gd`
suites, `play_tests`, `measure_player`, four of the ten layers that extend `SceneTree`, and the shell layer
`check_prose` — none of them in `P_INHERIT`. Every one of the 89 inheritors self-names.

**The tree now matches its own contributor guide, which it did not before.** `CONTRIBUTING.md`'s canonical
layer template has always ended `_verdict("check_thing", "the thing holds")`, and has always described the
exit protocol in terms of `_verdict()`. Fifty-eight layers did something else. Nothing compared the two,
which is the same shape as everything else in this section: a rule with no runner.

### The three a tail conversion could not reach, and how they were reached

`check_frametime`, `check_opening` and `check_underground` call neither `_check()` nor `_verdict()`. They
hand-roll their comparisons *and* their diagnostics — `check_underground` distinguishes a fixture that
could not reach the rock from a verdict on the rock, in its own words, over several lines. There is no
shared protocol tail in them to move, so the batch conversion refused all three, by itself, rather than
guessing.

They were recorded here as an open finding: three layers nothing would notice going quiet. Closed in
`abf8969`, and not by rewriting their judgement. Each decision is recorded with `_check()` **beside** the
diagnostic rather than instead of it — the `_check` carries the property and the numbers, the `printerr`
beneath keeps the prose that makes a red usable, and every early return stays where it was so a later
reading is never taken over an earlier one that failed. `check_opening` and `check_underground` assert 3
properties each; `check_frametime` asserts 5.

`check_frametime` is the one worth naming. `_gate`, `_workload` and `_absolute` each print lines reading
`      PASS:` and `      FAIL:` that no counter has ever seen — they only ever fed a local boolean. **A
layer printing assertion-shaped lines that nothing counts is harder to notice than one printing none.**
The helpers are untouched and their detail lines stay; the five call sites now record what they returned.

**The exemption list is empty, and the ratchet is what asked for that.** It went `3 FAILURE(S) of 12` the
moment the three became compliant, one red per stale row, saying *tighten the list the day it does not* —
the ratchet firing on real data rather than on the synthetic mutant it shipped with. The machinery stays:
a gate that cannot express an exemption gets one anyway, in the form of somebody quietly not registering
their layer. What must stay expensive is adding a row.

### The second way to hand-roll the protocol

`_check(false, label)` is exactly `_failures += 1` followed by `printerr("  FAIL: %s")`. Six layers had
written that pair out by hand at a fixture-bail — `check_aim`, `check_plunge`, `check_pump`,
`check_teaching`, `check_water_reads`, `check_wrap` — with byte-identical output, so nothing in any log
could tell them apart.

**They were harmless as written, and that is the point.** The counter really was incremented. The danger is
not the six sites, it is that the counter is reachable at all: `_passes += 1` at a fixture-bail is the same
keystrokes and would manufacture the number `_verdict()`'s refusal keys on — turning the one guard against
a layer that stopped judging into a value the layer supplies itself. The first rule stops a layer exiting 0
around the guard; the second stops it feeding the guard. Reads stay allowed: `check_item_reads` decides
between a failure and a skip on `if _failures > 0:`, which is a real decision that needs the count.

### Arming the gate before the shape arrived

The conversion would have disarmed `check_verdict_claims`, which exists to refuse a verdict claiming a
speed the layer never compared. It matched string literals containing `<layer>: PASS`; a layer calling
`_verdict(layer, note)` writes only the note, and the base class builds the line. It was already blind to
the 31 existing `_verdict()` users, and the conversion would have taken it to blind for 86 of 89 — with
nothing going red to say so.

Armed first, in `a91725c`, with a positive control for the note form and a mutation control showing the
new assertion is the only thing the new code holds up. Then the sharpened gate immediately found a second
defect in itself, `782c6d9`: its pattern's negated class `[^"\\]*` matches newlines, so any two quote
characters anywhere in a file bracketed a candidate literal, and it reported a "claim" assembled from six
lines of comment — prose *about this gate*, which happened to contain the words `: PASS`. A detector that
can build its own subject out of the commentary about it is worse than one that misses, because the miss is
quiet and this is a confident wrong red.

One real note changed as a result. `check_seam_flood`'s verdict was two concatenated chunks, and the word
the gate keys on sat in the second, which its pattern never reached — so its green was a property of the
detector's blind spot rather than of the note. Reworded to say the same thing in the layer's own terms:
both timings are reported, neither is asserted. No bound was moved and no rule relaxed.

**Evidence:** configured sweep `110 PASS / 0 FAIL / 0 SKIP` with six documented stand-downs,
`HARNESS_EXIT=4`, `HARNESS_RESULT=yes`, 287s, retained at
`docs/tracelog/sweeps/2026-08-23-verdict-tail-converted-green/`. Not a full sweep, and the runner says so
itself.

### The rule now has a runner

None of the above would have been caught by anything. The refusal lived in `check_base.gd`'s docstring and
in `CONTRIBUTING.md`'s layer template, and a rule with no runner is a preference. `check_verdict_route`
asserts the narrow version of it: **an inheritor may not exit 0 under its own power.** Not "must call
`_verdict()`", which a layer could satisfy while quitting 0 somewhere else, but the thing that actually
bypasses the guard. `quit(1)`, `quit(SKIP)` and `_void_layer()` are left alone — a false red is loud, and a
skip is already accounted for by `tools/stand_downs.txt`. A bare `quit()` is the same offence, since
Godot's default exit code is 0.

The three uncovered layers are named in the gate with the reason each cannot be converted, and the list is
a **shrink-only ratchet**: an exemption whose layer has since become compliant is a red demanding the list
be tightened, not a quiet no-op. That is the difference between a permission and a debt.

| control | result |
|---|---|
| positive: a hand-rolled `quit(0)` green | flagged |
| negative twin: the same layer through `_verdict()` | silent |
| a bare `quit()` | flagged |
| `quit(0)` only in a comment | silent |
| `quit(0)` sharing a line with a trailing comment | flagged |
| `quit(0)` only inside a string literal | silent |
| positive: a layer moving `_failures` itself | flagged |
| negative twin: a layer that only READS `_failures` | silent |
| mutation: hand-rolled tail put back into `check_agility` | FAIL naming `check_agility.gd` |
| mutation: an exemption added for a layer that does not need one | FAIL demanding the list be tightened |
| mutation: the hand-rolled counter pair put back into `check_pump` | FAIL naming `check_pump.gd` |

**It flagged itself on its first run**, and that is recorded in the file rather than smoothed over. Its own
controls are triple-quoted blocks containing the exact shape it hunts, and its comment stripper did not
understand triple quotes. The fix on offer was a per-file exemption for the detector. The stripper was
fixed instead, with a control for it, because widening a permission list to hide a defect in the detector
is the trade the layer exists to refuse.

It carries two rules, not one. **An inheritor may not exit 0 under its own power**, and **an inheritor may
not write `_passes` or `_failures`.** Each turns exactly one assertion red under its own mutant, and the
exemption list — a shrink-only ratchet — is empty.

**Evidence:** four configured sweeps across the day, every one `111 PASS / 0 FAIL / 0 SKIP` with six
documented stand-downs, `HARNESS_EXIT=4`, `HARNESS_RESULT=yes`, retained at
`docs/tracelog/sweeps/2026-08-23-verdict-route-gate-green/`,
`.../2026-08-23-last-three-converted-green/` and `.../2026-08-23-counter-writes-green/`. Not full sweeps,
and the runner says so itself.

## Area 3 — a wait with a budget smaller than the thing it waited for

`check_ceremony_reads` went red on a configured sweep and green standalone four minutes later on the same
tree, which is the shape of the flakiness finding below. It is not that. Tracing the mechanism instead of
re-running it found a defect that had been shipping in both directions.

The layer measures what the arrival plate does to a rope hanging in a dark shaft, and it first waits for a
frame with nothing else happening on it. That wait is not decoration: `_rope_x` takes the brightest pixel
in the column, so a lesson bubble drawn over the rope BECOMES the rope, and every reading after it is of
the wrong pixel. The wait could not do its job:

| quantity | value |
|---|---|
| what the frame needs to clear when a lesson fires behind the plate | `Hud.ARRIVAL_HOLD` 3.4s + `Hints.SHOW_SECONDS` 9.0s = **12.4s** |
| what the wait allowed | `QUIET_MAX` 600 physics frames = **10.0s** |

The same file's surface wait is `SURFACE_QUIET_MAX`, 1500 frames, which does cover it. The asymmetry is
the evidence: the wider budget was already discovered empirically at the other site.

**The green was the dangerous outcome, not the red.** Promotion sets `_life` to `SHOW_SECONDS` with nothing
shown yet, so the first frame of the fade-IN reads `hint_alpha` 0.00 exactly. A threshold on the alpha
cannot tell that frame from a bubble that has worn out, and the wait exited on it. Both observed outcomes
were one defect: the passing run sampled the promotion frame, the failing run sampled a frame later and
then ran out of budget.

The fix makes the frame quiet by construction rather than by waiting for it, through the game's own
returning-player path (`restore_taught` then `resync`) with the ids read off the lesson tables so a lesson
added later is covered unasked, and moves the exit condition off the alpha onto the state behind it. No
budget was raised.

    godot --script res://tools/check_ceremony_reads.gd
    PASS: the reference frame carries no interrupt of its own
          (waited 146 frames; arrival 0.00, lesson none, 0 queued, hint 0.00)
    check_ceremony_reads: PASS (9 asserted)

    with the pose removed, which is the control:
    FAIL: ... (waited 600 frames; arrival 0.00, lesson rope, 1 queued, hint 1.00)

The control names the rope lesson the layer's own comment was written about, with a second one queued
behind it: two bubbles at nine seconds each, on a ten second budget.

## Area 3 — two layers reported on the art when the art had not been drawn

Both machine-judging layers in the flakiness table below emit findings about sprites. One says twenty
machines are drawn as the same shape, twenty-eight pairs of them pixel-identical. The other says the Forge
and the Generator have no state cue at all, 0.0 against 0.0. **Neither layer could distinguish that from a
frame with nothing rendered in it**, and every control they already carried passes its hardest on exactly
that frame: an unmoving camera is unmoving, still-frame noise is at its quietest when there is no picture
to be noisy, and two synthetic masks do their arithmetic without looking at the screen.

`check_grapple_reads` is the counter-example that makes the gap legible. Its red was its own positive
controls firing, in its own words: the miner was not drawn, the preview drew nothing. Same environment,
same sweep family, and that layer refused to report geometry. The other two did not have the control to
refuse with.

- **`check_machine_identity` already computed the missing quantity.** Coverage, the share of the cell each
  machine puts material into, sat in the printed table and was never asserted. It is asserted now against
  this run's own empty-stage reading, and when it fails the pair statistics are not computed at all,
  because a number taken off an empty stage gets quoted as if it were about the machines.
- **`check_machine_state`'s control existed only in prose.** The comment over its empty-stage capture calls
  that capture "the control for saturation and for did anything change at all". The capture was taken,
  printed, and never compared to anything. It now has a floor read off five shots of the cell with nothing
  on it, and a subject that fails presence is reported as missing rather than accused of a weak cue.

`check_machine_identity` also photographs the empty stage once more at the end and requires it to FAIL the
bar the machines cleared, so the bar is shown able to fail on real data every run. It works there because
that layer judges in mask units, where an empty cell scores a hard zero.

**The same negative half was tried on `check_machine_state` and withdrawn**, which is recorded in that file
rather than quietly dropped. Scored against the reference the subjects were scored against, the end-of-run
empty cell came back 7.98 levels away from it while the bar stood at 3.87: the noise term is a five-shot
burst and sees fast noise only, where the cell wanders further than that over the minutes a run takes.
Deriving the bar from the run-length wander instead would make the control measure the quantity that
defines it. So that layer carries the positive half only and does not claim a demonstrated-failable bar.

**And the attempt cost a lesson worth more than the control.** Taking the empty reference inside the subject
loop put ten physics frames between `set_solid` and `place_machine`. With nothing else altered, on the
pre-change file:

| Generator | working face | D_state | ratio against a 3.0 bound |
|---|---|---|---|
| placed immediately, as the layer always did | 203.5 | 136.9 | 4.07 |
| ...again | 203.7 | 137.0 | 4.48 |
| placed ten frames later, nothing else changed | 167.8 | 100.5 | **2.96, DOES NOT READ** |

Ten frames of fixture timing decide that subject's verdict. The references are gathered in a pass of their
own now, one per distinct floor material, before any machine is placed, so the shutter does not move. **The
finding that remains open is not the control: it is that this layer's ratios are a function of when it
photographs.** The same three subjects have read 16x / 10x / 4.4x when `MOTION_MARGIN` was calibrated,
8.6x / 5.0x / 3.0x with the reference inside the loop, and 6.9x / 6.3x / 28.1x with it in a pass of its own.
A bound of 3.0 chosen from a measured gap cannot be trusted against numbers that move like that, and
re-deriving it needs the negative population it was derived against, which was the pre-gate Drill at 1.9x
and no longer exists. **That decision is queued and not taken here: nothing was moved to accommodate a red.**

Mutation controls, both layers, both exit 1:

    masking every subject against itself, which is what a blank stage looks like:
      FAIL: CONTROL: every machine put more of itself on the stage than still-frame noise does
            (0.0000) - DREW NOTHING: Blast Furnace (0.0000), Power Conduit (0.0000) ...
      the stage did not draw, so the pair statistics are not computed

    photographing the empty cell in place of the working one:
      FAIL: CONTROL: every subject was actually drawn on the stage - NOT DRAWN: Forge (0.00
            levels against the empty stage, drift 1.24), Drill (0.00), Generator (0.00)
      and the SILENT accusation against those three does not appear

## Area 3 — which layers can fail, counted

Positive controls were being added one layer at a time, on suspicion. This is the population, so the next
one is chosen by evidence instead. The rule: a layer that asserts anything, and whose assertions are at
least half of the form `_check(something.is_empty(), ...)`, passes over an empty list, and an empty list is
what a dead instrument produces. Those are the layers where a control matters most.

    grep -oE 'res://(tools|tests)/[a-z_]*\.(gd|sh)' tools/run_harness.sh | sed 's|res://||' | sort -u > /tmp/reg.txt
    python3 - <<'EOF'
    import io, os, re
    reg = [l.strip() for l in io.open('/tmp/reg.txt') if l.strip()]
    ctrl, chk = re.compile(r'"\s*CONTROL'), re.compile(r'_check\(')
    emp = re.compile(r'_check\(\s*[A-Za-z_][A-Za-z_0-9]*\.is_empty\(\)')
    rows = []
    for f in reg:
        if not os.path.exists(f): continue
        s = io.open(f, encoding='utf-8', errors='replace').read()
        n = len(chk.findall(s))
        if n: rows.append((f, n, len(emp.findall(s)), bool(ctrl.search(s))))
    risky = [r for r in rows if not r[3] and r[2] > 0 and r[2] >= r[1] * 0.5]
    print(len(rows), sum(1 for r in rows if r[3]), len(risky), [r[0] for r in risky])
    EOF

| | before | after |
|---|---|---|
| registered files that assert anything | 99 | 99 |
| ...carrying an assertion labelled CONTROL | 17 | **19** |
| ...majority-emptiness with no such label | 5 | **3** |

**And the five were read rather than counted**, because the label is a convention and not a property. Three
of them are controlled under other names: `check_item_reads` plants an unknown item and requires it caught,
`check_encoding` runs its detector over deliberate mojibake, `check_save_frontier` requires a field to have
changed. The two that were not are both COLLISION DETECTORS that had never been shown finding a collision:

- **`check_gamepad`** asserts that no pad input drives two verbs. A label function that never collides makes
  that unfalsifiable, while `owner.size()` keeps counting up and the non-vacuity floor at the bottom of the
  file keeps reporting health. That floor covers a table with no pad bindings; it does not cover a detector
  that cannot detect.
- **`check_status_reads`** asserts that no two different jobs share a mark. Its two drift scans control each
  other, one reading sim to table and one table to sim, so a scanner that read nothing is caught by the
  second even though it satisfies the first. This rule has no such partner.

Each detector is a function now that the control and the real scan both call, run over two tables built
from data the game really carries: one where the collision is present, one where it is not. Forcing each
comparison false makes the positive half fail and **leaves every real assertion in both layers passing**,
which is the finding stated as an experiment.

## An open flakiness finding, recorded rather than absorbed

Four configured sweeps were run on effectively one tree while reconciling the population above. The only
working-tree difference between them was two markdown files and one comment-only edit to `check_base.gd` —
comment-only verified by counting non-comment lines in its own diff, with a planted code line as the
positive control that the count can register one.

| run | verdict | failing layers |
|---|---|---|
| 1 | 110 PASS / 0 FAIL / 0 SKIP | — |
| 2 | 109 PASS / 1 FAIL | `check_grapple_reads` |
| 3 | 108 PASS / 2 FAIL | `check_machine_identity`, `check_machine_state` |
| 4 | 110 PASS / 0 FAIL / 0 SKIP | — |

**Every failing layer judges pixels, and every one passed standalone immediately afterwards**, on the same
tree, within minutes. The failures are degenerate readings rather than wrong ones: the miner's own
silhouette measured 0.0 levels of edge over 1071 pixels where it normally reads 87; three masks came back
at 0 px; 28 of 190 machine pairs were drawn IDENTICAL; a Forge read state 0.0 against motion 0.0. A body
that measures as absent is a capture that did not happen, not a body that stopped being drawn.

`check_grapple_reads` is already registered `add_excl`, and the exclusivity defect that used to make it red
is patched, with the before-and-after concurrency measurements recorded in the runner. So this is not that.

**It is left classified as environmental and unexplained rather than dismissed**, with all four sweeps
retained under `docs/tracelog/sweeps/` including the two reds, because a red that is deleted once it stops
reproducing is a red nobody can ever study.

**The shader-cache hypothesis was tested and is weakened, not retired.** Its precondition is real and is
now verified rather than asserted: the harness redirects `HOME` so `user://` is isolated per repo root,
Godot keeps its shader and pipeline caches under the user directory, and of the fifty isolated homes on
this machine **none contains a single file matching `*shader*`**, against a real user directory that has
both `shader_cache/` and `vulkan/`. Every harness run genuinely boots with nothing cached.

What the hypothesis predicts is a degenerate early frame, and a probe that boots the scene and captures the
viewport at eleven offsets from frame 0 to frame 90 does not find one:

| frame | 0 | 1 | 3 | 8 | 21 | 55 | 90 |
|---|---|---|---|---|---|---|---|
| mean luma | 63.34 | 62.97 | 62.71 | 62.66 | 62.68 | 62.54 | 62.67 |
| distinct tones | 227 | 228 | 233 | 231 | 229 | 227 | 228 |
| black | 0.7% | 0.7% | 0.7% | 0.8% | 0.7% | 0.8% | 0.7% |

The first captured frame is as fully rendered as the ninetieth, and the layers that went red wait 40 to 90
frames before they photograph anything.

**The limit of that result, stated rather than left for a reader to notice.** The probe ran ALONE. Both reds
appeared only inside a sweep, under a dozen concurrent engine processes, and no run of this probe has been
taken in that condition, because the machine lock exists precisely to stop concurrent engine runs. So the
treatment was not applied in the domain where the symptom lives, and a null from outside the domain
excludes nothing. The probe is kept at `tools/_scratch_cold_pipeline.gd`, untracked and registered nowhere,
so the next attempt starts from a working instrument.

**What changed since, and what did not.** `check_grapple_reads` leaves this group: its red was its own
positive controls firing, which is a layer working rather than a layer confused. The two machine layers
stay in it. Nothing here reproduced them and nothing here diagnoses them, and the state layer's red had
the Drill at 11.8 levels against 14.1, which is a machine that drew. What the section above changes is only
that the next occurrence can say which of the two candidate causes it was: a frame that did not render now
withholds the art finding and says the stage did not draw, and sprites that really are alike are reported
with the coverage table standing behind them. One mechanism is worth testing and is **not** claimed here: the
harness runs with shader caching disabled, so every headed layer recompiles its pipeline on boot, and a
frame captured before that pipeline is warm would read exactly like these. That is a hypothesis with a
plausible shape and no evidence yet, and the honest note is that nobody has tested it.

## Exit condition

All six areas closed, the full suite green on `main`, and every remaining stand-down carrying a written
reason. No new gameplay work begins until then.

**Where that stands.** Areas 1, 2, 3, 4, 5 and 6 are closed. The configured sweep is green on `main` at
`112 PASS / 0 FAIL / 0 SKIP`, and each of the six stand-downs carries its reason in `tools/stand_downs.txt`
and resolves on every run of its layer. One finding remains open and is not an area: the pixel-layer
flakiness below, which is classified environmental and unexplained with all four sweeps retained.

It is worth being exact about what "the full suite green" can mean here, because the runner is. A sweep
with a display cannot reach exit 0 and never will — three of the stand-downs are structural — so the
reachable target is **exit 4 with exactly the registered six and no others**, which is what the sweeps in
`docs/tracelog/sweeps/` show. "Configured sweep passed with six documented stand-downs" is the accurate
sentence; "all 112 layers fully asserted" is not.
