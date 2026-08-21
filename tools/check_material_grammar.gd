extends "res://tools/check_base.gd"

## DIRT AND STONE HAVE TO BE DIFFERENT MATERIALS, NOT ONE MATERIAL IN TWO COLOURS.
##
## TR-02: *"Stop using equal-frequency noise for dirt and stone — both read as square variation before
## material."* TR-04: *"Establish stone as plane/fracture rather than speckle."* Completion for both is
## *"an independent reviewer names each material without UI"*.
##
## THE TRAP THIS LAYER EXISTS TO AVOID. Earth is brown (0.34, 0.24, 0.155) and stone is grey
## (0.355, 0.350, 0.335), so ANY separability test that can see colour scores near-perfect and closes
## TR-02 while the thing the ticket is about goes untouched. A hue difference is not a material grammar;
## a player told "the brown one is dirt" has learned a colour key, not read a material. So the verdict
## here is computed on STRUCTURE ONLY, and the colour cues are kept, as a CONTROL that must stay high,
## because if colour separability collapses too then the rig is broken rather than the grammar being good.
##
## AND THE SECOND TRAP, which is the same one in the other direction. The fine layer applies grain
## MULTIPLICATIVELY on the material's own colour (`col.r * vmul`, scenes/fine_terrain.gd), so a brighter
## material carries a larger ABSOLUTE grain deviation for free. Reading raw standard deviation would
## therefore separate stone from earth on brightness while printing the word GRAIN over it. The grain cue
## is a COEFFICIENT OF VARIATION, std/mean, which is invariant to that scaling. Anisotropy is already a
## normalised ratio of gradient energies.
##
## THE RIG IS SYMMETRIC AND HAS A NULL. A corridor is carved at a fixed depth with one material filled to
## its left and another to its right, mirrored about the player, so both sides sit at matched distances
## from the lamp and receive matched AO and rim from matched geometry. Then the whole measurement is run
## a second time with THE SAME MATERIAL ON BOTH SIDES. If the null rig separates, the instrument is
## reading position or lighting rather than material, and every number in the treatment run is void.
##
## Deliberately NOT registered while TR-02 is open; `check_rock_reads` was held out the same way through
## 6a. A layer that is red on arrival is not a gate, it is a ticket with a runner attached.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 70

## THREE INDEPENDENT PLACEMENTS, POOLED. One rig yields 28 mirrored pairs and the floor is 30, and the two
## ways of manufacturing more are both dishonest: moving the player would multiply the standings but the
## mirror axis is the material SEAM, not the body, so pairs would stop being matched on lamp distance; and
## halving the stride would overlap windows that are two cells tall, inflating n with samples that are not
## independent. Rebuilding the rig at three depths gives genuinely separate rock and keeps the player
## centred on the seam each time.
const DEPTHS: Array[int] = [22, 26, 30]
const HALF_W: int = 20         ## corridor half-width in cells
## SHALLOW ON PURPOSE. Torch light reaches a few cells into rock, so a slab ten rows deep puts most of its
## windows where nothing is visible: the first lit rig lit 12 of 48. The sampled band is now the rock a
## torch actually reaches, which is also the only rock a player ever sees the material of.
const HALF_H: int = 8          ## slab half-height in cells
const STRIDE: int = 2          ## cells between window centres — windows overlap less than they tile
const GAP: int = 3             ## columns either side of the seam left unsampled (contacts are not interiors)
const CORRIDOR: int = 1        ## rows carved out either side of centre
## THE RIG HAS TO BE LIT, and the first version was not. With only the player's lamp, 7 of 48 windows were
## bright enough to see a material in, and the NULL rig duly "separated" at 83% on six of them, which is
## five windows out of six and is noise wearing a percentage. TR-02 is answered where a player can see, so
## the corridor carries a line of torches and the lit band becomes the population rather than a remainder.
const TORCH_EVERY: int = 2     ## columns between torches along the corridor

