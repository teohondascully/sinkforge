extends "res://tools/check_base.gd"

## CAN YOU TELL A WORKING MACHINE FROM A STOPPED ONE WITHOUT READING ANYTHING?
##
## `PC-05`: *"give installed machines a visible active/idle distinction"*, with the evidence line
## *"labels/pointers carry state because hardware does not"* and a guard that is unusually precise about
## how to check it: **causality survives labels hidden and grayscale.**
##
## That guard names three conditions at once, and the machine's existing state cues fail a different one
## each:
##
##   the STATUS LAMP        is not the hardware. It is a rimmed dot in the corner of the cell, and its own
##                          comment says it "mirrors Factorio's entity status light", UI about the
##                          machine, which is the thing the ticket is complaining about. Hidden here.
##   the WARM TOP BEVEL     is one pixel, and it is a HUE shift: `col.lightened(0.34)` against that lerped
##                          30% toward warm. In grayscale those two are nearly the same value.
##   the GLYPH ANIMATION    is motion, and **a still frame has no motion.** A screenshot, a marketing shot,
##                          a capture in this repository's own evidence directories: none of them contain
##                          a spinning gear, only a gear at some angle.
##
## SO THE MEASUREMENT HAS TO SEPARATE STATE FROM PHASE, or it will score the animation as the cue and
## report a pass on a frame where nothing distinguishes the two machines at all. Three captures, not two:
##
##   D_motion = | A(t1) - A(t2) |     the SAME state, two animation phases: what a still frame can gain
##                                     purely by being taken at a different moment
##   D_state  = | A(t1) - I(t1) |     different states
##
## **A state cue is only real if `D_state` clears `D_motion` by a margin.** If they are comparable, the
## thing being measured is the clock, not the machine, and a gauge that cannot tell those apart would
## have called the animation a success and closed the ticket.
##
## Everything is measured on LUMA (Rec.709) inside the machine's own cell, projected through
## `get_final_transform() * get_canvas_transform()`: the full chain. The half-chain is a known defect in
## this repository: `check_opening` located its horizon 24px high for want of the `get_final_transform()`
## half, judged the wrong band and under-reported for as long as it existed.
##
##   godot --path . --script res://tools/check_machine_state.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40
const STEADY_FRAMES: int = 75         ## frames a state is given to reach its steady LIGHT before the
                                      ## shutter; status says "running", not "finished changing"
const PHASE_FRAMES: int = 22          ## frames between the two same-state captures — a visibly different
                                      ## point in every machine animation in the vocabulary
## THE FAMILY, not one machine. `PC-05` asks for *"one physical state cue for forge/drill family"*, and a
## layer that measured only the Forge would have answered a question about one machine and reported it as
## an answer about the family, which is the measurement-boundary error this project keeps finding, in the
## direction where the population is SMALLER than the claim.
##
## Each is placed on the chamber floor with whatever its own run-gate wants underneath it, then driven by
## one generic feeder and read through `sim.machine_status`. A machine that will not reach `working` is
## REPORTED AND EXCLUDED BY NAME, never dropped: a silently missing subject is how a family test comes to
## be about whichever member happened to cooperate.
const SUBJECTS: Array[Dictionary] = [
	{"res": "processor", "name": "Forge", "under": &"stone"},
	{"res": "drill", "name": "Drill", "under": &"ore"},
	{"res": "generator", "name": "Generator", "under": &"stone"},
	{"res": "crusher", "name": "Crusher", "under": &"stone"},
	{"res": "spur", "name": "Spur", "under": &"stone"},
	{"res": "gear_mill", "name": "Gear Mill", "under": &"stone"},
]
## ONE AT A TIME, IN THE SAME CELL, AND THE FIRST VERSION DID NOT DO THAT EITHER. Six machines standing
## two cells apart lit each other: the Generator's glow washed the Forge beside it to a mean luma of 252
## out of 255 in BOTH states, and the layer reported the Forge as having no state cue when what it
## actually had was a neighbour and a blown highlight. **Every subject now occupies the same cell in turn,
## alone**, so the only thing that differs between two subjects' numbers is the subject.
const STAGE := Vector2i(46, 26)       ## the one cell every subject is measured in
## SATURATION IS MEASURED AS A SHARE OF PIXELS AT THE CEILING, NOT AS A MEAN. A mean can sit at 150 while
## the machine's whole lit face is pinned at 255 and its shading, rivets and glyph are gone: the dark
## surround pulls the average back down and the average reports comfort. What matters is how much of the
## subject has stopped carrying information.
const CLIP_LEVEL: float = 250.0       ## luma at or above this is, for our purposes, white
const CLIP_SHARE: float = 0.25        ## ...and this share of the patch being white means the cue is gone
const ROOM_LEFT: int = 40
const ROOM_RIGHT: int = 54
const ROOM_TOP: int = 22
const ROOM_BOTTOM: int = 28

