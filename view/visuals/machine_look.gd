class_name MachineLook
extends RefCounted

## THE MACHINE STYLE REGISTRY (A' step 6b, D0363): the one table wiring a behaviour tag to its LOOK (glyph
## kind + casing colour), and the casing itself. Legacy `scenes/visuals.gd`'s machine half lifted onto
## the observation's machine records: a record carries `id`, `behavior` and `source` (a recipe with no
## inputs), which is everything `machine_kind`/`machine_color` read off a `MachineDef`, and the view never
## sees the def. Seven dead entries are out (splitter, descent, h_drill, drift, crush, spur, ore_vent);
## `tests/test_looks.gd` pins the population against `data/machines`. The glyphs are `MachineGlyphs`.

## A def with no entry falls back on its recipe: a no-input source reads as a furnace, anything else as a
## gear (the generic runner). Adding a machine = one entry here (+ a drawer in `MachineGlyphs` if its kind
## is genuinely new).
const STYLE: Dictionary = {
	&"drill": {"kind": "drill", "color": Color(0.72, 0.56, 0.30)},          # steel-amber, ore-extraction tech
	&"lift": {"kind": "lift", "color": Color(0.26, 0.66, 0.62)},            # teal, anti-gravity tech
	&"generator": {"kind": "generator", "color": Color(0.80, 0.66, 0.26)},  # electric gold: burns fuel -> power
	&"conduit": {"kind": "conduit", "color": Color(0.66, 0.47, 0.30)},      # copper, the power-tube material
	&"hopper": {"kind": "hopper", "color": Color(0.40, 0.44, 0.52)},        # cool gunmetal: a storage bin
	&"rope": {"kind": "rope", "color": Color(0.62, 0.50, 0.32)},            # hemp tan, the placeable climb
	&"torch": {"kind": "torch", "color": Color(0.86, 0.60, 0.26)},          # flame amber, placeable light
	# The crafter modules: recipe-runners wearing their OWN faces, so each visibly announces its product.
	&"iron_forge": {"kind": "furnace", "color": Color(0.40, 0.48, 0.62)},   # steel-blue furnace, smelts iron
	&"blast_furnace": {"kind": "furnace", "color": Color(0.82, 0.60, 0.28)}, # white-gold heat: 1 rich ore -> 2 ingots
	&"plate_press": {"kind": "press", "color": Color(0.52, 0.57, 0.68)},    # slab-grey, presses plates
	&"gear_mill": {"kind": "gear", "color": Color(0.72, 0.56, 0.26)},       # bronze, mills gears
	&"pump": {"kind": "pump", "color": Color(0.30, 0.52, 0.68)},            # water-blue, the powered flood-drain
	# The Freight Winch is graybox on purpose: the hopper's glyph (both are stockpile-shaped single-cell
	# machines) until the hero machine's own silhouette gets an art pass.
	&"winch_head": {"kind": "hopper", "color": Color(0.70, 0.48, 0.22)},      # cable amber: the hauling end
	&"winch_station": {"kind": "hopper", "color": Color(0.34, 0.46, 0.56)},   # cool steel: the receiving end
}
const FURNACE_BODY := Color(0.28, 0.23, 0.20)   # dark sooty IRON: the heat is in the glowing mouth, lit only while smelting
const RUNNER_BODY := Color(0.30, 0.55, 0.75)    # steel-blue, the generic processor

