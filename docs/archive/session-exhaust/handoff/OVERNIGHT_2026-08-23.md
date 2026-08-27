# OVERNIGHT HANDOFF — 2026-08-22 into 08-23

    branch          main   (one worktree, no branches created, no worktrees created)
    started at      c3e5284   (2026-08-22 23:44)
    ended at        0b9410c
    note            an earlier draft of this file said "started at 23dce82". That commit is on NO branch:
                    the history rewrite landed between it and the run's real first commit, so citing it
                    sends a reader to an orphan. Verified with `git merge-base --is-ancestor`.
    origin/main     63b75cd   pushed mid-run; the last 17 commits are UNPUSHED
    worktree        clean

**Nothing was force-pushed, no history was rewritten, no public ref was moved, no threshold was lowered,
and no failure was converted to a SKIP.** One item that would have left this machine is written up under
AUTHORIZATION BOUNDARY rather than as an item I did not reach.

---

## What the night was

Thirty-four commits, seventeen of them pushed mid-run. The A+ programme reached its exit: all six areas closed with the evidence named, the
configured sweep green on `main`, every stand-down carrying a written reason.

The recurring shape, stated once because it explains most of the list: **an instrument that cannot
register its subject reports a quiet green.** A wait whose budget was smaller than the thing it waited
for, and whose passing runs sampled the one frame of a fade-in that reads zero. Two layers reporting on
art that had not been drawn, where every control they already carried passes its hardest on a blank
frame. Two counting layers with population floors and nothing that could say no. Two collision detectors
never shown finding a collision. A gate that ran in exactly one place, and that place had been red for
days. And, underneath all of it, a suite where a layer could fall from 112 assertions to one and still
print PASS.

---

## Done, with the evidence

    5889720  the base-member scan had no way to fail                        control + twin + mutation
    9bec472  the ceremony wait's budget was smaller than what it waited for mutation names the lesson
    748c499  two pixel layers reported on art that had not been drawn       2 mutants, both exit 1
    68fd817  A_PLUS_STATUS records those three
    e61bba6  two counting layers had floors but nothing that could say no   2 mutants; the twin caught one
    2af2bde  the empty-stage reference was moving the shutter it served     measured 203 -> 168 levels
    cd039b0  the shader-cache hypothesis, tested outside its own domain     limit recorded with the result
    8d5428d  two collision detectors never shown finding a collision        both comparisons forced false
    ba4796a  the control census, so the next control is chosen by evidence
    05bc77f  a layer could stop asserting and the sweep would still be green  6 control paths exercised
    526b382  the assertion floor, and the control that passed for the wrong reason
    a721eab  the manifest gate ran in one place, and that place had been red
    747cb79  91 rows against a suite of 113 is a gap, so the gap is named
    3d6e622  what a byte-identical tree cannot see
    b3b7507  the four largest bodies of assertions in the suite were held by nothing  3 controls
    19b3054  A_PLUS_STATUS: the floor gate's second rule
    0b9410c  the runner's two load-failure protections, fired rather than assumed

Every one of these carries its command, its result, and its mutation control in the commit message.

### The three findings worth reading first

**The green was the dangerous outcome, not the red.** `check_ceremony_reads` wanted a frame with nothing
happening on it before photographing a rope, because a lesson bubble drawn over the rope BECOMES the rope
to a brightest-pixel scan. The wait needed 12.4 seconds and allowed 10.0, and promotion sets the bubble's
life with nothing shown yet, so the first frame of the fade-IN reads alpha 0.00 exactly and the wait exited
on it. The failing run and the passing run were one defect. The frame is made quiet by construction now,
through the game's own returning-player path, and no budget was raised.

**A control I added moved the shutter it was there to serve.** Taking a per-subject empty reference inside
`check_machine_state`'s loop put ten physics frames between `set_solid` and `place_machine`. Measured on
the pre-change file with nothing else altered, that moved the Generator's working face from 203 levels to
168 and its state difference from 137 to 100, which is the difference between that subject reading and not
reading. The references are gathered in a pass of their own now. **The finding underneath is still open and
is queued below**: this layer's ratios are a function of when it photographs.

**A byte-identical tree cannot see a generated file go stale.** CI had been red on the capture manifest.
Only column three had moved, on 51 of 52 rows, with names, dates, recipes and the whole grouping unchanged:
the signature of a history rewrite, which moves which commit `git log --follow` lands on. The rewrite's own
verification asserted the tree byte-identical, and it was.

---

