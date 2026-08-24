extends "res://tools/check_base.gd"

## CAN YOU TELL TWO MACHINES APART WITH THE ICONS OFF?
##
## `PC-01`: *"make the machine silhouette carry more identity than its label"*, with the evidence line
## *"Forge hardware is tiny and generic relative to its text badge"* and the constraint *"name may remain
## available on inspect."* The constraint is the whole ticket: the name is allowed to exist, it is just not
## allowed to be **how you know what the thing is.**
##
## THE AUDIT ALREADY SAID THIS AND HALF OF IT WAS DONE. `Visuals.draw_machine_casing`'s own header quotes
## COMPREHENSIVE_AUDIT §194 and answers it exactly: *"Every machine in the game was the same 30x30 flat
## square in a different hue with an icon on it. Hue and icon are how a toolbar distinguishes its entries;
## they are not how a world distinguishes its objects."* What followed was a **lighting** model (top
## catch, bevel, plinth, rivets), and it is good, and it is not the sentence it was written under. Every
## machine is still the same square. The diagnosis was accepted and the silhouette half was never built.
##
## SO THE MEASUREMENT IS A SHAPE MEASUREMENT AND NOTHING ELSE, and each exclusion is one of the answers
## this ticket would otherwise accept from the wrong channel:
##
##   the GLYPH        is a decal on the front. It is precisely what a toolbar uses, and it is what the
##                    ticket says is doing the label's job. `SILHOUETTE_ONLY` turns it off, so this layer
##                    cannot pass on twenty identical boxes wearing twenty different icons.
##   the LIGHT POOL   is a glow, not a body. `check_machine_state` already owns that channel and proved it
##                    carries STATE; letting it carry identity here would double-count one cue for two
##                    tickets. Off.
##   the CASING HUE   is PAINTED OUT (every body drawn in one grey), and the first version of this layer
##                    did not do that, on the reasoning quoted above: that an occupancy mask is already
##                    blind to colour. It is not, because occupancy is decided by a threshold and a
##                    threshold is a brightness. The Descent Engine's shadowed foot sits within 3 levels
##                    of the rock behind it, so a DARK machine measured as a SMALLER machine, and twenty
##                    identical rectangles scored a mean pair difference of 0.201, which the layer would
##                    have reported as twenty distinguishable shapes. **The instrument could not register
##                    its subject, in the same session that catalogued it as the dominant failure here.**
##
## THE UNIT IS THE SHARE OF THE CELL WHERE ONE MACHINE HAS MATERIAL AND THE OTHER DOES NOT: a symmetric
## difference of masks over the patch area. It answers the question a player's eye answers at 16 screen
## pixels (*is that the same box?*) and it cannot be satisfied by any amount of surface treatment,
## which is the property that makes it the right gauge for this ticket rather than a luma comparison.
##
##   godot --path . --script res://tools/check_machine_identity.gd
##
## `SF_MIDENT_DUMP=<dir>` writes each subject's patch and its mask. Numbers say two shapes differ; only
## the image says whether the difference is a shape or a rounding error at the cell border.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40
const SHOW_FRAMES: int = 12           ## frames a newly placed machine gets before the shutter
## How long the stage is given to lose the last machine before the empty-stage control is judged.
## Four frames was the old implicit budget and it was not enough on three runs in six.
const CLEAR_FRAMES: int = 180

## THE REFERENCE'S OWN SETTLE BUDGET, and it is a CONVERGENCE WAIT rather than a frame count because a
## frame count is what was wrong. `REF_SETTLE_STEP` is the gap between two probes of the same cell and
## `REF_SETTLE_MAX` bounds the whole wait.
const REF_SETTLE_STEP: int = 30
const REF_SETTLE_MAX: int = 600
const ANIM_POSE: float = 0.0          ## the cosmetic clock is held here while a frame is read

## THE WHOLE REGISTRY, DISCOVERED RATHER THAN LISTED. A hand-written subject list in a layer about "do the
## machines look alike" would go stale the first time somebody adds a machine, and the machine most
## likely to be a copy of an existing one is the one added last. Read from disk every run.
const MACHINE_DIR: String = "res://src/data/machines"

## The one cell every subject is measured in, alone. Same reason as `check_machine_state`: six machines two
## cells apart lit each other and the layer scored a neighbour's glow as the subject's own.
const STAGE := Vector2i(46, 26)
const ROOM_LEFT: int = 40
const ROOM_RIGHT: int = 54
const ROOM_TOP: int = 22
const ROOM_BOTTOM: int = 28

