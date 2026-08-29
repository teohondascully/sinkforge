class_name CanonicalObservation
extends RefCounted

## THE CONTROL PLANE brief's own Boundary A (canonical obs/action <-> policy/adapter), SIMULATED here
## inside `tests/`, not built into the real `interface/` layer -- `interface/` does not exist yet
## (docs/ARCHITECTURE.md §5/§7), and absorbing it into this slice now is the scope blowout the director's
## own ruling explicitly declined. A `Policy` speaks ONLY this shape, never `Body`/`TileGrid` directly
## (unlike `tests/body/scripted_traverse.gd`'s existing oracle policy, which reads both plus privileged
## `HostileChamber` landmark constants) -- proving that seam is correct is this slice's whole job; moving
## it into `interface/` proper is its own later task against ARCHITECTURE's existing plan.

var pos_x: int
var pos_y: int
var vel_x: int
var vel_y: int
var on_floor: bool
var facing: int
var envelope: StringName      ## which ObservationSpec envelope produced this -- provenance, not policy
var visible_cells: Dictionary ## Vector2i -> {"solid": bool, "material": StringName}, scoped by envelope
