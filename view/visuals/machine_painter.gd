class_name MachinePainter
extends RefCounted

## EVERYTHING THE WORLD DRAWS ABOUT A MACHINE (A' step 6c, D0364): casing, glyph, construction flash,
## status lamp and need bubble, nameplate, held-count badge, progress bar, input and output marks. Legacy
## `scenes/machine_view.gd` on the `Frame` contract: its reach-ins (`_aim`, `_anim_time`, `_zoom`, `_font`,
## `_construct`, `_cell_center`) are the frame's aim cell, clock and zoom, the theme's fallback font, a
## construction clock this painter keeps by watching records appear, and arithmetic. Everything it read
## off a `MachineState` it reads off the observation's machine record (`id`, `behavior`, `source`, `name`,
## `recipe`, `status`, `power_permille`, `progress_permille`, `facing`, `fuel`, `input`, `output`).
##
## STATEFUL, so it goes in as an object (`add_stateful_painter`): the construction flash outlives the
## frame that placed the machine, and the nameplate plan is laid out once per frame for every machine at
## once, because three plates on adjacent cells overlap into garbage and a machine cannot see its
## neighbours. Every layout decision is a static function a test can fail on.
##
## UNITS. The casing and the glyph are CELL-sized: 16 px here against legacy's 32, drawn at the cell.
## The chrome -- lamp, bubble, badge, plate, wedges, bar -- is legacy's screen pixels at its 1.0 zoom,
## drawn under a 0.5 transform, which is the fine-detail rule made one number (`CHROME_SCALE`). The zoom
## gates map the same way: legacy's 0.65 at a 32 px cell is 1.3 here for the same screen size.
##
## NOT PORTED, stated: the load well (legacy drew it for the rig's three capped bellies, all dead; the
## hopper's `feed_cap` is this build's one capped belly and a candidate), the objective guide's airspace
## rule (no objectives yet), the silhouette and bare-machine debug switches.

const CELL: float = float(Interface.Observation.LOGIC_PX)
const CHROME_SCALE: float = CELL / 32.0
const TEXT_ZOOM: float = 1.3      ## legacy 0.65: would 8 px type survive at this scale
const DETAIL_ZOOM: float = 1.24   ## legacy 0.62: rivets and vents only when resolvable
const LABEL_NEAR_M: float = 6.4   ## legacy REACH_CELLS 3.2 × 2, in metres: the ring you are about to touch
const WORK_ANIM_FPS: float = 4.0
const CONSTRUCT_DUR: float = 0.38
const PROGRESS_BAR_H: float = 3.0 ## legacy px
const WEDGE_HALF: float = 4.5     ## legacy px; the apex stands WEDGE_JUT off the base
const WEDGE_JUT: float = WEDGE_HALF + 2.5
const CHROME := Color(0.78, 0.83, 0.92)   ## what a mark wears with nothing of its own to say; never white
const BADGE_FS: int = 9

var _construct: Dictionary = {}   ## logic cell -> seconds since the machine appeared
var _seen: Dictionary = {}
var _primed: bool = false
var _last_time: float = 0.0
var _label_plan: Dictionary = {}


func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	track_construction(o, dt)
	var font: Font = ThemeDB.fallback_font
	var view: Rect2 = frame.view_world_rect.grow(2.0 * CELL)
	var aim: Vector2i = aim_logic(o)
	var named: Dictionary = {}
	var shown: Dictionary = {}
	for rec: Dictionary in o.machines:
		var cell: Vector2i = rec["cell"]
		if String(rec.get("name", "")).is_empty():
			continue
		named[cell] = String(rec["name"]).to_upper()
		if view.has_point(Vector2(cell) * CELL) and label_visible(frame, cell, aim):
			shown[cell] = true
	_label_plan = MachineLabels.plan(named, shown, aim, font, CELL)
	for rec: Dictionary in o.machines:
		if view.has_point(Vector2(rec["cell"]) * CELL):
			_draw_machine(frame, ci, rec, font, aim)


## A machine that was not in the last frame's records has just been placed: its flash starts. The first
## frame primes the set without flashing, so a loaded base does not assemble itself on screen.
func track_construction(o: Interface.Observation, dt: float) -> void:
	var now: Dictionary = {}
	for rec: Dictionary in o.machines:
		var cell: Vector2i = rec["cell"]
		now[cell] = true
		if _primed and not _seen.has(cell):
			_construct[cell] = 0.0
	for cell: Vector2i in _construct.keys():
		_construct[cell] = float(_construct[cell]) + dt
		if float(_construct[cell]) >= CONSTRUCT_DUR or not now.has(cell):
			_construct.erase(cell)
	_seen = now
	_primed = true


