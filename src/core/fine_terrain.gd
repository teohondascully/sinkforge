extends RefCounted

## The deterministic fine-grid build of the dual-grid terrain. Stateless; fills the sim's `_fine_solid` byte
## array from the coarse `solid` grid plus seeded fine worldgen. Deterministic in (world_seed, coords) only,
## no time and no RNG, so two loads mold identically. Never saved; it derives from `solid` plus the seed.

## Rebuild the entire fine terrain array, after load_world and save-restore, since it is never saved.
## O(fine cells); incremental edits use sync_block.
static func rebuild(sim: FactorySim) -> void:
	_ensure_noise(sim)
	var fw: int = sim.fine_w()
	var fh: int = sim.fine_h()
	if sim._fine_solid.size() != fw * fh:
		sim._fine_solid.resize(fw * fh)
	for fy: int in fh:
		for fx: int in fw:
			sim._fine_solid[fy * fw + fx] = 1 if _cell_solid(sim, fx, fy) else 0


## Coarse cells of margin an edit re-molds around the edited cell. `_cell_solid` reads a cell's eight coarse
## neighbours to decide whether it is on a boundary, so changing one coarse cell changes the molded shape of
## the whole ring touching it, not just its own SUBDIV^2 block. The number is a contract: anything caching
## the fine grid must refresh at least this wide after an edit, or it keeps stale solidity. The renderer's
## per-dig fast lane (scenes/fine_terrain.gd rebake_region) reads it, and a narrower hardcoded window
## diverges from a full bake by a 16-texel smear.
const SYNC_BAND: int = 1

## Re-mold one coarse cell's SUBDIV x SUBDIV fine block plus SYNC_BAND cells around it, since edge molding
## reads the coarse neighbours. O(local): (SUBDIV*(1 + 2*SYNC_BAND))^2 fine cells per edit, 144 at today's
## constants. The incremental path used on mine/place/bore/fell.
static func sync_block(sim: FactorySim, coarse: Vector2i) -> void:
	_ensure_noise(sim)
	var fw: int = sim.fine_w()
	var fh: int = sim.fine_h()
	if sim._fine_solid.size() != fw * fh:
		rebuild(sim)
		return
	# Cover this cell's SUBDIV block and SYNC_BAND coarse cells of margin on every side.
	var fx0: int = maxi(0, (coarse.x - SYNC_BAND) * FactorySim.SUBDIV)
	var fy0: int = maxi(0, (coarse.y - SYNC_BAND) * FactorySim.SUBDIV)
	var fx1: int = mini(fw, (coarse.x + 1 + SYNC_BAND) * FactorySim.SUBDIV)
	var fy1: int = mini(fh, (coarse.y + 1 + SYNC_BAND) * FactorySim.SUBDIV)
	for fy: int in range(fy0, fy1):
		for fx: int in range(fx0, fx1):
			sim._fine_solid[fy * fw + fx] = 1 if _cell_solid(sim, fx, fy) else 0


## Decide whether one fine cell is solid: the fine worldgen, deterministic in (world_seed, fx, fy). Base
## solidity is the parent coarse cell's, and in the interior (all coarse neighbours agree) it stays as-is, so
## the gravity hook's terrain is never punched. Only at a solid/air boundary does detail apply: a bilinear
## ramp of coarse solidity perturbed by edge noise, then grit, then thresholded. Coarse stays the authority.
static func _cell_solid(sim: FactorySim, fx: int, fy: int) -> bool:
	var pcx: int = fx / FactorySim.SUBDIV
	var pcy: int = fy / FactorySim.SUBDIV
	var parent: bool = sim.solid.has(Vector2i(pcx, pcy))
	# In a boundary band (any coarse neighbour differs from the parent)? Only then does molding apply.
	var boundary: bool = false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if sim.solid.has(Vector2i(pcx, pcy) + d) != parent:
			boundary = true
			break
	if not boundary:
		return parent    # deep interior or deep air: molding is skipped and the base stands
	# Bilinear solidness at the fine cell centre (coarse-cell units) → a smooth 0..1 ramp across the edge.
	var wx: float = (float(fx) + 0.5) / float(FactorySim.SUBDIV)
	var wy: float = (float(fy) + 0.5) / float(FactorySim.SUBDIV)
	var solidness: float = _bilinear(sim, wx, wy)
	# Edge noise bends the boundary (organic erosion and accretion); a slight net-erode opens cave mouths.
	var band: float = 1.0 - absf(solidness - 0.5) * 2.0     # full swing at the 0.5 edge, 0 deep in either
	var edge: float = sim._fine_edge.get_noise_2d(float(fx), float(fy)) * FactorySim.FINE_EDGE_AMP - FactorySim.FINE_EROSION_BIAS
	solidness = clampf(solidness + edge * band, 0.0, 1.0)
	# Grit: high-frequency noise adds bite near a face and fades inward, so exposed rock gets pits and
	# nubs while deep rock stays whole.
	var grit: float = sim._fine_grit.get_noise_2d(float(fx), float(fy)) * FactorySim.FINE_GRIT_BITE * band
	solidness = clampf(solidness + grit, 0.0, 1.0)
	return solidness >= 0.5


## Bilinear sample of coarse solidity (0/1 per cell, out of bounds = 0/air) at a fractional coarse position.
## Turns the hard solid/air step into the ramp the fine noise then bends.
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


## Build the fine-detail noise fields once, seeded off world_seed. Rebuilt if the seed changed under a reused
## sim, e.g. a title reroll into a new load_world.
static func _ensure_noise(sim: FactorySim) -> void:
	if sim._fine_edge != null and sim._fine_seed_built == sim.world_seed:
		return
	sim._fine_seed_built = sim.world_seed
	# Single octave on both fields. FastNoiseLite defaults to 5-octave FBM and each octave doubles the
	# frequency, so a field resolving on the fine grid still ships octaves that do not. An aliased octave in
	# a shape field flips the boundary in and out per cell, printing a rock lip as a one-pixel dither.
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
