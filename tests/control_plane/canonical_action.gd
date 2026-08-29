class_name CanonicalAction
extends RefCounted

## Boundary A's own canonical action type, RAW level only for this slice -- docs/ARCHITECTURE.md §5's
## Semantic level (`goto`/`mine`/`place`/`haul_to`, executed by a harness, never sim) is explicitly
## deferred. The minimal slice (THE CONTROL PLANE brief §4) needs only enough for three different Policy
## implementations to drive the same world through one interface; Semantic actions need a harness-level
## translator that does not exist yet, and building one is out of scope until the Raw-level seam itself
## is proven.

var move_dir: int = 0
var jump_pressed: bool = false
var jump_held: bool = false
var mantle_hold: bool = false
var dig_pressed: bool = false


## The one place a CanonicalAction becomes something `sim/body` actually understands -- a harness-level
## concern (docs/ARCHITECTURE.md §5), simulated here rather than inside `sim/body` itself, which must
## stay engine-and-interface-agnostic (`no_engine_imports.py`'s own scope, and `sim` depends on nothing
## above it in the layer diagram).
func to_input_frame() -> InputFrame:
	var input: InputFrame = InputFrame.new()
	input.move_dir = move_dir
	input.jump_pressed = jump_pressed
	input.jump_held = jump_held
	input.mantle_hold = mantle_hold
	input.dig_pressed = dig_pressed
	return input
