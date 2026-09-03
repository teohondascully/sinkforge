class_name DepositPlane
extends SignedPlane

## Ore yield per terrain cell, and the lode behind the wall. Lifted in A' step 3c (D0348) from the
## `deposits`, `lode` and `lode_max` dictionaries `legacy/src/core/factory_sim.gd` kept on the hub
## (:197-215) and their reads (`ore_deposit_at` 1481, `deposit_material_at`, `lode_at` 1509,
## `lode_workable`, `lode_fraction` 1553). A plane of `World` beside terrain, water and the placed layers
## (ADR 0009). Every key is a `terrain_cell`: legacy's cell was the metre; ore here is where the 4 px
## grid puts it, and "a cell's yield" is that cell's.
##
## `deposits` is ONE grid shared by solid ore blocks and the background lode, so a caller takes the AMOUNT
## and the IDENTITY from this pair (`ore_deposit_at`, `deposit_material_at`) and never the identity from
## the block material: for a buried vein the block in front is stone. `lode_fraction` was a float for the
## renderer; it is per-mille here ("a float in an observation is a float in a replay", plan step 4).
##
## The hand verb `take_lode` (the pack, the ledger, the cap) is `Items.take_lode`; this plane's
## primitive is `take_one`, which decrements and retires a worked-out vein.

## An ore cell with no explicit seed reads this. Legacy's `DEFAULT_ORE_DEPOSIT` was 250 PER METRE CELL;
## this plane is keyed on the 4 px cell, sixteen to the metre, and it is quantities per METRE the economy
## is balanced on (2 ore to an ingot, a 3-6 burst per hand strike, a drill at one unit a cycle), so the
## per-cell default is 250 / 16 rounded to 16: a metre of unseeded ore holds 256, 2.4% over legacy's 250,
## and a drill bores a metre in the same number of cycles it did (D0349, correcting D0348's 250).
const DEFAULT_ORE_DEPOSIT: int = 16

var deposits: Dictionary = {}  # terrain_cell -> units left
var lode: Dictionary = {}      # terrain_cell -> ore material behind the wall
var lode_max: Dictionary = {}  # terrain_cell -> units the lode held when opened (the fraction's denominator)


## Remaining drill-yield of the SOLID ore/fuel block at `terrain_cell`, or of the lode there, or 0.
func ore_deposit_at(grid: TileGrid, terrain_cell: Vector2i) -> int:
	if grid.is_solid(terrain_cell) and WorldMaterials.is_ore_like(grid.get_material(terrain_cell)):
		return int(deposits.get(terrain_cell, DEFAULT_ORE_DEPOSIT))
	if lode.has(terrain_cell):
		return int(deposits.get(terrain_cell, 0))
	return 0


## WHICH ore the yield at `terrain_cell` belongs to: `ore_deposit_at`'s companion, branch for branch.
func deposit_material_at(grid: TileGrid, terrain_cell: Vector2i) -> StringName:
	if grid.is_solid(terrain_cell) and WorldMaterials.is_ore_like(grid.get_material(terrain_cell)):
		return grid.get_material(terrain_cell)
	if lode.has(terrain_cell):
		return lode[terrain_cell]
	return &""


## The ore in the background at `terrain_cell`, or &"". A lode under a solid block still exists.
func lode_at(terrain_cell: Vector2i) -> StringName:
	return lode.get(terrain_cell, &"")


## Is there a lode here whose face is open? "There is ore here" and "it can be worked" differ.
func lode_workable(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return lode.has(terrain_cell) and not grid.is_solid(terrain_cell) and int(deposits.get(terrain_cell, 0)) > 0


## How much of a lode is left, per mille of what it held when opened -- the number the renderer thins
## the fleck field by. 0 where there is no lode.
func lode_permille(terrain_cell: Vector2i) -> int:
	if not lode.has(terrain_cell):
		return 0
	var full: int = maxi(1, int(lode_max.get(terrain_cell, deposits.get(terrain_cell, 1))))
	return clampi(int(deposits.get(terrain_cell, 0)) * 1000 / full, 0, 1000)


## Open a lode at a cell with `amount` units (worldgen and tests). Its richness IS its deposit.
func seed_lode(terrain_cell: Vector2i, material: StringName, amount: int) -> void:
	_write(terrain_cell, material, amount, amount)


## Seed the yield of a solid ore block (worldgen). No lode: the block is the ore.
func set_deposit(terrain_cell: Vector2i, amount: int) -> void:
	_write(terrain_cell, lode_at(terrain_cell), amount, int(lode_max.get(terrain_cell, 0)))


## Take ONE UNIT from an exposed lode -- the primitive under the hand verb. Returns the material taken,
## or &"" if nothing here was workable. A vein worked dry is retired: it stops drawing as one.
func take_one(grid: TileGrid, terrain_cell: Vector2i) -> StringName:
	if not lode_workable(grid, terrain_cell):
		return &""
	var item: StringName = lode[terrain_cell]
	var left: int = int(deposits.get(terrain_cell, 0)) - 1
	if left > 0:
		_write(terrain_cell, item, left, int(lode_max.get(terrain_cell, 0)))
	else:
		_write(terrain_cell, &"", 0, 0)
	return item


## Every cell with a lode, in scan order.
func lode_terrain_cells() -> Array[Vector2i]:
	return Ordering.cells(lode)


func state_signature() -> String:
	return _lanes("d")


func recomputed_signature() -> String:
	var seen: Dictionary = {}
	for c: Vector2i in deposits:
		seen[c] = true
	for c: Vector2i in lode:
		seen[c] = true
	return _rebuilt("d", seen.keys())


func clone() -> DepositPlane:
	var copy: DepositPlane = DepositPlane.new()
	_clone_into(copy, [&"deposits", &"lode", &"lode_max"])
	return copy


## THE ONE WRITE: all three dictionaries move together under the signature sandwich.
func _write(terrain_cell: Vector2i, material: StringName, amount: int, max_amount: int) -> void:
	_xor_term(_term_of(terrain_cell))
	if amount <= 0 and material.is_empty():
		deposits.erase(terrain_cell)
		lode.erase(terrain_cell)
		lode_max.erase(terrain_cell)
	else:
		if amount > 0:
			deposits[terrain_cell] = amount
		else:
			deposits.erase(terrain_cell)
		if material.is_empty():
			lode.erase(terrain_cell)
			lode_max.erase(terrain_cell)
		else:
			lode[terrain_cell] = material
			lode_max[terrain_cell] = max_amount
	_xor_term(_term_of(terrain_cell))


func _term_of(key: Variant) -> Vector2i:
	var terrain_cell: Vector2i = key
	if not deposits.has(terrain_cell) and not lode.has(terrain_cell):
		return Vector2i.ZERO
	var amount: int = int(deposits.get(terrain_cell, 0))
	var full: int = int(lode_max.get(terrain_cell, 0))
	return StateHash.term(terrain_cell.x, terrain_cell.y, StateHash.id_fold(lode_at(terrain_cell)), Vector2i(amount, full))