## Is a machine visibly working this tick? Behaviour-aware, so the glyph animates truthfully: a generator
## burns only while fuelled, a lift stirs while powered or holding goods, others while a cycle runs or they
## hold product.
static func active(rec: Dictionary) -> bool:
	match StringName(rec.get("behavior", &"")):
		&"generator":
			return int(rec.get("fuel", 0)) > 0
		&"lift":
			return int(rec.get("power_permille", 0)) > 50 or not (rec.get("input", {}) as Dictionary).is_empty()
		_:
			return held(rec) > 0 or int(rec.get("progress_permille", 0)) > 0


static func held(rec: Dictionary) -> int:
	return _total(rec.get("input", {})) + _total(rec.get("output", {}))


static func _total(buffer: Dictionary) -> int:
	var n: int = 0
	for v: Variant in buffer.values():
		n += int(v)
	return n


## The aimed LOGIC cell, or (-1,-1): the observation's aim is a terrain cell.
static func aim_logic(o: Interface.Observation) -> Vector2i:
	if o.aim_cell == Vector2i(-1, -1):
		return o.aim_cell
	var n: int = Interface.Observation.LOGIC_PX / Interface.Observation.CELL_PX
	return Vector2i(_floor_div(o.aim_cell.x, n), _floor_div(o.aim_cell.y, n))


static func _floor_div(a: int, b: int) -> int:
	return (a - (b - 1 if a < 0 else 0)) / b


## Would 8 px type survive at this scale, or is this the aimed machine: the gate for the badge and the
## bubble, per-machine state the player wants wherever the machine is.
static func text_visible(frame: Frame, cell: Vector2i, aim: Vector2i) -> bool:
	return cell == aim or frame.zoom >= TEXT_ZOOM


## The nameplate's gate: aimed at, or near AND readable. Relevance is proximity or intent; a name is worth
## reading once and then never again.
static func label_visible(frame: Frame, cell: Vector2i, aim: Vector2i) -> bool:
	if cell == aim:
		return true
	if frame.zoom < TEXT_ZOOM:
		return false
	var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	var body := Vector2(float(frame.obs.pos_x) / float(Fx.SCALE), float(frame.obs.pos_y) / float(Fx.SCALE))
	return centre.distance_to(body) <= LABEL_NEAR_M * CELL


## The glyph's scale: legacy's rule (fit the face, never larger than 1.0, because a glyph that overhangs
## its casing reads as a sticker) at this cell's size.
static func glyph_scale(face: Rect2) -> float:
	return clampf(minf(face.size.x, face.size.y) / CELL + 0.24, 0.6, 1.0) * CHROME_SCALE


## What a stalled machine is asking for: coal when it is out of fuel, otherwise its recipe's first input.
static func need_item(rec: Dictionary) -> StringName:
	if StringName(rec.get("status", &"")) == &"no_fuel":
		return &"coal"
	var inputs: Dictionary = _recipe(rec).get("inputs", {})
	if inputs.is_empty():
		return &"ore"
	return StringName(String(inputs.keys()[0]))


static func _recipe(rec: Dictionary) -> Dictionary:
	return RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {})


## The ink a mark wears when it speaks for an item: the item's colour, or chrome when it has none.
static func ink(item: StringName) -> Color:
	var col: Color = ItemLook.color(item)
	return CHROME if col == Color.WHITE else col


## The ports, in world px: the mouth on the face's top edge (goods land ON the body), the spout on the cell
## line (goods leave INTO the cell below; a lift's leaves upward). Each is {base, dir, color}.
static func io_ports(rec: Dictionary, pos: Vector2, face: Rect2) -> Array[Dictionary]:
	var ports: Array[Dictionary] = []
	var recipe: Dictionary = _recipe(rec)
	var mid: float = face.get_center().x
	var inputs: Dictionary = recipe.get("inputs", {})
	if not inputs.is_empty():
		ports.append({"base": Vector2(mid, face.position.y), "dir": Vector2(0, 1), "color": ink(StringName(String(inputs.keys()[0])))})
	var outputs: Dictionary = recipe.get("outputs", {})
	var out_col: Color = Color(0.80, 0.86, 0.94) if outputs.is_empty() else ink(StringName(String(outputs.keys()[0])))
	if StringName(rec.get("behavior", &"")) == &"lift":
		ports.append({"base": Vector2(mid, face.position.y), "dir": Vector2(0, -1), "color": Color(0.5, 1.0, 0.92)})
	else:
		ports.append({"base": Vector2(mid, pos.y + CELL), "dir": Vector2(0, 1), "color": out_col})
	return ports


