extends "res://tests/test_base.gd"

## `view/visuals/rock_tone.gd` — legacy's molded-rock shading (D0327, `docs/PORT_ORDER.md` V2).
##
## **THE ASSERTIONS HERE ARE ARITHMETIC, NOT PICTURES, AND THAT IS THE POINT.** Legacy shipped its seam
## direction inverted for the whole first life of the feature — `[3.00, 0.35]` for Bedded gave features
## 3.7 cells wide by 31.7 tall, vertical laminae in the material named for flat ones — under a comment
## asserting the opposite of what the arithmetic did. Its own note on why nothing caught it: *"No number
## the layer prints could see it, because ANISO is disqualified by its own null rig and was the one cue
## that could have registered a direction error."* The check it prescribes instead is
## `1 / (freq * multiplier)` per grammar, read against the sentence. That is `_test_the_seam_directions`.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_rock_tone.gd

const SEED: int = 20260826
const CELLS_PER_M: int = 4  ## MaterialLook.CELLS_PER_METRE -- asserted against it below, not trusted


func _initialize() -> void:
	_test_the_frequencies_port_unchanged_because_our_cell_is_legacys_fine_cell()
	_test_the_seam_directions_run_the_way_their_comments_say()
	_test_a_grammar_actually_changes_how_loud_the_rock_is()
	_test_no_grammar_table_is_silently_uniform()
	_test_no_stack_of_darkeners_punches_a_hole_in_the_rock()
	_test_the_shading_is_deterministic_in_the_seed_and_moves_with_it()
	_test_every_shipped_material_resolves_to_the_grammar_its_own_yaml_names()
	_finish("rock_tone")


## THE FINDING THIS WHOLE PORT RESTS ON, asserted in metres. Legacy renders on a fine grid of 8px cells
## against a 32px/1-metre coarse cell, so its fine cell is 1/4 metre; this build's terrain cell is 4px
## against 16px/metre, also 1/4 metre. The two grids are the same physical granularity, so legacy's
## frequency constants port UNCHANGED and its own feature-size comments must still hold here.
##
## If that claim is wrong, every constant in `rock_tone.gd` is off by a factor of four and the rock reads
## at the wrong scale — which is exactly the WG-4 trap (D0305), and it is invisible in a screenshot
## because wrong-scale noise still looks like noise.
func _test_the_frequencies_port_unchanged_because_our_cell_is_legacys_fine_cell() -> void:
	_check(MaterialLook.CELLS_PER_METRE == CELLS_PER_M,
		"this suite's cells-per-metre (%d) is the palette's own" % MaterialLook.CELLS_PER_METRE)
	# A cell is 1/4 metre here, and legacy's fine cell was 8px against a 32px metre -- also 1/4.
	_check(Interface.TERRAIN_CELL_PX * MaterialLook.CELLS_PER_METRE == 16,
		"16 world px per metre, so a 4px cell is a quarter of one -- legacy's fine cell exactly")
	# Legacy's own comments, in cells, checked against the frequencies that shipped.
	var rows: Array = [
		[RockTone.GRAIN_FREQ, 11.0, "grain: legacy calls it ~11 fine cells"],
		[RockTone.GRAIN_FREQ2, 9.0, "grain octave 2: legacy calls it ~9 fine cells"],
		[RockTone.PATCH_FREQ, 22.0, "broad patch: legacy calls it ~22 fine cells"],
		[RockTone.STONE_FREQ, 10.0, "stone blob: legacy calls it ~10 fine cells across"],
		[RockTone.HUE_FREQ, 36.0, "hue region: legacy calls it ~36 fine cells"],
	]
	var agreed: int = 0
	for r: Array in rows:
		var cells: float = 1.0 / float(r[0])
		if absf(cells - float(r[1])) < 1.0:
			agreed += 1
		else:
			_check(false, "%s -- got %.1f" % [r[2], cells])
	_check_over(rows.size(), agreed == rows.size(),
		"every frequency still produces the feature size legacy's own comment names -- %d of %d"
			% [agreed, rows.size()])
	# And the same sizes stated in METRES, which is the unit that has to survive a regime change.
	var grain_m: float = 1.0 / RockTone.GRAIN_FREQ / float(CELLS_PER_M)
	_check(absf(grain_m - 2.75) < 0.3,
		"the grain's feature is %.2f m here; at legacy's 8px fine cell it was 11 x 8px = 2.75 m" % grain_m)


