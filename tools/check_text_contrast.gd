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
## weigh gamma-encoded sRGB components directly, in two different conventions — Rec.709 `(0.2126, 0.7152,
## 0.0722)` and Rec.601 `(0.299, 0.587, 0.114)` — and either of them dropped into `(L1 + 0.05) / (L2 +
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
## our own colours can catch that — only a number nobody here chose can.
##
## THE COLOURS ARE READ OUT OF `scenes/hud.gd`, not sampled off a frame. Sampling would drag in the lighting
## veil, the vignette, the panel sheen and glyph antialiasing, and antialiased edges are most of the pixels
## in small type: an average over them measures the rasteriser. The constants are the thing an author
## actually edits, so they are the thing to hold a floor against. They are pulled from the script's own
## constant map rather than through `Hud.` so the layer reads the FILE and cannot be satisfied by a stale
## global class cache.
##
## THE POPULATION IS NINE PAIRS: the four named text inks that land on a named plate, against the four
## named plates that carry text. Every row names its call sites. What is NOT in it is written out here, at
## length, because a layer called "text contrast" that measured nine pairs would otherwise be read as a
## sweep of the HUD: the title screen and the tooltip draw their type in inline literals; the wash tiles
## (`Color(1, 1, 1, 0.028…0.062)` over the modal) are plates this layer does not name and the cost chip's
## shortfall sits on the heaviest of them; `RAIL_ON_FILL` carries a glyph and no text; the
## disabled verb button is deliberately quiet and is exempt under every readability standard that has an
## opinion about disabled controls; and text drawn at a fading alpha (`hint_a` on the objective hint) is
## measured at full strength, because the values in between are a transition and not a state. `UI_ACCENT`
## is absent for a reason that is itself a shipped decision: `MNU-06` moved gold off every site where it
## was labelling anything, so gold is not a text ink on a named plate any more. Roughly a hundred
## `draw_string` calls exist in that file. Nine pairs is what is asserted.
##
## THE PLATE IS COMPOSITED, because every one of the four carries alpha and a translucent plate is not a
## colour — it is a colour plus a window onto whatever is behind it. The ground is black: that is the value
## the palette was authored against ("the HUD is still perfectly readable against its own near-black
## panels"), and it is the only ground `scenes/hud.gd` can be held responsible for. A brighter world behind
## the window can only close the gap, so the over-white figure is printed beside every row as the bracket
## on how much it can cost. It is not asserted, and the stand-down below says so — the one row it would
## take under the floor is the hotbar's keybind digit at 4.11, the hotbar being the only furniture here
## thin enough and low enough for a lamp to sit behind it.
##
## MEASURED BEFORE THE FLOOR WAS SET. The palette's named inks — `UI_TEXT`, `UI_TEXT_DIM`, `UI_ACCENT`,
## `UI_WARN` — came in between 4.57 and 13.13 across every named plate, the lowest of them being
## `UI_TEXT_DIM` under the worst backdrop a translucent panel can have. The floor is 4.5, which is not
## invented for this layer: it is the level the palette's own dimmest named role already cleared without
## help. Four bounds guessed in advance have been wrong in this repository; this one is a ratchet on a
## decision the design had already made, which is the only kind of bound worth writing down here.
##
## WHAT IT CAUGHT, at 2.0 to 4.0 against the same plates: four separate literals doing one job, eight sites,
## no name between them — the counter's tab name at title size (2.04), both key legends (2.90 and 3.13),
## both rails' unlit labels (3.27), the detail plate's tally line, the cost chip's shortfall, and the
## hotbar's keybind digit (3.96). They are `UI_TEXT_FAINT` now, and the third tier of the type ramp is a
## constant this layer can hold a floor against instead of a literal it cannot see.
##
## PROVED RED BY KNOCKOUT, TWICE, BECAUSE THERE ARE TWO THINGS HERE THAT COULD BE VACUOUS. The subject
## first: `UI_TEXT_FAINT` was set to `Color(0.14, 0.15, 0.19)` — a value change and not a hue change, so
## the fault is contrast and nothing else — and the three rows carrying it went to 1.12, 1.25 and 1.31
## against a floor of 4.5, while the six rows that do not carry it printed the same figures they print
## green. Then the instrument: `_linear` was replaced by the identity, which is exactly the mistake this
## header is about, and the calibration went to 2.05 and failed before any of the palette was reached.
## Both restored, and green.

