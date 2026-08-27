# OVERNIGHT HANDOFF — 2026-08-20 → 21

    branch          overnight/2026-08-20-autonomous
    started at      cf2e7b2   (local main, untouched all night)
    ended at        af99f20   (48 commits since local main; 51 ahead of origin/main)
    origin/main     bd2b1d7   UNTOUCHED — nothing was pushed
    local main      cf2e7b2   UNTOUCHED — no commits, merges, rebases or rewrites

**Nothing left this machine.** The one item that would have — pushing the branch and reading CI — is a
director's call and is written up as BLOCKED-DECISION below, not as an item I did not reach.

---

## What the night was

Thirty-nine commits. All the harness or the things that judge it, except the last one, which is
the first shipped-code defect the harness itself led to. Every red the session started
with is closed, **not one bound was lowered and nothing was converted to a SKIP**, and the release gate now
has a reachable, checkable target instead of an unreachable one.

The recurring shape, stated once because it explains most of the list: **an instrument that cannot register
its subject reports a quiet green.** A guard whose grep matched the comment naming the thing it was
looking for. A registry half of whose rows could not fail in either direction. A gate that read its own
shell's environment instead of the run's. A runner that recorded `HARNESS_EXIT=0` for a sweep killed by a
signal. A layer that never loaded and was counted as PASS.

---

## Completed

| # | Item | Commits | Evidence |
|---|---|---|---|
| 1 | The four opening reds, all instrument faults | `71d8a8f` `65280fd` `480ee08` `025fe78` | each re-run green; no threshold moved |
| 2 | Machine-lock protocol collapsed to one file | `028b9fb` `fbc0092` | `check_lock` 31 assertions PASS |
| 3 | VOID as a fourth verdict, with a cost | `a6267f0` | exit 43 documented and gated |
| 4 | The verdict gate reachable from a terminal, not only CI | `a3cde62` `a694094` | one implementation, two callers |
| 5 | Wall-clock cap for fixtures (`tools/cap_lib.sh`) | `a4a3d8c` | exit 6, watchdog holds no stdout |
| 6 | The stand-down registry, ids, and `iff:` conditions | `9071f63` `363ac06` | conditions read from the run, not the gate's shell |
| 7 | `HARNESS_EXIT=0` on a signal-killed sweep | `f513cc8` `47c99c7` | in-population control, both legs |
| 8 | Three-valued stand-down accounting | `82fc4fc` | 12 of 12 rows resolved on a real sweep |
| 9 | Base-class namespace collisions caught pre-commit | `9c51e31` `e7c4250` | graded against the engine, 7/7 |
| 10 | An assertion printed value and bound at 1-point resolution | `a68f969` | `20%, cap 20%` became `20.45% = 374 of 1829 frames` |
| 11 | The comment register in three shipped files | `7e0d42b` | gate clean; code byte-identical with comments stripped |
| 12 | Two shell gates that ran nowhere, registered | `f097834` | 107 layers; mutant fires, control passes |

### The release gate, stated so it can be quoted

**Exit 0 is unreachable and always will be** — the stand-downs are structural. The target is
**exit 4 with exactly the registered stand-downs and no others**, and that is now asserted rather than
described. Last full sweep, `e7c4250` minus the docs:

    107 PASS / 0 FAIL / 0 SKIP of 107 · exit 4 · 0 engine load failures · HARNESS_RESULT=yes
    twelve registered rows, all resolved: 6 declined · 5 asserted · 1 out of reach

**THE LAST SWEEP OF THE NIGHT REACHED IT AGAIN**, at `9894aa9`, after the pipefail repair:

    107 PASS / 0 FAIL / 0 SKIP of 107 · exit 4 · 0 engine load failures · HARNESS_RESULT=yes
    stand-downs: exactly the registered ones, 6 ids, 6 lines

**But do not read a green `check_material_grammar` as a fixed one.** It passed in sweepC and sweepD and
failed in sweepA; it sits exactly on its bound and falls under it about a third of the time. Read its
entry below before quoting any number from it. Nothing was moved to make it green.

---

## Blocked, skipped, and deferred — with the reason, not the word

**PUSH THE BRANCH AND READ CI — BLOCKED-DECISION (director).** Pushing publishes 27 commits of
harness-forensics prose to a public repository the user keeps as a portfolio piece, while an
authorized-but-unexecuted plan exists to purge exactly that corpus from the public tree. That is a
director's call and neither session should make it unattended.

> **One premise I gave for this was stale and c1 corrected it.** I claimed `origin/main`'s `harness.yml`
> still carried the `AI` tell in two CI job names. It does not — verified here, with the input checked
> first: blob 11682 bytes, 22 matches for a control pattern, **0** for the tell. The decision stands on the
> premises that survive.

**Consequence, so it is not rediscovered:** every CI claim on this branch is a **prediction**. Four reds
were fixed against a job matrix that has not run them. `check_dig_hitch` on Linux (bulk transfer ~19%
slower than per-cell, symmetric best-of-3 within one run, a real platform result) cannot be re-measured
from here at all — the claim is about the other platform.

**`grapple.gr03-single-frame-bow` — DECISION-DEFERRED, and c1 withdrew the argument for changing it.**
The proposal was to reclassify the saturated reading as VOID. c1 retracted it on the CI evidence: the
saturation is **deterministic** on xvfb — every run, stable numbers — so re-running produces the identical
result and the single action VOID exists to recommend cannot help. Independently of the standing rule
about never converting a red, VOID is wrong on its own terms. And 0.4624 exceeds `SAG_CAP` at 0.42, the
maximum hang the renderer can DRAW, so the mask is reliably picking up something that cannot be the rope
under that rasteriser. **The red is doing its job.** Left red, numbers attached.

**Director's calls left open, unchanged:** the 33 lines printing a value and its bound at 1-point
resolution; the pooled-roughness guard (6.53% against a 6.50% ceiling, printed and asserted by nothing);
45 stale worktrees under `.claude/worktrees/`.

---

## Design decisions discovered, not made

**PRIORITY.md's #1 active item was describing a build that no longer exists.** T1.0 reads *"there is no
`pack_cap`, `carry_cap`, `MAX_CARRY` or bulk limit anywhere in `src/`"*. There is:
`const PACK_BULK_CAP: int = 90` at `src/core/factory_sim.gd:215`, with `is_bulk_item`, `carried_bulk`,
`pack_room` and `can_carry`, and the player verbs ask before they take. Five commits, **all ancestors of
`main`** by `git merge-base --is-ancestor` rather than by author: `71481d5` `b6a5a4f` `db6363b` `93bd934`
`707416c`. A dated correction banner is now above that block; the original paragraph is kept, because a
list that quietly edits its own past cannot be audited.

**What is actually open under T1.0 is the spike's own conclusion: the gravity trunk is not a sink.** Ore
dropped down the shaft rests at the bottom, walking to the spine puts the body at that bottom, and with
auto-pickup on the player walks back into their own delivery and re-pockets it — knockout-verified at
65 → 130 → 195 → 260 with it on, 65 → 65 → 65 → 65 with it off. **No cap value fixes a route with no
destination that keeps what arrives.** What the sink should be is undecided and was not decided here.

---

## Tests run

    full display sweeps      39341f4 103/2/0 exit 1 · 0729de4 105/0/0 · 5c8af7b 105/0/0 · 363ac06 105/0/0
                             sweep7 (105/0/0 but exit 7 — a layer had stopped loading; see below)
                             sweep8 105 PASS / 0 FAIL / 0 SKIP · exit 4 · HARNESS_RESULT=yes
                             sweep9 107/0/0 exit 4 HARNESS_RESULT=yes — the release gate, at f097834
                             sweepA 106/1/0 — check_material_grammar, characterised below
                             sweepB 105/2/0 — the same, plus a play-tests failure I caused; retracted below
                             sweepC 106/1/0 exit 1 HARNESS_RESULT=yes, 0 load failures, at 31e6c9c
                                    play-tests GREEN (the revert confirmed), grammar GREEN this run,
                                    one FAIL: check_exit_codes, a flake diagnosed and fixed below
                             tight-gap ruler  2 legs x 16 phases, the one-row opening characterised
                             census run  SF_ONLY=play-tests with a log-only probe, see below
                             sweepD 107 PASS / 0 FAIL / 0 SKIP · exit 4 · HARNESS_RESULT=yes · 0 load
                                    failures · exactly the 12 registered stand-downs, at 9894aa9.
                                    THE RELEASE GATE, re-reached after the pipefail repair.
    headless sweep           90 PASS / 0 FAIL / 15 SKIP, 3 stand-down ids, 3 absent layers named
    parse-check              all 103 subclasses of check_base.gd, with a positive control
    seed corpus              SF_CORPUS_ONLY=check_pacing, 8 seeds — IN FLIGHT at handoff time
    signal legs              SIGTERM against the pre-fix and post-fix runner, one variable
    gate mutants             synthetic log dirs, one line moved per leg

### The one that should be read by a human, in c1's words

**The runner's own table printed `PASS` for a layer that never loaded.** `godot --script` exits 0 on a load
failure, so `96-check_hint_gate.log` — nothing in it but a parse error — appeared in the table as a pass
and the run said 105 PASS / 0 FAIL. `tools/harness_verdict.sh` caught it at 275s by reading the log rather
than the code, which is the system working as designed, **and it does not repair the table.** Anyone
quoting the layer table without the verdict is quoting a green over a layer that did not run.

---

## Known reds and skips

- **CI on `main` (`bd2b1d7`, run 32448201825) is RED**: 83/5/15 headless plus 15/1 pixels. Four of the six
  are fixed on this branch and unverified there. Two are not fixed: `check_dig_hitch` bulk-vs-per-cell
  timing on Linux, and `check_grapple_reads` saturation on xvfb (the gr03 item above).
- **Twelve registered stand-downs**, all in `tools/stand_downs.txt` with a reason each. Six declined, five
  asserted, one out of reach on this machine. Exit 4 is the expected verdict of a healthy full sweep.
- **`check_exit_codes` is fixed, not accepted** (`9894aa9`). It went red once, in sweepC, and the cause
  was its own instrument rather than the property. Full-sweep verification of the fix is the last thing
  this session ran; see the sweeps row above for which run carries it.
- **`play-tests` is NOT a standing red.** It failed once, in `sweepB`, because of a change I made and
  reverted the same hour. Green before it and green after it. Recorded here only so nobody reads the
  sweepB log cold and opens an investigation into a layer that is fine.

---

## Subagents and worktrees

**None spawned.** All engine work was serialised through `tools/with_machine.sh` by this session, which is
the protocol when timing layers are in the mix. 45 stale worktrees under `.claude/worktrees/` predate the
night and were left alone: they are not mine to remove without a word from the director.

---

