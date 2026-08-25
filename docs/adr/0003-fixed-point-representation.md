# ADR 0003: Fixed-point representation is i32 with 16 fractional bits

**Status:** accepted, 2026-08-26.

## Context

`docs/ARCHITECTURE.md` §4 and `core/MODULE.md` both stated "i32, 16 fractional bits" for all
state-affecting positions and velocities from the moment the module skeleton was written in Task 0, but
that number had never actually been checked against anything. Fixed-point bit depth touches every
position in the game and is expensive to change once `sim/body` and `sim/transport` are built against
it, so an autonomous session working `core/` (2026-08-26) was instructed to validate it rather than
implement on the existing spec's word alone — and found it couldn't: two facts the check depends on,
the world's pixels-per-meter scale and a maximum playable depth, weren't written down anywhere. The
session logged the gap (`docs/DECISIONS_LEDGER.md` D0004) and built nothing that depended on it.

## Decision

The missing constants are now stated, in `docs/ARCHITECTURE.md` §9 ("The world scale"):

- World scale: 16px = 1m (also the machine/logic cell size).
- Terrain/digging grid: 4px.
- Maximum playable depth: 4096px, i.e. 256m — a range budget for this decision, not a hard
  world-generation ceiling.

Against those: i32 with 16 fractional bits gives ±32,768px (±2,048m) of integer range and 1/65,536px of
precision. Range headroom is 8x the stated maximum depth (2,048m budgeted range against 256m maximum
depth). Precision is many orders finer than either resolution level that could actually consume it
(1px visual, 4px terrain grid). Neither number is close to binding.

i32 rather than i64 is independently motivated, not just a range choice: GDScript's native `int` is
64-bit, so i32 × i32 fixed-point multiplication always fits in a native 64-bit intermediate before
shifting back down to format. i64 × i64 would need 128-bit intermediates the runtime doesn't have,
which would make multiplication itself a harder problem than the range this ADR is otherwise about.

## Consequences

- `core/fixed_point.gd` implements exactly this format: values are raw GDScript `int`s holding an i32
  bit pattern (not GDScript's native 64-bit range) scaled by 65,536, with all arithmetic performed and
  masked as if the type were genuinely 32-bit, mirroring how `core/split_rng.gd` and
  `core/entity_id_pool.gd` already treat GDScript's 64-bit `int` as a holder for a narrower bit pattern.
- If the maximum playable depth budget ever needs to grow past roughly 2,048m, this ADR is the thing to
  revisit — not a silent reinterpretation of what "position" means elsewhere in the codebase.
- The world-scale constants (16px/m, 4px terrain grid) are now load-bearing beyond this one decision:
  anything that renders a "meters" readout, generates terrain, or reasons about machine placement should
  cite `docs/ARCHITECTURE.md` §9 rather than re-deriving or re-guessing the conversion.
- This does not resolve whether position uses a single global fixed-point coordinate or a chunked/
  relative scheme — the stated depth budget makes a single global coordinate sufficient, so the
  question doesn't need to be forced now, but a chunked scheme remains a legitimate later choice if the
  depth budget is ever revised upward enough to make it necessary again.
