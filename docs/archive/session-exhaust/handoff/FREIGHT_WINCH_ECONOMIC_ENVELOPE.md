# Freight Winch — economic envelope and packing semantics

`DIRECTOR_BRIEF.md` §3.9: *"Before graybox implementation, define an economic envelope... Packing semantics
are architectural invariants, not late polish."* This is that document, written before any graybox code,
per the brief's own explicit sequencing. Local-only (`docs/handoff/`, gitignored via `.git/info/exclude`).

**Status of the blockers this depended on:** Q1 (which sink) is answered — Option A + Option B's relocatable
geometry, "the first Freight Winch retires repeated upward cargo hauling from a deep active face, using a
relocatable trunk and receiver." The one requested pre-implementation measurement (lateral vs. vertical trip
cost) is answered — see `Q1_FREIGHT_WINCH_PAIN_OPTIONS.md` and `OVERNIGHT_RUN_STATE.md`'s matching entry: an
8-column lateral branch's walking-only lower bound (174 frames, five seeds) already lands inside the
existing vertical climb-cost reference range (114-232), which is part of why this document treats the
lateral walk as staying manual (per the Q1 ruling) while only the vertical return is retired.

**Method.** Every number or rule below is graded by where it comes from:
- **PRECEDENT** — already established by an existing, working game mechanic; proposed as-is for consistency,
  not invented.
- **PROPOSAL** — grounded in measured evidence from this session, but a real design choice; a reasonable
  default to implement, reversible, flagged so it isn't silently treated as decided.
- **OPEN** — genuinely undecided, needs either a director ruling or human playtesting (T0.1) before a number
  can be trusted; graybox implementation should not block on these, but should not paper over them either.
- **ENGINEERING GAP** — no existing precedent in this codebase; the first real architectural decision the
  graybox build will have to make, named here so it isn't discovered mid-implementation.

## What already exists and constrains every answer below

- **The conservation invariant is locked, not a design choice.** Every existing removal path in
  `factory_sim.gd` either credits `total_consumed` or moves items to the pack/floor — `pickup_machine`
  salvages buffer contents before removing (`factory_sim.gd:1671-1696`), `remove_machine` credits whatever
  a raw removal discards (`:1809-1822`), mining and building both go through the same pack-cap-aware
  `take_into_pack`/`_take_from_pack`. Nothing in this codebase silently destroys items, and the Winch's
  packing semantics must not be the first exception.
