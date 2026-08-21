extends "res://tools/check_base.gd"

## THE CAP HAS TO BITE ON THE VERB, AND FOR WEEKS IT BIT ON NOTHING.
##
## `PACK_BULK_CAP`, `is_bulk_item`, `carried_bulk`, `pack_room` and `can_carry` were written, commented and
## unit-tested long before any of them was wired, and `tools/_scratch_carry_cap.gd` still exercises exactly
## that: the predicate, in isolation, correctly. **Every one of its assertions passed throughout the entire
## period in which the cap did nothing whatsoever to the player.** That is the gap this layer exists to
## close, and it is why nothing here calls `can_carry` directly. A test that asks the predicate whether it
## would refuse cannot notice that nobody asks it.
##
## So every assertion below goes through `mine()` and `collect_ground()` — the calls the player's swing and
## the player's step actually make — and reads the pack afterwards.
##
## THE FOUR PROPERTIES, and each of them is one somebody could plausibly "fix" into being wrong:
##
##   THE SWING IS NEVER REFUSED. A full pack still breaks the block. Gating the dig on room is the obvious
##     implementation and it is the wrong one: a pick that stops working reads as a broken control, not as a
##     full bag, and the player has no way to tell which it is.
##   THE PACK NEVER EXCEEDS THE CAP. The whole point.
##   THE OVERFLOW IS CONSERVED. It falls. This file argues for conservation everywhere else and a cap that
##     quietly deletes ore would be the one place it lies. Asserted by finding the units, not by observing
##     that the pack failed to grow — those two are indistinguishable from inside the pack and only one of
##     them is correct.
##   A FULL PACK DOES NOT SCOOP ITS OWN SPILL. `collect_ground` is capped too. Without that the material
##     lands and is picked straight back up on the next step, the return trip never happens, and the cap
##     becomes a stutter in the pickup animation. This is the assertion that decides whether the feature is
##     real, so it is the one with the most controls around it.
##
## BOTH DIRECTIONS, ALWAYS. Every full-pack assertion is paired with a below-cap or non-bulk control,
## because a cap stuck permanently closed satisfies all four properties above and breaks the game. A layer
## that only tests the refusal is a layer that cannot tell working from jammed.

const FLOOR_ROWS: int = 3       ## solid rows under the mined cell, so the spill has somewhere to land
const LATENT: int = 8           ## deposit planted in the test cell; larger than any burst it can yield


func _initialize() -> void:
	print("== the bulk carry cap, on the verb ==")
	var cap: int = FactorySim.PACK_BULK_CAP
	_check(cap > 0, "fixture: PACK_BULK_CAP is a positive number of units (%d)" % cap)
	if cap <= 0:
		_verdict("check_carry_cap", "the cap constant is meaningless; nothing below could mean anything")
		return

	_full_pack_still_swings(cap)
	_overflow_is_conserved(cap)
	_a_full_pack_leaves_its_spill(cap)
	_the_lode_face_is_the_ore_verb(cap)
	_the_other_direction(cap)

	_verdict("check_carry_cap",
		"a full pack breaks the block, keeps the cap, spills the rest where it can be fetched, and "
			+ "does not pick it straight back up")


## A sim with ground under the test cell and a known deposit in it. THE FLOOR IS NOT DECORATION: a falling
## item goes to the first machine below, else the first floor, else the void sink, so a bare `FactorySim`
## has a bottomless column and the sink eats the spill. The first run of this fixture reported the overflow
## destroyed and the seam was fine — it was this. A real world always has rock under a mined cell.
func _rig(cell: Vector2i, prefill: int) -> FactorySim:
	var sim := FactorySim.new()
	for dy: int in range(1, FLOOR_ROWS + 1):
		sim.solid[cell + Vector2i(0, dy)] = &"stone"
	sim.solid[cell] = &"ore"
	sim.deposits[cell] = LATENT
	if prefill > 0:
		# The STARTING STATE, not the thing under test. Written straight into the pack on purpose: posing it
		# through `mine` would make the setup depend on the behaviour being measured.
		sim.inventory[&"stone"] = prefill
	return sim


