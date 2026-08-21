class_name Hud
extends Node2D

## Screen-fixed HUD. It lives under a CanvasLayer so the follow camera does not scroll it, reads the sim
## only and draws in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
## Where the bottom furniture starts, as one definition rather than two. `_draw_inventory` derives the
## bar's y from these, and anything outside the HUD should read `bottom_furniture_fraction()` rather
## than carry its own number; `tools/check_opening.gd` hardcodes `HUD_BOTTOM = 0.20` where the real band
## starts at 295/360 = 0.819.
const HOTBAR_BAND_TOP: float = CANVAS.y - 28.0 - SLOT - 7.0
const HOTBAR_BAND_H: float = SLOT + 14.0


## The fraction of the canvas above the bottom furniture: the last row that is still world.
static func bottom_furniture_fraction() -> float:
	return HOTBAR_BAND_TOP / CANVAS.y
const MINI_W: float = 150.0     ## minimap box in the top-right corner; the world fits inside it,
const MINI_H: float = 116.0     ## ...whatever shape the world happens to be
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

## --- UI skin palette -------------------------------------------------------------------------------
##
## The HUD used to hold the two brightest values in the frame, which pulled the eye to the chrome and
## away from the play space. Both are stepped down here; they keep plenty of contrast against their own
## near-black panels. Nothing in the UI should ever be brighter than lit rock.
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight → panels read as raised
## Gold never labels and never counts. It marks only what the player's input is connected to: the
## selection, the verb that acts on it, the next available research node, an engaged control. The nine
## sites where the accent was pure information now draw in text colours, and the call sites are
## all in this file, and the roles that kept the accent are walked through below.
##
## A machine's stalled count belongs in `UI_WARN`, not here.
##
## Three of those four roles are now settled, by putting one question to every gold mark in the file
## rather than to the ones anybody remembered: can a player's input reach the thing this mark is on,
## right now? Twenty-four draw sites, and only the ones that answer yes keep the accent.
##
##   The live verb keeps it, because it is the definition: `_verb_button`'s slab, and the title's
##   `[ENTER] descend`.
##
##   The selection keeps it for a mechanical reason rather than a preference. Every gold selection mark
##   here is the argument of the gold verb beside it. The picked row is what `bazaar_action()` acts on,
##   the lit hotbar slot is what a click places, the lit rail tab is the page the keys now drive. That
##   is the verb's own sentence said about the noun, which is why the pair was never worth splitting.
##   Two marks were hiding inside the role without being selection. The settings rail lit its glyph
##   when a category was on or when the pointer was merely over it, so two categories could wear the
##   selection colour at once and the gold one under the hand was not the page you were on; the
##   counter's rail passes `on` alone, and the two rails are otherwise written to be one thing. The
##   pack grid's `HELD` badge marks a well that is usually not the cursor, in the cursor's own colour
##   family, which put two golds meaning two things on one grid.
##
##   The next step splits. The bench's `is_next` lamp keeps gold, since it marks the one node a
##   keystroke can buy and it is the middle rung of a lamp whose other rungs are done and locked. The
##   objective bullet and the hint bubble's spine do not, because both are printed on plates that take
##   no input at all. That is the sentence the item tooltip's spine was already moved off gold for, and
##   it leaves the bare screen carrying gold on exactly one thing, the lit hotbar slot.
##
## An engaged control is the fourth role and it stays open on purpose. `_settings_chip` fills gold for
## on while `_settings_controls` fills gold while it is capturing a key, so a state and a live input
## share one colour on one page. The split is decidable, since capture is where every key you press is
## going while on is a fact about the toggle. The repaint is not: the chip's dark type is a literal on
## a fill no contrast layer can name yet, so moving it would swap a measured pair for an unmeasured one.
const UI_ACCENT := Color(0.80, 0.66, 0.30)           ## gold accent: selection, the live verb, the next step
## The same gold seen under more light, which nine sites wrote out as a bare literal: the lit rail
## glyph, the lit settings glyph, the HELD badge, three detail-plate titles, the selected works row, the
## picked bench chip and the hot slider cap.
##
## It is gold and not a second amber. In HSV it sits at hue 42.3 against `UI_ACCENT`'s 43.2, at 0.67 of
## its saturation and 0.95 of its value. That derivation is clean in HSV and not in RGB: no single scale
## reproduces all three channels, so it is written as a channel lift and moving the accent moves this
## with it.
const GOLD_PALE_LIFT := Color(0.149, 0.171, 0.249, 0.0)
const GOLD_PALE := Color(UI_ACCENT.r + GOLD_PALE_LIFT.r, UI_ACCENT.g + GOLD_PALE_LIFT.g,
	UI_ACCENT.b + GOLD_PALE_LIFT.b)
## The same gold seen under less light, `GOLD_PALE`'s opposite number. It was written as the gold rung
## of the type ramp whose grey rungs are `UI_TEXT` / `UI_TEXT_DIM` / `UI_TEXT_FAINT`, and that claim did
## not survive being tested; see below, and see where its callers went. Three literals were doing this
## one job across five sites with nothing relating any of them to the accent they are a darker cut of:
## `0.451/0.365/0.180` on the pack ledger's heading and the works group titles, `0.451/0.402/0.280` on
## the "N more wait behind research" line and its BENCH pointer, and `0.58/0.48/0.32` on the detail
## plate's refusal note. The same shape as the four literals that became `UI_TEXT_FAINT` one layer up.
##
## Measured against the plates they print on, those three read 2.98, 3.35 and 4.37 to one, every one of
## them under 4.5. Subordinate was the intent at all five sites and they are still plainly subordinate
## here: this lands at 5.40:1 on `UI_MODAL` against `UI_TEXT_FAINT`'s 5.39 on the same plate. It is the
## third rung, in gold, at the third rung's readability. The `BAZAAR` title beside it is `UI_TEXT` at
## 12.57, so nothing has been promoted. A heading that measured 2.98 was not subordinate, it was absent.
##
## The argument for these headings being gold at all was that a rung is not a meaning: this is a type
## weight that happens to be gold, the way `UI_TEXT_FAINT` is a type weight that happens to be grey,
## carrying no affordance claim at any of its sites. The parallel is exactly where it fails. Grey is
## free, because nothing in this file means anything by grey beyond "less of your attention", so a rung
## cut from it inherits nothing. Gold is not free. It is the single channel the whole act-on-this signal
## was concentrated into, said one line from its own declaration, and a rung cut from a colour that
## already carries a meaning inherits the meaning and only changes the volume. So a gold heading says
## "act on this, quietly", which is the sentence that was stripped off seven surfaces to get here.
##
## The direction of the drop is the worst one available, because dim is already spoken for. An
## unaffordable row's name is `UI_TEXT_FAINT`, the dead verb is 0.44 grey, a muted slider is the accent
## at 0.55 alpha: dim is this file's word for "not for you right now". A dimmed cut of the affordance
## colour therefore reads as a disabled affordance, and it was sitting directly over the works rows,
## where dim really does mean you cannot afford it.
##
## So the label sites moved to `UI_TEXT_DIM`, the grey ramp's subordinate rung, which was already an
## asserted pair on this plate rather than a colour invented to receive them. It measures 6.15:1 on
## `UI_MODAL` against this constant's 5.40, brighter rather than quieter, and still a clear step under
## the `UI_TEXT` the rows and the ledger's verdict beside them are drawn in. Three have gone: the ledger
## heading, both works group titles, the research pointer. What is left here is the detail plate's
## refusal note, which is a state rather than a heading and belongs to a pass over that plate.
##
## The drop is uniform, and that is the derivation. Subtracting one value from all three channels leaves
## every channel difference untouched, so the hue is preserved exactly: 43.2 degrees here and 43.2 on
## `UI_ACCENT`, where `GOLD_PALE`'s uneven lift moves the hue by 0.9. It sits at 1.25x the accent's
## saturation and 0.83 of its value, the accent in shadow, which is what a subordinate heading is.
const GOLD_DIM_DROP := Color(0.14, 0.14, 0.14, 0.0)
const GOLD_DIM := Color(UI_ACCENT.r - GOLD_DIM_DROP.r, UI_ACCENT.g - GOLD_DIM_DROP.g,
	UI_ACCENT.b - GOLD_DIM_DROP.b)
## The colour the alert stack uses for a machine in trouble, named so the other site reporting the same
## fact says it the same way instead of reaching for the accent.
##
## A third caller has arrived since. The counter's cost numerals printed a shortfall in
## `0.804/0.427/0.376` at two sites, `_cost_glyphs` and `_detail_chip`, and on the selected row's brass
## plate that literal measured 4.20:1, under the floor. It is the same fact this constant already names,
## said in a second colour that nothing in the file related to the first; the note in
## `_settings_controls` had already written the argument out ("the only other thing in this UI that
## means 'this will not do what you think'") and then reached for a literal anyway. On brass it is 5.33
## now, and 6.33 and 6.02 on the two washes the same numerals land on elsewhere. The green partner is
## untouched: it clears everywhere it is drawn, and moving a passing colour buys nothing and costs a hue.
const UI_WARN := Color(0.96, 0.46, 0.30)
const UI_TEXT := Color(0.80, 0.83, 0.89)
const UI_TEXT_DIM := Color(0.54, 0.58, 0.66)
## The third rung of the type ramp. It replaces four literals doing one job across eight sites
## (`0.36/0.39/0.45` five times, plus `0.34/0.37/0.43`, `0.45/0.48/0.56` and `0.26/0.28/0.34`) which
## measured between 2.04:1 and 3.96:1 against the plates they print on, while the two inks above them
## clear 4.5:1 with room to spare. This is the same role at a value that clears it too.
##
## Named as much as lifted: a literal is invisible to `tools/check_text_contrast.gd`, and a floor can
## only be held against something that has somewhere to be held.
##
## Three more joined it on a second pass, missed the first time because they are not on a named plate:
## `0.40/0.42/0.48` on a locked bench chip (3.38 on the 0.022 wash), `0.40/0.43/0.50` on the settings
## detail plate's placeholder sentence (3.76 on a 0.22 black well over the modal) and `0.42/0.45/0.53`
## on the settings page's own `SETTINGS` word (3.95 on the modal). All three sit at hue 222 to 225
## degrees against this constant's 220, one rung below it in value and nowhere near the floor.
##
## There is no fourth rung, which is a finding rather than an aside. The obvious repair was another step
## down the ramp, which already carries a unit: `UI_TEXT_DIM` minus this is 0.04 on every channel. That
## colour measures 4.70 on the modal, 4.49 on the 0.022 wash and 4.19 on the 0.050 wash, so a rung below
## this one cannot clear 4.5 on the plates these three land on. The quiet those sites were reaching for
## does not exist in this palette. They are this rung: 5.15, 5.55 and 5.39 respectively.
const UI_TEXT_FAINT := Color(0.50, 0.54, 0.62)
const UI_SLOT := Color(0.11, 0.12, 0.16, 0.95)       ## empty hotbar slot well
## The modal plate, which the counter and the settings page carried as two copies of one literal. It is
## opaque on purpose. `UI_BG` is 90% because furniture sits over the world and is meant to; a modal is
## not furniture, and at 0.90 the objective banner read straight through the settings page.
const UI_MODAL := Color(0.062, 0.070, 0.094, 0.985)
## The rail behind both tab strips. `RAIL_ON_FILL` is a plain lift off this value, so a rail that moves
## now takes its own lit tile with it.
const UI_RAIL := Color(0.043, 0.049, 0.070, 0.92)

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## Fast-forward game clock, set by MainView. Above 1 it draws a small "▶▶ Nx" chip top-left; 1.0 draws
## nothing, which is the calm-screen default.
var time_scale: float = 1.0
## The tutorial chain, which answers "how do I play?". Set by MainView.
var objectives: Objectives
## Craftable machines for the CRAFT strip (set by MainView): [{name: String, cost: {item->count}}].
var craft_options: Array[Dictionary] = []
## Machine item id -> {color: Color, tag: String}, so machine items in the hotbar read as machines.
var machine_icons: Dictionary = {}
## The item id per craft row, parallel to `craft_options` and set by MainView, machines then tools. It
## lets the craft panel render either a machine or a tool per row without depending on insertion order.
var craft_ids: Array[StringName] = []
## The active carried-item slot in the inventory hotbar (set by MainView; mouse-wheel cycles it).
var inv_selected_getter: Callable
## Inspector facts for the machine under the aim, pushed here by MainView: name, recipe, routing mode
## and what it holds. Empty means nothing is hovered. Drawn top-right under FORGED.
var hover_info: Dictionary = {}
var _hover_rect: Rect2 = Rect2()          ## the inspector's canvas rect this frame (the pin region)
var _knob_hits: Array[Dictionary] = []    ## clickable knob chips this frame: [{rect, payload}]
## Stalled machines from `sim.machine_problems()`, pushed each frame. A compact left-edge stack that
## appears only when something is stuck, each row clickable to ping the culprit. `_alert_hits` holds
## this frame's clickable rects as [{rect, cell}].
var alerts: Array[Dictionary] = []
var _alert_hits: Array[Dictionary] = []
const ALERT_REASON: Dictionary = {
	&"blocked": "output blocked — dig a drain",
	&"no_fuel": "out of coal — feed it",
	&"no_input": "starved — nothing feeding it",
	# The Drift Rig has two outputs dug in different places, so "output blocked" cannot say which column
	# jammed (docs/DRIFT.md §7).
	&"blocked_pay": "ore column jammed — dig a drain UNDER it",
	&"blocked_spoil": "spoil column jammed — dig a drain BEHIND it",
	&"no_power": "no power — it eats a network, not a coal box",
	# Spent is not starved. A Head that has finished its vein has nothing wrong with it, and calling it
	# starved sends the player hunting for a feed problem that does not exist (docs/LODE.md §5).
	&"spent": "the vein is worked out — pick it up and move it",
	&"unlinked": "nothing to feed — a Spur must touch a Drill, or a Spur that reaches one",
}
## The title and new-game card. {} means closed; otherwise {seed, tint, tint_name, tints, has_save}.
var title_info: Dictionary = {}
## Minimap inputs pushed by MainView: a material-id to colour lookup, handed over as a Callable so the
## HUD stays decoupled, plus the camera focus and the world-space view size. The terrain image is cached
## and rebuilt only on a dig.
var minimap_color: Callable
var minimap_focus: Vector2 = Vector2.ZERO
var minimap_view: Vector2 = Vector2.ZERO
var _minimap_tex: ImageTexture
var _minimap_solid_count: int = -1
const CELL: float = 32.0

## On-demand overlays, pushed by MainView each frame. Only the hotbar, the FORGED chip and the current
## objective line are permanent; the crafting screen (E), the map (M) and the controls help (H/?) are
## summoned so they never clutter the playfield.
var inventory_open: bool = false   ## E/T: the Bazaar panel is open, and `bazaar_tab` picks the tab
var can_craft: bool = false        ## near a claimed Bazaar? gates the verbs, never the layout

## The Bazaar: one counter with three tabs (`docs/BAZAAR.md`).
##
## It is one panel at one size with the same three tabs, and it opens the same everywhere, including at
## the bottom of a shaft, where the point is to read every recipe and every tech price and plan the trip
## back. Away from a Bazaar the verbs are dimmed and one line says where they live; nothing moves and
## nothing disappears.
##
## There is no scrolling viewport and no dead space. The rows are a dense card grid across three
## columns, and the bottom of the panel is a detail plate drawing the thing you are about to buy large
## enough to want. Twenty-one rows fit unscrolled, which `check_pack_layout` asserts rather than trusts.
## The counter's width and the height it is allowed to reach rather than the height it takes.
##
## 608x348 on a 640x360 canvas is 91.8% of the screen by area. The counter takes the height its active
## tab asks for through `_bazaar_wanted_h`, clamped between `BAZAAR_MIN_H` and this. A fresh PACK
## therefore lands at 190, or 50.1% of the canvas: head 48 + one row of wells 46 + the gap 8 + the
## compact plate 72 + the foot 16. BENCH still asks for more than this and is still clamped to it.
##
## Both percentages are areas and neither is a height. That is worth a line because the two frames give
## different answers: as heights the same panels are 52.8% and 96.7%.
##
## The width does not move. The detail plate carries a machine's whole sentence, which is what the 528px
## of content width buys. Narrowing it to match one 46px well would trade a void for a truncation.
const BAZAAR_SIZE := Vector2(608.0, 348.0)
const PACK_CELL: float = 46.0         ## pitch of a pack well; the well itself is 6px smaller
const BAZAAR_RAIL: float = 56.0       ## the vertical tab rail down the left edge
const BAZAAR_PAD: float = 12.0
const BAZAAR_HEAD: float = 48.0       ## title + the carried-goods strip, with air under it
const BAZAAR_FOOT: float = 16.0       ## the key legend
## The detail plate is the height of what it draws, and it draws two different things.
##
## The full plate is for a thing you are deciding whether to spend on: a lit square, a title, a two-line
## blurb and a row of price chips. The square is `DETAIL_ART` on a side with `DETAIL_PAD`
## above and below, which is the 88 exactly. The chips are the deepest thing in the text column beside
## it, starting 62 below the plate's top and standing 19 tall. So 81 of the 88 is spoken for and 78 of
## it by the square alone, and the two columns reach the same floor independently. Nothing here scales:
## a coefficient in front of the 88 clips the chips before it has taken a fifth of the height away.
##
## The compact plate is for a thing there is nothing to weigh. What is already in the pack has no price
## and PACK's own summary has no cost, so neither draws the chip row. The deepest thing left is then the
## last blurb line plus one fact under it. That sum is `BAZAAR_DETAIL_MIN`, and the square becomes
## whatever fits beside it, which is why `_draw_bazaar_detail` reads it off the plate's rect.
##
## The plate sits inside the height it is a share of. A fresh PACK is 118px of head, wells, gap and foot
## plus the plate, so the share is plate/(118+plate) and shrinking the plate shrinks the panel under it.
## 88 of 206 is 42.7% and 72 of 190 is 37.9%. `check_pack_layout` floors the plate at 70px, so 37.2% is
## all this lever has ever been worth.
const DETAIL_PAD: float = 10.0        ## plate edge to the art square, and the same again under it
const DETAIL_ART: float = 68.0        ## the lit square a thing on sale is drawn in
const BAZAAR_DETAIL: float = DETAIL_PAD * 2.0 + DETAIL_ART
## The lamp's rings and the thing inside them are sized off the square rather than written down, because
## the square is no longer one size. An 8px step off a 34px radius spills over the edge of a compact
## plate's square, and a 44px glyph would swallow the rim the lamp needs to read against.
const DETAIL_GLYPH_INSET: float = 12.0  ## square edge to the thing in it
## Ring to ring, as a share of the square's radius rather than the 8px it is at the full depth.
const DETAIL_LAMP_STEP: float = 8.0 / (DETAIL_ART * 0.5)
## The compact plate's text column, which is what sets its height. `DETAIL_LINE` is what the plate
## reserves per blurb line rather than what the face draws, because `draw_multiline_string` takes its own
## pitch from the font. The tail pays for what hangs off the last baseline.
##
## The reserve is a floor and not a cap. Both numbers have to stay `const`, because `BAZAAR_MIN_H` is
## built out of `BAZAAR_DETAIL_MIN` and `check_pack_layout` asserts that a fresh pack lands on that
## floor rather than being caught by it, so they cannot be the font's own measurement. What they can
## stop being is the last word: `_hold_overflow_h` measures the sentence about to be drawn and adds the
## font's real line height for every line past these two.
const DETAIL_BLURB_Y: float = 40.0    ## first blurb baseline, below the plate's top
const DETAIL_BLURB_LINES: int = 2     ## the lines the floor pays for, not a limit on what the blurb takes
const DETAIL_LINE: float = 12.0       ## reserved per blurb line
const DETAIL_TAIL: float = 8.0        ## last baseline to the bottom of the plate
const DETAIL_BLURB_SIZE: int = 9      ## and the size it is set at, which is what makes the pitch measurable
## Where the fact under the blurb sits when the plate is at its floor, which is the sum the floor is
## written as. The plates take it off their own bottom edge instead, so a plate that grew a line carries
## the fact down with it rather than printing it through the blurb's last row.
const DETAIL_FACT_Y: float = DETAIL_BLURB_Y + DETAIL_LINE * DETAIL_BLURB_LINES
const BAZAAR_DETAIL_MIN: float = DETAIL_FACT_Y + DETAIL_TAIL
## The horizontal furniture the text column is bought out of: the square's right edge to the first
## letter, and the last letter to the margin the verb button keeps. Both were repeated literals at the
## two plates that draw a blurb, which is how the hold plate came to wrap against a 260 that sums to
## nothing.
const DETAIL_TEXT_GAP: float = 14.0
const DETAIL_TEXT_RIGHT: float = 24.0
## The pack plate's verb and its key, named because the column's width is measured off the button and
## the button is drawn from the same pair. A second copy of the word would be a width that stops
## matching the button the day the word changes.
const HOLD_VERB: String = "HOLD"
const HOLD_KEY: String = "ENTER"
const BAZAAR_DETAIL_GAP: float = 8.0  ## rows to plate: the body's one gap, named once for its three sites
## Head, one row of pack wells, the gap, the detail plate and the foot, added up rather than written
## down. It was a 196 sitting beside that same sentence, which sums to 206.
##
## The plate term is the compact one, because this is PACK's floor and PACK never draws the other. A
## floor carrying the taller plate would sit 16px above where a fresh pack's own sum lands, and
## `check_pack_layout` asserts that a fresh pack lands on this floor rather than being caught by it.
const BAZAAR_MIN_H: float = BAZAAR_HEAD + PACK_CELL + BAZAAR_DETAIL_GAP + BAZAAR_DETAIL_MIN + BAZAAR_FOOT
## Elevation, not a gold slab. The live tab on both rails used to be a filled brass-tinted tile plus an
## accent edge plus a lit glyph, which is three signals for one bit of state. This is a lift off
## `UI_RAIL`, so the brass is spent once, on the edge, and it is derived rather than merely described as
## derived: the arithmetic below reproduces the bytes of the `Color(0.090, 0.100, 0.130)` it replaces.
##
## The lift is per-channel and deliberately not flat. 0.047 / 0.051 / 0.060 rises toward blue, so the
## lit tile comes up slightly cooler than its rail rather than just brighter, which keeps it from
## reading as the gold beside it. Alpha is zeroed: the rail is 92% and the tile inside it is opaque.
const RAIL_ON_LIFT := Color(0.047, 0.051, 0.060, 0.0)
const RAIL_ON_FILL := Color(UI_RAIL.r + RAIL_ON_LIFT.r, UI_RAIL.g + RAIL_ON_LIFT.g,
	UI_RAIL.b + RAIL_ON_LIFT.b)
const BAZAAR_GUTTER: float = 10.0
## Three columns of eight is twenty-four rows, not the 22 a two-column layout needed, so the row can
## afford the two pixels back and the type can breathe.
const BAZAAR_ROW_H: float = 24.0
const BAZAAR_COLS: int = 3
## How long the counter takes to arrive. A panel that appears fully formed in one frame is the loudest
## thing separating a menu from an interface, and 0.13s of rise is cheaper than any art.
const BAZAAR_RISE: float = 0.13
const TAB_PACK: int = 0
const TAB_WORKS: int = 1
const TAB_BENCH: int = 2
const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]
var bazaar_tab: int = TAB_PACK
var _bazaar_t: float = 0.0            ## 0..1 open ease, driven in _process
var _bazaar_h: float = BAZAAR_SIZE.y  ## the height the counter is currently at, eased toward its tab's
## The rack, the shop half of WORKS, set by MainView beside `craft_options` in the same {name, cost}
## shape with `rack_ids` parallel to it. It is kept a separate list rather than appended to the craft
## list because the two columns mean different things: the left is what you build from your own
## materials, the right is what you buy with refined goods (`docs/BITS.md` §7).
var rack_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
## The highlighted row on the active tab. One cursor serves the whole panel, and what "acts" means is
## the tab's own business: buy, craft or research.
var bazaar_row: int = 0
## ...and where that cursor was left on each of the other two, one slot per tab. The cursor is shared
## but the place is not, so a glance sideways no longer costs the walk back down a long list. It is kept
## here rather than as three cursors because everything reading the selection asks the one that is live.
var _bazaar_rows: PackedInt32Array = PackedInt32Array()
var show_minimap: bool = false
var minimap_large: bool = false    ## M cycles corner → LARGE (centred) → hidden
## True while a grapple line is on screen, hook in flight or anchored, pushed every frame by MainView.
## An arrival ceremony is held while it is set: the plate is centred on the body and the rope hangs
## through the same column so the two cannot share a frame legibly.
var rope_active: bool = false
## The player's ping marker in world coords, where Vector2.INF means none, set by clicking the open map.
## MainView owns it and pushes it here and to the renderer, which draws the in-world beacon.
var ping_world: Vector2 = Vector2.INF
var show_help: bool = false
var show_dashboard: bool = false   ## G: the production dashboard, throughput bars plus factory census
## The settings page, reached with ESC on a calm screen. Values are read straight off the `Settings`
## statics and every control click returns a payload through `settings_click()`, so the HUD never
## touches InputMap, audio or the config file.
var settings_open: bool = false
var settings_capture: StringName = &""     ## the action awaiting its new key ("press a key…")
var _settings_hits: Array[Dictionary] = [] ## clickable controls this frame: [{rect, payload}]
var _slider_rects: Dictionary = {}         ## slider id -> its bar Rect2 this frame (drag support)
var settings_cat: int = CAT_AUDIO          ## which face of the page is open (the rail's selection)
var _set_h: float = SET_MIN_H              ## eased toward `_settings_wanted_h()`, like the counter
var _set_t: float = 0.0                    ## the page's own rise, 0..1; drives the scrim and the defocus
## The dashboard and the key list have no rise of their own, so they share one. Without it they were the
## two modals of four that left the world sharp behind them.
var _plain_t: float = 0.0
var settings_row: int = 0                  ## the keyboard cursor on the binding list

