class_name PageTokens
extends RefCounted

## THE MODAL PAGE'S TWO SKINS (D0632), re-cut as a TYPESET page (D0634): the director picked PAPER and
## named the miss -- the reference look is typographic discipline, not parchment colour. The token sets
## below are therefore Theme vocabulary for a page built like print: a small tracked overline over a
## large display title, hairline rules instead of boxed rows, a rail whose selected tab is underlined
## in the accent rather than filled, and two-three inks plus the one accent the gold rule permits.
##
## EVERY COLOUR AND TYPE RUNG LIVES IN THE THEME, not in per-node overrides. That is not tidiness for
## its own sake: a capture showed the paper page still printing the INSTRUMENT skin's ink_faint on its
## detail and footer lines -- `apply_skin` rebuilt the Theme but every `add_theme_color_override` set
## at build time kept the old skin's value. The fix is structural: overrides that say what a thing
## LOOKS LIKE are gone (Label variations carry them); the only per-node colours left are the ones
## `_refresh` re-states every frame from live state (muted, clashes), which re-read `_tokens` anyway.
##
## THE MEASURED RULE BOTH SKINS OBEY: nothing in the UI brighter than lit rock -- measured on HUD
## furniture over the world (ui_theme.gd's header keeps the provenance). A MODAL is the exception the
## rule's own measurement permits: the scrim suppresses the world behind the page, so PAPER's light
## plate does not compete with the play space the way a bright chip over it would.
##
## THE KNOWN GAP, named rather than hidden: no font asset ships in this repo, so every size below is a
## ramp on `ThemeDB.fallback_font` and the serif-feel is faked honestly -- the overline is a
## FontVariation with tracking, the title the same font emboldened. `display_font`/`body_font` are
## honoured when a path exists so the asset can land without a code change, but picking and licensing
## the faces is a director call, not a session's.
##
## `plate`, `row` and `row_lit` are the surfaces type prints on; the pairings are the contrast
## contract -- `ink` lives on `plate`/`row_lit`, `accent` marks only what input is connected to (the
## gold rule, unchanged from ui_theme.gd: it never labels and never counts). `rule` is the typeset
## hairline: an ink at half strength, thin by construction everywhere it is used.

const INSTRUMENT: Dictionary = {
	"name": "instrument",
	"scrim": Color(0.02, 0.025, 0.04, 0.42),
	"plate": Color(0.066, 0.075, 0.10, 0.97),        ## the rig's panel, near-opaque
	"edge": Color(0.20, 0.23, 0.30),
	"shadow": Color(0.0, 0.0, 0.0, 0.45),            ## the plate's lift off the dimmed world
	"row": Color(0.11, 0.12, 0.16, 0.95),            ## chip well / idle control face
	"row_lit": Color(0.145, 0.129, 0.082),           ## hover/armed bed
	"ink": Color(0.80, 0.83, 0.89),
	"ink_dim": Color(0.54, 0.58, 0.66),
	"ink_faint": Color(0.50, 0.54, 0.62),
	"ink_on_accent": Color(0.10, 0.10, 0.12),        ## dark print on a gold fill
	"accent": Color(0.80, 0.66, 0.30),               ## brass: what input is connected to
	"accent_pale": Color(0.949, 0.831, 0.549),       ## the same gold under more light (focus ring)
	"warn": Color(0.96, 0.46, 0.30),
	"track": Color(0.0, 0.0, 0.0, 0.5),              ## slider bed
	"rule": Color(0.40, 0.44, 0.54, 0.42),           ## the hairline: ink at half strength
	"radius": 8.0,
	"display_size": 34,                              ## canvas px: the display title
	"overline_size": 13,                             ## canvas px: the tracked eyebrow
	"overline_track": 4.0,                           ## px between glyphs on the overline
	"body_size": 20,                                 ## canvas px: rows, labels
	"small_size": 16,                                ## detail note, footer legend
	"rail_size": 14,                                 ## rail slot captions
	"display_font": "res://assets/fonts/display_serif.ttf",
	"body_font": "res://assets/fonts/body_sans.ttf",
}

