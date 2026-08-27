THE SWEEP THAT EMPTIED check_verdict_route's EXEMPTION LIST.

  configured sweep: 111 PASS / 0 FAIL / 0 SKIP, with six documented stand-downs
  HARNESS_EXIT=4   HARNESS_RESULT=yes   286s

check_frametime, check_opening and check_underground are converted. All 90 inheritors now reach
exit 0 only through _verdict(), and EXEMPT is empty.

THE RATCHET ASKED FOR THIS, on real data rather than on a synthetic mutant. The moment the three
became compliant, check_verdict_route went 3 FAILURE(S) of 12 — one per stale exemption, saying
"tighten the list the day it does not". That run is the evidence the ratchet is not decorative.

Not a full sweep: exit 4, six registered stand-downs, and the runner says so itself. Both
check_frametime rows resolved as before -- absolute-budget stood down on unset SF_PERF_HOST,
paced-phase out-of-reach -- so routing that layer through _verdict() did not disturb the
stand-down accounting it owns.
