extends SceneTree

## LOCAL DESIGN TOOL — draws the PROPOSAL for the settings page over a real frame of the real game, so the
## look can be judged against the thing it would replace rather than against a description of it. Outputs
## _mock_settings.png (gitignored, like every _moment_*.png).
##
## Run WITHOUT --headless (needs a real GL context — headless is the dummy renderer and saves blank frames):
##   godot --path . --script res://tools/mock_settings.gd
##
## WHY THIS SCREEN AND NOT THE COUNTER. `tools/mock_bazaar.gd` put three proposals over a real frame and the
## Bazaar we have today came out of that round (docs/FEEL_GAP.md §the counter). Settings never went through
## it. The seven-rung menu matrix photographs the consequence: the two screens are the same game's two
## modals and they share nothing.
##
##                       THE BAZAAR                        SETTINGS
##   plate               _round_rect, r=8, alpha 0.985      draw_rect, hard corners, alpha 0.90
##   ground              scrim 0.42, tinted, world BLURRED  scrim 0.55, pure black, world sharp
##   structure           rail -> columns -> detail plate    two columns of text
##   the selected thing  drawn large, named, priced         nothing is selected
##   opened by           E / T                              ESC
##   drawn by            _draw_inventory_overlay            _draw_settings_overlay
##
## MNU-26's complaint in one line: it is opened by a different key, drawn by a different path, and shares
## none of the panel's grammar. So the proposal is not a repaint. It is the same counter with a fourth tab.
##
## WHAT THE PROPOSAL ACTUALLY CHANGES, which is the part a screenshot can argue about:
##
##   1. SETTINGS IS A TAB. The rail already teaches "1 2 3 opens a face of this object". A fourth face
##      costs one glyph and removes an entire second modal grammar from the game.
##   2. THE BINDINGS GET A DETAIL PLATE. Today twenty-two rows carry equal weight and remapping is
##      "click the small chip on the right of the row you want". The counter's answer to exactly this
##      problem was to make the SELECTED thing large, say what it is for, and put the verb on a real
##      button. A key binding wants that more than a machine does: the row says `grapple  F`, and the
##      plate says what grapple DOES, which is the sentence a first-timer is actually short of.
##   3. FEEL AND AUDIO SIT BESIDE THE KEYS, not above them, because WORKS already established the
##      two-column shape (the counter builds | THE RACK sells) and this page has the same shape:
##      the keys are a long list, the levels are a short one.
##
## The geometry is READ FROM `Hud`, not copied: BAZAAR_SIZE, BAZAAR_RAIL, BAZAAR_HEAD, BAZAAR_DETAIL. A
## mock that invents its own numbers is a picture of a different object, and the whole argument here is
## that this IS the same object.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 50
const CANVAS := Vector2(640.0, 360.0)

# The counter's palette, sampled from hud.gd rather than re-chosen, for the same reason as the geometry.
const PLATE := Color(0.062, 0.070, 0.094, 0.985)
const RAIL_BG := Color(0.043, 0.049, 0.070, 0.92)
const WELL := Color(0.0, 0.0, 0.0, 0.22)
const ACCENT := Color(0.80, 0.66, 0.30)
const ACCENT_HI := Color(0.949, 0.831, 0.549)
const TEXT := Color(0.80, 0.83, 0.89)
const DIM := Color(0.54, 0.58, 0.66)
const FAINT := Color(0.36, 0.39, 0.45)
const LIT_ROW := Color(0.145, 0.129, 0.082)

