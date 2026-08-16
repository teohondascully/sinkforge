extends SceneTree

## IS THE SURFACE A PLACE, OR A LINE?
##
## Asked because the answer was "a line". Printing the generated surface as a height profile gave this,
## one character per two columns, 0 being the highest ground in the world:
##
##     0000000001249000000000000000000000000000000001100001200000000000
##
## Every column the same height. The apparent range of sixty-seven rows was entirely the three sinkhole
## mouths — the only thing in eighty metres of world that ever left the datum. The relief constants were
## `NEAR_AMP 0.85`, `FAR_AMP_A 1.60`, `FAR_AMP_B 0.90`: two and a half rows of roll, clamped to five.
##
## That was a deliberate retreat and the reason is in the generator's own comment — three-row steps a dozen
## columns from spawn halved the body's travel speed and the fast-forward guard read it as "not advancing".
## What changed since is the movement: the stride survives leaving the ground, the winch hauls at thirteen
## cells a second, and the hook shows you where it will bite. Terrain that used to be a tax on traversal is
## now terrain that gives traversal something to do.
##
## So this layer holds BOTH ends of that, because raising relief without the second half is just
## reintroducing the old bug:
##
##   THERE IS RELIEF.      A real height range, a mean step per column that is not zero, and no enormous
##                         dead-flat plain. Measured with the route mouths EXCLUDED, because a hole in the
##                         ground is not a hill and counting it as one is how the surface got to look like
##                         a landscape in the numbers while looking like a table on screen.
##   IT IS STILL WALKED.   Almost every column-to-column step stays inside the auto-step-up, so a walk
##                         across the world is a walk and not a stairclimb. Amplitude and steepness are
##                         independent — a sixteen-row hill over forty columns steps less than one row per
##                         column — and this is the number that keeps them honest.
##   THE PAD IS FLAT.      The tutorial's ground, where the bazaar and the forge and the mineshaft are
##                         stamped, stays dead level by contract. Relief is for the rest of the world.
##   SOMETHING TO CLIMB.   At least a few faces too tall to walk up. These are the reason the world has a
##                         grapple, and a landscape with none is just a smooth one with more amplitude.
##
##   godot --headless --path . --script res://tools/check_relief.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

const RANGE_MIN: int = 11            ## rows between the highest and lowest ground (mouths excluded)
const FLAT_RUN_MAX: int = 46         ## columns of near-level ground before it is a plain
const STEP_MEAN_MIN: float = 0.30    ## mean rows of change per column — proof something is happening
const WALKABLE_MIN: float = 0.90     ## share of steps the body's auto-step-up glides without jumping
const BLUFF_MIN: int = 2             ## faces too tall to walk up — the reason to own a rope
const BLUFF_ROWS: int = 3            ## ...and how tall that is (MAX_STEP is 1.3 cells)

var _fails: int = 0


func _initialize() -> void:
	print("== is the surface a place ==")
	MainView.dev_start = false
	await _run()
	if _fails == 0:
		print("check_relief: PASS — a landscape, and one you can still walk across")
		quit(0)
	else:
		print("check_relief: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim

	# The GROUND profile: every column's surface, with the route mouths taken out. A sinkhole plunges
	# forty rows and would otherwise dominate every statistic here while contributing nothing a player
	# would ever call relief.
	var ground: Array[int] = []
	var cols: Array[int] = []
	for c: int in FactorySim.GRID_COLS:
		var top: int = sim.surface_row(c)
		if top > Strata.SURFACE_ROW + MOUTH_DEPTH:
			continue                                  # a hole, not a hill
		ground.append(top)
		cols.append(c)

	var lo: int = ground[0]
	var hi: int = ground[0]
	for r: int in ground:
		lo = mini(lo, r)
		hi = maxi(hi, r)

	var steps: int = 0
	var churn: float = 0.0
	var walked: int = 0
	var run: int = 1
	var flat_run: int = 1
	var bluffs: int = 0
	for i: int in range(1, ground.size()):
		if cols[i] != cols[i - 1] + 1:
			run = 1
			continue                                  # a mouth sits between these two: not a real step
		var d: int = ground[i] - ground[i - 1]
		churn += absf(float(d))
		if absi(d) >= BLUFF_ROWS:
			bluffs += 1
		# A marked SCARP face is the deliberate exception to the walkable contract, exactly as a sinkhole
		# mouth is to the sealed-surface one, so it is not counted against it. Everything else is.
		if LayeredWorldGen.on_scarp(cols[i]):
			run = 1
			continue
		steps += 1
		if absi(d) <= 1:
			walked += 1
		if absi(d) <= 1:
			run += 1
			flat_run = maxi(flat_run, run)
		else:
			run = 1

	var mean_step: float = churn / maxf(float(steps), 1.0)
	var walkable: float = float(walked) / maxf(float(steps), 1.0)
	print("  ground runs rows %d..%d (range %d) over %d columns" % [lo, hi, hi - lo, ground.size()])
	print("  mean step %.2f rows/column; %.0f%% of off-scarp steps are walked; %d faces of %d+ rows"
		% [mean_step, walkable * 100.0, bluffs, BLUFF_ROWS])
	print("  longest near-level run: %d columns" % flat_run)
	print("  %s" % _profile(ground, lo, hi))

	_check(hi - lo >= RANGE_MIN,
		"there is relief (%d rows, floor %d)" % [hi - lo, RANGE_MIN])
	_check(mean_step >= STEP_MEAN_MIN,
		"...it is not one long ramp either (%.2f rows/column, floor %.2f)" % [mean_step, STEP_MEAN_MIN])
	_check(flat_run <= FLAT_RUN_MAX,
		"...and no endless plain (%d columns level, cap %d)" % [flat_run, FLAT_RUN_MAX])
	_check(walkable >= WALKABLE_MIN,
		"the world OFF the scarps is still WALKED, not climbed (%.0f%% of steps, floor %.0f%%)"
			% [walkable * 100.0, WALKABLE_MIN * 100.0])
	_check(bluffs >= BLUFF_MIN,
		"...but something in it needs the rope (%d faces, floor %d)" % [bluffs, BLUFF_MIN])
	_check(_pad_is_flat(sim),
		"the tutorial's ground is dead level (columns %d..%d)"
			% [LayeredWorldGen.BASE_PAD_START, LayeredWorldGen.BASE_PAD_END])

	main.queue_free()
	await physics_frame


## Rows below the datum past which a column is a MOUTH rather than ground.
const MOUTH_DEPTH: int = 6


## The fixtures' ground: flat by contract, because the bazaar, the forge and the mineshaft are stamped on
## it and the opening is walked over it a hundred times.
func _pad_is_flat(sim: FactorySim) -> bool:
	var datum: int = LayeredWorldGen.FLAT_SURFACE_ROW
	for c: int in range(LayeredWorldGen.BASE_PAD_START, LayeredWorldGen.BASE_PAD_END + 1):
		# Level or OPEN — the mineshaft and the forge are stamped into this ground and their mouths read as
		# a deeper surface, which is a fixture and not a bump. What must never happen is the pad rising.
		if sim.surface_row(c) < datum:
			return false
	return true


## The surface, one character per two columns, 0 = the highest ground — the picture that started this.
func _profile(ground: Array[int], lo: int, hi: int) -> String:
	var out: String = ""
	for i: int in range(0, ground.size(), 2):
		out += String.chr(0x30 + clampi((ground[i] - lo) * 9 / maxi(hi - lo, 1), 0, 9))
	return out


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL: %s" % msg)
