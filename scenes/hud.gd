class_name Hud
extends Node2D

## Screen-fixed HUD. Lives under a CanvasLayer so the follow-camera does NOT scroll it. Reads the sim
## only (OUTPUT total + the carried inventory) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
## WHERE THE BOTTOM FURNITURE STARTS, in canvas space, as ONE definition rather than two.
##
## `_draw_inventory` derives the bar's y from these; anything outside the HUD that needs to know where the
## furniture begins should read `bottom_furniture_fraction()` rather than carry its own number. It exists
## because `check_opening.gd` carries `HUD_BOTTOM = 0.20` — a hardcoded guess at this band, with nothing
## tying it to the HUD. The real band starts at 295/360 = 0.819, so that layer currently excludes about
## eight percent of the frame as "HUD" while it is ground, and if this bar ever moves the layer will keep
## excluding the rectangle where it used to be, silently, with no assertion anywhere that would notice.
## Whether to adopt the derived figure is a calibration decision for that layer's owner — the number
## changes what it judges — so this only makes the truth readable from outside.
const HOTBAR_BAND_TOP: float = CANVAS.y - 28.0 - SLOT - 7.0
const HOTBAR_BAND_H: float = SLOT + 14.0


## The fraction of the canvas ABOVE the bottom furniture — i.e. the last row that is still world.
static func bottom_furniture_fraction() -> float:
	return HOTBAR_BAND_TOP / CANVAS.y
const MINI_W: float = 150.0     ## minimap BOX in the top-right corner; the world fits inside it,
const MINI_H: float = 116.0     ## ...whatever shape the world happens to be
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

## --- UI skin palette (one cohesive theme so the HUD reads as designed, not flat code-drawn) -------
##
## THE FOCAL HIERARCHY (#A3). The HUD used to hold the two brightest values in the frame — a near-white
## text and a near-fluorescent gold — which inverted the whole image: the eye was pulled to the chrome
## and away from the play space, and the world it left behind was a same-value jumble by comparison.
## That is a large part of what "it hurts my eyes to play" was pointing at. Both are stepped down here.
## The HUD is still perfectly readable against its own near-black panels (it always had the contrast to
## spare); it simply stops competing with the world for first look. Nothing in the UI should ever be
## brighter than lit rock.
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight → panels read as raised
## **GOLD NEVER LABELS AND NEVER COUNTS.** The first step of `MNU-06` ("reassign gold to a single semantic
## meaning"), taken as a rule rather than as nine separate opinions, and deliberately the smallest step that
## is a rule at all: the nine sites where the accent was pure INFORMATION — three headings, three headline
## numbers, two mode chips and the off-screen-more mark — now draw in text colours. Gold is left on every
## site where the player's input is connected to the thing: the selection, the verb that acts on it, the
## next available research node, an engaged control.
##
## What this does NOT do is split the remaining twenty into named roles. Nine constants resolving to the
## same gold would document the ambiguity and change nothing a player sees, and the pair a naive split
## would separate — the selected row's spine and the button that acts on it — is the one place the doubling
## CARRIES meaning. Splitting it is a separate decision from this one, and it is not this one to make.
##
## GOLD, AND IT MEANT NINE THINGS. Counted from source rather than from this comment, which used to read
## "(FORGED, selected slot, current step)" — three examples standing in for a definition, and the three it
## happened to name are three DIFFERENT roles. Full enumeration with call sites in `docs/MENU_MATRIX.md`.
## Eight of the nine are all "look here" and cost nothing but precision. The ninth was a contradiction: the
## dashboard drew a machine's stalled count in it, so gold meant "something is wrong" on the one screen
## where it also meant "this is the total you are producing" — see UI_WARN, which the game already had.
const UI_ACCENT := Color(0.80, 0.66, 0.30)           ## gold accent — selection, the live verb, the next step
## The colour the alert stack has always used for a machine in trouble. Named so that the OTHER place which
## reports the same fact can say it the same way, instead of reaching for the accent and inverting it.
const UI_WARN := Color(0.96, 0.46, 0.30)
const UI_TEXT := Color(0.80, 0.83, 0.89)
const UI_TEXT_DIM := Color(0.54, 0.58, 0.66)
const UI_SLOT := Color(0.11, 0.12, 0.16, 0.95)       ## empty hotbar slot well

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## Fast-forward game clock (set by MainView). >1 draws a small "▶▶ Nx" chip top-left so you know the
## world is running fast; 1.0 draws nothing (the calm-screen default).
var time_scale: float = 1.0
## The tutorial chain (representation-layer legibility — answers "how do I play?"). Set by MainView.
var objectives: Objectives
## Craftable machines for the CRAFT strip (set by MainView): [{name: String, cost: {item->count}}].
var craft_options: Array[Dictionary] = []
## Machine item id -> {color: Color, tag: String}, so machine items in the hotbar read as machines.
var machine_icons: Dictionary = {}
## The item id per craft row (parallel to craft_options), set by MainView — machines then tools. Lets the
## craft panel render a machine (casing + glyph) or a tool (item glyph) per row without a fragile
## insertion-order dependency between two structures.
var craft_ids: Array[StringName] = []
## The active carried-item slot in the inventory hotbar (set by MainView; mouse-wheel cycles it).
var inv_selected_getter: Callable
## When you aim at one of your machines in reach, MainView pushes its inspector info here (name, recipe
## in→out, routing mode, what it's holding). Empty = nothing hovered. Drawn top-right under FORGED.
var hover_info: Dictionary = {}
var _hover_rect: Rect2 = Rect2()          ## the inspector's canvas rect this frame (#32 — pin region)
var _knob_hits: Array[Dictionary] = []    ## clickable knob chips this frame: [{rect, payload}]
## FACTORY ALERTS: stalled machines from sim.machine_problems(), pushed each frame.
## A compact LEFT-edge stack that appears ONLY when something's stuck (calm-by-default), each row
## clickable to ping the culprit. _alert_hits = this frame's clickable rects [{rect, cell}].
var alerts: Array[Dictionary] = []
var _alert_hits: Array[Dictionary] = []
const ALERT_REASON: Dictionary = {
	&"blocked": "output blocked — dig a drain",
	&"no_fuel": "out of coal — feed it",
	&"no_input": "starved — nothing feeding it",
	# The Drift Rig has TWO outputs, so "output blocked" is not an answer to anything — it has to say which
	# column jammed, because the two are dug in different places (docs/DRIFT.md §7).
	&"blocked_pay": "ore column jammed — dig a drain UNDER it",
	&"blocked_spoil": "spoil column jammed — dig a drain BEHIND it",
	&"no_power": "no power — it eats a network, not a coal box",
	# SPENT is not STARVED. A Head that has finished its vein has nothing wrong with it, and telling the
	# player it is "starved" sends them hunting for a feed problem that does not exist (`docs/LODE.md` §5).
	&"spent": "the vein is worked out — pick it up and move it",
	&"unlinked": "nothing to feed — a Spur must touch a Drill, or a Spur that reaches one",
}
## THE TITLE / NEW-GAME card (#6 + #45): {} = closed; else {seed, tint, tint_name, tints, has_save}.
var title_info: Dictionary = {}
## Minimap inputs (pushed by MainView): a material-id → colour lookup (the renderer's, handed over as a
## Callable so the HUD stays decoupled), the camera focus (player world pos) and the world-space view
## size, so the minimap can mark "you are here" + the visible window. The terrain image is cached and
## only rebuilt when you DIG (sim.solid changes), like the skylight veil.
var minimap_color: Callable
var minimap_focus: Vector2 = Vector2.ZERO
var minimap_view: Vector2 = Vector2.ZERO
var _minimap_tex: ImageTexture
var _minimap_solid_count: int = -1
const CELL: float = 32.0

## On-demand overlays (pushed by MainView each frame). The screen is calm by default: only the hotbar,
## a small FORGED chip, and the current-objective line are permanent. The crafting screen (E), the map
## (M), and the controls help (H/?) are summoned, so they never clutter the playfield.
var inventory_open: bool = false   ## E/T — THE BAZAAR panel is open (which TAB is `bazaar_tab`)
var can_craft: bool = false        ## are we near a claimed Bazaar? gates the VERBS, never the layout

## THE BAZAAR — one counter, three tabs (`docs/BAZAAR.md`).
##
## What this replaces: a 360-wide column on a 640x360 canvas that stacked the inventory grid, the craft list
## and the research bench on top of each other, ran out of room, and answered with a scrolling viewport and
## a scrollbar. Beside it, a SEPARATE full-screen tech overlay on `T` that drew the ladder you could not act
## on, because the research verb lived back in the pack screen. Look here, act there.
##
## Now it is one panel, always the same size, always the same three tabs, and it opens the same everywhere —
## including at the bottom of a shaft, where the whole point is that you can read every recipe and every tech
## price and plan the trip back. Away from a Bazaar the VERBS are dimmed and one line says where they live;
## nothing moves and nothing disappears. That is the fix for the panel that used to change shape depending on
## where you stood.
##
## NO SCROLLING VIEWPORT, and no dead space either. #S34 rebuilt the SURFACE on top of that shape: the rows
## became a dense card grid across three columns, and the space the old two-column layout wasted became a
## DETAIL PLATE along the bottom — the thing you are about to buy, drawn large enough to want, with its
## price and its verb in the same look. Twenty-one rows fit without scrolling; `check_pack_layout` asserts
## it rather than trusting it.
## THE COUNTER'S WIDTH, AND THE HEIGHT IT IS ALLOWED TO REACH — not the height it takes.
##
## 608x348 on a 640x360 canvas is 91.8% of the screen BY AREA, and T2.1's complaint was never that the panel
## is large but that it is large REGARDLESS: a fresh game's PACK tab holds one item and drew the same 92% as
## a finished game's nineteen-machine WORKS list. The counter now takes the height its ACTIVE TAB asks for
## (`_bazaar_wanted_h`), clamped between `BAZAAR_MIN_H` and this. A fresh PACK lands at 190 -- 50.1% of the
## canvas instead of 91.8% -- and BENCH still asks for more than this and still gets clamped to it, so the
## deep end of the game is unchanged.
##
## BOTH PERCENTAGES ARE AREA and neither is a height, which is worth one line because the two frames give
## different answers to the same question: as heights the same panels are 52.8% and 96.7% of the canvas.
## The 196 this paragraph used to name is not what a fresh PACK asks for: head 48 + one row of wells 46 +
## the gap 8 + the compact plate 72 + the foot 16 is 190. 196 was the clamp floor, which sat ten pixels
## below its own stated sum and so could never be the number that quoting it was meant to describe.
##
## THE WIDTH DOES NOT MOVE, deliberately. The detail plate along the bottom carries a machine's whole
## sentence ("breaks tier-1 rock (earth / stone / ore / coal) -- hold LMB"), and that is what the 528px of
## content width is bought for. Shrinking width to match one 46px well would trade a void for a truncation.
const BAZAAR_SIZE := Vector2(608.0, 348.0)
const PACK_CELL: float = 46.0         ## pitch of a pack well; the well itself is 6px smaller
const BAZAAR_RAIL: float = 56.0       ## the vertical tab rail down the left edge
const BAZAAR_PAD: float = 12.0
const BAZAAR_HEAD: float = 48.0       ## title + the carried-goods strip, with air under it
const BAZAAR_FOOT: float = 16.0       ## the key legend
## THE DETAIL PLATE IS THE HEIGHT OF WHAT IT DRAWS — and it draws two different things, so it has two
## heights and neither of them is written down.
##
## THE FULL PLATE, for a thing you are deciding whether to spend on. A lit square with the thing in it and,
## beside that, a title, a two-line blurb and a row of have/need price chips. The square is `DETAIL_ART` on
## a side with `DETAIL_PAD` of margin above and below it, which is the 88 exactly; the chips are the deepest
## thing in the text column beside it, starting 62 below the plate's top and standing 19 tall. So 81 of the
## 88 is spoken for and 78 of it by the square alone, and the two columns arrive at the same floor
## independently. Nothing here can be scaled: a coefficient in front of the 88 clips the chips off the
## bottom before it has taken a fifth of the height away.
##
## THE COMPACT PLATE, for a thing there is nothing to weigh. What is already in your pack has no price, and
## PACK's own summary of the line has no cost at all, so neither of them draws the chip row — and with the
## chips gone the deepest thing left is the last blurb line and one fact under it. That sum is
## `BAZAAR_DETAIL_MIN`, and the square is then whatever fits BESIDE it rather than the other way round,
## which is why `_draw_bazaar_detail` reads the square off the plate's rect instead of off `DETAIL_ART`.
## At both depths the plate and the square it holds are one number.
##
## THE SHARE THIS BUYS, AND WHY IT IS NEARLY ALL OF IT. The plate sits inside the height it is a share of:
## a fresh PACK is 118px of head, wells, gap and foot PLUS the plate, so the share is plate/(118+plate) and
## shrinking the plate shrinks the panel underneath it. 88 of 206 is 42.7% and 72 of 190 is 37.9%; the 25.3%
## the plate held when the panel was a fixed 348 would need a 40px plate, which is under half of what the
## compact plate has to draw. `check_pack_layout` floors the plate at 70px independently, so 37.2% is the
## whole of what this lever has ever been worth and the 2px between it and 72 is the margin on that floor.
const DETAIL_PAD: float = 10.0        ## plate edge to the art square, and the same again under it
const DETAIL_ART: float = 68.0        ## the lit square a thing on sale is drawn in
const BAZAAR_DETAIL: float = DETAIL_PAD * 2.0 + DETAIL_ART
## The lamp's rings and the thing inside them are sized off the SQUARE and not written down, because the
## square is no longer one size: an 8px step off a 34px radius spills over the edge of a compact plate's
## square, and a 44px glyph in it would have swallowed the rim the lamp needs to read against.
const DETAIL_GLYPH_INSET: float = 12.0  ## square edge to the thing in it
## Ring to ring, as a share of the square's radius rather than the 8px it is at the full depth.
const DETAIL_LAMP_STEP: float = 8.0 / (DETAIL_ART * 0.5)
## THE COMPACT PLATE'S TEXT COLUMN, which is the thing that sets its height. `DETAIL_LINE` is what the plate
## RESERVES per blurb line rather than what the face draws — `draw_multiline_string` takes its own pitch from
## the font, and the full plate already assumes no more than this by seating the chips 22px under a two-line
## blurb. The tail is for what hangs off the last baseline.
const DETAIL_BLURB_Y: float = 40.0    ## first blurb baseline, below the plate's top
const DETAIL_BLURB_LINES: int = 2     ## and what the blurb is allowed to wrap to
const DETAIL_LINE: float = 12.0       ## reserved per blurb line
const DETAIL_TAIL: float = 8.0        ## last baseline to the bottom of the plate
const DETAIL_FACT_Y: float = DETAIL_BLURB_Y + DETAIL_LINE * DETAIL_BLURB_LINES
const BAZAAR_DETAIL_MIN: float = DETAIL_FACT_Y + DETAIL_TAIL
const BAZAAR_DETAIL_GAP: float = 8.0  ## rows to plate: the body's one gap, named once for its three sites
## Head + one row of pack wells + the gap + the detail plate + the foot, ADDED UP rather than written down.
## It was a 196 sitting beside that same sentence, which sums to 206, so the floor was ten pixels below the
## shape it named and nothing in the file could notice. Below this the counter would be smaller than the
## thing it is a counter for.
##
## THE PLATE TERM IS THE COMPACT ONE, because this floor is PACK's floor and PACK never draws the other.
## While the plate had a single height the distinction did not exist. Now that it has two, a floor carrying
## the taller one would sit 16px above where a fresh pack's own sum lands, and `check_pack_layout` asserts
## that the fresh pack LANDS on this floor rather than being caught by it — an assertion that would still
## have gone green, on the clamp, saying nothing about the panel.
const BAZAAR_MIN_H: float = BAZAAR_HEAD + PACK_CELL + BAZAAR_DETAIL_GAP + BAZAAR_DETAIL_MIN + BAZAAR_FOOT
## ELEVATION, NOT A GOLD SLAB. The live tab on both rails used to be a filled brass-tinted tile AND an
## accent edge AND a lit glyph: three signals for one bit of state, and the tinted fill is the one that reads
## as a pressed button from a decade ago. This is a plain lift off the rail's own 0.043/0.049/0.070, so the
## brass is spent once, on the edge. Named because the bazaar rail and the settings rail were carrying the
## same literal separately and had no way to notice if one of them moved.
const RAIL_ON_FILL := Color(0.090, 0.100, 0.130)
const BAZAAR_GUTTER: float = 10.0
## 24 again, not the 22 the two-column layout needed: three columns of eight is twenty-four rows, so the row
## can afford the two pixels back and the type can breathe.
const BAZAAR_ROW_H: float = 24.0
const BAZAAR_COLS: int = 3
## How long the counter takes to arrive. Not decoration: a panel that appears fully formed in one frame is
## the single loudest thing separating a menu from an interface, and 0.13s of rise is cheaper than any art.
const BAZAAR_RISE: float = 0.13
const TAB_PACK: int = 0
const TAB_WORKS: int = 1
const TAB_BENCH: int = 2
const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]
var bazaar_tab: int = TAB_PACK
var _bazaar_t: float = 0.0            ## 0..1 open ease, driven in _process
var _bazaar_h: float = BAZAAR_SIZE.y  ## the height the counter is currently at, eased toward its tab's
## THE RACK — the shop half of WORKS. Set by MainView beside `craft_options`, same {name, cost} shape, with
## `rack_ids` parallel to it. Kept a SEPARATE list rather than appended to the craft list because the two
## columns mean different things: the left is what you build from your own materials, the right is what you
## buy with refined goods (`docs/BITS.md` §7), and a player should never have to work out which is which.
var rack_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
## The highlighted row on the active tab. One cursor for the whole panel: Enter acts on it, and what "acts"
## means is the tab's business — buy, craft, research.
var bazaar_row: int = 0
## ...and where that cursor was left on each of the other two, one slot per tab. The cursor is shared but
## the PLACE is not: walking down to the ninth machine on WORKS, checking what the ninth costs to research
## on BENCH and coming back put you at the top of the list again, and the wheel changes tab, so a glance
## sideways cost the whole walk. Kept here rather than as three cursors because everything that reads the
## selection (`bazaar_action`, the three tab painters, the detail plate) asks the one that is live.
var _bazaar_rows: PackedInt32Array = PackedInt32Array()
var show_minimap: bool = false
var minimap_large: bool = false    ## M cycles corner → LARGE (centred) → hidden
## True while a grapple line is on screen, hook in flight or anchored. MainView pushes it every frame.
## An arrival ceremony is held while this is set: the plate is centred on the body and the rope hangs
## through the same column, so the two cannot share a frame legibly.
var rope_active: bool = false
## The player's PING marker in world coords (Vector2.INF = none) — set by clicking the open map;
## MainView owns it and pushes it here + to the renderer (which draws the in-world beacon).
var ping_world: Vector2 = Vector2.INF
var show_help: bool = false
var show_dashboard: bool = false   ## G — the PRODUCTION DASHBOARD (throughput bars + factory census)
## THE SETTINGS page: ESC on a calm screen. Values are read straight off the Settings
## statics (representation reading representation); every control click returns a payload through
## settings_click() for MainView to act on — the HUD never touches InputMap, audio or the config file.
var settings_open: bool = false
var settings_capture: StringName = &""     ## the action awaiting its new key ("press a key…")
var _settings_hits: Array[Dictionary] = [] ## clickable controls this frame: [{rect, payload}]
var _slider_rects: Dictionary = {}         ## slider id -> its bar Rect2 this frame (drag support)
var settings_cat: int = CAT_AUDIO          ## which face of the page is open (the rail's selection)
var _set_h: float = SET_MIN_H              ## eased toward `_settings_wanted_h()`, like the counter
var _set_t: float = 0.0                    ## the page's own rise, 0..1 — drives the scrim AND the defocus
## The dashboard and the key list have no rise of their own to borrow, so they share one. Without it they
## were the two modals of four that left the world sharp behind them, which is the same complaint the
## settings page was fixed for.
var _plain_t: float = 0.0
var settings_row: int = 0                  ## the keyboard cursor on the binding list (`MNU-29a`)

## Transient toast ("SAVED" / "LOADED" / short notices) — set via flash(), fades out on its own.
var _flash_text: String = ""
var _flash_life: float = 0.0

## THE DESCENT readout + arrivals. `depth_row` is poked every frame by MainView; the arrival is a
## one-shot banner MainView fires when the body first crosses into a band it has not been in.
var depth_row: int = Strata.SURFACE_ROW
var _arrival_text: String = ""
var _arrival_kicker: String = ""
var _arrival_color: Color = Color.WHITE
var _arrival_life: float = 0.0
const ARRIVAL_HOLD: float = 3.4          ## total life of the banner, fade included

## The just-in-time HINT BUBBLE (pushed by MainView from the Hints tracker): a small
## speech bubble anchored NEAR THE BODY teaching a newly-acquired item's use. Empty text = none.
var hint_text: String = ""
var hint_anchor: Vector2 = Vector2.ZERO   ## canvas-space point the tail points at (above the head)
var hint_alpha: float = 0.0

## ITEM TOOLTIPS: hover a hotbar/pack slot → what this item is FOR. One line per id —
## the reference card behind the one-shot acquisition hints. Machines answer "what does placing it buy";
## resources answer "what wants this". Absent id = no purpose line (name + count still show).
const ITEM_PURPOSE: Dictionary = {
	&"ore": "smeltable — a Forge turns it into ingots (toss it in, Q)",
	&"ingot": "the L1 metal — pays for crafting, research, the Engine's toll",
	&"coal": "FUEL — generators, drills and borers burn it (drop it on them)",
	&"wood": "placeable block (RMB) — crafts ropes, torches, the Bazaar frame",
	&"stone": "placeable block — and the Stone Pickaxe's making",
	&"earth": "placeable block — plug a pit, bridge a gap",
	&"deepslate": "the deep rock — the sample that unlocks DESCENT research",
	&"gravel": "PACKED fill — the one block that doesn't weep when water leans on it",
	&"iron": "L2 ore — the Iron Forge smelts it into iron ingots",
	&"iron_ingot": "the L2 metal — plates, gears and the Iron Pickaxe",
	&"plate": "pressed iron sheet — the Borer's frame wants them",
	&"gear": "milled cog (iron + ingot) — the Borer's works want them",
	&"wood_pickaxe": "breaks tier-1 rock (earth · stone · ore · coal) — hold LMB",
	&"stone_pickaxe": "tier-2 pick — opens deepslate, iron and rich ore. A key, not a stat",
	&"iron_pickaxe": "tier-3 pick — the deepest key on the ladder, for what waits under L2",
	&"wood_axe": "an old hatchet — your pick chops trees now; this is a keepsake",
	&"sapling": "RMB plants it on grassy ground — a new tree grows (renewable wood)",
	&"rich_ore": "high-grade ore from the deep shelf — a Blast Furnace pours 2 ingots from 1",
	&"shale": "placeable block — the banded rock of the middle band; nothing is made from it yet",
	# THE RACK'S FOUR CUTTING HEADS, which had no sentence at all until the menu matrix photographed one.
	# Each line is the bit's OWN entry in `BitRules.BIT` said in the second person — `keeps: false` is why
	# the Broad's says nothing reaches your pack, `recovery: 0.85` is the Lance's long pause, and
	# `grain_only: true` is why the Wedge does nothing across the grain. The icons already say this in
	# silhouette (`Visuals._item_bit`); the plate that exists to explain the selected thing said "—".
	&"broad_bit": "2x2 head — but it PULVERISES: nothing it breaks reaches your pack. Rooms, never veins",
	&"sinker_bit": "sinks three cells straight down, walls untouched — the clean 1-wide shaft",
	&"lance_bit": "drives five the way you face, then a long recovery — a commitment, not a rhythm",
	&"wedge_bit": "splits eight ALONG a seam — and does nothing whatsoever across the grain",
	&"blast_furnace": "smelts RICH ore 1 → 2 ingots — the deep veins' payoff",
	&"scanner": "sonar — select it, RMB pulses: nearby veins echo through the rock",
	&"rope": "RMB above a drop — it unrolls down; W/S climbs it",
	&"torch": "RMB on a wall-backed cell — light that STAYS",
	&"conduit": "RMB lays power tube — power flows down + sideways, never up",
	&"processor": "the Forge — smelts what falls into it (ore → ingots)",
	&"splitter": "routes falling items DOWN + RIGHT (aim R at it: ratio)",
	&"spur": "one more mouth on a Head — reaches across a vein the drill alone cannot (it says 'unlinked' if it reaches nothing)",
	&"pump": "POWERED, it drains water from its own cell and the ones below — the way back out of a flood",
	&"lift": "hauls goods — and YOU — up its column; power multiplies it",
	&"drill": "bores straight down through an ore vein — burns coal",
	&"hopper": "banks what falls in, meters it DOWN — keeps the first item it tastes",
	&"generator": "burns coal into POWER for the machines around it",
	&"descent_engine": "stand it ON the seal, feed it ingots — it breaches the way down",
	&"iron_forge": "smelts iron ore into iron ingots (the L2 chain's base)",
	&"plate_press": "presses iron ingots into plates",
	&"gear_mill": "mills iron ingots + ingots into gears (two inputs, one column)",
	&"h_drill": "the Borer — chews sideways the way you faced; its haul drops below it",
	&"drift_rig": "cuts a 2-high gallery on POWER, and sorts it: ore drops below, spoil drops behind",
	&"crusher": "eats SPOIL, pours GRAVEL — pay falls straight through it, untouched",
}
## The hovered slot this frame (captured while drawing the hotbar/pack grid, drawn last, on top).
var _tooltip_item: StringName = &""
var _tooltip_count: int = 0
var _tooltip_anchor: Vector2 = Vector2.ZERO   ## top-centre of the hovered slot


## Show a short transient notice centred under the objective banner (~2s, fades).
func flash(text: String) -> void:
	_flash_text = text
	_flash_life = 2.2


## Announce arrival in a new stratum — the one moment the descent gets to be an EVENT.
##
## HELD, NOT DROPPED, WHILE THE BIG MAP IS UP. The plate is centred at y ~62..112 and the large map's panel
## spans 181..459 by 41..319, so an arrival crossed with the map open lands squarely inside it — measured
## overlap 222x50, held by `check_hud_layout`. The other three elements that collide with that map (the
## goal plate :699, the pack bar :2290, the inspector :812) simply stand down, because they are PERSISTENT
## and standing down costs nothing: they come back. This one is a ONE-SHOT with a 3.4s life, so standing it
## down would not compose it safely, it would delete it — you would cross into THE DEEPSLATE and never be
## told. T2.1 asks for "announce once, in a safe composition", and dropping the announcement is not a
## composition. So it waits for the map to close and then fires in full.
func announce(text: String, kicker: String, color: Color) -> void:
	if _announce_held():
		_pending_arrival = [text, kicker, color]
		return
	_arrival_text = text
	_arrival_kicker = kicker
	_arrival_color = color
	_arrival_life = ARRIVAL_HOLD


## An arrival that fired while the whole-world view was open, waiting for it to close. Empty when none.
var _pending_arrival: Array = []


