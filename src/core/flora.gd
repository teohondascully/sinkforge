extends RefCounted

## Per-tick flora sweep: ages planted saplings into trees. Stateless, operating on the sim's
## `sapling` layer and terrain grids; FactorySim owns the state, the SAPLING_* constants and the
## public API. Deterministic (cell-hash trunk heights, no RNG) and conservation-safe: an uprooted
## seed is ledgered back into play.

## The growth sweep. Every sapling ages one tick. One built over is destroyed; one whose soil
## vanished drops as a ground item. At SAPLING_GROW_TICKS it sprouts a tree into cells still open.
static func grow(sim: FactorySim) -> void:
	if sim.sapling.is_empty():
		return
	var grown: Array[Vector2i] = []
	var dead: Array[Vector2i] = []
	var uprooted: Array[Vector2i] = []
	for cv: Variant in sim.sapling:
		var c: Vector2i = cv
		if sim.solid.has(c) or sim.grid.has(c):
			dead.append(c)                              # built over — crushed
		elif not FactorySim.SAPLING_SOILS.has(sim.solid.get(c + Vector2i(0, 1), &"")):
			uprooted.append(c)                          # soil mined out — the seed drops free
		else:
			sim.sapling[c] = int(sim.sapling[c]) + 1
			if int(sim.sapling[c]) >= FactorySim.SAPLING_GROW_TICKS:
				grown.append(c)
	for c: Vector2i in dead:
		sim.sapling.erase(c)
	for c: Vector2i in uprooted:
		sim.sapling.erase(c)
		var pile: Dictionary = sim.ground.get(c, {})
		pile[&"sapling"] = int(pile.get(&"sapling", 0)) + 1
		sim.ground[c] = pile
		sim.total_produced[&"sapling"] = int(sim.total_produced.get(&"sapling", 0)) + 1   # back in play → ledgered
	for c: Vector2i in grown:
		sim.sapling.erase(c)
		_stamp_tree(sim, c)


## Stamp a tree with its trunk base at `base`: a 2-3 tall &"wood" trunk (height from the cell hash,
## so deterministic) under the worldgen's rounded 3-wide &"leaves" canopy. Only open cells are
## stamped, so a roof or machine prunes the tree. Stamped cells are world matter and chop like any.
static func _stamp_tree(sim: FactorySim, base: Vector2i) -> void:
	var trunk: int = 2 + absi((int(base.x) * 40503) ^ int(base.y)) % 2
	for h: int in range(0, trunk):
		var t: Vector2i = base + Vector2i(0, -h)
		if sim.in_bounds(t) and not sim.solid.has(t) and not sim.grid.has(t) and not sim.rope.has(t) and not sim.torch.has(t):
			sim.solid[t] = &"wood"
			sim._dirty_terrain(t)
	var ttr: int = base.y - trunk + 1                   # row of the topmost trunk cell
	for leaf: Vector2i in [
			Vector2i(base.x, ttr - 1), Vector2i(base.x, ttr - 2),
			Vector2i(base.x - 1, ttr - 1), Vector2i(base.x + 1, ttr - 1),
			Vector2i(base.x - 1, ttr), Vector2i(base.x + 1, ttr)]:
		if sim.in_bounds(leaf) and not sim.solid.has(leaf) and not sim.grid.has(leaf) \
				and not sim.rope.has(leaf) and not sim.torch.has(leaf):
			sim.solid[leaf] = &"leaves"
			sim._dirty_terrain(leaf)
