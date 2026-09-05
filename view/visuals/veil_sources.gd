class_name VeilSources
extends RefCounted

## EVERY LIGHT BUT THE LAMP CUTS THE VEIL. Ported from `legacy/scenes/world_renderer.gd:3120-3212`
## (`_update_veil`'s source loop and `_veil_cut`'s tint) and `:3081-3118` (the tints and radii). A' step
## 6l (ii), D0375.
##
## Legacy's veil is cut by six sources -- the lamp, the machines, the torches, the conduits, the ore seams
## and the falling motes -- and then the additive pass lays each one's colour on top. The port carried the
## lamp's three cuts (D0336) and, in 6k and 6l (i), every source's ADDITIVE half; the veil itself still
## took no light but the lamp's, so a working furnace in the deep showed its ember on black rock. This is
## the other half: the list of cuts the veil applies, as data, so `VeilPainter.light_rgb_at` can lift its
## texel toward each one and a test can read which sources cut how hard.
##
## LIGHT HAS A COLOUR. Legacy: "the cut lifts each channel toward `255 * tint` rather than toward flat
## white, so lamp-lit rock comes out amber and lift-lit rock comes out teal through the multiply ... This
## is the job the additive pass used to do by painting over the rock, which is why the additive pass could
## drop to a fraction of its old strength: revealing in colour beats repainting in colour." The tint is the
## source's colour at LIGHT_TINT toward white; a full-colour tint "would strangle a channel".
##
## Radii and strengths are legacy's, denominated in metres; centres and radii come out in CELLS, the
## veil's own unit. The machine cut follows legacy's table and NOT the pool's status gate (D0373): legacy
## cuts 0.6 for any machine, only a burner going dark unfuelled and a lift breathing with its power.

const LIGHT_TINT: float = 0.28
const TORCH_LIGHT := Color(1.0, 0.72, 0.34)   ## "a wall torch burns hotter and oranger than the head-lamp"
const TORCH_GLOW_R_M: float = 7.6              ## the wide soft glow that makes a room habitable
const TORCH_GLOW_S: float = 0.52
const TORCH_CORE_R_M: float = 4.4              ## the hot core at the flame
const TORCH_CORE_S: float = 0.94
const MACHINE_R_M: float = 2.8
const MACHINE_S: float = 0.6                   ## the cool working glow, any kind
const FURNACE_S: float = 0.85
const BURNER_S: float = 0.9                    ## and dark when it runs dry
const LIFT_S_BASE: float = 0.35
const LIFT_S_POWER: float = 0.55
const CONDUIT_R_M: float = 1.8
const CONDUIT_GATE: float = 0.04
const CONDUIT_S: float = 0.7
const SEAM_S_BASE: float = 0.62
const SEAM_S_BREATH: float = 0.26
const MOTE_R_M: float = 1.4
const MOTE_S: float = 0.5
## THE STATUS BEACON (D0401, the director's T014 ruling: a starved machine must read from ten metres in
## the dark). A machine that needs something -- fuel, input, power, a clear, a link (`StatusLook`'s `fix`)
## -- cuts the veil a second time in its STATUS colour, a small pool that breathes at `BEACON_HZ`, so the
## dark carries a red or amber pulse where the working glow is a steady cool one. The mark on the face
## still says WHICH fix; the beacon says WHERE, from further than the face can be read.
const BEACON_R_M: float = 1.7
const BEACON_S_LOW: float = 0.30
const BEACON_S_HIGH: float = 0.75
const BEACON_HZ: float = 0.9
## The cull margin, in metres: no source is dropped while its pool can still reach the drawn rect.
const CULL_M: float = TORCH_GLOW_R_M
const PER_M: float = float(MaterialLook.CELLS_PER_METRE)


static func light_tint(source: Color) -> Color:
	return Color.WHITE.lerp(source, LIGHT_TINT)


## How hard one machine cuts, by legacy's table.
static func machine_strength(rec: Dictionary) -> float:
	var kind: String = MachineLook.kind(rec.get("behavior", &""), rec.get("id", &""), bool(rec.get("source", false)))
	if kind == "generator":
		var fuel: int = int(rec.get("fuel", 0)) + int((rec.get("input", {}) as Dictionary).get(&"coal", 0))
		return BURNER_S if fuel > 0 else 0.0
	if kind == "furnace":
		return FURNACE_S
	if kind == "lift":
		return LIFT_S_BASE + LIFT_S_POWER * clampf(float(rec.get("power_permille", 0)) / 1000.0, 0.0, 1.0)
	return MACHINE_S


static func _cut(centre: Vector2, radius_m: float, strength: float, tint: Color = Color.WHITE) -> Dictionary:
	return {"centre": centre, "radius": radius_m * PER_M, "strength": strength, "tint": tint}


