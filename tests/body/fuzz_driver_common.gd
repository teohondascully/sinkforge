class_name FuzzDriverCommon
extends RefCounted

## Shared by `tests/fixture_body_fuzz_probe.gd` (D0057, the standing goalless input fuzzer) and
## `tests/diag_resolve_floor.gd` (D0137, the resolve_floor diagnosis driver). Both `extends SceneTree`,
## both drive the same `HostileChamber` with the same undirected random input, and so both grew
## byte-identical `_spawn_body`/`_random_input` scaffolding -- caught as two exact clusters by
## `tools/quality_check/duplication.py`'s own blocking gate, exactly the way `DebugSceneCommon` was
## (`docs/DECISIONS_LEDGER.md` D0116). The second driver was modeled closely on the first, which is
## precisely the case that gate exists to catch, so this is real deduplication rather than a new
## exclusion.
##
## `diag_resolve_floor.gd`'s own header states it REPRODUCES `Heightfield`'s column-selection math
## rather than calling it, "so this file adds zero coupling". That intent is about the SUBJECT under
## diagnosis -- the floor-resolution math it exists to observe without perturbing -- not about harness
## setup, so sharing the spawn/input scaffolding here does not weaken it. Nothing in this file touches
## `Heightfield`, `VerticalResolve`, or any quantity either driver measures.

const CELL: int = Heightfield.TERRAIN_CELL_PX


## The chamber's standard fuzz spawn: two columns past `SPAWN_START`, horizontally centred within its
## own cell, resting on `FLOOR_ROW`.
static func spawn_body() -> Body:
	var col: int = HostileChamber.SPAWN_START + 2
	return Body.new(
		col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)


## One tick of fully-decorrelated random input -- uniform, not human-shaped; that contrast is deliberate
## (`docs/EXPERIENCE_EVALUATION.md`).
##
## `dig_pressed` is real input surface, and a fuzzer's whole reason to exist is exercising the input
## space undirected, not just the subset that existed when it was first written. `dig_disabled`
## overrides only the RESULT of the dig draw, never whether the draw HAPPENS -- disabling dig must not
## shift every later rng draw this tick by one, which would confound the dig-on/dig-off A/B with a
## second variable. Preserved verbatim from the original callers; the draw order below is load-bearing
## and any change to it invalidates every fuzz bound measured against it.
static func random_input(rng: SplitRng, dig_disabled: bool) -> InputFrame:
	var input: InputFrame = InputFrame.new()
	input.move_dir = rng.next_range(-1, 1)
	input.jump_pressed = rng.next_float() < 0.5
	input.jump_held = rng.next_float() < 0.5
	input.mantle_hold = rng.next_float() < 0.5
	var dig_roll: bool = rng.next_float() < 0.5
	input.dig_pressed = dig_roll and not dig_disabled
	return input
