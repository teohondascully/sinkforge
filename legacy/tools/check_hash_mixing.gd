extends "res://tools/check_base.gd"

## Harness layer: a multiply by a big odd constant is not a hash, and this layer refuses to let one be
## read as though it were.
##
## `i * K` for an odd K is an arithmetic progression. Every `% m` taken off an arithmetic progression is
## another arithmetic progression, and so is every low-bit slice of one. A bare multiplicative step
## followed by a modulus, a mask or a small right shift therefore does not scatter: it wears the costume
## of a hash, a famous constant and a modulus, and produces a lattice. Taking several different moduli off
## one product does not give several independent values either; it gives several views of one sequence.
##
## Two of these shipped, both visible on screen:
##
##   `((band * 2654435761) >> 3) % 3 == 0` was arithmetically identical to `(band / 8) % 3`, because
##   2654435761 = 8 * 331804470 + 1 and 331804470 is divisible by 3. Shelf bands came out 0..7 and nothing
##   else, so the strata that were meant to stack at unpredictable depths stacked at eight of them.
##
##   `(cyc * 2654435761) & 0x7fffffff` then `% 2` is exactly `cyc % 2`: the mask clears only bit 31 and the
##   constant is odd, so the low bit of the product is the low bit of the input. The bird crossing the sky
##   strictly alternated direction, every crossing, for the life of the build.
##
## Neither was found by looking at the code. Both were found by looking at the screen and asking why
## something that was supposed to be irregular was not. Static detection is the only cheap way to catch
## the third one, because the tell at runtime is a subtle regularity in a cue nobody is measuring.
##
## The correct shape carries entropy upward with a multiply and folds the high half back down with a
## xor-shift, so the low bits a caller reads are a function of the whole key rather than of the input
## almost intact:
##
##     var h: int = (n * 2654435761) & 0xFFFFFFFF
##     h = (h ^ (h >> 15)) & 0xFFFFFFFF
##     h = (h * 0x2545F491) & 0xFFFFFFFF
##     return (h ^ (h >> 16)) & 0xFFFFFFFF
##
## The rule.
##
## Every integer literal in the tree whose value is one of the known mixing constants below is a site,
## whether written in decimal or in hex, and whether written inline or reached through a file-level
## `const` alias. A site is judged only when the constant participates in a multiplication; a constant
## handed to `FastNoiseLite` as a seed, or xored into one, is a salt and is exempt, because there is no
## product whose bits anyone is about to read.
##
## A judged site holds when, inside the function that contains it:
##   1. there is an xor-shift fold, an `^` whose expression also contains a `>>`, at a position after the
##      constant, and
##   2. nothing narrows the value between the constant and that fold. Narrowing means `%`, a comparison, a
##      right shift that is not part of a fold, or an `&` against a mask narrower than 24 bits. A mask of
##      `0xFFFFFFFF` or `0x7fffffff` is not narrowing: it is width normalisation for GDScript's 64-bit
##      ints, and every correct site here uses one.
##
## A site with no enclosing function fails. So does a site whose function could not be resolved. The
## question this layer asks is "can the product be shown to have been folded", and every answer other than
## yes is no.
##
## The two-input case, decided here rather than left to the reader. `(c.x * A) ^ (c.y * B)` is genuinely
## better than a single product: it decorrelates the two axes, and it is the shape the four correct sites
## in this tree start from. It is still not accepted as the fold. Hold `c.y` fixed and the value is an
## arithmetic progression in `c.x` again, so `% m` on it is a lattice along that row, which is exactly the
## artefact that reads as regularity on screen. All four correct sites follow the xor with a fold anyway,
## so requiring one costs this tree nothing, and admitting the two-input xor as sufficient would be the
## only remaining way for a lattice to get back in.
##
## What this cannot see, stated because a static scan invites being trusted past its reach:
##   - a mixing constant that is not in the table below. New ones have to be added when they are authored.
##   - a multiply written with a constant reached through another file's class name where that constant is
##     not itself a known value, for example `Foo.STEP * 3` with `STEP` computed at runtime.
##   - a product returned unfolded from one function and consumed in another. Rule 1 still fails it, since
##     the defining function has no fold, but the reason it prints names the wrong end of the problem.
##   - anything about the quality of a mix that has a fold. This layer checks that the shape is present,
##     not that the result is well distributed.
##
## Non-vacuity. A scanner whose glob is wrong finds nothing and passes everything, which is the failure
## this repo has met most often, so the checks run in this order: a floor on the files read, a named
## anchor on each of the four correct sites already in the tree, and a set of synthetic controls run
## through the same judge on every invocation. The controls are the part that matters. They include both
## real defects, a fold placed after the consume, a two-input xor with no fold, a multiply at class scope
## and two correct shapes, so the judge is proved able to answer WRONG and able to answer OK on the same
## run that it clears the tree. A guard that has never returned WRONG is not known to work.
##
## Reads source and boots nothing, so it needs no display and no exclusivity.
##
##   godot --headless --path . --script res://tools/check_hash_mixing.gd