## THE WINDOW HAS TO BE THE SIZE OF THE THING IT IS LOOKING FOR, and the first version of this layer was
## not. It sampled 0.30 of a cell (15 screen pixels) while `fine_terrain.gd` says in its own constants
## that a grain feature spans ABOUT ELEVEN FINE CELLS. SUBDIV is 4, so a fine cell is 12 screen px and a
## feature is ~132; the patch covered 1.25 fine cells. A window that small cannot see a texture at all,
## only the inside of one of its pixels, and it duly reported that a 2.9x difference in grain amplitude
## was worth four points of separability.
##
## Two cells across (~96 px, ~8 fine cells) sits under the feature scale and above the pixel scale. It is
## deliberately NOT larger: the broad tonal patch field runs at ~22 fine cells and is global, so a window
## wide enough to average that in would dilute the material's own signal with the world's.
## THE WINDOW IS WIDE AND SHALLOW BECAUSE THE VISIBLE REGION IS. Torchlight reaches about two cells into
## a rock face, so the only rock whose material a player ever sees is a thin skin behind whatever they
## have just dug, while a grain feature spans ~11 fine cells, which is 2.75 coarse cells. **The texture's
## features are larger than the band in which they can be seen**, and that is a finding about the grammar's
## scale rather than about the rig: a square window big enough to contain a feature necessarily reaches
## into rock nobody can see, which is how the first lit band ended up at 11 of 32 windows.
##
## So the window is 4 cells across and 2 deep: wide enough horizontally to contain a feature, shallow
## enough vertically to stay inside the lit skin. Matching the sampling shape to the shape of the region
## the question is about, rather than to the shape of the thing being measured.
const WIN_W: float = 4.0       ## window width in coarse cells — spans a grain feature
const WIN_H: float = 2.0       ## window height in coarse cells — stays inside the torch-lit skin
const MIN_SAMPLES: int = 30    ## a ratio over a handful of windows is not a small result, it is no result
## Every Nth pixel, both axes. The window is 193px across and the finest thing in it is a 12px fine cell,
## so a 3px lattice is still four samples per fine cell, nowhere near the structure being measured. The
## first version walked every pixel with `get_pixel`, three separate times per window, which came to ~32
## million calls and took the layer past a ten-minute wall. One fused pass over `get_data()` bytes at
## stride 3 is the same four numbers about 30x faster.
const STEP: int = 3
## A WINDOW IS "LIT" WHEN A PLAYER COULD ACTUALLY SEE IT. The first version of this layer sampled the
## whole slab and reported 64% separability on rock whose mean luma is 10/255; a 4x crop of it is
## visually BLACK. That number is real and it is about nothing: no variation language reads at 4%
## brightness, at any amplitude, so a texture statistic taken there cannot answer TR-02's completion
## criterion ("an independent reviewer names each material"). The lit band is where the claim lives; the
## dark band is reported beside it because "they cannot be told apart out here" is itself the finding, and
## it is a BRIGHTNESS finding rather than a texture one.
const LIT_FLOOR: float = 22.0  ## mean window luma above which rock is actually visible
const READ_FLOOR: float = 0.75 ## the same bar check_rock_reads holds rock/void to
const NULL_CEILING: float = 0.62  ## the null rig may not separate by more than this on structure

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_material_grammar: SKIP — needs a real surface to photograph")
		quit(42)
		return
	MainView.dev_start = false
	await _run()


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame

	print("== dirt and stone have to be different materials, not one material in two colours ==")

	# THE NULL FIRST, and deliberately so. Running it after the treatment invites reading it as a
	# post-hoc excuse for a number already in hand; running it first makes it a precondition.
	var null_r: Dictionary = await _measure(main, &"earth", &"earth", "NULL   earth | earth", true)
	var real_r: Dictionary = await _measure(main, &"earth", &"stone", "TREAT  earth | stone", true)

	# THE SAME MEASUREMENT WITH THE TOOTH PASS OFF, and it is not a curiosity: it is the mechanism
	# question. `rock_tooth.gdshader` adds texture ABOVE the darkness veil in ABSOLUTE levels, because 6a
	# established that anything the fine layer writes underground is multiplied by the veil down to
	# nothing. That fix worked and it is why rock reads against void at all. But the tooth is ISOTROPIC and
	# material-blind by construction: it masks on alpha and adds the same hash to every solid cell in the
	# world. So underground it is plausibly the dominant surface texture, in which case a material grammar
	# written into the fine layer is being crushed by the veil AND overpainted by the fix for the veil.
	# If structure separation jumps with the tooth off, that is the answer, and it means the grammar has to
	# reach the frame the way the tooth does rather than the way the fine layer does.
	# THE PAIRED BASELINE, and without it the headline is a category error. The 57% recorded before the
	# grammar existed was a POOLED number, and pairing alone lifts a cue several points by removing the
	# lighting spread, so quoting today's paired figure against that pooled one would credit the grammar
	# with the statistic's improvement. This arm is the same two materials with the SAME language: stone's
	# MaterialDef is flattened to Clastic, so the slabs still differ in colour and no longer differ in
	# grammar. Whatever separates here is what separated before any of this work.
	var stone_def: MaterialDef = main._renderer._material(&"stone")
	var keep: int = stone_def.grammar
	stone_def.grammar = 0
	var flat: Dictionary = await _measure(main, &"earth", &"stone", "BASE   earth | stone, ONE GRAMMAR", true)
	stone_def.grammar = keep

	var tooth: CanvasItem = main._renderer._tooth
	var real_nt: Dictionary = {}
	if tooth != null:
		tooth.visible = false
		real_nt = await _measure(main, &"earth", &"stone", "TREAT  earth | stone, TOOTH OFF", false)
		tooth.visible = true

	# A CUE IS DISQUALIFIED BY ITS OWN NULL, per cue rather than in aggregate. The null rig holds the SAME
	# material on both sides, so any separation it shows is the instrument reading position, lighting or
	# geometry, and a cue that separates identical rock cannot be trusted to be reading material when the
	# rock differs. Pooled over three placements the two structure cues come apart sharply: GRAIN reads 51%
	# on the null, ANISO reads 73%. So ANISO is not a material cue in this rig and is excluded from the
	# verdict by rule rather than by picking a preferred number. It is still printed, because "the attempt
	# to read direction failed" is a finding about the seams, not an absence of one.
	#
	# ANISO's failure is also informative rather than merely inconvenient: the treatment's own anisotropy
	# reads 50-51%, so the per-grammar seam DIRECTION (bedded running flat, massive running steep) is not
	# reaching the frame at all. The seams are drawn multiplicatively, which is the constraint written at
	# the head of fine_terrain.gd, and direction is the half of the grammar that constraint costs most.
	var cues: Array[String] = ["grain", "aniso"]
	var usable: Array[String] = []
	for cue: String in cues:
		var nv: float = float(null_r[cue + "_lit"])
		if nv <= NULL_CEILING:
			usable.append(cue)
		else:
			print("  DISQUALIFIED: %s separates the NULL rig at %.0f%% (ceiling %.0f%%) — it is reading"
				% [cue.to_upper(), nv * 100.0, NULL_CEILING * 100.0]
				+ " something other than material, so it cannot carry a verdict about material")
	_check(not usable.is_empty(),
		"at least one structure cue survived its own null rig (%d of %d)" % [usable.size(), cues.size()])
	if usable.is_empty():
		main.queue_free()
		await physics_frame
		_verdict("check_material_grammar")
		return

	var col_auc: float = maxf(float(real_r["value_lit"]), float(real_r["chroma_lit"]))
	_check(col_auc >= READ_FLOOR,
		"CONTROL: the two slabs really are different materials — colour tells them apart %.0f%% of the"
			% (col_auc * 100.0) + " time. If this ever falls the rig broke, not the grammar")

	# THE VERDICT IS THE LIT BAND. A separability taken on rock at 4% brightness is a true statement about
	# pixels and a false one about play; see LIT_FLOOR.
	var struct_auc: float = 0.0
	for cue: String in usable:
		struct_auc = maxf(struct_auc, float(real_r[cue + "_lit"]))
	_check(int(real_r["n_lit"]) >= MIN_SAMPLES,
		"%d of the sampled windows are bright enough for a material to be visible in (floor %d)"
			% [int(real_r["n_lit"]), MIN_SAMPLES])
	_check(struct_auc >= READ_FLOOR,
		# TWO DECIMALS, because %.0f prints a near miss and its own floor as the SAME NUMBER. This line
		# read "75% of the time (floor 75%)" against a `>=` comparison, which looks like a broken
		# assertion rather than a value fractions of a point under the bar, and a reader cannot tell
		# which from the text. Identical defect to the one already fixed in check_texture.
		"STRUCTURE, colour removed: dirt and stone are tellable apart %.2f%% of the time (floor %.2f%%,"
			% [struct_auc * 100.0, READ_FLOOR * 100.0]
			+ " a coin is 50%) — this is TR-02's actual subject")

	print("  BASELINE: with one grammar for both materials, structure reads %.0f%% in the lit band;"
		% (_best(flat, usable) * 100.0)
		+ " with the grammar it reads %.0f%%. Both paired, both lit — the comparison the ticket wants."
		% (struct_auc * 100.0))
	if not real_nt.is_empty():
		var nt: float = maxf(float(real_nt["grain_auc"]), float(real_nt["aniso_auc"]))
		print("  MECHANISM: structure reads %.0f%% with the tooth on and %.0f%% with it off — a large gap"
			% [struct_auc * 100.0, nt * 100.0]
			+ " here means the material grammar is being overpainted by an isotropic pass, not that it is"
			+ " absent from the bake")

	main.queue_free()
	await physics_frame
	_verdict("check_material_grammar",
		"structure %.0f%%, colour %.0f%%, null %.0f%%"
			% [struct_auc * 100.0, col_auc * 100.0, _best(null_r, usable) * 100.0])


