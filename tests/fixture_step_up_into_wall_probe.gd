extends SceneTree

## D0202. A minimal, hand-authored reproduction of a COLLISION RESOLVER defect: standing at the foot of a
## ragged wall and pressing toward it makes `try_step` lift the body INTO solid rock, from which it never
## recovers -- overlap grows, the body accelerates, and within a few hundred ticks it is ejected out of
## the world entirely.
##
## Not a suite (no `_finish()`, doesn't extend `test_base.gd`): the defect is UNFIXED and the collision
## resolver is a hard stop for the slice that found it, so this is a reproducer for whoever takes the
## collision arc, not a gate that would paint CI red about something nobody is allowed to touch here.
##
## NO MINING. That is the whole point. It was found by replaying the director's own `--play` session at
## bite radius 1 (`tools/measure_play_session.gd <log> 1`), and the tick it goes wrong on excavates NOTHING
## -- the grid is byte-identical either side of it. The bite only carved the shaft; what fails is
## `body.tick()` against a static geometry, so the geometry is transcribed here verbatim and the mining
## verb is absent. Reachable in shipped Slice 1 too: any cell set a radius-1 blow clears, a radius-0 blow
## clears one at a time.
##
## THE GEOMETRY, exactly as dumped at the failing tick (`#` solid, `.` open; the body's box covers columns
## 1-4, rows 3-12, standing on row 13):
##
##       0123456789012
##   r 0 #############
##   r 1 #.....#######     <- the right wall is at column 6 here ...
##   r 2 #......######
##   r 3 #.....#######
##   r 4 #......######
##   r 5 #.....#######
##   r 6 #.....#######
##   r 7 #......######
##   r 8 #.....#######
##   r 9 #......######
##   r10 #.....#######
##   r11 #....########     <- ... but at column 5 here, a two-row ledge at the body's feet
##   r12 #....########
##   r13 #############
##
## THE MECHANISM (corrected -- D0203 supersedes D0202's account of it). Pressing right, the body's lower
## rows meet the column-5 ledge at rows 11-12. That ledge is inside `STEP_UP_PX`, so `_try_step` runs --
## and it DOES validate its destination, `_box_blocked` on the body's own box translated up by the lift,
## half-open bounds and all. The step is legal when it is taken.
##
## What goes wrong is that it is undone inside its own tick. `Body.tick` runs `_integrate_horizontal` ->
## `pos_x +=` -> `HorizontalResolve.resolve` (the step) -> `_integrate_vertical` -> `VerticalResolve`. The
## vertical pass runs AFTER the step, moves the body again by one tick of gravity against the `vel_y` the
## step had just zeroed, and leaves it inside rock without re-grounding it. The tell is on screen and
## contradictory: the tick ends with `floor_source_this_tick = "try_step"` and `on_floor = false`, which
## cannot both be true, because `_try_step` sets `on_floor = true` as it lifts.
##
## Run: godot --headless --path . --script res://tests/fixture_step_up_into_wall_probe.gd
## Prints one line per tick and a verdict. Exits 0 either way -- it reports, it does not gate.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const TICKS: int = 12
## Transcribed from the dump above. Row 13 is the floor the body rests on; rows 14+ are irrelevant to the
## step and are left solid.
const MAP: Array[String] = [
	"#############",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#......######",
	"#.....#######",
	"#....########",
	"#....########",
	"#############",
	"#############",
]


func _initialize() -> void:
	var grid: TileGrid = TileGrid.new(MAP[0].length(), MAP.size(), 1)
	for row: int in MAP.size():
		for col: int in MAP[row].length():
			if MAP[row][col] == "#":
				grid.set_material(Vector2i(col, row), &"clay")
	# The body's own position at the failing tick, in pixels: centred on x=12 (box 4..20, columns 1-4) and
	# y=32 (box 12..52, rows 3-12), at rest on row 13. Stated as pixels rather than derived from a cell,
	# because it is a transcribed observation and deriving it would invite a rounding that moves it.
	var body: Body = Body.new(Fx.from_int(12), Fx.from_int(32))
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1  ## the director pressed RIGHT for the first time on this tick, and only this
	var worst: int = 0
	for t: int in TICKS:
		body.tick(input, grid)
		var overlap: int = PropertyChecks.solid_overlap_count(body, grid)
		worst = maxi(worst, overlap)
		print("  t%-3d pos=(%6.2f,%7.2f) vel=(%7.2f,%7.2f) floor=%-5s src=%-20s OVERLAPPING %d solid cells%s"
			% [t, float(body.pos_x) / float(Fx.SCALE), float(body.pos_y) / float(Fx.SCALE),
			float(body.vel_x) / float(Fx.SCALE), float(body.vel_y) / float(Fx.SCALE),
			str(body.on_floor), str(body.floor_source_this_tick), overlap,
			"  <<< BOUNDS VIOLATION" if body.bounds_violation_this_tick else ""])
	if worst > 0:
		print("REPRODUCED: the body ended up inside %d solid cell(s) after pressing toward the ledge." % worst)
	else:
		print("NOT REPRODUCED: the body never overlapped solid rock. If this is a fix, retire the fixture;")
		print("if it is a change of geometry or spawn, the transcription above no longer poses the defect.")
	quit(0)
