# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. This file is the current disposition; an area is CLOSED only where the
evidence is named, and a partial area is stated as partial rather than rounded up.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Partial, open** | three seams cut out of `world_renderer.gd` (4601 -> 3555 lines) against a measured ranking; every remaining candidate in that file is rejected with its numbers. `main.gd` and `factory_sim.gd` are measured and found to have no separable seam, which is a result rather than a deferral. See below. |
| 3. Harness quality | **Closed** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. |
| 4. Performance and maintainability | **Open, in progress** | a formal pass found seven full-grid loops, one of which ran every frame. The bazaar cache is now verified by direct measurement. The frame-SLO contract is still open. |
| 5. Documentation and contributor readiness | **Done** | architecture docs reconciled with executable behaviour, contributor and release workflow written, repository map present, and layer-count drift is now gated by the registry so a stated total cannot rot. |
| 6. Public presentation | **Complete** | the README explains the engineering system and the test-surface ratio accurately, history and media are retained deliberately with clone guidance, and the repository is legible to a reviewer in their first ten minutes. |

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

The floor is now **8.0**, which sits 1.48x above the loudest frame with no preview in it and 1.63x below
the quietest frame with one. It fails on the mutant at 4.7 and passes clean at 13.5.

**A second control on the same subject is reported rather than adjusted.** The companion assertion — the
preview drew something against open sky, floor 60 pixels — discriminates on fifteen of those sixteen runs.
Its one miss is a heavy tail that appears on both sides: with the ghost removed the mask came back at 5922
pixels once, larger than any run with the ghost drawn, and the drawn side has its own tail at 1791, 2323
and 5496 against a median of 198. That single tail event is why the first mutation run left the whole layer
green. No bound can fix this: excluding 5922 would need a floor above every honest run. The tail has a
cause worth finding, and moving the number would only hide it, so the number stays and the instability is
recorded here with its samples.

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