## THE DIRECTION ERROR LEGACY SHIPPED, and the arithmetic check it prescribes. In
## `get_noise_2d(x * a, y * b)` a LARGE multiplier makes the field vary fast on that axis, so features are
## NARROW on it. Bedding is horizontally elongated, so it needs a SMALL x and a LARGE y.
##
## Stated as width-vs-height rather than as a multiplier comparison on purpose: the multipliers are the
## thing that is easy to read backwards, so an assertion phrased in multipliers would reproduce the bug.
func _test_the_seam_directions_run_the_way_their_comments_say() -> void:
	var clastic: Vector2 = RockTone.seam_feature_cells(RockTone.GRAM_CLASTIC)
	var bedded: Vector2 = RockTone.seam_feature_cells(RockTone.GRAM_BEDDED)
	var massive: Vector2 = RockTone.seam_feature_cells(RockTone.GRAM_MASSIVE)
	_check(absf(clastic.x - clastic.y) < 0.01,
		"CLASTIC is isotropic: %.1f x %.1f cells, no direction, because loose ground does not fracture "
			% [clastic.x, clastic.y] + "along planes")
	_check(bedded.x > bedded.y * 3.0,
		"BEDDED runs FLAT: %.1f cells wide by %.1f tall -- the material named for flat planes"
			% [bedded.x, bedded.y])
	_check(massive.y > massive.x * 3.0,
		"MASSIVE runs STEEP: %.1f wide by %.1f tall -- and its direction is the OPPOSITE of bedding's"
			% [massive.x, massive.y])
	# THE REGRESSION ITSELF: legacy's shipped-and-wrong pair. If someone swaps the tables back, bedded
	# would measure 3.7 x 31.7 and this row says so by name rather than by a picture looking odd.
	_check(not (bedded.x < bedded.y),
		"NOT legacy's inverted table: bedded is not %.1f wide by %.1f tall (vertical laminae)"
			% [bedded.x, bedded.y])


## A GRAMMAR HAS TO BE AUDIBLE, not merely present. Legacy's own diagnosis of the build before grammars:
## "every solid material in the world ran the identical noise at a different hue", so two materials "read
## as square variation before material" as a structural fact. Soil is granular (GRAM_GRAIN 1.60), stone is
## restrained (0.30) — so a run of clastic cells must vary measurably more than the same run of massive.
##
## Measured as mean |delta luma| between adjacent cells, which is a roughness, not a variance: a variance
## would also count the broad patch term and the two grammars would separate on the wrong signal.
func _test_a_grammar_actually_changes_how_loud_the_rock_is() -> void:
	var tone := RockTone.new(SEED)
	var base := Color(0.4, 0.38, 0.35)
	var rough: Dictionary = {}
	for gram: int in [RockTone.GRAM_CLASTIC, RockTone.GRAM_BEDDED, RockTone.GRAM_MASSIVE]:
		var total: float = 0.0
		var n: int = 0
		var prev: float = -1.0
		for col: int in range(200, 600):
			var c: Color = tone.shade(base, col, 300, gram)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if prev >= 0.0:
				total += absf(l - prev)
				n += 1
			prev = l
		rough[gram] = total / float(maxi(n, 1))
	_check_over(3, rough.size() == 3, "all three grammars produced a roughness reading")
	_check(rough[RockTone.GRAM_CLASTIC] > rough[RockTone.GRAM_MASSIVE] * 1.5,
		"CLASTIC is louder than MASSIVE: %.5f vs %.5f mean |dL| per cell -- soil is granular, stone is "
			% [rough[RockTone.GRAM_CLASTIC], rough[RockTone.GRAM_MASSIVE]] + "a quiet broad plane")
	# CONTROL: the flat fill this replaces has ZERO roughness, so the numbers above are the subject and
	# not an artefact of the measurement. Without this a shade() that returned `base` unchanged would give
	# 0.0 for every grammar and the ratio assertion above would be comparing nothing to nothing.
	var flat: float = 0.0
	var fprev: float = -1.0
	for col: int in range(200, 600):
		var l: float = 0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b
		if fprev >= 0.0:
			flat += absf(l - fprev)
		fprev = l
	_check(flat == 0.0 and rough[RockTone.GRAM_MASSIVE] > 0.0,
		"CONTROL: the un-toned flat fill measures %.5f roughness and even the quietest grammar measures "
			% flat + "%.5f, so the tone is doing the work" % rough[RockTone.GRAM_MASSIVE])


