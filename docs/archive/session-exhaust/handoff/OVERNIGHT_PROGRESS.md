# Overnight progress — 2026-08-20

Live queue state. Not published: `docs/handoff/` is excluded through `.git/info/exclude` rather than
`.gitignore`, because the ignore file itself ships.

    branch          overnight/2026-08-20-autonomous
    cut from        cf2e7b2
    main            FROZEN at cf2e7b2, unpushed, not committed to since the branch order arrived
    origin/main     bd2b1d7

`f446b26` and `cf2e7b2` had landed on local `main` before the branch order arrived. They stay: removing
them would be the history rewrite the order forbids.

## Commits, in order

| commit | what it closes |
|---|---|
| `fbc0092` | lock: a waiter that decided to sweep, then acted after somebody took it |
| `71d8a8f` | **RED-1** worldgen frontier richness — invalid instrument |
| `a694094` | CI: a run now says whether it was a run; VOID added as a fourth verdict |
| `52df6b3` | `add_excl` bought a clean start and nothing else |
| `65280fd` | **RED-3** texture roughness — invalid instrument |
| `62f4bb1` | save: a restore with no seed opened a world that was not the player's |
| `480ee08` | **RED-4** third rung passed with its dependency deleted, and paved what it crossed |
| `860172a` | docs true from a clean clone; the content-catalog plan |
| `ddf3c07` | the prose gate could not see most of the tree, or the word it most needed |
| `bd5e3ad` | the grammar layer aimed a lamp across the seam it was comparing (PARTIAL) |
| `028b9fb` | the lock protocol had three copies and one file's worth of tests (**D**) |
| `a6267f0` | a run that measured nothing usable now says so, and cannot say it for free |
| `a3cde62` | the gate against a green over layers that never ran was unreachable from a terminal |
| `a4a3d8c` | the save sentinel, the guard whose failure costs real data, had no time bound |
| `39341f4` | the sentence asserting an invariant kept the test of that invariant green |
| `0729de4` | a guard whose predicate is thoroughly controlled and whose population is not |
| `5c8af7b` | the summary called four layers four assertion groups; green was never reachable |
| `dd2e178` | my stability control ran the same environment twice, so it controlled nothing |
| `9071f63` | the registry knew nothing about the job it was in, and half of it could not fail |
| `aada1ca` | the three registry rows c1 read as weakest, escalated with what would settle each |
| `363ac06` | one condition was read from the gate's shell, under a comment saying otherwise |
| `025fe78` | the guard on a locked project rule was failing from a checkout setting, not code |
| `5c8af7b` | the summary called four layers four assertion groups; green was never reachable |

Earlier, on `main` before the branch: `f446b26` (**RED-2**), `cf2e7b2` (lock release-by-owner).

## The four reds — all closed, and every one an instrument fault

Not one of the four turned out to be a defect in the game. That is the headline finding of the night, and
it is uncomfortable rather than reassuring: four gauges were reporting on themselves.

| red | classification | evidence |
|---|---|---|
| RED-1 worldgen | **invalid instrument** | `max()` selected the window the field rates NEUTRAL (mean multiplier 1.02) and totalled ore across windows with unequal rock. Corrected: 12/12 seeds clear the untouched 1.15 floor, worst 1.246x, 3 serial runs identical |
| RED-2 rock/air | **environment contamination** | the layer read the real OS mouse; its sample boundary followed a hand on the desk. 74.32% → 78.67%, 2/5 → 5/5, floor untouched |
| RED-3 texture | **invalid instrument** | measured paint convolved with worldgen; composed slab now. Mutation re-verified locally: 3.67% → 9.53% red, two control arms unmoved |
| RED-4 progression | **invalid instrument, and a fixture that erased its own subject** | at `cf2e7b2` the rung PASSED with the iron chain deleted, printing ALL PLAY-GOALS MET. Verified locally. It also paved the suite's only gated surface crossing |

**No threshold was lowered anywhere.** Every number was recovered by repairing the thing doing the
measuring.

## Three defects nobody had listed

- **`add_excl` never worked.** Peak concurrency **5** where it must be 1, measured on the real runner with
  the sampler proving it observed the exclusive layer alive. Every timing layer's history was taken beside
  up to five other engines, and `check_grapple_reads` going red under load *after* being made exclusive was
  read as flakiness rather than as the scheduler never having done the thing.
- **`godot --script` exits 0 on a missing or unparseable script.** On a fresh clone the runner would print
  ALL 103 HARNESS LAYERS PASS over 103 layers that never ran. Gated in CI; **local runs are still exposed.**
- **A shipped save bug.** `_stage` defaulted `world_seed` to 0 when absent. Absent is not zero — zero is a
  different specific world — so a restore succeeded into a world quietly not the player's, and the next
  save wrote over the only record of which one it was.

## The machine lock, and what C1 caught in it

Two commits, and the second existed because the first was incomplete. Release was not ownership-checked;
then the stale *sweep* had the same fault from the other side. C1 caught the second, and then caught two
more in my fix for it. All accepted:

- **A** — the gc-mutex recovery path repeats the same late-actor failure, guarded by a rename, eleven lines
  under my own comment saying rename cannot tell whose directory it is.
- **B** — a sweeper killed between `mkdir` and its pid write leaves a gc nothing can classify, and the lock
  wedges permanently until a human removes it.
- **C** — the caller logs "clearing a stale lock" before the callee decides, so the message asserts an
  action that often did not happen.
- **D** — the protocol exists as three hand-maintained copies; 19 lines byte-identical today, and the only
  thing keeping them equal is my hand. **This is the next commit.**

I also priced A's residual wrong in the commit message: it needs one hard kill plus ordinary scheduling,
not two kills. The honest claim is the narrowing, not the count.

## Methodology notes worth keeping

Three separate times tonight a measurement returned zero and the zero was about the instrument:

- the lock race: 0/10, then 0/5 with the window widened. Both stagings were symmetric, so both waiters
  swept together, which is the harmless case. It needs one waiter to be LATE.
- the scheduler: peak `0` because I filtered on `--path <root>` and the runner passes `--path .`; then
  peak 5-vs-4 because I measured global concurrency when the claim was about one window.
- the prose gate: 145 files, 0 failures — which is equally consistent with clean and with blind, until a
  planted tell proved it fires.

And one fix that read as correct and measured as nothing: the atomic-rename version of the lock sweep
still put two engines on the box 5 times in 5.

## Open, carried forward

1. ~~**Lock protocol duplication (D)**~~ — **CLOSED** in `028b9fb`. One sourced library, A/B/C fixed inside
   it, and three new structural properties in `check_lock.sh` asserting the protocol lives only there. The
   extraction found a divergence neither review had: `seed_corpus.sh` wrote a TWO-line owner file where the
   other two wrote four, so waiters behind a corpus sweep were told a run was in progress and never told
   what it was.
2. ~~**RED-2 pose sensitivity**~~ — **CLOSED, the pose is not load-bearing.** Four fixed world points, two
   runs each, through a gitignored scratch copy so the shipped layer was never parameterised (scratch since
   deleted). Body `78/77`, `+300,0` `77/78`, `-300,0` `76/76`, `0,-300` `78/78`, against a 75 floor. The
   judged population DOES move with the pose (498–536 solid, 180–194 air) — the pose changes what is
   measured — but every pose clears the floor, so it does not change the verdict. Limits stated: the
   headline prints through `%.0f`, so these are buckets; and four points on one seed samples poses rather
   than proving invariance.
3. ~~**Runner-side VOID**~~ — **CLOSED** in `a6267f0`. `VOID_CODE=43`, its own tally, and the branch placed
   ABOVE the strict branch so a contaminated run cannot be laundered into a skip. `_void_layer` now refuses
   a reason string containing no digit, so a layer cannot void itself without naming a measurement.
4. **A red retired without replacement** — the pooled world roughness (6.53% against a 6.50% ceiling) is
   now printed and asserted by nothing. A population guard belongs in a worldgen layer and there is none.
   Director's call.
5. **The texture instrument is less sensitive than the one it replaces.** A slab reads a quieter quantity;
   the trip point moved from 0.70–1.00 to 1.00–1.60. No ceiling was invented to compensate, deliberately.
6. **`check_prose` backlog** — 3 pre-existing failures at the base: 13 em-dashes in `bazaars.gd`, 176 in
   `visuals.gd`, one comma-density ceiling. Not tonight's, and tonight stopped adding to it.
7. **Commit messages are an ungated public prose surface.** 63 em-dashes across the 60 commits before
   tonight, 25 across tonight's — consistent rate, no anomaly added, exposure real and not rewritable.
8. **Does the prose gate itself ship?** A tool whose stated job is removing authorship fingerprints is one.
   Recorded, not answered.
9. `run_harness.sh` calls the save sentinel through a bare uncapped engine at three sites.
10. Cross-process save equivalence is verified against a fresh *object*, never a fresh *process*.

## Local sweeps are gated now, and the gate was certifying runs it had not read

`a3cde62`. Two findings, one of them c1's, plus two gates that ran in no sweep.

**The known hazard, finally reproduced rather than described.** `godot --script` exits 0 on a missing or
unparseable script. Registering one layer whose script does not exist produced `[ 1/ 1] check_ghost PASS`,
`1 PASS / 0 FAIL`, `HARNESS_EXIT=0` -- and the gate then caught it and the runner exited **7**. The rule
moved from `.github/` to `tools/harness_verdict.sh`; both callers now run that one file.

**The gate scored clean over an empty set.** With no logs present, `n_died` and `n_empty` are both zero,
neither branch fires, and it printed "every layer log carries the output of a layer that executed" --
vacuously true of zero logs, phrased as a verification. Control, same input, both gates:

    gate at HEAD          layer logs: 0 ... this run is a RESULT ... may be quoted     exit 0
    gate with the branch  layer logs: 0 ... NO LAYER LOGS WERE READ                    exit 1

Not live in CI; the coupling that makes it real is the `*.log` glob agreeing with the runner's log naming
across two files by convention. c1's argument for fixing it BEFORE the local reuse was the right call: the
precondition that kept it latent is one log path written once, and that is exactly what a workstation with
worktrees and `SF_LOG_DIR` overrides does not have.

**Two gates that ran in no sweep**, found by the question that found `check_trailers`: which files only
ever execute when a human remembers them? `check_lock.sh` holds the machine lock to 26 properties and was
in neither CI nor a local run. It is registered now through a new `add_excl_hl` -- alone, because it stages
races and a stagger that fails to stage passes over a condition that never happened; headless, because
marking it GL would lie to `check_ci_coverage`, which reads that flag from the runner's own function bodies.

**And one of my own properties could not fail.** `sed '/\*)/,/;;/p'` reads like "that case entry" and is
not: sed seeks the end address from the NEXT line, so when `*)` and `;;` share a line the range runs to end
of file and matched a `bad=1` three branches away. The mutant with `bad=1` deleted PASSED. Rewritten with
awk and re-watched red.

## The save sentinel had no time bound, and two structural guards could not fail

`a4a3d8c`. The watchdog left `with_machine.sh` for `tools/cap_lib.sh`, because the runner needed it and
could not have it: `with_machine.sh` takes the lock the runner is already holding, so a bound living only
in the lock-TAKER is unavailable to the lock-HOLDER.

    GODOT=<stub that never exits>, SF_SENTINEL_CAP=5
    before   forever, holding the machine lock, looking healthy to ps and to elapsed time
    after    exit 2 in 5s, lock released, "it never answered ... nothing here knows its state"

All three verbs verified through the real runner: arm and verify on a normal sweep, disarm by SIGTERM
mid-run. `check_lock`'s existing 26 properties hold the extraction.

**Two of the three new structural properties could not fail when written**, and that is the finding:

- "the watchdog polls rather than sleeping the whole cap" went red on a CORRECT file. `cap_lib.sh`
  explains the hazard by NAMING the bad pattern, and the grep for the bad pattern matched the sentence
  warning against it. The guard read the prose about its subject as its subject.
- "both cap users source the shared watchdog" passed with the source line DELETED, because every caller
  carries a comment naming the library and `grep -q 'cap_lib\.sh'` matched that. **The identical hole is in
  the lock property shipped in `028b9fb`**, so it could never fail either. It looked watched because the
  red observed at the time came from the DUPES assertion printed beside it. Two assertions on one line of
  output are one assertion as far as evidence goes.

Both now match a `.` or `source` line and both were re-watched red by deleting exactly that line and
leaving the comment in place.

## A signal-killed sweep writes `HARNESS_EXIT=0`

Found while testing the disarm path, not yet fixed, and the dangerous half is already closed.
`harness_cleanup` takes `$?` on its first line; when the runner is killed by SIGTERM mid-`wait`, that is
`0`, so the summary records a clean exit for a run that was killed. The new gate catches the consequence
(`no layer rows in the summary at all`, `HARNESS_RESULT=no`), so nothing quotes it as a pass. Two notes for
whoever fixes it: `exit 7` from the EXIT trap does NOT survive a signal death either (bash re-raises, and
the observed status was 143), and the CI gate's existing rule for this case keys on a MISSING
`HARNESS_EXIT` line, which is not what a signal produces here.

## The first full sweep on this head, and what it found

`39341f4`, with a display, 277s.

    103 PASS / 2 FAIL / 0 SKIP of 105 (4 of those passes stood assertions down)
    HARNESS_EXIT=1        layers reported: 105 of 105
    layer logs: 105       engine-level load failures: 0       silent: 0
    HARNESS_RESULT=yes
    FAILED: check_save_isolation, check_doc_counts
    stood assertions down: check_frametime, check_grapple_reads, check_text_contrast, check_ceremony_reads

**Both failures were mine and both were bookkeeping**, closed in `0729de4`; the five affected layers re-run
5 PASS / 0 FAIL. Three things worth not losing to a summary:

**`check_material_grammar` PASSED this run and is NOT fixed.** It is the bimodal layer at mean 74.86
against a 75.00 floor and this run landed on the passing side of the flip. A green from a coin is not a
green. It stays budget-closed and backlogged; do not count it as resolved on the strength of this row.

**`check_save_isolation` failed in the honest direction.** It matched the literal `save_sentinel.gd -- arm`
and the capping commit collapsed those invocations into a helper passing the verb as `"$1"`. Same mechanism
as the four guards that stayed green this week -- a structural guard tracking text that moved -- resolved
the other way. The difference between "annoying red" and "silent green" was only whether the stale text
happened to be prose.