## The constants worth watching, value to a short label. Keyed by VALUE rather than by spelling, because
## `0x27d4eb2f` and `668265263` are the same constant and the tree writes both. Labels say where a value
## comes from only where that is certain; the rest say where it is used here, because an invented
## provenance in a report is worse than no provenance.
const KNOWN: Dictionary = {
	2654435761: "0x9E3779B1, 2^32 over the golden ratio",
	2654435769: "0x9E3779B9, the odd golden-ratio variant",
	2246822507: "0x85EBCA6B, murmur3 fmix32",
	2246822519: "0x85EBCA77, the fmix32 neighbour",
	3266489909: "0xC2B2AE35, murmur3 fmix32",
	3266489917: "0xC2B2AE3D, the fmix32 neighbour",
	461845907: "0x1B873593, murmur3 round constant",
	2146121005: "0x7FEB352D, low-bias 32-bit mixer",
	625341585: "0x2545F491, xorshift multiplier",
	374761393: "0x165667B1, in-tree mixing prime",
	668265263: "0x27D4EB2F, in-tree mixing prime",
	1274126177: "0x4BF19F61, in-tree second-stage multiplier",
	1867459473: "0x6F4F2B91, in-tree field salt",
}

## Below this the walk has plainly broken rather than the tree having shrunk. About 150 tracked `.gd` and
## 5 shaders today; a floor well under both catches a wrong root without going red on ordinary churn.
const GD_FLOOR: int = 120
const SHADER_FLOOR: int = 3

## An `&` against a mask at least this wide is width normalisation, not a read of the value. `0xFFFFFFFF`
## and `0x7fffffff` both sit above it and both appear on correct sites; `0xffff` sits below it and is a
## genuine extraction of the low bits.
const WIDE_MASK_MIN: int = 0x01000000

## The correct sites already in the tree, named as `file::function`. Each one must be FOUND and must be
## judged OK. A count floor would not do here: it passes on any four sites at all, including four the
## scanner found in its own constant table. If a function below is renamed this layer goes red, which is
## the correct amount of friction for moving the thing the instrument is calibrated against.
const ANCHORS: Array[String] = [
	"res://scenes/terrain_painter.gd::_fringe_hash",
	"res://src/data/seams.gd::grain",
	"res://src/data/seams.gd::_plane",
	# `sky_painter.gd::_hash` stood here and the merge removed the function: the star field now goes
	# through `Seams.grain`, which is the anchor two lines up. Dropped because the site MOVED, not to buy
	# green -- the coverage it provided is still anchored, by its new name.
]

## How far a product must be shifted right before taking the top bits counts as finalisation rather than
## as reading it raw. Half the 32-bit width these mixers work in: the top half of a multiplicative hash is
## the well-mixed half, which is the whole basis of Fibonacci hashing. Below this the read reaches into
## bits the multiply never stirred, and the site is judged unfolded.
const HIGH_TAKE_MIN: int = 16

## Extra files to judge, comma separated, for proving this layer red against a fixture. It can only ADD
## work: nothing here removes a file from the sweep or relaxes a rule, so a run with it set is a superset
## of a run without it, and a green run stays green for the same reasons.
const EXTRA_ENV: String = "SF_HASH_SCAN_EXTRA"

