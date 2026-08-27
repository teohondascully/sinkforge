# shell

## Purpose

Entry points, scene flow, save IO. The only layer allowed to depend on
everything else — that's the whole point of pulling it out as its own
layer: every other module in the stack has a narrow, enforced dependency
list, and the parts of the game that legitimately need to touch
everything (booting the game, moving between menus and gameplay, writing a
save file) live here instead of leaking that breadth into `sim`,
`interface`, `harness`, `experiment`, or `view`. What exactly "moving
between menus and gameplay" means is open, same as `sim/run`'s own shape
(`sim/run/MODULE.md`) — this used to name a specific `MetaIdle`/`RunActive`
flow; that structure is retired and nothing has replaced it yet.

## Dependencies

Everything: `core`, `sim`, `interface`, `harness`, `experiment`, `view`,
`data`.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
