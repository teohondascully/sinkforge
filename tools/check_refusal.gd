extends "res://tools/check_base.gd"

## THE ROCK THAT SAYS NO.
##
## `docs/BITS.md` §2 deleted the speed axis: a drive is a KEY, not a stat, and rock above your tier does not
## come slowly; it does not come at all. §5 is the other half of that bargain, and it is the half that was
## missing: **a binary gate is only honest if you can see it coming.** Until now a swing at over-tier rock
## produced nothing whatsoever, no sound and no spark and no words, which is indistinguishable from a game that
## dropped your click. That is the single worst thing a hard gate can feel like.
##
##   IT STILL REFUSES.   Holding on rock over your drive yields NO progress at all, ever. Not slow: none.
##   IT SAYS SO FIRST.   The aim cursor reports the refusal BEFORE the press: `_drive_bites` is false on
##                       over-tier rock and true on rock your pick can take, so the cold crossed cursor and
##                       the actual gate can never disagree.
##   IT SKIDS.           Holding fires the skid on its own cadence, a real sound from the real library,
##                       so what you feel is swinging and not biting rather than nothing happening.
##   IT NAMES THE RUNG.  Once, on a cooldown: the drive this rock wants, by name, derived from the same
##                       table the gate reads. "You need a better pick" is not information.
##   AND IT SHUTS UP ON ROCK YOU CAN BREAK. The tell must never fire where the pick works, or it is noise.
##
##   godot --headless --path . --script res://tools/check_refusal.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

var _main: MainView
var _sim: FactorySim


func _initialize() -> void:
	print("== the rock that says no ==")
	await _run()
	_verdict("check_refusal", "over-tier rock refuses, and you can see, hear and read why")

func _run() -> void:
	MainView.dev_start = false
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame
	_sim = _main.sim
	_the_table()
	_it_refuses()
	_it_says_so_first()
	_it_skids_and_names_the_rung()
	_the_wedge_refusal()
	_it_shuts_up_where_the_pick_works()


## THE TABLE. The name in the refusal comes from the same place as the gate, so it cannot drift.
func _the_table() -> void:
	_check(MiningRules.drive_for(&"deepslate") == &"stone_pickaxe",
		"deepslate names the STONE pickaxe — the lowest drive that can actually bite it")
	_check(MiningRules.drive_for(&"stone") == &"wood_pickaxe",
		"…and ordinary stone names the starter pick, not an upgrade you don't need")
	var deep_tier: int = MiningRules.required_tier(&"deepslate")
	_check(int(MiningRules.TOOLS[MiningRules.drive_for(&"deepslate")][&"tier"]) >= deep_tier,
		"…and the drive it names actually meets the tier the rock demands (%d)" % deep_tier)


## A SEALED POCKET whose every wall is `mat`, with the body standing in it. The mining LOOP derives its own
## aim from the real cursor, and a headless cursor sits twenty cells off the body (the snap only considers
## cells within reach of the CURSOR), so the loop can never be pointed at a wall from here. What can be
## driven honestly is the gate, the predicate the loop branches on, and the skid itself, which is all of
## the mechanism; the loop's own line is `if pressed and _refuses(_aim): _skid(...)`.
func _pocket(mat: StringName) -> Vector2i:
	var home: Vector2i = _main._cell_at(_main._player.position)
	for dx: int in range(-4, 5):
		for dy: int in range(-4, 5):
			_sim.set_solid(home + Vector2i(dx, dy), mat)
	for dx2: int in range(-1, 2):
		for dy2: int in range(-2, 1):
			_sim.set_solid(home + Vector2i(dx2, dy2), &"")
	_sim.inventory.erase(&"stone_pickaxe")
	_sim.inventory.erase(&"iron_pickaxe")
	_sim.inventory[&"wood_pickaxe"] = 1
	_main._inv_selected = 0
	_main._cracks.clear()
	_main._dig_marks.clear()
	_main._hud._flash_text = ""
	_main._skid_tell = 0.0
	_main._skid_clock = MainView.SKID_PERIOD
	return home + Vector2i(2, 0)


## IT STILL REFUSES, through try_mine, the verb the play-harness drives and the one real gate.
func _it_refuses() -> void:
	var face: Vector2i = _pocket(&"deepslate")
	var broke: bool = false
	for _i: int in 40:
		broke = broke or _main.try_mine(face)
	_check(not broke and _sim.is_solid(face), "forty swings at over-tier rock break nothing at all")
	_check(not _main._cracks.has(face), "…and bank no charge either — not slow, NONE")
	var stone: Vector2i = _pocket(&"stone")
	var took: bool = false
	for _i2: int in 60:
		took = took or _main.try_mine(stone)
	_check(took and not _sim.is_solid(stone), "…while the same swings take ordinary rock (the control)")