## Synthetic sources run through the same judge on every invocation. `sites` is the number of constant
## occurrences expected, `wrong` how many of those must be judged WRONG and `salt` how many must be exempt;
## the rest must be OK. `path` selects which scope parser runs and defaults to GDScript. Written as arrays
## of single lines rather than as triple-quoted blocks so that this file's own scan sees them as string
## content and not as code, which it does.
##
## The last two are shaders, and they carry more weight than their subject does. No shader in this tree
## uses a mixing constant, so the brace-depth scope has nothing real to exercise it and would otherwise be
## a half of the instrument that has never registered anything at all.
const CONTROLS: Array[Dictionary] = [
	{
		"why": "the shelf band: a product shifted three and taken mod three",
		"sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"func _is_shelf_band(row: int) -> bool:",
			"\tvar band: int = row / 24",
			"\treturn ((band * 2654435761) >> 3) % 3 == 0",
		],
	},
	{
		"why": "the bird: a product masked to 31 bits and taken mod two",
		"sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"func _draw_surface_life() -> void:",
			"\tvar bh: int = (cyc * 2654435761) & 0x7fffffff",
			"\tvar bx: float = lerpf(-80.0, 900.0, frac if bh % 2 == 0 else 1.0 - frac)",
		],
	},
	{
		"why": "a fold that arrives after the value has already been read",
		"sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"func _late_fold(n: int) -> int:",
			"\tvar h: int = (n * 2654435761) % 7",
			"\th = h ^ (h >> 13)",
			"\treturn h",
		],
	},
	{
		"why": "two inputs xored together and consumed with no fold at all",
		"sites": 2, "wrong": 2, "salt": 0,
		"src": [
			"func _pair(x: int, y: int) -> int:",
			"\tvar h: int = (x * 374761393) ^ (y * 668265263)",
			"\treturn h % 9",
		],
	},
	{
		"why": "a multiply at class scope, where no function can be shown to fold it",
		"sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"const STEP: int = 3 * 2654435761",
		],
	},
	{
		"why": "finalised by taking the top half, which is Fibonacci hashing and not a defect",
		"sites": 2, "wrong": 0, "salt": 0,
		"src": [
			"static func _top_bits(n: int) -> int:",
			"\tvar h: int = (n * 2654435761) & 0xFFFFFFFF",
			"\th = (h ^ (h >> 15)) & 0xFFFFFFFF",
			"\th = (h * 0x2545F491) & 0xFFFFFFFF",
			"\treturn h >> 16",
		],
	},
	{
		"why": "a shift too small to clear the weak bits still reads them",
		"sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"static func _shallow(n: int) -> int:",
			"\tvar h: int = (n * 2654435761) & 0xFFFFFFFF",
			"\treturn h >> 4",
		],
	},
	{
		"why": "the correct shape, multiply and fold twice over",
		"sites": 2, "wrong": 0, "salt": 0,
		"src": [
			"static func _hash(n: int) -> int:",
			"\tvar h: int = (n * 2654435761) & 0xFFFFFFFF",
			"\th = (h ^ (h >> 15)) & 0xFFFFFFFF",
			"\th = (h * 0x2545F491) & 0xFFFFFFFF",
			"\treturn (h ^ (h >> 16)) & 0xFFFFFFFF",
		],
	},
	{
		"why": "two inputs xored together and THEN folded, which is the shape this tree uses",
		"sites": 3, "wrong": 0, "salt": 0,
		"src": [
			"static func _pair_ok(x: int, y: int) -> int:",
			"\tvar h: int = (x * 374761393) ^ (y * 668265263)",
			"\th = (h ^ (h >> 13)) * 1274126177",
			"\treturn (h ^ (h >> 16)) & 0x7fffffff",
		],
	},
	{
		"why": "a constant xored in as a salt, never multiplied, which is not this defect",
		"sites": 1, "wrong": 0, "salt": 1,
		"src": [
			"func _salted(world_seed: int) -> int:",
			"\treturn world_seed ^ 0xc2b2ae35",
		],
	},
	{
		"why": "a named salt, counted once where it is declared and once where it is used",
		"sites": 2, "wrong": 0, "salt": 2,
		"src": [
			"const SALT: int = 0x85ebca6b",
			"func _use(world_seed: int) -> int:",
			"\treturn world_seed ^ SALT",
		],
	},
	{
		"why": "the same salt multiplied through its name, where the digits are three lines away",
		"sites": 2, "wrong": 1, "salt": 1,
		"src": [
			"const SALT: int = 0x85ebca6b",
			"func _bad_alias(n: int) -> int:",
			"\treturn (n * SALT) % 5",
		],
	},
	{
		"why": "a shader function, braces for scope, taking a modulus off a bare product",
		"path": "res://control.gdshader", "sites": 1, "wrong": 1, "salt": 0,
		"src": [
			"int band_of(int n) {",
			"\tint h = n * 2654435761;",
			"\treturn h % 3;",
			"}",
		],
	},
	{
		"why": "the same shader function with the fold put back",
		"path": "res://control.gdshader", "sites": 1, "wrong": 0, "salt": 0,
		"src": [
			"int band_of(int n) {",
			"\tint h = n * 2654435761;",
			"\th = h ^ (h >> 15);",
			"\treturn h % 3;",
			"}",
		],
	},
]

## Directories that would not open during the walk. A directory that refuses to open is not an empty one,
## and the difference has to reach the verdict.
var _unopenable: Array[String] = []


## The checkout this scan actually read, printed before any finding.
##
## This layer reads SOURCE, so every line it prints is a statement about one working tree and not about
## the project. Two refs disagreed twice about how many bad hash sites exist -- 2 against
## 4, then a site one of them called "unfixed by either of us" that was already correct on the other ref --
## and both disagreements were the same error: a finding published without the frame that produced it.
## A red naming a file and a line invites exactly that, because a path looks absolute and is not.
##
## `git` may be absent or may fail, and the honest answer then is that the ref is unknown. It must never
## fall back to a plausible-looking name: a wrong ref printed beside a real finding is worse than no ref,
## because it makes the frame error harder to spot rather than easier.
func _frame() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	var out: Array = []
	var code: int = OS.execute("git", ["-C", root, "rev-parse", "--abbrev-ref", "HEAD"], out, true)
	var branch: String = "unknown ref (git exit %d)" % code
	if code == 0 and not out.is_empty():
		var t: String = String(out[0]).strip_edges()
		if not t.is_empty():
			branch = t
	var sha: Array = []
	var scode: int = OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], sha, true)
	if scode == 0 and not sha.is_empty():
		var t2: String = String(sha[0]).strip_edges()
		if not t2.is_empty():
			branch += " @ " + t2
	return "%s  [%s]" % [root, branch]


