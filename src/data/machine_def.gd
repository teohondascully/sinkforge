class_name MachineDef
extends Resource

## PROVISIONAL prototype data. For Prototype 1 a machine is simply a named recipe-runner:
## its behaviour emerges from its recipe, NOT from a machine-type enum or a capability system
## (both deferred — the real machine model is an open question). Individual
## placed machines hold runtime state in MachineState and share
## this definition (flyweight).

## Stable identifier — saves/lookups reference this, never the file path.
@export var id: StringName = &""
## Human-readable label for UI. Kept out of sim logic so it stays localizable.
@export var display_name: String = ""
## What this machine runs each cycle. A no-input recipe makes it a source.
@export var recipe: RecipeDef
## PROVISIONAL routing tag. Empty (default) = ordinary recipe-runner: output falls straight
## down its column. &"splitter" = a router: it runs no recipe and instead divides whatever
## falls into it between two downstream columns. This is a deliberately thin, deletable label
## (NOT a type enum or capability system — those stay deferred); it just lets the sim branch on
## the few machines that don't fit "named recipe-runner". See 2026-06-27.
@export var behavior: StringName = &""
## What it costs to CRAFT one of these machine items (item StringName -> count), e.g. {&"ingot": 3}.
## Empty = not hand-craftable. Drives the Factorio-style build economy: forge ingots → craft a
## machine item into the pack → place it. PROVISIONAL numbers, tuned by feel.
@export var craft_cost: Dictionary = {}
## How many items ONE craft yields (default 1). Machines yield 1; cheap consumables placed in bulk
## (rope segments) yield a bundle so one craft covers a real shaft.
@export var craft_count: int = 1
