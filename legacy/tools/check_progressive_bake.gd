extends "res://tools/check_base.gd"

## Harness layer: A PROGRESSIVE BAKE MUST END BYTE-IDENTICAL TO A SINGLE-SHOT ONE — and must actually be
## progressive, which is the half a correctness test alone would never notice.
##
## #17 splits the 262144-cell boot bake into "paint the visible rect now, owe the rest to `bake_pending`",
## because the whole thing costs 1199ms in front of the first frame and the profiling that went looking for
## a hotspot found there isn't one (bulk fine grid 11%, noise 16%, the remaining ~74% diffuse across
## `_paint_fine`). Splitting the work is the only thing left that does not change the output.
##
## THE CORRECTNESS ARGUMENT IS ALREADY STRONG, WHICH IS EXACTLY WHY IT IS TESTED. `_paint_fine` reads only
## caches that `rebake` fills completely before any painting begins, and writes only its own four bytes —
## so paint ORDER cannot affect the result and any partition of the grid yields the same image, by
## construction. Correct by construction is what the guards in this project that later turned out to prove
## nothing all had going for them. The argument justifies the design; it does not excuse the assertion.
##
## WHAT WOULD BREAK IT, so the assertions have something to be about: a paint term that read a neighbour's
## PAINTED BYTES rather than its solidity would become order-dependent overnight, and nothing else in this
## suite would see it — `check_dig_hitch` compares a region bake against a full one, and both of those
## paint their cells in one uninterrupted pass.
##
## NON-VACUITY, built in rather than argued. `got == want` between two bakes of the same world is a
## comparison that passes trivially if anything upstream quietly stopped varying, and it is the single most
## common way a guard in this project has died. So the layer holds a POSITIVE CONTROL: it compares a bake
## that is deliberately left UNDRAINED against the reference and requires that one to DIFFER. If the
## control ever stops failing, the comparison has stopped working and the whole layer says so, in the same
## run, without anyone re-reading it.
##   godot --headless --path . --script res://tools/check_progressive_bake.gd

const SCENE: String = "res://scenes/main.tscn"
const FINE_SEED: int = 1337                 ## must match WorldRenderer's FineTerrain.new(..., 1337)
## The view handed to the progressive bake. Deliberately NOT the renderer's own camera rect: this layer is
## about the SPLIT, and a fixture that reads the live camera would change what it tests every time someone
## moves the spawn point. A screen-ish rect in the middle of the world, in world pixels.
const VIEW := Rect2(600.0, 300.0, 1280.0, 720.0)
## The visible rect must be a small fraction of the grid, or the split has bought nothing. 47104 fine cells
## against 262144 is 18%; the bar is set at a third, which no plausible camera rect approaches and which a
## regression that quietly baked everything would blow through instantly.
const VIEW_SHARE_MAX: float = 0.33

var _main: MainView = null
var _frames: int = 0


func _initialize() -> void:
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	process_frame.connect(_on_frame)


## The renderer's exact palette / surface / wall authorities, so the only thing differing between the two
## bakes below is the PATH through the baker. Handed back as an Array because GDScript has no tuple and
## seven positional Callables at three call sites is how they drift apart.
func _authorities(r: WorldRenderer) -> Array:
	return [
		func(c: Vector2i) -> bool: return r.sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return r.sim.fine_is_solid(fx, fy),
		func(c: Vector2i) -> Color: return r._cell_base_color(c, r._material(r.sim.material_at(c))),
		r._wall_base_color,
		func(col: int) -> int: return r.sim.surface_row(col),
		r._cell_tone,
		r._has_wall,
	]


