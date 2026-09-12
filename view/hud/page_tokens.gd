class_name PageTokens
extends RefCounted

## THE MODAL PAGE'S TWO SKINS (D0632): token sets for the frame-pick, consumed by `SettingsControl`'s
## Theme builder. The Hybrid ruling keeps the painter HUD in CanvasItem space and gives the modal page
## a real Control tree -- so the tokens here are Theme vocabulary (StyleBoxFlat colours, font colours,
## type sizes), not painter literals.
##
## THE MEASURED RULE BOTH SKINS OBEY: nothing in the UI brighter than lit rock -- measured on HUD
## furniture over the world (ui_theme.gd's header keeps the provenance). A MODAL is the exception the
## rule's own measurement permits: the scrim suppresses the world behind the page, so PAPER's light
## plate does not compete with the play space the way a bright chip over it would.
##
## THE KNOWN GAP, named rather than hidden: no font asset ships in this repo, so every size below is a
## ramp on `ThemeDB.fallback_font`. The 2026 delta in the reference frames is a serif display face over
## a tabular sans; `display_font`/`body_font` are honoured when a path exists so the asset can land
## without a code change, but picking and licensing the faces is a director call, not a session's.
##
## `rail`, `row` and `chip` are the surfaces type prints on; the pairings are the contrast contract --
## `ink` lives on `plate`/`row_lit`, `accent` marks only what input is connected to (the gold rule,
## unchanged from ui_theme.gd: it never labels and never counts).

const INSTRUMENT: Dictionary = {
	"name": "instrument",
	"scrim": Color(0.02, 0.025, 0.04, 0.42),
	"plate": Color(0.066, 0.075, 0.10, 0.97),        ## the rig's panel, near-opaque
	"rail": Color(0.043, 0.049, 0.070, 0.92),
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
	"radius": 8.0,
	"display_size": 30,                              ## canvas px: the tracked head
	"body_size": 20,                                 ## canvas px: rows, labels
	"small_size": 16,                                ## detail plate, footer legend
	"rail_size": 14,                                 ## rail slot captions
	"display_font": "res://assets/fonts/display_serif.ttf",
	"body_font": "res://assets/fonts/body_sans.ttf",
}

const PAPER: Dictionary = {
	"name": "paper",
	"scrim": Color(0.10, 0.08, 0.05, 0.50),          ## warmer dim: the world goes amber, not black
	"plate": Color(0.909, 0.874, 0.796, 0.985),      ## #E8DFCB -- the field notebook's leaf
	"rail": Color(0.863, 0.824, 0.722, 1.0),         ## #DCD2B8
	"edge": Color(0.541, 0.494, 0.388),              ## worn edge, like a much-handled cover
	"shadow": Color(0.20, 0.16, 0.10, 0.40),         ## warm dark: the leaf sits off the table
	"row": Color(0.796, 0.749, 0.616, 1.0),          ## #CBBF9D chip well
	"row_lit": Color(0.909, 0.847, 0.671, 1.0),      ## lifted leaf for hover/focus
	"ink": Color(0.169, 0.153, 0.125),               ## #2B2720 ink
	"ink_dim": Color(0.361, 0.333, 0.275),           ## #5C5546
	"ink_faint": Color(0.478, 0.447, 0.376),         ## #7A7260
	"ink_on_accent": Color(0.13, 0.10, 0.05),
	"accent": Color(0.541, 0.416, 0.173),            ## #8A6A2C: brass on paper needs depth, not lift
	"accent_pale": Color(0.35, 0.27, 0.12),
	"warn": Color(0.66, 0.29, 0.16),                 ## #A84A28: stamped in red-brown
	"track": Color(0.72, 0.68, 0.57, 1.0),
	"radius": 4.0,                                   ## paper wants square-er corners than the panel
	"display_size": 30,
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


## One `Theme` for the whole page tree: a named variation per surface so a row, a rail tab and the
## plate can disagree without per-node overrides. `Label`/`Button`/`HSlider` read their colours from
## here; geometry stays in `SettingsControl`.
static func make_theme(tokens: Dictionary) -> Theme:
	var t := Theme.new()
	var ink: Color = tokens["ink"]
	t.set_color("font_color", "Label", ink)
	t.set_color("font_color", "Button", ink)
	t.set_font("font", "Label", font_for(tokens, "body_font"))
	t.set_font("font", "Button", font_for(tokens, "body_font"))
	_plate_type(t, "PagePlate", tokens["plate"], tokens["edge"], float(tokens["radius"]), tokens["shadow"])
	_plate_type(t, "PageRail", tokens["rail"], tokens["edge"], float(tokens["radius"]), Color.TRANSPARENT)
	_button_type(t, "RailTab", tokens)
	_button_type(t, "Chip", tokens)
	_button_type(t, "ChipWarn", tokens, true)
	_slider_type(t, tokens)
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
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	t.set_stylebox("panel", name_, sb)


## A Button variation with the four states the painter drew by hand: normal well, hover lift, pressed
## gold, focus RINGED from outside (the ring is `focus`, not a border -- outside the control's rect).
static func _button_type(t: Theme, name_: StringName, tokens: Dictionary, warn: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = tokens["row"] if not warn else Color(tokens["warn"], 0.22)
	normal.set_corner_radius_all(int(float(tokens["radius"]) * 0.5))
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
	focus.set_corner_radius_all(int(float(tokens["radius"]) * 0.5) + 2)
	focus.set_expand_margin_all(3.0)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, name_, {"normal": normal, "hover": hover, "pressed": pressed, "focus": focus}[state])
	t.set_color("font_color", name_, tokens["warn"] if warn else tokens["ink"])
	t.set_color("font_hover_color", name_, tokens["ink"])
	t.set_color("font_pressed_color", name_, tokens["ink_on_accent"])
	t.set_color("font_focus_color", name_, tokens["ink"])
	t.set_font("font", name_, font_for(tokens, "body_font"))


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
