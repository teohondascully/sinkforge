class_name Richness
extends RefCounted
## The per-column richness field: legacy `layered_world_gen.gd` `_horizontal_field` (:265-283), the
## reason a world is richer away from spawn -- "a seeded low-frequency noise band mixed with a distance
## ramp, then mapped from [0,1] into [1-S, 1+S]" -- read there by the ore and coal scatters (their
## acceptance and their size) and by the lodes (their amount). Ported in A' step 8f (D0386) as integers
## in thousandths: 1000 is legacy's 1.0.
##
## Legacy sampled `FastNoiseLite` simplex along one row at `HORIZONTAL_FREQ`. Here the band is
## one-dimensional value noise: lattice points `1 / freq_per_m` metres apart, each a draw from the terrain
## stream's own `richness` split, smoothstepped between -- no libm and no float past the record's own
## numbers, which convert once. A site without the `richness` record reads 1000 in every column, and a
## consumer multiplying by exactly one is the consumer as it was.

const MILLI: int = 1000


## One multiplier per column, in thousandths.
static func field(site: Dictionary, width: int, spawn_col: int, seed: int, cells_per_m: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(width)
	if not site.has("richness"):
		out.fill(MILLI)
		return out
	var cfg: Dictionary = site["richness"]
	var rng: SplitRng = SplitRng.new(seed).split("terrain_gen").split("richness")
	# Cells between lattice points, in thousandths, and one point past the end for the last interpolation.
	var spacing: int = maxi(1, int(round(float(cells_per_m) * float(MILLI) / float(cfg["freq_per_m"]))))
	var lattice := PackedInt32Array()
	lattice.resize(width * MILLI / spacing + 2)
	for i: int in lattice.size():
		lattice[i] = rng.next_range(0, MILLI)
	var strength: int = int(round(float(cfg["strength"]) * float(MILLI)))
	var bias: int = int(round(float(cfg["frontier_bias"]) * float(MILLI)))
	# Farthest any column sits from spawn, so an edge column's ramp reaches about 1.
	var max_dist: int = maxi(1, maxi(spawn_col, width - 1 - spawn_col))
	for col: int in width:
		var pos: int = col * MILLI
		var i: int = pos / spacing
		var f: int = (pos % spacing) * MILLI / spacing
		var smooth: int = f * f / MILLI * (3 * MILLI - 2 * f) / MILLI
		var band: int = lattice[i] + (lattice[i + 1] - lattice[i]) * smooth / MILLI
		var ramp: int = absi(col - spawn_col) * MILLI / max_dist
		var mix: int = band + (ramp - band) * bias / MILLI              # lerp(band, ramp, bias)
		out[col] = MILLI + (2 * mix - MILLI) * strength / MILLI         # symmetric about 1000, bounded by S
	return out


## The field as legacy's float multiplier, for the two float consumers (the scatters' acceptance and size).
static func multiplier(field_permille: PackedInt32Array, col: int) -> float:
	return float(field_permille[col]) / float(MILLI)