## The sprite for a machine's state, or null for the code-drawn casing: working with work_0 and work_1
## present cycles them; working with only work_0 alternates it with idle; idle, or no frames, the static
## machine_<id>. Partial sets degrade gracefully, so frames can land one at a time.
static func sprite(id: StringName, is_active: bool, clock: float) -> Texture2D:
	var base: String = "machine_" + String(id)
	var idle: Texture2D = Art.tex(base)
	if idle == null:
		return null
	if is_active:
		var work_0: Texture2D = Art.tex(base + "_work_0")
		if work_0 != null:
			if int(clock * WORK_ANIM_FPS) % 2 == 1:
				var work_1: Texture2D = Art.tex(base + "_work_1")
				return work_1 if work_1 != null else idle
			return work_0
	return idle


func _draw_machine(frame: Frame, ci: CanvasItem, rec: Dictionary, font: Font, aim: Vector2i) -> void:
	var cell: Vector2i = rec["cell"]
	var pos: Vector2 = Vector2(cell) * CELL
	var behavior := StringName(rec.get("behavior", &""))
	var kind: String = MachineLook.kind(behavior, StringName(rec["id"]), bool(rec.get("source", false)))
	var face_u: Rect2 = MachineLook.face(kind)
	var face := Rect2(pos + face_u.position * CELL, face_u.size * CELL)
	# The contact shadow grounds the machine on the floor it sits on.
	ci.draw_set_transform(pos + Vector2(CELL * 0.5, CELL - 0.5), 0.0, Vector2(1.0, 0.26))
	ci.draw_circle(Vector2.ZERO, CELL * 0.46, Color(0.0, 0.0, 0.0, 0.30))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var on: bool = active(rec)
	var clock: float = frame.anim_time
	if behavior == &"lift":
		clock *= 1.0 + float(rec.get("power_permille", 0)) / 1000.0   # the chevrons surge when powered
	var spr: Texture2D = sprite(StringName(rec["id"]), on, clock)
	if spr != null:
		if int(rec.get("facing", 1)) < 0:
			ci.draw_set_transform(pos + Vector2(CELL, CELL) * 0.5, 0.0, Vector2(-1.0, 1.0))
			ci.draw_texture_rect(spr, Rect2(Vector2(CELL, CELL) * -0.5, Vector2(CELL, CELL)), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			ci.draw_texture_rect(spr, Rect2(pos, Vector2(CELL, CELL)), false)
	else:
		MachineLook.draw_casing(ci, pos, CELL, MachineLook.color(behavior, StringName(rec["id"]), bool(rec.get("source", false))),
			on, frame.zoom >= DETAIL_ZOOM, kind)
		MachineGlyphs.draw(ci, face.get_center(), kind, glyph_scale(face), on, clock)
	var show_text: bool = text_visible(frame, cell, aim)
	if _label_plan.has(cell) and label_visible(frame, cell, aim):
		_chrome(ci, Vector2.ZERO)
		MachineLabels.draw(ci, font, _label_plan[cell], pos.y / CHROME_SCALE)
		_unchrome(ci)
	var n: int = held(rec)
	if show_text and n > 0:
		_draw_badge(ci, font, face, n)
	if int(_recipe(rec).get("time_ticks", 0)) > 0:
		var bar_h: float = PROGRESS_BAR_H * CHROME_SCALE
		var bar_y: float = face.end.y - bar_h
		ci.draw_rect(Rect2(face.position.x, bar_y, face.size.x, bar_h), Color(0.0, 0.0, 0.0, 0.35))
		ci.draw_rect(Rect2(face.position.x, bar_y, face.size.x * float(rec.get("progress_permille", 0)) / 1000.0, bar_h), Color(0.40, 0.90, 0.45))
	for port: Dictionary in io_ports(rec, pos, face):
		_matter_wedge(ci, port["base"], port["dir"], port["color"])
	_draw_status(frame, ci, rec, face, show_text)
	if _construct.has(cell):
		_draw_construct(ci, pos, clampf(float(_construct[cell]) / CONSTRUCT_DUR, 0.0, 1.0))


## Chrome is drawn in legacy's px under this transform; `origin` is the world point legacy px count from.
static func _chrome(ci: CanvasItem, origin: Vector2) -> void:
	ci.draw_set_transform(origin, 0.0, Vector2(CHROME_SCALE, CHROME_SCALE))


static func _unchrome(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The badge is sized to its number: a count that outgrows its box is a count you cannot trust. Chrome,
## not white: a standing quantity on its own near-black plate.
static func _draw_badge(ci: CanvasItem, font: Font, face: Rect2, n: int) -> void:
	var tag: String = str(n)
	var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FS).x + 3.0
	_chrome(ci, face.position)
	var badge := Vector2(face.size.x / CHROME_SCALE - 2.0 - tw, 2.0)
	ci.draw_rect(Rect2(badge, Vector2(tw, 11.0)), Color(0.04, 0.04, 0.06, 0.85))
	ci.draw_string(font, badge + Vector2(1.5, 9.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FS, CHROME)
	_unchrome(ci)


## The matter wedge: a bare head sitting on the boundary it names, goods crossing rather than travelling.
static func _matter_wedge(ci: CanvasItem, base: Vector2, dir: Vector2, color: Color) -> void:
	var perp := Vector2(dir.y, -dir.x) * WEDGE_HALF * CHROME_SCALE
	var apex := base + dir * WEDGE_JUT * CHROME_SCALE
	ci.draw_colored_polygon(PackedVector2Array([apex, base + perp, base - perp]), Color(color.r, color.g, color.b, 0.95))
	ci.draw_line(base + perp, base - perp, Color(0.04, 0.04, 0.06, 0.55), 1.0)


## The status lamp in the face's top-left corner (it grows as you zoom out, capped so it never eats the
## casing), and for a stall the need bubble on a stem down onto the roof holding what the player would
## fetch (an item) or do (a fix glyph); zoomed out past the text gate the alarm is a breathing ring around
## the cell instead, the one channel that needs no resolution.
func _draw_status(frame: Frame, ci: CanvasItem, rec: Dictionary, face: Rect2, show_bubble: bool) -> void:
	var status := StringName(rec.get("status", &"idle"))
	var look: Dictionary = StatusLook.of(status)
	var lamp: Color = look["color"]
	var k: float = clampf(2.0 / maxf(frame.zoom, 0.4), 1.0, 1.8)
	var r: float = 3.1 * k * CHROME_SCALE
	var lamp_c: Vector2 = face.position + Vector2(2.4 * CHROME_SCALE + r, 2.4 * CHROME_SCALE + r)
	ci.draw_circle(lamp_c, 4.2 * k * CHROME_SCALE, Color(0.03, 0.03, 0.05, 0.9))
	StatusLook.draw_mark(ci, lamp_c, r, look["mark"], lamp)
	if StringName(look["fix"]) == &"none" or status == &"spent":
		return
	if not show_bubble:
		var alarm: float = 0.40 + 0.60 * absf(sin(frame.anim_time * 2.6))
		ci.draw_rect(Rect2(face.position - Vector2(0.75, 0.75), face.size + Vector2(1.5, 1.5)), Color(lamp.r, lamp.g, lamp.b, 0.80 * alarm), false, 1.0)
		return
	var pulse: float = 0.62 + 0.38 * sin(frame.anim_time * 6.5)
	var bob: float = sin(frame.anim_time * 3.0) * 1.5 * CHROME_SCALE
	var br: float = 9.0 * CHROME_SCALE
	var bc := Vector2(face.get_center().x, face.position.y - 24.0 * CHROME_SCALE + bob)
	var foot := Vector2(bc.x, face.position.y)
	var stem := Color(lamp.r, lamp.g, lamp.b, 0.55 * pulse)
	ci.draw_line(bc + Vector2(0.0, br), foot, stem, 0.75)
	ci.draw_line(foot - Vector2(br * 0.4, 0.0), foot + Vector2(br * 0.4, 0.0), stem, 0.75)
	ci.draw_circle(bc, br, Color(0.05, 0.04, 0.06, 0.82 * pulse))
	ci.draw_arc(bc, br, 0.0, TAU, 20, Color(lamp.r, lamp.g, lamp.b, pulse), 0.8)
	if not bool(look["feeds"]):
		StatusLook.draw_fix_glyph(ci, bc, 11.0 * CHROME_SCALE, look["fix"], Color(lamp.r, lamp.g, lamp.b, 0.55 + 0.45 * pulse))
		return
	ItemLook.draw(ci, bc, 11.0 * CHROME_SCALE, need_item(rec))


## The one-shot assemble overlay for a just-placed machine: a settling flash that fades, a scan line running
## up the casing so the frame prints upward, corner brackets snapping inward. `t` runs 0 to 1.
static func _draw_construct(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var c: float = CELL
	var e: float = 1.0 - t
	ci.draw_rect(Rect2(pos, Vector2(c, c)), Color(1.0, 0.94, 0.78, 0.45 * e * e))
	var ly: float = pos.y + c * (1.0 - t)
	ci.draw_rect(Rect2(pos.x, ly - 0.5, c, 1.0), Color(0.82, 0.95, 1.0, 0.85 * sin(t * PI)))
	var off: float = e * 5.0 * CHROME_SCALE
	var bl: float = 5.0 * CHROME_SCALE
	var bc := Color(0.96, 0.86, 0.52, 0.35 + 0.55 * e)
	for cn: Array in [
			[Vector2(-off, -off), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(c + off, -off), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(-off, c + off), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
			[Vector2(c + off, c + off), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]]:
		var p: Vector2 = pos + (cn[0] as Vector2)
		ci.draw_line(p, p + (cn[1] as Vector2) * bl, bc, 0.75)
		ci.draw_line(p, p + (cn[2] as Vector2) * bl, bc, 0.75)