## HOW FAR FROM BARE ROCK A PIXEL HAS TO BE BEFORE IT COUNTS AS MATERIAL. Not guessed: the empty stage is
## captured twice and the largest difference between those two captures is printed every run as the noise
## floor. This sits far above it, and far below the ~100-level step between rock and any casing in the
## registry: there is nothing in between for it to be sensitive to.
## 12 rather than 25, because the casing's hard outline (the one pixel that IS the silhouette edge)
## composites to about 15 levels over rock, and a threshold that drops the outline is a threshold that
## cannot see the boundary it is measuring.
const MASK_LEVEL: float = 12.0

## HOW MUCH OF THE CELL TWO MACHINES MUST DISAGREE ABOUT.
##
## Set from measurement AFTER the silhouette work, never before it: guessing a floor before playing the
## thing has been wrong four times running in this repository. The first run of this layer reported 0.000
## for all 190 pairs, which is not a number a floor can be derived from; it is the ticket.
## 0.025: a floor set from the measurement, and only after the work, with both sides of the gap stated.
## Before any silhouette existed the whole registry scored 0.000. After it, the tightest pair of DIFFERENT
## kinds is 0.036 (Descent Engine / Splitter) and the next three are 0.041, 0.047 and 0.049, so 0.025
## leaves the tightest passing pair 44% of headroom and fails every pair the old code produced.
const SHAPE_FLOOR: float = 0.025

## PAIRS THAT SHARE A KIND ARE EXEMPT, AND THE EXEMPTION IS THE INTERESTING PART. The Forge, the Iron Forge
## and the Blast Furnace are one machine at three tiers; they take the same profile on purpose, because a
## family that reads as a family is worth more than three strangers. That is a real design position and it
## is also exactly the shape of an escape hatch, so it is bounded from both ends: every exempt pair is
## PRINTED by name every run, and the share of the registry allowed to hide behind it is capped below.
const FAMILY_SHARE_CAP: float = 0.15

var _skipped: bool = false
var _main: MainView = null
var _rect := Rect2i()