## COLD IRON: how far an idle machine falls away from its working colour, SUBTRACTED from idle rather than
## added to working, so the working state every glyph was drawn against stays byte-identical. Measured
## by legacy's `check_machine_state`, not chosen by eye.
const COLD_DARKEN: float = 0.22
const COLD_DESAT: float = 0.18
## THE PROFILE: the shape a machine's body occupies inside its cell, in UNIT SPACE (y down). One solid body
## from the crown line to the foot and identity in the TOP BAND, the only part of a machine's outline with
## sky behind it; every profile WITH A BODY keeps a FLAT FOOT at y=1.0 (the conduit is a bar mid-cell, a
## pipe is not bolted down). Rectangles, not polygons: at play zoom a diagonal is four grey steps. A kind
## with no entry keeps the full square.
const CROWN: float = 0.20
const BODY := Rect2(0.0, CROWN, 1.0, 1.0 - CROWN)
const PROFILE: Dictionary = {
	"furnace": [BODY, Rect2(0.56, 0.0, 0.26, 0.22)],                                   # a chimney
	"generator": [BODY, Rect2(0.14, 0.09, 0.72, 0.13)],                                # a drum's domed cap, wide and low
	"drill": [BODY, Rect2(0.06, 0.02, 0.24, 0.20), Rect2(0.70, 0.02, 0.24, 0.20)],      # slung between two mounts
	"hopper": [BODY, Rect2(0.0, 0.0, 1.0, 0.14)],                                       # a mouth: a full-width flange
	"lift": [BODY, Rect2(0.08, 0.0, 0.18, 0.22), Rect2(0.74, 0.0, 0.18, 0.22)],         # a gantry: two tall posts
	"press": [BODY, Rect2(0.26, 0.06, 0.48, 0.16)],                                     # a ram: one heavy block
	"gear": [BODY, Rect2(0.18, 0.0, 0.20, 0.22)],                                       # driven from above, off-centre
	"pump": [BODY, Rect2(0.62, 0.06, 0.34, 0.16)],                                      # a spout, leaving to one side
	"rope": [Rect2(0.38, 0.0, 0.24, 1.0)],                                              # the placeables: not full squares
	"torch": [Rect2(0.36, 0.28, 0.28, 0.72), Rect2(0.22, 0.04, 0.56, 0.22)],
	"conduit": [Rect2(0.0, 0.32, 1.0, 0.36)],
}
const FULL_PROFILE: Array = [Rect2(0.0, 0.0, 1.0, 1.0)]
## The gap each body part leaves around itself, so adjacent parts read as separate castings. Anything laid
## INSIDE a casing has to clear the same edge; this is the one line relating them.
const CASING_INSET: float = 1.0
## The box height a glyph is authored to fill at scale 1.0 (an authored fit, not a derived one), and the
## divisor every HUD chip uses to turn the box it has into the scale `MachineGlyphs.draw` wants.
const GLYPH_BOX_PX: float = 20.0


## The icon kind of a machine: its style entry, else furnace (the base Forge, or any no-input source) or
## gear (the generic runner).
static func kind(behavior: StringName, id: StringName, source: bool) -> String:
	if STYLE.has(behavior):
		return (STYLE[behavior] as Dictionary)["kind"]
	return "furnace" if id == &"processor" or source else "gear"


## The casing colour (the riveted body the glyph sits on).
static func color(behavior: StringName, id: StringName, source: bool) -> Color:
	if STYLE.has(behavior):
		return (STYLE[behavior] as Dictionary)["color"]
	return FURNACE_BODY if id == &"processor" or source else RUNNER_BODY


static func profile(kind_name: String) -> Array:
	return PROFILE.get(kind_name, FULL_PROFILE)


## The part of a kind's body that carries everything drawn ON the machine: the largest part by area.
static func face(kind_name: String) -> Rect2:
	var parts: Array = profile(kind_name)
	var best: Rect2 = parts[0]
	for r: Rect2 in parts:
		if r.size.x * r.size.y > best.size.x * best.size.y:
			best = r
	return best


static func glyph_cells_for(px: float) -> float:
	return px / GLYPH_BOX_PX


## An idle casing: value gone and the hue pulled toward grey. Both, because darkening alone reads as a
## machine standing in shadow and desaturation alone as a different material; together, switched off.
static func cold_iron(c: Color) -> Color:
	var grey: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return c.lerp(Color(grey, grey, grey), COLD_DESAT).darkened(COLD_DARKEN)


