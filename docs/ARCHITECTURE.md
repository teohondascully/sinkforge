# Architecture

**Status:** normative. **Last revised:** 2026-08-25. **Changes to anything in this document require an ADR in `docs/adr/`.**

---

## 1. The premise this architecture serves

Sinkforge is a game and a measurement instrument for game design. The instrument only works if automated agents can play the real game, thousands of times, with no human and no window, and produce evidence that is comparable to how humans actually play.

Every structural decision below follows from that. If a decision here seems expensive, check it against this question: *does it let an agent play the real game headlessly and comparably?* Most of them are the cheapest way to buy that property.

---

## 2. Layers

```
┌──────────────────────────────────────────────────────────────────────┐
│ L4  EXPERIMENT            the research layer. no game code.          │
│                                                                      │
│   claims/         one file per design assertion + threshold + status │
│   corpus/         every scenario ever written. append-only.          │
│   sweeps/         N seeds x M envelopes -> distributions             │
│   ablations/      change one data value, re-run, diff every metric   │
│   calibration/    recorded human sessions, same schema as agents     │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ metrics, provenance, verdicts
┌───────────────────────────────┴──────────────────────────────────────┐
│ L3  HARNESS               makes runs happen and comparable           │
│                                                                      │
│   scenario/       declarative fixture: seed, rig state, goal, budget │
│   envelope/       agent capability: fog, lookahead, noise, priors    │
│   driver/         headless boot, tick loop, budget enforcement       │
│   aggregate/      telemetry -> metrics -> report artifacts           │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ commands in / observations out
┌───────────────────────────────┴──────────────────────────────────────┐
│ L2  INTERFACE             THE ONLY DOOR. everything enters here.     │
│                                                                      │
│      observe(envelope) -> fogged view      apply(Command) -> Result  │
│                                                                      │
│   ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐  │
│   │  HUMAN     │   │  SCRIPTED  │   │  PLANNER   │   │  LANGUAGE  │  │
│   │  via view  │   │  bot (T0)  │   │  bot (T1)  │   │  agent(T2) │  │
│   └─────┬──────┘   └─────┬──────┘   └─────┬──────┘   └─────┬──────┘  │
│         └────────────────┴────────────────┴────────────────┘         │
│                              peers. same door.                       │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ Command / Observation. nothing else.
┌───────────────────────────────┴──────────────────────────────────────┐
│ L1  SIM                   pure. deterministic. engine-free.          │
│                                                                      │
│   world  terrain_gen  body  items  machines  behaviors  transport    │
│   fluid  economy  run  meta  commands  telemetry  invariants         │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
┌───────────────────────────────┴──────────────────────────────────────┐
│ L0  CORE          fixed-point · seeded split RNG · stable IDs        │
└──────────────────────────────────────────────────────────────────────┘

           VIEW hangs off L2 as a peer, never above L1
           ┌──────────────────────────────────────────┐
           │  render_world  render_entities  hud  fx  │
           │  reads observations · emits commands     │
           │  ONE narrow reverse channel:             │
           │    frame capture -> vision model         │
           │    (legibility claims only)              │
           └──────────────────────────────────────────┘
```

The research loop this enables:

```
   design claim ──> scenario ──> sweep ──> metrics ──> verdict
        ▲                                                 │
        │                                                 ▼
   human decides <── proposed data diff <── agent reads metrics
```

Agent proposes, instrument evaluates, human decides. That is the whole pitch, and it is achievable. What it is not, and must never be claimed as, is an agent autonomously optimizing engagement.

---

## 3. Dependency rules

Lint-enforced. A violation is a build failure, not a code smell. The lint lives in `tools/layer_lint` and runs in CI.