**`check_doc_counts` read 104 where the runner declares 105**, because it named three verbs by hand and
could not see `add_excl_hl`: a guard against stale counts holding a stale count of the things it counts. It
derives them now, and requires every derived verb to have a row in the execution-class table.

    105 = 87 add + 14 add_gl + 3 add_excl + 1 add_excl_hl

## A control on the predicate is not a control on the population

c1's finding, in the same function as the fix for it. The `warp_mouse` ratchet skipped its whole loop if
`DirAccess` returned null and `continue`d past any unreadable file, so `found` stayed empty, `over` stayed
empty, and the budget assertion passed over zero files while printing "0 calls across 0 file(s)". Three
assertions beneath it prove `_is_warp_line` recognises a real call and refuses a comment about one -- all
genuine, all passing, all answering "does my detector work" while nothing answered "did it look at
anything". An assertion counter cannot see the difference.

    control   115 .gd fixtures on disk        the scan reports 115 opened
    mutant    chmod 000 on one                114 opened, and FAIL naming check_aim.gd
    before    the same mutant                 silent continue, PASS

**And `--check-only` verifies syntax, not that the methods named exist.** Twice in two commits: `get_dirs()`
(does not exist) and `[verb] if x else _verbs()` (untyped Array into Array[String]). Both parsed clean, both
threw at runtime, both were caught only by a concrete floor -- and in the second case an assertion about the
SHAPE of the evidence ("`add_excl` has a row in the table") passed over a count of 0, because a row exists
whether the number beside it is 3 or garbage.

## The four stand-downs, read rather than counted

All four PASSES that "stood assertions down" in the 105-layer sweep, from their retained logs. **Three are
correct refusals and one is a real gap with a priced fix.** None is a defect in the game.

**`check_frametime` -- correct, permanent, and already written down.** The 8.33ms (120fps) budget asserts
only when `SF_PERF_HOST` names the machine, and it is set nowhere. The file says so itself at line 349:
"SF_PERF_HOST was unset everywhere for the whole life of the code". That is the layer refusing to make a
timing claim on arbitrary hardware, which is the correct behaviour and not an oversight. **Nothing is
owed.** Anyone who wants the budget live must name a quiet controlled box.

**`check_grapple_reads` -- correctly disqualified.** GR-05's share of the throw the preview inks measures
0.22 and is unasserted, because the cap that used to stand there was 1.01 over a quantity `_corridor_fill`
bounds at 1.0 BY CONSTRUCTION: an assertion that could not fail. Removing it was right; what is owed is a
design decision, not a guessed bound.

**`check_ceremony_reads` -- two, both waiting on a decision, both refusing to guess.** The arm now carries
a drift floor measured inside its own run, so the reading finally has something in its own units to be a
ratio against; the missing piece is the distribution across several runs. Its own words: a bound argued
from the first one "has been wrong four times in this repository".

**`check_text_contrast` -- one lane boundary, one REAL gap.** The bright-backdrop column belongs to the
renderer and this layer's lane is the palette; fine. The second is not: the wash tiles
(`Color(1, 1, 1, 0.022...0.062)` over the modal) and the picked row's brass are **literals in the drawing
code rather than named constants, so no row here can reference them.** They were measured by hand once,
cleared, and nothing re-measures them on the next edit -- the worst was a cost shortfall at 4.20 on the
picked row's brass. This is the constant-nobody-can-name shape.

    priced by the layer itself: ten drawing sites would have to move to constants

That is shipped drawing code with visual risk, so it is recorded as a decision rather than done
unattended. It is the only one of the four that converts into an assertion rather than a design call.

## THE RELEASE GATE, DECIDED: exit 4 with exactly these stand-downs

**`0729de4` full sweep, with a display: 105 PASS / 0 FAIL / 0 SKIP of 105, HARNESS_EXIT=4, 281s,
HARNESS_RESULT=yes.** c1 predicted the 4 before it ran, from `run_harness.sh:118` -- "1 MASKS 4 ... the day
the failure is fixed it will record a green that was never full". Today was that day: the two failures were
masking the four stand-downs and fixing them unmasked exactly those four.

**Exit 0 is not reachable on a full sweep with a display, now or later.** All four stand-downs are
structural, and read rather than counted they are this repository's own lessons applied correctly. So
"the full sweep is green" is a gate that can only be met by deleting an honest stand-down or inventing a
bound nobody earned, and both are worse than the sweep is today.

    THE TARGET IS: exit 4, with exactly these stand-downs and no others.

Asserted now, not merely written down: `tools/stand_downs.txt` registers each with the reason it carries no
bound, and `tools/harness_verdict.sh` checks it -- the only thing in the system that reads every layer's
log at once. Subset runs are exempt, since SF_ONLY makes the mismatch legitimate.

## Four layers, six stand-downs, and the summary said four groups

`partial` increments once per LAYER and was printed as "$partial assertion group(s) skipped". `nskip`, the
per-layer count, is computed, shown in the per-layer row, and totalled nowhere. So the sweep reported how
many layers stood down at least one assertion under the name of how many assertions were stood down --
in the single sentence that goes into release evidence. `partial_groups` exists now.

    frametime 1   grapple_reads 1   ceremony_reads 2   text_contrast 2   = 6, reported as 4

## The registry's first draft was a licence, and I had just written the warning against it

I keyed it on the layer and defended that on robustness: frametime has two SKIP sites and fires one, so an
exact count "would go red on a run that stood down LESS". c1 took it apart. **A per-layer registry is green
when a listed layer goes from 2 stand-downs to 5, and green when a DIFFERENT assertion inside it is stood
down -- it authorises unlimited stand-downs inside the four layers it names.** That is the licence shape I
had described to c1 two messages earlier, using the warp ratchet at seven-against-zero as the example, and
then wrote into the body of a file whose header carries the warning.

**Going red on a run that stood down FEWER is correct**: it means an assertion is now being made and the
list must be tightened to say so.

And the robustness worry was testable in one command against logs already on disk:

    39341f4   frametime=1  grapple_reads=1  ceremony_reads=2  text_contrast=2
    0729de4   frametime=1  grapple_reads=1  ceremony_reads=2  text_contrast=2

Identical, while the measurement inside grapple_reads moved 0.22 to 0.26. Third time this week the answer
was in a retained log directory and I reasoned instead of grepping.

Keyed on `(layer, count)`, watched red three ways against the real sweep logs: an unregistered layer
standing down; a registered layer standing down fewer; and the registry's tabs flattened, which parses to
zero rows and would otherwise agree with a sweep that stood nothing down -- the empty-set-agrees-with-
empty-set failure this gate exists to refuse one level up.

**Not keyed on WHICH assertion.** A layer swapping one of its two is invisible. Closing that needs
`_stand_down()` to carry a stable id, owed alongside making `_stand_down()` the only way to produce the
line -- `check_frametime` prints `SKIP:` by hand, so the whole tally rests on a text convention holding
across 105 layers, in a suite where four guards in one week were defeated by text matching.

## The registry would have failed CI's headless job, and told the wrong story about why

Found by c1 from the job matrix, **confirmed here by running the sweep headless rather than accepting the
read**. The headless CI job sets no selector, so it is not a SUBSET run and the registry fires -- but three
of the four registered layers need a display and whole-layer SKIP there. `${_got:-0}` then scored "never
ran" as "ran and stood down zero":

    !! THE STAND-DOWNS ARE NOT THE REGISTERED ONES
       check_frametime(got 0, want >=1)  check_grapple_reads(got 0, want 1)
       check_ceremony_reads(got 0, want 2)  check_dig_hitch:1(NOT REGISTERED)
    HARNESS_RESULT=no   ->  runner exits 7

A missing measurement read as a measured zero -- the same root as the zero-log finding and the walker that
never descended, surfacing as a loud WRONG red rather than a quiet green, which is luckier and not better.
Worse than a plain red: the recommended response is to tighten the registry, and tightening it to match
the headless job would delete three real entries from the release gate.

**AND THERE WAS A FIFTH STAND-DOWN NEITHER OF US KNEW EXISTED.** `check_dig_hitch` stands down
`byte-identity` ONLY headless -- the dummy driver returns a blank image, so the comparison cannot fail and
asserting it would be a lie. It has printed that line since before tonight. **A registry built entirely
from display runs did not know one of its own members existed**, and no amount of reading the registry's
logic could have found it. Two full sweeps had felt like coverage; they were one condition sampled twice.

## The stand-downs now carry stable ids, and the helper is the only way to produce one

`_stand_down(id, what, why)` prints `SKIP: [id] ...`, prefix unchanged so both counters still see the line,
and it refuses an empty id the same way `_void_layer` refuses a reason with no number. Every hand-printed
`SKIP:` in the tree is converted -- `check_frametime` x2, `check_dig_hitch`, `check_save_durability` --
so there are none left outside the helper.

    tools/stand_downs.txt      <id>  <layer>  <always|env>  <reason>

    an id fires that is not listed                   RED
    an `always` id is absent and its layer RAN       RED
    a registered layer did not run at all            EXEMPT, and NAMED

It lists **every** possible stand-down, not only the ones observed firing, so the file is the complete list
of assertions this suite may decline to make. Twelve ids across seven layers.

**And c1's naming rule caught a bug in my implementation of c1's naming rule.** My first version built the
absent list only from rows marked `always`, so `check_frametime` -- both of whose entries are `env` -- was
exempted SILENTLY. It would have stopped running one day with no line anywhere saying so, which is the
licence the naming exists to prevent. Every registered layer is now tested for having run.

The `env`/`always` split also dissolves the `>=1` hack: switching `SF_PERF_HOST` on moves set membership
between two named things rather than moving an integer nobody can interpret.

**Softest part, flagged for review:** six ids are marked `env` because their conditions did not hold on the
runs available, and four of those have never been seen to fire --
`grapple.gr03-single-frame-bow`, `ceremony.words-vs-sky-arm`, `save-durability.failed-backup`,
`bindings.file-order-control`. If any is really `always` under a condition not yet run, the registry is
over-permissive.

## `env` rows could not fail, inside the registry built to stop assertions going missing

c1's finding, verified in my own code before acting: `[ "$_kind" = "always" ] || continue` skips env rows
from the only presence check, and the registration check passes anything listed. **Two places an env row
could be tested, neither tests it. Six of twelve rows were a comment with a tab in it.** The specific loss
is a conditional stand-down that silently becomes permanent -- a real assertion going missing, invisibly,
which is the one thing this file exists to catch.

Both halves of the fix are in. Rows whose condition can be STATED are now `iff:<cond>` and fail both ways;
the rest are reported when they fire, which costs nothing and is how the headless-only dig-hitch id would
have surfaced months earlier.

    frametime.absolute-budget   iff:perf-host-unset      M8 absent+unset RED   M9 fires+set RED
    dig-hitch.byte-identity     iff:no-display           M7 absent headless RED   M6 fires with display RED
    the other four              env, reported            M10 green, id named

**That the remaining rows resist a condition is the sorting function**, not a shortcoming: they are the
suspicious ones, and saying so turns the `env` list from an excuse into a work queue.

**M6 also caught a bug that exists only on the error path.** A backtick inside a double-quoted `note`
executed as a command, so the diagnosis printed `always: command not found` into the middle of its own
explanation. Four green runs never touched it. A message that renders only when something is wrong is code
that runs only when nobody is checking.

## The three weakest rows, escalated rather than quietly kept

1. **`save-durability.failed-backup` -- HIGHEST STAKES, UNMEASURED WHERE IT MATTERS.** It gates the forcing
   function for the whole failed-backup path. On macOS `copy_absolute` fails onto a directory, so the path
   IS exercised and this never fires. **It has never run on Linux**, and `check_save_durability` is a plain
   `add`, so CI executes it there with different filesystem semantics. If `copy_absolute` behaves
   differently, the backup-abort assertions stop being made in CI permanently, silently, green -- in the
   guard whose failure costs a person their data. **The id refactor made it answerable**: grep the first
   Linux job log for `[save-durability.failed-backup]`. Present -> the path is unexercised there and wants
   a platform-independent forcing function, not a registry row. Absent -> the platforms agree, delete the
   row. **Nothing should be called release evidence with this open.**
2. **`bindings.file-order-control` -- mislabelled.** Its condition is deterministic per engine build, so
   `env` is describing a coin that is actually a constant. It will always fire or never fire on a given
   version. Today it never fires and the precedence control works; one engine update and that control is
   permanently dead with nothing saying so.
3. **`grapple.gr03-single-frame-bow` -- probably not a stand-down at all.** It fires on instrument
   saturation, which is this repository's definition of VOID almost word for word. A stand-down says a
   design decision is owed; a VOID says the sample is spoiled, run it again. Opposite responses. Left
   as-is: changing a layer's verdict semantics is a decision, not a cleanup, and it has never fired.

## The coarse-headline class, measured

c1's `%.0f`-against-0.14-points observation, generalised and counted rather than argued:

    83 coarse percentage prints across 24 layers
    33 lines print a value AND a bound at the same 1-point resolution

The second number is the actionable subset, and the shape is exactly the `check_material_grammar` defect
already fixed twice in this repo (there, and in `check_texture`):

    check_underground.gd:124   "%d/%d lit tiles dead (%.0f%%, cap %.0f%%)"
    check_contact_edge.gd:367  "...distinguishable from rock's own texture — %.0f%% (floor %.0f%%)"

**A value of 74.86 against a floor of 75.00 prints as "75% (floor 75%)".** The assertion is correct -- it
compares full-precision floats -- so this is not a wrong verdict. It is evidence that cannot show its own
margin, in the line a human reads and quotes. Not every one of the 33 is this shape; some are two
unrelated percentages.

Recorded rather than swept: the fix is per-line judgement about which number is a value and which is its
bound, and the precedent for it (`%.0f` -> `%.2f` on the comparison line only) is already set in two files.

## One `iff:` condition read the gate's shell, not the run

    iff:no-display        grep -q 'NO DISPLAY' "$SUM"      the RUN being judged
    iff:perf-host-unset   [ -z "${SF_PERF_HOST:-}" ]       THE GATE'S OWN SHELL

    # The conditions an `iff:` row may name. Read from the run rather than from a layer's prose.

