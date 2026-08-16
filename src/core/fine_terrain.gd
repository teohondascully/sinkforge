extends RefCounted

## THE FINE-TERRAIN MOLDING (the dual-grid Noita overhaul) — the deterministic fine-grid BUILD, extracted
## from FactorySim so the sim's core isn't carrying ~90 lines of noise-molding. Pure derived-data logic,
## no state of its own: it fills the sim's `_fine_solid` byte array from the coarse `solid` grid + seeded
## fine worldgen. FactorySim still owns the fine STATE (_fine_solid / _fine_edge / _fine_grit /
## _fine_seed_built) and the public accessors (fine_w / fine_h / fine_is_solid / rebuild_fine_terrain).
## Deterministic in (world_seed, coords) ONLY — no time, no RNG — so two loads of a world mold identically;
## the fine grid is never saved (it derives from `solid` + seed).

## Rebuild the ENTIRE fine terrain array from the coarse `solid` grid + deterministic fine worldgen.
## Called after load_world / save-restore (the fine grid is not saved — it derives from `solid` + seed).
## Deterministic in (world_seed, coords) ONLY (no time, no RNG), so two loads of the same world produce
## an identical fine array. O(fine cells) — full rebuild; incremental edits use sync_block instead.
static func rebuild(sim: FactorySim) -> void:
	_ensure_noise(sim)
	var fw: int = sim.fine_w()
	var fh: int = sim.fine_h()
	if sim._fine_solid.size() != fw * fh:
		sim._fine_solid.resize(fw * fh)
	for fy: int in fh:
		for fx: int in fw:
			sim._fine_solid[fy * fw + fx] = 1 if _cell_solid(sim, fx, fy) else 0


## Re-mold ONE coarse cell's SUBDIV×SUBDIV fine block PLUS the one-cell boundary band around it (its
## edge molding reads the coarse neighbours, so a dig must re-mold the neighbours' rims to stay organic).
## O(local): (SUBDIV+2)² fine cells per edit — the cheap incremental path used on mine/place/bore/fell.
static func sync_block(sim: FactorySim, coarse: Vector2i) -> void:
	_ensure_noise(sim)
	var fw: int = sim.fine_w()
	var fh: int = sim.fine_h()
	if sim._fine_solid.size() != fw * fh:
		rebuild(sim)
		return
	# Cover this cell's SUBDIV block and one coarse cell of margin on every side (the boundary band).
	var fx0: int = maxi(0, (coarse.x - 1) * FactorySim.SUBDIV)
	var fy0: int = maxi(0, (coarse.y - 1) * FactorySim.SUBDIV)
	var fx1: int = mini(fw, (coarse.x + 2) * FactorySim.SUBDIV)
	var fy1: int = mini(fh, (coarse.y + 2) * FactorySim.SUBDIV)
	for fy: int in range(fy0, fy1):
		for fx: int in range(fx0, fx1):
			sim._fine_solid[fy * fw + fx] = 1 if _cell_solid(sim, fx, fy) else 0


