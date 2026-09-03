# ADR 0010: The save is one versioned envelope over the planes, the item service and the registry, starting at v3

**Status:** accepted, 2026-09-03. Required because the save schema is an ADR-gated area
(`docs/QUALITY.md` gate 20). Written at the start of A′ step 3g (`docs/A_PRIME_REFACTOR_PLAN.md` §5.3),
before `shell/save_game.gd` existed. Ledger: D0352.

## Context

Legacy's `save_game.gd` (455 lines, v2) captured `FactorySim`'s dictionaries into one Dictionary, wrote
it with Godot's binary Variant serializer through a temp-and-backup protocol, and restored it
transactionally: stage everything, refuse on anything wrong, commit only a known-good envelope. All of
that is worth keeping. What changed underneath it is the world: terrain is a 4 px `TileGrid`, the
placed layers and machines are metre-cell planes (ADR 0009), water is per 4 px cell, the ledger is
`Items`, the machines are `Machines` with the winch's tables, and every float it saved is an integer
now. The current build cannot save at all, so no player holds a save of this game.

## Decision

1. **One envelope, version 3, in `shell/save_game.gd` (`SaveGame`).** The shell is the one layer that may
   reach everything (`shell/README.md`); the sim knows nothing of files. Top-level keys, 22:
   `version world_seed width height blocks walls dig_extent placed conduit_tiers sapling water deposits
   lode lode_max pack ground sink produced consumed machines winch_routes winch_transit`. Per machine,
   12: `def cell in out progress_ticks route_toggle fuel power_permille fed facing mode filter`. The
   caller adds the body (`player_pos` as two `Fx` ints and what else step 5 decides) when the interface
   owns it (step 4); `restore` ignores keys it does not know.
2. **v3 is this game's first version.** `OLDEST_READABLE = 3`. A legacy v2 envelope describes a
   metre-cell world with `solid`, `fill`, `research` and `seep_tick` — a different game's state, not an
   older encoding of this one — and is refused with the reason `pre-pivot save (v2): the world format
   changed`, the file left on disk. The plan's §5.3 asked for a v2→v3 migration against a stored fixture;
   that would be a world converter for saves nobody has. Deviation recorded for the director (D0352).
   The migration chain and the refuse-if-the-chain-stops guard are kept, empty, for v4.
3. **Required keys** (a save missing one is refused): `version world_seed width height blocks walls
   placed water deposits pack ground sink produced consumed machines`. **No-default keys** (legacy's
   rule: an absence whose default is a different specific value may not be defaulted): `world_seed
   width height`. **Additive keys** (absent in an older v3 → truthfully empty): `dig_extent
   conduit_tiers sapling lode lode_max winch_routes winch_transit`.
4. **Restore is staged then committed, in place at the service level.** `_stage` builds FRESH planes,
   a fresh pack, piles and registry from the envelope through each plane's own public mutators
   (`set_material`, `occupy`, `set_level`, `seed_lode`, `Pack.add`, `Machines.place`, …), so every running
   signature is right by construction and a machine on a cell that is not open refuses the whole save.
   `_commit` then swaps the staged planes into the caller's `World`, `Items` and `Machines`, which stay
   the same objects. Holders may keep the three services; nothing may cache a plane across a load.
   Derived state is reset: `power`, `flow_events`, `last_drop_landing`; the production-rate window is the
   caller's and starts empty (D0351).
5. **Order is state and is preserved.** The `machines` Array, the pack's insertion order (the hotbar), and
   every buffer's key order (the hopper latch) survive the round trip because `store_var` keeps
   Dictionary order and restore never sorts them. Machine cells in `placed` are NOT saved: `Machines.place`
   re-registers them, so the plane cannot disagree with the registry.
6. **Dangling winch routes reconcile after commit**, legacy's rule: a route whose end is not the machine
   it names is dropped; cargo in flight returns to a surviving Head's input buffer, or spills to the floor
   at the Head's last cell through `Items.eject`. Conservation is never broken by a load.
7. **Durability is legacy's, verbatim:** encode to `.tmp`, read it back and prove it is an envelope, copy
   the good primary to `.bak`, rename. `read()` falls back to `.bak` and reports `NONE / OK / RECOVERED /
   CORRUPT`. **Fixture guard:** the harness has no isolated user directory yet (`docs/QUALITY.md` §7's
   sentinel is unbuilt), so a `--script` fixture may write any path except the real slot `SLOT`, refused
   unless `SF_REAL_HOME=1`. Suites write scratch paths.
8. **Determinism is the verifier.** The suite captures, restores into fresh services, and asserts every
   signature equal and every rebuilt signature agreeing, then ticks both hubs and compares again.

## Consequences

- Adding a plane means adding a key, a stage branch and a test row; the transactional shape makes a
  forgotten key a refusal, not a partial world.
- The save reaches inside no module: every read is a public field or accessor (`TileGrid.dig_extents()`
  is new for this), every write a public mutator.
- A v2 fixture in `legacy/` proves the refusal, not a migration.

## Reverse cost

CHEAP: one file in `shell/`, one accessor, one suite. A v2 converter can be added later as a migration
branch if the director wants pre-pivot saves to open.
