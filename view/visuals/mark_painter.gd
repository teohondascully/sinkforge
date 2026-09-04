class_name MarkPainter
extends RefCounted

## THE MARK GRAMMAR. Ported from `legacy/scenes/world_renderer.gd:1660-2190` (S5): the cursor square, the
## corners, the bar, the dash, the pulse, the ghost, the previews, the feed lip, the placement hint, the
## dig plan, and CHROME. A' step 6m (D0376). `MarkLayout` decides WHAT is on screen as a list of marks;
## this file owns the shapes and transcribes the list, so a test fails on the list and not on a pixel.
##
## Legacy's grammar, kept whole: "A square is where you point. Corners are what you would act on. A dash
## is a plan. A bar is a refusal." The square is chrome and never white ("a permanent mark cannot hold the
## brightest colour the screen has"); it neither breathes nor grows. Corners breathe, grow, and carry the
## thing's own colour, and they are the ONE growing outline: the next press lands here. A bar is struck
## across the cell it refuses, in the one red both refusals share, so the answer survives a glance.
## "An arrow is matter moving. A chevron is attention. Nothing else points."
##
## UNITS. Legacy's strokes and insets are its screen pixels at a 32 px cell; ours is 16, so every one is
## scaled by `S` (WG-4), with a one-pixel floor on the strokes -- a half-pixel line does not draw.
##
## WHAT IS NOT HERE, AND WHY. The objective chevron and its dotted tether: `Objectives` carries no cells
## yet, so guidance has nothing to point at (the chevron is the only floating mark and only guidance may
## draw one; when it comes, it comes here). The Borer and Drift Rig previews: both records are DEAD. The
## tier refusal ("rock over your drive's tier"): this build's mining has no tier gate. The map pin: no
## map click. The sonar: dead.

const CELL: float = float(Interface.Observation.LOGIC_PX)
const S: float = CELL / 32.0                       ## legacy px to ours
const CHROME: Color = MachinePainter.CHROME        ## one chrome, shared with the factory's own chrome
const REFUSE := Color(0.95, 0.45, 0.40)            ## the one red a refusal is drawn in
const FLOW := Color(1.0, 0.80, 0.30, 0.95)         ## a preview's gold: the ore is there and it will flow
const WARN := Color(0.98, 0.45, 0.38, 0.95)        ## red-amber: a machine with nowhere to drain
const DIG := Color(0.95, 0.72, 0.30)               ## the dig plan's amber
const HINT := Color(0.45, 0.85, 0.55)              ## "you may place THERE instead", neither chrome nor red
const ROPE_GHOST := Color(0.90, 0.78, 0.52, 0.55)
const MARK_INSET: float = 1.0 * S
const MARK_W: float = maxf(2.0 * S, 1.0)
const MARK_BAR_W: float = MARK_W * 1.5             ## heavier than the square it crosses, derived
const MARK_ARM: float = 0.25                       ## corner arm as a fraction of the rect
const MARK_FILL: float = MARK_INSET + MARK_W * 0.5 ## a wash starts clear of the outline's stroke
const DASH: float = 6.0 * S
const PULSE_GROW: float = 2.0 * S
const PULSE_BREATH: float = 2.5 * S
const THIN_W: float = maxf(1.5 * S, 1.0)           ## the dig plan's stroke: later, not now


static func logic_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))


## The rect every cell mark is drawn on, so the square, the corners, the dash and the bar cannot come
## apart by a pixel as any one of them is retuned.
static func mark_rect(rect: Rect2) -> Rect2:
	return rect.grow(-MARK_INSET)


## The wash inside a mark: the same rect the outline sits on, pulled in clear of its stroke.
static func mark_wash(rect: Rect2) -> Rect2:
	return mark_rect(rect).grow(MARK_INSET - MARK_FILL)


## What one blow destroys, as a rect around the aimed terrain cell: legacy's cursor covered its metre cell,
## and the metre is what a blow takes; here the blow is `(2r + 1)` cells and the square covers exactly that.
static func blow_rect(o: Interface.Observation) -> Rect2:
	var cell_px: float = float(o.cell_px)
	var r: int = maxi((o.mining_blow_px / maxi(o.cell_px, 1) - 1) / 2, 0)
	var span: float = float(2 * r + 1) * cell_px
	return Rect2((Vector2(o.aim_cell) - Vector2(r, r)) * cell_px, Vector2(span, span))


static func aim_logic(o: Interface.Observation) -> Vector2i:
	return MachinePainter.aim_logic(o)


## Is a build in hand -- a machine, a placed kind or a block material?
static func is_build(o: Interface.Observation) -> bool:
	return MachinesRecords.RECORDS.has(o.held_item) or MaterialsRecords.RECORDS.has(o.held_item)


## The rect the cursor answers about: the METRE when a machine is under the aim or a build is in hand
## (the press acts on the logic cell), else the blow's footprint (the pick acts on terrain cells).
static func target_rect(o: Interface.Observation) -> Rect2:
	if o.aim_cell == Vector2i(-1, -1):
		return Rect2()
	if not o.machine_at(aim_logic(o)).is_empty() or is_build(o):
		return logic_rect(aim_logic(o))
	return blow_rect(o)


