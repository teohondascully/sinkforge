class_name BazaarPage
extends BazaarSurface

## THE COUNTER'S PAGES, WHICH ARE NOT THE COUNTER.
##
## `Hud` owns the Bazaar's shell: when it is open, how tall it has eased to, which tab is selected, and
## what the focused row does. This owns what the tabs DRAW. The two change for different reasons -- a
## new tab is a shell edit, a new row on the bench is a page edit -- and the shell is the part that has
## to keep working while the pages move here one at a time.
##
## It starts with the bench because the bench is the loosest of the five clusters the Bazaar decomposes
## into: nine functions that reach outside themselves for a canvas, a font, the sim, the icon table and
## one id. Works, the rail, the pack and the detail plate follow into this file, in that order, because
## the detail plate is the hub every other cluster calls and it has to move last.
##
## Nothing here calls back into `Hud`. That is the property worth keeping while the rest arrives: the
## shell may call in, and this may not call out, so no slice has to unpick a cycle a previous one made.

## The canvas, the font and the probe come from `PageSurface`, along with the eleven helpers that
## bind them onto the primitives in `Visuals` and `UiTheme`.
var _inv_selected: Callable                 ## `Hud.inv_selected_getter`, set from outside the Hud
## Near a claimed Bazaar. The Hud owns it because `main.gd` writes it and `tools/capture_moments.gd`
## reads it there; the accessor copies it in, the same way `probing` arrives.
## The height the counter has eased to. The Hud owns the easing because its `_process` runs it and
## `tools/check_hud_layout.gd` reads it there; the accessor hands the settled value across.
var _bazaar_h: float = BAZAAR_SIZE.y

## The bench tab, which draws itself. Bound the same way the Hud binds this page: the shell owns the
## instance and hands it the surface and the sim, and it never reaches back.
var _bench: BazaarBench = BazaarBench.new()

## The pack tab, on the same terms.
var _pack: BazaarPack = BazaarPack.new()

## The hovered-thing tooltip. The pack tab and the hotbar both set it and the Hud draws it. The pack owns
## the state now that it is a file of its own, and this page keeps a property of each name so that the
## Hud's three -- which forward to these -- did not have to learn where it went.
var _tooltip_item: StringName:
	get: return _pack._tooltip_item
	set(v): _pack._tooltip_item = v
var _tooltip_count: int:
	get: return _pack._tooltip_count
	set(v): _pack._tooltip_count = v
var _tooltip_anchor: Vector2:   ## top-centre of the hovered slot
	get: return _pack._tooltip_anchor
	set(v): _pack._tooltip_anchor = v

var can_craft: bool = false

## Measured once per item and kept. The sentences are `const`, the column derives from constants and the
## font, and neither moves while the game is running, so there is nothing for this to go stale against.
## The alternative is re-shaping every carried sentence on every frame the pack is open.
var _blurb_lines_memo: Dictionary = {}


# ------------------------------------------------------------------------------------------------
# THE COUNTER'S MODEL: what is on offer, what the cursor is on, and what pressing it would do.
#
# None of this draws. It is the same split `SettingsPage` keeps -- data and pure resolvers above, the
# drawing below -- and it is the half that decides whether a row exists, whether you can afford it, and
# which of the three tabs is showing. That is the part most likely to be wrong and least visible in a
# screenshot, so it is the part worth being able to call without a running game.
#
# It moved before the works, rail and pack drawing rather than after, because those tabs read this state
# on nearly every line. Extracting a tab first would have meant threading eleven things through it.

const BAZAAR_COLS: int = 3


const TAB_PACK: int = 0

const TAB_WORKS: int = 1

const TAB_BENCH: int = 2

const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]

