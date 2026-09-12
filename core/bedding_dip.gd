class_name BeddingDip
extends RefCounted
## THE BEDDING DIP -- one function, two layers, and that is the whole reason it is in `core/`.
## Legacy's two slow sines warp the strata's own coordinates along x so a bed dips and rises instead
## of ruling a straight line across the world (`view/visuals/bedding_tone.gd`'s `bedding_metres`).
## Until P044 the MATERIAL layer contacts did not share the warp: `ShaftGenerator._fill_base` read
## them off flat absolute rows, so the tone said the bedding dipped six metres and the rock said it
## never had -- the most artificial thing in the deep frame. `view/` may depend on `core/` and never
## on `sim/`, and `sim/` cannot depend on `view/`, so the line both sides read lives here (the same
## "vocabulary ahead of its address" move as `Seams` and `Reach`).
##
## dip(x) = 2.4 * sin(0.055 * x) + 3.6 * sin(0.021 * x), x in metres -- legacy's constants, untouched.
## Positive means the beds ride UP (smaller row). The sines are `Angle.sin_milli`'s table lookup, so
## the value is identical on every platform -- the contacts the generator writes and the bands the
## tone draws must be THE SAME line, not two functions that happen to agree within a cell on one
## machine's libm.
##
## Reading it: `bedding_metres(col, row) = row_m + dip_m(col)`, so a material contact written at
## `threshold_row - dip_cells(col)` sits at a CONSTANT bedding coordinate -- it is a bedding plane,
## not a horizontal line warped to look like one.

const AMP_A_MM: int = 2400   ## 2.4 m -- the faster sine's amplitude, in thousandths of a metre
const AMP_B_MM: int = 3600   ## 3.6 m -- the slower one's
const FREQ_A: float = 0.055  ## rad per metre (~114 m period)
const FREQ_B: float = 0.021  ## rad per metre (~299 m period)


## The dip in thousandths of a metre at a terrain column. `units()` does the float-to-integer edge
## conversion per term; inside, it is a table lookup and integer multiply.
static func dip_milli_m(col: int, cells_per_m: int) -> int:
	var xm: float = float(col) / float(cells_per_m)
	return (AMP_A_MM * Angle.sin_milli(Angle.units(FREQ_A * xm))
		+ AMP_B_MM * Angle.sin_milli(Angle.units(FREQ_B * xm))) / Angle.MILLI


## The same dip in whole cells, rounded half away from zero -- the unit `_fill_base` writes rows in.
static func dip_cells(col: int, cells_per_m: int) -> int:
	return Angle.round_milli(dip_milli_m(col, cells_per_m) * cells_per_m)
