extends "res://tools/check_base.gd"

## THE BAZAAR CACHE MUST AGREE WITH THE WORLD AFTER EVERY WAY THE WORLD CAN CHANGE.
##
## `find_bazaars()` and `find_bazaar_ruins()` are served from a cache that a full-grid rescan refills when
## `_bazaars_dirty` is set. Every write to `solid` is therefore load-bearing twice: once for the world, and
## once for the flag. A write that forgets the flag does not fail, crash or slow anything down — it makes
## the game answer a question about a structure that is not there any more.
##
## THE DEFECT THIS WAS WRITTEN FOR WAS LIVE IN SHIPPING CODE, AND REACHABLE THROUGH AN ORDINARY VERB.
## `Flora.grow` stamps a tree trunk straight into `sim.solid` and set no flag. Plant a sapling in your
## bazaar's open interior — nothing stops you, `can_plant_sapling` asks only for empty ground on soil —
## and two minutes later the trunk closes the interior. `is_bazaar_at` answers false; `find_bazaars()` went
## on returning the origin. The stall stays drawn, the near-bazaar craft gate stays open, and the game
## corrects itself only when some unrelated dig happens to invalidate the cache. The mirror is worse: a
## trunk growing into a ruin's one missing cell COMPLETES a bazaar nobody has been told about.
##
## SO THE ASSERTION IS BEHAVIOURAL AND NOT A SOURCE SCAN. A gate that greps for `_bazaars_dirty` beside
## every `solid[` write would have missed this one anyway — the write is in another file, through a
## reference the grep would have to know to follow — and it would pass a write that sets the flag in a
## branch that is not taken. What is checked here is the only thing that matters: after each way the world
## changes, does the cached answer equal a scan of the world as it now is.
##
## THE CONTROL IS BRUTE FORCE AND IT TRAVELS INSIDE EVERY CASE. `_truth()` walks the whole grid calling
## `is_bazaar_at` and `bazaar_gap_at`, ignoring the cache entirely, and every case compares against it. If
## the two agreed because both were empty the case would prove nothing, so each one also asserts what it
## expects the world to hold — a case that measures nothing is the house defect, not a passing case.
##
##   godot --headless --script res://tools/check_bazaar_cache.gd

const Flora := preload("res://src/core/flora.gd")

## Somewhere with room around it, well away from the grid edges so a 4x4 window and a canopy both fit.
const AT := Vector2i(40, 40)

## The two triple-quote spellings, as constants: a literal `"""` inside the function that skips `"""`
## blocks is a hall of mirrors for the next reader.
const TRIPLE_D: String = '"""'
const TRIPLE_S: String = "'''"

## THE FILES ALLOWED TO WRITE THE COARSE `solid` GRID, and this list is a ratchet rather than a note.
##
## The behavioural cases below cover the ways the world changes THAT SOMEBODY THOUGHT OF. `Flora.grow`
## was not one of them for as long as it existed, and the reason is worth keeping: it lives in another
## file and reaches the grid through a preloaded reference, so nothing about `factory_sim.gd` suggested
## that a second file was mutating the thing its cache describes. A new writer arriving the same way would
## be just as quiet.
##
## So the population is asserted too. A file that writes `solid` and is not named here turns this layer
## red, and clearing that red means adding a case below rather than adding a name up here.
const SOLID_WRITERS: Array[String] = ["res://src/core/factory_sim.gd", "res://src/core/flora.gd"]

## Where a writer could live. Not `res://` whole: `tools/` and `tests/` write `solid` constantly, by
## design, to build fixtures, and they are not shipping paths.
const WRITER_ROOTS: Array[String] = ["res://src/", "res://scenes/"]

## A write to the COARSE grid. `_fine_solid` is a different grid with a different owner and no bazaar in
## it, and the leading character class is what keeps this from matching it.
const SOLID_WRITE: String = "(^|[^_A-Za-z])solid(\\[[^\\]]*\\]\\s*=[^=]|\\.erase\\()"

## The positive control for that pattern, and its two near misses.
const WRITE_YES: String = "\tsim.solid[t] = &\"wood\"\n"
const WRITE_FINE: String = "\t_fine_solid[fy * _fcols + fx] = 1\n"
const WRITE_READ: String = "\tif sim.solid[key] == &\"leaves\":\n"


func _initialize() -> void:
	_grows_into_a_bazaar()
	_grows_inside_a_bazaar()
	_mined()
	_placed()
	_set_solid()
	_loaded()
	_writers()
	_verdict("check_bazaar_cache",
		"the cached answer matches a full scan after growth, mining, placing, set_solid and a world load")