## IS THE ANNOUNCE CHANNEL OCCUPIED RIGHT NOW? One caller: the controller, which uses it to hold a
## just-in-time lesson back rather than stacking it under the ceremony. `P1`'s rule is *only one primary
## attention state at a time*, and this is the predicate that makes it enforceable rather than aspirational.
func announcing() -> bool:
	return _arrival_life > 0.0


## The conditions under which an arrival ceremony is held.
##
## Held, not dropped. The plate is a one-shot with a 3.4s life, so standing it down deletes the
## announcement rather than composing it. Its clock stops and it draws nothing while held, then resumes
## with its remaining life intact.
##
## Two conditions, for two different collisions. The large map shares the plate's rectangle, and the
## collision runs both ways: a ceremony firing while the map is open waits in `_pending_arrival`, and one
## already up when the map opens freezes here, since `_draw_arrival` runs after `_draw_minimap` and would
## otherwise land on top of it. A live grapple line shares the plate's column instead: the camera centres
## the body, so the plate spans canvas y 61.6 to 111.6 directly over the miner, and any rope reaching them
## passes through it. There is no position on a 640-wide canvas that avoids this, so the rope case can
## only be solved in time, not in space.
##
## Every gate site calls this rather than testing the conditions inline. A hold condition added to some
## sites and not others freezes the clock while the plate still fires and still draws.
func _announce_held() -> bool:
	return minimap_large or rope_active


func _process(delta: float) -> void:
	if not _pending_arrival.is_empty() and not _announce_held():
		var held: Array = _pending_arrival
		_pending_arrival = []
		announce(String(held[0]), String(held[1]), held[2] as Color)
	_flash_life = maxf(0.0, _flash_life - delta)
	if not _announce_held():
		_arrival_life = maxf(0.0, _arrival_life - delta)
	# The counter's arrival. Eased OUT, so it decelerates into place rather than sliding at a constant rate —
	# the difference between a panel that lands and a panel that is dragged on.
	var target: float = 1.0 if inventory_open else 0.0
	var step: float = delta / BAZAAR_RISE
	_bazaar_t = clampf(_bazaar_t + (step if target > _bazaar_t else -step * 2.0), 0.0, 1.0)
	# The counter's HEIGHT follows the tab, on the same clock as its rise. Snapped when closed so opening
	# never animates a size, and snapped near the target so a settled frame is a settled measurement rather
	# than a lerp caught mid-flight -- `check_hud_layout` photographs this panel and a footprint that
	# depends on how many frames have passed is not a footprint.
	if inventory_open or _bazaar_t > 0.0:
		var want: float = _bazaar_wanted_h()
		if _bazaar_t <= 0.0 or absf(want - _bazaar_h) < 0.5:
			_bazaar_h = want
		else:
			_bazaar_h += (want - _bazaar_h) * clampf(delta / BAZAAR_RISE, 0.0, 1.0)
	# THE SETTINGS PAGE FOLLOWS ITS CATEGORY, on the counter's clock and by the counter's rule. Snapped
	# while closed for the reason above: a settled frame has to be a settled measurement, or a footprint
	# is a statement about how many frames elapsed before the shutter.
	_set_t = clampf(_set_t + (step if settings_open else -step * 2.0), 0.0, 1.0)
	_plain_t = clampf(_plain_t + (step if (show_dashboard or show_help) else -step * 2.0), 0.0, 1.0)
	var set_want: float = _settings_wanted_h()
	if not settings_open or absf(set_want - _set_h) < 0.5:
		_set_h = set_want
	else:
		_set_h += (set_want - _set_h) * clampf(delta / BAZAAR_RISE, 0.0, 1.0)
	queue_redraw()


## Ease-out cubic. The counter's rise reads as arriving because it slows down at the end.
func _bazaar_ease() -> float:
	var u: float = 1.0 - _bazaar_t
	return 1.0 - u * u * u


## The settings page's rise, on the same curve. Public because `MainView._update_defocus` racks the world
## out of focus behind it — a modal that leaves the world sharp behind it reads as a sticker on the frame,
## which is `MNU-07`'s whole complaint.
func settings_ease() -> float:
	var u: float = 1.0 - _set_t
	return 1.0 - u * u * u


## The dashboard and the key list, on the same curve as the other two. Public for the same reason: whichever
## modal is up should rack the world, and picking only the modals that happened to already have a rise is
## how two of the four ended up reading as stickers on a sharp frame.
func plain_modal_ease() -> float:
	var u: float = 1.0 - _plain_t
	return 1.0 - u * u * u


## UI-07 — EVERY HELPER SURFACE, CLASSIFIED. The ticket's bounded treatment is *"inventory all active
## helpers and tag as critical/active/discoverable/ambient"*, with the rule *"only one primary attention
## state at a time"*, and this is that inventory. It is a constant rather than a document because
## `check_hud_layout` asserts that **every `_draw_*` method on this class appears here** — so adding a
## surface and not deciding what kind of thing it is fails the harness instead of quietly becoming the
## eighth thing on the screen.
##
## The tags, and what each one is allowed to do:
##
##   `critical`      interrupts. It arrives on its own schedule and expects to be read NOW. **At most one
##                   may be on screen at a time** — that is the rule, and it is the only tag the rule is
##                   about. The `P0` baseline photographed two of them sharing pixels in three frames.
##   `active`        describes what you are doing or looking at THIS moment. Several may coexist; they are
##                   answers to questions you just asked with the cursor or the verb.
##   `discoverable`  you summoned it. It may cover everything, because you asked it to.
##   `ambient`       always-on state you read at a glance and never respond to. It must never move, and it
##                   is not allowed to become any of the above.
##   `internal`      not a surface — a drawing helper another entry uses. Listed so the registry check
##                   above is total, and so "is this a helper or a screen" is a decision someone made.
##
## `_draw_title` is `discoverable` on a technicality worth stating: you did not summon it, but it owns the
## whole screen by design and returns before anything else draws, so nothing can collide with it.
const HELPER_TAGS: Dictionary = {
	# critical — the interrupt channel, and the one with a one-at-a-time rule
	"_draw_arrival": &"critical",         # the stratum plate: "stop, look"
	"_draw_flash": &"critical",           # save/load toast
	"_draw_alerts": &"critical",          # a machine is stalled and will stay stalled
	"_draw_hint_bubble": &"critical",     # a lesson, which is why strike 1 made it yield to the plate
	# active — about the thing under your hand right now
	"_draw_objective_line": &"active",
	"_draw_hover": &"active",
	"_draw_item_tooltip": &"active",
	# discoverable — you pressed a key to get it
	"_draw_minimap": &"discoverable",
	"_draw_inventory_overlay": &"discoverable",
	"_draw_dashboard_overlay": &"discoverable",
	"_draw_help_overlay": &"discoverable",
	"_draw_settings_overlay": &"discoverable",
	"_draw_title": &"discoverable",
	# ambient — state, read at a glance, never answered
	"_draw_depth": &"ambient",
	"_draw_forged": &"ambient",
	"_draw_inventory": &"ambient",        # the hotbar
	"_draw_hint": &"ambient",             # the bottom-left key legend
	"_draw_fastforward": &"ambient",
	# internal — helpers, not screens
	"_draw": &"internal",
	"_draw_scrim": &"internal",
	"_draw_tracked": &"internal",
	"_draw_thing_icon": &"internal",
	"_draw_tech_art": &"internal",
	"_draw_tech_chip": &"internal",
	"_draw_bazaar_rail": &"internal",
	"_draw_bazaar_head": &"internal",
	"_draw_settings_rail": &"internal",
	"_draw_settings_head": &"internal",
	"_draw_settings_detail": &"internal",
	"_draw_bazaar_foot": &"internal",
	"_draw_bazaar_detail": &"internal",
}

## THE PAUSED CHIP IS A CRITICAL SURFACE WITHOUT A FUNCTION OF ITS OWN — it is eight lines inline in
## `_draw()`. It is named here so the registry is honest about it, and so the collision below has
## somewhere to be written down.
##
## **IT WAS MOVED ONCE, INTO THE PLACE IT THEN COLLIDED.** It used to print across the objective line at
## y=8, so it was pushed down to y 50..76 — straight into the arrival plate's scrim core, which sits at
## `CANVAS.y * 0.26 - SCRIM_ABOVE` = y 61.6..111.6. Pausing on the frame you cross a stratum is not an
## exotic input: crossing a band is exactly when a player stops to read. *A fix that relocates a collision
## instead of resolving it is indistinguishable from a fix, until the second surface shows up.*
##
## **So it leaves the centre column entirely** and joins the left stack the depth readout owns — under the
## fast-forward chip, in the one column where nothing centred can reach it. Moving it in Y was the trap;
## the ceremony, the objective line and the lesson bubble are all centred, so the centre column has three
## occupants competing for a strip 100px tall while the left column has two chips and 300px of nothing.
## Being paused is also the least surprising thing on this list — the player did it a moment ago — so of
## the two criticals it is the one that can afford the quiet corner.
const PAUSED_CHIP: Rect2 = Rect2(10.0, 60.0, 104.0, 22.0)


## IS A MODAL UP: the counter, the dashboard, the controls page or the settings page. All four dim the
## world behind them and put a plate over the middle of it, so for as long as one is open it IS the screen
## and the furniture around it stands down. Written once because it was being spelled out three times, and
## one of the three had a different idea of which screens counted (`_draw_arrival` left `show_help` out).
##
## The minimap is deliberately not in here. It is summoned, not modal, and it has the opposite rule: the
## furniture stands down for the LARGE form only, inside the surfaces it collides with.
func _modal_open() -> bool:
	return inventory_open or show_dashboard or show_help or settings_open


func _draw() -> void:
	_tooltip_item = &""    # re-captured by whichever slot the cursor sits on this frame
	_alert_hits.clear()    # stale unless _draw_alerts repopulates it this frame (menus suppress it)
	# THE TITLE (#6): while it's open nothing else matters — the veil + the new-game card ARE the screen.
	if not title_info.is_empty():
		_draw_title()
		return
	# --- always on, unless a modal has taken the screen ---
	# Every line in here is world furniture, and each of the four modals draws a plate across the middle of
	# a 640x360 canvas: the counter alone is 608 wide and reaches 348 tall. Drawn unconditionally, the depth
	# chip and the hotbar came out in two pieces, one half dimmed by the modal's own scrim and the other
	# covered by its plate, and a chip cut by an edge reads as a drawing fault rather than as a chip. The
	# bubble and the alert stack were already standing down for exactly this; the other five now do too, so
	# there is one rule for the question instead of one per surface.
	if not _modal_open():
		_draw_forged()         # top-right production chip (small)
		_draw_depth()          # top-left depth readout — the one number a descent game owes you
		_draw_objective_line()  # top-centre, ONE current step — the signpost without the wall of text
		_draw_inventory()      # bottom-centre hotbar
		_draw_hint()           # tiny bottom-left "E craft · M map · H keys" — replaces the giant footer
		_draw_hint_bubble()  # just-in-time teaching near the body (hidden while a menu dims the world)
		_draw_alerts()       # left-edge stalled-machine stack (only when something's stuck)
	# THE INSPECTOR STANDS DOWN INSIDE ITSELF, not here, because it owns a click region as well as a panel.
	# Skipping the call would leave `_hover_rect` at whatever it held on the frame before the menu opened,
	# and `_cursor_on_hover_panel()` reads that rect: a click on the counter would land on a config knob
	# belonging to a machine nobody can see. Same reason `_draw_hover` returns AFTER clearing, not before.
	_draw_hover()          # inspector for the machine under the cursor (only when one is hovered)
	# --- on demand (summoned, so they never clutter) ---
	if show_minimap:
		_draw_minimap()    # M — top-right world map
	if inventory_open:
		_draw_inventory_overlay()  # E/T — THE BAZAAR: one counter, three tabs (docs/BAZAAR.md)
	if show_dashboard:
		_draw_dashboard_overlay()  # G — throughput bars + factory census (the flywheel made legible)
	if show_help:
		_draw_help_overlay()      # H / ? — the full controls list
	if settings_open:
		_draw_settings_overlay()  # ESC — audio / feel / the remap page
	if paused_getter.is_valid() and bool(paused_getter.call()):
		# UNDER the objective line, not on top of it. Both were aimed at top-centre at y=8 and the
		# objective panel is 37 tall, so PAUSED printed straight across the one line telling you what to
		# do next — and pausing is exactly when a player stops to read it.
		_panel(PAUSED_CHIP)
		draw_string(_font, PAUSED_CHIP.position + Vector2(12.0, 15.0), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)
	_draw_fastforward()    # top-left "▶▶ Nx" chip when the game clock is sped up
	# The stratum plate is the one channel that means "stop, look", so it does not fire over a modal, where
	# there is nothing to look at and it prints straight through the price column. It is a transient, and
	# holding it costs nothing: the depth readout comes back with the world and names the band you are in.
	# This list used to be spelled out here with `show_help` missing from it while the other three were on
	# it, so the one banner that means "look at the world" fired over the page that is purely for reading.
	if not _modal_open():
		_draw_arrival()    # the stratum banner, on the frames after you first cross into one
	_draw_flash()          # transient toast (save/load feedback)
	_draw_item_tooltip()   # hovered-slot tooltip — drawn last so it rides over every panel


## THE TITLE / NEW-GAME screen (#6 + #45): a dark veil over the live (paused) world, the game's name,
## and the two choices that make this world YOURS — its seed and your lamp's colour. Deliberately
## spare: the world glowing behind the veil is the real menu art.
func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS)), Color(0.03, 0.035, 0.06, 0.82))
	var cx: float = CANVAS.x * 0.5
	var y: float = CANVAS.y * 0.30
	# The name — tracked out wide, with the accent rule under it.
	var title: String = "S I N K F O R G E"
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_font, Vector2(cx - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Color(0.97, 0.90, 0.62))
	draw_rect(Rect2(cx - tw * 0.5, y + 7.0, tw, 2.0), UI_ACCENT)
	var tag: String = "the way is down"
	var gw: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(cx - gw * 0.5, y + 24.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.64, 0.70, 0.80))
	# The choices card.
	y += 48.0
	var card := Rect2(cx - 128.0, y, 256.0, 84.0)
	_panel(card)
	var x0: float = card.position.x + 14.0
	var ly: float = y + 22.0
	draw_string(_font, Vector2(x0, ly), "world seed", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.62, 0.66, 0.74))
	draw_string(_font, Vector2(x0 + 78.0, ly), "%d" % int(title_info.get("seed", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.80))
	draw_string(_font, Vector2(card.end.x - 92.0, ly), "[TAB] reroll", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.60, 0.70))
	ly += 26.0
	draw_string(_font, Vector2(x0, ly), "lamp", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.66, 0.74))
	var tints: Array = title_info.get("tints", [])
	var sel: int = int(title_info.get("tint", 0))
	var sx: float = x0 + 44.0
	for i: int in tints.size():
		var sw := Rect2(sx, ly - 11.0, 14.0, 14.0)
		draw_rect(sw, (tints[i] as Dictionary)["color"])
		if i == sel:
			draw_rect(sw.grow(2.0), UI_ACCENT, false, 1.5)
		sx += 20.0
	draw_string(_font, Vector2(card.end.x - 92.0, ly), "[<-/->] pick", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.60, 0.70))
	ly += 20.0
	draw_string(_font, Vector2(x0 + 44.0, ly), str(title_info.get("tint_name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.76, 0.84))
	# The verbs.
	y = card.end.y + 26.0
	var go: String = "[ENTER]  descend"
	var gow: float = _font.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, Vector2(cx - gow * 0.5, y), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	if bool(title_info.get("has_save", false)):
		var cont: String = "[C]  continue your last save"
		var cw: float = _font.get_string_size(cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(cx - cw * 0.5, y + 18.0), cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.70, 0.76, 0.86))


## The transient toast: a small accented chip centred under the objective line, fading out over its
## last half-second. Cheap, reusable feedback for one-shot actions (F5 save / F9 load).
func _draw_flash() -> void:
	if _flash_life <= 0.0 or _flash_text == "":
		return
	var a: float = clampf(_flash_life / 0.5, 0.0, 1.0)
	var w: float = _font.get_string_size(_flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28.0
	var p := Rect2(CANVAS.x * 0.5 - w * 0.5, 46.0, w, 24.0)
	draw_rect(p, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(p, Color(UI_EDGE.r, UI_EDGE.g, UI_EDGE.b, a), false, 1.0)
	draw_string(_font, p.position + Vector2(14.0, 17.0), _flash_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.62, a))


## The just-in-time HINT BUBBLE: a small speech bubble with a tail pointing down at the body, teaching
## the item that just landed in the pack. Word-wrapped, gold-capped like every panel,
## faded by the tracker's envelope. Clamped on-canvas so a body near a world edge still gets taught.
## UI-06 — THE TUTORIAL'S FOOTPRINT, AS A FUNCTION RATHER THAN AS ARITHMETIC IN A DRAW CALL.
##
## The ticket asks for *"a capture-reviewed max height/coverage for non-modal lessons"*, and a ceiling is
## only a ceiling if something can measure the thing it caps. This is the box `_draw_hint_bubble` actually
## draws, extracted so the harness can size every lesson in the game **without reimplementing the layout**
## — a second copy of this arithmetic would be a gauge that agrees with itself and not with the screen.
## SIZE IS THE WHOLE COMPLAINT. At 11pt over a 230px wrap this box was 250x52 on a 640x360 canvas —
## 39% of the width, 14% of the height, set at nearly the objective banner's weight, floating over the
## body in the middle of the play area. A just-in-time hint is the quietest thing on screen, not the
## loudest. 8pt over 176 halves the footprint; the lessons were rewritten to one line each in the same
## pass, because a smaller box around the same paragraph is just a smaller paragraph.
const HINT_FS: int = 8
const HINT_WRAP: float = 176.0

static func hint_box(font: Font, text: String) -> Vector2:
	var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, HINT_WRAP, HINT_FS)
	return Vector2(minf(ts.x, HINT_WRAP) + 16.0, ts.y + 11.0)


func _draw_hint_bubble() -> void:
	if hint_text == "" or hint_alpha <= 0.01:
		return
	var fs: int = HINT_FS
	var wrap_w: float = HINT_WRAP
	var box: Vector2 = hint_box(_font, hint_text)
	var w: float = box.x
	var h: float = box.y
	var tail := Vector2(clampf(hint_anchor.x, 8.0, CANVAS.x - 8.0),
		clampf(hint_anchor.y, 60.0, HOTBAR_BAND_TOP - 6.0))
	var origin := Vector2(clampf(tail.x - w * 0.5, 6.0, CANVAS.x - w - 6.0), tail.y - 7.0 - h)
	if origin.y < 38.0:                       # never under the objective line — flip below the anchor
		origin.y = tail.y + 7.0
	var a: float = hint_alpha
	var rect := Rect2(origin, Vector2(w, h))
	# ELEVATION, NOT AN OUTLINE. A flat fill inside a 1px border with a full-width bar across the top is
	# a dialog box, and it reads as one. A soft drop shadow puts the plate ABOVE the world instead of
	# cut into it, and the accent shrinks to a left edge so the eye lands on the word, not the frame.
	_round_rect(Rect2(rect.position + Vector2(0.0, 1.5), rect.size), 4.0, Color(0.0, 0.0, 0.0, 0.38 * a))
	_round_rect(rect, 4.0, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), Vector2(1.5, h - 6.0)),
		Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.85 * a))
	var tip_y: float = tail.y if origin.y < tail.y else origin.y - 1.0   # tail reaches toward the body
	var base_y: float = (origin.y + h) if origin.y < tail.y else origin.y
	var tx: float = clampf(tail.x, origin.x + 10.0, origin.x + w - 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 3.5, base_y), Vector2(tx + 3.5, base_y),
		Vector2(tx, tip_y)]), Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_multiline_string(_font, origin + Vector2(8.0, 5.0 + 8.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.92, 0.88, 0.74, a))