func _initialize() -> void:
	print("== with the icons off, is that the same box? ==")
	await _run()
	if _skipped:
		return
	_verdict("check_machine_identity", "a machine's body says which machine it is")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_machine_identity", "no display; every mask would be empty and twenty empty "
			+ "masks are perfectly identical, which this layer would read as its own failure")
		return
	WorldRenderer.BARE_MACHINES = true
	WorldRenderer.SILHOUETTE_ONLY = true   # no glyph, no light pool, and one grey for every body

	MainView.dev_start = false
	MainView.boot_skip_title = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame

	var sim: FactorySim = _main.sim
	for x: int in range(ROOM_LEFT, ROOM_RIGHT + 1):
		for y: int in range(ROOM_TOP, ROOM_BOTTOM + 1):
			sim.mine(Vector2i(x, y))
	for x: int in range(ROOM_LEFT, ROOM_RIGHT + 1):
		sim.set_solid(Vector2i(x, ROOM_BOTTOM + 1), &"stone")
	sim.set_solid(STAGE + Vector2i(0, 1), &"stone")
	_main._renderer.repaint_world()
	_main._player.place(_main._cell_center(Vector2i(ROOM_LEFT + 1, ROOM_BOTTOM)))
	for _i: int in 90:
		await physics_frame
	_rect = _lock_patch(STAGE)
	for _i: int in 20:
		await physics_frame
	_check(_lock_patch(STAGE) == _rect,
		"CONTROL: the camera has stopped — a cell's screen rect is identical 20 frames apart")

	# THE EMPTY STAGE, TWICE. The first capture is the reference every mask is taken against; the second
	# exists only to measure how much two captures of an unchanging cell differ, which is the noise this
	# layer's threshold has to clear. A threshold quoted without its noise floor is a preference.
	# THE REFERENCE HAS TO BE SETTLED, NOT MERELY LATE, AND IT USED TO BE ONLY LATE.
	#
	# The after-capture below already waits for CONVERGENCE: it re-reads until the stage stops differing
	# or `CLEAR_FRAMES` runs out. The reference did not. It was taken on a fixed 90-plus-20 frame budget,
	# and a fixed window measures whatever the machine had time to finish. On an idle box that is enough;
	# inside a twelve-way sweep it is not, and the reference then holds a half-settled picture that the
	# settled after-capture is scored against. The difference gets charged to the machine that was
	# removed, which is the one thing in the frame that did change.
	#
	# THAT IS WHY THIS LAYER WENT RED ON 2 OF 5 SWEEPS AND NEVER ONCE STANDALONE, and three tidier
	# explanations died before this one. The residual is ONE COMPACT BLOB, so it is not the shader's
	# film grain, which is diffuse. The after-capture shows no machine drawn and `machine_at` agrees, so
	# it is not the removal being slow. `lamp_pos` is identical at both captures to five decimals, so the
	# head-lamp is not drifting across the cell. Cutting this settle to two frames REPRODUCES the failure
	# standalone at 0.0744, inside the 0.0187..0.1131 the sweeps had recorded.
	#
	# AND THE BACK-TO-BACK PAIR BELOW CANNOT SEE ANY OF IT, which is why the bar read a confident 0.0000
	# through every one of those reds. Two captures taken one frame apart agree beautifully while both sit
	# at the same point of a slow convergence. Agreement over a one-frame window is not stability; it is a
	# statement about one frame. So the probes here are separated by `REF_SETTLE_STEP`, and the renderer's
	# `_process` is put back between them, because `_luma_patch` switches it off and a frozen world cannot
	# finish settling.
	var ref_waited: int = 0
	var ref_prev: PackedFloat32Array = await _luma_patch()
	while ref_waited < REF_SETTLE_MAX:
		_main._renderer.set_process(true)             # `_luma_patch` froze it; let the world run again
		for _i: int in REF_SETTLE_STEP:
			await physics_frame
		ref_waited += REF_SETTLE_STEP
		var ref_now: PackedFloat32Array = await _luma_patch()
		if _count_over(ref_prev, ref_now, MASK_LEVEL) == 0:
			break
		ref_prev = ref_now
	print("    reference settled after %d frame(s) of gapped waiting (step %d, bound %d)"
		% [ref_waited, REF_SETTLE_STEP, REF_SETTLE_MAX])
	# SAY SO IF IT NEVER SETTLED. An unconverged reference is not a machine finding and must not be read
	# as one; every mask in this run is taken against it.
	_check(ref_waited < REF_SETTLE_MAX,
		"CONTROL: the reference picture stopped changing before it was used (%d frame(s), bound %d)"
			% [ref_waited, REF_SETTLE_MAX])

	var bare: PackedFloat32Array = await _luma_patch()
	var bare2: PackedFloat32Array = await _luma_patch()
	var floor_noise: float = _max_abs(bare, bare2)
	var noisy: int = _count_over(bare, bare2, MASK_LEVEL)
	var noisy_share: float = float(noisy) / float(maxi(bare.size(), 1))
	print("    empty stage: mean luma %.1f, largest still-frame difference %.1f levels, %d of %d pixels (%.4f of the cell) clear the mask threshold"
		% [_mean(bare), floor_noise, noisy, bare.size(), noisy_share])
	# THE CONTROL IS IN MASK UNITS, NOT IN LEVELS, and it was not always; that cost a red sweep.
	#
	# It used to assert `_max_abs(bare, bare2) < MASK_LEVEL * 0.75`: the LARGEST difference between two
	# captures of an unchanging cell, against three quarters of the threshold. A max over a thousand pixels
	# is the statistic most sensitive to a single one, so it is a noisy estimator of exactly the thing it
	# estimates: it read 3.9 the night the threshold was set and 10.7 four runs later with nothing changed,
	# and the second reading failed a layer whose subject had not moved. The stage is not perfectly still
	# either: the body's lamp pulses a few cells away, so a handful of pixels genuinely swing ten levels.
	#
	# The claim that matters is not "no pixel ever wobbles". It is "wobble cannot be mistaken for a machine",
	# and that is answerable in the units the layer actually judges in: the share of the cell a mask covers,
	# against the share two machines must differ by. A max in levels was never comparable to SHAPE_FLOOR;
	# this is. The level figure stays PRINTED, because it is the diagnostic that says whether the stage has
	# started moving, and it should not be the thing that fails.
	_check(noisy_share < SHAPE_FLOOR,
		"CONTROL: still-frame noise masks %.4f of the cell, under the %.3f two machines must differ by"
			% [noisy_share, SHAPE_FLOOR])
	_dump_luma("_stage", bare)

	var subjects: Array[Dictionary] = []
	var unplaceable: Array[String] = []
	for res: String in _registry():
		var def: MachineDef = load("%s/%s" % [MACHINE_DIR, res]) as MachineDef
		if def == null:
			_check(false, "%s loads" % res)
			continue
		var m: MachineState = sim.place_machine(def, STAGE)
		if m == null:
			# NAMED, NOT DROPPED. A layer about "do the machines look alike" that silently skips the ones
			# it could not place is reporting on whichever ones cooperated and calling that the registry.
			unplaceable.append(String(def.display_name))
			continue
		for _i: int in SHOW_FRAMES:
			await physics_frame
		var patch: PackedFloat32Array = await _luma_patch()
		var mask: PackedByteArray = _mask(patch, bare)
		subjects.append({"name": String(def.display_name), "id": String(def.id), "mask": mask,
			"kind": Visuals.machine_kind(def), "cover": _coverage(mask)})
		_dump_luma(String(def.id), patch)
		_dump_mask(String(def.id), mask)
		sim.remove_machine(STAGE)
		for _i: int in 4:
			await physics_frame

	# AND THE BAR CAN BE FAILED, shown on this run rather than argued. The last subject has been taken off,
	# so the stage is empty again: it is photographed once more and put through the same mask the machines
	# went through. Nothing on it should clear the bar. If an empty cell does, the bar is not measuring
	# presence and the control above it is decoration.
	#
	# TAKING THE MACHINE OFF IS NOT THE SAME AS THE PICTURE LOSING IT, and the four frames waited after
	# `remove_machine` were a guess, not a wait. Six runs of one unchanged tree photographed this stage
	# three times while the last subject was still on it: 0.0089, 0.1037 and 0.1084 of the cell, and the
	# last two are more than FOUR TIMES the 0.0250 two machines must differ by. That is a machine in the
	# frame, not noise, so the control was right to fail and the layer was wrong to ask it then.
	#
	# The bar is untouched: still `empty_cover <= noisy_share`, both measured exactly as before. What
	# changed is that the removal is given until `CLEAR_FRAMES` to reach the picture instead of four, and
	# the wait ends the moment it has. A stage that never clears still fails, and now says how long it was
	# given. This is the same fixed-frame-count mistake the grapple layer made against the lamp: a wait
	# whose length is a constant is not a wait on the thing you are waiting for.
	var after: PackedFloat32Array = await _luma_patch()
	var empty_cover: float = _coverage(_mask(after, bare))
	var waited: int = 0
	while empty_cover > noisy_share and waited < CLEAR_FRAMES:
		await physics_frame
		waited += 1
		after = await _luma_patch()
		empty_cover = _coverage(_mask(after, bare))
	# AND WHEN IT FAILS, SAY WHICH OF THE TWO THINGS IT IS. The wait above treats a stage that still shows
	# a machine as a slow removal. Twenty-five runs say the removal usually reaches the picture on the
	# frame it happens -- 0 frames on twenty of the twenty-two passes -- but not always: one pass took 21
	# frames and another 39, so the wait is doing real work and is not merely masking. What it does not
	# cover is the tail: three failures, at 0.0187, 0.0489 and 0.1131, all still uncleared at the 180
	# bound. Whether that tail is the same latency stretched further or a stage that never clears at all
	# is UNRESOLVED, and three failures cannot decide it. (An earlier note here read the distribution as
	# bimodal and concluded waiting could never be the repair; it was written from eight runs and missed
	# the 39-frame sample that was already on record. Retracted.)
	#
	# Which leaves two rivals that the number above cannot tell apart: the sim never lost the machine, or
	# the sim lost it and the picture kept it. `machine_at` answers that in one call, and it is the number
	# a reader would need first, so it leads the failure rather than sitting in a comment for whoever
	# reproduces it next.
	# AND THE FRAME ITSELF, because `[sim: stage empty]` narrows this to the renderer and then stops. What
	# is still drawn there -- the machine's body, its glow, a hole it cut in the lightmap veil -- is a
	# question only the picture answers, and the layer already writes every other patch it takes.
	_dump_luma("_stage_after", after)
	_dump_mask("_stage_after", _mask(after, bare))

	# Phrased as a FACT rather than as a diagnosis, because `_check` prints one label on both paths: a
	# passing run said "so this is the RENDERER holding the last frame" about a stage that had cleared.
	var still_there: bool = sim.machine_at(STAGE) != null
	_check(empty_cover <= noisy_share,
		"CONTROL: the empty stage does NOT clear the bar the machines cleared [sim: %s] (%.4f against "
			% ["A MACHINE IS STILL AT THE STAGE" if still_there else "stage empty", empty_cover]
			+ "%.4f, after %d frame(s) of clearing)" % [noisy_share, waited])

	if not unplaceable.is_empty():
		print("    could not place: " + ", ".join(unplaceable))
	_check(subjects.size() >= 10,
		"%d machines stood on the stage — fewer than ten is not a registry" % subjects.size())
	_report(subjects, noisy_share)

	# AND THE SAME TREATMENT FOR `_count_over`, WHICH IS WHERE THAT FAILURE MODE ACTUALLY WAS. The two
	# synthetic masks below have guarded `_mask` since this layer was written. `_count_over` had no such
	# guard and had been returning ZERO FOR EVERY INPUT SINCE IT WAS WRITTEN: it compared `absf(a - b)`, a
	# difference of two 0..1 luma values, against `MASK_LEVEL` of 12.0, which no such difference can ever
	# exceed. `_mask` multiplies by 255 and `_count_over` did not. One threshold constant, two conventions,
	# ten lines apart.
	#
	# What that cost is not hypothetical. It is both of this layer's uses of the function:
	#
	#     the settle loop   `if _count_over(ref_prev, ref_now, MASK_LEVEL) == 0: break` was `0 == 0`, so the
	#                       reference "converged" on its first probe on every run ever taken. That is why
	#                       the counter read the 30-frame minimum idle AND inside a twelve-way sweep, an
	#                       anomaly recorded against `fac0c71` as unexplained. It was not convergence.
	#     `noisy_share`     forced to exactly 0.0000, so the empty-stage bar was `empty_cover <= 0`: the
	#                       stage had to come back BIT-IDENTICAL to a reference hundreds of frames old.
	#                       The run that found this printed a 31.4-level still-frame difference and
	#                       reported 0 of 2352 pixels over a 12.0 threshold in the same sentence.
	#
	# Repairing the units changes nothing on a quiet stage, measured three times: the back-to-back pair
	# differs by 4.0 levels, under the threshold, so the floor is still 0.0000 and it is now 0.0000 because
	# it was measured rather than because it could not be anything else. It differs only on the runs where
	# the stage is genuinely moving, which are the runs that go red.
	#
	# The controls below are the ones that would have caught it: a pair differing by a known number of
	# LEVELS, and a pair differing by nothing.
	var lo := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var hi := PackedFloat32Array([0.0, 20.0 / 255.0, 0.0, 20.0 / 255.0])
	_check(_count_over(lo, hi, MASK_LEVEL) == 2,
		"CONTROL: two of four pixels 20 levels apart count as over a %.0f-level bar (%d)"
			% [MASK_LEVEL, _count_over(lo, hi, MASK_LEVEL)])
	_check(_count_over(lo, lo, MASK_LEVEL) == 0,
		"CONTROL: a patch against itself counts zero pixels over the bar (%d)"
			% _count_over(lo, lo, MASK_LEVEL))

	# THE GUARD MUST BITE, and on this layer that is not a formality: the entire failure mode is a
	# comparison that returns zero for everything and reads as "no differences found". Two synthetic masks
	# whose difference is known by construction are judged every run.
	var a := PackedByteArray()
	var b := PackedByteArray()
	for i: int in 100:
		a.append(1)
		b.append(1 if i < 70 else 0)
	_check(is_equal_approx(_shape_diff(a, a), 0.0),
		"CONTROL: a mask against itself scores 0.000 (%.3f)" % _shape_diff(a, a))
	_check(is_equal_approx(_shape_diff(a, b), 0.30),
		"CONTROL: two masks differing by 30 of 100 cells score 0.300 (%.3f)" % _shape_diff(a, b))

	_main.queue_free()
	await physics_frame


