class_name Pack
extends SignedPlane

## The player's pack: what is carried, and the BULK CAP that makes hauling a repeated job instead of one
## trip. Lifted in A' step 3c (D0348) from `legacy/src/core/factory_sim.gd` -- the `inventory` dictionary
## (:219), `inventory_slots` 1564, `_take_from_pack` 1786, `is_bulk_item` 1809, `carried_bulk`/`pack_room`/
## `can_carry` 1822-1849 -- with the two numbers legacy kept as `const` read from `data/player/pack.yaml`
## (`PlayerRecords`) instead. The verbs that fill and spill it (`take_into_pack`, `collect_ground`,
## `drop_item`) are `Items`; this is the container and the cap's arithmetic.
##
## THE CAP TAXES FREIGHT, NOT THE KIT. Ore, rock and refined goods are bulk; a placeable machine item is
## not. Legacy derived "machine item" from `ResourceLoader.exists(...tres)` inside the sim (plan §5.1 row
## 023, an engine-IO call on the state path); `MachineDef.exists` is the same question over the records
## table. Legacy also exempted tools and bits; that table is dead (GDD §9), so nothing else is exempt.
##
## INSERTION ORDER IS STATE HERE, on purpose: the hotbar draws stacks in the order they were first
## picked up, and a save preserves it. `slots()` walks that order for the view; anything state-affecting
## walks `ids()`, which is text order (`Ordering`, D0346).

var items: Dictionary = {}   # item id: StringName -> count (insertion-ordered, see above)
static var _bulk_class: Dictionary = {}  # memo of `is_bulk_item`: a pure function of the records


static func inventory_slots() -> int:
	return int(PlayerRecords.RECORDS["pack"]["inventory_slots"])


static func bulk_cap() -> int:
	return int(PlayerRecords.RECORDS["pack"]["bulk_cap"])


func count(item: StringName) -> int:
	return int(items.get(item, 0))


func is_empty() -> bool:
	return items.is_empty()


## Put `n` of `item` in, uncapped. The cap is the caller's question (`can_carry`, `take_into_pack`).
func add(item: StringName, n: int) -> void:
	if n <= 0:
		return
	_store(item, count(item) + n)


## Take up to `n` of `item` out; returns how many came out. A stack drained to 0 leaves the pack, so
## the hotbar never shows an empty slot (legacy `_take_from_pack`).
func remove(item: StringName, n: int) -> int:
	var removed: int = mini(n, count(item))
	if removed <= 0:
		return 0
	_store(item, count(item) - removed)
	return removed


## The carried pack as an ordered list of {item, count} for the inventory hotbar, in pickup order.
func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in items:
		out.append({"item": item, "count": int(items[item])})
	return out


## Every carried id in text order, for state-affecting walks.
func ids() -> Array[StringName]:
	return Ordering.ids(items)


## Is this item BULK freight, the class the cap counts? Everything is, except a placeable machine.
static func is_bulk_item(item: StringName) -> bool:
	if _bulk_class.has(item):
		return bool(_bulk_class[item])
	var bulk: bool = not MachineDef.exists(item)
	_bulk_class[item] = bulk
	return bulk


func carried_bulk() -> int:
	var total: int = 0
	for item: StringName in items:
		if is_bulk_item(item):
			total += int(items[item])
	return total


## Bulk units the pack still has room for, 0 when it is full (clamped, so an overfilled pack reads as
## "no room" rather than a negative every caller has to remember).
func pack_room() -> int:
	return maxi(0, bulk_cap() - carried_bulk())


## Would taking `n` of `item` leave the pack within the cap? Machine items always fit; `n` at or below
## zero always fits, because taking nothing cannot overfill anything.
func can_carry(item: StringName, n: int) -> bool:
	if n <= 0 or not is_bulk_item(item):
		return true
	return carried_bulk() + n <= bulk_cap()


func state_signature() -> String:
	return _lanes("p")


func recomputed_signature() -> String:
	return _rebuilt("p", ids())


func _store(item: StringName, n: int) -> void:
	_write_int(items, item, n)


## One term per stack: the id folded as the position, the count as the payload. A pack has no cells.
func _term_of(key: Variant) -> Vector2i:
	var item: StringName = key
	var n: int = count(item)
	if n <= 0:
		return Vector2i.ZERO
	var f: Vector2i = StateHash.id_fold(item)
	return StateHash.term(f.x, f.y, Vector2i(n, n), Vector2i.ONE)
