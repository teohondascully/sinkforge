> **ARCHIVED 2026-09-03.** The overnight fleet/lane plan of 2026-08-30. Superseded twice: by the
> sequential-port directive of 2026-09-01 (`docs/PORT_ORDER.md`) and then by `docs/A_PRIME_REFACTOR_PLAN.md`
> (D0341/D0342). Its §0 cardinal rule — port the logic, refactor the form, never rewrite from scratch —
> survives verbatim in the A′ plan §1. Its "current (~15%)" figure and its lanes are historical.

# MASTER PLAN — maximum verified progress by morning

*For the engineer/orchestrator agent. Standing plan; re-read at the top of every /loop cycle. GOAL: the director wakes to a large amount of REAL, MERGED, GREEN progress — not five symptoms fixed, not a pile of half-branches, not a rewrite that reproduces what already worked. Close the legacy↔current gap comprehensively and fast, by PORTING working logic and refactoring it clean, to A+ modularity, self-tested by deterministic agent-playthroughs, merged frequently to ONE main. Foot on the gas. The only brakes are the corrupting-failure class (determinism) and the one corrupt-everything module (the collision resolver).*

---

## 0. THE CARDINAL RULE — port the logic, refactor the form. NEVER rewrite from scratch.

The last week was lost rebuilding a working sky from scratch. That must not repeat. For EVERY legacy system in scope:

**"Use legacy X" means: READ legacy's working code for X, LIFT the algorithm/logic that already works, and REIMPLEMENT it clean and modular against the CURRENT sim's interface. It does NOT mean rewrite-from-scratch, and it does NOT mean copy-paste-with-coupling.**

- If legacy's forge works, you do NOT rewrite the forge. You read forge logic, keep the working algorithm, and re-express it against the current interface — dropping legacy's coupling, keeping legacy's behavior. Same for chute, drill, water, freight, rope-sim, everything.
- Where legacy's logic is deterministic-compatible already (water_flow.gd is integer-only and order-stable per the map — near-direct port), the reimplementation is close to a lift.
- Where legacy's logic is float-tangled, keep the working algorithm and swap ONLY the tangled part (FastNoiseLite → core/SplitRng). Do not rewrite the algorithm because one input was float.
- Rewriting-from-scratch is BANNED unless the logic itself is wrong (the terminal-economy structure is the one genuinely-wrong thing — that gets redesigned, not ported). "It's legacy" is not a reason to rewrite. "It's coupled" is a reason to refactor at the seam, not to rewrite.
- The test for every unit: did you reproduce legacy's working behavior faster by porting-and-refactoring than you would have by rewriting? If you're rewriting logic that already worked, STOP — read the legacy code and port it instead.

This is the single rule that makes "a lot of progress by morning" achievable: porting working logic is fast; rewriting is the week-on-a-sky trap.

---

## 1. THE /loop SELF-REMINDER (top of every 30-min cycle)

Re-read this doc, then restate in one line each:
1. Which lane, which next unit, pulled from LEGACY_GAP.md (§3)?
2. Am I PORTING legacy's working logic and refactoring clean, or accidentally rewriting from scratch (§0)? If rewriting logic that worked, stop and go read the legacy code.
3. Is everything finished MERGED to main and green? A branch/worktree is not truth (§5). If not merged, reconcile before new work.
4. Determinism green on main? (the one corrupting failure — §4 Risk 2)
5. Am I about to mark a feel/look item "done" that is the director's eye to judge? Downgrade to BUILT-PARKED + screenshot (§4 Risk 3).
6. Does this unit meet the A+ modularity/auditability bar (§2)? If not, it doesn't land.

---

## 2. A+ MODULARITY, QUALITY, SENIOR-STAFF AUDITABILITY — standing bar, every commit

