class_name AmbiencePainter
extends RefCounted

## THE PLACED PLANE AND ITS CLOCKWORK. Ported from `legacy/scenes/world_renderer.gd` S6: `_draw_conduits`
## and `_conduit_level` (1385-1422), `_draw_power_pulses` (1424), `_draw_torches` (1463), `_draw_saplings`
## (1474), `_draw_drop_paths` and `_guide_end_y` (2347, 2388), `_draw_updrafts` (2363), `_draw_ground`
## (2397), `_draw_speed_streaks` (2787). A' step 6n (D0377).
##
## Everything here is what the factory LEAVES in the world and how it shows it is alive: the copper tubes
## and the beads of power running down them (never up: "the sim's locked hook made visible"), the torches'
## guttering, the saplings' sprouts, the piles a machine has spat out, the teal shimmer rising above a
## lift, the faint guide under every machine to where its output falls, and the body's own speed streaks.
## Cosmetic clockwork over derived fields: every function reads the observation and writes nothing.
##
## TWO CANVASES. The drop-path guides go UNDER the machines (`paint_under`), the rest over them (`paint`),
## because a guide is a line the casing must cover and a bead is a light the casing must not.
##
## UNITS. Legacy's radii, widths and offsets are its screen pixels at a 32 px metre, scaled by `S` (WG-4)
## with a one-pixel floor on strokes; its speeds in pixels a second scale the same way.
##
## NOT HERE: the seal's violet breath (no sealrock band in this world), the sonar (dead), the splitter's
## lateral guide (ruling 4 of §8), the rock's grain (`SeamPainter`, S6's one ported function).

const CELL: float = float(Interface.Observation.LOGIC_PX)
const S: float = CELL / 32.0
const COPPER := Color(0.46, 0.32, 0.20)
const GLOW_DEAD := Color(0.26, 0.22, 0.17)
const GLOW_LIVE := Color(1.0, 0.85, 0.40)
const PULSE_SPEED: float = 1.7            ## links a bead travels per second
const PULSE_GATE: float = 0.08            ## a dead or near-dead tube shows no flow
const BEAD_HALO := Color(1.0, 0.85, 0.45)
const BEAD_CORE := Color(1.0, 0.92, 0.58)
const GUIDE := Color(0.45, 0.55, 0.68, 0.20)
const GUIDE_STUB: float = 0.9             ## cells a guide runs when nothing below catches
const UPDRAFT := Color(0.6, 1.0, 0.92)
const UPDRAFT_MOTES: int = 6
const UPDRAFT_RISE_PX_S: float = 46.0 * S
const UPDRAFT_SWAY: float = 7.0 * S
const PILE_CAP: int = 4                   ## chips a pile shows; a bigger pile reads as more, not as forty
const CHIP_PX: float = 12.0 * S
const CHIP_STEP: float = 4.5 * S
const ITEM_PX: float = 9.0 * S
## Legacy's `FactorySim.SAPLING_GROW_TICKS`: 20 Hz x 120 s, and the hub ticks at 20 Hz here too. No sim
## rule advances a sapling's age in this build yet (the flora loop is step 7's), so every sprout is a nub.
const SAPLING_GROW_TICKS: int = 2400
const STEM := Color(0.48, 0.36, 0.22)
const LEAF := Color(0.40, 0.62, 0.28)
const STREAK_MIN: float = 1.15            ## multiple of the run speed before any line is drawn
const STREAK_COUNT: int = 5
const STREAK_SPREAD: float = 9.0 * S
const STREAK_COLOR := Color(0.86, 0.92, 1.0)
const SWING_MAX_FACTOR: float = 2.8       ## legacy Player.SWING_MAX_SPEED = RUN_SPEED x 2.8
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


static func logic_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## A conduit's power as a fraction of tube capacity: the one reading the copper channel, the beads and the
## veil's cut all key off, so the tube and its light never disagree.
static func conduit_level(o: Interface.Observation, cell: Vector2i) -> float:
	var cap: int = int(MachinesRecords.RECORDS["conduit"]["capacity_milli"])
	return clampf(float(o.power_at(cell)) / float(maxi(cap, 1)), 0.0, 1.0)