func _initialize() -> void:
	print("== hash mixing: a multiply is not a hash ==")
	print("  scanned tree: %s" % _frame())
	print("  every path below is relative to THAT checkout; a site named here may be absent or already"
		+ " correct on another ref.")

	# The controls run first. If the judge cannot answer WRONG on a known defect there is no point reading
	# anything the tree has to say, and printing that fact before the sweep stops a broken instrument from
	# being read as a clean tree.
	_run_controls()

	var paths: Array[String] = []
	_walk("res://", paths)
	paths.sort()
	var extra: String = OS.get_environment(EXTRA_ENV)
	if not extra.is_empty():
		for p: String in extra.split(",", false):
			var t: String = p.strip_edges()
			if not t.is_empty() and not paths.has(t):
				paths.append(t)
		print("  (%s adds %s to the sweep)" % [EXTRA_ENV, extra])

	var texts: Dictionary = {}
	var unreadable: Array[String] = []
	var gd_seen: int = 0
	var shader_seen: int = 0
	for p: String in paths:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		if f == null:
			unreadable.append(p)
			continue
		var body: String = f.get_as_text()
		if body.is_empty():
			# No source file in this tree is empty. An empty read is a read that failed, and treating it as
			# a clean file is how a scanner reports a sweep it never performed.
			unreadable.append(p)
			continue
		texts[p] = body
		if p.ends_with(".gd"):
			gd_seen += 1
		else:
			shader_seen += 1

	_check(_unopenable.is_empty(),
		"every directory under res:// opened%s"
		% ("" if _unopenable.is_empty() else ": " + ", ".join(_unopenable)))
	_check(unreadable.is_empty(),
		"every source file read back non-empty%s"
		% ("" if unreadable.is_empty() else ": " + ", ".join(unreadable)))
	_check(gd_seen >= GD_FLOOR,
		"the walk found %d GDScript files (floor %d, under which assume the glob broke)" % [gd_seen, GD_FLOOR])
	_check(shader_seen >= SHADER_FLOOR,
		"…and %d shader files, so the shader half of the sweep is not silently empty" % shader_seen)

	# File-level `const` aliases for known values, so `SALT_VERTICAL * K` is a site even though the digits
	# are three hundred lines away. Collected across the whole tree because a const is reached by class
	# name from other files.
	var aliases: Dictionary = {}
	for p2: String in texts:
		_collect_aliases(str(texts[p2]), aliases)

	var judged: Array[Dictionary] = []
	var salted: Array[Dictionary] = []
	for p3: String in texts:
		for s: Dictionary in _judge(p3, str(texts[p3]), aliases):
			if bool(s["mul"]):
				judged.append(s)
			else:
				salted.append(s)

	# Non-vacuity, before any verdict. A scan that matched nothing satisfies "no site is wrong".
	_check(judged.size() + salted.size() > 0, "the scan found uses of the known mixing constants at all")
	_check(judged.size() >= ANCHORS.size(),
		"it found at least the %d multiplication sites already known to be correct (%d judged, %d exempt salts)"
		% [ANCHORS.size(), judged.size(), salted.size()])

	print("  judged sites (a known constant inside a multiplication):")
	var wrong: Array[String] = []
	var seen: Dictionary = {}
	for s2: Dictionary in judged:
		var key: String = "%s::%s" % [str(s2["path"]), str(s2["func"])]
		seen[key] = bool(s2["ok"]) and bool(seen.get(key, true))
		print("    %s:%d:%d  %s  in %s  %s — %s"
			% [str(s2["path"]).trim_prefix("res://"), int(s2["line"]), int(s2["col"]),
				str(s2["label"]), ("(class scope)" if str(s2["func"]).is_empty() else str(s2["func"]) + "()"),
				("OK" if bool(s2["ok"]) else "WRONG"), str(s2["why"])])
		if not bool(s2["ok"]):
			wrong.append("%s:%d %s" % [str(s2["path"]).trim_prefix("res://"), int(s2["line"]), str(s2["why"])])
	if not salted.is_empty():
		var by_file: Dictionary = {}
		for s3: Dictionary in salted:
			var fp: String = str(s3["path"]).trim_prefix("res://")
			by_file[fp] = int(by_file.get(fp, 0)) + 1
		var parts: Array[String] = []
		for fp2: String in by_file:
			parts.append("%s x%d" % [fp2, int(by_file[fp2])])
		parts.sort()
		print("  exempt (constant present, never multiplied): %s" % ", ".join(parts))

	# The anchors. Each named site must have been reached by the scan and judged OK. This is the check that
	# fails if a pattern here stops matching real code, which is the state in which every other check on
	# this page passes for the wrong reason.
	for a: String in ANCHORS:
		_check(seen.has(a) and bool(seen[a]),
			"%s is reached by the scan and judged correctly mixed%s"
			% [a.trim_prefix("res://"), ("" if seen.has(a) else " — NOT FOUND, so the scan missed it")])

	_check(wrong.is_empty(),
		"no product of a mixing constant has its bits read before it is folded%s"
		% ("" if wrong.is_empty() else " — " + "; ".join(wrong)))

	_verdict("check_hash_mixing",
		"%d multiplication sites judged and %d salts exempt across %d GDScript and %d shader files,"
		% [judged.size(), salted.size(), gd_seen, shader_seen]
		+ " with %d controls proving the judge fires both ways" % CONTROLS.size())