## FACTORY ALERTS: a compact left-edge stack of stalled machines, shown ONLY when
## something's actually stuck (calm-by-default — a healthy factory draws nothing here). Each row names
## the machine + count + why, and is CLICKABLE to drop a ping on the culprit so you can walk to it (the
## camera is body-locked; a beacon is the honest "take me there"). MainView pushes `alerts` + routes the
## click through alert_click(). Capped at 5 rows so a cascading failure can't wallpaper the screen.
func _draw_alerts() -> void:
	if alerts.is_empty():
		return
	var mouse: Vector2 = Controls.pointer_viewport(self)
	var w: float = 184.0
	var rh: float = 22.0
	var x: float = 10.0
	var y: float = 100.0
	var tri := Vector2(x + 5.0, y - 8.0)                       # a small warning triangle (font-safe glyph)
	draw_colored_polygon(PackedVector2Array([tri + Vector2(-4.0, 3.0), tri + Vector2(4.0, 3.0),
		tri + Vector2(0.0, -4.0)]), Color(0.95, 0.60, 0.30))
	draw_string(_font, Vector2(x + 13.0, y - 4.0), "ALERTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.94, 0.64, 0.44))
	for i: int in mini(5, alerts.size()):
		var a: Dictionary = alerts[i]
		var rect := Rect2(x, y, w, rh - 3.0)
		var lit: bool = rect.has_point(mouse)
		draw_rect(rect, Color(0.20, 0.11, 0.10, 0.95) if lit else Color(0.15, 0.09, 0.09, 0.92))
		draw_rect(rect, Color(0.78, 0.40, 0.32, 0.7 if lit else 0.45), false, 1.0)
		draw_rect(Rect2(x, y, 2.5, rh - 3.0), UI_WARN)                          # the warning edge
		var mdef: MachineDef = a["def"]
		var box := Rect2(x + 6.0, y + 2.5, 13.0, 13.0)
		draw_rect(box, Visuals.machine_color(mdef))
		Visuals.draw_machine_glyph(self, box.position + box.size * 0.5, Visuals.machine_kind(mdef),
			box.size.y / 20.0, false, 0.0)
		var cnt: int = int(a["count"])
		var nm: String = str(a["name"]) + ("  ×%d" % cnt if cnt > 1 else "")
		draw_string(_font, Vector2(x + 24.0, y + 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 9,
			Color(0.96, 0.86, 0.78))
		draw_string(_font, Vector2(x + 24.0, y + 16.0), str(ALERT_REASON.get(a["status"], str(a["status"]))),
			HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 8, Color(0.82, 0.62, 0.54))
		_alert_hits.append({"rect": rect, "cell": a["cell"]})
		y += rh
	draw_string(_font, Vector2(x + 2.0, y + 5.0), "click one → mark it on the map",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_DIM)


## Route a click at `mouse` (canvas coords) to the alert it hit → {cell: Vector2i} to ping, or {} if the
## click missed the stack. MainView owns the ping; the HUD only reports the hit (the minimap-click rule).
func alert_click(mouse: Vector2) -> Dictionary:
	for hit: Dictionary in _alert_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return {"cell": hit["cell"]}
	return {}


## Is `mouse` over the alert stack this frame? (MainView holsters the pick over it, like the minimap.)
func cursor_on_alerts(mouse: Vector2) -> bool:
	for hit: Dictionary in _alert_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return true
	return false


## Fast-forward chip (top-left): a small "▶▶ Nx" tag shown ONLY while the game clock is sped up, so the
## world visibly racing has an on-screen cause. Hidden at 1x to keep the default screen calm. Press "."
## to cycle. Uses the shared accented panel skin.
## THE DEPTH READOUT (top-left). Metres below the surface datum, and the name of the band you are in,
## in that band's own colour — so the number and the world's palette agree. Permanent, because in a game
## whose entire subject is descending, "how far down am I" is not an optional overlay.
## The depth chip's width, on its own so the objective banner can measure what it must not grow under.
func _depth_chip_w() -> float:
	var m: int = Strata.depth_m(depth_row)
	var label: String = ("%d m" % m) if m >= 0 else ("+%d m" % -m)
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var bw: float = _font.get_string_size(Strata.name_at(depth_row), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	return maxf(lw + 10.0 + bw, 96.0) + 24.0


func _draw_depth() -> void:
	var m: int = Strata.depth_m(depth_row)
	var label: String = ("%d m" % m) if m >= 0 else ("+%d m" % -m)
	var band: String = Strata.name_at(depth_row)
	var tint: Color = Strata.color_at(depth_row)
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var chip := Rect2(10.0, 8.0, _depth_chip_w(), 22.0)
	_panel(chip)
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_string(_font, Vector2(chip.position.x + 12.0, cy + 6.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_TEXT)
	draw_string(_font, Vector2(chip.position.x + 12.0 + lw + 10.0, cy + 5.0), band,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tint)


## THE ARRIVAL PLATE. Only ever the FIRST time you enter a band — the whole value is that it is rare.
##
## It used to be set at three times this size across a full-width bar, which made the one moment the
## descent gets to be an event read instead as a modal dialog: it covered the play space, it competed
## with the objective banner directly above it, and a player's first instinct was to dismiss it. Weight
## in a title card comes from SPACING, not from point size. So: half the type, letters tracked apart, a
## kicker line above it, rules only as wide as the text, and no panel at all.
const ARRIVAL_SIZE: int = 15             ## canvas px; the objective banner above runs at 13
const ARRIVAL_TRACK: float = 3.4         ## extra px between letters — what makes small type read as engraved

## THE SCRIM. Panel-less type only reads while the thing behind it is dark, and every stratum plate fires
## underground, so the plate was legible for as long as it was the only thing that used this channel. The
## first-automation hail fires on the surface at midday, against a bright sky and a mountain range and a
## rotating gearwheel — and the words simply disappeared. The fix is not a panel (a panel is the modal
## dialog this design was built to escape) but a soft darkening under the words that has no edge to read
## as a shape: a soft field of dusk under the words that fades to nothing in every direction, so the text
## sits in its own patch of evening wherever it lands.
const SCRIM_COLS: int = 12               ## quads across the field...
const SCRIM_ROWS: int = 8                ## ...and down it
## PEAK DARKENING, DEAD CENTRE — 0.80 until it was measured, and the measurement is why it is 0.28.
##
## The scrim exists so the words separate from what is behind them. It is `Color(0.02, 0.025, 0.04)` drawn
## over the frame, which is a MULTIPLY in all but name: it keeps a fixed fraction of whatever is underneath.
## Underground the rock behind it sits at a luma near ten, so eighty percent of it is nearly nothing and
## the veil is almost invisible over the mass of the frame. The ROPE is hemp at 0.76/0.63/0.42.
##
## `check_ceremony_reads` measured what that costs: across the plate the rope moved a mean of **26.5 dE**
## out of the **41.4** of separation it had from its backing, while the rock behind the rope moved **6.6**.
## **The veil took four times more from the line you are hanging from than from the background it was drawn
## to suppress** — and the plate cannot be moved out of the way, because the camera centres the body and
## the plate is centred too, so its 420 px footprint on a 640 px canvas always contains the miner's column.
##
## So the words got their contrast LOCALLY instead — a near-black shadow a pixel behind each glyph, which
## buys the same separation inside a letter's width and works on bright sky as well as on dark rock — and
## the field veil dropped to what a compositional weight needs rather than what legibility was leaning on.
const SCRIM_ALPHA: float = 0.28
const SCRIM_PAD: float = 34.0            ## px of solid core beyond the widest line
const SCRIM_INK := Color(0.02, 0.025, 0.04)   ## the veil's own colour, now spent per glyph instead
const SCRIM_INK_OFF := Vector2(1.0, 1.0)      ## a pixel down and right — enough at this type size
const SCRIM_INK_A: float = 0.90
const SCRIM_FEATHER: float = 96.0        ## px the core fades out over, left and right
const SCRIM_ABOVE: float = 32.0
const SCRIM_BELOW: float = 18.0

func _draw_arrival() -> void:
	if _arrival_life <= 0.0 or _announce_held():
		return
	var t: float = _arrival_life / ARRIVAL_HOLD
	var a: float = clampf(minf((1.0 - t) * 6.0, t * 2.4), 0.0, 1.0)     # fast in, slow out
	var y: float = CANVAS.y * 0.26 - (1.0 - t) * 5.0
	var w: float = _tracked_width(_arrival_text, ARRIVAL_SIZE, ARRIVAL_TRACK)
	var half: float = w * 0.5 + 12.0
	var kw: float = _tracked_width(_arrival_kicker, 9, 2.6) if _arrival_kicker != "" else 0.0
	var core_half: float = maxf(w, kw) * 0.5 + SCRIM_PAD
	# THE CEREMONY IS FURNITURE WHILE IT IS UP, so the layout layer has to be able to see it. It draws no
	# `_panel()` — deliberately, a panel is the modal dialog this design escapes — so `panel_probe` was
	# blind to it and `check_hud_layout` could not judge the collision T2.1 reports ("zone ceremony
	# colliding with map, rope and action"). Registered as the SOLID CORE only, not the feathered extent:
	# the feather fades to nothing by construction and calling it occupied would report collisions with
	# regions that are visually empty.
	if probing:
		panel_probe.append(Rect2(CANVAS.x * 0.5 - core_half, y - SCRIM_ABOVE,
			core_half * 2.0, SCRIM_ABOVE + SCRIM_BELOW))
	_draw_scrim(core_half, y, a)
	# The shadow carries the contrast the veil used to. Drawn under every glyph rather than under the whole
	# plate, so what it costs the world is a pixel around each letter instead of a 420x50 field.
	if _arrival_kicker != "":
		_draw_tracked(_arrival_kicker, Vector2(CANVAS.x * 0.5 - kw * 0.5, y - 15.0) + SCRIM_INK_OFF, 9, 2.6,
			Color(SCRIM_INK, SCRIM_INK_A * a))
		_draw_tracked(_arrival_kicker, Vector2(CANVAS.x * 0.5 - kw * 0.5, y - 15.0), 9, 2.6,
			Color(_arrival_color, 0.80 * a))
	_draw_tracked(_arrival_text, Vector2(CANVAS.x * 0.5 - w * 0.5, y) + SCRIM_INK_OFF, ARRIVAL_SIZE,
		ARRIVAL_TRACK, Color(SCRIM_INK, SCRIM_INK_A * a))
	_draw_tracked(_arrival_text, Vector2(CANVAS.x * 0.5 - w * 0.5, y), ARRIVAL_SIZE, ARRIVAL_TRACK,
		Color(_arrival_color, a))
	# Two hairlines the width of the words: a frame that says "plate" without drawing a panel.
	for ry: float in [y - 25.0, y + 7.0]:
		draw_line(Vector2(CANVAS.x * 0.5 - half, ry), Vector2(CANVAS.x * 0.5 + half, ry),
			Color(_arrival_color, 0.40 * a), 1.0)


## The arrival plate's soft ground, drawn as an interpolated GRID rather than as a stack of bands.
##
## The first version stacked constant-alpha strips with a half-pixel overlap to hide the seams, which is
## precisely backwards: where two translucent strips overlap their alpha COMPOSITES, so every seam came
## out darker than either neighbour and the scrim rasterized as venetian blinds straight across the sky.
## A grid has no seams to hide. Adjacent quads share their edge vertices AND those vertices' colours, so
## the hardware interpolates one continuous field across the whole plate — and the falloff can then be
## smoothstepped on both axes, which puts a zero derivative at every outer edge and leaves nothing for
## the eye to catch.
func _draw_scrim(core_half: float, y: float, a: float) -> void:
	var cx: float = CANVAS.x * 0.5
	var top: float = y - SCRIM_ABOVE
	var bot: float = y + SCRIM_BELOW
	var half_w: float = core_half + SCRIM_FEATHER
	var xstep: float = half_w * 2.0 / float(SCRIM_COLS)
	var ystep: float = (bot - top) / float(SCRIM_ROWS)
	for r: int in SCRIM_ROWS:
		var y0: float = top + ystep * float(r)
		var y1: float = y0 + ystep
		var v0: float = _scrim_v(y0, top, bot)
		var v1: float = _scrim_v(y1, top, bot)
		if maxf(v0, v1) <= 0.004:
			continue
		for c: int in SCRIM_COLS:
			var x0: float = cx - half_w + xstep * float(c)
			var x1: float = x0 + xstep
			var h0: float = _scrim_h(x0 - cx, core_half)
			var h1: float = _scrim_h(x1 - cx, core_half)
			if maxf(h0, h1) <= 0.004:
				continue
			draw_polygon(
				PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
				PackedColorArray([_scrim_c(h0 * v0, a), _scrim_c(h1 * v0, a),
					_scrim_c(h1 * v1, a), _scrim_c(h0 * v1, a)]))


## Full weight across the core, smoothly out to nothing across the feather.
func _scrim_h(dx: float, core_half: float) -> float:
	return 1.0 - smoothstep(core_half, core_half + SCRIM_FEATHER, absf(dx))


## ...and a bell down the plate, so it has no top or bottom edge either.
func _scrim_v(yy: float, top: float, bot: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, absf(yy - (top + bot) * 0.5) / maxf((bot - top) * 0.5, 0.001))


func _scrim_c(weight: float, a: float) -> Color:
	return Color(0.02, 0.025, 0.04, SCRIM_ALPHA * a * weight)


## Letter-tracked text. Godot's draw_string has no tracking, and tracking is the entire difference
## between small type that reads as a label and small type that reads as a caption.
func _draw_tracked(text: String, at: Vector2, size: int, track: float, color: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


func _tracked_width(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(0, text.length() - 1))


func _draw_fastforward() -> void:
	if time_scale <= 1.0:
		return
	var label: String = "▶▶ %dx" % int(time_scale)
	var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var chip := Rect2(10.0, 34.0, tw + 24.0, 22.0)   # under the depth chip, which owns the corner
	_panel(chip)
	draw_string(_font, chip.position + Vector2(12.0, 15.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)


## FORGED production chip (top-right): an ingot swatch + the lifetime ingot count, in a small panel —
## consistent with the inspector/minimap skin instead of bare floating text.
## The FORGED chip's width — the other wall the objective banner has to stay inside of.
func _forged_chip_w() -> float:
	var label_w: float = _font.get_string_size("FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var count_w: float = _font.get_string_size(str(int(sim.total_produced.get(&"ingot", 0))),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	return 12.0 + 14.0 + 8.0 + label_w + 8.0 + count_w + 12.0


func _draw_forged() -> void:
	var n: int = int(sim.total_produced.get(&"ingot", 0))
	var count: String = str(n)
	var label_w: float = _font.get_string_size("FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var w: float = _forged_chip_w()
	var chip := Rect2(CANVAS.x - w - 10.0, 8.0, w, 22.0)
	_panel(chip)
	var x: float = chip.position.x + 12.0
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Visuals.item_color(&"ingot"))
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
	x += 14.0 + 8.0
	draw_string(_font, Vector2(x, cy + 5.0), "FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT_DIM)
	x += label_w + 8.0
	draw_string(_font, Vector2(x, cy + 6.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_TEXT)


## How long a fresh step shows its full how-to line, how long that takes to fade, and how long you have
## to sit on one step before it comes back (#B4).
const HINT_HOLD: float = 9.0
const HOVER_MAX_W: float = 300.0   ## the inspector may grow to fit its widest line, but no further
## ...and never shrinks below this, so a one-word machine name still reads as a panel rather than a chip.
## Named because `check_hud_layout` needs the same number to reason about the right column, and a test
## that re-types a literal is checking its own arithmetic against itself.
const HOVER_MIN_W: float = 218.0
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0

## The permanent objective plate is retired after the opening lesson.
##
## The problem was permanence rather than existence: the game may say what has just become possible, but
## it may not stand over the player while they do it. The how-to line already behaved that way, holding,
## fading, and returning on a stall. The goal line did not, and sat at top-centre through every step.
##
## After the opening lesson nothing is offered. Later steps do not announce, hold, or fade, and the top of
## the screen stays empty. Guidance becomes reactive and returns only once the player has genuinely
## stalled. The world carries it meanwhile: `world_renderer._draw_guide_targets()` pulses a ring on the
## cells the current step points at.
##
## A softer variant that announces, holds six seconds, then fades is one `else` branch away.
##
## `GOAL_PERSISTS_THROUGH` is how many steps count as the opening lesson and keep the old permanent plate,
## so nobody is stranded on the first thing they ever see. At 1 that is the first step only. Raise it to
## teach for longer, or set it to 0 to remove the plate entirely, including from the opening.
const GOAL_FADE: float = 1.2       ## how long reactive guidance takes to arrive once you have stalled
const GOAL_PERSISTS_THROUGH: int = 1


## The OBJECTIVE line (top-centre) — the current step only, as a gentle nudge. Pure read of the
## Objectives tracker. Top-centre sits over open sky, so it never buries the avatar the way the old
## panel did. When the whole chain is done it shows a brief "all set" then auto-hides (the Guide stops
## nagging).
##
## LESS TEXT, MORE SHOW (#B4). This used to be one long imperative sentence, permanently — thirteen of
## them in a row, each a banner of prose across the top of the screen. It reads as homework: the game
## telling you what to do rather than a world inviting you to try things, and it was a real part of
## "the early game is annoying instead of seamless". The banner now leads with the SHORT goal ("Mine 4
## ore"), which is all a player needs once they know the verb, and carries the full how-to underneath
## only while it's actually wanted: for the first few seconds after a step opens, and again once you
## have been stuck on one long enough to want it back. In between, the world does the talking — the
## pulsing target ring already points at where the step happens.
func _draw_objective_line() -> void:
	if objectives == null:
		return
	if objectives.all_done() and objectives.done_for() > 5.0:
		return  # finished + lingered → clear the screen for veterans
	# THE BIG MAP IS THE SCREEN. It is centred and 272 tall in a 360 canvas, so its panel top sits at y=41
	# while this banner reaches y=45 whenever its how-to line is up — a four-pixel overlap that
	# `check_hud_layout` caught only INTERMITTENTLY, because whether the how-to is on screen depends on
	# `step_age`, which depends on how much sim time the layer happened to burn. A latent collision behind
	# a flaky assertion. Standing down here fixes it for every timing rather than nudging the map: someone
	# who opened the whole-world view is looking at the world, and a goal plate over it is the supervisor
	# talking across the one screen that is purely for reading the game.
	if minimap_large:
		return
	var text: String
	var col: Color
	var hint: String = ""
	var hint_a: float = 0.0
	var goal_a: float = 1.0
	if objectives.all_done():
		text = "✓  All set — keep digging deeper."
		col = Color(0.62, 0.86, 0.58)
	else:
		var step: Dictionary = objectives.steps[objectives.current_index()]
		text = str(step["goal"])
		col = Color(0.97, 0.93, 0.78)
		var age: float = objectives.step_age
		# Reactive guidance, the ONLY thing a later step may put on screen: it arrives once you have sat on
		# a step long enough to want it, and it is zero until then.
		var stalled: float = clampf((age - HINT_STUCK) / GOAL_FADE, 0.0, 1.0)
		if objectives.current_index() < GOAL_PERSISTS_THROUGH:
			# The opening lesson keeps the plate, and the how-to that arrives with it and fades.
			if age < HINT_HOLD + HINT_FADE:
				hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
			elif age > HINT_STUCK:
				hint_a = stalled
		else:
			goal_a = stalled                     # nothing is OFFERED after the first lesson
			hint_a = stalled
		if hint_a > 0.0:
			hint = str(step["label"])
	if goal_a <= 0.0 and hint_a <= 0.0:
		return                                    # nothing to say: leave the sky alone
	var fs: int = 13
	var hfs: int = 10
	var pad: float = 12.0
	# THE FREE SPAN. The banner is centred between two fixed chips — depth on the left, FORGED on the
	# right — so a long how-to line grows symmetrically until the plate's own frame runs under one and
	# through the other. ("Toss ore down the mineshaft into the forge…" did exactly that.) Clamp to what
	# is actually free and let the HOW-TO be the part that gives: the goal is the half you need.
	var free_w: float = CANVAS.x - (maxf(_depth_chip_w(), _forged_chip_w()) + 18.0) * 2.0
	text = _fit_text(text, fs, free_w - pad * 2.0 - 14.0)
	hint = _fit_text(hint, hfs, free_w - pad * 2.0)
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x if hint != "" else 0.0
	var w: float = minf(maxf(tw, hw) + pad * 2.0, free_w)
	var h: float = 24.0 + (13.0 if hint != "" else 0.0)
	var rect := Rect2((CANVAS.x - w) * 0.5, 8.0, w, h)
	_panel(rect, maxf(goal_a, hint_a))   # the skin is as present as its most visible line
	var cy: float = rect.position.y + 12.0
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, Color(UI_ACCENT, UI_ACCENT.a * goal_a))
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * goal_a))
	if hint != "":
		draw_string(_font, Vector2(rect.position.x + pad, cy + 18.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UI_TEXT_DIM, hint_a))


## Trim a string until it fits `max_w`, with an ellipsis standing in for what was cut. Binary-search-free
## on purpose: these are one-line labels, the loop runs a handful of times, and a wrong answer here is a
## sentence running off a panel rather than a frame-rate problem.
func _fit_text(text: String, size: int, max_w: float) -> String:
	if text == "" or max_w <= 0.0:
		return text
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var cut: String = text
	while cut.length() > 1:
		cut = cut.substr(0, cut.length() - 1)
		if _font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
			return cut.strip_edges(false, true) + "…"
	return "…"


## A framed, lightly-beveled panel backing — the shared skin for every HUD widget (objectives,
## inspector, minimap, the bottom pack). A faint lit top edge makes it read as raised rather than a
## flat sticker; `accent` paints a gold cap bar for headlined panels.
## TEST HOOK — while `probing`, every panel this frame appends its rect here and nothing else changes.
##
## The HUD is immediate-mode: there are no Control nodes, so nothing about the layout can be read off the
## scene tree, and a layout test would otherwise have to RE-DERIVE where each chip goes. A test that
## recomputes the layout it is checking agrees with itself by construction and catches nothing. This is
## two lines that let `check_hud_layout` observe the boxes the HUD ACTUALLY DREW, at real screen size, in
## the real scene.
## THE PROBES ARE OFF UNLESS A FIXTURE TURNS THEM ON, and this flag is the whole guard because the one it
## replaces could never be false. `if panel_probe != null:` reads as "unset", and the comment above said
## "left null in play" — but a `static var panel_probe: Array[Rect2]` initialises to `[]`, and in GDScript
## `[] != null` is TRUE (checked against 4.6.2, not assumed). So the guard fell open on every frame of
## every real session: one Rect2 appended per panel, ~6-10 panels a frame at 60fps, into a static array
## nothing clears and nothing frees. A test instrument that only costs a null check in play was, in play,
## an unbounded leak. Fixtures set `Hud.probing = true`; `check_hud_layout` asserts it is false by default
## and that the probes stay empty when it is, so this cannot silently fall open again.
static var probing: bool = false
static var panel_probe: Array[Rect2]

## The hotbar, measured the same way and for the same reason. It reports RECTANGLES, and the first version
## of it reported a COUNT — which was worth exactly nothing. `wells += 1` sat unconditionally inside `for k
## in n`, so the count could only ever equal `n`, which is `clampi(carried, 1, INVENTORY_SLOTS)`, which is
## arithmetic. Three assertions downstream compared it against numbers that were therefore already decided
## the moment `carried` was set, under a docstring claiming it caught "the case where those two disagree".
## They cannot disagree. Written, ironically, in the commit that fixed a different guard for being unable
## to be false.
##
## Geometry can disagree. Had `sx` been derived from the PACK index rather than the window slot — the exact
## sibling of the name-plate bug this probe exists to catch — the wells would have marched off the end of
## their own backing and off the canvas, and no count would have moved. Keys: carried (item types held),
## wells (the slot rect of every well drawn, in draw order), sel (the active index), sel_lit (did any DRAWN
## well light up as the selection), window (the pack index the first well shows), backing (the framed
## rect), label (the selected item's name plate, or a zero Rect2 when none was drawn). The bar's early
## returns leave it untouched, so an empty probe under `probing` means "the bar did not draw".
static var hotbar_probe: Dictionary


## `alpha` modulates the whole skin so a panel can FADE rather than blink out. Panels that fade fully are
## expected to return before calling this at all, so the probe keeps recording only what was really drawn.
## MNU-06 — A PANEL DOES NOT WEAR THE SELECTION COLOUR.
##
## This used to take an `accent` flag that drew a 2px `UI_ACCENT` rule across the panel's top, and eight
## surfaces asked for it: PAUSED, the title's choices card, the fast-forward chip, the objective line, the
## dashboard, the help page, settings, and the hotbar backing. `UI_ACCENT` is documented one line from its
## own declaration as *"selection, the live verb, the next step"* — so on the bare screen the colour that is
## supposed to mean "this is the thing your next keystroke acts on" was also the trim on the pause chip and
## the speed chip and the shelf your items sit on.
##
## **A mark that appears on eight things marks nothing.** The rule is now: gold goes on the thing you can
## act on — a selection spine, the live verb button, the next research step, the objective's own goal dot,
## the lit hotbar slot — and never on the furniture around it. What made panels read as raised was never
## the gold anyway; it is `UI_EDGE_HI`, the one-pixel bevel along the top, which is the elevation language
## the rest of this file is written in.
##
## The parameter is REMOVED rather than defaulted to false. A flag with no caller is a switch waiting to be
## flipped back by someone who reads it as an available option instead of as a retired one.
func _panel(rect: Rect2, alpha: float = 1.0) -> void:
	if probing:
		panel_probe.append(rect)
	draw_rect(rect, Color(UI_BG, UI_BG.a * alpha))
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0),
		Color(UI_EDGE_HI, UI_EDGE_HI.a * alpha), 1.0)
	draw_rect(rect, Color(UI_EDGE, UI_EDGE.a * alpha), false, 1.0)


## The machine INSPECTOR (top-right, under FORGED) — appears when you aim at one of your machines in
## reach. Names it and shows its recipe as item chips (inputs → outputs) or its routing mode, plus what
## it's currently holding. The "where does this eat / spit / what does it make" answer without a manual.
## CONFIG PANEL: machines with a knob also draw CLICKABLE rows — the splitter's three
## ratio chips, a filtered hopper's [clear] chip — and machines with a fill draw a real BAR (the
## engine's quota). MainView PINS the hover while the cursor crosses onto this panel, so the knobs are
## reachable; clicks land through hover_click() (every mutation stays a discrete sim call out there).
func _draw_hover() -> void:
	_knob_hits.clear()
	_hover_rect = Rect2()
	# Called every frame rather than from inside the not-modal branch, because those two clears are frame
	# hygiene: skip the call and the knob hit-boxes and the panel rect survive into a frame that never drew
	# them, and a click lands on a control that is no longer on screen. So the call stays and the DRAWING
	# leaves instead. main.gd:798 recomputes hover_info off the world aim whichever menu is up, so without
	# this the world inspector prints over an open pack or settings page.
	if _modal_open():
		return
	if hover_info.is_empty():
		return
	# THE BIG MAP IS THE SCREEN — the third element to take this rule, after the goal plate
	# (`_draw_objective_line`) and the pack bar (`_draw_inventory`), and for the reason written down once
	# for all three there. Standing down BEFORE the rect is built, so `_hover_rect` stays empty and
	# `_cursor_on_hover_panel()` reports false — otherwise the config-panel PIN in MainView's frame sync
	# would latch a machine nobody can see.
	#
	# A MODAL EARNS THE SAME STAND-DOWN, and it has to happen here rather than at the call site for the
	# second half of that sentence: the rect is a click region, so a skipped call leaves the last one
	# behind and a click on the counter lands on an invisible knob. You also cannot aim at a machine while
	# a plate covers the world, so an inspector under one is describing a cursor you are not driving.
	if minimap_large or _modal_open():
		return
	var ins: Array = hover_info.get("in", [])
	var outs: Array = hover_info.get("out", [])
	var holding: Array = hover_info.get("holding", [])
	var knobs: Array = hover_info.get("knobs", [])
	var bar: Dictionary = hover_info.get("bar", {})
	var has_recipe: bool = not ins.is_empty() or not outs.is_empty()
	var has_mode: bool = hover_info.has("mode") and str(hover_info["mode"]) != ""
	var has_rate: bool = hover_info.has("rate")
	var pad: float = 9.0
	var line_h: float = 18.0
	# THE PANEL TAKES THE WIDTH OF ITS WIDEST LINE. It is anchored to the right edge of the canvas, so a
	# line that overflowed a fixed 218px ran off the SCREEN — which is how "too hard for your pick — craft
	# a Stone Pickaxe", the single most important sentence the inspector says, came out as "craft a Stone
	# Pick". Capped, and anything past the cap is ellipsized rather than lost off the edge.
	var name_text: String = str(hover_info.get("name", ""))
	var mode_text: String = str(hover_info.get("mode", "")) if has_mode else ""
	var rate_text: String = str(hover_info.get("rate", "")) if has_rate else ""
	var widest: float = _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	for line: String in [mode_text, rate_text]:
		if line != "":
			widest = maxf(widest, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var width: float = clampf(widest + pad * 2.0, HOVER_MIN_W, HOVER_MAX_W)
	name_text = _fit_text(name_text, 13, width - pad * 2.0)
	mode_text = _fit_text(mode_text, 11, width - pad * 2.0)
	rate_text = _fit_text(rate_text, 11, width - pad * 2.0)
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty()) + int(has_rate) \
		+ knobs.size() + int(not bar.is_empty())
	# Sits below whatever occupies the top-right column: the CORNER minimap if it's shown, else just the
	# FORGED chip.
	#
	# THIS COMMENT USED TO SAY "(the large map is centred, off this column) — so the inspector never
	# collides", AND THAT WAS FALSE. Centred does not mean narrow: at 128x128 the large map spans x
	# 181..459, while this panel is right-anchored with a HOVER_MIN_W floor, so its left edge is at most
	# 640 - 218 - 12 = 410. Measured overlap 49x50 — and the collision was reachable in ordinary play
	# (open the map with M, aim at a machine). The `else 34.0` below is what caused it: the fallback fires
	# exactly when `minimap_large`, placing the panel high on a column the map does occupy.
	#
	# The comment asserted the impossibility of the thing the code was doing, which is why it survived so
	# long — anyone auditing this column read the guarantee and stopped. `_draw_hover` now returns early
	# under the large map, so the branch below only ever runs for the corner form, where the claim is true.
	var mini_bottom: float = minimap_frame().end.y if (show_minimap and not minimap_large) else 34.0
	var origin := Vector2(CANVAS.x - width - 12.0, mini_bottom + 10.0)
	_hover_rect = Rect2(origin, Vector2(width, 10.0 + float(rows) * line_h + 4.0))
	_panel(_hover_rect)
	var x0: float = origin.x + pad
	var y: float = origin.y + 8.0 + 12.0
	draw_string(_font, Vector2(x0, y), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.80))
	y += line_h
	if has_recipe:
		var x: float = _chips(x0, y, ins)
		x = _arrow(x, y)
		_chips(x, y, outs)
		y += line_h
	if has_mode:
		draw_string(_font, Vector2(x0, y), mode_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.80, 0.90))
		y += line_h
	if not holding.is_empty():
		var hx: float = draw_string_pos(x0, y, "holds")
		_chips(hx, y, holding)
		y += line_h
	if has_rate:
		draw_string(_font, Vector2(x0, y), rate_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.72, 0.42))
		y += line_h
	if not bar.is_empty():
		var br := Rect2(x0, y - 11.0, width - pad * 2.0, 12.0)
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(float(bar.get("frac", 0.0)), 0.0, 1.0),
			br.size.y)), Color(0.62, 0.42, 0.95, 0.85))
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(x0 + 3.0, y - 1.0), str(bar.get("label", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.94, 0.99))
		y += line_h
	var mouse: Vector2 = Controls.pointer_viewport(self)
	for knob: Variant in knobs:
		var k: Dictionary = knob
		var x: float = x0
		if k.get("kind", "") == "choice":
			x = draw_string_pos(x, y, str(k.get("label", "")))
			var options: Array = k.get("options", [])
			for i: int in options.size():
				var text: String = str(options[i])
				var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
				var chip := Rect2(x, y - 12.0, w, 15.0)
				var current: bool = i == int(k.get("current", -1))
				var lit: bool = chip.has_point(mouse)
				draw_rect(chip, Color(0.93, 0.78, 0.30) if current
					else (Color(0.30, 0.34, 0.44) if lit else Color(0.16, 0.18, 0.24)))
				draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
				draw_string(_font, Vector2(x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.10, 0.10, 0.12) if current else Color(0.90, 0.92, 0.96))
				_knob_hits.append({"rect": chip, "payload": {"knob": "choice", "index": i}})
				x += w + 5.0
		elif k.get("kind", "") == "action":
			var text2: String = str(k.get("label", ""))
			var w2: float = _font.get_string_size(text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
			var chip2 := Rect2(x, y - 12.0, w2, 15.0)
			draw_rect(chip2, Color(0.34, 0.30, 0.22) if chip2.has_point(mouse) else Color(0.22, 0.20, 0.16))
			draw_rect(chip2, Color(0.93, 0.78, 0.30, 0.55), false, 1.0)
			draw_string(_font, Vector2(x + 6.0, y), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.95, 0.88, 0.62))
			_knob_hits.append({"rect": chip2, "payload": {"knob": "action", "id": k.get("id", "")}})
		y += line_h


## The inspector's on-canvas rect this frame (Rect2() = not shown). MainView uses it to PIN the hover
## while the cursor travels onto the panel — the same "the open map is UI" rule the minimap follows.
func hover_panel_rect() -> Rect2:
	return _hover_rect


## The knob payload under a canvas point ({} = none). Read by MainView on LMB — the HUD never touches
## the sim; the controller turns the payload into a discrete sim call.
func hover_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _knob_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			return hit["payload"]
	return {}


## Draw a run of item chips (a colour swatch + count) left-to-right; returns the x just past them.
func _chips(x0: float, y: float, items: Array) -> float:
	var x: float = x0
	for entry: Dictionary in items:
		var item: StringName = entry["item"]
		var sw := Rect2(x, y - 11.0, 12.0, 12.0)
		if machine_icons.has(item):
			draw_rect(sw, machine_icons[item]["color"])
		else:
			draw_rect(sw, Visuals.item_color(item))
		draw_rect(sw, Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
		var label: String = " %d" % int(entry["count"])
		draw_string(_font, Vector2(x + 14.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.92, 0.93, 0.96))
		x += 14.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
	return x


func _arrow(x: float, y: float) -> float:
	draw_string(_font, Vector2(x, y), "->", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.74, 0.82))
	return x + _font.get_string_size("->", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0


func draw_string_pos(x: float, y: float, text: String) -> float:
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.66, 0.74))
	return x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0


