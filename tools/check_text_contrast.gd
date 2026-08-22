extends "res://tools/check_base.gd"

## CAN YOU READ THE WORDS OFF THE PLATE THEY ARE PRINTED ON?
##
##   godot --headless --path . --script res://tools/check_text_contrast.gd
##
## The second half of `MNU-32`. The first half asked whether a selection still reads with the colour taken
## away, and the answer was yes on every surface. This one asks a question that has nothing to do with
## selection and everything to do with the same requirement: a label is only a label if there is enough
## light between the ink and the plate to see the shape of it.
##
## **CONTRAST RATIO IS NOT COMPUTED FROM THE LUMA THIS REPOSITORY ALREADY USES, AND THAT IS THE WHOLE
## REASON THIS FILE EXISTS RATHER THAN A LINE ADDED TO AN EXISTING LAYER.** The measurement sites here
## weigh gamma-encoded sRGB components directly, in two different conventions (Rec.709 `(0.2126, 0.7152,
## 0.0722)` and Rec.601 `(0.299, 0.587, 0.114)`), and either of them dropped into `(L1 + 0.05) / (L2 +
## 0.05)` produces a number with the right units and the wrong value. Relative luminance LINEARISES each
## channel first:
##
##     c_lin = c / 12.92                    for c <= 0.04045
##     c_lin = ((c + 0.055) / 1.055) ^ 2.4  otherwise
##     L     = 0.2126*R_lin + 0.7152*G_lin + 0.0722*B_lin
##
## On this palette the two disagree by up to 1.8x AND THEY DISAGREE IN BOTH DIRECTIONS, which is what makes
## the substitution dangerous rather than merely conservative. Light ink on a near-black plate scores 12.5
## linearised and 7.2 gamma-encoded, so the naive figure is pessimistic; dark ink on the same plate scores
## 2.6 linearised and 3.2 gamma-encoded, so it is optimistic exactly where a failure would be. `UI_EDGE`
## against `UI_BG` sits in that second band. The function below is called `_relative_luminance` and never
## `luma`, because `luma` already means two things in this tree and the ambiguity has flipped the sign of a
## result before.
##
## THE IMPLEMENTATION IS CALIBRATED AGAINST A VALUE FROM OUTSIDE THIS REPOSITORY before it is trusted. The
## grey `#767676` on white is the canonical borderline case: it is the darkest neutral that clears 4.5:1,
## and it comes out at 4.54 linearised and 2.05 gamma-encoded. A layer that measured contrast with the
## wrong luminance would pass every assertion below and be wrong by a factor of two, and no arrangement of
## the palette's own colours can catch that: only a number nobody here chose can.
##
## THE COLOURS ARE READ OUT OF `scenes/hud.gd`, not sampled off a frame. Sampling would drag in the lighting
## veil, the vignette, the panel sheen and glyph antialiasing, and antialiased edges are most of the pixels
## in small type: an average over them measures the rasteriser. The constants are the thing an author
## actually edits, so they are the thing to hold a floor against. They are pulled from the script's own
## constant map rather than through `Hud.` so the layer reads the FILE and cannot be satisfied by a stale
## global class cache.
##
## THE POPULATION IS THIRTEEN PAIRS: every named text ink that lands on a named plate, against the five
## named plates that carry text. Every row names its call sites. What is NOT in it is written out here, at
## length, because a layer called "text contrast" that measured thirteen pairs would otherwise be read as a
## sweep of the HUD: the title screen and the tooltip draw their type in inline literals; the wash tiles
## (`Color(1, 1, 1, 0.022…0.062)` over the modal) and the picked row's brass are plates this layer cannot
## name, because they are literals in the drawing code and not constants; SEE THE STAND-DOWN BELOW, since
## that is where the remaining exposure sits; `RAIL_ON_FILL` carries a glyph and no text; the disabled verb
## button is deliberately quiet and is exempt under every readability standard that has an opinion about
## disabled controls; and text drawn at a fading alpha (`hint_a` on the objective hint) is measured at full
## strength, because the values in between are a transition and not a state. Roughly a hundred
## `draw_string` calls exist in that file. Thirteen pairs is what is asserted.
##
## `UI_ACCENT` ENTERS AS A PLATE AND NOT AS AN INK, which is `MNU-06` holding rather than bending: gold was
## moved off every site where it was labelling anything, so it is still not a text ink, but the live verb
## button is a slab of it with dark type on top, and that is a plate carrying text like any other.
##
## THE FOUR ROWS ADDED BY `MNU-32`'s ink pass are `GOLD_DIM` and `GOLD_PALE` on the modal, and `VERB_INK`
## on the accent at both of its strengths. They exist because the pass NAMED the colours it lifted: seven
## literals across eleven sites became four constants, and a constant is the only thing a floor can be held
## against. The thinned row is the one that had actually failed, at 3.77 against a floor of 4.5.
##
## `GOLD_DIM`'s ROW IS DOWN TO ONE CALL SITE, and the row is kept rather than dropped. `MNU-06`'s closing
## pass moved the three headings it was lifted for onto `UI_TEXT_DIM` (a gold rung of a type ramp turned
## out to be an affordance claim at a lower volume), and their figures are now carried by the row that
## already asserted that ink on this plate. What is left is the detail plate's refusal note, which sits on
## a wash this layer cannot name (see the stand-down), so the modal under it is the nearest ground a row
## can hold. The site list is written out per row precisely so a shrinking one is visible here instead of
## being a number that keeps measuring green over an empty population.
##
## THE PLATE IS COMPOSITED, because every one of the four carries alpha and a translucent plate is not a
## colour: it is a colour plus a window onto whatever is behind it. The ground is black: that is the value
## the palette was authored against ("the HUD is still perfectly readable against its own near-black
## panels"), and it is the only ground `scenes/hud.gd` can be held responsible for. A brighter world behind
## the window can only close the gap, so the over-white figure is printed beside every row as the bracket
## on how much it can cost. It is not asserted, and the stand-down below says so: the one row it would
## take under the floor is the hotbar's keybind digit at 4.11, the hotbar being the only furniture here
## thin enough and low enough for a lamp to sit behind it.
##
## MEASURED BEFORE THE FLOOR WAS SET. The palette's named inks (`UI_TEXT`, `UI_TEXT_DIM`, `UI_ACCENT`,
## `UI_WARN`) came in between 4.57 and 13.13 across every named plate, the lowest of them being
## `UI_TEXT_DIM` under the worst backdrop a translucent panel can have. The floor is 4.5, which is not
## invented for this layer: it is the level the palette's own dimmest named role already cleared without
## help. Four bounds guessed in advance have been wrong in this repository; this one is a ratchet on a
## decision the design had already made, which is the only kind of bound worth writing down here.
##
## WHAT IT CAUGHT, at 2.0 to 4.0 against the same plates: four separate literals doing one job, eight sites,
## no name between them: the counter's tab name at title size (2.04), both key legends (2.90 and 3.13),
## both rails' unlit labels (3.27), the detail plate's tally line, the cost chip's shortfall, and the
## hotbar's keybind digit (3.96). They are `UI_TEXT_FAINT` now, and the third tier of the type ramp is a
## constant this layer can hold a floor against instead of a literal it cannot see.
##
## PROVED RED BY KNOCKOUT, TWICE, BECAUSE THERE ARE TWO THINGS HERE THAT COULD BE VACUOUS. The subject
## first: `UI_TEXT_FAINT` was set to `Color(0.14, 0.15, 0.19)` (a value change and not a hue change, so
## the fault is contrast and nothing else), and the three rows carrying it went to 1.12, 1.25 and 1.31
## against a floor of 4.5, while the six rows that do not carry it printed the same figures they print
## green. Then the instrument: `_linear` was replaced by the identity, which is exactly the mistake this
## header is about, and the calibration went to 2.05 and failed before any of the palette was reached.
## Both restored, and green.

