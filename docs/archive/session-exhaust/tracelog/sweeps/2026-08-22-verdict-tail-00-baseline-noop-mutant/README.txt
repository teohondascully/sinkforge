STEP 0 — THE "BEFORE" HALF OF THE PAIRED MUTATION, AND THE REASON THE WHOLE SLICE EXISTS.

Tree:      c3e5284, clean, main == origin/main
Mutation:  every one of the 55 hand-rolling layers had `_check(cond, label)` overridden to record
           nothing. Assertions still ran; none of them were counted.
Command:   SF_ONLY='^(check_agility|...|check_wrap)( |$)' SF_LOG_DIR=<this dir> tools/run_harness.sh
Result:    55 PASS / 0 FAIL / 0 SKIP of 55 selected (of 110 declared — SUBSET RUN), 120s wall-clock.
           HARNESS_RESULT=yes.

WHAT THAT MEANS. Fifty-five registered layers exited 0 — reported as green by the runner, quotable in
a summary — having tested nothing at all. Not one of them noticed.

Confirmed rather than inferred: `grep -cE '^[[:space:]]*(PASS|FAIL):'` over all 55 retained logs
returns 0 for every one, so the override really did take and the layers really did assert nothing.
The same grep on the unmutated run of 2026-08-22 returns 26 for check_bits, 21 for check_drift,
14 for check_seam, 11 for check_seam_flood — so the instrument can see assertion lines when there
are any. A zero here is a measured zero and not a broken grep.

The three registered hand-rollers NOT in this population, and why: check_frametime, check_opening and
check_underground never call `_check()` at all. They hand-roll their own comparisons and their own
diagnostics. Converting them is assertion rewriting, not protocol-tail conversion, and it is out of
this slice's scope by the slice's own definition. They are also, for exactly that reason, the three
layers this guard will still not cover afterwards. Recorded as an open finding, not as a pass.

The "after" half of this pair is the same mutation over the converted tree: every one of the 55 must
then exit 1 with "the layer made NO ASSERTIONS and reached its verdict anyway".
