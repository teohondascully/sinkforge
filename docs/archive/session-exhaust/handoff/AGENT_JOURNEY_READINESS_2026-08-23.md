# Agent-journey evaluation: readiness gates, measured

UNTRACKED, and it sits beside the protocol it reads. Written during the overnight run of 2026-08-22/23,
against `main` at `63b75cd`.

**Verdict: DO NOT IMPLEMENT OR RUN. Gate 6 fails, and the protocol says a failure there makes the
evaluation `INVALID` rather than low-scoring.** Nothing about the design is questioned here; the gates are
the design's own precondition and one of them is not met.

## Gate 6 — actor boundary. **FAILS, decisively.**

> *"the actor can be given only player-visible information. If the implementation still exposes
> `FactorySim`, target cells, inventories, resource lists, objective IDs, or world-event state to its
> decision policy, the evaluation is INVALID."*

`tools/play_agent.gd` is 786 lines and its decision policy reads the sim directly, fifty times:

    git grep -oE '\bsim\.[a-z_]+' -- tools/play_agent.gd | sort | uniq -c | sort -rn

    25  sim.is_solid          12  sim.inventory          4  sim.machine_at
     4  sim.is_climbable       4  sim.in_bounds          3  sim.surface_row
     2  sim.solid              2  sim.machines           1  sim.is_bulk_item
     1  sim.inventory_slots    1  sim.carried_bulk

Four of those are named in the gate's own prohibition list — `FactorySim` itself, target cells
(`sim.solid`, `sim.is_solid`, `sim.surface_row`), and inventories (`sim.inventory`,
`sim.inventory_slots`, `sim.carried_bulk`). This is not a near miss.

**It is also not a defect in `play_agent.gd`.** That actor exists to drive harness layers deterministically
and cheaply; reading the sim is why it is fast enough to run in a sweep and stable enough to assert
against. The gate is about a *different actor* — one whose decisions are judged. Satisfying it means a
second implementation with a player-visible feed, not a rewrite of this one, and the protocol's own
"actor is a calibrated instrument" section is where that belongs.

**The cheapest honest next step** is a boundary the code can enforce rather than a promise: a feed object
the judged actor is handed, holding only what a player can see, with `FactorySim` unreachable from it. Then
gate 6 becomes checkable by a layer instead of by reading — the same move the verdict-route gate made for
the exit protocol this week.

## The other five, on the evidence to hand

These were not audited to the same depth, because gate 6 already blocks the run. Recorded so the next
pass starts from something.

| gate | reading | evidence |
|---|---|---|
| 1 — safe isolation | **likely satisfied** | `with_machine.sh` refuses to boot without an isolated `HOME`; `run_harness.sh` arms and verifies a save sentinel around every sweep; `check_save_isolation` and `check_lock` are registered layers and green |
| 2 — truthful route | **unmeasured** | `check_progression_payable`, `check_bazaar_ruin` and `check_vein_guard` exercise the shipping seed, but none of them asserts *the opening route is completable through player-facing verbs with no injected inventory* |
| 3 — unmanufactured desire | **unmeasured** | nothing in `scenes/objectives.gd` matches `rail` or `permanent`; whether the rail is absent after the opening lesson has to be established by playing it, not by grep |
| 4 — legible route | **partially satisfied, and narrower than the gate** | `check_underground` asserts lamp-lit deep rock is not dead space, and passes. The gate asks for *every underground region required by the route*, which nothing enumerates |
| 5 — evidence feed | **likely satisfied** | `tools/capture_moments.gd` and `tools/capture_manifest.sh` exist and retain captures without overwriting canonical ones |

Two of the five are unmeasured and one is narrower than its gate. **A readiness report that called this
"one gate short" would be wrong**: it is one gate failed, two unmeasured, and one satisfied over a smaller
population than the gate names.
