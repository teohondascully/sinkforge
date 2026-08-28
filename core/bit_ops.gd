class_name BitOps
extends RefCounted

## Bit-level integer primitives with no domain concept of their own -- extracted 2026-08-28
## (`docs/DECISIONS_LEDGER.md` D0097) from `SplitRng`/`EntityIdPool`, which each defined an identical
## `_ushr()` static helper independently. `tools/quality_check/duplication.py`'s first real run against
## this tree found the two copies byte-for-byte identical; this file is that finding's fix, not a
## speculative refactor -- `core/MODULE.md`'s own Gotchas section had documented the duplication as a
## known, deliberate-sounding fact ("each defines its own... rather than sharing one file"), which this
## supersedes.


## Logical (zero-fill) right shift of a 64-bit bit pattern held in a signed GDScript int. `x >> n` in
## GDScript sign-extends for negative `x`; this does not. Verified empirically against the pinned engine
## (4.6.2-stable), not assumed from the language spec -- see `tests/test_split_rng.gd` and
## `tests/test_entity_id_pool.gd`, both of which exercise this indirectly through their own class's
## public API and both passed unchanged after this extraction.
static func ushr(x: int, n: int) -> int:
	if n <= 0:
		return x
	if n >= 64:
		return 0
	return (x >> n) & ((1 << (64 - n)) - 1)