True of the first, false of the second, comment directly above both. The runner records NO DISPLAY at :933
and recorded NOTHING about SF_PERF_HOST -- one comment at :488 and nothing else -- so the gate read its own
environment because that was the only place the information existed. c1's finding.

Locally the frames agree (the gate runs from the EXIT trap in the same shell). In CI they need not: the
harness is one step with its own `env:` and the gate is a separate composite-action step, and step-level
`env:` does not propagate. **Controlled against the previous gate rather than argued** -- same input, run
says `SF_PERF_HOST=m4max-16in`, budget correctly absent, gate shell unset:

    gate at HEAD   !! frametime.absolute-budget(SF_PERF_HOST unset ... so it MUST stand down)   RED
    fixed          stand-downs: exactly the registered ones                                     green

Fixed in the RUNNER: `perf-host=<name|unset>` goes in the header, the gate reads `$SUM`. Both conditions
now come from the run. It also makes the retained archive interpretable -- a historical frame-budget number
was previously silently ambiguous about whether the budget was even switched on.

**Absent is not unset**: a summary predating the token reports NOT CHECKED and is named. Third place this
gate has had to separate "no measurement" from "a measurement of zero".

**A MUTANT INHERITS THE TOPOLOGY OF THE RUN THAT HOSTS IT.** c1's formulation, and it explains three
findings on this branch with one mechanism: M1-M13 all execute inside the topology under test, so the
topology is the one variable a mutant cannot hold wrong. Two display sweeps could not see a headless-only
stand-down; setting SF_PERF_HOST locally sets it for both halves at once. **Three findings where the
untested axis was the environment, twice on this same variable.** The practical form: when a fix concerns
WHERE something is read from, no mutant in the current topology can test it -- only a run in a different
topology, or a control against the previous implementation.

## A category: error paths are code with no coverage by construction

The backtick bug in `note` would first have executed on the day something real broke, in the middle of
explaining what. Four green runs never touched it; M6 found it only by routing through the failure branch.
Every diagnosis string, `printerr` branch, and `else` arm of a guard that has never failed is in this
category. Not chased tonight. c1's cheap first pass, recorded: error paths that are STRINGS can be rendered
unconditionally in a test without side effects.

## CI on main is red, and what my branch does and does not fix

c1 read CI run `32448201825` on `origin/main` (`bd2b1d7`); every claim below re-verified here with
`gh run view`.

    headless   83 PASS / 5 FAIL / 15 SKIP of 103
    pixels     15 PASS / 1 FAIL of 16

    worldgen frontier richness 1.13x            FIXED on this branch   71d8a8f
    check_texture roughness 6.53% vs 6.50%      FIXED                  65280fd
    play-tests RUNG 3, the L2 iron chain        FIXED                  480ee08
    check_trailers "shallow clone"              FIXED                  025fe78
    check_dig_hitch bulk slower than per-cell   NOT FIXED, see below
    check_grapple_reads 2 saturation FAILs      NOT FIXED, environment-reachable

**Three of the fixes line up exactly with what CI was complaining about, which is real confirmation the
night targeted the right things -- but nothing on this branch has ever run in CI.** 22 commits, none
pushed. Treat "these are fixed" as a PREDICTION until a run exists. c1's framing and it is correct,
especially given how many times tonight the untested axis turned out to be the environment.

## `check_dig_hitch`: a real platform finding, and the fix would be the forbidden move

    _check(bulk_us <= full_us, "handing the fine grid over whole is not SLOWER than reading it a cell
                                at a time (%.2f vs %.2f ms)")
    CI (Linux): 2585.38 vs 2172.20 ms -- the bulk path is ~19% SLOWER

**I checked the obvious instrument fault and it is not there.** My hypothesis was that `bulk_us` might be
a single sample while `full_us` is best-of-N, which would bias the comparison; both are `mini()` over
`TIME_SAMPLES=3`. The comparison is symmetric, within one run, on one machine -- a well-posed control.

So this is a genuine platform-dependent result: on Linux with the software stack, `PackedByteArray` bulk
transfer of the fine grid is really slower than the per-cell Callable path, and on macOS it is not. It
passes here headless, so it is not headless-vs-display either.

**What must NOT happen: adding tolerance to make it green.** The assertion is a strict `<=` with zero
slack, which is arguably the wrong shape for a wall-clock comparison -- but "the bound has no tolerance" is
an argument for re-deriving the property, not for widening it until the red goes away, and the standing
rule is that a red may not be made to disappear by moving a bound. The legitimate next step is to find out
whether the bulk path IS slower on Linux, which is a finding about the code and worth having either way.

## BACKLOG — `check_material_grammar`, closed against the red budget

**Director's rule, applied here:** a red may consume autonomous capacity only while it is producing new
causal information. This one has been instrument-corrected (`bd5e3ad`, pointer pose) and independently
classified. It is a recorded backlog item from here, not a prerequisite. **No further engine cycles were
spent on it**, including the one-run discriminating test below, which is written down for whoever picks
it up rather than executed.

    status      PARTIAL, red and open
    reading     mean 74.86 against a 75.00 floor, margin 0.14
    shape       flips between exactly two values across five runs

**C1's mechanism analysis, accepted, and it overturns the suspect I recorded.** I named
`scenes/main.gd:685,690` — the camera lead easing on a wall-clock delta. **An ease is continuous and
predicts a continuum, not two values.** The observed bimodality contradicts the suspect I wrote down. Two
mechanisms that DO predict two values sit within five lines of it, both confirmed present in the tree:

    main.gd:687    if _cam_pos.distance_to(target) > VIEWPORT.x / _current_zoom() * 0.5:
                       _cam_pos = target                        # SNAP
                   else:
                       _cam_pos = _cam_pos.lerp(target, ...)    # EASE          <- a binary branch
    main.gd:2212   return (world_pos * zoom).round() / zoom     # snap_to_pixel
    main.gd:691    _camera.global_position = snap_to_pixel(...) # applied every frame  <- a quantizer

`.round()` on the camera means sub-pixel jitter straddling a `.5` boundary shifts the whole frame one
pixel, and a layer sampling a LEFT half against a RIGHT half then re-samples every point one pixel over —
two outcomes, on either side of one rounding boundary.

**The discriminating test, unexecuted, one run:** log `_cam_pos` and its snapped result at capture on each
of the five runs. Five distinct values means the ease. Two means the branch or the quantizer.

**The fixes are not interchangeable**, which is why the test comes first: pinning the delta repairs an ease
and does nothing for a quantizer, since the camera still lands where it lands and then rounds. If the delta
is pinned and the flip persists, that is not evidence the camera is innocent.

**And note the class.** A fixture measuring an unpinned continuous input, in a layer that also had no
pointer pose — the same fault as `f446b26`, twice in one file. The camera wants precisely the seam
`Controls.pose_pointer()` already is. That is likely the shape of the fix rather than chasing the delta.

## Next five READY

1. **Read the sweep at `5c8af7b`** -- the release evidence, with the corrected summary line and the
   registry live. Expect exit 4, six groups across four layers, "exactly the 4 registered".
2. **`_stand_down()` as the only way to produce a `SKIP:` line, carrying a stable id.** Closes the two
   things the registry cannot see: which assertion was stood down, and a layer printing the line by hand.
3. **`HARNESS_EXIT=0` on a signal-killed sweep.** `exit 7` from an EXIT trap does not survive a signal
   death either (bash re-raises; observed 143), and the CI rule for "killed outright" keys on a MISSING
   `HARNESS_EXIT` line, which is not what this produces.
4. **`check_text_contrast`'s ten drawing sites** -- the wash tiles and the picked row's brass are literals
   the layer cannot name. The only one of the four stand-downs that converts into an assertion rather than
   a design call. Shipped drawing code, so it wants a deliberate pass, not an unattended one.
5. **`%.0f` headlines against 0.14-point decisions**, and **the pooled-roughness guard** (6.53% against a
   6.50% ceiling, printed and asserted by nothing). Both director's calls.

---

## `HARNESS_EXIT=0` on a signal-killed sweep — COMPLETE (`f513cc8`)

    item        READY 3 from the last handoff
    status      COMPLETE
    class       instrument defect (the runner recorded a number that was false)
    commit      f513cc8

`harness_cleanup` takes `$?` on its first line. That is the correct way to capture a normal exit, and it
is **0** when the shell is cut down by a signal while blocked in `wait` — so a sweep SIGTERMed at layer 30
wrote `HARNESS_EXIT=0` into its own summary. The sweep archive is a regression history read by grep, and
that grep would have counted a killed run as a clean one.

Fix: `trap 'exit 130' INT` and `trap 'exit 143' TERM` in the runner, both codes documented in its exit
table, both added to `harness_verdict.sh` as `bad=1`. `check_exit_codes` derives its two lists from those
two files, so it picked the codes up with no edit of its own — **PASS (11 codes, 6 asserted)**.

**Evidence, two measurements with one variable each:**

    the real runner, SIGTERMed mid-sweep     exit=143, HARNESS_EXIT=143, sentinel disarmed, lock released
    the mechanism, both legs in one script   traps off -> recorded 0;  traps on -> recorded 143

The second is a control on the **mechanism**, not on the population: a nine-line script with the same trap
shape, not this runner. What it rules out is "bash was already propagating 143 and something else swallowed
it". There is no in-population control leg, because the population is a ten-minute sweep; one stashed
attempt at it was **inconclusive and is recorded as inconclusive**, not as a pass.

**Argued omission, flagged rather than buried:** the gate is not consulted for 130/143. `exit` from inside
the EXIT trap does not survive a signal death — bash re-raises, and the observed status was 143 regardless
of the trap's own `exit 7` — so the gate's exit-7 override would replace the signal's own status with a
vaguer one. The gate already catches the consequence of a killed run (no layer rows -> `HARNESS_RESULT=no`).

## Push the branch and read CI — BLOCKED-DECISION, and not "not got to yet"

    item        READY 1 from the last handoff
    status      BLOCKED-DECISION (director)
    blocker     publishing to a public tree is not an autonomous action

Pushing `overnight/2026-08-20-autonomous` would publish 23 commits of harness-forensics prose to a public
repository the user keeps as a resume piece, while an authorized-but-unexecuted plan exists to purge
exactly that corpus from the public tree, and while `origin/main`'s `harness.yml` still carries the `AI`
tell in two CI job `name:` fields that render on the Actions tab. Publishing more of it overnight moves
against the standing constraint rather than with it. **Director's call.**

**Consequence, recorded so it is not rediscovered:** READY 2 (`check_dig_hitch` on Linux) has no
measurement path tonight. The prediction stands written down and unmeasured; the local number cannot
answer it, because the claim is about the other platform.

---

## Three-valued stand-down accounting — COMPLETE (`82fc4fc`, `9c51e31`)

    item        READY 4 from the last handoff (the remaining `env` rows)
    status      COMPLETE
    class       invalid instrument (half the registry could not fail in either direction)
    commits     82fc4fc, 9c51e31
    evidence    full sweep: 105 PASS / 0 FAIL / 0 SKIP, exit 4, 0 load failures, HARNESS_RESULT=yes

`iff:` was the wrong generalisation and only two rows ever fit it: it reaches conditions the GATE can read
out of summary.txt, and most rows have conditions only the LAYER knows. Replaced by accounting, with
`iff:` kept for the two it does fit, because the two assert different things — accounting says every row
spoke, `iff:` says what it must have said.

    SKIP:      [id]   available and DECLINED       a design decision is owed
    HELD:      [id]   MADE this run                the debt is paid here; tighten the list
    UNREACHED: [id]   control flow never arrived   intact; this box cannot exercise it

**The third state is derived by the GATE, not emitted at the site**, and that is the whole trick — c1
caught the site-emitted version before it shipped. A branch that is not taken cannot announce that it was
not taken, so a third state written at the site is absence again wearing a new label. `_not_reached()`
survives only as an optional annotation from a branch that DOES run, about a sibling it knows will not be.

**Where the hook could not live, measured rather than assumed.** The first version derived it in
`_verdict()`, which reads as universal and is not: of 86 layers inheriting `check_base.gd`, **29 call
`_verdict()` and 57 print their own line and quit** — including three of the seven layers that own rows.
The accounting was invisible to all three on its first run, which is how the number came to be counted.

**All twelve rows resolved on the real sweep:** 6 declined, 5 asserted, 1 out of reach. And the
environment split is now visible instead of inferred — `grapple.gr03-single-frame-bow` reports ASSERTED on
this machine and stands down on CI's software rasteriser, which is exactly what the registry existed to
record and could not.

### The collision it cost, and the gate that now catches it

Adding `_asserted()` to the base broke `check_hint_gate.gd` (`var _asserted`, weeks old). GDScript rejects
the SUBCLASS, so `--check-only` on the edited file was clean, `godot --script` exited 0 on the load
failure, and **the runner scored the broken layer 105 PASS / 0 FAIL**. Only the verdict gate caught it, by
reading the log rather than the code, 275 seconds in.

`tools/check_base_namespace.sh` (new, called from pre-commit) is a pure-text check over the base
namespace, graded against the engine on six cases including two that must be ACCEPTED. Parse-checking all
103 subclasses afterwards found one more: `_scratch_ceremony_knockout.gd` has been unloadable since
`_stand_down` gained its id — untracked and unregistered, so nothing ever noticed.

**A defect inside my own control, recorded because it is the night's theme:** I graded the engine's
verdict by grepping for `already exists in parent class`, and the func-over-var case says `Member "x" is
not a function` instead, so the control reported my check as WRONG when the check was right and the
control's predicate was too narrow.

### `grapple.gr03` — NOT decided tonight, and c1 withdrew the argument for VOID

c1 proposed VOID (saturation = spoiled sample) and then retracted it on the CI evidence: **the saturation
is deterministic on xvfb** — every run, stable numbers — so re-running produces the identical result and
the one action VOID exists to recommend cannot help. Independently of the standing rule about never
converting a red, VOID is the wrong classification on its own terms. And 0.4624 exceeds `SAG_CAP` at 0.42,
the maximum hang the renderer can DRAW, so the mask is reliably picking up something that cannot be the
rope on software Vulkan. **The red is doing its job.** Left red, with the numbers, for the director.

---

## The prose gate, the two orphaned shell gates, and T1.0b re-measured

    commits     a68f969  7e0d42b  f097834  5c4a6b5  07fba3a
    status      COMPLETE (gate), COMPLETE (scrub), COMPLETE (registration), PARTIAL (T1.0b)
    evidence    full sweep 107 PASS / 0 FAIL / 0 SKIP · exit 4 · HARNESS_RESULT=yes

**`tools/check_prose.sh` was registered nowhere** — no layer, no CI job, no hook — and was RED on three
files live on `origin/main`. `scenes/visuals.gd` had gone 117 → 166 em-dashes across ten commits, forty-nine
added in four days, every one written after an earlier scrub. c1 found why it could stay missing:
`check_ci_coverage`, the layer whose job is "every layer runs", filtered its population to `.gd`.

Scrubbed by hand rather than swapped (the gate's own header: a uniform em-dash-to-comma swap is more
detectable than the punctuation it replaced). `rock_tooth.gdshader` 0.893 → 0.607 commas/line with its
comment-line count UNCHANGED at 56. **With comments stripped from both sides the code is byte-identical to
HEAD in all three files** — verified here and independently by c1 with an instrument it proved capable of
failing first.

**The obvious repair to `check_ci_coverage` repaired nothing.** Widening the extension filter and re-running
with `check_prose` unregistered: still PASS. The operative exclusion was the inheritance test thirteen lines
down, which a shell script cannot satisfy. Only the mutant could tell.

### T1.0b — two of the five failing seeds are the PILOT, not the world

    20260817  FALLING in a pit of its own digging; both hop branches are guarded by `on_floor`
    512       WEDGED in a ONE-ROW gallery it mined, on floor, walkable cell ahead, zero velocity

My first mechanism (the walker probing from a cell inside the ground) was refuted by its own first
instrumented run — `own cell open`. And the ruler I wrote to settle it printed the world AS GENERATED while
the failure is in the world AS PLAYED; both readings correct, different worlds.

---

## `check_material_grammar` — A KNOWN RED, and the floor is NOT to be moved

    item        found by the final sweep, not by looking for it
    status      OPEN, classified: invalid instrument (variance comparable to the margin)
    reading     74.29% against a 75.00% floor — 52 of 70 windows, where the floor needs 53

**First: it is not mine.** The layer contains zero references to `play_agent`, `PlayAgent` or `AGENT`, and
the only source files I touched since the last green sweep are `tools/check_prose.sh` and
`tools/play_agent.gd`. The reachability control comes before the flakiness argument, not after it.

**POOLED OVER SIXTEEN RUNS OF THE SAME INSTRUMENT, in three groups with their conditions**, because the
first two groups disagreed and c1 was right to refuse a single characterisation. Nothing in the layer's
measurement path changed across any of them: the last edit to it before tonight's print fix was `bd5e3ad`,
and all sixteen are after it.

    early, recorded before compaction   52 52 52 53 53              mean 52.4   spread 1
    later, box busy with sweeps         54 54 54 51 56 55           mean 54.0   spread 5
    quiet box, load 2.3                 53 50 54 53 53              mean 52.6   spread 4

    all sixteen, sorted   50 51 52 52 52 53 53 53 53 53 54 54 54 54 55 56
                          mean 53.06   MEDIAN 53   range 50..56   below the floor: 5 of 16

The floor needs **53**. The pooled **median is exactly 53**: the layer sits ON its bound and falls under it
about **31% of the time**. It passed sweep8 and sweep9 and failed sweepA on identical code.

**The load hypothesis does not survive the pooling** — the quiet group (52.6) looks like the early group
(52.4) and the busy group (54.0) is the outlier, which is the opposite of contention depressing a reading.
Six-run and five-run groups cannot settle that, and the honest statement is that the middle group is
unexplained rather than attributed.

**A floor set inside the instrument's own spread cannot decide anything, and here the bound is the
median.** That is the finding, and the unstable spread strengthens it rather than weakening it: an
instrument whose spread is itself unstable is further from being able to decide, not closer. The
mechanism is almost certainly the documented one: this layer photographs the real scene after 70 settle
frames, and captures on this project differ run-to-run from animation phase alone — guttering torches move
which windows read as lit.

**What must NOT happen:** the floor is 0.75 and the reading is 0.7429. Moving the floor to 0.74 would make
this green tonight and would be the forbidden move — the property is not more true at a lower bound.

**What the fix looks like**, unbuilt: pin the animation clock before the capture, or raise the window count
until the spread is small against the margin. Both reduce variance rather than relax the claim. Note also
that at n=70 the achievable readings either side of the floor are 74.29 and 75.71 — **75.00 is not a
reachable value**, so the bound is really "53 of 70" and would be better written that way.

---

## RETRACTED: "a one-row opening is a wall" — written, measured, refuted, reverted

    status      REVERTED, nothing committed
    class       my mechanism was wrong, and the sweep is what said so

c1's diagnosis of corpus seed 512 was that the walker's probe reads the step cell and the cell BELOW it,
never the cell ABOVE, so a mined row with rock over it scores as a clean walkable step — while the body is
`Player.HEIGHT` 34px in a `WorldRenderer.CELL` 32px grid and cannot enter one row of clearance. The
movement code says as much itself at `player.gd:460`: *"don't climb into a ceiling (a tight gap is a
wall)"*. I accepted it, implemented the detection, and it fired precisely on 512:

    walk to column 44: the opening at (44, 26) is ONE ROW high ... it cannot enter
    could not walk to column 44 ... in 27 frames        (was 178)