## Does a build ghost stand at the aim this frame? The one case the sky must step aside for.
static func ghost_shown(o: Interface.Observation) -> bool:
	return o.aim_cell != Vector2i(-1, -1) and o.aim_in_reach and not o.solid_at(o.aim_cell) \
		and is_build(o) and o.machine_at(aim_logic(o)).is_empty()


## World-pixel points where a marker needs the background to get out of its way (`Frame.marks`).
static func sky_marks(o: Interface.Observation) -> PackedVector2Array:
	var out := PackedVector2Array()
	if o != null and ghost_shown(o):
		out.append(logic_rect(aim_logic(o)).get_center())
	return out


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	for m: Dictionary in MarkLayout.build(frame.obs, frame.anim_time, frame.look):
		draw_mark(ci, m)


## One mark onto the canvas. Every kind `MarkLayout` emits has a case here; an unknown kind draws nothing.
static func draw_mark(ci: CanvasItem, m: Dictionary) -> void:
	match String(m["kind"]):
		"wash":
			ci.draw_rect(m["rect"], m["color"], true)
		"square":
			ci.draw_rect(m["rect"], m["color"], false, float(m.get("width", MARK_W)))
		"corners":
			corners(ci, m["rect"], m["color"], float(m.get("width", MARK_W)))
		"bar", "line":
			ci.draw_line(m["a"], m["b"], m["color"], float(m.get("width", MARK_W)))
		"dash":
			dashed_rect(ci, m["rect"], m["color"], DASH, MARK_W)
		"glyph":
			MachineGlyphs.draw(ci, m["centre"], String(m["glyph"]), float(m["scale"]), false, 0.0)
		"arrow":
			out_arrow(ci, m["cell"], m["color"])
		"rope":
			rope_ghost(ci, float(m["x"]), float(m["top"]), float(m["bot"]), int(m["hung"]))


## Four L-brackets hugging `rect`, arms turned inward. The hovered thing wears them solid and the plan
## thin: the difference between now and later is a stroke width, not a second shape.
static func corners(ci: CanvasItem, rect: Rect2, col: Color, width: float) -> void:
	var arm: float = minf(rect.size.x, rect.size.y) * MARK_ARM
	for corner: int in 4:
		var c := Vector2(rect.position.x if corner % 2 == 0 else rect.end.x, rect.position.y if corner < 2 else rect.end.y)
		var d := Vector2(1.0 if corner % 2 == 0 else -1.0, 1.0 if corner < 2 else -1.0)
		ci.draw_line(c, c + Vector2(arm * d.x, 0.0), col, width)
		ci.draw_line(c, c + Vector2(0.0, arm * d.y), col, width)


## A plan: the perimeter walked clockwise, laying `dash`-length ticks every other `dash`.
static func dashed_rect(ci: CanvasItem, rect: Rect2, color: Color, dash: float, width: float) -> void:
	var pts: Array[Vector2] = [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]
	for i: int in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		var dir: Vector2 = (b - a) / seg
		var t: float = 0.0
		while t < seg:
			ci.draw_line(a + dir * t, a + dir * minf(t + dash, seg), color, width)
			t += dash * 2.0


## A drop-column arrow: goods leave the machine above and fall into `cell`. A stem down the middle of the
## column ending in the machines' own matter wedge -- the same head a spout wears, because it is the same
## claim about the same goods one cell further along. Returns the tip.
static func out_arrow(ci: CanvasItem, cell: Vector2i, tint: Color) -> Vector2:
	var cx: float = float(cell.x) * CELL + CELL * 0.5
	var top_y: float = float(cell.y) * CELL + 3.0 * S
	var tip := Vector2(cx, top_y + CELL * 0.55)
	var jut: float = MachinePainter.WEDGE_JUT * MachinePainter.CHROME_SCALE
	ci.draw_line(Vector2(cx, top_y), tip - Vector2(0.0, jut), tint, maxf(2.5 * S, 1.0))
	MachinePainter.matter_wedge(ci, tip - Vector2(0.0, jut), Vector2(0.0, 1.0), tint)
	return tip


## Rope held over a valid anchor: a translucent hemp line down every cell it will rope, a faint knot at
## each, a tick at the floor it reaches.
static func rope_ghost(ci: CanvasItem, x: float, top: float, bot: float, hung: int) -> void:
	ci.draw_line(Vector2(x, top), Vector2(x, bot), ROPE_GHOST, maxf(1.8 * S, 1.0))
	for k: int in range(1, hung):
		var ky: float = top - 4.0 * S + float(k) * CELL
		ci.draw_line(Vector2(x - 3.0 * S, ky), Vector2(x + 3.0 * S, ky), ROPE_GHOST, maxf(1.5 * S, 1.0))
	ci.draw_line(Vector2(x - 5.0 * S, bot), Vector2(x + 5.0 * S, bot), ROPE_GHOST, maxf(2.2 * S, 1.0))
