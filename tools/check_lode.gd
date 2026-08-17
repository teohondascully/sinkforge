extends SceneTree

## THE VEIN OUTLIVES THE BLOW.
##
## Until this layer existed, one cell was both terrain and resource, and the two verbs that acted on it
## disagreed by two orders of magnitude: a drill took 250 units out of an ore cell, and a pick took a 3-6
## burst and then `deposits.erase(cell)`d the rest out of existence. Swinging at ore was the single most
## destructive act in the game and NOTHING said so — no tell, no refusal, no number on screen. A player who
## cleared a room to build in it could annihilate a four-hundred-unit vein in six swings and never learn it.
##
## Worse, it contradicted the kit: `docs/BITS.md` shipped a bit set whose premise is that you clear rock
## freely, by shape, and clearing rock freely was punished in exactly the places worth clearing.
##
## `docs/LODE.md`: terrain is what you CARVE, the lode is what you EXTRACT, and they stop being the same
## object. This layer holds the half of that which can be true before the generator moves (phase 1 of
## `docs/LODE_PLAN.md` §4) — the mechanic, the conservation, and the trap being gone.
##
##   THE TRAP IS GONE.      Clear rock over a seeded vein with every bit in the set; the deposit total is
##                          unchanged. This one case is the whole reason the migration exists.
##   THE BLOW OPENS IT.     Hand-mining an ore block takes its burst OUT of the vein and leaves the rest
##                          exposed and workable — not a hole where a vein used to be.
##   ONE POOL, TWO HANDS.   Hand-work and the drill draw down the same number, and every unit either takes
##                          is realised as production exactly once. Conservation is not renegotiated here.
##   IT IS FINITE.          A worked-out lode is gone: it stops reading as a vein and stops drawing as one.
##   COVERING IS NOT KILLING. Build a block back over a lode and the lode is behind it, not destroyed.
##   THE LADDER STILL HOLDS. Ore over your drive refuses, with #S37's own predicates, on a face instead of
##                          a block.
##
##   godot --headless --path . --script res://tools/check_lode.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

## The body is 34px tall against a 32px cell, so it always occupies two rows and any passage it uses must
## be at least that tall. Named here because the adit's whole geometry is a consequence of it.
const BODY_ROWS: int = 2

var _fails: int = 0
var _main: MainView
var _sim: FactorySim