## The list, with the sentence each binding is missing. This is the proposal's real content: a key legend
## that says what the key is FOR is a different document from a key legend that says which key it is.
const ROWS: Array[Array] = [
	["move left", "A", ""], ["move right", "D", ""],
	["climb up", "W", "ladders, ropes and lift shafts"],
	["climb down", "S", ""],
	["jump", "SPACE", ""],
	["mine (hold)", "LMB", "hold on rock; the pickaxe decides what breaks"],
	["grapple", "F", "throw a line at what you are aiming at — it takes your weight, and pays out as you fall"],
	["build / place", "RMB", "puts the held thing where you are aiming"],
	["drop / feed", "Q", "into a machine's mouth if one is there"],
	["pack", "E", "the counter: what you carry, what you can build"],
	["research / config", "R", ""],
	["map", "M", "press twice for the whole world"],
	["tech tree", "T", ""], ["mute sound", "N", ""],
	["dashboard", "G", ""], ["help", "H", ""],
	["pause", "P", ""], ["game speed", "Period", ""],
	["zoom", "Z", ""], ["quicksave", "F5", ""],
	["quickload", "F9", ""], ["clear dig plan", "X", ""],
]
## The binding the plate is showing. Chosen deliberately: `grapple` is the one binding whose key tells you
## nothing at all about what it does, which is the case the detail plate exists for.
const PICKED: int = 6

var _font: Font


func _initialize() -> void:
	_font = ThemeDB.fallback_font
	await _render()
	quit()


func _render() -> void:
	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	# The game's own HUD would fight the mock for the same pixels, and the point of the mock is the page.
	main._hud.visible = false
	await process_frame
	await process_frame

	var shot: Image = get_root().get_texture().get_image()
	var blur: ImageTexture = ImageTexture.create_from_image(_blurred(shot, 8))

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.scale = Vector2(MainView.HUD_SCALE, MainView.HUD_SCALE)
	var mock := Control.new()
	mock.size = CANVAS
	mock.draw.connect(func() -> void: _draw_mock(mock, blur))
	layer.add_child(mock)
	get_root().add_child(layer)
	for _i: int in 4:
		await process_frame

	var out: Image = get_root().get_texture().get_image()
	var path: String = "res://_mock_settings.png"
	out.save_png(ProjectSettings.globalize_path(path))
	print("wrote %s (%dx%d)" % [path, out.get_width(), out.get_height()])


## A real box blur, done the cheap honest way: shrink the frame and grow it back. The counter already gets
## this treatment in play (`MainView._bazaar_blur`); the settings page does not, and the difference is half
## of why one reads as being in front of the world and the other as a sheet over a screenshot.
func _blurred(src: Image, factor: int) -> Image:
	var img: Image = Image.new()
	img.copy_from(src)
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.resize(maxi(w / factor, 8), maxi(h / factor, 8), Image.INTERPOLATE_LANCZOS)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