## Transient toast for "SAVED", "LOADED" and other short notices. Set via `flash()`; fades on its own.
var _flash_text: String = ""
var _flash_life: float = 0.0

## The descent readout and its arrivals. `depth_row` is poked every frame by MainView, and the arrival
## is a one-shot banner fired when the body first crosses into a band it has not been in.
var depth_row: int = Strata.SURFACE_ROW
var _arrival_text: String = ""
var _arrival_kicker: String = ""
var _arrival_color: Color = Color.WHITE
var _arrival_life: float = 0.0
const ARRIVAL_HOLD: float = 3.4          ## total life of the banner, fade included

## The just-in-time hint bubble, pushed by MainView from the Hints tracker: a small speech bubble
## anchored near the body that teaches a newly acquired item's use. Empty text means none.
var hint_text: String = ""
var hint_anchor: Vector2 = Vector2.ZERO   ## canvas-space point the tail points at (above the head)
var hint_alpha: float = 0.0

## Item tooltips, which say what an item is for when you hover a hotbar or pack slot. One line per id,
## the reference card behind the one-shot acquisition hints: machines answer "what does placing it buy"
## and resources answer "what wants this". An absent id draws no purpose line.
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
	# Each line is the bit's own entry in `BitRules.BIT` said in the second person. `keeps: false` is why
	# the Broad's says nothing reaches your pack, `recovery: 0.85` is the Lance's long pause, and
	# `grain_only: true` is why the Wedge does nothing across the grain.
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


## Announce arrival in a new stratum, which is the one moment the descent gets to be an event.
##
## It is held rather than dropped while the big map is up. The plate is centred at y 62..112 and the
## large map's panel spans 181..459 by 41..319, so an arrival crossed with the map open lands inside it,
## a measured 222x50 overlap held by `check_hud_layout`. The goal plate, the pack bar and the inspector
## simply stand down there because they are persistent and come back. This one is a one-shot with a 3.4s
## life, so standing it down would delete it rather than compose it, and you would cross into the
## deepslate and never be told. It waits for the map to close and then fires in full.
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


## Is the announce channel occupied right now? One caller, the controller, uses it to hold a
## just-in-time lesson back rather than stack it under the ceremony. Only one primary attention state
## may be up at a time, and this is the predicate that makes that rule enforceable.
func announcing() -> bool:
	return _arrival_life > 0.0


## The conditions under which an arrival ceremony is held.
##
## Held rather than dropped. The plate is a one-shot with a 3.4s life, so standing it down deletes the
## announcement instead of composing it. Its clock stops and it draws nothing while held. It then
## resumes with its remaining life intact.
##
## Two conditions, for two collisions. The large map shares the plate's rectangle in both directions. A
## ceremony firing under an open map waits in `_pending_arrival`, and one already up when the map opens
## freezes here, since `_draw_arrival` runs after `_draw_minimap`. A live grapple line shares the
## plate's column instead. The camera centres the body, so the plate spans canvas y 61.6 to 111.6
## directly over the miner and any rope reaching them passes through it. No position on a 640-wide
## canvas avoids that so the rope case can only be solved in time.
##
## Every gate site calls this rather than testing the conditions inline. A condition added to some sites
## and not others freezes the clock while the plate still fires and still draws.
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
	# The counter's arrival, eased out so it decelerates into place rather than sliding at a constant rate.
	# That is the difference between a panel that lands and a panel that is dragged on.
	var target: float = 1.0 if inventory_open else 0.0
	var step: float = delta / BAZAAR_RISE
	_bazaar_t = clampf(_bazaar_t + (step if target > _bazaar_t else -step * 2.0), 0.0, 1.0)
	# The counter's height follows the tab on the same clock as its rise. It is snapped when closed so that
	# opening never animates a size, and snapped near the target so a settled frame is a settled
	# measurement: `check_hud_layout` photographs this panel, and a footprint that depends on how many
	# frames have passed is not a footprint.
	if inventory_open or _bazaar_t > 0.0:
		var want: float = _bazaar_wanted_h()
		if _bazaar_t <= 0.0 or absf(want - _bazaar_h) < 0.5:
			_bazaar_h = want
		else:
			_bazaar_h += (want - _bazaar_h) * clampf(delta / BAZAAR_RISE, 0.0, 1.0)
	# The settings page follows its category on the counter's clock and by the counter's rule, snapped
	# while closed for the reason above.
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


## The settings page's rise, on the same curve. It is public because `MainView._update_defocus` racks
## the world out of focus behind it, and a modal that leaves the world sharp reads as a sticker.
func settings_ease() -> float:
	var u: float = 1.0 - _set_t
	return 1.0 - u * u * u


## The dashboard and the key list, on the same curve as the other two. Public for the same reason:
## whichever modal is up should rack the world, and racking only the modals that already had a rise is
## how two of the four came to read as stickers on a sharp frame.
func plain_modal_ease() -> float:
	var u: float = 1.0 - _plain_t
	return 1.0 - u * u * u


## Every helper surface, classified. The rule is that only one primary attention state may be on screen
## at a time, and this is the inventory that makes it checkable. It is a constant rather than a document
## because `tools/check_hud_layout.gd` asserts that every `_draw_*` method on this class appears here,
## so adding a surface without deciding what kind of thing it is fails rather than quietly becoming the
## eighth thing on the screen.
##
## The tags and what each one is allowed to do:
##
##   `critical`      interrupts. It arrives on its own schedule and expects to be read now, and at most
##                   one may be on screen at a time, which is the rule this registry is about.
##   `active`        describes what you are doing or looking at this moment. Several may coexist, since
##                   they answer questions you just asked with the cursor or the verb.
##   `discoverable`  you summoned it, so it may cover everything.
##   `ambient`       always-on state you read at a glance and never respond to. It must never move, and
##                   it may not become any of the above.
##   `internal`      not a surface but a drawing helper another entry uses, listed so the check above is
##                   total, and so "helper or screen" is a decision someone made.
##
## `_draw_title` is `discoverable` on a technicality worth stating. You did not summon it, but it owns
## the whole screen by design and returns before anything else draws, so nothing can collide with it.
const HELPER_TAGS: Dictionary = {
	# critical: the interrupt channel, and the one with a one-at-a-time rule
	"_draw_arrival": &"critical",         # the stratum plate: "stop, look"
	"_draw_flash": &"critical",           # save/load toast
	"_draw_alerts": &"critical",          # a machine is stalled and will stay stalled
	"_draw_hint_bubble": &"critical",     # a lesson, which is why it yields to the plate
	# active: about the thing under your hand right now
	"_draw_objective_line": &"active",
	"_draw_hover": &"active",
	"_draw_item_tooltip": &"active",
	# discoverable: you pressed a key to get it
	"_draw_minimap": &"discoverable",
	"_draw_inventory_overlay": &"discoverable",
	"_draw_dashboard_overlay": &"discoverable",
	"_draw_help_overlay": &"discoverable",
	"_draw_settings_overlay": &"discoverable",
	"_draw_title": &"discoverable",
	# ambient: state, read at a glance, never answered
	"_draw_depth": &"ambient",
	"_draw_forged": &"ambient",
	"_draw_inventory": &"ambient",        # the hotbar
	"_draw_hint": &"ambient",             # the bottom-left key legend
	"_draw_fastforward": &"ambient",
	# internal: helpers, not screens
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

## The paused chip is a critical surface with no function of its own, being eight lines inline in
## `_draw()`. It is named here so the registry is honest about it.
##
## It lives in the left column under the fast-forward chip, and it may not move back to the centre. It
## used to print across the objective line at y=8, was pushed down to y 50..76, and landed inside the
## arrival plate's scrim core at `CANVAS.y * 0.26 - SCRIM_ABOVE`, or y 61.6..111.6. Pausing on the frame
## you cross a stratum is not exotic, because crossing a band is when a player stops to read. The
## ceremony, the objective line and the lesson bubble are all centred, so three surfaces compete over a
## 100px strip there while the left column holds two chips and 300px of nothing.
const PAUSED_CHIP: Rect2 = Rect2(10.0, 60.0, 104.0, 22.0)


## Is a modal up: the counter, the dashboard, the controls page or the settings page. All four dim the
## world and put a plate over the middle of it, so while one is open it is the screen and the furniture
## around it stands down. It is written once because it was spelled out three times, and one of the
## three had a different idea of which screens counted.
##
## The minimap is deliberately not in here. It is summoned rather than modal, and it has the opposite
## rule: the furniture stands down for the large form only, inside the surfaces it collides with.
func _modal_open() -> bool:
	return inventory_open or show_dashboard or show_help or settings_open


func _draw() -> void:
	_tooltip_item = &""    # re-captured by whichever slot the cursor sits on this frame
	_alert_hits.clear()    # stale unless _draw_alerts repopulates it this frame (menus suppress it)
	# While the title is open nothing else matters: the veil and the new-game card are the screen.
	if not title_info.is_empty():
		_draw_title()
		return
	# --- always on, unless a modal has taken the screen ---
	# Every line in here is world furniture, and each of the four modals draws a plate across the middle of
	# a 640x360 canvas; the counter alone is 608 wide and reaches 348 tall. Drawn unconditionally, the
	# depth chip and the hotbar came out in two pieces, half dimmed by the modal's scrim and half covered
	# by its plate, and a chip cut by an edge reads as a drawing fault.
	if not _modal_open():
		_draw_forged()         # top-right production chip (small)
		_draw_depth()          # top-left depth readout, the one number a descent game owes you
		_draw_objective_line()  # top-centre, one current step, the signpost without the wall of text
		_draw_inventory()      # bottom-centre hotbar
		_draw_hint()           # tiny bottom-left key legend, which replaces the giant footer
		_draw_hint_bubble()  # just-in-time teaching near the body (hidden while a menu dims the world)
		_draw_alerts()       # left-edge stalled-machine stack (only when something's stuck)
	# The inspector stands down inside itself rather than here, because it owns a click region as well as
	# a panel. Skipping the call would leave `_hover_rect` at whatever it held before the menu opened, and
	# `_cursor_on_hover_panel()` reads that rect, so a click on the counter would land on a config knob
	# belonging to a machine nobody can see. `_draw_hover` returns after clearing for the same reason.
	_draw_hover()          # inspector for the machine under the cursor (only when one is hovered)
	# --- on demand (summoned, so they never clutter) ---
	if show_minimap:
		_draw_minimap()    # M: top-right world map
	if inventory_open:
		_draw_inventory_overlay()  # E/T: the Bazaar, one counter with three tabs (docs/BAZAAR.md)
	if show_dashboard:
		_draw_dashboard_overlay()  # G: throughput bars and factory census
	if show_help:
		_draw_help_overlay()      # H, or the slash key: the full controls list
	if settings_open:
		_draw_settings_overlay()  # ESC: audio, feel, and the remap page
	if paused_getter.is_valid() and bool(paused_getter.call()):
		# Under the objective line, not on top of it. Both were aimed at top-centre at y=8 and the objective
		# panel is 37 tall so PAUSED printed across the one line telling you what to do next.
		_panel(PAUSED_CHIP)
		draw_string(_font, PAUSED_CHIP.position + Vector2(12.0, 15.0), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)
	_draw_fastforward()    # top-left "▶▶ Nx" chip when the game clock is sped up
	# The stratum plate is the one channel that means "stop, look", so it does not fire over a modal, where
	# there is nothing to look at and it prints through the price column. Holding it costs nothing, since
	# the depth readout comes back with the world and names the band you are in.
	if not _modal_open():
		_draw_arrival()    # the stratum banner, on the frames after you first cross into one
	_draw_flash()          # transient toast (save/load feedback)
	_draw_item_tooltip()   # hovered-slot tooltip, drawn last so it rides over every panel


## The title and new-game screen: a dark veil over the live, paused world, the game's name, and the two
## choices that make this world yours. It is deliberately spare, because the world glowing behind the
## veil is the real menu art.
func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS)), Color(0.03, 0.035, 0.06, 0.82))
	var cx: float = CANVAS.x * 0.5
	var y: float = CANVAS.y * 0.30
	# The name, tracked out wide, with the rule under it in the name's own ink rather than in the accent.
	# The 2px gold rule was retired from eight panels; this was the ninth, and it survived that pass only
	# because it is drawn by hand here instead of through `_panel`. A wordmark's rule is part of the
	# wordmark, so it takes one colour with the letters above it rather than a second one underneath.
	# The only thing on this screen a keypress reaches, `[ENTER] descend`, is the only gold left here.
	var title: String = "S I N K F O R G E"
	var mark := Color(0.97, 0.90, 0.62)
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_font, Vector2(cx - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, mark)
	draw_rect(Rect2(cx - tw * 0.5, y + 7.0, tw, 2.0), mark)
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
		# The swatch row is the hardest case on the page, because here the thing being chosen is itself a
		# colour. A 1.5px `UI_ACCENT` outline was the whole mark, and gold sits in one of the five tints'
		# own neighbourhood, since miner's gold is (1.0, 0.90, 0.66), so the caret was a hue laid over hues
		# at lighter weight than any other cursor in the game. The shared ring is 2px with a dark keyline
		# under it, which is a value step and a shape whatever colour it lands beside.
		if i == sel:
			_focus_ring(sw)
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


## The transient toast: a small accented chip centred under the objective line, fading over its last
## half-second. Cheap reusable feedback for one-shot actions such as F5 save and F9 load.
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


## The just-in-time hint bubble: a small speech bubble with a tail pointing down at the body, teaching
## the item that just landed in the pack. It is word-wrapped, gold-capped like every panel, faded by the
## tracker's envelope, and clamped on-canvas so a body near a world edge still gets taught.
##
## `hint_box` is the box `_draw_hint_bubble` actually draws, extracted so a layout check can size every
## lesson without reimplementing the layout; a second copy of this arithmetic would agree with itself
## and not with the screen.
##
## Size was the whole complaint. At 11pt over a 230px wrap this box was 250x52 on a 640x360 canvas, 39%
## of the width and 14% of the height, set at nearly the objective banner's weight. 8pt over 176 halves
## the footprint, and the lessons were rewritten to one line each in the same pass, because a smaller
## box around the same paragraph is just a smaller paragraph.
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
	if origin.y < 38.0:                       # never under the objective line, so flip below the anchor
		origin.y = tail.y + 7.0
	var a: float = hint_alpha
	var rect := Rect2(origin, Vector2(w, h))
	# Elevation, not an outline. A flat fill inside a 1px border with a full-width bar across the top is a
	# dialog box and reads as one. A soft drop shadow puts the plate above the world instead of cut into
	# it and the rule shrinks to a left edge so the eye lands on the word rather than the frame.
	#
	# That edge is not the accent, because a hint is a thing to read and not a thing to press. It is the
	# sentence the item tooltip's spine was moved off gold for, and this plate has even less claim to it:
	# the tooltip at least describes what the cursor is over, while this one arrives on its own and
	# points at your body. `UI_EDGE_HI` at full strength is what that spine draws in, and the swap costs
	# nothing worth having, 6.24:1 against this plate before and 6.06:1 now.
	_round_rect(Rect2(rect.position + Vector2(0.0, 1.5), rect.size), 4.0, Color(0.0, 0.0, 0.0, 0.38 * a))
	_round_rect(rect, 4.0, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), Vector2(1.5, h - 6.0)),
		Color(UI_EDGE_HI.r, UI_EDGE_HI.g, UI_EDGE_HI.b, a))
	var tip_y: float = tail.y if origin.y < tail.y else origin.y - 1.0   # tail reaches toward the body
	var base_y: float = (origin.y + h) if origin.y < tail.y else origin.y
	var tx: float = clampf(tail.x, origin.x + 10.0, origin.x + w - 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 3.5, base_y), Vector2(tx + 3.5, base_y),
		Vector2(tx, tip_y)]), Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_multiline_string(_font, origin + Vector2(8.0, 5.0 + 8.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.92, 0.88, 0.74, a))


## Factory alerts: a compact left-edge stack of stalled machines, shown only when something is stuck, so
## a healthy factory draws nothing here. Each row names the machine, the count and the reason, and is
## clickable to drop a ping on the culprit; the camera is body-locked, so a beacon is the honest way to
## get there. MainView pushes `alerts` and routes the click through `alert_click()`. Capped at 5 rows so
## a cascading failure cannot wallpaper the screen.
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


## Route a click at `mouse`, in canvas coords, to the alert it hit, returning {cell: Vector2i} to ping
## or {} on a miss. MainView owns the ping and the HUD only reports the hit.
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


## The depth readout, top-left. Metres below the surface datum and the name of the band you are in, in
## that band's own colour, so the number and the world's palette agree. It is permanent: in a game whose
## whole subject is descending, "how far down am I" is not an optional overlay.
##
## The chip's width sits on its own, so the objective banner can measure what it must not grow under.
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


## The arrival plate, which fires only the first time you enter a band, because the value is that it is
## rare.
##
## Weight in a title card comes from spacing, not from point size. At three times this size across a
## full-width bar it read as a modal dialog: it covered the play space, it competed with the objective
## banner directly above it and the first instinct was to dismiss it. So: half the type, letters
## tracked apart, a kicker line above it, rules only as wide as the text, and no panel at all.
const ARRIVAL_SIZE: int = 15             ## canvas px; the objective banner above runs at 13
const ARRIVAL_TRACK: float = 3.4         ## extra px between letters, which makes small type read as engraved

## The scrim. Panel-less type only reads while the thing behind it is dark, and every stratum plate
## fires underground except the first-automation hail, which fires on the surface at midday against a
## bright sky, a mountain range and a rotating gearwheel, where the words simply disappeared. The fix is
## not a panel, because a panel is the modal dialog this design escapes, but a soft field of dusk under
## the words that fades to nothing in every direction and so has no edge to read as a shape.
const SCRIM_COLS: int = 12               ## quads across the field...
const SCRIM_ROWS: int = 8                ## ...and down it
## Peak darkening, dead centre. It was 0.80 until it was measured. The scrim is
## `Color(0.02, 0.025, 0.04)` drawn over the frame, which is a multiply in all but name: it keeps a
## fixed fraction of whatever is underneath. Underground the rock behind it sits at a luma near ten and
## barely moves. The rope is hemp at 0.76/0.63/0.42.
##
## `check_ceremony_reads` measured what that costs. Across the plate the rope moved a mean of 26.5 dE
## out of the 41.4 of separation it had from its backing while the rock behind it moved 6.6. The veil
## took four times more from the line you are hanging from than from the background it was drawn to
## suppress. The plate cannot be moved aside either. The camera centres the body and the plate is
## centred too, so its 420px footprint on a 640px canvas always contains the miner's column.
##
## The words get their contrast locally instead, from a near-black shadow a pixel behind each glyph.
## That buys the same separation inside a letter's width and works on bright sky as well as dark rock.
## The field veil is then only what a compositional weight needs.
const SCRIM_ALPHA: float = 0.28
const SCRIM_PAD: float = 34.0            ## px of solid core beyond the widest line
const SCRIM_INK := Color(0.02, 0.025, 0.04)   ## the veil's own colour, now spent per glyph instead
const SCRIM_INK_OFF := Vector2(1.0, 1.0)      ## a pixel down and right, which is enough at this type size
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
	# The ceremony is furniture while it is up, so a layout check has to be able to see it. It draws no
	# `_panel()`, deliberately, so `panel_probe` was blind to it. It is registered as the solid core only
	# and not the feathered extent, because the feather fades to nothing by construction and calling it
	# occupied would report collisions with regions that are visually empty.
	if probing:
		panel_probe.append(Rect2(CANVAS.x * 0.5 - core_half, y - SCRIM_ABOVE,
			core_half * 2.0, SCRIM_ABOVE + SCRIM_BELOW))
	_draw_scrim(core_half, y, a)
	# The shadow carries the contrast the veil used to. It is drawn under every glyph rather than under
	# the whole plate so it costs the world a pixel around each letter instead of a 420x50 field.
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


## The arrival plate's soft ground, drawn as an interpolated grid rather than as a stack of bands.
##
## Constant-alpha strips with a half-pixel overlap are precisely backwards: where two translucent strips
## overlap their alpha composites, so every seam comes out darker than either neighbour and the scrim
## rasterizes as venetian blinds across the sky. A grid has no seams to hide, since adjacent quads share
## their edge vertices and those vertices' colours, so the hardware interpolates one continuous field
## and the falloff can be smoothstepped on both axes, putting a zero derivative at every outer edge.
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


## ...and a bell down the plate so it has no top or bottom edge either.
func _scrim_v(yy: float, top: float, bot: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, absf(yy - (top + bot) * 0.5) / maxf((bot - top) * 0.5, 0.001))


func _scrim_c(weight: float, a: float) -> Color:
	return Color(0.02, 0.025, 0.04, SCRIM_ALPHA * a * weight)


