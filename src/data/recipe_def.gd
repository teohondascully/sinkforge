class_name RecipeDef
extends Resource

## PROVISIONAL prototype data (2026-06-27 "Machine schema provisional"). Input items -> output items
## over a fixed run time. A recipe with no inputs makes its machine a source.

## Stable identifier. Saves and lookups reference this, never the file path or object ref.
@export var id: StringName = &""
## StringName item id -> count consumed per craft.
@export var inputs: Dictionary = {}
## StringName item id -> count produced per craft.
@export var outputs: Dictionary = {}
## Seconds of run time per craft.
@export var time: float = 1.0