**And then the full sweep went red on `play-tests`, which had been green in the two sweeps before it.**

    · walk to column 34: the opening at (43, 19) is ONE ROW high ... it cannot enter
    ·     from there: own cell open, ahead open, ahead-floor SOLID; on_floor=true, v=(-150.0, 0.0)

**The body was moving at 150 px/s through the opening the predicate had just declared impassable.** One
row of clearance is not always impassable, whatever the two constants say, and the geometry alone does not
separate 512's genuinely-stuck body (`v=(0,0)`) from this one. Reverted; `play_tests` re-run alone
afterwards: **ALL PLAY-GOALS MET**.

**What survives.** 512 is still a pilot failure and still not a design call: the body is stopped, on floor,
pushing at zero velocity, and a player cannot be soft-locked that way. What does NOT survive is the
mechanism — one row of clearance — and therefore the fix built on it. The discriminator is dynamic, not
geometric, and nobody has one yet.

**What this cost and what it bought.** It cost a sweep. It bought the refutation of a mechanism that two
sessions found convincing, one of which had the source lines in front of it. Second time tonight a
plausible, mechanical, well-sourced story about this walker died on its first real measurement — the first
was mine (the walker probes from inside the ground; refuted by `own cell open`).

---

## The tight gap, measured: it is a COIN FLIP, and the design comment says which side is the bug

    tool        tools/_scratch_tight_gap.gd (untracked ruler, extends SceneTree, asserts nothing)
    class       implementation defect in shipped movement, DESIGN-DEFERRED for the repair

A flat gallery, floor row 12, a seven-cell one-row tunnel under a ceiling at row 10, goal past the far
mouth. Sixteen runs differing in ONE quantity: the sub-cell x the body starts from. Same map, same body,
same input. That is the control travelling inside the measurement.

    8 of 16 CROSSED       8 of 16 PINNED, every one at x=441.00, feet_y=384.00, v=(0,0), on_floor

441 + WIDTH/2 = 448 = the mouth boundary exactly. The pinned body is standing on the floor, holding
right, at zero velocity, forever.

**The mechanism, and it now predicts a number rather than telling a story.** `_resolve_axis`
(player.gd:511) skips a solid cell when `ov_x > ov_y`. With the feet resting on a row boundary the head
pokes into the ceiling cell by exactly `HEIGHT - CELL` = 2px, so `ov_y` is 2 and the test reduces to
"did this frame carry the body more than 2px into the mouth cell". At the measured arrival speed the
overlap on the contact frame is uniform in (0, travel], so the pin rate should be `2 / travel`. It then
latches: the block sets `velocity.x = 0`, and at ACCEL 1700 a body restarting from rest travels 0.47px
in its first frame, which is under 2px again. **Being blocked is what causes the next block.**

**Which half is the defect is settled by the source, not by taste.** player.gd:20 says: *"Just over one
cell tall, so a body still needs two tiles of clearance and a one-tall gap is an honest squeeze."* The
design says a one-row gap is impassable. So the eight CROSSED runs are the bug: the body tunnels through
terrain it does not fit in, on a coin flip.

**And that is why my predicate broke the friction play-test.** That pilot's route crosses a one-row
opening at speed. It is not exercising a feature; it is passing because of this defect. Any repair that
makes the mover match its own documented design breaks that fixture's route, which is exactly what
happened in sweepB.

**Not repaired tonight, and the reason is not timidity.** The two candidate repairs are mutually
exclusive and one of them changes what the whole world is passable to:

  - make one-row gaps consistently IMPASSABLE (matches the design comment) — then seed 512's pilot is
    correct to give up, my reverted predicate becomes right, and the friction play-test needs a new route
  - make them consistently PASSABLE — then the design comment is wrong and the body is effectively 32px
    for traversal, which is a feel change to every drift in the game

What is NOT a design call, and is true either way: **50% is wrong.** A player who walks into a drift and
is refused half the time, with no feedback and no way to tell which, is reading a coin flip as a bug in
the controls.

### The rate is predicted, not just the direction

The ruler prints, per leg, the rate the mechanism requires. Each run has its own arrival speed and so
its own pin probability `2 / travel`, averaged PER RUN, because `2 / mean(travel)` is a different
quantity and averaging the wrong way is how a statistic ends up measuring its own summary.

    leg 1, run-up 8 cells    8 of 16 PINNED (50%)   mean 3.39 px/frame   predicted 60% (9.5), sd 2.0
    leg 2, run-up 2 cells   13 of 16 PINNED (81%)   mean 2.70 px/frame   predicted 75% (12.0), sd 1.7

Both inside one standard deviation, and the two legs predict DIFFERENT numbers, so agreeing with both
is not something a vacuous model could do.

**The sharpest cut is a sub-population inside leg 2.** Twelve of its sixteen runs arrived at exactly
150.0 px/s, which is RUN_SPEED with no stride built yet, so 2.50 px/frame. Two of those twelve crossed.
`1 - 2/2.5` predicts 20% cross, or 2.4 of 12. Nobody tuned that.

    file      tools/_scratch_tight_gap.gd (untracked; the full output is in this document)
    verdict   confirmed implementation defect; the repair is a director's call, see above

### The census: which of the suite actually stands on the squeeze

c1's point, checked against the source and correct on both counts: the `friction: cross a jagged tunnel`
goal carves clearance of 3 to 5 rows at columns 57-64 (`play_tests.gd:1397-1400`), so it is NOT the
dependent I named; and `walk_to_column(34)` has exactly one caller, `_goal_round_trip_to_vein`, whose
docstring calls it *"the most common real loop"* with pass condition *"not stranded"*. The goal my
reverted predicate broke was the round trip, not the tunnel. I read the last PASS line before
ALL PLAY-GOALS MET as the goal that had been at risk; it was simply the last one printed.

Their proposed instrument is the reverted predicate, re-applied to enumerate rather than to fix. I ran a
weaker and better version of it: **log-only, at both walk sites (`walk_to_column` and `approach`), deduped
per cell, changing nothing.** A predicate that breaks the walk enumerates the consequences of its own
intervention; one that only prints lets every goal run its normal course.

**The whole suite touches the squeeze exactly once.**

    17 goals, 17 PASS, ALL PLAY-GOALS MET
    CENSUS one-row opening at (43, 19), walking to column 34, v=-150.0        <- the only line

Same cell sweepB named. One goal, `_goal_round_trip_to_vein`, and in a normal run the body crosses it at
150 px/s and the goal passes.

**The census carries its own positive control.** It fired. A search that returns almost nothing is
evidence about the search first, and this one is not dead: it printed the cell the earlier failure named,
from the walk that failure was on. So one is a real one.

**And the reason the suite is green is the reason it is blind.** The ruler says this geometry pins
somewhere between half and four fifths of approaches. The suite does not see that, because the play-test
runs the same seed, the same route, and therefore the same sub-cell phase every time: it always lands on
the same side of the coin. **The determinism that makes the fixture reproducible is what hides the coin
flip from it.** A player varies their approach and does not get one fixed draw. Seed 512's pilot lands on
the other side, which is the whole of the difference between the two.

So the cost of the IMPASSABLE repair is now bounded and named: one goal of seventeen, and it is the game's
most common loop. That is not a fixture to re-route around; it means a player hand-mining a shaft would be
refused entry to their own dig. The bound is what makes the director's choice a real one rather than a
guess, and it argues for repairing the mover, not the pilot.

---

## The repair, measured but NOT committed: the ledge exemption is direction-blind

c1's reading, verified in source. `player.gd:369` runs `_resolve_axis(true)` BEFORE the vertical
integration at 379, so the horizontal pass uses the PREVIOUS frame's `position.y`. A body grounded at the
end of last frame had its feet snapped to a row boundary, so `ov_y` is exactly `HEIGHT - CELL` = 2.0 every
frame it walks. The ruler's condition is not an artifact of the ruler; it is what the vertical snap
produces on every walking frame.

And the test itself:

    player.gd:511   if ov_x > ov_y:
    player.gd:512           continue   # shallower in Y -> a ledge to step/land onto, not a wall to block

**It is direction-blind.** The intent is "the body is clipping the top of a block BELOW it, so let it step
up rather than block". The identical condition fires when the body is clipping the bottom of a block
ABOVE it. Nothing in the branch compares the cell's position to the body's. It is a two-way classifier,
ledge or wall, in a world that also contains ceilings, and a ceiling is neither.

**One condition, tested:** apply the exemption only when the cell's centre is below the body's centre.

    baseline    leg 1  8 of 16 PINNED      leg 2  13 of 16 PINNED
    gated       leg 1 16 of 16 PINNED      leg 2  16 of 16 PINNED

A one-row opening becomes impassable regardless of approach speed, sub-cell phase or tick rate, which is
what `player.gd:20` already claims the world does. (Note the ruler still prints a "predicted" rate on the
gated build. That line models the OLD classifier and does not apply; 100% against it is not a miss.)