## EVERY GRAMMAR TABLE MUST ACTUALLY DIFFERENTIATE, one at a time.
##
## **THIS TEST EXISTS BECAUSE A MUTANT SURVIVED.** Flattening `GRAM_GRAIN` to `[1.00, 1.00, 1.00]` left
## `_test_a_grammar_actually_changes_how_loud_the_rock_is` green, because four other tables
## (`XSTR`, `CLUMP`, `SEAM`, `PATCH`) still differentiate and that test measures the ENSEMBLE. A grammar
## cue can therefore be silently switched off while the suite reports the grammar working — which is this
## repository's dominant failure class, an instrument that cannot register its subject, sitting inside the
## instrument written to catch it.
##
## The ensemble test above is still the right claim about the LOOK. This one names each table as its own
## subject, which no measurement over the rendered colour can do, because their effects are superimposed.
##
## Legacy's argument for why every one of them matters: the two ends are deliberately opposite in BOTH
## cues a viewer has — how loud the surface is, and which way it runs — and "a material told apart on only
## one of those is told apart by a knob rather than by a language."
func _test_no_grammar_table_is_silently_uniform() -> void:
	var tables: Array = [
		[RockTone.GRAM_GRAIN, "GRAM_GRAIN", "how loud the surface is"],
		[RockTone.GRAM_XSTR, "GRAM_XSTR", "which way the grain runs"],
		[RockTone.GRAM_CLUMP, "GRAM_CLUMP", "embedded aggregate: pebbles in soil, not in stone"],
		[RockTone.GRAM_SEAM, "GRAM_SEAM", "fracture seam strength"],
		[RockTone.GRAM_SEAM_X, "GRAM_SEAM_X", "seam direction, x"],
		[RockTone.GRAM_SEAM_Y, "GRAM_SEAM_Y", "seam direction, y"],
		[RockTone.GRAM_SEAM_W, "GRAM_SEAM_W", "seam band width"],
		[RockTone.GRAM_PATCH, "GRAM_PATCH", "broad mass before microtexture"],
	]
	var checked: int = 0
	var uniform: int = 0
	for row: Array in tables:
		var t: Array = row[0]
		checked += 1
		if t.size() != 3:
			_check(false, "%s has %d entries, one per grammar expected" % [row[1], t.size()])
			continue
		# CLASTIC and MASSIVE are the two ends legacy calls "deliberately opposite", so they are the pair
		# that must differ. Comparing min-to-max instead would pass on a table whose two ends agree and
		# whose middle is an outlier -- which is not a language, it is one odd material.
		if is_equal_approx(float(t[0]), float(t[2])):
			uniform += 1
			_check(false, "%s is uniform across the two opposite ends (%.2f vs %.2f) -- the cue '%s' is "
				% [row[1], t[0], t[2], row[2]] + "switched off while every rendered measurement still "
				+ "reports the grammar working")
	_check_over(checked, uniform == 0,
		"all %d grammar tables differentiate CLASTIC from MASSIVE -- %d were uniform" % [checked, uniform])


