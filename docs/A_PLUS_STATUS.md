# Engineering programme — status

A bounded quality programme run over this repository before further feature work. Six areas, fixed order,
no new gameplay until it exits. This file is the current disposition; an area is CLOSED only where the
evidence is named, and a partial area is stated as partial rather than rounded up.

| Area | State | Evidence |
|---|---|---|
| 1. Reliability and safety | **Closed** | save isolation, durable save transactions, explicit migration and version semantics, and honest PASS / FAIL / SKIP behaviour throughout. Audited and found substantially already met. |
| 2. Architecture | **Closed** | `world_renderer.gd` 4601 -> 3557 lines across three extractions, each cut against a measured ranking and each proven equivalent before it landed. Every candidate still in the file is rejected with its numbers rather than with a plan to get to it. `main.gd` and `factory_sim.gd` were measured and have no separable seam: their coupling is semantic, not a god-file boundary. Closed because the measurement says there is nothing left worth cutting, not because the time ran out. |
| 3. Harness quality | **Closed, with one narrowed finding open** | seven sub-areas, each closed with evidence, including two where the first diagnosis was wrong and the record carries the correction rather than the conclusion. A later audit found 58 of the 89 layers inheriting `check_base.gd` hand-rolling the verdict protocol, and so missing the base class's refusal of a green that asserted nothing. Fifty-five are converted; the measured before-state was **55 registered layers exiting 0 having asserted nothing at all**. Three remain uncovered and are named below, because they call neither `_check()` nor `_verdict()` and so cannot be reached by a tail conversion. |
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
| `P_REG` | rows the runner registers, from its `add`/`add_gl`/`add_excl`/`add_excl_hl` calls | 110 (105 of them `.gd`) |
| `P_GLOB` | tracked files whose basename starts with `check_` | 100 |
| **`P_INHERIT`** | **tracked `.gd` matching `^extends "res://tools/check_base.gd"`** | **89** |

`P_INHERIT` is the one the finding is about, and it is well-behaved: every inheritor is registered, and
every inheritor is named `check_*`. Both set differences are empty — checked as sets, not as counts. Eleven
`check_*` files do not inherit, which is why `P_GLOB` is larger.

Over `P_INHERIT` the partition is complete, with nothing left over:

**89 inheritors = 31 calling `_verdict()` + 58 hand-rolling the verdict + 0 neither** — as it stood when
the audit was written. After the conversion below it is **86 + 3 + 0**, over the same population and by the
same rule.

**A fifth denominator exists and is not an error.** `tools/check_base_namespace.sh` reports 106 subclasses
because it searches with `grep -r` and so sees the 17 untracked, gitignored `tools/_scratch_*.gd` probes
that `git grep` cannot: 106 = 89 tracked + 17 scratch. Its population is deliberately the wider one — a
scratch probe that shadows a base member is a real collision — so the two numbers disagree correctly.

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

### The three that a tail conversion cannot reach

`check_frametime`, `check_opening` and `check_underground` call neither `_check()` nor `_verdict()`. They
hand-roll their comparisons *and* their diagnostics — `check_underground` distinguishes a fixture that
could not reach the rock from a verdict on the rock, in its own words, over several lines. There is no
shared protocol tail in them to move, and rewriting their judgement is a different piece of work with a
different risk.

They are, for exactly that reason, **the three layers the no-assertions guard still does not cover**, and
they are recorded here as an open finding rather than counted as done. Nothing today would notice if one of
them stopped judging.

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
reproducing is a red nobody can ever study. One mechanism is worth testing and is **not** claimed here: the
harness runs with shader caching disabled, so every headed layer recompiles its pipeline on boot, and a
frame captured before that pipeline is warm would read exactly like these. That is a hypothesis with a
plausible shape and no evidence yet, and the honest note is that nobody has tested it.

## Exit condition

All six areas closed, the full suite green on `main`, and every remaining stand-down carrying a written
reason. No new gameplay work begins until then.