## Letter-tracked text. `draw_string` has no tracking, and tracking is the whole difference between
## small type that reads as a label and small type that reads as a caption.
func _draw_tracked(text: String, at: Vector2, size: int, track: float, color: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


func _tracked_width(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(0, text.length() - 1))


## The fast-forward chip, top-left: a small "▶▶ Nx" tag shown only while the game clock is sped up, so a
## visibly racing world has an on-screen cause. Hidden at 1x to keep the default screen calm.
func _draw_fastforward() -> void:
	if time_scale <= 1.0:
		return
	var label: String = "▶▶ %dx" % int(time_scale)
	var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var chip := Rect2(10.0, 34.0, tw + 24.0, 22.0)   # under the depth chip, which owns the corner
	_panel(chip)
	draw_string(_font, chip.position + Vector2(12.0, 15.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)


## The FORGED production chip, top-right: an ingot swatch and the lifetime ingot count in a small panel,
## on the same skin as the inspector and the minimap rather than as bare floating text.
##
## Its width sits on its own too, being the other wall the objective banner has to stay inside of.
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
## to sit on one step before it comes back.
const HINT_HOLD: float = 9.0
const HOVER_MAX_W: float = 300.0   ## the inspector may grow to fit its widest line, but no further
## ...and never shrinks below this, so a one-word machine name still reads as a panel rather than a
## chip. It is named because `check_hud_layout` needs the same number to reason about the right column,
## and a check that re-types a literal is checking its own arithmetic against itself.
const HOVER_MIN_W: float = 218.0
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0

## The permanent objective plate is retired after the opening lesson.
##
## The problem was permanence rather than existence. The game may say what has just become possible, but
## it may not stand over the player while they do it. The how-to line already behaved that way, holding,
## fading and returning on a stall; the goal line sat at top-centre through every step.
##
## After the opening lesson nothing is offered. Later steps do not announce, hold or fade, and guidance
## becomes reactive, returning only once the player has genuinely stalled. The world carries it
## meanwhile, since `world_renderer._draw_guide_targets()` pulses a ring on the cells the step points at.
##
## `GOAL_PERSISTS_THROUGH` is how many steps count as the opening lesson and keep the permanent plate,
## so nobody is stranded on the first thing they ever see. At 1 that is the first step only; raise it to
## teach for longer, or set it to 0 to remove the plate entirely.
const GOAL_FADE: float = 1.2       ## how long reactive guidance takes to arrive once you have stalled
const GOAL_PERSISTS_THROUGH: int = 1


## The objective line, top-centre: the current step only as a gentle nudge, and a pure read of the
## Objectives tracker. Top-centre sits over open sky, so it never buries the avatar. When the whole
## chain is done it shows a brief "all set" and then auto-hides.
##
## The banner leads with the short goal, "Mine 4 ore", which is all a player needs once they know the
## verb, and carries the full how-to underneath only while that is wanted: for the first few seconds
## after a step opens and again once you have been stuck long enough to want it back. In between the
## world does the talking. The pulsing target ring already points at where the step happens.
func _draw_objective_line() -> void:
	if objectives == null:
		return
	if objectives.all_done() and objectives.done_for() > 5.0:
		return  # finished + lingered → clear the screen for veterans
	# The big map is the screen. It is centred and 272 tall in a 360 canvas, so its panel top sits at y=41
	# while this banner reaches y=45 whenever its how-to line is up, and whether the how-to is up depends
	# on `step_age`, which made the collision intermittent. Standing down here fixes it for every timing
	# rather than nudging the map: someone who opened the whole-world view is looking at the world.
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
		# Reactive guidance, the only thing a later step may put on screen. It arrives once you have sat on a
		# step long enough to want it and it is zero until then.
		var stalled: float = clampf((age - HINT_STUCK) / GOAL_FADE, 0.0, 1.0)
		if objectives.current_index() < GOAL_PERSISTS_THROUGH:
			# The opening lesson keeps the plate, and the how-to that arrives with it and fades.
			if age < HINT_HOLD + HINT_FADE:
				hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
			elif age > HINT_STUCK:
				hint_a = stalled
		else:
			goal_a = stalled                     # nothing is offered after the first lesson
			hint_a = stalled
		if hint_a > 0.0:
			hint = str(step["label"])
	if goal_a <= 0.0 and hint_a <= 0.0:
		return                                    # nothing to say: leave the sky alone
	var fs: int = 13
	var hfs: int = 10
	var pad: float = 12.0
	# The free span. The banner is centred between two fixed chips, depth on the left and FORGED on the
	# right, so a long how-to line grows symmetrically until the plate's frame runs under one and through
	# the other. Clamp to what is actually free and let the how-to be the part that gives, because the
	# goal is the half you need.
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
	# The bullet belongs to the sentence, so it is drawn in the sentence's ink. It used to be the accent,
	# which put "the thing you can act on" on a banner that takes no input at all, a few dozen pixels
	# from a lit hotbar slot on the bare screen that does. Nor was the colour carrying the state: the
	# state is the dot's presence, since a finished ladder draws a tick inside the line instead of a dot
	# beside it. The colour here was free, and free is not a reason to spend the one colour that means
	# something. 8.25:1 against this plate before, 15.91:1 now.
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, Color(col, col.a * goal_a))
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * goal_a))
	if hint != "":
		draw_string(_font, Vector2(rect.position.x + pad, cy + 18.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UI_TEXT_DIM, hint_a))


## Trim a string until it fits `max_w`, with an ellipsis standing in for what was cut. It is
## deliberately not a binary search: these are one-line labels, the loop runs a handful of times, and a
## wrong answer here is a sentence running off a panel rather than a frame-rate problem.
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


## Layout probe. While `probing` is set, every panel drawn this frame appends its rect here and nothing
## else changes. The HUD is immediate-mode with no Control nodes so nothing about the layout can be read
## off the scene tree. A layout check that re-derived where each chip goes would agree with itself by
## construction and catch nothing. These two lines let `check_hud_layout` observe the boxes the HUD
## actually drew, at real screen size, in the real scene.
##
## The flag is the whole guard because the one it replaces could never be false. `if panel_probe != null:`
## reads as "unset" but a `static var panel_probe: Array[Rect2]` initialises to `[]` and in GDScript
## `[] != null` is true, checked against 4.6.2 rather than assumed. The guard therefore fell open on
## every frame of every real session: one Rect2 per panel, six to ten panels a frame at 60fps, into a
## static array nothing clears. Fixtures set `Hud.probing = true` and `check_hud_layout` asserts that it
## is false by default and that the probes stay empty when it is.
static var probing: bool = false
static var panel_probe: Array[Rect2]

## The hotbar, measured the same way and for the same reason. It reports rectangles. The first version
## reported a count, which was worth nothing: `wells += 1` sat unconditionally inside `for k in n`, so
## the count could only ever equal `n`, itself `clampi(carried, 1, INVENTORY_SLOTS)`. That is arithmetic.
##
## Geometry can disagree. Had `sx` been derived from the pack index rather than the window slot, the
## wells would have marched off the end of their own backing and off the canvas without moving any
## count. The keys: `carried` is the item types held; `wells` every drawn slot rect in draw order; `sel`
## the active index; `sel_lit` whether any drawn well lit up as the selection; `window` the pack index
## the first well shows; `backing` the framed rect; `label` the selected item's name plate or a zero
## Rect2 when none was drawn. The bar's early returns leave it untouched so an empty probe under
## `probing` means the bar did not draw.
static var hotbar_probe: Dictionary


## A framed, lightly bevelled panel backing: the shared skin for every HUD widget. A faint lit top edge
## makes it read as raised rather than as a flat sticker. `alpha` modulates the whole skin so a panel
## can fade rather than blink out. Panels that fade fully are expected to return before calling this at
## all, so the probe records only what was really drawn.
##
## A panel does not wear the selection colour. This used to take an `accent` flag that drew a 2px
## `UI_ACCENT` rule across the top. Eight surfaces asked for it: PAUSED, the title's choices card, the
## fast-forward chip, the objective line, the dashboard, the help page, settings and the hotbar backing.
## A mark that appears on eight things marks nothing. What made panels read as raised was never the gold
## anyway. It is `UI_EDGE_HI`, the one-pixel bevel along the top.
##
## The parameter is removed rather than defaulted to false. A flag with no caller is a switch waiting to
## be flipped back by someone reading it as an available option.
func _panel(rect: Rect2, alpha: float = 1.0) -> void:
	if probing:
		panel_probe.append(rect)
	draw_rect(rect, Color(UI_BG, UI_BG.a * alpha))
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0),
		Color(UI_EDGE_HI, UI_EDGE_HI.a * alpha), 1.0)
	draw_rect(rect, Color(UI_EDGE, UI_EDGE.a * alpha), false, 1.0)


## The machine inspector, top-right under FORGED, shown when you aim at one of your machines in reach.
## It names the machine and shows its recipe as item chips, inputs to outputs, or its routing mode, plus
## what it is holding. Machines with a knob also draw clickable rows such as the splitter's three ratio
## chips or a filtered hopper's [clear] chip, and machines with a fill draw a real bar. MainView pins
## the hover while the cursor crosses onto this panel so the knobs are reachable. Clicks land through
## `hover_click()` because every mutation stays a discrete sim call out there.
func _draw_hover() -> void:
	_knob_hits.clear()
	_hover_rect = Rect2()
	# Called every frame rather than from inside the not-modal branch, because those two clears are frame
	# hygiene. Skip the call and the knob hit-boxes and the panel rect survive into a frame that never drew
	# them, so a click lands on a control no longer on screen. The call stays and the drawing leaves
	# instead, since `main.gd` recomputes `hover_info` off the world aim whichever menu is up.
	if _modal_open():
		return
	if hover_info.is_empty():
		return
	# The big map is the screen, the third element to take this rule after the goal plate and the pack bar.
	# It stands down before the rect is built so `_hover_rect` stays empty and `_cursor_on_hover_panel()`
	# reports false; otherwise the config-panel pin in MainView's frame sync would latch a machine nobody
	# can see.
	#
	# A modal earns the same stand-down, and it has to happen here rather than at the call site. The rect
	# is a click region, so a skipped call leaves the last one behind and a click on the counter lands on
	# an invisible knob. You also cannot aim at a machine while a plate covers the world.
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
	# The panel takes the width of its widest line. It is anchored to the right edge of the canvas, so a
	# line overflowing a fixed 218px ran off the screen: "too hard for your pick, craft a Stone Pickaxe",
	# the most important sentence the inspector says, came out as "craft a Stone Pick". It is capped now,
	# and anything past the cap is ellipsized rather than lost off the edge.
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
	# This sits below whatever occupies the top-right column: the corner minimap if it is shown, otherwise
	# the FORGED chip. Centred does not mean narrow. At 128x128 the large map spans x 181..459 while this
	# panel is right-anchored with a `HOVER_MIN_W` floor, so its left edge is at most 640 - 218 - 12 = 410,
	# and the measured overlap was 49x50, reachable in ordinary play. `_draw_hover` returns early under the
	# large map so the `else 34.0` fallback below only runs for the corner form.
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


## The inspector's on-canvas rect this frame, where Rect2() means not shown. MainView uses it to pin the
## hover while the cursor travels onto the panel, under the same "the open map is UI" rule.
func hover_panel_rect() -> Rect2:
	return _hover_rect


## The knob payload under a canvas point, or {} for none. MainView reads it on LMB; the HUD never
## touches the sim, and the controller turns the payload into a discrete sim call.
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


## Where the minimap sits right now, in canvas space: corner and small, or large and centred. It is
## public so MainView can route map clicks to the ping and keep world verbs off the map.
##
## Both forms fit the world's aspect inside a box rather than deriving one side from the other. A corner
## map sized by width alone was fine while the world was 96x80 and became a 150x150 slab down half the
## screen the moment it went square. A corner element has a height budget as much as a width one.
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


## The minimap, on M for the corner form and M again for the large one. It is a cached image of the
## whole world: solid cells in their material colour; carved cells as a dim wall backing; open sky as
## void. Over that go live overlays for the depth bands, your machines, Bazaar diamonds, a pulsing
## breach marker on every opened way down, your ping, the visible window and you. The terrain image
## rebuilds only when you dig so the per-frame cost is one textured blit.
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
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)   # cosmetic clock, HUD only
	# --- depth bands: the layer ladder made legible at a glance ---
	var seal_y: float = origin.y + float(LayeredWorldGen.SEAL_TOP) * scale.y
	var seal_h: float = maxf(float(LayeredWorldGen.SEAL_ROWS) * scale.y, 1.5)
	draw_rect(Rect2(origin.x, seal_y + seal_h, frame.size.x, frame.end.y - (seal_y + seal_h)),
		Color(0.35, 0.50, 0.95, 0.10))                                  # Stonereach: a cold wash
	draw_rect(Rect2(origin.x, seal_y, frame.size.x, seal_h), Color(0.62, 0.42, 0.85, 0.55))  # the seal
	# The descent chart. Every band Strata knows about gets a hairline at its ceiling and its own name in
	# its own colour, so the map answers "how far down does this go and what is between here and there" at
	# a glance. It used to name TOPSOIL and STONEREACH only, and put the first of them immediately above
	# the seal, which is deepslate, sixty rows from any topsoil.
	if minimap_large:
		for i: int in range(1, Strata.BANDS.size()):     # skip OPEN SKY: it has no ceiling to draw
			var band: Dictionary = Strata.BANDS[i]
			var by: float = origin.y + float(int(band["from"])) * scale.y
			if by < origin.y or by > frame.end.y - 6.0:
				continue
			var tint: Color = band["color"]
			draw_line(Vector2(origin.x, by), Vector2(frame.end.x, by), Color(tint, 0.30), 1.0)
			# A thin band, and the seal is two rows, would stack its name on the one below it. Every band keeps
			# its line, and the one that loses its text is the shallower of a colliding pair, because the deeper
			# name tells you what you are about to be in.
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
	# --- aquifers: the flooded pockets that guard rich ore, in a cool cyan-blue clear of the amber power
	# wash, the gold bazaars and the violet seal, with alpha scaling by fill so deep water reads solid and
	# a puddle reads faint. It is a live overlay, since water flows each tick rather than in the bake.
	var wcell: Vector2 = Vector2(maxf(scale.x, 1.0), maxf(scale.y, 1.0)).ceil()
	for water_cell_v: Variant in sim.water:
		var water_cell: Vector2i = water_cell_v
		var fill: float = clampf(float(sim.water[water_cell]) / float(FactorySim.WATER_MAX), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(water_cell) * scale, wcell),
			Color(0.25, 0.62, 0.95, 0.30 + 0.45 * fill))
	# --- frontier reach: where the factory's power and placed light actually extend. Power is a warm amber
	# wash per powered cell, brighter for more units and read off the derived `sim.power` field, and placed
	# torches are small warm halos. The alphas stay subtle so terrain reads under the claim.
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


## A small filled diamond, the minimap's icon shape, which reads at 3-5px where a square blurs into rock.
func _map_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)


## Rebuild the cached terrain image at one pixel per cell: solid takes the material colour, dug-but-
## walled takes a dim wall backing, and open sky is void. Cheap, and it runs only when terrain changes.
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


## The Bazaar's geometry: one shape computed in one place and read by both the drawing and the layout
## check, so what is seen is what is tested. Nothing here depends on where you are standing. A panel
## that changes shape depending on where you are is a panel you cannot learn.
##
## What it does depend on is what the open tab holds: `h` through `_bazaar_wanted_h` and the plate
## through `_detail_wanted_h`. Both are read here rather than recomputed, so the content box is bought
## out of the same number the plate is drawn at. The plate's depth is a property of the selection, but
## the kinds a selection can have partition by tab, so it stays constant while a tab is open. That is
## what keeps a cursor move from reflowing the rows it walks through, and `_hold_overflow_h` asks the
## whole pack for its deepest sentence for the same reason.
##
## The shape is a rail, a head, a grid of rows and a detail plate across the bottom. Rows are for
## choosing between and the plate is for wanting. Splitting those two jobs is what let the rows get
## denser, because a row no longer has to carry a description.
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


## How tall the counter wants to be, for the tab that is open.
##
## Every term here comes from the function that draws it, never from a second copy of its arithmetic,
## because a height computed from a duplicated layout rule is right on the day it is written and
## silently wrong the day either copy moves. So `_pack_cols` is the single source for the well grid,
## `_works_rows_needed` asks `works_columns` itself, `_bench_tiers` is the tier walk lifted out of
## `_tab_bench` whole, and the plate term is `_detail_wanted_h` rather than the constant it sometimes
## equals.
func _bazaar_wanted_h() -> float:
	if sim == null:
		return BAZAAR_SIZE.y
	var inner_w: float = BAZAAR_SIZE.x - BAZAAR_RAIL - BAZAAR_PAD * 2.0
	var need: float = 0.0
	match bazaar_tab:
		TAB_WORKS:
			need = float(_works_rows_needed()) * BAZAAR_ROW_H
		TAB_BENCH:
			# The tree sizes its own chips down to fit whatever it is given, so what it wants is the tallest tier
			# at full chip height. Today that asks for more than the panel may ever be, so BENCH is clamped and
			# unchanged, which is the correct outcome rather than a coincidence to rely on.
			var tall: int = maxi(1, _bench_tallest())
			need = float(tall) * 64.0 + float(tall - 1) * 6.0
		_:
			# The wells and the summary band under them. The band was missing from this sum while the summary's
			# own guard tested against a content box this sum had already decided, so the two could only agree by
			# accident. `_ledger_h` carries the reasoning.
			need = float(_pack_rows(inner_w)) * PACK_CELL + _ledger_h()
	return clampf(BAZAAR_HEAD + need + BAZAAR_DETAIL_GAP + _detail_wanted_h() + BAZAAR_FOOT,
		BAZAAR_MIN_H, BAZAAR_SIZE.y)


## How tall the plate wants to be for the thing that is selected. Every site positioning against the
## plate reads this number. There is deliberately no second copy: `_bazaar_geometry` buys the content
## box out of it, the panel's asking height adds it, and `_draw_bazaar_detail` takes the art square back
## off the rect it is handed.
##
## The plate expands for a choice. A machine, a Rack row and a rung of the ladder all cost something,
## and the chip row saying whether you can afford it is what the full 88 is for. What is already in your
## pack has no price to weigh and PACK's summary is not a purchase, so both get the compact plate.
##
## It is keyed on the selection rather than on the tab, because the content decides. The kinds partition
## by tab all the same, which is what makes the depth constant while a tab is open.
##
## The compact depth is a floor rather than the answer. `BAZAAR_DETAIL_MIN` pays for two lines of
## sentence and `_hold_overflow_h` is what the pack needs beyond that. A pack whose sentences fit the
## reserve adds nothing, which is how a fresh game still lands exactly on `BAZAAR_MIN_H`.
func _detail_wanted_h() -> float:
	if sim == null:
		return BAZAAR_DETAIL
	match str(bazaar_action().get("kind", "")):
		"machine", "rack", "tech":
			return BAZAAR_DETAIL
		_:
			return BAZAAR_DETAIL_MIN + _hold_overflow_h()


## The width the pack plate's sentence wraps at. Both the height above and the drawing below take it
## from here. It was `box.size.x - 260.0` at the draw and nothing at all at the measure. 260 is the sum
## of nothing on this plate: it stopped the column 70px short of the button it was meant to stop at,
## which is why the longest sentence in the catalogue needed a third line that `DETAIL_BLURB_LINES` was
## then cutting off.
##
## It is measured against the largest square the plate may draw. The square is read back off the plate's
## height, and the height is what this width is being asked for, so a column that narrowed as the plate
## grew would be an input to its own answer. `DETAIL_ART` is the square's ceiling.
##
## It reserves for the button and not for the state. `HELD` is a tick and a word where `HOLD` is a pill
## with a key in it. Sizing the column to whichever form a row carries would rewrap the sentence you are
## reading as a consequence of pressing the key underneath it.
func _hold_text_w() -> float:
	return BAZAAR_SIZE.x - BAZAAR_RAIL - BAZAAR_PAD * 2.0 \
		- (DETAIL_PAD + DETAIL_ART + DETAIL_TEXT_GAP) \
		- _verb_button_w(HOLD_VERB, HOLD_KEY) - DETAIL_TEXT_RIGHT


## How many lines a sentence takes in a column `w` wide, asked of the font that will draw it rather than
## estimated from a character count. The reported height is the line count times the line height, so the
## division is exact. It uses `roundi` rather than `ceili`, because a paragraph coming back a hair over
## a whole number would otherwise reserve a line nobody needs.
func _blurb_lines(text: String, w: float) -> int:
	var block: float = _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w,
		DETAIL_BLURB_SIZE).y
	return maxi(1, roundi(block / _font.get_height(DETAIL_BLURB_SIZE)))


## Measured once per item and kept. The sentences are `const`, the column derives from constants and the
## font, and neither moves while the game is running, so there is nothing for this to go stale against.
## The alternative is re-shaping every carried sentence on every frame the pack is open.
var _blurb_lines_memo: Dictionary = {}


## How much deeper than its floor the compact plate has to be, for the pack that is open. It is zero for
## a pack whose sentences all fit the two lines `BAZAAR_DETAIL_MIN` pays for, which is every pack the
## catalogue can make today. The point is the day one does not. The plate grows a line instead of eating
## the end of the sentence, which the hold plate used to do by handing `DETAIL_BLURB_LINES` to
## `draw_multiline_string` as a cap.
##
## It is asked of the whole pack and not of the selected row, because the plate's depth has to stay
## constant while the tab is open. An empty pack asks for nothing, which keeps a fresh game on the floor.
##
## Only PACK can ask. The compact plate is also what a WORKS or BENCH tab with no selection falls back
## to, and `_detail_pack` has no sentence on it. Sizing it against a pack it is not showing would
## reserve depth for text on another tab.
##
## Growth is in the font's own line height while the floor is in the written one. See `DETAIL_LINE`.
func _hold_overflow_h() -> float:
	if bazaar_tab != TAB_PACK:
		return 0.0
	var w: float = _hold_text_w()
	var over: int = 0
	for slot: Dictionary in sim.inventory_slots():
		var id: StringName = slot["item"]
		if not _blurb_lines_memo.has(id):
			_blurb_lines_memo[id] = _blurb_lines(str(ITEM_PURPOSE.get(id, "—")), w)
		over = maxi(over, int(_blurb_lines_memo[id]) - DETAIL_BLURB_LINES)
	# There is no floor on `over`: it opens at zero and `maxi` only ever raises it, so a clamp would be a
	# guard that cannot fire.
	return float(over) * _font.get_height(DETAIL_BLURB_SIZE)


## How many wells fit across the content and how many rows they take. `_tab_pack` calls the first of
## these rather than keeping its own copy of the division.
func _pack_cols(w: float) -> int:
	return maxi(1, int(w / PACK_CELL))


func _pack_rows(w: float) -> int:
	var n: int = sim.inventory_slots().size()
	return maxi(1, ceili(float(n) / float(_pack_cols(w))))


## The fewest rows at which the two WORKS lists fit the counter's columns, asked of `works_columns`
## itself so the squeeze rule and this measure cannot disagree. Fresh, machines 4 and rack 6 fit in
## three columns at four rows. With the full tech tree, machines 19 and rack 7, it wants ten rows, which
## asks for more height than the counter has and is clamped.
func _works_rows_needed() -> int:
	for r: int in range(1, 25):
		if int(works_demand(r)["total"]) <= BAZAAR_COLS:
			return r
	return 24


## The research tree, grouped by how many prerequisites deep each tech is. It is lifted out of
## `_tab_bench` so the drawing and the sizing read the same tiers.
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
		if lock == &"" or sim.is_researched(lock):
			out.append(i)
	return out


func open_machines() -> Array[int]:
	return _unlocked(craft_ids, craft_options.size())


func open_rack() -> Array[int]:
	return _unlocked(rack_ids, rack_options.size())


## How many columns each WORKS group takes, at this row height. Groups are laid left to right and never
## share a column, because the left list is what you build from your own materials and the right is what
## you buy with refined goods, and a player should not have to work that out from a row's position.
func works_columns(rows: int) -> Dictionary:
	var want: Dictionary = works_demand(rows)
	var m: int = int(want["machines"])
	var r: int = int(want["rack"])
	# The counter has a fixed number of columns, so two lists asking for more than it has get squeezed
	# rather than allowed to run off the panel's edge, and the group that overflows falls back to a window
	# around the cursor. This clamp is the failure mode made legible rather than the intended layout, and
	# it is the late-game normal rather than a safety valve. Measured on the real scene:
	#
	#   FRESH      machines= 4 rack= 6   ask 1+1=2 of 3   no squeeze
	#   FULL TECH  machines=19 rack= 7   ask 3+1=4 of 3   squeezed, granted 2+1
	#
	# The squeeze is kept because the alternative measured worse: a fourth column is 124.5px, and
	# `_works_row` would give the name about 48px, truncating every machine. Three columns and a cursor
	# window is the design, and `works_window_first` is what makes the window testable.
	if m + r > BAZAAR_COLS:
		r = clampi(r, 1, BAZAAR_COLS - 1)
		m = BAZAAR_COLS - r
	return {"machines": m, "rack": r, "total": m + r}


## What the two lists ask for at a given row count, before the squeeze. The split exists because a
## caller that needs the demand and gets the grant reads a constant. `works_columns` clamps its answer
## to `BAZAAR_COLS`, so its total is never above three whatever the catalogue does, and
## `_works_rows_needed` scanning for the first row count whose total fits got three at one row and sized
## the counter for a single row of WORKS.
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


## What Enter would do, as {kind, id}, where kind is "machine", "rack", "tech" or "". The panel owns the
## cursor because the panel draws it, and MainView owns the verbs, so the highlighted row and the thing
## that happens cannot drift apart.
func bazaar_action() -> Dictionary:
	var i: int = bazaar_row
	match bazaar_tab:
		TAB_WORKS:
			if i < 0 or i >= bazaar_row_count():
				return {}
			# The cursor walks the open rows, while `row` indexes the full catalogue, because that is what
			# MainView's verbs are keyed on. Filtering the view must never renumber the world.
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
			# PACK's verb is HOLD. It was the one tab with a cursor and nothing to do with it, and holding a
			# thing from the pack screen is what the stateless bit-equipping in `BitRules` wants: what is in your
			# hand is what you dig with.
			var slots: Array[Dictionary] = sim.inventory_slots()
			if i < 0 or i >= slots.size():
				return {}
			return {"kind": "hold", "id": slots[i]["item"], "row": i}


## Move the cursor. `dy` steps a row, while `dx` jumps a whole column, which is the same motion your eye
## makes and carries you across the counter-to-Rack gap in one keystroke rather than ten.
func bazaar_move(dx: int, dy: int) -> void:
	var n: int = bazaar_row_count()
	if n <= 0:
		return
	if dx != 0:
		bazaar_row = clampi(bazaar_row + dx * int(_bazaar_geometry()["rows"]), 0, n - 1)
	bazaar_row = clampi(bazaar_row + dy, 0, n - 1)


