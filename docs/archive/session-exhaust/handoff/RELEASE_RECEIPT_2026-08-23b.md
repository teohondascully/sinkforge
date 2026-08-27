# Release receipt — 21 commits ahead of origin/main

UNTRACKED. Prepared 2026-08-23 under the director's continuation requirement: a receipt is owed for any
local commits ahead of `origin/main`. **The push is NOT taken.** A push is undone only by a force-push,
which is on the stop list, so it stays at the authorization boundary.

    origin/main   9377a91
    main          c3e9ea8
    ahead         21       behind  0
    worktree      clean, one canonical worktree plus the approved Lane A laboratory

**AMENDED 2026-08-23, third time.** This receipt was written at 5 commits and `defdc44`, amended at
`685646d`, and amended again at `b0e3348`. Two more have landed since. The verification below has been
RE-RUN against the actual current HEAD rather than a parent, which was the specific gap the director
named. Every count in this file now describes `c3e9ea8`, verified by a sweep at that exact commit:
**113 PASS / 1 FAIL / 0 SKIP of 114, 327s, `HARNESS_RESULT=yes`, `HARNESS_QUOTABLE=yes`**, the one FAIL
being GR-06. Logs `/var/folders/wx/qzmllhgn0cj5q26_mb77s3n00000gn/T/tmp.lFa8cQdwST`. GR-06 is now
NARROWED rather than merely known: its verdict reverses between p90 and p99 of the same frame, and the
ladder that shows it prints every run. This receipt carries
TWO player-visible changes, `baff88f` and `c744f2a`, which no harness layer asserts; both were verified by
photograph and by scratch probe. It also carries `6958cb2`, which repairs a statistic that had returned a
constant since it was written. Stand-down groups
fell from six to five: `ceremony.words-vs-sky` was paid and retired from the registry.

**One caveat travels with this receipt and must not be dropped on push.** `check_machine_identity` failed
at `3858b4e` (112 PASS / 2 FAIL) and passes at `5d39f93`, but it is an INTERMITTENT red and one clean
sweep is one sample. `5d39f93` repairs a proven contributor and a subject-removed probe shows a second
one still firing. Its status is UNDER OBSERVATION, not closed. See `docs/handoff/OVERNIGHT_RUN_STATE.md`.

## The commits

Regenerated from `git log 9377a91..HEAD`, not hand-maintained.

    5ea5a6f docs: two documents named things that were not there
    0a2153f fix(machines): the face table described an exception it never had
    9c6611e docs(terrain): the cobble note said itself twice
    4b7e160 fix(hud): the machine inspector printed across the stratum plate
    defdc44 chore(floors): ratchet check_hud_layout to the two assertions it gained
    5963bba fix(hud): the grapple lesson printed across the bend it was describing
    685646d test(T1.0): the first rung to fill the pack, and it hauls the full load out
    3b5d0dc test(UI01): the occlusion number becomes a rule, with its control inside it
    73e1b6f test(UI01): ask whether the occlusion class reaches the sapling lesson
    aa71a1f test(T1.0): a hand miner wins the burst and leaves most of the vein
    fac0c71 fix(harness): the reference picture was late, not settled
    f1cf298 fix(pilot): the rope anchor could not see a gap below the top of its reach
    b0e3348 test(T1.0): trips to clear a face, the other half of the priority-1 row
    3858b4e docs(harness): the motion bar's own comment described the estimator it replaced
    5d39f93 fix(harness): the clock pose never reached the layer drawing the glints
    95f36ea test(T2.1): the open-sky arm has its distribution, so the words get a ratchet
    918c210 fix(pilot): the play agent fed machines through a verb no key reaches
    baff88f feat(hud): the one placement refusal that had no words
    c744f2a feat(hud): the help card listed every bound key except zoom
    6958cb2 fix(harness): _count_over compared luma against a level and returned zero for everything
    c3e9ea8 test(GR-06): the verdict reverses inside the top decile, so the ladder prints beside it

