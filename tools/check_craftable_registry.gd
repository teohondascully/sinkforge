extends "res://tools/check_base.gd"

## CONTRACT GUARD — every research-unlockable MACHINE is reachable in real play.
##
## The bug class this kills (hit for real with the pump): a machine can have its `.tres`, a sim behavior,
## a Visuals.MACHINE_STYLE glyph, AND a ResearchRules unlock — yet be MISSING from MainView._craftable,
## the ONE list that feeds both the Bazaar craft menu (craft_ids) AND the item->def resolver that lets a
## carried machine be PLACED (_machine_defs_by_id). Miss it there and a player who researches the tech
## still can't craft or place the machine: the whole feature is unreachable. Only a RUNG play-goal that
## exercises that exact machine catches it today; this is the cheap BROAD guard.
##
## Assert: for EVERY machine id any tech in ResearchRules can unlock, that id is registered in the LIVE
## MainView._craftable (== resolvable by _machine_defs_by_id). TOOL/equipment unlocks (pickaxes, scanner)
## are crafted but never PLACED as machines, so they're EXCLUDED — identified by MiningRules.is_tool_item.
##
## _craftable is instance state built in MainView._ready (a hardcoded load() array), so the LIVE list is
## the ground truth — we boot the real scene headlessly (mirroring tools/check_mining.gd) and read it,
## rather than re-deriving it (a re-derivation could agree with itself while the controller is missing the
## entry — the exact drift this guards against).
##
## Run: godot --headless --path . --script res://tools/check_craftable_registry.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== craftable registry contract ==")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	# Wait for MainView._ready to have populated _craftable (mirrors check_mining's 3-frame settle).
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_run()
	if _failures == 0:
		print("ALL CRAFTABLE-REGISTRY CHECKS PASS")
		quit(0)
	else:
		printerr("%d CRAFTABLE-REGISTRY FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	# The LIVE controller registry: the ids MainView will actually craft/place. Read from the real _ready'd
	# instance, not re-derived, so a missing entry is genuinely visible.
	var registered: Dictionary = {}
	for def: MachineDef in _main._craftable:
		registered[def.id] = true
	# Sanity: the resolver the placement path uses agrees with the list (they're built from the same array).
	_check(_main._machine_defs_by_id.size() == _main._craftable.size(),
		"_machine_defs_by_id resolves every _craftable entry (%d)" % _main._craftable.size())
	_check(registered.size() > 0, "_craftable is populated (%d machines)" % registered.size())

	# The guard: walk EVERY tech's unlocks. A machine unlock MUST be registered; a tool/equipment unlock is
	# excluded (crafted at the Bazaar but never placed as a machine — pickaxes, scanner).
	var checked: int = 0
	for tid: StringName in ResearchRules.TECHS:
		var tech: Dictionary = ResearchRules.TECHS[tid]
		for uid: StringName in (tech["unlocks"] as Array):
			if MiningRules.is_tool_item(uid):
				continue  # tool/equipment — never PLACED, so absence from _craftable is correct
			checked += 1
			_check(registered.has(uid),
				"'%s' (unlocked by %s) is registered in MainView._craftable — researchable AND placeable" % [uid, tid])
	_check(checked > 0, "the guard actually walked machine unlocks (%d checked)" % checked)

	# ------------------------------------------------------------------------------------------------
	# AND THE OTHER WAY IN. `try_build` (main.gd) picks a placed machine back UP — it gates on reach and
	# on there BEING a machine in the cell, not on whether that machine is craftable and not on whether
	# you placed it. So `pickup_machine` (factory_sim.gd) can put ANY placed def's id into the pack, by a
	# route that never touches `_craftable`.
	#
	# `Hud.machine_icons` is built by iterating `_craftable` (main.gd), and `_draw_thing_icon` sends
	# anything absent from it to `Visuals.draw_item`, whose default arm fills a flat rect with
	# `item_color` — last line `return Color.WHITE`. A machine that reaches the pack without a craft path
	# therefore draws as a blank white square, which is a failure mode this project has already shipped
	# once (the carried terrain blocks).
	#
	# It is not reachable today, and the reason is worth writing down because it is NOT the one I first
	# gave: it is not that nothing crafts these defs, it is that nothing PLACES them. `world_seeder`
	# seeds exactly one machine def and it is a craftable one. That is a worldgen fact, not an icon fact,
	# and it can change in a commit that has nothing to do with icons.
	#
	# So the assertion is tied to what the world ACTUALLY placed, read off the booted sim rather than
	# parsed out of the seeder: every machine standing in a fresh world must be one the pack can draw.
	var placed: Dictionary = {}
	for st: MachineState in _main.sim.machines:
		if st != null and st.def != null:
			placed[st.def.id] = true
	var iconless: Array[String] = []
	for id: StringName in placed:
		if not _main._hud.machine_icons.has(id):
			iconless.append(String(id))
	_check(iconless.is_empty(),
		"every one of the %d machine kinds the world placed can be drawn in the pack if you pick it up%s"
			% [placed.size(), "" if iconless.is_empty() else " — NO ICON (draws as a white square): "
				+ ", ".join(iconless)])
	# NON-VACUITY: a world with no machines in it satisfies the above perfectly, and a fresh save that
	# seeds nothing would be its own, larger finding.
	_check(placed.size() > 0, "the fresh world placed %d machine kinds to check" % placed.size())
	# CONTROL: an id the registry certainly does not carry, through the same predicate.
	_check(not _main._hud.machine_icons.has(&"not_a_real_machine"),
		"the same lookup rejects an id that was never registered")
