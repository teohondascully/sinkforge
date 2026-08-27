THE CONFIGURED SWEEP AFTER THE VERDICT-TAIL CONVERSION.

Head at run time: 9474ffd plus three uncommitted comment-count corrections (check_base.gd,
check_verdict_claims.gd, run_harness.sh), landed immediately after as one commit.

  configured sweep: 110 PASS / 0 FAIL / 0 SKIP, with six documented stand-downs
  HARNESS_EXIT=4   HARNESS_RESULT=yes   287s wall-clock

NOT A FULL SWEEP, and the runner says so itself: exit 4 means conditional rows were stood down
under SF_STRICT. The six are the registered ones and no others -- two in check_frametime, two in
check_grapple_reads, one in check_text_contrast, one in check_ceremony_reads -- which is the
reachable target tools/stand_downs.txt defines, not a pass with something quietly missing.

The five pixel-judging layers that went red on two of the four sweeps of 2026-08-22 all passed
here. That is one more green, not an explanation; the finding stays open.
