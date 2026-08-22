class_name BazaarCatalogue
extends RefCounted

## WHAT THE COUNTER HAS ON OFFER, and which of it you are allowed to buy today.
##
## `scenes/main.gd` fills the four lists and the counter reads them. They are separated into ids and
## options so that machines and tools can interleave in one column without depending on the insertion
## order of a Dictionary.
##
## This is model, not drawing, so it sits beside `BazaarCosts` rather than under `PageSurface`. It was
## lifted out because the shell and the WORKS tab both query it, and once a tab is a file of its own a
## query it shares with the shell cannot live in the page without the tab reaching back into its owner.


## The sim the locks are read against, and the face table `_craft_id` falls back to.
var _sim: FactorySim = null
var _icons: Dictionary = {}

## Filled by `scenes/main.gd` through the Hud and the page, both of which keep a property of each name.
var craft_ids: Array[StringName] = []
var craft_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
var rack_options: Array[Dictionary] = []


func open_machines() -> Array[int]:
	return _unlocked(craft_ids, craft_options.size())


func open_rack() -> Array[int]:
	return _unlocked(rack_ids, rack_options.size())


## The id of the i-th craftable, supplied explicitly by MainView as `craft_ids`, parallel to
## `craft_options`, so machines and tools can interleave without relying on `_icons` insertion
## order. It falls back to the old `_icons`-keys derivation if `craft_ids` was not set.
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = _icons.keys()
	return keys[i] if i < keys.size() else &""


## What the counter will sell you today: the indices of the rows whose tech is already yours.
##
## WORKS used to list the whole catalogue, sixteen machines deep with thirteen greyed out behind techs
## you had not reached, which is a wall of things you cannot have in the place you go to get things. The
## future has a home already: the BENCH, where every locked machine sits under the rung that unlocks it.
func _unlocked(ids: Array[StringName], n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		var id: StringName = ids[i] if i < ids.size() else &""
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock == &"" or _sim.is_researched(lock):
			out.append(i)
	return out