## Where the minimap sits RIGHT NOW (canvas space) — corner (top-right, small) or LARGE (centred).
## Public: MainView uses it to route map-clicks to the PING and to keep world verbs off the map.
##
## Both forms FIT the world's aspect inside a box rather than deriving one side from the other. A corner
## map sized by width alone was fine while the world was 96x80 and became a 150x150 slab down half the
## screen the moment it went square — a corner element has a height budget as much as a width one, and
## the world's shape is not the HUD's to assume.
func minimap_frame() -> Rect2:
	var world := Vector2(float(FactorySim.GRID_COLS), float(FactorySim.GRID_ROWS))
	if minimap_large:
		var big: Vector2 = _fit(world, Vector2(360.0, 272.0))
		return Rect2((CANVAS - big) * 0.5, big)
	var small: Vector2 = _fit(world, Vector2(MINI_W, MINI_H))
	return Rect2(Vector2(CANVAS.x - small.x - 12.0, MINI_TOP), small)


## The largest rect with `aspect`'s proportions that fits inside `box`.
func _fit(aspect: Vector2, box: Vector2) -> Vector2:
	return aspect * minf(box.x / aspect.x, box.y / aspect.y)


## The MINIMAP (M — corner; M again — LARGE): a cached image of the whole world — solid cells in their
## material colour, carved/dug cells as a dim wall backing, open sky as void — with the live overlays of
## Minimap 2.0: DEPTH BANDS (the violet seal line + the cold Stonereach wash below it),
## your machines, BAZAAR diamonds, a pulsing BREACH marker on every opened way down, your PING (click
## the map to set/clear it — the in-world beacon is the renderer's), the visible window, and YOU. The
## terrain image rebuilds only when you DIG (sim.solid changes), so per-frame cost is one textured blit.
func _draw_minimap() -> void:
	if sim == null or not minimap_color.is_valid():
		return
	if _minimap_tex == null or sim.solid.size() != _minimap_solid_count:
		_minimap_solid_count = sim.solid.size()
		_rebuild_minimap()
	var cols: float = float(FactorySim.GRID_COLS)
	var rows: float = float(FactorySim.GRID_ROWS)
	var frame: Rect2 = minimap_frame()
	var origin: Vector2 = frame.position
	_panel(frame.grow(3.0))
	draw_texture_rect(_minimap_tex, frame, false)
	var scale := Vector2(frame.size.x / cols, frame.size.y / rows)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)   # cosmetic clock — HUD only
	# --- depth bands: the layer ladder made legible at a glance ---
	var seal_y: float = origin.y + float(LayeredWorldGen.SEAL_TOP) * scale.y
	var seal_h: float = maxf(float(LayeredWorldGen.SEAL_ROWS) * scale.y, 1.5)
	draw_rect(Rect2(origin.x, seal_y + seal_h, frame.size.x, frame.end.y - (seal_y + seal_h)),
		Color(0.35, 0.50, 0.95, 0.10))                                  # Stonereach: a cold wash
	draw_rect(Rect2(origin.x, seal_y, frame.size.x, seal_h), Color(0.62, 0.42, 0.85, 0.55))  # THE SEAL
	# THE DESCENT CHART. The large map used to name exactly two bands, TOPSOIL and STONEREACH, and it
	# put the first of them immediately above the seal — which is the deepslate, sixty rows from any
	# topsoil. Every band Strata knows about now gets a hairline at its ceiling and its own name in its
	# own colour, so the map answers "how far down does this go, and what is between here and there"
	# at a glance. That is the whole reason to open a map in a game about descending.
	if minimap_large:
		for i: int in range(1, Strata.BANDS.size()):     # skip OPEN SKY: it has no ceiling to draw
			var band: Dictionary = Strata.BANDS[i]
			var by: float = origin.y + float(int(band["from"])) * scale.y
			if by < origin.y or by > frame.end.y - 6.0:
				continue
			var tint: Color = band["color"]
			draw_line(Vector2(origin.x, by), Vector2(frame.end.x, by), Color(tint, 0.30), 1.0)
			# A thin band (THE SEAL is two rows) would stack its name on top of the one below it. Every
			# band keeps its LINE; the one that loses its text is the shallower of a colliding pair,
			# because the deeper name is the one telling you what you are about to be in.
			if i + 1 < Strata.BANDS.size():
				var next_y: float = origin.y + float(int(Strata.BANDS[i + 1]["from"])) * scale.y
				if next_y - by < 9.0:
					continue
			draw_string(_font, Vector2(origin.x + 5.0, by + 8.0), str(band["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(tint, 0.80))
			var depth: String = "%d m" % Strata.depth_m(int(band["from"]))
			var dw: float = _font.get_string_size(depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string(_font, Vector2(frame.end.x - dw - 5.0, by + 8.0), depth,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(tint, 0.55))
	# --- AQUIFERS: the flooded pockets that guard rich ore. A distinct cool cyan-blue (clear of the
	# amber power wash, the gold bazaars, and the violet seal/breach), alpha scaling with fill so deep
	# water reads solid, a puddle reads faint. Live overlay: water FLOWS each tick, not in the cached bake.
	var wcell: Vector2 = Vector2(maxf(scale.x, 1.0), maxf(scale.y, 1.0)).ceil()
	for water_cell_v: Variant in sim.water:
		var water_cell: Vector2i = water_cell_v
		var fill: float = clampf(float(sim.water[water_cell]) / float(FactorySim.WATER_MAX), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(water_cell) * scale, wcell),
			Color(0.25, 0.62, 0.95, 0.30 + 0.45 * fill))
	# --- FRONTIER REACH: where the factory's POWER and placed LIGHT actually extend —
	# "your reach is how deep you can survive" read straight off the map. Power = a warm amber wash
	# per powered cell (brighter = more units, live off the derived sim.power field); placed torches =
	# small warm halos. Subtle alphas so terrain stays readable under the claim.
	for pcell_v: Variant in sim.power:
		var pcell: Vector2i = pcell_v
		var lvl: float = clampf(float(sim.power[pcell]) / FactorySim.GENERATOR_POWER, 0.12, 1.0)
		draw_rect(Rect2(origin + Vector2(pcell) * scale, scale.ceil()),
			Color(1.0, 0.70, 0.22, 0.10 + 0.24 * lvl))
	var halo: float = maxf(scale.x, scale.y) * 2.6
	for tcell_v: Variant in sim.torch:
		draw_circle(origin + (Vector2(tcell_v as Vector2i) + Vector2(0.5, 0.5)) * scale, halo,
			Color(1.0, 0.80, 0.42, 0.16))
	# --- your placed machines ---
	var dot := Vector2(maxf(scale.x, 2.0), maxf(scale.y, 2.0))
	for m: MachineState in sim.machines:
		draw_rect(Rect2(origin + Vector2(m.cell) * scale, dot), Visuals.machine_color(m.def))
	# --- bazaars: the crafting hubs wear a gold diamond ---
	for o: Vector2i in sim.find_bazaars():
		_map_diamond(origin + (Vector2(o) + Vector2(float(FactorySim.BAZAAR_W) * 0.5, 1.0)) * scale,
			3.5, Color(0.98, 0.84, 0.35))
	# --- breach markers: every opened way down pulses violet (find it again from anywhere) ---
	for m: MachineState in sim.machines:
		if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA:
			_map_diamond(origin + (Vector2(m.cell) + Vector2(0.5, 0.5)) * scale,
				3.0 + pulse * 2.5, Color(0.80, 0.55, 1.0, 0.55 + 0.45 * pulse))
	# --- your ping ---
	if ping_world.x != INF:
		var pc: Vector2 = origin + ping_world / CELL * scale
		draw_line(pc + Vector2(-4.0, 0.0), pc + Vector2(4.0, 0.0), Color(0.45, 0.95, 1.0), 1.0)
		draw_line(pc + Vector2(0.0, -4.0), pc + Vector2(0.0, 4.0), Color(0.45, 0.95, 1.0), 1.0)
		draw_arc(pc, 4.0 + pulse * 3.0, 0.0, TAU, 20, Color(0.45, 0.95, 1.0, 0.9 - pulse * 0.5), 1.0)
	if minimap_view.length() > 1.0:                            # the visible window
		var half: Vector2 = minimap_view * 0.5 / CELL
		var fc: Vector2 = minimap_focus / CELL
		var vr := Rect2(origin + (fc - half) * scale, minimap_view / CELL * scale)
		draw_rect(vr.intersection(frame), Color(1.0, 1.0, 1.0, 0.55), false, 1.0)
	var you := origin + minimap_focus / CELL * scale           # you-are-here marker
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.97, 0.86, 0.36))
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.10, 0.08, 0.0), false, 1.0)
	if minimap_large:
		var cap: String = "click the map to ping · M cycles size"
		var cw: float = _font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_rect(Rect2(origin.x + 3.0, frame.end.y - 17.0, cw + 10.0, 14.0), Color(0.05, 0.06, 0.09, 0.8))
		draw_string(_font, Vector2(origin.x + 8.0, frame.end.y - 6.0), cap,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)


## A small filled diamond — the minimap's icon shape (reads at 3-5px where a square blurs into terrain).
func _map_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)


## Rebuild the cached terrain image: one pixel per cell — solid = material colour, dug-but-walled = a
## dim wall backing (the carved room), open sky = void. Cheap; runs only when terrain changes.
func _rebuild_minimap() -> void:
	var w: int = FactorySim.GRID_COLS
	var h: int = FactorySim.GRID_ROWS
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var cell := Vector2i(x, y)
			var c: Color
			if sim.is_solid(cell):
				c = minimap_color.call(sim.material_at(cell))
			elif sim.wall_at(cell) != &"":
				c = (minimap_color.call(sim.wall_at(cell)) as Color).darkened(0.5)
			else:
				c = Color(0.09, 0.11, 0.16)
			img.set_pixel(x, y, c)
	_minimap_tex = ImageTexture.create_from_image(img)


## THE BAZAAR'S GEOMETRY — one shape, computed in one place, read by both the draw and the layout test, so
## seen == tested. Nothing here depends on where you are standing, which is the half of the original claim
## that still holds: the panel that changes shape depending on where you are is the panel you cannot learn.
##
## What it DOES depend on now is what the open tab holds — `h` through `_bazaar_wanted_h`, and the plate
## through `_detail_wanted_h`. Both are read here rather than recomputed, so the content box is bought out
## of the same number the plate is drawn at and the two cannot overlap or leave a gap between them. The
## plate's depth is a property of the SELECTION, but the kinds a selection can have partition by tab
## (`bazaar_action`), so it is constant while a tab is open — which is what keeps a cursor move from
## reflowing the rows the cursor is moving through.
##
## The shape is a rail, a head, a grid of rows, and a DETAIL PLATE across the bottom. The plate is the whole
## argument of #S34: the old layout gave the goods a 16px glyph on a 22px row and then left a third of the
## panel empty, so nothing in the shop was ever drawn large enough to want. Rows are for choosing between;
## the plate is for wanting. Splitting those two jobs is also what let the rows get denser — a row no longer
## has to carry a description, because there is somewhere for the description to live.
func _bazaar_geometry() -> Dictionary:
	var h: float = _bazaar_h
	var origin := Vector2((CANVAS.x - BAZAAR_SIZE.x) * 0.5, (CANVAS.y - h) * 0.5)
	var inner_x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	var inner_w: float = BAZAAR_SIZE.x - BAZAAR_RAIL - BAZAAR_PAD * 2.0
	var body_h: float = h - BAZAAR_HEAD - BAZAAR_FOOT
	var plate: float = _detail_wanted_h()
	var content := Rect2(inner_x, origin.y + BAZAAR_HEAD, inner_w,
		body_h - plate - BAZAAR_DETAIL_GAP)
	var detail := Rect2(inner_x, content.end.y + BAZAAR_DETAIL_GAP, inner_w, plate)
	return {
		"origin": origin, "w": BAZAAR_SIZE.x, "h": h,
		"content": content, "detail": detail, "cols": BAZAAR_COLS,
		"col_w": (content.size.x - BAZAAR_GUTTER * float(BAZAAR_COLS - 1)) / float(BAZAAR_COLS),
		"row_h": BAZAAR_ROW_H,
		"rows": int(content.size.y / BAZAAR_ROW_H),
	}


## HOW TALL THE COUNTER WANTS TO BE, for the tab that is open.
##
## EVERY TERM HERE COMES FROM THE FUNCTION THAT DRAWS IT, never from a second copy of its arithmetic. A
## height computed from a duplicated layout rule is a number that is right on the day it is written and
## silently wrong the day either copy moves -- and this panel already has one instance of that in its
## history (`_cycle_inventory` wrapping modulo a count the drawing did not share). So `_pack_cols` is the
## single source for the well grid, `_works_rows_needed` asks `works_columns` itself rather than
## re-deriving the split, `_bench_tiers` is the tier walk lifted out of `_tab_bench` whole, and the plate
## term is `_detail_wanted_h` rather than the constant it sometimes equals.
func _bazaar_wanted_h() -> float:
	if sim == null:
		return BAZAAR_SIZE.y
	var inner_w: float = BAZAAR_SIZE.x - BAZAAR_RAIL - BAZAAR_PAD * 2.0
	var need: float = 0.0
	match bazaar_tab:
		TAB_WORKS:
			need = float(_works_rows_needed()) * BAZAAR_ROW_H
		TAB_BENCH:
			# The tree sizes its own chips down to fit whatever it is given; what it WANTS is the tallest
			# tier at full chip height. Today that asks for more than the panel may ever be, so BENCH is
			# clamped and unchanged -- which is the correct outcome, not a coincidence to rely on.
			var tall: int = maxi(1, _bench_tallest())
			need = float(tall) * 64.0 + float(tall - 1) * 6.0
		_:
			# The wells AND the summary band under them. The band was missing from this sum, and the
			# summary's own guard was testing against a content box this sum had already decided, so the
			# two could only agree by accident and did not. `_ledger_h` carries the reasoning.
			need = float(_pack_rows(inner_w)) * PACK_CELL + _ledger_h()
	return clampf(BAZAAR_HEAD + need + BAZAAR_DETAIL_GAP + _detail_wanted_h() + BAZAAR_FOOT,
		BAZAAR_MIN_H, BAZAAR_SIZE.y)


## HOW TALL THE PLATE WANTS TO BE, for the thing that is selected — the move above, one level down, and the
## number every site that positions against the plate reads. There is deliberately no second copy of it:
## `_bazaar_geometry` buys the content box out of this, the panel's asking height adds this, and
## `_draw_bazaar_detail` takes the art square back off the rect it is handed, so the plate's depth is stated
## once and everything else is downstream of it.
##
## THE PLATE EXPANDS FOR A CHOICE. A machine, a Rack row and a rung of the ladder all cost something, and
## the chip row that says whether you can afford it is what the full 88 is for. What is already in your pack
## has no price to weigh and PACK's summary of the line is not a purchase at all, so both of those get the
## compact plate — the same title and blurb, one fact under them, and no chips.
##
## KEYED ON THE SELECTION, not on the tab, because it is the CONTENT that decides. The kinds partition by tab
## all the same (`bazaar_action`: PACK yields "hold" or nothing, WORKS "machine" and "rack", BENCH "tech"),
## which is what makes the depth constant while a tab is open — see `_bazaar_geometry` on why that matters.
func _detail_wanted_h() -> float:
	if sim == null:
		return BAZAAR_DETAIL
	match str(bazaar_action().get("kind", "")):
		"machine", "rack", "tech":
			return BAZAAR_DETAIL
		_:
			return BAZAAR_DETAIL_MIN


## How many wells fit across the content, and how many rows they take. `_tab_pack` calls the first of these
## rather than keeping its own copy of the division.
func _pack_cols(w: float) -> int:
	return maxi(1, int(w / PACK_CELL))


func _pack_rows(w: float) -> int:
	var n: int = sim.inventory_slots().size()
	return maxi(1, ceili(float(n) / float(_pack_cols(w))))


## The fewest rows at which the two WORKS lists fit the counter's columns — asked of `works_columns`
## itself, so the squeeze rule and this measure can never disagree. Fresh: machines 4 + rack 6 fit in three
## columns at four rows. Full tech (machines 19, rack 7) it wants ten rows, which asks for more height than
## the counter has and is clamped — which is the squeeze the panel already applies, arrived at from the
## other side.
func _works_rows_needed() -> int:
	for r: int in range(1, 25):
		if int(works_demand(r)["total"]) <= BAZAAR_COLS:
			return r
	return 24


## The research tree, grouped by how many prerequisites deep each tech is. Lifted out of `_tab_bench` so
## the drawing and the sizing read the same tiers.
func _bench_tiers() -> Array:
	var tiers: Array = []
	for tid: StringName in ResearchRules.ORDER:
		var d: int = 0
		var cur: StringName = ResearchRules.tech(tid).get("requires", &"")
		while cur != &"":
			d += 1
			cur = ResearchRules.tech(cur).get("requires", &"")
		while tiers.size() <= d:
			tiers.append([])
		(tiers[d] as Array).append(tid)
	return tiers


func _bench_tallest() -> int:
	var tallest: int = 1
	for tier: Array in _bench_tiers():
		tallest = maxi(tallest, tier.size())
	return tallest


## WHAT THE COUNTER WILL SELL YOU TODAY — the indices of the rows whose tech is already yours.
##
## #S34b: WORKS used to list the whole catalogue, sixteen machines deep, thirteen of them greyed out behind
## techs you had not reached. That is decision paralysis dressed as content: a wall of things you cannot have
## in the place you go to get things. The future has a home already — it is the BENCH, where every locked
## machine sits under the rung that unlocks it, greyed, in the one screen whose whole job is "what comes
## next". So the counter shows what you can BUILD and the ladder shows what you could build LATER, and
## neither one has to do both jobs badly.
func _unlocked(ids: Array[StringName], n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		var id: StringName = ids[i] if i < ids.size() else &""
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock == &"" or sim.is_researched(lock):
			out.append(i)
	return out


func open_machines() -> Array[int]:
	return _unlocked(craft_ids, craft_options.size())


func open_rack() -> Array[int]:
	return _unlocked(rack_ids, rack_options.size())


## How many columns each WORKS group takes, at this row height. Groups are laid left to right and never
## share a column, because the left list is what you BUILD from your own materials and the right is what you
## BUY with refined goods — a player should never have to work out which is which from a row's position.
func works_columns(rows: int) -> Dictionary:
	var want: Dictionary = works_demand(rows)
	var m: int = int(want["machines"])
	var r: int = int(want["rack"])
	# The counter has a fixed number of columns, so if the two lists ever ask for more than it has, they get
	# SQUEEZED rather than allowed to run off the panel's edge — the group that overflows falls back to a
	# window around the cursor, which is ugly but reachable. This clamp is the FAILURE MODE made legible
	# instead of invisible, not the intended layout.
	#
	# THE PROPERTY, CORRECTED — and the correction is the more interesting half. This said "today the two
	# lists together ask for no more columns than the counter has, so this branch never fires." IT FIRES.
	# Measured on the real scene:
	#
	#   FRESH      machines= 4 rack= 6   ask 1+1=2 of 3   no squeeze
	#   FULL TECH  machines=19 rack= 7   ask 3+1=4 of 3   SQUEEZED, granted 2+1
	#
	# So it fires for every player who finishes the tech tree, which makes the "safety valve" the late-game
	# NORMAL. `check_pack_layout` did hold the unsqueezed property correctly — it asks the DEMAND rather
	# than this function's already-clamped answer, which was a real repair — but it only ever evaluated it
	# in the fresh state, where it cannot fail. A property true where it is checked and false where it is
	# not is the same shape as an assertion that cannot fail, wearing better clothes.
	#
	# The squeeze is kept, because the alternative is worse and that was measured too: a fourth column is
	# 124.5px, and `_works_row` would give the name about 48px, truncating every machine. Three columns and
	# a cursor window is the design. `works_window_first` is what makes the window testable.
	if m + r > BAZAAR_COLS:
		r = clampi(r, 1, BAZAAR_COLS - 1)
		m = BAZAAR_COLS - r
	return {"machines": m, "rack": r, "total": m + r}


## WHAT THE TWO LISTS ASK FOR at a given row count, BEFORE the squeeze — and the split exists because a
## caller that needs the demand and gets the grant reads a constant.
##
## `works_columns` clamps its answer to `BAZAAR_COLS`, so its `total` is never above three whatever the
## catalogue does. `_works_rows_needed` scanned for the first row count whose total fits, got three at one
## row, and sized the counter for a single row of WORKS — the panel came out at its floor with the content
## squeezed to 36px. The file's own comment eighteen lines above says exactly this about a different
## caller: *"it asks the DEMAND rather than this function's already-clamped answer."* Reading that and then
## writing the clamped version anyway is the whole reason it is now a separate function with a name.
func works_demand(rows: int) -> Dictionary:
	var m: int = maxi(1, ceili(float(open_machines().size()) / float(maxi(rows, 1))))
	var r: int = maxi(1, ceili(float(open_rack().size()) / float(maxi(rows, 1))))
	return {"machines": m, "rack": r, "total": m + r}


## How many rows the active tab offers the cursor. WORKS is the two lists end to end; BENCH is the ladder.
func bazaar_row_count() -> int:
	match bazaar_tab:
		TAB_WORKS:
			return open_machines().size() + open_rack().size()
		TAB_BENCH:
			return ResearchRules.ORDER.size()
		_:
			return sim.inventory_slots().size()


## WHAT ENTER WOULD DO, as {kind, id} — kind is "machine", "rack", "tech" or "". The panel owns the cursor
## because the panel draws it; MainView owns the verbs. Splitting it this way means the highlighted row and
## the thing that happens can never drift apart, which is the bug that made `R` two different keys.
func bazaar_action() -> Dictionary:
	var i: int = bazaar_row
	match bazaar_tab:
		TAB_WORKS:
			if i < 0 or i >= bazaar_row_count():
				return {}
			# The cursor walks the OPEN rows; `row` is the index into the full catalogue, because that is
			# what MainView's verbs are keyed on. Filtering the view must never renumber the world.
			var open_m: Array[int] = open_machines()
			if i < open_m.size():
				return {"kind": "machine", "id": _craft_id(open_m[i]), "row": open_m[i]}
			var r: int = open_rack()[i - open_m.size()]
			return {"kind": "rack", "id": rack_ids[r] if r < rack_ids.size() else &"", "row": r}
		TAB_BENCH:
			if i < 0 or i >= ResearchRules.ORDER.size():
				return {}
			return {"kind": "tech", "id": ResearchRules.ORDER[i], "row": i}
		_:
			# PACK's verb is HOLD. It was the one tab with a cursor and nothing to do with it, which is also
			# why it read as half a screen — and holding a thing from the pack screen is exactly what the
			# stateless bit-equipping wants (`BitRules`): what is in your hand is what you dig with.
			var slots: Array[Dictionary] = sim.inventory_slots()
			if i < 0 or i >= slots.size():
				return {}
			return {"kind": "hold", "id": slots[i]["item"], "row": i}


## Move the cursor. `dy` steps a row; `dx` jumps a whole COLUMN, which is the same motion your eye makes and
## is what carries you across the counter-to-Rack gap in one keystroke rather than in ten.
func bazaar_move(dx: int, dy: int) -> void:
	var n: int = bazaar_row_count()
	if n <= 0:
		return
	if dx != 0:
		bazaar_row = clampi(bazaar_row + dx * int(_bazaar_geometry()["rows"]), 0, n - 1)
	bazaar_row = clampi(bazaar_row + dy, 0, n - 1)


## Change tab, keeping each tab's place in its own list.
##
## RE-PICKING THE TAB YOU ARE ALREADY ON STILL MEANS "BACK TO THE TOP". That is the same call and the same
## outcome it has always had (pressing 2 while WORKS is up), and it is the only way left to send the cursor
## home now that leaving and returning no longer does it.
func set_bazaar_tab(tab: int) -> void:
	var want: int = clampi(tab, TAB_PACK, TAB_BENCH)
	# Sized from the tab list itself, on first use, so a fourth tab does not need this line changed and
	# cannot index past the end of the store. `resize` fills the new slots with zero, which is row one.
	if _bazaar_rows.size() < TAB_NAMES.size():
		_bazaar_rows.resize(TAB_NAMES.size())
	if want == bazaar_tab:
		bazaar_row = 0
		_bazaar_rows[want] = 0
		return
	_bazaar_rows[bazaar_tab] = bazaar_row
	bazaar_tab = want
	# A LIST CAN SHRINK UNDER A STORED INDEX WHILE YOU ARE AWAY FROM IT: you spend the last of a material
	# and its well leaves the pack, a machine you were looking at gets built and the rack row goes. So the
	# stored row is re-clamped against the count the tab has NOW, never the one it had when you left it.
	# `bazaar_row_count()` reads the sim on two of the three tabs, so a HUD without one keeps the old
	# behaviour of landing at the top rather than reaching through a null.
	var n: int = bazaar_row_count() if sim != null else 0
	bazaar_row = clampi(_bazaar_rows[want], 0, maxi(n - 1, 0))
	_bazaar_rows[want] = bazaar_row


## THE COUNTER. Drawn as a lamp-lit object rather than as a dialog box: elevation instead of a border, a
## gradient instead of a fill, one accent doing one job, and a 0.13s rise on open so it ARRIVES.
func _draw_inventory_overlay() -> void:
	# DIMMED, NOT BLACKED. You are at a counter with a shopkeeper standing next to you and banners over your
	# head — the staging `scenes/bazaars.gd` builds block by block — so the world stays legible behind the
	# panel instead of being switched off the moment you open it. MainView blurs it in the same breath
	# (`_bazaar_blur`), which is what makes the panel read as being IN FRONT of something.
	var t: float = _bazaar_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var panel := Rect2(origin, Vector2(g["w"], g["h"]))
	# The whole counter rises the last few pixels into place. One transform, so nothing below has to know.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)

	_soft_shadow(panel, 12, 0.34)
	_round_rect(panel, 8.0, Color(0.062, 0.070, 0.094, 0.985))
	_panel_sheen(panel)
	# The rail is the tab strip, turned on its side and given room to be an object. Three icons you can hit
	# with a glance beat three words you have to read.
	_draw_bazaar_rail(origin, g)
	_draw_bazaar_head(origin, g)
	match bazaar_tab:
		TAB_WORKS:
			_tab_works(g)
		TAB_BENCH:
			_tab_bench(g)
		_:
			_tab_pack(g)
	_draw_bazaar_detail(g)
	_draw_bazaar_foot(origin, g)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## ONE KEY, DRAWN AS A KEY. A bare digit painted in the corner of a tile reads as a step number, which is
## what makes a three-tab counter feel like a three-page wizard; the same digit inside a raised cap reads as
## something to press. Returns the width it consumed so a row of them lays out without measuring twice.
func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	var tw: float = _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w: float = maxf(tw + 8.0, 14.0)
	var h: float = float(fs) + 7.0
	var box := Rect2(at, Vector2(w, h))
	_round_rect(Rect2(box.position + Vector2(0.0, 1.0), box.size), 3.0, Color(0.0, 0.0, 0.0, 0.35))
	_round_rect(box, 3.0, Color(0.13, 0.145, 0.18))
	draw_string(_font, at + Vector2((w - tw) * 0.5, h - 5.0), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.74, 0.78, 0.86))
	return w