- `core` depends on nothing.
- `sim` depends only on `core`. **No engine imports. No file IO. No wall clock. No global mutable state.**
- `interface` depends on `sim` and `core`.
- `harness` depends on `interface`, `sim`, `core`. May do file IO and process control. May not depend on `view`.
- `experiment` depends on `harness`. May not depend on `sim` directly.
- `view` depends on `interface` and `core`. Reads observations, emits commands, never calls a sim mutator.
- `shell` depends on everything.
- **No module imports a sibling's internal files.** Each module exposes exactly one public interface file.

---

## 4. L1: the simulation

### Modules

Each is a directory with `MODULE.md`, one interface file, internal implementation, and tests.

| Module | Responsibility | Must not |
|---|---|---|
| `world` | Tile grid, chunks, material IDs, hardness, terrain queries and mutations | Know about machines or items |
| `terrain_gen` | Seeded strata generation, deposit and ruin placement, per-site parameters | Depend on run state |
| `body` | Player kinematics: integration, collision, depenetration, step-up, corner correction, coyote and buffer, climb, rope, swim, carry weight | Read input devices; know about rendering |
| `items` | Item instances as packed arrays; falling, settling, pile state, pickup | Own transport policy |
| `machines` | Instances, placement validity, tick scheduling, state machine | Contain per-machine-type code |
| `behaviors` | The composable primitives machines are built from. Under a dozen, ever. | Grow one class per machine |
| `transport` | Chutes (free, gravity), lifts (powered, cost per unit-meter), feeders. Implements R1. | Special-case machine types |
| `fluid` | Water automaton, active-cell set, flood level, aquifer breach | Tick every cell every frame |
| `economy` | Recipes, tiers, refinery conversion, haul accounting. Implements R2. | Hardcode quantities |
| `run` | Run lifecycle, flood clock driven by rig state (R3), termination, extraction resolution | Know about menus or saves |
| `meta` | Persistent rig state, unlocks, stockpile, offline processing | Mutate run state directly |

**One module shape is unresolved and it affects this table.** `docs/GDD.md` §8 leaves open whether the surface rig is a small fixed deck or a second buildable factory built upward. If it is a factory, `meta` is not one module: it needs its own placement, routing, and machine scheduling, and the honest options are either reusing `world`, `machines`, and `transport` against a second grid, or a dedicated `rig` module. Reusing is strongly preferred and is a reason to keep those three modules free of any assumption that there is exactly one world. Do not resolve this by building the deck version and discovering later that it cannot grow. Ask.
| `commands` | The complete typed command vocabulary | Contain logic |
| `telemetry` | Structured event emission from inside the sim | Do IO |
| `invariants` | Continuous assertions | Be disabled in tests |

### Determinism

- Fixed timestep, 60 Hz. Rendering interpolates. The sim never sees `delta`.
- Fixed-point (i32, 16 fractional bits) for all state-affecting positions and velocities. No `sin`/`cos`/`pow` on state-affecting paths.
- Seeded, split RNG: one stream per subsystem, streams are serialized state. No global random.
- No iteration over hash maps in state-affecting code. Sorted arrays or insertion-ordered structures with stable IDs.
- Generational-index entity IDs.
- Fixed tick phase order: `input → body → machines → transport → items → fluid → economy → invariants → telemetry`.

`replay_determinism_test`: run a 20,000-tick recorded input log twice from one seed, hash full state every 100 ticks, assert identical. Exists from day one.

### Invariants, asserted continuously

Conservation of matter across the tick modulo declared sinks. Non-negative buffers. No items inside solid rock. No machine in an invalid cell. Flood level monotonic within a run. Panic in debug, log in release. Most factory-game bugs are invariant violations discovered ten hours later.

---

## 5. L2: the interface

The only door. Two operations:

```
observe(envelope) -> Observation
apply(Command)    -> Result
```

**Commands are typed values, not method calls.** The full vocabulary lives in `sim/commands` and is small enough to read in one sitting. A command is submitted, validated, and either applied or rejected with a reason. Rejection reasons are part of the telemetry.

**Observations are filtered by envelope.** This is the part that is easy to get wrong and expensive to fix later.

### Capability envelopes