## THE CASING: a lighting model and almost nothing else. Top-lit body (a thin catch along the top, a real
## shadow across the foot, per part), a bevel (two edges catch the light, two do not; a working machine's
## top light is warm, the casing's only emissive), the hard outline that keeps it off the rock, and a
## plinth bolting it to the floor. `detail` adds the tier that only exists when it can be seen: a
## recessed faceplate on the face part, vent slots, rivets with a lit crown.
static func draw_casing(canvas: CanvasItem, pos: Vector2, cell_px: float, col_in: Color,
		active: bool, detail: bool, kind_name: String = "") -> void:
	var col: Color = col_in if active else cold_iron(col_in)
	var parts: Array = profile(kind_name)
	var face_rect: Rect2 = face(kind_name)
	for u: Rect2 in parts:
		var body := Rect2(pos + Vector2(u.position.x * cell_px + CASING_INSET, u.position.y * cell_px + CASING_INSET),
			Vector2(maxf(u.size.x * cell_px - CASING_INSET * 2.0, 2.0), maxf(u.size.y * cell_px - CASING_INSET * 2.0, 2.0)))
		canvas.draw_rect(body, col)
		canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, minf(3.0, body.size.y))), Color(1.0, 0.98, 0.92, 0.07))
		var shade: float = minf(cell_px * 0.30, body.size.y * 0.5)
		canvas.draw_rect(Rect2(body.position + Vector2(0.0, body.size.y - shade), Vector2(body.size.x, shade)), Color(0.0, 0.0, 0.02, 0.30))
		var top: Color = col.lightened(0.34) if not active else col.lightened(0.34).lerp(Color(1.0, 0.86, 0.58), 0.30)
		canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, 1.0)), top)
		canvas.draw_rect(Rect2(body.position, Vector2(1.0, body.size.y)), col.lightened(0.16))
		canvas.draw_rect(Rect2(body.position + Vector2(0.0, body.size.y - 1.0), Vector2(body.size.x, 1.0)), col.darkened(0.50))
		canvas.draw_rect(Rect2(body.position + Vector2(body.size.x - 1.0, 0.0), Vector2(1.0, body.size.y)), col.darkened(0.42))
		canvas.draw_rect(Rect2(pos + u.position * cell_px, u.size * cell_px), Color(0.03, 0.03, 0.05, 0.85), false, 1.0)
		if detail and u == face_rect:
			_draw_detail(canvas, body, col)
	canvas.draw_rect(Rect2(pos.x + 2.0, pos.y + cell_px - 4.0, cell_px - 4.0, 3.0), Color(0.05, 0.05, 0.07, 0.55))


## The recessed faceplate (the bevel runs the OTHER way, dark on top and light below, which is the only
## thing that distinguishes a hole from a bump, and it darkens the ground every glyph is drawn on), the
## vent slots fitted to the part, and the rivets: a dark seat with a lit crown offset up-left.
static func _draw_detail(canvas: CanvasItem, body: Rect2, col: Color) -> void:
	var inset: float = minf(4.0, minf(body.size.x, body.size.y) * 0.22)
	var plate := Rect2(body.position + Vector2(inset, inset), Vector2(body.size.x - inset * 2.0, body.size.y - inset * 2.0))
	if plate.size.x < 4.0 or plate.size.y < 4.0:
		return
	canvas.draw_rect(plate, Color(0.0, 0.0, 0.02, 0.26))
	canvas.draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1.0)), Color(0.0, 0.0, 0.02, 0.38))
	canvas.draw_rect(Rect2(plate.position + Vector2(0.0, plate.size.y - 1.0), Vector2(plate.size.x, 1.0)), col.lightened(0.22))
	var slots: int = int(clampf(floorf((body.size.x - 8.0) / 4.0), 0.0, 3.0))
	for s: int in slots:
		canvas.draw_rect(Rect2(body.position.x + 4.0 + float(s) * 4.0, body.position.y + body.size.y - 6.0, 2.0, 3.0), Color(0.0, 0.0, 0.02, 0.42))
	if body.size.x >= 10.0 and body.size.y >= 10.0:
		for corner: Vector2 in [Vector2(3.0, 3.0), Vector2(body.size.x - 3.0, 3.0),
				Vector2(3.0, body.size.y - 3.0), Vector2(body.size.x - 3.0, body.size.y - 3.0)]:
			canvas.draw_circle(body.position + corner, 1.4, Color(0.0, 0.0, 0.02, 0.55))
			canvas.draw_circle(body.position + corner - Vector2(0.4, 0.4), 0.7, col.lightened(0.40))
