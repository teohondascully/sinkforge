# ADR 0007: L2 exists, and it is a value-copying door with one envelope dimension

**Status:** accepted, 2026-08-30.

Required because this changes a layer boundary: `interface/` stops being a skeleton and starts being a
thing other layers may depend on, and `docs/adr/README.md` names layer boundaries as ADR-gated.

## Context

`docs/ARCHITECTURE.md` §5 specifies L2 as "the only door" into the sim, with exactly two operations
(`observe(envelope) -> Observation`, `apply(Command) -> Result`), a typed command vocabulary in
`sim/commands`, and observations filtered by a four-dimensional capability envelope. Both directories
have existed as `MODULE.md`-only skeletons since the layer plan was written. Nothing consumed them,
because nothing above L1 existed.

That changed with the presentation work. `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` §9 makes Slice 2 the
keystone for one blunt reason: **every lifted `view/` file needs a legal thing to read.**
`tools/layer_lint/layer_lint.py`'s own table gives `view` access to `interface` and `core` and nothing
else, so a renderer that reads `TileGrid` directly is a gate failure, not a style problem. The migration
is blocked on this door existing.

## Decision 1: an `Observation` is a copied value, and that is the whole design

`observe()` returns a flat `PackedByteArray` over one window plus a `PackedStringArray` legend. It holds
no reference to `TileGrid`, `Body`, or `Mining`.

The cheap alternative — hand back the grid and let the consumer index it — **silently deletes the
envelope**. A consumer holding a live `TileGrid` can read any cell it likes, fogged or not, and no
filter inside `interface.gd` can stop it; the envelope becomes a suggestion. `interface/MODULE.md`
already states the invariant ("every read goes through `observe(envelope)`, so the envelope's filtering
is never bypassable by reaching around it"), and a copy is what makes that sentence enforceable rather
than aspirational. `tests/test_interface.gd` tests it by actually attempting the reach-around: it
observes, excavates the grid, and asserts the observation still reports the old state.

The cost is real and accepted: a few KB per call for a screen-sized window, rebuilt per call. That is
paid in `view/`, per frame, in a language where the alternative is a design hole. If it ever measures as
a problem the answer is a dirty-region protocol on top of this contract, not a reference handed out
underneath it.

## Decision 2: one envelope dimension, because one has a mechanism

`Envelope` carries a `window: Rect2i` and nothing else. §5's other three dimensions — planning, motor,
priors — and vision's fog half are **absent, not stubbed**.

There is no fog in this build, no planner to bound, no motor-noise model and no priors table. A field
per dimension would be four entries in the type system that no code reads and no test can exercise: a
`vision: Vision.ORACLE` that never filters anything reads, to the next person, as a filter that has been
checked. `sim/commands/MODULE.md` already carries this project's own precedent in its gotcha — the
Freight Winch regrew as ad hoc verbs on the pre-pivot entry point because a vocabulary existed before
the thing it described. The same reasoning gives `Command` exactly two members (`MOVE`, `MINE`), one per
verb this build actually has.

`window` has no default and there is no "everything" envelope reachable by omission. `Envelope.oracle_over(grid)`
exists so the unfiltered case has to say its own name at the call site — the run that must never be
handed perfect information by accident is the constrained one measuring discoverability, and a defaulted
whole-world window is exactly how that accident happens.

## Decision 3: validation lives in `interface`, and rejections are named

`Mining.mine` already refuses an out-of-reach or non-solid target by doing nothing. `apply()` checks the
same three conditions anyway and returns `Result.rejected(REJECT_OUT_OF_REACH)` and friends.

That is not redundancy. §5 makes rejection reasons telemetry — "a command is submitted, validated, and
either applied or rejected with a reason. Rejection reasons are part of the telemetry" — and a silent
no-op is not telemetry. The distinction a discoverability run needs is between an agent that never tried
and one that tried and could not reach, and only a named rejection carries it. The reasons are
`StringName` constants, not prose, so a counter can be keyed on them.

## What this ADR does NOT decide

- **Migrating existing consumers.** `tests/body/reveal_scene.gd`, `play_scene.gd` and the harness drivers
  still drive `sim/` directly and are untouched. They are test scenes rather than `view/` files, so no
  gate requires them to move, and bundling that migration into the same change would have mixed a new
  contract with a rewrite of its first consumer.
- **The renderer.** `interface/` is not a coordinator: it owns no scene, draws nothing, and runs no loop.
- **Fog, or how a `Constrained` envelope will actually filter.** When there is a fog mechanism, it filters
  inside `_fill_window`. The window's existing "outside reads empty, and `in_window` tells you which"
  behaviour is the shape that will take.
- **Semantic actions.** §5 puts `goto`/`haul_to` in the harness, on top of raw. Still true, still unbuilt.

## Consequences

`view/` and `harness/` have something legal to read, which unblocks the presentation migration's
observation-dependent files. `sim/` gains one new leaf module (`sim/commands`) that every gameplay
submodule may match against without a cycle.

The reversibility that makes this safe to land in one pass: **nothing persists.** No save schema, no
golden, no fixture depends on the shape of an `Observation`, because every one is derived fresh and
thrown away. Changing its fields later costs a recompile of its consumers and nothing else — which is
precisely the property `docs/LEGACY_MIGRATION_MAP_2026-08-29.md` did not have when it budgeted Slice 2 at
3-5 sessions on the assumption that the keystone would be expensive to get wrong.
