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

	if not unplaceable.is_empty():
		print("    could not place: " + ", ".join(unplaceable))
	_check(subjects.size() >= 10,
		"%d machines stood on the stage — fewer than ten is not a registry" % subjects.size())
	_report(subjects)

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


func _report(subjects: Array[Dictionary]) -> void:
	print("    %-16s %9s" % ["machine", "cell used"])
	for s: Dictionary in subjects:
		print("    %-16s %8.0f%%" % [s["name"], float(s["cover"]) * 100.0])

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
				below.append("%s (%.3f)" % [label, d])
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
		"every pair of machines of DIFFERENT kinds disagrees about at least %.1f%% of the cell%s"
			% [SHAPE_FLOOR * 100.0,
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


## The LARGEST single-pixel difference between two captures, not the mean. A mean over 2352 pixels hides a
## handful of moving ones, and it is exactly a handful of moving pixels that a mask threshold has to
## survive.
## How many pixels of an unchanging cell move further than `level` between two captures. The population is
## pixels and the answer is a count, so it can be turned into a share of the cell and compared with the
## floor the shape assertion uses, which a maximum in luma levels never could be.
func _count_over(a: PackedFloat32Array, b: PackedFloat32Array, level: float) -> int:
	var n: int = 0
	for i: int in mini(a.size(), b.size()):
		if absf(a[i] - b[i]) > level:
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
