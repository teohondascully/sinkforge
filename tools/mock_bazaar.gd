extends SceneTree

## LOCAL DESIGN TOOL — draws PROPOSAL mockups of the Bazaar counter over a real frame of the real game, so
## a look can be judged against the thing it would replace rather than against a description of it. Outputs
## _mock_bazaar_<variant>.png (gitignored, like every _moment_*.png).
##
## Run WITHOUT --headless (needs a real GL context — headless is the dummy renderer and saves blank frames):
##   godot --path . --script res://tools/mock_bazaar.gd -- a
##
## Every mock draws through the SAME pipeline the HUD does — a CanvasLayer scaled by MainView.HUD_SCALE over
## a 640x360 authoring canvas — so what you see is what the panel would actually look like, at the real type
## sizes, with the real item glyphs, over the real world. Nothing here is a Photoshop promise.
##
## The backdrop is the live frame, snapshotted and then BLURRED in-image, because the treatment of what is
## behind the counter is half of each proposal: today the world is dimmed 38% and left sharp, which reads as
## a screenshot with a sheet over it. A blurred backdrop is the single cheapest thing that makes a panel look
## like it is in front of something rather than pasted on top of it — and it is a two-line shader in the real
## build (`scenes/main.gd` already runs a full-screen FX layer).
##
##   a — THE LEDGER    a physical object: slate, brass frame, rivets, file tabs, a lit detail plate.
##   b — THE WORKBENCH modern dark product UI: icon rail, cards, one accent, big type scale, real buttons.
##   c — THE STALL     no panel at all: a bottom counter slab, goods on a shelf, the world left visible.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 50
const CANVAS := Vector2(640.0, 360.0)

# --- palette ------------------------------------------------------------------------------------------
# Warmer and deeper than the current UI constants on purpose: the counter is lamp-lit, and every surface in
# it should be able to say which way the light is coming from.
const INK := Color(0.055, 0.062, 0.086)
const SLATE := Color(0.086, 0.098, 0.133)
const SLATE_HI := Color(0.121, 0.137, 0.184)
const WELL := Color(0.043, 0.049, 0.070)
const BRASS := Color(0.792, 0.639, 0.302)
const BRASS_HI := Color(0.949, 0.831, 0.549)
const BRASS_DIM := Color(0.451, 0.365, 0.180)
const TEXT := Color(0.847, 0.867, 0.906)
const DIM := Color(0.514, 0.549, 0.616)
const FAINT := Color(0.325, 0.353, 0.412)
const GOOD := Color(0.482, 0.796, 0.518)
const BAD := Color(0.804, 0.427, 0.376)

var _font: Font = ThemeDB.fallback_font
var _variant: String = "a"


func _initialize() -> void:
	var uargs: PackedStringArray = OS.get_cmdline_user_args()
	_variant = (uargs[0] if uargs.size() > 0 else "a")
	await _render()
	quit(0)


func _render() -> void:
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	# The game's own HUD would fight the mock for the same pixels, and the point of the mock is the counter.
	main._hud.visible = false
	await process_frame
	await process_frame

	var shot: Image = get_root().get_texture().get_image()
	var tex: ImageTexture = ImageTexture.create_from_image(_blurred(shot, 12 if _variant == "b" else 7))
	var sharp: ImageTexture = ImageTexture.create_from_image(shot)

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.scale = Vector2(MainView.HUD_SCALE, MainView.HUD_SCALE)
	var mock := Control.new()
	mock.size = CANVAS
	mock.draw.connect(func() -> void: _draw_mock(mock, tex, sharp))
	layer.add_child(mock)
	get_root().add_child(layer)
	for _i: int in 4:
		await process_frame

	var out: Image = get_root().get_texture().get_image()
	var path: String = "res://_mock_bazaar_%s.png" % _variant
	out.save_png(ProjectSettings.globalize_path(path))
	print("wrote %s (%dx%d)" % [path, out.get_width(), out.get_height()])


## A real box blur, done the cheap honest way: shrink the frame and grow it back. Lanczos down keeps the
## composition, bilinear up smears it.
func _blurred(src: Image, factor: int) -> Image:
	var img: Image = Image.new()
	img.copy_from(src)
	var w: int = img.get_width()
	var h: int = img.get_height()
	img.resize(maxi(w / factor, 8), maxi(h / factor, 8), Image.INTERPOLATE_LANCZOS)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return img


