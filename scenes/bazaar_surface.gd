class_name BazaarSurface
extends PageSurface

## WHAT EVERY PART OF THE COUNTER NEEDS: the sim it is reporting on, and the three questions all of its
## tabs ask about a thing.
##
## `PageSurface` underneath holds what any page needs to draw at all — the canvas, the font, the probe,
## the rounded plates. This layer is the counter's own: the tabs share a sim and a table of faces, and
## the moment one of them became a file of its own it had to write both out again for itself.
##
## Only what is actually shared lives here. Measured over the tabs, `_draw_thing_icon` is called from all
## of them, `_item_label` from two, and `_cost_numeral` from two. The plate's own fabric — the lamp, the
## glyph inset, the verb button — is called from the detail plate and the shell and nowhere else, so it
## stays with them rather than being promoted to a base on the strength of sounding general.


## The sim every tab reports on, and the machine-icon table, both handed down from the Hud.
var _sim: FactorySim = null
var _icons: Dictionary = {}                 ## `Hud.machine_icons`, assembled by `main.gd`


## A thing drawn in a box, from the table above.
func _draw_thing_icon(id: StringName, box: Rect2) -> void:
	Visuals.thing_icon(_canvas, id, box, _icons)


## What a thing is called.
func _item_label(item: StringName) -> String:
	return Visuals.thing_label(item, _icons)


## What one ingredient's numeral says: the deficit when you are short of it, the price when you are not.
##
## It is a function and not an expression because the width pass and the draw pass are two walks of the
## same dictionary, and they used to each format the numeral for themselves. The width is not cosmetic
## here: `_works_row` subtracts this function's total from the name's budget, so a numeral that measures
## narrower than it draws puts the price on top of the word it was widened to protect.
func _cost_numeral(item: StringName, need: int) -> String:
	var gap: int = BazaarCosts.gap(_sim.inventory, item, need)
	return ("-%d" % gap) if gap > 0 else str(need)
