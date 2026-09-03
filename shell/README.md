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

- `SaveGame` (`save_game.gd`, ADR 0010, D0352) — `capture(world, items, machines) → envelope` (v3, 22
  keys), `restore(world, items, machines, envelope) → bool` (staged then committed in place at the
  service level; `last_invalid` names a refusal), `write(path, envelope)` (tmp, readback, `.bak`, rename),
  `read(path)` (falls back to `.bak`; `last_read` is `NONE / OK / RECOVERED / CORRUPT`), `SLOT`.
  Also `settings.gd` (`Settings`) and `settings_bindings.gd`, here since before the save.

## Gotchas

- **A `--script` fixture may not write `SLOT`.** The harness has no isolated user directory yet, so the
  guard is by path; suites write scratch paths under `user://`. `SF_REAL_HOME=1` overrides.
- **Holders keep the services, never a plane.** `restore` swaps `World`'s four planes, `Items`' pack,
  piles and ledger, and the registry's contents; anything that cached `world.grid` is stale after a load.
- **Pre-pivot (v2) saves are refused by name**, not migrated (ADR 0010 §2, plan §8).
