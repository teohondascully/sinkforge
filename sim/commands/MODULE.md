# sim/commands

## Purpose

The complete typed command vocabulary — the only way anything mutates the
sim. This is the L2 interface's `apply(Command) -> Result` target: commands
are typed values, submitted from outside `sim/` (via `interface`), and
validated/applied by the submodules they target.

## Must-not

- Contain logic. Commands are typed values (structs/enums with payloads),
  not behavior. Validation and application happen in `interface` and in
  each target submodule, not here.

## Dependencies

`core` only. Command payloads reference `core` primitives (fixed-point
values, generational entity IDs) but do not depend on `items`/`machines`/
etc. for their own types — this is what keeps `commands` a leaf module that
every gameplay submodule can be matched against without a cycle.

## Consumers

`interface`, primarily — this is literally its `apply(Command)` parameter
type. Sim-internal: every submodule with mutating behavior (`world`,
`body`, `items`, `machines`, `transport`, `run`, `meta`, ...) matches
against the command types it cares about to implement its own mutations.

## Tick phase

Not tick-phase code. Commands are consumed during the `input` phase (or,
for out-of-run actions, via `apply()` outside the fixed tick loop
entirely) — they aren't a phase's logic themselves, just the vocabulary
that phase acts on.

## Public API

`sim/commands/command.gd`, `class_name Command`. A tag plus a payload, no behaviour — named
constructors only, because a `Command.new()` with every payload defaulted would be a command with no
kind and there is no valid one. Nine members since A′ step 4b (D0357), one per verb the sim has:
`move(InputFrame)`, `mine(terrain_cell)`, `build(logic_cell)`, `drop()`, `collect()`,
`configure(logic_cell)`, `link_winch(logic_cell)`, `select(index)`, `clear_plan()`. Each is matched in
`Interface.apply`, which answers with a `Result` whose `detail` says what a verb did and whose `reason`
names why it did not (`nothing_to_do`, `selection_out_of_range`, the mine gates).

**A member arrives with its verb, never before it.** `docs/ARCHITECTURE.md` §5 wants a vocabulary
"small enough to read in one sitting"; the mine hold is deliberately NOT a member: it rides `MOVE`'s
`InputFrame`, whose aim cell and held button are already state-affecting input recorded per tick.

`MOVE` carries a whole `InputFrame` rather than decomposing into per-key commands: that is §5's "raw"
action level, a first-class member of the vocabulary rather than a legacy path. One command per
keypress would be the second, incompatible input format §5 names as the thing not to build.

## Gotchas

**Freight Winch / haul-mechanic work is gated on `sim/run` and this module having real
implementations, not just this skeleton.** The old codebase's Freight Winch regrew as ad hoc verbs on
the pre-pivot entry point once (5 commits, see `docs/WORKING.md`'s commit-audit note); the risk is a
haul-related command type getting added here before the typed command vocabulary and whatever session
concept it should route through actually exist. Director directive, 2026-08-26 — note that
`sim/run`'s own shape is itself open as of the 2026-08-27 reversal (`sim/run/MODULE.md`), which makes
this gate stricter, not looser: there is now no session lifecycle at all to route a haul command
through until that question resolves.