## The ink for a short row with the cursor on it. Affordability and the cursor are orthogonal, so there
## are four combinations and not three. The name colour read `(gold if selected else UiTheme.UI_TEXT) if afford
## else grey`, with the test on `afford` outermost, so it swallowed the test on `selected` whole. A
## short row drew the same grey whether or not the cursor was on it while `if selected:` still lifted
## the plate and hung a gold spine off its left edge. That put the row being read at 3.74:1 against its
## own plate.
##
## The unselected short row moved off its own literal at the same time. `Color(0.48, 0.50, 0.56)` read
## 4.44:1 on the plain row fill, under the 4.5 this repository holds named inks to. The faint rung reads
## 5.05:1 and sits 74 steps below `UiTheme.UI_TEXT`, so the row still says "you cannot afford this" at a glance.
##
## The lift is the ramp's own step. `UiTheme.UI_TEXT_DIM` is `UiTheme.UI_TEXT_FAINT` plus exactly 0.04 on every channel,
## so one more of that unit lands the selected short row at 5.51:1 against the 5.05:1 it reads
## unselected. `UiTheme.UI_TEXT_DIM` itself measured 4.86:1: over the floor but under the unselected figure,
## which is the same inversion in miniature. It is written as the gap between the two named rungs rather
## than as `0.04`, which would be a literal equal to a difference nothing in the file relates it to.
##
## Ratios are WCAG relative luminance with channels linearised before weighing, per
## `tools/check_text_contrast.gd`. They are not the gamma-encoded Y709 quoted beside them for the plates.
const SHORT_SELECTED := Color(
	UiTheme.UI_TEXT_DIM.r + (UiTheme.UI_TEXT_DIM.r - UiTheme.UI_TEXT_FAINT.r),
	UiTheme.UI_TEXT_DIM.g + (UiTheme.UI_TEXT_DIM.g - UiTheme.UI_TEXT_FAINT.g),
	UiTheme.UI_TEXT_DIM.b + (UiTheme.UI_TEXT_DIM.b - UiTheme.UI_TEXT_FAINT.b))

const BAZAAR_GUTTER: float = 10.0

## Three columns of eight is twenty-four rows, not the 22 a two-column layout needed, so the row can
## afford the two pixels back and the type can breathe.
const BAZAAR_ROW_H: float = 24.0






const DETAIL_ART: float = 68.0        ## the lit square a thing on sale is drawn in
const DETAIL_GLYPH_INSET: float = 12.0  ## square edge to the thing in it
const DETAIL_LAMP_STEP: float = 8.0 / (DETAIL_ART * 0.5)

const DETAIL_TAIL: float = 8.0        ## last baseline to the bottom of the plate

## The horizontal furniture the text column is bought out of: the square's right edge to the first
## letter, and the last letter to the margin the verb button keeps. Both were repeated literals at the
## two plates that draw a blurb, which is how the hold plate came to wrap against a 260 that sums to
## nothing.
const DETAIL_TEXT_GAP: float = 14.0

## THE DETAIL PLATE'S OWN MEASUREMENTS. Thirty-three constants that no other tab reads, which is the
## measured reason they travel with it rather than sitting in a shared table.

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

const BAZAAR_DETAIL: float = DETAIL_PAD * 2.0 + DETAIL_ART

## The lamp's rings and the thing inside them are sized off the square rather than written down, because
## the square is no longer one size. An 8px step off a 34px radius spills over the edge of a compact
## plate's square, and a 44px glyph would swallow the rim the lamp needs to read against.
## Ring to ring, as a share of the square's radius rather than the 8px it is at the full depth.
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

const DETAIL_BLURB_SIZE: int = 9      ## and the size it is set at, which is what makes the pitch measurable

## Where the fact under the blurb sits when the plate is at its floor, which is the sum the floor is
## written as. The plates take it off their own bottom edge instead, so a plate that grew a line carries
## the fact down with it rather than printing it through the blurb's last row.
const DETAIL_LINE: float = 12.0       ## reserved per blurb line
const DETAIL_FACT_Y: float = DETAIL_BLURB_Y + DETAIL_LINE * DETAIL_BLURB_LINES

const BAZAAR_DETAIL_MIN: float = DETAIL_FACT_Y + DETAIL_TAIL

const DETAIL_TEXT_RIGHT: float = 24.0

## The pack plate's verb and its key, named because the column's width is measured off the button and
## the button is drawn from the same pair. A second copy of the word would be a width that stops
## matching the button the day the word changes.
const HOLD_VERB: String = "HOLD"

const HOLD_KEY: String = "ENTER"

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

const STATE_TICK: float = 9.0         ## the mark's width

const STATE_GAP: float = 6.0          ## mark → word

## The one word on the row that says which way the numbers point, named because the row measures it and
## draws it from the same string. Every other numeral on this counter is a price for the thing named
## beside it. These are one item's line in somebody else's price, and without the lead-in the row is a
## rebus.
const DEMAND_LEAD: String = "wanted by"

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

## THE COUNTER'S OWN FRAME: the head, the foot and the height it eases to.

const BAZAAR_HEAD: float = 48.0       ## title + the carried-goods strip, with air under it

const BAZAAR_FOOT: float = 16.0       ## the key legend

const BAZAAR_DETAIL_GAP: float = 8.0  ## rows to plate: the body's one gap, named once for its three sites

## Head, one row of pack wells, the gap, the detail plate and the foot, added up rather than written
## down. It was a 196 sitting beside that same sentence, which sums to 206.
##
## The plate term is the compact one, because this is PACK's floor and PACK never draws the other. A
## floor carrying the taller plate would sit 16px above where a fresh pack's own sum lands, and
## `check_pack_layout` asserts that a fresh pack lands on this floor rather than being caught by it.
const BAZAAR_MIN_H: float = BAZAAR_HEAD + PACK_CELL + BAZAAR_DETAIL_GAP + BAZAAR_DETAIL_MIN + BAZAAR_FOOT