func _draw_mock(c: Control, blur: ImageTexture) -> void:
	c.draw_texture_rect(blur, Rect2(Vector2.ZERO, CANVAS), false)
	c.draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42))
	_vignette(c, 0.5)

	# --- the shell, on the counter's own numbers -------------------------------------------------------
	var size := Hud.BAZAAR_SIZE
	var origin := Vector2((CANVAS.x - size.x) * 0.5, (CANVAS.y - size.y) * 0.5)
	var panel := Rect2(origin, size)
	_shadow(c, panel, 12, 0.34)
	_round_rect(c, panel, 8.0, PLATE)
	_sheen(c, panel)

	var inner_x: float = origin.x + Hud.BAZAAR_RAIL + Hud.BAZAAR_PAD
	var inner_w: float = size.x - Hud.BAZAAR_RAIL - Hud.BAZAAR_PAD * 2.0
	var body_h: float = size.y - Hud.BAZAAR_HEAD - Hud.BAZAAR_FOOT
	var content := Rect2(inner_x, origin.y + Hud.BAZAAR_HEAD, inner_w, body_h - Hud.BAZAAR_DETAIL - 8.0)
	var detail := Rect2(inner_x, content.end.y + 8.0, inner_w, Hud.BAZAAR_DETAIL)

	_rail(c, origin, size)
	# The head, in the counter's voice: the object's name, then the face you are looking at.
	_tracked(c, "BAZAAR", Vector2(inner_x, origin.y + 30.0), 15, 3.0, TEXT)
	_tracked(c, "KEYS", Vector2(inner_x + 92.0, origin.y + 30.0), 15, 3.0, FAINT)

	# --- left: THE KEYS, two columns of eleven ---------------------------------------------------------
	var keys_w: float = 330.0
	var col_w: float = (keys_w - 14.0) * 0.5
	_tracked(c, "THE KEYS", Vector2(content.position.x, content.position.y + 10.0), 9, 2.0, ACCENT)
	var per_col: int = int(ceil(float(ROWS.size()) * 0.5))
	for i: int in ROWS.size():
		var col: int = i / per_col
		var x: float = content.position.x + float(col) * (col_w + 14.0)
		var y: float = content.position.y + 22.0 + float(i % per_col) * 14.6
		var row := Rect2(x, y, col_w, 14.0)
		if i == PICKED:
			_round_rect(c, row, 3.0, LIT_ROW)
			c.draw_rect(Rect2(row.position, Vector2(2.0, row.size.y)), ACCENT)
		elif i % 2 == 1:
			c.draw_rect(row, Color(1.0, 1.0, 1.0, 0.016))
		c.draw_string(_font, Vector2(x + 7.0, y + 10.5), str(ROWS[i][0]), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, TEXT if i == PICKED else DIM)
		_cap(c, str(ROWS[i][1]), Vector2(row.end.x - 5.0, y + 1.0), i == PICKED)

	# --- right: THE FEEL, the short list beside the long one -------------------------------------------
	var fx: float = content.position.x + keys_w + 14.0
	var fw: float = content.end.x - fx
	_tracked(c, "THE FEEL", Vector2(fx, content.position.y + 10.0), 9, 2.0, ACCENT)
	var fy: float = content.position.y + 26.0
	for pair: Array in [["master", 1.0], ["sound", 1.0], ["ambience", 0.7], ["music", 0.4]]:
		c.draw_string(_font, Vector2(fx, fy + 8.0), str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
		_slider(c, Rect2(fx + 62.0, fy + 1.0, fw - 62.0, 8.0), float(pair[1]))
		fy += 17.0
	fy += 8.0
	for pair: Array in [["screen shake", "ON"], ["auto-pickup", "ON"], ["zoom", "1.00x"], ["sound", "MUTED"]]:
		c.draw_string(_font, Vector2(fx, fy + 9.0), str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
		_toggle(c, Vector2(content.end.x, fy), str(pair[1]), str(pair[1]) != "MUTED")
		fy += 18.0

	# --- the detail plate: the selected binding, and what it is FOR ------------------------------------
	_round_rect(c, detail, 6.0, Color(1.0, 1.0, 1.0, 0.035))
	var art := Rect2(detail.position + Vector2(10.0, 10.0), Vector2(68.0, 68.0))
	_round_rect(c, art, 6.0, Color(0.0, 0.0, 0.0, 0.30))
	c.draw_circle(art.get_center(), 30.0, Color(0.949, 0.831, 0.549, 0.05))
	_cap(c, str(ROWS[PICKED][1]), Vector2(art.get_center().x + 15.0, art.get_center().y - 11.0), true, 2.0)
	var dx: float = detail.position.x + 92.0
	_tracked(c, str(ROWS[PICKED][0]).to_upper(), Vector2(dx, detail.position.y + 24.0), 13, 2.4, ACCENT_HI)
	# WRAPPED, NOT CLIPPED. `draw_string` with a width TRUNCATES; the first render of this mock cut the
	# grapple's sentence at "it takes your weight, a" — a page arguing that the detail plate is where the
	# explanation goes, with the explanation running off the edge of the plate.
	c.draw_multiline_string(_font, Vector2(dx, detail.position.y + 42.0), str(ROWS[PICKED][2]),
		HORIZONTAL_ALIGNMENT_LEFT, detail.size.x - 250.0, 9, 2, DIM)
	c.draw_string(_font, Vector2(dx, detail.end.y - 14.0), "held: your weight swings from it · cut it with the same key",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)
	# The verb as a real button carrying the key that runs it — the counter's BUILD / RESEARCH, in the one
	# place this page has never had one. Remapping stops being "hit the small chip" and becomes a decision
	# you make about the thing the plate is describing.
	var btn := Rect2(detail.end.x - 132.0, detail.position.y + 46.0, 122.0, 26.0)
	_round_rect(c, btn, 5.0, Color(0.145, 0.129, 0.082))
	c.draw_rect(Rect2(btn.position, Vector2(btn.size.x, 1.0)), Color(1.0, 0.94, 0.82, 0.10))
	_tracked(c, "REBIND", Vector2(btn.position.x + 16.0, btn.position.y + 17.0), 11, 2.0, ACCENT_HI)
	c.draw_string(_font, Vector2(btn.end.x - 30.0, btn.position.y + 17.0), "ENTER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)
	c.draw_string(_font, Vector2(detail.end.x - 132.0, detail.position.y + 32.0),
		"reset every key to default", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)

	# --- the foot: the same legend the counter carries, with the fourth digit on it ---------------------
	c.draw_string(_font, Vector2(inner_x, panel.end.y - 5.0), "arrows  pick     1 2 3 4  tab     E  close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FAINT)


## The rail with FOUR faces. The fourth slot costs nothing: the rail is 348 tall and three tabs use 242 of
## it, so KEYS lands at y+242 with room under it — which is the cheapest possible evidence that settings
## was always meant to live here.
func _rail(c: Control, origin: Vector2, size: Vector2) -> void:
	var rail := Rect2(origin, Vector2(Hud.BAZAAR_RAIL, size.y))
	_round_rect_left(c, rail, 8.0, RAIL_BG)
	for i: int in 4:
		var y: float = rail.position.y + 62.0 + float(i) * 58.0
		var on: bool = i == 3
		var box := Rect2(rail.position.x + 9.0, y, 38.0, 38.0)
		if on:
			_round_rect(c, box, 6.0, LIT_ROW)
			c.draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), ACCENT)
		_rail_glyph(c, box.get_center(), i, on)
		var label: String = ["PACK", "WORKS", "BENCH", "KEYS"][i]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		c.draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + 48.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, TEXT if on else FAINT)
		c.draw_string(_font, Vector2(box.position.x + 1.0, y + 10.0), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.34, 0.30, 0.22) if on else Color(0.24, 0.26, 0.31))


