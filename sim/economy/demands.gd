class_name Demands
extends RefCounted

## THE RIG'S LADDER (D0484): `data/progression`'s demand records in `order`, read by the rig's runner, by
## `Machines.machine_eats`, by the machine painter's need bubble and by the objective ladder. A rig's
## `MachineState.stage` is how many demands it has met; `at(stage)` is the one it is asking for now, `{}`
## once the ladder is spent. Item ids come out as StringNames whatever the generated table stored.

static var _ordered: Array[Dictionary] = []


static func ordered() -> Array[Dictionary]:
	if _ordered.is_empty():
		var records: Array[Dictionary] = []
		for id: StringName in Ordering.ids(ProgressionRecords.RECORDS):
			records.append(ProgressionRecords.RECORDS[String(id)])
		records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
		_ordered = records
	return _ordered


static func count() -> int:
	return ordered().size()


static func at(stage: int) -> Dictionary:
	var all: Array[Dictionary] = ordered()
	return all[stage] if stage >= 0 and stage < all.size() else {}


## What the demand at `stage` takes, item id -> count; `{}` past the ladder's end.
static func wants(stage: int) -> Dictionary:
	return RecipeDef.item_counts(at(stage).get("wants", {}))


## What the rig sets down when the demand at `stage` is met.
static func grants(stage: int) -> Dictionary:
	return RecipeDef.item_counts(at(stage).get("grants", {}))