## ROCK IN SHADOW IS DARK ROCK, NEVER A HOLE. Several independent darkeners stack — grain, an embedded
## stone, a crack — and unfloored they could drive a cell past black, which prints as a PUNCTURE in an
## otherwise continuous face. Legacy: "the same wrong note as a blown highlight, at the other end."
##
## **SWEPT OVER THE REAL SHIPPED MATERIALS, not an invented dark colour.** The first version of this test
## used a hand-written `Color(0.10, 0.11, 0.13)` and called it "the darkest shipped rock"; the darkest
## material this build actually ships is coal at luma 0.160, and the invented value was darker than
## anything real. It still found a genuine defect — the additive drift carried channels NEGATIVE, 3,013 of
## 36,000 samples, worst luma -0.14, because the port had omitted the clamp legacy performs structurally
## at its byte write (`fine_terrain.gd:1105`). But a bound derived from an invented fixture is not a bound
## on anything shipped, which is why this now reads its population out of `MaterialsRecords`.
func _test_no_stack_of_darkeners_punches_a_hole_in_the_rock() -> void:
	var look := MaterialLook.new()
	var tone := RockTone.new(SEED)
	var tally: Dictionary = {"checked": 0, "out_of_gamut": 0, "clamped": 0, "materials": 0,
		"worst_frac": 0.0, "worst_id": ""}
	for id: String in MaterialsRecords.RECORDS:
		_sweep_material(tone, look, id, tally)
	var checked: int = int(tally["checked"])
	var out_of_gamut: int = int(tally["out_of_gamut"])
	var clamped_to_zero: int = int(tally["clamped"])
	var materials: int = int(tally["materials"])
	var worst_black_frac: float = float(tally["worst_frac"])
	var worst_id: String = String(tally["worst_id"])
	_check_over(checked, out_of_gamut == 0,
		"no channel over %d samples of %d real materials leaves [0,1] -- %d did"
			% [checked, materials, out_of_gamut])
	# MEASURED, not guessed. Coal is the darkest thing shipped (base luma 0.160) and reads 1.0-1.5% fully
	# black depending on the rows sampled; every other material reads 0.0%. Coal rendering black is coal,
	# not a defect, so the bound is set from that measurement with headroom rather than at zero -- a bound
	# at zero would be a bound on nothing, since it is already true of six of the seven materials.
	_check(worst_black_frac < 0.03,
		"the worst material (%s) is %.1f%% fully black, under the 3%% bound measured off coal's 1.0-1.5%%"
			% [worst_id, 100.0 * worst_black_frac])
	# CONTROL: the clamp actually FIRES. If it never did, `min` would sit above zero and the invariant
	# above would be true of an expression that never needed clamping -- a guard that cannot be observed
	# working is not a guard. This is the row that makes the one above a measurement.
	_check(clamped_to_zero > 0,
		"CONTROL: the clamp fired on %d channel(s), so the in-gamut result above is the clamp's doing and "
			% clamped_to_zero + "not a property the arithmetic had anyway")