## Something a tube couples to: another tube, or a machine (feeding it or drawing from it).
static func coupled(o: Interface.Observation, cell: Vector2i) -> bool:
	return o.has_conduit(cell) or not o.machine_at(cell).is_empty()


## The stubs a tube throws toward its couplings; a lone tube keeps a short vertical nub each way.
static func conduit_stubs(o: Interface.Observation, cell: Vector2i) -> Array[Vector2]:
	var centre: Vector2 = logic_centre(cell)
	var stubs: Array[Vector2] = []
	for d: Vector2i in DIRS:
		if coupled(o, cell + d):
			stubs.append(centre + Vector2(d) * CELL * 0.5)
	if stubs.is_empty():
		stubs = [centre + Vector2(0.0, CELL * 0.5), centre - Vector2(0.0, CELL * 0.5)]
	return stubs


## The links a bead may leave this node by: down when coupled below, and along a lateral toward an
## equal-or-lower tube, ties going right. Never up.
static func flow_links(o: Interface.Observation, cell: Vector2i) -> Array[Vector2i]:
	var links: Array[Vector2i] = []
	var lvl: float = conduit_level(o, cell)
	if coupled(o, cell + Vector2i(0, 1)):
		links.append(Vector2i(0, 1))
	for dx: int in [1, -1]:
		var nb: Vector2i = cell + Vector2i(dx, 0)
		if not o.has_conduit(nb):
			continue
		var nl: float = conduit_level(o, nb)
		if nl < lvl or (is_equal_approx(nl, lvl) and dx == 1):
			links.append(Vector2i(dx, 0))
	return links


static func bead_count(lvl: float) -> int:
	return 1 + int(lvl * 2.0)


## A bead's alpha along its link: brighter with power, faded at both ends of the run.
static func bead_alpha(lvl: float, t01: float) -> float:
	return (0.32 + 0.5 * lvl) * (0.35 + 0.65 * sin(t01 * PI))


## The pixel y a machine's output guide ends at: the top of the next machine down its column inside the
## window, else a short stub.
static func guide_end_y(o: Interface.Observation, col: int, start_row: int, stub_from: float) -> float:
	for row: int in range(start_row, o.logic_window.end.y):
		if not o.machine_at(Vector2i(col, row)).is_empty():
			return float(row) * CELL
	return stub_from + CELL * GUIDE_STUB


## The first open terrain row above a lift, scanning the column's centre cell up to the window's top: the
## top of the shaft the updraft climbs.
static func shaft_top_row(o: Interface.Observation, lift_cell: Vector2i) -> int:
	var n: int = Interface.Observation.LOGIC_PX / Interface.Observation.CELL_PX
	var tc: int = lift_cell.x * n + n / 2
	var top: int = o.window.position.y
	for row: int in range(lift_cell.y * n - 1, o.window.position.y - 1, -1):
		var c := Vector2i(tc, row)
		if o.solid_at(c) or not o.machine_at(Vector2i(lift_cell.x, _floor_div(row, n))).is_empty():
			top = row + 1
			break
	return top


static func _floor_div(a: int, b: int) -> int:
	return (a - (b - 1 if a < 0 else 0)) / b