## The counter's own state. `Hud` keeps a property of each name forwarding here, because `scenes/main.gd`
## and six tools have always read them there.
var bazaar_tab: int = TAB_PACK
var bazaar_row: int = 0
var craft_ids: Array[StringName] = []
var craft_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
var rack_options: Array[Dictionary] = []
var _bazaar_rows: PackedInt32Array = PackedInt32Array()
var _bazaar_t: float = 0.0            ## 0..1 open ease, driven in _process



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


## The id of the i-th craftable, supplied explicitly by MainView as `craft_ids`, parallel to
## `craft_options`, so machines and tools can interleave without relying on `_icons` insertion
## order. It falls back to the old `_icons`-keys derivation if `craft_ids` was not set.
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = _icons.keys()
	return keys[i] if i < keys.size() else &""


## The fewest rows at which the two WORKS lists fit the counter's columns, asked of `works_columns`
## itself so the squeeze rule and this measure cannot disagree. Fresh, machines 4 and rack 6 fit in
## three columns at four rows. With the full tech tree, machines 19 and rack 7, it wants ten rows, which
## asks for more height than the counter has and is clamped.
func _works_rows_needed() -> int:
	for r: int in range(1, 25):
		if int(works_demand(r)["total"]) <= BAZAAR_COLS:
			return r
	return 24


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
			return _sim.inventory_slots().size()


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
			var slots: Array[Dictionary] = _sim.inventory_slots()
			if i < 0 or i >= slots.size():
				return {}
			return {"kind": "hold", "id": slots[i]["item"], "row": i}


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
	# against the count the tab has now. `bazaar_row_count()` reads the _sim on two of the three tabs, so a
	# HUD without one keeps the old behaviour of landing at the top rather than reaching through a null.
	var n: int = bazaar_row_count() if _sim != null else 0
	bazaar_row = clampi(_bazaar_rows[want], 0, maxi(n - 1, 0))
	_bazaar_rows[want] = bazaar_row


## Ease-out cubic. The counter's rise reads as arriving because it slows down at the end.
func _bazaar_ease() -> float:
	var u: float = 1.0 - _bazaar_t
	return 1.0 - u * u * u


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


# ------------------------------------------------------------------------------------------------
# THE PAGES AS THEY ARE DRAWN.

## The two primitives the bench reaches for, mirrored with the canvas this page was handed.


func _detail_glyph(art: Rect2) -> Rect2:
	return art.grow(-DETAIL_GLYPH_INSET)


