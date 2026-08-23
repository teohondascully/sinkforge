# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. An area is CLOSED only where the evidence is named, and a partial area is
stated as partial rather than rounded up.

**FRAME FOR EVERY NUMBER BELOW.** This page is two documents. The **disposition table** immediately below
is a present-tense claim and has to be true today. **Everything after it is a chronological log**: each
section was written when its work landed and records what was measured then, so its numbers are readings
at their own date and are not restated as the suite grows. A heading that says the assertion floor reaches
109 of 113 and a later one that says it reaches every layer in the suite are both correct — they are
waypoints, not contradictions. Treat a count in the log as evidence that an experiment happened and
produced that value, and re-derive from the repository before quoting one as current. Where a section
makes a present-tense claim about *status* rather than reporting a measurement, staying true is that
section's job; the exit condition carries a dated re-read for exactly that reason.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Closed** | `world_renderer.gd` 4601 -> 3557 lines across three extractions (3569 today — the 3557 is what the extractions achieved, not a current size, and this row is in the present-tense table so it says which is which), each cut against a measured ranking and each proven equivalent before it landed. Every candidate still in the file is rejected with its numbers rather than with a plan to get to it. `main.gd` and `factory_sim.gd` were measured and have no separable seam: their coupling is semantic, not a god-file boundary. Closed because the measurement says there is nothing left worth cutting, not because the time ran out. |
| 3. Harness quality | **Closed** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. A later audit found 58 of the 89 layers then inheriting `check_base.gd` hand-rolling the verdict protocol, and so missing the base class's refusal of a green that asserted nothing. The measured before-state was **55 registered layers exiting 0 having asserted nothing at all**. All 92 inheritors now reach exit 0 only through `_verdict()`, none of them moves an assertion counter itself, and both rules are gated by `check_verdict_route` with a shrink-only exemption list that is empty. |
| 4. Performance and maintainability | **Closed** | a formal pass found seven full-grid loops, one of which ran every frame; both cliffs are fixed and the residual is measured at 2.74ms, which the charter's *fix confirmed cliffs only* answers rather than defers. The frame SLO has been evaluated on the host it was written for, and its allowances — one machine's numbers applied to any machine — are now a per-host registry that refuses rather than borrows. The hidden-coupling bullet found a live defect: a tree could grow inside a bazaar and the cache would not notice, reachable through an ordinary player verb. Fixed, and gated behaviourally plus by writer population. |
| 5. Documentation and contributor readiness | **Done, with one gap now named** | architecture docs reconciled with executable behaviour, contributor and release workflow written, repository map present, and layer-count drift is gated by `check_doc_counts` against the runner's registration. **That gate covers the five phrasings it enumerates, and only those.** It deliberately refuses a loose `[0-9]+ layers`, because "17 layers" and "16 layers" are correct statements about other populations — so it trades false positives for false negatives, and a total written in a sixth phrasing is ungated. On 2026-08-23 that was not hypothetical: the README's CI table said "all 110 layers" twice and "110 PASS ... of 110" once, against a suite of 114, while the gate passed. Corrected at `36144de`; widening the gate is harness expansion and wants a priority ID. The claim that "a stated total cannot rot" was too strong and is withdrawn. |
| 6. Public presentation | **Complete, and decaying between audits** | the README explains the engineering system and the test-surface ratio, history and media are retained deliberately with clone guidance, and the repository is legible to a reviewer in their first ten minutes. **The same caveat as Area 5, and it is the sharper one:** on 2026-08-23 the README's CI section was found describing a 110-layer suite and explaining a red that had been repaired days earlier, having drifted silently while three gates passed over it. Corrected at `36144de`. "Explains it accurately" is not a property a repository holds; it is one that decays with every commit, and nothing currently gates it. |

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
"a layer that has nothing to assert must `_skip_layer()` or `_void_layer()` and say why" — and prints the assertion count as part of the
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

## Area 3 — the runner's own two protections, exercised rather than assumed

The verdict gate carries two checks that nothing in the suite can trigger on purpose: did the engine fail
to LOAD a layer, and did a layer produce no output at all. Both exist because `godot --script` exits 0 when
a script is missing or unparseable, so a layer that never ran reports PASS. Both were written from measured
output. **Neither had been fired in a long time**, and a protection nobody has seen fire is a claim.

Both were fired, by registering a layer for one subset run and taking it out again:

    a path to a file that does not exist
      [ 1/ 2] check_ghost (a layer that does not exist)   PASS   1s        <- the table says PASS
      layer logs: 2   engine-level load failures: 1   silent: 0
      !! THESE LAYERS DID NOT RUN - the engine could not load them
      HARNESS_EXIT=0 ... !! exiting 7: the sweep above is NOT A RESULT

    a layer that boots and calls quit(0) without printing
      [ 1/ 2] check_mute (a layer that says nothing)      PASS   1s        <- the table says PASS again
      layer logs: 2   engine-level load failures: 0   silent: 1
      !! THESE LAYERS PRODUCED NO OUTPUT AT ALL beyond the engine banner
      HARNESS_EXIT=0 ... !! exiting 7: the sweep above is NOT A RESULT

**In both cases the layer table shows a green row and the run is still rejected**, which is the design: the
table classifies on exit codes, and an exit code is exactly what a layer that never ran is best at
producing. The gate names the layer in both branches rather than only counting it.

## Area 3 — a gate that ran in one place, and that place had been red for days

The published head carried a failing CI check while the local suite reported `112 PASS`. The failing check
was `capture_manifest.sh --check`, and it ran in exactly ONE place: the CI authorship job. So the person
running the sweep by hand to decide whether to commit was the one reader it could not reach, and a red that
nobody sees is a gate that has stopped working while still being correct.

**Censused rather than assumed.** Every `run:` step in the workflow was listed against the runner's
registrations: `capture_manifest.sh --check` was the only CI step with no local counterpart, and
`check_trailers.sh` was already registered. The population was one and is now zero. The gate is registered
through a wrapper that exists only to pass `--check`, because the runner takes a path with no arguments and
the generator's default mode rewrites a tracked file: registering the generator itself would have a sweep
mutate the tree.

**And the staleness is explained rather than regenerated away.** A regenerated tracked artifact with no
reason attached cannot be told apart from one regenerated to make a red disappear. Only column three moved,
on 51 of 52 rows: names, dates and recipes byte-identical, and the grouping summary unchanged at 37 / 8 /
4 / 2 frames with only its four labels rebased. That is the signature of a history rewrite and not of a
renderer change. The identifier is a hash of the drawing sources as they stood in the tree of the commit
that last wrote each capture; the rewrite moved which commit `git log --follow` lands on, so the trees moved
while the author dates the same lookup provides were preserved.

**The part worth keeping is what the rewrite's own verification could not see.** It asserted the tree
byte-identical, and it was. *A byte-identical tree is exactly what a stale generated file gives you.* A
file whose content depends on commit identity does not survive a rewrite, and no tree comparison can
register that it has gone stale.

## Area 3 — the floor between "asserted nothing" and "asserted everything"

`_verdict()` refuses a green that asserted NOTHING, and that was the only floor in the suite. Between
nothing and everything there was none at all: measured on a green sweep, the widest layer here makes 112
assertions and the median layer makes eight, so a layer could have fallen from 24 to one, silently, and
still printed PASS. An early return after a guard, a loop whose population went empty, a block moved behind
a condition that is now always false, all of them leave a green. Both of tonight's instrument defects were
of that family, and neither was caught by the count.

