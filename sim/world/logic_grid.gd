class_name LogicGrid
extends RefCounted

## The metre-cell planes: what is PLACED on the 16 px logic grid, beside `TileGrid`'s 4 px terrain.
## `docs/adr/0009-metre-cell-planes-over-the-terrain-grid.md`; lifted in A' step 3b (D0347) from the
## `conduit`, `rope`, `torch` and `sapling` dictionaries `legacy/src/core/factory_sim.gd` kept on the hub
## (lines 279-313), plus legacy's `grid` (cell -> MachineState) reduced to an opaque occupant here.
##
## ONE `placed` PLANE. Legacy's rule that rock, a machine, a conduit, a rope and a torch never share a
## cell was a five-way `or` in `cell_occupied`; here every placed thing is one entry keyed by its cell,
## so two cannot coexist by construction. Machines register as the kind `&"machine"` and nothing more:
## this module knows no machine TYPE (`sim/world/MODULE.md`). Saplings are their own plane and keep
## legacy's known exception -- not in the exclusive set -- recorded in ADR 0009 rather than fixed here.
##
## Every coordinate is a `logic_cell` (D0020). The running signature is `TileGrid`'s pattern (D0261):
## two XOR lanes through `StateHash`, one term per record keyed by cell, kind and payload, and every
## write passes through one of the three `_write_*` sandwiches so a fourth mutator cannot skip the lanes.

const TERRAIN_PER_LOGIC: int = 4  ## terrain cells per logic cell per axis (16 px / 4 px). ADR 0009 says
                                  ## why this is written here rather than derived; the suite asserts it.

const KIND_MACHINE: StringName = &"machine"
const KIND_CONDUIT: StringName = &"conduit"
const KIND_ROPE: StringName = &"rope"
const KIND_TORCH: StringName = &"torch"
const KIND_SAPLING: StringName = &"sapling"   # signature namespace only; saplings live in their own plane

var placed: Dictionary = {}         # logic_cell -> kind: StringName (mutually exclusive per cell)
var conduit_tiers: Dictionary = {}  # logic_cell -> tier: int, only where placed[cell] == KIND_CONDUIT
var sapling: Dictionary = {}        # logic_cell -> age in hub ticks
var _sig_a: int = 0
var _sig_b: int = 0


func occupant(logic_cell: Vector2i) -> StringName:
	return placed.get(logic_cell, &"")


func is_occupied(logic_cell: Vector2i) -> bool:
	return placed.has(logic_cell)


func has_conduit(logic_cell: Vector2i) -> bool:
	return occupant(logic_cell) == KIND_CONDUIT


## The tier of the conduit at a cell (0 = none). One tier for now; deeper materials raise it later.
func conduit_tier(logic_cell: Vector2i) -> int:
	return int(conduit_tiers.get(logic_cell, 0))


func is_climbable(logic_cell: Vector2i) -> bool:
	return occupant(logic_cell) == KIND_ROPE


func has_torch(logic_cell: Vector2i) -> bool:
	return occupant(logic_cell) == KIND_TORCH


func has_sapling(logic_cell: Vector2i) -> bool:
	return sapling.has(logic_cell)


func sapling_age(logic_cell: Vector2i) -> int:
	return int(sapling.get(logic_cell, -1))


## Put `kind` at a cell. Refuses an occupied cell (returns false): the caller checks `World.logic_open`
## first, and this second gate is what makes exclusivity structural rather than conventional.
func occupy(logic_cell: Vector2i, kind: StringName, tier: int = 0) -> bool:
	if placed.has(logic_cell) or kind.is_empty():
		return false
	_write_placed(logic_cell, kind, tier)
	return true


## Clear whatever is placed at a cell; returns the kind that was there (empty if nothing).
func vacate(logic_cell: Vector2i) -> StringName:
	var was: StringName = occupant(logic_cell)
	if not was.is_empty():
		_write_placed(logic_cell, &"", 0)
	return was