## The strongest verification available, run at the end

    bash tools/run_harness.sh
    113 PASS / 0 FAIL / 0 SKIP of 113  (4 passes stood down 6 assertion groups)
    stand-downs: exactly the registered ones, 6 id(s), 6 line(s) in total
    HARNESS_EXIT=4    HARNESS_RESULT=yes
    assert_floors: PASS -- 108 layers still assert at least what they did
    HARNESS_QUOTABLE=yes
    docs/tracelog/sweeps/2026-08-23-final-green/

**The accurate sentence is "configured sweep passed with six documented stand-downs."** Not "full sweep",
not "all 113 layers fully asserted". A sweep with a display cannot reach exit 0 and never will: three of
the six stand-downs are structural.

Twelve sweeps were retained under `docs/tracelog/sweeps/`, including the two reds:
`2026-08-23-assert-floors-MUTANT-red` (the floor gate turning a 112-PASS sweep into exit 7) and the
`check_machine_state` red inside `2026-08-23-accounting-controls-green`, which the shutter fix explains.

---

## AUTHORIZATION BOUNDARY — queued, not taken

1. **Seventeen commits are unpushed.** `origin/main` is `63b75cd`, pushed earlier in this run; `main` is
   `0b9410c`. A push to `main` is not a local decision and is only undone by a force-push, which is on the
   stop list, so it was not taken. Nothing about the tree requires it.

       git push origin main

   **CI is currently RED on `63b75cd`**, on `capture_manifest.sh --check`, and `a721eab` is the fix. The
   other two jobs are green on that head. Pushing is expected to clear it; nothing else in CI is red.

2. **`MOTION_MARGIN` in `check_machine_state` cannot be trusted against the numbers it judges.** The same
   three subjects read 16x / 10x / 4.4x when the bound was calibrated, 8.6x / 5.0x / 3.0x with the
   reference inside the loop, and 6.9x / 6.3x / 28.1x with it in a pass of its own. Ten frames of fixture
   timing decide a verdict. Re-deriving the bound needs the negative population it was derived against,
   the pre-gate Drill at 1.9x, which no longer exists. **Nothing was moved to accommodate the red.**

3. **`frametime.paced-phase` resolves out-of-reach on this host every run.** Arming it means accepting an
   allowance that a reading has exceeded. `tools/perf_hosts.txt` records why nothing arms it.

4. **Gameplay and the Freight Winch.** The programme is at its exit so nothing blocks them, but which slice
   comes first is a director's call, not an engineering one.

---

## BLOCKED, with the blocker named

**The agent-journey evaluation: DO NOT IMPLEMENT OR RUN.** Its own gate 6 fails.
`docs/handoff/AGENT_JOURNEY_READINESS_2026-08-23.md` carries the evidence: `tools/play_agent.gd` makes 50
direct `sim.*` reads, 25 of them `sim.is_solid`. Gates 1 and 5 look satisfied, 2 and 3 are unmeasured, and
4 is satisfied over a smaller population than the gate names.

**Two pixel layers remain environmental and unexplained.** `check_machine_identity` and
`check_machine_state`, one sweep each on 2026-08-22, never reproduced. The shader-cache hypothesis was
tested: its precondition is real (fifty isolated homes, not one file matching `*shader*`), and a probe
capturing the viewport at eleven offsets from frame 0 to 90 found the first frame as fully rendered as the
ninetieth. **But that probe ran alone, and both reds appeared only under a dozen concurrent engine
processes**, so the treatment was never applied in the domain where the symptom lives. Weakened, not
retired. The probe is kept at `tools/_scratch_cold_pipeline.gd`.

What changed for those two is that they can now tell the candidate causes apart: a frame that did not
render withholds the art finding and says the stage did not draw.

---

## What the next session should not have to rediscover

- **The rolling queue is `docs/tracelog/OVERNIGHT_QUEUE.md`** and it is untracked, like this file.
- **`docs/A_PLUS_PROGRAM.md` had three tables answering the same question, and they disagreed.** It has
  one now. Area 6 was measured from the remote rather than argued from the sentences in it: 887 commits
  where the census counted 1015, the session logs in none of them, and 0 of 887 messages carrying a word
  from the held-out list, with a positive control at 23 commits and a negative at 0.
- **Two memories were corrected against that measurement.** Both said the history rewrite was authorized
  but unexecuted. It was executed and pushed.
- **`bash tools/assert_floors.sh --write <log-dir>`** regenerates the floors after a deliberate change.
  Lowering a row is a deliberate act and the commit that does it has to say which assertion went and why.