## Build the cross-section, photograph it, and return every cue's separability.
func _measure(main: MainView, left: StringName, right: StringName, label: String,
		_tooth_on: bool) -> Dictionary:
	var pooled: Dictionary = {"l_value": [] as Array[float], "r_value": [] as Array[float],
		"l_chroma": [] as Array[float], "r_chroma": [] as Array[float],
		"l_grain": [] as Array[float], "r_grain": [] as Array[float],
		"l_aniso": [] as Array[float], "r_aniso": [] as Array[float]}
	for depth: int in DEPTHS:
		var one: Dictionary = await _sample_at(main, left, right, depth)
		for k: String in pooled:
			(pooled[k] as Array[float]).append_array(one[k] as Array[float])
	return _report(pooled, label)


func _sample_at(main: MainView, left: StringName, right: StringName, depth: int) -> Dictionary:
	var sim: FactorySim = main.sim
	var p: Player = main._player
	var home: Vector2i = main._cell_at(p.position)
	var cy: int = sim.surface_row(home.x) + depth
	var cx: int = home.x

	# Fill the slab. GAP columns astride the seam are filled but never sampled: a contact is a different
	# subject with its own layer (check_contact_edge), and letting one leak in here would let an edge
	# treatment answer a question about interiors.
	for dy: int in range(-HALF_H, HALF_H + 1):
		for dx: int in range(-HALF_W, HALF_W + 1):
			sim.set_solid(Vector2i(cx + dx, cy + dy), left if dx < 0 else right)
	# Carve the corridor so the slab faces are seen, lit and rimmed; symmetric, so both sides get the
	# same geometry and therefore the same AO and rim.
	for dy: int in range(-CORRIDOR, CORRIDOR + 1):
		for dx: int in range(-HALF_W, HALF_W + 1):
			sim.mine(Vector2i(cx + dx, cy + dy))
	sim.inventory[&"torch"] = 999
	for dx: int in range(-HALF_W + 1, HALF_W, TORCH_EVERY):
		sim.place_torch(Vector2i(cx + dx, cy))
	p.place(main._cell_center(Vector2i(cx, cy)))
	p.velocity = Vector2.ZERO
	# POSE THE POINTER, AND POSE IT ON THE BODY, because this layer compares a LEFT half against a RIGHT
	# half and the head-lamp is aimed. `Controls.pointer_world` falls through to the real
	# `get_mouse_position()` unless a fixture poses it; `_aim` is built from that, and the lamp's veil cut
	# rides an offset easing toward `_aim`. So an unposed run lights one side of the seam more than the
	# other by an amount set by where a hand was left on the desk — a DIRECTIONAL bias on a directional
	# comparison, not merely noise on it. Nine other fixtures under `tools/` already pose the pointer.
	#
	# On the body specifically, because that is the pose that makes the lamp symmetric about the seam. Any
	# other fixed point would be reproducible and still tilted, which is a quieter version of the same
	# fault.
	Controls.pose_pointer(p.position)
	main._renderer.repaint_world()
	for _i: int in 40:
		await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img: Image = get_root().get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = img.get_data()
	var iw: int = img.get_width()
	var to_px: Transform2D = main.get_viewport().get_final_transform() \
		* main.get_viewport().get_canvas_transform()
	var cell_px: float = to_px.basis_xform(Vector2(float(WorldRenderer.CELL), 0.0)).length()
	var rx: int = int(cell_px * WIN_W * 0.5)
	var ry: int = int(cell_px * WIN_H * 0.5)

	var out: Dictionary = {"l_value": [] as Array[float], "r_value": [] as Array[float],
		"l_chroma": [] as Array[float], "r_chroma": [] as Array[float],
		"l_grain": [] as Array[float], "r_grain": [] as Array[float],
		"l_aniso": [] as Array[float], "r_aniso": [] as Array[float]}

	# MIRRORED SAMPLING. Every cell is taken with its mirror twin at the same |dx| and the same dy, so the
	# two populations are matched on distance from the lamp and on depth. An unmatched sample would let a
	# lighting gradient masquerade as a material difference, which is precisely what the null rig would
	# then fail to catch: the null and the mirroring guard the same hole from two sides.
	var half_x: int = int(ceil(WIN_W * 0.5))
	var half_y: int = int(ceil(WIN_H * 0.5))
	for dy: int in range(-HALF_H, HALF_H + 1, STRIDE):
		# The corridor, its rim band, AND a window radius clear of both: a window centred one cell from
		# the corridor still reaches into it, and carved-edge AO is not a material property.
		if absi(dy) <= CORRIDOR + half_y:
			continue
		if absi(dy) + half_y > HALF_H:
			continue
		for dx: int in range(GAP + half_x, HALF_W + 1 - half_x, STRIDE):
			var lc := Vector2i(cx - dx, cy + dy)
			var rc := Vector2i(cx + dx, cy + dy)
			if not _solid_around(sim, lc, half_x, half_y) or not _solid_around(sim, rc, half_x, half_y):
				continue
			var lp: Vector2 = to_px * main._cell_center(lc)
			var rp: Vector2 = to_px * main._cell_center(rc)
			if not _inside(img, lp, rx, ry) or not _inside(img, rp, rx, ry):
				continue
			_take(out, "l", data, iw, int(lp.x), int(lp.y), rx, ry)
			_take(out, "r", data, iw, int(rp.x), int(rp.y), rx, ry)

	return out


