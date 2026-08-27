The writer-population ratchet added to check_bazaar_cache.
  configured sweep: 112 PASS / 0 FAIL / 0 SKIP, six documented stand-downs, HARNESS_EXIT=4,
  HARNESS_RESULT=yes, 287s.  check_bazaar_cache: PASS (35 asserted).

The behavioural cases cover the ways the world changes that somebody thought of. Flora.grow was
not one of them for as long as it existed, because it lives in another file and reaches the grid
through a preloaded reference. So the POPULATION is asserted too: 55 .gd files under src/ and
scenes/ scanned with comments and strings stripped, and exactly two write the coarse grid.

Mutations: a third file starts writing solid -> FAIL naming it; a known writer dropped from the
expected list -> FAIL. Both retained here.