**One correction to the derivation that came with it.** c1 computed the crossing margin from RUN_SPEED
150, giving 2.5 px/frame and a bound of "half a pixel off the floor". `STRIDE_GAIN` is 0.55, so
`speed_top` reaches 232.5 px/s and the real advance is up to **3.875 px/frame**; the bound is `h < 1.875`,
not 0.5. Leg 1's measured arrival speeds were 182 to 228 px/s, all above RUN_SPEED. The direction of the
claim survives, the margin is 3.75x wider than stated, and the mid-fall case is still unmeasured.

**Left in the working tree only long enough to price it. Nothing committed.**

### Pricing the repair: the blast radius is measured, and it is nothing

Full sweep on the gated build: **107 PASS / 0 FAIL / 0 SKIP, exit 4, HARNESS_RESULT=yes**, and the
round-trip goal's metrics are BYTE-IDENTICAL to the baseline's:

    mines=9 places=3 jumps=2 frames=82 stuck=2 | PEAKBULK=25 HANDED=25 MINED=0

That is not proof of no effect on its own, so I probed the behaviour DELTA directly: log every cell where
the old code would have exempted and the new one blocks, once per cell, across the whole play-test suite.

    CEILING-BLOCK at (74, 27) ov_x=0.47 ov_y=0.08 v=(28.3,325.0) feet=929.92
    CEILING-BLOCK at (69, 37) ov_x=0.47 ov_y=0.25 v=(-28.3,560.0) feet=1249.75

**Two, in seventeen goals, and neither changed an outcome.** Both are falling bodies (`velocity.y` 325
and 560) grazing a cell corner by a fraction of a pixel: `ov_y` of 0.08 and 0.25, nothing like the
grounded 2.0. The probe fires, so the two is a real two.

**And neither is (43, 19).** The census's one hit never became a ceiling overlap in the mover at all. A
cell-level predicate and an AABB-level mover disagree there and I have not closed why; the likeliest
candidate is `_follow_slope`, which moves `position.y` before the horizontal resolve and can take the
head clear of the row above. **Recorded as unexplained rather than explained away** — it means the census
OVER-reports, so its one hit is an upper bound on the dependent set, not a member of it.

### The guard, and why it takes four approaches instead of one

A fix with no guard regresses, so the repair carries one: a fifth phase in `check_stepup` that builds a
one-row tunnel and walks into it **from four different sub-cell start phases**, asserting all four are
refused.

    repaired     PASS: a one-row opening refused the body from all 4 start phases
    unrepaired   FAIL: ... (SQUEEZED THROUGH at +16px)   1 STEP-UP CHECK(S) FAILED

**Only one of the four crossed against the unrepaired mover.** A single-approach guard written at any of
the other three offsets would have passed against the very defect it was written for, and read as
evidence the world was sound. That is [[deterministic-fixture-draws-once]] again, one level up: the guard
had to vary the axis the defect lives on, or it would have inherited the same blindness as the fixtures
it was written to replace.

---

## The seed corpus under the repair, and the control that had to come with it

`SF_CORPUS_ONLY=check_pacing`, all eight seeds, at `fafad04`:

    seed 1337      13.69%  density 31.89   ok
    seed 4242      23.70%  density 25.96   FAIL (dead air)
    seed 7         20.45%  density 26.24   FAIL (dead air)
    seed 99        16.27%  density 26.53   ok
    seed 20260817  67.26%  density 20.00   FAIL (opening, dead air, thin)
    seed 31337     25.47%  density 25.47   FAIL (dead air)
    seed 512       83.47%  density  6.58   FAIL (opening, dead air, thin)
    seed 8675309   14.22%  density 27.81   ok

**5 of 8 red, the same count as before the repair. No seed went red that was not already red**, which is
the safety claim and it is sound: a new failure would show as a sixth.

**What is NOT yet a claim.** Seed 512 previously read 92% silence, density 3.0, over 10,430 frames; it now
reads 83.47%, density 6.58, over 5,016. The session halved and the dead air fell. That looks like the
repair improving the worst seed, and it may be. But the tree has changed in other ways since that
baseline was taken (`check_pacing`'s assertion resolution, `play_agent`'s give-up diagnostics), so the
comparison is not one variable and the number is at its most dangerous precisely because it is moving.

**So the corpus was run again with only the mover line reverted, same tree otherwise, one variable.**

    diff of the per-seed numbers, repaired vs control:   IDENTICAL, every seed, every number
    the same five seeds red, the same failing assertions in each

**The mover repair changes nothing in the corpus, seed 512 included.** Every improvement against the
earlier baseline belongs to the other tree changes, not to the fix. My provisional reading of it
("that looks like the repair improving the worst seed") was wrong, and the control is the only reason it
did not go into the handoff as a claim. This is [[scrutiny-asymmetry]] exactly: the number was most
dangerous while it was moving, and moving in the flattering direction.

Two things it does establish:

  - **the repair introduced no new seed failure**, across a population the play-tests do not cover; and
  - **seed 512's opening failure is NOT the one-row gap.** It survives a mover that now refuses those
    gaps consistently, unchanged to the digit. Whatever strands that pilot is still unidentified, and the
    tight-gap story is now excluded by measurement rather than by argument.

---

## Seed 512, closed. And my exclusion of the gap was invalid

c1's partition probe, which is not a mechanism story: it splits "why is `velocity.x` zero" into cases and
asks which. For a grounded ropeless body the writes are the input block and the collision zeroing, so
`vx_in` (what the input block left) plus a flag on the zeroing separates them completely.

    WHYZERO in=-1.0 vx_in=-28.33 zeroed=true body=(45,26) feet=864.00 | BLOCKER (44,25) ov_x=0.47 ov_y=2.00
    39 of 40 frames identical; the 40th differs only in ov_y

The pilot IS pressing. The input DOES reach the body: `vx_in` is exactly one frame of ACCEL. The collision
zeroing fires every frame. Feet at 864 is row 27's top, head at 830 is **2px into row 25**, `ov_y = 2.00`.
**One-row-gap geometry, blocker named.**

**I had excluded this an hour earlier and the exclusion was invalid.** From the corpus being byte-identical
with and without the repair I concluded 512's failure was not the gap. It does not follow. The repair
changes an outcome only where `ov_x > ov_y`, that is only for approaches that would have CROSSED; 512
latched at `ov_x = 0.47`, which the old code blocked too. **512 was already on the pinning side, and the
repair only removes the other side.** Identical numbers were the predicted result of the diagnosis being
RIGHT, and I read them as evidence against it.

So c1's original diagnosis stands. What my refutation actually killed was the stronger claim bundled with
it, that a one-row gap is always impassable: pre-repair it was not, post-repair it is, and 512 sat in the
always-impassable case the whole time.

**One correction to the probe's premise.** c1 enumerated four writes to `velocity.x`; there are six
(`:273` the swing add and `:288` the coast were missed), plus the whole-vector rope writes. The partition
is exhaustive only for a GROUNDED, ROPELESS body, which is 512's state, so the reading holds. Stated
because an exhaustive-partition argument is worth exactly its exhaustiveness.

**And the obvious follow-up is still wrong.** Re-applying the reverted cell-level predicate now that the
mover guarantees the geometry looks safe and is not: the round trip still crosses (43,19) post-repair,
byte-identically, and the delta probe found no ceiling block there. That cell is a one-row gap in CELLS
and passable in PIXELS. The honest pilot guard keys on the trap, not its shape: grounded, pressing,
`|velocity.x| < 1.0`, sustained for N frames. It cannot misfire on a moving body and needs no geometry.

---

## The third branch: right diagnosis, insufficient fix. Written, measured, reverted

c1's structural finding is correct and I verified it in source. `walk_to_column` has exactly two branches
and both end in `_do_jump()`:

    if not solid(ahead) and not solid(ahead_floor):   _do_jump()      a GAP
    elif not progressing and solid(ahead):            _do_jump()      a WALL

512's state is `ahead` OPEN and `ahead_floor` SOLID with the blocker overhead, which is neither, so the
walk falls through both and holds its direction until the budget expires. **The pilot is not making a bad
decision; it has no case for what it is looking at.** Same shape as the mover's ledge-or-wall test, in a
different file, reached independently. `here_cell + Vector2i(dir, -1)` is exactly the `(44,25)` the probe
named.

So I added the third case: not progressing, `ahead` open, `up` solid, therefore the obstruction is
overhead, so `do_mine(up)`.

**It is not enough, and the measurement says so plainly.**

    before   could not walk to column 44 in 178 frames, stopped at (45, 26)
    after    could not walk to column 44 in 202 frames, stopped at (44, 26)

    fafad04            83.47% dead air = 4187 of 5016 frames, density 6.58
    with the branch    83.91% dead air = 4235 of 5047 frames, density 6.14

**The branch fires and works**: the "will not cut" note never printed, so every `do_mine(up)` succeeded,
and the body advanced one column, from (45,26) to (44,26). Then it stuck again and burned MORE frames
doing it. What stops it at (44,26) is not identified; it is not the same cell, and one mined cell per
stuck episode does not open a multi-column drift inside the walk budget.

**Reverted. Nothing committed.** The diagnosis survives and is worth more than the fix was: the taxonomy
gap is real, mining `up` is the right kind of action, and the remaining obstruction at (44,26) is the next
question. What does not survive is "add the third branch and 512 clears", which is the prediction that was
made and the one that failed.

Fourth mechanism of the night to be written from source, predict something specific, and die on its first
run. That rate is the process working, not the process failing: every one of them died on a measurement
that cost minutes, and the only thing that shipped tonight is the one whose prediction held.

---

## The trajectory, and it moves the question upstream of everything above

c1's call was right: stop writing mechanisms, log the route. A log-only probe in `walk_to_column`, one
line per distinct cell, no behaviour change. The whole failing walk:

    TRAJ to col 44: 4 distinct cells
      (49, 19) a=o af=S up=o  -
      (48, 20) a=S af=S up=o  WALL
      (47, 20) a=o af=o up=o  GAP
      (45, 26) a=o af=S up=S  HEADROOM(unnamed)
      STALL (45, 26) for 151 frames
    TRAJ stalled 153 frames across 3 cells

**The population is ONE.** Exactly one headroom cell on the entire route, not a gallery of them. So
clearing cells one at a time was never going to run out of budget for the reason we assumed, and the
one-column advance under the third branch was not "one of many".

**The interesting event is two lines earlier.** Between `(47,20)` and `(45,26)` the body drops **six rows
and two columns**, and there are no cells recorded in between because the probe only logs while
`on_floor` is true: **the body was in the air for that stretch.** The cell it left was classified GAP,
whose branch is `_do_jump()`, and whose comment reads *"there's almost always a near landing on the
surface"*.

So the shape of the failure, in the order it happens:

    1. a gap at (47,20)          the walk jumps it
    2. no near landing           the body falls six rows into a pocket
    3. it comes to rest at (45,26) with rock overhead, in one row of clearance
    4. it pushes for 151 frames  because the taxonomy has no case for that
    5. 4,736 frames of opening   never reaching first automation

**The headroom stall is where the body came to REST, not what stranded it.** Every fix considered
tonight, mine and c1's, was aimed at step 3 or 4. The event that decides the outcome is step 1, and
`walk_to_column`'s own docstring already records the same class of accident: *"A worldgen change opened a
58-row chasm at column 71, across the approach; the body fell in, walked the floor, and this returned
true."* That paragraph is about a different column and the identical mistake.

**Stated as what is measured and what is inferred.** Measured: four cells, one HEADROOM, a six-row two-
column discontinuity between consecutive on-floor records, a GAP classification immediately before it,
151 frames stalled. Inferred: that the jump at (47,20) caused the fall. Strongly supported by the
airborne gap in the record, and not directly instrumented. **The next run should instrument step 1**, not
step 3, and it should ask whether the gap branch checks for a landing at all before committing the body
to a jump.

### ...and the upstream fix is inert. Fifth mechanism, cleanest death yet

`approach()` tests for a landing before it hops a gap; `walk_to_column()` asserted one in a comment
("there's almost always a near landing on the surface"). **That asymmetry is real** and I verified it in
source: same case, twelve lines apart, one checked and one taken on trust.

Ported `approach`'s check into `walk_to_column` (jump if a landing sits within a short hop, else bridge
with a block, exactly as the sibling does) and ran seed 512:

    fafad04             83.47% = 4187 of 5016 frames, density 6.58, stopped at (45,26) in 178 frames
    with the check      83.47% = 4187 of 5016 frames, density 6.58, stopped at (45,26) in 178 frames

**Byte-identical. The change is INERT on this path.** Which refutes the inference: either the gap branch
did fire and the landing test passed, so the body hopped and fell anyway, or the branch never fired and
the six-row drop came from somewhere else entirely. The trajectory could not distinguish those, because
it only records cells while `on_floor` is true and the whole descent happened in the air.

**Reverted. Nothing committed.** And the reason to revert is not only that it did not help: an inert
change cannot be validated. Byte-identical output is exactly what a branch that never executed produces,
so there is no evidence this code does anything at all on any path, and shipping it would be shipping an
untested line.

What survives: **the source asymmetry is a real latent difference** and worth fixing on its own merits
some day, with a fixture that proves the branch live first. What does not survive: that it is seed 512's
cause. Measured, not argued.

**Where 512 actually stands, after five dead mechanisms.** The body ends at (45,26), six rows below and
two columns across from the last cell it was recorded standing on, having been airborne for the whole
gap, stuck under one row of clearance for 151 frames, with the opening never reaching first automation.
The stall is fully explained and fully repaired at the mover level. **The descent that puts it there is
not explained**, and the next instrument has to record airborne frames, which every probe tonight
deliberately did not.

---

## A null from an uncontrolled scanner is not a null

c1 flagged an index hazard on their branch: a working tree reset to HEAD without the index, leaving a
staged blob present in neither HEAD nor the worktree and **armed**, because a staged blob is exactly what
the next commit writes whatever its message says. This checkout ran `git checkout <file>` seven times
tonight reverting probes, so it is the same operation. Checked:

    git diff --cached --stat     empty        git diff-index --cached HEAD   index == HEAD
    git diff --stat              empty        git diff-files                 worktree == index

And the declaration-set diff on the one commit touching shipped code: `player.gd` 98 members before and
after with none missing, `check_stepup.gd` 13 to 19 with none missing.