const HUD: String = "res://scenes/hud.gd"
const UI_THEME: String = "res://scenes/ui_theme.gd"

## WCAG 2 AA for body text. See the header: chosen after the nine rows were measured, and set at the level
## the palette's dimmest named ink already reached on its own.
const FLOOR: float = 4.5

## The calibration anchor: `#767676` on white, the canonical borderline grey. Linearised this is 4.54; a
## gamma-encoded luma in the same formula gives 2.05, so the tolerance is far tighter than the gap it has
## to detect.
const REF_GREY: float = 118.0 / 255.0
const REF_RATIO: float = 4.54
const REF_TOL: float = 0.02

## Below this a plate is opaque enough that the ground behind it cannot matter; used only to report which
## rows the bracket applies to, never to excuse one.
const OPAQUE: float = 0.98

var _consts: Dictionary = {}
var _sources: Array[String] = []


func _initialize() -> void:
	print("== text against the plate it is drawn on ==")
	# THE PALETTE MOVED OUT FROM UNDER THIS LAYER, so it reads the owners rather than one file. It used to
	# load `scenes/hud.gd` alone and that worked while the Hud aliased every colour, because an alias
	# resolves to its value in the constant map. As the Hud decomposes those aliases go, and the first one
	# to go took `UI_RAIL` with it -- four rows failed here naming a colour that had simply moved house.
	#
	# Reading the owners is the fix rather than putting the alias back: a constant kept alive on the Hud
	# only so a checker can find it is a checker deciding where the code lives.
	#
	# Order matters only for a name defined twice, and then the Hud wins, because a Hud that still names a
	# colour is still drawing with it. Add a source here when a palette constant moves to a new home; the
	# absence check below is what makes that failure loud instead of silent.
	_sources = [UI_THEME, HUD]
	for path: String in _sources:
		var script: GDScript = load(path) as GDScript
		if script == null:
			_skip_layer("check_text_contrast", "%s did not load, so there are no palette constants "
				% path + "to measure and a green result here would be a statement about an empty table")
			return
		_consts.merge(script.get_script_constant_map(), true)
	_calibrate()
	_measure()
	_stand_down("contrast.bright-backdrop", "the bright-backdrop column", "how much light the world can put through a 0.90 plate is a "
		+ "property of the renderer, not of the palette, and this layer's lane is the palette")
	# NAMED HONESTLY BECAUSE IT IS THE GAP, not because it is tidy. `MNU-32`'s ink pass measured these by
	# hand and the worst of them was the cost shortfall at 4.20 on the picked row's brass, which is why
	# that ink is `UI_WARN` now, but the FLOOR on it is not held here, and will not be until the wash
	# tiles and the brass are constants this layer can name. Ten drawing sites would have to change colour
	# nothing to get there, so it is a separate decision and not a silent one.
	_stand_down("contrast.wash-and-brass", "the wash tiles and the picked row's brass", "they are literals in the drawing code rather "
		+ "than named constants, so no row here can reference them — the inks that land on them were "
		+ "measured by hand for the ticket and cleared, but nothing re-measures them on the next edit")
	_verdict("check_text_contrast", "every named HUD ink clears %.1f:1 on every named plate it lands on"
		% FLOOR)


