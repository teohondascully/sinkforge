# SINKFORGE — E-menu proposal D: THE SLATE

Generate ONE image, 1920 x 1080, a game interface mockup. Not a collage, not a storyboard.

This is a visual design study for a game menu. The quantities below are a fixture for the drawing.

## The game in four lines

Sinkforge is a side-on pixel-art excavation and factory game. A field engineer digs beneath a permanent
surface rig. Gravity carries goods down the passages the player cuts: the hole is a conveyor. Machines
process and lift material, and the rig issues orders for processed goods.

## The idea this image is testing

No paper. No notebook. The menu is the game's own heads-up display, grown larger. Same palette, same
raised dark panels, same square wells, same drawn item silhouettes the player already learned from the
hotbar. The player never changes rendering worlds when they press E.

This is the conservative proposal, and it exists so we can see what we give up by leaving the shipped
identity behind.

## Layout

A single raised panel filling about 80 percent of the screen width and 76 percent of its height, with
the dimmed pixel-art shaft visible around it.

**Left half, two well-grids.**

FREIGHT: five square wells in a row, each with the item's drawn silhouette, its count on a small dark
corner plate, and its keybind digit top-left. Directly under the row, a horizontal brass load bar
running the full width of the group, filled to 48 of 90, with the figure at its right end.

KIT: three square wells in a second row below a hairline. No bar under them. A small label beside the
row reading "no load".

**Under the grids, the selected item.** Plate Press: the machine's own drawn silhouette at larger size,
its name, "2 Iron ingots to 1 Plate", and one filled brass button reading **Place in shaft** with a
clear focus ring.

**Right half, the shaft.** Rendered as the game's own world, not as a line drawing: actual terrain
colours, actual machine sprites, dug space near black, machines lit by their own lamps, seen as a dim
cutaway. Depths in small brass figures down a ruled left margin. The engineer stands on it at minus 20
metres.

**Under the shaft, two compact rows.** The order as six brass pips, two filled solid, three ringed
hollow, one empty, beside "Ingots for the winch". And beside that, small, the glimmer with "Kept it
anyway."

**The live mark:** the Processor at minus 24 metres burns red in the cutaway, and the coal well in the
freight row wears the same small red upward triangle in its top-right corner. Same glyph, same colour,
two places.

## The fixture

FREIGHT, 48 of 90 carried: Clay 24 · Coal 12 · Iron-bearing ore 8 · Iron ingot 3 · Glimmer 1
KIT, free: Torch 4 · Rope 2 · Plate Press 1

Eight wells, keybind digits 1 to 8. Well 5 is the Plate Press and it is the lit one: a brass border and
a faint brass wash behind it.

## The shaft, drawn the same way in every proposal

Surface rig at top right with a Winch Station beside it. Drill at minus 12 metres on the left. An
excavated ore chute descends from the Drill, bending twice, widening into a collection cavity above the
Processor at minus 24 metres. A Coal Hopper at minus 18 metres sits right of the ore chute and sends a
separate coal chute down to meet the Processor's intake at a marked junction. The Processor's output
descends right to a Winch Head at minus 28 metres. A powered return climbs the right-hand side from the
Winch Head to the Winch Station. A dotted route leaves the Winch Station and arrives at the Surface Rig,
labelled "Carry to rig", the one leg the engineer walks.

## Palette and rendering — these are the game's shipped values, use them exactly

Panel ground #12141D. Modal ground #101218. Slot well #1C1F29. Rail #0B0C12.
Panel edge #333B4D, with a #8594AD top bevel so every panel reads as raised rather than outlined.
Brass accent #CCA84D. Warn #F5754D.
Text #CCD4E3. Dim #8A94A8. Faint #808A9E.

Item inks: clay #AD7A4F · coal #3D404A · iron-bearing ore #6B7A9E · iron ingot #CCD6EB · glimmer
#3DC7D2 · rope #C7A870 · torch #FFC25C · plate #A8B5CC.

Machine lamps: starved of fuel #F54233, starved of input #F7B838, working #59EB6B, idle #858C9E.

Item icons are flat drawn silhouettes, readable at 16 pixels tall, distinguished by shape before colour:
coal a dark faceted lump, clay a rounded brick, ore a speckled chunk, ingot a bar, glimmer a crystal
cluster, rope a coil, torch a flame on a stick, plate press a low machine on legs.

The game authors its interface on a 640 x 360 grid and presents it at 2x. Draw on that grid: crisp
on-pixel edges, 1-pixel hairlines at authored scale, small confident type with tabular figures.

Show the screen at rest, settled and sharp.