The reason to port-and-refactor rather than copy-paste: the substrate's whole value is clean, modular, auditable code. A port that drags legacy's coupling poisons that. So every landed unit:
- **Modular:** single responsibility, one public interface, no sibling reach-in. A painter reads its Frame; a sim system exposes observe()/apply(); legacy's coupling is refactored OUT at the seam.
- **Sized:** 400-line file / 50-line function caps hold; split at real seams (legacy's headers have measured seam tables), never trim WHY-comments to squeak under.
- **Auditable — the senior-staff test:** legible cold. Header stating what+why, WHY-comments on non-obvious decisions, a deterministic agent-playthrough documenting behavior by exercising it, a ledger entry per judgment call.
- **No vacuous gates:** every check asserts over a real population (TestBase.over()) and is mutation-tested.
- **Determinism-clean by construction:** sim-path code is fixed-point/integer, no engine RNG/clock/FastNoiseLite/hash-map-iteration-on-state.
- **Visible restraint:** what's deliberately NOT ported/built is documented.
- **Demo-grade record:** every milestone leaves a before/after capture keyed to its commit.

A+ is not overhead — good-looking AND clean AND auditable is the entire reason to rebuild rather than pay down legacy's debt. Legacy was good-looking and debt-laden; current must be good-looking and clean. Porting-and-refactoring (not copy, not rewrite) is how you get both.

---

## 3. THE SCOPE IS THE WHOLE DELTA — generate it, work it continuously

Do NOT work from the director's example symptoms. FIRST ACTION: build docs/LEGACY_GAP.md — the ranked living backlog of EVERY gap between legacy (complete game) and current (~15%), generated from the legacy↔current diff (the migration map inventoried 55 files/28,522 lines — use it plus a fresh legacy pass). For each gap: does current have it, at what fidelity, and is it PORT (legacy's logic lifts+refactors) or REDESIGN (legacy's logic is wrong, like terminal economy). Rank by player-visible-impact × portability. Refresh as items close. Pull the next-highest each cycle. This will be dozens-to-hundreds of items — that's the point; the run works them continuously, not five symptoms.

Categories the backlog spans (the generated list is the real worklist): cave carving/shape, depth shading, light pool, shadow veil, parallax, back-wall, water rendering, particles, post-fx, shaders, miner sprite, pickaxe+swing, tool/item/machine sprites, camera/zoom/shake/scale, movement feel (audit each verb vs legacy), rope/grapple, mining feel, forge/chute/drill/bin/feeder logic, water/fluid sim, transport/winch/freight, HUD (depth/bands/hotbar/objective/keys/map), synthesized audio (hollow tell, breach, blow, depth-mixed score), materials/recipes/strata data, world-gen invariants, the agent-playthrough harness, determinism fast-track.

---

## 4. THE FIVE RISKS + META-RISK (per-cycle checks)
1. **Lane file-set collisions** — declare each lane's file set; serialize on intersection; live lane→files table in WORKING.md.
2. **World-gen determinism swap (the sim-adjacent lane)** — two-process replay after every commit; diverge = pause that lane, sole priority; noise swap before golden capture (CI Linux, D0167).
3. **Feel/look "done" over-claim** — BUILT-PARKED + screenshot for the director's eye; "done" = machine-verifiable only.
4. **New/ported sim code higher-risk** — full treatment: deterministic, replay-tested, agent-playthrough-tested; rushed sim parks.
5. **Half-finished lanes** — finish one vertical to DONE-MERGED-GREEN before breadth; track per-lane state (NOT-STARTED/IN-PROGRESS/BUILT-PARKED/DONE-MERGED-GREEN) in WORKING.md.
**META-RISK — over-correction:** the two guardrails that do NOT loosen are the determinism hard-stop and park-the-resolver-change. Everything else fast.

---

## 5. ONE SOURCE OF TRUTH — strict reconciliation (mandatory)
A task is NOT done until merged to main and green on main. Branches/worktrees are WIP, never truth.
- One main. Every lane on a branch. Merge each completed unit AS SOON AS built-and-self-tested — small frequent merges, not hours of divergence.
- Rebase-only, main protected, every merge through a passing-checks PR. Can't pass → fix or park, never bypass.
- Before the run is done: `git branch --all` + `git worktree list`, every one accounted for — merged at SHA / parked-documented / discarded-with-reason. Nothing stranded (the 469MB-orphaned-refs failure must not recur).
- Divergence detected each cycle → rebase onto current main before drift.
- Reconciliation report: every branch/worktree + disposition; state plainly what is on main and green.

---

## 6. DETERMINISM FAST-TRACK (the novelty — its own priority lane, build early)
The determinism suite is ~93% string-building, not simulation: state_signature() re-serializes ~46,805 cells ×200 checkpoints ×3 processes = ~28M formats; the sim is 7%. The sim has NO wall clock (tick-only, ~200-3000× real time) — ALL slowness is re-serialization. Fix: state_signature() becomes an O(1) running hash updated incrementally on every mutation path (set_material/excavate/extend_terrain_dig_extent). ~74s → ~5s. CAUTION: the hash IS the determinism contract — it must update on EVERY mutation path or it agrees when worlds differ; mutation-test that a forgotten update breaks a test. Then shard the fuzz by seed (fix grid-per-seed reset first — also fixes the fuzz-population cluster). Fast tests → more agent-playthroughs per commit → the behavioral-coverage novelty scales.

---

## 7. THE LANES (categories the backlog sorts into; parallel where file-sets don't collide; each pulls its highest-ranked backlog items, ports-and-refactors, self-tests, merges)
- **A — camera/feel/scale:** zoom, framing, shake, sprite scale. (Body-collision-width = resolver, PARK proposal.)
- **B — world-gen/atmosphere (sim-adjacent, Risk 2):** port legacy's cave carving (noise→SplitRng), depth shading, light pool, shadow veil, parallax, back-wall, strata. Biggest visual jump.
- **C — sprites/visuals:** port miner sprite, pickaxe+swing, tool/item/machine sprites, particles, post-fx, shaders, glimmer.
- **D — agent-playthrough harness (build EARLY, safety substrate) + §6 fast determinism:** per-verb test pattern, O(1) hash, sharding. Makes everything else verifiable and fast.
- **E — verbs/systems (port legacy's working logic, refactor clean):** mining feel, forge, chute, bin, feeder, drill, water/fluid (near-direct port — integer-only), transport/winch/freight (port the throttled-per-trip mechanism), rope-sim (Risk 4). Sim + view.
- **F — HUD/UI:** port depth readout, strata bands, hotbar, objective card, key hints, map, the UI theme grammar. Much of "looks like legacy." (MERGE — trim dead content.)
- **G — audio:** port synthesized SFX (hollow tell, breach, blow-against-material) and depth-mixed score. Synthesized at boot, no assets.

---

## 8. DURABLE DESIGN INVARIANTS — guardrails only (NOT sequencing; sequencing is freed for speed)
These bind because they're the game's identity; do NOT violate them, but do NOT let them slow the build:
- R1: down free, up powered. R2: deep material required not more valuable. R4: upgrades change the problem shape, NO global multipliers ever. Hole-as-conveyor (excavation IS routing). Rig-as-consumer at the top. No combat/enemies/health-bar. No roguelite (dead). No idle beyond the retention feature. Material not currency. Terrain generated not pre-built. Every item collectible by walking over it; no hidden inventory; blocked machines legible; starved/jammed/running animations.
- REDESIGN (don't port) the one genuinely-wrong thing: the terminal-economy structure. Everything else ports.
- The week-old spec's SEQUENCING (ten-minute-test-first) is OVERRIDDEN — it was written when work was crawling. Build fast and broad now. The durable invariants above still hold; the order does not.

---

## 9. THE STANDING BACKLOG (fold in as tails)
Gate 2 filter fix; Seams doc-drift (3 files); gate-7 docs-exclusion (both-directions proof); empty-state guard rollout to fuzz suites; Droid's 19/1 gate findings (fix cheap like gate 28's missing subprocess guards, park judgment-dense like gate 1/P008); P016 fuzz-bound slack (PARK, entangled with fuzz-population, don't ratchet); the fuzz-population fix (grid-per-seed reset, enables §6 sharding); headed-boot CI green on Ubuntu.

---

## 10. HARD STOPS (pause the lane or run; document; continue others)
Determinism replay diverges → pause that lane, sole priority. Collision resolver needed → park proposal. Lane file-sets intersect → serialize. Ported/new sim can't be made deterministic-and-tested in a bounded window → park. state_signature O(1) can't be proven to update on every mutation → do NOT ship (it's the contract). data/economy structure REDESIGN (not this run's porting scope — the economy is the one redesign, sequence it separately). PR blocked only by gate 7 (pre docs-exclusion) → park, never bypass. Reconciliation finds stranded work → fix before done. Rewriting logic that already worked in legacy → STOP, port it instead (§0). 10h or backlog dry → stop, reconcile, report.

## 11. REPORT
- LEGACY_GAP.md generated/ranked (how many items, how many DONE-MERGED-GREEN this run, honest remaining fraction to legacy).
- Per lane: DONE-MERGED-GREEN vs BUILT-PARKED (screenshot for director's eye), each with its agent-playthrough, milestone capture, determinism status. For each ported system: confirm it was PORTED-AND-REFACTORED, not rewritten (name the legacy source it lifted from).
- §6: determinism suite new runtime (~5s target), O(1) hash mutation-tested.
- §2: confirm every landed unit meets A+ (modular/sized/auditable/tested) or name what didn't and why.
- §5 RECONCILIATION: every branch/worktree accounted for; what's on main and green.
- Backlog chipped. Over-correction check. Anything that felt wrong though it passed.

## 12. THE FRAME
The director has waited a week and is right to demand real progress by morning. The way to deliver it WITHOUT repeating the week-on-a-sky failure is the cardinal rule: PORT legacy's working logic and refactor it clean, never rewrite from scratch. Generate the full gap backlog, work it continuously across parallel lanes, port-and-refactor every system that legacy already solved, build everything to A+ modularity so the result is good-looking AND clean AND auditable, self-test with the deterministic agent-playthroughs legacy pioneered, fast-track the determinism suite so those tests are cheap, and merge frequently to one true main so nothing strands. Foot on the gas; the only brakes are determinism regression and the collision resolver. The durable design invariants (R1, hole-as-conveyor, rig-as-consumer, no-multipliers, no-combat) hold; the week-old sequencing does not. Wake the director to a lot of real, merged, green, auditable progress — legacy's proven logic on the substrate's clean bones, moving at the speed this always could have moved.