An agent with perfect information measures a different game than the one you ship. Agent capability is per-scenario configuration, not a property of the bot.

| Dimension | What it controls |
|---|---|
| Vision | Unexplored terrain, undiscovered deposits, unrevealed strata |
| Planning | Lookahead depth, whether replanning mid-action is allowed |
| Motor | Movement noise, reaction latency, raw controller vs semantic `goto` |
| Priors | Which recipes, machine behaviors, and map facts are known a priori |

Three standard envelopes:

- **Oracle.** Perfect information, optimal play. Measures the ceiling: dominant strategies, throughput maxima, exploits, reachability.
- **Constrained.** Fogged, bounded lookahead, movement noise. Measures the floor: discoverability. If a constrained agent never finds hole-as-conveyor, neither will a human.
- **Language.** Natural-language reasoning over player-visible observation only. Measures legibility. Slow, nondeterministic, never in CI.

**The gap between oracle and constrained is the difficulty of the design.** It is a number you can watch move.

### Two action levels

**Raw:** the same input frame a human produces. Used for movement testing and true agility measurement.

**Semantic:** `goto(cell)`, `mine(cell)`, `place(machine, cell)`, `haul_to(cell)`. Implemented on top of raw by an executor **inside the harness, never inside the sim**. Used where movement noise would pollute the signal.

**The raw level exists independently of `interface` and predates it in build order.** `sim/body` (§4) is validated first, against a fixed hostile-geometry chamber, before `sim/commands` or `interface` exist — movement is the highest-risk stage in the whole build sequence and should not sit blocked behind a command layer. That early validation driver is not a throwaway harness: it is a sequence of raw input frames replayed against `sim/body` with acceptance metrics read from telemetry, and it is built as the raw action level described above from the start. When `interface` lands, this driver becomes `observe`/`apply`'s raw path rather than being discarded. A second, incompatible input-replay format built for pre-interface testing would be a design leak; if one starts to look necessary, that is a sign to stop and reconsider rather than proceed.

The fog filter applies identically to the renderer and the agent. That is what makes an agent run and a human run comparable.

---

## 6. L3: the harness

### Scenario format

Declarative, versioned, schema-validated at build time.

```yaml
name: first_bore
claim: C001
seed: 12345
world:
  site: shallow_clay
rig:
  pump_capacity: 2min
  unlocks: [hand_pick]
  stockpile: {}
player:
  start_depth: 0
  pack: []
envelope: constrained
goal:
  type: deliver
  material: ore_copper
  quantity: 6
budget_ticks: 7200
assertions:
  - invariants_hold
  - no_edge_catch_events
  - sim_tick_p99_under_ms: 4
```

**Every scenario names a claim.** A scenario with no claim does not merge.

### Driver

```
sinkforge run --scenario scenarios/first_bore.yaml --seed 12345 \
  --agent scripted:greedy_miner --out runs/<timestamp>/
```

Outputs: `result.json`, `telemetry.jsonl`, `state_hashes.txt`, `input.log`, `report.md`, `heatmap.png`.

Must run with no GPU, no window, in CI, at 100x realtime or better for a two-minute scenario.

### Playable fixtures

A scenario is already a declarative fixture — the same YAML above, whether a bot or a human ends up
driving it. The driver takes a `--play` flag that boots one with a renderer and human input instead of
an agent, in place of `--agent`. No new system, one entry point; the scenario format and the fixture
format are the same format.

Every stage ships at least one playable fixture demonstrating what it changed, alongside the bot
scenarios in `scenarios/`. Fixtures are derived, never hand-authored: a seed, a config, and — where the
question is about feel rather than a cold boot — a recorded `input.log` from a real run, so before/after
review replays the identical input against pre- and post-change code rather than two different sessions.
Hand-crafting a state the game cannot actually produce is reviewing a game that doesn't exist. See
`docs/QUALITY.md` §2 for the mutation-testing analog of this rule, and `docs/TASTE_QUEUE.md` for how
fixtures reach review.

