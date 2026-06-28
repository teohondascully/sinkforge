class_name MaterialDef
extends Resource

## A TERRAIN MATERIAL — the shared vocabulary of the world-engine handshake (see docs/WORLDGEN.md).
## A cell in the world holds a material `id` (StringName); everything ELSE about that material lives
## here. The GENERATOR emits ids only (it never imports these Resources); the VISUALISER maps
## `id -> MaterialDef -> appearance` through the registry. So gen and viz share only the id
## vocabulary + this def — improve generation OR the look without the other knowing.
##
## Richness later (new ores, rock types, biome looks) = new MaterialDefs, NOT a contract change.
## Flyweight like MachineDef: one def shared by every cell of that material.

## Stable identifier — the world grids store this, lookups reference it (never the file path).
@export var id: StringName = &""
## Human-readable label for UI/debug. Kept out of sim logic so it stays localizable.
@export var display_name: String = ""
## Which terrain layer this material belongs to: &"block" (solid foreground you stand on / dig) or
## &"wall" (background behind dug-out cells). The handshake's two grids.
@export var layer: StringName = &"block"

# --- appearance (the visualiser reads these; generation never does) ---
## Base fill colour of the tile.
@export var base_color: Color = Color(0.30, 0.22, 0.16)
## Dirt-grain speckle on/off (deterministic per-cell texture so it isn't a flat fill).
@export var grain: bool = true
## Grass-style cap drawn on the exposed top surface. Off when alpha == 0.
@export var cap_color: Color = Color(0, 0, 0, 0)
## Embedded specks (ore nuggets) drawn scattered in the tile. Off when alpha == 0.
@export var nugget_color: Color = Color(0, 0, 0, 0)
## How many nuggets to scatter when nugget_color is visible (denser = reads more as a rich vein).
@export var nugget_count: int = 3
## How much the tile darkens with depth (0 = none). Sells "deeper = deeper".
@export var depth_darken: float = 0.38


## True when `cap_color` should be drawn (a visible grass cap).
func has_cap() -> bool:
	return cap_color.a > 0.0


## True when `nugget_color` should be drawn (visible ore specks).
func has_nuggets() -> bool:
	return nugget_color.a > 0.0