**The count turned out to be worth holding, which was measured before anything was built.** Across three
consecutive sweeps of the same 91 layers, the only counts that moved were the five layers edited between
those sweeps, and each moved by exactly the number of assertions added or withdrawn:

| between | layers whose count changed |
|---|---|
| ceremony-quiescence → machine-presence | `check_machine_identity` 8→10, `check_machine_state` 6→8 |
| machine-presence → detector-controls | `check_ci_coverage` 17→19, `check_doc_counts` 19→21, `check_gamepad` 7→9, `check_status_reads` 9→11, `check_machine_state` 8→7 |

Nothing else drifted, on 91 layers, three times. So `tools/assert_floors.txt` holds one row per layer with
the floor set to the observed count rather than a margin below it, because a margin absorbs the first real
loss and that loss is the whole subject. `tools/assert_floors.sh` reads a finished sweep's per-layer logs
and is called from `harness_cleanup` beside the verdict gate. It is deliberately not a harness layer and is
named so it cannot be taken for one: no layer has the sweep's logs.

**It judges only a full configured sweep with the recorded stand-down set.** A subset has no opinion about
layers it did not run, and a different stand-down set means different assertions were reached, so it says
it did not judge rather than inventing a verdict. The comparison is a function the real pass and the
control both call: one row is raised by one against a copy of what the sweep just reported, the same
function has to catch it, the untouched copy has to stay quiet, and if either control misbehaves the gate
says the instrument is broken and prints no verdict at all.

**`HARNESS_QUOTABLE` is a second key and not a second `HARNESS_RESULT` line.** They answer different
questions. `HARNESS_RESULT` says the run happened, and after a floor failure it is still correctly `yes`.
What stops being true is the sentence printed under it, that the verdict may be quoted. Two lines carrying
one key is a reader taking whichever one grep hands them first.

    bash tools/run_harness.sh
    112 PASS / 0 FAIL / 0 SKIP of 112, six documented stand-downs
    HARNESS_EXIT=4   HARNESS_RESULT=yes
    assert_floors: PASS - 108 layers still assert at least what they did (control: check_agility at 7)
    HARNESS_QUOTABLE=yes

    with one floor raised by one, which is what a layer going quiet looks like:
    112 PASS / 0 FAIL / 0 SKIP of 112
    assert_floors: FAIL - DROPPED: check_agility asserted 7, floor is 8
    !! exiting 7: the sweep above is NOT A RESULT

**A second rule followed, and it brought in the four largest bodies of assertions in the suite.** The gate
reached 91 of 113 rows; the 22 it could not reach have no `_check` to count and print one PASS line per
claim instead, which is the same quantity arrived at differently. Among them: `sim` at 526 assertions,
`stress` at 447, `power_water` at 203, `worldgen` at 147. **Nothing held any of them.** `sim` could have
fallen from 526 claims to one and the sweep would have reported PASS. Coverage is 108 of 113 now, each row
carrying the rule that produced it, and the same three-sweep stability check was run first: identical
counts, no membership drift.

Five rows remain unreachable and are named in the floors header rather than left to be discovered:
`check_capture_manifest`, `check_prose`, `check_score`, `check_water_audio` and `measure_player` each print
a verdict in a shape neither rule counts. They are not exempted; holding them needs a third rule or a
change to what they print, and neither is written.

The control that matters most for a second rule is the one that breaks the rule itself. With the PASS-line
pattern forced to match nothing, all 17 rows it reaches report `MISSING` rather than vanishing: **a dead
rule does not quietly shrink the population.**

Four more controls were exercised and are listed here so nobody has to rediscover which paths were tested:
a layer with no floor row reports `UNFLOORED`, a floor with no layer reports `MISSING`, a subset and a
mismatched stand-down set each report that they did not judge, and forcing the comparison's field separator
wrong makes the gate refuse rather than report the clean tree it would otherwise have found.

**One of those controls passed for the wrong reason first**, which is recorded because it is the same
failure the gate exists to catch. The stand-down-mismatch control was driven with a process substitution,
the script read the summary twice, the first `grep` consumed the pipe, and the second saw nothing and
skipped the check. The control reported PASS. The script reads the summary once now.

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

## Area 3 — which layers give the same answer twice, measured

Every red this month came from a layer that judges pixels, and "the pixel layers are flaky" was folklore.
`tools/sweep_drift.py` turns it into a measurement: two finished sweeps taken on trees where no layer
changed, compared per layer on the numbers inside its `PASS`/`FAIL` lines only. A duration or a seed in a
diagnostic can move without meaning anything; a number a threshold is compared against cannot.

**91 of 107 layers reproduce EXACTLY.** That is the control as much as the finding: exact reproduction is
the norm here, so the movers are a real subset rather than noise spread over everything. Stable across
three independent same-tree pairs:

| layer | how many judged numbers moved | the widest single move, relative |
|---|---|---|
| `check_snap_frame` | 4 of 8 | 100% |
| `check_water_reads` | 3 of 8 | 100% |
| `check_lock` | 2 of 29 | 68% |
| `check_grapple_reads` | 9 of 25 | 43% |
| `check_ceremony_reads` | 6 of 20 | 16% |
| `check_hud_layout` | 10 of 206 | 12% |
| `check_dig_hitch` | 7 of 38 | 2% |
| `check_rock_reads` | 4 of 8 | 1.5% |

**THE FIRST VERSION OF THIS TABLE RANKED BY THE LEFT COLUMN ALONE AND WAS QUOTED AS A RISK RANKING. It is
not one, and neither column is.** Both were caught over-reporting on this very data, in opposite
directions, which is why both are printed:

- **A count of movers over-reports last-digit wobble.** `check_rock_reads` led that first ranking at 50%,
  four of eight. The largest of those four was a legibility cue reading 87.68% against a floor of 75.00%
  on one run and 87.55% on the next. Twelve points of headroom; nothing at risk.
- **A relative magnitude over-reports small integers.** `check_snap_frame` leads this one at 100%, because
  a control line went from `198193 changed against 0` to `198193 changed against 1`. A count of 0 to 1 is
  a 100% move and that control needs a factor of four.

The quantity that WOULD rank risk is headroom consumed: movement as a fraction of the distance to the
assertion's own bound. It is deliberately not computed. **Only 159 of 3266 assertion lines state a bound at
all**, and pairing a stated bound with the right value inside a free-text line is a guess that would be
silently wrong on some of them — which is the failure this whole section is about. The tool says WHERE TO
LOOK and refuses to say HOW BAD.

**Three groups, and only one is a defect.** Layers whose SUBJECT is time — `check_frametime`,
`check_dig_hitch`, `check_lock`, `check_pacing` — belong on this list and are sound; `dig_hitch` moving
exactly 7 of 38 in all three pairs is a duration measurement doing its job. Layers whose INPUT legitimately
changed between the two sweeps — `check_trailers` reads commits, `check_prose` reads files — are evidence
the comparison is alive rather than findings. What remains is the layers that judge PIXELS, and for those
a moved judged number means the verdict carries a random component.

**Read with that caveat, the set still coincides with the red history**: `check_grapple_reads`, `check_material_grammar` (whose own
closure figure is recorded elsewhere in this document as one draw of 76.72 / 78.45 / 98.28 / 100.00), and
`check_ceremony_reads`, whose mechanism was found and fixed. `check_machine_identity` and
`check_machine_state` are the instructive exception: their diagnostics move 17% and 30% while their judged
numbers hold, which is what assertions built on set emptiness rather than on a magnitude look like. It also
means the drift census would NOT have predicted their reds, and saying so is the honest limit of it.