- **`pickup_machine` is the load-bearing precedent for every other machine in the game today**: picking one
  up is **free** (no material cost), **instant** (no delay), refunds **100%** of the machine item, salvages
  buffer contents (spilling to the floor via `take_into_pack`'s cap handling if the pack is full), and does
  **not** preserve fuel or in-progress work — `remove_machine`'s own comment: *"Fuel and progress are not
  items, so they are not credited."*
- **`PACK_BULK_CAP = 90`** is the established player-carry ceiling (T1.0's own evidence). Any salvage/spill
  path answers to this same cap, not a new one.
- **No existing machine spans more than one cell or references another machine by position.** Belts, pipes,
  and multi-endpoint routing have no precedent anywhere in `src/core/`. The Winch's head-to-station route is
  genuinely new architecture — see the ENGINEERING GAP section below, not glossed over here.

## Economic envelope

### 1. Deposit life / useful trips before depletion — PROPOSAL

Grounded in this session's own measurements rather than picked freehand: `trip_frames` (`aa7f8ad`) showed
climb share growing 58%→73% of a capped (90-unit) trip and roughly doubling by the third trip on a 24-deep
face; the lateral measurement above shows even a modest 8-column branch already costs a comparable order of
magnitude to that climb. **Propose:** a source is "Winch-worthy" once it holds enough remaining yield to
demand more than ~3 manual round trips at the current pack cap — the point where, on the existing evidence,
per-trip pain is already compounding rather than flat. This is a proposal to implement and watch, not a
locked constant; a human playtest (T0.1) is the right instrument to confirm it feels right, not a harness
assertion.

### 2. Pack/rebuild cost — PRECEDENT

Follow `pickup_machine` exactly: free, instant, full refund of the Winch head item. No new tax invented.
Justification is direct, not inferred: §3.4 states *"Winch heads and stations must be packable, reproducible,
extendable, or cheap enough to abandon,"* and every other machine in the game already answers that with
free relocation. Deviating here would be the unmotivated exception, not the consistent choice.

### 3. Cable recovery — PROPOSAL, resolved together with the route-reference gap below

No existing item type represents "cable" today. Two shapes are available:
- **(a) Cable as a placed, per-cell world object** (like a wall or a wire), picked up cell-by-cell.
- **(b) Cable as an abstract route property** — its "length" is just the distance between two installed
  endpoints, with nothing placed in the cells between them.

**Propose (b).** It needs no new inventory item, no new per-cell placement/removal code path, and "recovering
the cable" on pack-up is then simply: the length becomes available again the moment the endpoint is picked
up, because nothing was ever spent as a countable resource in the first place — consistent with §3.4's "cheap
enough to abandon." (a) would need a new placeable, a new pickup path, and a new inventory item for a
single-purpose object nothing else in the game has a precedent for. This is an implementation-detail choice,
not a vision-level one — it does not change what the player sees or does, only how the route is represented
internally.

### 4. Loaded-cargo recovery — PRECEDENT (the conservation invariant is not optional here)

Whatever the skip or a station buffer is holding at pack time salvages into the pack, spilling to the floor
if it would exceed `PACK_BULK_CAP` — the exact path `pickup_machine` already uses for every other machine's
buffers. This is not a design choice available for this document to make differently; it is the
architecture's own locked rule, restated so a future implementer does not treat it as optional.

### 5. Recommissioning time — PROPOSAL, default to instant

Placing a Winch head or station from the pack should cost no more time than `build_from_pack` already costs
any other machine: none. §3.7 asks for *"a strong startup and catch sequence"* but that is about how
*running* reads once commissioned — the drum spinning up, the first skip catching the cable — not an
artificial delay gating a relocated machine back into service. Inventing a wait timer here would edge toward
§3.8's anti-goal, *"an always-hungry chore that recalls the player every minute,"* for no benefit named
anywhere in the brief. Flagged OPEN only in the sense that a human playtest could reveal a startup delay
*feels* better for hero-machine weight — not proposed here without evidence.

### 6. What survives abandonment — PRECEDENT

The machine item, its cable (per §3 above, implicitly — nothing was ever spent), and any cargo in transit:
all recoverable, per the conservation invariant. What does not survive: accumulated fuel or in-progress
work state, matching `remove_machine`'s own explicit rule for every other machine. No new exception invented.

## Packing semantics (the architectural invariants §3.9 asks to fix before a persistence model)

1. **A loaded skip on pack-up** — salvages into the pack, spill-safe, per `pickup_machine`'s existing path.
2. **Station buffers** — same salvage rule, per endpoint, since each is presumably its own machine instance
   in the existing sense (`MachineState` with `input_buffer`/`output_buffer`).
3. **Extended cable** — not a separate recovery step; see Proposal 3 above (route property, not an object).
4. **Operating power/fuel — PROPOSAL.** Draw from the existing power grid (`power_at`/`power_throttle`,
   `src/core/factory_sim.gd:1959-1967`, `power_flow.gd`) like other powered machines, not a separate
   fuel item. Precedent from this session's own Q1 research (`Q1_FREIGHT_WINCH_PAIN_OPTIONS.md`, Option D):
   generators already burn coal and the deep drill is deliberately self-sustaining specifically to avoid a
   fuel-hauling chore — the Winch should not reintroduce that chore by needing hand-fed fuel, which would
   also read as a second instance of §3.8's "always-hungry chore" anti-goal.
5. **Route references — ENGINEERING GAP, narrowed but not resolved here.** No existing machine references
   another by position; `MachineState`'s save schema (`save_game.gd:74-82`) is flat per machine — def, cell,
   buffers, progress, `route_toggle`, fuel, `power_factor`, `fed`, `facing`, `mode`, `filter` — none of which
   is a reference to another cell. Two shapes are available, and the existing save format already favors one
   of them: **(a)** add a `linked_cell: Vector2i` field to `MachineState` itself, touching every machine's
   save schema for one machine type's needs, or **(b)** a separate top-level save key, e.g. `winch_routes:
   {head_cell: station_cell}`, following the exact pattern `conduit`/`rope`/`torch` already use — each its
   own flat dictionary alongside `machines` in the save envelope (`save_game.gd:96-101`), not folded into
   `MachineState`. **(b) matches the existing convention more closely** and avoids widening every machine's
   schema for a property only one machine type has. Still not fully resolved here — what happens on load if
   one endpoint references a cell that no longer holds the expected machine (picked up independently, or a
   corrupted save) needs an explicit answer before this is implementation-ready, matching the existing
   save-loader's own "refuse rather than silently misload" discipline (`save_game.gd:110+`'s presence-loop
   comment). Named as the first real decision graybox work should make, not an afterthought.
6. **A player grappled to the mechanism at pack time — OPEN, needs a quick precedent-check before
   implementation.** §3.9 item 4 requires the player be able to grapple with or around the *moving*
   mechanism, which is a different question from what happens if the *machine itself* is picked up while
   something is actively interacting with it (e.g., an in-progress feed, or a grapple anchored to a cell the
   machine occupied). Not answered here — the right first step is checking whether any existing verb already
   handles "the thing the player is interacting with just left the world" (e.g. what `try_drop`/feeding does
   if its target machine is picked up mid-animation), and following that precedent rather than inventing a
   new one.

## What this document is not

Not a full mechanical spec (skip capacity number, cable length limit, drum/brake visual states) and not a
graybox implementation plan. It is exactly what §3.9 asked for before either: the economic envelope and the
packing invariants, graded by where each answer actually comes from. The next step, if this reads sound, is
either a director pass on the OPEN items above, or — if none of them are treated as blocking — a graybox
implementation plan scoped against `DIRECTOR_BRIEF.md` §3.9's seven-item prototype slice directly.
