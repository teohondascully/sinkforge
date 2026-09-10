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

## THE SLOT A STACK KEEPS WHILE THE PLAYER HOLDS IT (D0553).
##
## The hotbar used to be `items`' own key order, and `remove()` erased a stack drained to 0 "so the
## hotbar never shows an empty slot". That comment named the benefit and not the cost: draining a stack
## SHIFTED EVERY STACK AFTER IT DOWN A NUMBER, and re-acquiring the item appended it at the END. So the
## rung that asks a player to drain stacks into a machine is exactly the rung that invalidates the
## numbers its own card tells them to press ("press each stack's NUMBER and Q"). Strangers 127-132
## measured it: four of six fed or selected the wrong stack, and the ONLY seat that delivered was the one
## whose bar never reordered (D0544).
##
## So the order is held here instead of being read off `items`. A drained stack leaves a GAP that keeps
## its number; the item returns to that number if it is picked up again; a NEW item takes the leftmost
## gap before it grows the bar, so the bar stays compact without any held stack ever moving.
##
## This is presentation and selection order only. `items` is untouched, so the state signature,
## conservation, `ids()` (text order, D0346) and the save envelope all behave exactly as before.
var order: Array[StringName] = []
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
	_remember(item)
	_store(item, count(item) + n)


## Take up to `n` of `item` out; returns how many came out. A stack drained to 0 leaves `items` -- that
## is legacy `_take_from_pack` and the signature depends on it -- but KEEPS ITS SLOT in `order`, so the
## numbers either side of it do not move (D0553). An entirely empty pack forgets its order, because a
## bar of nothing but gaps is not a bar and D0412 says an empty pack draws none.
func remove(item: StringName, n: int) -> int:
	var removed: int = mini(n, count(item))
	if removed <= 0:
		return 0
	_store(item, count(item) - removed)
	if items.is_empty():
		order.clear()
	return removed


## Give `item` a slot if it does not hold one: the leftmost gap, or a new slot at the end. Called only
## when something is actually going in, so a refused pickup never rearranges the bar.
func _remember(item: StringName) -> void:
	if order.has(item):
		return
	for i: int in order.size():
		if count(order[i]) <= 0:
			order[i] = item
			return
	order.append(item)


## The carried pack as an ordered list of {item, count} for the inventory hotbar, in pickup order.
func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in order:
		out.append({"item": item, "count": count(item)})
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