## Decide whether a single fine cell is solid — the FINE WORLDGEN, deterministic in (world_seed, fx, fy).
## Base solidity = its parent coarse cell's solidity. In the INTERIOR (all coarse neighbours agree) it
## stays as-is — deep rock stays solid, open air stays open, so the hook's terrain is never punched. Only
## at a solid/air BOUNDARY does fine detail apply: a bilinear ramp of coarse solidity is perturbed by
## seeded edge noise (organic curves) then grit (crunch/protrusions near faces) and thresholded — so
## rock reads Noita-crunchy, not smooth, WITHOUT any change to the coarse authority.
static func _cell_solid(sim: FactorySim, fx: int, fy: int) -> bool:
	var pcx: int = fx / FactorySim.SUBDIV
	var pcy: int = fy / FactorySim.SUBDIV
	var parent: bool = sim.solid.has(Vector2i(pcx, pcy))
	# Is this fine cell in a boundary band? (any coarse neighbour differs from the parent) — only then mold.
	var boundary: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if sim.solid.has(Vector2i(pcx, pcy) + d) != parent:
			boundary = true
			break
	if not boundary:
		return parent    # deep interior / deep air — untouched, the base stays solid by construction
	# Bilinear solidness at the fine cell centre (coarse-cell units) → a smooth 0..1 ramp across the edge.
	var wx: float = (float(fx) + 0.5) / float(FactorySim.SUBDIV)
	var wy: float = (float(fy) + 0.5) / float(FactorySim.SUBDIV)
	var solidness: float = _bilinear(sim, wx, wy)
	# EDGE noise bends the boundary (organic erosion/accretion); a slight net-erode opens cave mouths.
	var band: float = 1.0 - absf(solidness - 0.5) * 2.0     # full swing at the 0.5 edge, 0 deep in either
	var edge: float = sim._fine_edge.get_noise_2d(float(fx), float(fy)) * FactorySim.FINE_EDGE_AMP - FactorySim.FINE_EROSION_BIAS
	solidness = clampf(solidness + edge * band, 0.0, 1.0)
	# GRIT: near a face the rock crumbles/protrudes — high-freq noise adds bite that fades toward interior,
	# so exposed rock gets little pits + nubs (crunch), deep rock stays whole.
	var grit: float = sim._fine_grit.get_noise_2d(float(fx), float(fy)) * FactorySim.FINE_GRIT_BITE * band
	solidness = clampf(solidness + grit, 0.0, 1.0)
	return solidness >= 0.5


## Bilinear sample of coarse solidity (0/1 per cell, out-of-bounds = 0/air) at a fractional coarse
## position — turns the hard solid/air step into the smooth ramp the fine noise then bends.
static func _bilinear(sim: FactorySim, wx: float, wy: float) -> float:
	var gx: float = wx - 0.5
	var gy: float = wy - 0.5
	var x0: int = int(floor(gx))
	var y0: int = int(floor(gy))
	var tx: float = gx - float(x0)
	var ty: float = gy - float(y0)
	var s00: float = 1.0 if sim.solid.has(Vector2i(x0, y0)) else 0.0
	var s10: float = 1.0 if sim.solid.has(Vector2i(x0 + 1, y0)) else 0.0
	var s01: float = 1.0 if sim.solid.has(Vector2i(x0, y0 + 1)) else 0.0
	var s11: float = 1.0 if sim.solid.has(Vector2i(x0 + 1, y0 + 1)) else 0.0
	return lerpf(lerpf(s00, s10, tx), lerpf(s01, s11, tx), ty)


## Build the fine-detail noise fields once, seeded off world_seed (deterministic; rebuilt if the seed
## changed under a reused sim, e.g. a title reroll → new load_world).
static func _ensure_noise(sim: FactorySim) -> void:
	if sim._fine_edge != null and sim._fine_seed_built == sim.world_seed:
		return
	sim._fine_seed_built = sim.world_seed
	# SINGLE OCTAVE, both fields. FastNoiseLite defaults to 5-octave FBM and each octave doubles the
	# frequency, so a field whose base frequency resolves on the fine grid still ships octaves that do
	# not — and an aliased octave mixed into a SHAPE field is not texture, it is the boundary flipping
	# in and out on every single cell. That is what printed a rock lip as a one-pixel dither.
	sim._fine_edge = FastNoiseLite.new()
	sim._fine_edge.seed = sim.world_seed ^ 0x1f83d9ab
	sim._fine_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	sim._fine_edge.fractal_type = FastNoiseLite.FRACTAL_NONE
	sim._fine_edge.frequency = FactorySim.FINE_EDGE_FREQ
	sim._fine_grit = FastNoiseLite.new()
	sim._fine_grit.seed = sim.world_seed ^ 0x5be0cd19
	sim._fine_grit.noise_type = FastNoiseLite.TYPE_VALUE       # blocky value noise = crisp per-fine-cell grit
	sim._fine_grit.fractal_type = FastNoiseLite.FRACTAL_NONE
	sim._fine_grit.frequency = FactorySim.FINE_GRIT_FREQ
