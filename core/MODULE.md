# core

## Purpose

Fixed-point arithmetic (i32, 16 fractional bits), a seeded splittable RNG (one stream per subsystem;
streams are serialized state, not wall-clock seeded), generational-index entity IDs, the seam/grain hash
and the state-signature mixer. Small, pure, fully unit-tested. Every other layer in the stack (sim,
interface, harness, experiment, view, shell) depends on this one; this one depends on nothing.

## Dependencies

None. This is the floor of the stack.

## Consumers

Every other layer: sim, interface, harness, experiment, view, shell.

## Invariants

- No engine imports (no Godot types, nodes, or singletons).
- No file IO.
- No wall clock — no `OS.get_ticks_*`, no `Time` singleton, nothing that
  reads real-world time on any path that affects state.
- No global mutable state. RNG streams are values the caller owns and threads through explicitly, not statics.
- No `sin`/`cos`/`pow` (or any other transcendental/floating-point-only
  function) on a path that affects simulation state. Determinism across
  platforms depends on this module staying pure fixed-point integer math.

## Public API

- `SplitRng` (`split_rng.gd`) — seeded, splittable PRNG stream. SplitMix64. `.next_u64()`, `.split(label:
  String) -> SplitRng` (deterministic, keyed off the root seed not current draw position —
  order-independent), `.get_state()` / `.set_state()` for serialization. Naming the actual per-subsystem
  streams (`world`, `terrain_gen`, ...) is each sim/ module's job, not core's — it doesn't know sim/'s list.
- `EntityIdPool` (`entity_id_pool.gd`) — generational-index entity IDs, packed as one 64-bit int
  (`(generation << 32) | index`) so ids compare with plain `==` and serialize as one integer. `.allocate()`,
  `.release(id) -> bool` (false on double-release or a never-allocated id, never a crash), `.is_valid(id)`, `.live_count()`.
- `Ordering` (`ordering.gd`) — ids sorted by TEXT. `StringName <` is a pointer compare in Godot 4, so a bare
  `.sort()` over ids is creation order, a within-platform determinism breaker (D0346). `.ids(names)`, `.less(a, b)`.
- `StateHash` (`state_hash.gd`) — the two-lane running-signature mixer every sim plane hashes with (from
  `TileGrid`, A′ step 2, D0344; arithmetic unchanged from D0261, outputs pinned in `tests/test_state_hash.gd`).
  `.fold()`, `.mix()`, `.term(x, y, m: Vector2i, w: Vector2i)` (both lanes), `.text_term()`, `.id_fold()` (memoised).
- `BitOps` (`bit_ops.gd`) — bit-level integer primitives with no domain concept of their own.
  `.ushr(x: int, n: int) -> int`, a logical (zero-fill) right shift of a 64-bit bit pattern held in a
  signed GDScript int. Why it is its own file rather than a helper: see Gotchas.
- `Fx` (`fixed_point.gd`) — fixed-point scalar arithmetic, i32 with 16 fractional bits. World-scale
  constants and the range/precision check this format was validated against: `docs/ARCHITECTURE.md` §9
  ("The world scale"), `docs/adr/0003-fixed-point-representation.md`. `.from_int()`, `.to_float()`
  (debug/render only), `.add()`, `.sub()`, `.mul()`, `.div()` (returns 0 and logs an error on
  division by zero rather than raising — see Gotchas), `.lerp()`, `.isqrt()`, `.length_sq()`,
  `.length()`. `length()`/`length_sq()` were LOCAL-neighborhood-only (safe only to ~181px per axis)
  until D0029 (`docs/DECISIONS_LEDGER.md`) widened them to accumulate raw i64 rather than route through
  `mul()`'s i32 reduction — safe now for any pair of valid `Fx` deltas, with no reachable overflow
  boundary inside the range a valid `Fx` value can occupy. `mul()` ITSELF still has the ~181-per-axis
  limit when used to square a value directly; that's a `mul()` property, not a `length()` one.