Two controls run against the very logs being censused, and nothing is printed if either misbehaves: a
sweep compared against ITSELF must report zero movers, and one digit changed inside one `PASS` line must
be caught with only that layer named. Forcing the comparison to find nothing is refused by the second;
forcing it to flag everything is refused by the first.

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

**Where that stands — re-read 2026-08-23, and the previous version of this paragraph had stopped being
true without changing.** Areas 1 through 6 are closed, with the qualifications now written into Areas 5
and 6. **The suite is not green.** The configured sweep at `e89eef9`, tree clean from launch to verdict,
reads `113 PASS / 1 FAIL / 0 SKIP of 114`, and the single red is `check_grapple_reads` (`GR-06`). Each of
the six stand-downs a display sweep resolves carries its reason in `tools/stand_downs.txt`. This paragraph
previously read `112 PASS / 0 FAIL / 0 SKIP`; that was true when it was written and was left standing
afterwards, which is the failure mode the frame at the top of this file exists to make visible.

**So has the programme exited?** The condition above asks for "the full suite green on `main`", and by
those words, no. The words predate the red-disposition policy this work now runs under, in which a red is
classified rather than counted. `GR-06` is P3, scoped to grapple presentation, director-owned, with a
measured next step and an expiry, and it fails identically on a real GPU and on CI's software rasterizer —
so it is a finding about the game, not an unexplained instability. Treating it as a global stop would
freeze the whole programme over something that blocks one surface. The accurate statement is that **five
criteria hold outright and the sixth holds in substance but not in the words it was written in.** It is
the words being corrected here, not the criterion, and the criterion is not being relaxed to fit.

**And "one finding remains open" is no longer true either.** Beyond the pixel-layer flakiness below, which
is still classified environmental and unexplained with its sweeps retained, `FLOORS-UNJUDGED` and
`DOC-COUNTS-NARROW` were both found after this section was last written, and both qualify areas marked
closed: the floors gate declines to judge either CI job, and the doc-count gate checks five enumerated
phrasings rather than a population. Neither reopens an area. Both are reasons to stop reading "closed" as
"nothing left to find".

It is worth being exact about what "the full suite green" can mean here, because the runner is. A sweep
with a display cannot reach exit 0 and never will — three of the stand-downs are structural — so the
reachable target is **exit 4 with exactly the registered six and no others**, which is what the sweeps in
`docs/tracelog/sweeps/` show. "Configured sweep passed with six documented stand-downs" is the accurate
sentence; "all 112 layers fully asserted" is not.


## `check_grapple_reads` does not register the aim preview

**This section replaces one written an hour earlier under the heading "the sky control was measuring an
animation". That account was wrong, and so was the one before it. Both are kept below, because the way
this was got wrong twice is the useful part.**

The layer photographs the grapple's aim preview by differencing two otherwise identical frames, once
against dark rock and once against open sky. The dark-rock number carries the assertion — `GR-04`'s claim
that the cable stays readable underground — and the open-sky number is reported beside a control asking
whether the preview drew anything at all, `_count(guide) > 60`.

Flip every `AIM_GHOST_OFF = false` in a copy of the layer to `true` and the preview is never drawn at all.
The measurement does not notice:

| | preview drawn | preview never drawn |
|---|---|---|
| open sky, mask pixels | 62 … 9264 (n=16) | 15 … 10076 (n=8) |
| open sky, median | 646 | 471 |
| dark rock, edge levels | 2.4 – 3.7 (n=9) | 1.9 – 3.5 (n=8) |
| dark rock, mask pixels | 2692 – 5170 (n=9) | 2856 – 4539 (n=8) |

The subject-removed runs reach higher than any run with the preview on. Their medians are the same order.
Every range overlaps. Turning off the thing being measured is not visible in the number that measures it,
which means the green this layer has been printing says nothing about the aim preview, and the design
sentence it publishes — `GR-04 REPRODUCES`, quoting contrast levels on rock and on sky — is quoting the
residual. The floor of 60 is not merely low: a run with no preview whatsoever read 196 against it. The
2026-08-22 red at 0 pixels was that residual landing small, not the preview going missing.

### The two wrong explanations

The spread across sixteen same-tree runs was first read as cloud drift: `moving` is subtracted from the
mask before it is counted, and on the surface `moving` is drifting cloud, so a small count could be a
preview the difference mask had eaten. That is a real mechanism and it is not this one. Measuring the
eaten corridor over the same lane with the same body cut refuted it — eaten and survivor move together
across the spread, not against each other.

It was then read as a reveal animation caught mid-draw, because the small masks are spatial prefixes of
the large ones: same start near the hand, stopping early, with the endpoint ring present in the large runs
at (1135, 357) and absent from the small. That is a real pattern in the dumps and it is still unexplained.
It is not a reveal, because `_draw_aim_ghost` has no state — it is a dotted stub capped at `AIM_STUB_MAX`
plus a ring, recomputed whole every frame, with nothing drawn in between.

Both explanations were consistent with the data in hand and both survived until the cheap decisive test
was run: remove the subject and see whether the instrument notices. Neither hypothesis needed to be
settled to answer the question the layer exists to answer. The prefix geometry is a live loose end, but it
is a question about what the mask *does* contain, and that is downstream of the finding that it does not
contain the preview.

### What it was: the lamp, and a mask built at the wrong time scale

The miner's head-lamp throws an amber pool over whatever is being aimed at, and it breathes by design on
`0.030 * sin(t * 11.0) + 0.020 * sin(t * 27.0)` — periods of 34.3 and 14.0 frames. The corridor being
photographed sits inside that pool. The old block differenced the shot against a reference **four** frames
away and then excluded the pixels that moved between two references **thirty-eight** frames apart. On one
run, in the window the corridor occupies:

| pair | separation | slow periods | pixels over `DRAW_LEVEL` |
|---|---|---|---|
| reference to shot | 34 fr | 0.99 | 1645 |
| reference to reference | 38 fr | 1.11 | 2642 |
| shot to reference | 4 fr | 0.12 | **15716** |

The long pairs come back nearly in phase and see almost nothing, so the exclusion they build excludes
almost nothing. The four-frame pair catches the flicker mid-swing. Of that pair's 15892 differing pixels
frame-wide, 15716 were inside the corridor. A difference taken at one separation cannot be removed by a
mask built at another.

### The repair, and the one that did not work

Widening the exclusion was tried first: still pairs at the measurement's own four-frame separation,
unioned across a full lamp period so every phase is covered. It fails, and it fails informatively — the
corridor lost 4720..12364 pixels and the preview kept 0..167, three runs in four going red. The preview is
drawn **on top of** the pool and shares every pixel with it, so any mask wide enough to cover the flicker
covers the preview too. That result is kept in the layer's comment, because the next person to reach for a
wider exclusion should see it already measured.

What works is posing the clock. `SF_ANIM_FROZEN=1` holds `_anim_time`, the free-running cosmetic clock
that drives the lamp flicker, the ping ring, the chevron bob, the dig pulse and the ore glints, and which
never feeds the sim. It is the same move the repository already makes on the pointer, through
`SF_AIM_GHOST_OFF`, for this same measurement. The layer holds it for the length of the sky block only.

The pre-registered acceptance test — fixed before the repair was written, and not a threshold — was that
the subject-removed run must separate from the subject-present run:

| | preview drawn | preview never drawn |
|---|---|---|
| mask pixels | 182, 182, 189, 182 | 0, 0, 0 |
| edge levels | 157.1, 158.4, 159.6 | 0.0, 0.0, 0.0 |

A spread of 62..9264 became 182..189. The residual is exactly nothing. The union exclusion is kept as the
travelling control on the pose: it read 4720..12364 unposed and reads 0..162 posed, so a corridor still
losing thousands of pixels means something is alive that `_anim_time` does not drive.