## THE MIRROR OF THE SHIPPED DEFECT, AND THE MORE DANGEROUS DIRECTION. A ruin one wood short, with a
## sapling in the gap. The trunk fills it and the frame becomes a bazaar; before the fix the cache said
## there were none.
func _grows_into_a_bazaar() -> void:
	var sim: FactorySim = _ruin(AT, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	# The gap's own floor, so the sapling has soil under it. Outside the interior, so the frame is
	# unaffected by it.
	sim.solid[AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H)] = &"earth"
	_check(_truth(sim)["bazaars"].is_empty(), "the fixture starts as a ruin and not as a bazaar")
	_check(sim.find_bazaars().is_empty(), "...and the cache agrees before anything grows")
	_plant_and_grow(sim, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	_agrees(sim, "a tree grew into the ruin's missing cell")
	_check(not _truth(sim)["bazaars"].is_empty(),
		"...and the case is live: the frame really did complete (%d bazaar(s))" % _truth(sim)["bazaars"].size())


## THE SHIPPED DEFECT ITSELF. A whole bazaar, a sapling in its open interior, and the trunk that closes it.
func _grows_inside_a_bazaar() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar, and the cache is warm on it")
	_plant_and_grow(sim, AT + Vector2i(1, FactorySim.BAZAAR_H - 1))
	_agrees(sim, "a tree grew inside the frame and closed its interior")
	_check(_truth(sim)["bazaars"].is_empty(),
		"...and the case is live: the frame really did stop being a bazaar")


func _mined() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar (mining case)")
	sim.mine(AT, false)                                    # a top-beam corner: the frame breaks
	_agrees(sim, "a frame cell was mined out")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: mining really did break it")


func _placed() -> void:
	var sim: FactorySim = _ruin(AT, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	_check(sim.find_bazaars().is_empty(), "the fixture starts as a ruin (placing case)")
	sim.inventory[&"wood"] = 1
	var gap: Vector2i = AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1)
	_check(sim.place_block(gap, &"wood"), "the missing post can be placed")
	_agrees(sim, "the missing post was placed")
	_check(not _truth(sim)["bazaars"].is_empty(), "...and the case is live: placing really did complete it")


func _set_solid() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar (set_solid case)")
	sim.set_solid(AT + Vector2i(1, 1), &"stone")           # rock in the interior: no longer open
	_agrees(sim, "set_solid filled the interior")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: the interior really did close")


## A LOAD IS A BULK WRITE AND IT USED TO LEAVE THE FLAG TO ITS CALLER. `main.gd` got away with that by
## loading into a fresh sim, whose flag starts dirty, so the miss was invisible from the only path anybody
## exercised. This loads into a sim whose cache is ALREADY WARM on a different world, which is the case
## that separates "load_world invalidates" from "nobody has tried".
func _loaded() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar, cache warm (load case)")
	var world := WorldData.new()
	world.seed = 12345
	world.blocks = {}
	world.walls = {}
	world.amounts = {}
	sim.load_world(world)
	_agrees(sim, "an empty world was loaded over a warm cache")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: the loaded world holds no bazaar")


## Plant a sapling one tick short of sprouting and run the growth pass. Not `plant_sapling`, which spends
## an inventory sapling and asks questions this fixture has already answered; the subject is the growth
## write, and `Flora.grow` is what the sim calls every tick.
func _plant_and_grow(sim: FactorySim, cell: Vector2i) -> void:
	sim.sapling[cell] = FactorySim.SAPLING_GROW_TICKS - 1
	_check(FactorySim.SAPLING_SOILS.has(sim.solid.get(cell + Vector2i(0, 1), &"")),
		"the sapling at %s has soil under it, so it will actually grow" % cell)
	Flora.grow(sim)
	_check(sim.solid.get(cell, &"") == &"wood", "...and it grew: %s is wood now" % cell)


## The whole grid, scanned without the cache. This is the control, and it travels inside every case.
func _truth(sim: FactorySim) -> Dictionary:
	var bazaars: Array[Vector2i] = []
	var ruins: Array[Vector2i] = []
	for y: int in range(0, FactorySim.GRID_ROWS - FactorySim.BAZAAR_H):
		for x: int in range(0, FactorySim.GRID_COLS - FactorySim.BAZAAR_W + 1):
			var o := Vector2i(x, y)
			if sim.is_bazaar_at(o):
				bazaars.append(o)
			elif sim.bazaar_gap_at(o).x >= 0:
				ruins.append(o)
	return {"bazaars": bazaars, "ruins": ruins}


## Both cached answers against both scanned ones, as SETS of origins rather than as counts. Two lists of
## the same length can name different cells, and a count would call that agreement.
func _agrees(sim: FactorySim, what: String) -> void:
	var truth: Dictionary = _truth(sim)
	var cached_b: Array[Vector2i] = sim.find_bazaars().duplicate()
	var cached_r: Array[Vector2i] = []
	for d: Dictionary in sim.find_bazaar_ruins():
		cached_r.append(d["origin"])
	cached_b.sort()
	cached_r.sort()
	var truth_b: Array[Vector2i] = truth["bazaars"]
	var truth_r: Array[Vector2i] = truth["ruins"]
	truth_b.sort()
	truth_r.sort()
	_check(cached_b == truth_b, "the bazaars the cache names are the bazaars in the world after %s"
		% what + " (cache %s, world %s)" % [cached_b, truth_b])
	_check(cached_r == truth_r, "...and so are the ruins after %s (cache %s, world %s)"
		% [what, cached_r, truth_r])


## A complete bazaar at `o`: wood top beam, wood posts, open interior, earth under the interior.
func _bazaar(o: Vector2i) -> FactorySim:
	var sim := FactorySim.new()
	for dx: int in FactorySim.BAZAAR_W:
		sim.solid[o + Vector2i(dx, 0)] = &"wood"
	for dy: int in range(1, FactorySim.BAZAAR_H):
		sim.solid[o + Vector2i(0, dy)] = &"wood"
		sim.solid[o + Vector2i(FactorySim.BAZAAR_W - 1, dy)] = &"wood"
	for ix: int in range(1, FactorySim.BAZAAR_W - 1):
		sim.solid[o + Vector2i(ix, FactorySim.BAZAAR_H)] = &"earth"
	sim.invalidate_bazaars()
	return sim


## The same frame with `missing` left out: one wood short, which is what `bazaar_gap_at` calls a ruin.
func _ruin(o: Vector2i, missing: Vector2i) -> FactorySim:
	var sim: FactorySim = _bazaar(o)
	sim.solid.erase(missing)
	sim.invalidate_bazaars()
	return sim


## Nobody writes the coarse `solid` grid outside the files this layer knows about.
func _writers() -> void:
	var re := RegEx.create_from_string(SOLID_WRITE)
	_check(re.search(WRITE_YES) != null, "the writer scan sees a real `solid` write (positive control)")
	_check(re.search(WRITE_FINE) == null, "...and does not mistake a `_fine_solid` write for one")
	_check(re.search(WRITE_READ) == null, "...and does not mistake a read for a write")

	var found: Array[String] = []
	var scanned: int = 0
	for root: String in WRITER_ROOTS:
		scanned += _scan(root, re, found)
	found.sort()
	var want: Array[String] = SOLID_WRITERS.duplicate()
	want.sort()
	_check(scanned >= 30, "the writer scan actually read the shipping tree (%d .gd files)" % scanned)
	_check(found == want, "the files writing the coarse `solid` grid are the ones with a case here"
		+ " (found %s, expected %s)" % [found, want])


## Recurse a res:// directory, appending every .gd file whose code matches `re`. Returns how many were
## read, because a scan that read nothing agrees with any expectation.
func _scan(dir_path: String, re: RegEx, out: Array[String]) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_check(false, "%s opens, so the writer scan has something to scan" % dir_path)
		return 0
	var n: int = 0
	for d: String in dir.get_directories():
		n += _scan(dir_path + d + "/", re, out)
	for f: String in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		n += 1
		var src: String = FileAccess.get_file_as_string(dir_path + f)
		# COMMENTS OUT FIRST. `solid[cell] = ...` is written ABOUT in this tree as often as it is written,
		# and a detector that reads prose as code answers a clean tree with a confident wrong red. Strings
		# go too, for the same reason one level in.
		if re.search(_code_only(src)) != null:
			out.append(dir_path + f)
	return n


## Source with comments and string literals removed. Small on purpose, and its limit is stated rather than
## discovered: a `#` inside a string does not start a comment, a quote inside a comment does not start a
## string, and a triple-quoted block is skipped whole. Nothing else is understood, which is enough for a
## question about whether a `solid[...] =` appears in executable code.
func _code_only(src: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < src.length():
		var three: String = src.substr(i, 3)
		if three == TRIPLE_D or three == TRIPLE_S:
			var close: int = src.find(three, i + 3)
			i = src.length() if close == -1 else close + 3
			continue
		var c: String = src[i]
		if c == "\"" or c == "'":
			var j: int = i + 1
			while j < src.length() and src[j] != c and src[j] != "\n":
				j += 2 if src[j] == "\\" else 1
			i = j + 1
			continue
		if c == "#":
			while i < src.length() and src[i] != "\n":
				i += 1
			continue
		out += c
		i += 1
	return out