## Change tab, keeping each tab's place in its own list. Re-picking the tab you are already on means
## "back to the top", which is the only way left to send the cursor home now that leaving and returning
## no longer does it.
func set_bazaar_tab(tab: int) -> void:
	var want: int = clampi(tab, TAB_PACK, TAB_BENCH)
	# Sized from the tab list itself on first use, so a fourth tab needs no change here and cannot index
	# past the end of the store. `resize` fills the new slots with zero, which is row one.
	if _bazaar_rows.size() < TAB_NAMES.size():
		_bazaar_rows.resize(TAB_NAMES.size())
	if want == bazaar_tab:
		bazaar_row = 0
		_bazaar_rows[want] = 0
		return
	_bazaar_rows[bazaar_tab] = bazaar_row
	bazaar_tab = want
	# A list can shrink under a stored index while you are away from it: spend the last of a material and
	# its well leaves the pack, or build a machine and the rack row goes. So the stored row is re-clamped
	# against the count the tab has now. `bazaar_row_count()` reads the sim on two of the three tabs, so a
	# HUD without one keeps the old behaviour of landing at the top rather than reaching through a null.
	var n: int = bazaar_row_count() if sim != null else 0
	bazaar_row = clampi(_bazaar_rows[want], 0, maxi(n - 1, 0))
	_bazaar_rows[want] = bazaar_row


## The counter, drawn as a lamp-lit object rather than as a dialog box: elevation instead of a border, a
## gradient instead of a fill, one accent doing one job, and a 0.13s rise on open.
func _draw_inventory_overlay() -> void:
	# Dimmed, not blacked. You are at a counter with a shopkeeper beside you and banners overhead, which
	# `scenes/bazaars.gd` stages block by block, so the world stays legible behind the panel instead of
	# being switched off. MainView blurs it in the same breath, which is what makes the panel read as
	# being in front of something.
	var t: float = _bazaar_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var panel := Rect2(origin, Vector2(g["w"], g["h"]))
	# The whole counter rises the last few pixels into place. One transform, so nothing below has to know.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)

	_soft_shadow(panel, 12, 0.34)
	_round_rect(panel, 8.0, UI_MODAL)
	_panel_sheen(panel)
	# The rail is the tab strip turned on its side and given room to be an object, since three icons you
	# can hit with a glance beat three words you have to read.
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


## What a cap is made of, named rather than written inline. Caps are placed by callers that own a
## baseline and not a box, and a caller working those numbers out for itself is a second copy that stops
## agreeing the day the cap changes size.
const KEYCAP_PAD_X: float = 8.0       ## ink to either edge
const KEYCAP_MIN_W: float = 14.0      ## a single digit still wants a square-ish cap
const KEYCAP_PAD_Y: float = 7.0       ## how much taller than its type the cap stands
const KEYCAP_BASE: float = 5.0        ## the key's baseline, up from the cap's floor
const KEYCAP_DROP: float = 1.0        ## and the shadow, one under the cap: the slot's last mark


func _keycap_w(key: String, fs: int) -> float:
	return maxf(_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + KEYCAP_PAD_X,
		KEYCAP_MIN_W)


func _keycap_h(fs: int) -> float:
	return float(fs) + KEYCAP_PAD_Y


## One key, drawn as a key. A bare digit in the corner of a tile reads as a step number, which is what
## makes a three-tab counter feel like a three-page wizard, while the same digit inside a raised cap
## reads as something to press. It returns the width it consumed, so a row of them lays out once.
func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	var tw: float = _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w: float = _keycap_w(key, fs)
	var h: float = _keycap_h(fs)
	var box := Rect2(at, Vector2(w, h))
	_round_rect(Rect2(box.position + Vector2(0.0, KEYCAP_DROP), box.size), 3.0,
		Color(0.0, 0.0, 0.0, 0.35))
	_round_rect(box, 3.0, Color(0.13, 0.145, 0.18))
	draw_string(_font, at + Vector2((w - tw) * 0.5, h - KEYCAP_BASE), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.74, 0.78, 0.86))
	return w


## The rail: three tabs as glyphs, the live one lit and carrying a brass edge. The key that selects a
## tab rides on the word as a cap because a key legend nobody can find is a key nobody presses.
##
## The cap sits on the word's baseline and may not hang below it. Hung below it sat at `y + 51` and
## stands 14 tall, so a slot ran to `y + 65` while `_rail_slots` caps the pitch at 58, and every cap
## landed 7px inside the footprint of the tile beneath it at every height the counter can take. No pitch
## fixes that, which is worth stating because it is where a fix wants to go first: clearing a cap that
## ends at `y + 65` needs a pitch of at least 65 and three slots on the shortest page, 190, leave room
## for 45. On the word's baseline a slot ends at `y + 54`, where three fit any page this panel has.
func _draw_bazaar_rail(origin: Vector2, g: Dictionary) -> void:
	var rail := Rect2(origin, Vector2(BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, UI_RAIL)
	# The rail's pitch follows the panel, and the arithmetic that makes it follow lives in `_rail_slots`,
	# shared with the settings rail. At full height these are the numbers they always were, top 62, and on
	# a short counter the slots close up to their floor rather than into each other.
	var ys: Array = _rail_slots(rail, 3, _rail_key_slot_h() + RAIL_SLOT_AIR, _rail_key_slot_h())
	for i: int in 3:
		var y: float = ys[i]
		var on: bool = i == bazaar_tab
		var box := Rect2(rail.position.x + 9.0, y, RAIL_ICON, RAIL_ICON)
		if on:
			_round_rect(box, 6.0, RAIL_ON_FILL)
			draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UI_ACCENT)
		_rail_glyph(box.get_center(), i, on)
		# The cap and the word are one thing, laid out and centred as one. The key belongs to the name it
		# selects, and a cap centred on the tile with a word centred under it are two objects that only look
		# related at the width they happen to have today.
		var key: String = str(i + 1)
		var label: String = TAB_NAMES[i]
		var kw: float = _keycap_w(key, RAIL_LABEL_FS)
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, RAIL_LABEL_FS).x
		var lx: float = box.get_center().x - (kw + RAIL_KEY_GAP + lw) * 0.5
		_keycap(Vector2(lx, y + _rail_key_dy()), key, RAIL_LABEL_FS)
		draw_string(_font, Vector2(lx + kw + RAIL_KEY_GAP, y + _rail_word_dy()), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, RAIL_LABEL_FS, UI_TEXT if on else UI_TEXT_FAINT)


## The three tab glyphs, drawn rather than lettered: a satchel, a gear, a ladder of rungs.
func _rail_glyph(at: Vector2, kind: int, on: bool) -> void:
	var col: Color = GOLD_PALE if on else Color(0.40, 0.43, 0.50)
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


## The materials the open tab is pricing in, in the order that tab lists them. It is empty for a tab
## that prices nothing.
##
## The head strip used to be a literal six written into the drawing function. Against the prices it is
## read next to it was wrong in both directions. `ore` is the cost of nothing the counter sells: no
## `craft_cost` in `src/data/machines/*.tres` names it, no rung in `src/data/research_rules.gd` does,
## and neither does a tool or bit recipe. Three materials that are costs could never appear at all:
## `plate` and `gear` (research_rules.gd:69, 81 and 96, plus the craft costs of the Crusher, Blast
## Furnace, Drift Rig and Borer) and `iron` (iron_forge.tres:14).
##
## Reading the costs also answers where the strip belongs. It is a global account of the pack but is
## only ever read against a price, so it lives on the tabs that quote prices. PACK returns nothing here.
## Every chip it drew duplicated a well two rows underneath it.
##
## BENCH walks the whole ladder rather than the reachable rungs, because the tree draws the whole
## ladder. A tech's sample material is a real cost and is deliberately not in here. It is not in the
## rung's `cost` dictionary either, and `_shortfall_note` is the one place that names it.
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


## The head: who you are talking to, which counter you are at, and what you are carrying of what this
## tab charges, as chips you can count without reading.
func _draw_bazaar_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	_tracked("BAZAAR", Vector2(x, origin.y + 29.0), 17, 2.8, UI_TEXT)
	var tab_x: float = x + _tracked_w("BAZAAR", 17, 2.8) + 16.0
	_tracked(TAB_NAMES[bazaar_tab], Vector2(tab_x, origin.y + 29.0), 17, 2.8, UI_TEXT_FAINT)
	# The strip stops one panel pad short of the title's last stroke, measured off the title rather than
	# guessed at. It was `x + 170.0`, a statement about the widths of "BAZAAR" and the longest tab name at
	# 17pt with 2.8 of tracking, with nothing in the file relating it to either.
	var floor_x: float = tab_x + _tracked_w(TAB_NAMES[bazaar_tab], 17, 2.8) + BAZAAR_PAD
	var rx: float = origin.x + float(g["w"]) - BAZAAR_PAD
	# A material priced but not held draws no chip. The shortfall for the thing under the cursor is
	# answered per ingredient on the detail plate instead, and a strip of zeroes for everything the ladder
	# will ever charge would be a wall of what you do not have, on the tab where you choose what next.
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