func _initialize() -> void:
	print("== the vein outlives the blow ==")
	await _run()
	if _fails == 0:
		print("check_lode: PASS — the blow opens the vein instead of ending it")
		quit(0)
	else:
		printerr("check_lode: FAIL (%d)" % _fails)
		quit(1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _run() -> void:
	MainView.dev_start = false
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame
	_sim = _main.sim
	_the_adit_is_there()      # FIRST: every case below carves the spawn plateau up as its own fixture
	_the_trap_is_gone()
	_the_blow_opens_it()
	_one_pool_two_hands()
	_it_is_finite()
	_covering_is_not_killing()
	_the_ladder_still_holds()
	_it_round_trips()
	_the_rock_tells_on_itself()


## A sealed working with the body standing in it and a wall of `mat` in reach, each cell seeded to `each`.
## Returns the cell directly right of the body — the face every case swings at.
func _working(mat: StringName, each: int, span: int = 3) -> Vector2i:
	var home: Vector2i = _main._cell_at(_main._player.position)
	for dx: int in range(-5, 7):
		for dy: int in range(-5, 6):
			_sim.set_solid(home + Vector2i(dx, dy), &"stone")
			_sim.lode.erase(home + Vector2i(dx, dy))
			_sim.deposits.erase(home + Vector2i(dx, dy))
	for dx2: int in range(-1, 2):
		for dy2: int in range(-2, 1):
			_sim.set_solid(home + Vector2i(dx2, dy2), &"")
	# A BODY of ore, not a row: the Wedge only splits ALONG the grain, so a single-cell face it happens to
	# cross gives a vacuous pass (it destroys nothing because it does nothing). A body guarantees every bit
	# in the set has at least one cell it can really bite.
	for k: int in span:
		for dy3: int in range(-1, 2):
			var c: Vector2i = home + Vector2i(2 + k, dy3)
			_sim.set_solid(c, mat)
			_sim.deposits[c] = each
	_sim.inventory[&"wood_pickaxe"] = 1
	_sim.inventory[&"stone_pickaxe"] = 1
	_main._inv_selected = 0
	_main._cracks.clear()
	_main._dig_marks.clear()
	return home + Vector2i(2, 0)


## THE TRAP IS GONE. The headline case, and the one the whole migration is for: clear the rock over a
## seeded vein with every bit in the set and the vein is still worth exactly what it was worth. Driven
## through `try_mine` — the real verb, with the real bit equipped — rather than through `sim.mine`, because
## it is the BIT's extra reach (shape and calving) that makes this frightening: one Lance blow takes a
## column, and every cell it takes used to be a vein deleted.
func _the_trap_is_gone() -> void:
	var total_before: int = 0
	var total_after: int = 0
	# The per-bit assertions below already refuse a vacuous pass (no blow landed => red). The LOOP itself
	# needs the same treatment: drive it from BIT_RECIPES and an empty BIT_RECIPES skips every one of them,
	# leaving the summary assertion comparing 0 to 0 and printing green. 4 bits today.
	_check(BitRules.BIT_RECIPES.size() >= 3,
		"there is a bit set to swing at all (%d bits)" % BitRules.BIT_RECIPES.size())
	for bit: StringName in BitRules.BIT_RECIPES.keys():
		var face: Vector2i = _working(&"ore", 60, 3)
		_sim.inventory[bit] = 1
		var slots: Array[Dictionary] = _sim.inventory_slots()
		for i: int in slots.size():
			if slots[i]["item"] == bit:
				_main._inv_selected = i
		var before: int = _vein_total()
		var swung: int = 0
		for _i: int in 12:
			for k2: int in 3:
				for dy4: int in range(-1, 2):
					swung += 1 if _main.try_mine(face + Vector2i(k2, dy4)) else 0
		var after: int = _vein_total() + _pocketed()
		# GUARD AGAINST A VACUOUS PASS. "Nothing was destroyed" is trivially true if nothing was swung at;
		# this case is only worth having if the blows actually LANDED and actually opened the vein.
		_check(swung > 0, "%s: the blows land (%d took rock off)" % [String(bit), swung])
		_check(_opened_a_lode(face), "%s: …and what they opened is a lode you can still work" % String(bit))
		total_before += before
		total_after += after
		_check(after == before, "%s: the rock comes off and the vein is untouched (%d → %d)"
			% [String(bit), before, after])
		_sim.inventory.erase(bit)
		_main._inv_selected = 0
		_reset_pack()
	_check(total_after == total_before,
		"…across the whole bit set, not one unit of ore was destroyed by clearing rock (%d → %d)"
			% [total_before, total_after])


## THE BLOW OPENS IT. A hand-mined ore block leaves a workable face, and the burst it paid comes OUT of
## the vein rather than out of nowhere — so the number on the wall is the number you can still get.
func _the_blow_opens_it() -> void:
	var face: Vector2i = _working(&"ore", 60, 1)
	var before: int = _sim.ore_deposit_at(face)
	var got: int = int(_sim.inventory.get(&"ore", 0))
	_check(_sim.mine(face) == &"ore", "the pick takes the ore BLOCK off the face")
	var burst: int = int(_sim.inventory.get(&"ore", 0)) - got
	_check(burst > 0, "…and pays a loose burst for the blow (%d)" % burst)
	_check(not _sim.is_solid(face), "…the cell is open, as it always was")
	_check(_sim.lode_at(face) == &"ore", "…but what is behind it is a LODE, not nothing")
	_check(_sim.lode_workable(face), "…and it is workable: exposed, and with something left in it")
	_check(_sim.ore_deposit_at(face) == before - burst,
		"…and the burst came OUT of the vein (%d - %d = %d)" % [before, burst, _sim.ore_deposit_at(face)])


## ONE POOL, TWO HANDS. The hand and the machine draw the same number down, and each unit is realised as
## production exactly once. This is the invariant `docs/LODE_PLAN.md` §5c forbids renegotiating.
func _one_pool_two_hands() -> void:
	var face: Vector2i = _working(&"ore", 30, 1)
	_sim.mine(face)
	var pool: int = _sim.ore_deposit_at(face)
	var made: int = int(_sim.total_produced.get(&"ore", 0))
	var held: int = int(_sim.inventory.get(&"ore", 0))
	var took: int = 0
	for _i: int in 10:
		if _sim.take_lode(face) == &"ore":
			took += 1
	_check(took == 10, "ten hand-pulls take ten units (%d)" % took)
	_check(_sim.ore_deposit_at(face) == pool - 10,
		"…off the same pool the drill reads (%d → %d)" % [pool, _sim.ore_deposit_at(face)])
	_check(int(_sim.inventory.get(&"ore", 0)) == held + 10, "…into the pack, one for one")
	_check(int(_sim.total_produced.get(&"ore", 0)) == made + 10,
		"…and realised as production exactly once, so the ledger still balances")


## IT IS FINITE. A vein worked dry is spent, and everything that reads it has to agree — otherwise the wall
## keeps glittering at a player who cannot get anything out of it, which is the worst kind of lie a tell
## can tell.
func _it_is_finite() -> void:
	var face: Vector2i = _working(&"ore", 12, 1)
	_sim.mine(face)
	var guard: int = 0
	while _sim.lode_workable(face) and guard < 200:
		_sim.take_lode(face)
		guard += 1
	_check(guard < 200, "a vein can actually be worked dry (%d pulls)" % guard)
	_check(_sim.take_lode(face) == &"", "…and a dry vein gives nothing more")
	_check(_sim.lode_at(face) == &"", "…it stops being a lode at all")
	_check(_sim.ore_deposit_at(face) == 0, "…it reads as no vein")
	_check(_sim.lode_fraction(face) == 0.0, "…and it stops drawing as one (the renderer thins on this)")
	_check(not _main._lode_workable(face), "…so the hold-loop has nothing to work here")


## COVERING IS NOT KILLING. The lode is background; a block in front of it is a block in front of it. This
## matters because the whole point is that construction and resource stopped being the same object — if
## backfilling a gallery destroyed the vein behind it, they would still be the same object.
func _covering_is_not_killing() -> void:
	var face: Vector2i = _working(&"ore", 40, 1)
	_sim.mine(face)
	var left: int = _sim.ore_deposit_at(face)
	_check(left > 0 and _sim.lode_workable(face), "an open vein with %d in it" % left)
	_sim.set_solid(face, &"stone")
	_check(_sim.lode_at(face) == &"ore", "…build a wall over it and the vein is still there")
	_check(not _sim.lode_workable(face), "…just not workable, because you cannot reach through a wall")
	_sim.set_solid(face, &"")
	_check(_sim.lode_workable(face) and _sim.ore_deposit_at(face) == left,
		"…take the wall back off and it is the same vein, unchanged (%d)" % left)


## THE LADDER STILL HOLDS (#S37). A lode over your drive refuses, and it refuses through the SAME two
## predicates the crossed cursor and the skid are drawn from — so ore inherits every tell rock has without
## one line of new tell code. What must NOT happen is the bit gating it: bits shape holes, and working a
## face cuts no hole (`docs/LODE_PLAN.md` §8.3).
func _the_ladder_still_holds() -> void:
	var face: Vector2i = _working(&"iron", 40, 1)
	_sim.mine(face)
	_sim.inventory.erase(&"stone_pickaxe")
	_sim.inventory.erase(&"iron_pickaxe")
	_check(_sim.lode_workable(face), "there is iron in the wall, and the sim says it is workable rock")
	_check(not _main._lode_workable(face), "…but the starter drive cannot touch it")
	_check(_main._refuses(face), "…so it REFUSES, through the same predicate rock refuses with")
	_check(not _main._drive_bites(face), "…and the cursor goes cold and crossed before you press")
	_check(_main.try_work_lode(face) == false, "…and the verb takes nothing")
	_sim.inventory[&"stone_pickaxe"] = 1
	_check(_main._lode_workable(face) and not _main._refuses(face),
		"…and the moment you own the drive it gives")
	_sim.inventory[BitRules.WEDGE] = 1
	var slots: Array[Dictionary] = _sim.inventory_slots()
	for i: int in slots.size():
		if slots[i]["item"] == BitRules.WEDGE:
			_main._inv_selected = i
	_check(_main._lode_workable(face),
		"…and the Wedge — the one bit that refuses rock — never refuses ORE, because it shapes no hole here")
	_sim.inventory.erase(BitRules.WEDGE)
	_main._inv_selected = 0


## IT ROUND-TRIPS. A new world layer that does not survive a save is a bug the player meets hours later.
func _it_round_trips() -> void:
	var face: Vector2i = _working(&"ore", 44, 1)
	_sim.mine(face)
	var left: int = _sim.ore_deposit_at(face)
	var data: Dictionary = SaveGame.capture(_sim)
	var fresh := FactorySim.new()
	SaveGame.restore(fresh, data)
	_check(fresh.lode_at(face) == &"ore", "the lode survives a save/load round-trip")
	_check(fresh.ore_deposit_at(face) == left, "…with what was left in it (%d)" % left)
	var old: Dictionary = data.duplicate()
	old.erase("lode")
	var older := FactorySim.new()
	SaveGame.restore(older, old)
	_check(older.lode.is_empty(), "…and a save from before the lode existed still loads, with none")


## Did any cell of the seeded body end up as a workable lode? (The bit chooses which ones it can take.)
func _opened_a_lode(face: Vector2i) -> bool:
	for k: int in 3:
		for dy: int in range(-1, 2):
			if _sim.lode_at(face + Vector2i(k, dy)) == &"ore":
				return true
	return false


## THE STARTER ADIT. Once ore lives behind rock, the opening has a hole in it: a first-time player has
## nothing to aim at, because every vein in the world is buried and the stain that will telegraph them is
## phase 4. The adit is the answer — a face you can see from the surface, with the rock already off it.
##
## Three things have to be true, and the third is the one that bites: the vein has to be VISIBLE without
## digging, it has to CONTINUE past what you were given, and the cut has to be a place you can walk out of.
## This plateau's entire layout is arranged around the last one ("a 2-deep pit would trap the body — step-up
## climbs one tile"), and a fixture that ignored it would strand the player in the tutorial's own hole.
func _the_adit_is_there() -> void:
	var sim: FactorySim = _sim
	var top: int = MainView.SURFACE + MainView.ADIT_ROOF
	var mouth: int = MainView.ADIT_COLS[0]
	var face: int = MainView.ADIT_COLS[1]
	var room: int = MainView.ADIT_CHAMBER_COL
	var open_face: Array[Vector2i] = [Vector2i(face, top + 2), Vector2i(room, top + 1),
		Vector2i(room, top + 2), Vector2i(room, top + 3)]
	var seen: int = 0
	for c: Vector2i in open_face:
		if sim.lode_workable(c):
			seen += 1
	_check(seen == open_face.size(),
		"every spawn opens with a vein you can SEE and work without a swing (%d cells)" % seen)
	_check(not sim.is_solid(Vector2i(mouth, top)) and not sim.is_solid(Vector2i(face, top + 1)),
		"…because the rock is already off it — that is what makes it a face and not a guess")
	_check(not sim.lode.has(Vector2i(mouth, top)) and not sim.lode.has(Vector2i(mouth, top + 1)),
		"…and the break-in end is bare, so the vein is a reason to go deeper rather than a thing you land on")
	# THE SURFACE IS WHOLE. The pocket is sealed, and this is the assertion that earns its keep: the first two
	# versions of this cut opened onto the sky, and the plateau's surface is not spare ground — it is the
	# corridor the opening walks AND the runway `measure_player` and `check_fastforward` measure motion on.
	# A hole in it took four playthrough layers down at once, twice, in two different columns.
	var roof_whole: bool = true
	for col: int in [mouth, face, room]:
		for r: int in range(MainView.SURFACE, MainView.SURFACE + MainView.ADIT_ROOF):
			roof_whole = roof_whole and sim.is_solid(Vector2i(col, r))
	_check(roof_whole,
		"the ground OVER the pocket is unbroken — you can walk across it without knowing it is there")
	# YOU CAN WALK IT. The property the first cut broke and nothing caught: it stepped down one row per column
	# without keeping the row above open, so the body — 34px against a 32px cell, always two rows — met solid
	# rock with its HEAD at every step. The sim was content because the floor cells were clear. So this asserts
	# the corridor the way the body meets it: contiguous, two rows minimum, and OVERLAPPING by the body's own
	# height where one column hands over to the next.
	var cols: Array[int] = [mouth, face, room]
	var rows: Array = []
	for col: int in cols:
		var open_rows: Array[int] = []
		for r: int in range(top, top + 8):
			if not sim.is_solid(Vector2i(col, r)):
				open_rows.append(r)
		rows.append(open_rows)
	var tall: bool = true
	var contiguous: bool = true
	for open_rows: Variant in rows:
		var rr: Array[int] = open_rows
		tall = tall and rr.size() >= BODY_ROWS
		contiguous = contiguous and rr.size() == (rr[rr.size() - 1] - rr[0] + 1)
	_check(tall and contiguous,
		"every column of the cut is a clear run at least %d rows tall — the body's own height" % BODY_ROWS)
	var passable: bool = true
	var descends: bool = true
	for i: int in cols.size() - 1:
		var a: Array[int] = rows[i]
		var b: Array[int] = rows[i + 1]
		var shared: int = 0
		for r2: int in a:
			if b.has(r2):
				shared += 1
		passable = passable and shared >= BODY_ROWS
		var drop: int = b[b.size() - 1] - a[a.size() - 1]
		descends = descends and drop == 1
	_check(passable,
		"…and each column overlaps the next by %d, so you can walk through at the height you arrive at"
			% BODY_ROWS)
	_check(descends,
		"…dropping exactly one row per column, which is the reach of a step-up — two would be a trap")
	_check(sim.is_solid(Vector2i(mouth, MainView.SURFACE)),
		"…so getting in costs exactly ONE swing at the roof, which is the lesson the whole migration is about")
	# IT CONTINUES. What you were handed is the end of something, not the whole of it.
	var buried: int = 0
	for dy: int in range(4, 7):
		var c2 := Vector2i(room, top + dy)
		if sim.lode_at(c2) == &"ore" and sim.is_solid(c2):
			buried += 1
	_check(buried >= 3, "the vein CONTINUES behind the rock below the face (%d cells)" % buried)
	_check(int(sim.deposits.get(Vector2i(room, top + 4), 0))
			> int(sim.deposits.get(Vector2i(room, top + 3), 0)),
		"…and it gets richer as it goes, so following it is worth the digging")
	# And the free part is a taste, not a supply — the pressure to dig has to survive the gift.
	var given: int = 0
	for c3: Vector2i in open_face:
		given += int(sim.deposits.get(c3, 0))
	_check(given < FactorySim.DEFAULT_ORE_DEPOSIT,
		"…while the exposed part is a taste (%d), not a factory's worth" % given)


## Every unit still in the ground across the working.
func _vein_total() -> int:
	var t: int = 0
	for key: Variant in _sim.deposits:
		t += int(_sim.deposits[key])
	return t


## Every unit of ore that ended up in the pack instead (a burst is not a loss — it is a withdrawal).
func _pocketed() -> int:
	return int(_sim.inventory.get(&"ore", 0))


func _reset_pack() -> void:
	_sim.inventory.erase(&"ore")


## THE ROCK TELLS ON ITSELF (`docs/LODE.md` §10 phase 4).
##
## Once ore stops being a block, a world with no stain is uniform stone and the only way to find anything is
## to dig at random — so this is not a cosmetic pass, it is the prerequisite that keeps the cutover from
## being a legibility regression. Asserted on the RULE rather than on pixels: the tell is a HUE move that
## holds the host's value, it is real enough to see, and it is markedly quieter than an open face, because
## a buried vein you can read as clearly as an exposed one makes clearing the rock pointless.
func _the_rock_tells_on_itself() -> void:
	var r: WorldRenderer = _main._renderer
	var host := Color(0.29, 0.30, 0.34)                     # plain stone, untouched
	var vein: MaterialDef = r._material(&"ore")
	var buried: Color = r._stain(host, vein, WorldRenderer.LODE_STAIN_BURIED)
	buried.v *= WorldRenderer.LODE_STAIN_BURIED_DARK
	var face: Color = r._stain(host, vein, WorldRenderer.LODE_STAIN)
	var shift_buried: float = absf(buried.h - host.h) + absf(buried.s - host.s)
	var shift_face: float = absf(face.h - host.h) + absf(face.s - host.s)
	_check(shift_buried > 0.01, "rock with a vein behind it is NOT the colour of the rock beside it (%.3f)"
		% shift_buried)
	_check(buried.v < host.v and buried.v > host.v * 0.7,
		"…and it reads DARKER, like metal in stone, without becoming a hole (%.2f vs %.2f)"
			% [buried.v, host.v])
	_check(face.v >= host.v,
		"…while an OPEN face never darkens, because a hole that reads dark is just more rock")
	_check(shift_face > shift_buried,
		"…and an OPEN face stains further still (%.3f vs %.3f)" % [shift_face, shift_buried])
	# …and it actually reaches the terrain bake, not just the helper.
	var plain := Vector2i(6, 60)
	var veined := Vector2i(7, 60)                           # reused as `buried_cell` below
	for d: Vector2i in [Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		_sim.set_solid(plain + d, &"stone")
		_sim.set_solid(veined + d, &"stone")
	_sim.lode.erase(plain)
	_sim.lode[veined] = &"ore"
	_sim.deposits[veined] = 120
	var stone: MaterialDef = r._material(&"stone")
	var a: Color = r._cell_base_color(plain, stone)
	var b: Color = r._cell_base_color(veined, stone)
	_check(not a.is_equal_approx(b),
		"…and the SOLID terrain pass picks it up, so the tell survives into the rock you have not dug")
	# WHAT CLEARING THE ROCK ACTUALLY BUYS YOU. This started as a comparison of the two stains and the
	# comparison was the wrong test: covered rock now DARKENS and an open face does not, so they are not two
	# volumes of one signal, they are two different signals. The real answer is that only an exposed face
	# carries metal — the grain field of `_draw_lode`, which is also exactly the state the hand and the Head
	# can work. Buried, you get a discolouration and a decision; exposed, you get the vein.
	var open_cell := Vector2i(7, 58)
	_sim.set_solid(open_cell, &"")
	_sim.lode[open_cell] = &"ore"
	_sim.deposits[open_cell] = 120
	_sim.lode_max[open_cell] = 120
	_check(not _sim.lode_workable(veined) and _sim.lode_workable(open_cell),
		"…and only the OPEN one carries metal you can see and work — that is what the swing buys")

	# NO MOTION. `_draw_ore_glints` learned at some cost that sparkling sealed cells read as a starfield;
	# the buried tell must stay still, so a sealed cell is not allowed to be a glint candidate.
	var sealed: bool = _sim.is_solid(veined + Vector2i(0, -1)) and _sim.is_solid(veined + Vector2i(0, 1)) \
		and _sim.is_solid(veined + Vector2i(-1, 0)) and _sim.is_solid(veined + Vector2i(1, 0))
	_check(sealed, "…on a cell sealed in rock, which is exactly where a GLINT would read as a floating star")