## IT SAYS SO FIRST. The cursor's refusal and the loop's gate are one fact read two ways, so they are
## asserted against each other rather than each against a hard-coded answer.
func _it_says_so_first() -> void:
	var face: Vector2i = _pocket(&"deepslate")
	_check(_main._refuses(face), "the loop's own predicate calls over-tier rock a REFUSAL")
	_check(not _main._drive_bites(face), "…and the cursor draws it cold and crossed, before any press")
	_sim.inventory[&"stone_pickaxe"] = 1
	_check(not _main._refuses(face) and _main._drive_bites(face),
		"…and the moment you own the drive, both agree it bites")
	_sim.inventory.erase(&"stone_pickaxe")
	var air: Vector2i = _main._cell_at(_main._player.position)
	_check(not _main._refuses(air) and _main._drive_bites(air),
		"…while open air is never a refusal — there is nothing there to refuse")


## IT SKIDS, AND THE RUNG IS NAMED, by the inspector, which is the panel that is already on screen for
## as long as you hold the cursor on the rock. The skid brings the sound and the sparks; the words are
## said once, in one place, by whichever tell owns them.
func _it_skids_and_names_the_rung() -> void:
	var face: Vector2i = _pocket(&"deepslate")
	_check(_main._sfx._streams.has(&"skid"), "there is a real SKID in the sound library, synthesised like the rest")
	var before: int = _main._skids
	_main._skid(face, 0.05)
	_check(_main._skids == before + 1, "a swing at rock over your drive skids")
	var panel: Dictionary = _main._hover_info_at(face)
	print("  the inspector says: %s / %s" % [str(panel.get("name", "")), str(panel.get("mode", ""))])
	_check(str(panel.get("mode", "")).findn("stone pickaxe") >= 0,
		"…and the inspector NAMES the rung — the drive this rock wants, not 'you need a better pick'")
	_check(str(panel.get("mode", "")).findn("tier 2") >= 0,
		"…with the tier, so the ladder is legible and not just the next purchase")
	_check(_main._hud._flash_text == "",
		"…and nothing shouts it a second time — two panels saying one sentence is noise")
	# The drive the inspector names is the drive that actually opens the rock: asserted, not assumed.
	_sim.inventory[&"stone_pickaxe"] = 1
	_check(MiningRules.can_mine(&"deepslate", _sim.inventory),
		"…and owning the named drive is exactly what makes the rock give")
	_sim.inventory.erase(&"stone_pickaxe")


## THE OTHER REFUSAL. The Wedge splits along the grain and does nothing whatsoever across it: a different
## no, wanting a different answer. "You need a better pick" would be a lie: the pick is fine, the ANGLE is
## wrong, and the tell has to say so.
func _the_wedge_refusal() -> void:
	var face: Vector2i = _pocket(&"stone")
	_sim.inventory[BitRules.WEDGE] = 1
	var slots: Array[Dictionary] = _sim.inventory_slots()
	for i: int in slots.size():
		if slots[i]["item"] == BitRules.WEDGE:
			_main._inv_selected = i
	var across: Vector2i = face
	var found: bool = false
	for dy: int in range(-2, 3):                                  # find a cell whose grain the swing crosses
		var c: Vector2i = face + Vector2i(0, dy)
		if _sim.is_solid(c) and _main._refuses(c):
			across = c
			found = true
			break
	_check(found, "with a Wedge equipped there is rock in reach it will not split")
	if not found:
		return
	_check(MiningRules.can_mine(_sim.material_at(across), _sim.inventory),
		"…and it is NOT a tier problem — the drive is perfectly good for this rock")
	_main._hud._flash_text = ""
	_main._skid_tell = 0.0
	_main._skid_clock = MainView.SKID_PERIOD
	_main._skid(across, 0.05)
	print("  the wedge refusal said: %s" % _main._hud._flash_text)
	_check(_main._hud._flash_text.findn("grain") >= 0 or _main._hud._flash_text.findn("seam") >= 0,
		"…so the tell names the GRAIN, not a pick you already have")
	_check(_main._hover_info_at(across).is_empty(),
		"…and it is the skid that has to say it: the inspector has nothing to add about rock you CAN mine")
	# Once, then quiet; nagging on every swing would train you to ignore the one message that matters.
	_main._hud._flash_text = ""
	for _i: int in 10:
		_main._skid_clock = MainView.SKID_PERIOD
		_main._skid(across, 0.05)
	_check(_main._hud._flash_text == "", "…said once, then quiet while the tell is still warm")
	_main._skid_clock = MainView.SKID_PERIOD
	_main._skid(across, MainView.SKID_TELL_COOLDOWN)
	_check(_main._hud._flash_text != "", "…and said again once you have been away long enough to forget")
	_sim.inventory.erase(BitRules.WEDGE)
	_main._inv_selected = 0


## AND IT SHUTS UP WHERE THE PICK WORKS. A tell that fires on ordinary rock is noise, and noise is worse
## than silence. Driven through the real loop: a held press whose aim is NOT a refusal must never skid.
func _it_shuts_up_where_the_pick_works() -> void:
	var stone: Vector2i = _pocket(&"stone")
	_check(not _main._refuses(stone), "rock the pick can take is not a refusal")
	Input.action_press(Controls.MINE)
	for _i: int in 40:
		_main._update_mining(0.05)
	Input.action_release(Controls.MINE)
	_check(_main._skid_tell == 0.0, "…so holding LMB through the real loop never skids on it")
	_check(_main._hud._flash_text == "", "…and never lectures you about a drive you already have")
