# Freight Winch — graybox implementation plan

`DIRECTOR_BRIEF.md` §3.9 asks for the economic envelope and packing semantics *before* graybox, and this
document is the step after both: a scope for the seven-item prototype slice, grounded in the codebase as it
actually is. Local-only (`docs/handoff/`, gitignored via `.git/info/exclude`), matching the convention of
`Q1_FREIGHT_WINCH_PAIN_OPTIONS.md` and `FREIGHT_WINCH_ECONOMIC_ENVELOPE.md`, which this builds on directly
rather than restating.

**What was cleared before this could be written:** Q1 (which sink — Option A + relocatable Option B
geometry), the lateral-vs-vertical measurement (174 frames mean, inside the 114-232 climb reference range),
and the economic envelope's six-item envelope plus six-item packing semantics. Two items that document left
OPEN, and the one it named an ENGINEERING GAP, are resolved below by reading precedent rather than deferred
further — this is the "first real architectural decision" that document said graybox work would have to
make.

## Director ruling, 2026-08-24 — accepted and superseding the open items below where it settles them

The economic envelope is accepted as the basis for this phase. Q1 is confirmed in the director's own words:

> The first Freight Winch retires repeated upward cargo hauling from a deep active face, using a relocatable
> trunk and receiver. It moves freight, not the player, and leaves lateral movement and grappling expressive.

Five working defaults, adopted as this document's decisions (renumbered against the sections below rather
than left as a separate list, so nothing reads as merely proposed where it has actually been settled):

1. Route persistence: the `winch_routes` top-level save key decided below — **confirmed**, not just proposed.
2. Invalid route on load: **fail closed at the route level**, not the whole save — preserve surviving
   machines, invalidate only the bad link, **preserve any cargo by materializing it at a surviving endpoint
   or a safe floor location, emit a diagnostic, never silently destroy cargo**. This corrects and replaces
   the dangling-reference handling this document originally proposed (which dropped in-flight cargo along
   with the route — a real defect, caught by this ruling before any code shipped it; see below).
3. A player grappled to the mechanism at pack/removal time: **detach cleanly using existing grapple-release
   semantics** — no damage, lockup, or lost input. This is now a formal acceptance case (see below), even
   though the precedent read already shows it is currently a vacuous case (a grapple cannot anchor to a
   machine at all today) — named explicitly so the case is tested, not merely reasoned about, and so it
   still holds if a later pass makes the cable/skip grappleable.
4. Recommissioning: **stays instant** unless the graybox build demonstrates a startup sequence adds real
   physical feedback without becoming a chore — matches this document's own PROPOSAL, now confirmed as the
   default rather than merely proposed.
5. Power: **the existing power grid**, not a new fuel item, unless the prototype proves it creates an
   unwanted fuel-hauling loop — likewise confirmed as the default.