## `grammar_at` does NOT travel in the `rebake` signature, so a FineTerrain this fixture builds itself
## bakes every material as GRAM_CLASTIC unless it is set here. That did not make this layer's answer wrong
## — it compares two bakes of the SAME world and both sides were flattened identically, so
## order-independence still held for the right reason — but it made the POPULATION narrow, and narrow in
## exactly the wrong place: this layer's own header says it exists to catch "a paint term that read a
## neighbour's PAINTED BYTES rather than its solidity", and the grammar terms are the newest paint terms
## in `_paint_fine`. They were the only ones it never exercised. (Checked at the time: they read noise
## fields and the `_mat_gram` / `_accreted_gram` caches, never a painted byte, so the gap was theoretical.
## One line makes it permanent.) Found by auditing every `rebake` call site after `check_texture`
## turned out to have the same omission with a live regression behind it.
func _bake(fine: FineTerrain, a: Array, bulk: PackedByteArray, view: Rect2) -> void:
	if not fine.grammar_at.is_valid():
		var rr: WorldRenderer = _main._renderer
		fine.grammar_at = func(c: Vector2i) -> int: return rr._material(rr.sim.material_at(c)).grammar
	fine.rebake(a[0], a[1], a[2], a[3], a[4], a[5], a[6], bulk, view)


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	process_frame.disconnect(_on_frame)
	var r: WorldRenderer = _main._renderer
	var a: Array = _authorities(r)
	var bulk: PackedByteArray = r.sim.fine_solid_bytes()
	var whole: int = FactorySim.GRID_COLS * FactorySim.SUBDIV * FactorySim.GRID_ROWS * FactorySim.SUBDIV

	# THE REFERENCE: one uninterrupted bake of the whole grid, the path every caller took before #17.
	var ref := FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, FINE_SEED)
	var full_t0: int = Time.get_ticks_usec()
	_bake(ref, a, bulk, Rect2())
	var full_us: int = Time.get_ticks_usec() - full_t0
	var want: PackedByteArray = ref.baked_bytes()
	_check(ref.pending_rows() == 0, "a bake with no view owes nothing — the old path is untouched")
	_check(ref.last_baked_cells == whole, "the reference bake painted the whole grid (%d cells)" % whole)
	# The bytes must VARY. Everything below compares this array to another one, and two uniform buffers
	# compare equal — which is precisely how one byte-identity assertion in this project passed for its
	# whole life against two blank headless textures.
	_check(want.size() == whole * 4, "the reference produced a full-size buffer (%d bytes)" % want.size())
	var spread: int = _distinct(want)
	_check(spread > 8, "the reference image has real content: %d distinct sampled bytes" % spread)

	# THE PROGRESSIVE BAKE, stage one: the visible rect and nothing else.
	var prog := FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, FINE_SEED)
	var t0: int = Time.get_ticks_usec()
	_bake(prog, a, bulk, VIEW)
	var open_us: int = Time.get_ticks_usec() - t0
	var opening: int = prog.opening_baked_cells
	var share: float = float(opening) / float(whole)
	print("  opening bake painted %d of %d fine cells (%.1f%% of the grid); %d rows still owed"
		% [opening, whole, share * 100.0, prog.pending_rows()])
	# THE NUMBER THIS ITEM EXISTS FOR, measured rather than inferred, both bakes on the same machine in the
	# same process moments apart — so the ratio is a property of the code and not of the box (the argument
	# check_dig_hitch's cost gate is built on). PRINTED, not asserted: a millisecond count on arbitrary
	# hardware is exactly the threshold this project keeps having to delete.
	print("  what the first frame now waits for: %.1fms instead of %.1fms (%.2fx), at %.2f and %.2f us/cell"
		% [float(open_us) / 1000.0, float(full_us) / 1000.0, float(full_us) / maxf(float(open_us), 1.0),
			float(open_us) / float(maxi(opening, 1)), float(full_us) / float(whole)])
	_check(opening > 0, "the opening bake painted something")
	_check(share < VIEW_SHARE_MAX, "the opening bake is a small fraction of the grid (%.1f%% < %.0f%%)"
		% [share * 100.0, VIEW_SHARE_MAX * 100.0])
	_check(prog.pending_rows() > 0, "and it owes the rest (%d rows)" % prog.pending_rows())

	# THE POSITIVE CONTROL. An undrained bake MUST differ from the reference. If this ever passes, the
	# comparison below has stopped being able to fail and every green it prints is worthless.
	var partial: PackedByteArray = prog.baked_bytes()
	_check(partial != want, "CONTROL: an UNDRAINED progressive bake differs from the reference — so the"
		+ " byte comparison below is capable of failing")

	# The visible rect itself must be FINISHED, not merely started: this is the entire user-visible promise
	# of #17, and it is the one thing a "drain it and compare" test cannot see.
	_check(_rect_matches(partial, want, VIEW), "every fine cell inside the view is already correct in the"
		+ " opening bake — what the player is looking at did not wait")

	# Stage two: drain it. A real budget first, so the paced path is the one under test rather than a
	# one-shot fallback, then the remainder in one go.
	var slices: int = 0
	while prog.bake_pending(4000):
		slices += 1
		if slices > whole:
			break
	print("  drained in %d budgeted slices" % slices)
	_check(slices > 4, "the fill really was PACED across many calls, not done in one (%d slices)" % slices)
	_check(prog.pending_rows() == 0, "the fill finished — nothing outstanding")
	_check(prog.baked_bytes() == want,
		"a progressive bake ends BYTE-IDENTICAL to a single-shot bake of the same world")

	# And a rebake over a progressive one must reset it rather than inheriting stale pending state.
	_bake(prog, a, bulk, Rect2())
	_check(prog.pending_rows() == 0 and prog.baked_bytes() == want,
		"re-baking a progressive grid with no view repaints it whole and clears what it owed")

	_verdict("check_progressive_bake", "the visible rect is painted first and the finished grid is identical")


## Distinct byte values over a strided sample — cheap evidence that a buffer holds an image rather than a
## constant. Strided rather than exhaustive: 262144 cells is a million bytes and the question is only
## "does this vary at all".
func _distinct(buf: PackedByteArray) -> int:
	var seen: Dictionary = {}
	var step: int = maxi(buf.size() / 4096, 1)
	var i: int = 0
	while i < buf.size():
		seen[buf[i]] = true
		i += step
	return seen.size()


## Do two buffers agree over every fine cell inside a world-space rect? The rect is converted the same way
## FineTerrain converts it — deliberately duplicated rather than shared, because a test that borrows the
## implementation's own arithmetic cannot catch that arithmetic being wrong.
func _rect_matches(got: PackedByteArray, want: PackedByteArray, view: Rect2) -> bool:
	var fcols: int = FactorySim.GRID_COLS * FactorySim.SUBDIV
	var frows: int = FactorySim.GRID_ROWS * FactorySim.SUBDIV
	var fine_px: int = FineTerrain.FINE
	var x0: int = clampi(int(floor(view.position.x / float(fine_px))), 0, fcols)
	var y0: int = clampi(int(floor(view.position.y / float(fine_px))), 0, frows)
	var x1: int = clampi(int(ceil(view.end.x / float(fine_px))), 0, fcols)
	var y1: int = clampi(int(ceil(view.end.y / float(fine_px))), 0, frows)
	for fy: int in range(y0, y1):
		for fx: int in range(x0, x1):
			var i4: int = (fy * fcols + fx) * 4
			for b: int in 4:
				if got[i4 + b] != want[i4 + b]:
					return false
	return true