## The rail: three tabs as glyphs, the live one lit and carrying a brass edge. The key that selects it rides
## under each glyph as a cap, because a key legend nobody can find is a key nobody presses.
func _draw_bazaar_rail(origin: Vector2, g: Dictionary) -> void:
	var rail := Rect2(origin, Vector2(BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, Color(0.043, 0.049, 0.070, 0.92))
	# THE RAIL'S PITCH FOLLOWS THE PANEL, and the arithmetic that makes it follow now lives in
	# `_rail_slots`, shared with the settings rail. At full height these are the numbers they always were
	# — top 62, pitch 58 — and on a short counter they close up rather than running off the bottom edge.
	var ys: Array = _rail_slots(rail, 3)
	for i: int in 3:
		var y: float = ys[i]
		var on: bool = i == bazaar_tab
		var box := Rect2(rail.position.x + 9.0, y, 38.0, 38.0)
		if on:
			_round_rect(box, 6.0, RAIL_ON_FILL)
			draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UI_ACCENT)
		_rail_glyph(box.get_center(), i, on)
		var label: String = TAB_NAMES[i]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + 48.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UI_TEXT if on else Color(0.36, 0.39, 0.45))
		_keycap(Vector2(box.get_center().x - 7.0, y + 51.0), str(i + 1), 7)


## The three tab glyphs, drawn rather than lettered: a satchel, a gear, a ladder of rungs.
func _rail_glyph(at: Vector2, kind: int, on: bool) -> void:
	var col: Color = Color(0.949, 0.831, 0.549) if on else Color(0.40, 0.43, 0.50)
	match kind:
		TAB_PACK:
			draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(16.0, 11.0)), col)
			draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 1.8)
		TAB_WORKS:
			draw_arc(at, 6.5, 0.0, TAU, 20, col, 2.2)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				draw_line(at + Vector2(cos(a), sin(a)) * 6.5, at + Vector2(cos(a), sin(a)) * 9.5, col, 1.8)
		_:
			for i: int in 3:
				draw_rect(Rect2(at.x - 8.0 + float(i) * 2.0, at.y + 5.0 - float(i) * 6.0,
					16.0 - float(i) * 4.0, 2.6), col)


## The materials the open tab is pricing in, in the order that tab lists them, and empty for a tab that
## prices nothing.
##
## The head strip used to be a literal six written into the drawing function, and against the prices it is
## read next to it was wrong in both directions. `ore` is the cost of nothing the counter sells: no
## `craft_cost` in `src/data/machines/*.tres` names it, no rung in `src/data/research_rules.gd` does, and
## neither does a tool or bit recipe (`MiningRules.TOOL_RECIPES`, `BitRules.BIT_RECIPES`). Three materials
## that ARE costs could never appear at all: `plate` and `gear` (research_rules.gd:69, 81, 96, and the
## craft costs of the Crusher, Blast Furnace, Drift Rig and Borer) and `iron` (iron_forge.tres:14).
## A strip assembled by hand cannot follow a cost table it has no link to, so it stops following it the
## first time either one moves.
##
## Reading the costs is also the answer to where the strip belongs. It is a global account of the pack,
## but it is only ever READ against a price, so it lives on the tabs that quote prices. PACK returns
## nothing here: every chip it drew was a second copy of a well two rows underneath it, since the grid
## below already lists the same ids with the same counts out of the same `sim.inventory`.
##
## BENCH walks the whole ladder rather than the reachable rungs, because the tree draws the whole ladder.
## A tech's sample material is a real cost and is deliberately not in here: it is not in the rung's `cost`
## dictionary either, and `_shortfall_note` is the one place that names it.
func _priced_materials() -> Array[StringName]:
	var out: Array[StringName] = []
	match bazaar_tab:
		TAB_WORKS:
			for i: int in open_machines():
				_price_items(craft_options[i]["cost"], out)
			for i: int in open_rack():
				_price_items(rack_options[i]["cost"], out)
		TAB_BENCH:
			for tid: StringName in ResearchRules.ORDER:
				_price_items(ResearchRules.tech(tid).get("cost", {}), out)
	return out


func _price_items(cost: Dictionary, out: Array[StringName]) -> void:
	for item: StringName in cost:
		if not out.has(item):
			out.append(item)


