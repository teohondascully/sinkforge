class_name MaterialDef
extends Resource

## A terrain material. World cells hold a material `id`; everything else about it lives here. Generation emits
## ids only and never imports these Resources; the visualiser maps `id -> MaterialDef -> appearance` through the
## registry. Flyweight: one def per material.

## Stable identifier. The world grids store this and lookups reference it, never the file path.
@export var id: StringName = &""
## Human-readable label for UI/debug. Kept out of sim logic so it stays localizable.
@export var display_name: String = ""
## Which terrain grid this belongs to: &"block" (solid foreground) or &"wall" (background).
@export var layer: StringName = &"block"

# --- appearance (the visualiser reads these; generation never does) ---
## Base fill colour of the tile.
@export var base_color: Color = Color(0.30, 0.22, 0.16)
## Dirt-grain speckle on/off (deterministic per-cell texture so it isn't a flat fill).
@export var grain: bool = true
## Texture GRAMMAR, distinct from colour (TR-02 / TR-04). `grain` is only on/off, so every grained material ran
## one identical noise at a different hue. This picks the fine baker's noise language:
##   Clastic: soil, gravel, clay. Granular noise and rounded clumps, barely any seams.
##   Bedded:  shale and other layered rock. Features stretched horizontally into flat laminae.
##   Massive: stone, deepslate. Restrained speckle, cut by steeply-dipping fracture seams.
@export_enum("Clastic", "Bedded", "Massive") var grammar: int = 0
## Grass-style cap drawn on the exposed top surface. Off when alpha == 0.
@export var cap_color: Color = Color(0, 0, 0, 0)
## Embedded specks (ore nuggets) drawn scattered in the tile. Off when alpha == 0.
@export var nugget_color: Color = Color(0, 0, 0, 0)
## How many nuggets to scatter when nugget_color is visible (denser = reads more as a rich vein).
@export var nugget_count: int = 3
## How much the tile darkens with depth (0 = none).
@export var depth_darken: float = 0.38
## True when exposed veins of this material glitter (discovery accent plus glint sparks). Off for bulk fuels
## such as coal: glittering coal was being mistaken for a blue crystal.
@export var glitters: bool = true


## True when `cap_color` should be drawn (a visible grass cap).
func has_cap() -> bool:
	return cap_color.a > 0.0


## True when `nugget_color` should be drawn (visible ore specks).
func has_nuggets() -> bool:
	return nugget_color.a > 0.0
