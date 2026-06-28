class_name MachineDef
extends Resource

## PROVISIONAL prototype data. For Prototype 1 a machine is simply a named recipe-runner:
## its behaviour emerges from its recipe, NOT from a machine-type enum or a capability system
## (both deferred — the real machine model is an open question; see DECISIONS.md and
## docs/RISKS.md). Individual placed machines hold runtime state in MachineState and share
## this definition (flyweight).

## Stable identifier — saves/lookups reference this, never the file path (see docs/RISKS.md).
@export var id: StringName = &""
## Human-readable label for UI. Kept out of sim logic so it stays localizable.
@export var display_name: String = ""
## What this machine runs each cycle. A no-input recipe makes it a source.
@export var recipe: RecipeDef