var _skipped: bool = false
var _main: MainView = null


func _initialize() -> void:
	print("== a working machine has to look different from a stopped one ==")
	await _run()
	if _skipped:
		return
	_verdict("check_machine_state", "the hardware says whether it is running")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_machine_state", "no display; every capture would be a blank frame and the "
			+ "difference between two blank frames is zero, which this layer would read as a failure")
		return
	# SET RATHER THAN REQUIRED. The first version skipped unless `SF_MACHINE_BARE=1` was in the
	# environment, which makes the layer's own precondition somebody else's job, and under `SF_STRICT` a
	# skip is a failure, so a layer that can arrange its own condition and instead demands one from the
	# runner is just a layer that does not run. The env var stays for driving `capture_moments` by hand.
	WorldRenderer.BARE_MACHINES = true

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
	_main._renderer.repaint_world()
	# The body is parked well away so its head-lamp is not the thing that changes between captures, and
	# then given long enough for the CAMERA EASE to finish. A camera still drifting between captures moves
	# the cell under the patch, and every level of difference that drift produces is scored as a state cue.
	_main._player.place(_main._cell_center(Vector2i(ROOM_LEFT + 1, ROOM_BOTTOM)))
	for _i: int in 90:
		await physics_frame
	_rect = _lock_patch(STAGE)
	for _i: int in 20:
		await physics_frame
	var settled: Rect2i = _lock_patch(STAGE)
	_check(settled == _rect,
		"CONTROL: the camera has stopped — a cell's screen rect is identical 20 frames apart (%s vs %s)"
			% [_rect, settled])

	# THE EMPTY STAGE, measured first and kept. It is the control for saturation and for "did anything
	# change at all": a subject whose working shot is no brighter than bare rock is not lit, whatever the
	# difference between its own two states says.
	_rect = _lock_patch(STAGE)
	var bare: PackedFloat32Array = await _luma_patch()
	# AND MEASURED, NOT JUST DESCRIBED. The comment above claimed the empty stage was the control for "did
	# anything change at all" for as long as it has existed, and the capture was taken, printed, and never
	# compared to anything. A layer whose subject failed to draw scored every machine at 0.0 against 0.0
	# and reported that the machines have no state cue, which is a finding about the art, from a frame with
	# no art in it. The claim needs a floor, and a floor for "something is there" has to be read off the
	# stage with nothing on it, so the empty cell is photographed five times and the largest difference
	# between consecutive shots is what a subject has to beat.
	var drift: float = 0.0
	var prev: PackedFloat32Array = bare
	for _i: int in 4:
		var again: PackedFloat32Array = await _luma_patch()
		drift = maxf(drift, _mean_abs(prev, again))
		prev = again
	print("    empty stage mean luma %.1f, %.2f levels of still-frame drift across five shots"
		% [_mean(bare), drift])

	# THE REFERENCES ARE GATHERED IN A PASS OF THEIR OWN, one for each distinct floor a subject stands on,
	# before any machine is placed. One reference for the whole run is a photograph of a different scene:
	# each subject puts a different material in the cell below and the light it throws reaches into the
	# patch. Taking them INSIDE the loop is worse still, and the cost is not subtle. Ten physics frames
	# between `set_solid` and `place_machine`, with nothing else altered, moved the Generator's working
	# face from 203 to 168 levels and its state difference from 137 to 100, which is the difference between
	# that subject reading and not reading. The shutter is not allowed to move, so it does not.
	var refs: Dictionary = {}
	for spec: Dictionary in SUBJECTS:
		var floor_of: StringName = StringName(spec["under"])
		if refs.has(floor_of):
			continue
		sim.set_solid(STAGE + Vector2i(0, 1), floor_of)
		for _i: int in 20:
			await physics_frame
		refs[floor_of] = await _luma_patch()
	print("    %d floor reference(s) taken with the stage empty" % refs.size())

	var rows: Array[Dictionary] = []
	var undrivable: Array[String] = []
	for spec: Dictionary in SUBJECTS:
		sim.set_solid(STAGE + Vector2i(0, 1), StringName(spec["under"]))
		var empty: PackedFloat32Array = refs[StringName(spec["under"])]
		var def: MachineDef = load("res://src/data/machines/%s.tres" % spec["res"]) as MachineDef
		if def == null:
			_check(false, "%s's definition loads" % spec["name"])
			continue
		var m: MachineState = sim.place_machine(def, STAGE)
		if m == null:
			_check(false, "%s stands on the stage" % spec["name"])
			continue
		_feed(sim, m)
		if not await _settle_until(sim, m, &"working"):
			undrivable.append("%s (%s)" % [spec["name"], sim.machine_status(m)])
			sim.remove_machine(STAGE)
			await physics_frame
			continue
		# LIGHT HAS A RISE AND A DECAY, AND THE FIRST VERSION PHOTOGRAPHED BOTH TRANSIENTS.
		#
		# It captured the instant `machine_status` first said `working` and the instant it first said
		# anything else. The Forge's ember ramps up and fades out over many frames, so those two shots
		# caught it mid-ramp and mid-fade, and the numbers moved enormously between two runs of the same
		# code: stopped luma 248.8 then 48.8, `D_motion` 0.71 then 139.49. **A gauge whose answer changes
		# by 200 levels between identical runs is measuring the shutter, not the subject.**
		#
		# So each state is allowed to REACH ITS STEADY VALUE before it is photographed. `machine_status`
		# is the sim's answer to "is it running"; it is not an answer to "has the light finished moving".
		#
		# AND THE TRANSIENT IS CAPTURED AND REPORTED RATHER THAN JUST AVOIDED. `a0` is the frame at the
		# instant the status flips; `a1` is the same state 75 frames later. The gap between them is the
		# ignition flare, and it is worth a permanent column because it was nearly filed as a bug in the
		# tonemap: the Forge reads 253/255 on `a0` and 142 on `a1`, and the post-FX had already taken the
		# blame for blowing machines to white before the shutter here turned out to be the cause.
		# WHAT THE RENDERER BELIEVES, recorded beside what the sim reports. They are two different
		# predicates: `machine_status` is the sim's vocabulary (ten answers, guarded by
		# `check_status_reads`), while the casing and glyph are drawn from `_machine_active`, which is a
		# three-arm match in the renderer that nothing checks against that vocabulary. **If a machine's
		# pixels do not change, the first question is whether the renderer was ever told to change them**,
		# and answering that from the outside is guesswork.
		var flash_work: bool = _main._renderer._machines._machine_active(m)
		var a0: PackedFloat32Array = await _luma_patch()
		for _i: int in STEADY_FRAMES:
			await physics_frame
		# SAMPLED WITH `a1`, AND THE FIRST VERSION SAMPLED IT WITH `a0`: the same shutter error as the
		# ignition flare, made twice, because it was fixed for the pixels and not for the predicate beside
		# them. The Generator reported `OFF` at the working state on every run: `_status_generator` calls a
		# machine working the moment it HOLDS coal, while `_machine_active` asks whether it is BURNING
		# (`fuel > 0`), and the tick that converts one into the other had not run yet at the flip. Both
		# samples are kept, because the gap between them is the only evidence of which of the two happened.
		var live_work: bool = _main._renderer._machines._machine_active(m)
		var a1: PackedFloat32Array = await _luma_patch()
		_dump("%s_work" % String(spec["name"]).to_lower().replace(" ", "_"))
		for _i: int in PHASE_FRAMES:
			await physics_frame
		# NOT RE-FED HERE. Depositing between the two shots changes `progress` and the fill of the recipe
		# bar, which would land in `D_motion` as though it were animation. The single feed above is large
		# enough that the machine is still working; if it is not, the check below says so rather than
		# quietly comparing a working frame to a starving one.
		var still: bool = sim.machine_status(m) == &"working"
		var a2: PackedFloat32Array = await _luma_patch()
		_starve(sim, m)
		var stopped: bool = await _settle_until_not(sim, m, &"working")
		for _i: int in STEADY_FRAMES:
			await physics_frame
		var i1: PackedFloat32Array = await _luma_patch()
		_dump("%s_stop" % String(spec["name"]).to_lower().replace(" ", "_"))
		if not still:
			undrivable.append("%s (stopped working between its two phase shots)" % spec["name"])
			sim.remove_machine(STAGE)
			await physics_frame
			continue
		var live_stop: bool = _main._renderer._machines._machine_active(m)
		rows.append({"name": String(spec["name"]), "a0": a0, "a1": a1, "a2": a2, "i1": i1, "empty": empty,
			"live_work": live_work, "live_stop": live_stop, "flash_work": flash_work,
			"status": String(sim.machine_status(m)), "stopped": stopped})
		sim.remove_machine(STAGE)
		for _i: int in 6:
			await physics_frame
	# A NEGATIVE HALF WAS TRIED HERE AND WITHDRAWN, and it is written down rather than quietly dropped.
	# The intent was the one `check_machine_identity` carries: photograph the empty stage once more at the
	# end and require it to FAIL the bar the machines cleared, so the bar is shown able to fail on real
	# data. It does not work in these units. Scored against the reference the subjects were scored against,
	# the end-of-run empty cell came back 7.98 levels away from it while the bar stood at 3.87, because
	# `drift` is a five-shot burst and sees fast noise only, where the cell wanders further than that over
	# the minutes a run takes. Deriving the bar from the run-length wander instead would make the control
	# measure the quantity that defines it, which is a guard causing what it bounds. The identity layer's
	# version stands because it works in mask units, where an empty cell scores a hard zero.
	#
	# So what is here is the positive half only, and this layer does NOT claim a demonstrated-failable
	# presence bar. The mutation control for it is in the commit that added it: photographing the empty
	# cell in place of the working one reports all three subjects as NOT DRAWN and exits 1.

	# NOT A SILENT CAP. A family test that quietly drops the members it could not drive reports on
	# whichever ones cooperated and calls that the family.
	print("    drove %d of %d subjects to `working`%s"
		% [rows.size(), SUBJECTS.size(),
			"" if undrivable.is_empty() else " — could not drive: " + ", ".join(undrivable)])
	_check(rows.size() >= 2,
		"at least two machines could be driven to `working` (%d) — one is a machine, not a family"
			% rows.size())
	_report(rows, drift)
	_main.queue_free()
	await physics_frame