## A tech has no glyph of its own, being knowledge, so its plate shows what it buys: the machines it
## unlocks, laid out big. That is also the honest answer to "why would I research this".
func _draw_tech_art(tid: StringName, art: Rect2) -> void:
	var unlocks: Array = ResearchRules.tech(tid).get("unlocks", [])
	if unlocks.is_empty():
		Visuals.draw_item(_canvas, art.get_center(), 40.0, &"ingot")
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
		var dim: Color = UiTheme.UI_TEXT_DIM
		var y: float = content.end.y - 2.0
		var head: String = "%d more wait behind research" % hidden
		_canvas.draw_string(_font, Vector2(content.position.x + 1.0, y), head,
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x, 9, dim)
		var x: float = content.position.x + 1.0 \
			+ _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
		x += _keycap(Vector2(x, y - 10.0), "3", 8) + 5.0
		_canvas.draw_string(_font, Vector2(x, y), "BENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)


## One group: a list poured down as many columns as it needs, left to right. `base` is where the group
## starts in the panel's flat cursor index, so the highlight and `bazaar_action()` cannot disagree.
func _works_group(content: Rect2, col0: int, cols: int, col_w: float, rows: int, title: String,
		opts: Array[Dictionary], open_rows: Array[int], base: int, machines: bool) -> void:
	var x0: float = content.position.x + float(col0) * (col_w + BAZAAR_GUTTER)
	# MACHINES / THE RACK are labels, in the grey ramp for the reason written at `GOLD_DIM`. This is the
	# site where the gold rung was doing the most damage: a dimmed cut of the affordance colour, standing
	# directly over rows where dim genuinely means you cannot afford the thing.
	_tracked(title, Vector2(x0 + 1.0, content.position.y - 6.0), 8, 2.0, UiTheme.UI_TEXT_DIM)
	if open_rows.is_empty():
		_canvas.draw_string(_font, Vector2(x0 + 1.0, content.position.y + 16.0), "(nothing unlocked yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.UI_TEXT_DIM)
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


## One row, drawn as a card and not as an outlined box: a surface tint you can see through to the panel,
## a well for the glyph and a brass edge with a warmer fill when the cursor is on it. Nothing is
## outlined, because an outline around every row makes every row shout and the selected one shout no
## louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = BazaarCosts.can_afford(_sim.inventory, opt["cost"])
	if selected:
		_round_rect(rr, 4.0, Color(0.176, 0.153, 0.098))
		_canvas.draw_rect(Rect2(rr.position + Vector2(0.0, 2.0), Vector2(2.0, rr.size.y - 4.0)), UiTheme.UI_ACCENT)
	else:
		_round_rect(rr, 4.0, Color(1.0, 1.0, 1.0, 0.030))
	_draw_thing_icon(id, Rect2(rr.position + Vector2(6.0, 2.5), Vector2(16.0, 16.0)))
	var name_col: Color = (UiTheme.GOLD_PALE if selected else UiTheme.UI_TEXT) if afford \
		else (SHORT_SELECTED if selected else UiTheme.UI_TEXT_FAINT)
	var cw: float = _cost_glyphs(rr, opt["cost"])
	_canvas.draw_string(_font, rr.position + Vector2(26.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 36.0 - cw, 10, name_col)


func _works_id(machines: bool, i: int) -> StringName:
	if machines:
		return _craft_id(i)
	return rack_ids[i] if i < rack_ids.size() else &""


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
	var order: Array[StringName] = BazaarCosts.order(_sim.inventory, cost)
	var w: float = 0.0
	for item: StringName in order:
		w += 12.0 + _font.get_string_size(_cost_numeral(item, int(cost[item])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	var x: float = rr.end.x - 5.0 - w
	for item: StringName in order:
		var label: String = _cost_numeral(item, int(cost[item]))
		Visuals.draw_item(_canvas, Vector2(x + 6.0, rr.position.y + 10.5), 12.0, item)
		# The ink reads the sign rather than asking the pack a second time. `have < need` written out twice,
		# three lines apart, is how the mark and the colour start disagreeing about one ingredient, and
		# disagreeing is worse than either cue missing, because each reader sees only one of them.
		_canvas.draw_string(_font, Vector2(x + 13.0, rr.position.y + 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			UiTheme.UI_WARN if label.begins_with("-") else Color(0.482, 0.796, 0.518))
		x += 12.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
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
	var rail := Rect2(origin, Vector2(UiTheme.BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, UiTheme.UI_RAIL)
	# The rail's pitch follows the panel, and the arithmetic that makes it follow lives in `_rail_slots`,
	# shared with the settings rail. At full height these are the numbers they always were, top 62, and on
	# a short counter the slots close up to their floor rather than into each other.
	var ys: Array = _rail_slots(rail, 3, _rail_key_slot_h() + UiTheme.RAIL_SLOT_AIR, _rail_key_slot_h())
	for i: int in 3:
		var y: float = ys[i]
		var on: bool = i == bazaar_tab
		var box := Rect2(rail.position.x + 9.0, y, UiTheme.RAIL_ICON, UiTheme.RAIL_ICON)
		if on:
			_round_rect(box, 6.0, UiTheme.RAIL_ON_FILL)
			_canvas.draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UiTheme.UI_ACCENT)
		_rail_glyph(box.get_center(), i, on)
		# The cap and the word are one thing, laid out and centred as one. The key belongs to the name it
		# selects, and a cap centred on the tile with a word centred under it are two objects that only look
		# related at the width they happen to have today.
		var key: String = str(i + 1)
		var label: String = TAB_NAMES[i]
		var kw: float = _keycap_w(key, UiTheme.RAIL_LABEL_FS)
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.RAIL_LABEL_FS).x
		var lx: float = box.get_center().x - (kw + UiTheme.RAIL_KEY_GAP + lw) * 0.5
		_keycap(Vector2(lx, y + _rail_key_dy()), key, UiTheme.RAIL_LABEL_FS)
		_canvas.draw_string(_font, Vector2(lx + kw + UiTheme.RAIL_KEY_GAP, y + _rail_word_dy()), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.RAIL_LABEL_FS, UiTheme.UI_TEXT if on else UiTheme.UI_TEXT_FAINT)


## The three tab glyphs, drawn rather than lettered: a satchel, a gear, a ladder of rungs.
func _rail_glyph(at: Vector2, kind: int, on: bool) -> void:
	var col: Color = UiTheme.GOLD_PALE if on else Color(0.40, 0.43, 0.50)
	match kind:
		TAB_PACK:
			_canvas.draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(16.0, 11.0)), col)
			_canvas.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 1.8)
		TAB_WORKS:
			_canvas.draw_arc(at, 6.5, 0.0, TAU, 20, col, 2.2)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				_canvas.draw_line(at + Vector2(cos(a), sin(a)) * 6.5, at + Vector2(cos(a), sin(a)) * 9.5, col, 1.8)
		_:
			for i: int in 3:
				_canvas.draw_rect(Rect2(at.x - 8.0 + float(i) * 2.0, at.y + 5.0 - float(i) * 6.0,
					16.0 - float(i) * 4.0, 2.6), col)


## PACK has nothing to buy, so its plate answers the other question a pack screen is asked: what the
## factory is making for you while you stand here.
func _detail_pack(box: Rect2, art: Rect2) -> void:
	_detail_lamp(art, 0.035)
	Visuals.draw_item(_canvas, art.get_center(), _detail_glyph(art).size.x, &"ingot")
	var tx: float = art.end.x + DETAIL_TEXT_GAP
	_tracked("THE PACK", Vector2(tx, box.position.y + 24.0), 13, 1.8, UiTheme.GOLD_PALE)
	var rates: Array[Dictionary] = _sim.production_rates()
	if rates.is_empty():
		_canvas.draw_string(_font, Vector2(tx, box.position.y + 42.0),
			"nothing is running — build a Forge at the WORKS tab and feed it ore",
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 120.0, 9, UiTheme.UI_TEXT_DIM)
		return
	_canvas.draw_string(_font, Vector2(tx, box.position.y + 42.0), "your line is making",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.UI_TEXT_DIM)
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
		Visuals.draw_item(_canvas, Vector2(cx + 11.0, base - 4.0), 13.0, item)
		_canvas.draw_string(_font, Vector2(cx + 19.0, base), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.72, 0.42))
		cx += cw + 6.0


## The lamp. Three rings behind the goods is the whole trick, and it is what makes a glyph read as lit
## rather than as big. All three plates light their square the same way and each used to say so in its
## own numbers, which stopped being survivable the moment the compact plate gave one of them a smaller
## square: a radius written as 34 hangs a third of the outer ring over the edge of a 52px square.
func _detail_lamp(art: Rect2, alpha: float) -> void:
	var r: float = art.size.x * 0.5
	for k: int in 3:
		_canvas.draw_circle(art.get_center(), r * (1.0 - float(k) * DETAIL_LAMP_STEP),
			Color(0.85, 0.70, 0.35, alpha))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))


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
	if _sim == null:
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
	return BAZAAR_SIZE.x - UiTheme.BAZAAR_RAIL - UiTheme.BAZAAR_PAD * 2.0 \
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
	for slot: Dictionary in _sim.inventory_slots():
		var id: StringName = slot["item"]
		if not _blurb_lines_memo.has(id):
			_blurb_lines_memo[id] = _blurb_lines(str(Visuals.ITEM_PURPOSE.get(id, "—")), w)
		over = maxi(over, int(_blurb_lines_memo[id]) - DETAIL_BLURB_LINES)
	# There is no floor on `over`: it opens at zero and `maxi` only ever raises it, so a clamp would be a
	# guard that cannot fire.
	return float(over) * _font.get_height(DETAIL_BLURB_SIZE)


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
		_round_rect(btn, 5.0, UiTheme.UI_ACCENT)
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK, VERB_INK)
		if hint != "":
			_canvas.draw_string(_font, Vector2(btn.position.x + VERB_PAD + vw + VERB_GAP, ty), hint,
				HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_HINT_SIZE, Color(VERB_INK, VERB_HINT_A))
	else:
		_round_rect(btn, 5.0, Color(1.0, 1.0, 1.0, 0.05))
		_tracked(verb, Vector2(btn.position.x + VERB_PAD, ty), VERB_SIZE, VERB_TRACK,
			Color(0.44, 0.46, 0.52))
	return btn