### Two clocks

**Fast loop.** Deterministic scripted bots, small scenarios, every PR, under sixty seconds total. Assertion-based, binary, gating.

**Slow loop.** Thousands of runs across seeds and envelopes, nightly, statistical. Non-gating, produces distributions and trend lines. **Never let the slow loop gate CI.** A flaky gate destroys trust in the whole suite within a week.

---

## 7. L4: the experiment layer

### Metrics that matter

**Strategy diversity.** Run 200 oracle agents with randomized objective weightings on one seed. Cluster their build orders. Convergence on one build means a dominant strategy and the rest of the design is furniture. A spread across many clusters with comparable outcomes means real decision space. This is computable, it is the thing factory games live or die on, and almost nobody measures it.

**Supporting family.** Time-to-milestone distribution. Stall seconds and their location. Backtrack ratio. Decision entropy per run phase. Payback time on built infrastructure. Fraction of unlocked machines a competent agent never uses (a direct measure of dead content). Oracle-to-constrained gap.

### Ablations

Change one data value, re-run the corpus, diff every metric. Balance stops being taste and becomes an experiment with a control.

### Calibration

A small corpus of recorded human sessions, captured through the same L2 interface, producing the same telemetry schema. Without it, every number the instrument produces is unfalsifiable and the first serious reviewer will say so. With it, you can state which proxies track human friction and which do not, which is a more interesting result than a clean dashboard.

Ten sessions is enough to start.

`docs/EXPERIENCE_EVALUATION.md` specifies how calibrated-agent journeys, screenshot-only criticism, and counterfactual A/B evaluation actually get run — the layers above what a single rendered-frame legibility check (`docs/CLAIMS.md` §5) can answer, and below what only a human session can. Specification and backlog only; implement no new harness subsystem for it before the readiness gates it states are met.

### The honest limitation, stated in every report

Agents find mechanical dead ends, softlocks, unreachable goals, and dominant strategies. They do not find boredom. Any engagement claim needs a stated proxy and a stated account of what it misses.

---

## 8. Content is data

The single strongest defense against a code monolith.

A machine definition is data:

```yaml
id: drill_mk1
tier: 1
footprint: [2, 2]
placement_rule: attached_to_vein
behaviors:
  - Consume { resource: fuel, rate: 1 per 40 ticks }
  - Extract { target: vein, rate: 1 per 30 ticks, hardness_max: 2 }
  - Emit     { port: bottom }
states: [idle, working, starved, flooded]
build_cost: { ingot_iron: 8 }
```

- Adding a machine is adding one data file. Zero new classes. A genuinely new verb means a new behavior primitive, which is an architectural event and needs an ADR.
- Recipes, strata, materials, upgrades, run configs, and progression curves get the same treatment.
- **Shaft modifiers are data too.** `docs/GDD.md` §2 makes per-shaft constraints (floods fast, no fuel above 50m, hard rock starts early) the primary source of long-tail variety, on the argument that constraint variety costs an order of magnitude less per hour of play than content variety. That only holds if a modifier is a data file and not a code branch. Design `terrain_gen` and `run` so a modifier composes with any site rather than special-casing one.
- Schema-validated at build time. A malformed definition fails the build, not the game.
- `data/` is human-diffable text. Never binary resources.
- **Balance numbers are never in code.** A tuning pass is a diff of `data/`, so an agent can change balance without touching logic and a human can review balance without reading logic.
- **Draft A versus Draft C is a data file.** If switching requires a code change, that is a defect.

---

## 9. Movement

`sim/body`. Fully deterministic, testable without rendering. This is what makes feel auditable.

### Resolution is not one number

Decided now, before `sim/body` or `sim/world` are built, because it's structural and expensive to
retrofit — even though feel tuning itself is deferred to stage 4. Four resolutions, decoupled:

