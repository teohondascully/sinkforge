> **ARCHIVED 2026-08-27.** Untracked since the 2026-08-25 pivot despite `docs/archive/PIVOT_PLAN_2026-08-25.md`
> §1 recommending KEEP as-is. The doc set that actually shipped (`docs/README.md`'s normative table) is
> smaller than the plan recommended — a later, real decision, not corrected here. Describes the
> two-session handoff protocol that ANVIL's own session registry (§8) is meant to subsume. Moved here
> while closing the `.git/info/exclude` hole (ANVIL step 1). Kept for provenance.

---

# SINKFORGE — session protocol

> **THE PROTOCOL IS THREE RULES (user reset, 2026-08-19). Everything below this block is history and
> rationale, not procedure. Where the two disagree, these three win.**
>
> 1. **One owner per file or lane.**
> 2. **All Godot/test runs go through `tools/with_machine.sh`.**
> 3. **Only HALT, WATCH and integration conflicts use the director bus.** Ordinary work goes in the trace
>    logs and in normal agent-to-agent messages.
>
> **A protocol violation is not a project-level incident.** Record it in the trace, correct the behaviour,
> continue. Escalate only when it touches **source integrity, evidence validity, user data, or
> attribution**.
>
> **Production ratio: at least 80% of time on game code, visual changes, or player-facing evaluation; at
> most 20% on harness or process**, unless a genuine safety defect is blocking production. No new harness
> expansion unless it is required to close the currently assigned item.
>
> *Why: the harness caught real defects — invalid assertions, contaminated measurements, false causal
> claims, unsafe coordination — and then crossed from protective infrastructure into self-consuming work.
> The bottleneck stopped being engineering ability and became governance overhead. Harvest the lessons,
> simplify, ship player-facing milestones.*

Two agent sessions working the same repository at the same time, coordinating by explicit message rather
than by luck. This document is the protocol. It was written the night it first worked, from what actually
happened, including the parts that nearly went wrong.

## What this is called

**There is no single established name for it.** Do not go looking for one. The nearest real analogues each
cover about a third of it:

- **Pair / ensemble programming** — two minds on one artifact. Covers the collaboration, not the concurrency.
- **Contract-based concurrent development** — declared ownership of files. Covers the writes, not the shared
  machine.
- **Mutual exclusion** — one holder of a resource at a time. Covers the machine, not the judgement.

In multi-agent terms it is peer-to-peer coordination with explicit resource arbitration and adversarial
verification. Within this repo it is **the peer-session protocol**, and the two roles are just *peers* —
neither is subordinate. There is no orchestrator here; an orchestrator directs subagents it spawned and can
stop, which is a different thing with different rules.

### When a director is present

The peer relation stays intact: **C1 and C2 remain independent implementers and reviewers, not a chain of
command.** A director is an additional, deliberately narrow role used when the project needs a continuous
view across both lanes and the game’s design intent. The director does not replace peer verification,
silently take an agent’s files, or turn an acknowledgement into proof.

The director’s job is to:

- maintain the ordered game-facing priority and identify dependencies or scope drift before a lane invests
  deeply in the wrong problem;
- read each agent’s *actual checkout*, current diff, trace, and test/mutation evidence rather than relying
  on summaries or the root checkout’s stale copy of a worktree file;
- set the evidence bar for a claim: the production subject is reached, the assertion reaches its final
  verdict, a hostile mutation fails for the claimed reason, and a green is attached to an identified,
  frozen tree;
- make the design calls that connect implementation to player experience — especially the next desire,
  manual pain retired by automation, and visible world consequence — while reserving vision-level forks for
  the user;
- issue only small, durable directives through the Director Bus (`docs/DIRECTOR_BUS.md`): **INFO**, **WATCH**,
  **REDIRECT**, **HALT**, or **USER_DECISION**. A directive must name its priority, the observed evidence,
  the required correction, and what would close it;
- stop unsafe integration: shared-tree mutations during a run, save-risking tests, floor-lowering to buy
  green, destructive Git recovery, or a branch whose base has gone stale enough that it cannot be merged
  honestly.

The director does **not** use the Bus as a task tracker, a substitute for a design document, or a reason to
interrupt working code with preference churn. An ACK means *the agent saw the instruction*, not *the defect
is fixed*. The director resolves a directive only after inspecting the resulting artifact and its evidence.
The user remains the authority for a genuine vision fork, external action, or a change to project-level
constraints.

This changes the development approach in one precise way: implementation is no longer judged only by
whether its scripted actor reached a milestone. It is judged first by whether a player can form the intended
next desire without being told, then by the peer’s independent re-derivation, then by the relevant automated
evidence. The harness protects facts; the peers protect reasoning; the director protects the game’s through
line. None replaces the others.

## Why it is worth the overhead

Two sessions on one repo is a hazard by default. Every rule below exists because the failure it prevents is
real and cheap to trigger. What makes it worth doing anyway is that a peer is the only reviewer who will
independently *re-derive* your result instead of reading it. On the night this was written, a peer took a
measurement one session had produced, followed it to a conclusion that session had not reached yet, and
fixed the underlying defect — and the first session then verified the peer's commit was byte-identical to
the tree it had tested rather than taking its word. Neither half would have happened alone.

---

## The rules

### 1. Announce ownership before you write

State what you have in flight, in which files, and whether you intend to commit it yourself. Ask the same.

**Never `git add -A`.** Stage by explicit path, always. The whole hazard collapses to this one command: it
sweeps up the other session's half-finished work and commits it under your message. Everything else in this
document is recoverable; that is the one that silently destroys attribution and bisectability at once.

**The lock now carries a claim, and the reason is a message I sent while looking at one.** It used to print
`waiting for the harness lock (held by pid 65489)`, which required a `ps` on another terminal to learn what
was running and whether it was nearly done — and a lock that makes you go and look is a lock that gets
overridden. The owner file has four lines (pid, tree, what is running, when it started) and both waiters
print `held by pid 65489 running check_material_grammar.gd in capture-deafness for 254s`. Lines 1 and 2 are
unchanged because the stale-holder check is `head -1`; an owner file written by an older copy of either
script simply has no lines 3-4 and those fields are left out rather than printed as question marks. **The
two durations are printed separately** — how long the holder has held, and how long this run has waited —
because collapsing them is how "held for 900s" gets read as a wedged lock when it is a long layer that
started ten seconds ago.

**The Bash tool clamps a command's timeout to 600s whatever you pass.** `c1` requested 900000 ms twice and
silently got 600 s both times. **The symptom to recognise is `Command timed out after 10m 0s` when you
asked for fifteen** — there is no indication anywhere that the request was reduced, so it reads as a hung
run rather than a truncated one. Anything that can
exceed ten minutes — a full sweep behind a held lock, a slow layer, a capture batch — has to be
backgrounded rather than given a longer timeout. **And a backgrounded command's exit code is the last
command in its pipeline**, so `cmd > f 2>&1; echo $?; tail f` reports `tail`'s status; that one is already
in the harness exit-code notes and it still caught `c2` tonight, four hours after reading it, while
hunting for exactly that class. Naming a failure mode does not inoculate you against it.

**Do not edit a script while it is executing.** Bash reads incrementally from a byte offset, so an edit
makes the running shell resume inside the new text at the old position — it does not crash cleanly, it
produces a plausible error about something else (`lock_claim: command not found`, for a function defined a
hundred lines above its use). GDScript has the twin: a parse error introduced into a scene dependency does
not abort the run, it loads the scene with the class unresolvable and prints the consequence every frame —
one real cause under sixty-seven thousand copies of `Nonexistent function 'set_aim' in base 'Nil'`. The
bash one is more dangerous because a mixed-version run can FINISH and be believed; `run_harness.sh` now
checksums itself at start and exit and says so if the bytes moved. The GDScript one is cheaper to prevent:
`godot --headless --check-only --script res://path.gd --quit` on every file you touched, as a step and not
as an intention.

### 2. Announce the machine, with a purpose and a duration

Long-running shared resources — the harness, a capture sweep, anything that boots the engine — get claimed
out loud: *what for, roughly how long*. The holder says **"clear"** when done. Everyone else stays off.

This is not politeness, it is correctness. In this project **Godot keys `user://` on the project NAME, not
the directory, so git worktrees do NOT isolate the save slot, the sentinel, or the test fixtures.** Two
concurrent harness runs corrupt each other's state. That produced a phantom `THE SAVE SLOT WAS DELETED`
alarm — the loudest alarm the repo has — and cost two sessions an investigation each. It can equally produce
a **false GREEN**, which is worse, because nobody investigates a green.

A result produced while another session was running is not a result. Re-run it exclusively before believing
it, and say in the report that you did.

### 3. Send evidence, not conclusions

A peer message that says "I fixed the lighting" is nearly useless. One that says "pristine layer on 1337
reads 2.21x PASS; the median version at 0.46 reads 1.87x FAIL against a floor of 2.0; 86 x 0.54 = 46.4
confirms it is the model and not the measurement" can be checked, and was.

Include the numbers, the command, and the seed. Assume the peer will re-run it — and re-run theirs.

**And this rule is hardest to obey where it matters most, because a NEGATIVE result has no numbers.** Every
example above is a measurement that found something. When the finding is an absence — "the logs are gone",
"that symbol does not exist", "no ref carries it" — there is nothing to paste, the rule reads as
inapplicable, and what gets sent is the conclusion alone. **For a negative result the command IS the
evidence, and it is the only evidence there is.**

This cost a real edit. One session reported *"the harness log directory is already gone, so the logs do not
outlive the run"*, on the strength of `ls -dt ${TMPDIR}/*harness*` returning nothing — the directory is
`mktemp`'s default `tmp.XXXXXX` and contains no such word, and 94 log files were sitting in it. The peer read
the runner's source, wrote down that the code was correct, **invented an unmeasured mechanism to keep the
reported defect alive** ("macOS reaps `/var/folders`"), and was three lines into relocating the log directory
when the retraction arrived.

Note what had to happen: a confident report from a peer **outweighed the source in front of them**. A
cross-session finding arrives wearing the authority of a second opinion while being a single uncontrolled
observation. Had the message said *"`ls -dt ${TMPDIR}/*harness*` returns nothing"* instead of *"it is gone"*,
the hole is visible in one second, because the runner prints the real path in its own output.

So: **state the command, not the conclusion** — and before a zero-result search becomes a claim at all, run
the weaker search that must return something. `ls` the parent before declaring a directory missing. If the
weaker search is also empty, the instrument is wrong, not the world.

### 4. Verify the peer; do not trust it

The peer is a careful colleague, not an oracle. When it reports a commit, check the commit. When it reports
a measurement, check that the thing it measured is the thing you are about to build on. The specific check
that mattered here: *is the committed tree byte-identical to the tree I ran the harness against?* — because
a green suite against an intermediate state is a rumour, not a gate.

This cuts both ways and is not an insult. Say plainly when the peer was right and you were wrong; it is
cheaper than defending a bad position to a peer who has the measurement.

### 5. Land coupled changes together

If change A alone leaves the build red and change B alone leaves the build red, they are one change and
must land in one commit — even when they are owned by different sessions and live in different files.

An instrument that reveals a defect and the fix for that defect are the canonical case. Whoever commits
credits the other explicitly in the message, by contribution, not by courtesy.

### 6. One owner per durable document

Shared logs (`docs/handoff/AUDIT_UPDATE.md` here) have exactly one writer. Peers send paragraphs to the
owner instead of co-editing. Two sessions editing one narrative file is the `git add -A` hazard in slower
motion, and it corrupts the one artifact you would use to reconstruct what happened.

New files are free — a peer opening `docs/MATERIAL_SPINE.md` collides with nobody.

### 7. Mark provisional work as provisional

A change supported by a number and two A/B captures is a good bet, not a settled question. Say which it is.
Anything reversible-in-one-constant should be labelled as such so a later session knows the cost of undoing
it.

### 8. Do not run the test whose answer you want

Once both peers know which result they are hoping for, neither should be the one to run the judgement call.
Hand perceptual and "does it read" questions to a fresh zero-context agent. Agreement between two sessions
that have been reasoning together for hours is not independent evidence — it is the same reasoning twice.

---

## The failure modes, named

Keep these in view; each one actually occurred or came within one command of occurring.

| Failure | How it shows up | Prevention |
|---|---|---|
| Attribution loss | `git add -A` commits the peer's WIP under your message | Stage by path |
| Phantom alarm | Sentinel reports the save slot deleted; nothing is wrong | Announce the machine |
| **False green** | Two runs corrupt each other's fixtures and the suite passes | Exclusive runs only |
| Split-red commit | Instrument lands without its fix; main is red for everyone | Land coupled changes together |
| Log corruption | Two sessions interleave edits in the strike log | One owner per document |
| Shared delusion | Both peers agree because they reasoned together | Fresh agent judges |

### 9. Reproduce an alarm with a second instrument before acting on it

Twice in one night an instrument reported a catastrophe that had not happened. The sentinel reported
`THE SAVE SLOT WAS DELETED BY THE HARNESS` (two concurrent runs, nothing lost). A peer reported every
`_moment_*.png` capture gone — all 44 were present, and `ls` is aliased to `eza --icons`, whose output
begins with permissions, so `ls -a | grep -c '^_moment'` returns 0 no matter how many files exist.

Before acting, re-measure with a **differently implemented** tool: `find` and `stat`, not `ls | grep`.

**And check whether the remedy is destructive when the alarm is wrong.** The proposed fix for the missing
captures was to regenerate them — which would have overwritten `_moment_delve.png`, the only frame taken
before the lighting change, with one taken after it. The baseline would have been destroyed by the attempt
to protect it, and the later comparison would have silently compared the new render against itself.

> If the remedy is worse than the doubt when the alarm is false, verify twice before you act once.

### 10. Split the board into lanes before either peer builds momentum

The moment both sessions are working autonomously, **stop and divide the list before doing anything else.**
Two unsupervised peers on one repo will otherwise converge on the same interesting problem — the
interesting problems are interesting to both of you — and you find out only when the diffs collide.

What a working split looks like:

- **Post your whole list, in order, and ask for theirs.** Diff them explicitly. Do not assume that because
  the lists are worded differently they do not overlap; ours had "CI render/perf coverage" on one side and
  "merge the CI worktree" on the other, which is the same job under two names.
- **Lanes follow context, not fairness.** Whoever already has the context for a lane takes it. Nobody is
  owed an equal share; the goal is throughput, not symmetry.
- **Name the files each lane owns, and the ones you will not touch.** "I stay out of `run_harness.sh` and
  `AUDIT_UPDATE.md`" is worth more than any amount of good intent.
- **Hand over documents, do not co-own them.** When a peer's work becomes the main content of a file, give
  them the file outright. `DECISIONS.md` moved that way and stopped being a hazard the moment it did.
- **Name what neither of you takes, and why.** Ours was "rock legibility is blocked on a blind-vision pass
  we both agreed not to run tonight." Unclaimed-and-stated beats unclaimed-and-forgotten.
- **Announce a dependency between lanes rather than discovering it.** "Wait for my merge before you build
  CI render coverage" saved that job being written twice.
- **Say which TREE, not just which file.** File ownership and tree ownership are different claims, and
  agreeing perfectly on the first does not prevent a collision in the second. A peer told me "I have
  edited `docs/PRIORITY.md`" — correct under our split, that file was theirs — and wrote it into the main
  checkout, on `main`, in my working tree, while I was mid-sweep and nine commits ahead of origin. For
  about four minutes my `git status` carried a modification I did not make. They caught it themselves,
  saved the diff to a patch first, confirmed it was 48 insertions and zero deletions so none of my content
  could be lost, applied it in their own worktree, and only then reverted my copy.
  Two things this taught that nothing above covers:
  - **An uncommitted write into a peer's checkout is invisible to every rule we have.** It is not a commit,
    so no hook sees it; it is not a push, so no remote sees it; and the file was legitimately theirs, so
    ownership was never violated. The only reason it surfaced is that the lock owner file names its repo
    root, which made them check where their edits had been landing.
  - **You write to what you have been reading.** They had been reading the main copy of a doc all session
    because it was not in their worktree, and then wrote to the copy they had open. That is not
    carelessness, it is the default behaviour of having two checkouts, and it needs a mechanical answer
    rather than more care: say the absolute path when you claim a file, and check `git rev-parse
    --show-toplevel` before writing to one you have only been reading.

  **The isolation cuts both ways, and that is the fact both of us were missing.** The second instance ran
  in the opposite direction: `c2` committed into the root checkout while `c1` held the harness lock, and
  spent a message apologising for a contamination that could not have happened — `c1` runs from
  `.claude/worktrees/capture-deafness`, and a git worktree shares `.git` and nothing else. One session
  reached across trees and did damage; the other assumed it had and had not. **The lock protects the BOX;
  the worktree protects the FILES; neither protects the other** (`c1`'s formulation). Which means the
  claim to make out loud is a pair — *which tree, and do I hold the box* — and the check before worrying
  is one command: `git merge-base --is-ancestor <sha> HEAD` in the tree you are actually worried about.

Re-sync whenever the instruction changes. A split made under one mandate does not survive a new one.

### 11. Choose hostile mutations, and let the peer re-run yours

A new guard must be proven able to fail — but *how* you break the code decides what you have proven. A
peer put it best, and it generalises well past peer review:

> **My mutation proved the layer could go red, not that it could go red for the right reason. Choosing the
> mutation that's convenient to write is a way of grading your own homework.**

The concrete case: a new economy guard was proven red by *deleting* two lines of source. A peer instead
*commented them out* — how a person actually disables something — and the layer stayed **green** over a
game that was now unwinnable, because the guard regexed source text and a regex cannot tell live code from
dead code.

So: pick the mutation you would least like to survive, not the one that is easy to script. Prefer the edit
a real person would make. And hand your mutations to the peer to re-run — a mutation invented while
holding the fix in your head is drawn from the same distribution as the fix.

### 12. Keep a shared list of the shapes you have been fooled by

Vacuity has recurring shapes, and naming them makes the next one findable. The running list from one night:

1. **An assertion that cannot fail in the environment it runs in** — two blank textures compared headless.
2. **An assertion inside a loop that may not iterate** — driven by the very constant it is testing.
3. **A floor no configuration of the model can reach**, passing on measurement noise.
4. **A test that sets the value it then observes** — every audio layer set `muted` before reading it, so
   the suite asserting "can you tell what happened with your eyes shut" answered *yes* for months about a
   game that shipped silent.
5. **A set of checks that are all true and all about the wrong thing.** This one is the most dangerous
   because it survives diligence — the more checks you run, the more confident it makes you. Two instances
   in one hour:

   - A peer's commit was silently deleted by `git pull --rebase`. They checked `git status` (clean),
     `git log` (healthy), and the push exit code (0). All three TRUE. All three about something other than
     "is my change in the tree." The only check that would have caught it was reading the file they
     claimed to have changed.
   - A full harness run reported exit 0, 58 PASS / 0 FAIL, and `save_sentinel: verified — the production
     slot is untouched`. All TRUE. All about a tree that had been edited out from under the run 58 seconds
     in (see rule 14). The only check that would have caught it was `git status` *during* the run, which
     nobody runs, because the tree was clean when it started.

   The tell is that every check is a *status* check and none is an *identity* check. Ask "does this
   verify the thing I actually claim?" — not "did it pass?"
6. **An assertion gated behind an opt-in that nobody ever opted into.** The code is correct, the guard is
   well-designed, the reasoning is documented — and it has never once executed.

   `check_frametime` contains `FRAME_BUDGET_MS = 1000.0 / 120.0` and an `_absolute()` that asserts p95 ≤
   8.33 ms per phase. It is careful work: it runs *only* where `SF_PERF_HOST` names the machine, refuses
   to assert on unnamed hardware and says so in its output, and even fails on named hardware whose frames
   are vsync-pinned rather than reporting the monitor's refresh rate as a game metric.

   `SF_PERF_HOST` was unset everywhere — locally, in CI, in every script. So for the entire life of that
   code the layer printed `absolute: NOT ASSERTED` and moved on, and the project's only 120 fps assertion
   sat behind an environment variable no one set. The first time anyone exported it, three of four phases
   were over budget and the absolute check failed immediately.

   The tell: **an assertion whose output has a "not asserted" branch that nobody has ever seen NOT taken.**
   Grep for the flag that enables it and count the places it is set. If the answer is zero, the guard is
   decoration. Skip-by-default is the right design for hardware-dependent checks — it just needs someone
   to actually name the hardware, and a line in the setup notes is not that someone.

   *How this entry got written is itself the lesson.* One peer grepped the file, matched the header
   sentence "it never compared anything to 8.33ms", and reported to the other that the absolute budget did
   not exist and had to be built. That sentence was the header **narrating a bug it had already fixed**;
   the fix was described eight lines further down. A confident, forcefully-argued, entirely wrong finding,
   from reading one matched line instead of the file. The peer caught it in one message. *Grep tells you a
   string is present, never what it means — and past-tense prose in a header is a trap laid for exactly
   this.*

7. **A guard that tells you your data is meaningless, while you reason with the data anyway.**

   `check_frametime` printed, in as many words, *"vsync is pacing these frames and the millisecond numbers
   describe the monitor, not the game."* A peer quoted that line in a report — and in the next paragraph
   compared those same milliseconds against a historical 19.8 ms figure and concluded there had been a
   1.7× regression. There had not. The measured 33.16 ms is almost exactly 4 × 8.33, a refresh-interval
   multiple; under vsync a true 19.8 ms frame reports ~25 ms, so the two numbers were never on the same
   scale.

   They caught it themselves within the hour and retracted it unprompted, which is the behaviour that
   makes this list possible. But note the asymmetry that caused it, because it is general:

   > **The warning is prose and the number is data.** Numbers get compared, copied into tables, and
   > reasoned with; the sentence next to them explaining that they are meaningless does not survive the
   > trip. When a measurement is invalid, the instrument should refuse to *print the number* — not print
   > it with a caveat.

   Distinguish the fixes, because these shapes keep recurring and each needs a different one:

   | shape | what's broken | fix |
   |---|---|---|
   | unreachable floor (`CONTRAST_FLOOR`) | floor no configuration can reach; passes on noise | fix the model, or the floor |
   | sets-then-observes (the audio layers) | the test authored the value it checked | fix the test |
   | never-enabled opt-in (`_absolute`) | the assertion is correct and never ran | set the flag; count where it is set |
   | caveated bad number | the instrument printed data it had just declared invalid | suppress the number, not just annotate it |

8. **A check present on one of two paths through the same data.** Harder to see than a missing check,
   because grepping for it *finds* it.

   `FallingItems` drops are consumed twice inside `world_renderer.gd`. The veil pass iterates
   `falling.motes()` and culls them against the view (`if cull.has_point(fpos)`). Eighty lines later the
   light pass iterates **the same collection** and culls nothing. Anyone auditing "do we cull falling
   items?" greps, finds the cull, and moves on satisfied. The same shape covered `FallingItems.draw()`,
   which had no cull at all while `MAX_ITEMS = 240` and each drop paints ~10 primitives — up to ~2400 draw
   calls for items that may all be off-screen, in the *common* case of a factory left running upstairs
   while you mine somewhere else.

   The audit question is not "is this data culled?" but **"how many places consume this data, and is each
   one culled?"** Enumerate the consumers first; the answer to the second question is only meaningful
   once you know the count.

9. **The coupling you had no reason to look for — run the whole suite anyway.**

   Not a vacuity shape but it belongs beside them, because it is the failure that survives every good
   habit on this list. A peer added Bazaar ruins, wrote a *new* layer for it, mutation-tested that layer,
   and pushed green. The commit broke `check_save_frontier` — an unrelated layer, three layers into the
   suite — because the change added a field to `FactorySim`, and **adding a field to the sim is a
   save-system event**. Nothing about writing a draw-culling test tells you to think about the save
   envelope.

   > Care about the change in front of you does not substitute for the suite. The coupling that bites is
   > the one you had no reason to suspect, and the only thing that finds it is running everything.

10. **A benchmark that exercises the cheap branch and reports the function as cheap.**

    An optimisation to the fine-terrain bake measured `1671ms → 1687ms`: no change, hypothesis apparently
    dead. The hypothesis was fine. The fixture was timing the *Callable reference object* rather than the
    bulk path the optimisation had added, so it re-measured the old route with great precision both times.
    A performance fixture must be made to prove **which branch it took**, not merely that it ran — the same
    discipline as proving an assertion can fail, applied to a number instead of a boolean.

11. **A check whose N grew after it was written.** Shape 8 with a clock on it, and the reason 8 recurs.

    `check_save_isolation` refuses to let the save sentinel be registered as a parallel harness layer. It
    hunted for `add ` and `add_gl `. Both were complete when written. Then a session added `add_excl` to
    the runner — *the same session that had been cataloguing these shapes* — and the gate went on printing
    PASS while covering two of three registration paths. Nothing turned red, because nothing was broken;
    the check simply stopped being exhaustive, silently, at the moment the codebase grew a third door.

    The fix is not a third string. **Derive the set from the source of truth and assert you covered all of
    it**: anything appending to `NAMES` is a registration verb, by definition, and the floor is *"every
    appending line resolved to a verb"* — never *"at least three"*, which repeats the same mistake one
    level up. A hardcoded count is a snapshot of the code on the day it was written.

    > Any test containing a hand-written list of the ways something can happen is a test with an
    > expiry date, and nothing prints the date.

12. **A test that raced its own subject and reported the win.**

    Proving the harness cleans up after an aborted run: start a run, signal it mid-sweep, assert the
    production slot is clean. It printed clean. The run had **finished in 5 seconds before the signal
    landed**, cleaned up by the ordinary path, and the abort path was never taken — a green about a code
    path that did not execute. Shape 1 wearing a stopwatch, and it took a second look to notice, in a
    session that had spent the whole day on this exact family of error.

    The repair is a **liveness guard**: the test now refuses to report at all on a run that reached its
    normal completion marker. Whenever a test acts *on* a running process, assert the process was still in
    the state you meant to act on, or the result describes something else entirely.

13. **A test that never reached its subject, and reported a verdict on it anyway.**

    `check_underground` sinks a shaft sixteen rows down, cuts a chamber, and judges whether lamp-lit rock
    has anything in it. On one world in eight the dig silently never started, so it photographed the
    **sunlit surface** and graded it against a standard written for deep rock — then reported 23% dead as
    though the rock had failed. It had been doing this on that world for its entire life.

    Nothing in the layer was wrong except that it never checked it had arrived. **A fixture must prove its
    premise before it is allowed a verdict**, and "I ran and produced a number" is not that proof — it is
    the same lesson as a DIG phase that timed a body standing still, arriving from the opposite direction.

    Two things about how it was caught are worth more than the bug:

    > **The tell was the denominator, not the verdict.** 74 lit tiles where every other world had ~12. The
    > failing number was believable; the *sample size* was not. When a result is plausible, check the thing
    > the result was computed FROM.

    And the first attempt to measure the descent read **−3 on all eight seeds**, because digging a shaft
    down a column moves that column's own surface, so the gauge was measuring the body against the hole it
    had just dug. A reading that is identical across every input is not a reading — the same signature as
    the seed-blind layer in the very same sweep, twenty minutes apart.

14. **A mutation that survives because the branch is unreachable.** *(found by the peer session)*

    Standard practice is: break the code, watch the test go red, and if it stays green the test is weak.
    Deleting `_sky_form`'s hoisted column bound changed nothing, on any test — because **no caller,
    production included, can reach that branch**. The test was not weak. The code was dead.

    These need opposite fixes and the diagnosis does not tell you which: *delete it* and *test it* are
    different bets about the future. The peer chose to cover it by calling `_sky_form` off-grid directly,
    on the grounds that deleting would narrow what the function promises a future caller. It now fails 160
    cells. Either answer is defensible; **treating it as a weak test and stopping there is not.**

    > A surviving mutation says the assertion and the line disagree about mattering. Find out which one is
    > wrong before you fix either.

15. **A gate that cannot fail, dressed as rigour.** The near-miss worth logging even though it never shipped.

    The `check_frametime` absolute budget compares a phase's p95 to 8.33ms, and on a vsync-paced display
    that comparison is close to meaningless. The proposed repair was to assert against
    `viewport_get_measured_render_time_cpu` instead — a real number, from a real API, measuring a real
    thing. It reads **0.12–0.16ms** on this machine. A gate comparing 0.16ms to 8.33ms **can never fail**.

    It would have replaced an ambiguous gate with a decorative one, in the single place this project had
    spent two days making honest, and it would have read as a rigorous improvement in the diff.

    > Before adopting a metric, ask what value it takes when the thing you fear has happened. If you cannot
    > describe the failing reading, you are installing a decoration.

    And check a new instrument's numbers against **each other** before leaning on any of them. The same
    profiler reported whole-frame 8.33ms, render-GPU 0.00ms (absent measurement on Metal, not absent cost)
    and script `_process` 21.89ms — a figure that cannot exceed the frame containing it. One of three rows
    was load-bearing and nothing marked which.

16. **An instrument that reports "nothing" identically to "nothing measured".** *(found by the peer session)*

    Their profiler printed a render-GPU cost of **0.00ms**, and it was believed, because 0.00 is a
    perfectly ordinary reading. Metal does not fill the timestamp query in this build: the number was the
    ABSENCE of a measurement wearing the costume of one. A missing row gets investigated; a zero row gets
    quoted. It now prints `NOT MEASURED` when both percentiles are zero.

    This one is about OUTPUT rather than assertions, which is why it took longer to see — nothing was
    asserting on it, so nothing could go red. It still cost a session's worth of belief that the GPU was
    idle.

    > If an instrument can fail to measure, it must have a way of SAYING so that is not also a legal value.

17. **A detector that cannot see the failure it was built for.** The one I nearly shipped today, and the
    reason it is worth logging is that it was measured against its own target and lost.

    The hitch ratios divide by a quiet frame, and contention had just been shown to break them. The obvious
    guard: measure the quiet frame twice, start and end, and refuse a verdict if the unit moved. It reads
    1.00–1.13x across eight idle-box runs. Beside five deliberately unlocked Godot processes at load 7.89
    it reads **1.03–1.17x** — the same numbers. A threshold would have had to sit between 1.13 and 1.17,
    inside the idle box's own noise.

    The mechanism is the general lesson: **sustained load scales a whole distribution uniformly.** The
    contended runs were not noisier in SHAPE — their IDLE p95/p50 was 1.33–1.37x against an idle box's
    1.05–1.68x — they were the same distribution multiplied by 2.4. So no statistic internal to a run
    separates "this box is loaded" from "this box is slow", and every detector of that family is dead
    before it is written, not just the one I wrote.

    Deleted rather than tuned, and the negative result is written where the code would have been
    (`tools/check_frametime.gd`, `_load_caveat`). The defence that does work is not a measurement at all —
    it is the protocol: everything that boots Godot goes through `tools/with_machine.sh`.

    > Before shipping a detector, run it against the failure it exists for. If its readings there overlap
    > its readings on a healthy run, you have not built a detector, and no threshold will make one.

18. **A defect that lives in the WIRING, not at either end.** The family both sessions converged on, from
    two directions on the same day, and the reason the suite was green through both instances.

    The peer's: `machine_status` returns ten statuses, the lamp matched five, the rest fell through to a
    default that drew *go fix the ore feed* on a machine whose problem was no power. The pixel tests were
    green because the lamp rendered correctly; the sim tests were green because the sim was right.

    Mine: `check_progressive_bake` builds its own `FineTerrain`, hands it a good view rect, and proves
    fifteen things about what the baker does with it. None of that could see the renderer passing an EMPTY
    view, because `setup()` runs before the node is in the tree and `get_canvas_transform()` fails there
    and returns a rect that `rebake` reads as "bake everything". The feature silently defeated itself on
    the one bake it existed to split, with a green sweep behind it.

    Also CI: the workflow named its pixel layers by hand, `add_gl` grew past the list, and two layers ran
    in no job at all — the headless job honestly reporting SKIP and the display job honestly reporting
    four passes, with nothing holding the two reports against each other.

    > **Every test we own instantiates one side and asserts about it.** A vocabulary declared in one file
    > and consumed in another, a caller and a callee, two CI jobs whose coverage only means something
    > together — assert on the JOIN, or nobody does.

19. **A field whose meaning depended on there being only one writer.** *(named by the peer session.)*

    `FineTerrain.last_baked_cells` was a true name for as long as exactly one thing wrote it. Making the
    bake progressive added two more writers, and `check_dig_hitch` — which reads it ten frames after boot
    to ask "how big was the boot bake?" — started getting the size of the most recent 4 ms fill slice.
    It reported **1024 for a bake of 43520**, and it only surfaced because the range happened to fail. A
    plausible number would have been reported forever, under a name that made it unquestionable.

    The fix narrows the WRITER, not the reader: `opening_baked_cells` is written by `rebake` and by
    nothing else, so every existing reader is corrected without being touched.

    > Adding a writer to a shared field changes what every existing READ means, and touches none of them.

20. **A check whose evidence is free text is satisfiable by writing about it.** Two versions of
    `check_ci_coverage` died this way within twenty minutes, which is what makes it a shape rather than a
    slip.

    First, `flow.contains("SF_ONLY:")` went red on **the comment explaining why `SF_ONLY` was removed** —
    a scanner failing on its own explanation. Then, requiring each CI-excluded layer to be named in a
    comment PASSED the mutation, because the paragraph describing the original defect contains the string
    `check_hud_layout`. Prose about the bug satisfied the guard against the bug, for precisely the two
    layers the bug was about.

    The fix is a MARKER, not a keyword: `# CI-EXCLUDED <layer>: <reason>`, with a length floor. Nobody
    writes that by accident and no amount of surrounding explanation imitates it.

    > A keyword search cannot tell a justification from a description. If a human is meant to have decided
    > something, make them declare it in a form that only a decision takes.

21. **A threshold is satisfied by a run that never happened, and the failure moves the number the passing
    way.** Five separate assertions across four layers, found in one sitting while merging the
    six-assertion union (Strike 15). Each compares against a quantity accumulated *during* a play:

    | assertion | what a non-run does |
    |---|---|
    | `speedup >= SPEEDUP_FLOOR` | a stalled shaft burns its whole 6000-frame budget going nowhere and returns those frames as its cost — the hole scores ~21× |
    | `legs["back"] <= LEGS_BACK_CAP` | a body that never fell into the trap regains no rows and passes with room |
    | `spin > free_spin * WHIP_EDGE` | `free_spin` starts at `0.0` and only ever rises, so no free arc decays this to `spin > 0.0` |
    | `score >= SCORE_FLOOR` | the penalties are tallies starting at zero; a sampler that never ticked scores **100** |
    | `pace = frames / par` | an arc that dies at step 3 elapsed almost no frames and reads as blisteringly fast |

    The unifying property is nastier than vacuity. A vacuous check is merely useless; these are
    **anti-correlated with the truth** — the more broken the subject, the better the number, and the more
    confidently the layer reports green.

    The peer session sharpened this past where I first put it, and the sharper version is the one to keep.
    A ratcheting floor is not merely *blind* to a non-run; it is **constructed so the only direction it can
    detect is the direction a healthy run moves.** It watches the value fall, and a broken subject makes it
    rise. So this is not a weak assertion that a tighter number would fix — **it is an assertion pointed
    backwards, and tightening the floor makes a broken run pass more comfortably.**

    **The mechanical tell, in its correct form.** I first wrote it as *"any quantity that starts at zero and
    only accumulates upward"*. That is half of it, and the peer supplied the other half by walking into it:
    **the sign is not the property. The property is an accumulator whose INITIAL VALUE already satisfies the
    assertion.**

    | direction | seed | assertion | a non-run reads |
    |---|---|---|---|
    | rising | `0` | `>= FLOOR` … via a ratio, or `<= CAP` | passes |
    | falling | `INF` | `>= FLOOR` | passes |

    The falling form hides better, and dangerously so: `var worst: float = INF` reads as *"unset"* to whoever
    writes it and as *"excellent"* to whoever reads the result. Live example, `tools/check_voice.gd:83` —
    `worst` seeded `INF`, minimised over every pair of registered sounds, asserted `worst >= NEAR`. The set
    is `sfx._streams.keys()`, i.e. **defined by the thing under test**, so if the library registers one
    sound the inner loop never runs and `worst` is still `INF`. Every voice that fails to register removes a
    chance to fail.

    So: `min_clearance`, `closest_approach`, `worst`, `INF`, `-INF`, `MAX_INT` are all candidates on sight,
    exactly like `0` and a rising count. Ask of the seed, not of the direction.

    **The divide-guard corollary, which is where the worst instances actually live.** A guard written to
    prevent a crash also, silently, picks a verdict:

    ```gdscript
    "frac": float(dead) / float(maxi(total, 1))     # tools/dead_space.gd — nothing judged ⇒ 0.0 ⇒ BEST score
    var region_pc := float(region_us) / float(maxi(region_cells, 1))   # check_dig_hitch — same shape
    ```

    `maxi(n, 1)`, `?: 0.0`, `if empty: return`, `maxf(x, 0.001)` are reached for to stop a division by zero
    and are almost never thought of as choosing an answer. But *"I could not measure this"* and *"this is
    perfect"* are the two readings available, and only one of them is safe to be wrong about.

    > **A guard against an impossible arithmetic case must fall to the side that stops the build.**

    `dead_space.judge()` now returns `frac = 1.0` when nothing was judged. This is worth hunting for
    specifically, because it hides in *shared helpers* rather than in layers — one `maxi(total, 1)` silently
    disarmed a cap in three callers at once, and no amount of reading the layers would have shown it.

    **Enumerate the helpers rather than guessing at them.** There are exactly three, and the broken one was
    findable in a single command:

    ```sh
    grep -hoE 'preload\("res://tools/[a-z_]+\.gd"\)' tools/check_*.gd | sort | uniq -c
    #   4  play_agent      clean
    #   3  dead_space   <- the outlier
    #   2  arc_driver      clean
    ```

    **And the reason the other two are clean is the whole lesson.** Every finder in `play_agent` and
    `arc_driver` already seeds on the failing side — `_nearest_ore_not_shaft`, `_nearest_tree_base`,
    `_nearest_coal`, `nearest_material` all return `Vector2i(-1, -1)` for "not found", and all six call
    sites test `x < 0`. `_floored_exit` returns `0.0` where the value is a *direction*, and zero is not one.
    So the convention was already house style; `dead_space` was the single outlier.

    What made it the outlier is the sharpest form of this whole entry:

    > Nobody writing `Vector2i(-1, -1)` is in any doubt that they are encoding "not found". Everybody writing
    > `maxi(n, 1)` believes they are preventing a crash. **The defect is not the absence of the convention —
    > it is that an arithmetic-safety guard does not look like a place where the convention applies.**

    So the greppable instruction is narrower than "audit shared helpers": **in any helper that returns a
    judged quantity, look at every arithmetic-safety guard** — `maxi(_, 1)`, `maxf(_, 1e-6)`, `x if y else
    0.0`, an early `return` on an empty collection. Each silently picks a verdict for the unmeasurable case,
    and unlike a sentinel it does not announce that it is doing so.

    **And the counter-example, so the fix is not only "add a floor".** `check_agility._jump_latency` returns
    **99** when the body never leaves the floor — a sentinel deliberately placed *above* `JUMP_LATENCY_CAP`.
    The probe that fails to measure reports the worst possible value instead of the best, so `latency <= CAP`
    needs no companion assertion at all. **Seeding the sentinel on the failing side is strictly better than
    guarding afterwards**, because it cannot be forgotten at a second call site.

    > Every threshold needs a companion assertion that the run occurred: the slower route ARRIVED, the body
    > went DOWN, the sampler TICKED, the baseline is NON-ZERO. If you cannot name what a zero-length run
    > would score, the threshold is not yet a test.

    Cheap tell when auditing: for each `>=` / `<=` in a play-test, ask *what does this read if the play does
    nothing at all?* If the answer is "it passes", it is this shape.

22. **A source comment that cites a test as a guarantee is an assertion nobody runs.** `hud.gd`, beside the
    clamp in `works_columns`:

    > *"The counter has a fixed number of columns, so if the two lists ever ask for more than it has, they
    > get SQUEEZED rather than allowed to run off the panel's edge … `check_pack_layout` asserts the squeeze
    > is not happening today; this clamp is what makes the failure mode legible instead of invisible."*

    Every clause is reasonable and the citation was false the whole time: `check_pack_layout` read
    `lay["total"] <= cols` back out of the very function that had just clamped it, so it asserted the
    postcondition of the code under test and could not fail however far the lists overflowed. The comment
    was written in one file about a test in another, by an author who did not run it, and nothing has ever
    held the two together.

    This is the mirror of #20. There, prose about a bug satisfied the guard against the bug; here, prose
    *delegates* a guarantee to a guard that was not making it. Both are free text being trusted as evidence,
    in opposite directions — and note that a cross-file citation is a join defect (#16) as well: the comment
    and the assertion are a vocabulary defined in one file and consumed in another.

    > When you write "X asserts this", you have made a claim about a file you are not editing. Either open
    > it and confirm the assertion says what you just promised, or name the property instead of the test.
    > A citation is not weaker than an assertion — it is an assertion, made somewhere it cannot run.

23. **The exit code is the half that gets thrown away, so the refusal has to be in words.** The peer's
    `check_gamepad` came back as *"completed (exit code 0)"* and **had never run**: `with_machine.sh` waited
    out its 900s behind this session's lock and gave up. The script's `exit 5` was correct and provably so.
    It did not survive the journey.

    Everything in ordinary use discards it. `cmd | tail -45` returns *tail's* status. A backgrounded task
    reports the wrapper's. `cmd; echo done` returns echo's. **I was doing exactly this at the moment the
    peer reported it** — my six-layer run was piped to `tail`, so its exit code was meaningless and I had
    been planning to read the summary text and call it verified. The only thing standing between that and a
    false green was a human reading log prose, which is #20's lesson pointed at the runner itself.

    Counter-measures, in order of how much they buy:
    - **Print the refusal on stdout, in words**: `GAVE UP — NOTHING RAN. Not a pass.` Words survive pipes,
      backgrounding, and log capture; the code does not.
    - **Make the give-up path testable.** It needed a fifteen-minute contended lock to exercise, so the one
      path that must never be mistaken for success was the one path nobody could run. `SF_LOCK_WAIT` fixes
      that, and *the untestability was upstream of the bug* — same move as declaring "zero frames driven"
      for the source-scan layers. **When a path cannot be tested, that is the defect; fix it one level up.**
    - **Assert the codes survive the wrapper** (`tools/check_lock.sh`), including **42**. A wrapper that
      flattened 42 would silently convert every skipped layer into a passing one, and nothing tested it.
    - Where a code must be read through a pipe, read `PIPESTATUS`/`pipefail` — or do not pipe.

    > A tool whose job is to refuse must refuse *loudly*, because its verdict travels through channels that
    > preserve only text. And the run that never happened is the one most likely to return the passing code.

    **Then I did it myself, four hours after filing this, and it cost the other session 18 minutes of
    machine time.** `with_machine.sh` runs `"$GODOT" --path "$ROOT" "$@"` — it takes GODOT ARGUMENTS. I gave
    it a command:

    ```sh
    bash tools/with_machine.sh bash tools/run_harness.sh
    # → godot --path <repo> bash tools/run_harness.sh
    ```

    Godot booted the project and **played the game for thirty-nine minutes** with two junk positional args,
    holding the lock, while the peer's layer queued behind it. No layer ran. The task notification then read
    `completed (exit code 0)`. (`run_harness.sh` takes the lock itself, so the wrapper was both unnecessary
    and malformed — there was no valid reading of that call.)

    **Three signals agreed it was healthy, and all three were about the wrong thing:**
    - *Elapsed time.* A wedged-but-alive process produces it perfectly.
    - *`tail -45` buffering.* "No output yet" and "no output ever" are the same observation.
    - *The peer twice checked my CPU and reported 49%, then 23% — "phase boundary, not a stall".* Both
      readings were **true, and measured Godot playing the game.** A correct measurement of the wrong
      process, offered in good faith and accepted as evidence about something it could not see.

    That last one is this whole family arriving as an *interaction* rather than an assertion, and it is the
    reason this sits here rather than in a commit message: **"check the peer's process is alive" is advice
    both sessions would have called good that morning.** It cannot distinguish a run from a non-run.

    **The peer's sharpening, which is the keeper:**

    > The tell is not "a healthy-looking measurement". It is **a measurement taken one level below the
    > claim.** CPU and elapsed time are properties of *a process*; "the harness is running" is a claim about
    > *what that process is doing*. Every signal offered was true of the layer sampled and silent about the
    > layer being discussed.

    Which is `check_voice` again in a different costume — measuring the population the subject handed you
    instead of the one the claim was about. And note the aggravating factor was not the number but the
    *interpretation* offered with it: a bare reading invites a second look, while "phase boundary, not a
    stall" closes the question.

    > The check that would have taken ten seconds: **`ps -o args`, not `ps -o %cpu`.** Same keystrokes,
    > different question. `godot … bash tools/run_harness.sh` is wrong on sight.

    **But argv-checking is advice, and advice has a per-occasion failure rate** — the sentinel rule (#21)
    pointed at a protocol. The real fix is that the tool now refuses the call: `with_machine.sh` rejects a
    non-flag first argument **before taking the lock** (a bad call must neither queue nor make anyone queue),
    printing the argv you wrote, the argv it would have become, and `REFUSED — NOTHING RAN. Not a pass.`
    Verified against the exact original call: **exit 2, zero seconds.**

    **One correction to the first draft of this entry, on the record because the wrong version flatters
    me.** I wrote that my failure "printed nothing at all" while the peer's "at least printed a give-up
    line". Untrue in the way that matters: theirs printed one *only because they had fixed it an hour
    earlier*. Before that commit theirs was exactly as silent as mine. **I was not sloppier — I was earlier
    in the same queue**, and the tool was the variable, not the operator. Which is the whole argument for
    the guard over the advice.

    Scale of the illusion, for calibration: **the real run of those layers takes 63 seconds.** The fake ran
    for thirty-nine minutes and was rationalised the whole way as "`check_plunge` and `check_loop_health`
    are slow play-tests".

24. **A bounded wait loop is falsifiable only if the loop bound exceeds the assertion cap.** The peer's,
    found while sweeping #21, and it earns a separate number because **the seed is perfectly innocent** —
    the danger lives entirely in the relationship between two constants usually written far apart.

    ```gdscript
    while p.stride > 0.01 and decay < 2.0:            # bound 2.0
    _check(decay <= DECAY_MAX_SECONDS)                # cap   0.6   → falsifiable

    while p.grapple.state == FLYING and frames < 60:  # bound 60
    _check(frames <= PLANT_FRAMES_CAP)                # cap   12    → falsifiable
    ```

    Both are safe. Both become **unfalsifiable the moment the two numbers meet**: the loop cannot let the
    quantity exceed the bound, so comparing it against an equal-or-larger cap asks a question whose answer
    the loop has already forced. That is #3 wearing a loop, and it arrives by someone tuning a timeout, not
    by anyone touching the assertion.

    Greppable without understanding the layer: find `while … and X < N`, find `_check(X <= M)`, compare `N`
    and `M`. **Only bites where the loop counter IS the asserted quantity** — a loop whose result is
    asserted as a *state* (`_check(not p.grapple.live())`) is a different animal, and usually a safe one,
    because exhausting the bound leaves the state unchanged and the assertion fails closed.

25. **The guards that prevent these defects are the ones review deletes first — so mark them.** Not a shape
    but the standing pressure on every fix above, and it is worth its own number because it operates on
    *correct* code, forever, rather than biting once.

    Every non-vacuity guard has the same profile: **an assertion about the FIXTURE rather than the feature,
    which reads as redundant precisely because it never fires.** `region_cells > 0`, `released > 0.0`,
    `at_stall.size() >= 6`, "both racers actually ran", separate floors on two tables. A reviewer trimming
    for signal removes them first, and they are the only lines standing between the suite and the four
    defects a full day's sweep found.

    This is not hypothetical: I nearly dropped `at_stall.size() >= 6` as noise while trimming an agent's
    diff, and then — an hour later, having forgotten — cited that same guard as the reason my code was not a
    fifth instance of the defect. The pressure caught the person actively hunting the defect, in the same
    change set.

    So the counter-measure is a **naming convention, not vigilance**: mark them `# NON-VACUITY`, and say
    which specific failure the line prevents.

    ```gdscript
    # NON-VACUITY — an unwatched play scores a perfect 100.
    _check(_sampled_frames > 0 and _sampled_frames >= frames - 1, …)
    ```

    Already in 19 of 74 layers before it was ever agreed, so this codifies an existing habit rather than
    importing one. **Write the site-specific reason, never a generic sentence.** The first pass of this
    stamped one boilerplate line on eight sites and on `check_seam` it was flatly false — that guard is
    about a *fixture existing*, not about a run having happened. A marker that misstates why a line is there
    is worse than no marker, because it is the one thing a trimmer reads before deciding.

    > A guard that never fires looks like dead weight to everyone except the person who knows what it
    > catches. Write that down beside it, or it will not survive its first tidy-up.

    **The guard justified itself within hours, and the honest version of that story is narrower than the
    flattering one.** Mutating `check_teaching`'s key-sweep regex empties `named`, and `unbound == 0` —
    *"every key a hint names is really bound"* — then passes **perfectly, reporting health over nothing.**
    The only assertion that fired was the floor added that morning.

    But the peer flagged their own evidence before either session wrote it up, and the caveat is the part
    worth keeping: **that mutation proves the floor catches a broken instrument. It does not prove the floor
    was worth its cost against the actual risk** — which was never "somebody breaks the regex" but "somebody
    edits the token set and quietly narrows what gets swept". Those share a signature, so the guard does
    cover the real case; but the mutation chosen was the one that was easy to apply with `sed`, not the
    representative failure.

    > **Green tells you the assertions did not fail; never that they ran.** A log-grep confirms they ran; a
    > mutation confirms they can fail. Different properties — and the second is the one that costs
    > something, so it is the one that gets skipped. When you report a mutation as evidence, say which of
    > the two you bought, and whether the mutant you picked was the representative failure or the
    > convenient one.

    **And the reason this needs saying at all**: the convention was already in 19 of 74 layers before either
    session proposed it. It was not missing — it was **load-bearing in a quarter of the suite and unnamed,
    which is exactly why it was trimmable.** Unnamed practice is not protected practice. Naming it is what
    lets it survive a reviewer who was not there when it was written.

    **The sentinel rule has an inversion, and it is worse than the defect it fixes.** Sealing an
    unmeasurable case into a distinct return value (#21) is only correct if that value lands on the
    **failing** side *of the assertion* — which is not the same question as whether it is empty. Check the
    direction each caller reads it in. If any caller treats "non-empty" as the expected condition, the
    sentinel has become a passing value that **also looks deliberate**, and so survives review by
    advertising the care that went into getting it wrong. Empty and failing coincide almost everywhere,
    which is why the one place they do not is where this will bite.

    > Check the seed against the assertion's direction, never against "empty versus non-empty".

26. **A layer that reports a DURATION must declare whether it can be timed under contention — and read the
    header the run printed about itself before theorising about what the run was doing.**

    `check_dig_hitch` was red in CI all afternoon and green on every developer machine. Both sessions
    theorised: one blamed the renderer (the failing job was headless, the passing one had a display), the
    other blamed memory bandwidth. **Both were wrong, and the answer was printed in plain text at the top of
    both logs:**

    ```
    display:   Sinkforge harness (parallel, JOBS=1, layers=6 of 75 — SUBSET, display, STRICT)
    headless:  Sinkforge harness (parallel, JOBS=4, layers=75, NO DISPLAY)
    ```

    A layer that measures TIME, timed four-up. `bulk_us <= full_us` is 12% clear on an idle box under
    **both** renderers, and inverted to 2.2% then 8.2% the wrong way on the contended job. Nothing about the
    code changed; the contending processes were eating the bandwidth the bulk path's advantage is made of.

    **It was a registration bug wearing a performance bug's costume.** The mechanism already existed and the
    sibling layer already used it — `add_excl` (runs alone) versus `add_gl`. One word.

    ```sh
    add_excl "check_frametime (hitch+budget)"   # measures time — already correct
    add_gl   "check_dig_hitch (friction)"       # measures time — ran 4-up      ← the bug
    ```

    > **Checkable against the registration table without reading a single layer.** Every layer that prints a
    > millisecond figure and asserts on it must be `add_excl`. That is a five-second lookup; diagnosing it
    > from the symptom took an evening and two wrong theories.

    Two failures of method to keep, one each:

    - *Each session picked the variable it was already thinking about.* The two CI jobs differed in renderer
      **and** layer-set **and** parallelism; one session reasoned from the renderer because that was the
      visible difference, the other from bandwidth because that was the familiar mechanism. Neither argument
      settled anything — **a local headless run did**, by eliminating the renderer and leaving load as the
      only axis with a factor of 2.6 behind it. When two candidate explanations both fit, stop arguing and
      remove a variable.
    - *The catalogue exists because authors do not retrieve their own documents.* I wrote
      `check_frametime`'s load caveat **that same day** — recording that a still frame costs 2.4× more with
      five Godot processes beside it, and that the DIG ratio moved 3.9–4.4× → 4.7–6.7× *purely from load* —
      then spent the evening theorising about the identical effect in the identical suite. Retrieval
      latency on my own measurement: about six hours. That is not a lesson about being more careful; **it is
      the measurement that justifies this file's format.** Anything depending on the author remembering
      their own document has a failure rate, and the guard beats the advice because the advice needs
      somebody to be thinking of it at the right moment.

27. **Three ways to draw the measurement boundary wrong, all found in one evening.** The unifying error is
    not any of them individually:

    > **A measurement is only as good as the boundary you drew around what you were measuring — and the
    > boundary is the part nobody writes down.**

    **(a) The subject inside the population.** `check_dig_hitch` timed a bake while running as one of four
    concurrent Godot processes doing bakes. Shape 26.

    **(b) The detector inside the population.** A quiet-box waiter:

    ```sh
    until [ ! -d "$L" ] && ! ps -eo args | grep -q "[g]odot"; do sleep 5; done
    ```

    The waiter's own command line contained `GODOT=/opt/homebrew/bin/godot`, so `ps -eo args` returned the
    waiter, the grep matched, and it **blocked forever on its own existence.** Fixed with `pgrep -x godot` —
    match the process *name*, not any command line containing the word.

    Its failure direction deserves recording: **a self-matching waiter can only ever say "not ready", so it
    has no false green — only silence indistinguishable from the awaited event never happening.** No alarm
    fires, ever. It was found by going to look at *which* process was lingering and finding a `zsh` — `ps -o
    args` doing the same work it does in #23.

    **(c) The population larger than the claim.** `until ! pgrep -f "run_harness.sh"` on a two-session box.
    The predicate was true the whole time and it was true about the *other session's* run. **A wait on
    shared hardware needs an OWNER, not a predicate about the box** — a pid, a task id, a named log file.
    `run_harness.sh` already writes its pid to the lock's `owner` file, which is what should have been read.

    **And the near-miss is the part worth keeping.** (c) presented with (b)'s exact symptoms — same `pgrep
    -f`, same hang, right after the peer reported (b). Confirming it would have cost one sentence and felt
    like solidarity. A five-second probe (`pgrep -f 'zzz_selfmatch_probe'` → 0 matches, for a name that
    exists nowhere) showed there is no self-match in this harness at all. Had it gone unrun, both sessions
    would now believe a false thing about their tooling **and the real defect would still be live**.

    > An explanation that arrives pre-built from someone you trust gets **less** scrutiny, not more. Probe
    > it exactly as hard as one you built yourself — harder, because you did not watch it being made.

28. **A guard whose green gets BETTER as the subject gets more broken — and which fires, prints numbers, and
    passes every counter-measure in this file.** The peer named this as distinct from #21 and they are
    right; it is the one shape here that survives everything else we built today.

    `check_frametime`'s DIG phase measured **13.06 ms p95 when mining excavated nothing**, against **32.81
    ms** when the work-proof forced it to do the job. **Breaking mining outright would have registered as a
    60% performance win.**

    Why the #21 counter-measure does not catch it: *the run happened.* The frames were drawn, the clock ran,
    the assertion executed, the log filled with plausible milliseconds. A companion assertion that "the play
    occurred" passes cheerfully. What collapsed was not the run but the **work inside** it, and the gauge
    measures cost per frame, so less work is a better score.

    | | #21 — the threshold a non-run satisfies | #28 — the gauge that rewards breakage |
    |---|---|---|
    | does it fire? | no — trivially satisfied | **yes**, with numbers |
    | does the run happen? | no | **yes** |
    | fix | assert the run occurred | assert the WORK occurred — a work-proof |

    The counter-measure is a **work-proof**: the gauge must assert what the subject accomplished, not only
    that it ran. `check_frametime` now requires the mines to have landed, which is what turned 13.06 into
    32.81.

    **And the historical trap that follows from it.** A performance number recorded *before* a work-proof
    existed cannot be compared with one recorded after — the earlier figure may be cheap because the subject
    was doing less. `FEEL_GAP.md` records DIG p95 improving 33.8 → 19.8 ms; **both endpoints predate the
    work-proof, so that improvement is now UNKNOWN, not disproven.** The peer went looking for a historical
    baseline, found the 19.8, and was one step from filing "regressed to pre-#S30" before reading the
    withdrawal note.

    > When you add a work-proof to a gauge, every number that gauge ever produced becomes unusable as a
    > baseline. Say so where the old numbers live, not only where the fix lands — someone will find them,
    > and a low number reads as good news.

    Independent confirmation, which is the standard this deserves: two sessions, different fixtures (46
    mines and 40), measured DIG p95 at **32.81** and **32.30 / 33.76 / 35.06** — one of them actively
    looking for grounds to call it a regression.

Add to it whenever one bites. It is the cheapest artifact either peer produces.

### The two counter-measures that generalise

Most entries above are diagnoses. These two are fixes, and both are cheap enough to apply by default.

**Assert set EQUALITY, not containment.** *(the peer's, generalised from `check_status_reads`.)* Any layer
comparing two sources of truth — a scanner against a registry, a renderer's `match` against the vocabulary
the sim actually returns — must check BOTH directions. Forward alone ("every status has a look") passes
trivially when the scan comes back empty, which is the cleanest vacuous pass there is: a regex that
silently stops matching is indistinguishable from a system with nothing to report. The reverse direction
("no look describes a status the sim cannot return") turns that same empty scan into a pile of dead
entries and a red run. It makes the instrument self-proving, in the same run, without anyone re-reading it.

The defect that motivated it is worth naming as a category on its own: **it lived in a JOIN.** Ten statuses
were defined in `factory_sim.gd`, five were matched in `world_renderer.gd`, and the other five fell through
to a default that drew a confident wrong answer — *go fix the ore feed*, on a machine whose problem was no
power. Every pixel test was green because the lamp rendered correctly; every sim test was green because the
sim was right. **Every test either session owned read one file or the other.** Look for the rest: any
`match` on strings another file produces, any dictionary keyed off a vocabulary defined elsewhere.

**Make a registry layer reject something.** A layer that iterates N entries and passes them all cannot
distinguish "all N are fine" from "the check is inert". Give it two entries it is REQUIRED to reject,
judged on every run — the first version of `check_casing_light` passed twenty registry colours against a
floor its own arithmetic could not reach, and the tightest reading looked like comfortable margin.

**And a limit on both: a test that constructs its subject directly cannot see the CALLER getting the
arguments wrong.** `check_progressive_bake` builds its own `FineTerrain`, hands it a good view rect, and
proves fifteen things about what the baker does with it. None of that could see the renderer passing an
EMPTY view because `setup()` runs before the node is in the tree — which silently defeated the entire
feature while the layer stayed green. Assert on the real call site, or assert that the real call site
produces a sane argument.

### 13. The index is shared mutable state, and it rewrites the meaning of the other session's commands

Rule 1 says never `git add -A`, and frames the hazard as carelessness — one session sweeping up another's
work. This is the version where **both sessions are careful and the tree combines them anyway.**

What happened. One peer ran `git merge --no-commit --no-ff` to land a worktree, then paused to verify the
staging was right — six files, the correct layer registrations, the right layer count. That pause is the
diligent thing to do and it is exactly what armed the trap. The other peer, meanwhile, staged four audio
files *by explicit path* — rule 1 followed perfectly — and ran `git commit`. Git did not create their
commit. It **completed the pending merge**, absorbing their four files into a two-parent commit under their
message. Then `git pull --rebase` did what rebase does by default: it skipped the merge commit. Silently.
Exit 0, nothing printed, `git status` clean, `git log` healthy — and their entire change gone from HEAD.

Both peers then spent time reconstructing it from opposite ends: one saw "nothing to commit, working tree
clean" for a merge they had staged; the other saw their own edits reverted in the files in front of them.
Nothing was lost — the reflog held it, and `git checkout <lost-sha> -- <paths>` restored it byte-for-byte —
but only because one peer happened to look at file contents rather than at git's status reporting.

The rules that fall out, and all four are cheap:

1. **`test -f .git/MERGE_HEAD` before every commit.** If it exists, someone else's merge is pending and
   your commit will complete it. Stop; do not commit through it.
2. **`git log -1 --format='%P'` after every commit.** Two hashes means you made a merge commit, which
   means the next `pull --rebase` will delete it.
3. **Verify a push landed by fetching and reading `origin/main`.** Never trust a quiet `git push -q`; its
   exit code answers a different question than the one you have.
4. **Never leave the index staged across a tool call in a shared checkout.** `--no-commit` verification is
   correct practice in a private tree and a loaded trap in a shared one. Verify in a scratch clone, or
   stage-and-commit as one uninterruptible step.

> A pending merge is not private state. It is a trap armed in shared memory, and the peer who springs it
> has done nothing wrong.

### 14. An exclusive claim freezes the tracked tree, not just the processes

Rule 2 claims the machine against *processes*: announce long-running things, say "clear" when done. That
is necessary and it is not sufficient, and the gap cost a full verification run.

One peer handed over the machine with the exactly-correct words — *"nothing of mine is running"* — which
was true. They then edited two tracked source files, which is not running anything. Meanwhile the other
peer's 62-layer harness was mid-flight:

```
harness run window        03:00:33 -> 03:03:06
src/core/factory_sim.gd   modified 03:01:31   <- t+58s, loaded by nearly every layer
scenes/bazaars.gd         modified 03:02:26   <- t+113s
```

The run went green. The green meant nothing, and it could not even be salvaged as a partial result:
`run_harness.sh` is parallel by default (`JOBS=$NCPU`), so there is no clean prefix of layers that tested
the original tree — per-layer durations summed to 422s against 152s of wall-clock, and any layer could
have straddled the write.

**The harness re-reads source from the working tree at every layer launch. An edit during a run is
operationally identical to a concurrent run, and produces the same false green.**

So the claim to make is not "the machine is busy," it is **"the tree is frozen"**:

- The holder **pins and states the hash** being tested, and reports the result against that hash so a peer
  can check it.
- The other session writes **nothing the engine loads** — `.gd`, `.tscn`, `.tres`, `.import`,
  `project.godot`, shaders, assets — committed or not, for the duration. Documents, scratch directories,
  and thinking are all still free.

  **Bind this to what Godot loads, not to what git tracks.** The first draft of this rule said "no tracked
  file", which was wrong in a way worth keeping visible: `.md` files are tracked and no layer loads one.
  A peer caught it by pointing at direct evidence — `PEER_SESSIONS.md` was being edited *during* one of
  their runs and the run was unaffected. The precision is not pedantry. An over-broad rule that both peers
  visibly violate is a rule that gets ignored, and this one is load-bearing.
- The holder runs `git status` **during** the run, not only before it. It is the one check that catches
  this, and it is one command.
- Ask for a **freeze window** rather than seizing the machine. It is a smaller ask, it is easier to grant
  honestly, and it is what you actually need.

> "Nothing of mine is running" and "the tree is frozen" are different claims. Only the second one makes a
> green mean anything.

### 15. Anything that boots Godot takes the harness lock

Not only `run_harness.sh`. `user://` is keyed on the project **name**, so every worktree, every one-off
`--script` probe, and every micro-benchmark shares one save slot, one sentinel state, and one set of test
fixtures (see rule 14). A stray profiling run beside a sweep contaminates the sweep and is invisible in its
output. If it boots the engine, take the lock or announce it — a measurement taken next to an unannounced
neighbour is not a measurement, and the neighbour is usually the peer.

**The rule is now a TOOL, and that is the whole correction.** `tools/with_machine.sh` (peer, `0cdb36a`)
holds the lock and passes Godot's exit code through, so the three-state protocol survives it:

```sh
GODOT=... bash tools/with_machine.sh --headless --check-only --script res://tools/check_frametime.gd
GODOT=... bash tools/with_machine.sh --script res://tools/capture_moments.gd -- delve
```

The peer wrote it after fixing the lock in `profile.sh` and finding the hole still open, because the
processes on my box during a threshold derivation were not the profiler — they were ad-hoc
`godot --script res://tools/check_*.gd` invocations, which is how most single-layer runs actually happen.
**A rule enforced by one of N call sites is enforced by none.** The line to remember is not "check the
lock first"; checking is what a careful session does anyway, and it is precisely what did not scale.

And the cost of ignoring it is now measured rather than asserted: five unlocked Godot processes beside a
timing layer moved its quiet frame 2.4x and its DIG ratio from 3.9-4.4x to 4.7-6.7x, straight through a
6.0x cap. Nothing inside the run can detect that — see vacuity shape 17.

### 16. The machine lock serialises RUNS, not FILE STATES — announce mutations of shared files

The peer raised this against their own work rather than reporting it as a thing they had got right, which
is the only reason it is here.

Mutation-testing a new assertion means **editing the subject**, and the subject is often a game file
outside either session's lane — `sfx.gd`, `hints.gd`, `player.gd`. `tools/with_machine.sh` guarantees that
two Godot processes never run at once. It guarantees **nothing** about the tree those processes read. A
peer who starts a run while a shared file is mutated gets a result about a codebase that existed for four
seconds and will never exist again — and it can fail *or pass* wrongly, so there is no safe direction.

This is strictly worse than a normal race, because a mutation-test is designed to make the suite go RED.
Its red is expected, and a peer's genuine red arriving in the same window is indistinguishable from it.

The rule, and it costs one message:

> **Before mutating a file outside your lane, say so, and stay off the machine until you have restored
> it.** Verify the restore with a residue scan (`grep` for your mutation markers across the tree), not by
> remembering that the `trap` fired.

**The full cycle, and the peer sharpened it against their own harness rather than mine:**

    back up → ASSERT THE BACKUP EXISTS → mutate → run → restore → scan for residue

The middle assertion is the one that was missing, and its absence is this whole document's subject wearing
the costume of a safety mechanism. Their `restore()` copied from `$S/*.bak` without ever checking the
backups were written. **Had a `cp` failed — bad path, full disk, a typo in `$S` — `restore` would have run
to completion, reported nothing, and left the mutation in the tree.** A restore whose broken state is
indistinguishable from its working state, sitting inside the tool being used to hunt exactly that.

> Every step but the last produces *intent*. **The residue scan is the only one that produces evidence.**

Rule 14 already freezes the tree for an *exclusive claim*; this is the same idea at the granularity of a
single mutate-run-restore cycle, where nobody would think to declare a claim for a window measured in
seconds. **The window being short is the argument for announcing it, not against** — a four-second window is
exactly the one nobody thinks to mention and nobody can reconstruct afterwards.

### 17. An identifier allocated by "read the last one and add one" collides silently

We both wrote a `history/137` on the same night. Mine was
`137-the-button-nobody-had-photographed.png`, the peer's was
`137-the-layer-that-paints-nothing-down-here.png`. The merge took both without a murmur, because a
directory of numbered files has no uniqueness constraint for git to object to. Two files, one number, and
the only thing that could ever have caught it is somebody reading the directory afterwards.

The general shape, and it is not about `history/`:

> **Any identifier allocated by reading the current maximum and adding one collides silently when two
> sessions read the same maximum.** The read and the write are not atomic, and nothing between them
> notices.

The same shape sits under tracelog section numbers, capture-manifest entries, ticket IDs, strike numbers —
every monotonic counter in this repository, all of which are allocated exactly this way.

There are two fixes and they are not equal:

- **Announce before claiming.** Costs a message, needs both peers awake, and fails the moment either one
  forgets. It is coordination standing in for a constraint.
- **Derive the number after the merge, not before.** Costs nothing, needs no coordination, and cannot be
  forgotten because there is no moment at which you could forget it. Name the file for what it is, merge,
  then number it from the tree you actually have.

The second is the right one, for the same reason the residue scan in rule 16 is: it produces evidence
rather than intent.

**And the obvious third fix — scan the directory for duplicate numbers — cannot work, which I found out
by writing it.** The scan's first version reported 114 collisions; every one of them was a `.png` counted
beside its own `.import` sidecar, an instrument that could not tell a file from its metadata. Corrected,
it found exactly three: `12`, `21` and `53`. All three are **deliberate**, all three landed in one commit
(`3c46c8c`), and they are pairs and triples of the same milestone — `53-old.png` beside `53-new.png`,
`12-lighting-shaft.png` beside `12-lighting-surface.png`.

So the number in `history/` is not a file identifier at all. It is a MILESTONE identifier, and several
frames of one milestone are supposed to share it. Which means:

> **A duplicate-number scan over `history/` cannot fire on the defect, because duplicates are legal there
> by design.** The only thing separating "two frames of one milestone" from "two milestones that collided"
> is what the names mean, and no scan reads meaning.

That is the night's own subject wearing a different costume, and a nastier cut of it than I first wrote.
The archive *means* one number per milestone. Nothing *enforces* it. And the artifact's legitimate
duplicates sit in exactly the shape a detector would look for, so the detector is not merely absent — it
is **unbuildable from the filenames**. Derive-after-merge is not the better fix here. It is the only one.

## A finding that outranks the protocol

From the night this was written, and it generalises well past peer sessions:

> **A comfortable margin pointing the wrong way should be more suspicious than a red.**

A floor demanded 2.0x contrast. The model's structural maximum was 1.85x, so the floor was unreachable *by
construction* — and it passed for a long time anyway, at 2.21x, because it sampled a single cell and that
cell's material tone rode along with the lighting. The 10% "headroom" was a lucky texel sitting on top of an
impossible assertion.

Add it to the vacuity hunt list, beside *assertions inside loops that may not iterate*:

- **a floor no configuration of the model can reach, passing on measurement noise.**

Both are guards that were never guarding.

### 18. Attribute by branch membership, never by author and never by memory

The authorship rule (`docs/DECISIONS.md`) makes every commit on every ref carry the same identity, by
design. That is correct and it should not change — but it means **`git log` cannot answer "whose commit is
this", for either session, ever.** Branch membership is the only attribution signal that exists here:

```
git merge-base --is-ancestor <sha> <ref>     # the only honest answer
git branch -a --contains <sha>
```

One session credited **its own commit to the peer** while writing a message addressed to them, and the peer
had to run the check to disprove it. No git field contradicted the claim, because none could. The failure is
structural rather than careless: a message addressed to someone makes their name the default owner of
whatever it is about, and the usual corrective — look at the author — returns the same string either way.

So: **run the check before crediting or blaming, including when crediting yourself.** It costs one command,
and it is the only thing standing between a sole-author history and a wrong attribution nobody can refute
from the record.

### 19. When two sessions cite different line numbers, assume FILE DRIFT before error

Three times in one night, a disagreement over a line number resolved to *both citations correct, on refs
where the file had moved* — a comment pass on one branch shifted a constant by nine lines. Each time the
first instinct was that one of us had misread.

A line number is a fact about a ref at a moment, not about a symbol. Cite the symbol and the ref together,
expect the number to rot, and **locate by reading rather than by trusting a number you were given** — an
agent handed a stale address spends its budget re-deriving what you already knew, which is budget that does
not go into the work.