## Put enough in the forge that the sim's own run-gates open. Read through `machine_status` rather than
## assumed: a fixture that decides for itself when a machine is working is measuring its own opinion.
func _feed(sim: FactorySim, m: MachineState) -> void:
	for item: StringName in [&"ore", &"coal", &"ingot", &"stone", &"gravel", &"iron"]:
		sim.inventory[item] = 64
		sim.deposit(m.cell, item, 8)
	m.power_factor = 1.0


func _starve(sim: FactorySim, m: MachineState) -> void:
	m.input_buffer.clear()
	m.output_buffer.clear()
	m.fuel = 0
	m.progress = 0.0


func _settle_until(sim: FactorySim, m: MachineState, want: StringName) -> bool:
	for _i: int in 90:
		await physics_frame
		if sim.machine_status(m) == want:
			return true
	return false


## Any not-working status will do for the stopped shot; WHICH one differs per machine (`no_input`,
## `no_fuel`, `no_power`, `spent`) and pinning a specific one here would be this fixture deciding what a
## machine's idle looks like instead of asking it.
func _settle_until_not(sim: FactorySim, m: MachineState, avoid: StringName) -> bool:
	for _i: int in 90:
		await physics_frame
		if sim.machine_status(m) != avoid:
			return true
	return false


## The machine's cell, in screen pixels, as LUMA. THE FULL TRANSFORM CHAIN: `get_final_transform()` maps
## the render viewport onto the window and `get_canvas_transform()` maps the world into the viewport;
## using only the second is the defect that put `check_opening`'s horizon 24px high for its whole life.
## THE PATCH RECTANGLE IS COMPUTED ONCE AND REUSED, and the first version did not do that. Recomputing it
## per capture let the camera's easing move the cell a fraction of a pixel between shots, the rect rounded
## to a different size, and `_mean_abs` returned its "these are not comparable" sentinel, which the layer
## then printed as `D_motion = -1.00`, a difference of MINUS ONE LEVEL. **A sentinel that flows into an
## arithmetic comparison stops being a sentinel and becomes a very good score:** `-1.00` sailed through
## `d_state > d_motion * 2` and that assertion PASSED on a run where the motion baseline did not exist.
## The size check is what caught it, and only because it was written first.
var _rect := Rect2i()