| Layer | Resolution | Governs |
|---|---|---|
| Visual | 1px | fine grain |
| Terrain / digging | fine grid, 2-4px cells | what you excavate, what water flows through. `legacy/` already has a fine-terrain layer to port from. |
| Machine / logic | 16px | placement, ports, routing |
| Collision | **derived** from the fine terrain, never equal to it | see below |

**The derivation.** Noita's rigid bodies trace a polygon outline from the pixel grid (marching
squares), simplify it (Douglas-Peucker), triangulate, and hand the result to Box2D — collision
geometry is polygonal contours derived from pixels, never the pixel grid itself. That decoupling is
the real lesson, but the pipeline that produces it is not something to copy: it fights two
constraints this project has that Noita doesn't. The sim is engine-free, so the polygon solver would
have to be written from scratch rather than borrowed from Box2D. And the sim is fixed-point
deterministic, where real polygon collision (clipping, triangulation, manifold generation) is real,
expensive, hard-to-verify work.

Build the 80% version instead. Derive a per-column surface height from the fine terrain and treat
walkable ground as a heightfield: sub-pixel column heights, linearly interpolated between columns.
The player walks a 3px rubble slope as a ramp rather than colliding with three stacked steps. Ceilings
and walls stay grid-swept — nearly all edge-catching lives on the ground plane, which is what the
player is actually standing on most of the time, so that's where the payoff is concentrated. This is
trivially deterministic (integer column heights, linear interpolation, no geometry solver) and it's
incremental over a capsule sweep, not a rewrite.

Keep the existing forgiveness set on top of this, unchanged: capsule collider, auto step-up, corner
correction, shortest-axis depenetration, coyote time and jump buffer.

**Where the frictionless feeling actually comes from.** Noita players do get stuck on single pixels —
it's a documented complaint with a built-in unstuck mechanism — so Noita's collision quality is not
the source of its frictionless feel. Flight is: Noita gives the player near-unlimited vertical
mobility, which deletes ground-traversal friction entirely rather than solving it. That specific
answer isn't available here — a flying player breaks R1 outright (upward movement becomes free, lifts
become pointless, the central asymmetry evaporates) — so the primitive this project's freedom has to
come from is different. It's the rope. See "Rope and grapple: the vertical traversal primitive"
below and `docs/GDD.md` §1 for the full reasoning. Collision correctness (this section) is necessary
for good feel; it is not sufficient, and effort should be allocated accordingly once stage 4 starts.

### Rope and grapple: the vertical traversal primitive

Currently just one feature among several inside `sim/body` ("climb, rope, swim, carry weight" in the
module table above). It should be named and budgeted as the primitive that carries this game's
movement feel, the way flight carries Noita's — not because it needs to do everything flight does,
but because it's the one system where getting the feel right buys the most. Concrete requirements,
not yet tuned but stated so a build can be checked against them: fast attach, fast climb, no
fumbling, auto-anchor at shaft mouths, a dismount that does not fling the player, and swing momentum
worth chaining. If traversal ends up feeling great, it will be because the rope is great, not because
collision is perfect.

| Property | Value |
|---|---|
| Collider | Capsule or rounded AABB, 1 tile wide, 2.5 tall |
| Ground accel / decel | 8 ticks to max / 4 ticks to zero |
| Air control | 60% of ground accel |
| Coyote time / jump buffer | 6 ticks / 6 ticks |
| Variable jump | Release cuts upward velocity to 40% |
| Apex float | Gravity x0.6 within 3 ticks of apex |
| Auto step-up | 1 tile, no input, when blocked and the cell above is clear |
| Mantle | 2 tiles on toward-and-up hold |
| Corner correction | Horizontal nudge up to 6px on ceiling contact near a corner |
| Depenetration | Shortest-axis ejection, max 1 tile per tick, never teleport |
| Machine collision | Non-solid to the player except a 1-tile base |
| Carry penalty | Accel and jump scale with pack mass. Collision behavior never changes. |