## Three of these are the counter's own glyphs; the fourth is the proposal. A key drawn as a key — bow,
## shank, two teeth — so the rail stays four pictures rather than three pictures and a word.
func _rail_glyph(c: Control, at: Vector2, kind: int, on: bool) -> void:
	var col: Color = ACCENT_HI if on else Color(0.40, 0.43, 0.50)
	match kind:
		0:
			c.draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(16.0, 11.0)), col)
			c.draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 1.8)
		1:
			c.draw_arc(at, 6.5, 0.0, TAU, 20, col, 2.2)
			c.draw_circle(at, 2.0, col)
		2:
			for k: int in 3:
				c.draw_rect(Rect2(at + Vector2(-8.0, -6.0 + float(k) * 5.0), Vector2(16.0, 2.4)), col)
		_:
			c.draw_arc(at + Vector2(-4.0, -3.0), 4.2, 0.0, TAU, 16, col, 2.0)
			c.draw_rect(Rect2(at + Vector2(-1.0, -0.6), Vector2(10.0, 2.2)), col)
			c.draw_rect(Rect2(at + Vector2(5.0, 1.6), Vector2(2.2, 4.0)), col)
			c.draw_rect(Rect2(at + Vector2(8.6, 1.6), Vector2(2.2, 2.6)), col)