const PAPER: Dictionary = {
	"name": "paper",
	"scrim": Color(0.10, 0.08, 0.05, 0.50),          ## warmer dim: the world goes amber, not black
	"plate": Color(0.875, 0.831, 0.714, 0.99),       ## #DFD4B6 -- the leaf, aged off printer-white
	"edge": Color(0.49, 0.44, 0.34),                 ## worn edge, like a much-handled cover
	"shadow": Color(0.20, 0.16, 0.10, 0.40),         ## warm dark: the leaf sits off the table
	"row": Color(0.765, 0.714, 0.576, 1.0),          ## #C3B693 chip well, kept quiet against the leaf
	"row_lit": Color(0.894, 0.835, 0.671, 1.0),      ## lifted leaf for hover/focus
	"ink": Color(0.169, 0.153, 0.125),               ## #2B2720 ink
	"ink_dim": Color(0.286, 0.259, 0.208),           ## #494235 -- darkened for print legibility (D0634)
	"ink_faint": Color(0.396, 0.365, 0.294),         ## #655D4B footnote ink: quiet, still read
	"ink_on_accent": Color(0.13, 0.10, 0.05),
	"accent": Color(0.541, 0.416, 0.173),            ## #8A6A2C: brass on paper needs depth, not lift
	"accent_pale": Color(0.35, 0.27, 0.12),
	"warn": Color(0.66, 0.29, 0.16),                 ## #A84A28: stamped in red-brown
	"track": Color(0.70, 0.65, 0.53, 1.0),
	"rule": Color(0.31, 0.28, 0.22, 0.45),           ## warm hairline, ink at half strength
	"radius": 4.0,                                   ## paper wants square-er corners than the panel
	"display_size": 34,
	"overline_size": 13,
	"overline_track": 4.0,
	"body_size": 20,
	"small_size": 16,
	"rail_size": 14,
	"display_font": "res://assets/fonts/display_serif.ttf",
	"body_font": "res://assets/fonts/body_sans.ttf",
}

const SKINS: Array[String] = ["instrument", "paper"]


static func named(skin: String) -> Dictionary:
	return PAPER if skin == "paper" else INSTRUMENT


