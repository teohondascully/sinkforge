> **ARCHIVED 2026-08-27.** Untracked and excluded via `.git/info/exclude` since the 2026-08-25 pivot;
> moved here while closing that exclusion hole (ANVIL step 1). The pivot plan
> (`docs/archive/PIVOT_PLAN_2026-08-25.md` §1) already called this "3,447 lines of work-log for a
> superseded queue" not worth line-editing into relevance. No live replacement priority document exists;
> `docs/WORKING.md`/the queue projection (once ANVIL ships) carry that role now.
> Kept for provenance, not deleted, per this repository's own rule for `docs/archive/`.

---

# SINKFORGE — the one priority list

**This is the single list. It supersedes the ordering in every other document**, and it is the union of
four that had drifted apart: the queue in `docs/handoff/AUDIT_UPDATE.md` (items 1–18), the "updated
priority order" in `AUDIT_REPONSE.md` (8 items), Tracks A and B in `docs/FEEL_GAP.md`, and the kill list
and one-week plan in `docs/handoff/VIBE_AUDIT_RESPONSE.md`. **Nothing was dropped for being
inconvenient.** Items removed are marked with why, and shipped items are kept at the bottom rather than
deleted, because two of them were re-opened once already by someone who could not tell shipped from
assumed.

Those four lists disagreed about what mattered, and the disagreement was invisible while each lived in
its own file. Where they conflict, the ordering below follows `VIBE_AUDIT_RESPONSE.md`, because it is the
only one written from the artifact by someone who had not built it.