## THE LODE FACE, WHICH THE FIRST VERSION OF THIS LAYER DID NOT COVER AND SHOULD HAVE.
##
## `mine()` breaks blocks; `take_lode` is the hand verb for working an exposed ore face one unit at a time,
## and the lode is where ore actually lives — terrain is what you carve, the lode is what you extract. The
## first version asserted through `mine()` and `collect_ground()` only, so the cap could have bound on rock
## and missed ore entirely and this layer would have stayed green. Found by c1 reading the seam against the
## call sites rather than against the layer.
##
## THE RULE HERE IS DELIBERATELY NOT THE MINING RULE, and the difference is not an inconsistency.
## `mine()` DESTROYS a block, so the material it frees has nowhere to be but the world, and refusing the
## swing would make a full pack read as a broken pick. `take_lode` takes one unit off a face that stays
## exactly where it was: nothing is destroyed, so there is no homeless material, and the honest answer to
## "you cannot carry this" is that you do not take it. Refusing also keeps the vein intact instead of
## letting a full player drain it onto the floor and down the column one click at a time.
##
## So: a full pack takes nothing, the deposit is untouched, and NOTHING is spilled. All three, because
## "returned empty" and "took it anyway" and "spilled it" are three different behaviours and only one is
## right.
func _the_lode_face_is_the_ore_verb(cap: int) -> void:
	var cell := Vector2i(30, 40)
	var sim := FactorySim.new()
	# An exposed workable face: a lode with no solid over it and units left in the deposit.
	sim.lode[cell] = &"ore"
	sim.deposits[cell] = 5
	sim.inventory[&"stone"] = cap
	_check(sim.lode_workable(cell), "fixture: the lode face is exposed and workable")
	_check(sim.carried_bulk() == cap, "fixture: and the pack is at the cap")

	var deposit_before: int = int(sim.deposits.get(cell, 0))
	var bulk_before: int = sim.carried_bulk()
	var got: StringName = sim.take_lode(cell)

	_check(got == &"",
		"A FULL PACK TAKES NOTHING FROM THE FACE (returned '%s')" % String(got))
	_check(sim.carried_bulk() == bulk_before,
		"...the pack did not grow (%d -> %d)" % [bulk_before, sim.carried_bulk()])
	_check(int(sim.deposits.get(cell, 0)) == deposit_before,
		"...the vein is intact, not drained onto the floor (%d -> %d)"
			% [deposit_before, int(sim.deposits.get(cell, 0))])
	_check(_on_floor(sim, &"ore") == 0,
		"...and nothing was spilled: a face that keeps its ore has none to spill")

	# CONTROL, the direction that catches a verb jammed shut: with room, the same call yields.
	var open_sim := FactorySim.new()
	open_sim.lode[cell] = &"ore"
	open_sim.deposits[cell] = 5
	var yielded: StringName = open_sim.take_lode(cell)
	_check(yielded == &"ore",
		"CONTROL a pack with room takes the unit from the identical face ('%s')" % String(yielded))
	_check(int(open_sim.inventory.get(&"ore", 0)) == 1,
		"...and it is in the pack")


## Every unit of `item` anywhere in the world's piles, so conservation is checked by finding the material
## rather than by noting its absence from the pack. Returns 0 for an empty world, which is the honest answer
## and also the FAILING one wherever it is used below — a helper whose empty case satisfies its caller is
## this repository's most repeated defect.
func _on_floor(sim: FactorySim, item: StringName) -> int:
	var total: int = 0
	for key: Variant in sim.ground:
		total += int((sim.ground[key] as Dictionary).get(item, 0))
	return total