## A KEY CAP, not a bordered rectangle: a raised face with a lip under it. The current page draws its
## bindings as `draw_rect` + a 1px black outline, which is the single detail that reads most like 2003.
func _cap(c: Control, text: String, right_top: Vector2, lit: bool, scale: float = 1.0) -> void:
	var s: int = int(round(9.0 * scale))
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + 11.0 * scale
	var h: float = 12.0 * scale
	var box := Rect2(right_top.x - w, right_top.y, w, h)
	_round_rect(c, box.grow(-0.0), 2.5 * scale, Color(0.16, 0.17, 0.21) if lit else Color(0.115, 0.125, 0.155))
	c.draw_rect(Rect2(box.position + Vector2(1.0, h - 2.0 * scale), Vector2(w - 2.0, 1.6 * scale)),
		Color(0.0, 0.0, 0.0, 0.45))
	c.draw_rect(Rect2(box.position + Vector2(1.0, 0.0), Vector2(w - 2.0, 1.0)),
		Color(1.0, 1.0, 1.0, 0.10))
	c.draw_string(_font, Vector2(box.position.x + 5.5 * scale, box.position.y + 9.0 * scale), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, s, ACCENT_HI if lit else TEXT)


func _slider(c: Control, bar: Rect2, v: float) -> void:
	_round_rect(c, bar, 3.0, WELL)
	_round_rect(c, Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), 3.0, ACCENT)
	c.draw_circle(Vector2(bar.position.x + bar.size.x * v, bar.get_center().y), 3.4, ACCENT_HI)


func _toggle(c: Control, right_top: Vector2, text: String, on: bool) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14.0
	var box := Rect2(right_top.x - w, right_top.y, w, 14.0)
	_round_rect(c, box, 7.0, LIT_ROW if on else Color(0.09, 0.10, 0.13))
	c.draw_string(_font, Vector2(box.position.x + 7.0, box.position.y + 10.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ACCENT_HI if on else FAINT)


# --- the counter's own surface tricks, so the mock is made of the same material ------------------------

func _round_rect(c: Control, r: Rect2, rad: float, col: Color) -> void:
	# StyleBoxFlat, exactly as `Hud._round_rect` does it, and not a hand-decomposed rect-plus-four-circles.
	# The hand version double-blends wherever the corner discs overlap the middle band, which is invisible
	# at the plate's 0.985 and produced four bright dots on the corners of a 0.035 detail plate — a mock
	# arguing for elevation, with a blending artefact on the one surface it was arguing about.
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.corner_detail = 8
	sb.draw(c.get_canvas_item(), r)


func _round_rect_left(c: Control, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(rad)
	sb.corner_radius_bottom_left = int(rad)
	sb.corner_detail = 8
	sb.draw(c.get_canvas_item(), r)


func _shadow(c: Control, r: Rect2, steps: int, a: float) -> void:
	for i: int in steps:
		var t: float = float(i + 1) / float(steps)
		_round_rect(c, r.grow(t * 12.0), 8.0 + t * 12.0, Color(0.0, 0.0, 0.0, a * (1.0 - t) * 0.16))


func _sheen(c: Control, r: Rect2) -> void:
	for i: int in 10:
		var t: float = float(i) / 9.0
		c.draw_rect(Rect2(r.position.x + 2.0, r.position.y + 2.0 + t * 46.0, r.size.x - 4.0, 5.0),
			Color(1.0, 0.94, 0.82, 0.020 * (1.0 - t)))
	c.draw_rect(Rect2(r.position.x + 8.0, r.position.y, r.size.x - 16.0, 1.0), Color(1.0, 1.0, 1.0, 0.075))


func _vignette(c: Control, a: float) -> void:
	for i: int in 12:
		var t: float = float(i) / 11.0
		var g: float = t * 46.0
		c.draw_rect(Rect2(Vector2(g, g), CANVAS - Vector2(g, g) * 2.0),
			Color(0.0, 0.0, 0.0, a * 0.03 * (1.0 - t)), false, 4.0)


func _tracked(c: Control, text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		c.draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track