**Then c1 asked whether that scanner could report anything at all, and it had not been shown to.** It had
not. Controlled it:

    leg 1  the real comparison                      parent 98, head 98, missing: none
    leg 2  MUTANT, one member deleted from HEAD     mutant 97, missing: const GRAVITY

The scanner names it, so leg 1's null is a real null. **It was not, an hour ago.** I spent the night
insisting a mutant be proven live before its result counts, and then read a null off an unproven scanner
without noticing, in the middle of writing that exact rule into a commit message.

**Third instance in one night of output that cannot distinguish a working instrument from a blind one:**
my inert landing-check (byte-identical output is what an unexecuted branch produces), c1's control that
used a non-amputating merge as its known-positive and therefore passed for free, and this. Three
different tasks, three people, one failure mode. It is the house class and it does not get less frequent
by being known.

---

## The tell surface my own screen could not reach

c1 checked the push candidate for AI tells and found two things my screen had missed. **The screen was
scoped to the nine ADDED files; the branch also modifies 49, and both findings were in modified files.**
A screen whose population is "what is new" cannot see a line inserted into something old.

### 1. Fifteen attributions to an internal session identifier

    attribution-form comments   origin/main: 1      HEAD: 15 (14 net new, all mine, all tonight)

Every one is a comment crediting the peer session by name: *"Found by c1 in the CI log for bd2b1d7"*,
*"c1's finding"*, *"c1 caught that before it shipped"*. The worst placement is
`.github/workflows/harness.yml`, a public CI workflow. A reader asks who c1 is, finds a single author
throughout and no such contributor, and the only available answer is an internal session identifier.

Rewritten, all fifteen. The engineering content is the valuable part and it is kept intact; only the
identifier goes. *"Found by c1, who went and read the CI log for the thing I had said I could not
measure"* becomes *"Found by reading the CI log for the thing I had said I could not measure"* -- the
self-criticism survives, which is the part worth having.

### 2. The gate built to catch tells was the last thing in the repo carrying them

    tools/check_prose.sh   WIDE_TOKENS = [agentic, subagent, AI, Claude, Anthropic, LLM, ChatGPT,
                                          copilot, language model]

**A public repository containing a banned-word list of exactly those tokens is self-documenting.** It
does not merely leak a word; it publishes the author's expectation of finding them, which is evidence of
intent rather than of authorship, and it tells a reader how to read everything else.

And the measurement settles what to do. Every word on that list occurs **zero** times in the tracked tree
(control: the same search for `harness` returns 13 files). **The list had already done its job, and the
only surviving instance of each forbidden word was the line forbidding it.** A rule that is the sole
remaining example of what it prohibits is not protecting anything.

So the list moved out of the tracked gate into `tools/prose_words.txt`, excluded via `.git/info/exclude`,
with `SF_PROSE_WORDS` to point at another. The mechanism, the paths, the self-exclusion and the reporting
all stay. The file already excluded itself from its own scan *because* it spelled the literals, so the
author had seen half the problem and solved the wrong half.

### The controls found two defects in my own fix

    leg 1  list present, tree clean       -> named a default path that did not exist (one dir too high)
    leg 2  a word that really occurs      -> rc=1, names all 13 files. The instrument works.
    leg 3  no list at all                 -> printed "ASSERTED NOTHING" and then, on the next line,
                                             "151 more clean on the wide sweep", and PASSED

**Leg 3 is the house failure inside the fix for the house failure.** A gate that reads 151 files, tests
zero words, and reports them clean is precisely the quiet green this file exists to prevent, and I wrote
it. The summary now reads `and the wide sweep ASSERTED NOTHING (no word list; 151 file(s) read, 0 words
tested)`, and the header counts words tested rather than files opened, because the number that matters is
what was asserted and not what was walked past.

### ...and the fix put the quiet green one level up, where it lasts forever

c1 ran my repaired gate in a worktree with no `prose_words.txt`, which is a fresh clone exactly, and found
what the reporting fix did not reach:

    no word list      EXIT 0    155 files read, 0 words tested, SKIP markers emitted: 0
                                rows in stand_downs.txt for check_prose: 0
    CONTROL, one real word      EXIT 1, names 15x in harness.yml, 7x CONTRIBUTING.md, 5x README.md

So the instrument is live and the null is real. **But the layer exited 0 with no marker and no registry
row, so the runner scored it a plain PASS** — byte-indistinguishable from a run that tested every word.
And because the list is deliberately untracked, that is not an edge case: **it is the permanent state in
CI, the one environment where the tree becomes public.**

I had fixed the message and left the verdict lying. `107 PASS` included a layer that asserted nothing
about the thing it exists for. That is this repository's house failure inside the fix for the house
failure, one level up from the leg I had just congratulated myself on catching.

**Repaired through the registry rather than the prose.** The layer now prints `SKIP: [prose.wide-word-list]`
when the sweep is declined and `HELD: [prose.wide-word-list]` when it ran, and `tools/stand_downs.txt`
carries an `env` row for it. A shell layer has no `check_base.gd` to call, so the three-valued markers are
spelled by hand; the gate resolves them the same way either route.

    leg A  list present (this machine)   HELD, 11 words, exit 0
    leg B  no list (fresh clone / CI)    SKIP, named, and the summary says ASSERTED NOTHING
    leg C  a word that occurs            exit 1

**What is NOT fixed, and is written into the registry row as a director's question.** The protection now
exists on the two machines that do not need it and is absent exactly where the artifact becomes public.
Shipping the list as salted digests would get both properties at once — no vocabulary in the tree AND a
live check in CI — and is the better answer if a reader finding an obfuscated word list is judged
acceptable. That is a publication call, not a code one, so it is priced and left.

**And c1's first attempt at this measurement was a driver failure**, which is worth recording beside the
finding: they ran the script from a scratchpad, `cd "$(dirname "$0")/.."` rooted it there, and it exited 2
on a missing reference file. A broken driver reading as a broken subject, caught by re-running from a real
`tools/`. Sixth instance tonight of an instrument that could not register its subject, and the second
where the person who found it was the person it fooled.

### Verifying c1's count found a hole in my own gate

c1 reported four live `agentic` instances on `origin/main` and said my branch had none. Both halves check
out, and getting to the arithmetic exposed something neither of us was looking for.

    origin/main   play_agent.gd 1   play_tests.gd 2   run_harness.sh 1      HEAD: 0 of any of them

My first count said three, because `grep -c` counts LINES and one of the two in `play_tests.gd` is spelled
**`AGENTIC`**, capitalised, in a docstring. Chasing that discrepancy rather than rounding it off is what
found the defect:

    tools/check_prose.sh:316   narrow sweep   re.findall(pat, m["body"], re.IGNORECASE)
    tools/check_prose.sh:292   wide sweep     re.findall(pat, wsrc)          <- no IGNORECASE

**And `tools/prose_words.txt`'s own header promised "matched whole-word and case-insensitively".** The
list documented a behaviour the code did not implement, and I wrote both of them tonight, hours apart.

Proven live before repairing, on a real scanned file:

    planted `# AGENTIC`   exit 0    the gate missed it
    planted `# agentic`   exit 1    the gate caught it

Fixed, re-controlled (capitalised now exits 1), and the tree stays clean under case-insensitive matching,
so nothing false-positives today. The one entry with room to bite later is `AI`, which is whole-word and
case-insensitive and would fire on a bare identifier named `ai`; noted in the list itself, with the
instruction to rename the identifier rather than drop the word, because a loud wrong answer is the trade
this list is making.

**Two of the three surviving instances on `origin/main` are RUNTIME OUTPUT, not comments**, which ranks
them above where either of us placed them:

    play_tests.gd:34   print("== Sinkforge agentic play-tests ==")   heads the layer log in every run
    run_harness.sh:551 add "play-tests (agentic + friction)"         every sweep summary and the Actions tab
    play_agent.gd:15   ## ... the agentic test TYPE                  source only

The first two are read by people who never open a file. This branch already carries `driven play-tests`
and `scripted pilot + friction` in their place, so the fix is a public one rather than a candidate one.

## THE SAME GATE HAD A SECOND HOLE, AND IT WAS THE POPULATION