## Every `.tres` in the machine directory, sorted so the report is stable between runs.
func _registry() -> PackedStringArray:
	var out := PackedStringArray()
	var d: DirAccess = DirAccess.open(MACHINE_DIR)
	if d == null:
		_check(false, "the machine registry directory opens")
		return out
	for f: String in d.get_files():
		if f.ends_with(".tres"):
			out.append(f)
	out.sort()
	return out


func _report(subjects: Array[Dictionary], floor_share: float) -> void:
	print("    %-16s %9s" % ["machine", "cell used"])
	for s: Dictionary in subjects:
		print("    %-16s %8.0f%%" % [s["name"], float(s["cover"]) * 100.0])

	# THE STAGE MUST HAVE DRAWN, and every other control on this layer passes its hardest on a frame where
	# nothing did. An unmoving camera is unmoving. Still-frame noise is at its quietest when there is no
	# picture to be noisy. The two synthetic masks do their arithmetic without looking at the screen. On a
	# blank stage every mask is empty, every pair scores zero, and the layer reports that twenty machines
	# are drawn as the same shape, which is an art finding, in a sweep, about a frame with no art in it.
	#
	# The quantity that tells the two apart was already in the table above and was never asserted. It is
	# checked against this run's own empty-stage reading rather than against zero, because the floor for
	# "something is there" has to come from a measurement of the stage with nothing on it.
	var blank: Array[String] = []
	for s: Dictionary in subjects:
		if float(s["cover"]) <= floor_share:
			blank.append("%s (%.4f)" % [s["name"], float(s["cover"])])
	_check(blank.is_empty(),
		"CONTROL: every machine put more of itself on the stage than still-frame noise does (%.4f)%s"
			% [floor_share, "" if blank.is_empty() else " — DREW NOTHING: " + ", ".join(blank.slice(0, 8))
				+ ("" if blank.size() <= 8 else " ... and %d more" % (blank.size() - 8))])
	if not blank.is_empty():
		# The pair statistics below are about shapes, and there are no shapes. They are not stood down and
		# not skipped: the control above has already failed the layer. They are simply not reported, because
		# a number computed from an empty stage would be quoted as if it were about the machines.
		print("    the stage did not draw, so the pair statistics are not computed")
		return

	var worst: float = 9.0
	var best: float = -1.0
	var worst_pair: String = ""
	var best_pair: String = ""
	var twins: Array[String] = []
	var family: Array[String] = []
	var below: Array[String] = []
	var total: float = 0.0
	var pairs: int = 0
	var ranked: Array[Array] = []
	for i: int in subjects.size():
		for j: int in range(i + 1, subjects.size()):
			var d: float = _shape_diff(subjects[i]["mask"], subjects[j]["mask"])
			total += d
			pairs += 1
			var label: String = "%s/%s" % [subjects[i]["name"], subjects[j]["name"]]
			ranked.append([d, label])
			if d < worst:
				worst = d
				worst_pair = label
			if d > best:
				best = d
				best_pair = label
			if String(subjects[i]["kind"]) == String(subjects[j]["kind"]):
				family.append("%s (%s, %.3f)" % [label, subjects[i]["kind"], d])
				continue
			if is_zero_approx(d):
				twins.append(label)
			elif d < SHAPE_FLOOR:
				# FOUR DECIMALS, AND THE FLOOR PRINTED THE SAME WAY. At three, a pair at 0.0249 printed
				# as "0.025" against a bound printed as "2.5%", so the failure line read as a pair
				# sitting exactly on its own limit and said nothing about which side it was on.
				below.append("%s (%.4f)" % [label, d])
	print("    %d pairs — mean %.3f, tightest %.3f (%s), widest %.3f (%s)"
		% [pairs, total / maxf(float(pairs), 1.0), worst, worst_pair, best, best_pair])
	# THE TIGHT END IS THE ONLY END WITH INFORMATION IN IT. A mean over 190 pairs is dominated by the
	# machines that were never in question, and the floor this layer will eventually hold has to be argued
	# from the pairs nearest to it, including the ones that are alike ON PURPOSE, which a single number
	# cannot tell apart from the ones that are alike by neglect.
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	print("    the ten most alike:")
	for k: int in mini(10, ranked.size()):
		print("      %.3f  %s" % [ranked[k][0], ranked[k][1]])

	# PIXEL-IDENTICAL BODIES ARE THEIR OWN FINDING, reported separately from the floor. A pair at 0.004 is
	# a machine that needs more shape; a pair at exactly 0.000 is **the same drawing**, and calling those
	# two things by one name would let the second hide inside a threshold discussion.
	_check(twins.is_empty(),
		"no two machines are drawn as the SAME SHAPE%s"
			% ("" if twins.is_empty() else " — IDENTICAL (%d of %d pairs): " % [twins.size(), pairs]
				+ ", ".join(twins.slice(0, 6))
				+ ("" if twins.size() <= 6 else " ... and %d more" % (twins.size() - 6))))
	print("    same-kind pairs, exempt and named: %s"
		% ("none" if family.is_empty() else ", ".join(family)))
	_check(float(family.size()) / maxf(float(pairs), 1.0) <= FAMILY_SHARE_CAP,
		"the family exemption covers %d of %d pairs (cap %.0f%%) — an exemption that grows to fit the "
			% [family.size(), pairs, FAMILY_SHARE_CAP * 100.0] + "registry has stopped being one")
	_check(below.is_empty(),
		"every pair of machines of DIFFERENT kinds disagrees about at least %.4f of the cell%s"
			% [SHAPE_FLOOR,
				"" if below.is_empty() else " — TOO ALIKE: " + ", ".join(below.slice(0, 8))])


