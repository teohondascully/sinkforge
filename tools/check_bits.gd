extends "res://tools/check_base.gd"

## A BIT IS A VERB, NOT A NUMBER.
##
## `BitRules` splits the pick into a DRIVE (what you may bite at all — researched, monotonic) and a BIT (what
## one swing takes — bought, horizontal, kept forever). The point of the split is that no bit is a strict
## upgrade over another: each is worse somewhere, so choosing one is a decision rather than a purchase. This
## layer holds the four claims that make that true, because every one of them is a claim about what the code
## does rather than about what the design document says.
##
##   THE SHAPE — each bit takes the geometry it advertises, and the aimed cell is always in it. The aim
##     cursor points at one cell; a bit adds to that cell and must never move it, or the cursor is lying.
##   THE PRICE — the Broad PULVERISES. Nothing it breaks reaches your pack. That single cost is what makes
##     the set a set: you hollow a chamber with the Broad and swap to the Point at the first vein, and if
##     this check ever passes silently the Broad becomes a free 4x upgrade and every other bit is pointless.
##   THE DRIVE STILL RULES — no bit breaks a cell `can_mine` refuses, through its own shape OR through a
##     seam run. A bit changes the shape of the hole; it must never change how deep in the world you may be.
##   THE REACH OF A BLOW — a driven bit stops at rock's edge. Neither a Lance nor a seam run may cross an
##     open chamber and take rock on the far side.
##
## The Wedge gets its own case because it is the one bit that can REFUSE, and the refusal has to happen in
## `_mineable` rather than in `try_mine`: the hold-loop charges on that same predicate, so a cell that reads
## as mineable and then will not break spiders a full charge and starts over, forever.

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _sim: FactorySim
var _frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== a bit is a verb ==")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_sim = _main.sim
	_equipping()
	_shapes()
	_pulverise()
	_gates()
	_wedge()
	_verdict("check_bits", "every bit is worse than the Point somewhere")


## Equipping is stateless: the bit is whatever is in the selected slot, and everything else is the Point.
func _equipping() -> void:
	_check(BitRules.equipped(BitRules.BROAD) == BitRules.BROAD, "selecting a bit equips it")
	_check(BitRules.equipped(&"ore") == BitRules.POINT, "selecting ore puts you back on the Point")
	_check(BitRules.equipped(&"") == BitRules.POINT, "an empty pack is the Point")
	_check(not BitRules.is_bit(BitRules.POINT), "the Point is not an item — nothing to seed or migrate")
	_check(MiningRules.is_tool_item(BitRules.LANCE), "a bit is GEAR, so it can't be fed to a machine as fuel")


## Each bit takes the geometry it claims, and the aimed cell is always among it.
func _shapes() -> void:
	for bit: StringName in [BitRules.POINT, BitRules.BROAD, BitRules.LANCE, BitRules.SINKER, BitRules.WEDGE]:
		var cells: Array[Vector2i] = BitRules.cut(bit, Vector2i(50, 50), 1)
		_check(cells.has(Vector2i(50, 50)), "the %s cuts the cell you aimed at" % BitRules.label(bit))

	# Driven against a solid block, each shape must take exactly the cells it advertises.
	_check(_dig(BitRules.POINT, 4) == 1, "the Point takes one cell")
	_check(_dig(BitRules.BROAD, 4) == 4, "the Broad takes a 2x2")
	_check(_dig(BitRules.LANCE, 6) == 5, "the Lance drives five cells")
	_check(_dig(BitRules.SINKER, 4) == 3, "the Sinker takes three straight down")

	# A directional bit is a DRIVEN line: a chamber in the way ends the drive.
	var row: int = _plain_row()
	_clear(row, 20, 50)
	for x: int in range(30, 33):
		_sim.set_solid(Vector2i(x, row), &"stone")     # a three-thick face, then a gap, then more rock
	for x: int in range(35, 40):
		_sim.set_solid(Vector2i(x, row), &"stone")
	_equip(BitRules.LANCE)
	_main._player.position = _main._cell_center(Vector2i(29, row))
	var before: int = _solid_in(row, 20, 50)
	_main.try_mine(Vector2i(30, row))
	var took: int = before - _solid_in(row, 20, 50)
	print("  a Lance driven at a three-thick face with a gap behind it took %d cells" % took)
	_check(took == 3, "a driven bit stops at rock's edge — it never crosses a chamber")


## The Broad pulverises. This is the cost that makes the whole set a set.
func _pulverise() -> void:
	var row: int = _plain_row()
	_clear(row, 60, 74)
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_sim.set_solid(Vector2i(66, row) + d, &"ore")
	_equip(BitRules.BROAD)
	_main._player.position = _main._cell_center(Vector2i(65, row))
	var ore_before: int = int(_sim.inventory.get(&"ore", 0))
	var made_before: int = int(_sim.total_produced.get(&"ore", 0))
	var solid_before: int = _solid_in(row, 60, 74)
	_main.try_mine(Vector2i(66, row))
	var broke: int = solid_before - _solid_in(row, 60, 74)
	print("  a Broad through a 2x2 of ore broke %d cells and pocketed %d ore"
		% [broke, int(_sim.inventory.get(&"ore", 0)) - ore_before])
	_check(broke == 4, "the Broad broke the whole 2x2 of ore")
	_check(int(_sim.inventory.get(&"ore", 0)) == ore_before, "…and NONE of it reached the pack")
	# Conservation: a pulverised block was never produced, so the ledger must not have moved either.
	_check(int(_sim.total_produced.get(&"ore", 0)) == made_before,
		"…and none of it was counted as produced (the ledger stays total)")

	# The same 2x2 with the Point is the control: this is a cost of the BIT, not of the rock.
	_clear(row, 60, 74)
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_sim.set_solid(Vector2i(66, row) + d, &"ore")
	_equip(&"")
	var point_before: int = int(_sim.inventory.get(&"ore", 0))
	_main.try_mine(Vector2i(66, row))
	_check(int(_sim.inventory.get(&"ore", 0)) > point_before, "the Point pockets the same ore (it is the bit's cost, not the rock's)")