static func _logic_centre_cells(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * (float(Interface.Observation.LOGIC_PX) / float(Interface.Observation.CELL_PX))


## The cuts for this frame. `seams` are `OrePainter` seams (cells), `motes` are `FallingItems` motes (px),
## `cull` is in cells and already grown by `CULL_M`. Every centre and radius returned is in cells.
static func cuts(obs: Interface.Observation, seams: Array[Dictionary], motes: Array[Dictionary],
		t: float, cull: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if obs == null:
		return out
	for rec: Dictionary in obs.machines:
		var at: Vector2 = _logic_centre_cells(rec["cell"])
		if not cull.has_point(at):
			continue
		var s: float = machine_strength(rec)
		if s > 0.0:
			out.append(_cut(at, MACHINE_R_M, s, light_tint(MachineLook.color(rec.get("behavior", &""), rec.get("id", &""), bool(rec.get("source", false))))))
		var beacon: Dictionary = beacon_cut(rec, at, t)
		if not beacon.is_empty():
			out.append(beacon)
	for cell: Vector2i in obs.placed:
		var at: Vector2 = _logic_centre_cells(cell)
		if not cull.has_point(at):
			continue
		if obs.has_torch(cell):
			out.append(_cut(at, TORCH_GLOW_R_M, TORCH_GLOW_S, light_tint(TORCH_LIGHT)))
			out.append(_cut(at, TORCH_CORE_R_M, TORCH_CORE_S, light_tint(TORCH_LIGHT)))
		elif obs.has_conduit(cell):
			var lvl: float = clampf(float(obs.power_at(cell)) / float(int(MachinesRecords.RECORDS["conduit"]["capacity_milli"])), 0.0, 1.0)
			if lvl > CONDUIT_GATE:
				out.append(_cut(at, CONDUIT_R_M, lvl * CONDUIT_S))
	for seam: Dictionary in seams:
		var pos: Vector2 = seam["pos"]
		out.append({"centre": pos, "radius": float(seam["radius"]), "strength": seam_strength(t, pos.x), "tint": light_tint(OrePainter.SEAM_LIGHT)})
	var cell_px: float = float(Interface.Observation.CELL_PX)
	for m: Dictionary in motes:
		var at: Vector2 = (m["pos"] as Vector2) / cell_px
		if cull.has_point(at):
			out.append(_cut(at, MOTE_R_M, MOTE_S))
	return out


## The status beacon for one machine record, or {} for a machine that wants nothing done. Breathes between
## `BEACON_S_LOW` and `BEACON_S_HIGH` on `t`; the colour is the status's own from `StatusLook`, tinted the
## way every source is so it composes with the rest.
static func beacon_cut(rec: Dictionary, at: Vector2, t: float) -> Dictionary:
	var look: Dictionary = StatusLook.of(StringName(rec.get("status", &"idle")))
	if StringName(look["fix"]) == &"none":
		return {}
	var breath: float = 0.5 + 0.5 * sin(t * TAU * BEACON_HZ)
	return _cut(at, BEACON_R_M, lerpf(BEACON_S_LOW, BEACON_S_HIGH, breath), light_tint(look["color"]))


## A seam's cut breathes with the same breath its glow does, so the reveal and the pool never disagree.
static func seam_strength(t: float, x_cells: float) -> float:
	return SEAM_S_BASE + SEAM_S_BREATH * OrePainter.breath(t, x_cells)


## This frame's cuts for the veil: the ore painter's seams and the falling items' motes if the painter
## was given them, the machines, torches and conduits off the observation; culled to the drawn rect grown
## by the widest pool, so no source is dropped while its light can still reach the screen.
static func cuts_for(frame: Frame, drawn: Rect2i, ore: OrePainter, falling: FallingItems) -> Array[Dictionary]:
	var seams: Array[Dictionary] = ore.seams_for(frame.look, frame.obs) if ore != null and frame.look != null else []
	var motes: Array[Dictionary] = falling.motes() if falling != null else []
	var cull: Rect2 = Rect2(drawn).grow(CULL_M * PER_M)
	return cuts(frame.obs, seams, motes, frame.anim_time, cull)


## Legacy's `_veil_cut` composition: start from the grey light level `s`, and let every cut lift each
## channel toward its tint by `VeilPainter.cut_lift` -- "a light only ever adds light to a channel", and
## sources stack by each lifting what the previous one left, so overlapping pools brighten toward the tint
## and can never overshoot it. With no cuts the answer is `s` in every channel.
static func compose(s: float, cuts: Array[Dictionary], cell: Vector2i) -> Color:
	var g: float = clampf(s, 0.0, 1.0)
	var rgb := Vector3(g, g, g)
	for cut: Dictionary in cuts:
		var lift: float = VeilPainter.cut_lift(cut["centre"], float(cut["radius"]), float(cut["strength"]), cell)
		if lift <= 0.0:
			continue
		var tint: Color = cut["tint"]
		var target := Vector3(tint.r, tint.g, tint.b)
		for k: int in 3:
			if target[k] > rgb[k]:
				rgb[k] += (target[k] - rgb[k]) * lift
	return Color(rgb.x, rgb.y, rgb.z, 1.0)