- `Seams` (`seams.gd`) — the rock's grain as a pure function of `(coordinate, world_seed)`. `.at()`,
  `.terrain_axis()`, `.aligned()`, `.grain()`. Moved from `sim/world/` so `view/` can reach `grain()` (D0237).

## Gotchas

- **GDScript's `>>` is an arithmetic (sign-extending) shift, not logical.** `SplitRng` and
  `EntityIdPool` need a logical right shift to treat a 64-bit int as an unsigned bit pattern (SplitMix64's
  mixing steps; unpacking the generation field). **Both call `BitOps.ushr()` (`bit_ops.gd`)** — until
  2026-08-28 each defined its own identical private `_ushr()` static helper instead of sharing one file;
  `tools/quality_check/duplication.py`'s first run against this tree found the two copies byte-for-byte
  identical and this was extracted as a direct result (`docs/DECISIONS_LEDGER.md` D0097). Verified
  empirically against the pinned engine (4.6.2-stable), not assumed — see `tests/test_split_rng.gd` and
  `tests/test_entity_id_pool.gd`, both re-run and unchanged (ALL PASS) after the extraction. `Fx` doesn't
  need this helper: its rescale step (`mul`'s `>>`) wants arithmetic (sign-preserving) shift semantics,
  which is what GDScript already gives it for free.
- **GDScript's parser rejects `>>`/`<<` where the LEFT OPERAND is syntactically a negative literal, a
  negative const, or a direct unary-minus expression** ("Invalid operands for bit shifting. Only positive
  operands are supported") — but allows it fine at runtime through a plain variable that happens to hold
  a negative value, even one assigned from an identical expression one line earlier. This is a syntactic
  restriction, not a value-based one: never write `(-x) >> n` directly; assign the negated value to a
  variable first, then shift the variable.
- **An unguarded runtime script error's effect on a bare `--headless --script` run depends on exactly
  where it happens, and the more common location is the more dangerous one, not the more obvious one
  (`docs/DECISIONS_LEDGER.md` D0115/D0116, correcting this note's original, narrower claim).** Directly
  inside `_initialize()` itself, it HANGS — nothing after the error runs, the bare SceneTree idles forever
  with no further output, no exit code. But inside any function `_initialize()` CALLS (every real
  `test_base.gd` suite's own `_test_*()` functions, since `_initialize()` is always just a flat list of
  calls to them), it does neither: the crashing expression logs a `SCRIPT ERROR:` and evaluates to a
  type-default value, execution continues from the very next line in the SAME function, and the suite can
  finish normally — `_finish()` reached, `ALL PASS` printed, process exits 0 — having silently lost
  whatever that one function's remaining `_check()` calls would have reported. Any arithmetic in `core/`
  or `sim/` that could divide by a caller-supplied value must still guard it explicitly (`push_error()`
  logs without triggering either mode, a raw `/` does not) — but for TEST suites specifically, trusting a
  bare invocation's own exit code/printed summary is no longer enough either way; use
  `tools/run_gd_test.sh` (D0116), which catches both.
- **GDScript hex literals cannot represent values ≥ 2^63.** Any 64-bit constant with its top bit set
  (several of SplitMix64's) has to be written as its signed two's-complement decimal equivalent, computed
  externally — `python3 -c "print(x - (1<<64) if x >= (1<<63) else x)"` — not typed as hex.
- **`free` is reserved.** Every GDScript class inherits `Object.free()`. `EntityIdPool`'s release
  operation is named `release()`, not `free()`, to avoid the collision — caught by a parse error, not a
  silent shadow, but worth knowing before reaching for the obvious name again.
- **The global script class cache does not rebuild itself for a bare `--headless --script` run.** A
  freshly added or renamed `class_name` isn't visible until `godot --headless --path . --import` runs
  once. If a test suite reports "Identifier not declared in the current scope" for a class you just
  wrote, this is almost always why — not a real reference error.