**Acceptance criteria, automated, run against a fixed hostile-geometry chamber** with 1-tile ledges, 1-tile pits, machine clusters, narrow shafts, half-dug slopes, rope transitions, **sub-tile rubble slopes, 1-to-3px ledges, and jagged fresh-dig surfaces**. That last group is not optional texture on the chamber — as specified before this addition, the chamber would pass a controller that still catches on excavated debris, which is the surface the player is actually standing on most of the time (this is what the heightfield collision derivation above exists to handle; the chamber has to actually exercise it):

| Metric | Threshold |
|---|---|
| `edge_catch_events` | 0 |
| `depenetration_events` | 0 |
| `velocity_efficiency` | ≥ 0.92 |
| `step_up_success_rate` | 100% |
| `corner_correction_success_rate` | 100% |
| `input_to_state_change_latency` | ≤ 2 ticks |
| `stall_seconds` (input held, blocked unintentionally) | 0 |
| `traverse_time` on the standard route | within 5% of golden |

A movement change that regresses any of these fails CI. "It feels sticky" becomes a number.

---

## 10. Performance budgets

Budgets are asserted, not aspired to. Each has a benchmark scenario in CI.

| Budget | Target |
|---|---|
| Sim tick p50 / p99 | ≤ 2.0 ms / ≤ 4.0 ms at 2,000 machines, 20,000 items, 40,000 active fluid cells |
| Frame time p99 | ≤ 16.6 ms at 1080p |
| Draw calls | ≤ 150 |
| Headless throughput | ≥ 100x realtime |
| Save / load | ≤ 250 ms at late-run state |
| Peak sim memory | ≤ 256 MB |

**Why this is the research loop and not polish.** A two-minute run is 7,200 ticks. At 2 ms that is fourteen seconds of compute, or well under a second headless. A thousand-run sweep is a couple of minutes on a few cores. At 20 ms per tick the same sweep takes half an hour and you stop running it. The perf budget determines whether the slow loop exists at all.

Requirements to hit it: no node per item or per machine; event-driven machine ticks so idle machines cost zero; active-cell fluid; chunked terrain with dirty-rect rebuilds; a uniform-grid spatial index, not a quadtree; flat render packets, no per-entity objects crossing a boundary. Note also that per-frame cosmetic scanning of all machines and fluid (for audio or HUD) is a real cost that is easy to leave out of a budget; it belongs in the budget.

---

## 11. Save and run lifecycle

```
MetaIdle → SiteSelect → RunConfig(seed, start_depth, loadout, pump_capacity)
  → RunActive(flood clock ticking)
  → RunEnding(extraction resolution)
  → RunResolved(materials banked, artifacts applied)
  → MetaIdle
```

- Run state and meta state are separate structs with no shared mutable references. A run can be discarded without touching meta. This is what makes runs cheap to simulate in bulk.
- Run duration derives from rig pump capacity. Never a constant.
- Two files: `meta.save` (durable, precious, written atomically) and `run.save` (disposable, mid-run resume). A corrupt `run.save` must never take down `meta.save`.
- Versioned schema with an explicit integer version and a migration chain, each migration unit-tested against a stored fixture save.
- Offline processing is a pure function of elapsed real time, applied on load. Never a background timer.

---

## 12. Language and runtime

**GDScript, for now.** The prior codebase demonstrated, by measurement rather than assertion, that the three concerns behind an earlier Rust recommendation are already addressed: the sim was genuinely node-free under the strictest available test, determinism was proven live by byte-identical replay including a save/load round trip, and untyped declarations are already a build failure via project settings.

What remains of the case for a port is runtime headroom at a scale nothing has been measured against. That is not a reason to migrate; it is a reason to build the benchmark.

**The trigger for revisiting this is a specific benchmark scenario at the Section 10 load returning a number GDScript cannot hit.** Not a deadline, not a document. Building that benchmark is independently worth doing and should happen early.

If the trigger fires, the sim's engine-free boundary is what makes a port tractable, which is another reason that boundary is worth its cost.
