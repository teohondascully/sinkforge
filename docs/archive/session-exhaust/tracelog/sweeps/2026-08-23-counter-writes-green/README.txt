The sweep for the second rule: no layer moves _passes or _failures itself.
  configured sweep: 111 PASS / 0 FAIL / 0 SKIP, six documented stand-downs, HARNESS_EXIT=4,
  HARNESS_RESULT=yes, 287s.

Six fixture-bails were hand-rolled `_failures += 1` + `printerr("  FAIL: ...")`, which is
byte-identical to _check(false, label). Converted, and the rule added to check_verdict_route.
Mutation: put the pair back into check_pump -> FAIL naming check_pump.gd, 1 of 12.
