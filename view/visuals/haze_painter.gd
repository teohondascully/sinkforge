class_name HazePainter
extends RefCounted

## THE HEAT-HAZE PLUMES. Ported from `legacy/scenes/world_renderer.gd:3278-3296` (`_paint_heat_haze`) for
## A' step 6p (D0379): "every working furnace or generator gets a plume quad above its casing whose vertex
## alpha, which is the shader's strength mask, is full at the machine top and fades to nothing about 2
## cells up. The shader displaces whatever the screen already shows there, so the plume warps terrain,
## walls, items and the machine's own smoke alike." Only forge-style machines shimmer, keyed on the glyph
## kind as legacy keys, and only while working.
##
## The layer's material is `heat_haze.gdshader`; the painter feeds it the deterministic clock, because the
## ripple must climb for a player and reproduce for a capture (D0277, D0328). Mounted over the veil and the
## tooth and under the additive pools, so hot air bends the rock but not the light.

const CELL: float = float(Interface.Observation.LOGIC_PX)
const S: float = CELL / 32.0
const PLUME_W: float = 0.72       ## of a cell
const PLUME_H: float = 2.1        ## cells up
const PLUME_TAPER: float = 0.34   ## the top's half-width as a fraction of the base width
const PLUME_TOP_PX: float = 2.0   ## legacy px below the casing top the plume roots at
const MASK_BASE: float = 0.85


## Does this machine convect? A forge-style kind, working.
static func is_hot(rec: Dictionary) -> bool:
	var kind: String = MachineLook.kind(rec.get("behavior", &""), rec.get("id", &""), bool(rec.get("source", false)))
	return (kind == "furnace" or kind == "generator") and rec.get("status", &"") == &"working"


## One plume quad over a machine cell: {pts, cols}, the alpha the shader's strength mask.
static func plume(cell: Vector2i) -> Dictionary:
	var top := Vector2(float(cell.x) * CELL + CELL * 0.5, float(cell.y) * CELL + PLUME_TOP_PX * S)
	var w: float = CELL * PLUME_W
	var h: float = CELL * PLUME_H
	var pts := PackedVector2Array([top + Vector2(-w * 0.5, 0.0), top + Vector2(w * 0.5, 0.0),
		top + Vector2(w * PLUME_TAPER, -h), top + Vector2(-w * PLUME_TAPER, -h)])
	var cols := PackedColorArray([Color(1, 1, 1, MASK_BASE), Color(1, 1, 1, MASK_BASE), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)])
	return {"pts": pts, "cols": cols}


static func plumes(o: Interface.Observation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if o == null:
		return out
	for rec: Dictionary in o.machines:
		if is_hot(rec):
			out.append(plume(rec["cell"]))
	return out


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	if ci.material is ShaderMaterial:
		(ci.material as ShaderMaterial).set_shader_parameter(&"anim_time", frame.anim_time)
	for p: Dictionary in plumes(frame.obs):
		ci.draw_polygon(p["pts"], p["cols"])
