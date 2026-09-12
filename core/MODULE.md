# core

## Purpose

Fixed-point arithmetic (i32, 16 fractional bits), a seeded splittable RNG (one stream per subsystem;
streams are serialized state, not wall-clock seeded), generational-index entity IDs, the seam/grain hash,
the state-signature mixer and the reach rule. Small, pure, fully unit-tested.

## Dependencies

None. This is the floor of the stack.

## Consumers

Every other layer: sim, interface, harness, experiment, view, shell.

## Invariants

- No engine imports (no Godot types, nodes, or singletons). No file IO.
- No wall clock — no `OS.get_ticks_*`, no `Time` singleton, nothing that reads real-world time on a state path.
- No global mutable state. RNG streams are values the caller owns and threads through explicitly, not statics.
- No `sin`/`cos`/`pow` (or any other transcendental/floating-point-only function) on a path that affects
  simulation state. Determinism across platforms depends on this module staying pure fixed-point integer math.

## Public API

- `SplitRng` (`split_rng.gd`) — seeded, splittable PRNG stream. SplitMix64. `.next_u64()`, `.split(label:
  String) -> SplitRng` (deterministic, keyed off the root seed not current draw position —
  order-independent), `.get_state()` / `.set_state()` for serialization. Naming the actual per-subsystem
  streams (`world`, `terrain_gen`, ...) is each sim/ module's job, not core's — it doesn't know sim/'s list.
- `EntityIdPool` (`entity_id_pool.gd`) — generational-index entity IDs, packed as one 64-bit int
  (`(generation << 32) | index`) so ids compare with plain `==` and serialize as one integer. `.allocate()`,
  `.release(id) -> bool` (false on double-release or a never-allocated id, never a crash), `.is_valid(id)`, `.live_count()`.
- `Ordering` (`ordering.gd`) — the one way to sort in `sim/`: `.ids(names)`/`.less(a, b)` by TEXT (`StringName <`
  is a pointer compare, so a bare `.sort()` is creation order — D0346) and `.cells(dict)`/`.cell_less(a, b)` row-major.
- `StateHash` (`state_hash.gd`) — the two-lane mixer every plane hashes with (from `TileGrid`, D0344; arithmetic
  unchanged from D0261, pinned in `tests/test_state_hash.gd`): `.fold()`, `.mix()`, `.term()`, `.text_term()`, `.id_fold()`.
- `SignedPlane` (`signed_plane.gd`, D0348) — the running-signature plane base: the two lanes, `_xor_term`, the
  `_write_int` sandwich, `_lanes`, `_rebuilt`, `_clone_into`; a subclass supplies `_term_of(key)`. `TileGrid` predates it.
- `BitOps` (`bit_ops.gd`) — bit-level integer primitives with no domain concept of their own.
  `.ushr(x: int, n: int) -> int`, a logical (zero-fill) right shift of a 64-bit bit pattern held in a
  signed GDScript int. Why it is its own file rather than a helper: see Gotchas.
- `Fx` (`fixed_point.gd`) — fixed-point scalar arithmetic, i32 with 16 fractional bits. World-scale
  constants and the range/precision check this format was validated against: `docs/ARCHITECTURE.md` §9
  ("The world scale"), `docs/adr/0003-fixed-point-representation.md`. `.from_int()`, `.to_float()`
  (debug/render only), `.add()`, `.sub()`, `.mul()`, `.div()` (returns 0 and logs an error on
  division by zero rather than raising — see Gotchas), `.lerp()`, `.isqrt()`, `.length_sq()`,
  `.length()`, and the vectors (D0358) `.normalize()`, `.dot()`, `.limit_length()` — `Vector2i` pairs of
  `Fx`, both divisions rounding toward LESS energy (ceiling root, truncated components), never arithmetic
  on the `Vector2i` itself. `length()`/`length_sq()` accumulate raw i64 since D0029 — safe for any pair
  of valid `Fx` deltas. `mul()` ITSELF still has the ~181-per-axis limit when used to square a value
  directly; that's a `mul()` property, not a `length()` one.
- `Seams` (`seams.gd`) — the rock's grain as a pure function of `(coordinate, world_seed)`. `.at()`,
  `.terrain_axis()`, `.aligned()`, `.grain()`. Moved from `sim/world/` so `view/` can reach `grain()` (D0237).
- `Reach` (`reach.gd`, D0521) — the one reach rule: `NUM/DEN` (16/5, 3.2 metres) and the squared, inclusive
  Euclidean compare over `Fx` points: `.in_reach()`, `.in_reach_metre()`, `.metre_centre_fx()`; the metre's px is
  a parameter (this module may not know `Body`'s tile). `Aim.in_reach_point` delegates here; `RingPainter` reads it.
- `Angle` (`angle.gd`, D0629) — the deterministic sine: a 256-entry milli table looked up by 1/65536-turn
  integer angles (`.sin_milli()`, `.units()`, `.round_milli()`), because `sin` is a libm call and no state
  path may make one. Hoisted from `Relief`, which still exposes the names as delegates.
- `BeddingDip` (`bedding_dip.gd`, D0629) — the bedding warp, in metres and cells: `.dip_milli_m(col, cpm)`,
  `.dip_cells(col, cpm)`. One function for the generator's layer contacts (`_fill_base`) and the view's
  tone (`BeddingTone.bedding_metres`), so a stratum's material boundary IS a bedding line.

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
- **GDScript's parser rejects `>>`/`<<` where the LEFT OPERAND is syntactically negative** — a literal,
  a negative const, or a unary-minus expression ("Invalid operands for bit shifting") — yet allows the
  same shift at runtime through a plain variable holding a negative value. Syntactic, not value-based:
  never write `(-x) >> n` directly; assign the negated value to a variable first, then shift it.
- **An unguarded runtime script error's effect on a bare `--headless --script` run depends on exactly
  where it happens, and the more common location is the more dangerous one, not the more obvious one
  (`docs/DECISIONS_LEDGER.md` D0115/D0116, correcting this note's original, narrower claim).** Directly
  inside `_initialize()` itself it HANGS — nothing after the error runs, the bare SceneTree idles
  forever, no exit code. But inside any function `_initialize()` CALLS (every real suite's `_test_*()`s,
  since `_initialize()` is a flat list of calls to them), it does neither: the expression logs a
  `SCRIPT ERROR:`, evaluates to a type-default value, and execution continues from the next line in the
  SAME function — the suite can finish normally, `ALL PASS` printed, exit 0, having silently lost that
  function's remaining `_check()`s. Arithmetic that could divide by a caller-supplied value must still
  guard explicitly (`push_error()` logs without triggering either mode; a raw `/` does not) — and for
  TEST suites, trusting a bare invocation's exit code or printed summary is not enough either way; use
  `tools/run_gd_test.sh` (D0116), which catches both.
- **GDScript hex literals cannot represent values ≥ 2^63.** A top-bit-set 64-bit constant (several of SplitMix64's) must be written as signed two's-complement decimal, computed externally (`python3 -c "print(x - (1<<64) if x >= (1<<63) else x)"`) — not hex.
- **`free` is reserved.** Every class inherits `Object.free()`; `EntityIdPool`'s release operation is
  `release()`, not `free()` — caught by a parse error, not a silent shadow, but worth knowing.
- **The script class cache does not rebuild for a bare `--headless --script` run.** A new or renamed
  `class_name` isn't visible until `godot --headless --path . --import` runs once — the usual cause of
  "Identifier not declared in the current scope" for a class you just wrote, not a real reference error.