## The font the token asks for when the asset exists; the stock fallback when it does not. The ramp
## sizes carry the hierarchy until a real face ships -- this is the honest part of "no font asset yet".
static func font_for(tokens: Dictionary, key: String) -> Font:
	var path: String = String(tokens.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		var f: Font = load(path)
		if f != null:
			return f
	return ThemeDB.fallback_font


## The tracked caps of the overline: the body face with `spacing_glyph` between letters -- the eyebrow
## treatment faked until a display face ships. Verified on a probe: spacing 4 widens "SETTINGS" at 13px
## from 60 to 88 canvas px.
static func font_tracked(tokens: Dictionary) -> Font:
	var fv := FontVariation.new()
	fv.base_font = font_for(tokens, "body_font")
	fv.spacing_glyph = int(tokens["overline_track"])
	return fv


## The display title on the same face, emboldened -- the serif-feel fake the token header owns up to.
static func font_display(tokens: Dictionary) -> Font:
	var fv := FontVariation.new()
	fv.base_font = font_for(tokens, "display_font")
	fv.variation_embolden = 0.55
	return fv


## One `Theme` for the whole page tree: a named variation per surface and per TYPE RUNG, so a row, a
## rail tab, the overline and the plate can disagree without per-node overrides. Geometry stays in
## `SettingsControl`; everything that says what a thing looks like lives here.
static func make_theme(tokens: Dictionary) -> Theme:
	var t := Theme.new()
	var ink: Color = tokens["ink"]
	t.set_color("font_color", "Label", ink)
	t.set_color("font_color", "Button", ink)
	t.set_font("font", "Label", font_for(tokens, "body_font"))
	t.set_font("font", "Button", font_for(tokens, "body_font"))
	_plate_type(t, "PagePlate", tokens["plate"], tokens["edge"], float(tokens["radius"]), tokens["shadow"])
	_detail_type(t, tokens)
	_rule_type(t, tokens["rule"])
	_label_type(t, "PageOverline", font_tracked(tokens), int(tokens["overline_size"]), tokens["ink_dim"])
	_label_type(t, "PageTitle", font_display(tokens), int(tokens["display_size"]), ink)
	_label_type(t, "RowLabel", font_for(tokens, "body_font"), int(tokens["body_size"]), tokens["ink_dim"])
	_label_type(t, "NoteLabel", font_for(tokens, "body_font"), int(tokens["small_size"]), tokens["ink_faint"])
	_label_type(t, "NumLabel", font_for(tokens, "body_font"), int(tokens["body_size"]), ink)
	_rail_tab_type(t, tokens)
	_button_type(t, "Chip", tokens)
	_button_type(t, "ChipWarn", tokens, true)
	_slider_type(t, tokens)
	# A custom type name is INVISIBLE to the theme lookup until its base is declared -- without these,
	# a "PagePlate" PanelContainer resolves straight to the class's default panel (verified on a
	# capture: the plate drew the stock translucent panel, not this fill).
	for pair: Array in [["PagePlate", "PanelContainer"],
			["PageDetail", "PanelContainer"], ["PageRule", "PanelContainer"],
			["RailTab", "Button"], ["Chip", "Button"], ["ChipWarn", "Button"],
			["PageOverline", "Label"], ["PageTitle", "Label"], ["RowLabel", "Label"],
			["NoteLabel", "Label"], ["NumLabel", "Label"]]:
		t.set_type_variation(StringName(pair[0]), StringName(pair[1]))
	return t


## A PanelContainer variation: fill, hairline border, and a soft shadow -- raised off the dimmed
## world rather than outlined, as a StyleBox so the engine draws it.
static func _plate_type(t: Theme, name_: StringName, fill: Color, edge: Color, radius: float, shadow: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = shadow
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	t.set_stylebox("panel", name_, sb)


## The detail note as a footnote block, not a card: no fill, a hairline rule above, the small print
## under it -- the typeset version of "this row explains itself".
static func _detail_type(t: Theme, tokens: Dictionary) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = tokens["rule"]
	sb.border_width_top = 1
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 2.0
	t.set_stylebox("panel", "PageDetail", sb)


## The hairline itself, as a PanelContainer skin so its colour rides the skin swap like everything
## else: `SettingsControl` gives it only a height (or a width, for the vertical rule beside the rail).
static func _rule_type(t: Theme, rule: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = rule
	t.set_stylebox("panel", "PageRule", sb)


## A Label variation: the type rungs the page is built from -- tracked overline, display title, dim
## row verbs, faint notes, and the numeral column.
static func _label_type(t: Theme, name_: StringName, font: Font, size: int, color: Color) -> void:
	t.set_font("font", name_, font)
	t.set_font_size("font_size", name_, size)
	t.set_color("font_color", name_, color)


## The rail tab as running text, not a chip: nothing drawn until hovered (a faint lift), and the
## SELECTED tab reads through a two-pixel accent rule under its word -- the same "input is connected
## here" the gold already means, carried as an underline instead of a filled box. Pressed is the
## selected state because the tabs are toggle_mode.
static func _rail_tab_type(t: Theme, tokens: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.content_margin_left = 2.0
	normal.content_margin_right = 2.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tokens["row_lit"], 0.55)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = tokens["accent"]
	pressed.border_width_bottom = 2
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = tokens["accent_pale"]
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.set_expand_margin_all(3.0)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "RailTab", {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus}[state])
	t.set_color("font_color", "RailTab", tokens["ink_dim"])
	t.set_color("font_hover_color", "RailTab", tokens["ink"])
	t.set_color("font_pressed_color", "RailTab", tokens["ink"])
	t.set_color("font_focus_color", "RailTab", tokens["ink"])
	t.set_font("font", "RailTab", font_for(tokens, "body_font"))
	t.set_font_size("font_size", "RailTab", int(tokens["rail_size"]))


## A Button variation as a QUIET PILL: the filled well stays, but the corner runs to the full radius
## of the chip's height so the control reads as a typeset pill rather than a drawn box. The four
## states the painter drew by hand: normal well, hover lift, pressed gold, focus RINGED from outside.
static func _button_type(t: Theme, name_: StringName, tokens: Dictionary, warn: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = tokens["row"] if not warn else Color(tokens["warn"], 0.22)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = tokens["row_lit"]
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tokens["accent"]
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = tokens["accent_pale"]
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(16)
	focus.set_expand_margin_all(3.0)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, name_, {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus}[state])
	t.set_color("font_color", name_, tokens["warn"] if warn else tokens["ink"])
	t.set_color("font_hover_color", name_, tokens["ink"])
	t.set_color("font_pressed_color", name_, tokens["ink_on_accent"])
	t.set_color("font_focus_color", name_, tokens["ink"])
	t.set_font("font", name_, font_for(tokens, "body_font"))
	t.set_font_size("font_size", name_, int(tokens["body_size"]))


## The HSlider's track and grabber, tokenized: a recessed bed, a brass fill, a grab that reads as a
## handled part rather than a glow.
static func _slider_type(t: Theme, tokens: Dictionary) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = tokens["track"]
	track.set_corner_radius_all(3)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = tokens["accent"]
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	var grab := StyleBoxFlat.new()
	grab.bg_color = tokens["ink"]
	grab.set_corner_radius_all(6)
	t.set_stylebox("grabber", "HSlider", grab)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = tokens["accent_pale"]
	t.set_stylebox("grabber_highlight", "HSlider", grab_hi)