const HUD: String = "res://scenes/hud.gd"

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


func _initialize() -> void:
	print("== text against the plate it is drawn on ==")
	var script: GDScript = load(HUD) as GDScript
	if script == null:
		_skip_layer("check_text_contrast", "scenes/hud.gd did not load, so there are no palette constants "
			+ "to measure and a green result here would be a statement about an empty table")
		return
	_consts = script.get_script_constant_map()
	_calibrate()
	_measure()
	_stand_down("the bright-backdrop column", "how much light the world can put through a 0.90 plate is a "
		+ "property of the renderer, not of the palette, and this layer's lane is the palette")
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


## The nine pairs, and every call site that draws one. The colours come out of the file; only the PAIRING —
## which ink lands on which plate — is written here, because that is a fact about the drawing code and not
## a value that can drift out from under a copy.
func _measure() -> void:
	var pairs: Array[Dictionary] = [
		{"ink": "UI_TEXT", "plate": "UI_BG", "at": "the FORGED count, the grand total, a machine name"},
		{"ink": "UI_TEXT_DIM", "plate": "UI_BG", "at": "the FORGED label, PRODUCTION, CONTROLS, the hint"},
		{"ink": "UI_WARN", "plate": "UI_BG", "at": "the dashboard's stalled counts"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_SLOT", "at": "the hotbar's keybind digit"},
		{"ink": "UI_TEXT", "plate": "UI_MODAL", "at": "the BAZAAR title, the chip counts, a works row"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_MODAL", "at": "the tab name, both key legends, the tally"},
		{"ink": "UI_TEXT", "plate": "UI_RAIL", "at": "the lit rail label, on both rails"},
		{"ink": "UI_TEXT_FAINT", "plate": "UI_RAIL", "at": "the unlit rail labels, on both rails"},
		{"ink": "UI_TEXT_DIM", "plate": "UI_MODAL", "at": "the detail blurb, the settings rows"},
	]
	# NON-VACUITY, both directions. A population that quietly shrank to nothing would satisfy every ratio
	# assertion below by having none to make, and a table where every plate came back opaque would carry the
	# compositing path untested while looking like nine honest rows. Both are asserted before the rows are.
	_check(pairs.size() == 9, "the population is the nine pairs the header enumerates (%d)" % pairs.size())
	var translucent: int = 0
	for p: Dictionary in pairs:
		if _colour(str(p["plate"])).a < OPAQUE:
			translucent += 1
	_check(translucent > 0, "at least one plate is translucent, so the compositing path is exercised "
		+ "rather than being carried untested (%d of %d rows)" % [translucent, pairs.size()])

	print("  %-16s %-10s %8s %8s   %s" % ["ink", "plate", "on dark", "on lit", "drawn at"])
	for p: Dictionary in pairs:
		var ink_name: String = str(p["ink"])
		var plate_name: String = str(p["plate"])
		var ink: Color = _colour(ink_name)
		var plate: Color = _colour(plate_name)
		var dark: float = _contrast(ink, _over(plate, Color.BLACK))
		var lit: float = _contrast(ink, _over(plate, Color.WHITE))
		print("  %-16s %-10s %8.2f %8.2f   %s" % [ink_name, plate_name, dark, lit, str(p["at"])])
		_check(dark >= FLOOR, "%s on %s is readable — %.2f:1, floor %.1f (%s)"
			% [ink_name, plate_name, dark, FLOOR, str(p["at"])])


## A named constant out of `scenes/hud.gd`, or a loud failure. A missing name would otherwise resolve to
## opaque black and quietly turn one row into a measurement of nothing.
func _colour(name: String) -> Color:
	if not _consts.has(name):
		_check(false, "scenes/hud.gd still defines %s, which a row here measures" % name)
		return Color.BLACK
	return _consts[name] as Color


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
