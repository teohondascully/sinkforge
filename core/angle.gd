class_name Angle
extends RefCounted
## THE DETERMINISTIC SINE, AT THE FLOOR OF THE STACK. `sin` is a libm call, and libm is not bound by
## IEEE-754 to round identically on every platform -- D0167 watched macOS and Linux disagree inside a
## generation run over exactly this class of arithmetic. The generation path may not make that call
## (D0381), and now neither may anything that shares a terrain warp across layers: this is
## `sim/terrain_gen/relief.gd`'s own table, hoisted when `core/bedding_dip.gd` needed a sine the view
## could reach and `Relief` was the wrong address for it (view may not depend on sim).
##
## The angle unit is 1/65536 of a turn; a table entry covers 256 units, so a phase resolves to 1.4
## degrees. Conversions from radians happen ONCE at the edge with IEEE basic operations (a multiply, a
## divide, a round -- all correctly-rounded, all portable), and from there it is integers.
##
## round(sin(2*pi*i/256) * 1000) for i in 0..255. Checked in `tests/test_relief.gd` against the values
## a sine must have (the quarter points, the octant, odd symmetry).

const TURN: int = 65536       ## angle units in a full turn
const TABLE_SHIFT: int = 8    ## TURN / SIN_MILLI.size(): 256 angle units per table entry
const MILLI: int = 1000

const SIN_MILLI: PackedInt32Array = [
	0, 25, 49, 74, 98, 122, 147, 171, 195, 219, 243, 267, 290, 314, 337, 360,
	383, 405, 428, 450, 471, 493, 514, 535, 556, 576, 596, 615, 634, 653, 672, 690,
	707, 724, 741, 757, 773, 788, 803, 818, 831, 845, 858, 870, 882, 893, 904, 914,
	924, 933, 942, 950, 957, 964, 970, 976, 981, 985, 989, 992, 995, 997, 999, 1000,
	1000, 1000, 999, 997, 995, 992, 989, 985, 981, 976, 970, 964, 957, 950, 942, 933,
	924, 914, 904, 893, 882, 870, 858, 845, 831, 818, 803, 788, 773, 757, 741, 724,
	707, 690, 672, 653, 634, 615, 596, 576, 556, 535, 514, 493, 471, 450, 428, 405,
	383, 360, 337, 314, 290, 267, 243, 219, 195, 171, 147, 122, 98, 74, 49, 25,
	0, -25, -49, -74, -98, -122, -147, -171, -195, -219, -243, -267, -290, -314, -337, -360,
	-383, -405, -428, -450, -471, -493, -514, -535, -556, -576, -596, -615, -634, -653, -672, -690,
	-707, -724, -741, -757, -773, -788, -803, -818, -831, -845, -858, -870, -882, -893, -904, -914,
	-924, -933, -942, -950, -957, -964, -970, -976, -981, -985, -989, -992, -995, -997, -999, -1000,
	-1000, -1000, -999, -997, -995, -992, -989, -985, -981, -976, -970, -964, -957, -950, -942, -933,
	-924, -914, -904, -893, -882, -870, -858, -845, -831, -818, -803, -788, -773, -757, -741, -724,
	-707, -690, -672, -653, -634, -615, -596, -576, -556, -535, -514, -493, -471, -450, -428, -405,
	-383, -360, -337, -314, -290, -267, -243, -219, -195, -171, -147, -122, -98, -74, -49, -25,
]


## sin(angle) in thousandths, any integer angle: `>>` is arithmetic, so a negative angle lands on the
## right entry after the mask, and a full turn past it lands on the same one.
static func sin_milli(angle_units: int) -> int:
	return SIN_MILLI[(angle_units >> TABLE_SHIFT) & (SIN_MILLI.size() - 1)]


## Radians to angle units, once, at the edge. A multiply, a divide and a round: IEEE guarantees all
## three, which is the whole of what a float may do on a state path.
static func units(rad: float) -> int:
	return int(round(rad / TAU * float(TURN)))


## Thousandths to whole, rounding half away from zero (legacy's `int(round(h))`); integer `/` truncates
## toward zero, so the half is added on the side of the sign.
static func round_milli(v: int) -> int:
	return (v + MILLI / 2) / MILLI if v >= 0 else (v - MILLI / 2) / MILLI