## The head: who you are talking to, which counter you are at, and what you are carrying of what this tab
## charges, as chips you can count without reading.
func _draw_bazaar_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	_tracked("BAZAAR", Vector2(x, origin.y + 29.0), 17, 2.8, UI_TEXT)
	var tab_x: float = x + _tracked_w("BAZAAR", 17, 2.8) + 16.0
	_tracked(TAB_NAMES[bazaar_tab], Vector2(tab_x, origin.y + 29.0), 17, 2.8, Color(0.26, 0.28, 0.34))
	# The strip stops one panel pad short of the title's last stroke, measured off the title rather than
	# guessed at. It was `x + 170.0`, which is a statement about the widths of "BAZAAR" and the longest tab
	# name at 17pt with 2.8 of tracking, with nothing in the file relating it to either: move the type size
	# and the guess is wrong in whichever direction nobody looks.
	var floor_x: float = tab_x + _tracked_w(TAB_NAMES[bazaar_tab], 17, 2.8) + BAZAAR_PAD
	var rx: float = origin.x + float(g["w"]) - BAZAAR_PAD
	# A material priced but not held draws no chip, which is the behaviour this loop always had. The
	# shortfall for the thing under the cursor is answered per ingredient on the detail plate instead
	# (`_detail_chip`, `_shortfall_note`), and a strip of zeroes for everything the ladder will ever charge
	# would be a wall of what you do not have on the tab where you are choosing what to do next.
	for item: StringName in _priced_materials():
		var n: int = int(sim.inventory.get(item, 0))
		if n <= 0:
			continue
		var label: String = str(n)
		var cw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 25.0
		rx -= cw + 5.0
		if rx < floor_x:
			break
		_round_rect(Rect2(rx, origin.y + 6.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(self, Vector2(rx + 11.0, origin.y + 16.0), 13.0, item)
		draw_string(_font, Vector2(rx + 19.0, origin.y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)


## The footer is now one line: the keys. What you are carrying moved to the head as chips, and where the
## verbs live moved onto the verb BUTTON, where it is answering the question you are actually asking.
func _draw_bazaar_foot(origin: Vector2, g: Dictionary) -> void:
	# ONE INPUT GRAMMAR, AND IT IS THE RAIL'S. This was a single run-on string using double spaces as
	# structure, which reads as prose and gets skipped like prose: keys and verbs sat at the same weight, so
	# nothing in the line said which half was the thing to press. Each key is a cap now with its verb beside
	# it at the old dim weight, so the eye lands on the key.
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	var y: float = origin.y + float(g["h"]) - 15.0
	for pair: Array in [["up/dn", "pick"], ["1-3", "tab"], ["E", "close"]]:
		x += _keycap(Vector2(x, y), str(pair[0]), 8) + 5.0
		var label: String = str(pair[1])
		draw_string(_font, Vector2(x, y + 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.34, 0.37, 0.43))
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0


# --- the tabs -------------------------------------------------------------------------------------------

## PACK — the whole carried inventory as a grid of wells, given the whole width. It is the same pack it
## always was; it simply stopped sharing a 360px column with two other screens.
func _tab_pack(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var slots: Array[Dictionary] = sim.inventory_slots()
	var cell: float = PACK_CELL
	var cols: int = _pack_cols(content.size.x)
	# The wells are served first and the summary gets what is left. `_bazaar_wanted_h` asks for both, so
	# below the panel's height cap this subtraction takes nothing the grid needed; above the cap the band
	# is what gives way, because the grid is the tab's subject and the summary is a footnote on it.
	#
	# maxi(1, ...) rather than the slot count, so an empty pack reserves the one row `_pack_rows` charged
	# the panel for and the band lands where the height was bought. An empty pack with a running factory
	# is a real state, not a corner: it is what standing at the counter having just fed everything in
	# looks like, and it is the state `_detail_pack` exists for.
	var rows: int = maxi(1, (slots.size() + cols - 1) / cols)
	var band: float = clampf(content.size.y - float(rows) * cell, 0.0, _ledger_h())
	var wells := Rect2(content.position, Vector2(content.size.x, content.size.y - band))
	if slots.is_empty():
		draw_string(_font, content.position + Vector2(2.0, 20.0), "(empty — go dig)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT_DIM)
		_pack_ledger(Rect2(wells.position.x, wells.end.y, content.size.x, band))
		return
	var held: int = inv_selected_getter.call() if inv_selected_getter.is_valid() else -1
	for i: int in slots.size():
		var box := Rect2(content.position.x + float(i % cols) * cell, content.position.y + float(i / cols) * cell,
			cell - 6.0, cell - 6.0)
		if box.end.y > wells.end.y:
			break
		var item: StringName = slots[i]["item"]
		var hot: bool = box.has_point(Controls.pointer_viewport(self))
		var picked: bool = i == bazaar_row
		if picked:
			_round_rect(box, 5.0, Color(0.176, 0.153, 0.098))
			draw_rect(Rect2(box.position + Vector2(0.0, 3.0), Vector2(2.0, box.size.y - 6.0)), UI_ACCENT)
		else:
			_round_rect(box, 5.0, Color(1.0, 1.0, 1.0, 0.062 if hot else 0.030))
		if hot:
			_tooltip_item = item
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(box.get_center().x, box.position.y)
		_draw_thing_icon(item, Rect2(box.position + Vector2(8.0, 5.0),
			Vector2(box.size.x - 16.0, box.size.y - 17.0)))
		draw_string(_font, box.position + Vector2(box.size.x - 13.0, box.size.y - 4.0),
			str(int(slots[i]["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
		# The thing actually in your hand wears a mark, because "what am I holding" is the question the pack
		# screen is opened to answer and the hotbar is behind the panel while it is open.
		if i == held:
			draw_string(_font, box.position + Vector2(5.0, 12.0), "HELD",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.949, 0.831, 0.549))
	_pack_ledger(Rect2(wells.position.x, wells.end.y, content.size.x, band))


## How tall the summary under the wells is, and 0.0 when it has nothing to say. `_bazaar_wanted_h` adds
## this to what PACK asks for and `_tab_pack` takes the same number back off the bottom of the grid, so
## the band the summary draws into and the height the panel was sized to are one piece of arithmetic run
## twice rather than two numbers that have to agree.
##
## They were two numbers, and they did not agree. The summary tested `top > content.end.y - 30.0`, which
## needs `content.size.y >= rows*46 + 44`, while PACK's asking height was head + wells + gap + plate +
## foot with no term for the summary in it, so `content` came out at exactly `rows*46`. Short by 44px at
## every row count, and past four rows of wells the panel is at its 348 cap and the shortfall only widens.
## The summary has therefore been reaching the screen at no settled height at all: only on the frames
## where `_bazaar_h` is still easing down from a taller tab, or from the 348 it initialises to. Measured
## across 1, 2, 3, 4, 5 and 6 rows of wells, the guard's two sides came back 185/141, 208/164, 231/187,
## 254/210, 298/212 and 344/212, which is a block that has never once been photographed in a settled
## frame and has been reviewed from the ones where the panel was still moving.
##
## Four rows because the band is bought out of the grid above it. At four the band is
## 14 + 12 + 3*17 + 7 = 84px, which a one-row and a two-row pack both still fit under the 348 cap.
const LEDGER_GAP: float = 14.0        ## last row of wells to the header's baseline
const LEDGER_HEAD: float = 12.0       ## header baseline to the first row's baseline
const LEDGER_ROW: float = 17.0        ## row pitch
const LEDGER_TAIL: float = 7.0        ## last baseline to the bottom of the bar sitting on it
const LEDGER_MAX: int = 4             ## goods listed; the verdict shares the header's line
func _ledger_h() -> float:
	if sim == null:
		return 0.0
	var n: int = mini(LEDGER_MAX, sim.production_rates().size())
	if n <= 0:
		return 0.0
	return LEDGER_GAP + LEDGER_HEAD + float(n - 1) * LEDGER_ROW + LEDGER_TAIL


## What the line takes back. Per input item, how many of it a minute the placed recipe machines are
## consuming, derived from the measured output rates and nothing else: a forge measured at 2.2 ingot/min
## has, by smelt_ingot's 2 ore for 1 ingot (src/data/recipes/smelt_ingot.tres), consumed exactly 4.4
## ore/min. The ratio is the recipe's and the rate is the sim's, so there is no capacity model here and
## nothing to calibrate.
##
## Returns {"draw": item -> per minute, "eater": item -> the machine's display name or "" when more than
## one type is eating it, "mute": item -> true for the ones this cannot speak about}.
##
## The mute set is the point. Two placed machine types can output the same good, and a measured ingot rate
## cannot be split between a Forge turning 2 ore into 1 and a Blast Furnace turning 1 rich_ore into 2
## (smelt_ingot.tres, smelt_rich.tres). Attributing the whole rate to either one invents the other's
## throughput, so every input of every candidate recipe goes mute instead: no bar, no clause, and out of
## the verdict. Silence is the only honest output there, and it is a different state from an item nothing
## consumes, which reports as a real zero.
##
## Machines that run their own tick rather than the recipe runner carry no recipe inputs to add up here:
## a drill's mine_ore has none, and the descent engine eats ingots through DESCENT_EATS
## (src/core/factory_sim.gd:149) with no recipe at all. So the clause names the machines this did add up
## and says "to the Forge" rather than "consumed", which is true whatever else is also eating.
func _line_offtake() -> Dictionary:
	var makers: Dictionary = {}                       # output item -> [{recipe, name}, ...]
	for row: Dictionary in sim.machine_census():
		var rec: RecipeDef = (row["def"] as MachineDef).recipe
		if rec == null or rec.inputs.is_empty():
			continue
		for out: StringName in rec.outputs:
			if not makers.has(out):
				makers[out] = []
			(makers[out] as Array).append({"recipe": rec, "name": str(row["name"])})
	var taken: Dictionary = {}
	var eater: Dictionary = {}
	var mute: Dictionary = {}
	for r: Dictionary in sim.production_rates():
		var out: StringName = r["item"]
		var mk: Array = makers.get(out, [])
		if mk.is_empty():
			continue
		if mk.size() > 1:
			for m: Dictionary in mk:
				for item: StringName in (m["recipe"] as RecipeDef).inputs:
					mute[item] = true
			continue
		var rec: RecipeDef = mk[0]["recipe"]
		var per: float = float(int(rec.outputs[out]))
		if per <= 0.0:
			continue
		var who: String = str(mk[0]["name"])
		for item: StringName in rec.inputs:
			taken[item] = float(taken.get(item, 0.0)) \
				+ float(r["rate"]) * float(int(rec.inputs[item])) / per
			# Two machine types can share one ingredient (the Gear Mill and the Plate Press both eat iron
			# ingots), and the total stays right while the name stops being. Naming neither beats naming
			# whichever the census happened to yield last.
			eater[item] = who if not eater.has(item) or str(eater[item]) == who else ""
	return {"draw": taken, "eater": eater, "mute": mute}


## Under the grid: what the factory is making for you, and what the rest of the line does with it.
##
## It was a list of rates and one bar grammar for all of them, scaled to whichever rate was largest. That
## is a readout, and it is a readout that flattens the one thing worth reading: a bar drawn as a share of
## the fastest number on the panel makes a trickle of a refined good and a flood of a common raw look like
## the same kind of fact at two lengths, and the length moves when an unrelated row moves.
##
## So the bar is not a magnitude any more. It is the share of that item's own income the line is taking
## back, which is a 0..1 quantity meaning the same thing on every row, and the /min number beside it keeps
## the magnitude. Rows split themselves into two kinds out of the data rather than out of a rule: an item
## the line consumes gets a bar and a clause naming what is eating it, an item nothing on the line touches
## gets neither, and an item the offtake cannot attribute gets neither and says nothing.
##
## The verdict on the header's line is the decision the rows only imply. It is chosen over the items the
## line actually consumes, so it is always about a live flow rather than about the earth and stone a
## hand-mining player's rate list is otherwise full of. A deficit outranks a surplus: a step drawing more
## than its feed earns is a step that will stall, and a pile that is growing can wait.
func _pack_ledger(band: Rect2) -> void:
	var rates: Array[Dictionary] = sim.production_rates()
	if rates.is_empty() or band.size.y <= 0.0:
		return
	var off: Dictionary = _line_offtake()
	var taken: Dictionary = off["draw"]
	var eater: Dictionary = off["eater"]
	var mute: Dictionary = off["mute"]
	var hb: float = band.position.y + LEDGER_GAP
	var head: String = "YOUR LINE IS MAKING"
	_tracked(head, Vector2(band.position.x + 1.0, hb), 8, 2.0, Color(0.451, 0.365, 0.180))
	var vx: float = band.position.x + 1.0 + _tracked_w(head, 8, 2.0) + 12.0
	var verdict: String = _ledger_verdict(rates, off)
	if verdict != "" and band.end.x > vx:
		draw_string(_font, Vector2(vx, hb), verdict, HORIZONTAL_ALIGNMENT_RIGHT, band.end.x - vx, 9,
			UI_TEXT)
	# Columns: glyph, name, the rate right-aligned against the bar's left edge, the bar, the clause. The
	# bar is 120 rather than the old `min(240, width/2)` because a share does not need half the panel to be
	# read and the clause beside it does need the room: at 528 of content that leaves 246px for it.
	var bar_x: float = band.position.x + 154.0
	var bar_w: float = 120.0
	for i: int in mini(LEDGER_MAX, rates.size()):
		var y: float = hb + LEDGER_HEAD + float(i) * LEDGER_ROW
		if y + LEDGER_TAIL > band.end.y:
			return
		var item: StringName = rates[i]["item"]
		var rate: float = float(rates[i]["rate"])
		Visuals.draw_item(self, Vector2(band.position.x + 8.0, y + 3.0), 13.0, item)
		draw_string(_font, Vector2(band.position.x + 18.0, y + 7.0), _item_label(item),
			HORIZONTAL_ALIGNMENT_LEFT, 80.0, 9, UI_TEXT)
		draw_string(_font, Vector2(band.position.x + 100.0, y + 7.0), "%.1f/min" % rate,
			HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 9, UI_TEXT)
		var took: float = float(taken.get(item, 0.0))
		if mute.has(item) or took <= 0.0 or rate <= 0.0:
			continue
		_round_rect(Rect2(bar_x, y - 3.0, bar_w, 10.0), 3.0, Color(1.0, 1.0, 1.0, 0.035))
		# The item's own colour rather than the panel's gold. The dashboard's throughput bars already read
		# this way (`Visuals.item_color`), and gold on this screen means selected, affordable and the live
		# verb, which is not what a share of an income is.
		_round_rect(Rect2(bar_x, y - 3.0, maxf(3.0, bar_w * clampf(took / rate, 0.0, 1.0)), 10.0), 3.0,
			Color(Visuals.item_color(item), 0.62))
		var who: String = str(eater.get(item, ""))
		var clause: String = "%.1f/min back into the line" % took
		if who != "":
			clause = "%.1f/min to the %s" % [took, who]
		draw_string(_font, Vector2(bar_x + bar_w + 8.0, y + 7.0), clause,
			HORIZONTAL_ALIGNMENT_LEFT, band.end.x - bar_x - bar_w - 8.0, 9, UI_TEXT_DIM)


## The one line of the summary that asks for a decision instead of reporting a number. Empty when the
## offtake has nothing it can speak about, which is the same silence the rows keep in that state.
func _ledger_verdict(rates: Array[Dictionary], off: Dictionary) -> String:
	var taken: Dictionary = off["draw"]
	var mute: Dictionary = off["mute"]
	# Empty because nothing refines anything, and empty because everything that does is unattributable, are
	# two different states and only the first of them is a fact about the factory. Measured: place a Forge
	# and a Blast Furnace together and the offtake goes to {} with ore and rich_ore muted, which read as
	# "nothing on the line refines any of it yet" while two machines were refining it.
	if taken.is_empty():
		return "" if not mute.is_empty() else "nothing on the line refines any of it yet"
	var by_item: Dictionary = {}
	for r: Dictionary in rates:
		by_item[r["item"]] = float(r["rate"])
	var pick: StringName = &""
	var spare: float = 0.0
	for item: StringName in taken:
		if mute.has(item):
			continue
		var s: float = float(by_item.get(item, 0.0)) - float(taken[item])
		# A deficit wins outright, and between two of the same sign the larger one wins.
		var better: bool = (s < 0.0 and spare >= 0.0) \
			or (spare < 0.0 and s < spare) \
			or (spare >= 0.0 and s > spare)
		if pick == &"" or better:
			pick = item
			spare = s
	if pick == &"":
		return ""
	var label: String = _item_label(pick).to_lower()
	var who: String = str((off["eater"] as Dictionary).get(pick, ""))
	if who == "":
		who = "line"
	if spare < 0.0:
		return "the %s outruns your %s by %.1f/min" % [who, label, -spare]
	return "%.1f %s/min spare past the %s" % [spare, label, who]


## WORKS — the counter (what you BUILD from your own materials) and the Rack (what you BUY with refined
## goods), as a dense card grid. No scrolling, no scrollbar, no shift-digit.
func _tab_works(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var rows: int = int(g["rows"])
	var lay: Dictionary = works_columns(rows)
	# The columns SPREAD to fill the counter. Once WORKS lists only what you can build, most of the game is
	# two columns rather than three, and three columns' worth of narrow rows with an empty third is exactly
	# the dead space this rebuild exists to kill. Capped, because a row wide enough to lose its price at the
	# far end is its own problem.
	var used: int = maxi(1, int(lay["total"]))
	var col_w: float = minf(268.0,
		(content.size.x - BAZAAR_GUTTER * float(used - 1)) / float(used))
	var open_m: Array[int] = open_machines()
	var open_r: Array[int] = open_rack()
	_works_group(content, 0, int(lay["machines"]), col_w, rows, "MACHINES", craft_options, open_m, 0, true)
	_works_group(content, int(lay["machines"]), int(lay["rack"]), col_w, rows, "THE RACK",
		rack_options, open_r, open_m.size(), false)
	# ...and one quiet line saying the rest exists and where it lives. Hiding the locked half is only honest
	# if the panel still tells you there IS a locked half — otherwise the counter looks finished at four
	# machines and the tech ladder looks optional.
	var hidden: int = (craft_options.size() - open_m.size()) + (rack_options.size() - open_r.size())
	if hidden > 0:
		# The key is a cap and not a word in a sentence. "press 3 for the BENCH" asks the reader to parse an
		# instruction to find the one glyph that matters; the cap grammar the rail and footer already use
		# puts it where the eye lands, and the sentence shrinks to what it is actually saying.
		var dim := Color(0.451, 0.402, 0.280)
		var y: float = content.end.y - 2.0
		var head: String = "%d more wait behind research" % hidden
		draw_string(_font, Vector2(content.position.x + 1.0, y), head,
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x, 9, dim)
		var x: float = content.position.x + 1.0 \
			+ _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
		x += _keycap(Vector2(x, y - 10.0), "3", 8) + 5.0
		draw_string(_font, Vector2(x, y), "BENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)


## THE WINDOW'S FIRST ROW. A group shorter than its columns starts at 0 and this is a no-op; a longer one
## shows `capacity` rows centred on the cursor, clamped so it never runs past either end of the list.
##
## IT IS THE LATE-GAME NORMAL, NOT A SAFETY VALVE, and the comment beside the clamp in `works_columns` used
## to say the opposite — *"today the two lists together ask for no more columns than the counter has, so
## this branch never fires."* Measured on the real scene: fresh, MACHINES and THE RACK ask for 1+1 of 3 and
## it does not fire; with the tech tree finished they hold 19 and 7 and ask for 3+1 of 3, and it fires for
## every player who gets there. `check_pack_layout` only ever evaluated the unsqueezed property in the
## fresh state, so a claim that is false for a finished game read as green for as long as it existed.
##
## Three columns and a window is nonetheless the right answer rather than a fourth column: 528px of content
## over four columns is 124.5px a row, and `_works_row` gives the name `width - 36 - cost glyphs`, about
## 48px at size 10. Four columns truncates every machine name. Measured before choosing.
static func works_window_first(count: int, capacity: int, base: int, cursor: int) -> int:
	if count <= capacity:
		return 0
	return clampi(cursor - base - capacity / 2, 0, count - capacity)


## One GROUP — a list poured down as many columns as it needs, left to right. `base` is where the group
## starts in the panel's flat cursor index, so the highlight and `bazaar_action()` cannot disagree.
func _works_group(content: Rect2, col0: int, cols: int, col_w: float, rows: int, title: String,
		opts: Array[Dictionary], open_rows: Array[int], base: int, machines: bool) -> void:
	var x0: float = content.position.x + float(col0) * (col_w + BAZAAR_GUTTER)
	_tracked(title, Vector2(x0 + 1.0, content.position.y - 6.0), 8, 2.0, Color(0.451, 0.365, 0.180))
	if open_rows.is_empty():
		draw_string(_font, Vector2(x0 + 1.0, content.position.y + 16.0), "(nothing unlocked yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
		return
	# A group longer than its columns shows a WINDOW around the cursor rather than truncating. Named and
	# lifted out of this loop so `check_pack_layout` can assert a PROPERTY of what the drawing code
	# computes — that the cursor is always inside the window — instead of re-deriving the arithmetic and
	# agreeing with itself. It also runs headless, which `_works_group` cannot: this only executes inside
	# `_draw`.
	var capacity: int = rows * cols
	var first: int = works_window_first(open_rows.size(), capacity, base, bazaar_row)
	for i: int in mini(capacity, open_rows.size()):
		var oi: int = open_rows[first + i]
		var rr := Rect2(x0 + float(i / rows) * (col_w + BAZAAR_GUTTER),
			content.position.y + float(i % rows) * BAZAAR_ROW_H, col_w, BAZAAR_ROW_H - 3.0)
		_works_row(rr, opts[oi], _works_id(machines, oi), base + first + i == bazaar_row)


func _works_id(machines: bool, i: int) -> StringName:
	if machines:
		return _craft_id(i)
	return rack_ids[i] if i < rack_ids.size() else &""


## One row. A CARD, not an outlined box: a surface tint you can see through to the panel, a well for the
## glyph, and — when it is the one the cursor is on — a brass edge and a warmer fill. Nothing is outlined,
## because an outline around every row makes every row shout and the selected one shout no louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = _can_afford(opt["cost"])
	if selected:
		_round_rect(rr, 4.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 2.0), Vector2(2.0, rr.size.y - 4.0)), UI_ACCENT)
	else:
		_round_rect(rr, 4.0, Color(1.0, 1.0, 1.0, 0.030))
	_draw_thing_icon(id, Rect2(rr.position + Vector2(6.0, 2.5), Vector2(16.0, 16.0)))
	var name_col: Color = (Color(0.949, 0.831, 0.549) if selected else UI_TEXT) if afford \
		else Color(0.48, 0.50, 0.56)
	var cw: float = _cost_glyphs(rr, opt["cost"])
	draw_string(_font, rr.position + Vector2(26.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 36.0 - cw, 10, name_col)


## The price as GLYPHS, not as prose. "6 Iron Ingot 3 Wood" is a hundred pixels of a hundred-and-seventy
## pixel row, and it was clipping the NAME off the thing you were buying — "Iron Pickax", "Blast Furnac".
## The same fact as two icons and two numbers is forty, and it reads faster besides: you are matching a
## picture against the chips in the head rather than parsing a sentence. Green when the pack covers it, red
## when it does not, per ingredient, so a short list says WHICH thing is short.
func _cost_glyphs(rr: Rect2, cost: Dictionary) -> float:
	var w: float = 0.0
	for item: StringName in cost:
		w += 12.0 + _font.get_string_size(str(int(cost[item])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	var x: float = rr.end.x - 5.0 - w
	for item: StringName in cost:
		var n: int = int(cost[item])
		Visuals.draw_item(self, Vector2(x + 6.0, rr.position.y + 10.5), 12.0, item)
		var label: String = str(n)
		draw_string(_font, Vector2(x + 13.0, rr.position.y + 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.482, 0.796, 0.518) if int(sim.inventory.get(item, 0)) >= n else Color(0.804, 0.427, 0.376))
		x += 12.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	return w


## A machine's sprite or an item's glyph, whichever this id is. Both the pack grid, the works rows and the
## tech chips want exactly this and used to each carry their own copy of it.
func _draw_thing_icon(id: StringName, box: Rect2) -> void:
	if machine_icons.has(id):
		var spr: Texture2D = Art.tex("machine_" + String(id))
		if spr != null:
			draw_texture_rect(spr, box, false)
			return
		draw_rect(box, machine_icons[id]["color"])
		Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
			str(machine_icons[id]["kind"]), box.size.y / 20.0, false, 0.0)
		return
	if id != &"":
		Visuals.draw_item(self, box.position + box.size * 0.5, box.size.y, id)


## THE COUNTER HAS EXACTLY ONE VERB BUTTON, and until now it was drawn twice from two sets of numbers.
##
## It was never photographed live. `capture_moments` set `_hud.can_craft = true` and `main.gd:793`
## recomputed it from `_near_bazaar()` before the shutter, so every menu capture in the archive shows the
## dead branch of this if. The first frame ever taken with `ready` true read **`BUILDENTER`** — the key
## hint starting four pixels after the verb's last stroke, at 10pt against 8pt, which is one word.
##
## `_detail_hold` drew the same construct with the hint hardcoded at `x + 58.0`, a ~20px gap, so the two
## buttons in the same plate disagreed by a factor of five about how far apart a verb and its key sit. Both
## numbers were guesses; only one of them was ever looked at.
##
## And the fixed 104px plate could not hold the longest verb this screen produces. RESEARCH is eight
## tracked characters — the button was sized for BUY.
##
## So: one function, one gap constant, and a width that is DERIVED from the verb rather than asserted over
## it. The button stays anchored to the plate's right edge, so growing it moves its left edge inward and
## nothing downstream shifts. Returns the rect it drew, because the caller prints the precondition note
## centred above it.
const VERB_SIZE: int = 10
const VERB_TRACK: float = 2.0
const VERB_HINT_SIZE: int = 8
const VERB_GAP: float = 14.0          ## verb ink → key hint. 4.0 was the shipped value and it read as one word.
const VERB_PAD: float = 12.0          ## plate edge → ink, both ends
const VERB_MIN_W: float = 104.0       ## BUY and BUILD keep the width the layout was drawn around
const VERB_H: float = 24.0
## How wide the button has to be for this verb. Separate from the drawing because the blurb beside it wraps
## against the button's left edge, and a blurb that wraps against a guessed width runs under a real one.
func _verb_button_w(verb: String, hint: String) -> float:
	var hw: float = 0.0 if hint == "" else _font.get_string_size(
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_HINT_SIZE).x
	return maxf(VERB_MIN_W, VERB_PAD * 2.0 + _tracked_w(verb, VERB_SIZE, VERB_TRACK)
		+ (0.0 if hint == "" else VERB_GAP + hw))


func _verb_button(box: Rect2, verb: String, hint: String, live: bool) -> Rect2:
	var vw: float = _tracked_w(verb, VERB_SIZE, VERB_TRACK)
	var w: float = _verb_button_w(verb, hint)
	var btn := Rect2(box.end.x - w - 10.0, box.position.y + box.size.y - 34.0, w, VERB_H)
	var ty: float = btn.position.y + 16.0
	if live:
		_round_rect(btn, 5.0, UI_ACCENT)
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK,
			Color(0.08, 0.07, 0.04))
		if hint != "":
			draw_string(_font, Vector2(btn.position.x + VERB_PAD + vw + VERB_GAP, ty), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_HINT_SIZE, Color(0.08, 0.07, 0.04, 0.62))
	else:
		_round_rect(btn, 5.0, Color(1.0, 1.0, 1.0, 0.05))
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK,
			Color(0.44, 0.46, 0.52))
	return btn


# --- the detail plate -----------------------------------------------------------------------------------

## THE DETAIL PLATE. The selected thing, drawn large under a lamp, with one sentence of what it is for, its
## price as have/need chips, and the verb as a real button carrying the key that runs it.
##
## This is where the panel stops being a list and starts being a shop. It also puts the three answers a
## player is actually after — what is this, can I afford it, what do I press — in one place, at one glance,
## instead of spread across a row, a footer and a manual.
##
## AND IT IS WHERE THE PLATE'S SHARE OF THE PANEL IS DECIDED, because the plate is the height of what it
## draws and this is what draws it. A thing on sale gets the full 88 and everything in it; a thing you
## already own gets the compact plate, which is the same card with the price taken out of it.
func _draw_bazaar_detail(g: Dictionary) -> void:
	var box: Rect2 = g["detail"]
	_round_rect(box, 6.0, Color(1.0, 1.0, 1.0, 0.028))
	# The one place the art square is built, for all three plates: `_detail_hold` and `_detail_pack` are
	# handed this rect rather than each writing the margin down again. It is READ OFF THE PLATE — the square
	# is what is left of the plate's height once its margins are taken — so at the full depth it is the
	# `DETAIL_ART` that `BAZAAR_DETAIL` is built from and at the compact depth it is whatever fits beside the
	# text, and neither of them can drift from what `_detail_wanted_h` handed the geometry.
	var side: float = box.size.y - DETAIL_PAD * 2.0
	var art := Rect2(box.position + Vector2(DETAIL_PAD, DETAIL_PAD), Vector2(side, side))
	var act: Dictionary = bazaar_action()
	var kind: String = str(act.get("kind", ""))
	if kind == "":
		_detail_pack(box, art)
		return
	var id: StringName = act["id"]
	if kind == "hold":
		_detail_hold(box, art, id, int(act.get("row", 0)))
		return
	var title: String = ""
	var blurb: String = ""
	var cost: Dictionary = {}
	var verb: String = ""
	var ready: bool = false
	var note: String = ""
	if kind == "tech":
		var t: Dictionary = ResearchRules.tech(id)
		title = str(t["name"])
		cost = t["cost"]
		var sample: StringName = t.get("sample", &"")
		# What it BUYS you, by name. A ladder that only prices its rungs is asking you to buy a number; the
		# reason to climb is the machines waiting at the top of it, and now that WORKS lists only what you
		# can already build, this plate is the only place those machines are named at all.
		var names: PackedStringArray = []
		for uid: StringName in (t.get("unlocks", []) as Array):
			names.append(_thing_label(uid))
		if not names.is_empty():
			blurb = "unlocks " + " · ".join(names)
		elif sample != &"":
			blurb = "analyze a sample of %s, then pour in the metal" % _item_label(sample)
		else:
			blurb = "a rung of the ladder — spend the metal, keep the knowledge"
		if sample != &"" and not names.is_empty():
			blurb += "\nanalyze a sample of %s, then pour in the metal" % _item_label(sample)
		var next: StringName = ResearchRules.next_tech(sim.research)
		if sim.is_researched(id):
			verb = "RESEARCHED"
			note = "already yours"
		elif id != next:
			verb = "LOCKED"
			var req: StringName = t.get("requires", &"")
			note = "behind %s" % (str(ResearchRules.tech(req)["name"]) if req != &"" else "an earlier rung")
		else:
			verb = "RESEARCH"
			ready = can_craft and _can_afford(cost) \
				and (sample == &"" or int(sim.inventory.get(sample, 0)) >= 1)
			note = "at a claimed Bazaar" if not can_craft else _shortfall_note(cost, sample)
	else:
		var opts: Array[Dictionary] = craft_options if kind == "machine" else rack_options
		var row: int = int(act.get("row", 0))
		if row < 0 or row >= opts.size():
			return
		title = str(opts[row]["name"])
		cost = opts[row]["cost"]
		blurb = str(ITEM_PURPOSE.get(id, "—"))
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock != &"" and not sim.is_researched(lock):
			verb = "LOCKED"
			note = "research %s first" % str(ResearchRules.tech(lock)["name"])
		else:
			verb = "BUILD" if kind == "machine" else "BUY"
			ready = can_craft and _can_afford(cost)
			note = "at a claimed Bazaar" if not can_craft else _shortfall_note(cost, &"")

	_detail_lamp(art, 0.045)
	if kind == "tech":
		_draw_tech_art(id, art)
	else:
		_draw_thing_icon(id, _detail_glyph(art))

	var tx: float = art.end.x + 14.0
	var text_w: float = box.end.x - tx - _verb_button_w(verb, "ENTER" if ready else "") - 24.0
	_tracked(title.to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, Color(0.949, 0.831, 0.549))
	draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y), blurb,
		HORIZONTAL_ALIGNMENT_LEFT, text_w, 9, DETAIL_BLURB_LINES, UI_TEXT_DIM)
	# The price as have/need chips: "can I afford this" answered in the same glance as "what does it cost".
	var cx: float = tx
	for item: StringName in cost:
		var need: int = int(cost[item])
		var have: int = int(sim.inventory.get(item, 0))
		cx = _detail_chip(Vector2(cx, box.position.y + 62.0), item, need, have) + 6.0

	var btn: Rect2 = _verb_button(box, verb, "ENTER" if ready else "", ready)
	if note != "":
		var nw: float = _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(_font, Vector2(btn.get_center().x - nw * 0.5, btn.position.y - 6.0), note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.58, 0.48, 0.32))


## THE LAMP. Three rings behind the goods is the whole trick, and it is what makes a glyph read as lit
## rather than as big. All three plates light their square the same way and each of them used to say so in
## its own numbers, which was survivable while every square was 68 across and stopped being survivable the
## moment the compact plate gave one of them a smaller square: a radius written as 34 hangs a third of the
## outer ring over the edge of a 52px square and out through the side of the plate.
func _detail_lamp(art: Rect2, alpha: float) -> void:
	var r: float = art.size.x * 0.5
	for k: int in 3:
		draw_circle(art.get_center(), r * (1.0 - float(k) * DETAIL_LAMP_STEP),
			Color(0.85, 0.70, 0.35, alpha))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))


## The thing itself, inside the square. Same reason: it is the square inset by a rim rather than a 44 written
## at two of the three plates and a 40 at the third, which were the same intent recorded twice at sizes that
## differ by nothing anyone decided, and both of which overflow the compact square. `_draw_tech_art` keeps
## its own composition — it lays four unlock icons out in the square rather than centring one thing in it,
## and a tech is only ever selected on BENCH, where the plate is always at full depth.
func _detail_glyph(art: Rect2) -> Rect2:
	return art.grow(-DETAIL_GLYPH_INSET)


## WHY THE BUTTON IS DEAD, when the reason is the pack and not the place.
##
## The plate has always had a line for the precondition it cannot meet — "at a claimed Bazaar", "behind
## Automation", "research Ironworks first" — and every one of those fires for a reason OUTSIDE the pack.
## Stand at a counter you cannot afford anything at and the line was blank: a grey button, no sentence, and
## a red numeral in a price chip as the only account of why nothing happens when you press ENTER.
##
## That gap was invisible for as long as the captures were, because a fixture standing away from the Bazaar
## always took the "at a claimed Bazaar" branch — the one state where the note is never empty. **The screen
## explained every blocker except the one a player actually hits.**
##
## Says the DEFICIT and not the price, because the price is already on the chips two lines up and repeating
## it answers a question nobody asked. The sample material (a tech's analysis input) is a cost the chips do
## NOT show, so it is named here or it is named nowhere.
func _shortfall_note(cost: Dictionary, sample: StringName) -> String:
	var parts: PackedStringArray = []
	for item: StringName in cost:
		var gap: int = int(cost[item]) - int(sim.inventory.get(item, 0))
		if gap > 0:
			parts.append("%d %s" % [gap, _item_label(item)])
	if sample != &"" and int(sim.inventory.get(sample, 0)) < 1:
		parts.append("a sample of %s" % _item_label(sample))
	return "" if parts.is_empty() else "short " + " · ".join(parts)


## A machine's display name if it is one, an item's label otherwise. The tech ladder names both.
func _thing_label(id: StringName) -> String:
	if machine_icons.has(id):
		return str(machine_icons[id]["name"])
	return _item_label(id)


## A tech has no glyph of its own — it is knowledge — so its plate shows WHAT IT BUYS: the machines it
## unlocks, laid out big. That is also the honest answer to "why would I research this", which a lamp icon
## would not have been.
func _draw_tech_art(tid: StringName, art: Rect2) -> void:
	var unlocks: Array = ResearchRules.tech(tid).get("unlocks", [])
	if unlocks.is_empty():
		Visuals.draw_item(self, art.get_center(), 40.0, &"ingot")
		return
	var n: int = mini(4, unlocks.size())
	if n == 1:
		_draw_thing_icon(unlocks[0], Rect2(art.get_center() - Vector2(21.0, 21.0), Vector2(42.0, 42.0)))
		return
	var cell: float = 25.0
	var cols: int = 2
	var span := Vector2(float(cols) * cell, float((n + cols - 1) / cols) * cell)
	var at: Vector2 = art.get_center() - span * 0.5
	for i: int in n:
		_draw_thing_icon(unlocks[i], Rect2(at + Vector2(float(i % cols) * cell + 2.0,
			float(i / cols) * cell + 2.0), Vector2(cell - 4.0, cell - 4.0)))


## The plate for a thing you are CARRYING: what it is for, how many you have, and the one verb the pack
## screen has — put it in your hand.
##
## TWO QUANTITIES, TWO WORDS, AND NEITHER OF THEM BORROWS THE OTHER'S. This one plate used to say
## "carrying 24" next to a button reading "IN HAND", over a grid whose lit well was badged "HELD": three
## words for what a player reads as one relationship, on the shallowest plate in the panel. Carrying,
## holding and having in hand are the same thing in English, so "carrying 24" could be read as 24 of them
## in your hand.
##
## So the pack owns one vocabulary and the hand owns the other. What you have is IN THE PACK, the word the
## tab, the plate title and the head's chips already use. What you are wielding is HELD, the past tense of
## the button beside it, so the badge on the well and the dead button now say the same word as each other.
##
## The lifetime figure is ALL TOLD with no verb in front of it, because there is no verb that is true of
## every row: this plate prices ore you mined, wood you chopped and ingots your line poured, and "gathered"
## was wrong for the third exactly as "made" is wrong for the first two. Against "in the pack" the contrast
## carries it. It is the only per-item total on any screen; the FORGED chip counts ingots and says so.
func _detail_hold(box: Rect2, art: Rect2, id: StringName, row: int) -> void:
	_detail_lamp(art, 0.045)
	_draw_thing_icon(id, _detail_glyph(art))
	var tx: float = art.end.x + 14.0
	_tracked(_item_label(id).to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8,
		Color(0.949, 0.831, 0.549))
	draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y),
		str(ITEM_PURPOSE.get(id, "—")), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 260.0, 9,
		DETAIL_BLURB_LINES, UI_TEXT_DIM)
	# THE TALLY SITS WHERE THE BLURB ENDS, not at a baseline of its own. It used to be written 76 down a
	# plate that was always 88, which is the shop's chip row's depth borrowed by a plate that has no chips —
	# and this is the plate that no longer has the height to spare. `DETAIL_FACT_Y` is the last line the
	# blurb can reach, and it is also the sum the compact plate's height is built out of, so the fact cannot
	# be placed below the plate that was sized to hold it.
	var carried: int = int(sim.inventory.get(id, 0))
	var made: int = int(sim.total_produced.get(id, 0))
	draw_string(_font, Vector2(tx, box.position.y + DETAIL_FACT_Y),
		"%d in the pack   ·   %d all told" % [carried, made],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.36, 0.39, 0.45))
	var held: int = inv_selected_getter.call() if inv_selected_getter.is_valid() else -1
	if row == held:
		_verb_button(box, "HELD", "", false)
	else:
		_verb_button(box, "HOLD", "ENTER", true)


## PACK has nothing to buy, so its plate answers the other question a pack screen is asked: what is the
## factory actually making for you while you stand here.
func _detail_pack(box: Rect2, art: Rect2) -> void:
	_detail_lamp(art, 0.035)
	Visuals.draw_item(self, art.get_center(), _detail_glyph(art).size.x, &"ingot")
	var tx: float = art.end.x + 14.0
	_tracked("THE PACK", Vector2(tx, box.position.y + 24.0), 13, 1.8, Color(0.949, 0.831, 0.549))
	var rates: Array[Dictionary] = sim.production_rates()
	if rates.is_empty():
		draw_string(_font, Vector2(tx, box.position.y + 42.0),
			"nothing is running — build a Forge at the WORKS tab and feed it ore",
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 120.0, 9, UI_TEXT_DIM)
		return
	draw_string(_font, Vector2(tx, box.position.y + 42.0), "your line is making",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	# The rate chips sit ON the compact plate's last line — the same `DETAIL_FACT_Y` the hold plate's tally
	# uses, so the one plate that has two contents puts them both in the same place, and the row the plate's
	# height was built to hold is the row the chips are drawn in rather than one written 50 down beside it.
	var cx: float = tx
	var base: float = box.position.y + DETAIL_FACT_Y
	for i: int in mini(5, rates.size()):
		var item: StringName = rates[i]["item"]
		var label: String = "%.1f/min" % float(rates[i]["rate"])
		var cw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 25.0
		if cx + cw > box.end.x - 12.0:
			break
		_round_rect(Rect2(cx, base - 14.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(self, Vector2(cx + 11.0, base - 4.0), 13.0, item)
		draw_string(_font, Vector2(cx + 19.0, base), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.72, 0.42))
		cx += cw + 6.0


## One have/need chip. Green when the pack covers it, red when it does not — the affordability answer given
## per ingredient rather than as one verdict, so a short shopping list says WHICH thing is short.
func _detail_chip(at: Vector2, item: StringName, need: int, have: int) -> float:
	# HAVE OVER NEED, which is what the three comments above this one have always said it was and what the
	# code did not do. It drew `need/have`, so a fresh save priced the Forge at "3/0" — a fraction with a
	# zero denominator, in the one screen state nobody had ever photographed — and a finished save priced
	# it at "3/64", which reads as five percent of the way there while you are carrying twenty-one times
	# what it asks. The numerator is now the number that MOVES while you play, which is also the one the
	# affordability colour belongs on.
	var label: String = "%d/%d" % [have, need]
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 26.0
	_round_rect(Rect2(at, Vector2(w, 19.0)), 4.0, Color(1.0, 1.0, 1.0, 0.05))
	Visuals.draw_item(self, at + Vector2(11.0, 9.5), 13.0, item)
	var ok: bool = have >= need
	draw_string(_font, at + Vector2(19.0, 13.5), str(have), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.482, 0.796, 0.518) if ok else Color(0.804, 0.427, 0.376))
	var hw: float = _font.get_string_size(str(have), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, at + Vector2(19.0 + hw, 13.5), "/%d" % need, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.36, 0.39, 0.45))
	return at.x + w


# --- the bench ------------------------------------------------------------------------------------------

## BENCH — the research ladder as a graph, AND the verb that acts on it, on one screen.
##
## This is the fix for the worst of the six: the tree used to be a separate full-screen overlay on `T` that
## showed you the ladder you could not act on, because the research verb lived back inside the pack screen.
## You read here and acted there. Now the ladder is a tab of the same counter, a cursor walks it, and the
## SELECTED rung is the one the detail plate prices and the one Enter takes.
##
## Tiers derive from each tech's `requires` chain, so a branching tree simply stacks its chips in a column
## and no layout changes. The chips are SCALED to the panel rather than the panel to the chips: the ladder
## grows, the counter does not.
func _tab_bench(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var tiers: Array = _bench_tiers()
	if tiers.is_empty():
		return
	var tallest: int = _bench_tallest()
	var gap := Vector2(10.0, 6.0)
	var chip := Vector2(
		minf(108.0, (content.size.x - float(tiers.size() - 1) * gap.x) / float(tiers.size())),
		minf(64.0, (content.size.y - float(tallest - 1) * gap.y) / float(tallest)))
	var span := Vector2(float(tiers.size()) * chip.x + float(tiers.size() - 1) * gap.x,
		float(tallest) * chip.y + float(tallest - 1) * gap.y)
	var at := Vector2(content.position.x + (content.size.x - span.x) * 0.5,
		content.position.y + (content.size.y - span.y) * 0.5)
	var rects: Dictionary = {}
	for ti: int in tiers.size():
		var tier: Array = tiers[ti]
		var col_h: float = float(tier.size()) * chip.y + float(tier.size() - 1) * gap.y
		for ni: int in tier.size():
			rects[tier[ni]] = Rect2(at + Vector2(float(ti) * (chip.x + gap.x),
				(span.y - col_h) * 0.5 + float(ni) * (chip.y + gap.y)), chip)
	# Arrows first, under the chips: the prereq's right edge to the dependent's left edge. A path you have
	# already walked glows, so the tree reads as a route rather than as a table.
	for tid: StringName in ResearchRules.ORDER:
		var req: StringName = ResearchRules.tech(tid).get("requires", &"")
		if req == &"" or not rects.has(req):
			continue
		var a: Rect2 = rects[req]
		var b: Rect2 = rects[tid]
		var p0 := Vector2(a.end.x, a.position.y + a.size.y * 0.5)
		var p1 := Vector2(b.position.x, b.position.y + b.size.y * 0.5)
		var lc: Color = Color(0.48, 0.72, 0.52, 0.85) if sim.is_researched(req) \
			else Color(0.26, 0.29, 0.36, 0.85)
		draw_line(p0, p1, lc, 1.5)
		draw_colored_polygon(PackedVector2Array([p1, p1 + Vector2(-5.0, -3.5), p1 + Vector2(-5.0, 3.5)]), lc)
	var next: StringName = ResearchRules.next_tech(sim.research)
	var picked: StringName = &""
	var act: Dictionary = bazaar_action()
	if act.get("kind", "") == "tech":
		picked = act["id"]
	for tid: StringName in ResearchRules.ORDER:
		_draw_tech_chip(tid, rects[tid], tid == next, tid == picked)


## One tech chip: a lamp, a name, and the machines it unlocks. Its PRICE moved to the detail plate — a chip
## that carried the price had to shrink the name to fit it, and a truncated name ("Prospecti") costs the
## player more than a second glance downward does.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool, picked: bool = false) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = sim.is_researched(tid)
	if picked:
		_round_rect(rr, 5.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 3.0), Vector2(2.0, rr.size.y - 6.0)), UI_ACCENT)
	elif done:
		_round_rect(rr, 5.0, Color(0.078, 0.113, 0.086))
	else:
		_round_rect(rr, 5.0, Color(1.0, 1.0, 1.0, 0.040 if is_next else 0.022))
	var name_col: Color = Color(0.48, 0.70, 0.52) if done \
		else ((Color(0.949, 0.831, 0.549) if picked else UI_TEXT) if is_next else Color(0.40, 0.42, 0.48))
	var narrow: bool = rr.size.x < 96.0
	var indent: float = 15.0 if narrow else 19.0
	# The largest size the NAME actually fits at, rather than a size picked from the chip's width. A chip
	# guessed from its own geometry printed "Prospectin" and "Enrichmen" — a truncated name costs the player
	# more than a point of type does, and only the string knows how wide it is.
	var room: float = rr.size.x - indent - 5.0
	var fs: int = 9 if narrow else 11
	while fs > 7 and _font.get_string_size(str(t["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	draw_circle(rr.position + Vector2(8.0 if narrow else 11.0, 13.0), 3.2,
		Color(0.38, 0.78, 0.44) if done else (UI_ACCENT if is_next else Color(0.22, 0.24, 0.30)))
	draw_string(_font, rr.position + Vector2(indent, 16.0), str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, room, fs, name_col)
	# What it buys: the unlocked machines' faces, dimmed until the tech is live.
	var ux: float = rr.position.x + 7.0
	for uid: StringName in (t.get("unlocks", []) as Array):
		var box := Rect2(ux, rr.position.y + 26.0, 17.0, 17.0)
		if box.end.x > rr.end.x - 3.0 or box.end.y > rr.end.y - 3.0:
			break                                          # a narrow chip shows what it can, never overflows
		_draw_thing_icon(uid, box)
		if not done:
			draw_rect(box, Color(0.0, 0.0, 0.0, 0.22 if is_next else 0.45))
		ux += 20.0


# --- the counter's surface primitives --------------------------------------------------------------------

## A REAL rounded rect. Composing one from a rect plus four circles double-blends every corner the moment
## the fill is translucent, which is exactly what a modern surface tint is.
func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	# ROUNDED BOXES ARE PANELS TOO. `panel_probe` used to see only `_panel()`, and the BAZAAR is built
	# entirely out of these — so `check_hud_layout`'s "Bazaar open" row recorded the bare screen's four
	# panels and nothing else, and the layer's headline claim ("the HUD must not print on top of itself")
	# had never once covered the largest overlay in the game. The states-differ assertion is what found it:
	# the Bazaar's screen was byte-identical to the bare screen's.
	if probing:
		panel_probe.append(rect)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## Rounded on the left two corners only — for the rail, flush against the panel's edge.
func _round_rect_left(rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## Elevation instead of a border. A modern panel does not outline itself; it casts. Concentric translucent
## rings are the cheap honest version of that, and they are what stop the counter reading as printed on the
## world behind it.
func _soft_shadow(rect: Rect2, spread: int, peak: float) -> void:
	for i: int in range(spread, 0, -1):
		var t: float = float(i) / float(spread)
		draw_rect(rect.grow(float(i)), Color(0.0, 0.0, 0.0, peak * (1.0 - t) * 0.32))


## One hairline of light along the top edge and a slow warm gradient down the plate — the two marks that say
## which way the lamp is, which is the difference between a surface and a fill.
func _panel_sheen(rect: Rect2) -> void:
	for i: int in 10:
		var t: float = float(i) / 9.0
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0 + t * 46.0, rect.size.x - 4.0, 5.0),
			Color(1.0, 0.94, 0.82, 0.020 * (1.0 - t)))
	draw_rect(Rect2(rect.position.x + 8.0, rect.position.y, rect.size.x - 16.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.075))


## Letter-spaced type. Small caps with air between them is most of what separates a title from a label.
func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


## What `_tracked` actually occupies — the plain width plus one gap per letter. Measuring tracked type with
## `get_string_size` is how a caption ends up printed through its own title.
func _tracked_w(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(text.length() - 1, 0))


## Darkens the frame's edges so the eye is pushed to the counter. Every modern pause screen does it; this
## one did not, which was part of why the panel read as pasted onto a screenshot.
func _bazaar_vignette(peak: float) -> void:
	if peak <= 0.001:
		return
	for i: int in 18:
		var t: float = float(i) / 18.0
		var inset: float = t * 130.0
		draw_rect(Rect2(0.0, 0.0, CANVAS.x, 1.0 + inset * 0.5), Color(0.0, 0.0, 0.0, peak * 0.030))
		draw_rect(Rect2(0.0, CANVAS.y - 1.0 - inset * 0.5, CANVAS.x, 1.0 + inset * 0.5),
			Color(0.0, 0.0, 0.0, peak * 0.030))
		draw_rect(Rect2(0.0, 0.0, 1.0 + inset, CANVAS.y), Color(0.0, 0.0, 0.0, peak * 0.024))
		draw_rect(Rect2(CANVAS.x - 1.0 - inset, 0.0, 1.0 + inset, CANVAS.y),
			Color(0.0, 0.0, 0.0, peak * 0.024))


## THE PRODUCTION DASHBOARD ([G]): the flywheel made legible — the factory's whole
## output at a glance so scaling is FELT, not guessed. Two columns, both pure sim reads: THROUGHPUT
## (production_rates() → per-item /min bars, relative + absolute, sorted fastest-first, grand total) and
## FACTORY (machine_census() → machines by type with a live working-count). Non-modal, like the tech
## tree — a status read, never blocks the world.
func _draw_dashboard_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.5))
	var w: float = 392.0
	var h: float = 238.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)))
	draw_string(_font, origin + Vector2(14.0, 22.0), "PRODUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_TEXT_DIM)
	draw_string(_font, origin + Vector2(w - 108.0, 21.0), "G / Esc to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	draw_line(origin + Vector2(206.0, 34.0), origin + Vector2(206.0, h - 12.0), UI_EDGE, 1.0)  # column rule

	# --- left column: THROUGHPUT (the flywheel — is output growing?) -----------------------------
	var lx: float = origin.x + 14.0
	var rates: Array[Dictionary] = sim.production_rates()
	var grand: float = 0.0
	var top: float = 0.0
	for r: Dictionary in rates:
		grand += float(r["rate"])
		top = maxf(top, float(r["rate"]))
	draw_string(_font, Vector2(lx, origin.y + 48.0), "THROUGHPUT · last 60s",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	draw_string(_font, Vector2(lx, origin.y + 66.0), "%.1f" % grand, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI_TEXT)
	draw_string(_font, Vector2(lx + 4.0 + _font.get_string_size("%.1f" % grand,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, origin.y + 66.0), "items/min",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	if rates.is_empty():
		draw_string(_font, Vector2(lx, origin.y + 92.0), "nothing producing yet —",
			HORIZONTAL_ALIGNMENT_LEFT, 184.0, 10, UI_TEXT_DIM)
		draw_string(_font, Vector2(lx, origin.y + 106.0), "mine, or feed a machine.",
			HORIZONTAL_ALIGNMENT_LEFT, 184.0, 10, UI_TEXT_DIM)
	else:
		var y: float = origin.y + 84.0
		var bar_x: float = lx + 74.0
		var bar_w: float = 118.0
		for i: int in mini(9, rates.size()):                  # top nine — the panel's height budget
			var item: StringName = rates[i]["item"]
			var rate: float = float(rates[i]["rate"])
			Visuals.draw_item(self, Vector2(lx + 7.0, y - 3.0), 13.0, item)
			draw_string(_font, Vector2(lx + 16.0, y), _item_label(item), HORIZONTAL_ALIGNMENT_LEFT, 56.0, 9, UI_TEXT)
			var frac: float = rate / top if top > 0.0 else 0.0
			draw_rect(Rect2(bar_x, y - 8.0, bar_w, 9.0), UI_SLOT)   # bar well
			var col: Color = Visuals.item_color(item)
			draw_rect(Rect2(bar_x, y - 8.0, maxf(2.0, bar_w * frac), 9.0), col)
			draw_string(_font, Vector2(bar_x + 3.0, y - 0.5), "%.1f/min" % rate,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT)
			y += 16.6

	# --- right column: FACTORY census (the empire — how big, how healthy?) ------------------------
	var rx: float = origin.x + 218.0
	var census: Array[Dictionary] = sim.machine_census()
	var total_m: int = sim.grid.size()
	var working_m: int = 0
	for c: Dictionary in census:
		working_m += int(c["working"])
	draw_string(_font, Vector2(rx, origin.y + 48.0), "FACTORY · %d machine%s" % [total_m,
		"" if total_m == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	if census.is_empty():
		draw_string(_font, Vector2(rx, origin.y + 70.0), "no machines built yet.",
			HORIZONTAL_ALIGNMENT_LEFT, 160.0, 10, UI_TEXT_DIM)
		draw_string(_font, Vector2(rx, origin.y + 84.0), "craft one (E), place it (RMB).",
			HORIZONTAL_ALIGNMENT_LEFT, 160.0, 10, UI_TEXT_DIM)
	else:
		# THE SUMMARY IS GREEN WHEN IT IS TRUE, and it used to be green unconditionally. `0 working` sat in
		# the healthy colour directly above a row flagging the same machines as stalled — the two lines
		# describing one fact with opposite valence, one of which could not change. A colour that is the
		# same for every value of the number beside it is not reporting the number.
		var all_up: bool = working_m >= total_m and total_m > 0
		draw_string(_font, Vector2(rx, origin.y + 63.0), "%d working" % working_m,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.78, 0.55) if all_up else UI_WARN)
		var y2: float = origin.y + 84.0
		for i: int in mini(9, census.size()):
			var row: Dictionary = census[i]
			var mdef: MachineDef = row["def"]
			var box := Rect2(rx, y2 - 11.0, 15.0, 15.0)
			draw_rect(box, Visuals.machine_color(mdef))
			Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
				Visuals.machine_kind(mdef), box.size.y / 20.0, false, 0.0)
			draw_string(_font, Vector2(rx + 20.0, y2), str(row["name"]), HORIZONTAL_ALIGNMENT_LEFT, 96.0, 9, UI_TEXT)
			# count · working — green when all are running, the ALERT colour when some are stalled.
			# This line used to say "amber when some are stalled" and draw UI_ACCENT, which is the colour
			# this same panel uses for its heading and its grand total. A player who has learned that gold
			# means "selected, available, yours" was being shown a fault in it, two rows under a gold number
			# that means the opposite. The left-edge alert stack already reports this exact fact — the same
			# machines, from `sim.machine_problems()` — in UI_WARN. Now both say it the same way.
			var cnt: int = int(row["count"])
			var wrk: int = int(row["working"])
			var stat_col: Color = Color(0.55, 0.78, 0.55) if wrk == cnt else UI_WARN
			draw_string(_font, Vector2(rx + 118.0, y2), "%d" % cnt, HORIZONTAL_ALIGNMENT_RIGHT, 24.0, 10, UI_TEXT)
			draw_string(_font, Vector2(rx + 144.0, y2), "%d▸" % wrk, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stat_col)
			y2 += 16.6


## The id of the i-th craftable — supplied explicitly by MainView (craft_ids, parallel to craft_options),
## so machines and tools can interleave without relying on machine_icons insertion order. Falls back to the
## old machine_icons-keys derivation if craft_ids wasn't set (defensive).
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = machine_icons.keys()
	return keys[i] if i < keys.size() else &""


## The HELP overlay (H / ?) — the full control list, summoned not stuck on screen. Centred card.
## The CONTROLS card, hoisted out of _draw_help_overlay so check_hud_layout can MEASURE it. Text is the
## half a panel-rect test cannot see: every one of these is drawn inside a fixed-width column, and a line
## wider than its column spills across the card or off it entirely while the panel it overflows still
## reports a perfectly legal rectangle.
## Column width for the CONTROLS card, and the number check_hud_layout holds every line to.
const HELP_COL_W: float = 236.0
## Text size the card is drawn at — named so the measuring layer cannot drift from the drawing code.
const HELP_TEXT_SIZE: int = 11

const HELP_LINES: Array[String] = [
	"move        A / D  (or ← →)",
	"jump        W  or  SPACE",
	"climb       W / S  on a rope (not a jump)",
	"grapple     F  at ringed rock · again to ride",
	"swing       W / S reel in / out · SPACE off",
	# The three techniques the winch grew. Each is taught in place by a hint the first time you are in
	# the situation (scenes/hints.gd), but a lesson you can only be told once is a lesson you can miss,
	# so the card carries them too — same key-first voice as every line above it.
	"chain       F in mid-air — keeps your speed",
	"wrap        the line bends round corners",
	"catch       F while falling — ends the fall",
	"mine        LMB (hold)",
	"dig plan    LMB drag paints it · X clears",
	"select      1–9  ·  mouse wheel",
	"place/pick  RMB  (machine, rope, block)",
	"scan        RMB  (Scanner — veins echo)",
	"drop / feed  Q  (gravity feeds it in)",
	"counter     E  (pack · works · bench)",
	"  tabs      1 / 2 / 3   ·   mouse wheel",
	"  pick      arrows / WASD   ·   buy  ENTER",
	"bench       T  (straight to the tech ladder)",
	"configure   R  (aimed at a splitter / hopper)",
	"dashboard   G",
	"map         M  (again: LARGE · click it = ping)",
	"fast-fwd    .     (1x → 2x → 4x → 8x)",
	"save / load  F5 / F9",
	"pause       P     ·   help   H",
	"settings    ESC  (audio · shake · remap keys)",
	]


func _draw_help_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.45))
	# TWO COLUMNS, BECAUSE ONE DID NOT FIT ON THE SCREEN. At 16px a row this list is 25 rows and 440px
	# tall on a 360px canvas, centred — so it hung 40px off the top AND 40px off the bottom, and the first
	# and last controls were simply not on screen. It rendered cleanly and looked deliberate, which is why
	# nothing caught it until check_hud_layout measured the box instead of looking at it.
	#
	# Splitting rather than shrinking is the right repair twice over: a smaller font would have fitted the
	# same wall of 25 rows into the same screen, and a wall of rows is the thing this card should least be.
	var lines: Array[String] = HELP_LINES
	var half: int = int(ceil(float(lines.size()) * 0.5))
	var col_w: float = HELP_COL_W
	var w: float = col_w * 2.0 + 16.0
	var h: float = 30.0 + float(half) * 16.0 + 10.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)))
	draw_string(_font, origin + Vector2(14.0, 22.0), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_TEXT_DIM)
	for i: int in lines.size():
		var col: int = i / half
		var row: int = i % half
		draw_string(_font, Vector2(origin.x + 16.0 + float(col) * col_w, origin.y + 38.0 + float(row) * 16.0),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, HELP_TEXT_SIZE, UI_TEXT)


