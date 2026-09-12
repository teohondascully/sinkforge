class_name RingWord
extends RefCounted

## THE WORD UNDER THE RING (D0499, strangers 76-81, `docs/playtests/2026-09-07_strangers76-81_seam_slot.md`).
## The WHITE RING (`TargetGuide`) stood on the coal seam for the smelt rung (D0486) and the seventy-ninth
## stranger stood INSIDE it, on the seam's own metre with its outline under its boots, and strode past. The
## card said "the black seam right of you" and the ring said nothing about what it ringed; three reports say
## they hunted "black" and pressed shadows and holes, because a solid black metre and an open black shaft
## mouth are the same black.
##
## The ring stays a pointer that does not read (D0428): its geometry answers WHERE. One word under it
## answers WHICH -- ORE, COAL SEAM, FORGE, RIG, DRILL, MOUTH, COAL, HOPPER, GENERATOR, WINCH HEAD -- and
## nothing else. The word is decided by WHAT THE RING STANDS ON, not by the rung alone: `TargetGuide.target`
## sends the smelt rung to the seam until the pack holds coal and to the forge after (D0486), the build rung
## to the drill pile until the drill is in hand and to the shaft's mouth after (D0459), the winch rung to the
## rig until the head is paid out (D0492), so the word reads the target back rather than re-deciding it.
##
## THE INK IS THE TARGET'S OWN (D0449): `TargetGuide.INK` over `TargetGuide.RIM`, never a status colour --
## the target is the one white mark on the screen and a second colour under it would make it two marks.
## The word does NOT breathe with the ring: the ring's pulse is what finds the eye, and a word whose
## contrast moves is a word that gets read twice. It takes the ring's alpha flat.
##
## WHERE IT SITS is the one rule the dock's own header sets out (`LessonDock`): the zone round the target is
## where every verb lands, so nothing readable may cover the metre the pointer has to hit. The word goes
## BELOW the ring, outside its compass ticks, clear of the ringed metre and clear of the body's own box --
## pushed further down past either when it would cross it, never sideways, so its place under the ring is
## the same place every time.

const FS: int = 7                      ## authored type size: the rail's label size, the smallest the HUD sets
const GAP: float = 3.0                 ## authored px of air under the ticks, and under anything else it clears
const PAD: float = 2.0                 ## authored px either side of the word inside its rect
const RIM_PX: float = 1.0              ## canvas px the rim is offset by, in each of the eight directions
## The rim is eight offset draws rather than `draw_string_outline`: an outline that a font has no cache for
## draws NOTHING and says so nowhere, and this rim is what keeps the word off a lit rock face.
const RIM_STEPS: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0),
	Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]
## THE WORD SAYS WHICH SIDE OF THE LINE (D0521, strangers 103-120): when the ring is on a machine or the
## shaft's mouth and the body's centre is within the drop's own reach of it (`RingPainter.in_reach`), the
## word reads "FORGE · IN REACH". S119 stood at the band's last cell and pressed Q eleven times at TOO FAR;
## S111: "the game showed me I was always too far but never showed me where close enough was".
const IN_REACH: String = " · IN REACH"


## The word for the rung `id` whose ring stands on `at` (world px), or "" for a rung with no target and for
## a rung that points at nothing nameable. Pure over the observation.
## What the last draw pass decided (word, rect, alpha), the one witness a suite has that `TargetGuide.paint`
## reached this far: every pin over `word`/`label_rect` is pure, and a broken `draw_string` would be a quiet
## green without it (D0499's own caveat).
static var last_drawn: Dictionary = {}


static func word(id: StringName, o: Interface.Observation, at: Vector2) -> String:
	if o == null or at == TargetGuide.NONE:
		return ""
	match id:
		&"mine":
			return "ORE"
		&"smelt":
			return "FORGE" if machine_at(o, at, &"processor") else "COAL SEAM"
		&"deliver":
			return "INGOTS" if pile_holds(o, at, &"ingot") else "RIG"   # the dropped stack first (D0505)
		&"build":
			return "DRILL" if pile_holds(o, at, &"drill") else "MOUTH"
		&"fuel":
			return "COAL"
		&"hopper":
			return "HOPPER"
		&"power":
			return "GENERATOR"
		&"winch":
			return "WINCH HEAD" if pile_holds(o, at, &"winch_head") else "RIG"
	return ""


## The logic metre a world point lies in.
static func metre_of(at: Vector2) -> Vector2i:
	var m: float = float(Interface.Units.LOGIC_PX)
	return Vector2i(floori(at.x / m), floori(at.y / m))


## Whether a machine of this record id stands on the metre the ring is on: how the word tells the forge
## (a machine) from the seam (a cell), which is the fork `TargetGuide.target` makes for the smelt rung.
static func machine_at(o: Interface.Observation, at: Vector2, id: StringName) -> bool:
	var m: Vector2i = metre_of(at)
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") == id and rec.get("cell", Vector2i(-1, -1)) == m:
			return true
	return false