## The instrument, against a number nobody here chose. Both ends are checked: white on black is exactly 21
## under any correct implementation, which catches a transposed constant, and the borderline grey catches
## the gamma-encoded substitution this whole layer is a reaction to.
func _calibrate() -> void:
	var extreme: float = _contrast(Color.WHITE, Color.BLACK)
	_check(absf(extreme - 21.0) < 0.001,
		"white on black measures the defined extreme (%.4f, exactly 21 by construction)" % extreme)
	var grey: float = _contrast(Color(REF_GREY, REF_GREY, REF_GREY), Color.WHITE)
	_check(absf(grey - REF_RATIO) < REF_TOL,
		"#767676 on white measures %.2f against the published %.2f — the luminance is linearised, not the "
			% [grey, REF_RATIO] + "repository's gamma-encoded luma, which would read 2.05 here")


## The nine pairs, and every call site that draws one. The colours come out of the file; only the PAIRING (
## which ink lands on which plate) is written here, because that is a fact about the drawing code and not
## a value that can drift out from under a copy.
func _measure() -> void:
	var pairs: Array[Dictionary] = [
		{"ink": "GOLD_DIM", "plate": "UI_MODAL",
			"at": "the detail plate's refusal note — its one remaining site, over a wash on this plate"},
		{"ink": "GOLD_PALE", "plate": "UI_MODAL", "at": "the hot slider's value cap"},
		{"ink": "VERB_INK", "plate": "UI_ACCENT", "at": "the live verb's word"},
		{"ink": "VERB_INK", "ink_a": "VERB_HINT_A", "plate": "UI_ACCENT",
			"at": "the live verb's key hint, thinned"},
		{"ink": "UI_TEXT", "plate": "UI_BG", "at": "the FORGED count, the grand total, a machine name"},
		{"ink": "UI_TEXT_DIM", "plate": "UI_BG", "at": "the FORGED label, PRODUCTION, CONTROLS, the hint"},
		{"ink": "UI_WARN", "plate": "UI_BG", "at": "the dashboard's stalled counts"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_SLOT", "at": "the hotbar's keybind digit"},
		{"ink": "UI_TEXT", "plate": "UI_MODAL", "at": "the BAZAAR title, the chip counts, a works row"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_MODAL", "at": "the tab name, both key legends, the tally"},
		{"ink": "UI_TEXT", "plate": "UI_RAIL", "at": "the lit rail label, on both rails"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_RAIL", "at": "the unlit rail labels, on both rails"},
		{"ink": "UI_TEXT_DIM", "plate": "UI_MODAL",
			"at": "the detail blurb, the settings rows, the ledger heading, both works group titles, "
				+ "the research pointer"},
	]
	# NON-VACUITY, both directions. A population that quietly shrank to nothing would satisfy every ratio
	# assertion below by having none to make, and a table where every plate came back opaque would carry the
	# compositing path untested while looking like nine honest rows. Both are asserted before the rows are.
	_check(pairs.size() == 13, "the population is the thirteen pairs the header enumerates (%d)"
		% pairs.size())
	var translucent: int = 0
	for p: Dictionary in pairs:
		if _colour(str(p["plate"])).a < OPAQUE:
			translucent += 1
	_check(translucent > 0, "at least one plate is translucent, so the compositing path is exercised "
		+ "rather than being carried untested (%d of %d rows)" % [translucent, pairs.size()])
	# THE THINNED ROW IS THE ONE THAT WAS BROKEN, so its path is asserted rather than assumed. A row that
	# quietly lost its `ink_a` would be measured at full strength (which is exactly the reading that hid
	# the verb hint's 3.77 for as long as it did), and would still print nine honest-looking figures.
	var thinned: int = 0
	for p: Dictionary in pairs:
		if p.has("ink_a"):
			thinned += 1
	_check(thinned > 0, "at least one row carries an ink alpha, so the ink-compositing path is exercised "
		+ "and not carried untested (%d of %d rows)" % [thinned, pairs.size()])

	print("  %-16s %-10s %8s %8s   %s" % ["ink", "plate", "on dark", "on lit", "drawn at"])
	for p: Dictionary in pairs:
		var ink_name: String = str(p["ink"])
		var plate_name: String = str(p["plate"])
		var plate: Color = _colour(plate_name)
		# AN INK WITH AN ALPHA IS NOT ITS OWN COLOUR. `_verb_button` draws its key hint as the verb's ink
		# thinned, and reading that constant at full strength measures a glyph nobody is looking at: the
		# hint scored 8.30 that way and 3.77 as drawn. The ink is composited onto its own plate first, so
		# the row measures the pixels the player sees.
		var ink: Color = _colour(ink_name)
		var dark_plate: Color = _over(plate, Color.BLACK)
		var lit_plate: Color = _over(plate, Color.WHITE)
		var dark_ink: Color = ink
		var lit_ink: Color = ink
		if p.has("ink_a"):
			var a: float = _alpha(str(p["ink_a"]))
			ink_name = "%s @%.2f" % [ink_name, a]
			# Composited against EACH ground separately. Thinning the ink onto the dark plate and then
			# measuring it against the lit one would mix two frames into one number.
			dark_ink = _over(Color(ink, a), dark_plate)
			lit_ink = _over(Color(ink, a), lit_plate)
		var dark: float = _contrast(dark_ink, dark_plate)
		var lit: float = _contrast(lit_ink, lit_plate)
		print("  %-16s %-10s %8.2f %8.2f   %s" % [ink_name, plate_name, dark, lit, str(p["at"])])
		_check(dark >= FLOOR, "%s on %s is readable — %.2f:1, floor %.1f (%s)"
			% [ink_name, plate_name, dark, FLOOR, str(p["at"])])


## A named constant out of `scenes/hud.gd`, or a loud failure. A missing name would otherwise resolve to
## opaque black and quietly turn one row into a measurement of nothing.
func _colour(name: String) -> Color:
	if not _consts.has(name):
		_check(false, "%s is defined by none of the %d palette source(s) searched (%s), and a row here measures"
			% [name, _sources.size(), ", ".join(_sources)])
		return Color.BLACK
	return _consts[name] as Color


## A named alpha out of `scenes/hud.gd`. Loud on absence for the same reason `_colour` is, and then some:
## a missing alpha would fall back to 1.0, which is the value that makes the row PASS. An error path that
## returns the passing value is how a thinned ink gets measured at full strength and reads green.
func _alpha(name: String) -> float:
	if not _consts.has(name):
		_check(false, "%s is defined by none of the %d palette source(s) searched (%s), and a row here thins an ink by"
			% [name, _sources.size(), ", ".join(_sources)])
		return 0.0
	return float(_consts[name])


## Relative luminance, per the sRGB definition the contrast ratio is written against. NOT `luma`: see the
## header. The channels are linearised before they are weighed, which is the entire difference.
func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


## `(L1 + 0.05) / (L2 + 0.05)`, lighter over darker, so the caller never has to know which is which. 1.0
## means the two are indistinguishable; 21.0 is white on black.
func _contrast(a: Color, b: Color) -> float:
	var la: float = _relative_luminance(a)
	var lb: float = _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Source-over, in the same non-linear space Godot's blender works in, because the question is what the
## plate LOOKS like and the rasteriser is what decides that.
func _over(fg: Color, bg: Color) -> Color:
	return Color(fg.r * fg.a + bg.r * (1.0 - fg.a), fg.g * fg.a + bg.g * (1.0 - fg.a),
		fg.b * fg.a + bg.b * (1.0 - fg.a))
