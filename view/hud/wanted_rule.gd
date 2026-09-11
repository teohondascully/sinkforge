class_name WantedRule
extends RefCounted

## WHICH THING IN YOUR PACK A MACHINE IN SIGHT IS ASKING FOR (item 41, D0592).
##
## Both halves of this were already drawn and neither knew about the other. A stalled machine floats a
## gold need bubble with the item inside it (`MachinePainter._draw_status` -> `need_item`), and the pack
## draws every stack you carry (`Hotbar`), and a player holding coal beside a red forge had to make the
## join themselves. `docs/WORKING.md` item 41: "Both are drawn; nothing connects them."
##
## THE ANSWER IS ONE GLYPH IN TWO PLACES, not a new piece of language. The machine already wears
## `StatusLook`'s `feed` mark -- a triangle pointing UP, at the bubble it is asking for -- so the slot
## holding what it wants wears the same mark in the same lamp colour. Nothing here invents a vocabulary;
## it repeats the machine's, which is what makes the two read as one statement.
##
## AND IT IS NOT COLOUR ALONE, deliberately, on `StatusLook`'s own finding: "green working against red
## no-fuel is the single most common colour confusion there is, with amber starved joining them; for a
## deuteranope those three lamps were one lamp." A slot that only changed colour would reintroduce
## exactly that. The mark is the channel; the colour agrees with it.
##
## THE GATE IS `feeds`, NOT `wants_bubble`. `BubbleRule.wants_bubble` is true for `no_power`, `blocked`
## and `unlinked` too, and none of those is answered by an item in your pack -- walking over with coal
## fixes nothing. `StatusLook`'s table already carries the distinction as `feeds`: "whether a floating
## need bubble, which can ONLY draw an item, can tell the truth about this status". So that field decides
## it, rather than a second list here that could come to disagree with it.
##
## THE POPULATION IS THE OBSERVATION'S MACHINES, which is windowed to roughly what is on screen
## (`WorldView.WINDOW_MARGIN_CELLS` past the view). That is the honest reading of "in sight" available
## without a second search, and it errs toward marking a machine just off the edge rather than missing
## one just inside it -- the cheaper mistake, because the fix is to walk a little further.


## Item id -> the status of a machine asking for it. Empty when nothing in sight wants anything.
## A status wins over another for the same item only by being found first; they draw the same mark, and
## the colours differ only between `no_fuel` (red) and `no_input` (amber), which is a distinction about
## the MACHINE and not about the stack you are carrying.
static func wanted(o: Interface.Observation) -> Dictionary:
	var out: Dictionary = {}
	if o == null:
		return out
	for rec: Dictionary in o.machines:
		var status: StringName = StringName(rec.get("status", &"idle"))
		if not bool(StatusLook.of(status).get("feeds", false)):
			continue
		var item: StringName = MachinePainter.need_item(rec)
		if item != &"" and not out.has(item):
			out[item] = status
	return out


## The lamp colour for a marked slot: the machine's own, so the slot and the machine agree on sight.
static func tint(status: StringName) -> Color:
	return StatusLook.of(status)["color"]