## The share of the patch where exactly one of the two machines has material. Symmetric, so it does not
## matter which is named first, and blind to colour, so a repaint scores zero.
func _shape_diff(a: PackedByteArray, b: PackedByteArray) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var n: int = 0
	for i: int in a.size():
		if a[i] != b[i]:
			n += 1
	return float(n) / float(a.size())


func _mask(patch: PackedFloat32Array, bare: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in patch.size():
		out.append(1 if absf(patch[i] - bare[i]) * 255.0 >= MASK_LEVEL else 0)
	return out


func _coverage(mask: PackedByteArray) -> float:
	if mask.is_empty():
		return 0.0
	var n: int = 0
	for v: int in mask:
		n += v
	return float(n) / float(mask.size())


## The full transform chain, computed once. Both halves: `get_final_transform()` maps the render viewport
## onto the window and `get_canvas_transform()` maps the world into the viewport, and using only the
## second is the defect that put `check_opening`'s horizon 24px high for its whole life.
func _lock_patch(cell: Vector2i) -> Rect2i:
	var vp: Viewport = _main.get_viewport()
	var xform: Transform2D = vp.get_final_transform() * vp.get_canvas_transform()
	var tl: Vector2 = xform * (Vector2(cell) * float(WorldRenderer.CELL))
	var br: Vector2 = xform * (Vector2(cell + Vector2i.ONE) * float(WorldRenderer.CELL))
	var x0: int = int(floor(minf(tl.x, br.x)))
	var y0: int = int(floor(minf(tl.y, br.y)))
	return Rect2i(x0, y0, int(ceil(maxf(tl.x, br.x))) - x0, int(ceil(maxf(tl.y, br.y))) - y0)


## POSE THE COSMETIC CLOCK BEFORE EVERY SHUTTER, subjects and baseline alike.
##
## Machine glyphs are drawn with the renderer's `_anim_time` (`world_renderer.gd` hands it straight to
## `Visuals.draw_machine_glyph`), and that clock free-runs on wall-clock delta while this layer counts
## frames. Alone the two agree well enough; inside a parallel sweep they come apart, and each machine is
## then photographed at a different point of its own animation.
##
## What gave it away was not a number drifting. In every standalone run and in the green sweeps the tightest
## pair is Iron Forge/Forge at 0.005, which the family exemption covers. In the failing sweep that pair was
## not tightest at all and three unrelated pairs -- Plate Press/Forge, Forge/Splitter, Pump/Splitter -- had
## collapsed onto the bound instead. A shifted reading is noise. A REORDERED DISTANCE MATRIX means the
## subjects were photographed in different states.
##
## Zero is the pose, and `_process` is stopped first: setting the clock and letting the frame run advances
## it again before the draw.
##
## HOW MUCH THE FREE CLOCK WAS WORTH, paired and alternated on one box, three runs each. The pair below is
## the tightest one in the registry, so it is where an inflation shows first:
##
##     free-running   0.0391  0.0336  0.0591      spread 0.0255, no two runs alike
##     posed          0.0281  0.0259  0.0255      spread 0.0026
##
## Every free reading is larger than every posed reading. That is the direction worth being clear about:
## the free clock did not add scatter around the true value, it added DISTANCE. Two machines photographed
## seconds apart are compared against a background that moved between the two shutters, and every pixel
## that moved lands in one mask and not the other, which reads as shape the machines do not have. The
## layer was passing partly on that, and posing the clock took it away rather than adding it.
##
## Which is also why the still-frame control above can be trusted only while this pose is in force: it
## diffs two CONSECUTIVE bare frames, a window far shorter than the seconds that separate the twenty
## subject captures. With the clock frozen the two windows are the same window. Without it they are not,
## and the control would certify a mask threshold against the easiest interval in the run.
func _luma_patch() -> PackedFloat32Array:
	_main._renderer.set_process(false)
	_main._renderer._anim_time = ANIM_POSE
	_main._renderer.repaint_world()
	# AND THE POSE HAS TO REACH THE LAYER THAT CARRIES THE COSMETIC CLOCK, WHICH IT DID NOT.
	#
	# `repaint_world()` queues the terrain chunks and nothing else. `_lights` and `_marks` are queued from
	# `WorldRenderer._process`, which the line above has just switched off. So the two lines above held
	# `_anim_time` at the pose and then photographed those layers exactly as the last FREE-RUNNING process
	# tick had drawn them: the pose was real, and the frame did not contain it. `_paint_lights` draws the
	# ore glint flares, whose flare window is `fmod(_anim_time + offset, PERIOD)`, so a warm circle a pixel
	# or two across was being lit at whatever phase the free clock happened to be at, which is WALL CLOCK
	# and not frame count.
	#
	# Measured, on a stage with NO MACHINE EVER PLACED, the same frame budget burned, coverage read against
	# the run's own settled reference:
	#
	#     stale layers   t=0..320  maxabs 3.9, 5.2, 5.1, 5.9, 7.2, 7.6 levels and climbing
	#     redrawn        t=0..320  maxabs 4.0 at every checkpoint, mean luma 23.3 at every checkpoint
	#
	# The layer's own free-versus-posed table above predicted the direction on live subjects, and the run
	# agrees with it: the tightest pair goes 0.014 to 0.007 against the 0.005 recorded there, and it is the
	# pair that table names rather than a reordered matrix.
	#
	# THIS DOES NOT CLOSE THE INTERMITTENT RED, and the same probe is why. A second transient still fires on
	# an empty stage, warm and round and roughly 58 to 88 pixels, at an onset that moves between runs with
	# identical frame budgets. `_haze` is left out of the redraw on purpose: its ripple runs off the shader
	# `TIME` built-in, which no GDScript pose reaches, so queueing it would look like coverage it cannot give.
	_main._renderer.queue_redraw()
	if _main._renderer._lights != null:
		_main._renderer._lights.queue_redraw()
	if _main._renderer._marks != null:
		_main._renderer._marks.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var out := PackedFloat32Array()
	for y: int in range(_rect.position.y, _rect.end.y):
		for x: int in range(_rect.position.x, _rect.end.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				out.append(0.0)
				continue
			var c: Color = img.get_pixel(x, y)
			out.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	_main._renderer.set_process(true)
	return out


## The LARGEST single-pixel difference between two captures, not the mean. A mean over 2352 pixels hides a
## handful of moving ones, and it is exactly a handful of moving pixels that a mask threshold has to
## survive.
## How many pixels of an unchanging cell move further than `level` between two captures. The population is
## pixels and the answer is a count, so it can be turned into a share of the cell and compared with the
## floor the shape assertion uses, which a maximum in luma levels never could be.
func _count_over(a: PackedFloat32Array, b: PackedFloat32Array, level: float) -> int:
	var n: int = 0
	for i: int in mini(a.size(), b.size()):
		if absf(a[i] - b[i]) * 255.0 > level:
			n += 1
	return n


func _max_abs(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var worst: float = 0.0
	for i: int in a.size():
		worst = maxf(worst, absf(a[i] - b[i]))
	return worst * 255.0


func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return -1.0
	var sum: float = 0.0
	for v: float in a:
		sum += v
	return sum / float(a.size()) * 255.0


func _dump_dir() -> String:
	return OS.get_environment("SF_MIDENT_DUMP")


func _dump_luma(tag: String, _patch: PackedFloat32Array) -> void:
	var dir: String = _dump_dir()
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img: Image = get_root().get_texture().get_image()
	img.get_region(Rect2i(_rect.position, _rect.size)).save_png("%s/%s.png" % [dir.trim_suffix("/"), tag])


func _dump_mask(tag: String, mask: PackedByteArray) -> void:
	var dir: String = _dump_dir()
	if dir == "":
		return
	var img: Image = Image.create(_rect.size.x, _rect.size.y, false, Image.FORMAT_RGBA8)
	for y: int in _rect.size.y:
		for x: int in _rect.size.x:
			var on: bool = mask[y * _rect.size.x + x] == 1
			img.set_pixel(x, y, Color.WHITE if on else Color(0.06, 0.06, 0.09))
	img.save_png("%s/%s_mask.png" % [dir.trim_suffix("/"), tag])