## Whether a machine of any record stands on the metre the ring is on.
static func machine_on(o: Interface.Observation, at: Vector2) -> bool:
	var m: Vector2i = metre_of(at)
	for rec: Dictionary in o.machines:
		if rec.get("cell", Vector2i(-1, -1)) == m:
			return true
	return false


## Whether the verb this ring asks for lands on the ringed METRE by the one reach rule (`Reach`, from the
## body's centre to the metre's centre): a drop into a machine (smelt's forge, deliver's and winch's rig)
## and BUILD at the shaft's mouth (`Verbs.build` gates on the same `can_reach`). A cell target (ore, the
## seam, coal, a trunk) is the pointer's, snapped by the aim; a pile is scooped by the trunk's own
## distance (D0456). Neither is this rule's, and the ring on them says nothing about reach (D0521).
static func metre_target(id: StringName, o: Interface.Observation, at: Vector2) -> bool:
	if o == null or at == TargetGuide.NONE:
		return false
	if machine_on(o, at):
		return true
	return id == &"build" and word(id, o, at) == "MOUTH"


## Whether the pile on the ringed metre holds this item: how the word tells the drill lying at the rig's
## foot from the shaft's mouth, and the paid winch head from the rig that owes it.
static func pile_holds(o: Interface.Observation, at: Vector2, item: StringName) -> bool:
	var pile: Dictionary = o.piles.get(metre_of(at), {})
	return int(pile.get(item, 0)) > 0


## The word's rect on the canvas: centred on the ring, its top a gap below the ring's compass ticks, and
## pushed further down past any rect in `clear_of` whose columns it would cross. `clear_of` is untyped so a
## caller may hand it a bare array of `Rect2`. Empty rect for an empty word or no font.
static func label_rect(font: Font, text: String, centre: Vector2, r: float, clear_of: Array) -> Rect2:
	if font == null or text == "":
		return Rect2()
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(FS))
	var box := Vector2(size.x + UiTheme.px(PAD) * 2.0, size.y)
	var top: float = centre.y + r + 2.0 + TargetGuide.TICK_LEN + UiTheme.px(GAP)
	for k: Rect2 in clear_of:
		if k.size.x <= 0.0 or k.size.y <= 0.0:
			continue
		if k.position.x < centre.x + box.x * 0.5 and k.end.x > centre.x - box.x * 0.5:
			top = maxf(top, k.end.y + UiTheme.px(GAP))
	return Rect2(Vector2(centre.x - box.x * 0.5, top), box)


## What the word may not cover, on the canvas: the ringed metre -- the square the pointer has to land on --
## and the body's own box, whose edges the observation carries so the view never recomputes them.
static func clearances(frame: Frame, metre: Rect2) -> Array[Rect2]:
	var o: Interface.Observation = frame.obs
	var s: float = float(Fx.SCALE)
	var body := Rect2(Vector2(float(o.left_x), float(o.top_y)) / s,
		Vector2(float(o.right_x - o.left_x), float(o.bottom_y - o.top_y)) / s)
	return [canvas_rect(frame, metre), canvas_rect(frame, body)]


## A world-space rect on the frame's canvas.
static func canvas_rect(frame: Frame, world: Rect2) -> Rect2:
	var p: Vector2 = frame.canvas_of(world.position)
	return Rect2(p, frame.canvas_of(world.end) - p)


## The whole chip, called from the ring's own paint: the rung's word under the ring at `centre` of radius
## `r` (canvas px), at the ring's alpha, or nothing at all. `reached` (a metre target within the drop's
## reach, D0521) appends IN_REACH to the word, and to the receipt.
static func draw_under(ci: CanvasItem, frame: Frame, id: StringName, at: Vector2, centre: Vector2, r: float, alpha: float, reached: bool = false) -> void:
	var text: String = word(id, frame.obs, at)
	if reached and text != "":
		text += IN_REACH
	var font: Font = ThemeDB.fallback_font
	var rect: Rect2 = label_rect(font, text, centre, r, clearances(frame, TargetGuide.target_metre(at)))
	last_drawn = {"word": text, "rect": rect, "alpha": alpha}   # the draw pass's own receipt, for `tests/test_ring_word.gd`
	if rect.size == Vector2.ZERO:
		return
	var pen := Vector2(rect.position.x + UiTheme.px(PAD), rect.position.y + font.get_ascent(UiTheme.pt(FS)))
	for d: Vector2 in RIM_STEPS:
		ci.draw_string(font, pen + d * RIM_PX, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(FS), Color(TargetGuide.RIM, alpha * 0.6))
	ci.draw_string(font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(FS), Color(TargetGuide.INK, alpha))
