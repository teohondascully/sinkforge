# How this project is verified

Sinkforge is a Godot 4 game with an unusually large test surface: 118 registered check layers across
34,000 lines of harness (`tools/*.gd`) against 26,000 lines of game code (`src/` and `scenes/`). Both
figures name their glob deliberately, because the ratio is the claim: counting the harness's shell
scripts as well, and counting the headless suites in `tests/` as game code, the same measurement reads
roughly 36,500 against 30,300. That ratio is deliberate either way, and this document explains the
reasoning, because the harness is the part of the repository most worth reading.

A game is hard to test for an ordinary reason: most of what makes it good is a picture on a screen and a
feeling in the hand, and neither is a return value. The layers here exist to turn as much of that as
possible into something that can fail.

## Four execution classes, because the environment is part of the measurement

`tools/run_harness.sh` registers every layer under one of four verbs, and the verb is load-bearing.

| verb | count | meaning |
|---|---|---|
| `add` | 100 | safe headless; no window, no GPU readback |
| `add_gl` | 14 | needs a real display, because it photographs the frame |
| `add_excl` | 3 | must run alone on the machine, and needs a display |
| `add_excl_hl` | 1 | must run alone, but headless: it stages races rather than measuring frames |

`add_gl` exists because a layer that reads a `SubViewport` or waits on `frame_post_draw` does not fail
under `--headless`. It hangs. The distinction is recorded in the runner rather than in a comment so that
a layer cannot be registered into the wrong class by accident.

`add_excl` exists because three layers assert on a duration. Duration is a property of the box, not of
the code, and running four jobs in parallel once turned a 12% timing margin into an 8% loss. A layer that
measures time has to own the machine while it does so, and anything that boots the engine takes a
machine-wide lock through `tools/with_machine.sh` for the same reason.

## An assertion that cannot fail is a defect, not a passing test

Every layer is required to document how it would fail. `CONTRIBUTING.md` calls this the non-vacuity note,
and it is the single most useful convention in the repository, because the failure mode it catches is
invisible: a green check that was never capable of being red.

A real example is preserved in `tools/check_grapple_reads.gd`. A cap of `1.01` stood over a quantity that
`_corridor_fill` bounds at `1.0` by construction. It passed every run it ever made and could not have done
anything else. It is now a recorded stand-down rather than a silent pass, with the measurement published
and no bound asserted, because inventing a threshold to replace a tautology would be the same mistake
with a different number.

The general form is worth stating plainly, since it recurs: **ask what it would take for this check to
fail, and if there is no answer, the check is decoration.** A search that returns zero results is evidence
about the search. A statistic whose threshold moves with the data measures the threshold. A guard whose
own mechanism can produce the symptom it watches for will produce it.

## A number written in prose is a test with no runner

Documentation drifts silently. `tools/check_doc_counts.gd` asserts that every layer count printed in
`README.md`, `CONTRIBUTING.md` and this file equals the count the runner actually registers. It was
written after the same number went stale twice within an hour of being correct. This document is inside
its own guard rather than outside it: the per-verb table above is exactly the kind of number that rots in
a table cell, because a table cell is not a sentence anyone rereads.

The same rule applies in reverse: where a count would rot, the repository prefers to record the command
that derives it instead of the answer.

## The capture set is an archival record, not a screenshot folder

`docs/media/moments/` holds 52 canonical captures of named moments, and `docs/CAPTURE_MANIFEST.md` is
generated from them by `tools/capture_manifest.sh`, which runs in CI with `--check`.

Each row carries the date the frame was written and a signature of the drawing sources as they stood in
the tree that wrote it. That second column is the point. Two frames sharing a renderer signature are
pictures of the same renderer whatever day they were taken; two frames that differ are not comparable,
and anyone judging them side by side is judging two builds. Without it, a visual comparison silently
becomes an argument about which week the screenshot came from.

## Controls belong inside the measurement

Where a layer can carry its own control, it does. The strongest form is a control that travels in the
same frame as the subject: unchanged rows measured beside the one row that moved, so that a shift in the
machine moves both and cannot be mistaken for a result.

Where that is not possible, a layer prefers absolute levels over ratios, and repeats on the same build
over a single reading. Captures on this project differ by roughly 38% run to run from animation phase
alone, so a single-frame difference proves very little on its own.