func _draw_mock(c: Control, blur: ImageTexture, sharp: ImageTexture) -> void:
	match _variant:
		"b":
			_variant_b(c, blur)
		"c":
			_variant_c(c, sharp)
		_:
			_variant_a(c, blur)


# =========================================================================================================
# A — THE LEDGER. The counter is a physical object you are standing at: a slate plate in a brass frame,
# rivets at the corners, tabs cut into the top edge like a ledger's, and a lamp above and to the left. The
# right two-fifths is a DETAIL PLATE — the single change that both kills the dead space and makes buying
# feel like a decision, because the thing you are about to buy is finally drawn large enough to want.
# =========================================================================================================
func _variant_a(c: Control, blur: ImageTexture) -> void:
	c.draw_texture_rect(blur, Rect2(Vector2.ZERO, CANVAS), false)
	c.draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.55))
	_vignette(c, 0.55)

	var panel := Rect2(30.0, 26.0, 580.0, 300.0)
	_drop(c, panel, 10, 0.30)
	# The plate: a vertical gradient, lit from the top, so it reads as a surface under a lamp rather than a
	# fill. Two colours and eight strips is the whole trick.
	_vgrad(c, panel, SLATE_HI, INK, 16)
	_frame(c, panel, BRASS, 2.0)
	c.draw_rect(panel.grow(-3.0), Color(0.0, 0.0, 0.0, 0.35), false, 1.0)
	for p: Vector2 in [panel.position + Vector2(7.0, 7.0), Vector2(panel.end.x - 7.0, panel.position.y + 7.0),
			Vector2(panel.position.x + 7.0, panel.end.y - 7.0), panel.end - Vector2(7.0, 7.0)]:
		c.draw_circle(p, 2.2, BRASS_DIM)
		c.draw_circle(p - Vector2(0.4, 0.4), 1.2, BRASS_HI)

	# Header: title tracked wide, and the tabs cut into the top edge as brass files.
	_tracked(c, "THE BAZAAR", panel.position + Vector2(16.0, 27.0), 15, 2.6, BRASS_HI)
	_tracked(c, "MARKET  ·  DEPTH 0m", panel.position + Vector2(17.0, 40.0), 8, 1.4, FAINT)
	var tx: float = panel.position.x + 232.0
	for i: int in 3:
		var name: String = ["PACK", "WORKS", "BENCH"][i]
		var tw: float = _w(name, 10) + 34.0
		var on: bool = i == 1
		var top: float = panel.position.y + (6.0 if on else 10.0)
		var bot: float = panel.position.y + 46.0
		var pts := PackedVector2Array([Vector2(tx + 7.0, top), Vector2(tx + tw - 7.0, top),
			Vector2(tx + tw, bot), Vector2(tx, bot)])
		c.draw_colored_polygon(pts, SLATE_HI if on else Color(0.075, 0.085, 0.113))
		c.draw_polyline(pts, BRASS if on else Color(0.20, 0.22, 0.27, 0.9), 1.0)
		if on:
			c.draw_rect(Rect2(tx + 6.0, top + 2.0, tw - 12.0, 1.5), BRASS_HI)
		_tracked(c, name, Vector2(tx + 17.0, bot - 14.0), 10, 1.6, TEXT if on else FAINT)
		tx += tw + 6.0
	c.draw_line(panel.position + Vector2(14.0, 47.0), Vector2(panel.end.x - 14.0, panel.position.y + 47.0),
		Color(0.30, 0.26, 0.18, 0.85), 1.0)

	# --- left: the list, on a recessed well so the rows sit IN the plate rather than on it ---
	var list := Rect2(panel.position.x + 14.0, panel.position.y + 56.0, 322.0, 208.0)
	_well(c, list)
	_tracked(c, "THE RACK", list.position + Vector2(10.0, 15.0), 9, 2.0, BRASS_DIM)
	_tracked(c, "cutting heads · kept forever", Vector2(list.end.x - 10.0 - _w("cutting heads · kept forever", 8), list.position.y + 15.0), 8, 0.0, FAINT)
	var rows: Array[Dictionary] = [
		{"id": &"broad_bit", "name": "Broad", "note": "2×2 — pulverises", "cost": "3 ingot · 12 stone", "state": 1},
		{"id": &"sinker_bit", "name": "Sinker", "note": "three straight down", "cost": "3 ingot · 8 wood", "state": 0},
		{"id": &"lance_bit", "name": "Lance", "note": "drives five, slow to recover", "cost": "5 ingot · 4 coal", "state": 0},
		{"id": &"wedge_bit", "name": "Wedge", "note": "splits eight along a seam", "cost": "8 ingot · 6 coal", "state": 2},
		{"id": &"scanner", "name": "Scanner", "note": "sonar — ore answers back", "cost": "6 ingot · 2 plate", "state": 0},
		{"id": &"rope", "name": "Rope coil ×20", "note": "the way back up", "cost": "2 ingot", "state": 0},
	]
	var ry: float = list.position.y + 24.0
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var row := Rect2(list.position.x + 5.0, ry, list.size.x - 10.0, 28.0)
		var picked: bool = i == 0
		if picked:
			_vgrad(c, row, Color(0.176, 0.157, 0.106), Color(0.106, 0.098, 0.078), 6)
			c.draw_rect(Rect2(row.position, Vector2(2.5, row.size.y)), BRASS_HI)
		elif i % 2 == 1:
			c.draw_rect(row, Color(1.0, 1.0, 1.0, 0.018))
		var icon := Rect2(row.position + Vector2(7.0, 3.0), Vector2(22.0, 22.0))
		c.draw_rect(icon, Color(0.0, 0.0, 0.0, 0.30))
		c.draw_rect(icon, Color(1.0, 1.0, 1.0, 0.06), false, 1.0)
		Visuals.draw_item(c, icon.get_center(), 16.0, r["id"])
		var locked: bool = int(r["state"]) == 2
		c.draw_string(_font, row.position + Vector2(36.0, 14.0), String(r["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FAINT if locked else (BRASS_HI if picked else TEXT))
		c.draw_string(_font, row.position + Vector2(36.0, 24.0), String(r["note"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)
		var cost: String = String(r["cost"])
		var col: Color = GOOD if int(r["state"]) == 0 or picked else (BAD if int(r["state"]) == 1 else FAINT)
		if locked:
			cost = "needs PROSPECTING"
		c.draw_string(_font, Vector2(row.end.x - 8.0 - _w(cost, 9), row.position.y + 18.0), cost,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
		ry += 30.0

	# --- right: the DETAIL PLATE. The dead space becomes the reason to look. ---
	var det := Rect2(panel.position.x + 346.0, panel.position.y + 56.0, 220.0, 208.0)
	_well(c, det)
	c.draw_rect(Rect2(det.position, Vector2(det.size.x, 82.0)), Color(0.098, 0.086, 0.055, 0.85))
	c.draw_line(det.position + Vector2(0.0, 82.0), Vector2(det.end.x, det.position.y + 82.0), BRASS_DIM, 1.0)
	# A lamp glow behind the goods, three rings — the cheapest way to say "this one is lit".
	for k: int in 3:
		c.draw_circle(det.position + Vector2(det.size.x * 0.5, 40.0), 34.0 - float(k) * 8.0,
			Color(0.85, 0.70, 0.35, 0.05 + float(k) * 0.02))
	Visuals.draw_item(c, det.position + Vector2(det.size.x * 0.5, 40.0), 42.0, &"broad_bit")
	_tracked(c, "BROAD BIT", det.position + Vector2(12.0, 98.0), 13, 1.8, BRASS_HI)
	c.draw_string(_font, det.position + Vector2(12.0, 114.0),
		"Takes a 2×2 the way you face. Everything", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	c.draw_string(_font, det.position + Vector2(12.0, 125.0),
		"it breaks is dust — hollow rooms with it,", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	c.draw_string(_font, det.position + Vector2(12.0, 136.0),
		"never veins.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	_tracked(c, "PRICE", det.position + Vector2(12.0, 154.0), 8, 1.6, FAINT)
	_cost_chip(c, det.position + Vector2(12.0, 160.0), &"ingot", "3", "8", true)
	_cost_chip(c, det.position + Vector2(78.0, 160.0), &"stone", "12", "24", true)
	# The verb as a real KEYCAP, lit, sitting where your eye already is.
	var buy := Rect2(det.position.x + 12.0, det.position.y + 184.0, det.size.x - 24.0, 20.0)
	_vgrad(c, buy, Color(0.612, 0.478, 0.196), Color(0.400, 0.310, 0.125), 6)
	c.draw_rect(buy, BRASS_HI, false, 1.0)
	_tracked(c, "ENTER   ·   BUY", buy.position + Vector2(buy.size.x * 0.5 - 42.0, 14.0), 10, 2.0,
		Color(0.10, 0.08, 0.05))

	_foot_a(c, panel)


func _foot_a(c: Control, panel: Rect2) -> void:
	var y: float = panel.end.y - 22.0
	c.draw_line(Vector2(panel.position.x + 14.0, y), Vector2(panel.end.x - 14.0, y),
		Color(0.30, 0.26, 0.18, 0.7), 1.0)
	var x: float = panel.position.x + 16.0
	for pair: Array in [[&"ingot", "8"], [&"iron_ingot", "3"], [&"ore", "24"], [&"coal", "12"], [&"stone", "24"]]:
		Visuals.draw_item(c, Vector2(x + 7.0, y + 13.0), 13.0, pair[0])
		c.draw_string(_font, Vector2(x + 17.0, y + 17.0), String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
		x += 17.0 + _w(String(pair[1]), 10) + 12.0
	var keys: String = "1 2 3  tab      E  close"
	c.draw_string(_font, Vector2(panel.end.x - 16.0 - _w(keys, 9), y + 17.0), keys,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FAINT)


# =========================================================================================================
# B — THE WORKBENCH. Not diegetic at all: a 2026 product UI with a game's palette. No border, no bevel, no
# 1px outline anywhere — depth comes from ELEVATION (shadow + surface tint) the way every modern dark UI
# does it. A vertical icon rail replaces the tab strip, rows become cards with air around them, and there is
# exactly one accent colour doing exactly one job (this is selected / this is affordable).
# =========================================================================================================
func _variant_b(c: Control, blur: ImageTexture) -> void:
	c.draw_texture_rect(blur, Rect2(Vector2.ZERO, CANVAS), false)
	c.draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.035, 0.039, 0.055, 0.72))

	var panel := Rect2(24.0, 22.0, 592.0, 316.0)
	_drop(c, panel, 14, 0.34)
	_rrect(c, panel, 8.0, Color(0.070, 0.078, 0.106, 0.985))
	# One hairline of light along the very top edge. It is the only "border" in the whole design.
	c.draw_rect(Rect2(panel.position.x + 8.0, panel.position.y, panel.size.x - 16.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.07))

	# --- the rail ---
	var rail := Rect2(panel.position, Vector2(58.0, panel.size.y))
	_rrect_left(c, rail, 8.0, Color(0.047, 0.055, 0.078, 0.9))
	for i: int in 3:
		var ry: float = rail.position.y + 58.0 + float(i) * 54.0
		var on: bool = i == 1
		var box := Rect2(rail.position.x + 9.0, ry, 40.0, 40.0)
		if on:
			_rrect(c, box, 6.0, Color(0.153, 0.137, 0.086))
			c.draw_rect(Rect2(rail.position.x, ry + 6.0, 3.0, 28.0), BRASS)
		_rail_glyph(c, box.get_center(), i, on)
		var label: String = ["PACK", "WORKS", "BENCH"][i]
		_tracked(c, label, Vector2(box.get_center().x - _w(label, 7) * 0.5 - 2.5, ry + 51.0), 7, 1.0,
			TEXT if on else FAINT)
	_tracked(c, "1", Vector2(rail.position.x + 26.0, rail.end.y - 12.0), 7, 0.0, FAINT)

	# --- head: title + a live resource strip, which is the thing every shop screen needs and this one
	# never had. It sits ABOVE the content, on its own line, so no list has to carry it. ---
	var head: Vector2 = panel.position + Vector2(76.0, 0.0)
	_tracked(c, "BAZAAR", head + Vector2(0.0, 32.0), 19, 3.0, TEXT)
	_tracked(c, "WORKS", head + Vector2(_w("BAZAAR", 19) + 40.0, 32.0), 19, 3.0, Color(0.25, 0.27, 0.33))
	var rx: float = panel.end.x - 20.0
	for pair: Array in [[&"stone", "24"], [&"coal", "12"], [&"ore", "24"], [&"iron_ingot", "3"], [&"ingot", "8"]]:
		var t: String = String(pair[1])
		var cw: float = _w(t, 10) + 26.0
		rx -= cw + 6.0
		_rrect(c, Rect2(rx, panel.position.y + 18.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(c, Vector2(rx + 11.0, panel.position.y + 28.0), 13.0, pair[0])
		c.draw_string(_font, Vector2(rx + 20.0, panel.position.y + 32.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)

	# --- cards ---
	_tracked(c, "MACHINES", head + Vector2(1.0, 58.0), 8, 2.2, FAINT)
	var cards: Array[Dictionary] = [
		{"def": "processor", "name": "Forge", "note": "smelts ore into ingots", "cost": "2 ingot", "ok": true},
		{"def": "drill", "name": "Drill", "note": "eats the rock it faces", "cost": "4 ingot", "ok": true},
		{"def": "hopper", "name": "Hopper", "note": "buffers a line", "cost": "3 ingot", "ok": true},
		{"def": "generator", "name": "Generator", "note": "locked behind POWER", "cost": "POWER", "ok": false},
	]
	var cy: float = panel.position.y + 68.0
	for i: int in cards.size():
		var d: Dictionary = cards[i]
		var card := Rect2(head.x, cy, 236.0, 44.0)
		_rrect(c, card, 5.0, Color(1.0, 1.0, 1.0, 0.032))
		var icon := Rect2(card.position + Vector2(8.0, 8.0), Vector2(28.0, 28.0))
		_rrect(c, icon, 4.0, Color(0.0, 0.0, 0.0, 0.28))
		_machine(c, icon.get_center(), String(d["def"]), 0.62)
		c.draw_string(_font, card.position + Vector2(44.0, 20.0), String(d["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT if bool(d["ok"]) else DIM)
		c.draw_string(_font, card.position + Vector2(44.0, 33.0), String(d["note"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)
		var cost: String = String(d["cost"])
		c.draw_string(_font, Vector2(card.end.x - 10.0 - _w(cost, 10), card.position.y + 27.0), cost,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOOD if bool(d["ok"]) else FAINT)
		cy += 50.0

	# --- the selected card, blown up on the right: one big illustration, one sentence, one button ---
	var det := Rect2(panel.position.x + 330.0, panel.position.y + 62.0, 244.0, 232.0)
	_rrect(c, det, 6.0, Color(1.0, 1.0, 1.0, 0.028))
	for k: int in 4:
		c.draw_circle(det.position + Vector2(det.size.x * 0.5, 54.0), 46.0 - float(k) * 10.0,
			Color(0.85, 0.70, 0.35, 0.032))
	_machine(c, det.position + Vector2(det.size.x * 0.5, 54.0), "processor", 1.5)
	_tracked(c, "FORGE", det.position + Vector2(16.0, 118.0), 15, 2.0, TEXT)
	c.draw_string(_font, det.position + Vector2(16.0, 136.0), "Smelts ore into ingots, one at a time,",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	c.draw_string(_font, det.position + Vector2(16.0, 148.0), "and drops them into the cell below.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	c.draw_line(det.position + Vector2(16.0, 162.0), Vector2(det.end.x - 16.0, det.position.y + 162.0),
		Color(1.0, 1.0, 1.0, 0.06), 1.0)
	_tracked(c, "COST", det.position + Vector2(16.0, 178.0), 8, 2.0, FAINT)
	_cost_chip(c, det.position + Vector2(58.0, 170.0), &"ingot", "2", "8", true)
	var buy := Rect2(det.position.x + 16.0, det.position.y + 196.0, det.size.x - 32.0, 24.0)
	_rrect(c, buy, 5.0, BRASS)
	_tracked(c, "BUILD", buy.position + Vector2(buy.size.x * 0.5 - 24.0, 16.0), 11, 2.4, Color(0.08, 0.07, 0.04))
	_tracked(c, "ENTER", Vector2(buy.end.x - 34.0, buy.position.y + 16.0), 8, 0.8, Color(0.08, 0.07, 0.04, 0.65))

	c.draw_string(_font, Vector2(panel.position.x + 76.0, panel.end.y - 14.0),
		"↑↓ pick    1/2/3 tab    E close", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, FAINT)


## A machine drawn with its OWN glyph — `Visuals.draw_item` only knows carried goods, and a machine drawn as
## a carried good is the white square this mock caught on its first pass.
func _machine(c: Control, at: Vector2, def_name: String, s: float) -> void:
	var def: MachineDef = load("res://src/data/machines/%s.tres" % def_name) as MachineDef
	if def == null:
		return
	c.draw_rect(Rect2(at - Vector2(11.0, 11.0) * s, Vector2(22.0, 22.0) * s), Visuals.machine_color(def))
	Visuals.draw_machine_glyph(c, at, Visuals.machine_kind(def), s, false, 0.0)


func _rail_glyph(c: Control, at: Vector2, kind: int, on: bool) -> void:
	var col: Color = BRASS_HI if on else Color(0.42, 0.45, 0.52)
	match kind:
		0:      # PACK — a satchel
			c.draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(16.0, 12.0)), col)
			c.draw_arc(at + Vector2(0.0, -3.0), 6.0, PI, TAU, 10, col, 2.0)
		1:      # WORKS — a gear
			c.draw_arc(at, 7.0, 0.0, TAU, 20, col, 2.4)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				c.draw_line(at + Vector2(cos(a), sin(a)) * 7.0, at + Vector2(cos(a), sin(a)) * 10.0, col, 2.0)
		_:      # BENCH — a rising ladder of rungs
			for i: int in 3:
				var y: float = at.y + 6.0 - float(i) * 6.0
				c.draw_rect(Rect2(at.x - 8.0 + float(i) * 2.0, y, 16.0 - float(i) * 4.0, 3.0), col)


# =========================================================================================================
# C — THE STALL. The most aggressive answer to "it feels like a menu": stop drawing a menu. The world stays
# SHARP and lit; a counter slab slides up from the bottom edge with the goods laid out on it as physical
# plates, the selected one raised into the lamp light. You never lose sight of your miner, the stall, or the
# sky — which is the whole argument for it, and also its risk: less room for text, so prices have to be
# glanceable rather than readable.
# =========================================================================================================
func _variant_c(c: Control, sharp: ImageTexture) -> void:
	c.draw_texture_rect(sharp, Rect2(Vector2.ZERO, CANVAS), false)
	# No dim over the world at all — only a vignette, and a warm wash near the counter as if the stall's
	# lantern had been turned up.
	_vignette(c, 0.62)
	c.draw_rect(Rect2(0.0, 250.0, CANVAS.x, 110.0), Color(0.06, 0.05, 0.04, 0.25))

	# The awning board — three hanging signs are the tabs.
	var sx: float = 150.0
	for i: int in 3:
		var name: String = ["PACK", "WORKS", "BENCH"][i]
		var w: float = _w(name, 11) + 34.0
		var on: bool = i == 1
		var top: float = 196.0 if on else 200.0
		c.draw_line(Vector2(sx + 10.0, top - 8.0), Vector2(sx + 10.0, top), Color(0.35, 0.30, 0.22), 1.0)
		c.draw_line(Vector2(sx + w - 10.0, top - 8.0), Vector2(sx + w - 10.0, top), Color(0.35, 0.30, 0.22), 1.0)
		var board := Rect2(sx, top, w, 24.0)
		_vgrad(c, board, Color(0.192, 0.145, 0.094) if on else Color(0.106, 0.090, 0.070),
			Color(0.118, 0.086, 0.055) if on else Color(0.070, 0.062, 0.051), 5)
		c.draw_rect(board, BRASS if on else Color(0.25, 0.22, 0.18), false, 1.0)
		_tracked(c, name, board.position + Vector2(17.0, 16.0), 11, 1.6, BRASS_HI if on else Color(0.45, 0.42, 0.38))
		sx += w + 14.0

	# The counter slab: a heavy wooden top edge with a lit lip, then the goods sitting ON it.
	var slab := Rect2(0.0, 236.0, CANVAS.x, 124.0)
	_drop(c, slab, 12, 0.4)
	_vgrad(c, slab, Color(0.129, 0.106, 0.082), Color(0.047, 0.043, 0.043), 14)
	c.draw_rect(Rect2(slab.position, Vector2(slab.size.x, 3.0)), Color(0.35, 0.27, 0.17))
	c.draw_rect(Rect2(slab.position, Vector2(slab.size.x, 1.0)), Color(0.62, 0.50, 0.32))

	var goods: Array[Dictionary] = [
		{"id": &"sinker_bit", "name": "SINKER", "cost": "3", "on": false},
		{"id": &"broad_bit", "name": "BROAD", "cost": "3", "on": true},
		{"id": &"lance_bit", "name": "LANCE", "cost": "5", "on": false},
		{"id": &"wedge_bit", "name": "WEDGE", "cost": "8", "on": false},
		{"id": &"scanner", "name": "SCANNER", "cost": "6", "on": false},
	]
	var gx: float = 78.0
	for g: Dictionary in goods:
		var on: bool = bool(g["on"])
		var plate := Rect2(gx, 258.0 - (8.0 if on else 0.0), 84.0, 74.0)
		if on:
			for k: int in 4:
				c.draw_circle(plate.get_center() - Vector2(0.0, 8.0), 44.0 - float(k) * 9.0,
					Color(0.90, 0.72, 0.36, 0.045))
		_drop(c, plate, 6, 0.35)
		_vgrad(c, plate, Color(0.157, 0.145, 0.125) if on else Color(0.086, 0.082, 0.078),
			Color(0.070, 0.066, 0.062), 8)
		c.draw_rect(plate, BRASS if on else Color(0.19, 0.18, 0.17), false, 1.0)
		Visuals.draw_item(c, plate.position + Vector2(42.0, 28.0), 34.0 if on else 28.0, g["id"])
		_tracked(c, String(g["name"]), Vector2(plate.position.x + 42.0 - _w(String(g["name"]), 9) * 0.5 - 4.0,
			plate.position.y + 56.0), 9, 1.2, BRASS_HI if on else Color(0.48, 0.46, 0.44))
		Visuals.draw_item(c, plate.position + Vector2(32.0, 66.0), 12.0, &"ingot")
		c.draw_string(_font, plate.position + Vector2(41.0, 70.0), String(g["cost"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOOD if on else DIM)
		gx += 94.0

	# The one line of prose, on the slab's front edge where a price card would be.
	_tracked(c, "BROAD BIT", Vector2(78.0, 348.0), 11, 2.0, BRASS_HI)
	c.draw_string(_font, Vector2(78.0 + _tracked_w("BROAD BIT", 11, 2.0) + 20.0, 348.0),
		"takes a 2×2 — and grinds every scrap of it to dust", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, DIM)
	var buy: String = "ENTER  buy"
	c.draw_string(_font, Vector2(CANVAS.x - 22.0 - _w(buy, 10), 348.0), buy, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BRASS_HI)
	# Carried goods ride the top-right of the slab, out of the goods' way.
	var hx: float = CANVAS.x - 22.0
	for pair: Array in [[&"stone", "24"], [&"coal", "12"], [&"ore", "24"], [&"ingot", "8"]]:
		var t: String = String(pair[1])
		hx -= _w(t, 10) + 26.0
		Visuals.draw_item(c, Vector2(hx + 7.0, 250.0), 13.0, pair[0])
		c.draw_string(_font, Vector2(hx + 16.0, 254.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)


# --- shared primitives --------------------------------------------------------------------------------

func _w(s: String, size: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## What `_tracked` actually occupies — the plain width plus one gap per letter. Measuring tracked type with
## `_w` is how the mock's first pass printed a caption straight through its own title.
func _tracked_w(s: String, size: int, track: float) -> float:
	return _w(s, size) + track * float(maxi(s.length() - 1, 0))


## Letter-spaced type. Small caps with air between them is most of what separates a title from a label, and
## the HUD already owns this trick for the stratum plates.
func _tracked(c: Control, text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		c.draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


## A soft drop shadow, faked with concentric translucent rings. Elevation is what a modern panel uses
## instead of a border, and it is the difference between "in front of the world" and "printed on it".
func _drop(c: Control, rect: Rect2, spread: int, peak: float) -> void:
	for i: int in range(spread, 0, -1):
		var t: float = float(i) / float(spread)
		c.draw_rect(rect.grow(float(i)), Color(0.0, 0.0, 0.0, peak * (1.0 - t) * 0.35))


func _vgrad(c: Control, rect: Rect2, top: Color, bot: Color, steps: int) -> void:
	var h: float = rect.size.y / float(steps)
	for i: int in steps:
		var t: float = float(i) / float(maxi(steps - 1, 1))
		c.draw_rect(Rect2(rect.position.x, rect.position.y + float(i) * h, rect.size.x, h + 0.6),
			top.lerp(bot, t))


func _frame(c: Control, rect: Rect2, col: Color, width: float) -> void:
	c.draw_rect(rect, col, false, width)
	c.draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0),
		BRASS_HI, 1.0)


## A recessed well: darker than its surround, with a shadow along the top and left inner edges. Two lines,
## and the content stops floating.
func _well(c: Control, rect: Rect2) -> void:
	c.draw_rect(rect, WELL)
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Color(0.0, 0.0, 0.0, 0.55))
	c.draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), Color(0.0, 0.0, 0.0, 0.45))
	c.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), Color(1.0, 1.0, 1.0, 0.05))


## A REAL rounded rect, via StyleBoxFlat, because composing one from a rect plus four circles double-blends
## every corner when the fill is translucent — which is exactly the case a modern surface tint is.
func _rrect(c: Control, rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 8
	sb.draw(c.get_canvas_item(), rect)


## Rounded on the left two corners only — for a rail flush against a panel's edge.
func _rrect_left(c: Control, rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.corner_detail = 8
	sb.draw(c.get_canvas_item(), rect)


## have/need as one chip: the icon, what it costs, and what you are carrying, so "can I afford this" is
## answered in the same glance as "what does it cost".
func _cost_chip(c: Control, at: Vector2, item: StringName, need: String, have: String, ok: bool) -> void:
	var label: String = "%s / %s" % [need, have]
	var w: float = _w(label, 10) + 24.0
	_rrect(c, Rect2(at, Vector2(w, 18.0)), 4.0, Color(1.0, 1.0, 1.0, 0.05))
	Visuals.draw_item(c, at + Vector2(11.0, 9.0), 13.0, item)
	c.draw_string(_font, at + Vector2(20.0, 13.0), need, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		GOOD if ok else BAD)
	c.draw_string(_font, at + Vector2(20.0 + _w(need, 10), 13.0), " / " + have,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FAINT)


## Darkens the frame's edges so the eye is pushed to the middle. Every modern pause screen does it and this
## one does not, which is part of why the panel reads as pasted on.
func _vignette(c: Control, peak: float) -> void:
	var steps: int = 22
	for i: int in steps:
		var t: float = float(i) / float(steps)
		var inset: float = t * 120.0
		c.draw_rect(Rect2(0.0, 0.0, CANVAS.x, 1.0 + inset * 0.55), Color(0.0, 0.0, 0.0, peak * 0.028))
		c.draw_rect(Rect2(0.0, CANVAS.y - 1.0 - inset * 0.55, CANVAS.x, 1.0 + inset * 0.55),
			Color(0.0, 0.0, 0.0, peak * 0.028))
		c.draw_rect(Rect2(0.0, 0.0, 1.0 + inset, CANVAS.y), Color(0.0, 0.0, 0.0, peak * 0.022))
		c.draw_rect(Rect2(CANVAS.x - 1.0 - inset, 0.0, 1.0 + inset, CANVAS.y),
			Color(0.0, 0.0, 0.0, peak * 0.022))
