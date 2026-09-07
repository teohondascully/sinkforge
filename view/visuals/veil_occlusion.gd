class_name VeilOcclusion
extends RefCounted

## THE LAMP IS OCCLUDED BY THE ROCK IT CROSSES (D0427, Astra's item 5, Part B's first line). The veil's
## lamp pool -- legacy's `lamp_lift`, three radial cuts -- lit rock THROUGH rock: a cell three deep in a
## wall took the same lift as the face, so a lit cave read as a disc of warmth stamped on the mass. Now the
## light a lamp cut delivers to a point falls by exp(-K) for every solid cell on the straight line from the
## cut's centre, the point's own cell excluded -- a face is lit and the mass behind it goes dark over about
## half a metre (two cells keep 37%, four 14%). Zero is legacy's pass and the control of a comparison.
##
## `veil.gdshader::occluded` is the GPU statement of `survives`, sample for sample; this file is the CPU
## statement a suite can pin and a reader can find. `VeilLayer.lamp_occlusion` feeds the shader K, and the
## seat's `--lamp-occlusion=K` overrides it for a capture pair.

const K: float = 0.5
const STEPS: int = 12


## The light that survives the rock between two points in cells: `solid` answers whether a cell is rock.
## Samples the segment at `steps` points, the endpoint's own cell excluded, as the shader does.
static func survives(from_cells: Vector2, to_cells: Vector2, solid: Callable, k: float = K, steps: int = STEPS) -> float:
	if k <= 0.0:
		return 1.0
	var d: Vector2 = to_cells - from_cells
	var step_cells: float = d.length() / float(steps)
	var own := Vector2i(floori(to_cells.x), floori(to_cells.y))
	var solid_cells: float = 0.0
	for i: int in range(1, steps):
		var p: Vector2 = from_cells + d * (float(i) / float(steps))
		var c := Vector2i(floori(p.x), floori(p.y))
		if c != own and bool(solid.call(c)):
			solid_cells += step_cells
	return exp(-k * solid_cells)