func _state_plate_w(word: String) -> float:
	return STATE_TICK + STATE_GAP + _tracked_w(word, VERB_SIZE, VERB_TRACK)


## Set on the button's own baseline and against the plate's right edge, because a state and a verb are
## read in the same place at the same moment, and only one of them is ever on a given plate.
func _state_plate(box: Rect2, word: String) -> void:
	var row: Rect2 = _detail_row(box)
	var x: float = row.end.x - DETAIL_PAD - _state_plate_w(word)
	var ty: float = row.position.y + VERB_BASE
	var mid: float = ty - 4.0
	_canvas.draw_line(Vector2(x, mid), Vector2(x + 3.5, mid + 3.5), UiTheme.STATE_INK, 1.6)
	_canvas.draw_line(Vector2(x + 3.5, mid + 3.5), Vector2(x + STATE_TICK, mid - 4.5), UiTheme.STATE_INK, 1.6)
	_tracked(word, Vector2(x + STATE_TICK + STATE_GAP, ty), VERB_SIZE, VERB_TRACK, UiTheme.STATE_INK)


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
			names.append(_item_label(uid))
		if not names.is_empty():
			blurb = "unlocks " + " · ".join(names)
		elif sample != &"":
			blurb = "analyze a sample of %s, then pour in the metal" % _item_label(sample)
		else:
			blurb = "a rung of the ladder — spend the metal, keep the knowledge"
		if sample != &"" and not names.is_empty():
			blurb += "\nanalyze a sample of %s, then pour in the metal" % _item_label(sample)
		var next: StringName = ResearchRules.next_tech(_sim.research)
		if _sim.is_researched(id):
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
			ready = can_craft and BazaarCosts.can_afford(_sim.inventory, cost) \
				and (sample == &"" or int(_sim.inventory.get(sample, 0)) >= 1)
			note = "at a claimed Bazaar" if not can_craft else _shortfall_note(cost, sample)
	else:
		var opts: Array[Dictionary] = craft_options if kind == "machine" else rack_options
		var row: int = int(act.get("row", 0))
		if row < 0 or row >= opts.size():
			return
		title = str(opts[row]["name"])
		cost = opts[row]["cost"]
		blurb = str(Visuals.ITEM_PURPOSE.get(id, "—"))
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
		if lock != &"" and not _sim.is_researched(lock):
			verb = "LOCKED"
			note = "research %s first" % str(ResearchRules.tech(lock)["name"])
		else:
			verb = "BUILD" if kind == "machine" else "BUY"
			ready = can_craft and BazaarCosts.can_afford(_sim.inventory, cost)
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
	_tracked(title.to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, UiTheme.GOLD_PALE)
	_canvas.draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y), blurb,
		HORIZONTAL_ALIGNMENT_LEFT, text_w, 9, DETAIL_BLURB_LINES, UiTheme.UI_TEXT_DIM)
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
	var order: Array[StringName] = BazaarCosts.order(_sim.inventory, cost)
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
		_canvas.draw_string(_font, Vector2(nx, chip_y + DETAIL_CHIP_BASE), note, HORIZONTAL_ALIGNMENT_LEFT,
			btn.position.x - DETAIL_ROW_GAP - nx, DETAIL_NOTE_SIZE, UiTheme.GOLD_DIM)


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
		var gap: int = int(cost[item]) - int(_sim.inventory.get(item, 0))
		if gap > 0:
			parts.append("%d %s" % [gap, _item_label(item)])
	if sample != &"" and int(_sim.inventory.get(sample, 0)) < 1:
		parts.append("a sample of %s" % _item_label(sample))
	return "" if parts.is_empty() else "short " + " · ".join(parts)


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
	_tracked(_item_label(id).to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, UiTheme.GOLD_PALE)
	# There is no line cap, because the plate was sized to hold this. `_hold_overflow_h` measured every
	# sentence in the pack at `_hold_text_w` and bought the deepest one its lines, so the count this used
	# to be capped at is a floor the height already answered. It is the same width at both ends for the
	# same reason: a blurb wrapping at a different number than the height was computed from would run off.
	_canvas.draw_multiline_string(_font, Vector2(tx, box.position.y + DETAIL_BLURB_Y),
		str(Visuals.ITEM_PURPOSE.get(id, "—")), HORIZONTAL_ALIGNMENT_LEFT, _hold_text_w(),
		DETAIL_BLURB_SIZE, -1, UiTheme.UI_TEXT_DIM)
	# The tally sits where the blurb ends, not at a baseline of its own. It used to be written 76 down a
	# plate that was always 88, which is the shop chip row's depth borrowed by a plate that has no chips,
	# and this is the plate that no longer has the height to spare. It is taken off the plate's own bottom
	# edge rather than off `DETAIL_FACT_Y`, because the two are the same pixel only while the plate is at
	# its floor and a fact pinned to the constant would print through a row the blurb had grown into.
	var carried: int = int(_sim.inventory.get(id, 0))
	var made: int = int(_sim.total_produced.get(id, 0))
	var tally: String = "%d in the pack   ·   %d all told" % [carried, made]
	_canvas.draw_string(_font, Vector2(tx, box.end.y - DETAIL_TAIL), tally,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_BLURB_SIZE, UiTheme.UI_TEXT_FAINT)
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
	var held: int = _inv_selected.call() if _inv_selected.is_valid() else -1
	if row == held:
		# HELD is not HOLD greyed out. It answers "which one is in my hand", which is what the pack screen is
		# opened to ask, while the dead pill said the pack's one verb had broken.
		_state_plate(box, "HELD")
	else:
		_verb_button(box, HOLD_VERB, HOLD_KEY, true)


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
	if _sim == null or id == &"":
		return owed
	for i: int in open_machines():
		_demand_line(id, _craft_id(i), "", craft_options[i]["cost"], owed, settled)
	for r: int in open_rack():
		# The same expression `bazaar_action` resolves a Rack row with, so the row you can select and the
		# row this prices are the same row by construction rather than by two rules that agree today.
		_demand_line(id, rack_ids[r] if r < rack_ids.size() else &"", "",
			rack_options[r]["cost"], owed, settled)
	var next: StringName = ResearchRules.next_tech(_sim.research)
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
	if BazaarCosts.gap(_sim.inventory, id, need) > 0:
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
	_canvas.draw_string(_font, at, DEMAND_LEAD, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE, UiTheme.UI_TEXT_FAINT)
	at.x += lead + DETAIL_ROW_GAP
	for i: int in shown:
		at.x += _demand_mark(at, id, lines[i], glyph) + DETAIL_ROW_GAP
	if cut > 0:
		_canvas.draw_string(_font, at, "+%d" % cut, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE,
			UiTheme.UI_TEXT_FAINT)


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
		_canvas.draw_string(_font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_NOTE_SIZE, UiTheme.UI_TEXT_FAINT)
	var num: String = _cost_numeral(id, int(e["need"]))
	_canvas.draw_string(_font, Vector2(at.x + head + DETAIL_CHIP_GAP, at.y), num, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_CHIP_SIZE, UiTheme.UI_WARN if num.begins_with("-") else UiTheme.UI_TEXT_FAINT)
	return _demand_w(id, e, glyph)


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
	var gap: int = BazaarCosts.gap(_sim.inventory, item, need)
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
	return w if BazaarCosts.gap(_sim.inventory, item, need) > 0 else w - DETAIL_CHIP_RIM


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
	var ok: bool = BazaarCosts.gap(_sim.inventory, item, need) <= 0
	if not ok:
		_round_rect(Rect2(at, Vector2(w, DETAIL_CHIP_H)), 4.0, Color(1.0, 1.0, 1.0, 0.05))
	Visuals.draw_item(_canvas, at + Vector2(11.0, DETAIL_CHIP_H * 0.5), 13.0, item)
	var head: String = _chip_numeral(item, need)
	_canvas.draw_string(_font, at + Vector2(DETAIL_CHIP_WELL, DETAIL_CHIP_BASE), head, HORIZONTAL_ALIGNMENT_LEFT, -1,
		DETAIL_CHIP_SIZE, Color(0.482, 0.796, 0.518) if ok else UiTheme.UI_WARN)
	var hw: float = _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE).x
	_canvas.draw_string(_font, at + Vector2(DETAIL_CHIP_WELL + hw, DETAIL_CHIP_BASE), "/%d" % need,
		HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_CHIP_SIZE, UiTheme.UI_TEXT_FAINT)
	return at.x + w


