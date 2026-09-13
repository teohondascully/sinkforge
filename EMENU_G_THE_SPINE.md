# SINKFORGE — E-menu proposal G: THE SPINE (at scale)

Generate ONE image, 1920 x 1080, a game interface mockup. Not a collage, not a storyboard.

This is a visual design study for a game menu. The quantities below are a fixture for the drawing.

## The game in four lines

Sinkforge is a side-on pixel-art excavation and factory game. A field engineer digs beneath a permanent
surface rig. Gravity carries goods down the passages the player cuts: the hole is a conveyor. Machines
process and lift material, and the rig issues orders for processed goods.

## The idea this image is testing

**This factory has five hundred working machines spread over three hundred and eighty metres of shaft,
and the interface never draws a diagram of it.**

Instead it uses the one coordinate a vertical game always has. A narrow strip down the right edge is
indexed by depth, not by machine, so it stays the same size whether the factory has six machines or
five hundred. Each twenty-metre band aggregates what lives in it: a count, and the colour of the worst
lamp in that band. The player does not need to see the network. They need to know which band is red.

## Layout

**The world fills the frame**, undimmed and fully rendered: a side-on pixel-art cross-section of one
region of a very large factory, spanning roughly minus 190 to minus 245 metres. The engineer stands at
minus 212 metres. This is a dense, built-out stretch: machines packed along both walls, chutes crossing,
conduit running between them, several machines working with green lamps, one burning red nearby. The
frame should feel like a small window onto something much larger in both directions.

**Along the bottom, two rows of wells with the load beneath them.**

FREIGHT: five square wells, keybind digits 1 to 5, each with its drawn silhouette and count. Beneath
them a horizontal load bar filled to 71 of 90 — and the bar is **stratified**: each freight item holds
its own segment of the fill, sized by its contribution and painted in that item's own ink, so the bar
is also the list.

KIT: five square wells, digits 6 to 0, below a hairline, with a small "no load" beside them. All ten
slots are full, which is the point: the pack is capped whatever the factory does.

**Above the selected well**, one compact card: Gear Mill, "Iron ingot and ingot to 1 Gear", and one
filled brass button reading **Place in shaft**.

**Down the right edge, the spine — about 10 percent of the width and the full height.**

A vertical depth scale from 0 at the top to minus 380 at the bottom, divided into nineteen bands of
twenty metres. Each band is a short horizontal cell carrying two things: a small count of the machines
in it, and a fill in the colour of the worst lamp among them. Most bands are quiet green or grey.
**Three bands are red** — at minus 140, minus 220 and minus 300 — and **one is amber**, at minus 60.

A brass caret sits at minus 212, marking where the engineer is.

**One band is open.** The minus 140 band has expanded into a short list of six machine names, each with
its own small lamp colour beside it, one of them red. This is how the player reaches a machine: find
the red band, open it, choose.

At the very top of the spine, above the depth scale, the current order as six pips: three filled solid,
two ringed hollow, one empty.

## The fixture

FREIGHT, 71 of 90 carried: Coal 22 · Steel plate 18 · Iron ingot 16 · Copper ore 14 · Glimmer 1
KIT, free: Conduit 12 · Torch 6 · Rope 3 · Plate Press 1 · Gear Mill 1

Gear Mill is the selected well, lit brass.

The coal well wears a small red upward triangle in its top-right corner. In this game a starving machine
wears that triangle and the stack that would feed it wears the same glyph in the same colour. The red
band at minus 220 in the spine is the one asking, and a machine just below the engineer in the world is
burning the same red — so the pack, the world and the spine all say it at once.

## Palette and rendering

Rock at this depth reads cool grey-blue with warm ore seams, near black in dug space, with torch pools
and machine lamps throwing colour.

Interface ground #12141D, wells #1C1F29, edges #333B4D with a #8594AD top bevel so panels read as
raised. Brass accent #CCA84D. Text #CCD4E3, dim #8A94A8, faint #808A9E.

Item inks: coal #3D404A · steel plate #A8B5CC · iron ingot #CCD6EB · copper ore #E0853D · glimmer
#3DC7D2 · conduit #A8784D · rope #C7A870 · torch #FFC25C.

Machine lamps: starved of fuel #F54233, starved of input #F7B838, working #59EB6B, idle #858C9E,
no power #5CD6FA.

The game authors its interface on a 640 x 360 grid and presents it at 2x. Keep every interface element
small, crisp and on-grid, with tabular figures. The world is the large thing in this image, and the
spine is narrow.

Show the screen at rest, settled and sharp.