## The footer is one line: the keys. What you are carrying moved to the head as chips, and where the
## verbs live moved onto the verb button, where it answers the question you are actually asking.
func _draw_bazaar_foot(origin: Vector2, g: Dictionary) -> void:
	# One input grammar, and it is the rail's. This was a single run-on string using double spaces as
	# structure, which reads as prose and gets skipped like prose: keys and verbs sat at the same weight,
	# so nothing said which half was the thing to press. Each key is a cap now, with its verb beside it at
	# the old dim weight so the eye lands on the key.
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	var y: float = origin.y + float(g["h"]) - 15.0
	for pair: Array in [["up/dn", "pick"], ["1-3", "tab"], ["E", "close"]]:
		x += _keycap(Vector2(x, y), str(pair[0]), 8) + 5.0
		var label: String = str(pair[1])
		draw_string(_font, Vector2(x, y + 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_FAINT)
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0


# --- the tabs -------------------------------------------------------------------------------------------

## PACK: the whole carried inventory as a grid of wells, given the whole width. It is the same pack it
## always was, and it simply stopped sharing a 360px column with two other screens.
func _tab_pack(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var slots: Array[Dictionary] = sim.inventory_slots()
	var cell: float = PACK_CELL
	var cols: int = _pack_cols(content.size.x)
	# The wells are served first and the summary gets what is left. `_bazaar_wanted_h` asks for both, so
	# below the panel's height cap this subtraction takes nothing the grid needed, and above the cap the
	# band gives way, because the grid is the tab's subject and the summary is a footnote on it.
	#
	# It uses `maxi(1, ...)` rather than the slot count, so an empty pack reserves the one row `_pack_rows`
	# charged the panel for and the band lands where the height was bought. An empty pack with a running
	# factory is a real state: it is what standing at the counter having just fed everything in looks like,
	# and it is the state `_detail_pack` exists for.
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
		# screen is opened to answer, and the hotbar is behind the panel while it is open.
		#
		# It is a state rather than the cursor, which is why it is no longer in the cursor's colour. The
		# held well is usually not the picked well, so the grid was carrying two golds a row apart saying
		# two different things, the doubling the gold rule exists to stop. `_state_plate` has always drawn
		# this exact word in `STATE_INK` a couple of hundred pixels to the right, and green is already
		# this file's colour for a fact that is true of you rather than an offer: the researched tech's
		# name, the finished lamp. One word, one colour, on one screen. The well's wash goes from 12.22:1
		# to 7.20:1 and the picked row's brass from 10.29:1 to 6.06:1, both clear of the 4.5 floor.
		if i == held:
			draw_string(_font, box.position + Vector2(5.0, 12.0), "HELD",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, STATE_INK)
	_pack_ledger(Rect2(wells.position.x, wells.end.y, content.size.x, band))


## How tall the summary under the wells is and 0.0 when it has nothing to say. `_bazaar_wanted_h` adds
## this to what PACK asks for and `_tab_pack` takes the same number back off the bottom of the grid. The
## band the summary draws into and the height the panel was sized to are therefore one piece of
## arithmetic run twice rather than two numbers that have to agree.
##
## They were two numbers and they did not agree. The summary tested `top > content.end.y - 30.0`, which
## needs `content.size.y >= rows*46 + 44`, while PACK's asking height had no term for the summary in it
## and `content` came out at exactly `rows*46`. Across 1 to 6 rows of wells the guard's two sides read
## 185/141, 208/164, 231/187, 254/210, 298/212 and 344/212. The summary has therefore only ever reached
## the screen on frames where `_bazaar_h` was still easing down from a taller tab.
##
## Four rows, because the band is bought out of the grid above it. At four the band is
## 14 + 12 + 3*17 + 7 = 84px, which a one-row and a two-row pack both fit under the 348 cap.
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
## consuming, derived from the measured output rates and nothing else. A forge measured at 2.2 ingot/min
## has, by smelt_ingot's 2 ore for 1 ingot, consumed exactly 4.4 ore/min. The ratio is the recipe's and
## the rate is the sim's, so there is no capacity model here and nothing to calibrate.
##
## It returns {"draw": item -> per minute, "eater": item -> the machine's display name, or "" when more
## than one type is eating it, "mute": item -> true for the ones this cannot speak about}.
##
## The mute set is the point. Two placed machine types can output the same good. A measured ingot rate
## cannot be split between a Forge turning 2 ore into 1 and a Blast Furnace turning 1 rich_ore into 2.
## Attributing the whole rate to either invents the other's throughput, so every input of every
## candidate recipe goes mute instead. That is a different state from an item nothing consumes, which
## reports a real zero.
##
## Machines running their own tick carry no recipe inputs to add up here. A drill's mine_ore has none,
## and the descent engine eats ingots through DESCENT_EATS with no recipe at all. So the clause says "to
## the Forge" rather than "consumed", which is true whatever else is also eating.
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
			# Two machine types can share one ingredient, since the Gear Mill and the Plate Press both eat iron
			# ingots, and the total stays right while the name stops being. Naming neither beats naming whichever
			# the census happened to yield last.
			eater[item] = who if not eater.has(item) or str(eater[item]) == who else ""
	return {"draw": taken, "eater": eater, "mute": mute}


## Under the grid: what the factory is making for you, and what the rest of the line does with it.
##
## The bar is not a magnitude. Drawn as a share of the fastest number on the panel, a trickle of a
## refined good and a flood of a common raw look like the same kind of fact at two lengths, and the
## length moves when an unrelated row moves. It is the share of that item's own income the line is
## taking back, a 0..1 quantity meaning the same thing on every row. The /min number beside it keeps the
## magnitude. Rows split into two kinds out of the data rather than out of a rule: an item the line
## consumes gets a bar and a clause naming what eats it, and anything unattributable gets neither.
##
## The verdict on the header's line is the decision the rows only imply. It is chosen over the items the
## line actually consumes, so it is always about a live flow rather than the earth and stone a
## hand-mining player's rate list is full of. A deficit outranks a surplus. A step drawing more than its
## feed earns will stall, and a pile that is growing can wait.
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
	# A heading is a label, and gold does not label. See `GOLD_DIM`, where the type-weight argument that
	# put this in gold is taken apart. `UI_TEXT_DIM` is the grey ramp's subordinate rung and reads brighter
	# here than the gold rung did (6.15:1 against 5.40), while staying a step under the `UI_TEXT` verdict
	# printed beside it, which is the order the two lines are supposed to be read in.
	_tracked(head, Vector2(band.position.x + 1.0, hb), 8, 2.0, UI_TEXT_DIM)
	var vx: float = band.position.x + 1.0 + _tracked_w(head, 8, 2.0) + 12.0
	var verdict: String = _ledger_verdict(rates, off)
	if verdict != "" and band.end.x > vx:
		draw_string(_font, Vector2(vx, hb), verdict, HORIZONTAL_ALIGNMENT_RIGHT, band.end.x - vx, 9,
			UI_TEXT)
	# The columns are the glyph, the name, the rate right-aligned against the bar's left edge, the bar and
	# the clause. The bar is 120 rather than the old `min(240, width/2)`, because a share does not need
	# half the panel to be read and the clause beside it does need the room: 246px of the 528.
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
		# this way, and gold on this screen means selected, affordable and the live verb, which is not what a
		# share of an income is.
		_round_rect(Rect2(bar_x, y - 3.0, maxf(3.0, bar_w * clampf(took / rate, 0.0, 1.0)), 10.0), 3.0,
			Color(Visuals.item_color(item), 0.62))
		var who: String = str(eater.get(item, ""))
		var clause: String = "%.1f/min back into the line" % took
		if who != "":
			clause = "%.1f/min to the %s" % [took, who]
		draw_string(_font, Vector2(bar_x + bar_w + 8.0, y + 7.0), clause,
			HORIZONTAL_ALIGNMENT_LEFT, band.end.x - bar_x - bar_w - 8.0, 9, UI_TEXT_DIM)


## The one line of the summary that asks for a decision instead of reporting a number. It is empty when
## the offtake has nothing it can speak about, which is the same silence the rows keep in that state.
func _ledger_verdict(rates: Array[Dictionary], off: Dictionary) -> String:
	var taken: Dictionary = off["draw"]
	var mute: Dictionary = off["mute"]
	# Empty because nothing refines anything, and empty because everything that does is unattributable, are
	# two different states, and only the first is a fact about the factory. Measured: place a Forge and a
	# Blast Furnace together and the offtake goes to {} with ore and rich_ore muted, which reads as
	# "nothing on the line refines any of it yet" while two machines are refining it.
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


## WORKS: the counter, what you build from your own materials, and the Rack, what you buy with refined
## goods, as a dense card grid. No scrolling, no scrollbar, no shift-digit.
func _tab_works(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var rows: int = int(g["rows"])
	var lay: Dictionary = works_columns(rows)
	# The columns spread to fill the counter. Once WORKS lists only what you can build, most of the game is
	# two columns rather than three, and three columns of narrow rows with an empty third is exactly the
	# dead space this layout exists to kill. It is capped, because a row wide enough to lose its price at
	# the far end is its own problem.
	var used: int = maxi(1, int(lay["total"]))
	var col_w: float = minf(268.0,
		(content.size.x - BAZAAR_GUTTER * float(used - 1)) / float(used))
	var open_m: Array[int] = open_machines()
	var open_r: Array[int] = open_rack()
	_works_group(content, 0, int(lay["machines"]), col_w, rows, "MACHINES", craft_options, open_m, 0, true)
	_works_group(content, int(lay["machines"]), int(lay["rack"]), col_w, rows, "THE RACK",
		rack_options, open_r, open_m.size(), false)
	# ...and one quiet line saying the rest exists and where it lives. Hiding the locked half is only
	# honest if the panel still says there is one, because otherwise the counter looks finished at four
	# machines and the tech ladder looks optional.
	var hidden: int = (craft_options.size() - open_m.size()) + (rack_options.size() - open_r.size())
	if hidden > 0:
		# The key is a cap and not a word in a sentence. "press 3 for the BENCH" asks the reader to parse an
		# instruction to find the one glyph that matters, while the cap grammar the rail and footer already
		# use puts it where the eye lands.
		#
		# The line is a pointer rather than an offer: the thing your input reaches is the cap, and the cap
		# draws itself. Off the gold with the headings, for the reason written at `GOLD_DIM`.
		var dim: Color = UI_TEXT_DIM
		var y: float = content.end.y - 2.0
		var head: String = "%d more wait behind research" % hidden
		draw_string(_font, Vector2(content.position.x + 1.0, y), head,
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x, 9, dim)
		var x: float = content.position.x + 1.0 \
			+ _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
		x += _keycap(Vector2(x, y - 10.0), "3", 8) + 5.0
		draw_string(_font, Vector2(x, y), "BENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)


## The window's first row. A group shorter than its columns starts at 0 and this is a no-op, while a
## longer one shows `capacity` rows centred on the cursor, clamped so it never runs past either end.
##
## Three columns and a window is the right answer rather than a fourth column: 528px of content over
## four columns is 124.5px a row, and `_works_row` gives the name `width - 36 - cost glyphs`, about 48px
## at size 10, which truncates every machine name. Measured before choosing.
static func works_window_first(count: int, capacity: int, base: int, cursor: int) -> int:
	if count <= capacity:
		return 0
	return clampi(cursor - base - capacity / 2, 0, count - capacity)


## One group: a list poured down as many columns as it needs, left to right. `base` is where the group
## starts in the panel's flat cursor index, so the highlight and `bazaar_action()` cannot disagree.
func _works_group(content: Rect2, col0: int, cols: int, col_w: float, rows: int, title: String,
		opts: Array[Dictionary], open_rows: Array[int], base: int, machines: bool) -> void:
	var x0: float = content.position.x + float(col0) * (col_w + BAZAAR_GUTTER)
	# MACHINES / THE RACK are labels, in the grey ramp for the reason written at `GOLD_DIM`. This is the
	# site where the gold rung was doing the most damage: a dimmed cut of the affordance colour, standing
	# directly over rows where dim genuinely means you cannot afford the thing.
	_tracked(title, Vector2(x0 + 1.0, content.position.y - 6.0), 8, 2.0, UI_TEXT_DIM)
	if open_rows.is_empty():
		draw_string(_font, Vector2(x0 + 1.0, content.position.y + 16.0), "(nothing unlocked yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
		return
	# A group longer than its columns shows a window around the cursor rather than truncating. It is lifted
	# out of this loop so `check_pack_layout` can assert a property of what the drawing computes, that the
	# cursor is always inside the window, instead of re-deriving the arithmetic and agreeing with itself.
	# It also runs headless, which `_works_group` cannot, since that only executes inside `_draw`.
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


## The ink for a short row with the cursor on it. Affordability and the cursor are orthogonal, so there
## are four combinations and not three. The name colour read `(gold if selected else UI_TEXT) if afford
## else grey`, with the test on `afford` outermost, so it swallowed the test on `selected` whole. A
## short row drew the same grey whether or not the cursor was on it while `if selected:` still lifted
## the plate and hung a gold spine off its left edge. That put the row being read at 3.74:1 against its
## own plate.
##
## The unselected short row moved off its own literal at the same time. `Color(0.48, 0.50, 0.56)` read
## 4.44:1 on the plain row fill, under the 4.5 this repository holds named inks to. The faint rung reads
## 5.05:1 and sits 74 steps below `UI_TEXT`, so the row still says "you cannot afford this" at a glance.
##
## The lift is the ramp's own step. `UI_TEXT_DIM` is `UI_TEXT_FAINT` plus exactly 0.04 on every channel,
## so one more of that unit lands the selected short row at 5.51:1 against the 5.05:1 it reads
## unselected. `UI_TEXT_DIM` itself measured 4.86:1: over the floor but under the unselected figure,
## which is the same inversion in miniature. It is written as the gap between the two named rungs rather
## than as `0.04`, which would be a literal equal to a difference nothing in the file relates it to.
##
## Ratios are WCAG relative luminance with channels linearised before weighing, per
## `tools/check_text_contrast.gd`. They are not the gamma-encoded Y709 quoted beside them for the plates.
const SHORT_SELECTED := Color(
	UI_TEXT_DIM.r + (UI_TEXT_DIM.r - UI_TEXT_FAINT.r),
	UI_TEXT_DIM.g + (UI_TEXT_DIM.g - UI_TEXT_FAINT.g),
	UI_TEXT_DIM.b + (UI_TEXT_DIM.b - UI_TEXT_FAINT.b))
## One row, drawn as a card and not as an outlined box: a surface tint you can see through to the panel,
## a well for the glyph and a brass edge with a warmer fill when the cursor is on it. Nothing is
## outlined, because an outline around every row makes every row shout and the selected one shout no
## louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = _can_afford(opt["cost"])
	if selected:
		_round_rect(rr, 4.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 2.0), Vector2(2.0, rr.size.y - 4.0)), UI_ACCENT)
	else:
		_round_rect(rr, 4.0, Color(1.0, 1.0, 1.0, 0.030))
	_draw_thing_icon(id, Rect2(rr.position + Vector2(6.0, 2.5), Vector2(16.0, 16.0)))
	var name_col: Color = (GOLD_PALE if selected else UI_TEXT) if afford \
		else (SHORT_SELECTED if selected else UI_TEXT_FAINT)
	var cw: float = _cost_glyphs(rr, opt["cost"])
	draw_string(_font, rr.position + Vector2(26.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 36.0 - cw, 10, name_col)


## The price as glyphs rather than prose. "6 Iron Ingot 3 Wood" is a hundred pixels of a hundred-and-
## seventy pixel row and it clipped the name off the thing being bought: "Iron Pickax", "Blast Furnac".
## The same fact as two icons and two numbers is forty, and it reads faster besides.
##
## An ingredient you are short of prints what you are short by (`-2`) where this printed `2` in red and
## left the subtraction to the reader. It is the same number `_shortfall_note` prints in words under the
## detail button, so the row is the compressed form of that sentence. An ingredient the pack covers
## still prints its price, which is what an expert scans a row end for.
##
## The sign exists so the hue is not the only copy of it. Green covered against red short is a hue
## difference. That is nothing to a greyscale reader and nothing on a one-ingredient recipe with no
## second numeral to compare against. Both come off the same string below, so the two readers cannot be
## told different things.
##
## It costs 3px per short ingredient and nothing per covered one. A deficit cannot carry more digits
## than the price it was subtracted from, so the only growth is the sign itself: 3.0px at size 9 in the
## Open Sans SemiBold `ThemeDB.fallback_font` resolves to here. Measured at the tightest row this panel
## can draw, three ingredients in a 169.3px column with every one short, the name's budget goes 58.3 to
## 49.3. The longest name a three-ingredient row can carry is Drift Rig at 40.0px, which clears it by
## 9.3. Nothing clips.
##
## What it does not fix is the red. Against the selected row's plate that literal measures 4.20:1, under
## the 4.5 `tools/check_text_contrast.gd` holds body text to and under the 4.99 the same red reads on an
## unselected row. Every lift of it closes the value gap between green and red, which used to be the
## only thing carrying affordability without colour. The sign now carries that job.
func _cost_glyphs(rr: Rect2, cost: Dictionary) -> float:
	# One walk order for both passes. The sum is the same whichever way the dictionary is read, so the
	# width pass does not need this. It takes it anyway, because the day the two passes walk the price by
	# two different rules is the day one of them stops describing the other.
	var order: Array[StringName] = _cost_order(cost)
	var w: float = 0.0
	for item: StringName in order:
		w += 12.0 + _font.get_string_size(_cost_numeral(item, int(cost[item])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	var x: float = rr.end.x - 5.0 - w
	for item: StringName in order:
		var label: String = _cost_numeral(item, int(cost[item]))
		Visuals.draw_item(self, Vector2(x + 6.0, rr.position.y + 10.5), 12.0, item)
		# The ink reads the sign rather than asking the pack a second time. `have < need` written out twice,
		# three lines apart, is how the mark and the colour start disagreeing about one ingredient, and
		# disagreeing is worse than either cue missing, because each reader sees only one of them.
		draw_string(_font, Vector2(x + 13.0, rr.position.y + 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			UI_WARN if label.begins_with("-") else Color(0.482, 0.796, 0.518))
		x += 12.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	return w


## What one ingredient's numeral says: the deficit when you are short of it, the price when you are not.
##
## It is a function and not an expression because the width pass and the draw pass above are two walks
## of the same dictionary, and they used to each format the numeral for themselves. The width is not
## cosmetic here: `_works_row` subtracts this function's total from the name's budget, so a numeral that
## measures narrower than it draws puts the price on top of the word it was widened to protect.
func _cost_numeral(item: StringName, need: int) -> String:
	var gap: int = _cost_gap(item, need)
	return ("-%d" % gap) if gap > 0 else str(need)


## The one subtraction, and the one predicate. What this ingredient is short by: positive while the pack
## cannot cover the line, zero or below once it can.
##
## Everything that tells an outstanding ingredient from a settled one reads this and nothing else: the
## order the price is walked in, the card under a detail chip, the sign on both surfaces' numerals and
## the ink they are drawn in. `have < need` was written out at four addresses before, which is
## survivable only while the four cannot disagree. They can, and a mark that disagrees with the colour
## beside it about one ingredient is worse than either cue missing, because each reader only ever sees
## one of them.
func _cost_gap(item: StringName, need: int) -> int:
	return need - int(sim.inventory.get(item, 0))


## The bill-of-materials order: the lines you still owe first, the lines the pack already settles after.
##
## The numerals were the half of this that shipped first, a deficit printing as a signed `-N` instead of
## leaving the subtraction to the reader, and fixing a numeral does not make a row of chips a bill. A
## bill is a list whose outstanding lines are grouped, because the only question anybody brings to a
## price is which lines are still open. Interleaved, that question is a scan of every ingredient and a
## comparison per chip. Grouped, it is a glance at the front of the price, and the count of open lines is
## the length of the first run.
##
## Stable inside each run, so a recipe keeps the order its `.tres` or its rung wrote it in and the only
## thing that ever moves a chip is that ingredient crossing the line. The crossing is the point rather
## than the price of it: the frame where you pick up the last ingot is the frame the owed run gets
## shorter, which is the most direct feedback on the panel and the one thing a static row could never say.
##
## It sorts the works rows and the detail plate alike, so a machine's price does not rearrange itself
## between the row you picked it from and the plate that prices it.
func _cost_order(cost: Dictionary) -> Array[StringName]:
	var owed: Array[StringName] = []
	var settled: Array[StringName] = []
	for item: StringName in cost:
		if _cost_gap(item, int(cost[item])) > 0:
			owed.append(item)
		else:
			settled.append(item)
	owed.append_array(settled)
	return owed


## A machine's sprite or an item's glyph, whichever this id is. The pack grid, the works rows and the
## tech chips all want exactly this and used to each carry their own copy of it.
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


## The counter has exactly one verb button. Until now it was drawn twice from two sets of numbers.
##
## It was never photographed live. `capture_moments` set `_hud.can_craft = true` and `main.gd`
## recomputed it from `_near_bazaar()` before the shutter, so every menu capture shows the dead branch
## of this if. The first frame taken with `ready` true read `BUILDENTER`: the key hint started four
## pixels after the verb's last stroke at 10pt against 8pt, which is one word. `_detail_hold` drew the
## same construct with the hint hardcoded at `x + 58.0`, a gap of about 20px, so two buttons in one
## plate disagreed by a factor of five. The fixed 104px plate could not hold RESEARCH either, which is
## eight tracked characters, since it was sized for BUY.
##
## So: one function, one gap constant, and a width derived from the verb rather than asserted over it.
## The button stays anchored to the plate's right edge, so growing it moves its left edge inward and
## nothing downstream shifts. It returns the rect it drew, because the caller prints the note above it.
const VERB_SIZE: int = 10
const VERB_TRACK: float = 2.0
const VERB_HINT_SIZE: int = 8
const VERB_GAP: float = 14.0          ## verb ink to key hint; at the shipped 4.0 the two read as one word
const VERB_PAD: float = 12.0          ## plate edge → ink, both ends
const VERB_MIN_W: float = 104.0       ## BUY and BUILD keep the width the layout was drawn around
const VERB_H: float = 24.0
const VERB_BASE: float = 16.0         ## button top → the verb's baseline. The state form shares the line.
## The ink on a live button. The key hint beside it is that same ink thinned, rather than a second copy
## of the literal carrying its own alpha, which is what the file held: `Color(0.08, 0.07, 0.04)` and
## `Color(0.08, 0.07, 0.04, 0.62)`, three lines apart, with nothing relating them.
##
## The alpha is bounded by the contrast floor and not by taste, which is the whole reason it moved. The
## hint measured 3.77:1 against the gold it is printed on while the verb above it read 8.30, so the
## thinning that made the hint subordinate had taken it under 4.5 and the one glyph naming the key that
## runs the button was the least legible thing on it. At 0.75 it is 5.15:1 and still visibly quieter
## than the word. 0.70 would have cleared at 4.57, and a floor of 4.5 with a value at 4.57 is a defect
## waiting for the next palette nudge, so it is not set there.
const VERB_INK := Color(0.08, 0.07, 0.04)
const VERB_HINT_A: float = 0.75       ## the hint is the verb's own ink, thinned to the floor and no further
const DETAIL_ROW_GAP: float = 8.0     ## between the row's three parts: the price, the reason, the verb
const DETAIL_NOTE_SIZE: int = 8       ## the reason the verb will not run; the smallest type on the plate
## The plate's bottom shelf, computed once for everything that stands on it. `_verb_button` and
## `_state_plate` each wrote `box.size.y - 34.0`, and 34 has no relation anywhere in this file to the two
## numbers it is the sum of: the 24 the button is tall, and the `DETAIL_PAD` of margin the plate keeps
## under everything else. It is the sum now, so the row's floor is the plate's own bottom margin.
func _detail_row(box: Rect2) -> Rect2:
	return Rect2(box.position.x, box.end.y - DETAIL_PAD - VERB_H, box.size.x, VERB_H)


## How wide the button has to be for this verb. It is separate from the drawing because the blurb beside
## it wraps against the button's left edge, and a blurb wrapping against a guessed width runs under it.
func _verb_button_w(verb: String, hint: String) -> float:
	var hw: float = 0.0 if hint == "" else _font.get_string_size(
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_HINT_SIZE).x
	return maxf(VERB_MIN_W, VERB_PAD * 2.0 + _tracked_w(verb, VERB_SIZE, VERB_TRACK)
		+ (0.0 if hint == "" else VERB_GAP + hw))


func _verb_button(box: Rect2, verb: String, hint: String, live: bool) -> Rect2:
	var vw: float = _tracked_w(verb, VERB_SIZE, VERB_TRACK)
	var w: float = _verb_button_w(verb, hint)
	var row: Rect2 = _detail_row(box)
	var btn := Rect2(row.end.x - DETAIL_PAD - w, row.position.y, w, VERB_H)
	var ty: float = btn.position.y + VERB_BASE
	if live:
		_round_rect(btn, 5.0, UI_ACCENT)
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK, VERB_INK)
		if hint != "":
			draw_string(_font, Vector2(btn.position.x + VERB_PAD + vw + VERB_GAP, ty), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_HINT_SIZE, Color(VERB_INK, VERB_HINT_A))
	else:
		_round_rect(btn, 5.0, Color(1.0, 1.0, 1.0, 0.05))
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK,
			Color(0.44, 0.46, 0.52))
	return btn


## A word that is true of you, not a button you failed to press.
##
## `_verb_button` draws the right pair: one action, live or not yet. RESEARCHED and HELD are not that
## pair's second half. They are states with no verb behind them and in the same grey pill they read as
## an action whose button is broken, so the plate said AUTOMATION, already yours, RESEARCHED.
##
## So a state gets a form of its own and the difference in shape arrives before the difference in
## colour: no plate under it, a tick, and the green the ladder already paints what is yours in. Three
## marks now say three things across the counter. A gold pill is the verb you can run, a grey pill the
## verb you cannot run yet, and this is nothing to run.
const STATE_INK := Color(0.48, 0.70, 0.52)
const STATE_TICK: float = 9.0         ## the mark's width
const STATE_GAP: float = 6.0          ## mark → word
func _state_plate_w(word: String) -> float:
	return STATE_TICK + STATE_GAP + _tracked_w(word, VERB_SIZE, VERB_TRACK)


## Set on the button's own baseline and against the plate's right edge, because a state and a verb are
## read in the same place at the same moment, and only one of them is ever on a given plate.
func _state_plate(box: Rect2, word: String) -> void:
	var row: Rect2 = _detail_row(box)
	var x: float = row.end.x - DETAIL_PAD - _state_plate_w(word)
	var ty: float = row.position.y + VERB_BASE
	var mid: float = ty - 4.0
	draw_line(Vector2(x, mid), Vector2(x + 3.5, mid + 3.5), STATE_INK, 1.6)
	draw_line(Vector2(x + 3.5, mid + 3.5), Vector2(x + STATE_TICK, mid - 4.5), STATE_INK, 1.6)
	_tracked(word, Vector2(x + STATE_TICK + STATE_GAP, ty), VERB_SIZE, VERB_TRACK, STATE_INK)


# --- the detail plate -----------------------------------------------------------------------------------

## The detail plate: the selected thing drawn large under a lamp, with one sentence of what it is for,
## its price as one chip per ingredient, and the verb as a real button carrying the key that runs it.
## This is where the panel stops being a list and starts being a shop, and it puts the three answers a
## player is after in one place: what this is, whether they can afford it, and what they press.
##
## It is also where the plate's share of the panel is decided, because the plate is the height of what
## it draws and this is what draws it. A thing on sale gets the full 88, while a thing you already own
## gets the compact plate, which is the same card with the price taken out.
func _draw_bazaar_detail(g: Dictionary) -> void:
	var box: Rect2 = g["detail"]
	_round_rect(box, 6.0, Color(1.0, 1.0, 1.0, 0.028))
	# The one place the art square is built, for all three plates, since `_detail_hold` and `_detail_pack`
	# are handed this rect rather than each writing the margin down again. It is read off the plate, being
	# what is left of the plate's height once its margins are taken, so at the full depth it is the
	# `DETAIL_ART` that `BAZAAR_DETAIL` is built from, and at the compact depth it is whatever fits beside
	# the text.
	#
	# It is capped, because the plate can now be deeper than the full 88 as well as shallower. A compact
	# plate carrying a third line of sentence is taller than the square is meant to be, and letting the
	# square follow it up would push the text column right, narrow the sentence and ask for a fourth line,
	# which is the height feeding its own input.
	var side: float = minf(DETAIL_ART, box.size.y - DETAIL_PAD * 2.0)
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
	# The word for a thing you already have and the counter's one flag for having it. Everything the plate
	# does differently for such a thing hangs off this: the state form instead of the button and no price.
	var state: String = ""
	if kind == "tech":
		var t: Dictionary = ResearchRules.tech(id)
		title = str(t["name"])
		cost = t["cost"]
		var sample: StringName = t.get("sample", &"")
		# What it buys you, by name. A ladder that only prices its rungs asks you to buy a number, while the
		# reason to climb is the machines waiting at the top of it, and now that WORKS lists only what you can
		# already build, this plate is the only place those machines are named at all.
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
			# One plate said it twice. The note under the button read "already yours" over a button reading
			# RESEARCHED, which is one sentence in two registers, so the word that names the state keeps the job.
			# A rung you have climbed has no precondition left to name.
			state = "RESEARCHED"
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
		# This branch cannot fire today and it is kept anyway. `kind`, `id` and `row` come from
		# `bazaar_action()` and from nowhere else. Its RACK arm resolves the id as
		# `rack_ids[r] if r < rack_ids.size() else &""`. That is textually the expression `_unlocked` filtered
		# on, at the index `_unlocked` handed back, so for a Rack row this test is false by construction. Its
		# MACHINE arm resolves through `_craft_id`, which falls back to `machine_icons.keys()[i]` when
		# `craft_ids` is short, while `_unlocked` was handed `craft_ids` and filtered on the `&""` it read
		# past the end. Two functions answer "which thing is works row i" by two rules. They agree only while
		# `craft_ids` is as long as `craft_options`, which `main.gd` gets right and nothing in this tree
		# asserts.
		#
		# So the counter cannot reach this and deleting it would change no state on any screen. What deletion
		# would cost is a filled gold BUILD and an ENTER hint for a machine behind unresearched tech, in the
		# one configuration `_craft_id`'s fallback is written for. The defect worth fixing is the two
		# resolvers rather than the guard that outlives them, and that is a change to `_unlocked`.
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

	var tx: float = art.end.x + DETAIL_TEXT_GAP
	var reserve: float = _state_plate_w(state) if state != "" \
		else _verb_button_w(verb, "ENTER" if ready else "")
	var text_w: float = box.end.x - tx - reserve - DETAIL_TEXT_RIGHT
	_tracked(title.to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, GOLD_PALE)
	draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y), blurb,
		HORIZONTAL_ALIGNMENT_LEFT, text_w, 9, DETAIL_BLURB_LINES, UI_TEXT_DIM)
	# A thing you own has no price left to weigh and no verb to run, so the plate stops at the word for
	# having it. It was printing the price: the AUTOMATION rung read RESEARCHED and still carried a "64/2"
	# chip, which invites being read as "64 of 3 required" on a rung nobody can buy. The plate keeps its
	# full depth all the same, since `_detail_wanted_h` is keyed on the kind, so the tree does not reflow
	# under a cursor walking across researched and unresearched rungs.
	if state != "":
		_state_plate(box, state)
		return
	# The decision row: the price, the reason the verb will not run, and the verb, on one shelf against the
	# plate's right margin.
	#
	# They were three things at three addresses on three different lines. The chips started at the text
	# column's left edge. The button was pinned to the plate's right edge with the better part of 300px of
	# nothing between them. The reason floated in that void a line above the button. Chip tops sat at 62,
	# the button top at 54 and the reason baseline at 48.
	#
	# It packs from the button leftward, because the button is the one element whose position may not move.
	# `text_w` above measures the blurb's column against it, so a verb walking with the length of a
	# shortfall sentence would rewrap the sentence it stands under.
	#
	# The blurb's reserve is still the button alone, which reads like an oversight and is not one. The
	# price and the reason do overlap the sentence in x, by some 20px on the Prospecting plate, but they
	# clear it in the other axis. The chips stand on the row's floor, `DETAIL_CHIP_H` up from a shelf
	# `DETAIL_PAD` off the plate's bottom, which puts their ceiling 59 down an 88px plate. The blurb's
	# second line is `DETAIL_BLURB_Y` plus one font line height, landing 53 down on the BENCH plate with
	# descenders bottoming out at 55. Four pixels. Only the button is tall enough to reach the sentence's
	# line, and a bigger blurb face or a third reserved line would move `BAZAAR_DETAIL_MIN`.
	var btn: Rect2 = _verb_button(box, verb, "ENTER" if ready else "", ready)
	var shelf: Rect2 = _detail_row(box)
	# The price as a bill: what you still owe first, what the pack already settles after (`_cost_order`),
	# and the two runs told apart by the card rather than by a gap or a fourth colour (`_detail_chip`).
	# The width pass and the draw pass below take the same array, so the row cannot pack one arrangement
	# and paint another. The row's give point is unchanged, because a settled line is narrower than it was.
	var order: Array[StringName] = _cost_order(cost)
	var chips_w: float = 0.0
	for item: StringName in order:
		if chips_w > 0.0:
			chips_w += DETAIL_CHIP_GAP
		chips_w += _detail_chip_w(item, int(cost[item]))
	var note_w: float = 0.0 if note == "" \
		else _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE).x
	var note_gap: float = 0.0 if note == "" else DETAIL_ROW_GAP
	# The row gives at the reason and never at the art. The column is 426 wide, the panel's inner width
	# less the square, its gaps and the plate's two margins, and nothing bounds a price and a shortfall
	# sentence against it: the widest thing the catalogue quotes today is the Drift Rig's three ingredients
	# with all three short, and a fourth ingredient is one `.tres` away. So the chips stop at the text
	# column's left edge and the reason takes what is left, drawn to that width rather than through the art
	# square. A sentence clipped at its end is a bad frame; one printed across the picture is a broken one.
	var cx: float = maxf(tx, btn.position.x - DETAIL_ROW_GAP - note_w - note_gap - chips_w)
	var chip_y: float = shelf.end.y - DETAIL_CHIP_H
	for item: StringName in order:
		cx = _detail_chip(Vector2(cx, chip_y), item, int(cost[item])) + DETAIL_CHIP_GAP
	# Left open, and recorded rather than quietly created. Now that a short chip prints the deficit, the
	# shortfall branch of this note is the same number a second time some two hundred pixels along one
	# row, "-2/3" beside "short 2 Iron Ingot". That is the shape `_detail_hold` stood a note down for, and
	# the argument for standing this one down too is already written there. It is not stood down here, for
	# two reasons that are about evidence rather than taste. It is the shipped treatment for a dead button
	# saying why it is dead, and one surface does not get to retire a decision that was made for the whole
	# counter. It is also the only prose account of the shortfall on the plate, which a reader who is not
	# reading the glyphs has instead of them, and whether the chips cover that reader is a question for a
	# text-only review rather than an edit. The note's other branches, the sample material, "behind
	# Automation" and "at a claimed Bazaar", say things no chip can and are not in question either way.
	if note != "":
		# On the price's own baseline, because the reason and the numbers it is derived from are one sentence.
		# The verb's label sits a couple of pixels higher, centred in a pill half again as deep: text aligns to
		# text, and a button's word aligns to its button.
		var nx: float = maxf(cx - DETAIL_CHIP_GAP + note_gap, btn.position.x - DETAIL_ROW_GAP - note_w)
		draw_string(_font, Vector2(nx, chip_y + DETAIL_CHIP_BASE), note, HORIZONTAL_ALIGNMENT_LEFT,
			btn.position.x - DETAIL_ROW_GAP - nx, DETAIL_NOTE_SIZE, GOLD_DIM)


## The lamp. Three rings behind the goods is the whole trick, and it is what makes a glyph read as lit
## rather than as big. All three plates light their square the same way and each used to say so in its
## own numbers, which stopped being survivable the moment the compact plate gave one of them a smaller
## square: a radius written as 34 hangs a third of the outer ring over the edge of a 52px square.
func _detail_lamp(art: Rect2, alpha: float) -> void:
	var r: float = art.size.x * 0.5
	for k: int in 3:
		draw_circle(art.get_center(), r * (1.0 - float(k) * DETAIL_LAMP_STEP),
			Color(0.85, 0.70, 0.35, alpha))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))


## The thing itself, inside the square: the square inset by a rim, rather than a 44 written at two of
## the three plates and a 40 at the third, both of which overflow the compact square. `_draw_tech_art`
## keeps its own composition, since it lays four unlock icons out in the square rather than centring one
## thing and a tech is only ever selected on BENCH, where the plate is at full depth.
func _detail_glyph(art: Rect2) -> Rect2:
	return art.grow(-DETAIL_GLYPH_INSET)


## Why the button is dead, when the reason is the pack and not the place.
##
## The plate has always had a line for the precondition it cannot meet, "at a claimed Bazaar" or "behind
## Automation" or "research Ironworks first", and every one of those fires for a reason outside the
## pack. Stand at a counter you cannot afford anything at and the line was blank: a grey button, no
## sentence, and a red numeral in a price chip as the only account of why ENTER does nothing. The
## captures could not show that gap. A fixture standing away always took the "at a claimed Bazaar"
## branch, the one state where the note is never empty.
##
## It says the deficit and not the price because the price is already on the chips this sentence sits
## beside. The sample material, a tech's analysis input, is a cost the chips do not show, so it is named
## here or nowhere.
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


## A tech has no glyph of its own, being knowledge, so its plate shows what it buys: the machines it
## unlocks, laid out big. That is also the honest answer to "why would I research this".
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


## The plate for a thing you are carrying: what it is for, how many you have, and the pack screen's one
## verb, which is to put it in your hand.
##
## Two quantities, two words, and neither borrows the other's. This plate used to say "carrying 24" next
## to a button reading "IN HAND", over a grid whose lit well was badged "HELD". Carrying, holding and
## having in hand are the same thing in English, so "carrying 24" could be read as 24 in your hand.
##
## So the pack owns one vocabulary and the hand owns the other. What you have is in the pack, the word
## the tab, the plate title and the head's chips already use. What you are wielding is HELD.
##
## The lifetime figure is all told, with no verb in front of it, because no verb is true of every row.
## This plate prices ore you mined, wood you chopped and ingots your line poured. It is the only
## per-item total on any screen, since the FORGED chip counts ingots and says so.
func _detail_hold(box: Rect2, art: Rect2, id: StringName, row: int) -> void:
	_detail_lamp(art, 0.045)
	_draw_thing_icon(id, _detail_glyph(art))
	var tx: float = art.end.x + DETAIL_TEXT_GAP
	_tracked(_item_label(id).to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, GOLD_PALE)
	# There is no line cap, because the plate was sized to hold this. `_hold_overflow_h` measured every
	# sentence in the pack at `_hold_text_w` and bought the deepest one its lines, so the count this used
	# to be capped at is a floor the height already answered. It is the same width at both ends for the
	# same reason: a blurb wrapping at a different number than the height was computed from would run off.
	draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y),
		str(ITEM_PURPOSE.get(id, "—")), HORIZONTAL_ALIGNMENT_LEFT, _hold_text_w(),
		DETAIL_BLURB_SIZE, -1, UI_TEXT_DIM)
	# The tally sits where the blurb ends, not at a baseline of its own. It used to be written 76 down a
	# plate that was always 88, which is the shop chip row's depth borrowed by a plate that has no chips,
	# and this is the plate that no longer has the height to spare. It is taken off the plate's own bottom
	# edge rather than off `DETAIL_FACT_Y`, because the two are the same pixel only while the plate is at
	# its floor and a fact pinned to the constant would print through a row the blurb had grown into.
	var carried: int = int(sim.inventory.get(id, 0))
	var made: int = int(sim.total_produced.get(id, 0))
	var tally: String = "%d in the pack   ·   %d all told" % [carried, made]
	draw_string(_font, Vector2(tx, box.end.y - DETAIL_TAIL), tally,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_BLURB_SIZE, UI_TEXT_FAINT)
	# And then the rest of that line, which was the emptiest run of pixels on the counter: two counters at
	# the left margin, a button at the right, and the whole middle of the plate's bottom shelf holding
	# nothing. `_detail_demand` fills it with the one live fact the pack screen can answer, per its note.
	#
	# It is handed the tally's measured right edge, not a column the two agree about by writing the same
	# number twice. The tally is the fixed thing on this line, being the plate's own fact, and the demand
	# gives, so the row's give point is at the demand's left end and the string that decides where that is
	# is the string that was just drawn.
	_detail_demand(box, id, tx + _font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_BLURB_SIZE).x + DETAIL_ROW_GAP)
	var held: int = inv_selected_getter.call() if inv_selected_getter.is_valid() else -1
	if row == held:
		# HELD is not HOLD greyed out. It answers "which one is in my hand", which is what the pack screen is
		# opened to ask, while the dead pill said the pack's one verb had broken.
		_state_plate(box, "HELD")
	else:
		_verb_button(box, HOLD_VERB, HOLD_KEY, true)