The floor stays at 60. It now sits between a residual of nothing and a signal reproducing to within seven
pixels, which is the first time it has meant anything. It was not raised: six samples on one machine can
say the gap is real and cannot say where inside it a bound belongs.

### The dark-rock half, and the red it uncovered

The same fault and the same fix. That block's exclusion is unioned from pairs thirty frames apart and its
reference, `bg`, sits 120 frames and three and a half lamp periods before the shot. The churn control
above it must keep running on the live frame — it asserts the frame is mostly still, and a held clock
would make it unfalsifiable — so only the capture pair is posed, against a fresh reference taken with the
clock already stopped. The pose is released on every path out, including the one where the hook fails.

| dark rock | preview drawn | preview never drawn |
|---|---|---|
| edge levels | 141.3, 142.6 | 0.0, 0.0 |
| mask pixels | 148, 138 | 1, 0 |

Was 2.4–3.7 against 1.9–3.5, which is no separation at all.

**This turns `GR-06` red, and the red is real.** The assertion is that the miner out-reads their own
telemetry, `body_edge >= guide_edge * 1.15`, and it is asserted on purpose: a tool easier to see than the
person holding it has inverted the frame. It now reads **88.2 levels for the miner against 141.3 for the
preview**. It was passing because the preview's number was p90 over a mask that was mostly lamp shimmer;
measured over the preview itself it is forty times larger. Both quantities are the same statistic — p90 of
a four-neighbour maximum gradient, in levels — so this is not a ruler mismatch, and `_edge_gain` subtracts
the background's own gradient so the preview is not being credited with the rock behind it.

`BODY_MARGIN` was not touched and the assertion was not retracted. Which way this resolves is a design
call, not a harness one: either the aim mark is genuinely louder than the miner and should be quietened,
or `GR-06` wants a different pairing. It is queued as an authorization-boundary item.

### Still open

