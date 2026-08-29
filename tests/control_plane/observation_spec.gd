class_name ObservationSpec
extends RefCounted

## Names ONE of docs/ARCHITECTURE.md §5's three standard envelopes -- ORACLE (perfect info, a baseline
## comparison point, unrestricted BY DESIGN, not a leak) or CONSTRAINED (fogged, discoverability-gated).
## LANGUAGE is explicitly deferred: ARCHITECTURE §5 states it is "never in CI," so this slice's own
## automated anti-cheat test has nothing to prove against it yet -- adding it here without a real natural-
## language adapter to exercise it would be an unexercised stub, the same class of risk this project's
## own "gate that runs nowhere" finding warns against.

const ORACLE: StringName = &"oracle"
const CONSTRAINED: StringName = &"constrained"

var envelope: StringName
var vision_radius_cells: int  ## only meaningful for CONSTRAINED; unused (0) for ORACLE


static func oracle() -> ObservationSpec:
	var spec: ObservationSpec = ObservationSpec.new()
	spec.envelope = ORACLE
	return spec


## `radius_cells`: a Chebyshev (box) radius around the body's own cell -- the simplest fog rule that
## still lets the anti-cheat test assert a precise, derivable cell count, rather than an authored-cave-
## shaped visibility region. Dig-based discoverability (only cells the body has actually excavated or
## stands adjacent to) is a real refinement ARCHITECTURE §5's own "discoverability" language points at,
## left for whichever later task promotes this slice into `interface/` proper -- this radius is the first
## concrete, testable CONSTRAINED envelope, not the final one.
static func constrained(radius_cells: int) -> ObservationSpec:
	var spec: ObservationSpec = ObservationSpec.new()
	spec.envelope = CONSTRAINED
	spec.vision_radius_cells = radius_cells
	return spec
