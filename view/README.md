# view

## Purpose

Renderer. Hangs off L2 (`interface`) as a peer of agents (`harness`),
never above L1 (`sim`). Reads observations, emits commands, never calls a
sim mutator directly — a human playing through `view` and a bot playing
through `harness/bots` go through the identical `apply()`/`observe()` door.

Has exactly one narrow reverse channel: frame capture -> vision model, for
legibility claims only. This is the one place `view` is allowed to feed
data back toward the research layer, and it's scoped tightly (a captured
frame, not a state read) so it can't become a second way to read sim state
around the envelope filter.

## Dependencies

`interface`, `core`.

**And `data/`, in one narrow place, which this line did not previously admit.**
`visuals/material_look.gd` reads `BandsRecords` and `MaterialsRecords` to turn a
material id into a `Color`. `tools/layer_lint/layer_lint.py` does not police
`data/` (it is in `UNPOLICED`), so this edge is invisible to the gate rather
than permitted by it. It is content, not sim state -- a static palette table,
read cosmetically, with no route back to a mutator -- so it does not weaken the
envelope. Flagged for a ruling in `docs/NEEDS_DIRECTOR.md` P013 rather than
quietly adopted, because `docs/ARCHITECTURE.md` §3's table does not grant it.

## Must-not

- Call a sim mutator directly. All state changes go through
  `interface.apply()`.
- Read sim state directly. All reads go through `interface.observe()`.

## Public API

**The coordinator (Phase 1 of the rebuild, `docs/DECISIONS_LEDGER.md` D0240):**

- `WorldView` (`world_view.gd`) — calls `observe()`, builds one `Frame` per
  tick, hands it to painters, draws nothing itself. Constructed around an
  `Interface` its caller owns; holds no `TileGrid`. `.setup()`,
  `.add_painter()`, `.refresh()`, `.current_frame()`, `.view_world_rect()`.
- `Frame` (`frame.gd`) — what a painter is given and the only thing it may
  read: `obs`, `anim_time` (pinned), `view_world_rect`, `zoom`, `look`,
  `marks`. `docs/COORDINATOR_CONTRACT.md` §2.
- `PaintLayer` (`paint_layer.gd`) — one painter's own `CanvasItem`, so
  parallax is possible and a painter is testable without a coordinator.

**Lifted pieces, not yet wired to the coordinator:** `controls.gd`,
`audio/score.gd`, `fx/particles.gd`, `fx/light_layer.gd`,
`visuals/art.gd`, `visuals/material_look.gd`.

## Gotchas

- **A painter asks `obs.in_window(c)`, never `in_bounds`.** `in_window` asks
  "was I given this cell"; `in_bounds` asks "is this cell in the world".
  `material_at`/`wall_at` return `&""` outside the window rather than
  "unknown", so confusing them draws the viewport's edge as the world's edge.
- **`class_name` is path-independent, so `view/` can depend on a file in
  `tests/` and the layer lint will not say a word** — `tests` is in its
  `UNPOLICED` set and its class map is built from the policed tree only. That
  is why `material_look.gd` was physically moved here rather than just
  referenced (D0240). The gate cannot catch this one for you.
