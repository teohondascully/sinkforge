# sim/run

## Purpose — SHAPE OPEN, 2026-08-27; the hub tick lives here since 2026-09-03

**What is here now (D0349, D0353, D0355):** `hub_tick.gd`, `HubTick` — legacy `FactorySim.tick()`'s
fixed order as a stateless phase runner over the three services (`World`, `Items`, `Machines`), at
`HUB_TICK_DIVISOR = 3` on the 60 Hz body tick (D0345); `world_seeder.gd`, `WorldSeeder` — the one door
a new world comes through (generate, wrap, stamp a `data/starts` record, hand back the spawn); and
`verbs.gd`, `Verbs` — the situated verbs the body does from where it stands, legacy's main-scene
state-logic blocks over the four services. None is a session state machine; all foreclose nothing below.

This module's purpose used to be a session lifecycle: `MetaIdle -> SiteSelect
-> RunConfig -> RunActive -> RunEnding -> RunResolved`, owning a flood clock
driven by rig state, termination, and extraction resolution. That entire
premise assumed a session was a bounded, disposable expedition with a
defined end. The run-based structure it implemented is retired
(`docs/GDD.md` §9, `docs/DECISIONS_LEDGER.md` D0076) — one persistent shaft
under one permanent rig doesn't reset, so there is no `RunResolved` to
reach and no `MetaIdle` to return to.

What replaces this module is genuinely undecided, not just unbuilt. Local
flooding (R3, now continuous section-level upkeep rather than a run-ending
clock) and shaft-to-surface haul/extraction resolution still need to live
somewhere — this module, a renamed version of it, or something that folds
into `sim/meta` once that module's own open question (below) resolves. Do
not build the state machine above. Read `docs/ARCHITECTURE.md` §4's `run`
row and §11 (kept as a record of the pre-reversal design, not a spec)
before deciding anything here — this is a real design question, not
something to resolve unprompted (`ONBOARDING.md`: "do not resolve the open
design questions yourself").

## Must-not

- Know about menus. No UI concepts here — whatever session state ends up being is data that
  `view`/`shell` render, not something this module presents.
- Know about saves. Persisting state across process launches is `shell`'s job; this module just
  produces the state that gets saved.

## Dependencies

`core` and the gameplay submodules it sits above: `world`, `terrain_gen` (generates the shaft, once,
at creation — no longer "at run start"), `body`, `items`, `machines`, `behaviors`, `transport`,
`fluid`, `economy` (extraction resolution converts hauled items to value).

The cyclic-dependency question this file used to flag against `sim/meta` (rig state feeding a flood
clock, results feeding stockpile, each module needing the other) survives the reversal in spirit —
local flooding still needs rig-adjacent state, and haul results still need to reach a stockpile —
even though the specific "at `RunConfig` time" resolution no longer applies, since `RunConfig` doesn't
exist as a concept. Still deliberately *not* declaring `sim/meta` as a dependency until this is
resolved, for the same reason as before: keeping both out of each other's dependency list forecloses
nothing.

## Consumers

`interface`, at minimum, once there is a concept for it to surface via `observe()`. No sim-internal
consumer is declared.

## Tick phase

Not itself a tick phase. The old framing — this module gates *whether* the fixed tick loop runs at
all, only during `RunActive` — assumed a session with an inactive phase. Under one persistent shaft,
does the tick loop simply always run? Unresolved, part of the same open question as Purpose above.

## Public API

- `HubTick` (`hub_tick.gd`) — `step(world, items, machines, rates = null)`: power field, each machine
  in placement order, `Flow.step` (D0350), water, prune empty piles, `rates.sample` when a
  `ProductionRate` is handed in (D0351; seep and flora join on a ruling); `advance(body_tick, …) →
  fired`: `step` on every `HUB_TICK_DIVISOR`th tick.
- `WorldSeeder` (`world_seeder.gd`, D0353) — `load_world(site, seed) → World`, `stamp(world, items,
  machines, start_id, site_id = &"") → bool` (validates every fixture before stamping; `last_refusal`),
  `stamp_record(…, dict)`, `spawn_logic_cell(start)`, `SURFACE_ROW_M` (the generator's datum in metres).
  Lives here, not in `terrain_gen` as the plan filed it: stamping places machines and stocks the pack.
- `Verbs` (`verbs.gd`, D0355) — `Verbs.new(world, items, machines, body)`; `build(cell) → outcome`
  (pick up a machine/conduit/rope/torch/sapling there, else place what `selected` names: sapling, torch,
  conduit, rope, machine facing the body's way, supported block), `drop() → units` (into a reachable
  eater, else forward, else down; the landing gets `DROP_GRACE_TICKS`), `collect() → units` (piles within
  2.5 m, not graced), `configure(cell) → toast`, `link_winch(cell) → armed|linked|failed`, `tick()` (ages
  the grace), `placeable()`, `body_occupies()`, `can_reach()` (`Aim.in_reach_logic`), `state_signature()`.
  Its state (selection, grace, the armed head) is session-scoped and not in the save.

## Gotchas

**The Purpose section above is the load-bearing gotcha now: this module's entire premise changed
2026-08-27 and its replacement isn't decided.** Read it before assuming anything else in this file.

**Freight Winch / haul-mechanic work is gated on this module and `sim/commands` having real
implementations, not just skeletons.** Same directive and reasoning as `sim/commands/MODULE.md`'s
Gotchas entry — do not resume Freight Winch work until both modules actually exist as code, and note
that "real implementation" now depends on the shape question above being resolved first.