## One material's sweep, accumulated into `tally`. Split out of the test above at QUALITY gate 4's 50-line
## limit; the seam is the right one, because everything here counts and everything there judges.
func _sweep_material(tone: RockTone, look: MaterialLook, id: String, tally: Dictionary) -> void:
	var rec: Dictionary = MaterialsRecords.RECORDS[id]
	if not rec.has("base_color"):
		return
	tally["materials"] = int(tally["materials"]) + 1
	var bc: Array = rec["base_color"]
	var base := Color(float(bc[0]), float(bc[1]), float(bc[2]))
	var gram: int = look.grammar_of(StringName(id))
	var black: int = 0
	var n: int = 0
	for col: int in range(0, 120):
		for row: int in range(150, 270):
			var c: Color = tone.shade(base, col, row, gram)
			tally["checked"] = int(tally["checked"]) + 1
			n += 1
			# THE CLAMP'S OWN INVARIANT, and the real defect the first run caught. A Color channel outside
			# [0,1] is not "dark", it is undefined, and the engine's behaviour on it is not something a
			# renderer should be relying on.
			if c.r < 0.0 or c.g < 0.0 or c.b < 0.0 or c.r > 1.0 or c.g > 1.0 or c.b > 1.0:
				tally["out_of_gamut"] = int(tally["out_of_gamut"]) + 1
			if c.r == 0.0 or c.g == 0.0 or c.b == 0.0:
				tally["clamped"] = int(tally["clamped"]) + 1
			if 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b <= 0.0:
				black += 1
	var frac: float = float(black) / float(maxi(n, 1))
	if frac > float(tally["worst_frac"]):
		tally["worst_frac"] = frac
		tally["worst_id"] = id


## Deterministic in the seed, and NOT constant across seeds. The second half is the one that matters: a
## `shade` that ignored its noise entirely would satisfy "same seed, same colour" perfectly.
func _test_the_shading_is_deterministic_in_the_seed_and_moves_with_it() -> void:
	var a := RockTone.new(SEED)
	var b := RockTone.new(SEED)
	var c := RockTone.new(SEED + 1)
	var base := Color(0.4, 0.38, 0.35)
	var same: int = 0
	var differ: int = 0
	var checked: int = 0
	for col: int in range(0, 120):
		var pa: Color = a.shade(base, col, 250, RockTone.GRAM_BEDDED)
		var pb: Color = b.shade(base, col, 250, RockTone.GRAM_BEDDED)
		var pc: Color = c.shade(base, col, 250, RockTone.GRAM_BEDDED)
		checked += 1
		if pa == pb:
			same += 1
		if pa != pc:
			differ += 1
	_check_over(checked, same == checked,
		"two RockTones on one seed paint identically -- %d of %d cells" % [same, checked])
	_check_over(checked, differ > checked / 2,
		"and a different seed paints a different world -- %d of %d cells differ" % [differ, checked])


## The `grammar:` field has been in `data/materials/*.yaml` since Slice 0 and was read by nothing until
## D0327. Assert the consumer resolves each shipped material to the grammar its OWN record names, and that
## the shipped set actually uses more than one — a language nothing speaks is not a language.
func _test_every_shipped_material_resolves_to_the_grammar_its_own_yaml_names() -> void:
	var look := MaterialLook.new()
	var want: Dictionary = {
		"clastic": RockTone.GRAM_CLASTIC,
		"bedded": RockTone.GRAM_BEDDED,
		"massive": RockTone.GRAM_MASSIVE,
	}
	var checked: int = 0
	var wrong: int = 0
	var distinct: Dictionary = {}
	for id: String in MaterialsRecords.RECORDS:
		var rec: Dictionary = MaterialsRecords.RECORDS[id]
		if not rec.has("grammar"):
			continue
		checked += 1
		var got: int = look.grammar_of(StringName(id))
		distinct[got] = true
		if got != want.get(String(rec["grammar"]), -1):
			wrong += 1
			_check(false, "%s declares grammar '%s' and resolved to %d" % [id, rec["grammar"], got])
	_check_over(checked, wrong == 0,
		"every one of the %d materials declaring a grammar resolves to it -- %d wrong" % [checked, wrong])
	_check(distinct.size() > 1,
		"and the shipped set uses %d distinct grammars, so the language is actually spoken"
			% distinct.size())
	# An unmapped material must not error, and must land on CLASTIC -- legacy's own silent default.
	_check(look.grammar_of(&"no_such_material") == RockTone.GRAM_CLASTIC,
		"an unknown material defaults to CLASTIC rather than erroring, as legacy's unset grammar_at does")
