class_name MachineDef
extends Resource

## Provisional prototype data. A machine is a named recipe-runner; there is no machine-type enum or
## capability system, both deferred. Runtime state lives in MachineState; this def is a flyweight.

## Stable identifier. Saves and lookups reference this, never the file path.
@export var id: StringName = &""
## Human-readable label for UI. Kept out of sim logic so it stays localizable.
@export var display_name: String = ""
## What this machine runs each cycle. A no-input recipe makes it a source.
@export var recipe: RecipeDef
## Provisional routing tag. Empty (default) means recipe-runner, output falling straight down its column.
## &"splitter" = a router: runs no recipe, divides what falls into it between two downstream columns.
## A thin deletable label, not a type enum, so the sim can branch on the few non-recipe-runners.
@export var behavior: StringName = &""
## Cost to craft one of these machine items (item StringName -> count). Empty = not hand-craftable.
## Provisional numbers.
@export var craft_cost: Dictionary = {}
## Items one craft yields (default 1). Bulk consumables such as rope yield a bundle.
@export var craft_count: int = 1