The layer's other reported figures were all computed from the blind masks and are superseded. `GR-04
REPRODUCES` in particular now quotes real contrast on both surfaces for the first time.


## Which other layers cannot see their subject: all of them can

`check_grapple_reads` was blind because it photographed a cue by subtracting two frames and its bar was set
against a temporally distant reference. That shape is not unique to it, so the population was enumerated
rather than guessed: of 15 layers that capture pixels at all, 5 contain a temporal-difference idiom, and
of those `check_dig_hitch` is not a cue-photographing layer — it asserts bake region counts and carries its
own `cells > 0` witness. Four remain.

Each was tested the way the grapple layer should have been tested first: remove the subject in a scratch
copy, run it, and see whether the layer notices. Reading the controls is not the test — the grapple layer
had elaborate ones and was blind behind them.

| layer | subject removed by | result |
|---|---|---|
| `check_machine_state` | idle frame replaced by a second active frame | **FAIL**, every machine `SILENT`, state ≡ motion (11.9/11.9, 14.5/14.5, 2.7/2.7) |
| `check_machine_identity` | machine taken off the stage before its portrait | **FAIL**, `DREW NOTHING` for all 20 |
| `check_bake_idempotent` | the dig loop neutered | **witness FAILS**, "that column moved 0" |
| `check_grapple_reads` | `AIM_GHOST_OFF` forced true | repaired this run; 182 px drawn against 0 removed |

All three unrepaired layers catch it, and each catches it in the right place: `check_machine_state`'s other
controls — presence, drawn-on-stage, renderer/sim agreement, clipping — all still passed, so the failure
lands on the cue and not on the driver.

`check_bake_idempotent` is the one worth keeping in mind. With the digs removed its **headline claim still
passes**: "12 of 12 cells nobody dug hold their colour after 8 digs elsewhere (worst drift 0, tol 1)". Only
the witness fails. A layer that asserts two things are the SAME is satisfied by a build where nothing
happened, and the only thing standing between that and a green is a control the layer already has. It is
load-bearing, not decorative, and this run is the demonstration.

What separates the grapple layer from these three is not care taken; it is where the bar sits. In all three
the quantity being asserted against is measured from the same run under the subject-removed condition — the
empty stage, the same-state pair, the witness column. The grapple layer's bar was a constant, and a
constant cannot notice that its subject has gone.


## The assertion floor reaches 109 of 113, and the last four need a source change

`measure_player` writes its verdict at the end of the line — "run speed px/s: measured 150.0, intended
150.0 (+/-6%)  OK" — which neither of the gate's two rules could see. A third rule counts trailing `OK`.
It was checked against all 113 logs of a full sweep before being added: five layers matched neither of the
first two rules, and the new pattern counts 3 for `measure_player` and 0 for the other four, so it holds
exactly one new row and moves nothing that was already held. Controls: dropping one metric line from the
log gives "DROPPED: measure_player asserted 2, floor is 3"; replacing the dialect entirely gives "MISSING:
measure_player has a floor of 3 and reported no count", so a rule that stops matching cannot pass quietly.

The remaining four — `check_capture_manifest`, `check_prose`, `check_score`, `check_water_audio` — will
not yield to a fourth rule, and it is worth being exact about why. Two are shell layers and two are
GDScript layers that `extends SceneTree` rather than `check_base.gd`, so none of them has a `_check` to
tally. Each prints its diagnostics and then a single summary sentence with the verdict buried in the
middle: "check_score: PASS — 3 seamless beds, monotone descent, eased mix, headless-safe". There is no
count in that line because the layer never enumerated one. No pattern can count assertions that were not
made individually, so closing these four means changing what they print.

One inference along the way was wrong and is worth recording. The five unreachable rows are all off
`check_base.gd`, which looked like the characterisation — until it was counted. Nineteen registered layers
are off the base class and fifteen of them are held, because they print a PASS line per claim. Being off
`check_base.gd` is necessary but not sufficient; the boundary is the dialect a layer speaks, not what it
inherits from.


## The floor reaches 111 of 113; the last two are shell layers

`check_score` and `check_water_audio` could not be held because they counted only their FAILURES, and a
failure count of zero is what both a layer that checked twenty-one things and a layer that checked nothing
report. No pattern could fix that from outside, so it was fixed at the source: each gained a
`_claim(ok, msg)` that tallies the attempt and returns the result, leaving the `continue` paths intact.

Both now print "(N asserted)" on the passing path and "N FAILURE(S) of M asserted" on the failing one, so
a red still reports its count — the property whose absence made this gate accuse `check_grapple_reads` of
a drop it had not made. Counts: `check_score` 21, `check_water_audio` 10, each reconstructible by hand
from the source (score: 1 muted + 3 beds x 5 + 2 monotonicity + 2 endpoints + 1 easing).

One judgement call inside `check_score`. Its descent walk checks monotonicity at every sampled step, and
claiming per step would tie the layer's assertion count to the number of steps, so re-sampling the descent
would read as assertions appearing or going missing. Those are collected and claimed once, with every
violation still named in the message. The per-bed checks stay granular, because bed count is content: if a
bed disappears, the floor should notice.

Controls: a mutant that breaks the swell assertion prints "check_water_audio: 1 FAILURE(S) of 10 asserted"
and the gate reads 10 from it. The earlier standalone red on `check_score` — "expected _muted under the
headless driver" — was the harness's `--headless` missing from the invocation, not a regression; it is a
driver failure and is recorded as one.

Two rows remain: `check_capture_manifest` and `check_prose`, both shell layers, which need a shell
convention rather than a pattern or a source tally.


## The 2026-08-22 machine-identity red, explained and fixed

It came back. The sweep at `92e5eda` failed `check_machine_identity` on the control that photographs the
empty stage after the last machine is taken off. Six standalone runs of one unchanged tree:

| run | empty-stage cover |
|---|---|
| 1, 2, 5 | 0.0000 — pass |
| 6 | 0.0089 — fail |
| 3, 4 | **0.1037, 0.1084** — fail |

The first reading of this was that the bar had no headroom: it compares against still-frame noise, which
measures exactly 0.0000, so the control demands a pixel-perfect match. That is true and it is not the
cause. 0.10 is **four times** the 0.0250 two machines must differ by. That is a machine in the frame, not a
transient. The layer waited four fixed frames after `remove_machine` and then photographed, and taking the
machine off is not the same as the picture losing it.

The bar is untouched — still `empty_cover <= noisy_share`, both measured exactly as before. What changed is
that the removal is given up to `CLEAR_FRAMES` to reach the picture and the wait ends the moment it has.
Six runs after: all pass, and one of them needed **39 frames**, nearly ten times the old budget, which is
the evidence that the old number was a guess rather than a wait. Mutation: with the machine never removed
at all, the control reads 0.7092 after the full 180 frames and fails. It cannot mask a real failure.

This is the same mistake the grapple layer made against the lamp — a wait whose length is a constant is
not a wait on the thing you are waiting for — and it retires ENVIRONMENTAL / UNEXPLAINED for this layer.

## Two more witnesses, and a guard that did not work

`check_texture` builds its whole grammar table from a directory scan with nothing checking the scan found
anything. The lookup falls back to grammar 0 on a miss, so an empty table is not an error: it is a world
where every deep cell reports the same grammar, and the per-grammar profiles would be computed over that.
`DirAccess.open` returning null was dereferenced immediately. Now the scan is survived, counted, and held
to a derived bound — every file in the directory must load — and `_report_world` returns its failures
instead of discarding them. Mutant pointing at a directory that does not exist: exit 1, naming the scan.

The two layers taught to count in this iteration also needed `check_base`'s refusal to green on zero
assertions, since a failure count of zero cannot tell "checked everything" from "checked nothing". The
first version of that guard did not work, and the control is what found it: `quit()` requests the tree to
exit and does not return, so the mutant printed the FAIL line, then printed "PASS (0 asserted)", and
exited 0 — the exact shape the guard exists to stop. With an explicit `return` after it, the mutant exits 1
and prints only the failure.


## `check_machine_state` did not have its sibling's race, but its bar was one draw

The question was whether the other 2026-08-22 red shared the fixed-frame fault that turned out to be
`check_machine_identity`'s. It does not: it waits on a condition (`_settle_until(sim, m, &"working")`) and
then gives the light 75 frames to reach steady, and six runs of one tree pass with `D_state` stable to
3–6%.

What it did have is a bar drawn once. `D_motion` — the same state photographed at two animation phases —
is what `D_state` must clear by `MOTION_MARGIN`, and over six runs it swung **3.75 to 16.83** on the
Generator, 4.5x, while that machine's `D_state` moved 6%. Which phase pair the shutter caught was doing
more to the margin than the machine was.

Three estimators were measured and two were wrong, which is why the workings are in the source:

| estimator | Forge `D_motion` | verdict |
|---|---|---|
| one draw (shipped) | 10.6 – 13.1 | passes, but the Generator's twin swings 4.5x |
| max, each draw vs `a1` | 32.9 – 35.7 | **all six red** — the draws span 22/44/66/88 frames, four intervals of a growing quantity |
| max of consecutive pairs | 43.1 – 43.9 | **all six red** — dominated by one discrete event |
| median of consecutive pairs | 15.0 – 15.5 | passes, and stable |

The first wrong estimator is the mistake `check_grapple_reads` made and had to unmake, with a second edge
here: the recipe bar fills as the machine works, and a window four times longer admits four times as much
of it. The second was caught by printing every pair instead of the summary. One run's Forge read **11.25,
43.39, 18.87, 9.26** with the status `working` throughout — pair 1 is a craft completing, the bar
resetting, an output appearing. A discrete event, not an animation phase, and a maximum is certain to find
it.

The median of consecutive pairs is what this repository already settled on for a statistic over a
duty-cycled cue. `MOTION_MARGIN` is untouched at 3.0, and the new bar is **stricter than what shipped**:
the single draw it replaces was the first pair, and the Generator's went from as low as 3.75 to a steady
24.4. Margins are 5.0–6.2x. The Generator's 4.5x instability is gone: 24.02–24.97 across six runs.
Subject-removed control still fires — every machine SILENT with state equal to motion.

And a note this layer needed once `SF_ANIM_FROZEN` existed: **the clock must not be posed here.** This
layer's bar IS the animation. Freezing it drives `D_motion` toward zero and makes the margin trivially
satisfied — the exact opposite of what posing bought the grapple layer, where the animation was the
contaminant rather than the control.


## The assertion floor now reaches every layer in the suite

The last two rows were the shell layers, and they closed the same way the GDScript ones did: at the
source, not with a fourth pattern. The convention is that a shell layer prints the same two sentences a
GDScript one does — "(N asserted)" passing, "N FAILURE(S) of M asserted" failing — so a red still carries
its count.

`check_capture_manifest` could not be counted until it had a witness. Its claim is that the tracked
manifest equals a freshly regenerated one, and **a claim of sameness is satisfied by a build where nothing
happened**: had the scan found no captures, `diff` would have been quiet and the layer would have reported
the archive correctly described while describing nothing. This is the third instance of that shape this
run, after `check_bake_idempotent`'s witness and `check_texture`'s materials scan. The population is
asserted first — 52 captures today — so the comparison is a comparison of something. Three claims.
Mutant forcing the scan to describe nothing: exit 1, "the scan described 0 capture(s), so there is nothing
for the manifest to be right or wrong about".

`check_prose` counts the files it actually **tested**, which is not the files it opened: its wide sweep
with no word list opens every tracked file and tests nothing, and that population is excluded for exactly
the reason the script's own last line already refuses to call it clean. 444 = 60 narrow + 22 positional +
362 wide. Mutant injecting one failure: "check_prose: 1 FAILURE(S) of 444 asserted", which the gate reads.
A second mutant pointing the word list at a missing file showed the layer refusing outright before it ever
reaches the vacuous branch — a guard that was already there.

**113 of 113.** Three rules: 95 report "(N asserted)", 17 print one PASS line per claim, one writes its
verdict at the end of the line. Being off `check_base.gd` was never why any row was unreachable — 19
registered layers are off it and 15 were held before any of this work. The boundary was always the dialect
a layer speaks, and four layers were taught to speak one.


### What reaching 113 bought that was not the point

`check_base._verdict()` refuses a green from a layer that asserted nothing. Nineteen registered layers do
not inherit it, and auditing each of them for an equivalent guard was queued as its own item. It is now
largely moot: every one of the 113 rows carries a floor of at least 2, so a layer that asserted nothing
reports 0 and is caught as DROPPED, and a layer that printed no count at all is caught as MISSING. The
protection that was inline for 91 layers is now structural for all of them.

The limit is worth stating exactly, because it is the kind of thing that reads as broader than it is: the
floor gate judges **only on a full configured sweep**, by its own header, and a subset run has no opinion
about layers it did not run. So a layer run standalone still gets no zero-assertion protection unless it
inherits `check_base`. That is a real remaining gap and a much smaller one than eleven unguarded layers.


## The water depth reading was a transient measured through a stale rectangle

The open question was whether `check_water_reads`'s tightest assertion — 3.3 to 6.8 levels over 45
retained sweep logs, against a floor of 2.5 — was a single draw of something that animates, as
`check_machine_state`'s bar had been. It was not. Sampling the quantity every six frames from the point
the layer shoots gives a curve, not an oscillation:

```
frame  0     6     12    18    24    30    36    42    48    60   ...  234
fall   1.59  3.28  4.90  6.34  6.77  7.90  7.95  8.17  8.20  8.57 ...  8.51
```

A ramp for roughly forty frames, then a plateau. `SHOT_SETTLE` is 90 frames and was already there for
exactly this reason, and it was not enough: the shutter lands on the ramp, so every one of those 45
historical readings was a measurement of the veil converging rather than of the body.

The wait is now on stability rather than on frames — consecutive draws within 0.25 twice running, with a
budget that says so if it expires. It ends on stability and never on the floor, because a settle that
stopped when the number cleared its bound would be a waiter inside its own condition; a mutant with the
floor raised to 99 settles at the usual 48 frames and fails at 4.2, which is the proof.

**And fixing that exposed a second fault, which was mine.** The rect locating the body was computed on the
ramp frame and then applied to the settled one, and the body's detected top edge moves as the veil
converges — 118 and 117 on runs that passed, 112 and 115 on runs where the surface assertion read 0.9 and
0.7 levels against a floor of 7.0, because a rect starting a few pixels high puts air where the surface
should be. A rect measured on one frame is not a rect on another. It is relocated on the settled frame now.

Six runs after both fixes: `fall` 4.2, 4.2, 4.2, 4.2, 4.3, 4.3 and `rise` 10.0 to 11.2, every run green,
the settle taking 48 frames every time. The spread went from a factor of two to two percent. The magnitude
did not move — 4.2 is about what the old readings averaged — so this bought reproducibility, not headroom,
and the margin stays an honest 1.68x. `GRADIENT_MIN` is untouched.

One correction to my own working: an intermediate reading of this put the settled value at ~8.2. That was
measured through the stale rect. Over the correctly relocated one it is 4.2.


## The reproducibility census could not check the one thing it depends on

The census compares two finished sweeps and reports, per layer, how many of the numbers inside its
PASS/FAIL lines moved. It only measures reproducibility if the two sweeps ran on the same tree, and until
now that was a sentence in its docstring asking the operator to guarantee it.

That is not a small gap, because of what the census is for. A layer whose source was repaired between the
two sweeps moves every number it prints. Run across a repair, the census ranks the layers that were just
fixed as the least reproducible in the suite — the exact inverse of the truth. Four layers were repaired
in a single day here, and the obvious next step was to re-run the census over the sweeps either side of
them.

Auditing the archive to find a valid pair turned up that there wasn't one. Of 23 retained sweeps, **14 ran
on a modified worktree**, and no two shared a clean head. The precondition had never been met by
construction, only by the three sweeps it was first run against — and those were all dirty, so a
clean-only rule would have refused them. They share a head *and* a `delta`, the content-address of the
uncommitted diff that every sweep already writes into its own `summary.txt`. Same head plus same delta is
the same tree, clean or not, so the check is on that pair and the original use stands.

Its recorded limit: the delta comes from `git diff HEAD`, which reports nothing for a file git has never
seen. Two trees agreeing on head and delta can still differ by an untracked file. No registered layer can
arrive that way — the registry is tracked — but an untracked asset can change pixels. This makes the
precondition testable, not certain.

Four controls: two sweeps on the same commit with different deltas are refused; two on different commits
are refused and the nine differing files under `tools/` are named, `check_machine_state.gd` among them,
which is precisely the false drift the guard exists to prevent; the legitimate dirty trio is accepted; and
the new pair is accepted. `--cross-tree` still allows the comparison with a banner saying any row may be a
code change.

**The first valid pair, two sweeps at clean `e8d832f`: 95 of 107 layers reproduce exactly, up from 91.**
`check_water_reads` fell from 100.0% widest move to 4.5%, which is the water repair confirmed by an
instrument that knows nothing about it.


## The same commit gave a red and a green in the same hour, and the green was the broken one

Two sweeps were taken at clean `e8d832f` to build the census pair. One reported `check_grapple_reads`
FAILING `GR-06` and the other reported it PASSING. Same commit, same machine, an hour apart. Both asserted
all 13 rows, so this was not a stand-down; the measurement itself moved:

```
A (red)    miner 88.1 levels, preview 134.2 levels (322 preview pixels)  -> FAIL
B (green)  miner 88.1 levels, preview  43.6 levels (465 preview pixels)  -> PASS
```

The preview's reading is a p90 over a difference mask, so a mask that grows by 143 pixels of near-threshold
noise dilutes it — and diluting the preview is precisely what makes the miner look louder than it. **The
passing run was the broken measurement.**

`ANIM_FROZEN` holds `WorldRenderer._anim_time`, a GDScript variable. `post_fx.gdshader` runs film grain off
the shader built-in `TIME`, which nothing in GDScript poses: `grain_amount` 0.014, about 3.6 levels,
re-seeded on `fract(TIME * 0.96)`, so it cycles about once a second. Two captures four frames apart hold
two partially decorrelated grain fields, every pixel differs a little, and the pixels near the mask
threshold cross it or do not depending on how much WALL TIME those four frames took. Under load they take
longer. That is the whole mechanism, and it makes the layer's verdict a function of machine load.

`Engine.time_scale` scales shader `TIME`, so zero holds the grain too. Eight unloaded control runs of the
layer as it stood read 144, 147, 265, 176, 304, 149, 177, 153 preview pixels. Six with the clock held read
146, 148, 143, 147, 149, 141, and 140.6..142.4 levels. Three confirmation runs of the committed layer read
149, 145, 154 and 142.0, 141.2, 140.8.

The count stops moving, the reading stops moving, and it stops at the value the clean runs already gave —
so this is not stability bought by measuring nothing, which is the way this fix could have gone wrong.
**`GR-06` still fails every run. The repair makes the red reliable; it does not remove it.** What it
retires is the possibility of a false green, which is the direction that matters: a red gets read, a green
gets filed.

The pose is released at the end of the capture pair rather than with `ANIM_FROZEN`, which runs on into
GR-02. `_hook` drives a real throw, and a throw needs physics to advance.


## The sky half had the same fault, and its own control had been naming it for days

The grain contaminates any two-frame difference, so the open-sky block had it too — but there the cost
landed on the exclusion rather than on the mask. That block poses the world clock *before* building its
drift exclusion, so with the grain still running the only pixels `_moving` can find ARE grain. The
exclusion stopped being a drift mask and became a noise mask sized by machine load, and every pixel it
holds is a corridor pixel taken away from the measurement.

```
only _anim_time posed    ate 344 / 51 / 21 corridor px   142.8 .. 160.2 levels   181..185 mask px
shader clock posed too   ate   0 /  0 /  0 /  0          156.4 .. 159.1 levels   182 mask px every run
```

**The layer already had the control that says this.** `eaten` is documented in place as "the travelling
control on the pose: a corridor that is still losing pixels means something in the frame is alive that
`_anim_time` does not drive". That sentence is an exact description of the film grain, and the number
beside it printed 21, 30, 51 and 344 across recent runs while nothing read it. A control that reports and
cannot fail is a control that gets read only after someone already suspects the answer.

It is still not asserted, and that is now a recorded gap rather than an oversight. With both clocks posed
it reads 0 in the corridor over four runs, but the whole-frame mover count over those same four reads
0, 0, 0 and 3 — the residual is not identically zero, and four samples do not locate a bound. A cap could
not catch every unposed run either: one of the five measured without the shader clock happened to eat 0.
Both populations are written into the source so the next pass starts from data instead of from a guess.


## Reading every census nomination, and finding nothing left at risk

The census says where to look and refuses to say how bad, so its twelve movers on the valid pair were read
one at a time against the layers' own PASS lines. After the grapple repair, none of them threatens a bound:

| layer | what moved | why it is not a finding |
|---|---|---|
| `check_hint_gate` | `alpha 0.048` → `0.025` | a fade envelope, and the verdict is the boolean beside it. The source says so in place: "not a legibility claim... what this asks is whether anything is CLAMPING it to zero". The wait is a proper wait-on-condition with a budget |
| `check_ceremony_reads` | `mean 14.1` → `12.2` dE | printed beside a MEDIAN-based assertion (1.9 against a cap of 12.0). Reporting both is deliberate — a thresholded mean is the statistic this repository already caught measuring its own threshold |
| `check_snap_frame` | `against 2` → `against 0` | the known small-integer artifact. A control needing 4x of a count that is 0 or 2 scores 100% relative movement and has 198000 of headroom |
| `check_rock_reads` | 532 → 517 solid cells | a population count with a floor of 40, and the cue itself moved 87.41% → 87.70% against a floor of 75.00% |
| `check_selection_reads` | 59650 → 59638 px | floor 800. Its colour-survival number moved 99% → 100% against a floor of 90% |
| `check_hud_layout` | 3.367 → 3.366 s | twelve numbers, all sub-0.1% |
| `check_contact_edge` | 608 → 609 faces | floor 40 |
| `check_lock`, `check_frametime`, `check_dig_hitch` | durations | their subject IS time; the census header names these as expected |
| `check_water_reads` | 4.5% widest | was 100.0% before the settle repair |

Two of the top three non-time nominations turned out to be **printed diagnostics rather than judged
bounds**. That is not a fault in the census — it counts the numbers inside PASS lines because it cannot
know which of them a threshold is compared against, and its header already refuses to rank risk for
exactly this reason. It is worth writing down as measured experience: a high row is a reason to open the
layer, and opening the layer is where most of them end.


## A layer that said SKIP and exited PASS

`check_verdict_route` enforces that no layer exits 0 by hand, and its exemption list is empty. Its
population is documented as the INHERITORS of `check_base.gd`, on the reasoning that a layer extending
`SceneTree` "has no base-class guard to bypass". True, and it also means the thirteen `SceneTree` layers
are the ones nothing checks — which is the shape this repository has found before: the opt-out predicts
the defect.

Auditing their exit paths found one. `check_bake_idempotent` guards itself for a display it needs, prints

    check_bake_idempotent: SKIP — needs a display (the bake is a SubViewport render target)

and then exits **0**. The harness's skip contract is exit 42; `SKIP_CODE=42` in the runner and
`const SKIP: int = 42` in the layers, described in the runner as a load-bearing pair. Exit 0 is a pass. So
in the headless CI job this layer reported green having rendered nothing, and the sentence saying otherwise
was in the log where nothing reads it. The word was right and the exit code was the part being read.

Before and after, same runner, same flags:

```
  [ 1/ 1] check_bake_idempotent (bake holds)   PASS    1s
  1 PASS / 0 FAIL / 0 SKIP of 1 selected — subset green

  [ 1/ 1] check_bake_idempotent (bake holds)   SKIP    0s
  SKIPPED — NOT RUN, NOT PASSED: check_bake_idempotent (bake holds)
  0 PASS / 0 FAIL / 1 SKIP of 1 selected