## Files needing review

    tools/check_base.gd            new accounting API; 12 call sites across 7 layers depend on it
    tools/harness_verdict.sh       the gate is now the only party that derives "not reached"
    tools/stand_downs.txt          header rewritten; the three states are specified there
    tools/run_harness.sh           signal traps and the not-a-result annotation
    tools/check_base_namespace.sh  new, called from .githooks/pre-commit
    .githooks/pre-commit           new gate above the early return; mojibake decoder no longer passes
                                   an undecodable file
    tools/check_hint_gate.gd       `_asserted` renamed to `_attempted` — a rename for the base class's
                                   benefit, and the only file changed for a reason outside itself
    tools/_scratch_ceremony_knockout.gd   untracked; unloadable since `_stand_down` gained its id, repaired
                                   in place rather than deleted
    scenes/player.gd               THE ONE SHIPPED-CODE CHANGE OF THE NIGHT. One condition in
                                   `_resolve_axis`. Read the commit body before the diff; the diff is
                                   nine words and the reason is a page.
    tools/check_stepup.gd          its guard, over four sub-cell start phases. Watched red verified
                                   against the unrepaired mover, and only ONE of the four phases catches
                                   it, so do not "simplify" this to a single approach.
    tools/_scratch_tight_gap.gd    untracked ruler (gitignored with the other 40), the instrument the
                                   whole finding rests on. Its printed "predicted" line models the
                                   UNREPAIRED classifier and no longer applies to the current tree.

---

## The resume-piece constraint, which turned out to have the biggest live defect of the night

`tools/check_prose.sh` measures the comment prose in shipped game code and fails on the marks and
vocabulary that read as machine-written. **It was registered in no harness layer, no CI job and no git
hook** — all three grepped, with a positive control. And it was RED, on three files that are on
`origin/main` right now.

Worse, the count was growing. Ten commits of `scenes/visuals.gd`, oldest to newest:

    117 · 125 · 129 · 135 · 151 · 152 · 156 · 156 · 160 · 166   em-dashes in comment text

**Forty-nine added in four days**, every one written after an earlier scrub had removed them all, past a
gate that would have refused every one and was never invoked.

**Why it survived an audit whose question was exactly this.** `check_ci_coverage` is the layer whose whole
job is *every layer file on disk is registered in the runner*, and its population was filtered to `.gd`.
A shell gate could not appear in it. The guard against this defect was green over a population that
excluded the file that went missing. c1's finding.

**Scrubbed, not swapped.** The gate's own header records that a uniform em-dash-to-comma swap is more
detectable than the punctuation it replaced, which is what its comma ceiling exists to catch. Each site
got the mark its sentence wanted. `rock_tooth.gdshader` went 0.893 to 0.607 commas/line with its
comment-line count UNCHANGED at 56 — the cheap way to lower a per-line density is to add lines, and the
header records an earlier pass that did exactly that. With comments stripped from both sides, **the code
is byte-identical to HEAD in all three files**.

Both orphaned shell gates are now registered, and the coverage layer's population was widened — after a
mutant showed the obvious version of that widening changed nothing.

---

## T1.0b, re-measured tonight (the run that had been owed since `dc9d8e9`)

    1337 ok · 4242 FAIL 24% · 7 FAIL 20.45% · 99 ok · 20260817 FAIL 67% · 31337 FAIL 25%
    512 FAIL 83% · 8675309 ok                                                      3 of 8

Two of the five (20260817, 512) fail the OPENING — the arc never reaches first automation — so their
silence and density are consequences rather than independent readings. The other three miss the silence
cap by 0.45, 4 and 5 points. **The floors were not touched.** `check_pacing` prints the pilot's trace on a
failed opening, so the two severe logs already name which of the nine steps gave up and where the body was
standing when it did.

---

## The one red at the end of the night, and why nothing was moved

    [63/107] check_material_grammar (dirt vs stone) FAIL — 74.29% against a 75.00% floor

**Reachability control first, before any argument about noise.** The layer contains zero references to
`play_agent`, `PlayAgent` or `AGENT`, and the only source files touched since the last green sweep were
`tools/check_prose.sh` and `tools/play_agent.gd`. It cannot be tonight's work. c1 independently confirmed
the three scrubbed files are byte-identical with comments stripped, using a stripper they control-tested in
both directions, so the scrub cannot have moved a rendering statistic either.

**Sixteen runs of the same instrument, in three groups with their conditions**, because the first two
disagreed and c1 was right to refuse a single characterisation:

    early, recorded before compaction   52 52 52 53 53              mean 52.4   spread 1
    later, box busy with sweeps         54 54 54 51 56 55           mean 54.0   spread 5
    quiet box, load 2.3                 53 50 54 53 53              mean 52.6   spread 4

    all sixteen   50 51 52 52 52 53 53 53 53 53 54 54 54 54 55 56
                  mean 53.06   MEDIAN 53   range 50..56   below the floor: 5 of 16

**The floor needs 53 of 70. The pooled median IS 53.** The layer sits on its bound and falls under it about
31% of the time — it passed sweep8 and sweep9 and failed sweepA on identical code.

**And 75.00% is not a value this statistic can take.** 75% of 70 is 52.5 windows; the readings either side
are 74.29 and 75.71. A threshold written in units its own statistic cannot attain is the same object as two
constants that must be ordered with nothing relating them. The bound is really "53 of 70" and would be
honest written that way. `31e6c9c` puts `n` on the line so a reader can see this; it does not change the
bound.

**The load hypothesis does not survive the pooling.** The quiet group looks like the early group and the
busy group is the outlier, which is the opposite of contention depressing a reading. That group is
unexplained rather than attributed.

**What must not happen:** moving the floor to 0.74. The property is not more true at a lower bound. The
repairs that would count all reduce variance instead of relaxing the claim — pin the animation clock before
the capture, sample a full flicker period, or raise the window count until the spread is small against the
margin. This layer photographs the real scene after 70 settle frames, and captures here differ run-to-run
on animation phase alone, so guttering torches move which windows read as lit.

---

## The gate check that failed BECAUSE the gate was called

    9894aa9   tools/check_exit_codes.sh

`check_exit_codes` property 4 asks whether `run_harness.sh` still invokes `harness_verdict.sh`, and it
asked with `grep -v '^#' file | grep -q PATTERN` under `set -o pipefail`. **grep -q exits at the first
match.** On a 22KB file whose match sits at byte 13454 the upstream grep is often still writing, so it
takes SIGPIPE and exits 141, and pipefail promotes 141 over the consumer's 0. The layer then prints
"local sweeps are ungated again" at exactly the moment the invocation is present and found.

    1 in 400 quiet   2 in 400 under twelve spinners   400 in 400 on a 300KB control, match on line 1
    upstream 141 and downstream 0 in every failing trial; 0 in 400 for a consumer that reads to EOF

The CI action leg never showed it: 491 bytes fits the pipe buffer, so its producer finishes first. That
asymmetry inside one run is what pointed at the buffer rather than at the file.

Replaced with a single awk pass. Three watched reds still fire: the invocation deleted with the prose
paragraph left behind FAILs (3 comment mentions survive the strip and do not save it), a path that does
not exist FAILs, the unchanged tree PASSes. The shape was then swept across every file that sets
pipefail: this is the only live instance, every other `| grep -q` has an upstream under 2KB, the four
early-exit `head` pipes discard their status, and nothing sets `-e`, so none of them can abort a run.

**Why it belongs in a handoff rather than a changelog.** It is the sharpest instance this repo has of
the standing screen *can this guard's own mechanism cause the symptom it watches for*, and it was
sitting in the layer whose whole job is to keep the exit-code contract honest.

---

## The one-row opening: a coin flip, and the source says which half is the bug

    tools/_scratch_tight_gap.gd   untracked ruler, extends SceneTree, asserts nothing

Sixteen runs on one map, differing in ONE quantity: the sub-cell x the body starts from.

    leg 1, run-up 8 cells    8 of 16 PINNED (50%)   mean 3.39 px/frame   predicted 60% (9.5), sd 2.0
    leg 2, run-up 2 cells   13 of 16 PINNED (81%)   mean 2.70 px/frame   predicted 75% (12.0), sd 1.7

Every pin identical: `col 13 x=441.00 v=(0.0,0.0) feet_y=384.00 on_floor=true`, and 441 + WIDTH/2 = 448
is the mouth boundary exactly. A body standing on the floor, holding right, at zero velocity, forever.

**The mechanism predicts the rate.** `_resolve_axis` (player.gd:511) skips a solid cell when
`ov_x > ov_y`. Feet resting on a row boundary put exactly `HEIGHT - CELL` = 2px of head into the ceiling
cell, so the test reduces to "did this frame carry the body more than 2px into the mouth". Pin
probability is therefore `2 / travel`, averaged per run. Then it latches: the block sets `velocity.x = 0`
and at ACCEL 1700 a restarting body travels 0.47px in its first frame, under 2px again. **Being blocked
is what causes the next block.** Sharpest cut: twelve of leg 2's runs arrived at exactly 150.0 px/s, so
2.50 px/frame; `1 - 2/2.5` predicts 20% cross and two of the twelve crossed.

**Which half is the defect is settled by the source, not by taste.** player.gd:20 reads *"Just over one
cell tall, so a body still needs two tiles of clearance and a one-tall gap is an honest squeeze."* The
CROSSINGS are the bug: the body tunnels through terrain it does not fit in, on a coin flip.

