class_name RecipeDef
extends Resource

## PROVISIONAL prototype data (see 2026-06-27 "Machine schema provisional").
## A recipe transforms input items into output items over a fixed run time. A machine whose
## recipe has NO inputs is a source (the Ore Vent "mines" ore from nothing). Behaviour comes
## from the recipe data, not from any machine-type enum or capability system.

## Stable identifier — saves/lookups reference this, never the file path or object ref
## (see "Stable IDs"). Items are likewise referenced by StringName id.
@export var id: StringName = &""
## StringName item id -> count consumed per craft.
@export var inputs: Dictionary = {}
## StringName item id -> count produced per craft.
@export var outputs: Dictionary = {}
## Seconds of run time per craft.
@export var time: float = 1.0