## What changes, and what does not

     docs/A_PLUS_STATUS.md       | 14 +++++++--
     docs/LODE.md                |  8 ++---
     scenes/fine_terrain.gd      | 18 ++++-------
     scenes/hud.gd               | 50 +++++++++++++++++++++++++++++--
     scenes/main.gd              |  8 +++++
     scenes/visuals.gd           | 17 ++++++-----
     tools/assert_floors.txt     |  2 +-
     tools/capture_moments.gd    |  3 +-
     tools/check_casing_light.gd | 12 +++++++-
     tools/check_hud_layout.gd   |  9 ++++++
     tools/play_tests.gd         | 73 +++++++++++++++++++++++++++++++++++++++++++--
     11 files changed, 179 insertions(+), 35 deletions(-)

**Three of the 7 change no executable line at all** (`5ea5a6f`, `9c6611e`, and the docs half of the
others): zero non-comment lines across every `.gd` file in them. The two that do are:

- `4b7e160` — one predicate in `scenes/hud.gd`. The machine inspector now stands down while a stratum
  arrival is on screen. This is the only **player-visible behaviour change** in the set, it is a design
  call recorded as SHIP in its own message, and it is reverted by deleting ` or plate_on_screen()`.
- `defdc44` — one row in `tools/assert_floors.txt`, raised to match a measurement. Tightening only.

## Verification, on the tree being shipped

    bash tools/run_harness.sh                 AT b0e3348 ITSELF, clean tree from launch to verdict
    113 PASS / 1 FAIL / 0 SKIP of 114         369s; and three times at fac0c71 before it
    tools/play_tests.gd                       ALL 20 PLAY-GOALS MET, which is the regression check that
                                              matters for f1cf298: four other rungs climb through the
                                              function it changes

    BACK TO ONE RED. GR-06 is the standing director-owned design call and is unchanged.
    check_machine_identity, which was the second red at aa71a1f, has a repair at fac0c71 and is UNDER
    OBSERVATION rather than closed: 3 clean sweeps post-fix against 2 failures in 5 pre-fix is
    consistent with a fix and is not evidence of one.
    GR-06 is the same assertion as the baseline, read from the log rather than assumed:
      88.1 vs 142.2 levels against a 1.15x floor, where the baseline read 88.2 vs 141.3.
      Both of its controls PASS in the same run, so it is a design finding, not a dead frame.
    the FAIL                                  check_grapple_reads, GR-06, known and director-owned
    layers reported                           114 of 114; 0 load failures; 0 silent
    stand-downs                               exactly the registered ones, 6 ids, 6 lines
    assert_skip_route                         PASS -- 114
    assert_floors                             PASS -- 114   (control: check_agility at 7)
    HARNESS_RESULT=yes                        HARNESS_QUOTABLE=yes

**Baseline comparison: identical.** The last sweep before this set, at `9377a91` which IS `origin/main`,
was also 113 PASS / 1 FAIL / 0 SKIP of 114 with the same single red and the same six stand-downs. **No new
red and no worsened red.**

    check_prose         PASS (446 asserted), 60 files clean, 364 more on the wide sweep
    check_trailers      PASS, 979 commits, one author, no trailers

## Risk, stated rather than implied

**CI will still show one red job after this push**, and that is a choice rather than an oversight.
`check_grapple_reads` fails `GR-06` every run by design, pending a design call that must not be resolved
by moving `BODY_MARGIN`. Nothing in this set touches it and nothing in this set clears it.

**The one behaviour change is unreviewed by a human.** It has geometry (21x32 canvas px of overlap removed),
a matched before/after capture pair at normal scale, and a control proving the inspector was suppressed
rather than never posed. It has not been played. If the director dislikes it, the revert is one clause.

## Rollback

    git reset --hard 9377a91     # discards all 5, local only

Nothing here rewrites a public ref, deletes a recovery artifact, lowers a threshold, or converts a failure
to a skip.