> **That rule is no longer the top of the stack, and saying so is the point of this note.** There are
> **five** sources now: `docs/DIRECTOR_BRIEF.md` sits above the vibe audit and **overrules it twice** — on
> the Descent Engine (the audit's single costliest recommendation, 2 days, superseded by the Freight Winch)
> and on *"first conversion on screen before 60 seconds"* (now kill-list #11). A merge rule that names a
> winner which has itself been overruled is the same defect this document exists to fix, so it is recorded
> here rather than left for the next reader to trip over.
>
> **Two further departures, marked so they can be overruled.** (1) The entire eight-item ordering of
> `AUDIT_REPONSE.md` was demoted **wholesale** into Tier 5 and made demand-pull, on the authority of kill
> list #8. That is not a merge, it is one source overruling another, and it is the most consequential
> single call in this document — reverse this line if measurement debt should be paid on its own schedule.
> (2) `T0.2`/`T1.6` (the lode cutover) was promoted into the active set on the **director brief's**
> reasoning, not the vibe audit's — the audit never mentions lodes, because they are invisible to a
> first-timer. That is a departure from the stated rule and it should not have gone unmarked.

> **Director update, 2026-08-17:** `docs/DIRECTOR_BRIEF.md` supersedes the specific Descent Engine,
> 60-second full-line, early waste-stream, and fixed buried-Sinkforge prescriptions below. The approved
> next progression target is a player-placeable **Freight Winch / Skipway**, staged behind experienced
> manual mining, automated extraction, automated logistics, and automated processing. Existing items are
> preserved here and explicitly backlogged rather than deleted.

> ### Worldgen, 2026-08-20 — SETTLED, and REVISED the same day. Act on nothing below without finishing this.
>
> **Move no worldgen constant.** `9d1841c` (the strata-hash repair) is correct and stays. That much is
> unchanged. What has changed is the reading of what it did.
>
> **The "four quality gauges" were largely four broken instruments.** Re-examined one at a time, two of the
> four have now been closed as measurement faults with no world change involved, one was already known to
> be a fixture artifact, and one is still open:
>
> | gauge | what was believed | what it is | status |
> |---|---|---|---|
> | rock/air legibility | 80% → 73%, a seven-point fall | the layer never posed the pointer and was reading the mouse on the desk | **instrument** — 78.67% corrected, floor 75% |
> | frontier richness | 3.05x → 1.13x under a 1.15x floor | a total over unequal rock, on a window the field calls neutral | **instrument** — 1.246x worst of twelve seeds |
> | legs-only plunge | 34 rows → 27 | the sinkhole moved; the fixture measures whichever mouth it finds | fixture artifact, already recorded |
> | paint roughness | 6.4% → 6.5% | measures paint convolved with worldgen | **open**, under diagnosis |
>
> **2026-08-23: the fourth gauge is closed too, and was closed on 2026-08-20 without this table being
> updated.** `1522270` is the repair, and its title is this row's complaint word for word: the paint layer
> "was named for the painter and measured the painter times worldgen". It replaced the pooled reading over
> real rows 60–110 with one composed slab per grammar built from Callables, with no `FactorySim` and no
> `LayeredWorldGen` anywhere in the call graph — so no worldgen edit can reach the number **by construction
> rather than by care**. The ceiling and floor were not moved. Confirmed rather than argued: dropping the
> `ee2120e^` and `ee2120e` generators into the tree as scratch scripts swung the material mix ten points and
> the pooled roughness 6.350% → 6.534%, and asserting per material did not fix it — per-material readings
> moved MORE than the pooled one across the same commit.
>
> **So all four gauges were instrument faults. No world change was involved in any of them and no floor has
> been moved.** Current readings at `f47021f`: roughness across a face 5.3% / 4.7% / 3.7% for clastic /
> bedded / massive against a 6.5% ceiling, and rock-vs-air legibility 87.45% against a 75.00% floor.
>
> **Do not read those numbers as a like-for-like improvement on 6.5%** — they are a different population.
> The old figure pooled materials; these are per grammar, and the slab is a QUIETER subject than real rock:
> the same grammars read 5.8 / 5.3 / 4.3 with real caves and 6.4 / 6.6 / 5.6 in-world.
>
> **Two residuals, and both need a picture rather than a number, so neither is autonomous work:**
>
> - **The slab is less sensitive than what it replaced, and that cost is recorded rather than compensated.**
>   `GRAM_SEAM 1.00` now escapes at 4.8% where the old pooled statistic caught it at 6.9%; the trip point
>   moved from between 0.70 and 1.00 to between 1.00 and 1.60. No new ceiling was invented, deliberately.
>   The slab needs its own calibration walk against pictures, and every number that walk needs prints on
>   every run.
> - **Contacts read 11.2% across on about 8% of samples** — the loudest population in the frame, belonging
>   to no material, and invisible to any per-material repair. Whether an 11% step between two different
>   rocks is a defect or simply what a boundary looks like is a judgement about the picture.
>
> The mechanism this block named for the legibility drop — *"the rock did not get less textured, the air got
> grainier"* — has also reversed since it was written. It rested on rock 3.06 → 3.01 against air 1.76 → 1.87,
> a GRAIN gap closing to 1.14. At `f47021f` the same cue reads **rock 4.22, air 1.74, gap 2.47**: air is
> below its pre-`9d1841c` value and the gap is more than double the one that raised the alarm. The
> background-wall-plane target this block proposed is therefore **not actionable as written** — the symptom
> it was aimed at is gone, and quietening the plane now would be a change with no measurement asking for it.
>
> **No floor was moved and none has been.** Every number above was recovered by repairing what was doing the
> measuring, which is the opposite of re-tuning a bound to restore green. The general lesson is the one this
> repository keeps relearning: a gauge that moves when the world changes is not thereby measuring the world.
>
> Note what this costs. The claim that correcting the strata made the underground *harder to read* — the
> finding this list ranked above everything else — **is withdrawn.** It rested on 80% and 73%, both produced
> by an instrument whose run-to-run spread was 4.24 points because its sample boundary followed an
> uncontrolled mouse. Whether a real drop is hidden under that noise is now unanswerable without re-running
> the corrected instrument against the pre-`9d1841c` world, and it is moot for shipping, because the world
> as it stands clears the floor.
>
> One real design question is open and is a judgment about the game, not a number: **a 58-row full-depth
> chasm now opens at column 71, immediately beside the starting fixtures.** Character or damage — unreviewed
> either way.
>
> Everything below is the working that got here, in the order it happened, **including three wrong turns
> that are kept because they are more instructive than the claims were.** Later paragraphs supersede earlier
> ones.
>
> ---
>
> **Finding, 2026-08-20 — one worldgen fix moved four quality gauges, and one of them is legibility.**
> `9d1841c` repaired a degenerate strata hash. The old expression reduced *exactly* to `(band / 8) % 3 == 0`,
> which is bands 0–7 and nothing else: **the top 32 rows were one contiguous shale slab and rows 32–75 had no
> strata at all.** The repair is correct and independently verified — upper half 8 shelf bands → 3, deep half
> 0 → 3. But it changes the rock everywhere, and four layers that passed before it fail after it:
>
> | gauge | before `9d1841c` | after | bound |
> |---|---|---|---|
> | rock/air legibility in the dark | **80%** | **73%** | floor 75% |
> | paint roughness across a face | 6.4% | **6.5%** | ceiling 6.5% |
> | frontier richness vs spawn | **3.05x** | **1.13x** | floor 1.15x |
> | legs-only plunge | 34 rows (mouth col 24) | 27 rows (mouth col 68) | asked 34 |
>
> **These are not one result.** The legibility
> drop is **seven points** and is the one that matters: correcting the strata made the underground *harder to
> read*, which runs directly against the priority this list puts above everything else. The plunge number is
> not a regression in traversal at all — the sinkhole *moved*, and the fixture measures whichever mouth it
> finds. The frontier ratio fell because the ore redistributed, spawn 10,258 → 19,288 while frontier 31,316 →
> 21,806; the old 3.05x was partly an artifact of a world with no deep strata to dilute it.
>
> **No floor has been moved, and none should be until somebody looks at the new world.** Three of these four
> bounds were calibrated against terrain that was structurally broken, so "re-derive them" is defensible —
> but only *after* deciding whether the corrected world actually reads and plays better, which is a judgment
> about the game and not about the numbers. Re-tuning four thresholds to restore green would convert a real
> finding into a silent one. The lode fix in `1ad38d1` is separate and is a genuine bug, not a recalibration.
>
> ---
>
> **RULING, 2026-08-20 — frontier richness. Classification: INVALID INSTRUMENT.** Not a world-design defect,
> not an insufficient corpus alone, and not an intentional design choice. The assertion could not measure the
> property it was named for.
>
> It took total ore mass in a 16-column window at each map edge, `max()` of the two, over the same total at
> spawn, on one hardcoded seed, pricing ore with no `amounts` entry at 1. Four faults, in rising order:
>
> - **`max()` selects a window that is not a frontier.** Spawn sits at column 48 of 128, so the two edges lie
>   48 and 79 columns out and the field normalises by the larger. Across twelve seeds the left window's mean
>   multiplier is **1.02 — the neutral value** — against the right window's 1.23. Taking the larger *total*
>   of the two silently selects the neutral one whenever it happens to hold more ore.
> - **A total is not a richness.** `RIFT_SPAWN_KEEPOUT` (columns 38–58) and `SINKHOLE_KEEPOUT` (28–67) both
>   exclude the spawn window, so carving strips rock from the frontier's numerator while protecting spawn's
>   denominator. Two windows with different amounts of rock left in them were scored as one sample.
> - **Base-layer ore was priced at 1.** `HeightmapWorldGen` writes veins with no `amounts` entry, and the
>   documented contract reads an absent entry as `FactorySim.DEFAULT_ORE_DEPOSIT` (250). About 76 cells worth
>   ~19,000 units were scoring as ~76.
> - **One seed, and not the shipping one** — 20260807, where the game ships 1337.
>
> **The failing seed is the corollary, not a coincidence.** On 20260807 the right window carries the highest
> field value in the corpus (1.29) and has lost half its rock to carving — 358 solid cells against spawn's
> 704. Its *density* is 1.25x spawn; its *total* is not. So `max()` took the left window at multiplier 0.99
> and 21806/19288 gives exactly the 1.13x that was reported. **The design was working and the instrument
> could not see it.**
>
> Corrected — frontier chosen by the field, richness per solid cell, ore priced at 250, twelve seeds:
>
>     worst 1.246x (seed 20260807)   median 3.05x   best 4.27x   clearing the floor 12 of 12
>
> Three serial runs, 147 PASS / 0 FAIL, identical numbers each time.
>
> **THE FLOOR DID NOT MOVE, AND THIS IS AN INSTRUMENT CORRECTION RATHER THAN A TEST TURNING GREEN.** What is
> measured changed; the bar did not. Two checks that cut against the result are recorded because they are the
> reason to believe it: pricing ore properly makes the worst seed **worse** (1.259 → 1.246) and was adopted
> anyway, and the retired statistic is still computed and printed unasserted on every seed, reproducing
> 1.13x on 20260807 exactly — a disqualified cue that stops being visible also stops being able to warn you.
>
> **Still open, and deliberately not bundled.** The 1.15 literal has never been derived: it was written when
> the observed value was 6.3x, it names no constant, and no arithmetic relates it to the field's own bound.
> Re-deriving a bar in the same commit that changes what the bar measures would make both unreviewable.
> Larger and underneath it: **the design intent for a lateral richness gradient is written nowhere** outside
> the commit that added it and the comment that implements it. Every documented richness gradient in
> `docs/GDD.md` and `docs/PROGRESSION.md` is *depth*. A ruling on the magnitude has nothing to rule against
> until that intent exists, and `_seed_droughts` is a deliberate, documented pass that cancels the lateral
> edge on purpose — so the design already contains a mechanism arguing the other way.
>
> `tools/frontier_corpus.gd` is the ruler this was measured with. It is **deliberately not a registered
> layer**: it asserts nothing, and it should not become one without a separate argument.
>
> **Correction to the line above, made on reading the ceiling's own comment.** The roughness move was first
> written up here as *"0.1pp across a boundary and hairline"*, and that was wrong about what the number is.
> `PAINT_ROUGH_CEIL` is a **ratchet, not a threshold**: its comment records untextured rock at 12.7% across a
> face, the retune that made it read as rock at **5.9%**, and states that 6.5% is *"that, plus enough room to
> move a constant without tripping — this number's job is to stop the slide back, not to name a target."*
> Measured against 5.9% rather than against the ceiling, the face was **already at 6.4% before `9d1841c`** and
> is 6.5% after: two-thirds of the drift away from the design target predates tonight, and the ratchet did
> the job it was installed for. Calling it hairline read the distance to the ceiling instead of the distance
> to the target. The down-a-face axis is fine at 5.7% against 5.6%, so one axis has slid rather than the
> paint as a whole — which also says the cause is directional, not a uniform retune.
>
> **Completed attribution, and the mechanism behind the legibility drop.** A fifth layer belongs on the list:
> the scripted-pilot **play-tests** pass every goal at `9d1841c^` (16 assertions, ALL PLAY-GOALS MET) and fail after
> it. So five reds have **one cause**, and the remaining three in that sweep were not this at all — one was a
> genuinely undeclared field, one was a contention artifact that passes when run alone, and one was a false
> positive off an untracked scratch file.
>
> The legibility drop has a specific mechanism, and it is not the one the headline suggests. **The rock did
> not get less textured — the air got grainier.** On the GRAIN cue the verdict is actually made of, rock
> moved 3.06 → 3.01 while air moved **1.76 → 1.87**, and the gap closed from 1.29 to 1.14 almost entirely
> from the air side. The sample composition moved the same way: 406 solid / 214 air became 516 solid / 186
> air, which is what more shale resistance and fewer caves looks like.
>
> So the actionable target is **the background wall plane behind open air**, which is picking up the new
> strata variety and giving air a texture it should not have. That is a narrower and more tractable problem than
> "the underground got less legible", and it is checkable: quieten the plane behind air and the GRAIN gap
> should reopen from the air side without touching the rock.
>
> **And that fix is not free, so it is not a licence to strip the texture.** `TerrainPainter.paint_wall_face`
> gives the back plane grain *on purpose* — the same vocabulary as the foreground rock at reduced contrast,
> because it is the same ground seen from further away, and its comment is explicit that a wall with no
> texture at all reads wrong. The two requirements are in genuine tension: the plane needs enough texture to
> read as a receding surface and little enough that air does not read as rock. **Deleting the wall grain
> would trade a 7-point legibility loss for a depth-perception loss nothing in the suite measures**, which is
> the worse trade and the invisible one. Whatever is done here needs the GRAIN gap and the wall's own
> read-as-surface property held at the same time.
>
> **And "quieten it" is the wrong move, which this file already knows.** Traced to source: the back wall
> inherits the FRONT ROCK'S OWN strata field at seven-tenths strength —
> `apply_wall_tone(_wall_col[cidx], _tone_at_fine(fx, fy).y * WALL_STRATA_QUIET)`, with
> `WALL_STRATA_QUIET = 0.7` commented *"the same beds, a little quieter back there"*
> (`scenes/fine_terrain.gd:331`, `:1122`). Scattering the shelf bands added bedding variety across depth and
> the plane behind air picked it up at 0.7. That is the air median 1.76 → 1.87, at source rather than by
> inference.
>
> **Fifteen lines above that constant sits the measured refutation of the amplitude fix.** The `VOID_ALPHA`
> note records an earlier round of exactly this fight: *"air's local grain is 2.06 against rock's 1.83. The
> void is textured slightly MORE than the material. That is not a tuning problem and no amplitude fixes it —
> texturing both equally cannot separate them by construction."* It was solved with a **mask**, one level of
> alpha invisible at 254/255, giving the pass something true to gate on. Strata is applied in the *paint*, so
> `VOID_ALPHA` does not gate it and that trick does not reach here.
>
> So the direction is **decorrelation, not attenuation**. The wall samples the *same* strata field as the
> rock in front, so a bed in the rock is the same bed, aligned, in the wall seen through the air beside it —
> which is precisely what makes the wall read as a continuation of the rock instead of a plane behind it.
> Offsetting or re-salting the wall's sample keeps it a textured surface while stopping it agreeing with the
> foreground, and it should reopen the gap from the air side with the rock untouched. **Turning the amplitude
> down is the move this file has already measured and rejected**, and it would cost what `WALL_RECESS` and
> the whole wall-tone pass exist for.
>
> **RESOLVED 2026-08-20 — and the answer is: MOVE NO WORLDGEN CONSTANT.** A four-point bisect over the whole
> play-tests layer settles everything below. First bad commit is `9d1841c` after all, reproduced
> deterministically, with `71481d5` and HEAD carrying an identical failure fingerprint. `1ad38d1` is cleared
> outright by timestamp: it was committed at 04:19 and the failing sweep's log was written at 04:10, naming
> an earlier head — it did not exist in that tree. The 122 retained sweep summaries record `head:` per run,
> and **RUNG 3 passed in 121 of them**, across both branches, from 08-17 through 08-19. It is not flaky and
> never was.
>
> **The defect is in the harness, not the world.** `tools/play_agent.gd:273` gates arrival on
> `here_cell.x == col and player.on_floor` — **x only**. A predicate named *walk to column* cannot tell
> standing on the surface from standing at the bottom of a shaft: one axis where the claim needs two. Traced
> on the shipped function with a concurrent observer, `walk_to_column(75)` returned true with the body
> **twenty-six rows underground**, before any digging; `dig_down_to` was then asked for a cell twenty-four
> rows *above* the body, only digs downward, and mined it deeper still. One commit earlier the same call put
> the body at row 20 and finished in two mines.
>
> **Why the terrain change triggered a latent harness bug, and why that is not a reason to tune terrain.**
> Column 75's own surface is intact at `9d1841c`. The body never fell there — it fell en route. Surface row
> by column across the approach:
>
> | col | 69 | 70 | **71** | 72 | 73 | 74 | 75 |
> |---|---|---|---|---|---|---|---|
> | before | 20 | 20 | **20** | 20 | 20 | 20 | 21 |
> | after | 30 | 30 | **78** | 55 | 51 | 22 | 21 |
>
> **A 58-row chasm opened at column 71**, and rung 3 picks column 75 with the comment *"clear of every
> fixture (they end at 71)"* — so its approach runs straight across the new chasm mouth. **Nothing in rows
> 36–67 was ever involved.** "The lower strata zone is too hard" was never the story, and the director
> question this page raised is answered: there is no evidence the corrected strata zone is too hard, so
> `STRATA_SHELF_EVERY` and `STRATA_SHELF_RESIST` stay where they are.
>
> **One genuinely open design question survives, and it is not a harness matter:** a full-depth chasm
> immediately beside the starting fixtures is either good sinkhole character or a worldgen quality problem.
> Recorded as a measurement, with no constant proposed.
>
> **The paragraph below is kept struck through because its errors are more instructive than its claim was.**
> `(75, 22)` and `(75, 75)` are `Vector2i(col, row)`, both printed whole (`tools/play_tests.gd:943`,
> `tools/play_agent.gd:397`). Row 22 is `surface_row(75) + 1` — the module socket, **one cell below the
> surface**, not a descent target. So the body **started near the surface and ended 54 rows DOWN**; it never
> climbed toward anything, and the new shelf bands are in the region it ended up in rather than on the path
> it was asked to take. The causal story below is built on a column read as a row.
>
> **[SUPERSEDED by the bisect above — the attribution WAS supported; only the mechanism was wrong.]** The play-tests layer was run at `9d1841c^` (all goals
> met) and at **HEAD, forty-nine commits later** — never at `9d1841c` itself. The range in between contains
> `1ad38d1`, a change to `_seed_lodes` in the same file, which alters which cells lodes accrete into — and
> RUNG 3 is the **iron** chain, placed by that function. That commit is at least as good a suspect as the
> shelf scatter, and it is a repair made while investigating the shelf scatter. A correct repair makes every
> unexplained failure near it look like its consequence, including one introduced two commits later by the
> person doing the attributing.
>
> Kept rather than deleted, because the misreading is more instructive than the claim: three of the four
> gauges above were bisected properly with both arms, and this one was allowed to ride on a single arm
> **because it agreed with the others**. A result that fits the pattern gets less scrutiny than one that
> breaks it, which is exactly backwards.
>
> ~~**The severest consequence is not a gauge at all — a progression rung became unreachable.**~~ The scripted-pilot
> play-test's failing goal is **RUNG 3, the L2 iron chain**, missed on both retries, and its own diagnosis is
> unusually specific:
>
> ```
> · ran out of budget digging to (75, 22) (stuck near (75, 75))
> · could not dig the module socket at (75, 22)
> ```
>
> **Corrected before anyone builds on it:** row 75 is *not* the floor of the world, which this note first
> said. The grid is **128 x 128**; row 75 is the bottom of the **strata zone**, since banding stops at
> `STRATA_MAX_ROW = DEEPSLATE_ROW = 76`, with deepslate below it and the seal at row 84 below that. So the
> banded region is the top 59% of the world, not the whole of it, and "the deep half of the world" was the
> wrong name for rows 32–75 — they are the **lower strata zone**. Checking `GRID_ROWS` before writing "the
> floor" would have cost one grep.
>
> The mechanism survives the correction and is in fact sharper. The player was at row 75 needing row 22, and
> **the three new shelf bands sit at rows 36–39, 52–55 and 64–67 — directly across that path**, where
> previously there were none anywhere below row 31. Read beside `check_plunge`, where the legs-only descent
> fell from 34 rows to 27 and the sinkhole mouth moved from column 24 to 68, the two say one thing: **the
> lower strata zone went from no shelf bands to three, and a shelf band adds `STRATA_SHELF_RESIST` to the
> CAVE-CARVE threshold — so it is not that the rock is harder to mine per block, it is that far fewer caves
> open there, leaving solid rock where there used to be passage.** More to dig through, on the exact rows a
> climb out of L2 must cross.
>
> That is the real cost of the repair, and it is a design consequence rather than a bug: the old world was
> easy down there because it was *empty of structure*. The question the four gauges were circling is
> therefore not "which threshold should move" but **"is the corrected deep world too hard, and if so is the
> lever `STRATA_SHELF_RESIST`, the shelf density `STRATA_SHELF_EVERY`, or the dig budget the rungs assume?"**
> That is a director call and it is the one thing on this page that should be answered before anything else
> in Tier 3 is judged, because every legibility and traversal reading below is taken in the world it settles.

---

## The verdict this list is organised around

> SINKFORGE has found a silhouette, but it has not found a soul; dangling over darkness feels like its
> game, while building a factory still feels like its tutorial.

Overall **4.9 / 10** across 20 dimensions. The four lowest are not art problems:

| Lore Load-Bearing | Surprise Budget | Addiction Architecture | The Fun Tax |
|---:|---:|---:|---:|
| **2.2** | **3.2** | **3.3** | **3.5** |

**Three consequences that reorder everything below.**

1. **Human evidence is the bottleneck, not measurement.** 71.3% of changed paths in the last 93 commits
   were under `tools/`. The project has instrumentation abundance and human-evidence scarcity. It can
   measure whether a scripted agent meets "news"; it cannot tell whether a human reads that news as a
   reason to keep playing.
2. **The operative design test changes.** "Factorio × Terraria" is retired as the thing we build against.
   The game is a **kinetic industrial descent**, and the remembered image is the miner on the bending gold
   rope — not a factory. Every item below is ranked by how much it strengthens that.
3. **Automation must create desire, not complete a checklist.** Do not compress extraction, logistics,
   processing, world consequence, and the next bottleneck into one tutorial ceremony. The player must
   experience each manual problem before its automation can feel like liberation.

---

## Product recovery pass, 2026-08-24 — SUPERSEDES "the active set" below, until it is worked through

**Trigger: a live playtest, not a screening.** The user played with one drill, one forge, ten lodes, lost
coal fast, watched items pile up unpickable, and said plainly: "I have no incentive to go down... this
game is unplayable." That was fed to a design review (not this session; a separate PM pass, ~39 min,
preserved in full in `docs/handoff/PRODUCT_RECOVERY_PASS_2026-08-24.md`) which read the actual code
and confirmed: **the mental model failing was not the player's.** Every mechanic the player asked about
(coal-to-power routing, hopper filtering, a self-feeding drill) already exists in `src/core/factory_sim.gd`
— `_COAL_BURNERS`, hopper first-taste filtering, `h_drill`'s self-stock — and none of it has ever been
taught as one coherent machine language. Confirmed independently this session by direct code read (not
taking the PM review's word for it): `factory_sim.gd:380` (`_COAL_BURNERS`), `factory_sim.gd:441`
(`_status_drill`'s `no_fuel` check), `factory_sim.gd:2280-2296` (`_run_hopper`'s first-taste filter),
`factory_sim.gd:242` (`PACK_BULK_CAP = 90`, the un-signalled cap behind the "unpickable piles").

**The corrected automation ladder — this is now the governing design frame, replacing any power-first
assumption anywhere else in this document.** The user's own correction: Factorio's early game is not a
race to electricity; automation arrives in layers, and burner logistics is a real, earned tier of its own
before power exists at all.

| Tier | Player experience | Teaches |
|---|---|---|
| 0 — hand-powered survival | mine, carry, forge, learn gravity | brief, satisfying, not the whole early game |
| 1 — gravity automation | one Drill over a vein feeds a Forge; coal still hand-fed | "the factory works without me," for the ore side only |
| 2 — burner logistics | route coal separately from ore via chained Hoppers, sustain the Drill without hand-feeding | machines need inputs; inputs can be routed; streams differ; layout affects throughput — **this is the tier the game currently skips entirely** |
| 3 — sustainable burner networks | a coal Drill may feed itself, but the lode is finite, throughput competes, a buffer/second machine is needed to stabilize it | self-feeding as an earned puzzle, not a banned exploit and not a free infinite loop |
| 4 — power | Generator arrives only once burner logistics' limits (fuel-hungry, unscalable, high manual load) have actually been felt | power solves *scale*, not *fueling* |

**The governing principle for every future machine, from the PM review, worth holding onto:** *every new
technology should answer a pain the player has personally experienced.* Drill answers repetitive hand
mining. Hopper answers uncontrolled falling output. Burner logistics answers repeated coal-feeding. Power
answers scaling beyond burner logistics. **A machine that arrives before its problem exists is inventory
clutter** — which is exactly what the Bazaar's ~15 purchasable-with-no-reason items are right now.

**This replaces the table in "The active set" below as the actual work queue, in this order, until
explicitly reordered:**

1. **Movement feel pass** — not a Noita clone; remove snagging on corner traps, add ledge forgiveness,
   depenetration, coyote time, tuned accel/braking/air control. Gates how tolerable every other system
   feels, so it goes first.
2. **Pickup and overflow recovery** — every dropped item must resolve to: collectible, redirectable,
   visibly-blocked-with-a-reason, or recoverable, never silent loss. *Three pieces shipped this session*:
   `ca39870` (bazaar "N more wait behind research" no longer draws over the WORKS grid's last row),
   `10d01e3` (an explicit PACK FULL chip, top-right, when `pack_room() <= 0` — previously zero signal
   existed anywhere in the HUD), and `4898252` — the reachability slice, CLOSED for this pass, 2026-08-25.
   Traced the "can't pick up" report to a real, always-reproducible cause: a Drill above a vein and a
   Forge below it, both dug into the same one-cell shaft (the natural shape of hand-mining, and exactly
   what the tutorial teaches), together plug the only way back into that column, so a machine's spare
   output can land somewhere with literally no path to it. `FactorySim.pile_reachable`/
   `first_unreachable_pile` (bounded BFS, reuses the avatar's own collision test) detect it; a new HUD
   chip says so. Deliberately did NOT redirect where anything lands (real pathfinding, out of scope this
   pass) — the recovery already exists (RMB picks the sealing machine back up) and was simply untaught.
   Full detail in the state doc. Still open: a short-range pickup assist / manual collect interaction
   beyond detection, if the "pick the machine back up" recovery turns out to feel too costly in practice.
3. **Separate inventory from Bazaar** — CLOSED, 2026-08-25 (`76cce28`, `05ea38e`, `890f1b7`). Mouse click
   works on all three tabs (WORKS/BENCH/PACK). `B` opens the Bazaar directly on WORKS; the wheel and
   `1`/`2`/`3` can no longer wander a player from Pack into the Bazaar or back. Kept the shared panel
   chrome rather than building two separate panels — the mapping fork's literal call-site inventory (15+
   files, a full `docs/BAZAAR.md` rewrite) was the wrong scope once it was clear the actual complaint was
   cross-navigation, not panel geometry; see `docs/handoff/OVERNIGHT_RUN_STATE.md`'s 2026-08-25 entry for
   the full reasoning.
4. **Rewrite the first automation loop** — CLOSED for this pass, 2026-08-25 (`8bcc206`, `1e84eb4`,
   `286999c`), but not the way this bullet originally proposed. There is no Burner-Drill-vs-Powered-Drill
   split: `docs/DRIFT.md` (shipped, Strike 35) already answered "what makes power matter" with a different,
   deliberate design — the Drift Rig, a separate later machine that draws power instead of coal, built
   specifically because a self-feeding coal drill is "the old constraint wearing a new hat." Building a
   Powered Drill on the original vertical Drill would have contradicted that, not filled a gap. What
   actually shipped: a "hopper" tutorial step teaching coal-routing (the chain jumped straight from
   hand-feeding to researching Power before this), plus hint entries for `drift_rig`, `crusher`, and `spur`
   — all real, craftable, frequently-used machines with zero in-game explanation. `spur` in particular is
   the literal answer to this whole priority pass's opening question ("is 1 drill + 10 lodes the best
   approach") — full detail in the state doc.
5. **Give the Hopper an explicit visual and interaction language** — CLOSED for this pass, 2026-08-25
   (`662ff3e`). Investigation found most of this bullet already shipped in an earlier, unrelated pass:
   the hover panel already read the filter/stock as text, and clearing the filter was already a real
   mouse-clickable knob (`hover_click` -> `_apply_knob`, wired since before this recovery pass started).
   The one actual gap was the "blocked/empty/feeding" state: `_status_mover` gave the Hopper only two
   states, idle and working, so a hopper backed up on a full downstream machine (nothing moving) looked
   pixel-identical to one genuinely feeding a drill. New `FactorySim._status_hopper` mirrors
   `_run_hopper`'s own back-pressure gate and reports a real `blocked` status, which the status-lamp and
   need-bubble system every other stalled machine already uses picks up automatically — no new glyph
   code. `662ff3e` also carries a required doc-count sync (README/CONTRIBUTING/ENGINEERING) and, in
   `ba95841`, an unrelated `check_prose` cleanup a full sweep surfaced along the way (7 files, categorical
   em-dash/vocabulary debt from earlier cycles, no substance changed).
6. **A genuine post-Forge desire** — CLOSED for this pass, 2026-08-25 (`39d924e`), text-only per the
   bullet's own "do not add more machines" constraint. Investigation found the "iron-gated upgrade" example
   already exists as real, substantial, already-built content: `research_rules.gd`'s "ironworks" tech
   (requires DESCENT, sample IRON) unlocks the Iron Forge, which gates plate/gear/borer content in turn — a
   whole tier already visible (dimmed) in the Bazaar Bench's tech tree. The actual gap was framing: the two
   places a player meets the Seal (`hover_info.gd`'s hover text, `objectives.gd`'s final "breach" step) both
   described only the mechanism ("feed it N ingots... then explore on your own"), never naming Stonereach or
   iron as the payoff. Fixed both; new layer `check_seal_desire` (7 assertions) locks the new text in and
   guards the still-present mechanism text against regression. Full detail in the state doc. Still open, if
   this framing turns out not to be enough on its own: a visible unreachable structure or a coal-pressure
   problem, both bigger worldgen/design asks than one pass should attempt without a human read on whether
   the text alone moved the needle.
7. Depth and pacing pass — each layer introduces a new *problem*, not just a new material; preview
   consequences before asking the player to descend.
8. World-material visual pass (soil/rock transitions, tree silhouette/rootedness, material palette).
9. Lighting pass (sourced/occluded, not arbitrary vertical beams; light should carry gameplay information).
10. Typography and panel language (one display face, one body face, less black-rectangle-behind-everything).
11. Machine identity pass (recognizable silhouettes, ports that physically communicate in/out).
12. Journey evaluation — script a fresh-player run scoring stuck time, backtracking, and whether they can:
    collect a dropped item, build the first Drill, understand coal, understand the Hopper, automate one
    real chain, and name their own next reason to descend.

**What this explicitly means for this document:** items 8–11 above overlap real work already tracked in
Tier 3 ("legibility and placeholder art") below — that tier is not wrong, it is *reordered*, subordinate to
1–7 rather than competing with them. Tiers 0–5 and the active-set table immediately below are **not
deleted** and remain a valid map of everything else; they are simply not the next thing to work unless it
is independently unblocked and disjoint from this list (as the two shipped fixes above were).

---

## The active set — a selection, not the top of the ranking

**The tiers below rank importance. They are not a work queue, and reading them as one is the mistake this
section exists to prevent.** `docs/DIRECTOR_BRIEF.md` §5 names five items as simultaneously active, and two
of them are filed in Tier 2 and Tier 3 here. Their rank is not wrong; they are *prerequisites for judging
the items above them*, which is a different property from importance and does not survive being sorted.

| # | Item | Why it is active now | Holder |
|---|---|---|---|
| 1 | ~~**T1.0** the pain the Winch retires~~ — **RESOLVED 2026-08-24: no Forge at the trunk bottom for v1** | `PACK_BULK_CAP = 90` shipped (`71481d5` … `707416c`). The trunk decision is measured (`685646d`, `b0e3348`): a capped trip is a second trip, not a trap. Director ruled directly on the remaining open question — no Forge for v1, since climb cost dominates and grows, and a Forge cannot touch it — see below. Confirming measurement + a real hand-feed bug fix (`machine_eats` had no `winch_head` case) both closed same day | ✅ me |
| 2 | ~~**T0.2 / T1.6** truthful lodes + generated pockets~~ | **SHIPPED 2026-08-17 — archived as a completed prerequisite, see below** | ✅ `303d1f5` + `8498ae3` |
| 3 | **T2.3** the DIG stall | the manual verb must be tolerable before retiring it can read as relief | **peer** |
| 4 | **T3.1** rock/void legibility | a player cannot plan a route through space they cannot parse | **peer** |
| 5 | **T2.1** HUD subtraction | the objective rail must stop manufacturing desire before any evaluation can detect real desire | **me** |

#### T1.0, the measurement half — done, and it returned a gap rather than a number

Measured at `738875c`, `SF_PLAY_ONLY=friction`, seeds 1337 / 512 / 7, against `PACK_BULK_CAP = 90`.

**Nothing in the suite can observe a capped trip.** The four friction rungs are the only instruments that
measure what a trip costs, and the heaviest load any of them reaches is **38 bulk against a cap of 90** —
25/27/25, 38/37/37, 12/12/12, 8/8/8 across the three seeds. It is structural rather than a seed accident:
`_bury_vein` seeds the vein at 40 units and the rungs hand out 12 and 20 earth, so the deepest rung's
arithmetic ceiling is about 74. **The cap cannot bind in any of them even in principle.**

The trip-COUNT evidence does exist, at `factory_sim.gd:218-224` — a 263-unit lode face giving 3 full trips
at cap 90 — but it counted raw ore only and says three is a floor, not an estimate.

**The two do not overlap.** One measures trips-per-face and does not measure cost; the others measure
cost-per-trip and cannot reach the cap. **Cost per trip at the cap has never been measured**, so the
question "is a capped trip still a trip" currently has no instrument, not merely no answer.

One defect was repaired on the way, and it sat directly on this row: the pilot's peak-bulk sampler ran only
on `step()` and `do_mine()`, so a journey that walks without mining never sampled — the jagged-tunnel rung
printed `peak carried: (carried nothing)` while holding 8 bulk. **Hauling is walking.** Fixed at `738875c`;
no ratcheted friction ceiling moved, 17 of 17 play-goals pass.

**WHAT THIS ROW NEEDED NEXT WAS** a friction rung posed ABOVE the cap — a player who fills the pack and
hauls it — reporting frames and trips together. **It exists at `685646d`, and it delivered one of those two
things.** Everything above this paragraph is the state before it and is kept as the gap it closed.

---

#### T1.0, the instrument — BUILT at `685646d`, and the answer moves the question

An ore-bottomed shaft forty deep, thirty rows of ore at three units each on top of a granted twenty:

    PEAKBULK=90 HANDED=20 MINED=70   room_at_end=0   down=true up=true   frames=361 stuck=2
    peak carried: ore=60 rope=50 earth=30 wood_pickaxe=1                 rope_left=8

**The cap is reached for the first time in the suite's history, and the loaded body climbs out.** So the
cap charges TRIPS; it does not strand. That is the evidence the trunk decision rests on.

**The first run said the opposite and was wrong, which is worth keeping.** It read `up=false stuck=128`,
the exact signature of a full pack trapping a player at the bottom of its own shaft. A control at four ore
rows, nineteen bulk short of the cap, printed the SAME `mines=41 places=11 jumps=2 frames=394 stuck=128` —
every driver counter identical while the load differed, so the load was not in the causal path. The rung
had granted twenty-five rope for a forty-deep shaft and `place_rope` spends one unit per segment.

Both assertions carry a demonstrated negative, so neither passes by construction: `filled` is false at four
ore rows, `up` is false at twenty-five rope.

**AND TRIPS, WHICH THE ROW ASKED FOR EXPLICITLY, LANDED AT `b0e3348`.** A 25-cell face holding 280 units
is cleared with `produced 111 = delivered 111` and nothing spilled. **So cost-per-trip and trips-per-face
are one measurement for the first time**, and the row's complaint that the two halves did not overlap is
retired.

**THE "TWO TRIPS" THIS PARAGRAPH USED TO LEAD WITH WAS ONE SEED, AND THE DEFAULT IS NOT IT.** Measured
across the corpus, the yield is identical everywhere and the trip COUNT is not:

| seed | trips | produced / delivered / left for a drill |
|---|---|---|
| 1337 (the default) | **3** — 54, 54, 3 | 111 / 111 / 169 |
| 512 | 2 | 111 / 111 / 169 |
| 7 | 2 | 111 / 111 / 169 |

The vein is fully posed and the burst is a coordinate hash, so the 280 units and the 111 that come out by
hand do not move. What moves is **incidental spoil**: the default run carries `earth=23 wood=7 shale=1`
alongside its ore, and that is what turns two trips into three. **The load-bearing claim is unaffected** —
a capped trip is a second trip rather than a trap — but "two trips" is not the number and the seed has to
travel with it.

**And the figures above were taken through a driver the player cannot reach**, which was found and fixed
this session; see the driver note below. It changed nothing here: old and new drivers give byte-identical
runs on this rung, `frames=573 stuck=8` and the same per-trip splits.

It was blocked for two iterations on a real bug in the pilot, fixed at `f1cf298`: `_rope_anchor_above`
tested only the top of its reachable stretch, so it could not see the one-cell rope gap that a second
descent leaves between the first trip's hang and the second's, and reported the stretch already roped
while the body held 275 rope and could not grip past a bare cell in reach.

Two findings from the same run that change the sink arithmetic:

- **The climb is exempt from the cap.** Fifty rope rode down and back on a pack already at ninety, because
  `is_bulk_item` exempts placeable machines. A sink changes trip count and nothing else; it cannot make
  the descent cheaper.
- **A third of the capped pack was not ore** (`ore=60 earth=30`, of which twenty was granted loadout).
  Spoil competes with freight for the same ninety, so a 2:1 Forge at the trunk bottom compresses the ore
  half only: sixty ore becomes thirty ingot and the trip carries sixty instead of ninety. **A saving of a
  third, not a half.** The sink spike's payoff table says "halves the bulk"; that is true of the recipe and
  false of the haul. Frame: one rung, one seed, one loadout chosen to make the cap bind.

Making the trunk a sink remains a change to gameplay intent and is **not started**. The costed
recommendation is in `docs/handoff/T1_0_SINK_DESIGN.md` and awaits a director yes or no.

#### T1.0 — RESOLVED 2026-08-24: no Forge at the trunk bottom for the first Freight version

**The director ruled directly: no.** A Forge only compresses the ore third of a capped pack (the "third,
not a half" finding two paragraphs up); it cannot touch climb cost, which `trip_frames` (`aa7f8ad`) found
to be the dominant AND GROWING share of a manual trip (58%→73% across 3 trips). For v1, raw ore enters the
Freight Head at the face, the Winch removes the repeated climb, and processing happens at top-side receiver
infrastructure instead of the shaft bottom. Revisit only if later evidence shows payload volume, not
vertical movement, is the bottleneck. Full rationale and the confirming measurement (a real, linked Winch
route run against the same seed/fixture as `trip_frames`, one-time setup cost 784 frames vs. manual trips
`[197,313,318]`, and a climb-only-counter cross-check proving zero additional climb frames across a full
return-mine-feed-deliver cycle) are in `docs/handoff/T1_0_SINK_DESIGN.md`'s closing section.

**One real bug surfaced and fixed while building that confirming measurement:** a player could not hand-feed
a Winch Head at all — `machine_eats()` had no case for `winch_head` behavior (its `MachineDef.recipe` is
`null`), so `try_drop()`'s reachable-eater scan silently never routed to it, despite the Head's own design
doc naming hand-drop as a supported feed path and `_run_winch_head` itself being item-agnostic. Fixed in
`src/core/factory_sim.gd`: `winch_head` now accepts any `is_bulk_item` item (tools, bits, rope, and machine
items stay excluded, the same classifier `PACK_BULK_CAP` already uses). Verified against the full 115-layer
harness sweep.


#### The playtest's zoom finding — a one-row omission in the one surface a first-timer is pointed at

**Reproduced, and three of the acceptance clauses were already met.** Zoom is bound (`KEY_Z`, and D-pad
up), remappable on the settings CONTROLS page (`REMAP_ROWS`), explained on the feel page (*"how much of
the shaft you can see at once"*), and `Z` clashes with no core verb.

**The failing clause was the help surface, and it is also the discoverability clause.** The bottom-left
legend offers `H keys`. `H` opens the CONTROLS card. The card listed **twenty-five controls and not that
one**. `SPEED`, which sits on the very same line of `REMAP_ROWS` as `ZOOM`, has been on the card all
along, which is the tell that this was an omission rather than a decision.

**Shipped `c744f2a`**, and the row cost nothing: `half` is `ceil(n / 2)`, which is 13 at both 25 rows and
26, so the card is exactly as tall as it was and the second column takes the extra entry.

**AND THE FIRST DRAFT OVERFLOWED THE PANEL**, caught by photographing the card and by nothing else. The
card calls `draw_string` with a width of `-1`, so **it has no width guard**: a row wider than
`HELP_COL_W` (236.0) runs out through the right border in silence. The draft was 49 characters against
the 47 of the longest row already present, and its closing bracket sat outside the frame. Shortened,
re-shot, and the trap written beside the row: `check_hud_layout` measures panel RECTS and cannot see text
leaving one, so anyone adding a row here has to look at it.

#### The playtest's "building under the player" finding — rule KEPT, and the footprint is not one cell

**The complaint was literally accurate: it was the one placement refusal with no words.** Too-hard rock
names the drive it wants. The seal names the research. A spur's ghost turns red and the hover says which
half is missing. Standing in your own way turned the ghost red and said nothing.

**"Necessary or forgiving": NECESSARY, and decided on the collision test rather than on taste.**
`scenes/player.gd` blocks the body on `is_solid(cell) or machine_at(cell) != null`, so a machine is a
collider. Placing one where the body overlaps would embed the body inside it. `_placeable` is right to
refuse and the rule stays.

**AND THE BLOCKED FOOTPRINT IS NOT THE SQUARE YOU ARE STANDING ON**, which is why this refusal is the one
a player cannot work out by aiming around. `_player_occupies` intersects the body RECT with the cell rect,
and the body is **34 px tall against a 32 px cell**, so it covers **two rows always and one never**; at
14 px wide it takes a second column whenever it straddles a boundary. Measured on the real scene rather
than derived:

| standing | cells the body rect covers |
|---|---|
| mid-column, x = 1584 | **2** — (49,18), (49,19) |
| centre on the boundary, x = 1568 | **4** — (48,18), (49,18), (48,19), (49,19) |

**Shipped `baff88f`:** the reason joins the hover readout, last in the chain, following the rule `main.gd`
writes down at the skid — *"the words, and only where nothing else has them"* — so a rope underfoot still
answers with the rope. Gated on holding something that would actually have gone there, so standing about
with a pickaxe says nothing. Controls on the real scene: present on the body cell and the cell above it,
absent two cells over, absent with a tool selected and the body unmoved.

**STILL OWED, and it is a third of the acceptance note:** *"with a nearby valid placement path."* Nothing
suggests where the machine COULD go. That is a visible affordance rather than a sentence, so it is left
for a director selection rather than taken unilaterally.

#### The playtest's "adjacent machine" finding, reproduced — and it found a driver fault first

**Investigated per this list's own rule** (*"investigate these during T2.1 ... then promote only after a
controlled replay confirms they recur"*). Reproducing it statically settled where the ambiguity is, and
turned up something that had to be fixed before any replay could be trusted.

**The feed verb the player presses is `try_drop`, and its targeting is CORRECT.** `_reachable_eater` picks
the **nearest machine in reach that actually eats the item**. There is no ambiguity in the rule.

**The ambiguity is that nothing SHOWS it.** With two adjacent eaters at similar distance, a player cannot
tell which will receive before pressing. That is exactly the acceptance evidence this table already asks
for: *"the hovered/selected receiver is visibly identified before drop."* So the finding is a legibility
gap and not a targeting-rule gap, which puts it squarely in T2.1 rather than in the sim. The contract's
second clause is already met: `pickup_machine` salvages both buffers back into the pack, so a mistaken
target costs a dismantle and not the material.

**AND THE DRIVER WAS FEEDING MACHINES THROUGH A RETIRED VERB.** `7d2b20b` ("controls remap + gravity
drop-feed") took `try_deposit()` out of the input path and put `try_drop()` there. `tools/play_agent.gd`
kept calling `try_deposit`, under a header claiming it drives *"the SAME surface a human drives with mouse
and keys."* The two verbs disagree about which machine gets the goods:

    try_deposit   first machine in `sim.machines` that is in reach. BUILD ORDER. No check that the
                  machine wants the item, so it will push coal into something that cannot burn it.
    try_drop      the NEAREST machine in reach that actually eats the item, else the old arc.

`deposit_selected` also hard-coded `sim.machines[0]` as the walk target, so the approach was build-order
coupled too. Both halves are repaired: walk to a machine that will take the item, then press the key a
player presses, and answer on whether the buffer actually grew rather than on whether a stack left the
pack. **Controlled: old and new drivers are byte-identical on the rung that uses it**, so this removes a
latent invalidity rather than correcting a live number.

**Two things the mutation control turned up that are worth keeping.** Neutering the function leaves
*"feed the forge & smelt"* PASSING — that goal already pressed `try_drop` directly and was never affected.
The goal that actually exercises the deposit verb is *"friction: trips to clear a face."* And since both
verbs pass every goal, **the play suite could not have caught this**: it has no rung where two machines
compete for one item, which is precisely the player's complaint.

**Recommended promotion:** the legibility half only, into T2.1's queue, with the receiver highlighted on
the same frame the player is holding a stack. Not promoted unilaterally — it is a visible change and the
kill list forbids solving it with permanent tutorial chrome.

#### Waiting on a priority ID: a citation gate, now with 43 measured instances

The harness workstream is frozen, so this is an ask rather than a plan. Two audit passes over the tracked
tree found **43 wrong `file:NNN` citations** in comments and documents — every one of which RESOLVES, so
the file exists and the line exists and the line says something unrelated. Three of the 43 are worse than
a stale pointer: **quotations attributed to a source that never contained them.**

    "a quick, inefficient grab"          credited to factory_sim.gd; lives in tests/test_sim.gd,
                                         and reads "a quick AND inefficient grab"
    "the large map is centred, off this  credited to hud.gd:837; appears nowhere in the tree
     column -- so the inspector..."
    "yet -- a knob to turn when          credited to factory_sim.gd:207; deleted by the commit
     trip-friction is the thing..."      that turned the knob

Nothing catches this class. `check_prose` reads prose rules, not cross-references. An earlier sweep
existence-checked 276 paths and reported zero defects, which was true and narrow — a dangling path
announces itself, a citation landing on real code does not.

**The cheap form is two rules.** Resolve every `file:NNN` (by basename, since the tree writes `hud.gd`
rather than `scenes/hud.gd`) and fail on past-EOF. Then, for any quoted span attributed to a file,
`git grep` the phrase. The second rule is about three lines and catches the worst class outright.

**What it would cost.** A new layer, so a new registered row, a floor, and sweep time. **What it saves:**
the 43 are repaired, but they accumulated silently between audits and nothing stops the next 43 — the
three files most affected (`hud.gd`, `main.gd`, `world_renderer.gd`) are the three the catalog plan already
names as moving constantly, and `hud.gd` lost two thirds of its length in the decomposition.

**Not started. Needs an explicit yes**, per the freeze.


### Fresh human playtest findings — 2026-08-21

These are direct observations from a short player session, not automated verdicts. They are added as
actionable candidates without allowing one brief session to reorder the active set.

| Candidate | Observation | Recommended acceptance evidence |
|---|---|---|
| ~~**Input discoverability: zoom**~~ **SHIPPED `c744f2a`** | `Z` is an arbitrary choice that a new player is unlikely to infer. | **Met.** Three clauses were already true and are recorded rather than re-earned (remappable, in settings, no clash with core verbs). The failing one was the help surface: the CONTROLS card listed 25 controls and not zoom. See below. |
| ~~**Placement safety: building under the player**~~ **INVESTIGATED, rule KEPT, reason SHIPPED `baff88f`** | The player cannot build beneath their own position, but the refusal is experienced as an unexplained restriction. | **Two of three clauses met — see below.** The rule is necessary (machines are colliders). The reason is now in the hover, where every other refusal already lives. The *nearby valid placement path* is NOT done. |
| **Machine targeting: adjacent inputs** | Feeding coal into one of several adjacent machines is frustrating because the intended receiver is not unambiguous. | With adjacent valid machines, the hovered/selected receiver is visibly identified before drop, and a player can correct a mistaken target without losing the material. |

**Priority placement:** investigate these during T2.1 HUD subtraction and the Bazaar/Works extraction, then
promote only after a controlled replay confirms they recur. Do not solve them by adding permanent tutorial
chrome; prefer clearer targeting, placement affordances, and discoverable controls.

**T0.1 is deliberately not on this list, and the reason is a correction.** It sat at #1 for a day as
*"holder: user"* on a task **the user has no way to perform** — they do not have access to unfamiliar
players. An item nobody can start, parked at the top of a table headed *active now*, quietly converts the
entire list into advice. Worse, the reasoning was misread — including by me. *"Every other rank is a guess
until it exists"* is an **epistemic** claim about our confidence, **not a dependency**: nothing below T0.1
consumes its output as an input, and no item was ever actually waiting on it. It is re-gated in Tier 0
rather than deleted.

Note what #5 buys: Evaluation A (§4.4 of the brief) scores whether a player forms a desire *with no
objective supplied*. While the permanent objective slab is live, that evaluation cannot return a valid
result on this build — the instrument reads the supervisor, not the player. T2.1 is not merely subtraction
for taste; it is the precondition for the highest-priority subjective measurement the project has.

**T1.1 is not on this list**, and that is the brief's most consequential single call. It is approved as the
next *design* target and explicitly **not cleared for implementation** until §7's first question is
answered. Building it now would be building the answer before anyone has asked the question.

---

## TIER 0 — blocks everything else

**T0.1 · Observe three to five unfamiliar players.** Fresh save, no coaching. Record time of first
delight, first confusion, first automation, first voluntary detour, first *"now what?"* Do not ask whether
they liked it until they stop. *(½ day. Vibe week #1.)*

> **UNAVAILABLE, 2026-08-17 — not deferred.** The user does not have access to unfamiliar players. This is
> not "later"; it is a cohort the project cannot obtain, and the list must be honest about that rather than
> keep an unmeetable precondition at the top.
>
> **What survives is the epistemic caveat, which is weaker than the dependency everyone read into it.**
> "Every other rank is a guess until this exists" lowers our *confidence* in the ordering of Tiers 3–5. It
> does **not** block any item, because nothing below consumes a cohort study as an input. Proceed, and hold
> the rankings loosely.
>
> **The human evidence we do have, and have been discounting to zero.** The list previously carried the
> auditor's line that the project has *"no human cohort"* — true — alongside an implicit claim that it
> therefore has no human evidence, which is **false, and it is a boundary error of exactly the kind this
> project keeps catching in its own gauges: the one human in the room was excluded from the population
> being counted.** *"This feels 2003 coded."* *"Preschool."* *"Shitty even when the mechanics are
> correct."* Those came from a human playing the actual build, and they have redirected this project
> harder than any harness layer ever has. One sample, not naive, unblinded, and with an obvious stake —
> every one of which is a real limit and none of which makes it zero. Treat the user's reactions as the
> project's primary human evidence, weight them accordingly, and stop writing as though the cohort we
> cannot get is the only kind that counts.

**T0.2 · Truthful depletion and generated extraction sites. — SUPERSEDED 2026-08-17, NOT CURRENT WORK.**
*Phase 3a shipped in `303d1f5` + `8498ae3`; the live status is the archived block under T1.6 below and the
table at the top of this file. The paragraph that follows is the ORIGINAL framing, kept because it is why
the item existed and what it was allowed to claim — read it as history, never as an instruction.*

> Complete the lode cutover honestly and prove that generated deep pockets create usable extraction sites
> across seeds. A relocatable freight system cannot be evaluated against injected, empty, or non-paying
> sites. This promotes `T1.6` as an evidence prerequisite; it does not waive any of that cutover's red gates.

**What 3a settled and what it did not.** Generated worlds now contain lode across 12 seeds × 5 sizes,
deterministic, legally sited, ingested by the sim and workable. That retires "usable sites do not exist by
construction". It does **not** retire the pay chute (untested, not exonerated), and it does **not** author
phase 3b, which inherits a half-migration this plan's risk table once called impossible.

---

## TIER 1 — the loop (the game's actual problem)

> ## ⚠ CORRECTED 2026-08-21 — THE FINDING BELOW IS HISTORY, NOT STATUS.
>
> **The cap exists.** `src/core/factory_sim.gd:215` is `const PACK_BULK_CAP: int = 90`, with `is_bulk_item`,
> `carried_bulk`, `pack_room` and `can_carry`, and the player verbs ask before they take. Five commits, all
> ancestors of `main` (checked with `git merge-base --is-ancestor`, not by author):
>
>     71481d5  add a bulk carry cap and the predicate the player verb asks
>     b6a5a4f  the carry cap reaches the player, because the rule finally has a seam to live at
>     db6363b  the cap bound on rock and missed ore — take_lode wrote the pack inline
>     93bd934  three more paths were writing the pack inline, and one of my repairs destroyed ore
>     707416c  say at craft_item that its exemption from the cap is a decision
>
> **This block sat at #1 of the active set describing a build that no longer existed**, and it was read as
> current an hour before this correction. A recorded defect is a claim with a timestamp, not a standing
> fact — the same rot that took `public-tree-has-a-live-tell` and INP-01's header. The paragraph is kept
> rather than rewritten because the reasoning under it is still the reasoning, and because a list that
> quietly edits its own past cannot be audited.
>
> **What is still open is below, at SPIKE RESULT: the trunk is not a sink.** The cap creates the trips
> (1 → 3 → 5) and the player then walks back into their own delivery and re-pockets it, so no cap value
> makes a job out of a route with no destination that keeps what arrives.

**T1.0 · THE PAIN THE WINCH RETIRES DOES NOT EXIST IN THIS BUILD.** Found by the peer session, verified
independently in the source rather than relayed. `src/core/factory_sim.gd:206` is a bare
`var inventory: Dictionary = {}`; there is **no `pack_cap`, `carry_cap`, `MAX_CARRY` or bulk limit anywhere
in `src/` or `scenes/`**, while `docs/GDD.md:78` has promised *"carry ore in a **limited pack**, trip by
trip"* for as long as that document has existed. A player pockets arbitrarily large quantities, so hauling
is **one occasional trip, not a repeated job.**

> **The code was never dishonest about this, and that distinction is the lesson.** `factory_sim.gd:207-210`
> says outright that *"no hard capacity is ENFORCED yet — that's a feel/economy knob to turn **when
> trip-friction is the thing being tuned**"*. That is not a comment asserting a guarantee the code lacks
> (shape 22); it is the honest inverse — **a deliberate, documented deferral that became load-bearing for
> an entire design direction because nobody re-read it before designing on top of it.** The note even names
> the condition for turning it on, and that condition is exactly the Freight Winch's premise. Unlike the
> trailer and artifact cases, the remedy here is not another guard: it is *read the code before designing
> against the design doc.*

**Why this outranks the Winch and everything below it.** T1.1 exists to retire face-to-spine deadheading.
Every rank below T1.1 was set against a game in which that manual problem **is not currently possible to
feel**. It also explains **Haul 3.4**, the worst verb on the board: the audit graded a verb whose designed
friction was never implemented, so what it graded was a trip you take once.

**Shape, the user's and not mine:** a separate **generous BULK** limit. Tools and construction components
stay convenient; raw ore and bulk freight consume cargo capacity; roughly **2–4 manual trips of exposure**
before the Winch is attainable; the limit stops mattering once the route is automated. **The tax is
INTERRUPTION, NOT DEGRADED MOVEMENT** — grapple handling stays fast and joyful.

**BLOCKED ON A MEASUREMENT, and the block is deliberate.** Several play-tests drive mining to a goal count
and would meet a cap they have never met. Peer is measuring the maximum single-item quantity any fixture
holds at once, as a histogram. Landing a cap blind would produce a red sweep we could not attribute — a
real regression and a fixture that was silently relying on infinite pockets look identical.

> **THE FLOORS DO NOT MOVE — director ruling 2026-08-17.** *"Continue diagnosis and report
> distributions/rejection reasons. Escalate only an actual design choice, not a missing measurement."*
> **Six-of-eight failing is a finding, not a calibration error, and this is the exact spot where a
> threshold gets edited into agreement with the artifact.** What this lane may do: widen the corpus, report
> the distribution, and name each seed's rejection reason. What it may not do: relax a floor, or escalate
> *"I have not measured enough yet"* as though it were a design fork.

**T1.0 · SPIKE RESULT (directive 0041) — RECOMMENDATION: REFRAME PAIN.** Not PROCEED, not REJECT CAP
SHAPE. Full packet in `docs/tracelog/c2.md` A40; prediction pre-registered on the bus as **0045 before the
treatment run**. Rig `tools/_scratch_t10_cap.gd`: gitignored, unregistered, in no sweep, and it changes
**nothing** in `src/` or `scenes/` — the cap lives in the ACTOR. Generated world, seed 1337. Real held
input (`Input.action_press(Controls.MINE)` + warped cursor), so every unit costs its true `LODE_CYCLE`
0.55 game-seconds; **no `try_*` verb is called as an actor action**, which is the flaw that invalidated A3.

| cap (raw ore) | full trips | delivered | working s | loaded haul s | empty return s | not digging |
|---|---|---|---|---|---|---|
| **OFF (control)** | **1** | 263 | 170.0 | 2.7 | 3.0 | **3.2%** |
| 130 | 3 | 263 | 167.2 | 8.2 | 8.8 | 9.3% |
| 90 | 3 | 263 | 165.6 | 8.2 | 8.8 | 9.3% |
| 65 | **5** | 263 | 164.4 | 13.7 | 14.8 | **14.7%** |

**The control confirms T1.0 at player-legal speed:** uncapped is ONE trip and 3.2% of the session not
digging. **A cap does create the repetition** — 1 → 3 → 5 trips, no prompting, zero pathing failures — and
gravity offers no escape at this site (**0 rows** of open air below the face). Note the curve is a
staircase: 90 and 130 buy the same three trips.

> **But the recommendation is REFRAME, because THE GRAVITY TRUNK IS NOT A SINK.** Ore dropped down the
> shaft rests at its bottom, and walking to the spine puts the body at that bottom — so on the shipped
> default (auto-pickup ON) the player walks back into their own delivery and picks it up again.
> Knockout-verified: ore at the spine reads 65 → 130 → 195 → 260 with auto-pickup on, and 65 → 65 → 65 →
> 65 with it off, where 263 (the face's true content) is the total either way.
>
> **A Freight Winch automates a route; this route has no destination that keeps what arrives.** The
> prerequisite is a consumer at the foot of the trunk. Until one exists, face-to-spine deadheading is a
> trip, not a job — and no cap value fixes that.

**Open, and NOT decided here:** what the sink should be, and whether the 2-4 trip band (cap 65-130 against
this face's 263 units) survives on other sites. One site is one sample.

> ## ⚠ RE-MEASURED 2026-08-21 at `07fba3a` — 3 of 8 PASS, and TWO OF THE FIVE ARE THE PILOT.
>
> The re-run this block has owed since `dc9d8e9` merged. `SF_CORPUS_ONLY=check_pacing bash tools/seed_corpus.sh`:
>
>     1337 ok · 4242 FAIL 24% · 7 FAIL 20.45% · 99 ok · 20260817 FAIL 67% · 31337 FAIL 25% · 512 FAIL 83% · 8675309 ok
>
> **Seeds 20260817 and 512 do not fail the pacing floors. They fail the OPENING**, and their silence and
> density are downstream of an arc that never reaches first automation. The harness drives the game, so
> what it measures is driver∘world, and the walker's own report now separates them:
>
>     20260817  own cell open, ahead open, ahead-floor OPEN;  on_floor=false, v=(0,70), ground 3 below
>               FALLING, in a pit of its own digging. Both hop branches are guarded by `on_floor`, so an
>               airborne body cannot act on the gap it is falling into. It spends the whole 600 frames.
>
>     512       own cell open, ahead open, ahead-floor SOLID; on_floor=true,  v=(0, 0), ground 1 below
>               WEDGED. Standing on solid ground, walkable cell ahead, pushing into it at zero velocity,
>               inside a ONE-ROW gallery it mined. This game already knows a walkable gallery must be two
>               high — it is why the Drift Rig's cutting head is two high.
>
> So the count that matters for the WORLD is **three seeds missing the silence cap by 0.45, 4 and 5
> points** (7, 4242, 31337), not five worlds failing. The other two are a movement bug and a mining bug in
> the pilot. **No floor was moved**, and `7`'s reading is 0.45 points rather than "20%, cap 20%" because
> that line's resolution was fixed in `a68f969`.
>
> Kept rather than rewritten: the corrected-count reasoning below is still the reasoning, and the seeds it
> names are still the seeds. What changed is which of them are statements about worlds.

**T1.0b · THE PACING FLOORS WERE CALIBRATED ON ONE WORLD, AND SIX OF EIGHT FAIL THEM.** Found by the peer
across four ad-hoc seeds, then measured on the committed corpus. `tools/seed_corpus.sh` had never been
pointed at `check_pacing`; it is now in the layer list. Run on `main`'s fixture (the peer's T5.2 descent
repair is branch-only in `dc9d8e9`, so a re-run is owed after that merges), `SF_CORPUS_ONLY=check_pacing`,
tree `/Users/thondascully/Projects/sinkforge`, head `d51c546`:

| seed | longest silence (cap 20%) | density (floor 24.0/1000f) | |
|---|---|---|---|
| **1337** (shipping) | 15% | 32.2 | ok |
| 8675309 | 14% | 28.7 | ok |
| 99 | 21% | 19.7 | FAIL |
| 31337 | 23% | 24.0 | FAIL |
| 7 | 26% | 18.7 | FAIL |
| 4242 | 56% | 13.5 | FAIL |
| 20260817 | 67% | 17.9 | FAIL |
| **512** | **92%** | **3.0** | FAIL |

**TWO OF THOSE EIGHT CELLS ARE INSTRUMENT ARTIFACTS — CORRECTED 2026-08-17.** The peer identified it from
their T5.2 work and I confirmed it against **my own corpus logs**, not theirs, before changing this block.
`check_pacing` prints its session shape and the answer was in the file the whole time:

| seed | descent frames | |
|---|---|---|
| 99 | **0** | the session scored was the OPENING AND NOTHING ELSE |
| 7 | **0** | same |
| 4242 | 262 | real |
| 20260817 | 284 | real |
| 512 | 344 | real |
| 31337 | 370 | real |

On seeds 99 and 7 the descent target row is already open, so `dig_down_to`'s contract returned true on its
first iteration and the agent never moved. The silence *share* inflated because it is a fraction of a
session that lost its second act, and the density fell for the same reason. **Those two rows measure the
fixture, not the world.**

**SO THE CORRECTED COUNT IS 5 OF 8, AND THE ARGUMENT GETS STRONGER RATHER THAN WEAKER.** The bimodality is
cleaner once the artifacts are out:

- **passing:** 1337, 8675309, and 99 (peer's repaired fixture: 17% / 24.5)
- **marginal, silence-only, all within three points of a 20% cap:** 7 (22%), 31337 (23%)
- **severe:** 4242 (56% / 13.5), 20260817 (67% / 17.9), **512 (92% / 3.0)**

**512 IS UNTOUCHED AND IT IS THE WHOLE CASE.** It was the row most exposed to the "your gauge was broken"
objection and it survives it: the descent ran **344 frames**, the session is **10,430 frames with 10,086
of them in the opening alone**, and it is still 92% silence. That world is not failing because the agent
stalled.

> **THE POPULATION OF THOSE SESSION LENGTHS IS THE FAILING CELLS, NOT THE CORPUS — corrected 2026-08-17,
> and the correction is mine.** `seed_corpus.sh:158` copies a log only inside the FAIL branch, so **1337
> and 8675309 left no log and their session and opening lengths are unmeasured.** I printed that fact
> myself while reading the logs — *"no log — cell passed, corpus keeps logs for failing cells only"* — and
> then used the six figures as though they were a sample of the eight. So "the longest of the eight" is
> not supported and has been struck; **512 is the longest of the six that failed.** The opening-phase
> spread across those six is 664 / 1318 / 1381 / 1441 / 1669 / 10086 frames. Selection on a correlated
> outcome can inflate a spread's magnitude but cannot manufacture variance that is absent — if openings
> were seed-invariant these six would cluster regardless of why they were selected — so the *direction*
> survives and the *magnitude* is a statement about failing worlds only. Caught by the blind-evaluation
> actor, in a report I had briefed about exactly this class.

**PROVENANCE, KEPT SEPARATE.** The `descent 0` facts and the six real descent counts are **mine, from my own
logs on `main`**. The corrected values for 99 and 7 (17% / 24.5 and 22% / 23.3) are the **peer's, measured
on their merged tree `7eaa201`** in a two-arm isolation that changed only the call. **My re-run on `main`
is still owed once `dc9d8e9` merges**, and until then this block does not claim those two numbers as
verified here.

**AND THE SESSION-VERSUS-WORLD CAVEAT ABOVE JUST PAID FOR ITSELF.** It said a thin session means the world
is barren *or* the scripted agent fails to make things happen, with opposite remedies and nothing
separating them. Seeds 99 and 7 turned out to be the second one — and not "failed to find events" but
**failed to descend at all**. The caveat was written before anyone knew which; that is the only time such a
caveat is worth writing.

**THE DISTRIBUTION IS BIMODAL, WHICH IS THE PART THAT MATTERS — this is not "the floors are a little
tight".** Two worlds sit with the shipping seed. Three (99, 31337, 7) are marginally over the silence cap
at 21–26%. Three (4242, 20260817, 512) are somewhere else entirely, and **seed 512 is 92% silence at 3.0
events per thousand frames** — a session that is almost entirely nothing happening. A player who rerolls
the seed on the title screen can be handed that.

**AND THIS DATA CANNOT TELL YOU WHY, which is the honest limit of it.** `check_pacing` measures a
**`PlayAgent` session's event stream**, so a thin session means either *the world is barren* or *the
scripted agent fails to make things happen in that world*. Those are a worldgen finding and an
agent-competence finding, they have opposite remedies, and nothing in this table separates them. Seed 512
is extreme enough to be worth opening either way.

**NO FLOOR IS BEING MOVED.** `seed_corpus.sh`'s own header: *"a seed-fragile generator is the FINDING, not
a thing to tune away... If most seeds fail a floor, the floor may genuinely be wrong — but that is an
argument to make explicitly, with the distribution in hand, not a number to quietly edit."* Both sessions
agreed to this independently before the numbers landed. The distribution is the argument; the call is the
user's. The floors' provenance is `check_pacing.gd:48` — *"Measured 2026-08-16: longest silence 15%,
density 30.6"* — one world, on the day they were written.

**IT ALSO CONSTRAINS THE BLIND AGENT-PLAY EVALUATION.** `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` gate 2
requires *"an unmodified generated seed contains usable lode and the first research → drill route can be
completed through player-facing verbs"*. A blind run on 512 would return a terrible result for reasons that
are about the world and not about the opening's design. **The seed-selection rule cannot be "any seed"
until this is understood**, and picking only 1337 makes the evaluation a statement about one world — the
exact failure this row records.

**T1.1 · Freight Winch desirability / route prototype.** Stage the opening as manual mining → automated
extraction → passive downward logistics → automated processing → major logistics payoff → external
consumer. The Freight Winch is the **major logistics payoff**, not the external consumer: a player-placeable,
relocatable cargo route that retires a real bulk-haul task, physically changes the shaft, and exposes a
visible queue or routing bottleneck. It must complement grapple movement rather than become a safe elevator.
First prove pre-reveal demand, one natural route gravity does not already solve, relocation economics, and
a later purpose for the delivered material. See `docs/DIRECTOR_BRIEF.md` §§3–4. **This is the highest-value
new design item, but not yet cleared for blind implementation.**

> **What blocks it is a question, not a schedule** — which is why it does not appear in the active set
> above. `docs/DIRECTOR_BRIEF.md` §7 lists five, to be taken **one at a time as five-option brainstorms**,
> and the first must be answered before an implementation spec can honestly be written:
>
> 1. ~~What exact manual transport pain does the first Freight Winch retire?~~ **ANSWERED 2026-08-17,
>    verbatim, the user's framing:** *"**Face-to-spine deadheading**: as a deposit extends sideways away
>    from the vertical factory spine, the player must repeatedly stop productive work, carry ore back
>    through a tunnel they have already mastered, dump it into the gravity trunk, and return empty."*
>    Their reasons, theirs: gravity already solves downward movement; it arises naturally from horizontal
>    lodes and depletion; it preserves the grapple as the best way to move the *player*; it lets endpoints
>    relocate without relocating the factory; it makes the existing factory **visibly insufficient** — the
>    remote Head fills while the central processor starves; and another extraction face produces *"I need
>    another route"* rather than *"now what?"*. Ranked 2nd–5th: deep-mine→upper-hub (strong fantasy, but
>    encourages one permanent central base), supplies→frontier (begins as maintenance, not liberation),
>    parts→construction-front (depends on content not designed), pack-and-move-the-factory (too episodic
>    for visible throughput hunger). **Their reveal test, verbatim:** *"With the Winch recipe, name, and
>    tutorial hidden, does the player perform repeated face-to-spine trips and independently attempt to
>    eliminate them?"* → **and see T1.0: those trips are not currently possible.**
>    **UNRESOLVED, flagged by the peer as their inference and NOT the user's intent:** the chronology
>    unlocks the Winch after *"two or three identical trips"* — **repetition OBSERVED, not a tech tier.**
>    Nothing in the game unlocks that way and nobody has specified it. Left open deliberately.
> 2. Is its first route a vertical lift, a horizontal collection, or the junction between them?
> 3. What expansion parts or operating resources does it use without becoming a maintenance chore, and
>    how many useful trips amortize one installation?
> 4. What can the player physically *do* with the moving skip and cable?
> 5. What later world-facing consumer gives the delivered material purpose — Descent Engine/Seal,
>    drainage, lighting, construction front, or something else?
>
> These are **user / vision-level decisions.** Answering #1 by picking whichever haul is easiest to
> instrument would reproduce the exact failure the brief was written to stop: building the automated answer
> before the manual problem has been felt by anyone.

**T1.2 · Make each automation stage retire its own labour.** Extraction, transport and processing each
follow a task the player has performed and understood; once automated, that exact repeated labor stays
retired. Later labor must be *qualitatively* different, never the same task at a larger number. Validate
with the Labor Retirement experience evaluation in `docs/DIRECTOR_BRIEF.md` §4.5. *(Fun Tax 3.5.)*

**T1.3 · BACKLOG — one two-input machine that emits a waste stream**, forcing supply *and* disposal as a
new recurring rule. *(Surprise 3.2.)* Strong later complexity; premature before the simple Freight Winch
route proves that one visible logistics bottleneck creates desire.

**T1.4 · Re-time the opening from human evidence, not a 60-second doctrine.** Keep first contact and payout
fast, but do not force a complete production answer before the player understands the manual problems it
solves. Track first dig, first desired automation, automated extraction, automated route, complete line,
and Freight Winch separately. *(First 90s 5.0.)*

**T1.5 · BACKLOG AFTER FREIGHT — one reversible flood consequence** that interrupts a route or machine
without deleting inventory. *(Cruelty 4.2 — "generous about loss, accidentally punitive about time.")*
The environment-as-antagonist direction survives intact; prove stable logistics and readable recovery
before adding the first environmental punishment.

**T1.6 · The lode cutover, phase 3. — PHASE 3a SHIPPED 2026-08-17; 3b NOT AUTHORIZED. NOT CURRENT WORK.**
*Everything in this section is a historical record. The `98.6/100` branch below was never merged and the
standing instruction not to merge on that number is still in force.*

> Active foundation for depletion, relocation, and extraction topology. **Gates are RED** — completion,
> pacing and deep-pocket play all fail — and it prints 98.6/100 anyway. **Do not merge on that number**
> (standing user instruction). The Borer and Drift Rig expose lode but their pay chute draws nothing on a
> generated world; that is the largest known gameplay gap. *(Was AUDIT_UPDATE item 11.)*

**Correction to the last sentence above.** The pay-chute symptom had an upstream cause — generated worlds
held no lode at all — and 3a removed that cause. The chute is therefore **untested, not exonerated**: no
fixture has yet driven a Borer or Drift Rig on a generated world and watched it pay.

> ## ✅ SHIPPED 2026-08-17 — phase 3a, GENERATED lodes. The premise below is now HISTORY, not status.
>
> **Everything from here to the end of this block describes the world BEFORE `303d1f5`.** It is preserved
> deliberately: the zero-lode finding is why the work happened, and a planning document that erases the
> discovery keeps only the answer and loses the reason. Read it as the diagnosis, not as the current state.
>
> **What shipped.** `WorldData.lodes`; `LayeredWorldGen._seed_lodes` / `_grow_lode` writing veins into the
> background plane behind rock that STAYS SOLID; `FactorySim.load_world` ingesting the plane after
> `amounts`, because a lode's richness IS its deposit.
>
> **Evidence, all on GENERATED worlds and labelled as such** (a controlled lode proves the route and says
> nothing about the generator — that rule is below and still binds):
> - 378 lode cells on seed 1337; determinism both ways; six overlap guards at zero; and the chain end to
>   end — buried → not workable; clear the rock → workable; work it → yields its own ore.
> - **Across the fuzz population**, 12 seeds × 5 sizes = 60 worlds: lode legality (host rock, dry, out of
>   the seal, walled), positive richness, whole-plane ingestion (count, per-cell material, positive
>   `lode_max`), and a usable buried vein in BOTH tiers on all 12 production-size worlds — with the arm's
>   own coverage asserted so it cannot pass by skipping.
> - **Targeted mutants that exit red**, anchored inside `_grow_lode`: bypassing the host-rock guard (caught
>   at seed 0 *and*, independently, by the tier arm at seed 42), zeroing the richness, and ingesting
>   `lode_max` as 0.
>
> **THIS DOES NOT EXONERATE THE PAY CHUTE.** An empty world means everything downstream of it was never
> exercised. The chute is **untested, not proven** — it may hold independent defects that only become
> visible now there is lode to draw. The first rig pointed at a generated lode is a real experiment.
>
> **THIS DOES NOT AUTHORIZE PHASE 3b.** 3a is purely ADDITIVE: it adds a class of deposit and converts
> nothing. **Solid-ore deletion remains parked**, along with the conversions, `world_seeder`, the tutorial
> ladder rewrite, sonar, and the Borer/Drift re-source. See `docs/LODE_PLAN.md`, where phase 3 is now split
> 3a/3b and the risk register's top mitigation ("the cutover is one commit") is recorded as VOID.
>
> **Also not established: whether a player can SEE a buried vein.** The through-rock tell is asserted in
> code and unverified in pixels; the one capture taken is invalid for the purpose (the subject was occluded
> by a tutorial bubble). 3b's "sonar re-pointed at lodes through rock" should not assume the stain covers
> it meanwhile.
>
> ---
>
> **THE NO-OUTPUT SYMPTOM HAS AN UPSTREAM CAUSE: GENERATED WORLDS CONTAIN NO LODE.** *Verified
> 2026-08-17, and SUPERSEDED the same day by the block above.* `WorldData` has **no lode field**, **no generator emits lode**, and the only write to
> `sim.lode` outside save/load is `factory_sim.gd:770` — the blow that *opens* a vein. **Lode is derived
> from mining an ore block; it is never generated.** So a fresh generated world contains exactly zero
> lode, the rig cuts rock and has nothing to expose, and it pays on hand-seeded fixtures only because
> those inject lode directly. `docs/LODE_PLAN.md` says as much: phase 1 shipped *"the half of that which
> can be true **before the generator moves**"*, and **the generator has not moved.** So "generated deep
> pockets create usable extraction sites" is currently false **by construction, not by degree** — which
> makes T0.2 the cutover itself rather than a tuning exercise.
>
> **WORDING CORRECTED BY THE DIRECTOR, 2026-08-17, and the correction matters more than the phrasing.**
> This entry previously read *"the pay chute is not broken, the world is empty"* — and one pushed commit
> title (`57e567c`) still carries it, which is not rewritable and is noted here instead. **What is proven
> is that the observed symptom has an upstream cause, not that the chute is sound.** An empty world means
> nothing downstream of it was ever exercised, so the chute is **untested, not exonerated**; it may hold
> independent defects that only become visible once lode exists to draw. I found a sufficient cause and
> wrote it up as *the* cause. That is the same error as grading a component whose input never arrived —
> the absence of a symptom under an absent input is not evidence about the component.
>
> **THE WORKTREE IS EXTREMELY STALE, AND THAT — NOT THE 98.6 SCORE — IS THE REASON NOT TO ADOPT IT
> WHOLESALE.** Read-only comparison of `agent-a0d233e93485c52d9` against current main:
> **336 files changed, 1,501 insertions, 21,068 deletions.** It predates `save_sentinel.gd`,
> `with_machine.sh`, `check_trailers.sh`, `seed_corpus.sh`, `profile_frame.gd` and 537 lines of
> `run_harness.sh`: the entire user-data isolation, trailer-enforcement and machine-lock apparatus.
> **T5.9's "re-derive against current source, not merge wholesale" is therefore not a preference but the
> only safe option.** Treat the worktree as a reference text, never as a branch. Its red gates remain red
> and are a second, independent reason.
>
> **WORDING CORRECTED BY THE DIRECTOR, 2026-08-17.** This previously said merging *would destroy the
> project's infrastructure* and that the deletions *are main's work*. That overstates what a diff shows.
> A tree comparison measures **divergence**, not what any particular merge would do — the number is
> evidence of extreme staleness that makes wholesale adoption unsafe, and it is not a prediction that
> 21,000 lines would be deleted. The conclusion (re-derive, never merge) is unchanged; the reasoning
> offered for it was stronger than the measurement supported.
>
> **The peer is NOT blocked on this.** The directive authorises "one generated **or controlled** lateral
> lode", and `world_seeder.gd` can inject one today — which is how every existing lode fixture works. The
> freight experiment needs a lateral face that *pays*, not one that was procedurally born.
>
> **BUT THE TWO KINDS OF EVIDENCE MUST BE LABELLED SEPARATELY, AND THIS IS A STANDING RULE FOR T0.2.**
> *Director, 2026-08-17:* a controlled seeded lode is **sufficient for the blind freight experiment** and
> is **not evidence that generated-world behaviour works**. They fail differently and they are not
> interchangeable: an injected lode proves the extraction/haul path given a lode, while T0.2's whole claim
> is about what the **generator** produces. The current bug is precisely a case of the first passing while
> the second was false, for months, with nobody able to see the difference — every lode fixture in the
> suite injects. So any T0.2 assertion must state which world it ran on, and a green from a seeded fixture
> may never be cited for a generated-world property.

**T1.7 · Make experience evidence valid before accepting T1.1.** The minimum HUD subtraction needed to
stop objectives manufacturing desire (`T2.1`), honest DIG work (`T2.3`), and rock/void route legibility
(`T3.1`) are playtest prerequisites, not post-loop polish. They may proceed in parallel with lode work.

**T1.8 · Define, then backlog, the first external consumer.** Freight moves cargo; it does not consume it.
After the Winch proves a natural route, choose the modest world-facing appetite it serves. Descent
Engine/Seal is the leading candidate, but no candidate is cleared for implementation until the logistics
payoff and human desire evidence are real.

---

## TIER 2 — subtraction, then one hero machine

**T2.1 · PROMOTED BY T1.7 — remove the visual supervisor.** *(**P1 parent** — see the visual-triage
program at the head of Tier 3; `UI-01`–`UI-15` are its execution queue.)* *A subtraction pass, not a UI redesign.* The HUD is currently the
art director; ~85–90% of the interface floats above the world. *(½ day. Vibe week #5; Diegetic 3.7.)*
- ~~Retire the permanent objective slab after its first lesson; attach later guidance to the world
  object.~~ **SHIPPED (`adb947e` + `e57f381`)** — *"the goal may announce itself; it may not stand over
  you"*, then *"after the first lesson, nothing is offered"*. Both touch `scenes/hud.gd` only.
- **SHIPPED (`18af7cd`)** — the persistent bottom-left key legend now retires learned verbs contextually.
  **THIS LINE IS NOT THE ONE ABOVE IT**, and the marker sitting under an unmarked bullet is why at least
  two readers have merged them: `18af7cd` is *"the key legend retires itself, one key at a time"*. The
  slab's own commits went unmarked for a day, so the adjacent SHIPPED tag was read as belonging to it.
- Stop zone ceremony colliding with map, rope and action; announce once, in a safe composition.
  **THE MAP HALF IS CLOSED AND THE ROPE HALF IS A DIFFERENT KIND OF PROBLEM.** `_draw_arrival` registers
  its solid core into `panel_probe` and `check_hud_layout` carries two states that raise the plate with
  the minimap up, so map-versus-plate is measured and green.

  **The rope half cannot be closed by that layer, and the reason is the finding.** `check_hud_layout`
  compares HUD rectangles against HUD rectangles. Every rope in this game is drawn by `world_renderer.gd`
  — `_draw_ropes` for the placed ladders, `_draw_cord` for the grapple line — in **world space**. There is
  no `_draw_rope` anywhere in `scenes/hud.gd` and no rope rectangle in `panel_probe`. A plate printed
  across the rope is not a collision the layout layer declines to report; it is one the layer's
  **population does not contain**. Not a missing state. **A missing plane.** `HELPER_TAGS` governs
  HUD-versus-HUD and its `critical` rule caps how many interrupts share the screen; nothing anywhere says
  what an interrupt may do to the world it is interrupting.

  **AND THE PLATE CANNOT BE MOVED OUT OF THE WAY, which is derivable from the constants alone.** The
  camera centres the body, so the miner sits at canvas (320, 180) and the plate is centred too, spanning
  canvas y 61.6..111.6 — the 4.3rd to the 7.4th cell above the body, in the body's own column. The core is
  ~114 canvas px either side of centre and `SCRIM_FEATHER` adds 96 more: a ~420 px footprint on a 640 px
  canvas. There is nowhere on the canvas to put it that is not over the miner's own column.

  **MEASURED** (`tools/_scratch_ceremony_over_rope.gd`, a rope hung down a rigged shaft, the body parked
  on it, captures frozen at `time_scale = 0`, the rope's own pixels traced out of the reference frame and
  re-read out of the ceremony frame):

  | band | rows | rope, median dE | rope, mean dE | rock behind it, mean dE |
  |---|---|---|---|---|
  | **across the ceremony** | 151 | **21.2** | **25.8** | 6.6 |
  | below it (drift control) | 151 | 1.3 | 4.3 | 0.9 |

  The rope's own separation from its backing, where nothing is over it, is **41.4 dE** in that band. So the
  ceremony moves about 26 of the 41 dE the rope had, at fifteen times the drift, and **it takes 3.9x more
  from the rope than from the rock behind it**.

  **THE FIRST VERSION OF THIS TABLE REPORTED "89% OF ROWS OCCLUDED" AND THAT FIGURE IS WITHDRAWN.** It
  counted rope rows past a flat 3.0 dE — underneath the control band's own mean drift of 4.5 — so it was
  counting the world moving as the ceremony arriving. Setting the threshold from the data instead (the 95th
  percentile of untouched rows) is the right idea and still not a statistic: **two runs of the identical
  build put that threshold at 34.4 and 4.4**, an eightfold swing off one twinkling row in 151, and the
  headline swung 25% against 84% for a subject that had not changed. The mean over those same rows was 25.8
  and 26.0. The fraction is gone; the means and the median are what `check_ceremony_reads` reports.

  **The median sitting at 21 against a mean of 26 is the part that names the mechanism.** A mean lifted by a
  handful of glyph rows and a mean lifted evenly across the band are the same number. They are not the same
  picture, and the median separates them: this is the VEIL erasing the rope down the whole band, not the
  words landing on a few rows of it.

  **THE MECHANISM IS THE PART WORTH KEEPING, because it is not "a banner is in the way".** The scrim is
  `Color(0.02, 0.025, 0.04)` at alpha 0.80 — a multiply in all but name. Underground the rock behind it
  sits at a luma near ten, so eighty percent of it is nearly nothing and the scrim is almost invisible
  over the mass of the frame. The rope is HEMP at 0.76/0.63/0.42. **A multiplicative veil takes 80% from
  the bright thin things and almost nothing from the dark mass** — it selectively erases exactly the
  rope, the cord and the glints while leaving the rock it was drawn to suppress completely intact. The
  ceremony is not too big. It is subtractive against the wrong population.

  **SHIPPED — the contrast moved from the field to the glyphs.** `SCRIM_ALPHA` 0.80 → **0.28**, and the
  words took their separation locally instead: a near-black shadow one pixel behind every glyph
  (`SCRIM_INK`, `SCRIM_INK_OFF`, `SCRIM_INK_A`). Same guarantee, spent inside a letter's width rather than
  inside a 420 px field.

  **Measured before and after at the same two standings, five runs against four**, and the repeat count is
  not decoration — the first version of this table was built on one run per cell and two of its three
  claims did not survive a proper floor.

  | | before (n=5) | after (n=4) |
  |---|---|---|
  | rope, **median** dE across the plate | 21.1 – 23.2 | **7.6 – 7.8** |
  | rope, mean dE across the plate | 25.6 – 26.8 | 20.5 – 21.0 |
  | rock behind the rope, mean dE | 6.6 – 6.9 | 5.7 – 6.0 |
  | the ceremony's words, underground | 49.3 (one outlier at 43.4) | 48.0 – 48.3 |
  | the ceremony's words, against open sky | 49.5 · 61.9 · 62.0 | 49.0 · 52.2 · 68.4 |

  **The rope result is unambiguous**: the ranges do not overlap on any of the three rope rows. Median −65%,
  mean −20%, and the rock behind it −13%.

  **The two legibility claims I first wrote are withdrawn.** I reported the words *gaining* 11% underground
  (43.4 → 48.1) — that compared the after-set against the single lowest before-run; four of the five before
  runs read 49.3 to 49.7, so the words are **unchanged within noise**, −2.4% on the medians. And I reported
  them *losing* a fifth of their margin against open sky (62 → 50). **My own data refutes it**: the sky
  figure is bimodal in *both* configurations, before 49.5–62.0 and after 49.0–68.4, and the highest reading
  of all nine runs is an *after* one. The ranges overlap completely and **no conclusion about the surface is
  available from three samples a side.**

  So the honest result is better than the story I wrote and rests on less: **the rope's median occlusion
  falls by two thirds and nothing measurable is paid for it at either standing.**

  **~~OWED: the open-sky arm cannot carry a claim yet.~~ PAID at `95f36ea`, and the debt was a statistic
  rather than a sample size.** The 25% swing recorded here was the MEAN's. Thirteen boots of one commit:

  | | range over 13 boots | spread |
  |---|---|---|
  | words vs open sky, **mean** dE | 43.3 – 55.1 | 11.8, **27%** of the low |
  | words vs open sky, **median** dE | 57.2 – 61.2 | 4.0, **7%** of the low |

  The median is the same statistic the deep arm already found carries this measurement, for the same
  reason: a few rows where the sky moved lift a mean and leave a median alone. So no pooling and no
  pinned standing were needed — the arm was reading the right frames with the wrong summary.

  `ceremony.words-vs-sky` is **retired from `tools/stand_downs.txt`** and replaced by a ratchet at 50.0,
  12.6% under the worst of thirteen. **It is a ratchet and not a design bound**: nobody has decided what
  the words ought to read against open sky. The gap is wide on purpose — nine boots put the minimum at
  57.4 and the tenth read 57.2, so a ratchet just under the observed worst gets re-broken by the next
  sample of a duty-cycled cue.

  **AND THE ARM'S OWN OPEN QUESTION WAS ANSWERED BADLY FOR THE CONTROL IT WAS ABOUT.** Its comment said
  nothing had established that the sky alone cannot clear the 400 ink px the positive control demands,
  and that if the figure came back near 400 the control wanted rewriting rather than tightening. Sky
  drift over thirteen boots: 0, 0, 0, 1, 10, 21, 34, 103, 125, 169, 171, 200, 243, **247** — the worst is
  **62% of the bar**. The 400 is kept and joined by a control that travels inside the measurement: what
  the plate put on the screen against what the sky put there by itself, same band, same interval length,
  same run, observed margin 27x.

  **The first version of that control was a guard that could not be false**, and its own mutation control
  is how that was found: written as a bare ratio it reads `ink >= 0` on the boots where the sky does not
  move, and a 100x mutant PASSED on one while still counting toward the layer's asserted total. Floored
  at the absolute count now, so it can never be weaker than the check above it.

  What stays stood down is `ceremony.sky-drift-ratio`, the dE ratio: 1.32x to 8.59x with three of thirteen
  boots having no drift rows at all, so a bound there would fail on the weather rather than on the words.

  **Held by `check_ceremony_reads` (layer 89), both standings, with the words arm added BEFORE the
  treatment.** The scrim was the sole guarantor of the words' legibility, and weakening a sole guarantor
  without first putting an instrument on what it guaranteed is how a disqualified cue takes a defect with
  it — the same shape the peer hit when disqualifying ANISO cost them the only witness to seam direction.
- **THE OCCLUSION RULE SHIPPED, AND THE CLASS WAS THEN CHECKED AGAINST THE OTHER LESSON.**
  `4b7e160` stands the machine inspector down while a stratum plate is up; `5963bba` gives the grapple
  lesson a keep-out list so it lifts off the bend it describes; `3b5d0dc` turns that from a printed number
  into a refusal. **They needed opposite remedies and that is the finding**: the inspector had somewhere
  else to be, the lesson IS the thing being shown and had to move.

  **The SAPLING lesson does NOT need the same treatment, measured rather than assumed** (`73e1b6f`).
  Its gate at `main.gd:740` is `_can_reach(_aim) and can_plant_sapling(_aim)`, so the thing the sentence
  is about is the aimed cell, not the tree. The bubble covers **0 of 1**, clearing it by 18 canvas px,
  and the keep-out list holds **0 points** there because it is populated from grapple pivots only. So the
  clearance is geometry, not the rule.

  **Why it is structural and not luck, with the witness that proves it.** A 13x13 box around the body
  holds **3 plantable and reachable cells and every one of them is on row 19, the body's own row; none is
  above it**. The bubble hangs overhead, so the subject and the panel occupy different bands. A grapple
  pivot can sit above the body and a patch of grass essentially cannot, which is the whole reason one
  lesson needed a keep-out list and the other does not.

  **AND THE CASE THAT WOULD FLIP IT IS STRUCTURALLY UNREACHABLE. Derived, and the derivation is checked
  against the measurement.** An earlier version of this row guessed "a plantable cell 2 or 3 rows above
  the body" off a wrong scale (`HUD_SCALE` is 2.0 and `CANVAS` is 640x360, so a cell is 16 canvas px at
  zoom 1, not 10.67). Redone:

    main.gd:793      a GATED lesson anchors to its own subject, `_cell_center(_aim)` less CELL/2 + 6,
                     so the bubble tracks the subject wherever the subject goes
    measured         bubble origin.y 139.5, box.y 23  ->  tail.y 169.5
    model            anchor = subject - 22 world px = subject - 11 canvas px = 180.5 - 11 = 169.5  ✓
    the flip         `hint_rect` puts the bubble BELOW the tail only when tail.y - 7 - box.y < 38,
                     which for this bubble means tail.y < 68
    reach            REACH_CELLS 3.2 = 51.2 canvas px, so the highest subject a player can aim at puts
                     the anchor near 118 -- fifty px clear of the flip, about three cells of margin

  There IS a narrow covering window, at an anchor of roughly 56..60 canvas px, where `hint_tail`'s clamp
  floor of 60 pins the tail and the flipped bubble at y 67..90 lands on a subject just under it. **A
  player cannot reach it**: it needs the subject about seven cells above the body and reach caps it at
  3.2. It is also the wrong half of the screen for this lesson, which only fires on grass at the surface,
  where the camera clamp puts the body BELOW centre if anything.

  **So the sapling lesson cannot print across the ground it names, and it is not luck: the anchor is tied
  to the subject and the one branch that would break that is out of reach.** No keep-out list is needed
  here. The row is CLOSED rather than parked.

  **`docs/VISUAL_TRIAGE.md`'s own complaint reproduces and is a different claim.** That row reports the
  panel obscuring *the tree*, and **4 of 33 world cells under the panel are wood or leaves**. True, and
  the tree is not what the sentence names, so it is a HUD-over-world observation rather than a
  lesson-over-its-own-subject one. Counted anyway: disqualifying a cue also blinds you to whatever only
  that cue could see.


- ~~Rework or fold away the standalone full-screen **PACK** tab~~ — **REFUSED WITH CAUSE 2026-08-17
  (`144bd5a`). PACK stays.** The premise was that it "does not hold enough decisions to justify erasing
  the world". It holds one, and it is the only place holding it. `FactorySim.inventory_slots()` has **no
  cap** — one entry per item TYPE, against a universe of 20 machine types plus 16 materials plus the
  crafted intermediates — while the hotbar draws ten. `bazaar_row_count()`'s PACK branch returns the full
  count, so the PACK tab is the only surface in the game that shows the rest of your pack. Folding it away
  would not have simplified anything; it would have deleted the only correct view and kept the truncated
  one. **This is the second T2.1 line that measuring split in half** — see the zone ceremony above, which
  collided, but not where the ticket said and not in a way stand-down could fix.
  **AND THE CLAMP THAT HID IT WAS A BUG, NOT A DESIGN.** `_cycle_inventory` wraps modulo the FULL count
  (main.gd:2214), so the wheel walks the selection past the last drawn well — no glow, no border, no lit
  well anywhere — while the name plate, guarded by `sel < slots.size()` rather than `sel < n`, was still
  drawn at the selection's arithmetic position. Measured on the real scene at fifteen carried types with
  the fifteenth selected: bar backing x 144..496, name plate x **618.5..667.5 on a 640 canvas**. Reachable
  on frame one of a dev start (the kit is ten types; the starter pickaxe is an eleventh, seeded by a
  different function). Fixed to a window that contains the selection, with a chevron marking whichever end
  still has pack behind it. Held by `check_hud_layout:_check_pack_window`, mutant-proven three ways.
  **AND THE TICKET'S OBSERVATION WAS RIGHT EVEN THOUGH ITS REMEDY WAS WRONG — now measured.**
  "Erasing the world" is not a figure of speech: the Bazaar's counter panel is **608x348 on a 640x360
  canvas**, and the state covers **91.95%** of the screen (`check_hud_layout` footprint report). Not a
  dimming scrim — that IS the panel. So the *right* subtraction is to shrink the counter, not to delete
  the only surface that shows a pack past ten types. **OPEN, and it is what is left of this line.**
  **AND SHRINKING IT IS NOT THE MOVE EITHER — the alternative was priced.** The counter's content is 528px
  wide; a fourth column is 124.5px, and `_works_row` gives a name `width - 36 - cost glyphs`, about 48px at
  size 10. Four columns truncates every machine name. The 92% is bought by three readable columns and a
  detail plate, not by air: at full tech MACHINES alone holds 19 rows.
  **What was genuinely open was whether the counter needs to be a full-screen modal at all when PACK has
  one row in it** — the fresh-game PACK tab is 1 row in a 21-slot grid covering 92% of the screen, and that
  specific state is the one the ticket was reacting to.
  **SHIPPED — the counter is now the size of what it holds.** `_bazaar_wanted_h()` asks the active tab what
  it needs, eased on the same clock as the panel's rise and clamped between `BAZAAR_MIN_H` (196) and the
  old fixed `BAZAAR_SIZE.y` (348). Measured on the real scene, panel area as a share of the canvas:

  | tab | before | after |
  |---|---|---|
  | **PACK**, fresh game (one item) | 91.8% | **54.5%** |
  | **PACK**, six carried types | 91.8% | 54.5% |
  | **WORKS**, fresh (4 machines + 6 rack) | 91.8% | **67.6%** |
  | **BENCH** | 91.8% | 91.8% — *unchanged, and correctly so* |

  **BENCH staying at full size is the result, not an exception to it.** The tech tree's tallest tier at full
  chip height asks for 504px on a 360px canvas; it is clamped to 348 exactly as before. The panel was never
  too big for the deep end of the game — it was too big for the shallow end, every time, because it was the
  same size at both.

  **The width does not move**, deliberately: the detail plate carries a machine's whole sentence and the
  528px of content width is what buys it. Shrinking to match one 46px well would trade a void for a
  truncation, which is the trade `144bd5a` already refused for a fourth column.

  **AND THE FIRST VERSION SIZED WORKS TO A SINGLE ROW, from the mistake this file already documents.**
  `_works_rows_needed` scanned `works_columns` for the first row count whose columns fit — but
  `works_columns` **clamps its own answer** to `BAZAAR_COLS`, so it fits at one row always, and WORKS came
  out at the 196 floor with its content squeezed to 36px. Eighteen lines above that function, about a
  different caller, the correction is already written down: *"it asks the DEMAND rather than this
  function's already-clamped answer."* I read that an hour before writing the clamped version.
  `works_demand` is now split out so the ask and the grant have different names — **a clamp that shares a
  name with the thing it clamps will be misread again.**

  **And the probe written to verify the fix reported that the fix did nothing.** It posed
  `hud.inventory_open` directly, and `main.gd:792` re-pushes that field onto the HUD every frame, so the
  pose never survived to `_process` — the tell was `_bazaar_t` sitting at 0.00 after forty frames while the
  panel reported its default height. Read through the real owner it gives 54.5% where the posed version
  said 91.8%. Same class as `check_posed_fields`, in the instrument rather than in a fixture. **Twenty
  fields are in that class** (the peer enumerated them from `main.gd::_process`): `alerts`, `can_craft`,
  `hint_alpha`, `hint_anchor`, `hint_text`, `hover_info`, `inventory_open`, `minimap_focus`,
  `minimap_large`, `minimap_view`, `ping_world`, `settings_capture`, `settings_open`, `show_dashboard`,
  `show_help`, `show_minimap`, `time_scale`, `title_info`, plus `set_aim` and `set_guide_targets` on the
  renderer. **The defence that makes the existing harness safe: pose a standalone object and assert on a
  return value, or pose a live scene and assert on pixels — never pose a live scene and assert on pixels
  through a field its owner re-pushes.**


**THE HUD FOOTPRINT, MEASURED, so that "subtraction" stops being an adjective.** *(Stale-prose correction,
2026-08-24: this said "three of T2.1's four lines have shipped" — the fourth, the PACK tab line directly
above, is also resolved: REFUSED WITH CAUSE on its original premise, then SHIPPED on the root cause the
measurement actually found, `_bazaar_wanted_h`. All four of T2.1's original lines are closed. T2.1m, the
larger Bazaar/Settings menu-language item below, remains open and is a separate, much larger scope.)*
`check_hud_layout` now reports the
union area of HUD panels as a share of the canvas, per state, and ratchets the bare screen at the value
measured the day those subtractions landed.

| state | canvas covered |
|---|---|
| the bare screen | **7.84%** — ratcheted at 8.00% |
| paused | 9.02% |
| running fast | 8.46% |
| a machine hovered | 12.55% |
| running fast AND hovering | 13.17% |
| the minimap up | 14.30% |
| a stratum arrival, map up | 19.22% |
| the BIG map (all three forms) | 35.79% |
| the dashboard | 48.26% |
| the help overlay | 60.19% |
| **settings** | **50.97%** — was 79.75% before the page took its category's height (`MNU-26`/`27`/`30`/`31`). AUDIO is the default face; CONTROLS, the tall one, is 432x273. **Both numbers corrected 2026-08-20:** they were 50.97% and 432x292.5, measured before `1f0e478` took `SET_DETAIL` 56 to 36. The footprint is now **47.22%** (`scenes/hud.gd:2768`), and the height re-derives as `SET_HEAD` 40 + 11 remap rows x `REMAP_ROW_H` 15 + 8 + 8 + `SET_DETAIL` 36 + `SET_FOOT` 16 = 273, which is what `docs/MENU_MATRIX.md:724` already said. *The 68.77% once recorded here was stale — on an untouched tree it measured 79.75%* |
| **the Bazaar** | **79.84%** — was 91.95% before the counter took its content's height |

**READ THE BOUNDARY BEFORE READING THE NUMBERS.** `panel_probe` sees `_panel()`, `_round_rect()` and the
arrival scrim; it does **not** see bare `draw_rect`/`draw_string` — chips, legends, glyphs and loose text.
So this is the share of the canvas covered by HUD **panels**, a LOWER BOUND on the HUD's footprint. **It
is not the "~85-90% of the interface floats above the world" figure and does not test it**: that claim is
about the interface's *composition* (screen-space versus diegetic), a different population, and it came
from a subjective audit rather than a measurement. Nothing here confirms or refutes it.

**The ratchet may be LOWERED by measurement after a real subtraction. It must never be raised to buy
green** — raising it is the change that made the HUD bigger, wearing the costume of a calibration. Proven
tight: growing one bare-screen panel by 46px moved the figure 7.84% -> 8.26% and the assertion fired.

**T2.1m · THE BAZAAR AND SETTINGS READ AS A 2008 DASHBOARD.** *(**P6 parent** — `MNU-01`–`MNU-35` are its
execution queue; brief in `docs/handoff/VISUAL_TRIAGE_MENU_UPDATE.md`, root cause as `V5` in
`docs/VISUAL_TRIAGE.md`. Director-filed 2026-08-17 (`f30f88d`). **Do not paste 35 rows into this file.**)*
**Begins after P1's guidance quietness; may explore in parallel with T3.1, and may not displace it.**

**The finding is a system, not four screens.** PACK, WORKS, BENCH and SETTINGS are visually interchangeable
dark applications that represent inventory, fabrication and research — nested rounded black cards, widely
tracked uppercase, gold rectangles carrying six unrelated meanings, detached resource chips, large dead
zones, a dense-but-weak research graph, and a settings page whose alignment visibly breaks down. *"They
fail differently. Do not paint over them one by one before a menu language is chosen."*

**The first deliverable is a capture matrix and ONE reversible prototype, not a rewrite.** Fresh-game PACK
(one row) · midgame PACK (many carried types) · WORKS with available and unavailable selected · BENCH with
one actionable path and late locked branches · SETTINGS including the longest binding list. The prototype
answers six questions: what the Bazaar physically *is* (counter, rack, work order, research board); how the
tabs navigate as semantic sections rather than numbered tutorial steps; **what gold means**, and what
separates selected / locked / unavailable / affordable / actionable; which information is global,
cost-adjacent, contextual, or hidden until inspection; when the world shows behind the interface; and how
Settings gets an independent compact utility layout instead of the Bazaar shell. Director review before
broad implementation.

**Three constraints that are already load-bearing here:**
- **PACK STAYS.** Ruled twice — see the kill list. Fix layout and decision density (`MNU-11`, `MNU-12`).
  **Updated 2026-08-20:** `MNU-11` SHIPPED in `d8bcc87` — the counter takes its active tab's height, so a
  fresh PACK is the compact view, 54.4% of canvas against 91.8%. It had been credited nowhere, and the
  same ledger line still listed it as untouched. `MNU-12` stays open, but its obvious treatment is now
  refused with a reason rather than undecided: the detail plate is the height of what it draws, and cut
  to its old share the price chips overrun it by 29px. The lever is `_draw_bazaar_detail`, not a
  coefficient in front of the height.
- **A green layout test is not proof of a modern menu.** `check_hud_layout` is 57 assertions about geometry
  and it would pass every one of these frames unchanged. Before/after capture review at normal scale is the
  evidence; the harness only proves nothing broke. *This is the same sentence as P1's, and it keeps needing
  to be written because a green suite is the most available thing to mistake for a verdict.*
- **Keyboard-only navigation, focus states, affordability comprehension and settings accessibility survive
  every ticket.** `MNU-32` makes accessibility a visual requirement rather than a footnote.

**Every `MNU-*` closes as `SHIPPED`, `REJECTED`, `BLOCKED`, `INVALID` or `SUPERSEDED`.** Per ticket, report:
frame, observed problem, treatment hypothesis, files claimed, before/after evidence, functional and
accessibility checks, and one of `SHIP` / `REVERT` / `RUN ONE MORE CONTROL` / `DEFER`.

> **DELIVERABLE 1 IS DONE AND THE TICKET LEDGER IS IN `docs/MENU_MATRIX.md` — `c2`, 2026-08-18.** Twelve
> canonical captures (three rungs × three tabs, settings, WORKS-unaffordable, BENCH-actionable), one
> reversible prototype in two variants (`tools/mock_settings.gd`, nothing shipped), and per-ticket closes
> for the nine `MNU-*` touched. **Five of the nine are still open on purpose**; what shipped are defects
> *(Counts stale as of 2026-08-18 and corrected 2026-08-20: the ledger now covers 15 tickets across 13
> sections, of which 9 are open in whole or in part.)*
> found while building the instrument, not the redesign.
>
> **THE FIRST MATRIX WAS POSED WRONG AND EVERY JUDGEMENT MADE ON IT WAS TOO.** The fixture set
> `_hud.can_craft = true`; `main.gd:793` recomputes that field every `_process`. All ten menu captures
> photographed the counter from across the room, and the archive contained **no picture of the Bazaar's
> gold verb button at all**. The tell was in the frame the whole time — `works_full` prices the Forge at a
> green `64/3` and greys out BUILD under the note "at a claimed Bazaar" — and it was looked at, and read as
> the design. The first frame ever taken with the verb live read **`BUILDENTER`**, and the 104px button
> could not hold RESEARCH.
>
> `check_posed_fields` now holds the class statically: twenty per-frame fields read out of the game, every
> fixture write crossed against them, three exemptions each carrying its reason, and the extractor proven
> to fire on a planted write. *(Its own first version matched on field name alone and reported fifty-eight
> offences, fifty-seven of them `_player.position` colliding with `_motes.position` — the layer written to
> catch "the population is not the claim", with a population that was every field with a common name.)*
>
> **`MNU-06` is answered as analysis and not as a repaint.** Gold carries **nine** meanings across
> twenty-nine call sites, not six; the constant's own comment named three of them as if they were examples
> of one. Eight are *look here* at different precisions and stay for director review. The ninth was a
> contradiction — the dashboard drew a machine's STALLED count in the accent — and is fixed against the
> colour the alert stack already used for the same fact.

**Not a Noita reskin.** *"Borrow world-first composition, information restraint, and material hierarchy;
keep SINKFORGE's industrial descent identity."* `MNU-35` exists to hold that line — Noita is the alarm that
these read as generic, not the target.

**T2.2 · Freight Winch as the first hero machine.** Large, animated, unmistakable drum/cable/counterweight
silhouette, visible cargo, startup and catch behaviour, shape-readable state, and a positional sound
identity. Design action and silhouette together, but do not polish hero art before the route creates a
real desire. Do not resprite the catalogue — prove one machine can own a frame. *(Era 5.2, Placeholder
4.1, Name Recall 6.2.)*

**T2.3 · PROMOTED BY T1.7 — fix the honest DIG stall.** ~~Work from the **work-proven 32–35 ms**
baseline~~ — **WITHDRAWN 2026-08-17 (director 0026), and no replacement number is supplied.**
`check_frametime.gd:490` calls `_main.try_mine(target)` directly once per frame; `_update_mining` is never
invoked in that file. Real play accumulates temporal charge *inside* `_update_mining` under **hardness,
tool speed, rhythm and recovery** rules before the spatial verb is reached, so the fixture breaks blocks at
a rate no player can produce and its frame time is not player-time evidence. *(An earlier draft of this
line said play "pays `hardness(mat)/speed` seconds" — that is only the zero-rhythm base, and quoting it as
a formula invites exactly the replacement number this withdrawal forbids. The rate's dependence on rhythm
and recovery state, which the fixture never establishes, is precisely why no figure can be derived.)*
**Note what this number was.** It was trusted *because* the greener figures had already been withdrawn — it
read as the conservative survivor of a prior cleanup, and inherited their credibility by outliving them. A
withdrawal that leaves one number standing implies that one was checked. It was not.
**Before any optimization claim on this lane,** the DIG performance fixture must drive the real input path
or faithfully reproduce temporal input legality. Until then there is no baseline, and "the action holds
frame time" has nothing to hold against. Do not add another break particle in the meantime.
*(1 day. Vibe week #4; Dig 6.3.)* **Peer holds this lane.**

> **THE PRECONDITION IS MET AND THE BASELINE IS SUPPLIED — `c1`, 2026-08-18, three runs, stable.** A probe
> that drives the REAL input path (`Controls.deaf = false`, `Input.action_press(Controls.MINE)` held, the
> cursor warped onto the target so `_update_mining` computes its own `_aim`; nothing calls `try_mine`) run
> against the existing direct-call arm in the same world, same tree:
>
> | arm | blocks broken | blocks/s | p50 ms | p95 ms |
> |---|---|---|---|---|
> | direct `try_mine` (what `check_frametime` does) | 64 | **9.15** | 30.5–32.1 | 34.5–34.9 |
> | the real input path | 8 | **1.14** | **16.60–16.63** | 24.0–25.0 |
>
> **The fixture breaks blocks 8x faster than the game lets a player break them**, and the withdrawn 32–35ms
> is almost exactly the direct arm's p50/p95 here. So the number quoted for the DIG stall was the cost of a
> dig rate that cannot be produced by playing.
>
> **At player-legal rate there is no stall.** p50 lands on **16.6ms**, which is one 60Hz refresh interval to
> two decimal places — vsync-paced, not merely "under budget". p95 at ~24.7ms is about 1.5 intervals: an
> occasional single dropped frame, not a hitch.
>
> **THAT SENTENCE IS TOO STRONG AND I AM CORRECTING IT MYSELF — `c1`, same day, after converting the layer.**
> The probe above runs vsync-paced, which quantises every frame to a refresh interval and hides the shape of
> the tail. `check_frametime` uncaps (`Engine.max_fps = 0`, `VSYNC_DISABLED`), and converted to the real
> input path it reports:
>
>     DIG   mean 10.09ms   p50 9.39   p95 13.19   p99 33.47   worst 36.58   (1.7x a quiet frame, cap 6.0x)
>
> **p99 and worst are within a millisecond of the direct arm's 32.42 and 38.08. The hitch did not go away.**
> What changed is that it is **RARE rather than constant**: the median dig frame is indistinguishable from a
> quiet one, and the cost lands on the frames where a block actually breaks — about **eleven in four
> hundred**. So *"there is no DIG stall"* is as wrong as *"the DIG stall is 32–35ms"*. There is a real ~33ms
> frame; you meet it eleven times in seven seconds instead of every frame. Whether that is tolerable is a
> FEEL question and this ticket's remaining one.
>
> **THE TWO ARMS ARE NOT THE SAME WORK MEASURED TWO WAYS, and the table must not be read as a speedup.** The
> direct arm crams 8x the mining into the same frames; of course it costs more. What the comparison
> establishes is narrower and is the thing the ticket asked for: *the actual verb* is cheap, and *an
> impossible workload* is what was being timed.
>
> **And state what the real arm's p50 IS.** It is the cost of a frame while the dig button is held — most of
> those frames are charge frames under the hardness/tool-speed/rhythm/recovery rules, not break frames. That
> is the right measure for *"is the manual verb tolerable"*, which is this ticket's question, and it is NOT
> "the cost of breaking a block". Do not quote it as the latter.
>
> **`check_frametime` ITSELF IS STILL UNCONVERTED**, so the gate still reports the direct arm's numbers. The
> recorded blocker for converting it — *"it is `add_excl`, therefore headless, and `warp_mouse` is a no-op"*
> — **is false**: `add_excl()` sets `GLFLAG=1` exactly as `add_gl` does, and `run_harness.sh:618` runs any
> `GLFLAG=1` layer WITH a window wherever a display exists. What a conversion genuinely needs is a stand-down
> for CI's headless job, where `warp_mouse` really is inert, so the DIG phase refuses rather than silently
> timing zero mining events.

**T2.4 · Re-test and recapture.** Same build, new players; ask what the game *is* and what they wanted to
do next. Capture a thumbnail only after someone independently describes the desired second goal.
*(1 day. Vibe week #7.)* **USER task.**

**T2.5 · Repository presentation pass — make the repo legible to a senior engineer opening it cold.**
*User-specified 2026-08-17, filed here rather than in Tier 5 deliberately: it is unblocked, touches no
gameplay code, and every day it waits is a day the repo introduces itself badly.* **Bounded.** This is
organization and contributor-experience work — **not** gameplay, rendering, test-threshold, or
architecture refactoring.

*Read first:* `README.md`, `docs/ORCHESTRATOR.md`, `docs/PEER_SESSIONS.md`, `docs/ARCHITECTURE.md`,
`docs/DECISIONS.md`, `docs/PRIORITY.md`, `.gitignore`, `tools/capture_moments.gd`, `tools/zoom.gd`.

*Rules, and they are the ticket as much as the deliverables are:*
- Do not run the full harness or capture tools without the machine lock (`tools/with_machine.sh`).
- Do not alter gameplay code, simulation behaviour, renderer behaviour, test thresholds, save behaviour,
  CI semantics, or the priority order.
- Do not delete user files, rewrite history, or use `git add -A`.
- Preserve tracked image history with `git mv`; do not duplicate 66 MB of captures.
- `docs/tracelog/` is **read-only** to this pass.
- Do not merge or touch other worktrees.
- Before editing, write a file-ownership declaration in your own trace and inspect `git status`.

*Deliverables:*
1. Move the canonical `_moment_*.png` and their tracked sidecars off the repository root, history
   preserved, into one documented home.
2. Update **every** producer, consumer, README link, doc reference and ignore rule that move affects.
3. Keep the image categories unambiguous — `assets/` shipped runtime art only; `docs/media/` curated
   current screenshots used by README and design docs; `history/` the immutable dated visual archive
   (**do not reorganize its internal chronology in this pass**); diagnostic/scratch output ignored,
   never tracked, never at root.
4. README as a landing page: one representative screenshot, a concise premise, how to run safely, how to
   run **focused** tests safely, a small directory map, and links to architecture / design / decisions /
   priorities / contribution guidance. **No claim that the harness is "full" when layers can skip, and no
   unsupported release or export claims.**
5. A concise `CONTRIBUTING.md`: required Godot version, the machine lock and save isolation, the
   focused-test-first workflow, the worktree/ownership protocol, the trace-log protocol, commit hygiene.
6. ~~Move root-level audit/report documents into `docs/`... Fix the filename typo `AUDIT_REPONSE.md` as part
   of that move.~~ **DONE 2026-08-24, the typo-fix half reversed**: moved to `docs/handoff/AUDIT_REPONSE.md`
   (root entry gone); the file's own text says the spelling was requested by the user, missed when this
   line was written, so the spelling is kept rather than fixed. No tracked file referenced it, so nothing
   was "repaired" — every citation already lived in an excluded doc.
7. `docs/REPOSITORY_MAP.md` **only if** README would otherwise be crowded — purpose and ownership, not a
   restatement of architecture.

*Verification:* `git diff --check`; `git status --short`; a `rg` sweep confirming no stale root capture
paths or old audit-report paths survive outside explicitly retained history; README links and moved
capture paths resolve. **Report what moved, what was intentionally left alone, and any uncertain
reference — rather than guessing.**

*Stop after this pass.* Do not broaden into god-file decomposition, test redesign, exports, CI changes or
asset rework.

*The recommended long-term layout (a target to move toward, not a mandate for this pass):*

```
assets/                 shipped game assets only — sprites/ audio/ fonts/
src/                    simulation/domain code — core/ data/
scenes/                 Godot scene / controller / view code
tools/                  developer tools and harness — checks/ capture/ profiling/ support/
tests/                  deterministic unit/integration tests
docs/
  design/               GDD, progression, material spine, lore
  architecture/         architecture and technical decisions
  operations/           orchestrator, peer protocol, repository map
  audits/               vibe / engineering / comprehensive audit reports
  handoff/              session-transfer documents only
  media/moments/        curated current canonical screenshots
  tracelog/             append-only active work traces
  archive/              superseded plans and historical docs
history/                immutable chronological screenshot archive
```

**One conflict this ticket must resolve rather than silently pick a side on.** `_moment_map.png` and its
siblings are *tracked canonical captures*, and several are **stale** — HUD work since they were taken
changes what they should show. Deliverable 1 moves them; it does not authorise **regenerating** them.
Whether a moved capture is refreshed, kept as a dated historical frame, or left alone is the **user's
call**, and the mover must surface the list rather than decide it. See also the standing rule that
`capture_moments`' fixture depths are a historical record and cannot be retuned to suit a new question.

**Measured premises, 2026-08-17 — so the mover inherits facts and not adjectives.** Root holds **43
tracked PNGs totalling 66 MB**, of which **41 are `_moment_*.png`**, plus **30 further root PNGs that are
gitignored scratch** (`_capture_*`, `_diag_*`, `_mock_*`, `_crop_*`) — ignored, but sitting at root, which
rule 3's last clause already forbids. The sidecars are **not** in one-to-one correspondence and the move
must not assume they are: **12 tracked moments carry no tracked `.import`** (`_moment_adit`, `_chain`,
`_delve_after`, `_drift`, `_head`, `_head_z1`, `_lode`, `_pack`, `_refuse`, `_room_after`, `_room_before`,
`_stain`) and **3 tracked `.import` files are orphans whose PNG is untracked** (`_moment_water`,
`_water_body`, `_water_rock`). A `git mv` sweep written as "png plus its sidecar" silently drops fifteen
files. **`_moment_drift.png` is one of the twelve** and it is the tracked sibling of two deliberately-kept
untracked inputs (`_moment_drift_before/after.png`) — untracked is not disposable, and this is the case
that taught us so.

---

## TIER 3 — legibility and placeholder art

**THE VISUAL-TRIAGE PROGRAM (V) — a director-approved active workstream, and PRIORITY.md is deliberately
NOT its queue.** Landed 2026-08-17 as `docs/handoff/VISUAL_TRIAGE_LEAD_HANDOFF.md` (`92bef7e`). Three
documents, verified present, each with a different job — the handoff forbids a fourth:

| question | source of truth |
|---|---|
| what is important now / what may run | **this file** — small parent milestones only |
| what exact visual tickets exist | `docs/VISUAL_RECOMMENDATIONS_SURFACE.md` — **80 tickets**: UI 15, TR 10, SF 7, GR 7, PC 6, **MNU 35** (counted 2026-08-17) |
| why a class matters / what success means | `docs/VISUAL_TRIAGE.md` — root causes, acceptance rules; **V1–V5 root workstreams** |
| how an assigned engineer works | `docs/handoff/VISUAL_TRIAGE_ENGINEER_BRIEF.md` |
| the menu overhaul's brief and first assignment | `docs/handoff/VISUAL_TRIAGE_MENU_UPDATE.md` (`f30f88d`) |
| how visual treatments are compared and how screenshot symptoms are deduplicated | `docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md` — baseline/A/B/C protocol plus the `SUR-*`, `LGT-*`, `UIQ-*`, and `QUA-*` atomic inventory |

**The outcome it is aimed at:** *normal play frames prioritise player action, route, material mass and
visible machine causality over tutorials, labels, target telemetry and undifferentiated texture.*

**Deduplication rule (2026-08-24).** The atomic screenshot inventory in
`docs/VISUAL_DESIGN_SYSTEM_AND_THREE_WAY_EVALS.md` is not a second queue. Do not paste its 50 symptoms into
this file or create one parent per symptom. Map each confirmed symptom to the existing V1–V5/P1–P6 parent,
run one bounded three-way experiment at a time, and update the ticket ledger only when a treatment is selected
and evidenced. `PRESENTATION_AUDIT_2026-08-19.md`, `VIBE_AUDIT_RESPONSE.md`, and
`COMPREHENSIVE_AUDIT.md` remain historical evidence and critique; they do not create new execution items.

**Sequenced on purpose. Work may parallelise INSIDE a phase; a later phase may not use prettier
screenshots to waive an earlier functional gate.** Every ticket closes explicitly as `SHIPPED`,
`REJECTED`, `BLOCKED`, `INVALID` or `SUPERSEDED` — *"waiting" is not a state* and silent abandonment is
forbidden. Status annotations live on the tickets, not here.

**FIRST, A NAME COLLISION THAT THIS TABLE CAUSED AND THIS TABLE MUST FIX.** The execution phases below
came from the *handoff*, which numbers five phases 1–5. `VISUAL_TRIAGE.md` separately numbers five **root
workstreams** `V1`–`V5`. I labelled the phases `V0`–`V5`, and **the two V-namespaces disagree in three of
six slots** — the doc's `V2` is terrain material grammar while my `V2` was interior legibility; the doc's
`V5` is the Bazaar while mine was machines. The director's own correction used both meanings in one
message, which is the collision arriving in practice rather than in theory. **Phases are now `P0`–`P6` and
`V1`–`V5` means only what `VISUAL_TRIAGE.md` says it means.**

| phase | scope | root (`VISUAL_TRIAGE.md`) | attaches to | owner |
|---|---|---|---|---|
| ~~**P0** baseline~~ | **SHIPPED `cb2b34f`** — seven named frames under `docs/media/baseline/` with their provenance, both closure checks run, and six observations separated from inference. Two instrument defects found by looking at what the instruments produced. | — | `docs/media/baseline/README.md` | ✅ **c2** |
| **P1** guidance quietness | `UI-01`–`UI-08` core (SAPLING lesson is the required opening treatment), `UI-09`–`UI-15` only after a helper inventory | `V1` | **T2.1** | **c2** |
| **P2** interior legibility | flat-interior rock/void; contact edge is green and must not be reopened | `V2`/`V3` partly | **T3.1 (6a)** | **c1** |
| **P3** terrain grammar | `TR-01`–`TR-10`, `SF-01`–`SF-03`; one controlled dirt→stone cross-section first | `V2` + `V3` | **T3.12** (new) | **c1** |
| **P4** grapple language | **5 of 7 closed `a528d97`.** `GR-01`/`GR-05` SHIPPED — the preview inked 0.50 of the throw (a dimension line); a stub off the hand inks 0.16. `GR-03` SHIPPED — sag was a flat 26px whatever the length, so a 0.55-slack rope bowed 0.013 of its chord against a bar-taut 0.012; sag-by-length gives 0.237. `GR-02` was ALREADY SATISFIED (0.998 of the corridor differs). **`GR-06` NOW REPRODUCES AND IS THE SUITE'S ONE STANDING RED — this clause is corrected 2026-08-24.** It read *"DOES NOT REPRODUCE (miner 87.5 vs preview 42.5 levels of edge)"*, which was true when written and has been false for weeks. The same comparison now reads **miner 88.0 vs preview 140.8**: **the miner side did not move and the preview side tripled.** Narrowed at `c3e9ea8`, and the narrowing says the number is not a fact about the drawing. Both sides are p90 but their masks are not comparable populations — the preview is a 163px outline that SATURATES (142.7 to 149.7 across its entire top decile) and the miner is a 1071px filled sprite that does not (88.0 to 214.2), because p90 over an outline samples the outline while p90 over a blob samples its flat interior. **The verdict reverses inside the top decile: the miner loses at p90, wins at p99, and wins by 1.44x at the maximum.** A ladder prints beside the verdict every run. Nothing was changed on the strength of it: `BODY_MARGIN` is untouched and picking the percentile that passes would be threshold-shopping wearing a diagnosis. **AND THE 42.5 IS EXPLAINED — that clause is withdrawn 2026-08-24, having stood for one day.** It said the jump was still open and named two candidates, *"the guide mask narrowed onto the ring"* or *"the ring itself got louder"*, the second of which would have sent someone hunting a player-facing regression that does not exist. **Both are wrong and the answer was already written in the layer's own source at `tools/check_grapple_reads.gd:548`**, which I had not read before theorising. The guide mask is GRAIN-CONTAMINATED: `post_fx.gdshader` runs film grain off the shader `TIME` built-in, so pixels cross the mask threshold according to how much WALL CLOCK elapsed between the two captures, and under sweep contention the mask balloons. The retained sweep logs show the whole relationship, and it is INVERSE:

| preview mask | preview level | GR-06 |
|---|---|---|
| 2311 – 6045 px | **2.1 – 5.4** | PASS |
| 465 px | 43.6 | PASS |
| 322 px | 134.2 | RED |
| 141 – 163 px | **140.6 – 142.4** | RED |

A p90 over a mask stuffed with thousands of grain pixels lands in the diluted bulk and reads 2 levels. **So a BIGGER mask, meaning more contamination, made the layer PASS** — diluting the preview is exactly what makes the miner look louder than it. The 42.5 in the retracted clause is the 465-pixel run, one of those false greens.

**THE RECLASSIFICATION THAT MATTERS: GR-06's red is RELIABLE, not flaky, and it became visible when the instrument was repaired rather than when the game changed.** `Engine.time_scale = 0.0` scales shader `TIME` and holds the grain; six posed runs read 141–149 px and 140.6–142.4 levels and GR-06 fails all six. The layer's own words: *"the fix makes the red reliable; it does not remove it."* The *"DOES NOT REPRODUCE"* era was the artifact, not the red. **`GR-04` REPRODUCES and is ESCALATED**: on dark rock the preview adds ~15 levels of edge, on open sky its endpoint mark alone carries ~208, against a miner whose silhouette step is 87 — and it is the RING, not the lead. Reported, never asserted, and the tuning was reverted: *how loud an aim mark should be* is a director call. **OPEN: `GR-07`** (human, in motion). | `V4` | **T3.13** (new, adjacent to T3.10) | **c2** |
| **P5a** machine state | `PC-05` **SHIPPED `85b28e3`** — the idle light-pool gate was furnace-only, so every other machine lit the rock as brightly stopped as running (Drill `D_state` 12.4 → 81.2; stopped was *brighter* than working). `PC-01` **SHIPPED `71b35bd`** — every machine was the same square; one solid body + a per-kind crown took the mean pair difference 0.093 → 0.252 (`check_machine_identity`). **P5a CLOSED.** Escalated, not invented: a 16-screen-pixel cell caps what a silhouette can carry, so *machines wider than one cell* is a director call. **Unblocked after P1. Director ruling 2026-08-17: it does NOT wait on terrain grammar.** | — | **T3.2** | **c2** |
| **P5b** surface composition | `SF-04`–`SF-07` — world-embedding; genuinely wants settled ground under it | `V3` | **T3.11** | **c2** |
| **P6** menu overhaul | `MNU-01`–`MNU-35`; begins with a capture matrix + one visual-language/IA prototype, **not** a reskin | `V5` | **T2.1m** (new, below) | **c2** |

**P5 WAS SPLIT BY DIRECTOR RULING (2026-08-17) AND THE REASON GENERALISES.** It read as one phase blocked
on `P3`, which invented a dependency between *"the Forge reads as a machine"* and *"all dirt-to-stone
grammar is settled"*. Those share a frame, not a cause: `PC-01`/`PC-05` fail because **labels are carrying
state that hardware should carry**, and no amount of terrain grammar fixes that. `SF-04`–`SF-07` really do
want settled ground beneath them. **A phase boundary drawn around a screen region rather than around a
cause will block work that was never dependent** — worth checking the other rows for the same shape.

**`P2` AND `P3` ARE ACCEPTED BY `c1` (2026-08-17), AND THE DIRECTOR HAS SINCE CONFIRMED THE SAME ORDER** —
*"C1's priority is T3.1 interior legibility, then terrain grammar."* `c1` reached it independently: they
read the handoff, `VISUAL_TRIAGE.md` and the ticket table before answering rather than accepting my table,
and said `P3` stays blocked behind `P2` rather than starting terrain grammar while the functional gate is
open. Every remaining phase is **c2's**, and that is now a ruling rather than a proposal.

**`T1.0` DOES NOT MOVE TO `c1` — DIRECTOR RULING 2026-08-17, CORRECTING MY OVERNIGHT ORDER.** I had drafted
the face-to-spine haul measurement and the temporary carry-cap experiment onto `c1` because they hold the
instrumentation that would measure it. *"Do not transfer it merely because C1 can instrument it."* **T1.0
is progression/loop work and it stays in c2's lane** — the reasoning I used would migrate any item to
whoever owns the nearest tool, which is how a lane dissolves. The active-set table above already says
**me**; it was right and the overnight draft was wrong.

**`P0` IS A CAPTURE-DISCIPLINE HAZARD AND IS WRITTEN DOWN AS ONE.** *"Baseline evidence exists without
overwriting canonical captures"* is its completion condition, and this project's canonical `_moment_*.png`
are **tracked**, several are already **stale**, and T2.5 exists partly because of where they live. `P0`
must write to a new location; regenerating a canonical frame to serve a baseline is the failure mode, and
it would be indistinguishable from the work afterwards.

**ITS CLOSURE CONDITION IS AN EXPLICIT PATH CHECK, NOT A CLEAN `git status` — director ruling 2026-08-17.**
*"Do not require a globally clean git status; this is a shared working tree."* Two sessions and several
worktrees write here, so a dirty tree is the normal condition and a green `git status` would be measuring
the peer as much as me — **a gate whose subject is larger than its claim**, the same defect class as the
day's other findings. The two conditions that are actually about `P0`:

1. **no canonical `_moment_*` file was modified** — `git status --porcelain -- '_moment_*.png'` empty, and
   `git diff --stat HEAD -- '_moment_*.png'` empty;
2. **every baseline artifact is under the new noncanonical directory** — enumerate what `P0` wrote and
   assert each path is inside it.

Both name `P0`'s own outputs. Neither can be reddened by the peer, which is the property the `git status`
version lacked.

**AND `_moment_drift_before/after.png` ARE NOT SCRATCH.** They are untracked in `c1`'s worktree, match no
ignore rule, and are the **inputs** to a tracked sibling added by `3c46c8c`. `P0` must not sweep, rename
or regenerate them. *Untracked is evidence about tracking; it is not evidence about value.*

**AND THE ONE RULE THE PROGRAM SHARES WITH EVERYTHING ELSE ON THIS LIST:** *"Do not call a green layout
test proof that the frame is pleasant."* The HUD footprint measurement below is a lower bound on panel
coverage; it is not a claim about how the screen reads. **P1's completion evidence is a human/director
review, and no assertion in the harness substitutes for it.**


**T3.1 · PROMOTED BY T1.7 — rock legibility, TWO problems, not one.** Do not treat as one ticket.

> **A SEPARATION STATISTIC IS NOT A PERCEPTION, AND THIS TICKET IS NOT CLOSED BY A GREEN LAYER.**
> `check_rock_reads` passes and T3.12's block has been lifted on its numbers, so the next reader will
> arrive at a green gate and an unblocked child ticket. Both are true and neither says what this ticket
> asks. Rock grain measures 3.01 against air's 1.65 at a median luma of 11 — a clean 87% separation on a
> difference an eye may not be able to use at all. **What is still owed is a blind vision tester**, and
> nothing computed from pixels can stand in for it. Placed at the head rather than in the unblock note
> because unblock notes are read once and ticket headers are read every time (`c2`, 2026-08-18).
- **6a — outside the lamp, rock and void are the same near-black.** Blind tester: *"I cannot reliably tell
  solid rock from empty air, and I want to say that loudly."* **Do not fix by raising global brightness.**
  *Status — pooled across three viewpoints (`check_rock_reads`, 2026-08-17, three runs, stable): better cue
  **GRAIN 62%** against an unchanged **75%** floor; **VALUE is 50% — a coin flip.** 402 solid / 205 air at
  rows 52 and 51. The INVERSION is closed (`4ffe7e3`). **6a REMAINS OPEN, and the open part is the INTERIOR,
  not the boundary.*** **Peer holds this lane.**

  > **SUPERSEDED 2026-08-18 — THE INTERIOR NOW READS, AND THE 62%/56% FIGURES ABOVE ARE THE PRE-TOOTH
  > BUILD.** Everything in this block down to the partition table was measured before `7181e04` landed
  > `rock_tooth.gdshader` at 23:44:57 on 2026-08-17, and nothing re-measured it for a day. Kept in full,
  > because the reasoning that got here is sound and the numbers are a correct record of the build they were
  > taken on. Current reading, `c1`, four runs, stable (VALUE 70/70/70, GRAIN 88/87/87, CHROMA 94/94/94):
  >
  > | cue | tooth OFF | tooth ON | floor |
  > |---|---|---|---|
  > | pooled VALUE | 51% | **70%** | — |
  > | pooled GRAIN | 61% | **87%** | 75% |
  > | plain interior ON GRAIN | 53% | **86%** | 75% |
  > | plain BOUNDARY ON GRAIN | 90% | **95%** | 75% |
  > | layer exit | 1 | 0 | |
  >
  > **The OFF column is a knockout** of `rock_tooth.gdshader`'s two amplitudes — temporary mutant, restored
  > immediately, never a shipped switch — and it **reproduces the recorded pre-tooth pooled figures** (50%
  > value, 62% grain). That is what makes the comparison trustworthy: the baseline is not a differently
  > shaped run, it is this run with the treatment removed.
  >
  > **THE PARTITION ABOVE WAS MEASURING THE WRONG CUE, and reading it beside the verdict invites a category
  > error I nearly published.** All four arms are fed `stat.x`, the patch MEAN — a VALUE partition judged
  > against air's VALUE — while the verdict is the better of value and grain. So *"plain interior 66% against
  > a 75% floor"* looks like the interior failing, when 66% is an interior VALUE number and the floor is
  > cleared by a pooled GRAIN number. `a1cdd0e` adds the same 2×2 on grain; **interior-on-grain is 86%**.
  >
  > **This retires the one-sided finding.** `SF_WALL_GRAIN=0` gave 50% because rock contributed NOTHING and
  > the whole distinction lived in the back wall. *"A second, independent signal on the ROCK side is the
  > thing that does not exist"* — the tooth is that signal, and it exists now.
  >
  > **REGISTERED (`cb9017b`), and the floor never moved.** 75% before and 75% now; the picture changed, not
  > the bar. Skips under `SF_HEADLESS=1` rather than failing, and `check_ci_coverage` passes with it in.
  >
  > **6a IS CLOSED ON MEASUREMENT AND IS NOT CLOSED ON PERCEPTION, and the gate cannot tell the difference.**
  > Rock's patch grain is 3.01 against air's 1.65 at a median luma of 11 — a statistic can separate at 86% on
  > a difference an eye cannot use. This is the same refusal applied to chroma at 94%, turned against a
  > result I like: the gauge's population is pixels and this ticket's population is a blind tester who said
  > *"I cannot reliably tell solid rock from empty air."* **What is shown is that the renderer encodes the
  > distinction and the gauge can see it. The ticket closes when a fresh zero-context tester says the rock
  > reads.** (The only perceptual evidence so far is `c1` eyeballing tooth-on against tooth-off and seeing a
  > visible fine grain where there had been a smooth gradient — **not blind, and not to be counted as such**.)
  >
  > **AND THE BLIND RUN IS BLOCKED ON THE STALE BASELINE.** 41 of 48 tracked `_moment_*.png` predate at
  > least one renderer commit, so the frames a vision tester would judge are not this build. That is `c2`'s
  > canonical-capture finding and this result from the other end — the same problem.

  **THE VALUE APPROACH IS EXHAUSTED. The pooled value gap is 0.4 levels (rock 8.4 vs air 8.8), and value
  alone separates at chance.** No constant closes that, because there is nothing there to amplify.

  **THE PARTITION IS THE ACTUAL DIAGNOSIS, and both arms clear the 40-sample floor for the first time:**
  | subject | n | median | vs air | verdict |
  |---|---|---|---|---|
  | plain **BOUNDARY** rock | 79 | 16.11 | **79%** | **clears the 75% floor — boundaries already read** |
  | plain **INTERIOR** rock | 302 | 7.45 | **56%** | **near chance — this is what fails** |

  So 6a is not a marginal miss across the board. **A rock boundary is legible and already passes; a flat
  expanse of interior rock against a flat expanse of air in the dark is a coin flip.** That agrees with 6b
  from the opposite direction (edge step 13.09 / 6.47 / 8.16 against interior texture 1.8), now with n=302
  behind the interior arm instead of an argument. **Scope any treatment to the flat interior case.**

  > **THIS BLOCK HAS BEEN WRONG THREE TIMES AND THE MIDDLE ONE WAS MINE.** The chain, because no single
  > number here has survived a change of instrument:
  > | reading | method | status |
  > |---|---|---|
  > | 53% vs a coin flip; *"THE VALUE APPROACH IS NOW EXHAUSTED"*; inversion at air 9.9 / rock 8.6 | broken world→pixel projection (32px/cell against a true 48px) | **withdrawn** |
  > | GRAIN 70% / VALUE 67%, value gap 4.9 | projection repaired (`c6f23b8`), but **single viewpoint centred on the lamp** | **withdrawn** |
  > | GRAIN 62% / VALUE 50%, value gap 0.4, boundary 79% / interior 56% | repaired **and pooled across three viewpoints**, three runs | current |
  >
  > **I STRUCK "THE VALUE APPROACH IS NOW EXHAUSTED" AND IT WAS RIGHT.** I removed it in `643ebf1` on the
  > strength of the 4.9 gap, writing that it "declares a route dead on evidence that no longer exists."
  > The pooled gap is **0.4**. The original sentence was better evidenced than my correction to it, and it
  > is restored above in my own voice on the pooled figures. The peer supplied the number; **I made the
  > edit**, and a correction is not safer than the claim it replaces merely because it is newer.
  >
  > **WHY POOLING CHANGED IT, and this is the transferable part:** the lamp rides the player and the camera
  > centres on the player, so a single frame always judges the region the lamp is standing in. One
  > viewpoint is not a small sample of the world — it is a *biased* sample of it, and the bias points at
  > the best-lit rock in the frame. 6b's single-viewpoint reading cleared its floor by one point and its
  > pooled reading cleared by ten; 6a's went the other way, 70% to 62%. **Direction of movement is not
  > predictable, which is the argument for pooling before publishing rather than after being challenged.**
  >
  > **NOT INDEPENDENTLY VERIFIED BY THIS SESSION.** `check_rock_reads.gd` is on `main`, but the projection
  > repair is not (`c6f23b8` is branch-only), so a run from here reproduces the withdrawn numbers. Recorded
  > as the peer's report with the reason, on the same terms as 6b.
  >
  > **THAT CAVEAT HAS EXPIRED — `c1`, 2026-08-18.** `c6f23b8` is now an ancestor of `main`
  > (`git merge-base --is-ancestor c6f23b8 main`), so a run from either tree reproduces the CURRENT pooled
  > figures rather than the withdrawn ones. Left standing rather than deleted, because the reflex that wrote
  > it is still right; only the fact underneath it moved.
  >
  > **UNTOUCHED BY ANY OF THIS:** the argument that *air is legitimately two things* (sky-lit openness and
  > carved room) is reasoning, not a measurement, and it stands.

  **THE CUE EXISTS, IN COLOUR, AND EVERY GATED STATISTIC IS BLIND TO IT — `c1`, recorded at
  `docs/tracelog/c1.md:1185`, three runs, stable.**

      CHROMA b-r    rock +0.61   air +8.15   gap 7.5   ->  95%      three runs: 95 / 95 / 95

  Against VALUE 50% and GRAIN 62% on the same frames. `check_rock_reads` computes it and PRINTS it, but the
  verdict is `best = max(v_auc, g_auc)` — luma-only — so chroma cannot reach the pass/fail by construction.
  The separation is deliberate renderer design: `BACKROCK_COOL` is `Color(0.10, 0.15, 0.20)`, blue-dominant
  so the wall reads as set BEHIND, while rock's three hue poles average near neutral (TEAL +0.18, BROWN
  −0.13, VIOLET +0.06). The renderer already encodes rock-versus-air in hue and says so in its own comments.
  Nothing measured it. Precedent inside our own suite: `check_water_reads` separates water from the rock
  beneath it on blue-minus-red and passes comfortably, same darkness, same frame, on the axis 6a discards.

  **DO NOT GATE ON IT, AND THAT IS THE POINT.** The gap is 7.5 levels of blue-minus-red at a luma of 8–9,
  and human colour discrimination collapses at mesopic luminance. **A cue can be present in the framebuffer
  and unavailable to the eye.** The gauge's population is pixels; the ticket's population is percepts, and
  this is exactly where those two stop being the same population. Gating here would close 6a by measurement
  alone — the failure mode this document exists to police. **The blind vision tester is the instrument that
  can rule; until it does, this is an added axis and not a fix.** It makes the published luma figures
  NARROWER rather than wrong: *"flat interior rock against flat air is a coin flip"* is true of LUMINANCE
  and false of the frame.

  **AND THE ONE SHIPPED ROCK-SIDE TREATMENT HAS NEVER BEEN MEASURED — `c1`, 2026-08-18.** The pooled 62% is
  dated 2026-08-17; `7181e04` landed `rock_tooth.gdshader` at 23:44:57 that night, and no `check_rock_reads`
  result after it exists in either tracelog. That matters because the amplitude axis was measured
  **one-sided**: `SF_WALL_GRAIN=0` gave 50%, pure chance — rock contributed NOTHING, and the whole
  distinction lived in the back wall's texture. The tooth is the first signal on the ROCK side, and whether
  it moved that is simply unknown. **Re-run before anyone proposes a fifth treatment.** (The sweep knobs are
  out of the tree — `SF_WALL_GRAIN` greps clean — so a knockout needs re-adding as a branch-only mutant,
  never a shipped escape hatch.)

  > **RE-RUN SUPPLIED, 2026-08-24 (overnight coordinator).** Command: `GODOT=/opt/homebrew/bin/godot bash
  > tools/with_machine.sh --script res://tools/check_rock_reads.gd`, three times, `main` at `8143798`.
  > Output:
  >
  > | run | VALUE gap → % | GRAIN gap → % | reported verdict |
  > |---|---|---|---|
  > | 1 | rock 15.1 / air 8.8, gap 6.3 → **88%** | rock 4.21 / air 1.79, gap 2.41 → **85%** | PASS, better cue 87.89% |
  > | 2 | rock 15.1 / air 8.8, gap 6.3 → **88%** | rock 4.22 / air 1.81, gap 2.41 → **85%** | PASS, better cue 87.93% |
  > | 3 | rock 15.0 / air 8.8, gap 6.3 → **88%** | rock 4.19 / air 1.86, gap 2.34 → **85%** | PASS, better cue 87.79% |
  >
  > Against the pooled pre-tooth baseline recorded above (VALUE 50%, GRAIN 62%): both cues moved, stable
  > across three runs, `check_rock_reads: PASS (4 asserted)` on all three. **This is the command and its
  > output, not a claim about the ticket.** Whether an 88%/85% pixel-population separation is a difference a
  > player's eye can use is exactly the open question this section already says only a blind vision tester
  > can close — nothing here answers that, and 6a is not being marked closed on the strength of it. Recorded
  > so whoever proposes the next treatment (or schedules the blind tester) has the number that was missing.

  **TWO MECHANISMS PROPOSED AND REFUTED THE SAME DAY, both `c1`'s, both killed on pre-tooth captures before
  any machine time was spent** (working in `docs/tracelog/c1.md`). (i) *GRAIN is dominated by the
  illumination ramp, because a raw patch std cannot separate texture from a gradient* — a per-patch plane
  fit puts the ramp at 24/34/38% of GRAIN variance at patch radius 10/21/30. Real, and not the story: a
  perfect removal takes std 2.77 → 2.07, which does not carry 62% to 75%. (ii) *the dark is pixel-scale
  speckle, so the four failures were the wrong SCALE and not the wrong amplitude* — box-averaging before
  taking the std gives 2.77/2.44/2.17/1.96/1.26 at 1/2/4/8/16px, so **71% survives an 8×8 average and the
  dark is BROADBAND**. The second was the worse error: a Laplacian magnitude is consistent with a MIXTURE
  and I read it as a proportion. Baseline that survives both: dark-region patch means, median luma **8.59**,
  across-patch spread **7.21**, within-patch **2.80**; chroma b−r median **5.26**, across-patch spread
  **5.94** — comparable to luma, and independent of it.

  **AND THE TICKET IS NARROWER THAN IT READS.** With valid samples, 6a's own 2×2 partition gives plain
  interior rock a median of 5.21 (n=140) against plain BOUNDARY rock at 21.76 (n=30) — **four times**.
  Independently, 6b puts the edge step at 11.7 against an interior texture of 2.8. Two repaired
  instruments, from opposite directions, agree: **contacts read; interiors do not.** So what actually
  fails 6a is *a flat expanse of rock against a flat expanse of air in the dark*, not boundaries — which
  the renderer already handles. Scope the fix to the flat case.

  *(Superseded text, kept so the reasoning is legible: once carved space is excluded from the void floor —
  which `check_room_reads` requires — the inversion returned at air 9.9 against rock 8.6. **Air cannot be one value, because air is legitimately two things**
  (sky-lit openness and carved room), and the two layers assert opposite things about the same cells.
  **No constant closes 6a.** That is a contradiction, not a threshold, and it retires the whole field-cue
  approach by exhausting it rather than by taking the audit's word.)*
  *(End superseded text. The two-things argument above survives every revision; the numbers around it do
  not. **"No constant closes 6a" is back to SETTLED** — I downgraded it to "an open question" in `643ebf1`
  on the withdrawn 4.9 value gap, and the pooled gap of 0.4 restores the original conclusion. Its old
  supporting figures stay struck; the conclusion they were reaching for turned out to be right.)*
- **6b — "inside the lit pool the rock has no edges."** *(Blind-tester report: a soft mottled gradient —
  fog, not carved mass; no contact line anywhere rock meets air.)*

  > **THE GATE IS REGISTERED AND IT DOES NOT MEASURE THIS TICKET'S SUBJECT — `c1`, 2026-08-18, flagged on
  > my own commit.** `check_contact_edge` is now registered (`1b6e9ee`) and passes at detectability 95/95/95
  > and polarity 98/97/97 against a 75% floor. **That is a real property and it is not this bullet's.**
  >
  > The layer EXCLUDES every lit cell — `_is_lit` drops any cell the veil brightened, and a single standing
  > throws away 667 of them. Its own docstring says so plainly: it judges *"deep unlit rock against carved
  > void"*, and that *"6b no longer judges the identical frame 6a does"*. **The headline above is about the
  > LIT POOL.** The blind tester's complaint was that inside the lamp the rock reads as a soft mottled
  > gradient; the instrument answers a question about the dark outside it.
  >
  > That scope change was made honestly and inside the layer, and it was never carried back to the ticket, so
  > the ticket has been quoting a number about the opposite population. **It is the same defect class as
  > every other one found this week — prose describing a system the code stopped being — and I nearly shipped
  > it by registering the gate and calling 6b done.**
  >
  > **What is now true:** the unlit rock/air contact READS, is gated, and cannot regress silently.
  >
  > **THE LIT-POOL ARM IS ADDED rather than the ticket being rewritten** — rewriting a ticket to match the
  > instrument that missed it is closing it by redefinition. Three runs, diagnostic, asserted nowhere:
  >
  > **THE FIRST VERSION OF THIS ARM MEASURED THE WRONG POPULATION, and the peer caught it before the number
  > was quoted anywhere but here.** The unlit arm skips a face when EITHER cell is lit, and I built the lit
  > arm as the naive complement of that — *either* side lit. That population includes every face where the
  > lamp fills the VOID while the rock stays dark, which is the commonest lit-contact geometry there is, and
  > a big step across one of those is a statement about the LAMP'S OWN BOUNDARY rather than about how lit
  > rock reads. 6b's claim is about rock INSIDE the pool, so the predicate that matches the claim is **both
  > sides lit**. `either` and `both` are two populations wearing one name.
  >
  > **The peer's prediction was that the step would collapse toward the 3.8 interior if the arm had been
  > measuring the lamp's edge. It did the opposite** — tightening the predicate moved the step UP, 20.6 →
  > 21.9, on a population that shrank 109 → 96. The faces the old arm was carrying were DILUTING the result,
  > not inflating it. The finding survives its own correction, which is the only reason it is still here.
  >
  > The 342-350 faces with exactly one side lit now belong to NEITHER arm, are counted under their own name,
  > and a new gate asserts the skip breakdown sums to the skip total — an accounting line that does not add
  > up is a line that has quietly stopped naming where its population went.
  >
  > | inside the lamp, BOTH sides lit | r1 | r2 | r3 | r4 | r5 | r6 |
  > |---|---|---|---|---|---|---|
  > | rock\|air faces | 96 | 97 | 95 | 95 | 97 | 97 |
  > | contact step (median) | 22.98 | 22.75 | 21.05 | 21.29 | 21.90 | 21.16 |
  > | lit flat-rock step | 4.49 | 4.57 | 4.55 | 4.42 | 4.38 | 4.59 |
  > | rock brighter | 97% | 97% | 97% | 97% | 97% | 97% |
  >
  > **By this instrument the LIT contact reads BETTER than the unlit one** — 21.9 against an interior of 4.5,
  > where the dark arm is 10.4 against 1.5. **That is not a refutation of the blind tester**, and it must not
  > be recorded as one. Their report has two halves and this measures one of them: *"no contact line anywhere
  > rock meets air"* is now measured; ***"a soft mottled gradient — fog, not carved mass"* is about the
  > INTERIOR of lit rock reading as form**, which is a different property and is still unmeasured. That is
  > the same boundary/interior split 6a turned out to need, arriving from the other side. The renderer has
  > also moved a great deal since the report was written.
  >
  > **THE FORM HALF NOW HAS AN INSTRUMENT TOO, and it answers half of itself.** Fog has no orientation; a
  > mass lit from above does. The renderer claims a key light, so if that light reaches the lit pool the
  > ROCK-side luma must ORDER by which way the face points — and if the medians sit on top of each other,
  > uniform shading is exactly what "fog rather than carved mass" looks like as a number. Six runs:
  >
  > | lit rock by face orientation | spread across 6 runs | n | verdict |
  > |---|---|---|---|
  > | TOP (sky-facing) | 43.6 – 44.6 | 41 | stable inside one level |
  > | SIDE (wall) | 27.7 – 29.5 | 42 | stable inside two levels |
  > | UNDER (ceiling) | 26.8 – 42.8 | **12** | **refused — see below** |
  >
  > **TOP sits ~16 levels above SIDE and both hold to within a level or two across six runs.** That is a key
  > light reaching the lit pool, and it is the opposite of what uniform shading would print. On this axis the
  > lit rock reads as a mass, not as vapour.
  >
  > **UNDER PRINTS NO MEDIAN AT ALL, by a floor added for it.** At n=12 it swung 26.8 to 42.8 — landing
  > either below SIDE or level with TOP depending on which faces the sample caught — because at that size the
  > median moves a whole rank when one face enters. That is not a weak result, it is a coin, and printed
  > beside two solid numbers it would read as the third leg of an ordering and get quoted as one. Widening
  > `VIEWPOINTS` from three standings to seven did NOT help: UNDER stayed at exactly n=12, which says
  > down-facing rock inside a lamp is RARE IN THIS WORLD rather than merely unsampled. The widening also
  > shifted TOP and SIDE by 3-5 levels, so the standing set is load-bearing for the absolute values and was
  > reverted.
  >
  > **So 6b remains open, and what is open has shrunk to one named question:** the contact half is measured
  > and gated, the TOP-vs-SIDE form axis is measured and passes, and what is left is whether the UNDER face
  > participates — which this world may not contain enough of to answer. A blind vision tester remains the
  > only judge of whether ~16 levels of orientation separation is a difference an EYE can use, which is the
  > same open question 6a closed on. A statistic separating cleanly is not a perception.

  **THE MEASUREMENT THIS LANE WAS FOUNDED ON WAS AN ARTIFACT. Read the chain, not a single number.**
  | when | commit | reading | status |
  |---|---|---|---|
  | before 2026-08-17 20:22 | — | *"the contact carries very nearly no information at all"*; edge step **1.38** *below* interior texture 2.1; detect 52%, polarity 51% | **WITHDRAWN** |
  | 2026-08-17 20:22 | `c6f23b8` | the capture layers projected world→pixel at 32px/cell where the true captured size is **48px**, sampling every cell **inboard** of its true position — the interior beside each face instead of the face | the repair |
  | 2026-08-17 20:31 | `036fdca` | post-repair, single viewpoint: step **11.7** vs interior 2.8, detect 76%, polarity 91% — but reach **33/26/11** against an unchanged floor of 40, so **no per-orientation conclusion was drawable** | superseded |
  | 2026-08-17 21:00 | `1e7af35` | pools **three viewpoints** (0, ±12 columns): reach **75/65/75**, detect **86%**, polarity **95%**, three clean runs (86/85/86, 95/95/95) | **reported by peer, NOT independently verified — see below** |

  **Why the pooling was the unlock, and it is a structural fact rather than a tuning result:** the lamp
  rides the player and the camera centres on the player, so the lit region is *always* the middle of the
  judged slab. Carving cannot move it; **standing somewhere else can.** Each viewpoint lights a different
  third and the union covers what no single frame can.

  **NOT INDEPENDENTLY VERIFIED, and the reason matters.** `tools/check_contact_edge.gd` lives on the peer's
  branch under the `0031` freeze, not on `main`, so this session cannot run it. The 21:00 figures are the
  peer's report. They are recorded here because a status doc should say what is known and by whom — not
  retyped into this file's own voice, which is exactly how *"53% vs a coin flip"* became canonical.

  **6b IS NOT SUITE-COVERED.** `check_contact_edge` is **unregistered** in `run_harness.sh` (only comment
  lines 259-260 mention it). It reads `FineTerrain._side_mutant_cells`, which lives in the test-only
  `SF_SIDE_MUTANT` patch `0031` keeps unmerged, so registering it would drag that patch into the suite.
  The counter is inert without the env var, but *inert is not authorised*, and decoupling is a director
  call. **An unregistered layer reads as coverage and is not** — the same defect class as the phantom docs.

  **WHAT THIS COSTS THE PLAN.** If the pooled reading holds, a rock/air contact **is** visible in all three
  orientations **with no renderer change of any kind**, and every treatment proposed against the original
  premise — including `_wall_form`, reverted on its evidence — was aimed at a defect that was not there.
  **The first `_wall_form` negative stands and is NOT reversed by this:** a voided measurement is not
  grounds to restore a patch, only grounds to stop citing the measurement. It stays parked.
- **Corollary from the vibe audit:** *"The frame already has grain; it needs form."* **Stop adding surface
  grain.** Give every solid-to-air boundary a dependable value-and-edge signature outside lamp influence.
  *(Material Honesty 5.6; kill list #10.)*
  *It used to say this "retires a whole approach", on the strength of the withdrawn 6b premise. It does
  not retire anything on its own — it is a human's aesthetic read, and it now sits alongside instrumented
  evidence that boundaries may already carry a signal. Keep it as direction, not as a finding.*

**T3.2 · Machines should look like installed hardware, not UI.** SPUR / DRILL / GENERATOR are flat pale
rectangles with a nameplate — *"tooltips someone left on."* **DRIFT RIG is the exception and is much
better** — chassis, bolts, a visible mechanism. Bring the others up to it. *Folded into T2.2's sprite kit:
do the hero machine first, then this as its family.*

**T3.3 · The clipped green/red stubs at the top-left corner. — CLOSED 2026-08-20. NO LIVE DEFECT; THE
CAPTURES ARE STALE.** It was fixed on 2026-08-18 by `deff5e7`, *"the colour grade was eating the terrain,
one bake at a time"*, whose whole subject is *"a band of pure red and pure green ran the full width of the
frame"*. The fix is one line — `_terrain_viewport.own_world_3d = true` (`world_renderer.gd:391`), the only
commit that has ever touched that string, and `git merge-base --is-ancestor deff5e7 HEAD` passes.

**What the colour actually is, since three sessions failed to grep it.** Nobody wrote it. The bake
SubViewport retains its target (`CLEAR_MODE_NEVER`) and, before the fix, inherited the world environment, so
`adjustment_saturation = 1.18` (`main.gd:484-487`) was re-applied to the *stored pixels* on every incremental
bake. Saturation compounds as 1.18^n until each pixel's dominant channel clips to 1 and the others to 0.
**A pure primary is the FIXED POINT of that map.** The commit records the measured trajectory for one grass
cell: `(87,130,47) → (87,143,35) → (87,160,19) → (87,182,0) → (80,255,0) → (42,255,0)`.

**So "no such literal exists, therefore the colour is computed at runtime" was right about the source and
wrong about what followed from it.** It is computed — by the GPU's environment pass, repeatedly, on stored
pixels. No `.gd`, `.gdshader`, `.tres` or `Color.NAME` search could ever have reached it, and four separate
empty greps were being read as statements about the code rather than about the greps.

**And there is a THIRD bar, which is the confirmation.** A pure BLUE block sits in the same capture at
device `23x23+0+256`. Green, red and blue are the three attractors of a repeated saturation transform;
finding all three is what an authored colour cannot explain. Independently corroborated: the blue is caught
*mid-trajectory*, its top rows reading `(0,36,250)` against `(0,0,254)` below — two stages of one compounding
curve in a single block.

**The old justification is withdrawn even though its conclusion was right.** *"Proven to be world-layer
geometry because the depth chip's alpha dims it"* does not follow: being dimmed by the chip proves only that
it draws BEFORE the chip, which includes earlier draws inside `hud.gd`. The valid exclusion is the post-FX
lens signature the HUD cannot carry — the bars show film grain (238-242 pixel to pixel, not a flat fill) and
chromatic aberration displacing red `+0.62px` and blue `−0.65px` against a predicted `±0.655px` from
`aberration = 0.0007`. The HUD is `CanvasLayer.layer = 10`, above the lens at 5, and gets neither.

**Why only `delve`.** `delve` is the one moment staged by `_dig_in` alone — many incremental chunk bakes, no
reset. `room` and `swing` run the same `_dig_in` and are clean because `_hollow_room` ends with
`repaint_world()` → `CLEAR_MODE_ONCE`, which wipes the retained target. A strict pure-primary scan across
60+ captures hits **only** `_moment_delve.png` and `_moment_delve_after.png`, both committed by `3c46c8c` on
2026-08-17 14:03 — **eleven hours before the fix landed**.

**REMAINING ACTION IS A RE-SHOOT, NOT A CODE CHANGE**, and it is left for the director because it rewrites
tracked binaries: the delve captures are photographs of a renderer that no longer exists. They are now stale
on a second axis too, since the icon work of 2026-08-20 changed `iron`, `rope` and `torch`.

**T3.4 · The hotbar has two identical grey icons.** *"Completely indistinguishable… instantly says
placeholder."* Partly addressed by the silhouette pass (`318f65e`) — **re-verify against current art
before spending on it.**

> **RE-VERIFIED 2026-08-18 (`c2`) — IT REPRODUCES, AND THE PAIR HAS A NAME.** `check_item_reads` now ranks
> the closest pairs by colour on the DRAWN icon (reported, never asserted — turning this into a floor would
> invent a threshold nobody has looked at a screen to set):
>
> | dE | IoU | pair |
> |---|---|---|
> | **1.0** | **0.72** | **deepslate / iron** |
> | 2.2 | 0.33 | rich_ore / stone_pickaxe |
> | 2.9 | 0.31 | stone / gravel |
> | 3.2 | 0.75 | iron_ingot / plate |
> | 3.2 | 0.57 | lance_bit / wedge_bit |
>
> **dE 1.0 is at or below the just-noticeable difference**, and 0.72 IoU means the outlines overlap by
> nearly three quarters. Both are carried, so both can sit in the hotbar at once. The layer is green and
> correctly so: it asserts on the CONJUNCTION of outline and tint (IoU ≥ 0.90 **and** dE < 10), and this
> pair clears the shape half. **A pair separated by shape and identical in colour was invisible in every
> number the layer printed** — which is why the ranking is now printed beside them.
>
> Second and third places are pairs where shape is doing all the work (IoU 0.33, 0.31); those are the
> design working. `iron_ingot`/`plate` at dE 3.2 / IoU 0.75 is the one to watch after `deepslate`/`iron`.
>
> **A method note, because it cost me a wrong answer first.** I ranked the pairs by RGB distance between
> the `Visuals.item_color` CONSTANTS and got a completely different list — it put `iron_pickaxe`/`iron_ingot`
> first and did not have `deepslate`/`iron` in the top ten. The icons are drawn with shading, highlights and
> partial coverage, so the constant is not the icon. **The base colour is a proxy and the drawn pixels are
> the subject**, and only the second one answers the ticket.
>
> **AND THE FIX IS A SILHOUETTE, NOT A TINT — established by trying the tint and being refused.**
> `_item_iron` is `_item_ore`'s polygon and `_item_ore`'s fleck POSITIONS, byte for byte. The two are one
> nugget separated by a single parameter, the matrix value: ore's body `0.44/0.46/0.52`, iron's
> `0.30/0.33/0.42`. **That one number carries two separations in opposite directions.** Dark enough to be
> told from ore and it is deepslate; light enough to be told from deepslate and it is ore.
>
> Enlarging the flecks to four at r=0.085 — which is the icon's own docstring promise, since three dots at
> r=0.06 are a tenth of the covered pixels and the metal was rounding error — cleared `deepslate/iron` out
> of the closest six entirely (dE 1.0, next-worst became `shale/iron` at 3.8) **and immediately reddened
> `check_item_reads` with `ore/iron` at IoU 1.00, dE 9.5**, the exact conjunction the layer asserts on.
> Reverted; the layer is green again and the trade is real.
>
> **The authorised spend is therefore iron's own outline**, after which value is free to leave deepslate.
> `iron_ingot`/`plate` (dE 3.2, IoU 0.75) is the same shape of problem one rung down and is next.
>
> **SHIPPED 2026-08-20 — the outline was spent, and the tint followed it out.** `_item_iron` is now a
> two-lump CLUSTER on a diagonal rather than a copy of ore's nugget, and only then does its host move to
> `0.50/0.55/0.66`. The order is the whole point: the reverted attempt above moved the tint while the
> outline was still ore's, so tint was the only separation left and `ore/iron` collapsed onto the
> conjunction. With the outline separated the tint is free.
>
> **Measured on the drawn icons, which is the only measurement that has ever answered this ticket.**
> `deepslate/iron` leaves the six closest colour pairs altogether — iron appears nowhere in them — and
> **every other entry is unchanged**, so nothing was bought with it:
>
> | | before | after |
> |---|---|---|
> | closest pair | **dE 1.0 · IoU 0.72 · `deepslate`/`iron`** | dE 2.2 · `rich_ore`/`stone_pickaxe` |
> | 2nd–4th | 2.2 / 2.9 / 3.2 | 2.2 / 2.9 / 3.2 — identical |
>
> **The silhouette half was verified WITHOUT the engine, and the method carries its own control.** The
> glyphs are polygons, so IoU is arithmetic: rasterise and count. Calibrating it against two figures the
> layer had already published — `deepslate/iron` 0.72 and `iron_ingot/plate` 0.75 — it returns **0.703 and
> 0.747**, so it agrees with the instrument before being asked anything new. On that footing iron's outline
> goes **1.000 → 0.562** against ore, 0.703 → 0.497 against deepslate, 0.895 → 0.550 against coal, while its
> area barely moves (0.338 → 0.309): it is a different shape, not a smaller one.
>
> **THREE PAIRS IN THIS CATALOGUE WEAR ONE OUTLINE, and only one of them was this ticket.** `ore`/`iron`
> was IoU 1.000 (fixed here); **`ingot`/`iron_ingot` is still 1.000**, and `stone`/`sealrock` is 1.00 —
> both surviving purely on tint, one palette edit from being the same defect. `coal`/`ore` sits at **0.894
> against an assert threshold of 0.90**, which is 0.006 of margin nobody chose.
>
> **Why the suite could not have told you that, stated precisely.** `check_item_reads` ranks and prints the
> **six** closest COLOUR pairs and exactly **one** most-alike OUTLINE pair. So a pair that is identical in
> shape but far apart in tint appears in one line of output at most, and never in the ranking anyone reads.
> *(An earlier draft of this note said the layer never reports shape at all — it does, once. The asymmetry
> is six against one, not six against zero.)*
>
> **The six-deep outline ranking now exists (`62998fa`) and it named a pair nobody had found: `rope`/`torch`
> at IoU 1.00, dE 29.** Two unrelated placeables — the climb and the light — drawn from one outline, both
> carried, both warm amber, separated on tint alone. Was OPEN; **CLOSED 2026-08-24 — STALE, already fixed.**
> `70c92a2`/`bfe88a6` ("rope and torch had no icon at all, only a coloured square") gave both a distinct
> silhouette — coil vs. diagonal haft+flame — after this note was written against two identical placeholder
> squares. Reverified 2026-08-24: `check_item_reads.gd` standalone via `tools/with_machine.sh`, current
> top-6 outline pairs are `stone`/`sealrock` (1.00), `ingot`/`iron_ingot` (1.00), `ore`/`coal` (0.89),
> `earth`/`ore` (0.85), `earth`/`coal` (0.80), `gear`/`coal` (0.75) — `rope`/`torch` is absent, and since
> 1.00 is the maximum value a tie would have to appear at the top. `70c92a2` confirmed an ancestor of HEAD.
> The same run confirms `ore`/`coal` at 0.89 against a 0.90 clash floor, unchanged.
>
> **AND THE LAYER MEASURES THESE ICONS AT ALMOST FOUR TIMES THE SIZE THE GAME DRAWS THEM. OPEN.**
> `check_item_reads.gd:49` renders at `ICON = 48.0`, commented *"the size draw_item is asked for, roughly a
> hotbar cell"*. It is roughly **four** hotbar cells. Every `Visuals.draw_item` call site in `scenes/`:
>
> | size | where |
> |---|---|
> | **13.0** | most of the HUD — carried-count chips, pack rows, detail chips, legend |
> | **12.0** | `hud.gd:2785` |
> | **9.0** | `world_renderer.gd:2321` — an item lying on the ground |
> | 40.0 / `box.size.y` | the detail plate and the bazaar wells, the only large ones |
>
> **So any cue that exists at 48 and dies at 13 is invisible to the layer, and to any contact sheet drawn at
> its default.** This is not hypothetical about the glyphs shipped above: the rope coil's six wrap marks are
> `size * 0.035`, which is 1.7px at 48 and **0.46px at 13** — the marks that stop it reading as a lens are
> sub-pixel at the size it is actually seen. `tools/icon_sheet.gd` now takes the size as an env knob
> (`SF_ICON_PX`) for exactly this reason, and the small sizes are the ones that decide whether a glyph works.
>
> Correct instrument, wrong scale — accurate and blind at once. The open question is not whether the layer is
> wrong but **what it should measure at**, and that is a real decision rather than a typo: 48 is where a
> silhouette comparison is most sensitive, and 13 is where the player is. Probably both.
>
> **SHIPPED — the answer was "both," and it landed the same day this note was written (`85fb985`,
> 2026-08-20): assert at 48, report at 13 on every run.** This line sat marked OPEN for four days after its
> own fix shipped; caught 2026-08-24 re-deriving state from the tree instead of trusting the prose.
> `check_item_reads.gd` now runs a second internal pass at `HOTBAR_PX = 13.0` whenever it is running at the
> default 48px, scaling its render target with it (`_canvas`) so a thin 13px glyph does not read as blank
> coverage the way it would in a canvas sized for 48px art — the failure mode the layer's own first
> `SF_ICON_PX=13` run actually hit. The 48px assertions are the ones that gate the harness; the 13px pass is
> printed, not asserted, matching the outline-ranking convention already established above rather than
> inventing a new threshold nobody has looked at a screen to set.
>
> **Reverified live 2026-08-24** (`GODOT=... bash tools/with_machine.sh --script res://tools/check_item_reads.gd`,
> a real GL context — this layer needs one and SKIPs cleanly under `--headless`): 11/11 PASS. At 48px the
> six closest colours are unchanged from the ranking already printed above (`rich_ore`/`stone_pickaxe` dE
> 2.2 still closest). **At 13px, the hotbar's own size, three pairs surface that never appear in the 48px
> ranking**: `gravel`/`iron_pickaxe` (dE 1.5, IoU 0.13), `ore`/`stone_pickaxe` (dE 1.7, IoU 0.47),
> `rich_ore`/`stone_pickaxe` (dE 1.7, IoU 0.41). None cross the clash floor (dE 10 + IoU 0.90), so nothing
> asserts red — but they are exactly the class of pair the four-day-stale "OPEN" was warning could sit
> unseen, and are now on record rather than invisible. Not spent on further design here: reporting-only
> findings, same as the outline ranking's own precedent, left for whoever next touches item colour/shape to
> read before assuming a clean sheet.

**T3.5 · The Bazaar as a physical object — and as a character.** The ruin has **no art at all**:
`Bazaars.draw()` iterates only *completed* frames, so the first Bazaar every player sees is four wood
cells wearing the dirt palette with grass on it. The awning is 1.04:1 against the sky (optically invisible
as shape); the keeper is *"a lavender bowling pin."* **The vibe audit raises the ceiling on this one:**
make the Bazaar a recurring physical **character** — an unmistakable attendant or apparatus whose opinions
and silhouette persist — and stage the (good) menu hierarchy on a visible counter with the world readable
behind it. *(Personality 4.4, Menu Craft 6.9.)*

**RESOLVED 2026-08-24 — the character direction, and one stale-prose correction along the way.** Director:
*"make the Bazaar a stubborn buried exchange, not a chatty NPC — personality through physical behavior,"*
and explicitly non-humanoid. Implemented in `scenes/bazaars.gd`: `_draw_keeper` (a robed humanoid figure —
the "lavender bowling pin" this passage quotes) is replaced by `_draw_apparatus` — a salvaged two-plank
counter (mismatched tones, patched rather than built new), a mechanical roll-shutter, a balance scale, a
slate ledger with scratched tallies standing in for "what it wants/what it gives" without world-painted
text, and one centred lamp as the sole "is anyone home" cue (the place goes dark; nothing walks away).
Comments referencing the old shopkeeper corrected in `scenes/main.gd` and `scenes/hud.gd`.

**Stale-prose correction:** "the ruin has no art at all" was already false when this passage was written —
`6b24f2f` (`feat(bazaar): the stall you have not finished yet is a thing you can see`) gave ruins their own
dressing at `RUIN_WEAR`, predating this note. Left uncorrected until now because nobody had reason to
re-read this paragraph closely.

**Not addressed this pass, still open:** the awning's 1.04:1 sky contrast. Bounded to the character
direction (the keeper replacement); the awning-visibility finding is a separate, still-live T3.5 sub-item.

**T3.6 · Water reads as a blue rectangular slab**, legible as *water* but not *behaving* like it — no
fluid edge behaviour. *(Material Honesty 5.6, Placeholder #2.)*

**Partially stale, 2026-08-24:** `9eaa0e5` (`feat(water): a body of water, not a blue rectangle`, 2026-08-16)
gave `WaterView._draw_water()` smoothed top-edge interpolation, ripple animation, depth-based tint, dual
caustic bands, a meniscus band and a bright surface line — dated one day before the `VIBE_AUDIT_RESPONSE.md`
run (2026-08-17) that produced this score. `git merge-base --is-ancestor 9eaa0e5 <that audit's cited HEAD>`
could not confirm ordering directly (the cited hash no longer resolves, consistent with the 2026-08-19
history rewrite), so this rests on date order under normal linear-history assumption, not a proven ancestry
check. Direct re-inspection of a current capture (`docs/media/moments/_moment_pack.png`) shows the
mechanisms present — an irregular top edge, faint surface sparkle — but visually subtle at normal play zoom;
the pool still reads close to a flat blue block at a glance. So: the literal "no fluid edge behaviour" claim
is false (the behaviour exists and is coded), but the holistic "reads as a slab" impression the audit scored
may still hold at normal zoom, matching the "technically present but too faint" pattern already seen on the
Winch cable (T1.9/T5.11 experiment). Left open as a narrower, real gap: increase the effects' visual
prominence at normal zoom, not "add fluid edge behaviour" from scratch.

**T3.7 · Sprite animation weight.** The 15 sprites hold at 4× and stay identifiable at 1×, with a
disciplined 19-colour palette — but action frames reuse a rigid torso and mostly move limbs. Redraw
anticipation / contact / recovery around changing **torso angle and centre of mass**; keep palette and
silhouette. *(Sprite Craft 6.2 — the highest art score; this is polish on a strength.)*

**T3.8 · Haul has no body.** Carried mass is expressed as counts and slots, never through pose, inertia or
drop impact. *(Haul 3.4 — the lowest verb.)*

**Partially resolved, 2026-08-24:** `38d5239` (`feat(T3.8): a dropped item now lands somewhere, instead of
puffing where it left`, 2026-08-20) shipped the "drop impact" third of this item — `_land_drops()` in
`scenes/main.gd` borrows the body-landing impact vocabulary (dust count, capped sound, thump pitch) and
scales it by fall distance, so a toss into a shaft now lands with weight instead of a silent puff at the toss
cell. Verified headless in that commit's own message (11 flights merged into 2 landing cells).

**The "pose" third also shipped the same day and this entry was never updated to say so — corrected
2026-08-25, found by re-reading the code rather than trusting this paragraph.** `fbbee1c7`
(`feat(T3.8): carried mass gets a pose — a load-scaled pack on the back`, 2026-08-24 18:23) added
`_carry_load()` plus a load-scaled sack drawn on the player's back in `scenes/player.gd:745-761`, on the
same cool-rim/canvas-tan grammar the body silhouette already uses. The commit's own message says as much
("Inertia... stays open... pose is done") but the line below was left saying "still open" for both. **Only
inertia remains open**, and it correctly gets the "needs human tuning, not an agent" treatment T3.10
already has rather than being agent-tuned blind. **One real gap found in the process of correcting this:**
the pose was verified by eye in the shipping commit ("empty shows nothing, 2 items ticks visibly, 18 reads
full"), not by a harness assertion — there is no registered layer covering `_carry_load()` or the pack's
on-screen presence, so a future regression here would go undetected. Not fixed in this pass (a new harness
layer for a shipped feature wants its own scoping, not a drive-by add); flagged here so it is not lost.

**T3.9 · Build has no assembly.** Machines appear as small finished boxes. A short material-consuming
assembly sequence would expose each machine's input/output orientation. *(Build 4.4.)*

**T3.10 · Swing release momentum** — human-tune so letting go becomes a deliberate mastery verb rather
than merely ending the rope state. *(Swing 7.5 — the strongest verb; this is sharpening the best thing in
the game, and per T0.1 it needs human tuning, not an agent.)*

**T3.11 · Surface trees and ruin blocks read as enlarged construction tiles** beside the more polished
skyline cog. *(Placeholder #4.)*

---

**T3.12 · Terrain material grammar (P3 parent).** Broad mass before local texture; dirt and stone receive
**distinct** variation languages; bright accents are reserved to carry meaning — ore, fresh fracture,
wetness, light — rather than decoration; surface is the top of the same earth beneath it. Tickets `TR-01`–
`TR-10` and `SF-01`–`SF-03` in `docs/VISUAL_RECOMMENDATIONS_SURFACE.md`. **Start with ONE controlled
dirt→stone cross-section; do not distribute a new texture rule across the world before it works.**
Completion: normal-scale + 1x + 4x A/B, an independent material-identification review, no rock/void
regression, and a visible rule adopted across the chosen family. **Rejected treatments stay documented
rather than silently replaced** — the bedding rejection is the precedent and it is worth more written down
than deleted. ~~**BLOCKED until P2 clears**: if the required route is still chance-level readable, terrain
art is blocked, not merely lower quality.~~

> **UNBLOCKED 2026-08-18 BY ITS OWN CRITERION, and the criterion is quoted rather than paraphrased because
> I am the person who benefits from reading it loosely.** The block says *"if the required route is still
> CHANCE-LEVEL readable"*. Chance is 50%. Measured after `rock_tooth` (`check_rock_reads`, registered,
> pooled over three viewpoints, four runs, stable): VALUE 70%, GRAIN 87%, CHROMA 94%, against 51/61 with
> the pass switched off. The layer clears its own 75% floor on GRAIN and is gated in the sweep, so this
> cannot silently regress while terrain work proceeds on top of it.
>
> **What is NOT claimed by that.** P2 is not "closed" — 6a's remaining question is whether 87% separation
> is a difference an EYE can use, which no statistic can answer and which needs a blind vision tester.
> Rock grain 3.01 against air 1.65 at a median luma of 11 is a real separation on a difference that may be
> invisible. That question stays open and is recorded above. What HAS changed is the specific condition
> this block was written to test, and a block whose stated condition is false is not a block any more —
> it is a habit. The director ruling sequences C1 *"T3.1 interior legibility, then terrain grammar"*, which
> is the authorisation to proceed on the same finding.

> **P3's FIRST FINDING IS THAT THE MATERIAL-SPECIFIC ART IS IN A LAYER THE PLAYER NEVER SEES UNDERGROUND
> — measured 2026-08-18, `c1`, `tools/_scratch_layer_owner.gd`.** TR-02 reads *"stop using equal-frequency
> noise for dirt and stone"* and the obvious place to fix it is `scenes/terrain_painter.gd`, which is where
> all the material-specific art lives: `def.grain` gates a speckle triple and `_draw_fissure` draws a
> bedding line, both keyed off `MaterialDef`. **That file contributes nothing to an underground frame.**
>
> Toggling each layer's visibility over 435 on-screen underground solid cells, five interleaved pairs per
> condition, twice:
>
> **RE-MEASURED 2026-08-18 ON A SOUND INSTRUMENT — the conclusion holds and the original statistic could
> not have established it.** The first version averaged a luma delta (COARSE hidden 1.08/1.20 against a
> same-state control of 1.56/1.58) and **an averaged delta cannot separate "absent" from "present but
> crushed"**: underground rock renders at ~10/255, so a real contribution scaled by the darkness veil lands
> under the floor and reads as nothing. It also had **no positive control**, which means a run where the
> hide silently failed would have produced the same answer and looked like a result.
>
> Rebuilt with three corrections — count pixels that differ AT ALL rather than averaging magnitudes;
> `Engine.time_scale = 0` so the ~40%-of-frame animation floor disappears while frames still tick and the
> progressive bake drains; drain the owed bake before comparing — and sampled on a **5×5 lattice per cell**
> rather than cell centres, because the coarse layer's marks (caps, ramps, edge AO) live at cell
> BOUNDARIES and a centre-sampled zero is exactly where an edge treatment would not be:
>
> | camera | sampled px | floor (two untouched captures) | COARSE hidden | FINE hidden |
> |---|---|---|---|---|
> | **SURFACE — positive control** | 10,282 | 0 | **593** | 9,655 |
> | **UNDERGROUND, 26 rows down** | 11,718 | 2 | **0** | 10,973 |
>
> **Zero of 11,718, against a floor of 2, with a positive control proving the hide takes effect and the
> rebake happens.** Not "below the noise floor" — literally zero changed pixels while the floor itself was
> two. The surface arm is what makes it a measurement rather than a hope: near-floor there would have meant
> the hide never took and the run was void.
>
> *(A whole-frame byte comparison was tried and is NOT usable: even frozen, two untouched captures differ
> somewhere in the frame, so its floor is nonzero. Something outside the sim clock still moves — a shader
> on real TIME, most likely.)* This generalises the 6a `_draw_edge_ao` knockout (7398 surface pixels, 0 underground)
> from one pass to the whole layer. `history/139-the-layer-that-paints-nothing-down-here.png` is the frame
> with the fine layer hidden: it is back-wall blue, so the coarse art is not merely covered down here.
>
> **Consequence, and it changes where the sprint goes.** TR-02 and TR-04 have to be done in
> `scenes/fine_terrain.gd`. And that file **cannot express a material grammar today**: its entire per-cell
> material input is `material_color_at(Vector2i) -> Color`, cached as `_mat_col: PackedColorArray`. No id,
> no `MaterialDef`, no `grain` flag. Every noise field it owns — `_grain`, `_stone`, `_crack`, `_patch`,
> `_noise` — is global and applied identically to every solid cell in the world.
>
> **So "both read as square variation before material" is not a tuning choice; it is structural.** Dirt and
> stone cannot be given different variation languages at any amplitude, because the layer that paints them
> does not know which one it is painting. This is the same shape as 6a's root cause — `rock_grit` masked on
> an alpha the void also had, so texturing both equally could not separate them — and it has the same
> consequence: **the first task of P3 is not a texture rule, it is threading material identity into the
> fine baker so a rule can exist.** Every `.tres` in `src/data/materials/` sets `grain = true` and differs
> only in `base_color` and `depth_darken`, which is the same fact read from the data side.

> **P3 STATE, 2026-08-18 (`c1`) — the renderer can now HOLD a material grammar, and whether the grammar
> READS is measurable in the dark and not yet measurable in the light.** Four things landed and one did
> not; the one that did not is the headline.
>
> **1. Material identity reaches the layer that paints underground.** `MaterialDef` gains
> `@export_enum("Clastic", "Bedded", "Massive") var grammar`; `FineTerrain` gains an optional
> `grammar_at` Callable (unset = Clastic = byte-identical to before, so the eight `rebake` call sites
> across five files are untouched — one passes its arguments positionally out of an array). Grain
> amplitude, horizontal stretch, aggregate clumping, seam strength, seam WIDTH and seam DIRECTION are now
> per-grammar. Stone and deepslate are Massive, shale is Bedded, the rest default Clastic.
>
> **2. A standing constraint is written into `scenes/fine_terrain.gd`, above the paint**, because three
> separate tickets have now discovered it independently and none left a note:
>
> > ANYTHING MULTIPLICATIVE IS INVISIBLE AT DEPTH. Anything that must survive the dark has to be ADDITIVE,
> > in absolute value levels.
>
> The veil is a MULTIPLY and the sampled rock mean underground is ~10/255, so a generous ±0.16 swing on
> `vmul` arrives as **1.6 levels against a measured within-window σ of 4.5**. `rock_grit` lost this to the
> veil and was answered by `rock_tooth` adding above it; `_draw_edge_ao` paints ZERO underground; the
> material grammars moved separability two points for a 5.3× amplitude ratio. The comment carries a second
> half that cost more to learn: **additive is necessary and NOT sufficient** — at luma 10 a 4× crop of
> underground rock is visually BLACK, so a difference an instrument measures there may be one no eye can
> use.
>
> **3. `check_material_grammar` exists, is NOT registered, and currently FAILS by design** — the same way
> `check_rock_reads` was held out through 6a. It carves a controlled dirt→stone cross-section, samples
> MIRRORED window pairs matched on distance-from-lamp and depth, and runs the whole measurement four
> times: a NULL rig (same material both sides), the treatment, a BASELINE arm with stone's grammar
> flattened to Clastic, and the treatment with the tooth pass off.
>
> **4. Where n is adequate, the grammar works.** Dark band, 17–21 window pairs, paired statistic:
>
> | GRAIN, dark band | null (earth\|earth) | baseline (one grammar) | treatment |
> |---|---|---|---|
> | separability | 51–62% | 59% | **72–88%** |
>
> **5. AND THE PART THAT IS NOT DONE: the lit band cannot be measured in this rig, so nothing about
> whether a PLAYER can tell them apart has been established.** Torches along the corridor lit only 11–15
> of 32 windows, and at that size **the NULL rig separates at 71–73%** — so every lit-band figure tonight
> is noise, including an 86% and an 83% that were one commit from being recorded as results. The proof is
> internal: in the last run the BASELINE arm, which has no grammar at all, "beat" the treatment in the lit
> band 73% to 60%. Two of the layer's three gates fire on exactly this and they are correct to.
>
> **6. AND THE DIAGNOSIS OF WHY THE LIT BAND WOULD NOT FILL, which is a finding about the GRAMMAR and not
> about the rig.** Torchlight reaches about two cells into a rock face, so the only rock whose material a
> player ever sees is a thin skin behind whatever they have just dug. A grain feature spans ~11 fine cells
> — SUBDIV is 4, so **2.75 coarse cells**. **The texture's features are larger than the band in which
> they can be seen.** Any square window big enough to contain a feature necessarily reaches into rock
> nobody can see, which is exactly how the lit band kept coming out at 11–15 of 32 however many torches
> went in.
>
> Two consequences, and they point in different directions:
> - **For the instrument:** the window is now 4 cells wide by 2 deep — wide enough to contain a feature,
>   shallow enough to stay in the lit skin. Match the sampling shape to the shape of the region the
>   question is about, not to the shape of the thing being measured.
> - **For the ART, and this is the open design question:** if a material's identity lives at a scale larger
>   than the skin you can see, then no amount of amplitude makes it legible in play — you would be reading
>   one third of one feature. That argues the grammars should carry a per-material FREQUENCY as well as an
>   amplitude, pitched so a material states itself inside two cells. Not implemented; it is a hypothesis
>   with a mechanism, which is exactly the kind of thing that was wrong twice tonight, so it gets measured
>   before it gets built.

> **7. RESOLVED — TR-02 IS MEASURABLY ANSWERED IN THE LIT BAND, and `check_material_grammar` is
> REGISTERED.** Three changes got the lit band to adequate power, none of them a tuning knob:
> - **Wide-shallow windows** (4 cells across, 2 deep) — matched to the shape of the visible skin rather
>   than to the shape of the feature, per finding 6.
> - **Three independent rig placements pooled** (depths 22 / 26 / 30). The two easy ways to get more
>   samples were both dishonest: extra standings would break the mirror axis, which is the material SEAM
>   rather than the body, so pairs would stop being matched on lamp distance; halving the stride would
>   overlap two-cell-tall windows and inflate n with samples that are not independent.
> - **Torches along the corridor**, so the lit band is the population rather than a remainder.
>
> | lit band, paired, 3 runs | GRAIN separability |
> |---|---|
> | NULL rig (earth\|earth) | 53 / 53 / 51% |
> | BASELINE (both materials, ONE grammar) | 61 / 63 / 61% |
> | **TREATMENT (per-material grammar)** | **81 / 81 / 81%** *(86 before the seam-axis correction — see 8)* |
> | colour control (must stay high) | 93% |
>
> 84 mirrored pairs, 70 of them lit. **Proved red by knockout**: setting `stone.tres` `grammar = 0` drops
> structure to 63% and the layer FAILS, so the gate can register its subject.
>
> **A CUE IS DISQUALIFIED BY ITS OWN NULL, by rule rather than by my choosing.** ANISO separates the null
> rig at 80% against a 62% ceiling, so it cannot carry a verdict about material and is excluded
> automatically — printed as a DISQUALIFIED line with its number, so the cue cannot be dropped quietly
> after the results are in.
>
> **8. THE SEAM AXES WERE INVERTED, and the disqualification is why nothing caught it.** The constants
> carried the comment *"bedded runs flat, massive runs steep"* and the arithmetic did the opposite:
> `get_noise_2d(x * a, y * b)` with a LARGE multiplier makes features NARROW on that axis, so Bedded's
> `[3.00, 0.35]` gave features 3.7 cells wide by 31.7 tall — **vertical laminae, in the material named for
> flat ones** — and Massive had the mirror error. The one cue that could have registered a direction error
> is ANISO, and ANISO was excluded on independent grounds, so a comment asserting the opposite of its own
> code survived every number the layer prints. Found by computing `1 / (freq × multiplier)` per grammar and
> reading the answer against the sentence.
>
> Corrected. **The treatment's own anisotropy moves 50% → 83%**, so the direction now reaches the frame —
> but ANISO is STILL disqualified at 80% on the null, and that limitation is real rather than a threshold
> quibble: **the rig controls material and not GEOMETRY.** The fine carved shape differs left of the seam
> from right, and anisotropy is sensitive to carved shape. No amount of mirroring fixes that, because the
> mirror is about the lamp rather than about the rock.
>
> **The trade, stated rather than reverted: correcting the direction cost 5 points of the GRAIN verdict,
> 86 → 81 (3 runs, stable, floor 75).** A material whose seams run the wrong way scored better while being
> wrong. TR-04 asks for stone as plane and fracture, so the direction is the point; the photograph is the
> only instrument that can confirm it, and at 4× the stone now carries vertically elongated dark seams
> where it previously had square chips.
>
> **WHAT THIS DOES NOT CLAIM.** TR-02's completion is *"an independent reviewer names each material without
> UI"*, and 86% separability is not that — it is the necessary condition, measured. The same boundary as
> 6a, and the same sentence at the head of T3.1: a separation statistic is not a perception. What HAS
> changed is that the renderer can now hold a material grammar, the grammar demonstrably reaches rock a
> player can see, and a gated layer stops it regressing silently.

> *(Superseded by 7: this block previously said P3 needed a lit chamber before anything could be said. It
> did — the fix turned out to be the window's SHAPE and pooled placements rather than a new rig, and the
> statement it was waiting on is now above.)*

> **9. HOW MUCH OF THE FRAME ANY OF THIS CAN REACH — measured, because P3 kept implying it and never
> asked.** A shaft sunk in the real world, the body standing in it with only its own lamp, no torches and
> no rig. Share of on-screen rock at or above luma 22, the threshold at which `check_material_grammar`
> considers a material visible:
>
> | depth | rock samples | median luma | p90 | at or above 22 |
> |---|---|---|---|---|
> | 8 rows | 5,927 | 12.7 | 37.7 | **24.1%** |
> | 16 rows | 6,162 | 12.9 | 55.9 | **22.8%** |
> | 26 rows | 5,225 | 15.4 | 48.8 | **27.9%** |
> | 40 rows | 4,258 | 20.0 | 59.3 | **40.8%** |
>
> **So a material grammar reaches roughly a quarter to two-fifths of the rock on screen, and the rest sits
> at a median of 13 where nothing reads at any amplitude.** That is a bound on what every remaining TR
> ticket can achieve, and it is neither the disaster the black 4× crop suggested nor the clean canvas the
> 81% verdict suggests on its own. Both numbers were true about different populations; this one says how
> big each population is.
>
> Two consequences worth separating:
> - **Texture work is not futile** — a quarter of the frame is a lot of pixels, and it is the quarter the
>   player is looking at, because it is the lit part.
> - **But light is what converts rock into readable rock**, which makes torch placement a legibility verb
>   rather than only a visibility one. That is a design observation from a measurement rather than a
>   proposal, and whether to act on it is a director call — TR-09 explicitly forbids the lazy version
>   (*"do not globally brighten underground"*).

> **10. A DEPTH TREND THAT WAS THE SHUTTER — retracted before it was published, and the rule that
> replaces it.** TR-05 asks whether the brightest marks on screen are the ones that matter. The instrument
> classifies every world pixel of a capture (HUD bands excluded) into exposed ore / buried ore / the body /
> open air / plain rock, and reports LIFT: how much likelier exposed ore is than plain rock to sit in the
> frame's top 1% of luma. First three runs gave **11.3× at depth 26, 1.25× at 12, 18.6× at 6**, and a
> depth-effect write-up was drafted off them.
>
> There is no depth effect. `world_renderer.gd:_draw_ore_glints` sets `PERIOD = 3.4` and
> `FLARE_LEN = 0.5`, so **only 14.7% of exposed ore cells are inside their flare window at any instant**.
> A one-frame instrument samples a random ~15% of its own subject. Five depths × three scene offsets,
> one frame each:
>
> | depth | x=0 | x=+45 | x=−45 |
> |---|---|---|---|
> | 8 | 6.08× | 44.68× | 0.74× |
> | 12 | 1.25× | 2.16× | 0.74× |
> | 16 | 85.50× | 44.86× | 43.28× |
> | 20 | 1.34× | 43.76× | 3.78× |
> | 26 | 12.52× | 99.42× | 2.58× |
>
> **Within-depth spread equals between-depth spread**, and d=26 x=0 read 11.28× once and 12.52× on a
> re-run of identical coordinates in a deterministic world — `_anim_time` at capture depends on real frame
> pacing, so the flare phase differs run to run. The x-offset knob exists only because the first three
> numbers confounded depth with scene composition; it is the control that killed the finding.
>
> **Two denominators were thrown out before the question had a population**, both the class this document
> keeps recording. `sim.lode` covers the background wall plane wholesale since the lode migration, so 18%
> of the frame counted as "ore pixel" while being unlit backdrop. And "solid + `has_nuggets`" is still
> wrong, because `world_renderer.gd:1114` states the design outright — *"Only EXPOSED ore glints … not
> buried in solid rock"* — so scoring buried ore as a miss measures the renderer against a rule it
> deliberately does not follow. The subject is whatever `_exposed_ore_cells()` returns: **the renderer's
> own predicate, so the instrument cannot disagree with the thing it audits about what counts.**
>
> **The standing rule: before computing any statistic on a cosmetic cue, find its period and sample at
> least one full one.** Keep the threshold per frame — "the brightest thing on screen" is a claim about
> one screen — and prefer the question the eye asks, which is not the pooled rate but whether a cell
> flashes at all while you stand there looking at it.

> **11. TR-05 — THE ORE GLINT WAS DRAWN UNDER THE VEIL, AND MOVING IT ABOVE IS WORTH 2.4x TO 10x. Two
> withdrawals on the way, both of them mine, both instructive.** TR-05 reads *"Reserve brightest mineral
> glints for identifiable ore/event semantics — bright marks in earth and cavity compete with UI white."*
>
> **The answer.** `_dark` is a `LightLayer` at **z 50 with `BLEND_MODE_MUL`**. `_draw_ore_glints` ran inside
> `WorldRenderer._draw` at **z 0 — under the multiply** — while every cue that reaches the eye is above it:
> the crystal-seam pools and the lamp on `_lights` at z 51 (additive), the body at z 60. Worse, `glint_dark`
> RAISES the flare's alpha as the surround darkens, `clampf(_skylight_alpha(…) / AMBIENT_DARK, 0, 1)`, and
> the veil multiplied the result back down by nearly the same factor — **the compensation and the
> attenuation were the same number.** The flares now draw from `_paint_lights`, additive and post-veil, on
> the same canvas as the pools they were losing to. `glint_dark` is kept, because above the veil it finally
> does what its comment always claimed.
>
> **Exposed-ore p99 luma, one scene per depth, x = +45:**
>
> | depth | glints off | flares at z 0 | flares at z 51 | under the veil | above it |
> |---|---|---|---|---|---|
> | 12 | 108.1 | 124.3 | 146.1 | +16.2 | **+38.0** |
> | 20 | 122.6 | 129.2 | 189.2 | +6.6 | **+66.6** |
> | 26 | 148.8 | 152.1 | 168.9 | +3.3 | **+20.1** |
>
> **The evidence is not the size of the gain, it is the shape of the loss.** The pre-veil glint's
> contribution decays with depth — **16.2, 6.6, 3.3 levels** — which is what a multiplicative veil predicts
> and nothing else here does. That is a depth trend the instrument was *built to be able to refuse* (see 10,
> where one just like it turned out to be the shutter): it sits on absolute levels rather than a quantile,
> and same-build repeats put the noise at **±0.35 levels, 0.2%**.
>
> **No blow-out, and not a global brighten.** `max` is 253.2 in every arm at every depth, `p99.9` moves by
> at most 4.7 levels, and the MEAN moves by less than 0.6 — the lift is confined to the cue. That check is
> not decoration: `_paint_lights` records a previous additive pass that summed past 1.0 and washed the
> centre of the frame to a white smear.
>
> **WITHDRAWAL 1 — "lone ore never reaches the bright band", six cells.** The first cut split exposed ore
> into clustered and lone and reported lone ore at 0.00× across all nine runs. `_cluster_seams` absorbs ~87%
> of exposed ore, so lone exposed ore averages **one cell per scene**, and three of those nine runs divided
> 0 by 0 and printed a confident zero. Nine runs of apparent agreement over a population that barely exists.
>
> **WITHDRAWAL 2 — "the glint contributes nothing", and then, briefly, "the veil is not why".** The metric
> was *share of the frame's top 1% of luma*. A knockout on it said suppressing the flares changed which ore
> cells are visible by **nothing** — 9 of 13, 12 of 20, 20 of 30, identical cell for cell. Both halves of
> that were artefacts:
> - **The quantile moves with the treatment.** Adding bright pixels raises the cut and pushes other pixels
>   of the same kind below it, so at depth 26 switching the glints ON made ore's bright count *fall* by 619.
>   A statistic that scores a working cue as a loss. Its run-to-run floor was **7.4%**, never measured until
>   two supposedly identical builds disagreed by it.
> - **The discovery statistic was saturated.** With glints off, ore's p99 is already 148 against a top-1%
>   cut near 89 — those cells clear the bar on the seam pool alone, so the glint had nothing left to flip.
>
> **On the strength of those two blind instruments agreeing, the z-order mechanism was retracted — and the
> retraction was the bigger error.** Two instruments that cannot register a thing will always agree about
> it; that is not corroboration. The correct move was to withdraw the MEASUREMENT and remeasure, which on
> levels reinstated the mechanism at 5.9× within the hour. Corrections feel verified in a way first findings
> do not, and this is the second time that has been recorded here.
>
> **The category, now at three instances: a threshold that is a function of its own treatment.** `c2`'s
> ceremony threshold sat *under* the noise it existed to clear; this one was computed *from the frame the
> treatment had already changed*; and the seam-axis correction (8) cost 5 points because a material with
> its seams running the wrong way scored better while being wrong. In all three the statistic improves as
> the subject degrades, and in all three the only way to catch it is to ask what the number is made of
> rather than which way it moved.

> **12. PLAYER-INTENT MARKERS WERE UNDER THE VEIL TOO, AND THEY KEPT EXACTLY 31% OF THEMSELVES.** The
> glint fix (11) said a cue's z relative to `_dark` decides whether it exists, so every affordance drawn in
> `WorldRenderer._draw` at z 0 became suspect. The ones whose own comments give away the stake: `_draw_ping`
> — *"the spot you marked, findable on foot"* — `_draw_dig_marks`, and `_draw_guide_targets` — *"pulsing
> do it HERE"*. All three are things the PLAYER put on the world, and all three were being divided by the
> darkness they exist to work in.
>
> **Measured at 24 m by differencing per-pixel maxima with the cue placed against the cue cleared**, which
> isolates the subject by construction and cannot be fooled by what else is in frame:
>
> | cue | asks for | before | after | footprint before → after |
> |---|---|---|---|---|
> | null control | 0 | +1.0 | +2.6 | **0 px → 0 px** |
> | map beacon | **205.4** | +63.3 | **+199.9** | 2,592 → 4,218 px |
> | dig bracket | ~104 (rough) | +32.1 | **+124.6** | 260 → 1,917 px |
>
> The beacon asks for luma 205.4 — `Color(0.45, 0.95, 1.0)` at full alpha, read out of the source rather
> than measured — and now delivers **199.9, within 3%**. Before the fix it kept **31%**; the dig bracket
> independently kept **31%** at a different colour and a different alpha, which is one multiplicative
> factor rather than two coincidences.
>
> **Fixed by `_marks`, a `LightLayer` at z 53 painting MIX.** Not ADD: a marker should arrive at the colour
> it was authored in, and `_paint_lights` records an additive pass that once summed past 1.0 and washed the
> centre of the frame. This is the same exemption `_player` already has at z 60 — the body is not subject
> to the dark either.
>
> **THE INSTRUMENT TOOK THREE TRIES AND EACH FAILURE IS A DIFFERENT ONE.**
> - **v1 took the max luma in a window and never checked the max was the cue.** All three cues returned an
>   identical "lit peak" of 161.5 — the miner's lamp, photographed three times, because the probe sat one
>   cell from the body. Two then returned an identical 54.8 in the dark: both were *dimmer than some
>   background feature*, so the max found that instead. **A statistic can be sound while the pixel it reads
>   is not the subject.**
> - **v2 differenced, and its null control failed in the lit arm at 144.1 levels** — a cue that was never
>   placed. The lamp's veil cut FOLLOWS the body, so "inside the light" and "beside the animated thing" are
>   the same place by construction and no window there can be clean. The lit arm was deleted rather than
>   repaired; the dark arm's null is 1.0, and the target it is compared against is read out of the source,
>   which is better than a measured control — **a shared bias cannot cancel against a number from the code.**
> - **v3 added a FOOTPRINT (pixels above the floor) and that is what caught the last one.** The guide ring
>   read +1.6 levels over **0 px** — identical to the null. It was never drawn: `main.gd:782` re-pushes
>   `set_guide_targets` every frame from `_process`, so the probe photographed an empty array. A peak alone
>   cannot tell "rendered and dim" from "never rendered"; the footprint can.
>
> **So the guide ring is UNMEASURED and its fix is by analogy only** — same layer, same mechanism, no
> number. Stated rather than folded into the table.

> **13. TR-07 — THE HOLE IS NOT BLACK, IT IS SMOOTH; and the obvious fix was measured, costed and
> REVERTED.** TR-07 reads *"holes can read as black cut-outs rather than removed earth"*. Its face half is
> already answered: 6b's header records that `_draw_edge_ao` puts zero pixels on screen underground
> (`c2`'s baseline: −16), while the rock/air step survives. So the complaint is about the HOLE, and the
> back wall — the plane the lode migration moved ore into — is where it lives.
>
> **Measured inside the lamp, three depths.** Split by distance from the body rather than by brightness,
> because splitting by the pixel's own luma sorts pixels by the thing being measured and then reports that
> the bright group is brighter:
>
> | | median luma | local texture |
> |---|---|---|
> | solid rock | 31–35 | **4.1–4.6** levels/px |
> | the hole (back wall) | 19–27 | **1.9–2.4** levels/px |
>
> **70% of the value and half the surface.** Similar value carrying no structure is exactly what a cut-out
> looks like — so the ticket's instinct is right and its word *black* points the wrong way. (Pooled over
> the whole frame the gap is only 4 levels, because rock's unlit median is ~15 and both sit in the band
> where a 4× crop is visually black. That pooled number answers nothing; finding 9 already said why.)
>
> **The cause is one mask, and its stated reason applied to something else.** `rock_tooth.gdshader` gates
> on `step(0.998, src.a)` — solids only — because an earlier version had air carrying MORE tooth than rock
> (2.06 vs 1.83). Right about the **void**; wrong about the **wall**, which is not void but the earth you
> did not dig. Knockout at 22 rows: removing the pass costs the rock **1.43 levels/px** and the hole
> **nothing** (2.02 → 1.94, inside noise). **Two thirds of the gap is that mask.**
>
> **A `wall_frac = 0.5` band was built, measured, and reverted.** It worked:
>
> | | before | after |
> |---|---|---|
> | wall texture | 2.02 | **2.30** (+14%, every depth, rock unchanged) |
> | `check_contact_edge` detectability | 95% (step 15.5) | **94% (step 14.9)** |
> | lit edge step | 23.27 | **21.57** |
> | polarity | 97% | 97% |
>
> **The gain is subliminal and the cost is on a guarded property.** Across the frame 55% of pixels move by
> ≥2 levels and only **0.04% by ≥10**; the eye check was inconclusive and is reported as inconclusive
> rather than resolved in the change's favour. Against that, TR-06 is PROVED with the guard *"existing
> rock/void gate must not regress"*, and this regresses it. **Trading a guarded property for one below the
> perceptual threshold is the wrong trade even when both are small.**
>
> **AND THE REASON IT CANNOT BE TUNED, which is the finding that outlives the revert.** `rock_tooth` is
> `blend_add` and POSITIVE ONLY — its own header says *"an additive pass cannot subtract"*. So any texture
> it gives the wall also raises the wall's MEAN, and raising the wall's mean is precisely what narrows the
> face step. **The wall does not need brightness. It needs STRUCTURE — a zero-mean grain that darkens as
> much as it lightens** — and no additive pass can make one at any amplitude. A post-veil **MIX** layer
> can, and one now exists at z 53 (`_marks`, finding 12). That is where a back-wall grain belongs. Filed
> rather than built: it is a new texture source and a new mask, and it should not be rushed onto the end
> of the session that found it.
>
> The negative result is written where the code would have been, in `rock_tooth.gdshader`, so the next
> reader does not re-derive it.

> **14. TR-08 — THE SMOOTHING IS LOCATED, AND ONE OF THE TWO SOURCES IS A LENS AFFECTATION COSTING A
> QUARTER OF THE RED CHANNEL'S SHARPNESS AT THE FRAME EDGE. Flagged for a look decision, NOT changed.**
> TR-08 asks to *"locate renderer layer causing smoothing; test removal or semantic assignment"*, guarding
> *"preserve intentional lamps, water, fog, and depth effects"*.
>
> **By inspection there are exactly two sources.** `project.godot` sets `default_texture_filter=0`
> (NEAREST) and every renderer canvas re-states NEAREST, with one exception:
> - **`_dark` at `TEXTURE_FILTER_LINEAR`** — the darkness veil, one texel per CELL stretched across the
>   world. This is the lighting model and the guard names it. **Not a defect.**
> - **`post_fx.gdshader`**, which samples the composited frame through `hint_screen_texture,
>   filter_linear_mipmap` and splits the channels for chromatic aberration:
>   `shift = c * aberration` with `c = SCREEN_UV - 0.5`, then `textureLod(screen_tex, uv ± shift, defocus)`
>   on R and B while G is sampled at `uv` exactly.
>
> **The offset is SUB-PIXEL and grows radially** — zero at centre, ~0.9 px at a corner at 1920 wide — and a
> sub-pixel offset through a LINEAR sampler is an interpolation. So R and B are blended with their
> neighbours by an amount that increases with distance from the centre, in a frame whose entire grammar is
> hard pixels. **Chromatic aberration is not a lamp, water, fog or a depth effect**; it is the one thing
> here the guard does not protect.
>
> **Measured. Per-channel sharpness — mean |difference| to the pixel on the right — in five radial bands,
> aberration at its shipped 0.0007 against 0:**
>
> | band | R/G off | R/G **on** | B/G off | B/G **on** |
> |---|---|---|---|---|
> | centre | 1.067 | 0.995 | 0.966 | 0.897 |
> | 2 | 0.993 | 0.885 | 1.079 | 0.959 |
> | 3 | 0.985 | 0.874 | 1.084 | 0.955 |
> | 4 | 0.991 | **0.742** | 1.130 | 0.847 |
> | edge | 0.965 | **0.758** | 1.123 | 0.892 |
>
> **Red loses about a quarter of its per-pixel sharpness at the frame edge and nothing at the centre.**
> The prediction was registered before the run precisely because a radial trend is the kind of thing that
> can be read into noise, and the control it named is the one that carries it: **G is untouched between
> the two arms** — 3.195/3.174, 2.421/2.413, 1.888/1.893, 2.742/2.799, 2.093/2.091. Had G moved, the
> mechanism would have been something else.
>
> **NOT CHANGED, deliberately, and this is the one thing on the P3 list that should not be a `c1` call.**
> The blur is a side effect; the intent is a colour fringe, and the two are separable — quantising `shift`
> to whole screen pixels would keep the fringe and remove the interpolation entirely. But at a maximum
> shift of ~0.9 px that quantisation has only two states, so it trades a gradient for a visible ring, and
> which of those is worse is a question about the look rather than about the renderer. The post-FX pass is
> the *modern-feel* direction the user asked for; how much pixel crispness that look may spend at the
> periphery is a vision-level fork, and the measurement is the deliverable here rather than the fix.
>
> Three options, costed: **leave it** (24% of R at the edge, a fringe nobody consciously sees); **lower
> `aberration`** (proportionally less of both); **quantise the shift** (fringe kept, blur gone, banding
> risk unmeasured).

> **15. TR-09 — THE DENSITY GRADIENT THE TICKET ASSUMES DOES NOT EXIST. Closed on a negative result.**
> TR-09 reads *"audit texture density by depth band — upper earth is busy while lower mass becomes dark
> noisy ambiguity; produce density/value histogram by material/band, then one band treatment"*, guarding
> *"do not globally brighten underground"*.
>
> **The histogram, inside the lamp, five depths.** Density is local texture — mean |luma difference| to the
> neighbouring pixel of the SAME material, so a face between two materials is not counted as texture:
>
> | depth | material | px | median luma | p90 | density |
> |---|---|---|---|---|---|
> | 6 | shale | 44,419 | 26.2 | 45.9 | 3.81 |
> | 6 | stone | 47,240 | 18.9 | 29.2 | 3.12 |
> | 6 | ore | 19,656 | 19.7 | 37.8 | 3.29 |
> | 6 | coal | 5,845 | 9.2 | 14.6 | 2.49 |
> | 14 | stone | 78,260 | 30.6 | 68.1 | 4.01 |
> | 14 | ore | 30,803 | 61.9 | 115.3 | 5.78 |
> | 22 | stone | 45,800 | 30.9 | 64.9 | 4.00 |
> | 22 | coal | 26,315 | 32.0 | 61.1 | 4.17 |
> | 30 | stone | 113,959 | 34.8 | 94.0 | 4.56 |
> | 40 | stone | 60,110 | 25.5 | 65.6 | 4.01 |
> | 40 | ore | 62,647 | 60.0 | 97.7 | 5.50 |
>
> **Read raw, this says density RISES with depth — 3.12 to 4.56 for stone — which is the opposite of the
> ticket and would have been the write-up.** It is an artefact. Density is measured in absolute levels and
> scales with contrast, which scales with light, and the lit band is brighter deeper (stone's median goes
> 18.9 → 34.8) because at 6 rows "inside the lamp" is really daylight spread thin while at 30 it is a lamp
> at close range. **The two arms are not the same lighting regime, so the raw comparison is between light
> levels wearing a depth label.**
>
> **Normalised by its own median, stone's texture is FLAT down the whole column: 0.165, 0.131, 0.129,
> 0.131, 0.157.** There is no density gradient. TR-09's premise — busy above, ambiguous below — is not a
> property of the texture.
>
> **So there is no band to treat, and the ticket closes without one.** The only material that stands out is
> coal at 6 rows (median 9.2 against stone's 18.9, density 2.49), and coal is *designed* dark —
> `world_renderer.gd` states it twice: *"coal has nuggets but does NOT glitter (it's fuel, not a gem)"*,
> *"coal reads as dark clusters"*. Treating it would be undoing an intent, not fixing a defect.
>
> What the ticket was probably seeing is finding 9 restated: **59–76% of on-screen rock sits below the
> threshold at which anything reads**, everywhere, at every depth. That is a LIGHT finding and TR-09's own
> guard forbids the lazy version of it (*"do not globally brighten underground"*). The texture is fine; it
> is unlit.
>
> **A note on the instrument, because it failed silently first.** Every material initially reported **0 px
> with its key present** — impossible unless the append never landed. `PackedFloat32Array` is a VALUE type,
> so `(dict[k] as PackedFloat32Array).append(v)` appends to a temporary copy and discards it; the
> neighbouring `grad` accumulator happened to be written back and the luma one was not. It was caught by
> the minimum-sample floor, which refused to report rather than indexing an empty array — the same
> footprint discipline that caught the unrendered guide ring in finding 12. **A floor that refuses is worth
> more than a number that is produced.**

> **16. THE GRAMMARS SHIPPED A REGRESSION AND `check_texture` COULD NOT SEE IT, BECAUSE ITS FIXTURE BAKED
> A WORLD THAT HAS NEVER RUN.** Found while chasing TR-01/TR-03, which are claims about what the terrain
> PAINTS — so the lit frame was the wrong place, twice (a lamp gradient inflated a two-scale statistic;
> filtering to pairs at equal radius cost 97% of the sample and kept only pairs straddling the miner).
> `check_texture` already bakes the real `FineTerrain` over a FLAT GREY palette with no lighting at all.
>
> **Its `rebake` call never wires `grammar_at`.** That input does not travel in the `rebake` signature — its
> own docstring says so — so omitting it does not disable the grammars, it bakes **every material as
> `GRAM_CLASTIC`**. Same bake, same seed, same population, one variable:
>
> | | flattened (what the layer measured) | as shipped |
> |---|---|---|
> | stone across a face | lag-1 0.94, roughness **5.93%** | lag-1 **0.63**, roughness **10.40%** |
> | deepslate across | lag-1 0.94, roughness 5.91% | lag-1 0.64, roughness **10.77%** |
>
> **The ceiling is 6.5% and that layer's own comment calibrates the scale: 12.7% was "unmistakably a grid
> of tiles at any magnification", 5.9% is the retune that made it read as rock.** The grammars from
> findings 7–8 put stone most of the way back to the tile grid, and the layer passed at 5.93% while the
> game printed 10.40%. Wiring the fixture makes it FAIL at 9.2% / 7.4%.
>
> **KNOCKED OUT ONE TERM AT A TIME, and the first guess was wrong.** `CRACK_FREQ` 0.09 × `GRAM_SEAM_X` 3.40
> puts a Massive seam feature every 3.3 fine cells — on the layer's own three-samples-per-feature boundary,
> so it looked like the answer. Reducing it to 2.60 moved roughness **9.2% → 9.2%**. Reverted rather than
> kept: a change that sits alongside a fix is not part of it.
>
> | Massive term set to Clastic's | roughness across |
> |---|---|
> | `GRAM_SEAM` 2.20 → 0.15 | **5.5% PASS** |
> | `GRAM_SEAM_W` 1.70 → 1.00 | 7.7% FAIL |
> | `GRAM_XSTR` 1.60 → 1.00 | 9.1% FAIL |
>
> Amplitude is the whole of it, and the arithmetic says why: `CRACK_DARKEN` is 0.15, so at 2.20 a seam
> removed **0.33 of a 0.42 base — 79% of the value.** A black line, not the *restrained chips* TR-04 asks
> for. Sweep: 1.40 → 7.6%, 1.20 → 6.8%, 1.00 → 6.9%, **0.70 → 6.3% PASS**; trading amplitude for width does
> not help (1.20 with W 1.25 → 6.8%).
>
> **AND CUTTING IT MADE THE OTHER GUARD BETTER, which neither of us predicted.** The obvious worry was that
> stone's seams were carrying dirt-vs-stone separability and a 3× cut would drop it under its 75% floor.
> The opposite:
>
> | | before | after |
> |---|---|---|
> | `check_texture` roughness | 9.2% / 7.4% | **6.4% / 5.7%** |
> | `check_material_grammar` | 81% | **87%** |
>
> **The artifact was costing separability, not carrying it** — a near-black seam grid was noise the
> classifier had to see through. Which also re-reads finding 8: *"correcting the direction cost 5 points,
> 86 → 81"* was probably never about the direction. 87 with the axes right and the amplitude sane is the
> best that verdict has been. (One run; direction solid, magnitude provisional — that layer wants three.)
>
> **THE GENERALISATION, `c2`'s phrasing, now written into `fine_terrain.gd`:**
>
> > **A correct guard that silently substitutes a default is what makes an omitted input invisible.** The
> > guard did its job perfectly and that is precisely why nobody found out for 89 layers.
>
> `_grammar_of` guards `grammar_at` with `.is_valid()`, which is the *right* guard — this document's own
> catalogue insists on it because `Callable() != null` is true. So the defect sat upstream of a correct
> guard. `rebake` now calls `_warn_if_flat()`: sets a `baked_flat` flag a fixture can assert on and warns
> once per instance. Not a failure — **a silent default is a fixture-omission amplifier; an audible one is
> a detector.** Proven both ways: flattened bake warns, wired bake is silent.
>
> **All five `rebake` call sites audited** (by `c2`, after this landed): `world_renderer` sets it on both
> the full and region paths, so **shipped was always correct and the regression was entirely in what the
> instruments saw**. `check_dig_hitch` is clean *by luck* — one `ref` built once and reused through
> `_cost` — so a refactor there would silently move a timing layer onto the flat world.
> `check_progressive_bake` was flattened too; its answer was still right (it compares two bakes of the same
> world and both sides were flattened identically, so order-independence held for the right reason) but its
> population was narrow exactly where its header aims — the grammar terms are the newest paint terms in
> `_paint_fine` and were the only ones it never exercised. Now wired.

**T3.14 · A posed-field layer for the SIM half (peer request, filed by `c1` 2026-08-18).** `c2`'s
`check_posed_fields` (layer 87) catches a fixture posing a node field that `_process` recomputes, and asked
whether the same defect exists in the sim. **It does, and their extractor cannot see it — measured:**
fixtures pose 13 distinct sim fields across ~129 sites (`inventory[]` 37, `deposits[]` 21,
`total_produced[]` 15, `torch[]` 12, `lode[]` 12, `research[]` 11, `lode_max[]` 6, `solid[]` 5,
`world_seed` 4, `fill[]` 2, `_seep_tick` 1, `_bazaars_dirty` 1). But `FactorySim.tick()` assigns exactly
ONE field in its own body (`factory_sim.gd:1659`, `_seep_tick += 1`); the six it actually rewrites go
through `PowerFlow.compute(self)`, `WaterFlow.step(self)` and `Flora.grow(self)` — static helpers in other
files writing through a parameter — and **every one of those six is a subscript write**, `sim.water[c] = …`,
which `_assigned_pair` rejects on `lhs.contains("[")`. A direct port would scan the sim, report a clean
population, and be clean because the instrument cannot register its subject. So this is a different layer,
not a port: the population must be the tick's TRANSITIVE closure, and the extractor must read container
mutations.

> **One rule to carry over, because it is load-bearing and reads like an afterthought.** `=` destroys a
> pose; `+=` PRESERVES it as an offset. `check_save_durability` poses `sim._seep_tick`, then poses
> `phase_b._seep_tick = phase_a._seep_tick + SEEP_INTERVAL/2`, then advances both four seep cycles and
> asserts they diverge — a textbook offence under a naive port, and in fact one of the better fixtures in
> the tree (the pose IS the subject, with a non-vacuity check that the warm sim is genuinely out of phase
> and a control proving phase decides the future at all). `check_posed_fields` already excludes `+=` via a
> one-line operator check, which is what keeps that fixture out of its report.
>
> **NOT yet proven:** that any specific pose is destroyed. Most posed fields look written only on player
> actions rather than under the tick, but that is a grep over write-sites, not reachability — and `solid[]`
> is posed 5 times while `Flora.grow` writes `sim.solid[`. Computing the closure and checking IS the layer.

**T3.13 · Grapple visual language (P4 parent, adjacent to T3.10).** Visual intensity should follow player
COMMITMENT: quiet aim, clear attachment, expressive tension and release. Tickets `GR-01`–`GR-07`. **The
goal is not to make grapple less useful.** Completion: named motion captures for aim / attach / tension /
release / miss; direct input reliability unchanged or better; the player silhouette remains the first read;
and no permanent debug-looking guide survives where it is not aiding a decision. Pairs with **T3.10**
(swing-release momentum), which is a feel tune rather than a look one — do them together or the look will
be tuned against a feel that is about to change.

> **17. `check_texture` GUARDS "THE PAINT" OVER A POPULATION CONTAINING 0.0% EARTH AND 0.0% SHALE — AND
> TR-01's DIRT IS NOT A TEXTURE PROBLEM AT ALL.** Directive 0042 asked for one visible dirt→stone
> cross-section with a pre-registered hypothesis and a SHIP / REJECT / ONE MORE CONTROL verdict. All three
> answers below are on the record, and the pre-registration was **wrong**.
>
> **The population, measured (seed 1337, deep-interior, `tools/_scratch_pop_mix.gd`).** `check_texture`
> pools fine rows 60–110 into one lag-1/roughness pair and calls the result "the paint". That band is:
>
>     deepslate 34.0% | stone 17.4% | rich_ore 14.1% | ore 12.9% | coal 9.4% | iron 6.3% | sealrock 5.9%
>     earth 0.0%      | shale 0.0%
>
> Earth occupies coarse rows 12..33 and shale 20..31 — **both lie entirely above row 60**. So the guard is
> structurally incapable of registering either, and the two plain-rock materials that exceed its own
> ceiling are the two it cannot see. Measured against that 6.5% ceiling: earth **18.62%** across a face and
> **18.05%** down; shale 7.42% / 8.19%; stone 4.90% / 3.51%. The layer's own calibration note calls 17.9%
> "unmistakably a grid of tiles at any magnification". **The dirt band has been a point above our named
> failure case, under a green gauge, for the whole project.** This is the second population defect found in
> this one layer in two days (finding 16 was the same layer baking every material as GRAM_CLASTIC), which
> is itself the finding: one fixture, two independent ways of not containing its subject.
>
> **REJECT — the treatment the data seemed to support does not work.** Pre-registered: "reducing earth's
> Clastic accent terms moves earth below 12% without moving stone by more than 0.5 points". Decomposed
> properly, one term at a time:
>
>     baseline                                   18.62% / 18.05%
>     GRAM_GRAIN 1.60→0.80, GRAM_CLUMP 1.45→0.75,
>       GRAM_PATCH 1.35→1.85                     18.37% / 17.64%
>     ...with GRAM_PATCH back at 1.35            17.63% / 16.93%
>
> Halving **both** of earth's high-frequency terms buys **0.99 points of 18.6** — about 95% of earth's
> roughness is something neither term controls. Reverted; the shipped values stand. Note the first arm
> changed three constants at once and was therefore unattributable — I repeated the decomposition error I
> had been corrected on the same night, and only the second arm has any information in it.
>
> **SHIP — TR-10, `history/148-the-clayband-*.png`,** and the standard that goes with it: frame the cut
> with sky in it. Four captures came back showing nothing because the framing kept failing in ways the
> image did not advertise — the shaft never reached daylight, then `surface_row` was read AFTER
> `descend_to` had dug the column it measures (it reported row 47 against a real surface at 20, and the
> carve loop `range(47,47)` silently did nothing), then the body fell down the open shaft three times and
> photographed the bottom. **The HUD said `27 m` on every one of those frames and 27 is exactly shaft-floor
> minus surface.** The instrument was reporting the defect in plain language the whole time.
>
> **ONE MORE CONTROL — and TR-01's cause is probably not paint.** At 4× the "cow spots" are AXIS-ALIGNED
> RECTANGLES about one fine cell across, grey-blue on brown. Noise fields make blobs; rectangles come from
> cells. And the composition table says rows 20–31 hold earth, shale, ore and coal *at once*. So the
> mottled read is most likely **material interleaving at cell scale**, not earth's own texture — which
> independently explains why halving earth's amplitudes did nothing, and why a per-material roughness probe
> reports 18.6% for "earth" when the warped index lets a cell read its neighbour's grammar. The control
> that settles it is a roughness measured over runs whose three cells share one coarse material, against
> today's number. **Until that runs, TR-01 stays OPEN and no dirt treatment should be tuned**, because
> every constant in `fine_terrain` would be being tuned against a worldgen mix.

> **18. THE POINTER STEERS THE LAMP, SO EVERY WINDOWED MEASUREMENT WAS AUDITED. MOST SURVIVE; TR-09 DOES
> NOT.** `main.gd:1349` refreshes `_aim` from the real OS mouse unconditionally in `_process`, and
> `world_renderer.gd:545-554` eases the HEAD-LAMP toward `_aim` with `limit_length(LAMP_LEAD)`,
> `CELL * 1.9` = 60.8 world px ≈ 1.9 cells. It is not jitter: past `CELL*0.9` the lead sits at FULL
> magnitude pointing wherever the hand is. Translating the reveal disc that far changes `lift` by ≈0.37
> near the core — tens of luma levels on lit rock. So every claim measured from `get_root().get_texture()`
> had to be re-examined, and the machine's owner was using the machine throughout.
>
> **What survives, and why — the pattern is worth more than the verdicts.** Every measurement that held up
> did so because it carried a control that travelled INSIDE the same measurement, and in every case that
> control had been collected for an unrelated reason and was never read as a lighting control:
>
> - **ore-glint z-order** (108.1/124.3/146.1 etc.) — the same print emits `seam ore LEVELS mean`, near-pure
>   background light on the identical population: **≤1.8% spread across arms against a 46% p99 effect**,
>   and `plain rock LEVELS mean` holds to **0.23% across four boots**. A 1.9-cell lamp swing cannot leave
>   those flat. The published `max 253.2` independently rules out the aim box having landed on ore.
> - **player-intent markers** (beacon 63.3 → 199.9) — PROTECTED BY GEOMETRY. The probe window sits 14 cells
>   from the body; the reveal reaches 9 cells from `head + _lamp_offset` with a lead ≤1.9, so the nearest
>   lit edge is 10.9 cells. **The lamp cannot reach the window at any pointer position.**
> - **TR-07** (rock 4.13 vs wall 2.02) — both populations in ONE capture under ONE lamp, plus a same-build
>   repeat at 4.13/2.01 (0.3% boot-to-boot), plus the finding replicating in the `dark` arm the lamp never
>   reaches.
> - **TR-08** — the G channel was pre-registered as the untouched control: ≤2.1% drift against a 25% effect.
> - **findings 16 and 17, and every roughness number** (earth 18.62%, stone 4.90%, the GRAM decomposition,
>   the population table) — **IMMUNE**. They come from `FineTerrain.rebake` over flat grey read straight
>   out of `fine._data`, with no scene, no window and no renderer. No lamp exists in that path.
>
> **TR-09 IS REOPENED.** Finding 15 closed it on the normalised series 0.165 / 0.131 / 0.129 / 0.131 /
> 0.157, and that claim is the one place where all four weaknesses coincide: a cross-boot comparison of an
> absolute luma statistic, **n=1 per depth with no same-build repeat**, and — decisively — **no control
> independent of the quantity at risk, because the lighting proxy IS the denominator**. Normalising cancels
> a uniform scale change; it does not cancel a lamp TRANSLATION. Worse, the bias runs *toward* the
> published answer: pointer variation injects scatter, and scatter is exactly what turns a modest real
> gradient into a "flat" reading. The two points carrying the flatness (0.165 at 6 rows, 0.157 at 40) are
> also the only two with no cross-fixture corroboration; the three middle points that agree at 0.129–0.131
> are the ones that can be independently anchored. **A ticket was closed and no treatment was built on
> this.** It needs re-measuring with repeats on a lamp-settled build before it may be closed again.
>
> **Finding 9 is corrected rather than reopened.** Its share-of-readable-rock series (24.1 / 22.8 / 27.9 /
> 40.8%) carries a confound that has nothing to do with the pointer: **the rock denominator falls 6162 →
> 4258 with depth**, while the bright-pixel count only rises 1405 → 1737. So roughly **10 of the 18-point
> rise is arithmetic in the denominator**, not light. The headline survives — a majority of on-screen rock
> sits below the readable threshold at every depth, 59% even at the brightest — but the series must not be
> read as a depth TREND, and it is quoted downstream as a bound on the remaining TR tickets.
>
> **A second pointer channel exists that finding 17's write-up does not name:** `world_renderer.gd:1605`
> `_draw_aim()` paints a white box at α 0.85 at `_aim`, at z 0 — the pointer places a bright mark IN THE
> WORLD, not merely in the HUD, and where it lands on exposed ore it lands on the glint fixture's subject.

---

## TIER 4 — world, lore, descent

**T4.1 · Give every band one exclusive full-frame landmark or physical behaviour** that cannot appear in
the band above it. Surface-vs-deep is legible; **15 m vs 27 m is not**. Today's reward for depth is tint,
darkness, water incidence and typography. *(Descent 6.6.)* This is the surviving form of the
"one-rule-per-layer" thesis and of the iconic per-layer physics twist.

**T4.2 · Make geology causally predict resources and hazards** — visible faults generating both ore
concentration *and* water intrusion. *(World Coherence 5.6.)* Pairs naturally with T1.5.

**T4.3 · Lore that teaches.** Put **one industrial remnant in each band whose history visually teaches
that band's new mechanical rule.** Deleting the fiction today would barely change play — it is
nomenclature, not structure. Keep it light; make it load-bearing. *(Lore 2.2 — the lowest score on the
board.)* Supersedes AUDIT_UPDATE item 16 ("The Works Are Cold" first slice) by giving it a *form*; the
choice of fiction remains a **user, vision-level decision**.

**T4.4 · BACKLOG — define the Sinkforge for a relocatable world.** A single mandatory fixed structure is
no longer the default: depleted deposits and Terraria-style player relocation make coordinate ownership a
design liability. Choose later among a player-built machine, distributed network state, repeated buried
nodes, mobile core, or geological process. The world may supply bones; no coordinate may own the player's
organs. *(Name Recall 6.2.)*

> **This item REFUSES the vibe audit's own recommendation, and that was sitting here unstated.** Dimension
> #19 asks for *"a gigantic recurring structure the player crosses, repairs and eventually awakens across
> multiple bands"* — the most evocative single line in the audit. It is incompatible with the relocation
> premise, because it hands one coordinate ownership of the player's progression. **Refuse it knowingly or
> reverse the relocation premise; do not keep both.**
>
> **RESOLVED — the brief now LOCKS the invariant, so this is a decision rather than my read:**
>
> > *Campaign progress accumulates in player-owned capability and network reach; no unique coordinate owns
> > progression.*
>
> The fiction is still open; the invariant is not. Dimension #19 is therefore **refused knowingly**, and
> any later Sinkforge must satisfy the invariant rather than the audit's phrasing.
>
> **And the current build already violates it.** The brief names the live case: the opening is
> coordinate-led through the ruined Bazaar near spawn and the fixed Seal ladder. The Seal may remain a
> world band, but player capability, Bazaar access and ordinary production **must not quietly make the
> starting ruin a mandatory permanent home** — and *reproducibility or portability has to be demonstrated
> before relocation is claimed*, not assumed because nothing forbids it. That is an open gap against a
> locked invariant, which makes it the strongest-standing unassigned item in Tier 4. Pairs with T3.5.

**T4.5 · Audio: rock-mass occlusion.** Listener enclosure changes reverb, but the solid world does not
obstruct and darken distant sound. Source-to-listener occlusion with progressive low-pass and attenuation.
*(Soundstage 7.8 — the highest score; this is the one named architectural omission.)* Also flagged: the
silence is almost continuously occupied by beds, which may weaken contrast. Remaining audio follow-ups
from AUDIT_UPDATE item 14: the strike ringing the room via the existing `hollow` reading so a blow tells
you the *size* of what you are about to open; per-machine voices in the hum; a `check_space` layer —
**but see kill list #8 before building that layer.**

**Partially shipped, 2026-08-24:** the attenuation half landed (`9d3f1cd`). `Sfx._occlusion(source,
listener)` walks the same `is_solid`/`in_bounds` primitive `_probe_space` already used for the listener's
own enclosure, aimed at one point instead of swept in twelve fixed directions, and `play()` now subtracts
`occ * OCCLUSION_DB_MAX` from `volume_db` — a distant blow behind rock is quieter than the same blow with a
clear line to it, not just quieter with distance. Verified headless: a walled line reads more occluded than
the same line open, an open line reads exactly 0. `OCCLUSION_DB_MAX` (10.0) is a **conservative placeholder,
not a tuned value**, flagged in-code the way T3.10's tuning is. **The progressive-low-pass half is
deliberately NOT built:** `AudioStreamPlayer2D` has no per-voice filter property, so it would mean giving
each pool voice its own bus carrying an `AudioEffectLowPassFilter` — real structural risk against the pool's
already-delicate teardown bookkeeping (`_owns_bus`/`_exit_tree`, guarding a documented headless ObjectDB
leak), not a mechanical add. Scoped by a fork before any code was touched; its recommendation to split the
mechanical half from the structural+tuning half is why only the first half shipped this cycle.

---

## TIER 5 — infrastructure debt (only to protect a chosen change)

> **Governing rule, from kill list #8:** *no new harness layer that is not attached to a human-observed
> failure or a chosen visible change.* Everything in this tier is now **demand-pull**. It is real debt and
> it is not deleted — but nothing here is picked up because it is next.

**T5.1 · Performance SLO semantics.** `check_frametime` is internally inconsistent: it reports missed-slot
rate but still fails named hardware on p95 > 8.33 ms. `DROP_AT = 1.5` classifies skipped slots on a
*confirmed refresh-paced* display; on an unpaced run a 10 ms frame counts "not late" at 100 fps. **Decide
the contract, then encode exactly that** — a stated percentage of frames within one refresh interval, plus
a separate hitch ceiling. A literal zero-miss "minimum 120 fps" bar is not a realistic SLO. *(AUDIT_REPONSE
#2.)* **Attach to T2.3.**

**T5.2 · `check_pacing` never asserts arrival. — SHIPPED 2026-08-17.** It called `dig_down_to(...)` without
arrival mode and discarded the result, so its descent-dependent measurements were untrustworthy. Done as the
item preferred: `excavate_to(cell)` / `descend_to(cell)` added as named wrappers in `play_agent.gd`, with the
22 existing callers left meaning contract one rather than mechanically re-pointed. *(AUDIT_REPONSE #3.)*

> **Two things the fix turned up that the item did not anticipate.** (1) The first veto was *itself* blind:
> `PlayAgent._arrived` is one-sided (`body.y >= cell.y - ARRIVE_SLACK`), so a body already below the target
> satisfies "arrival" without moving — measured at descent 0 frames, body parked at row 19, arrival granted.
> The veto is now a depth floor asserted against the layer's own target, and `_arrived`'s one-sidedness is
> documented rather than changed under 22 callers. (2) **`check_pacing` fails on two of four seeds** — 7
> (silence 22% over a 20% cap, density 23.3 under a 24.0 floor) and 1234 (silence 22%) — while the harness
> runs one seed and is green. Floors untouched: whether the pacing is too thin on those worlds is a design
> call, not a threshold to move. Wants `tools/seed_corpus.sh` pointed at it and a ruling.

**T5.3 · Make the registry authoritative.** `NAMES+=` source parsing recognises today's three helper verbs
and would miss a multiline, sourced, aliased or generated registration. Replace with a runner `--list` /
JSON manifest consumed by execution, CI coverage, corpus selection and the save guard; keep text parsing as
a mutation-tested secondary. `MIN_LAYERS = 40` against 76 is a weak parser-non-vacuity floor, not proof of
equality. *(AUDIT_REPONSE #4.)*

**T5.4 · Progressive-fill frame cost is unmeasured.** `bake_pending(4000)` times the row loop but performs
`Image.set_data` and texture upload *outside* that budget, and always paints at least one whole row — so a
slow machine overshoots by a row plus upload, against 4 ms that is already ~48% of an 8.33 ms frame. Needs:
time-to-first-present, complete per-frame slice cost including upload, and an assertion that no frame
records both a dig-region bake and a pending fill. The row-major sweep can also be **outrun by a fast
camera or a load at depth**. *(AUDIT_REPONSE #6; item 17 is **partly** closed.)*

**T5.5 · The 1.1× plunge — a design failure against stated intent.** The brief says an under-~2× route is
scenery; measured payoff is ~1.1× against a 1.0 floor. **Do not lower the prose to buy green and do not
raise the threshold without tuning evidence.** Report as *mechanically complete, design-red*. The choice —
make the plunge materially faster, or revise the intent after watching players — is a **user decision**.
*(AUDIT_REPONSE #7.)*

> **TIER 5 IS DEMAND-PULL AND MAY NOT CONSUME OVERNIGHT CAPACITY — director ruling 2026-08-17.** *"They
> are valid debt, but do not let them consume overnight capacity ahead of active player-facing work unless
> a selected change touches them."* **T5.6 and branch/worktree hygiene run only when a selected change
> touches them.** T5.9/T5.10 stay **safety monitoring** — they exist so nothing is lost or pushed with a
> trailer, **not as a mandate for a broad cleanup pass.** Debt that is genuinely inert is the cheapest work
> to feel productive doing, and this tier is where an autonomous night goes to hide from the game.

**T5.6 · Finish semantic non-vacuity.** The completed sweep cleared **two greppable forms** plus the three
shared helpers — roughly the first of six columns. A suite-wide clearance needs a per-layer evidence table:
fixture preconditions, independent oracle, headless semantics, mutation result, seed coverage, skipped
sub-assertions. Completion, evidence count, required state transitions and semantic arrival must be
**vetoes** before any ratio or score is computed. *(AUDIT_REPONSE #3.)*

**T5.7 · Decompose the three god files** along seams that already exist: a lighting painter and a water
painter out of `world_renderer.gd`; a `digging.gd` out of `main.gd`; per-behaviour modules out of
`factory_sim.gd` (`_BEHAVIORS` was designed for it). **Behind immutable-suite evidence only.**

**T5.8 · `FineTerrain` names two unrelated classes** — the renderer's baker and the sim's molding module.

**T5.9 · Preserve worktrees.** Seven viable branches to be **re-derived against current source, not merged
wholesale**; two upstream; two superseded; the lode cutover forbidden. **Delete nothing** until the user
explicitly accepts a disposition and any unique patch is archived or re-derived. *(AUDIT_REPONSE #8.)*

**T5.10 · Two live branches carry the AI trailer** — `refs/heads/audio-per-material` (4) and
`refs/heads/presentation-glyphs` (3). Reinfection risk on merge. **User's worktrees: per-item confirmation
before touching.**

**T5.12 · `check_hud_layout` is flaky — new finding, 2026-08-24, human-observed.** Found auditing the 17
unpushed commits for coherent publication: the layer FAILED on a fresh `HEAD` run (scenario "running fast,"
the fast-forward chip colliding with several panels), which read at first like a regression. Re-run twice
more on the identical commit: PASS, PASS. Then checked `origin/main` (before any of the 17 commits) the same
way: FAIL on run 1 (different scenarios — "machine hovered," "minimap up"), PASS, PASS on runs 2–3. Same
~1-in-3 flake rate on both commits, never the same failing scenario twice, and none of the 17 commits touch
`scenes/hud.gd`'s drawing code for any panel involved (confirmed via `git diff origin/main..HEAD --
scenes/hud.gd`: only an unrelated alert-text addition and a comment fix). Verdict: **pre-existing timing
race in the check itself, not a layout regression in any of the 17 commits.** Not yet root-caused — the
file's own comments describe a related mouse-cursor race in the "hover" scenarios that a prior commit
already had to fix by warping the cursor rather than trusting the latch; the "running fast" scenario doesn't
hover, so this is likely a second, distinct timing issue in the same layer's frame-settle logic
(`_snapshot`'s 3-frame `await RenderingServer.frame_post_draw` wait). Flagged rather than fixed here per the
"no harness expansion without a scoped priority ID" rule — this is P0-adjacent (a flaky layer silently
returning green on rerun is worse than a consistently red one, since nobody notices), but root-causing an
intermittent race is real, separate investigation work, not a one-line fix alongside a commit audit.

---

## The experience evaluations — a workstream, not a tier

`docs/DIRECTOR_BRIEF.md` §4 defines fourteen (A–N). They are **director gates, not unit tests**, they do not
run per commit, and — this is the part that matters for this list — **they are explicitly forbidden from
becoming harness infrastructure yet.** Run them by hand from committed prompts, save the evidence, and
automate orchestration only after two or three runs prove the evaluation finds differences worth having.
That is kill-list #8 applied to ourselves, and it is the correct call: this project's diagnosed failure
mode is instrumentation abundance against human-evidence scarcity, and an eighth harness subsystem written
to measure fun would be that failure wearing a new hat.

**T1.9 / T5.11 · Calibrated agent-journey evaluation layer — DESIGN BACKLOGGED, IMPLEMENTATION GATED.**
The existing play-agent checks prove scripted milestones; they do not yet explore whether a capable actor
forms a desire, understands a payoff, recovers from friction, or chooses to continue. Do not make the
deterministic harness answer subjective questions or add another repeated milestone layer. Keep a separate
portfolio: deterministic system checks; real-engine encounter contracts; calibrated journeys; screenshot-
only criticism; one-treatment A/B comparisons; and small human calibration sessions. Each layer must retain
its own evidence and cadence. The journey corpus should rotate seeds, depth, lighting, depletion, route
shape, machine adjacency, inventory, objective visibility, and recovery conditions. Calibrate the actor
before judging the game; use a privileged oracle only for reachability; apply an L0–L3 assistance ladder;
detect actor loops; classify `WORLD_INVALID`, `DRIVER_INVALID`, `ACTOR_INVALID`,
`COMMUNICATION_FINDING`, `DESIGN_FINDING`, `MOTIVATION_FINDING`, `ACTOR_LOOP`, and `VOID`; retain raw
receipts and never emit a single fun score. Evaluate whether the actor forms the intended next desire after
ore, fuel, automation, depletion, and recovery payoffs—not merely whether it reaches a milestone. The full
specification, schema, controls, and engineer task list are in
[`docs/AGENT_PLAY_EVALUATION_PROTOCOL.md`](AGENT_PLAY_EVALUATION_PROTOCOL.md) and
[`docs/handoff/AGENT_JOURNEY_EVALUATION_ENGINEER_PROMPT.md`](handoff/AGENT_JOURNEY_EVALUATION_ENGINEER_PROMPT.md).
Run two or three manual pilots first; only then may minimal orchestration be proposed. Adaptive self-play
and generated-goal search are explicitly later work because they can reward-hack the evaluator. This item
may not displace T1.0, T2.1, T2.3, or T3.1, and no Freight desirability claim may use it before the
pre-reveal demand evaluation is valid.

**RECONCILED 2026-08-24 — a documentation contradiction resolved, gate state re-measured, explicit
definition of done attached.** Two prior findings appeared to disagree (`docs/handoff/
AGENT_JOURNEY_READINESS_2026-08-23.md` said gate 6 fails; `tools/eval/LANE.md` said gate 6 is DONE) —
reconciled: the first measured `tools/play_agent.gd` as the candidate judged actor and correctly found it
fails (it makes 50 direct `sim.*` reads and was never meant to be the judged actor — it is the
deterministic harness driver), and its own text already recommended the fix as a SEPARATE player-visible
feed object rather than a rewrite. That fix was built afterward (`tools/eval/player_feed.gd` +
`check_actor_boundary.gd`, mechanically enforced with denylist + signature rules and three control
fixtures, in the disposable `/private/tmp/sinkforge-agent-journey-eval` lane worktree) and IS what "gate 6
DONE" refers to. Both findings are true of their own subject. Current six-gate standing, re-measured more
rigorously than the original readiness pass:

    1  safe isolation     NARROWER-THAN-CLAIMED   redirection not confinement; lock is per-invocation
    2  truthful route     UNMEASURED              needs play
    3  unmanufactured     UNMEASURED              needs play
    4  legible route      NARROWER-THAN-CLAIMED   smaller population than the gate names
    5  evidence feed      FAILS                   0 of 7 artifacts retained; the no-overwrite condition holds
    6  actor boundary     DONE                    mechanically enforced, check_actor_boundary.gd

**The evaluation stays INVALID: one gate closed of six.** This item's priority ID was already assigned
(`T1.9 / T5.11` — no new ID needed) and is now an explicit **bounded product milestone**, not open-ended
harness expansion: closing gates 1-5 remains real engineering, individually costed in
`tools/eval/READINESS_GATES_1_AND_5.md`, and none of it is authorized by this reconciliation alone.

**Hard definition of done, director's terms:** the actor receives only permitted observations/actions; no
direct simulation reads (gate 6 — DONE); capability and input reliability validated; one seeded 20-minute
journey reaches a defined progression goal; failures distinguish game friction from actor incapability; the
run produces raw evidence plus a human-readable report. **Then stop — do not spend another week polishing
the harness without running the journey.** The next move on this item is scoping the cheapest real path to
ONE manual pilot, not further gate-closure infrastructure.

**That scoping is done, 2026-08-25 — `docs/handoff/T1_9_JOURNEY_PILOT_SCOPING_2026-08-25.md`.** Read-only
synthesis across the three documents above that had never been reconciled into one current picture;
zero code changed to produce it. Finding: gates 1, 5, and 6 do not need another harness commit — 6 is
already done, and 1/5 have known, zero-code procedural paths for one supervised manual run (screen
recording, a hand-written evidence header, careful `with_machine.sh` discipline). Gates 2 and 3 are not
blocked on anything; they are simply untried and can only be evaluated *during* an actual run. **The one
real remaining blocker is gate 4, and it is peer `c1`'s T3.1/P2 interior-legibility work, not this
session's to close.** (Also confirms the `(6a)` label on that ticket predates this session's identity and
is not a reference to it — checked directly to rule out a false lead.) No further gate-closure work is
recommended; the memo also flags that gate 3 in particular cannot be pre-diagnosed from source, only
observed once someone runs the pilot.

| | Evaluation | Gate |
|---|---|---|
| **A** | desire formation — the *"now what?"* test | **highest-priority subjective evaluation**; blocked by T2.1 |
| **B** | labour-retirement integrity | every milestone touching the opening or the winch loop |
| **C** | bottleneck legibility | as above |
| **D** | depletion + relocation freedom | before accepting the winch as progression architecture |
| **E** | grapple preservation | as above; **advisory until human-calibrated** |
| **F** | hero-machine causality | every major hero-machine art pass |
| **G** | novelty half-life | before adding another material tier or stratum |
| **H** | failure comprehension and recovery | before shipping any environmental punishment |
| **I** | pre-reveal demand | before accepting the Freight Winch as a major logistics payoff |
| **J** | construction and commissioning | as above |
| **K** | payoff delight | before hero art is considered successful; human authority |
| **L** | capacity appetite | before scaling beyond one winch route |
| **M** | accessibility and redundant state | as above, across alternate sensory profiles |
| **N** | long-tail network burden | before several routes and depleted sites become the campaign norm |

**The 2026-08-17 revision to §4 is a methodology correction we should generalise beyond these eight.** Every
change was the same defect — *the instrument was inside the population it measured*:

- **A no longer asks the actor what it wants.** The old prompt said *"say what you want to accomplish
  before you take a substantial action"*; asking that question **manufactures the desire being scored.**
  Spontaneous behaviour and prompted explanation are now scored separately.
- **C splits into a blind detection run and a directed diagnostic run.** *"Continue playing this save for
  five minutes"* first, and only then *"inspect the running system"*. Directed diagnosis can no longer
  earn spontaneous-detection credit — those were two different measurements sharing one number.
- **Evaluators are not independent if they share a model family, prompt wording, and transcript order.**
  This one indicts existing practice, not just future work: our blind-vision "Sees" tier and any
  N-skeptic adversarial verification are correlated by construction, and their agreement has been reading
  as corroboration when it is partly a shared prior.
- **The actor's exact feed, cadence, controls, and any state a human could not see must be declared** —
  otherwise the boundary of what was measured is undefined, which is the failure already catalogued as
  shape 27.

---

## The kill list — stop doing these

1. The permanent giant objective plate *(→ T2.1)*.
2. **"Factorio × Terraria" as the operative design test.** Keep it as ancestry and possible market
   shorthand, but do not advertise it as a proven promise until the artifact supports sustained automation
   decisions; build internally against kinetic industrial descent.
3. Terminal gear and plate production as production *branches* — collapse into construction costs unless
   they become recurring sinks *(→ T1.1)*.
4. ~~The standalone full-screen PACK tab in its current form~~ — **STRUCK 2026-08-17, twice over.**
   Measurement refused it (`144bd5a`: PACK is the only surface showing the pack beyond ten slots), and the
   director then ruled it directly: *"Do not remove PACK: it is still the only correct view beyond the
   ten-slot hotbar."* **The kill list keeps the entry struck rather than deleted** — a killed line that
   silently disappears looks like a line that was never proposed, and the reason it was wrong is the useful
   part. Its real complaint — layout and decision density — is live as **`MNU-12`** under **T2.1m**.
   *(Was "`MNU-11`/`MNU-12`" until 2026-08-20; `MNU-11` had already shipped in `d8bcc87`.)*
5. Recurring full-width band ceremonies over live movement *(→ T2.1)*.
6. The persistent bottom-left keyboard legend *(→ T2.1)*.
7. Any new lore campaign, bosses, or ending work — **the first automated line does not yet generate a
   second interesting decision.**
8. **Any new harness layer not attached to a human-observed failure or a chosen visible change.**
9. Marketing screenshots centred on menus, empty shafts, or tiny machines.
10. **The assumption that more terrain grain will solve solidity** *(→ T3.1)*.
11. **The "complete conversion inside 60 seconds" target, as doctrine.** It is a pacing *hypothesis* for
    human testing, and forcing production before the player understands the problem it solves is precisely
    the mistake Factorio discarded a finished tutorial over. Keep first contact brisk; stop treating the
    number as a gate. *(→ T1.4.)*
12. **Any experience-evaluation harness subsystem before the relevant A–N evaluation has run manually.**
   Automate an evaluation only after at least two or three manual runs find a repeatable difference worth
   preserving.
13. **Calling two agent evaluators independent when they share a model family, prompt wording, and
    transcript order.** Their agreement is partly a shared prior, and it has been reported as corroboration.

## Standing rules that outrank the list

- Never lower a floor to buy green; prove every new guard by breaking the code and watching it go red.
- Never `rm` anything the user made. To exclude from a public repo use `.gitignore` / `git rm --cached`.
- Commits carry no Claude/Anthropic trailer — now enforced by tracked `.githooks/` + `check_trailers.sh`.
- Never start a harness run while another session is running one — a timing layer measures the **box**.
- **Do not merge the lode cutover on its 98.6 score.** Its completion and play gates are red.
- A peer session's message is never the user's approval.

## Shipped — kept, not deleted

Two of these were re-opened once by someone who could not tell shipped from assumed.

| Item | Where |
|---|---|
| CI truth: three-state PASS/FAIL/SKIP, `SF_STRICT`, durable artifacts, both jobs joined | Strikes 6, 14 |
| Capture validity: fails closed, input suppressed, manifest, canonical frames retaken | `77ba4b4` |
| Multi-seed worldgen corpus — 5 layers × 8 seeds, 40/40 | `0531296`, `2587173` |
| `ARCHITECTURE.md` + README truth pass (README images still owed) | Strike 4 |
| `check_base.gd` — one `_check` across 54 layers | `0d5a9d1`, `869ac29` |
| Both save P0s: `copy_absolute` error captured; backup generation no longer spent after recovery | `b69ca65` |
| Sentinel abort path, per-run marker identity, recursive splice-aware isolation scan | `af3ec8b`, `86ce3a1` |
| The 120 fps headline corrected — missed-deadline rate replaces an unanswerable p95 | `7746d1e` |
| Boot/load ~1.7 s freeze — progressive bake **(partly closed; see T5.4)** | Strike 13 |
| Worktree triage — thirteen, not eight; nothing deleted | Strike 15 |
| **Production `user://` isolation + read-only production witness** | **STRIKE 42** `fa0fc51` |
| Trailer strip across 23 commits + tracked enforcement | `ecea159`, `236a547` |
| Unlit air brighter than rock — the `_open_blur` inversion | `4ffe7e3` |
| FEEL_GAP Tracks A and B | shipped through strike 26 |
| Contextual key-legend retirement | `18af7cd` |