func _lock_patch(cell: Vector2i) -> Rect2i:
	var vp: Viewport = _main.get_viewport()
	var xform: Transform2D = vp.get_final_transform() * vp.get_canvas_transform()
	var tl: Vector2 = xform * (Vector2(cell) * float(WorldRenderer.CELL))
	var br: Vector2 = xform * (Vector2(cell + Vector2i.ONE) * float(WorldRenderer.CELL))
	var x0: int = int(floor(minf(tl.x, br.x)))
	var y0: int = int(floor(minf(tl.y, br.y)))
	return Rect2i(x0, y0, int(ceil(maxf(tl.x, br.x))) - x0, int(ceil(maxf(tl.y, br.y))) - y0)


## `SF_MSTATE_DUMP=<dir>` writes each patch as a PNG. **Numbers say a difference is small; only the image
## says WHY**, and this layer has already cost two wrong theories that a glance would have settled: the
## ignition flare read as a tonemap bug, and a casing treatment that measured as no change.
func _dump(tag: String) -> void:
	var dir: String = OS.get_environment("SF_MSTATE_DUMP")
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var img: Image = get_root().get_texture().get_image()
	var cut: Image = img.get_region(Rect2i(_rect.position, _rect.size))
	cut.save_png("%s/%s.png" % [dir.trim_suffix("/"), tag])