## THE SETTINGS PAGE — THE COUNTER'S GRAMMAR, ITS OWN STATE.
##
## `MNU-26` filed one complaint: the settings page "shares none of the panel's grammar". Two prototypes
## were drawn for it (`tools/mock_settings.gd` a/b) and NEITHER was taken -- see
## docs/MENU_MATRIX.md for the ruling and its two facts. The short form:
##
##   * the reason recorded for making Settings independent was that the counter is a PLACE with a
##     precondition. It is not. `E` sets `_inventory_open` with no proximity check (`main.gd:1024`);
##     `_near_bazaar()` gates exactly one field, `can_craft`.
##   * the reason not to make Settings the counter's fourth face is real and lives in the input handlers.
##     `main.gd:1006` routes EVERY event to `_settings_input` and returns — a total intercept, which is
##     what key capture requires, because it must be able to swallow any key. The counter binds the digit
##     row AND the mouse wheel to tab selection. A binding capture cannot live inside a tab strip.
##
## So: share the language, keep the state. The plate, the rail, the head, the detail plate and the
## sizing behaviour are the counter's; `_settings_open` and ESC are still Settings' own.
##
## THE GRID, which is `MNU-27`. The old page put slider bars at x0+62 and chips at x0+92 — two control
## columns in one stack, 30px apart, which is what "several unrelated columns" meant. There is now ONE
## label x, ONE control x and ONE value x, and every control in every category lands on them.
##
## THE HEIGHT, which is `MNU-26`'s "modal bulk". The old page was a fixed 592x286 whatever it was showing.
## One category at a time on a panel that sizes to it makes FEEL barely half the height of CONTROLS —
## the same treatment the counter got, by the same helper shape.
const SET_W: float = 432.0
const SET_HEAD: float = 40.0          ## title + category name
const SET_FOOT: float = 16.0          ## the key legend
## The plate that says what the control under your hand DOES. Was 56, tall enough for three lines and
## never given more than one; the CONTROLS face is the only one that puts anything else in it, and that
## is a single RESET KEYS button on the same baseline. 36 holds both with room and takes 20px off every
## page height, which is 20px less of the objective banner above and the hotbar below that this panel
## prints over. Measured consequence: settings footprint 50.97% -> 47.22% of canvas, `check_hud_layout`.
const SET_DETAIL: float = 36.0
const SET_ROW: float = 22.0           ## an audio/feel row
const SET_MIN_H: float = 196.0
## The rail's icon box is 38 tall and its label sits `RAIL_LABEL_DY` below the box top, so three labelled
## slots need `top + 2 * pitch + RAIL_LABEL_DY` of rail. At the old 150 floor the FEEL page came out 186
## tall, the pitch collapsed to exactly 38 — the box height — and the boxes met with no room between them.
const RAIL_PITCH_MIN: float = 54.0
const RAIL_LABEL_DY: float = 44.0
## The shared grid, measured from the content's left edge. Named because a layout assertion that
## re-derives them is checking its own arithmetic against itself (the counter's rule, same reason).
const SET_CTRL_DX: float = 116.0
const SET_BAR_W: float = 116.0
const SET_VALUE_DX: float = 242.0     ## SET_CTRL_DX + SET_BAR_W + 10

const CAT_AUDIO: int = 0
const CAT_CONTROLS: int = 1
const CAT_FEEL: int = 2
const CAT_NAMES: Array[String] = ["AUDIO", "CONTROLS", "FEEL"]

## THE BINDINGS, each with the sentence its key does not tell you. A key legend that says what the key is
## FOR is a different document from one that says which key it is; the rows that say nothing here are the
## ones whose label already said it ("jump", "map"), and an empty string draws no plate rather than a
## padded restatement of the label.
const REMAP_ROWS: Array[Array] = [
	[Controls.LEFT, "move left", ""], [Controls.RIGHT, "move right", ""],
	[Controls.UP, "climb up", "ladders, ropes and lift shafts"],
	[Controls.DOWN, "climb down", ""],
	[Controls.JUMP, "jump", ""],
	[Controls.MINE, "mine (hold)", "hold on rock; the pickaxe decides what breaks"],
	[Controls.GRAPPLE, "grapple",
		"throw a line at what you are aiming at — it takes your weight, and pays out as you fall"],
	[Controls.BUILD, "build / place", "puts the held thing where you are aiming"],
	[Controls.DROP, "drop / feed", "into a machine's mouth if one is there"],
	[Controls.CRAFT, "pack", "the counter: what you carry, what you can build"],
	[Controls.RESEARCH, "research / config", ""],
	[Controls.MAP, "map", "press twice for the whole world"],
	[Controls.TECH, "tech tree", ""],
	[Controls.MUTE, "mute sound", ""],
	[Controls.DASHBOARD, "dashboard", ""], [Controls.HELP, "help", ""],
	[Controls.PAUSE, "pause", ""],
	[Controls.SPEED, "game speed", ""], [Controls.ZOOM, "zoom", ""],
	[Controls.SAVE, "quicksave", ""], [Controls.LOAD, "quickload", ""],
	[Controls.CLEAR_MARKS, "clear dig plan", ""],
]
const REMAP_ROW_H: float = 15.0
const REMAP_GAP: float = 16.0


## The page's geometry for the category that is open — the counter's `_bazaar_geometry` in every respect
## except its numbers, so the two pages cannot drift into different shapes.
func _settings_geometry() -> Dictionary:
	var h: float = _set_h
	var origin := Vector2((CANVAS.x - SET_W) * 0.5, (CANVAS.y - h) * 0.5)
	var inner_x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	var inner_w: float = SET_W - BAZAAR_RAIL - BAZAAR_PAD * 2.0
	var body_h: float = h - SET_HEAD - SET_FOOT
	var content := Rect2(inner_x, origin.y + SET_HEAD, inner_w, body_h - SET_DETAIL - 8.0)
	return {
		"origin": origin, "w": SET_W, "h": h, "content": content,
		"detail": Rect2(inner_x, content.end.y + 8.0, inner_w, SET_DETAIL),
		"col_w": (inner_w - REMAP_GAP) * 0.5,
	}


## How tall the page wants to be for the category that is open. Every term is taken from the function
## that draws it — see `_bazaar_wanted_h`, which learned this the hard way.
func _settings_wanted_h() -> float:
	var need: float = 0.0
	match settings_cat:
		CAT_CONTROLS:
			need = float(_remap_per_col()) * REMAP_ROW_H + 8.0
		CAT_FEEL:
			need = float(FEEL_ROWS.size()) * SET_ROW
		_:
			need = float(AUDIO_ROWS.size() + 1) * SET_ROW    # the levels, plus the mute above them
	return maxf(SET_HEAD + need + 8.0 + SET_DETAIL + SET_FOOT, SET_MIN_H)


## Rows per binding column. The single source for the split: `_settings_wanted_h` asks this rather than
## re-deriving it, because a height computed from a second copy of a layout rule is right on the day it
## is written and silently wrong the day either copy moves.
func _remap_per_col() -> int:
	return int(ceil(float(REMAP_ROWS.size()) * 0.5))


## The audio levels and the feel toggles, as data, so the drawing is one loop over a table and the
## detail plate has somewhere to read its sentence from.
const AUDIO_ROWS: Array[Array] = [
	["master", "master", "everything, including the ambience bed"],
	["effects", "sound", "picks, impacts, machines — the things you cause"],
	["ambience", "ambience", "the layer's own voice: water, wind, the deep hum"],
	["music", "music", ""],
]
const FEEL_ROWS: Array[Array] = [
	["screen shake", "shake", "impacts and blasts kick the camera"],
	["zoom", "zoom", "how much of the shaft you can see at once"],
	["auto-pickup", "auto_pickup", "walk over a dropped thing to take it"],
]


func _draw_settings_overlay() -> void:
	_settings_hits.clear()
	_slider_rects.clear()
	# The counter's ground, not the old page's: a tinted scrim rather than pure black, because a modal
	# that blacks the world out reads as a different application and one that tints it reads as a screen
	# you are ON. `MNU-07`'s remaining question is which of those Settings wants; this answers it the
	# same way the counter did.
	var t: float = settings_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _settings_geometry()
	var origin: Vector2 = g["origin"]
	var mouse: Vector2 = Controls.pointer_viewport(self)
	var plate := Rect2(origin, Vector2(SET_W, float(g["h"])))
	# The page rises the last few pixels into place, one transform, exactly as the counter does.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)
	# ELEVATION, NOT A BORDER. The old page was a hard-cornered rectangle with a 1px edge, which is the
	# single most 2003 thing a menu can be; the counter earned its depth from a soft shadow and a sheen
	# and this page now gets the same two.
	_soft_shadow(plate, 12, 0.34)
	# OPAQUE, and the comment that earned it stays: `UI_BG` is 90% because furniture sits over the world
	# and is MEANT to. A modal is not furniture — at 0.90 the objective banner read straight through this
	# page, and ten percent of a lit banner over an unlit panel is about twice the panel's own value.
	_round_rect(plate, 8.0, Color(0.062, 0.070, 0.094, 0.985))
	_panel_sheen(plate)
	_draw_settings_rail(origin, g, mouse)
	_draw_settings_head(origin, g)
	# The plate follows the mouse: whatever control is under your hand explains itself. Nothing under it
	# falls back to the category's own line, so the plate is never blank and never stale.
	var told: String = _settings_body(g, mouse)
	_draw_settings_detail(g, told, mouse)
	draw_string(_font, Vector2(origin.x + BAZAAR_RAIL + BAZAAR_PAD, origin.y + float(g["h"]) - 5.0),
		"1 2 3 switch category    ESC closes", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.36, 0.39, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The category rail. Shares `_rail_slots` with the counter's rail so the two cannot drift apart, and
## registers a hit per category — the rail is how you change page with the mouse.
func _draw_settings_rail(origin: Vector2, g: Dictionary, mouse: Vector2) -> void:
	var rail := Rect2(origin, Vector2(BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, Color(0.043, 0.049, 0.070, 0.92))
	var ys: Array = _rail_slots(rail, CAT_NAMES.size(), RAIL_PITCH_MIN)
	for i: int in CAT_NAMES.size():
		var y: float = ys[i]
		var on: bool = i == settings_cat
		var box := Rect2(rail.position.x + 9.0, y, 38.0, 38.0)
		if on:
			_round_rect(box, 6.0, RAIL_ON_FILL)
			draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UI_ACCENT)
		_settings_glyph(box.get_center(), i, on or box.has_point(mouse))
		# THE NUMBER TRAVELS INSIDE THE WORD. It used to be drawn separately above the icon while the word
		# sat below it, which put every word equidistant between the icon it names and the number of the
		# NEXT one — measured on the shipped frames at 47px to its own icon against 46px to the wrong
		# number, and on the shortest page they landed on the same baseline and the rail printed
		# "2 AUDIO" when 2 is CONTROLS. One string cannot drift away from itself at any pitch.
		var label: String = "%d %s" % [i + 1, CAT_NAMES[i]]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + RAIL_LABEL_DY), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UI_TEXT if on else Color(0.36, 0.39, 0.45))
		_settings_hits.append({"rect": box.grow(6.0), "payload": {"cat": i}})


## Where a rail's boxes sit, for a rail of any height and any number of slots. Extracted from the
## counter's rail rather than copied into this one: two rails that compute their own pitch are two rails
## that eventually disagree, and this project has a catalogue of exactly that.
func _rail_slots(rail: Rect2, n: int, min_pitch: float = 0.0) -> Array:
	# THE FLOOR IS NOT COSMETIC. Without one, a short page drives the pitch down to the icon box's own
	# height (38) and the boxes become contiguous — see `RAIL_PITCH_MIN`. The default of 0.0 leaves the
	# counter's rail exactly as it was; only a caller that draws text between the boxes needs to ask.
	var pitch: float = maxf(min_pitch,
		minf(58.0, (rail.size.y - 110.0) / maxf(float(n - 1), 1.0)))
	var top: float = minf(62.0, rail.size.y * 0.18)
	var out: Array = []
	for i: int in n:
		out.append(rail.position.y + top + float(i) * pitch)
	return out


## Three category glyphs, drawn rather than lettered, in the counter's hand: a speaker cone with two arcs,
## a key cap, three sliders at different settings.
func _settings_glyph(at: Vector2, kind: int, on: bool) -> void:
	var col: Color = Color(0.949, 0.831, 0.549) if on else Color(0.40, 0.43, 0.50)
	match kind:
		CAT_AUDIO:
			draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(4.0, 6.0)), col)
			var pts := PackedVector2Array([at + Vector2(-4.0, -1.0), at + Vector2(1.0, -7.0),
				at + Vector2(1.0, 7.0), at + Vector2(-4.0, 1.0)])
			draw_colored_polygon(pts, col)
			draw_arc(at + Vector2(1.0, 0.0), 5.5, -PI * 0.4, PI * 0.4, 8, col, 1.4)
			draw_arc(at + Vector2(1.0, 0.0), 8.5, -PI * 0.4, PI * 0.4, 8, col, 1.4)
		CAT_CONTROLS:
			draw_rect(Rect2(at + Vector2(-8.0, -6.0), Vector2(16.0, 13.0)), Color(col, 0.35))
			draw_rect(Rect2(at + Vector2(-8.0, -6.0), Vector2(16.0, 13.0)), col, false, 1.4)
			draw_rect(Rect2(at + Vector2(-3.0, -2.0), Vector2(6.0, 5.0)), col)
		_:
			for i: int in 3:
				var y: float = at.y - 6.0 + float(i) * 6.0
				draw_rect(Rect2(at.x - 9.0, y - 0.7, 18.0, 1.6), Color(col, 0.45))
				draw_rect(Rect2(at.x - 9.0 + float(3 - i) * 4.5, y - 3.0, 2.6, 6.0), col)


## The head: what page this is, and which face of it you are on — the counter's title pair exactly.
func _draw_settings_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	# THE IDENTIFYING WORD CARRIES THE CONTRAST. This pair was the other way round: `SETTINGS` at 12.6:1
	# and the category at 2.0:1 — the brightest text on the page was the word that is the same on all
	# three faces, and the dimmest was the only one that says which face you are looking at. A blind read
	# called it the most damaging defect on the screen: it fails at telling you what it is.
	_tracked("SETTINGS", Vector2(x, origin.y + 26.0), 15, 2.8, Color(0.42, 0.45, 0.53))
	_tracked(CAT_NAMES[settings_cat],
		Vector2(x + _tracked_w("SETTINGS", 15, 2.8) + 16.0, origin.y + 26.0), 15, 2.8, UI_TEXT)


## The open category, returning the sentence the detail plate should say — which is whatever the mouse is
## over. Returning it rather than storing it keeps the plate's content derived from the same pass that
## decided what was under the cursor.
func _settings_body(g: Dictionary, mouse: Vector2) -> String:
	var c: Rect2 = g["content"]
	match settings_cat:
		CAT_CONTROLS:
			return _settings_controls(g, c, mouse)
		CAT_FEEL:
			return _settings_feel(c, mouse)
		_:
			return _settings_audio(c, mouse)


## Named rather than fetched. `Settings` is a `class_name` of STATIC vars, and a dynamic `get()` against
## one is a lookup that fails at runtime rather than at parse time — the wrong trade in a page that four
## harness layers photograph.
func _audio_level(id: String) -> float:
	match id:
		"master": return Settings.master
		"sound": return Settings.sound
		"ambience": return Settings.ambience
		_: return Settings.music


