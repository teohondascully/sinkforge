AREA 4, BULLET 3 -- "a number means the same thing on two machines".

  configured sweep: 111 PASS / 0 FAIL / 0 SKIP, six documented stand-downs, HARNESS_EXIT=4,
  HARNESS_RESULT=yes, 286s. SF_PERF_HOST unset, exactly as before.

THE DEFECT. The frame SLO's allowances -- MISS_QUIET 1.0%, MISS_WORKING 6.0%, SEVERITY_X 3.0x --
were global constants ratcheted onto five runs of one Mac16,8, and they applied unchanged to ANY
box whose operator set SF_PERF_HOST. Naming a second machine would have asserted the first
machine's numbers on it. That is the Area 4 requirement failing in the one place the project
makes an absolute performance claim.

THE FIX. tools/perf_hosts.txt: one row per host per phase, each carrying the measurement it came
from and the model the measurement was taken on. A host with no rows is a hard FAIL, never a
fallback to somebody else's numbers and never a stand-down.

FOUR PATHS, ALL RUN (frametime-runs/):
  SF_PERF_HOST unset               -> stands down as before, PASS (5 asserted)          ft_a
  SF_PERF_HOST=some-other-box      -> FAIL, "a machine this repository has never measured"
  SF_PERF_HOST=mac16-8-120hz       -> asserts, "allowances read from ... (4 phase rows)"  ft_c/ft_d
  model column changed to MacIntel99,1
                                   -> FAIL, "measured on MacIntel99,1 and this box reports Mac16,8"
  a tab removed from one row       -> FAIL, "line 56 has 5 tab-separated fields, needs 6"

AND A READING THAT DID NOT FIT, KEPT. Six runs on the named host at load average 3.1-5.3: five
clean, one with SWING at 1.5% against its 1.0% allowance -- three late frames where all five
neighbours read zero. The allowance was NOT moved. This layer cannot tell a contended box from a
real tail, and widening a bar to fit a reading converts "we cannot tell" into "this is fine".
r1..r5 are the five clean runs; ft_c.log is the exceedance.

The host stays unarmed, and now for two reasons instead of one: IDLE's known one-frame margin,
and SWING's exceedance measured today.