func _luma_patch() -> PackedFloat32Array:
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
	return out


func _mean_abs(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var sum: float = 0.0
	for i: int in a.size():
		sum += absf(a[i] - b[i])
	return sum / float(a.size()) * 255.0        # levels out of 255, which is the unit a person can picture


## What share of the patch has reached the ceiling and can no longer hold a difference.
func _clip_share(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var n: int = 0
	for v: float in a:
		if v * 255.0 >= CLIP_LEVEL:
			n += 1
	return float(n) / float(a.size())


func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return -1.0
	var sum: float = 0.0
	for v: float in a:
		sum += v
	return sum / float(a.size()) * 255.0


## THE FLOOR IS NOT SET HERE YET, AND THAT IS DELIBERATE FOR THIS COMMIT. The first run reports; the number
## it reports is what a floor may later be set from. Guessing a floor before measuring has been wrong four
## times running in this project, and every one of those guesses looked reasonable at the time.
## HOW MANY TIMES THE MOTION BASELINE THE STATE DIFFERENCE MUST CLEAR, and this number was 2.0 until the
## measurement showed 2.0 was a coin toss.
##
## At 2.0 the Drill measured ratios of 1.68, 1.94, 2.01, 1.41, 2.04 and 2.43 across six runs of identical
## code: **the verdict flipped between runs while the subject never changed.** A threshold that lands
## inside its own noise is not a threshold, and a green from one is the least trustworthy kind there is.
##
## 3.0 is chosen from a measured GAP rather than from taste, and the gap has both sides stated. After the
## idle-pool gate, three runs give Forge ~16x, Drill ~10x, Generator ~4.4x; the tightest passing subject
## has 45% headroom. Before the gate the Drill sat at ~1.9x. **Any threshold in (2.5, 4.0) separates those
## two populations stably**; 3.0 is the middle of that band and would have failed the old Drill on every
## one of the six runs, including the ones where 2.0 passed it.
const PRESENCE_MARGIN: float = 3.0      ## a drawn machine beats the empty stage's own drift by this
const MOTION_MARGIN: float = 3.0
const MIN_STATE_LEVELS: float = 6.0     ## ...and an absolute floor, so two near-identical frames cannot
                                        ## satisfy the ratio by both being nearly still

func _report(rows: Array[Dictionary], still: float) -> void:
	print("    %-11s %8s %8s %8s %9s %9s %7s %7s   %s"
		% ["machine", "ignite", "work", "stop", "D_motion", "D_state", "clip@ig", "clip@wk", "verdict"])
	print("    (ignite = the frame the status flips; work = the same state %d frames later;"
		% STEADY_FRAMES + " told = what _machine_active reported)")
	var weak: Array[String] = []
	var blind: Array[String] = []
	var clipped: Array[String] = []
	var disagrees: Array[String] = []
	var lagged: Array[String] = []
	var absent: Array[String] = []
	for r: Dictionary in rows:
		var a1: PackedFloat32Array = r["a1"]
		var a2: PackedFloat32Array = r["a2"]
		var i1: PackedFloat32Array = r["i1"]
		var d_motion: float = _mean_abs(a1, a2)
		var d_state: float = _mean_abs(a1, i1)
		if d_motion < 0.0 or d_state < 0.0:
			blind.append(String(r["name"]))
			continue
		# THE SUBJECT HAS TO BE IN THE PICTURE BEFORE ITS PICTURE IS JUDGED. Everything below asks whether
		# this machine's body distinguishes running from stopped, and every one of those questions answers
		# "no, and identically no" for a machine that was never drawn. Presence is judged first, against
		# the empty stage, and a subject that failed it is not also accused of having a weak cue: it is
		# reported as missing and its cue is not scored at all.
		var presence: float = _mean_abs(a1, r["empty"])
		if presence <= still * PRESENCE_MARGIN:
			absent.append("%s (%.2f levels against the empty stage, drift %.2f)" % [r["name"], presence, still])
			continue
		# SATURATION IS ITS OWN VERDICT, not a low score. A patch pinned near white has no room left to
		# carry a cue, and reporting that as "this machine has no state cue" would blame the machine for
		# the tonemap. It is the same finding being bisected on the surface band, arriving here.
		var flare: PackedFloat32Array = r["a0"]
		var share: float = _clip_share(a1)
		var flare_share: float = _clip_share(flare)
		if share >= CLIP_SHARE:
			clipped.append("%s (%.0f%% of its lit face at white)" % [r["name"], share * 100.0])
		var ok: bool = d_state > d_motion * MOTION_MARGIN and d_state >= MIN_STATE_LEVELS
		if not ok:
			weak.append("%s (state %.1f vs motion %.1f)" % [r["name"], d_state, d_motion])
		var told: String = "%s->%s" % ["on" if r["live_work"] else "OFF",
			"ON" if r["live_stop"] else "off"]
		# TWO PREDICATES FOR ONE QUESTION, AND NOTHING IN THE REPOSITORY MADE THEM AGREE. The sim answers
		# with `machine_status` (ten words, guarded by check_status_reads) and the renderer draws from
		# `_machine_active`, a three-arm match whose default arm (`_held > 0 or progress > 0`) is a GUESS
		# about every behaviour added after it was written. A new machine kind that the sim calls working
		# and the default arm calls idle would ship dark and nothing would notice. It is asserted here, at
		# steady state, in both directions.
		if not bool(r["live_work"]):
			disagrees.append("%s (sim says working, renderer says idle)" % r["name"])
		if bool(r["live_stop"]):
			disagrees.append("%s (sim says %s, renderer says running)" % [r["name"], r["status"]])
		if bool(r["flash_work"]) != bool(r["live_work"]):
			lagged.append("%s (%s at the flip, %s once settled)"
				% [r["name"], "on" if r["flash_work"] else "off",
					"on" if r["live_work"] else "off"])
		print("    %-11s %8.1f %8.1f %8.1f %9.2f %9.2f %6.0f%% %6.0f%% %8s   %s"
			% [r["name"], _mean(flare), _mean(a1), _mean(i1), d_motion, d_state,
				flare_share * 100.0, share * 100.0, told, "reads" if ok else "DOES NOT READ"])
	if not lagged.is_empty():
		# REPORTED, NOT FAILED. A one-tick lag between "holds coal" and "is burning it" is 50ms of a
		# generator drawn cold, which no eye resolves, but it is exactly the shape a real desync would
		# take, so it is printed every run rather than smoothed away.
		print("    settling lag (not a failure): " + ", ".join(lagged))
	_check(absent.is_empty(),
		"CONTROL: every subject was actually drawn on the stage%s"
			% ("" if absent.is_empty() else " — NOT DRAWN: " + ", ".join(absent)))
	_check(disagrees.is_empty(),
		"the renderer's `_machine_active` and the sim's `machine_status` agree once both have settled%s"
			% ("" if disagrees.is_empty() else " — DISAGREE: " + ", ".join(disagrees)))
	_check(clipped.is_empty(),
		"no subject's working frame is clipped white, which would hide any cue it has%s"
			% ("" if clipped.is_empty() else " — SATURATED: " + ", ".join(clipped)))
	_check(blind.is_empty(), "every subject produced comparable patches%s"
		% ("" if blind.is_empty() else " — MISMATCHED: " + ", ".join(blind)))
	_check(weak.is_empty(),
		"every machine's HARDWARE says whether it is running, with labels hidden and in luma%s"
			% ("" if weak.is_empty() else " — SILENT: " + ", ".join(weak)))