Chasing the case-sensitivity fix one step further asked the obvious next question: the wide sweep now
matches correctly, but *what does it read?* Two sweeps live in `check_prose.sh` and the pair reads as a
cover of the tree. It is not one.

    narrow sweep   scenes/ src/  .gd .gdshader     COMMENT BODIES only, 14-token style list
    wide sweep     tools/ .github/ docs/*.md       whole file, the 11-word vendor list
                   README.md CONTRIBUTING.md

Measured with a control leg, by planting three lines in `scenes/player.gd`:

    # agentic probe comment.        exit 1   caught     <- control: file IS in population, gate IS live
    # Claude wrote this helper.     exit 0   MISSED
    print("agentic probe")          exit 0   MISSED

The control is what makes the two passes mean blindness rather than a broken probe. Both misses are real:
the narrow list carries none of the eight vendor words (`Claude`, `Anthropic`, `LLM`, `ChatGPT`,
`copilot`, `co-pilot`, `language model`, `AI`), and it reads comment bodies, so a string literal in the
game code was unreachable from either direction.

**And a third population, scanned by neither sweep, ever:**

    tests/test_sim.gd         117363 bytes
    tests/test_worldgen.gd     64197
    tests/test_stress.gd       59431
    tests/test_power_water.gd  17937
    tests/test_base.gd          4757
    .githooks/pre-commit        5946      project.godot, LICENSE, .editorconfig, .gitignore

264KB of tracked, shipped GDScript that no prose gate had ever opened. **Note which surface nearly
shipped the instance that started all this**: `print("== Sinkforge agentic play-tests ==")`, runtime
output, and it was caught only because it happened to live under `tools/`.

**Repair.** `WIDE_PATHS = sorted(_tracked)` — the whole tree. The list's own premise is vocabulary wrong
ANYWHERE in a repository written by one person, so any narrower population is a claim that some corner is
exempt, and no such corner was ever argued for. Measured before changing anything: **0 hits across the 58
text files it adds**, so this hardens the gate and moves no verdict.

**A silent-skip path found while making room for it.** The loop carried

    except (UnicodeDecodeError, OSError):
        continue          # binary or unreadable: not prose, and not silently counted as clean either

and `continue` is *exactly* silently counted as clean: no counter, no output, nothing in the summary. The
comment asserted a property the code did not have — the same defect as the case-insensitivity bug, in the
same function, written the same night. It was unreachable while the population was 152 curated text
files. It runs ~250 times a run now, so it had to be right *before* the population grew. Binary is now
decided by inspection (a NUL byte in the first 8KB, git's own heuristic, not an extension allowlist —
that would be the same enumerated-set mistake one level down), and **an unreadable tracked file now
FAILS**, because a file the gate cannot open is a hole and not a pass.

**Every exit path from the loop increments exactly one counter, and the counters are reconciled:**

    wide sweep: 11 word(s) tested over 321 text file(s) -- every tracked file in the repository
                248 binary, 1 self-skipped (the gate does not scan itself), 0 tracked-but-absent,
                0 unreadable

    321 + 248 + 1 + 0 + 0 = 570 = git ls-files | wc -l

If they ever fail to sum, the layer exits 2 and says the sweep's silence is not evidence about anything.
**That guard is proven live, not asserted**: deleting the two `wide_binary += 1` increments in a copy
produced `POPULATION DOES NOT ADD UP: 322 accounted for against 570`.

Method note, because the first attempt at that mutant lied: run from the scratchpad it printed
`reference scenes/fine_terrain.gd is missing` and exited 2 with no accounting line, which reads exactly
like a dead guard. `check_prose.sh:70` is `cd "$(dirname "$0")/.."`, so the copy re-rooted itself to the
scratchpad and never reached the subject. Driver failure wearing the subject's clothes. Re-run from
`tools/`, with an unmutated copy at the same path as the driver control (exit 0), the guard fires.

Post-repair, all five legs fail and the baseline stays green:

    scenes/player.gd     # Claude wrote this helper.        exit 1   1x Claude
    scenes/player.gd     print("agentic probe")             exit 1   1x agentic
    scenes/player.gd     # agentic probe comment.           exit 1   1x agentic
    tests/test_base.gd   # ChatGPT drafted this fixture.    exit 1   1x ChatGPT
    .githooks/pre-commit # co-pilot suggested this hook.    exit 1   1x co-pilot

**What is deliberately still narrow, stated so it is not rediscovered as a surprise.** The narrow sweep
keeps reading comment bodies only in `scenes/` and `src/`, so its own six vernacular tokens (`harness`,
`director`, `peer`, `the user`, `play-test`, `agent`) remain unreachable in game-code string literals.
Measured: **0 such hits today**, so the limit is real and currently empty. It is left in place on purpose
— that list is prose rules (`**bold**`, a bare date, a ticket id) that produce nonsense against code,
where `\*\*[^*]+\*\*` would start matching arithmetic. The vendor list is the one the standing constraint
turns on, and it now covers every tracked byte. If the vernacular tokens ever need code coverage they
need their own third population, not a wider glob on this one.

## AND THE POPULATION NOBODY HAS EVER SCANNED IS THE ONE THAT IS ALREADY PUBLIC

Found by auditing my own branch for trailers before committing the fix above. The audit returned 1 where
it should have returned 0, and the hit was not a trailer: it was the word in the BODY of `ddf3c07`,
quoting a planted test fixture. Chasing that one non-zero, exactly as with the count of three-versus-four,
opened a fifth population.

**Commit messages are scanned by nothing.** `.githooks/commit-msg` and `tools/check_trailers.sh` screen
the *form* of a trailer (`co-authored-by:`, `*-session:`, `generated with [`) and nothing else. No sweep
in `check_prose.sh` has ever read a commit message, and a commit message is not in the tree, so widening
`WIDE_PATHS` to the whole tracked tree does not reach it either.

Scanning all 896 messages reachable from `origin/main` with the same eleven words:

    origin/main    896 messages    25 carry vendor vocabulary    ALREADY PUSHED
    branch-only     42 messages     4 carry vendor vocabulary    unpushed

Four of the public ones are in **subject lines**, which is what GitHub renders in the commit list, in
blame, and beside every file view (4 subject + 22 body - 1 carrying both = 25):

    7d60177  chore: gitignore local .claude/ agent state
    8c21f6a  docs(trace): A43 - subagent assignments and the 0049 read receipt
    3a66af8  Run the agentic play-tests under the game clock (2x) - faster CI
    8ab284d  harness: agentic play-tests - the harness PLAYS the game to a goal (layer 6)

**This does not contradict the clean bill on the tree; it re-scopes it.** `origin/main`'s *tree* is
clean, verified with a positive control. Commit messages are not in the tree. The earlier note said "the
public tree is clean" and that sentence is still true and was never a claim about history.

**Why this matters more than everything else recorded tonight.** Every other item is a guard being made
honest on an unpushed branch. This one is live, public, and has been for months, on the surface a
reviewer of a portfolio repository reads first: the commit list.

**And the authorised purge as currently scoped would not touch it.** The pending
history rewrite is written against the agent-process *corpus* -- files moved out of the repository root.
A filter that removes paths does not rewrite messages unless explicitly told to. If the rewrite happens,
the message callback has to be part of it or this survives the purge intact.

**BLOCKED, and correctly so.** The only repair for a pushed commit message is a history rewrite, which
this run is directed not to perform on any branch. Recorded with the full list rather than acted on.
Cheap forward-looking option, no rewrite required, not built because it is a design decision and not a
defect: extend `.githooks/commit-msg` to screen the message against `tools/prose_words.txt`, with a
harness layer asserting messages newer than a named baseline commit -- and that baseline is a constant
that must be derived from the last offending commit rather than written by hand.

## THE EXEMPTION BECAME THE HIDING PLACE, AND I WAS THE ONE WHO FILLED IT

Found by checking a peer's consolidated report line by line. One row read *"Process vocabulary in tracked
source: 0 across 11 words, case-insensitive"*, marked `measured`. It was measured with the gate — and the
gate excludes itself:

    WIDE_SKIP = {"tools/check_prose.sh"}

Correct, and necessary: a file that reports on the list matches anything the list names. But the exemption
made it **the one tracked, shipped file that no gate reads**, and the claim inherited the blind spot.

    bd2b1d7  origin/main             0 occurrences
    e7041fe  the case-fold repair    2
    da42feb  the population repair   5      (4x agentic, 1x Claude)

**Every one added by me tonight, in the two commits whose subject was removing that vocabulary from the
repository, into the only place nothing would catch them.** Comments explaining the mutant probe, spelling
out the planted words to make the evidence legible. The word list was moved out of the tree hours earlier
precisely so the repository would stop being the last surviving example of what it prohibits; the same
defect walked straight back in through the gate's own comment block.

**Repaired, then taken further than repair.** Comments rewritten to `<listed-word>` / `<vendor-name>`
placeholders, taking the file to 0 — and with 0 the reason for the exemption is gone, so
`WIDE_SKIP = set()`. The set and its counter stay, because an empty exclusion nobody mentions is as
invisible as an unlisted one.

Proven live, not asserted: planting `# Claude probe:` in the gate exits 1 naming `tools/check_prose.sh
1x Claude`; restored, exit 0. Accounting still reconciles, 322 + 248 + 0 + 0 + 0 = 570.

**Named on both axes.** Better on coverage: the last unscanned tracked file is now scanned. Worse on
freedom of expression in that one file: writing about a listed word there now fails the gate. Right way
round — the alternative is a blind spot exactly where someone is thinking hardest about the vocabulary.

**And the fourth instance of the same defect, inside the commit that fixed the third.** The summary line
still read `%d self-skipped (the gate does not scan itself)` after the gate started scanning itself. Now
`%d excluded by name`. Comment contradicting code, four times in one night, three of them in this file.

## THE SAME POPULATION DEFECT, IN THE SAME FILE, FOR THE RULE IT CALLS CATEGORICAL

Found by chasing a two-byte discrepancy. A peer's byte counts for `check_prose.sh` were +2/+4 against
mine at three revisions. Not a convention difference and not their error: **I printed `len(decoded_string)`
and labelled it bytes.** The gap is exactly the em-dashes, three bytes each.

    rev        cat-file bytes   my chars   em-dashes
    bd2b1d7             9659       9657      1
    da42feb            24712      24708      2
    53ac136            26259      26255      2

Which raised the question the number was standing in front of. This file's header says of the em-dash:
*"This is categorical, not a taste threshold: the character is the tell."* The rule implementing it is
`body.count(EMDASH)` over `paths`, which is `scenes/` and `src/` comment bodies.

    origin/main (PUBLIC)   1902 em-dashes in tracked text
                            314 inside the rule's population
                           1588 outside it        tools/ 1134, docs/ 354, tests/ 56, root 23, .github 18

**A clean run has always been able to read as "this tree has no em-dashes" while 84% of them sit one
directory across.** Same defect as the vendor-word population, same file, discovered four hours later,
for the rule the file is most emphatic about.

### And tonight's work moved the number in a way the aggregate hides

    start of the night (cf2e7b2)   1903
    candidate          (53ac136)   1898        net -5

    removed from the GATED population    -194      scenes/visuals.gd alone -176
    added to the UNGATED population      +189      tools/ +129, docs/ +40, README +7

**Net -5 reads as no change. It is a near-complete substitution across the coverage boundary.** The
quantity the gate measures improved by sixty per cent; the quantity that gets published did not move.
Nothing was chosen and nothing was concealed, which is the point: no output in the repository could have
shown it, and the aggregate actively conceals it.

### What was done, and what was deliberately not

**Not a scrub.** 1772 ungated em-dashes is a backlog decision that belongs to the director, and it spans
149 files including documents the user writes.

**Not a gate.** Extending the categorical rule would arrive red on 1772 lines, and a gate that arrives
already red gets switched off.

**A census that reports and fails nothing**, counted on the read the wide sweep already does, so it is
free. One line every run:

    note: 1772 em-dash(es) in 149 tracked file(s) OUTSIDE the categorical rule's population
          ... a report of 0 em-dashes above is a statement about 47 file(s), not about the tree.

That last clause is the whole intervention: it converts a count into a coverage statement, which is the
principle this pair of sessions arrived at an hour ago and had not yet applied here.

Proven responsive rather than asserted: planting one em-dash in `tools/lock_lib.sh` moves the line 1772
to 1773, removing it moves it back. And the census agrees with an independent whole-tree scan at 1772,
so the two instruments cross-check.

---

## The narrow list's population hole: process vocabulary in `tools/`

C1 filed one line — `tools/stand_downs.txt:72` carried a word naming who decides — in a file that is
**absent from `origin/main`**, so the push would have *introduced* it rather than merely leaving it.
Fixed. But the interesting part is why nothing caught it, and the answer generalises well past one line.

### Two lists, two populations, one uncovered cell

    NARROW  13 tokens (process vocabulary)  ->  scenes/ and src/ only     136 files
    WIDE    11 words  (vendor names)        ->  every tracked file        570 files

So `tools/` and `docs/` are screened for **vendor names** and screened for **nothing else**. Every
process word the narrow list exists to catch is unguarded there. `stand_downs.txt:72` was one instance
of a whole empty cell, not a one-off.

### The suggested fix is not available, and measuring that was the useful step

Adding the word to the wide list looks obvious and fails hard. The wide matcher anchors tokens of three
characters or fewer and matches longer ones as **plain substrings**, so the word matches inside
`directory` and `directories`: **37 files, 6 hits in `.gitignore` alone.** A classified count of four,
taken over the paths the narrow sweep cannot reach, missed this because the wide list's reach is the
whole tree — the same population error the night keeps producing, one more time.

There is also a hard blocker underneath it. `tools/check_prose.sh:152` is a **live token, not prose** —
the gate must contain the word to function — and `WIDE_SKIP` is now empty, so the gate scans itself.
The word cannot go on the wide list until the narrow token list is externalised the way the wide one
already is.

**The general rule, which is worth more than the line it came from:** the wide list's substring
discipline is safe *because vendor names are coined proper nouns*. Process vocabulary is ordinary
English and collides constantly. The length rule is not a bug here — it is correctly matched to the only
kind of word that list is allowed to hold. **The two lists are not two lengths of the same rope.**

### Census of the uncovered cell, and 15 repairs

Six narrow tokens read as process regardless of which file they sit in (`harness` and `agent` do not —
in `tools/` they are the subject matter, not a tell). Over the 434 tracked paths narrow cannot reach,
186 text and 248 binary — the population conserves:

    the user  24     peer  5     director  2     TRIED AND REVERTED  2     blind judge  1     RAISED  0

Every hit read, not sampled. They partition cleanly:

- **`peer` — 3 real, 2 of them inside the gate that hunts these words.** All the same shape: *"a peer
  found it"*, crediting another session as the discoverer of a bug. The finding is what belongs in a
  comment; who found it is process. Reworded to state the mechanism. The other 2 are legitimate — one
  live token, and `lock_lib.sh:103`'s "a slow peer" meaning a competing lock holder.
- **`the user` — 24 splits 11 / 12 / 1.** Eleven are ordinary software English: the human at the
  keyboard whose cursor a fixture must not warp, Godot's `user://`, the user directory. Twelve use
  "the user" to mean **the person who commissioned the work** — "the hypothesis the user handed over",
  "the feel the user asked for", "the friction the user named". In a solo-authored repository that
  second sense quietly says the author is not the author. It is the subtlest tell found all night and
  the largest single group. Reworded; the ordinary eleven left exactly as they were.
- **`director` — 2 remain and both are correct**: the live token, and a quoted design note reading
  "the HUD is currently the art director", which is a film-and-games role, not a process word.

The separating test, for reuse: **is "the user" the person operating the machine, or the person who
ordered the work?** The first is ordinary; only the second is a tell.

### A misquote found on the way

`.gitignore:59` attributed to `docs/DECISIONS.md` a LOCKED rule reading *"Never destroy anything the
user made"*. **That string does not occur in that file.** The real heading is `DECISIONS.md:404`,
"Never destroy a curated file". `DECISIONS.md` is written throughout in the impersonal voice — line 424
already reads "a public MIT-licensed repository of **one's own** game" — so `.gitignore` had paraphrased
its own source into the commissioner voice and then quoted the paraphrase. Both now match the source
verbatim. An invented quote attributed to a real document is worse than an unsourced claim, because it
is checkable and passes a casual check.

### Known gap, recorded rather than closed

Nothing gates this cell. Closing it needs the narrow token list externalised like the wide one, and that
**enlarges the open publication question** in `stand_downs.txt:72` rather than settling it — more of the
gate would live in a file that a fresh clone does not have. That is a call for the director, not a 3am
edit, so it is filed and left. The repairs above are unconditional and stand on their own.

### A second find, in the same edit: the stale-count guard's own stale count, again

Rewording `tools/check_doc_counts.gd:21` meant reading the worked example it carries, and the example had
rotted. It described the count as taken from "the **three** registration verbs", naming three function
definitions. `tools/run_harness.sh` has **four**: `add_excl_hl` at line 264, used once at line 330 for
`check_lock`, the layer that must run alone but needs no display.

The gate itself is correct. Its `_verb_pattern` derives verbs from the runner, and lines 106 to 110 record
precisely this incident:

    THE VERBS ARE DERIVED FROM THE RUNNER, and this function used to name three of them. `add_excl_hl` was
    added ... the total read 104 where the runner declared 105 ... A guard against stale counts, holding
    its own stale count of the things it counts.

So the fix landed in the code and in the note beneath it, and **the header comment eighty lines above was
never updated** — still naming three verbs, in the file whose own commentary names that exact failure. The
guard against stale counts held its own stale count in a second place, and the note describing the first
occurrence sat between them.

Repaired by removing the pinned pair of numbers rather than refreshing them, because refreshing them just
restarts the clock. It now states a **relation**, which was verified rather than asserted:

    bare `^add` in run_harness.sh   111
    their own function definitions    4
    111 - 4 = 107                       = the count the runner reports

so "overcounts by exactly those definitions" is exactly true today and stays true as layers are added.
The same reasoning is why the gate's rule is "any function that appends to NAMES" and why line 111 can say
"Adding a fifth requires no edit here" — the code was already derived; only the prose was pinned.

**The transferable bit:** a worked example inside a guard is prose, so nothing checks it, and it ages
faster than the code because it names totals the code deliberately does not. Where a comment must
illustrate with numbers, state the invariant that holds (`bare count minus definitions equals registered`)
rather than the reading that held once. This is the same shape as the rotted header found earlier in the
night, and it is now twice in two days, so it is a class and not an accident.

---

## RED, classified and NOT silenced: `check_material_grammar` asserts inside its own noise

Sweep R came back `106 PASS / 1 FAIL`, the first red in many sweeps, on a comment-only diff:

    FAIL: STRUCTURE, colour removed: dirt and stone are tellable apart 74.29% of the time
          over 70 lit windows (floor 75.00%, a coin is 50%)

The floor was not touched and must not be. Here is why it is nevertheless not a regression.

### The statistic is a count of windows, so it can only move in steps of 1.43 points

70 lit windows, so every reachable value is `k/70`. The floor of 75.00% is 52.5 windows, meaning the gate
requires 53 and the failing run scored 52. **The whole failure is one window.**

### Fifteen samples, and the layer has failed before

Five isolated re-runs on this exact tree, plus the same line recovered from every retained sweep log,
which carries it for free at ten different heads:

    full sweeps B..R (10)   51, 52, 53, 53, 53, 53, 53, 54, 54, 54      8 PASS, 2 FAIL
    isolated SF_ONLY (5)    51, 52, 53, 55, 56                          3 PASS, 2 FAIL

    full-sweep mean 75.71%   median 75.71%   floor 75.00%
    margin above the median  0.710 pp
    one window               1.4286 pp
    ==> the margin is 0.50 windows, against an observed spread of 5 windows
    4 of 15 samples (27%) land below the floor

**Sweep B failed at 72.86% before any of tonight's work.** This red is pre-existing, it fails about one
sweep in four, and it landed on mine. The diff that "caused" it is 20 lines of comments in nine files,
none of them this layer, a renderer, or a shader.

### The classification

Not a bound that is slightly too tight. **A bound placed inside the quantisation step of its own
statistic.** The gate's entire margin is half a window, on a measurement that cannot resolve less than a
whole one and empirically swings five. A gate whose margin is finer than the resolution of the instrument
feeding it cannot be reliably green, and its greens carry no more information than its reds. This is
[[unstable-threshold-statistics]] with the numbers attached, and it is the house failure class again from
the other side: not an instrument that cannot register its subject, but a THRESHOLD that cannot register
the difference between signal and its own rounding.

### What was deliberately NOT done

- **The floor was not lowered.** 74.29 is not evidence that 75.00 is wrong; it is evidence that a single
  sample cannot decide either way. Moving the floor to fit the sample would encode the noise as the spec.
- **No stand-down row, no SKIP.** The rule for the night is that a red does not disappear by being
  reclassified into a quieter category, and a flaky gate converted to a skip is the worst version of that.

### The repair, which is a backlog item and not a 4am edit

Raise n until the quantisation step is smaller than the margin, by pooling more placements, or assert on
a statistic pooled across placements rather than on one run's fraction. Both change what the layer
measures and belong in daylight with the ticket (TR-02) open next to them. Recorded as a known red:
**the sweep is 106/107 with one classified, pre-existing, intermittent failure**, and that is stated
rather than papered over in any verdict quoted from tonight.

### I went looking for more of the stale-count class and mostly found my own bad instrument

Having repaired one rotted worked example, the obvious next move was to census the rest. Six comment
lines pinning a layer count looked stale. **Four of the six were exactly right, and the measurement
saying otherwise was mine.**

    check_base.gd:97          "of the 86 layers inheriting this file, 29 call _verdict() and 57 ..."
                              measured 86 / 29 / 57                                       CORRECT
    check_hint_gate.gd:108    "all 86 layers that inherit it"                             CORRECT
    harness_verdict.sh:286    "29 of the 86 layers inheriting check_base.gd"              CORRECT
    check_base_namespace.sh:13 "there are 103 of them here"      its gate prints 103       CORRECT
    check_verdict_claims.gd:23 "30 of 98 layers call _verdict()"  layer reports 96 today   mildly stale
    run_harness.sh:116        "ALL 103 HARNESS LAYERS PASS over 103 layers"  runner has 107  STALE

My first pass reported 31 `_verdict()` callers against the comments' 29. The grep counted the definition
site and non-`.gd` files. Restricted to the population the claim is actually about, it is 29 — the number
written in the comment.

Then the same thing again, one minute later and worse. `check_base_namespace.sh:13` says 103 subclasses
where I measured 86, so I had it as stale. **The gate prints 103 at runtime.** Its population is

    grep -rlE '^[[:space:]]*extends ... res://tools/check_base\.gd' "$ROOT/tools" "$ROOT/tests" --include='*.gd'

a `grep -r` over the WORKING TREE. Mine was `git ls-files`, the index. The gap is exactly the **17
untracked local probes** on this machine — scratch copies of layers under investigation, which
`check_save_isolation.gd:77` already documents as a normal thing to have lying around.

Two consequences, and the second is the keeper:

- **I nearly filed four correct comments as defects.** Every one of the four would have been "fixed" into
  being wrong. The instrument that hunts stale claims produced stale claims, which is the night's house
  class landing on the person hunting it. See [[scrutiny-asymmetry]]: the suspicion felt like rigour.
- **`git ls-files` and `grep -r` are different populations and the difference is not noise.** One answers
  about the artifact, the other about this machine. That gate's 103 is machine-scoped by construction: a
  fresh clone or CI checks 86 of them. Not a defect — a local probe that shadows a base member really
  does break your local run, so checking it is right — but **the number it prints is not a property of
  the repository**, and any doc quoting it as one would be wrong on every other machine. Same distinction
  as `check-ignore` measuring the machine rather than the artifact.

So the class is real and it is **two sites, not six**, and both are left for daylight rather than folded
into a commit about voice. `run_harness.sh:116` is the clear one: a hypothetical about the current runner
pinned at 103 when it registers 107.

### Correction to the section above: this red was already classified, and I re-derived it blind

The classification stands and the numbers reproduce, but it was not a discovery. The same layer had been
characterised on 2026-08-21 with a pooled n=16, the same median of 53, the same "do not move the floor",
and a sharper way of saying it than mine. Pooling all three investigations: **median 53, about 30% below
the floor.** The standing rule is that a red earns autonomous capacity only while it produces new causal
information; this one was already instrument-corrected and classified, and I spent a sweep plus five
isolated runs re-deriving it because I did not check first.

Two things to keep from the rework rather than from the result:

- **Say the bound in windows.** Every readout is `k/70`, so **75.00% is 52.5 windows and is not a value
  the layer can return.** The failing run scored 52 where 53 is required. Reported as "74.29% against a
  75.00% floor" a one-window miss reads as a measured shortfall; reported as "52 of 70, needs 53" the
  entire argument is in the sentence and no analysis is required to see it.
- **The one genuinely new fact, and it closes a candidate rather than opening one.** The earlier work saw
  a wider spread on a busy box and named machine load as the live mechanism. My groups invert the sign:
  ten full parallel sweeps at JOBS=12 span 51-54, five isolated runs on an idle box span 51-56. Two
  batches disagreeing on the *direction* of a load effect, with means 53.1 and 53.4, means load is not the
  mechanism and the spread is the instrument's own.

Also worth the note: ten of those fifteen samples cost nothing. The statistic is printed in every retained
per-layer log, so ten readings at ten different heads came out of one `grep` over the kept sweep
directories. Retained logs are a regression history for statistics, not only for failures.

---

## The two filed pins, closed — and the population is the measurement

Both sites filed earlier as "left for daylight" turned out cheap to close correctly, because the evidence
was already on disk. A peer declined to verify the second one and gave the right reason: checking "98"
needs a layer count, and the only cheap static ways to get one are `git ls-files` or a tree walk — **the
exact pair that made my `check_base_namespace` reading wrong an hour earlier.** A static count would have
reproduced my own failure mode and agreed with itself.

The answer was not to count more carefully. It was to **stop counting and read the gate's own runtime
output**, which sweep S had already written to a per-layer log:

    PASS: the scan actually read the suite (96 layers)

### `check_verdict_claims.gd:23`

Comment pinned "30 of 98 layers call `_verdict()`" and "88 of 98 call `_check()`". Derived over the
population that layer actually scans — `DirAccess` over `res://tools/` for `check_*.gd`, **skipping its
own file**, which is 97 on disk minus itself and reconciles exactly with the 96 it prints:

    call _verdict()    29 of 96   30%      comment: 30 of 98   31%
    call _check()      86 of 96   90%      comment: 88 of 98   90%

**Only the totals moved; the argument was never wrong.** "Blind to two thirds of the tree on one axis and
a tenth on the other" is 70% and 10% today, exactly as written. Restated as proportions.

### `run_harness.sh:116`

"ALL 103 HARNESS LAYERS PASS over 103 layers that never ran" against a registered 107. A hypothetical
about output, so nothing behaves on it, but a stale total inside the warning about **silent all-pass
lines** is the last place to carry one. Restated with no total; the count is derived from the registration
verbs a few lines below.

### What the whole thread was actually about

Every single error in this sequence, mine and the peer's, was a **population** error, and none was an
arithmetic one:

    the suggested fix          measured over 523 paths; the matcher's domain is 570
    my "31 _verdict callers"   counted the definition site and non-.gd files
    my "86 subclasses"         read the index; that gate walks the working tree (103, gap = 17 probes)
    my pinned-count census     `-E` with `\s`, which matches zero-width, so only unindented comments
    the peer's declined check  refused precisely because both cheap populations were known-wrong

The arithmetic was never in doubt. **The question is always which set of things the number is about**, and
the reliable answer is not a better grep, it is the gate's own definition of its population — read from
its source, or better, from what it prints at runtime. Four comments suspected of rot survived this
treatment unchanged, including `check_base_namespace.sh:13`'s "103", which a naive count puts at 86.

---

## Sweep T: a SECOND red, and this one is not a flaky statistic

    106 PASS / 1 FAIL   FAILED: check_ceremony_reads   HARNESS_EXIT=1
    HARNESS_RESULT=no   THIS RUN IS NOT A RESULT. Do not read the verdict -- re-run it.

Two symptoms, one cause. `HARNESS_RESULT=no` is a **consequence** of the failure, not a second problem:
the layer owns two registered stand-down rows, and failing short-circuited it before it could resolve
either, so both came back UNACCOUNTED and the verdict gate correctly refused to be quotable. That is the
three-valued accounting doing exactly its job — a layer that dies mid-way has not said "skip" or "held",
it has said nothing, and nothing is not a pass.

### It is not noise, and the retained logs say so in one line

    FAIL: the reference frame carries no interrupt of its own (waited 600 frames; arrival 0.00, hint 1.00)

Pulled from every retained sweep, the same assertion at twelve earlier heads:

    sweeps A,B,J,K,L,M,N,O,P,Q,R,S    PASS   waited 146-147 frames   hint 0.00     (12 of 12)
    sweep T                           FAIL   waited 600 frames       hint 1.00

**600 is the wait cap.** Twelve runs settle at 146 and the thirteenth runs out the clock with the hint
still up, so the exit condition never fired. That is a different shape from the `check_material_grammar`
red entirely: not a statistic straddling a bound, but a wait that did not end.

### It is not the tree either

Three isolated `SF_ONLY` runs on the exact failing tree: **PASS at 146, 147, 147, hint 0.00.** The only
edits between the last green sweep and this one are two comment blocks in `check_verdict_claims.gd` and
`run_harness.sh`, neither of which is this layer, the game, or a renderer.

**So it reproduces only inside the parallel sweep.** Fifteen samples say the tree is clean and one says
the sweep is not.

### The candidate channel, stated as a candidate

`scenes/hints.gd:11` — *"Shown hints latch, and the latches persist through a save"* — and :270 keeps a
`_done` record written to disk so a save can carry it. Meanwhile:

    add_gl "check_ceremony_reads (interrupt vs world)"   <- needs a surface, NOT exclusive
    add    "check_hint_gate (lesson waits)"              <- plain, runs concurrently

Eleven layers touch hints, all 107 share one `user://` inside a repo root, and this layer is not
registered `add_excl`. That is a real persistence channel between concurrent layers and it would explain a
hint being up in a frame that is supposed to be clean.

**What is NOT established: that any specific layer actually wrote the state that flipped it.** The channel
is documented and the layer is non-exclusive; the writer is unidentified. Confirming a mechanism exists is
not confirming this run took it, and the honest form of this finding stops here rather than naming a
culprit that would then be "confirmed" by everyone reading the note afterwards.

### Action

Re-ran the sweep, which is what the runner itself instructs on `HARNESS_RESULT=no`. **No bound was moved,
no row was added, and `check_ceremony_reads` was not made exclusive** — registering a layer `add_excl`
changes sweep scheduling and wall-clock for every future run, and doing that to make a red go away, at
this hour, with the writer unidentified, is precisely the move the night's rule forbids. Recorded as a
known intermittent, with the same standing as the other: real, pre-existing in its channel, and owed a
daylight fix rather than a quiet one.

### CORRECTION to the section above: wrong mechanism, and the error is instructive

The persisted-state channel is **withdrawn**. A peer refuted it from source and every claim verified:
`QUIET_MAX` is 600 frames = 10.000 s, a fired hint needs 8.994 s to fade, so there is a **1.006 s launch
window** and missing it makes the wait unsatisfiable. Arithmetic, unconditional, no rerun required. The
twelve greens exit at 2.43 s with `hint 0.00`, which is far too early for a bubble to have faded, so **no
bubble fired in any of them** — the pass/fail split is between two populations, not two draws from one
distribution. Full detail is now in the `constant-must-dominate-constant` memory.

My channel was not just unproven, it was **impossible in two independent ways**: `_done` gates a hint's
*firing*, so contamination would suppress a bubble rather than raise one (wrong sign), and `_done` only
persists through a save while this layer's sole `load(` is `load(SCENE)` (path closed). Both were
checkable in ten minutes from the same file I had already quoted.

**The lesson is one step past the one I thought I had learned.** I deliberately refused to name which
layer wrote the state, and was pleased with that restraint — but I still recorded the channel as *the*
candidate, and a candidate written into a handoff becomes the accepted cause for the next reader. Refusing
to name a culprit is not enough. **Before offering a channel at all, ask whether it can produce the
observed sign, and whether the subject can even reach it.** A channel that is real, documented, and
incapable of causing the symptom is worse than no hypothesis, because it looks like progress and it
retires the question.

Worth noting where the peer's own first instinct went: a two-clock story about physics frames versus
`_process`. Also wrong — the clocks agree, the constants do not. Two sessions, two plausible mechanisms,
one arithmetic fact underneath both.

### Third pass on the same red: the refutation had the same defect as the thing it refuted

Two claims from the correction above are withdrawn, and the peer withdrew them himself. `active_alpha()`
returns 0.0 under `_ceremony` or `_busy` (`hints.gd:263`) and the wait exits on `alpha <= 0.01`, so **a
freeze makes the layer pass, not hang** — "unbounded under a ceremony" is wrong. And `alpha 0.00` has five
readings, so a hidden bubble reads 0.00 too: the twelve greens are *consistent with* no bubble rather than
proof of it, which means my original reading of them was not the error it was called.

The surviving mechanism is sharper than either wrong one. A frozen bubble "arrives with its full life the
moment the body settles" (`hints.gd:261`), so the freeze **defers**: 146 settle + 540 decay = **686 frames
required against a 600 cap**. `QUIET_MAX` owes the settle *and* the bubble, not the bubble alone.

**The tally for this one red: three diagnoses, two of them wrong, and the arithmetic never moved.** Mine
was a channel with the wrong sign down a closed path. The refutation was a mechanism that predicts the
opposite of the observed value. Both were offered by someone who had just articulated the rule the other
had broken.

**The one-line screen neither of us ran, on opposite sides of the same thread an hour apart:** *before
offering a mechanism, compute what the observable would read if that mechanism fired.* `_ceremony`
predicts `alpha 0.00`. The failure printed `1.00`. Ten seconds of arithmetic.

And one more, which I flagged back rather than accepting: the replacement model's own confirming detail —
that it reproduces `hint 1.00` at the cap — is nearly vacuous, because **alpha reads exactly 1.00 for 91%
of a visible bubble's life**. A matched observable that is 91% likely under the hypothesis is not a test.
The frame count is the evidence; the alpha match is decoration. Same class as the guard that cannot be
false, arriving this time as a prediction that cannot be wrong.