func _full_pack_still_swings(cap: int) -> void:
	var cell := Vector2i(12, 40)
	var sim: FactorySim = _rig(cell, cap)
	_check(sim.carried_bulk() == cap, "fixture: the pack starts exactly at the cap (%d)" % sim.carried_bulk())
	_check(sim.pack_room() == 0, "fixture: ...so it reports no room")

	var before: int = sim.carried_bulk()
	sim.mine(cell, true)
	_check(not sim.solid.has(cell),
		"THE SWING IS NOT REFUSED — a full pack still breaks the block out of the wall")
	_check(sim.carried_bulk() <= cap,
		"the pack never exceeds the cap (%d <= %d)" % [sim.carried_bulk(), cap])
	_check(sim.carried_bulk() == before,
		"and standing exactly at the cap it took nothing at all (%d -> %d)" % [before, sim.carried_bulk()])


func _overflow_is_conserved(cap: int) -> void:
	var cell := Vector2i(12, 40)
	var sim: FactorySim = _rig(cell, cap)
	var produced_before: int = int(sim.total_produced.get(&"ore", 0))
	sim.mine(cell, true)
	var produced: int = int(sim.total_produced.get(&"ore", 0)) - produced_before
	var in_pack: int = int(sim.inventory.get(&"ore", 0))
	var on_floor: int = _on_floor(sim, &"ore")

	# The control has to come first: if the burst were zero, "nothing was lost" would be trivially true and
	# the conservation assertion below would pass while measuring an empty event.
	_check(produced > 0,
		"CONTROL the burst really happened — the world gave up %d unit(s) of ore" % produced)
	_check(in_pack + on_floor == produced,
		"CONSERVATION every produced unit is in the pack or on the floor (%d + %d == %d)"
			% [in_pack, on_floor, produced])
	_check(on_floor > 0,
		"...and with the pack full the overflow is what reached the floor (%d there)" % on_floor)


func _a_full_pack_leaves_its_spill(cap: int) -> void:
	var cell := Vector2i(12, 40)
	var sim: FactorySim = _rig(cell, cap)
	sim.mine(cell, true)

	var spill := Vector2i(-1, -1)
	for key: Variant in sim.ground:
		if int((sim.ground[key] as Dictionary).get(&"ore", 0)) > 0:
			spill = key
			break
	_check(spill != Vector2i(-1, -1), "fixture: the spill left a pile to try collecting")
	if spill == Vector2i(-1, -1):
		return

	var pile_before: int = int((sim.ground[spill] as Dictionary).get(&"ore", 0))
	var took: int = sim.collect_ground(spill)
	var pile_after: int = int((sim.ground.get(spill, {}) as Dictionary).get(&"ore", 0))
	_check(took == 0,
		"A FULL PACK COLLECTS NOTHING from its own spill — otherwise the return trip never happens")
	_check(pile_after == pile_before,
		"...and the pile is left whole for that trip (%d -> %d)" % [pile_before, pile_after])

	# The other half, on the same pile: make room and the material is genuinely retrievable. Without this a
	# `collect_ground` that always returned 0 would satisfy everything above.
	sim.inventory[&"stone"] = 0
	var got: int = sim.collect_ground(spill)
	_check(got == pile_before,
		"CONTROL and once there is room the same pile comes up whole (%d of %d)" % [got, pile_before])


func _the_other_direction(cap: int) -> void:
	# An empty pack must still fill from the identical call. A cap stuck permanently closed passes every
	# assertion above and is a broken game, and this is the cheapest thing that tells the two apart.
	var cell := Vector2i(12, 40)
	var open_sim: FactorySim = _rig(cell, 0)
	open_sim.mine(cell, true)
	_check(open_sim.carried_bulk() > 0,
		"CONTROL an EMPTY pack still fills from the same verb (%d unit(s))" % open_sim.carried_bulk())
	_check(_on_floor(open_sim, &"ore") == 0,
		"...and with room to spare nothing was spilled that did not need to be")

	# Gear is not freight. The cap is on what you haul, not on what you carry to work with, and the exempt
	# side is where `is_bulk_item` derives its whole classification from.
	var kit: FactorySim = _rig(Vector2i(20, 40), cap)
	_check(kit.can_carry(&"wood_pickaxe", 1),
		"CONTROL a pickaxe still fits a pack that is full of freight")
	_check(not kit.can_carry(&"ore", 1),
		"...on the very same pack that refuses one more unit of ore")