## No bit reaches past the drive — not through its own shape, and not through a seam run.
func _gates() -> void:
	var tier: int = MiningRules.best_tier(&"pick", _sim.inventory)
	if tier >= MiningRules.required_tier(&"deepslate"):
		print("  (skipped: the pack already holds a tier-%d pick, so nothing here is over-tier)" % tier)
		return
	var row: int = _plain_row()
	_clear(row, 80, 100)
	_sim.set_solid(Vector2i(86, row), &"stone")
	for x: int in range(87, 92):
		_sim.set_solid(Vector2i(x, row), &"deepslate")     # straight in the Lance's path
	_equip(BitRules.LANCE)
	_main._player.position = _main._cell_center(Vector2i(85, row))
	var before: int = _solid_in(row, 80, 100)
	_main.try_mine(Vector2i(86, row))
	var took: int = before - _solid_in(row, 80, 100)
	print("  a Lance driven into over-tier rock took %d cell(s)" % took)
	_check(took == 1, "a bit's shape never breaks rock the drive cannot bite")


## The Wedge splits or it does nothing — and it must say which BEFORE the swing, or the hold-loop spins.
func _wedge() -> void:
	var bedded: int = _bedding_row()
	var plain: int = _plain_row()
	if bedded < 0 or plain < 0:
		_check(false, "the world has both a bedded and an unbedded row to test the Wedge on")
		return
	_equip(BitRules.WEDGE)

	# Across the grain: the cursor must refuse it, so the charge never starts.
	_clear(plain, 100, 118)
	for y: int in range(plain - 1, plain + 2):
		_sim.set_solid(Vector2i(108, y), &"stone")
	_main._player.position = _main._cell_center(Vector2i(107, plain))
	var target := Vector2i(108, plain)
	_check(_main._can_reach(target), "the across-grain target is genuinely in reach (so the next check means something)")
	_check(not _main._mineable(target),
		"the Wedge REFUSES rock across the grain in _mineable — the cursor greys out, the charge never spins")
	_check(not _main.try_mine(target), "…and the verb refuses it too")

	# Along the grain: it splits, and deeper than the Point would.
	_clear(bedded, 100, 124)
	for x: int in range(110, 122):
		_sim.set_solid(Vector2i(x, bedded), &"stone")
	_main._player.position = _main._cell_center(Vector2i(109, bedded))
	var before: int = _solid_in(bedded, 100, 124)
	_check(_main._mineable(Vector2i(110, bedded)), "the Wedge accepts rock ALONG the grain")
	_main.try_mine(Vector2i(110, bedded))
	var split: int = before - _solid_in(bedded, 100, 124)
	print("  a Wedge along a bedding plane split %d cells (the Point's cap is %d)" % [split, Seams.RUN_CAP])
	_check(split > Seams.RUN_CAP, "the Wedge splits further along a seam than a plain swing does")
	_check(split <= BitRules.cap(BitRules.WEDGE), "…and never past its own cap")


# --- rigging -------------------------------------------------------------------------------------

## Put a bit in the pack and select it. `&""` selects nothing, which is the Point.
func _equip(bit: StringName) -> void:
	if bit == &"":
		_main._inv_selected = -1
		return
	_sim.inventory[bit] = maxi(int(_sim.inventory.get(bit, 0)), 1)
	var slots: Array[Dictionary] = _sim.inventory_slots()
	for i: int in slots.size():
		if slots[i]["item"] == bit:
			_main._inv_selected = i
			return
	_check(false, "could not select %s in the hotbar" % bit)


## Drive one blow at a solid block of `size` cells square and report how many cells it took.
func _dig(bit: StringName, size: int) -> int:
	var row: int = _plain_row()
	_clear(row, 20, 20 + size + 10)
	for x: int in range(26, 26 + size):
		for y: int in range(row, row + size):
			_sim.set_solid(Vector2i(x, y), &"stone")
	_equip(bit if bit != BitRules.POINT else &"")
	_main._player.position = _main._cell_center(Vector2i(25, row))
	var before: int = _solid_in(row, 20, 20 + size + 10)
	_main.try_mine(Vector2i(26, row))
	return before - _solid_in(row, 20, 20 + size + 10)


func _clear(row: int, from_x: int, to_x: int) -> void:
	for x: int in range(from_x, to_x):
		for y: int in range(row - 4, row + 8):
			_sim.set_solid(Vector2i(x, y), &"")


func _solid_in(row: int, from_x: int, to_x: int) -> int:
	var n: int = 0
	for x: int in range(from_x, to_x):
		for y: int in range(row - 4, row + 8):
			if _sim.solid.has(Vector2i(x, y)):
				n += 1
	return n


## A row this world made a bedding plane — where the Wedge and the seam run have something to follow.
func _bedding_row() -> int:
	for y: int in range(MainView.SURFACE + 8, MainView.SURFACE + 44):
		if Seams.at(Vector2i(0, y), _sim.world_seed) == Seams.HORIZONTAL:
			return y
	return -1


## A row with NO bedding plane on it — where a swing is honestly across the grain, so the shape tests
## measure the bit rather than the rock.
func _plain_row() -> int:
	for y: int in range(MainView.SURFACE + 8, MainView.SURFACE + 44):
		if Seams.at(Vector2i(0, y), _sim.world_seed) != Seams.HORIZONTAL:
			return y
	return -1