## The one word on the row that says which way the numbers point, named because the row measures it and
## draws it from the same string. Every other numeral on this counter is a price for the thing named
## beside it. These are one item's line in somebody else's price, and without the lead-in the row is a
## rebus.
const DEMAND_LEAD: String = "wanted by"


## Who else wants this, and how short you still are for them: the pack plate's half of the bill.
##
## The standing rule is that the inspector expands only for a meaningful choice. The height half of that
## is refused with its evidence written beside the constants: 81 of the full plate's 88 is spoken for,
## the chips run off the bottom 29px before the old share is reached, and `check_pack_layout` floors the
## plate at 70 independently. What was left is the content, and on PACK the content was the complaint.
## The plate drew a sentence out of a `const` table and two counters, "24 in the pack · 61 all told",
## and then left the right two thirds of its bottom shelf empty beside the one verb this tab has.
## Neither number is a thing you act on. A lifetime total is a souvenir.
##
## The question a pack screen is actually opened with is whether to keep gathering the stuff, and the
## counter is the one screen in the game that knows, because it holds every price this stack is a line
## in. So the shelf carries the transpose of a works row. A price is indexed by product and answers
## "what does this machine cost", while standing in your own pack you are asking it the other way round,
## "what is this stack short for", and nothing anywhere answered that. `ITEM_PURPOSE`'s own docstring
## says the resource lines exist so that resources answer "what wants this". This is that sentence with
## the pack's state in it.
##
## A buyer is whatever the counter would let you press ENTER on today: the open machines, the open Rack
## rows, and the next rung of the ladder. They come from `open_machines()`, `open_rack()` and
## `ResearchRules.next_tech`, the three sources the tabs themselves list from, so this row and those
## tabs cannot come to disagree about what is buildable. The locked half is deliberately absent, for the
## reason `_tab_works` gives for hiding it there: a wall of what you cannot have is what that rebuild
## was clearing out, and the future has a home already on the BENCH where it reads as a ladder.
##
## The rung's sample is part of the rung's price. Research eats one of its signature material on top of
## the metal, a cost the rung's own `cost` dictionary does not carry and which `_shortfall_note` is
## otherwise the only place in this file to name. It is folded into the rung's line rather than listed
## as a second one, because a rung that wants six iron ingots and a seventh to analyze wants seven.
func _item_demand(id: StringName) -> Array[Dictionary]:
	var owed: Array[Dictionary] = []
	var settled: Array[Dictionary] = []
	if sim == null or id == &"":
		return owed
	for i: int in open_machines():
		_demand_line(id, _craft_id(i), "", craft_options[i]["cost"], owed, settled)
	for r: int in open_rack():
		# The same expression `bazaar_action` resolves a Rack row with, so the row you can select and the
		# row this prices are the same row by construction rather than by two rules that agree today.
		_demand_line(id, rack_ids[r] if r < rack_ids.size() else &"", "",
			rack_options[r]["cost"], owed, settled)
	var next: StringName = ResearchRules.next_tech(sim.research)
	if next != &"":
		var rung: Dictionary = ResearchRules.tech(next)
		var price: Dictionary = (rung.get("cost", {}) as Dictionary).duplicate()
		var sample: StringName = rung.get("sample", &"")
		if sample == id:
			price[id] = int(price.get(id, 0)) + 1
		# A rung is named rather than drawn. It has no glyph of its own, which is the whole reason
		# `_draw_tech_art` exists, and at plate size that function's answer is to show the machines the
		# rung unlocks. Borrowing one of those down here would put a Drill on the row and mean Automation,
		# so the ladder's entry wears its word instead. There is at most one of them and it is always last.
		_demand_line(id, &"", str(rung.get("name", "")), price, owed, settled)
	# Owed first and settled after, which is `_cost_order`'s rule one level up. There it groups the
	# ingredients of one price; here it groups the prices of one ingredient, and the reason is the same.
	# The only question anybody brings to a bill is which lines are still open, and the count of open
	# lines is the length of the first run. What crosses a line here is the same subtraction, `_cost_gap`.
	owed.append_array(settled)
	return owed


## One buyer's line, or none if this buyer does not name the item. Split out so the three sources above
## cannot each grow their own copy of the predicate that decides which run a line belongs in.
func _demand_line(id: StringName, glyph: StringName, word: String, cost: Dictionary,
		owed: Array[Dictionary], settled: Array[Dictionary]) -> void:
	var need: int = int(cost.get(id, 0))
	if need <= 0:
		return
	var line: Dictionary = {"glyph": glyph, "word": word, "need": need}
	if _cost_gap(id, need) > 0:
		owed.append(line)
	else:
		settled.append(line)


## The row, right-packed against the space the verb keeps and given whatever the tally leaves it.
##
## That space is reserved for the button and not for the state, which is `_hold_text_w`'s rule and it is
## here for the same reason. `HELD` is a tick and a word where `HOLD` is a pill with a key in it, so a
## row measured against whichever form this slot carries would slide sideways, or drop a line, as a
## consequence of pressing the key underneath it.
##
## It sits on the tally's baseline rather than on the shelf's floor where the priced plate stands its
## chips. Text aligns to text, and a card cannot follow it here: a chip's baseline is `DETAIL_CHIP_BASE`
## down its own top edge, so the card runs `DETAIL_CHIP_H - DETAIL_CHIP_BASE` past whatever line it is
## set on, and this line is `DETAIL_TAIL` off the bottom of the plate. Seat a card on it and the card's
## bottom edge lands inside the `DETAIL_PAD` margin every other thing on the plate keeps. So the buyers
## are drawn the way a works row prices instead, glyph and signed numeral straight onto the plate with
## no well. That is the form `_cost_glyphs` has always used, and the form a settled chip already falls
## back to on the plate above. The elevation that tells the two runs apart there is spent here on the
## order, which is the cue that costs no pixels.
##
## The ink reads the sign, out of the same `_cost_numeral` the works rows print, so a machine that is
## two ingots short says `-2` in the list and `-2` here. Nothing new is coloured in. A shortfall is
## `UI_WARN` as it is everywhere else, and a covered line is drawn in the type ramp's quiet rung rather
## than in the price surfaces' green: on those surfaces green means "you can pay this" about a price you
## are standing in front of, while here a covered line means there is nothing to do, which is what this
## counter draws quiet everywhere. The minus is the cue either way and needs no comparison to read.
func _detail_demand(box: Rect2, id: StringName, left: float) -> void:
	var lines: Array[Dictionary] = _item_demand(id)
	if lines.is_empty():
		return
	# The glyph is the height of the line it stands in, asked of the font rather than written as the 12
	# the works row happens to use. A mark on a text line that is not the text's own line height is a
	# number that has to be re-guessed the day the face or the size moves, and this row already has to
	# fit under a baseline 8px off the bottom of the plate.
	var glyph: float = _font.get_height(DETAIL_BLURB_SIZE)
	var lead: float = _font.get_string_size(DEMAND_LEAD, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_NOTE_SIZE).x
	var right: float = box.end.x - DETAIL_PAD - _verb_button_w(HOLD_VERB, HOLD_KEY) - DETAIL_ROW_GAP
	var runs: PackedFloat32Array = PackedFloat32Array()
	var whole: float = 0.0
	for e: Dictionary in lines:
		var ew: float = _demand_w(id, e, glyph)
		runs.append(ew)
		whole += ew + (DETAIL_ROW_GAP if runs.size() > 1 else 0.0)
	var budget: float = right - left - lead - DETAIL_ROW_GAP
	# What did not fit is said rather than swallowed. A row that quietly stops after two buyers reads as
	# "two things want this", which is a stronger claim than the truth and one the reader has no way to
	# doubt. The reserve is taken at the count's widest, with every line dropped, because the marker's
	# width decides how many lines fit and how many lines fit decides the marker. An upper bound settles
	# that in one pass, and it can only ever leave a pixel or two of air before the button.
	var more_w: float = _font.get_string_size("+%d" % lines.size(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_NOTE_SIZE).x
	if whole > budget:
		budget -= more_w + DETAIL_ROW_GAP
	var shown: int = 0
	var used: float = 0.0
	for i: int in runs.size():
		var step: float = runs[i] + (DETAIL_ROW_GAP if i > 0 else 0.0)
		if used + step > budget:
			break
		used += step
		shown += 1
	# The row gives at the demand, never at the tally. The tally is this plate's own fact about the thing
	# under the cursor, while the demand is about everything else. A pack whose longest tally leaves no
	# room for a lead-in and one buyer draws the plate it drew before, rather than a lead-in with nothing
	# after it.
	if shown <= 0:
		return
	var cut: int = lines.size() - shown
	var span: float = lead + DETAIL_ROW_GAP + used + (0.0 if cut <= 0 else DETAIL_ROW_GAP + more_w)
	var at := Vector2(right - span, box.end.y - DETAIL_TAIL)
	draw_string(_font, at, DEMAND_LEAD, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE, UI_TEXT_FAINT)
	at.x += lead + DETAIL_ROW_GAP
	for i: int in shown:
		at.x += _demand_mark(at, id, lines[i], glyph) + DETAIL_ROW_GAP
	if cut > 0:
		draw_string(_font, at, "+%d" % cut, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE,
			UI_TEXT_FAINT)


## How wide one buyer's line is. Asked before the row is packed and returned by the drawing below, which
## calls this rather than adding the same three terms a second time. The width pass and the draw pass on
## the plate above are two walks of one dictionary and used to each format their own numeral, which is
## survivable only for as long as the two spellings cannot differ.
##
## The inner gap is tighter than the outer one, and the two are the constants that already say so:
## `DETAIL_CHIP_GAP` holds a buyer to its number, `DETAIL_ROW_GAP` separates one buyer from the next.
## That is the plate's own spacing argument, that a price and the three parts of a row set at one
## spacing would be seven equal things in a line, applied to a row whose parts are buyers.
func _demand_w(id: StringName, e: Dictionary, glyph: float) -> float:
	var word: String = str(e["word"])
	var head: float = glyph if word == "" else _font.get_string_size(word,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE).x
	return head + DETAIL_CHIP_GAP + _font.get_string_size(_cost_numeral(id, int(e["need"])),
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE).x


## One buyer drawn, and the width it took, which is the measured one and not a second sum of the same
## terms.
##
## `at` is the row's baseline, and a baseline sits about two thirds down its line box, so the mark is
## centred a third of a line height above it and comes out optically level with the digits beside it.
## Said as a fraction of the line rather than as an offset in pixels, because the line height is asked
## of the font: pin it to a number and it is a guess again the day the face or the size moves.
func _demand_mark(at: Vector2, id: StringName, e: Dictionary, glyph: float) -> float:
	var word: String = str(e["word"])
	var head: float = glyph
	if word == "":
		var mark: StringName = e["glyph"]
		_draw_thing_icon(mark, Rect2(at.x, at.y - glyph / 3.0 - glyph * 0.5, glyph, glyph))
	else:
		head = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE).x
		draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE, UI_TEXT_FAINT)
	var num: String = _cost_numeral(id, int(e["need"]))
	draw_string(_font, Vector2(at.x + head + DETAIL_CHIP_GAP, at.y), num, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_CHIP_SIZE, UI_WARN if num.begins_with("-") else UI_TEXT_FAINT)
	return _demand_w(id, e, glyph)


## PACK has nothing to buy, so its plate answers the other question a pack screen is asked: what the
## factory is making for you while you stand here.
func _detail_pack(box: Rect2, art: Rect2) -> void:
	_detail_lamp(art, 0.035)
	Visuals.draw_item(self, art.get_center(), _detail_glyph(art).size.x, &"ingot")
	var tx: float = art.end.x + DETAIL_TEXT_GAP
	_tracked("THE PACK", Vector2(tx, box.position.y + 24.0), 13, 1.8, GOLD_PALE)
	var rates: Array[Dictionary] = sim.production_rates()
	if rates.is_empty():
		draw_string(_font, Vector2(tx, box.position.y + 42.0),
			"nothing is running — build a Forge at the WORKS tab and feed it ore",
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 120.0, 9, UI_TEXT_DIM)
		return
	draw_string(_font, Vector2(tx, box.position.y + 42.0), "your line is making",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	# The rate chips sit on the compact plate's last line, the same line the hold plate's tally uses, so
	# the one plate with two contents puts both in the same place. They are taken off the plate's bottom
	# edge for the reason `_detail_hold` gives: this plate carries no sentence of its own but shares a
	# height with one that does, and it has to land wherever that height puts it.
	var cx: float = tx
	var base: float = box.end.y - DETAIL_TAIL
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


## The price chip's own measurements, named because the decision row packs from its right edge leftward
## and has to know how tall and how wide a chip is before it can place one. The height matters twice
## over, since it is what seats the chips on the row's floor beside a button half again their depth.
##
## `DETAIL_CHIP_WELL` is not `DETAIL_CHIP_H` wearing another hat. One is the room the glyph stands in
## and the other is how deep the card is, and the two are equal by coincidence, so they are left as
## separate numbers on purpose. The well is named at all only because a chip without a card has to know
## where its numerals start without the card's width to read it off.
const DETAIL_CHIP_H: float = 19.0
const DETAIL_CHIP_BASE: float = 13.5  ## chip top → the numeral pair's baseline, which the reason shares
const DETAIL_CHIP_SIZE: int = 9
const DETAIL_CHIP_WELL: float = 19.0  ## chip left edge → the numerals: the well the item glyph stands in
const DETAIL_CHIP_PAD: float = 26.0   ## the glyph well and the right margin, around the numeral pair
## The card's right margin, which is `DETAIL_CHIP_PAD` less the well the numerals start after, and
## therefore not a fifth number that has to be kept in step with the other four by hand. It is derived
## rather than written as a `7.0` for the reason this file has had to learn twice: a literal that must
## equal the difference between two other literals, with nothing relating them, is wrong the first time
## either of them moves and nothing anywhere fails when it does.
##
## It is named because a settled line has no card, and a margin is a property of the card. Such a line
## gives this back, which is what makes the covered run sit tighter than the owed one, so the grouping
## is paid for out of a number the drawing already contained rather than out of a new gap invented to
## sit between the runs. A new gap was the first design and it was wrong: `DETAIL_CHIP_GAP` is
## deliberately tighter than `DETAIL_ROW_GAP` so the price reads as one of the row's three parts, and
## any seam wide enough to group chips inside the price would have been wider than the gap that
## separates the price from the reason.
const DETAIL_CHIP_RIM: float = DETAIL_CHIP_PAD - DETAIL_CHIP_WELL
## Chip to chip inside the price, deliberately tighter than `DETAIL_ROW_GAP`. A four-ingredient price
## and the three parts of the row set at one spacing would be seven equal things in a line, and the
## price has to read as one of the three.
const DETAIL_CHIP_GAP: float = 6.0
## What one chip's pair says. The denominator is always the price. The numerator is the number you can
## act on: the deficit while the line is outstanding, the count you hold once it is settled.
##
## The plate first shipped have/need with the affordability colour on the number you hold, and that
## survives wherever a held count is still the useful one, because on a covered line there is nothing
## left to close and what you are carrying is the whole of the answer. On a short line it was the wrong
## number. "1/3" says where you stand, while the only question anybody asks a short line is how far
## there is to go, and that was a subtraction left to the reader on the one screen they are doing
## arithmetic on already. "-2/3" answers both at once, in the same width, and the price is not lost: it
## is still the denominator it always was.
##
## Nothing is lost that was not recoverable the other way round. What you hold is the price less the
## gap, so the reading this drops is itself one subtraction away. The difference is that it is now the
## subtraction nobody was doing rather than the one everybody was.
##
## And it is the works row's spelling. `_cost_glyphs` has printed a signed deficit per ingredient for
## longer, so a machine you cannot afford said "-2" in the list and "1/3" on the plate: one fact in two
## registers, two rows apart, which is how a reader ends up believing the two are about different
## things. The sign also carries affordability without hue, per that function's own argument, since a
## greyscale reader and a one-ingredient recipe both have nothing to compare a colour against and a
## leading minus needs no comparison.
func _chip_numeral(item: StringName, need: int) -> String:
	var gap: int = _cost_gap(item, need)
	# `need - gap` is what the pack holds, out of the same read the sign came from. Asking the inventory
	# a second time here would put the numerator and the mark above it on two different states of it.
	return ("-%d" % gap) if gap > 0 else str(need - gap)


## The pair whole, which is the string the width below measures and the two halves below that paint.
func _chip_label(item: StringName, need: int) -> String:
	return "%s/%d" % [_chip_numeral(item, need), need]


## Asked before the chip is drawn and asked by the chip when it draws itself, so the row cannot pack to
## one width and paint at another. It measures the pair whole while `_detail_chip` paints it in two
## halves, in two colours.
##
## It takes the item rather than a count, because what a chip says and how wide its card is both depend
## on whether the line is settled, and a caller that measured from a count would have to know that rule
## too.
##
## The row gets narrower more often than it gets wider. A settled line drops `DETAIL_CHIP_RIM`, while an
## outstanding one grows by whatever a signed deficit costs over the held count it replaced, which is
## bounded by the price's own digits: the whole catalogue's largest single ingredient is 12, in BROAD's
## stone and AUTOMATION's ingots, and no recipe with a two-digit ingredient has more than two of them.
func _detail_chip_w(item: StringName, need: int) -> float:
	var w: float = _font.get_string_size(_chip_label(item, need),
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE).x + DETAIL_CHIP_PAD
	return w if _cost_gap(item, need) > 0 else w - DETAIL_CHIP_RIM


## One line of the bill. A line you still owe gets a card under it, a line the pack already settles does
## not, and that is the grouping the numerals on their own could not give. How much of the price is
## raised is how much of it is outstanding, countable at a glance and without reading a numeral at all.
## Afford everything and the price goes flat, leaving the gold button the only lifted thing on the row.
## Afford nothing and every line of it stands up.
##
## Shape before colour, which is the rule `_state_plate` is already built on, and it is why this adds no
## fourth ink to the three the screen spent two passes concentrating down to. Both forms were already in
## the file: the card is the same surface tint every chip wore, and a settled line is drawn in exactly
## the form the works row prices in, glyph and numeral straight onto the plate with no well.
##
## The order the two runs arrive in is `_cost_order`'s, so the raised lines are also the first lines, and
## the two cues cannot say different things about one ingredient: both read `_cost_gap` and nothing else.
func _detail_chip(at: Vector2, item: StringName, need: int) -> float:
	# Have over need, which is what the three comments above have always said it was and what the code did
	# not do. It drew `need/have`, so a fresh save priced the Forge at "3/0", a fraction with a zero
	# denominator, and a finished save priced it at "3/64", which reads as five percent of the way there
	# while you carry twenty-one times what it asks. The numerator is the number you can act on, which is
	# also the one the affordability colour belongs on.
	var w: float = _detail_chip_w(item, need)
	var ok: bool = _cost_gap(item, need) <= 0
	if not ok:
		_round_rect(Rect2(at, Vector2(w, DETAIL_CHIP_H)), 4.0, Color(1.0, 1.0, 1.0, 0.05))
	Visuals.draw_item(self, at + Vector2(11.0, DETAIL_CHIP_H * 0.5), 13.0, item)
	var head: String = _chip_numeral(item, need)
	draw_string(_font, at + Vector2(DETAIL_CHIP_WELL, DETAIL_CHIP_BASE), head, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_CHIP_SIZE, Color(0.482, 0.796, 0.518) if ok else UI_WARN)
	var hw: float = _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE).x
	draw_string(_font, at + Vector2(DETAIL_CHIP_WELL + hw, DETAIL_CHIP_BASE), "/%d" % need,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE, UI_TEXT_FAINT)
	return at.x + w


# --- the bench ------------------------------------------------------------------------------------------

## BENCH: the research ladder as a graph and the verb that acts on it, on one screen.
##
## The tree used to be a separate full-screen overlay on `T` that showed the ladder you could not act
## on, because the research verb lived back inside the pack screen. Now the ladder is a tab of the same
## counter, a cursor walks it, and the selected rung is the one the plate prices and the one Enter takes.
##
## Tiers derive from each tech's `requires` chain, so a branching tree simply stacks its chips in a
## column and no layout changes. The chips are scaled to the panel rather than the panel to the chips.
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
	# One type size for the whole ladder, chosen once here rather than per chip. See `_bench_name_fs`.
	var fs: int = _bench_name_fs(chip.x)
	var rects: Dictionary = {}
	for ti: int in tiers.size():
		var tier: Array = tiers[ti]
		var col_h: float = float(tier.size()) * chip.y + float(tier.size() - 1) * gap.y
		for ni: int in tier.size():
			rects[tier[ni]] = Rect2(at + Vector2(float(ti) * (chip.x + gap.x),
				(span.y - col_h) * 0.5 + float(ni) * (chip.y + gap.y)), chip)
	# Arrows first, under the chips, from the prereq's right edge to the dependent's left edge. A path you
	# have already walked glows, so the tree reads as a route rather than as a table.
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
		_draw_tech_chip(tid, rects[tid], tid == next, tid == picked, fs)


## Where the name starts and how much of the chip is left for it. The lamp is the only other thing on
## that line, so the indent is the lamp's own right edge plus air. It used to be 15 on a narrow chip and
## 19 on a wide one, beside a dot drawn at 8 and 11 with a radius of 3.2, which is 3.8 and 4.8 of dead
## space in the one measurement the names were short of.
const BENCH_NARROW: float = 96.0      ## under this a chip tucks its lamp in against the edge
const BENCH_DOT_R: float = 3.2
const BENCH_NAME_AIR: float = 1.8     ## lamp → first letter
const BENCH_NAME_PAD: float = 4.0     ## last letter → the chip's right edge
const BENCH_NAME_FS: int = 11         ## the size a name is set at when the chip has the room
const BENCH_NAME_FS_MIN: int = 7
func _bench_dot_x(w: float) -> float:
	return 8.0 if w < BENCH_NARROW else 11.0


func _bench_indent(w: float) -> float:
	return _bench_dot_x(w) + BENCH_DOT_R + BENCH_NAME_AIR


## The ladder's one type size: the largest at which the longest name on it fits a chip. Every name on
## the board is then set at the size the worst of them can take.
##
## Each chip used to shrink its own name until it fit, and a chip only knows its own string. On the
## finished tree that printed Descent, Ironworks and Machining at 9, Prospecting and Enrichment at 8,
## and Automation and Crosscutting at 7: three sizes on one board, tracking the length of the word.
##
## Measured on the finished ladder, whose seven tiers leave a chip 66.9 wide, the longest name is
## Crosscutting at 49.0 across at size 8 against 49.9 of room. So the whole board sets at 8. Size 9 is
## not available at seven tiers, where Crosscutting asks for 55.0, and the consequence of setting from
## the longest name is that the board drops a size together the day the ladder grows a longer one.
## Uniformly small is the smaller cost: a name smaller than its neighbours reads as worth less.
func _bench_name_fs(w: float) -> int:
	var room: float = w - _bench_indent(w) - BENCH_NAME_PAD
	var fs: int = BENCH_NAME_FS
	while fs > BENCH_NAME_FS_MIN and _bench_name_w(fs) > room:
		fs -= 1
	return fs