**Explicitly out of scope for this slice** (director's words): production art, full logistics networking,
fuel chores, player elevators, multiple-route support. **Sequencing instruction**: implement only after the
plan and its acceptance cases are explicit — the acceptance-case list below is written to satisfy that
directly, and is the gate before any of the file-level work in this document's touch list proceeds.

## Resolving what the economic envelope left open

### Grapple-at-pack-time — RESOLVED, PRECEDENT, no new code needed

Checked directly rather than guessed. `scenes/grapple.gd`'s anchor logic (`advance`, `_catch`, `trace`) tests
only `sim.is_solid(cell)` — never `machine_at(cell)`. Player body collision separately blocks on
`is_solid(cell) or machine_at(cell) != null` (`scenes/player.gd`, cited in `PRIORITY.md`'s "building under
the player" finding), but the grapple's own catch logic does not consult machine presence at all. Neither
`pickup_machine` nor `remove_machine` (`factory_sim.gd:1671-1822`) reference `grapple` anywhere, and neither
does `scenes/main.gd`'s machine-removal call sites.

**Conclusion: a grapple line can never be anchored to a machine cell, only to solid terrain.** Picking up a
Winch head or station therefore cannot orphan a grapple anchor, because one could never have formed there in
the first place. Nothing needs to change for this invariant to hold in v1. If a later pass makes the moving
skip/cable itself grappleable (§3.3's "may become grapple geometry"), that is new anchor logic reached
through a different path, not a pack-time hazard — out of scope for the prototype slice, which only asks
that the player "can grapple with or around the moving mechanism" (item 4), not onto it.

### Route reference storage — DECIDED

Follows `save_game.gd`'s own convention rather than inventing one. `conduit`, `rope`, `torch`, `water`,
`fill` are each a flat top-level `Dictionary` alongside `machines` in the save envelope
(`save_game.gd:83-107`); no existing field inside `MachineState` references another cell. A new key,

    winch_routes: { Vector2i head_cell : Vector2i station_cell }

matches that shape exactly and touches no other machine's schema. Treated as **additive**, like `water` /
`fill` / `sapling`: absent on an older save defaults to `{}`, exactly the pattern `_stage()` already uses
(`save_game.gd:196-224` — `env.get("water", {})` etc.), so no version bump or migration branch is required.

**Dangling-reference handling — the one piece the envelope explicitly left unresolved.** Two failure modes
exist and they are not the same thing:

- **Structural corruption** (wrong types) — follows the existing additive-key precedent exactly: no new
  validation infrastructure invented, matching how `lode`, `water`, `fill` are handled today (blind
  `as Dictionary` cast — a corrupted key here fails exactly as those already do, no new behavior).
- **Semantic dangling** (well-formed entry, but one cell no longer holds the expected machine — e.g. a
  station picked up independently of its head) — **this is not save corruption, it is an expected
  consequence of ordinary play** (per §3.6, relocating a depleted endpoint is meant to be normal, not an
  error state). Refusing the whole save over it — the treatment `_stage()` gives a bad `MachineDef` id
  (`save_game.gd:177-193`, whole-envelope refuse) — would be the wrong tier of response: that refusal exists
  for saves referencing content that no longer exists in the build, not for ordinary in-session teardown.
  **Decision, per the director's ruling above: after `machines` is rebuilt, cross-check every
  `winch_routes` entry against the rebuilt set; drop (not refuse-whole-save) any entry whose head or station
  cell is missing or holds the wrong def — but fail closed at the route level, never at the cargo's
  expense.** A dropped route means exactly what it should mean in the world: the head and station stop being
  linked, the skip stops moving between them, and the player sees why (empty buffers, no motion) — which is
  §3.6's own standard, "I see why it stopped, and I already know what I want to change," applied to the
  loader's failure mode instead of just the machine's runtime one.

  **Cargo in flight at the moment a route is dropped must not disappear with it** — this document's first
  draft got this wrong (it proposed erasing the matching `winch_transit` record along with the route, which
  is silent destruction, caught by the director's ruling before any code shipped it). Corrected policy:
  - If the **head** machine still exists (only the station is invalid) → materialize the transit's items
    into the head's own `input_buffer`. Always safe: the head cell is confirmed to exist by the same
    cross-check that found the route invalid.
  - If the **head** machine no longer exists → materialize the transit's items onto the world floor at the
    head's last-known cell, reusing whatever existing "spill items outside a buffer" mechanism the codebase
    already has (the same path `take_into_pack`'s cap-overflow spill uses) rather than inventing a new
    item-placement mechanism. If no such precedent is found to be reusable as-is, the fallback is the
    station's `input_buffer` if the station exists; if neither endpoint exists, this is a genuine gap to
    flag rather than paper over with an invented mechanism.
  - Either branch **emits a diagnostic** (`print()` is sufficient for this graybox slice) — per the
    director's ruling, a dropped route must be visible in the log even though the graybox slice has no HUD
    surface for it yet.

**And the same rule should not wait for a reload to discover it.** `pickup_machine` / `remove_machine`
should also purge any `winch_routes` entry keyed to the cell being removed, in the same call, so a route
dangles for zero frames rather than until the next save/load — one small addition to two existing functions,
not new machinery. This in-session path salvages into the player's pack (the existing `pickup_machine`
buffer-salvage precedent), which is a different and simpler case than the load-time one above: the player is
standing right there, so "the pack" is the correct, already-precedented destination — the load-time
materialize-to-floor/head-buffer rule above only applies when there is no player action to attach the
salvage to.

## Architecture — reusing what already exists, naming what's new

**Machines stay single-cell and data-driven; no new "kind" system.** `MachineDef.behavior`
(`src/data/machine_def.gd:14-17`) is documented as "a thin deletable label, not a type enum, so the sim can
branch on the few non-recipe-runners" — the existing precedent is `&"splitter"` and the lift behavior
(`_run_lift`, `factory_sim.gd:2024+`), dispatched from `_run_machine` via `_BEHAVIORS.get(machine.def.behavior)`
(`factory_sim.gd:1975-1980`). **Propose two new behaviors, `&"winch_head"` and `&"winch_station"`, on two new
single-cell `MachineDef` resources**, following the exact `.tres` + behavior-flyweight convention every other
machine already uses. No multi-cell machine, no new persistence class.

**The route, not the machine, owns transit state — and it must bypass `_flow()`, not feed it.** Checked
directly rather than assumed: every existing machine's `output_buffer` is drained same-tick by `_flow()`
into an ADJACENT cell (straight down its column by default, or wherever a `dests` behavior entry routes it
— `factory_sim.gd:2760-2775`, `_destinations`/`_destinations_lift`). There is no existing notion of an item
in transit over multiple ticks anywhere in the sim; a lift's `LIFT_THROUGHPUT` caps *rate*, not *travel
time*, and delivers same-tick regardless. A winch route is the first genuinely new case, and it has to stay
out of `output_buffer` entirely to keep it that way: **`winch_head` fills the normal way on its
`input_buffer`** (whatever feeds it — hand-drop, belt, adjacent extraction), and its `run` behavior reads
directly from `input_buffer`, never populates `output_buffer` (so `_flow()`'s per-machine step no-ops on it
by construction — `machine.output_buffer.is_empty(): continue` — no `dests`/`flow` registry entry needed).
Each tick, if a station is linked and has buffer room, and no transit is already in flight, it moves up to
trip capacity out of its own `input_buffer` into a transit record — route-scoped, not machine-scoped, a
second dictionary alongside `winch_routes`: `winch_transit: { head_cell: {items: Dictionary,
ticks_remaining: int} }` — then decrements `ticks_remaining` each tick until it empties into the station's
`input_buffer` (the station's own `run` behavior, or the head's, whichever is simpler to keep the transfer
single-writer). This keeps `src/` node-free and keeps the conservation invariant intact by construction:
items leave one buffer and enter another, with an accounted-for dictionary in between, never a bare
subtraction.

**The skip is representation only.** `scenes/` reads `winch_transit` (how full, what fraction of the trip
elapsed) to draw cable tension, skip position, and load — it writes nothing back, matching the seam every
other representation reads (`docs/handoff` architecture note, confirmed by grep: no `scenes/*.gd` writes to
`sim.machines` state directly anywhere in the tree today). A new `scenes/winch_skip.gd` (or a method on
`world_renderer.gd`, matching wherever moving-machine visuals already live) is pure read.

**Power, not fuel.** `winch_head`'s tick calls `power_throttle(machine.cell, WINCH_POWER_DEMAND)`
(`factory_sim.gd:1959-1967`, the exact call `_run_lift` already makes) and gates trip capacity or transit
speed on the returned factor — identical shape to the lift's existing power-scaling, not a new subsystem.
Carries forward the economic envelope's PROPOSAL (§4, item 4) as the implementation default.

## Acceptance cases — the explicit list the director's sequencing instruction gates implementation on

One fixture, reused across cases rather than a separate world per case: one deep active face (a vertical
shaft, ore at the bottom, matching the existing `trip_frames`/lateral-measurement fixture shape already
proven in this session's own scratch scripts), one relocatable trunk (the shaft itself — nothing new to
build, it is the existing dig), one winch head placed at the face, one receiver placed at the top. Cargo
moves upward (head → transit → station), which is Q1's confirmed direction — no lateral or downward case is
in scope for this slice. The player remains responsible for route setup (the link verb) and for lateral
access to both endpoints (walking there, per the existing traversal verbs) — the Winch does not move the
player, only the freight, per Q1's own wording.

1. **Depletion case.** The face's ore runs out while the route is live. The head's `input_buffer` empties
   and stays empty (nothing feeds it); no crash, no stuck transit, the route stays linked and simply idles —
   matching §3.6's "a stopped winch must not strand the player."
2. **Relocation case.** The player picks up the head (or station) after depletion and re-places it
   elsewhere. Free, instant, full refund (`pickup_machine` precedent) — covered by the in-session purge path
   above, not the load-time one.
3. **Pack/rebuild case.** Either endpoint is packed and rebuilt without ever having been part of a save/load
   cycle — pure runtime, exercises the `pickup_machine`/`remove_machine` purge-and-salvage path only.
4. **Invalid-route-load case.** A save is loaded where one endpoint's cell no longer holds the expected
   machine (constructed directly for the test, not waited for) — exercises the `_stage()` cross-check and
   the cargo-materialization policy above, including the sub-case where a transit was mid-flight at save
   time.
5. **Grapple-detach case.** The player grapples near/at a Winch head or station cell, then the machine is
   packed or removed. Per the precedent check above, a grapple cannot anchor to a machine cell at all today
   (`is_solid` only, never `machine_at`), so this case's acceptance evidence in v1 is: confirm the grapple
   was never anchored to the machine in the first place (i.e. the precedent holds, not a new detach code
   path) — no damage, lockup, or lost input, trivially, because nothing needs to detach. Recorded as a real
   case rather than assumed so it is re-checked if the cable/skip ever become grapple geometry later.
6. **Conservation check, every cargo path.** One assertion per path rather than one general claim: hand-fed
   → head buffer → transit → station buffer (the normal case); transit → head buffer (invalid-route-load,
   head survives); transit → floor (invalid-route-load, head gone); head/station buffer → pack
   (pickup/relocation). Each is a `total_produced - total_consumed == present` check before and after, per
   this codebase's existing conservation-test convention.
7. **Visual/audio states — named now, authored later.** Graybox scope means these are *states to gate
   representation-layer logic on*, not final art or sound: **startup** (route just linked / power just
   reached the head), **movement** (transit in flight), **arrival** (transit empties into the station),
   **obstruction** (station buffer full, head has cargo waiting — the visible-queue case from item 5 of
   §3.9), **failure** (route dangling/invalid, or unpowered). `scenes/` reads `winch_transit` /
   `winch_routes` / `power_factor` to select which of these five states is current; the graybox
   implementation should expose that state (even as a debug label or existing placeholder sprite swap) so a
   later art pass has something concrete to hang animation on, without this slice producing that art itself.

## Sequencing against §3.9's seven items

1. **Manual haul first.** Already true — `PACK_BULK_CAP=90` and the trip-count evidence
   (`factory_sim.gd:218-224`, `trip_frames`) already make hauling a repeated, felt cost. No new work; a
   design note for whoever sequences the tutorial/unlock, not an engineering task: don't let the Winch
   become buildable before a player has made at least one capped trip by hand.
2. **Choose two endpoints, install one route.** New: the two `MachineDef`s above, placed through the
   existing `build_from_pack` / `_placeable` path unchanged (same cost, collision, and footprint rules as
   every other machine — no new placement code). New: a **link verb** — aim at an owned, unlinked head,
   confirm, aim at an owned, unlinked station, confirm — writing one `winch_routes` entry. Follows the
   existing verb-dispatch pattern in `scenes/main.gd` (reach-gated, one key, same shape as `_toggle_grapple`
   or the feed verbs).
3. **The skip moves one real material, no teleport or loss.** The `winch_head` tick + `winch_transit`
   dictionary described above. Conservation is structural, not asserted after the fact: total across
   (head output buffer + transit record + station input buffer) is invariant every tick by construction,
   which is checkable the same way every other conservation property in this codebase already is
   (`present == produced - consumed`, unchanged, since nothing here is a production or consumption event).
4. **Grapple with or around the moving mechanism.** No new anchor code (see resolution above) — satisfied by
   *not* placing anything that blocks `is_solid` terrain checks near the route, and verified by playtest, not
   a new mechanic.
5. **Under-capacity setup produces a visible queue.** Direct consequence of a finite trip capacity and
   transit time — no separate mechanic. Visibility: check whether `hud.gd` already has a generic
   buffer-fill-level affordance (a fill bar or similar) before inventing one; if one exists, reuse it for
   head/station buffers rather than adding a bespoke Winch-only readout, per this project's own
   single-ownership-of-implementation rule.
6. **Player recognizes the queue and changes something, objectives suppressed.** Not implementable — this is
   the same evidence class as `DIRECTOR_BRIEF.md` §4.4 (Evaluation A) and T0.1: a human-judgment finding, not
   a harness assertion. Named here only so it is not silently dropped: the acceptance evidence for this item
   is a playtest observation logged after graybox lands, not a passing test.
7. **Source depletes; player extends, moves, or abandons without losing progress.** This is the economic
   envelope's packing semantics section, already answered: `pickup_machine`-identical free/instant relocation
   of head or station (no new cost invented), cable recovers itself because nothing was ever spent as a
   countable resource (route-as-property, not route-as-object), and the dangling-route purge above fires
   the moment either endpoint is picked up — so the "lost progress" failure mode this item warns against is
   closed by the same mechanism that closes the save-load ENGINEERING GAP, not a second one.

## What this plan is not

It does not pick exact numbers — trip capacity, transit ticks, `WINCH_POWER_DEMAND` — those need one short
tuning pass once the mechanism exists to tune, not a value guessed in prose. It names the five graybox
visual/audio *states* above (a gating requirement from the director's ruling) but does not design the
hero-machine's actual art, animation, or sound (§3.7) — that is a separate art/character pass, not gated on
this document, and explicitly excluded from this slice ("no production art"). It does not implement the
Evaluation A–N harness instrumentation from §4 — those measure a mechanism that does not exist yet. And it
does not re-litigate anything the economic envelope already decided; this is the next document in that
sequence, not a replacement for it.

**Grounded file-level touch list**, not a task list to execute unreviewed: `src/data/machine_def.gd` (no
change — behavior is already a free-text `StringName`), two new `.tres` defs under wherever `DEF_DIR` points
(`save_game.gd`'s `DEF_DIR` constant), `src/core/factory_sim.gd` (`_BEHAVIORS` registration, `_run_winch_head`
/ `_run_winch_station`, `winch_routes` + `winch_transit` state, purge-on-pickup in `pickup_machine` /
`remove_machine`), `src/core/save_game.gd` (`capture`/`_stage` additive-key handling per above),
`scenes/main.gd` (the link verb), `scenes/hud.gd` (buffer-fill reuse, only if nothing suitable already
exists), one new `scenes/*.gd` for the skip's read-only visual.