```

The display path is unchanged and still passes in 5s. The population was enumerated rather than guessed:
of the 17 layers registered `add_gl`, six already exit 42 on this branch and this was the only one exiting
0. A scan for the same shape across all 104 registered GDScript layers returns exactly this one.

**Correction, measured within the hour: "the other ten carry no display guard at all" was wrong.** They
all carry one. They call `_skip_layer()`, the `check_base.gd` helper that prints the SKIP line and calls
`quit(SKIP)` for them, and the scan that produced the claim looked for a literal `quit(` within three lines
of the headless test — so it saw the guard's absence rather than the helper's presence. A declaration form
a scan omits reads as a finding.

Running the job that settles it, `SF_HEADLESS=1 SF_GL_ONLY=1`:

```
1 PASS / 0 FAIL / 16 SKIP of 17
```

Sixteen skip and say why. The single pass is `check_dig_hitch`, which is registered `add_gl` for its
pixel-timing half but whose headless assertions are bake REGION ARITHMETIC — rect containment, 43520 of
262144 cells, 418 rows outstanding before and after a dig — and its pixel group stood down. That is a real
pass on a real subject.

So the correction tightens the finding rather than softening it. Every `add_gl` layer guards itself; the
one that got the exit code wrong is the one layer that **could not call the helper**, because it extends
`SceneTree` and had to hand-roll both the guard and the constant. Same root, one level down. After
`9d16f81` the headless job carries no false green from this class.


## Giving the skip contract a runner

`check_bake_idempotent` said SKIP and exited 0 and nothing in the suite noticed. That is this repository's
own test for whether a rule exists — a rule with no runner is a preference — and the skip contract had been
living in the runner's constants and in the layers' good manners. `tools/assert_skip_route.sh` is the
runner for it: it reads a finished sweep's per-layer logs and its summary table and refuses a sweep where a
layer was counted as a pass after announcing that it did not run.

**Telling the two SKIP shapes apart is the whole difficulty.** A layer declining ONE assertion prints an
indented `SKIP: [some.id] ...` and is otherwise passing honestly; a layer declining to RUN prints
`<name>: SKIP ...` hard against the left margin. Catching the first would turn every honest stand-down into
a red, which is the fastest way to get a gate switched off. Only the second is the subject, and only in the
false-green direction: a layer that announced a skip and then failed is odd, but nobody files a red.

Two things it got wrong first, both caught before it ever issued a verdict:

- **Mapping logs to rows by index is wrong.** Log files are numbered by declaration order and summary rows
  stream in COMPLETION order, so `[12/113]` is a completion counter. Log 11 is `worldgen` while row 12 is
  `check_bazaar_cache`. It maps by name instead, normalised on both sides because `power/water
  (field/flood)` is logged as `power_water.log` — and a log it cannot place in the table is a REFUSAL, not
  a skipped row, because the population this gate covers has to equal the population the sweep ran.
- **The row pattern did not allow the runner's padding.** A full sweep prints `[ 1/113]` and a one-layer
  subset prints `[ 1/ 1]`, with a space after the slash. `[0-9]+/[0-9]+` reads the second as no row at all,
  so no rows parsed, no logs mapped, and the gate complained about nothing. Its own positive control caught
  it — the entire argument for running controls on every invocation rather than once at authoring time.

It runs before `assert_floors` and suppresses it on failure, because both end in a `HARNESS_QUOTABLE=` line
and the floors' own comment already names the hazard: two lines with one key is a reader taking whichever
one grep hands them first. Exactly one is emitted in every case.

**Unlike the floors, it judges a subset.** A floor says nothing about layers that did not run, but every
layer that DID run either announced a whole-layer skip or did not. That matters here specifically: the job
where this defect lives is the headless one, which is a subset by construction.

Five behaviours, each on real data: a 113-log display sweep passes; the headless GL run with sixteen honest
skips passes; the same run with one row put back to PASS fails and names the layer with its own line; a log
absent from the table refuses; an empty directory refuses. And end to end, with the defect reintroduced in
the source, the runner goes from

```
1 PASS / 0 FAIL / 0 SKIP of 1 selected — subset green
HARNESS_EXIT=0     HARNESS_RESULT=yes
```

to `assert_skip_route: FAIL`, one `HARNESS_QUOTABLE=no`, and `!! exiting 7: the sweep above is NOT A RESULT`.


## Measuring whether a bound was possible, and finding it was not

The grapple pose left a gap on purpose: `eaten` is documented in the layer as the travelling control on
the pose and asserts nothing. Closing it needed the distribution on both sides, so both were measured —
eight runs each, **interleaved rather than run in blocks**, so drift in machine conditions could not
separate the arms, against a copy of the layer differing by exactly one line.

```
posed     0    0    0    0    0    7    0    0        max 7, median 0
unposed   0    2    2    6   19   19  213  557        sorted; median 12.5
```

**The distributions overlap, so no cap separates them.** A cap at the posed arm's maximum of 7 passes four
of the eight unposed runs. A cap at 0 breaks one of the eight posed runs. Either is a red that means
nothing or a green that means nothing, and there is no third number to pick.

The reason is in the mechanism rather than the sample size, which is what makes this a conclusion instead
of a pause. The grain decorrelates with wall time between the two captures, so an idle machine barely
contaminates the mask whether the clock is held or not — which is exactly why the defect this control
exists for stayed invisible until a sweep ran twelve engines at once and the mask reached 465 pixels. The
arm that would separate them is the *loaded* one, and eight sweeps to get eight samples of it is not a
measurement anyone will repeat.

So it stays a printed diagnostic, and the note left in the source says a bound here needs the loaded
distribution and not more idle runs. Two smaller things recorded with it: the posed arm is **not**
identically zero — one run in eight ate 7, and whole-frame movers under the same pose read 0, 0, 0, 3 —
and the preview mask held at exactly 182 pixels in 8 of 8 posed runs against 5 of 8 unposed, which is a
sharper contrast than `eaten` gives but is not assertable either, since pinning an exact pixel count would
fail on any legitimate change to how the mark is drawn.

This is the second time this programme has answered "what bound goes here" with "none, and here is why".
The first was `grapple.gr05-preview-share`, where the cap that used to stand was `1.01` over a quantity
bounded at 1.0 by construction — an assertion that could not fail. Recording the refusal with its data
costs a line of prose and saves the next reader from re-deriving a number that does not exist.


## The census confirms the grapple repair, the way it confirmed the water one

A second valid pair, two sweeps at clean `782b194`, taken because the only earlier pair sat one commit
before the shader-clock fix and so could not speak to it.

```
                        pair at e8d832f      pair at 782b194
check_grapple_reads     8/27   100.0%        8/27    16.7%
check_snap_frame        4/8    100.0%        3/8      0.3%
check_water_reads       3/8      4.5%        2/8     13.5%
layers reproducing      95 of 107            92 of 107
```

**The same count of grapple numbers still move, and the size of the move collapsed** — which is the right
signature for this repair. It never claimed to make the layer deterministic; it claimed to stop the
preview's reading being a function of machine load. The reading itself now goes 142.5 against 142.2, a
0.2% move where it once went 134.2 against 43.6. What is left at 16.7% is the still-frame churn
**diagnostic** (0.10% → 0.12%), a number nothing judges, printed beside the control that reads it as a
boolean.

Two honest notes against the win. `check_snap_frame` fell from 100.0% to 0.3% and nothing was done to it —
its control compares against a count that happens to be 0, 1 or 2, so its relative move is decided by which
small integer it lands on, exactly as its row has said all along. And `check_water_reads` moved the other
way, 4.5% to 13.5%: the surface reading went 11.1 to 9.6 against a floor of 7.0. That is 37% of headroom
and not a risk, but it is a wider spread than the settle repair's own six runs showed, and it is the number
to watch if that layer is opened again. The count of exactly-reproducing layers also went 95 to 92 — a
different pair, three small new movers, none above 6.7%.


## Three traversals, none of them posed, and a green

Auditing the thirteen layers that extend `SceneTree` for a population guard turned up two with none at
all. The first, `check_step`, is a live instance of the shape this programme keeps finding.

It makes three claims — a body climbs out of a 1-pit, walks over a machine, walks through a wood trunk —
and each needs a flat run of terrain to build its subject on. Each setup answered "no flat run" by printing
a line to stderr and moving on. None recorded a failure. `_done()` prints `ALL STEP-UP TRAVERSALS PASS`
whenever `_fails == 0`, and a run that tested nothing has `_fails == 0`.

Measured rather than argued, with `_flat_run` forced to return -1:

```
  (no flat run found to test the pit — skipping A)
  (no flat run found to test the machine — skipping B)
ALL STEP-UP TRAVERSALS PASS
EXIT=0
```

C was never even announced, because B's skip jumps straight to the verdict. Three claims, none posed, exit
0 — and the two stderr lines saying so are the same shape as `check_bake_idempotent` printing SKIP before
exiting PASS: the sentence is right and the thing being read is the exit code.

The sweep was covered by the assertion floor — three pass lines, and a full skip prints none — but the
floor only judges on a full configured sweep, so a standalone run reported success. The layer now counts
what it actually posed and refuses a verdict below three, before looking at `_fails`, because `_fails == 0`
is exactly what a run that tested nothing reports.

One detail worth the line it costs: the first version of the refusal printed *"3 of 3 traversals were never
posed: A, B"* and read like an off-by-one. It is not — a skip jumps straight to the verdict, so the
traversals after it never run and never announce a reason. The count and the list genuinely disagree, and
the message now says why instead of leaving a reader to decide which number is wrong.

Controls: the mutant exits 1 with `0 step-up traversal(s) FAILED, and 3 were not attempted`; the real layer
still prints its three PASS lines and exits 0, so the floor of 3 is untouched.


## The same defect in a second layer, found because the first one named its shape

`check_fastforward` has two guard cases — a body falling onto a one-tile ledge under fast-forward without
tunnelling, and a body walking a built runway — and both setups need terrain to build on. Both answered
"no site" the way `check_step` did: a line to stderr, no failure recorded, and `_done()` printing
`FAST-FORWARD GUARD PASS` because `_fails == 0`, which is exactly what a run that posed nothing reports.

The mutant is kept in the file rather than applied by hand, following the convention this layer already
set for its other guard: it carries `SF_FF_MUTANT`, with the reasoning that *"prove the guard goes red is a
claim that should be re-runnable by anyone who doubts it"*. `SF_FF_NOSITE=1` now forces both finders to
fail:

```
  (no flat run found — skipping A)
  (no machine-free 56-column site with room to build — skipping B)
  2 of 2 guard cases were never posed, so this run judged nothing about them: A (the ledge), B (the runway walk)
0 fast-forward guard case(s) FAILED, and 2 were not attempted
EXIT=1
```

Before the change that same run printed `FAST-FORWARD GUARD PASS` and exited 0. The real layer still poses
both cases, prints its two PASS lines and exits 0, so the floor of 2 is untouched.

**The audit that found both is worth stating as a method rather than as two fixes.** The question asked of
all thirteen `SceneTree` layers was not "does it assert enough" — the floor gate already answers that on a
sweep — but "can its population go empty without anything noticing". Grepping for a minimum guard returned
two layers with none: `check_step` and `measure_player`. `check_step` was live. `measure_player` was a
false positive of the grep and is structurally protected: it is a phase machine where each phase only
advances after calling `_report`, with a TIMEOUT path that exits 1, so reaching the verdict implies all
three reports happened. `check_fastforward` was not on that shortlist at all — it was found by then reading
the *verdict paths* of the two layers whose guard count was merely thin, which is the check the grep could
not do.
