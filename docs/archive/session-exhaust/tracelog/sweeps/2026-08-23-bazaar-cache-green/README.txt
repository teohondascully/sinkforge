A LIVE BUG IN SHIPPING CODE, AND THE GATE FOR IT.

  configured sweep: 112 PASS / 0 FAIL / 0 SKIP, six documented stand-downs, HARNESS_EXIT=4,
  HARNESS_RESULT=yes, 294s.

THE BUG. `Flora.grow` runs inside `FactorySim.tick()` and stamps a tree trunk straight into
`sim.solid` without setting `_bazaars_dirty`. Reachable through an ordinary player verb: plant a
sapling in your bazaar's open interior -- `can_plant_sapling` asks only for empty ground on soil,
and the bazaar's interior floor is earth -- and two minutes later the trunk closes the interior.
Probed directly before any fix:

    is_bazaar_at(o) before: true      find_bazaars() warm: [(40, 40)]
    is_bazaar_at(o) after:  false     find_bazaars() after: [(40, 40)]

The stall stays drawn and the near-bazaar craft gate stays open over a structure that is not a
bazaar, until an unrelated dig invalidates the cache. The mirror is worse: a trunk growing into a
ruin's one missing cell completes a bazaar nobody has been told about.

A SECOND, LATENT ONE FOUND IN THE SAME CENSUS. `load_world` writes `solid` in bulk and left the
flag to its caller. `main.gd` got away with it by loading into a fresh sim whose flag starts
dirty, and `SaveGame` did it by setting the private field by name from outside the class.

THE FIX is a named `FactorySim.invalidate_bazaars()`, called by Flora, by load_world itself, and
by SaveGame in place of the poke.

THE GATE is behavioural, not a source scan: a grep for `_bazaars_dirty` beside every `solid[`
write would have missed this one, because the write is in another file through a preloaded
reference. Six ways the world can change, each compared against a brute-force walk of the whole
grid, as SETS of origins rather than counts. 30 assertions. Every case also asserts that the
world really did change, so a case cannot pass by measuring nothing.

MUTATION CONTROLS (both retained here):
  flora forgets to invalidate  -> 3 FAILURE(S) of 30, showing the defect in BOTH directions:
                                  cache [] / world [(40,40)], and cache [(40,40)] / world []
  load_world forgets           -> 1 FAILURE(S) of 30, on the load case alone

RED-prose-before-reword.txt is the sweep before this one: 111 PASS / 1 FAIL, check_prose, on two
em-dashes and a date in the new game-code comments. The comment register caught them; reworded,
no rule relaxed.