**REPAIRED, `fafad04`, after the cost was measured rather than guessed.** The two candidate repairs were
never symmetric (c1's framing, and it is the right one): consistently IMPASSABLE costs a fixture a route,
consistently PASSABLE costs a stated design property, making player.gd:20 false and leaving the world with
no honest squeeze anywhere in it. And the status quo was neither, it was a coin flip, which no design can
want.

**The root cause is one condition.** `_resolve_axis` exempts a cell when `ov_x > ov_y`, meaning "the body
is clipping the top of a block UNDER it, so let the vertical pass land it". The identical test fires when
the body clips the BOTTOM of a block above it. Nothing compared the cell to the body: a two-way
classifier, ledge or wall, in a world that also has ceilings. Gating the exemption on the cell being below
the body's centre gives 16 of 16 refused in both legs.

**The cost was measured, not assumed.** Full sweep with the change: 107 PASS / 0 FAIL / 0 SKIP, exit 4,
HARNESS_RESULT=yes, round-trip metrics byte-identical. A probe logging every cell where the old code would
exempt and the new one blocks found TWO across seventeen goals, both falling bodies grazing a corner by a
fraction of a pixel (`ov_y` 0.08 and 0.25), neither changing an outcome.

**Guarded, over four sub-cell start phases.** `check_stepup` now walks a one-row tunnel from four start
offsets and asserts all four are refused. Watched red against the unrepaired mover: FAIL, SQUEEZED THROUGH
at +16px, **and only that one of the four crossed.** A single-approach guard at any of the other three
offsets would have passed against the exact defect it was written for.

**If the director wants squeezes passable**, drop the second half of the condition at the marked line in
`_resolve_axis` and delete phase 3 of `check_stepup`. The decision is one line either way, and the
evidence for both sides is above.

Either way, **50% is wrong**: a player refused entry half the time with no feedback reads it as broken
controls.

### The census, and why the suite cannot see this

A log-only probe at both walk sites in `play_agent.gd` (`walk_to_column` and `approach`), deduped per
cell, changing nothing, so every goal ran its normal course and the list carries no cascade. Applied,
run, reverted; nothing committed.

    17 goals, 17 PASS, ALL PLAY-GOALS MET
    CENSUS one-row opening at (43, 19), walking to column 34, v=-150.0     <- the only line in the run

**One hit in the whole suite**, at the cell sweepB named, on `_goal_round_trip_to_vein`, crossed at
150 px/s. The probe fired, so the near-zero is a real near-zero rather than a dead search.

**The ruler says that geometry pins between half and four fifths of approaches, and the suite crosses it
every time.** Those do not conflict. The play-test runs the same seed and the same route, so it draws the
same sub-cell phase on every run: it draws the coin once and keeps the result. **The determinism that
makes the fixture reproducible is what hides the coin flip from it.** Seed 512's pilot draws the other
side, and that is the entire difference between the two cases. A green play-test here is one sample of a
distribution nobody sampled.

That bounds the impassable repair at **one goal of seventeen**, and it is the game's most common loop.
Which argues the opposite of what a small number usually argues: one dependent, but the wrong one. It
says a player hand-mining a shaft is refused entry to their own dig, so the repair belongs in the mover
and the pilot both, not in a re-routed fixture.

**Not measured, and it changes what the repair has to mean:** every trial in the ruler holds `feet_y`
exactly on a row boundary. A body arriving mid-fall or on a ramp has a different `ov_y` and may block
outright rather than coin-flip.

---

## A mechanism written, measured, and retracted inside one hour

Worth more than the code it deleted, so it gets a section rather than a line.

c1's account of the seed-512 pilot failure was that `walk_to_column`'s probe reads the step cell and the
cell BELOW it and never the cell ABOVE, so a mined row with rock over it scores as a clean walkable step —
while the body is `Player.HEIGHT` 34px in a `WorldRenderer.CELL` 32px grid. The mover already says so
itself at `player.gd:460`: *"don't climb into a ceiling (a tight gap is a wall)"*. Two sessions found this
convincing. I implemented the detection.

**It fired exactly as predicted on 512** — gave up in 27 frames instead of 178, naming the cell. Then
`sweepB` went red on `play-tests`, which had been green in the two sweeps before it:

    · walk to column 34: the opening at (43, 19) is ONE ROW high ... it cannot enter
    ·     from there: own cell open, ahead open, ahead-floor SOLID; on_floor=true, v=(-150.0, 0.0)

**The body was moving at 150 px/s through the opening the predicate had just declared impassable.**
Reverted; the layer re-run alone afterwards: `PASS: friction: cross a jagged tunnel` / `ALL PLAY-GOALS MET`.

What survives: 512 is still a pilot failure and still not a design call — a body stopped on the floor at
zero velocity for 151 frames is a soft-lock however it got there. What does not survive is the mechanism,
and with it the fix. One row of clearance is not sufficient for stuck-ness, so it cannot be the explanation
for 512 either; the same geometry that stops 512 lets the friction pilot through at full walk speed. The
discriminator is dynamic — approach velocity, sub-cell offset, axis resolution order — and nobody has one.

Two general things came out of it. **A source comment states an intent, not the resolved behaviour of the
code around it**, and I quoted `player.gd:460` back to myself as though it were a measurement. And a
mechanism that predicts the case it was built from has predicted nothing; the sweep is what tested it, and
the sweep is the reason the change is not in the tree. Third time in the night that a well-sourced static
story about this walker died on first contact with a measurement — the earlier two were mine.

---

## The corpus control, which killed a flattering number of mine

`SF_CORPUS_ONLY=check_pacing`, eight seeds, at `fafad04`: **5 of 8 red, the same count as before.** Seed
512 read 92% silence / density 3.0 / 10,430 frames at the earlier baseline and 83.47% / 6.58 / 5,016 now.
The session halved and the dead air fell, which looks like the repair improving the worst seed.

It is not. The corpus was re-run with **only the mover line reverted**, same tree otherwise:

    diff of the per-seed numbers, repaired vs control:   IDENTICAL, every seed, every number
    the same five seeds red, the same failing assertions in each

**The repair changes nothing in the corpus.** The improvement belongs to the other tree changes since
that baseline (`check_pacing`'s assertion resolution, `play_agent`'s diagnostics), and the comparison was
never one variable. The control is the only reason that did not enter this document as a claim. A number
is most dangerous when it is moving, and this one was moving in the direction I wanted.

Two things it does establish, and the second matters more than the first:

  - **the repair introduced no new seed failure**, across a population the play-tests do not cover;
  - and a second inference I drew from it and then had to withdraw. See the section below.

---

## Seed 512, closed: it IS the one-row gap, and my exclusion of it was invalid

I wrote, on the strength of the identical corpus, that 512's failure could not be the one-row gap because
it survived a mover that now refuses such gaps. **That inference is wrong and this retracts it.**

A partition probe (c1's design, and it is not a mechanism story: it splits "why is `velocity.x` zero" into
cases and asks which one) printed the same line forty times:

    WHYZERO in=-1.0 vx_in=-28.33 zeroed=true body=(45,26) feet=864.00 | BLOCKER (44,25) ov_x=0.47 ov_y=2.00

Read it: the pilot IS pressing, the input DOES reach the body (`vx_in` is one frame of ACCEL), and the
collision zeroing at `_resolve_axis` fires every frame. Feet at 864 is the top of row 27, so the head sits
at 830, **2px into row 25**. `ov_y = 2.00`. That is the one-row-gap geometry exactly, and the blocker is
named.

**Why the corpus did not move, correctly explained.** The repair changes an outcome only where
`ov_x > ov_y`, that is only for approaches that would have CROSSED. 512's approach latched at
`ov_x = 0.47`, so the old code blocked it too. **512 was already on the pinning side of the coin flip, and
the repair only removes the other side.** Identical numbers were the predicted result, not evidence
against the diagnosis. I read "the repair changed nothing here" as "the gap is not the cause", which does
not follow.

**So c1's original diagnosis of 512 was right**, and what my refutation actually killed was the stronger
claim it was packaged with, that a one-row gap is always impassable. Pre-repair it was not; post-repair it
is; 512 sat in the always-impassable case throughout.

**And the pilot-side predicate is STILL wrong, for a different reason.** The obvious follow-up is to
re-apply the reverted "one-row opening is a wall" check now that the mover guarantees it. Do not. The
round-trip goal still crosses (43,19) post-repair, byte-identically, and the delta probe found no ceiling
block there: that cell reads as a one-row gap in CELLS and is passable in PIXELS. A cell-level predicate
would misfire there exactly as it did before. The honest pilot-side guard is c1's earlier one and it keys
on the trap rather than its shape: **grounded, pushing, `|velocity.x| < 1.0`, sustained for N frames.**
That cannot misfire on a body that is moving, and it needs no geometry at all.

---

## The through-line: `play_agent` reasons in CELLS, the mover reasons in PIXELS

Four geometric stories died tonight, and they are one story. c1's framing, and it is better than the four
retractions it replaces.

    "the walker probes from inside the ground"    cells    refuted by `own cell open`
    the ruler's as-generated terrain              cells    answered the wrong world
    the tight-gap predicate                       cells    broke a passing goal
    the census at (43, 19)                        cells    over-reported by exactly one

The two languages ask different questions about different objects:

    the census asks    is cell (43,18) solid, (43,19) open, (43,20) solid?
    the mover asks     does a 14 x 34 px rectangle at this sub-pixel position overlap a solid cell, and
                       by how much in each axis, at this frame's y, which `_follow_slope` may already
                       have changed before the horizontal resolve ran

**Every geometric claim made in the first language is approximate in the second.** So the census
OVER-REPORTING is its normal behaviour rather than a fault, which is what makes its one hit an upper
bound on the dependent set rather than a member of it. Zero dependents stands, and the (43,19)
disagreement needs no specific mechanism to be expected.

It is also the reason the repair belongs in the mover and not in the pilot. A pilot-side guard would be a
cell-level statement about a pixel-level fact, which is the class of claim that failed four times.

**And the general form, which outlives this bug:** when a defect's incidence is a function of some
parameter, a test that holds that parameter fixed has a PASS RATE, not a verdict. The one-row guard varies
sub-cell phase across four approaches; only one of the four crosses against the unrepaired mover, so three
of the four possible single-approach guards would have certified the defect as absent. See
`[[deterministic-fixture-draws-once]]` in the session memory.

---

## The tell surface, and the screen that could not reach it (`bf9893e`)

A review of the push candidate found two AI tells my own screen had missed, **because my screen's
population was the nine ADDED files and both were in the 49 MODIFIED ones.** A screen scoped to what is
new cannot see a line inserted into something old, and that is the same population error the night kept
producing in other clothes.

**Fifteen comments credited an internal session identifier** (`origin/main` had one). *"Found by c1 in the
CI log for bd2b1d7"*, in `.github/workflows/harness.yml` among others. A reader finds a single author
throughout and no such contributor. Rewritten, all fifteen; the engineering content kept whole and only
the name removed.

**And `check_prose.sh`, the gate written to catch tells, was the last thing in the repo carrying them:**
a banned-word list naming exactly the tokens a reader would look for. Shipping that list publishes its
author's expectation of finding them, which is a stronger signal than any stray word because it is
evidence of intent. The file already excluded itself from its own scan *because* it spelled the literals,
so half the problem had been seen and the wrong half solved.

**The measurement decided the remedy.** Every word on the list occurs zero times in the tracked tree
(control: `harness` returns 13 files), so the only surviving instance of each forbidden word was the line
forbidding it. The list moved to `tools/prose_words.txt`, kept out through `.git/info/exclude`, with
`SF_PROSE_WORDS` to point elsewhere. Mechanism, paths and reporting unchanged; three control legs, one of
which caught a quiet green in the fix itself (151 files read, 0 words tested, reported "clean").

**And then the fix put a worse one where it lasts (`009783e`).** Run in a clone with no list, the layer
exited 0 with no marker and no registry row, so the runner scored a plain PASS. Because the list is
untracked that is not an edge case, **it is the permanent state in CI** — so "107 PASS" included a layer
asserting nothing about the thing it exists for, in the one environment where the tree becomes public. The
message had been fixed and the verdict left lying. Now the layer prints `SKIP: [prose.wide-word-list]` when
declined and `HELD:` when it ran, with an `env` row in the registry; the sweep resolves it
`prose.wide-word-list=ASSERTED` on this machine and would report `PASS*` in CI.

**And verifying somebody else's count of the same vocabulary found a hole in the gate (`e7041fe`).** The
wide sweep matched case-sensitively while the word list's header promised case-insensitive, so `AGENTIC`
walked through a gate that stopped `agentic`. `origin/main` carries exactly that pair in one file, and
only the lowercase one was reachable. Proven live by planting each spelling, fixed, re-controlled. The
discrepancy that led to it was one instance out of four, and rounding it off would have left the hole.

**And asking what the repaired gate actually READS found the bigger half (`da42feb`).** Matching
correctly is not the same as reading everything. The wide sweep's population was an enumerated directory
list, and the narrow sweep reads comment BODIES with a token list carrying none of the eight vendor
words, so the pair read as a cover of the tree and was not one. Measured with a control leg by planting
three lines in `scenes/player.gd`: a listed word in a comment failed (control -- file in population, gate
live), a vendor name in a comment passed, and a listed word in a string literal passed. A third
population had never been opened by either sweep at all: `tests/` (five tracked `.gd` files, 264KB, one
of them 117KB), both git hooks, `project.godot`, `LICENSE`, `.editorconfig`, `.gitignore`. Note which
surface nearly shipped the instance that started all this -- a `print()` banner, runtime output, caught
only because it happened to live under `tools/`.

The repair is `WIDE_PATHS = sorted(_tracked)`, measured at **0 hits across the 58 text files it adds**,
so it hardens the gate and moves no verdict. Making room for it exposed a silent-skip path whose own
comment claimed the file was "not silently counted as clean either" while `continue` did exactly that --
unreachable at 152 curated text files, taken ~250 times a run at 570. Binary is now decided by
inspection, an unreadable tracked file FAILS, every loop exit increments exactly one counter, and the
counters are reconciled against the population (321 + 248 + 1 = 570) with a guard **proven live** by
mutant rather than asserted.

**Still open, and written into the registry row itself:** the protection now lives on the machines that do
not need it and is absent where the artifact becomes public. Salted digests would get both properties;
that is a publication call, priced and left.

**And the surface none of this reaches is the published one — see the section at the foot of this
document.** Commit messages are not tracked files.

---

## The push, priced for THIS branch (a merge into main was recommended and DECLINED)

c1 computed, with `git merge-tree --write-tree` and without touching anything, that pushing
`capture-deafness` over `main` would delete **55 public paths** (`docs/ENGINEERING.md` and 54 curated
screenshots) and would RESURRECT `docs/PRIORITY.md`, 358KB of harness forensics that `main` deliberately
untracked, as an unresolvable modify/delete. They recommended merging that branch into `main`.

**Declined, and not on the merits.** The standing directive is that `main` stays untouched: no commits,
no merges, no pushes, on any branch. A peer session cannot lift that, so the merge is the director's to
authorise, not mine to execute. The analysis is theirs and is filed on their branch as `414d9f1`.

**What I did do is run the same two checks on THIS branch, which nobody had.**

    merge-base with origin/main   bd2b1d7, which IS origin/main: 0 behind, 39 ahead. A fast-forward.
    paths on origin/main absent from HEAD          0     (control: the reverse direction reports 9)
    docs/ENGINEERING.md                            present
    docs/media/moments/                            all 54 present
    PRIORITY / FEEL_GAP / DIRECTOR_BUS / MENU_MATRIX / VISUAL_RECOMMENDATIONS_SURFACE   none tracked
    anything under docs/handoff, docs/tracelog, .claude                                 0 tracked

**Neither hazard exists here.** This branch deletes nothing public and resurrects nothing untracked.
That is a real null, not a free pass: the identical comparison in the other direction returns 9.

**The nine paths a push would add**, so the decision is made on a list rather than a count:

    .github/actions/harness-verdict/action.yml   tools/cap_lib.sh          tools/lock_lib.sh
    tools/check_base_namespace.sh                tools/check_exit_codes.sh tools/harness_verdict.sh
    tools/frontier_corpus.gd                     tools/stand_downs.txt     docs/CONTENT_CATALOG_PLAN.md

Eight are harness, and `tools/prose_words.txt` is deliberately NOT among them: it is excluded, so a clone
gets the gate without the list and the layer says so out loud. The ninth is the only prose that becomes
public: `860172a`, 555 lines, a content-schema
specification. Checked against the resume-piece constraint and it reads as engineering, not process, with
no agent, session or tooling vocabulary in it (its "harness layer" is this project's own word for a test
layer). **Flagged rather than blocked**, because publishing it is a director's call like the rest of the
push.

---

## The next five READY

1. **T1.0b's two OPENING failures** (seeds 20260817 and 512). These are the severe ones and they are not
   pacing problems: the first-automation arc never completes, and the silence and density readings are
   downstream of that. The traces are already in the corpus logs. **The floors are not to be moved**, and
   **the cause IS the one-row gap and the blocker is named**: `BLOCKER (44,25) ov_x=0.47 ov_y=2.00`, the
   body grounded at (45,26) with its head 2px into row 25, the collision zeroing firing every frame while
   the pilot presses. The mover is now correct there (`fafad04`); what remains is the PILOT.
   **`walk_to_column` has two branches, a gap and a wall, and this is neither**, so it holds its direction
   until the budget expires. Adding a third branch that mines the overhead cell was tried and is NOT
   enough: it fires, it works, the body advances exactly one column to (44,26), and then stalls again
   for longer than before (202 frames against 178, dead air 83.91% against 83.47%). Reverted, written up
   in OVERNIGHT_PROGRESS.md. **The next question is what stops it at (44,26)**, and it is a different
   cell from the one already named. **Do not reach for a cell-level "one-row gap" predicate**: the round
   trip still crosses (43,19), the same shape in cells and passable in pixels.
2. **T1.0b itself.** 5 of 8 seeds failed the pacing floors; seed 512 at 92% silence and density 3.0 against
   a floor of 24.0, with 10,086 of its 10,430 frames in the OPENING. That is not a thin world, it is a
   starved opening — the first-automation arc is not seed-robust. `check_pacing` prints the pilot's trace
   on a failed opening, so the failing logs already name which of the nine steps gave up and where the body
   was standing. **The floors are not to be moved.**
3. **The sink at the foot of the trunk** (T1.0's open half). A design fork, so it wants the director — but
   the measurement behind it is done and quoted above.
4. **`check_dig_hitch` on Linux.** No measurement path without the push decision. The prediction is written
   down and unmeasured.
5. **`check_material_grammar`'s variance**, which is the one red on the board and is fully characterised
   above. Reduce the spread; do not move the floor.

Also standing, and neither is mine to resolve: the **push decision**, and the branch **`capture-deafness`**,
which holds several `docs(priority)` corrections that are not ancestors of this branch (`6a652a7`,
`5460b58`, `d4ac1cc`). One of that set was rediscovered here from scratch by opening an unrelated file.
Whoever picks this up should read that branch rather than find a fourth one by luck.

And three director's calls unchanged: the 1-point-resolution printouts elsewhere in the suite, the
pooled-roughness guard, the 45 stale worktrees.

---

## THE ITEM THAT OUTRANKS EVERY OTHER ONE HERE, AND IT IS ALREADY PUBLIC

Everything else in this document is a guard being made honest on a branch nobody can see. This is live.

**25 of the 896 commit messages reachable from `origin/main` carry vendor vocabulary, and four of them
are in subject lines** — the text GitHub renders in the commit list, in blame, and beside every file
(4 subject + 22 body - 1 carrying both = 25):

    7d60177  chore: gitignore local .claude/ agent state
    8c21f6a  docs(trace): A43 - subagent assignments and the 0049 read receipt
    3a66af8  Run the agentic play-tests under the game clock (2x) - faster CI
    8ab284d  harness: agentic play-tests - the harness PLAYS the game to a goal (layer 6)

Nothing has ever scanned a commit message. `.githooks/commit-msg` and `tools/check_trailers.sh` screen
the *form* of a trailer and no vocabulary at all; `check_prose.sh` reads `git ls-files`, and a message is
not a tracked file, so tonight's repair widening it to the whole tree does not reach this either.

**This does not contradict the clean bill on the tree.** `origin/main`'s tree is clean and that was
verified with a positive control. A repository is not its tree. The question that would have caught this
months ago is: *what published surface is not a tracked file?* — messages, tags, branch names, releases,
the Actions tab.

**BLOCKED-DECISION, and it changes the shape of a decision already on your desk.** A pushed message can
only be repaired by a history rewrite, which this run is directed not to perform. The authorised purge is
scoped to *paths*; a filter that removes files does not rewrite messages unless explicitly told to, so as
currently scoped **the purge would leave all 25 intact**. If the rewrite happens, the message callback has
to be part of the same pass — doing it twice means rewriting the history twice.

Forward-looking option, no rewrite needed, deliberately NOT built because it is a design decision:
screen new messages in `.githooks/commit-msg` against `tools/prose_words.txt`, with a harness layer
asserting every commit newer than a baseline. That baseline is a constant that must be *derived* from
the last offending commit, never typed.

How it surfaced: a routine pre-commit trailer audit that should have returned 0 returned 1. The hit was
prose in a body, not a trailer — a false positive for the rule being checked and a true finding about a
surface nobody was checking. Same shape as the count of three-versus-four that started the evening.

### The timing edge, which changes the push decision rather than merely informing it

Raised by c1 and reproduced here independently. The audit above scans the public history; run it against
the *candidate* and the picture is different in kind, not degree:

    origin/main         896 messages    4 SUBJECT + 22 body - 1 both = 25    ALREADY PUSHED
    origin/main..HEAD    43 messages    1 SUBJECT +  4 body - 1 both =  4    NEVER PUBLISHED

The one subject-line occurrence on this branch is `e7041fe` — *the commit that repaired the gate's
blindness to the capitalised spelling, announcing that spelling twice in its own subject.* I reported
that four branch messages carried vocabulary and did not split subject from body, so this did not surface;
it should have. Three of the four are bodies quoting a measurement, which is the bind the word list itself
was moved out of the repository to escape: a record of the rule becomes the last surviving example of it.

**The asymmetry is the whole point.** Those four have never left this machine, so repairing them touches
no published history, invalidates no clone, and breaks no link. The 25 need a rewrite of 896 published
commits, which changes every SHA in the repository.

**Pushing as-is collapses that distinction in one action.** It adds a fifth subject-line occurrence to the
public repository and converts four cheap local repairs into part of an authorised-but-unexecuted rewrite
of published history. That is a fact about ordering, not about the branch's merit, and it wants to be in
front of the decision rather than behind it.

**NOT ACTED ON.** Amending or rebasing unpushed commits is still rewriting history, which this run is
directed not to do on any branch, and "unpushed" is not an exemption a peer can grant. Prepared so the
call is one step rather than a research task:

    e7041fe  SUBJECT  ->  fix(prose): the wide sweep matched one spelling of a listed word, not the other
             body 14-15   the two planted spellings, written as <WORD>/<word> rather than spelled
             body 18-19   "the entry with room to bite later is the two-letter one"
    ddf3c07  body 4       "its token was the plural-anchored form, which cannot match the -ic derivative"
             body 34      "the sweep named all three planted words back"
    480ee08  body 61      "the runtime banner named the process"
    52df6b3  body 47      "the registered layer name named the process"

If the director wants the branch published clean, the repair is `git rebase -i --exec` over 43 unpushed
commits and costs minutes. If the branch is pushed first, the same four lines can only be reached by the
rewrite that is already pending for the other 25, and it should then be one pass and not two.

**Two constraints on the forward guard, one of them c1's.** The baseline commit must be *derived* by
scanning for the last offending commit, never typed — two unrelated literals that must stay ordered is a
shape this repository has already been bitten by. And the guard must screen SUBJECT separately from body:
they are different public surfaces with different repair costs, and one pass/fail over the whole message
hides which fired. My own count of "three subject lines" against a list of four, corrected above, is that
failure in miniature.

**The rest of the non-tree surface, enumerated rather than assumed — and then RETRACTED and re-measured.**
The first pass produced this, and the last sentence of it was the strongest claim in this document:

    tag names                 3 items    0 carrying vocabulary
    annotated tag messages    3 items    0
    remote branch names       2 items    0
    local branch names       57 items    0   (not public, scanned anyway)
    "a complete enumeration of those refs and not a sample, so the null is a cover"   <- WRONG

**It is not a cover, and the reason is tonight's failure again, inside the enumeration written to close
it.** The population was complete. The *instrument* was carried over from the population it was tuned for:

    57 local branch names, scanned with prose_words.txt      ->   0 hits
    57 local branch names, scanned for process vocabulary    ->  41 hits

    by leading token:  worktree 34   agent 4   director 2   overnight 1

`prose_words.txt` carries `agentic`, `subagent`, `sub-agent` and eight vendor names. It has no bare
`agent`, no `director`, no `overnight`, no `autonomous`, no `worktree` — and it correctly should not,
because it screens PROSE, where `agent` is an ordinary English word that would fire on every line about a
test pilot. Pointed at IDENTIFIERS, where those words appear only because of how the work was organised,
the same list is blind by construction. **A complete enumeration scanned with the wrong vocabulary reads
STRONGER than a partial one, because the count is total.** Raised by c1, reproduced here.

**And two of the four rows were the wrong instrument in a second way.** They were measured with
`git branch -r` and `git tag -l`, which read the LOCAL cache. Against the remote:

    git ls-remote --heads origin   ->  1   refs/heads/main         (I reported 2)
    git ls-remote --tags  origin   ->  1   refs/tags/pre-lode      (I scanned 3)

The extra branch row was `refs/remotes/localmain`, an orphan ref left by a removed remote — only `origin`
is configured. The two extra tags are local-only. **The conclusions survive**, because a superset scanned
at 0 covers its subset, but the FRAME did not: I described a local cache as the published surface. To make
a claim about what is published, query the remote — `ls-remote`, never `branch -r`.

**Corrected statement, which is narrower and true.** Of the non-tree published surfaces reachable from
here, commit messages are the only one carrying vocabulary TODAY. Branch names are a **latent** tell that
becomes real only at a branch push, and only for the branch pushed:

    exposure now                      0 of 41 published (ls-remote confirms)
    this candidate's own branch name  overnight/2026-08-20-autonomous

That name is about as legible a process tell as the repository could carry, and it does not require a
reader to know what any of our labels mean. It costs nothing to avoid: **pushing to `main` never publishes
a branch name**, and if a branch push is ever wanted, `git push origin <branch>:<other-name>` renames at
the remote without touching anything local.

**One row of the GitHub-side gap is reachable after all** (c1). The Actions tab renders workflow and job
`name:` fields, and those ARE tracked files — that is exactly the surface finding 42 was about, already
repaired and pushed. The genuinely unreachable remainder is account state: repo description, topics, the
About blurb, releases, and Actions run titles. Those need the director to open the page; no local
instrument either session has can see them.

**A ref screen looked nearly free, and pricing it that way would ship a guard that covers nothing.**
The first version of this paragraph reported "the NARROW prose list (agent, director, peer, harness, ...)
catches 40 of 41". The parenthetical says `...` but the measurement applied **six** of the list's thirteen
tokens, and normalised `-` and `/` to spaces first. Neither choice was stated. Re-run with every frame
named (c1 raised the discrepancy; both numbers are correct in their own frame):

    full 13 tokens, RAW ref name            41 of 41      <- candidate caught by `a date`
    full 13 tokens, separators normalised   40 of 41
    6-token vernacular subset, RAW          40 of 41
    6-token subset, normalised (mine)       40 of 41

**The candidate is caught by `(?<![0-9])20[0-9]{2}-[0-9]{2}-[0-9]{2}` matching its datestamp, not by any
process vocabulary.** `overnight` and `autonomous` are absent from both lists, exactly as stated — but the
count that would be used to price the guard says the opposite of what is true. Rename the branch
`overnight-autonomous`, dropping the date, and a guard built on "41 of 41" goes green on the single name
it exists to catch.

**An accidental catch reads identically to coverage, and it is harder to spot than a blind instrument**,
because it is *right* about every name in the sample. That is what would carry it through review. It also
lands on a build decision rather than a report, which makes it the most expensive shape this failure has
taken tonight.

Note too that my two variants both returned 40 and that agreement was worth nothing: the candidate misses
under the subset for one reason and under normalisation for another, so the result was overdetermined, not
robust. Two paths to the same number is not a replication.

**And the narrow list is the wrong instrument for refs on its own terms.** Its style tokens fire on
ordinary names any project has:

    release/2026-08-21       a date
    hotfix/2026-09-01        a date
    feature/UI-1204-menus    a ticket id

On prose a bare date in a comment really is organisational residue; on identifiers it is noise, and a
screen at that false-positive rate gets muted inside a week, which is how a gate becomes decorative.

**Corrected conclusion, still cheap but for a different reason.** The ref screen wants the process words
*narrowed out* of the prose list rather than the prose list retargeted: `agent`, `director`, `peer`,
`overnight`, `autonomous`, `worktree`, `session`, and none of the style tokens. `overnight` and
`autonomous` are load-bearing, not belt-and-braces. That makes **three vocabularies for three populations**
— prose, identifiers, messages — which is larger than either session assumed and is the real size of the
thing. Not built; recorded so the price is right when someone does.

### One consequence of removing the self-exclusion that touches a decision still open

`tools/prose_words.txt` is untracked, so it is not in `git ls-files` and the sweep never reads it. **If it
were ever tracked, the gate would now fail on it** — it is a file containing all eleven literals, and the
mutant above proves that case exactly: a tracked file carrying a listed word exits 1 and is named.

That interacts with director's call #2, the salted-digest question, and it interacts *asymmetrically*:

    ship the list as plaintext    -> the gate now BLOCKS it
    ship it as salted digests     -> passes, no literals present
    keep it untracked (today)     -> passes, and the check stands down in CI

I did not intend to constrain that choice and I am flagging it rather than leaving it to be discovered as
a mysterious red. It is arguably the correct behaviour — a public denylist naming the words is the exact
thing the externalisation was for — but it is now enforced by a gate rather than decided by a person, and
those are different things. If the director wants plaintext shipping to stay available, `WIDE_SKIP` is
where that exemption goes, and it should be added deliberately with the reason written next to it rather
than rediscovered when the gate goes red.


### Closing count on the gate's own file, measured independently of the gate

    check_prose.sh @ bd2b1d7   origin/main            9657 bytes   0 occurrences
    check_prose.sh @ da42feb   previous candidate    24708 bytes   5
    check_prose.sh @ 53ac136   candidate             26255 bytes   0

    whole tree @ 53ac136       570 tracked = 322 text + 248 binary
                               0 files carrying vocabulary, 0 occurrences

Derived from git objects with an independent enumeration, reader and matcher — deliberately not the
gate's own output, because the gate is the instrument whose blind spot produced the last false clean
bill. A number that would be reported by the thing under test is not evidence about the thing under test.

### Every full sweep from the pipefail repair onward, read from the retained logs

    log              verdict                        exit  RESULT  stand-down ids
    sweepC           106 PASS / 1 FAIL / 0 SKIP     1     yes     6 id(s)
    sweepD           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepE_gated     107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepF           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepG           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepH           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepI           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepJ           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepK           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)
    sweepL           107 PASS / 0 FAIL / 0 SKIP     4     yes     6 id(s)

**Nine greens, D through L, over SEVEN distinct heads.** The one FAIL in the series is sweepC,
diagnosed and fixed as the pipefail defect. The first version of this line said "nine identical greens
across every repair", which is the stronger-sounding claim and the wrong one: **D, E and F all record
head `9894aa9`**, so three of the nine are a repeat on one head, which is a flakiness check and useful,
but a different kind of evidence from nine separate repairs. Raised by c1, reproduced here.

**And the true number of distinct TREES is not recoverable from these artifacts at all.** `head:` is the
commit at run time, and the discipline is sweep-then-commit, so the content under test was uncommitted
and the header recorded no dirty state. Between the D/E/F runs and G, `fafad04` was committed, so at
least one of those three was testing the next commit's pending content while recording the previous
head. **Nine runs, seven distinct heads, somewhere between seven and nine distinct trees, and the
archive cannot close the gap.** Counting distinctness by `head:` is the same off-by-one one level up:
the field being counted is the one just shown to be blind to the content.

Repaired in the runner rather than left as a caveat, since it is cheap and it is the evidence layer
everything else in this document is argued from. Every run now prints what it tested:

    head: 0d8f4be  worktree: clean
    head: 0d8f4be  worktree: 1 file(s) modified, delta 3d4882261d6f

**A units correction while reading these back.** The Completed table above says sweepD carried *"exactly
the 12 registered stand-downs"*. Those are two different quantities and the sentence merges them:

    rows in tools/stand_downs.txt        13 today (12 before prose.wide-word-list was added)
    env ids RESOLVED on a given sweep     6, and it has been 6 for every run in this table

The runner asserts the second, not the first: `stand-downs: exactly the registered ones, 6 id(s)`. A row
of type `always` or `iff:` does not resolve on every run, so the registry count and the run count are not
comparable and should never be quoted as one number.

### All commits on the branch, in order

    fbc0092  fix(harness): a waiter that decided to sweep the lock, then acted after somebody took it
    71d8a8f  fix(worldgen): the frontier richness test measured a total, on a window the field calls neutral
    a694094  ci: make a run say whether it was a run, and give the suite a fourth verdict
    52df6b3  fix(harness): add_excl bought a clean start and nothing else
    65280fd  fix(harness): the paint layer was named for the painter and measured the painter times worldgen
    62f4bb1  fix(save): a restore with no seed opened a world that was not the player's, and saved over it
    480ee08  fix(play): the third rung passed with its own dependency deleted, and paved the ground it crossed
    860172a  docs: make the documentation true from a clean clone, and map what adding one machine costs
    ddf3c07  fix(harness): the prose gate could not see most of the tree, or the word it most needed to catch
    bd5e3ad  fix(harness): the grammar layer aimed a lamp across the seam it was comparing
    028b9fb  refactor(harness): the machine lock protocol had three copies and one file's worth of tests
    a6267f0  feat(harness): a run that measured nothing usable now says so, and cannot say it for free
    a3cde62  fix(harness): the gate against a green over layers that never ran could not be reached from a termi…
    a4a3d8c  fix(harness): the save sentinel, the one guard whose failure costs a person their data, had no time…
    39341f4  fix(harness): the sentence asserting an invariant was what kept the test of that invariant green
    0729de4  fix(harness): a guard whose predicate is thoroughly controlled and whose population is not
    5c8af7b  fix(harness): the summary called four layers four assertion groups, and green was never reachable a…
    dd2e178  fix(harness): my stability control ran the same environment twice, so it controlled nothing that mo…
    9071f63  fix(harness): the registry knew nothing about the job it was in, and half of it could not fail
    aada1ca  docs(harness): the three registry rows c1 read as weakest, escalated with what would settle each
    363ac06  fix(harness): one of the two conditions was read from the gate's shell, under a comment saying othe…
    025fe78  fix(ci): the guard on a locked project rule has been failing from a checkout setting, not from code…
    f513cc8  fix(harness): a sweep killed by a signal recorded HARNESS_EXIT=0
    47c99c7  fix(harness): say NOT A RESULT in words on a signal death, and the control I said did not exist
    82fc4fc  feat(harness): every registered stand-down now says something on every run
    9c51e31  fix(harness): catch a base-class namespace collision before it costs a sweep
    e7c4250  fix(harness): the namespace guard's population floor bound only at total failure
    a68f969  fix(pacing): an assertion printed its value and its bound at a resolution that hid the decision
    7e0d42b  style(scenes): the comment register in three shipped files, and the gate that never ran
    f097834  fix(harness): the layer that checks every layer runs could not see two file types
    5c4a6b5  fix(prose): a ceiling derived from a file that is free to move is not a ceiling
    07fba3a  fix(play): "could not walk two columns across flat ground" is not a diagnosis
    0a2532d  fix(prose): the anchor ratchet did not tighten, which is the defect it was modelled on
    31e6c9c  fix(grammar): a floor of 75.00% that the statistic cannot reach, on a line with no sample size
    9894aa9  fix(harness): a gate check that fails BECAUSE the gate is called
    fafad04  fix(move): a one-row gap was a coin flip, because the ledge test cannot tell up from down
    bf9893e  chore(prose): the repository stops naming its own process
    009783e  fix(prose): a sweep that tests nothing must not report a pass
    e7041fe  fix(prose): the wide sweep read `agentic` and not `AGENTIC`
    da42feb  fix(prose): two sweeps that do not cover the tree, and a skip that counted as clean
    53ac136  fix(prose): the gate excluded itself, and the exemption is where the words went
    0d8f4be  fix(prose): the categorical rule covers 16% of the character it calls categorical

    42 commits since local main cf2e7b2, 45 ahead of origin/main bd2b1d7, 0 behind, true fast-forward.
    Single author teohondascully throughout, 0 co-author or tool-generation trailers on any of them.

### What backs each of those rows, because "read from the retained logs" was too loose

A peer could corroborate only four greens from retained `summary.txt` files and correctly refused to call
that a shortfall. The reason is in `run_harness.sh:723`:

    if [ -n "${SF_LOG_DIR:-}" ]; then DIR="$SF_LOG_DIR"; KEEP_LOGS=1
    else DIR="$(mktemp -d)";          KEEP_LOGS=0; fi

**A clean sweep deletes its own logs; a failing one keeps them.** So the retained set is structurally a
record of FAILURES, and counting greens or streaks from it is invalid in both directions. It cannot show
a green that happened, and its silence is not evidence that one did not.

The series above is therefore backed by two different classes of evidence and the rows are not equal:

    sweep   verdict from            log dir retained
    C..G,I  redirected stdout       no  (clean runs; KEEP_LOGS=0 deleted them)
    H       redirected stdout       no  -- see the collision note below
    J,K,L   stdout AND summary.txt  yes (SF_LOG_DIR was set explicitly)

The stdout captures are the runner's own printed verdict, so they are first-class evidence for the
verdict line; what they cannot offer is the per-layer log dir. J, K and L have both, at
`<session-scratchpad>/sweep{J,K,L}/summary.txt`, and their stdout and directory headers agree on `head:`.

**A NAME COLLISION IN MY OWN EVIDENCE, caught while writing this down.** `sweepH.log` and the directory
`sweepH/` are two different runs that share a stem: the log is the display sweep at `bf9893e` (107/0/0),
the directory is the HEADLESS sweep at `dd2e178` (90 PASS / 0 FAIL / 15 SKIP of 105). The table row is
correct because it was read from the log, but anyone opening `sweepH/` to check it would find a different
run and reasonably conclude the row was fabricated. Same-stem artifacts from different runs are a trap;
the header line inside each file is what settles it, never the filename.

**AND THE RECORDED `head:` IS THE PARENT OF THE COMMIT IT VALIDATED.** Each sweep ran against the working
tree before the commit was made, so:

    sweepJ   head e7041fe   validated the content committed as da42feb
    sweepK   head da42feb   validated the content committed as 53ac136
    sweepL   head 53ac136   validated the content committed as 0d8f4be

Matching a sweep to a commit by its `head:` field mis-attributes by exactly one, and the mis-attribution
is silent because every value in the column is a real commit on this branch. Anything quoting "the sweep
at `<commit>`" needs to say whether it means the head at run time or the content under test.


### The last commit, and why it was made after both sessions had agreed to stop

`84c3b03` repairs the run header, and the reason it was not left as a caveat is worth stating because it
is a distinction the stopping rule needs. "Continued auditing is its own population error" is aimed at
*finding new things*, and it was the right call. **Repairing the instrument the findings are recorded in
is a different act.** A caveat lives in a document the next reader may not have; the header travels with
every run forever. This was the one place where a fix was worth more than a note.

Both branches exercised in situ rather than on extracted logic, because every driver failure tonight
presented as a subject failure:

    head: 84c3b03  worktree: clean                                     (after the commit)
    head: 0d8f4be  worktree: 1 file(s) modified, delta 3d4882261d6f    (sweep M, before it)

Sweep M is the first run in this archive whose header states what it tested rather than where the commit
pointer was standing.

### A peer disclosed cwd drift into this checkout; verified clean, and the cause is structural

Verified by path rather than by cwd, which is the fix the disclosure argues for:

    HEAD 84c3b03 · main cf2e7b2 · origin/main bd2b1d7
    tracked modified 0 · untracked 0 · staged 0 · index/worktree not inverses (no armed blob)
    reflog: 8 entries, all my own commits, nothing unexplained
    no .cp*.sh anywhere; my own mutant temp copies were cleaned

**The drift is not inattention, it is the repository layout.** `git worktree list` reports **48
worktrees, 45 of them nested under `/Users/thondascully/Projects/sinkforge/.claude/worktrees/`** —
inside this checkout's own directory. A peer's tree is a subdirectory of mine. Two `cd ..`s land you in
somebody else's checkout with a valid `.git`, and every `git` command answers confidently about the wrong
tree. A bare `git status` in this repo is a measurement with an unstated frame, and the frame moves
without announcing itself. **Use `git -C <path>` for anything cwd-dependent.**

**Two errors of my own, in the very command that verified the peer's:**

- **My `find` crossed the same boundary in the opposite direction.** It reported 120 "stray artifacts"; 41
  were mine and gitignored, and **79 belonged to other worktrees**. Had I not read the paths I would have
  filed a contamination report about files in someone else's checkout — the mirror of the error I was
  checking, one minute later.
- **My own label could not be false.** The probe printed `(none above = clean)` unconditionally, and it
  printed it directly beneath 120 hits. Skimmed, it reads as a clean bill. A summary line that does not
  depend on the data is the house defect in a single `echo`.

**And the repository had already defended against the first one.** `check_prose.sh` reads `git ls-files`
rather than globbing the filesystem, with a comment saying exactly why: *"a generated `.gd`, a scratch
copy, or anything a worktree left behind under `scenes/` or `src/` would be judged by a gate about what
SHIPS."* That decision was made as hardening, before anyone had measured 45 nested checkouts sitting
under the repository root. Any future filesystem-walking gate here silently ingests 47 other trees.

The stale-worktree cleanup already on the director's list is measured at **48, not 45**.


### A tell removal that took the rule with it, and the only defect of its kind tonight

`ddf3c07` deleted `.claude/` from the shipped `.gitignore`. **Correct on its own terms** — a vendor name
in a file that ships is exactly what the sweep in that same commit exists to catch. It also moved the
function into `.git/info/exclude`, which is local and is not part of a clone:

    origin/main   shipped .gitignore covers the directory
    candidate     it did not; only this machine did

A fresh clone therefore ignored nothing there, and one broad `git add` would have committed a working
directory full of tool state — the precise corpus the scrub exists to keep out. **A two-word tell traded
for a tree that had stopped defending against publishing the whole thing.**

**This is not the coverage-boundary class that accounts for every other defect tonight.** Nothing was out
of population; no instrument was blind. **One line had two jobs**, the edit optimised the visible one, and
the job it carried was invisible until exercised from a clone. Screen, before deleting anything for
presentation reasons: *what else was that line doing?* Config, ignore rules, CI job names, fixture names
and log prefixes all read as text and behave as code.

Repaired at `3cf037c` **by shape rather than by name**, so the fix cannot become the thing it prevents:

    /.*/
    !/.github/
    !/.githooks/

A negation cannot reach *inside* an excluded directory, so exclusion and re-inclusion both sit on the
directory itself. That is what would bite a later rewrite.

Verified from the REF rather than the worktree, in an isolated repo with `core.excludesFile=/dev/null`
and two control legs, then differenced against `origin/main`:

    axis                                    origin/main   3cf037c
    ignores the tool directory                  yes         yes
    ignores an unnamed or future tool dir       NO          yes
    carries a vendor name in a shipped file     YES         no

Better on all three axes named, rather than "strictly better" unqualified.

**How it was found, which is the transferable part.** A peer reported `gitignored: yes` under a `measured`
mark, from `git check-ignore` — which consults the LOCAL rule set including `info/exclude`, so it
described that machine and not the tree. It sat beside a correct "0 tracked files", and that pairing is
what carries a wrong sentence through review: one true number lending its credibility to the one next to
it. **If a claim is about what ships, the command must take a ref.** `check-ignore`, `status`, `diff`,
`ls-files`, `branch -r` and `tag -l` all answer about a configured working copy; only `show <ref>:<path>`,
`ls-tree <ref>` and `ls-remote` answer about the artifact.

### The public count is FIVE, not four, and the fifth is the file this section is about

Raised by c1 from the other side of the same defect, and reproduced here whole-tree from git objects,
every tracked file, no extension filter:

    origin/main (PUBLIC)   561 tracked, 313 text (7 extensionless)   5 occurrence(s) in 4 file(s)
        .gitignore              1x <vendor>
        tools/play_agent.gd     1x agentic
        tools/play_tests.gd     2x agentic
        tools/run_harness.sh    1x agentic

    candidate 3cf037c      570 tracked, 322 text (7 extensionless)   0 occurrence(s)

Both sessions had been reporting **four**. Both had been filtering by extension while describing the
population as "tracked source", and **`.gitignore` has no extension**, so every scan silently dropped it.
I had also never scanned `origin/main` whole-tree for all eleven words — only for one word, scoped to
four directories — and reported the result as though it covered the tree.

**Extensionless files at a repository root are exactly the configuration that decides what ships**:
`.gitignore`, `.editorconfig`, `LICENSE`, the git hooks. A scan that filters by extension is filtering
out the files with the most authority over the artifact.

No conclusion moves — the candidate is 0 either way — but the push now removes **five** occurrences from
the public tree rather than four, and the fifth sits in the file that governs what gets published. That
belongs in the push's favour, not as a footnote.

### The public count is SIX, and the last one was hidden by the care taken to find it

Sequence on this number, each correction adding a file with authority rather than code:

    4 -> 5   .gitignore              no extension; every extension-filtered scan dropped it
    5 -> 6   tools/check_prose.sh    a listed word inside a REGEX LITERAL in its own token list

The second is the mechanism worth keeping. The line reads `(r"\b<word>|\bagents?\b", "agent")`, and the
character before the word is the `b` of `\b` — **a word character** — so every whole-word lookbehind
rejects it. The word was in all three scans' vocabularies the whole time. **The precision was the blind
spot**, and the scan that found it had a quarter of the vocabulary and no anchors.

**Three separately built scans, across two sessions, agreed on a number that was too low.** Each of us
read the other's agreement as corroboration. The rule that covers it, and also covers my two sweep-count
variants both returning 40 earlier: **agreement between instruments is evidence only if they could have
disagreed for the reason being tested.** Independent authorship does not establish that; a different
matching discipline does. Note the direction, too: precision cost recall in the one place where a miss is
silent and a false positive is loud. Both sessions spent care in the direction that hides things.

Repaired: anchors only for tokens short enough to occur inside ordinary English, substrings for the rest.
Verified with a control leg in the same file, which mattered — the first version of the test planted in
`scenes/`, exited 1, and looked like coverage while the vocabulary sweep saw nothing. The narrow rule was
firing on a different token. An accidental catch reads exactly like a catch.

**The length rule is a proxy and its exception is now named in the code.** My first comment claimed longer
names do not occur inside ordinary words; false at nine letters, and a peer found it by testing the
invariant rather than reading it — one message after I had written that a threshold should be a property
and not a number picked to fit. It stays a substring: a short token collides constantly, a long one
collides rarely and LOUDLY, and the word list already makes that exact trade for its two-letter entry.

**Twice while writing that comment the gate went red on the comment itself** — once for spelling the
hidden word, once for spelling the three colliding adjectives. Both correct, both invisible to reading,
both caught only because this file lost its exemption two commits earlier. That is the clearest evidence
the exemption removal was worth its cost.

Public tree: **6 occurrences in 5 files.** Candidate: **0**, verified unfiltered and unanchored across
all 570 tracked paths. The push now removes six rather than four, and two of the six sit in files that
govern what ships.


### The message surface, both trees, at gate discipline — and a partition that did not partition

    origin/main    896 messages   vocabulary: 4 SUBJECT + 21 body = 25
                                  em-dash:  164 in subjects, 1599 in bodies, 1763 total
    candidate       49 messages   vocabulary: 1 SUBJECT +  3 body =  4
                                  em-dash:    0 in subjects,  100 in bodies,  100 total

A peer first reported the public em-dash figure as "164 in subjects, 1763 in bodies". Both numbers were
individually correct; the label was not. **`git log --format=%B` includes the subject line**, so `%s` and
`%B` are not disjoint and cannot be quoted as a partition. Verified mechanically here:

    %s 164   +   %b 1599   =   %B 1763

Caught from the outside with no access to their data, by adding the two published numbers and getting a
third. **The screen is one line: state the total, and check the parts sum to it.** A partition given as
two independent figures invites the reader to add them, and if the sum matches nothing you also stated,
nobody finds out.

Two details worth carrying. The vocabulary row on the same line survived only by granularity — it counts
MESSAGES, which the overlap cannot double-count; had it counted occurrences it would have been wrong the
same way and the numbers are small enough that nobody would have queried them. And **a partition bug is
invisible exactly when one side is zero**, which is why the candidate's figures were unaffected rather
than lucky.

The honest comparison for the director is **the candidate's 0 em-dashes in subjects against 164 already
public**, not its 100 in bodies — subjects being the surface GitHub renders in the commit list.

---

## bb34f01 — the voice pass, and a red that is not ours

**`chore(prose): the token list guards two directories, and the tell was in a third`** — 9 files,
23 insertions, 21 deletions, all comment and note text. No code path changed.

The starting point was one line a peer filed: `tools/stand_downs.txt:72` carried a word naming who
decides, in a file **absent from `origin/main`**, so publishing would have introduced it rather than left
it. What made it worth more than one edit is the cell it sat in:

    NARROW  13 process tokens  ->  scenes/ and src/ only   136 files
    WIDE    11 vendor words    ->  every tracked file      570 files

`tools/` and `docs/` are screened for vendor names and for **nothing else**. Fifteen repairs followed from
censusing the six process tokens that read as a tell in any file, over the 434 paths the narrow sweep
cannot reach, reading every hit rather than sampling.

**The one worth carrying forward is the "the user" split.** Twenty-four occurrences partition 11 / 12 / 1:
eleven mean the human at the keyboard (a cursor a fixture must not warp, Godot's `user://`) and are
untouched; twelve meant the person who **commissioned** the work, which in a solo-authored repository
quietly says the author is not the author. The separating test is reusable: *is "the user" operating the
machine, or ordering the work?* Only the second is a tell.

Also repaired: an invented quote (`.gitignore` attributed to `DECISIONS.md` a rule reading "Never destroy
anything the user made"; the real heading is "Never destroy a curated file", and `DECISIONS.md` is
impersonal throughout), and a rotted worked example in `check_doc_counts.gd` that named three registration
verbs where the runner has four, in the file whose own commentary calls that failure by name.

### Verified

    sweep S   107 PASS / 0 FAIL / 0 SKIP   exit 4   HARNESS_RESULT=yes   6 registered ids   0 load failures
    commit    author teohondascully, 0 trailers, 0 vendor words under BOTH matchers, 0 em-dashes
    main      cf2e7b2 untouched;  origin/main bd2b1d7 untouched;  nothing pushed

### KNOWN RED: invalid assertion, pre-existing, not silenced

Sweep R on this same tree returned `106 PASS / 1 FAIL` on `check_material_grammar`, and sweep S returned
green on the identical tree. **State it in windows, not percent:** every readout is `k/70`, so the layer
scored **52 of 70 where 53 is required**, and 75.00% is 52.5 windows, a value it cannot return. Written as
a percentage a one-window miss reads as a measured shortfall. 4 of 15 samples fall below the floor and
sweep B failed the same way long before this branch.

**This red was already classified before tonight**, on 2026-08-21, with the same conclusion and a pooled
n=16. I re-derived it from zero without checking, which is exactly the capacity the standing directive
says not to spend on an already-classified red. The re-derivation returned one new fact and only one: the
earlier work named machine load as the live candidate for the spread, and my two groups invert its sign
(the contended sweeps were the *tighter* group, 51-54, against 51-56 for the idle box), so **load is not
the mechanism.** That closes a candidate. The rest was rework.
The floor was not moved, no stand-down row was added, and the repair (raise n, or pool across placements)
is left for daylight with TR-02 open. Any verdict quoted from tonight should carry this.

### Deliberately not done

- The word cannot join the wide list: it matches inside `directory` across 37 files, and `check_prose.sh`
  must contain it to function while scanning itself. Closing that cell needs the narrow list held out of
  the tree the way the wide one is, which **enlarges** the open publication question in `stand_downs.txt`
  rather than settling it.
- Two genuinely stale pinned counts (`run_harness.sh:116` says 103 layers where the runner registers 107;
  `check_verdict_claims.gd:23` says 98 where its layer reports 96) are filed, not fixed — a separate
  concern from voice, and four other suspects turned out to be correct with my measurement at fault.

**Correction to the classification above (peer refutation, accepted).** I called it "a bound inside the
quantisation step". Wrong mechanism. Over 15 samples the mean is 53.13 windows with sd 1.36 against a
threshold of 52.5, so `z = -0.47` and a *continuous* version of the same statistic fails 32% of the time;
the four failures are 51, 52, 51, 52, every one below 52.5 as a real number. The step (1 window) is
smaller than the noise (1.36), so quantisation is not what fails the runs — the process mean simply sits
half a standard deviation above the bar. It matters because it picks the repair: quantisation would point
at snapping the floor to a lattice point, which changes nothing, while variance points at raising n or
pooling placements, which is the repair already filed. Right action, wrong stated reason.

**The actual finding was one line in the source, and both of us walked past it for hours.**
`tools/check_material_grammar.gd:93` reads `const READ_FLOOR: float = 0.75 ## the same bar
check_rock_reads holds rock/void to`. **The floor is borrowed from another layer**, with a different
statistic, n and variance. That is the strongest reason not to touch it: the number was never a property
of this measurement, so raising *or* lowering it is unprincipled until it is derived from this layer's own
control. Classified for the release report as **invalid assertion, pre-existing**.

---

## af99f20 — two pinned totals restated as relations

**`chore(harness): two pinned totals restated as the relations they stand for`** — 2 files, comment only.

`run_harness.sh:116` pinned "ALL 103 HARNESS LAYERS PASS over 103 layers" where the runner registers 107.
`check_verdict_claims.gd:23` pinned "30 of 98" and "88 of 98"; measured over the population that layer
actually scans it is **29 of 96 (30%) and 86 of 96 (90%)** — only the totals moved, the argument was never
wrong. Both now state the relation instead of the pair.

The method matters more than the two edits. A peer declined to verify the second one for the right reason:
checking "98" needs a layer count, and the cheap static ways to get one are `git ls-files` or a tree walk,
**the exact pair that had made my own reading wrong an hour earlier**. The answer was to stop counting and
read the gate's own runtime output from a per-layer log already on disk (`the scan actually read the suite
(96 layers)`), then derive over that gate's own population definition — `DirAccess` over `res://tools/`
for `check_*.gd`, skipping its own file, which reconciles 97-on-disk to the 96 it prints.

Every error in that whole thread, mine and the peer's, was a **population** error and none was arithmetic.

    sweep U   107 PASS / 0 FAIL / 0 SKIP   exit 4   HARNESS_RESULT=yes   6 ids   0 load failures

### SECOND KNOWN RED: `check_ceremony_reads` — MY DIAGNOSIS BELOW WAS WRONG, SEE THE CORRECTION AFTER IT

Sweep T returned `106 PASS / 1 FAIL` with **`HARNESS_RESULT=no`** — the verdict refused to be quotable,
correctly, because the failing layer short-circuited before resolving its two registered rows and both
came back UNACCOUNTED. That is the accounting working, not a second defect.

    12 retained sweeps  PASS  waited 146-147 frames, hint 0.00
    sweep T             FAIL  waited 600 (the cap),  hint 1.00
    3 isolated runs on the identical tree   PASS at 146, 147, 147
    re-run (sweep U)                        PASS at 146

**Fifteen samples say the tree is clean and one says the sweep is not.** Unlike the other red this is not
a statistic straddling a bound: a wait that runs out its cap means the exit condition never fired.
Candidate channel, stated as a candidate — `scenes/hints.gd:11` says hint latches persist through a save,
eleven layers touch hints, all 107 share one `user://`, and this layer is `add_gl` rather than `add_excl`.
**Which layer wrote the state is not established and is not guessed at.** The layer was NOT made exclusive
to make the red go away; that changes scheduling for every future sweep and is a daylight decision.

#### CORRECTION — it is a constants defect, not a concurrency one (peer refutation, verified)

**The candidate channel above is wrong and is withdrawn.** Verified from source, not accepted on trust:

    check_ceremony_reads.gd:84   QUIET_MAX    = 600 frames = 10.000 s   (60 Hz; project.godot sets no rate)
    hints.gd:16 / :24            SHOW_SECONDS = 9.0        FADE_OUT = 0.6
    the wait exits on hint_alpha <= 0.01, and alpha = minf(shown/FADE_IN, _life/FADE_OUT)
    so a fired bubble needs _life <= 0.006 -- 8.994 s of decay against a 10.000 s cap

**A 1.006 second launch window.** If the hint fires later than one second into the wait, the loop cannot
mathematically outlast it. Unconditional, provable from source, and needing no rerun.

The greens prove it as well as the red: twelve passes exit at ~146 frames = 2.43 s with `hint 0.00`, and a
fired bubble cannot fade in 2.43 s, so **no bubble fired in any of them.** Sweep T is not a slow run of the
same thing — it is the only run where a hint fired at all. And its `hint 1.00` at the cap requires
`_life >= FADE_OUT`, so the bubble still had 0.6 s left.

Also broken: `MAX_LINGER = SHOW_SECONDS * 3.0` = 27 s = **2.7x the cap**, so the guaranteed-dismissal
bound is unreachable inside the wait; and `hints.gd:216` nests the dismissal test inside
`if _active != &"" and not _ceremony:`, so under a ceremony both clocks stop and dismissal is unbounded —
in a layer named `check_ceremony_reads`.

**Why my candidate was not merely unproven but impossible.** `hints.gd:212` is
`if on and not _was.get(id, false) and not _done.has(id)` — `_done` gates a hint's *firing*, so an
inherited record would SUPPRESS a bubble; the symptom was a bubble that fired, so the sign is backwards.
And the path is closed regardless: `_done` persists only through a save and the layer's only `load(` is
`load(SCENE)`, a PackedScene. I refused to name a writer, which was right, but recorded the channel
anyway — and a "candidate" in a handoff becomes the accepted cause for whoever reads it next. **Before
offering a channel, ask whether it can produce the observed sign and whether the subject can reach it.**

**Classification: invalid assertion, constants — not statistics.** Same verdict word as
`check_material_grammar`, opposite repair: raising n does nothing here. The fix is to derive `QUIET_MAX`
from `SHOW_SECONDS` so it cannot rot, or have the layer dismiss the bubble rather than wait it out. Both
are behaviour changes to a currently-green layer inside a release tranche. **Filed, not fixed.**

**`af99f20`'s commit message carries the superseded diagnosis** — its closing paragraph describes the
ceremony red as reproducing "only inside the parallel sweep" with the hint-latch channel named as the
candidate. That paragraph is wrong in the way corrected above. **It was NOT amended**: the standing rule
for the night forbids history rewriting on any branch, and the tip being unpushed does not make it an
exception. The correction lives here and in the memory; anyone quoting that message should quote this
alongside it. If the branch is later rewritten wholesale for other reasons, that is the moment to fix it.

#### SECOND CORRECTION — two claims in the correction above are themselves wrong

**Retracted: "under a ceremony dismissal is unbounded".** `hints.gd:263` opens `active_alpha()` with
`if _active == &"" or _ceremony or _busy: return 0.0`, and the layer's wait exits on `hint_alpha <= 0.01`.
**A freeze makes the layer PASS, not hang.** The clocks stopping at :216 is real and beside the point —
neither of us asked what the *reader* does with a frozen bubble.

**Weakened: "no bubble fired in any of the twelve greens".** `alpha 0.00` has five readings — no active
hint, ceremony, busy, still fading in, nearly dead — so a bubble that fired and was *hidden* by `_busy`
also reads 0.00. The greens are **consistent with** no bubble, not evidence of it.

**What survives is better, and it is what the ticket needs.** `hints.gd:261`: a frozen bubble *"arrives
with its full life the moment the body settles"*. The freeze **defers** rather than cancels, so the cost
is additive:

    settle, from the greens          146 frames
    visible decay to alpha <= 0.01   540 frames
                                     ---
    required                         686   vs QUIET_MAX 600   short by 86

**`QUIET_MAX` must dominate settle time PLUS `SHOW_SECONDS`, not `SHOW_SECONDS` alone** — a constant
derived only from the bubble's own life would still be wrong. That is the note for the ticket.

**One caveat on the confirming arithmetic, flagged rather than swallowed.** The model puts `_life` at
1.43 s at the cap, giving alpha `= min(30.3, 2.39)` clamped to 1.00, matching the observed value. But
alpha reads exactly 1.00 whenever `_life` is in [0.60, 8.75] — **91% of a visible bubble's span** — so
that match is nearly free and cannot discriminate between firing times. The load-bearing evidence is the
frame count, 686 needed against 600 available. The alpha value is decoration.

**Classification is unchanged: invalid assertion, constants.** Three diagnoses in this thread, two of them
wrong, and the arithmetic underneath never moved.

#### The finding's second, independent leg: a bimodal exit distribution

Running the second half of the screen — *what would the observable read if the mechanism did NOT fire* —
found a discriminator sitting in data already collected. Every run of this assertion prints its exit
frame:

    11 runs at frame 146      5 runs at frame 147      1 run at frame 600 (exactly the cap)
    nothing between 148 and 599, across 17 runs

A bubble must be visible by frame 60 (600 − 540) to clear inside the cap, and the arrival ceremony forces
alpha to 0 until ~146, so a fired bubble is never visible early enough. The model predicts **exactly two
exit values and nothing between**; a "fades slowly under load" rival predicts a spread through the middle,
and none was observed.

So the classification is now **deterministic, not probabilistic**: any bubble that fires during the wait
is a certain failure, and **the layer's pass rate is the bubble's non-fire rate** (~6% firing here). This
predicts a step change in failure rate rather than a drift, which is falsifiable and free to watch.

Both legs of the finding — 686 required against 600 available, and the bimodal exit distribution — are
frame counts. Neither needs the alpha value that three diagnoses were argued over.

#### Final form of the ceremony finding: sized for the maximum, needed the sum

`_ceremony` is set from `_hud.announcing()`, which returns `_arrival_life > 0.0` — **the wait loop's own
first clause** — and `_ceremony` forces `active_alpha()` to 0. So the two sides of the `or` can never both
be true: the layer waits for the arrival plate, then starts waiting for the bubble, whose nine seconds
begin at the frame the first clause clears.

**`QUIET_MAX` bounds a wait over two phases that are sequential, so it must cover their sum. 600 covers a
9 s bubble — it was sized for their maximum.** Same 686-against-600 conclusion, but it names why the
constant is wrong, and it predicts that a repair derived from `SHOW_SECONDS` alone would reproduce the
original error. That is the note for the ticket.

The empty middle in the 17-run table now follows by construction: the ceremony lifting is what *starts*
the bubble's life, so no run can be partway through it. The table confirmed a structural fact rather than
establishing a statistical one.

**And a cheap improvement to the layer regardless of the fix:** three diagnoses were argued over `hint`,
the saturated envelope value, because it is what the failure line prints prominently. `waited` sat in the
same message as a trailing decoration and carried the whole signal. A `_check` message should print the
quantity that discriminates, not the one that is most legible.

---

## CLOSING STATE

    branch          overnight/2026-08-20-autonomous
    started at      cf2e7b2   (local main, untouched all night)
    ended at        af99f20   (48 commits since local main; 51 ahead of origin/main)
    local main      cf2e7b2   UNTOUCHED — no commits, merges, rebases or rewrites
    origin/main     bd2b1d7   UNTOUCHED — nothing pushed
    worktree        clean

Independently verified by the peer session at `af99f20`: 51 ahead / 0 behind, true fast-forward,
`bb34f01` an ancestor, sole author, 0 trailers, 570 tracked files with 0 vendor occurrences, 0 filenames
carrying process vocabulary, 2 process-vocabulary hits both previously cleared and both legitimate.

### Tonight's two commits

    bb34f01  chore(prose): the token list guards two directories, and the tell was in a third
             9 files, 23+/21-, comments and notes only. 15 voice repairs, an invented quote corrected
             against its source, and a rotted worked example naming three registration verbs of four.

    af99f20  chore(harness): two pinned totals restated as the relations they stand for
             2 files, comments only. 103-vs-107 and 30/98-vs-29/96, both restated as relations.

Sweeps run: R (red, classified), S (green, gate met), T (red, classified, RESULT=no), U (green, gate met).
Release gate at the final tree: **107 PASS / 0 FAIL / 0 SKIP, exit 4, HARNESS_RESULT=yes, 6 registered
ids, 0 load failures.**

### Two known reds, both classified, NEITHER quieted

No bound was moved, no stand-down row was added, and nothing was converted to a SKIP for either.

1. **`check_material_grammar`** — invalid assertion, *statistics*. `READ_FLOOR` is borrowed verbatim from
   `check_rock_reads` (`:93`, "the same bar check_rock_reads holds rock/void to") and governs a process
   that clears it ~70% of the time. Repair: derive the floor from this layer's own control. Raising n or
   pooling placements attacks the variance; moving the floor is unprincipled until it is derived.
2. **`check_ceremony_reads`** — invalid assertion, *constants*. `QUIET_MAX` bounds a wait over two phases
   that are sequential (`_ceremony` is assigned from the loop's own first clause and forces the second to
   false), so it owes their sum; 600 covers a 9 s bubble and was sized for their maximum. Repair: derive
   `QUIET_MAX` from settle + `SHOW_SECONDS` — **not from `SHOW_SECONDS` alone, which reproduces the
   original error.** Separately and safely: reorder that layer's failure message to lead with `waited`.

### Next five READY items

1. Reorder `check_ceremony_reads`'s assertion message to lead with `waited` (no behaviour change).
2. Derive `QUIET_MAX` from settle + `SHOW_SECONDS`; derive `READ_FLOOR` from `check_material_grammar`'s
   own control. Both are behaviour changes to green layers and want daylight.
3. Externalise the narrow token list the way the wide one is, which is what would close the
   process-vocabulary gap in `tools/` and `docs/` — **but it enlarges the open publication question in
   `stand_downs.txt:72` rather than settling it, so it follows the director's call on that row, not the
   other way round.**
4. Sweep `tools/`/`docs/` by hand for the commissioner-voice class; the gates cannot see it.
5. Watch `check_material_grammar` and `check_ceremony_reads` failure rates for **step changes**, which is
   what the second one's classification predicts if anything changes what makes the bubble fire.

### The four decisions that remain the director's, none touched

(a) the push itself; (b) the four unpushed commit messages carrying vocabulary, free to repair today and
rewrite-only once pushed; (c) the word list's publication form; (d) whether the categorical em-dash stance
extends past game-code comments.