## Pool, then judge. Nothing above this line looks at a cue; nothing below it knows about geometry.
func _report(out: Dictionary, label: String) -> Dictionary:
	var lv: Array[float] = out["l_value"]
	var n: int = lv.size()
	print("  %s — %d mirrored windows pooled over %d placements, %.0fx%.0f cells"
		% [label, n, DEPTHS.size(), WIN_W, WIN_H])
	_check(n >= MIN_SAMPLES,
		"  %s found %d pairs to judge (floor %d)" % [label, n, MIN_SAMPLES])

	# PAIRED, NOT POOLED, and the first version threw the whole point of the rig away. Every window is
	# sampled with its MIRROR TWIN at the same |dx| and the same dy, so the two are matched on distance
	# from the lamp and on depth, and then the pooled Mann-Whitney compared two unordered bags and let
	# all that matching evaporate. Lighting varies far more across the slab than material does, so the
	# within-material spread it re-introduced was swamping the between-material difference the rig was
	# built to isolate. A paired comparison asks the only question the design supports: for THIS pair of
	# matched windows, is the left one different from the right one.
	var res: Dictionary = {}
	var lv2: Array[float] = out["l_value"]
	var rv2: Array[float] = out["r_value"]
	var lit_idx: Array[int] = []
	var dark_idx: Array[int] = []
	for i: int in lv2.size():
		if (lv2[i] + rv2[i]) * 0.5 >= LIT_FLOOR:
			lit_idx.append(i)
		else:
			dark_idx.append(i)
	print("    %d windows lit (mean luma >= %.0f), %d dark — median luma lit %.1f, dark %.1f"
		% [lit_idx.size(), LIT_FLOOR, dark_idx.size(),
		_median(_pick(lv2, lit_idx)), _median(_pick(lv2, dark_idx))])
	for cue: String in ["value", "chroma", "grain", "aniso"]:
		var a: Array[float] = out["l_" + cue]
		var b: Array[float] = out["r_" + cue]
		res[cue + "_auc"] = _paired(a, b)
		res[cue + "_lit"] = _paired(_pick(a, lit_idx), _pick(b, lit_idx))
		res[cue + "_dark"] = _paired(_pick(a, dark_idx), _pick(b, dark_idx))
		print("    %-6s left med %+8.3f  right med %+8.3f  ->  all %3.0f%%   LIT %3.0f%%   dark %3.0f%%"
			% [cue.to_upper(), _median(a), _median(b), float(res[cue + "_auc"]) * 100.0,
			float(res[cue + "_lit"]) * 100.0, float(res[cue + "_dark"]) * 100.0])
	res["n_lit"] = lit_idx.size()
	return res