## The head: who you are talking to, which counter you are at, and what you are carrying of what this
## tab charges, as chips you can count without reading.
func _draw_bazaar_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD
	_tracked("BAZAAR", Vector2(x, origin.y + 29.0), 17, 2.8, UiTheme.UI_TEXT)
	var tab_x: float = x + _tracked_w("BAZAAR", 17, 2.8) + 16.0
	_tracked(TAB_NAMES[bazaar_tab], Vector2(tab_x, origin.y + 29.0), 17, 2.8, UiTheme.UI_TEXT_FAINT)
	# The strip stops one panel pad short of the title's last stroke, measured off the title rather than
	# guessed at. It was `x + 170.0`, a statement about the widths of "BAZAAR" and the longest tab name at
	# 17pt with 2.8 of tracking, with nothing in the file relating it to either.
	var floor_x: float = tab_x + _tracked_w(TAB_NAMES[bazaar_tab], 17, 2.8) + UiTheme.BAZAAR_PAD
	var rx: float = origin.x + float(g["w"]) - UiTheme.BAZAAR_PAD
	# A material priced but not held draws no chip. The shortfall for the thing under the cursor is
	# answered per ingredient on the detail plate instead, and a strip of zeroes for everything the ladder
	# will ever charge would be a wall of what you do not have, on the tab where you choose what next.
	for item: StringName in _priced_materials():
		var n: int = int(_sim.inventory.get(item, 0))
		if n <= 0:
			continue
		var label: String = str(n)
		var cw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 25.0
		rx -= cw + 5.0
		if rx < floor_x:
			break
		_round_rect(Rect2(rx, origin.y + 6.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(_canvas, Vector2(rx + 11.0, origin.y + 16.0), 13.0, item)
		_canvas.draw_string(_font, Vector2(rx + 19.0, origin.y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.UI_TEXT)


## The footer is one line: the keys. What you are carrying moved to the head as chips, and where the
## verbs live moved onto the verb button, where it answers the question you are actually asking.
func _draw_bazaar_foot(origin: Vector2, g: Dictionary) -> void:
	# One input grammar, and it is the rail's. This was a single run-on string using double spaces as
	# structure, which reads as prose and gets skipped like prose: keys and verbs sat at the same weight,
	# so nothing said which half was the thing to press. Each key is a cap now, with its verb beside it at
	# the old dim weight so the eye lands on the key.
	var x: float = origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD
	var y: float = origin.y + float(g["h"]) - 15.0
	for pair: Array in [["up/dn", "pick"], ["1-3", "tab"], ["E", "close"]]:
		x += _keycap(Vector2(x, y), str(pair[0]), 8) + 5.0
		var label: String = str(pair[1])
		_canvas.draw_string(_font, Vector2(x, y + 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.UI_TEXT_FAINT)
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0


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
	var origin := Vector2((UiTheme.CANVAS.x - BAZAAR_SIZE.x) * 0.5, (UiTheme.CANVAS.y - h) * 0.5)
	var inner_x: float = origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD
	var inner_w: float = BAZAAR_SIZE.x - UiTheme.BAZAAR_RAIL - UiTheme.BAZAAR_PAD * 2.0
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
	if _sim == null:
		return BAZAAR_SIZE.y
	var inner_w: float = BAZAAR_SIZE.x - UiTheme.BAZAAR_RAIL - UiTheme.BAZAAR_PAD * 2.0
	var need: float = 0.0
	match bazaar_tab:
		TAB_WORKS:
			need = float(_works_rows_needed()) * BAZAAR_ROW_H
		TAB_BENCH:
			# The tree sizes its own chips down to fit whatever it is given, so what it wants is the tallest tier
			# at full chip height. Today that asks for more than the panel may ever be, so BENCH is clamped and
			# unchanged, which is the correct outcome rather than a coincidence to rely on.
			var tall: int = maxi(1, _bench_page()._bench_tallest())
			need = float(tall) * 64.0 + float(tall - 1) * 6.0
		_:
			# The wells and the summary band under them. The band was missing from this sum while the summary's
			# own guard tested against a content box this sum had already decided, so the two could only agree by
			# accident. `_ledger_h` carries the reasoning.
			need = float(_pack_page()._pack_rows(inner_w)) * PACK_CELL + _pack_page()._ledger_h()
	return clampf(BAZAAR_HEAD + need + BAZAAR_DETAIL_GAP + _detail_wanted_h() + BAZAAR_FOOT,
		BAZAAR_MIN_H, BAZAAR_SIZE.y)


## Move the cursor. `dy` steps a row, while `dx` jumps a whole column, which is the same motion your eye
## makes and carries you across the counter-to-Rack gap in one keystroke rather than ten.
func bazaar_move(dx: int, dy: int) -> void:
	var n: int = bazaar_row_count()
	if n <= 0:
		return
	if dx != 0:
		bazaar_row = clampi(bazaar_row + dx * int(_bazaar_geometry()["rows"]), 0, n - 1)
	bazaar_row = clampi(bazaar_row + dy, 0, n - 1)


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

## Hand the bench tab the surface it draws on. Called wherever the page reaches it, so the binding cannot
## drift from the use.
func _bench_page() -> BazaarBench:
	_bench._canvas = _canvas
	_bench._font = _font
	_bench._sim = _sim
	_bench._icons = _icons
	_bench.probing = probing
	_bench.panel_probe = panel_probe
	return _bench


## The shell draws the tabs, so it calls this one from outside. Kept as a forwarder rather than rewiring
## the caller: the bench binding is this page's business, and a caller that knew about it would have to be
## told again the next time a tab moves.
func _tab_bench(g: Dictionary, picked: StringName) -> void:
	_bench_page()._tab_bench(g, picked)


## Hand the pack tab the surface it draws on, plus the two pieces of the page's own state it reads: the
## focused row and the hotbar's pick.
func _pack_page() -> BazaarPack:
	_pack._canvas = _canvas
	_pack._font = _font
	_pack._sim = _sim
	_pack._icons = _icons
	_pack.probing = probing
	_pack.panel_probe = panel_probe
	_pack.bazaar_row = bazaar_row
	_pack._inv_selected = _inv_selected
	return _pack


## Forwarded for the same reason as the bench above: the shell draws the tabs.
func _tab_pack(g: Dictionary) -> void:
	_pack_page()._tab_pack(g)
