# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. This file is the current disposition; an area is CLOSED only where the
evidence is named, and a partial area is stated as partial rather than rounded up.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Closed** | `world_renderer.gd` 4601 -> 3557 lines across three extractions, each cut against a measured ranking and each proven equivalent before it landed. Every candidate still in the file is rejected with its numbers rather than with a plan to get to it. `main.gd` and `factory_sim.gd` were measured and have no separable seam: their coupling is semantic, not a god-file boundary. Closed because the measurement says there is nothing left worth cutting, not because the time ran out. |
| 3. Harness quality | **Closed** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. |
| 4. Performance and maintainability | **Open, in progress** | a formal pass found seven full-grid loops, one of which ran every frame. The bazaar cache is verified by direct measurement, and the frame SLO has now been evaluated on the host it was written for — all four phases hold, with one resolution caveat recorded below. |
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
**failed inside the full sweep, on an honest frame, at 2.8 levels over 3982 pixels.** All sixteen samples
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

## Exit condition

All six areas closed, the full suite green on `main`, and every remaining stand-down carrying a written
reason. No new gameplay work begins until then.