## Every coarse cell the window covers must be solid, or the window is measuring air and rim as if they
## were the material's own texture.
func _solid_around(sim: FactorySim, c: Vector2i, hx: int, hy: int) -> bool:
	for y: int in range(c.y - hy, c.y + hy + 1):
		for x: int in range(c.x - hx, c.x + hx + 1):
			if not sim.is_solid(Vector2i(x, y)):
				return false
	return true


func _inside(img: Image, p: Vector2, rx: int, ry: int) -> bool:
	var s: Vector2i = img.get_size()
	return p.x > float(rx + STEP + 1) and p.y > float(ry + STEP + 1) \
		and p.x < float(s.x - rx - STEP - 2) and p.y < float(s.y - ry - STEP - 2)


func _take(out: Dictionary, side: String, d: PackedByteArray, w: int, x: int, y: int,
		rx: int, ry: int) -> void:
	var m: Dictionary = _window(d, w, x, y, rx, ry)
	(out[side + "_value"] as Array[float]).append(float(m["mean"]))
	(out[side + "_chroma"] as Array[float]).append(float(m["chroma"]))
	# COEFFICIENT OF VARIATION, not standard deviation; see the header. Multiplicative grain makes raw
	# std track brightness, so a raw-std "grain" cue would be the VALUE cue with a different label.
	(out[side + "_grain"] as Array[float]).append(float(m["std"]) / maxf(float(m["mean"]), 1.0))
	(out[side + "_aniso"] as Array[float]).append(float(m["aniso"]))