## Run every synthetic source through the same judge the tree gets, and hold each one to its stated
## counts. Named `CONTROL` in the output because the point is that the instrument answered, not that the
## specimen is interesting.
func _run_controls() -> void:
	for c: Dictionary in CONTROLS:
		var src: String = "\n".join(PackedStringArray(c["src"] as Array))
		var aliases: Dictionary = {}
		_collect_aliases(src, aliases)
		var sites: Array[Dictionary] = _judge(str(c.get("path", "res://control.gd")), src, aliases)
		var n_wrong: int = 0
		var n_salt: int = 0
		for s: Dictionary in sites:
			if not bool(s["mul"]):
				n_salt += 1
			elif not bool(s["ok"]):
				n_wrong += 1
		_check(sites.size() == int(c["sites"]) and n_wrong == int(c["wrong"]) and n_salt == int(c["salt"]),
			"CONTROL %s: %d site(s), %d wrong, %d exempt (expected %d/%d/%d)"
			% [str(c["why"]), sites.size(), n_wrong, n_salt,
				int(c["sites"]), int(c["wrong"]), int(c["salt"])])


## Every known-constant occurrence in one source, with a verdict on each. Returns dictionaries carrying
## path, line, col, label, `mul` (the constant is inside a multiplication and therefore judged), `func`
## (the enclosing function, "" at class scope), `ok` and `why`.
func _judge(path: String, text: String, aliases: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Cheap gate first: a file that does not spell any known value, in either base, and names no alias
	# cannot hold a site, so the per-character work below is skipped rather than paid on 150 files.
	if not _may_hold_a_site(text, aliases):
		return out

	var raw: PackedStringArray = text.replace("\r", "").split("\n")
	var code: PackedStringArray = PackedStringArray()
	for ln: String in raw:
		code.append(_strip(ln))

	var funcs: Array[Dictionary] = (_shader_functions(code) if path.ends_with(".gdshader")
		or path.ends_with(".gdshaderinc") else _gd_functions(code))

	for i: int in code.size():
		for tok: Dictionary in _constant_tokens(code[i], aliases):
			var site: Dictionary = {
				"path": path, "line": i + 1, "col": int(tok["col"]),
				"label": str(KNOWN.get(int(tok["value"]), "0x%X" % int(tok["value"]))),
				"mul": _in_multiply(code[i], int(tok["col"]), int(tok["col"]) + int(tok["len"])),
				"func": "", "ok": true, "why": "not multiplied, so no product's bits are being read",
			}
			if bool(site["mul"]):
				_rule(site, code, funcs, i, int(tok["col"]))
			out.append(site)
	return out


## The rule, applied to one judged site. Sets `func`, `ok` and `why` in place.
func _rule(site: Dictionary, code: PackedStringArray, funcs: Array[Dictionary], line: int, col: int) -> void:
	var fn: Dictionary = {}
	for f: Dictionary in funcs:
		if line >= int(f["first"]) and line <= int(f["last"]):
			fn = f
			break
	if fn.is_empty():
		# No enclosing body means nothing can be pointed at as the fold. The honest answer is that the mix
		# cannot be shown, and every answer other than yes is no.
		site["ok"] = false
		site["why"] = "multiplied outside any function, so no fold can be shown to follow it"
		return
	site["func"] = str(fn["name"])

	var fold_line: int = -1
	var fold_col: int = -1
	for j: int in range(line, int(fn["last"]) + 1):
		for fc: int in _fold_cols(code[j]):
			if j == line and fc <= col:
				continue      # a fold to the LEFT of the constant folded something else
			fold_line = j
			fold_col = fc
			break
		if fold_line >= 0:
			break
	if fold_line < 0:
		# A FOLD IS NOT THE ONLY WAY TO KEEP THE WEAK BITS OUT OF THE ANSWER, and this rule could not see
		# the other one. In `x * K mod 2^n` output bit i depends only on input bits 0..i, so the LOW bits
		# are the badly mixed ones and the high bits are the good ones. Discarding the low half with a
		# right shift protects exactly what a fold protects, by throwing the bad bits away instead of
		# stirring them in; it is Fibonacci hashing and it is not a defect.
		#
		# Found by this layer calling `layered_world_gen.gd::_band_hash` an arithmetic progression. That
		# function is multiply, fold, multiply, `return h >> 16`, and the rule read every `>>` as a read of
		# the product whatever the shift, so the one shift that makes the read SAFE was scored as the thing
		# that made it unsafe. MEASURED before changing anything, because the shape of the code is not the
		# property: over the seven groups that ship it picks shelf rows 0-3, 16-19, 28-31, 36-39, 52-55 and
		# 64-67, matching the rows the generator documents, and 64 sorted outputs have 63 DISTINCT GAPS.
		# Three or fewer is what a lattice looks like (three-distance theorem), so it is not one.
		#
		# The exemption is deliberately narrow: EVERY read of the product must be a right shift, and the
		# smallest of them must clear HIGH_TAKE_MIN. One `%`, one comparison or one narrow mask anywhere in
		# the window and the site is judged on the old rule, because those read the bits this defends.
		var shift: int = _high_take_shift(code, line, int(fn["last"]), col)
		if shift >= HIGH_TAKE_MIN:
			site["why"] = ("not folded, but the only read is `>> %d`, so the weak low bits never reach the answer"
				% shift)
			return
		site["ok"] = false
		site["why"] = ("the product is never folded in %s(); a multiply alone is an arithmetic progression"
			% str(fn["name"]))
		return

	for j2: int in range(line, fold_line + 1):
		for nw: Dictionary in _narrowings(code[j2]):
			var nc: int = int(nw["col"])
			if j2 == line and nc <= col:
				continue
			if j2 == fold_line and nc >= fold_col:
				continue
			site["ok"] = false
			site["why"] = "`%s` at %d:%d reads the product before the fold at %d:%d" % [
				str(nw["kind"]), j2 + 1, nc, fold_line + 1, fold_col]
			return
	site["why"] = "folded at %d:%d before anything reads it" % [fold_line + 1, fold_col]


## The smallest right shift among every read of the product between the constant and the end of its
## function, or -1 if ANY read is something other than a right shift (or a shift whose amount cannot be
## read as a literal). -1 routes the site back to the unfolded verdict, so the unresolvable case resolves
## toward red exactly as `_mask_is_narrow` does.
func _high_take_shift(code: PackedStringArray, line: int, last: int, col: int) -> int:
	var smallest: int = -1
	for j: int in range(line, last + 1):
		for nw: Dictionary in _narrowings(code[j]):
			var nc: int = int(nw["col"])
			if j == line and nc <= col:
				continue
			if str(nw["kind"]) != ">>":
				return -1
			var amt: int = _shift_amount(code[j], nc)
			if amt < 0:
				return -1
			smallest = amt if smallest < 0 else mini(smallest, amt)
	return smallest


## The literal shift amount immediately right of the `>>` at `col`, or -1 when it is not a plain integer.
func _shift_amount(code: String, col: int) -> int:
	var i: int = col + 2
	while i < code.length() and code[i] == " ":
		i += 1
	var digits: String = ""
	while i < code.length() and code[i] >= "0" and code[i] <= "9":
		digits += code[i]
		i += 1
	return int(digits) if digits != "" else -1


## True when the text spells a known value in either base, or names a known alias. Sound as a gate because
## a site is produced only by one of those two spellings, and an alias's own definition carries the digits
## in whichever file defines it.
func _may_hold_a_site(text: String, aliases: Dictionary) -> bool:
	for v: int in KNOWN:
		if text.contains(str(v)) or text.containsn("0x%x" % v):
			return true
	for name: String in aliases:
		if text.contains(name):
			return true
	return false


## File-level `const NAME ... = <known literal>` declarations, added to `out` as NAME -> value. Collected
## across the whole tree, because a const is reached by class name from other files and a per-file table
## would miss exactly that.
func _collect_aliases(text: String, out: Dictionary) -> void:
	for raw: String in text.replace("\r", "").split("\n"):
		var ln: String = _strip(raw)
		var t: String = ln.strip_edges()
		if not t.begins_with("const "):
			continue
		var eq: int = t.find("=")
		if eq < 0:
			continue
		var lhs: String = t.substr(6, eq - 6).strip_edges()
		var colon: int = lhs.find(":")
		if colon >= 0:
			lhs = lhs.substr(0, colon).strip_edges()
		if lhs.is_empty() or not _is_ident(lhs):
			continue
		var lits: Array[Dictionary] = _literals(t.substr(eq + 1))
		if lits.size() != 1:
			continue      # a computed const is not an alias for one value
		if KNOWN.has(int(lits[0]["value"])):
			out[lhs] = int(lits[0]["value"])


## Occurrences of a known constant on one stripped line, as literals and as alias identifiers.
##
## An alias's own declaration is not one of its uses. Without that exclusion `const SALT = 0x85ebca6b`
## reports twice, once for the digits and once for the name they were given, and the site count in the
## report stops being a count of anything.
func _constant_tokens(code: String, aliases: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lit: Dictionary in _literals(code):
		if KNOWN.has(int(lit["value"])):
			out.append(lit)
	if not aliases.is_empty():
		var decl_end: int = -1
		if code.strip_edges().begins_with("const "):
			decl_end = code.find("=")
		for id: Dictionary in _identifiers(code):
			if aliases.has(str(id["text"])) and (decl_end < 0 or int(id["col"]) > decl_end):
				out.append({"col": int(id["col"]), "len": str(id["text"]).length(),
					"value": int(aliases[str(id["text"])])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["col"]) < int(b["col"]))
	return out


## Is the token spanning [start, end) an operand of a `*`? Whitespace and brackets are stepped over on
## both sides, so `(band * K)` and `(K) * band` both count. `f(K) * b` counts too, which flags an argument
## that is not the multiplicand; that direction is the safe one and the report names the line.
func _in_multiply(code: String, start: int, end: int) -> bool:
	var j: int = start - 1
	while j >= 0 and (code[j] == " " or code[j] == "\t" or code[j] == "("):
		j -= 1
	if j >= 0 and code[j] == "*":
		return true
	var k: int = end
	while k < code.length() and (code[k] == " " or code[k] == "\t" or code[k] == ")"):
		k += 1
	return k < code.length() and code[k] == "*"


## Columns of the `^` of every xor-shift fold on one stripped line: an `^` with a `>>` to its right. The
## `>>` has to be on the same line because a fold split across lines is not a shape this tree writes, and
## admitting one would mean pairing operators across statements without a parser.
func _fold_cols(code: String) -> Array[int]:
	var out: Array[int] = []
	var ops: Array[Dictionary] = _ops(code)
	var last_shift: int = -1
	for i: int in range(ops.size() - 1, -1, -1):
		var o: Dictionary = ops[i]
		if str(o["op"]) == ">>":
			last_shift = int(o["col"])
		elif str(o["op"]) == "^" and last_shift > int(o["col"]):
			out.append(int(o["col"]))
	out.reverse()
	return out


## Every operator on one stripped line that reads a value's bits rather than mixing them, as
## {col, kind}. A right shift counts only when no `^` precedes it on the line, because the shift inside a
## fold is the mixing step itself and not a read of the result.
func _narrowings(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ops: Array[Dictionary] = _ops(code)
	var first_xor: int = -1
	for o: Dictionary in ops:
		if str(o["op"]) == "^":
			first_xor = int(o["col"])
			break
	for o2: Dictionary in ops:
		var op: String = str(o2["op"])
		var col: int = int(o2["col"])
		if op == "%" or op == "cmp":
			out.append({"col": col, "kind": ("%" if op == "%" else "a comparison")})
		elif op == ">>" and (first_xor < 0 or first_xor > col):
			out.append({"col": col, "kind": ">>"})
		elif op == "&" and _mask_is_narrow(code, col):
			out.append({"col": col, "kind": "&"})
	return out


## Is the `&` at `col` a narrowing mask? A numeric operand at least WIDE_MASK_MIN wide on either side says
## no; anything else, including a named mask this layer cannot evaluate, says yes. The unresolvable case
## resolves toward red on purpose: it can only fire in the gap between a multiply and its fold, which is a
## few characters wide, and a false report there is cheap next to a missed lattice.
func _mask_is_narrow(code: String, col: int) -> bool:
	for lit: Dictionary in _literals(code):
		var s: int = int(lit["col"])
		var e: int = s + int(lit["len"])
		var adjacent: bool = false
		if s > col:
			adjacent = _only_brackets(code, col + 1, s)
		elif e <= col:
			adjacent = _only_brackets(code, e, col)
		if adjacent and int(lit["value"]) >= WIDE_MASK_MIN:
			return false
	return true


func _only_brackets(code: String, from: int, to: int) -> bool:
	for i: int in range(from, to):
		if not (code[i] == " " or code[i] == "\t" or code[i] == "(" or code[i] == ")"):
			return false
	return true


## Operators on one stripped line, as {op, col}. Two-character forms are consumed whole so that `>>` is
## never read as a comparison and `->` never as one either.
func _ops(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i: int = 0
	var n: int = code.length()
	while i < n:
		var c: String = code[i]
		var d: String = code[i + 1] if i + 1 < n else ""
		if c == ">" and d == ">":
			out.append({"op": ">>", "col": i})
			i += 2
		elif c == "<" and d == "<":
			i += 2
		elif d == "=" and (c == "=" or c == "!" or c == "<" or c == ">"):
			out.append({"op": "cmp", "col": i})
			i += 2
		elif c == "&" and d == "&":
			i += 2
		elif c == "^":
			out.append({"op": "^", "col": i})
			i += 1
		elif c == "%":
			out.append({"op": "%", "col": i})
			i += 1
		elif c == "&":
			out.append({"op": "&", "col": i})
			i += 1
		elif (c == "<" or c == ">") and not (c == ">" and i > 0 and code[i - 1] == "-"):
			out.append({"op": "cmp", "col": i})
			i += 1
		else:
			i += 1
	return out


## Integer literals on one stripped line, decimal or hex, as {col, len, value}. A literal touching a `.`
## or an identifier character on either side is skipped: that is a float or part of a name, not a value
## anyone is multiplying by.
func _literals(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i: int = 0
	var n: int = code.length()
	while i < n:
		if not _is_digit(code[i]):
			i += 1
			continue
		if i > 0 and (_is_word(code[i - 1]) or code[i - 1] == "."):
			while i < n and (_is_word(code[i]) or code[i] == "."):
				i += 1
			continue
		var start: int = i
		var hex: bool = code[i] == "0" and i + 1 < n and (code[i + 1] == "x" or code[i + 1] == "X")
		if hex:
			i += 2
			while i < n and (_is_hex(code[i]) or code[i] == "_"):
				i += 1
		else:
			while i < n and (_is_digit(code[i]) or code[i] == "_"):
				i += 1
		var raw: String = code.substr(start, i - start).replace("_", "")
		if i < n and (code[i] == "." or _is_word(code[i])):
			# a float, an exponent, or a suffix; not an integer constant
			while i < n and (_is_word(code[i]) or code[i] == "."):
				i += 1
			continue
		out.append({"col": start, "len": i - start,
			"value": (raw.hex_to_int() if hex else raw.to_int())})
	return out


## Identifiers on one stripped line, as {col, text}.
func _identifiers(code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i: int = 0
	var n: int = code.length()
	while i < n:
		if not (_is_alpha(code[i]) or code[i] == "_"):
			i += 1
			continue
		var start: int = i
		while i < n and _is_word(code[i]):
			i += 1
		out.append({"col": start, "text": code.substr(start, i - start)})
	return out


## Function bodies in a GDScript source, as {name, first, last} over zero-based line indexes. The body is
## bounded the way GDScript bounds it, by the next non-blank line at an indentation no deeper than the
## `func` itself. Blank and comment-only lines cannot close a body, because after stripping they are
## indistinguishable from each other and neither ends a function.
func _gd_functions(code: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i: int = 0
	while i < code.size():
		var t: String = code[i].strip_edges()
		if not (t.begins_with("func ") or t.begins_with("static func ")):
			i += 1
			continue
		var indent: int = _indent(code[i])
		# A signature may wrap; the body starts after the line whose statement closes with a colon.
		var head: int = i
		while head < code.size() and not code[head].strip_edges().ends_with(":"):
			head += 1
		if head >= code.size():
			head = i
		var last: int = code.size() - 1
		var j: int = head + 1
		while j < code.size():
			if code[j].strip_edges().is_empty():
				j += 1
				continue
			if _indent(code[j]) <= indent:
				last = j - 1
				break
			j += 1
		out.append({"name": _func_name(t), "first": head + 1, "last": last})
		i = head + 1
	return out


## Top-level braced blocks in a shader source, as {name, first, last}. Shaders have no indentation rule to
## lean on, so the scope is the brace depth, and the name is whatever the opening line declares.
func _shader_functions(code: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var depth: int = 0
	var start: int = -1
	for i: int in code.size():
		var ln: String = code[i]
		for k: int in ln.length():
			if ln[k] == "{":
				if depth == 0:
					start = i
				depth += 1
			elif ln[k] == "}":
				depth -= 1
				if depth <= 0:
					if start >= 0:
						out.append({"name": _shader_name(code[start]), "first": start, "last": i})
					depth = 0
					start = -1
	return out


func _func_name(stripped: String) -> String:
	var t: String = stripped.trim_prefix("static ").trim_prefix("func ").strip_edges()
	var paren: int = t.find("(")
	return t.substr(0, paren).strip_edges() if paren > 0 else t


func _shader_name(line: String) -> String:
	var t: String = line.strip_edges()
	var paren: int = t.find("(")
	if paren > 0:
		t = t.substr(0, paren)
	var sp: int = t.rfind(" ")
	return (t.substr(sp + 1) if sp >= 0 else t).strip_edges()


func _indent(line: String) -> int:
	var n: int = 0
	while n < line.length() and (line[n] == "\t" or line[n] == " "):
		n += 1
	return n


## One source line with every comment and string literal blanked to spaces of the same width, so that a
## column in the result is a column in the file. Strings are closed at end of line, which is where
## GDScript closes them; a triple-quoted block therefore reads as code, and the only consequence is that
## its contents are scanned, which is the safe direction.
##
## The sigil in front of a quote is blanked with it. `&"stone"` and `^"path"` would otherwise leave a bare
## `&` or `^` behind, and this layer reads both as operators.
func _strip(line: String) -> String:
	var out: String = ""
	var i: int = 0
	var n: int = line.length()
	var quote: String = ""
	while i < n:
		var c: String = line[i]
		if quote != "":
			if c == "\\":
				out += " "
				i += 1
				if i < n:
					out += " "
					i += 1
				continue
			if c == quote:
				quote = ""
			out += " "
			i += 1
			continue
		if c == "#":
			while i < n:
				out += " "
				i += 1
			break
		if c == "\"" or c == "'":
			quote = c
			if out.length() > 0 and out[out.length() - 1] in ["&", "^", "$"]:
				out = out.substr(0, out.length() - 1) + " "
			out += " "
			i += 1
			continue
		out += c
		i += 1
	return out


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _is_alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _is_word(c: String) -> bool:
	return _is_alpha(c) or _is_digit(c) or c == "_"


func _is_hex(c: String) -> bool:
	return _is_digit(c) or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")


func _is_ident(s: String) -> bool:
	if s.is_empty() or _is_digit(s[0]):
		return false
	for i: int in s.length():
		if not _is_word(s[i]):
			return false
	return true


## Every `.gd` and shader source under `res://`, excluding dot-directories and the gitignored
## `tools/_scratch_*` throwaways. The scratch files are excluded because they are not in the tree: several
## checkouts keep their own, they are deleted without notice, and a layer that judged them would report on
## code nobody has committed. A fixture is pointed at this layer through EXTRA_ENV instead.
func _walk(dir_path: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		_unopenable.append(dir_path)
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(full, out)
		elif not n.begins_with("_scratch_") and (n.ends_with(".gd") or n.ends_with(".gdshader")
				or n.ends_with(".gdshaderinc")):
			out.append(full)
		n = d.get_next()
	d.list_dir_end()