func _bench_name_w(fs: int) -> float:
	var w: float = 0.0
	for tid: StringName in ResearchRules.ORDER:
		w = maxf(w, _font.get_string_size(str(ResearchRules.tech(tid)["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w


## One tech chip: a lamp, a name, and the machines it unlocks. Its price moved to the detail plate,
## because a chip carrying the price had to shrink the name to fit it, and a truncated name such as
## "Prospecti" costs the player more than a second glance downward does.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool, picked: bool, fs: int) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = sim.is_researched(tid)
	if picked:
		_round_rect(rr, 5.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 3.0), Vector2(2.0, rr.size.y - 6.0)), UI_ACCENT)
	elif done:
		_round_rect(rr, 5.0, Color(0.078, 0.113, 0.086))
	else:
		_round_rect(rr, 5.0, Color(1.0, 1.0, 1.0, 0.040 if is_next else 0.022))
	var name_col: Color = STATE_INK if done \
		else ((GOLD_PALE if picked else UI_TEXT) if is_next else UI_TEXT_FAINT)
	var indent: float = _bench_indent(rr.size.x)
	var room: float = rr.size.x - indent - BENCH_NAME_PAD
	draw_circle(rr.position + Vector2(_bench_dot_x(rr.size.x), 13.0), BENCH_DOT_R,
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

## A real rounded rect. Composing one from a rect plus four circles double-blends every corner the
## moment the fill is translucent, which is exactly what a modern surface tint is.
func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	# Rounded boxes are panels too. `panel_probe` used to see only `_panel()`, and the Bazaar is built
	# entirely out of these, so `check_hud_layout`'s "Bazaar open" row recorded the bare screen's four
	# panels and nothing else, and its headline claim, that the HUD must not print on top of itself, had
	# never covered the largest overlay in the game.
	if probing:
		panel_probe.append(rect)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## Rounded on the left two corners only, for the rail, flush against the panel's edge.
func _round_rect_left(rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## The focus ring: where the next keypress will land, on any control that can take the keyboard.
##
## The measurement shipped for the two cursors that had one, the counter's row and the hotbar's lit
## slot, and it left the rest of the page open, because every other traversable control loses the caret
## the moment you leave those two surfaces. This is the mark the rest of them wear.
##
## It is the idiom the two measured cursors already use rather than a third invention. The hotbar's lit
## slot swaps a 1px `UI_EDGE` border for a 2px `UI_ACCENT` one and hangs a glow outside it, an outline
## at double weight sitting off the well's own edge. That is what this draws, in the same gold family
## (`GOLD_PALE`, which is `UI_ACCENT` lifted, already the page's token for the hot one) and at the same
## 2px. The counter's spine is the other half of the idiom, and row-shaped controls keep it (`spine`).
##
## It is not a hue. The finding behind that measurement was that the game's affordance signal had been
## concentrated into one colour channel, and a focus ring that is only a colour change repeats that on a
## new surface. Three channels carry this mark, and any one of them alone would still say focus:
##
##   Shape. An unbroken ring is drawn in no other state on this page. Selection fills and hover lifts a
##   fill, while neither of them outlines, so present against absent needs no colour to read.
##
##   Weight. 2px, against the 1px every edge on the page is drawn at: the chip's keyline, the slider's
##   frame, the row plates. Twice the ink of anything it could be confused with.
##
##   Inset. It is drawn outside the control's own box, which is the one place no other state paints.
##   Focus is the only thing here that changes a control's footprint rather than its interior, so it
##   survives on a chip that is already filled gold for being on.
##
## The keyline is the fourth: one dark line immediately inside the ring, so the pale gold cannot merge
## into a light fill under it. The lamp swatches on the title card are the case that needs it, since
## there the thing being chosen is itself a colour and five bright tints would each have argued with a
## bare gold ring.
##
## `grow` is the caller's, because the clearance is the caller's. A chip has air around it and takes the
## default, while the binding rows are drawn on a 15px pitch with 15px plates and would have rung their
## neighbours, so they pass 0.0 and the ring lands on the plate's own edge.
const FOCUS_W: float = 2.0            ## the ring, at double the weight of every 1px edge near it
const FOCUS_GROW: float = 2.5         ## how far outside the control it sits, where nothing else paints
const FOCUS_KEYLINE := Color(0.0, 0.0, 0.0, 0.55)   ## one dark line inside it, so it reads on any fill
const FOCUS_SPINE_W: float = 2.0      ## the counter's mark, kept for the controls that are rows
## Far enough left of the plate that the two marks stay two marks. The ring at `grow` 0.0 straddles the
## plate's edge, half a `FOCUS_W` either side of it, so a spine parked flush against that edge merges with
## it into one thicker bar and the row loses the spine it is supposed to be carrying: 4.0 leaves 1px of
## ground between them at the weights above, and any future change to either has to be checked against
## that subtraction rather than against the picture.
const FOCUS_SPINE_DX: float = 4.0
const FOCUS_SPINE_INSET: float = 2.0  ## ...and how far short of the row's ends it stops, as the counter's


## The mark itself. See the block above the constants for why it is shaped the way it is.
func _focus_ring(box: Rect2, grow: float = FOCUS_GROW, spine: bool = false) -> void:
	draw_rect(box.grow(grow - 1.0), FOCUS_KEYLINE, false, 1.0)
	draw_rect(box.grow(grow), GOLD_PALE, false, FOCUS_W)
	if spine:
		draw_rect(Rect2(box.position.x - FOCUS_SPINE_DX, box.position.y + FOCUS_SPINE_INSET,
			FOCUS_SPINE_W, box.size.y - FOCUS_SPINE_INSET * 2.0), UI_ACCENT)


## Elevation instead of a border. A modern panel does not outline itself, it casts, and concentric
## translucent rings are the cheap honest version of that, which is what stops the counter reading as
## printed on the world behind it.
func _soft_shadow(rect: Rect2, spread: int, peak: float) -> void:
	for i: int in range(spread, 0, -1):
		var t: float = float(i) / float(spread)
		draw_rect(rect.grow(float(i)), Color(0.0, 0.0, 0.0, peak * (1.0 - t) * 0.32))


## One hairline of light along the top edge and a slow warm gradient down the plate. Those are the two
## marks that say which way the lamp is, which is the difference between a surface and a fill.
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


## What `_tracked` actually occupies: the plain width plus one gap per letter. Measuring tracked type
## with `get_string_size` is how a caption ends up printed through its own title.
func _tracked_w(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(text.length() - 1, 0))


## Darkens the frame's edges so the eye is pushed to the counter. Every modern pause screen does it, and
## this one did not, which was part of why the panel read as pasted onto a screenshot.
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


## The production dashboard, on G: the factory's whole output at a glance, so scaling is felt rather
## than guessed. Two columns, both pure sim reads. THROUGHPUT takes `production_rates()` as per-item
## /min bars, relative and absolute, sorted fastest first, with a grand total; FACTORY takes
## `machine_census()` as machines by type with a live working count. It is non-modal, a status read.
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

	# --- left column: THROUGHPUT, meaning is output growing? -------------------------------------
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
		for i: int in mini(9, rates.size()):                  # top nine, which is the panel's height budget
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

	# --- right column: FACTORY census, meaning how big and how healthy? --------------------------
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
		# The summary is green when it is true, and it used to be green unconditionally. `0 working` sat in
		# the healthy colour directly above a row flagging the same machines as stalled, and a colour that is
		# the same for every value of the number beside it is not reporting the number.
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
			# The count and the working count: green when all are running, and the alert colour when some are
			# stalled. This used to draw `UI_ACCENT`, the colour this same panel uses for its heading and its
			# grand total, so a player who had learned that gold means "selected, available, yours" was shown a
			# fault in it, two rows under a gold number meaning the opposite. The left-edge alert stack reports
			# the same machines in `UI_WARN`, and now both say it the same way.
			var cnt: int = int(row["count"])
			var wrk: int = int(row["working"])
			var stat_col: Color = Color(0.55, 0.78, 0.55) if wrk == cnt else UI_WARN
			draw_string(_font, Vector2(rx + 118.0, y2), "%d" % cnt, HORIZONTAL_ALIGNMENT_RIGHT, 24.0, 10, UI_TEXT)
			draw_string(_font, Vector2(rx + 144.0, y2), "%d▸" % wrk, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stat_col)
			y2 += 16.6


## The id of the i-th craftable, supplied explicitly by MainView as `craft_ids`, parallel to
## `craft_options`, so machines and tools can interleave without relying on `machine_icons` insertion
## order. It falls back to the old `machine_icons`-keys derivation if `craft_ids` was not set.
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = machine_icons.keys()
	return keys[i] if i < keys.size() else &""


## The CONTROLS card's measurements, hoisted out of `_draw_help_overlay` so `check_hud_layout` can
## measure it. Text is the half a panel-rect test cannot see: every line is drawn inside a fixed-width
## column and a line wider than its column spills across the card while the panel it overflows still
## reports a perfectly legal rectangle.
## Column width for the card and the number `check_hud_layout` holds every line to.
const HELP_COL_W: float = 236.0
## Text size the card is drawn at, named so the measuring code cannot drift from the drawing code.
const HELP_TEXT_SIZE: int = 11

const HELP_LINES: Array[String] = [
	"move        A / D  (or ← →)",
	"jump        W  or  SPACE",
	"climb       W / S  on a rope (not a jump)",
	"grapple     F  at ringed rock · again to ride",
	"swing       W / S reel in / out · SPACE off",
	# The three techniques the winch grew. Each is taught in place by a hint the first time you are in the
	# situation, in scenes/hints.gd, but a lesson you can only be told once is a lesson you can miss, so
	# the card carries them too, in the same key-first voice as every line above it.
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


## The help overlay, on H or the slash key: the full control list, summoned rather than stuck on
## screen, on a centred card.
func _draw_help_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.45))
	# Two columns, because one did not fit on the screen. At 16px a row this list is 25 rows and 440px tall
	# on a 360px canvas, centred, so it hung 40px off the top and 40px off the bottom, and the first and
	# last controls were simply not on screen. Splitting rather than shrinking is the right repair twice
	# over: a smaller font would have fitted the same wall of 25 rows into the same screen, and a wall of
	# rows is the thing this card should least be.
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


## The settings page, which takes the counter's grammar and keeps its own state.
##
## It shares the counter's plate, rail, head, detail plate and sizing behaviour, while `_settings_open`
## and ESC stay its own. It is not the counter's fourth face, and the reason lives in the input handlers
## rather than in proximity. `main.gd:1006` routes every event to `_settings_input` and returns. That
## total intercept is what key capture requires, because it must be able to swallow any key, while the
## counter binds the digit row and the mouse wheel to tab selection. A binding capture cannot live
## inside a tab strip. The other reason once recorded, that the counter is a place with a precondition,
## is not true: `E` sets `_inventory_open` with no proximity check, and `_near_bazaar()` gates exactly
## one field.
##
## The grid. The old page put slider bars at x0+62 and chips at x0+92: two control columns in one stack,
## 30px apart. There is now one label x, one control x and one value x.
##
## The height. The old page was a fixed 592x286 whatever it was showing. One category at a time on a
## panel that sizes to it makes FEEL barely half the height of CONTROLS.
const SET_W: float = 432.0
const SET_HEAD: float = 40.0          ## title + category name
const SET_FOOT: float = 16.0          ## the key legend
## The plate that says what the control under your hand does. It was 56, tall enough for three lines and
## never given more than one, because the CONTROLS face is the only one that puts anything else in it, and
## that is a single RESET KEYS button on the same baseline. 36 holds both with room and takes 20px off
## every page height, which is 20px less of the banner above and the hotbar below that this panel prints
## over: the settings footprint measured 47.22% of canvas, down from 50.97%.
const SET_DETAIL: float = 36.0
const SET_ROW: float = 22.0           ## an audio/feel row
const SET_MIN_H: float = 196.0
## What a rail slot is made of. Both rails stack a tile with one line of type under it and neither may
## print into the slot below, so the pitch is a clearance and not a taste: at the old 150 floor the FEEL
## page came out 186 tall, the pitch collapsed to exactly `RAIL_ICON`, and the tiles met.
##
## What the two rails do not share is the line. The settings rail writes a word there and its slot ends
## at the word's descender, while the counter's rail puts the key that selects the tab on that same line
## as a cap and a cap is taller than a word, so its slot ends where the cap's shadow does. Both floors
## are the same sentence, the slot's last mark plus air, read off each rail's own drawing. For the
## settings rail that returns 54.0, which is the number this file shipped.
const RAIL_ICON: float = 38.0         ## the tile at the top of every slot, both rails
const RAIL_LABEL_FS: int = 7          ## and the type on the line under it
const RAIL_LABEL_DY: float = 44.0     ## the settings word's baseline, below the tile
const RAIL_KEY_GAP: float = 3.0       ## cap to word, on the counter's rail
const RAIL_TEXT_AIR: float = 2.0      ## tile to the top of the type under it
const RAIL_SLOT_AIR: float = 7.0      ## a slot's last mark to the next slot's tile
const RAIL_PITCH_MAX: float = 58.0    ## a tall rail spreads its tabs no further than this
const RAIL_TOP: float = 62.0          ## where the first tile sits when the rail has the room
const RAIL_TOP_FRAC: float = 0.18     ## ...and the share of a shorter rail it takes instead
const RAIL_EDGE: float = 6.0          ## the margin no slot crosses at either end
## The shared grid, measured from the content's left edge. It is named because a layout assertion that
## re-derives them is checking its own arithmetic against itself.
const SET_CTRL_DX: float = 116.0
const SET_BAR_W: float = 116.0
const SET_VALUE_DX: float = 242.0     ## SET_CTRL_DX + SET_BAR_W + 10

const CAT_AUDIO: int = 0
const CAT_CONTROLS: int = 1
const CAT_FEEL: int = 2
const CAT_NAMES: Array[String] = ["AUDIO", "CONTROLS", "FEEL"]

## The bindings, each with the sentence its key does not tell you. A key legend that says what the key
## is for is a different document from one that says which key it is. The rows that say nothing here are
## the ones whose label already said it, such as "jump" and "map", and an empty string draws no plate
## rather than a padded restatement of the label.
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


## The page's geometry for the category that is open: the counter's `_bazaar_geometry` in every respect
## except its numbers so the two pages cannot drift into different shapes.
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
## that draws it. See `_bazaar_wanted_h`.
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


## Rows per binding column and the single source for the split. `_settings_wanted_h` asks this rather
## than re-deriving it, because a height computed from a second copy of a layout rule is right on the
## day it is written and silently wrong the day either copy moves.
func _remap_per_col() -> int:
	return int(ceil(float(REMAP_ROWS.size()) * 0.5))


## The audio levels and the feel toggles as data, so the drawing is one loop over a table and the detail
## plate has somewhere to read its sentence from.
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
	# The counter's ground rather than the old page's: a tinted scrim instead of pure black, because a
	# modal that blacks the world out reads as a different application, while one that tints it reads as a
	# screen you are on.
	var t: float = settings_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _settings_geometry()
	var origin: Vector2 = g["origin"]
	var mouse: Vector2 = Controls.pointer_viewport(self)
	var plate := Rect2(origin, Vector2(SET_W, float(g["h"])))
	# The page rises the last few pixels into place, one transform, exactly as the counter does.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)
	# Elevation, not a border. The old page was a hard-cornered rectangle with a 1px edge, while the
	# counter earned its depth from a soft shadow and a sheen, and this page gets the same two.
	_soft_shadow(plate, 12, 0.34)
	# Opaque, and the comment that earned it stays. `UI_BG` is 90% because furniture sits over the world
	# and is meant to, while a modal is not furniture: at 0.90 the objective banner read straight through
	# this page, since ten percent of a lit banner over an unlit panel is about twice the panel's value.
	_round_rect(plate, 8.0, UI_MODAL)
	_panel_sheen(plate)
	_draw_settings_rail(origin, g, mouse)
	_draw_settings_head(origin, g)
	# The plate follows the mouse, so whatever control is under your hand explains itself. With nothing
	# under it, it falls back to the category's own line, so the plate is never blank and never stale.
	var told: String = _settings_body(g, mouse)
	_draw_settings_detail(g, told, mouse)
	# What the keyboard can do here, said on the page rather than left to be found. The line named 1 2 3
	# and ESC because those were the only two keys true of the whole page: the arrows moved a cursor on one
	# of the three faces and every other control was mouse-only. They are true of all three now, and a
	# control you can focus but cannot discover is the same defect one step further in, on the page a
	# player opens precisely when their input is not doing what they expect.
	var legend: String = "arrows move   ENTER rebinds   1 2 3 category   ESC closes" \
		if settings_cat == CAT_CONTROLS \
		else "arrows move and adjust   ENTER acts   1 2 3 category   ESC closes"
	draw_string(_font, Vector2(origin.x + BAZAAR_RAIL + BAZAAR_PAD, origin.y + float(g["h"]) - 5.0),
		legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_FAINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The category rail. It shares `_rail_slots` with the counter's rail so the two cannot drift apart and
## it registers a hit per category, since the rail is how you change page with the mouse.
func _draw_settings_rail(origin: Vector2, g: Dictionary, mouse: Vector2) -> void:
	var rail := Rect2(origin, Vector2(BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, UI_RAIL)
	var ys: Array = _rail_slots(rail, CAT_NAMES.size(),
		_rail_word_slot_h() + RAIL_SLOT_AIR, _rail_word_slot_h())
	for i: int in CAT_NAMES.size():
		var y: float = ys[i]
		var on: bool = i == settings_cat
		var box := Rect2(rail.position.x + 9.0, y, RAIL_ICON, RAIL_ICON)
		if on:
			_round_rect(box, 6.0, RAIL_ON_FILL)
			draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UI_ACCENT)
		_settings_glyph(box.get_center(), i, on, box.has_point(mouse))
		# The number travels inside the word. It used to be drawn separately above the icon while the word
		# sat below it, which put every word equidistant between the icon it names and the number of the
		# next one: 47px to its own icon against 46px to the wrong number on the shipped frames, and on
		# the shortest page they landed on one baseline and the rail printed "2 AUDIO" when 2 is CONTROLS.
		# One string cannot drift away from itself at any pitch.
		var label: String = "%d %s" % [i + 1, CAT_NAMES[i]]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, RAIL_LABEL_FS).x
		draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + RAIL_LABEL_DY), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, RAIL_LABEL_FS, UI_TEXT if on else UI_TEXT_FAINT)
		_settings_hits.append({"rect": box.grow(6.0), "payload": {"cat": i}})


## The two measurements of a slot, taken off the drawing that makes them. The word clears the tile by
## the font's own ascent, which is why the counter's word sits at 48 and not at the settings rail's 44,
## and the cap is hung so its key lands on that same baseline, leaving the cap's shadow as the lowest
## mark in the slot. Every one of these is read from the font at the size the rail actually draws,
## because a metric copied into a constant stops being true when the type changes.
func _rail_word_dy() -> float:
	return RAIL_ICON + _font.get_ascent(RAIL_LABEL_FS) + RAIL_TEXT_AIR


func _rail_key_dy() -> float:
	return _rail_word_dy() - (_keycap_h(RAIL_LABEL_FS) - KEYCAP_BASE)


func _rail_key_slot_h() -> float:
	return _rail_key_dy() + _keycap_h(RAIL_LABEL_FS) + KEYCAP_DROP


func _rail_word_slot_h() -> float:
	return RAIL_LABEL_DY + _font.get_descent(RAIL_LABEL_FS)


## Where a rail's boxes sit, for a rail of any height and any number of slots. It is extracted from the
## counter's rail rather than copied into this one, because two rails computing their own pitch are two
## rails that eventually disagree.
##
## Neither measurement has a default any more. `min_pitch` used to default to 0.0 and the counter's rail
## was the caller that took the default, so the rail with the taller slot of the two was the one drawing
## without a floor. An optional argument is answered by whichever caller thought about it, which is
## never the caller that needed the answer.
##
## `slot_h` is what a slot draws below its own top, and it is here so a stack too tall for its rail
## comes back inside the panel rather than off the bottom of it: the floor clears the slot above, and
## this clears the panel's own edge. Where there is room to spare the first tile sits at `RAIL_TOP`.
func _rail_slots(rail: Rect2, n: int, min_pitch: float, slot_h: float) -> Array:
	# The floor is not cosmetic. Without one, a short page drives the pitch down to the tile's own height
	# and the boxes become contiguous. A floor above `RAIL_PITCH_MAX` wins over it, because the cap limits
	# how far a tall rail may spread while the floor is a clearance the drawing cannot do without.
	var pitch: float = maxf(min_pitch,
		minf(RAIL_PITCH_MAX, (rail.size.y - 110.0) / maxf(float(n - 1), 1.0)))
	var top: float = minf(minf(RAIL_TOP, rail.size.y * RAIL_TOP_FRAC),
		rail.size.y - RAIL_EDGE - (float(n - 1) * pitch + slot_h))
	top = maxf(top, RAIL_EDGE)
	var out: Array = []
	for i: int in n:
		out.append(rail.position.y + top + float(i) * pitch)
	return out


## Three category glyphs, drawn rather than lettered, in the counter's hand: a speaker cone with two
## arcs, a key cap, and three sliders at different settings.
##
## `hot` is a separate argument from `on` because they are separate facts, and one call site's
## `on or box.has_point(mouse)` blurred them. Under a resting pointer the rail lit two glyphs in the
## selection gold at once, and the brighter-looking one was not the page you were on: hover is where the
## hand happens to be, while gold in this file says your input is connected to the thing. The counter's
## rail (`_rail_glyph`) never had the bug, since it passes `on` alone, and the two rails share their slot
## pitch, their fill and their labels, so the odd one out was this signature. Hover keeps a cue and takes
## it out of the gold family: `UI_TEXT_DIM` is one clear value step over the unlit glyph, 6.42:1 on the
## rail against the unlit 3.82, and nowhere near the 13.60:1 of the lit one.
func _settings_glyph(at: Vector2, kind: int, on: bool, hot: bool = false) -> void:
	var col: Color = GOLD_PALE if on else (UI_TEXT_DIM if hot else Color(0.40, 0.43, 0.50))
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


## The head: what page this is and which face of it you are on. The counter's title pair exactly.
func _draw_settings_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	# The identifying word carries the contrast. This pair was the other way round, with `SETTINGS` at
	# 12.6:1 and the category at 2.0:1, so the brightest text on the page was the word that is the same on
	# all three faces and the dimmest was the only one saying which face you are looking at. A blind read
	# called it the most damaging defect on the screen: it fails at telling you what it is.
	_tracked("SETTINGS", Vector2(x, origin.y + 26.0), 15, 2.8, UI_TEXT_FAINT)
	_tracked(CAT_NAMES[settings_cat],
		Vector2(x + _tracked_w("SETTINGS", 15, 2.8) + 16.0, origin.y + 26.0), 15, 2.8, UI_TEXT)


## The open category, returning the sentence the detail plate should say, which is whatever the mouse is
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


## Named rather than fetched. `Settings` is a `class_name` of static vars, and a dynamic `get()` against
## one fails at runtime rather than at parse time, which is the wrong trade in a page four checks
## photograph.
##
## The match itself moved to `Settings` and this is the forwarder. Keyboard adjustment of a level has to
## read the level before it can move it, and that read happens in `MainView` where the mutation lives, so
## the alternative to one shared accessor was two copies of the same four names in two files, which is
## the shape of defect this page has already shipped once.
func _audio_level(id: String) -> float:
	return Settings.level(id)


## The plate follows the hand, and then the caret. `said` was set by hover alone, which is correct while
## the mouse is on the page and leaves the plate saying the category's own line for a keyboard user
## standing on a control that has a sentence written for it. The order is the one `_settings_controls`
## already argued for and had to be corrected into: hover first and unconditionally, because it is the
## more deliberate pointer, and focus fills in when nothing is hovered.
func _settings_audio(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	draw_string(_font, Vector2(c.position.x, y), "sound", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	# The mute reads as its state and never as an instruction, because a chip that says the opposite of
	# what is happening is the oldest bug in settings UI.
	#
	# The focus arm needs no `said == ""` beside it, unlike the rows below. This is the first control the
	# category draws, so nothing can have spoken yet and a test for it would be a guard that cannot be
	# false, which is the exact shape the rest of this function's history is a catalogue of.
	var mute_focused: bool = settings_row == 0
	if _settings_chip(c.position.x + SET_CTRL_DX, y, "MUTED" if Settings.muted else "SOUND ON",
			settings_row_payload(CAT_AUDIO, 0), not Settings.muted, mouse, 10, Settings.muted,
			mute_focused) or mute_focused:
		said = "silences everything at once; the levels below are kept"
	for i: int in AUDIO_ROWS.size():
		var row: Array = AUDIO_ROWS[i]
		y += SET_ROW
		var id: String = str(row[1])
		var focused: bool = settings_row == i + 1
		if _settings_slider(c.position.x, y, id, str(row[0]), _audio_level(id), mouse, focused):
			said = str(row[2])
		elif focused and said == "":
			said = str(row[2])
	return said


func _settings_feel(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	for i: int in FEEL_ROWS.size():
		var row: Array = FEEL_ROWS[i]
		var id: String = str(row[1])
		draw_string(_font, Vector2(c.position.x, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT)
		var text: String = ""
		var on: bool = false
		if id == "zoom":
			text = "%.2fx" % MainView.ZOOM_LEVELS[
				clampi(Settings.zoom_idx, 0, MainView.ZOOM_LEVELS.size() - 1)]
		else:
			on = Settings.screen_shake if id == "shake" else Settings.auto_pickup
			text = "ON" if on else "OFF"
		var focused: bool = settings_row == i
		if _settings_chip(c.position.x + SET_CTRL_DX, y, text, settings_row_payload(CAT_FEEL, i), on,
				mouse, 10, false, focused) or (focused and said == ""):
			said = str(row[2])
		y += SET_ROW
	return said


## Which bindings share a key with another and who with.
##
## `Settings.rebind` writes the new key and returns; it has never checked for a conflict. Bind `jump` to
## `W` and `W` is now `climb up` and `jump`, both fire, and nothing anywhere says so. The page shows the
## clash rather than the rebind refusing it, because refusing would overrule a deliberate choice, and
## silently unbinding the other action would be worse than either.
##
## They are compared on the label, which is what the row displays, because a clash the page draws has to
## be a clash the page can show you. `unbound` and `?` are excluded, since two actions with no key are
## not in conflict and a naive equality would call them the loudest clash on the board.
## equality would have called them the loudest clash on the board.
func _binding_clashes() -> Dictionary:
	# The population is every event of every action and it used to be neither. It compared
	# `Settings.binding_label`, which is `events[0]`, across the 22 `REMAP_ROWS`. Most actions have two or
	# three events, so a collision on any event but the first was invisible: bind something to the up arrow
	# and it silently shares with `climb up`, whose first event is W. And `Settings.rebind` scans all 25 of
	# `Controls.defaults()`, so it can displace `close`, `cycle next` or `cycle prev`, none of which have a
	# row here.
	#
	# Detecting over all 25 while displaying on the 22 is deliberate. The page owns 22 rows, but a warning
	# naming an off-page action is still true and still actionable, and silence would not be.
	var by_key: Dictionary = {}
	for act: StringName in Controls.defaults():
		for label: String in Settings.event_labels(act):
			if label == "unbound" or label == "?":
				continue
			var seen: Array = by_key.get(label, [])
			seen.append(act)
			by_key[label] = seen
	# The phrase names the colliding key, not the row's chip. Once a clash can live on an action's second
	# event, "%s is also %s" filled in with `binding_label(action)` would point at the wrong key and the
	# row would turn orange over `A` while the collision was on the left arrow. The display and the fix
	# have to be about the same event, which is why both sides share one predicate.
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


## An action's human name, from the same table the page draws. It is static because `MainView` needs it
## to say which binding a rebind just took the key from, and a second copy of these names would be a
## second place for them to go stale.
static func action_label(action: StringName) -> String:
	for row: Array in REMAP_ROWS:
		if row[0] == action:
			return str(row[1])
	return String(action)


## How many controls the open category offers the keyboard, which is the population `settings_row` is an
## index into. It was 22 and it was only ever the bindings, because the cursor existed for the binding
## list alone and every other control on this page was reachable by mouse only. That gap is what this
## closes: the levels, the toggles and RESET KEYS could not be focused at all, so there was nothing for a
## focus state to be drawn on.
##
## RESET KEYS is part of the controls list, at its end, rather than a fourth thing with its own key. It
## is drawn on the detail plate under the two columns, so arriving at it by pressing Down off the bottom
## of the second column is where it already sits on the page.
func settings_focus_count() -> int:
	match settings_cat:
		CAT_CONTROLS: return REMAP_ROWS.size() + 1        # the bindings, then RESET KEYS
		CAT_FEEL: return FEEL_ROWS.size()
		_: return AUDIO_ROWS.size() + 1                   # the mute chip, then the levels


## What one row of a category does, as the payload the click path already speaks.
##
## The keyboard and the mouse produce the same dictionary, deliberately, and this is the only place
## either of them gets it from. `_settings_audio`, `_settings_feel` and `_settings_controls` register
## these as the hit payloads, and `settings_focus_payload` returns this for the focused row, so
## `MainView._apply_setting` is one mutation path for both pointers rather than two that have to be kept
## agreeing. The page has already paid once for a page-side copy of a rule drifting from the resolver's,
## in `_binding_clashes`.
func settings_row_payload(cat: int, i: int) -> Dictionary:
	match cat:
		CAT_CONTROLS:
			if i < 0 or i >= REMAP_ROWS.size():
				return {"reset": true}
			return {"bind": String(REMAP_ROWS[i][0])}
		CAT_FEEL:
			var f: int = clampi(i, 0, FEEL_ROWS.size() - 1)
			var fid: String = str(FEEL_ROWS[f][1])
			return {"cycle": "zoom"} if fid == "zoom" else {"toggle": fid}
		_:
			if i <= 0:
				return {"toggle": "mute"}
			return {"slider": str(AUDIO_ROWS[clampi(i - 1, 0, AUDIO_ROWS.size() - 1)][1])}


## The focused control's payload. `MainView` acts on this and never on the index, so what ENTER does is
## decided by the same table that decided what a click on the same control does.
func settings_focus_payload() -> Dictionary:
	return settings_row_payload(settings_cat, settings_row)


## Move the keyboard cursor. Up and Down step within a column, while Left and Right jump a column, which
## is what the two-column layout makes them mean. It is clamped rather than wrapped, because a cursor
## that leaps from the last row to the first reads as a lost keypress.
##
## It used to refuse every category but CONTROLS, in its first two lines, which is the mechanical form of
## the same gap: on AUDIO and FEEL the arrow keys did nothing at all, so the page a player opens when
## their input is not working had four levels and three toggles that only a mouse could reach.
##
## The column jump is the one thing that stays category-shaped. AUDIO and FEEL are single columns, so
## there is no column to jump to and the step is 0. `MainView` reads Left and Right on those faces as an
## adjustment to the focused control instead, and only falls back here when the control has nothing to
## adjust. One rule, and it never has to guess: a slider and a cycle move, everything else steps.
func move_settings_row(keycode: int) -> void:
	var step: int = _remap_per_col() if settings_cat == CAT_CONTROLS else 0
	match keycode:
		KEY_UP: settings_row -= 1
		KEY_DOWN: settings_row += 1
		KEY_LEFT: settings_row -= step
		KEY_RIGHT: settings_row += step
	settings_row = clampi(settings_row, 0, settings_focus_count() - 1)


## The action under the keyboard cursor, or &"" when the cursor is not on a binding list. That now also
## covers the last CONTROLS index, RESET KEYS, since that is a control and not a binding. The guard was
## already written as a range test rather than a category test, so it held the day the list grew a tail.
func settings_row_action() -> StringName:
	if settings_cat != CAT_CONTROLS or settings_row < 0 or settings_row >= REMAP_ROWS.size():
		return &""
	return REMAP_ROWS[settings_row][0]


## The bindings: two columns of eleven, each row a label and the key that does it. The capture state is
## on the row that is capturing, "press a key…", rather than in a sentence at the bottom of the page
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
		var plate := Rect2(x - 4.0, y - 11.0, col_w + 8.0, 15.0)
		if lit or capturing or cursor:
			# The whole row lights, not just the chip, because the row is the thing you are choosing, and
			# that is what makes the plate below it read as being about something.
			_round_rect(plate, 3.0, Color(0.145, 0.129, 0.082))
		# The keyboard cursor is not the hover and must not look like it. Hover is a warm fill under
		# whatever the mouse happens to be over, while focus is a claim about where the next keypress will
		# land, and it persists with no pointer anywhere near it. So focus gets the rail's own gold edge
		# bar, the mark this UI already uses for the selected one, and the two can coexist on different
		# rows without either being ambiguous.
		#
		# The spine is only half of that now. It was the whole mark while the binding list was the only
		# thing on this page a keyboard could reach, and now that the levels, the toggles and RESET wear a
		# ring, a row that wore only a spine would be the one focused control on the page saying it
		# differently. The ring goes on the row's own plate edge rather than outside it, since these rows
		# are drawn on a 15px pitch with 15px plates and there is no outside to draw in. The spine stays,
		# because it is the counter's mark for a cursor sitting on a row and this is one.
		if cursor:
			_focus_ring(plate, 0.0, true)
		# The mouse wins when it is on a row, because it is the more deliberate pointer, and the keyboard
		# cursor speaks when nothing is hovered, so the plate always describes the thing that would act.
		#
		# That sentence was here while the code did the opposite. The whole block sat under `if cursor:`,
		# so `said` was set only for the row the keyboard cursor was parked on, and hovering a row with
		# the mouse produced no plate text at all, which made the clash message unreachable by mouse.
		#
		# `lit` is checked first and unconditionally, and `cursor` fills in when nothing is hovered. The
		# old `elif lit or said == "":` could not be false either, since exactly one row is the cursor row
		# and `said` is still empty when it is reached.
		if lit or (cursor and said == ""):
			if capturing:
				said = "press any key to bind it — ESC cancels"
			elif not clash.is_empty():
				said = " and ".join(clash)
			else:
				said = str(row[2]) if str(row[2]) != "" else "%s — press Enter to rebind" % str(row[1])
		draw_string(_font, Vector2(x, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT if (lit or capturing) else UI_TEXT_DIM)
		# A clashing key is not a selected one, so it does not get the gold. It gets the warn colour the
		# stalled-machine alerts use, which is the only other thing in this UI meaning "this will not do what
		# you think". Dark type on both, because light grey on either is unreadable.
		var fill: Color = UI_ACCENT if capturing else (
			UI_WARN if not clash.is_empty() else (Color(0.30, 0.34, 0.44) if lit else UI_SLOT))
		draw_rect(chip, fill)
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(chip.position.x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.10, 0.10, 0.12) if (capturing or not clash.is_empty()) else UI_TEXT)
		_settings_hits.append({"rect": chip, "payload": settings_row_payload(CAT_CONTROLS, i)})
	# The tail of the list is RESET KEYS, which is drawn on the detail plate below and therefore cannot
	# describe itself the way a row does, since the plate is written before the chip on it is. Its sentence
	# is said here where the rest of the category's are, so a caret parked on it is not sitting over the
	# page's generic line with no idea what ENTER is about to do to twenty-two bindings.
	if settings_row >= REMAP_ROWS.size() and said == "":
		said = "puts every binding back to its default"
	return said


## The detail plate. The counter's answer to twenty-two rows of equal weight was to make the selected
## thing large, say what it is for, and put the verb on a real button. A key binding wants that more
## than a machine does, because the row `grapple  F` tells a first-timer nothing whatever.
func _draw_settings_detail(g: Dictionary, said: String, mouse: Vector2) -> void:
	var d: Rect2 = g["detail"]
	_round_rect(d, 5.0, Color(0.0, 0.0, 0.0, 0.22))
	var line: String = said
	if line == "":
		line = CATEGORY_LINE[settings_cat]
	# Wrapped by hand at the plate's width, since `draw_string` will not wrap, and a sentence that runs off
	# a plate is the defect this page was opened to fix.
	var y: float = d.position.y + 20.0
	for part: String in _wrap(line, d.size.x - 24.0, 10):
		draw_string(_font, Vector2(d.position.x + 12.0, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UI_TEXT if said != "" else UI_TEXT_FAINT)
		y += 13.0
	if settings_cat == CAT_CONTROLS:
		var w: float = _font.get_string_size("RESET KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0
		_settings_chip(d.end.x - w, d.end.y - 8.0, "RESET KEYS",
			settings_row_payload(CAT_CONTROLS, REMAP_ROWS.size()), false, mouse, 9, false,
			settings_row >= REMAP_ROWS.size())


## What each category says when your hand is not on anything: the page describing itself rather than
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


## One level, with its label, bar and percentage all on the shared grid. It returns whether the mouse is
## on it so the caller can hand its sentence to the detail plate.
##
## `focused` is the keyboard's claim on it, a third state beside `hot` and the level itself. The bar
## already had two hover marks, a lifted frame and a pale cap, and neither of them can say that the next
## keypress moves this particular level. Hover is wherever the hand happens to be resting and vanishes
## when it leaves, while focus persists with no pointer on the page at all.
func _settings_slider(x0: float, y: float, id: String, label: String, value: float,
		mouse: Vector2, focused: bool = false) -> bool:
	var bar := Rect2(x0 + SET_CTRL_DX, y - 9.0, SET_BAR_W, 10.0)
	_slider_rects[id] = bar
	var hot: bool = bar.grow(4.0).has_point(mouse)
	# Dimmed while muted. The levels are still yours and still remembered, but nothing they say is audible,
	# and a bright slider over a silent game is the page lying about which control is in charge.
	draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UI_TEXT_DIM if Settings.muted else UI_TEXT)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y))
	draw_rect(fill, Color(UI_ACCENT, 0.55) if Settings.muted else UI_ACCENT)
	# The travelled end gets a bright cap rather than the bar getting brighter, because a long gold fill
	# reads as a progress meter and a meter is a thing you watch rather than a thing you drag.
	#
	# Frame first, then the handle. Drawn the other way round the frame overprints the handle where it
	# crosses the bar, and a cap standing 2px proud top and bottom renders as three disconnected pieces: a
	# nub, a sliver, a nub. That reads as a rendering fault rather than as something to drag.
	draw_rect(bar, UI_EDGE_HI if hot else UI_EDGE, false, 1.0)
	if value > 0.0:
		draw_rect(Rect2(fill.end.x - 2.0, bar.position.y - 2.0, 2.5, bar.size.y + 4.0),
			GOLD_PALE if hot else Color(0.80, 0.83, 0.89))
	draw_string(_font, Vector2(x0 + SET_VALUE_DX, y), "%d%%" % int(round(value * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT if (hot or focused) else UI_TEXT_DIM)
	# Outside the cap as well as outside the bar. The travelled end stands 2px proud of the frame top and
	# bottom, so a ring at the default clearance would have crossed it and read as the rendering fault the
	# cap was reshaped to avoid. The extra 2px puts the ring clear of both.
	if focused:
		_focus_ring(bar.grow(2.0))
	_settings_hits.append({"rect": bar.grow(3.0), "payload": {"slider": id}})
	return hot


## One chip. It returns whether the mouse is on it, for the same reason the slider does.
##
## `warn` is a third state, and it exists because two were not enough. `UI_ACCENT` is spoken for one
## line from its definition, so a chip filled with it asserts that the thing it names is on. The mute
## chip passed `Settings.muted` as `active`, which lit the loudest element on the AUDIO page gold
## precisely when the audio was off. Flipping it to `not muted` alone would be wrong the other way,
## since muted would then read as merely unselected, and silence the player did not intend is worth
## noticing. Warm-on-dark says suppressed without claiming chosen.
##
## `focused` is a fourth state, orthogonal to the other three rather than another value of them. A chip
## can be on, hovered and focused at once and has to say all three. `active` fills it gold, `hot` lifts
## the unfilled fill and `warn` paints it warm-on-dark, all three of them changes to the chip's interior,
## while focus rings it from the outside, which is why the gold fill of an engaged toggle cannot swallow
## it. That separation is the point: if focus and selection drew the same mark, a keyboard user could not
## tell the toggle they are standing on from the toggle that is switched on.
func _settings_chip(x: float, y: float, text: String, payload: Dictionary, active: bool,
		mouse: Vector2, size: int = 10, warn: bool = false, focused: bool = false) -> bool:
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
	if focused:
		_focus_ring(chip)
	_settings_hits.append({"rect": chip, "payload": payload})
	return hot


## Move to a category. It is named like `set_bazaar_tab` and for the same reason: the page owns which
## face it is showing and `main.gd` asks for a change rather than pushing the field every frame.
##
## The cursor comes with it. The three faces offer 5, 23 and 3 controls, so an index that was legal on
## CONTROLS is off the end of both the others, and an out-of-range cursor is not cosmetic here. It is a
## focus ring drawn on nothing, on the page whose whole job is saying where the keyboard is. Clamped
## rather than reset, so switching away and back on a short page leaves you near where you were.
func set_settings_cat(cat: int) -> void:
	settings_cat = clampi(cat, 0, CAT_NAMES.size() - 1)
	settings_row = clampi(settings_row, 0, settings_focus_count() - 1)



## The control payload under a canvas point, or {} for none. Sliders add the clicked fraction, so a
## single press already sets the value and a drag then refines it via `settings_slider_frac`.
func settings_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _settings_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			var payload: Dictionary = (hit["payload"] as Dictionary).duplicate()
			if payload.has("slider"):
				payload["frac"] = settings_slider_frac(str(payload["slider"]), canvas_pos.x)
			return payload
	return {}


## Fraction along a slider's bar for a canvas x, used by click and by drag alike, since MainView keeps
## updating through mouse motion while the button stays down, even if the cursor drifts off the bar.
func settings_slider_frac(id: String, canvas_x: float) -> float:
	var bar: Rect2 = _slider_rects.get(id, Rect2())
	if bar.size.x <= 0.0:
		return 0.0
	return clampf((canvas_x - bar.position.x) / bar.size.x, 0.0, 1.0)


## A tiny dim hint, bottom-left, listing the toggle keys. It tells the player the menus exist without an
## always-on keyboard-reference footer hogging the whole bottom edge.
##
## It retires itself, one key at a time, and that is the point. The charge against this line was never
## that it is ugly at 10px and dim, but that it is permanent. A reference card that never leaves says
## the game expects you never to learn it, and it sits in the corner of every screenshot. So each entry
## disappears the first time you press that key, and when the last one goes the line goes with it.
##
## It is deliberately not written to the save. Which keys a player has pressed is not world state. It is
## a teaching aid whose cost of being wrong is one dim line for four seconds.
const HINT_KEYS: Array = [
	[Controls.GRAPPLE, "F hook"], [Controls.DROP, "Q drop"], [Controls.CRAFT, "E pack"],
	[Controls.MAP, "M map"], [Controls.HELP, "H keys"],
]

var _hint_used: Dictionary = {}          ## action -> true, once the player has pressed it


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
		return                            # everything here has been used, so the line has finished its job
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "   ·   ".join(parts),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)


func _can_afford(cost: Dictionary) -> bool:
	for item: StringName in cost:
		if int(sim.inventory.get(item, 0)) < int(cost[item]):
			return false
	return true


## The carried pack as a hotbar of slots, icon and count, centred along the bottom. The active slot,
## which the mouse wheel cycles, is highlighted and it is the one the world verbs act with. It reads
## `sim.inventory_slots()`.
func _draw_inventory() -> void:
	# The big map is the screen, the same rule as the goal plate and decided there for the same reason.
	# The map's panel runs y 41..319 of a 360 canvas, this bar's backing starts at y=295, and the map draws
	# second, so the bar was not overlapped but buried: rows 319..339 poked out below the map's edge, which
	# is exactly where each slot's count badge sits, so every count stayed legible while every icon it
	# counts was cut in half. It stands down rather than nudging the map, because the map is the one screen
	# purely for reading the world. M puts it back.
	if minimap_large:
		return
	var slots: Array[Dictionary] = sim.inventory_slots()
	# Show only the slots you actually carry, not a fixed row of empty wells, because a trailing empty slot
	# reads as "broken, what goes here?". The bar grows and shrinks with your pack, with a floor of 1.
	var n: int = clampi(slots.size(), 1, FactorySim.INVENTORY_SLOTS)
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	# The bar is a window onto the pack, not the pack. `inventory_slots()` has no cap: it returns one entry
	# per item type, and the type universe is 20 machines plus 16 materials plus the crafted intermediates,
	# while this bar is capped at ten and `clampi` used to swallow the difference in silence. Carrying
	# eleven types drew ten wells and said nothing about the eleventh. Worse, `_cycle_inventory` wraps
	# modulo the full count, so the wheel walks the selection to index 10+ where the loop below never
	# reaches it, leaving no lit well anywhere on the bar. The name plate, whose guard is
	# `sel < slots.size()` and not `sel < n`, was still drawn at the selection's arithmetic position, off
	# the right end of the bar and eventually off the canvas. It is reachable on frame one of a dev start,
	# where the dev kit is ten types and the starter pickaxe is an eleventh. So the window is placed to
	# contain the selection instead of assuming it does, centred and derived purely from `sel`.
	var w0: int = clampi(sel - n / 2, 0, maxi(slots.size() - n, 0))
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = HOTBAR_BAND_TOP + 7.0            # the band is the definition; the well row sits inside it
	# A clean framed backing just for the hotbar, since the craft strip that used to share this panel now
	# lives in the E screen. It keeps the bar reading as one deliberate unit rather than as floating slots.
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
		# A faint keybind number in the slot corner, so the hotbar reads as keyed, and only where a key really
		# exists. The row is 1-9 then 0 for the tenth, so the tenth well said "10" for a key nobody has and
		# once the window can scroll, `k + 1` would relabel whichever items happen to be on screen. The digit
		# follows the pack index and stops when the keys do, staying blank rather than lying.
		if i < 10:
			draw_string(_font, slot_rect.position + Vector2(2.0, 9.0), "0" if i == 9 else str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_FAINT)
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
					# The same glyph the world draws, from the shared Visuals, scaled to the chip, so it never drifts.
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
	# The pack continues that way, so a chevron marks whichever end has more pack behind it. It is
	# deliberately a mark and not a count, because the number of types you carry is the pack screen's job,
	# and a bar that starts reporting totals is on its way to being a second inventory. It only says "not
	# all of it is here", which is the fact the bar was concealing.
	if w0 > 0:
		_more_mark(Vector2(backing.position.x - 5.0, y + SLOT * 0.5), -1.0)
	if w0 + n < slots.size():
		_more_mark(Vector2(backing.end.x + 5.0, y + SLOT * 0.5), 1.0)
	# Name the selected item just above the bar, so the coloured chips stop being mystery squares.
	var label_rect := Rect2()
	if sel >= w0 and sel < mini(w0 + n, slots.size()):
		var label: String = _item_label(slots[sel]["item"])
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var lx: float = x0 + float(sel - w0) * (SLOT + SLOT_GAP) + (SLOT - lw) * 0.5
		var ly: float = y - 12.0
		var plate := Rect2(lx - 5.0, ly - 11.0, lw + 10.0, 15.0)
		draw_rect(plate, Color(0.05, 0.06, 0.09, 0.88))
		# The name of the selected item, not the selection. The slot already carries a gold border and a gold
		# glow and a third gold on the same object is emphasis competing with itself.
		draw_string(_font, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
		label_rect = plate
	if probing:
		hotbar_probe = {"carried": slots.size(), "wells": wells, "sel": sel, "sel_lit": sel_lit,
			"window": w0, "backing": backing, "label": label_rect}


## "There is more pack this way." A chevron pointing outward from the end of the hotbar, drawn only when
## the window is hiding something in that direction. It is dim on purpose, since it hints that the bar
## is a view rather than a control and nothing about it is clickable.
func _more_mark(at: Vector2, dir: float) -> void:
	var col := Color(UI_TEXT_DIM.r, UI_TEXT_DIM.g, UI_TEXT_DIM.b, 0.55)
	draw_line(at + Vector2(-3.0 * dir, -5.0), at + Vector2(2.0 * dir, 0.0), col, 1.5)
	draw_line(at + Vector2(2.0 * dir, 0.0), at + Vector2(-3.0 * dir, 5.0), col, 1.5)


## The hovered slot's tooltip: the item's name, the count you hold, and one purpose line, which answers
## what this is for where the question is asked. It is captured by the hotbar and pack-grid slot loops
## this frame and drawn last, above every panel, clamped on-canvas above the hovered slot.
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
	# A spine rather than a cap and no longer gold, because a tooltip describes what the cursor is over,
	# which is `active` and not the thing a keystroke acts on. `UI_EDGE_HI` keeps the edge without the verb.
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), Color(UI_EDGE_HI, 1.0))
	draw_string(_font, origin + Vector2(9.0, 15.0), name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	if purpose != "":
		draw_multiline_string(_font, origin + Vector2(9.0, 29.0), purpose,
			HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.78, 0.74, 0.62))


## Human-readable name for a carried item. A machine item uses its def's display name, such as Forge or
## Drill, and a resource its capitalised id, so ore becomes "Ore".
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