## The teal motes rising above one lift: {pos, alpha}, empty when the shaft has no height.
static func updraft_motes(o: Interface.Observation, lift_cell: Vector2i, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top_y: float = float(shaft_top_row(o, lift_cell) * o.cell_px)
	var bot_y: float = float(lift_cell.y) * CELL
	var height: float = bot_y - top_y
	if height <= 1.0:
		return out
	var cx: float = float(lift_cell.x) * CELL + CELL * 0.5
	for i: int in UPDRAFT_MOTES:
		var phase: float = fmod(t * UPDRAFT_RISE_PX_S + float(i) * height / float(UPDRAFT_MOTES), height)
		var mx: float = cx + sin((t * 2.0 + float(i)) * 1.7) * UPDRAFT_SWAY
		out.append({"pos": Vector2(mx, bot_y - phase), "alpha": (1.0 - phase / height) * 0.7})
	return out


## The chips a pile shows, bottom first: items in name order, each up to its count, capped at PILE_CAP.
static func pile_chips(pile: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var names: Array = pile.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var total: int = 0
	for v: Variant in pile.values():
		total += int(v)
	var shown: int = mini(total, PILE_CAP)
	for item: Variant in names:
		for _k: int in mini(int(pile[item]), shown - out.size()):
			out.append(StringName(String(item)))
	return out


## Where one sapling stands: rooted at its cell's floor, taller with age, swaying more as it grows.
static func sapling_pose(cell: Vector2i, age: int, t: float) -> Dictionary:
	var g: float = clampf(float(age) / float(SAPLING_GROW_TICKS), 0.0, 1.0)
	var foot := Vector2(float(cell.x) * CELL + CELL * 0.5, float(cell.y + 1) * CELL - 1.0 * S)
	var h: float = (6.0 + g * 22.0) * S
	var sway: float = sin(t * 2.2 + float(cell.x) * 1.3) * (1.0 + g * 1.5) * S
	return {"foot": foot, "tip": foot + Vector2(sway, -h), "h": h, "g": g}


## The body's velocity in world pixels a second, off the observation's per-tick fixed-point numbers.
static func speed_px_s(o: Interface.Observation) -> Vector2:
	return Vector2(float(o.vel_x), float(o.vel_y)) * float(Interface.Observation.TICK_HZ) / float(Fx.SCALE)


## The speed streaks: nothing below 1.15x the run, then a fan of five that grows in toward the swing's
## terminal, longest through the middle. {a, b, alpha}.
static func streaks(o: Interface.Observation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Vector2 = speed_px_s(o)
	var speed: float = v.length()
	var run: float = float(Interface.Observation.RUN_SPEED_PX_S)
	var floor_speed: float = run * STREAK_MIN
	if speed < floor_speed:
		return out
	var t: float = clampf((speed - floor_speed) / (run * SWING_MAX_FACTOR - floor_speed), 0.0, 1.0)
	var dir: Vector2 = v / speed
	var side := Vector2(-dir.y, dir.x)
	var height: float = float(o.bottom_y - o.top_y) / float(Fx.SCALE)
	var origin := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE) + Vector2(0.0, -height * 0.15)
	for i: int in STREAK_COUNT:
		var f: float = (float(i) / float(STREAK_COUNT - 1)) * 2.0 - 1.0
		var a: Vector2 = origin + side * f * STREAK_SPREAD
		var length: float = (16.0 + 30.0 * t) * S * (1.0 - absf(f) * 0.45)
		out.append({"a": a - dir * 6.0 * S, "b": a - dir * (6.0 * S + length), "alpha": (0.10 + 0.26 * t) * (1.0 - absf(f) * 0.5)})
	return out


## UNDER the machines: the faint guide from each machine's foot to where its output falls.
static func paint_under(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	for rec: Dictionary in o.machines:
		var cell: Vector2i = rec["cell"]
		var cx: float = float(cell.x) * CELL + CELL * 0.5
		var bottom: float = float(cell.y + 1) * CELL
		ci.draw_line(Vector2(cx, bottom), Vector2(cx, guide_end_y(o, cell.x, cell.y + 1, bottom)), GUIDE, maxf(2.0 * S, 1.0))


## OVER the machines: tubes and their beads, torches, saplings, piles, updrafts, streaks.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	var o: Interface.Observation = frame.obs
	var t: float = frame.anim_time
	var view: Rect2 = frame.view_world_rect.grow(2.0 * CELL)
	for cell: Vector2i in o.placed:
		var at: Vector2 = logic_centre(cell)
		if not view.has_point(at):
			continue
		if o.has_conduit(cell):
			_draw_conduit(o, ci, cell, t)
		elif o.has_torch(cell):
			MachineGlyphs.draw(ci, at, "torch", MachinePainter.glyph_scale(Rect2(at - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))), true, t)
	for cell: Vector2i in o.saplings:
		if view.has_point(logic_centre(cell)):
			_draw_sapling(ci, sapling_pose(cell, o.sapling_age(cell), t))
	for cell: Vector2i in o.piles:
		if view.has_point(logic_centre(cell)):
			_draw_pile(ci, cell, o.piles[cell])
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == &"lift":
			for m: Dictionary in updraft_motes(o, rec["cell"], t):
				ci.draw_circle(m["pos"], 2.4 * S, Color(UPDRAFT.r, UPDRAFT.g, UPDRAFT.b, m["alpha"]))
	for s: Dictionary in streaks(o):
		ci.draw_line(s["a"], s["b"], Color(STREAK_COLOR.r, STREAK_COLOR.g, STREAK_COLOR.b, s["alpha"]), 1.0)


static func _draw_conduit(o: Interface.Observation, ci: CanvasItem, cell: Vector2i, t: float) -> void:
	var centre: Vector2 = logic_centre(cell)
	var lvl: float = conduit_level(o, cell)
	var glow: Color = GLOW_DEAD.lerp(GLOW_LIVE, lvl)
	var stubs: Array[Vector2] = conduit_stubs(o, cell)
	ci.draw_circle(centre, 4.5 * S, COPPER)
	for s: Vector2 in stubs:
		ci.draw_line(centre, s, COPPER, maxf(7.0 * S, 1.0))
	ci.draw_circle(centre, 2.2 * S, glow)
	for s: Vector2 in stubs:
		ci.draw_line(centre, s, glow, maxf(3.0 * S, 1.0))
	if lvl < PULSE_GATE:
		return
	for d: Vector2i in flow_links(o, cell):
		var span: float = CELL if o.has_conduit(cell + d) else CELL * 0.5
		var to: Vector2 = centre + Vector2(d) * span
		var beads: int = bead_count(lvl)
		for b: int in beads:
			var t01: float = fmod(t * PULSE_SPEED + float(b) / float(beads) + float(cell.x + cell.y) * 0.13, 1.0)
			var p: Vector2 = centre.lerp(to, t01)
			var a: float = bead_alpha(lvl, t01)
			ci.draw_circle(p, 3.0 * S, Color(BEAD_HALO.r, BEAD_HALO.g, BEAD_HALO.b, a * 0.32))
			ci.draw_circle(p, 1.7 * S, Color(BEAD_CORE.r, BEAD_CORE.g, BEAD_CORE.b, a))


static func _draw_sapling(ci: CanvasItem, pose: Dictionary) -> void:
	var g: float = pose["g"]
	var tip: Vector2 = pose["tip"]
	ci.draw_line(pose["foot"], tip, STEM, maxf((1.6 + g * 1.4) * S, 1.0))
	ci.draw_circle(tip, (2.0 + g * 3.5) * S, LEAF)
	ci.draw_circle(tip + Vector2(-2.0 - g * 2.0, 1.0) * S, (1.6 + g * 2.2) * S, LEAF.darkened(0.15))
	ci.draw_circle(tip + Vector2(2.0 + g * 2.0, 0.5) * S, (1.6 + g * 2.2) * S, LEAF.lightened(0.10))


## A pile as a stack of chips on the cell's floor, each a dark plate under the item's own mark.
static func _draw_pile(ci: CanvasItem, cell: Vector2i, pile: Dictionary) -> void:
	var base: Vector2 = Vector2(cell) * CELL
	var idx: int = 0
	for item: StringName in pile_chips(pile):
		var p: Vector2 = base + Vector2(CELL * 0.5, CELL - 6.0 * S - float(idx) * CHIP_STEP)
		ci.draw_rect(Rect2(p - Vector2(CHIP_PX, CHIP_PX) * 0.5, Vector2(CHIP_PX, CHIP_PX)), Color(0.04, 0.04, 0.06))
		ItemLook.draw(ci, p, ITEM_PX, item)
		idx += 1