## All four descriptors in ONE walk of the window. Kept fused rather than split into readable helpers
## because three separate walks is what put this layer over a ten-minute timeout; the cost is real and the
## arithmetic is not complicated enough to need the separation.
func _window(d: PackedByteArray, w: int, cx: int, cy: int, rx: int, ry: int) -> Dictionary:
	var n: int = 0
	var sum: float = 0.0
	var sum2: float = 0.0
	var chroma: float = 0.0
	var gh: float = 0.0
	var gv: float = 0.0
	for y: int in range(cy - ry, cy + ry + 1, STEP):
		var row: int = y * w
		for x: int in range(cx - rx, cx + rx + 1, STEP):
			var i: int = (row + x) * 4
			var rr: float = float(d[i])
			var bb: float = float(d[i + 2])
			var l: float = rr * 0.299 + float(d[i + 1]) * 0.587 + bb * 0.114
			sum += l
			sum2 += l * l
			chroma += bb - rr
			n += 1
			var ix: int = (row + x + STEP) * 4
			gh += absf(float(d[ix]) * 0.299 + float(d[ix + 1]) * 0.587 + float(d[ix + 2]) * 0.114 - l)
			var iy: int = ((y + STEP) * w + x) * 4
			gv += absf(float(d[iy]) * 0.299 + float(d[iy + 1]) * 0.587 + float(d[iy + 2]) * 0.114 - l)
	if n == 0:
		return {"mean": 0.0, "std": 0.0, "chroma": 0.0, "aniso": 0.0}
	var mean: float = sum / float(n)
	return {"mean": mean, "std": sqrt(maxf(sum2 / float(n) - mean * mean, 0.0)),
		"chroma": chroma / float(n),
		"aniso": ((gv - gh) / (gv + gh)) if gh + gv > 0.0 else 0.0}


## The matched-pair statistic: over mirrored windows, how often the two sides differ in the SAME direction.
## Folded for the same reason the pooled version is: which way round the cue runs is not something a
## player has to be told, only that the two materials are not the same picture.
func _paired(a: Array[float], b: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var wins: float = 0.0
	for i: int in a.size():
		if a[i] > b[i]:
			wins += 1.0
		elif a[i] == b[i]:
			wins += 0.5
	var f: float = wins / float(a.size())
	return maxf(f, 1.0 - f)


## The best surviving cue's lit-band reading, used for the baseline arm so it is scored on exactly the
## cues the treatment is scored on.
func _best(d: Dictionary, cues: Array[String]) -> float:
	var out: float = 0.0
	for cue: String in cues:
		out = maxf(out, float(d[cue + "_lit"]))
	return out


func _pick(v: Array[float], idx: Array[int]) -> Array[float]:
	var out: Array[float] = []
	for i: int in idx:
		out.append(v[i])
	return out


## Mann-Whitney, folded; the same statistic and the same reasoning as check_rock_reads: distribution-free
## because a bimodal population (bedding against fissure) should not be punished for its shape, and folded
## because which way round the cue runs is not something a player needs to be told.
func _readability(a: Array[float], b: Array[float]) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var wins: float = 0.0
	for x: float in a:
		for y: float in b:
			if x > y:
				wins += 1.0
			elif x == y:
				wins += 0.5
	var auc: float = wins / float(a.size() * b.size())
	return maxf(auc, 1.0 - auc)


func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s: Array[float] = a.duplicate()
	s.sort()
	return s[s.size() / 2]