func plant(logic_cell: Vector2i) -> void:
	_write_sapling(logic_cell, 0)


func set_sapling_age(logic_cell: Vector2i, age: int) -> void:
	_write_sapling(logic_cell, age)


## Removes the sapling; returns whether one was there.
func unplant(logic_cell: Vector2i) -> bool:
	if not sapling.has(logic_cell):
		return false
	_write_sapling(logic_cell, -1)
	return true


## The topmost segment of the connected rope through `logic_cell`: its ANCHOR end. Ropes are vertical.
func logic_rope_anchor(logic_cell: Vector2i) -> Vector2i:
	var c: Vector2i = logic_cell
	while is_climbable(c + Vector2i(0, -1)):
		c += Vector2i(0, -1)
	return c


## How many segments hang in the connected rope through `logic_cell` (0 = no rope there).
func rope_length(logic_cell: Vector2i) -> int:
	if not is_climbable(logic_cell):
		return 0
	var c: Vector2i = logic_rope_anchor(logic_cell)
	var n: int = 0
	while is_climbable(c):
		n += 1
		c += Vector2i(0, 1)
	return n


## Every placed cell of one kind, in scan order (top-to-bottom, left-to-right) -- the walk order for
## anything state-affecting (ADR 0009 §7).
func placed_logic_cells(kind: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in placed:
		if placed[c] == kind:
			out.append(c)
	out.sort_custom(Ordering.cell_less)
	return out


func sapling_logic_cells() -> Array[Vector2i]:
	return Ordering.cells(sapling)


func state_signature() -> String:
	return "l%d:%d" % [_sig_a, _sig_b]


func recomputed_signature() -> String:
	var a: int = 0
	var b: int = 0
	for c: Vector2i in placed:
		var t: Vector2i = _placed_term(c)
		a ^= t.x
		b ^= t.y
	for c: Vector2i in sapling:
		var t2: Vector2i = _sapling_term(c)
		a ^= t2.x
		b ^= t2.y
	return "l%d:%d" % [a, b]


func clone() -> LogicGrid:
	var copy: LogicGrid = LogicGrid.new()
	copy.placed = placed.duplicate()
	copy.conduit_tiers = conduit_tiers.duplicate()
	copy.sapling = sapling.duplicate()
	copy._sig_a = _sig_a
	copy._sig_b = _sig_b
	return copy


func _write_placed(logic_cell: Vector2i, kind: StringName, tier: int) -> void:
	_xor_term(_placed_term(logic_cell))
	if kind.is_empty():
		placed.erase(logic_cell)
		conduit_tiers.erase(logic_cell)
	else:
		placed[logic_cell] = kind
		if kind == KIND_CONDUIT:
			conduit_tiers[logic_cell] = tier
		else:
			conduit_tiers.erase(logic_cell)
	_xor_term(_placed_term(logic_cell))


func _write_sapling(logic_cell: Vector2i, age: int) -> void:
	_xor_term(_sapling_term(logic_cell))
	if age < 0:
		sapling.erase(logic_cell)
	else:
		sapling[logic_cell] = age
	_xor_term(_sapling_term(logic_cell))


func _placed_term(logic_cell: Vector2i) -> Vector2i:
	if not placed.has(logic_cell):
		return Vector2i.ZERO
	var tier: int = conduit_tier(logic_cell)
	return StateHash.term(logic_cell.x, logic_cell.y, StateHash.id_fold(placed[logic_cell]), Vector2i(tier, tier))


func _sapling_term(logic_cell: Vector2i) -> Vector2i:
	if not sapling.has(logic_cell):
		return Vector2i.ZERO
	var age: int = int(sapling[logic_cell])
	return StateHash.term(logic_cell.x, logic_cell.y, StateHash.id_fold(KIND_SAPLING), Vector2i(age + 1, age + 1))


func _xor_term(t: Vector2i) -> void:
	_sig_a ^= t.x
	_sig_b ^= t.y