func _settings_audio(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	draw_string(_font, Vector2(c.position.x, y), "sound", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	# The mute reads as its STATE, never as an instruction — a chip that says the opposite of what is
	# happening is the oldest bug in settings UI.
	if _settings_chip(c.position.x + SET_CTRL_DX, y, "MUTED" if Settings.muted else "SOUND ON",
			{"toggle": "mute"}, not Settings.muted, mouse, 10, Settings.muted):
		said = "silences everything at once; the levels below are kept"
	for row: Array in AUDIO_ROWS:
		y += SET_ROW
		var id: String = str(row[1])
		if _settings_slider(c.position.x, y, id, str(row[0]), _audio_level(id), mouse):
			said = str(row[2])
	return said


func _settings_feel(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	for row: Array in FEEL_ROWS:
		var id: String = str(row[1])
		draw_string(_font, Vector2(c.position.x, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT)
		var text: String = ""
		var payload: Dictionary = {}
		var on: bool = false
		if id == "zoom":
			text = "%.2fx" % MainView.ZOOM_LEVELS[
				clampi(Settings.zoom_idx, 0, MainView.ZOOM_LEVELS.size() - 1)]
			payload = {"cycle": "zoom"}
		else:
			on = Settings.screen_shake if id == "shake" else Settings.auto_pickup
			text = "ON" if on else "OFF"
			payload = {"toggle": id}
		if _settings_chip(c.position.x + SET_CTRL_DX, y, text, payload, on, mouse):
			said = str(row[2])
		y += SET_ROW
	return said


## WHICH BINDINGS SHARE A KEY WITH ANOTHER, and who with.
##
## `Settings.rebind` writes the new key and returns; **it has never checked for a conflict**. Bind `jump`
## to `W` and `W` is now `climb up` AND `jump`, both fire, and nothing anywhere says so. `MNU-29` asks for
## a conflict state by name and `MNU-30` asks that conflicts stay explicit, so the page shows it rather
## than the rebind refusing it — refusing would be the page overruling a deliberate choice, and silently
## unbinding the other action would be worse than either.
##
## Compared on the LABEL, which is what the row displays: a clash the page draws has to be a clash the page
## can show you. `unbound` and `?` are excluded — two actions with no key are not in conflict, and a naive
## equality would have called them the loudest clash on the board.
func _binding_clashes() -> Dictionary:
	# THE POPULATION IS EVERY EVENT OF EVERY ACTION, and it used to be neither.
	#
	# It compared `Settings.binding_label`, which is `events[0]`, across the 22 REMAP_ROWS. Two things were
	# wrong with that. Most actions have two or three events, so a collision on any event but the first was
	# invisible — bind something to the up arrow and it silently shares with `climb up`, whose first event
	# is W. And `Settings.rebind` scans all 25 of `Controls.defaults()`, so it could displace `close`,
	# `cycle next` or `cycle prev`, none of which have a row here to show that it happened.
	#
	# Detecting over all 25 while DISPLAYING on the 22 is deliberate: the page owns 22 rows, but a warning
	# that names an off-page action is still true and still actionable, and silence would not be.
	var by_key: Dictionary = {}
	for act: StringName in Controls.defaults():
		for label: String in Settings.event_labels(act):
			if label == "unbound" or label == "?":
				continue
			var seen: Array = by_key.get(label, [])
			seen.append(act)
			by_key[label] = seen
	# THE PHRASE NAMES THE COLLIDING KEY, not the row's chip. Once a clash can live on an action's second
	# event, "%s is also %s" filled in with `binding_label(action)` would point at the wrong key — the row
	# would turn orange over `A` while the actual collision was on the left arrow. **The display and the
	# fix have to be about the same event**, which is the whole reason both sides share one predicate.
	var out: Dictionary = {}
	for row: Array in REMAP_ROWS:
		var act: StringName = row[0]
		var said: Array = []
		for label: String in Settings.event_labels(act):
			for other_v: Variant in by_key.get(label, []):
				if StringName(other_v) != act:
					said.append("%s is also %s" % [label, action_label(StringName(other_v))])
		if not said.is_empty():
			out[act] = said
	return out


## An action's human name, from the same table the page draws. Static because `MainView` needs it to say
## which binding a rebind just took the key from, and a second copy of these names would be a second place
## for them to go stale.
static func action_label(action: StringName) -> String:
	for row: Array in REMAP_ROWS:
		if row[0] == action:
			return str(row[1])
	return String(action)


## Move the keyboard cursor. Up/Down step within a column; Left/Right jump a column, which is what the
## two-column layout makes them mean. Clamped rather than wrapped: a cursor that leaps from the last row
## to the first reads as a lost keypress.
func move_settings_row(keycode: int) -> void:
	if settings_cat != CAT_CONTROLS:
		return
	var per_col: int = _remap_per_col()
	var n: int = REMAP_ROWS.size()
	match keycode:
		KEY_UP: settings_row -= 1
		KEY_DOWN: settings_row += 1
		KEY_LEFT: settings_row -= per_col
		KEY_RIGHT: settings_row += per_col
	settings_row = clampi(settings_row, 0, n - 1)


## The action under the keyboard cursor, or &"" when the cursor is not on a binding list.
func settings_row_action() -> StringName:
	if settings_cat != CAT_CONTROLS or settings_row < 0 or settings_row >= REMAP_ROWS.size():
		return &""
	return REMAP_ROWS[settings_row][0]


## The bindings: two columns of eleven, each row a label and the key that does it. `MNU-30` — the capture
## state is now ON the row that is capturing ("press a key…"), not a sentence at the bottom of the page
## competing with the reset control.
func _settings_controls(g: Dictionary, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var per_col: int = _remap_per_col()
	var col_w: float = float(g["col_w"])
	var clashes: Dictionary = _binding_clashes()
	for i: int in REMAP_ROWS.size():
		var row: Array = REMAP_ROWS[i]
		var col: int = i / per_col
		var x: float = c.position.x + float(col) * (col_w + REMAP_GAP)
		var y: float = c.position.y + 12.0 + float(i % per_col) * REMAP_ROW_H
		var action: StringName = row[0]
		var capturing: bool = settings_capture == action
		var clash: Array = clashes.get(action, [])
		var text: String = "press a key…" if capturing else Settings.binding_label(action)
		var bw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
		var chip := Rect2(x + col_w - bw, y - 10.0, bw, 13.0)
		var lit: bool = chip.has_point(mouse)
		var cursor: bool = i == settings_row
		if lit or capturing or cursor:
			# The whole row lights, not just the chip — the row is the thing you are choosing, which is
			# what makes the plate below it read as being ABOUT something.
			_round_rect(Rect2(x - 4.0, y - 11.0, col_w + 8.0, 15.0), 3.0, Color(0.145, 0.129, 0.082))
		# THE KEYBOARD CURSOR IS NOT THE HOVER, and it must not look like it. Hover is a warm fill under
		# whatever the mouse happens to be over; focus is a claim about where the NEXT keypress will land,
		# and it persists with no pointer anywhere near it. So focus gets the rail's own gold edge bar —
		# the mark this UI already uses for "this is the selected one" — and the two can coexist on
		# different rows without either being ambiguous.
		if cursor:
			draw_rect(Rect2(x - 6.0, y - 11.0, 2.0, 15.0), UI_ACCENT)
		# THE MOUSE WINS WHEN IT IS ON A ROW, because it is the more deliberate pointer; the keyboard cursor
		# speaks when nothing is hovered, so the plate always describes the thing that would act.
		#
		# THAT SENTENCE WAS HERE WHILE THE CODE DID THE OPPOSITE. The whole block sat under `if cursor:`,
		# so `said` was set only for the single row the keyboard cursor was parked on and hovering a row
		# with the mouse produced no plate text at all. **The clash message is this ticket's entire payload,
		# and it was unreachable by mouse** — visible only if the cursor happened to be on the clashing row.
		#
		# `lit` (hover) is checked FIRST and unconditionally; `cursor` fills in when nothing is hovered.
		# The old `elif lit or said == "":` could not be false either, since exactly one row is the cursor
		# row and `said` is still empty when it is reached — a guard that cannot fail, inside the fix for a
		# ticket about guards that cannot fail.
		if lit or (cursor and said == ""):
			if capturing:
				said = "press any key to bind it — ESC cancels"
			elif not clash.is_empty():
				said = " and ".join(clash)
			else:
				said = str(row[2]) if str(row[2]) != "" else "%s — press Enter to rebind" % str(row[1])
		draw_string(_font, Vector2(x, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT if (lit or capturing) else UI_TEXT_DIM)
		# A CLASHING KEY IS NOT A SELECTED ONE, so it does not get the gold — it gets the warn colour the
		# stalled-machine alerts use, which is the only other thing in this UI that means "this will not do
		# what you think". Dark type on both, because light grey on either is unreadable.
		var fill: Color = UI_ACCENT if capturing else (
			UI_WARN if not clash.is_empty() else (Color(0.30, 0.34, 0.44) if lit else UI_SLOT))
		draw_rect(chip, fill)
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(chip.position.x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.10, 0.10, 0.12) if (capturing or not clash.is_empty()) else UI_TEXT)
		_settings_hits.append({"rect": chip, "payload": {"bind": String(action)}})
	return said


## The detail plate. The counter's answer to "twenty-two rows of equal weight" was to make the SELECTED
## thing large, say what it is FOR, and put the verb on a real button; a key binding wants that more than
## a machine does, because the row `grapple  F` tells a first-timer nothing whatever.
func _draw_settings_detail(g: Dictionary, said: String, mouse: Vector2) -> void:
	var d: Rect2 = g["detail"]
	_round_rect(d, 5.0, Color(0.0, 0.0, 0.0, 0.22))
	var line: String = said
	if line == "":
		line = CATEGORY_LINE[settings_cat]
	# Wrapped by hand at the plate's width: `draw_string` will not wrap and a sentence that runs off a
	# plate is the defect this page was opened to fix.
	var y: float = d.position.y + 20.0
	for part: String in _wrap(line, d.size.x - 24.0, 10):
		draw_string(_font, Vector2(d.position.x + 12.0, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT if said != "" else Color(0.40, 0.43, 0.50))
		y += 13.0
	if settings_cat == CAT_CONTROLS:
		var w: float = _font.get_string_size("RESET KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0
		_settings_chip(d.end.x - w, d.end.y - 8.0, "RESET KEYS", {"reset": true}, false, mouse, 9)


## What each category says when your hand is not on anything — the page describing itself rather than
## sitting blank, which is the state it is in most of the time it is open.
const CATEGORY_LINE: Array[String] = [
	"levels are remembered while muted",
	"click a binding, then press its new key",
	"how the game moves and what it does for you",
]


## Break a sentence to a pixel width. Words only; a plate this size never needs more.
func _wrap(text: String, width: float, size: int) -> Array:
	var out: Array = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var probe: String = word if line == "" else line + " " + word
		if _font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = probe
	if line != "":
		out.append(line)
	return out


## One level: label, bar, percentage — all three on the shared grid. Returns whether the mouse is on it,
## so the caller can hand its sentence to the detail plate.
func _settings_slider(x0: float, y: float, id: String, label: String, value: float,
		mouse: Vector2) -> bool:
	var bar := Rect2(x0 + SET_CTRL_DX, y - 9.0, SET_BAR_W, 10.0)
	_slider_rects[id] = bar
	var hot: bool = bar.grow(4.0).has_point(mouse)
	# Dimmed while muted: the levels are still yours and still remembered, but nothing they say is
	# audible, and a bright slider over a silent game is the page lying about which control is in charge.
	draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UI_TEXT_DIM if Settings.muted else UI_TEXT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y))
	draw_rect(fill, Color(UI_ACCENT, 0.55) if Settings.muted else UI_ACCENT)
	# The travelled end gets a bright cap rather than the bar getting brighter: `MNU-28`'s complaint about
	# these bars is that a long gold fill reads as a progress meter, and a meter is a thing you watch
	# rather than a thing you drag.
	# FRAME FIRST, THEN THE HANDLE. Drawn the other way round the frame overprints the handle where it
	# crosses the bar, and a cap that stands 2px proud top and bottom renders as three disconnected
	# pieces — a nub, a sliver, a nub. It reads as a rendering fault rather than as something to drag.
	draw_rect(bar, UI_EDGE_HI if hot else UI_EDGE, false, 1.0)
	if value > 0.0:
		draw_rect(Rect2(fill.end.x - 2.0, bar.position.y - 2.0, 2.5, bar.size.y + 4.0),
			Color(0.949, 0.831, 0.549) if hot else Color(0.80, 0.83, 0.89))
	draw_string(_font, Vector2(x0 + SET_VALUE_DX, y), "%d%%" % int(round(value * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT if hot else UI_TEXT_DIM)
	_settings_hits.append({"rect": bar.grow(3.0), "payload": {"slider": id}})
	return hot


## One chip. Returns whether the mouse is on it, for the same reason the slider does.
## `warn` is a THIRD state, and it exists because two were not enough. `UI_ACCENT` is spoken for one line
## from its definition — "selection, the live verb, the next step" — so a chip filled with it asserts that
## the thing it names is ON. The mute chip passed `Settings.muted` as `active`, which meant the loudest,
## most saturated element on the AUDIO page lit up gold precisely when the audio was off, in the same
## colour the rail uses for the selected category and the sliders use for their level. Flipping it to
## `not muted` alone would have been wrong the other way: muted would then read as merely unselected, and
## silence the player did not intend is worth noticing. Warm-on-dark says suppressed without claiming
## chosen.
func _settings_chip(x: float, y: float, text: String, payload: Dictionary, active: bool,
		mouse: Vector2, size: int = 10, warn: bool = false) -> bool:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	var chip := Rect2(x, y - 11.0, w, 15.0)
	var hot: bool = chip.has_point(mouse)
	if warn:
		draw_rect(chip, Color(0.22, 0.15, 0.11))
		draw_rect(chip, Color(0.86, 0.47, 0.31, 0.95 if hot else 0.75), false, 1.0)
		draw_string(_font, Vector2(x + 6.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0.96, 0.64, 0.47))
	else:
		draw_rect(chip, UI_ACCENT if active else (Color(0.30, 0.34, 0.44) if hot else UI_SLOT))
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(x + 6.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0.10, 0.10, 0.12) if active else UI_TEXT)
	_settings_hits.append({"rect": chip, "payload": payload})
	return hot


## Move to a category. Named like `set_bazaar_tab` and for the same reason: the page owns which face it
## is showing, and `main.gd` asks for a change rather than pushing the field every frame.
func set_settings_cat(cat: int) -> void:
	settings_cat = clampi(cat, 0, CAT_NAMES.size() - 1)



## The control payload under a canvas point ({} = none) — sliders add the clicked fraction so a
## single press already sets the value (drag then refines it via settings_slider_frac).
func settings_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _settings_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			var payload: Dictionary = (hit["payload"] as Dictionary).duplicate()
			if payload.has("slider"):
				payload["frac"] = settings_slider_frac(str(payload["slider"]), canvas_pos.x)
			return payload
	return {}


## Fraction along a slider's bar for a canvas x — used by click AND drag (MainView keeps updating
## through mouse motion while the button stays down, even if the cursor drifts off the bar).
func settings_slider_frac(id: String, canvas_x: float) -> float:
	var bar: Rect2 = _slider_rects.get(id, Rect2())
	if bar.size.x <= 0.0:
		return 0.0
	return clampf((canvas_x - bar.position.x) / bar.size.x, 0.0, 1.0)


## A tiny dim hint, bottom-left — the toggle keys, so the player knows the menus exist without the old
## always-on keyboard-reference footer hogging the whole bottom edge.
##
## IT RETIRES ITSELF, ONE KEY AT A TIME, AND THAT IS THE POINT. The subjective audit's charge against this
## line was not that it is ugly — it is 10px and dim — but that it is PERMANENT: "the persistent bottom-left
## key legend reads like test-build chrome", listed on the kill list under "teach contextually, then remove
## it". A reference card that never leaves is a statement that the game expects you never to learn it, and
## it sits in the corner of every screenshot the game will ever take.
##
## So each entry disappears the first time you press that key, and when the last one goes the line goes with
## it. A player who already knows the controls clears it in about four seconds and never sees it again; a
## player who does not gets exactly the entries they have not yet used, which is a smaller and more pointed
## hint every time they look. Nothing is hidden that has not been demonstrably learned.
##
## SESSION-SCOPED ON PURPOSE. This is not written to the save. `check_save_frontier` guards every field in
## the envelope and would rightly demand this one declare its disposition, and "which keys has this player
## pressed" is not world state — it is a teaching aid whose cost of being wrong is one dim line for four
## seconds. A returning player re-clears it. That is cheaper than owning a migration for it.
const HINT_KEYS: Array = [
	[Controls.GRAPPLE, "F hook"], [Controls.DROP, "Q drop"], [Controls.CRAFT, "E pack"],
	[Controls.MAP, "M map"], [Controls.HELP, "H keys"],
]

var _hint_used: Dictionary = {}          ## action -> true, once the player has pressed it this session


## Called from the input handler when one of the hinted actions fires. Unknown actions are ignored, so a
## caller may pass anything without checking.
func note_hint_used(action: StringName) -> void:
	_hint_used[action] = true


func _draw_hint() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for row: Array in HINT_KEYS:
		if not _hint_used.has(row[0]):
			parts.append(String(row[1]))
	if parts.is_empty():
		return                            # everything here has been used — the line has finished its job
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "   ·   ".join(parts),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)


func _can_afford(cost: Dictionary) -> bool:
	for item: StringName in cost:
		if int(sim.inventory.get(item, 0)) < int(cost[item]):
			return false
	return true


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item: StringName in cost:
		parts.append("%d %s" % [int(cost[item]), _item_label(item)])   # "6 Iron Ingot", never a raw id
	return " ".join(parts)


## The carried pack as a hotbar of slots (icon + count), centred along the bottom. The active slot
## (mouse-wheel) is highlighted; it's the item E deposits. Reads `sim.inventory_slots()`.
func _draw_inventory() -> void:
	# THE BIG MAP IS THE SCREEN — the same rule as the goal plate at :699, decided there for the same
	# reason. The map's panel runs y 41..319 of a 360 canvas and this bar's backing starts at y=295, and the
	# map draws SECOND (:270 after :263). So the bar was not overlapped, it was BURIED: rows 319..339 poked
	# out below the map's edge, which is exactly where each slot's count badge sits (:2330) — every count
	# legible, every icon it counts cut in half. That is worse than either showing the bar or hiding it.
	# Standing down rather than nudging the map, because :696 already rejected nudging in writing: the map
	# is the one screen that is purely for reading the world, and your pack is not what you are reading.
	# M puts it back. Held by `check_hud_layout:_check_big_map`.
	if minimap_large:
		return
	var slots: Array[Dictionary] = sim.inventory_slots()
	# Show ONLY the slots you actually carry, not a fixed row of empty wells — a trailing empty slot reads
	# as "broken / what goes here?". The bar grows/shrinks with your pack (min 1 so it never vanishes).
	var n: int = clampi(slots.size(), 1, FactorySim.INVENTORY_SLOTS)
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	# THE BAR IS A WINDOW ONTO THE PACK, NOT THE PACK. `inventory_slots()` has no cap — it returns one entry
	# per item TYPE, and the type universe is 20 machines plus 16 materials plus the crafted intermediates —
	# while this bar is capped at ten and `clampi` used to swallow the difference in silence. Carrying
	# eleven types drew ten wells and said nothing about the eleventh, in a bar whose stated contract two
	# lines up is that it grows and shrinks with your pack. Worse, `_cycle_inventory` wraps modulo the FULL
	# count (main.gd:2214), so the wheel walks the selection to index 10+ where the loop below never reaches
	# it: no glow, no accent border, no lit well anywhere on the bar — and the name plate, whose guard is
	# `sel < slots.size()` and not `sel < n`, was still drawn at the selection's arithmetic position, off
	# the right end of the bar and eventually off the canvas. A floating item name over empty space, naming
	# the thing your next click will place. It is reachable on frame one of a dev start: the dev kit is ten
	# types and the starter pickaxe is an eleventh, seeded independently.
	# So the window is placed to CONTAIN the selection instead of assuming it does. Centred, derived purely
	# from `sel` — no persistent scroll state to desynchronise from the thing it is scrolling.
	var w0: int = clampi(sel - n / 2, 0, maxi(slots.size() - n, 0))
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = HOTBAR_BAND_TOP + 7.0            # the band is the definition; the well row sits inside it
	# A clean framed backing just for the hotbar (the craft strip that used to share this panel now lives
	# in the E screen). Keeps the bar reading as one deliberate unit, not floating slots.
	var backing := Rect2(x0 - 8.0, HOTBAR_BAND_TOP, total_w + 16.0, HOTBAR_BAND_H)
	_panel(backing)
	var wells: Array[Rect2] = []
	var sel_lit: bool = false
	for k: int in n:
		var i: int = w0 + k                                      # window slot -> the pack index it shows
		var sx: float = x0 + float(k) * (SLOT + SLOT_GAP)
		var slot_rect := Rect2(sx, y, SLOT, SLOT)
		var active: bool = i == sel
		wells.append(slot_rect)
		sel_lit = sel_lit or active
		if i < slots.size() and slot_rect.has_point(Controls.pointer_viewport(self)):
			_tooltip_item = slots[i]["item"]                     # hovered hotbar slot → tooltip
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(slot_rect.get_center().x, slot_rect.position.y)
		if active:
			draw_rect(slot_rect.grow(2.0), Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.18))  # selection glow
		draw_rect(slot_rect, UI_SLOT)                                                            # well
		draw_line(slot_rect.position + Vector2(1.0, 1.0), slot_rect.position + Vector2(SLOT - 1.0, 1.0),
			UI_EDGE_HI, 1.0)                                                                      # top bevel
		draw_rect(slot_rect, UI_ACCENT if active else UI_EDGE, false, 2.0 if active else 1.0)
		# Faint keybind number in the slot corner so the hotbar reads as keyed — and ONLY where a key really
		# exists. The row is 1-9 then 0 for the tenth (main.gd:1092), so the tenth well said "10" for a key
		# nobody has, and once the window can scroll, `k + 1` would relabel whichever items happen to be on
		# screen. The digit follows the PACK INDEX and stops when the keys do; past that the well is
		# wheel-and-PACK territory and says so by staying blank rather than by lying.
		if i < 10:
			draw_string(_font, slot_rect.position + Vector2(2.0, 9.0), "0" if i == 9 else str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.48, 0.56))
		if i < slots.size():
			var item: StringName = slots[i]["item"]
			var count: int = int(slots[i]["count"])
			var icon := Rect2(sx + 6.0, y + 6.0, SLOT - 12.0, SLOT - 14.0)
			if machine_icons.has(item):  # a machine item: its sprite, or casing colour + a mini silhouette
				var mspr: Texture2D = Art.tex("machine_" + String(item))
				if mspr != null:
					draw_texture_rect(mspr, icon, false)
				else:
					var ic: Dictionary = machine_icons[item]
					draw_rect(icon, ic["color"])
					draw_rect(icon, Color(0.0, 0.0, 0.0, 0.35), false, 1.0)
					# Same glyph the world draws (shared Visuals), scaled to the chip — never drifts.
					Visuals.draw_machine_glyph(self, icon.position + icon.size * 0.5, str(ic["kind"]),
						icon.size.y / 20.0, false, 0.0)
			else:  # a resource item: its sprite (item_<id>.png) or the flat colour chip
				Visuals.draw_item(self, icon.position + icon.size * 0.5, icon.size.y, item)
			# Count badge bottom-right with a dark backing so it stays legible over any icon colour.
			var cnt: String = str(count)
			var cw: float = _font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_rect(Rect2(sx + SLOT - cw - 5.0, y + SLOT - 13.0, cw + 4.0, 12.0), Color(0.03, 0.03, 0.05, 0.85))
			draw_string(_font, Vector2(sx + SLOT - cw - 3.0, y + SLOT - 3.0), cnt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	# THE PACK CONTINUES THAT WAY. A chevron at whichever end has more pack behind it — the one thing the
	# clamp never said. It is deliberately a mark and not a count: the number of types you are carrying is
	# the PACK screen's job, and a bar that starts reporting totals is on its way to being a second
	# inventory. This only says "not all of it is here", which is the fact the bar was concealing.
	if w0 > 0:
		_more_mark(Vector2(backing.position.x - 5.0, y + SLOT * 0.5), -1.0)
	if w0 + n < slots.size():
		_more_mark(Vector2(backing.end.x + 5.0, y + SLOT * 0.5), 1.0)
	# Name the SELECTED item just above the bar — so the coloured chips stop being mystery squares.
	var label_rect := Rect2()
	if sel >= w0 and sel < mini(w0 + n, slots.size()):
		var label: String = _item_label(slots[sel]["item"])
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var lx: float = x0 + float(sel - w0) * (SLOT + SLOT_GAP) + (SLOT - lw) * 0.5
		var ly: float = y - 12.0
		var plate := Rect2(lx - 5.0, ly - 11.0, lw + 10.0, 15.0)
		draw_rect(plate, Color(0.05, 0.06, 0.09, 0.88))
		# The NAME of the selected item, not the selection. The slot itself already carries a gold border and
		# a gold glow; a third gold on the same object is emphasis competing with itself.
		draw_string(_font, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
		label_rect = plate
	if probing:
		hotbar_probe = {"carried": slots.size(), "wells": wells, "sel": sel, "sel_lit": sel_lit,
			"window": w0, "backing": backing, "label": label_rect}


## "There is more pack this way." A chevron pointing outward from the end of the hotbar, drawn only when
## the window is actually hiding something in that direction. Dim on purpose — it is a hint that the bar is
## a view, not a control, and nothing about it is clickable.
func _more_mark(at: Vector2, dir: float) -> void:
	var col := Color(UI_TEXT_DIM.r, UI_TEXT_DIM.g, UI_TEXT_DIM.b, 0.55)
	draw_line(at + Vector2(-3.0 * dir, -5.0), at + Vector2(2.0 * dir, 0.0), col, 1.5)
	draw_line(at + Vector2(2.0 * dir, 0.0), at + Vector2(-3.0 * dir, 5.0), col, 1.5)


## The hovered slot's TOOLTIP: the item's name, the count you hold, and one purpose
## line — "what is this FOR" answered where the question is asked. Captured by the hotbar/pack-grid
## slot loops this frame; drawn last, above every panel, clamped on-canvas above the hovered slot.
func _draw_item_tooltip() -> void:
	if _tooltip_item == &"":
		return
	var name_line: String = "%s  ×%d" % [_item_label(_tooltip_item), _tooltip_count]
	var purpose: String = str(ITEM_PURPOSE.get(_tooltip_item, ""))
	var fs: int = 10
	var wrap_w: float = 200.0
	var name_w: float = _font.get_string_size(name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var body: Vector2 = _font.get_multiline_string_size(purpose, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs) \
		if purpose != "" else Vector2.ZERO
	var w: float = maxf(name_w, minf(body.x, wrap_w)) + 18.0
	var h: float = 22.0 + (body.y + 4.0 if purpose != "" else 0.0)
	var origin := Vector2(clampf(_tooltip_anchor.x - w * 0.5, 6.0, CANVAS.x - w - 6.0),
		maxf(_tooltip_anchor.y - h - 6.0, 6.0))
	var rect := Rect2(origin, Vector2(w, h))
	draw_rect(rect, Color(UI_BG.r, UI_BG.g, UI_BG.b, 0.96))
	draw_rect(rect, UI_EDGE, false, 1.0)
	# A spine rather than a cap — and no longer gold: a tooltip describes what the cursor is OVER, which is
	# `active`, not the thing a keystroke acts on. `UI_EDGE_HI` keeps the edge without claiming the verb.
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), Color(UI_EDGE_HI, 1.0))
	draw_string(_font, origin + Vector2(9.0, 15.0), name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	if purpose != "":
		draw_multiline_string(_font, origin + Vector2(9.0, 29.0), purpose,
			HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.78, 0.74, 0.62))


## Human-readable name for a carried item: a machine item uses its def's display name (Forge/Drill/…),
## a resource its capitalised id (ore → "Ore"). Stops the hotbar chips from being unlabelled colour squares.
func _item_label(item: StringName) -> String:
	if machine_icons.has(item):
		return String(machine_icons[item].get("name", item))
	return String(item).capitalize()


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