## Determinism

The same seed produces the same world. Worldgen is pure and node-free; `src/` holds the simulation and
imports nothing from `scenes/`, which is checked rather than trusted. That seam is what lets a headless
layer construct a world, assert on it and exit in a few seconds, and it is why most of the suite can run
without a display at all.

## Running it

```
bash tools/run_harness.sh                    # everything
SF_HEADLESS=1 bash tools/run_harness.sh      # force the no-display path, as CI's headless job does
bash tools/with_machine.sh --headless --check-only --script res://scenes/main.gd
```

The runner is configured by environment variables and parses no command-line arguments at all, so a
`--headless` flag would be accepted in silence and ignored. `CONTRIBUTING.md` has the full list of
switches.

Exit codes and the parse-check trap are documented in `CONTRIBUTING.md`. The short version of the trap:
`--check-only` prints the parse error and then exits `0` anyway, so read the output rather than the
status.

## The frame SLO, and what it deliberately does not promise

Performance claims are worth exactly as much as the hardware they name, so this project makes one only on
a machine you have named yourself. Set `SF_PERF_HOST=<machine-id>` and `check_frametime` asserts a frame
SLO; leave it unset, and the layer measures, prints, and explicitly declines to conclude.

The SLO has **two terms**, and the reason is worth stating because a single number cannot carry it:

| term | what it asks | why it alone is not enough |
| --- | --- | --- |
| **miss rate** | what share of frames run past 1.5x the display's refresh interval | it cannot see a stall getting shallower -- halving a 30ms stall to 17ms leaves the same frames late |
| **severity** | how many refresh intervals the worst frame took | it cannot see a stall becoming more frequent |

Both are **ratchets on measured behaviour, not targets.** Nobody has decided what frame behaviour this
game owes a player. What the numbers encode is "no worse than it was measured to be", with margin, so a
regression is caught while nothing is claimed about what is good enough. The allowances are separated by
phase because digging is the only phase doing work the player asked for mid-frame, and one global number
would let a dig regression quietly spend the idle phases' headroom.

**What it does not use is a percentile against a millisecond budget**, and that is the part most people
would write first. Under vsync a frame lands on 1.0x or 2.0x the refresh and nothing between, so p95
measures the *pacing* and not the work. The first time that assertion was actually switched on it failed
a phase that was holding 120fps with 0.0% of its frames late. The p95 is still printed beside the verdict;
it is a diagnostic, not a bar.

## Limits that are named rather than hidden

A suite that reports only successes is not being honest about what it can see. These are the places
where the instruments are known to fall short, kept here so that a green sweep is not read as a claim
they do not.

### One reading the software renderer cannot currently give

`check_grapple_reads` judges whether a rope hangs. It measures the cord's greatest departure from the
straight line between the hand and the piton, as a share of that line, and compares a slack rope against
a taut one. On real hardware it separates them cleanly. On the software renderer used by the build
machines it does not: both arms come back pinned at the top of what the measurement can represent, which
is a statement about the instrument and not about the rope.

The layer says so itself rather than passing. The two saturated readings are reported as failures, and
the assertion that would have used them stands down with its reason printed, because a verdict on the
rope computed from the instrument's own ceiling would be a claim about the instrument wearing the rope's
name. The measurement is published; the conclusion is withheld. That is the intended behaviour for a
reading that cannot be trusted on the machine taking it.

Note what is *not* being done. The bound has not been lowered to fit the saturated number, and the layer
has not been switched off on the machine where it struggles. Either would turn a known blind spot into a
green tick, which is the failure this suite is most concerned with.

A replacement measurement is being developed alongside the incumbent rather than in place of it, so both
can be read on both renderers before either is trusted.

### Timing is a property of the box

Three layers assert on a duration, and a duration measured on a busy machine is a measurement of the
machine. They are registered to run alone, and anything that boots the engine takes a machine-wide lock.
A timing number from this suite describes one machine with nothing else running on it, and is not a
portable claim about performance.

### A pixel judgement is only as good as the renderer under it

Two renderers do not draw the same frame. A layer that photographs the frame is therefore making a claim
about the renderer as much as about the code, which is why a green local sweep and a red build are not a
contradiction and why the pixel layers are registered in their own execution class.
